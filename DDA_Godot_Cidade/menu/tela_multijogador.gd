extends CanvasLayer
# TELA MULTIJOGADOR (botão "Multijogador" do menu principal), do jeito dos jogos de celular com SALA:
#   INÍCIO   -> dois botões grandes: CRIAR SALA e ENTRAR NUMA SALA (+ seu perfil e convites que chegaram)
#   SALA     -> 8 vagas com quem já entrou (ícone e nome). O HOST vê a lista de AMIGOS (online primeiro) com o
#               botão CHAMAR em cada um: o amigo recebe um aviso na tela (menu/aviso_chamado.gd) e, se aceitar,
#               aparece numa vaga. O host toca COMEÇAR e todo mundo vai para a cidade. Quem entrou espera na sala.
#               Para quem não é amigo: "Convidar por código" (copia uma mensagem para o WhatsApp).
#   ENTRAR   -> salas dos amigos (as que te chamaram primeiro), salas no mesmo Wi-Fi e entrar com código.
# A conexão: mesmo Wi-Fi (código) > internet com WebRTC (amigos) > códigos do roteador/VPN (rede/rede.gd).
# Mexa AQUI para: textos, layout e a ordem das telas do multijogador.

signal fechar
signal comecar                                # hora de ir para a cidade (main.gd abre o mundo livre)
signal abrir_perfil
signal pedir_login

const UI := preload("res://menu/ui.gd")
const AvatarCls := preload("res://menu/avatar.gd")
const CHAMADO_DURA := 30.0                    # segundos que o botão fica em "Chamado"

var modo := "inicio"                          # inicio · sala · entrar · conectando
var _raiz: Control
var _status: Label
var _ip: LineEdit
var _nome: LineEdit
var _achadas := {}                            # ip -> [nome, jogadores, tempo] (mesmo Wi-Fi)
var _esperando := false
var _reserva := ""                            # código para tentar se a conexão pela internet (WebRTC) falhar
var _destino := ""                            # nome do host da sala em que estou entrando
var _chamados := {}                           # uid do amigo -> {"t": segundos, "estado": "chamado"/"aceitou"/"recusou"}
var _fechar_confirma := false
var _t_amigos := 0.0
var _t_respostas := 0.0
var _t_convites := 0.0
var _t_tela := 0.0
var _sinais: Array = []

func _ready() -> void:
	layer = 30
	_sinais = [[Rede.pronto, _pronto], [Rede.falhou, _falhou], [Rede.caiu, _falhou], [Rede.partida_achada, _achou],
		[Rede.internet, _redesenhar], [Rede.jogador_entrou, _redesenhar], [Rede.jogador_saiu, _redesenhar], [Rede.comecou, _comecou],
		[Conta.mudou, _redesenhar], [Conta.convites_mudaram, _redesenhar], [Conta.amigos_atualizados, _redesenhar],
		[Conta.aviso, _aviso], [Conta.resposta, _resposta]]
	for s in _sinais:
		(s[0] as Signal).connect(s[1])
	Rede.procurar(true)
	if Rede.ligado:                           # aberta de dentro do jogo (pausa do host): já mostra a sala
		modo = "sala"
	get_viewport().size_changed.connect(_montar)
	_montar()
	Conta.atualizar_amigos()
	Conta.atualizar_convites()

func _exit_tree() -> void:
	Rede.procurar(false)
	for s in _sinais:
		if (s[0] as Signal).is_connected(s[1]):
			(s[0] as Signal).disconnect(s[1])

func _redesenhar(_a = null, _b = null, _c = null) -> void:
	_montar()

func _aviso(t: String) -> void:
	if _status != null:
		_status.text = t

