@tool
extends Node3D
# CIDADE · CONSTRUÇÕES (Liberty City em blocagem): céu e sol, chão (terra, mar, lagos, parques), ruas e prédios.
# Dados exportados do jogo em HTML (res://data/city.json, metros, x/z como no jogo).
# Mexa AQUI para: cor/altura/densidade dos prédios, ruas, parques, céu, neblina, sol.
# Quem usa: main.gd (cria o nó "Cidade") e mundo/colisao_mundo.gd (recebe dados + predios para a colisão).

const CELL := 20.0                          # resolução das máscaras (m)
const WORLD := Vector2(11000.0, 8600.0)     # metade do mundo (m)
const DOWNTOWN := Vector2(-1550.0, -237.0)  # centro (Algonquin): prédios mais altos

var W := 0
var H := 0
var land := PackedByteArray()
var park := PackedByteArray()
var road := PackedByteArray()
var built: Array[Node] = []
var is_built := false
var dados_cidade = null
var predios := PackedFloat32Array()         # x, z, tam_x, tam_z, altura de cada prédio (para a colisão)

func construir() -> void:
	is_built = true
	var t0 := Time.get_ticks_msec()
	W = int(WORLD.x * 2.0 / CELL)
	H = int(WORLD.y * 2.0 / CELL)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/city.json"))
	dados_cidade = data
	_env()
	_ground(data)
	_roads(data)
	_buildings()
	print("Cidade pronta em ", Time.get_ticks_msec() - t0, " ms")

func _adopt(n: Node) -> void:
	built.append(n)
	add_child(n)

func limpar() -> void:
	for n in built:
		n.queue_free()
	built.clear()
	is_built = false

# grava res://cidade.scn: a cidade vira uma cena de verdade, editável com as ferramentas da Godot
func salvar_cena() -> void:
	if not is_built:
		construir()
	var root := Node3D.new()
	root.name = "Cidade"
	for n in built:
		var d := n.duplicate()
		root.add_child(d)
		d.owner = root
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, "res://cidade.scn")
	print("Cena salva em res://cidade.scn (código ", err, " · 0 = ok)")

