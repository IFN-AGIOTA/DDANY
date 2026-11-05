extends Node3D
# 1.14 · CIDADE CHEIA NO MODO HISTÓRIA ("antes do caos")
# A grade da cidade (mundo/cidade.gd _buildings) só põe prédio em quadrados de 40 x 40 m SEM nenhum pedaço de rua.
# Na beira das ruas sobram faixas de terreno vazio (terra, mato, árvore seca). No modo livre isso passa por cidade
# abandonada, mas nas cenas de perto do Dia -5 parecia que "a cidade não foi desenhada".
# Aqui, só no modo história, cada célula de 20 m de terra que está vazia (longe do asfalto e da calçada, sem parque, sem prédio,
# fora dos locais especiais e da água) ganha um PRÉDIO DE PREENCHIMENTO, com o mesmo material e as mesmas janelas dos
# prédios da cidade e colisão de caixa. É montado em pedaços de PEDACO m EM VOLTA DA CÂMERA (a da cena ou a do jogo):
# perto dela aparece; longe, sai. Determinístico (sorteio pela célula): a mesma esquina tem sempre os mesmos prédios.
# O minimapa e o mapa não mostram estes prédios.
# Mexa AQUI para: o raio em volta da câmera, os tamanhos e as alturas.

const LocaisCls := preload("res://mundo/locais.gd")

const PEDACO := 100.0
const RAIO := 280.0               # monta os pedaços até aqui da câmera
const RAIO_SAIR := 380.0          # e tira os que passaram disto
const POR_QUADRO := 3             # pedaços montados por quadro (os mais perto primeiro)
const MARGEM := 3.0               # distância mínima dos prédios da cidade
const TAMANHOS := [18.0, 15.0, 12.0, 9.0]
const DESLOCA := [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3), Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]

var cidade = null
var _malha: Mesh = null
var _pedacos := {}                # Vector2i -> Node3D
var _lotes := {}                  # Vector2i -> PackedFloat32Array [x, z, sx, sz, h] (cache, também para fachadas)
var _hash := {}                   # Vector2i (50 m) -> PackedInt32Array (prédios da cidade)
var _locais: Array[Rect2] = []
var _t := 0.0
var _t_ocupa := 0.0
var _reservas: Array = []         # [Vector2, raio]: aqui não nasce prédio (carros da história, o jogador)
var jogador: Node3D = null
var n_predios := 0                # quantos estão montados agora (testes)

const GRUPO_OCUPA := "historia_ocupa"   # carros da história (mundo/veiculo.gd); os atores ficam nas calçadas, que nunca têm prédio
const RAIO_OCUPA := 4.5

func ligar(c) -> void:
	cidade = c
	for mm in cidade._mm_predios.values():
		_malha = (mm as MultiMesh).mesh
		break
	var pr: PackedFloat32Array = cidade.predios
	for i in range(0, pr.size(), 5):
		var hx: float = pr[i + 2] * 0.5 + MARGEM
		var hz: float = pr[i + 3] * 0.5 + MARGEM
		for gx in range(floori((pr[i] - hx) / 50.0), floori((pr[i] + hx) / 50.0) + 1):
			for gz in range(floori((pr[i + 1] - hz) / 50.0), floori((pr[i + 1] + hz) / 50.0) + 1):
				var k := Vector2i(gx, gz)
				if not _hash.has(k):
					_hash[k] = PackedInt32Array()
				_hash[k].append(i / 5)
	for i in LocaisCls.LOCAIS.size():
		_locais.append(LocaisCls.retangulo(i, 4.0))

func _process(dt: float) -> void:
	if cidade == null or _malha == null:
		return
	_t_ocupa -= dt
	if _t_ocupa <= 0.0:
		_t_ocupa = 0.5
		_conferir_ocupados()
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.1
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_atualizar(Vector2(cam.global_position.x, cam.global_position.z), POR_QUADRO)

# monta tudo em volta de p agora (teleporte, começo de cena longe)
func forcar(p: Vector3) -> void:
	if cidade != null and _malha != null:
		_atualizar(Vector2(p.x, p.z), 1 << 20)

