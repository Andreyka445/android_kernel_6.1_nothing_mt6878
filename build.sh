#!/bin/bash
# Kernel build script for Nothing Phone 3a Lite (MT6878)
# KernelSU-Next + susfs

set -e

# ===================== CONFIG =====================
KERNEL_DIR="$HOME/kernel-mt6878/kernel-6.1"
TOOLCHAIN_DIR="$HOME/kernel-mt6878/toolchain"
OUT_DIR="$HOME/kernel-mt6878/out/kernel-6.1"
DIST_DIR="$HOME/kernel-mt6878/dist"
DEFCONFIG="gki_defconfig"
# ==================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[*]${NC} $1"; }
ok()  { echo -e "${GREEN}[+]${NC} $1"; }
err() { echo -e "${RED}[-]${NC} $1"; exit 1; }
warn(){ echo -e "${YELLOW}[!]${NC} $1"; }

# Setup environment
log "Setting up environment..."
export PATH="$TOOLCHAIN_DIR/bin:$PATH"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export LLVM=1
export LLVM_IAS=1

# Verify toolchain
clang --version | head -1 || err "Clang not found at $TOOLCHAIN_DIR"

mkdir -p "$OUT_DIR" "$DIST_DIR"

# Apply defconfig
log "Applying defconfig: $DEFCONFIG..."
make -C "$KERNEL_DIR" O="$OUT_DIR" \
    ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    LLVM=1 LLVM_IAS=1 \
    "$DEFCONFIG" || err "defconfig failed"

# Enable KernelSU + susfs
log "Enabling KernelSU-Next and susfs..."
cat >> "$OUT_DIR/.config" << EOF
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
EOF

# Update config
make -C "$KERNEL_DIR" O="$OUT_DIR" \
    ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    LLVM=1 LLVM_IAS=1 \
    olddefconfig || err "olddefconfig failed"

# Build kernel
log "Building kernel with $(nproc) threads..."
START_TIME=$(date +%s)

make -C "$KERNEL_DIR" O="$OUT_DIR" \
    ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    LLVM=1 LLVM_IAS=1 \
    -j$(nproc) Image || err "Kernel build failed"

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

# Compress to lz4
log "Compressing to Image.lz4..."
lz4 -l -f "$OUT_DIR/arch/arm64/boot/Image" "$DIST_DIR/Image.lz4" || err "lz4 compression failed"

ok "Done! Build time: $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"
ok "Output: $DIST_DIR/Image.lz4"
ls -lh "$DIST_DIR/Image.lz4"