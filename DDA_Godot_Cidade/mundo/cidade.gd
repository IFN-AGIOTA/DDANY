@tool
extends Node3D
# CIDADE · CONSTRUÇÕES (Liberty City): céu e sol, mar com ondas, terra com praias, parques com árvores,
# ruas com calçadas e faixas, e prédios com janelas. Dados do jogo em HTML (res://data/city.json, metros).
#   RUAS: cada trecho vira um retângulo e CADA PONTO ganha um disco do mesmo raio, então curvas, esquinas e
#   cruzamentos se encaixam sem buracos (igual à colisão, que trata a rua como "cápsula"). Pontas que quase
#   encostavam em outra rua (até 20 m) são puxadas para encostar de verdade. Calçada por baixo, asfalto por
#   cima, faixas no topo; faixas de pedestre e linha de parada nos cruzamentos.
#   PRÉDIOS: divididos em blocos de 1 km (o celular só desenha o que a câmera vê), com tipos (concreto,
#   tijolo, pedra, vidro), torres escalonadas no centro e caixas d'água nos telhados.
# Mexa AQUI para: densidade/altura dos prédios, largura da calçada, faixas, árvores, céu e sol.
# Aparência (cores, ondas, janelas): mundo/materiais_cidade.gd.
# Quem usa: main.gd (cria o nó "Cidade") e mundo/colisao_mundo.gd (recebe dados + predios para a colisão).

const Mat := preload("res://mundo/materiais_cidade.gd")
const AbandonoCls := preload("res://mundo/abandono.gd")

const CELL := 20.0                          # resolução das máscaras (m)
const WORLD := Vector2(11000.0, 8600.0)     # metade do mundo (m)
const DOWNTOWN := Vector2(-1550.0, -237.0)  # centro (Algonquin): prédios mais altos
const BLOCO := 1000.0                       # tamanho dos blocos de prédios/árvores (m)
const CALCADA := 5.0                        # largura da calçada de cada lado (m)
const PUXAR_PONTA := 20.0                   # pontas de rua a até 20 m de outra rua são ligadas

# alturas (iguais às da colisão em mundo/colisao_mundo.gd) e camadas de desenho
const Y_MAR := -0.5
const Y_TERRA := 0.0
const Y_LAGO := 0.2
const Y_PARQUE := 0.4
const Y_CALCADA := 0.55
const Y_RUA := 0.6
const CAMADA := {"mar": 0.0, "terra": 1.0, "lago": 2.0, "parque": 3.0, "calcada": 4.0, "rua": 5.0, "faixa": 6.0}

const BRANCO := Color(0.92, 0.92, 0.88)
const AMARELO := Color(0.95, 0.72, 0.15)

var W := 0
var H := 0
var land := PackedByteArray()
var park := PackedByteArray()
var road := PackedByteArray()
var built: Array[Node] = []
var is_built := false
var dados_cidade = null
var predios := PackedFloat32Array()         # x, z, tam_x, tam_z, altura de cada prédio (para a colisão)
var ambiente: Environment                   # céu/neblina (Opções › Gráficos mexe na neblina)
var sol: DirectionalLight3D                 # Opções › Gráficos › Sombras
var mat_predio: ShaderMaterial              # Opções › Gráficos › Detalhes dos shaders (janelas)
var mats_agua: Array[ShaderMaterial] = []   # Opções › Gráficos › Água
var mats_chao: Array[ShaderMaterial] = []   # terra, parque, calçada, asfalto (sombra dos prédios no chão: mundo/mato.gd)
var detalhes: Array[GeometryInstance3D] = []   # árvores e caixas d'água (Opções › Distância dos detalhes)
var detalhes_abandono: Array[GeometryInstance3D] = []   # carros, lixo, entulho

var _mascara: ImageTexture                  # terra (1) / água (0) para praias, mar raso e espuma
var _nos := {}                              # Vector2i (m) -> {"n": quantas ruas chegam, "r": raio}

