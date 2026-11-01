# Leva o corpo-base do MakeHuman (e os "helpers" em volta dele) até o corpo UBC (pose + forma)
import numpy as np, json, sys
from scipy.spatial import cKDTree
from mhlib import *

def rot_alinhar(a, b):
    a = a/np.linalg.norm(a); b = b/np.linalg.norm(b)
    v = np.cross(a, b); c = np.dot(a, b)
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3) if c > 0 else -np.eye(3)
    vx = np.array([[0,-v[2],v[1]],[v[2],0,-v[0]],[-v[1],v[0],0]])
    return np.eye(3) + vx + vx@vx*(1/(1+c))

def segmentos(os_, U, topo_ubc):
    J = lambda n, k="h": os_[n][k]
    fim_dedo = {}
    for lado in "LR":
        c = [n for n in os_ if n.startswith("finger3") and n.endswith("."+lado)]
        fim_dedo[lado] = max((os_[n]["t"] for n in c), key=lambda p: abs(p[0]))
    S = {}
    S["tronco"] = (J("spine05"), J("neck01"), U["pelvis"], U["neck_01"])
    S["cabeca"] = (J("neck01"), J("head","t"), U["neck_01"], topo_ubc)
    for lado, l in (("L","l"),("R","r")):
        S["clav"+l] = (J("clavicle."+lado), J("clavicle."+lado,"t"), U["clavicle_"+l], U["upperarm_"+l])
        S["braco"+l] = (J("upperarm01."+lado), J("lowerarm01."+lado), U["upperarm_"+l], U["lowerarm_"+l])
        S["antebraco"+l] = (J("lowerarm01."+lado), J("wrist."+lado), U["lowerarm_"+l], U["hand_"+l])
        S["mao"+l] = (J("wrist."+lado), fim_dedo[lado], U["hand_"+l], U["middle_04_leaf_"+l])
        S["coxa"+l] = (J("upperleg01."+lado), J("lowerleg01."+lado), U["thigh_"+l], U["calf_"+l])
        S["canela"+l] = (J("lowerleg01."+lado), J("foot."+lado), U["calf_"+l], U["foot_"+l])
        S["pe"+l] = (J("foot."+lado), J("toe1-1."+lado), U["foot_"+l], U["ball_"+l])
    T = {}
    for k, (h, t, hu, tu) in S.items():
        R = rot_alinhar(t-h, tu-hu)
        s = np.linalg.norm(tu-hu)/np.linalg.norm(t-h)
        T[k] = (R, s, h, hu)
    return T

def seg_do_osso(nm, os_):
    m = {"spine05":"tronco","spine04":"tronco","spine03":"tronco","spine02":"tronco","spine01":"tronco","root":"tronco",
         "neck01":"cabeca","neck02":"cabeca","neck03":"cabeca","head":"cabeca"}
    n = nm
    while n is not None:
        if n in m: return m[n]
        lado = "l" if n.endswith(".L") else ("r" if n.endswith(".R") else None)
        if lado:
            b = n[:-2]
            if b == "clavicle": return "clav"+lado
            if b in ("shoulder01","upperarm01","upperarm02"): return "braco"+lado
            if b in ("lowerarm01","lowerarm02"): return "antebraco"+lado
            if b == "wrist" or b.startswith("finger") or b.startswith("metacarpal"): return "mao"+lado
            if b in ("upperleg01","upperleg02"): return "coxa"+lado
            if b in ("lowerleg01","lowerleg02"): return "canela"+lado
            if b == "foot" or b.startswith("toe"): return "pe"+lado
            if b == "pelvis": return "tronco"
        n = os_[n]["pai"] if n in os_ else None
    return "tronco"

def amostrar(d, por=6):
    V = d["V"]; I = d["I"]; N = d["N"]
    rng = np.random.default_rng(1)
    a = rng.random((por, 2)); f = a.sum(1) > 1; a[f] = 1 - a[f]
    bc = np.stack([1-a[:,0]-a[:,1], a[:,0], a[:,1]], 1)
    bc = np.vstack([bc, [[1/3,1/3,1/3],[1,0,0],[0,1,0],[0,0,1]]])
    P = np.einsum('kj,tjd->tkd', bc, V[I]).reshape(-1,3)
    Nn = np.einsum('kj,tjd->tkd', bc, N[I]).reshape(-1,3)
    Nn /= np.linalg.norm(Nn,axis=1,keepdims=True)+1e-9
    tri = np.repeat(np.arange(len(I)), len(bc)); BC = np.tile(bc, (len(I),1))
    return P, Nn, tri, BC

def normais(V, F):
    N = np.zeros_like(V)
    for f in F:
        for k in range(1, len(f)-1):
            a,b,c = V[f[0]],V[f[k]],V[f[k+1]]
            n = np.cross(b-a, c-a)
            N[f[0]]+=n; N[f[k]]+=n; N[f[k+1]]+=n
    return N/(np.linalg.norm(N,axis=1,keepdims=True)+1e-9)

