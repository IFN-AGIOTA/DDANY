extends CanvasLayer
# CONTROLES DE TOQUE (multitoque de verdade) + teclado/mouse no PC.
# Botões próprios desenhados aqui (os Button da Godot só reconhecem UM dedo, e no tiroteio
# você anda, olha e atira ao mesmo tempo).
#  - metade ESQUERDA da tela: joystick que aparece onde você toca (fraco = andar · forte = trote)
#  - metade DIREITA: arrastar = olhar
#  - ATIRAR (segurar; dá para arrastar o dedo em cima dele para mirar enquanto atira) · CORRER (segurar)
#  - PULAR · AGACHAR (liga/desliga) · MIRAR (liga/desliga, aproxima a câmera) · RECARREGAR · ARMA (troca)
#  - VOO (canto de cima): câmera livre para inspecionar a cidade
#  - INV (canto de cima): abre o inventário (estilo DayZ) · PEGAR aparece quando há um item no chão perto
#  - II (canto de cima): pausa. Posições/tamanhos/opacidade vêm de Opções › HUD (aplicar_layout / modo de edição)
# TECLADO E MOUSE (0.62): com teclado/mouse (PC, ou celular com teclado/mouse ligado) o jogo entra no MODO PC:
#   a HUD de toque SOME, o mouse fica preso na tela (olhar), e as teclas são as de jogador/teclas.gd (trocáveis em
#   Opções › Teclado e mouse). Padrão: WASD andar · Shift correr · Alt andar devagar · Espaço pular · C agachar ·
#   mouse esquerdo atirar · mouse direito mirar · R recarregar · X trocar arma · rodinha troca arma · Q roda ·
#   1..8 atalhos · E pegar · Tab inventário · M mapa · Esc pausa · V câmera livre (E/Q sobe/desce).
#   "auto" (Config "entrada"): usou teclado/mouse -> modo PC; tocou na tela -> modo toque (HUD volta).
#   O mouse se solta sozinho com inventário, mapa, pausa, roda e telas por cima (bloqueado / mouse_solto).
# Com o inventário aberto (bloqueado = true) os controles ficam neutros: o jogador para e nada é desenhado.

signal voo_pedido
signal camera_pedida               # 0.65: 1ª/3ª pessoa (botão CAM, tecla F)
signal ombro_pedido                # 0.79: trocar de ombro (botão OMBRO, botão do meio do mouse)
signal vel_pedida
signal agachar_pedido
signal mirar_pedido
signal recarregar_pedido
signal trocar_arma_pedido          # rodinha do mouse: troca direto
signal roda_inicio(pos: Vector2)   # 0.56: dedo apertou ARMA -> abre a RODA DE ARMAS (hud/roda_armas.gd)
signal roda_arrasto(pos: Vector2)
signal roda_fim(pos: Vector2)
signal roda_tecla                  # PC: tecla Q
signal atalho_pedido(indice: int)
signal inventario_pedido
signal pegar_pedido
signal pausa_pedida
signal selecionou(id: String)      # modo de edição da HUD: botão tocado
signal mensagem_pedida             # 0.71: mensagens rápidas do multijogador (botão MSG, tecla T)
signal empurrar_pedido             # 0.90: empurrão / pisão (botão EMPURRAR, tecla G)
signal mic_pedido                  # 0.97: chat de voz: mutar/desmutar o SEU microfone (botão MIC, tecla J · rede/voz.gd)
signal vozes_pedido                # 0.97: chat de voz: mutar/desmutar os OUTROS jogadores (botão VOZES, tecla K)
signal sentido_pedido              # 0.95: mutado/controlado: FAREJAR / ESCUTAR (botão SENTIDO, tecla H · jogador/sentidos.gd)
signal construir_pedido            # 0.90: abrir/fechar a construção (botão CONSTRUIR, tecla B)
signal girar_pedido                # 0.90: construindo: girar a peça (botão GIRAR, tecla R)
signal confirmar_pedido            # 0.90: construindo: pôr a peça aqui (botão OK, tecla E / clique)
signal cancelar_pedido             # 0.90: construindo: desistir (botão CANCELAR, botão direito)
var construindo := false           # 0.90: com a peça na mão, R gira, E/clique põe, botão direito cancela

const UI := preload("res://menu/ui.gd")
const Teclas := preload("res://jogador/teclas.gd")
const RAIO_STICK := 90.0
# 0.67: ÍCONES dos botões (game-icons.net, CC BY 3.0): todos numa folha só (hud/icones/botoes.png, 8 colunas de 128 px,
# feita por ferramentas/gerar_icones_botoes.gd; a ordem aqui é a mesma de lá). Botão sem ícone mostra o texto.
const FOLHA_ICONES := preload("res://hud/icones/botoes.png")
const ICONES := ["PAUSA", "INV", "VOO", "CAM", "MIRAR", "ATIRAR", "PULAR", "CORRER", "AGACHAR", "RECARREGAR", "PEGAR",
	"SOBE", "DESCE", "VEL", "pistola", "m4", "mp5", "ak", "espingarda", "rifle_caca", "faca", "taco", "machado", "cano",
	"lanca", "facao", "pe_de_cabra", "punhos", "MSG", "EMPURRAR", "CONSTRUIR", "GIRAR", "OK", "CANCELAR"]

