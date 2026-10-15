extends Node3D
# MATO TOMANDO A CIDADE + SOMBRA NO CHÃO PERTO DOS PRÉDIOS (só em volta do jogador, para pesar pouco)
#   - o mundo é dividido em pedaços de TAM x TAM m; os pedaços a menos de RAIO m do jogador ganham mato
#     (sempre o mesmo em cada lugar: sorteio pela posição do pedaço). Pedaços longe são apagados.
#   - onde nasce: terrenos (tufos e arbustos), PARQUES (capim alto: agachado nele os infectados quase não
#     veem você), calçadas (no pé das paredes e nas rachaduras) e, raro, no meio da rua.
#   - o mato balança com o vento (mais forte na chuva/tempestade) e se abre quando o jogador passa.
#   - some aos poucos (encolhe) perto do fim do alcance, sem "estalar".
#   - SOMBRA NO CHÃO: manda as plantas dos prédios mais perto para os shaders do chão escurecerem o pé das
#     paredes (mundo/materiais_cidade.gd, trecho CHAO).
# Opções › Gráficos: "Distância dos detalhes" = até onde o mato aparece · "Densidade do cenário" = quanto mato.
# Mexa AQUI para: quantidade, tamanho e cores do mato, alcance e sombra no chão.

const Col := preload("res://mundo/colisao_mundo.gd")
const Cid := preload("res://mundo/cidade.gd")
const TAM := 32.0                                   # tamanho de cada pedaço (m)
const RAIOS := [40.0, 56.0, 72.0, 90.0]             # alcance por "Distância dos detalhes" (0..3)
const DENSIDADES := [0.45, 0.75, 1.0]               # por "Densidade do cenário" (0..2)
const CANDIDATOS := 200                             # pontos sorteados por pedaço (densidade máxima)
const AO_MAX := 24                                  # prédios mandados para a sombra no chão
const AO_RAIO := 70.0

var cidade: Node3D
var mundo: Node3D
var jogador: Node3D
var no_capim := false                               # jogador dentro do capim alto (parque)
var raio := 72.0
var pedacos_criados := 0                            # (para testes)

