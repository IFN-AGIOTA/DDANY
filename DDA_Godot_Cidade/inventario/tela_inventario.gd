extends CanvasLayer
# TELA DE INVENTÁRIO (estilo DayZ) · abre com o botão INV, Tab ou I · fecha com Tab, I, Esc ou FECHAR.
#   ESQUERDA ... o que está PERTO no mundo: itens no chão (grade "CHÃO"), caixas/armários e mochilas jogadas
#   MEIO ....... o personagem (3D em tempo real no modo livre: inventario/boneco_3d.gd): encaixes do corpo (cabeça, camisa, colete, cinto, ombro, coldre, calça, mochila),
#                MÃOS, barra de atalhos 1..8 e informações do item selecionado (USAR / PEGAR / LARGAR / DIVIDIR)
#   DIREITA .... o que você carrega: bolsos da camisa, calça, colete, cinto e a mochila
# Arrastar e soltar entre qualquer lugar; durante o arraste, R / Espaço / botão direito / 2º dedo = girar.
# Duplo toque = ação rápida (pegar do chão, vestir, usar, guardar a arma). Com a tela aberta o jogador fica parado.

const Sons := preload("res://audio/sons.gd")
const GradeUi := preload("res://inventario/grade_ui.gd")
const SlotUi := preload("res://inventario/slot_ui.gd")
const GradeCls := preload("res://inventario/grade.gd")
const Itens := preload("res://inventario/itens.gd")
const Visual := preload("res://inventario/visual.gd")
const Boneco3D := preload("res://inventario/boneco_3d.gd")
const PortaCls := preload("res://mundo/porta.gd")

const AMBAR := Color(1.0, 0.71, 0.0)
const SLOTS_ESQ := ["cabeca", "rosto", "camisa", "colete", "cinto"]   # 0.65: ROSTO (máscara de gás)
const SLOTS_DIR := ["ombro", "coldre", "calca", "mochila"]

var inv = null                 # inventario.gd
var controles = null
var aberto := false
var fonte: Font
var cel := 44.0
var selecionado = null

var _raiz: Control
var _col_esq: VBoxContainer
var _col_dir: VBoxContainer
var _peso: Label
var _info: Label
var _bt := {}                  # nome -> Button
var _grades_ui: Array = []
var _slots_ui: Array = []
var _grade_chao = null
var _arrastando = null         # dados do arraste atual (Dictionary) ou null
var _hover_atual = null
var _refazer := true
var _assinatura := ""
var _t_scan := 0.0
var _cel_montada := -1.0
var _aviso := ""
var _aviso_t := 0.0
var _t_vida := 0.0

func _ready() -> void:
	layer = 20
	fonte = ThemeDB.fallback_font
	_grade_chao = GradeCls.new(8, 3, "CHÃO", null)
	_grade_chao.chao = true
	get_viewport().size_changed.connect(_tela_mudou)

func _tela_mudou() -> void:
	if aberto:
		_montar()

func ligar(inventario, c) -> void:
	inv = inventario
	controles = c
	inv.mudou.connect(_ao_mudar)
	inv.aviso.connect(_ao_avisar)
	c.inventario_pedido.connect(alternar)

# ---------- abrir / fechar ----------
func alternar() -> void:
	if aberto:
		fechar()
	else:
		abrir()

func abrir() -> void:
	aberto = true
	selecionado = null
	_assinatura = inv.assinatura_perto()
	_montar()
	controles.set_bloqueado(true)
	Sons.tocar("inventario/mochila", -6.0)        # abriu a mochila (pano/zíper)

func fechar() -> void:
	if aberto:
		Sons.tocar("inventario/mochila", -9.0, 0.9)
	aberto = false
	_arrastando = null
	if _raiz != null:
		_raiz.queue_free()
		_raiz = null
	_grades_ui.clear()
	_slots_ui.clear()
	controles.set_bloqueado(false)

func _ao_mudar() -> void:
	_refazer = true
	if aberto:
		_atualizar_meio()