# OTIMIZAÇÃO: botões = disco e anel em TEXTURA (menu/ui.gd circulo/aro): todos os discos = 1 chamada de desenho,
# todos os anéis = 1, textos = 1 (draw_circle/draw_arc eram 2 chamadas por botão).

var mover := Vector2.ZERO          # x = direita, y = frente
var modo_voo := false
var info: Label
var indicadores := {}              # id -> bool (botão aceso: AGACHAR/MIRAR ligados)
var textos := {}                   # id -> texto trocado em tempo real (ex.: nome da arma)
var ocultos := {}                  # id -> true para esconder o botão (ex.: PEGAR sem item perto)
var icones := {}                   # id -> ícone trocado em tempo real (ARMA: o id da arma na mão, ex.: "faca")
var bloqueado := false             # inventário aberto
var mostrar_info := true           # contador de FPS (Opções › Vídeo e som)
var editando := false              # Opções › HUD › Personalizar HUD: arrastar os botões
var editar_ignorar := Rect2()      # área do painel do editor (toques ali não mexem nos botões)
var selecionado := ""
var escala := 1.0                  # Opções › HUD › Tamanho geral
var layout := {}                   # posições editadas: id -> [off_x, off_y, raio] (sem a escala)
var botoes: Array = []
var _arraste := -1
var _arraste_dif := Vector2.ZERO

var _olhar := Vector2.ZERO
var _toque_mover := -1
var _toque_olhar := -1
var _origem := Vector2.ZERO
var _atual := Vector2.ZERO
var _visual: Control
var _mouse_dir := false
var _fonte: Font
# ---- teclado e mouse (0.62) ----
var modo_pc := false               # true: HUD de toque escondida, mouse preso, teclas de jogador/teclas.gd
var preferencia := "auto"          # Config "entrada": "auto", "pc" ou "toque"
var mirar_modo := "segurar"        # mouse direito: "segurar" ou "alternar"
var agachar_modo := "alternar"     # "alternar" ou "segurar"
var correr_modo := "segurar"       # "segurar" ou "alternar"
var roda_mouse := true             # rodinha troca de arma
var dicas := true                  # dicas de tecla na tela ("E  PEGAR...")
var mouse_solto := false           # alguém precisa do cursor (roda de armas aberta)
var _capturado := false
var _olhar_mouse := Vector2.ZERO
var _correr_on := false
var _moveu := false                # 0.64: andou desde que ligou a corrida "alternar" (parar desliga)
var _dica: Label

