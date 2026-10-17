extends RefCounted
# CIDADE ABANDONADA: carros largados nas ruas (estacionados, parados no meio da pista, batidos, capotados e
# queimados), engavetamentos em cruzamentos, barreiras de concreto, barris, caçambas, sacos de lixo,
# montes de entulho e pedaços de concreto (mais perto dos prédios em ruína).
# Tudo em MultiMesh por blocos de 250 m (o celular só desenha o que está perto, na frente da câmera e não escondido
# atrás dos prédios: "visibility_range_end" + frustum + oclusão).
# Devolve também os OBSTÁCULOS (caixas para a colisão perto do jogador) e os CARROS (porta-malas com loot).
# Mexa AQUI para: quantos carros/obstáculos por rua, modelos dos carros, cores.

const Malhas := preload("res://mundo/malhas.gd")
const BLOCO := 250.0
const Y := 0.6                       # altura do asfalto

const CORES_CARRO := [Color(0.55, 0.08, 0.07), Color(0.12, 0.2, 0.42), Color(0.75, 0.75, 0.72), Color(0.1, 0.1, 0.11),
	Color(0.3, 0.32, 0.3), Color(0.22, 0.34, 0.22), Color(0.6, 0.55, 0.42), Color(0.45, 0.45, 0.5)]
const AMARELO_TAXI := Color(0.95, 0.7, 0.08)
const QUEIMADO := Color(0.13, 0.11, 0.1)

var cid                                  # mundo/cidade.gd
var rng := RandomNumberGenerator.new()
var densidade := 1.0
var obstaculos := PackedFloat32Array()   # x, z, giro, tam_x, tam_y, tam_z, y_centro (7 por obstáculo)
var carros: Array = []                   # [pos Vector3, giro, tipo] (porta-malas)
var _inst := {}                          # nome do modelo -> {Vector2i: [[Transform3D, Color], ...]}
var nos: Array[GeometryInstance3D] = []

func construir(cidade, ruinas: Array, dens: float) -> void:
	cid = cidade
	densidade = dens
	rng.seed = 777
	_carros_nas_ruas()
	_engavetamentos()
	_barreiras()
	_lixo_nas_calcadas()
	_mobiliario_urbano()
	_entulho(ruinas)
	_montar()

