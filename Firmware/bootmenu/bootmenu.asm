	NOLIST	; vasmm68k_mot -Fbin -pic -o bootmenu.rom bootmenu.asm

	IDNT	BOOTMENU_ROM
	IFD 	__VASM
		MACHINE	68000
		FAR
		FPU    	0
		OPT    	a-  ; noautopc
		OPT    	c+  ; nocase
		OPT    	d-  ; nodebug
		OPT    	o+  ; all optimizations on
		OPT    	ow+ ; show optimizations on
		OPT    	p+  ; chkpc
		OPT    	s-  ; nosymtab
		OPT    	t+  ; type
		OPT    	w+  ; warn
		OPT    	x-  ; noxdebug
	ENDC

	INCLUDE bootmenu.i

;TODO: cleanup and much more comments

BOOTMENU_SLOTS	EQU 	((1<<(22-19))-1) ; 4M/512K-1 = 7
DISP_MODE_SLOT	EQU 	(BOOTMENU_SLOTS+1)
KICK_DISK_SLOT	EQU 	(BOOTMENU_SLOTS+2)

COL_BLACK   	EQU 	$000 ; implied for some optimizations
COL_SCREEN  	EQU 	$AAA
COL_FAILED  	EQU 	$F00
; header (components/color/silk)
COL_HEAD_1  	EQU 	COL_BLACK
COL_HEAD_2  	EQU 	$175 ; green (Kickstart)
COL_F0_ROM  	EQU 	$05A ; blue (Ext F0 ROM)
COL_HEAD_3  	EQU 	$CCC
; cursor (shadow/color/highlight)
COL_CURS_1  	EQU 	COL_HEAD_1
COL_CURS_2  	EQU 	$E44
COL_CURS_3  	EQU 	$EEC
; invalid slot (chip/background/digit)
COL_SOFF_1  	EQU 	$555
COL_SOFF_2  	EQU 	COL_SCREEN
COL_SOFF_3  	EQU 	$888
; valid, selected/highlighted slot
COL_SOVR_1  	EQU 	COL_BLACK
COL_SOVR_2  	EQU 	$68B
COL_SOVR_3  	EQU 	$FFF
; valid, active, not selected slot
COL_SACT_1  	EQU 	COL_SOVR_1
COL_SACT_2  	EQU 	$AAB
COL_SACT_3  	EQU 	$EEE
; valid, not selected slot
COL_SLOT_1  	EQU 	COL_SACT_1
COL_SLOT_2  	EQU 	COL_SCREEN
COL_SLOT_3  	EQU 	$DDD

CURSOR_W    	EQU 	11
CURSOR_H    	EQU 	11
SCREEN_W    	EQU 	320
SCREEN_H    	EQU 	(200+CURSOR_H)
SCREEN_T    	EQU 	44  ; $2C (Workbench NTSC/PAL default)
SCREEN_L    	EQU 	129 ; $81 (LoRes: (DDFSTRT + 8.5) * 2)
SCREEN_B    	EQU 	(SCREEN_T+SCREEN_H)                  ; $0FF
SCREEN_R    	EQU 	(SCREEN_L+SCREEN_W)                  ; $1C1
DIW_STRT    	EQU 	((SCREEN_T<<8)!SCREEN_L)             ; $2C81
DIW_STOP    	EQU 	((($FF&SCREEN_B)<<8)!($FF&SCREEN_R)) ; $FFC1
DDF_STRT    	EQU 	$0028 ; ((SCREEN_L-17)/2)            ; ($0038)
DDF_STOP    	EQU 	$0030 ; (DDF_STRT+((SCREEN_W-16)/2)) ; ($00D0)
BPL_CON0    	EQU 	((1<<PLNCNTSHFT)!COLORON)
BPL_CON1    	EQU 	$0000
BPL_CON2    	EQU 	((4<<3)!(4<<0)) ; priority SP01,SP23,SP45,SP67,PF1,PF2
BPL_MOD1    	EQU 	($FFFF&-((DDF_STOP+8-DDF_STRT)/4*1)) ; reset bplpt
SPRITEDX    	EQU 	1 ; don't ask why, I don't know (0 = DIWSTRT:HSTART-1)
SPRITE_L    	EQU 	(SCREEN_L-SPRITEDX)
SPRITE_R    	EQU 	(SCREEN_R-SPRITEDX)
SPRITE_C    	EQU 	(SPRITE_L+((SPRITE_R-SPRITE_L)/2))
HEADER_W    	EQU 	(7*16)
HEADER_H    	EQU 	(31+6)
HEADER_T    	EQU 	7
HEADER_L    	EQU 	(SPRITE_C-(HEADER_W/2)-4) ; +/- even (spr pos)
HEADER_B    	EQU 	(HEADER_T+HEADER_H)
SYMBOL_W    	EQU 	(2*16)
SYMBOL_H    	EQU 	32
SYMBOLDX    	EQU 	24 ; even (spr pos)
SYMBOLDY    	EQU 	15 ; >= 4 setup lines
SYMBOL_T    	EQU 	(HEADER_B+SYMBOLDY+10)
SYMBOL_M    	EQU 	(SPRITE_C-(SYMBOL_W/2))
SYMBOL_L    	EQU 	(SYMBOL_M-SYMBOLDX-SYMBOL_W)
SYMBOL_B    	EQU 	(SYMBOL_T+(3*(SYMBOL_H+SYMBOLDY)-SYMBOLDY))
SYMBOL_R    	EQU 	(SYMBOL_M+SYMBOL_W+SYMBOLDX)
CURSORDY    	EQU 	1 ; setup line (WaitDIW/NextLine)
CURSOR_T    	EQU 	SYMBOL_T-SYMBOLDY ; >= 0
CURSOR_L    	EQU 	(SYMBOL_L-SYMBOLDX) ; >= SPRITE_L
CURSOR_B    	EQU 	(SYMBOL_B+SYMBOLDY) ; <= (SCREEN_H-CURSOR_H)
CURSOR_R    	EQU 	(SYMBOL_R+SYMBOL_W+SYMBOLDX) ; <= (SPRITE_R-CURSOR_W)

;------------------------------------------------------------------------------
;
;             Global register usage alias/definitions, macros, and
;             chipset defs, so that it looks similar to NDK usage.
;             However, it is still hand-written assembly code with
;             many internal dependencies that are easily broken...
;

reg_D0      	EQUR	d0 ; scratch
reg_A0      	EQUR	a0 ; scratch
reg_D1      	EQUR	d1 ; scratch
reg_A1      	EQUR	a1 ; scratch
menu_state  	EQUR	d2 ; trashed (_.b/flags.b/fwword.w)
func_raddr  	EQUR	a2 ; trashed
curs_pos    	EQUR	d3 ; trashed (h: SCR.X / l: DIW.Y--)
curs_dat    	EQUR	a3 ; trashed (cursor image data ptr)
curs_state  	EQUR	d4 ; trashed (_.b/lmb.b/joy0dat.w)
vhposr_H    	EQUR	a4 ; trashed (custom)
kick_cksum  	EQUR	d5 ; unchanged (F0 ROM API)
diag_raddr  	EQUR	a5 ; unchanged (F0 ROM API)
reg_D6      	EQUR	d6 ; unchanged
reg_A6      	EQUR	a6 ; unchanged
reg_D7      	EQUR	d7 ; unchanged
fw_status   	EQUR	a7 ; preserved (F0 ROM API)
;           	    	usp ; trashed (=ssp)
;           	    	sr  ; unchanged (clear ccr)
; menu_state _.b/flags.b/fwword.w
BMSB_KICKLOAD	EQU 	31
BMSB_MODE_PAL	EQU 	16
; curs_state _.b/lmb.b/joy0dat.w
BMCS_LMB_BASE	EQU 	16 ; LMB_ISUP state byte left shift register

