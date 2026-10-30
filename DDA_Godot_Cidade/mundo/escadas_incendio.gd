extends Node3D
# ESCADAS DE INCÊNDIO DE VERDADE (1.04 · substitui as de enfeite do mundo/fachadas.gd): todo prédio (menos as ruínas)
# tem pelo menos 2, do chão (calçada) até o TELHADO, e dá para subir nelas andando (sem pular), até de perna quebrada.
#   · Cada uma: um PATAMAR em cada andar (L x P m, colado na fachada) e os LANCES em zigue-zague entre eles. Os lances
#     alternam entre duas faixas (a de fora e a de dentro do patamar), então um lance nunca fica em cima da cabeça de
#     quem sobe o outro; o patamar tem o vão só por cima do lance que chega nele. Grade em volta de tudo.
#   · O 1º lance sai da calçada; o último chega numa plataforma na altura do telhado, encostada nele: dali se anda para
#     o telhado (que tem física: a caixa do prédio, a "casca" dos prédios abertos altos, ou o telhado com mureta dos
#     abertos baixos, que ganha uma abertura onde a escada chega: mundo/interior.gd _telhado).
#   · Onde fica: em lados do prédio sem outro prédio colado (se só um lado está livre e é largo, as duas ficam nele).
#     Tudo sai dos dados do prédio (sempre igual: no multijogador todos veem a mesma coisa, sem mandar nada pela rede).
#   · DESENHO: montado aos poucos em pedaços de CEL m perto da câmera (detalhado até PERTO m, simplificado até o
#     alcance de Opções › Distância dos detalhes); os aparelhos de ar-condicionado das janelas também vêm daqui.
#   · FÍSICA: só nos prédios a até RAIO_FISICA m do jogador, montada aos poucos (no máximo ORCAMENTO_US por quadro),
#     na camada CAMADA (só o jogador colide: os infectados passam por ela na calçada e não sobem).
# Mexa AQUI para: tamanho dos patamares e lances, quantas por prédio, alcances, cor.

const Malhas := preload("res://mundo/malhas.gd")
const Interior := preload("res://mundo/interior.gd")

const ANDAR := 3.3                     # = shader PREDIO (mundo/materiais_cidade.gd): andar de 3,3 m...
const BASE := 4.6                      # ... a partir de 4,6 m
const COLUNA := 2.7                    # colunas de janelas
const Y_RUA := 0.6                     # = mundo/cidade.gd Y_RUA (base dos prédios fechados)
const Y_CALCADA := 0.55                # = mundo/cidade.gd Y_CALCADA (piso dos prédios abertos e chão do 1º lance)
const P := 2.0                         # fundo do patamar (para fora da fachada)
const W := 0.85                        # largura de cada lance (faixa)
const A := 2.4                         # meio comprimento do lance: corre 4,8 m (3,3 m de subida = 34°)
const L := 6.8                         # largura do patamar (sobra 1 m em cada ponta para virar)
const ESP := 0.12                      # espessura do piso (física)
const SUBIDA_MIN := 2.3                # o lance mais baixo (altura livre por baixo do patamar de cima)
const SUBIDA_MAX := 4.7                # o mais alto (o 1º, da calçada ao 1º andar, tem ~4,65; 44°)
const GRADE := 1.1                     # altura da grade (física)
const POR_PREDIO := 2
const CEL := 125.0
const PERTO := 70.0                    # m (do meio do sub-pedaço de CEL/2): até aqui o desenho detalhado
const ALCANCES := [150.0, 220.0, 300.0, 400.0]   # por Opções › Distância dos detalhes (o simplificado vai até aqui)
const RAIO_FISICA := 30.0
const ORCAMENTO_US := 1500
const MAX_AR := 10
const FERRO := Color(0.13, 0.12, 0.11)
# camada de física só das escadas: o JOGADOR colide (a máscara dele tem 16), os INFECTADOS não (só a 1): eles não
# esbarram nem empacam nos lances da calçada (e não sobem: a escada é um refúgio); os tiros passam pela grade
const CAMADA := 16

