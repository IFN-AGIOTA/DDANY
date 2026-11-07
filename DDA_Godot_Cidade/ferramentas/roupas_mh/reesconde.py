# recalcula só a pele escondida (esconde) de cada .json de saída, sem refazer o ajuste
import json, glob, sys, numpy as np
from roupa import pele_coberta, base
fs = sorted(glob.glob("saida/*_[mf].json")) if len(sys.argv) < 2 else sys.argv[1:]
for f in fs:
    j = json.load(open(f)); sx = f[-6]
    d = base(sx)["ubc"]
    V = np.array(j["V"]); N = np.array(j["N"])
    T = np.array(j["I"]).reshape(-1, 3)
    antes = len(j["esconde"])
    j["esconde"] = pele_coberta(d, V, T, None)
    json.dump(j, open(f, "w"))
    print(f.split("/")[-1], antes, "->", len(j["esconde"]), flush=True)