# ---------- modelos ----------
static func modelo(nome: String) -> ArrayMesh:
	var c := Malhas.Construtor.new()
	var vidro := Color(0.1, 0.11, 0.12)
	var pneu := Color(0.05, 0.05, 0.05)
	var roda := Basis(Vector3.RIGHT, PI * 0.5)
	match nome:
		"sedan", "taxi":
			c.caixa(Vector3(0, 0.62, 0), Vector3(4.4, 0.72, 1.85), Color.WHITE)
			c.caixa(Vector3(-0.25, 1.28, 0), Vector3(2.3, 0.62, 1.66), Color(0.95, 0.95, 0.95))
			c.caixa(Vector3(-0.25, 1.27, 0), Vector3(2.34, 0.4, 1.7), vidro)
			c.caixa(Vector3(2.21, 0.72, 0.6), Vector3(0.04, 0.16, 0.36), Color(1.6, 1.6, 1.4))
			c.caixa(Vector3(2.21, 0.72, -0.6), Vector3(0.04, 0.16, 0.36), Color(1.6, 1.6, 1.4))
			c.caixa(Vector3(-2.21, 0.75, 0.62), Vector3(0.04, 0.14, 0.3), Color(1.8, 0.2, 0.15))
			c.caixa(Vector3(-2.21, 0.75, -0.62), Vector3(0.04, 0.14, 0.3), Color(1.8, 0.2, 0.15))
			if nome == "taxi":
				c.caixa(Vector3(-0.25, 1.68, 0), Vector3(0.6, 0.18, 0.3), Color(1.1, 1.1, 1.0))
			for x in [1.4, -1.35]:
				for z in [0.86, -0.86]:
					c.cilindro(Vector3(x, 0.34, z), 0.34, 0.24, 10, pneu, roda)
		"van":
			c.caixa(Vector3(0, 1.15, 0), Vector3(4.9, 1.75, 1.98), Color.WHITE)
			c.caixa(Vector3(1.75, 1.55, 0), Vector3(1.42, 0.55, 2.02), vidro)
			c.caixa(Vector3(0.0, 1.62, 0), Vector3(1.8, 0.4, 2.02), vidro)
			for x in [1.6, -1.6]:
				for z in [0.9, -0.9]:
					c.cilindro(Vector3(x, 0.36, z), 0.36, 0.26, 10, pneu, roda)
		"onibus":
			c.caixa(Vector3(0, 1.75, 0), Vector3(11.0, 2.7, 2.5), Color.WHITE)
			c.caixa(Vector3(0, 2.15, 0), Vector3(11.04, 0.9, 2.54), vidro)
			c.caixa(Vector3(5.5, 1.5, 0), Vector3(0.06, 1.2, 2.2), vidro)
			for x in [3.8, -3.6]:
				for z in [1.05, -1.05]:
					c.cilindro(Vector3(x, 0.5, z), 0.5, 0.35, 12, pneu, roda)
		"barreira":
			c.caixa(Vector3(0, 0.2, 0), Vector3(3.0, 0.4, 0.62), Color.WHITE)
			c.caixa(Vector3(0, 0.62, 0), Vector3(3.0, 0.45, 0.3), Color.WHITE)
		"barril":
			c.cilindro(Vector3(0, 0.45, 0), 0.3, 0.9, 10, Color.WHITE)
			c.cilindro(Vector3(0, 0.3, 0), 0.315, 0.05, 10, Color(0.7, 0.7, 0.7))
			c.cilindro(Vector3(0, 0.62, 0), 0.315, 0.05, 10, Color(0.7, 0.7, 0.7))
		"cacamba":
			c.caixa(Vector3(0, 0.65, 0), Vector3(2.0, 1.1, 1.3), Color.WHITE)
			c.caixa(Vector3(0, 1.25, -0.1), Vector3(2.05, 0.06, 1.2), Color(0.8, 0.8, 0.8), Basis(Vector3.RIGHT, -0.25))
			c.caixa(Vector3(0, 0.08, 0), Vector3(1.8, 0.16, 1.1), Color(0.3, 0.3, 0.3))
		"lixo":
			for q in [[Vector3(0, 0.22, 0), Vector3(0.6, 0.45, 0.5), 0.3], [Vector3(0.45, 0.18, 0.25), Vector3(0.5, 0.36, 0.45), -0.5],
					[Vector3(-0.3, 0.16, 0.35), Vector3(0.45, 0.32, 0.4), 1.1], [Vector3(0.1, 0.5, 0.05), Vector3(0.4, 0.3, 0.35), 0.8]]:
				c.caixa(q[0], q[1], Color.WHITE, Basis(Vector3.UP, q[2]) * Basis(Vector3.RIGHT, q[2] * 0.3))
		"entulho":
			var r := RandomNumberGenerator.new()
			r.seed = 31
			for i in 14:
				var a := r.randf() * TAU
				var d := r.randf() * 1.6
				var s := Vector3(r.randf_range(0.4, 1.4), r.randf_range(0.2, 0.7), r.randf_range(0.3, 1.1))
				var b := Basis.from_euler(Vector3(r.randf_range(-0.6, 0.6), r.randf() * TAU, r.randf_range(-0.6, 0.6)))
				var g := r.randf_range(0.75, 1.1)
				c.caixa(Vector3(cos(a) * d, s.y * 0.4 + (1.6 - d) * 0.35, sin(a) * d), s, Color(g, g * 0.97, g * 0.93), b)
			c.caixa(Vector3(0.3, 0.9, 0.1), Vector3(2.4, 0.08, 0.12), Color(0.45, 0.3, 0.2), Basis(Vector3.FORWARD, 0.5))   # viga
		"cacos":
			var r := RandomNumberGenerator.new()
			r.seed = 77
			for i in 7:
				var s := Vector3(r.randf_range(0.15, 0.5), r.randf_range(0.06, 0.18), r.randf_range(0.12, 0.4))
				c.caixa(Vector3(r.randf_range(-1.2, 1.2), s.y * 0.5, r.randf_range(-1.2, 1.2)), s, Color.WHITE, Basis(Vector3.UP, r.randf() * TAU))
			c.caixa(Vector3(0.2, 0.04, -0.3), Vector3(1.6, 0.06, 0.18), Color(0.5, 0.35, 0.22), Basis(Vector3.UP, 0.7))    # tábua
		"poste":
			var ferro := Color(0.2, 0.21, 0.22)
			c.cilindro(Vector3(0, 4.0, 0), 0.13, 8.0, 8, ferro, Basis.IDENTITY, 0.09)
			c.caixa(Vector3(0.9, 7.9, 0), Vector3(1.9, 0.12, 0.12), ferro)
			c.caixa(Vector3(1.75, 7.78, 0), Vector3(0.6, 0.18, 0.3), Color(0.25, 0.25, 0.25))
			c.caixa(Vector3(1.75, 7.67, 0), Vector3(0.5, 0.04, 0.24), Color(0.8, 0.78, 0.65))
			c.cilindro(Vector3(0, 0.2, 0), 0.22, 0.4, 8, ferro)
		"semaforo":
			var ferro := Color(0.18, 0.19, 0.2)
			c.cilindro(Vector3(0, 3.0, 0), 0.12, 6.0, 8, ferro)
			c.caixa(Vector3(2.6, 5.8, 0), Vector3(5.2, 0.14, 0.14), ferro)
			for x in [2.2, 4.6]:
				c.caixa(Vector3(x, 5.25, 0), Vector3(0.38, 1.0, 0.32), Color(0.12, 0.12, 0.08))
				c.caixa(Vector3(x, 5.55, 0.17), Vector3(0.18, 0.18, 0.04), Color(0.5, 0.08, 0.06))
				c.caixa(Vector3(x, 5.25, 0.17), Vector3(0.18, 0.18, 0.04), Color(0.45, 0.35, 0.05))
				c.caixa(Vector3(x, 4.95, 0.17), Vector3(0.18, 0.18, 0.04), Color(0.06, 0.3, 0.12))
			c.caixa(Vector3(0, 1.3, 0.15), Vector3(0.3, 0.4, 0.15), Color(0.15, 0.15, 0.15))
		"hidrante":
			var verm := Color(0.6, 0.1, 0.07)
			c.cilindro(Vector3(0, 0.35, 0), 0.14, 0.7, 8, verm)
			c.cilindro(Vector3(0, 0.75, 0), 0.1, 0.12, 8, verm, Basis.IDENTITY, 0.04)
			c.cilindro(Vector3(0, 0.45, 0), 0.06, 0.45, 6, verm, Basis(Vector3.FORWARD, PI * 0.5))
		"banco":
			var mad := Color(0.42, 0.28, 0.16)
			var fer := Color(0.15, 0.15, 0.16)
			for i in 3:
				c.caixa(Vector3(0, 0.45, -0.18 + i * 0.16), Vector3(1.8, 0.05, 0.12), mad)
			for i in 2:
				c.caixa(Vector3(0, 0.62 + i * 0.16, 0.24), Vector3(1.8, 0.1, 0.04), mad, Basis(Vector3.RIGHT, -0.2))
			for x in [-0.75, 0.75]:
				c.caixa(Vector3(x, 0.22, 0), Vector3(0.08, 0.44, 0.5), fer)
		"arvore_rua":
			c.cilindro(Vector3(0, 1.6, 0), 0.16, 3.2, 6, Color(0.32, 0.24, 0.17), Basis.IDENTITY, 0.11)
			c.cilindro(Vector3(0, 0.04, 0), 0.65, 0.08, 8, Color(0.25, 0.2, 0.15))          # canteiro
			for q in [[Vector3(0, 3.9, 0), 1.7, 2.2], [Vector3(0.4, 4.7, 0.2), 1.3, 1.6], [Vector3(-0.3, 5.3, -0.2), 0.9, 1.2]]:
				c.cilindro(q[0], q[1], q[2], 7, Color.WHITE, Basis(Vector3.UP, q[1]), q[1] * 0.55)

	return c.malha()