_ciaa	EQU 	$BFE001 ; read-only (Gayle disables overlay on write)
ciapra  	EQU 	$000
CIAB_GAMEPORT1  	EQU 	7 ; LMB up (port B)
CIAB_GAMEPORT0  	EQU 	6 ; LMB up (port A)
CIAF_GAMEPORT1  	EQU 	(1<<CIAB_GAMEPORT1)
CIAF_GAMEPORT0  	EQU 	(1<<CIAB_GAMEPORT0)
_custom	EQU 	$DFF000
custom	EQUR	vhposr_H ; rebased for NextLine()
CustomL	MACRO  	; <void>
		lea    	(($006+1)+_custom).l,custom ; vhposr.H
       	ENDM
CustomC	MACRO  	; <void> ; reset to _custom on exit
		subq.l 	#($006+1),custom ; vhposr.H -> _custom
       	ENDM
CustomR	MACRO  	; <offset>,<symbol>
\2	EQU 	((\1)-($006+1)) ; -vhposr.H
       	ENDM
	CustomR	$004,vposr ; BITDEF not in NDK
VPOSB_LOF 	EQU 	15 ; force non-interlaced long fields (like Kickstarts)
VPOSB_ECS 	EQU 	13 ; NTSC/PAL is switchable (also present if VPOSB_AGA)
VPOSB_NTSC	EQU 	12 ; used by Kickstart boot menu for NTSC/PAL detection
VPOSB_AGA 	EQU 	9  ; used by the RPROM boot menu to reset FMODE
VPOSB_LOL 	EQU 	7  ; used by the RPROM boot menu for NTSC/PAL detection
VPOSB_V8  	EQU 	0  ; used by the RPROM boot menu for WaitTOF() function
	CustomR	$006,vhposr
	CustomR	$00A,joy0dat
	CustomR	$00C,joy1dat
	CustomR	$016,potgor ; old name 'potinp'
	CustomR	$01C,intenar
	CustomR	$01E,intreqr
	CustomR	$02A,vposw
	CustomR	$034,potgo ; BITDEF not in NDK
POTGOB_OUTRY	EQU 	15 ; output enable for DATRY
POTGOB_DATRY	EQU 	14 ; data for port B, pin 9
POTGOB_OUTRX	EQU 	13 ; output enable for DATRX
POTGOB_DATRX	EQU 	12 ; data for port B, pin 5
POTGOB_OUTLY	EQU 	11 ; output enable for DATLY
POTGOB_DATLY	EQU 	10 ; data for port A, pin 9 (RMB)
POTGOB_OUTLX	EQU 	9  ; output enable for DATLX
POTGOB_DATLX	EQU 	8  ; data for port A, pin 5 (MMB)
POTGOB_START	EQU 	0  ; dump capacitors, start counters
POTGO_OE_RY 	EQU 	((1<<POTGOB_OUTRY)!(1<<POTGOB_DATRY))
POTGO_OE_RX 	EQU 	((1<<POTGOB_OUTRX)!(1<<POTGOB_DATRX))
POTGO_OE_LY 	EQU 	((1<<POTGOB_OUTLY)!(1<<POTGOB_DATLY))
POTGO_OE_LX 	EQU 	((1<<POTGOB_OUTLX)!(1<<POTGOB_DATLX))
POTGO_OE_ALL	EQU 	(POTGO_OE_RY!POTGO_OE_RX!POTGO_OE_LY!POTGO_OE_LX)
POTGOF_START	EQU 	(1<<POTGOB_START)
	CustomR	$07C,deniseid ; ECS/AGA
	CustomR	$08E,diwstrt
	CustomR	$090,diwstop
	CustomR	$092,ddfstrt
	CustomR	$094,ddfstop
	CustomR	$096,dmacon
DMAF_SETCLR 	EQU 	$8000
DMAF_RASTER 	EQU 	$0100
DMAF_MASTER 	EQU 	$0200
DMAF_ALL    	EQU 	$01FF ; without DMAF_BLITHOG
	CustomR	$09A,intena
INTF_ALL    	EQU 	$7FFF
	CustomR	$09C,intreq ; all $3FFF
	CustomR	$0E0,bplpt
	CustomR	$100,bplcon0
	CustomR	$102,bplcon1
PLNCNTSHFT  	EQU 	12
COLORON     	EQU 	$0200
	CustomR	$104,bplcon2
	CustomR	$106,bplcon3
	CustomR	$108,bpl1mod
	CustomR	$10A,bpl2mod
	CustomR	$110,bpldat
	CustomR	$140,spr
sd_pos      	EQU 	$00
sd_ctl      	EQU 	$02
sd_dataa    	EQU 	$04
sd_dataB    	EQU 	$06
sd_SIZEOF   	EQU 	$08
	CustomR	$180,color
	CustomR	$1DC,beamcon0
BEAMCONB_PAL	EQU 	5 ; BITDEF not in NDK
DISPLAYPAL  	EQU 	(1<<BEAMCONB_PAL)
	CustomR	$1FC,fmode ; AGA ; BITDEF not in NDK
FMB_SSCAN2  	EQU 	15
FMB_BSCAN2  	EQU 	14
FMB_SPAGEM  	EQU 	3
FMB_SPR32   	EQU 	2
FMB_BPAGEM  	EQU 	1
FMB_BLP32   	EQU 	0
	CustomR	$1FE,rnop ; RGA bus no-op (-1)

SpriteP	MACRO  	; <sprite_index>,<pos_ea=#(SPRITE_L+x)>>1> ; 280ns (2px)
		move.w 	\2,(sd_pos+spr+(sd_SIZEOF*(\1)),custom)
       	ENDM
SPR_CTL	EQU 	($0001&SPRITE_L) ; sprites 1/2-7 must use even DIW.X
SpriteC	MACRO  	; <sprite_index>,<ctl_ea=SPR_CTL>
		move.w 	\2,(sd_ctl+spr+(sd_SIZEOF*(\1)),custom)
       	ENDM
SpriteD	MACRO  	; <sprite_index>,<data_ea>
		move.l 	\2,(sd_dataa+spr+(sd_SIZEOF*(\1)),custom) ; /sd_dataB
       	ENDM

Color  	MACRO  	;.<size=w> <color_index>,<ea>
		move.\0 	\2,(color+(2*(\1)),custom)
       	ENDM

; 'functions' cannot be nested (no stack, single return address register)
FuncLnk	MACRO  	; <r_label>,[c_label] ;[4]
		lea    	(\1,pc),func_raddr
	IFC 	'\2',''
	MEXIT
	ENDC
\2:
       	ENDM
FuncDef	MACRO  	; <f_label>
\1:
       	ENDM
FuncRts	MACRO  	; [r_label] ;[4]
		jmp    	(func_raddr)
	IFC	'\1',''
	MEXIT
	ENDC
\1:
       	ENDM
CallF  	MACRO  	;.<size=w> <f_label>,<r_label>,[c_label] ;[9]
		FuncLnk	\2,\3
		bra.\0 	\1
\2:
       	ENDM

btstm  	MACRO  	;.<size=w> <bit>,<d16>,<ea> ;[8]
	IFC 	'\0','w'
		btst.b 	#(\1)&7,((\2)+1-((\1)/8),\3)
	MEXIT
	ENDC
	IFC 	'\0','l'
		btst.b 	#(\1)&7,((\2)+3-((\1)/8),\3)
	MEXIT
	ENDC
	FAIL	'use btst.b directly instead of btstm.b'
       	ENDM

	LIST
