extends MeshInstance3D
# CÉU DA NOITE (0.92): ESTRELAS e LUA por cima do céu (o céu do jogo é o "ProceduralSky" da Godot, que não tem nada
# disso). É uma esfera grande que acompanha a câmera, desenhada sem neblina e somando luz: os prédios, o chão e o mato
# na frente tapam (teste de profundidade normal). Criada por mundo/clima.gd, que diz quanto aparece (escuro e nuvens)
# e onde está a lua (a mesma direção da luz da lua). Mexa AQUI para: quantas estrelas, tamanho e brilho da lua.

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform float forca = 0.0;              // 0 = dia (nada) · 1 = noite fechada
uniform float nuvens = 0.0;             // céu coberto esconde as estrelas e quase toda a lua
uniform vec3 lua_dir = vec3(0.0, -1.0, 0.0);
uniform float lua = 0.0;                // 0..1 a lua está acima do horizonte
varying vec3 dir;
float hash(vec2 p) {
	p = mod(p, 4096.0);
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
void vertex() {
	dir = VERTEX;
}
void fragment() {
	vec3 d = normalize(dir);
	float acima = smoothstep(0.0, 0.12, d.y);
	// estrelas: grade de ~0,5 grau no céu, 1,6% das células tem uma (tamanho e brilho sorteados, piscando de leve)
	vec2 sc = vec2(atan(d.z, d.x) * 115.0, asin(clamp(d.y, -1.0, 1.0)) * 115.0);
	vec2 cel = floor(sc);
	vec2 f = fract(sc) - 0.5 - (vec2(hash(cel + 3.1), hash(cel + 7.7)) - 0.5) * 0.6;
	float h = hash(cel);
	float tam = 0.07 + 0.1 * hash(cel + 1.3);
	float est = step(0.984, h) * (1.0 - smoothstep(tam * 0.4, tam, length(f)));
	est *= (0.35 + 0.65 * hash(cel + 9.1)) * (0.75 + 0.25 * sin(TIME * (1.5 + 3.0 * hash(cel + 4.4)) + h * 60.0));
	vec3 cor_est = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.9, 0.75), hash(cel + 2.2));
	// lua: disco com manchas e um brilho em volta
	vec3 ld = normalize(lua_dir);
	float ml = dot(d, ld);
	float disco = smoothstep(0.99955, 0.99975, ml);
	vec3 lado = normalize(cross(ld, vec3(0.0, 1.0, 0.0)) + vec3(1e-4));
	vec2 pl = vec2(dot(d - ld, lado), dot(d - ld, cross(lado, ld))) * 900.0;
	float manchas = 0.82 + 0.18 * hash(floor(pl * 0.5));
	float halo = pow(max(ml, 0.0), 900.0) * 0.35 + pow(max(ml, 0.0), 60.0) * 0.06;
	vec3 c = cor_est * est * 1.1 * (1.0 - nuvens * 0.95) * acima;
	c += (vec3(0.95, 0.95, 0.88) * disco * manchas * 1.4 + vec3(0.55, 0.62, 0.8) * halo) * lua * (1.0 - nuvens * 0.75);
	ALBEDO = c * forca;
}
"""

var _mat: ShaderMaterial

func _ready() -> void:
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	esfera.radial_segments = 32
	esfera.rings = 16
	mesh = esfera
	var s := Shader.new()
	s.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = s
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 100000.0
	top_level = true
	visible = false

# mundo/clima.gd chama a cada atualização do céu
func definir(forca: float, nuvens: float, lua_dir: Vector3, lua: float) -> void:
	visible = forca > 0.01
	_mat.set_shader_parameter("forca", forca)
	_mat.set_shader_parameter("nuvens", nuvens)
	_mat.set_shader_parameter("lua_dir", lua_dir)
	_mat.set_shader_parameter("lua", lua)

func _process(_dt: float) -> void:
	if not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var r := cam.far * 0.85
	global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r), cam.global_position)
