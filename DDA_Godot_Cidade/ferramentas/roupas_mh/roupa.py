# Ajusta uma roupa do MakeHuman (.mhclo + .obj) ao corpo UBC já ajustado (base_<sx>.pkl)
import numpy as np, json, os, sys, pickle, re
from scipy.spatial import cKDTree
from mhlib import carregar_obj, ubc, B
from ajuste import amostrar

def ler_mhclo(p):
    cab = {}; refs = []; dele = []; modo = None
    for l in open(p, encoding='utf-8', errors='ignore'):
        s = l.strip()
        if not s or s.startswith('#'): continue
        if modo == 'v':
            t = s.split()
            if re.match(r'^-?\d', t[0]) and (len(t) in (1, 9)):
                refs.append([float(x) for x in t]); continue
            if refs:
                modo = None          # acabaram os pontos (antes deles, linhas de cabeçalho não encerram a lista)
        if modo == 'd':
            if re.match(r'^\d', s):
                t = s.split(); k = 0
                while k < len(t):
                    if k + 2 < len(t) and t[k+1] == '-':
                        dele.extend(range(int(t[k]), int(t[k+2])+1)); k += 3
                    else:
                        dele.append(int(t[k])); k += 1
                continue
            modo = None
        t = s.split()
        if t[0] == 'verts': modo = 'v'; continue
        if t[0] == 'delete_verts': modo = 'd'; continue
        if t[0] in ('x_scale','y_scale','z_scale'): cab[t[0]] = (int(t[1]), int(t[2]), float(t[3]))
        elif t[0] in ('obj_file','material','name'): cab[t[0]] = t[1]
    return cab, refs, set(dele)

def ler_mhmat(p):
    m = {}
    if os.path.exists(p):
        for l in open(p, encoding='utf-8', errors='ignore'):
            t = l.split(None, 1)
            if len(t) == 2: m[t[0]] = t[1].strip()
    return m

# pele coberta: o vértice do corpo some se a roupa passa logo "por fora" dele (na direção da normal, até 6 cm, com
# até 2,2 cm de lado) E todos os vizinhos dele também estão cobertos (a borda da roupa nunca mostra buraco)
_viz = {}
def pele_coberta(d, P, T, NP=None):
    """pele escondida: um vértice do corpo some se, logo "por fora" dele (na direção da normal, de -5 a +5 cm, com até
    2,2 cm de lado), passa um pedaço de roupa VIRADO PARA O MESMO LADO (a aba do boné, de lado para o rosto, não
    conta) E todos os vizinhos dele também estão cobertos (a borda da roupa nunca mostra buraco)"""
    key = id(d)
    if key not in _viz:
        nv = len(d["V"]); viz = [set() for _ in range(nv)]
        for a, b_, c in d["I"]:
            viz[a].update((b_, c)); viz[b_].update((a, c)); viz[c].update((a, b_))
        _viz[key] = viz
    viz = _viz[key]
    T = np.array(T, int).reshape(-1, 3) if len(T) else np.zeros((0, 3), int)
    usados = np.unique(T.ravel())
    pts = [P[usados]]
    if NP is None:
        NP = np.zeros_like(P)
        for t in T:
            n = np.cross(P[t[1]]-P[t[0]], P[t[2]]-P[t[0]])
            NP[t] += n
        NP /= np.linalg.norm(NP, axis=1, keepdims=True) + 1e-9
    nrm = [NP[usados]]
    rng = np.random.default_rng(3)
    for t in T:
        a, b_, c = P[t[0]], P[t[1]], P[t[2]]
        cr = np.cross(b_-a, c-a); area = np.linalg.norm(cr) / 2
        n = int(min(400, area / 6e-5))
        if n > 0:
            r = rng.random((n, 2)); f = r.sum(1) > 1; r[f] = 1 - r[f]
            pts.append(a + np.outer(r[:,0], b_-a) + np.outer(r[:,1], c-a))
            nrm.append(np.tile(cr / (np.linalg.norm(cr) + 1e-12), (n, 1)))
    P = np.vstack(pts); NP = np.vstack(nrm)
    kd = cKDTree(P)
    V = d["V"]; N = d["N"]
    cob = np.zeros(len(V), bool)
    lst = kd.query_ball_point(V, 0.06)
    for i, js in enumerate(lst):
        if not js: continue
        q = P[js] - V[i]
        h = q @ N[i]
        lat = np.linalg.norm(q - np.outer(h, N[i]), axis=1)
        alinh = np.abs(NP[js] @ N[i]) > 0.45
        if np.any((h > -0.05) & (h < 0.05) & (lat < 0.022) & alinh):
            cob[i] = True
    # nada abaixo da parte mais baixa da peça (+1 cm) some: embaixo da aba do boné o rosto continua
    cob &= V[:, 1] > P[:, 1].min() + 0.01
    final = cob.copy()
    for i in np.where(cob)[0]:
        if not all(cob[j] for j in viz[i]):
            final[i] = False
    return np.where(final)[0].tolist()

