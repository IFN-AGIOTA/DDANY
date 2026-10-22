extends Node
# EVENTOS DINÂMICOS (0.65, estilo DayZ): lugares especiais que aparecem pela cidade, a 0,4–1,6 km de você, e
# trocam de lugar com o tempo (um evento longe e velho some e nasce outro do mesmo tipo em outro lugar):
#   · HELICÓPTERO CAÍDO ... destroços pegando fogo com uma COLUNA DE FUMAÇA que se vê de longe; 2 caixas e itens
#                           no chão com LOOT MILITAR (tabela "militar" de mundo/loot_mundo.gd). Infectados em volta.
#                           Com o RÁDIO ligado você ouve quando um cai (e a direção).
#   · COMBOIO DESTRUÍDO ... 3 a 4 veículos militares queimados parados numa rua, cada um com um compartimento para
#                           saquear (militar + carro). Alguns infectados.
#   · ZONA CONTAMINADA .... névoa verde de GÁS TÓXICO (raio 35–60 m). Sem MÁSCARA DE GÁS (slot ROSTO) você perde vida
#                           e tosse (jogador/sobrevivencia.gd gas); com a máscara, o filtro gasta. No meio, uma caixa
#                           da QUARENTENA com loot militar. Ao chegar perto aparece o aviso.
# Não vão no jogo salvo (ao carregar, nascem de novo). Cada jogador da partida tem os seus.
# Mexa AQUI para: quantos de cada, distâncias, raio do gás, quantidade de loot e de infectados.

const CaixaMundoCls := preload("res://inventario/caixa_mundo.gd")
const ItemMundo := preload("res://inventario/item_mundo.gd")
const Sons := preload("res://audio/sons.gd")

const QUANTOS := {"heli": 1, "comboio": 1, "gas": 2}
const DIST := Vector2(400.0, 1600.0)       # de você até onde nasce
const LONGE_SOME := 2600.0                 # mais longe que isso (e com mais de VIDA_MIN) troca de lugar
const VIDA_MIN := 1800.0                   # segundos
const PERTO_HORDA := 120.0
const RAIO_GAS := Vector2(35.0, 60.0)
const DIRECOES := ["NORTE", "NORDESTE", "LESTE", "SUDESTE", "SUL", "SUDOESTE", "OESTE", "NOROESTE"]

var main = null
var eventos: Array = []                    # {"tipo", "pos", "no", "t", "horda", "raio", "avisou"}
var _rng := RandomNumberGenerator.new()
var _t := 3.0
var _mats := {}

func ligar(m) -> void:
	main = m
	_rng.randomize()

func _process(dt: float) -> void:
	if main == null or main.jogador == null:
		return
	var j: Node3D = main.jogador
	var pj := j.global_position
	# gás: o quanto tem onde o jogador está (0..1)
	var gas := 0.0
	for e in eventos:
		e["t"] += dt
		var d := Vector2(pj.x - e["pos"].x, pj.z - e["pos"].z).length()
		if e["tipo"] == "gas":
			var r: float = e["raio"]
			if d < r:
				gas = maxf(gas, clampf((r - d) / (r * 0.25), 0.0, 1.0))
			if not e["avisou"] and d < r + 45.0:
				e["avisou"] = true
				_aviso("ZONA CONTAMINADA À FRENTE · USE MÁSCARA DE GÁS")
			elif e["avisou"] and d > r + 120.0:
				e["avisou"] = false
		if not e["horda"] and d < PERTO_HORDA:
			e["horda"] = true
			_soltar_horda(e)
	var sv = j.get("sobrevivencia")
	if sv != null:
		sv.gas = 0.0 if bool(j.get("morto")) else gas
	_t -= dt
	if _t > 0.0:
		return
	_t = 5.0
	# troca os eventos longe e velhos; completa o que falta de cada tipo
	for e in eventos.duplicate():
		var d := Vector2(pj.x - e["pos"].x, pj.z - e["pos"].z).length()
		if d > LONGE_SOME and e["t"] > VIDA_MIN:
			_tirar(e)
	for tipo in QUANTOS:
		var n := 0
		for e in eventos:
			if e["tipo"] == tipo:
				n += 1
		if n < int(QUANTOS[tipo]):
			_novo(tipo, pj)
			return                             # um por vez (não pesa num quadro só)

