extends Control
# UM ENCAIXE NA TELA (coluna do meio): roupa/mochila/arma no corpo, MÃOS ou atalho (1..8).
#  - corpo/mãos: soltar um item aqui = vestir/segurar (o antigo é trocado) · duplo toque = tirar
#  - atalho: soltar um item que você carrega = liga o atalho (o item não sai do lugar) · duplo toque = usar
#    arrastar o atalho para fora = desliga

const Visual := preload("res://inventario/visual.gd")
const Itens := preload("res://inventario/itens.gd")

var slot := ""                # "maos", "mochila", ... (vazio quando é atalho)
var atalho := -1              # 0..7 quando é atalho
var tela = null
var _hover := 0               # 0 nada · 1 aceita · -1 recusa

func configurar(t, nome_slot: String, indice_atalho := -1) -> void:
	tela = t
	slot = nome_slot
	atalho = indice_atalho
	mouse_filter = Control.MOUSE_FILTER_STOP

func item():
	if atalho >= 0:
		return tela.inv.atalhos[atalho]
	return tela.inv.slots.get(slot)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		var it = item()
		if it == null:
			return
		accept_event()
		if e.double_click:
			if atalho >= 0:
				tela.inv.usar_atalho(atalho)
			else:
				tela.acao_rapida(it)
		else:
			tela.selecionar(it)

func _get_drag_data(_p: Vector2) -> Variant:
	var it = item()
	if it == null:
		return null
	tela.selecionar(it)
	var dados := {"item": it, "off": Vector2i.ZERO, "rot": false}
	if atalho >= 0:
		dados["atalho"] = atalho
	var pv := preload("res://inventario/grade_ui.gd").Previa.new()
	pv.item = it
	pv.dados = dados
	pv.cel = tela.cel
	pv.fonte = tela.fonte
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(pv)
	tela.comecou_arraste(dados)
	return dados

func _can_drop_data(_p: Vector2, d: Variant) -> bool:
	var ok := false
	if typeof(d) == TYPE_DICTIONARY and d.has("item"):
		var it = d["item"]
		if atalho >= 0:
			ok = tela.inv.do_jogador(it)
		elif not d.has("atalho"):
			ok = tela.inv.pode_equipar(it, slot) and tela.inv.slots.get(slot) != it
			if tela.inv.pode_combinar(it, tela.inv.slots.get(slot)):
				ok = true             # pente/munição/acessório em cima da arma vestida ou na mão
	_hover = 1 if ok else -1
	queue_redraw()
	return ok

func _drop_data(_p: Vector2, d: Variant) -> void:
	_hover = 0
	var it = d["item"]
	if atalho >= 0:
		var de: int = d.get("atalho", -1)
		var aqui = tela.inv.atalhos[atalho]
		tela.inv.atribuir_atalho(it, atalho)
		if de >= 0 and aqui != null and aqui != it:
			tela.inv.atribuir_atalho(aqui, de)     # troca de lugar os dois atalhos
	elif tela.inv.pode_combinar(it, tela.inv.slots.get(slot)):
		tela.inv.combinar(it, tela.inv.slots.get(slot))
	else:
		tela.inv.equipar(it, slot)

func _notification(what: int) -> void:
	if (what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END) and _hover != 0:
		_hover = 0
		queue_redraw()

func _draw() -> void:
	var f: Font = tela.fonte
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Visual.FUNDO_CELULA)
	draw_rect(r, Color(1, 1, 1, 0.18), false, 1.0)
	var it = item()
	if it != null:
		# o item cabe inteiro no encaixe, mantendo a proporção
		var t: Vector2i = it.tam(false)
		var k := minf(size.x / float(t.x), size.y / float(t.y))
		var tam := Vector2(t) * k
		var ri := Rect2((size - tam) * 0.5, tam)
		Visual.desenhar_item(self, it, ri, f, false, 0.35 if it == tela.item_arrastado() else 1.0)
		if it == tela.selecionado:
			draw_rect(r.grow(-1.0), Color(1.0, 0.71, 0.0), false, 2.0)
	elif atalho < 0:
		var nome: String = Itens.SLOTS.get(slot, slot)
		var w := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		Visual.texto(self, f, nome, Vector2((size.x - w) * 0.5, size.y * 0.5 + 4), 11, Color(1, 1, 1, 0.35), false)
	if atalho >= 0:
		Visual.texto(self, f, str(atalho + 1), Vector2(3, 12), 11, Color(1, 1, 1, 0.8))
	if _hover != 0:
		var cor := Color(0.2, 0.85, 0.3) if _hover > 0 else Color(0.9, 0.15, 0.1)
		draw_rect(r, Color(cor.r, cor.g, cor.b, 0.3))
		draw_rect(r, cor, false, 2.0)
