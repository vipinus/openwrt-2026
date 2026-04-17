# stunnel + tun2socks VPN Architecture — Design Spec

**Date:** 2026-04-17
**Author:** ddxs (with Claude)
**Status:** Draft — pending review
**Supersedes:** Current openconnect-based architecture (vipin-vpn / vipin-vpnc-script)

## Problem

The existing router VPN stack is based on `openconnect` talking DTLS to
`ocserv` on `un.fanq.in`. It has two persistent bugs we have been unable
to close from the router side:

1. **DTLS data plane stalls silently.** Under NAT binding expiry or any
   transient DTLS hiccup, the control channel still reports
   `connected` while the data plane blackholes in one direction. User
   symptom: "phone has no internet" that clears only after a manual
   reconnect.
2. **DNS flow tied to a fragile VPN-pushed DNS (`172.16.0.1`).** Works
   when the tunnel is healthy; breaks the moment DTLS is half-open.

Separately, the data plane has UDP/DTLS handling complexity (MTU
discovery, DPD, reconnect logic) that we do not actually need — user
traffic is overwhelmingly TCP, and the site already has a stable
stunnel + SOCKS5 + HAproxy infrastructure on the servers.

## Goal

Replace the router-side VPN data plane with a simpler, TCP-only stack
using existing server-side components, while preserving every current
user-visible feature:

- VPN on/off via LuCI (implicit — controlled by credential presence)
- Server selection
- Forward / reverse / split-off modes
- Video acceleration (`video_direct`)
- 5-minute session revalidation with auto-recovery
- "Plain router" fallback when auth expires

## Non-Goals

- UDP-over-VPN. QUIC/WebRTC/etc. will fall back to TCP or go direct
  over WAN.
- Supporting multiple concurrent VPN sessions per router.
- Backup servers / automatic failover.

## High-Level Architecture

### Data path

```
LAN client
  → router br-lan
  → vipin_prerouting (nft mark 0 = go VPN / 0x200 = go WAN)
  → mark 0 → main routing table → 0.0.0.0/1 dev tun0
  → tun0 (badvpn-tun2socks)
  → SOCKS5 to 127.0.0.1:1080 (stunnel client listener)
  → TLS → uci.vpn.server : <port_from_auth>   (e.g. un.fanq.in:22)
  → server stunnel TLS-terminates → haproxy 127.0.0.1:8123
  → haproxy → local stunnel client → cn2.fanq.in:995 (TLS)
  → cn2 stunnel TLS-terminates → dante SOCKS5 127.0.0.1:1080
  → dante → public internet
```

### Changed vs current stack

| Concern               | Old (openconnect)                      | New (stunnel + tun2socks)                      |
|-----------------------|----------------------------------------|------------------------------------------------|
| Data protocol         | Anyconnect / DTLS (UDP 443)            | TLS-wrapped TCP (port from server env.local)   |
| Router binary         | openconnect                            | stunnel-openssl + badvpn-tun2socks             |
| TUN device            | vpn_vipin (openconnect-created)        | tun0 (badvpn-tun2socks-created)                |
| Session liveness      | DPD over DTLS (brittle)                | TCP keepalive (standard)                       |
| vpnc-script           | `/usr/sbin/vipin-vpnc-script`          | **deleted** (no longer needed)                 |
| Chain `oifname`       | `vpn_vipin`                            | `tun0`                                         |
| Auth failure behavior | Keep running until retry fails 5×      | Immediately stop stack → plain-router fallback |

### Unchanged

- `vipin-vpn-routing` (nft chains, `@vipin_domestic` / `@vipin_video` sets)
- `vipin-video-domains` (dnsmasq `nftset=` includes + remote list refresh)
- `vipin-country-ips`
- LuCI page layout (controller / view), minus the deleted buttons
- DNS sidecar chain (stunnel `:5355` → cn2 `:994` → dedicated forwarder
  → 223.5.5.5). Reused whenever router is overseas + connected to a CN
  server; otherwise local dnscrypt-proxy.

## Server-Delivered Configuration

Authoritative source: **`env.local` on the auth backend**. Ports and
cert material change there, not in code.

### Request

`POST /api/v1/router-auth`