;##############################################################################
;#
;#                         CPU exception vector table
;#                         and firmware buffer/status
;#

	NOLIST
DIAG_BASE	EQU 	$00F00000
DIAG_CART	EQU 	$1111
KICK_BASE	EQU 	$00F80000
VecDef 	MACRO  	; <entry>,<index>,[last]
	IFNC	'\3',''
		dcb.l  	1-(\2)+(\3),\1-RomBase
	MEXIT
	ENDC
		dcb.l   1,\1-RomBase
       	ENDM

	LIST
RomBase:
;	VecDef 	VEC_RESETSP,0
		dc.w   	DIAG_CART ; F0 ROM API: required for callback
		bra.b  	0$        ; F0 ROM API: entry, rts = JMP (A5)
;	VecDef 	VEC_RESETPC,1
		dc.l   	KICK_BASE+2 ; self / CDTV-CR -> system
	VecDef 	VecEntry,2,11 ; (VEC_BUSERR,VEC_LINE11)
;	VecDef 	VEC_RESV,12
0$:		bra.w  	RomEntry
	VecDef 	VecEntry,13,15 ; (VEC_COPROC,VEC_UNINT)
;	VecDef 	VEC_RESV,16,22
	FuncDef	SendCmdP ; <reg_D0.w=CMDID/PARAM>
		ext.l  	reg_D0
		ori.w  	#RPBM_FWWORDF_FUNC,reg_D0
		movea.l	reg_D0,reg_A0
		eori.w 	#RPBM_FWWORDF_FUNC,reg_D0
	FuncDef	SendWord ; <reg_A0=FWWORD>
		adda.l 	reg_A0,reg_A0 ; <<RPBM_ADDR_SHIFT
		lea    	(RomBase,pc),reg_A1
		adda.l 	reg_A0,reg_A1
		lea    	(FwMagic1,pc),reg_A0
		cmpm.w 	(reg_A0)+,(reg_A1)+
	FuncRts	; JMP is executed from CPU intruction prefetch/pipeline
FwSerial:
;	VecDef 	VEC_RESV,23
		dc.l   	'RPBM' ; expected to be set by loader (firmware)
	VecDef 	VecEntry,24,58 ; (VEC_SPUR,VEC_MMUACC)
FwMagic1:
;	VecDef 	VEC_RESV,59
		dc.w   	DIAG_CART-1 ; CMDID/PARAM = 0 -> CCR %XNZVC = %_0000
		dc.w   	'BM'
	VecDef 	VecEntry,60,61 ; (VEC_UNIMPEA,VEC_UNIMPII)
VecFrame:
;	VecDef 	VEC_RESV,62,63
		; return with fake NMI expection frame
		dc.w   	$2700                                 ; ($0000,sp),SR
		dc.w   	(KICK_BASE+2)>>16,$FFFF&(KICK_BASE+2) ; ($0002,sp),PC
		dc.w   	(%0000<<12)!(4*31)                    ; ($0006,sp),F/V
FwBuffer:
;	VecDef 	VEC_USER,0,63
	NOLIST
	IFND	TESTMENU
	LIST
		dcb.b  	RPBM_PAGE_SIZE,~0
	NOLIST
	ELSE
TESTMENU_BSLOT	EQU 	4
TESTMENU_SLOTS	EQU 	(%0000111<<1)!(1<<TESTMENU_BSLOT)
TESTMENU_BCONF_LMB	EQU 	0;RPBM_CONFF_LMB_TEST;RPBM_CONFF_LMB_ISUP
TESTMENU_BCONF_RMB	EQU 	0!RPBM_CONFF_RMB_TEST!RPBM_CONFF_RMB_ISUP
TESTMENU_BCONF_BTNS	EQU 	TESTMENU_BCONF_LMB!TESTMENU_BCONF_RMB
TESTMENU_BCONF_MODE	EQU 	0!RPBM_CONFF_SET_MODE!RPBM_CONFF_MODE_PAL
TESTMENU_BCONF	EQU 	TESTMENU_BCONF_BTNS!TESTMENU_BCONF_MODE
		; struct BootMenuInfo
		dc.b   	BOOTMENU_SLOTS ; rpbmi_SlotCount
		dc.b   	TESTMENU_BSLOT ; rpbmi_BootSlot
		dc.w   	TESTMENU_BCONF ; rpbmi_BootConf
		dc.l   	TESTMENU_SLOTS ; rpbmi_SlotValid
		; struct BootMenuSlotInfo[31]
		dc.l   	$00000000+2,$1114<<16 ; rpbmsi_ResetPC/rpbmsi_ResetSP
		dc.l   	$00FC0000+2,$1114<<16 ; rpbmsi_ResetPC/rpbmsi_ResetSP
		dc.l   	$00FFF000+2,$1114<<16 ; rpbmsi_ResetPC/rpbmsi_ResetSP
		dc.l   	KICK_BASE+2,$1114<<16 ; rpbmsi_ResetPC/rpbmsi_ResetSP
		dc.l   	$00F800D0+2,$1114<<16 ; rpbmsi_ResetPC/rpbmsi_ResetSP
		dc.l   	$00F800D0+2,$1114<<16 ; rpbmsi_ResetPC/rpbmsi_ResetSP
		dc.l   	$00F800D0+2,$1114<<16 ; rpbmsi_ResetPC/rpbmsi_ResetSP
		dcb.b  	rpbmsi_SIZEOF*(31-7),0
	ENDC
	LIST
FwStatus:
;	VecDef 	VEC_USER,64
	NOLIST
	IFND	TESTMENU
	LIST
		; The RPBM_CMDID_BOOTMENUINFO command is executed
		; automatically by the firmware after loading the
		; bootmenu, but the status must be initialized so
		; that we do not assume the command has already
		; completed before it has actually been started.
		dc.b   	(1<<(RPBM_FWSTATUSB_BUSY-24))
		dc.b   	0
		dc.w   	RPBM_CMDID_BOOTMENUINFO!0
	NOLIST
	ELSE
		; fake RPBM_CMDID_SLOT_TO_KICK sucess for TESTMENU
		; so the bootmenu jumps to itself in a loop, until
		; the mouse buttons are in the configured state...
		dc.b   	0;(1<<(RPBM_FWSTATUSB_FAIL-24))
		dc.b   	0
		dc.w   	RPBM_CMDID_SLOT_TO_KICK!TESTMENU_BSLOT
	ENDC
ChkAddr	MACRO  	; <offset>,<label>
	IFNE	\1-(\2-RomBase)
	FAIL	'bootmenu.asm: fix interface offset'
	ENDC
       	ENDM
	ChkAddr	RPBM_FWSERIAL_ADDR,FwSerial
	ChkAddr	RPBM_FWMAGIC1_ADDR,FwMagic1
	ChkAddr	RPBM_FWBUFFER_ADDR,FwBuffer
	ChkAddr	RPBM_FWSTATUS_ADDR,FwStatus
	ChkAddr	RPBM_FWSTATUS_ADDR+4,*
	LIST
;	VecDef 	VEC_USER,65,78
VecEntry:
	NOLIST
	IFND	TESTMENU
	LIST
		; any exception will jump to KICK_BASE+2
		lea    	(VecFrame,pc),sp
		rte
	NOLIST
	ELSE
		; freeze TESTMENU to detect exceptions
0$:		stop   	#$2700
		bra.b 	0$
	ENDC
	LIST