func _ao_avisar(t: String) -> void:
	_aviso = t
	_aviso_t = 1.5
	if aberto:
		_atualizar_meio()

# ---------- chamados pelas grades/encaixes ----------
func selecionar(it) -> void:
	selecionado = it
	_atualizar_meio()

func acao_rapida(it) -> void:
	inv.acao_rapida(it)

func comecou_arraste(d: Dictionary) -> void:
	_arrastando = d
	_redesenhar()

func item_arrastado():
	return _arrastando["item"] if _arrastando != null else null

func marcar_hover(g) -> void:
	if _hover_atual != null and _hover_atual != g and is_instance_valid(_hover_atual):
		_hover_atual.limpar_hover()
	_hover_atual = g

# ---------- entrada: girar durante o arraste, Esc ----------
func _input(e: InputEvent) -> void:
	if not aberto:
		return
	if _arrastando != null and get_viewport().gui_is_dragging():
		var girar := false
		if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_R or e.keycode == KEY_SPACE):
			girar = true
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			girar = true
		elif e is InputEventScreenTouch and e.pressed and e.index > 0:
			girar = true
		if girar:
			var it = _arrastando["item"]
			var t: Vector2i = it.tam(false)
			if t.x != t.y:
				_arrastando["rot"] = not bool(_arrastando.get("rot", false))
			get_viewport().set_input_as_handled()
			return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		fechar()
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if inv == null:
		return
	_t_scan -= dt
	if _t_scan <= 0.0:
		_t_scan = 0.25
		if controles != null:
			var perto = inv.item_mais_proximo()
			# 0.73: sem item perto, o mesmo botão serve para a PORTA (abrir, fechar, tirar tábua)
			var acao_porta := ""
			if perto == null and inv.jogador != null:
				var pt = PortaCls.perto(inv.jogador.global_position)
				if pt != null:
					acao_porta = pt.acao(inv)
			controles.ocultos["PEGAR"] = aberto or (perto == null and acao_porta == "")
			# o botão diz O QUE vai pegar (nome curto do item)
			if acao_porta != "":
				controles.textos["PEGAR"] = acao_porta
			elif perto != null:
				controles.textos["PEGAR"] = "PEGAR\n" + String(perto.def().get("sigla", perto.nome()))
		if aberto:
			var s: String = inv.assinatura_perto()
			if s != _assinatura:
				_assinatura = s
				_refazer = true
			_t_vida -= 0.25
			if _t_vida <= 0.0 and _peso != null:      # vida/sangue no cabeçalho: atualiza 1 vez por segundo
				_t_vida = 1.0
				_atualizar_meio()
	if not aberto:
		return
	if _aviso_t > 0.0:
		_aviso_t -= dt
		if _aviso_t <= 0.0:
			_atualizar_meio()
	if _arrastando != null and not get_viewport().gui_is_dragging():
		_arrastando = null
		_redesenhar()
	if _refazer and _arrastando == null:
		_montar_colunas()

# ---------- montagem ----------
func _calcular_celula() -> float:
	var vs := get_viewport().get_visible_rect().size
	return floorf(clampf(minf((vs.x - 80.0) / 25.0, (vs.y - 100.0) / 13.5), 26.0, 52.0))

