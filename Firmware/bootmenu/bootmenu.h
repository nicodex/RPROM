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

/*
 * RPROM firmware command/data transfer status (volatile)
 */
#define RPBM_FWSTATUS_ADDR 0x000200u /* VEC_USER[64] */
#define RPBM_FWSTATUS_WORD (RPBM_FWSTATUS_ADDR >> RPBM_ADDR_SHIFT)

struct FirmwareStatus { /* TODO: move this into protocol header */
  	uint8_t  Flags; /* 00: BUSY/FAIL flags */
  	uint8_t  State; /* 01: reserved (busy bytes / fail errno) */
  	uint16_t FwCmd; /* 02: current/last RPBM_CMD_* with PARAM */
};	                /* 04: sizeof FirmwareStatus */

/* struct FirmwareStatus.Flags */
#define RPFW_STATUSB_BUSY 7u
#define RPFW_STATUSF_BUSY (1u << RPFW_STATUSB_BUSY)
#define RPFW_STATUSB_FAIL 5u
#define RPFW_STATUSF_FAIL (1u << RPFW_STATUSB_FAIL)

/*
 * RPROM firmware bootmenu command/data word format:
 *
 *	| DATA | VALUE:16                          | ROM address access range |
 *	| ---: | :-------------------------------- | -----------------------: |
 *	| `=1` | `0bFEDCBA9876543210`              | 128-256K (020000,03FFFE) |
 *
 *	| DATA | FUNC |  CMDID:4 | PARAM:11        | ROM address access range |
 *	| ---: | :--- |--------: | :-------------- | -----------------------: |
 *	| `=0` | `=1` | `0bEDCB` | `0bA9876543210` |  64-128K (010000,01FFFE) |
 *
 * NOTE: Only 17 bits (128K words), due to F0 ROM address decoder limits.
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
 *	PARAM: reserved (0)
 *
 * The firmware exits bootmenu mode and switches to Kickstart SRAM memory.
 * Point of no return -- the bootmenu is responsible to setup/prepare the
 * system before sending this command, and has to immediately jump to the
 * Kickstart (jump has to be run from the CPU instruction prefetch queue).
 */
#define RPBM_CMDID_JUMP_TO_KICK (0x0u << RPBM_FWWORD_CMDID_BASE)
#define RPBM_CMD_JUMP_TO_KICK (RPBM_FWWORDF_FUNC | RPBM_CMDID_JUMP_TO_KICK)

/******************************************************************************
 *
 *	RPBM_CMDID_BOOTMENUINFO (1)
 *	PARAM: reserved (0)
 *
 * The firmware writes a BootMenuInfo struct into the buffer page.
 * - firmware automatically executes this command after loading
 */
#define RPBM_CMDID_BOOTMENUINFO (0x1u << RPBM_FWWORD_CMDID_BASE)
#define RPBM_CMD_BOOTMENUINFO (RPBM_FWWORDF_FUNC | RPBM_CMDID_BOOTMENUINFO)

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
 *	PARAM: <slot_number> (0 = firmware/config)
 *
 * The firmware copies a slot from Flash storage into Kickstart SRAM memory.
 * - firmware sets struct FirmwareInfo.KickSlot = <slot_number>
 */
#define RPBM_CMDID_SLOT_TO_KICK (0x2u << RPBM_FWWORD_CMDID_BASE)
#define RPBM_CMD_SLOT_TO_KICK (RPBM_FWWORDF_FUNC | RPBM_CMDID_SLOT_TO_KICK)
#define RPBM_FIRMWARE_TO_KICK 0 /* including config storage (BootSlot) */

/******************************************************************************
 *
 *	RPBM_CMDID_FIRMWAREINFO (3)
 *	PARAM: reserved (0)
 *
 * The firmware writes a struct FirmwareInfo into the buffer page.
 */
#define RPBM_CMDID_FIRMWAREINFO (0x3u << RPBM_FWWORD_CMDID_BASE)
#define RPBM_CMD_FIRMWAREINFO (RPBM_FWWORDF_FUNC | RPBM_CMDID_FIRMWAREINFO)

struct FirmwareInfo { /* TODO: move this into protocol header */
  	uint8_t  Magic[4]; /* 00: RPFW_FIRMWAREINFO_MAGIC */
  	uint8_t  InfoSize; /* 04: sizeof FirmwareInfo & 0xFF (0 = 256) */
  	uint8_t  FwMajor;  /* 05: firmware major version (0 = develop) */
  	uint8_t  FwMinor;  /* 06: firmware minor version */
  	uint8_t  FwPatch;  /* 07: firmware patch version */
  	uint8_t  BoardRev; /* 08: RPROM hardware revision */
  	uint8_t  FlashMB;  /* 09: Flash size in MB (4MB = 7 slots) */
  	uint8_t  BootSlot; /* 0A: default boot slot from stored config */
  	uint8_t  KickSlot; /* 0B: slot loaded in Kickstart SRAM memory */
  	uint16_t BootConf; /* 0C: see struct BootMenuInfo.BootConf */
};	                   /* 0E: sizeof FirmwareInfo */

/* struct FirmwareInfo.Magic */
#define RPFW_FIRMWAREINFO_MAGIC "RPRM"

#endif /* RPROM_FIRMWARE_BOOTMENU_H */
