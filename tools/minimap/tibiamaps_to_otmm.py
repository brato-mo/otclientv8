# Converts the tibiamaps.io minimap export into an OTClientV8 minimap.otmm.
# Download https://tibiamaps.github.io/tibia-map-data/minimap-without-markers.zip, unzip it, then run:
#   python tibiamaps_to_otmm.py minimap ../../data/minimap.otmm
# Needs Pillow (pip install pillow).
import sys, os, re, struct, zlib
from collections import Counter
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
B = 64
blocks = {}  # (bx,by,z) -> bytearray
def blk(x, y, z):
    k = (x//B, y//B, z)
    b = blocks.get(k)
    if b is None:
        b = bytearray(b'\x00\xff\x0a' * (B*B)); blocks[k] = b
    return b
cols = Counter()
for f in sorted(os.listdir(src)):
    m = re.match(r'Minimap_Color_(\d+)_(\d+)_(\d+)\.png$', f)
    if not m: continue
    X, Y, Z = map(int, m.groups())
    im = Image.open(os.path.join(src, f)).convert('RGB'); px = im.load()
    wp = os.path.join(src, f.replace('Color', 'WaypointCost'))
    wpx = Image.open(wp).convert('RGB').load() if os.path.exists(wp) else None
    W, H = im.size
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            if r == 0 and g == 0 and b == 0: continue
            cols[(r,g,b)] += 1
            c = (r//51)*36 + (g//51)*6 + (b//51)
            flags = 0
            if wpx is not None and wpx[x, y] == (255, 255, 0): flags |= 4
            ax, ay = X+x, Y+y
            bb = blk(ax, ay, Z)
            i = ((ay % B)*B + (ax % B))*3
            bb[i] = flags; bb[i+1] = c
hdr_desc = b'OTMM 1.0'
o = bytearray(struct.pack('<IHHI', 0x4D4D544F, 0, 1, 0)) + struct.pack('<H', len(hdr_desc)) + hdr_desc
struct.pack_into('<H', o, 4, len(o))
for (bx, by, z) in sorted(blocks, key=lambda k: (k[2], k[1], k[0])):
    d = zlib.compress(bytes(blocks[(bx,by,z)]), 6)
    o += struct.pack('<HHBH', bx*B, by*B, z, len(d)) + d
o += struct.pack('<HHB', 65535, 65535, 255)
open(out, 'wb').write(o)
print(len(blocks), 'blocks', len(o), 'bytes'); print(cols.most_common(25))
