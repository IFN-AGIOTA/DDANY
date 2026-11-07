# CAMADAS (1.11): para cada peça e corpo, grava no .json de saída:
#   ib  = o vértice do corpo mais perto de cada vértice da peça  ·  dv = a distância dele até a pele (na normal, m)
#   esp = espessura da peça em cada vértice do corpo (mm, 0..255): até onde a peça vai "por fora" daquele ponto
# O jogo usa para pôr o colete por fora da camisa e a camisa por fora da calça (jogador/roupa.gdshader).
import json, glob, sys, numpy as np
from scipy.spatial import cKDTree
from roupa import base
fs = sys.argv[1:] or sorted(glob.glob("saida/*_[mf].json"))
for f in fs:
    j = json.load(open(f)); sx = f[-6]
    d = base(sx)["ubc"]; U = d["V"]; UN = d["N"]
    P = np.array(j["V"])
    kdu = cKDTree(U)
    _, ib = kdu.query(P)
    dv = ((P - U[ib]) * UN[ib]).sum(1)
    esp = np.zeros(len(U))
    kdp = cKDTree(P)
    for u, js in enumerate(kdp.query_ball_point(U, 0.16)):
        if not js: continue
        q = P[js] - U[u]; h = q @ UN[u]
        lat = np.linalg.norm(q - np.outer(h, UN[u]), axis=1)
        m = (lat < 0.03) & (h > -0.02) & (h < 0.15)
        if m.any(): esp[u] = max(0.0, h[m].max())
    j["ib"] = ib.tolist(); j["dv"] = np.round(dv, 4).tolist()
    j["esp"] = np.clip(np.round(esp * 1000), 0, 255).astype(int).tolist()
    json.dump(j, open(f, "w"))
    print(f.split("/")[-1], "esp máx %d mm" % max(j["esp"]), flush=True)
