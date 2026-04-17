# stunnel + tun2socks Architecture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the router's openconnect/DTLS VPN stack with a TCP-only stunnel + badvpn-tun2socks path, routing all LAN traffic through the existing server-side stunnel → haproxy → cn2 → dante SOCKS5 chain. Preserves split-tunnel semantics, video acceleration, 5-minute auth revalidation, and plain-router fallback on auth failure.

**Architecture:** Router runs `stunnel` client (localhost SOCKS listener ← TLS tunnel → server port from env.local) and `badvpn-tun2socks` (tun0 ← SOCKS5). nftables chains unchanged except `vpn_vipin` literal → `tun0`. Auth response at `POST /api/v1/router-auth` (with new `source=stunnel`) delivers tunnel port, CA cert, DNS stunnel host/port, default split mode — all sourced from backend `env.local`.

**Tech Stack:** OpenWrt 25.12.1, busybox ash, procd, stunnel-openssl, badvpn-tun2socks, nftables/fw4, Lua LuCI, bats (tests).

**Spec:** `docs/superpowers/specs/2026-04-17-stunnel-tun2socks-architecture-design.md`
**Branch:** `feat/stunnel-tun2socks-architecture`

---

## File Structure

**Create:**
- `files/etc/uci-defaults/60-stunnel-migration` — one-time UCI migration on firmware upgrade
- `tests/bats/test_vipin_vpn_stunnel.bats` — unit tests for new `vipin-vpn` helpers (MOCK mode)
- `tests/bats/test_vipin_auth_check_stunnel.bats` — unit tests for new auth-check loop (MOCK mode)

**Modify:**
- `files/etc/init.d/vipin-vpn` — full rewrite (openconnect → stunnel + tun2socks orchestration)
- `files/usr/sbin/vipin-auth-check` — revised main loop + watchdog + fetch-from-auth logic
- `files/usr/sbin/vipin-vpn-routing` — `vpn_vipin` → `tun0` in 6 locations
- `files/usr/lib/lua/luci/controller/vpn.lua` — `api_login` starts stack; new `api_server_change`; `api_status` returns `auth_status` + `vpn_connected`
- `files/usr/lib/lua/luci/view/vpn/settings.htm` — remove toggle + logout button, add auth_status banner, server-onchange trigger
- `files/usr/lib/lua/luci/view/vpn/i18n/*.lua` (17 locales) — new banner strings
- `files/etc/config/vipin` — drop `enabled`, add `auth_status`
- `configs/*.config` (1071 files) — replace `CONFIG_PACKAGE_openconnect=y` with `CONFIG_PACKAGE_stunnel-openssl=y` + `CONFIG_PACKAGE_tun2socks=y`

**Delete:**
- `files/usr/sbin/vipin-vpnc-script`

Each file has a single responsibility: init.d = orchestration, auth-check = revalidation+watchdog, vpn-routing = nft chains, controller = HTTP API, view = presentation, migration = one-time cleanup.

---

## Task 1: UCI migration script

Drops stale `openconnect` UCI keys and seeds `auth_status=ok` so a fresh boot doesn't flash a false error banner before first auth.

**Files:**
- Create: `files/etc/uci-defaults/60-stunnel-migration`

- [ ] **Step 1: Write the migration script**

Create `files/etc/uci-defaults/60-stunnel-migration`:

```sh
#!/bin/sh
# One-shot migration for stunnel+tun2socks architecture.
# Removes obsolete openconnect UCI keys and initializes new ones.

uci -q delete vipin.vpn.enabled
uci -q delete vipin.vpn.cert_pin

# Seed auth_status=ok so first boot does not show an error banner
# before vipin-auth-check has a chance to run.
[ -z "$(uci -q get vipin.vpn.auth_status)" ] && uci set vipin.vpn.auth_status='ok'

# Default split_mode to 'forward' on first install (overwrite only if unset).
[ -z "$(uci -q get vipin.vpn.split_mode)" ] && uci set vipin.vpn.split_mode='forward'

uci commit vipin

# Also remove the legacy openconnect cert pin file if present.
rm -f /etc/vipin/cert_pin

exit 0
```

- [ ] **Step 2: Mark executable**

```bash
chmod +x files/etc/uci-defaults/60-stunnel-migration
```

- [ ] **Step 3: Syntax-check**

```bash
sh -n files/etc/uci-defaults/60-stunnel-migration && echo OK
```

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add files/etc/uci-defaults/60-stunnel-migration
git commit -m "feat(migration): add 60-stunnel-migration uci-defaults for architecture switch"
```

---

## Task 2: Rename `vpn_vipin` → `tun0` in vipin-vpn-routing

nft chain structure unchanged; only the interface name changes because tun2socks creates `tun0` instead of openconnect's `vpn_vipin`.

**Files:**
- Modify: `files/usr/sbin/vipin-vpn-routing`

- [ ] **Step 1: Inventory every `vpn_vipin` reference**

```bash
grep -n 'vpn_vipin' files/usr/sbin/vipin-vpn-routing
```

Expected: about 6 matches (chain oifname references, route checks, comments).

- [ ] **Step 2: Replace every literal `vpn_vipin` with `tun0`**

Use sed in-place:

```bash
sed -i 's/vpn_vipin/tun0/g' files/usr/sbin/vipin-vpn-routing
```

- [ ] **Step 3: Verify no `vpn_vipin` remains**

```bash
grep -c 'vpn_vipin' files/usr/sbin/vipin-vpn-routing
```

Expected: `0`

- [ ] **Step 4: Syntax-check**

```bash
sh -n files/usr/sbin/vipin-vpn-routing && echo OK
```

Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-vpn-routing
git commit -m "refactor(vpn-routing): rename vpn_vipin→tun0 for tun2socks architecture"
```

---

## Task 3a: `vipin-vpn` helper — `resolve_connect_server`

Router location + UCI-selected server determine the actual TLS peer. If router is non-CN and user picked `cn.fanq.in`, we connect to `un.fanq.in` (un is a cn alias with CN exit via cn2). Display/UCI stays `cn.fanq.in`.

**Files:**
- Create: `tests/bats/test_vipin_vpn_stunnel.bats`

- [ ] **Step 1: Write failing bats test**

Create `tests/bats/test_vipin_vpn_stunnel.bats`:

