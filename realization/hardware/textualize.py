#!/usr/bin/env python3
import sys
import struct
import numpy as np

if len(sys.argv) <3:
    raise RuntimeError

input_filename = sys.argv[1]
output_filename = sys.argv[2]

with open(input_filename, "rb") as frref, open(output_filename, "w") as fwref:
    _ = frref.read(8)
    binary_image = frref.read()

    [fwref.write(np.binary_repr(n, 8) + '\n') for n in struct.unpack(str(len(binary_image)) + "B", binary_image)]
