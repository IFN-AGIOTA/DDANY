@tool
extends Node3D
# CIDADE · CONSTRUÇÕES (Liberty City): céu e sol, mar com ondas, terra com praias, parques com árvores,
# ruas com calçadas e faixas, e prédios com janelas. Dados do jogo em HTML (res://data/city.json, metros).
#   RUAS: cada trecho vira um retângulo e CADA PONTO ganha um disco do mesmo raio, então curvas, esquinas e
#   cruzamentos se encaixam sem buracos (igual à colisão, que trata a rua como "cápsula"). Pontas que quase
#   encostavam em outra rua (até 20 m) são puxadas para encostar de verdade. Calçada por baixo, asfalto por
#   cima, faixas no topo; faixas de pedestre e linha de parada nos cruzamentos.
#   PRÉDIOS: divididos em blocos de 500 m (o celular só desenha o que a câmera vê e o que não está escondido
#   atrás de outros prédios: mundo/oclusao.gd), com tipos (concreto,
#   tijolo, pedra, vidro), torres escalonadas no centro e caixas d'água nos telhados.
# Mexa AQUI para: densidade/altura dos prédios, largura da calçada, faixas, árvores, céu e sol.
# Aparência (cores, ondas, janelas): mundo/materiais_cidade.gd.
# Quem usa: main.gd (cria o nó "Cidade") e mundo/colisao_mundo.gd (recebe dados + predios para a colisão).

const Mat := preload("res://mundo/materiais_cidade.gd")
const AbandonoCls := preload("res://mundo/abandono.gd")
const FachadasCls := preload("res://mundo/fachadas.gd")
const OclusaoCls := preload("res://mundo/oclusao.gd")
const LocaisCls := preload("res://mundo/locais.gd")
const Cenario := preload("res://mundo/cenario.gd")

const CELL := 20.0                          # resolução das máscaras (m)
const WORLD := Vector2(11000.0, 8600.0)     # metade do mundo (m)
const DOWNTOWN := Vector2(-1550.0, -237.0)  # centro (Algonquin): prédios mais altos
const BLOCO_ARVORE := 250.0                 # blocos de árvores
const BLOCO_PREDIO := 500.0                 # blocos de prédios: menores = a câmera e a oclusão descartam mais
const CALCADA := 5.0                        # largura da calçada de cada lado (m)
const PUXAR_PONTA := 20.0                   # pontas de rua a até 20 m de outra rua são ligadas

# alturas (iguais às da colisão em mundo/colisao_mundo.gd) e camadas de desenho
const Y_MAR := -0.5
const Y_TERRA := 0.0
const Y_LAGO := 0.2
const Y_PARQUE := 0.4
const Y_CALCADA := 0.55
const Y_RUA := 0.6
# 0.82: faixas pintadas 6 mm acima do asfalto (na mesma altura piscavam). Elas usam a MESMA camada do asfalto: a
# camada é um empurrão de profundidade e, com mais empurrão, de longe as faixas passavam por cima dos pneus dos
# carros e da base das coisas (pareciam flutuar). Os 6 mm já separam bem (rasante, viram metros de profundidade).
const FAIXA_ACIMA := 0.006
const CAMADA := {"mar": 0.0, "terra": 1.0, "lago": 2.0, "parque": 3.0, "lote": 3.5, "calcada": 4.0, "rua": 5.0, "faixa": 5.0}

const BRANCO := Color(0.92, 0.92, 0.88)
const AMARELO := Color(0.95, 0.72, 0.15)

var W := 0
var H := 0
var land := PackedByteArray()
var park := PackedByteArray()
var road := PackedByteArray()
var lote := PackedByteArray()              # 1 = célula de 20 m com prédio: chão na altura da calçada (mundo/colisao_mundo.gd)
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
var detalhes_fachada: Array[GeometryInstance3D] = []    # escadas de incêndio e ar-condicionado (mundo/fachadas.gd)
var detalhes_veg: Array[GeometryInstance3D] = []        # 0.69: árvores/plantas baixadas de perto (meta "alcance" = no nível 2)
var oclusao                                 # mundo/oclusao.gd (caixas oclusoras dos prédios)

var _mascara: ImageTexture                  # terra (1) / água (0) para praias, mar raso e espuma
var _nos := {}                              # Vector2i (m) -> {"n": quantas ruas chegam, "r": raio}

# 0.99.1 · FATIAR: com a tela de carregamento (main.gd liga "fatiar"), as partes pesadas param a cada FATIA_MS e
# deixam a tela desenhar um quadro (a barra e as brasas não congelam); "progresso" diz quanto da etapa já foi
# (0..1, -1 = não sabe). Sem a tela (servidor, editor, testes) nada para: tudo é montado de uma vez, como antes.
const FATIA_MS := 35
var fatiar := false
var progresso := -1.0
var t_fatia := 0
func respirar(feito: int, total: int) -> void:
	progresso = maxf(progresso, clampf(float(feito) / float(maxi(total, 1)), 0.0, 1.0))
	await pausa()

# só a parada (sem mexer no progresso)
func pausa() -> void:
	if fatiar and Time.get_ticks_msec() - t_fatia > FATIA_MS and is_inside_tree():
		await get_tree().process_frame
		t_fatia = Time.get_ticks_msec()

func construir() -> void:
	var t0 := Time.get_ticks_msec()
	for e in etapas():
		e[2].call()
	print("Cidade pronta em ", Time.get_ticks_msec() - t0, " ms")

