#ifndef RPROM_FIRMWARE_BOOTMENU_H
#define RPROM_FIRMWARE_BOOTMENU_H

#include <stdint.h>

/* ROM interface is word-based (no A0) */
#define RPBM_ADDR_SHIFT 1u

/* RPROM firmware page size (256 bytes) */
#define RPBM_PAGE_BITS 8u
#define RPBM_PAGE_SIZE (1u << RPBM_PAGE_BITS)

/*
 * RPROM firmware is expected to set it after loading the bootmenu
 * (used by the bootmenu to find itself when run from $00/overlay)
 */
#define RPBM_FWSERIAL_ADDR 0x00005Cu /* VEC_RESV23 (23*4) */
#define RPBM_FWSERIAL_WORD (RPBM_FWSERIAL_ADDR >> RPBM_ADDR_SHIFT)

/*
 * Reading this magic address/word sends the next read word offset
 * as command/data to the firmware -- since the bootmenu code runs
 * in the ROM area -- the only practical read-only CPU instruction
 * available is "CMPM.W (Ay)+,(Ax)+ ; [6].r.r.p", which allows two
 * addresses to be read directly one after the other (without the
 * CPU instruction pipeline accessing other addresses in between).
 * A single-value magic address sequence is generally acceptable,
 * since we have full control over the code in the bootmenu mode;
 * however, we do not have exclusive control over the system, and
 * the protocol must be protected from accidental commands caused
 * by read accesses from external hardware by the protocol design.
 */
#define RPBM_FWMAGIC1_ADDR 0x0000ECu /* VEC_RESV59 (59*4) */
#define RPBM_FWMAGIC1_WORD (RPBM_FWMAGIC1_ADDR >> RPBM_ADDR_SHIFT)

/* RPROM firmware data transfer buffer (second bootmenu page) */
#define RPBM_FWBUFFER_ADDR 0x000100u /* VEC_USER[0-63] */
#define RPBM_FWBUFFER_WORD (RPBM_FWBUFFER_ADDR >> RPBM_ADDR_SHIFT)
#define RPBM_FWBUFFER_SIZE RPBM_PAGE_SIZE

/* RPROM firmware command/data transfer status (volatile) */
#define RPBM_FWSTATUS_ADDR 0x000200u /* VEC_USER[64] */
#define RPBM_FWSTATUS_WORD (RPBM_FWSTATUS_ADDR >> RPBM_ADDR_SHIFT)
#define RPBM_FWSTATUSB_BUSY (7u+24u) /* DQ7 */
#define RPBM_FWSTATUSF_BUSY (1u << RPBM_FWSTATUSB_BUSY)
#define RPBM_FWSTATUSB_FAIL (5u+24u) /* DQ5 */
#define RPBM_FWSTATUSF_FAIL (1u << RPBM_FWSTATUSB_FAIL)
/* TODO: low word contains current command/param pair */

/*
 * RPROM firmware bootmenu command/data word format:
 *
 *	| data | VALUE                             | ROM address access range |
 *	| ---: | :-------------------------------- | -----------------------: |
 *	| `=1` | `0bFEDCBA9876543210`              |     (0x020000, 0x03FFFE) |
 *
 *	| data | func |    CMDID | PARAM           | ROM address access range |
 *	| ---: | :--- |--------: | :-------------- | -----------------------: |
 *	| `=0` | `=1` | `0bEDCB` | `0bA9876543210` |     (0x010000, 0x01FFFE) |
 *
 * NOTE: Only 17 bits (128K words), due to F0 address decoder /ROMEN.
 */
#define RPBM_FWWORD_BITS 17u /* 18 - RPBM_ADDR_SHIFT */
#define RPBM_FWWORD_MASK ((1u << RPBM_FWWORD_BITS) - 1u)
/* if data == 1: remaining bits are the transferred data value */
#define RPBM_FWWORDB_DATA 16u /* RPBM_FWWORD_BITS - 1 */
#define RPBM_FWWORDF_DATA (1u << RPBM_FWWORDB_DATA)
#define RPBM_FWWORD_VALUE_BITS 16u
#define RPBM_FWWORD_VALUE_MASK (1u << RPBM_FWWORD_VALUE_BITS)
/* if data == 0 and func == 1: command and param bits (4 + 11) */
#define RPBM_FWWORDB_FUNC 15u /* RPBM_FWWORDB_DATA - 1 */
#define RPBM_FWWORDF_FUNC (1u << RPBM_FWWORDB_FUNC)
#define RPBM_FWWORD_CMDID_BITS 4u
#define RPBM_FWWORD_CMDID_MASK ((1u << RPBM_FWWORD_CMDID_BITS) - 1u)
#define RPBM_FWWORD_CMDID_BASE (RPBM_FWWORDB_FUNC - RPBM_FWWORD_CMDID_BITS)
#define RPBM_FWWORD_PARAM_BITS 11u /* enough to address 2048 pages/slot */
#define RPBM_FWWORD_PARAM_MASK ((1u << RPBM_FWWORD_PARAM_BITS) - 1u)

