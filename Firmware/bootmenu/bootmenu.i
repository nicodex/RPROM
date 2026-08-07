	IFND	RPROM_FIRMWARE_BOOTMENU_I
RPROM_FIRMWARE_BOOTMENU_I	SET 	1

; ROM interface is word-based (no A0)
RPBM_ADDR_SHIFT	EQU 	1

; RPROM firmware page size (256 bytes)
RPBM_PAGE_BITS	EQU 	8
RPBM_PAGE_SIZE	EQU 	(1<<RPBM_PAGE_BITS)

;
; RPROM firmware is expected to set it after loading the bootmenu
; (used by the bootmenu to find itself when run from $00/overlay)
;
RPBM_FWSERIAL_ADDR	EQU 	$00005C ; VEC_RESV23 (23*4)
RPBM_FWSERIAL_WORD	EQU 	(RPBM_FWSERIAL_ADDR>>RPBM_ADDR_SHIFT)

;
; Reading this magic address/word sends the next read word offset
; as command/data to the firmware -- since the bootmenu code runs
; in the ROM area -- the only practical read-only CPU instruction
; available is "CMPM.W (Ay)+,(Ax)+ ; [6].r.r.p", which allows two
; addresses to be read directly one after the other (without the
; CPU instruction pipeline accessing other addresses in between).
; A single-value magic address sequence is generally acceptable,
; since we have full control over the code in the bootmenu mode;
; however, we do not have exclusive control over the system, and
; the protocol must be protected from accidental commands caused
; by read accesses from external hardware by the protocol design.
;
RPBM_FWMAGIC1_ADDR	EQU 	$0000EC ; VEC_RESV59 (59*4)
RPBM_FWMAGIC1_WORD	EQU 	(RPBM_FWMAGIC1_ADDR>>RPBM_ADDR_SHIFT)

; RPROM firmware data transfer buffer (second bootmenu page)
RPBM_FWBUFFER_ADDR	EQU 	$000100 ; VEC_USER[0-63]
RPBM_FWBUFFER_WORD	EQU 	(RPBM_FWBUFFER_ADDR>>RPBM_ADDR_SHIFT)
RPBM_FWBUFFER_SIZE	EQU 	RPBM_PAGE_SIZE

;
; RPROM firmware command/data transfer status (volatile)
;
RPBM_FWSTATUS_ADDR	EQU 	$000200 ; VEC_USER[64]
RPBM_FWSTATUS_WORD	EQU 	(RPBM_FWSTATUS_ADDR>>RPBM_ADDR_SHIFT)

; struct FirmwareStatus ;TODO: move this into protocol header
rpfws_Flags 	EQU 	$00 ;<.b> BUSY/FAIL flags
rpfws_State 	EQU 	$01 ;<.b> reserved (busy bytes / fail errno)
rpfws_FwCmd 	EQU 	$02 ;<.w> current/last RPBM_CMD_* with PARAM
rpfws_SIZEOF	EQU 	$04

; rpfws_Flags
RPFW_STATUSB_BUSY	EQU 	7
RPFW_STATUSF_BUSY	EQU 	(1<<RPFW_STATUSB_BUSY)
RPFW_STATUSB_FAIL	EQU 	5
RPFW_STATUSF_FAIL	EQU 	(1<<RPFW_STATUSB_FAIL)

