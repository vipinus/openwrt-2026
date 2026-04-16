# Video Direct v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the `video_direct` feature on top of current `main` — route video CDN IPs out via WAN using dnsmasq-full `nftset=` populating a parallel nftables set `vipin_video`, fed by a two-source domain list (curated GitHub `domains.txt` + user-maintained `local` file).

**Architecture:** Domain lists → dnsmasq-full nftset directives → nft `vipin_video` set (filled at DNS resolve time) → mark rule in `vipin-vpn-routing` prerouting chain (`ip daddr @vipin_video mark set 0x200`) → existing WAN table 101 via fwmark. Boot/cron/LuCI converge on one `enable` function.

**Tech Stack:** POSIX shell (OpenWrt ash), Lua (LuCI), nftables (fw4), dnsmasq-full, procd, bats (shell tests), shellcheck (static analysis).

**Spec reference:** `docs/superpowers/specs/2026-04-16-video-direct-redo-design.md`

**Branch:** `feat/video-direct-v2` off `main`.

---

## Prerequisites

1. **Working directory:** `/home/ddxs/Sync/Works/openwrt-2026` on branch `feat/video-direct-v2`. Verify with `git branch --show-current`.
2. **Tools on host:** `bats`, `shellcheck`, `curl`, `nft` (for syntax verification — not runtime). Install if missing: `sudo apt-get install bats shellcheck`.
3. **No device needed** for this plan. Real-device smoke test is a release-time activity (see §12 of spec).

---

## File Structure

**New files:**

```
files/usr/sbin/vipin-video-domains              # main runtime script (~180 lines)
files/etc/init.d/vipin-video                    # procd init, START=91
files/etc/crontabs/root                         # weekly cron (new file if absent, else edit)
files/etc/vipin/video-domains.local             # empty placeholder
tests/bats/test_vipin_video_domains.bats        # bats test file
tests/bats/fixtures/domains-remote-sample.txt   # test fixture
tests/bats/fixtures/domains-local-sample.txt    # test fixture
.github/workflows/test.yml                      # CI (bats + shellcheck)
docs/release-checklists/video-direct-v2.md      # release checklist
aux-repo-seed/README.md                         # seed for openwrt-2026-video-domains repo
aux-repo-seed/domains.txt                       # initial 48-domain list
```

**Files edited in place:**

```
files/etc/config/vipin                          # +2 UCI options
files/usr/sbin/vipin-vpn-routing                # +vipin_video set declaration + mark rule
files/usr/lib/lua/luci/controller/vpn.lua       # +5 entry() + 5 api_video_* functions
files/usr/lib/lua/luci/view/vpn/settings.htm    # +panel + JS
files/usr/lib/lua/luci/view/vpn/i18n/*.lua × 17 # +15 i18n keys per locale
configs/*.config × 1071                         # dnsmasq → dnsmasq-full (mechanical)
```

---

# Phase 1: Core script with bats TDD

Build the main shell script `vipin-video-domains` function-by-function using bats TDD.

### Task 1.1: Create bats test skeleton and helpers

**Files:**
- Create: `tests/bats/test_vipin_video_domains.bats`
- Create: `tests/bats/fixtures/domains-remote-sample.txt`
- Create: `tests/bats/fixtures/domains-local-sample.txt`

- [ ] **Step 1: Create fixture files**

`tests/bats/fixtures/domains-remote-sample.txt`:
```
# openwrt-2026 video_direct — sample remote
netflix.ca
nflxvideo.net
bilivideo.com
# comment line
hdslb.com

apdcdn.tc.qq.com
```

`tests/bats/fixtures/domains-local-sample.txt`:
```
# local additions
my.custom-cdn.example.com
hdslb.com
```

- [ ] **Step 2: Create the bats test file with setup/teardown and placeholders**

`tests/bats/test_vipin_video_domains.bats`:
```bash
#!/usr/bin/env bats
# Unit tests for vipin-video-domains
# Run: bats tests/bats/test_vipin_video_domains.bats

SCRIPT="${BATS_TEST_DIRNAME}/../../files/usr/sbin/vipin-video-domains"
FIX="${BATS_TEST_DIRNAME}/fixtures"

setup() {
    export VIPIN_VIDEO_ROOT="$(mktemp -d)"
    export VIPIN_VIDEO_MOCK=1
    mkdir -p "${VIPIN_VIDEO_ROOT}/etc/vipin"
    mkdir -p "${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d"
    mkdir -p "${VIPIN_VIDEO_ROOT}/var/lock"
    mkdir -p "${VIPIN_VIDEO_ROOT}/var/log"
}

teardown() {
    rm -rf "$VIPIN_VIDEO_ROOT"
}

@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "invoked without args prints usage and exits 2" {
    run "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage:"* ]]
}
```

- [ ] **Step 3: Create the script skeleton so tests can find it**

`files/usr/sbin/vipin-video-domains`:
```sh
#!/bin/sh
# vipin-video-domains — manage the video_direct domain list
#
# Subcommands:
#   enable              Merge sources, write dnsmasq include, reload dnsmasq
#   disable             Remove dnsmasq include, reload dnsmasq, flush nft set
#   refresh             Fetch remote list from GitHub, re-run enable
#   status              Print status summary
#   add <domain>        Add to local list
#   remove <domain>     Remove from local list
#   list                Print merged final list with source tags
#   show-set            Dump current nft set contents
#   parse-list <file>   (test hook) parse a list file to stdout
#   merge               (test hook) print merged domain list
#   validate-domain <d> (test hook) exit 0 if valid
#   render-dnsmasq      (test hook) print dnsmasq include content
#
# Env:
#   VIPIN_VIDEO_ROOT    Override /etc /var paths (for bats)
#   VIPIN_VIDEO_MOCK    =1 to skip dnsmasq restart / nft / uci calls

set -eu

ROOT="${VIPIN_VIDEO_ROOT:-}"
MOCK="${VIPIN_VIDEO_MOCK:-0}"

CONF_DIR="${ROOT}/etc/vipin"
REMOTE="${CONF_DIR}/video-domains.remote"
LOCAL="${CONF_DIR}/video-domains.local"
DNSMASQ_DIR="${ROOT}/etc/dnsmasq.d"
DNSMASQ_CONF="${DNSMASQ_DIR}/vipin-video.conf"
LOCK_FILE="${ROOT}/var/lock/vipin-video.lock"
LOG_FILE="${ROOT}/var/log/vipin-video.log"

NFT_SET="vipin_video"
NFT_FAMILY="inet"
NFT_TABLE="fw4"

DEFAULT_URL="https://raw.githubusercontent.com/vipinus/openwrt-2026-video-domains/main/domains.txt"

usage() {
    cat <<EOF
Usage: vipin-video-domains {enable|disable|refresh|status|add|remove|list|show-set}
       vipin-video-domains {parse-list|merge|validate-domain|render-dnsmasq}  (test hooks)
EOF
    exit 2
}

case "${1:-}" in
    *) usage ;;
esac
```

Make executable:
```bash
chmod +x files/usr/sbin/vipin-video-domains
```

- [ ] **Step 4: Run bats — expect the two skeleton tests to pass**

Run:
```bash
cd /home/ddxs/Sync/Works/openwrt-2026
bats tests/bats/test_vipin_video_domains.bats
```
Expected: `2 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-video-domains tests/bats/
git commit -m "feat(video): skeleton script + bats test harness"
```

### Task 1.2: Implement `parse_list` (TDD)

**Files:**
- Modify: `files/usr/sbin/vipin-video-domains`
- Modify: `tests/bats/test_vipin_video_domains.bats`

- [ ] **Step 1: Add failing tests for parse_list**

Append to `tests/bats/test_vipin_video_domains.bats`:
```bash
@test "parse-list: strips comments, blanks, whitespace, lowercases" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/in.txt"
    run "$SCRIPT" parse-list "${VIPIN_VIDEO_ROOT}/in.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"netflix.ca"* ]]
    [[ "$output" == *"bilivideo.com"* ]]
    [[ "$output" == *"apdcdn.tc.qq.com"* ]]
    [[ "$output" != *"#"* ]]
    [[ "$output" != *"comment line"* ]]
}

@test "parse-list: returns empty for missing file" {
    run "$SCRIPT" parse-list "${VIPIN_VIDEO_ROOT}/nope.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "parse-list: handles uppercase input by lowercasing" {
    echo "FOO.BAR.com" > "${VIPIN_VIDEO_ROOT}/up.txt"
    run "$SCRIPT" parse-list "${VIPIN_VIDEO_ROOT}/up.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == "foo.bar.com" ]]
}
```

- [ ] **Step 2: Run tests — expect 3 failures (command not implemented)**

Run: `bats tests/bats/test_vipin_video_domains.bats`
Expected: 3 tests fail with usage-exit status.

- [ ] **Step 3: Implement `parse_list` and wire `parse-list` subcommand**

Edit `files/usr/sbin/vipin-video-domains`. Replace the `case "${1:-}"` block near the bottom with this (and add the function above the case):

