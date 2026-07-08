#!/bin/bash
#===============================================================================
# i.MX6ULL SDK2 主编译脚本 (新版 U-Boot 2025.04 + Kernel 7.2)
# 运行环境: Docker 容器内 /linux/imx6_sdk/sdk2/
#
# 用法:
#   ./build.sh all / uboot / kernel / rootfs / clean / menuconfig
#===============================================================================

set -e

SDK_PATH="$(cd "$(dirname "$0")" && pwd)"
TOOLCHAIN_DIR="/linux/tools/arm-buildroot-linux-gnueabihf_sdk-buildroot"
TOOLCHAIN_BIN="${TOOLCHAIN_DIR}/bin"
CROSS_PREFIX="arm-buildroot-linux-gnueabihf-"
TARGET_DIR="${SDK_PATH}/imx-target"

UBOOT_DIR="${SDK_PATH}/uboot-2025.04"
KERNEL_DIR="${SDK_PATH}/kernel-7.2"
ROOTFS_DIR="${SDK_PATH}/buildroot-2026.05"

UBOOT_DEFCONFIG="mx6ull_14x14_evk_emmc_defconfig"
KERNEL_DEFCONFIG="imx_v6_v7_defconfig"
ROOTFS_DEFCONFIG="imx6ull_emmc_512m_defconfig"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m'

check_toolchain() {
    if [ ! -x "${TOOLCHAIN_BIN}/${CROSS_PREFIX}gcc" ]; then
        echo -e "${RED}[ERROR] 交叉编译工具链未找到${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK] 工具链: $(${TOOLCHAIN_BIN}/${CROSS_PREFIX}gcc --version | head -1)${NC}"
}

setup_env() {
    export PATH="${TOOLCHAIN_BIN}:${PATH}"
    export ARCH=arm
    export CROSS_COMPILE="${CROSS_PREFIX}"
}

usage() {
    echo -e "${BLUE}i.MX6ULL SDK2 编译脚本${NC}"
    echo "  all / uboot / kernel / rootfs / clean / menuconfig"
    echo "  UBOOT  = ${UBOOT_DEFCONFIG}"
    echo "  KERNEL = ${KERNEL_DEFCONFIG}"
    echo "  ROOTFS = ${ROOTFS_DEFCONFIG}"
}

ensure_target_dir() {
    mkdir -p "${TARGET_DIR}"
}

run_in_dir() {
    local dir="$1" cmd="$2" desc="$3"
    echo -e "${BLUE}[执行] ${desc}${NC}"
    cd "${dir}" || { echo -e "${RED}无法进入 ${dir}${NC}"; exit 1; }
    eval "${cmd}" || { echo -e "${RED}命令执行失败${NC}"; exit 1; }
    cd "${SDK_PATH}"
}

# ---- U-Boot ----
build_uboot() {
    echo -e "\n${YELLOW}===== U-Boot =====${NC}"
    case "${1:-build}" in
        build)
            # GCC 12 不支持 generic-armv7-a
            sed -i "s/generic-armv7-a/cortex-a7/g" "${UBOOT_DIR}/arch/arm/Makefile" 2>/dev/null || true
            run_in_dir "${UBOOT_DIR}" \
                "make distclean && make ${UBOOT_DEFCONFIG} && make -j$(nproc)" \
                "编译 U-Boot"
            ensure_target_dir
            if [ -f "${UBOOT_DIR}/u-boot-dtb.imx" ]; then
                cp "${UBOOT_DIR}/u-boot-dtb.imx" "${TARGET_DIR}/u-boot-imx6ull-14x14-ddr512-emmc.imx"
            fi
            echo -e "${GREEN}-> U-Boot 完成${NC}"
            ;;
        clean)
            run_in_dir "${UBOOT_DIR}" "make distclean" "清理 U-Boot"
            ;;
        menuconfig)
            run_in_dir "${UBOOT_DIR}" "make ${UBOOT_DEFCONFIG} && make menuconfig" "U-Boot menuconfig"
            ;;
    esac
}

# ---- Kernel ----
build_kernel() {
    echo -e "\n${YELLOW}===== Kernel =====${NC}"
    case "${1:-build}" in
        build)
            run_in_dir "${KERNEL_DIR}" \
                "make distclean && make ${KERNEL_DEFCONFIG} && make -j$(nproc) dtbs && make modules -j$(nproc)" \
                "编译 Kernel"
            ensure_target_dir
            cp "${KERNEL_DIR}/arch/arm/boot/zImage" "${TARGET_DIR}/" 2>/dev/null
            # 新内核 DTS 在 nxp/imx/ 子目录
            find "${KERNEL_DIR}/arch/arm/boot/dts" -name "*imx6ull*evk*.dtb" -exec cp {} "${TARGET_DIR}/" \; 2>/dev/null
            echo -e "${GREEN}-> Kernel 完成${NC}"
            ;;
        clean)
            run_in_dir "${KERNEL_DIR}" "make distclean" "清理 Kernel"
            ;;
        menuconfig)
            run_in_dir "${KERNEL_DIR}" "make ${KERNEL_DEFCONFIG} && make menuconfig" "Kernel menuconfig"
            ;;
    esac
}

