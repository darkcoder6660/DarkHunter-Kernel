#!/bin/bash
# Build the OnePlus Pad 2 (caihong / SM8650 "pineapple") kernel 6.1
# Source: LineageOS android_kernel_oneplus_sm8650 @ lineage-23.2
# Toolchain: clang/LLVM 17 (matches android14-6.1 pinned CLANG_VERSION=r487747c)
#
# Layout expected (siblings of this script):
#   kernel-caihong/        android_kernel_oneplus_sm8650
#   sm8650-modules/        android_kernel_oneplus_sm8650-modules
#   sm8650-devicetrees/    android_kernel_oneplus_sm8650-devicetrees
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
. ./env.sh

cd "$KERNEL_DIR"

if [ "${CLEAN:-0}" = "1" ]; then
  echo ">>> cleaning out/"
  rm -rf "$OUT_DIR"
fi

echo ">>> [1/3] base GKI config"
make O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 gki_defconfig

echo ">>> [2/3] merge pineapple + oplus vendor fragments"
# NOTE: merge_config.sh treats the FIRST file as the base, so gki_defconfig
# must come first. Passing a fragment alone silently discards the GKI base.
# The oplus overlay is required: it enables OPLUS/OnePlus downstream code
# (e.g. CONFIG_UFSFEATURE) that the vendor kernel calls unconditionally.
export KCONFIG_CONFIG="$OUT_DIR/.config"
./scripts/kconfig/merge_config.sh -m -r -y \
  arch/arm64/configs/gki_defconfig \
  arch/arm64/configs/vendor/pineapple_GKI.config \
  arch/arm64/configs/vendor/oplus/pineapple_GKI.config
make O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
echo "    symbols: $(grep -cE '^CONFIG_' "$OUT_DIR/.config")"

echo ">>> [3/3] compile (-j$JOBS, caihong device-tree flags)"
# CONFIG_CAIHONG_DTB / CONFIG_OPLUS_DEVICE_DTBS are MAKE variables (not .config
# symbols) that select the OnePlus Pad 2 overlay DTBOs in the devicetrees repo.
make O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 \
  CONFIG_CAIHONG_DTB=y CONFIG_OPLUS_DEVICE_DTBS=y \
  -j"$JOBS"

echo ">>> done"
ls -la "$OUT_DIR"/arch/arm64/boot/Image* 2>/dev/null || echo "no Image produced"
