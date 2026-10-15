extends Node3D
# FUMAÇA NO HORIZONTE: colunas de fumaça escura saindo de alguns prédios em ruína pela cidade.
# Vistas de longe (dão clima de fim do mundo e servem para se orientar). Cada coluna é 1 quadrado que sempre
# vira para a câmera (só no eixo vertical), com fumaça animada no shader; a neblina e a luz do dia/noite
# pegam nela normalmente. Escolhe no máximo 1 ruína por região de REGIAO x REGIAO m, até MAX colunas.
# Mexa AQUI para: quantas colunas, tamanho, cor e vento da fumaça.

const MAX := 14
const REGIAO := 2600.0
const LARGURA := 70.0
const ALTURA := 260.0

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;
global uniform float vento;
uniform float semente = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return ruido(p) * 0.5 + ruido(p * 2.1) * 0.3 + ruido(p * 4.3) * 0.2; }
void vertex() {
	// sempre de frente para a câmera, girando só em volta do eixo vertical
	vec3 dir = normalize(vec3(CAMERA_POSITION_WORLD.x - MODEL_MATRIX[3].x, 0.0, CAMERA_POSITION_WORLD.z - MODEL_MATRIX[3].z));
	vec3 lado = normalize(cross(vec3(0.0, 1.0, 0.0), dir));
	vec3 w = MODEL_MATRIX[3].xyz + lado * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	NORMAL = (VIEW_MATRIX * vec4(dir, 0.0)).xyz;
}
void fragment() {
	float t = 1.0 - UV.y;                                       // 0 embaixo, 1 no alto
	float tempo = TIME * 0.04;
	float desvio = (0.12 + 0.25 * vento) * t * t + (ruido(vec2(t * 3.0, tempo + semente)) - 0.5) * 0.12 * t;
	float meio = 0.5 + desvio;
	float largura = mix(0.05, 0.42, pow(t, 0.7));
	float x = abs(UV.x - meio) / largura;
	vec2 q = vec2(UV.x * 3.0 + semente, UV.y * 5.0 + tempo * 6.0);
	float n = fbm(q + fbm(q * 0.7 - tempo) * 1.5);
	float corpo = (1.0 - smoothstep(0.35, 1.0, x + (n - 0.5) * 0.7)) * smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.55, 1.0, t));
	float a = clamp(corpo * (0.55 + 0.6 * n), 0.0, 1.0);
	ALBEDO = mix(vec3(0.07, 0.065, 0.06), vec3(0.32, 0.31, 0.30), t * 0.8 + n * 0.2);
	ALPHA = a * 0.85;
	ROUGHNESS = 1.0;
}
"""

var colunas := 0

func montar(cidade: Node3D) -> void:
	var sh := Shader.new()
	sh.code = SHADER
	var regioes := {}
	var r := RandomNumberGenerator.new()
	r.seed = 1977
	var ruinas: Array = cidade.ruinas.duplicate()
	# ordem sorteada (sempre a mesma), para não pegar só as primeiras do mapa
	for i in range(ruinas.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = ruinas[i]
		ruinas[i] = ruinas[j]
		ruinas[j] = tmp
	var qm := QuadMesh.new()
	qm.size = Vector2(LARGURA, ALTURA)
	qm.center_offset = Vector3(0.0, ALTURA * 0.5, 0.0)
	for ru in ruinas:
		if colunas >= MAX:
			break
		var key := Vector2i(floori(float(ru[0]) / REGIAO), floori(float(ru[1]) / REGIAO))
		if regioes.has(key):
			continue
		regioes[key] = true
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("semente", r.randf() * 50.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = ALTURA
		mi.position = Vector3(float(ru[0]), 0.6 + float(ru[4]) * 0.6, float(ru[1]))
		add_child(mi)
		colunas += 1
