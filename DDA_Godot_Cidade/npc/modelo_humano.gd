extends Node3D
# BONECO DE UM SOBREVIVENTE (Greg, Mavie e outros personagens): feito de caixas, com pivôs nas juntas e
# animação por código: parado (respirando), andar, correr, golpe com a arma da mão, levar golpe, caído no chão.
# Frente = -Z (igual ao jogador). Altura ~1,78 m. Cada parte é uma malha (Malhas.Construtor), um material só.
# Mexa AQUI para: aparência (roupa, cabelo, pele) em VISUAIS e as poses/animações.

const Malhas := preload("res://mundo/malhas.gd")
const ModelosArmas := preload("res://armas/modelos_armas.gd")

const ALT_QUADRIL := 0.96
# aparência de cada personagem: pele, cabelo, camisa, calça, sapato, jaqueta (ou null), cabelo comprido, atadura
const VISUAIS := {
	# Bíblia da Lore: negro, dreads curtos, bigode e cavanhaque, tatuagens no pescoço, corrente de ouro grossa,
	# jaqueta preta college com "TF" no peito, moletom escuro, calça cargo preta, luvas, botas verde-oliva
	"greg": {"pele": Color(0.36, 0.24, 0.17), "cabelo": Color(0.06, 0.05, 0.04), "camisa": Color(0.12, 0.12, 0.13),
		"calca": Color(0.08, 0.08, 0.09), "sapato": Color(0.3, 0.32, 0.2), "jaqueta": Color(0.06, 0.06, 0.07),
		"comprido": false, "barba": true, "atadura": false, "largura": 1.06, "dreads": true, "corrente": true,
		"tatuagem": true, "tf": true, "luvas": Color(0.08, 0.08, 0.08)},
	# Bíblia da Lore: cabelo branco em tranças finas no topo, laterais raspadas, pele muito clara, óculos de aviador,
	# tatuagens no pescoço, jaqueta de couro preta, camiseta branca, calça preta, botas pretas
	"dominic": {"pele": Color(0.93, 0.85, 0.8), "cabelo": Color(0.95, 0.95, 0.93), "camisa": Color(0.88, 0.88, 0.86),
		"calca": Color(0.08, 0.08, 0.09), "sapato": Color(0.05, 0.05, 0.05), "jaqueta": Color(0.07, 0.07, 0.08),
		"comprido": false, "barba": false, "atadura": false, "largura": 1.02, "oculos": true, "trancas": true,
		"tatuagem": true},
	"garoto": {"pele": Color(0.7, 0.52, 0.4), "cabelo": Color(0.12, 0.09, 0.06), "camisa": Color(0.85, 0.55, 0.15),
		"calca": Color(0.25, 0.25, 0.27), "sapato": Color(0.9, 0.9, 0.9), "jaqueta": null,
		"comprido": false, "barba": false, "atadura": false, "largura": 0.85},
	"bartender": {"pele": Color(0.75, 0.6, 0.5), "cabelo": Color(0.3, 0.3, 0.3), "camisa": Color(0.9, 0.9, 0.9),
		"calca": Color(0.1, 0.1, 0.1), "sapato": Color(0.1, 0.1, 0.1), "jaqueta": Color(0.1, 0.1, 0.12),
		"comprido": false, "barba": true, "atadura": false, "largura": 1.1},
	# referência do autor (lore/Mavie_referencia.png): gorro preto, cabelo escuro comprido e liso, moletom escuro
	# gasto com bolso canguru, atadura no antebraço, mochila com bolso de primeiros socorros, calça escura
	"mavie": {"pele": Color(0.88, 0.76, 0.68), "cabelo": Color(0.09, 0.07, 0.06), "camisa": Color(0.16, 0.15, 0.14),
		"calca": Color(0.14, 0.14, 0.15), "sapato": Color(0.12, 0.11, 0.1), "jaqueta": null,
		"comprido": true, "barba": false, "atadura": true, "largura": 0.92, "gorro": Color(0.1, 0.1, 0.11),
		"mochila": Color(0.25, 0.22, 0.17), "moletom": true},
}

var corpo: Node3D               # gira inteiro ao cair (pivô nos pés)
var quadril: Node3D
var tronco: Node3D
var cabeca: Node3D
var ombro: Array[Node3D] = []
var cotovelo: Array[Node3D] = []
var coxa: Array[Node3D] = []
var joelho: Array[Node3D] = []
var arma: Node3D = null
var caido := false
var pose := ""                   # "" (anda/para) · "sentado" · "acenar" · "abraco" · "dirigindo" · "segurar_luz"
var escala := 1.0

