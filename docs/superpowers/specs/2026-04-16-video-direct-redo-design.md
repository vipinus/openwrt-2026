# Video Direct (v2 Redo) — Design Spec

**Date:** 2026-04-16
**Status:** Draft — pending user review
**Supersedes:** `docs/superpowers/specs/2026-04-10-video-direct-bypass-design.md`
**Area:** `files/` firmware overlay; new shell script; LuCI UI; 1071 router configs (dnsmasq → dnsmasq-full).

## 1. Problem Statement

CN users connecting to the VPN for overseas browsing waste tunnel bandwidth on video CDN traffic (Netflix, Bilibili, iQiyi, Youku, Tencent). These streams are bandwidth-heavy, region-tolerant for their segment CDNs, and can egress directly via the local WAN. The goal is to identify video CDN IPs dynamically and route them out via WAN, keeping tunnel bandwidth for latency-sensitive flows.

This spec is a **redo** of the 2026-04-10 design after the `main` branch absorbed 15+ commits (atomic `vipin_domestic` flush, global IPv6 kill, dynamic DNS upstream via dnsmasq UCI server, self-heal cert pin, LuCI connect button + status polling, UCI `base_domain`/`site_url` refactor). The original video-direct worktree drifted beyond practical merge. This design rebuilds the feature on top of current `main` with a simplified data model.

## 2. Scope

### In Scope
- New nftables set `vipin_video` parallel to existing `vipin_domestic`, populated at DNS-resolution time by dnsmasq-full `nftset=` directive.
- **Two-source domain list**: a single `domains.txt` fetched from a self-maintained GitHub repo + a user-editable `/etc/vipin/video-domains.local` on the router.
- **Forward split-tunnel mode only.** Reverse mode force-disables the feature (geographic inversion makes CN-CDN direct routing incorrect for overseas users).
- Three refresh triggers: `init.d` enable on boot (no network required), weekly cron `refresh`, and LuCI manual "refresh" button.
- UCI options `vipin.vpn.video_direct` (default `1`) and `vipin.vpn.video_last_refresh` (unix timestamp).
- LuCI UI: toggle, status badge, remote/local domain counts, nft set IP count, last-refresh timestamp, manual refresh button, local-domain add/remove.
- 17-language i18n for all new UI strings.
- All 1071 `configs/*.config` bumped from `dnsmasq` to `dnsmasq-full`.
- Bats test coverage for all script logic.

### Out of Scope
- **Build-time domain baking.** No `.github/workflows/fetch-video-domains.py`, no `video-domains.baked.conf`. First-boot behavior: empty remote until first successful refresh (cron or manual).
- **API-domain blacklist.** The owner curates the GitHub list; the user curates their local list. No automated filter — geo-leak prevention is owner responsibility, not code responsibility.
- **v2fly community list consumption at runtime.** The owner may pull v2fly content into the GitHub `domains.txt` manually as part of curation, but the router only sees the single curated URL.
- **YouTube / Google** (causes Google-wide side effect; list owner should not include).
- **Reverse-mode support.**
- **IPv6.** (`vipin_video` is IPv4-only; `main` already disables IPv6 globally — `6fcf5e8`.)
- **Per-platform independent toggles** (single master switch).
- **Auto-detection of Netflix OCA failure.**
- **4MB-flash routers** (dnsmasq-full adds ~200KB; assume modern targets; existing `configs/` target set is already modern).

## 3. Design Principles