# 0.99: construir() em ETAPAS, na ordem: a tela de carregamento (menu/tela_carregamento.gd) chama uma por quadro e
# mostra o texto; o peso é o tempo relativo de cada uma (a barra anda proporcional) · [texto, peso, Callable]
func etapas() -> Array:
	var r: Array = [
		["Lendo o mapa de Nova York", 1.5, _comecar],
		["Chão, praias e o mar", 1.2, func(): await _ground(dados_cidade)],
		["Ruas e avenidas", 16.0, func(): await _roads(dados_cidade)],
		["Levantando os prédios", 11.0, _buildings],
		["Quarteirões e calçadas", 5.0, _lotes],
		["Escadas de incêndio e fachadas", 5.0, _fachadas],
	]
	var ab := AbandonoCls.new()              # só vira o "abandono" da cidade quando estas etapas rodam
	r.append(["Espalhando o abandono", 0.5, func(): _abandono_comecar(ab)])
	r.append_array(ab.etapas())
	r.append(["Juntando o abandono", 1.3, _abandono_fim])
	r.append(["Árvores e canteiros", 8.0, _arvores])
	r.append(["Escondendo o que a câmera não vê", 3.0, _oclusao])
	return r

func _comecar() -> void:
	is_built = true
	W = int(WORLD.x * 2.0 / CELL)
	H = int(WORLD.y * 2.0 / CELL)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/city.json"))
	_ligar_pontas(data)
	dados_cidade = data
	_env()

func _adopt(n: Node) -> void:
	built.append(n)
	add_child(n)

func limpar() -> void:
	for n in built:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.queue_free()
			else:
				n.free()                   # chunk descarregado (fora da cena: mundo/chunks.gd)
	built.clear()
	detalhes.clear()
	detalhes_abandono.clear()
	detalhes_veg.clear()
	detalhes_fachada.clear()
	oclusao = null
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
	for d in detalhes_fachada:
		if is_instance_valid(d):
			d.visibility_range_end = FachadasCls.ALCANCES[clampi(nivel_distancia, 0, 3)]
	var fator: float = [0.6, 0.8, 1.0, 1.3][clampi(nivel_distancia, 0, 3)]
	for d in detalhes_veg:
		if is_instance_valid(d):
			d.visibility_range_end = float(d.get_meta("alcance", 120.0)) * fator

# 0.84: Opções › Gráficos "Detalhes das texturas" (0..3) e "Filtragem anisotrópica" (1, 2, 4, 8, 16) no chão
const VIES_TEX := [1.5, 0.8, 0.3, 0.0]
func aplicar_texturas(nivel_tex: int, aniso: int) -> void:
	for m in mats_chao:
		if is_instance_valid(m):
			m.set_shader_parameter("vies_tex", VIES_TEX[clampi(nivel_tex, 0, 3)])
			m.set_shader_parameter("aniso", float(clampi(aniso, 1, 16)))

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
	sky.radiance_size = Sky.RADIANCE_SIZE_64          # reflexo do céu pequeno: refazer custa bem menos no celular
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
	env.fog_aerial_perspective = 0.35      # ao longe a neblina pega a cor do céu (o "azul" do horizonte do DayZ)
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

# OTIMIZAÇÃO: o chão (terra, parques, lagos, calçadas, asfalto, faixas) era UMA malha para a cidade inteira, que a
# placa de vídeo processava toda em todo quadro. Agora cada malha é cortada em PEDAÇOS de PEDACO_CHAO metros
# (cada triângulo vai para o pedaço do seu centro): só os pedaços que aparecem na câmera são desenhados.
const PEDACO_CHAO := 2000.0                 # 0.79: 4 x 4 chunks (antes 1000): chão é barato em triângulos, caro em chamadas de desenho
const PEDACO_FAIXAS := 500.0                # faixas somem a LONGE_FAIXAS do centro do pedaço: pedaço pequeno
const LONGE_FAIXAS := 700.0                  # faixas pintadas somem de longe (nem dá para ver)