static var _mat: StandardMaterial3D = null
var _t := 0.0
var _ph := 0.0
var _mv := 0.0
var _corr := 0.0
var _golpe := -1.0               # -1 = sem golpe · 0..DUR_GOLPE
var _fl := 0.0
var _queda := 0.0
const DUR_GOLPE := 0.55

func montar(quem: String, tipo_arma: String) -> void:
	if _mat == null:
		_mat = Malhas.mat_cores(0.9)
	var v: Dictionary = VISUAIS.get(quem, VISUAIS["greg"])
	var L: float = v["largura"]
	corpo = _pivo(self, Vector3.ZERO)
	quadril = _pivo(corpo, Vector3(0, ALT_QUADRIL, 0))
	tronco = _pivo(quadril, Vector3.ZERO)
	var c := Malhas.Construtor.new()
	var jaq = v["jaqueta"]
	var roupa: Color = jaq if jaq != null else v["camisa"]
	c.caixa(Vector3(0, 0.3, 0), Vector3(0.42 * L, 0.6, 0.24), roupa)
	if jaq != null:
		c.caixa(Vector3(0, 0.3, -0.122), Vector3(0.16, 0.56, 0.01), v["camisa"])        # camisa aparecendo na frente
	c.caixa(Vector3(0, -0.02, 0), Vector3(0.38 * L, 0.12, 0.22), v["calca"])
	if v.get("moletom", false):
		c.caixa(Vector3(0, 0.12, -0.125), Vector3(0.26, 0.14, 0.02), v["camisa"].darkened(0.25))         # bolso canguru
		c.caixa(Vector3(0, 0.58, 0.1), Vector3(0.3, 0.1, 0.08), v["camisa"].darkened(0.15))              # capuz nas costas
		for x in [-0.04, 0.04]:
			c.caixa(Vector3(x, 0.45, -0.125), Vector3(0.012, 0.12, 0.01), Color(0.6, 0.6, 0.58))         # cordões
	if v.has("mochila"):
		var mo: Color = v["mochila"]
		c.caixa(Vector3(0, 0.3, 0.22), Vector3(0.32, 0.42, 0.18), mo)
		c.caixa(Vector3(0.1, 0.24, 0.32), Vector3(0.12, 0.14, 0.04), mo.darkened(0.15))                 # bolso de primeiros socorros
		c.caixa(Vector3(0.1, 0.24, 0.343), Vector3(0.05, 0.015, 0.005), Color(0.15, 0.12, 0.1))
		c.caixa(Vector3(0.1, 0.24, 0.343), Vector3(0.015, 0.05, 0.005), Color(0.15, 0.12, 0.1))
		for x in [-0.1, 0.1]:
			c.caixa(Vector3(x, 0.38, -0.125), Vector3(0.04, 0.3, 0.012), mo.darkened(0.3))                # alças
	if v.get("corrente", false):
		c.caixa(Vector3(0, 0.5, -0.125), Vector3(0.16, 0.03, 0.02), Color(0.85, 0.68, 0.2))
		c.caixa(Vector3(0, 0.44, -0.125), Vector3(0.05, 0.08, 0.02), Color(0.85, 0.68, 0.2))
	if v.get("tf", false):
		c.caixa(Vector3(-0.11, 0.42, -0.124), Vector3(0.08, 0.06, 0.01), Color(0.8, 0.75, 0.6))   # emblema "TF"
	_parte(tronco, c)
	cabeca = _pivo(tronco, Vector3(0, 0.62, 0))
	c = Malhas.Construtor.new()
	c.caixa(Vector3(0, 0.03, 0), Vector3(0.1, 0.08, 0.1), v["pele"])                     # pescoço
	c.caixa(Vector3(0, 0.17, 0), Vector3(0.2, 0.24, 0.22), v["pele"])
	if v.get("trancas", false):
		# laterais raspadas (só a pele) e tranças finas no topo, puxadas para trás
		for k in 5:
			c.caixa(Vector3(-0.08 + k * 0.04, 0.305, 0.02), Vector3(0.025, 0.035, 0.24), v["cabelo"])
		c.caixa(Vector3(0, 0.27, 0.15), Vector3(0.12, 0.12, 0.05), v["cabelo"])
	elif v.get("dreads", false):
		c.caixa(Vector3(0, 0.3, 0.01), Vector3(0.22, 0.05, 0.24), v["cabelo"])
		for k in 9:
			var a := TAU * k / 9.0
			c.caixa(Vector3(sin(a) * 0.11, 0.27, cos(a) * 0.11 + 0.01), Vector3(0.04, 0.1, 0.04), v["cabelo"])
	else:
		c.caixa(Vector3(0, 0.3, 0.01), Vector3(0.22, 0.06, 0.24), v["cabelo"])
		c.caixa(Vector3(0, 0.2, 0.1), Vector3(0.22, 0.16, 0.05), v["cabelo"])           # nuca
	if v.get("tatuagem", false):
		c.caixa(Vector3(0.045, 0.03, -0.045), Vector3(0.03, 0.06, 0.02), Color(0.15, 0.17, 0.22))
	if v.has("gorro"):
		c.caixa(Vector3(0, 0.31, 0.01), Vector3(0.24, 0.1, 0.25), v["gorro"])
		c.caixa(Vector3(0, 0.27, -0.002), Vector3(0.245, 0.05, 0.255), v["gorro"].lightened(0.08))       # barra dobrada
		c.caixa(Vector3(0, 0.27, -0.13), Vector3(0.12, 0.025, 0.005), Color(0.75, 0.72, 0.6))           # bordado na frente
	if v["comprido"]:
		c.caixa(Vector3(0, 0.05, 0.12), Vector3(0.24, 0.34, 0.06), v["cabelo"])
	if v["barba"]:
		c.caixa(Vector3(0, 0.09, -0.1), Vector3(0.19, 0.08, 0.04), v["cabelo"].lightened(0.1))
	for s in [-1.0, 1.0]:
		c.caixa(Vector3(s * 0.05, 0.19, -0.112), Vector3(0.035, 0.02, 0.01), Color(0.08, 0.08, 0.1))  # olhos
	if v.get("oculos", false):
		c.caixa(Vector3(0, 0.19, -0.118), Vector3(0.21, 0.055, 0.02), Color(0.04, 0.04, 0.05))      # óculos de aviador
		c.caixa(Vector3(0, 0.215, -0.12), Vector3(0.21, 0.012, 0.022), Color(0.7, 0.6, 0.3))
	_parte(cabeca, c)
	for lado in 2:
		var s := -1.0 if lado == 0 else 1.0
		var o := _pivo(tronco, Vector3(s * 0.25 * L, 0.52, 0))
		c = Malhas.Construtor.new()
		c.caixa(Vector3(0, -0.14, 0), Vector3(0.11, 0.3, 0.11), roupa)
		_parte(o, c)
		var cv := _pivo(o, Vector3(0, -0.29, 0))
		c = Malhas.Construtor.new()
		c.caixa(Vector3(0, -0.12, 0), Vector3(0.1, 0.24, 0.1), roupa)
		c.caixa(Vector3(0, -0.28, 0), Vector3(0.08, 0.09, 0.09), v.get("luvas", v["pele"]))
		if v["atadura"] and lado == 0:
			c.caixa(Vector3(0, -0.17, 0), Vector3(0.115, 0.08, 0.115), Color(0.92, 0.9, 0.86))
		_parte(cv, c)
		ombro.append(o)
		cotovelo.append(cv)
		var cx := _pivo(quadril, Vector3(s * 0.1, -0.03, 0))
		c = Malhas.Construtor.new()
		c.caixa(Vector3(0, -0.21, 0), Vector3(0.14, 0.44, 0.15), v["calca"])
		_parte(cx, c)
		var jo := _pivo(cx, Vector3(0, -0.44, 0))
		c = Malhas.Construtor.new()
		c.caixa(Vector3(0, -0.2, 0), Vector3(0.12, 0.42, 0.13), v["calca"])
		c.caixa(Vector3(0, -0.45, -0.04), Vector3(0.12, 0.08, 0.24), v["sapato"])
		_parte(jo, c)
		coxa.append(cx)
		joelho.append(jo)
	if tipo_arma != "":
		arma = ModelosArmas.construir(tipo_arma)
		var cano := arma.get_node_or_null("Cano")
		if cano != null:
			cano.free()
		arma.position = Vector3(0, -0.3, 0)
		arma.rotation = Vector3(-PI * 0.5, PI, 0)          # cabo na mão, ponta para cima
		cotovelo[1].add_child(arma)
	atualizar(0.0, 0.0)