# ---------- dados (estáticos: interior.gd e os testes usam sem o nó) ----------
static var _cid = null
static var _hash := {}                 # Vector2i (células de 50 m) -> PackedInt32Array (prédios)
static var _planos := {}               # índice do prédio -> Array de planos

static func preparar(cid) -> void:
	_cid = cid
	_planos.clear()
	_hash.clear()
	var tmp := {}
	for i in cid.predio_info.size():
		var inf: Dictionary = cid.predio_info[i]
		var r := Rect2(float(inf["x"]) - float(inf["sx"]) * 0.5, float(inf["z"]) - float(inf["sz"]) * 0.5, float(inf["sx"]), float(inf["sz"]))
		for cx in range(floori(r.position.x / 50.0), floori(r.end.x / 50.0) + 1):
			for cz in range(floori(r.position.y / 50.0), floori(r.end.y / 50.0) + 1):
				var k := Vector2i(cx, cz)
				if not tmp.has(k):
					tmp[k] = []
				tmp[k].append(i)
	for k in tmp:
		_hash[k] = PackedInt32Array(tmp[k])

static func _livre(r: Rect2, menos: int) -> bool:
	for cx in range(floori(r.position.x / 50.0), floori(r.end.x / 50.0) + 1):
		for cz in range(floori(r.position.y / 50.0), floori(r.end.y / 50.0) + 1):
			for i in _hash.get(Vector2i(cx, cz), PackedInt32Array()):
				if i == menos:
					continue
				var inf: Dictionary = _cid.predio_info[i]
				var b := Rect2(float(inf["x"]) - float(inf["sx"]) * 0.5, float(inf["z"]) - float(inf["sz"]) * 0.5, float(inf["sx"]), float(inf["sz"]))
				if b.intersects(r):
					return false
	return true

# [normal para fora, eixo ao longo da fachada, meia-largura, distância do centro] (igual ao antigo mundo/fachadas.gd)
static func _fachada(lado: int, sx: float, sz: float) -> Array:
	var n: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][lado]
	var largo := sx if lado < 2 else sz
	var fundo := sz if lado < 2 else sx
	return [n, Vector3.UP.cross(n), largo * 0.5, fundo * 0.5]

# altura do telhado onde a escada chega (a do prédio aberto, que é o que existe quando o jogador está nela)
static func altura_telhado(inf: Dictionary) -> float:
	var h: float = inf["h"]
	if bool(inf.get("entra", false)):
		var t := Interior.altura_telhado(inf)
		return Y_CALCADA + (t if t > 0.0 else h)
	return Y_RUA + h

