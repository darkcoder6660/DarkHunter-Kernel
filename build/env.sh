#!/bin/sh
# Build environment for OnePlus Pad 2 (caihong / SM8650 "pineapple") kernel 6.1
# LineageOS android_kernel_oneplus_sm8650 @ lineage-23.2
export ARCH=arm64
export SUBARCH=arm64
export LLVM=1
export LLVM_IAS=1
# clang-17 matches the android14-6.1 pinned CLANG_VERSION=r487747c (LLVM 17 generation)
export LLVM_BIN=/usr/lib/llvm-17/bin
export PATH="$LLVM_BIN:$PATH"
export KERNEL_DIR=/home/dark/nethunter-build/kernel-caihong
export OUT_DIR=/home/dark/nethunter-build/kernel-caihong/out
# conservative parallelism for 14GB RAM
export JOBS=8