```bash
#!/usr/bin/env bats

load fixtures/common

setup() {
    # Source the init script in MOCK mode. We only need function definitions.
    export VIPIN_VPN_MOCK=1
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    # Point UCI lookups at a test-only config file; stub when MOCK=1.
}

teardown() {
    rm -rf "$VIPIN_CONFIG_DIR"
}

@test "resolve_connect_server: non-CN router + cn.fanq.in -> un.fanq.in" {
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; resolve_connect_server'
    [ "$status" -eq 0 ]
    [ "$output" = "un.fanq.in" ]
}

@test "resolve_connect_server: CN router + cn.fanq.in -> cn.fanq.in" {
    export VIPIN_VPN_ROUTER_COUNTRY=cn
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; resolve_connect_server'
    [ "$status" -eq 0 ]
    [ "$output" = "cn.fanq.in" ]
}

@test "resolve_connect_server: non-CN router + jp.fanq.in -> jp.fanq.in" {
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=jp.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; resolve_connect_server'
    [ "$status" -eq 0 ]
    [ "$output" = "jp.fanq.in" ]
}
```

- [ ] **Step 2: Run test (expect fail — function missing)**

```bash
bats tests/bats/test_vipin_vpn_stunnel.bats
```

Expected: FAIL (`resolve_connect_server: command not found` or similar).

- [ ] **Step 3: Implement the helper inside `files/etc/init.d/vipin-vpn`**

Open `files/etc/init.d/vipin-vpn` and add near the top (after shebang + START/STOP lines, before `get_config`):

```sh
# MOCK mode: functions can be sourced for tests without side effects.
VIPIN_VPN_MOCK="${VIPIN_VPN_MOCK:-0}"

resolve_connect_server() {
    # Returns the hostname stunnel should actually connect to.
    # UCI-selected server is what the user picked (and what we display);
    # if they picked cn.fanq.in but the router is outside CN, we connect
    # to un.fanq.in — an overseas frontend that forwards CN traffic to cn2.
    # Treats un as a cn alias so the rest of the codebase doesn't care.
    local router_country uci_server base_domain
    if [ "$VIPIN_VPN_MOCK" = "1" ]; then
        router_country="$VIPIN_VPN_ROUTER_COUNTRY"
        uci_server="$VIPIN_VPN_UCI_SERVER"
        base_domain="$VIPIN_VPN_BASE_DOMAIN"
    else
        router_country=$(/usr/sbin/vipin-detect 2>/dev/null | \
            grep -o '"country": *"[^"]*"' | cut -d'"' -f4)
        [ -z "$router_country" ] && router_country="$(uci -q get vipin.vpn.country || echo cn)"
        uci_server=$(uci -q get vipin.vpn.server)
        base_domain=$(uci -q get vipin.vpn.base_domain || echo fanq.in)
    fi
    if [ "$router_country" != "cn" ] && \
       echo "$uci_server" | grep -q "^cn\.${base_domain}$"; then
        echo "un.${base_domain}"
    else
        echo "$uci_server"
    fi
}
```

- [ ] **Step 4: Run tests (expect pass)**

```bash
bats tests/bats/test_vipin_vpn_stunnel.bats
```

Expected: 3 of 3 pass.

- [ ] **Step 5: Commit**

```bash
git add tests/bats/test_vipin_vpn_stunnel.bats files/etc/init.d/vipin-vpn
git commit -m "feat(vpn): add resolve_connect_server helper (un alias for cn)"
```

---

## Task 3b: `vipin-vpn` helper — `fetch_auth_params`

Calls the backend `POST /api/v1/router-auth` with `source=stunnel`, writes the JSON response to `/etc/vipin/auth-params.json`, and returns: 0=ok, 1=expired/invalid, 2=network error.

**Files:**
- Modify: `files/etc/init.d/vipin-vpn`
- Modify: `tests/bats/test_vipin_vpn_stunnel.bats`

- [ ] **Step 1: Add failing tests**

Append to `tests/bats/test_vipin_vpn_stunnel.bats`:

```bash
@test "fetch_auth_params: status=ok writes params file and returns 0" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_API_RESPONSE='{"status":"ok","session_expires":1700000000,"tunnel":{"port":22,"ca_cert":"CERT"},"dns":{"stunnel_host":"cn2.fanq.in","stunnel_port":994},"split":{"default_mode":"forward"}}'
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; fetch_auth_params user pass AA:BB'
    [ "$status" -eq 0 ]
    [ -f "$VIPIN_CONFIG_DIR/auth-params.json" ]
    grep -q '"status":"ok"' "$VIPIN_CONFIG_DIR/auth-params.json"
    rm -rf "$VIPIN_CONFIG_DIR"
}

@test "fetch_auth_params: status=expired returns 1" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_API_RESPONSE='{"status":"expired","message":"trial ended"}'
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; fetch_auth_params user pass AA:BB'
    [ "$status" -eq 1 ]
    rm -rf "$VIPIN_CONFIG_DIR"
}

@test "fetch_auth_params: empty response (network) returns 2" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_API_RESPONSE=''
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; fetch_auth_params user pass AA:BB'
    [ "$status" -eq 2 ]
    rm -rf "$VIPIN_CONFIG_DIR"
}
```

- [ ] **Step 2: Run tests (expect fail — function missing)**

```bash
bats tests/bats/test_vipin_vpn_stunnel.bats
```

Expected: 3 new tests fail.

- [ ] **Step 3: Implement `fetch_auth_params` in `files/etc/init.d/vipin-vpn`**

Add after `resolve_connect_server`:

```sh
fetch_auth_params() {
    # POST /api/v1/router-auth source=stunnel with creds, write response to
    # $VIPIN_CONFIG_DIR/auth-params.json.
    # Exit codes: 0=ok, 1=expired/invalid, 2=network error.
    local username="$1" password="$2" mac="$3"
    local cfgdir="${VIPIN_CONFIG_DIR:-/etc/vipin}"
    local api_base response status
    mkdir -p "$cfgdir"

    if [ "$VIPIN_VPN_MOCK" = "1" ]; then
        response="$VIPIN_VPN_API_RESPONSE"
    else
        api_base=$(uci -q get vipin.vpn.site_url || echo "https://www.anyfq.com")
        response=$(wget -q -O- --timeout=10 \
            "${api_base}/api/v1/router-auth" \
            --post-data="username=${username}&credentials=${password}&mac=${mac}&source=stunnel" \
            2>/dev/null)
    fi

    if [ -z "$response" ]; then
        return 2
    fi

    echo "$response" > "$cfgdir/auth-params.json"
    status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    case "$status" in
        ok) return 0 ;;
        expired|invalid|not_vip) return 1 ;;
        *) return 2 ;;
    esac
}
```

- [ ] **Step 4: Run tests (expect pass)**

```bash
bats tests/bats/test_vipin_vpn_stunnel.bats
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add tests/bats/test_vipin_vpn_stunnel.bats files/etc/init.d/vipin-vpn
git commit -m "feat(vpn): add fetch_auth_params helper for POST /api/v1/router-auth"
```

---

## Task 3c: `vipin-vpn` helper — `render_stunnel_conf` and `extract_ca_cert`