func construir() -> void:
	is_built = true
	var t0 := Time.get_ticks_msec()
	W = int(WORLD.x * 2.0 / CELL)
	H = int(WORLD.y * 2.0 / CELL)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/city.json"))
	_ligar_pontas(data)
	dados_cidade = data
	_env()
	_ground(data)
	_roads(data)
	_buildings()
	_abandono()
	_arvores()
	print("Cidade pronta em ", Time.get_ticks_msec() - t0, " ms")

func _adopt(n: Node) -> void:
	built.append(n)
	add_child(n)

func limpar() -> void:
	for n in built:
		n.queue_free()
	built.clear()
	detalhes.clear()
	detalhes_abandono.clear()
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

# Opções › Gráficos: janelas nos prédios (shaders) e até onde aparecem árvores/caixas d'água
func aplicar_detalhes(nivel_shaders: int, nivel_distancia: int, agua_completa := true) -> void:
	for m in mats_agua:
		m.set_shader_parameter("completa", 1.0 if agua_completa else 0.0)
	if mat_predio != null:
		mat_predio.set_shader_parameter("detalhe", 0.0 if nivel_shaders <= 0 else (0.6 if nivel_shaders == 1 else 1.0))
	for m in mats_chao:
		m.set_shader_parameter("detalhe", 0.0 if nivel_shaders <= 0 else 1.0)
	var alcance: float = [500.0, 900.0, 1500.0, 2400.0][clampi(nivel_distancia, 0, 3)]
	for d in detalhes:
		if is_instance_valid(d):
			d.visibility_range_end = alcance

# ---------- ambiente ----------
func _env() -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.20, 0.33, 0.60)
	sm.sky_horizon_color = Color(0.98, 0.66, 0.42)
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.92, 0.64, 0.45)     # abaixo do horizonte = cor da névoa (sem faixa escura)
	sm.ground_bottom_color = Color(0.80, 0.56, 0.42)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sm
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.64, 0.45)
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.0006
	env.fog_aerial_perspective = 0.35       # ao longe a neblina pega a cor do céu (o "azul" do horizonte do DayZ)
	var we := WorldEnvironment.new()
	we.environment = env
	ambiente = env
	_adopt(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, -52.0, 0.0)
	sun.light_color = Color(1.0, 0.80, 0.60)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	_adopt(sun)
	sol = sun

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

func _malha(verts: PackedVector3Array, mat: Material, cores := PackedColorArray(), nome := "") -> void:
	if verts.is_empty():
		return
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	if not cores.is_empty():
		arr[Mesh.ARRAY_COLOR] = cores
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if nome != "":
		mi.name = nome
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_adopt(mi)

func _poly(v: PackedVector3Array, polys: Array, y: float) -> void:
	for p in polys:
		var idx := Geometry2D.triangulate_polygon(p)
		if idx.is_empty():
			push_warning("polígono não triangulado (ignorado)")
			continue
		for k in range(0, idx.size() - 2, 3):
			_tri(v, Vector3(p[idx[k]].x, y, p[idx[k]].y), Vector3(p[idx[k + 1]].x, y, p[idx[k + 1]].y), Vector3(p[idx[k + 2]].x, y, p[idx[k + 2]].y))