```
username=<u>&credentials=<pw_or_hash>&mac=<AA:BB:...>&source=stunnel
```

`source=stunnel` distinguishes from the legacy openconnect flow so the
backend can evolve the response shape without breaking old firmwares.

### Response (status=ok)

```json
{
  "status": "ok",
  "session_expires": 1776430000,

  "tunnel": {
    "port": 22,
    "ca_cert": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n"
  },

  "dns": {
    "stunnel_host": "cn2.fanq.in",
    "stunnel_port": 994
  },

  "split": {
    "default_mode": "forward"
  }
}
```

All fields originate from server `env.local`; the backend handler is a
templated passthrough.

### Response (status=expired | invalid | not_vip)

```json
{ "status": "expired", "message": "human-readable reason" }
```

### Session semantics

- `session_expires` is informational for the LuCI UI — router does not
  self-expire based on it. Revalidation is driven by `vipin-auth-check`
  on a 5-minute timer.
- Verification **timeout / network error → no action.** The stack stays
  in whatever state it is in.
- `status=expired | invalid` → immediately stop the stack, persist
  `vipin.vpn.auth_status`, wait for a future `ok` to auto-recover.

## Router Components

### New packages

- `stunnel-openssl` (OpenWrt OPKG, ~150 KB)
- `tun2socks` (the `badvpn-tun2socks` build; OpenWrt OPKG, ~80 KB)

### Deleted

- `openconnect` package (removed from firmware to save flash)
- `files/usr/sbin/vipin-vpnc-script` (no longer needed)

### Retained

- `vipin-auth` (API client)
- `vipin-auth-check` (reconnect + revalidation daemon)
- `vipin-vpn-routing` (nft chains)
- `vipin-video-domains`
- `vipin-country-ips`
- `vipin-detect`

### New runtime files

- `/etc/vipin/stunnel-client.conf` — rendered at each `start_service`
  from the auth response
- `/etc/vipin/stunnel-ca.pem` — the CA cert from the auth response
- `/etc/vipin/auth-params.json` — cached copy of the latest
  `/api/v1/router-auth` response for post-mortem / debug

## Router Service Topology

### `/etc/init.d/vipin-vpn` — orchestrator (rewritten)

```
start_service():
    get_config                          # UCI
    has_auth_file || return 1

    fetch_auth_params                   # POST /api/v1/router-auth
    case $? in
      0)   ;;                           # status=ok, /etc/vipin/auth-params.json written
      1)   stop_service; exit 0 ;;      # status=expired/invalid
      2)   logger "network error on boot"; exit 0 ;;
    esac

    render_stunnel_conf \
        > /etc/vipin/stunnel-client.conf
    extract_ca_cert > /etc/vipin/stunnel-ca.pem

    configure_dns                       # 4-matrix decision

    procd_open_instance stunnel
    procd_set_param command /usr/bin/stunnel /etc/vipin/stunnel-client.conf
    procd_set_param respawn
    procd_close_instance

    procd_open_instance tun2socks
    procd_set_param command /usr/bin/badvpn-tun2socks \
        --tundev tun0 \
        --netif-ipaddr 192.168.200.1 --netif-netmask 255.255.255.0 \
        --socks-server-addr 127.0.0.1:1080
    procd_set_param respawn
    procd_close_instance

    ( sleep 3
      ip link set tun0 up 2>/dev/null
      ip route add 0.0.0.0/1 dev tun0
      ip route add 128.0.0.0/1 dev tun0
      /usr/sbin/vipin-vpn-routing enable "$country" "$split_mode"
    ) &

stop_service():
    procd_kill stunnel tun2socks
    ip route del 0.0.0.0/1 dev tun0 2>/dev/null
    ip route del 128.0.0.0/1 dev tun0 2>/dev/null
    ip link del tun0 2>/dev/null
    /usr/sbin/vipin-vpn-routing disable
    teardown_dns                        # revert dnsmasq upstream to dnscrypt
```

### Rendered stunnel client config

