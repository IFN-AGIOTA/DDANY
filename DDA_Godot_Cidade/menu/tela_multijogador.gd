extends CanvasLayer
# TELA MULTIJOGADOR (botão "Multijogador" do menu principal): seu nome, CRIAR PARTIDA, PARTIDAS NA REDE (achadas
# sozinhas no mesmo Wi-Fi) e ENTRAR (código, convite colado, IP, IP:porta ou endereço:porta).
# Criando a partida abre a SALA: os CÓDIGOS (internet, VPN, Wi-Fi), COPIAR CONVITE (para mandar no WhatsApp),
# quem já entrou e COMEÇAR A JOGAR. Quem entra começa assim que o host aceita.
# CONTA (rede/conta.gd, Firebase): entrar com GOOGLE ou como convidado, seu CÓDIGO DE AMIGO, adicionar amigos e
# PARTIDAS DOS AMIGOS (aparecem sozinhas: é só tocar para entrar).
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
var _conta_box: VBoxContainer                 # login / perfil
var _amigos_box: VBoxContainer                # lista de amigos + adicionar
var _partidas_amigos: VBoxContainer
var _cod_amigo: LineEdit
var _login_codigo := ""
var _login_site := ""
var _t_convites := 0.0

func _ready() -> void:
	layer = 30
	Rede.pronto.connect(_pronto)
	Rede.falhou.connect(_falhou)
	Rede.partida_achada.connect(_achou)
	Rede.internet.connect(_internet)
	Rede.jogador_entrou.connect(_mudou_sala)
	Rede.jogador_saiu.connect(_mudou_sala)
	Conta.mudou.connect(_conta_mudou)
	Conta.login_codigo.connect(_conta_codigo)
	Conta.login_erro.connect(_conta_erro)
	Conta.aviso.connect(_conta_aviso)
	Conta.convites_mudaram.connect(_convites)
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
	Conta.mudou.disconnect(_conta_mudou)
	Conta.login_codigo.disconnect(_conta_codigo)
	Conta.login_erro.disconnect(_conta_erro)
	Conta.aviso.disconnect(_conta_aviso)
	Conta.convites_mudaram.disconnect(_convites)

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
	# coluna da direita: conta, partidas dos amigos, partidas na rede local, amigos
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir.add_theme_constant_override("separation", int(1.2 * v))
	linhas.add_child(dir)
	_status = _texto("", v)
	_status.add_theme_color_override("font_color", UI.AMBAR)
	dir.add_child(_status)
	_secao(dir, "CONTA", v)
	_conta_box = VBoxContainer.new()
	_conta_box.add_theme_constant_override("separation", int(1.0 * v))
	dir.add_child(_conta_box)
	_secao(dir, "PARTIDAS DOS AMIGOS", v)
	_partidas_amigos = VBoxContainer.new()
	_partidas_amigos.add_theme_constant_override("separation", int(1.0 * v))
	dir.add_child(_partidas_amigos)
	_secao(dir, "PARTIDAS NA REDE (WI-FI)", v)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", int(1.0 * v))
	dir.add_child(_lista)
	_amigos_box = VBoxContainer.new()
	_amigos_box.add_theme_constant_override("separation", int(1.0 * v))
	dir.add_child(_amigos_box)
	_atualizar_lista()
	_montar_conta()
	_convites(Conta.convites)

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
	if Conta.logado:
		var ta := _texto("Seus AMIGOS da conta já veem esta partida na lista deles (é só tocar para entrar).", v)
		ta.add_theme_color_override("font_color", UI.AMBAR)
		dir.add_child(ta)
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

