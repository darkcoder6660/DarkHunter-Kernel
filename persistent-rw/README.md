# Persistent read-write setup (OnePlus Pad 2 / caihong)

Two KernelSU boot scripts in `/data/adb/service.d/`:

| Script | Makes writable |
|---|---|
| `rw-remount.sh` | `/`, `/system_ext`, `/product` (plain ext4 remount) |
| `erofs-rw-overlay.sh` | `/vendor_dlkm`, `/system_dlkm`, `/odm` (erofs via overlayfs) |

Verified across a reboot.

---

## Part 1 -- ext4 partitions (`rw-remount.sh`)

Remounts `/`, `/system_ext`, `/product` as rw. Two gotchas:

1. **Wait for `sys.boot_completed`** -- remounting too early fails.
2. **Re-enter via `su`** -- at the service.d stage the domain is `u:r:ksu:s0`,
   which is NOT permitted to remount (`mount` returns `Permission denied`, an
   AVC denial). Running as uid 0 is not enough; the SELinux domain matters.
   `su -c "mount -o remount,rw ..."` switches to a permitted domain.

## Part 2 -- erofs partitions (`erofs-rw-overlay.sh`)

`/vendor_dlkm`, `/system_dlkm`, `/odm` are erofs: read-only by design, no rw
mode. They are made writable with overlayfs.

### Why an ext4 loop image

overlayfs rejects raw f2fs (`/data`) as an upperdir -- f2fs native casefolding
makes the dentry "weird" (`ovl_dentry_weird`):

    overlayfs: filesystem on '...' not supported

Fix: create an **ext4 image**, loop-mount it, and use that as the upperdir.
(Documented in magisk_overlayfs and mountify.)

### Why the image lives in /data/local/tmp

The kernel's loop worker (`u:r:kernel:s0`) must READ the image.
`/data/local/tmp` is `shell_data_file` and works.
`/data/adb` (`adb_data_file`) and `/mnt/vendor` (`mnt_vendor_file`) are DENIED,
which surfaces as a misleading `I/O error` on the loop mount.

### Why /vendor is NOT included

`/vendor` has SUBMOUNTS underneath it:

    /vendor/firmware_mnt   (vfat)
    /vendor/dsp            (ext4)
    /vendor/bt_firmware    (vfat)

A bind-mount over a parent HIDES its children, so overlaying /vendor emptied
`/vendor/firmware_mnt` -- the wifi firmware disappeared. `erofs-rw-overlay.sh`
therefore has a GUARD that counts submounts and refuses any partition that has
them. `/vendor_dlkm`, `/system_dlkm` and `/odm` have none, so they are safe.

### Safety checks in the script

Before binding, it verifies (a) the overlay actually appears in the mount table
and (b) the merged view is non-empty. A bind over an empty overlay would hide
the real files.

### Space

Each overlay is backed by a 256 MB ext4 image, so the overlaid partitions have
~240 MB free -- far more than the original erofs partitions, which reported
0 bytes free.

---

## Reverting

    su -c "rm /data/adb/service.d/rw-remount.sh /data/adb/service.d/erofs-rw-overlay.sh"
    reboot

Nothing is written into the real partitions; all changes live in the loop
images under `/data/local/tmp/erofs-rw/`. To reclaim that space too:

    su -c "rm -rf /data/local/tmp/erofs-rw"