func _montar() -> void:
	if _raiz != null:
		_raiz.queue_free()
	_grades_ui.clear()
	_slots_ui.clear()
	cel = _calcular_celula()
	_raiz = Control.new()
	_raiz.name = "Inventario"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	# soltar um ATALHO fora da barra (fundo / colunas) = desliga o atalho
	_raiz.set_drag_forwarding(Callable(),
		func(_p, d): return typeof(d) == TYPE_DICTIONARY and d.has("atalho"),
		func(_p, d): inv.limpar_atalho(int(d["atalho"])))
	_raiz.theme = _tema()
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.035, 0.04, 0.9)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fundo)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 14
	hb.offset_top = 10
	hb.offset_right = -14
	hb.offset_bottom = -10
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	_raiz.add_child(hb)
	# ESQUERDA: perto (soltar no fundo da coluna = largar no chão)
	var esq := _coluna("PERTO DE VOCÊ")
	hb.add_child(esq[0])
	_col_esq = esq[1]
	esq[0].set_drag_forwarding(Callable(),
		func(_p, d): return typeof(d) == TYPE_DICTIONARY and d.has("item") and not d.has("atalho") and d["item"].no_mundo == null,
		func(_p, d): inv.largar(d["item"]))
	# MEIO: personagem
	hb.add_child(_montar_meio())
	# DIREITA: inventário
	var dir := _coluna("INVENTÁRIO")
	hb.add_child(dir[0])
	_col_dir = dir[1]
	_cel_montada = cel
	_montar_colunas()
	_atualizar_meio()

func _tema() -> Theme:
	var t := Theme.new()
	var cores := {"normal": Color(0.16, 0.17, 0.18, 0.95), "hover": Color(0.24, 0.25, 0.26, 0.95),
		"pressed": Color(0.55, 0.40, 0.05, 0.95), "disabled": Color(0.10, 0.10, 0.11, 0.8)}
	for estado in cores:
		var sb := StyleBoxFlat.new()
		sb.bg_color = cores[estado]
		sb.border_color = Color(1, 1, 1, 0.12 if estado != "disabled" else 0.04)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		t.set_stylebox(estado, "Button", sb)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.25))
	return t

func _rotulo(txt: String, tam := 15, cor := Color(1, 1, 1, 0.9)) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# [coluna, conteúdo rolável, título]
func _coluna(titulo: String) -> Array:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_PASS     # o que ela não aceita passa para o fundo (desligar atalho)
	v.add_theme_constant_override("separation", 6)
	var t := _rotulo(titulo, 17, AMBAR)
	v.add_child(t)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(sc)
	var conteudo := VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation", 10)
	conteudo.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(conteudo)
	return [v, conteudo, t]

func _botao(txt: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.custom_minimum_size = Vector2(0, maxf(34.0, cel * 0.8))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): Sons.ui("clique"))
	b.pressed.connect(acao)
	return b

func _encaixe(nome: String, tamanho: Vector2, indice := -1) -> Control:
	var s: Control = SlotUi.new()
	s.configurar(self, nome, indice)
	s.custom_minimum_size = tamanho
	_slots_ui.append(s)
	return s

func _montar_meio() -> Control:
	var largura := 8.0 * cel + 14.0
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = largura
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_theme_constant_override("separation", 6)
	var topo := HBoxContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_PASS
	_peso = _rotulo("", 15)
	_peso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_peso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(_peso)
	var fechar_bt := _botao("FECHAR", fechar)
	fechar_bt.size_flags_horizontal = Control.SIZE_SHRINK_END
	fechar_bt.custom_minimum_size.x = 110
	topo.add_child(fechar_bt)
	v.add_child(topo)
	# corpo: encaixes à esquerda e à direita do boneco
	var corpo := HBoxContainer.new()
	corpo.mouse_filter = Control.MOUSE_FILTER_PASS
	corpo.add_theme_constant_override("separation", 6)
	var tam_slot := Vector2(cel * 1.75, cel * 1.24)       # 0.65: 5 encaixes na coluna da esquerda
	var ve := VBoxContainer.new()
	var vd := VBoxContainer.new()
	for col in [[ve, SLOTS_ESQ], [vd, SLOTS_DIR]]:
		col[0].mouse_filter = Control.MOUSE_FILTER_PASS
		col[0].add_theme_constant_override("separation", 4)
		for s in col[1]:
			col[0].add_child(_encaixe(s, tam_slot))
	var boneco: Control
	var jog = inv.jogador
	if jog != null and jog.get_node_or_null("Modelo/Sobrevivente") != null:
		# modo livre: o personagem 3D em tempo real, com o que está equipado (girar = arrastar)
		boneco = Boneco3D.new(inv)
		boneco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		boneco = Control.new()
		boneco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boneco.draw.connect(_desenhar_boneco.bind(boneco))
	boneco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_child(ve)
	corpo.add_child(boneco)
	corpo.add_child(vd)
	v.add_child(corpo)
	# mãos
	v.add_child(_rotulo("MÃOS", 14, Color(1, 1, 1, 0.6)))
	v.add_child(_encaixe("maos", Vector2(largura, cel * 2.1)))
	# atalhos
	var barra := HBoxContainer.new()
	barra.mouse_filter = Control.MOUSE_FILTER_PASS
	barra.add_theme_constant_override("separation", 2)
	var lado := floorf((largura - 14.0) / 8.0)
	for i in inv.N_ATALHOS:
		barra.add_child(_encaixe("", Vector2(lado, lado), i))
	v.add_child(barra)
	# informações do item selecionado + ações (bom para o celular)
	_info = _rotulo("", 13, Color(1, 1, 1, 0.85))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(largura, 48)
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_info)
	var acoes := HBoxContainer.new()
	acoes.mouse_filter = Control.MOUSE_FILTER_PASS
	for par in [["USAR", _usar], ["PEGAR", _pegar], ["LARGAR", _largar], ["DIVIDIR", _dividir]]:
		var b := _botao(par[0], par[1])
		_bt[par[0]] = b
		acoes.add_child(b)
	v.add_child(acoes)
	return v