# ======================================================================
func _montar() -> void:
	var st := _status.text if _status != null else ""
	var ip_antes := _ip.text if _ip != null and is_instance_valid(_ip) else str(Config.valor("ip_rede"))
	var nome_antes := _nome.text if _nome != null and is_instance_valid(_nome) else _meu_nome_salvo()
	if _raiz != null:
		_raiz.queue_free()
	_ip = null
	_nome = null
	var v := UI.vh(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.06, 0.025, 0.01, 0.985)
	_raiz.add_child(fundo)
	var titulos := {"inicio": "MULTIJOGADOR", "sala": "SALA", "entrar": "ENTRAR NUMA SALA", "conectando": "ENTRANDO"}
	var tit := UI.titulo_degrade(titulos[modo], 8.0 * v, 0.1 * 8.0 * v)
	tit.position = Vector2(6.0 * v, 3.0 * v)
	_raiz.add_child(tit)
	var rotulo_voltar := "Voltar"
	if modo == "sala":
		if Rede.partida_comecou:
			rotulo_voltar = "Voltar ao jogo"
		elif Rede.eh_host():
			rotulo_voltar = "Toque de novo" if _fechar_confirma else "Fechar sala"
		else:
			rotulo_voltar = "Sair da sala"
	elif modo == "conectando":
		rotulo_voltar = "Cancelar"
	var voltar := UI.BotaoMenu.new(rotulo_voltar, "", modo != "sala", 3.2, 20.0)
	voltar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	voltar.offset_left = -30.0 * v
	voltar.offset_right = -4.0 * v
	voltar.offset_top = 4.0 * v
	voltar.apertado.connect(_voltar)
	_raiz.add_child(voltar)
	var area := ScrollContainer.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.offset_left = 6.0 * v
	area.offset_right = -4.0 * v
	area.offset_top = 15.0 * v
	area.offset_bottom = -7.0 * v
	area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_raiz.add_child(area)
	_status = UI.rotulo(st, 2.6 * v, UI.AMBAR, 700)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_left = 6.0 * v
	_status.offset_right = -4.0 * v
	_status.offset_top = -6.5 * v
	_status.offset_bottom = -1.0 * v
	_raiz.add_child(_status)
	match modo:
		"inicio": _tela_inicio(area, v, nome_antes)
		"sala": _tela_sala(area, v)
		"entrar": _tela_entrar(area, v, ip_antes)
		"conectando": _tela_conectando(area, v)

# ---------------------------------------------------------------- INÍCIO
func _tela_inicio(area: Control, v: float, nome_antes: String) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(2.2 * v))
	area.add_child(col)
	# quem sou eu
	var eu := HBoxContainer.new()
	eu.add_theme_constant_override("separation", int(1.6 * v))
	col.add_child(eu)
	if Conta.logado:
		eu.add_child(AvatarCls.new(Conta.avatar, 8.0 * v))
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 0)
		c.add_child(UI.rotulo(Conta.nome, 3.4 * v, Color.WHITE, 900, 0.0, true))
		c.add_child(UI.rotulo("código de amigo %s · %d amigo(s)" % [Conta.codigo_amigo, Conta.amigos.size()], 2.4 * v, Color(1, 0.91, 0.82, 0.75), 400))
		eu.add_child(c)
		var bp := UI.BotaoMenu.new("Perfil e amigos", "", false, 2.8, 22.0)
		bp.apertado.connect(func(): abrir_perfil.emit())
		eu.add_child(bp)
	else:
		eu.add_child(UI.rotulo("Seu nome:", 3.0 * v, UI.TEXTO, 800))
		_nome = _campo(nome_antes, "Sobrevivente", v)
		_nome.max_length = 16
		eu.add_child(_nome)
		if Conta.configurado:
			var bl := UI.BotaoMenu.new("Entrar na conta", "para chamar amigos", true, 2.8, 24.0)
			bl.apertado.connect(func(): pedir_login.emit())
			eu.add_child(bl)
	# convites que chegaram (alguém me chamou há pouco)
	var agora := Time.get_unix_time_from_system() * 1000.0
	for c in Conta.convites:
		if float(c.get("chamou", 0)) > 0.0 and agora - float(c["chamou"]) < 120000.0:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", int(1.4 * v))
			h.add_child(AvatarCls.new(int(c.get("avatar", 0)), 7.0 * v))
			var t := UI.rotulo("%s te chamou para a sala (%d/%d)" % [c["nome"], int(c["n"]), Rede.MAX_JOGADORES], 3.0 * v, UI.AMBAR, 800)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(t)
			var be := UI.BotaoMenu.new("Entrar", "", true, 3.0, 14.0)
			be.apertado.connect(func(): entrar_na_sala(c))
			h.add_child(be)
			col.add_child(h)
	# os dois botões grandes
	var cartoes := HBoxContainer.new()
	cartoes.add_theme_constant_override("separation", int(3.0 * v))
	col.add_child(cartoes)
	var cc := _Cartao.new("+", "CRIAR SALA", "Você é o host. Chame seus amigos e comece quando quiser.", true)
	cc.custom_minimum_size = Vector2(0, 30.0 * v)
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.apertado.connect(_criar)
	cartoes.add_child(cc)
	var n_salas := Conta.convites.size() + _achadas.size()
	var ce := _Cartao.new(">", "ENTRAR NUMA SALA", ("%d sala(s) aberta(s) para você" % n_salas) if n_salas > 0 else "Salas dos amigos, mesmo Wi-Fi ou código.", false)
	ce.custom_minimum_size = Vector2(0, 30.0 * v)
	ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ce.apertado.connect(func():
		modo = "entrar"
		_montar())
	cartoes.add_child(ce)

