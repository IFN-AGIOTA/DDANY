extends CanvasLayer
# NOVIDADES (0.96): aberta pelo botão "Novidades" no canto de baixo à direita do menu principal. Mostra TODAS as
# atualizações, de CIMA PARA BAIXO, da MAIS NOVA para a MAIS ANTIGA (a versão instalada vem marcada "ATUAL").
# Cada uma é um cartão com a versão, o título e o que mudou. Para ficar leve no celular, abre com as POR_VEZ mais
# novas e o botão "Mostrar mais antigas" vai acrescentando.
# A lista vem de menu/novidades_lista.gd, GERADA do LEIA-ME.txt por ferramentas/gerar_novidades.gd (rodar a cada
# atualização). Mexa AQUI para: aparência dos cartões e quantas aparecem de cada vez.

signal fechar

const UI := preload("res://menu/ui.gd")
const Lista := preload("res://menu/novidades_lista.gd")
const POR_VEZ := 12

var _raiz: Control
var _col: VBoxContainer
var _mais: Control
var _mostradas := 0
var _v := 1.0

func _ready() -> void:
	layer = 30
	get_viewport().size_changed.connect(_montar)
	_montar()

func _montar() -> void:
	if _raiz != null:
		_raiz.queue_free()
	var quantas := maxi(_mostradas, POR_VEZ)
	_mostradas = 0
	_v = UI.vh(self)
	var v := _v
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.06, 0.025, 0.01, 0.985)
	_raiz.add_child(fundo)
	var tit := UI.titulo_degrade("NOVIDADES", 9.0 * v, 0.1 * 9.0 * v)
	tit.position = Vector2(6.0 * v, 3.0 * v)
	_raiz.add_child(tit)
	var sub := UI.rotulo("%d atualizações · da mais nova para a mais antiga · você está na versão %s" % [Lista.LISTA.size(), Config.VERSAO],
		2.3 * v, Color(1, 0.91, 0.82, 0.7), 400)
	sub.position = Vector2(6.4 * v, 12.4 * v)
	_raiz.add_child(sub)
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
	rolar.offset_top = 17.0 * v
	rolar.offset_bottom = -3.0 * v
	rolar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_raiz.add_child(rolar)
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", int(1.8 * v))
	rolar.add_child(_col)
	_mais = null
	_acrescentar(quantas)

# põe mais "n" cartões no fim da lista (as mais antigas que ainda não apareceram)
func _acrescentar(n: int) -> void:
	if _mais != null and is_instance_valid(_mais):
		_mais.queue_free()
		_mais = null
	var fim := mini(_mostradas + n, Lista.LISTA.size())
	for i in range(_mostradas, fim):
		_col.add_child(_cartao(Lista.LISTA[i]))
	_mostradas = fim
	if _mostradas < Lista.LISTA.size():
		var b := UI.BotaoMenu.new("Mostrar mais antigas", "faltam %d" % (Lista.LISTA.size() - _mostradas), false, 3.0, 30.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.apertado.connect(func(): _acrescentar(POR_VEZ))
		_col.add_child(b)
		_mais = b

func _cartao(a: Array) -> Control:
	var v := _v
	var atual: bool = str(a[0]) == Config.VERSAO
	var painel := PanelContainer.new()
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.06, 0.02, 0.85) if atual else Color(0.11, 0.045, 0.015, 0.75)
	sb.border_color = UI.AMBAR if atual else UI.BORDA
	sb.set_border_width_all(maxi(1, int((0.35 if atual else 0.18) * v)))
	sb.set_corner_radius_all(int(1.2 * v))
	sb.content_margin_left = 2.4 * v
	sb.content_margin_right = 2.4 * v
	sb.content_margin_top = 1.6 * v
	sb.content_margin_bottom = 1.8 * v
	painel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(0.7 * v))
	painel.add_child(col)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", int(1.6 * v))
	topo.add_child(UI.rotulo("VERSÃO " + str(a[0]), 3.4 * v, UI.AMBAR, 900, 0.1 * 3.4 * v, true))
	if atual:
		topo.add_child(UI.rotulo("ATUAL", 2.2 * v, Color("#5dff8a"), 900, 0.15 * 2.2 * v))
	col.add_child(topo)
	var t := UI.rotulo(str(a[1]), 2.9 * v, UI.TEXTO, 800)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(t)
	var d := UI.rotulo("\n".join(a[2]), 2.2 * v, Color(1, 0.91, 0.82, 0.78), 400)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(d)
	return painel

func _sair() -> void:
	fechar.emit()
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_sair()
