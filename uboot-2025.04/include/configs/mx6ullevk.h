/* SPDX-License-Identifier: GPL-2.0+ */
/* Minimal board config for i.MX6ULL EVK (U-Boot 2025.04) */

#ifndef __MX6ULLEVK_CONFIG_H
#define __MX6ULLEVK_CONFIG_H

#include <linux/sizes.h>
#include <asm/arch/imx-regs.h>

/* DDR configuration */
#define CFG_SYS_SDRAM_BASE       0x80000000
#define PHYS_SDRAM               0x80000000
#define PHYS_SDRAM_SIZE          SZ_512M

/* IRAM */
#define CFG_SYS_INIT_RAM_ADDR    0x00900000
#define CFG_SYS_INIT_RAM_SIZE    0x00020000

/* MMC */
#define CFG_SYS_FSL_ESDHC_ADDR   0

/* Board extra environment */
#define CFG_EXTRA_ENV_SETTINGS \
	"image=zImage\0" \
	"console=ttymxc0\0" \
	"fdtfile=imx6ull-14x14-evk-emmc.dtb\0" \
	"fdt_addr=0x83000000\0" \
	"fdt_high=0xffffffff\0" \
	"initrd_high=0xffffffff\0" \
	"mmcdev=1\0" \
	"mmcpart=2\0" \
	"mmcroot=/dev/mmcblk1p2 rootwait rw\0" \
	"mmcargs=setenv bootargs console=${console} root=${mmcroot}\0" \
	"loadimage=load mmc ${mmcdev}:1 ${loadaddr} ${image}\0" \
	"loadfdt=load mmc ${mmcdev}:1 ${fdt_addr} ${fdtfile}\0" \
	"mmcboot=echo Booting from mmc ...; " \
		"run mmcargs; " \
		"if run loadfdt; then " \
			"bootz ${loadaddr} - ${fdt_addr}; " \
		"else " \
			"echo WARN: Cannot load the DT; " \
		"fi;\0"

#endif

/* System counter timer */
#define CFG_SC_TIMER_CLK          8000000

/* PMIC */
#define CFG_MXC_OCOTP

/* Ethernet */
#define CFG_FEC_MXC_PHYADDR       0x1