```sh
parse_list() {
    local file="$1"
    [ -f "$file" ] || return 0
    # Strip # comments, leading/trailing whitespace, blank lines; lowercase.
    sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$file" \
        | awk 'NF' \
        | tr '[:upper:]' '[:lower:]'
}

case "${1:-}" in
    parse-list) shift; [ $# -ge 1 ] || usage; parse_list "$1" ;;
    *) usage ;;
esac
```

- [ ] **Step 4: Run tests — expect all to pass**

Run: `bats tests/bats/test_vipin_video_domains.bats`
Expected: `5 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-video-domains tests/bats/test_vipin_video_domains.bats
git commit -m "feat(video): parse_list function with bats tests"
```

### Task 1.3: Implement `validate_domain` (TDD)

- [ ] **Step 1: Append failing tests**

Add to `tests/bats/test_vipin_video_domains.bats`:
```bash
@test "validate-domain: accepts valid domains" {
    run "$SCRIPT" validate-domain "foo.example.com"
    [ "$status" -eq 0 ]
    run "$SCRIPT" validate-domain "a.b"
    [ "$status" -eq 0 ]
    run "$SCRIPT" validate-domain "x-y.example.net"
    [ "$status" -eq 0 ]
}

@test "validate-domain: rejects double-dot, leading-dot, trailing-dot" {
    run "$SCRIPT" validate-domain "foo..bar"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain ".foo.bar"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain "foo.bar."
    [ "$status" -ne 0 ]
}

@test "validate-domain: rejects leading/trailing dash, bare hostname, empty, illegal chars" {
    run "$SCRIPT" validate-domain "-foo.bar"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain "foo.bar-"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain "nodot"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain ""
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain "foo!bar.com"
    [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run tests — expect failures**

Run: `bats tests/bats/test_vipin_video_domains.bats`
Expected: 3 new tests fail.

- [ ] **Step 3: Implement `validate_domain`**

Add this function above the `case` block in `files/usr/sbin/vipin-video-domains`:
```sh
validate_domain() {
    local d="$1"
    case "$d" in
        ""|.*|*.|*..*|-*|*-|*[!a-z0-9.-]*) return 1 ;;
    esac
    case "$d" in
        *.*) return 0 ;;
        *)   return 1 ;;
    esac
}
```

Add dispatch in `case "${1:-}"`:
```sh
    validate-domain)  shift; [ $# -ge 1 ] || usage; validate_domain "$1" ;;
```

- [ ] **Step 4: Run tests — expect pass**

Run: `bats tests/bats/test_vipin_video_domains.bats`
Expected: `8 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-video-domains tests/bats/test_vipin_video_domains.bats
git commit -m "feat(video): validate_domain with format tests"
```

### Task 1.4: Implement `merge` (TDD)

- [ ] **Step 1: Append failing tests**

Add to `tests/bats/test_vipin_video_domains.bats`:
```bash
@test "merge: combines remote + local, deduped" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    cp "$FIX/domains-local-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
    run "$SCRIPT" merge
    [ "$status" -eq 0 ]
    [[ "$output" == *"netflix.ca"* ]]
    [[ "$output" == *"my.custom-cdn.example.com"* ]]
    # hdslb.com appears in both — must appear exactly once
    local n
    n=$(echo "$output" | grep -cx "hdslb.com")
    [ "$n" = "1" ]
}

@test "merge: works with only remote present" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" merge
    [ "$status" -eq 0 ]
    [[ "$output" == *"netflix.ca"* ]]
}

@test "merge: works with only local present" {
    cp "$FIX/domains-local-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
    run "$SCRIPT" merge
    [ "$status" -eq 0 ]
    [[ "$output" == *"my.custom-cdn.example.com"* ]]
}

@test "merge: empty when no files" {
    run "$SCRIPT" merge
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
```

- [ ] **Step 2: Run — expect failures**

Run: `bats tests/bats/test_vipin_video_domains.bats`

- [ ] **Step 3: Implement `merge`**

Add function and dispatch:
```sh
merge() {
    {
        parse_list "$REMOTE"
        parse_list "$LOCAL"
    } | awk 'NF && !seen[$0]++'
}
```

Dispatch: `merge) merge ;;`

- [ ] **Step 4: Run — expect pass**

Run: `bats tests/bats/test_vipin_video_domains.bats` (12 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-video-domains tests/bats/test_vipin_video_domains.bats
git commit -m "feat(video): merge function with dedup tests"
```

### Task 1.5: Implement `render_dnsmasq` (TDD)

- [ ] **Step 1: Append failing tests**

```bash
@test "render-dnsmasq: produces nftset directives" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" render-dnsmasq
    [ "$status" -eq 0 ]
    [[ "$output" == *"nftset=/netflix.ca/4#inet#fw4#vipin_video"* ]]
    [[ "$output" == *"nftset=/bilivideo.com/4#inet#fw4#vipin_video"* ]]
    [[ "$output" == *"# Auto-generated"* ]]
}

@test "render-dnsmasq: skips blank/invalid domains from merge output" {
    printf "\nnetflix.ca\n\n" > "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" render-dnsmasq
    [ "$status" -eq 0 ]
    local n
    n=$(echo "$output" | grep -c "^nftset=")
    [ "$n" = "1" ]
}
```

- [ ] **Step 2: Run — expect failures**

Run: `bats tests/bats/test_vipin_video_domains.bats`

- [ ] **Step 3: Implement `render_dnsmasq`**

```sh
render_dnsmasq() {
    echo "# /etc/dnsmasq.d/vipin-video.conf"
    echo "# Auto-generated by vipin-video-domains; DO NOT EDIT"
    echo ""
    merge | while IFS= read -r d; do
        [ -z "$d" ] && continue
        echo "nftset=/${d}/4#${NFT_FAMILY}#${NFT_TABLE}#${NFT_SET}"
    done
}
```

Dispatch: `render-dnsmasq) render_dnsmasq ;;`

- [ ] **Step 4: Run — expect pass**

Run: `bats tests/bats/test_vipin_video_domains.bats` (14 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-video-domains tests/bats/test_vipin_video_domains.bats
git commit -m "feat(video): render_dnsmasq producing nftset directives"
```

### Task 1.6: Implement lock acquisition helpers

- [ ] **Step 1: Append failing tests**

```bash
@test "lock: acquire and release" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    # Touch lock file manually; script should remove stale one after 120s.
    # We test the happy path here — script must create and remove lock.
    run "$SCRIPT" add "foo.example.com"
    [ "$status" -eq 0 ]
    [ ! -f "${VIPIN_VIDEO_ROOT}/var/lock/vipin-video.lock" ]
}
```

(This test passes only after Task 1.8 adds `add`. For now we only implement the helpers.)

Note: this test will actually be validated at Task 1.8.

- [ ] **Step 2: Implement lock helpers**

Add to `files/usr/sbin/vipin-video-domains` above the `case`:
```sh
log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
    [ "$MOCK" = "1" ] || logger -t vipin-video "$*" 2>/dev/null || true
}

acquire_lock() {
    mkdir -p "$(dirname "$LOCK_FILE")" 2>/dev/null || true
    local wait=0
    while [ -f "$LOCK_FILE" ]; do
        local age
        age=$(( $(date +%s) - $(date -r "$LOCK_FILE" +%s 2>/dev/null || echo 0) ))
        if [ "$age" -gt 120 ]; then
            log "Removing stale lock (${age}s old)"
            rm -f "$LOCK_FILE"
            break
        fi
        wait=$((wait + 1))
        [ "$wait" -ge 60 ] && { log "Timeout waiting for lock"; return 1; }
        sleep 1
    done
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE" 2>/dev/null || true
}
```

- [ ] **Step 3: Run existing tests — expect still 14/14 passing**

Run: `bats tests/bats/test_vipin_video_domains.bats`
Expected: 14 tests pass (lock test is deferred to 1.8).

- [ ] **Step 4: Commit**

```bash
git add files/usr/sbin/vipin-video-domains
git commit -m "feat(video): lock + log helpers"
```

### Task 1.7: Implement `cmd_enable` and `cmd_disable` (TDD, MOCK-aware)

- [ ] **Step 1: Append failing tests**

```bash
@test "enable: writes dnsmasq include with merged domains" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" enable
    [ "$status" -eq 0 ]
    local conf="${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d/vipin-video.conf"
    [ -f "$conf" ]
    grep -q "nftset=/netflix.ca/4#inet#fw4#vipin_video" "$conf"
}

@test "enable: writes atomically via .new then rename" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" enable
    [ "$status" -eq 0 ]
    [ ! -f "${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d/vipin-video.conf.new" ]
}