# os planos das escadas do prédio i: [{"lado", "n", "e", "o" (pé na fachada, y 0), "niveis" (chão, patamares..., telhado)}]
static func planos(i: int) -> Array:
	if _planos.has(i):
		return _planos[i]
	var r: Array = []
	_planos[i] = r
	if _cid == null or i < 0 or i >= _cid.predio_info.size():
		return r
	var inf: Dictionary = _cid.predio_info[i]
	if bool(inf.get("ruina", false)) or not inf.has("t"):
		return r
	var R := altura_telhado(inf)
	if R - Y_CALCADA < 1.6:
		return r
	# níveis: chão, um patamar por andar (até SUBIDA_MIN abaixo do telhado: o lance que chega no telhado nunca é
	# curto demais, senão a cabeça bate no patamar de cima) e o telhado; um lance alto demais vira dois iguais
	var base := PackedFloat32Array([Y_CALCADA])
	var d := Y_RUA + BASE
	while d <= R - SUBIDA_MIN:
		base.append(d)
		d += ANDAR
	base.append(R)
	var niveis := PackedFloat32Array([base[0]])
	for k in range(1, base.size()):
		var sobe := base[k] - base[k - 1]
		var partes := 1 if sobe <= SUBIDA_MAX else int(ceil(sobe / ANDAR))
		for p in range(1, partes + 1):
			niveis.append(base[k - 1] + sobe * p / partes)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([i, 1104])
	var lados := [0, 1, 2, 3]
	for k in range(3, 0, -1):
		var j := rng.randi_range(0, k)
		var t = lados[k]
		lados[k] = lados[j]
		lados[j] = t
	var c := Vector3(float(inf["x"]), 0.0, float(inf["z"]))
	var usados := {}                     # lado -> [u já usados]
	for passada in 2:                    # 1ª: uma por lado livre · 2ª: a segunda num lado largo que já tem uma
		for lado in lados:
			if r.size() >= POR_PREDIO:
				break
			var f := _fachada(lado, float(inf["sx"]), float(inf["sz"]))
			var hw: float = f[2] - L * 0.5 - 0.3
			if hw < 0.0:
				continue
			var tentativas: Array = []
			if passada == 0:
				var u0 := clampf(snappedf(rng.randf_range(-hw, hw), COLUNA), -hw, hw)
				tentativas = [u0, -u0, 0.0]
			else:
				if not usados.has(lado) or hw < L * 0.5 + 0.3:
					continue
				tentativas = [-hw, hw]
			for u in tentativas:
				var ok := true
				for uu in usados.get(lado, []):
					if absf(float(uu) - float(u)) < L + 0.6:
						ok = false
				if not ok:
					continue
				var o: Vector3 = c + f[0] * f[3] + f[1] * float(u)
				var a: Vector3 = o + f[1] * (L * 0.5 + 0.2) + f[0] * 0.02
				var b: Vector3 = o - f[1] * (L * 0.5 + 0.2) + f[0] * (P + 0.4)
				var ret := Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(a.x - b.x), absf(a.z - b.z)))
				if not _livre(ret, i):
					continue
				r.append({"lado": lado, "n": f[0], "e": f[1], "o": o, "u": float(u), "niveis": niveis, "meia": L * 0.5})
				if not usados.has(lado):
					usados[lado] = []
				usados[lado].append(u)
				break
	return r

# ---------- peças (na fachada: x ao longo, y = altura do mundo, z para fora) ----------
static func _base(pl: Dictionary) -> Basis:
	return Basis(pl["e"], Vector3.UP, pl["n"])

static func _mundo(pl: Dictionary, x: float, y: float, z: float) -> Vector3:
	return (pl["o"] as Vector3) + (pl["e"] as Vector3) * x + Vector3.UP * y + (pl["n"] as Vector3) * z

static func _faixa(k: int) -> float:
	return P - W * 0.5 if k % 2 == 0 else P - W * 1.5         # centro da faixa do lance k (0: de fora · 1: de dentro)