func _atualizar(p: Vector2, limite: int) -> void:
	for k in _pedacos.keys():
		if p.distance_to((Vector2(k) + Vector2(0.5, 0.5)) * PEDACO) > RAIO_SAIR:
			var no: Node3D = _pedacos[k]
			n_predios -= int(no.get_meta("n", 0))
			no.queue_free()
			_pedacos.erase(k)
	var c := Vector2i(floori(p.x / PEDACO), floori(p.y / PEDACO))
	var nr := int(ceil(RAIO / PEDACO))
	var falta: Array = []
	for dz in range(-nr, nr + 1):
		for dx in range(-nr, nr + 1):
			var k := c + Vector2i(dx, dz)
			if _pedacos.has(k):
				continue
			var d := p.distance_to((Vector2(k) + Vector2(0.5, 0.5)) * PEDACO)
			if d < RAIO:
				falta.append([d, k])
	falta.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(limite, falta.size()):
		_montar(falta[i][1])

# os prédios de preenchimento de um pedaço: [x, z, sx, sz, h] (mesmo resultado sempre)
func lotes(k: Vector2i) -> PackedFloat32Array:
	if _lotes.has(k):
		return _lotes[k]
	var r := PackedFloat32Array()
	var W: int = cidade.W
	var H: int = cidade.H
	var cel: float = cidade.CELL
	var mundo: Vector2 = cidade.WORLD
	var n := int(PEDACO / cel)
	var c0 := Vector2i(floori((k.x * PEDACO + mundo.x) / cel), floori((k.y * PEDACO + mundo.y) / cel))
	for j in n:
		for i in n:
			var lc := c0.x + i
			var lr := c0.y + j
			if lc < 1 or lr < 1 or lc >= W - 1 or lr >= H - 1:
				continue
			var q := lr * W + lc
			# (a máscara de ruas é grossa: a célula "rua" muitas vezes é terra; quem decide é a distância de verdade
			# até o asfalto + calçada, em _livre -> cidade._predio_ruim)
			if cidade.land[q] == 0 or cidade.park[q] == 1:
				continue
			var x := (lc + 0.5) * cel - mundo.x
			var z := (lr + 0.5) * cel - mundo.y
			if x > 5700.0 and z > -1487.0 and z < 2512.0:      # aeroporto / base militar (igual à cidade)
				continue
			var achou := false
			for s in TAMANHOS:
				for o in DESLOCA:
					var px: float = x + (o as Vector2).x
					var pz: float = z + (o as Vector2).y
					if _livre(px, pz, s, s):
						var rng := RandomNumberGenerator.new()
						rng.seed = hash(Vector2i(lc, lr))
						var d := Vector2(px, pz).distance_to(cidade.DOWNTOWN) / 1500.0
						var h := 12.0 + rng.randf() * 22.0 + 110.0 * exp(-d * d) * rng.randf_range(0.4, 1.0)
						r.append_array(PackedFloat32Array([px, pz, s, s, h]))
						achou = true
						break
				if achou:
					break
	_lotes[k] = r
	return r

func _livre(x: float, z: float, sx: float, sz: float) -> bool:
	var ret := Rect2(x - sx * 0.5, z - sz * 0.5, sx, sz)
	for rv in _reservas:
		if _dist_ret(rv[0], ret) < float(rv[1]):
			return false
	for l in _locais:
		if l.intersects(ret):
			return false
	var pr: PackedFloat32Array = cidade.predios
	for gx in range(floori(ret.position.x / 50.0), floori(ret.end.x / 50.0) + 1):
		for gz in range(floori(ret.position.y / 50.0), floori(ret.end.y / 50.0) + 1):
			for i in _hash.get(Vector2i(gx, gz), PackedInt32Array()):
				var o: int = i * 5
				var r2 := Rect2(pr[o] - pr[o + 2] * 0.5 - MARGEM, pr[o + 1] - pr[o + 3] * 0.5 - MARGEM, pr[o + 2] + MARGEM * 2.0, pr[o + 3] + MARGEM * 2.0)
				if r2.intersects(ret):
					return false
	return cidade._predio_ruim(x, z, sx, sz) == ""

