extends CanvasLayer
# TELA DE OPÇÕES (igual à do HTML): abas Controles · Teclado e mouse · Câmera · HUD · Gráficos · Vídeo e som ·
# Infectados (0.89: as regras no estilo Project Zomboid) · Ajuda.
# 0.62: aba "Teclado e mouse": tipo de controle, mouse (sensibilidade, eixo), jeito de mirar/agachar/correr e a
# tecla de cada ação (clique e aperte a tecla nova; jogador/teclas.gd).
# Tudo é salvo na hora em Config (menu/config.gd) e aplicado no jogo por menu/aplicar_opcoes.gd.
# Na aba Gráficos as mudanças só valem ao tocar APLICAR (como no HTML).
# Opções marcadas "(em breve)" ficam salvas, mas ainda não têm efeito na versão Godot (não existe carro,
# câmera cockpit, fachadas com shader, fios, halos etc. ainda).
# Mexa AQUI para: o que aparece em cada aba e os textos da Ajuda.

signal fechar
signal editar_hud

const UI := preload("res://menu/ui.gd")
const Teclas := preload("res://jogador/teclas.gd")
const ABAS := ["Controles", "Teclado e mouse", "Câmera", "HUD", "Gráficos", "Vídeo e som", "Infectados", "Ajuda"]
const NIVEIS := [[0, "MUITO BAIXO"], [1, "BAIXO"], [2, "MÉDIO"], [3, "ALTO"]]

var aba := 0
var _raiz: Control
var _abas: Control
var _paginas: Array = []
var _msg: Label
var _msg_t := 0.0
var _pend := {}                # gráficos ainda não aplicados
var _gfx_widgets := {}         # chave -> widget (para atualizar quando muda a predefinição)
var _rotulo_preset: Label
var _bt_aplicar: Button
var _nota_gfx: Label
var _sec_gsens: Control
var _linha_gyro: Control
var _confirmar_t := 0.0
var _bt_restaurar: Control
var _area: Control              # 1.02: onde as páginas entram (cada uma é montada na primeira vez que a aba abre)
var _v := 1.0

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pend = Config.g.duplicate()
	get_viewport().size_changed.connect(_montar)
	_montar()
	visibility_changed.connect(_esconder_3d)
	_esconder_3d()

# 1.02: o fundo das Opções cobre 94-97% da tela, mas o mundo 3D (a cidade no jogo, a cena do menu) continuava sendo
# desenhado inteiro atrás. Com as Opções na tela, o 3D não é desenhado (volta ao fechar ou ao editar a HUD).
func _esconder_3d() -> void:
	get_viewport().disable_3d = visible

func _exit_tree() -> void:
	get_viewport().disable_3d = false

const SHADER_FUNDO := """
shader_type canvas_item;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.35)) * vec2(1.0, 1.4);
	float t = clamp(length(d) / 0.85, 0.0, 1.0);
	COLOR = mix(vec4(0.188, 0.078, 0.031, 0.94), vec4(0.063, 0.024, 0.008, 0.97), t);
}
"""

func _montar() -> void:
	if _raiz != null:
		_raiz.queue_free()
	_paginas.clear()
	_gfx_widgets.clear()
	_rotulo_preset = null
	_bt_aplicar = null
	_nota_gfx = null
	_sec_gsens = null
	_linha_gyro = null
	_bt_restaurar = null
	var v := UI.vh(self)
	var vs := get_viewport().get_visible_rect().size
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_FUNDO
	sm.shader = sh
	fundo.material = sm
	_raiz.add_child(fundo)
	var largura := minf(vs.x * 0.94, 150.0 * v)
	var painel := VBoxContainer.new()
	painel.add_theme_constant_override("separation", int(1.0 * v))
	painel.position = Vector2((vs.x - largura) * 0.5, 3.0 * v)
	painel.size = Vector2(largura, vs.y - 5.0 * v)
	painel.mouse_filter = Control.MOUSE_FILTER_PASS
	_raiz.add_child(painel)
	# cabeçalho
	var cab := HBoxContainer.new()
	cab.mouse_filter = Control.MOUSE_FILTER_PASS
	cab.add_child(UI.titulo_degrade("Opções", 6.6 * v))
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cab.add_child(esp)
	var voltar := UI.BotaoMenu.new("Voltar", "", false, 3.2, 0.0)
	voltar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	voltar.apertado.connect(func(): fechar.emit())
	cab.add_child(voltar)
	painel.add_child(cab)
	var abas := UI.Abas.new(ABAS)
	_abas = abas
	abas.atual = aba
	abas.escolheu.connect(_trocar_aba)
	painel.add_child(abas)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	painel.add_child(area)
	# 1.02: só a aba aberta é montada agora; as outras na primeira vez que forem abertas (antes as 8 de uma vez:
	# ~900 nós e o dobro do tempo para abrir as Opções)
	_area = area
	_v = v
	_paginas.resize(ABAS.size())
	_paginas.fill(null)
	_pagina(aba).visible = true
	_msg = UI.rotulo("", 2.5 * v, UI.AMBAR, 700)
	_msg.custom_minimum_size.y = 3.2 * v
	painel.add_child(_msg)
	_atualizar_gyro()

