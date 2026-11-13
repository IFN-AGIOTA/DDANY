import json, numpy as np
import os
B = os.environ.get("MH_PASTA", os.path.expanduser("~/roupas_mh_trabalho")).rstrip("/") + "/"
def carregar_obj(p):
    V=[];F=[];G=[];g=None;VT=[];FT=[]
    for l in open(p,encoding='utf-8',errors='ignore'):
        if l.startswith('v '): V.append([float(x) for x in l.split()[1:4]])
        elif l.startswith('vt '): VT.append([float(x) for x in l.split()[1:3]])
        elif l.startswith('g '): g=l.split(None,1)[1].strip()
        elif l.startswith('f '):
            p_=l.split()[1:]
            F.append([int(x.split('/')[0])-1 for x in p_]); G.append(g)
            FT.append([int(x.split('/')[1])-1 if len(x.split('/'))>1 and x.split('/')[1] else -1 for x in p_])
    return np.array(V),F,G,np.array(VT) if VT else None,FT
def mh_base():
    V,F,G,_,_=carregar_obj(B+"base/base.obj")
    sk=json.load(open(B+"base/default.mhskel"))
    J={k:V[v].mean(0) for k,v in sk["joints"].items()}
    ossos={}
    for nm,b in sk["bones"].items():
        ossos[nm]={"h":J[b["head"]],"t":J[b["tail"]],"pai":b["parent"]}
    w=json.load(open(B+"base/default_weights.mhw"))["weights"]
    return V,F,G,ossos,w
def ubc(sx):
    d=json.load(open(B+"ubc/ubc_%s.json"%sx))
    d["V"]=np.array(d["V"]);d["N"]=np.array(d["N"]);d["I"]=np.array(d["I"]).reshape(-1,3)
    nv=len(d["V"]); d["B"]=np.array(d["B"]).reshape(nv,-1); d["W"]=np.array(d["W"]).reshape(nv,-1)
    d["os"]={o["nome"]:np.array(o["o"]) for o in d["ossos"]}
    return d