# ---------- colocação ----------
func _por(nome: String, t: Transform3D, cor: Color) -> void:
	if not _inst.has(nome):
		_inst[nome] = {}
	var k := Vector2i(floori(t.origin.x / BLOCO), floori(t.origin.z / BLOCO))
	if not _inst[nome].has(k):
		_inst[nome][k] = []
	_inst[nome][k].append([t, cor])

func _obstaculo(p: Vector3, giro: float, tam: Vector3) -> void:
	obstaculos.append_array(PackedFloat32Array([p.x, p.z, giro, tam.x, tam.y, tam.z, p.y + tam.y * 0.5]))

static func _giro(dir: Vector2) -> float:
	return atan2(-dir.y, dir.x)

func _carro(pos: Vector2, giro: float, estado: String) -> void:
	var r := rng.randf()
	var nome := "sedan"
	if r < 0.1:
		nome = "taxi"
	elif r < 0.3:
		nome = "van"
	elif r < 0.33:
		nome = "onibus"
	var cor: Color = AMARELO_TAXI if nome == "taxi" else CORES_CARRO[rng.randi() % CORES_CARRO.size()]
	if nome == "onibus":
		cor = [Color(0.85, 0.6, 0.1), Color(0.75, 0.75, 0.75), Color(0.2, 0.35, 0.6)][rng.randi() % 3]
	cor = cor * rng.randf_range(0.7, 1.0)
	if rng.randf() < 0.2:
		cor = QUEIMADO * rng.randf_range(0.8, 1.3)
	cor.a = 1.0
	var b := Basis(Vector3.UP, giro)
	var y := Y
	var alto: float = {"sedan": 1.6, "taxi": 1.6, "van": 2.0, "onibus": 3.1}[nome]
	var tam: Vector3 = {"sedan": Vector3(4.4, 1.6, 1.9), "taxi": Vector3(4.4, 1.6, 1.9), "van": Vector3(4.9, 2.0, 2.0), "onibus": Vector3(11, 3.1, 2.5)}[nome]
	if estado == "capotado" and nome != "onibus":
		b = b * Basis(Vector3.RIGHT, PI)
		y = Y + alto
	elif estado == "tombado" and nome != "onibus":
		b = b * Basis(Vector3.RIGHT, PI * 0.5)
		y = Y + tam.z * 0.5
		tam = Vector3(tam.x, tam.z, tam.y)
	_por(nome, Transform3D(b, Vector3(pos.x, y, pos.y)), cor)
	_obstaculo(Vector3(pos.x, Y, pos.y), giro, tam)
	carros.append([Vector3(pos.x, Y, pos.y), giro, nome])