func _ready() -> void:
	layer = 10
	_fonte = ThemeDB.fallback_font
	_visual = Control.new()
	_visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS    # ícones e círculos diminuídos sem serrilhar
	_visual.draw.connect(_desenhar)
	add_child(_visual)
	info = Label.new()
	info.position = Vector2(16.0, 12.0)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(info)
	_dica = Label.new()
	_dica.add_theme_font_size_override("font_size", 18)
	_dica.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_dica.add_theme_constant_override("shadow_offset_x", 2)
	_dica.add_theme_constant_override("shadow_offset_y", 2)
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dica.offset_top = -150.0
	_dica.offset_bottom = -110.0
	_dica.offset_left = -300.0
	_dica.offset_right = 300.0
	_dica.visible = false
	add_child(_dica)
	modo_pc = _comeca_no_pc()
	#        id            texto          canto  distância do canto     raio  cor                         modo       olhar  só no voo
	_bt("ATIRAR", "ATIRAR", "br", Vector2(215, 250), 70, Color(0.88, 0.02, 0.0), "segurar", true, false)
	_bt("CORRER", "CORRER", "br", Vector2(90, 125), 60, Color(0.11, 0.56, 0.30), "segurar", false, false)
	_bt("PULAR", "PULAR", "br", Vector2(78, 330), 46, Color(0.75, 0.75, 0.80), "segurar", false, false)
	_bt("AGACHAR", "AGACHAR", "br", Vector2(228, 95), 44, Color(0.62, 0.66, 0.70), "tocar", false, false)
	_bt("MIRAR", "MIRAR", "br", Vector2(355, 335), 46, Color(0.95, 0.95, 0.95), "tocar", false, false)
	_bt("RECARREGAR", "RECARREGAR", "br", Vector2(362, 168), 40, Color(0.23, 0.63, 1.0), "tocar", false, false)
	_bt("ARMA", "ARMA", "br", Vector2(482, 282), 44, Color(1.0, 0.71, 0.0), "tocar", false, false)
	_bt("OMBRO", "OMBRO", "br", Vector2(445, 405), 32, Color(0.8, 0.8, 0.95), "tocar", false, false)
	_bt("PEGAR", "PEGAR", "br", Vector2(500, 150), 40, Color(0.35, 0.85, 0.45), "tocar", false, false)
	_bt("VOO", "VOO", "tr", Vector2(56, 46), 30, Color(0.6, 0.6, 0.6), "tocar", false, false)
	_bt("INV", "INV", "tr", Vector2(132, 46), 30, Color(1.0, 0.71, 0.0), "tocar", false, false)
	_bt("PAUSA", "II", "tr", Vector2(208, 46), 30, Color(1.0, 0.54, 0.21), "tocar", false, false)
	_bt("CAM", "CAM", "tr", Vector2(284, 46), 30, Color(0.75, 0.85, 1.0), "tocar", false, false)
	_bt("MSG", "MSG", "tr", Vector2(360, 46), 30, Color(0.45, 1.0, 0.45), "tocar", false, false)
	_bt("CONSTRUIR", "CONSTRUIR", "tr", Vector2(436, 46), 30, Color(0.85, 0.62, 0.35), "tocar", false, false)
	_bt("MIC", "MIC", "tr", Vector2(512, 46), 30, Color(0.45, 0.85, 1.0), "tocar", false, false)
	_bt("VOZES", "VOZES", "tr", Vector2(588, 46), 30, Color(0.85, 0.7, 1.0), "tocar", false, false)
	_bt("EMPURRAR", "EMPURRAR", "br", Vector2(585, 360), 40, Color(0.92, 0.55, 0.25), "tocar", false, false)
	_bt("SENTIDO", "SENTIDO", "br", Vector2(605, 235), 38, Color(0.88, 0.16, 0.14), "tocar", false, false)
	_bt("GIRAR", "GIRAR", "br", Vector2(355, 335), 46, Color(0.75, 0.85, 1.0), "tocar", false, false)
	_bt("OK", "OK", "br", Vector2(215, 250), 70, Color(0.25, 0.8, 0.35), "tocar", false, false)
	_bt("CANCELAR", "CANCELAR", "br", Vector2(362, 168), 40, Color(0.9, 0.3, 0.25), "tocar", false, false)
	for b in ["GIRAR", "OK", "CANCELAR"]:
		ocultos[b] = true                 # só aparecem construindo (mundo/construcao.gd)
	ocultos["PEGAR"] = true
	ocultos["MSG"] = true                 # só aparece no multijogador (rede/sessao_rede.gd mostra)
	ocultos["MIC"] = true                 # 0.97: chat de voz, só no multijogador (rede/voz.gd mostra)
	ocultos["VOZES"] = true
	ocultos["SENTIDO"] = true             # 0.95: só para o mutado/controlado (jogador/sentidos.gd mostra)
	_bt("SOBE", "SOBE", "br", Vector2(80, 330), 50, Color(0.6, 0.6, 0.6), "segurar", false, true)
	_bt("DESCE", "DESCE", "br", Vector2(80, 210), 50, Color(0.6, 0.6, 0.6), "segurar", false, true)
	_bt("VEL", "VEL", "br", Vector2(80, 90), 44, Color(0.6, 0.6, 0.6), "tocar", false, true)
	get_viewport().size_changed.connect(func(): _visual.queue_redraw())

func _bt(id: String, txt: String, canto: String, off: Vector2, r: float, cor: Color, modo: String, olhar: bool, voo: bool) -> void:
	botoes.append({"id": id, "txt": txt, "canto": canto, "off": off, "r": r, "off0": off, "r0": r, "cor": cor, "modo": modo, "olhar": olhar, "voo": voo, "toque": -1})

# posições/tamanhos: padrão do botão, ou o que foi salvo no editor da HUD; tudo vezes a escala geral
# 0.97.1: os botões da CONSTRUÇÃO aparecem no lugar de outro (OK no do ATIRAR, GIRAR no do MIRAR, CANCELAR no do
# RECARREGAR): seguem a posição e o tamanho dele e não aparecem no editor da HUD (antes ficavam soltos, repetidos).
const NO_LUGAR_DE := {"OK": "ATIRAR", "GIRAR": "MIRAR", "CANCELAR": "RECARREGAR"}

func _seguir_iguais() -> void:
	for id in NO_LUGAR_DE:
		var b := _botao(id)
		var o := _botao(NO_LUGAR_DE[id])
		if not b.is_empty() and not o.is_empty():
			b["off"] = o["off"]
			b["r"] = o["r"]
			b["canto"] = o["canto"]

func aplicar_layout(pos: Dictionary, esc: float, opacidade: float) -> void:
	layout = pos.duplicate(true)
	escala = esc
	_visual.modulate.a = opacidade
	for b in botoes:
		var p = layout.get(b["id"])
		var off: Vector2 = b["off0"]
		var r: float = b["r0"]
		if p is Array and p.size() >= 3:
			off = Vector2(p[0], p[1])
			r = p[2]
		b["off"] = off * escala
		b["r"] = r * escala
	_seguir_iguais()
	_visual.queue_redraw()

