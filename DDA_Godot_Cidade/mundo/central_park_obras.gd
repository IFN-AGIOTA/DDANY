extends RefCounted
# CONSTRUÇÕES DO CENTRAL PARK (1.20), feitas olhando as fotos do parque de verdade. Quem chama: mundo/central_park.gd
# (montar), com a posição e o giro de data/central_park.json. Cada uma é montada em coordenadas LOCAIS (y = 0 no
# chão do parque; salvo dito, +Z = a frente) com o Construtor (mundo/malhas.gd), um por material, e as caixas de
# colisão vão para o corpo do parque.
#   bethesda    · BETHESDA TERRACE: terraço alto de arenito (92 x 24 m, 4,6 m) com balaustrada, a ARCADA por baixo (7 arcos
#                 para o lago, 3 para a rua, colunas e o teto de azulejos), 2 escadarias largas descendo até a praça de
#                 tijolos e a FONTE DO ANJO (Angel of the Waters) no meio da bacia; na beira do lago, balaustrada e o
#                 cais dos barcos. Escadas laterais sobem da rua até o terraço. (Montada já virada para o norte: -Z.)
#   bow_bridge  · BOW BRIDGE: ponte de ferro creme em arco baixo (44 m), guarda-corpo de círculos entrelaçados, vasos.
#   gapstow     · GAPSTOW BRIDGE: ponte de pedra (xisto) com um arco só, sobre o braço do The Pond.
#   belvedere   · BELVEDERE CASTLE em cima da VISTA ROCK: torre com ameias, torrinha redonda com telhado cônico e
#                 bandeira, o corpo do castelo, o pavilhão de madeira e o terraço de frente para o Turtle Pond.
#   boathouse   · LOEB BOATHOUSE: casa comprida de tijolo claro com telhado verde, varanda para o lago, cais e barcos.
#   bandshell   · NAUMBURG BANDSHELL: concha (meia cúpula) de pedra clara sobre o palco.
#   cleopatra   · CLEOPATRA'S NEEDLE: o obelisco de granito vermelho (21 m) no pedestal com os caranguejos.
#   wollman     · WOLLMAN RINK: a pista oval com as muretas e o prédio da pista.
#   carrossel   · CARROUSEL: casa octogonal de tijolo com o carrossel de cavalinhos dentro.
#   imagine     · STRAWBERRY FIELDS: o mosaico "IMAGINE".
#   delacorte, kerbs, alice, cherry_fonte, estatua (Shakespeare, Colombo, Burns, Scott), beisebol (campo + alambrado)
# Mexa AQUI para: o desenho de cada construção.

const Malhas := preload("res://mundo/malhas.gd")
const CP := preload("res://mundo/central_park.gd")
const PEDRA := Color(0.76, 0.67, 0.52)
const PEDRA_CLARA := Color(0.84, 0.8, 0.72)
const XISTO := Color(0.43, 0.42, 0.41)
const FERRO := Color(0.07, 0.09, 0.075)
const CREME := Color(0.88, 0.85, 0.76)
const BRONZE := Color(0.28, 0.37, 0.31)          # bronze com pátina verde
const BRONZE_ESCURO := Color(0.2, 0.21, 0.18)
const MADEIRA := Color(0.42, 0.3, 0.2)
const TELHADO_VERDE := Color(0.33, 0.52, 0.44)
const TIJOLO_CLARO := Color(0.74, 0.6, 0.45)
const TIJOLO := Color(0.55, 0.3, 0.22)
const GRANITO := Color(0.48, 0.47, 0.46)

var parque                                       # o nó mundo/central_park.gd
var T := Transform3D.IDENTITY                    # local -> mundo da construção atual
var cs := {}                                     # material -> Construtor
var r := RandomNumberGenerator.new()

func _init(p) -> void:
	parque = p
	r.seed = 1857

func montar(tipo: String, pos: Vector3, giro: float, extra: Dictionary) -> void:
	T = Transform3D(Basis(Vector3.UP, giro), pos)
	cs = {}
	match tipo:
		"bethesda": _bethesda()
		"bow_bridge": _bow_bridge(float(extra.get("vao", 44.0)))
		"gapstow": _gapstow(float(extra.get("vao", 30.0)))
		"belvedere": _belvedere()
		"boathouse": _boathouse()
		"bandshell": _bandshell()
		"cleopatra": _cleopatra()
		"wollman": _wollman()
		"carrossel": _carrossel()
		"imagine": _imagine()
		"delacorte": _delacorte()
		"kerbs": _kerbs()
		"alice": _alice()
		"cherry_fonte": _cherry_fonte()
		"estatua": _estatua(String(extra.get("quem", "")))
		"beisebol": _beisebol()
	_fim("CP_" + tipo + "_%d_%d" % [int(pos.x), int(pos.z)])

# ---------------------------------------------------------------------------------------------------------------
# PEÇAS
# ---------------------------------------------------------------------------------------------------------------
func _c(m: String) -> Malhas.Construtor:
	if not cs.has(m):
		cs[m] = Malhas.Construtor.new()
	return cs[m]

func _b(m: String, c: Vector3, tam: Vector3, cor: Color, b := Basis.IDENTITY) -> void:
	_c(m).caixa(c, tam, cor, b)

func _bc(m: String, c: Vector3, tam: Vector3, cor: Color, b := Basis.IDENTITY) -> void:
	_c(m).caixa(c, tam, cor, b)
	_col(c, tam, b)

func _cil(m: String, c: Vector3, raio: float, h: float, lados: int, cor: Color, b := Basis.IDENTITY, topo := -1.0) -> void:
	_c(m).cilindro(c, raio, h, lados, cor, b, topo)

func _col(c: Vector3, tam: Vector3, b := Basis.IDENTITY) -> void:
	parque.col(T * c, tam, T.basis * b)

func _fim(nome: String) -> void:
	var am: ArrayMesh = null
	for m in cs:
		var c: Malhas.Construtor = cs[m]
		if c.vazio():
			continue
		am = c.malha(CP.mat(m), am)
	if am != null:
		parque.por_malha(nome, am, T, 1400.0)

# escada de pedra (degraus + rampa de colisão): começa embaixo em "ini" (local, y = ini.y), sobe "dy" ao longo de "dir"
# em "comp" m, largura "larg"
func _escada(m: String, ini: Vector3, dir: Vector2, larg: float, dy: float, comp: float, cor: Color) -> void:
	var n := int(ceil(dy / 0.17))
	var b := Basis(Vector3.UP, atan2(-dir.y, dir.x))
	for i in n:
		var t := (i + 0.5) / n
		var p := Vector2(ini.x, ini.z) + dir * comp * t
		var topo := ini.y + (i + 1) * dy / n
		var h := minf(topo - ini.y, 0.5)
		_b(m, Vector3(p.x, topo - h * 0.5, p.y), Vector3(comp / n + 0.02, h, larg), cor * (0.96 if i % 2 == 0 else 1.0), b)
	# rampa (o personagem sobe sem tropeçar) + o pedaço plano depois do último degrau
	var u := Vector3(dir.x, 0, dir.y) * comp + Vector3.UP * dy
	var l := u.length()
	var meio := Vector3(ini.x, ini.y, ini.z) + u * 0.5
	var bb := Basis(Vector3.UP, atan2(-dir.y, dir.x)) * Basis(Vector3.BACK, atan2(dy, comp))
	# a rampa termina EXATAMENTE no topo (o pedaço a mais fica só embaixo, enterrado): sem "degrauzinho" lá em cima,
	# que a cápsula do personagem toma por parede
	_col(meio - bb.y * 0.15 - u.normalized() * 0.15, Vector3(l + 0.3, 0.3, larg), bb)
	var fim := Vector3(ini.x, ini.y + dy, ini.z) + Vector3(dir.x, 0, dir.y) * (comp + 0.7)    # começa onde a rampa acaba
	_col(fim - Vector3(0, 0.15, 0), Vector3(1.4, 0.3, larg) if absf(dir.x) > 0.5 else Vector3(larg, 0.3, 1.4))
	var gi: Vector3 = T * Vector3(ini.x, ini.y, ini.z)
	var gd: Vector3 = T.basis * Vector3(dir.x, 0, dir.y)
	parque.escadas.append([Vector2(gi.x, gi.z), Vector2(gd.x, gd.z).normalized(), larg, gi.y, dy, comp])