Renders the stunnel client config from the auth response + UCI-selected server (mapped through `resolve_connect_server`).

**Files:**
- Modify: `files/etc/init.d/vipin-vpn`
- Modify: `tests/bats/test_vipin_vpn_stunnel.bats`

- [ ] **Step 1: Add failing tests**

Append to `tests/bats/test_vipin_vpn_stunnel.bats`:

```bash
@test "extract_ca_cert: writes CA from auth-params.json" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    cat > "$VIPIN_CONFIG_DIR/auth-params.json" <<EOF
{"status":"ok","tunnel":{"port":22,"ca_cert":"-----BEGIN CERTIFICATE-----\nMIIBXX\n-----END CERTIFICATE-----\n"}}
EOF
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; extract_ca_cert'
    [ "$status" -eq 0 ]
    [ -f "$VIPIN_CONFIG_DIR/stunnel-ca.pem" ]
    grep -q 'BEGIN CERTIFICATE' "$VIPIN_CONFIG_DIR/stunnel-ca.pem"
    rm -rf "$VIPIN_CONFIG_DIR"
}

@test "render_stunnel_conf: uses port from auth + connect_server from resolve" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    cat > "$VIPIN_CONFIG_DIR/auth-params.json" <<EOF
{"status":"ok","tunnel":{"port":22,"ca_cert":"CERT"}}
EOF
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; render_stunnel_conf'
    [ "$status" -eq 0 ]
    [ -f "$VIPIN_CONFIG_DIR/stunnel-client.conf" ]
    grep -q 'connect = un.fanq.in:22' "$VIPIN_CONFIG_DIR/stunnel-client.conf"
    grep -q 'accept = 127.0.0.1:1080' "$VIPIN_CONFIG_DIR/stunnel-client.conf"
    grep -q 'client = yes' "$VIPIN_CONFIG_DIR/stunnel-client.conf"
    rm -rf "$VIPIN_CONFIG_DIR"
}
```

- [ ] **Step 2: Run tests (expect fail)**

```bash
bats tests/bats/test_vipin_vpn_stunnel.bats
```

Expected: 2 new tests fail.

- [ ] **Step 3: Implement `extract_ca_cert` and `render_stunnel_conf`**

Add after `fetch_auth_params`:

```sh
extract_ca_cert() {
    # Pull ca_cert field out of auth-params.json into a PEM file.
    local cfgdir="${VIPIN_CONFIG_DIR:-/etc/vipin}"
    local params="$cfgdir/auth-params.json"
    [ -f "$params" ] || return 1
    # The ca_cert value is JSON-string with \n escapes — unescape to real newlines.
    awk 'match($0, /"ca_cert":"[^"]*"/) {
        s = substr($0, RSTART+11, RLENGTH-12)
        gsub(/\\n/, "\n", s)
        print s
    }' "$params" > "$cfgdir/stunnel-ca.pem"
    [ -s "$cfgdir/stunnel-ca.pem" ]
}

render_stunnel_conf() {
    # Build the stunnel client config from auth-params.json + resolved server.
    local cfgdir="${VIPIN_CONFIG_DIR:-/etc/vipin}"
    local params="$cfgdir/auth-params.json"
    [ -f "$params" ] || return 1

    local port connect_host
    port=$(grep -o '"port":[0-9]*' "$params" | head -1 | cut -d: -f2)
    connect_host=$(resolve_connect_server)
    [ -z "$port" ] || [ -z "$connect_host" ] && return 1

    cat > "$cfgdir/stunnel-client.conf" <<EOF
; Generated by vipin-vpn start_service — do not edit by hand.
pid = /var/run/vipin-stunnel.pid
foreground = yes
debug = 4
output = /var/log/vipin-stunnel.log

[vipn]
client = yes
accept = 127.0.0.1:1080
connect = ${connect_host}:${port}
CAfile = ${cfgdir}/stunnel-ca.pem
verifyChain = yes
checkHost = ${connect_host}
EOF
}
```

- [ ] **Step 4: Run tests (expect pass)**

```bash
bats tests/bats/test_vipin_vpn_stunnel.bats
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add tests/bats/test_vipin_vpn_stunnel.bats files/etc/init.d/vipin-vpn
git commit -m "feat(vpn): add render_stunnel_conf and extract_ca_cert helpers"
```

---

## Task 3d: `vipin-vpn` helper — `configure_dns`

Implements the 4-matrix DNS decision. When router-country != cn AND server-country == cn, swap dnsmasq upstream to the stunnel bridge; otherwise use local dnscrypt-proxy.

**Files:**
- Modify: `files/etc/init.d/vipin-vpn`
- Modify: `tests/bats/test_vipin_vpn_stunnel.bats`

- [ ] **Step 1: Add failing tests**

Append:

```bash
@test "configure_dns: overseas router + cn server -> stunnel chain upstream" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; configure_dns'
    [ "$status" -eq 0 ]
    [ "$output" = "127.0.0.1#5356" ]
}

@test "configure_dns: cn router + cn server -> dnscrypt upstream" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=cn
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; configure_dns'
    [ "$status" -eq 0 ]
    [ "$output" = "127.0.0.1#5353" ]
}

@test "configure_dns: overseas router + jp server -> dnscrypt upstream" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=jp.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; configure_dns'
    [ "$status" -eq 0 ]
    [ "$output" = "127.0.0.1#5353" ]
}

@test "configure_dns: overseas router + un server -> stunnel chain (un=cn alias)" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=un.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; configure_dns'
    [ "$status" -eq 0 ]
    [ "$output" = "127.0.0.1#5356" ]
}
```

- [ ] **Step 2: Run tests (expect fail)**

```bash
bats tests/bats/test_vipin_vpn_stunnel.bats
```

Expected: 4 new tests fail.

- [ ] **Step 3: Implement `configure_dns`**

Add after `render_stunnel_conf`:

