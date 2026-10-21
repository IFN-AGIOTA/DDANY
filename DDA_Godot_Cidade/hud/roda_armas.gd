extends CanvasLayer
# RODA DE ARMAS (0.56): o botão ARMA abre uma roda com as ARMAS do INVENTÁRIO RÁPIDO (atalhos 1..8 do
# inventario/inventario.gd; o que não é arma fica de fora). No meio: GUARDAR (mãos livres).
#   · SEGURAR e ARRASTAR: segure ARMA, arraste o dedo na direção da arma e solte = troca.
#   · TOCAR: toque rápido em ARMA = a roda fica aberta; toque na arma (ou no meio para guardar). Fora fecha.
#   · PC: tecla Q abre/fecha (clique escolhe). A rodinha do mouse continua trocando direto.
# Jogando sozinho o tempo fica mais lento enquanto a roda está aberta (em rede não: os outros continuam).
# Cada fatia mostra a foto da arma (inventario/visual.gd), o nome, as balas (pente + reserva) e o número do
# atalho; a arma que está na mão fica marcada.
# Mexa AQUI para: tamanho da roda, lentidão, zona morta do arraste.

const UI := preload("res://menu/ui.gd")
const Visual := preload("res://inventario/visual.gd")
const Sons := preload("res://audio/sons.gd")
const RAIO := 30.0                 # vh (raio da roda)
const MIOLO := 0.34                # fração do raio: círculo do meio (GUARDAR)
const ZONA_MORTA := 3.5            # vh de arraste até começar a escolher
const LENTO := 0.3                 # velocidade do jogo com a roda aberta (sozinho)

signal aviso(texto: String)

var inv                            # inventario/inventario.gd
var controles
var aberta := false
var _itens: Array = []             # [{"i": índice do atalho, "it": item}]
var _sel := -2                     # -2 nada · -1 GUARDAR · 0.. fatia
var _modo := ""                    # "arraste" (dedo no ARMA) ou "toque" (roda parada esperando um toque)
var _inicio := Vector2.ZERO
var _moveu := false
var _tela: Control
var _tempo_antes := 1.0

func ligar(c, inventario) -> void:
	controles = c
	inv = inventario
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS      # fecha sozinha se o jogo pausar
	_tela = Control.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	visible = false
	c.roda_inicio.connect(_inicio_arraste)
	c.roda_arrasto.connect(_arrastou)
	c.roda_fim.connect(_soltou)
	c.roda_tecla.connect(func(): fechar() if aberta else abrir("toque", Vector2.ZERO))

# ---------- abrir / fechar ----------
func abrir(modo: String, pos: Vector2) -> void:
	_itens.clear()
	for i in inv.atalhos.size():
		var it = inv.atalhos[i]
		if it != null and it.eh_arma() and inv.do_jogador(it):
			_itens.append({"i": i, "it": it})
	if _itens.is_empty():
		aviso.emit("NENHUMA ARMA NO INVENTÁRIO RÁPIDO")
		return
	aberta = true
	visible = true
	_modo = modo
	_inicio = pos
	_moveu = false
	_sel = -2
	var na_mao = inv.slots.get("maos")
	for k in _itens.size():
		if _itens[k]["it"] == na_mao:
			_sel = k
	_tempo_antes = Engine.time_scale
	if not Rede.ligado:
		Engine.time_scale = LENTO
	Sons.ui("abrir", -6.0)
	_tela.queue_redraw()

func fechar() -> void:
	if not aberta:
		return
	aberta = false
	visible = false
	Engine.time_scale = _tempo_antes if _tempo_antes > 0.0 else 1.0

func _confirmar() -> void:
	var s := _sel
	fechar()
	var na_mao = inv.slots.get("maos")
	if s == -1:
		if na_mao != null:
			inv.desequipar(na_mao)
	elif s >= 0 and s < _itens.size():
		var it = _itens[s]["it"]
		if it != na_mao:
			inv.equipar(it, "maos")

# ---------- entrada ----------
# dedo no botão ARMA (controles.gd): começa no modo arraste
func _inicio_arraste(pos: Vector2) -> void:
	if aberta:
		fechar()                       # tocou de novo no ARMA com a roda aberta: fecha
		return
	abrir("arraste", pos)

func _arrastou(pos: Vector2) -> void:
	if not aberta or _modo != "arraste":
		return
	var d := pos - _inicio
	if d.length() < ZONA_MORTA * UI.vh(_tela) and not _moveu:
		return
	_moveu = true
	_escolher_direcao(d, d.length() < ZONA_MORTA * UI.vh(_tela))

func _soltou(_pos: Vector2) -> void:
	if not aberta or _modo != "arraste":
		return
	if _moveu:
		_confirmar()
	else:
		_modo = "toque"                # toque rápido: a roda fica aberta esperando escolher

# modo toque (e mouse no PC): toque/clique na roda
func _input(e: InputEvent) -> void:
	if not aberta or _modo != "toque":
		return
	var pos := Vector2.ZERO
	var solto := false
	if e is InputEventScreenTouch:
		pos = e.position
		solto = not e.pressed
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		solto = not e.pressed
	elif e is InputEventMouseMotion or e is InputEventScreenDrag:
		var c := _centro()
		var d: Vector2 = e.position - c
		if d.length() <= RAIO * UI.vh(_tela) * 1.15:
			_escolher_direcao(d, d.length() < RAIO * UI.vh(_tela) * MIOLO)
		return
	else:
		return
	get_viewport().set_input_as_handled()
	if not solto:
		return
	var d2 := pos - _centro()
	var r := RAIO * UI.vh(_tela)
	if d2.length() > r * 1.25:
		fechar()                       # fora da roda: cancela
		return
	_escolher_direcao(d2, d2.length() < r * MIOLO)
	_confirmar()

