#!/usr/bin/env python3

import os
import re
import sys
sys.dont_write_bytecode = True
from sprite import ocs_to_rgb, load_image

ASM_FILENAME = 'header.i'
IMG_FILENAME = 'header.png'
VER_FILENAME = '../../Firmware/cmake-build-release/generated/firmware/version.i'
if __name__ == '__main__':
  if len(sys.argv) > 1:
    ASM_FILENAME = sys.argv[1]
    if len(sys.argv) > 2:
      IMG_FILENAME = sys.argv[2]
      if len(sys.argv) > 3:
        VER_FILENAME = sys.argv[3]
    else:
      IMG_FILENAME = os.path.join(os.path.dirname(sys.argv[0]), IMG_FILENAME)

data = load_image(IMG_FILENAME, 112, 37 - 6, (
  ocs_to_rgb(0xAAA), ocs_to_rgb(0x000), ocs_to_rgb(0x175), ocs_to_rgb(0xCCC)))

def set_data_pixel(x, y, c):
  w = x // 16
  b = 15 - (x % 16)
  for d in range(len(data[y][w])):
    data[y][w][d] &= ~(1 << b) & 0xFFFF
    data[y][w][d] |= ((c >> d) & 1) << b

def blt_data_tuple(x, y, t):
  for ty, r in enumerate(t):
    for tx, c in enumerate(r):
      if c >= 0:
        set_data_pixel(x + tx, y + ty, c)

def get_fw_version():
  v = [-1, -1, -1]
  if os.path.isfile(VER_FILENAME):
    with open(VER_FILENAME, 'r', encoding='ascii') as f:
      p = [
        re.compile(f'^RPROM_FIRMWARE_VERSION_{s}\\s+EQU\\s+(\\d+)\\s*$',
        re.ASCII | re.IGNORECASE) for s in ('MAJOR', 'MINOR', 'PATCH')]
      for l in f:
        for i in range(len(v)):
          m = p[i].match(l)
          if m:
            v[i] = int(m[1])
  return tuple(v)

VERSION = get_fw_version()
RELEASE = (VERSION[0] > 0) and (VERSION[1] >= 0)
_ = -1
C = 3 if RELEASE else 2
X, Y = 38, 8
blt_data_tuple(X + 0, Y + 3, (
  (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _),
  (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _),
  (_, C, C, _, C, C, C, _, C, C, _, C, C, C, _, C, C, C, C, C, _),
  (_, C, _, _, C, _, C, _, C, _, _, C, _, C, _, C, _, C, _, C, _),
  (_, C, _, _, C, C, C, _, C, _, _, C, C, C, _, C, _, C, _, C, _),
  (_, _, _, _, C, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
  ) if RELEASE else ( # 'rprom' / 'custom'
  (_, _, _, _, _, _, _, _, _, _, C, _, _, _, _, _, _, _, _, _, _),
  (_, _, _, _, _, _, _, _, _, _, C, C, _, _, _, _, _, _, _, _, _),
  (_, C, C, _, C, _, C, _, C, C, C, _, C, C, C, C, C, C, C, C, _),
  (_, C, _, _, C, _, C, _, C, _, C, _, C, _, C, C, _, C, _, C, _),
  (_, C, C, C, C, C, C, C, C, _, C, C, C, C, C, C, _, C, _, C, _),
  (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)))
DIGITS = (
  ((C, C, C), (C, _, C), (C, _, C), (C, _, C), (C, C, C)), # 0
  ((_, C, _), (C, C, _), (_, C, _), (_, C, _), (C, C, C)), # 1
  ((C, C, C), (_, _, C), (C, C, C), (C, _, _), (C, C, C)), # 2
  ((C, C, C), (_, _, C), (C, C, C), (_, _, C), (C, C, C)), # 3
  ((C, _, C), (C, _, C), (C, C, C), (_, _, C), (_, _, C)), # 4
  ((C, C, C), (C, _, _), (C, C, C), (_, _, C), (C, C, C)), # 5
  ((C, C, C), (C, _, _), (C, C, C), (C, _, C), (C, C, C)), # 6
  ((C, C, C), (_, _, C), (_, _, C), (_, _, C), (_, _, C)), # 7
  ((C, C, C), (C, _, C), (C, C, C), (C, _, C), (C, C, C)), # 8
  ((C, C, C), (C, _, C), (C, C, C), (_, _, C), (C, C, C)), # 9
  ((C, C, C), (C, _, C), (_, _, C), (_, C, _), (_, _, _), (_, C, _))) # ?
digit = lambda n : DIGITS[-1] if not 0 <= n < len(DIGITS) else DIGITS[n]
#TODO: add support for version numbers > 9
blt_data_tuple(X +  3, Y + 12, digit(VERSION[0]))
set_data_pixel(X +  7, Y + 16, C)
blt_data_tuple(X +  9, Y + 12, digit(VERSION[1]))
set_data_pixel(X + 13, Y + 16, C)
blt_data_tuple(X + 15, Y + 12, digit(VERSION[2]))

code = ''
for y, r in enumerate(data):
  code += '\t\tdc.w   \t'
  code += ','.join(f'${d:04X}' for w in r for d in w)
  code += f' ; {y:2d}{f',{y + 37 - 6:d}' if y < 6 else '':s}\n'

with open(ASM_FILENAME, 'w', encoding='ascii') as file:
  file.write(code)
print(f'{ASM_FILENAME:s}: generated from {IMG_FILENAME:s} for {VERSION}')

