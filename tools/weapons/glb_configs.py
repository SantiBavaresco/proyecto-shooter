"""Parámetros de los modelos .glb de armas (alineación, piezas, marcadores, manos).
Uso: python3 tools/weapons/glb_configs.py [ids]  → escribe model_params en data/weapons/<id>.tres"""
import json, subprocess, sys
import os
S = os.path.dirname(os.path.abspath(__file__))
POSE_RIFLE={"top": [0, -0.045, 0.03], "bottom": [0, -0.128, 0.058], "r": 0.016, "trigger": [0, -0.05, -0.038], "left": "forend", "lc": [0, -0.004, -0.3], "lr": 0.03}
POSE_PISTOL={"top": [0, -0.011, 0.026], "bottom": [0, -0.1, 0.056], "r": 0.016, "trigger": [0, -0.024, -0.03], "left": "pistol"}
W="res://assets/models/weapons/"
C={
 "akm": {"shape":"glb","scene":W+"akmn/akmn.glb","rot":[0,90,0],"scale":0.1,"offset":[0,-0.0795,-0.12],
    "parts":{"Mag":["mag_low"],"Charging":["__ninguna__"]},"pivots":{"Mag":[0,-0.03,-0.13],"Charging":[0.024,0.044,-0.151]},
    "metas":{"Charging":{"knob":[0.006,0,0]}},
    "sight":[0,0.045,-0.514],"eye_relief":0.63,"muzzle":[0,0,-0.551],"ejection":[0.016,0.0165,-0.174],
    "pose":{"top":[0,-0.034,0.045],"bottom":[0,-0.125,0.063],"r":0.015,"trigger":[0,-0.04,-0.004],"left":"forend","lc":[0,-0.003,-0.25],"lr":0.028}},
 "m14ebr": {"shape":"glb","scene":W+"m14/m14.glb","rot":[0,-90,0],"scale":0.09,"offset":[0,-0.2068,-0.13],"hide":["mag_extend","bullet"],
    "parts":{"Mag":["mag_main","mag_026","j_mag_762n"],"Charging":["j_charging_handle"]},
    "pivots":{"Mag":[0,-0.066,-0.159],"Charging":[0.024,0.022,-0.05]},"metas":{"Charging":{"knob":[0.006,0,0]}},
    "shift":[{"match":["tag_rail"],"by":[0,-0.06,0]},{"match":["sight_scope","zoom_wheel"],"by":[0,-0.088,0]}],
    "scope_lens":{"pos":[0,0.0747,0.009],"d":0.034},
    "sight":[0,0.0747,0.008],"eye_relief":0.07,"muzzle":[0,0,-0.6725],"ejection":[0.015,0.0147,-0.057],
    "pose":{"top":[0,-0.0476,0.0458],"bottom":[0,-0.1172,0.1044],"r":0.018,"trigger":[0,-0.0806,0.0018],"left":"forend","lc":[0,-0.022,-0.35],"lr":0.025}},
 "xm2010": {"shape":"glb","scene":W+"xm2010/xm2010.glb","rot":[0,-90,0],"scale":0.09,"offset":[0,-0.1565,-0.235],"hide":["bullet"],
    "parts":{"Mag":["mag_main","mag_00","j_follower"],"Bolt":["bolt_main","j_bolt","j_boltend","j_boltpin"]},
    "pivots":{"Mag":[0,-0.0372,-0.128],"Bolt":[0,0,0.017]},"metas":{"Bolt":{"knob":[0.04,-0.0767,0.006]}},
    "scope_lens":{"pos":[0,0.0572,0.06],"d":0.036},
    "sight":[0,0.0572,0.058],"eye_relief":0.095,"hip":[0.13,-0.15,-0.34],"muzzle":[0,0,-0.82],"ejection":[0.015,0.015,0.0],
    "pose":{"top":[0,-0.057,0.0503],"bottom":[0,-0.152,0.0938],"r":0.016,"trigger":[0,-0.0688,0.0265],"left":"forend","lc":[0,-0.005,-0.47],"lr":0.03}},
 "sten": {"shape":"glb","scene":W+"sten/sten.glb","rot":[0,90,0],"scale":0.304,"offset":[0,-0.003,-0.38],
    "parts":{"Mag":["cube_003","cube_004","cube_005","bolt head/","plane_012"],"Charging":["shutter"]},
    "pivots":{"Mag":[-0.03,-0.001,-0.243],"Charging":[0.016,0.0215,-0.055]},
    "metas":{"Charging":{"knob":[0.006,0,0],"cycle":0.045},"Mag":{"roll":-90.0,"grab":[-0.06,0,0]}},"side_mag_wrist":-35.0,
    "shift":[{"match":["aim_2_"],"by":[0,0.004,0]}],
    "sight":[0,0.0346,-0.28],"eye_relief":0.43,"muzzle":[0,0,-0.471],"ejection":[0.012,0.01,-0.2],
    "pose":{"top":[0,-0.043,0.052],"bottom":[0,-0.099,0.067],"r":0.012,"trigger":[0,-0.073,0.008],"left":"forend","lc":[0,-0.001,-0.31],"lr":0.018}},
 "pleter91": {"shape":"glb","scene":W+"pleter91/pleter91.glb","rot":[0,180,0],"scale":1.0,"offset":[0,-0.0466,0],
    "parts":{"Mag":["ero_magazine"],"Charging":["pleter_bolt"]},"pivots":{"Mag":[0,-0.010,-0.0587],"Charging":[0,0.0222,-0.0048]},
    "metas":{"Charging":{"knob":[0,0.004,0],"cycle":0.03}},
    "sight":[0,0.0204,-0.0964],"eye_relief":0.26,"muzzle":[0,0,-0.2525],"ejection":[0.012,0.0,-0.05],
    "pose":{"top":[0,-0.0567,0.0418],"bottom":[0,-0.1106,0.0669],"r":0.015,"trigger":[0,-0.055,0.0023],"left":"forend","lc":[0,-0.03,-0.16],"lr":0.02},"hip":[0.12,-0.105,-0.29]},
 "andrews": {"shape":"glb","scene":W+"andrews/andrews.glb","rot":[0,90,0],"scale":1.0,"offset":[0.089,-0.1266,0],"hide":["_001","bullets"],
    "parts":{"Mag":["magazineshort","magazineholder","magazinepusher","magazinespring"],"Charging":["andrewsmachinegun_ring/","andrewsmachinegun_ringstick/","andrewsmachinegun_bolt/"]},
    "pivots":{"Mag":[-0.031,-0.002,-0.021],"Charging":[0,0.0008,0.1766]},
    "metas":{"Charging":{"knob":[0,0,0.005]},"Mag":{"roll":-90.0,"grab":[-0.06,0,0]}},"side_mag_wrist":-35.0,
    "sight":[0,0.0402,-0.1566],"eye_relief":0.45,"muzzle":[0,0,-0.2018],"ejection":[0.035,0.0008,-0.021],
    "pose":{"top":[0,-0.0354,0.1611],"bottom":[0,-0.1232,0.1662],"r":0.016,"trigger":[0,-0.0483,0.1094],"left":"forend","lc":[0,0,-0.12],"lr":0.035}},
 "revolver45": {"shape":"glb","scene":W+"revolver/revolver.glb","rot":[0,180,0],"scale":1.0,"offset":[0,0.0079,-0.055],
    "parts":{"Crane":["/arm","magazine","axis"],"Rounds":["cartrige","bullet"]},"pivots":{"Crane":[-0.012,-0.013,-0.085],"Rounds":[-0.012,-0.013,-0.085]},
    "sight":[0,0.0413,-0.168],"eye_relief":0.568,"muzzle":[0,0.02,-0.171],"ejection":[0,0.02,-0.055],
    "pose":{"top":[0,-0.0103,0.0276],"bottom":[0,-0.117,0.0578],"r":0.016,"trigger":[0,-0.0512,-0.0418],"left":"pistol"}},
}
if __name__=="__main__":
    ids = sys.argv[1].split(",") if len(sys.argv)>1 else list(C)
    for i in ids:
        json.dump(C[i], open(f"{S}/cfg_{i}.json","w"))
        subprocess.run(["python3", f"{S}/set_params.py", i, f"{S}/cfg_{i}.json"])
