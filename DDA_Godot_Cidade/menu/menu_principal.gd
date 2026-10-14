extends CanvasLayer
# MENU PRINCIPAL (igual ao do HTML): "DIAS DE UM / APOCALIPSE / NOVA YORK", versão, botões
# História · Ato 1 · Jogar (mundo livre) · Opções, e o ícone de tela cheia no canto. Fica por cima da cena_menu.gd.
# Mexa AQUI para: textos e botões do menu principal. (A cena 3D de fundo é menu/cena_menu.gd.)

signal jogar
signal historia
signal opcoes

const UI := preload("res://menu/ui.gd")

var _raiz: Control
var _aviso: Label
var _aviso_t := 0.0
var _carregando: Label

func _ready() -> void:
	layer = 20
	get_viewport().size_changed.connect(_montar)
	_montar()

const SHADER_VEU := """
shader_type canvas_item;
// escurece a esquerda (onde ficam o título e os botões) e a parte de baixo, com borda escura em volta
void fragment() {
	vec2 uv = UV;
	float a = 0.0;
	if (uv.x < 0.24) a = mix(0.9, 0.72, uv.x / 0.24);
	else if (uv.x < 0.44) a = mix(0.72, 0.3, (uv.x - 0.24) / 0.2);
	else if (uv.x < 0.62) a = mix(0.3, 0.0, (uv.x - 0.44) / 0.18);
	float b = mix(0.6, 0.0, clamp((1.0 - uv.y) / 0.28, 0.0, 1.0));
	a = 1.0 - (1.0 - a) * (1.0 - b);
	vec2 e = min(uv, 1.0 - uv);
	float borda = 1.0 - smoothstep(0.0, 0.16, min(e.x * 0.56, e.y));
	vec3 cor = vec3(0.078, 0.027, 0.008);
	float total = 1.0 - (1.0 - a) * (1.0 - borda * 0.55);
	COLOR = vec4(cor, total);
}
"""

