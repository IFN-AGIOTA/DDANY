extends Node3D
# 1.13 · ÁREA LIBERADA DE CADA MISSÃO (modo história): onde o jogador pode ir, de acordo com a história. Em cada rua que
# SAI da área fica um BLOQUEIO de verdade, com colisão (nada de parede invisível solta):
#   "corrida": cavaletes listrados e cones (a rota fechada pelos próprios corredores / obras)
#   "policia": cavaletes azuis e brancos "POLICE LINE", cones e uma viatura atravessada com o giroflex piscando
# E o GPS (hud/rota_gps.gd) desliga as ruas de fora: a linha nunca manda para um bloqueio.
# corredor(caminho, metros): a área é tudo a até "metros" do caminho (a corrida).
# Mexa AQUI para: o desenho dos bloqueios, a distância entre eles e as cores.

const RotaGps := preload("res://hud/rota_gps.gd")
const Abandono := preload("res://mundo/abandono.gd")

var dados_cidade = null
var mundo = null                     # mundo/colisao_mundo.gd (altura do chão)
var bloqueios: Array = []            # [posição Vector3, direção Vector2 (para fora), largura]
var _corpo: StaticBody3D
var _luzes: Array = []               # [OmniLight3D vermelha, OmniLight3D azul] das viaturas
var _t := 0.0

static var _tex_listra: ImageTexture = null

func corredor(caminho: PackedVector2Array, metros: float, estilo := "corrida") -> void:
	limpar()
	RotaGps.limitar_corredor(caminho, metros + 6.0)
	var saidas := RotaGps.saidas_do_corredor(dados_cidade, caminho, metros)
	_montar(saidas, estilo)

func poligono(poli: PackedVector2Array, estilo := "policia") -> void:
	limpar()
	RotaGps.limitar_area(poli)
	_montar(RotaGps.saidas_da_area(dados_cidade, poli), estilo)

func limpar() -> void:
	RotaGps.limitar_area(PackedVector2Array())
	for c in get_children():
		c.queue_free()
	bloqueios.clear()
	_luzes.clear()
	_corpo = null

func _altura(x: float, z: float) -> float:
	return mundo.altura(x, z) if mundo != null else 0.6

func _montar(saidas: Array, estilo: String) -> void:
	_corpo = StaticBody3D.new()
	_corpo.collision_layer = 1
	_corpo.collision_mask = 0
	add_child(_corpo)
	var tablas: Array = []             # Transform3D das tábuas (listradas)
	var pes: Array = []
	var cones: Array = []
	var viaturas: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	var policia := estilo == "policia"
	# junta saídas muito perto (ruas largas cruzadas por vários trechos)
	var usados: Array = []
	for s in saidas:
		var p: Vector2 = s[0]
		var perto := false
		for u in usados:
			if (u as Vector2).distance_to(p) < 9.0:
				perto = true
				break
		if perto:
			continue
		usados.append(p)
		var dir: Vector2 = s[1]
		var larg: float = clampf(float(s[2]), 8.0, 40.0)
		var lado := dir.orthogonal()
		var y := _altura(p.x, p.y)
		bloqueios.append([Vector3(p.x, y, p.y), dir, larg])
		var giro := atan2(lado.x, lado.y)              # as tábuas ficam atravessadas na rua
		var n := maxi(2, int(ceil(larg / 2.4)))
		for k in n:
			var off := (float(k) - (n - 1) * 0.5) * (larg / n)
			var c := p + lado * off + dir * rng.randf_range(-0.3, 0.3)
			var yy := _altura(c.x, c.y)
			var b := Basis(Vector3.UP, giro + rng.randf_range(-0.08, 0.08))
			for h in [0.55, 0.95]:
				tablas.append(Transform3D(b, Vector3(c.x, yy + h, c.y)))
			for lx in [-0.85, 0.85]:
				for lz in [-0.22, 0.22]:
					var q: Vector3 = b * Vector3(lx, 0, lz)
					var tp := Transform3D(b * Basis(Vector3.RIGHT, -signf(lz) * 0.22), Vector3(c.x + q.x, yy + 0.5, c.y + q.z))
					pes.append(tp)
		# cones na frente (lado de dentro)
		for k in int(larg / 3.0):
			var c2 := p - dir * rng.randf_range(1.2, 2.6) + lado * rng.randf_range(-larg * 0.45, larg * 0.45)
			cones.append(Transform3D(Basis(), Vector3(c2.x, _altura(c2.x, c2.y), c2.y)))
		if policia and larg > 9.0:
			var cv := p + dir * 3.2 + lado * rng.randf_range(-larg * 0.2, larg * 0.2)
			viaturas.append(Transform3D(Basis(Vector3.UP, giro + rng.randf_range(-0.25, 0.25)), Vector3(cv.x, _altura(cv.x, cv.y), cv.y)))
		# colisão: uma caixa atravessando a rua inteira
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(larg + 2.0, 2.4, 0.8)
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, giro), Vector3(p.x, y + 1.2, p.y))
		_corpo.add_child(cs)
	# desenho (MultiMesh: poucas chamadas de desenho para todos os bloqueios)
	var mat_tabua := StandardMaterial3D.new()
	mat_tabua.albedo_texture = _listras(policia)
	mat_tabua.uv1_scale = Vector3(3, 1, 1)
	mat_tabua.roughness = 0.6
	var tb := BoxMesh.new()
	tb.size = Vector3(2.1, 0.24, 0.05)
	tb.material = mat_tabua
	_mm(tb, tablas)
	var mat_pe := StandardMaterial3D.new()
	mat_pe.albedo_color = Color(0.85, 0.85, 0.82) if policia else Color(0.95, 0.42, 0.08)
	var pb := BoxMesh.new()
	pb.size = Vector3(0.06, 1.05, 0.06)
	pb.material = mat_pe
	_mm(pb, pes)
	var mat_cone := StandardMaterial3D.new()
	mat_cone.albedo_color = Color(1.0, 0.38, 0.05)
	mat_cone.emission_enabled = true
	mat_cone.emission = Color(0.35, 0.1, 0.0)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.17
	cm.height = 0.7
	cm.radial_segments = 10
	cm.material = mat_cone
	var cones_ok: Array = []
	for t in cones:
		cones_ok.append(Transform3D(t.basis, t.origin + Vector3(0, 0.35, 0)))
	_mm(cm, cones_ok)
	if not viaturas.is_empty():
		_viaturas(viaturas)

