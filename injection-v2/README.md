# qcacld internal injection — v2 (complete patch set)

Rebuilt with the three patches (the one EmberHeart sent + the two the OP11 dev
provided in chat). **Builds cleanly. NOT deployed — no flash, no boot test.**

## Patch set (apply in order)

| # | Patch | What it does |
|---|---|---|
| 01 | `01-emberheart-injection.patch` | The injection core (DP TX ring, `wma_injection_tx`) + the `hdd_monitor_ctx` prerequisite our tree lacked |
| 02 | `02-scan-nchannels-fix.patch` | **Crash fix**: `__wlan_hdd_cfg80211_vendor_scan()` used `n_channels` before init → UBSAN array-bounds trap (brk #0x5512) → with `PANIC_ON_OOPS=1` → reboot |
| 03 | `03-tx-validation.patch` | Extends `hdd_injection_frame_is_valid()` from Management-only to Mgmt + Control + Data |

## Why patch 02 matters for YOUR kernel specifically

Your kernel has the exact configuration that turns that bug fatal:

```
CONFIG_UBSAN=y  CONFIG_UBSAN_TRAP=y  CONFIG_UBSAN_BOUNDS=y
CONFIG_UBSAN_ARRAY_BOUNDS=y  CONFIG_UBSAN_SANITIZE_ALL=y
CONFIG_PANIC_ON_OOPS=y  CONFIG_PANIC_ON_OOPS_VALUE=1
```

Trigger per the commit message: a QCA vendor scan carrying SSIDs **plus a
frequency list** — exactly what NetHunter's `wpa_supplicant` sends during WPS
attacks. This is a **pre-existing bug in the currently-flashed kernel**, not
introduced by the injection work.

## Build result

```
mem -> dataipa -> wlan/platform -> qcacld-3.0   all OK
qca_cld3_kiwi_v2.ko   22 MB (matches stock 22 MB)
vermagic: 6.1.174-g638ecc425319-dirty SMP preempt mod_unload modversions aarch64
depends:  cfg80211,cnss_utils,cnss_nl,ipam,cnss_prealloc,qcom_iommu_util,sched-walt,qcom_va_minidump,cnss2
```

Build fixes needed for out-of-tree standalone builds (both had to be re-applied
after a source revert):
- `dataipa/drivers/platform/msm/ipa/Kbuild` — `-I$(srctree)/$(src)/...` → `-I$(src)/...`
- `qcacld-3.0/Makefile` — `KBUILD_EXTRA_SYMBOLS` paths (`.kiwi_v2` is a symlink, so
  the `..` count was off)

## The unresolved part

**Loading.** The code is now complete and the OP11 dev reports it working on
kiwi_v2 + 6.1. But on the Pad 2 the *stock* qcacld cannot be unloaded — `rmmod`
hangs in `D` state with `cnss_driver_event` stuck — and the boot-time overlay
loses the race (the driver loads before post-fs-data). That load path, not the
patch code, is the remaining problem.