# ---------- CONTA (rede/conta.gd) ----------
func _montar_conta() -> void:
	if _conta_box == null or not is_instance_valid(_conta_box):
		return
	var v := UI.vh(self)
	for f in _conta_box.get_children():
		f.queue_free()
	for f in _amigos_box.get_children():
		f.queue_free()
	if not Conta.configurado:
		_conta_box.add_child(_texto("Login com Google e amigos: falta configurar o Firebase (rede/firebase_config.cfg, passo a passo no LEIA-ME). O resto do multijogador funciona sem conta.", v))
		return
	if Conta.entrando and _login_codigo != "":
		_conta_box.add_child(_texto("Abra o site abaixo (neste celular ou em qualquer outro aparelho), digite o código e escolha sua conta Google:", v))
		_conta_box.add_child(UI.rotulo(_login_codigo, 6.0 * v, UI.TEXTO, 900, 0.12 * 6.0 * v, true))
		_conta_box.add_child(_texto(_login_site, v))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(1.4 * v))
		var ba := UI.BotaoMenu.new("Abrir o site", "o código já vai copiado", true, 3.2, 22.0)
		ba.apertado.connect(func():
			DisplayServer.clipboard_set(_login_codigo)
			OS.shell_open(_login_site))
		h.add_child(ba)
		var bx := UI.BotaoMenu.new("Cancelar", "", false, 3.2, 16.0)
		bx.apertado.connect(func():
			_login_codigo = ""
			Conta.cancelar_login())
		h.add_child(bx)
		_conta_box.add_child(h)
		_conta_box.add_child(_texto("Esperando você confirmar no site…", v))
		return
	if Conta.entrando:
		_conta_box.add_child(_texto("Entrando…", v))
		return
	if not Conta.logado:
		_conta_box.add_child(_texto("Entre para ter AMIGOS: as partidas deles aparecem aqui sozinhas, sem precisar de código.", v))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(1.4 * v))
		if Conta.google_disponivel():
			var bg := UI.BotaoMenu.new("Entrar com Google", "conta Google", true, 3.2, 24.0)
			bg.apertado.connect(func(): Conta.entrar_google())
			h.add_child(bg)
		var bv := UI.BotaoMenu.new("Convidado", "sem Google", false, 3.2, 18.0)
		bv.apertado.connect(func(): Conta.entrar_convidado())
		h.add_child(bv)
		_conta_box.add_child(h)
		return
	var quem := Conta.nome + ("  ·  " + Conta.email if Conta.email != "" else ("  ·  convidado" if Conta.tipo == "convidado" else ""))
	_conta_box.add_child(UI.rotulo(quem, 3.0 * v, UI.TEXTO, 800))
	var hc := HBoxContainer.new()
	hc.add_theme_constant_override("separation", int(1.4 * v))
	hc.add_child(UI.rotulo("Seu código de amigo: %s" % Conta.codigo_amigo, 3.0 * v, UI.AMBAR, 900, 0.0, true))
	var bcop := UI.BotaoMenu.new("Copiar", "", false, 2.6, 12.0)
	bcop.apertado.connect(func():
		DisplayServer.clipboard_set("Me adiciona no Dias de um Apocalipse! Meu código de amigo: %s" % Conta.codigo_amigo)
		_status.text = "Código de amigo copiado.")
	hc.add_child(bcop)
	var bsair := UI.BotaoMenu.new("Sair da conta", "", false, 2.6, 18.0)
	bsair.apertado.connect(func(): Conta.sair_da_conta())
	hc.add_child(bsair)
	_conta_box.add_child(hc)
	# amigos
	_secao(_amigos_box, "AMIGOS", v)
	_amigos_box.add_child(_texto("Os dois precisam adicionar o código um do outro para verem as partidas.", v))
	var ha := HBoxContainer.new()
	ha.add_theme_constant_override("separation", int(1.4 * v))
	_cod_amigo = _campo("", "código do amigo", v)
	_cod_amigo.custom_minimum_size.x = 24.0 * v
	_cod_amigo.max_length = 10
	ha.add_child(_cod_amigo)
	var badd := UI.BotaoMenu.new("Adicionar", "", false, 3.0, 16.0)
	badd.apertado.connect(func(): Conta.adicionar_amigo(_cod_amigo.text))
	ha.add_child(badd)
	_amigos_box.add_child(ha)
	for outro in Conta.amigos:
		var a: Dictionary = Conta.amigos[outro]
		var hl := HBoxContainer.new()
		hl.add_theme_constant_override("separation", int(1.4 * v))
		hl.add_child(UI.rotulo("• %s  (%s)" % [a.get("nome", "?"), a.get("codigo", "")], 2.8 * v, UI.TEXTO, 700))
		var brm := UI.BotaoMenu.new("Remover", "", false, 2.2, 10.0)
		brm.apertado.connect(func(): Conta.remover_amigo(outro))
		hl.add_child(brm)
		_amigos_box.add_child(hl)

func _conta_mudou() -> void:
	if not Conta.entrando:
		_login_codigo = ""
	if Conta.logado and _nome != null and (_nome.text == "" or _nome.text == "Sobrevivente"):
		_nome.text = Conta.nome
	_montar_conta()

func _conta_codigo(codigo: String, site: String) -> void:
	_login_codigo = codigo
	_login_site = site
	_montar_conta()

func _conta_erro(motivo: String) -> void:
	_login_codigo = ""
	if _status != null:
		_status.text = motivo
	_montar_conta()

func _conta_aviso(t: String) -> void:
	if _status != null:
		_status.text = t