# caixas de colisão de uma escada: [centro, tamanho, 0.0, Basis] (o formato de mundo/interior.gd adicionar_caixas)
static func caixas(pl: Dictionary) -> Array:
	var cx: Array = []
	var b := _base(pl)
	var nv: PackedFloat32Array = pl["niveis"]
	var add := func(x: float, y: float, z: float, tam: Vector3, local := Basis.IDENTITY) -> void:
		cx.append([_mundo(pl, x, y, z), tam, 0.0, b * local])
	# patamares (o 1º nível é o chão) e o vão por cima do lance que chega
	for j in range(1, nv.size()):
		var y := nv[j]
		var teto := j == nv.size() - 1
		var z0 := -0.5 if teto else 0.0              # a plataforma do telhado entra 0,5 m em cima dele
		var zc := (z0 + P) * 0.5
		var fundo := P - z0
		add.call(-(L * 0.5 + A) * 0.5, y - ESP * 0.5, zc, Vector3(L * 0.5 - A, ESP, fundo))
		add.call((L * 0.5 + A) * 0.5, y - ESP * 0.5, zc, Vector3(L * 0.5 - A, ESP, fundo))
		if (j - 1) % 2 == 0:                       # vão na faixa de fora
			add.call(0.0, y - ESP * 0.5, (z0 + P - W) * 0.5, Vector3(2.0 * A, ESP, P - W - z0))
		else:                                       # vão na faixa de dentro
			add.call(0.0, y - ESP * 0.5, (z0 + P - 2.0 * W) * 0.5, Vector3(2.0 * A, ESP, P - 2.0 * W - z0))
			add.call(0.0, y - ESP * 0.5, P - W * 0.5, Vector3(2.0 * A, ESP, W))
		# grades: frente, pontas e a borda do vão
		add.call(0.0, y + GRADE * 0.5, P - 0.03, Vector3(L, GRADE, 0.06))
		add.call(-(L * 0.5 - 0.03), y + GRADE * 0.5, zc, Vector3(0.06, GRADE, fundo))
		add.call(L * 0.5 - 0.03, y + GRADE * 0.5, zc, Vector3(0.06, GRADE, fundo))
		add.call(0.0, y + GRADE * 0.5, P - W, Vector3(2.0 * A, GRADE, 0.06))
	# lances: rampa que chega na altura de cima um pouco antes do fim + pedaço plano + grade dos dois lados
	for k in nv.size() - 1:
		var y0 := nv[k]
		var sobe := nv[k + 1] - y0
		var s := 1.0 if k % 2 == 0 else -1.0
		var zc := _faixa(k)
		var corre := 2.0 * A - 0.15
		var inc := atan2(sobe, corre)
		var l_r := sqrt(corre * corre + sobe * sobe)
		# rampa (no plano x-y da fachada): do pé (x = -s A) subindo para +s
		var rot := Basis(Vector3.BACK, inc * s)                 # gira em volta de z (o eixo "para fora")
		var up_r := rot * Vector3.UP
		var dir_r := rot * Vector3(s, 0, 0)
		var meio := Vector3(-s * A, y0, zc) + dir_r * (l_r * 0.5) - up_r * 0.15 - dir_r * 0.075
		add.call(meio.x, meio.y, meio.z, Vector3(l_r + 0.15, 0.3, W), rot)
		add.call(s * (A - 0.15 + 0.25), y0 + sobe - 0.1, zc, Vector3(0.5, 0.2, W))
		for lado in [-1.0, 1.0]:
			var zg: float = zc + float(lado) * (W * 0.5 + 0.03)
			for p in 5:
				var t := (p + 0.5) / 5.0
				add.call(-s * A + s * 2.0 * A * t, y0 + sobe * t + 0.375, zg, Vector3(2.0 * A / 5.0, 1.35, 0.06))
	return cx

# ---------- malhas (desenho) ----------
static var _mat: Material = null
static var _m_deck: Array = [null, null]      # [vão de fora, vão de dentro]
static var _m_lance: Mesh = null
static var _m_deck_longe: Mesh = null
static var _m_lance_longe: Mesh = null
static var _m_ar: Mesh = null

static func _malhas() -> void:
	if _mat != null:
		return
	var mat := Malhas.mat_cores(0.6)
	mat.metallic = 0.3
	_mat = mat
	for vao in 2:
		var c := Malhas.Construtor.new()
		c.ao = 0.15
		_deck(c, vao)
		_m_deck[vao] = c.malha(mat)
	var cl := Malhas.Construtor.new()
	cl.ao = 0.15
	_lance(cl)
	_m_lance = cl.malha(mat)
	var cd := Malhas.Construtor.new()
	cd.caixa(Vector3(0, -0.04, P * 0.5), Vector3(L, 0.08, P), FERRO)
	cd.caixa(Vector3(0, 0.5, P - 0.02), Vector3(L, 1.0, 0.03), FERRO * 1.4)
	_m_deck_longe = cd.malha(mat)
	var cr := Malhas.Construtor.new()
	var inc := atan2(ANDAR, 2.0 * A)
	cr.caixa(Vector3(0, ANDAR * 0.5, 0), Vector3(2.0 * A / cos(inc), 0.06, W), FERRO, Basis(Vector3.BACK, inc))
	_m_lance_longe = cr.malha(mat)
	var ca := Malhas.Construtor.new()
	ca.caixa(Vector3(0, 0, 0.18), Vector3(0.66, 0.42, 0.5), Color(1, 1, 1))
	ca.caixa(Vector3(0, 0, 0.44), Vector3(0.56, 0.3, 0.02), Color(0.45, 0.45, 0.45))      # grade da frente
	ca.caixa(Vector3(0, -0.24, 0.3), Vector3(0.6, 0.04, 0.04), Color(0.4, 0.35, 0.3))     # suporte
	_m_ar = ca.malha(Malhas.mat_cores(0.7))

