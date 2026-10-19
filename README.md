# DarkHunter — NetHunter Kernel for OnePlus Pad 2 (caihong)

Custom **Linux 6.1.174** kernel for the **OnePlus Pad 2** on **PixelOS 16 (Android 16)**, with:

- **Internal Wi-Fi packet injection** — patched Qualcomm `qcacld` loaded from a modified `vendor_dlkm`. **No dongle required.**
- **External USB adapter injection** — AR9271 (`ath9k_htc`) and RTL8188EU/8192EU (`rtl8xxxu`).
- **KernelSU compatible** — root is installed separately in `init_boot`.

> [!WARNING]
> For authorized security testing only. Only use this against networks you own or have written permission to test. You are responsible for your actions.

## Tested on

| | |
|---|---|
| Device | OnePlus Pad 2 — `caihong` (OPD2403) |
| ROM | PixelOS 16.2 — `PixelOS_caihong-16.2-20260621-0702` |
| Kernel | `6.1.174-g638ecc425319-dirty` — build #9 (13 Oct 2026) |
| Root | KernelSU (patched `init_boot`) |
| Slot tested | `b` |

> [!IMPORTANT]
> **Flash only on the PixelOS build above.** The vendor image contains the complete vendor module set from that build. The kernel and `vendor_dlkm` image are a matched pair — flash both from this release. Using them on another ROM build can break Wi-Fi, Bluetooth, audio, or boot.

## Files

| File | Use |
|---|---|
| `darkhunter_boot.img` | Kernel — `fastboot flash boot` |
| `vendor_dlkm-swap/vendor_dlkm_INJECTION_v3.img` | Patched vendor image — flash in **fastbootd** |
| `caihong-wifi-injection-modules.zip` | Optional external-adapter modules |

```
darkhunter_boot.img        38,260,736 bytes
SHA-256 ddfb09284be77e2bf990175a555cc1ed5ce54ae418da21feadbb83ebb70ff337

vendor_dlkm_INJECTION_v3.img   48,828,416 bytes
SHA-256 c565cf431345c35e25cc846a3e75a4ac64631a748f6360903da879152d214a5b
```

## Requirements

- Unlocked bootloader, USB data cable, battery above 50%.
- `adb` / `fastboot` (Android platform-tools).
- Root for backups and the injection scripts (KernelSU recommended).

---

## 1. Back up stock images

```sh
SLOT=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')

# boot
adb shell su -c "dd if=/dev/block/by-name/boot$SLOT of=/sdcard/boot_stock.img bs=4M"
adb pull /sdcard/boot_stock.img

# vendor_dlkm
adb shell su -c "dd if=/dev/block/mapper/vendor_dlkm of=/sdcard/vendor_dlkm_stock.img bs=4M"
adb pull /sdcard/vendor_dlkm_stock.img
```

No root? Extract `boot.img` and `vendor_dlkm.img` from the PixelOS OTA with `payload-dumper-go`.

## 2. Flash the kernel

```sh
adb reboot bootloader
fastboot flash boot darkhunter_boot.img
fastboot reboot
```

## 3. Flash the patched vendor_dlkm

`vendor_dlkm` is a logical partition — it must be flashed in **fastbootd**, not the bootloader.

```sh
adb reboot fastboot
fastboot devices
fastboot flash vendor_dlkm vendor_dlkm-swap/vendor_dlkm_INJECTION_v3.img
fastboot reboot
```

> [!NOTE]
> The image is in `vendor_dlkm-swap/` in this repo. If you downloaded the `.img` on its own, drop the folder prefix in the command above.

## 4. Root (recommended)

Patch your stock `init_boot.img` with the KernelSU app, then:

```sh
adb reboot bootloader
fastboot flash init_boot kernelsu_patched.img
fastboot reboot
```

Root is needed for backups, `setenforce`, the Kali chroot and the auto-load scripts.

## Verify

```sh
adb shell uname -r
# 6.1.174-g638ecc425319-dirty

adb shell su -c 'cat /sys/module/qca_cld3_kiwi_v2/scmversion'
# gec04e4f8d5c9-dirty  ← patched module is active

adb shell su -c 'cat /sys/module/qca_cld3_kiwi_v2/parameters/injection_dp_inflight_limit'
# 4
```