@test "disable: removes dnsmasq include" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    "$SCRIPT" enable
    run "$SCRIPT" disable
    [ "$status" -eq 0 ]
    [ ! -f "${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d/vipin-video.conf" ]
}
```

- [ ] **Step 2: Run — expect 3 failures**

Run: `bats tests/bats/test_vipin_video_domains.bats`

- [ ] **Step 3: Implement cmd_enable and cmd_disable**

```sh
# UCI read helpers — fall through to defaults under MOCK.
uci_get() {
    if [ "$MOCK" = "1" ]; then
        case "$1" in
            vipin.vpn.video_direct) echo "${VIPIN_VIDEO_DIRECT:-1}" ;;
            vipin.vpn.split_mode)   echo "${VIPIN_SPLIT_MODE:-forward}" ;;
            vipin.vpn.video_url)    echo "${VIPIN_VIDEO_URL:-}" ;;
            *) echo "" ;;
        esac
    else
        uci get "$1" 2>/dev/null || echo ""
    fi
}

mode_compatible() {
    [ "$(uci_get vipin.vpn.split_mode)" = "forward" ]
}

cmd_enable() {
    local enabled
    enabled=$(uci_get vipin.vpn.video_direct)
    [ "$enabled" = "1" ] || { log "video_direct disabled in UCI"; cmd_disable; return 0; }
    mode_compatible || { log "reverse mode — video_direct not enabled"; cmd_disable; return 0; }
    mkdir -p "$DNSMASQ_DIR"
    render_dnsmasq > "${DNSMASQ_CONF}.new"
    mv "${DNSMASQ_CONF}.new" "$DNSMASQ_CONF"
    log "Wrote $DNSMASQ_CONF ($(merge | wc -l) domains)"
    if [ "$MOCK" != "1" ]; then
        /etc/init.d/dnsmasq restart 2>/dev/null || log "dnsmasq restart failed"
        /usr/sbin/vipin-vpn-routing reload 2>/dev/null || log "vipin-vpn-routing reload failed"
    fi
}

cmd_disable() {
    rm -f "$DNSMASQ_CONF"
    if [ "$MOCK" != "1" ]; then
        /etc/init.d/dnsmasq restart 2>/dev/null || true
        /usr/sbin/vipin-vpn-routing reload 2>/dev/null || true
        nft flush set "$NFT_FAMILY" "$NFT_TABLE" "$NFT_SET" 2>/dev/null || true
    fi
    log "Disabled video_direct"
}
```

Dispatch:
```sh
    enable)  cmd_enable ;;
    disable) cmd_disable ;;
```

- [ ] **Step 4: Run — expect pass**

Run: `bats tests/bats/test_vipin_video_domains.bats` (17 tests)

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-video-domains tests/bats/test_vipin_video_domains.bats
git commit -m "feat(video): cmd_enable and cmd_disable with MOCK support"
```

### Task 1.8: Implement `cmd_add` and `cmd_remove` (TDD)

- [ ] **Step 1: Append failing tests**

```bash
@test "add: appends valid domain to local file" {
    run "$SCRIPT" add "foo.example.com"
    [ "$status" -eq 0 ]
    grep -qx "foo.example.com" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
}

@test "add: rejects invalid domain" {
    run "$SCRIPT" add "not_a_domain"
    [ "$status" -ne 0 ]
}

@test "add: idempotent — duplicate not appended" {
    "$SCRIPT" add "foo.example.com"
    "$SCRIPT" add "foo.example.com"
    local n
    n=$(grep -cx "foo.example.com" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local")
    [ "$n" = "1" ]
}

@test "remove: deletes existing domain" {
    "$SCRIPT" add "foo.example.com"
    run "$SCRIPT" remove "foo.example.com"
    [ "$status" -eq 0 ]
    ! grep -qx "foo.example.com" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
}

@test "remove: idempotent when domain absent" {
    touch "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
    run "$SCRIPT" remove "not.present.example"
    [ "$status" -eq 0 ]
}

@test "add: releases lock on success" {
    "$SCRIPT" add "foo.example.com"
    [ ! -f "${VIPIN_VIDEO_ROOT}/var/lock/vipin-video.lock" ]
}
```

- [ ] **Step 2: Run — expect failures**

Run: `bats tests/bats/test_vipin_video_domains.bats`

- [ ] **Step 3: Implement cmd_add / cmd_remove**

```sh
cmd_add() {
    local d="$1"
    validate_domain "$d" || { echo "invalid domain: $d" >&2; return 1; }
    acquire_lock || return 1
    touch "$LOCAL"
    if ! grep -qxF "$d" "$LOCAL"; then
        echo "$d" >> "$LOCAL"
        log "Added local: $d"
    fi
    release_lock
    [ "$MOCK" = "1" ] || cmd_enable
}

cmd_remove() {
    local d="$1"
    acquire_lock || return 1
    if [ -f "$LOCAL" ]; then
        local tmp="${LOCAL}.tmp"
        grep -vxF "$d" "$LOCAL" > "$tmp" || true
        mv "$tmp" "$LOCAL"
        log "Removed local: $d"
    fi
    release_lock
    [ "$MOCK" = "1" ] || cmd_enable
}
```

Dispatch:
```sh
    add)    shift; [ $# -ge 1 ] || usage; cmd_add "$1" ;;
    remove) shift; [ $# -ge 1 ] || usage; cmd_remove "$1" ;;
```

- [ ] **Step 4: Run — expect pass**

Run: `bats tests/bats/test_vipin_video_domains.bats` (23 tests)

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-video-domains tests/bats/test_vipin_video_domains.bats
git commit -m "feat(video): cmd_add and cmd_remove with idempotency"
```

### Task 1.9: Implement `cmd_refresh` (TDD with MOCK curl)

- [ ] **Step 1: Append failing tests**

```bash
@test "refresh: successful curl updates remote and last_refresh" {
    # Inject a mock curl that writes our fixture to the output path.
    export VIPIN_VIDEO_MOCK_CURL_OK=1
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/mock-fetch.txt"
    export VIPIN_VIDEO_MOCK_CURL_PAYLOAD="${VIPIN_VIDEO_ROOT}/mock-fetch.txt"

    run "$SCRIPT" refresh
    [ "$status" -eq 0 ]
    [ -f "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote" ]
    grep -q "netflix.ca" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
}

@test "refresh: failed curl preserves old remote" {
    echo "OLD.CONTENT" > "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    export VIPIN_VIDEO_MOCK_CURL_OK=0

    run "$SCRIPT" refresh
    [ "$status" -ne 0 ]
    grep -q "OLD.CONTENT" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
}

@test "refresh: empty payload is treated as failure" {
    echo "OLD.CONTENT" > "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    export VIPIN_VIDEO_MOCK_CURL_OK=1
    echo -n "" > "${VIPIN_VIDEO_ROOT}/empty.txt"
    export VIPIN_VIDEO_MOCK_CURL_PAYLOAD="${VIPIN_VIDEO_ROOT}/empty.txt"

    run "$SCRIPT" refresh
    [ "$status" -ne 0 ]
    grep -q "OLD.CONTENT" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
}
```

- [ ] **Step 2: Run — expect failures**

Run: `bats tests/bats/test_vipin_video_domains.bats`

- [ ] **Step 3: Implement cmd_refresh and mock hook**

Add in `files/usr/sbin/vipin-video-domains` above the `case`:
```sh
fetch_remote() {
    local url="$1"
    local out="$2"
    if [ "$MOCK" = "1" ]; then
        if [ "${VIPIN_VIDEO_MOCK_CURL_OK:-0}" = "1" ] && [ -f "${VIPIN_VIDEO_MOCK_CURL_PAYLOAD:-}" ]; then
            cp "$VIPIN_VIDEO_MOCK_CURL_PAYLOAD" "$out"
            return 0
        fi
        return 1
    fi
    curl -sSL --max-time 10 --retry 1 "$url" -o "$out"
}

cmd_refresh() {
    acquire_lock || return 1
    trap 'release_lock' EXIT INT TERM

    local url
    url=$(uci_get vipin.vpn.video_url)
    [ -z "$url" ] && url="$DEFAULT_URL"

    local tmp="${REMOTE}.new"
    if ! fetch_remote "$url" "$tmp"; then
        log "fetch failed: $url"
        rm -f "$tmp"
        release_lock
        trap - EXIT INT TERM
        return 1
    fi
    if [ ! -s "$tmp" ]; then
        log "fetch empty: $url"
        rm -f "$tmp"
        release_lock
        trap - EXIT INT TERM
        return 1
    fi
    mv "$tmp" "$REMOTE"
    log "Fetched $(wc -l < "$REMOTE") lines from $url"

    if [ "$MOCK" != "1" ]; then
        uci set vipin.vpn.video_last_refresh="$(date +%s)"
        uci commit vipin
        nft flush set "$NFT_FAMILY" "$NFT_TABLE" "$NFT_SET" 2>/dev/null \
            && log "Flushed nft set $NFT_SET" \
            || log "nft flush skipped"
    fi

    cmd_enable
    release_lock
    trap - EXIT INT TERM
}
```

Dispatch: `refresh) cmd_refresh ;;`

- [ ] **Step 4: Run — expect pass**

Run: `bats tests/bats/test_vipin_video_domains.bats` (26 tests)

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-video-domains tests/bats/test_vipin_video_domains.bats
git commit -m "feat(video): cmd_refresh with mockable curl and atomic write"
```