# ---------------------------------------------------------------- SALA
func _tela_sala(area: Control, v: float) -> void:
	var linhas := HBoxContainer.new()
	linhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linhas.add_theme_constant_override("separation", int(5.0 * v))
	area.add_child(linhas)
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.size_flags_stretch_ratio = 1.15
	esq.add_theme_constant_override("separation", int(1.4 * v))
	linhas.add_child(esq)
	var host_nome := Rede.nome_de(1)
	esq.add_child(UI.rotulo("Sala de %s · %d/%d jogadores" % [host_nome, Rede.jogadores.size(), Rede.MAX_JOGADORES], 3.6 * v, Color.WHITE, 900, 0.0, true))
	# vagas
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", int(1.2 * v))
	g.add_theme_constant_override("v_separation", int(1.2 * v))
	esq.add_child(g)
	var ids: Array = Rede.jogadores.keys()
	ids.sort()
	for i in Rede.MAX_JOGADORES:
		g.add_child(_vaga(ids[i] if i < ids.size() else -1, v))
	# ações
	var acoes := HBoxContainer.new()
	acoes.add_theme_constant_override("separation", int(1.4 * v))
	esq.add_child(acoes)
	if Rede.eh_host():
		if Rede.partida_comecou:
			var bv := UI.BotaoMenu.new("Voltar ao jogo", "a partida continua", true, 3.8, 28.0)
			bv.apertado.connect(func(): fechar.emit())
			acoes.add_child(bv)
		else:
			var bc := UI.BotaoMenu.new("COMEÇAR", "todos vão para a cidade", true, 4.2, 28.0)
			bc.apertado.connect(func(): Rede.comecar_partida())
			acoes.add_child(bc)
		var bconv := UI.BotaoMenu.new("Convidar por código", "copia para o WhatsApp", false, 3.0, 26.0)
		bconv.apertado.connect(func():
			DisplayServer.clipboard_set(Rede.convite())
			_status.text = "Convite copiado! Cole no WhatsApp: quem não é seu amigo entra pelo código.")
		acoes.add_child(bconv)
		var cods: Array = Rede.codigos()
		var txt := ""
		if not cods.is_empty():
			txt = "Códigos da sala: " + " · ".join(cods.map(func(c): return "%s %s" % [c[0], c[1]]))
		if Rede.ip_internet == "" and Rede.internet_motivo != "" and not Rede.internet_motivo.ends_with("…"):
			txt += "\n(roteador: %s. Seus AMIGOS da conta entram pela internet mesmo assim.)" % Rede.internet_motivo
		esq.add_child(_texto(txt, v))
	else:
		esq.add_child(UI.rotulo("Esperando %s começar…" % host_nome, 3.4 * v, UI.AMBAR, 800))
		esq.add_child(_texto("Assim que o host tocar em COMEÇAR, todo mundo vai para a cidade junto.", v))
		return
	# direita (host): chamar amigos
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir.add_theme_constant_override("separation", int(1.0 * v))
	linhas.add_child(dir)
	dir.add_child(UI.rotulo("CHAMAR AMIGOS", 3.0 * v, UI.TITULO_SECAO, 900, 0.15 * 3.0 * v, true))
	if not Conta.logado:
		dir.add_child(_texto("Entre na sua conta para chamar amigos com um toque. Sem conta, use \"Convidar por código\".", v))
		if Conta.configurado:
			var bl := UI.BotaoMenu.new("Entrar na conta", "", true, 3.0, 20.0)
			bl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bl.apertado.connect(func(): pedir_login.emit())
			dir.add_child(bl)
		return
	if Conta.amigos.is_empty():
		dir.add_child(_texto("Você ainda não tem amigos na conta. Adicione pelo código de amigo no Perfil.", v))
		var bp := UI.BotaoMenu.new("Abrir Perfil", "", false, 3.0, 20.0)
		bp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bp.apertado.connect(func(): abrir_perfil.emit())
		dir.add_child(bp)
		return
	var na_sala := {}
	for id in Rede.jogadores:
		na_sala[str(Rede.jogadores[id].get("uid", ""))] = true
	for f in _amigos_ordenados():
		dir.add_child(_linha_chamar(f, na_sala.has(f), v))

