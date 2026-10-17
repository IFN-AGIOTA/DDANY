# MODELA O DOMINIC NO BLENDER a partir das medidas da referência (medir_referencia.py), do mesmo jeito que se faz
# à mão no vídeo de low poly: cilindros de poucos lados para o tronco, cabeça, braços e pernas, com cada anel de
# vértices ajustado à silhueta da FRENTE (largura) e do LADO (profundidade). As faces ficam retas (estilo facetado,
# em triângulos) e cada uma é pintada com a cor do desenho na vista que ela encara (frente, lado ou costas).
# Peças extras: óculos escuros e tranças de verdade (em relevo) por cima da cabeça.
# Rodar:  REF=<pasta com medidas.json, cores.npy, mascara.npy> SAIDA=<arquivo .blend> blender -b -P modelar_dominic.py
# Blender: Z para cima, frente = -Y, esquerda do personagem = +X.
import bpy, bmesh, json, math, os
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

REF = os.environ["REF"]
D = json.load(open(os.path.join(REF, "medidas.json")))
COR = np.load(os.path.join(REF, "cores.npy"))
LISA = np.load(os.path.join(REF, "cores_lisas.npy"))
MASC = np.load(os.path.join(REF, "mascara.npy"))
BRACOS = np.load(os.path.join(REF, "bracos.npy"))
S = D["escala"]
CXF, CXB, CYS, PE = D["cxf"], D["cxb"], D["cys"], D["pe"]
HH, WW = MASC.shape

bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------------------------------------------------------------- anéis
def anel_horizontal(m, lados, e, gira=0.0, cortes=None):
	"""m = [z, x_esq, x_dir, y_frente, y_tras] -> pontos do anel (superelipse, um vértice bem na frente).
	cortes = meia-largura x onde também deve haver vértice na frente (borda da camiseta)"""
	z, xl, xr, yf, yb = m
	cx, a = (xl + xr) / 2, (xr - xl) / 2
	angs = [-math.pi / 2 + 2 * math.pi * k / lados + gira for k in range(lados)]
	if cortes:
		dt = math.acos(min(0.999, (cortes / max(a, 1e-4)) ** (1.0 / e)))
		passo = 2 * math.pi / lados
		angs = [t for t in angs if abs(t - (-math.pi / 2)) > passo * 0.6 or abs(t + math.pi / 2) < 1e-6]
		angs = sorted(angs + [-math.pi / 2 - (math.pi / 2 - dt), -math.pi / 2 + (math.pi / 2 - dt)])
		angs = [t for t in angs if abs(t + math.pi / 2) > 1e-6]
	pts = []
	for t in angs:
		c, s = math.cos(t), math.sin(t)
		x = cx + a * math.copysign(abs(c) ** e, c)
		y = ((yf + yb) / 2) + ((yb - yf) / 2) * math.copysign(abs(s) ** e, s)
		pts.append(Vector((x, y, z)))
	return pts

def tubo(nome, aneis, tampa_cima=True, tampa_baixo=True, ponta_cima=None):
	bm = bmesh.new()
	vs = [[bm.verts.new(p) for p in a] for a in aneis]
	n = len(aneis[0])
	qid = bm.faces.layers.int.new("quad")
	conta = [0]
	def par(f1, f2):
		conta[0] += 1
		f1[qid] = conta[0]; f2[qid] = conta[0]
	for i in range(len(vs) - 1):
		for k in range(n):
			a, b, c, d = vs[i][k], vs[i][(k + 1) % n], vs[i + 1][(k + 1) % n], vs[i + 1][k]
			# quad -> 2 triângulos, diagonal alternada (as facetas em triângulo da referência)
			if (i + k) % 2 == 0:
				par(bm.faces.new((a, b, c)), bm.faces.new((a, c, d)))
			else:
				par(bm.faces.new((a, b, d)), bm.faces.new((b, c, d)))
	if tampa_cima:
		cen = sum(aneis[0], Vector()) / n
		if ponta_cima is not None:
			cen = cen + ponta_cima
		vc = bm.verts.new(cen)
		for k in range(n):
			bm.faces.new((vs[0][(k + 1) % n], vs[0][k], vc))
	if tampa_baixo:
		cen = sum(aneis[-1], Vector()) / n
		vc = bm.verts.new(cen)
		for k in range(n):
			bm.faces.new((vs[-1][k], vs[-1][(k + 1) % n], vc))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm

