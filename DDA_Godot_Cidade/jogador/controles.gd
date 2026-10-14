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
# PC: WASD andar · Shift correr · Espaço pular · C/Ctrl agachar · F atirar · botão direito do mouse mirar
#     R recarregar · 1..8 atalhos (1 = pistola, 2 = M4) · rodinha troca arma · Tab ou I inventário · E pegar
#     mouse arrastando na metade direita = olhar · Q/E sobem/descem no voo
# Com o inventário aberto (bloqueado = true) os controles ficam neutros: o jogador para e nada é desenhado.

signal voo_pedido
signal vel_pedida
signal agachar_pedido
signal mirar_pedido
signal recarregar_pedido
signal trocar_arma_pedido
signal atalho_pedido(indice: int)
signal inventario_pedido
signal pegar_pedido
signal pausa_pedida
signal selecionou(id: String)      # modo de edição da HUD: botão tocado

const RAIO_STICK := 90.0

var mover := Vector2.ZERO          # x = direita, y = frente
var modo_voo := false
var info: Label
var indicadores := {}              # id -> bool (botão aceso: AGACHAR/MIRAR ligados)
var textos := {}                   # id -> texto trocado em tempo real (ex.: nome da arma)
var ocultos := {}                  # id -> true para esconder o botão (ex.: PEGAR sem item perto)
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

func _ready() -> void:
	layer = 10
	_fonte = ThemeDB.fallback_font
	_visual = Control.new()
	_visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.draw.connect(_desenhar)
	add_child(_visual)
	info = Label.new()
	info.position = Vector2(16.0, 12.0)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(info)
	#        id            texto          canto  distância do canto     raio  cor                         modo       olhar  só no voo
	_bt("ATIRAR", "ATIRAR", "br", Vector2(215, 250), 70, Color(0.88, 0.02, 0.0), "segurar", true, false)
	_bt("CORRER", "CORRER", "br", Vector2(90, 125), 60, Color(0.11, 0.56, 0.30), "segurar", false, false)
	_bt("PULAR", "PULAR", "br", Vector2(78, 330), 46, Color(0.75, 0.75, 0.80), "segurar", false, false)
	_bt("AGACHAR", "AGACHAR", "br", Vector2(228, 95), 44, Color(0.62, 0.66, 0.70), "tocar", false, false)
	_bt("MIRAR", "MIRAR", "br", Vector2(355, 335), 46, Color(0.95, 0.95, 0.95), "tocar", false, false)
	_bt("RECARREGAR", "RECARREGAR", "br", Vector2(362, 168), 40, Color(0.23, 0.63, 1.0), "tocar", false, false)
	_bt("ARMA", "ARMA", "br", Vector2(482, 282), 44, Color(1.0, 0.71, 0.0), "tocar", false, false)
	_bt("PEGAR", "PEGAR", "br", Vector2(500, 150), 40, Color(0.35, 0.85, 0.45), "tocar", false, false)
	_bt("VOO", "VOO", "tr", Vector2(56, 46), 30, Color(0.6, 0.6, 0.6), "tocar", false, false)
	_bt("INV", "INV", "tr", Vector2(132, 46), 30, Color(1.0, 0.71, 0.0), "tocar", false, false)
	_bt("PAUSA", "II", "tr", Vector2(208, 46), 30, Color(1.0, 0.54, 0.21), "tocar", false, false)
	ocultos["PEGAR"] = true
	_bt("SOBE", "SOBE", "br", Vector2(80, 330), 50, Color(0.6, 0.6, 0.6), "segurar", false, true)
	_bt("DESCE", "DESCE", "br", Vector2(80, 210), 50, Color(0.6, 0.6, 0.6), "segurar", false, true)
	_bt("VEL", "VEL", "br", Vector2(80, 90), 44, Color(0.6, 0.6, 0.6), "tocar", false, true)
	get_viewport().size_changed.connect(func(): _visual.queue_redraw())

func _bt(id: String, txt: String, canto: String, off: Vector2, r: float, cor: Color, modo: String, olhar: bool, voo: bool) -> void:
	botoes.append({"id": id, "txt": txt, "canto": canto, "off": off, "r": r, "off0": off, "r0": r, "cor": cor, "modo": modo, "olhar": olhar, "voo": voo, "toque": -1})

# posições/tamanhos: padrão do botão, ou o que foi salvo no editor da HUD; tudo vezes a escala geral
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
				if b["voo"]:
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
		_visual.queue_redraw()

func _centro(b: Dictionary) -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	var off: Vector2 = b["off"]
	if b["canto"] == "tr":
		return Vector2(vs.x - off.x, off.y)
	return Vector2(vs.x - off.x, vs.y - off.y)

