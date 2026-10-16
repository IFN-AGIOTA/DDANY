extends Node3D
# CENA 3D DO MENU PRINCIPAL (porte do menuScene/menuCam/menuPose do HTML v1.1.19):
# pôr do sol alaranjado, skyline de Nova York em camadas sumindo na névoa, torres em degraus, sol baixo com brilho,
# faixas de nuvem, colunas de fumaça, terraço em primeiro plano, poeira flutuando e o soldado com a M4 baixa
# olhando o horizonte (à direita da tela). Não depende da cidade: abre na hora.
# Mexa AQUI para: cores do céu, posição do sol, densidade da skyline, pose/posição do soldado e da câmera.
# (Coordenadas do HTML giradas 180° no eixo Y: x -> -x, z -> -z, porque a frente na Godot é -Z.)

const SobreviventeCls := preload("res://jogador/modelo_sobrevivente.gd")
const ItemCls := preload("res://inventario/item.gd")
const ModelosArmas := preload("res://armas/modelos_armas.gd")

const NEVOA := Color("#f0a05a")
const CAM_Y := 1.52
const FOV := 42.0
const DIST := 2.35

var camera: Camera3D
var soldado: Node3D
var _fumaca: Array = []           # {no, x, i, d}
var _poeira: CPUParticles3D
var _semente := 31337
var _t := 0.0

func _rnd() -> float:            # mesmo gerador do HTML (mnRnd) para a skyline sair igual
	_semente = (_semente * 1664525 + 1013904223) & 0xFFFFFFFF
	return float(_semente) / 4294967296.0

static func _dir(az: float, el: float, d: float) -> Vector3:
	return Vector3(-sin(az) * cos(el) * d, sin(el) * d, -cos(az) * cos(el) * d)

func _ready() -> void:
	_ambiente()
	_sol_e_nuvens()
	_skyline()
	_terraco()
	_poeira_no_ar()
	_soldado()
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.1
	camera.far = 4000.0
	camera.environment = _env
	add_child(camera)
	camera.make_current()
	_camera(0.0)

# ---------- céu, luzes ----------
var _env: Environment

const SHADER_CEU := """
shader_type sky;
// degradê do pôr do sol: âmbar -> vermelho-queimado -> roxo escuro (mesmas paradas do HTML)
const vec3 C0 = vec3(0.941, 0.627, 0.353);
const vec3 C1 = vec3(0.914, 0.541, 0.282);
const vec3 C2 = vec3(0.816, 0.416, 0.227);
const vec3 C3 = vec3(0.604, 0.263, 0.196);
const vec3 C4 = vec3(0.353, 0.145, 0.188);
const vec3 C5 = vec3(0.141, 0.071, 0.125);
void sky() {
	float t = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 c = mix(C0, C1, smoothstep(0.0, 0.05, t));
	c = mix(c, C2, smoothstep(0.05, 0.14, t));
	c = mix(c, C3, smoothstep(0.14, 0.30, t));
	c = mix(c, C4, smoothstep(0.30, 0.55, t));
	c = mix(c, C5, smoothstep(0.55, 1.0, t));
	COLOR = c;
}
"""

func _ambiente() -> void:
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CEU
	sm.shader = sh
	var ceu := Sky.new()
	ceu.sky_material = sm
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = ceu
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("#ffb072")
	_env.ambient_light_energy = 0.75
	var sol := DirectionalLight3D.new()
	sol.light_color = Color("#ff8a3c")
	sol.light_energy = 1.9
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 25.0
	add_child(sol)
	sol.look_at_from_position(Vector3(-260, 131, -1480).normalized() * 50.0, Vector3.ZERO)
	var contorno := DirectionalLight3D.new()       # luz quente do lado esquerdo do soldado
	contorno.light_color = Color("#ff9a48")
	contorno.light_energy = 1.1
	add_child(contorno)
	contorno.look_at_from_position(Vector3(-4, 2.2, -3), Vector3.ZERO)
	# massa da cidade lá embaixo: escura perto, cor da névoa ao longe
	var base := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	var bm := ShaderMaterial.new()
	var bs := Shader.new()
	bs.code = """
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
varying vec3 p;
void vertex() { p = VERTEX; }
void fragment() {
	float r = pow(clamp(length(p.xz) / 2600.0, 0.0, 1.0), 0.6);
	ALBEDO = mix(vec3(0.180, 0.090, 0.051), vec3(0.847, 0.533, 0.282), r);
}
"""
	bm.shader = bs
	pm.material = bm
	base.mesh = pm
	base.position.y = -260.0
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)

