extends CanvasLayer
# TELA DE UM NPC DO HOSPITAL (0.91) · a base da loja da Mônica (npc/tela_loja.gd) e das trocas do Lucas
# (npc/tela_trocas.gd): fundo escuro, painel com o nome, o seu dinheiro, abas, uma lista que rola (dedo ou rodinha)
# e um rodapé com o aviso e o botão FECHAR. Enquanto está aberta, os controles do jogo ficam travados.
# Cada linha da lista (Linha) mostra o ícone do item (inventario/visual.gd), o nome, um detalhe e um botão à direita;
# pode ser "marcável" (fica destacada quando escolhida). Mexa AQUI para: tamanhos e cores das telas dos NPCs.

const UI := preload("res://menu/ui.gd")
const Visual := preload("res://inventario/visual.gd")
const Precos := preload("res://npc/precos.gd")
const ItemCls := preload("res://inventario/item.gd")

signal fechou

var gerente = null                      # npc/hospitais.gd
var npc = null                          # npc/npc_hospital.gd
var abas: UI.Abas
var lista: VBoxContainer
var _rolar: ScrollContainer
var _titulo: Label
var _dinheiro: Label
var _aviso: Label
var _v := 8.0

func abrir(titulo: String, sub: String, nomes_abas: Array) -> void:
	layer = 21
	_v = UI.vh(gerente.main)
	var v := _v
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)
	var veu := ColorRect.new()
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.color = Color(0.02, 0.03, 0.04, 0.82)
	raiz.add_child(veu)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 5.0 * v
	col.offset_right = -5.0 * v
	col.offset_top = 3.0 * v
	col.offset_bottom = -3.0 * v
	col.add_theme_constant_override("separation", int(1.0 * v))
	raiz.add_child(col)
	var topo := HBoxContainer.new()
	col.add_child(topo)
	var tt := VBoxContainer.new()
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(tt)
	_titulo = UI.rotulo(titulo, 5.0 * v, UI.AMBAR, 900, 0.0, true)
	tt.add_child(_titulo)
	tt.add_child(UI.rotulo(sub, 2.3 * v, Color(1, 1, 1, 0.7), 400))
	_dinheiro = UI.rotulo("", 3.6 * v, Color(0.5, 1.0, 0.55), 900)
	_dinheiro.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	topo.add_child(_dinheiro)
	abas = UI.Abas.new(nomes_abas)
	col.add_child(abas)
	abas.escolheu.connect(func(_i): refazer())
	_rolar = ScrollContainer.new()
	_rolar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rolar.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_rolar)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", int(0.7 * v))
	_rolar.add_child(lista)
	var rod := HBoxContainer.new()
	rod.add_theme_constant_override("separation", int(1.5 * v))
	col.add_child(rod)
	_aviso = UI.rotulo("", 2.6 * v, UI.TEXTO, 700)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rod.add_child(_aviso)
	var bf := UI.BotaoMenu.new("FECHAR", "", true, 3.2, 22.0)
	bf.apertado.connect(fechar)
	rod.add_child(bf)
	if gerente.main.controles != null:
		gerente.main.controles.set_bloqueado(true)
	refazer()

func fechar() -> void:
	if gerente != null and gerente.main != null and gerente.main.controles != null and is_instance_valid(gerente.main.controles):
		gerente.main.controles.set_bloqueado(false)
	fechou.emit()
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ESCAPE, KEY_TAB]:
		get_viewport().set_input_as_handled()
		fechar()

# a tela de cada NPC monta as linhas aqui
func refazer() -> void:
	for c in lista.get_children():
		c.queue_free()
	_dinheiro.text = "VOCÊ TEM " + Precos.texto(gerente.dinheiro())
	abas.queue_redraw()
	_montar(abas.atual)

func _montar(_aba: int) -> void:
	pass

func avisar(t: String, ruim := false) -> void:
	_aviso.text = t
	_aviso.modulate = Color(1.0, 0.55, 0.45) if ruim else Color(0.75, 1.0, 0.75)