# espessura da peça no tronco (m): quanto ela fica longe da pele no peito/costas (percentil 85). O colete usa para
# ficar por fora da camisa/jaqueta que estiver por baixo (jogador/modelo_sobrevivente.gd)
def medir_grossura(d, P, pct=85):
    reg = (np.array(d["C"]) * 15 + 0.5).astype(int)
    kd = cKDTree(d["V"])
    dist, j = kd.query(P)
    tronco = (reg[j] == 3) & (dist < 0.15)
    return float(np.percentile(dist[tronco], pct)) if tronco.sum() > 20 else 0.0

_cache = {}
def base(sx):
    if sx not in _cache:
        b = pickle.load(open(B+"base_%s.pkl"%sx, "rb"))
        d = ubc(sx)
        P, PN, ptri, pbc = amostrar(d, 10)
        b["ubc"] = d; b["P"] = P; b["PN"] = PN; b["ptri"] = ptri; b["pbc"] = pbc; b["kdp"] = cKDTree(P)
        b["kdb"] = cKDTree(b["V"][b["corpo_v"]])
        _cache[sx] = b
    return _cache[sx]

# acertos por peça (metros, no corpo em pé): o boné do exército ficava com a aba nos olhos
DESLOCA = {"mindfront_patrol_cap": {"m": (0.0, 0.05, -0.012), "f": (0.0, 0.045, -0.01)}}
# peças que vão POR CIMA de outras grossas (o colete fica por fora da jaqueta): incha ao longo da normal (m)
INFLAR = {}
PERNAS = {7, 8, 9, 10}      # QUADRIL, COXA, CANELA, PE (regiões do corpo UBC, COLOR.r)
def filtrar_parte(F, FT, P, d, parte):
    """separa um conjunto em parte de cima / de baixo pelas ilhas do UV (cada pedaço do molde vai inteiro)"""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    nf = len(F)
    # faces ligadas por vértice de UV em comum
    linhas = []; cols = []
    dono = {}
    for fi, ft in enumerate(FT):
        for t in ft:
            if t in dono:
                linhas.append(fi); cols.append(dono[t])
            else:
                dono[t] = fi
    g = coo_matrix((np.ones(len(linhas)), (linhas, cols)), shape=(nf, nf))
    n, lab = connected_components(g, directed=False)
    reg = (np.array(d["C"]) * 15 + 0.5).astype(int)
    kd = cKDTree(d["V"])
    cent = np.array([P[f].mean(0) for f in F])
    _, j = kd.query(cent)
    perna = np.isin(reg[j], list(PERNAS)) & (cent[:, 1] < 1.0)
    voto = np.zeros(n); tot = np.zeros(n)
    np.add.at(voto, lab, perna.astype(float)); np.add.at(tot, lab, 1.0)
    baixo = (voto / np.maximum(tot, 1)) > 0.5
    quer = baixo[lab] if parte == "baixo" else ~baixo[lab]
    return [f for f, q in zip(F, quer) if q], [ft for ft, q in zip(FT, quer) if q]