JumpKick: ; [noreturn] <reg_D0.b=slot_number> ; after RPBM_CMDID_SLOT_TO_KICK
		CustomC
		lea    	(rpbmi_SlotInfo-rpbmsi_SIZEOF+FwBuffer,pc),reg_A0
		ext.w  	reg_D0
		lsl.w  	#3,reg_D0 ; *rpbmsi_SIZEOF
		adda.w 	reg_D0,reg_A0
		movem.l	(reg_A0),func_raddr/sp ; rpbmsi_ResetPC/rpbmsi_ResetSP
		; F0 ROM API handling
		lea    	(RomBase+2,pc),reg_A1
		cmpa.l 	#DIAG_BASE+2,reg_A1
		bne.b  	0$
		movea.l	diag_raddr,func_raddr ; return to caller (!DIAG)
		move   	usp,sp ; always restore SSP
		cmpi.w 	#DIAG_CART,(rpbmsi_ResetSP,reg_A0)
		bne.b  	0$
		movea.l	reg_A1,func_raddr     ; jump into F0 ROM (=DIAG)
0$:		moveq  	#RPBM_CMDID_JUMP_TO_KICK!0,reg_D0
	IFNE	%10000&(RPBM_CMDID_JUMP_TO_KICK!0)
		move   	#%00000,ccr ; clear X bit, other bits see FwMagic1 word
	ELSE
		move   	reg_D0,ccr
	ENDC
		bra.w  	SendCmdP
;	VecDef 	VEC_USER,79,191

;##############################################################################
;#
;#                              ROM entry point
;#

RomEntry:
		; stranger things #1 - called from overlay
		lea    	(RomBase,pc),reg_A0
		move.l 	reg_A0,reg_D0
		bne.b  	1$
		movea.l	(RomBase+4,pc),diag_raddr ; VEC_RESETPC
		; only possible on CDTV-CR
		lea    	(DIAG_BASE+2).l,reg_A0
		move.l 	(FwSerial-2,reg_A0),reg_D0
		sub.l  	(FwSerial,pc),reg_D0
		beq.b  	0$
		; else jump to VEC_RESETPC (KICK_BASE+2)
		exg    	reg_A0,diag_raddr
0$:		jmp    	(reg_A0)
1$:		; stranger things #2 - called from mirror
		andi.l 	#(1<<19)-1,reg_D0
		beq.b  	RomStart
		suba.l 	reg_D0,reg_A0
		jmp    	(2,reg_A0)
RomStart:
		move   	sp,usp ; (privileged instruction)
		lea    	(FwStatus,pc),fw_status
		CustomL
		move.l 	#(INTF_ALL<<16)!INTF_ALL,(intena,custom) ; /intreq
		move.w 	#DMAF_MASTER!DMAF_ALL,(dmacon,custom)
	IFNE	RPBM_FWSTATUSB_BUSY-31
3$:		btst.b 	#RPBM_FWSTATUSB_BUSY-24,(fw_status)
		bne.b  	3$
	ELSE
3$:		tst.b 	(fw_status) ; RPBM_FWSTATUSB_BUSY
		bmi.b  	3$
	ENDC
InitMode:
		move.w 	(rpbmi_BootConf+FwBuffer,pc),reg_D0
		btst.l 	#RPBM_CONFB_SET_MODE,reg_D0
		beq.b  	AutoTest
		btstm.w	VPOSB_ECS,vposr,custom
		beq.b  	0$
	IFNE	BEAMCONB_PAL-RPBM_CONFB_MODE_PAL
	IFGT	BEAMCONB_PAL-RPBM_CONFB_MODE_PAL
		lsl.w  	#BEAMCONB_PAL-RPBM_CONFB_MODE_PAL,reg_D0
	ELSE
		lsr.w  	#RPBM_CONFB_MODE_PAL-BEAMCONB_PAL,reg_D0
	ENDC
	ENDC
		andi.w 	#DISPLAYPAL,reg_D0
		move.w 	reg_D0,(beamcon0,custom)
0$:		; force long field (for 240p/288p)
		CallF.w	WaitTOF,1$
		move.w 	#(1<<VPOSB_LOF),reg_D0          ;[4].p.p
		lea    	(vposw,custom),reg_A0           ;[4].p.p
		or.w   	(vposr,custom),reg_D0           ;[6].p.r.p
		move.w 	reg_D0,(reg_A0)                 ;[4].w.p
AutoTest:
		; no active BootSlot -> BootMenu
		move.b 	(rpbmi_BootSlot+FwBuffer,pc),reg_D0
		beq.w  	BootMenu
		; test left mouse button state (if enabled)
		move.w 	(rpbmi_BootConf+FwBuffer,pc),reg_D0
		btst.l 	#RPBM_CONFB_LMB_TEST,reg_D0
		beq.b  	0$
		btst.l 	#RPBM_CONFB_LMB_ISUP,reg_D0
		; less register usage has priority here
		sne.b  	reg_D0
		ext.w  	reg_D0
		btst.b 	#CIAB_GAMEPORT0,(ciapra+_ciaa).l
		sne.b  	reg_D0
		tst.w  	reg_D0
		beq.b  	0$
		addq.w 	#1,reg_D0
		bne.b  	AutoLoad
0$:		; test right mouse button state
		move.w 	(rpbmi_BootConf+FwBuffer,pc),reg_D0
		btst.l 	#RPBM_CONFB_RMB_TEST,reg_D0
		beq.w  	BootMenu
		; switch both buttons on both ports to output
		move.w 	#POTGO_OE_ALL!POTGOF_START,(potgo,custom)
		moveq  	#((300+63)/64)-1,reg_D0 ; 300µs (5 scanlines)
1$:		swap   	reg_D0
		move.b 	(vhposr,custom),reg_D0 ; vhposr.V
2$:		cmp.b  	(vhposr,custom),reg_D0 ; vhposr.V
		beq.b  	2$
		swap   	reg_D0
		dbf    	reg_D0,1$
		btstm.w	RPBM_CONFB_RMB_ISUP,rpbmi_BootConf+FwBuffer,pc
		sne.b  	reg_D0
		ext.w  	reg_D0
		btstm.w	POTGOB_DATLY,potgor,custom
		sne.b  	reg_D0
		tst.w  	reg_D0
		beq.b  	BootMenu
		addq.w 	#1,reg_D0
		beq.b  	BootMenu
AutoLoad:
		move.w 	#RPBM_CMDID_SLOT_TO_KICK,reg_D0
		move.b 	(rpbmi_BootSlot+FwBuffer,pc),reg_D0
		CallF.w	SendCmdP,0$
1$:		cmp.w  	(2,fw_status),reg_D0
		bne.b  	1$
	IFNE	RPBM_FWSTATUSB_BUSY-31
2$:		btst.b 	#RPBM_FWSTATUSB_BUSY-24,(fw_status)
		bne.b  	2$
	ELSE
2$:		tst.b  	(fw_status) ; RPBM_FWSTATUSB_BUSY
		bmi.b  	2$
	ENDC
		btst.b 	#RPBM_FWSTATUSB_FAIL-24,(fw_status)
		beq.w  	JumpKick

;##############################################################################
;#
;#                              Boot Menu entry
;#

BootMenu:
		moveq  	#0,menu_state
		btstm.w	VPOSB_AGA,vposr,custom
		beq.b  	InitScr
		move.w 	menu_state,(fmode,custom) ; 0 = 16 bit, normal CAS
InitScr:
		move.l 	#(BPL_CON0<<16)!BPL_CON1,(bplcon0,custom) ; /bplcon1
		move.w 	#BPL_CON2,(bplcon2,custom)
		move.w 	#BPL_MOD1,(bpl1mod,custom)
		move.l 	#(DIW_STRT<<16)!DIW_STOP,(diwstrt,custom) ; /diwstop
		move.l 	#(DDF_STRT<<16)!DDF_STOP,(ddfstrt,custom) ; /ddfstop
		move.l 	menu_state,(bplpt,custom) ; NULL
		Color.w	0,#COL_SCREEN
		move.l 	menu_state,(bpldat,custom) ; %0000000000000000
		move.w 	#DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER,(dmacon,custom)