# ---------------------------------------------------------------- partes do corpo
partes = {}
partes["tronco"] = tubo("tronco", [anel_horizontal(m, 14, 0.7, cortes=D["camiseta_meia"]) for m in D["tronco"]], tampa_cima=True)
for lado in ("d", "e"):
	partes["perna_" + lado] = tubo("perna", [anel_horizontal(m, 10, 0.8) for m in D["perna_" + lado]])

def braco(fatias):
	# começa onde o braço sai do tronco (o ombro fica dentro da jaqueta)
	hw = max(abs(m[1]) for m in D["tronco"] if abs(m[0] - D["z_axila"]) < 0.04)
	ini = 0
	for i, f in enumerate(fatias):
		if abs(f[0]) > hw * 0.82:
			ini = i
			break
	larg_med = sorted(f[2] for f in fatias)[len(fatias) // 2]
	while ini < len(fatias) - 1 and fatias[ini][2] > larg_med * 1.25:
		ini += 1
	fat = fatias[min(ini + 1, len(fatias) - 2):]
	fim = next((i for i, f in enumerate(fat) if f[3] > 0.45), len(fat))
	fat = fat[:min(len(fat), fim + 1)]
	aneis = []
	for i, f in enumerate(fat):
		c = Vector((f[0], 0.0, f[1]))
		a = Vector((fat[min(i + 1, len(fat) - 1)][0], 0, fat[min(i + 1, len(fat) - 1)][1])) - Vector((fat[max(i - 1, 0)][0], 0, fat[max(i - 1, 0)][1]))
		a.normalize()
		perp = Vector((a.z, 0, -a.x))
		mao = False
		larg = f[2] / 2
		prof = larg * (0.45 if mao else 0.92)
		if i == 0:
			larg *= 0.9; prof = larg * 0.92
		pts = []
		for k in range(10):
			t = 2 * math.pi * k / 10
			pts.append(c + perp * math.cos(t) * larg + Vector((0, -1, 0)) * math.sin(t) * prof)
		aneis.append(pts)
	return tubo("braco", aneis)

partes["braco_d"] = braco(D["braco_d"])
partes["braco_e"] = braco(D["braco_e"])

# ---------------------------------------------------------------- cabeça e mãos: humano do MakeHuman (MPFB, CC0)
# reduzido a poucos triângulos (rosto facetado) e encaixado nas medidas da referência
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.targetservice import TargetService
ALVOS = [("head/head-square", 0.7), ("chin/chin-width-incr", 0.5), ("chin/chin-bones-incr", 0.6), ("chin/chin-prominent-incr", 0.3),
	("cheek/l-cheek-bones-incr", 0.6), ("cheek/r-cheek-bones-incr", 0.6), ("cheek/l-cheek-volume-decr", 0.5), ("cheek/r-cheek-volume-decr", 0.5),
	("forehead/forehead-nubian-incr", 0.4), ("eyebrows/eyebrows-trans-forward", 0.5), ("eyebrows/eyebrows-angle-down", 0.4),
	("nose/nose-hump-incr", 0.3), ("neck/neck-scale-horiz-incr", 0.4)]
JUNTAS = ["joint-l-hand", "joint-r-hand", "joint-l-finger-3-4", "joint-r-finger-3-4", "joint-l-finger-1-4", "joint-r-finger-1-4",
	"joint-mouth", "joint-l-eye", "joint-r-eye"]

def humano():
	macro = TargetService.get_default_macro_info_dict()
	macro.update({"gender": 1.0, "age": 0.5, "muscle": 0.68, "weight": 0.5, "proportions": 0.8, "height": 0.6})
	macro["race"] = {"asian": 0.0, "caucasian": 1.0, "african": 0.0}
	h = HumanService.create_human(macro_detail_dict=macro, scale=0.1)
	pasta = os.path.join(os.path.dirname(TargetService.__module__.replace(".", "/")), "")
	import bl_ext.user_default.mpfb as mpfb
	T = os.path.join(os.path.dirname(mpfb.__file__), "data", "targets") + "/"
	for nome, peso in ALVOS:
		TargetService.load_target(h, T + nome + ".target.gz", weight=peso)
	bpy.ops.object.select_all(action="DESELECT")
	bpy.context.view_layer.objects.active = h
	h.select_set(True)
	bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
	gi = {g.name: g.index for g in h.vertex_groups}
	J = {}
	for nome in JUNTAS:
		pts = [v.co.copy() for v in h.data.vertices if any(g.group == gi[nome] for g in v.groups)]
		J[nome] = sum(pts, Vector()) / len(pts)
	for m in list(h.modifiers):
		bpy.ops.object.modifier_apply(modifier=m.name)
	return h, J

def pedaco(h, filtro, transf, reduz):
	bm = bmesh.new()
	bm.from_mesh(h.data)
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not filtro(v.co)], context="VERTS")
	bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=60)
	for v in bm.verts:
		v.co = transf(v.co)
	me = bpy.data.meshes.new("tmp")
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new("tmp", me)
	bpy.context.scene.collection.objects.link(o)
	d = o.modifiers.new("dec", "DECIMATE")
	d.ratio = reduz
	bpy.ops.object.select_all(action="DESELECT")
	bpy.context.view_layer.objects.active = o
	o.select_set(True)
	bpy.ops.object.modifier_apply(modifier="dec")
	bm = bmesh.new()
	bm.from_mesh(o.data)
	bpy.data.objects.remove(o, do_unlink=True)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm

H_MH, J = humano()
VMH = [v.co.copy() for v in H_MH.data.vertices]
topo_mh = max(v.z for v in VMH)
boca = J["joint-mouth"]
queixo_mh = min(v.z for v in VMH if v.z > boca.z - 0.075 and v.y < boca.y + 0.022 and abs(v.x) < 0.02)
nariz_mh = min(v.y for v in VMH if v.z > queixo_mh)
topo_ref = max(m[0] for m in D["cabeca"]) - 0.007            # sem o volume das tranças
QUEIXO = D["z_pescoco"] - 0.004
nariz_ref = min(m[3] for m in D["cabeca"] if QUEIXO < m[0] < QUEIXO + 0.13)
K = (topo_ref - QUEIXO) / (topo_mh - queixo_mh)
def na_ref(p):
	return Vector((p.x * K, (p.y - nariz_mh) * K + nariz_ref, (p.z - queixo_mh) * K + QUEIXO))
corte_pescoco = queixo_mh - (QUEIXO - 1.515) / K
eixo_y = sum(v.y for v in VMH if queixo_mh - 0.05 < v.z < queixo_mh) / max(1, len([v for v in VMH if queixo_mh - 0.05 < v.z < queixo_mh]))
partes["cabeca"] = pedaco(H_MH, lambda c: c.z > corte_pescoco and (c.z > queixo_mh - 0.01 or (abs(c.x) < 0.07 and abs(c.y - eixo_y) < 0.08)), na_ref, 0.07)
OLHOS = [na_ref(J["joint-l-eye"]), na_ref(J["joint-r-eye"])]
# pescoço com faces menores: a tatuagem do desenho aparece
_bm = partes["cabeca"]
_pesc = [f for f in _bm.faces if f.calc_center_median().z < QUEIXO + 0.004]
_ares = list({e for f in _pesc for e in f.edges})
bmesh.ops.subdivide_edges(_bm, edges=_ares, cuts=3, use_grid_fill=True)
bmesh.ops.triangulate(_bm, faces=_bm.faces[:])
BOCA = na_ref(boca)
print("cabeça MakeHuman: escala", K, "olhos", OLHOS, "boca", BOCA)