```
cert = /etc/stunnel/stunnel.pem    ; reuse existing firmware cert for mTLS if server enforces
pid = /var/run/vipin-stunnel.pid

[vipn]
client = yes
accept = 127.0.0.1:1080
connect = <uci get vipin.vpn.server>:<tunnel.port>
CAfile = /etc/vipin/stunnel-ca.pem
verifyChain = yes
checkHost = <uci get vipin.vpn.server>
```

### DNS decision matrix (at start_service)

| router country | server country     | dnsmasq upstream               |
|----------------|--------------------|--------------------------------|
| cn             | cn (cn/un alias)   | `127.0.0.1#5353` (dnscrypt)    |
| cn             | overseas (jp/us)   | `127.0.0.1#5353` (dnscrypt)    |
| overseas       | cn (cn/un alias)   | `127.0.0.1#5356` (stunnel chain) |
| overseas       | overseas (jp/us)   | `127.0.0.1#5353` (dnscrypt)    |

For the overseas-to-CN case, the stunnel DNS chain uses the
server-delivered `dns.stunnel_host` / `dns.stunnel_port`.

### nft chain delta

`files/usr/sbin/vipin-vpn-routing` changes every `vpn_vipin` literal to
`tun0`. No chain-structure changes.

```
chain vipin_postrouting {
    type nat hook postrouting priority srcnat;
    oifname "tun0" masquerade    ; was "vpn_vipin"
}
```

### `vipin-auth-check` revised main loop

```
every RECONNECT_INTERVAL (30 s):
    if stunnel not running or tun2socks not running:
        log "component died, restarting"
        /etc/init.d/vipin-vpn restart       ; keeps chain intact
        continue

every CHECK_INTERVAL (300 s):
    resp = POST /api/v1/router-auth
    if resp.status == ok:
        uci set vipin.vpn.auth_status=ok
        if not (stunnel_running and tun2socks_running):
            /etc/init.d/vipin-vpn start      ; auto-recover
    elif resp.status in (expired, invalid, not_vip):
        uci set vipin.vpn.auth_status=<status>
        /etc/init.d/vipin-vpn stop           ; keep auth files
    else:
        ; network error / timeout → no action
```

Key inversion vs old daemon: **network error never stops the stack**;
**explicit auth failure always does.**

## UCI Schema Changes

### Removed

- `vipin.vpn.enabled` — no longer used; presence of `/etc/vipin/auth.conf`
  is the single source of truth for "should the stack be up."
- `vipin.vpn.cert_pin` — openconnect artefact.

### Added

- `vipin.vpn.auth_status` — one of `ok | expired | invalid | not_vip |
  network_error`. Written by `vipin-auth-check`; read by LuCI for
  status display.
- `vipin.vpn.tunnel_port` — cached from latest auth response for
  informational display / debug.

### Unchanged

- `vipin.vpn.server`, `vipin.vpn.username`, `vipin.vpn.country`,
  `vipin.vpn.split_mode`, `vipin.vpn.split_tunnel`,
  `vipin.vpn.video_direct`, `vipin.vpn.video_last_refresh`,
  `vipin.vpn.site_url`, `vipin.vpn.base_domain`.

Default split mode on first install: `forward`.

## LuCI UI Changes

`files/usr/lib/lua/luci/controller/vpn.lua`:

- `api_login` (existing `POST` login endpoint) — on success additionally
  triggers `/etc/init.d/vipin-vpn start` and waits for connect
  confirmation; returns `{status, vpn_connected, auth_status}` so the
  UI can show success or the verification error inline.
- `api_server_change` — accepts new server hostname, writes UCI, and if
  stack is currently running calls `/etc/init.d/vipin-vpn restart`.
- `api_status` — extends existing status response with
  `auth_status` and `vpn_connected` (detected by presence of
  running stunnel + tun2socks processes + tun0 UP, not by
  `vipin.vpn.enabled`).

`files/usr/lib/lua/luci/view/vpn/settings.htm`:

- **Remove** the VPN on/off toggle.
- **Remove** the logout button.
- **Add** an inline banner for non-ok `auth_status` values
  ("账户已过期，续费后自动恢复" / "验证失败: <reason>").
- Server selector `onchange` now triggers `api_server_change` instead
  of waiting for an explicit save.
- Split mode / video acceleration interactions unchanged.

i18n files updated for the new banner strings.