### Task 1.10: Implement `cmd_status` and `cmd_list` and `cmd_show_set`

- [ ] **Step 1: Append failing tests**

```bash
@test "status: outputs expected lines under MOCK" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"video_direct:"* ]]
    [[ "$output" == *"split_mode:"* ]]
    [[ "$output" == *"domains:"* ]]
}

@test "list: tags source on each domain" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    cp "$FIX/domains-local-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
    run "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"remote netflix.ca"* ]]
    [[ "$output" == *"local my.custom-cdn.example.com"* ]]
}
```

- [ ] **Step 2: Run — expect failures**

Run: `bats tests/bats/test_vipin_video_domains.bats`

- [ ] **Step 3: Implement**

```sh
cmd_status() {
    local enabled mode rcount lcount last
    enabled=$(uci_get vipin.vpn.video_direct)
    mode=$(uci_get vipin.vpn.split_mode)
    rcount=$(parse_list "$REMOTE" | wc -l)
    lcount=$(parse_list "$LOCAL" | wc -l)
    last=$(uci_get vipin.vpn.video_last_refresh)
    if [ -n "$last" ]; then
        last=$(date -d "@$last" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$last")
    else
        last="never"
    fi
    cat <<EOF
video_direct: $( [ "$enabled" = "1" ] && echo enabled || echo disabled )
split_mode:   $mode ($( mode_compatible && echo compatible || echo incompatible ))
domains:      remote $rcount / local $lcount
last_refresh: $last
EOF
}

cmd_list() {
    parse_list "$REMOTE" | while IFS= read -r d; do echo "remote $d"; done
    parse_list "$LOCAL"  | while IFS= read -r d; do echo "local $d"; done
}

cmd_show_set() {
    nft list set "$NFT_FAMILY" "$NFT_TABLE" "$NFT_SET" 2>/dev/null \
        || echo "set $NFT_SET not present"
}
```

Dispatch:
```sh
    status)    cmd_status ;;
    list)      cmd_list ;;
    show-set)  cmd_show_set ;;
```

- [ ] **Step 4: Run — expect pass**

Run: `bats tests/bats/test_vipin_video_domains.bats` (28 tests)

- [ ] **Step 5: Commit**

```bash
git add files/usr/sbin/vipin-video-domains tests/bats/test_vipin_video_domains.bats
git commit -m "feat(video): cmd_status, cmd_list, cmd_show_set"
```

### Task 1.11: Behavioral tests for `video_direct=0` and `split_mode=reverse`

- [ ] **Step 1: Append tests**

```bash
@test "enable is a no-op when video_direct=0" {
    export VIPIN_VIDEO_DIRECT=0
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" enable
    [ "$status" -eq 0 ]
    [ ! -f "${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d/vipin-video.conf" ]
}

@test "enable is a no-op when split_mode=reverse" {
    export VIPIN_SPLIT_MODE=reverse
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" enable
    [ "$status" -eq 0 ]
    [ ! -f "${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d/vipin-video.conf" ]
}
```

- [ ] **Step 2: Run — expect pass (cmd_enable already handles these)**

Run: `bats tests/bats/test_vipin_video_domains.bats` (30 tests)

- [ ] **Step 3: Commit**

```bash
git add tests/bats/test_vipin_video_domains.bats
git commit -m "test(video): coverage for video_direct=0 and reverse mode"
```

### Task 1.12: shellcheck clean-pass

- [ ] **Step 1: Run shellcheck**

Run:
```bash
shellcheck files/usr/sbin/vipin-video-domains
```

Expected: clean. If warnings, fix them (most common: quote variables, use `$()` not backticks, etc.).

- [ ] **Step 2: Run bats again to confirm no regression**

Run: `bats tests/bats/test_vipin_video_domains.bats`

- [ ] **Step 3: Commit if any fixes**

```bash
git add files/usr/sbin/vipin-video-domains
git commit -m "chore(video): shellcheck clean"
```

---

# Phase 2: UCI config + init.d + cron

### Task 2.1: Add UCI options to `/etc/config/vipin`

**Files:** `files/etc/config/vipin`

- [ ] **Step 1: Edit config file**

Current content:
```
config vpn 'vpn'
	option enabled '0'
	option server ''
	option username ''
	option split_tunnel '1'
	option split_mode 'forward'
	option country 'cn'
	option base_domain 'fanq.in'
	option site_url 'https://www.anyfq.com'
```

New content (append two options before the blank final line):
```
config vpn 'vpn'
	option enabled '0'
	option server ''
	option username ''
	option split_tunnel '1'
	option split_mode 'forward'
	option country 'cn'
	option base_domain 'fanq.in'
	option site_url 'https://www.anyfq.com'
	option video_direct '1'
	option video_last_refresh ''
```

- [ ] **Step 2: Commit**

```bash
git add files/etc/config/vipin
git commit -m "feat(uci): add video_direct and video_last_refresh options"
```

### Task 2.2: Create `/etc/init.d/vipin-video`

**Files:** Create `files/etc/init.d/vipin-video`

- [ ] **Step 1: Write the init script**

```sh
#!/bin/sh /etc/rc.common
# vipin-video — video_direct feature init.d (runs enable on boot)

START=91
USE_PROCD=1
NAME=vipin-video

start_service() {
    # enable is network-free; safe to run at boot regardless of VPN state
    /usr/sbin/vipin-video-domains enable 2>/dev/null || true
}

stop_service() {
    /usr/sbin/vipin-video-domains disable 2>/dev/null || true
}

reload_service() {
    /usr/sbin/vipin-video-domains enable 2>/dev/null || true
}
```

Make executable:
```bash
chmod +x files/etc/init.d/vipin-video
```

- [ ] **Step 2: Commit**

```bash
git add files/etc/init.d/vipin-video
git commit -m "feat(video): procd init.d for vipin-video (START=91)"
```

### Task 2.3: Add weekly cron entry

**Files:** Edit/create `files/etc/crontabs/root`

- [ ] **Step 1: Check if file exists**

Run: `ls files/etc/crontabs/root 2>&1`

- [ ] **Step 2: Append cron line (create if missing)**

If file exists, append:
```
0 4 * * 0 /usr/sbin/vipin-video-domains refresh
```

If file does not exist, create with just that line.

- [ ] **Step 3: Commit**

```bash
git add files/etc/crontabs/root
git commit -m "feat(video): weekly Sunday 04:00 cron for domain refresh"
```

### Task 2.4: Create placeholder for local domain file

**Files:** Create `files/etc/vipin/video-domains.local`

- [ ] **Step 1: Create empty file**

Content:
```
# User-maintained additions to video_direct domain list.
# One domain per line. # for comments.
# Edit via LuCI "Video Direct" panel or directly here.
```

- [ ] **Step 2: Commit**

```bash
git add files/etc/vipin/video-domains.local
git commit -m "feat(video): empty local domain placeholder"
```

---

# Phase 3: nftables integration in vipin-vpn-routing

`vipin-vpn-routing` writes `/etc/nftables.d/vipin.nft` (currently the variable `NFT_RULES`). We add the `vipin_video` set declaration in BOTH the reverse and forward heredocs, but only add the **mark rule** in the forward heredoc (because reverse mode force-disables the feature).

### Task 3.1: Patch `vipin-vpn-routing` forward-mode heredoc

**Files:** `files/usr/sbin/vipin-vpn-routing`

- [ ] **Step 1: Read current forward heredoc (lines 200-228)**

Run:
```bash
sed -n '199,230p' files/usr/sbin/vipin-vpn-routing
```

- [ ] **Step 2: Edit the forward-mode heredoc**

Replace the block from `# Forward (default):` through the matching `EOF`:

Old (current lines ~199-228):
```sh
    else
        # Forward (default): IPs in set → mark direct, everything else → VPN
        cat > "$NFT_RULES" << 'EOF'
set vipin_domestic {
    type ipv4_addr
    flags interval
}

chain vipin_prerouting {
    type filter hook prerouting priority mangle;
    ip daddr 10.0.0.0/8 return
    ip daddr 172.16.0.0/12 return
    ip daddr 192.168.0.0/16 return
    ip daddr @vipin_domestic meta mark set 0x200
}

chain vipin_output {
    type route hook output priority mangle;
    oifname "vpn_vipin" return
    oifname "lo" return
    ip daddr 10.0.0.0/8 return
    ip daddr 172.16.0.0/12 return
    ip daddr 192.168.0.0/16 return
    ip daddr @vipin_domestic meta mark set 0x200
}

chain vipin_postrouting {
    type nat hook postrouting priority srcnat;
    oifname "vpn_vipin" masquerade
}
EOF
    fi
```