def ajustar_roupa(pasta, sx, folga=0.004, empurrar=None, parte=""):
    nm = os.path.basename(pasta.rstrip('/'))
    cab, refs, dele = ler_mhclo(os.path.join(pasta, nm + ".mhclo"))
    b = base(sx); V0 = b["V0"]; V = b["V"]; R = b["R"]
    # escala por eixo (como o MakeHuman) e conversão para o corpo ajustado
    s0 = np.ones(3); razao = []
    for a, k in enumerate(('x_scale','y_scale','z_scale')):
        if k in cab:
            v1, v2, den = cab[k]
            s0[a] = abs(V0[v1][a] - V0[v2][a]) / den
            razao.append(np.linalg.norm(V[v1]-V[v2]) / max(np.linalg.norm(V0[v1]-V0[v2]), 1e-6))
    rz = float(np.mean(razao)) if razao else 0.11
    P = np.zeros((len(refs), 3))
    for i, r in enumerate(refs):
        if len(r) == 1:
            P[i] = V[int(r[0])]
        else:
            i0, i1, i2 = int(r[0]), int(r[1]), int(r[2])
            P[i] = r[3]*V[i0] + r[4]*V[i1] + r[5]*V[i2] + (R[i0] @ (np.array(r[6:9]) * s0)) * rz
    Vo, F, _, VT, FT = carregar_obj(os.path.join(pasta, cab.get("obj_file", nm + ".obj")))
    if len(Vo) != len(P):
        raise Exception("vértices %d no obj e %d no mhclo" % (len(Vo), len(P)))
    # normais da roupa (por posição) e folga para fora
    N = np.zeros_like(P)
    for f in F:
        for k in range(1, len(f)-1):
            n = np.cross(P[f[k]]-P[f[0]], P[f[k+1]]-P[f[0]])
            for q in (f[0], f[k], f[k+1]): N[q] += n
    N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-9
    P = P + N * folga
    if nm in DESLOCA:
        P = P + np.array(DESLOCA[nm][sx])
    if nm in INFLAR:
        P = P + N * INFLAR[nm]
    # nada do corpo atravessa: um "campo de empurrão" no CORPO (quanto a roupa precisa sair em cada ponto da pele) e
    # cada vértice da roupa anda o valor do ponto de pele mais perto. Camadas da mesma roupa (camisa por cima da
    # calça) andam juntas, então a de fora continua por fora.
    vao = 0.006
    bb = base(sx)
    U = bb["ubc"]["V"]; UN = bb["ubc"]["N"]
    kdu = cKDTree(U)
    dist, ju = kdu.query(P)
    h = ((P - U[ju]) * UN[ju]).sum(1)
    perto = (dist < 0.08) & (h > -0.05)
    campo = np.zeros(len(U))
    np.maximum.at(campo, ju[perto], np.maximum(vao - h[perto], 0))
    # pele que fica na frente da roupa (ponta do seio, dedos): olha os vértices de roupa em volta de cada ponto
    kdc = cKDTree(P)
    for ui, js in enumerate(kdc.query_ball_point(U, 0.03)):
        if not js: continue
        q = P[js] - U[ui]; hh = q @ UN[ui]
        lat = np.linalg.norm(q - np.outer(hh, UN[ui]), axis=1)
        m = (hh < vao) & (hh > -0.05) & (lat < 0.025)
        if m.any():
            campo[ui] = max(campo[ui], float((vao - hh[m]).max()))
    # suaviza o campo na pele (sem degrau), sem baixar o que já precisa
    if "_vizu" not in bb:
        vz = [set() for _ in range(len(U))]
        for a, b_, c in bb["ubc"]["I"]:
            vz[a].update((b_, c)); vz[b_].update((a, c)); vz[c].update((a, b_))
        bb["_vizu"] = [np.fromiter(x, int) for x in vz]
    for _ in range(4):
        media = np.array([campo[v].mean() if len(v) else 0 for v in bb["_vizu"]])
        campo = np.maximum(campo, media * 0.9)
    if empurrar is None: empurrar = os.environ.get("EMPURRAR", "0") == "1"
    if empurrar:
        P = P + UN[ju] * (campo[ju] * perto)[:, None]
    if parte:
        F, FT = filtrar_parte(F, FT, P, base(sx)["ubc"], parte)
        if not F:
            raise Exception("parte vazia")
    # pesos: do ponto do corpo mais perto
    d = b["ubc"]
    _, j = b["kdp"].query(P)
    tri = b["ptri"][j]; bc = b["pbc"][j]
    vs = d["I"][tri]
    nb = d["B"].shape[1]
    acc = [dict() for _ in range(len(P))]
    for c in range(3):
        Bc = d["B"][vs[:, c]]; Wc = d["W"][vs[:, c]] * bc[:, c:c+1]
        for i in range(len(P)):
            a = acc[i]
            for k in range(nb):
                if Wc[i, k] > 0: a[Bc[i, k]] = a.get(Bc[i, k], 0) + Wc[i, k]
    BB = np.zeros((len(P), 4), int); WW = np.zeros((len(P), 4))
    for i, a in enumerate(acc):
        top = sorted(a.items(), key=lambda x: -x[1])[:4]
        s = sum(w for _, w in top) or 1
        for k, (bo, w) in enumerate(top):
            BB[i, k] = bo; WW[i, k] = w / s
    # vértices separados por (posição, uv) e triângulos
    chave = {}; idx = []; VV = []; UV = []; NN = []; Bo = []; Wo = []
    for f, ft in zip(F, FT):
        ids = []
        for v, t in zip(f, ft):
            k = (v, (round(float(VT[t][0]), 4), round(float(VT[t][1]), 4)) if (VT is not None and t >= 0) else -1)
            if k not in chave:
                chave[k] = len(VV); VV.append(P[v]); NN.append(N[v]); Bo.append(BB[v]); Wo.append(WW[v])
                UV.append(VT[t] if (VT is not None and t >= 0) else [0, 0])
            ids.append(chave[k])
        for k in range(1, len(ids)-1):
            idx += [ids[0], ids[k], ids[k+1]]
    # pele escondida: vértice do corpo UBC cujo vértice do MakeHuman mais perto foi apagado pela roupa
    tris = []
    for f in F:
        for k in range(1, len(f)-1): tris.append((f[0], f[k], f[k+1]))
    esconde = pele_coberta(d, P, tris)
    mat = ler_mhmat(os.path.join(pasta, cab.get("material", nm + ".mhmat")))
    grossura = medir_grossura(d, np.array(VV)) if VV else 0.0
    perto = medir_grossura(d, np.array(VV), 5) if VV else 0.0
    return {"nome": nm + ("__" + parte if parte else ""), "sexo": sx, "V": np.round(np.array(VV), 5).tolist(), "N": np.round(np.array(NN), 4).tolist(),
            "UV": np.round(np.array(UV), 5).tolist(), "I": idx, "B": np.array(Bo).tolist(), "W": np.round(np.array(Wo), 4).tolist(),
            "esconde": esconde, "tex": mat.get("diffuseTexture", ""), "cor": mat.get("diffuseColor", "1 1 1") if not mat.get("diffuseTexture") else "1 1 1",
            "transparente": mat.get("transparent", "False"), "grossura": grossura, "perto": perto}

if __name__ == "__main__":
    os.makedirs(B+"saida", exist_ok=True)
    for nm in sys.argv[2:]:
        for sx in sys.argv[1].split(","):
            r = ajustar_roupa(B+"roupas/"+nm, sx)
            json.dump(r, open(B+"saida/%s_%s.json" % (nm, sx), "w"))
            print(nm, sx, "verts", len(r["V"]), "tris", len(r["I"])//3, "esconde", len(r["esconde"]), "tex", r["tex"])