# retângulo plano de a até b com meia-largura hw
func _faixa(v: PackedVector3Array, a: Vector2, b: Vector2, hw: float, y: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var nn := Vector2(-d.y, d.x) / l * hw
	var a1 := a + nn
	var a2 := a - nn
	var b1 := b + nn
	var b2 := b - nn
	_tri(v, Vector3(a1.x, y, a1.y), Vector3(a2.x, y, a2.y), Vector3(b1.x, y, b1.y))
	_tri(v, Vector3(b1.x, y, b1.y), Vector3(a2.x, y, a2.y), Vector3(b2.x, y, b2.y))

# disco plano (fecha curvas, esquinas e cruzamentos)
func _disco(v: PackedVector3Array, c: Vector2, r: float, y: float, lados := 16) -> void:
	var cc := Vector3(c.x, y, c.y)
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		_tri(v, cc, Vector3(c.x + cos(a0) * r, y, c.y + sin(a0) * r), Vector3(c.x + cos(a1) * r, y, c.y + sin(a1) * r))

# retângulo colorido (faixas): centro, direção unitária, comprimento, largura
func _marca(v: PackedVector3Array, cores: PackedColorArray, c: Vector2, dir: Vector2, comp: float, larg: float, cor: Color) -> void:
	var a := c - dir * comp * 0.5
	var b := c + dir * comp * 0.5
	var n0 := v.size()
	_faixa(v, a, b, larg * 0.5, Y_RUA)
	for i in v.size() - n0:
		cores.append(cor)

# máscara por paridade (par-ímpar): terra com lagos furados, parques
func _fill(mask: PackedByteArray, polys: Array, valor := 1) -> void:
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
				mask[r * W + c] = valor
			k += 2

# ---------- chão: mar, terra (com praias), lagos, parques ----------
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
	# máscara terra/água em textura (com mipmaps = versão "borrada" para praias, mar raso e espuma)
	var terra_tex := PackedByteArray()
	terra_tex.resize(W * H)
	_fill(terra_tex, lpolys, 255)
	var img := Image.create_from_data(W, H, false, Image.FORMAT_L8, terra_tex)
	img.generate_mipmaps()
	_mascara = ImageTexture.create_from_image(img)
	var agua := Mat.material(Mat.AGUA, {"mascara": _mascara, "mundo": WORLD, "ondas_a": Mat.ondas(11, 0.012), "ondas_b": Mat.ondas(23, 0.02), "camada": CAMADA["mar"]})
	var sea := MeshInstance3D.new()
	sea.name = "Mar"
	var pm := PlaneMesh.new()
	pm.size = Vector2(WORLD.x * 2.0 + 20000.0, WORLD.y * 2.0 + 20000.0)    # vai além do mapa até o horizonte
	pm.material = agua
	sea.mesh = pm
	sea.position.y = Y_MAR
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_adopt(sea)
	var v := PackedVector3Array()
	_poly(v, lands_out, Y_TERRA)
	var mt := Mat.material(Mat.TERRA, {"mascara": _mascara, "mundo": WORLD, "camada": CAMADA["terra"]})
	_malha(v, mt, PackedColorArray(), "Terra")
	v = PackedVector3Array()
	_poly(v, lakes, Y_LAGO)
	var agua_lago: ShaderMaterial = agua.duplicate()
	agua_lago.set_shader_parameter("camada", CAMADA["lago"])
	_malha(v, agua_lago, PackedColorArray(), "Lagos")
	mats_agua = [agua, agua_lago]
	v = PackedVector3Array()
	_poly(v, parks, Y_PARQUE)
	var mp := Mat.material(Mat.PARQUE, {"camada": CAMADA["parque"]})
	_malha(v, mp, PackedColorArray(), "Parques")
	mats_chao = [mt, mp]

# ---------- ruas: ligar pontas soltas e marcar cruzamentos ----------
static func _no(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.y))