func _montar() -> void:
	if _raiz != null:
		_raiz.queue_free()
	var v := UI.vh(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", int(2.6 * v))
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 5.0 * v
	col.offset_right = 80.0 * v
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_raiz.add_child(col)
	# título
	var tit := VBoxContainer.new()
	tit.add_theme_constant_override("separation", 0)
	tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d1 := UI.rotulo("DIAS DE UM", 3.8 * v, Color("#ffb866"), 900, 0.42 * 3.8 * v, true)
	d1.add_theme_color_override("font_shadow_color", Color(1.0, 0.47, 0.12, 0.6))
	d1.add_theme_constant_override("shadow_outline_size", int(1.2 * v))
	d1.add_theme_constant_override("shadow_offset_x", 0)
	d1.add_theme_constant_override("shadow_offset_y", 0)
	var m1 := MarginContainer.new()
	m1.add_theme_constant_override("margin_left", int(0.6 * v))
	m1.add_child(d1)
	tit.add_child(m1)
	tit.add_child(_titulo_grande("APOCALIPSE", 17.0 * v, v))
	var d3 := UI.rotulo("NOVA YORK", 6.4 * v, Color("#ff8a35"), 900, 0.24 * 6.4 * v, true)
	d3.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	d3.add_theme_constant_override("shadow_offset_y", int(0.3 * v))
	var m3 := MarginContainer.new()
	m3.add_theme_constant_override("margin_left", int(6.6 * v))
	m3.add_theme_constant_override("margin_top", int(0.4 * v))
	m3.add_child(d3)
	tit.add_child(m3)
	var dv := UI.rotulo("VERSÃO " + Config.VERSAO, 2.5 * v, Color(1.0, 0.722, 0.4, 0.8), 800, 0.22 * 2.5 * v, true)
	var mv := MarginContainer.new()
	mv.add_theme_constant_override("margin_top", int(1.2 * v))
	mv.add_child(dv)
	tit.add_child(mv)
	col.add_child(tit)
	# botões
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", int(1.4 * v))
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b1 := UI.BotaoMenu.new("História · Ato 1", "Parte 1 · A Última Corrida", true, 3.8)
	b1.apertado.connect(func(): historia.emit())
	var b2 := UI.BotaoMenu.new("Jogar", "Mundo livre", false, 3.8)
	b2.apertado.connect(func(): jogar.emit())
	var b3 := UI.BotaoMenu.new("Opções", "", false, 3.8)
	b3.apertado.connect(func(): opcoes.emit())
	for b in [b1, b2, b3]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		nav.add_child(b)
	col.add_child(nav)
	# tela cheia (canto de cima)
	var tc := _BotaoTelaCheia.new()
	tc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tc.offset_left = -8.5 * v
	tc.offset_right = -2.0 * v
	tc.offset_top = 2.0 * v
	tc.offset_bottom = 8.5 * v
	_raiz.add_child(tc)
	_aviso = UI.rotulo("", 3.0 * v, UI.AMBAR, 700, 0.0, true)
	_aviso.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_aviso.offset_top = -9.0 * v
	_aviso.offset_bottom = -3.0 * v
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.visible = false
	_raiz.add_child(_aviso)
	_carregando = UI.rotulo("CARREGANDO A CIDADE…", 4.0 * v, Color.WHITE, 900, 0.1 * 4.0 * v, true)
	_carregando.set_anchors_preset(Control.PRESET_FULL_RECT)
	_carregando.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carregando.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_carregando.visible = false
	_raiz.add_child(_carregando)

# APOCALIPSE: degradê + sombra (a sombra é um filho desenhado atrás, sem o degradê)
func _titulo_grande(txt: String, tam: float, v: float) -> Control:
	var frente := UI.titulo_degrade(txt, tam, -0.01 * tam)
	var sombra := UI.rotulo(txt, tam, Color(0, 0, 0, 0.55), 900, -0.01 * tam, true)
	sombra.show_behind_parent = true
	sombra.position = Vector2(0, 0.5 * v)
	frente.add_child(sombra)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(-0.12 * tam))
	m.add_theme_constant_override("margin_bottom", int(-0.1 * tam))
	m.add_child(frente)
	return m

func avisar(t: String) -> void:
	_aviso.text = t
	_aviso.visible = true
	_aviso_t = 3.0

func mostrar_carregando() -> void:
	for f in _raiz.get_children():
		if f is VBoxContainer:
			f.visible = false
	_carregando.visible = true

func _process(dt: float) -> void:
	if _aviso_t > 0.0:
		_aviso_t -= dt
		_aviso.modulate.a = clampf(_aviso_t, 0.0, 1.0)
		if _aviso_t <= 0.0:
			_aviso.visible = false

# ícone ⛶ de tela cheia (canto de cima à direita)
class _BotaoTelaCheia extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			var w := DisplayServer.window_get_mode()
			var cheia := w == DisplayServer.WINDOW_MODE_FULLSCREEN or w == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if cheia else DisplayServer.WINDOW_MODE_FULLSCREEN)
	func _draw() -> void:
		var s := size
		var r := Rect2(Vector2.ZERO, s)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.157, 0.055, 0.016, 0.5)
		sb.border_color = Color(1.0, 0.667, 0.353, 0.55)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(s.x * 0.12))
		draw_style_box(sb, r)
		var m := s.x * 0.3
		var l := s.x * 0.14
		var c := Color("#ffe9d0")
		var w := maxf(2.0, s.x * 0.06)
		for q in [[Vector2(m, m), Vector2(1, 0), Vector2(0, 1)], [Vector2(s.x - m, m), Vector2(-1, 0), Vector2(0, 1)],
				[Vector2(m, s.y - m), Vector2(1, 0), Vector2(0, -1)], [Vector2(s.x - m, s.y - m), Vector2(-1, 0), Vector2(0, -1)]]:
			draw_line(q[0], q[0] + q[1] * l, c, w)
			draw_line(q[0], q[0] + q[2] * l, c, w)
