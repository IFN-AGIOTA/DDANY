extends CanvasLayer
# VISTA DA LUNETA (0.99) · mira 4x (M4A1, AKM) e luneta do rifle de caça. Criada pelo jogador (jogador/jogador.gd)
# na 1ª vez que você mira com uma delas.
#   - A câmera do jogo vai para o olho, atrás da ocular (armas/mira_ferro.gd LUNETAS): em volta aparece a própria
#     luneta 3D, a arma e a cena de fora, levemente DESFOCADA (o olho está focado na lente).
#   - Dentro do VIDRO da ocular, uma 2ª câmera (só ligada enquanto você olha pela luneta) desenha a vista AMPLIADA
#     ("aumento": 4x na mira, 6x na luneta), na direção do tubo da luneta (o retículo mostra onde a arma aponta).
#   - Efeito de LENTE: borda escura, a sombra em meia-lua quando o olho não está no centro (entrando na mira, no
#     coice), leve curvatura e cores separando perto da borda, reflexo do vidro e o RETÍCULO desenhado na lente:
#     luneta = cruz fina com traços grossos nas pontas (duplex); mira 4x = divisa vermelha acesa com a escala de queda.
# Mexa AQUI para: a qualidade da imagem ampliada (QUALIDADE), o desfoque de fora, a aparência da lente e os retículos.

const MiraFerro := preload("res://armas/mira_ferro.gd")
const QUALIDADE := 0.85                 # resolução da imagem ampliada (1 = um pixel por pixel da tela)
const PX_MAX := 900
const PERTO := 0.45                     # a 2ª câmera não desenha nada mais perto que isso (a própria arma e a luneta)

var jogador = null
var alfa := 0.0                         # 0 = escondida · 1 = olhando pela luneta (testes leem)
var centro := Vector2.ZERO              # centro do vidro na tela (px) e raio (px) · testes leem
var raio := 0.0

var _sv: SubViewport
var _cam: Camera3D
var _fora: ColorRect                    # desfoque da cena fora da lente
var _lente: TextureRect
var _mat_lente: ShaderMaterial
var _mat_fora: ShaderMaterial

const SHADER_LENTE := """
shader_type canvas_item;
uniform float alfa = 1.0;
uniform vec2 desalinho = vec2(0.0);     // olho fora do centro (em raios da lente)
uniform int reticulo = 0;               // 0 = duplex (luneta) · 1 = divisa da mira 4x

float traco(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	float d = length(pa - ba * h);
	float aa = fwidth(d) + 0.0015;
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + aa, d);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;            // -1..1 (y para baixo)
	float r = length(p);
	// lente: um pouco de curvatura e as cores separando perto da borda
	vec2 q = p * (1.0 - 0.06 * r * r);
	float ab = 0.014 * r * r;
	vec3 c;
	c.r = texture(TEXTURE, q * (1.0 + ab) * 0.5 + 0.5).r;
	c.g = texture(TEXTURE, q * 0.5 + 0.5).g;
	c.b = texture(TEXTURE, q * (1.0 - ab) * 0.5 + 0.5).b;
	// borda escura e a sombra em meia-lua do olho fora do centro
	float borda = smoothstep(0.7, 1.0, r);
	float sombra = smoothstep(0.62, 1.08, length(p + desalinho * 1.7));
	c *= (1.0 - 0.7 * borda) * (1.0 - 0.95 * sombra);
	// vidro bom: um pouco mais de contraste, tom levemente frio e um reflexo fraco no alto à esquerda
	c = clamp((c - 0.5) * 1.12 + 0.48, 0.0, 1.0) * vec3(0.97, 0.99, 1.03);
	c += vec3(0.04, 0.05, 0.065) * pow(max(0.0, 1.0 - length(p - vec2(-0.5, -0.55)) * 1.1), 2.0);
	// retículo
	float preto = 0.0;
	vec3 aceso = vec3(0.0);
	float luz = 0.0;
	if (reticulo == 0) {
		// duplex: cruz fina no meio, traços grossos de 0,45 até a borda
		preto = max(preto, traco(p, vec2(-0.45, 0.0), vec2(0.45, 0.0), 0.006));
		preto = max(preto, traco(p, vec2(0.0, -0.45), vec2(0.0, 0.45), 0.006));
		preto = max(preto, traco(p, vec2(-1.1, 0.0), vec2(-0.45, 0.0), 0.028));
		preto = max(preto, traco(p, vec2(0.45, 0.0), vec2(1.1, 0.0), 0.028));
		preto = max(preto, traco(p, vec2(0.0, 0.45), vec2(0.0, 1.1), 0.028));
		preto = max(preto, traco(p, vec2(0.0, -1.1), vec2(0.0, -0.45), 0.028));
	} else {
		// mira 4x: divisa (^) acesa com a ponta no centro, escala de queda embaixo e linhas pretas dos lados
		luz = max(traco(p, vec2(0.0, 0.0), vec2(-0.075, 0.085), 0.016), traco(p, vec2(0.0, 0.0), vec2(0.075, 0.085), 0.016));
		aceso = vec3(1.0, 0.22, 0.08);
		preto = max(preto, traco(p, vec2(0.0, 0.14), vec2(0.0, 0.62), 0.006));
		for (int i = 1; i <= 4; i++) {
			float y = 0.14 + float(i) * 0.1;
			float w = 0.07 - float(i) * 0.012;
			preto = max(preto, traco(p, vec2(-w, y), vec2(w, y), 0.006));
		}
		preto = max(preto, traco(p, vec2(-1.1, 0.0), vec2(-0.32, 0.0), 0.012));
		preto = max(preto, traco(p, vec2(0.32, 0.0), vec2(1.1, 0.0), 0.012));
	}
	c = mix(c, vec3(0.01), preto * 0.95);
	c = mix(c, aceso * 1.4, luz);
	float a = (1.0 - smoothstep(0.965, 1.0, r)) * alfa;
	COLOR = vec4(c, a);
}
"""