func _trocar_aba(i: int) -> void:
	aba = i
	if _abas != null and _abas.atual != i:
		_abas.atual = i
		_abas.queue_redraw()
	_pagina(i)
	for k in _paginas.size():
		if _paginas[k] != null:
			_paginas[k].visible = k == i
	_atualizar_gyro()

# a página da aba i (monta na primeira vez)
func _pagina(i: int) -> Control:
	if _paginas[i] != null:
		return _paginas[i]
	var p: Control
	match i:
		0: p = _pagina_controles(_v)
		1: p = _pagina_teclado(_v)
		2: p = _pagina_camera(_v)
		3: p = _pagina_hud(_v)
		4: p = _pagina_graficos(_v)
		5: p = _pagina_video(_v)
		6: p = _pagina_infectados(_v)
		_: p = _pagina_ajuda(_v)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	_area.add_child(p)
	_paginas[i] = p
	return p

func mensagem(t: String) -> void:
	if _msg != null:
		_msg.text = t
		_msg_t = 3.5

func _process(dt: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0 and _msg != null:
			_msg.text = ""
	if _esperando_t > 0.0:
		_esperando_t -= dt
	if _confirmar_t > 0.0:
		_confirmar_t -= dt
		if _confirmar_t <= 0.0 and is_instance_valid(_bt_restaurar):
			_bt_restaurar.titulo = "Restaurar todas as opções"
			_bt_restaurar.queue_redraw()

# ---------- peças ----------
func _grade(v: float) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", int(3.0 * v))
	g.add_theme_constant_override("v_separation", int(1.8 * v))
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	return g

# seção = título (com valor em âmbar, ex.: "Sensibilidade da câmera 100%") + controle
func _secao(pai: Control, titulo: String, w: Control, valor := "") -> Label:
	var v := UI.vh(self)
	var s := VBoxContainer.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_theme_constant_override("separation", int(0.9 * v))
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(0.8 * v))
	h.add_child(UI.rotulo(titulo, 2.8 * v, UI.TITULO_SECAO, 700))
	var em := UI.rotulo(valor, 2.8 * v, UI.AMBAR, 700)
	h.add_child(em)
	s.add_child(h)
	s.add_child(w)
	pai.add_child(s)
	return em

func _seg(chave: String, ops: Array, sem_efeito := {}) -> Control:
	var s := UI.Seletor.new(ops, Config.valor(chave))
	s.escolheu.connect(func(val):
		Config.definir(chave, val)
		if sem_efeito.has(val):
			mensagem(sem_efeito[val]))
	return s

func _deslizante(chave: String, mn: int, mx: int, ps: int, sufixo: String, pai: Control, titulo: String) -> void:
	var d := UI.Deslizante.new(mn, mx, ps, int(Config.valor(chave)))
	var em := _secao(pai, titulo, d, str(int(Config.valor(chave))) + sufixo)
	d.mudou.connect(func(val):
		em.text = str(val) + sufixo
		Config.definir(chave, val))

