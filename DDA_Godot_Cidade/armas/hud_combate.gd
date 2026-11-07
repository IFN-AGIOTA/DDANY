extends CanvasLayer
# HUD DE COMBATE (porte do HTML): mira no centro que abre com movimento/pulo/disparo (0.65: só no modo MIRA),
# ícone de PENTE embaixo no meio que muda de cor (0.65 · HUD mínima, sem números nem barra),
# marcador de acerto ✕ (vermelho = tiro na cabeça / abate) e avisos rápidos ("SEM MUNIÇÃO", nome da arma, itens pegos).
# Sem arma nas mãos o painel de munição some.
# Tamanhos em "vh" (1% da altura da tela), como no HTML.

const HudStatus := preload("res://hud/hud_status.gd")
const AMBAR := Color(1.0, 0.71, 0.0)
const VERMELHO := Color(0.88, 0.02, 0.0)

var armas: Node = null
var escala := 1.0                   # Opções › HUD › Tamanho geral
var jogador: Node = null

var _tela: Control
var _gap := 1.2
var _hit := 0.0
var _hit_cor := Color.WHITE
var _avisos: Array = []               # fila de avisos [texto, tempo restante] (até 3 na tela)
const DUR_AVISO := 1.8
var _fonte: Font

func _ready() -> void:
	layer = 5
	_fonte = ThemeDB.fallback_font
	_tela = Control.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)

# Opções › HUD: opacidade e tamanho
func aplicar_estilo(esc: float, opacidade: float) -> void:
	escala = esc
	_tela.modulate.a = opacidade

func ligar(a: Node, j: Node) -> void:
	armas = a
	jogador = j
	armas.acertou.connect(_acertou)
	armas.aviso.connect(mostrar_aviso)
	var inv = j.get("inventario")
	if inv != null:
		inv.aviso.connect(mostrar_aviso)

# 0.99: Opções › HUD › "Avisos no meio da tela" (desligados por padrão): sem eles, nenhum aviso aparece
func mostrar_aviso(t: String, dur := DUR_AVISO) -> void:
	if not bool(Config.valor("avisos")):
		return
	for a in _avisos:                   # o mesmo aviso de novo só renova o tempo
		if a[0] == t:
			a[1] = dur
			return
	_avisos.append([t, dur])
	if _avisos.size() > 3:
		_avisos.pop_front()

func _acertou(cabeca: bool, matou: bool) -> void:
	_hit = 1.0
	_hit_cor = VERMELHO if (cabeca or matou) else Color.WHITE

func _process(dt: float) -> void:
	_hit = maxf(0.0, _hit - dt * 4.0)
	for a in _avisos:
		a[1] -= dt
	while not _avisos.is_empty() and _avisos[0][1] <= 0.0:
		_avisos.pop_front()
	if armas != null:
		# mesma fórmula do HTML: g = 0,7 + dispersão·140 + coice·0,9 (em vh)
		var alvo: float = 0.7 + armas.dispersao() * 140.0 + armas.rec * 0.9
		_gap += (alvo - _gap) * minf(1.0, dt * 18.0)
	_tela.visible = jogador == null or (bool(jogador.ativo) and not _inventario_aberto())
	# OTIMIZAÇÃO: redesenha só quando algo na tela mudou (antes: todo quadro)
	var anima: bool = _hit > 0.0 or not _avisos.is_empty() or (armas != null and armas.rel > 0.0)
	var mirando := jogador == null or bool(jogador.get("mirando"))
	var a := 0
	if armas != null:
		var A: Dictionary = armas.estado() if armas.atual != "" and not armas.eh_corpo() else {"mag": 0, "res": 0}
		if armas.atual != "" and not armas.eh_corpo() and int(A["mag"]) <= 0:
			anima = true                    # pente vazio pisca
		a = hash([armas.atual, A["mag"], A["res"], armas.travada, mirando, armas.item_arma.pente_id if armas.item_arma != null else "",
			roundi(_gap * 40.0), _tela.visible, _tela.get_viewport_rect().size])
	if anima or a != _assinatura or _anima_antes:
		_assinatura = a
		_tela.queue_redraw()
	_anima_antes = anima                    # mais um quadro depois que a animação acaba (some o marcador)

