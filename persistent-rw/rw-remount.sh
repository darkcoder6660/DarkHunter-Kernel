#!/system/bin/sh
# Persistent read-write remounts for the ext4 system partitions.
#
# Installed at /data/adb/service.d/ (KernelSU runs it as root during boot).
#
# WHY THE su RE-ENTRY:
#   This script runs in the SELinux domain u:r:ksu:s0, which is NOT permitted to
#   remount filesystems -- mount returns "Permission denied" (an AVC denial).
#   Re-entering via `su` switches to a domain that IS allowed, which is exactly
#   what a manual `su -c "mount -o remount,rw /"` does.
#
# /vendor /vendor_dlkm /system_dlkm /odm are erofs: read-only BY DESIGN and
# cannot be made writable. They are deliberately not listed.

LOG=/data/local/tmp/rw-remount.log
PARTS="/ /system_ext /product"

{
  echo "=== $(date) ==="
  echo "context: $(cat /proc/self/attr/current 2>/dev/null)"

  # wait for boot to complete (max ~120s)
  i=0
  while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ $i -lt 60 ]; do
    sleep 2
    i=$((i+1))
  done
  echo "boot_completed after ~$((i*2))s"
  sleep 5

  for p in $PARTS; do
    before=$(grep -E " $p " /proc/mounts | awk '{print $4}' | head -1)
    out=$(su -c "mount -o remount,rw $p" 2>&1)
    rc=$?
    after=$(grep -E " $p " /proc/mounts | awk '{print $4}' | head -1)
    echo "$p: rc=$rc  $before -> $after  ${out}"
  done
} >> "$LOG" 2>&1