func _rolavel(conteudo: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(conteudo)
	return sc

# ---------- abas ----------
func _pagina_controles(v: float) -> Control:
	var g := _grade(v)
	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_theme_constant_override("separation", int(0.9 * v))
	var seg := UI.Seletor.new([["touch", "Toque"], ["gyro", "Giroscópio"]], Config.valor("ctrl"))
	seg.escolheu.connect(func(val):
		Config.definir("ctrl", val)
		_atualizar_gyro()
		if val == "gyro" and Input.get_gyroscope() == Vector3.ZERO:
			mensagem("Sem sinal do giroscópio agora. Se o aparelho tiver o sensor, ele começa a funcionar ao mexer o celular."))
	_secao(col1, "Controle", seg)
	_linha_gyro = HBoxContainer.new()
	_linha_gyro.add_theme_constant_override("separation", int(1.0 * v))
	var cal := UI.BotaoMenu.new("Calibrar", "", false, 3.2, 0.0)
	cal.apertado.connect(func():
		Config.definir("gyro_zero", Input.get_gyroscope())
		mensagem("Giroscópio calibrado nesta posição."))
	var inv := UI.BotaoMenu.new("Inverter", "", false, 3.2, 0.0)
	inv.apertado.connect(func():
		Config.definir("gyro_inv", not bool(Config.o.get("gyro_inv", false)))
		mensagem("Direção do giroscópio invertida."))
	_linha_gyro.add_child(cal)
	_linha_gyro.add_child(inv)
	col1.add_child(_linha_gyro)
	g.add_child(col1)
	_sec_gsens = VBoxContainer.new()
	_sec_gsens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_secao(_sec_gsens, "Sensibilidade do giroscópio", _seg("gsens", [[35, "Baixa"], [25, "Média"], [18, "Alta"]]))
	g.add_child(_sec_gsens)
	_deslizante("sens", 40, 220, 5, "%", g, "Sensibilidade da câmera")
	_secao(g, "Eixo vertical da câmera", _seg("inv", [[false, "Normal"], [true, "Invertido"]]))
	_secao(g, "Aceleração", _seg("gas", [["manual", "Manual"], ["auto", "Automática"]],
		{"auto": "Aceleração automática é para veículos, que ainda não existem na versão Godot (fica salva)."}))
	_secao(g, "Vibração", _seg("vib", [[true, "Ligada"], [false, "Desligada"]]))
	return _rolavel(g)

# ---------- teclado e mouse (0.62) ----------
var _bt_teclas := {}           # ação -> BotaoMenu com a tecla
var _esperando := ""           # ação esperando a tecla nova
var _esperando_t := 0.0

func _pagina_teclado(v: float) -> Control:
	Teclas.carregar(Config.valor("teclas"))
	_bt_teclas.clear()
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(1.6 * v))
	var g := _grade(v)
	_secao(g, "Tipo de controle", _seg("entrada", [["auto", "Automático"], ["pc", "Teclado e mouse"], ["toque", "Toque"]]))
	_secao(g, "Rodinha do mouse", _seg("roda_mouse", [[true, "Troca de arma"], [false, "Desligada"]]))
	_deslizante("msens", 20, 300, 5, "%", g, "Sensibilidade do mouse")
	_deslizante("msens_mira", 20, 150, 5, "%", g, "Sensibilidade mirando")
	_secao(g, "Eixo vertical do mouse", _seg("minv", [[false, "Normal"], [true, "Invertido"]]))
	_secao(g, "Mirar", _seg("mirar_modo", [["segurar", "Segurar"], ["alternar", "Apertar liga/desliga"]]))
	_secao(g, "Agachar", _seg("agachar_modo", [["alternar", "Apertar liga/desliga"], ["segurar", "Segurar"]]))
	_secao(g, "Correr", _seg("correr_modo", [["segurar", "Segurar"], ["alternar", "Apertar liga/desliga"]]))
	_secao(g, "Dicas de teclas na tela", _seg("dicas_teclas", [[true, "Mostrar"], [false, "Esconder"]]))
	col.add_child(g)
	var nota := UI.rotulo("Automático: usou teclado ou mouse, a HUD de toque some e o mouse controla a câmera; tocou na tela, ela volta. "
		+ "Clique numa tecla abaixo e aperte a nova (Esc cancela).", 2.4 * v, UI.TEXTO, 400)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(nota)
	# teclas, por grupo, em duas colunas
	var grupo := ""
	var tg: GridContainer = null
	for a in Teclas.ACOES:
		if a[3] != grupo:
			grupo = a[3]
			col.add_child(UI.rotulo(grupo, 3.0 * v, UI.TITULO_SECAO, 700))
			tg = _grade(v)
			tg.add_theme_constant_override("v_separation", int(0.8 * v))
			col.add_child(tg)
		var linha := HBoxContainer.new()
		linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_theme_constant_override("separation", int(1.0 * v))
		var nome := UI.rotulo(a[1], 2.6 * v, UI.TEXTO, 600)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nome)
		var acao: String = a[0]
		var bt := UI.BotaoMenu.new(Teclas.texto_de(acao), "", false, 2.8, 0.0)
		bt.custom_minimum_size.x = 26.0 * v
		bt.apertado.connect(func(): _esperar_tecla(acao))
		linha.add_child(bt)
		_bt_teclas[acao] = bt
		tg.add_child(linha)
	var rest := UI.BotaoMenu.new("Restaurar teclas padrão", "", false, 3.4, 0.0)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.apertado.connect(func():
		_esperando = ""
		Teclas.carregar({})
		Config.definir("teclas", {})
		_mostrar_teclas()
		mensagem("Teclas voltaram ao padrão."))
	col.add_child(rest)
	return _rolavel(col)

func _esperar_tecla(acao: String) -> void:
	_mostrar_teclas()
	_esperando = acao
	_esperando_t = 0.2                 # o próprio clique que abriu não conta
	var bt = _bt_teclas.get(acao)
	if bt != null:
		bt.titulo = "Aperte a tecla..."
		bt.queue_redraw()

func _mostrar_teclas() -> void:
	for acao in _bt_teclas:
		var bt = _bt_teclas[acao]
		bt.titulo = Teclas.texto_de(acao)
		bt.queue_redraw()

