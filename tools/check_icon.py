#!/usr/bin/env python3
"""Fails if the exe does not contain the images from icon.ico."""
import struct
import sys

exe = open(sys.argv[1], "rb").read()
ico = open(sys.argv[2], "rb").read()
expected = sorted(
    struct.unpack("<I", ico[6 + i * 16 + 8 : 6 + i * 16 + 12])[0]
    for i in range(struct.unpack("<H", ico[4:6])[0])
)
pe = struct.unpack("<I", exe[0x3C:0x40])[0]
sections = struct.unpack("<H", exe[pe + 6 : pe + 8])[0]
optional = struct.unpack("<H", exe[pe + 20 : pe + 22])[0]
rsrc = next(
    struct.unpack("<I", exe[o + 20 : o + 24])[0]
    for o in (pe + 24 + optional + i * 40 for i in range(sections))
    if exe[o : o + 8].rstrip(b"\0") == b".rsrc"
)


def entries(offset):
    named, ids = struct.unpack("<HH", exe[rsrc + offset + 12 : rsrc + offset + 16])
    return [struct.unpack("<II", exe[rsrc + offset + 16 + i * 8 : rsrc + offset + 24 + i * 8]) for i in range(named + ids)]


actual = []
for type_id, type_dir in entries(0):
    if type_id == 3:
        for _, name_dir in entries(type_dir & 0x7FFFFFFF):
            for _, leaf in entries(name_dir & 0x7FFFFFFF):
                actual.append(struct.unpack("<I", exe[rsrc + leaf + 4 : rsrc + leaf + 8])[0])
actual.sort()
print("icon images in exe:", actual, "expected:", expected)
sys.exit(0 if actual == expected else 1)