static func _proj(q: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var d := b - a
	var l2 := d.length_squared()
	if l2 < 0.0001:
		return a
	return a + d * clampf((q - a).dot(d) / l2, 0.0, 1.0)

func _ligar_pontas(data) -> void:
	var roads: Array = data["roads"]
	var hash := {}                     # célula 200 m -> [[rua, i], ...]
	for ri in roads.size():
		var f: Array = roads[ri][1]
		for i in range(0, f.size() - 3, 2):
			var a := Vector2(f[i], f[i + 1])
			var b := Vector2(f[i + 2], f[i + 3])
			for cx in range(floori(minf(a.x, b.x) / 200.0) - 1, floori(maxf(a.x, b.x) / 200.0) + 2):
				for cz in range(floori(minf(a.y, b.y) / 200.0) - 1, floori(maxf(a.y, b.y) / 200.0) + 2):
					var k := Vector2i(cx, cz)
					if not hash.has(k):
						hash[k] = []
					hash[k].append([ri, i])
	# quantas ruas passam/terminam em cada ponto
	_nos.clear()
	for rd in roads:
		var f: Array = rd[1]
		var hw: float = float(rd[0]) * 0.5
		var n := f.size() / 2
		for j in n:
			var k := _no(Vector2(f[j * 2], f[j * 2 + 1]))
			var e: Dictionary = _nos.get(k, {"n": 0, "r": 0.0})
			e["n"] += 1 if (j == 0 or j == n - 1) else 2
			e["r"] = maxf(e["r"], hw)
			_nos[k] = e
	# pontas: encostam no meio de outra rua (T) ou estão quase encostando (puxa até encostar)
	for ri in roads.size():
		var f: Array = roads[ri][1]
		var hw: float = float(roads[ri][0]) * 0.5
		for j in [0, f.size() / 2 - 1]:
			var q := Vector2(f[j * 2], f[j * 2 + 1])
			var e: Dictionary = _nos.get(_no(q), {"n": 1, "r": hw})
			if e["n"] >= 2:
				continue                  # já encosta na ponta de outra rua
			var melhor := INF
			var ponto := q
			var hw2 := 0.0
			for s in hash.get(Vector2i(floori(q.x / 200.0), floori(q.y / 200.0)), []):
				if s[0] == ri:
					continue
				var g: Array = roads[s[0]][1]
				var p := _proj(q, Vector2(g[s[1]], g[s[1] + 1]), Vector2(g[s[1] + 2], g[s[1] + 3]))
				var d := p.distance_to(q)
				if d < melhor:
					melhor = d
					ponto = p
					hw2 = float(roads[s[0]][0]) * 0.5
			if melhor <= PUXAR_PONTA:
				f[j * 2] = ponto.x
				f[j * 2 + 1] = ponto.y
				var k2 := _no(ponto)
				var e2: Dictionary = _nos.get(k2, {"n": 0, "r": 0.0})
				e2["n"] += 3              # encontro em T conta como cruzamento
				e2["r"] = maxf(e2["r"], maxf(hw, hw2))
				_nos[k2] = e2

func _cruzamento(p: Vector2) -> float:
	var e = _nos.get(_no(p))
	if e == null or e["n"] < 3:
		return -1.0
	return e["r"]

# ---------- ruas: calçada, asfalto e faixas ----------
func _roads(data) -> void:
	var calc := PackedVector3Array()
	var asf := PackedVector3Array()
	var mv := PackedVector3Array()
	var mc := PackedColorArray()
	for rd in data["roads"]:
		var w: float = rd[0]
		var f: Array = rd[1]
		var hw := w * 0.5
		var pts := _pts(f)
		for p in pts:
			_disco(calc, p, hw + CALCADA, Y_CALCADA)
			_disco(asf, p, hw, Y_RUA)
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			_faixa(calc, a, b, hw + CALCADA, Y_CALCADA)
			_faixa(asf, a, b, hw, Y_RUA)
			# quanto a rua vira em cada ponta (para as faixas se encontrarem em chanfro nas curvas)
			var giro_a := 0.0
			var giro_b := 0.0
			if i > 0:
				giro_a = (a - pts[i - 1]).angle_to(b - a)
			if i < pts.size() - 2:
				giro_b = (b - a).angle_to(pts[i + 2] - b)
			_faixas_trecho(mv, mc, a, b, hw, i == 0, i == pts.size() - 2, giro_a, giro_b)
			_mascara_rua(a, b, hw)
	var m_calc := Mat.material(Mat.CALCADA, {"camada": CAMADA["calcada"]})
	var m_asf := Mat.material(Mat.ASFALTO, {"camada": CAMADA["rua"]})
	_malha(calc, m_calc, PackedColorArray(), "Calcadas")
	_malha(asf, m_asf, PackedColorArray(), "Asfalto")
	mats_chao.append_array([m_calc, m_asf])
	_malha(mv, Mat.material(Mat.FAIXA, {"camada": CAMADA["faixa"]}), mc, "Faixas")

# faixas de um trecho: linha central (amarela dupla nas avenidas, tracejada branca nas ruas), divisórias de
# pista tracejadas, bordas, e faixa de pedestre + linha de parada perto dos cruzamentos
func _faixas_trecho(v: PackedVector3Array, c: PackedColorArray, a: Vector2, b: Vector2, hw: float, inicio: bool, fim: bool, giro_a := 0.0, giro_b := 0.0) -> void:
	var d := b - a
	var l := d.length()
	if l < 4.0:
		return
	var dir := d / l
	var nrm := Vector2(-dir.y, dir.x)
	var ra := _cruzamento(a)
	var rb := _cruzamento(b)
	var t0 := (ra + 7.5) if ra >= 0.0 else (0.0 if not inicio else 1.0)
	var t1 := l - ((rb + 7.5) if rb >= 0.0 else (0.0 if not fim else 1.0))
	# linha contínua no deslocamento lateral k: nas curvas encurta/estica k·tan(giro/2) para fechar em chanfro
	var ta := tan(clampf(giro_a, -1.2, 1.2) * 0.5) if ra < 0.0 else 0.0
	var tb := tan(clampf(giro_b, -1.2, 1.2) * 0.5) if rb < 0.0 else 0.0
	if t1 - t0 > 2.0:
		if hw >= 10.0:
			for k in [0.3, -0.3, hw - 1.0, -(hw - 1.0)]:
				var s0: float = t0 + k * ta
				var s1: float = t1 - k * tb
				if s1 - s0 > 0.5:
					_marca(v, c, a + dir * (s0 + s1) * 0.5 + nrm * k, dir, s1 - s0, 0.22 if absf(k) < 1.0 else 0.2, AMARELO if absf(k) < 1.0 else BRANCO)
			for lado in [-1.0, 1.0]:
				var t := t0 + 2.0
				while t + 5.0 < t1:                                                     # divisória de pistas
					_marca(v, c, a + dir * (t + 2.5) + nrm * lado * hw * 0.5, dir, 5.0, 0.18, BRANCO)
					t += 12.0
		else:
			var t := t0 + 1.0
			while t + 4.0 < t1:
				_marca(v, c, a + dir * (t + 2.0), dir, 4.0, 0.18, BRANCO)
				t += 9.0
	# faixa de pedestre (zebra) e linha de parada em cada ponta que chega num cruzamento
	for ponta in [[a, dir, ra], [b, -dir, rb]]:
		var r: float = ponta[2]
		if r < 0.0 or l < r * 2.0 + 10.0:
			continue
		var o: Vector2 = ponta[0]
		var di: Vector2 = ponta[1]
		var centro := o + di * (r + 3.0)
		var k := -hw + 1.6
		while k <= hw - 1.6:
			_marca(v, c, centro + nrm * k, di, 4.0, 0.75, BRANCO)
			k += 1.6
		_marca(v, c, o + di * (r + 6.2) - nrm * hw * 0.5, nrm, hw - 0.6, 0.45, BRANCO)

# máscara: onde há rua (+ margem) não nascem prédios
func _mascara_rua(a: Vector2, b: Vector2, hw: float) -> void:
	var d := b - a
	var l := d.length()
	var rad := int(ceil((hw + 8.0) / CELL))
	var steps := maxi(1, int(ceil(l / 8.0)))
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

# ---------- prédios ----------
const CORES_TIPO := [Color(0.60, 0.58, 0.55), Color(0.50, 0.29, 0.21), Color(0.74, 0.67, 0.55), Color(0.30, 0.34, 0.38)]

# usos dos prédios (decidem os móveis e o loot lá dentro: mundo/interiores.gd)
const USOS := ["residencial", "loja", "mercado", "restaurante", "escritorio", "farmacia", "delegacia", "clinica"]
const PESO_USOS := [0.42, 0.12, 0.08, 0.1, 0.1, 0.08, 0.05, 0.05]
const CHANCE_RUINA := 0.07
const CHANCE_ENTRA := 0.76                  # 76% dos prédios inteiros = mais de 70% de todos

var predio_info: Array = []                 # um Dictionary por prédio (mesma ordem de "predios")
var _mm_predios := {}                       # Vector2i -> MultiMesh dos prédios daquele bloco
var ruinas: Array = []                      # [x, z, tam_x, tam_z, altura] dos prédios destruídos
var abandono                                # mundo/abandono.gd (carros, obstáculos)

func _sortear_uso(r: RandomNumberGenerator, h: float) -> String:
	if h > 70.0:
		return "escritorio"
	var x := r.randf()
	for i in USOS.size():
		x -= PESO_USOS[i]
		if x <= 0.0:
			return USOS[i]
	return "residencial"

func _buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20081029
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.0009
	var blocos := {}                     # Vector2i -> [[Transform3D, cor, custom], ...]
	var caixas := {}                     # caixas d'água: Vector2i -> [Transform3D, ...]
	var extra := RandomNumberGenerator.new()
	extra.seed = 4242
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 9090
	predios = PackedFloat32Array()
	predio_info.clear()
	ruinas.clear()
	_mm_predios.clear()
	var n := 0
	var n_entra := 0
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
			# tipo: torres altas quase sempre de vidro; o resto concreto, tijolo ou pedra
			var tipo: int = 3 if (h > 75.0 and extra.randf() < 0.7) else [0, 1, 1, 2][extra.randi() % 4]
			var cor: Color = CORES_TIPO[tipo] * extra.randf_range(0.82, 1.12)
			cor.a = 1.0
			var sem := extra.randf() * 0.98
			var chave := Vector2i(floori(bx / BLOCO), floori(bz / BLOCO))
			if not blocos.has(chave):
				blocos[chave] = []
			var ruina := sorte.randf() < CHANCE_RUINA
			var info := {"x": bx, "z": bz, "sx": sx, "sz": sz, "tipo": tipo, "cor": cor, "sem": sem, "bloco": chave,
				"uso": _sortear_uso(sorte, h), "entra": false, "idx": -1, "ruina": ruina}
			if ruina:
				# prédio destruído: mais baixo, metade desabada, fuligem (tipo 4) e entulho em volta/em cima
				h = h * sorte.randf_range(0.3, 0.65)
				var h_b := h * sorte.randf_range(0.35, 0.8)
				var cz := Color(0.36, 0.34, 0.32) * sorte.randf_range(0.8, 1.1)
				cz.a = 1.0
				var pb := Vector2(bx + sx * 0.25, bz) if sx > sz else Vector2(bx, bz + sz * 0.25)
				if sx > sz:
					blocos[chave].append([Transform3D(Basis.from_scale(Vector3(sx * 0.5, h, sz)), Vector3(bx - sx * 0.25, Y_RUA + h * 0.5, bz)), cz, Color(sx * 0.5, h, sz, 4 + sem)])
					blocos[chave].append([Transform3D(Basis.from_scale(Vector3(sx * 0.5, h_b, sz * 0.85)), Vector3(bx + sx * 0.25, Y_RUA + h_b * 0.5, bz)), cz, Color(sx * 0.5, h_b, sz * 0.85, 4 + sem)])
				else:
					blocos[chave].append([Transform3D(Basis.from_scale(Vector3(sx, h, sz * 0.5)), Vector3(bx, Y_RUA + h * 0.5, bz - sz * 0.25)), cz, Color(sx, h, sz * 0.5, 4 + sem)])
					blocos[chave].append([Transform3D(Basis.from_scale(Vector3(sx * 0.85, h_b, sz * 0.5)), Vector3(bx, Y_RUA + h_b * 0.5, bz + sz * 0.25)), cz, Color(sx * 0.85, h_b, sz * 0.5, 4 + sem)])
				ruinas.append([bx, bz, sx, sz, h, pb.x, pb.y, h_b])
				info["h"] = h
				predios.append_array(PackedFloat32Array([bx, bz, sx, sz, h]))
				predio_info.append(info)
				continue
			predios.append_array(PackedFloat32Array([bx, bz, sx, sz, h]))   # guardado para a colisão
			var h1 := h
			if h > 60.0 and extra.randf() < 0.55:
				# torre escalonada: corpo + topo mais estreito
				h1 = h * extra.randf_range(0.6, 0.75)
				var k2 := extra.randf_range(0.55, 0.75)
				var h2 := h - h1 + extra.randf_range(4.0, 16.0)
				blocos[chave].append([Transform3D(Basis.from_scale(Vector3(sx * k2, h2, sz * k2)), Vector3(bx, Y_RUA + h1 + h2 * 0.5, bz)), cor, Color(sx * k2, h2, sz * k2, tipo + sem)])
			elif h < 70.0 and extra.randf() < 0.18:
				# caixa d'água de madeira no telhado (marca registrada de Nova York)
				if not caixas.has(chave):
					caixas[chave] = []
				var off := Vector3(extra.randf_range(-0.25, 0.25) * sx, 0.0, extra.randf_range(-0.25, 0.25) * sz)
				caixas[chave].append(Transform3D(Basis.from_scale(Vector3.ONE * extra.randf_range(0.8, 1.2)), Vector3(bx, Y_RUA + h1, bz) + off))
			var t := Transform3D(Basis.from_scale(Vector3(sx, h1, sz)), Vector3(bx, Y_RUA + h1 * 0.5, bz))
			info["h"] = h1
			info["t"] = t
			info["idx"] = blocos[chave].size()
			info["entra"] = sorte.randf() < CHANCE_ENTRA
			if info["entra"]:
				n_entra += 1
			blocos[chave].append([t, cor, Color(sx, h1, sz, tipo + sem)])
			predio_info.append(info)
	mat_predio = Mat.material(Mat.PREDIO, {"detalhe": 1.0})
	var caixa := BoxMesh.new()
	caixa.material = mat_predio
	for chave in blocos:
		var lista: Array = blocos[chave]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = caixa
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i][0])
			mm.set_instance_color(i, lista[i][1])
			mm.set_instance_custom_data(i, lista[i][2])
		n += lista.size()
		_mm_predios[chave] = mm
		var mi := MultiMeshInstance3D.new()
		mi.name = "Predios_%d_%d" % [chave.x, chave.y]
		mi.multimesh = mm
		_adopt(mi)
	var malha_caixa := _malha_caixa_dagua()
	for chave in caixas:
		var lista: Array = caixas[chave]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malha_caixa
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "CaixasDagua_%d_%d" % [chave.x, chave.y]
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 1500.0
		_adopt(mi)
		detalhes.append(mi)
	print("Prédios: ", predios.size() / 5, " (", n, " blocos de malha) · com entrada: ", n_entra, " · em ruína: ", ruinas.size())

