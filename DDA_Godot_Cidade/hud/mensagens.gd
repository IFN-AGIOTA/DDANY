extends CanvasLayer
# MENSAGENS RÁPIDAS (0.71 · multijogador): botão MSG (toque) ou tecla T (PC) abre uma lista de frases prontas;
# tocar/clicar ou apertar 1..8 manda para todos da partida. Quem recebe vê "NOME: frase" na tela (com um som).
# Criado por rede/sessao_rede.gd (só existe em partida em rede).
# Mexa AQUI para: as frases.

const UI := preload("res://menu/ui.gd")
const Sons := preload("res://audio/sons.gd")

const FRASES := ["SOCORRO!", "VEM AQUI", "CUIDADO: INFECTADOS", "CUIDADO: JOGADOR", "AMIGO, NÃO ATIRE",
	"ACHEI LOOT", "PRECISO DE REMÉDIO", "VAMOS EMBORA"]

signal escolheu(indice: int)

var controles = null
var _raiz: Control
var aberto := false

func _ready() -> void:
	layer = 12
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.visible = false
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.45)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			fechar())
	_raiz.add_child(fundo)
	var v := UI.vh(self)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(1.2 * v))
	_raiz.add_child(col)
	var t := UI.rotulo("MENSAGEM PARA TODOS", 3.4 * v, UI.AMBAR, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", int(1.5 * v))
	g.add_theme_constant_override("v_separation", int(1.2 * v))
	col.add_child(g)
	for i in FRASES.size():
		var b := UI.BotaoMenu.new("%d  %s" % [i + 1, FRASES[i]], "", false, 3.0, 38.0)
		b.apertado.connect(func(): _mandar(i))
		g.add_child(b)

func abrir() -> void:
	if aberto:
		fechar()
		return
	aberto = true
	_raiz.visible = true
	if controles != null:
		controles.mouse_solto = true

func fechar() -> void:
	aberto = false
	_raiz.visible = false
	if controles != null:
		controles.mouse_solto = false

func _mandar(i: int) -> void:
	fechar()
	escolheu.emit(i)

func _input(e: InputEvent) -> void:
	if not aberto or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_8:
		_mandar(k - KEY_1)
		get_viewport().set_input_as_handled()
	elif k == KEY_ESCAPE or k == KEY_T:
		fechar()
		get_viewport().set_input_as_handled()

# alguém mandou (inclusive eu): mostra na tela
static func texto(nome: String, indice: int) -> String:
	return "%s: %s" % [nome.to_upper(), FRASES[clampi(indice, 0, FRASES.size() - 1)]]
