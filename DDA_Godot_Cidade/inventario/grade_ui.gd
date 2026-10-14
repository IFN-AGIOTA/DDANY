extends Control
# UMA GRADE NA TELA (bolso, mochila, caixa ou chão), com arrastar e soltar.
#  - arrastar um item: move (mostra em verde onde cabe, vermelho onde não cabe)
#  - soltar em cima de uma pilha igual: junta
#  - durante o arraste: R / Espaço / botão direito / um 2º dedo na tela = girar
#  - tocar: seleciona (informações embaixo, no meio) · duplo toque: ação rápida (pegar, vestir, usar)
# Tocar numa célula vazia e arrastar rola a coluna (celular).

const Visual := preload("res://inventario/visual.gd")

var grade = null              # grade.gd
var tela = null               # tela_inventario.gd
var cel := 44.0

var _hover := false
var _hover_pos := Vector2i.ZERO
var _hover_rot := false
var _hover_ok := false
var _hover_item = null

class Previa extends Control:
	var item = null
	var dados := {}
	var cel := 44.0
	var fonte: Font
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var girado: bool = dados.get("rot", false)
		var t: Vector2i = item.tam(girado)
		var off: Vector2i = dados.get("off", Vector2i.ZERO)
		var r := Rect2(-Vector2(off) * cel - Vector2(cel, cel) * 0.5, Vector2(t) * cel)
		Visual.desenhar_item(self, item, r, fonte, girado, 0.8)

func configurar(g, t, tamanho_celula: float) -> void:
	grade = g
	tela = t
	cel = tamanho_celula
	mouse_filter = Control.MOUSE_FILTER_STOP
	atualizar_tamanho()

func atualizar_tamanho() -> void:
	custom_minimum_size = Vector2(grade.largura * cel, grade.altura * cel)
	queue_redraw()

func _celula(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cel)), int(floor(p.y / cel)))

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		var it = grade.item_em(_celula(e.position).x, _celula(e.position).y)
		if it == null:
			return                # célula vazia: deixa a coluna rolar
		accept_event()            # segura o toque (a coluna não rola enquanto arrasta um item)
		if e.double_click:
			tela.acao_rapida(it)
		else:
			tela.selecionar(it)

func _get_drag_data(p: Vector2) -> Variant:
	var c := _celula(p)
	var it = grade.item_em(c.x, c.y)
	if it == null:
		return null
	tela.selecionar(it)
	var dados := {"item": it, "off": c - Vector2i(it.x, it.y), "rot": it.rot}
	var pv := Previa.new()
	pv.item = it
	pv.dados = dados
	pv.cel = cel
	pv.fonte = tela.fonte
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(pv)
	tela.comecou_arraste(dados)
	return dados

func _can_drop_data(p: Vector2, d: Variant) -> bool:
	if typeof(d) != TYPE_DICTIONARY or not d.has("item") or d.has("atalho"):
		return false
	var it = d["item"]
	var girado: bool = d.get("rot", it.rot)
	var off: Vector2i = d.get("off", Vector2i.ZERO)
	var t: Vector2i = it.tam(girado)
	off = Vector2i(mini(off.x, t.x - 1), mini(off.y, t.y - 1))
	var c := _celula(p)
	tela.marcar_hover(self)
	_hover = true
	_hover_rot = girado
	_hover_pos = c - off
	_hover_item = it
	var pilha = tela.inv.alvo_pilha(it, grade, c.x, c.y)
	if pilha != null:
		_hover_pos = Vector2i(pilha.x, pilha.y)
		_hover_rot = pilha.rot
		_hover_item = pilha
		_hover_ok = true
	elif grade.chao:
		_hover_ok = it.no_mundo == null
	else:
		_hover_ok = tela.inv.pode_ir_para_grade(it, grade, _hover_pos.x, _hover_pos.y, girado)
	queue_redraw()
	return _hover_ok

func _drop_data(p: Vector2, d: Variant) -> void:
	var it = d["item"]
	var c := _celula(p)
	limpar_hover()
	var pilha = tela.inv.alvo_pilha(it, grade, c.x, c.y)
	if pilha != null:
		tela.inv.juntar(it, pilha)
		return
	var girado: bool = d.get("rot", it.rot)
	var off: Vector2i = d.get("off", Vector2i.ZERO)
	var t: Vector2i = it.tam(girado)
	off = Vector2i(mini(off.x, t.x - 1), mini(off.y, t.y - 1))
	var pos := c - off
	tela.inv.mover_para_grade(it, grade, pos.x, pos.y, girado)

func limpar_hover() -> void:
	if _hover:
		_hover = false
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		limpar_hover()

func _draw() -> void:
	var f: Font = tela.fonte
	draw_rect(Rect2(Vector2.ZERO, size), Visual.FUNDO_CELULA)
	for gx in range(1, grade.largura):
		draw_line(Vector2(gx * cel, 0), Vector2(gx * cel, grade.altura * cel), Visual.LINHA_CELULA, 1.0)
	for gy in range(1, grade.altura):
		draw_line(Vector2(0, gy * cel), Vector2(grade.largura * cel, gy * cel), Visual.LINHA_CELULA, 1.0)
	var arrastado = tela.item_arrastado()
	for it in grade.itens:
		var r := Rect2(Vector2(it.x, it.y) * cel, Vector2(it.largura(), it.altura()) * cel)
		Visual.desenhar_item(self, it, r, f, it.rot, 0.35 if it == arrastado else 1.0)
		if it == tela.selecionado:
			draw_rect(r.grow(-1.0), Color(1.0, 0.71, 0.0), false, 2.0)
	if _hover and _hover_item != null:
		var t: Vector2i = _hover_item.tam(_hover_rot)
		var r2 := Rect2(Vector2(_hover_pos) * cel, Vector2(t) * cel)
		var cor := Color(0.2, 0.85, 0.3, 0.35) if _hover_ok else Color(0.9, 0.15, 0.1, 0.35)
		draw_rect(r2, cor)
		draw_rect(r2, Color(cor.r, cor.g, cor.b, 0.9), false, 2.0)
