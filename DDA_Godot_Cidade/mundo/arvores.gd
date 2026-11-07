extends Node3D
# ÁRVORES (1.20): as árvores da cidade inteira (as 13 mil dos lugares guardados na 1.19 + o Central Park bem denso).
# Modelos REALISTAS gerados pelo EZ-Tree (ferramentas/arvores_ez/, MIT; texturas CC0: mundo/arvores/texturas/LICENCA.txt),
# 24 variações (carvalho, freixo, olmo, álamo, pinheiro e secas) preparadas por ferramentas/preparar_arvores.gd:
#   mundo/arvores/modelos/<nome>.res (casca + folhas, sem material) e mundo/arvores/arvores.json (altura, raios, tipo...)
#   mundo/arvores/impostores.png: a "foto" de cada árvore (de lado e de cima), num atlas.
# COMO DESENHA (dois níveis, um passando para o outro na mesma distância, sem buraco e sem árvore dobrada):
#   PERTO (até raio_perto m da câmera): a árvore de verdade (2 a 5 mil triângulos), com vento nas folhas e sombra.
#     A lista das que estão perto é refeita aqui (CPU) quando a câmera anda MOVER m: as que estão a até raio + FOLGA
#     entram num MultiMesh por modelo. O shader esconde (encolhe para um ponto) as que já passaram de raio_perto.
#   LONGE: o IMPOSTOR (3 planos em pé cruzados + 1 deitado no alto da copa = 8 triângulos) com a foto do atlas, num
#     MultiMesh por bloco de BLOCO m (todos os modelos juntos: 1 chamada de desenho por bloco; os chunks tiram da cena
#     os blocos longe). O shader esconde os que estão a menos de raio_perto (ali a árvore de verdade aparece).
#   "centro" e "raio_perto" vão para os 8 materiais a cada quadro (a câmera de verdade; na sombra também vale ela).
# COLISÃO: o tronco de cada árvore vira um obstáculo (caixa) da física perto do jogador (mundo/colisao_mundo.gd).
# Quem usa: mundo/cidade.gd (planta: lugares guardados + mundo/central_park.gd) e menu/aplicar_opcoes.gd ("Distância
# dos detalhes" muda raio_perto e até onde vão os impostores).
# Mexa AQUI para: distâncias, vento, cor das folhas, sorteio dos modelos de cada lugar antigo.

const DIR := "res://mundo/arvores/"
const BLOCO := 250.0                     # impostores: um MultiMesh por bloco
const CEL := 32.0                        # grade para achar as árvores perto
const MOVER := 7.0                       # a lista de perto é refeita quando a câmera anda isso
const FOLGA := 10.0                      # a lista de perto pega até raio_perto + FOLGA (cobre o andar até refazer)
const RAIO_PERTO := [26.0, 36.0, 48.0, 64.0]          # por "Distância dos detalhes" (0..3)
const ALCANCE_IMPOSTOR := [650.0, 1000.0, 1500.0, 2200.0]
# atlas dos impostores (mundo/arvores/impostores.png): em cima, as fotos de lado (CEL_LADO px, COLS por linha);
# embaixo, as de cima (CEL_TOPO px, COLS_TOPO por linha)
const COLS := 6
const CEL_LADO := 256
const CEL_TOPO := 128
const COLS_TOPO := 12
const ATLAS := Vector2i(1536, 1280)
const Y_TOPO_ATLAS := 1024               # onde começam as fotos de cima
const ALTURA_TOPO := 0.62                # o plano deitado fica a esta fração da altura
const TRONCO_ALTURA := 4.0               # altura da caixa de colisão do tronco

# ---------------------------------------------------------------------------------------------------------------
# MODELOS (static: os mesmos para todo mundo; carregados uma vez)
# ---------------------------------------------------------------------------------------------------------------
static var _info := {}                   # nome -> {tipo, seca, altura, raio_copa, raio_tronco, lado, casca, folha, cor_folha, celula}
static var _nomes: Array = []            # na ordem do atlas (celula)
static var _malhas := {}
static var _mats := {}

