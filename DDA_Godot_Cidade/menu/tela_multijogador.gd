extends CanvasLayer
# TELA MULTIJOGADOR (botão "Multijogador" do menu principal): seu nome, CRIAR PARTIDA (você vira o host e
# aparece o seu IP para os amigos), PARTIDAS NA REDE (achadas sozinhas no mesmo Wi-Fi) e ENTRAR POR IP.
# Quando a conexão fica pronta (rede/rede.gd: sinal pronto) emite "comecar" e o main.gd abre o mundo livre.
# Mexa AQUI para: textos e o layout desta tela.

signal fechar
signal comecar

const UI := preload("res://menu/ui.gd")

var _raiz: Control
var _nome: LineEdit
var _ip: LineEdit
var _lista: VBoxContainer
var _status: Label
var _achadas := {}                            # ip -> [nome, jogadores, tempo]
var _esperando := false

func _ready() -> void:
	layer = 30
	Rede.pronto.connect(_pronto)
	Rede.falhou.connect(_falhou)
	Rede.partida_achada.connect(_achou)
	Rede.procurar(true)
	get_viewport().size_changed.connect(_montar)
	_montar()

func _exit_tree() -> void:
	Rede.procurar(false)
	Rede.pronto.disconnect(_pronto)
	Rede.falhou.disconnect(_falhou)
	Rede.partida_achada.disconnect(_achou)

func _montar() -> void:
	var nome_antes := _nome.text if _nome != null else str(Config.valor("nome_rede"))
	var ip_antes := _ip.text if _ip != null else str(Config.valor("ip_rede"))
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
	var tit := UI.titulo_degrade("MULTIJOGADOR", 9.0 * v, 0.1 * 9.0 * v)
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
	var linhas := HBoxContainer.new()
	linhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linhas.add_theme_constant_override("separation", int(6.0 * v))
	rolar.add_child(linhas)
	# coluna da esquerda: nome + criar + entrar por IP
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.add_theme_constant_override("separation", int(1.2 * v))
	linhas.add_child(esq)
	_secao(esq, "SEU NOME", v)
	_nome = _campo(nome_antes, "Sobrevivente", v)
	esq.add_child(_nome)
	_secao(esq, "CRIAR PARTIDA", v)
	esq.add_child(_texto("Você vira o HOST: o mundo (hora, clima e loot) é o seu. Os amigos no mesmo Wi-Fi acham a partida sozinhos ou entram pelo seu IP.", v))
	var bc := UI.BotaoMenu.new("Criar partida", "até %d jogadores" % Rede.MAX_JOGADORES, true, 3.6, 30.0)
	bc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bc.apertado.connect(_criar)
	esq.add_child(bc)
	_secao(esq, "ENTRAR POR IP", v)
	_ip = _campo(ip_antes, "ex.: 192.168.0.10", v)
	esq.add_child(_ip)
	var be := UI.BotaoMenu.new("Entrar", "", false, 3.4, 20.0)
	be.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	be.apertado.connect(func(): _entrar(_ip.text))
	esq.add_child(be)
	# coluna da direita: partidas achadas na rede local
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir.add_theme_constant_override("separation", int(1.2 * v))
	linhas.add_child(dir)
	_secao(dir, "PARTIDAS NA REDE", v)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", int(1.0 * v))
	dir.add_child(_lista)
	_status = _texto("", v)
	_status.add_theme_color_override("font_color", UI.AMBAR)
	dir.add_child(_status)
	_atualizar_lista()

func _secao(col: VBoxContainer, txt: String, v: float) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(1.6 * v))
	m.add_child(UI.rotulo(txt, 3.0 * v, UI.TITULO_SECAO, 900, 0.15 * 3.0 * v, true))
	col.add_child(m)

func _texto(t: String, v: float) -> Label:
	var l := UI.rotulo(t, 2.4 * v, Color(1, 0.91, 0.82, 0.75), 400)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _campo(txt: String, dica: String, v: float) -> LineEdit:
	var e := LineEdit.new()
	e.text = txt
	e.placeholder_text = dica
	e.max_length = 40
	e.custom_minimum_size = Vector2(40.0 * v, 6.5 * v)
	e.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	e.add_theme_font_override("font", UI.fonte(700, 0.0, false))
	e.add_theme_font_size_override("font_size", int(3.0 * v))
	e.add_theme_color_override("font_color", UI.TEXTO)
	e.add_theme_color_override("font_placeholder_color", Color(1, 0.91, 0.82, 0.35))
	for est in ["normal", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UI.FUNDO_SEG
		sb.border_color = UI.LARANJA if est == "focus" else UI.BORDA
		sb.set_border_width_all(2)
		sb.content_margin_left = 1.4 * v
		sb.content_margin_right = 1.4 * v
		e.add_theme_stylebox_override(est, sb)
	return e

# ---------- ações ----------
func _meu_nome() -> String:
	Config.definir("nome_rede", _nome.text.strip_edges())
	return _nome.text

func _criar() -> void:
	if _esperando:
		return
	_esperando = true
	_status.text = "Abrindo a partida…"
	Rede.criar_partida(_meu_nome(), randi())

func _entrar(ip: String) -> void:
	if _esperando:
		return
	ip = ip.strip_edges()
	Config.definir("ip_rede", ip)
	_esperando = true
	_status.text = "Conectando em %s…" % ip
	Rede.entrar(ip, _meu_nome())
	# sem resposta em 8 s: desiste
	await get_tree().create_timer(8.0).timeout
	if is_inside_tree() and _esperando and not Rede.ligado:
		Rede.sair()
		_falhou("Sem resposta de %s (é o mesmo Wi-Fi? o host criou a partida?)." % ip)

func _pronto() -> void:
	_esperando = false
	if Rede.eh_host():
		var ips := Rede.meus_ips()
		_status.text = "Partida criada. Seu IP: %s" % (", ".join(ips) if not ips.is_empty() else "?")
	comecar.emit()

func _falhou(motivo: String) -> void:
	_esperando = false
	if _status != null:
		_status.text = motivo

func _achou(ip: String, nome: String, n: int) -> void:
	var novo := not _achadas.has(ip)
	_achadas[ip] = [nome, n, Time.get_ticks_msec()]
	if novo:
		_atualizar_lista()

func _atualizar_lista() -> void:
	if _lista == null:
		return
	for f in _lista.get_children():
		f.queue_free()
	var v := UI.vh(self)
	if _achadas.is_empty():
		_lista.add_child(_texto("Procurando partidas no mesmo Wi-Fi…\nSe não aparecer, peça o IP ao host e use ENTRAR POR IP.", v))
		return
	for ip in _achadas:
		var a: Array = _achadas[ip]
		var b := UI.BotaoMenu.new("Partida de %s" % a[0], "%s · %d jogador(es)" % [ip, a[1]], false, 3.2, 34.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.apertado.connect(func(): _entrar(ip))
		_lista.add_child(b)

func _process(_dt: float) -> void:
	# some da lista a partida que parou de anunciar (5 s)
	var agora := Time.get_ticks_msec()
	var mudou := false
	for ip in _achadas.keys():
		if agora - int(_achadas[ip][2]) > 5000:
			_achadas.erase(ip)
			mudou = true
	if mudou:
		_atualizar_lista()

func _sair() -> void:
	if not Rede.ligado:
		Rede.sair()
	fechar.emit()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_sair()