func _vaga(id: int, v: float) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.157, 0.055, 0.016, 0.55) if id >= 0 else Color(1, 1, 1, 0.03)
	sb.border_color = Color("#ff8a35") if id == Rede.meu_id() else UI.BORDA
	sb.set_border_width_all(2 if id >= 0 else 1)
	sb.set_corner_radius_all(int(1.2 * v))
	sb.content_margin_left = 0.8 * v
	sb.content_margin_right = 0.8 * v
	sb.content_margin_top = 0.8 * v
	sb.content_margin_bottom = 0.8 * v
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(15.5 * v, 15.0 * v)
	var c := VBoxContainer.new()
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", int(0.3 * v))
	p.add_child(c)
	if id < 0:
		var l := UI.rotulo("vaga", 2.4 * v, Color(1, 1, 1, 0.3), 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(l)
		return p
	var a := AvatarCls.new(Rede.avatar_de(id), 7.0 * v)
	a.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(a)
	var n := UI.rotulo(Rede.nome_de(id), 2.3 * v, Color.WHITE, 800)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size.x = 13.5 * v
	c.add_child(n)
	var tag := "HOST" if id == 1 else ("você" if id == Rede.meu_id() else "")
	if tag != "":
		var t := UI.rotulo(tag, 1.9 * v, UI.AMBAR, 900)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(t)
	elif Rede.eh_host():
		var bt := UI.BotaoMenu.new("tirar", "", false, 1.9, 8.0)
		bt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bt.apertado.connect(func(): Rede.expulsar(id))
		c.add_child(bt)
	return p

func _linha_chamar(f: String, na_sala: bool, v: float) -> Control:
	var s: Dictionary = Conta.status_amigos.get(f, {})
	var st: Array = Conta.status_de(f)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(1.2 * v))
	var a := AvatarCls.new(int(s.get("avatar", Conta.amigos[f].get("avatar", 0))), 6.5 * v)
	a.online = int(st[0])
	h.add_child(a)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(UI.rotulo(str(s.get("nome", Conta.amigos[f].get("nome", "?"))), 2.9 * v, UI.TEXTO, 800))
	var t := _texto(str(st[1]), v)
	t.add_theme_color_override("font_color", [Color(1, 0.91, 0.82, 0.55), Color("#7be38f"), UI.AMBAR][int(st[0])])
	c.add_child(t)
	h.add_child(c)
	var ch: Dictionary = _chamados.get(f, {})
	var falta := CHAMADO_DURA - (Time.get_ticks_msec() / 1000.0 - float(ch.get("t", -999.0)))
	var rotulo := "Chamar"
	var sub := ""
	var ativo := true
	if na_sala:
		rotulo = "Na sala"
		ativo = false
	elif not bool(s.get("mutuo", true)):
		sub = "não aceitou ainda"
		ativo = false
	elif str(ch.get("estado", "")) == "aceitou":
		rotulo = "Entrando…"
		ativo = false
	elif str(ch.get("estado", "")) == "recusou":
		sub = "recusou"
	elif falta > 0.0:
		rotulo = "Chamado"
		sub = "%d s" % int(ceil(falta))
		ativo = false
	var b := UI.BotaoMenu.new(rotulo, sub, ativo and int(st[0]) > 0, 2.9, 16.0)
	if not ativo:
		b.modulate.a = 0.55
	else:
		b.apertado.connect(func(): _chamar(f))
	h.add_child(b)
	return h

