import json, glob, numpy as np
from roupa import medir_grossura, base
for f in sorted(glob.glob("saida/*_[mf].json")):
    j = json.load(open(f)); sx = f[-6]
    j["grossura"] = medir_grossura(base(sx)["ubc"], np.array(j["V"]))
    j["perto"] = medir_grossura(base(sx)["ubc"], np.array(j["V"]), 5)
    json.dump(j, open(f, "w"))
    if j["grossura"] > 0: print(f.split("/")[-1], round(j["grossura"], 4))
