# Router-side hysteria2 migration

## Status
draft — package config refactored, init.d/runtime not yet touched.

## Why

Today's router VPN data plane is `stunnel(TCP) + tun2socks(SOCKS5/TCP)`.
That nests TCP-in-TCP across the GFW border, which is the textbook HoL
blocking trap: an outer TCP retransmit causes an inner TCP retransmit
which in turn causes another outer TCP retransmit. On 5%+ loss links
throughput collapses to single-digit-percent of native.

We just deployed hysteria2 (QUIC + Brutal congestion + salamander obfs)
end-to-end on the **server side** (cn2 ↔ jp1-4). Tests confirmed UDP/8443
[ASSURED] across all 4 jp paths, ocserv users on cn2 see immediate fluency.

The remaining bottleneck is the **router-side** stunnel client (router →
upstream :22/:995) which still uses TCP-over-TCP. Goal: replace it with a
hysteria2 client on the router so the router-to-jp leg is also QUIC.

## Constraint

GL-MT300N-V2 is the primary target — 16 MB flash, 64 MB RAM, mt7628 (mips
LE, mips24kec). Hysteria2 mipsle binary is 21 MB raw, ~7 MB UPX-compressed.
With current firmware overlay only 2.6 MB free, the binary does not fit
without removing other software from squashfs.

## What gets removed

| Package | Binary size | Reason |
|---|---|---|
| `dnscrypt-proxy2` | 15.3 MB (Go binary) | DNS resolution moves into hysteria's tunnel |
| `stunnel` | 266 KB | Replaced by hysteria2 transport |

**Net flash saved**: ~15.6 MB after squashfs rebuild → 7 MB hysteria2 fits
with margin of ~8 MB. Real-world available overlay rises from 2.6 MB to
roughly 10 MB.

## What stays

- `hev-socks5-tunnel` — TUN-to-SOCKS5 gateway. Hysteria2 client exposes a
  local SOCKS5 listener; hev-socks5-tunnel still bridges TUN packets into
  that SOCKS5. No replacement needed.
- `openssl-util` — used by acme/cert tooling and other scripts; not on the
  hot path.
- `dnsmasq` — unchanged, but its forwarder switches from 127.0.2.1
  (dnscrypt) to a target reachable over the new hysteria2 tunnel.

## DNS path after migration

```
LAN client → dnsmasq → forward to upstream-DNS over hysteria2 tunnel → resolved IP
```

Concretely, dnsmasq forwards to a DNS endpoint reachable through the
hysteria2 SOCKS5 listener. Two reasonable choices:

1. **Tunnel TCP DNS to a CN-friendly resolver** (e.g. 223.5.5.5:53 over TCP
   exposed as a hysteria2 `tcpForwarding` rule). Simple but resolver isn't
   itself encrypted; depends on hysteria2 tunnel for confidentiality.
2. **DoH inside the tunnel** — point dnsmasq at a local DoH proxy (e.g.
   `https-dns-proxy`, ~150 KB) which resolves via DoH over the hysteria2
   tunnel. Cleaner, but adds another small binary.

Pick option 1 first; revisit if leak tests demand DoH.

## Init.d changes (deferred to next commit)

Today's `vipin-vpn` (init.d) starts: stunnel client → hev-socks5-tunnel.
After migration: hysteria2 client → hev-socks5-tunnel. The auth flow
(`fetch_auth_params`, `extract_ca_cert`, etc.) must be rewritten because
hysteria2 uses a different credential model (PSK + cert pinning, no
per-session CA fetch). Defer until binary distribution path is solved
(see below).

## Binary distribution

Hysteria2 binary (~7 MB UPX-compressed mipsle) needs to land in the
firmware. Three options:

1. **Bake into squashfs** — copy `files/usr/bin/hysteria` into the build
   tree. Pro: works offline; Con: git repo grows by 7 MB, not LFS-friendly.
2. **Download at build time** — `local-build.sh` and CI
   (`.github/workflows/build.yml`) fetch the binary from GitHub releases,
   UPX-compress, drop into `custom-files/usr/bin/` before `make image`.
   Pro: keeps git small. Con: build needs network access.
3. **First-boot download** — uci-defaults script fetches the binary on
   first boot. Con: extra dependency, fails on offline routers.

Pick option 2. The build script already fetches `direct.txt` and
`dnscrypt-resolvers.md` from upstream at build time, so adding hysteria
download is consistent with the existing pattern.

## Migration order

1. **This commit**: package config refactor (this doc + remove stunnel +
   dnscrypt-proxy2 from `configs/*.config`). Firmware build still needs
   `vipin-vpn` rewrite to actually start hysteria2; without that the
   firmware boots without VPN. Mark as breaking change.
2. **Next commit**: build-time hysteria binary fetch + UPX in
   `local-build.sh` and `build.yml`.
3. **Next commit**: rewrite `files/etc/init.d/vipin-vpn` to start hysteria2
   client + hev-socks5-tunnel; update `files/etc/vipin/` config templates.
4. **Next commit**: dnsmasq DNS forwarder reconfigure (point at upstream
   reachable through tunnel; remove dnscrypt include).

## Rollback

`git revert <commit>` flips package list back. The previous firmware (still
flashed on existing routers) is unaffected by repo changes. New flashes
after this PR but before init.d rewrite would boot without VPN — do not
flash production routers from this commit alone.

## Owner verdict

This commit alone does **not** ship working firmware — it's the package
plumbing change in service of a 4-commit migration. Reading this without
the follow-up commits will look incomplete; that's intentional.