# balaustrada de pedra de a até b (y de a e b = onde ela pisa: pode ser inclinada, como nas escadarias)
func _balaustrada(m: String, a: Vector3, b: Vector3, cor: Color, alt := 1.05, colisao := true) -> void:
	var d := b - a
	var comp := Vector2(d.x, d.z).length()
	if comp < 0.3:
		return
	var giro := atan2(-d.z, d.x)
	var incl := atan2(d.y, comp)
	var bb := Basis(Vector3.UP, giro) * Basis(Vector3.BACK, incl)
	var l := d.length()
	var meio := (a + b) * 0.5
	_b(m, meio + Vector3(0, 0.12, 0), Vector3(l, 0.24, 0.42), cor * 0.95, bb)                     # base
	_b(m, meio + Vector3(0, alt - 0.08, 0), Vector3(l, 0.16, 0.48), cor, bb)                       # corrimão de pedra
	var n := int(comp / 0.36)
	for k in n:
		var t := (k + 0.5) / n
		var p := a + d * t
		_cil(m, p + Vector3(0, 0.24 + (alt - 0.4) * 0.5, 0), 0.075, alt - 0.4, 6, cor * 1.02, Basis.IDENTITY, 0.055)
	var npil := int(comp / 6.0)
	for k in range(npil + 1):
		var p := a + d * (float(k) / maxf(npil, 1))
		_b(m, p + Vector3(0, alt * 0.5 + 0.05, 0), Vector3(0.55, alt + 0.1, 0.55), cor * 0.97, Basis(Vector3.UP, giro))
	if colisao:
		_col(meio + Vector3(0, alt * 0.5 + 0.1, 0), Vector3(l, alt + 0.2, 0.45), bb)

# parede com aberturas em arco ao longo de X (de x0 a x1, em z, espessura "esp", do chão até "y1");
# aberturas: [centro x, largura, altura do começo do arco]
func _parede_arcos(m: String, x0: float, x1: float, z: float, esp: float, y1: float, aberturas: Array, cor: Color) -> void:
	var x := x0
	var lista := aberturas.duplicate()
	lista.sort_custom(func(a, b): return a[0] < b[0])
	for ab in lista:
		var xa: float = float(ab[0]) - float(ab[1]) * 0.5
		if xa > x + 0.01:
			_bc(m, Vector3((x + xa) * 0.5, y1 * 0.5, z), Vector3(xa - x, y1, esp), cor)
		# o arco: fatias de cima (do arco até y1)
		var w: float = ab[1]
		var ya: float = ab[2]
		var rr := w * 0.5
		var nf := 10
		for k in nf:
			var xx := xa + (k + 0.5) * w / nf
			var dx := xx - float(ab[0])
			var ycurva := ya + sqrt(maxf(rr * rr - dx * dx, 0.0))
			var h := y1 - ycurva
			if h > 0.02:
				_b(m, Vector3(xx, ycurva + h * 0.5, z), Vector3(w / nf + 0.01, h, esp), cor)
		# aduelas (o contorno do arco, um pouco mais claro e saliente)
		for k in 9:
			var a := PI * (k + 0.5) / 9.0
			var p := Vector3(float(ab[0]) + cos(a) * (rr + 0.12), ya + sin(a) * (rr + 0.12), z)
			_b(m, p, Vector3(0.3, 0.42, esp + 0.12), cor * 1.06, Basis(Vector3.BACK, a - PI * 0.5))
		_col(Vector3(float(ab[0]), (ya + rr + y1) * 0.5, z), Vector3(w, maxf(y1 - ya - rr, 0.3), esp))
		x = xa + w
	if x1 > x + 0.01:
		_bc(m, Vector3((x + x1) * 0.5, y1 * 0.5, z), Vector3(x1 - x, y1, esp), cor)

# urna de pedra/ferro com planta em cima
func _vaso(m: String, p: Vector3, cor: Color, esc := 1.0) -> void:
	_cil(m, p + Vector3(0, 0.15 * esc, 0), 0.22 * esc, 0.3 * esc, 8, cor)
	_cil(m, p + Vector3(0, 0.55 * esc, 0), 0.18 * esc, 0.5 * esc, 10, cor, Basis.IDENTITY, 0.48 * esc)
	_cil("madeira", p + Vector3(0, 0.95 * esc, 0), 0.42 * esc, 0.35 * esc, 8, Color(0.2, 0.32, 0.14), Basis.IDENTITY, 0.2 * esc)

# figura de bronze simples (em pé): ~altura "h"; "capa" = manto até o chão
func _figura(m: String, p: Vector3, h: float, cor: Color, giro := 0.0, capa := true) -> void:
	var b := Basis(Vector3.UP, giro)
	var s := h / 1.8
	if capa:
		_cil(m, p + b * Vector3(0, 0.55 * s, 0), 0.3 * s, 1.1 * s, 8, cor, b, 0.2 * s)
	else:
		for lado: float in [-1.0, 1.0]:
			_b(m, p + b * Vector3(0.1 * s * lado, 0.45 * s, 0), Vector3(0.14 * s, 0.9 * s, 0.16 * s), cor, b)
	_b(m, p + b * Vector3(0, 1.22 * s, 0), Vector3(0.44 * s, 0.6 * s, 0.26 * s), cor, b)
	_cil(m, p + b * Vector3(0, 1.6 * s, 0), 0.11 * s, 0.22 * s, 8, cor * 1.05, b)
	for lado: float in [-1.0, 1.0]:
		_b(m, p + b * Vector3(0.28 * s * lado, 1.15 * s, 0.02 * s), Vector3(0.11 * s, 0.55 * s, 0.12 * s), cor, b * Basis(Vector3.BACK, 0.12 * lado))