static func info() -> Dictionary:
	if _info.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "arvores.json"))
		if d is Dictionary:
			for e in d["modelos"]:
				_info[String(e["nome"])] = e
				_nomes.append(String(e["nome"]))
	return _info

static func nomes() -> Array:
	info()
	return _nomes

static func do_tipo(tipo: String) -> Array:
	var r: Array = []
	for n in nomes():
		if String(_info[n]["tipo"]) == tipo:
			r.append(n)
	return r

static func malha(nome: String) -> ArrayMesh:
	if not _malhas.has(nome):
		_malhas[nome] = load(DIR + "modelos/%s.res" % nome)
	return _malhas[nome]

static func cor_folha(nome: String) -> Color:
	var c = info()[nome].get("cor_folha", "ffffff")
	return Color.html(String(c))

# ---------------------------------------------------------------------------------------------------------------
# MATERIAIS (8, compartilhados: 3 cascas, 4 folhas, 1 impostor)
# ---------------------------------------------------------------------------------------------------------------
const _CORTE := """
uniform vec3 centro = vec3(0.0, -100000.0, 0.0);
uniform float raio_perto = 48.0;
global uniform float vento;
"""

const SHADER_CASCA := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float foto = 0.0;
""" + _CORTE + """
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	if (foto < 0.5 && distance(o.xz, centro.xz) > raio_perto) {
		VERTEX = vec3(0.0);                       // longe: quem desenha é o impostor
	}
}
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	ALBEDO = c * mix(vec3(1.0), COLOR.rgb, 0.25);
	NORMAL_MAP = texture(tex_normal, UV).rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
"""

# folhas: dos dois lados, recorte pela transparência, vento (as pontas mexem mais), cor de cada árvore (COLOR)
const SHADER_FOLHA := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float foto = 0.0;
uniform float alpha_corte = 0.5;
""" + _CORTE + """
varying float h;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	if (foto < 0.5 && distance(o.xz, centro.xz) > raio_perto) {
		VERTEX = vec3(0.0);
	} else if (foto < 0.5) {
		float fase = o.x * 0.37 + o.z * 0.23;
		float t = TIME;
		float forca = (0.25 + vento) * clamp(VERTEX.y * 0.08, 0.0, 1.5);
		VERTEX.x += (sin(t * 1.9 + fase + VERTEX.y * 0.6) * 0.05 + sin(t * 0.7 + fase) * 0.09) * forca;
		VERTEX.z += cos(t * 1.6 + fase * 1.3 + VERTEX.x * 0.5) * 0.05 * forca;
	}
	h = VERTEX.y;
}
void fragment() {
	vec4 t = texture(tex, UV);
	vec3 c = t.rgb * COLOR.rgb;
	c *= 0.82 + 0.18 * clamp(h * 0.08, 0.0, 1.0);          // por dentro e embaixo da copa, mais escuro
	ALBEDO = c;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_corte;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	BACKLIGHT = c * 0.35;
}
"""

# impostor: 3 planos em pé + 1 deitado (UV2.x = 1), foto da célula INSTANCE_CUSTOM.x; o deitado tem o tamanho e a altura
# de cada modelo (INSTANCE_CUSTOM.y = largura da copa / lado da foto, .z = altura do plano / lado da foto)
static func shader_impostor() -> String:
	return """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_corte = 0.42;
""" + _CORTE + """
const float COLS = %d.0;
const float COLS_TOPO = %d.0;
const vec2 TAM = vec2(%d.0, %d.0);
const float LADO = %d.0;
const float TOPO = %d.0;
const float Y_TOPO = %d.0;
varying vec2 uv_atlas;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float cel = INSTANCE_CUSTOM.x;
	if (distance(o.xz, centro.xz) < raio_perto) {
		VERTEX = vec3(0.0);                       // perto: quem desenha é a árvore de verdade
	}
	if (UV2.x > 0.5) {
		VERTEX = vec3(VERTEX.x * INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z, VERTEX.z * INSTANCE_CUSTOM.y);
		vec2 cr = vec2(mod(cel, COLS_TOPO), floor(cel / COLS_TOPO));
		uv_atlas = (cr * TOPO + UV * TOPO + vec2(0.0, Y_TOPO)) / TAM;
		NORMAL = vec3(0.0, 1.0, 0.0);
	} else {
		vec2 cr = vec2(mod(cel, COLS), floor(cel / COLS));
		uv_atlas = (cr * LADO + UV * LADO) / TAM;
		NORMAL = normalize(vec3(VERTEX.x, 0.45, VERTEX.z));
		float fase = o.x * 0.37 + o.z * 0.23;
		VERTEX.x += sin(TIME * 0.8 + fase) * 0.012 * (0.3 + vento) * VERTEX.y * VERTEX.y;
	}
}
void fragment() {
	vec4 t = texture(atlas, uv_atlas);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_corte;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}
""" % [COLS, COLS_TOPO, ATLAS.x, ATLAS.y, CEL_LADO, CEL_TOPO, Y_TOPO_ATLAS]


