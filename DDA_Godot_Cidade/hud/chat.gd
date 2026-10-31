extends CanvasLayer
# CHAT DE TEXTO (1.09 · solo e multijogador): ENTER (PC) ou o botão CHAT (toque) abre o campo de texto embaixo, à
# esquerda; ENVIAR (ou Enter) manda. No multijogador a mensagem vai para todos da partida (rede/sessao_rede.gd, evento
# "chat"); no solo fica só na sua tela (anotações, testes). As mensagens aparecem em cima do campo e somem sozinhas
# depois de DURACAO s; com o chat aberto aparece o histórico (até HISTORICO linhas). Seta para cima repete a última
# que você mandou. Esc (ou X) fecha.
# MODO DESENVOLVEDOR: o que é escrito passa primeiro pelo dev/modo_dev.gd (o bloco de desenvolvimento, SEPARADO: na
# versão final é só apagar a pasta dev/ e o chat continua funcionando sem ele). Com o modo ligado, começar com "/"
# mostra a lista de comandos que combinam com o que foi escrito (toque/clique preenche, Tab completa).
# Quem cria: main.gd (no jogo, solo e rede). Mexa AQUI para: tamanho, cores, tempo na tela, limite de letras.

const UI := preload("res://menu/ui.gd")
const Sons := preload("res://audio/sons.gd")
const DEV_ARQ := "res://dev/modo_dev.gd"      # bloco de desenvolvimento (remover na versão final)

const DURACAO := 12.0                  # s que cada mensagem fica na tela (chat fechado)
const HISTORICO := 14                  # linhas com o chat aberto
const MAX_LETRAS := 140
const ESPERA := 0.8                    # s entre duas mensagens (sem metralhar)
const COR_NOME := Color(1.0, 0.78, 0.3)
const COR_SISTEMA := Color(0.6, 0.85, 1.0)

signal enviou(texto: String)           # mensagem normal (não comando): main/sessao manda para a rede

var main = null                        # main.gd
var controles = null
var aberto := false
var dev = null                         # dev/modo_dev.gd (null se a pasta dev/ não existir)

var _linhas: Array = []                # [texto, cor, tempo restante]
var _ultimas: Array = []               # o que você mandou (seta para cima)
var _i_ultima := -1
var _t_envio := 0.0
var _log: VBoxContainer
var _fundo_log: ColorRect
var _barra: HBoxContainer
var _campo: LineEdit
var _sug: VBoxContainer
var _painel_sug: PanelContainer
var _sug_cmds: Array = []              # comandos mostrados na lista (para Tab)
var _sujo := true

func _ready() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_ALWAYS
	var v := UI.vh(self)
	_fundo_log = ColorRect.new()
	_fundo_log.color = Color(0, 0, 0, 0.42)
	_fundo_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo_log.visible = false
	add_child(_fundo_log)
	_log = VBoxContainer.new()
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_constant_override("separation", int(0.25 * v))
	add_child(_log)
	# campo de texto + ENVIAR + X
	_barra = HBoxContainer.new()
	_barra.add_theme_constant_override("separation", int(0.8 * v))
	_barra.visible = false
	add_child(_barra)
	_campo = LineEdit.new()
	_campo.max_length = MAX_LETRAS
	_campo.placeholder_text = "Escreva uma mensagem..."
	_campo.custom_minimum_size = Vector2(52.0 * v, 6.2 * v)
	_campo.add_theme_font_override("font", UI.fonte(700))
	_campo.add_theme_font_size_override("font_size", int(2.7 * v))
	_campo.virtual_keyboard_enabled = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.85)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(0.8 * v))
	sb.content_margin_left = 1.2 * v
	sb.content_margin_right = 1.2 * v
	_campo.add_theme_stylebox_override("normal", sb)
	_campo.add_theme_stylebox_override("focus", sb)
	_campo.text_submitted.connect(func(_t): _enviar())
	_campo.text_changed.connect(func(_t): _atualizar_sugestoes())
	_barra.add_child(_campo)
	_barra.add_child(_botao("ENVIAR", Color("#19d46a"), Color("#04210f"), _enviar))
	_barra.add_child(_botao("X", Color(1, 1, 1, 0.15), Color.WHITE, fechar))
	# lista de comandos (modo desenvolvedor)
	_painel_sug = PanelContainer.new()
	var sp := StyleBoxFlat.new()
	sp.bg_color = Color(0.02, 0.03, 0.05, 0.92)
	sp.border_color = Color(0.6, 0.85, 1.0, 0.5)
	sp.set_border_width_all(2)
	sp.set_corner_radius_all(int(0.8 * v))
	sp.content_margin_left = 1.0 * v
	sp.content_margin_right = 1.0 * v
	sp.content_margin_top = 0.6 * v
	sp.content_margin_bottom = 0.6 * v
	_painel_sug.add_theme_stylebox_override("panel", sp)
	_painel_sug.visible = false
	_sug = VBoxContainer.new()
	_sug.add_theme_constant_override("separation", 0)
	_painel_sug.add_child(_sug)
	add_child(_painel_sug)
	if ResourceLoader.exists(DEV_ARQ):
		dev = load(DEV_ARQ).new()
		dev.chat = self
	get_viewport().size_changed.connect(_posicionar)
	_posicionar()