# mãos: do pulso às pontas dos dedos, giradas e escaladas para o fim do braço da referência
for lado_mh, lado_ref in (("l", "e"), ("r", "d")):
	w = J["joint-%s-hand" % lado_mh]
	if (w.x > 0) != (lado_ref == "e"):
		lado_ref = "d" if lado_ref == "e" else "e"
	ponta = J["joint-%s-finger-3-4" % lado_mh]
	pol = J["joint-%s-finger-1-4" % lado_mh]
	a1 = (ponta - w).normalized()
	a2 = (pol - w) - a1 * (pol - w).dot(a1)
	a2.normalize()
	a3 = a1.cross(a2)
	fat = D["braco_" + lado_ref]
	ip = next((i for i, f in enumerate(fat) if f[3] > 0.45), len(fat) - 3)
	wr = Vector((fat[ip][0], 0.0, fat[ip][1]))
	tr = Vector((fat[-1][0], 0.0, fat[-1][1]))
	b1 = (tr - wr).normalized()
	b2 = Vector((0, -1, 0)) - b1 * Vector((0, -1, 0)).dot(b1)
	b2.normalize()
	b3 = b1.cross(b2)
	from mathutils import Matrix
	A = Matrix((a1, a2, a3)).transposed()
	Bm = Matrix((b1, b2, b3)).transposed()
	R = Bm @ A.inverted()
	kh = ((tr - wr).length + 0.02) / (ponta - w).length
	def tm(p, R=R, w=w, kh=kh, wr=wr):
		return R @ ((p - w) * kh) + wr
	comp = (ponta - w).length
	partes["mao_" + lado_ref] = pedaco(H_MH, lambda c, w=w, a1=a1, comp=comp: (c - w).dot(a1) > -0.012 and (c - w).length < comp * 1.4, tm, 0.18)
bpy.data.objects.remove(H_MH, do_unlink=True)

# ---------------------------------------------------------------- pintura: cor do desenho na vista que a face encara
def pixel(vista, p):
	if vista == "frente":
		px, py = CXF + p.x / S, PE - p.z / S
	elif vista == "costas":
		px, py = CXB - p.x / S, PE - p.z / S
	else:
		px, py = CYS + p.y / S, PE - p.z / S
	return int(round(px)), int(round(py))

def amostra(vista, p, img=None, sem_bracos=False):
	img = LISA if img is None else img
	ok = MASC & ~BRACOS if sem_bracos else MASC
	x, y = pixel(vista, p)
	for raio in range(0, 30):
		for dx in range(-raio, raio + 1):
			for dy in (-raio, raio) if raio else (0,):
				xx, yy = x + dx, y + dy
				if 0 <= xx < WW and 0 <= yy < HH and ok[yy, xx]:
					return img[yy, xx]
			for dy in range(-raio + 1, raio):
				for dx in (-raio, raio):
					xx, yy = x + dx, y + dy
					if 0 <= xx < WW and 0 <= yy < HH and ok[yy, xx]:
						return img[yy, xx]
	return np.array([60, 60, 60])

import random
random.seed(3)
PELE = np.array([0.95, 0.87, 0.82])
RASPADO = np.array([0.84, 0.81, 0.78])
CABELO = np.array([0.93, 0.93, 0.91])
Z_QUEIXO = D["z_pescoco"]
TATUAGEM = np.array([0.24, 0.16, 0.12])
def cor_tatuagem(c):
	"""tatuagem geométrica do pescoço (como no desenho): linha no meio, Vs, verticais e faixa na base"""
	pts = [p for p in cab_pts if 1.53 < p.z < 1.57]
	cx = sum(p.x for p in pts) / len(pts)
	cy = sum(p.y for p in pts) / len(pts)
	a = math.atan2(c.x - cx, -(c.y - cy))                 # 0 = frente
	u = a / math.radians(120)
	h = (c.z - 1.53) / max(0.01, QUEIXO - 0.015 - 1.53)
	au = abs(u)
	if au > 1.0 or h < 0.0 or h > 1.0:
		return PELE * (0.95 + 0.04 * random.random())
	risco = au < 0.05
	risco |= abs(h - (0.18 + au * 1.0)) < 0.07 and au < 0.6
	risco |= abs(h - (0.58 + au * 0.85)) < 0.07 and au < 0.45
	risco |= 0.3 < au < 0.37 and 0.12 < h < 0.95
	risco |= 0.62 < au < 0.69 and h < 0.8
	risco |= h < 0.1 and au < 0.8
	return TATUAGEM if risco else PELE * (0.93 + 0.04 * random.random())

