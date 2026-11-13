extends CanvasLayer
# VISTA DA LUNETA · mira 4x (M4A1, AKM) e luneta do rifle de caça. Criada pelo jogador (jogador/jogador.gd) na 1ª vez
# que você mira com uma delas.
# 0.99.2 · LEVE (técnica de "uma câmera só", a dos jogos de celular e do modo simples dos jogos grandes). A 0.99
# desenhava a cidade DUAS vezes (uma 2ª câmera só para o vidro, "picture-in-picture", como Tarkov/Insurgency): no
# computador de teste o quadro ficava 67% mais lento. Agora:
#   - entrando na mira, a arma sobe com a luneta 3D (armas/mira_ferro.gd LUNETAS) e, com ela no olho, um "piscar"
#     escuro rápido (FECHAR + ABRIR) esconde a troca;
#   - na troca, a PRÓPRIA câmera do jogo aproxima (campo de visão dividido pelo "aumento": 4x na mira, 6x na luneta)
#     e a arma some (ela ficaria na frente do olho). Com o campo estreito, menos coisas entram na tela: olhar pela
#     luneta fica até mais leve que sem mirar;
#   - por cima, UMA passada 2D (este arquivo) desenha a lente: dentro do vidro a imagem nítida com leve curvatura e
#     cores separando na borda, sombra da borda e o RETÍCULO; o tubo escuro em volta; e fora dele a cena desfocada e
#     escura (o olho está focado na lente).
#   - soltando a mira (ou recarregando), o mesmo piscar volta tudo ao normal.
# Mexa AQUI para: tamanho do vidro (RAIO), espessura do tubo (TUBO), tempo do piscar, a lente e os retículos.

const MiraFerro := preload("res://armas/mira_ferro.gd")
const RAIO := {"luneta": 0.42, "mira_acog": 0.38}    # raio do vidro, em alturas da tela
const TUBO := 0.09                      # espessura do tubo escuro em volta do vidro (alturas da tela)
const FECHAR := 0.08                    # s escurecendo antes da troca
const ABRIR := 0.14                     # s clareando depois
const ESPERA := 0.12                    # s com a arma no olho antes de trocar (a subida da arma aparece)

var jogador = null
var ativa := false                      # câmera aproximada e arma escondida (jogador.gd usa fov_luneta)
var fov_luneta := 30.0
var luneta := ""                        # a luneta da vista ativa
var escuro := 0.0                       # o piscar da troca (0..1)
var centro := Vector2.ZERO              # centro e raio do vidro na tela (px) · testes leem
var raio := 0.0
var alfa := 0.0                         # 1 = olhando pela luneta (compatível com os testes da 0.99)

var _t_quer := 0.0
var _ponto: Node3D = null               # encaixe da arma escondido enquanto olha pela luneta
var _rect: ColorRect
var _mat: ShaderMaterial

const SHADER := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform float mostrar = 0.0;            // 1 = a lente aparece
uniform float escuro = 0.0;             // piscar da troca
uniform float raio = 0.42;              // raio do vidro (alturas da tela)
uniform float tubo = 0.09;
uniform float aspecto = 1.78;
uniform int reticulo = 0;               // 0 = duplex (luneta) · 1 = divisa da mira 4x

float traco(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	float d = length(pa - ba * h);
	float aa = fwidth(d) + 0.0015;
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + aa, d);
}

