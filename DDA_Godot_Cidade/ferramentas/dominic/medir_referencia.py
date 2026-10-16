# MEDE A REFERÊNCIA DO DOMINIC (imagem com FRENTE · LADO · COSTAS) para modelar igual ao desenho.
# Faz por medida o que se faz à mão no Blender (contornar a silhueta com anéis de vértices, como no vídeo de
# low poly): separa o personagem do fundo em cada vista e, para cada altura do corpo, mede largura (frente)
# e profundidade (lado). Sai um JSON com os anéis do tronco, cabeça, pernas e braços, em metros.
# Também grava a imagem com as cores da LORE (Bíblia: cabelo BRANCO e pele quase albina), que o Blender usa
# para pintar cada face (cor da vista que a face encara).
# Rodar (Python com numpy, scipy e Pillow):  python3 medir_referencia.py <imagem> <pasta de saída>
import sys, json, numpy as np
from PIL import Image
from scipy import ndimage as nd

ARQ, SAIDA = sys.argv[1], sys.argv[2]
ALTURA = 1.80                          # metros (Dominic, 24 anos)
img = np.asarray(Image.open(ARQ).convert("RGB")).astype(np.float32)
H, W, _ = img.shape
m = img.mean(axis=2)
sat = img.max(axis=2) - img.min(axis=2)
r, g, b = img[..., 0], img[..., 1], img[..., 2]

# ---------------- silhueta (fundo cinza-azulado do quadriculado)
fundo = (m >= 108) & (m <= 185) & (sat < 22) & (b >= r - 3)
fg = ~fundo
fg[:75] = False
VISTAS = {"frente": (0, 500), "lado": (504, 880), "costas": (885, W)}
for x in (500, 501, 502, 503, 880, 881, 882, 883, 884):
	fg[:, x] = False
fg = nd.binary_opening(fg, iterations=1)
fg = nd.binary_closing(fg, iterations=2)
fg = nd.binary_fill_holes(fg)
masc = np.zeros_like(fg)
for nome, (x0, x1) in VISTAS.items():
	sub = fg[:, x0:x1]
	lab, n = nd.label(sub)
	tam = nd.sum(sub, lab, range(1, n + 1))
	masc[:, x0:x1] = lab == (int(np.argmax(tam)) + 1)
# costas: a camiseta branca entre jaqueta e calça some com o fundo; fecha na vertical
x0c = VISTAS["costas"][0]
masc[:, x0c:] = nd.binary_closing(masc[:, x0c:], structure=np.ones((15, 1)), iterations=1) | masc[:, x0c:]
# o lado tem uma fresta (abertura da jaqueta): fecha por linha
for y in range(H):
	xs = np.nonzero(masc[y, 504:880])[0]
	if xs.size:
		masc[y, 504 + xs.min():504 + xs.max() + 1] = True

def corridas(lin):
	"""trechos contínuos [ini, fim] de True numa linha"""
	d = np.diff(np.concatenate([[0], lin.astype(np.int8), [0]]))
	return list(zip(np.nonzero(d == 1)[0], np.nonzero(d == -1)[0] - 1))

def info(nome):
	x0, x1 = VISTAS[nome]
	ys, xs = np.nonzero(masc[:, x0:x1])
	return x0, ys.min(), ys.max()

xf0, topo, pe = info("frente")
s = ALTURA / (pe - topo)               # metros por pixel
print("escala", s, "topo", topo, "pé", pe)
Z = lambda y: (pe - y) * s

def linha(nome, y):
	x0, x1 = VISTAS[nome]
	return [(a + x0, c + x0) for a, c in corridas(masc[y, x0:x1])]

# centro da frente e das costas: meio do quadril
yq = int(topo + (pe - topo) * 0.55)
cxf = np.mean(max(linha("frente", yq), key=lambda t: t[1] - t[0]))
cxb = np.mean(max(linha("costas", yq), key=lambda t: t[1] - t[0]))
cys = np.mean(max(linha("lado", yq), key=lambda t: t[1] - t[0]))
print("centros", cxf, cxb, cys)

# ---------------- linhas-chave na frente
virilha = None
for y in range(pe - 5, topo, -1):
	if masc[y, int(cxf)]:
		virilha = y
		break
axila = None
viu_bracos = False
for y in range(virilha - 5, topo, -1):
	rs = linha("frente", y)
	if len(rs) >= 3:
		viu_bracos = True
	elif viu_bracos and len(rs) == 1:
		axila = y
		break