def cor_cabeca(f):
	c = f.calc_center_median()
	n = f.normal
	if c.z < QUEIXO - 0.006 and not (n.y < -0.6 and c.z > QUEIXO - 0.02):
		return cor_tatuagem(c)                              # pescoço: tatuagem geométrica
	frente = n.y < -0.3 and c.y < OLHOS[0].y + 0.03
	z_cabelo = OLHOS[0].z + 0.052                           # linha do cabelo na testa
	if c.z > z_cabelo and abs(c.x) < 0.047:
		return CABELO * (0.97 + 0.03 * random.random())     # faixa das tranças
	if c.z > OLHOS[0].z + 0.025 and not frente:
		return RASPADO * (0.96 + 0.04 * random.random())    # laterais raspadas
	if c.y > OLHOS[0].y + 0.11 and c.z > QUEIXO + 0.02:
		return RASPADO * (0.96 + 0.04 * random.random())    # nuca raspada
	if frente and abs(c.x) < 0.024 and abs(c.z - (QUEIXO + 0.036)) < 0.006:
		return np.array([0.66, 0.5, 0.48])                  # lábios
	for o in OLHOS:
		if frente and abs(c.x - o.x) < 0.024 and 0.01 < c.z - o.z < 0.022:
			return np.array([0.86, 0.85, 0.82])             # sobrancelhas brancas
	return PELE * (0.95 + 0.06 * random.random())

JAQUETA = np.array([0.16, 0.165, 0.175])
CALCA = np.array([0.1, 0.1, 0.11])
BOTA = np.array([0.08, 0.08, 0.085])
SOLA = np.array([0.2, 0.2, 0.21])
BRANCO = np.array([0.93, 0.93, 0.94])
def cor_roupa(f, sem_bracos=False, so_frente_costas=False):
	"""classe pelo desenho (camiseta branca / pele / roupa escura) e a cor fixa da peça; o sombreado vem da luz"""
	c = f.calc_center_median()
	rgb = cor_face(f, so_frente_costas, sem_bracos=sem_bracos) * 255.0
	lum = rgb.mean()
	frente_c = f.normal.y < -0.4 and abs(c.x) < D["camiseta_meia"] * 1.6
	costas_c = f.normal.y > 0.4 and D["z_barra"] - 0.06 < c.z < D["z_barra"] + 0.02
	if lum > 175 and (frente_c or costas_c):
		return BRANCO * (0.97 + 0.03 * random.random())
	if rgb[0] - rgb[2] > 25 and lum > 90:
		return PELE * (0.95 + 0.05 * random.random())
	if c.z < 0.035:
		return SOLA
	if c.z < D["z_bota"]:
		return BOTA * (0.95 + 0.1 * random.random())
	if c.z < D["z_barra"] - 0.004:
		return CALCA * (0.95 + 0.1 * random.random())
	# painéis de tons (como as facetas cinza da referência)
	from mathutils import noise as nz
	v = nz.noise(c * 4.5)
	tom = 0.75 if v < -0.15 else (1.15 if v < 0.25 else 1.7)
	return JAQUETA * (tom + 0.06 * random.random())

def cor_face(f, so_frente_costas=False, img=None, sem_bracos=False):
	c = f.calc_center_median()
	n = f.normal
	pesos = {"frente": max(0.0, -n.y), "costas": max(0.0, n.y), "lado": 0.0 if so_frente_costas else abs(n.x) * 0.9}
	vista = max(pesos, key=pesos.get)
	pts = [c] + [c.lerp(v.co, 0.4) for v in f.verts]
	cs = np.array([amostra(vista, p, img, sem_bracos) for p in pts], dtype=np.float32)
	return np.median(cs, axis=0) / 255.0

mat = bpy.data.materials.new("Dominic")
mat.use_nodes = True
nt = mat.node_tree
pr = nt.nodes["Principled BSDF"]
vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"
nt.links.new(vc.outputs["Color"], pr.inputs["Base Color"])
pr.inputs["Roughness"].default_value = 0.9

def srgb_para_linear(c):
	return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

class _Quad:
	"""os 2 triângulos de um quad juntos (mesma cor)"""
	def __init__(self, fs):
		self.fs = fs
		self.verts = list({v for f in fs for v in f.verts})
		self.normal = sum((f.normal for f in fs), Vector()).normalized()
	def calc_center_median(self):
		return sum((v.co for v in self.verts), Vector()) / len(self.verts)

