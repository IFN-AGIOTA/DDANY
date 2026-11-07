# calçado fechado: o pé inteiro (região PE do corpo) some embaixo dele (o dedão não fura a ponta da bota)
import json, numpy as np
from catalogo import I, pecas
from roupa import base
feitos = []
for num, iid, nome, sig, slot, pc, ex in I:
    if slot != "pes": continue
    for p in pecas(pc):
        for sx in "mf":
            f = "saida/%s_%s.json" % (p, sx)
            j = json.load(open(f))
            d = base(sx)["ubc"]
            reg = (np.array(d["C"]) * 15 + 0.5).astype(int)
            pe = set(np.where(reg == 10)[0].tolist())
            antes = len(j["esconde"])
            j["esconde"] = sorted(set(j["esconde"]) | pe)
            json.dump(j, open(f, "w"))
            feitos.append(p)
            print(p, sx, antes, "->", len(j["esconde"]))
print(",".join(sorted(set(feitos))))