var _pedacos := {}                                  # Vector2i -> Node3D
var _malhas: Array[ArrayMesh] = []                  # 0 tufo · 1 capim alto · 2 arbusto
var _mats: Array[ShaderMaterial] = []
var _ultimo_ao := Vector2(1e9, 1e9)
var _t_capim := 0.0
var _dens := 1.0

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
global uniform vec3 pos_jogador;
global uniform float vento;
global uniform float molhado;
uniform float alcance = 72.0;
uniform float rigidez = 1.0;
void vertex() {
	vec3 origem = MODEL_MATRIX[3].xyz;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float alto = max(w.y - origem.y, 0.0);
	float fase = INSTANCE_CUSTOM.w * 6.2832;
	// vento: balanço + inclinação para um lado
	vec2 v = vec2(sin(TIME * 1.9 + w.x * 0.4 + fase), cos(TIME * 1.4 + w.z * 0.35 + fase)) * (0.04 + 0.12 * vento);
	v += vec2(0.55, 0.3) * 0.1 * vento;
	// o jogador abre o mato quando passa
	vec2 a = origem.xz - pos_jogador.xz;
	float d = length(a);
	float perto = (1.0 - smoothstep(0.4, 1.5, d)) * (1.0 - smoothstep(1.5, 2.5, abs(origem.y - pos_jogador.y)));
	vec2 dobra = d > 0.001 ? a / d * perto * 1.1 : vec2(0.0);
	float k = alto * alto / max(alto + 0.25, 0.25);
	w.xz += (v * rigidez + dobra) * k;
	w.y -= perto * alto * 0.45;
	// encolhe no fim do alcance
	float cam = length(origem - CAMERA_POSITION_WORLD);
	float some = 1.0 - smoothstep(alcance * 0.72, alcance, cam);
	w.y = origem.y + (w.y - origem.y) * some;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);   // luz igual dos dois lados da folha
	ALBEDO = COLOR.rgb * mix(1.0, 0.72, molhado);
	ROUGHNESS = mix(0.85, 0.45, molhado);
	SPECULAR = 0.25;
}
"""

func ligar(c: Node3D, m: Node3D, j: Node3D) -> void:
	cidade = c
	mundo = m
	jogador = j
	var sh := Shader.new()
	sh.code = SHADER
	_malhas = [_malha_tufo(9, 0.22, Vector2(0.25, 0.5)), _malha_tufo(14, 0.45, Vector2(0.7, 1.25)), _malha_arbusto()]
	for i in 3:
		var mt := ShaderMaterial.new()
		mt.shader = sh
		mt.set_shader_parameter("rigidez", 0.25 if i == 2 else 1.0)
		_mats.append(mt)

# ---------- malhas (feitas uma vez) ----------
func _malha_tufo(laminas: int, espalhar: float, altura: Vector2) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = laminas * 31 + 7
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	for i in laminas:
		var a := r.randf() * TAU
		var dist := sqrt(r.randf()) * espalhar
		var base := Vector3(cos(a) * dist, 0.0, sin(a) * dist)
		var giro := r.randf() * TAU
		var lado := Vector3(cos(giro), 0.0, sin(giro)) * r.randf_range(0.03, 0.05)
		var h := r.randf_range(altura.x, altura.y)
		var inclina := Vector3(cos(a), 0.0, sin(a)) * h * r.randf_range(0.1, 0.45)
		var ponta := base + inclina + Vector3(0, h, 0)
		var pe := Color(0.20, 0.24, 0.10)
		var cor_ponta := Color(0.42, 0.58, 0.22).lerp(Color(0.62, 0.55, 0.30), r.randf() * 0.5)
		for p in [[base - lado, pe], [base + lado, pe], [ponta, cor_ponta]]:
			v.append(p[0])
			n.append(Vector3.UP)             # normal para cima = luz igual à do chão (sem lado escuro)
			c.append(p[1])
	return _arrays(v, n, c)

func _malha_arbusto() -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	for b in 6:
		var a := r.randf() * TAU
		var centro := Vector3(cos(a), 0.0, sin(a)) * r.randf_range(0.0, 0.45) + Vector3(0, r.randf_range(0.35, 0.8), 0)
		var raio_b := r.randf_range(0.3, 0.55)
		var esc := Vector3(raio_b, raio_b * r.randf_range(0.8, 1.2), raio_b)
		var pts := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
		var faces := [[2, 0, 4], [2, 4, 1], [2, 1, 5], [2, 5, 0], [3, 4, 0], [3, 1, 4], [3, 5, 1], [3, 0, 5]]
		var verde := Color(0.16, 0.25, 0.08).lerp(Color(0.30, 0.34, 0.12), r.randf())
		for f in faces:
			var q: Array = []
			for idx in f:
				q.append(centro + pts[idx] * esc)
			var nn: Vector3 = (q[2] - q[0]).cross(q[1] - q[0]).normalized()
			if nn.dot(q[0] - centro) < 0.0:
				nn = -nn
			for p in q:
				v.append(p)
				n.append((nn + Vector3.UP * 0.6).normalized())
				c.append(verde * (0.6 + 0.4 * clampf(p.y / 1.0, 0.0, 1.0)))
	return _arrays(v, n, c)

func _arrays(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

# ---------- a cada quadro ----------
func _process(dt: float) -> void:
	if jogador == null or not is_instance_valid(jogador) or mundo == null:
		return
	var p := jogador.global_position
	RenderingServer.global_shader_parameter_set("pos_jogador", p)
	var g: Dictionary = Config.g
	raio = RAIOS[clampi(int(g.get("detd", 2)), 0, 3)]
	_dens = DENSIDADES[clampi(int(g.get("den", 1)), 0, 2)]
	for m in _mats:
		m.set_shader_parameter("alcance", raio)
	var p2 := Vector2(p.x, p.z)
	# apaga os pedaços longe
	for k in _pedacos.keys():
		if _dist_pedaco(k, p2) > raio + TAM:
			_pedacos[k].queue_free()
			_pedacos.erase(k)
	# cria os que faltam (o mais perto primeiro); muitos de uma vez só quando o jogador acabou de chegar/teleportar
	var faltam := _faltando(p2)
	var limite := 1 if _pedacos.size() > 4 else 64
	for i in mini(limite, faltam.size()):
		_pedacos[faltam[i]] = _criar(faltam[i])
	# sombra dos prédios no chão
	if p2.distance_to(_ultimo_ao) > 6.0:
		_ultimo_ao = p2
		_atualizar_sombra(p2)
	_t_capim -= dt
	if _t_capim <= 0.0:
		_t_capim = 0.25
		no_capim = _dens > 0.0 and is_equal_approx(mundo.altura(p.x, p.z), Col.ALT_PARQUE)

# chamado ao teleportar/carregar: refaz tudo em volta já
func refazer() -> void:
	for k in _pedacos:
		_pedacos[k].queue_free()
	_pedacos.clear()
	_ultimo_ao = Vector2(1e9, 1e9)

func _dist_pedaco(k: Vector2i, p: Vector2) -> float:
	var dx := maxf(absf(p.x - (k.x + 0.5) * TAM) - TAM * 0.5, 0.0)
	var dz := maxf(absf(p.y - (k.y + 0.5) * TAM) - TAM * 0.5, 0.0)
	return sqrt(dx * dx + dz * dz)

func _faltando(p: Vector2) -> Array:
	var o := []
	var n := ceili(raio / TAM) + 1
	var c := Vector2i(floori(p.x / TAM), floori(p.y / TAM))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if not _pedacos.has(k) and _dist_pedaco(k, p) < raio:
				o.append(k)
	o.sort_custom(func(a, b): return _dist_pedaco(a, p) < _dist_pedaco(b, p))
	return o

# ---------- um pedaço de mato ----------
func _criar(k: Vector2i) -> Node3D:
	pedacos_criados += 1
	var no := Node3D.new()
	add_child(no)
	var r := RandomNumberGenerator.new()
	r.seed = hash(k) + 777
	var listas := [[], [], []]                       # tufos, capim alto, arbustos: [x, y, z, giro, escala, tinta]
	var n := int(CANDIDATOS * _dens)
	for i in n:
		var x := (k.x + r.randf()) * TAM
		var z := (k.y + r.randf()) * TAM
		var sorte := r.randf()
		var esc := r.randf_range(0.7, 1.3)
		var y: float = mundo.altura_rua(x, z)
		var tipo := 0
		if y == Col.ALT_RUA:
			if sorte > 0.02:                         # só nas rachaduras, raro
				continue
			esc *= 0.5
		elif y == Col.ALT_CALCADA:
			if mundo.dentro_de_predio(x, z, 0.0, true):
				continue
			var na_parede: bool = mundo.dentro_de_predio(x, z, 1.3, true)
			if sorte > (0.6 if na_parede else 0.05):
				continue
			esc *= 0.7
		else:
			y = _sem_rua(x, z)
			if y == Col.ALT_PARQUE:
				tipo = 2 if sorte < 0.05 else 1
			elif y == Col.ALT_TERRA:
				if sorte > 0.8 or mundo.dentro_de_predio(x, z, 0.0, true):
					continue
				tipo = 2 if sorte < 0.07 else 0
			else:
				continue                             # mar, lago
		if mundo.dentro_de_obstaculo(x, z, 0.1):
			continue
		var t := Color(1, 1, 1)
		var cor := r.randf()
		if cor < 0.3:
			t = Color(1.0, 0.9, 0.6)                 # seco/amarelado
		elif cor < 0.45:
			t = Color(0.8, 0.85, 0.7)
		listas[tipo].append([x, y, z, r.randf() * TAU, esc, t, r.randf()])
		if tipo == 1 and r.randf() < 0.5:            # parque: capim bem fechado
			listas[1].append([x + r.randf_range(-0.8, 0.8), y, z + r.randf_range(-0.8, 0.8), r.randf() * TAU, esc, t, r.randf()])
	for tipo in 3:
		var l: Array = listas[tipo]
		if l.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true                         # (sem isso a cor da malha sai preta no celular)
		mm.mesh = _malhas[tipo]
		mm.instance_count = l.size()
		for i in l.size():
			var e: Array = l[i]
			var b := Basis(Vector3.UP, e[3]).scaled(Vector3(e[4], e[4] * (0.8 + 0.4 * e[6]), e[4]))
			mm.set_instance_transform(i, Transform3D(b, Vector3(e[0], e[1], e[2])))
			var tc: Color = e[5]
			mm.set_instance_color(i, tc)
			mm.set_instance_custom_data(i, Color(0, 0, 0, e[6]))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _mats[tipo]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(mi)
	return no

# terra / parque / lago / mar: usa a máscara de 20 m da cidade; só nas bordas faz a conta exata (polígonos)
func _sem_rua(x: float, z: float) -> float:
	var cx := int((x + Cid.WORLD.x) / Cid.CELL)
	var cz := int((z + Cid.WORLD.y) / Cid.CELL)
	if cx < 1 or cz < 1 or cx >= cidade.W - 1 or cz >= cidade.H - 1:
		return Col.ALT_MAR
	var terra := 0
	var parque := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var i: int = (cz + dz) * cidade.W + cx + dx
			terra += cidade.land[i]
			parque += cidade.park[i]
	if terra == 9 and parque == 0:
		return Col.ALT_TERRA
	if terra == 9 and parque == 9:
		return Col.ALT_PARQUE
	if terra == 0:
		return Col.ALT_MAR
	return mundo.altura_sem_rua(x, z)

# ---------- sombra no chão (plantas dos prédios mais perto) ----------
func _atualizar_sombra(p: Vector2) -> void:
	if cidade == null or cidade.mats_chao.is_empty():
		return
	var ids: PackedInt32Array = mundo.predios_perto(p.x, p.y, AO_RAIO)
	var pred: PackedFloat32Array = cidade.predios
	var lista := []
	for idx in ids:
		var o := idx * 5
		var dx := maxf(absf(p.x - pred[o]) - pred[o + 2] * 0.5, 0.0)
		var dz := maxf(absf(p.y - pred[o + 1]) - pred[o + 3] * 0.5, 0.0)
		lista.append([dx * dx + dz * dz, Vector4(pred[o], pred[o + 1], pred[o + 2] * 0.5, pred[o + 3] * 0.5)])
	lista.sort_custom(func(a, b): return a[0] < b[0])
	var caixas := []
	for i in AO_MAX:
		caixas.append(lista[i][1] if i < lista.size() else Vector4(0, 0, 0, 0))
	var n := mini(lista.size(), AO_MAX)
	for m in cidade.mats_chao:
		m.set_shader_parameter("ao_caixas", caixas)
		m.set_shader_parameter("ao_n", n)