# ---------------------------------------------------------------------------------------------------------------
# BETHESDA TERRACE e a FONTE DO ANJO (y=0 no chão; o terraço alto vai de z 0 (rua) a z -24; a praça até z -110)
# ---------------------------------------------------------------------------------------------------------------
func _bethesda() -> void:
	var ht := 4.6                          # topo do terraço alto
	var ha := 4.0                          # teto da arcada
	var w2 := 46.0
	var dd := 24.0
	# laje do terraço alto (o piso de cima) e os blocos maciços dos lados
	_bc("pedra", Vector3(0, ht - 0.25, -dd * 0.5), Vector3(w2 * 2.0, 0.5, dd), PEDRA)
	for s: float in [-1.0, 1.0]:
		_bc("pedra", Vector3(s * (w2 + 20.0) * 0.5, (ht - 0.5) * 0.5, -dd * 0.5), Vector3(w2 - 20.0, ht - 0.5, dd), PEDRA * 0.97)
	# fachada da arcada para a RUA (3 arcos) e para o LAGO (7 arcos)
	_parede_arcos("pedra", -20.0, 20.0, -0.6, 1.2, ha, [[-6.0, 3.4, 2.3], [0.0, 3.4, 2.3], [6.0, 3.4, 2.3]], PEDRA)
	var ab7: Array = []
	for k in 7:
		ab7.append([-17.15 + k * 5.72, 3.6, 2.1])
	_parede_arcos("pedra", -20.0, 20.0, -dd + 0.6, 1.2, ha, ab7, PEDRA)
	# colunas da arcada (2 fileiras) e o teto de azulejos (Minton)
	for z: float in [-8.0, -16.0]:
		for k in 6:
			var x := -14.3 + k * 5.72
			_cil("pedra", Vector3(x, ha * 0.5, z), 0.38, ha, 10, PEDRA * 1.03)
			_b("pedra", Vector3(x, ha - 0.25, z), Vector3(1.1, 0.5, 1.1), PEDRA * 1.06)
			_b("pedra", Vector3(x, 0.2, z), Vector3(1.0, 0.4, 1.0), PEDRA * 0.95)
			_col(Vector3(x, ha * 0.5, z), Vector3(0.8, ha, 0.8))
	_b("azulejo", Vector3(0, ha + 0.02, -dd * 0.5), Vector3(39.6, 0.04, dd - 2.4), Color(1, 1, 1))
	_b("pedra", Vector3(0, 0.03, -dd * 0.5), Vector3(39.6, 0.06, dd - 1.2), PEDRA * 0.8)                # piso da arcada
	# balaustradas do terraço alto: na frente (entre as escadarias), na rua e nos lados
	_balaustrada("pedra", Vector3(-26.0, ht, -dd + 0.25), Vector3(26.0, ht, -dd + 0.25), PEDRA)
	for s: float in [-1.0, 1.0]:
		_balaustrada("pedra", Vector3(s * 40.6, ht, -dd + 0.25), Vector3(s * w2, ht, -dd + 0.25), PEDRA)
		_balaustrada("pedra", Vector3(s * w2 - s * 0.25, ht, -dd), Vector3(s * w2 - s * 0.25, ht, -11.5), PEDRA)
		_balaustrada("pedra", Vector3(s * w2 - s * 0.25, ht, -2.6), Vector3(s * w2 - s * 0.25, ht, -0.25), PEDRA)
	_balaustrada("pedra", Vector3(-w2, ht, -0.25), Vector3(w2, ht, -0.25), PEDRA)
	# as 2 ESCADARIAS largas (do terraço alto até a praça, para o norte) com as balaustradas inclinadas
	for s: float in [-1.0, 1.0]:
		var xc := s * 33.3
		_escada("pedra", Vector3(xc, 0.0, -dd - 14.0), Vector2(0, 1), 13.0, ht, 14.0, PEDRA * 0.98)
		for lado: float in [-1.0, 1.0]:
			var xl := xc + lado * 6.8
			_bc("pedra", Vector3(xl, ht * 0.25, -dd - 7.0), Vector3(0.6, ht * 0.5, 14.0), PEDRA * 0.95)
			_balaustrada("pedra", Vector3(xl, 0.2, -dd - 14.0), Vector3(xl, ht, -dd), PEDRA)
			_b("pedra", Vector3(xl, 0.75, -dd - 14.6), Vector3(1.2, 1.5, 1.2), PEDRA * 1.02)
			_vaso("pedra", Vector3(xl, 1.5, -dd - 14.6), PEDRA_CLARA, 1.2)
	# escadas laterais: da calçada da rua (leste e oeste) até o terraço alto
	for s: float in [-1.0, 1.0]:
		_escada("pedra", Vector3(s * (w2 + 15.0), 0.0, -7.0), Vector2(-s, 0), 8.6, ht, 15.0, PEDRA * 0.97)
		_balaustrada("pedra", Vector3(s * (w2 + 15.0), 0.2, -2.45), Vector3(s * w2, ht, -2.45), PEDRA)
		_balaustrada("pedra", Vector3(s * (w2 + 15.0), 0.2, -11.55), Vector3(s * w2, ht, -11.55), PEDRA)
	# ---- a PRAÇA DE BAIXO (o piso de tijolo é do chão do parque) e a FONTE ----
	_fonte_anjo(Vector3(0, 0, -68.0))
	# beira do lago: balaustrada com a abertura do cais no meio, o cais e 2 lampiões
	_balaustrada("pedra", Vector3(-52.0, 0.0, -109.6), Vector3(-7.0, 0.0, -109.6), PEDRA)
	_balaustrada("pedra", Vector3(7.0, 0.0, -109.6), Vector3(52.0, 0.0, -109.6), PEDRA)
	_bc("pedra", Vector3(0, -0.25, -114.5), Vector3(14.0, 0.5, 9.0), PEDRA * 0.9)            # cais (o lago começa em z -110)
	for s: float in [-1.0, 1.0]:
		_b("pedra", Vector3(s * 7.0, 0.7, -109.6), Vector3(1.0, 1.4, 1.0), PEDRA)
		_vaso("pedra", Vector3(s * 7.0, 1.4, -109.6), PEDRA_CLARA)
		for z: float in [-40.0, -96.0]:
			_b("pedra", Vector3(s * 50.0, 0.6, z), Vector3(1.1, 1.2, 1.1), PEDRA)
			_vaso("pedra", Vector3(s * 50.0, 1.2, z), PEDRA_CLARA, 1.1)
	# a praça é fechada nos lados por muretas (com abertura para os caminhos)
	for s: float in [-1.0, 1.0]:
		_balaustrada("pedra", Vector3(s * 52.0, 0.0, -dd - 1.0), Vector3(s * 52.0, 0.0, -50.0), PEDRA)
		_balaustrada("pedra", Vector3(s * 52.0, 0.0, -62.0), Vector3(s * 52.0, 0.0, -109.6), PEDRA)
	parque.pontos_altos["bethesda_terraco"] = T * Vector3(0, ht, -12.0)
	parque.pontos_altos["bethesda_fonte"] = T * Vector3(0, 0, -50.0)

func _fonte_anjo(c: Vector3) -> void:
	var rb := 14.5
	var n := 36
	for k in n:
		var a0 := k * TAU / n
		var a1 := (k + 1) * TAU / n
		var am := (a0 + a1) * 0.5
		var corda := 2.0 * (rb + 0.45) * sin(PI / n) + 0.05
		var p := c + Vector3(cos(am) * (rb + 0.45), 0.32, sin(am) * (rb + 0.45))
		var b := Basis(Vector3.UP, -am + PI * 0.5)
		_b("pedra", p, Vector3(corda, 0.64, 0.9), PEDRA * 1.02, b)
		_b("pedra", p + Vector3(0, 0.36, 0), Vector3(corda + 0.04, 0.1, 1.05), PEDRA_CLARA, b)
		if k % 3 == 0:
			_col(p + Vector3(0, 0.0, 0), Vector3(corda * 3.0, 0.9, 1.0), b)
	_cil("agua_fonte", c + Vector3(0, 0.33, 0), rb, 0.04, 36, Color(1, 1, 1))
	# o pedestal de pedra, os 4 querubins e as bacias de bronze, e o ANJO em cima (~8,5 m)
	_cil("pedra", c + Vector3(0, 0.45, 0), 4.6, 0.9, 16, PEDRA * 0.95)
	_cil("pedra", c + Vector3(0, 1.2, 0), 2.2, 0.6, 12, PEDRA)
	_col(c + Vector3(0, 1.2, 0), Vector3(6.0, 2.4, 6.0))
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		_figura("bronze", c + Vector3(cos(a) * 1.5, 1.5, sin(a) * 1.5), 1.1, BRONZE, -a + PI * 0.5, false)
	_cil("bronze", c + Vector3(0, 2.4, 0), 0.9, 1.8, 12, BRONZE)
	_cil("bronze", c + Vector3(0, 3.55, 0), 2.4, 0.55, 20, BRONZE, Basis.IDENTITY, 5.4)             # bacia de baixo
	_cil("bronze", c + Vector3(0, 3.9, 0), 5.3, 0.18, 20, BRONZE * 1.1)
	_cil("bronze", c + Vector3(0, 4.7, 0), 0.5, 1.6, 10, BRONZE)
	_cil("bronze", c + Vector3(0, 5.55, 0), 1.0, 0.35, 14, BRONZE, Basis.IDENTITY, 2.2)            # bacia de cima
	_cil("bronze", c + Vector3(0, 5.95, 0), 0.45, 0.6, 10, BRONZE)
	_anjo(c + Vector3(0, 6.25, 0))

func _anjo(p: Vector3) -> void:
	var cor := BRONZE * 1.08
	_cil("bronze", p + Vector3(0, 0.75, 0), 0.38, 1.5, 10, cor, Basis.IDENTITY, 0.24)           # túnica
	_b("bronze", p + Vector3(0, 1.75, 0), Vector3(0.52, 0.62, 0.3), cor)                           # tronco
	_cil("bronze", p + Vector3(0, 2.18, 0), 0.13, 0.26, 10, cor)                                    # cabeça
	_b("bronze", p + Vector3(0.3, 1.75, 0.3), Vector3(0.12, 0.12, 0.7), cor, Basis(Vector3.RIGHT, -0.5))     # braço direito: abençoando
	_b("bronze", p + Vector3(-0.32, 1.6, 0.1), Vector3(0.12, 0.6, 0.12), cor, Basis(Vector3.BACK, 0.25))      # braço esquerdo
	_cil("bronze", p + Vector3(-0.42, 1.55, 0.18), 0.03, 0.9, 5, cor, Basis(Vector3.RIGHT, 0.4))             # os lírios
	# as asas: abertas para trás e para cima, 3 "penas" grandes cada
	for lado: float in [-1.0, 1.0]:
		for k in 3:
			var comp := 1.7 - k * 0.35
			var b := Basis(Vector3.UP, lado * (0.45 + k * 0.12)) * Basis(Vector3.BACK, lado * (0.7 + k * 0.18))
			_b("bronze", p + Vector3(lado * 0.45, 1.95 - k * 0.12, -0.25 - k * 0.04), Vector3(comp, 0.36 - k * 0.06, 0.06), cor * (1.0 - k * 0.04), b)