InitCur:
		moveq  	#0,curs_pos
		moveq  	#0,reg_D0
		move.b 	(rpbmi_BootSlot+FwBuffer,pc),reg_D0
		beq.b  	2$
		subq.b 	#1,reg_D0
		divu   	#3,reg_D0
		swap   	reg_D0
		move.w 	#(SYMBOL_L+8)-(SYMBOL_W+SYMBOLDX),curs_pos
0$:		addi.w 	#SYMBOL_W+SYMBOLDX,curs_pos
		dbf    	reg_D0,0$
		swap   	reg_D0
		swap   	curs_pos
		move.w 	#(SYMBOL_T+SYMBOL_H-8)-(SYMBOL_H+SYMBOLDY),curs_pos
1$:		addi.w 	#SYMBOL_H+SYMBOLDY,curs_pos
		dbf    	reg_D0,1$
2$:		addq.w 	#CURSORDY,curs_pos
		; last bit is shifted out in DrawLoop anyway
		moveq  	#%01111111<<(BMCS_LMB_BASE-16),curs_state
		btst.b 	#CIAB_GAMEPORT0,(ciapra+_ciaa).l
		beq.b  	3$
		swap   	curs_state ; %01111111<<BMCS_LMB_BASE
3$:		move.w 	(joy0dat,custom),curs_state

;##############################################################################
;#
;#                                 Draw loop
;#

	NOLIST
SkipL  	MACRO  	;.<size=w> <n>,<r_label>,<c_label> ; trashed reg_D0=-1.w
	IFGT	(\1)
	IFGT	(\1)-1
		moveq  	#(\1)-1,reg_D0
	ENDC
		CallF.\0	NextLine,\2,\3
	IFGT	(\1)-1
		dbf    	reg_D0,\3
	ENDC
	MEXIT
	ENDC
\3:
\2:
	IFLT	(\1)
	FAIL	'Negative skip lines (check SYMBOLDY/SYMBOL_T underflow)'
	ENDC
       	ENDM

	LIST
DrawLoop:
	FuncLnk	CursPos
	FuncDef	WaitTOF ; <void>
		; while vpos.V < 256 ; while vpos.V >= 256 ; vpos.V == 0
		moveq  	#VPOSB_V8&7,reg_D0
0$:		btst.b 	reg_D0,(vposr+(1-(VPOSB_V8/8)),custom)
		beq.b  	0$
1$:		btst.b 	reg_D0,(vposr+(1-(VPOSB_V8/8)),custom)
		bne.b  	1$
	FuncRts
CursPos:
		; reg_D0 = old Y_/_X ; reg_D1 = new Y_/_X ; old = new
		move.w 	curs_state,reg_D0
		swap   	reg_D0
		move.w 	curs_state,reg_D0
		move.w 	(joy0dat,custom),reg_D1
		move.w 	reg_D1,curs_state
		swap   	reg_D1
		move.w 	curs_state,reg_D1
		; curs_pos.X += new.X - old.X
		swap   	curs_pos
		sub.b  	reg_D0,reg_D1
		ext.w  	reg_D1
		add.w  	reg_D1,curs_pos
		; clamp curs_pos.X
		cmpi.w 	#CURSOR_L,curs_pos
		bge.b  	0$
		move.w 	#CURSOR_L,curs_pos
0$:		cmpi.w 	#CURSOR_R,curs_pos
		ble.b  	1$
		move.w 	#CURSOR_R,curs_pos
1$:		; sprite.X = curs_pos.X
		move.w 	curs_pos,reg_D0
		lsr.w  	#1,reg_D0
		SpriteP	0,reg_D0
		move.w 	curs_pos,reg_D0
		andi.w 	#1,reg_D0
		SpriteC	0,reg_D0
		; curs_pos.Y += new.Y - old.Y
		swap   	curs_pos
		rol.l  	#8,reg_D0
		rol.l  	#8,reg_D1
		sub.b  	reg_D0,reg_D1
		ext.w  	reg_D1
		add.w  	reg_D1,curs_pos
		; clamp curs_pos.Y
		cmpi.w 	#CURSORDY+CURSOR_T,curs_pos
		bge.b  	2$
		move.w 	#CURSORDY+CURSOR_T,curs_pos
2$:		cmpi.w 	#CURSORDY+CURSOR_B,curs_pos
		ble.b  	3$
		move.w 	#CURSORDY+CURSOR_B,curs_pos
3$:		lea    	(CursData,pc),curs_dat
	FuncLnk	FailTestEnd
	FuncDef	FailTest
		btst.b 	#RPBM_FWSTATUSB_FAIL-24,(fw_status)
		beq.b  	0$
		Color.w	0,#COL_FAILED
		moveq  	#-1,menu_state ; dead end (BMSB_KICKLOAD w/o match)
		bra.w  	HeadCol
0$:	FuncRts	FailTestEnd
LoadJmp:
		move.l 	menu_state,reg_D0
	IFNE	BMSB_KICKLOAD-31
		btst.l 	#BMSB_KICKLOAD,reg_D0
		beq.b  	CursSel
	ELSE
		bpl.b  	CursSel
	ENDC
		; wait for matching fwword (TESTMENU freeze !=TESTMENU_BSLOT)
		cmp.w  	(2,fw_status),reg_D0
		bne.w  	HeadCol
		; continue while firmware is still busy
	IFNE	RPBM_FWSTATUSB_BUSY-31
		btst.b 	#RPBM_FWSTATUSB_BUSY-24,(fw_status)
		bne.w  	HeadCol
	ELSE
		tst.b  	(fw_status) ; RPBM_FWSTATUSB_BUSY
		bmi.w  	HeadCol
	ENDC
		CallF.b	FailTest,0$ ; does not return on failure
	;	move.b 	menu_state,reg_D0
		moveq  	#0,reg_D1
		move.l 	reg_D1,menu_state
		move.l 	reg_D1,curs_pos
		move.l 	reg_D1,curs_state
		movea.l	reg_D1,curs_dat
		bra.w  	JumpKick
CursSel:
		; curs_pos.X
		move.l 	curs_pos,reg_D0
		swap   	reg_D0
		subi.w 	#SYMBOL_L,reg_D0
		ext.l  	reg_D0
		bmi.b  	0$
		divu   	#SYMBOL_W+SYMBOLDX,reg_D0
		cmpi.l 	#SYMBOL_W<<16,reg_D0
		bcc.b  	0$
		addq.w 	#1,reg_D0
		cmpi.w 	#3,reg_D0
		bhi.b  	0$
		; curs_pos.Y
		move.w 	curs_pos,reg_D1
		subi.w 	#CURSORDY+SYMBOL_T,reg_D1
		ext.l  	reg_D1
		bmi.b  	0$
		divu   	#SYMBOL_H+SYMBOLDY,reg_D1
		cmpi.l 	#SYMBOL_H<<16,reg_D1
		bcc.b  	0$
		add.w 	reg_D1,reg_D0
		add.w  	reg_D1,reg_D1
		add.w  	reg_D1,reg_D0
		cmpi.w 	#KICK_DISK_SLOT,reg_D0
		bls.b  	1$