func ligar(m) -> void:
	main = m
	controles = m.controles
	if dev != null:
		dev.main = m

func _botao(t: String, fundo: Color, cor: Color, acao: Callable) -> Button:
	var v := UI.vh(self)
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(6.2 * v, 6.2 * v)
	b.add_theme_font_override("font", UI.fonte(800))
	b.add_theme_font_size_override("font_size", int(2.5 * v))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, cor)
	for est in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = fundo.lightened(0.15) if est == "hover" else fundo
		s.set_corner_radius_all(int(0.8 * v))
		s.content_margin_left = 1.4 * v
		s.content_margin_right = 1.4 * v
		b.add_theme_stylebox_override(est, s)
	b.pressed.connect(acao)
	return b

func _posicionar() -> void:
	var vs := get_viewport().get_visible_rect().size
	var v := vs.y / 100.0
	_barra.position = Vector2(2.2 * v, vs.y - 9.5 * v)
	_barra.size = Vector2.ZERO
	_sujo = true

# ---------- abrir / fechar ----------
func abrir(texto := "") -> void:
	if aberto or (controles != null and controles.bloqueado):
		return
	aberto = true
	_barra.visible = true
	_campo.text = texto
	_campo.caret_column = texto.length()
	_campo.grab_focus()
	_i_ultima = -1
	if controles != null:
		controles.set_bloqueado(true)          # o personagem para enquanto você escreve
		controles.mouse_solto = true
	_atualizar_sugestoes()
	_sujo = true

func fechar() -> void:
	if not aberto:
		return
	aberto = false
	_barra.visible = false
	_painel_sug.visible = false
	_campo.release_focus()
	if controles != null:
		controles.set_bloqueado(false)
		controles.mouse_solto = false
	_sujo = true

func _input(e: InputEvent) -> void:
	if not aberto or not (e is InputEventKey) or not e.pressed:
		return
	var k: int = (e as InputEventKey).keycode
	if k == KEY_ESCAPE:
		fechar()
		get_viewport().set_input_as_handled()
	elif k == KEY_TAB:
		if not _sug_cmds.is_empty():
			_preencher(_sug_cmds[0])
		get_viewport().set_input_as_handled()
	elif k == KEY_UP and not _ultimas.is_empty():
		_i_ultima = clampi(_i_ultima + 1, 0, _ultimas.size() - 1)
		_campo.text = _ultimas[_ultimas.size() - 1 - _i_ultima]
		_campo.caret_column = _campo.text.length()
		get_viewport().set_input_as_handled()

# ---------- mandar ----------
func _enviar() -> void:
	var t := _campo.text.strip_edges().left(MAX_LETRAS)
	_campo.text = ""
	if t == "":
		fechar()
		return
	_ultimas.append(t)
	if _ultimas.size() > 20:
		_ultimas.pop_front()
	# o modo desenvolvedor vê primeiro (a senha e os comandos "/" não vão para ninguém)
	if dev != null and dev.tratar(t):
		_atualizar_sugestoes()
		if not dev.manter_aberto:
			fechar()
		return
	if t.begins_with("/"):
		sistema("Comando desconhecido.")
		fechar()
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _t_envio < ESPERA:
		sistema("Calma: espere um pouco para mandar outra.")
		return
	_t_envio = agora
	fechar()
	mostrar(_meu_nome(), t)
	enviou.emit(t)

func _meu_nome() -> String:
	var r = get_node_or_null("/root/Rede")
	if r != null and bool(r.get("ligado")):
		return str(r.nome_de(r.meu_id()))
	var c = get_node_or_null("/root/Conta")
	var n: String = str(c.get("nome")) if c != null and c.get("nome") != null else ""
	return n if n != "" else "VOCÊ"

# ---------- mostrar ----------
func mostrar(nome: String, texto: String) -> void:
	_add("[color=#%s]%s:[/color] %s" % [COR_NOME.to_html(false), _limpo(nome.to_upper()), _limpo(texto)])
	Sons.tocar("ui/aviso", -10.0)

func sistema(texto: String) -> void:
	_add("[color=#%s]%s[/color]" % [COR_SISTEMA.to_html(false), _limpo(texto)])

func limpar() -> void:
	_linhas.clear()
	_sujo = true