## Trigger Matrix (complete)

### User actions

| Action                       | Router behavior                                      |
|------------------------------|------------------------------------------------------|
| Login (save account)         | POST router-auth → ok: `start`; fail: show reason    |
| Change server                | save UCI; if running → `restart`                     |
| Change split mode            | `vipin-vpn-routing enable $country $new_mode`        |
| Toggle video acceleration    | `vipin-video-domains enable/disable`                 |

### Background

| Condition                                     | Action                                   |
|-----------------------------------------------|------------------------------------------|
| boot with `has_auth_file`                     | `start` (auth gated internally)          |
| auth-check 5 min: `status=ok` + stack stopped | `start` (auto-recover)                   |
| auth-check 5 min: `expired` / `invalid`       | `stop`, write `auth_status`              |
| auth-check 5 min: network error               | **no action**                            |
| auth-check 30 s: stunnel or tun2socks died    | `/etc/init.d/vipin-vpn restart`          |

## Migration Plan

1. Build matrix: replace `openconnect` with `stunnel-openssl` +
   `tun2socks` in every per-router `.config` file. Confirm both
   packages exist in the OpenWrt 25.12.1 package feeds we use.
2. Add `/etc/uci-defaults/60-stunnel-migration`:
   - Delete obsolete UCI: `vipin.vpn.enabled`, `vipin.vpn.cert_pin`.
   - Initialize `vipin.vpn.auth_status=ok` (so first boot does not
     display a bogus error banner before first auth).
3. Remove `files/usr/sbin/vipin-vpnc-script` from the firmware tree.
4. Rewrite `files/etc/init.d/vipin-vpn` per the pseudocode above.
5. `vipin-auth-check` revision (main loop + component watchdog).
6. `vipin-vpn-routing` textual replace `vpn_vipin` → `tun0`.
7. `controller/vpn.lua` and `settings.htm` UI changes.
8. Backend `/api/v1/router-auth` handler updated to read `env.local`
   and emit the new response schema when `source=stunnel`; legacy
   `source=router-plain` responses remain compatible for old
   firmwares during rollout.
9. Server-side: no changes to stunnel `[CN]` section (already
   `:22 → 127.0.0.1:8123 haproxy`). Document the haproxy → cn2 chain
   in `docs/architecture/` so on-call can reason about it.

## Test Plan

Smoke (must pass on every build):

- Login with valid credentials on a freshly flashed router →
  tunnel up within 15 s; LAN client resolves CN and overseas domains
  correctly; `baidu.com` is reachable and sees a CN exit IP (when the
  overseas-router + CN-server precondition holds).
- Login with invalid credentials → tunnel never starts, LuCI shows
  "验证失败" with the backend-provided message.

Lifecycle:

- Account marked expired server-side while stack is running → within
  5 minutes router stops and `auth_status=expired` appears in UI; no
  traffic leaks into the defunct tun0.
- Account flipped back to valid → within 5 minutes router auto-starts
  without user intervention.
- Server change while running → restart completes in under 10 s,
  connectivity restored.

Resiliency:

- Kill `stunnel` manually → watchdog restarts it within 30 s, nft
  chain remains intact throughout.
- Kill `tun2socks` manually → same.
- Router WAN loses connectivity for 60 s, then recovers → stack
  resumes; no duplicate tunnels.

Split and DNS:

- forward / reverse / split-off — verify one CN target (baidu) and
  one overseas target (google) route correctly in each mode.
- overseas-router + CN-server: DNS uses stunnel chain, `baidu.com`
  resolves to mainland IP, baidu sees CN exit.
- overseas-router + JP-server: DNS uses dnscrypt, overseas sites
  behave normally.

## Open Questions

None after Section 5 sign-off. Any late discoveries are called out in
the implementation plan that follows this spec.

## Out of Scope (explicit)

- Client-side UDP-over-SOCKS5 UDP ASSOCIATE — deferred unless a future
  feature requires it.
- openconnect rollback path — we are going forward; if the new stack
  has a ship-blocker we build another firmware.
- Multi-user VPN on one router — every router has one active account.
- Backup / failover servers — user's current need is single-server;
  revisit when telemetry shows servers failing often enough to matter.
