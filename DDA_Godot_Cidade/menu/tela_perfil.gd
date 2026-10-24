extends CanvasLayer
# PERFIL DO JOGADOR (ícone no canto do menu principal): ícone (toque para trocar), nome, CÓDIGO DE AMIGO (copiar),
# conta (Google/convidado), RECORDES (melhor tempo vivo, mais abates), PEDIDOS DE AMIZADE (aceitar/recusar),
# AMIGOS (online/jogando/visto há…, recorde, remover) e ADICIONAR AMIGO pelo código.
# Dados: rede/conta.gd (Firebase). Sem conta: mostra o botão para entrar (main.gd abre a tela de login).
# Mexa AQUI para: layout e textos do perfil.

signal fechar
signal pedir_login

const UI := preload("res://menu/ui.gd")
const AvatarCls := preload("res://menu/avatar.gd")

var _raiz: Control
var _status: Label
var _cod: LineEdit
var _nome: LineEdit
var _escolhendo := false
var _remover := ""                            # uid do amigo aguardando o 2º toque em "Remover"
var _t := 0.0

func _ready() -> void:
	layer = 32
	for s in [[Conta.mudou, _remontar], [Conta.pedidos_mudaram, _remontar], [Conta.amigos_atualizados, _remontar], [Conta.aviso, _aviso]]:
		(s[0] as Signal).connect(s[1])
	get_viewport().size_changed.connect(_montar)
	_montar()
	Conta.atualizar_amigos()
	Conta.atualizar_pedidos()

func _exit_tree() -> void:
	for s in [[Conta.mudou, _remontar], [Conta.pedidos_mudaram, _remontar], [Conta.amigos_atualizados, _remontar], [Conta.aviso, _aviso]]:
		if (s[0] as Signal).is_connected(s[1]):
			(s[0] as Signal).disconnect(s[1])

func _process(dt: float) -> void:
	_t += dt
	if _t > 20.0:                             # status dos amigos de 20 em 20 s
		_t = 0.0
		Conta.atualizar_amigos()
		Conta.atualizar_pedidos()

func _remontar(_a = null) -> void:
	_montar()

func _aviso(t: String) -> void:
	if _status != null:
		_status.text = t

func _montar() -> void:
	var st := _status.text if _status != null else ""
	var cod_antes := _cod.text if _cod != null and is_instance_valid(_cod) else ""     # não perde o que estava digitando
	var nome_antes := _nome.text if _nome != null and is_instance_valid(_nome) else Conta.nome
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
	var tit := UI.titulo_degrade("PERFIL", 9.0 * v, 0.1 * 9.0 * v)
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
	if not Conta.logado:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", int(1.6 * v))
		rolar.add_child(c)
		c.add_child(_texto("Você ainda não entrou numa conta. Com a conta você tem um CÓDIGO DE AMIGO, salva seus recordes e pode chamar os amigos para jogar.", v, 3.0))
		var b := UI.BotaoMenu.new("Entrar na conta", "Google ou convidado", true, 3.8, 34.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.apertado.connect(func(): pedir_login.emit())
		c.add_child(b)
		if not Conta.configurado:
			c.add_child(_texto("(Contas ainda não configuradas neste APK.)", v))
		return
	var linhas := HBoxContainer.new()
	linhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linhas.add_theme_constant_override("separation", int(6.0 * v))
	rolar.add_child(linhas)
	# ---- esquerda: eu
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.add_theme_constant_override("separation", int(1.2 * v))
	linhas.add_child(esq)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", int(2.4 * v))
	esq.add_child(topo)
	var av := AvatarCls.new(Conta.avatar, 16.0 * v)
	av.mouse_filter = Control.MOUSE_FILTER_STOP
	av.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_escolhendo = not _escolhendo
			_montar())
	topo.add_child(av)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", int(0.6 * v))
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_child(info)
	info.add_child(UI.rotulo(Conta.nome, 5.0 * v, Color.WHITE, 900, 0.0, true))
	info.add_child(_texto(("Google · " + Conta.email) if Conta.tipo == "google" else "Convidado (sem Google)", v))
	info.add_child(_texto("toque no ícone para trocar", v))
	if _escolhendo:
		var g := GridContainer.new()
		g.columns = 6
		g.add_theme_constant_override("h_separation", int(1.2 * v))
		g.add_theme_constant_override("v_separation", int(1.2 * v))
		for i in AvatarCls.ICONES.size():
			var a := AvatarCls.new(i, 9.0 * v)
			a.selecionado = i == Conta.avatar
			a.mouse_filter = Control.MOUSE_FILTER_STOP
			a.gui_input.connect(func(e):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					_escolhendo = false
					Conta.definir_avatar(i))
			g.add_child(a)
		esq.add_child(g)
	_secao(esq, "NOME", v)
	var hn := HBoxContainer.new()
	hn.add_theme_constant_override("separation", int(1.2 * v))
	_nome = _campo(nome_antes, "seu nome", v)
	_nome.max_length = 16
	hn.add_child(_nome)
	var bs := UI.BotaoMenu.new("Salvar", "", false, 3.0, 14.0)
	bs.apertado.connect(func():
		Config.definir("nome_rede", _nome.text.strip_edges())
		Conta.definir_nome(_nome.text))
	hn.add_child(bs)
	esq.add_child(hn)
	_secao(esq, "SEU CÓDIGO DE AMIGO", v)
	var hc := HBoxContainer.new()
	hc.add_theme_constant_override("separation", int(1.6 * v))
	hc.add_child(UI.rotulo(Conta.codigo_amigo, 6.0 * v, UI.AMBAR, 900, 0.15 * 6.0 * v, true))
	var bcop := UI.BotaoMenu.new("Copiar", "para mandar no WhatsApp", false, 3.0, 20.0)
	bcop.apertado.connect(func():
		DisplayServer.clipboard_set("Me adiciona no Dias de um Apocalipse! Meu código de amigo: %s" % Conta.codigo_amigo)
		_status.text = "Código copiado.")
	hc.add_child(bcop)
	esq.add_child(hc)
	_secao(esq, "RECORDES", v)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", int(4.0 * v))
	hr.add_child(_cartao(_tempo(Conta.recorde_tempo), "melhor tempo vivo", v))
	hr.add_child(_cartao(str(Conta.recorde_abates), "mais abates numa vida", v))
	esq.add_child(hr)
	var bsair := UI.BotaoMenu.new("Sair da conta", "", false, 2.6, 18.0)
	bsair.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bsair.apertado.connect(func(): Conta.sair_da_conta())
	esq.add_child(bsair)
	# ---- direita: pedidos, amigos, adicionar
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir.add_theme_constant_override("separation", int(1.0 * v))
	linhas.add_child(dir)
	_status = _texto(st, v)
	_status.add_theme_color_override("font_color", UI.AMBAR)
	dir.add_child(_status)
	if not Conta.pedidos.is_empty():
		_secao(dir, "PEDIDOS DE AMIZADE (%d)" % Conta.pedidos.size(), v)
		for de in Conta.pedidos:
			var p: Dictionary = Conta.pedidos[de]
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", int(1.2 * v))
			h.add_child(AvatarCls.new(int(p["avatar"]), 7.0 * v))
			var n := UI.rotulo(str(p["nome"]), 3.0 * v, UI.TEXTO, 800)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n)
			var ba := UI.BotaoMenu.new("Aceitar", "", true, 2.8, 14.0)
			ba.apertado.connect(func(): Conta.aceitar_pedido(de))
			h.add_child(ba)
			var br := UI.BotaoMenu.new("Recusar", "", false, 2.8, 14.0)
			br.apertado.connect(func(): Conta.recusar_pedido(de))
			h.add_child(br)
			dir.add_child(h)
	_secao(dir, "AMIGOS (%d)" % Conta.amigos.size(), v)
	if Conta.amigos.is_empty():
		dir.add_child(_texto("Ninguém ainda. Adicione pelo código de amigo abaixo e mande o seu para eles.", v))
	for f in _amigos_ordenados():
		dir.add_child(_linha_amigo(f, v))
	_secao(dir, "ADICIONAR AMIGO", v)
	var ha := HBoxContainer.new()
	ha.add_theme_constant_override("separation", int(1.2 * v))
	_cod = _campo(cod_antes, "código (6 letras)", v)
	_cod.max_length = 10
	_cod.custom_minimum_size.x = 26.0 * v
	ha.add_child(_cod)
	var badd := UI.BotaoMenu.new("Adicionar", "", true, 3.0, 16.0)
	badd.apertado.connect(func(): Conta.adicionar_amigo(_cod.text))
	ha.add_child(badd)
	dir.add_child(ha)