func _tirar(e: Dictionary) -> void:
	eventos.erase(e)
	if e["no"] != null and is_instance_valid(e["no"]):
		e["no"].queue_free()

# ---------- onde nasce ----------
func _ponto_na_rua(pj: Vector3) -> Vector2:
	var cid = main.cidade
	for tentativa in 300:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(DIST.x, DIST.y)
		var p := Vector2(pj.x + cos(a) * r, pj.z + sin(a) * r)
		var c := int((p.x + cid.WORLD.x) / cid.CELL)
		var l := int((p.y + cid.WORLD.y) / cid.CELL)
		if c < 1 or c >= cid.W - 1 or l < 1 or l >= cid.H - 1 or cid.road[l * cid.W + c] != 1:
			continue
		if main.mundo.dentro_de_predio(p.x, p.y, 4.0, true) or main.mundo.dentro_de_obstaculo(p.x, p.y, 3.0):
			continue
		var longe := true
		for e in eventos:
			if p.distance_to(Vector2(e["pos"].x, e["pos"].z)) < 300.0:
				longe = false
		if longe:
			return p
	return Vector2.INF

# a rua corre no eixo X (true) ou Z (false) neste ponto?
func _rua_em_x(p: Vector2) -> bool:
	var cid = main.cidade
	var c := int((p.x + cid.WORLD.x) / cid.CELL)
	var l := int((p.y + cid.WORLD.y) / cid.CELL)
	var nx := int(cid.road[l * cid.W + c - 1] == 1) + int(cid.road[l * cid.W + c + 1] == 1)
	var nz := int(cid.road[(l - 1) * cid.W + c] == 1) + int(cid.road[(l + 1) * cid.W + c] == 1)
	return nx >= nz

func _novo(tipo: String, pj: Vector3) -> void:
	var p := _ponto_na_rua(pj)
	if p == Vector2.INF:
		return
	var pos := Vector3(p.x, main.mundo.altura(p.x, p.y), p.y)
	var raiz := Node3D.new()
	raiz.name = "Evento_" + tipo
	main.jogo.add_child(raiz)
	raiz.global_position = pos
	var e := {"tipo": tipo, "pos": pos, "no": raiz, "t": 0.0, "horda": false, "raio": 0.0, "avisou": false}
	match tipo:
		"heli":
			_montar_heli(raiz)
			if main.jogador.inventario.radio_ligado():
				_aviso("RÁDIO: helicóptero militar caiu a %.1f km, %s" % [p.distance_to(Vector2(pj.x, pj.z)) / 1000.0, _direcao(pj, p)])
		"comboio":
			_montar_comboio(raiz, _rua_em_x(p))
		"gas":
			e["raio"] = _rng.randf_range(RAIO_GAS.x, RAIO_GAS.y)
			_montar_gas(raiz, e["raio"])
	eventos.append(e)

func _direcao(pj: Vector3, p: Vector2) -> String:
	var ang := fposmod(atan2(p.x - pj.x, -(p.y - pj.z)), TAU)       # 0 = norte (-Z)
	return DIRECOES[int(round(ang / (TAU / 8.0))) % 8]

# ---------- peças (feitas por código: caixas, cilindros) ----------
func _mat(cor: Color, emissao := 0.0) -> StandardMaterial3D:
	var k := "%s_%s" % [cor.to_html(), emissao]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 0.9
		if emissao > 0.0:
			m.emission_enabled = true
			m.emission = cor
			m.emission_energy_multiplier = emissao
		_mats[k] = m
	return _mats[k]

func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, rot: Vector3, cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = _mat(cor)
	pai.add_child(mi)
	mi.position = pos
	mi.rotation = rot
	return mi