func _convites(lista: Array) -> void:
	if _partidas_amigos == null or not is_instance_valid(_partidas_amigos):
		return
	var v := UI.vh(self)
	for f in _partidas_amigos.get_children():
		f.queue_free()
	if not Conta.logado:
		_partidas_amigos.add_child(_texto("Entre na conta (acima) para ver as partidas dos seus amigos.", v))
		return
	if lista.is_empty():
		_partidas_amigos.add_child(_texto("Nenhum amigo com partida aberta agora.", v))
		return
	for c in lista:
		var outra_versao: bool = str(c["versao"]) != Config.VERSAO
		var b := UI.BotaoMenu.new("Partida de %s" % c["nome"], ("versão %s: atualize o jogo" % c["versao"]) if outra_versao else "%d jogador(es) · tocar para entrar" % c["n"], not outra_versao, 3.2, 34.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.apertado.connect(func(): _entrar_amigo(c))
		_partidas_amigos.add_child(b)

# ordem: MESMO WI-FI (código) > INTERNET COM WEBRTC (sem abrir porta) > VPN > código "Internet" do roteador
func _entrar_amigo(c: Dictionary) -> void:
	if _esperando:
		return
	var cods: Array = c.get("codigos", [])
	var meus := Rede.meus_ips()
	var mesmo_wifi := ""
	for k in cods:
		var ip := str(k[2])
		for m in meus:
			if str(k[0]) == "Mesmo Wi-Fi" and ip.get_slice(".", 0) + "." + ip.get_slice(".", 1) + "." + ip.get_slice(".", 2) == m.get_slice(".", 0) + "." + m.get_slice(".", 1) + "." + m.get_slice(".", 2):
				mesmo_wifi = str(k[1])
	if mesmo_wifi != "":
		_entrar(mesmo_wifi)
		return
	if bool(c.get("rtc", false)):
		_reserva = _codigo_de_longe(cods)     # se o WebRTC falhar, tenta o código
		_esperando = true
		_status.text = "Conectando pela internet com %s…" % c["nome"]
		Rede.entrar_amigo(str(c["uid"]), _meu_nome())
		return
	if cods.is_empty():
		_status.text = "A partida de %s não mandou códigos (tente de novo em alguns segundos)." % c["nome"]
		return
	_entrar(_codigo_de_longe(cods) if _codigo_de_longe(cods) != "" else str(cods[0][1]))

var _reserva := ""                            # código para tentar se a conexão pela internet (WebRTC) falhar

func _codigo_de_longe(cods: Array) -> String:
	var meus := Rede.meus_ips()
	var escolha := ""
	for k in cods:
		var ip := str(k[2])
		for m in meus:
			if ip.get_slice(".", 0) + "." + ip.get_slice(".", 1) + "." + ip.get_slice(".", 2) == m.get_slice(".", 0) + "." + m.get_slice(".", 1) + "." + m.get_slice(".", 2):
				escolha = str(k[1])
	if escolha == "":
		for k in cods:
			if str(k[0]).begins_with("VPN") and meus.size() > 0 and Array(meus).any(func(m): return m.begins_with("100.") or m.begins_with("10.147.")):
				escolha = str(k[1])
	if escolha == "":
		for k in cods:
			if str(k[0]) == "Internet":
				escolha = str(k[1])
	return escolha

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
	Conta.definir_nome(_nome.text)
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
	_reserva = ""
	if Rede.eh_host():
		_sala = true                           # mostra os códigos; o host começa quando quiser
		_montar()
		return
	comecar.emit()

func _falhou(motivo: String) -> void:
	_esperando = false
	if _reserva != "":                         # o WebRTC não passou: tenta o código do host
		var r := _reserva
		_reserva = ""
		_entrar(r)
		return
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
		_lista.add_child(_texto("Procurando partidas no mesmo Wi-Fi…\nSe não aparecer, peça o convite ao host e use ENTRAR.", v))
		return
	for ip in _achadas:
		var a: Array = _achadas[ip]
		var b := UI.BotaoMenu.new("Partida de %s" % a[0], "%s · %d jogador(es)" % [ip, a[1]], false, 3.2, 34.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.apertado.connect(func(): _entrar(ip))
		_lista.add_child(b)

func _process(dt: float) -> void:
	# partidas dos amigos: pergunta de novo a cada 8 s enquanto esta tela está aberta
	if Conta.logado and not _sala:
		_t_convites -= dt
		if _t_convites <= 0.0:
			_t_convites = 8.0
			Conta.atualizar_convites()
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