const CASCAS := {"oak": "carvalho", "birch": "betula", "pine": "pinheiro", "willow": "carvalho"}
const FOLHAS := {"ash": "freixo", "aspen": "alamo", "oak": "carvalho", "pine": "pinheiro"}

static func _shader(codigo: String) -> Shader:
	var k := "sh_" + str(codigo.hash())
	if not _mats.has(k):
		var s := Shader.new()
		s.code = codigo
		_mats[k] = s
	return _mats[k]

static func mat_casca(tipo: String, foto := false) -> ShaderMaterial:
	var nome := String(CASCAS.get(tipo, "carvalho"))
	var k := "casca_%s_%s" % [nome, foto]
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _shader(SHADER_CASCA)
		m.set_shader_parameter("tex", load(DIR + "texturas/casca_%s.jpg" % nome))
		m.set_shader_parameter("tex_normal", load(DIR + "texturas/casca_%s_normal.jpg" % nome))
		m.set_shader_parameter("foto", 1.0 if foto else 0.0)
		_mats[k] = m
	return _mats[k]

static func mat_folha(tipo: String, foto := false) -> ShaderMaterial:
	var nome := String(FOLHAS.get(tipo, "carvalho"))
	var k := "folha_%s_%s" % [nome, foto]
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _shader(SHADER_FOLHA)
		m.set_shader_parameter("tex", load(DIR + "texturas/folha_%s.png" % nome))
		m.set_shader_parameter("foto", 1.0 if foto else 0.0)
		_mats[k] = m
	return _mats[k]

static func mat_impostor() -> ShaderMaterial:
	if not _mats.has("impostor"):
		var m := ShaderMaterial.new()
		m.shader = _shader(shader_impostor())
		m.set_shader_parameter("atlas", load(DIR + "impostores.png"))
		_mats["impostor"] = m
	return _mats["impostor"]

# os materiais que recebem "centro" e "raio_perto"
static func _mats_corte() -> Array:
	var r: Array = []
	for k in _mats:
		if _mats[k] is ShaderMaterial and not String(k).ends_with("_true"):
			r.append(_mats[k])
	return r

# a malha do impostor: 3 planos em pé (lado 1 m, base no chão, girados 0/60/120 graus) + 1 deitado (UV2.x = 1)
static var _malha_impostor: ArrayMesh = null
static func malha_impostor() -> ArrayMesh:
	if _malha_impostor != null:
		return _malha_impostor
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * PI / 3.0
		var d := Vector3(cos(a), 0.0, sin(a)) * 0.5
		var cs := [[-d, Vector2(0, 1)], [d, Vector2(1, 1)], [d + Vector3.UP, Vector2(1, 0)], [-d + Vector3.UP, Vector2(0, 0)]]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(cs[i][1])
			st.set_uv2(Vector2.ZERO)
			st.set_normal(Vector3.UP)
			st.add_vertex(cs[i][0])
	var tp := [[Vector3(-0.5, 0, -0.5), Vector2(0, 0)], [Vector3(0.5, 0, -0.5), Vector2(1, 0)], [Vector3(0.5, 0, 0.5), Vector2(1, 1)], [Vector3(-0.5, 0, 0.5), Vector2(0, 1)]]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(tp[i][1])
		st.set_uv2(Vector2(1, 0))
		st.set_normal(Vector3.UP)
		st.add_vertex(tp[i][0])
	_malha_impostor = st.commit()
	_malha_impostor.custom_aabb = AABB(Vector3(-0.6, -0.1, -0.6), Vector3(1.2, 1.2, 1.2))
	return _malha_impostor

