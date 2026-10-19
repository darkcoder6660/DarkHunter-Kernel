#!/system/bin/sh
# Wi-Fi injection overlay: take the qcacld driver we built (with internal
# packet injection) and make init load it instead of the stock one.
MOD=/data/adb/modules/wifi-injection
KO=$MOD/qca_cld3_kiwi_v2.ko
SRC=/data/local/tmp/qca_cld3_kiwi_v2-INJECTION.ko

cp "$SRC" "$KO"
chmod 644 "$KO"

# Path A: magic-mount via /system/vendor -> /vendor -> /vendor_dlkm symlink chain
mkdir -p "$MOD/system/vendor/lib/modules"
cp "$KO" "$MOD/system/vendor/lib/modules/qca_cld3_kiwi_v2.ko"

# Path B (fallback): explicit bind mount early in boot
cat > "$MOD/post-fs-data.sh" <<'EOS'
#!/system/bin/sh
MODDIR=/data/adb/modules/wifi-injection
TARGET=/vendor_dlkm/lib/modules/qca_cld3_kiwi_v2.ko
SRC=$MODDIR/qca_cld3_kiwi_v2.ko
[ -f "$SRC" ] && [ -f "$TARGET" ] || exit 0
mount --bind "$SRC" "$TARGET" 2>/dev/null
EOS

chmod 755 "$MOD/post-fs-data.sh"
chmod -R 755 "$MOD/system"
chmod 644 "$MOD/system/vendor/lib/modules/qca_cld3_kiwi_v2.ko"

echo "=== module tree ==="
find "$MOD" | sort
