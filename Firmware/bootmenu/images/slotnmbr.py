#!/usr/bin/env python3

import os
import sys
sys.dont_write_bytecode = True
from sprite import ocs_to_rgb, load_image

ASM_FILENAME = 'slotnmbr.i'
IMG_FILENAME = 'slotnmbr.png'
if __name__ == '__main__':
  if len(sys.argv) > 1:
    ASM_FILENAME = sys.argv[1]
    if len(sys.argv) > 2:
      IMG_FILENAME = sys.argv[2]
    else:
      IMG_FILENAME = os.path.join(os.path.dirname(sys.argv[0]), IMG_FILENAME)

data = load_image(IMG_FILENAME, 16, 7 * (6 // 3) * 3, ( # height * row * col
  (*ocs_to_rgb(0x05A), 0x00), # screen back (trans)
  (*ocs_to_rgb(0x002), 0xFF), # DIP IC body (black)
  (*ocs_to_rgb(0x68B), 0xFF), # slot back (focused)
  (*ocs_to_rgb(0xCCC), 0xFF)) # DIP IC pins / frame
  )

code = ''
for r in range(len(data) // 7 // 3):
  for y in range(7):
    for c in range(3):
      n = r * 3 + c
      code += f'\t\tdc.w   \t'
      code += ','.join(f'%{d:016b}' for w in data[n * 7 + y] for d in w)
      code += f' ; {y:d} "{n + 1:d}"\n'

with open(ASM_FILENAME, 'w', encoding='ascii') as file:
  file.write(code)
print(f'{ASM_FILENAME:s}: generated from {IMG_FILENAME:s}')