func _input(e: InputEvent) -> void:
	if _esperando == "" or _esperando_t > 0.0:
		return
	var c := ""
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE:
			_esperando = ""
			_mostrar_teclas()
			get_viewport().set_input_as_handled()
			return
		c = Teclas.codigo_do_evento(e)
	elif e is InputEventMouseButton and e.pressed and e.device != InputEvent.DEVICE_ID_EMULATION:
		c = Teclas.codigo_do_evento(e)
	if c == "":
		return
	get_viewport().set_input_as_handled()
	var acao := _esperando
	_esperando = ""
	Config.definir("teclas", Teclas.definir(acao, c))
	_mostrar_teclas()
	mensagem("%s: %s" % [_nome_acao(acao), Teclas.texto(c)])

func _nome_acao(acao: String) -> String:
	for a in Teclas.ACOES:
		if a[0] == acao:
			return a[1]
	return acao

func _atualizar_gyro() -> void:
	var on: bool = Config.valor("ctrl") == "gyro"
	if _sec_gsens != null:
		_sec_gsens.visible = on
	if _linha_gyro != null:
		_linha_gyro.visible = on

func _pagina_camera(v: float) -> Control:
	var g := _grade(v)
	_secao(g, "Câmera", _seg("cam", [[0, "3ª pessoa"], [1, "1ª pessoa"]],
		{1: "Câmera nos olhos: você vê os braços, a arma e as pernas. Troque no jogo com F ou o botão CAM."}))
	_secao(g, "Mirar em 3ª pessoa", _seg("mira_ferro", [[true, "Mira de ferro"], [false, "Por cima do ombro"]],
		{true: "Com arma de fogo, MIRAR leva a câmera para os olhos e você mira pela mira da própria arma.",
		false: "MIRAR aproxima a câmera por cima do ombro (a mira de ferro só em 1ª pessoa)."}))
	_secao(g, "Distância (câmera traseira)", _seg("dist", [["near", "Perto"], ["mid", "Média"], ["far", "Longe"]]))
	_secao(g, "Posição do personagem", _seg("pos", [["left", "Esquerda"], ["center", "Centro"], ["right", "Direita"]],
		{"left": "Câmera no ombro direito. Troque de ombro no jogo com o botão OMBRO ou o botão do meio do mouse.",
		"right": "Câmera no ombro esquerdo. Troque de ombro no jogo com o botão OMBRO ou o botão do meio do mouse."}))
	var d := UI.Deslizante.new(36, 70, 1, int(Config.valor("fov")))
	var em := _secao(g, "Campo de visão", d, str(int(Config.valor("fov"))) + "°")
	d.mudou.connect(func(val):
		em.text = str(val) + "°"
		Config.definir("fov", val))
	return _rolavel(g)

func _pagina_hud(v: float) -> Control:
	var g := _grade(v)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(0.6 * v))
	var b1 := UI.BotaoMenu.new("Personalizar HUD", "Arraste cada item para onde quiser", true, 3.6, 0.0)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.apertado.connect(func(): editar_hud.emit())
	var b2 := UI.BotaoMenu.new("Restaurar posições", "", false, 3.6, 0.0)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.apertado.connect(func():
		Config.definir_hud({})
		mensagem("Posições da HUD restauradas."))
	col.add_child(b1)
	col.add_child(b2)
	_secao(g, "Posição e tamanho dos botões", col)
	_secao(g, "Minimapa", _seg("map", [[true, "Visível"], [false, "Oculto"]],
		{true: "Minimapa no canto de cima (toque nele para abrir o mapa grande).", false: "Sem minimapa: só a bússola. O mapa grande abre com M."}))
	_secao(g, "Avisos na tela", _seg("avisos", [[false, "Desligados"], [true, "Ligados"]],
		{false: "Sem os textos no meio da tela (MICROFONE LIGADO, SANGRANDO, AGARRADO...).",
		true: "Mostra os avisos embaixo, no meio da tela (microfone, ferimentos, itens, zonas...). Mude o lugar e o tamanho em Personalizar HUD (item AVISOS)."}))
	_secao(g, "Fundo dos avisos", _seg("avisos_fundo", [[false, "Sem fundo"], [true, "Com fundo"]],
		{false: "Só o texto, com uma sombra leve (mais discreto).",
		true: "Uma faixa escura atrás de cada aviso: lê melhor com o céu ou o chão claro."}))
	_secao(g, "Ícone da munição", _seg("icone_mun", [[false, "Oculto"], [true, "Visível"]],
		{false: "Sem o ícone do pente embaixo, no meio da tela.",
		true: "Ícone do pente embaixo: muda de cor conforme a munição acaba e pisca vazio."}))
	_deslizante("op", 35, 100, 5, "%", g, "Opacidade da HUD")
	_deslizante("sc", 70, 125, 5, "%", g, "Tamanho geral da HUD")
	return _rolavel(g)