var _assinatura := 0
var _anima_antes := false

func _inventario_aberto() -> bool:
	var c = jogador.get("controles")
	return c != null and bool(c.bloqueado)

func _texto(txt: String, centro_x: float, base_y: float, tam: int, cor: Color) -> void:
	var w := _fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_tela.draw_string(_fonte, Vector2(centro_x - w * 0.5 + 1.5, base_y + 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.7))
	_tela.draw_string(_fonte, Vector2(centro_x - w * 0.5, base_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)

# 1.08 · AVISOS DISCRETOS: embaixo, no meio da tela (ou onde o jogador puser no editor da HUD: o item "AVISOS" de
# jogador/controles.gd dá o lugar e o tamanho), letra menor e um pouco transparente; o mais novo fica embaixo e os de
# antes sobem. Opções › HUD › "Fundo dos avisos": uma faixa escura atrás de cada um (lê melhor com o céu claro).
const AVISO_LETRA := 2.4                # vh (antes: 4,0, no alto da tela)
var _fundo_aviso: StyleBoxFlat = null

func _desenhar_avisos(vs: Vector2) -> void:
	if _avisos.is_empty():
		return
	var ancora := Vector2(vs.x * 0.5, vs.y - 92.0)
	var fator := 1.0
	var ctl = jogador.get("controles") if jogador != null else null
	if ctl != null:
		var b: Dictionary = ctl._botao("AVISOS")
		if not b.is_empty():
			ancora = ctl._centro(b)
			fator = float(b["r"]) / float(b["r0"])          # tamanho do editor x tamanho geral da HUD
	var tam := maxi(10, int(AVISO_LETRA * vs.y / 100.0 * fator))
	var passo := tam * 1.55
	var fundo: bool = bool(Config.valor("avisos_fundo"))
	if fundo and _fundo_aviso == null:
		_fundo_aviso = StyleBoxFlat.new()
		_fundo_aviso.bg_color = Color(0.0, 0.0, 0.0, 0.55)
		_fundo_aviso.set_corner_radius_all(6)
	var n := _avisos.size()
	for k in n:
		var a: Array = _avisos[k]
		var alfa := minf(1.0, float(a[1]) * 3.0)
		var txt: String = a[0]
		var w := _fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var base_y: float = ancora.y + tam * 0.35 - (n - 1 - k) * passo
		if fundo:
			_fundo_aviso.bg_color.a = 0.55 * alfa
			_tela.draw_style_box(_fundo_aviso, Rect2(ancora.x - w * 0.5 - tam * 0.6, base_y - tam * 0.95, w + tam * 1.2, tam * 1.3))
		else:
			_tela.draw_string(_fonte, Vector2(ancora.x - w * 0.5 + 1.0, base_y + 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.6 * alfa))
		_tela.draw_string(_fonte, Vector2(ancora.x - w * 0.5, base_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1, 1, 1, 0.88 * alfa))

func _desenhar() -> void:
	if armas == null:
		return
	var vs := _tela.get_viewport_rect().size
	var vh := vs.y / 100.0 * escala
	var c := vs * 0.5
	# ----- mira (0.65: só no modo MIRA) -----
	var esp := maxf(2.0, 0.36 * vh)
	# 0.98: olhando pela MIRA DE FERRO a cruz some (a própria mira da arma mostra onde vai)
	var ferro: bool = jogador != null and jogador.has_method("em_mira_ferro") and jogador.em_mira_ferro()
	if (jogador == null or bool(jogador.get("mirando"))) and not ferro:
		var g := _gap * vh
		var comp := 1.5 * vh
		var sombra := Color(0, 0, 0, 0.6)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var a: Vector2 = c + d * g
			var b: Vector2 = c + d * (g + comp)
			_tela.draw_line(a, b, sombra, esp + 2.0)
			_tela.draw_line(a, b, Color.WHITE, esp)
		_tela.draw_circle(c, esp * 0.6 + 1.0, sombra)
		_tela.draw_circle(c, esp * 0.6, Color.WHITE)
	if _hit > 0.0:
		var s := 1.7 * vh
		var cor := Color(_hit_cor.r, _hit_cor.g, _hit_cor.b, _hit)
		_tela.draw_line(c + Vector2(-s, -s), c + Vector2(-s * 0.4, -s * 0.4), cor, esp * 1.3)
		_tela.draw_line(c + Vector2(s, -s), c + Vector2(s * 0.4, -s * 0.4), cor, esp * 1.3)
		_tela.draw_line(c + Vector2(-s, s), c + Vector2(-s * 0.4, s * 0.4), cor, esp * 1.3)
		_tela.draw_line(c + Vector2(s, s), c + Vector2(s * 0.4, s * 0.4), cor, esp * 1.3)
	# ----- aviso -----
	_desenhar_avisos(vs)
	# ----- munição (0.65 · HUD mínima): um ícone de PENTE que muda de cor, sem números nem barra -----
	# branco = cheio · amarelo · laranja · vermelho piscando = vazio · âmbar pulsando = recarregando
	# chave inglesa vermelha (ou X) = EMPERRADA · pente apagado (ou só contorno) = SEM PENTE
	if armas.atual == "" or armas.eh_corpo() or not bool(Config.valor("icone_mun")):
		return                          # 0.99: Opções › HUD › "Ícone da munição" (oculto por padrão)
	var A: Dictionary = armas.estado()
	var cap: int = maxi(1, armas.capacidade())
	var f := float(A["mag"]) / float(cap)
	var cor := Color(0.95, 0.95, 0.92)
	if f <= 0.0:
		cor = Color(VERMELHO, 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008))
	elif f <= 0.25:
		cor = Color(1.0, 0.55, 0.15)
	elif f <= 0.5:
		cor = Color(1.0, 0.85, 0.25)
	if armas.rel > 0.0:
		cor = Color(AMBAR, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
	var lado := 6.0 * vh
	var r := Rect2(c.x - lado * 0.5, vs.y - 3.0 * vh - lado, lado, lado)
	_tela.draw_rect(r, Color(0, 0, 0, 0.42))
	var sem_pente: bool = armas.item_arma != null and armas.item_arma.usa_pente() != "" and armas.item_arma.pente_id == ""
	var tp := HudStatus._tex("pente")                  # 0.66: ícone do pacote game-icons.net (hud/icones)
	if tp != null:
		var ai := r.grow(-lado * 0.14)
		var c_i := Color(cor, 0.3) if sem_pente else cor
		_tela.draw_texture_rect(tp, Rect2(ai.position + Vector2(1.5, 1.5), ai.size), false, Color(0, 0, 0, 0.6))
		_tela.draw_texture_rect(tp, ai, false, c_i)
		var te := HudStatus._tex("emperrada")
		if armas.travada and te != null:
			_tela.draw_texture_rect(te, Rect2(r.position + r.size * 0.45, r.size * 0.6), false, VERMELHO)
		return
	var pr := Rect2(r.position.x + lado * 0.36, r.position.y + lado * 0.14, lado * 0.28, lado * 0.72)
	if sem_pente:
		_tela.draw_rect(pr, cor, false, maxf(1.0, 0.25 * vh))
	else:
		_tela.draw_rect(pr, cor)
		_tela.draw_rect(Rect2(pr.position.x + pr.size.x * 0.2, pr.position.y - lado * 0.06, pr.size.x * 0.6, lado * 0.08), cor)
	if armas.travada:
		var m := lado * 0.22
		_tela.draw_line(r.position + Vector2(m, m), r.end - Vector2(m, m), VERMELHO, maxf(2.0, 0.5 * vh))
		_tela.draw_line(Vector2(r.end.x - m, r.position.y + m), Vector2(r.position.x + m, r.end.y - m), VERMELHO, maxf(2.0, 0.5 * vh))