func _chamar(f: String) -> void:
	_chamados[f] = {"t": Time.get_ticks_msec() / 1000.0, "estado": "chamado"}
	_montar()
	var nm := str(Conta.status_amigos.get(f, Conta.amigos.get(f, {})).get("nome", "?"))
	if await Conta.chamar(f):
		_status.text = "%s foi chamado. Esperando a resposta…" % nm
	else:
		_chamados.erase(f)
		_montar()

func _resposta(f: String, aceitou: bool) -> void:
	_chamados[f] = {"t": -999.0, "estado": "aceitou" if aceitou else "recusou"}
	var nm := str(Conta.status_amigos.get(f, Conta.amigos.get(f, {})).get("nome", "?"))
	_status.text = ("%s aceitou! Entrando na sala…" if aceitou else "%s recusou o convite.") % nm
	_montar()

func _amigos_ordenados() -> Array:
	var l: Array = Conta.amigos.keys()
	l.sort_custom(func(a, b):
		var pa := int(Conta.status_de(a)[0]) * 2 + (1 if Conta.status_amigos.get(a, {}).get("mutuo", false) else 0)
		var pb := int(Conta.status_de(b)[0]) * 2 + (1 if Conta.status_amigos.get(b, {}).get("mutuo", false) else 0)
		if pa != pb:
			return pa > pb
		return str(Conta.amigos[a].get("nome", "")) < str(Conta.amigos[b].get("nome", "")))
	return l

# ---------------------------------------------------------------- ENTRAR
func _tela_entrar(area: Control, v: float, ip_antes: String) -> void:
	var linhas := HBoxContainer.new()
	linhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linhas.add_theme_constant_override("separation", int(5.0 * v))
	area.add_child(linhas)
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.add_theme_constant_override("separation", int(1.2 * v))
	linhas.add_child(esq)
	_secao(esq, "SALAS DOS AMIGOS", v)
	if not Conta.logado:
		esq.add_child(_texto("Entre na sua conta para ver as salas dos seus amigos aqui.", v))
		if Conta.configurado:
			var bl := UI.BotaoMenu.new("Entrar na conta", "", true, 3.0, 20.0)
			bl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bl.apertado.connect(func(): pedir_login.emit())
			esq.add_child(bl)
	elif Conta.convites.is_empty():
		esq.add_child(_texto("Nenhum amigo com sala aberta agora. Quando alguém te CHAMAR, aparece um aviso na tela.", v))
	else:
		var lista: Array = Conta.convites.duplicate()
		lista.sort_custom(func(a, b): return float(a.get("chamou", 0)) > float(b.get("chamou", 0)))
		for c in lista:
			esq.add_child(_linha_sala(c, v))
	_secao(esq, "MESMO WI-FI", v)
	if _achadas.is_empty():
		esq.add_child(_texto("Procurando salas na mesma rede Wi-Fi…", v))
	for ip in _achadas:
		var a: Array = _achadas[ip]
		var b := UI.BotaoMenu.new("Sala de %s" % a[0], "%d/%d · mesmo Wi-Fi" % [a[1], Rede.MAX_JOGADORES], false, 3.0, 30.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.apertado.connect(func():
			_destino = str(a[0])
			_entrar(ip))
		esq.add_child(b)
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir.add_theme_constant_override("separation", int(1.2 * v))
	linhas.add_child(dir)
	_secao(dir, "COM CÓDIGO", v)
	dir.add_child(_texto("Recebeu um convite no WhatsApp? Copie a mensagem e toque em COLAR. Também vale o código (ex.: K7G2Q-0M4XA) ou IP.", v))
	_ip = _campo(ip_antes, "código, IP ou endereço", v)
	_ip.max_length = 120
	dir.add_child(_ip)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(1.4 * v))
	var be := UI.BotaoMenu.new("Entrar", "", true, 3.2, 16.0)
	be.apertado.connect(func():
		_destino = ""
		_entrar(_ip.text))
	hb.add_child(be)
	var bc := UI.BotaoMenu.new("Colar", "", false, 3.2, 14.0)
	bc.apertado.connect(_colar)
	hb.add_child(bc)
	dir.add_child(hb)