pescoco = min(range(topo + 45, topo + 130), key=lambda y: sum(c - a for a, c in linha("frente", y) if a <= cxf <= c))
print("virilha", virilha, "axila", axila, "pescoço", pescoco)

def run_central(nome, y, cx):
	for a, c in linha(nome, y):
		if a - 2 <= cx <= c + 2:
			return a, c
	return None

# meia-largura do tronco logo abaixo da axila (sem os braços)
ra = run_central("frente", axila + 6, cxf)
hw_axila = (ra[1] - ra[0]) / 2.0

def aneis(y0, y1, passo, limite=None, perna=None):
	"""anéis entre as linhas y0 (cima) e y1 (baixo): [z, x_esq, x_dir, y_frente, y_tras] em metros
	(x: +X = esquerda do personagem; y: -Y = frente)"""
	out = []
	ys = list(np.arange(y0, y1, passo)) + [y1]
	for y in ys:
		y = int(round(y))
		if perna is None:
			rf = run_central("frente", y, cxf)
			rb = run_central("costas", y, cxb)
		else:
			rs = [t for t in linha("frente", y) if (t[0] + t[1]) / 2 < cxf] if perna == "d" else [t for t in linha("frente", y) if (t[0] + t[1]) / 2 > cxf]
			rf = max(rs, key=lambda t: t[1] - t[0]) if rs else None
			rb = None
		rl = linha("lado", y)
		if rf is None or not rl:
			continue
		a, c = rf
		if limite is not None:
			lim = limite(y)
			a = max(a, cxf - lim)
			c = min(c, cxf + lim)
		ra2 = max(rl, key=lambda t: t[1] - t[0])
		out.append([round(Z(y), 4), round((a - cxf) * s, 4), round((c + 1 - cxf) * s, 4),
			round((ra2[0] - cys) * s, 4), round((ra2[1] + 1 - cys) * s, 4)])
	return out

def lim_tronco(y):
	if y >= axila:
		return 1e9
	return hw_axila * 1.06

dados = {"escala": s, "altura": ALTURA, "cxf": float(cxf), "cxb": float(cxb), "cys": float(cys), "pe": int(pe), "topo": int(topo),
	"z_virilha": Z(virilha), "z_axila": Z(axila), "z_pescoco": Z(pescoco)}
dados["cabeca"] = aneis(topo + 1, pescoco + 18, 4.0)
# orelhas não entram na largura da cabeça (viram peça própria)
for a in dados["cabeca"]:
	if 1.605 < a[0] < 1.715:
		a[1] = max(a[1], -0.082); a[2] = min(a[2], 0.082)
dados["tronco"] = aneis(pescoco + 14, virilha - 2, 14.0, lim_tronco)
for a in dados["tronco"]:
	if a[0] > 1.49:                                   # a gola não vai até o queixo
		a[3] = max(a[3], -0.095); a[4] = min(a[4], 0.085)
# borda da camiseta branca na frente (para os vértices do tronco caírem bem nela)
yt = int(topo + (pe - topo) * 0.36)
xs = [x for x in range(int(cxf) - 60, int(cxf) + 60) if img[yt, x].mean() > 190]
dados["camiseta_meia"] = round((max(xs) - min(xs) + 1) / 2 * s, 4) if xs else 0.06
dados["perna_d"] = aneis(virilha - 14, pe, 17.0, perna="d")
dados["perna_e"] = aneis(virilha - 14, pe, 17.0, perna="e")
# barra da jaqueta (fim da camiseta branca na frente) e altura das botas
col = [y for y in range(axila, virilha) if img[y, int(cxf)].mean() > 185]
dados["z_barra"] = Z(max(col) + 2) if col else Z(virilha - 50)
dados["z_bota"] = Z(pe - 48)