/******************************************************************************
 *
 *	RPBM_CMDID_JUMP_TO_KICK (0)
 *	param: reserved (0)
 *
 * The firmware exits bootmenu mode and switches to Kickstart SRAM memory.
 * Point of no return -- the bootmenu is responsible to setup/prepare the
 * system before sending this command, and has to immediately jump to the
 * Kickstart (jump has to be run from the CPU instruction prefetch queue).
 */
#define RPBM_CMDID_JUMP_TO_KICK (0x0u << RPBM_FWWORD_CMDID_BASE)

/******************************************************************************
 *
 *	RPBM_CMDID_BOOTMENUINFO (1)
 *	param: reserved (0)
 *
 * The firmware writes a BootMenuInfo struct into the buffer page.
 * - firmware automatically executes this command after loading
 */
#define RPBM_CMDID_BOOTMENUINFO (0x1u << RPBM_FWWORD_CMDID_BASE)

struct BootMenuSlotInfo {
  	uint32_t ResetPC; /* 00: VEC_RESETPC (1) */
  	uint32_t ResetSP; /* 04: VEC_RESETSP (0) */
};	                  /* 08: sizeof BootMenuSlotInfo */

struct BootMenuInfo {
  	uint8_t  SlotCount; /* 00: 1-31 (4MB = 7 slots) */
  	uint8_t  BootSlot;  /* 01: see struct FirmwareInfo.BootSlot */
  	uint16_t BootConf;  /* 02: see RPBM_CONF* flags */
  	uint32_t SlotValid; /* 04: bit 0 reserved, bit 1-31 slot valid */
  	struct BootMenuSlotInfo SlotInfo[31]; /* 08: (16MB = 31 slots) */
};	                   /* 100: sizeof BootMenuInfo == RPBM_PAGE_SIZE */

/* struct BootMenuInfo.BootConf */
#define RPBM_CONFB_LMB_TEST 0u /* test left mouse button for menu */
#define RPBM_CONFB_LMB_ISUP 1u /* tested LMB state is UP, else DOWN */
#define RPBM_CONFB_RMB_TEST 2u /* test right mouse button for menu */
#define RPBM_CONFB_RMB_ISUP 3u /* tested RMB state is UP, else DOWN */
#define RPBM_CONFB_SET_MODE 4u /* force initial display mode (ECS+) */
#define RPBM_CONFB_MODE_PAL 5u /* the forced mode is PAL, else NTSC */
#define RPBM_CONFF_LMB_TEST (1u << RPBM_CONFB_LMB_TEST)
#define RPBM_CONFF_LMB_ISUP (1u << RPBM_CONFB_LMB_ISUP)
#define RPBM_CONFF_RMB_TEST (1u << RPBM_CONFB_RMB_TEST)
#define RPBM_CONFF_RMB_ISUP (1u << RPBM_CONFB_RMB_ISUP)
#define RPBM_CONFF_SET_MODE (1u << RPBM_CONFB_SET_MODE)
#define RPBM_CONFF_MODE_PAL (1u << RPBM_CONFB_MODE_PAL)

/******************************************************************************
 *
 *	RPBM_CMDID_SLOT_TO_KICK (2)
 *	param: <slot_number> (0 = firmware/config)
 *
 * The firmware copies a slot from Flash storage into Kickstart SRAM memory.
 * - firmware sets struct FirmwareInfo.KickSlot = <slot_number>
 */
#define RPBM_CMDID_SLOT_TO_KICK (0x2u << RPBM_FWWORD_CMDID_BASE)

/******************************************************************************
 *
 *	RPBM_CMDID_FIRMWAREINFO (3)
 *	param: reserved (0)
 *
 * The firmware writes a struct FirmwareInfo into the buffer page.
 */
#define RPBM_CMDID_FIRMWAREINFO (0x3u << RPBM_FWWORD_CMDID_BASE)

struct FirmwareInfo { /* TODO: move this into protocol header */
  	/* struct StatusV1, but BootSlot != active (KickSlot) */
  	uint8_t  Magic[4]; /* 00: RPFW_FIRMWAREINFO_MAGIC */
  	uint8_t  InfoSize; /* 04: sizeof FirmwareInfo & 0xFF (0 = 256) */
  	uint8_t  FwMajor;  /* 05: firmware major version (0 = develop) */
  	uint8_t  FwMinor;  /* 06: firmware minor version */
  	uint8_t  FwPatch;  /* 07: firmware patch version */
  	uint8_t  FlashMB;  /* 08: Flash size in MB (4MB = 7 slots) */
  	uint8_t  BootSlot; /* 09: default boot slot from stored config */
  	/* new to StatusV2 */
  	uint8_t  KickSlot; /* 0A: slot loaded in Kickstart SRAM memory */
  	uint8_t  WorkSlot; /* 0B: current Flash slot (page read/write) */
  	uint16_t BootConf; /* 0C: see struct BootMenuInfo.BootConf */
  	uint8_t  reserved; /* 0E: reserved/alignment (zero) */
  	uint8_t  BoardRev; /* 0F: RPROM hardware revision */
};	                   /* 10: sizeof FirmwareInfo */

/* struct FirmwareInfo.Magic */
#define RPFW_FIRMWAREINFO_MAGIC "RPRM"

#endif /* RPROM_FIRMWARE_BOOTMENU_H */