New:
```sh
    else
        # Forward (default): IPs in set → mark direct, everything else → VPN
        # Also includes vipin_video set (populated by dnsmasq-full at DNS resolve time)
        # for video_direct feature — matches route same mark, bypassing the tunnel.
        local video_rule=""
        if [ "$(uci get vipin.vpn.video_direct 2>/dev/null || echo 1)" = "1" ]; then
            video_rule="    ip daddr @vipin_video meta mark set 0x200"
        fi
        cat > "$NFT_RULES" << EOF
set vipin_domestic {
    type ipv4_addr
    flags interval
}

set vipin_video {
    type ipv4_addr
    flags interval
    size 65536
}

chain vipin_prerouting {
    type filter hook prerouting priority mangle;
    ip daddr 10.0.0.0/8 return
    ip daddr 172.16.0.0/12 return
    ip daddr 192.168.0.0/16 return
    ip daddr @vipin_domestic meta mark set 0x200
${video_rule}
}

chain vipin_output {
    type route hook output priority mangle;
    oifname "vpn_vipin" return
    oifname "lo" return
    ip daddr 10.0.0.0/8 return
    ip daddr 172.16.0.0/12 return
    ip daddr 192.168.0.0/16 return
    ip daddr @vipin_domestic meta mark set 0x200
${video_rule}
}

chain vipin_postrouting {
    type nat hook postrouting priority srcnat;
    oifname "vpn_vipin" masquerade
}
EOF
    fi
```

Note the heredoc delimiter changed from `<< 'EOF'` (quoted, no expansion) to `<< EOF` (expansion enabled) so `${video_rule}` interpolates.

- [ ] **Step 3: Verify nft syntax by rendering a mock output**

Run:
```bash
# Locally lint: run the forward branch by extracting the new block and
# replacing $NFT_RULES with a temp file.
tmp=$(mktemp)
mode=forward
video_rule="    ip daddr @vipin_video meta mark set 0x200"
cat > "$tmp" << EOF
set vipin_domestic { type ipv4_addr; flags interval; }
set vipin_video { type ipv4_addr; flags interval; size 65536; }
chain vipin_prerouting {
    type filter hook prerouting priority mangle;
    ip daddr 10.0.0.0/8 return
    ip daddr @vipin_domestic meta mark set 0x200
${video_rule}
}
EOF
nft -c -f "$tmp"  # -c: check only, no apply
rm -f "$tmp"
```

Expected: no output (syntax OK). Error means the heredoc produced malformed nft.

- [ ] **Step 4: Commit**

```bash
git add files/usr/sbin/vipin-vpn-routing
git commit -m "feat(video): declare vipin_video set + mark rule in forward mode"
```

### Task 3.2: Patch reverse-mode heredoc to declare the set (but not mark it)

**Files:** `files/usr/sbin/vipin-vpn-routing`

- [ ] **Step 1: Edit reverse heredoc (around lines 167-196)**

Old:
```sh
    if [ "$mode" = "reverse" ]; then
        # Reverse: IPs in set → return (go through VPN), everything else → mark direct
        cat > "$NFT_RULES" << 'EOF'
set vipin_domestic {
    type ipv4_addr
    flags interval
}

chain vipin_prerouting {
...
```

New (just adds the empty set declaration — no mark rule):
```sh
    if [ "$mode" = "reverse" ]; then
        # Reverse: IPs in set → return (go through VPN), everything else → mark direct
        # vipin_video set is declared but NOT referenced — video_direct is hard-disabled in reverse mode.
        cat > "$NFT_RULES" << 'EOF'
set vipin_domestic {
    type ipv4_addr
    flags interval
}

set vipin_video {
    type ipv4_addr
    flags interval
    size 65536
}

chain vipin_prerouting {
...
```

Apply the same 4-line insertion (blank line + `set vipin_video { ... }` block) after the `set vipin_domestic { ... }` block. Do NOT add `@vipin_video` anywhere in the reverse heredoc.

- [ ] **Step 2: Commit**

```bash
git add files/usr/sbin/vipin-vpn-routing
git commit -m "feat(video): declare empty vipin_video set in reverse mode"
```

### Task 3.3: Smoke test the patched script under MOCK

- [ ] **Step 1: Dry-run the script to a temp file**

Since we're not on a router, we can't run the real thing. Spot-check by searching:

```bash
grep -n "vipin_video" files/usr/sbin/vipin-vpn-routing
```

Expected output: set declarations in both heredocs, mark rule only in forward heredoc.

- [ ] **Step 2: Commit if any fix**

(Usually none.)

---

# Phase 4: LuCI controller RPC

Five new entries in `index()` and five new functions in `vpn.lua`.

### Task 4.1: Register the 5 new entry() calls

**Files:** `files/usr/lib/lua/luci/controller/vpn.lua`

- [ ] **Step 1: Read the current index() function**

Run:
```bash
sed -n '187,215p' files/usr/lib/lua/luci/controller/vpn.lua
```

- [ ] **Step 2: Insert new entries after line 202 (api_set_server)**

Add these 5 lines immediately after `api_set_server`:
```lua
    entry({"admin", "services", "vpn", "api_video_status"},  call("api_video_status"),  nil, 31)
    entry({"admin", "services", "vpn", "api_video_refresh"}, call("api_video_refresh"), nil, 32)
    entry({"admin", "services", "vpn", "api_video_toggle"},  call("api_video_toggle"),  nil, 33)
    entry({"admin", "services", "vpn", "api_video_add"},     call("api_video_add"),     nil, 34)
    entry({"admin", "services", "vpn", "api_video_remove"},  call("api_video_remove"),  nil, 35)
```

- [ ] **Step 3: Commit**

```bash
git add files/usr/lib/lua/luci/controller/vpn.lua
git commit -m "feat(luci): register 5 video_direct RPC entries"
```

### Task 4.2: Implement `api_video_status`

**Files:** `files/usr/lib/lua/luci/controller/vpn.lua`

- [ ] **Step 1: Append function at bottom of file (before EOF)**

Add:
```lua
function api_video_status()
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()

    local enabled = uci:get("vipin", "vpn", "video_direct") or "1"
    local mode = uci:get("vipin", "vpn", "split_mode") or "forward"
    local last = uci:get("vipin", "vpn", "video_last_refresh") or ""

    local remote_count = tonumber(sys.exec(
        "wc -l < /etc/vipin/video-domains.remote 2>/dev/null") or "0") or 0

    -- Read the full local list (excluding comments and blanks) so the UI
    -- can render individual rows with delete buttons. Cap at 200 lines
    -- as a safety rail; pagination is deferred to P1.
    local local_list = {}
    local local_f = io.open("/etc/vipin/video-domains.local", "r")
    if local_f then
        for line in local_f:lines() do
            local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
            if trimmed ~= "" and not trimmed:match("^#") then
                table.insert(local_list, trimmed)
                if #local_list >= 200 then break end
            end
        end
        local_f:close()
    end

    local set_count = tonumber(sys.exec(
        "nft list set inet fw4 vipin_video 2>/dev/null | awk '/elements =/{print NF-3; exit}' | tr -d ',}'") or "0") or 0

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        enabled = (enabled == "1"),
        split_mode = mode,
        remote_count = remote_count,
        local_count = #local_list,
        local_list = local_list,
        set_count = set_count,
        last_refresh = last
    })
end
```

- [ ] **Step 2: Commit**

```bash
git add files/usr/lib/lua/luci/controller/vpn.lua
git commit -m "feat(luci): api_video_status returns counts and last_refresh"
```

### Task 4.3: Implement `api_video_refresh`, `api_video_toggle`

- [ ] **Step 1: Append functions**

```lua
function api_video_refresh()
    local sys = require "luci.sys"
    local rc = sys.call("/usr/sbin/vipin-video-domains refresh >/tmp/vipin-video-refresh.log 2>&1")
    luci.http.prepare_content("application/json")
    if rc == 0 then
        luci.http.write_json({ success = true })
    else
        local msg = sys.exec("tail -3 /tmp/vipin-video-refresh.log 2>/dev/null")
        luci.http.write_json({ success = false, message = msg or "refresh failed" })
    end
end

function api_video_toggle()
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()
    local enabled = luci.http.formvalue("enabled")
    local target = (enabled == "1" or enabled == "true") and "1" or "0"
    uci:set("vipin", "vpn", "video_direct", target)
    uci:commit("vipin")
    if target == "1" then
        sys.call("/usr/sbin/vipin-video-domains enable >/dev/null 2>&1")
    else
        sys.call("/usr/sbin/vipin-video-domains disable >/dev/null 2>&1")
    end
    luci.http.prepare_content("application/json")
    luci.http.write_json({ success = true, enabled = (target == "1") })
end
```

- [ ] **Step 2: Commit**

```bash
git add files/usr/lib/lua/luci/controller/vpn.lua
git commit -m "feat(luci): api_video_refresh and api_video_toggle"
```

### Task 4.4: Implement `api_video_add` and `api_video_remove`

- [ ] **Step 1: Append functions**