# patamar (piso de grade com o vão, bordas, grades) · y = 0 no piso
static func _deck(c, vao: int) -> void:
	var g := FERRO * 1.25
	c.caixa(Vector3(-(L * 0.5 + A) * 0.5, -0.03, P * 0.5), Vector3(L * 0.5 - A, 0.06, P), g)
	c.caixa(Vector3((L * 0.5 + A) * 0.5, -0.03, P * 0.5), Vector3(L * 0.5 - A, 0.06, P), g)
	if vao == 0:
		c.caixa(Vector3(0, -0.03, (P - W) * 0.5), Vector3(2.0 * A, 0.06, P - W), g)
	else:
		c.caixa(Vector3(0, -0.03, (P - 2.0 * W) * 0.5), Vector3(2.0 * A, 0.06, P - 2.0 * W), g)
		c.caixa(Vector3(0, -0.03, P - W * 0.5), Vector3(2.0 * A, 0.06, W), g)
	c.caixa(Vector3(0, -0.12, P - 0.03), Vector3(L, 0.18, 0.05), FERRO)                       # borda da frente
	for y in [0.5, 1.0]:
		c.caixa(Vector3(0, y, P - 0.02), Vector3(L, 0.04, 0.04), FERRO)                       # grade da frente
		for sx in [-1.0, 1.0]:
			c.caixa(Vector3(sx * (L * 0.5 - 0.02), y, P * 0.5), Vector3(0.04, 0.04, P), FERRO)
		c.caixa(Vector3(0, y, P - W), Vector3(2.0 * A, 0.035, 0.035), FERRO)                   # borda do vão
	for i in 5:
		var x := -L * 0.5 + 0.02 + i * (L - 0.04) / 4.0
		c.caixa(Vector3(x, 0.5, P - 0.02), Vector3(0.035, 1.0, 0.035), FERRO)
	for x in [-A, A]:
		c.caixa(Vector3(x, 0.5, P - W), Vector3(0.03, 1.0, 0.03), FERRO)

# lance padrão: sobe ANDAR em 2A (de x = -A para +A), centrado na faixa (z = 0) · os outros são escalados na altura
static func _lance(c) -> void:
	var inc := atan2(ANDAR, 2.0 * A)
	var comp := 2.0 * A / cos(inc)
	var rot := Basis(Vector3.BACK, inc)
	for lado in [-1.0, 1.0]:
		c.caixa(Vector3(0, ANDAR * 0.5 - 0.1, lado * W * 0.5), Vector3(comp, 0.2, 0.04), FERRO, rot)                 # banzo
		c.caixa(Vector3(0, ANDAR * 0.5 + 0.95, lado * (W * 0.5 + 0.02)), Vector3(comp, 0.04, 0.04), FERRO, rot)      # corrimão
		for t in [0.0, 1.0]:
			c.caixa(Vector3(-A + 2.0 * A * t, ANDAR * t + 0.47, lado * (W * 0.5 + 0.02)), Vector3(0.03, 0.95, 0.03), FERRO)
	var n := 7
	for i in n:
		var t := (i + 0.5) / n
		c.caixa(Vector3(-A + 2.0 * A * t, ANDAR * t - 0.02, 0), Vector3(2.0 * A / n + 0.02, 0.035, W - 0.04), FERRO * 1.3)   # degraus