def ajustar(sx, iters=20, verbose=True):
    V0, F, G, os_, W = mh_base()
    d = ubc(sx)
    U = d["os"]
    topo = np.array([0.0, d["V"][:,1].max(), U["Head"][2]])
    T = segmentos(os_, U, topo)
    nomes = list(T.keys()); ix = {k:i for i,k in enumerate(nomes)}
    nv = len(V0)
    Wseg = np.zeros((nv, len(nomes)))
    for osso, lst in W.items():
        sgi = ix[seg_do_osso(osso, os_)]
        for vi, w in lst:
            Wseg[vi, sgi] += w
    sem = Wseg.sum(1) == 0
    # vértices sem peso (helpers sem peso): pega o do vizinho de corpo mais perto
    com = np.where(~sem)[0]
    kd = cKDTree(V0[com])
    _, j = kd.query(V0[sem]); Wseg[sem] = Wseg[com[j]]
    Wseg /= Wseg.sum(1, keepdims=True)
    # LBS
    V1 = np.zeros_like(V0); Rv = np.zeros((nv,3,3))
    for k,(R,s,h,hu) in T.items():
        w = Wseg[:, ix[k]][:,None]
        V1 += w * (((V0-h) @ R.T) * s + hu)
        Rv += w[:,:,None] * R
    # ortonormaliza as rotações por vértice
    u, _, vt = np.linalg.svd(Rv); Rv = u @ vt
    escala = np.einsum('vk,k->v', Wseg, np.array([T[k][1] for k in nomes]))
    corpo_f = [f for f,g in zip(F,G) if g == "body"]
    corpo_v = np.array(sorted({v for f in corpo_f for v in f}))
    # vizinhos (malha do corpo)
    viz = [set() for _ in range(nv)]
    for f in corpo_f:
        for a in range(len(f)):
            viz[f[a]].add(f[a-1]); viz[f[a]].add(f[(a+1)%len(f)])
    # matriz de média dos vizinhos (esparsa)
    from scipy.sparse import csr_matrix
    rows=[];cols=[]
    for v in corpo_v:
        for u_ in viz[v]: rows.append(v); cols.append(u_)
    A = csr_matrix((np.ones(len(rows)),(rows,cols)), shape=(nv,nv))
    deg = np.asarray(A.sum(1)).ravel(); deg[deg==0]=1
    P, PN, ptri, pbc = amostrar(d)
    kdp = cKDTree(P)
    hel = np.setdiff1d(np.arange(nv), corpo_v)
    V = V1.copy()
    for it in range(iters):
        Vb = V[corpo_v]
        Nb = normais(V, corpo_f)[corpo_v]
        dist, jj = kdp.query(Vb, k=8)
        best = np.full(len(Vb), -1)
        for c in range(8):
            ok = (best < 0) & ((PN[jj[:,c]] * Nb).sum(1) > 0.3)
            best[ok] = jj[ok, c]
        val = best >= 0
        alvo = np.where(val[:,None], P[np.maximum(best,0)], Vb)
        D = np.zeros((nv,3)); D[corpo_v] = alvo - Vb
        wv = np.zeros(nv); wv[corpo_v] = val.astype(float)
        # sentido contrário: cada vértice do corpo UBC puxa o vértice do MakeHuman mais perto (chega nas pontas:
        # seios, dedos dos pés, nariz...)
        UV_ = d["V"]; UN = d["N"]
        kdm = cKDTree(Vb)
        du, jm = kdm.query(UV_)
        okr = ((Nb[jm] * UN).sum(1) > 0.3) & (du < 0.08)
        Sr = np.zeros((len(Vb),3)); Cr = np.zeros(len(Vb))
        np.add.at(Sr, jm[okr], UV_[okr] - Vb[jm[okr]])
        np.add.at(Cr, jm[okr], 1.0)
        tem = Cr > 0
        Drev = np.zeros((len(Vb),3)); Drev[tem] = Sr[tem] / Cr[tem][:,None]
        if it >= 2:
            Df = D[corpo_v]; wf = val.astype(float); wr = tem.astype(float)
            D[corpo_v] = (Df*wf[:,None] + Drev*wr[:,None]) / np.maximum(wf+wr, 1e-9)[:,None]
            wv[corpo_v] = np.maximum(wf, wr)
        lam = 4.0 * (0.6 ** it) + 0.05
        X = D.copy()
        for _ in range(30):
            media = (A @ X) / deg[:,None]
            X = (wv[:,None]*D + lam*media) / (wv[:,None] + lam)
            X[hel] = 0
        # helpers seguem o deslocamento dos vértices do corpo mais perto
        kdb = cKDTree(V[corpo_v])
        dd, jb = kdb.query(V[hel], k=4)
        wb = 1/(dd+1e-4); wb/=wb.sum(1,keepdims=True)
        X[hel] = (X[corpo_v][jb] * wb[:,:,None]).sum(1)
        V = V + X
        if verbose:
            e = np.linalg.norm(alvo - Vb, axis=1)
            print(sx, "iter", it, "erro médio %.4f m · p95 %.4f · inválidos %d" % (e[val].mean(), np.percentile(e[val],95), (~val).sum()))
    return {"V0":V0, "V":V, "R":Rv, "esc":escala, "corpo_v":corpo_v, "corpo_f":corpo_f, "ubc":d, "amostras":(P,PN,ptri,pbc), "kdp":kdp}

if __name__ == "__main__":
    import pickle
    for sx in sys.argv[1:] or ["m"]:
        r = ajustar(sx)
        pickle.dump({k:r[k] for k in ("V0","V","R","esc","corpo_v")}, open(B+"base_%s.pkl"%sx,"wb"))