# ---------- sol baixo + faixas de nuvem (sprites com degradê radial) ----------
const SHADER_SPRITE := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled%s;
uniform vec4 c_in : source_color = vec4(1.0);
uniform vec4 c_out : source_color = vec4(1.0, 1.0, 1.0, 0.0);
void vertex() {
	// sempre de frente para a câmera, mantendo a escala
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = mv * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float r = clamp(length(UV - 0.5) * 2.0, 0.0, 1.0);
	vec4 c = mix(c_in, c_out, r);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""
var _sh_somar: Shader
var _sh_misturar: Shader
var _quad: QuadMesh

func _sprite(c_in: Color, c_out: Color, tam: Vector2, pos: Vector3, somar: bool) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_sh_somar = Shader.new()
		_sh_somar.code = SHADER_SPRITE % ", blend_add"
		_sh_misturar = Shader.new()
		_sh_misturar.code = SHADER_SPRITE % ""
	var m := ShaderMaterial.new()
	m.shader = _sh_somar if somar else _sh_misturar
	m.set_shader_parameter("c_in", c_in)
	m.set_shader_parameter("c_out", c_out)
	m.render_priority = -1
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(tam.x, tam.y, 1.0)
	mi.position = pos
	add_child(mi)
	return mi

func _sol_e_nuvens() -> void:
	var sd := _dir(0.17, deg_to_rad(5.0), 1500.0)
	_sprite(Color(1.0, 0.745, 0.431, 0.95), Color(1.0, 0.431, 0.118, 0.0), Vector2(2300, 2300), sd, true)
	_sprite(Color(1.0, 0.882, 0.667, 1.0), Color(1.0, 0.588, 0.235, 0.0), Vector2(560, 560), sd, true)
	_sprite(Color(1.0, 0.98, 0.91, 1.0), Color(1.0, 0.933, 0.784, 0.0), Vector2(150, 150), sd, true)
	# [azimute, elevação°, largura, altura, cor, opacidade, somar]
	for q in [[0.6, 9, 1100, 70, "#70302a", 0.55, false], [-0.5, 13, 1300, 90, "#5c2829", 0.5, false], [0.1, 17, 1500, 110, "#4e2229", 0.5, false],
			[1.0, 6, 900, 55, "#7a3a2c", 0.5, false], [-1.1, 8, 1000, 60, "#6a2f2c", 0.45, false],
			[0.35, 7, 1000, 38, "#ff8a3a", 0.55, true], [-0.2, 10.5, 1200, 44, "#ff9a4c", 0.45, true], [0.8, 11, 1000, 40, "#ff7a30", 0.45, true]]:
		var c := Color(q[4])
		_sprite(Color(c.r, c.g, c.b, q[5]), Color(c.r, c.g, c.b, 0.0), Vector2(q[2], q[3]), _dir(q[0], deg_to_rad(q[1]), 1650.0), q[6])

# ---------- skyline em camadas (silhuetas com névoa por distância) + torres em degraus ----------
func _skyline() -> void:
	var escuro := Color("#1d0f09")
	var piso := -300.0
	var itens: Array = []          # [pos, tamanho, ry, rz, cor]
	for dd in [190.0, 300.0, 430.0, 590.0, 780.0, 1000.0, 1250.0, 1500.0]:
		var d: float = dd
		var f := clampf(1.0 - exp(-d / 640.0), 0.0, 1.0) * 0.98
		var az := -1.75
		while az < 1.75:
			var w := 16.0 + _rnd() * 40.0
			var dp := 18.0 + _rnd() * 30.0
			az += (w * (0.9 + _rnd() * 0.25)) / d
			if _rnd() < 0.06:
				continue
			var ang := deg_to_rad(-13.0 * exp(-d / 450.0) + _rnd() * (3.4 + 2.0 * d / 1000.0))
			var topo := CAM_Y + d * tan(ang)
			var h := topo - piso
			var c := escuro.lerp(NEVOA, f) * (0.88 + _rnd() * 0.2)
			var rz := (_rnd() - 0.5) * 0.24 if _rnd() < 0.05 else 0.0       # alguns prédios inclinados (ruína)
			itens.append([Vector3(-d * sin(az), piso + h / 2.0, -d * cos(az)), Vector3(w, h, dp), az, rz, c])
			if _rnd() < 0.16:                                               # antenas
				var h2 := 10.0 + _rnd() * 30.0
				itens.append([Vector3(-d * sin(az), topo + h2 / 2.0, -d * cos(az)), Vector3(1.6, h2, 1.6), az, 0.0, c])
	for tw in [[720.0, -0.1, [[46, 32], [34, 52], [22, 68], [12, 78], [3.2, 112]]], [930.0, 0.46, [[40, 40], [28, 64], [16, 84], [7, 98], [2.6, 126]]]]:
		var d: float = tw[0]
		var az: float = tw[1]
		var c := escuro.lerp(NEVOA, clampf(1.0 - exp(-d / 640.0), 0.0, 1.0) * 0.98) * 0.95
		for t in tw[2]:
			itens.append([Vector3(-d * sin(az), piso + (t[1] - piso) / 2.0, -d * cos(az)), Vector3(t[0], t[1] - piso, t[0]), az, 0.0, c])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = itens.size()
	for i in itens.size():
		var q: Array = itens[i]
		var b := Basis(Vector3.UP, q[2]) * Basis(Vector3.BACK, q[3])
		mm.set_instance_transform(i, Transform3D(b * Basis.from_scale(q[1]), q[0]))
		mm.set_instance_color(i, q[4])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mm.mesh.material = mat
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# colunas de fumaça subindo da cidade
	for q in [[0.30, 420.0, 10], [-0.36, 610.0, 12], [0.62, 860.0, 12], [-0.8, 540.0, 9]]:
		var d: float = q[1]
		var by := CAM_Y + d * tan(deg_to_rad(-13.0 * exp(-d / 450.0) + 1.7))
		var bx := -d * sin(q[0])
		var bz := -d * cos(q[0])
		for i in int(q[2]):
			var sc := d * (0.025 + i * 0.012)
			var op := 0.36 - i * 0.018
			var s := _sprite(Color(0.173, 0.090, 0.055, op), Color(0.173, 0.090, 0.055, 0.0), Vector2(sc, sc), Vector3(bx, by + i * d * 0.045, bz), false)
			_fumaca.append({"no": s, "x": bx, "i": i, "d": d})

# ---------- terraço em primeiro plano ----------
func _caixa(tam: Vector3, cor: Color, pos: Vector3, ry := 0.0, mat: Material = null) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	if mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 1.0
		mat = m
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = ry
	add_child(mi)

func _terraco() -> void:
	# laje de concreto com manchas e rachaduras (textura feita por código, como no HTML)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color8(0x5a, 0x4a, 0x40))
	for i in 900:
		var v := 60 + int(_rnd() * 60)
		var a := 0.25 + _rnd() * 0.3
		var px := int(_rnd() * 128)
		var py := int(_rnd() * 128)
		var w := 1 + int(_rnd() * 3)
		var h := 1 + int(_rnd() * 3)
		for yy in range(py, mini(128, py + h)):
			for xx in range(px, mini(128, px + w)):
				img.set_pixel(xx, yy, img.get_pixel(xx, yy).lerp(Color8(v, v - 12, v - 22), a))
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = Vector3(8, 4, 1)
	m.roughness = 1.0
	_caixa(Vector3(28, 2, 14), Color.WHITE, Vector3(0, -1, 4), 0.0, m)
	_caixa(Vector3(28, 0.35, 0.5), Color("#6a5446"), Vector3(0, 0.175, -2.75))        # mureta da borda
	_caixa(Vector3(1.4, 2.2, 1.2), Color("#4a3a30"), Vector3(3.4, 1.1, -1.2))           # ventilação
	var antena := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.05
	cm.height = 5.0
	var am := StandardMaterial3D.new()
	am.albedo_color = Color("#2a2220")
	cm.material = am
	antena.mesh = cm
	antena.position = Vector3(2.6, 2.5, -1.6)
	add_child(antena)
	_caixa(Vector3(1.2, 0.05, 0.05), Color("#2a2220"), Vector3(2.6, 4.4, -1.6))
	_caixa(Vector3(0.8, 0.05, 0.05), Color("#2a2220"), Vector3(2.6, 3.8, -1.6))
	_caixa(Vector3(0.9, 0.6, 0.7), Color("#5b4630"), Vector3(1.8, 0.3, -1.9), 0.4)       # caixotes
	_caixa(Vector3(0.6, 0.5, 0.6), Color("#4a3a2a"), Vector3(2.45, 0.25, -2.15), -0.3)
	_caixa(Vector3(0.5, 0.35, 0.9), Color("#3d2f28"), Vector3(1.0, 0.175, -2.2), 0.9)

# ---------- poeira/cinzas flutuando na luz ----------
func _poeira_no_ar() -> void:
	_poeira = CPUParticles3D.new()
	_poeira.amount = 140
	_poeira.lifetime = 40.0
	_poeira.preprocess = 40.0
	_poeira.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_poeira.emission_box_extents = Vector3(6.0, 2.0, 4.5)
	_poeira.position = Vector3(0, 2.2, -1.5)
	_poeira.direction = Vector3(0, 1, 0)
	_poeira.spread = 60.0
	_poeira.gravity = Vector3.ZERO
	_poeira.initial_velocity_min = 0.03
	_poeira.initial_velocity_max = 0.09
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.75, 0.5, 0.6)
	q.material = m
	_poeira.mesh = q
	add_child(_poeira)