# ---------------------------------------------------------------------------------------------------------------
# BOW BRIDGE (ao longo de z; o arco sobe 1,6 m no meio)
# ---------------------------------------------------------------------------------------------------------------
func _bow_bridge(vao: float) -> void:
	var meio := vao * 0.5
	var hw := 2.4
	var f := func(z: float) -> float: return 0.0 + 1.9 * (1.0 - (z / meio) * (z / meio))
	var n := 22
	var dz := vao / n
	for k in n:
		var z0 := -meio + k * dz
		var z1 := z0 + dz
		var y0: float = f.call(z0)
		var y1: float = f.call(z1)
		var zc := (z0 + z1) * 0.5
		var yc := (y0 + y1) * 0.5
		var inc := atan2(y1 - y0, dz)
		var b := Basis(Vector3.RIGHT, -inc)
		var l := sqrt(dz * dz + (y1 - y0) * (y1 - y0)) + 0.02
		_b("madeira", Vector3(0, yc, zc), Vector3(hw * 2.0, 0.12, l), MADEIRA * 0.9, b)                    # tábuas
		for s: float in [-1.0, 1.0]:
			_b("ferro_creme", Vector3(s * (hw + 0.08), yc - 0.22, zc), Vector3(0.16, 0.5, l), CREME, b)   # viga da borda
			_b("renda", Vector3(s * (hw + 0.08), yc + 0.6, zc), Vector3(0.04, 1.0, l), CREME, b)           # guarda-corpo rendado
			_b("ferro_creme", Vector3(s * (hw + 0.08), yc + 1.12, zc), Vector3(0.14, 0.1, l), CREME, b)    # corrimão
			# o arco de baixo e a renda entre ele e a ponte
			if absf(zc) < meio - 6.0:
				var za := zc / (meio - 6.0)
				var ya := 1.45 * (1.0 - za * za)
				var h := yc - 0.47 - ya
				if h > 0.08:
					_b("renda", Vector3(s * (hw + 0.08), ya + h * 0.5, zc), Vector3(0.04, h, dz + 0.01), CREME)
				_b("ferro_creme", Vector3(s * (hw + 0.08), ya, zc), Vector3(0.18, 0.22, dz + 0.05), CREME, Basis(Vector3.RIGHT, -atan2(-2.9 * za / (meio - 6.0), 1.0)))
		if k % 2 == 0:
			var zz := z0 + dz
			var yy: float = f.call(zz)
			_col(Vector3(0, yy - 0.1, zz), Vector3(hw * 2.0, 0.3, dz * 2.0 + 0.1), Basis(Vector3.RIGHT, -atan2(f.call(zz + dz) - f.call(zz - dz), dz * 2.0)))
			for s: float in [-1.0, 1.0]:
				_col(Vector3(s * (hw + 0.1), yy + 0.6, zz), Vector3(0.2, 1.3, dz * 2.0 + 0.1))
	# postes do guarda-corpo e os 8 vasos
	for k in 13:
		var z := -meio + 2.0 + k * (vao - 4.0) / 12.0
		var y: float = f.call(z)
		for s: float in [-1.0, 1.0]:
			var vaso := k in [1, 4, 8, 11]
			_b("ferro_creme", Vector3(s * (hw + 0.08), y + (0.75 if vaso else 0.6), z), Vector3(0.22, 1.5 if vaso else 1.2, 0.22), CREME)
			if vaso:
				_vaso("ferro_creme", Vector3(s * (hw + 0.08), y + 1.5, z), CREME, 0.8)
	# cabeceiras de pedra nas margens
	for s: float in [-1.0, 1.0]:
		_bc("xisto", Vector3(0, -1.25, s * (meio - 3.0)), Vector3(hw * 2.0 + 1.6, 2.4, 7.0), XISTO)
		for lado: float in [-1.0, 1.0]:
			_bc("xisto", Vector3(lado * (hw + 1.4), -0.3, s * (meio - 1.0)), Vector3(1.4, 2.0, 5.0), XISTO * 1.05, Basis(Vector3.UP, lado * s * 0.35))
	parque.pontos_altos["bow_bridge"] = T * Vector3(0, f.call(0.0), 0)

# ---------------------------------------------------------------------------------------------------------------
# GAPSTOW BRIDGE (pedra, um arco; ao longo de z)
# ---------------------------------------------------------------------------------------------------------------
func _gapstow(vao: float) -> void:
	var meio := vao * 0.5
	var hw := 3.5
	var f := func(z: float) -> float: return 0.0 + 1.6 * (1.0 - (z / meio) * (z / meio))
	var raio_arco := 6.5
	var n := 30
	var dz := vao / n
	for k in n:
		var zc := -meio + (k + 0.5) * dz
		var yd: float = f.call(zc)
		var yb := -1.2
		if absf(zc) < raio_arco:
			yb = -0.2 + 3.4 * sqrt(1.0 - (zc / raio_arco) * (zc / raio_arco))
		var cor := XISTO * (0.9 + 0.2 * r.randf())
		cor.a = 1.0
		# corpo da ponte (entre o arco e o piso) e as muretas de pedra
		_b("xisto", Vector3(0, (yb + yd) * 0.5, zc), Vector3(hw * 2.0, yd - yb, dz + 0.02), cor)
		for s: float in [-1.0, 1.0]:
			_b("xisto", Vector3(s * (hw - 0.3), yd + 0.55, zc), Vector3(0.6, 1.1, dz + 0.02), cor * 1.05)
		if absf(zc) < raio_arco:
			for s: float in [-1.0, 1.0]:
				_b("xisto", Vector3(s * (hw + 0.05), yb + 0.25, zc), Vector3(0.12, 0.5, dz + 0.02), XISTO * 1.25)   # aduelas
	for k in 8:
		var z0 := -meio + k * vao / 8.0
		var z1 := z0 + vao / 8.0
		var y0: float = f.call(z0)
		var y1: float = f.call(z1)
		var b := Basis(Vector3.RIGHT, -atan2(y1 - y0, vao / 8.0))
		_col(Vector3(0, (y0 + y1) * 0.5 - 0.15, (z0 + z1) * 0.5), Vector3(hw * 2.0, 0.3, vao / 8.0 + 0.1), b)
		for s: float in [-1.0, 1.0]:
			_col(Vector3(s * (hw - 0.3), (y0 + y1) * 0.5 + 0.6, (z0 + z1) * 0.5), Vector3(0.6, 1.2, vao / 8.0 + 0.1), b)
	parque.pontos_altos["gapstow"] = T * Vector3(0, f.call(0.0), 0)

