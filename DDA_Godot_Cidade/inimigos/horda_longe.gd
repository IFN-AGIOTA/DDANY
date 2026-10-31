extends Node3D
# HORDA DE LONGE (1.00 · "impostores", estudos/ESTUDO_AAA.md 2.5): os grupos VIRTUAIS da população (inimigos/horda.gd)
# que estão de LONGE_MIN a LONGE_MAX m do jogador aparecem como silhuetas: cada infectado é um cartaz de 2 triângulos
# virado para a câmera (só no eixo de pé), com 4 quadros de andar desenhados por código numa textura pequena.
# Tudo num MultiMesh só (1 chamada de desenho para a horda inteira) atualizado A_CADA s: a cidade parece cheia sem
# custo de IA. Mais perto que LONGE_MIN os grupos viram infectados de verdade (horda.gd REAL = 95 m).
# Só no jogo solo e no host (no cliente a população não existe).
# Mexa AQUI para: distâncias, quantos no máximo, tamanho da silhueta, quantos de cada grupo aparecem.

const LONGE_MIN := 100.0
const LONGE_MAX := 230.0
const MAX := 300                       # silhuetas no máximo
const POR_GRUPO := 14                  # de um grupo grande aparecem no máximo tantos
const A_CADA := 0.4
const LARGURA := 0.9
const ALTURA := 1.8
const QUADROS := 4
const PX := Vector2i(32, 64)           # tamanho de cada quadro da textura

const SHADER := """
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec2 tam = vec2(0.9, 1.8);
varying float quadro;
void vertex() {
	// cartaz em pé virado para a câmera (gira só em volta do eixo Y)
	vec3 origem = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 para = cam - origem;
	para.y = 0.0;
	para = normalize(para + vec3(0.0001, 0.0, 0.0));
	vec3 lado = vec3(para.z, 0.0, -para.x);
	VERTEX = origem + lado * (UV.x - 0.5) * tam.x + vec3(0.0, (1.0 - UV.y) * tam.y, 0.0);
	NORMAL = para;
	// andando (INSTANCE_CUSTOM.x = 1): troca o quadro; parado: fica no quadro 0
	float t = TIME * 5.0 + float(INSTANCE_ID) * 1.37;
	quadro = INSTANCE_CUSTOM.x > 0.5 ? floor(mod(t, 4.0)) : 0.0;
}
void fragment() {
	vec4 c = texture(atlas, vec2((UV.x + quadro) / 4.0, UV.y));
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}
"""

var horda: Node = null                 # inimigos/horda.gd
var gerente: Node = null               # inimigos/vagos.gd
var mm: MultiMesh
var mostrados := 0                     # (testes) quantas silhuetas na última atualização
var _t := 0.0
static var _material: ShaderMaterial = null

static func material() -> ShaderMaterial:
	if _material == null:
		var sh := Shader.new()
		sh.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = sh
		_material.set_shader_parameter("atlas", _atlas())
		_material.set_shader_parameter("tam", Vector2(LARGURA, ALTURA))
	return _material

# 4 quadros de silhueta andando (cabeça torta, braços para a frente, pernas alternando), em cinza escuro
static func _atlas() -> ImageTexture:
	var img := Image.create(PX.x * QUADROS, PX.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cor := Color(0.32, 0.3, 0.29)
	for q in QUADROS:
		var ox := q * PX.x
		var passo := sin(q * PI * 0.5) * 6.0             # pernas: -6..6 px
		_elipse(img, ox + 17, 9, 4.2, 5.0, cor)           # cabeça (um pouco torta)
		_reta(img, ox + 16, 15, ox + 16, 37, 5.5, cor)     # tronco
		_reta(img, ox + 16, 18, ox + 25, 27 + int(passo * 0.3), 2.6, cor)   # braço da frente (esticado)
		_reta(img, ox + 15, 18, ox + 22, 30 - int(passo * 0.3), 2.4, cor * 0.9)
		_reta(img, ox + 15, 37, ox + 15 + int(passo), 61, 3.0, cor)          # pernas
		_reta(img, ox + 17, 37, ox + 17 - int(passo), 61, 3.0, cor * 0.9)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _elipse(img: Image, cx: int, cy: int, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)

static func _reta(img: Image, x0: int, y0: int, x1: int, y1: int, grossura: float, c: Color) -> void:
	var n := maxi(absi(x1 - x0), absi(y1 - y0)) * 2 + 1
	for k in n + 1:
		var t := float(k) / n
		_elipse(img, int(round(lerpf(x0, x1, t))), int(round(lerpf(y0, y1, t))), grossura * 0.5, grossura * 0.5, c)

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(LARGURA, ALTURA)
	mm.mesh = quad
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = "Silhuetas"
	mi.multimesh = mm
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-20000, -100, -20000), Vector3(40000, 400, 40000))   # posições mudam: nunca "sai da câmera"
	add_child(mi)

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = A_CADA
	atualizar()

func atualizar() -> void:
	if horda == null or gerente == null or gerente.jogador == null or bool(gerente.get("sem_jogador")):
		mm.visible_instance_count = 0
		mostrados = 0
		return
	var pj: Vector3 = gerente.jogador.global_position
	var p2 := Vector2(pj.x, pj.z)
	var mundo = gerente.mundo
	var n := 0
	for g in horda.grupos:
		if n >= MAX:
			break
		var gp: Vector2 = g["p"]
		var d := gp.distance_to(p2)
		if d < LONGE_MIN or d > LONGE_MAX:
			continue
		var anda: bool = g["d"] != Vector2.INF
		var k_max := mini(int(g["n"]), POR_GRUPO)
		for k in k_max:
			if n >= MAX:
				break
			# espiral de "girassol" em volta do meio do grupo (sempre igual para o mesmo grupo)
			var ang := k * 2.39996
			var r := 0.9 * sqrt(float(k))
			var q := gp + Vector2(cos(ang), sin(ang)) * r
			var y: float = mundo.altura(q.x, q.y) if mundo != null else 0.0
			mm.set_instance_transform(n, Transform3D(Basis.IDENTITY, Vector3(q.x, y, q.y)))
			var tom := 0.8 + 0.4 * fposmod(k * 0.618 + float(int(gp.x)) * 0.13, 1.0)
			mm.set_instance_color(n, Color(tom, tom * 0.97, tom * 0.95))
			mm.set_instance_custom_data(n, Color(1.0 if anda else 0.0, 0, 0, 0))
			n += 1
	mm.visible_instance_count = n
	mostrados = n