# online primeiro, depois quem já aceitou, depois o resto (por nome)
func _amigos_ordenados() -> Array:
	var l: Array = Conta.amigos.keys()
	l.sort_custom(func(a, b):
		var sa: Array = Conta.status_de(a)
		var sb: Array = Conta.status_de(b)
		var pa := (2 if int(sa[0]) > 0 else 0) + (1 if Conta.status_amigos.get(a, {}).get("mutuo", false) else 0)
		var pb := (2 if int(sb[0]) > 0 else 0) + (1 if Conta.status_amigos.get(b, {}).get("mutuo", false) else 0)
		if pa != pb:
			return pa > pb
		return str(Conta.amigos[a].get("nome", "")) < str(Conta.amigos[b].get("nome", "")))
	return l

func _linha_amigo(f: String, v: float) -> Control:
	var s: Dictionary = Conta.status_amigos.get(f, {})
	var st: Array = Conta.status_de(f)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(1.2 * v))
	var a := AvatarCls.new(int(s.get("avatar", Conta.amigos[f].get("avatar", 0))), 7.0 * v)
	a.online = int(st[0])
	h.add_child(a)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(UI.rotulo(str(s.get("nome", Conta.amigos[f].get("nome", "?"))), 3.0 * v, UI.TEXTO, 800))
	var extra := ""
	if float(s.get("recorde_tempo", 0.0)) > 0.0:
		extra = " · recorde " + _tempo(float(s["recorde_tempo"]))
	var t := _texto(str(st[1]) + extra, v)
	t.add_theme_color_override("font_color", [Color(1, 0.91, 0.82, 0.6), Color("#7be38f"), UI.AMBAR][int(st[0])])
	c.add_child(t)
	h.add_child(c)
	var brm := UI.BotaoMenu.new("Toque de novo" if _remover == f else "Remover", "", false, 2.2, 12.0)
	brm.apertado.connect(func():
		if _remover == f:
			_remover = ""
			Conta.remover_amigo(f)
		else:
			_remover = f
			_montar())
	h.add_child(brm)
	return h

func _cartao(valor: String, rotulo: String, v: float) -> Control:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	c.custom_minimum_size.x = 22.0 * v
	c.add_child(UI.rotulo(valor, 5.4 * v, Color.WHITE, 900, 0.0, true))
	c.add_child(UI.rotulo(rotulo, 2.3 * v, Color(1, 0.91, 0.82, 0.75), 400))
	return c

static func _tempo(seg: float) -> String:
	var s := int(seg)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]

func _secao(col: Container, txt: String, v: float) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(1.6 * v))
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
	e.custom_minimum_size = Vector2(36.0 * v, 6.5 * v)
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

func _sair() -> void:
	fechar.emit()
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_sair()