func _linha_sala(c: Dictionary, v: float) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(1.2 * v))
	h.add_child(AvatarCls.new(int(c.get("avatar", 0)), 7.0 * v))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UI.rotulo("Sala de %s" % c["nome"], 3.0 * v, Color.WHITE, 800))
	var agora := Time.get_unix_time_from_system() * 1000.0
	var sub := "%d/%d jogadores" % [int(c["n"]), Rede.MAX_JOGADORES] + (" · já começou" if bool(c.get("comecou", false)) else " · na sala")
	var chamou := float(c.get("chamou", 0)) > 0.0 and agora - float(c["chamou"]) < 120000.0
	if chamou:
		sub += " · te chamou!"
	var outra := str(c["versao"]) != Config.VERSAO
	if outra:
		sub = "versão %s: atualize o jogo" % c["versao"]
	var t := _texto(sub, v)
	if chamou and not outra:
		t.add_theme_color_override("font_color", UI.AMBAR)
	col.add_child(t)
	h.add_child(col)
	var b := UI.BotaoMenu.new("Entrar", "", not outra, 3.0, 14.0)
	if outra:
		b.modulate.a = 0.5
	else:
		b.apertado.connect(func(): entrar_na_sala(c))
	h.add_child(b)
	return h

# ---------------------------------------------------------------- CONECTANDO
func _tela_conectando(area: Control, v: float) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(1.6 * v))
	area.add_child(col)
	col.add_child(UI.rotulo(("Entrando na sala de %s…" % _destino) if _destino != "" else "Entrando na sala…", 4.4 * v, Color.WHITE, 900, 0.0, true))
	col.add_child(_texto("Conectando. Pela internet pode levar alguns segundos.", v, 2.8))

# ======================================================================
# entra na sala de um amigo (lista ENTRAR, aviso de convite aceito ou banner do início)
func entrar_na_sala(c: Dictionary) -> void:
	if _esperando:
		return
	_destino = str(c.get("nome", ""))
	modo = "conectando"
	_montar()
	var cods: Array = c.get("codigos", [])
	var meus := Rede.meus_ips()
	for k in cods:                            # mesmo Wi-Fi: direto pelo código
		var ip := str(k[2])
		for m in meus:
			if str(k[0]) == "Mesmo Wi-Fi" and ip.get_slice(".", 0) + "." + ip.get_slice(".", 1) + "." + ip.get_slice(".", 2) == m.get_slice(".", 0) + "." + m.get_slice(".", 1) + "." + m.get_slice(".", 2):
				_entrar(str(k[1]))
				return
	if bool(c.get("rtc", false)) and Conta.logado:   # internet com WebRTC
		_reserva = _codigo_de_longe(cods)
		_esperando = true
		Rede.entrar_amigo(str(c["uid"]), _meu_nome())
		return
	var cod := _codigo_de_longe(cods)
	if cod == "" and not cods.is_empty():
		cod = str(cods[0][1])
	if cod == "":
		_falhou("A sala de %s não mandou como entrar. Tente de novo em alguns segundos." % _destino)
		return
	_entrar(cod)

func _codigo_de_longe(cods: Array) -> String:
	var meus := Rede.meus_ips()
	var escolha := ""
	for k in cods:
		if str(k[0]).begins_with("VPN") and Array(meus).any(func(m): return m.begins_with("100.") or m.begins_with("10.147.")):
			escolha = str(k[1])
	if escolha == "":
		for k in cods:
			if str(k[0]) == "Internet":
				escolha = str(k[1])
	return escolha