# ---------- o nó: desenho por pedaços e física perto do jogador ----------
var jogador: Node3D = null
var alcance := 220.0                   # Opções › Distância dos detalhes (mundo/cidade.gd aplicar_detalhes)
var com_desenho := true
var _cel_predios := {}                 # Vector2i -> PackedInt32Array
var _cels := {}                        # Vector2i -> Node3D montado
var _t_cel := 0.0
var _fila_fis: Array = []              # [corpo, caixas, próxima]
var _corpos := {}                      # índice do prédio -> StaticBody3D
var _ult_fis := Vector2(1e9, 1e9)
var instancias := 0                    # (testes)

func ligar(cid, quem: Node3D) -> void:
	preparar(cid)
	jogador = quem
	_malhas()
	for i in cid.predio_info.size():
		var inf: Dictionary = cid.predio_info[i]
		var k := Vector2i(floori(float(inf["x"]) / CEL), floori(float(inf["z"]) / CEL))
		if not _cel_predios.has(k):
			_cel_predios[k] = PackedInt32Array()
		var lst: PackedInt32Array = _cel_predios[k]
		lst.append(i)
		_cel_predios[k] = lst

func _process(dt: float) -> void:
	if not com_desenho or _cid == null:
		return
	_t_cel -= dt
	if _t_cel > 0.0:
		return
	_t_cel = 0.25
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := Vector2(cam.global_position.x, cam.global_position.z)
	var raio := alcance + CEL * 0.75
	var c0 := Vector2i(floori(p.x / CEL), floori(p.y / CEL))
	var nr := int(ceil(raio / CEL))
	var falta: Vector2i = Vector2i(1 << 30, 0)
	var md := INF
	for dz in range(-nr, nr + 1):
		for dx in range(-nr, nr + 1):
			var k := c0 + Vector2i(dx, dz)
			if _cels.has(k) or not _cel_predios.has(k):
				continue
			var d := p.distance_to((Vector2(k) + Vector2(0.5, 0.5)) * CEL)
			if d < raio and d < md:
				md = d
				falta = k
	if falta.x != 1 << 30:
		_montar_cel(falta)                  # um pedaço por vez (o mais perto primeiro)
		_t_cel = 0.0
	for k in _cels.keys():
		if p.distance_to((Vector2(k) + Vector2(0.5, 0.5)) * CEL) > raio + CEL:
			_cels[k].queue_free()
			_cels.erase(k)

func aplicar_alcance(a: float) -> void:
	alcance = a
	for k in _cels:
		_alcances(_cels[k])

func _alcances(no: Node3D) -> void:
	for mi in no.get_children():
		if mi.has_meta("longe"):
			mi.visibility_range_begin = PERTO
			mi.visibility_range_end = alcance
		else:
			mi.visibility_range_end = PERTO + 5.0

func _montar_cel(k: Vector2i) -> void:
	var no := Node3D.new()
	no.name = "Escadas_%d_%d" % [k.x, k.y]
	add_child(no)
	_cels[k] = no
	# o detalhado vai em 4 sub-pedaços (CEL/2): só os bem perto da câmera ficam detalhados; o simples, no pedaço todo
	var sub := {}                            # Vector2i(0..1, 0..1) -> [deck vão fora, deck vão dentro, lances, ar, cores ar]
	var longe_deck: Array = []
	var longe_lance: Array = []
	for i in _cel_predios[k]:
		var inf: Dictionary = _cid.predio_info[i]
		var sk := Vector2i(clampi(floori((float(inf["x"]) - k.x * CEL) / (CEL * 0.5)), 0, 1), clampi(floori((float(inf["z"]) - k.y * CEL) / (CEL * 0.5)), 0, 1))
		if not sub.has(sk):
			sub[sk] = [[], [], [], [], []]
		var g: Array = sub[sk]
		var pls := planos(i)
		for pl in pls:
			var b := _base(pl)
			var nv: PackedFloat32Array = pl["niveis"]
			for j in range(1, nv.size()):
				var t := Transform3D(b, _mundo(pl, 0, nv[j], 0))
				g[(j - 1) % 2].append(t)
				longe_deck.append(t)
			for kk in nv.size() - 1:
				var s := 1.0 if kk % 2 == 0 else -1.0
				var bl := b if s > 0.0 else b * Basis(Vector3.UP, PI)
				bl = bl * Basis.from_scale(Vector3(1.0, (nv[kk + 1] - nv[kk]) / ANDAR, 1.0))
				var t := Transform3D(bl, _mundo(pl, 0, nv[kk], _faixa(kk)))
				g[2].append(t)
				longe_lance.append(t)
		_ar_condicionado(i, pls, g[3], g[4])
	for sk in sub:
		var g: Array = sub[sk]
		_mmi(no, _m_deck[0], g[0], [], false)
		_mmi(no, _m_deck[1], g[1], [], false)
		_mmi(no, _m_lance, g[2], [], false)
		_mmi(no, _m_ar, g[3], g[4], false)
	_mmi(no, _m_deck_longe, longe_deck, [], true)
	_mmi(no, _m_lance_longe, longe_lance, [], true)
	_alcances(no)