```sh
configure_dns() {
    # Decide which dnsmasq upstream to use and (in non-MOCK mode) write it.
    # Prints the chosen upstream server string to stdout either way.
    local router_country uci_server base_domain server_country
    if [ "$VIPIN_VPN_MOCK" = "1" ]; then
        router_country="$VIPIN_VPN_ROUTER_COUNTRY"
        uci_server="$VIPIN_VPN_UCI_SERVER"
        base_domain="$VIPIN_VPN_BASE_DOMAIN"
    else
        router_country=$(/usr/sbin/vipin-detect 2>/dev/null | \
            grep -o '"country": *"[^"]*"' | cut -d'"' -f4)
        [ -z "$router_country" ] && router_country="$(uci -q get vipin.vpn.country || echo cn)"
        uci_server=$(uci -q get vipin.vpn.server)
        base_domain=$(uci -q get vipin.vpn.base_domain || echo fanq.in)
    fi

    # un is a cn alias for split-tunnel and DNS purposes.
    server_country=$(echo "$uci_server" | cut -d. -f1)
    [ "$server_country" = "un" ] && server_country="cn"

    local upstream="127.0.0.1#5353"   # dnscrypt-proxy by default
    if [ "$router_country" != "cn" ] && [ "$server_country" = "cn" ]; then
        upstream="127.0.0.1#5356"      # UDP→TCP bridge → stunnel → cn2
    fi

    if [ "$VIPIN_VPN_MOCK" != "1" ]; then
        uci -q delete dhcp.@dnsmasq[0].server
        uci add_list dhcp.@dnsmasq[0].server="$upstream"
        uci set dhcp.@dnsmasq[0].noresolv='1'
        uci commit dhcp
        /etc/init.d/dnsmasq restart >/dev/null 2>&1
    fi
    echo "$upstream"
}

teardown_dns() {
    # Revert to dnscrypt-only upstream when VPN is stopped.
    if [ "$VIPIN_VPN_MOCK" != "1" ]; then
        uci -q delete dhcp.@dnsmasq[0].server
        uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5353'
        uci set dhcp.@dnsmasq[0].noresolv='1'
        uci commit dhcp
        /etc/init.d/dnsmasq restart >/dev/null 2>&1
    fi
}
```

- [ ] **Step 4: Run tests (expect pass)**

```bash
bats tests/bats/test_vipin_vpn_stunnel.bats
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add tests/bats/test_vipin_vpn_stunnel.bats files/etc/init.d/vipin-vpn
git commit -m "feat(vpn): add configure_dns 4-matrix decision helper"
```

---

## Task 3e: `vipin-vpn` — replace start_service / stop_service

With all helpers in place, rewrite the procd orchestration to launch stunnel + tun2socks instead of openconnect.

**Files:**
- Modify: `files/etc/init.d/vipin-vpn`

- [ ] **Step 1: Remove openconnect-specific helpers**

Open `files/etc/init.d/vipin-vpn`. Delete the functions `fetch_cert_pin`, `probe_cert_pin`, `get_cert_pin` (old cert-pin self-heal logic) entirely.

- [ ] **Step 2: Replace `start_service` body**

Replace the whole `start_service()` function with:

```sh
start_service() {
    get_config

    check_auth || return 1

    mkdir -p /var/log /etc/vipin /tmp/vipin

    local auth_info username pass_file
    auth_info=$(/usr/sbin/vipin-auth status 2>/dev/null)
    username=$(echo "$auth_info" | grep -o '"username": *"[^"]*"' | cut -d'"' -f4)
    pass_file="/etc/vipin/.vpn_pass"

    if [ -z "$username" ] || [ ! -f "$pass_file" ]; then
        logger -t "$NAME" "VPN not configured, skipping start"
        return 1
    fi

    local password mac
    password=$(cat "$pass_file")
    mac=$(/usr/sbin/vipin-auth mac 2>/dev/null | \
          grep -o '"mac": *"[^"]*"' | cut -d'"' -f4)

    fetch_auth_params "$username" "$password" "$mac"
    case $? in
        0) ;;  # ok — proceed
        1) logger -t "$NAME" "Auth expired/invalid, not starting VPN"
           uci set vipin.vpn.auth_status="$(grep -o '"status":"[^"]*"' /etc/vipin/auth-params.json | cut -d'"' -f4)"
           uci commit vipin
           return 1 ;;
        2) logger -t "$NAME" "Auth API unreachable on start, deferring"
           return 1 ;;
    esac

    uci set vipin.vpn.auth_status='ok'
    uci commit vipin

    extract_ca_cert || {
        logger -t "$NAME" "Failed to extract CA cert"
        return 1
    }
    render_stunnel_conf || {
        logger -t "$NAME" "Failed to render stunnel config"
        return 1
    }

    local dns_upstream
    dns_upstream=$(configure_dns)
    logger -t "$NAME" "DNS upstream set to $dns_upstream"

    ip link delete tun0 2>/dev/null

    local connect_host
    connect_host=$(resolve_connect_server)
    logger -t "$NAME" "Starting stunnel client → ${connect_host}:$(grep -o '"port":[0-9]*' /etc/vipin/auth-params.json | head -1 | cut -d: -f2)"

    procd_open_instance stunnel
    procd_set_param command /usr/bin/stunnel /etc/vipin/stunnel-client.conf
    procd_set_param respawn 5 30 3
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance

    procd_open_instance tun2socks
    procd_set_param command /usr/bin/badvpn-tun2socks \
        --tundev tun0 \
        --netif-ipaddr 192.168.200.1 \
        --netif-netmask 255.255.255.0 \
        --socks-server-addr 127.0.0.1:1080 \
        --loglevel warning
    procd_set_param respawn 5 30 3
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance

    ( sleep 3
      if ip link show tun0 >/dev/null 2>&1; then
          ip link set tun0 up 2>/dev/null
          ip route add 0.0.0.0/1 dev tun0 2>/dev/null
          ip route add 128.0.0.0/1 dev tun0 2>/dev/null
          local split_mode country
          split_mode=$(uci -q get vipin.vpn.split_mode || echo forward)
          country=$(uci -q get vipin.vpn.country || echo cn)
          if [ "$split_mode" = "reverse" ]; then
              local sc=$(echo "$(uci -q get vipin.vpn.server)" | cut -d. -f1)
              [ "$sc" = "un" ] && sc="cn"
              /usr/sbin/vipin-vpn-routing enable "$sc" reverse
          elif [ "$split_mode" = "forward" ]; then
              /usr/sbin/vipin-vpn-routing enable "$country" forward
          fi
          logger -t "$NAME" "VPN started"
      else
          logger -t "$NAME" "tun0 did not come up in 3s"
      fi
    ) &
}
```

- [ ] **Step 3: Replace `stop_service` body**

Replace `stop_service()` with:

```sh
stop_service() {
    get_config

    /usr/sbin/vipin-vpn-routing disable 2>/dev/null

    killall stunnel 2>/dev/null
    killall badvpn-tun2socks 2>/dev/null
    sleep 1

    ip route del 0.0.0.0/1 dev tun0 2>/dev/null
    ip route del 128.0.0.0/1 dev tun0 2>/dev/null
    ip link delete tun0 2>/dev/null

    teardown_dns

    rm -f /var/run/vipin-stunnel.pid

    logger -t "$NAME" "VPN stopped"
}
```

- [ ] **Step 4: Replace `status()` body**

Replace `status()` with process-based health check (no longer looks for openconnect):