func _pagina_video(v: float) -> Control:
	var g := _grade(v)
	_secao(g, "Contador de FPS", _seg("fps", [[false, "Oculto"], [true, "Visível"]]))
	_secao(g, "Som", _seg("som", [[true, "Ligado"], [false, "Mudo"]]))
	_deslizante("vol", 0, 100, 5, "%", g, "Volume")
	_secao(g, "Música", _seg("mus", [[true, "Ligada"], [false, "Desligada"]]))
	_deslizante("mvol", 0, 100, 5, "%", g, "Volume da música")
	_deslizante("svol", 0, 100, 5, "%", g, "Volume dos efeitos")
	_secao(g, "Dificuldade", _seg("dif", [[0, "Fácil"], [1, "Normal"], [2, "Difícil"]],
		{0: "Menos infectados e mordidas mais fracas.", 1: "Equilíbrio do jogo.", 2: "Mais infectados, mordidas mais fortes."}))
	_secao(g, "PvP no multijogador (quando você cria a partida)", _seg("pvp", [["zonas", "Só nas zonas"], ["tudo", "Cidade toda"], ["desligado", "Desligado"]],
		{"zonas": "Jogadores só se ferem nos postos, hospitais, supermercados e armazéns.", "tudo": "Jogadores se ferem em qualquer lugar.",
		"desligado": "Ninguém fere ninguém."}))
	_secao(g, "Manter tela ligada", _seg("awake", [[false, "Não"], [true, "Sim"]]))
	var tc := UI.BotaoMenu.new("Alternar tela cheia", "", false, 3.2, 0.0)
	tc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tc.apertado.connect(func():
		var w := DisplayServer.window_get_mode()
		var cheia := w == DisplayServer.WINDOW_MODE_FULLSCREEN or w == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if cheia else DisplayServer.WINDOW_MODE_FULLSCREEN))
	_secao(g, "Tela cheia", tc)
	return _rolavel(g)

# 0.89 · INFECTADOS no estilo PROJECT ZOMBOID (as "sandbox" de lá; números em inimigos/regras_infectados.gd).
# Valem para quem cria a partida (no multijogador, os infectados são os do host). Mudanças valem para os novos.
func _pagina_infectados(v: float) -> Control:
	var g := _grade(v)
	_secao(g, "População", _seg("z_pop", [[0, "Pouca"], [1, "Normal"], [2, "Muita"], [3, "Insana"]],
		{3: "A cidade inteira cheia. Barulho aqui vira horda."}))
	_secao(g, "Velocidade", _seg("z_vel", [["lentos", "Lentos"], ["rapidos", "Rápidos"], ["corredores", "Corredores"], ["misto", "Misturado"]],
		{"lentos": "Como na história: lentos, tropeçam, vêm em massa. Andando você escapa.",
		"rapidos": "Arrastam os pés depressa: andando você não escapa, no trote sim.",
		"corredores": "Correm quase como você. Só correndo você escapa.",
		"misto": "A maioria lenta, alguns rápidos e poucos corredores."}))
	_secao(g, "Força", _seg("z_forca", [[0, "Fraca"], [1, "Normal"], [2, "Sobre-humana"]]))
	_secao(g, "Resistência", _seg("z_resist", [[0, "Frágil"], [1, "Normal"], [2, "Resistente"]]))
	_secao(g, "Portas", _seg("z_cog", [[0, "Só batem"], [1, "Abrem"]],
		{0: "Batem na porta até quebrar (cada pancada chama os outros).", 1: "Abrem portas sem tábuas. Com tábuas, só batendo."}))
	_secao(g, "Memória", _seg("z_mem", [[0, "Nenhuma"], [1, "Curta"], [2, "Normal"], [3, "Longa"]],
		{0: "Te perdeu de vista, esquece na hora.", 1: "Procura você uns 20 s.", 2: "Procura você 1 minuto.", 3: "Procura você 2 minutos."}))
	_secao(g, "Visão", _seg("z_visao", [[0, "Ruim"], [1, "Normal"], [2, "Águia"]]))
	_secao(g, "Audição", _seg("z_audicao", [[0, "Ruim"], [1, "Normal"], [2, "Exata"]],
		{2: "Ouvem de mais longe e vão direto no lugar do barulho."}))
	_secao(g, "O vírus passa por", _seg("z_trans", [[0, "Sangue e saliva"], [1, "Só mordida"], [2, "Ninguém pega"]],
		{0: "Mordida passa sempre; laceração às vezes; arranhão raramente.", 2: "Ferimentos só machucam: ninguém vira infectado."}))
	_secao(g, "O vírus mata em", _seg("z_morte", [[0, "Horas"], [1, "1-2 dias"], [2, "2-3 dias"], [3, "1 semana"]]))
	_secao(g, "Puxar para o chão", _seg("z_derrubar", [[true, "Sim"], [false, "Não"]],
		{true: "Três infectados te acertando juntos te derrubam (morte)."}))
	_secao(g, "Reaparecem", _seg("z_reaparecer", [[true, "Sim"], [false, "Não"]],
		{true: "Lugar que você limpou volta a ter infectados depois de 3 dias sem ninguém por perto."}))
	_secao(g, "Mutados", _seg("z_mutados", [[0, "Não"], [1, "Raros"], [2, "Frequentes"]],
		{0: "Só os infectados comuns.",
		1: "De vez em quando um mutado aparece onde você não vê: corre e salta como bicho. O estalo dos dentes avisa.",
		2: "Mutados mais vezes (até 2 ao mesmo tempo)."}))
	_secao(g, "Ritmo", _seg("z_ritmo", [[0, "Sem Diretor"], [1, "Calmo"], [2, "Normal"], [3, "Intenso"]],
		{0: "Sem tensão e alívio: só a população da cidade, sem hordas mandadas atrás de você.",
		1: "Momentos de calma depois de cada luta e hordas raras.",
		2: "Depois de cada luta a cidade acalma; na rua, de vez em quando uma horda vem atrás de você.",
		3: "Hordas mais frequentes."}))
	_secao(g, "Andam", _seg("z_ativos", [["ambos", "Dia e noite"], ["dia", "Só de dia"], ["noite", "Só de noite"]],
		{"dia": "De noite ficam parados e quase não sentem nada.", "noite": "De dia ficam parados e quase não sentem nada."}))
	return _rolavel(g)