const SHADER_FORA := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float quanto = 0.0;
uniform vec2 centro = vec2(0.5);        // centro da lente (0..1 da tela)
uniform float raio = 0.2;               // raio da lente (em alturas da tela)
uniform float aspecto = 1.78;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(tela, uv).rgb * 0.2;
	float s = 0.0045;
	for (int i = 0; i < 8; i++) {
		float an = float(i) * 0.785398;
		vec2 o = vec2(cos(an) / aspecto, sin(an)) * s;
		c += texture(tela, uv + o).rgb * 0.06;
		c += texture(tela, uv + o * 2.2).rgb * 0.04;
	}
	vec2 d = (uv - centro) * vec2(aspecto, 1.0);
	float fora = smoothstep(0.98, 1.3, length(d) / raio);
	COLOR = vec4(c * 0.82, quanto * fora);
}
"""

func _ready() -> void:
	layer = 2                           # por cima da cena, embaixo da HUD e dos botões
	# a arma só fica no lugar final depois do esqueleto (IK) atualizar, no fim do quadro: a conta é feita logo antes
	# de desenhar, senão o vidro ficava deslocado da ocular 3D
	RenderingServer.frame_pre_draw.connect(_antes_de_desenhar)
	_sv = SubViewport.new()
	_sv.name = "VistaAmpliada"
	_sv.size = Vector2i(256, 256)
	_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sv.use_occlusion_culling = get_viewport().use_occlusion_culling
	_sv.mesh_lod_threshold = get_viewport().mesh_lod_threshold
	_sv.audio_listener_enable_3d = false
	add_child(_sv)
	_cam = Camera3D.new()
	_cam.near = PERTO
	_cam.current = true
	_sv.add_child(_cam)
	_fora = ColorRect.new()
	_fora.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fora.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat_fora = _material(SHADER_FORA)
	_fora.material = _mat_fora
	add_child(_fora)
	_lente = TextureRect.new()
	_lente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lente.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lente.stretch_mode = TextureRect.STRETCH_SCALE
	_lente.texture = _sv.get_texture()
	_mat_lente = _material(SHADER_LENTE)
	_lente.material = _mat_lente
	add_child(_lente)
	visible = false

static func _material(codigo: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = codigo
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_antes_de_desenhar):
		RenderingServer.frame_pre_draw.disconnect(_antes_de_desenhar)

var _dt := 0.0
func _process(dt: float) -> void:
	_dt += dt

func _antes_de_desenhar() -> void:
	var dt := _dt
	_dt = 0.0
	if not is_inside_tree():
		return
	var lid := ""
	var arma: Node3D = null
	var cam: Camera3D = jogador.camera if jogador != null and is_instance_valid(jogador) else null
	if cam != null and jogador.em_luneta():
		lid = jogador.luneta_montada()
		arma = jogador.armas.nos.get(jogador.armas.atual)
		if arma != null and (not is_instance_valid(arma) or not arma.is_inside_tree()):
			arma = null
	var tipo: String = str(jogador.armas.atual) if arma != null else ""
	var pos_ok := false
	var oc := Vector3.ZERO
	if arma != null:
		oc = arma.global_transform * MiraFerro.ocular(tipo, lid)
		pos_ok = not cam.is_position_behind(oc)
	alfa = move_toward(alfa, 1.0 if pos_ok else 0.0, dt * (7.0 if pos_ok else 14.0))
	var ver := alfa > 0.001 and pos_ok
	visible = ver
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if ver else SubViewport.UPDATE_DISABLED
	if not ver:
		return
	var l: Dictionary = MiraFerro.LUNETAS[lid]
	var gt := arma.global_transform
	# 2ª câmera: no olho, olhando pelo tubo; o campo de visão é o do vidro dividido pelo aumento
	_cam.global_transform = (gt * MiraFerro.quadro_olho(tipo, lid)).orthonormalized()
	var tan_vidro := float(l["vidro"]) / float(l["olho"])
	_cam.fov = rad_to_deg(2.0 * atan(tan_vidro / float(l["aumento"])))
	_cam.far = cam.far
	_cam.environment = cam.environment
	_cam.attributes = cam.attributes
	# o vidro na tela: onde a ocular aparece pela câmera do jogo
	centro = cam.unproject_position(oc)
	var borda := cam.unproject_position(gt * (MiraFerro.ocular(tipo, lid) + Vector3(0, float(l["vidro"]), 0)))
	raio = maxf(4.0, centro.distance_to(borda))
	var tela := get_viewport().get_visible_rect().size
	var px := clampi(int(raio * 2.0 * QUALIDADE), 64, PX_MAX)
	if _sv.size.x != px:
		_sv.size = Vector2i(px, px)
	_lente.position = centro - Vector2(raio, raio)
	_lente.size = Vector2(raio, raio) * 2.0
	_mat_lente.set_shader_parameter("alfa", smoothstep(0.0, 1.0, alfa))
	_mat_lente.set_shader_parameter("desalinho", (centro - tela * 0.5) / raio)
	_mat_lente.set_shader_parameter("reticulo", int(l["reticulo"]))
	_mat_fora.set_shader_parameter("quanto", alfa)
	_mat_fora.set_shader_parameter("centro", centro / tela)
	_mat_fora.set_shader_parameter("raio", raio / tela.y)
	_mat_fora.set_shader_parameter("aspecto", tela.x / tela.y)