0$:		moveq  	#0,reg_D0
1$:		move.b 	reg_D0,menu_state
LmbTest:
		beq.b  	HeadCol
		swap   	curs_state ; >>BMCS_LMB_BASE
		lsl.b  	#1,curs_state
		btst.b 	#CIAB_GAMEPORT0,(ciapra+_ciaa).l
		beq.b  	0$
		bset.l 	#0,curs_state
0$:		; click debouncing: 4 fields up/down (NTSC 67ms / PAL 80ms)
		cmpi.b 	#%11110000,curs_state
		bne.b  	4$
		; Kickstart loading
		cmpi.b 	#BOOTMENU_SLOTS,menu_state
		bhi.b  	2$
		bset.l 	#BMSB_KICKLOAD,menu_state
		move.w 	#RPBM_CMDID_SLOT_TO_KICK,reg_D0
		move.b 	menu_state,reg_D0
		move.w 	reg_D0,menu_state
		CallF.w	SendCmdP,1$
	;	bra.b  	4$
2$:		; display mode switch
		cmpi.b 	#DISP_MODE_SLOT,menu_state
		bne.b  	4$
	;	btstm.w	VPOSB_ECS,vposr,custom ; shouldn't do anything on OCS
	;	beq.b  	4$
		moveq  	#0,reg_D0
		btst.l 	#BMSB_MODE_PAL,menu_state
		bne.b  	3$
		ori.w  	#DISPLAYPAL,reg_D0
3$:		move.w 	reg_D0,(beamcon0,custom)
		;TODO: KICK_DISK_SLOT (not implemented yet)
4$:		swap   	curs_state ; <<BMCS_LMB_BASE
HeadCol:
		moveq  	#COL_HEAD_1,reg_D0
		movea.l	#(COL_HEAD_2<<16)!COL_HEAD_3,reg_A1
		lea    	(RomBase,pc),reg_A0
		cmpa.l 	#DIAG_BASE,reg_A0
		bne.b  	0$
		movea.l	#(COL_F0_ROM<<16)!COL_HEAD_3,reg_A1
0$:		lea    	(color+(2*(16+16)),custom),reg_A0
		moveq  	#(16/4)-1,reg_D1
1$:		movem.l	reg_D0/reg_A1,-(reg_A0)
		dbf    	reg_D1,1$
HeadPos:
		moveq  	#(HEADER_L)>>1,reg_D0
		lea    	(sd_pos+spr+(sd_SIZEOF*1),custom),reg_A0
0$:		move.b 	reg_D0,(reg_A0)
		addq.l 	#sd_SIZEOF,reg_A0
		addq.b 	#(16)>>1,reg_D0
		cmpi.b 	#(HEADER_L+HEADER_W)>>1,reg_D0
		bcs.b  	0$
		bset.l 	#BMSB_MODE_PAL,menu_state
WaitDIW:
		btstm.w	VPOSB_LOL,vposr,custom
		beq.b  	0$
		bclr.l 	#BMSB_MODE_PAL,menu_state
0$:		cmpi.b 	#SCREEN_T-CURSORDY,(vhposr,custom) ; vhposr.V
		bcs.b  	WaitDIW

;------------------------------------------------------------------------------
;                                 draw header
;

DrawH_0:
		SkipL.w	CURSORDY+HEADER_T-1,1$,0$       ;======================
		; upper 6 image lines are repeated at the bottom
		moveq  	#(HEADER_H-6)-1,reg_D0          ;[2].p
		lea    	(HeadData,pc),reg_A0            ;[4].p.p
DrawH_1:
		CallF.b	NextLine,0$                     ;======================
	FuncLnk	DrawHeadEnd                     	;[4]
	FuncDef	DrawHead                        	;[88]
		SpriteD	1,(reg_A0)+                     ;;[12].R.r.p.W.w.p
		SpriteD	2,(reg_A0)+                     ;;[12].R.r.p.W.w.p
		SpriteD	3,(reg_A0)+                     ;;[12].R.r.p.W.w.p
		SpriteD	4,(reg_A0)+                     ;;[12].R.r.p.W.w.p
		SpriteD	5,(reg_A0)+                     ;;[12].R.r.p.W.w.p
		SpriteD	6,(reg_A0)+                     ;;[12].R.r.p.W.w.p
		SpriteD	7,(reg_A0)+                     ;;[12].R.r.p.W.w.p
	FuncRts	DrawHeadEnd                     	;;[4]
		dbf    	reg_D0,DrawH_1                  ;[5/7]..p.p/..p.p.p
DrawH_2:
		moveq  	#(6)-1,reg_D0                   ;[2].p
		lea    	(HeadData,pc),reg_A0            ;[4].p.p
0$:		CallF.b	NextLine,1$                     ;======================
		CallF.b	DrawHead,2$                     ;[9+88]
		dbf    	reg_D0,0$                       ;[5/7]..p.p/..p.p.p
		; change cursor color in last header line
3$:		cmpi.b 	#((SPRITE_R-HEADER_W+16)/2)+4,(vhposr_H) ; [6].p.r.p
		bcs.b  	3$                              ;[4/5]...p/..p.p
	IFNE	COL_HEAD_1-COL_CURS_1
		Color.w	17,#COL_CURS_1
	ENDC
		Color.l	18,#(COL_CURS_2<<16)!COL_CURS_3 ;[12].p.p.p.W.w.p
		; additional gap between header and first row
	IFNE	SYMBOL_T-HEADER_B-SYMBOLDY
		CallF.b	NextLine,4$
		CallF.b	SlotPos,5$
		SkipL.w	SYMBOL_T-HEADER_B-SYMBOLDY-1,7$,6$
	ENDC

;------------------------------------------------------------------------------
;                            draw full 3-slot rows
;

		; we're getting really low on register memory now...
		moveq  	#(1)-1,reg_D1                   ;[2].p
		lea    	(SlotNmbr,pc),reg_A1            ;[4].p.p
DrawR_0:
	FuncLnk	NextLineEnd                      	;[4]
	FuncDef	NextLine ; <void>               	;======================
0$:		tst.b  	(vhposr_H)    ; HPOS <= $7F     ;;[4].r.p
		bpl.b  	0$                              ;;[4]...p
1$:		tst.b  	(vhposr_H)    ; HPOS >= $80     ;;[4|5].r.p|.+r.p
		bmi.b  	1$                              ;;[5|4]..p.p|...p
		subq.w 	#1,curs_pos   ; --curs_pos <= 0 ;;[2].p
		bgt.b  	2$                              ;;[4/5]...p/..p.p
		SpriteD	0,(curs_dat)+                   ;;[12].R.r.p.W.w.p
		bne.b  	2$            ; EOD: curs_dat-- ;;[4/5]...p/..p.p
		subq.l 	#4,curs_dat                     ;;[4].p..
2$:	FuncRts	NextLineEnd                     	;;[4]
		; disable sprites 1/2-7; set sprite 2-7 positions
	FuncLnk	SlotPosEnd                      	;[4]
	FuncDef	SlotPos ; <void>                	;[96]
		moveq  	#SPR_CTL,reg_D0                 ;;[2].p
		SpriteC	1,reg_D0                        ;;[6].p.w.p
		SpriteC	2,reg_D0                        ;;[6].p.w.p
		SpriteC	3,reg_D0                        ;;[6].p.w.p
		SpriteC	4,reg_D0                        ;;[6].p.w.p
		SpriteC	5,reg_D0                        ;;[6].p.w.p
		SpriteC	6,reg_D0                        ;;[6].p.w.p
		SpriteC	7,reg_D0                        ;;[6].p.w.p
		SpriteP	2,#(SYMBOL_L)>>1                ;;[8].p.p.w.p
		SpriteP	3,#(SYMBOL_L+16)>>1             ;;[8].p.p.w.p
		SpriteP	4,#(SYMBOL_M)>>1                ;;[8].p.p.w.p
		SpriteP	5,#(SYMBOL_M+16)>>1             ;;[8].p.p.w.p
		SpriteP	6,#(SYMBOL_R)>>1                ;;[8].p.p.w.p
		SpriteP	7,#(SYMBOL_R+16)>>1             ;;[8].p.p.w.p
	FuncRts	SlotPosEnd                     	        ;;[4]
	IFNE	BMSB_KICKLOAD-31
		btst.l 	#BMSB_KICKLOAD,menu_state       ;[5].p.p.
		beq.b  	2$                              ;[4/5]...p/..p.p
	ELSE
		tst.l  	menu_state                      ;[2].p
		bpl.b  	2$                              ;[4/5]...p/..p.p
	ENDC
		move.w 	#SYMBOL_B-SYMBOL_T+SYMBOLDY-2,reg_D0
		CallF.b	NextLine,1$,0$
		dbf    	reg_D0,0$
		bra.w  	DrawB_0