func _pagina_ajuda(v: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(1.0 * v))
	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.fit_content = true
	txt.scroll_active = false
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_theme_font_override("normal_font", UI.fonte(400, 0.0, false))
	txt.add_theme_font_override("bold_font", UI.fonte(800, 0.0, false))
	txt.add_theme_font_size_override("normal_font_size", int(2.7 * v))
	txt.add_theme_font_size_override("bold_font_size", int(2.7 * v))
	txt.add_theme_color_override("default_color", Color(UI.TEXTO.r, UI.TEXTO.g, UI.TEXTO.b, 0.92))
	var a := "[color=#ffb400][b]%s[/b][/color] "
	txt.text = (a % "Toque:") + "metade esquerda = joystick · metade direita = olhar · ATIRAR (segure; dá para mirar arrastando) · CORRER · PULAR · AGACHAR · MIRAR · RECARREGAR · ARMA (coldre/ombro) · PEGAR · INV (inventário) · II (pausa) · VOO.\n\n" \
		+ (a % "Teclado e mouse:") + "com teclado ou mouse a HUD de toque some e o mouse controla a câmera. Padrão: WASD/setas mover · Shift correr · Alt andar devagar · Espaço pular · C agachar · mouse esquerdo atirar · mouse direito mirar · R recarregar · X ou rodinha troca arma · Q roda · 1..8 atalhos · E pegar · Tab inventário · M mapa · V voo · Esc pausa. Troque as teclas em Opções › Teclado e mouse.\n\n" \
		+ (a % "Inventário:") + "arraste itens entre o chão (esquerda), o corpo (meio) e a mochila (direita); R ou um 2º dedo gira; duplo toque = ação rápida.\n\n" \
		+ (a % "HUD:") + "em Opções › HUD toque em Personalizar HUD, arraste cada botão e ajuste o tamanho; Concluir salva."
	col.add_child(txt)
	var b := UI.BotaoMenu.new("Restaurar todas as opções", "", false, 3.6, 0.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bt_restaurar = b
	b.apertado.connect(func():
		if _confirmar_t <= 0.0:
			_confirmar_t = 2.5
			b.titulo = "Toque de novo para confirmar"
			b.queue_redraw()
			return
		_confirmar_t = 0.0
		Config.restaurar_tudo()
		_pend = Config.g.duplicate()
		_montar()
		mensagem("Opções restauradas (as posições da HUD não mudam)."))
	col.add_child(b)
	return _rolavel(col)

# ---------- gráficos ----------
func _linha_gfx(lista: VBoxContainer, titulo: String, desc: String, w: Control, v: float, valor_em := "") -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(2.0 * v))
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	var esq := VBoxContainer.new()
	esq.add_theme_constant_override("separation", 0)
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.size_flags_stretch_ratio = 0.72
	esq.alignment = BoxContainer.ALIGNMENT_CENTER
	var th := HBoxContainer.new()
	th.add_child(UI.rotulo(titulo.to_upper(), 3.2 * v, Color("#fff4dc"), 900, 0.0, true))
	var em := UI.rotulo(valor_em, 2.8 * v, UI.AMBAR, 800, 0.0, true)
	th.add_child(em)
	esq.add_child(th)
	if desc != "":
		var d := UI.rotulo(desc, 1.9 * v, Color(UI.TEXTO.r, UI.TEXTO.g, UI.TEXTO.b, 0.8), 700)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		esq.add_child(d)
	h.add_child(esq)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(w)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(0.8 * v))
	m.add_theme_constant_override("margin_bottom", int(0.8 * v))
	m.add_child(h)
	lista.add_child(m)
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.custom_minimum_size.y = maxf(1.0, 0.15 * v)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lista.add_child(sep)
	return em