```sh
status() {
    if pgrep stunnel >/dev/null && pgrep badvpn-tun2socks >/dev/null && \
       ip link show tun0 >/dev/null 2>&1; then
        echo "VPN is running"
        local auth_info username
        auth_info=$(/usr/sbin/vipin-auth status 2>/dev/null)
        username=$(echo "$auth_info" | grep -o '"username": *"[^"]*"' | cut -d'"' -f4)
        [ -n "$username" ] && echo "User: $username"
        return 0
    fi
    echo "VPN is not running"
    return 1
}
```

- [ ] **Step 5: Update `boot()` to not require `enabled` flag**

Replace `boot()` with:

```sh
boot() {
    # Start in background 30s after boot; gated by presence of auth files.
    ( sleep 30
      if [ -f /etc/vipin/auth.conf ] && [ -f /etc/vipin/.vpn_pass ]; then
          /etc/init.d/vipin-auth start 2>/dev/null
          start_service
      fi
    ) &
}
```

- [ ] **Step 6: Remove `check_auth` dependency on `enabled` UCI**

Find `check_auth()` and remove any `$enabled` reference (if present). The new gating signal is "auth files exist."

Current (to edit):

```sh
check_auth() {
    [ "$enabled" = "1" ] || return 1
    local status=$(/usr/sbin/vipin-auth status 2>/dev/null)
    echo "$status" | grep -q '"logged_in": *true'
}
```

Replace with:

```sh
check_auth() {
    local status
    status=$(/usr/sbin/vipin-auth status 2>/dev/null)
    echo "$status" | grep -q '"logged_in": *true'
}
```

Also remove `config_get_bool enabled vpn enabled 0` from `get_config` since UCI `enabled` is gone.

- [ ] **Step 7: Syntax-check**

```bash
sh -n files/etc/init.d/vipin-vpn && echo OK
```

Expected: `OK`.

- [ ] **Step 8: Re-run bats tests — all helper tests still pass**

```bash
bats tests/bats/test_vipin_vpn_stunnel.bats
```

Expected: all pass.

- [ ] **Step 9: Commit**

```bash
git add files/etc/init.d/vipin-vpn
git commit -m "refactor(vpn): rewrite start_service for stunnel+tun2socks; drop openconnect helpers"
```

---

## Task 4: Rewrite `vipin-auth-check` main loop

Replace openconnect-process checks with stunnel + tun2socks checks; adopt "network error = no-op, explicit auth fail = stop" semantics; write `auth_status` UCI.

**Files:**
- Modify: `files/usr/sbin/vipin-auth-check`
- Create: `tests/bats/test_vipin_auth_check_stunnel.bats`

- [ ] **Step 1: Write failing tests**

Create `tests/bats/test_vipin_auth_check_stunnel.bats`:

```bash
#!/usr/bin/env bats

load fixtures/common

@test "is_stack_running returns 0 when both stunnel and tun2socks present" {
    export VIPIN_AUTH_CHECK_MOCK=1
    export VIPIN_AUTH_CHECK_STUNNEL_RUNNING=1
    export VIPIN_AUTH_CHECK_TUN2SOCKS_RUNNING=1
    run /bin/sh -c '. files/usr/sbin/vipin-auth-check; is_stack_running'
    [ "$status" -eq 0 ]
}

@test "is_stack_running returns 1 when stunnel missing" {
    export VIPIN_AUTH_CHECK_MOCK=1
    export VIPIN_AUTH_CHECK_STUNNEL_RUNNING=0
    export VIPIN_AUTH_CHECK_TUN2SOCKS_RUNNING=1
    run /bin/sh -c '. files/usr/sbin/vipin-auth-check; is_stack_running'
    [ "$status" -eq 1 ]
}

@test "is_stack_running returns 1 when tun2socks missing" {
    export VIPIN_AUTH_CHECK_MOCK=1
    export VIPIN_AUTH_CHECK_STUNNEL_RUNNING=1
    export VIPIN_AUTH_CHECK_TUN2SOCKS_RUNNING=0
    run /bin/sh -c '. files/usr/sbin/vipin-auth-check; is_stack_running'
    [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: Run tests (expect fail — function missing)**

```bash
bats tests/bats/test_vipin_auth_check_stunnel.bats
```

Expected: 3 tests fail.

- [ ] **Step 3: Replace `is_vpn_running` with stack-aware `is_stack_running`**

Open `files/usr/sbin/vipin-auth-check`. Remove the old `is_vpn_running` function:

```sh
is_vpn_running() {
    pgrep openconnect >/dev/null
}
```

Add near the top (after log() / is_vpn_enabled() definitions):

```sh
# MOCK mode: tests source the script and drive helpers via env.
VIPIN_AUTH_CHECK_MOCK="${VIPIN_AUTH_CHECK_MOCK:-0}"

is_stack_running() {
    if [ "$VIPIN_AUTH_CHECK_MOCK" = "1" ]; then
        [ "$VIPIN_AUTH_CHECK_STUNNEL_RUNNING" = "1" ] && \
        [ "$VIPIN_AUTH_CHECK_TUN2SOCKS_RUNNING" = "1" ]
        return
    fi
    pgrep stunnel >/dev/null && pgrep badvpn-tun2socks >/dev/null
}
```

- [ ] **Step 4: Run tests (expect pass)**

```bash
bats tests/bats/test_vipin_auth_check_stunnel.bats
```

Expected: 3 pass.

- [ ] **Step 5: Rewrite main loop**

Replace the existing `while true; do ... done` main loop with:

```sh
# Main loop
log "=== VIPIN Auth Monitor Started (stunnel+tun2socks) ==="

reconnect_fails=0
last_verify=0
RECONNECT_INTERVAL=30
CHECK_INTERVAL=300

while true; do
    now=$(date +%s)

    if ! has_auth_file; then
        sleep "$RECONNECT_INTERVAL"
        continue
    fi

    # Watchdog: if either component died, restart (keeps chain intact).
    if ! is_stack_running; then
        log "stunnel or tun2socks not running — calling vipin-vpn restart"
        /etc/init.d/vipin-vpn restart 2>/dev/null
    fi

    # Periodic auth revalidation.
    elapsed=$((now - last_verify))
    if [ "$elapsed" -ge "$CHECK_INTERVAL" ]; then
        last_verify=$now
        handle_auth_tick
    fi

    sleep "$RECONNECT_INTERVAL"
done
```

- [ ] **Step 6: Add `handle_auth_tick` helper**

Insert above the `# Main loop` comment:

```sh
handle_auth_tick() {
    local username password mac api_base response status
    username=$(get_saved_username)
    password=$(get_saved_password)
    mac=$(/usr/sbin/vipin-auth mac 2>/dev/null | \
          grep -o '"mac": *"[^"]*"' | cut -d'"' -f4)

    [ -z "$username" ] && return 0

    api_base=$(uci -q get vipin.vpn.site_url || echo "https://www.anyfq.com")
    response=$(wget -q -O- --timeout=10 \
        "${api_base}/api/v1/router-auth" \
        --post-data="username=${username}&credentials=${password}&mac=${mac}&source=stunnel" \
        2>/dev/null)

    if [ -z "$response" ]; then
        log "auth API unreachable — no action"
        return 0
    fi

    status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    case "$status" in
        ok)
            uci set vipin.vpn.auth_status='ok'
            uci commit vipin
            if ! is_stack_running; then
                log "auth=ok and stack stopped — auto-recover"
                /etc/init.d/vipin-vpn start
            fi
            ;;
        expired|invalid|not_vip)
            log "auth=$status — stopping stack, keeping credentials"
            uci set vipin.vpn.auth_status="$status"
            uci commit vipin
            /etc/init.d/vipin-vpn stop
            ;;
        *)
            log "auth returned unknown status=$status — no action"
            ;;
    esac
}
```

- [ ] **Step 7: Delete the old `disable_and_stop` body that wipes `enabled`**

Find and simplify `disable_and_stop` to just call stop (we no longer toggle `enabled`). Replace its body with:

```sh
disable_and_stop() {
    local reason="$1"
    log "Stopping VPN: $reason"
    /etc/init.d/vipin-vpn stop 2>/dev/null
    uci set vipin.vpn.auth_status='expired'
    uci commit vipin
    log "VPN stopped; auth_status=expired. Will auto-recover when auth returns ok."
}
```

- [ ] **Step 8: Syntax-check + run tests**

```bash
sh -n files/usr/sbin/vipin-auth-check && echo OK
bats tests/bats/test_vipin_auth_check_stunnel.bats
```

Expected: `OK`, all bats pass.

- [ ] **Step 9: Commit**

```bash
git add tests/bats/test_vipin_auth_check_stunnel.bats files/usr/sbin/vipin-auth-check
git commit -m "refactor(auth-check): stunnel+tun2socks watchdog; network-error = no-op"
```

---

## Task 5: LuCI controller changes

**Files:**
- Modify: `files/usr/lib/lua/luci/controller/vpn.lua`

- [ ] **Step 1: Locate `api_login` and `api_status`**

```bash
grep -n 'function .*api_login\|function .*api_status\|function .*server_change' \
    files/usr/lib/lua/luci/controller/vpn.lua
```

Note the line ranges — we'll edit these functions in-place.

- [ ] **Step 2: Update `api_login` to start the stack after successful auth**

In the existing `api_login` implementation, after the `/api/v1/router-auth` call returns ok (detection already present), add:

```lua
-- After successful auth, kick the VPN init.d. It will re-hit
-- router-auth with source=stunnel, render config, and launch stack.
util.exec("/etc/init.d/vipin-vpn start >/dev/null 2>&1")

-- Poll up to 12s for the stack to report running.
local connected = false
for _ = 1, 24 do
    local st = util.exec("/etc/init.d/vipin-vpn status 2>/dev/null")
    if st:find("VPN is running") then
        connected = true
        break
    end
    nixio.nanosleep(0, 500000000)  -- 500ms
end

http.write_json({
    status = "ok",
    vpn_connected = connected,
    auth_status = luci.model.uci:get("vipin", "vpn", "auth_status") or "ok",
})
return
```

On auth failure, set auth_status and emit the reason:

```lua
-- Auth failed — persist status, do NOT start VPN.
local reason = "invalid"
if resp_body:find('"status":"expired"') then reason = "expired"
elseif resp_body:find('"status":"not_vip"') then reason = "not_vip" end
luci.model.uci:set("vipin", "vpn", "auth_status", reason)
luci.model.uci:commit("vipin")
http.write_json({
    status = reason,
    message = extract_message(resp_body),
    vpn_connected = false,
    auth_status = reason,
})
return
```

(`extract_message` is a small helper that greps `"message":"..."` out of JSON — write it inline if not already present.)

- [ ] **Step 3: Add `api_server_change` endpoint**

Add a new dispatcher entry at the top of `index()` function:

```lua
entry({"admin", "services", "vipin_vpn", "server_change"},
      call("api_server_change")).leaf = true
```

And implement it:

```lua
function api_server_change()
    local http = require("luci.http")
    local util = require("luci.util")
    http.prepare_content("application/json")

    local new_server = http.formvalue("server")
    if not new_server or new_server == "" then
        http.write_json({status = "invalid_server"})
        return
    end

    luci.model.uci:set("vipin", "vpn", "server", new_server)
    luci.model.uci:commit("vipin")

    -- If the stack is currently running, restart it with the new server.
    local st = util.exec("/etc/init.d/vipin-vpn status 2>/dev/null")
    if st:find("VPN is running") then
        util.exec("/etc/init.d/vipin-vpn restart >/dev/null 2>&1")
    end

    http.write_json({status = "ok", server = new_server})
end
```

- [ ] **Step 4: Extend `api_status` to return `auth_status` and `vpn_connected`**

Inside `api_status`, where the JSON response is assembled, add / overwrite the following keys:

```lua
local st = util.exec("/etc/init.d/vipin-vpn status 2>/dev/null")
response.vpn_connected = st:find("VPN is running") ~= nil
response.auth_status = luci.model.uci:get("vipin", "vpn", "auth_status") or "ok"
```

Remove any existing `response.vpn_enabled` or similar key that reads `vipin.vpn.enabled` — that UCI key is gone.

- [ ] **Step 5: Syntax-check (lua)**

```bash
luac -p files/usr/lib/lua/luci/controller/vpn.lua && echo OK
```

Expected: `OK`. (Install luac via `apt install lua5.1` if missing.)

- [ ] **Step 6: Commit**

```bash
git add files/usr/lib/lua/luci/controller/vpn.lua
git commit -m "feat(luci): api_login starts stack; api_server_change; api_status returns auth_status"
```

---

## Task 6: LuCI view — remove toggle+logout, add banner, server onchange

**Files:**
- Modify: `files/usr/lib/lua/luci/view/vpn/settings.htm`

- [ ] **Step 1: Remove VPN on/off toggle**

```bash
grep -n 'enabled\|vpn-toggle\|vpnToggle' files/usr/lib/lua/luci/view/vpn/settings.htm | head
```

Delete the toggle block (the `<fieldset>` or row that contains the VPN enable switch). It reads `vipin.vpn.enabled` and calls `/cgi-bin/luci/admin/services/vipin_vpn/toggle` — remove the whole row.

- [ ] **Step 2: Remove logout button**

Find the logout `<button>` / `<input type="button">` element (probably associated with `api_logout` or `vipnLogout` JS function) and delete the element + JS handler.