# ---------------------------------------------------------------------------------------------------------------
# BELVEDERE CASTLE em cima da VISTA ROCK (de frente para o norte, -Z: o Turtle Pond)
# ---------------------------------------------------------------------------------------------------------------
func _belvedere() -> void:
	var yt := 7.5                          # topo da rocha (o terraço)
	# a rocha: blocos grandes de xisto, mais alta perto do lago
	for k in 14:
		var a := k * TAU / 14.0 + r.randf() * 0.3
		var dist := r.randf_range(9.0, 17.0)
		var p := Vector3(cos(a) * dist, 0, sin(a) * dist * 0.8 - 2.0)
		var h := yt * r.randf_range(0.55, 1.0) * (1.0 - dist / 30.0)
		var b := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(-0.2, 0.2))
		_b("xisto", p + Vector3(0, h * 0.5 - 0.5, 0), Vector3(r.randf_range(8.0, 13.0), h + 1.0, r.randf_range(7.0, 10.0)), XISTO * r.randf_range(0.75, 0.95), b)
	_bc("xisto", Vector3(0, yt * 0.5 - 0.3, -2.0), Vector3(30.0, yt, 20.0), XISTO * 0.85)
	_bc("pedra", Vector3(0, yt - 0.1, -2.0), Vector3(30.0, 0.2, 20.0), GRANITO)                   # piso do terraço
	# parapeito com ameias em volta do terraço (aberto atrás, onde a escada chega)
	var bordas := [[Vector2(-15, -12), Vector2(15, -12)], [Vector2(-15, -12), Vector2(-15, 8)], [Vector2(15, -12), Vector2(15, 8)],
		[Vector2(-15, 8), Vector2(-3, 8)], [Vector2(3, 8), Vector2(15, 8)]]
	for bd: Array in bordas:
		_muro_ameias(bd[0], bd[1], yt + 0.2, 1.1)
	# a TORRE (8 x 8, 11 m) com ameias e janelas góticas
	var tc := Vector3(-5.0, yt, -5.0)
	_bc("xisto", tc + Vector3(0, 5.5, 0), Vector3(8.0, 11.0, 8.0), XISTO)
	for k in 4:
		var a := k * PI * 0.5
		var lado := Vector2(cos(a), sin(a))
		_muro_ameias(Vector2(tc.x, tc.z) + lado * 4.0 + Vector2(-lado.y, lado.x) * 4.0, Vector2(tc.x, tc.z) + lado * 4.0 - Vector2(-lado.y, lado.x) * 4.0, tc.y + 11.0, 1.0, 0.0)
		for jy: float in [3.2, 7.4]:
			_janela_gotica(tc + Vector3(lado.x * 4.03, jy, lado.y * 4.03), atan2(-lado.y, lado.x) + PI * 0.5)
	# a torrinha redonda no canto (telhado cônico de ardósia e a bandeira)
	var tr := tc + Vector3(3.6, 0, -3.6)
	_cil("xisto", tr + Vector3(0, 7.0, 0), 1.7, 14.0, 12, XISTO * 1.03)
	_col(tr + Vector3(0, 7.0, 0), Vector3(3.0, 14.0, 3.0))
	_cil("telhado", tr + Vector3(0, 15.6, 0), 2.0, 3.2, 12, Color(0.22, 0.24, 0.26), Basis.IDENTITY, 0.05)
	_cil("ferro", tr + Vector3(0, 19.0, 0), 0.04, 4.0, 5, FERRO)
	_b("madeira", tr + Vector3(0.7, 20.3, 0), Vector3(1.4, 0.8, 0.03), Color(0.6, 0.15, 0.13))      # bandeira (rasgada)
	_b("madeira", tr + Vector3(0.35, 20.5, 0), Vector3(0.7, 0.4, 0.035), Color(0.15, 0.2, 0.42))
	# o corpo do castelo (mais baixo) com ameias e janelas
	var cc := Vector3(5.0, yt, -6.0)
	_bc("xisto", cc + Vector3(0, 3.0, 0), Vector3(12.0, 6.0, 7.0), XISTO * 0.97)
	_muro_ameias(Vector2(cc.x - 6, cc.z - 3.5), Vector2(cc.x + 6, cc.z - 3.5), cc.y + 6.0, 0.9, 0.0)
	_muro_ameias(Vector2(cc.x + 6, cc.z - 3.5), Vector2(cc.x + 6, cc.z + 3.5), cc.y + 6.0, 0.9, 0.0)
	_muro_ameias(Vector2(cc.x - 6, cc.z + 3.5), Vector2(cc.x + 6, cc.z + 3.5), cc.y + 6.0, 0.9, 0.0)
	for x: float in [-3.5, 0.0, 3.5]:
		_janela_gotica(cc + Vector3(x, 3.0, -3.53), PI)
	_b("madeira", cc + Vector3(-2.0, 1.3, 3.55), Vector3(1.6, 2.6, 0.12), MADEIRA * 0.7)             # porta (fechada)
	# o pavilhão de madeira (telhado pontudo)
	var pv := Vector3(9.0, yt, 4.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_bc("madeira", pv + Vector3(sx * 2.2, 1.6, sz * 2.2), Vector3(0.25, 3.2, 0.25), MADEIRA * 0.8)
	_cil("telhado", pv + Vector3(0, 4.2, 0), 3.6, 2.2, 4, Color(0.26, 0.24, 0.22), Basis(Vector3.UP, PI * 0.25), 0.05)
	# a escada que sobe a rocha (do caminho, atrás: +Z) em 2 lances
	_escada("pedra", Vector3(0, 0, 27.0), Vector2(0, -1), 3.2, yt * 0.5, 9.0, GRANITO)
	_bc("pedra", Vector3(0, yt * 0.5 - 0.15, 16.5), Vector3(3.2, 0.3, 3.0), GRANITO)
	_escada("pedra", Vector3(0, yt * 0.5, 15.0), Vector2(0, -1), 3.2, yt * 0.5, 7.0, GRANITO)
	for s: float in [-1.0, 1.0]:
		_bc("xisto", Vector3(s * 2.0, yt * 0.4, 17.0), Vector3(0.6, yt * 0.8, 20.0), XISTO * 0.9)
	parque.pontos_altos["belvedere"] = T * Vector3(0, yt + 0.2, -6.0)

func _muro_ameias(a: Vector2, b: Vector2, y: float, alt: float, esp := 0.6) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.2:
		return
	var giro := atan2(-d.y, d.x)
	var bb := Basis(Vector3.UP, giro)
	var m := (a + b) * 0.5
	if esp > 0.0:
		_bc("xisto", Vector3(m.x, y + alt * 0.5, m.y), Vector3(l, alt, esp), XISTO * 1.02, bb)
	var n := int(l / 1.6)
	for k in n:
		var p := a + d * ((k + 0.5) / n)
		_b("xisto", Vector3(p.x, y + alt + 0.45, p.y), Vector3(0.85, 0.9, maxf(esp, 0.6) + 0.04), XISTO * 1.06, bb)

func _janela_gotica(p: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	_b("vidro_escuro", p, Vector3(1.1, 1.8, 0.1), Color(0.08, 0.09, 0.1), b)
	for k in 5:
		var a := PI * (k + 0.5) / 5.0
		_b("vidro_escuro", p + b * Vector3(cos(a) * 0.45, 0.9 + sin(a) * 0.4, 0), Vector3(0.3, 0.3, 0.1), Color(0.08, 0.09, 0.1), b)
	_b("pedra", p + b * Vector3(0, -0.98, 0.05), Vector3(1.4, 0.16, 0.25), GRANITO, b)

# ---------------------------------------------------------------------------------------------------------------
# LOEB BOATHOUSE (frente +Z = o lago): casa comprida, varanda, cais e barcos
# ---------------------------------------------------------------------------------------------------------------
func _boathouse() -> void:
	var hw := 20.0
	_bc("tijolo_parede", Vector3(0, 2.5, -1.0), Vector3(hw * 2.0, 5.0, 12.0), TIJOLO_CLARO)
	# janelões na frente e nos lados
	for k in 9:
		var x := -16.0 + k * 4.0
		_b("vidro_escuro", Vector3(x, 2.4, 5.02), Vector3(2.8, 3.0, 0.1), Color(0.12, 0.16, 0.17))
		_b("pedra", Vector3(x, 0.85, 5.1), Vector3(3.0, 0.2, 0.3), PEDRA_CLARA)
	# telhado verde de 4 águas (2 planos inclinados + cumeeira) com beiral
	for s: float in [-1.0, 1.0]:
		_b("telhado", Vector3(0, 6.3, -1.0 + s * 3.9), Vector3(hw * 2.0 + 3.0, 0.25, 8.6), TELHADO_VERDE, Basis(Vector3.RIGHT, s * 0.32))
	_b("telhado", Vector3(0, 7.65, -1.0), Vector3(hw * 2.0 - 2.0, 0.3, 0.8), TELHADO_VERDE * 0.9)
	for s: float in [-1.0, 1.0]:
		_b("telhado", Vector3(s * (hw + 0.9), 6.4, -1.0), Vector3(3.4, 0.25, 15.0), TELHADO_VERDE, Basis(Vector3.BACK, -s * 0.5))
	# varanda para o lago: piso, colunas brancas e o toldo
	_bc("madeira", Vector3(0, 0.12, 8.5), Vector3(hw * 2.0, 0.24, 7.0), MADEIRA * 0.85)
	for k in 11:
		var x := -hw + 1.0 + k * (hw * 2.0 - 2.0) / 10.0
		_cil("pedra", Vector3(x, 2.5, 11.6), 0.15, 3.8, 8, PEDRA_CLARA)
	_b("telhado", Vector3(0, 4.55, 8.6), Vector3(hw * 2.0 + 1.0, 0.2, 7.6), TELHADO_VERDE, Basis(Vector3.RIGHT, 0.1))
	_b("madeira", Vector3(0, 1.1, 11.9), Vector3(hw * 2.0, 0.08, 0.1), FERRO)
	# letreiro
	var lb := Label3D.new()
	lb.text = "THE LOEB BOATHOUSE"
	lb.font_size = 96
	lb.pixel_size = 0.012
	lb.modulate = Color(0.95, 0.93, 0.85)
	lb.outline_size = 0
	lb.position = T * Vector3(0, 5.35, 5.2)
	lb.rotation.y = T.basis.get_euler().y
	parque.visuais.append(lb)
	# cais e barcos (alguns virados: ninguém mais rema aqui)
	_bc("madeira", Vector3(0, -0.05, 15.0), Vector3(hw * 1.8, 0.3, 3.0), MADEIRA)
	for k in 12:
		_cil("madeira", Vector3(-hw * 0.9 + k * hw * 1.8 / 11.0, -0.6, 16.4), 0.12, 1.4, 6, MADEIRA * 0.6)
	for k in 10:
		var x := -16.0 + k * 3.5 + r.randf_range(-0.4, 0.4)
		var virado := r.randf() < 0.3
		_barco(Vector3(x, -0.12, 19.0 + r.randf_range(-0.6, 1.2)), r.randf_range(-0.2, 0.2) + PI * 0.5, virado)

func _barco(p: Vector3, giro: float, virado: bool) -> void:
	var b := Basis(Vector3.UP, giro)
	var cor := Color(0.2, 0.42, 0.3) if r.randf() < 0.6 else Color(0.82, 0.8, 0.74)
	if virado:
		_b("madeira", p + Vector3(0, 0.12, 0), Vector3(3.6, 0.25, 1.2), cor, b)
		_b("madeira", p + Vector3(0, 0.12, 0) + b * Vector3(1.9, 0, 0), Vector3(0.6, 0.22, 0.7), cor, b)
	else:
		_b("madeira", p + Vector3(0, 0.05, 0), Vector3(3.4, 0.12, 1.1), cor * 0.8, b)
		for s: float in [-1.0, 1.0]:
			_b("madeira", p + Vector3(0, 0.3, 0) + b * Vector3(0, 0, s * 0.55), Vector3(3.4, 0.45, 0.07), cor, b)
		_b("madeira", p + Vector3(0, 0.32, 0) + b * Vector3(1.75, 0, 0), Vector3(0.1, 0.45, 1.0), cor, b)
		_b("madeira", p + Vector3(0, 0.3, 0), Vector3(0.3, 0.06, 1.0), MADEIRA, b)

# ---------------------------------------------------------------------------------------------------------------
# NAUMBURG BANDSHELL: palco e a concha (meia cúpula) de pedra clara; frente +Z
# ---------------------------------------------------------------------------------------------------------------
func _bandshell() -> void:
	_bc("pedra", Vector3(0, 0.65, -1.0), Vector3(22.0, 1.3, 14.0), PEDRA_CLARA * 0.95)
	_escada("pedra", Vector3(0, 0, 9.5), Vector2(0, -1), 8.0, 1.3, 3.5, PEDRA_CLARA)
	var c := Vector3(0, 1.3, -4.0)
	var raio := 9.5
	var cp := _c("pedra")
	var nl := 14
	var nb := 8
	for i in nl:
		for j in nb:
			var f0 := -PI * 0.5 + PI * i / nl
			var f1 := -PI * 0.5 + PI * (i + 1) / nl
			var t0 := PI * 0.5 * j / nb
			var t1 := PI * 0.5 * (j + 1) / nb
			var pts := []
			for q in [[f0, t0], [f1, t0], [f1, t1], [f0, t1]]:
				pts.append(c + Vector3(sin(q[0]) * cos(q[1]), sin(q[1]), -cos(q[0]) * cos(q[1])) * raio)
			var nn: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
			var cor := PEDRA_CLARA * (0.92 if (i + j) % 2 == 0 else 0.98)
			cor.a = 1.0
			cp._quad(pts[0], pts[1], pts[2], pts[3], -nn, cor, Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2))     # dentro (caixotões)
			var pe := []
			for q in pts:
				pe.append(c + (q - c) * 1.06)
			cp._quad(pe[0], pe[3], pe[2], pe[1], nn, PEDRA_CLARA * 0.9, Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2))  # fora
	# o arco da frente (moldura) e as pilastras
	for k in 16:
		var a := PI * (k + 0.5) / 16.0
		_b("pedra", c + Vector3(cos(a) * raio * 1.03, sin(a) * raio * 1.03, 0.2), Vector3(1.9, 0.7, 1.0), PEDRA_CLARA, Basis(Vector3.BACK, a - PI * 0.5))
	for s: float in [-1.0, 1.0]:
		_bc("pedra", c + Vector3(s * (raio + 0.6), 2.6, -1.0), Vector3(1.4, 5.2, 3.0), PEDRA_CLARA)
	_col(c + Vector3(0, 4.0, -raio * 0.7), Vector3(raio * 2.0, 8.0, 2.0))

