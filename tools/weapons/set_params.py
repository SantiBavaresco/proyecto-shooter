"""setp.py <weapon_id> <json-file-or-inline> [field=value ...]
Reemplaza model_params del .tres por el JSON dado y ajusta campos simples."""
import sys, json, re
wid = sys.argv[1]; src = sys.argv[2]
path = f"/home/claude/proyecto-shooter/data/weapons/{wid}.tres"
s = open(path).read()
params = json.load(open(src)) if not src.startswith('{') else json.loads(src)
txt = "model_params = " + json.dumps(params, indent=0, ensure_ascii=False).replace("\n", "\n") + "\n"
s2 = re.sub(r"model_params = \{.*?\n\}\n", lambda m: txt, s, count=1, flags=re.S)
if s2 == s and "model_params = {}" in s:
    s2 = s.replace("model_params = {}\n", txt)
for kv in sys.argv[3:]:
    k, v = kv.split("=", 1)
    if re.search(rf"^{k} = .*$", s2, flags=re.M):
        s2 = re.sub(rf"^{k} = .*$", lambda m: f"{k} = {v}", s2, count=1, flags=re.M)
    else:
        s2 = s2.rstrip("\n") + f"\n{k} = {v}\n"
open(path, "w").write(s2)
print("ok", wid)