func _criar() -> void:
	if _esperando:
		return
	_esperando = true
	_status.text = "Abrindo a sala…"
	Rede.criar_partida(_meu_nome(), randi())

func _entrar(ip: String) -> void:
	if _esperando:
		return
	ip = ip.strip_edges()
	if ip == "":
		_status.text = "Digite ou cole o código."
		return
	Config.definir("ip_rede", ip)
	_esperando = true
	modo = "conectando"
	_montar()
	Rede.entrar(ip, _meu_nome())
	await get_tree().create_timer(12.0).timeout
	if is_inside_tree() and _esperando and not Rede.ligado:
		Rede.sair()
		_falhou("Sem resposta da sala. O host ainda está com ela aberta? De longe, entrem pela conta (amigos) ou usem o Tailscale (código \"VPN\").")

func _colar() -> void:
	var t := DisplayServer.clipboard_get().strip_edges()
	var re := RegEx.create_from_string("\\b[0-9A-Za-z]{5}-[0-9A-Za-z]{5}\\b")
	var m := re.search(t)
	var cod := m.get_string() if m != null else t.get_slice("\n", 0).left(120)
	if _ip != null:
		_ip.text = cod
	if cod != "":
		_destino = ""
		_entrar(cod)
	else:
		_status.text = "A área de transferência está vazia: copie o convite antes."

func _meu_nome_salvo() -> String:
	return Conta.nome if Conta.logado else str(Config.valor("nome_rede"))

func _meu_nome() -> String:
	if not Conta.logado and _nome != null and is_instance_valid(_nome) and _nome.text.strip_edges() != "":
		Config.definir("nome_rede", _nome.text.strip_edges())
	return _meu_nome_salvo()

# ---------------------------------------------------------------- respostas da rede
func _pronto() -> void:
	_esperando = false
	_reserva = ""
	_fechar_confirma = false
	if Rede.partida_comecou:                  # entrou numa partida que já começou: direto para a cidade
		comecar.emit()
		return
	modo = "sala"
	_status.text = "Sala criada! Chame seus amigos." if Rede.eh_host() else ""
	Conta.atualizar_amigos()
	_montar()

func _comecou() -> void:
	comecar.emit()

func _falhou(motivo: String) -> void:
	_esperando = false
	if _reserva != "":                         # o WebRTC não passou: tenta o código do host
		var r := _reserva
		_reserva = ""
		_entrar(r)
		return
	if modo in ["sala", "conectando"]:
		modo = "inicio"
	_montar()
	if _status != null:
		_status.text = motivo

func _achou(ip: String, nome: String, n: int) -> void:
	var novo := not _achadas.has(ip)
	_achadas[ip] = [nome, n, Time.get_ticks_msec()]
	if novo and modo in ["entrar", "inicio"]:
		_montar()

func _process(dt: float) -> void:
	var agora := Time.get_ticks_msec()
	var mudou := false
	for ip in _achadas.keys():
		if agora - int(_achadas[ip][2]) > 5000:
			_achadas.erase(ip)
			mudou = true
	if mudou and modo in ["entrar", "inicio"]:
		_montar()
	if not Conta.logado:
		return
	_t_amigos -= dt
	if _t_amigos <= 0.0:
		_t_amigos = 15.0
		Conta.atualizar_amigos()
	if modo in ["entrar", "inicio"]:
		_t_convites -= dt
		if _t_convites <= 0.0:
			_t_convites = 6.0
			Conta.atualizar_convites()
	if modo == "sala" and Rede.eh_host():
		_t_respostas -= dt
		if _t_respostas <= 0.0:
			_t_respostas = 3.0
			Conta.ler_respostas()
		# o contador dos botões "Chamado 23 s" anda sozinho
		_t_tela -= dt
		if _t_tela <= 0.0 and _chamados.values().any(func(c): return c["estado"] == "chamado"):
			_t_tela = 1.0
			_montar()

