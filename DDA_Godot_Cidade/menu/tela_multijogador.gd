extends CanvasLayer
# TELA MULTIJOGADOR (botão "Multijogador" do menu principal): seu nome, CRIAR PARTIDA, PARTIDAS NA REDE (achadas
# sozinhas no mesmo Wi-Fi) e ENTRAR (código, convite colado, IP, IP:porta ou endereço:porta).
# Criando a partida abre a SALA: os CÓDIGOS (internet, VPN, Wi-Fi), COPIAR CONVITE (para mandar no WhatsApp),
# quem já entrou e COMEÇAR A JOGAR. Quem entra começa assim que o host aceita.
# Quando é hora de jogar emite "comecar" e o main.gd abre o mundo livre.
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
var _sala := false                            # host com a partida criada (mostra códigos e convite)
var _sala_info: VBoxContainer

func _ready() -> void:
	layer = 30
	Rede.pronto.connect(_pronto)
	Rede.falhou.connect(_falhou)
	Rede.partida_achada.connect(_achou)
	Rede.internet.connect(_internet)
	Rede.jogador_entrou.connect(_mudou_sala)
	Rede.jogador_saiu.connect(_mudou_sala)
	Rede.procurar(true)
	get_viewport().size_changed.connect(_montar)
	_montar()

func _exit_tree() -> void:
	Rede.procurar(false)
	Rede.pronto.disconnect(_pronto)
	Rede.falhou.disconnect(_falhou)
	Rede.partida_achada.disconnect(_achou)
	Rede.internet.disconnect(_internet)
	Rede.jogador_entrou.disconnect(_mudou_sala)
	Rede.jogador_saiu.disconnect(_mudou_sala)

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
	fundo.color = Color(0.06, 0.025, 0.01, 0.985)
	_raiz.add_child(fundo)
	var tit := UI.titulo_degrade("MULTIJOGADOR", 9.0 * v, 0.1 * 9.0 * v)
	tit.position = Vector2(6.0 * v, 3.0 * v)
	_raiz.add_child(tit)
	var voltar := UI.BotaoMenu.new("Cancelar" if _sala else "Voltar", "", true, 3.4, 20.0)
	voltar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	voltar.offset_left = -26.0 * v
	voltar.offset_right = -4.0 * v
	voltar.offset_top = 4.0 * v
	voltar.apertado.connect(_sair)
	_raiz.add_child(voltar)
	if _sala:
		_montar_sala(v)
		return
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
	esq.add_child(_texto("Você vira o HOST: o mundo (hora, clima e loot) é o seu. Depois você manda o CONVITE (código) para os amigos: de perto (mesmo Wi-Fi) ou de longe (internet).", v))
	var bc := UI.BotaoMenu.new("Criar partida", "até %d jogadores" % Rede.MAX_JOGADORES, true, 3.6, 30.0)
	bc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bc.apertado.connect(_criar)
	esq.add_child(bc)
	_secao(esq, "ENTRAR", v)
	esq.add_child(_texto("Código do convite (ex.: K7G2Q-0M4XA), IP ou endereço:porta. Copiou o convite no WhatsApp? Toque em COLAR.", v))
	_ip = _campo(ip_antes, "código, IP ou endereço", v)
	_ip.max_length = 120
	esq.add_child(_ip)
	var bes := HBoxContainer.new()
	bes.add_theme_constant_override("separation", int(1.4 * v))
	esq.add_child(bes)
	var be := UI.BotaoMenu.new("Entrar", "", false, 3.4, 18.0)
	be.apertado.connect(func(): _entrar(_ip.text))
	bes.add_child(be)
	var bcol := UI.BotaoMenu.new("Colar", "da área de transferência", false, 3.4, 18.0)
	bcol.apertado.connect(_colar)
	bes.add_child(bcol)
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