func tamanho_do(id: String) -> float:
	var b := _botao(id)
	if b.is_empty():
		return 1.0
	return float(b["r"]) / escala / float(b["r0"])

func definir_tamanho(id: String, fator: float) -> void:
	var b := _botao(id)
	if b.is_empty():
		return
	var off: Vector2 = b["off"] / escala
	layout[id] = [off.x, off.y, float(b["r0"]) * fator]
	aplicar_layout(layout, escala, _visual.modulate.a)

func item_padrao(id: String) -> void:
	layout.erase(id)
	aplicar_layout(layout, escala, _visual.modulate.a)

func set_info(v: bool) -> void:
	mostrar_info = v
	info.visible = mostrar_info and not bloqueado

func set_editando(v: bool) -> void:
	editando = v
	process_mode = Node.PROCESS_MODE_ALWAYS if v else Node.PROCESS_MODE_INHERIT   # funciona com o jogo pausado
	selecionado = ""
	_arraste = -1
	_soltar_tudo()

# arrastar um botão no modo de edição (toque ou mouse emulado como toque)
func _editar(e: InputEvent) -> void:
	var vs := get_viewport().get_visible_rect().size
	if e is InputEventScreenTouch:
		if e.index != 0:
			return
		if e.pressed:
			if editar_ignorar.has_point(e.position):
				return
			var melhor := -1
			var md := INF
			for i in botoes.size():
				var b: Dictionary = botoes[i]
				if b["voo"] or NO_LUGAR_DE.has(b["id"]):
					continue
				var d: float = e.position.distance_to(_centro(b))
				if d <= float(b["r"]) * 1.2 and d < md:
					md = d
					melhor = i
			if melhor >= 0:
				_arraste = melhor
				_arraste_dif = _centro(botoes[melhor]) - e.position
				selecionado = botoes[melhor]["id"]
				selecionou.emit(selecionado)
		else:
			_arraste = -1
		_visual.queue_redraw()
	elif e is InputEventScreenDrag and _arraste >= 0 and e.index == 0:
		var b: Dictionary = botoes[_arraste]
		var c: Vector2 = (e.position + _arraste_dif).clamp(Vector2(b["r"], b["r"]), vs - Vector2(b["r"], b["r"]))
		var off := Vector2(vs.x - c.x, c.y if b["canto"] == "tr" else vs.y - c.y)
		layout[b["id"]] = [off.x / escala, off.y / escala, float(b["r"]) / escala]
		b["off"] = off
		_seguir_iguais()
		_visual.queue_redraw()

func _centro(b: Dictionary) -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	var off: Vector2 = b["off"]
	if b["canto"] == "tr":
		return Vector2(vs.x - off.x, off.y)
	return Vector2(vs.x - off.x, vs.y - off.y)

func _visivel(b: Dictionary) -> bool:
	if editando:
		return not b["voo"] and not NO_LUGAR_DE.has(b["id"])
	if bloqueado or ocultos.get(b["id"], false):
		return false
	if b["id"] == "VOO":
		return true
	if b["id"] == "INV":
		return not modo_voo
	return b["voo"] == modo_voo

func _botao(id: String) -> Dictionary:
	for b in botoes:
		if b["id"] == id:
			return b
	return {}

func segurando(id: String) -> bool:
	var b := _botao(id)
	return not b.is_empty() and int(b["toque"]) != -1

func set_modo_voo(v: bool) -> void:
	modo_voo = v
	_soltar_tudo()

# inventário aberto: solta joystick/botões e ignora o toque (a tela do inventário cuida dele)
func set_bloqueado(v: bool) -> void:
	bloqueado = v
	info.visible = mostrar_info and not v
	_soltar_tudo()
	_correr_on = false                     # 0.64: fechar o inventário não volta correndo sozinho
	_moveu = false

var _toque_roda := -1               # dedo que está segurando o ARMA (roda de armas)