func _voltar() -> void:
	match modo:
		"sala":
			if Rede.partida_comecou:
				fechar.emit()                 # host voltando ao jogo
			elif Rede.eh_host() and not _fechar_confirma:
				_fechar_confirma = true
				_montar()
			else:
				Rede.sair()
				modo = "inicio"
				_fechar_confirma = false
				_status.text = ""
				_montar()
		"entrar":
			modo = "inicio"
			_montar()
		"conectando":
			_esperando = false
			_reserva = ""
			Rede.sair()
			modo = "inicio"
			_montar()
		_:
			if not Rede.ligado:
				Rede.sair()
			fechar.emit()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_voltar()

# main.gd chama _sair() no botão Voltar do Android
func _sair() -> void:
	_voltar()

# ---------------------------------------------------------------- ajudantes
func _secao(col: Container, txt: String, v: float) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(1.4 * v))
	m.add_child(UI.rotulo(txt, 3.0 * v, UI.TITULO_SECAO, 900, 0.15 * 3.0 * v, true))
	col.add_child(m)

func _texto(t: String, v: float, tam := 2.4) -> Label:
	var l := UI.rotulo(t, tam * v, Color(1, 0.91, 0.82, 0.75), 400)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _campo(txt: String, dica: String, v: float) -> LineEdit:
	var e := LineEdit.new()
	e.text = txt
	e.placeholder_text = dica
	e.max_length = 40
	e.custom_minimum_size = Vector2(36.0 * v, 6.5 * v)
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

# botão GRANDE do início (CRIAR SALA / ENTRAR): símbolo, título e explicação
class _Cartao extends Control:
	signal apertado
	const UIc := preload("res://menu/ui.gd")
	var simbolo := ""
	var titulo := ""
	var texto := ""
	var primario := false
	var _aperto := false
	func _init(s: String, t: String, x: String, p: bool) -> void:
		simbolo = s
		titulo = t
		texto = x
		primario = p
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_aperto = true
			elif _aperto:
				_aperto = false
				if Rect2(Vector2.ZERO, size).has_point(e.position):
					apertado.emit()
			queue_redraw()
			accept_event()
	func _draw() -> void:
		var v: float = UIc.vh(self)
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.85, 0.32, 0.06, 0.92) if primario else Color(0.157, 0.055, 0.016, 0.75)
		sb.border_color = Color("#ffe2b0") if primario else Color(1.0, 0.667, 0.353, 0.55)
		sb.set_border_width_all(int(maxf(2.0, 0.3 * v)))
		sb.set_corner_radius_all(int(1.6 * v))
		draw_style_box(sb, r)
		if _aperto:
			draw_rect(r.grow(-2), Color(1, 1, 1, 0.12))
		var c := Vector2(size.x * 0.5, size.y * 0.32)
		var rr := size.y * 0.16
		draw_circle(c, rr, Color(1, 1, 1, 0.16))
		var w := maxf(3.0, rr * 0.16)
		if simbolo == "+":
			draw_line(c - Vector2(rr * 0.5, 0), c + Vector2(rr * 0.5, 0), Color.WHITE, w)
			draw_line(c - Vector2(0, rr * 0.5), c + Vector2(0, rr * 0.5), Color.WHITE, w)
		else:
			draw_line(c - Vector2(rr * 0.45, 0), c + Vector2(rr * 0.45, 0), Color.WHITE, w)
			draw_line(c + Vector2(rr * 0.45, 0), c + Vector2(rr * 0.08, -rr * 0.37), Color.WHITE, w)
			draw_line(c + Vector2(rr * 0.45, 0), c + Vector2(rr * 0.08, rr * 0.37), Color.WHITE, w)
		var ft: Font = UIc.fonte(900)
		var tt := int(4.2 * v)
		var ws := ft.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tt).x
		draw_string(ft, Vector2((size.x - ws) * 0.5, size.y * 0.66), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tt, Color.WHITE)
		var f2: Font = UIc.fonte(400, 0.0, false)
		draw_multiline_string(f2, Vector2(size.x * 0.08, size.y * 0.79), texto, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.84, int(2.4 * v), 3, Color(1, 0.95, 0.88, 0.88))