```lua
function api_video_add()
    local sys = require "luci.sys"
    local domain = luci.http.formvalue("domain") or ""
    domain = string.lower(domain):gsub("^%s+", ""):gsub("%s+$", "")
    luci.http.prepare_content("application/json")
    -- Server-side format check mirrors shell validate_domain
    if domain == "" or not domain:match("^[a-z0-9%.%-]+$")
        or domain:match("%.%.") or domain:match("^%.") or domain:match("%.$")
        or domain:match("^%-") or domain:match("%-$") or not domain:match("%.") then
        luci.http.write_json({ success = false, message = "invalid domain format" })
        return
    end
    local rc = sys.call("/usr/sbin/vipin-video-domains add " ..
        string.format("%q", domain) .. " >/dev/null 2>&1")
    luci.http.write_json({ success = (rc == 0) })
end

function api_video_remove()
    local sys = require "luci.sys"
    local domain = luci.http.formvalue("domain") or ""
    domain = string.lower(domain):gsub("^%s+", ""):gsub("%s+$", "")
    luci.http.prepare_content("application/json")
    -- Same tight charset check as add — prevents shell injection via sys.call.
    if domain == "" or not domain:match("^[a-z0-9%.%-]+$")
        or domain:match("%.%.") or domain:match("^%.") or domain:match("%.$")
        or domain:match("^%-") or domain:match("%-$") or not domain:match("%.") then
        luci.http.write_json({ success = false, message = "invalid domain format" })
        return
    end
    local rc = sys.call("/usr/sbin/vipin-video-domains remove " ..
        string.format("%q", domain) .. " >/dev/null 2>&1")
    luci.http.write_json({ success = (rc == 0) })
end
```

- [ ] **Step 2: Commit**

```bash
git add files/usr/lib/lua/luci/controller/vpn.lua
git commit -m "feat(luci): api_video_add and api_video_remove"
```

---

# Phase 5: LuCI view (settings.htm)

### Task 5.1: Add the Video Direct panel HTML

**Files:** `files/usr/lib/lua/luci/view/vpn/settings.htm`

- [ ] **Step 1: Find insertion point**

Run:
```bash
grep -n "split_tunnel\|<%+footer%>\|</body>" files/usr/lib/lua/luci/view/vpn/settings.htm | head -20
```

Identify the end of the existing split-tunnel section. Insert the new panel immediately after it and before `<%+footer%>`.

- [ ] **Step 2: Insert panel block**

Paste this block (adjust parent wrapper class to match existing panels — inspect existing split-tunnel HTML for the class names):

```html
<!-- ============================= Video Direct ============================= -->
<div class="cbi-section" id="vipin-video-panel">
    <h3><%:video_direct_title%></h3>
    <p class="cbi-section-descr"><%:video_direct_desc%></p>

    <div id="vipin-video-reverse-warning" style="display:none; padding:10px; background:#fff3cd; border-left:4px solid #ffc107; margin-bottom:10px;">
        <%:video_reverse_warning%>
    </div>

    <div class="cbi-value">
        <label class="cbi-value-title"><%:video_direct_enable%></label>
        <div class="cbi-value-field">
            <input type="checkbox" id="vipin-video-toggle" />
        </div>
    </div>

    <div class="cbi-value">
        <label class="cbi-value-title"><%:video_status_remote%> / <%:video_status_local%> / <%:video_status_set%></label>
        <div class="cbi-value-field">
            <span id="vipin-video-remote-count">-</span> /
            <span id="vipin-video-local-count">-</span> /
            <span id="vipin-video-set-count">-</span> IPs
        </div>
    </div>

    <div class="cbi-value">
        <label class="cbi-value-title"><%:video_status_last_refresh%></label>
        <div class="cbi-value-field">
            <span id="vipin-video-last-refresh"><%:video_status_never%></span>
            <button type="button" id="vipin-video-refresh-btn" class="cbi-button"><%:video_refresh_button%></button>
        </div>
    </div>

    <div class="cbi-value">
        <label class="cbi-value-title"><%:video_local_add%></label>
        <div class="cbi-value-field">
            <input type="text" id="vipin-video-add-input" placeholder="<%:video_local_placeholder%>" style="width:240px;" />
            <button type="button" id="vipin-video-add-btn" class="cbi-button"><%:video_local_add%></button>
        </div>
    </div>

    <div class="cbi-value">
        <label class="cbi-value-title"><%:video_status_local%></label>
        <div class="cbi-value-field">
            <ul id="vipin-video-local-list" style="list-style:none; padding:0; margin:0;"></ul>
        </div>
    </div>
</div>
```

- [ ] **Step 3: Commit**

```bash
git add files/usr/lib/lua/luci/view/vpn/settings.htm
git commit -m "feat(luci): video_direct panel HTML"
```

### Task 5.2: Add JavaScript for polling, toggle, refresh, add, remove

**Files:** `files/usr/lib/lua/luci/view/vpn/settings.htm`

- [ ] **Step 1: Insert script block before `</body>` or inside existing script tag at bottom**

Locate the existing `<script>` region at the bottom of `settings.htm`. Append (or add new `<script>` block):

```html
<script>
(function() {
    const RPC = {
        status:  '<%=luci.dispatcher.build_url("admin/services/vpn/api_video_status")%>',
        refresh: '<%=luci.dispatcher.build_url("admin/services/vpn/api_video_refresh")%>',
        toggle:  '<%=luci.dispatcher.build_url("admin/services/vpn/api_video_toggle")%>',
        add:     '<%=luci.dispatcher.build_url("admin/services/vpn/api_video_add")%>',
        remove:  '<%=luci.dispatcher.build_url("admin/services/vpn/api_video_remove")%>'
    };

    function q(id) { return document.getElementById(id); }

    function postForm(url, data) {
        const body = Object.keys(data).map(k =>
            encodeURIComponent(k) + "=" + encodeURIComponent(data[k])).join("&");
        return fetch(url, {
            method: "POST", credentials: "same-origin",
            headers: {"Content-Type": "application/x-www-form-urlencoded"},
            body: body
        }).then(r => r.json());
    }

    function renderStatus(s) {
        q("vipin-video-toggle").checked = !!s.enabled;
        q("vipin-video-remote-count").textContent = s.remote_count;
        q("vipin-video-local-count").textContent = s.local_count;
        q("vipin-video-set-count").textContent = s.set_count;
        q("vipin-video-last-refresh").textContent = s.last_refresh
            ? new Date(s.last_refresh * 1000).toLocaleString()
            : '<%:video_status_never%>';
        const reverse = (s.split_mode === "reverse");
        q("vipin-video-reverse-warning").style.display = reverse ? "block" : "none";
        q("vipin-video-toggle").disabled = reverse;
        q("vipin-video-refresh-btn").disabled = reverse;

        const ul = q("vipin-video-local-list");
        ul.innerHTML = "";
        (s.local_list || []).forEach(function(d) {
            const li = document.createElement("li");
            li.style.padding = "4px 0";
            const label = document.createElement("span");
            label.textContent = d;
            label.style.marginRight = "8px";
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "cbi-button";
            btn.textContent = '<%:video_local_remove%>';
            btn.addEventListener("click", function() {
                postForm(RPC.remove, {domain: d}).then(function(r) {
                    if (r.success) refreshStatus();
                    else alert(r.message || "remove failed");
                });
            });
            li.appendChild(label);
            li.appendChild(btn);
            ul.appendChild(li);
        });
    }

    function refreshStatus() {
        fetch(RPC.status, {credentials: "same-origin"})
            .then(r => r.json()).then(renderStatus).catch(() => {});
    }

    q("vipin-video-toggle").addEventListener("change", function() {
        postForm(RPC.toggle, {enabled: this.checked ? "1" : "0"}).then(refreshStatus);
    });

    q("vipin-video-refresh-btn").addEventListener("click", function() {
        const btn = this; btn.disabled = true; btn.textContent = '<%:loading%>';
        postForm(RPC.refresh, {}).then(r => {
            btn.disabled = false; btn.textContent = '<%:video_refresh_button%>';
            alert(r.success ? '<%:video_refresh_success%>' : '<%:video_refresh_fail%>');
            refreshStatus();
        });
    });

    q("vipin-video-add-btn").addEventListener("click", function() {
        const input = q("vipin-video-add-input");
        const d = input.value.trim().toLowerCase();
        if (!d) return;
        postForm(RPC.add, {domain: d}).then(r => {
            if (r.success) { input.value = ""; refreshStatus(); }
            else alert(r.message || "add failed");
        });
    });

    refreshStatus();
    setInterval(refreshStatus, 10000);
})();
</script>
```

- [ ] **Step 2: Commit**

```bash
git add files/usr/lib/lua/luci/view/vpn/settings.htm
git commit -m "feat(luci): video_direct panel JS (toggle, refresh, add, poll)"
```

---

# Phase 6: i18n keys across 17 locales

### Task 6.1: Add English keys (authoritative)

**Files:** `files/usr/lib/lua/luci/view/vpn/i18n/en.lua`

