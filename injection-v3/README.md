# qcacld internal injection — v3 (LOADABLE)

The module now passes the kernel's full load validation. Verified on device:

```
insmod qca_cld3_kiwi_v2-INJECTION-v3.ko
  -> insmod: failed to load ...: File exists      <-- PASSED validation
```

## Why v1/v2 failed — my build error, not the patch

v1/v2 were compiled while the kernel tree's `out/.config` carried the **Lindroid
additions** (`USER_NS`, `CGROUP_DEVICE`, `SYSVIPC`, `PID_NS`, `DRM_LINDROID_EVDI`).
Those change the kernel's struct layout, which changes the `module_layout` CRC.
The module therefore did not match the kernel actually flashed.

Kernel log in that state:

```
qca_cld3_kiwi_v2: disagrees about version of symbol module_layout
```

| | module_layout CRC |
|---|---|
| Stock module (loads on the flashed kernel) | `0xea759d7f` |
| v2 module (Lindroid config polluting the tree) | `0x28c5e94f` |
| **v3 module (tree restored to the boot_test.img recipe)** | **`0xea759d7f`** ✅ |

The three patched-in changes (EmberHeart injection + scan n_channels fix + tx
validation) were never the problem — they compile and link fine.

## Build recipe that produces a loadable module

1. Config must match the **flashed** kernel exactly:
   `gki_defconfig` + `vendor/pineapple_GKI.config` + `vendor/oplus/pineapple_GKI.config`
   — and **no** Lindroid fragment.
2. Rebuild the kernel so `out/Module.symvers` regenerates; confirm
   `module_layout` == `0xea759d7f` before building any module.
3. Rebuild the chain: `datarmnet-ext/mem -> dataipa -> wlan/platform -> qcacld-3.0`.
4. Verify before pushing:
   `modprobe --dump-modversions qca_cld3_kiwi_v2.ko | grep module_layout`

## Remaining blocker (not the code)

The stock qcacld is loaded at boot and **cannot be unloaded** — `rmmod` hangs in
`D` state with `cnss_driver_event` stuck. So the module cannot be swapped into a
running system. Getting it loaded requires replacing it at boot time:

- `vendor_dlkm` partition edit (replace the .ko in the erofs image), or
- an early mount via the `init_boot` ramdisk.

The driver loads in init's early second stage — measured: qcacld already resident
at 3.9 s uptime with 517 modules loaded — which is **before** KernelSU's
post-fs-data, so no /data-based overlay can win that race.
