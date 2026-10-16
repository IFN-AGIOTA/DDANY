extends CanvasLayer
# CRÉDITOS (botão "Créditos" do menu principal): quem fez a história, o jogo e TUDO o que foi baixado de fora
# (modelos, fontes, sons...) com autor, licença e endereço. Rola com o dedo/mouse. "Licença da Godot" mostra o
# texto completo da licença MIT do motor (a licença pede que ele vá junto com o jogo).
# REGRA DO PROJETO: qualquer coisa baixada da internet que pedir (ou merecer) crédito entra na lista
# RECURSOS abaixo. Mexa AQUI para: textos dos créditos.

signal fechar

const UI := preload("res://menu/ui.gd")

# [título da seção, [[linha principal, detalhe], ...]]
const EQUIPE := [
	["HISTÓRIA E UNIVERSO", [
		["Willian Ulguim e Gabriel Solla", "Dias de um Apocalipse · Livro 1 e Bíblia da Lore"]]],
	["JOGO", [
		["Dias de um Apocalipse · Nova York", "Porte para a Godot do jogo original em HTML"],
		["Cidade, prédios, interiores, carros, clima e música", "Feitos por código para o jogo (sem arquivos de terceiros)"]]],
]
# [o quê, autor, licença, endereço]
const RECURSOS := [
	["Modelos 3D (manequins) e animações dos infectados", "Quaternius · \"Universal Animation Library\" 1 e 2",
		"CC0 1.0 (domínio público)", "quaternius.com · opengameart.org/content/universal-animation-library-2"],
	["Fonte Roboto Condensed", "Christian Robertson · Google Fonts (Copyright 2011 Google Inc.)",
		"SIL Open Font License 1.1", "fonts.google.com/specimen/Roboto+Condensed"],
	["Motor do jogo: Godot Engine 4.3", "Juan Linietsky, Ariel Manzur e colaboradores da Godot",
		"Licença MIT (texto completo no botão abaixo)", "godotengine.org"],
]

var _raiz: Control
var _licenca: Label

func _ready() -> void:
	layer = 30
	get_viewport().size_changed.connect(_montar)
	_montar()

func _montar() -> void:
	if _raiz != null:
		_raiz.queue_free()
	var v := UI.vh(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.06, 0.025, 0.01, 0.94)
	_raiz.add_child(fundo)
	var tit := UI.titulo_degrade("CRÉDITOS", 9.0 * v, 0.1 * 9.0 * v)
	tit.position = Vector2(6.0 * v, 3.0 * v)
	_raiz.add_child(tit)
	var voltar := UI.BotaoMenu.new("Voltar", "", true, 3.4, 20.0)
	voltar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	voltar.offset_left = -26.0 * v
	voltar.offset_right = -4.0 * v
	voltar.offset_top = 4.0 * v
	voltar.apertado.connect(_sair)
	_raiz.add_child(voltar)
	var rolar := ScrollContainer.new()
	rolar.set_anchors_preset(Control.PRESET_FULL_RECT)
	rolar.offset_left = 6.0 * v
	rolar.offset_right = -4.0 * v
	rolar.offset_top = 16.0 * v
	rolar.offset_bottom = -3.0 * v
	rolar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_raiz.add_child(rolar)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(1.0 * v))
	rolar.add_child(col)
	for secao in EQUIPE:
		_secao(col, secao[0], v)
		for item in secao[1]:
			_linha(col, item[0], item[1], v)
	_secao(col, "RECURSOS DE TERCEIROS", v)
	for r in RECURSOS:
		_linha(col, r[0], "%s\n%s · %s" % [r[1], r[2], r[3]], v)
	var esp := Control.new()
	esp.custom_minimum_size.y = 2.0 * v
	col.add_child(esp)
	var bl := UI.BotaoMenu.new("Licença da Godot", "texto completo (MIT)", false, 3.0, 30.0)
	bl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(bl)
	_licenca = UI.rotulo(Engine.get_license_text(), 2.0 * v, Color(1, 1, 1, 0.7), 400)
	_licenca.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_licenca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_licenca.visible = false
	col.add_child(_licenca)
	bl.apertado.connect(func(): _licenca.visible = not _licenca.visible)

func _secao(col: VBoxContainer, txt: String, v: float) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(2.4 * v))
	m.add_child(UI.rotulo(txt, 3.2 * v, UI.TITULO_SECAO, 900, 0.15 * 3.2 * v, true))
	col.add_child(m)

func _linha(col: VBoxContainer, titulo: String, detalhe: String, v: float) -> void:
	var t := UI.rotulo(titulo, 3.0 * v, UI.TEXTO, 800)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(t)
	var d := UI.rotulo(detalhe, 2.3 * v, Color(1, 0.91, 0.82, 0.68), 400)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(d)

func _sair() -> void:
	fechar.emit()
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_sair()
