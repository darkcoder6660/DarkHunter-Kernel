# caihong external Wi-Fi adapter injection modules

Kernel **6.1.174** (`g638ecc425319-dirty`) with the NetHunter-style mac80211
packet-injection patches applied to `net/mac80211/tx.c`, `net/mac80211/cfg.c`,
and `net/wireless/chan.c`.

## Contents

| File | Purpose |
|---|---|
| `cfg80211.ko`, `mac80211.ko` | patched wireless stack (injection + monitor channel change) |
| `libarc4.ko`, `rfkill.ko` | dependencies |
| `ath.ko`, `ath9k_hw.ko`, `ath9k_common.ko`, `ath9k_htc.ko` | Atheros **AR9271** USB (AWUS036NHA, TL-WN722N v1) |
| `rtl8xxxu.ko` | Realtek **RTL8188EU/8192EU** USB (TL-WN722N v2/v3) |
| `load-modules.sh` | insmod in dependency order |

## Usage (root required)

```sh
# 1. push the directory to the device
adb push inject-modules /data/local/tmp/wifi

# 2. on the device (or `adb shell su -c …`), load the modules
su -c "sh /data/local/tmp/wifi/load-modules.sh"

# 3. plug in the USB adapter, then verify
ip link
iw dev
```

The external adapter appears as an extra `wlanX` (usually `wlan1`). Injection
tests:

```sh
airmon-ng start wlan1
aireplay-ng --test wlan1        # should print "Injection is working!"
```

## Notes

- These modules are **stripped** (BTF/debug removed) for size.
- The internal Qualcomm radio is unchanged — use it for monitor-mode sniffing
  only; injection happens on the external USB adapter.
- The stock GKI `mac80211` is unloaded by the script before loading the patched
  one; the patched `cfg80211` is loaded only if the stock one is absent.
