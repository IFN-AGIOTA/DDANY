extends CanvasLayer
# HUD DE COMBATE (porte do HTML): mira no centro que abre com movimento/pulo/disparo,
# painel de munição embaixo (nome da arma, pente / reserva, barra; fica vermelho com pouca bala),
# marcador de acerto ✕ (vermelho = tiro na cabeça / abate) e avisos rápidos ("SEM MUNIÇÃO", nome da arma, itens pegos).
# Sem arma nas mãos o painel de munição some.
# Tamanhos em "vh" (1% da altura da tela), como no HTML.

const AMBAR := Color(1.0, 0.71, 0.0)
const VERMELHO := Color(0.88, 0.02, 0.0)

var armas: Node = null
var escala := 1.0                   # Opções › HUD › Tamanho geral
var jogador: Node = null

var _tela: Control
var _gap := 1.2
var _hit := 0.0
var _hit_cor := Color.WHITE
var _aviso := ""
var _aviso_t := 0.0
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

func mostrar_aviso(t: String) -> void:
	_aviso = t
	_aviso_t = 0.9

func _acertou(cabeca: bool, matou: bool) -> void:
	_hit = 1.0
	_hit_cor = VERMELHO if (cabeca or matou) else Color.WHITE

func _process(dt: float) -> void:
	_hit = maxf(0.0, _hit - dt * 4.0)
	_aviso_t = maxf(0.0, _aviso_t - dt)
	if armas != null:
		# mesma fórmula do HTML: g = 0,7 + dispersão·140 + coice·0,9 (em vh)
		var alvo: float = 0.7 + armas.dispersao() * 140.0 + armas.rec * 0.9
		_gap += (alvo - _gap) * minf(1.0, dt * 18.0)
	_tela.visible = jogador == null or (bool(jogador.ativo) and not _inventario_aberto())
	_tela.queue_redraw()

func _inventario_aberto() -> bool:
	var c = jogador.get("controles")
	return c != null and bool(c.bloqueado)

func _texto(txt: String, centro_x: float, base_y: float, tam: int, cor: Color) -> void:
	var w := _fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_tela.draw_string(_fonte, Vector2(centro_x - w * 0.5 + 1.5, base_y + 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.7))
	_tela.draw_string(_fonte, Vector2(centro_x - w * 0.5, base_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)

func _desenhar() -> void:
	if armas == null:
		return
	var vs := _tela.get_viewport_rect().size
	var vh := vs.y / 100.0 * escala
	var c := vs * 0.5
	# ----- mira -----
	var g := _gap * vh
	var comp := 1.5 * vh
	var esp := maxf(2.0, 0.36 * vh)
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
	if _aviso_t > 0.0:
		_texto(_aviso, c.x, vs.y * 0.3, int(4.0 * vh), Color(1, 1, 1, minf(1.0, _aviso_t * 3.0)))
	# ----- painel de munição (só com arma nas mãos) -----
	if armas.atual == "" or armas.eh_corpo():
		return
	var W: Dictionary = armas.WDEF[armas.atual]
	var A: Dictionary = armas.estado()
	var cap: int = maxi(1, armas.capacidade())
	var pw := 26.0 * vh
	var ph := 11.5 * vh
	var px := c.x - pw * 0.5
	var py := vs.y - 3.0 * vh - ph
	var baixo: bool = int(A["mag"]) <= int(ceil(float(cap) * 0.25))
	_tela.draw_rect(Rect2(px, py, pw, ph), Color(0.03, 0.05, 0.08, 0.58))
	_tela.draw_rect(Rect2(px, py, 0.7 * vh, ph), AMBAR)
	var nome: String = W["nome"]
	if armas.rel > 0.0:
		nome += " · DESTRAVANDO" if armas.travada else " · RECARREGANDO"
	elif armas.travada:
		nome += " · TRAVADA"
	elif armas.item_arma != null and armas.item_arma.usa_pente() != "" and armas.item_arma.pente_id == "":
		nome += " · SEM PENTE"
	_texto(nome, c.x, py + 3.0 * vh, int(2.4 * vh), Color(1, 1, 1, 0.85))
	var mag := str(A["mag"])
	var res := "/ " + str(A["res"])
	var tm := int(5.4 * vh)
	var tr := int(2.8 * vh)
	var wm := _fonte.get_string_size(mag, HORIZONTAL_ALIGNMENT_LEFT, -1, tm).x
	var wr := _fonte.get_string_size(res, HORIZONTAL_ALIGNMENT_LEFT, -1, tr).x
	var x0 := c.x - (wm + wr + vh) * 0.5
	_tela.draw_string(_fonte, Vector2(x0, py + 8.4 * vh), mag, HORIZONTAL_ALIGNMENT_LEFT, -1, tm, VERMELHO if baixo else Color.WHITE)
	_tela.draw_string(_fonte, Vector2(x0 + wm + vh, py + 8.4 * vh), res, HORIZONTAL_ALIGNMENT_LEFT, -1, tr, Color(1, 1, 1, 0.7))
	var frac: float = (1.0 - armas.rel / armas.rel_tot) if armas.rel > 0.0 else float(A["mag"]) / float(cap)
	_tela.draw_rect(Rect2(px + 1.5 * vh, py + ph - 1.6 * vh, pw - 3.0 * vh, 0.6 * vh), Color(1, 1, 1, 0.15))
	_tela.draw_rect(Rect2(px + 1.5 * vh, py + ph - 1.6 * vh, (pw - 3.0 * vh) * clampf(frac, 0.0, 1.0), 0.6 * vh), VERMELHO if baixo else AMBAR)