- [ ] **Step 1: Insert 15 new keys before the closing `}`**

Current last lines:
```lua
    split_reverse = "Reverse Split",
    split_reverse_desc = "Only VPN server country IPs via VPN, rest direct. For best results, set device DNS to a server in that country."
}
```

Replace with:
```lua
    split_reverse = "Reverse Split",
    split_reverse_desc = "Only VPN server country IPs via VPN, rest direct. For best results, set device DNS to a server in that country.",
    video_direct_title = "Video Direct",
    video_direct_desc = "Route video CDN traffic directly via WAN instead of through the VPN tunnel.",
    video_direct_enable = "Enable video direct routing",
    video_status_remote = "Remote",
    video_status_local = "Local",
    video_status_set = "IPs in set",
    video_status_last_refresh = "Last refresh",
    video_status_never = "Never",
    video_refresh_button = "Refresh now",
    video_refresh_success = "Domain list refreshed",
    video_refresh_fail = "Refresh failed (check logs)",
    video_local_add = "Add",
    video_local_placeholder = "Enter a domain (e.g. video.example.com)",
    video_local_remove = "Remove",
    video_reverse_warning = "Video direct is disabled in Reverse Split mode."
}
```

- [ ] **Step 2: Commit**

```bash
git add files/usr/lib/lua/luci/view/vpn/i18n/en.lua
git commit -m "i18n(en): 15 video_direct strings"
```

### Task 6.2: Add Chinese Simplified keys (zh-CN)

**Files:** `files/usr/lib/lua/luci/view/vpn/i18n/zh-CN.lua`

- [ ] **Step 1: Insert keys (translate English to zh-CN)**

Open the file, find the closing `}`, insert before it (add a comma to preceding line if needed):

```lua
    video_direct_title = "视频直连",
    video_direct_desc = "将视频 CDN 流量直接从 WAN 出，不经过 VPN 隧道。",
    video_direct_enable = "启用视频直连",
    video_status_remote = "远程列表",
    video_status_local = "本机列表",
    video_status_set = "集合 IP 数",
    video_status_last_refresh = "最后刷新",
    video_status_never = "从未",
    video_refresh_button = "立即刷新",
    video_refresh_success = "域名列表已刷新",
    video_refresh_fail = "刷新失败（查看日志）",
    video_local_add = "添加",
    video_local_placeholder = "输入域名（如 video.example.com）",
    video_local_remove = "删除",
    video_reverse_warning = "反向分流模式下视频直连不可用。"
```

- [ ] **Step 2: Commit**

```bash
git add files/usr/lib/lua/luci/view/vpn/i18n/zh-CN.lua
git commit -m "i18n(zh-CN): 15 video_direct strings"
```

### Task 6.3: Add strings to the remaining 15 locales

**Files:** `files/usr/lib/lua/luci/view/vpn/i18n/{zh-TW,ja,ko,de,fr,es,pt,ru,ar,fa,hi,id,vi,th,tr}.lua`

- [ ] **Step 1: For each locale, add the same 15 keys**

Translations (concise, machine-translatable):

**zh-TW** (same as zh-CN but Traditional): reuse zh-CN values but switch 视频 → 視頻, 远程 → 遠端, 启用 → 啟用, 刷新 → 重新整理, 删除 → 移除.

**ja**:
```lua
    video_direct_title = "ビデオ直通",
    video_direct_desc = "動画CDNトラフィックをVPNトンネルではなくWAN経由で直接送信します。",
    video_direct_enable = "ビデオ直通を有効化",
    video_status_remote = "リモート",
    video_status_local = "ローカル",
    video_status_set = "セット内IP数",
    video_status_last_refresh = "最終更新",
    video_status_never = "未実行",
    video_refresh_button = "今すぐ更新",
    video_refresh_success = "ドメインリストを更新しました",
    video_refresh_fail = "更新に失敗しました",
    video_local_add = "追加",
    video_local_placeholder = "ドメインを入力 (例: video.example.com)",
    video_local_remove = "削除",
    video_reverse_warning = "リバース分割モードではビデオ直通は無効です。"
```

**zh-TW** (Traditional Chinese) — use this content (direct conversion from zh-CN):
```lua
    video_direct_title = "視頻直連",
    video_direct_desc = "將視頻 CDN 流量直接從 WAN 出，不經過 VPN 隧道。",
    video_direct_enable = "啟用視頻直連",
    video_status_remote = "遠端列表",
    video_status_local = "本機列表",
    video_status_set = "集合 IP 數",
    video_status_last_refresh = "最後重新整理",
    video_status_never = "從未",
    video_refresh_button = "立即重新整理",
    video_refresh_success = "網域列表已更新",
    video_refresh_fail = "更新失敗（請查看日誌）",
    video_local_add = "新增",
    video_local_placeholder = "輸入網域（例：video.example.com）",
    video_local_remove = "移除",
    video_reverse_warning = "反向分流模式下視頻直連不可用。"
```

**Other 13 locales** (`ko`, `de`, `fr`, `es`, `pt`, `ru`, `ar`, `fa`, `hi`, `id`, `vi`, `th`, `tr`): ship **English fallback values** for v2. Each file gets the exact same 15 lines as `en.lua`. Native translations are a post-v2 P1 follow-up (tracked in `docs/release-checklists/video-direct-v2.md` as a known limitation).

For each of the 13 locales, insert this block (identical to English):
```lua
    video_direct_title = "Video Direct",
    video_direct_desc = "Route video CDN traffic directly via WAN instead of through the VPN tunnel.",
    video_direct_enable = "Enable video direct routing",
    video_status_remote = "Remote",
    video_status_local = "Local",
    video_status_set = "IPs in set",
    video_status_last_refresh = "Last refresh",
    video_status_never = "Never",
    video_refresh_button = "Refresh now",
    video_refresh_success = "Domain list refreshed",
    video_refresh_fail = "Refresh failed (check logs)",
    video_local_add = "Add",
    video_local_placeholder = "Enter a domain (e.g. video.example.com)",
    video_local_remove = "Remove",
    video_reverse_warning = "Video direct is disabled in Reverse Split mode."
```

**Insertion recipe** for every file:
1. Open the file. The last line is `}` (the closing of the `return { ... }` table).
2. Find the last `key = "value"` line (the one immediately above the closing `}`). If it ends with `"` (no trailing comma), append a comma: `",` becomes `","`.
3. Insert the 15 lines from the appropriate block (ja / ko–tr English fallback / zh-TW) between that line and the closing `}`.
4. Save.

- [ ] **Step 2: Batch commit**

```bash
git add files/usr/lib/lua/luci/view/vpn/i18n/
git commit -m "i18n: 15 video_direct strings across 15 locales (13 en-fallback, zh-TW native, ja native)"
```

---

# Phase 7: Bulk flip 1071 configs from dnsmasq → dnsmasq-full

### Task 7.1: Write and test a flip script

**Files:** Create `scripts/flip-dnsmasq-full.sh` (one-shot, NOT shipped)

- [ ] **Step 1: Write the flip script**

```sh
#!/bin/sh
# One-shot: replace CONFIG_PACKAGE_dnsmasq=y with CONFIG_PACKAGE_dnsmasq-full=y
# in every configs/*.config file.

set -eu
cd "$(dirname "$0")/../configs"

changed=0
for f in *.config; do
    if grep -q "^CONFIG_PACKAGE_dnsmasq=y$" "$f"; then
        sed -i 's/^CONFIG_PACKAGE_dnsmasq=y$/CONFIG_PACKAGE_dnsmasq-full=y/' "$f"
        changed=$((changed + 1))
    fi
done
echo "Flipped: $changed files"
```

Make executable:
```bash
chmod +x scripts/flip-dnsmasq-full.sh
```

- [ ] **Step 2: Dry-run count**

```bash
grep -l "^CONFIG_PACKAGE_dnsmasq=y$" configs/*.config | wc -l
```

Expected: ~1071 (matches previous worktree count).

- [ ] **Step 3: Run the flip**

```bash
./scripts/flip-dnsmasq-full.sh
```

Expected output: `Flipped: 1071 files` (or close).

- [ ] **Step 4: Verify**

```bash
grep -l "^CONFIG_PACKAGE_dnsmasq-full=y$" configs/*.config | wc -l  # should equal flipped count
grep -l "^CONFIG_PACKAGE_dnsmasq=y$"      configs/*.config | wc -l  # should be 0
```

- [ ] **Step 5: Commit**

```bash
git add configs/ scripts/flip-dnsmasq-full.sh
git commit -m "feat(configs): flip all routers from dnsmasq to dnsmasq-full"
```

---

# Phase 8: CI workflow + release checklist + aux-repo seed

### Task 8.1: Create/update CI workflow for shellcheck + bats

**Files:** `.github/workflows/test.yml`

- [ ] **Step 1: Check if file exists**

```bash
ls .github/workflows/test.yml 2>&1
```

- [ ] **Step 2: Write workflow**