2$:		CallF.b	NextLine,3$                     ;======================
		CallF.b	SlotCol,4$                      ;[9+133]
		CallF.w	NextLine,5$                     ;======================
		CallF.b	SlotCol,6$                      ;[9+133]
		CallF.w	NextLine,7$                     ;======================
	FuncLnk	SlotColEnd                      	;[4]
	FuncDef	SlotCol ; <void>                	;[133]
		; COLOR21+((slot++%3)*2*4) for slot (1-1,31-1)
		lea    	(color+(2*21),custom),reg_A0          ;;[4].p.p
		move.l 	#@6666666666,reg_D0                   ;;[6].p.p.p
		btst.l 	reg_D1,reg_D0                         ;;[3].p.
		beq.b  	0$                                    ;;[4/5]...p/..p.p
		addq.l 	#2*4,reg_A0                           ;;[4].p..
		move.l 	#@4444444444,reg_D0                   ;;[6].p.p.p
		btst.l 	reg_D1,reg_D0                         ;;[3].p.
		beq.b  	0$                                    ;;[4/5]...p/..p.p
		addq.l 	#2*4,reg_A0                           ;;[4].p..
0$:		addq.w 	#1,reg_D1                             ;;[2].p
		move.w 	#COL_SOFF_1,(reg_A0)+                 ;;[6].p.w.p
		move.l 	#(COL_SOFF_2<<16)!COL_SOFF_3,(reg_A0) ;;[10].p.p.W.w.p
		move.l 	(rpbmi_SlotValid+FwBuffer,pc),reg_D0  ;;[8].p.R.r.p
		btst.l 	reg_D1,reg_D0                         ;;[3].p.
		beq.b  	1$                                    ;;[4/5]...p/..p.p
	IFNE	COL_SOFF_1-COL_SOVR_1
		move.w 	#COL_SOVR_1,(-2,reg_A0)               ;;[8].p.p.w.p
	ENDC
		move.l 	#(COL_SOVR_2<<16)!COL_SOVR_3,(reg_A0) ;;[10].p.p.W.w.p
		cmp.b  	reg_D1,menu_state                     ;;[2].p
		beq.b  	1$                                    ;;[4/5]...p/..p.p
	IFNE	COL_SOVR_1-COL_SACT_1
	FAIL	move.w 	#COL_SACT_1,(-2,reg_A0) ; check cycle count
	ENDC
		move.l 	#(COL_SACT_2<<16)!COL_SACT_3,(reg_A0) ;;[10].p.p.W.w.p
		cmp.b  	(rpbmi_BootSlot+FwBuffer,pc),reg_D1   ;;[6].p.r.p
		beq.b  	1$                                    ;;[4/5]...p/..p.p
	IFNE	COL_SACT_1-COL_SLOT_1
	FAIL	move.w 	#COL_SLOT_1,(-2,reg_A0) ; check cycle count
	ENDC
		move.l 	#(COL_SLOT_2<<16)!COL_SLOT_3,(reg_A0) ;;[10].p.p.W.w.p
1$:		lea    	(SlotBkgd,pc),reg_A0                  ;;[4].p.p
	FuncRts	                                	      ;;[4]
SlotColEnd:
		SkipL.w	SYMBOLDY-4,1$,0$                ;=====================
		moveq  	#(4)-1,reg_D0                   ;[2].p
DrawR_1:
		CallF.w	NextLine,0$                     ;======================
	FuncLnk	DrawSlotEnd                     	;[4]
	FuncDef	DrawSlot                        	;[79]
		SpriteD	2,(reg_A0)+                     ;;[12].R.r.p.W.w.p
		SpriteD	3,(reg_A0)                      ;;[12].R.r.p.W.w.p
		SpriteD	4,-(reg_A0)                     ;;[13]..R.r.p.W.w.p
		SpriteD	5,(4,reg_A0)                    ;;[14].p.R.r..p.W.w.p
		SpriteD	6,(reg_A0)+                     ;;[12].R.r.p.W.w.p
		SpriteD	7,(reg_A0)+                     ;;[12].R.r.p.W.w.p
	FuncRts	DrawSlotEnd                     	;;[4]
		dbf    	reg_D0,DrawR_1                  ;[5/7]..p.p/..p.p.p
DrawR_2:
		moveq  	#(7)-1,reg_D0                   ;[2].p
		CallF.w	NextLine,1$,0$                  ;======================
		SpriteD	2,(reg_A0)                      ;[12].R.r.p.W.w.p
		SpriteD	3,(reg_A1)+                     ;[12].R.r.p.W.w.p
		SpriteD	4,(reg_A0)                      ;[12].R.r.p.W.w.p
		SpriteD	5,(reg_A1)+                     ;[12].R.r.p.W.w.p
		SpriteD	6,(reg_A0)+                     ;[12].R.r.p.W.w.p
		SpriteD	7,(reg_A1)+                     ;[12].R.r.p.W.w.p
		addq.l 	#4,reg_A0                       ;[4].p..
		dbf    	reg_D0,0$                       ;[5/7]..p.p/..p.p.p
DrawR_3:
		moveq  	#(SYMBOL_H-4-7)-1,reg_D0        ;[2].p
0$:		CallF.w	NextLine,1$                     ;======================
		CallF.b	DrawSlot,2$                     ;[9+79]
		dbf    	reg_D0,0$                       ;[5/7]..p.p/..p.p.p
DrawR_4:
		cmpi.w 	#BOOTMENU_SLOTS-3,reg_D1        ;[4].p.p
		bcs.w  	DrawR_0                         ;[4/5]...p/..p.p

;------------------------------------------------------------------------------
;                      draw last slot and extra symbols
;

		CallF.w	NextLine,0$                     ;======================
		CallF.w	SlotPos,1$                      ;[9+96]
		CallF.w	NextLine,2$                     ;======================
		CallF.w	SlotCol,3$                      ;[9+133]
ModeCol:
		CallF.w	NextLine,0$                     ;======================
		Color.w	25,#COL_SOFF_1                  ;[8].p.p.w.p
		move.l 	#(COL_SOFF_1<<16)!COL_SCREEN,reg_D0 ;[6].p.p.p
		move.l 	#(COL_SOFF_3<<16)!COL_SOFF_3,reg_D1 ;[6].p.p.p
		btstm.w	VPOSB_ECS,vposr,custom          ;[8].p.p.r.p
		beq.b  	1$                              ;[4/5]...p/..p.p
		Color.w	25,#COL_SLOT_1                  ;[8].p.p.w.p
		move.l 	#(COL_SLOT_1<<16)!COL_SLOT_3,reg_D0 ;[6].p.p.p
		move.l 	#(COL_SOFF_3<<16)!COL_SCREEN,reg_D1 ;[6].p.p.p
		cmpi.b 	#DISP_MODE_SLOT,menu_state      ;[4].p.p
		bne.b  	1$                              ;[4/5]...p/..p.p
		move.l 	#(COL_SOVR_2<<16)!COL_SOVR_3,reg_D1 ;[6].p.p.p