func _cilindro(pai: Node3D, r: float, h: float, pos: Vector3, rot: Vector3, cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _mat(cor)
	pai.add_child(mi)
	mi.position = pos
	mi.rotation = rot
	return mi

func _solido(pai: Node3D, tam: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	corpo.add_child(cs)
	pai.add_child(corpo)
	corpo.position = pos
	corpo.rotation.y = rot_y

func _conteiner(pai: Node3D, nome: String, pos: Vector3, tabelas: Array, n: Vector2i, modelo := "caixa_militar", medidas := Vector3(1.2, 0.7, 0.6)) -> void:
	var c = CaixaMundoCls.new()
	c.nome = nome
	c.tamanho = Vector2i(8, 6)
	c.medidas = medidas
	c.modelo = modelo
	c.cor = Color(0.2, 0.22, 0.17)
	pai.add_child(c)
	c.position = pos
	c.rotation.y = _rng.randf() * TAU
	var loot = main.loot_mundo
	if loot == null:
		return
	for k in _rng.randi_range(n.x, n.y):
		var it = loot._sortear(tabelas[_rng.randi() % tabelas.size()], _rng, c.tamanho)
		if it != null:
			c.guardar(it)

func _fogo(pai: Node3D, pos: Vector3, grande: bool) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.55, 0.2)
	luz.omni_range = 14.0 if grande else 8.0
	luz.light_energy = 2.2
	pai.add_child(luz)
	luz.position = pos + Vector3(0, 1.2, 0)
	var tw := luz.create_tween().set_loops()
	tw.tween_property(luz, "light_energy", 1.2, 0.18)
	tw.tween_property(luz, "light_energy", 2.6, 0.22)
	var chamas := _particulas(pai, pos, 18 if grande else 10, 1.2, Color(1.0, 0.5, 0.12, 0.9), Vector2(0.6, 1.2), 1.5, 1.0, true)
	chamas.emission_sphere_radius = 0.8 if grande else 0.4
	# fumaça escura subindo (alta, para ver de longe)
	var fum := _particulas(pai, pos + Vector3(0, 1.5, 0), 26 if grande else 12, 9.0 if grande else 6.0, Color(0.12, 0.12, 0.12, 0.55),
		Vector2(2.5, 7.0) if grande else Vector2(1.5, 4.0), 4.0 if grande else 2.5, 0.6, false)
	fum.emission_sphere_radius = 1.0

func _particulas(pai: Node3D, pos: Vector3, n: int, vida: float, cor: Color, tam: Vector2, vel: float, espalhar: float, brilha: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = vida
	p.preprocess = vida
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	if brilha:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.direction = Vector3.UP
	p.spread = 12.0 * espalhar
	p.gravity = Vector3(0.4, 0.0, 0.0)
	p.initial_velocity_min = vel * 0.6
	p.initial_velocity_max = vel
	p.scale_amount_min = tam.x
	p.scale_amount_max = tam.y
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.4))
	curva.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curva
	var g := Gradient.new()
	g.set_color(0, cor)
	g.set_color(1, Color(cor.r, cor.g, cor.b, 0.0))
	p.color_ramp = g
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 80, 60))
	pai.add_child(p)
	p.position = pos
	return p