# ---------- peças da lista ----------
func titulo_secao(t: String) -> void:
	var l := UI.rotulo(t, 2.7 * _v, UI.TITULO_SECAO, 800)
	lista.add_child(l)

func texto(t: String, cor := Color(1, 1, 1, 0.75)) -> void:
	var l := UI.rotulo(t, 2.4 * _v, cor, 400)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lista.add_child(l)

func linha(it, nome: String, detalhe: String, botao: String, ao_apertar: Callable, marcada := false, cor_botao := UI.LARANJA) -> Linha:
	var l := Linha.new()
	l.item = it
	l.nome = nome
	l.detalhe = detalhe
	l.botao = botao
	l.marcada = marcada
	l.cor_botao = cor_botao
	l.apertou.connect(ao_apertar)
	lista.add_child(l)
	return l

# uma fileira de botões: [[texto, Callable, primário?], ...]
func botoes(pares: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(1.0 * _v))
	for p in pares:
		var b := UI.BotaoMenu.new(str(p[0]), "", p.size() > 2 and bool(p[2]), 3.0, 12.0)
		b.apertado.connect(p[1])
		h.add_child(b)
	lista.add_child(h)
	return h

# uma linha da lista: [ícone] NOME / detalhe ........ [BOTÃO]
class Linha extends Control:
	signal apertou
	const UI := preload("res://menu/ui.gd")
	const Visual := preload("res://inventario/visual.gd")
	var item = null
	var nome := ""
	var detalhe := ""
	var botao := ""
	var marcada := false
	var cor_botao := Color("#ff7a1a")
	var _ini := Vector2.ZERO
	var _apertando := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size.y = 8.5 * UI.vh(self)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_ini = e.position
				_apertando = true
			elif _apertando:
				_apertando = false
				if e.position.distance_to(_ini) < 1.5 * UI.vh(self) and Rect2(Vector2.ZERO, size).has_point(e.position):
					UI.Sons.ui("clique")
					apertou.emit()
	func _draw() -> void:
		var v := UI.vh(self)
		var s := size
		UI.caixa_arredondada(self, Rect2(Vector2.ZERO, s), Color(1.0, 0.55, 0.15, 0.22) if marcada else Color(1, 1, 1, 0.06), 0.8 * v)
		if marcada:
			draw_rect(Rect2(0, 0, 0.7 * v, s.y), UI.LARANJA)
		var x := 1.4 * v
		var f := UI.fonte(700)
		if item != null:
			var t := s.y - 1.2 * v
			var it_tam: Vector2i = item.tam(false)
			var w := t * clampf(float(it_tam.x) / float(maxi(1, it_tam.y)), 1.0, 2.2)
			Visual.desenhar_item(self, item, Rect2(x, 0.6 * v, w, t), f, false)
			x += w + 1.4 * v
		var tb := int(2.6 * v)
		var bw := 0.0
		if botao != "":
			bw = UI.fonte(800).get_string_size(botao, HORIZONTAL_ALIGNMENT_LEFT, -1, tb).x + 3.0 * v
			var rb := Rect2(s.x - bw - 1.0 * v, s.y * 0.5 - 2.4 * v, bw, 4.8 * v)
			UI.caixa_arredondada(self, rb, Color(cor_botao.r, cor_botao.g, cor_botao.b, 0.85), 0.8 * v)
			draw_string(UI.fonte(800), Vector2(rb.position.x + 1.5 * v, rb.get_center().y + tb * 0.36), botao, HORIZONTAL_ALIGNMENT_LEFT, -1, tb, Color.WHITE)
		var larg := s.x - x - bw - 2.5 * v
		draw_string(UI.fonte(800), Vector2(x, s.y * 0.42), nome, HORIZONTAL_ALIGNMENT_LEFT, larg, int(2.8 * v), UI.TEXTO)
		draw_string(UI.fonte(400, 0.0, false), Vector2(x, s.y * 0.42 + 3.0 * v), detalhe, HORIZONTAL_ALIGNMENT_LEFT, larg, int(2.2 * v), Color(1, 1, 1, 0.65))
