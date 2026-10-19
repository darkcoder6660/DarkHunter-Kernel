# Injection Module — Live Test Results (2026-10-17)

Module under test: `qca_cld3_kiwi_v2.ko` (patched, md5 `2c5af6d1d298b72dfd5f6f7833ad4819`)
Deployed at: `/vendor_dlkm/lib/modules/qca_cld3_kiwi_v2.ko` (inside flashed `vendor_dlkm_INJECTION_v3.img`)
Device: OnePlus Pad 2 (OPD2403 / caihong), slot b, KernelSU, SELinux permissive
Test tooling: `iw` (Android), scapy 2.7.01 + aircrack-ng 1.7 inside NetHunter chroot (`/data/local/nhsystem/kali-arm64`)

## Verdict

| Test | Result |
|---|---|
| Monitor mode interface (`iw phy phy0 interface add mon0 type monitor`) | PASS |
| Monitor channel control (set ch 6 / ch 36) | PASS |
| Monitor RX (live radiotap capture: CTS/BlockACK/data/beacons + RSSI) | PASS |
| Injection 2.4 GHz (ch 6) — scapy probe test | PASS — 5 responses, 1 AP answered injected probes |
| Injection 2.4 GHz (ch 6) — `aireplay-ng --test` | PASS — "Injection is working!", 29/30 = 96%, ping 5.9/13.2/31.5 ms |
| Injection 5 GHz (ch 36 / 5180 MHz) — `aireplay-ng --test` | PASS — "Injection is working!", 30/30 = 100% and 29/30 = 96%, ping 3.2/6.9/9.1 ms |

Patched module loaded and active: `injection_dp_inflight_limit = 4`.

## How to reproduce

```sh
# 1. disable STA (radio lock: monitor channel can only be set with STA down)
svc wifi disable; sleep 5

# 2. create monitor interface
iw phy phy0 interface add mon0 type monitor
ip link set mon0 up
iw dev mon0 set channel 6          # or 36 etc.

# 3. injection test (chroot)
chroot /data/local/nhsystem/kali-arm64 /usr/bin/env -i \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  aireplay-ng --test mon0

# 4. TEARDOWN — delete mon0 BEFORE re-enabling WiFi (order matters)
ip link set mon0 down
iw dev mon0 del
svc wifi enable
```

## Operational notes

- **Always delete `mon0` before `svc wifi enable`.** Doing them in the other order
  (STA bring-up while monitor vdev alive) was followed by a spontaneous device
  reboot. With clean teardown, repeated test cycles left the device stable.
- First `iw dev mon0 set channel X` right after `svc wifi disable` may race the STA
  teardown; if it returns `Device or resource busy (-16)`, wait a few seconds and retry.
- `txpower` reports `0.00 dBm` on the monitor vdev in `iw dev` — cosmetic; TX works
  (proven by AP responses + aireplay stats).
- Reboots observed at 21:43–21:56 were soft ("reboot" reason, one boot tagged
  `fastboot`, empty pstore, no oops in logcat kernel buffer) — no kernel-panic
  evidence. Current boot stable, reboot history unchanged after final test cycles.
- Pre-existing benign boot warnings (NOT from the patched module):
  `Unbalanced enable for IRQ xx` (display, comm `crtc_commit`), stock cnss2
  `ASSERT line 1178` (DMS MAC not supported), firmware `-13` direct-load
  fallbacks (ueventd fallback succeeds).