# ---------------------------------------------------------------------------------------------------------------
# CLEOPATRA'S NEEDLE
# ---------------------------------------------------------------------------------------------------------------
func _cleopatra() -> void:
	_bc("granito", Vector3(0, 0.3, 0), Vector3(6.4, 0.6, 6.4), GRANITO * 1.1)
	_bc("granito", Vector3(0, 1.0, 0), Vector3(4.8, 0.8, 4.8), GRANITO)
	_bc("granito", Vector3(0, 2.0, 0), Vector3(3.5, 1.2, 3.5), GRANITO * 0.85)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_b("bronze", Vector3(sx * 1.35, 2.75, sz * 1.35), Vector3(0.7, 0.3, 0.6), BRONZE * 0.9)    # os caranguejos
	var vermelho := Color(0.58, 0.41, 0.34)
	_cil("granito", Vector3(0, 2.6 + 9.75, 0), 1.75, 19.5, 4, vermelho, Basis(Vector3.UP, PI * 0.25), 1.15)
	_cil("granito", Vector3(0, 2.6 + 19.5 + 0.8, 0), 1.15, 1.6, 4, vermelho * 1.05, Basis(Vector3.UP, PI * 0.25), 0.02)
	_col(Vector3(0, 12.0, 0), Vector3(2.2, 19.0, 2.2))
	# cerquinha de ferro em volta
	for k in 8:
		var a0 := k * TAU / 8.0
		var a1 := (k + 1) * TAU / 8.0
		var p0 := Vector2(cos(a0), sin(a0)) * 8.0
		var p1 := Vector2(cos(a1), sin(a1)) * 8.0
		var m := (p0 + p1) * 0.5
		var bb := Basis(Vector3.UP, atan2(-(p1 - p0).y, (p1 - p0).x))
		_b("ferro", Vector3(m.x, 0.95, m.y), Vector3(p0.distance_to(p1), 0.06, 0.06), FERRO, bb)
		for t in 8:
			var q := p0.lerp(p1, (t + 0.5) / 8.0)
			_b("ferro", Vector3(q.x, 0.5, q.y), Vector3(0.03, 1.0, 0.03), FERRO)
		_col(Vector3(m.x, 0.5, m.y), Vector3(p0.distance_to(p1), 1.0, 0.1), bb)
	parque.pontos_altos["cleopatra"] = T * Vector3(0, 0, 9.5)

# ---------------------------------------------------------------------------------------------------------------
# WOLLMAN RINK: pista (concreto: o gelo derreteu faz tempo), muretas e o prédio
# ---------------------------------------------------------------------------------------------------------------
func _wollman() -> void:
	var hx := 40.0
	var hz := 20.0
	var rr := 12.0
	_b("concreto", Vector3(0, 0.08, 0), Vector3(hx * 2.0 - rr * 2.0, 0.16, hz * 2.0), Color(0.62, 0.66, 0.68))
	_b("concreto", Vector3(0, 0.08, 0), Vector3(hx * 2.0, 0.16, hz * 2.0 - rr * 2.0), Color(0.62, 0.66, 0.68))
	for s: float in [-1.0, 1.0]:
		for t: float in [-1.0, 1.0]:
			_cil("concreto", Vector3(s * (hx - rr), 0.08, t * (hz - rr)), rr, 0.16, 12, Color(0.62, 0.66, 0.68))
	# muretas (brancas com a faixa azul em cima)
	var contorno: Array = []
	for k in 48:
		var a := k * TAU / 48.0
		var cx := (hx - rr) * signf(cos(a)) if absf(cos(a)) > 0.001 else 0.0
		var cz := (hz - rr) * signf(sin(a)) if absf(sin(a)) > 0.001 else 0.0
		contorno.append(Vector2(cx + cos(a) * rr, cz + sin(a) * rr))
	for k in contorno.size():
		var p0: Vector2 = contorno[k]
		var p1: Vector2 = contorno[(k + 1) % contorno.size()]
		var m := (p0 + p1) * 0.5
		var bb := Basis(Vector3.UP, atan2(-(p1 - p0).y, (p1 - p0).x))
		var l := p0.distance_to(p1) + 0.1
		if k == 12:
			continue                                     # a entrada
		_b("concreto", Vector3(m.x, 0.6, m.y), Vector3(l, 1.0, 0.12), Color(0.9, 0.9, 0.88), bb)
		_b("concreto", Vector3(m.x, 1.13, m.y), Vector3(l, 0.08, 0.2), Color(0.2, 0.35, 0.65), bb)
		_col(Vector3(m.x, 0.6, m.y), Vector3(l, 1.2, 0.2), bb)
	# o prédio da pista (sul: +Z)
	_bc("tijolo_parede", Vector3(0, 3.0, hz + 9.0), Vector3(36.0, 6.0, 9.0), Color(0.62, 0.55, 0.48))
	for k in 8:
		_b("vidro_escuro", Vector3(-14.0 + k * 4.0, 2.2, hz + 4.48), Vector3(3.0, 2.4, 0.08), Color(0.1, 0.13, 0.15))
	_b("concreto", Vector3(0, 6.1, hz + 9.0), Vector3(37.0, 0.25, 10.0), Color(0.5, 0.5, 0.5))
	var lb := Label3D.new()
	lb.text = "WOLLMAN RINK"
	lb.font_size = 128
	lb.pixel_size = 0.014
	lb.modulate = Color(0.85, 0.15, 0.15)
	lb.position = T * Vector3(0, 4.8, hz + 4.4)
	lb.rotation.y = T.basis.get_euler().y + PI
	parque.visuais.append(lb)