;
; RPROM firmware bootmenu command/data word format:
;
;	| DATA | VALUE:16                        | ROM address access range |
;	| ---: | :------------------------------ | -----------------------: |
;	| `=1` | `%FEDCBA9876543210`             | 128-256K (020000,03FFFE) |
;
;	| DATA | FUNC | CMDID:4 | PARAM:11       | ROM address access range |
;	| ---: | :--- |-------: | :------------- | -----------------------: |
;	| `=0` | `=1` | `%EDCB` | `%A9876543210` |  64-128K (010000,01FFFE) |
;
; NOTE: Only 17 bits (128K words), due to F0 ROM address decoder limits.
;
RPBM_FWWORD_BITS	EQU 	17 ; 18-RPBM_ADDR_SHIFT
RPBM_FWWORD_MASK	EQU 	((1<<RPBM_FWWORD_BITS)-1)
; if data == 1: remaining bits are the transferred data value
RPBM_FWWORDB_DATA	EQU 	16 ; RPBM_FWWORD_BITS-1
RPBM_FWWORDF_DATA	EQU 	(1<<RPBM_FWWORDB_DATA)
RPBM_FWWORD_VALUE_BITS	EQU 	16
RPBM_FWWORD_VALUE_MASK	EQU 	(1<<RPBM_FWWORD_VALUE_BITS)
; if data == 0 and func == 1: command and param bits (4+11)
RPBM_FWWORDB_FUNC	EQU 	15 ; RPBM_FWWORDB_DATA-1
RPBM_FWWORDF_FUNC	EQU 	(1<<RPBM_FWWORDB_FUNC)
RPBM_FWWORD_CMDID_BITS	EQU 	4
RPBM_FWWORD_CMDID_MASK	EQU 	((1<<RPBM_FWWORD_CMDID_BITS)-1)
RPBM_FWWORD_CMDID_BASE	EQU 	(RPBM_FWWORDB_FUNC-RPBM_FWWORD_CMDID_BITS)
RPBM_FWWORD_PARAM_BITS	EQU 	11 ; enough to address 2048 pages/slot
RPBM_FWWORD_PARAM_MASK	EQU 	((1<<RPBM_FWWORD_PARAM_BITS)-1)

;------------------------------------------------------------------------------
;
;	RPBM_CMDID_JUMP_TO_KICK (0)
;	PARAM: reserved (0)
;
; The firmware exits bootmenu mode and switches to Kickstart SRAM memory.
; Point of no return -- the bootmenu is responsible to setup/prepare the
; system before sending this command, and has to immediately jump to the
; Kickstart (jump has to be run from the CPU instruction prefetch queue).
;
RPBM_CMDID_JUMP_TO_KICK	EQU 	($0<<RPBM_FWWORD_CMDID_BASE)
RPBM_CMD_JUMP_TO_KICK  	EQU 	(RPBM_FWWORDF_FUNC!RPBM_CMDID_JUMP_TO_KICK)

;------------------------------------------------------------------------------
;
;	RPBM_CMDID_BOOTMENUINFO (1)
;	PARAM: reserved (0)
;
; The firmware writes a BootMenuInfo struct into the buffer page.
; - firmware automatically executes this command after loading
;
RPBM_CMDID_BOOTMENUINFO	EQU 	($1<<RPBM_FWWORD_CMDID_BASE)
RPBM_CMD_BOOTMENUINFO  	EQU 	(RPBM_FWWORDF_FUNC!RPBM_CMDID_BOOTMENUINFO)

; struct BootMenuSlotInfo
rpbmsi_ResetPC	EQU 	$00 ;<.l> VEC_RESETPC (1)
rpbmsi_ResetSP	EQU 	$04 ;<.l> VEC_RESETSP (0)
rpbmsi_SIZEOF 	EQU 	$08

; struct BootMenuInfo
rpbmi_SlotCount	EQU 	$00 ;<.b> 1-31 (4MB = 7 slots)
rpbmi_BootSlot 	EQU 	$01 ;<.b> see rpfwi_BootSlot
rpbmi_BootConf 	EQU 	$02 ;<.w> see RPBM_CONF* flags
rpbmi_SlotValid	EQU 	$04 ;<.l> bit 0 reserved, bit 1-31 slot valid
rpbmi_SlotInfo 	EQU 	$08 ; struct BootMenuSlotInfo[31] (16MB = 31 slots)
rpbmi_SIZEOF   	EQU 	(31*rpbmsi_SIZEOF+rpbmi_SlotInfo) ; RPBM_PAGE_SIZE