void fragment() {
	vec2 d = (SCREEN_UV - 0.5) * vec2(aspecto, 1.0);   // em alturas da tela, (0,0) no centro
	vec2 p = d / raio;                  // -1..1 dentro do vidro (y para baixo)
	float r = length(p);
	vec3 c = vec3(0.0);
	float a = 0.0;
	if (mostrar > 0.5) {
		a = 1.0;
		if (r < 1.0) {
			// vidro: leve curvatura; as cores separam só perto da borda (no meio, 1 leitura só)
			vec2 q = d * (1.0 - 0.06 * r * r);
			vec2 uv = 0.5 + q / vec2(aspecto, 1.0);
			if (r > 0.62) {
				vec2 ab = (uv - 0.5) * 0.014 * r * r;
				c = vec3(texture(tela, uv + ab).r, texture(tela, uv).g, texture(tela, uv - ab).b);
			} else {
				c = texture(tela, uv).rgb;
			}
			c = clamp((c - 0.5) * 1.1 + 0.49, 0.0, 1.0) * vec3(0.97, 0.99, 1.03);
			c *= 1.0 - 0.75 * smoothstep(0.72, 1.0, r);                   // borda escura do vidro
			c += vec3(0.04, 0.05, 0.065) * pow(max(0.0, 1.0 - length(p - vec2(-0.5, -0.55)) * 1.1), 2.0);
			float preto = 0.0;
			float luz = 0.0;
			if (reticulo == 0) {
				preto = max(preto, traco(p, vec2(-0.45, 0.0), vec2(0.45, 0.0), 0.006));
				preto = max(preto, traco(p, vec2(0.0, -0.45), vec2(0.0, 0.45), 0.006));
				preto = max(preto, traco(p, vec2(-1.1, 0.0), vec2(-0.45, 0.0), 0.028));
				preto = max(preto, traco(p, vec2(0.45, 0.0), vec2(1.1, 0.0), 0.028));
				preto = max(preto, traco(p, vec2(0.0, 0.45), vec2(0.0, 1.1), 0.028));
				preto = max(preto, traco(p, vec2(0.0, -1.1), vec2(0.0, -0.45), 0.028));
			} else {
				luz = max(traco(p, vec2(0.0), vec2(-0.075, 0.085), 0.016), traco(p, vec2(0.0), vec2(0.075, 0.085), 0.016));
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
			c = mix(c, vec3(1.0, 0.22, 0.08) * 1.4, luz);
		} else {
			// fora: a cena desfocada (nível pequeno da imagem: barato) e escura, e o tubo da luneta
			vec3 fora = textureLod(tela, SCREEN_UV, 4.5).rgb * 0.42;
			fora *= 1.0 - 0.6 * smoothstep(0.35, 0.95, length(d) / (0.5 * aspecto));
			float rt = 1.0 + tubo / raio;
			float no_tubo = 1.0 - smoothstep(rt - 0.02, rt + 0.06, r);
			vec3 cor_tubo = vec3(0.025, 0.026, 0.03) + vec3(0.05) * smoothstep(rt - 0.1, rt - 0.01, r) * (0.5 - 0.5 * p.y / max(r, 0.001));
			c = mix(fora, cor_tubo, no_tubo);
			c *= smoothstep(1.0, 1.015, r) * 0.85 + 0.15;               // a borda do vidro sem serrilhado
		}
	}
	c = mix(c, vec3(0.0), escuro);
	COLOR = vec4(c, max(a, escuro));
}
"""

# 1.00: o MESMO Shader para todo mundo (menu/pre_aquecer.gd o compila debaixo da tela de carregamento: a 1ª luneta
# não engasga)
static var _shader: Shader = null
static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader

func _ready() -> void:
	layer = 2                           # por cima da cena, embaixo da HUD e dos botões
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = shader()
	_rect.material = _mat
	add_child(_rect)
	visible = false

func _exit_tree() -> void:
	_mostrar_arma()

func _process(dt: float) -> void:
	var ok: bool = jogador != null and is_instance_valid(jogador) and jogador.em_luneta() and float(jogador._fp) > 0.97
	_t_quer = _t_quer + dt if ok else 0.0
	var quer := ok and _t_quer >= ESPERA
	if quer and ativa and jogador.luneta_montada() != luneta:
		quer = false                    # trocou de arma/luneta: sai e entra de novo
	if quer != ativa:
		escuro = move_toward(escuro, 1.0, dt / FECHAR)
		if escuro >= 1.0:
			ativa = quer
			if ativa:
				luneta = jogador.luneta_montada()
				_esconder_arma()
			else:
				_mostrar_arma()
	else:
		escuro = move_toward(escuro, 0.0, dt / ABRIR)
	visible = ativa or escuro > 0.0
	alfa = 1.0 if ativa else 0.0
	if not visible:
		return
	var tela := get_viewport().get_visible_rect().size
	var r_vidro: float = RAIO.get(luneta, 0.4)
	if ativa:
		# a câmera do jogo aproxima "aumento" vezes em relação à 1ª pessoa (jogador.gd aplica fov_luneta)
		var base: float = float(jogador.fov_camera) + 18.0
		var aumento := float(MiraFerro.LUNETAS[luneta]["aumento"])
		fov_luneta = rad_to_deg(2.0 * atan(tan(deg_to_rad(base) * 0.5) / aumento))
	centro = tela * 0.5
	raio = r_vidro * tela.y
	_mat.set_shader_parameter("mostrar", 1.0 if ativa else 0.0)
	_mat.set_shader_parameter("escuro", smoothstep(0.0, 1.0, escuro))
	_mat.set_shader_parameter("raio", r_vidro)
	_mat.set_shader_parameter("tubo", TUBO)
	_mat.set_shader_parameter("aspecto", tela.x / tela.y)
	_mat.set_shader_parameter("reticulo", int(MiraFerro.LUNETAS[luneta]["reticulo"]) if MiraFerro.LUNETAS.has(luneta) else 0)

# a arma ficaria bem na frente do olho com a câmera aproximada: esconde o encaixe das duas mãos (o mesmo que o
# modelo esconde segurando um item) e mostra de novo ao sair
func _esconder_arma() -> void:
	var m = jogador._slot.get_child(0) if jogador._slot.get_child_count() > 0 else null
	if m != null and m.get("_ponto_fuzil") != null:
		_ponto = m._ponto_fuzil
		_ponto.visible = false

func _mostrar_arma() -> void:
	if _ponto != null and is_instance_valid(_ponto):
		_ponto.visible = true
	_ponto = null
