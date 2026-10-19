#!/system/bin/sh
# Load patched mac80211 + external USB Wi-Fi adapter drivers
# OnePlus Pad 2 (caihong) — kernel 6.1.174 with mac80211 packet-injection patches.
# Run as root. Push this directory to the device and execute from within it.

M="$(cd "$(dirname "$0")" && pwd)"

# The stock GKI mac80211 lacks the injection patches. Unload it first (safe:
# no external-adapter driver is loaded yet). The stock cfg80211 is kept unless
# it conflicts; our patched copy is loaded if the stock one is absent.
rmmod mac80211 2>/dev/null

insmod "$M/libarc4.ko"   2>/dev/null || true
insmod "$M/rfkill.ko"    2>/dev/null || true
insmod "$M/cfg80211.ko"  2>/dev/null || true
insmod "$M/mac80211.ko"

# Atheros AR9271 USB (AWUS036NHA, TL-WN722N v1, Netgear WN111v2)
insmod "$M/ath.ko"
insmod "$M/ath9k_hw.ko"
insmod "$M/ath9k_common.ko"
insmod "$M/ath9k_htc.ko"

# Realtek RTL8188EU / RTL8192EU USB (TL-WN722N v2/v3)
insmod "$M/rtl8xxxu.ko"

echo "done. verify with: ip link; iw dev"
echo "inject test: airmon-ng start <iface> ; aireplay-ng --test <iface>"