# direção -> fatia (0 = em cima, sentido horário); no_meio = GUARDAR
func _escolher_direcao(d: Vector2, no_meio: bool) -> void:
	var antes := _sel
	if no_meio:
		_sel = -1
	else:
		var n := _itens.size()
		var a := fposmod(atan2(d.x, -d.y), TAU)      # 0 = para cima, cresce no sentido horário
		_sel = int(floor((a + PI / n) / (TAU / n))) % n
	if _sel != antes:
		Sons.ui("tique", -2.0)
		_tela.queue_redraw()

# balas de reserva: soltas + as dos pentes do tipo da arma (igual à HUD, armas/armas.gd estado())
func _reserva(it) -> int:
	var r: int = inv.contar(String(it.def().get("municao", "")))
	var tipo: String = it.usa_pente()
	if tipo != "":
		for g in inv.grades_do_jogador():
			for o in g.itens:
				if o.id == tipo:
					r += o.municao
	return r

func _process(_dt: float) -> void:
	if aberta and (inv == null or get_tree().paused or (controles != null and controles.bloqueado)):
		fechar()

# ---------- desenho ----------
func _centro() -> Vector2:
	return _tela.size * 0.5

func _desenhar() -> void:
	if not aberta:
		return
	var v := UI.vh(_tela)
	var c := _centro()
	var r := RAIO * v
	var rm := r * MIOLO
	var n := _itens.size()
	_tela.draw_rect(Rect2(Vector2.ZERO, _tela.size), Color(0, 0, 0, 0.35))
	UI.circulo(_tela, c, r * 1.04, Color(0.06, 0.03, 0.02, 0.82))
	var f := UI.fonte(800)
	var na_mao = inv.slots.get("maos")
	for k in n:
		var a0 := -PI * 0.5 + (k - 0.5) * TAU / n
		var a1 := a0 + TAU / n
		var sel := k == _sel
		var pts := PackedVector2Array()
		var passos := 18
		for s in passos + 1:
			var a := lerpf(a0, a1, float(s) / passos)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		for s in range(passos, -1, -1):
			var a := lerpf(a0, a1, float(s) / passos)
			pts.append(c + Vector2(cos(a), sin(a)) * (rm + 0.4 * v))
		var cor := Color(1.0, 0.48, 0.1, 0.78) if sel else Color(0.22, 0.10, 0.04, 0.70)
		_tela.draw_colored_polygon(pts, cor)
		_tela.draw_polyline(pts, Color(1.0, 0.67, 0.35, 0.55 if sel else 0.25), maxf(1.0, 0.25 * v), true)
		# conteúdo da fatia: foto, nome, balas, número do atalho
		var am := (a0 + a1) * 0.5
		var meio := c + Vector2(cos(am), sin(am)) * (rm + r) * 0.5
		var it = _itens[k]["it"]
		var lado := (r - rm) * 0.62
		var img := Visual._imagem_item(it)
		if img != null:
			var ts := img.get_size()
			var e := minf(lado * 1.5 / ts.x, lado * 0.62 / ts.y)
			_tela.draw_texture_rect(img, Rect2(meio - ts * e * 0.5 - Vector2(0, 1.2 * v), ts * e), false)
		var nome: String = it.def().get("sigla", it.nome())
		var tn := int(2.3 * v)
		var w := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tn).x
		Visual.texto(_tela, f, nome, meio + Vector2(-w * 0.5, lado * 0.42 + 0.6 * v), tn, Color.WHITE)
		if it.eh_arma_de_fogo():
			var res := _reserva(it)
			var balas := "%s / %d" % [it.rotulo(), res]
			var tb := int(2.0 * v)
			var wb := f.get_string_size(balas, HORIZONTAL_ALIGNMENT_LEFT, -1, tb).x
			Visual.texto(_tela, f, balas, meio + Vector2(-wb * 0.5, lado * 0.42 + 3.0 * v), tb, UI.AMBAR)
		var num := str(int(_itens[k]["i"]) + 1)
		var pn := c + Vector2(cos(am), sin(am)) * (r - 2.2 * v)
		Visual.texto(_tela, f, num, pn - Vector2(0.6 * v, -0.8 * v), int(2.0 * v), Color(1, 1, 1, 0.55))
		if it == na_mao:                     # na mão: bolinha verde ao lado do número do atalho (na borda)
			var pm := c + Vector2(cos(am), sin(am)) * (r - 2.2 * v) + Vector2(2.4 * v, -0.1 * v)
			UI.circulo(_tela, pm, 0.8 * v, Color("#7dff8a"))
	# meio: GUARDAR
	var sm := _sel == -1
	UI.circulo(_tela, c, rm, Color(1.0, 0.48, 0.1, 0.85) if sm else Color(0.12, 0.05, 0.02, 0.9))
	var tg := int(2.4 * v)
	var t1 := "GUARDAR" if na_mao != null else "MÃOS"
	var w1 := f.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, tg).x
	Visual.texto(_tela, f, t1, c + Vector2(-w1 * 0.5, 0.8 * v), tg, Color.WHITE)
	var dica := "arraste e solte" if _modo == "arraste" else "toque na arma · fora fecha"
	var td := int(2.0 * v)
	var wd := f.get_string_size(dica, HORIZONTAL_ALIGNMENT_LEFT, -1, td).x
	Visual.texto(_tela, f, dica, c + Vector2(-wd * 0.5, r * 1.04 + 3.2 * v), td, Color(1, 0.91, 0.82, 0.8))

func _exit_tree() -> void:
	if aberta:
		Engine.time_scale = 1.0              # saiu da partida com a roda aberta: o tempo volta ao normal
