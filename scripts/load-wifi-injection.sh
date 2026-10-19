#!/system/bin/sh
# Auto-load external Wi-Fi adapter injection modules at boot (KernelSU service.d)
# Runs as root at the service (late-boot) stage.
MOD_DIR=/data/local/tmp/wifi
LOG="$MOD_DIR/boot-load.log"

[ -d "$MOD_DIR" ] || exit 0

{
  # Unload any external-adapter drivers first, then the stock mac80211
  rmmod rtl8xxxu 2>/dev/null
  rmmod ath9k_htc 2>/dev/null
  rmmod ath9k_common 2>/dev/null
  rmmod ath9k_hw 2>/dev/null
  rmmod ath 2>/dev/null
  rmmod mac80211 2>/dev/null
  insmod "$MOD_DIR/libarc4.ko"   2>/dev/null || true
  insmod "$MOD_DIR/rfkill.ko"    2>/dev/null || true
  insmod "$MOD_DIR/cfg80211.ko"  2>/dev/null || true
  insmod "$MOD_DIR/mac80211.ko"

  # Atheros AR9271 (ath9k_htc)
  insmod "$MOD_DIR/ath.ko"
  insmod "$MOD_DIR/ath9k_hw.ko"
  insmod "$MOD_DIR/ath9k_common.ko"
  insmod "$MOD_DIR/ath9k_htc.ko"

  # Realtek RTL8188EU / RTL8192EU (rtl8xxxu)
  insmod "$MOD_DIR/rtl8xxxu.ko"
} > "$LOG" 2>&1