func _malha(verts: PackedVector3Array, mat: Material, cores := PackedColorArray(), nome := "", pedaco := PEDACO_CHAO) -> void:
	if verts.is_empty():
		return
	var com_cor := not cores.is_empty()
	var pv := {}                               # Vector2i -> PackedVector3Array
	var pc := {}                               # Vector2i -> PackedColorArray
	for t in range(0, verts.size() - 2, 3):
		if t % 12288 == 0:
			await pausa()
		var a := verts[t]
		var b := verts[t + 1]
		var c := verts[t + 2]
		var k := Vector2i(floori((a.x + b.x + c.x) / (3.0 * pedaco)), floori((a.z + b.z + c.z) / (3.0 * pedaco)))
		if not pv.has(k):
			pv[k] = PackedVector3Array()
			if com_cor:
				pc[k] = PackedColorArray()
		var v: PackedVector3Array = pv[k]
		v.append(a)
		v.append(b)
		v.append(c)
		pv[k] = v
		if com_cor:
			var cc: PackedColorArray = pc[k]
			cc.append(cores[t])
			cc.append(cores[t + 1])
			cc.append(cores[t + 2])
			pc[k] = cc
	for k in pv:
		await pausa()
		var vv: PackedVector3Array = pv[k]
		var normals := PackedVector3Array()
		normals.resize(vv.size())
		normals.fill(Vector3.UP)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vv
		arr[Mesh.ARRAY_NORMAL] = normals
		if com_cor:
			arr[Mesh.ARRAY_COLOR] = pc[k]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		if nome != "":
			mi.name = "%s_%d_%d" % [nome, k.x, k.y]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if nome == "Faixas":
			mi.visibility_range_end = LONGE_FAIXAS
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
	_faixa(v, a, b, larg * 0.5, Y_RUA + FAIXA_ACIMA)
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
	lote.resize(W * H)
	lote.fill(0)
	_lote_idx.clear()
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
	var p_terra := {"mascara": _mascara, "mundo": WORLD, "camada": CAMADA["terra"]}
	p_terra.merge(Mat.texturas_chao())
	var mt := Mat.material(Mat.TERRA, p_terra)
	await _malha(v, mt, PackedColorArray(), "Terra")
	v = PackedVector3Array()
	_poly(v, lakes, Y_LAGO)
	var agua_lago: ShaderMaterial = agua.duplicate()
	agua_lago.set_shader_parameter("camada", CAMADA["lago"])
	await _malha(v, agua_lago, PackedColorArray(), "Lagos")
	mats_agua = [agua, agua_lago]
	v = PackedVector3Array()
	_poly(v, parks, Y_PARQUE)
	var mp := Mat.material(Mat.PARQUE, {"camada": CAMADA["parque"]})
	await _malha(v, mp, PackedColorArray(), "Parques")
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
	var n_rua := 0
	for rd in data["roads"]:
		n_rua += 1
		await respirar(n_rua, data["roads"].size())
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
	await _malha(calc, m_calc, PackedColorArray(), "Calcadas")
	await _malha(asf, m_asf, PackedColorArray(), "Asfalto")
	mats_chao.append_array([m_calc, m_asf])
	await _malha(mv, Mat.material(Mat.FAIXA, {"camada": CAMADA["faixa"]}), mc, "Faixas", PEDACO_FAIXAS)

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
var locais_casca: Array = []                # 0.68: casca de longe de cada local especial (mundo/locais.gd), mesma ordem de LOCAIS
var remapa_v2 := PackedInt32Array()         # número do prédio na 0.43..0.67 -> agora (-1 = saiu para dar lugar a um local especial)
var remapa_v3 := PackedInt32Array()         # 0.78: número do prédio na 0.68..0.77 -> agora (-1 = saiu para os locais novos)

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
	_preparar_filtro(dados_cidade)
	remapa_predios = PackedInt32Array()
	removidos = {"agua": 0, "rua": 0, "local": 0}
	pos_removidos = PackedVector2Array()
	remapa_v2 = PackedInt32Array()
	remapa_v3 = PackedInt32Array()
	var rets_locais: Array[Rect2] = []
	for i in LocaisCls.LOCAIS.size():
		rets_locais.append(LocaisCls.retangulo(i, 3.0))
	var n_068: int = LocaisCls.N_LOCAIS_068
	for lr in range(0, H - 1, 2):
		await respirar(lr, H * 2)                   # a grade é ~metade do tempo; os blocos, a outra metade
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
			# em cima/perto da água ou da rua/calçada? (os sorteios continuam iguais para os outros prédios não mudarem)
			var fora := _predio_ruim(bx, bz, sx, sz)
			if fora == "":
				# 0.68: no terreno de um local especial (posto, hospital, mercado, armazém) o prédio comum sai
				var planta := Rect2(bx - sx * 0.5, bz - sz * 0.5, sx, sz)
				var no_antigo := false                  # num local da 0.68 (já saía antes)
				var no_novo := false                    # 0.78: num local novo (delegacia, escola, metrô, quartel)
				for il in rets_locais.size():
					if rets_locais[il].intersects(planta):
						if il < n_068:
							no_antigo = true
						else:
							no_novo = true
				var no_local := no_antigo or no_novo
				remapa_v2.append(-1 if no_local else predio_info.size())
				if not no_antigo:
					remapa_v3.append(-1 if no_novo else predio_info.size())
				if no_local:
					fora = "local"
			remapa_predios.append(-1 if fora != "" else predio_info.size())
			if fora != "":
				removidos[fora] += 1
				pos_removidos.append(Vector2(bx, bz))
			# tipo: torres altas quase sempre de vidro; o resto concreto, tijolo ou pedra
			var tipo: int = 3 if (h > 75.0 and extra.randf() < 0.7) else [0, 1, 1, 2][extra.randi() % 4]
			var cor: Color = CORES_TIPO[tipo] * extra.randf_range(0.82, 1.12)
			cor.a = 1.0
			var sem := extra.randf() * 0.98
			if fora == "":
				for o in [0, 1, W, W + 1]:
					lote[lr * W + lc + o] = 1
					_lote_idx.append(lr * W + lc + o)
			var chave := Vector2i(floori(bx / BLOCO_PREDIO), floori(bz / BLOCO_PREDIO))
			if fora == "" and not blocos.has(chave):
				blocos[chave] = []
			var lista_bloco: Array = blocos[chave] if fora == "" else []    # removido: monta "de mentira" e joga fora
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
					lista_bloco.append([Transform3D(Basis.from_scale(Vector3(sx * 0.5, h, sz)), Vector3(bx - sx * 0.25, Y_RUA + h * 0.5, bz)), cz, Color(sx * 0.5, h, sz, 4 + sem)])
					lista_bloco.append([Transform3D(Basis.from_scale(Vector3(sx * 0.5, h_b, sz * 0.85)), Vector3(bx + sx * 0.25, Y_RUA + h_b * 0.5, bz)), cz, Color(sx * 0.5, h_b, sz * 0.85, 4 + sem)])
				else:
					lista_bloco.append([Transform3D(Basis.from_scale(Vector3(sx, h, sz * 0.5)), Vector3(bx, Y_RUA + h * 0.5, bz - sz * 0.25)), cz, Color(sx, h, sz * 0.5, 4 + sem)])
					lista_bloco.append([Transform3D(Basis.from_scale(Vector3(sx * 0.85, h_b, sz * 0.5)), Vector3(bx, Y_RUA + h_b * 0.5, bz + sz * 0.25)), cz, Color(sx * 0.85, h_b, sz * 0.5, 4 + sem)])
				info["h"] = h
				if fora == "":
					ruinas.append([bx, bz, sx, sz, h, pb.x, pb.y, h_b])
					predios.append_array(PackedFloat32Array([bx, bz, sx, sz, h]))
					predio_info.append(info)
				continue
			if fora == "":
				predios.append_array(PackedFloat32Array([bx, bz, sx, sz, h]))   # guardado para a colisão
			var h1 := h
			if h > 60.0 and extra.randf() < 0.55:
				# torre escalonada: corpo + topo mais estreito
				h1 = h * extra.randf_range(0.6, 0.75)
				var k2 := extra.randf_range(0.55, 0.75)
				var h2 := h - h1 + extra.randf_range(4.0, 16.0)
				lista_bloco.append([Transform3D(Basis.from_scale(Vector3(sx * k2, h2, sz * k2)), Vector3(bx, Y_RUA + h1 + h2 * 0.5, bz)), cor, Color(sx * k2, h2, sz * k2, tipo + sem)])
			elif h < 70.0 and extra.randf() < 0.18:
				# caixa d'água de madeira no telhado (marca registrada de Nova York)
				if not caixas.has(chave):
					caixas[chave] = []
				var off := Vector3(extra.randf_range(-0.25, 0.25) * sx, 0.0, extra.randf_range(-0.25, 0.25) * sz)
				(caixas[chave] if fora == "" else []).append(Transform3D(Basis.from_scale(Vector3.ONE * extra.randf_range(0.8, 1.2)), Vector3(bx, Y_RUA + h1, bz) + off))
			var t := Transform3D(Basis.from_scale(Vector3(sx, h1, sz)), Vector3(bx, Y_RUA + h1 * 0.5, bz))
			info["h"] = h1
			info["t"] = t
			info["idx"] = lista_bloco.size()
			info["entra"] = sorte.randf() < CHANCE_ENTRA
			lista_bloco.append([t, cor, Color(sx, h1, sz, tipo + sem)])
			if fora == "":
				if info["entra"]:
					n_entra += 1
				predio_info.append(info)
	_locais()
	Mat.aquecer_texturas()                       # 0.92: texturas dos prédios/interiores (antes das threads)
	mat_predio = Mat.material(Mat.PREDIO, {"detalhe": 1.0})
	var caixa := BoxMesh.new()
	caixa.material = mat_predio
	var n_bloco := 0
	for chave in blocos:
		n_bloco += 1
		await respirar(blocos.size() + n_bloco, blocos.size() * 2)
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
		if lista.is_empty():
			continue
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
	print("Prédios: ", predios.size() / 5, " (", n, " blocos de malha) · com entrada: ", n_entra, " · em ruína: ", ruinas.size(),
		" · removidos: ", removidos["agua"], " na/perto da água, ", removidos["rua"], " em cima da rua/calçada, ",
		removidos["local"], " para os locais especiais")

