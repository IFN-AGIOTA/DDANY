extends RefCounted
# MONTA UM LOCAL ESPECIAL (0.68): POSTO DE GASOLINA, HOSPITAL, SUPERMERCADO ou ARMAZÉM, por fora e por dentro.
# São as ZONAS DE PvP: loot melhor e próprio de cada lugar (tabelas em mundo/loot_mundo.gd), mais infectados,
# várias entradas, coisas para se esconder atrás (bombas, carros, gôndolas, contêineres, sacos de areia) e
# lugares altos para vigiar (telhado do posto, heliponto do hospital, telhado do mercado, escritório e contêineres
# do armazém).
# Coordenadas LOCAIS: x = ao longo da frente, z = profundidade, +Z = FRENTE (o lado da rua), y = 0 no piso (altura
# da calçada). O nó raiz gira (giro x 90°) para a frente ficar virada para a rua (mundo/locais.gd).
# Igual aos prédios comuns (mundo/interior.gd): tudo vira UMA malha (5 superfícies) + UM corpo de colisão; a parte
# pesada (preparar) pode rodar numa thread; criar() faz os nós, a colisão e os contêineres de loot.
# Mexa AQUI para: a planta, os cômodos, os móveis e os enfeites de cada local. Onde ficam e quantos: mundo/locais.gd.
# 0.78: DELEGACIA, ESCOLA, ESTAÇÃO DO METRÔ e QUARTEL ficam em mundo/local_novos.gd (usa as peças daqui).

const Malhas := preload("res://mundo/malhas.gd")
const Moveis := preload("res://mundo/moveis.gd")
const Mat := preload("res://mundo/materiais_cidade.gd")
const CaixaMundo := preload("res://inventario/caixa_mundo.gd")
const InteriorCls := preload("res://mundo/interior.gd")      # 1.00: adicionar_caixas (colisão sem nós)

const PE := 4.0                        # pé-direito dos prédios de 2 andares (hospital)
const LAJE := 0.6
const ANDAR := PE + LAJE
const ESP := 0.3                       # paredes externas
const DIV := 0.15                      # paredes internas
const PORTA := 1.8
const PORTA_A := 2.5

const CONCRETO := Color(0.6, 0.59, 0.56)
const CONCRETO_ESC := Color(0.42, 0.41, 0.39)
const ASFALTO := Color(0.2, 0.2, 0.21)
const FAIXA := Color(0.85, 0.85, 0.8)
const AMARELO := Color(0.85, 0.66, 0.12)
const VERMELHO := Color(0.66, 0.1, 0.08)
const BRANCO := Color(0.85, 0.84, 0.8)
const METAL := Color(0.46, 0.47, 0.49)
const METAL_ESC := Color(0.22, 0.22, 0.24)
const VERDE_MIL := Color(0.27, 0.31, 0.2)
const VIDRO := Color(0.35, 0.45, 0.5)
const SACO := Color(0.55, 0.5, 0.38)

var tipo := ""
var idx := 0
var giro := 0
var centro := Vector2.ZERO             # no mundo
var r := RandomNumberGenerator.new()
var fora := Malhas.Construtor.new()    # chão, telhados, coberturas e tudo que fica no tempo (luz do sol normal)
var paredes := Malhas.Construtor.new() # paredes do prédio principal (papel de parede por dentro, hera/grafite por fora)
var piso := Malhas.Construtor.new()    # pisos de dentro (cerâmica)
var resto := Malhas.Construtor.new()   # móveis, enfeites, bombas, carros...
var teto := Malhas.Construtor.new()    # forro (embaixo das lajes)
var concreto := Malhas.Construtor.new()  # piso de concreto de dentro (oficina, estoque, armazém)
var chao := Malhas.Construtor.new()    # 0.78: chão pintado do terreno (asfalto, concreto, faixas): "camada" por cima do lote
var col: Array = []                    # [centro, tamanho, giro, base]
var cont: Array = []                   # contêineres de loot {"pos", "loot", "nome", "tam"}
var pontos: Array = []                 # chão livre para loot solto: [Vector3 local, cômodo]
var infectados: Array = []             # onde nascem os infectados (Vector3 local)
var bombas: Array = []                 # 0.76: bombas de gasolina (Vector3 local): enchem o galão (mundo/veiculos.gd)
var dentro := Rect2()                  # área coberta do prédio principal (shader: sol fraco lá dentro)
var textos: Array = []                 # 0.78: letreiros e pichações [Vector3 local, giro, texto, cor, tamanho]
var escadas: Array = []                # 0.81: [pé (Vector2), direção, largura, y0, subida, comprimento] (testes: chegada livre)
var _malha: ArrayMesh = null

const NOVOS := ["delegacia", "escola", "metro", "quartel"]
const NEOCLASSICOS := ["igreja", "prefeitura"]           # 1.06: mundo/local_igreja.gd

static func preparar(t: String, i: int, gi: int, c: Vector2) -> RefCounted:
	var arq := "res://mundo/local_bunker.gd" if t == "bunker" else ("res://mundo/local_novos.gd" if t in NOVOS else "res://mundo/local.gd")
	if t in NEOCLASSICOS:
		arq = "res://mundo/local_igreja.gd"
	var m = load(arq).new()
	m.tipo = t
	m.idx = i
	m.giro = gi
	m.centro = c
	m.r.seed = i * 9173 + 77
	match t:
		"posto": m._posto()
		"hospital": m._hospital()
		"supermercado": m._supermercado()
		"armazem": m._armazem()
		"delegacia": m._delegacia()
		"escola": m._escola()
		"metro": m._metro()
		"quartel": m._quartel()
		"bunker": m._bunker()             # 0.83: mundo/local_bunker.gd
		"igreja": m._igreja()             # 1.06: mundo/local_igreja.gd
		"prefeitura": m._prefeitura()
	if t in NOVOS or t == "bunker" or t in NEOCLASSICOS:
		m._livrar_pontos()
	m._criar_malha()
	return m

# 0.78: ponto de infectado/loot que ficou encostado numa caixa de colisão (parede, móvel, carro) vai para um lugar
# livre a até 1,6 m (ou sai da lista). Só nos locais novos (nos antigos a ordem dos pontos não muda).
func _livre(p: Vector3) -> bool:
	for h in [0.5, 1.2]:
		var q := p + Vector3(0, h, 0)
		for c in col:
			var b: Basis = c[3] if c.size() > 3 else Basis(Vector3.UP, c[2])
			var meio: Vector3 = (c[1] as Vector3).abs() * 0.5
			var l := b.inverse() * (q - (c[0] as Vector3))
			var perto := Vector3(clampf(l.x, -meio.x, meio.x), clampf(l.y, -meio.y, meio.y), clampf(l.z, -meio.z, meio.z))
			if l.distance_squared_to(perto) < 0.09:
				return false
	return true

func _achar_livre(p: Vector3) -> Vector3:
	if _livre(p):
		return p
	for raio in [0.6, 1.0, 1.6]:
		for k in 8:
			var a := k * TAU / 8.0
			var n: Vector3 = p + Vector3(cos(a), 0, sin(a)) * float(raio)
			if _livre(n):
				return n
	return Vector3.INF

func _livrar_pontos() -> void:
	var inf: Array = []
	for p in infectados:
		var n: Vector3 = _achar_livre(p)
		if n != Vector3.INF:
			inf.append(n)
	infectados = inf
	var pts: Array = []
	for e in pontos:
		var n: Vector3 = _achar_livre(e[0])
		if n != Vector3.INF:
			pts.append([n, e[1]])
	pontos = pts

# a malha (5 superfícies) pode ser feita na thread, como nos interiores
func _criar_malha() -> void:
	var cx := caixa_mundo(dentro)
	var am := ArrayMesh.new()
	fora.malha(Mat.material(Mat.INTERIOR, {"caixa": Vector4(0, 0, -1, -1), "padrao": 4.0, "sujeira": 0.45}), am)
	paredes.malha(Mat.material(Mat.INTERIOR, {"caixa": cx, "padrao": 3.0, "semente": float(idx % 97) / 97.0, "sujeira": 0.5, "forca_hera": 0.15}), am)
	if not piso.vazio():
		piso.malha(Mat.material(Mat.INTERIOR, {"caixa": cx, "padrao": 1.0, "sujeira": 0.7}), am)
	if not concreto.vazio():
		concreto.malha(Mat.material(Mat.INTERIOR, {"caixa": cx, "padrao": 4.0, "sujeira": 0.6}), am)
	if not chao.vazio():
		chao.malha(Mat.material(Mat.INTERIOR, {"caixa": Vector4(0, 0, -1, -1), "padrao": 4.0, "sujeira": 0.45, "camada": CAMADA_CHAO}), am)
	resto.malha(Mat.material(Mat.INTERIOR, {"caixa": cx, "padrao": 0.0, "sujeira": 0.6}), am)
	teto.malha(Mat.material(Mat.INTERIOR, {"caixa": cx, "padrao": 0.0, "sujeira": 0.5}), am)
	_malha = am

# retângulo local -> caixa do shader no MUNDO (centro x, z e meia-largura x, z); o giro é de 90 em 90 graus
func caixa_mundo(ret: Rect2) -> Vector4:
	var c := ret.get_center().rotated(-giro * PI * 0.5)
	var meia := ret.size * 0.5
	if giro % 2 == 1:
		meia = Vector2(meia.y, meia.x)
	return Vector4(centro.x + c.x, centro.y + c.y, meia.x, meia.y)

static func base_giro(g: int) -> Basis:
	return Basis(Vector3.UP, g * PI * 0.5)