1. **Orthogonality.** `video_direct` is independent of `split_tunnel` and `split_mode`. The feature composes with existing behavior; disabling it leaves all other behavior unchanged.
2. **Fail-safe.** Any failure in the video-direct subsystem degrades gracefully to tunneled video. It must never break basic connectivity or VPN.
3. **DNS-first.** The set is populated exclusively at DNS-resolution time by dnsmasq-full. No packet inspection, no background learner daemon, no geoip lookup.
4. **Owner responsibility.** No in-code API blacklist. The owner's GitHub `domains.txt` and the user's `local` file are each the responsibility of whoever maintains them. A mistaken entry (e.g. `netflix.com`) is corrected by the maintainer, not the code.
5. **Minimum main drift.** Two substantive script edits (`vipin-vpn-routing` for the set + mark rule, `/etc/config/vipin` for two UCI options). LuCI edits are purely additive (new panel in `vpn.lua` + `settings.htm` + i18n keys in 17 locale files). `configs/*.config` bulk-flips `dnsmasq` → `dnsmasq-full` (mechanical, one line per config). No other file in `main` is touched.
6. **Idempotent triggers.** Boot / cron / LuCI button all converge on the same `enable` function. `enable` is network-free; only `refresh` hits the network.
7. **Transparency.** LuCI exposes every domain currently in the merged list and the current nft set size, so the user can audit routing at any time.

## 4. Architecture

### 4.1 Topology