func _add(bb: String) -> void:
	_linhas.append([bb, DURACAO])
	while _linhas.size() > 60:
		_linhas.pop_front()
	_sujo = true

# o que o jogador escreve não vira formatação ([b], [color]...)
static func _limpo(t: String) -> String:
	return t.replace("[", "[lb]")

func _process(dt: float) -> void:
	var mudou := false
	for l in _linhas:
		if l[1] > 0.0:
			var antes: float = l[1]
			l[1] = maxf(0.0, l[1] - dt)
			if (antes > 1.0) != (l[1] > 1.0) or l[1] <= 1.0:
				mudou = true
	if mudou or _sujo:
		_sujo = false
		_redesenhar()

func _redesenhar() -> void:
	for c in _log.get_children():
		_log.remove_child(c)                     # sai já (senão ainda conta no tamanho até o fim do quadro)
		c.queue_free()
	var vs := get_viewport().get_visible_rect().size
	var v := vs.y / 100.0
	var mostrar_l: Array = []
	if aberto:
		mostrar_l = _linhas.slice(maxi(0, _linhas.size() - HISTORICO))
	else:
		for l in _linhas:
			if l[1] > 0.0:
				mostrar_l.append(l)
		mostrar_l = mostrar_l.slice(maxi(0, mostrar_l.size() - 6))
	var larg := 62.0 * v
	for l in mostrar_l:
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size.x = larg
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_theme_font_override("normal_font", UI.fonte(700))
		r.add_theme_font_size_override("normal_font_size", int(2.3 * v))
		r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		r.add_theme_constant_override("shadow_offset_x", 1)
		r.add_theme_constant_override("shadow_offset_y", 1)
		r.text = l[0]
		if not aberto:
			r.modulate.a = clampf(float(l[1]), 0.0, 1.0)
		_log.add_child(r)
	_log.reset_size()
	_log.size.x = larg
	# em cima do campo (aberto) ou um pouco acima do canto de baixo (fechado)
	var base_y := vs.y - (11.5 if aberto else 10.0) * v
	if _painel_sug.visible:
		base_y = _painel_sug.position.y - 0.8 * v
	_log.position = Vector2(2.2 * v, base_y)
	_atualizar_pos_log.call_deferred(base_y)

func _atualizar_pos_log(base_y: float) -> void:
	var v := get_viewport().get_visible_rect().size.y / 100.0
	_log.size = Vector2(_log.size.x, _log.get_combined_minimum_size().y)      # do tamanho do texto (não cresce à toa)
	_log.position.y = base_y - _log.size.y
	_fundo_log.visible = aberto and _log.get_child_count() > 0
	_fundo_log.position = _log.position - Vector2(0.8 * v, 0.6 * v)
	_fundo_log.size = _log.size + Vector2(1.6 * v, 1.2 * v)

# ---------- lista de comandos (modo desenvolvedor) ----------
func _atualizar_sugestoes() -> void:
	for c in _sug.get_children():
		_sug.remove_child(c)
		c.queue_free()
	_sug_cmds.clear()
	var t := _campo.text
	if not aberto or dev == null or not dev.ativo or not t.begins_with("/"):
		_painel_sug.visible = false
		_sujo = true
		return
	var v := UI.vh(self)
	var lista: Array = dev.sugestoes(t)          # [[texto que preenche, "uso", "descrição"], ...]
	for s in lista.slice(0, 12):
		_sug_cmds.append(s[0])
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s   —  %s" % [s[1], s[2]]
		b.add_theme_font_override("font", UI.fonte(700))
		b.add_theme_font_size_override("font_size", int(2.15 * v))
		b.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
		b.add_theme_color_override("font_hover_color", UI.AMBAR)
		var preenche: String = s[0]
		b.pressed.connect(func(): _preencher(preenche))
		_sug.add_child(b)
	if lista.size() > 12:
		var mais := UI.rotulo("... e mais %d (continue escrevendo)" % (lista.size() - 12), 2.0 * v, Color(1, 1, 1, 0.55), 600)
		_sug.add_child(mais)
	if lista.is_empty():
		_sug.add_child(UI.rotulo("Nenhum comando começa assim. /ajuda lista todos.", 2.1 * v, Color(1, 0.6, 0.5), 700))
	_painel_sug.visible = true
	_painel_sug.reset_size()
	_reposicionar_sug.call_deferred()

func _reposicionar_sug() -> void:
	var v := UI.vh(self)
	_painel_sug.size = _painel_sug.get_combined_minimum_size()               # encolhe quando a lista diminui
	_painel_sug.position = Vector2(2.2 * v, _barra.position.y - _painel_sug.size.y - 0.8 * v)
	_sujo = true

func _preencher(texto: String) -> void:
	_campo.text = texto
	_campo.caret_column = texto.length()
	_campo.grab_focus()
	_atualizar_sugestoes()
