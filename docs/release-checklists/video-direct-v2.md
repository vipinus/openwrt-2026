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
nft list set inet fw4 vipin_video | grep "elements =" | tr ',' '\n' | wc -l
# expect: >1 element after DNS queries
```

## Known limitations

- 13 of 17 locales (ko, de, fr, es, pt, ru, ar, fa, hi, id, vi, th, tr) show English strings for video_direct — native translations deferred to P1.
- Netflix OCA direct-path success rate is empirical (~60-80% per social reports). Users seeing failures should disable via LuCI.
- DoH/DoT clients bypass dnsmasq entirely and therefore the feature. Expected behavior.
- Reverse mode force-disables the feature. Override via `uci set vipin.vpn.video_direct_force_reverse=1` is undocumented and not supported.
- IPv6 video streams are not handled (main already kills IPv6 globally).
- The `vipin_video` set accumulates IPs across weekly refresh windows (65536 cap); routine accumulation is acceptable.

## Sign-off

- Tested by: ___________
- Date: ___________
- Device model(s): ___________
- Notes: ___________