# 2ª parte (thread principal): nós, malha, colisão e contêineres de loot (ids "L<local>_<k>")
func criar(lm, y: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Local_%d" % idx
	raiz.transform = Transform3D(base_giro(giro), Vector3(centro.x, y, centro.y))
	var mi := MeshInstance3D.new()
	mi.name = "Malha"
	mi.mesh = _malha
	raiz.add_child(mi)
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	InteriorCls.adicionar_caixas(corpo, col)      # 1.00: sem um nó CollisionShape3D para cada caixa
	raiz.add_child(corpo)
	if lm != null:
		for k in cont.size():
			var c: Dictionary = cont[k]
			var cx = CaixaMundo.new()
			cx.invisivel = true
			cx.nome = c["nome"]
			cx.tamanho = c["tam"]
			cx.grade = lm.grade("L%d_%d" % [idx, k], c["loot"], c["nome"], c["tam"], lm.CHANCE_VAZIO_BUNKER if tipo == "bunker" else lm.CHANCE_VAZIO_LOCAL)
			raiz.add_child(cx)
			cx.position = (c["pos"] as Vector3) + Vector3(0, 0.1, 0)
	raiz.set_meta("pontos_chao", pontos)
	# 0.78: letreiros e pichações (texto de verdade, iluminado como a parede)
	for t in textos:
		var l := Label3D.new()
		l.position = t[0]
		l.rotation.y = float(t[1])
		l.text = String(t[2])
		l.modulate = t[3]
		l.font_size = int(t[4])
		l.pixel_size = 0.01
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.visibility_range_end = 90.0
		raiz.add_child(l)
	# 0.76: as bombas (grupo "bombas"): PEGAR perto com um galão = encher
	for k in bombas.size():
		var b := Node3D.new()
		b.name = "Bomba_%d" % k
		b.add_to_group("bombas")
		b.set_meta("id", "L%d:%d" % [idx, k])
		b.position = bombas[k]
		raiz.add_child(b)
	# 0.83: bunker: a porta blindada (desce com o cartão) e o elevador lá embaixo (sobe) · mundo/porta_bunker.gd
	var elev = get("elevadores")
	if elev != null:
		var PortaBunker = load("res://mundo/porta_bunker.gd")
		for e in elev:
			var pb = PortaBunker.new()
			pb.name = "Elevador_%s" % e[1]
			pb.numero = int(get("numero"))
			pb.desce = e[1] == "desce"
			pb.position = e[0]
			pb.destino_local = e[2]
			pb.olhar_local = e[3]
			raiz.add_child(pb)
	# 1.06: o sino da igreja (mundo/sino.gd): PEGAR perto = tocar
	var sn = get("sinos")
	if sn != null:
		var SinoCls = load("res://mundo/sino.gd")
		for k in sn.size():
			var s = SinoCls.new()
			s.name = "Sino_%d" % k
			s.position = sn[k]
			raiz.add_child(s)
	return raiz

# ---------- peças ----------
func _bx(c, p: Vector3, tam: Vector3, cor: Color, colide := true, base := Basis.IDENTITY) -> void:
	c.caixa(p, tam, cor, base)
	if colide:
		col.append([p, tam, 0.0, base])

func _col(p: Vector3, tam: Vector3, base := Basis.IDENTITY) -> void:
	col.append([p, tam, 0.0, base])

# parede reta de a até b (alinhada a X ou Z), de y0 até y0 + h, com aberturas [s0, s1, y_baixo, y_cima]
# (s em metros a partir de a; y relativo a y0). lado_fora: +1/-1 = lado (normal à esquerda de a->b) que fica
# para fora, com a cor cf (o outro lado com cd); 0 = parede interna, uma cor só.
func _parede(c, a: Vector2, b: Vector2, y0: float, h: float, esp: float, cf: Color, cd: Color, vaos: Array, lado_fora := 0, colide := true) -> void:
	var L := a.distance_to(b)
	if L < 0.02:
		return
	var d := (b - a) / L
	var nrm := Vector2(-d.y, d.x)
	var em_x := absf(d.x) > 0.5
	vaos.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
	var pedacos: Array = []
	var cur := 0.0
	for v in vaos:
		var s0 := clampf(float(v[0]), cur, L)
		var s1 := clampf(float(v[1]), s0, L)
		pedacos.append([cur, s0, 0.0, h])
		if float(v[2]) > 0.01:
			pedacos.append([s0, s1, 0.0, float(v[2])])
		if float(v[3]) < h - 0.01:
			pedacos.append([s0, s1, float(v[3]), h])
		cur = s1
	pedacos.append([cur, L, 0.0, h])
	for p in pedacos:
		var s0: float = p[0]
		var s1: float = p[1]
		var hy: float = p[3] - p[2]
		if s1 - s0 < 0.02 or hy < 0.02:
			continue
		var m: Vector2 = a + d * (s0 + s1) * 0.5
		var yc: float = y0 + float(p[2]) + hy * 0.5
		if lado_fora == 0:
			c.caixa(Vector3(m.x, yc, m.y), Vector3(s1 - s0, hy, esp) if em_x else Vector3(esp, hy, s1 - s0), cd)
		else:
			for camada in [[1.0, cf], [-1.0, cd]]:
				var q: Vector2 = m + nrm * esp * 0.25 * float(camada[0]) * float(lado_fora)
				c.caixa(Vector3(q.x, yc, q.y), Vector3(s1 - s0, hy, esp * 0.5) if em_x else Vector3(esp * 0.5, hy, s1 - s0), camada[1])
		if colide:
			col.append([Vector3(m.x, yc, m.y), Vector3(s1 - s0, hy, esp) if em_x else Vector3(esp, hy, s1 - s0), 0.0, Basis.IDENTITY])
	# caixilho das janelas e cacos de vidro no chão
	for v in vaos:
		if v.size() > 4 and v[4] == "janela":
			var m: Vector2 = a + d * (float(v[0]) + float(v[1])) * 0.5
			var w := float(v[1]) - float(v[0])
			var tam := Vector3(w, 0.07, esp + 0.04) if em_x else Vector3(esp + 0.04, 0.07, w)
			resto.caixa(Vector3(m.x, y0 + float(v[2]), m.y), tam, METAL_ESC)
			resto.caixa(Vector3(m.x, y0 + float(v[3]), m.y), tam, METAL_ESC)
			if r.randf() < 0.5:
				for k in r.randi_range(1, 3):
					var q: Vector2 = m + d * r.randf_range(-w * 0.5, w * 0.5) + nrm * r.randf_range(-1.2, 1.2)
					resto.caixa(Vector3(q.x, y0 + 0.01, q.y), Vector3(r.randf_range(0.06, 0.2), 0.01, r.randf_range(0.05, 0.15)), Color(0.55, 0.65, 0.68), Basis(Vector3.UP, r.randf() * 3.0))

# as 4 paredes de fora de um retângulo, com os cantos fechados. vaos[k] = aberturas do lado k (s a partir do
# começo do lado): 0 = frente (+Z, de x0 para x1) · 1 = direita (+X, de z1 para z0) · 2 = fundo (-Z, de x1 para x0) ·
# 3 = esquerda (-X, de z0 para z1)
func _perimetro(ret: Rect2, y0: float, h: float, cf: Color, cd: Color, vaos: Array, c = null) -> void:
	if c == null:
		c = paredes
	var x0 := ret.position.x
	var x1 := ret.end.x
	var z0 := ret.position.y
	var z1 := ret.end.y
	var e := ESP * 0.5
	var lados := [[Vector2(x0 - e, z1), Vector2(x1 + e, z1)], [Vector2(x1, z1 + e), Vector2(x1, z0 - e)],
		[Vector2(x1 + e, z0), Vector2(x0 - e, z0)], [Vector2(x0, z0 - e), Vector2(x0, z1 + e)]]
	for k in 4:
		var v: Array = []
		for ab in vaos[k]:
			var n: Array = (ab as Array).duplicate()
			n[0] = float(n[0]) + e
			n[1] = float(n[1]) + e
			v.append(n)
		_parede(c, lados[k][0], lados[k][1], y0, h, ESP, cf, cd, v, 1)

# janelas a cada "passo" metros numa parede de comprimento L (sem cair em cima das portas)
func _janelas(L: float, passo: float, larg: float, yb: float, yc: float, portas: Array, chance := 0.9) -> Array:
	var v: Array = []
	var s := 1.4
	while s + larg < L - 1.0:
		var livre := true
		for p in portas:
			if s < float(p[1]) + 0.6 and s + larg > float(p[0]) - 0.6:
				livre = false
				break
		if livre and r.randf() < chance:
			v.append([s, s + larg, yb, yc, "janela"])
		s += passo
	return v + portas

const RAMPA_ANTES := 0.15            # 1.04: a rampa de colisão chega no topo esse tanto antes do fim (e fica plana)
const RAMPA_DEPOIS := 0.35           # o pedaço plano passa do fim da escada (cobre a borda do patamar)

# escada reta: pé em "ini", sobe na direção "dir" (eixo X ou Z) por "comp" metros até subir "dy"
func _escada(ini: Vector2, dir: Vector2, larg: float, y0: float, dy: float, comp: float, cor: Color, corrimao := 0) -> void:
	escadas.append([ini, dir, larg, y0, dy, comp, corrimao])   # 1.02: + lado do corrimão (0 = sem)
	var n := int(ceil(dy / 0.19))
	var lat := Vector2(-dir.y, dir.x)
	for i in n:
		var t := (i + 0.5) / n
		var p := ini + dir * comp * t
		var topo := y0 + (i + 1) * dy / n
		var lo := comp / n + 0.01
		var hh := minf(topo - y0, 0.6)                         # degrau "vazado" (dá para passar por baixo do alto)
		var tam := Vector3(lo, hh, larg) if absf(dir.x) > 0.5 else Vector3(larg, hh, lo)
		resto.caixa(Vector3(p.x, topo - hh * 0.5, p.y), tam, cor * (0.95 if i % 2 == 0 else 1.0))
	# corrimão (lado: +1/-1 = qual lateral)
	if corrimao != 0:
		var q0 := ini + lat * (larg * 0.5 - 0.05) * corrimao
		for k in 5:
			var t := k / 4.0
			var q := q0 + dir * comp * t
			resto.cilindro(Vector3(q.x, y0 + dy * t + 0.5, q.y), 0.025, 1.0, 5, METAL_ESC)
		var meio := q0 + dir * comp * 0.5
		var u3 := (Vector3(dir.x, 0, dir.y) * comp + Vector3.UP * dy)
		var bb := Basis(Vector3.UP, atan2(dir.x, dir.y)) * Basis(Vector3.RIGHT, -atan2(dy, comp))
		resto.caixa(Vector3(meio.x, y0 + dy * 0.5 + 1.0, meio.y), Vector3(0.05, 0.05, u3.length()), METAL_ESC, bb)
	# rampa invisível de colisão (o personagem sobe sem tropeçar nos degraus)
	# 1.04: a rampa chega na altura do topo RAMPA_ANTES m antes do fim e dali é PLANA até passar da borda do patamar.
	# Antes ela ia até o fim (e um pouco além) e o patamar/laje de cima começava ~10 cm antes: sobrava um degrauzinho de
	# ~5 cm em cima da rampa inclinada que a cápsula do personagem tomava por parede (só passava pulando; posto,
	# supermercado, metrô, quartel). O prolongamento da rampa fica só embaixo (enterrado no chão).
	var dir3 := Vector3(dir.x, 0.0, dir.y)
	var c_r := comp - RAMPA_ANTES
	var u := (dir3 * c_r + Vector3.UP * dy).normalized()
	var x := Vector3(lat.x, 0.0, lat.y)
	var y := u.cross(x)
	if y.y < 0.0:
		x = -x
		y = -y
	var l_r := sqrt(c_r * c_r + dy * dy)
	var meio2 := ini + dir * c_r * 0.5
	col.append([Vector3(meio2.x, y0 + dy * 0.5, meio2.y) - y * 0.15 - u * 0.075, Vector3(larg, 0.3, l_r + 0.15), 0.0, Basis(x, y, u)])
	var pl := ini + dir * (c_r + (RAMPA_ANTES + RAMPA_DEPOIS) * 0.5)
	var l_p := RAMPA_ANTES + RAMPA_DEPOIS
	col.append([Vector3(pl.x, y0 + dy - 0.1, pl.y), Vector3(l_p, 0.2, larg) if absf(dir.x) > 0.5 else Vector3(larg, 0.2, l_p), 0.0, Basis.IDENTITY])
	# 1.02: o CORRIMÃO segura (antes era só desenho: dava para cair da escada por baixo dele e quebrar a perna).
	# Uma "parede" fina inclinada como a escada, da rampa até a altura do corrimão.
	# 1.03: em PEDAÇOS RETOS em pé seguindo a subida (uma caixa inclinada só passava das pontas da escada e trancava
	# quem passava rente ao pé ou ao topo dela)
	if corrimao != 0:
		var n_ped := maxi(4, int(ceil(comp / 0.8)))
		for k in n_ped:
			var tk := (k + 0.5) / n_ped
			var mk := ini + lat * (larg * 0.5 - 0.05) * corrimao + dir * comp * tk
			var tam_k := Vector3(comp / n_ped, 1.4, 0.08) if absf(dir.x) > 0.5 else Vector3(0.08, 1.4, comp / n_ped)
			col.append([Vector3(mk.x, y0 + dy * tk + 0.4, mk.y), tam_k, 0.0, Basis.IDENTITY])

# grade de proteção de a até b na altura y
func _grade(a: Vector2, b: Vector2, y: float, cor := METAL_ESC) -> void:
	var L := a.distance_to(b)
	if L < 0.1:
		return
	var k := 0.0
	while k <= L + 0.01:
		var p := a.lerp(b, k / L)
		resto.cilindro(Vector3(p.x, y + 0.5, p.y), 0.025, 1.0, 5, cor)
		k += 1.2
	var m := (a + b) * 0.5
	var em_x := absf(b.x - a.x) > absf(b.y - a.y)
	var tam := Vector3(L, 0.05, 0.05) if em_x else Vector3(0.05, 0.05, L)
	resto.caixa(Vector3(m.x, y + 1.0, m.y), tam, cor)
	resto.caixa(Vector3(m.x, y + 0.5, m.y), tam, cor)
	col.append([Vector3(m.x, y + 0.55, m.y), Vector3(L, 1.1, 0.08) if em_x else Vector3(0.08, 1.1, L), 0.0, Basis.IDENTITY])

# laje: forro embaixo (teto), piso em cima (piso de dentro ou "fora" no telhado) e colisão; "buracos" = vãos de escada
func _laje(ret: Rect2, y: float, esp: float, buracos: Array, cor_cima: Color, cima_fora := false, cor_forro := Color(0.78, 0.77, 0.74)) -> void:
	var partes: Array[Rect2] = [ret]
	for bu in buracos:
		var novas: Array[Rect2] = []
		for p in partes:
			var b: Rect2 = (bu as Rect2).intersection(p)
			if b.size.x <= 0.0 or b.size.y <= 0.0:
				novas.append(p)
				continue
			novas.append(Rect2(p.position.x, p.position.y, b.position.x - p.position.x, p.size.y))
			novas.append(Rect2(b.end.x, p.position.y, p.end.x - b.end.x, p.size.y))
			novas.append(Rect2(b.position.x, p.position.y, b.size.x, b.position.y - p.position.y))
			novas.append(Rect2(b.position.x, b.end.y, b.size.x, p.end.y - b.end.y))
		partes = novas
	for p in partes:
		if p.size.x < 0.02 or p.size.y < 0.02:
			continue
		var c := p.get_center()
		teto.caixa(Vector3(c.x, y + esp * 0.5 - 0.02, c.y), Vector3(p.size.x, esp - 0.04, p.size.y), cor_forro, Basis.IDENTITY, false, true)
		(fora if cima_fora else piso).caixa(Vector3(c.x, y + esp - 0.02, c.y), Vector3(p.size.x, 0.04, p.size.y), cor_cima, Basis.IDENTITY, true)
		col.append([Vector3(c.x, y + esp * 0.5, c.y), Vector3(p.size.x, esp, p.size.y), 0.0, Basis.IDENTITY])

# chão pintado (asfalto/concreto) por cima do lote, sem colisão (o lote já é o chão). 0.78: numa superfície própria com
# "camada" (como os pisos da cidade): ao longe o chão do lote (camada 3,5) passava por cima e o asfalto sumia
const CAMADA_CHAO := 4.5
func _chao(ret: Rect2, cor: Color, y := 0.015) -> void:
	var c := ret.get_center()
	chao.caixa(Vector3(c.x, y, c.y), Vector3(ret.size.x, 0.03, ret.size.y), cor, Basis.IDENTITY, true)

func _faixa(a: Vector2, b: Vector2, larg := 0.12, cor := FAIXA, y := 0.035) -> void:
	var m := (a + b) * 0.5
	var L := a.distance_to(b)
	var em_x := absf(b.x - a.x) > absf(b.y - a.y)
	(chao if y < 0.1 else fora).caixa(Vector3(m.x, y, m.y), Vector3(L, 0.01, larg) if em_x else Vector3(larg, 0.01, L), cor, Basis.IDENTITY, true)

# vagas de estacionamento: fileira de linhas ao longo de X, de x0 até x1, vagas de "fundo" metros a partir de z0
func _vagas(x0: float, x1: float, z0: float, fundo: float) -> void:
	var x := x0
	while x <= x1 + 0.01:
		_faixa(Vector2(x, z0), Vector2(x, z0 + fundo))
		x += 2.7

# móvel de mundo/moveis.gd (loot trocado para a tabela do local, se pedir)
func _movel(nome: String, p: Vector3, g: float, loot := "", nome_cont := "") -> void:
	var antes := cont.size()
	Moveis.desenhar(nome, resto, p, Basis(Vector3.UP, g + r.randf_range(-0.04, 0.04)), r, col, cont, tipo)
	for k in range(antes, cont.size()):
		if loot != "":
			cont[k]["loot"] = loot
		if nome_cont != "":
			cont[k]["nome"] = nome_cont

# letreiro/pichação (Label3D, virado para +Z local girado de g)
func _texto(p: Vector3, g: float, texto: String, cor: Color, tam := 64) -> void:
	textos.append([p, g, texto, cor, tam])

func _loot(p: Vector3, loot: String, nome: String, tam: Vector2i) -> void:
	cont.append({"pos": p, "loot": loot, "nome": nome, "tam": tam})

func _ponto(p: Vector3, comodo: String) -> void:
	pontos.append([p, comodo])

# pontos de loot solto espalhados num retângulo (y = andar)
func _pontos_em(ret: Rect2, y: float, n: int, comodo: String) -> void:
	for k in n:
		_ponto(Vector3(r.randf_range(ret.position.x + 0.6, ret.end.x - 0.6), y, r.randf_range(ret.position.y + 0.6, ret.end.y - 0.6)), comodo)

# carro abandonado (caixas) com porta-malas de loot · tombado = deitado de lado
func _carro(p: Vector2, g: float, cor: Color, loot := "carro", tombado := false, nome := "PORTA-MALAS") -> void:
	var rb := Basis(Vector3.UP, g)
	var b := rb * Basis(Vector3.BACK, PI * 0.5) if tombado else rb
	var o := Vector3(p.x, 0.9 if tombado else 0.0, p.y)
	var off := Vector3(0, 0.75, 0) if tombado else Vector3.ZERO
	for pc in [[Vector3(0, 0.62, 0), Vector3(1.8, 0.62, 4.3), cor], [Vector3(0, 1.15, -0.2), Vector3(1.6, 0.5, 2.2), cor * 0.9],
			[Vector3(0, 1.16, -0.2), Vector3(1.62, 0.38, 1.9), Color(0.12, 0.14, 0.16)], [Vector3(0, 0.62, 2.16), Vector3(1.5, 0.15, 0.05), Color(0.9, 0.85, 0.6)]]:
		resto.caixa(o + b * ((pc[0] as Vector3) - off), pc[1], pc[2], b)
	for x in [-0.82, 0.82]:
		for z in [-1.35, 1.35]:
			resto.cilindro(o + b * (Vector3(x, 0.34, z) - off), 0.34, 0.22, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	if tombado:
		col.append([Vector3(p.x, 0.9, p.y), Vector3(1.5, 1.8, 4.3), 0.0, rb])
	else:
		col.append([Vector3(p.x, 0.75, p.y), Vector3(1.8, 1.5, 4.3), 0.0, rb])
	if loot != "":
		_loot(Vector3(p.x, 0.1, p.y) + rb * Vector3(0, 0, -2.7), loot, nome, Vector2i(6, 4))

# sacos de areia em linha de a até b (altura em camadas), apoiados em y
func _sacos(a: Vector2, b: Vector2, camadas := 3, y := 0.0) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / maxf(L, 0.01)
	var g := atan2(d.x, d.y) + PI * 0.5
	for k in camadas:
		var s := 0.3 if k % 2 == 1 else 0.0
		while s < L - 0.3:
			var p := a + d * (s + 0.3)
			resto.caixa(Vector3(p.x, y + 0.14 + k * 0.26, p.y), Vector3(0.62, 0.26, 0.4), SACO * r.randf_range(0.85, 1.08), Basis(Vector3.UP, g + r.randf_range(-0.08, 0.08)))
			s += 0.6
	var m := (a + b) * 0.5
	col.append([Vector3(m.x, y + camadas * 0.13, m.y), Vector3(0.45, camadas * 0.26, L), 0.0, Basis(Vector3.UP, atan2(d.x, d.y))])

# barreira de concreto (new jersey)
func _barreira(p: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	resto.caixa(Vector3(p.x, 0.2, p.y), Vector3(0.62, 0.4, 3.0), CONCRETO * 1.05, b)
	resto.caixa(Vector3(p.x, 0.6, p.y), Vector3(0.3, 0.45, 3.0), CONCRETO * 1.05, b)
	col.append([Vector3(p.x, 0.42, p.y), Vector3(0.6, 0.85, 3.0), 0.0, b])

# barril (óleo/combustível)
func _barril(p: Vector2, cor: Color, deitado := false) -> void:
	if deitado:
		resto.cilindro(Vector3(p.x, 0.3, p.y), 0.3, 0.9, 10, cor, Basis(Vector3.UP, r.randf() * 3.0) * Basis(Vector3.FORWARD, PI * 0.5))
	else:
		resto.cilindro(Vector3(p.x, 0.45, p.y), 0.3, 0.9, 10, cor)
		col.append([Vector3(p.x, 0.45, p.y), Vector3(0.6, 0.9, 0.6), 0.0, Basis.IDENTITY])

# poste de luz
func _poste(p: Vector2, g: float, h := 7.0) -> void:
	fora.cilindro(Vector3(p.x, h * 0.5, p.y), 0.09, h, 6, METAL_ESC)
	var d := Vector2(sin(g), cos(g))
	var q := p + d * 0.9
	fora.caixa(Vector3((p.x + q.x) * 0.5, h - 0.05, (p.y + q.y) * 0.5), Vector3(0.1, 0.1, 1.8) if absf(d.y) > 0.5 else Vector3(1.8, 0.1, 0.1), METAL_ESC)
	fora.caixa(Vector3(q.x, h - 0.15, q.y), Vector3(0.5, 0.12, 0.3), Color(0.9, 0.9, 0.82))
	col.append([Vector3(p.x, h * 0.5, p.y), Vector3(0.2, h, 0.2), 0.0, Basis.IDENTITY])

# lixeira grande (caçamba) com loot
func _cacamba(p: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	resto.caixa(Vector3(p.x, 0.7, p.y), Vector3(2.0, 1.3, 1.3), Color(0.18, 0.32, 0.2), b)
	resto.caixa(Vector3(p.x, 1.38, p.y) + b * Vector3(0, 0, -0.2), Vector3(2.0, 0.06, 0.9), Color(0.12, 0.2, 0.13), b * Basis(Vector3.RIGHT, -0.5))
	col.append([Vector3(p.x, 0.7, p.y), Vector3(2.0, 1.4, 1.3), 0.0, b])
	_loot(Vector3(p.x, 0.0, p.y) + b * Vector3(0, 0, 1.0), "lixo", "CAÇAMBA", Vector2i(5, 3))

# placa com faixas coloridas (fachada/totem)
func _placa(p: Vector3, tam: Vector3, cor: Color, cor2: Color) -> void:
	fora.caixa(p, tam, cor)
	fora.caixa(p + Vector3(0, -tam.y * 0.3, 0), tam * Vector3(1.01, 0.18, 1.04), cor2)

# entulho e papéis num retângulo (abandono)
func _bagunca(ret: Rect2, y: float, n: int) -> void:
	for k in n:
		var p := Vector2(r.randf_range(ret.position.x, ret.end.x), r.randf_range(ret.position.y, ret.end.y))
		resto.caixa(Vector3(p.x, y + 0.008, p.y), Vector3(0.21, 0.004, 0.3), Moveis.BRANCO * r.randf_range(0.6, 1.0), Basis(Vector3.UP, r.randf() * 3.0))
	for k in n / 4:
		var p := Vector2(r.randf_range(ret.position.x, ret.end.x), r.randf_range(ret.position.y, ret.end.y))
		var s := r.randf_range(0.5, 1.6)
		resto.caixa(Vector3(p.x, y + 0.004, p.y), Vector3(s, 0.003, s * r.randf_range(0.5, 1.0)), Color(0.18, 0.08, 0.06), Basis(Vector3.UP, r.randf() * 3.0))

# ======================================================================================================
# POSTO DE GASOLINA (46 x 36): pátio com cobertura e 2 ilhas de bombas, loja de conveniência (balcão, gôndolas,
# geladeiras, banheiro, estoque), oficina com elevador de carro e bancada, totem de preços, caçamba, botijões,
# e ESCADA DE FERRO até o TELHADO (mureta: vigia o pátio inteiro).
# ======================================================================================================
func _posto() -> void:
	var cor_loja := Color(0.78, 0.76, 0.7)
	var cor_marca := Color(0.72, 0.12, 0.1)
	var parede_d := Color(0.86, 0.86, 0.82)
	var h := 4.4
	# chão: pátio de asfalto na frente, concreto atrás
	_chao(Rect2(-23, -2, 46, 20), ASFALTO)
	_chao(Rect2(-23, -18, 46, 16), CONCRETO_ESC)
	for x in [-9.0, 13.0]:
		_faixa(Vector2(x, 0), Vector2(x, 16), 0.15, AMARELO)
	# ---- loja (x -21..-3) e oficina (x -3..9), z -17..-5 ----
	var pr := Rect2(-21, -17, 30, 12)
	dentro = pr.grow(-ESP * 0.5)
	_perimetro(pr, 0.0, h, cor_loja, parede_d, [
		# frente: vitrines e porta dupla da loja · portão de enrolar da oficina (meio aberto)
		[[2.5, 5.8, 0.5, 3.2, "janela"], [7.0, 9.4, 0.0, 2.6], [10.2, 13.6, 0.5, 3.2, "janela"], [14.3, 17.2, 0.5, 3.2, "janela"], [21.0, 27.0, 0.0, 3.6]],
		# direita (oficina): janela alta
		[[3.0, 4.6, 2.0, 3.0, "janela"]],
		# fundo: janela da oficina e porta dos fundos da loja (para o beco)
		[[4.0, 5.2, 1.8, 2.6, "janela"], [21.0, 22.8, 0.0, PORTA_A]],
		# esquerda: porta lateral da loja
		[[8.3, 10.1, 0.0, PORTA_A]]])
	resto.caixa(Vector3(3.0, 3.25, -4.92), Vector3(6.0, 0.7, 0.08), METAL)                    # portão de enrolar (no alto)
	for k in 5:
		resto.caixa(Vector3(3.0, 2.95 + k * 0.14, -4.85), Vector3(6.0, 0.02, 0.02), METAL_ESC)
	# loja x oficina (porta de ligação), banheiro e estoque no fundo da loja (z -17..-13)
	_parede(paredes, Vector2(-3, -5), Vector2(-3, -17), 0.0, h, DIV, Color.WHITE, CONCRETO * 1.1, [[2.0, 3.8, 0.0, PORTA_A]])
	_parede(paredes, Vector2(-11, -13), Vector2(-3, -13), 0.0, h, DIV, Color.WHITE, Color(0.8, 0.82, 0.8), [[1.0, 2.6, 0.0, PORTA_A], [5.2, 6.8, 0.0, PORTA_A]])
	_parede(paredes, Vector2(-11, -17), Vector2(-11, -13), 0.0, h, DIV, Color.WHITE, Color(0.8, 0.82, 0.8), [])
	_parede(paredes, Vector2(-7, -17), Vector2(-7, -13), 0.0, h, DIV, Color.WHITE, Color(0.8, 0.82, 0.8), [])
	# piso e laje (telhado plano com mureta)
	piso.caixa(Vector3(-12, 0.02, -11), Vector3(17.7, 0.04, 11.7), Color(0.82, 0.82, 0.78), Basis.IDENTITY, true)
	concreto.caixa(Vector3(3, 0.02, -11), Vector3(11.7, 0.04, 11.7), CONCRETO * 0.85, Basis.IDENTITY, true)
	_laje(pr.grow(ESP * 0.5), h, 0.4, [], CONCRETO, true)
	var yt := h + 0.4
	_mureta(pr.grow(ESP * 0.5), yt, 1.0, [[Vector2(9.15, -15.2), Vector2(9.15, -13.2)]])
	# telhado: ar-condicionado e respiros (cobertura para quem vigia daqui de cima)
	for p in [Vector2(-16, -12), Vector2(-9, -9), Vector2(2, -13)]:
		_bx(fora, Vector3(p.x, yt + 0.55, p.y), Vector3(1.6, 1.1, 1.2), Color(0.62, 0.63, 0.62))
	fora.cilindro(Vector3(-4, yt + 0.6, -15), 0.12, 1.2, 6, METAL_ESC)
	_ponto(Vector3(-12, yt, -8), "telhado")
	_ponto(Vector3(4, yt, -10), "telhado")
	# escada de ferro na lateral da oficina (x 9.3..10.6): sobe do pátio (z -4.6) para o fundo até o telhado
	_escada(Vector2(9.95, -4.6), Vector2(0, -1), 1.3, 0.0, yt, 9.0, METAL, 1)
	resto.caixa(Vector3(9.95, yt - 0.06, -14.4), Vector3(1.3, 0.12, 1.8), METAL)                      # patamar
	_col(Vector3(9.95, yt - 0.1, -14.4), Vector3(1.3, 0.2, 1.8))
	_grade(Vector2(10.6, -13.5), Vector2(10.6, -15.3), yt)
	_grade(Vector2(9.3, -15.3), Vector2(10.6, -15.3), yt)
	# ---- loja por dentro ----
	_movel("balcao", Vector3(-6.2, 0, -7.4), 0.0, "balcao", "CAIXA DO POSTO")
	_movel("prateleira", Vector3(-5.0, 0, -12.62), 0.0, "posto_loja", "PRATELEIRA DE CIGARROS")
	for p in [Vector2(-17.0, -9.6), Vector2(-13.5, -9.6), Vector2(-17.0, -11.9), Vector2(-13.5, -11.9)]:
		_movel("gondola", Vector3(p.x, 0, p.y), 0.0, "posto_loja", "GÔNDOLA")
	_geladeiras(Vector2(-20.45, -16.85), Vector2(0, 1), Vector2(1, 0), 3, "posto_bebidas")
	_movel("bancada", Vector3(-15.5, 0, -16.5), 0.0, "posto_loja", "BALCÃO DO CAFÉ")
	resto.caixa(Vector3(-15.0, 1.15, -16.6), Vector3(0.5, 0.5, 0.4), Moveis.PRETO)                    # máquina de café
	_movel("vaso", Vector3(-4.0, 0, -16.5), 0.0)
	_movel("pia", Vector3(-6.0, 0, -16.6), 0.0, "banheiro")
	_movel("prateleira", Vector3(-9.0, 0, -16.5), 0.0, "posto_deposito", "ESTOQUE")
	_movel("caixas", Vector3(-9.0, 0, -14.3), 0.0, "posto_deposito", "CAIXAS DO ESTOQUE")
	_pontos_em(Rect2(-20, -12.5, 12, 6.5), 0.0, 5, "loja")
	_bagunca(Rect2(-20.5, -12.8, 17, 7.5), 0.0, 14)
	# ---- oficina por dentro ----
	_movel("bancada", Vector3(1.0, 0, -16.5), 0.0, "posto_oficina", "BANCADA DE FERRAMENTAS")
	_movel("bancada", Vector3(5.5, 0, -16.5), 0.0, "posto_oficina", "BANCADA")
	_bx(resto, Vector3(8.45, 1.0, -9.0), Vector3(0.55, 2.0, 1.6), Color(0.62, 0.12, 0.1))             # armário de ferramentas
	_loot(Vector3(7.6, 0.1, -9.0), "posto_oficina", "ARMÁRIO DE FERRAMENTAS", Vector2i(6, 4))
	# elevador com carro em cima (dá para se esconder embaixo)
	for x in [0.9, 4.0]:
		_bx(resto, Vector3(x, 1.0, -11.0), Vector3(0.35, 2.0, 0.35), Color(0.75, 0.6, 0.1))
	resto.caixa(Vector3(2.45, 1.75, -11.0), Vector3(1.9, 0.12, 4.4), METAL_ESC)
	resto.caixa(Vector3(2.45, 2.25, -11.0), Vector3(1.8, 0.6, 4.3), Color(0.25, 0.32, 0.45))
	resto.caixa(Vector3(2.45, 2.75, -11.2), Vector3(1.6, 0.45, 2.1), Color(0.23, 0.29, 0.4))
	_col(Vector3(2.45, 2.3, -11.0), Vector3(1.9, 1.2, 4.4))
	for k in 4:
		_barril(Vector2(-1.9 + (k % 2) * 0.65, -15.9 + (k / 2) * 0.65), [Color(0.2, 0.3, 0.55), Color(0.55, 0.18, 0.12)][k % 2])
	for k in 5:
		resto.cilindro(Vector3(7.9, 0.12 + k * 0.24, -15.9), 0.36, 0.22, 10, Color(0.08, 0.08, 0.09))   # pneus
	_col(Vector3(7.9, 0.6, -15.9), Vector3(0.75, 1.2, 0.75))
	_pontos_em(Rect2(-2, -14, 10, 7), 0.0, 3, "oficina")
	# ---- cobertura e bombas ----
	var cy := 5.2
	var cob := Rect2(-10, 0, 24, 13)
	var cc := cob.get_center()
	fora.caixa(Vector3(cc.x, cy + 0.45, cc.y), Vector3(cob.size.x, 0.9, cob.size.y), Color(0.9, 0.9, 0.88))
	fora.caixa(Vector3(cc.x, cy + 0.45, cc.y), Vector3(cob.size.x + 0.1, 0.35, cob.size.y + 0.1), cor_marca)
	_col(Vector3(cc.x, cy + 0.45, cc.y), Vector3(cob.size.x, 0.9, cob.size.y))
	for x in [-4.0, 8.0]:
		for z in [2.0, 11.0]:
			_bx(fora, Vector3(x, cy * 0.5, z), Vector3(0.5, cy, 0.5), Color(0.85, 0.85, 0.83))
	for x in range(-8, 13, 4):
		fora.caixa(Vector3(x, cy - 0.03, 6.5), Vector3(1.6, 0.05, 0.6), Color(1.0, 1.0, 0.92))       # luminárias
	for x in [-1.0, 5.0]:
		_bx(fora, Vector3(x, 0.11, 6.5), Vector3(1.3, 0.22, 7.0), CONCRETO * 1.1)                      # ilha
		_faixa(Vector2(x - 0.66, 3.0), Vector2(x - 0.66, 10.0), 0.05, AMARELO, 0.225)
		_faixa(Vector2(x + 0.66, 3.0), Vector2(x + 0.66, 10.0), 0.05, AMARELO, 0.225)
		for z in [4.6, 8.4]:
			_bomba(Vector2(x, z), cor_marca)
		for z in [2.8, 10.2]:
			_bx(fora, Vector3(x, 0.6, z), Vector3(0.22, 1.2, 0.22), AMARELO)                            # pilarete
		_bx(resto, Vector3(x + 0.35, 0.62, 6.5), Vector3(0.35, 0.8, 0.35), Color(0.2, 0.25, 0.22))     # lixeira
	# carros abandonados (porta-malas com loot)
	_carro(Vector2(-2.8, 6.5), 0.05, Color(0.55, 0.12, 0.1))
	_carro(Vector2(10.8, 7.5), -0.35, Color(0.3, 0.35, 0.4))
	_carro(Vector2(-15.5, 7.0), 1.4, Color(0.75, 0.72, 0.62), "carro", true)
	# totem de preços
	fora.cilindro(Vector3(19.5, 3.5, 15.0), 0.25, 7.0, 8, METAL_ESC)
	_col(Vector3(19.5, 3.5, 15.0), Vector3(0.5, 7.0, 0.5))
	_placa(Vector3(19.5, 7.6, 15.0), Vector3(2.8, 3.0, 0.4), Color(0.92, 0.92, 0.9), cor_marca)
	for k in 3:
		fora.caixa(Vector3(19.5, 8.5 - k * 0.7, 15.22), Vector3(1.9, 0.45, 0.05), Color(0.1, 0.1, 0.1))
	# pátio dos fundos: caçamba, botijões na grade, gerador, calibrador, freezer de gelo
	_cacamba(Vector2(19.5, -9.0), PI * 0.5)
	for k in 6:
		resto.cilindro(Vector3(14.0 + (k % 3) * 0.55, 0.5, -14.0 + (k / 3) * 0.55), 0.22, 1.0, 8, Color(0.25, 0.45, 0.65))
	_gaiola(Rect2(13.5, -14.5, 1.9, 1.3), 1.6)
	_bx(resto, Vector3(17.5, 0.75, -15.0), Vector3(2.4, 1.5, 1.2), Color(0.5, 0.52, 0.3))              # gerador
	_bx(resto, Vector3(14.5, 0.7, -2.5), Vector3(0.5, 1.4, 0.4), Color(0.2, 0.35, 0.6))                # calibrador
	_bx(resto, Vector3(-8.5, 0.5, -3.6), Vector3(1.4, 1.0, 0.8), Color(0.82, 0.86, 0.9))                # freezer de gelo
	_loot(Vector3(-8.5, 0.1, -2.8), "posto_bebidas", "FREEZER DE GELO", Vector2i(5, 3))
	for p in [Vector2(-22, 16), Vector2(16, -3)]:
		_poste(p, 0.0)
	_ponto(Vector3(16, 0, 5), "patio")
	_ponto(Vector3(-6, 0, 13), "patio")
	_ponto(Vector3(2, 0, 1), "patio")
	_bagunca(Rect2(-20, -1, 40, 18), 0.0, 10)
	infectados = [Vector3(-14, 0, -8), Vector3(3, 0, -7), Vector3(2, 0, 13), Vector3(15, 0, 9)]

func _bomba(p: Vector2, cor: Color) -> void:
	bombas.append(Vector3(p.x, 0.0, p.y))
	_bx(resto, Vector3(p.x, 0.22 + 0.85, p.y), Vector3(0.75, 1.7, 0.5), Color(0.9, 0.9, 0.88))
	resto.caixa(Vector3(p.x, 0.22 + 1.85, p.y), Vector3(0.8, 0.3, 0.55), cor)
	for s in [-1.0, 1.0]:
		resto.caixa(Vector3(p.x + s * 0.39, 0.22 + 1.25, p.y), Vector3(0.02, 0.35, 0.3), Color(0.1, 0.12, 0.12))
		resto.caixa(Vector3(p.x + s * 0.4, 0.22 + 0.8, p.y + 0.15), Vector3(0.06, 0.18, 0.08), Moveis.PRETO)
		resto.caixa(Vector3(p.x + s * 0.5, 0.22 + 0.55, p.y + 0.15), Vector3(0.04, 0.9, 0.04), Moveis.PRETO, Basis(Vector3.FORWARD, s * 0.3))

# geladeiras de porta de vidro em fila (ao longo de "dir"), de costas para a parede, abrindo para "frente"
func _geladeiras(ini: Vector2, dir: Vector2, frente: Vector2, n: int, loot: String) -> void:
	var b := Basis(Vector3.UP, atan2(frente.x, frente.y))
	for k in n:
		var p := ini + dir * (k * 1.25 + 0.6)
		resto.caixa(Vector3(p.x, 1.05, p.y), Vector3(1.2, 2.1, 0.75), Color(0.85, 0.86, 0.86), b)
		resto.caixa(Vector3(p.x, 1.1, p.y) + b * Vector3(0, 0, 0.38), Vector3(1.05, 1.75, 0.02), VIDRO * 1.2, b)
		for y in [0.55, 0.95, 1.35, 1.75]:
			if r.randf() < 0.6:
				resto.caixa(Vector3(p.x, y, p.y) + b * Vector3(r.randf_range(-0.3, 0.3), 0, 0.15), Vector3(0.5, 0.25, 0.3), Color(r.randf(), r.randf(), r.randf()).lerp(Color.WHITE, 0.3), b)
		col.append([Vector3(p.x, 1.05, p.y), Vector3(1.2, 2.1, 0.75), 0.0, b])
		_loot(Vector3(p.x, 0.1, p.y) + b * Vector3(0, 0, 0.9), loot, "GELADEIRA", Vector2i(4, 4))

# mureta em volta de um telhado (aberturas = trechos [a, b] sem mureta, para a escada chegar)
func _mureta(ret: Rect2, y: float, h: float, aberturas: Array) -> void:
	var cs := [ret.position, Vector2(ret.end.x, ret.position.y), ret.end, Vector2(ret.position.x, ret.end.y)]
	for k in 4:
		var a: Vector2 = cs[k]
		var b: Vector2 = cs[(k + 1) % 4]
		var L := a.distance_to(b)
		var d := (b - a) / L
		var vaos: Array = []
		for ab in aberturas:
			var pa: Vector2 = ab[0]
			var pb: Vector2 = ab[1]
			# abertura em cima deste lado?
			if absf((pa - a).cross(d)) < 0.3 and absf((pb - a).cross(d)) < 0.3:
				var s0 := (pa - a).dot(d)
				var s1 := (pb - a).dot(d)
				vaos.append([minf(s0, s1), maxf(s0, s1), 0.0, 99.0])
		var dentro_n := Vector2(-d.y, d.x)
		var a2 := a + dentro_n * 0.12
		var b2 := b + dentro_n * 0.12
		_parede(fora, a2, b2, y, h, 0.24, CONCRETO, CONCRETO, vaos)

# grade de alambrado (gaiola dos botijões)
func _gaiola(ret: Rect2, h: float) -> void:
	var cs := [ret.position, Vector2(ret.end.x, ret.position.y), ret.end, Vector2(ret.position.x, ret.end.y)]
	for k in 4:
		var a: Vector2 = cs[k]
		var b: Vector2 = cs[(k + 1) % 4]
		var m := (a + b) * 0.5
		var em_x := absf(b.x - a.x) > 0.1
		resto.caixa(Vector3(m.x, h * 0.5, m.y), Vector3(a.distance_to(b), h, 0.02) if em_x else Vector3(0.02, h, a.distance_to(b)), Color(0.5, 0.52, 0.55, 1.0))
		resto.cilindro(Vector3(a.x, h * 0.5, a.y), 0.03, h, 5, METAL_ESC)
	col.append([Vector3(ret.get_center().x, h * 0.5, ret.get_center().y), Vector3(ret.size.x, h, ret.size.y), 0.0, Basis.IDENTITY])

# ======================================================================================================
# HOSPITAL (72 x 54): prédio de 2 andares (60 x 24) + telhado com HELIPONTO, casinha da escada e ninho de sacos de
# areia. Térreo: recepção, farmácia (balcão para a recepção), EMERGÊNCIA com macas e cortinas (porta das
# ambulâncias), corredor, consultório, laboratório, raio-x, depósito médico, necrotério e refeitório. 1º andar:
# 4 enfermarias, UTI, escritório dos médicos, CENTRO CIRÚRGICO e esterilização. Na frente: marquise da entrada,
# cobertura das ambulâncias, praça, estacionamento e um POSTO MILITAR abandonado (sacos de areia, barreiras,
# barracas com caixas militares, caminhão do exército).
# ======================================================================================================
func _porta(s: float, larg := PORTA) -> Array:
	return [s - larg * 0.5, s + larg * 0.5, 0.0, PORTA_A]

func _hospital() -> void:
	var B := Rect2(-30, -26, 60, 24)
	var cor_f := Color(0.86, 0.84, 0.78)
	var cor_d := Color(0.84, 0.87, 0.86)
	var verde_h := Color(0.62, 0.74, 0.72)
	dentro = B.grow(-ESP * 0.5)
	var xi := -29.85
	var xf := 29.85
	# ---- chão de fora ----
	_chao(Rect2(-36, -2, 72, 8), CONCRETO * 1.05)
	_chao(Rect2(-36, 6, 72, 21), ASFALTO)
	_chao(Rect2(-36, -27, 72, 1), CONCRETO_ESC)
	for z0 in [8.0, 20.5]:
		_vagas(-34.0, -9.5, z0, 5.0)
		_vagas(9.5, 34.0, z0, 5.0)
	_faixa(Vector2(-3, 6.5), Vector2(-3, 26.5), 0.15, AMARELO)
	_faixa(Vector2(3, 6.5), Vector2(3, 26.5), 0.15, AMARELO)
	# ---- paredes de fora (2 andares) ----
	var frente0 := _janelas(60.0, 3.6, 1.6, 1.0, 2.6, [[24.0, 28.4, 0.35, 3.3, "janela"], [28.4, 31.6, 0.0, 2.9], [31.6, 36.0, 0.35, 3.3, "janela"], [51.0, 54.0, 0.0, 3.2]])
	var lado_d0 := _janelas(24.0, 3.6, 1.6, 1.0, 2.6, [])
	var fundo0 := _janelas(60.0, 4.8, 1.4, 1.4, 2.5, [_porta(12.6, 2.0)], 0.5)
	var lado_e0 := _janelas(24.0, 3.6, 1.6, 1.0, 2.6, [_porta(19.0)])
	_perimetro(B, 0.0, ANDAR, cor_f, cor_d, [frente0, lado_d0, fundo0, lado_e0])
	var j1 := [_janelas(60.0, 3.6, 1.6, 1.0, 2.6, []), _janelas(24.0, 3.6, 1.6, 1.0, 2.6, []), _janelas(60.0, 3.6, 1.6, 1.0, 2.6, []), _janelas(24.0, 3.6, 1.6, 1.0, 2.6, [])]
	_perimetro(B, ANDAR, ANDAR, cor_f, cor_d, j1)
	fora.caixa(Vector3(0, ANDAR - 0.1, -1.83), Vector3(60.4, 0.25, 0.1), Color(0.55, 0.62, 0.62))   # friso entre os andares
	# ---- lajes, escadas e telhado ----
	var buraco_a := Rect2(-2.65, -24.0, 1.5, 8.0)
	var buraco_b := Rect2(1.15, -24.0, 1.5, 8.0)
	piso.caixa(Vector3(0, 0.02, -14), Vector3(59.7, 0.04, 23.7), Color(0.8, 0.82, 0.8), Basis.IDENTITY, true)
	_laje(B.grow(-0.05), PE, LAJE, [buraco_a], Color(0.74, 0.76, 0.74))
	_laje(B.grow(-0.05), ANDAR + PE, LAJE, [buraco_b], CONCRETO, true)
	var yt := ANDAR * 2.0
	_escada(Vector2(-1.9, -16.0), Vector2(0, -1), 1.4, 0.0, ANDAR, 8.0, CONCRETO, 1)
	_escada(Vector2(1.9, -24.0), Vector2(0, 1), 1.4, ANDAR, ANDAR, 8.0, CONCRETO, -1)
	_grade(Vector2(-1.15, -24.0), Vector2(-1.15, -16.0), ANDAR)
	_grade(Vector2(-2.65, -16.0), Vector2(-1.15, -16.0), ANDAR)
	_grade(Vector2(1.15, -24.0), Vector2(1.15, -16.0), yt)
	_grade(Vector2(1.15, -24.0), Vector2(2.65, -24.0), yt)
	_mureta(B.grow(ESP * 0.5), yt, 1.1, [])
	# casinha da escada no telhado (porta virada para a frente)
	var casa := Rect2(-0.6, -25.6, 3.9, 10.2)
	_perimetro(casa, yt, 2.8, CONCRETO, CONCRETO, [[[0.4, 3.5, 0.0, 2.5]], [], [], []], fora)
	fora.caixa(Vector3(casa.get_center().x, yt + 2.95, casa.get_center().y), Vector3(casa.size.x + 0.5, 0.3, casa.size.y + 0.5), CONCRETO_ESC)
	_col(Vector3(casa.get_center().x, yt + 2.95, casa.get_center().y), Vector3(casa.size.x + 0.5, 0.3, casa.size.y + 0.5))
	# heliponto, caixas militares e ninho de sacos de areia virado para a praça
	fora.cilindro(Vector3(14, yt + 0.03, -14), 6.0, 0.06, 28, Color(0.25, 0.27, 0.28))
	fora.cilindro(Vector3(14, yt + 0.05, -14), 5.3, 0.06, 28, AMARELO)
	fora.cilindro(Vector3(14, yt + 0.07, -14), 5.0, 0.06, 28, Color(0.25, 0.27, 0.28))
	for pc in [[Vector3(12.6, 0, -14), Vector3(0.6, 0.02, 4.4)], [Vector3(15.4, 0, -14), Vector3(0.6, 0.02, 4.4)], [Vector3(14, 0, -14), Vector3(2.4, 0.02, 0.6)]]:
		fora.caixa((pc[0] as Vector3) + Vector3(0, yt + 0.1, 0), pc[1], BRANCO)
	for p in [Vector2(22.5, -22.5), Vector2(7.0, -23.0), Vector2(24.0, -6.0)]:
		_caixa_militar(Vector3(p.x, yt, p.y), r.randf_range(-0.4, 0.4), "militar")
	_sacos(Vector2(-5.0, -3.4), Vector2(5.0, -3.4), 3, yt)
	_sacos(Vector2(-5.0, -3.4), Vector2(-5.0, -6.0), 3, yt)
	_sacos(Vector2(26.0, -3.4), Vector2(29.0, -6.4), 3, yt)
	for p in [Vector2(-20, -18), Vector2(-12, -8), Vector2(26, -18)]:
		_bx(fora, Vector3(p.x, yt + 0.7, p.y), Vector3(2.2, 1.4, 1.6), Color(0.6, 0.62, 0.62))
	fora.cilindro(Vector3(-25, yt + 2.5, -22), 0.06, 5.0, 5, METAL_ESC)                                 # antena
	_ponto(Vector3(10, yt, -6), "telhado")
	_ponto(Vector3(-15, yt, -15), "telhado")
	# ---- TÉRREO: paredes de dentro ----
	_parede(paredes, Vector2(xi, -12), Vector2(xf, -12), 0.0, PE, DIV, Color.WHITE, cor_d, [_porta(15.85, 2.0), [25.85, 33.85, 0.0, 99.0], _porta(43.85, 2.4)])
	_parede(paredes, Vector2(xi, -15), Vector2(xf, -15), 0.0, PE, DIV, Color.WHITE, cor_d,
		[_porta(4.85), _porta(14.1), _porta(22.6), [26.85, 32.85, 0.0, 99.0], _porta(37.35), _porta(46.35), _porta(55.25)])
	_parede(paredes, Vector2(-8, -12), Vector2(-8, -2.15), 0.0, PE, DIV, Color.WHITE, verde_h, [[3.0, 6.2, 1.05, 2.3], _porta(8.2)])
	_parede(paredes, Vector2(8, -12), Vector2(8, -2.15), 0.0, PE, DIV, Color.WHITE, verde_h, [_porta(2.8)])
	for x in [-20.0, -11.5, -3.0, 3.0, 12.0, 21.0]:
		_parede(paredes, Vector2(x, -25.85), Vector2(x, -15), 0.0, PE, DIV, Color.WHITE, cor_d, [])
	# recepção
	_movel("balcao", Vector3(-1.25, 0, -9.0), 0.0, "balcao", "RECEPÇÃO")
	_movel("balcao", Vector3(1.25, 0, -9.0), 0.0, "hospital_enfermaria", "RECEPÇÃO")
	for z in [-5.0, -6.6]:
		_movel("cadeiras_espera", Vector3(-5.0, 0, z), 0.0)
		_movel("cadeiras_espera", Vector3(5.0, 0, z), 0.0)
	for p in [Vector2(-7.3, -11.4), Vector2(7.3, -11.4), Vector2(-7.3, -2.8)]:
		_movel("planta", Vector3(p.x, 0, p.y), 0.0)
	_pontos_em(Rect2(-7, -11.5, 14, 9), 0.0, 3, "recepcao")
	# farmácia
	for k in 5:
		_movel("armario_remedios", Vector3(-28.5 + k * 1.15, 0, -11.6), 0.0, "hospital_farmacia", "ARMÁRIO DA FARMÁCIA")
	for z in [-9.0, -6.0]:
		_movel("armario_remedios", Vector3(-29.6, 0, z), PI * 0.5, "hospital_farmacia", "ARMÁRIO DA FARMÁCIA")
	for x in [-24.0, -19.0, -14.0]:
		_movel("gondola", Vector3(x, 0, -7.0), PI * 0.5, "hospital_farmacia", "GÔNDOLA DA FARMÁCIA")
	_movel("balcao", Vector3(-8.5, 0, -7.4), PI * 0.5, "hospital_farmacia", "BALCÃO DA FARMÁCIA")
	_pontos_em(Rect2(-29, -11, 20, 8), 0.0, 3, "farmacia")
	# emergência: macas com cortinas, carrinhos e armários
	for k in 6:
		var x := 10.5 + k * 3.5
		_movel("maca", Vector3(x, 0, -10.8), 0.0)
		if k < 5:
			resto.caixa(Vector3(x + 1.75, 1.2, -10.3), Vector3(0.03, 1.9, 2.6), Color(0.55, 0.7, 0.75))
			resto.caixa(Vector3(x + 1.75, 2.2, -10.3), Vector3(0.05, 0.05, 2.6), METAL)
		if k % 2 == 0:
			_bx(resto, Vector3(x + 0.9, 0.5, -8.6), Vector3(0.6, 1.0, 0.45), Color(0.8, 0.82, 0.84))
			_loot(Vector3(x + 0.9, 0.1, -8.0), "hospital_enfermaria", "CARRINHO DE EMERGÊNCIA", Vector2i(4, 3))
	for z in [-4.0, -6.0]:
		_movel("armario_remedios", Vector3(8.3, 0, z), -PI * 0.5 + PI, "hospital_farmacia", "ARMÁRIO DE REMÉDIOS")
	_pontos_em(Rect2(9, -8, 20, 5), 0.0, 4, "emergencia")
	# fundos do térreo: consultório, laboratório, raio-x, depósito, necrotério, refeitório
	_movel("maca", Vector3(-28.5, 0, -24.5), PI * 0.5)
	_movel("mesa_escritorio", Vector3(-24.0, 0, -24.9), 0.0, "escritorio")
	_movel("armario_remedios", Vector3(-21.0, 0, -25.6), 0.0, "hospital_farmacia", "ARMÁRIO DO CONSULTÓRIO")
	_movel("pia", Vector3(-26.5, 0, -25.6), 0.0, "banheiro")
	for x in [-18.6, -16.0, -13.4]:
		_movel("bancada", Vector3(x + 0.2, 0, -25.5), 0.0, "hospital_lab", "BANCADA DO LABORATÓRIO")
	_movel("arquivo", Vector3(-12.0, 0, -18.0), -PI * 0.5, "escritorio")
	_movel("geladeira", Vector3(-19.4, 0, -17.0), PI * 0.5, "hospital_lab", "GELADEIRA DE AMOSTRAS")
	_bx(resto, Vector3(-7.2, 1.0, -21.0), Vector3(2.0, 2.0, 1.2), Color(0.8, 0.8, 0.78))                # raio-x
	resto.caixa(Vector3(-7.2, 2.4, -19.6), Vector3(0.6, 0.5, 0.6), Color(0.7, 0.7, 0.68))
	_movel("maca", Vector3(-7.2, 0, -17.8), PI * 0.5)
	_movel("armario_remedios", Vector3(-4.0, 0, -25.6), 0.0, "hospital_deposito", "ARMÁRIO DO RAIO-X")
	for z in [-25.4, -22.0, -18.6]:
		_movel("prateleira", Vector3(7.5, 0, z), 0.0 if z < -25.0 else PI * 0.5 * 0.0, "hospital_deposito", "PRATELEIRA DO DEPÓSITO")
	_movel("caixas", Vector3(10.6, 0, -17.0), 0.0, "hospital_deposito", "CAIXAS DE SUPRIMENTOS")
	for k in 3:
		for j in 3:
			resto.caixa(Vector3(14.0 + k * 1.0, 0.6 + j * 0.85, -25.5), Vector3(0.95, 0.8, 0.6), Color(0.62, 0.64, 0.66))   # gavetas do necrotério
			resto.caixa(Vector3(14.0 + k * 1.0, 0.6 + j * 0.85, -25.18), Vector3(0.2, 0.05, 0.05), METAL_ESC)
	_col(Vector3(15.0, 1.45, -25.5), Vector3(3.0, 2.6, 0.6))
	for x in [17.5, 19.5]:
		_movel("maca", Vector3(x, 0, -20.0), 0.0)
		resto.caixa(Vector3(x, 0.85, -20.0), Vector3(0.6, 0.3, 1.8), Color(0.12, 0.16, 0.12))            # saco de corpo
	for p in [Vector2(23.5, -21.0), Vector2(27.0, -21.0), Vector2(25.2, -18.0)]:
		_movel("mesa_bar", Vector3(p.x, 0, p.y), 0.0)
	_movel("bancada", Vector3(25.0, 0, -25.5), 0.0, "casa_cozinha", "BALCÃO DO REFEITÓRIO")
	_movel("geladeira", Vector3(29.2, 0, -24.0), -PI * 0.5, "geladeira")
	_pontos_em(Rect2(-29, -14.6, 58, 2.2), 0.0, 4, "corredor")
	_pontos_em(Rect2(4, -24, 7, 5), 0.0, 2, "deposito")
	_bagunca(Rect2(-29.5, -25.5, 59, 23), 0.0, 40)
	# ---- 1º ANDAR ----
	var y1 := ANDAR
	_parede(paredes, Vector2(xi, -12), Vector2(xf, -12), y1, PE, DIV, Color.WHITE, cor_d, [_porta(7.85), _porta(21.85), _porta(35.85), _porta(51.25)])
	_parede(paredes, Vector2(xi, -15), Vector2(xf, -15), y1, PE, DIV, Color.WHITE, cor_d, [_porta(6.85), _porta(20.35), [26.85, 32.85, 0.0, 99.0], _porta(39.85), _porta(53.25)])
	for x in [-15.0, -1.0, 13.0]:
		_parede(paredes, Vector2(x, -12), Vector2(x, -2.15), y1, PE, DIV, Color.WHITE, cor_d, [])
	for x in [-16.0, -3.0, 3.0, 17.0]:
		_parede(paredes, Vector2(x, -25.85), Vector2(x, -15), y1, PE, DIV, Color.WHITE, cor_d, [])
	# enfermarias (camas encostadas na parede da frente, armário e criado-mudo)
	for sala in [[-29.85, -15.0], [-15.0, -1.0], [-1.0, 13.0], [13.0, 29.85]]:
		var a: float = sala[0]
		var b: float = sala[1]
		var x := a + 1.8
		while x < b - 1.5:
			_movel("maca", Vector3(x, y1, -3.4), PI)
			_movel("criado", Vector3(x + 0.95, y1, -2.5), PI, "hospital_enfermaria", "CRIADO-MUDO")
			x += 3.2
		_movel("armario_remedios", Vector3(b - 0.8, y1, -11.6), 0.0, "hospital_enfermaria", "ARMÁRIO DA ENFERMARIA")
		_pontos_em(Rect2(a + 0.5, -10.5, b - a - 1.0, 5.0), y1, 2, "enfermaria")
	# UTI e escritório dos médicos
	for x in [-27.5, -24.0, -20.5]:
		_movel("maca", Vector3(x, y1, -24.6), 0.0)
		_bx(resto, Vector3(x + 1.0, y1 + 0.8, -25.4), Vector3(0.12, 1.6, 0.12), METAL)
		resto.caixa(Vector3(x + 1.0, y1 + 1.6, -25.3), Vector3(0.5, 0.35, 0.1), Moveis.PRETO)            # monitor
	_movel("armario_remedios", Vector3(-17.0, y1, -20.0), -PI * 0.5, "hospital_cirurgia", "ARMÁRIO DA UTI")
	_movel("mesa_escritorio", Vector3(-12.0, y1, -24.9), 0.0, "escritorio")
	_movel("mesa_escritorio", Vector3(-7.5, y1, -24.9), 0.0, "escritorio")
	_movel("arquivo", Vector3(-15.4, y1, -17.0), PI * 0.5, "escritorio")
	_movel("estante_livros", Vector3(-9.5, y1, -15.4), PI)
	# centro cirúrgico: mesa, foco de luz, armários de instrumentos
	for cx in [7.5, 13.0]:
		_bx(resto, Vector3(cx, y1 + 0.45, -20.5), Vector3(0.5, 0.9, 0.5), METAL)
		_bx(resto, Vector3(cx, y1 + 0.95, -20.5), Vector3(0.75, 0.12, 2.1), Color(0.3, 0.45, 0.5))
		resto.cilindro(Vector3(cx, y1 + 3.0, -20.5), 0.45, 0.18, 12, Color(0.88, 0.9, 0.9))
		resto.cilindro(Vector3(cx, y1 + 3.5, -20.5), 0.04, 1.0, 5, METAL)
		_bx(resto, Vector3(cx + 1.3, y1 + 0.45, -19.5), Vector3(0.7, 0.9, 0.45), Color(0.75, 0.78, 0.8))
		_loot(Vector3(cx + 1.3, y1 + 0.1, -18.9), "hospital_cirurgia", "CARRINHO DE INSTRUMENTOS", Vector2i(4, 3))
	for x in [4.5, 9.0, 13.5]:
		_movel("armario_remedios", Vector3(x, y1, -25.6), 0.0, "hospital_cirurgia", "ARMÁRIO DO CENTRO CIRÚRGICO")
	for z in [-24.8, -21.6, -18.4]:
		_movel("prateleira", Vector3(29.4, y1, z), -PI * 0.5, "hospital_deposito", "ESTERILIZAÇÃO")
	_movel("pia", Vector3(18.0, y1, -25.6), 0.0, "banheiro")
	_pontos_em(Rect2(4, -24, 12, 7), y1, 2, "cirurgia")
	_pontos_em(Rect2(-29, -14.6, 58, 2.2), y1, 3, "corredor")
	_bagunca(Rect2(-29.5, -25.5, 59, 23), y1, 30)
	# ---- frente: marquise, cobertura das ambulâncias, placa com a cruz ----
	fora.caixa(Vector3(0, 4.2, 1.0), Vector3(12.0, 0.4, 6.0), Color(0.82, 0.82, 0.8))
	_col(Vector3(0, 4.2, 1.0), Vector3(12.0, 0.4, 6.0))
	for x in [-5.5, 5.5]:
		_bx(fora, Vector3(x, 2.0, 3.6), Vector3(0.4, 4.0, 0.4), Color(0.82, 0.82, 0.8))
	fora.caixa(Vector3(23, 4.8, 2.5), Vector3(12.0, 0.4, 9.0), Color(0.82, 0.82, 0.8))
	_col(Vector3(23, 4.8, 2.5), Vector3(12.0, 0.4, 9.0))
	for x in [17.5, 28.5]:
		_bx(fora, Vector3(x, 2.4, 6.6), Vector3(0.4, 4.8, 0.4), Color(0.82, 0.82, 0.8))
	fora.caixa(Vector3(0, 7.0, -1.75), Vector3(5.0, 3.2, 0.12), BRANCO)
	fora.caixa(Vector3(0, 7.0, -1.68), Vector3(0.9, 2.6, 0.06), VERMELHO)
	fora.caixa(Vector3(0, 7.0, -1.68), Vector3(2.6, 0.9, 0.06), VERMELHO)
	fora.caixa(Vector3(23, 5.4, 6.95), Vector3(8.0, 0.8, 0.1), VERMELHO)                                   # "EMERGÊNCIA"
	# ambulâncias, caminhão do exército e carros
	_ambulancia(Vector2(20.0, 2.6), PI)
	_ambulancia(Vector2(26.0, 3.2), PI - 0.15)
	_caminhao_mil(Vector2(14.0, 17.5), PI * 0.5 + 0.1)
	_carro(Vector2(-30.0, 10.5), 0.0, Color(0.32, 0.36, 0.42))
	_carro(Vector2(-12.0, 23.0), PI, Color(0.6, 0.6, 0.58))
	_carro(Vector2(29.0, 22.5), PI + 0.2, Color(0.5, 0.15, 0.12))
	_carro(Vector2(24.0, 11.0), 0.6, Color(0.2, 0.22, 0.25), "carro", true)
	# posto militar: sacos de areia na entrada, chicane de barreiras, barracas
	_sacos(Vector2(-7.5, 7.5), Vector2(-3.0, 7.5))
	_sacos(Vector2(3.0, 7.5), Vector2(7.5, 7.5))
	_sacos(Vector2(-7.5, 7.5), Vector2(-7.5, 4.8))
	_sacos(Vector2(7.5, 7.5), Vector2(7.5, 4.8))
	for k in 4:
		_barreira(Vector2(-1.5 if k % 2 == 0 else 1.5, 12.0 + k * 3.5), PI * 0.5)
	_tenda(Vector2(-26.0, 12.5), 0.0)
	_tenda(Vector2(-26.0, 21.5), 0.0)
	for k in 4:
		resto.caixa(Vector3(-19.5 + k * 0.9, 0.18, 17.0 + r.randf_range(-0.4, 0.4)), Vector3(0.55, 0.32, 1.9), Color(0.12, 0.16, 0.12), Basis(Vector3.UP, r.randf_range(-0.2, 0.2)))   # sacos de corpo
	for p in [Vector2(-34, 4), Vector2(34, 4), Vector2(-15, 26), Vector2(15, 26)]:
		_poste(p, 0.0, 7.5)
	_pontos_em(Rect2(-34, 0, 68, 6), 0.0, 3, "praca")
	_pontos_em(Rect2(-30, 8, 60, 18), 0.0, 3, "estacionamento")
	_bagunca(Rect2(-35, -1, 70, 27), 0.0, 20)
	infectados = [Vector3(0, 0, -6), Vector3(18, 0, -7), Vector3(-12, 0, -13.5), Vector3(14, 0, -13.5), Vector3(-20, ANDAR, -7),
		Vector3(9, ANDAR, -21), Vector3(5, 0, 10), Vector3(-21, 0, 15), Vector3(20, 0, 20)]

# caixa militar verde com loot
func _caixa_militar(p: Vector3, g: float, loot: String) -> void:
	var b := Basis(Vector3.UP, g)
	resto.caixa(p + Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 0.8), VERDE_MIL, b)
	resto.caixa(p + Vector3(0, 0.72, 0), Vector3(1.45, 0.06, 0.85), VERDE_MIL * 0.8, b)
	resto.caixa(p + b * Vector3(0, 0.35, 0.405), Vector3(0.9, 0.12, 0.01), Color(0.85, 0.85, 0.75), b)
	col.append([p + Vector3(0, 0.37, 0), Vector3(1.4, 0.74, 0.8), 0.0, b])
	_loot(p + b * Vector3(0, 0.1, 0.9), loot, "CAIXA MILITAR", Vector2i(8, 4))

# barraca militar (lona verde, aberta nas duas pontas, ao longo de Z) com macas e caixas
func _tenda(c: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(c.x, 0, c.y)
	var larg := 5.0
	var comp := 7.0
	var alt := 2.8
	var meia := larg * 0.5
	var inc := atan2(alt - 1.4, meia)
	var lado := sqrt(meia * meia + (alt - 1.4) * (alt - 1.4))
	for s in [-1.0, 1.0]:
		var bb := b * Basis(Vector3.BACK, -s * inc)
		resto.caixa(o + b * Vector3(s * meia * 0.5, 1.4 + (alt - 1.4) * 0.5, 0), Vector3(lado + 0.1, 0.05, comp), VERDE_MIL * 1.1, bb)
		resto.caixa(o + b * Vector3(s * meia, 0.7, 0), Vector3(0.05, 1.4, comp), VERDE_MIL, b)
		col.append([o + b * Vector3(s * meia, 0.7, 0), Vector3(0.1, 1.4, comp), 0.0, b])
	resto.cilindro(o + Vector3(0, alt * 0.5, 0) + b * Vector3(0, 0, comp * 0.5 - 0.1), 0.05, alt, 5, METAL_ESC)
	resto.cilindro(o + Vector3(0, alt * 0.5, 0) + b * Vector3(0, 0, -comp * 0.5 + 0.1), 0.05, alt, 5, METAL_ESC)
	_movel("colchao", o + b * Vector3(-1.6, 0, -1.5), g)
	_movel("colchao", o + b * Vector3(1.6, 0, -1.5), g)
	_caixa_militar(o + b * Vector3(-1.4, 0, 2.2), g + PI * 0.5, "militar_med")
	_caixa_militar(o + b * Vector3(1.4, 0, 2.0), g - PI * 0.5, "militar_med")
	_ponto(o + b * Vector3(0, 0, 0), "barraca")

func _ambulancia(c: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(c.x, 0, c.y)
	resto.caixa(o + b * Vector3(0, 1.55, -0.8), Vector3(2.3, 2.3, 4.0), Color(0.92, 0.92, 0.9), b)          # baú
	resto.caixa(o + b * Vector3(0, 1.3, -0.8), Vector3(2.32, 0.3, 4.02), VERMELHO, b)
	resto.caixa(o + b * Vector3(0, 1.1, 2.1), Vector3(2.1, 1.5, 1.9), Color(0.92, 0.92, 0.9), b)            # cabine
	resto.caixa(o + b * Vector3(0, 1.45, 2.6), Vector3(2.0, 0.6, 1.0), Color(0.12, 0.14, 0.16), b)
	resto.caixa(o + b * Vector3(0, 2.8, 1.2), Vector3(1.2, 0.18, 0.3), Color(0.2, 0.3, 0.8), b)             # giroflex
	for x in [-1.0, 1.0]:
		for z in [-2.0, 2.0]:
			resto.cilindro(o + b * Vector3(x, 0.4, z), 0.4, 0.25, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	col.append([o + Vector3(0, 1.4, 0) + b * Vector3(0, 0, 0.1), Vector3(2.3, 2.8, 6.0), 0.0, b])
	_loot(o + b * Vector3(0, 0.1, -3.4), "ambulancia", "AMBULÂNCIA", Vector2i(6, 5))

func _caminhao_mil(c: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(c.x, 0, c.y)
	resto.caixa(o + b * Vector3(0, 1.0, 0), Vector3(2.4, 0.5, 7.5), VERDE_MIL * 0.8, b)                    # chassi
	resto.caixa(o + b * Vector3(0, 1.65, 2.8), Vector3(2.3, 1.6, 1.9), VERDE_MIL, b)                       # cabine
	resto.caixa(o + b * Vector3(0, 1.95, 3.3), Vector3(2.2, 0.6, 0.9), Color(0.1, 0.12, 0.1), b)
	resto.caixa(o + b * Vector3(0, 2.3, -1.0), Vector3(2.4, 2.1, 5.0), Color(0.33, 0.36, 0.25), b)          # lona
	for z in [-2.8, -1.4, 2.8]:
		for x in [-1.1, 1.1]:
			resto.cilindro(o + b * Vector3(x, 0.5, z), 0.5, 0.35, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	col.append([o + Vector3(0, 1.7, 0), Vector3(2.4, 3.4, 7.5), 0.0, b])
	_loot(o + b * Vector3(0, 0.1, -4.3), "militar", "CAMINHÃO DO EXÉRCITO", Vector2i(8, 5))

# ======================================================================================================
# SUPERMERCADO (66 x 56): salão de 56 x 25 com fachada de vidro (entrada e saída), 6 CAIXAS, 8 corredores de
# gôndolas (mercearia, bebidas, utilidades, higiene), hortifrúti, açougue com balcões, freezers, paredão de
# geladeiras, ESTOQUE com porta-paletes, escritório do gerente com COFRE, 2 portas de carga nos fundos com
# carreta, escada de ferro para o TELHADO e estacionamento com carros e carrinhos.
# ======================================================================================================
func _supermercado() -> void:
	var B := Rect2(-28, -22, 56, 25)
	var H := 6.5
	var cor_f := Color(0.8, 0.78, 0.72)
	var cor_d := Color(0.9, 0.9, 0.86)
	var cor_marca := Color(0.12, 0.45, 0.22)
	dentro = B.grow(-ESP * 0.5)
	# ---- chão de fora ----
	_chao(Rect2(-33, 3, 66, 25), ASFALTO)
	_chao(Rect2(-33, -28, 66, 6), CONCRETO_ESC)
	_chao(Rect2(-33, 3, 66, 2.5), CONCRETO * 1.05)
	for z0 in [7.0, 17.5]:
		_vagas(-30.0, -4.0, z0, 5.0)
		_vagas(4.0, 30.0, z0, 5.0)
	# ---- paredes ----
	var frente: Array = [[10.5, 13.5, 0.0, 3.0], [42.5, 45.5, 0.0, 3.0]]
	var s := 1.0
	while s < 55.0:
		var s1 := minf(s + 2.8, 55.0)
		if not (s1 > 10.3 and s < 13.7) and not (s1 > 42.3 and s < 45.7):
			frente.append([s, s1, 0.4, 3.6, "janela"])
		s += 3.0
	var direita := [_porta(10.0)]
	var fundo := [[25.0, 30.0, 0.0, 4.2], [35.0, 40.0, 0.0, 4.2], _porta(52.0)]
	var esquerda := [_porta(17.0)]
	_perimetro(B, 0.0, H, cor_f, cor_d, [frente, direita, fundo, esquerda])
	piso.caixa(Vector3(0, 0.02, -6.575), Vector3(55.7, 0.04, 18.85), Color(0.84, 0.84, 0.8), Basis.IDENTITY, true)
	concreto.caixa(Vector3(0, 0.02, -18.925), Vector3(55.7, 0.04, 5.85), CONCRETO * 0.9, Basis.IDENTITY, true)
	_laje(B.grow(ESP * 0.5), H, 0.5, [], CONCRETO, true)
	var yt := H + 0.5
	_mureta(B.grow(ESP * 0.5), yt, 1.0, [[Vector2(28.15, -10.6), Vector2(28.15, -8.6)]])
	# letreiro na fachada, acima do vidro
	_placa(Vector3(0, 5.0, 3.25), Vector3(30.0, 2.2, 0.3), cor_marca, Color(0.95, 0.85, 0.2))
	for k in 12:
		fora.caixa(Vector3(-11.0 + k * 2.0, 5.25, 3.42), Vector3(1.3, 1.0, 0.05), Color(0.95, 0.95, 0.92))
	# portas de enrolar dos fundos (uma aberta, uma meio aberta)
	resto.caixa(Vector3(-9.5, 3.9, -22.05), Vector3(5.0, 0.7, 0.08), METAL)
	resto.caixa(Vector3(0.5, 3.0, -22.05), Vector3(5.0, 2.4, 0.08), METAL)
	_col(Vector3(0.5, 3.0, -22.05), Vector3(5.0, 2.4, 0.1))
	# escada de ferro para o telhado (lado direito, de fora)
	_escada(Vector2(28.95, 2.0), Vector2(0, -1), 1.3, 0.0, yt, 11.4, METAL, 1)
	resto.caixa(Vector3(28.95, yt - 0.06, -10.2), Vector3(1.3, 0.12, 1.8), METAL)
	_col(Vector3(28.95, yt - 0.1, -10.2), Vector3(1.3, 0.2, 1.8))
	_grade(Vector2(29.6, -9.3), Vector2(29.6, -11.1), yt)
	_grade(Vector2(28.3, -11.1), Vector2(29.6, -11.1), yt)
	# telhado: ar-condicionado grande, claraboias, caixa d'água
	for p in [Vector2(-18, -10), Vector2(-4, -14), Vector2(12, -6), Vector2(20, -16)]:
		_bx(fora, Vector3(p.x, yt + 0.8, p.y), Vector3(3.0, 1.6, 2.0), Color(0.62, 0.63, 0.62))
	for p in [Vector2(-12, -4), Vector2(0, -4), Vector2(-24, -16), Vector2(6, -18)]:
		_bx(fora, Vector3(p.x, yt + 0.35, p.y), Vector3(2.4, 0.7, 2.4), VIDRO)
	_ponto(Vector3(0, yt, -10), "telhado")
	_ponto(Vector3(-20, yt, -3), "telhado")
	# ---- dentro: parede do estoque (z = -16), com 2 portas vai-e-vem ----
	_parede(paredes, Vector2(-27.85, -16), Vector2(27.85, -16), 0.0, H, DIV, Color.WHITE, cor_d, [_porta(17.85, 2.4), _porta(37.85, 2.4)])
	_parede(paredes, Vector2(14, -21.85), Vector2(14, -16), 0.0, H, DIV, Color.WHITE, Color(0.75, 0.72, 0.62), [_porta(2.9)])
	# paredão de geladeiras (de costas para o estoque)
	_geladeiras(Vector2(-27.7, -15.55), Vector2(1, 0), Vector2(0, 1), 12, "super_bebidas")
	_geladeiras(Vector2(-8.6, -15.55), Vector2(1, 0), Vector2(0, 1), 13, "super_bebidas")
	# corredores de gôndolas
	var cats := ["super_mercearia", "super_mercearia", "super_bebidas", "super_utilidades", "super_higiene", "super_mercearia", "super_mercearia", "super_utilidades"]
	var nomes := ["MERCEARIA", "MERCEARIA", "BEBIDAS", "UTILIDADES", "HIGIENE E FARMÁCIA", "MERCEARIA", "ENLATADOS", "UTILIDADES"]
	for k in 8:
		var x := -24.5 + k * 4.5
		for z in [-12.0, -9.6, -7.2]:
			_movel("gondola", Vector3(x, 0, z), PI * 0.5, cats[k], "GÔNDOLA · " + nomes[k])
		fora.caixa(Vector3(x, 4.2, -9.6), Vector3(0.05, 0.6, 2.0), cor_marca)                               # placa do corredor
		fora.cilindro(Vector3(x, 5.35, -9.6), 0.015, 1.7, 4, METAL_ESC)
	# hortifrúti
	for i in 2:
		for j in 3:
			var p := Vector2(14.0 + i * 5.0, -12.5 + j * 3.2)
			_bx(resto, Vector3(p.x, 0.4, p.y), Vector3(2.6, 0.8, 1.3), MADEIRA_CLARA)
			for k in 6:
				resto.caixa(Vector3(p.x - 1.0 + (k % 3) * 1.0, 0.86, p.y - 0.3 + (k / 3) * 0.6), Vector3(0.85, 0.14, 0.5), [Color(0.7, 0.15, 0.1), Color(0.85, 0.6, 0.15), Color(0.3, 0.55, 0.2)][r.randi() % 3])
			_loot(Vector3(p.x, 0.1, p.y + 1.1), "super_hortifruti", "BANCA DE HORTIFRÚTI", Vector2i(4, 3))
	# açougue (balcões refrigerados) e freezers na parede da direita
	for k in 4:
		_bx(resto, Vector3(15.5 + k * 2.6, 0.55, -14.4), Vector3(2.5, 1.1, 1.0), Color(0.82, 0.84, 0.85))
		resto.caixa(Vector3(15.5 + k * 2.6, 1.25, -14.2), Vector3(2.4, 0.4, 0.6), VIDRO * 1.3, Basis(Vector3.RIGHT, 0.5))
		_loot(Vector3(15.5 + k * 2.6, 0.1, -13.4), "geladeira", "BALCÃO DO AÇOUGUE", Vector2i(5, 3))
	for z in [-11.5, -9.0, -6.5]:
		_movel("freezer", Vector3(27.35, 0, z), -PI * 0.5, "super_congelados", "FREEZER")
	# caixas (6) e balcão de atendimento
	for k in 6:
		var x := -13.0 + k * 4.0
		_bx(resto, Vector3(x, 0.45, -1.5), Vector3(0.9, 0.9, 2.8), Color(0.3, 0.3, 0.32))
		resto.caixa(Vector3(x, 0.92, -1.5), Vector3(0.7, 0.04, 2.6), Moveis.PRETO)                            # esteira
		resto.caixa(Vector3(x + 0.25, 1.15, -0.4), Vector3(0.45, 0.3, 0.4), Moveis.PRETO)                    # registradora
		resto.cilindro(Vector3(x - 0.3, 1.5, -0.2), 0.03, 1.2, 4, METAL)
		resto.caixa(Vector3(x - 0.3, 2.1, -0.2), Vector3(0.25, 0.25, 0.05), Color(0.9, 0.85, 0.2))           # número do caixa
		_bx(resto, Vector3(x + 1.2, 0.6, -0.4), Vector3(0.4, 1.2, 0.8), Color(0.65, 0.15, 0.12))             # doces
		_loot(Vector3(x + 0.9, 0.1, -1.0), "balcao", "CAIXA %d" % (k + 1), Vector2i(4, 2))
	_movel("balcao", Vector3(21.5, 0, -1.0), PI, "balcao", "ATENDIMENTO")
	_movel("balcao", Vector3(24.0, 0, -1.0), PI, "super_utilidades", "ATENDIMENTO")
	# carrinhos perto da entrada
	for k in 5:
		_carrinho(Vector2(-22.0 + k * 0.35, 0.8), PI * 0.5)
	_pontos_em(Rect2(-27, -14.5, 36, 9), 0.0, 8, "corredores")
	_pontos_em(Rect2(-20, -4.5, 40, 3), 0.0, 3, "caixas")
	_pontos_em(Rect2(12, -13, 14, 9), 0.0, 2, "hortifruti")
	_bagunca(Rect2(-27.5, -15.5, 55, 18), 0.0, 40)
	# ---- estoque e escritório ----
	var x := -26.4
	var n := 0
	while x < 12.0:
		if not (x > -12.8 and x < -7.2) and not (x > 7.5 and x < 12.5):
			_porta_palete(Vector2(x, -21.25), 0.0, "super_estoque" if n % 2 == 0 else "")
			n += 1
		x += 2.8
	for p in [Vector2(-18.0, -17.6), Vector2(-3.0, -18.0), Vector2(4.5, -17.8)]:
		_palete(Vector2(p.x, p.y), r.randf_range(-0.3, 0.3), 3)
	_carrinho_palete(Vector2(-6.0, -17.4), 0.4)
	_movel("mesa_escritorio", Vector3(21.0, 0, -21.0), 0.0, "escritorio")
	_movel("arquivo", Vector3(27.2, 0, -19.0), -PI * 0.5, "escritorio")
	_movel("arquivo", Vector3(27.2, 0, -18.2), -PI * 0.5, "escritorio")
	_bx(resto, Vector3(15.0, 0.55, -21.3), Vector3(0.9, 1.1, 0.9), Color(0.2, 0.22, 0.2))                    # cofre
	resto.cilindro(Vector3(15.0, 0.65, -20.84), 0.12, 0.04, 10, METAL, Basis(Vector3.RIGHT, PI * 0.5))
	_loot(Vector3(15.0, 0.1, -20.3), "cofre", "COFRE", Vector2i(4, 3))
	_pontos_em(Rect2(-27, -20, 40, 3), 0.0, 3, "estoque")
	_bagunca(Rect2(-27.5, -21.5, 55, 5.3), 0.0, 15)
	# ---- fundos: carreta encostada na porta de carga, caçamba e paletes ----
	_carreta(Vector2(-9.5, -25.4), PI * 0.5)
	_cacamba(Vector2(-22.0, -24.8), 0.0)
	_palete(Vector2(10.0, -25.0), 0.2, 2)
	_palete(Vector2(14.0, -25.3), -0.1, 1)
	# ---- estacionamento: carros, carrinhos largados, baias e postes ----
	_carro(Vector2(-25.5, 9.5), 0.0, Color(0.32, 0.36, 0.42))
	_carro(Vector2(-14.6, 20.0), PI, Color(0.6, 0.58, 0.55))
	_carro(Vector2(8.5, 9.6), 0.08, Color(0.5, 0.12, 0.1))
	_carro(Vector2(22.0, 20.0), PI + 0.1, Color(0.2, 0.3, 0.25))
	_carro(Vector2(0.0, 14.0), 1.2, Color(0.75, 0.73, 0.65), "carro", true)
	_carro(Vector2(-17.0, 5.5), PI * 0.5 + 0.2, Color(0.25, 0.25, 0.3))                                    # bloqueando a entrada
	for k in 9:
		_carrinho(Vector2(r.randf_range(-28, 28), r.randf_range(5, 25)), r.randf() * TAU, r.randf() < 0.3)
	for p in [Vector2(-10.0, 13.5), Vector2(14.0, 13.5)]:
		for k in 2:
			resto.caixa(Vector3(p.x, 0.5, p.y + (k * 2 - 1) * 0.6), Vector3(5.0, 0.05, 0.05), METAL)            # baia de carrinhos
		_col(Vector3(p.x, 0.5, p.y), Vector3(5.0, 1.0, 1.3))
	for p in [Vector2(-31, 13.5), Vector2(31, 13.5), Vector2(-2, 26), Vector2(-31, 26), Vector2(31, 26)]:
		_poste(p, 0.0, 8.0)
	_pontos_em(Rect2(-30, 5, 60, 20), 0.0, 4, "estacionamento")
	_bagunca(Rect2(-32, 4, 64, 22), 0.0, 25)
	infectados = [Vector3(-20, 0, -8), Vector3(-2, 0, -10), Vector3(10, 0, -3), Vector3(18, 0, -10), Vector3(-5, 0, -19),
		Vector3(0, 0, 10), Vector3(20, 0, 15)]

const MADEIRA_CLARA := Color(0.6, 0.45, 0.28)

func _carrinho(p: Vector2, g: float, tombado := false) -> void:
	var b := Basis(Vector3.UP, g)
	if tombado:
		b = b * Basis(Vector3.BACK, PI * 0.5)
	var o := Vector3(p.x, 0.45 if tombado else 0.0, p.y)
	var off := Vector3(0, 0.45, 0) if tombado else Vector3.ZERO
	resto.caixa(o + b * (Vector3(0, 0.75, 0) - off), Vector3(0.55, 0.45, 0.9), Color(0.6, 0.62, 0.64), b)
	resto.caixa(o + b * (Vector3(0, 0.3, 0) - off), Vector3(0.5, 0.05, 0.85), METAL_ESC, b)
	resto.caixa(o + b * (Vector3(0, 1.05, -0.5) - off), Vector3(0.55, 0.04, 0.04), Color(0.7, 0.15, 0.1), b)

# porta-paletes (estante alta de 2,7 m) com paletes e caixas em 3 níveis, de costas em "p", frente para +Z girada
func _porta_palete(p: Vector2, g: float, loot: String, alto := 5.4, prof := 1.1) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, 0, p.y)
	var cor := Color(0.2, 0.32, 0.62)
	var laranja := Color(0.85, 0.42, 0.1)
	for x in [-1.32, 1.32]:
		for z in [-prof * 0.5, prof * 0.5]:
			resto.caixa(o + b * Vector3(x, alto * 0.5, z), Vector3(0.08, alto, 0.08), cor, b)
	for y in [0.15, alto * 0.37, alto * 0.72]:
		for z in [-prof * 0.5, prof * 0.5]:
			resto.caixa(o + b * Vector3(0, y + 0.06, z), Vector3(2.7, 0.12, 0.07), laranja, b)
		resto.caixa(o + b * Vector3(0, y + 0.13, 0), Vector3(2.5, 0.12, prof - 0.1), MADEIRA_CLARA * 0.85, b)    # palete
		if r.randf() < 0.75:
			var hh := r.randf_range(0.5, 1.3)
			resto.caixa(o + b * Vector3(r.randf_range(-0.3, 0.3), y + 0.19 + hh * 0.5, 0), Vector3(r.randf_range(1.2, 2.3), hh, prof - 0.2), Color(0.55, 0.42, 0.28) * r.randf_range(0.8, 1.15), b)
	col.append([o + Vector3(0, alto * 0.5, 0), Vector3(2.7, alto, prof), 0.0, b])
	if loot != "":
		_loot(o + b * Vector3(0, 0.1, prof * 0.5 + 0.55), loot, "PORTA-PALETES", Vector2i(8, 4))

# palete no chão com caixas empilhadas (cobertura baixa)
func _palete(p: Vector2, g: float, camadas: int) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, 0, p.y)
	resto.caixa(o + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), MADEIRA_CLARA * 0.85, b)
	for k in camadas:
		resto.caixa(o + Vector3(0, 0.14 + 0.3 + k * 0.6, 0), Vector3(1.15, 0.58, 0.95), Color(0.55, 0.42, 0.28) * r.randf_range(0.85, 1.1), b * Basis(Vector3.UP, r.randf_range(-0.05, 0.05)))
	col.append([o + Vector3(0, (0.14 + camadas * 0.6) * 0.5, 0), Vector3(1.2, 0.14 + camadas * 0.6, 1.0), 0.0, b])

func _carrinho_palete(p: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, 0, p.y)
	resto.caixa(o + b * Vector3(-0.2, 0.08, 0), Vector3(0.18, 0.08, 1.2), Color(0.8, 0.6, 0.1), b)
	resto.caixa(o + b * Vector3(0.2, 0.08, 0), Vector3(0.18, 0.08, 1.2), Color(0.8, 0.6, 0.1), b)
	resto.caixa(o + b * Vector3(0, 0.6, -0.7), Vector3(0.06, 1.1, 0.06), METAL_ESC, b * Basis(Vector3.RIGHT, -0.3))

# carreta (baú de caminhão) ao longo de Z local girado, com loot
func _carreta(p: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, 0, p.y)
	resto.caixa(o + Vector3(0, 2.4, 0), Vector3(2.55, 2.8, 12.0), Color(0.85, 0.85, 0.83), b)
	resto.caixa(o + Vector3(0, 0.9, 0), Vector3(2.4, 0.3, 12.0), METAL_ESC, b)
	resto.caixa(o + Vector3(0, 2.4, 0) + b * Vector3(0, 0, 0), Vector3(2.57, 0.4, 12.02), Color(0.6, 0.12, 0.1), b)
	for z in [-4.5, -3.3]:
		for x in [-1.05, 1.05]:
			resto.cilindro(o + b * Vector3(x, 0.5, z), 0.5, 0.3, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	col.append([o + Vector3(0, 2.05, 0), Vector3(2.55, 3.5, 12.0), 0.0, b])
	_loot(o + b * Vector3(1.8, 0.1, 0), "armazem_carga", "CARRETA", Vector2i(8, 6))

# ======================================================================================================
# ARMAZÉM / CENTRO DE DISTRIBUIÇÃO (66 x 50): galpão de 52 x 26 e 9 m de altura (telhas com nervuras), 3 portas de
# doca (aberta, meia e fechada), 3 fileiras de PORTA-PALETES altos (corredores para tiroteio), empilhadeira,
# paletes, ESCRITÓRIO de 2 andares com janelões vigiando o galpão (escada por fora do escritório), pátio com
# CONTÊINERES empilhados e escadas até em cima (torre de vigia), carreta na doca, cerca com guarita no portão.
# ======================================================================================================
func _armazem() -> void:
	var B := Rect2(-28, -23, 52, 26)
	var H := 9.0
	var cor_f := Color(0.6, 0.65, 0.68)
	var cor_d := Color(0.7, 0.72, 0.72)
	dentro = B.grow(-ESP * 0.5)
	# ---- chão de fora ----
	_chao(Rect2(-33, 3, 66, 22), ASFALTO)
	_chao(Rect2(24, -25, 9, 28), ASFALTO * 1.1)
	_chao(Rect2(-33, -25, 5, 28), CONCRETO_ESC)
	_chao(Rect2(-28, -25, 52, 2), CONCRETO_ESC)
	for x in [-24.0, -14.0, -4.0]:
		_faixa(Vector2(x - 2.4, 3.2), Vector2(x - 2.4, 15.0), 0.15, AMARELO)
		_faixa(Vector2(x + 2.4, 3.2), Vector2(x + 2.4, 15.0), 0.15, AMARELO)
	# ---- paredes (3 portas de doca na frente) ----
	var frente := [[4.0, 8.5, 0.0, 5.0], [14.0, 18.5, 0.0, 5.0], _porta(43.9)]
	var direita := [_porta(18.9), [3.0, 5.0, 5.8, 6.8, "janela"], [9.0, 11.0, 5.8, 6.8, "janela"]]
	var fundo := [_porta(34.0), [8.0, 10.0, 6.0, 7.0, "janela"], [22.0, 24.0, 6.0, 7.0, "janela"], [40.0, 42.0, 6.0, 7.0, "janela"]]
	var esquerda := [[8.0, 12.5, 0.0, 5.0], [18.0, 20.0, 6.0, 7.0, "janela"]]
	_perimetro(B, 0.0, H, cor_f, cor_d, [frente, direita, fundo, esquerda])
	# nervuras das telhas (por fora)
	for k in 4:
		var cs: Array = [[Vector2(-28, 3.18), Vector2(1, 0), 52.0], [Vector2(24.18, 3), Vector2(0, -1), 26.0], [Vector2(24, -23.18), Vector2(-1, 0), 52.0], [Vector2(-28.18, -23), Vector2(0, 1), 26.0]][k]
		var t := 0.6
		while t < float(cs[2]):
			var q: Vector2 = cs[0] + cs[1] * t
			fora.caixa(Vector3(q.x, H * 0.5, q.y), Vector3(0.06, H, 0.06), cor_f * 0.85)
			t += 1.2
	# portas de doca: meia (painel no alto) e fechada (painel inteiro)
	resto.caixa(Vector3(-11.75, 4.0, 3.05), Vector3(4.5, 2.0, 0.08), METAL)
	_col(Vector3(-11.75, 4.0, 3.05), Vector3(4.5, 2.0, 0.1))
	for k in 6:
		fora.caixa(Vector3(-1.75, 0.4 + k * 0.8, 3.22), Vector3(4.5, 0.04, 0.05), METAL_ESC)
	fora.caixa(Vector3(-1.75, 2.5, 3.18), Vector3(4.5, 5.0, 0.04), METAL)
	for x in [-19.75, -11.75, -1.75]:
		_bx(fora, Vector3(x, 0.6, 3.6), Vector3(4.6, 1.2, 0.6), Color(0.15, 0.15, 0.16))                 # para-choque da doca
	concreto.caixa(Vector3(-2, 0.02, -10), Vector3(51.7, 0.04, 25.7), CONCRETO * 0.9, Basis.IDENTITY, true)
	_laje(B.grow(ESP * 0.5), H, 0.4, [], Color(0.5, 0.52, 0.55), true, Color(0.45, 0.46, 0.48))
	for k in 6:
		teto.caixa(Vector3(-2, H - 0.3, -20.0 + k * 4.2), Vector3(51.7, 0.4, 0.25), Color(0.4, 0.4, 0.42))        # vigas
	# ---- porta-paletes em 3 fileiras (costas com costas), corredor cruzando no meio ----
	var n := 0
	for zr in [-19.6, -14.0, -8.4]:
		var x := -25.6
		while x < 9.0:
			if not (x > -10.0 and x < -5.2):
				_porta_palete(Vector2(x, zr - 0.56), PI, "armazem_carga" if n % 3 == 0 else "", 6.0)
				_porta_palete(Vector2(x, zr + 0.56), 0.0, "armazem_carga" if n % 3 == 1 else "", 6.0)
				n += 1
			x += 2.75
	_pontos_em(Rect2(-27, -22.5, 36, 2), 0.0, 2, "corredor")
	_pontos_em(Rect2(-27, -17.6, 36, 2), 0.0, 2, "corredor")
	_pontos_em(Rect2(-27, -12.0, 36, 2), 0.0, 2, "corredor")
	# área de carga: empilhadeira, paletes, enroladeira de filme
	_empilhadeira(Vector2(-14.0, -2.0), 0.6)
	for p in [Vector2(-22.0, -3.5), Vector2(-20.6, -3.5), Vector2(-6.0, 0.5), Vector2(4.0, -2.5), Vector2(5.4, -2.5), Vector2(9.0, 0.0)]:
		_palete(p, r.randf_range(-0.2, 0.2), r.randi_range(1, 3))
	_bx(resto, Vector3(8.0, 1.0, -4.5), Vector3(1.6, 2.0, 1.6), Color(0.3, 0.3, 0.32))
	for k in 3:
		_caixa_militar(Vector3(-25.5 + k * 1.6, 0, 1.5), 0.0, "armazem_carga" if k != 1 else "armazem_conteiner")
	_pontos_em(Rect2(-27, -4, 36, 6), 0.0, 4, "doca")
	_bagunca(Rect2(-27.5, -22.5, 51, 25), 0.0, 30)
	# ---- escritório de 2 andares (x 12..23.85, z -22.85..-12) ----
	var ex := 12.0
	var ez := -12.0
	var yo := 3.6
	_parede(paredes, Vector2(ex, -22.85), Vector2(ex, ez), 0.0, yo, DIV, Color.WHITE, Color(0.78, 0.76, 0.7), [_porta(5.8), [1.5, 4.0, 1.0, 2.3, "janela"]])
	_parede(paredes, Vector2(ex, ez), Vector2(23.85, ez), 0.0, yo, DIV, Color.WHITE, Color(0.78, 0.76, 0.7), [[3.0, 6.0, 1.0, 2.3, "janela"]])
	_laje(Rect2(ex, -22.85, 11.85, 10.85), yo, 0.3, [], Color(0.5, 0.42, 0.32))
	var y2 := yo + 0.3
	_parede(paredes, Vector2(ex, -22.85), Vector2(ex, ez), y2, 3.0, DIV, Color.WHITE, Color(0.78, 0.76, 0.7), [[1.0, 4.5, 0.9, 2.4, "janela"], [5.5, 9.5, 0.9, 2.4, "janela"]])
	_parede(paredes, Vector2(ex, ez), Vector2(23.85, ez), y2, 3.0, DIV, Color.WHITE, Color(0.78, 0.76, 0.7), [[0.4, 2.0, 0.0, PORTA_A], [3.0, 6.5, 0.9, 2.4, "janela"]])
	_laje(Rect2(ex, -22.85, 11.85, 10.85), y2 + 3.0, 0.3, [], CONCRETO * 0.8, true)
	# escada encostada na frente do escritório (lado do galpão), sobe de x 22.8 até 15.3
	_escada(Vector2(22.8, -11.3), Vector2(-1, 0), 1.3, 0.0, y2, 7.5, METAL, -1)
	resto.caixa(Vector3(13.6, y2 - 0.06, -11.3), Vector3(3.4, 0.12, 1.3), METAL)                            # passarela
	_col(Vector3(13.6, y2 - 0.1, -11.3), Vector3(3.4, 0.2, 1.3))
	_grade(Vector2(11.9, -10.65), Vector2(15.3, -10.65), y2)
	_grade(Vector2(11.9, -10.65), Vector2(11.9, -11.95), y2)
	# escritório de baixo: armários (vestiário), mesa, geladeira
	for k in 4:
		_bx(resto, Vector3(23.5, 1.0, -21.5 + k * 0.62), Vector3(0.5, 2.0, 0.6), Color(0.35, 0.42, 0.5))
	_loot(Vector3(22.8, 0.1, -20.6), "casa_quarto", "ARMÁRIOS DO VESTIÁRIO", Vector2i(5, 5))
	_movel("mesa_escritorio", Vector3(16.0, 0, -22.2), 0.0, "armazem_escritorio")
	_movel("geladeira", Vector3(19.0, 0, -22.4), 0.0, "geladeira")
	_movel("mesa_bar", Vector3(17.5, 0, -15.5), 0.0)
	_pontos_em(Rect2(13, -21, 9, 7), 0.0, 2, "escritorio")
	# escritório de cima: mesas viradas para os janelões, arquivos e o armário do segurança
	_movel("mesa_escritorio", Vector3(14.0, y2, -18.0), -PI * 0.5, "armazem_escritorio")
	_movel("mesa_escritorio", Vector3(19.0, y2, -14.0), PI, "armazem_escritorio")
	_movel("arquivo", Vector3(23.5, y2, -20.0), -PI * 0.5, "armazem_escritorio")
	_movel("arquivo", Vector3(23.5, y2, -19.3), -PI * 0.5, "armazem_escritorio")
	_movel("armario_armas", Vector3(18.0, y2, -22.5), 0.0, "armazem_seguranca", "ARMÁRIO DO SEGURANÇA")
	_pontos_em(Rect2(13, -21.5, 10, 8), y2, 2, "escritorio")
	# ---- pátio: contêineres (torre de vigia com escadas), carreta na doca, cerca e guarita ----
	_conteiner(Vector2(29.6, -18.0), 0.0, Color(0.55, 0.2, 0.12), "")
	_conteiner(Vector2(29.6, -18.0), 0.0, Color(0.15, 0.3, 0.5), "armazem_conteiner", 2.6)
	_conteiner(Vector2(29.6, -11.6), 0.0, Color(0.2, 0.4, 0.25), "armazem_conteiner")
	_conteiner(Vector2(29.6, 6.0), 0.0, Color(0.6, 0.45, 0.12), "armazem_conteiner", 0.0, true)
	_conteiner(Vector2(29.6, 12.4), 0.0, Color(0.5, 0.5, 0.52), "")
	_conteiner(Vector2(29.6, 12.4), 0.0, Color(0.55, 0.2, 0.12), "armazem_conteiner", 2.6)
	_escada(Vector2(24.5, -11.0), Vector2(1, 0), 1.2, 0.0, 2.6, 3.9, METAL, 1)
	_escada(Vector2(30.15, -9.2), Vector2(0, -1), 1.1, 2.6, 2.6, 5.3, METAL, 1)     # 0.81: no outro lado (a 1ª chega livre)
	_carreta(Vector2(-19.75, 9.6), 0.0)
	_carro(Vector2(-6.0, 16.0), 0.4, Color(0.3, 0.32, 0.36))
	_carro(Vector2(10.0, 9.0), PI - 0.3, Color(0.6, 0.6, 0.6), "carro", true)
	_cerca(Vector2(-33.0, 24.5), Vector2(-12.0, 24.5))
	_cerca(Vector2(2.0, 24.5), Vector2(33.0, 24.5))
	_guarita(Vector2(4.5, 21.5))
	_cacamba(Vector2(-31.0, -8.0), PI * 0.5)
	for k in 5:
		_barril(Vector2(-31.5 + (k % 2) * 0.7, -16.0 + k * 0.7), [Color(0.2, 0.3, 0.55), Color(0.55, 0.18, 0.12), Color(0.2, 0.4, 0.2)][k % 3], k == 4)
	for p in [Vector2(-31, 14), Vector2(18, 20), Vector2(-14, 23)]:
		_poste(p, 0.0, 9.0)
	_ponto(Vector3(29.6, 2.6, -11.6), "conteiner")
	_ponto(Vector3(29.6, 5.2, -18.0), "conteiner")
	_pontos_em(Rect2(-30, 5, 60, 18), 0.0, 3, "patio")
	_bagunca(Rect2(-32, 4, 64, 20), 0.0, 20)
	infectados = [Vector3(-20, 0, -11.2), Vector3(0, 0, -16.8), Vector3(-8, 0, -1), Vector3(17, 0, -17), Vector3(-15, 0, 12), Vector3(20, 0, 5)]

func _empilhadeira(p: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, 0, p.y)
	var am := Color(0.9, 0.68, 0.1)
	resto.caixa(o + b * Vector3(0, 0.7, -0.3), Vector3(1.2, 0.9, 2.0), am, b)
	resto.caixa(o + b * Vector3(0, 1.0, -1.1), Vector3(1.2, 0.8, 0.5), Color(0.2, 0.2, 0.2), b)
	for x in [-0.55, 0.55]:
		resto.caixa(o + b * Vector3(x, 1.95, -0.2), Vector3(0.06, 1.3, 0.06), METAL_ESC, b)
		resto.caixa(o + b * Vector3(x, 1.4, 1.0), Vector3(0.08, 2.6, 0.12), METAL_ESC, b)
		resto.caixa(o + b * Vector3(x * 0.6, 0.12, 1.6), Vector3(0.12, 0.05, 1.1), METAL_ESC, b)
	resto.caixa(o + b * Vector3(0, 2.6, -0.2), Vector3(1.2, 0.06, 1.4), METAL_ESC, b)
	for z in [-1.0, 0.5]:
		resto.cilindro(o + b * Vector3(0, 0.3, z), 0.3, 1.3, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	col.append([o + Vector3(0, 1.0, 0) + b * Vector3(0, 0, 0.0), Vector3(1.3, 2.0, 2.8), 0.0, b])

# contêiner de 6 m (ao longo de Z local girado); y = apoiado em cima de outro; aberto = portas abertas e loot dentro
func _conteiner(p: Vector2, g: float, cor: Color, loot: String, y := 0.0, aberto := false) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, y, p.y)
	var L := 6.06
	var W := 2.44
	var Hc := 2.6
	if aberto:
		# paredes, teto e chão (dá para entrar), portas abertas viradas para +Z
		for s in [-1.0, 1.0]:
			resto.caixa(o + b * Vector3(s * (W * 0.5 - 0.04), Hc * 0.5, 0), Vector3(0.08, Hc, L), cor, b)
			col.append([o + b * Vector3(s * (W * 0.5 - 0.04), Hc * 0.5, 0), Vector3(0.1, Hc, L), 0.0, b])
			resto.caixa(o + b * Vector3(s * (W * 0.5 + 0.5), Hc * 0.5, L * 0.5 + 0.55), Vector3(0.06, Hc - 0.1, 1.15), cor * 0.9, b * Basis(Vector3.UP, s * 1.3))
		resto.caixa(o + b * Vector3(0, Hc - 0.04, 0), Vector3(W, 0.08, L), cor * 0.95, b)
		resto.caixa(o + b * Vector3(0, 0.04, 0), Vector3(W, 0.08, L), MADEIRA_CLARA * 0.6, b)
		resto.caixa(o + b * Vector3(0, Hc * 0.5, -L * 0.5 + 0.04), Vector3(W, Hc, 0.08), cor, b)
		col.append([o + b * Vector3(0, Hc - 0.04, 0), Vector3(W, 0.1, L), 0.0, b])
		col.append([o + b * Vector3(0, Hc * 0.5, -L * 0.5 + 0.04), Vector3(W, Hc, 0.1), 0.0, b])
		for k in 3:
			resto.caixa(o + b * Vector3(r.randf_range(-0.5, 0.5), 0.35, -2.0 + k * 1.1), Vector3(0.8, 0.55, 0.7), Color(0.55, 0.42, 0.28), b)
		if loot != "":
			_loot(o + b * Vector3(0, 0.15, -1.0), loot, "CONTÊINER", Vector2i(8, 5))
		return
	resto.caixa(o + Vector3(0, Hc * 0.5, 0), Vector3(W, Hc, L), cor, b)
	for k in 9:
		resto.caixa(o + b * Vector3(W * 0.5 + 0.01, Hc * 0.5, -L * 0.5 + 0.4 + k * 0.66), Vector3(0.03, Hc - 0.2, 0.1), cor * 0.8, b)
		resto.caixa(o + b * Vector3(-W * 0.5 - 0.01, Hc * 0.5, -L * 0.5 + 0.4 + k * 0.66), Vector3(0.03, Hc - 0.2, 0.1), cor * 0.8, b)
	col.append([o + Vector3(0, Hc * 0.5, 0), Vector3(W, Hc, L), 0.0, b])
	if loot != "":
		_loot(o + b * Vector3(0, 0.1, L * 0.5 + 0.6), loot, "CONTÊINER", Vector2i(8, 5))

# cerca de alambrado com postes
func _cerca(a: Vector2, b: Vector2, h := 2.4) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var t := 0.0
	while t <= L + 0.01:
		var p := a + d * t
		fora.cilindro(Vector3(p.x, h * 0.5, p.y), 0.04, h, 5, METAL_ESC)
		t += 3.0
	var m := (a + b) * 0.5
	var em_x := absf(d.x) > 0.5
	resto.caixa(Vector3(m.x, h * 0.5, m.y), Vector3(L, h - 0.1, 0.02) if em_x else Vector3(0.02, h - 0.1, L), Color(0.48, 0.5, 0.52))
	resto.caixa(Vector3(m.x, h, m.y), Vector3(L, 0.04, 0.04) if em_x else Vector3(0.04, 0.04, L), METAL_ESC)
	col.append([Vector3(m.x, h * 0.5, m.y), Vector3(L, h, 0.1) if em_x else Vector3(0.1, h, L), 0.0, Basis.IDENTITY])

func _guarita(p: Vector2) -> void:
	var ret := Rect2(p.x - 1.3, p.y - 1.3, 2.6, 2.6)
	_perimetro(ret, 0.0, 2.6, Color(0.82, 0.8, 0.74), Color(0.8, 0.78, 0.72), [[[0.3, 2.2, 1.0, 2.0, "janela"]], [[0.5, 1.7, 0.0, 2.3]], [[0.5, 2.1, 1.0, 2.0, "janela"]], [[0.4, 2.2, 1.0, 2.0, "janela"]]], resto)
	fora.caixa(Vector3(p.x, 2.75, p.y), Vector3(3.2, 0.3, 3.2), CONCRETO_ESC)
	_col(Vector3(p.x, 2.75, p.y), Vector3(3.2, 0.3, 3.2))
	_bx(resto, Vector3(p.x, 0.45, p.y - 0.75), Vector3(2.0, 0.9, 0.6), Moveis.MADEIRA_ESC)
	_loot(Vector3(p.x, 0.1, p.y), "balcao", "GUARITA", Vector2i(4, 2))