func _gfx_seg(lista: VBoxContainer, chave: String, titulo: String, desc: String, ops: Array, v: float) -> void:
	var s := UI.Seletor.new(ops, _pend.get(chave), 2.7, 5.2)
	s.borda = false
	s.escolheu.connect(func(val): _mudar_gfx(chave, val))
	_gfx_widgets[chave] = s
	_linha_gfx(lista, titulo, desc, s, v)

func _gfx_passo(lista: VBoxContainer, chave: String, titulo: String, desc: String, ops: Array, v: float) -> void:
	var p := UI.Passo.new(ops, _pend.get(chave))
	p.escolheu.connect(func(val): _mudar_gfx(chave, val))
	_gfx_widgets[chave] = p
	_linha_gfx(lista, titulo, desc, p, v)

func _gfx_desl(lista: VBoxContainer, chave: String, titulo: String, desc: String, mn: int, mx: int, v: float) -> void:
	var d := UI.Deslizante.new(mn, mx, 5, int(_pend.get(chave)))
	var em := _linha_gfx(lista, titulo, desc, d, v, "  " + str(int(_pend.get(chave))) + "%")
	d.mudou.connect(func(val):
		em.text = "  " + str(val) + "%"
		_mudar_gfx(chave, val))
	_gfx_widgets[chave] = d
	_gfx_widgets[chave + "_em"] = em