# ---- Rootfs ----
build_rootfs() {
    echo -e "\n${YELLOW}===== Rootfs =====${NC}"
    export FORCE_UNSAFE_CONFIGURE=1

    case "${1:-build}" in
        build)
            run_in_dir "${ROOTFS_DIR}" \
                "make ${ROOTFS_DEFCONFIG} && make -j$(nproc)" \
                "编译 Buildroot"

            # 扩容 rootfs 并生成 EMMC 整盘镜像
            echo -e "${YELLOW}扩容 rootfs 到 512MB 并生成 EMMC 镜像...${NC}"
            local rfs_img="${ROOTFS_DIR}/output/images/rootfs.ext2"
            if [ -f "${rfs_img}" ]; then
                local rfs_tmp="${ROOTFS_DIR}/output/images/rootfs_big.ext2"
                mkfs.ext4 -F -O "^metadata_csum,^64bit,^metadata_csum_seed" \
                    -d "${ROOTFS_DIR}/output/target" "${rfs_tmp}" "$((512 * 1024))" 2>/dev/null
                mv "${rfs_tmp}" "${rfs_img}"
            fi
            ensure_target_dir
            cp "${rfs_img}" "${TARGET_DIR}/" 2>/dev/null || true
            cp "${ROOTFS_DIR}/output/images/rootfs.tar" "${TARGET_DIR}/" 2>/dev/null || true
            _gen_emmc_image
            echo -e "${GREEN}-> Rootfs 完成${NC}"
            ;;
        clean)
            run_in_dir "${ROOTFS_DIR}" "make clean" "清理 Buildroot"
            ;;
        menuconfig)
            run_in_dir "${ROOTFS_DIR}" "make ${ROOTFS_DEFCONFIG} && make menuconfig" "Buildroot menuconfig"
            ;;
    esac
}

# ---- 全量 ----
build_all() {
    build_uboot build
    build_kernel build
    build_rootfs build
    echo -e "\n${GREEN}===== 全量编译完成! 产物: ${TARGET_DIR} =====${NC}"
    ls -la "${TARGET_DIR}"
}

clean_all() {
    build_uboot clean
    build_kernel clean
    build_rootfs clean
}

# ---- EMMC 镜像生成 ----
_gen_emmc_image() {
    local img_dir="${ROOTFS_DIR}/output/images"
    local tmp_cfg="${img_dir}/genimage_emmc.cfg"

            # 把 uboot/kernel/dtb 拷到 images 目录
    cp "${UBOOT_DIR}/u-boot-dtb.imx" "${img_dir}/u-boot-imx6ull-14x14-ddr512-emmc.imx" 2>/dev/null || true
    cp "${KERNEL_DIR}/arch/arm/boot/zImage" "${img_dir}/" 2>/dev/null || true
    # DTB: kernel 输出 evk.dtb，U-Boot 期望 evk-emmc.dtb
    local kdtb=$(find "${KERNEL_DIR}/arch/arm/boot/dts" -name "imx6ull-14x14-evk.dtb" 2>/dev/null | head -1)
    [ -n "$kdtb" ] && cp "$kdtb" "${img_dir}/imx6ull-14x14-evk-emmc.dtb"

    cat > "${tmp_cfg}" << EOF
image boot.vfat {
  vfat { label = "boot"
    files = { $(ls ${img_dir}/*.dtb ${img_dir}/zImage 2>/dev/null | while read f; do echo -n "\"$(basename $f)\","; done) }
  }
  size = 32M
}
image emmc.img {
  hdimage { partition-table-type = "mbr" }
  partition u-boot { in-partition-table = "no" image = "u-boot-imx6ull-14x14-ddr512-emmc.imx" offset = 1024 }
  partition boot { partition-type = 0xC bootable = "true" image = "boot.vfat" offset = 8M }
  partition rootfs { partition-type = 0x83 image = "rootfs.ext2" }
}
EOF

    "${ROOTFS_DIR}/output/host/bin/genimage" \
        --rootpath "${ROOTFS_DIR}/output/target" \
        --inputpath "${img_dir}" --outputpath "${img_dir}" \
        --config "${tmp_cfg}" 2>&1 | grep -E "ERROR|INFO: hdimage" || true

    cp "${img_dir}/emmc.img" "${TARGET_DIR}/" 2>/dev/null || true
    ls -lh "${img_dir}/emmc.img" 2>/dev/null
}

# ---- 主入口 ----
main() {
    check_toolchain
    setup_env
    echo -e "${BLUE}SDK2: ${SDK_PATH}${NC}"

    case "${1}" in
        all)       build_all ;;
        all_clean) clean_all ;;
        uboot)     build_uboot build ;;
        uboot_clean) build_uboot clean ;;
        uboot_menuconfig) build_uboot menuconfig ;;
        kernel)    build_kernel build ;;
        kernel_clean) build_kernel clean ;;
        kernel_menuconfig) build_kernel menuconfig ;;
        rootfs)    build_rootfs build ;;
        rootfs_clean) build_rootfs clean ;;
        rootfs_menuconfig) build_rootfs menuconfig ;;
        -h|--help|"") usage ;;
        *) echo -e "${RED}未知命令: $1${NC}"; usage; exit 1 ;;
    esac
}

main "$@"