# HELICÓPTERO: fuselagem tombada, cauda partida, pás tortas, fogo e fumaça; 2 caixas e itens no chão
func _montar_heli(raiz: Node3D) -> void:
	var verde := Color(0.17, 0.2, 0.14)
	var queimado := Color(0.07, 0.07, 0.07)
	var h := Node3D.new()
	raiz.add_child(h)
	h.rotation = Vector3(0.0, _rng.randf() * TAU, 0.35)          # caído de lado
	_caixa(h, Vector3(2.4, 2.0, 6.0), Vector3(0, 1.1, 0), Vector3.ZERO, verde)                 # fuselagem
	_caixa(h, Vector3(2.0, 1.4, 1.6), Vector3(0, 1.0, -3.5), Vector3(0.25, 0, 0), queimado)  # cabine queimada
	_caixa(h, Vector3(0.5, 0.6, 5.0), Vector3(0.3, 1.5, 5.2), Vector3(0.1, 0.25, 0), verde)  # cauda
	_caixa(h, Vector3(0.12, 1.4, 0.9), Vector3(0.4, 2.1, 7.5), Vector3(0, 0.25, 0.3), verde)
	_cilindro(h, 0.25, 0.6, Vector3(0, 2.3, 0), Vector3.ZERO, queimado)                     # eixo do rotor
	for k in 4:
		var pa := _caixa(h, Vector3(0.35, 0.06, 5.5), Vector3(0, 2.6, 0), Vector3(0.0, k * TAU / 4.0, 0.0), queimado)
		pa.position += Vector3(sin(k * TAU / 4.0), 0, cos(k * TAU / 4.0)) * 2.4
		pa.rotation.x = _rng.randf_range(-0.5, 0.5)                                            # pás tortas
	_caixa(h, Vector3(3.2, 0.08, 0.1), Vector3(0, 0.05, 1.2), Vector3.ZERO, queimado)        # esquis
	_caixa(h, Vector3(3.2, 0.08, 0.1), Vector3(0, 0.05, -1.2), Vector3.ZERO, queimado)
	_solido(raiz, Vector3(3.0, 2.4, 7.0), Vector3(0, 1.2, 0), h.rotation.y)
	# chão queimado
	_caixa(raiz, Vector3(12.0, 0.02, 12.0), Vector3(0, 0.03, 0), Vector3(0, _rng.randf() * TAU, 0), Color(0.05, 0.05, 0.05))
	_fogo(raiz, Vector3(0.0, 0.8, -2.0), true)
	var lado := Vector3(cos(h.rotation.y), 0, -sin(h.rotation.y))
	_conteiner(raiz, "DESTROÇOS DO HELICÓPTERO", lado * 3.2 + Vector3(0, 0, 2.0), ["militar"], Vector2i(4, 6))
	_conteiner(raiz, "CAIXA DE CARGA MILITAR", -lado * 3.4 + Vector3(0, 0, -1.0), ["militar"], Vector2i(3, 5))
	var loot = main.loot_mundo
	if loot != null:
		for k in _rng.randi_range(2, 4):
			var it = loot._sortear("militar", _rng)
			if it != null:
				var a := _rng.randf() * TAU
				var q := raiz.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(4.0, 8.0)
				q.y = main.mundo.altura(q.x, q.z) + 0.05
				ItemMundo.soltar(main.jogo, it, q, false)

# COMBOIO: 3-4 veículos militares queimados em fila na rua
func _montar_comboio(raiz: Node3D, em_x: bool) -> void:
	var eixo := Vector3(1, 0, 0) if em_x else Vector3(0, 0, 1)
	var rot := (PI * 0.5 if em_x else 0.0)
	var n := _rng.randi_range(3, 4)
	for k in n:
		var v := Node3D.new()
		raiz.add_child(v)
		v.position = eixo * (float(k) - float(n - 1) * 0.5) * 9.0 + Vector3(_rng.randf_range(-1.0, 1.0), 0, 0).rotated(Vector3.UP, rot)
		v.rotation.y = rot + _rng.randf_range(-0.35, 0.35)
		var queimado := _rng.randf() < 0.6
		var cor := Color(0.08, 0.08, 0.08) if queimado else Color(0.2, 0.23, 0.16)
		var caminhao := _rng.randf() < 0.6
		if caminhao:
			_caixa(v, Vector3(2.4, 1.6, 2.0), Vector3(0, 1.4, -2.6), Vector3.ZERO, cor)        # cabine
			_caixa(v, Vector3(2.5, 2.2, 4.6), Vector3(0, 1.9, 0.8), Vector3.ZERO, cor.darkened(0.2))   # baú/lona
		else:
			_caixa(v, Vector3(2.2, 1.2, 4.4), Vector3(0, 1.1, 0), Vector3.ZERO, cor)           # jipe/blindado
			_caixa(v, Vector3(1.8, 0.7, 2.0), Vector3(0, 2.0, 0.3), Vector3.ZERO, cor.darkened(0.2))
		for r in [Vector3(1.15, 0.5, -2.2), Vector3(-1.15, 0.5, -2.2), Vector3(1.15, 0.5, 2.0), Vector3(-1.15, 0.5, 2.0)]:
			_cilindro(v, 0.5, 0.35, r, Vector3(0, 0, PI * 0.5), Color(0.04, 0.04, 0.04))
		_solido(v, Vector3(2.6, 3.0, 7.2) if caminhao else Vector3(2.4, 2.4, 4.6), Vector3(0, 1.4, 0))
		if queimado and _rng.randf() < 0.6:
			_fogo(v, Vector3(0, 1.2, 0), false)
		var lado := Vector3(1.9, 0, 0)
		_conteiner(v, "VEÍCULO MILITAR", lado, ["militar", "carro"], Vector2i(2, 4), "", Vector3(0.9, 0.5, 0.6))

