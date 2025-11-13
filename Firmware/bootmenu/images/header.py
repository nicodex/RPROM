#!/usr/bin/env python3

import png
import sys

ASM_FILENAME = 'header.i'
IMG_FILENAME = 'header.png'
IMG_WIDTH = 7 * 16
IMG_HEIGHT = 37
ocs_to_rgb = lambda c : tuple(((c >> i) & 0x0F) * 0x11 for i in (8, 4, 0))
IMG_PALETTE = (
  (*ocs_to_rgb(0x033), 0x00), # BGCOLOR0 screen background
  (*ocs_to_rgb(0x002), 0xFF), # CHCOLOR1 cursor/header black
  (*ocs_to_rgb(0x286), 0xFF), # CHCOLOR2 cursor/header green
  (*ocs_to_rgb(0xCCC), 0xFF)) # CHCOLOR3 cursor/header white
# PNG chunk 'tRNS' = 0 : '0000000174524E530040E6D866'

width, height, pixels, metadata = png.Reader(filename=IMG_FILENAME).read()
if (width != IMG_WIDTH) or (height != IMG_HEIGHT):
  sys.exit(f'{IMG_FILENAME}: image size must be {IMG_WIDTH:d}x{IMG_HEIGHT:d}')
if 'palette' not in metadata:
  sys.exit(f'{IMG_FILENAME}: image has to be palette-based')
palette = metadata['palette']
try: # PNG writer/optimizer might reorder the palette colors
  index_to_color = tuple(palette.index(rgb) for rgb in IMG_PALETTE)
except ValueError:
  sys.exit(f'{IMG_FILENAME}: image palette color missmatch')
code = ''
for row in pixels:
  line = []
  for sprite in range(IMG_WIDTH // 16):
    SPRxDATA = 0
    SPRxDATB = 0
    for bit in range(16):
      color = index_to_color[row[sprite * 16 + bit]]
      SPRxDATA = (SPRxDATA << 1) | ((color >> 0) & 0x01)
      SPRxDATB = (SPRxDATB << 1) | ((color >> 1) & 0x01)
    line.append((SPRxDATA << 16) | SPRxDATB)
  code += f'\t\tdc.l\t{','.join(f'${data:08X}' for data in line)}\n'

with open(ASM_FILENAME, 'w', encoding='ascii') as asm:
  asm.write(code)
print(f'{ASM_FILENAME}: generated from {IMG_FILENAME}')