func _pagina_graficos(v: float) -> Control:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 0)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 0)
	var q := UI.Seletor.new([["auto", "AUTO"], ["low", "LEVE"], ["mid", "MÉDIO"], ["high", "ALTO"], ["ultra", "ULTRA"]], Config.preset_de(_pend), 2.7, 5.2)
	q.borda = false
	q.escolheu.connect(func(val):
		for k in Config.GFX_PRESETS[val]:
			_pend[k] = Config.GFX_PRESETS[val][k]
		_atualizar_gfx())
	_gfx_widgets["q"] = q
	_rotulo_preset = _linha_gfx(lista, "Predefinição", "", q, v)
	if OS.has_feature("pc"):
		# 0.92: modo de desenho (só no PC): vale ao abrir o jogo de novo (menu/aplicar_opcoes.gd escreve o override.cfg)
		_gfx_seg(lista, "rend", "Modo de desenho", "ULTRA: sombras nos cantos, luz rebatendo nas paredes, reflexos no chão molhado, brilho e neblina de verdade (precisa de placa de vídeo · vale ao abrir o jogo de novo)",
			[[0, "LEVE"], [1, "ULTRA"]], v)
	_gfx_seg(lista, "shd", "Detalhes dos shaders", "fachadas: janelas, andares e lojas", NIVEIS, v)
	_gfx_seg(lista, "tex", "Detalhes das texturas", "nitidez das texturas do chão (menos = mais leve)", NIVEIS, v)
	_gfx_seg(lista, "models", "Detalhes dos modelos", "até onde carros, postes, árvores e objetos da rua aparecem completos", NIVEIS, v)
	_gfx_seg(lista, "detd", "Distância dos detalhes", "árvores e caixas d'água nos telhados", NIVEIS, v)
	_gfx_seg(lista, "fx", "Detalhes dos efeitos", "colunas de fumaça no horizonte, poeira dos tiros e marcas de bala", NIVEIS, v)
	_gfx_seg(lista, "shad", "Sombras", "Simples: mancha sob o personagem · Alta: sombra em tempo real (usa mais GPU)",
		[[0, "DESLIGADAS"], [1, "SIMPLES"], [2, "ALTA"]], v)
	_gfx_seg(lista, "den", "Densidade do cenário abandonado", "quantidade de carros largados, entulho e capim", [[0, "BAIXA"], [1, "MÉDIA"], [2, "ALTA"]], v)
	_gfx_seg(lista, "wtr", "Água", "ondas, espuma na praia e brilho do sol", [[false, "SIMPLES"], [true, "COMPLETA"]], v)
	_gfx_seg(lista, "wire", "Fios de poste", "fios caídos entre os postes das ruas", [[false, "DESLIGADOS"], [true, "LIGADOS"]], v)
	_gfx_seg(lista, "halo", "Halos de luz", "brilho dos postes que ainda acendem e dos semáforos piscando, à noite", [[false, "DESLIGADOS"], [true, "LIGADOS"]], v)
	_gfx_seg(lista, "dist", "Distância de visão", "quanto da cidade é desenhado", NIVEIS, v)
	_gfx_passo(lista, "chk", "Raio de chunks", "pedaços de 500 m da cidade em volta da câmera (menor = mais leve; AUTO segue a distância de visão)",
		[[0, "AUTO"], [1, "1 (±500 m)"], [2, "2 (±1 km)"], [3, "3 (±1,5 km)"], [4, "4 (±2 km)"], [6, "6 (±3 km)"], [8, "8 (±4 km)"], [10, "10 (±5 km)"]], v)
	_gfx_seg(lista, "ocl", "Ocultar o que está atrás", "não desenha o que os prédios escondem (mais leve na placa, usa um pouco do processador)", [[true, "LIGADO"], [false, "DESLIGADO"]], v)
	_gfx_seg(lista, "fog", "Neblina", "densa esconde mais e deixa o jogo mais leve", [[0, "DENSA"], [1, "NORMAL"], [2, "LIMPA"]], v)
	_gfx_seg(lista, "res", "Resolução da tela", "", NIVEIS, v)
	_gfx_desl(lista, "rp", "Ajuste fino da resolução", "35% = automático pelo nível acima", 35, 100, v)
	_gfx_seg(lista, "dyn", "Resolução dinâmica", "reduz a resolução sozinha se o FPS cair", [[true, "LIGADA"], [false, "DESLIGADA"]], v)
	_gfx_passo(lista, "aa", "Anti-aliasing", "serrilhado nas bordas", [[0, "Desligado"], [1, "MSAA 2x"], [2, "MSAA 4x"], [3, "MSAA 8x"]], v)
	_gfx_passo(lista, "aniso", "Filtragem anisotrópica", "nitidez do chão e das ruas à distância (mais amostras = mais GPU)",
		[[1, "Desligada"], [2, "2x"], [4, "4x"], [8, "8x"], [16, "16x"]], v)
	_gfx_passo(lista, "cap", "Limite de FPS", "economiza bateria", [[0, "Sem limite"], [30, "30"], [45, "45"], [60, "60"]], v)
	_gfx_desl(lista, "bri", "Brilho", "", 70, 130, v)
	_gfx_desl(lista, "con", "Contraste", "", 80, 130, v)
	_gfx_desl(lista, "sat", "Saturação", "", 60, 140, v)
	_gfx_seg(lista, "vig", "Vinheta", "escurece os cantos da tela", [[false, "DESLIGADA"], [true, "LIGADA"]], v)
	var sc := _rolavel(lista)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caixa.add_child(sc)
	# rodapé: RESTAURAR PARA O PADRÃO · nota · APLICAR
	var pe := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.03, 0.01, 0.92)
	sb.border_color = Color(1.0, 0.667, 0.353, 0.3)
	sb.border_width_top = 2
	sb.content_margin_left = 2.0 * v
	sb.content_margin_right = 2.0 * v
	sb.content_margin_top = 0.8 * v
	sb.content_margin_bottom = 0.8 * v
	pe.add_theme_stylebox_override("panel", sb)
	var hp := HBoxContainer.new()
	var br := _botao_texto("RESTAURAR PARA O PADRÃO", v)
	br.pressed.connect(func():
		_pend = Config.gfx_padrao()
		Config.aplicar_graficos(_pend)
		_atualizar_gfx()
		mensagem("Gráficos restaurados para o padrão."))
	hp.add_child(br)
	_nota_gfx = UI.rotulo("", 2.4 * v, UI.AMBAR, 700, 0.0, true)
	_nota_gfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nota_gfx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_child(_nota_gfx)
	_bt_aplicar = _botao_texto("APLICAR", v)
	_bt_aplicar.pressed.connect(func():
		Config.aplicar_graficos(_pend)
		_atualizar_gfx()
		var quer_ultra := int(_pend.get("rend", 0)) == 1
		if OS.has_feature("pc") and quer_ultra != (RenderingServer.get_rendering_device() != null):
			mensagem("Gráficos aplicados. Feche e abra o jogo de novo para trocar o modo de desenho.")
		else:
			mensagem("Gráficos aplicados."))
	hp.add_child(_bt_aplicar)
	pe.add_child(hp)
	caixa.add_child(pe)
	_atualizar_gfx()
	return caixa

func _botao_texto(t: String, v: float) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UI.fonte(900))
	b.add_theme_font_size_override("font_size", int(3.0 * v))
	b.add_theme_color_override("font_color", Color("#fff4dc"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", UI.LARANJA)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.pressed.connect(func(): UI.Sons.ui("clique"))
	return b

func _mudar_gfx(chave: String, val) -> void:
	_pend[chave] = val
	_atualizar_gfx()

func _atualizar_gfx() -> void:
	var pre := Config.preset_de(_pend)
	for k in _gfx_widgets:
		var w = _gfx_widgets[k]
		if k == "q":
			w.definir(pre)
		elif k.ends_with("_em"):
			w.text = "  " + str(int(_pend.get(k.trim_suffix("_em")))) + "%"
		elif _pend.has(k):
			w.definir(_pend[k])
	if _rotulo_preset != null:
		_rotulo_preset.text = "  PERSONALIZADO" if pre == "custom" else ""
	var pendente := false
	for k in _pend:
		if Config.g.get(k) != _pend[k]:
			pendente = true
	if _bt_aplicar != null:
		_bt_aplicar.disabled = not pendente
	if _nota_gfx != null:
		_nota_gfx.text = "toque em APLICAR para usar" if pendente else ""
