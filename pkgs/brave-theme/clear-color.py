# Makes one color of a theme pack ("Cached Theme.pak", a DataPack whose
# colors resource is pairs of int32 id and ARGB) fully transparent, in place.
# Themes can't: their colors are painted onto the toolbar when packed, and
# Brave reads the pack back as it is.
# usage: clear-color.py PAK ID
import struct
import sys

COLORS = 0xFFFF - 3  # kColorsID

path, color_id = sys.argv[1], int(sys.argv[2])
data = bytearray(open(path, "rb").read())
version, encoding, count, aliases = struct.unpack_from("<IIHH", data, 0)
entries = [struct.unpack_from("<HI", data, 12 + i * 6) for i in range(count + 1)]
found = False
for i in range(count):
    if entries[i][0] != COLORS:
        continue
    for at in range(entries[i][1], entries[i + 1][1], 8):
        key, color = struct.unpack_from("<iI", data, at)
        if key == color_id:
            struct.pack_into("<I", data, at + 4, color & 0xFFFFFF)
            found = True
assert found, f"color {color_id} not in {path}"
open(path, "wb").write(data)