func _carros_nas_ruas() -> void:
	for rd in cid.dados_cidade["roads"]:
		var hw: float = float(rd[0]) * 0.5
		var pts: PackedVector2Array = cid._pts(rd[1])
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var l := a.distance_to(b)
			if l < 20.0:
				continue
			var dir := (b - a) / l
			var nrm := Vector2(-dir.y, dir.x)
			var ra: float = cid._cruzamento(a)
			var rb: float = cid._cruzamento(b)
			# engarrafamento abandonado: fila de carros colados numa pista
			if rng.randf() < 0.32 * densidade and l > 60.0:
				var lado := 1.0 if rng.randf() < 0.5 else -1.0
				var faixa := lado * hw * rng.randf_range(0.2, 0.75)
				var giro := _giro(dir * lado)
				var tf := rng.randf_range(10.0, l * 0.5)
				for j in rng.randi_range(3, 10):
					if tf > l - 10.0:
						break
					if not ((ra >= 0.0 and tf < ra + 9.0) or (rb >= 0.0 and tf > l - rb - 9.0)):
						_carro(a + dir * tf + nrm * (faixa + rng.randf_range(-0.6, 0.6)), giro + rng.randf_range(-0.25, 0.25), "")
					tf += rng.randf_range(5.6, 8.5)
			var t := rng.randf_range(6.0, 30.0)
			while t < l - 8.0:
				var perto_a := ra >= 0.0 and t < ra + 9.0
				var perto_b := rb >= 0.0 and t > l - rb - 9.0
				if not (perto_a or perto_b):
					var lado := 1.0 if rng.randf() < 0.5 else -1.0
					var giro := _giro(dir * lado)
					var e := rng.randf()
					if e < 0.55:      # estacionado na beira
						_carro(a + dir * t + nrm * lado * (hw - 1.7), giro + rng.randf_range(-0.06, 0.06), "")
					elif e < 0.86:    # largado no meio da pista
						_carro(a + dir * t + nrm * lado * hw * rng.randf_range(0.15, 0.7), giro + rng.randf_range(-0.4, 0.4), "")
					elif e < 0.95:    # batido, atravessado
						_carro(a + dir * t + nrm * lado * hw * rng.randf_range(0.0, 0.6), rng.randf() * TAU, "")
					else:
						_carro(a + dir * t + nrm * lado * hw * rng.randf_range(0.1, 0.6), rng.randf() * TAU, "capotado" if rng.randf() < 0.5 else "tombado")
				t += rng.randf_range(14.0, 48.0) / densidade

