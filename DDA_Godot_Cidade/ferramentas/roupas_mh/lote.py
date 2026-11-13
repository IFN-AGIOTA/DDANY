import json, os, sys, traceback
from catalogo import JOBS
from roupa import ajustar_roupa
from mhlib import B
feitos = 0
for job in JOBS:
    nm, _, parte = job.partition("__")
    for sx in "mf":
        dst = B + "saida/%s_%s.json" % (job, sx)
        if os.path.exists(dst) and os.environ.get("REFAZER") != "1":
            continue
        try:
            r = ajustar_roupa(B + "roupas/" + nm, sx, parte=parte)
            json.dump(r, open(dst, "w"))
            print("OK", job, sx, "tris", len(r["I"])//3, "esconde", len(r["esconde"]), flush=True)
        except Exception as e:
            print("FALHOU", job, sx, e, flush=True)
print("FIM LOTE", flush=True)
