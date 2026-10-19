#!/system/bin/sh
# OnePlus Pad 2 — load external Wi-Fi adapter injection modules
# (patched mac80211 + ath9k_htc + rtl8xxxu)
#
# Run after every reboot, as root:
#     su -c "sh /sdcard/Download/load-wifi-modules.sh"
sh /data/local/tmp/wifi/load-modules.sh
