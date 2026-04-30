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
#define RPBM_FWBUFFER_ADDR 0x000100u /* VEC_USER[0-63] (64*4-127*4) */
#define RPBM_FWBUFFER_WORD (RPBM_FWBUFFER_ADDR >> RPBM_ADDR_SHIFT)
#define RPBM_FWBUFFER_SIZE RPBM_PAGE_SIZE

/* RPROM firmware command/data transfer status (volatile) */
#define RPBM_FWSTATUS_ADDR 0x000200u /* VEC_USER[64] (128*4) */
#define RPBM_FWSTATUS_WORD (RPBM_FWSTATUS_ADDR >> RPBM_ADDR_SHIFT)
#define RPBM_FWSTATUSB_BUSY (7u+24u) /* DQ7 */
#define RPBM_FWSTATUSF_BUSY (1u << RPBM_FWSTATUSB_BUSY)
#define RPBM_FWSTATUSB_FAIL (5u+24u) /* DQ5 */
#define RPBM_FWSTATUSF_FAIL (1u << RPBM_FWSTATUSB_FAIL)
/* TODO: low word contains current command/param pair */

/*
 * RPROM firmware bootmenu command/data word format:
 *
 *	| data | value                             | ROM address access range |
 *	| ---: | :-------------------------------- | -----------------------: |
 *	| `=1` | `0bFEDCBA9876543210`              |     (0x020000, 0x03FFFE) |
 *
 *	| data | func |  command | param           | ROM address access range |
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

/* RPROM firmware bootmenu command IDs */
enum BootMenuCmdID {
	RPBM_CMDID_FIRMWAREINFO, /* 0b0000 */
	RPBM_CMDID_BOOTMENUINFO, /* 0b0001 */
	RPBM_CMDID_SLOT_TO_KICK, /* 0b0010 */
	RPBM_CMDID_JUMP_TO_KICK, /* 0b0011 */
	RPBM_CMDID_RESERVED_04,  /* 0b0100 */
	RPBM_CMDID_RESERVED_05,  /* 0b0101 */
	RPBM_CMDID_RESERVED_06,  /* 0b0110 */
	RPBM_CMDID_RESERVED_07,  /* 0b0111 */
	RPBM_CMDID_RESERVED_08,  /* 0b1000 */
	RPBM_CMDID_RESERVED_09,  /* 0b1001 */
	RPBM_CMDID_RESERVED_10,  /* 0b1010 */
	RPBM_CMDID_RESERVED_11,  /* 0b1011 */
	RPBM_CMDID_RESERVED_12,  /* 0b1100 */
	RPBM_CMDID_RESERVED_13,  /* 0b1101 */
	RPBM_CMDID_RESERVED_14,  /* 0b1110 */
	RPBM_CMDID_EXTENDED_CMD  /* 0b1111 */
};

/*****************************************************************************
 *
 *	RPBM_CMDID_FIRMWAREINFO
 *	param: reserved (1)
 *
 * The firmware writes a FirmwareInfo struct into the buffer page.
 */
#define RPBM_FIRMWAREINFO_PARAM 1u
struct FirmwareInfo { /* TODO: move this into protocol header */
  	uint32_t Magic;    /* 00: RPFW_FIRMWAREINFO_MAGIC */
#define RPFW_FIRMWAREINFO_MAGIC 'RPRM'
  	uint8_t  InfoSize; /* 04: sizeof FirmwareInfo & 0xFF (0 = 256) */
  	uint8_t  FwMajor;  /* 05: firmware major version (0 = develop) */
  	uint8_t  FwMinor;  /* 06: firmware minor version */
  	uint8_t  FwPatch;  /* 07: firmware patch version */
  	uint8_t  FlashMB;  /* 08: Flash size in MB (4MB = 7 slots) */
  	uint8_t  BootSlot; /* 09: default boot slot from stored config */
  	uint16_t BootConf; /* 0A: see struct BootMenuInfo.BootConf */
  	uint8_t  KickSlot; /* 0C: slot loaded in Kickstart SRAM memory */
  	uint8_t  WorkSlot; /* 0D: current Flash slot (page read/write) */
  	uint16_t reserved; /* 0E: reserved/alignment (0) */
};	                   /* 10: sizeof FirmwareInfo */

/*****************************************************************************
 *
 *	RPBM_CMDID_BOOTMENUINFO
 *	param: reserved (1)
 *
 * The firmware writes a BootMenuInfo struct into the buffer page.
 */
#define RPBM_BOOTMENUINFO_PARAM 1u
struct BootMenuSlotInfo {
  	uint32_t KickInfo; /* 00: TODO: compressed Kickstart details */
  	uint32_t ResetPC;  /* 04: VEC_RESETPC value */
};	                   /* 08: sizeof BootMenuSlotInfo */
struct BootMenuInfo {
  	uint8_t  SlotCount; /* 00: 1-31 (4MB = 7 slots) */
  	uint8_t  BootSlot;  /* 01: see struct FirmwareInfo.BootSlot */
  	uint16_t BootConf;  /* 02: TODO: bootmenu UI and/or control flags */
  	uint32_t SlotValid; /* 04: bit 0 reserved, bit 1-31 slot valid */
  	struct BootMenuSlotInfo SlotInfo[31]; /* 08: (16MB = 31 slots) */
};	                   /* 100: sizeof BootMenuInfo == RPBM_PAGE_SIZE */

/*****************************************************************************
 *
 *	RPBM_CMDID_SLOT_TO_KICK
 *	param: <slot_index> (0 = firmware/config)
 *
 * The firmware copies a slot from Flash storage into Kickstart SRAM memory.
 * - firmware sets struct FirmwareInfo.KickSlot = <slot_index>
 */
#define RPBM_FIRMWARE_TO_KICK 0u /* including config storage (BootSlot) */

/*****************************************************************************
 *
 *	RPBM_CMDID_JUMP_TO_KICK
 *	param: reserved (0)
 *
 * The firmware exits bootmenu mode and switches to Kickstart SRAM memory.
 * Point of no return -- the bootmenu is responsible to setup/prepare the
 * system before sending this command, and has to immediately jump to the
 * Kickstart (jump has to be run from the CPU instruction prefetch queue).
 */
#define RPBM_JUMP_TO_KICK_PARAM 0u

#endif /* RPROM_FIRMWARE_BOOTMENU_H */
