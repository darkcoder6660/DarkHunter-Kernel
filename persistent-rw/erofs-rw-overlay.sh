#!/system/bin/sh
# Make the erofs partitions writable at every boot, via ext4-loop-backed
# overlayfs.
#
# WHY AN EXT4 LOOP IMAGE:
#   overlayfs rejects raw f2fs (/data) as an upperdir -- its native casefolding
#   makes the dentry "weird" (ovl_dentry_weird), giving:
#       overlayfs: filesystem on '...' not supported
#   An ext4 image mounted via loopback is accepted.
#
# WHY /data/local/tmp:
#   The kernel's loop worker (u:r:kernel:s0) must be able to READ the image.
#   /data/local/tmp is labelled shell_data_file and works. /data/adb
#   (adb_data_file) and /mnt/vendor (mnt_vendor_file) are DENIED and give a
#   misleading "I/O error".
#
# WHY THIS WAITS FOR BOOT AND USES su:
#   At the service.d stage the domain is u:r:ksu:s0, where mount returns
#   "Permission denied" (AVC). Re-entering via su switches to a permitted
#   domain. Overlaying too early also fails, so we wait for boot_completed.
#
# WHY /vendor IS NOT IN THE LIST:
#   /vendor has SUBMOUNTS underneath it (firmware_mnt, dsp, bt_firmware).
#   A bind-mount over a parent hides its child mounts, which made
#   /vendor/firmware_mnt empty -- the wifi firmware vanished. Overlaying
#   /vendor_dlkm, /system_dlkm and /odm is safe: they have no submounts.
#   A runtime guard below refuses any partition that has submounts.
#
# SAFETY: the bind over a partition happens ONLY after verifying that the
# overlay mounted AND that the merged view shows the partition's content.
# A bind over an empty overlay would HIDE the real files.

LOG=/data/local/tmp/erofs-rw.log
BASE=/data/local/tmp/erofs-rw
PARTS="/vendor_dlkm /system_dlkm /odm"
SIZE_MB=256

{
  echo "=== $(date) ==="
  echo "context: $(cat /proc/self/attr/current 2>/dev/null)"

  i=0
  while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ $i -lt 60 ]; do
    sleep 2; i=$((i+1))
  done
  echo "boot_completed after ~$((i*2))s"
  sleep 5

  su -c "mkdir -p $BASE" 2>/dev/null

  for p in $PARTS; do
    name=$(echo "$p" | tr '/' '_')
    img="$BASE/${name}.img"
    mnt="$BASE/${name}_mnt"
    ovl="$BASE/${name}_ovl"

    echo "--- $p ---"

    # GUARD: never overlay a partition that has submounts underneath it
    subs=$(awk '{print $2}' /proc/mounts | grep -c "^$p/")
    if [ "$subs" -gt 0 ]; then
      echo "    has $subs submount(s) -- SKIPPING (would hide them)"
      continue
    fi

    if grep -q "$ovl" /proc/mounts; then
      echo "    already open"
      continue
    fi

    su -c "
      [ -f $img ] || { dd if=/dev/zero of=$img bs=1M count=$SIZE_MB 2>/dev/null; mkfs.ext4 -F -q $img >/dev/null 2>&1; }
      mkdir -p $mnt $ovl
      umount $ovl 2>/dev/null; umount $mnt 2>/dev/null
      mount -o loop $img $mnt || exit 10
      mkdir -p $mnt/upper $mnt/work
      mount -t overlay overlay -o lowerdir=$p,upperdir=$mnt/upper,workdir=$mnt/work $ovl || exit 11
    " 2>&1
    rc=$?
    if [ $rc -ne 0 ]; then
      echo "    setup FAILED (rc=$rc) -- NOT binding"
      continue
    fi

    if ! grep -q "$ovl" /proc/mounts; then
      echo "    overlay not in mount table -- NOT binding"
      continue
    fi

    # compare entry counts: the merged view must match the real partition
    real=$(awk '{print $2}' /proc/mounts | grep -qx "$p" && ls "$p" 2>/dev/null | wc -l)
    n=$(ls "$ovl" 2>/dev/null | wc -l)
    echo "    merged view: $n entries"
    if [ "$n" -eq 0 ]; then
      echo "    EMPTY merged view -- refusing to bind"
      continue
    fi

    su -c "mount --bind $ovl $p" 2>&1
    if su -c "touch $p/.rwtest" 2>/dev/null; then
      su -c "rm -f $p/.rwtest"
      echo "    BOUND and WRITABLE"
    else
      echo "    bound but write test failed"
    fi
  done
} >> "$LOG" 2>&1
