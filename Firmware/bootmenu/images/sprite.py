#!/usr/bin/env python3

import array
import math
import png
import sys

ocs_to_rgb = lambda c : tuple(((c >> i) & 0x0F) * 0x11 for i in (8, 4, 0))

def load_image(filename, width, height, palette):
  x, y, p, m = png.Reader(filename=filename).read()
  if (x != width) or (y != height):
    sys.exit(f'{filename:s}: image size must be {width:d}x{height:d}')
  if 'palette' not in m:
    sys.exit(f'{filename:s}: image has to be palette-based')
  try:
    cmap = tuple(palette.index(c) for c in m['palette'])
  except ValueError:
    # most likely the image editor/writer/optimizer replaced RGB0 with 0000
    # pngcrush -rem tRNS -c 3 -noreduce -speed -force sprite.png sprite_.png
    # pngcrush -trns 0 170 170 170 0 -c 3 -brute -force sprite_.png sprite.png
    sys.exit(f'{filename:s}: image palette color missmatch')
  DEPTH = int(math.ceil(math.log2(len(palette))))
  WORDS = (width + 15) // 16
  data = tuple(tuple(
    array.array('H', [0] * DEPTH)
    for w in range(WORDS))
    for y in range(height))
  for y, r in enumerate(p):
    for w in range(WORDS):
      for d in range(DEPTH):
        for b in range(16):
          x = w * 16 + b
          c = 0 if x >= width else cmap[r[x]]
          data[y][w][d] = (data[y][w][d] << 1) | ((c >> d) & 0x01)
  return data