func _mm(malha: Mesh, lista: Array) -> void:
	if lista.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malha
	mm.instance_count = lista.size()
	for i in lista.size():
		mm.set_instance_transform(i, lista[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# viatura atravessada: o sedã da cidade em preto e branco, barra de luzes e o giroflex de verdade (2 luzes piscando)
func _viaturas(lista: Array) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.12, 0.13, 0.16)
	mat.metallic = 0.3
	mat.roughness = 0.45
	var malha := Abandono.modelo("sedan")
	for t in lista:
		var mi := MeshInstance3D.new()
		mi.mesh = malha
		mi.material_override = mat
		mi.transform = t * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO)
		add_child(mi)
		for k in 2:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.5, 0.1, 0.18)
			var m2 := StandardMaterial3D.new()
			var cor := Color(1, 0.1, 0.1) if k == 0 else Color(0.15, 0.3, 1.0)
			m2.albedo_color = cor
			m2.emission_enabled = true
			m2.emission = cor
			m2.emission_energy_multiplier = 3.0
			bm.material = m2
			var luz := MeshInstance3D.new()
			luz.mesh = bm
			luz.transform = t * Transform3D(Basis(), Vector3((k - 0.5) * 0.5, 1.55, 0.0))
			add_child(luz)
			var o := OmniLight3D.new()
			o.light_color = cor
			o.omni_range = 9.0
			o.light_energy = 2.2
			o.transform = t * Transform3D(Basis(), Vector3((k - 0.5) * 0.6, 1.9, 0.0))
			add_child(o)
			_luzes.append(o)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.85, 1.3, 4.4)
		cs.shape = bs
		cs.transform = t * Transform3D(Basis(), Vector3(0, 0.75, 0))
		_corpo.add_child(cs)

func _process(dt: float) -> void:
	if _luzes.is_empty():
		return
	_t += dt
	var fase := int(_t * 6.0) % 2
	for i in _luzes.size():
		(_luzes[i] as OmniLight3D).visible = (i % 2) == fase

static func _listras(policia: bool) -> ImageTexture:
	var img := Image.create(64, 16, false, Image.FORMAT_RGB8)
	var a := Color(0.1, 0.2, 0.55) if policia else Color(0.95, 0.38, 0.05)
	var b := Color(0.95, 0.95, 0.92)
	for x in 64:
		for y in 16:
			img.set_pixel(x, y, a if int((x + y) / 8) % 2 == 0 else b)
	return ImageTexture.create_from_image(img)

# distância (m) do jogador até o bloqueio mais perto (para o policial falar)
func bloqueio_perto(p: Vector3) -> Array:
	var md := INF
	var mb: Array = []
	for b in bloqueios:
		var d := Vector2(p.x - b[0].x, p.z - b[0].z).length()
		if d < md:
			md = d
			mb = b
	return [md, mb]
