extends CanvasLayer
# EDITOR DA HUD (Opções › HUD › Personalizar HUD): arraste cada botão para onde quiser e ajuste o tamanho
# do botão escolhido. Concluir salva em Config (posições usadas pelos controles de toque).
# Se for aberto pelo menu principal (sem jogo), cria uns controles só para editar.
# Mexa AQUI para: o painel do editor (botões e textos).

signal concluido

const UI := preload("res://menu/ui.gd")
const ControlesCls := preload("res://jogador/controles.gd")

var controles = null
var _proprio := false
var _painel: PanelContainer
var _sel: Label
var _tam: UI.Deslizante
var _tam_v: Label

func abrir(c) -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	if c == null:
		c = ControlesCls.new()
		c.name = "ControlesEdicao"
		add_child(c)
		_proprio = true
	controles = c
	controles.set_editando(true)
	controles.aplicar_layout(Config.hud_pos, float(Config.valor("sc")) / 100.0, 1.0)
	controles.selecionou.connect(_selecionou)
	_montar()

func _montar() -> void:
	var v := UI.vh(self)
	_painel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.055, 0.93)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(1.2 * v))
	sb.content_margin_left = 1.4 * v
	sb.content_margin_right = 1.4 * v
	sb.content_margin_top = 1.0 * v
	sb.content_margin_bottom = 1.0 * v
	_painel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(0.9 * v))
	var l1 := HBoxContainer.new()
	l1.add_theme_constant_override("separation", int(0.9 * v))
	l1.add_child(UI.rotulo("Personalizar HUD", 3.0 * v, Color.WHITE, 900, 0.0, true))
	l1.add_child(_bt("Restaurar tudo", v, func():
		controles.aplicar_layout({}, controles.escala, 1.0)
		_selecionou(controles.selecionado), Color("#e10600")))
	l1.add_child(_bt("Concluir", v, _concluir, Color("#19d46a"), Color("#04210f")))
	col.add_child(l1)
	var l2 := HBoxContainer.new()
	l2.add_theme_constant_override("separation", int(0.9 * v))
	_sel = UI.rotulo("Toque num item e arraste", 2.7 * v, UI.AMBAR, 700)
	_sel.custom_minimum_size.x = 22.0 * v
	l2.add_child(_sel)
	_tam = UI.Deslizante.new(50, 200, 5, 100)
	_tam.custom_minimum_size.x = 20.0 * v
	_tam.mudou.connect(func(val):
		if controles.selecionado != "":
			controles.definir_tamanho(controles.selecionado, val / 100.0)
			_tam_v.text = str(val) + "%")
	l2.add_child(_tam)
	_tam_v = UI.rotulo("", 2.7 * v, Color.WHITE, 800)
	_tam_v.custom_minimum_size.x = 6.0 * v
	l2.add_child(_tam_v)
	l2.add_child(_bt("Item padrão", v, func():
		if controles.selecionado != "":
			controles.item_padrao(controles.selecionado)
			_selecionou(controles.selecionado)))
	col.add_child(l2)
	_painel.add_child(col)
	add_child(_painel)
	_posicionar.call_deferred()

func _posicionar() -> void:
	var vs := get_viewport().get_visible_rect().size
	_painel.reset_size()
	_painel.position = Vector2((vs.x - _painel.size.x) * 0.5, 2.0 * UI.vh(self))
	controles.editar_ignorar = Rect2(_painel.position, _painel.size).grow(8.0)

func _bt(t: String, v: float, acao: Callable, fundo := Color(1, 1, 1, 0.12), texto := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UI.fonte(800))
	b.add_theme_font_size_override("font_size", int(2.7 * v))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, texto)
	for est in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = fundo.lightened(0.15) if est == "hover" else fundo
		s.border_color = Color(1, 1, 1, 0.3)
		s.set_border_width_all(2)
		s.set_corner_radius_all(int(0.9 * v))
		s.content_margin_left = 1.6 * v
		s.content_margin_right = 1.6 * v
		s.content_margin_top = 0.6 * v
		s.content_margin_bottom = 0.6 * v
		b.add_theme_stylebox_override(est, s)
	b.pressed.connect(acao)
	return b

func _selecionou(id: String) -> void:
	if id == "":
		_sel.text = "Toque num item e arraste"
		_tam_v.text = ""
		return
	var b: Dictionary = controles._botao(id)
	_sel.text = String(b.get("txt", id))
	var f := int(round(controles.tamanho_do(id) * 100.0))
	_tam.definir(f)
	_tam_v.text = str(f) + "%"

func _concluir() -> void:
	Config.definir_hud(controles.layout)
	controles.selecionou.disconnect(_selecionou)
	controles.set_editando(false)
	if _proprio:
		controles.queue_free()
	concluido.emit()
	queue_free()