func _desenhar_boneco(c: Control) -> void:
	var s := c.size
	var cx := s.x * 0.5
	var h := s.y
	var cor := Color(1, 1, 1, 0.10)
	c.draw_circle(Vector2(cx, h * 0.1), h * 0.065, cor)
	c.draw_rect(Rect2(cx - h * 0.11, h * 0.18, h * 0.22, h * 0.36), cor)
	c.draw_rect(Rect2(cx - h * 0.17, h * 0.19, h * 0.05, h * 0.3), cor)
	c.draw_rect(Rect2(cx + h * 0.12, h * 0.19, h * 0.05, h * 0.3), cor)
	c.draw_rect(Rect2(cx - h * 0.1, h * 0.55, h * 0.09, h * 0.42), cor)
	c.draw_rect(Rect2(cx + h * 0.01, h * 0.55, h * 0.09, h * 0.42), cor)

# seção = título "NOME (usadas/total)" + grade
func _secao(col: VBoxContainer, titulo: String, g) -> void:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_theme_constant_override("separation", 2)
	var txt := titulo
	if not g.chao:
		txt += " (%d/%d)" % [g.celulas_usadas(), g.largura * g.altura]
	var cab := _rotulo(txt, 14)
	v.add_child(cab)
	var gu: Control = GradeUi.new()
	gu.configurar(g, self, cel)
	gu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(gu)
	_grades_ui.append(gu)
	col.add_child(v)

func _limpar(col: VBoxContainer) -> void:
	for f in col.get_children():
		col.remove_child(f)
		f.queue_free()

func _montar_colunas() -> void:
	_refazer = false
	if _raiz == null:
		return
	if cel != _cel_montada:
		_montar()
		return
	_hover_atual = null
	_grades_ui.clear()
	_limpar(_col_esq)
	_limpar(_col_dir)
	# esquerda: chão + caixas + mochilas jogadas
	var no_chao: Array = inv.itens_perto()
	_grade_chao.largura = 8
	_grade_chao.empacotar(no_chao)
	_secao(_col_esq, "CHÃO", _grade_chao)
	for c in inv.conteineres_perto():
		_secao(_col_esq, c.nome, c.grade)
	for it in no_chao:
		for g in it.grades():                     # 0.65: um quadro por bolso
			_secao(_col_esq, g.nome + " · NO CHÃO", g)
	# direita: roupas e mochila vestidas
	var n := 0
	for s in inv.CONTEINERES_CORPO:
		var it = inv.slots[s]
		if it != null and it.conteudo != null:
			for g in it.grades():                 # 0.65: cada bolso da roupa com a sua grade
				_secao(_col_dir, g.nome, g)
			n += 1
	if n == 0:
		_col_dir.add_child(_rotulo("Vista roupas ou uma mochila para carregar coisas.", 14, Color(1, 1, 1, 0.5)))
	_atualizar_meio()