def objeto(nome, bm, cor=None, so_frente_costas=False, material=None, funcao=None, sem_bracos=False):
	qid = bm.faces.layers.int.get("quad")
	grupos = {}
	if qid is not None:
		for f in bm.faces:
			if f[qid] > 0:
				grupos.setdefault(f[qid], []).append(f)
	cache = {}
	cores = []
	for f in bm.faces:
		if cor is not None:
			cores.append(cor); continue
		chave = f[qid] if qid is not None and f[qid] > 0 else None
		if chave is not None and chave in cache:
			cores.append(cache[chave]); continue
		alvo = _Quad(grupos[chave]) if chave is not None else f
		c = funcao(alvo) if funcao else cor_roupa(alvo, sem_bracos, so_frente_costas)
		if chave is not None:
			cache[chave] = c
		cores.append(c)
	me = bpy.data.meshes.new(nome)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(nome, me)
	bpy.context.scene.collection.objects.link(o)
	me.materials.append(material or mat)
	at = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
	for f, c in zip(me.polygons, cores):
		f.use_smooth = False
		lin = srgb_para_linear(np.array(c[:3], dtype=np.float64)) if not getattr(c, "_linear", False) else c
		for li in f.loop_indices:
			at.data[li].color = (*lin, 1.0)
	return o

# cabeça primeiro (para as tranças e óculos acharem a superfície)
bm_cab = partes["cabeca"]
arv = BVHTree.FromBMesh(bm_cab)
OBJ_CAB = True
cab_pts = [v.co.copy() for v in bm_cab.verts]
cranio = [p for p in cab_pts if p.z > OLHOS[0].z]
cab_c = Vector((0.0, sum(p.y for p in cranio) / len(cranio), OLHOS[0].z + 0.012))
zs = [m[0] for m in D["cabeca"]]
z_topo, z_base = max(zs), min(zs)

def superficie(d, de=None):
	o = de if de is not None else cab_c
	hit = arv.ray_cast(o + d.normalized() * 0.5, -d.normalized())
	return hit[0] if hit[0] is not None else o + d.normalized() * 0.1

for nome, bm in partes.items():
	objeto(nome, bm, so_frente_costas=nome.startswith("braco"), funcao=cor_cabeca if nome == "cabeca" else None,
		cor=PELE if nome.startswith("mao") else None, sem_bracos=nome.startswith(("tronco", "perna")))

# ---------------------------------------------------------------- óculos escuros (retangulares, envolventes)
def oculos():
	bm = bmesh.new()
	frente = Vector((0, -1, 0))
	for o in OLHOS:
		sx = 1 if o.x > 0 else -1
		borda = []
		for (dx, dz) in ((-0.024, 0.011), (0.027, 0.012), (0.03, -0.005), (0.022, -0.012), (-0.018, -0.012), (-0.025, -0.005)):
			p = Vector((o.x + sx * dx, o.y, o.z + dz))
			hit = arv.ray_cast(p + frente * 0.2, -frente)
			yy = (hit[0].y if hit[0] is not None else o.y) - 0.011
			borda.append(bm.verts.new(Vector((p.x, min(yy, o.y - 0.012) + max(0.0, sx * dx - 0.015) * 0.5, p.z))))
		bm.faces.new(borda if sx > 0 else list(reversed(borda)))
		# haste até a orelha
		h0 = borda[1].co + Vector((sx * 0.003, 0.003, -0.002))
		lado = Vector((sx, 0, 0))
		hit = arv.ray_cast(Vector((sx * 0.3, o.y + 0.07, o.z)), -lado)
		h1 = (hit[0] if hit[0] is not None else Vector((sx * 0.08, o.y + 0.07, o.z))) + lado * 0.004
		a = [bm.verts.new(h0), bm.verts.new(h1), bm.verts.new(h1 + Vector((0, 0, -0.006))), bm.verts.new(h0 + Vector((0, 0, -0.006)))]
		bm.faces.new(a)
	pe = OLHOS[0] + Vector((-0.02 if OLHOS[0].x > 0 else 0.02, -0.018, 0.008))
	pd = OLHOS[1] + Vector((-0.02 if OLHOS[1].x > 0 else 0.02, -0.018, 0.008))
	bm.faces.new([bm.verts.new(p) for p in (pe, pd, pd + Vector((0, 0, -0.006)), pe + Vector((0, 0, -0.006)))])
	return bm