func _visivel(b: Dictionary) -> bool:
	if editando:
		return not b["voo"]
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

func _soltar_tudo() -> void:
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
		if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_TAB or e.keycode == KEY_I):
			inventario_pedido.emit()
		return
	if e is InputEventScreenTouch:
		var t: InputEventScreenTouch = e
		if t.pressed:
			for b in botoes:
				if _visivel(b) and int(b["toque"]) == -1 and t.position.distance_to(_centro(b)) <= float(b["r"]) * 1.15:
					b["toque"] = t.index
					if b["modo"] == "tocar":
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
			if t.index == _toque_mover:
				_toque_mover = -1
				mover = Vector2.ZERO
			if t.index == _toque_olhar:
				_toque_olhar = -1
		_visual.queue_redraw()
	elif e is InputEventScreenDrag:
		var g: InputEventScreenDrag = e
		if g.index == _toque_mover:
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
	elif e is InputEventKey:
		var k: InputEventKey = e
		if k.pressed and not k.echo:
			match k.keycode:
				KEY_C, KEY_CTRL: agachar_pedido.emit()
				KEY_R, KEY_T: recarregar_pedido.emit()
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
					if not modo_voo:
						atalho_pedido.emit(k.keycode - KEY_1)
				KEY_TAB, KEY_I:
					if not modo_voo:
						inventario_pedido.emit()
				KEY_E:
					if not modo_voo:
						pegar_pedido.emit()
				KEY_V: voo_pedido.emit()
				KEY_ESCAPE, KEY_P: pausa_pedida.emit()
	elif e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_dir = mb.pressed
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			trocar_arma_pedido.emit()

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

func _process(_dt: float) -> void:
	_visual.queue_redraw()

func _desenhar() -> void:
	if bloqueado and not editando:
		return
	for b in botoes:
		if not _visivel(b):
			continue
		var c := _centro(b)
		var r: float = b["r"]
		var cor: Color = b["cor"]
		var aceso := int(b["toque"]) != -1 or bool(indicadores.get(b["id"], false))
		if editando:
			var sel: bool = b["id"] == selecionado
			_visual.draw_arc(c, r + 6.0, 0.0, TAU, 48, Color(1.0, 0.71, 0.0) if sel else Color(1, 1, 1, 0.75), 5.0 if sel else 2.0)
		_visual.draw_circle(c, r, Color(cor.r, cor.g, cor.b, 0.62 if aceso else 0.22))
		_visual.draw_arc(c, r, 0.0, TAU, 40, Color(cor.r, cor.g, cor.b, 0.95), 4.0)
		var txt: String = textos.get(b["id"], b["txt"])
		var tam := 20 if r >= 55 else (15 if txt.length() > 7 else 17)
		var w := _fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		_visual.draw_string(_fonte, c + Vector2(-w * 0.5, tam * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1, 1, 1, 0.95))
	if _toque_mover != -1:
		var d := (_atual - _origem).limit_length(RAIO_STICK)
		_visual.draw_circle(_origem, RAIO_STICK, Color(1, 1, 1, 0.10))
		_visual.draw_arc(_origem, RAIO_STICK, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
		_visual.draw_circle(_origem + d, 36.0, Color(1, 1, 1, 0.35))

# ---------- leitura (o jogador consulta todo quadro) ----------
func vetor_mover() -> Vector2:
	if bloqueado:
		return Vector2.ZERO
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): k.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): k.y -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): k.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): k.x -= 1.0
	if k != Vector2.ZERO:
		return k.normalized()
	return mover

func correndo() -> bool:
	return not bloqueado and (segurando("CORRER") or Input.is_key_pressed(KEY_SHIFT))

func pulando() -> bool:
	return not bloqueado and (segurando("PULAR") or Input.is_key_pressed(KEY_SPACE))

func atirando() -> bool:
	return not bloqueado and (segurando("ATIRAR") or Input.is_key_pressed(KEY_F))

func mirando_segurado() -> bool:
	return _mouse_dir and not bloqueado

func vertical() -> float:
	var v := 0.0
	if segurando("SOBE"): v = 1.0
	if segurando("DESCE"): v = -1.0
	if Input.is_key_pressed(KEY_E): v = 1.0
	if Input.is_key_pressed(KEY_Q): v = -1.0
	return v

# quanto o dedo arrastou para olhar desde a última chamada (pixels)
func consumir_olhar() -> Vector2:
	if bloqueado:
		_olhar = Vector2.ZERO
	var r := _olhar
	_olhar = Vector2.ZERO
	return r