# ---------- soldado ----------
# o SOBREVIVENTE do jogo (jogador/modelo_sobrevivente.gd), equipado: capacete, colete, jaqueta, mochila e a M4
# baixa nas duas mãos, olhando a cidade de costas para a câmera
func _soldado() -> void:
	soldado = SobreviventeCls.new()
	soldado.name = "SobreviventeMenu"
	add_child(soldado)
	soldado.rotation.y = PI + 0.32                  # o manequim olha para +Z; a cidade fica em -Z
	var equip := {"slots": {}}
	for par in [["camisa", "jaqueta"], ["calca", "calca"], ["colete", "colete"], ["cabeca", "capacete"], ["mochila", "mochila_combate"]]:
		equip["slots"][par[0]] = ItemCls.novo(par[1])
	soldado.vestir(_Equip.new(equip["slots"]))
	var m4 := ModelosArmas.construir("m4")
	soldado.segurar_arma("m4", m4)

# o vestir() do sobrevivente só lê "slots" do inventário
class _Equip extends RefCounted:
	var slots := {}
	func _init(s: Dictionary) -> void:
		slots = s

# ---------- animação ----------
func _process(dt: float) -> void:
	_t += dt
	if soldado != null and soldado.has_method("pose_menu"):
		soldado.pose_menu(_t)
	for f in _fumaca:
		(f["no"] as Node3D).position.x = f["x"] + sin(_t * 0.15 + f["i"] * 0.7) * f["d"] * 0.012 * (f["i"] * 0.3 + 1.0)
	_camera(_t)

# câmera parada atrás do soldado (ele fica à direita, ~73% da largura) com leve respiração
func _camera(t: float) -> void:
	if camera == null:
		return
	var asp := get_viewport().get_visible_rect().size.aspect()
	var off := DIST * tan(deg_to_rad(FOV) * 0.5) * asp * 0.46
	var x := off + sin(t * 0.23) * 0.05
	camera.position = Vector3(-x, CAM_Y + sin(t * 0.4) * 0.012, DIST - sin(t * 0.17) * 0.04)
	camera.look_at(Vector3(-(x + sin(t * 0.2) * 0.5), 1.6, -20.0), Vector3.UP)