func _mmi(no: Node3D, malha: Mesh, ts: Array, cores: Array, longe: bool) -> void:
	if ts.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true                    # (sem isso a cor da malha sai preta no renderizador do celular)
	mm.mesh = malha
	mm.instance_count = ts.size()
	for i in ts.size():
		mm.set_instance_transform(i, ts[i])
		mm.set_instance_color(i, cores[i] if i < cores.size() else Color.WHITE)
	instancias += ts.size()
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if longe:
		mi.set_meta("longe", true)
	no.add_child(mi)

# aparelhos de ar-condicionado em algumas janelas (não nas que a escada tapa)
func _ar_condicionado(i: int, pls: Array, ts: Array, cs: Array) -> void:
	var inf: Dictionary = _cid.predio_info[i]
	if bool(inf.get("ruina", false)) or not inf.has("t") or int(inf["tipo"]) == 3:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash([i, 5150])
	if int(inf["tipo"]) == 2 and r.randf() < 0.5:
		return
	var andares := int(floor((float(inf["h"]) - 1.3 - BASE) / ANDAR))
	if andares < 1:
		return
	var c := Vector3(float(inf["x"]), Y_RUA, float(inf["z"]))
	for n_i in r.randi_range(0, MAX_AR):
		var ld := r.randi() % 4
		var f := _fachada(ld, float(inf["sx"]), float(inf["sz"]))
		var kmax := int(floor(f[2] / COLUNA)) - 1
		if kmax < 1:
			continue
		var k := r.randi_range(-kmax, kmax - 1)
		var u := (k + 0.5) * COLUNA
		var tapa := false
		for pl in pls:
			if int(pl["lado"]) == ld and absf(float(pl["u"]) - u) < L * 0.5 + 0.6:
				tapa = true
		if tapa:
			continue
		var j := r.randi_range(0, mini(andares - 1, 9))
		var p: Vector3 = c + f[0] * f[3] + f[1] * u + Vector3(0, BASE + j * ANDAR + 0.22 * ANDAR + 0.2, 0)
		ts.append(Transform3D(Basis(f[1], Vector3.UP, f[0]), p))
		var cor: Color = [Color(0.82, 0.80, 0.74), Color(0.7, 0.7, 0.68), Color(0.62, 0.55, 0.45), Color(0.9, 0.9, 0.88)][r.randi() % 4]
		cs.append(cor * r.randf_range(0.8, 1.05))