1$:		btst.l 	#BMSB_MODE_PAL,menu_state       ;[5].p.p.
		beq.b  	2$                              ;[4/5]...p/..p.p
		exg    	reg_D1,reg_D0                   ;[3].p.
2$:		Color.l	26,reg_D0                       ;[8].p.W.w.p
DiskCol:
		CallF.w	NextLine,0$                     ;======================
		;TODO: KICK_DISK_SLOT (hidden/disabled for now)
	IFND 	TESTMENU
		Color.w	29,#COL_SCREEN                  ;[8].p.p.w.p
		Color.l	30,#(COL_SCREEN<<16)!COL_SCREEN ;[12].p.p.p.W.w.p
	ELSE
		Color.w	29,#COL_SOFF_1                  ;[8].p.p.w.p
		Color.l	30,#(COL_SOFF_3<<16)!COL_SOFF_2 ;[12].p.p.p.W.w.p
	ENDC
DrawX_0:
		SkipL.w	SYMBOLDY-4,1$,0$
		moveq  	#(12)-1,reg_D0                  ;[2].p
	;	lea    	(SlotXtra,pc),reg_A1 ; implicit after SlotNmbr
DrawX_1:
		CallF.w	NextLine,1$,0$                  ;======================
	FuncLnk	DrawXtraEnd                     	;[4]
	FuncDef	DrawXtra                        	;[72]
		SpriteD	2+0,(reg_A0)+                   ;[12].R.r.p.W.w.p
		SpriteD	2+1,(reg_A0)+                   ;[12].R.r.p.W.w.p
		SpriteD	4+0,(reg_A1)+                   ;[12].R.r.p.W.w.p
		SpriteD	4+1,(reg_A1)+                   ;[12].R.r.p.W.w.p
		SpriteD	6+0,(reg_A1)+                   ;[12].R.r.p.W.w.p
		SpriteD	6+1,(reg_A1)+                   ;[12].R.r.p.W.w.p
	FuncRts	DrawXtraEnd                     	;;[4]
		dbf    	reg_D0,DrawX_1                  ;[5/7]..p.p/..p.p.p
DrawX_2:
		moveq  	#(SYMBOL_H-12)-1,reg_D0         ;[2].p
0$:		CallF.w	NextLine,2$,1$                  ;======================
		Color.l	26,reg_D1                       ;[8].p.W.w.p
		CallF.b	DrawXtra,3$                     ;[9+72]
		dbf    	reg_D0,0$                       ;[5/7]..p.p/..p.p.p

;------------------------------------------------------------------------------
;                   draw cursor on the bottom of the screen
;

DrawB_0:
		CallF.w	NextLine,0$                     ;======================
		CallF.w	SlotPos,1$                      ;[9+96]
		moveq 	#SCREEN_H-SYMBOL_B-1,reg_D0     ;[4].p.p
		CallF.w	NextLine,3$,2$                  ;======================
		dbf    	reg_D0,2$                       ;[5/7]..p.p/..p.p.p
		; restore curs_pos.Y (decreased in NextLine)
		addi.w 	#CURSORDY+SCREEN_H,curs_pos
		bra.w  	DrawLoop

;##############################################################################
;#
;#                                 Image data
;#

CursData:
	INCLUDE	images/cursor.i
		dc.w   	0;0 ; EOD (you'll see it when HeadData[0] != 0)
HeadData:
	INCLUDE	images/header.i
SlotBkgd:
	INCLUDE	images/slotbkgd.i
SlotNmbr:
	INCLUDE	images/slotnmbr.i
SlotXtra:
	INCLUDE	images/slotxtra.i

	NOLIST
;##############################################################################
;#
;#             Kickstart ROM footer / MC68000 Autovector indices
;#
;#    $FFFFE8 ROM checksum (not used - might be updated by build process)
;#    $FFFFEC ROM size (not used, intended to be used for software reset)
;#    $FFFFF0 CPU Autovector interrupt exception vector indices (MC68000)
;#

RomTail:
ROM_SIZE     	EQU 	$1000 ; 4K
ROM_CODE_RESV	EQU 	(52*4+RPBM_PAGE_SIZE+4) ; VecDef+FwBuffer+FwStatus
ROM_CODE_SIZE	EQU 	(CursData-RomBase-ROM_CODE_RESV)
ROM_DATA_SIZE	EQU 	(RomTail-CursData)
ROM_FOOT     	EQU 	((2*4)+(8*2)) ; ROM csum/size + Autovector indices
ROM_FREE     	EQU 	(ROM_SIZE-(RomTail-RomBase)-ROM_FOOT)

	IFGE	ROM_FREE
		dcb.b  	ROM_FREE,~0
RomInfo	MACRO  	; <void>
	IFD 	__VASM
	PRINTT	"[ get ready to match our spin with the retro thrusters ]"
	PRINTT	'bootmenu.asm: ROM reserved bytes = \<ROM_CODE_RESV>'
	PRINTT	'bootmenu.asm: ROM code bytes = \<ROM_CODE_SIZE>'
	PRINTT	'bootmenu.asm: ROM data bytes = \<ROM_DATA_SIZE>'
	PRINTT	'bootmenu.asm: ROM free bytes = \<ROM_FREE>'
	PRINTT	'bootmenu.asm: ROM footer bytes = \<ROM_FOOT>'
	ENDC
       	ENDM
	ELSE
RomInfo	MACRO  	; <void>
	IFD 	__VASM
ROM_OVERFLOW	EQU	-ROM_FREE
	PRINTT	"[ this little maneuver's gonna cost us fifty-one years ]"
	PRINTT	'bootmenu.asm: ROM reserved bytes = \<ROM_CODE_RESV>'
	PRINTT	'bootmenu.asm: ROM code bytes = \<ROM_CODE_SIZE>'
	PRINTT	'bootmenu.asm: ROM data bytes = \<ROM_DATA_SIZE>'
	PRINTT	'bootmenu.asm: ROM free bytes = -\<ROM_OVERFLOW>'
	PRINTT	'bootmenu.asm: ROM footer bytes = \<ROM_FOOT>'
	ENDC
	PRINTT	"[ humor, seventy-five percent ]"
	FAIL	'bootmenu.asm: ROM size overflow'
       	ENDM
	ENDC
		RomInfo

		dc.l   	$0906FDFD ; Kickstart ROM csum
		dc.l   	$00080000 ; Kickstart ROM size (512K)
		; only the odd octets are read/used by the MC68000
		dc.b   	0,24 ; VEC_SPUR
		dc.b   	0,25 ; VEC_INT1 (TBE, DSKBLK, SOFTINT)
		dc.b   	0,26 ; VEC_INT2 (PORTS)
		dc.b   	0,27 ; VEC_INT3 (COPER, VERTB, BLIT)
		dc.b   	0,28 ; VEC_INT4 (AUD2, AUD0, AUD3, AUD1)
		dc.b   	0,29 ; VEC_INT5 (RBF, DSKSYNC)
		dc.b   	0,30 ; VEC_INT6 (EXTER, INTEN)
		dc.b   	0,31 ; VEC_INT7 (NMI)

	IFNE	(*-RomBase)-ROM_SIZE
	FAIL	'bootmenu.asm: fix the ROM size/footer'
	ENDC

	END
