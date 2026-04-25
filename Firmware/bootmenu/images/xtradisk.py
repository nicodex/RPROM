#!/usr/bin/env python3

import os
import sys
sys.dont_write_bytecode = True
from sprite import ocs_to_rgb, load_image

ASM_FILENAME = 'xtradisk.i'
IMG_FILENAME = 'xtradisk.png'
if __name__ == '__main__':
  if len(sys.argv) > 1:
    ASM_FILENAME = sys.argv[1]
    if len(sys.argv) > 2:
      IMG_FILENAME = sys.argv[2]
    else:
      IMG_FILENAME = os.path.join(os.path.dirname(sys.argv[0]), IMG_FILENAME)

data = load_image(IMG_FILENAME, 32, 32, (
  (*ocs_to_rgb(0xAAA), 0x00),
  (*ocs_to_rgb(0x000), 0xFF),
  (*ocs_to_rgb(0x135), 0xFF),
  (*ocs_to_rgb(0xCCC), 0xFF)))

code = ''
for y, r in enumerate(data):
  code += '\t\tdc.w   \t'
  code += ','.join(f'%{d:016b}' for w in r for d in w)
  code += f' ; {y:2d}\n'

with open(ASM_FILENAME, 'w', encoding='ascii') as file:
  file.write(code)
print(f'{ASM_FILENAME:s}: generated from {IMG_FILENAME:s}')