# esconde/mostra o bloco de um prédio (quando o interior dele está montado perto do jogador)
func esconder_predio(i: int, esconder: bool) -> void:
	var info: Dictionary = predio_info[i]
	if info["idx"] < 0:
		return
	var mm: MultiMesh = _mm_predios[info["bloco"]]
	if esconder:
		mm.set_instance_transform(info["idx"], Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(info["x"], -500.0, info["z"])))
	else:
		mm.set_instance_transform(info["idx"], info["t"])

# ---------- cidade abandonada (carros, barreiras, lixo, entulho) ----------
func _abandono() -> void:
	var dens := 1.0
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else null
	if cfg != null:
		dens = [0.45, 0.75, 1.0][clampi(int(cfg.g.get("den", 1)), 0, 2)]
	abandono = AbandonoCls.new()
	abandono.construir(self, ruinas, dens)
	for no in abandono.nos:
		_adopt(no)
		detalhes_abandono.append(no)
	print("Carros: ", abandono.carros.size(), " · obstáculos: ", abandono.obstaculos.size() / 7)

# junta várias malhas prontas (cilindro, cone...) numa só, deslocadas, cada uma com seu material
static func _juntar(partes: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	for p in partes:
		var arr: Array = (p[0] as PrimitiveMesh).get_mesh_arrays()
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in vs.size():
			vs[i] += p[1]
		arr[Mesh.ARRAY_VERTEX] = vs
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, p[2])
	return am