# ---------------------------------------------------------------------------------------------------------------
# AS ÁRVORES PLANTADAS
# ---------------------------------------------------------------------------------------------------------------
var _var := PackedInt32Array()            # índice do modelo (ordem de nomes())
var _pos := PackedVector3Array()
var _reg_perto := PackedFloat32Array()    # 20 floats por árvore: transform (12) + cor (4) + custom (4)
var _grade := {}                          # Vector2i -> PackedInt32Array
var _perto := {}                          # índice do modelo -> MultiMeshInstance3D
var _ult := Vector3(1.0e9, 0.0, 1.0e9)
var raio_perto: float = RAIO_PERTO[2]
var alcance_impostor: float = ALCANCE_IMPOSTOR[2]
var impostores: Array = []                # MultiMeshInstance3D (a cidade adota: os chunks cuidam)
var obstaculos := PackedFloat32Array()    # troncos no formato do mundo/colisao_mundo.gd (7 floats cada)
var contagem := {}                        # nome -> quantas (estatística e testes)
var sombra := true

func quantas() -> int:
	return _var.size()

# planta uma árvore do modelo "nome" em p (chão), girada "giro", escala s (e sh na altura), cor das folhas "tom"
func plantar(nome: String, p: Vector3, giro: float, s: float, sh := 1.0, tom := Color(1, 1, 1)) -> void:
	var lista := nomes()
	var vi := lista.find(nome)
	if vi < 0:
		return
	var e: Dictionary = _info[nome]
	var i := _var.size()
	_var.append(vi)
	_pos.append(p)
	var b := Basis(Vector3.UP, giro).scaled(Vector3(s, s * sh, s))
	var c := cor_folha(nome) * tom
	c.a = 1.0
	_reg_perto.append_array(PackedFloat32Array([b.x.x, b.y.x, b.z.x, p.x, b.x.y, b.y.y, b.z.y, p.y, b.x.z, b.y.z, b.z.z, p.z,
		c.r, c.g, c.b, 1.0, 0.0, 0.0, 0.0, 0.0]))
	var k := Vector2i(floori(p.x / CEL), floori(p.z / CEL))
	if not _grade.has(k):
		_grade[k] = PackedInt32Array()
	_grade[k].append(i)
	contagem[nome] = int(contagem.get(nome, 0)) + 1
	# tronco (colisão): caixa do tamanho do tronco perto do chão
	var rt := float(e.get("raio_tronco", 0.3)) * s * 1.6
	if rt > 0.12:
		obstaculos.append_array(PackedFloat32Array([p.x, p.z, giro, rt, TRONCO_ALTURA, rt, p.y + TRONCO_ALTURA * 0.5]))

# depois de plantar todas: os MultiMesh dos impostores (um por bloco); quem chama adota os nós (chunks)
func montar() -> Array:
	var blocos := {}
	var lista := nomes()
	for i in _var.size():
		var p := _pos[i]
		var k := Vector2i(floori(p.x / BLOCO), floori(p.z / BLOCO))
		if not blocos.has(k):
			blocos[k] = PackedInt32Array()
		blocos[k].append(i)
	var mat := mat_impostor()
	var mi_malha := malha_impostor()
	for k in blocos:
		var idx: PackedInt32Array = blocos[k]
		var buf := PackedFloat32Array()
		buf.resize(idx.size() * 20)
		var j := 0
		for i in idx:
			var e: Dictionary = _info[lista[_var[i]]]
			var lado := float(e["lado"])
			var r := _reg_perto.slice(i * 20, i * 20 + 20)
			for q in 12:
				if q % 4 != 3:
					r[q] *= lado                                # o impostor tem o tamanho da foto (lado x lado)
			var tom := Color(r[12], r[13], r[14]) / cor_folha(lista[_var[i]])
			r[12] = tom.r
			r[13] = tom.g
			r[14] = tom.b
			r[16] = float(e["celula"])
			r[17] = float(e["raio_copa"]) * 2.0 / lado
			r[18] = float(e["altura"]) * ALTURA_TOPO / lado
			for q in 20:
				buf[j + q] = r[q]
			j += 20
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mi_malha
		mm.instance_count = idx.size()
		mm.buffer = buf
		var mi := MultiMeshInstance3D.new()
		mi.name = "ArvoresLonge_%d_%d" % [k.x, k.y]
		mi.multimesh = mm
		mi.material_override = mat
		mi.visibility_range_end = alcance_impostor
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impostores.append(mi)
	return impostores