# ---------------------------------------------------------------------------------------------------------------
# CARROUSEL: casa octogonal de tijolo com aberturas em arco e o carrossel dentro
# ---------------------------------------------------------------------------------------------------------------
func _carrossel() -> void:
	var rr := 12.0
	for k in 8:
		var a0 := k * TAU / 8.0
		var a1 := (k + 1) * TAU / 8.0
		var p0 := Vector2(cos(a0), sin(a0)) * rr
		var p1 := Vector2(cos(a1), sin(a1)) * rr
		var d := p1 - p0
		var bb := Basis(Vector3.UP, atan2(-d.y, d.x))
		var l := d.length()
		# pilares nos cantos e a parede de cima (verga) por cima da abertura
		_bc("tijolo_parede", Vector3(p0.x, 2.4, p0.y), Vector3(1.6, 4.8, 1.6), TIJOLO)
		var m := (p0 + p1) * 0.5
		_b("tijolo_parede", Vector3(m.x, 4.0, m.y), Vector3(l - 1.4, 1.6, 0.6), TIJOLO * 1.05, bb)
		if k % 2 == 1:
			_bc("tijolo_parede", Vector3(m.x, 1.6, m.y), Vector3(l - 1.4, 3.2, 0.5), TIJOLO * 0.95, bb)
	_cil("telhado", Vector3(0, 6.1, 0), rr + 1.2, 2.6, 8, Color(0.3, 0.3, 0.32), Basis(Vector3.UP, PI / 8.0), 5.0)
	_cil("pedra", Vector3(0, 8.1, 0), 3.0, 1.4, 8, PEDRA_CLARA, Basis(Vector3.UP, PI / 8.0))
	_cil("telhado", Vector3(0, 9.4, 0), 3.4, 1.4, 8, Color(0.3, 0.3, 0.32), Basis(Vector3.UP, PI / 8.0), 0.1)
	# o carrossel: plataforma, coluna do meio e os cavalinhos
	_cil("madeira", Vector3(0, 0.25, 0), 8.5, 0.5, 20, Color(0.55, 0.15, 0.12))
	_col(Vector3(0, 0.25, 0), Vector3(12.0, 0.5, 12.0))
	_cil("madeira", Vector3(0, 2.5, 0), 1.3, 4.0, 12, Color(0.85, 0.75, 0.5))
	_col(Vector3(0, 2.5, 0), Vector3(2.4, 4.0, 2.4))
	_cil("madeira", Vector3(0, 4.3, 0), 8.6, 0.4, 20, Color(0.75, 0.2, 0.15))
	for k in 16:
		var a := k * TAU / 16.0
		var rd := 6.8 if k % 2 == 0 else 5.0
		var p := Vector3(cos(a) * rd, 0.5, sin(a) * rd)
		_cil("ferro", p + Vector3(0, 1.9, 0), 0.04, 3.8, 5, Color(0.85, 0.7, 0.3))
		var cor: Color = [Color(0.92, 0.9, 0.85), Color(0.4, 0.25, 0.15), Color(0.15, 0.13, 0.12), Color(0.8, 0.75, 0.6)][k % 4]
		_cavalo(p + Vector3(0, 1.2, 0), -a, cor)

func _cavalo(p: Vector3, giro: float, cor: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	_b("madeira", p, Vector3(0.35, 0.45, 1.3), cor, b)
	_b("madeira", p + b * Vector3(0, 0.4, 0.62), Vector3(0.25, 0.6, 0.3), cor, b * Basis(Vector3.RIGHT, -0.5))
	_b("madeira", p + b * Vector3(0, 0.7, 0.85), Vector3(0.22, 0.25, 0.5), cor, b)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_b("madeira", p + b * Vector3(sx * 0.12, -0.45, sz * 0.5), Vector3(0.08, 0.6, 0.08), cor * 0.9, b * Basis(Vector3.RIGHT, sz * 0.35))
	_b("madeira", p + b * Vector3(0, 0.27, -0.1), Vector3(0.38, 0.1, 0.4), Color(0.6, 0.12, 0.12), b)

# ---------------------------------------------------------------------------------------------------------------
# STRAWBERRY FIELDS: o mosaico "IMAGINE" (preto e branco, raios) com flores deixadas
# ---------------------------------------------------------------------------------------------------------------
const SHADER_MOSAICO := """
shader_type spatial;
global uniform float molhado;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);
	float raio = step(0.5, fract(a / 6.2831 * 24.0 + 0.25 * step(0.6, r)));
	float aneis = step(0.92, r) * step(r, 1.0) + step(0.33, r) * step(r, 0.36);
	float c = mix(raio, 1.0, step(r, 0.33));
	c = mix(c, 0.0, aneis);
	vec2 g = fract(UV * 90.0);
	float junta = step(0.85, max(g.x, g.y));
	vec3 cor = mix(vec3(0.12), vec3(0.86, 0.85, 0.8), c) * (1.0 - junta * 0.25);
	ALBEDO = cor * mix(1.0, 0.75, molhado);
	ROUGHNESS = mix(0.7, 0.3, molhado);
	if (r > 1.0) discard;
}
"""

func _imagine() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8.6, 8.6)
	var m := ShaderMaterial.new()
	m.shader = Mat_shader(SHADER_MOSAICO)
	pm.material = m
	mi.mesh = pm
	mi.position = T * Vector3(0, 0.1, 0)
	mi.visibility_range_end = 200.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parque.visuais.append(mi)
	var lb := Label3D.new()
	lb.text = "IMAGINE"
	lb.font_size = 64
	lb.pixel_size = 0.012
	lb.modulate = Color(0.12, 0.12, 0.12)
	lb.position = T * Vector3(0, 0.12, 0)
	lb.rotation = Vector3(-PI * 0.5, 0, 0)
	lb.double_sided = false
	parque.visuais.append(lb)
	for k in 14:
		var a := r.randf() * TAU
		var d := r.randf_range(2.8, 4.0)
		var cor: Color = [Color(0.8, 0.1, 0.12), Color(0.95, 0.85, 0.2), Color(0.95, 0.95, 0.9), Color(0.7, 0.3, 0.6)][k % 4] * 0.6
		cor.a = 1.0
		_b("madeira", Vector3(cos(a) * d, 0.15, sin(a) * d), Vector3(0.25, 0.08, 0.12), cor, Basis(Vector3.UP, r.randf() * TAU))

static func Mat_shader(codigo: String) -> Shader:
	return preload("res://mundo/materiais_cidade.gd").shader(codigo)

