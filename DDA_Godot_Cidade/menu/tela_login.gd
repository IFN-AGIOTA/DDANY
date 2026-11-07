extends CanvasLayer
# TELA DE LOGIN AO ABRIR O JOGO (por cima do menu principal): "ENTRAR COM GOOGLE", "CONVIDADO" ou "AGORA NÃO".
# Aparece uma vez por abertura do jogo, só se o Firebase estiver configurado (rede/conta.gd) e a pessoa ainda não
# tiver entrado. Quem já entrou antes volta logado sozinho: a tela nem aparece (o menu só diz "Olá, Fulano").
# O login com Google é "por código" (google.com/device), como no Multijogador.
# Mexa AQUI para: textos e layout da tela de login.

signal fechar

const UI := preload("res://menu/ui.gd")

var _raiz: Control
var _caixa: VBoxContainer
var _status: Label
var _codigo := ""
var _site := ""

func _ready() -> void:
	layer = 40
	Conta.mudou.connect(_mudou)
	Conta.login_codigo.connect(_recebeu_codigo)
	Conta.login_erro.connect(_erro)
	get_viewport().size_changed.connect(_montar)
	_montar()

func _exit_tree() -> void:
	Conta.mudou.disconnect(_mudou)
	Conta.login_codigo.disconnect(_recebeu_codigo)
	Conta.login_erro.disconnect(_erro)

func _montar() -> void:
	var status_antes := _status.text if _status != null else ""
	if _raiz != null:
		_raiz.queue_free()
	var v := UI.vh(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.06, 0.025, 0.01, 0.96)
	_raiz.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(centro)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 90.0 * v
	col.add_theme_constant_override("separation", int(1.6 * v))
	centro.add_child(col)
	col.add_child(UI.titulo_degrade("ENTRAR", 8.0 * v, 0.1 * 8.0 * v))
	_caixa = VBoxContainer.new()
	_caixa.add_theme_constant_override("separation", int(1.4 * v))
	col.add_child(_caixa)
	_status = _texto(status_antes, v)
	_status.add_theme_color_override("font_color", UI.AMBAR)
	col.add_child(_status)
	_preencher()

func _preencher() -> void:
	var v := UI.vh(self)
	for f in _caixa.get_children():
		f.queue_free()
	if Conta.entrando and _codigo != "":
		_caixa.add_child(_texto("1) Toque em ABRIR O SITE (o código já vai copiado).\n2) Cole o código e escolha sua conta Google.\n3) Volte para o jogo: ele entra sozinho.", v))
		_caixa.add_child(UI.rotulo(_codigo, 7.0 * v, UI.TEXTO, 900, 0.12 * 7.0 * v, true))
		_caixa.add_child(_texto(_site, v))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(1.4 * v))
		var ba := UI.BotaoMenu.new("Abrir o site", "google.com/device", true, 3.6, 26.0)
		ba.apertado.connect(func():
			DisplayServer.clipboard_set(_codigo)
			OS.shell_open(_site))
		h.add_child(ba)
		var bx := UI.BotaoMenu.new("Voltar", "", false, 3.6, 16.0)
		bx.apertado.connect(func():
			_codigo = ""
			Conta.cancelar_login())
		h.add_child(bx)
		_caixa.add_child(h)
		_caixa.add_child(_texto("Esperando você confirmar no site…", v))
		return
	if Conta.entrando:
		_caixa.add_child(_texto("Entrando na sua conta…", v))
		return
	_caixa.add_child(_texto("Entre com sua conta para ter AMIGOS e ver as partidas deles no Multijogador. Você só precisa fazer isso uma vez neste aparelho.", v))
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", int(1.2 * v))
	if Conta.google_disponivel():
		var bg := UI.BotaoMenu.new("Entrar com Google", "sua conta Google", true, 4.0, 40.0)
		bg.apertado.connect(func():
			_status.text = ""
			Conta.entrar_google())
		b.add_child(bg)
	var bc := UI.BotaoMenu.new("Jogar como convidado", "sem Google · dá para trocar depois", not Conta.google_disponivel(), 3.4, 40.0)
	bc.apertado.connect(func():
		_status.text = ""
		Conta.entrar_convidado())
	b.add_child(bc)
	var bn := UI.BotaoMenu.new("Agora não", "entrar depois em Multijogador", false, 3.0, 40.0)
	bn.apertado.connect(_sair)
	b.add_child(bn)
	_caixa.add_child(b)

func _texto(t: String, v: float) -> Label:
	var l := UI.rotulo(t, 2.6 * v, Color(1, 0.91, 0.82, 0.8), 400)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _mudou() -> void:
	if Conta.logado:
		_sair()
		return
	if not Conta.entrando:
		_codigo = ""
	_preencher()

func _recebeu_codigo(codigo: String, site: String) -> void:
	_codigo = codigo
	_site = site
	_preencher()

func _erro(motivo: String) -> void:
	_codigo = ""
	_status.text = motivo
	_preencher()

func _sair() -> void:
	fechar.emit()
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if Conta.entrando:
			_codigo = ""
			Conta.cancelar_login()
		else:
			_sair()