# 0.68: LOCAIS ESPECIAIS (mundo/locais.gd): o terreno vira lote (chão na altura da calçada) e ganha a casca de longe
func _locais() -> void:
	locais_casca.clear()
	for i in LocaisCls.LOCAIS.size():
		var rt := LocaisCls.retangulo(i, 1.0)
		var c0 := int(floor((rt.position.x + WORLD.x) / CELL))
		var c1 := int(floor((rt.end.x + WORLD.x) / CELL))
		var r0 := int(floor((rt.position.y + WORLD.y) / CELL))
		var r1 := int(floor((rt.end.y + WORLD.y) / CELL))
		for rr in range(maxi(r0, 0), mini(r1, H - 1) + 1):
			for cc in range(maxi(c0, 0), mini(c1, W - 1) + 1):
				var k := rr * W + cc
				if land[k] == 1 and lote[k] == 0:             # na máscara de rua (grossa) também: a rua de verdade fica por cima
					lote[k] = 1
					_lote_idx.append(k)
		var casca := LocaisCls.montar_casca(i, Y_CALCADA)
		_adopt(casca)
		locais_casca.append(casca)

# ---------- prédios fora do lugar: água e rua ----------
# A grade de 20 m (máscaras land/road) é grossa: um prédio de até 34 m (+3 m sorteados) podia invadir a calçada,
# a rua ou ficar com o pé na água. Aqui a conta é EXATA, com a planta do prédio:
#   água: a planta + MARGEM_AGUA tem de estar toda em terra (polígonos da cidade) e fora dos lagos
#   rua: a planta não pode chegar a menos de (meia rua + calçada + MARGEM_RUA) do eixo de nenhuma rua
const MARGEM_AGUA := 4.0
const MARGEM_RUA := 0.5
const CEL_FILTRO := 64.0
var remapa_predios := PackedInt32Array()   # índice antigo do prédio (antes da 0.43) -> novo (-1 = removido): saves antigos
var removidos := {}
var pos_removidos := PackedVector2Array()   # onde ficavam (para conferir/testes)
var _f_ruas := {}                          # Vector2i -> PackedFloat32Array (ax, az, bx, bz, alcance)
var _f_terra: Array = []                   # [Rect2, PackedVector2Array] (terra, sem lagos)
var _f_lagos: Array = []

func _preparar_filtro(data) -> void:
	_f_ruas.clear()
	_f_terra.clear()
	_f_lagos.clear()
	for l in data["lands"]:
		var p := _pts(l[1])
		var cx := Rect2(p[0], Vector2.ZERO)
		for q in p:
			cx = cx.expand(q)
		(_f_lagos if int(l[0]) == 1 else _f_terra).append([cx, p])
	var tmp := {}
	for rd in data["roads"]:
		var alc: float = float(rd[0]) * 0.5 + CALCADA + MARGEM_RUA
		var f: Array = rd[1]
		for k in range(0, f.size() - 3, 2):
			var a := Vector2(f[k], f[k + 1])
			var b := Vector2(f[k + 2], f[k + 3])
			var c0 := Vector2i(floori((minf(a.x, b.x) - alc) / CEL_FILTRO), floori((minf(a.y, b.y) - alc) / CEL_FILTRO))
			var c1 := Vector2i(floori((maxf(a.x, b.x) + alc) / CEL_FILTRO), floori((maxf(a.y, b.y) + alc) / CEL_FILTRO))
			for gx in range(c0.x, c1.x + 1):
				for gz in range(c0.y, c1.y + 1):
					var key := Vector2i(gx, gz)
					if not tmp.has(key):
						tmp[key] = PackedFloat32Array()
					var s: PackedFloat32Array = tmp[key]
					s.append_array(PackedFloat32Array([a.x, a.y, b.x, b.y, alc]))
					tmp[key] = s
	_f_ruas = tmp