- [ ] **Step 3: Add auth_status banner**

Near the top of the VPN form, insert:

```html
<div id="vpn-auth-banner"
     style="display:none;padding:8px 12px;margin-bottom:12px;border-radius:4px;"></div>
```

And in the `videoRenderStatus` (or equivalent render function) that runs on status refresh, add:

```javascript
var banner = document.getElementById('vpn-auth-banner');
if (s.auth_status && s.auth_status !== 'ok') {
    var msg = {
        expired:   t.auth_banner_expired,
        invalid:   t.auth_banner_invalid,
        not_vip:   t.auth_banner_not_vip
    }[s.auth_status] || (t.auth_banner_fail + ': ' + s.auth_status);
    banner.style.display = 'block';
    banner.style.background = '#ffeecc';
    banner.style.color = '#8a5a00';
    banner.textContent = msg;
} else {
    banner.style.display = 'none';
}
```

- [ ] **Step 4: Change server dropdown to trigger `api_server_change` on change**

Find the `<select id="vpn-server">` element. Replace any existing save-on-submit handler with an immediate onchange:

```html
<select id="vpn-server" onchange="serverChange(this.value)">
    ...
</select>
```

Add the `serverChange` JS function:

```javascript
function serverChange(newServer) {
    if (!newServer) return;
    fetch('<%=url("admin/services/vipin_vpn/server_change")%>', {
        method: 'POST',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'server=' + encodeURIComponent(newServer),
    }).then(r => r.json()).then(d => {
        if (d.status === 'ok') {
            // Reload status so the UI reflects the new session.
            refreshStatus();
        } else {
            alert(t.server_change_fail);
        }
    });
}
```

- [ ] **Step 5: Syntax-check (HTML/JS — grep for unclosed tags)**

```bash
grep -c '<fieldset' files/usr/lib/lua/luci/view/vpn/settings.htm
grep -c '</fieldset>' files/usr/lib/lua/luci/view/vpn/settings.htm
```

Both counts must match.

- [ ] **Step 6: Commit**

```bash
git add files/usr/lib/lua/luci/view/vpn/settings.htm
git commit -m "feat(luci): remove VPN toggle+logout; add auth_status banner; server onchange"
```

---

## Task 7: i18n strings for the auth banner

**Files:**
- Modify: `files/usr/lib/lua/luci/view/vpn/i18n/*.lua` (17 locales)

- [ ] **Step 1: Add English keys to `en.lua`**

Open `files/usr/lib/lua/luci/view/vpn/i18n/en.lua` and add (inside the returned table, near other string keys):

```lua
auth_banner_expired = "Account expired — will auto-recover after renewal",
auth_banner_invalid = "Verification failed — check credentials",
auth_banner_not_vip = "Not a VIP account",
auth_banner_fail    = "Verification error",
server_change_fail  = "Failed to change server, please try again",
```

- [ ] **Step 2: Add Chinese keys to `zh-CN.lua`**

```lua
auth_banner_expired = "账户已过期，续费后自动恢复",
auth_banner_invalid = "验证失败，请检查凭据",
auth_banner_not_vip = "非 VIP 账户",
auth_banner_fail    = "验证错误",
server_change_fail  = "更换服务器失败，请重试",
```

- [ ] **Step 3: Add same English text to the remaining 15 locales**

The existing 13 locales (ar, de, es, fa, fr, hi, id, ko, pt, ru, th, tr, vi) already use English placeholders elsewhere. Use the same pattern:

```bash
for f in files/usr/lib/lua/luci/view/vpn/i18n/*.lua; do
    case "$f" in
        */en.lua|*/zh-CN.lua|*/zh-TW.lua|*/ja.lua) continue ;;
    esac
    python3 <<PY
import re
with open("$f") as fh: c = fh.read()
insert = '''    auth_banner_expired = "Account expired — will auto-recover after renewal",
    auth_banner_invalid = "Verification failed — check credentials",
    auth_banner_not_vip = "Not a VIP account",
    auth_banner_fail    = "Verification error",
    server_change_fail  = "Failed to change server, please try again",
'''
if 'auth_banner_expired' not in c:
    c = c.replace('return {\n', 'return {\n' + insert, 1)
    with open("$f",'w') as fh: fh.write(c)
PY
done
```

- [ ] **Step 4: Add zh-TW and ja translations**

`zh-TW.lua`:

```lua
auth_banner_expired = "帳戶已過期，續費後自動恢復",
auth_banner_invalid = "驗證失敗，請檢查憑據",
auth_banner_not_vip = "非 VIP 帳戶",
auth_banner_fail    = "驗證錯誤",
server_change_fail  = "更換伺服器失敗，請重試",
```

`ja.lua`:

```lua
auth_banner_expired = "アカウントが期限切れです。更新後に自動回復します",
auth_banner_invalid = "認証失敗。認証情報を確認してください",
auth_banner_not_vip = "VIPアカウントではありません",
auth_banner_fail    = "認証エラー",
server_change_fail  = "サーバー変更失敗。再試行してください",
```

- [ ] **Step 5: Sanity check**

```bash
grep -l 'auth_banner_expired' files/usr/lib/lua/luci/view/vpn/i18n/*.lua | wc -l
```

Expected: `17`.

- [ ] **Step 6: Commit**

```bash
git add files/usr/lib/lua/luci/view/vpn/i18n/
git commit -m "i18n: add auth_status banner strings across 17 locales"
```

---

## Task 8: Build configs — replace openconnect with stunnel+tun2socks

**Files:**
- Modify: `configs/*.config` (1071 files)

- [ ] **Step 1: Verify OpenWrt 25.12.1 package names**

```bash
# Check against the same build repo we use in .github/workflows/build.yml
grep -h 'github.com/openwrt' .github/workflows/build.yml
```

Expected: the build clones OpenWrt v25.12.1. Verify by running a spot build with the new packages (done in Task 10 QA), but for sanity check the package names:

```bash
# These names are standard OpenWrt; spot-check one config file
grep -E 'CONFIG_PACKAGE_(openconnect|stunnel-openssl|tun2socks)=' configs/GLINET-GL-MT300N-V2.config
```

- [ ] **Step 2: Apply the package swap to all 1071 configs**

Use sed; the `openconnect` line is consistently on one line. We replace that single line with two:

```bash
for f in configs/*.config; do
    sed -i '/^CONFIG_PACKAGE_openconnect=y$/c\
CONFIG_PACKAGE_stunnel-openssl=y\
CONFIG_PACKAGE_tun2socks=y' "$f"
done
```

- [ ] **Step 3: Verify every config changed**

```bash
grep -l 'CONFIG_PACKAGE_openconnect=y' configs/*.config | wc -l
```

