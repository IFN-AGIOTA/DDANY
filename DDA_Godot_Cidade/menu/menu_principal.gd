extends CanvasLayer
# MENU PRINCIPAL (igual ao do HTML): "DIAS DE UM / APOCALIPSE / NOVA YORK", versão, botões
# História · Ato 1 · Jogar (mundo livre) · Multijogador (menu/tela_multijogador.gd) · Opções · Créditos (menu/creditos.gd), e o ícone do PERFIL no canto. Fica por cima da cena_menu.gd.
# Mexa AQUI para: textos e botões do menu principal. (A cena 3D de fundo é menu/cena_menu.gd.)

signal jogar
signal continuar
signal historia
signal opcoes
signal multijogador
signal perfil                            # ícone de perfil no canto (menu/tela_perfil.gd)

const UI := preload("res://menu/ui.gd")
const Salvamento := preload("res://menu/salvamento.gd")
const CreditosCls := preload("res://menu/creditos.gd")
const AvatarCls := preload("res://menu/avatar.gd")

var _raiz: Control
var _aviso: Label
var _aviso_t := 0.0
var _carregando: Label

func _ready() -> void:
	layer = 20
	get_viewport().size_changed.connect(_montar)
	Conta.mudou.connect(_montar)
	Conta.pedidos_mudaram.connect(_montar)
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
	var salvo: String = Salvamento.resumo()
	b1.apertado.connect(func():
		if salvo != "" and not _confirmou_hist:
			_confirmou_hist = true
			b1.sub = "Toque de novo: o jogo salvo será apagado"
			b1._medir()
			b1.queue_redraw()
			return
		historia.emit())
	var b2 := UI.BotaoMenu.new("Novo jogo" if salvo != "" else "Jogar", "Mundo livre", false, 3.8)
	b2.apertado.connect(func():
		# já existe jogo salvo: o 1º toque só avisa (o novo jogo grava por cima do salvo)
		if salvo != "" and not _confirmou_novo:
			_confirmou_novo = true
			b2.sub = "Toque de novo: o jogo salvo será apagado"
			b2._medir()
			b2.queue_redraw()
			return
		jogar.emit())
	var bm := UI.BotaoMenu.new("Multijogador", "Mundo livre com amigos · Wi-Fi ou internet", false, 3.8)
	bm.apertado.connect(func(): multijogador.emit())
	var b3 := UI.BotaoMenu.new("Opções", "", false, 3.8)
	b3.apertado.connect(func(): opcoes.emit())
	var b4 := UI.BotaoMenu.new("Créditos", "", false, 3.0, 26.0)
	b4.apertado.connect(_abrir_creditos)
	var botoes: Array = [b1, b2, bm, b3, b4]
	if salvo != "":
		var b0 := UI.BotaoMenu.new("Continuar", salvo, true, 3.8)
		b0.apertado.connect(func(): continuar.emit())
		botoes.push_front(b0)
		b1.primario = false
	for b in botoes:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		nav.add_child(b)
	col.add_child(nav)
	# PERFIL: ícone + nome no canto de cima à direita; bolinha com os pedidos de amizade
	if Conta.configurado:
		var bp := _BotaoPerfil.new()
		bp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		bp.offset_left = -38.0 * v
		bp.offset_right = -2.5 * v
		bp.offset_top = 2.0 * v
		bp.offset_bottom = 8.5 * v
		bp.apertado.connect(func(): perfil.emit())
		_raiz.add_child(bp)
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

func _abrir_creditos() -> void:
	if get_node_or_null("Creditos") != null:
		return
	var c := CreditosCls.new()
	c.name = "Creditos"
	add_child(c)

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

var _confirmou_novo := false
var _confirmou_hist := false

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

func _exit_tree() -> void:
	if Conta.mudou.is_connected(_montar):
		Conta.mudou.disconnect(_montar)
		Conta.pedidos_mudaram.disconnect(_montar)

# botão do PERFIL: ícone, nome (ou "Entrar") e bolinha de pedidos de amizade
class _BotaoPerfil extends Control:
	signal apertado
	const UIp := preload("res://menu/ui.gd")
	const Av := preload("res://menu/avatar.gd")
	var _av: Control
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _ready() -> void:
		_av = Av.new(Conta.avatar if Conta.logado else 1, 10.0)
		_av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_av)
		resized.connect(_ajustar)
		_ajustar()
	func _ajustar() -> void:
		var s := size.y
		_av.position = Vector2(size.x - s, 0)
		_av.size = Vector2(s, s)
		queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			apertado.emit()
	func _draw() -> void:
		var v: float = UIp.vh(self)
		var s := size.y
		var txt: String = Conta.nome if Conta.logado else "Entrar"
		var sub: String = ("código " + Conta.codigo_amigo) if Conta.logado else "conta e amigos"
		var ft: Font = UIp.fonte(900)
		var t1 := int(2.8 * v)
		var w1 := ft.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, t1).x
		var f2: Font = UIp.fonte(400, 0.0, false)
		var t2 := int(1.9 * v)
		var w2 := f2.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, t2).x
		var x := size.x - s - 1.2 * v
		draw_string(ft, Vector2(x - w1, s * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, t1, Color.WHITE)
		draw_string(f2, Vector2(x - w2, s * 0.5 + t2 * 1.3), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, t2, Color(1, 0.91, 0.82, 0.75))
		var n: int = Conta.pedidos.size()
		if n > 0:
			var c := Vector2(size.x - s * 0.12, s * 0.12)
			draw_circle(c, s * 0.2, Color("#e0312b"))
			var tn := int(s * 0.26)
			var wn := ft.get_string_size(str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, tn).x
			draw_string(ft, c + Vector2(-wn * 0.5, tn * 0.36), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, tn, Color.WHITE)