# ---------- SALA (host com a partida criada) ----------
func _montar_sala(v: float) -> void:
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
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.add_theme_constant_override("separation", int(1.2 * v))
	linhas.add_child(esq)
	_secao(esq, "PARTIDA CRIADA · CÓDIGOS", v)
	_sala_info = VBoxContainer.new()
	_sala_info.add_theme_constant_override("separation", int(0.8 * v))
	esq.add_child(_sala_info)
	var bs := HBoxContainer.new()
	bs.add_theme_constant_override("separation", int(1.4 * v))
	esq.add_child(bs)
	var bj := UI.BotaoMenu.new("Começar a jogar", "os amigos entram quando quiserem", true, 3.6, 30.0)
	bj.apertado.connect(func(): comecar.emit())
	bs.add_child(bj)
	var bconv := UI.BotaoMenu.new("Copiar convite", "para colar no WhatsApp", false, 3.6, 26.0)
	bconv.apertado.connect(func():
		DisplayServer.clipboard_set(Rede.convite())
		_status.text = "Convite copiado! Cole no WhatsApp (ou onde quiser) e mande para os amigos.")
	bs.add_child(bconv)
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir.add_theme_constant_override("separation", int(1.2 * v))
	linhas.add_child(dir)
	_secao(dir, "NA PARTIDA", v)
	_lista = VBoxContainer.new()
	dir.add_child(_lista)
	_status = _texto("", v)
	_status.add_theme_color_override("font_color", UI.AMBAR)
	dir.add_child(_status)
	_secao(dir, "DE LONGE NÃO CONECTA?", v)
	dir.add_child(_texto("Internet do celular (4G/5G) e muitos roteadores não deixam ninguém entrar de fora. Solução grátis: instalem o app TAILSCALE (ou ZeroTier) nos dois aparelhos, entrem na mesma conta/rede e usem o código \"VPN\". Também dá para usar um túnel (ex.: playit.gg, porta UDP %d) e entrar por endereço:porta." % Rede.PORTA, v))
	_atualizar_sala()

func _atualizar_sala() -> void:
	if _sala_info == null or not is_instance_valid(_sala_info):
		return
	var v := UI.vh(self)
	for f in _sala_info.get_children():
		f.queue_free()
	for c in Rede.codigos():
		var l := UI.rotulo("%s   %s" % [c[1], c[0]], 4.2 * v, UI.TEXTO, 900, 0.08 * 4.2 * v, true)
		_sala_info.add_child(l)
		_sala_info.add_child(_texto("IP %s · porta %d" % [c[2], Rede.PORTA], v))
	if Rede.ip_internet == "":
		var t := _texto("Internet: " + (Rede.internet_motivo if Rede.internet_motivo != "" else "…"), v)
		t.add_theme_color_override("font_color", UI.AMBAR)
		_sala_info.add_child(t)
	for f in _lista.get_children():
		f.queue_free()
	for id in Rede.jogadores:
		_lista.add_child(UI.rotulo("• " + Rede.nome_de(id) + (" (você, host)" if id == Rede.meu_id() else ""), 3.0 * v, UI.TEXTO, 700))

func _internet(_ok: bool, _ip_net: String, _motivo: String) -> void:
	_atualizar_sala()

func _mudou_sala(_id: int, _n := "") -> void:
	if _sala:
		_atualizar_sala()

# ---------- ações ----------
func _colar() -> void:
	var t := DisplayServer.clipboard_get().strip_edges()
	var re := RegEx.create_from_string("\\b[0-9A-Za-z]{5}-[0-9A-Za-z]{5}\\b")
	var m := re.search(t)
	_ip.text = m.get_string() if m != null else t.get_slice("\n", 0).left(120)
	if _ip.text != "":
		_entrar(_ip.text)
	else:
		_status.text = "A área de transferência está vazia: copie o convite antes."

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
	# sem resposta em 12 s: desiste (pela internet demora mais)
	await get_tree().create_timer(12.0).timeout
	if is_inside_tree() and _esperando and not Rede.ligado:
		Rede.sair()
		_falhou("Sem resposta de %s. O host criou a partida? De longe: o roteador dele abriu a porta (código \"Internet\")? Se não, usem o Tailscale (código \"VPN\")." % ip)

func _pronto() -> void:
	_esperando = false
	if Rede.eh_host():
		_sala = true                           # mostra os códigos; o host começa quando quiser
		_montar()
		return
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
	if _lista == null or _sala:
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
	if _sala:                                 # voltar da sala = cancelar a partida
		_sala = false
		Rede.sair()
		_montar()
		return
	if not Rede.ligado:
		Rede.sair()
	fechar.emit()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_sair()
