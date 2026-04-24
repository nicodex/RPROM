Classic 520 accelerator VHPOSR issue
====================================

While researching/developing a custom read-only bootmenu ROM for the 
[Classic 520](http://irixlabs.com/c520) accelerator, I stumbled over 
an issue while reading the VHPOSR register with the 68EC020 (28 MHz).

![VHPOSR - PAL LoRes - WinUAE v5.0](hposdump-pal-lores-wuae.png)
![VHPOSR - PAL LoRes - Classic 520](hposdump-pal-lores-c520.png)

Every 1280 CCKs the access to the Amiga chipset registers is blocked.
Therefore, it is practically impossible to use any chipset registers 
for slot-exact horizontal scanline synchronization, nor to draw/fill 
the bitplane data with the CPU. Ultimately, there is only one stable 
way to race the beam without DMA: manually draw sprites with the CPU.

The original [hposdump-c520.zip](hposdump-c520.zip) version has been 
attached in a [A1K thread](https://www.a1k.org/forum/threads/88444/).
Now licensed under [Zero-Clause BSD](https://spdx.org/licenses/0BSD).