func _engavetamentos() -> void:
	for k in cid._nos:
		var e = cid._nos[k]
		if e["n"] < 4 or rng.randf() > 0.12 * densidade:
			continue
		var c := Vector2(k)
		for i in rng.randi_range(2, 4):
			_carro(c + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7)), rng.randf() * TAU, "capotado" if rng.randf() < 0.15 else "")

func _barreiras() -> void:
	# fileiras de barreiras de concreto fechando parte de algumas ruas (bloqueios do exército)
	for rd in cid.dados_cidade["roads"]:
		var hw: float = float(rd[0]) * 0.5
		var pts: PackedVector2Array = cid._pts(rd[1])
		if rng.randf() > 0.045 * densidade or pts.size() < 2:
			continue
		var a := pts[0]
		var b := pts[1]
		if a.distance_to(b) < 30.0:
			continue
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var c := a + dir * rng.randf_range(14.0, minf(40.0, a.distance_to(b) - 10.0))
		var giro := _giro(nrm)
		var k := -hw + 1.6
		while k < hw - 1.5:
			if rng.randf() > 0.18:          # algumas faltando (passagem)
				var p := c + nrm * k + dir * rng.randf_range(-0.3, 0.3)
				_por("barreira", Transform3D(Basis(Vector3.UP, giro + rng.randf_range(-0.12, 0.12)), Vector3(p.x, Y, p.y)), Color(0.62, 0.6, 0.56) * rng.randf_range(0.85, 1.05))
				_obstaculo(Vector3(p.x, Y, p.y), giro, Vector3(3.0, 0.85, 0.62))
			k += 3.1

func _lixo_nas_calcadas() -> void:
	var cores_barril := [Color(0.5, 0.2, 0.08), Color(0.15, 0.25, 0.45), Color(0.2, 0.35, 0.2), Color(0.55, 0.12, 0.08)]
	for rd in cid.dados_cidade["roads"]:
		var hw: float = float(rd[0]) * 0.5
		var pts: PackedVector2Array = cid._pts(rd[1])
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var l := a.distance_to(b)
			if l < 25.0:
				continue
			var dir := (b - a) / l
			var nrm := Vector2(-dir.y, dir.x)
			var t := rng.randf_range(5.0, 40.0)
			while t < l - 5.0:
				var lado := 1.0 if rng.randf() < 0.5 else -1.0
				var p := a + dir * t + nrm * lado * (hw + rng.randf_range(1.0, 4.0))     # na calçada
				var g := Basis(Vector3.UP, rng.randf() * TAU)
				var r := rng.randf()
				if r < 0.4:
					_por("lixo", Transform3D(g.scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(p.x, Y - 0.05, p.y)), Color(0.07, 0.07, 0.08) if rng.randf() < 0.8 else Color(0.2, 0.25, 0.4))
				elif r < 0.65:
					var n := rng.randi_range(1, 3)
					for j in n:
						var q := p + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
						var deitado := rng.randf() < 0.25
						var bb := g * Basis(Vector3.FORWARD, PI * 0.5) if deitado else g
						_por("barril", Transform3D(bb, Vector3(q.x, Y - 0.05 + (0.3 if deitado else 0.0), q.y)), cores_barril[rng.randi() % cores_barril.size()] * rng.randf_range(0.7, 1.0))
						_obstaculo(Vector3(q.x, Y, q.y), 0.0, Vector3(0.6, 0.9, 0.6))
				elif r < 0.8:
					var giro := _giro(dir)
					_por("cacamba", Transform3D(Basis(Vector3.UP, giro + rng.randf_range(-0.3, 0.3)), Vector3(p.x, Y - 0.05, p.y)), [Color(0.15, 0.3, 0.18), Color(0.15, 0.2, 0.35), Color(0.4, 0.3, 0.1)][rng.randi() % 3])
					_obstaculo(Vector3(p.x, Y, p.y), giro, Vector3(2.0, 1.3, 1.3))
				else:
					_por("cacos", Transform3D(g, Vector3(p.x, Y - 0.05, p.y)), Color(0.55, 0.53, 0.5) * rng.randf_range(0.8, 1.1))
				t += rng.randf_range(25.0, 70.0) / densidade

