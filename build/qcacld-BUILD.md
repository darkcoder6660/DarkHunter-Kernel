# qcacld (internal Wi-Fi) module build — OnePlus Pad 2 (caihong / SM8650)

## What works (verified 2026-10-10)

Kernel 6.1.174 built with clang-17. The qcacld module compiles cleanly for the
`kiwi_v2` (WCN7850) chip profile. NetHunter monitor-mode refinements are applied
and compile-verified.

## Key non-obvious facts

1. **`.kiwi_v2` is a symlink to `.`** — it is a marker, not a directory. The
   Makefile derives the chip profile from the *last path component of `M`*.
   You must pass `M=…/qcacld-3.0/.kiwi_v2` on the make command line; do NOT
   `cd` into `.kiwi_v2` (it collapses to the parent and the profile becomes
   `qcacld-3.0`, which has no defconfig).

2. **Use clang-17**, not the distro clang-22. The kernel was built with
   clang-17; a newer compiler produces a mismatch and new -Werror failures.
   `export PATH=/usr/lib/llvm-17/bin:$PATH`.

3. The `core/`, `components/`, `configs/`, `Makefile` under `.kiwi_v2/` share
   inodes with the top-level tree (hardlinked). Patches applied to the top
   level are therefore also present in the `.kiwi_v2` build.

## Build command (qcacld)

```sh
cd /home/dark/nethunter-build/sm8650-modules/qcom/opensource/wlan/qcacld-3.0
export PATH=/usr/lib/llvm-17/bin:$PATH
make KERNEL_SRC=/home/dark/nethunter-build/kernel-caihong \
     O=/home/dark/nethunter-build/kernel-caihong/out \
     ARCH=arm64 LLVM=1 LLVM_IAS=1 \
     M=/home/dark/nethunter-build/sm8650-modules/qcom/opensource/wlan/qcacld-3.0/.kiwi_v2
```

Result: all objects compile; MODPOST fails only because the sibling modules'
`Module.symvers` are absent.

## Dependency order to fully link the .ko

qcacld links against two sibling vendor modules; `dataipa` in turn links against
`datarmnet-ext/mem`. Build order (each is an external kernel module):

1. `qcom/opensource/datarmnet-ext/mem`
2. `qcom/opensource/dataipa/drivers/platform/msm`
3. `qcom/opensource/wlan/platform`   (cnss2 + cnss_genl + cnss_prealloc + cnss_utils)
4. `qcom/opensource/wlan/qcacld-3.0/.kiwi_v2`

This is a subset of LineageOS `TARGET_KERNEL_EXT_MODULES` (~25 modules).

## Applied changes

`qcacld-monitor-mode-refinements.patch` (4 files, +82/-6):
- `hdd_is_client_mode` / `hdd_is_ap_mode`: treat `QDF_MONITOR_MODE`
- roam callback: handle `QDF_MONITOR_MODE`
- channel-width validation: switch form in `__wlan_hdd_cfg80211_set_mon_ch`
- `policy_mgr_is_hw_mode_change_required_for_channel_switch()`: skip redundant
  HW-mode change in monitor mode (adapted `adapter->vdev_id` → `deflink->vdev_id`)

## Injection status

The NetHunter injection series is 16 patches / ~12k lines / 67 files, written
for CAF 5.4. Porting it to 6.1 is mechanical but large. **Runtime efficacy is
firmware-gated**: Qualcomm's internal qcacld firmware does not transmit forged
frames, so driver-side injection does not yield working aireplay-ng injection on
the internal radio. The proven path (see Dragonw1nd/EmberHeart OnePlus 11 kernel)
is injection via an external USB adapter (rtw88 / ath9k_htc + mac80211), with the
internal radio used for monitor-mode sniffing only.