# ---------------------------------------------------------------------------------------------------------------
# DELACORTE THEATER: arquibancada em meia-lua de madeira em volta do palco (o palco em z 0, a plateia em -Z)
# ---------------------------------------------------------------------------------------------------------------
func _delacorte() -> void:
	_bc("madeira", Vector3(0, 0.5, 2.0), Vector3(14.0, 1.0, 8.0), MADEIRA * 0.8)
	for fila in 9:
		var raio := 10.0 + fila * 1.9
		var y := 0.2 + fila * 0.45
		var n := 10 + fila
		for k in n:
			var a0 := PI + PI * 0.12 + (PI * 0.76) * k / n
			var a1 := PI + PI * 0.12 + (PI * 0.76) * (k + 1) / n
			var am := (a0 + a1) * 0.5
			var p := Vector3(cos(am) * raio, y, sin(am) * raio)
			var corda := 2.0 * raio * sin((a1 - a0) * 0.5) + 0.05
			var bb := Basis(Vector3.UP, -am + PI * 0.5)
			_b("madeira", p, Vector3(corda, y * 2.0 if fila == 0 else 0.9, 1.9), MADEIRA * (0.9 if fila % 2 == 0 else 1.0), bb)
			if k % 2 == 0:
				_col(Vector3(p.x, y * 0.5, p.z), Vector3(corda * 2.0, y + 0.45, 1.9), bb)
	for s: float in [-1.0, 1.0]:
		var p := Vector3(s * 11.0, 0, 7.0)
		_cil("ferro", p + Vector3(0, 6.0, 0), 0.25, 12.0, 6, FERRO)
		_b("ferro", p + Vector3(0, 11.5, 0), Vector3(2.4, 1.0, 0.8), FERRO)
		_col(p + Vector3(0, 6.0, 0), Vector3(0.5, 12.0, 0.5))

# ---------------------------------------------------------------------------------------------------------------
# KERBS BOATHOUSE (Conservatory Water), ALICE NO PAÍS DAS MARAVILHAS, FONTE DO CHERRY HILL, ESTÁTUAS, BEISEBOL
# ---------------------------------------------------------------------------------------------------------------
func _kerbs() -> void:
	_bc("tijolo_parede", Vector3(0, 2.2, 0), Vector3(14.0, 4.4, 7.0), TIJOLO_CLARO * 0.95)
	for k in 4:
		_janela_gotica(Vector3(-4.5 + k * 3.0, 2.0, 3.53), 0.0)
	for s: float in [-1.0, 1.0]:
		_b("telhado", Vector3(0, 5.0, s * 2.2), Vector3(15.0, 0.22, 5.2), TELHADO_VERDE, Basis(Vector3.RIGHT, s * 0.4))

func _alice() -> void:
	_bc("granito", Vector3(0, 0.3, 0), Vector3(5.0, 0.6, 5.0), GRANITO)
	for e in [[Vector3(0, 0.6, 0), 2.2, 1.6], [Vector3(1.4, 0.6, 0.6), 1.2, 1.0], [Vector3(-1.3, 0.6, 0.8), 1.0, 0.8]]:
		var p: Vector3 = e[0]
		_cil("bronze", p + Vector3(0, float(e[1]) * 0.5, 0), 0.3, float(e[1]), 8, BRONZE * 1.4)
		_cil("bronze", p + Vector3(0, float(e[1]) + 0.12, 0), float(e[2]), 0.25, 12, BRONZE * 1.5, Basis.IDENTITY, float(e[2]) * 0.5)
	_figura("bronze", Vector3(0, 3.0, 0), 1.3, BRONZE * 1.7, 0.0)                         # a Alice (polida pelas mãos)
	_figura("bronze", Vector3(1.4, 1.95, 0.6), 0.9, BRONZE * 1.3, 0.6)                     # o Chapeleiro
	_b("bronze", Vector3(1.4, 2.95, 0.6), Vector3(0.35, 0.35, 0.35), BRONZE)
	_figura("bronze", Vector3(-1.3, 1.55, 0.8), 0.7, BRONZE * 1.3, -0.5, false)            # o Coelho
	_col(Vector3(0, 1.8, 0), Vector3(4.0, 3.6, 3.0))

func _cherry_fonte() -> void:
	_cil("pedra", Vector3(0, 0.3, 0), 2.8, 0.6, 8, PEDRA, Basis(Vector3.UP, PI / 8.0))
	_cil("agua_fonte", Vector3(0, 0.55, 0), 2.4, 0.04, 8, Color(1, 1, 1), Basis(Vector3.UP, PI / 8.0))
	_cil("pedra", Vector3(0, 1.6, 0), 0.4, 2.6, 8, PEDRA_CLARA)
	_cil("bronze", Vector3(0, 2.4, 0), 0.9, 0.25, 10, Color(0.65, 0.55, 0.25), Basis.IDENTITY, 0.4)
	_cil("ferro", Vector3(0, 3.6, 0), 0.06, 2.0, 6, FERRO)
	_cil("vidro", Vector3(0, 4.75, 0), 0.25, 0.5, 8, Color(1.0, 0.9, 0.7))
	_col(Vector3(0, 0.4, 0), Vector3(5.2, 0.8, 5.2))

func _estatua(quem: String) -> void:
	_bc("granito", Vector3(0, 1.3, 0), Vector3(2.0, 2.6, 2.0), GRANITO * 0.9)
	_b("granito", Vector3(0, 2.7, 0), Vector3(2.4, 0.25, 2.4), GRANITO)
	_b("granito", Vector3(0, 0.15, 0), Vector3(2.6, 0.3, 2.6), GRANITO * 0.85)
	if quem in ["burns", "scott"]:
		_b("bronze", Vector3(0, 3.25, 0), Vector3(0.9, 0.8, 0.9), BRONZE_ESCURO)                     # cadeira/rocha
		_figura("bronze", Vector3(0, 3.0, -0.1), 1.5, BRONZE_ESCURO, 0.0, true)
	else:
		_figura("bronze", Vector3(0, 2.83, 0), 2.1, BRONZE_ESCURO, 0.0, quem == "shakespeare")
		if quem == "colombo":
			_cil("bronze", Vector3(0.3, 4.3, 0.2), 0.25, 0.5, 8, BRONZE_ESCURO)                       # o globo

func _beisebol() -> void:
	# o "diamante" de terra (leque a partir da base principal, para +Z) e as bases
	var terra := Color(0.55, 0.42, 0.3)
	var c := _c("concreto")
	var n := 12
	for k in n:
		var a0 := PI * 0.25 + PI * 0.5 * k / n
		var a1 := PI * 0.25 + PI * 0.5 * (k + 1) / n
		var p0 := Vector3(cos(a0) * 29.0, 0.07, sin(a0) * 29.0)
		var p1 := Vector3(cos(a1) * 29.0, 0.07, sin(a1) * 29.0)
		c._quad(Vector3(0, 0.07, 0), p0, p1, Vector3(0, 0.07, 0), Vector3.UP, terra, Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_cil("concreto", Vector3(0, 0.12, 18.4), 2.7, 0.25, 12, terra * 1.05)
	for p: Vector3 in [Vector3(0, 0.12, 0), Vector3(19.4, 0.12, 19.4), Vector3(0, 0.12, 27.4), Vector3(-19.4, 0.12, 19.4)]:
		_b("concreto", p, Vector3(0.45, 0.08, 0.45), Color(0.95, 0.95, 0.92))
	# o alambrado atrás da base principal (tela) e os bancos
	for k in 7:
		var a0 := PI + PI * 0.15 + PI * 0.7 * k / 7.0
		var a1 := PI + PI * 0.15 + PI * 0.7 * (k + 1) / 7.0
		var p0 := Vector2(cos(a0), sin(a0)) * 14.0
		var p1 := Vector2(cos(a1), sin(a1)) * 14.0
		var m := (p0 + p1) * 0.5
		var bb := Basis(Vector3.UP, atan2(-(p1 - p0).y, (p1 - p0).x))
		var l := p0.distance_to(p1)
		_b("tela", Vector3(m.x, 2.4, m.y), Vector3(l, 4.8, 0.03), Color(1, 1, 1), bb)
		_cil("ferro", Vector3(p0.x, 2.5, p0.y), 0.06, 5.0, 6, Color(0.4, 0.42, 0.42))
		_col(Vector3(m.x, 2.4, m.y), Vector3(l, 4.8, 0.1), bb)
	for s: float in [-1.0, 1.0]:
		var p := Vector3(s * 9.0, 0, -3.0)
		_b("madeira", p + Vector3(0, 0.45, 0), Vector3(6.0, 0.08, 0.5), MADEIRA, Basis(Vector3.UP, s * 0.8))
		_b("ferro", p + Vector3(0, 0.22, 0), Vector3(5.6, 0.44, 0.1), Color(0.35, 0.37, 0.37), Basis(Vector3.UP, s * 0.8))
