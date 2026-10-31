extends CanvasLayer
# FILTRO DE TELA (Opções › Gráficos): brilho, contraste, saturação e vinheta por cima da imagem 3D
# (fica abaixo da HUD e dos menus). Só aparece quando alguma dessas opções sai do padrão.

const SHADER := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float brilho = 1.0;
uniform float contraste = 1.0;
uniform float saturacao = 1.0;
uniform float vinheta = 0.0;
void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb * brilho;
	c = (c - 0.5) * contraste + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturacao);
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vinheta * smoothstep(0.35, 0.85, length(d * vec2(1.25, 1.0)));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	layer = 4
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
	visible = false

func definir(brilho: float, contraste: float, saturacao: float, vinheta: bool) -> void:
	if _mat == null:
		_ready()
	_mat.set_shader_parameter("brilho", brilho)
	_mat.set_shader_parameter("contraste", contraste)
	_mat.set_shader_parameter("saturacao", saturacao)
	_mat.set_shader_parameter("vinheta", 0.75 if vinheta else 0.0)
	visible = not (is_equal_approx(brilho, 1.0) and is_equal_approx(contraste, 1.0) and is_equal_approx(saturacao, 1.0) and not vinheta)