Expected: `0`.

```bash
grep -l 'CONFIG_PACKAGE_stunnel-openssl=y' configs/*.config | wc -l
```

Expected: `1071`.

```bash
grep -l 'CONFIG_PACKAGE_tun2socks=y' configs/*.config | wc -l
```

Expected: `1071`.

- [ ] **Step 4: Commit**

```bash
git add configs/
git commit -m "build: replace openconnect with stunnel-openssl + tun2socks in 1071 configs"
```

---

## Task 9: Delete vipin-vpnc-script and update etc/config/vipin

**Files:**
- Delete: `files/usr/sbin/vipin-vpnc-script`
- Modify: `files/etc/config/vipin`

- [ ] **Step 1: Remove the script**

```bash
git rm files/usr/sbin/vipin-vpnc-script
```

- [ ] **Step 2: Update `files/etc/config/vipin` defaults**

```bash
cat files/etc/config/vipin
```

Inspect existing. Remove the `option enabled` line; ensure `option split_mode 'forward'` exists; add `option auth_status 'ok'`.

Result should look like:

```
config vpn 'vpn'
    option server ''
    option username ''
    option split_tunnel '1'
    option split_mode 'forward'
    option country 'cn'
    option video_direct '1'
    option auth_status 'ok'
    option site_url 'https://www.anyfq.com'
    option base_domain 'fanq.in'
```

- [ ] **Step 3: Commit**

```bash
git add files/etc/config/vipin files/usr/sbin/vipin-vpnc-script
git commit -m "chore: remove vipin-vpnc-script (openconnect only); update vipin UCI defaults"
```

---

## Task 10: QA on live router

Rebuild firmware, flash one test router, walk through the test matrix from the spec. Purely manual; no code changes. If any test fails, return to the relevant task, fix, re-run.

**Files:** none

- [ ] **Step 1: Trigger a fresh firmware build**

Push branch to GitHub. The `repository_dispatch` / `workflow_dispatch` path builds the new firmware. Wait for the artifact.

- [ ] **Step 2: Flash the test router (192.168.2.91) with the new firmware**

Use the usual OpenWrt sysupgrade path.

- [ ] **Step 3: Smoke — valid login**

Open the LuCI VPN page; log in with known good credentials. Expected:
- Within ~15 s, `ip link show tun0` shows `UP`.
- `pgrep stunnel` and `pgrep badvpn-tun2socks` both succeed.
- LAN client can load `baidu.com` and `google.com`.

- [ ] **Step 4: Smoke — invalid login**

Log out (clear `/etc/vipin/auth.conf` manually), log in with wrong password. Expected: inline banner "验证失败"; `tun0` not created; LAN still has internet via WAN direct.

- [ ] **Step 5: Lifecycle — account expired**

Mark account expired server-side. Wait ≤ 5 min. Expected: `uci get vipin.vpn.auth_status` returns `expired`; stack stopped; banner visible. Flip account back to valid, wait ≤ 5 min. Expected: stack auto-restarts.

- [ ] **Step 6: Server change**

Change server via LuCI dropdown. Expected: stack restarts in < 10 s.

- [ ] **Step 7: Resiliency — kill components**

```bash
ssh root@192.168.2.91 'killall stunnel'
```

Within 30 s, auth-check restarts it. `/proc/net/dev | grep tun0` shows RX incrementing.

```bash
ssh root@192.168.2.91 'killall badvpn-tun2socks'
```

Same recovery.

- [ ] **Step 8: DNS 4-matrix**

- Router overseas + CN server: `nslookup www.baidu.com 192.168.11.1` returns mainland IP (e.g. `183.2.172.177`).
- Router overseas + JP server: `nslookup www.baidu.com 192.168.11.1` returns an overseas CDN IP.
- Any CN router + any server: `nslookup www.baidu.com 192.168.11.1` uses dnscrypt (check upstream in dnsmasq log).

- [ ] **Step 9: Split modes**

For `forward` / `reverse` / split-off each:
- `curl -s https://ifconfig.me` from a LAN client to verify exit IP.
- Forward in CN + CN server → exit = CN.
- Reverse + CN server overseas → baidu exit = CN, google exit = CA.
- Split-off → everything through tunnel.

- [ ] **Step 10: Document any deviation**

If any test fails, open a follow-up task in this plan describing the fix, commit it, repeat step 1 onward for the affected area.

- [ ] **Step 11: Merge branch**

Once all smoke + lifecycle + resiliency + DNS + split tests pass:

```bash
gh pr create --title "feat: stunnel + tun2socks VPN architecture" \
    --body "Implements spec at docs/superpowers/specs/2026-04-17-stunnel-tun2socks-architecture-design.md"
```

Review the PR. Merge to main.

---

## Self-Review

**Spec coverage (§ of spec → task):**

- Problem / Goal / Architecture → Tasks 3a-3e (init.d rewrite) + 4 (auth-check) ✓
- Server-delivered configuration (request/response) → Task 3b (fetch_auth_params) ✓
- Session semantics (5-min revalidation, network-error=no-op) → Task 4 (handle_auth_tick) ✓
- Router components (new/deleted/retained, runtime files) → Task 3e (files created), Task 9 (delete vpnc-script) ✓
- Service topology (start/stop pseudocode) → Task 3e ✓
- Rendered stunnel config → Task 3c ✓
- DNS decision matrix → Task 3d ✓
- nft chain delta → Task 2 ✓
- vipin-auth-check revised loop → Task 4 ✓
- UCI schema changes → Task 1 (migration) + Task 9 (defaults) ✓
- LuCI UI changes → Task 5 (controller) + Task 6 (view) + Task 7 (i18n) ✓
- Trigger matrix → Tasks 3e + 4 + 5 cover user + background paths ✓
- Migration plan → Tasks 1, 2, 8, 9 ✓
- Test plan → Task 10 manual QA + bats unit tests across 3a-3d + 4 ✓

**Placeholder scan:** none detected; every code block is concrete.

**Type / name consistency:**

- `tun0` used in Tasks 2, 3e, 6 consistently (not `tun_vipin` / `vipin0` / any variant).
- `/etc/vipin/auth-params.json`, `/etc/vipin/stunnel-ca.pem`, `/etc/vipin/stunnel-client.conf` — single paths, no alternates.
- `VIPIN_VPN_MOCK` and `VIPIN_AUTH_CHECK_MOCK` env var naming consistent.
- UCI field `vipin.vpn.auth_status` used consistently; never seen `status`, `auth`, or `vpn_status`.
- `resolve_connect_server` returns a hostname (not a URL); every caller uses it as hostname only.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-17-stunnel-tun2socks-implementation.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task, two-stage review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batched with review checkpoints.

**Which approach?**