```
┌────────────────────────── Runtime (on router) ──────────────────────────┐
│                                                                         │
│  GitHub raw (domains.txt)                                               │
│         │  curl (weekly cron / LuCI button)                             │
│         ▼                                                               │
│  /etc/vipin/video-domains.remote    ←── owner-maintained (fetched)      │
│  /etc/vipin/video-domains.local     ←── user-maintained (via LuCI)      │
│         │                                                               │
│         │  merge + dedup + basic format validation                      │
│         ▼                                                               │
│  /etc/dnsmasq.d/vipin-video.conf                                        │
│     nftset=/netflix.ca/4#inet#fw4#vipin_video                           │
│     nftset=/bilivideo.com/4#inet#fw4#vipin_video                        │
│     ...                                                                 │
│         │                                                               │
│         ▼   (dnsmasq-full atomically adds A-record IP to nft set)       │
│  nft set inet fw4 vipin_video { ipv4_addr elements }                    │
│         │                                                               │
│         │   vipin-vpn-routing prerouting rule                           │
│         │   ip daddr @vipin_video mark set 0x200                        │
│         ▼                                                               │
│  fwmark 0x200 → ip rule → table 101 (WAN default route)                 │
│         │                                                               │
│         ▼                                                               │
│     client video packets → WAN directly (bypassing tun)                 │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 File Layout (additive to `main`)

**New files:**

```
files/etc/config/vipin                       # +2 options (edit)
files/etc/init.d/vipin-video                 # procd init, START=91
files/etc/crontabs/root                      # +1 line (weekly refresh)
files/etc/vipin/video-domains.local          # empty placeholder
files/usr/sbin/vipin-video-domains           # main runtime script (~180 lines)
files/usr/sbin/vipin-vpn-routing             # +8 lines (edit: set + mark rule)
files/usr/lib/lua/luci/controller/vpn.lua    # +40 lines (edit: 5 RPC actions)
files/usr/lib/lua/luci/view/vpn/settings.htm # +60 lines (edit: panel + JS)
files/usr/lib/lua/luci/view/vpn/i18n/*.lua   # +15 keys × 17 langs (edit)

tests/bats/test_vipin_video_domains.bats     # bats coverage

configs/*.config × 1071                      # dnsmasq → dnsmasq-full (bulk edit)
```

**No longer needed** (present in `2026-04-10` worktree, discarded here):

- `.github/workflows/fetch-video-domains.py`
- `.github/workflows/patches/`
- `.github/workflows/test.yml` changes specific to Python tests
- `files/etc/vipin/video-domains.baked.conf`
- `files/etc/hotplug.d/iface/99-vipin-video` (no hotplug; cron + boot + manual cover it)
- `aux-repo-seed/` (no separate aux repo; just one curated file in one repo)
- `tests/python/` for video (no Python build script to test)

## 5. Runtime Data Flow

### 5.1 Triggers

| Trigger | Action | Network? |
|---|---|---|
| Boot (init.d `vipin-video start`) | `vipin-video-domains enable` | No |
| Weekly cron (Sunday 04:00 local) | `vipin-video-domains refresh` | Yes |
| LuCI "Refresh" button | RPC `video_refresh` → `vipin-video-domains refresh` | Yes |
| LuCI toggle ON | `vipin-video-domains enable` | No |
| LuCI toggle OFF | `vipin-video-domains disable` | No |
| LuCI add/remove local domain | `vipin-video-domains add <d>` / `remove <d>` + `enable` | No |

### 5.2 `enable` (network-free, idempotent)

1. Read `uci get vipin.vpn.video_direct`; if not `1`, call `disable` and exit.
2. Read `uci get vipin.vpn.split_mode`; if not `forward`, log, call `disable` and exit.
3. `merge()` = `parse_list(remote) ∪ parse_list(local)` — dedup via `awk '!seen[$0]++'`.
4. `render_dnsmasq()` writes `/etc/dnsmasq.d/vipin-video.conf.new` with one `nftset=/DOMAIN/4#inet#fw4#vipin_video` line per domain, plus a header comment.
5. Atomic: `mv .new /etc/dnsmasq.d/vipin-video.conf`.
6. `/etc/init.d/dnsmasq restart` (best-effort; log on failure).
7. `vipin-vpn-routing reload` — this ensures the `vipin_video` set declaration and the prerouting mark rule are in place (idempotent).

### 5.3 `refresh` (network-dependent)

The GitHub raw URL is **hardcoded** at the top of `vipin-video-domains` as a constant (default: `https://raw.githubusercontent.com/vipinus/openwrt-2026-video-domains/main/domains.txt`). Overridable at runtime via `uci get vipin.vpn.video_url` for development and mirror use; the UCI option is not exposed in LuCI v2.

1. Acquire file lock (`/var/lock/vipin-video.lock`); bail after 60s.
2. Read URL: `URL=$(uci get vipin.vpn.video_url 2>/dev/null || echo "$DEFAULT_URL")`.
3. `curl -sSL --max-time 10 --retry 1 "$URL" -o /tmp/video-domains.remote.new`.
4. If curl failed OR output empty → log, release lock, exit 1 (old `remote` preserved).
5. `mv /tmp/video-domains.remote.new /etc/vipin/video-domains.remote`.
6. `uci set vipin.vpn.video_last_refresh=$(date +%s) && uci commit vipin`.
7. Call `enable`.
8. `nft flush set inet fw4 vipin_video` — clears accumulated stale IPs. Next DNS hit for a still-listed domain repopulates it via dnsmasq-full.
9. Release lock.

### 5.4 `disable`

1. `rm -f /etc/dnsmasq.d/vipin-video.conf`.
2. `/etc/init.d/dnsmasq restart`.
3. `nft flush set inet fw4 vipin_video 2>/dev/null || true`.
4. `vipin-vpn-routing reload` (to remove the mark rule; handled inside `vipin-vpn-routing` when `video_direct != 1`).

### 5.5 Concurrency

All write paths (`enable`, `disable`, `refresh`, `add`, `remove`) acquire the same file lock before touching `/etc/vipin/video-domains.*` or `/etc/dnsmasq.d/vipin-video.conf`. Lock timeout is 60s with a 120s stale-lock sweep (same pattern as the 2026-04-10 implementation — proven idiom).

## 6. Integration with `main`

### 6.1 `vipin-vpn-routing` patch (~8 lines)

Add near `enable_split()`, after `vipin_domestic` set declaration:

```sh
nft add set inet fw4 vipin_video { type ipv4_addr\; flags interval\; size 65536\; } 2>/dev/null || true
```

In the `forward` branch of the prerouting chain builder, immediately after the line that adds `ip daddr @vipin_domestic mark set 0x200 return`, check UCI:

```sh
if [ "$(uci get vipin.vpn.video_direct 2>/dev/null || echo 1)" = "1" ]; then
    echo "add rule inet fw4 vipin_prerouting ip daddr @vipin_video mark set 0x200" >> "$batch"
fi
```

In `disable_split()` / `reverse` branch: do NOT add the video rule. The set declaration remains (empty, no effect) — harmless.

**Rationale:** the `vipin_video` mark piggy-backs on the existing `0x200` = "direct via WAN" mark. No new mark, no new routing table, no new `ip rule`. Zero additional blast radius.

### 6.2 UCI schema (`/etc/config/vipin`)

Add to existing `config vpn 'vpn'` section:

```
    option video_direct '1'
    option video_last_refresh ''
```

(The `video_refresh_interval` option from the 2026-04-10 spec is dropped — cron expression is baked into `/etc/crontabs/root`, user can edit cron directly if needed.)

### 6.3 LuCI controller (`vpn.lua`) RPC actions

Five new entries, all under the existing `/vpn/` RPC namespace:

| Action | Input | Output | Calls |
|---|---|---|---|
| `video_status` | — | JSON: `{enabled, split_mode, remote_count, local_count, set_count, last_refresh}` | `vipin-video-domains status` |
| `video_refresh` | — | JSON: `{success, message}` | `vipin-video-domains refresh` (timeout 30s via uhttpd) |
| `video_add` | `domain` | JSON: `{success, message}` | `vipin-video-domains add <d>` |
| `video_remove` | `domain` | JSON: `{success, message}` | `vipin-video-domains remove <d>` |
| `video_toggle` | `enabled` (0/1) | JSON: `{success}` | `uci set vipin.vpn.video_direct=<x>` + `enable`/`disable` |

**Timeout budget:** `refresh` does one curl with `--max-time 10`, plus dnsmasq restart (~2-3s). Worst case 15s. Comfortably under uhttpd's default 60s LuCI timeout.

### 6.4 LuCI view (`settings.htm`)

A new collapsible panel "视频直连 / Video Direct" added below the existing VPN controls.

Panel contents:
- Toggle switch (bound to `video_direct` UCI option; calls `video_toggle` RPC).
- Status line: `remote 48 / local 3 / set 412 IPs / refreshed 2026-04-16 04:02`.
- "Refresh now" button (calls `video_refresh`, shows spinner, updates status on return).
- Local domain table: each row is a domain + delete button.
- Add-local input: text field + "Add" button. Client-side format check + server-side re-check.
- Warning banner when `split_mode=reverse`: panel is grayed out, shows explainer text.

Polling: the panel polls `video_status` every 10s while open (matches main's existing connect-status polling cadence).

### 6.5 i18n keys (17 languages)

New keys to add to each of `files/usr/lib/lua/luci/view/vpn/i18n/{en,zh-CN,zh-TW,ja,ko,de,fr,es,pt,ru,ar,fa,hi,id,vi,th,tr}.lua`:

```
video_direct_title, video_direct_desc, video_direct_enable,
video_status_remote, video_status_local, video_status_set, video_status_last_refresh, video_status_never,
video_refresh_button, video_refresh_success, video_refresh_fail,
video_local_add, video_local_placeholder, video_local_remove,
video_reverse_warning
```

15 keys × 17 languages = 255 translation entries. English is authoritative; other languages can be machine-translated initially and refined iteratively.

## 7. Error Handling

| Scenario | Behavior |
|---|---|
| First boot, no internet | `enable` reads empty `remote` + empty `local` → writes empty dnsmasq include → feature silently inactive. Status: "never synced". |
| Cron refresh fails (GitHub unreachable) | Old `remote` preserved. `video_last_refresh` NOT updated. Log entry. No degradation of currently-active set. |
| dnsmasq restart fails | Log entry. Previous dnsmasq config remains active (dnsmasq reload is graceful). Feature degrades to tunneled video until next successful restart. |
| User adds malformed domain (`foo..com`, `-foo`) | Rejected by `validate_domain` (same regex as 2026-04-10: `*[!a-z0-9.-]*`, `..`, leading/trailing `-` or `.`). LuCI shows error. |
| User enables video_direct under `split_mode=reverse` | Toggle writes UCI; `enable` detects and calls `disable`; panel shows warning banner. No silent success. |
| nft set already exists with different spec | `nft add set` with the same spec is idempotent; with a different spec would fail. We control the spec string, so no conflict in practice. |
| Cron + LuCI refresh race | File lock serializes. Second caller waits up to 60s then aborts with log entry. |
| User clicks "refresh" during cron refresh | Same lock — LuCI returns `{success: false, message: "refresh in progress"}`. User retries. |
| `video_direct=1` but `vipin_video` set empty (fresh install, never refreshed) | Mark rule exists but matches nothing → all video goes through VPN tunnel (same as feature-off behavior). Zero harm. |
| `vipin_video` set accumulates >65535 elements over weeks | Set declared with `size 65536`. Overflow elements silently dropped. Weekly `flush` on refresh resets. |

## 8. Testing

### 8.1 Bats (`tests/bats/test_vipin_video_domains.bats`)

| Test group | Cases |
|---|---|
| `parse_list` | comments stripped, blanks skipped, lowercase, whitespace trimmed |
| `merge` | dedup, local overrides order irrelevant (set semantics) |
| `validate_domain` | accepts `a.b.c`, rejects `a..b`, `-a.b`, `a.`, `foo`, `foo$`, empty |
| `render_dnsmasq` | correct `nftset=/D/4#inet#fw4#vipin_video` format, header present |
| `enable` (MOCK) | writes dnsmasq include, does not call `/etc/init.d/dnsmasq` |
| `disable` (MOCK) | removes dnsmasq include |
| `add` | appends to local, refuses duplicate, calls enable |
| `remove` | deletes from local, idempotent if absent |
| `refresh` (MOCK curl) | success writes remote, failure keeps old remote, updates last_refresh only on success |
| `split_mode=reverse` | `enable` no-ops via disable path |
| `video_direct=0` | `enable` no-ops via disable path |

Test hooks via env vars: `VIPIN_VIDEO_ROOT` (chroot-like path prefix), `VIPIN_VIDEO_MOCK=1` (skip dnsmasq/nft/uci calls). Same idiom as 2026-04-10.

### 8.2 CI workflow

Extend or rewrite `.github/workflows/test.yml` to run: `shellcheck files/usr/sbin/vipin-video-domains && bats tests/bats/test_vipin_video_domains.bats`.

Python tests are not part of v2 (no Python runtime script). If other Python tests exist in the repo they remain untouched.

### 8.3 Manual device testing

A release checklist document (`docs/release-checklists/video-direct-v2.md`) covers:
- Netflix (overseas user with US VPN): login/browse/play all work.
- Bilibili 1080P playback: smooth, `vipin-video-domains show-set` contains `upos-*.bilivideo.com` IPs.
- Tencent Video playback: smooth, set contains Tencent CDN IPs (223.x.x.x class).
- Reverse mode: panel grayed, rule absent from nft.
- LuCI refresh: RPC completes <15s, updates status.
- Router reboot: panel remembers state, feature reactivates after VPN up and first DNS query.
- VPN disconnect during playback: no crash, degrades to WAN-only (if user has WAN DNS) or stops cleanly.

## 9. Security & Abuse Considerations

- **SSRF via local domain input:** user-supplied domains are only used as dnsmasq match patterns, never as URLs. No SSRF surface.
- **Script injection via domain input:** `validate_domain` restricts charset to `[a-z0-9.-]`; shell interpolation is always quoted. No injection surface.
- **Remote list tampering:** the owner's GitHub repo is trusted. If compromised, an attacker could push a domain that causes traffic to leak to WAN. Mitigation is out of v2 scope; assume HTTPS to github.com is trustworthy. Long-term: consider pinning a commit SHA instead of `main` branch raw URL.
- **Runaway set size:** `size 65536` cap in the set declaration prevents nftables from consuming unbounded memory. Weekly flush keeps elements fresh.
- **Lock exhaustion:** 60s lock timeout + 120s stale-lock sweep prevents a wedged process from blocking future operations indefinitely.

## 10. Decisions Explicitly Deferred

- Pinning the GitHub raw URL to a commit SHA rather than `main` branch (trade-off: auto-update vs supply-chain safety).
- IPv6 support.
- Reverse-mode compatibility.
- Per-platform toggles.
- Auto-detection of streaming breakage with fallback to tunnel.
- Mirror list hosting (jsdelivr, ghproxy) for users in regions with GitHub access issues.
- 4MB-flash router support.

## 11. Initial `domains.txt` Content

An initial merged list (48 domains) has been generated by fetching v2fly's `netflix` / `bilibili-cdn` / `iqiyi` / `youku` community lists, filtering out regex entries (dnsmasq nftset does not support regex) and API/login domains, and adding 2 hand-curated Tencent CDN supplements:

```
# netflix (14): netflix.ca, netflix.net, nflxext.com, nflximg.com,
#   nflximg.net, nflxso.net, nflxvideo.net, nflxsearch.net,
#   netflix.com.edgesuite.net, netflixdnstest6..10.com
# bilibili (14): bilicdn1..5.com, biliimg.com, bilivideo.cn/.com/.net,
#   hdslb.com, hdslb.org, maoercdn.com, mincdn.com,
#   upos-hz-mirrorakam.akamaized.net
# iqiyi (11): 71.am, 71edge.com, iq.com, iqiyipic.com, msg.video.qiyi.com,
#   msg2.video.qiyi.com, pps.tv, ppsimg.com, qiyi.com, qiyipic.com, qy.net
# youku (7): cibntv.net, e.stat.ykimg.com, kumiao.com, mmstat.com,
#   p-log.ykimg.com, soku.com, ykimg.com
# tencent (2): apdcdn.tc.qq.com, ltsxmty.gtimg.com
```

Full file is at `/tmp/vipin-fetch/domains.txt` (generated during brainstorming).

Open questions for the list owner (not blocking v2 implementation):
- `msg.video.qiyi.com` / `msg2.video.qiyi.com` — names suggest messaging, not CDN. Verify with traffic capture before leaving in.
- Tencent supplement has only 2 entries — empirically too thin. Plan to expand via packet capture on a real Tencent Video session post-v2.

## 12. Release Criteria

- [ ] All bats tests pass in CI.
- [ ] shellcheck clean on `vipin-video-domains` and `vipin-vpn-routing`.
- [ ] One physical device flashed and smoke-tested (Bilibili playback verified via `show-set`).
- [ ] LuCI panel renders correctly in `en` and `zh-CN` locales.
- [ ] `domains.txt` published to `github.com/vipinus/openwrt-2026-video-domains` (repo name hardcoded in §5.3; if owner chooses a different repo, update the constant in `vipin-video-domains` before release) and raw URL confirmed reachable from a test router.
- [ ] Release checklist (`docs/release-checklists/video-direct-v2.md`) completed and signed.

## 13. Migration from v1 Worktree

This spec REPLACES the 2026-04-10 worktree. Transition plan:

1. Start from a fresh branch off `main` (not the drifted `openwrt-2026-video-direct` worktree).
2. Apply this spec's file additions/edits.
3. Copy over the 48-domain seed list to the new GitHub aux repo.
4. Delete the old worktree once v2 is merged to `main` (or keep it tagged for archaeology).
5. The 2026-04-10 spec + plan remain in git history as reference material but are explicitly superseded.