func _pivo(pai: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	pai.add_child(n)
	return n

func _parte(pai: Node3D, c) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = c.malha(_mat)
	mi.visibility_range_end = 160.0
	pai.add_child(mi)

func golpear() -> void:
	_golpe = 0.0

func levar_golpe() -> void:
	_fl = 1.0

func pos_cabeca() -> Vector3:
	return cabeca.global_transform * Vector3(0, 0.17, 0)

# vel = velocidade horizontal (m/s)
func atualizar(dt: float, vel: float) -> void:
	_t += dt
	_queda = move_toward(_queda, 1.0 if caido else 0.0, dt * 2.5)
	_corr = lerpf(_corr, clampf((vel - 2.5) / 2.5, 0.0, 1.0), minf(1.0, dt * 6.0))
	_mv = lerpf(_mv, clampf(vel / 1.2, 0.0, 1.0), minf(1.0, dt * 6.0))
	_ph += dt * TAU * clampf(0.6 + vel * 0.2, 0.6, 2.0) * (1.0 if vel > 0.15 else 0.0)
	_fl = maxf(0.0, _fl - dt * 4.0)
	var amp := lerpf(0.45, 0.85, _corr) * _mv
	for i in 2:
		var s := sin(_ph + (PI if i == 1 else 0.0))
		var cs := cos(_ph + (PI if i == 1 else 0.0))
		coxa[i].rotation.x = s * amp
		joelho[i].rotation.x = -maxf(0.0, -cs) * (0.4 + 0.9 * _corr) * _mv
		ombro[i].rotation = Vector3(-s * amp * 0.8 - 0.25 * _corr, 0.0, (0.08 if i == 1 else -0.08))
		cotovelo[i].rotation.x = -(0.25 + 0.9 * _corr)
	quadril.position.y = ALT_QUADRIL - absf(sin(_ph)) * 0.04 * _mv
	tronco.rotation.x = -0.18 * _corr - 0.12 * _fl
	tronco.rotation.y = sin(_ph) * 0.12 * _mv
	cabeca.rotation.x = 0.1 * _corr + sin(_t * 1.3) * 0.02
	# a mão da arma fica mais levantada, pronta
	if arma != null:
		ombro[1].rotation.x += -0.35
		cotovelo[1].rotation.x = -1.1
	# golpe: levanta por cima do ombro e desce na frente
	if _golpe >= 0.0:
		_golpe += dt
		var f := _golpe / DUR_GOLPE
		var ang: float
		if f < 0.4:
			ang = lerpf(-0.6, -2.7, f / 0.4)
		elif f < 0.7:
			ang = lerpf(-2.7, -0.3, (f - 0.4) / 0.3)
		else:
			ang = lerpf(-0.3, -0.6, (f - 0.7) / 0.3)
		ombro[1].rotation = Vector3(ang, 0.0, 0.2)
		cotovelo[1].rotation.x = -0.3
		ombro[0].rotation = Vector3(-0.9, 0.0, -0.3)
		cotovelo[0].rotation.x = -1.4
		tronco.rotation.y = lerpf(0.35, -0.3, clampf((f - 0.35) / 0.4, 0.0, 1.0))
		if _golpe >= DUR_GOLPE:
			_golpe = -1.0
	_poses()
	# caído: deita de costas (pivô nos pés)
	corpo.rotation.x = -_queda * PI * 0.5
	corpo.position.y = _queda * 0.12

# poses fixas das cutscenes (por cima da animação de andar)
func _poses() -> void:
	match pose:
		"sentado", "dirigindo":
			for i in 2:
				coxa[i].rotation.x = -1.45
				joelho[i].rotation.x = 1.45
			quadril.position.y = 0.5
			tronco.rotation.x = 0.05
			if pose == "dirigindo":
				for i in 2:
					ombro[i].rotation = Vector3(-1.1, 0.0, 0.0)
					cotovelo[i].rotation.x = -0.6
			else:
				ombro[0].rotation = Vector3(-0.6, 0.0, -0.1)
				cotovelo[0].rotation.x = -1.2
		"acenar":
			ombro[0].rotation = Vector3(0.0, 0.0, -2.6 + sin(_t * 9.0) * 0.25)
			cotovelo[0].rotation.x = -0.4
		"abraco":
			for i in 2:
				ombro[i].rotation = Vector3(-1.35, 0.0, (0.55 if i == 0 else -0.55))
				cotovelo[i].rotation.x = -1.0
		"segurar_luz":
			ombro[1].rotation = Vector3(0.0, 0.0, 2.9)
			cotovelo[1].rotation.x = 0.0