func _soltar_tudo() -> void:
	_toque_roda = -1
	mover = Vector2.ZERO
	_olhar = Vector2.ZERO
	_mouse_dir = false
	_toque_mover = -1
	_toque_olhar = -1
	for b in botoes:
		b["toque"] = -1
	_visual.queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	var vs := get_viewport().get_visible_rect().size
	if editando:
		_editar(e)
		return
	if bloqueado:
		if e is InputEventKey and e.pressed and not e.echo and Teclas.casa(e, "inventario"):
			inventario_pedido.emit()
		return
	# modo PC: o "toque" que o mouse imita não conta (o mouse é lido direto, preso na tela)
	if modo_pc and (e is InputEventScreenTouch or e is InputEventScreenDrag) and e.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if e is InputEventScreenTouch:
		var t: InputEventScreenTouch = e
		if t.pressed:
			for b in botoes:
				if _visivel(b) and int(b["toque"]) == -1 and t.position.distance_to(_centro(b)) <= float(b["r"]) * 1.15:
					b["toque"] = t.index
					if b["id"] == "ARMA":
						_toque_roda = t.index      # segurar e arrastar escolhe na roda de armas
						roda_inicio.emit(t.position)
					elif b["modo"] == "tocar":
						_tocou(b["id"])
					_visual.queue_redraw()
					return
			if t.position.x < vs.x * 0.5 and _toque_mover == -1:
				_toque_mover = t.index
				_origem = t.position
				_atual = t.position
			elif t.position.x >= vs.x * 0.5 and _toque_olhar == -1:
				_toque_olhar = t.index
		else:
			for b in botoes:
				if int(b["toque"]) == t.index:
					b["toque"] = -1
			if t.index == _toque_roda:
				_toque_roda = -1
				roda_fim.emit(t.position)
			if t.index == _toque_mover:
				_toque_mover = -1
				mover = Vector2.ZERO
			if t.index == _toque_olhar:
				_toque_olhar = -1
		_visual.queue_redraw()
	elif e is InputEventScreenDrag:
		var g: InputEventScreenDrag = e
		if g.index == _toque_roda:
			roda_arrasto.emit(g.position)
		elif g.index == _toque_mover:
			_atual = g.position
			var d := ((g.position - _origem) / RAIO_STICK).limit_length(1.0)
			mover = Vector2(d.x, -d.y)
			_visual.queue_redraw()
		elif g.index == _toque_olhar:
			_olhar += g.relative
		else:
			for b in botoes:
				if int(b["toque"]) == g.index and b["olhar"]:
					_olhar += g.relative
	elif e is InputEventKey or e is InputEventMouseButton:
		_tecla(e)

# teclado e botões do mouse (teclas de jogador/teclas.gd)
func _tecla(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		if mb.pressed and roda_mouse and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if not modo_voo:
				trocar_arma_pedido.emit()
			return
		if modo_pc and _capturado:
			return                         # mouse preso: os botões são lidos em _ler_botoes_mouse (não se perdem na HUD)
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_dir = mb.pressed        # toque/mouse livre: botão direito segura a mira (como antes)
		return
	var k: InputEventKey = e
	if k.echo:
		return
	for a in Teclas.ACOES:
		if Teclas.casa(k, a[0]):
			_acao(a[0], k.pressed)
	# P (pausa) e F11 (tela cheia) são fixos, mas só valem se nenhuma ação usa a tecla (0.64)
	if k.pressed and k.keycode == KEY_P and Teclas.acao_da_tecla("k:%d" % KEY_P) == "":
		pausa_pedida.emit()
	if k.pressed and k.keycode == KEY_F11 and Teclas.acao_da_tecla("k:%d" % KEY_F11) == "":
		var w := DisplayServer.window_get_mode()
		var cheia := w == DisplayServer.WINDOW_MODE_FULLSCREEN or w == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if cheia else DisplayServer.WINDOW_MODE_FULLSCREEN)

# botões do mouse com o mouse preso: lidos direto, para pegar o aperto e a soltura de cada um
var _botoes_ant := {}

func _ler_botoes_mouse() -> void:
	for a in Teclas.ACOES:
		var c := Teclas.codigo(a[0])
		if not c.begins_with("m:"):
			continue
		var p := Input.is_mouse_button_pressed(int(c.substr(2)))
		if p != bool(_botoes_ant.get(a[0], false)):
			_botoes_ant[a[0]] = p
			_acao(a[0], p)

# o que cada ação faz ao apertar (apertou = true) ou soltar
func _acao(acao: String, apertou: bool) -> void:
	# 0.90: construindo, o clique põe a peça e o botão direito desiste (não atira nem mira)
	if construindo and acao in ["atirar", "mirar"]:
		if apertou:
			(confirmar_pedido if acao == "atirar" else cancelar_pedido).emit()
		return
	match acao:
		"mirar":
			if mirar_modo == "alternar":
				if apertou:
					mirar_pedido.emit()
			else:
				_mouse_dir = apertou
			return
		"correr":
			if correr_modo == "alternar" and apertou and not modo_voo:
				_correr_on = not _correr_on
			return
	if not apertou:
		return
	match acao:
		"agachar":
			if agachar_modo == "alternar":
				agachar_pedido.emit()
		"recarregar":
			if not construindo:
				recarregar_pedido.emit()
		"trocar_arma":
			if not modo_voo:
				trocar_arma_pedido.emit()
		"inventario":
			if not modo_voo:
				inventario_pedido.emit()
		"pegar":
			if construindo:
				confirmar_pedido.emit()
			elif not modo_voo:
				pegar_pedido.emit()
		"empurrar":
			if not modo_voo and not construindo:
				empurrar_pedido.emit()
		"sentido":
			if not modo_voo and not bool(ocultos.get("SENTIDO", true)):
				sentido_pedido.emit()
		"mutar_mic":
			if not bool(ocultos.get("MIC", true)):
				mic_pedido.emit()
		"mutar_vozes":
			if not bool(ocultos.get("VOZES", true)):
				vozes_pedido.emit()
		"construir":
			if not modo_voo:
				construir_pedido.emit()
		"girar_peca":
			if construindo:
				girar_pedido.emit()
		"roda":
			if not modo_voo:
				roda_tecla.emit()
		"voo": voo_pedido.emit()
		"camera":
			if not modo_voo:
				camera_pedida.emit()
		"ombro":
			if not modo_voo:
				ombro_pedido.emit()
		"voo_vel":
			if modo_voo:
				vel_pedida.emit()
		"pausa": pausa_pedida.emit()
		"mensagem":
			if not ocultos.get("MSG", true):
				mensagem_pedida.emit()
		_:
			if acao.begins_with("atalho_") and not modo_voo:
				atalho_pedido.emit(int(acao.substr(7)) - 1)