func aplicar_alcance(nivel: int) -> void:
	raio_perto = RAIO_PERTO[clampi(nivel, 0, 3)]
	alcance_impostor = ALCANCE_IMPOSTOR[clampi(nivel, 0, 3)]
	for mi in impostores:
		if is_instance_valid(mi):
			mi.visibility_range_end = alcance_impostor
	_ult = Vector3(1.0e9, 0.0, 1.0e9)

func aplicar_sombra(ligada: bool) -> void:
	sombra = ligada
	for k in _perto:
		_perto[k].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ligada else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _var.is_empty():
		return
	atualizar(cam.global_position)

# a câmera em "c": manda para os materiais e, se andou, refaz a lista de perto
func atualizar(c: Vector3, forcar := false) -> void:
	for m in _mats_corte():
		m.set_shader_parameter("centro", c)
		m.set_shader_parameter("raio_perto", raio_perto)
	if not forcar and Vector2(c.x - _ult.x, c.z - _ult.z).length() < MOVER:
		return
	_ult = c
	var r := raio_perto + FOLGA
	var r2 := r * r
	var por_modelo := {}
	var c0 := Vector2i(floori((c.x - r) / CEL), floori((c.z - r) / CEL))
	var c1 := Vector2i(floori((c.x + r) / CEL), floori((c.z + r) / CEL))
	for gx in range(c0.x, c1.x + 1):
		for gz in range(c0.y, c1.y + 1):
			var k := Vector2i(gx, gz)
			if not _grade.has(k):
				continue
			for i in _grade[k]:
				var p := _pos[i]
				if (p.x - c.x) * (p.x - c.x) + (p.z - c.z) * (p.z - c.z) > r2:
					continue
				var v := _var[i]
				if not por_modelo.has(v):
					por_modelo[v] = PackedFloat32Array()
				por_modelo[v].append_array(_reg_perto.slice(i * 20, i * 20 + 20))
	var lista := nomes()
	for v in _perto.keys():
		if not por_modelo.has(v):
			_perto[v].visible = false
	for v in por_modelo:
		var buf: PackedFloat32Array = por_modelo[v]
		var mi: MultiMeshInstance3D = _perto.get(v)
		if mi == null:
			var e: Dictionary = _info[lista[v]]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			var am: ArrayMesh = malha(lista[v]).duplicate()
			am.surface_set_material(0, mat_casca(String(e["casca"])))
			if am.get_surface_count() > 1:
				am.surface_set_material(1, mat_folha(String(e["folha"])))
			mm.mesh = am
			mi = MultiMeshInstance3D.new()
			mi.name = "ArvoresPerto_" + String(lista[v])
			mi.multimesh = mm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_perto[v] = mi
		mi.visible = true
		mi.multimesh.instance_count = buf.size() / 20
		mi.multimesh.buffer = buf
		# a caixa (AABB) cobre o círculo de perto inteiro (a Godot não precisa recalcular a cada troca)
		mi.multimesh.custom_aabb = AABB(Vector3(c.x - r - 15.0, -5.0, c.z - r - 15.0), Vector3(2.0 * r + 30.0, 60.0, 2.0 * r + 30.0))
		mi.global_transform = Transform3D.IDENTITY

# quantas árvores de verdade estão na lista de perto agora (testes)
func perto_agora() -> int:
	var n := 0
	for v in _perto:
		if _perto[v].visible:
			n += _perto[v].multimesh.instance_count
	return n