# ---------------- braços (na frente): pixels fora do tronco, eixo pelo PCA, fatias perpendiculares
pele = (r > g) & (g > b) & (r - b > 30) & (r > 110)
def braco(lado):
	pts = []
	for y in range(pescoco + 5, virilha - 3):
		for a, c in linha("frente", y):
			if y >= axila and abs((a + c) / 2 - cxf) < hw_axila * 1.05 and (c - a) > 20:
				continue                              # tronco/quadril
			for x in range(a, c + 1):
				d = x - cxf
				lim = hw_axila * (0.9 if y < axila else 1.0)
				if y >= axila:
					rt = run_central("frente", y, cxf)
					if rt is not None and rt[0] <= x <= rt[1]:
						continue
				if (lado == "d" and d < -lim) or (lado == "e" and d > lim):
					pts.append((x, y))
	p = np.array(pts, dtype=np.float32)
	for x, y in pts:
		BRACOS[y, x] = True
	cen = p.mean(axis=0)
	u, sv, vt = np.linalg.svd(p - cen, full_matrices=False)
	eixo = vt[0]
	if (lado == "d" and eixo[0] > 0) or (lado == "e" and eixo[0] < 0):
		eixo = -eixo                          # do ombro para a mão
	perp = np.array([-eixo[1], eixo[0]])
	t = (p - cen) @ eixo
	q = (p - cen) @ perp
	t0, t1 = t.min(), t.max()
	fatias = []
	passo = 12.0
	k = t0
	while k <= t1:
		sel = (t >= k - passo / 2) & (t < k + passo / 2)
		if sel.sum() > 3:
			qa, qb = q[sel].min(), q[sel].max()
			c2 = cen + eixo * k + perp * (qa + qb) / 2
			larg = (qb - qa)
			xs = p[sel].astype(int)
			fr_pele = pele[xs[:, 1], xs[:, 0]].mean()
			fatias.append([round((c2[0] - cxf) * s, 4), round(Z(c2[1]), 4), round(larg * s, 4), round(float(fr_pele), 3)])
		k += passo
	return fatias

BRACOS = np.zeros((H, W), bool)
dados["braco_d"] = braco("d")
dados["braco_e"] = braco("e")
json.dump(dados, open(SAIDA + "/medidas.json", "w"), indent=1)

# ---------------- cores da LORE: cabelo branco e pele quase albina
cor = img.copy()
lum = img.mean(axis=2)
cabeca_rows = np.zeros((H, W), bool)
cabeca_rows[topo:pescoco + 10] = True
tan = (r > g) & (g >= b - 2) & (r - b > 12)
# cabelo: tons de bege no alto da cabeça (tranças) e nas tranças que descem atrás
y_testa_frente = topo + int((pescoco - topo) * 0.22)
cab = np.zeros((H, W), bool)
x0, x1 = VISTAS["frente"]; cab[topo:y_testa_frente, x0:x1] = True
x0, x1 = VISTAS["lado"]; cab[topo:pescoco, x0:x1] = True
x0, x1 = VISTAS["costas"]; cab[topo:pescoco + 6, x0:x1] = True
# no lado só atrás da orelha/testa (o rosto fica à esquerda)
xs_lado = np.arange(W)
lado_rosto = (xs_lado < cys + 2) & (xs_lado >= VISTAS["lado"][0]) & (xs_lado < VISTAS["lado"][1])
cab[:, lado_rosto] &= False
cab[topo:topo + int((pescoco - topo) * 0.3), VISTAS["lado"][0]:VISTAS["lado"][1]] = True
cabelo = cab & tan & masc & (lum > 95)
pele_m = masc & (r > g) & (g > b) & (r - b > 25) & (lum > 70) & ~cabelo
ref_pele = np.median(lum[pele_m])
f = (lum / ref_pele)[..., None]
cor[pele_m] = np.clip(np.array([238, 222, 212]) * f[pele_m], 0, 255)
ref_cab = np.median(lum[cabelo])
cor[cabelo] = np.clip(np.array([236, 236, 232]) * np.clip(f[cabelo] * ref_pele / ref_cab, 0.55, 1.08), 0, 255)
np.save(SAIDA + "/cores.npy", cor.astype(np.uint8))
# versão sem os traços de contorno do desenho (filtro de mediana): para pintar roupa e corpo
lisa = np.stack([nd.median_filter(cor[..., k], size=5) for k in range(3)], axis=-1)
np.save(SAIDA + "/cores_lisas.npy", lisa.astype(np.uint8))
np.save(SAIDA + "/mascara.npy", masc)
# braços também nas costas (espelho da frente em torno do centro)
xb0 = VISTAS["costas"][0]
for y, x in zip(*np.nonzero(BRACOS[:, :500])):
	xx = int(round(cxb - (x - cxf)))
	if xb0 <= xx < W:
		BRACOS[y, xx] = True
BRACOS = nd.binary_dilation(BRACOS, iterations=3)
np.save(SAIDA + "/bracos.npy", BRACOS)
Image.fromarray(cor.astype(np.uint8)).save(SAIDA + "/referencia_lore.png")
print("cabeça", len(dados["cabeca"]), "tronco", len(dados["tronco"]), "pernas", len(dados["perna_d"]), len(dados["perna_e"]),
	"braços", len(dados["braco_d"]), len(dados["braco_e"]))