; rpbmi_BootConf
RPBM_CONFB_LMB_TEST	EQU 	0 ; test left mouse button for menu
RPBM_CONFB_LMB_ISUP	EQU 	1 ; tested LMB state is UP, else DOWN
RPBM_CONFB_RMB_TEST	EQU 	2 ; test right mouse button for menu
RPBM_CONFB_RMB_ISUP	EQU 	3 ; tested RMB state is UP, else DOWN
RPBM_CONFB_SET_MODE	EQU 	4 ; force initial display mode (ECS+)
RPBM_CONFB_MODE_PAL	EQU 	5 ; the forced mode is PAL, else NTSC
RPBM_CONFF_LMB_TEST	EQU 	(1<<RPBM_CONFB_LMB_TEST)
RPBM_CONFF_LMB_ISUP	EQU 	(1<<RPBM_CONFB_LMB_ISUP)
RPBM_CONFF_RMB_TEST	EQU 	(1<<RPBM_CONFB_RMB_TEST)
RPBM_CONFF_RMB_ISUP	EQU 	(1<<RPBM_CONFB_RMB_ISUP)
RPBM_CONFF_SET_MODE	EQU 	(1<<RPBM_CONFB_SET_MODE)
RPBM_CONFF_MODE_PAL	EQU 	(1<<RPBM_CONFB_MODE_PAL)

;------------------------------------------------------------------------------
;
;	RPBM_CMDID_SLOT_TO_KICK (2)
;	PARAM: <slot_number> (0 = firmware/config)
;
; The firmware copies a slot from Flash storage into Kickstart SRAM memory.
; - firmware sets  rpfwi_KickSlot = <slot_number>
;
RPBM_CMDID_SLOT_TO_KICK	EQU 	($2<<RPBM_FWWORD_CMDID_BASE)
RPBM_CMD_SLOT_TO_KICK  	EQU 	(RPBM_FWWORDF_FUNC!RPBM_CMDID_SLOT_TO_KICK)
RPBM_FIRMWARE_TO_KICK	EQU 	0 ; including config storage (BootSlot)

;------------------------------------------------------------------------------
;
;	RPBM_CMDID_FIRMWAREINFO (3)
;	PARAM: reserved (0)
;
; The firmware writes a struct FirmwareInfo into the buffer page.
;
RPBM_CMDID_FIRMWAREINFO	EQU 	($3<<RPBM_FWWORD_CMDID_BASE)
RPBM_CMD_FIRMWAREINFO  	EQU 	(RPBM_FWWORDF_FUNC!RPBM_CMDID_FIRMWAREINFO)

; struct FirmwareInfo ;TODO: move this into protocol header
rpfwi_Magic     	EQU 	$00 ;<.l> RPFW_FIRMWAREINFO_MAGIC
rpfwi_InfoSize  	EQU 	$04 ;<.b> rpfwi_SIZEOF & $FF (0 = 256)
rpfwi_FwMajor   	EQU 	$05 ;<.b> firmware major version (0 = develop)
rpfwi_FwMinor   	EQU 	$06 ;<.b> firmware minor version
rpfwi_FwPatch   	EQU 	$07 ;<.b> firmware patch version
rpfwi_BoardRev  	EQU 	$08 ;<.b> RPROM hardware revision
rpfwi_FlashMB   	EQU 	$09 ;<.b> Flash size in MB (4MB = 7 slots)
rpfwi_BootSlot  	EQU 	$0A ;<.b> default boot slot from stored config
rpfwi_KickSlot  	EQU 	$0B ;<.b> slot loaded in Kickstart SRAM memory
rpfwi_BootConf  	EQU 	$0C ;<.w> see rpbmi_BootConf
rpfwi_SIZEOF    	EQU 	$0E

; rpfwi_Magic
RPFW_FIRMWAREINFO_MAGIC	EQU 	'RPRM'

	ENDC