static func _mat_simples(cor: Color, rough := 0.9, cor_da_instancia := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rough
	m.vertex_color_use_as_albedo = cor_da_instancia
	return m

func _malha_caixa_dagua() -> ArrayMesh:
	var madeira := _mat_simples(Color(0.36, 0.25, 0.17))
	var ferro := _mat_simples(Color(0.18, 0.17, 0.16), 0.6)
	var corpo := CylinderMesh.new()
	corpo.top_radius = 2.0
	corpo.bottom_radius = 2.0
	corpo.height = 4.0
	corpo.radial_segments = 10
	corpo.rings = 1
	var teto := CylinderMesh.new()
	teto.top_radius = 0.0
	teto.bottom_radius = 2.2
	teto.height = 1.4
	teto.radial_segments = 10
	teto.rings = 1
	var base := BoxMesh.new()
	base.size = Vector3(3.6, 2.0, 3.6)
	return _juntar([[base, Vector3(0, 1.0, 0), ferro], [corpo, Vector3(0, 4.0, 0), madeira], [teto, Vector3(0, 6.7, 0), ferro]])

# ---------- árvores nos parques ----------
const MAX_ARVORES := 9000

func _arvores() -> void:
	var celulas := PackedInt32Array()
	for i in W * H:
		if park[i] == 1 and land[i] == 1 and road[i] == 0:
			celulas.append(i)
	if celulas.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	var chance := minf(0.6, float(MAX_ARVORES) / celulas.size())
	var blocos := {}
	for i in celulas:
		if rng.randf() > chance:
			continue
		var x := (i % W + rng.randf()) * CELL - WORLD.x
		var z := (i / W + rng.randf()) * CELL - WORLD.y
		var s := rng.randf_range(0.7, 1.45)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s)), Vector3(x, Y_PARQUE, z))
		var verde := Color(0.20, 0.36, 0.14) * rng.randf_range(0.75, 1.25)
		if rng.randf() < 0.15:
			verde = Color(0.55, 0.40, 0.15) * rng.randf_range(0.8, 1.1)    # algumas já amareladas (outono)
		verde.a = 1.0
		var chave := Vector2i(floori(x / BLOCO), floori(z / BLOCO))
		if not blocos.has(chave):
			blocos[chave] = []
		blocos[chave].append([t, verde])
	var tronco := CylinderMesh.new()
	tronco.top_radius = 0.18
	tronco.bottom_radius = 0.3
	tronco.height = 3.0
	tronco.radial_segments = 5
	tronco.rings = 1
	var copa := SphereMesh.new()
	copa.radius = 2.6
	copa.height = 4.6
	copa.radial_segments = 7
	copa.rings = 4
	var malha := _juntar([[tronco, Vector3(0, 1.5, 0), _mat_simples(Color(0.30, 0.22, 0.15))], [copa, Vector3(0, 4.4, 0), _mat_simples(Color.WHITE, 1.0, true)]])
	var total := 0
	for chave in blocos:
		var lista: Array = blocos[chave]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = malha
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i][0])
			mm.set_instance_color(i, lista[i][1])
		total += lista.size()
		var mi := MultiMeshInstance3D.new()
		mi.name = "Arvores_%d_%d" % [chave.x, chave.y]
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 1500.0
		_adopt(mi)
		detalhes.append(mi)
	print("Árvores: ", total)