If `scmversion` is missing or shows `g6de5a9c04589`, the stock module is still active — recheck the slot and reflash `vendor_dlkm`.

---

## Internal packet injection (no dongle)

```sh
su
setenforce 0                 # only if your tools are blocked by SELinux

# STA must be off — the radio cannot do STA + monitor at the same time
svc wifi disable
sleep 5

# create monitor interface
iw phy phy0 interface add mon0 type monitor
ip link set mon0 up
iw dev mon0 set channel 6    # 2.4 GHz; use 36 for 5 GHz
iw dev mon0 info

# injection test (from the NetHunter chroot)
chroot /data/local/nhsystem/kali-arm64 /usr/bin/env -i \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  aireplay-ng --test mon0
# → "Injection is working!"

# teardown — ORDER MATTERS
ip link set mon0 down
iw dev mon0 del
svc wifi enable
```

> [!WARNING]
> Delete `mon0` **before** re-enabling Wi-Fi. Re-enabling STA while the monitor interface still exists caused a reboot during testing.

Notes:

- `iw` must be available (`command -v iw`); otherwise use the NetHunter chroot's `iw`.
- If `set channel` returns `-16`, wait a few seconds after `svc wifi disable` and retry.
- 2.4 GHz and 5 GHz are verified; 6 GHz was not tested.

## External USB adapter (optional)

```sh
adb shell mkdir -p /data/local/tmp/wifi
adb push modules/. /data/local/tmp/wifi/
adb shell su -c 'sh /data/local/tmp/wifi/load-modules.sh'

# plug the adapter (OTG) — usually appears as wlan1
airmon-ng start wlan1
aireplay-ng --test wlan1mon    # use the name airmon-ng prints
```

Auto-load on boot:

```sh
adb push scripts/load-wifi-injection.sh /data/local/tmp/
adb shell su -c 'mkdir -p /data/adb/service.d && cp /data/local/tmp/load-wifi-injection.sh /data/adb/service.d/ && chmod 755 /data/adb/service.d/load-wifi-injection.sh'
```

Supported: AR9271 (AWUS036NHA, TL-WN722N v1), RTL8188EU/8192EU (TL-WN722N v2/v3).

---

## Restore stock

```sh
adb reboot bootloader
fastboot flash boot boot_stock.img

adb reboot fastboot
fastboot flash vendor_dlkm vendor_dlkm_stock.img
fastboot reboot
```

Then remove the optional scripts:

```sh
adb shell su -c 'rm -f /data/adb/service.d/load-wifi-injection.sh'
adb shell su -c 'rm -rf /data/local/tmp/wifi'
```

## Troubleshooting

| Problem | Fix |
|---|---|
| Wi-Fi dead after flashing kernel | Flash the matching `vendor_dlkm_INJECTION_v3.img` in fastbootd. |
| `scmversion` missing or stock | Wrong slot, or `vendor_dlkm` was not flashed. |
| `set channel` → `-16` | STA teardown not finished — wait and retry. |
| `aireplay-ng --test` fails | Check `mon0` is up and on a channel; try 2.4 GHz ch 6; `setenforce 0`. |
| Device reboots when enabling Wi-Fi | Delete `mon0` first. |
| `fastboot flash vendor_dlkm` → `partition not found` | You are in the bootloader — use `adb reboot fastboot`. |
| OTA update broke Wi-Fi | OTA replaced `boot` / `vendor_dlkm` — reflash both. |

If the tablet won't boot: power off, hold **Volume Up + Volume Down + Power** until fastboot appears, then flash the stock images.

---

## Thanks

Huge thanks to the **EmberHeart dev** for the `qcacld-3.0` packet-injection work — the DP TX ring, `wma_injection_tx`, monitor-mode refinements and the patch series this internal-injection build is based on.

Also: LineageOS kernel tree, Kali NetHunter, osm0sis (AnyKernel3), and the KernelSU / erofs tooling.
