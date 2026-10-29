import sys, json
from PIL import Image, ImageDraw
out, ids = sys.argv[1], sys.argv[2].split(',')
for id in ids:
    try: info = json.load(open(f"{out}/{id}.json"))
    except Exception as e: print("no json", id, e); continue
    for view in ("side", "top"):
        im = Image.open(f"{out}/{id}_{view}.png").convert('RGB'); W, H = im.size
        d = ImageDraw.Draw(im)
        cz, cy, cx = info["center"][2], info["center"][1], info["center"][0]
        s = info["cam_size"]; ppm = H / s  # px per meter
        # side: screen x = -(z - cz), screen y = -(y - cy); top (up=-X): screen x = -(z-cz), screen y = (x - cx)
        def P(v):
            if view == "side": return (W/2 - (v[2]-cz)*ppm, H/2 - (v[1]-cy)*ppm)
            return (W/2 - (v[2]-cz)*ppm, H/2 + (v[0]-cx)*ppm)
        import math
        # grilla cada 1 cm (cada 5 cm más fuerte), en coordenadas del arma
        z0 = math.floor((cz - W/2/ppm)*100); z1 = math.ceil((cz + W/2/ppm)*100)
        for zc in range(z0, z1+1):
            x = W/2 - (zc/100 - cz)*ppm
            col = (120,120,200) if zc % 5 == 0 else (200,200,225)
            if zc % 10 == 0: col = (40,40,160)
            d.line([(x,0),(x,H)], fill=col, width=1)
            if zc % 10 == 0: d.text((x+2, 2), f"z{zc/100:.1f}", fill=(0,0,120))
        ax = 1 if view == "side" else 0
        a0 = info["center"][ax]
        y0 = math.floor((a0 - H/2/ppm)*100); y1 = math.ceil((a0 + H/2/ppm)*100)
        for yc in range(y0, y1+1):
            y = H/2 - (yc/100 - a0)*ppm if view == "side" else H/2 + (yc/100 - a0)*ppm
            col = (120,120,200) if yc % 5 == 0 else (200,200,225)
            if yc % 10 == 0: col = (40,40,160)
            d.line([(0,y),(W,y)], fill=col, width=1)
            if yc % 5 == 0: d.text((2, y+1), f"{'y' if view=='side' else 'x'}{yc/100:.2f}", fill=(0,0,120))
        # origen
        o = P([0,0,0]); d.ellipse([o[0]-5,o[1]-5,o[0]+5,o[1]+5], outline=(0,0,0), width=2)
        cols = {"Sight":(255,0,0),"Muzzle":(255,120,0),"Ejection":(0,160,0),"Mag":(200,0,200),"Charging_knob":(0,200,200),"Bolt_knob":(0,200,200),"grip_top":(0,0,255),"trigger":(255,0,255),"forend":(0,120,255)}
        for k, v in info["markers"].items():
            c = cols.get(k, (60,60,60)); p = P(v)
            d.ellipse([p[0]-4,p[1]-4,p[0]+4,p[1]+4], fill=c); d.text((p[0]+5,p[1]-12), k, fill=c)
        im.save(f"{out}/{id}_{view}_g.png")
    print(id, "aabb", info["aabb"], "markers", info["markers"])
