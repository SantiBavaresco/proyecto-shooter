"""px.py <calibdir> <id> side|top x,y [x,y ...]  → coordenadas del arma"""
import sys, json
d, wid, view = sys.argv[1], sys.argv[2], sys.argv[3]
info = json.load(open(f"{d}/{wid}.json"))
W, H = 1600, 1000
ppm = H / info["cam_size"]
cx, cy, cz = info["center"]
for a in sys.argv[4:]:
    px, py = map(float, a.split(","))
    z = cz - (px - W/2) / ppm
    if view == "side":
        y = cy - (py - H/2) / ppm
        print(f"{a:>12} -> z={z:+.4f} y={y:+.4f}")
    else:
        x = cx + (py - H/2) / ppm
        print(f"{a:>12} -> z={z:+.4f} x={x:+.4f}")
