#!/bin/bash
# Rebuild the full qcacld injection chain:
#   datarmnet-ext/mem -> dataipa -> wlan/platform -> qcacld-3.0 (injection)
set -e
export PATH=/usr/lib/llvm-17/bin:$PATH

KDIR=/home/dark/nethunter-build/kernel-caihong
OUT=$KDIR/out
SRC=/home/dark/nethunter-build/sm8650-modules/qcom/opensource
LOG=/home/dark/nethunter-build/injection-chain.log

run() { echo "$@" >> "$LOG"; }
: > "$LOG"

build() {   # name, then make args
  local name="$1"; shift
  echo ">>> $name" | tee -a "$LOG"
  if make -C "$KDIR" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 "$@" >> "$LOG" 2>&1; then
    echo "    OK" | tee -a "$LOG"
  else
    echo "    FAILED" | tee -a "$LOG"; exit 1
  fi
}

build "mem"      M=$SRC/datarmnet-ext/mem CONFIG_RMNET_MEM=m modules
build "dataipa"  M=$SRC/dataipa KBUILD_EXTRA_SYMBOLS=$SRC/datarmnet-ext/mem/Module.symvers modules
build "platform" M=$SRC/wlan/platform WLAN_PLATFORM_ROOT=$SRC/wlan/platform modules

echo ">>> qcacld (injection)" | tee -a "$LOG"
cd $SRC/wlan/qcacld-3.0
make KERNEL_SRC=$KDIR O=$OUT ARCH=arm64 LLVM=1 LLVM_IAS=1 \
     M=$SRC/wlan/qcacld-3.0/.kiwi_v2 >> "$LOG" 2>&1
echo "    OK" | tee -a "$LOG"

echo ">>> done" | tee -a "$LOG"
ls -lh $SRC/wlan/qcacld-3.0/.kiwi_v2/qca_cld3_kiwi_v2.ko 2>/dev/null | tee -a "$LOG"