# ---------- modo PC x toque (0.62) ----------
func _comeca_no_pc() -> bool:
	if preferencia == "pc":
		return true
	if preferencia == "toque":
		return false
	# automático: no PC (sem tela de toque) começa no teclado e mouse; no celular, no toque
	return not OS.has_feature("mobile")   # (a Godot diz "tem toque" no PC porque o projeto imita toque com o mouse)

# opções de Opções › Teclado e mouse (menu/aplicar_opcoes.gd)
func configurar_teclado(o: Dictionary) -> void:
	preferencia = str(o.get("entrada", "auto"))
	mirar_modo = str(o.get("mirar_modo", "segurar"))
	agachar_modo = str(o.get("agachar_modo", "alternar"))
	correr_modo = str(o.get("correr_modo", "segurar"))
	roda_mouse = bool(o.get("roda_mouse", true))
	dicas = bool(o.get("dicas_teclas", true))
	Teclas.carregar(o.get("teclas", {}))
	if preferencia != "auto":
		_definir_modo(preferencia == "pc")

func _definir_modo(pc: bool) -> void:
	if pc == modo_pc:
		return
	modo_pc = pc
	_soltar_tudo()
	_correr_on = false

# descobre o que o jogador está usando: teclado/mouse de verdade -> PC · dedo na tela -> toque
func _input(e: InputEvent) -> void:
	if preferencia == "auto" and not editando and not _digitando():
		if e is InputEventKey and e.pressed and not e.echo and e.keycode not in [KEY_BACK, KEY_VOLUMEUP, KEY_VOLUMEDOWN, KEY_UNKNOWN]:
			# no celular, tecla só conta se for de jogo (o teclado da tela, digitando um nome, não vira "PC")
			if not OS.has_feature("mobile") or _tecla_de_jogo(e):
				_definir_modo(true)
		elif (e is InputEventMouseMotion or e is InputEventMouseButton) and e.device != InputEvent.DEVICE_ID_EMULATION:
			if not (e is InputEventMouseMotion) or (e as InputEventMouseMotion).relative.length() > 3.0:
				_definir_modo(true)
		elif e is InputEventScreenTouch and e.pressed and e.device != InputEvent.DEVICE_ID_EMULATION:
			_definir_modo(false)
	# mouse preso: o movimento é o olhar
	if modo_pc and _capturado and e is InputEventMouseMotion and not bloqueado and visible:
		_olhar_mouse += (e as InputEventMouseMotion).relative

# 0.64: digitando num campo de texto (nome, código da sala...): as letras não trocam o modo de controle
func _digitando() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

func _tecla_de_jogo(e: InputEvent) -> bool:
	for a in Teclas.ACOES:
		if Teclas.casa(e, a[0]):
			return true
	return false

func _quer_mouse_preso() -> bool:
	# 0.64: controles escondidos (cena de cinema etc.) soltam o mouse, para clicar nos botões da tela
	return modo_pc and visible and not bloqueado and not editando and not mouse_solto and is_inside_tree() \
		and not get_tree().paused and DisplayServer.window_is_focused() and process_mode != Node.PROCESS_MODE_DISABLED

# pausa (o jogo para e este nó também): solta o mouse na hora para clicar no menu
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _capturado:
		_capturado = false
		_mouse_dir = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	if _capturado:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_capturado = false

func _tocou(id: String) -> void:
	match id:
		"AGACHAR": agachar_pedido.emit()
		"MIRAR": mirar_pedido.emit()
		"RECARREGAR": recarregar_pedido.emit()
		"ARMA": trocar_arma_pedido.emit()
		"VOO": voo_pedido.emit()
		"VEL": vel_pedida.emit()
		"INV": inventario_pedido.emit()
		"PAUSA": pausa_pedida.emit()
		"PEGAR": pegar_pedido.emit()
		"CAM": camera_pedida.emit()
		"OMBRO": ombro_pedido.emit()
		"MSG": mensagem_pedida.emit()
		"EMPURRAR": empurrar_pedido.emit()
		"SENTIDO": sentido_pedido.emit()
		"MIC": mic_pedido.emit()
		"VOZES": vozes_pedido.emit()
		"CONSTRUIR": construir_pedido.emit()
		"GIRAR": girar_pedido.emit()
		"OK": confirmar_pedido.emit()
		"CANCELAR": cancelar_pedido.emit()