# "" = pode ficar · "agua" · "rua"
func _predio_ruim(x: float, z: float, sx: float, sz: float) -> String:
	var hx := sx * 0.5
	var hz := sz * 0.5
	# rua/calçada: distância do eixo de cada trecho até o retângulo do prédio
	var ret := Rect2(x - hx, z - hz, sx, sz)
	var c0 := Vector2i(floori(ret.position.x / CEL_FILTRO), floori(ret.position.y / CEL_FILTRO))
	var c1 := Vector2i(floori(ret.end.x / CEL_FILTRO), floori(ret.end.y / CEL_FILTRO))
	for gx in range(c0.x, c1.x + 1):
		for gz in range(c0.y, c1.y + 1):
			var s: PackedFloat32Array = _f_ruas.get(Vector2i(gx, gz), PackedFloat32Array())
			for i in range(0, s.size(), 5):
				if _dist_seg_ret(Vector2(s[i], s[i + 1]), Vector2(s[i + 2], s[i + 3]), ret) < s[i + 4]:
					return "rua"
	# água: 9 pontos da planta alargada (cantos, meio das bordas e centro)
	var m := MARGEM_AGUA
	for p in [Vector2(x, z), Vector2(x - hx - m, z - hz - m), Vector2(x + hx + m, z - hz - m), Vector2(x + hx + m, z + hz + m),
			Vector2(x - hx - m, z + hz + m), Vector2(x, z - hz - m), Vector2(x, z + hz + m), Vector2(x - hx - m, z), Vector2(x + hx + m, z)]:
		if not _em_terra(p):
			return "agua"
	return ""

func _em_terra(p: Vector2) -> bool:
	for l in _f_lagos:
		if (l[0] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, l[1]):
			return false
	# longe da costa (as 3 x 3 células de 20 m em volta são terra): não precisa da conta exata (bem mais rápido)
	var cc := int((p.x + WORLD.x) / CELL)
	var rr := int((p.y + WORLD.y) / CELL)
	if cc >= 1 and rr >= 1 and cc < W - 1 and rr < H - 1:
		var todas := true
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				if land[(rr + dr) * W + cc + dc] == 0:
					todas = false
		if todas:
			return true
	for l in _f_terra:
		if (l[0] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, l[1]):
			return true
	return false

static func _dist_seg_ret(a: Vector2, b: Vector2, r: Rect2) -> float:
	if r.has_point(a) or r.has_point(b):
		return 0.0
	var cs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, cs[i], cs[(i + 1) % 4]) != null:
			return 0.0
	var d := INF
	for c in cs:
		d = minf(d, c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)))
	for q in [a, b]:
		d = minf(d, q.distance_to(Vector2(clampf(q.x, r.position.x, r.end.x), clampf(q.y, r.position.y, r.end.y))))
	return d

# esconde/mostra o bloco de um prédio (quando o interior dele está montado perto do jogador)
func esconder_predio(i: int, esconder: bool) -> void:
	var info: Dictionary = predio_info[i]
	if info["idx"] < 0:
		return
	var mm: MultiMesh = _mm_predios[info["bloco"]]
	if oclusao != null:
		oclusao.predio_fora(i, esconder)
	if esconder:
		mm.set_instance_transform(info["idx"], Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(info["x"], -500.0, info["z"])))
	else:
		mm.set_instance_transform(info["idx"], info["t"])

# ---------- LOTES: o chão dos quarteirões na altura da calçada ----------
# Antes os prédios ficavam em 0,6 m (altura da rua) em cima da terra em 0,0 m: pareciam flutuar e o piso dos
# interiores virava um degrau de 60 cm (o personagem travava na porta). Agora toda célula de 20 m com prédio vira
# um LOTE na altura da calçada (0,55 m), com RAMPA de RAMPA_LOTE m descendo até a terra nas bordas. A colisão
# (mundo/colisao_mundo.gd altura_lote) segue o mesmo desenho.
# VERTEX PAINT: cada vértice leva os pesos dos materiais do chão em COLOR (r = concreto, g = grama, b = terra):
# em cima do lote, concreto; no pé da rampa, terra e mato (o shader TERRA mistura com o splatmap).
const RAMPA_LOTE := 2.0
const PINTA_TOPO := Color(1.0, 0.12, 0.2, 1.0)
const PINTA_PE := Color(0.15, 0.45, 1.0, 1.0)
var _lote_idx := PackedInt32Array()       # células de lote (para não varrer o mapa inteiro)
var splat: ImageTexture                    # SPLATMAP (r = urbano, g = grama, b = entulho/terra), 1 pixel = 40 m
var mat_lote: ShaderMaterial