# ZONA CONTAMINADA: névoa verde (partículas grandes), placas de aviso e a caixa da quarentena no meio
func _montar_gas(raiz: Node3D, raio: float) -> void:
	var nevoa := _particulas(raiz, Vector3(0, 2.5, 0), int(clampf(raio * 0.9, 30.0, 60.0)), 14.0, Color(0.55, 0.75, 0.15, 0.22),
		Vector2(9.0, 16.0), 0.25, 8.0, false)
	nevoa.emission_sphere_radius = raio * 0.85
	nevoa.gravity = Vector3(0.15, 0.0, 0.05)
	nevoa.visibility_aabb = AABB(Vector3(-raio - 10, -5, -raio - 10), Vector3(raio * 2 + 20, 30, raio * 2 + 20))
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.6, 0.9, 0.2)
	luz.omni_range = raio
	luz.light_energy = 0.6
	raiz.add_child(luz)
	luz.position = Vector3(0, 6.0, 0)
	# placas de aviso na borda (amarelas)
	for k in 4:
		var a := k * TAU / 4.0 + _rng.randf_range(-0.3, 0.3)
		var pp := Vector3(cos(a), 0, sin(a)) * (raio + 6.0)
		var placa := Node3D.new()
		raiz.add_child(placa)
		placa.position = pp
		placa.rotation.y = -a + PI * 0.5
		_cilindro(placa, 0.04, 2.0, Vector3(0, 1.0, 0), Vector3.ZERO, Color(0.4, 0.4, 0.4))
		_caixa(placa, Vector3(0.9, 0.7, 0.04), Vector3(0, 2.0, 0), Vector3.ZERO, Color(0.95, 0.8, 0.1))
		var t := Label3D.new()
		t.text = "PERIGO\nGÁS"
		t.font_size = 48
		t.pixel_size = 0.004
		t.modulate = Color(0.05, 0.05, 0.05)
		t.outline_size = 0
		placa.add_child(t)
		t.position = Vector3(0, 2.0, 0.03)
	_conteiner(raiz, "MATERIAL DA QUARENTENA", Vector3(0, 0, 0), ["militar"], Vector2i(5, 7))

func _soltar_horda(e: Dictionary) -> void:
	var vg = main.get("vagos")
	if vg == null or not bool(vg.get("ativo")):
		return
	var n := 0
	match e["tipo"]:
		"heli": n = _rng.randi_range(4, 6)
		"comboio": n = _rng.randi_range(3, 5)
		"gas": n = _rng.randi_range(2, 4)
	var c: Vector3 = e["pos"]
	for k in n:
		for t in 6:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(6.0, 20.0)
			var q := Vector3(c.x + cos(a) * r, 0.0, c.z + sin(a) * r)
			if vg._livre(q.x, q.z):
				q.y = main.mundo.altura(q.x, q.z)
				vg._criar(q, c)
				break

func _aviso(t: String) -> void:
	if main.hud != null and main.hud.has_method("mostrar_aviso"):
		main.hud.mostrar_aviso(t, 5.0)
		Sons.tocar("partida/objetivo", -8.0)