def gola():
	pts = [p for p in cab_pts if 1.52 < p.z < 1.56]
	cen = sum(pts, Vector()) / len(pts)
	rx = max(abs(p.x - cen.x) for p in pts)
	ry = max(abs(p.y - cen.y) for p in pts)
	bm = bmesh.new()
	n = 16
	lin = []
	for dz, dr in ((-0.03, 0.03), (-0.005, 0.02), (0.02, 0.036)):
		l = []
		for i in range(n + 1):
			a = math.radians(-140 + 280 * i / n)            # 0° = frente; abre 80° na frente
			l.append(bm.verts.new(Vector((cen.x + math.sin(a) * (rx + dr), cen.y - math.cos(a) * (ry + dr), 1.51 + dz + 0.014 * abs(math.sin(a))))))
		lin.append(l)
	for k in range(2):
		for i in range(n):
			bm.faces.new((lin[k][i], lin[k][i + 1], lin[k + 1][i + 1], lin[k + 1][i]))
	bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.012)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	return bm
objeto("gola", gola(), cor=JAQUETA * 1.05)

lente = bpy.data.materials.new("Dominic_Lente")
lente.use_nodes = True
lp = lente.node_tree.nodes["Principled BSDF"]
lp.inputs["Base Color"].default_value = (0.01, 0.012, 0.014, 1)
lp.inputs["Metallic"].default_value = 0.6
lp.inputs["Roughness"].default_value = 0.15
objeto("oculos", oculos(), cor=np.array([0.04, 0.045, 0.05]), material=lente)

# ---------------------------------------------------------------- tranças (cornrows) do alto da testa até a nuca
def trancas():
	bm = bmesh.new()
	lados = 5
	for xk in (-0.04, -0.03, -0.02, -0.01, 0.0, 0.01, 0.02, 0.03, 0.04):
		cam = []
		n = 30
		for i in range(n + 1):
			t = i / n
			a = math.radians(-40 + 162 * t)               # -40° = linha do cabelo (frente), 122° = nuca descendo
			d = Vector((xk * 9 * (1 - 0.3 * max(0.0, t - 0.6)), math.sin(a), math.cos(a)))   # x: tranças lado a lado
			p = superficie(d)
			cam.append(p + (p - cab_c).normalized() * 0.002)
		aneis = []
		for i, p in enumerate(cam):
			tg = (cam[min(i + 1, n)] - cam[max(i - 1, 0)]).normalized()
			up = (p - cab_c).normalized()
			lado = tg.cross(up).normalized()
			up = lado.cross(tg).normalized()
			r = (0.0046 if i % 2 == 0 else 0.0032) * (0.4 if i == 0 or i == n else 1.0)
			aneis.append([bm.verts.new(p + (lado * math.cos(2 * math.pi * j / lados) * 1.2 + up * math.sin(2 * math.pi * j / lados) * 0.8) * r) for j in range(lados)])
		for i in range(n):
			for j in range(lados):
				bm.faces.new((aneis[i][j], aneis[i][(j + 1) % lados], aneis[i + 1][(j + 1) % lados], aneis[i + 1][j]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm

bm_tr = trancas()
cores_tr = []
for f in bm_tr.faces:
	v = 0.93 if f.normal.dot((f.calc_center_median() - cab_c).normalized()) > 0.5 else 0.72
	cores_tr.append(v)
me = bpy.data.meshes.new("trancas"); bm_tr.to_mesh(me); bm_tr.free()
o = bpy.data.objects.new("trancas", me); bpy.context.scene.collection.objects.link(o); me.materials.append(mat)
at = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
for f, v in zip(me.polygons, cores_tr):
	f.use_smooth = False
	for li in f.loop_indices:
		at.data[li].color = (v, v, v * 0.97, 1.0)

tot = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
print("TRIANGULOS", tot)
bpy.ops.wm.save_as_mainfile(filepath=os.environ["SAIDA"])
