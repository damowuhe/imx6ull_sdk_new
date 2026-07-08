# i.MX6ULL SDK2

基于 Buildroot 2026.05 + U-Boot 2025.04 + Linux Kernel 7.2 的 i.MX6ULL 开发板嵌入式 Linux SDK。

## 硬件配置

- **芯片**: NXP i.MX6ULL (Cortex-A7, 792MHz)
- **内存**: DDR3 512MB
- **存储**: EMMC 8GB
- **开发板**: 正点原子 / 百问网 i.MX6ULL Pro (ALPHA/MINI)

## 目录结构

```
sdk2/
├── build.sh                  # 一键编译脚本
├── uboot-2025.04/             # U-Boot 2025.04
├── kernel-7.2/                # Linux Kernel 7.2
├── buildroot-2026.05/         # Buildroot 2026.05 根文件系统
├── imx-target/                # 编译产物输出目录
└── README.md
```

## 编译环境

### Docker 容器

```bash
# 启动容器 (挂载WSL目录)
docker run -it --rm -v /linux/imx6:/linux/imx6_sdk imx6ull:v1 bash

# 容器内进入 SDK 目录
cd /linux/imx6_sdk/sdk2
```

### 交叉编译工具链

```
路径:   /linux/tools/arm-buildroot-linux-gnueabihf_sdk-buildroot
前缀:   arm-buildroot-linux-gnueabihf-
版本:   GCC 12.4.0 (glibc, hard-float, cortex-a7 + neon-vfpv4)
```

## 一键编译

```bash
# 全量编译 (U-Boot + Kernel + Rootfs)
./build.sh all

# 单独编译
./build.sh uboot         # 编译 U-Boot
./build.sh kernel        # 编译内核
./build.sh rootfs        # 编译根文件系统 + 生成 emmc.img

# 清理
./build.sh all_clean     # 全量清理
./build.sh uboot_clean   # 清理 U-Boot
./build.sh kernel_clean  # 清理内核
./build.sh rootfs_clean  # 清理根文件系统

# 菜单配置
./build.sh uboot_menuconfig   # U-Boot 图形配置
./build.sh kernel_menuconfig  # Kernel 图形配置
./build.sh rootfs_menuconfig  # Buildroot 图形配置
```

## 编译产物

编译完成后产物在 `imx-target/` 和 `buildroot-2026.05/output/images/`:

| 文件 | 说明 |
|------|------|
| `u-boot-dtb.imx` | U-Boot 镜像 (含 fastboot) |
| `zImage` | Linux 内核镜像 |
| `*.dtb` | 设备树文件 |
| `rootfs.ext2` | 根文件系统 (ext4) |
| `rootfs.tar` | 根文件系统压缩包 |
| `emmc.img` | 完整 EMMC 烧录镜像 |

## 系统特性

### 已集成软件

| 组件 | 说明 |
|------|------|
| **neofetch** | 系统信息显示工具 |
| **adbd** | Android ADB 调试守护进程 |
| **bash** | 默认 Shell |
| **openssh** | SSH 远程登录 (Buildroot 可选) |

### 系统配置

- **自动登录**: 开机直接进入 shell，无需输入密码
- **Shell 提示符**: `damo:/ # ` 格式
- **别名**: `ll` = `ls -la`, `..` = `cd ..`
- **ADB**: 开机自动启动，支持 USB 调试
- **bootdelay**: 3 秒，可在 U-Boot 中断自动启动

## 烧录到 EMMC

### 方法一：图形工具烧录

1. 下载 [100ask_imx6ull_flashing_tool_v4.0](https://gitee.com/weidongshan/openharmony_for_imx6ull)
2. 将 `emmc.img` 复制到工具 `files/` 目录
3. 开发板设为 USB 下载模式 (BOOT1=ON, BOOT2=OFF)
4. USB 线连接 OTG 口
5. 打开工具 → 专业版 → EMMC → write_all

### 方法二：UUU 命令行烧录

```powershell
# Windows PowerShell
uuu.exe -b emmc emmc.img
```

### 方法三：SD 卡烧录

1. 用 balenaEtcher 将 `emmc.img` 写入 SD 卡
2. 板子从 SD 卡启动 (BOOT1=OFF, BOOT2=ON)
3. 进入系统后，从 SD 卡 dd 到 EMMC:

```bash
dd if=/dev/mmcblk0 of=/dev/mmcblk1 bs=4M status=progress
```

## U-Boot 配置

- **defconfig**: `mx6ull_14x14_evk_emmc_defconfig`
- **Fastboot**: 支持 USB fastboot 烧录模式
- **自动启动**: 从 EMMC 分区 1 加载 zImage + dtb，启动 Linux
- **启动失败**: 自动进入 fastboot 模式等待烧录

### 修复记录

1. GCC 12 兼容：`-mtune=generic-armv7-a` → `cortex-a7`
2. 最小化 `mx6ullevk.h` 头文件 (适配 U-Boot 2025.04 API)
3. DTB 命名对齐：`imx6ull-14x14-evk.dtb`
4. 环境变量预嵌入 emmc.img，开机直接启动

## Kernel 配置

- **defconfig**: `imx_v6_v7_defconfig` (通用 ARMv7 多平台配置)
- **DTS**: `nxp/imx/imx6ull-14x14-evk.dts`
- **关键驱动** (全部内置):
  - USB Gadget / ConfigFS (ADB 支持)
  - EMMC (SDHCI ESDHC IMX)
  - 以太网 (FEC)
  - 显示 (DRM MXSFB + LVDS 面板)

## Buildroot 配置

- **defconfig**: `imx6ull_emmc_512m_defconfig`
- **工具链**: 外部预编译工具链 (跳过 GCC/binutils 编译)
- **C 库**: glibc
- **文件系统**: ext4 (512MB)
- **overlay**: 自动登录 inittab + S50adbd + /etc/profile + hostname

## USB ADB 调试

板子启动后，USB OTG 连接电脑:

```powershell
# Windows 上安装 ADB 驱动后:
adb devices
adb shell
```

ADB 使用 ConfigFS + FunctionFS，内核已内置支持。

## 许可证

各组件遵循其原始许可证:
- U-Boot: GPL-2.0+
- Linux Kernel: GPL-2.0
- Buildroot: GPL-2.0+
