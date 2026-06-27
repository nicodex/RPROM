AMIGA_TOOLCHAIN ?= /opt/amiga
VBCC ?= $(AMIGA_TOOLCHAIN)/vbcc
VASM ?= $(VBCC)/bin/vasmm68k_mot
VASM_OPTS ?= -Fbin -pic -quiet -wfail -x
PYTHON ?= /usr/bin/env python3
ROMTOOL ?= /usr/bin/env romtool
CMAKE_BINDIR ?= ../../Firmware/cmake-build-release
VER_FILENAME ?= $(CMAKE_BINDIR)/generated/firmware/version.i
UAE_DBG ?= false
FSUAE ?= /usr/bin/env fs-uae
WINE ?= /usr/bin/env WINEDEBUG=-all wine
WINE_PWD ?= $(if $(WINE:=),$(shell $(WINE) START /D "$(shell pwd)" /WAIT /B CMD /C CD),..)
WINUAE_ZIP ?= WinUAE6030.zip
WINUAE_URL ?= https://download.abime.net/winuae/releases/$(WINUAE_ZIP)

all: bootmenu.bin

.PHONY: all check \
	clean distclean \
	test-fsuae-cdtv test-fsuae-ntsc test-fsuae-pal \
	test-rprom-slot1 \
	test-winuae-cdtv test-winuae-ntsc test-winuae-pal \
	winuae-beta-just-shut-up \

IMAGES = \
	images/cursor.i \
	images/header.i \
	images/slotbkgd.i \
	images/slotnmbr.i \
	images/slotxtra.i \

check: bootmenu.rom
	$(ROMTOOL) info $<

clean:
	rm -f bootmenu.lst bootmenu.rom bootmenu.bin
	rm -f $(IMAGES)
	rm -f testmenu.bin testmenu.rom

distclean: clean
	rm -rf winuae

images/header.i: $(VER_FILENAME)
images/%.i: images/%.png images/%.py
	$(PYTHON) $(@:.i=.py) $@ $< $(VER_FILENAME)

bootmenu.rom: bootmenu.asm $(IMAGES) bootmenu.i Makefile
	$(VASM) $(VASM_OPTS) -L $(@:.rom=.lst) -Lbpl=10 -Lni -Lns -o $@ $< && \
	$(ROMTOOL) copy --fix-checksum $@ $@

bootmenu.bin: bootmenu.rom
	dd if=$< of=$@ bs=2 conv=swab

testmenu.bin: bootmenu.asm $(IMAGES) bootmenu.i Makefile
	$(VASM) $(VASM_OPTS) -DTESTMENU -o $@ $<

testmenu.rom: testmenu.asm testmenu.bin
	$(VASM) $(VASM_OPTS) -o $@ $<

FSUAE_DBG ?= $(UAE_DBG)
FSUAE_OPT ?= $(if $(findstring true,$(FSUAE_DBG)), \
	--console-debugger --no-initial-input-grab, \
	--fullscreen --initial-input-grab)

test-fsuae-cdtv: testmenu.rom
	@$(FSUAE) $(FSUAE_OPT) testmenu.fs-uae

test-fsuae-ntsc: testmenu.rom
	@$(FSUAE) $(FSUAE_OPT) --kickstart-file=$< \
	--ntsc-mode --zoom=640x480 --force-aspect=1.3333333333333333 \
	testmenu.fs-uae

test-fsuae-pal: testmenu.rom
	@$(FSUAE) $(FSUAE_OPT) --kickstart-file=$< \
	--no-ntsc-mode --zoom=640x512 --force-aspect=1.25 \
	testmenu.fs-uae

test-rprom-slot1: testmenu.rom
	picotool load $< -t bin -o 0x10080000 && picotool reboot

winuae/$(WINUAE_ZIP):
	mkdir -p winuae && cd winuae && wget -q $(WINUAE_URL)

winuae/winuae.exe: | winuae/$(WINUAE_ZIP)
	cd winuae && unzip -q $(WINUAE_ZIP)

WINUAE_DBG ?= $(UAE_DBG)
WINUAE_WIDTH_WIN ?= $(if $(findstring true,$(WINUAE_DBG)),908,671)
WINUAE_HEIGHT_WIN ?= $(if $(findstring true,$(WINUAE_DBG)),736,514)
WINUAE_FULLSCREEN ?= $(if $(findstring true,$(WINUAE_DBG)),false,true)
WINUAE_LINEMODE ?= $(if $(findstring true,$(WINUAE_DBG)),double2,double3)
WINUAE_OVERSCAN ?= $(if $(findstring true,$(WINUAE_DBG)),ultra_csync,tv_standard)
WINUAE_OPTS = \
	-s use_debugger=$(WINUAE_DBG) \
	-s win32.start_not_captured=$(if $(findstring true,$(WINUAE_FULLSCREEN)),false,true) \
	-s gfx_width_windowed=$(WINUAE_WIDTH_WIN) \
	-s gfx_height_windowed=$(WINUAE_HEIGHT_WIN) \
	-s gfx_linemode=$(WINUAE_LINEMODE) \
	-s gfx_overscanmode=$(WINUAE_OVERSCAN) \
	-s gfx_fullscreen_amiga=$(WINUAE_FULLSCREEN)

test-winuae-cdtv: testmenu.rom | winuae/winuae.exe winuae/amiga-os-310-a600.rom
	@cd winuae && $(WINE) winuae.exe \
		-f '$(WINE_PWD)\testmenu.uae' \
		-s chipset_compatible=CDTV -s chipset=ecs_agnus \
		-s kickstart_rom_file='$(WINE_PWD)\winuae\amiga-os-310-a600.rom' \
		-s kickstart_ext_rom_file='$(WINE_PWD)\$<' \
		$(WINUAE_OPTS)

test-winuae-ntsc: testmenu.rom | winuae/winuae.exe
	@cd winuae && $(WINE) winuae.exe \
		-f '$(WINE_PWD)\testmenu.uae' \
		-s kickstart_rom_file='$(WINE_PWD)\$<' \
		-s ntsc=true $(WINUAE_OPTS)

test-winuae-pal: testmenu.rom | winuae/winuae.exe
	@cd winuae && $(WINE) winuae.exe \
		-f '$(WINE_PWD)\testmenu.uae' \
		-s kickstart_rom_file='$(WINE_PWD)\$<' \
		-s ntsc=false $(WINUAE_OPTS)

winuae-beta-just-shut-up:
	$(WINE) reg add 'HKEY_CURRENT_USER\Software\Arabuusimiehet\WinUAE' \
		/v 'Beta_Just_Shut_Up' /t REG_DWORD /d 68010 /f /reg:32

