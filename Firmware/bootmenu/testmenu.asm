; $(VBCC)/bin/vasmm68k_mot -Fbin -pic -DTESTMENU -o testmenu.bin bootmenu.asm
; $(VBCC)/bin/vasmm68k_mot -Fbin -pic -o testmenu.rom testmenu.asm

	IDNT	TESTMENU_ROM

	REPT	512/4
	INCBIN	testmenu.bin
	ENDR

	END