# postes (alguns caídos), semáforos nos cruzamentos (alguns tortos), hidrantes, bancos e árvores de calçada
func _mobiliario_urbano() -> void:
	for rd in cid.dados_cidade["roads"]:
		var hw: float = float(rd[0]) * 0.5
		var pts: PackedVector2Array = cid._pts(rd[1])
		var com_arvores := rng.randf() < 0.45
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var l := a.distance_to(b)
			if l < 30.0:
				continue
			var dir := (b - a) / l
			var nrm := Vector2(-dir.y, dir.x)
			var ra: float = cid._cruzamento(a)
			var rb: float = cid._cruzamento(b)
			for lado in [-1.0, 1.0]:
				var t := (ra + 6.0 if ra >= 0.0 else 6.0) + rng.randf_range(0.0, 8.0)
				var fim := l - (rb + 6.0 if rb >= 0.0 else 6.0)
				var k := 0
				while t < fim:
					var p: Vector2 = a + dir * t + nrm * lado * (hw + 1.0)
					var giro := _giro(-nrm * lado)          # braço do poste por cima da rua
					if k % 2 == 0:
						if rng.randf() < 0.08:
							# poste caído atravessado na rua
							var bb := Basis(Vector3.UP, giro) * Basis(Vector3.FORWARD, -PI * 0.47)
							_por("poste", Transform3D(bb, Vector3(p.x, Y + 0.1, p.y)), Color.WHITE)
						else:
							_por("poste", Transform3D(Basis(Vector3.UP, giro) * Basis(Vector3.FORWARD, rng.randf_range(-0.04, 0.04)), Vector3(p.x, Y - 0.05, p.y)), Color.WHITE)
							_obstaculo(Vector3(p.x, Y, p.y), giro, Vector3(0.35, 8.0, 0.35))
					elif com_arvores:
						var q: Vector2 = a + dir * t + nrm * lado * (hw + 3.2)
						var verde := Color(0.24, 0.36, 0.15) * rng.randf_range(0.7, 1.2)
						if rng.randf() < 0.3:
							verde = Color(0.35, 0.27, 0.16) * rng.randf_range(0.8, 1.2)    # árvore seca
						verde.a = 1.0
						var s := rng.randf_range(0.85, 1.25)
						_por("arvore_rua", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(q.x, Y - 0.05, q.y)), verde)
						_obstaculo(Vector3(q.x, Y, q.y), 0.0, Vector3(0.45, 3.0, 0.45))
					var r := rng.randf()
					var q2: Vector2 = a + dir * (t + 7.0) + nrm * lado * (hw + 1.4)
					if r < 0.12:
						_por("hidrante", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q2.x, Y - 0.05, q2.y)), Color.WHITE)
					elif r < 0.2:
						var q3: Vector2 = a + dir * (t + 7.0) + nrm * lado * (hw + 3.8)
						_por("banco", Transform3D(Basis(Vector3.UP, _giro(dir) + (PI if lado > 0.0 else 0.0)), Vector3(q3.x, Y - 0.05, q3.y)), Color.WHITE)
					t += rng.randf_range(16.0, 22.0)
					k += 1
	# semáforos: um em cada canto dos cruzamentos grandes
	for kk in cid._nos:
		var e = cid._nos[kk]
		if e["n"] < 4:
			continue
		var r: float = e["r"] + 2.0
		for canto in 4:
			var ang := PI * 0.25 + canto * PI * 0.5
			var p := Vector2(kk) + Vector2(cos(ang), sin(ang)) * r * 1.414
			var giro := ang + PI * 0.75
			var torto := Basis.IDENTITY
			if rng.randf() < 0.2:
				torto = Basis(Vector3.FORWARD, rng.randf_range(-0.35, 0.35))
			_por("semaforo", Transform3D(Basis(Vector3.UP, giro) * torto, Vector3(p.x, Y - 0.05, p.y)), Color.WHITE)
			_obstaculo(Vector3(p.x, Y, p.y), 0.0, Vector3(0.3, 6.0, 0.3))