# ---------- ambiente ----------
func _env() -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.40, 0.75)
	sm.sky_horizon_color = Color(0.95, 0.65, 0.40)
	sm.ground_horizon_color = Color(0.95, 0.65, 0.40)
	sm.ground_bottom_color = Color(0.20, 0.20, 0.25)
	var sky := Sky.new()
	sky.sky_material = sm
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(0.90, 0.62, 0.42)
	env.fog_density = 0.00025
	var we := WorldEnvironment.new()
	we.environment = env
	_adopt(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30.0, -50.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	_adopt(sun)

# ---------- geometria utilitária ----------
func _pts(f: Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in range(0, f.size() - 1, 2):
		o.append(Vector2(f[i], f[i + 1]))
	return o

# triângulo voltado para cima (Godot: face frontal = sentido horário visto de cima)
func _tri(v: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var cr := (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
	v.append(a)
	if cr >= 0.0:
		v.append(b)
		v.append(c)
	else:
		v.append(c)
		v.append(b)

func _add_mesh(verts: PackedVector3Array, col: Color, shadow := false) -> void:
	if verts.is_empty():
		return
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_adopt(mi)

func _poly_mesh(polys: Array, y: float, col: Color) -> void:
	var v := PackedVector3Array()
	for p in polys:
		var idx := Geometry2D.triangulate_polygon(p)
		if idx.is_empty():
			push_warning("polígono não triangulado (ignorado)")
			continue
		for k in range(0, idx.size() - 2, 3):
			_tri(v, Vector3(p[idx[k]].x, y, p[idx[k]].y), Vector3(p[idx[k + 1]].x, y, p[idx[k + 1]].y), Vector3(p[idx[k + 2]].x, y, p[idx[k + 2]].y))
	_add_mesh(v, col)

# máscara por paridade (par-ímpar): terra com lagos furados, parques
func _fill(mask: PackedByteArray, polys: Array) -> void:
	var rows := []
	rows.resize(H)
	for r in H:
		rows[r] = []
	for p in polys:
		var n: int = p.size()
		for i in n:
			var a: Vector2 = p[i]
			var b: Vector2 = p[(i + 1) % n]
			if a.y == b.y:
				continue
			var r0 := int(ceil((minf(a.y, b.y) + WORLD.y) / CELL - 0.5))
			var r1 := int(floor((maxf(a.y, b.y) + WORLD.y) / CELL - 0.5))
			for r in range(maxi(r0, 0), mini(r1, H - 1) + 1):
				var zc := (r + 0.5) * CELL - WORLD.y
				rows[r].append(a.x + (zc - a.y) / (b.y - a.y) * (b.x - a.x))
	for r in H:
		var xs: Array = rows[r]
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			var c0 := maxi(int(ceil((xs[k] + WORLD.x) / CELL - 0.5)), 0)
			var c1 := mini(int(floor((xs[k + 1] + WORLD.x) / CELL - 0.5)), W - 1)
			for c in range(c0, c1 + 1):
				mask[r * W + c] = 1
			k += 2

# ---------- chão: mar, terra, lagos, parques ----------
func _ground(data) -> void:
	var lands_out := []
	var lakes := []
	var lpolys := []
	for l in data["lands"]:
		var p := _pts(l[1])
		lpolys.append(p)
		if int(l[0]) == 1:
			lakes.append(p)
		else:
			lands_out.append(p)
	var parks := []
	for f in data["parks"]:
		parks.append(_pts(f))
	land.resize(W * H)
	park.resize(W * H)
	road.resize(W * H)
	_fill(land, lpolys)
	_fill(park, parks)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(WORLD.x * 2.0, WORLD.y * 2.0)
	sea.mesh = pm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.16, 0.30, 0.38)
	smat.roughness = 0.35
	pm.material = smat
	sea.position.y = -0.5
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_adopt(sea)
	_poly_mesh(lands_out, 0.0, Color(0.38, 0.30, 0.24))
	_poly_mesh(lakes, 0.2, Color(0.16, 0.30, 0.38))
	_poly_mesh(parks, 0.4, Color(0.25, 0.42, 0.20))

# ---------- ruas ----------
func _roads(data) -> void:
	var v := PackedVector3Array()
	for rd in data["roads"]:
		var w: float = rd[0]
		var f: Array = rd[1]
		var hw := w * 0.5
		for i in range(0, f.size() - 3, 2):
			var a := Vector2(f[i], f[i + 1])
			var b := Vector2(f[i + 2], f[i + 3])
			var d := b - a
			var l := d.length()
			if l < 0.01:
				continue
			var nn := Vector2(-d.y, d.x) / l * hw
			var a1 := a + nn
			var a2 := a - nn
			var b1 := b + nn
			var b2 := b - nn
			_tri(v, Vector3(a1.x, 0.6, a1.y), Vector3(a2.x, 0.6, a2.y), Vector3(b1.x, 0.6, b1.y))
			_tri(v, Vector3(b1.x, 0.6, b1.y), Vector3(a2.x, 0.6, a2.y), Vector3(b2.x, 0.6, b2.y))
			# máscara: onde há rua (+ margem) não nascem prédios
			var rad := int(ceil((hw + 8.0) / CELL))
			var steps := int(ceil(l / 8.0))
			for s in range(steps + 1):
				var q := a + d * (float(s) / float(steps))
				var cc := int((q.x + WORLD.x) / CELL)
				var rr := int((q.y + WORLD.y) / CELL)
				for dr in range(-rad, rad + 1):
					for dc in range(-rad, rad + 1):
						if dr * dr + dc * dc > rad * rad + 1:
							continue
						var r2 := rr + dr
						var c2 := cc + dc
						if r2 >= 0 and r2 < H and c2 >= 0 and c2 < W:
							road[r2 * W + c2] = 1
	_add_mesh(v, Color(0.18, 0.18, 0.20))

# ---------- prédios (blocos) ----------
func _buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20081029
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.0009
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	predios = PackedFloat32Array()
	for lr in range(0, H - 1, 2):
		for lc in range(0, W - 1, 2):
			var n_land := 0
			var bad := false
			for o in [0, 1, W, W + 1]:
				var k: int = lr * W + lc + o
				n_land += land[k]
				if road[k] == 1 or park[k] == 1:
					bad = true
					break
			if bad or n_land < 4:
				continue
			var x := (lc + 1) * CELL - WORLD.x
			var z := (lr + 1) * CELL - WORLD.y
			if x > 5700.0 and z > -1487.0 and z < 2512.0:   # aeroporto / base militar: sem prédios
				continue
			if rng.randf() < 0.12:
				continue
			var d := Vector2(x, z).distance_to(DOWNTOWN) / 1500.0
			var h := 9.0 + (noise.get_noise_2d(x, z) + 1.0) * 16.0 + rng.randf() * 10.0 + 130.0 * exp(-d * d)
			var sx := rng.randf_range(20.0, 34.0)
			var sz := rng.randf_range(20.0, 34.0)
			var bx := x + rng.randf_range(-3.0, 3.0)
			var bz := z + rng.randf_range(-3.0, 3.0)
			xf.append(Transform3D(Basis.from_scale(Vector3(sx, h, sz)), Vector3(bx, h * 0.5 + 0.6, bz)))
			predios.append_array(PackedFloat32Array([bx, bz, sx, sz, h]))   # guardado para a colisão
			var g := rng.randf_range(0.42, 0.62)
			cols.append(Color(g, g * 0.95, g * 0.9))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mm.mesh.material = mat
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	_adopt(mi)
	print("Prédios: ", xf.size())