static func _dist_ret(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)

# aqui não nasce prédio de preenchimento; se já tinha, o pedaço é refeito sem ele
func reservar(p: Vector2, raio := RAIO_OCUPA) -> void:
	_reservas.append([p, raio])
	for gx in range(floori((p.x - raio) / PEDACO), floori((p.x + raio) / PEDACO) + 1):
		for gz in range(floori((p.y - raio) / PEDACO), floori((p.y + raio) / PEDACO) + 1):
			var k := Vector2i(gx, gz)
			_lotes.erase(k)
			if _pedacos.has(k):
				var no: Node3D = _pedacos[k]
				n_predios -= int(no.get_meta("n", 0))
				no.free()
				_pedacos.erase(k)
				_montar(k)

# carros da história (e o jogador) que estejam dentro de um prédio de preenchimento: o lugar fica reservado
func _conferir_ocupados() -> void:
	var nos: Array = get_tree().get_nodes_in_group(GRUPO_OCUPA)
	if jogador != null and is_instance_valid(jogador):
		nos.append(jogador)
	for n in nos:
		if not (n is Node3D) or not (n as Node3D).is_inside_tree():
			continue
		var g: Vector3 = (n as Node3D).global_position
		var p := Vector2(g.x, g.z)
		if dentro(p, 1.5):
			reservar(p)

# p está dentro (ou a menos de folga m) de um prédio de preenchimento montado?
func dentro(p: Vector2, folga := 0.0) -> bool:
	var k := Vector2i(floori(p.x / PEDACO), floori(p.y / PEDACO))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var kk := k + Vector2i(dx, dz)
			if not _pedacos.has(kk):
				continue
			var l: PackedFloat32Array = _lotes.get(kk, PackedFloat32Array())
			for i in range(0, l.size(), 5):
				if _dist_ret(p, Rect2(l[i] - l[i + 2] * 0.5, l[i + 1] - l[i + 3] * 0.5, l[i + 2], l[i + 3])) <= folga:
					return true
	return false

# prédios de preenchimento perto de p (para pôr fachadas neles: historia/cenario.gd fachada_perto)
func lotes_perto(p: Vector2, raio: float) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	for gx in range(floori((p.x - raio) / PEDACO), floori((p.x + raio) / PEDACO) + 1):
		for gz in range(floori((p.y - raio) / PEDACO), floori((p.y + raio) / PEDACO) + 1):
			r.append_array(lotes(Vector2i(gx, gz)))
	return r

func _montar(k: Vector2i) -> void:
	var l := lotes(k)
	var no := Node3D.new()
	no.name = "Preenche_%d_%d" % [k.x, k.y]
	add_child(no)
	_pedacos[k] = no
	var qtd := l.size() / 5
	no.set_meta("n", qtd)
	n_predios += qtd
	if qtd == 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _malha
	mm.instance_count = qtd
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	no.add_child(corpo)
	for i in qtd:
		var o := i * 5
		var x: float = l[o]
		var z: float = l[o + 1]
		var sx: float = l[o + 2]
		var sz: float = l[o + 3]
		var h: float = l[o + 4]
		var base := -0.5                                 # enterrado um pouco no terreno (que fica abaixo da calçada)
		var alt: float = h + 0.5 + float(cidade.Y_RUA)
		var t := Transform3D(Basis.from_scale(Vector3(sx, alt, sz)), Vector3(x, base + alt * 0.5, z))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2(x, z))
		var tipo: int = 3 if (h > 75.0 and rng.randf() < 0.7) else [0, 1, 1, 2][rng.randi() % 4]
		var cor: Color = cidade.CORES_TIPO[tipo] * rng.randf_range(0.82, 1.12)
		cor.a = 1.0
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, cor)
		mm.set_instance_custom_data(i, Color(sx, alt, sz, cidade.dado_predio(tipo, rng.randf() * 0.98, true)))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(sx, alt, sz)
		cs.shape = bs
		cs.position = t.origin
		corpo.add_child(cs)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	no.add_child(mi)