func _redesenhar() -> void:
	for g in _grades_ui:
		if is_instance_valid(g):
			g.queue_redraw()
	for s in _slots_ui:
		if is_instance_valid(s):
			s.queue_redraw()

func _existe(it) -> bool:
	return it != null and it.qtd > 0 and (it.onde != null or it.slot != "" or it.no_mundo != null)

func _atualizar_meio() -> void:
	if _raiz == null:
		return
	if not _existe(selecionado):
		selecionado = null
	_peso.text = "PESO %.1f kg" % inv.peso_total()
	# com o inventário aberto o jogo NÃO pausa: vida, sangue e sangramento ficam à vista aqui
	var sv = inv.jogador.get("sobrevivencia") if inv.jogador != null else null
	if sv != null:
		_peso.text += "   ·   VIDA %d   SANGUE %d%%" % [int(sv.vida), int(sv.sangue / 50.0)]
		if int(sv.sangramentos) > 0:
			_peso.text += "   ·   SANGRANDO"
	if _aviso_t > 0.0:
		_peso.text += "   ·   " + _aviso
	var it = selecionado
	if it == null:
		_info.text = "Toque num item para ver. Arraste para mover · duplo toque = ação rápida · R / 2º dedo = girar."
	else:
		var d: Dictionary = it.def()
		var linhas: String = it.nome()
		if it.max_pilha() > 1:
			linhas += "  ×%d" % it.qtd
		if it.eh_arma_de_fogo():
			if it.usa_pente() != "" and it.pente_id == "":
				linhas += "  ·  SEM PENTE"
			else:
				linhas += "  ·  %d/%d balas" % [it.municao, it.capacidade()]
			linhas += " (%d soltas)" % inv.contar(d.get("municao", ""))
			for k in it.acessorios:
				linhas += "  ·  " + String(Itens.def(it.acessorios[k]).get("sigla", ""))
		elif it.eh_pente():
			linhas += "  ·  %d/%d balas" % [it.municao, it.capacidade()]
		if d.get("pilha", false) or it.id == "pilha":      # 0.65: carga da pilha em palavras
			var c: float = it.carga
			linhas += "  ·  " + ("SEM PILHA" if c < 0.0 else ("PILHA VAZIA" if c <= 0.0 else ("PILHA FRACA" if c < 0.25 else ("PILHA PELA METADE" if c < 0.6 else "PILHA CHEIA"))))
			if it.id == "radio" and it.ligado:
				linhas += "  ·  LIGADO"
		linhas += "  ·  %.2f kg  ·  " % it.peso()
		_info.text = linhas
		_info.text += Itens.nome_estado(it.estado) + "\n" + String(d.get("desc", ""))
	var meu: bool = it != null and inv.do_jogador(it)
	var acao: String = inv.nome_acao(it)
	_bt["USAR"].disabled = it == null or not meu or (acao == "NA MÃO" and it.slot == "maos")
	_bt["USAR"].text = acao
	_bt["PEGAR"].disabled = it == null or meu
	_bt["LARGAR"].disabled = it == null or it.no_mundo != null
	_bt["DIVIDIR"].disabled = it == null or it.qtd < 2 or it.no_mundo != null
	_redesenhar()

func _usar() -> void:
	if selecionado != null:
		inv.usar(selecionado)

func _pegar() -> void:
	if selecionado != null:
		inv.pegar(selecionado)

func _largar() -> void:
	if selecionado != null:
		inv.largar(selecionado)

func _dividir() -> void:
	if selecionado != null:
		inv.dividir(selecionado)