# OTIMIZAÇÃO: redesenha só quando algo que aparece mudou (botão aceso, texto, botão escondido, bloqueio).
# Os toques já pedem redesenho na hora (_input). Antes redesenhava todos os botões em todo quadro.
var _assinatura := 0

func _process(_dt: float) -> void:
	var quer := _quer_mouse_preso()
	if quer != _capturado:
		_capturado = quer
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if quer else Input.MOUSE_MODE_VISIBLE
		_olhar_mouse = Vector2.ZERO
		_botoes_ant.clear()
		if not quer:
			_mouse_dir = false
	if _capturado:
		_ler_botoes_mouse()
	_visual.visible = editando or not modo_pc
	_atualizar_dica()
	var a := indicadores.hash() ^ (textos.hash() * 31) ^ (ocultos.hash() * 17) ^ (icones.hash() * 7) ^ (1 if bloqueado else 0) ^ (2 if editando else 0)
	if a != _assinatura:
		_assinatura = a
		_visual.queue_redraw()

func _desenhar() -> void:
	if bloqueado and not editando:
		return
	# OTIMIZAÇÃO: primeiro TODAS as formas, depois TODOS os textos. Intercalar círculo/texto/círculo/texto troca de
	# textura (a fonte) a cada botão e quebra o "lote" do desenho 2D: virava ~2 chamadas de desenho por botão.
	var textos_b := []
	for b in botoes:
		if not _visivel(b):
			continue
		var c := _centro(b)
		var r: float = b["r"]
		var cor: Color = b["cor"]
		var aceso := int(b["toque"]) != -1 or bool(indicadores.get(b["id"], false))
		UI.circulo(_visual, c, r, Color(cor.r, cor.g, cor.b, 0.62 if aceso else 0.22))
		textos_b.append([b, c, r])
	# depois todos os contornos (mesma textura seguida = um lote só)
	for e in textos_b:
		var b: Dictionary = e[0]
		var cor: Color = b["cor"]
		UI.aro_prop(_visual, e[1], e[2] + 2.0, 4.0 / 57.0, Color(cor.r, cor.g, cor.b, 0.95))   # ~4 px, meio para fora (como antes)
	if editando:                                         # só na edição da HUD (raro): pode ser o desenho comum
		for e in textos_b:
			var sel: bool = e[0]["id"] == selecionado
			_visual.draw_arc(e[1], e[2] + 6.0, 0.0, TAU, 48, Color(1.0, 0.71, 0.0) if sel else Color(1, 1, 1, 0.75), 5.0 if sel else 2.0)
	# ícones: sombra + ícone, todos da mesma folha (um lote só)
	var com_icone := {}
	for e in textos_b:
		var b: Dictionary = e[0]
		var i := ICONES.find(str(icones.get(b["id"], b["id"])))
		if i < 0:
			continue
		com_icone[b["id"]] = true
		var r: float = e[2]
		var lado := r * (1.05 if b["id"] in ["ARMA", "PEGAR"] else (1.2 if r >= 36.0 else 1.35))   # ARMA/PEGAR têm o nome embaixo
		var c: Vector2 = e[1] - Vector2(0.0, r * 0.12 if b["id"] in ["ARMA", "PEGAR"] else 0.0)
		var orig := Rect2((i % 8) * 128.0, (i / 8) * 128.0, 128.0, 128.0)
		var dest := Rect2(c - Vector2(lado, lado) * 0.5, Vector2(lado, lado))
		_visual.draw_texture_rect_region(FOLHA_ICONES, Rect2(dest.position + Vector2(1.5, 1.5), dest.size), orig, Color(0, 0, 0, 0.55))
		_visual.draw_texture_rect_region(FOLHA_ICONES, dest, orig, Color(1, 1, 1, 0.95))
	if _toque_mover != -1:
		var d := (_atual - _origem).limit_length(RAIO_STICK)
		_visual.draw_circle(_origem, RAIO_STICK, Color(1, 1, 1, 0.10))
		_visual.draw_arc(_origem, RAIO_STICK, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
		_visual.draw_circle(_origem + d, 36.0, Color(1, 1, 1, 0.35))
	for e in textos_b:
		var b: Dictionary = e[0]
		var c: Vector2 = e[1]
		var r: float = e[2]
		var txt: String = textos.get(b["id"], b["txt"])
		if com_icone.has(b["id"]):
			if b["id"] != "ARMA" and b["id"] != "PEGAR":
				continue
			# ARMA: nome da arma · PEGAR: sigla do item ("PEGAR\nM4A1" -> "M4A1"), pequeno embaixo do ícone
			var nome: String = txt.split("\n")[-1]
			var tn := 13 if r >= 40 else 11
			var wn := _fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tn).x
			if wn > r * 1.6:
				tn = maxi(8, int(tn * r * 1.6 / wn))
				wn = _fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tn).x
			_visual.draw_string(_fonte, Vector2(c.x - wn * 0.5, c.y + r * 0.72), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tn, Color(1, 1, 1, 0.95))
			continue
		# texto em até 2 linhas, diminuindo até caber dentro do círculo (ex.: "RECARREGAR", "PEGAR\nM4A1")
		var linhas := txt.split("\n")
		var tam := 20 if r >= 55 else 17
		var larg := 0.0
		for l in linhas:
			larg = maxf(larg, _fonte.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x)
		if larg > r * 1.7:
			tam = maxi(9, int(tam * r * 1.7 / larg))
		var y0 := c.y + tam * 0.35 - (linhas.size() - 1) * tam * 0.55
		for k in linhas.size():
			var l: String = linhas[k]
			var tk := tam if k == 0 else int(tam * 0.8)
			var w := _fonte.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, tk).x
			_visual.draw_string(_fonte, Vector2(c.x - w * 0.5, y0 + k * tam * 1.05), l, HORIZONTAL_ALIGNMENT_LEFT, -1, tk, Color(1, 1, 1, 0.95))