func _lote(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < W and r < H and lote[r * W + c] == 1

func _tri_cor(v: PackedVector3Array, cs: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var cr := (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
	v.append(a)
	cs.append(ca)
	if cr >= 0.0:
		v.append(b)
		v.append(c)
		cs.append(cb)
		cs.append(cc)
	else:
		v.append(c)
		v.append(b)
		cs.append(cc)
		cs.append(cb)

# quadrilátero a-b-c-d (em volta) com uma cor por vértice
func _quad_cor(v: PackedVector3Array, cs: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri_cor(v, cs, a, b, c, ca, cb, cc)
	_tri_cor(v, cs, a, c, d, ca, cc, cd)

func _lotes() -> void:
	var v := PackedVector3Array()
	var cs := PackedColorArray()
	var y1 := Y_CALCADA
	var y0 := Y_TERRA - 0.05
	var R := RAMPA_LOTE
	var idx := _lote_idx.duplicate()
	idx.sort()
	# topo: células seguidas na mesma linha viram um retângulo só (menos triângulos)
	var tr := _trechos(idx)
	for n in range(0, tr.size(), 2):
		if n % 64 == 0:
			await respirar(n, tr.size() * 3)
		var a := tr[n]
		var b := tr[n + 1]
		var r := a / W
		var xa := (a % W) * CELL - WORLD.x
		var xb := (b % W + 1) * CELL - WORLD.x
		var za := r * CELL - WORLD.y
		var zb := za + CELL
		_quad_cor(v, cs, Vector3(xa, y1, za), Vector3(xb, y1, za), Vector3(xb, y1, zb), Vector3(xa, y1, zb), PINTA_TOPO, PINTA_TOPO, PINTA_TOPO, PINTA_TOPO)
	# rampas norte/sul: bordas sem lote do outro lado, em trechos por linha
	for lado in [-1, 1]:
		var borda := PackedInt32Array()
		for i in idx:
			if not _lote(i % W, i / W + lado):
				borda.append(i)
		tr = _trechos(borda)
		for n in range(0, tr.size(), 2):
			var a := tr[n]
			var b := tr[n + 1]
			var xa := (a % W) * CELL - WORLD.x
			var xb := (b % W + 1) * CELL - WORLD.x
			var zb := (a / W + (1 if lado > 0 else 0)) * CELL - WORLD.y
			_quad_cor(v, cs, Vector3(xa, y1, zb), Vector3(xb, y1, zb), Vector3(xb, y0, zb + R * lado), Vector3(xa, y0, zb + R * lado), PINTA_TOPO, PINTA_TOPO, PINTA_PE, PINTA_PE)
	# rampas oeste/leste: trechos por coluna (chave = coluna * H + linha)
	for lado in [-1, 1]:
		var borda := PackedInt32Array()
		for i in idx:
			if not _lote(i % W + lado, i / W):
				borda.append((i % W) * H + i / W)
		borda.sort()
		var ini := -1
		var ant := -10
		borda.append(-5)                              # sentinela: fecha o último trecho
		for k in borda:
			if k == ant + 1 and k % H != 0:
				ant = k
				continue
			if ini >= 0:
				var c := ini / H
				var za := (ini % H) * CELL - WORLD.y
				var zb := (ant % H + 1) * CELL - WORLD.y
				var xb := (c + (1 if lado > 0 else 0)) * CELL - WORLD.x
				_quad_cor(v, cs, Vector3(xb, y1, za), Vector3(xb, y1, zb), Vector3(xb + R * lado, y0, zb), Vector3(xb + R * lado, y0, za), PINTA_TOPO, PINTA_TOPO, PINTA_PE, PINTA_PE)
			ini = k
			ant = k
	# cantos de fora (as duas rampas vizinhas não se encostam): um quadradinho inclinado
	var n_canto := 0
	for i in idx:
		n_canto += 1
		if n_canto % 256 == 0:
			await respirar(idx.size() * 2 + n_canto, idx.size() * 3)
		var c := i % W
		var r := i / W
		for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
			if _lote(c + d.x, r) or _lote(c, r + d.y):
				continue
			var px := (c + (1 if d.x > 0 else 0)) * CELL - WORLD.x
			var pz := (r + (1 if d.y > 0 else 0)) * CELL - WORLD.y
			_quad_cor(v, cs, Vector3(px, y1, pz), Vector3(px + R * d.x, y0, pz), Vector3(px + R * d.x, y0, pz + R * d.y), Vector3(px, y0, pz + R * d.y), PINTA_TOPO, PINTA_PE, PINTA_PE, PINTA_PE)
	_splatmap()
	var p_lote := {"mascara": _mascara, "splat": splat, "mundo": WORLD, "camada": CAMADA["lote"], "pintura": 1.0}
	p_lote.merge(Mat.texturas_chao())
	mat_lote = Mat.material(Mat.TERRA, p_lote)
	mats_chao.append(mat_lote)
	(mats_chao[0] as ShaderMaterial).set_shader_parameter("splat", splat)
	await _malha(v, mat_lote, cs, "Lotes")

# índices ORDENADOS -> pares (primeiro, último) de cada trecho de células seguidas na mesma linha
func _trechos(idx: PackedInt32Array) -> PackedInt32Array:
	var o := PackedInt32Array()
	if idx.is_empty():
		return o
	var ini := idx[0]
	var ant := idx[0]
	for n in range(1, idx.size()):
		var i := idx[n]
		if i == ant + 1 and i % W != 0:
			ant = i
			continue
		o.append(ini)
		o.append(ant)
		ini = i
		ant = i
	o.append(ini)
	o.append(ant)
	return o

# SPLATMAP: uma imagem do mapa inteiro (1 pixel = 1 célula de 20 m) que diz qual material do chão domina em cada
# lugar: R = urbano (lotes e ruas: concreto), G = grama (parques e beira deles), B = entulho/terra (em volta das
# ruínas). Meia resolução: 1 pixel = 40 m (o tamanho de um bloco de prédio). Com mipmaps: o shader lê "borrado" (transição larga e suave) e mexe a
# posição com ruído (a borda não fica quadrada).
func _splatmap() -> void:
	var w2 := W / 2
	var h2 := H / 2
	var dados := PackedByteArray()
	dados.resize(w2 * h2 * 3)                  # já vem tudo 0
	for i in _lote_idx:
		dados[((i / W) / 2 * w2 + (i % W) / 2) * 3] = 255
	for r in h2:
		var base := (r * 2 + 1) * W
		for c in w2:
			var k := base + c * 2 + 1             # amostra o centro do bloco de 40 m
			if road[k] == 1:
				dados[(r * w2 + c) * 3] = 255
			if park[k] == 1:
				dados[(r * w2 + c) * 3 + 1] = 255
	for ru in ruinas:
		var cc := int((ru[0] + WORLD.x) / (CELL * 2.0))
		var rr := int((ru[1] + WORLD.y) / (CELL * 2.0))
		for dr in range(-2, 3):
			for dc in range(-2, 3):
				var c: int = cc + dc
				var r: int = rr + dr
				if c >= 0 and r >= 0 and c < w2 and r < h2:
					var o := (r * w2 + c) * 3 + 2
					dados[o] = maxi(dados[o], 255 - 80 * maxi(absi(dr), absi(dc)))
	var img := Image.create_from_data(w2, h2, false, Image.FORMAT_RGB8, dados)
	img.generate_mipmaps()
	splat = ImageTexture.create_from_image(img)

# caixas oclusoras: o que fica todo atrás dos prédios não é desenhado (mundo/oclusao.gd)
func _oclusao() -> void:
	oclusao = OclusaoCls.new()
	await oclusao.montar(self)
	for oi in oclusao.nos:
		_adopt(oi)

# ---------- cidade abandonada (carros, barreiras, lixo, entulho) ----------
# escadas de incêndio e aparelhos de ar-condicionado nas fachadas
func _fachadas() -> void:
	for mi in await FachadasCls.new().montar(self, Y_RUA):
		_adopt(mi)
		detalhes_fachada.append(mi)

func _abandono_comecar(ab) -> void:
	var dens := 1.0
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else null
	if cfg != null:
		dens = [0.45, 0.75, 1.0][clampi(int(cfg.g.get("den", 1)), 0, 2)]
	abandono = ab
	abandono.preparar(self, ruinas, dens)

func _abandono_fim() -> void:
	for no in abandono.nos:
		_adopt(no)
		detalhes_abandono.append(no)
	print("Carros: ", abandono.carros.size(), " · obstáculos: ", abandono.obstaculos.size() / 7)

# junta várias malhas prontas (cilindro, cone...) numa só, deslocadas, cada uma com seu material
# uma = true (0.79): tudo numa superfície só, a cor de cada material nos vértices (1 desenho em vez de um por parte)
static func _juntar(partes: Array, uma := false) -> ArrayMesh:
	var am := ArrayMesh.new()
	if uma:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in partes:
			var arr: Array = (p[0] as PrimitiveMesh).get_mesh_arrays()
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var cor: Color = (p[2] as StandardMaterial3D).albedo_color
			var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for i in ids:
				st.set_color(cor)
				st.set_normal(ns[i])
				st.add_vertex(vs[i] + p[1])
		st.commit(am)
		var m := _mat_simples(Color.WHITE, 0.8, true)
		am.surface_set_material(0, m)
		return am
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
	return _juntar([[base, Vector3(0, 1.0, 0), ferro], [corpo, Vector3(0, 4.0, 0), madeira], [teto, Vector3(0, 6.7, 0), ferro]], true)

# ---------- árvores nos parques ----------
const MAX_ARVORES := 9000
const PERTO_ARVORE := 320.0                 # até aqui a árvore completa; depois, a versão simples (LOD)

func _arvores() -> void:
	var celulas := PackedInt32Array()
	for i in W * H:
		if i % 16384 == 0:
			await respirar(i, W * H * 3)
		if park[i] == 1 and land[i] == 1 and road[i] == 0:
			celulas.append(i)
	if celulas.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	var rv := RandomNumberGenerator.new()           # sorteios dos modelos baixados (0.69)
	rv.seed = 6901
	var veg := {}                                   # modelo -> {bloco: [[Transform3D, Color], ...]}
	var chance := minf(0.6, float(MAX_ARVORES) / celulas.size())
	var blocos := {}
	var n_cel := 0
	for i in celulas:
		n_cel += 1
		if n_cel % 1024 == 0:
			await respirar(celulas.size() + n_cel, celulas.size() * 3)
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
		var chave := Vector2i(floori(x / BLOCO_ARVORE), floori(z / BLOCO_ARVORE))
		if not blocos.has(chave):
			blocos[chave] = []
		blocos[chave].append([t, verde])
		# 0.69: de perto, um modelo baixado (sorteio à parte: as posições continuam as mesmas)
		var tipo := _tipo_arvore(rv, verde)
		var tom := Color(1, 1, 1) * rv.randf_range(0.78, 1.0)
		if verde.r > verde.g and not tipo.begins_with("arvore_seca"):
			tom = Color(1.0, 0.7, 0.4)                                    # outono
		tom.a = 1.0
		_veg(veg, tipo, t, tom)
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
	# LOD: de longe a árvore vira uma copa de 5 lados sem tronco (~6x menos triângulos; no meio da neblina ninguém vê)
	var copa_longe := SphereMesh.new()
	copa_longe.radius = 2.6
	copa_longe.height = 4.6
	copa_longe.radial_segments = 5
	copa_longe.rings = 2
	var malha_longe := _juntar([[copa_longe, Vector3(0, 4.2, 0), _mat_simples(Color.WHITE, 1.0, true)]])
	var total := 0
	var n_bl := 0
	for chave in blocos:
		n_bl += 1
		await respirar(blocos.size() + n_bl, blocos.size() * 2)
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
		mi.visibility_range_end = PERTO_ARVORE
		if not veg.is_empty():
			mi.visibility_range_begin = PERTO_MODELO_ARVORE           # de perto fica o modelo baixado
		_adopt(mi)
		var mm_l := mm.duplicate() as MultiMesh
		mm_l.mesh = malha_longe
		var ml := MultiMeshInstance3D.new()
		ml.name = "ArvoresLonge_%d_%d" % [chave.x, chave.y]
		ml.multimesh = mm_l
		ml.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ml.visibility_range_begin = PERTO_ARVORE
		ml.visibility_range_end = 1500.0
		_adopt(ml)
		detalhes.append(ml)
	print("Árvores: ", total)
	await _plantas(celulas, rv, veg)
	await _montar_veg(veg)

# ---------- 0.69: VEGETAÇÃO BAIXADA (mundo/cenario.gd: Quaternius "Stylized Nature MegaKit") ----------
const PERTO_MODELO_ARVORE := 110.0          # árvore baixada até aqui; depois, a árvore simples de código
# alcance (m) de cada planta no nível 2 de "Distância dos detalhes"
const ALCANCE_VEG := {"arvore": 110.0, "pinheiro": 110.0, "arvore_seca": 110.0, "arvore_grande": 130.0, "arbusto": 80.0,
	"samambaia": 55.0, "planta": 55.0, "flores": 50.0, "capim": 50.0, "pedra": 90.0, "poste_jardim": 200.0}
# plantas soltas: [modelo, peso, escala mínima, máxima]
const PLANTAS_PARQUE := [["arbusto", 24, 0.7, 1.3], ["arbusto_flores", 6, 0.7, 1.1], ["samambaia", 16, 0.8, 1.4], ["planta", 12, 0.7, 1.2],
	["flores", 8, 0.7, 1.1], ["capim_alto", 16, 0.8, 1.3], ["capim", 12, 0.8, 1.3], ["pedra_1", 3, 0.5, 1.2], ["pedra_3", 3, 0.5, 1.2], ["poste_jardim", 1, 1.0, 1.0]]
const PLANTAS_TERRENO := [["capim_alto", 32, 0.8, 1.3], ["capim", 28, 0.8, 1.3], ["arbusto", 20, 0.6, 1.1], ["pedra_1", 6, 0.4, 0.9],
	["pedra_3", 6, 0.4, 0.9], ["arvore_seca_1", 3, 0.6, 1.0], ["arvore_seca_2", 3, 0.6, 1.0]]

func _tipo_arvore(r: RandomNumberGenerator, verde: Color) -> String:
	var x := r.randf()
	if verde.r > verde.g and x < 0.5:
		return "arvore_seca_%d" % (r.randi() % 2 + 1)
	if x < 0.62:
		return ["arvore_1", "arvore_3", "arvore_4"][r.randi() % 3]
	if x < 0.8:
		return "pinheiro_%d" % (r.randi() % 2 + 1)
	if x < 0.97:
		return "arvore_seca_%d" % (r.randi() % 2 + 1)
	return "arvore_grande"

func _veg(veg: Dictionary, nome: String, t: Transform3D, cor: Color) -> void:
	if not Cenario.tem(nome):
		return
	if not veg.has(nome):
		veg[nome] = {}
	var k := Vector2i(floori(t.origin.x / BLOCO_ARVORE), floori(t.origin.z / BLOCO_ARVORE))
	if not veg[nome].has(k):
		veg[nome][k] = []
	veg[nome][k].append([t, cor])

static func _sortear_planta(r: RandomNumberGenerator, tabela: Array) -> Array:
	var total := 0.0
	for e in tabela:
		total += float(e[1])
	var x := r.randf() * total
	for e in tabela:
		x -= float(e[1])
		if x <= 0.0:
			return e
	return tabela[0]

# arbustos, samambaias, flores, capim e pedras: em todo PARQUE e, poucos, nos TERRENOS VAZIOS (sem prédio, sem rua)
func _plantas(celulas_parque: PackedInt32Array, r: RandomNumberGenerator, veg: Dictionary) -> void:
	var n := 0
	for i in celulas_parque:
		if n % 512 == 0:
			await pausa()
		for k in r.randi_range(0, 3):
			var e := _sortear_planta(r, PLANTAS_PARQUE)
			_planta(veg, e, i, r, Y_PARQUE)
			n += 1
	for i in range(0, W * H, 3):                       # 1 célula em 3 (mais rápido; a chance compensa)
		if i % 24576 == 0:
			await pausa()
		if land[i] == 1 and park[i] == 0 and road[i] == 0 and lote[i] == 0 and r.randf() < 0.5:
			var x := (i % W + 0.5) * CELL - WORLD.x
			var z := (i / W + 0.5) * CELL - WORLD.y
			if x > 5600.0 and z > -1600.0 and z < 2600.0:
				continue                                  # aeroporto
			var e := _sortear_planta(r, PLANTAS_TERRENO)
			_planta(veg, e, i, r, Y_TERRA)
			n += 1
	print("Plantas baixadas: ", n)

func _planta(veg: Dictionary, e: Array, celula: int, r: RandomNumberGenerator, y: float) -> void:
	var x := (celula % W + r.randf()) * CELL - WORLD.x
	var z := (celula / W + r.randf()) * CELL - WORLD.y
	var s := r.randf_range(float(e[2]), float(e[3]))
	var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.85, 1.15), s))
	var nome: String = e[0]
	var afunda := 0.15 * s if nome.begins_with("pedra") else 0.0
	if nome == "poste_jardim":
		b = Basis(Vector3.UP, r.randf() * TAU)                     # poste em pé, sem esticar
	var cor := Color(1, 1, 1) * r.randf_range(0.7, 1.0)
	if nome.begins_with("capim") and r.randf() < 0.4:
		cor = Color(0.95, 0.85, 0.6) * r.randf_range(0.8, 1.0)     # capim seco
	cor.a = 1.0
	_veg(veg, nome, Transform3D(b, Vector3(x, y - afunda, z)), cor)

func _montar_veg(veg: Dictionary) -> void:
	var total := 0
	for nome in veg:
		await pausa()
		var malha: ArrayMesh = Cenario.malha(nome)
		var grupo: String = nome.rstrip("0123456789").trim_suffix("_")
		if grupo.begins_with("arvore_seca"):
			grupo = "arvore_seca"
		elif grupo.begins_with("pedra"):
			grupo = "pedra"
		elif grupo.begins_with("capim"):
			grupo = "capim"
		elif grupo.begins_with("planta"):
			grupo = "planta"
		elif grupo.begins_with("arbusto"):
			grupo = "arbusto"
		var alcance: float = ALCANCE_VEG.get(grupo, 100.0)
		for k in veg[nome]:
			var lista: Array = veg[nome][k]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = malha
			mm.instance_count = lista.size()
			for j in lista.size():
				mm.set_instance_transform(j, lista[j][0])
				mm.set_instance_color(j, lista[j][1])
			total += lista.size()
			var mi := MultiMeshInstance3D.new()
			mi.name = "Veg_%s_%d_%d" % [nome, k.x, k.y]
			mi.multimesh = mm
			mi.visibility_range_end = alcance
			mi.set_meta("alcance", alcance)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # como as árvores de antes (sombra pesa no celular)
			_adopt(mi)
			detalhes_veg.append(mi)
	print("Vegetação baixada: ", total, " (", veg.size(), " modelos)")