func _entulho(ruinas: Array) -> void:
	for r in ruinas:
		var c := Vector2(r[0], r[1])
		var sx: float = r[2]
		var sz: float = r[3]
		# entulho em cima da metade desabada e pedaços grandes caídos na calçada/rua
		if r.size() >= 8:
			for i in rng.randi_range(2, 4):
				var q := Vector2(r[5], r[6]) + Vector2(rng.randf_range(-0.3, 0.3) * sx * 0.5, rng.randf_range(-0.3, 0.3) * sz * 0.5)
				var s := rng.randf_range(2.0, 3.5)
				_por("entulho", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(q.x, Y + float(r[7]) - 0.4, q.y)), Color(0.4, 0.38, 0.36) * rng.randf_range(0.8, 1.1))
		for i in rng.randi_range(7, 13):
			var lado := rng.randi() % 4
			var p := c
			if lado < 2:
				p += Vector2((sx * 0.5 + rng.randf_range(0.5, 4.0)) * (1 if lado == 0 else -1), rng.randf_range(-sz, sz) * 0.5)
			else:
				p += Vector2(rng.randf_range(-sx, sx) * 0.5, (sz * 0.5 + rng.randf_range(0.5, 4.0)) * (1 if lado == 2 else -1))
			var s := rng.randf_range(1.2, 3.4)
			_por("entulho", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.6, 1.2), s)), Vector3(p.x, Y - 0.1, p.y)), Color(0.42, 0.4, 0.37) * rng.randf_range(0.75, 1.1))
			if s > 1.3:
				_obstaculo(Vector3(p.x, Y, p.y), 0.0, Vector3(2.4 * s, 0.9 * s, 2.4 * s))
		for i in rng.randi_range(8, 16):
			var p := c + Vector2(rng.randf_range(-1, 1) * (sx * 0.5 + 16.0), rng.randf_range(-1, 1) * (sz * 0.5 + 16.0))
			_por("cacos", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, Y - 0.05, p.y)), Color(0.55, 0.53, 0.5) * rng.randf_range(0.8, 1.1))

func _montar() -> void:
	var mat_metal := _material(0.6)
	var mat_concreto := _material(0.0)
	var alcance := {"sedan": 900.0, "taxi": 900.0, "van": 900.0, "onibus": 1200.0, "barreira": 600.0, "barril": 350.0,
		"cacamba": 450.0, "lixo": 300.0, "entulho": 700.0, "cacos": 250.0, "poste": 600.0, "semaforo": 600.0,
		"hidrante": 200.0, "banco": 250.0, "arvore_rua": 700.0}
	for nome in _inst:
		var malha := modelo(nome)
		var concreto: bool = nome in ["barreira", "entulho", "cacos", "lixo", "arvore_rua", "banco"]
		malha.surface_set_material(0, mat_concreto if concreto else mat_metal)
		for k in _inst[nome]:
			var lista: Array = _inst[nome][k]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = malha
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, lista[i][0])
				mm.set_instance_color(i, lista[i][1])
			var mi := MultiMeshInstance3D.new()
			mi.name = "%s_%d_%d" % [nome, k.x, k.y]
			mi.multimesh = mm
			mi.visibility_range_end = alcance.get(nome, 600.0)
			if nome in ["lixo", "cacos", "barril", "hidrante", "banco"]:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			nos.append(mi)

static func _material(ferrugem: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var s := Shader.new()
	s.code = SHADER_PROPS
	m.shader = s
	m.set_shader_parameter("ferrugem", ferrugem)
	return m

# sujeira, desgaste e ferrugem (usa o UV em metros + a posição de cada objeto para variar)
const SHADER_PROPS := """
shader_type spatial;
uniform float ferrugem = 0.5;
varying vec3 wo;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wo = MODEL_MATRIX[3].xyz; }
void fragment() {
	vec3 c = COLOR.rgb;
	vec2 q = UV * 1.7 + wo.xz * 0.37;
	float n = ruido(q) * 0.6 + ruido(q * 3.1) * 0.4;
	float r = smoothstep(0.55, 0.8, ruido(UV * 0.9 + wo.xz)) * ferrugem;
	c = mix(c, vec3(0.32, 0.17, 0.08) * (0.7 + 0.5 * n), r);
	c *= 0.72 + 0.36 * n;
	ALBEDO = clamp(c, 0.0, 1.0);
	EMISSION = max(COLOR.rgb - vec3(1.0), vec3(0.0)) * 0.15;    // faróis/lanternas (cor > 1)
	ROUGHNESS = mix(0.55, 0.95, max(r, n * 0.5));
}
"""
