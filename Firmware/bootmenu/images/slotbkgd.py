#!/usr/bin/env python3

import os
import sys
sys.dont_write_bytecode = True
from sprite import ocs_to_rgb, load_image

ASM_FILENAME = 'slotbkgd.i'
IMG_FILENAME = 'slotbkgd.png'
if __name__ == '__main__':
  if len(sys.argv) > 1:
    ASM_FILENAME = sys.argv[1]
    if len(sys.argv) > 2:
      IMG_FILENAME = sys.argv[2]
    else:
      IMG_FILENAME = os.path.join(os.path.dirname(sys.argv[0]), IMG_FILENAME)

data = load_image(IMG_FILENAME, 32, 32, (
  (*ocs_to_rgb(0x05A), 0x00), # screen back (trans)
  (*ocs_to_rgb(0x002), 0xFF), # DIP IC body (black)
  (*ocs_to_rgb(0x68B), 0xFF), # slot back (focused)
  (*ocs_to_rgb(0xCCC), 0xFF)) # DIP IC pins / frame
  )

code = ''
for y, r in enumerate(data):
  code += '\t\tdc.w   \t'
  code += ','.join(f'%{d:016b}' for w in r for d in w)
  code += f' ; {y:2d}{f',{y - 4:d}' if 4 <= y <= 10 else '':s}\n'

with open(ASM_FILENAME, 'w', encoding='ascii') as file:
  file.write(code)
print(f'{ASM_FILENAME:s}: generated from {IMG_FILENAME:s}')