If the file doesn't exist, create it:
```yaml
name: Test
on:
  push:
    branches: [main, "feat/**"]
  pull_request:
    branches: [main]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update && sudo apt-get install -y shellcheck
      - run: shellcheck files/usr/sbin/vipin-video-domains
      - run: shellcheck files/etc/init.d/vipin-video

  bats:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update && sudo apt-get install -y bats
      - run: bats tests/bats/test_vipin_video_domains.bats
```

If it exists already, add the shellcheck + bats jobs for `vipin-video-domains` and `tests/bats/test_vipin_video_domains.bats`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/test.yml
git commit -m "ci: shellcheck + bats for video_direct"
```

### Task 8.2: Create aux-repo seed content

**Files:**
- Create `aux-repo-seed/README.md`
- Create `aux-repo-seed/domains.txt`

- [ ] **Step 1: Write aux README**

`aux-repo-seed/README.md`:
```markdown
# openwrt-2026-video-domains

Domain list consumed by the `video_direct` feature in
[openwrt-2026](https://github.com/vipinus/openwrt-2026).
The firmware fetches `domains.txt` via weekly cron.

## File

- `domains.txt` — one domain per line; `#` for comments.
  Matches parent-domain and all subdomains via dnsmasq-full nftset.

## Contributing

Domains must be **pure CDN / segment streaming endpoints**.
Do NOT add API, login, manifest, or DRM domains — they will cause
geo-restriction errors when direct-routed. Verify with `dig` + traffic
capture before opening a PR.

Examples of what goes in:
- `bilivideo.com` (Bilibili segment CDN)
- `nflxvideo.net` (Netflix OCA)
- `apdcdn.tc.qq.com` (Tencent Video APD CDN)

Examples of what does NOT belong:
- `netflix.com` (control plane, would break login)
- `v.qq.com` (API, would return geo-blocked manifest)

## License

MIT.
```

- [ ] **Step 2: Write the seed domains.txt**

`aux-repo-seed/domains.txt`:
```
# openwrt-2026 video_direct — curated domain list
# Updated: 2026-04-16
# Format: one domain per line; # for comments; dnsmasq matches subdomains

# --- netflix (14) ---
netflix.ca
netflix.com.edgesuite.net
netflix.net
netflixdnstest10.com
netflixdnstest6.com
netflixdnstest7.com
netflixdnstest8.com
netflixdnstest9.com
nflxext.com
nflximg.com
nflximg.net
nflxsearch.net
nflxso.net
nflxvideo.net

# --- bilibili (14) ---
bilicdn1.com
bilicdn2.com
bilicdn3.com
bilicdn4.com
bilicdn5.com
biliimg.com
bilivideo.cn
bilivideo.com
bilivideo.net
hdslb.com
hdslb.org
maoercdn.com
mincdn.com
upos-hz-mirrorakam.akamaized.net

# --- iqiyi (11) ---
71.am
71edge.com
iq.com
iqiyipic.com
msg.video.qiyi.com
msg2.video.qiyi.com
pps.tv
ppsimg.com
qiyi.com
qiyipic.com
qy.net

# --- youku (7) ---
cibntv.net
e.stat.ykimg.com
kumiao.com
mmstat.com
p-log.ykimg.com
soku.com
ykimg.com

# --- tencent (2) ---
apdcdn.tc.qq.com
ltsxmty.gtimg.com
```

- [ ] **Step 3: Commit**

```bash
git add aux-repo-seed/
git commit -m "feat(video): aux-repo-seed content (README + 48-domain list)"
```

### Task 8.3: Create release checklist

**Files:** `docs/release-checklists/video-direct-v2.md`

- [ ] **Step 1: Write the checklist**

```markdown
# Release Checklist: video_direct v2

**Spec:** `docs/superpowers/specs/2026-04-16-video-direct-redo-design.md`
**Plan:** `docs/superpowers/plans/2026-04-16-video-direct-redo.md`

## Pre-flight

- [ ] CI green on the tagged commit
- [ ] `domains.txt` published to `github.com/vipinus/openwrt-2026-video-domains`
- [ ] Raw URL reachable from a test router (`curl -I ...`)
- [ ] Firmware built for at least one device (e.g. GL.iNet MT300N-V2 or ASUS RT-AC68U)

## Scenario matrix

| # | Scenario | Expected | Actual | Pass/Fail |
|---|---|---|---|---|
| 1 | First boot, no prior refresh | Feature inactive, status "never" | | |
| 2 | Manual LuCI refresh button | Status updates, remote_count populates | | |
| 3 | Bilibili playback, forward mode | Smooth; `vipin-video-domains show-set` contains `upos-*.bilivideo.com` IPs | | |
| 4 | Tencent Video playback | Smooth; set contains 223.x.x.x IPs | | |
| 5 | Netflix login + play | Login works; playback uses tunnel or direct depending on route | | |
| 6 | LuCI add local domain | Appears in panel; entry in `/etc/vipin/video-domains.local` | | |
| 7 | LuCI remove local domain | Entry gone; nft set refills on next DNS | | |
| 8 | Switch to reverse mode | Panel greyed; warning shown; `@vipin_video` rule absent from nft | | |
| 9 | VPN disconnect mid-playback | No crash; graceful degradation | | |
| 10 | Router reboot | Feature reactivates on boot; set repopulates after first DNS query | | |
| 11 | Weekly cron fires | `video_last_refresh` updates | | |
| 12 | GitHub unreachable at cron | Old `remote` preserved; log entry | | |

## Post-install smoke

```sh
uci get vipin.vpn.video_direct             # expect: 1
/usr/sbin/vipin-video-domains status       # expect: enabled / forward / counts
/usr/sbin/vipin-video-domains list | head  # expect: tagged domains
nft list set inet fw4 vipin_video          # expect: declared (size 65536)
```

Then play Bilibili for 30s:

```sh
nft list set inet fw4 vipin_video | grep -c "\.,\|elements"
# expect: >1 element after DNS queries
```

## Sign-off

- Tested by: ___________
- Date: ___________
- Device model(s): ___________
- Notes: ___________
```

- [ ] **Step 2: Commit**

```bash
git add docs/release-checklists/video-direct-v2.md
git commit -m "docs: release checklist for video_direct v2"
```

---

# Phase 9: Final verification

### Task 9.1: Full test run from clean state

- [ ] **Step 1: Run shellcheck on all shipped shell**

```bash
shellcheck files/usr/sbin/vipin-video-domains files/etc/init.d/vipin-video
```
Expected: clean.

- [ ] **Step 2: Run all bats tests**

```bash
bats tests/bats/test_vipin_video_domains.bats
```
Expected: `30 tests, 0 failures` (count will match total after Phase 1).

- [ ] **Step 3: Lua syntax check for controller and views**

```bash
luac -p files/usr/lib/lua/luci/controller/vpn.lua
for f in files/usr/lib/lua/luci/view/vpn/i18n/*.lua; do
    luac -p "$f" || echo "SYNTAX ERROR: $f"
done
```
Expected: no output (all files parse clean).

- [ ] **Step 4: Grep for any TODO / TBD / placeholder left**

```bash
grep -rn "TODO\|TBD\|FIXME" files/ tests/ docs/superpowers/ | grep -v "^Binary"
```
Expected: zero matches (or only pre-existing ones from main, not introduced by this plan).

- [ ] **Step 5: Commit any fixes**

If step 4 surfaces issues, fix them and commit.

### Task 9.2: Create PR ready for review

- [ ] **Step 1: Push branch**

```bash
git push -u origin feat/video-direct-v2
```

- [ ] **Step 2: Create PR**

```bash
gh pr create --title "feat: video_direct v2 (redo on current main)" --body "$(cat <<'EOF'
## Summary
- Rebuild video_direct feature on top of current main, replacing the drifted 2026-04-10 worktree implementation.
- Two-source domain model: curated GitHub domains.txt + user-editable local list. No build-time baking, no API blacklist.
- Forward-mode only; reverse mode hard-disables the feature.

## Spec & Plan
- Spec: docs/superpowers/specs/2026-04-16-video-direct-redo-design.md
- Plan: docs/superpowers/plans/2026-04-16-video-direct-redo.md

## Test plan
- [ ] CI: shellcheck clean, bats 30/30 passing
- [ ] Flash one device, verify release checklist (docs/release-checklists/video-direct-v2.md)
- [ ] Publish aux-repo-seed/domains.txt to github.com/vipinus/openwrt-2026-video-domains before first flash

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Out-of-plan follow-ups (track elsewhere)

- **Orphan worktree cleanup:** the old `openwrt-2026-video-direct` worktree has an invalid gitdir pointer. Once v2 merges, remove that directory entirely.
- **Embedded GitHub token:** `.git/config` in the main repo has a token in the remote URL. Replace with a credential helper before the token expires or leaks.
- **Aux repo creation:** the GitHub repo `vipinus/openwrt-2026-video-domains` must exist with `domains.txt` at `main/domains.txt` before the first router calls `refresh` in production. Copy from `aux-repo-seed/`.
