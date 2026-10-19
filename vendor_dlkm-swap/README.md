# vendor_dlkm swap — internal qca_cld3_kiwi_v2 with injection patch (v3)

Date: 2026-10-17
Device: OnePlus Pad 2 (OPD2403 / caihong), slot **b**
Kernel: 6.1.174-g638ecc425319-dirty (floran custom build)

## What this is

The stock `qca_cld3_kiwi_v2.ko` is loaded **once** at boot by
`/vendor/bin/vendor_modprobe.sh` (triggered from `on early-init` in
`/vendor/etc/init/hw/init.qti.kernel.rc`), reading `modules.load` out of
`/vendor_dlkm/lib/modules`. It cannot be unloaded at runtime — `rmmod`
deadlocks forever in `cnss2` firmware teardown (D-state, uninterruptible),
so the terminal appears to "freeze".

The only way to get a patched module in is to **replace the file at rest**
inside the `/vendor_dlkm` erofs image and reflash that partition.

There is **no dm-verity** on `vendor_dlkm` on this ROM: `dm-8` (name
`vendor_dlkm_b`) maps straight onto `sda13` (super) with `sda13` as its only
slave, and `/vendor_dlkm` is mounted directly from it. The top-level
`vbmeta_b` also has both `VERIFICATION_DISABLED` and `HASHTREE_DISABLED`
set (flags `0x3`). So a modified image will not trip verification.

## Files

| File | What it is |
|---|---|
| `vendor_dlkm_ORIGINAL_backup.img` | Exact dump of `/dev/block/dm-8` before any change. **This is your rollback.** |
| `vendor_dlkm_INJECTION_v3.img` | Rebuilt image, identical in every respect except `lib/modules/qca_cld3_kiwi_v2.ko`. |

Checksums:

```
original : 4c025051104891a220fa4650330d994a
modified : 8e41e26d38291434026c1babc55e865f
```

Module inside the modified image:

```
name:       qca_cld3_kiwi_v2
scmversion: gec04e4f8d5c9-dirty      <-- the injection build
vermagic:   6.1.174-g638ecc425319-dirty SMP preempt mod_unload modversions aarch64
md5:        2c5af6d1d298b72dfd5f6f7833ad4819
size:       22657880
```

(Stock, for reference: `scmversion g6de5a9c04589`, 22305560 bytes,
md5 `20b9bb18d715f09ff6a3163864cb56e4`, vermagic `6.1.173-g84220fe763ed`.)

## How the image was rebuilt

```
dump.erofs -s                  -> blkszbits 12, compat sb_csum|mtime|xattr_filter,
                                  incompat lz4_0padding, lz4_max_distance 65535
mount -o loop,ro               -> extract whole tree with xattrs (security.selinux)
cp -a                          -> preserves SELinux labels, ownership, 1230768000 mtime
replace lib/modules/qca_cld3_kiwi_v2.ko
mkfs.erofs -zlz4hc,9 -b4096 -T 1230768000 \
           -U 60a46082-85ef-536f-9d8e-b32d063821c4 \
           --mount-point=/vendor_dlkm out.img tree/
truncate -s 48828416 out.img   -> pad to exact partition size
```

Resulting superblock features are bit-for-bit identical to the original.

## Flash

```
adb reboot fastboot
fastboot flash vendor_dlkm vendor_dlkm_INJECTION_v3.img
fastboot reboot
```

## Restore the stock module

```
adb reboot fastboot
fastboot flash vendor_dlkm vendor_dlkm_ORIGINAL_backup.img
fastboot reboot
```

## Verify after boot

```
adb shell su -c 'cat /sys/module/qca_cld3_kiwi_v2/scmversion'
# expect: gec04e4f8d5c9-dirty
```
