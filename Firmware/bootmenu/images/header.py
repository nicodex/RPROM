#!/usr/bin/env python3

import os
import sys
sys.dont_write_bytecode = True
from sprite import ocs_to_rgb, load_image

ASM_FILENAME = 'header.i'
IMG_FILENAME = 'header.png'
if __name__ == '__main__':
  if len(sys.argv) > 1:
    ASM_FILENAME = sys.argv[1]
    if len(sys.argv) > 2:
      IMG_FILENAME = sys.argv[2]
    else:
      IMG_FILENAME = os.path.join(os.path.dirname(sys.argv[0]), IMG_FILENAME)

data = load_image(IMG_FILENAME, 112, 37 - 6, (
  ocs_to_rgb(0xAAA), ocs_to_rgb(0x000), ocs_to_rgb(0x175), ocs_to_rgb(0xCCC)))

#TODO: patch firmware version string into the header image

code = ''
for y, r in enumerate(data):
  code += '\t\tdc.w   \t'
  code += ','.join(f'${d:04X}' for w in r for d in w)
  code += f' ; {y:2d}{f',{y + 37 - 6:d}' if y < 6 else '':s}\n'

with open(ASM_FILENAME, 'w', encoding='ascii') as file:
  file.write(code)
print(f'{ASM_FILENAME:s}: generated from {IMG_FILENAME:s}')