# ---------- física: prédios perto do jogador ----------
func _physics_process(_dt: float) -> void:
	if _cid == null or jogador == null or not is_instance_valid(jogador):
		return
	var p := Vector2(jogador.global_position.x, jogador.global_position.z)
	if p.distance_to(_ult_fis) > 3.0:
		_ult_fis = p
		var perto := {}
		var r := RAIO_FISICA
		for cx in range(floori((p.x - r) / 50.0), floori((p.x + r) / 50.0) + 1):
			for cz in range(floori((p.y - r) / 50.0), floori((p.y + r) / 50.0) + 1):
				for i in _hash.get(Vector2i(cx, cz), PackedInt32Array()):
					var inf: Dictionary = _cid.predio_info[i]
					var ex := maxf(absf(p.x - float(inf["x"])) - float(inf["sx"]) * 0.5, 0.0)
					var ez := maxf(absf(p.y - float(inf["z"])) - float(inf["sz"]) * 0.5, 0.0)
					if ex * ex + ez * ez < r * r:
						perto[i] = true
		for i in _corpos.keys():
			if not perto.has(i):
				var ex := maxf(absf(p.x - float(_cid.predio_info[i]["x"])) - float(_cid.predio_info[i]["sx"]) * 0.5, 0.0)
				var ez := maxf(absf(p.y - float(_cid.predio_info[i]["z"])) - float(_cid.predio_info[i]["sz"]) * 0.5, 0.0)
				if ex * ex + ez * ez > (r + 15.0) * (r + 15.0):
					_corpos[i].queue_free()
					_corpos.erase(i)
		for i in perto:
			if _corpos.has(i):
				continue
			var cx: Array = []
			for pl in planos(i):
				cx.append_array(caixas(pl))
			var corpo := StaticBody3D.new()
			corpo.name = "Escada_%d" % i
			corpo.collision_layer = CAMADA
			corpo.collision_mask = 0
			add_child(corpo)
			_corpos[i] = corpo
			if not cx.is_empty():
				_fila_fis.append([corpo, cx, 0])
			if _cid.caixas_dagua.has(i):
				caixa_dagua_fisica(corpo, _cid.caixas_dagua[i])
	# monta as caixas aos poucos (uma torre de 50 andares tem ~2000)
	var t0 := Time.get_ticks_usec()
	while not _fila_fis.is_empty() and Time.get_ticks_usec() - t0 < ORCAMENTO_US:
		var f: Array = _fila_fis[0]
		var corpo: StaticBody3D = f[0]
		if not is_instance_valid(corpo):
			_fila_fis.pop_front()
			continue
		var cx: Array = f[1]
		var fim := mini(int(f[2]) + 40, cx.size())
		Interior.adicionar_caixas(corpo, cx.slice(int(f[2]), fim))
		f[2] = fim
		if fim >= cx.size():
			_fila_fis.pop_front()

# 1.05 · CAIXA D'ÁGUA do telhado (a malha é a de mundo/cidade.gd _malha_caixa_dagua): base de ferro, tanque e
# tampa. Camada 1 (mundo): para você e para os tiros (os infectados não chegam no telhado).
static func caixa_dagua_fisica(pai: Node, t: Transform3D) -> StaticBody3D:
	var c := StaticBody3D.new()
	c.name = "CaixaDagua"
	c.collision_layer = 1
	c.collision_mask = 0
	pai.add_child(c)
	var s := t.basis.x.length()
	var base := BoxShape3D.new()
	base.size = Vector3(3.6, 2.0, 3.6) * s
	var tanque := CylinderShape3D.new()
	tanque.radius = 2.0 * s
	tanque.height = 4.0 * s
	var tampa := CylinderShape3D.new()
	tampa.radius = 1.3 * s
	tampa.height = 1.4 * s
	for f in [[base, 1.0], [tanque, 4.0], [tampa, 6.7]]:
		var cs := CollisionShape3D.new()
		cs.shape = f[0]
		cs.position = t.origin + Vector3(0.0, float(f[1]) * s, 0.0)
		c.add_child(cs)
	return c

# (testes) monta já a física dos prédios perto de p
func montar_fisica_agora() -> void:
	_ult_fis = Vector2(1e9, 1e9)
	_physics_process(0.0)
	while not _fila_fis.is_empty():
		var f: Array = _fila_fis.pop_front()
		if is_instance_valid(f[0]):
			Interior.adicionar_caixas(f[0], (f[1] as Array).slice(int(f[2])))
