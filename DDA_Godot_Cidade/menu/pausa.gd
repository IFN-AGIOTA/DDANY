extends CanvasLayer
# MENU DE PAUSA (igual ao do HTML): "Pausa" · Continuar · Opções · Voltar ao início · Menu principal,
# com placar ao lado (tempo de jogo e números do estande de tiro) e a faixa quadriculada embaixo.
# Abre com o botão II (canto de cima), P ou Esc. O jogo fica congelado enquanto está aberto.
# Mexa AQUI para: botões e números da pausa.

signal continuar
signal opcoes
signal reiniciar
signal menu_principal

const UI := preload("res://menu/ui.gd")

var estatisticas: Array = []          # [[rótulo, valor], ...] preenchido por quem abre (main.gd)
var _raiz: Control

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_montar)
	_montar()

const SHADER_VEU := """
shader_type canvas_item;
void fragment() {
	float a = UV.x < 0.55 ? mix(0.95, 0.82, UV.x / 0.55) : mix(0.82, 0.45, (UV.x - 0.55) / 0.45);
	COLOR = vec4(0.078, 0.027, 0.008, a);
}
"""
const SHADER_XADREZ := """
shader_type canvas_item;
uniform float lado = 23.0;
void fragment() {
	vec2 c = floor(FRAGCOORD.xy / lado);
	float x = mod(c.x + c.y, 2.0);
	vec3 cor = x < 0.5 ? vec3(0.957, 0.965, 0.98) : vec3(0.043, 0.051, 0.071);
	float m = 1.0 - smoothstep(0.35, 0.85, UV.x);
	COLOR = vec4(cor, m);
}
"""

func _montar() -> void:
	if _raiz != null:
		_raiz.queue_free()
	var v := UI.vh(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var veu := ColorRect.new()
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_VEU
	sm.shader = sh
	veu.material = sm
	_raiz.add_child(veu)
	var lin := HBoxContainer.new()
	lin.add_theme_constant_override("separation", int(5.0 * v))
	lin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	lin.offset_left = 5.0 * v
	lin.offset_right = 120.0 * v
	lin.offset_bottom = -5.0 * v
	lin.alignment = BoxContainer.ALIGNMENT_BEGIN
	lin.mouse_filter = Control.MOUSE_FILTER_PASS
	_raiz.add_child(lin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(1.4 * v))
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	var t := UI.titulo_degrade("Pausa", 9.0 * v)
	col.add_child(t)
	for par in [["Continuar", true, continuar], ["Opções", false, opcoes], ["Voltar ao início", false, reiniciar], ["Menu principal", false, menu_principal]]:
		var b := UI.BotaoMenu.new(par[0], "", par[1], 3.5, 32.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var sinal: Signal = par[2]
		b.apertado.connect(func(): sinal.emit())
		col.add_child(b)
	lin.add_child(col)
	var est := VBoxContainer.new()
	est.alignment = BoxContainer.ALIGNMENT_CENTER
	est.add_theme_constant_override("separation", int(1.8 * v))
	for e in estatisticas:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(1.4 * v))
		var barra := ColorRect.new()
		barra.color = Color("#ff8a35")
		barra.custom_minimum_size.x = 0.6 * v
		h.add_child(barra)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.add_child(UI.rotulo(str(e[1]), 5.4 * v, Color.WHITE, 900, 0.0, true))
		vb.add_child(UI.rotulo(e[0], 2.5 * v, Color(1, 1, 1, 0.95), 700))
		h.add_child(vb)
		est.add_child(h)
	lin.add_child(est)
	var xd := ColorRect.new()
	xd.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	xd.offset_top = -3.2 * v
	xd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xm := ShaderMaterial.new()
	var xs := Shader.new()
	xs.code = SHADER_XADREZ
	xm.shader = xs
	xm.set_shader_parameter("lado", 3.2 * v)
	xd.material = xm
	_raiz.add_child(xd)

func atualizar(est: Array) -> void:
	estatisticas = est
	_montar()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_ESCAPE or e.keycode == KEY_P):
		get_viewport().set_input_as_handled()
		continuar.emit()