# ---------- leitura (o jogador consulta todo quadro) ----------
func vetor_mover() -> Vector2:
	if bloqueado:
		return Vector2.ZERO
	var k := Vector2.ZERO
	if Teclas.apertado("frente") or _seta(KEY_UP): k.y += 1.0
	if Teclas.apertado("tras") or _seta(KEY_DOWN): k.y -= 1.0
	if Teclas.apertado("direita") or _seta(KEY_RIGHT): k.x += 1.0
	if Teclas.apertado("esquerda") or _seta(KEY_LEFT): k.x -= 1.0
	if k != Vector2.ZERO:
		_moveu = true
		return k.normalized()
	if _moveu:                             # parou depois de andar: a corrida "alternar" desliga
		_correr_on = false                 # (ligar parado e depois andar continua valendo)
		_moveu = false
	return mover

# setas andam também, a não ser que a seta tenha virado tecla de outra ação (0.64)
func _seta(tecla: Key) -> bool:
	return Input.is_key_pressed(tecla) and Teclas.acao_da_tecla("k:%d" % tecla) == ""

# PC: segurar a tecla "andar" (Alt) anda (caminhada) em vez de trotar
func andando_pc() -> bool:
	return not bloqueado and Teclas.apertado("andar")

func correndo() -> bool:
	if bloqueado:
		return false
	var tecla := _correr_on if correr_modo == "alternar" else Teclas.apertado("correr")
	return segurando("CORRER") or (tecla and not modo_voo)

func pulando() -> bool:
	return not bloqueado and (segurando("PULAR") or Teclas.apertado("pular"))

func atirando() -> bool:
	if bloqueado:
		return false
	if segurando("ATIRAR"):
		return true
	var c := Teclas.codigo("atirar")
	if c.begins_with("m:"):
		return modo_pc and _capturado and Teclas.apertado("atirar")     # clique só vale com o mouse preso no jogo
	return Teclas.apertado("atirar")

func mirando_segurado() -> bool:
	return _mouse_dir and not bloqueado

# agachar no modo "segurar": -1 = não está nesse modo · 0 = solto (em pé) · 1 = segurando (agachado)
func agachar_segurado() -> int:
	if agachar_modo != "segurar" or bloqueado or not modo_pc:
		return -1
	return 1 if Teclas.apertado("agachar") else 0

func vertical() -> float:
	var v := 0.0
	if segurando("SOBE"): v = 1.0
	if segurando("DESCE"): v = -1.0
	if Teclas.apertado("voo_sobe"): v = 1.0
	if Teclas.apertado("voo_desce"): v = -1.0
	return v

# quanto o dedo arrastou para olhar desde a última chamada (pixels)
func consumir_olhar() -> Vector2:
	if bloqueado:
		_olhar = Vector2.ZERO
	var r := _olhar
	_olhar = Vector2.ZERO
	return r

# quanto o MOUSE (preso) andou desde a última chamada (pixels); o jogador aplica a sensibilidade do mouse
func consumir_olhar_mouse() -> Vector2:
	var r := _olhar_mouse if not bloqueado else Vector2.ZERO
	_olhar_mouse = Vector2.ZERO
	return r

# dica de tecla no modo PC (o botão PEGAR some com a HUD de toque)
var _dica_txt := ""

func _atualizar_dica() -> void:
	var t := ""
	if modo_pc and dicas and not bloqueado and not editando and not modo_voo and not ocultos.get("PEGAR", false):
		t = "[%s]  %s" % [Teclas.texto_de("pegar"), str(textos.get("PEGAR", "PEGAR")).replace("\n", " ")]
	if t != _dica_txt:
		_dica_txt = t
		_dica.text = t
		_dica.visible = t != ""
