extends RefCounted
# PEÇAS VISUAIS DOS MENUS (paleta quente do jogo em HTML): fontes, título em degradê, botão inclinado,
# seletor (Toque | Giroscópio), deslizante, passo (‹ valor ›) e abas. Tudo desenhado por código e medido em "vh"
# (1% da altura da tela), como no HTML. Funciona com toque e mouse.
# Mexa AQUI para: cores, fontes e o formato dos botões de TODOS os menus.

const TEXTO := Color("#ffe9d0")
const TITULO_SECAO := Color("#ffb866")
const AMBAR := Color("#ffb400")
const LARANJA := Color("#ff7a1a")
const LARANJA_ESCURO := Color("#c9400a")
const BORDA := Color(1.0, 0.667, 0.353, 0.45)
const FUNDO_SEG := Color(0.157, 0.055, 0.016, 0.45)

static var _fontes := {}

# altura de 1% da tela (as medidas dos menus são em vh, como no HTML)
static func vh(no: Node) -> float:
	return no.get_viewport().get_visible_rect().size.y / 100.0

# fonte do jogo: Roboto Condensed (a mesma do HTML), em res://menu/fontes (licença OFL em LICENSE.txt)
const PESOS := [400, 700, 800, 900]

static func fonte(peso := 800, espacamento := 0.0, italico := true) -> Font:
	var chave := "%d|%.2f|%s" % [peso, espacamento, italico]
	if _fontes.has(chave):
		return _fontes[chave]
	var p := 400
	for w in PESOS:
		if peso >= w:
			p = w
	var arq := "res://menu/fontes/roboto-condensed-%d-%s.woff2" % [p, "italic" if italico else "normal"]
	var base: Font = load(arq) if ResourceLoader.exists(arq) else ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = int(espacamento)
	_fontes[chave] = fv
	return fv

static func rotulo(txt: String, tam: float, cor := TEXTO, peso := 700, espacamento := 0.0, italico := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", fonte(peso, espacamento, italico))
	l.add_theme_font_size_override("font_size", int(tam))
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# texto com degradê vertical (título APOCALIPSE, "Opções", "Pausa")
const SHADER_DEGRADE := """
shader_type canvas_item;
uniform vec4 c0 : source_color = vec4(1.0, 0.957, 0.863, 1.0);
uniform vec4 c1 : source_color = vec4(1.0, 0.761, 0.478, 1.0);
uniform vec4 c2 : source_color = vec4(1.0, 0.478, 0.165, 1.0);
uniform vec4 c3 : source_color = vec4(0.722, 0.212, 0.039, 1.0);
uniform float altura = 100.0;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	float t = clamp(ly / altura, 0.0, 1.0);
	vec3 c = t < 0.4 ? mix(c0.rgb, c1.rgb, smoothstep(0.06, 0.42, t)) : (t < 0.78 ? mix(c1.rgb, c2.rgb, (t - 0.42) / 0.36) : mix(c2.rgb, c3.rgb, (t - 0.78) / 0.22));
	COLOR = vec4(c, texture(TEXTURE, UV).a * COLOR.a);
}
"""
static var _shader_degrade: Shader

static func titulo_degrade(txt: String, tam: float, espacamento := 0.0) -> Label:
	var l := rotulo(txt, tam, Color.WHITE, 900, espacamento, true)
	if _shader_degrade == null:
		_shader_degrade = Shader.new()
		_shader_degrade.code = SHADER_DEGRADE
	var m := ShaderMaterial.new()
	m.shader = _shader_degrade
	l.material = m
	l.resized.connect(func(): m.set_shader_parameter("altura", maxf(1.0, l.size.y)))
	return l

# retângulo com degradê horizontal (botão primário / item escolhido)
static func degrade_h(ci: CanvasItem, pts: PackedVector2Array, a: Color, b: Color, x0: float, x1: float) -> void:
	var cores := PackedColorArray()
	for p in pts:
		cores.append(a.lerp(b, clampf((p.x - x0) / maxf(1.0, x1 - x0), 0.0, 1.0)))
	ci.draw_polygon(pts, cores)

# OTIMIZAÇÃO: o StyleBox de cada combinação (cor, raio, cheio, largura) é criado uma vez e reaproveitado
static var _caixas := {}

# ---------- círculos e anéis em TEXTURA (HUD) ----------
# No renderizador do celular cada draw_circle/draw_arc é uma chamada de desenho própria; retângulos com a mesma
# textura entram num lote só. disco()/anel() são feitos 1 vez (128 px, borda suave, mipmaps) e desenhados com
# circulo()/aro() (= draw_texture_rect colorido). anel(fracao) = grossura / raio.
static var _tex_disco: ImageTexture
static var _tex_aneis := {}
const TAM_TEX_CIRCULO := 128

static func disco() -> ImageTexture:
	if _tex_disco == null:
		_tex_disco = _fazer_circulo(-1.0)
	return _tex_disco

static func anel(fracao: float) -> ImageTexture:
	var k := snappedf(fracao, 0.005)
	if not _tex_aneis.has(k):
		_tex_aneis[k] = _fazer_circulo(k)
	return _tex_aneis[k]

static func _fazer_circulo(fracao: float) -> ImageTexture:
	var im := Image.create(TAM_TEX_CIRCULO, TAM_TEX_CIRCULO, false, Image.FORMAT_LA8)
	var c := (TAM_TEX_CIRCULO - 1) * 0.5
	var raio := c - 1.0
	var gr := maxf(1.0, raio * fracao)
	for y in TAM_TEX_CIRCULO:
		for x in TAM_TEX_CIRCULO:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(raio - d + 0.5, 0.0, 1.0) if fracao < 0.0 else clampf(0.5 - (absf(d - (raio - gr * 0.5)) - gr * 0.5), 0.0, 1.0)
			im.set_pixel(x, y, Color(1, 1, 1, a))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

# círculo cheio de raio r em c · aro de raio EXTERNO r e grossura g
static func circulo(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	ci.draw_texture_rect(disco(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, cor)

static func aro(ci: CanvasItem, c: Vector2, r: float, g: float, cor: Color) -> void:
	ci.draw_texture_rect(anel(g / maxf(r, 1.0)), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, cor)

# aro com grossura PROPORCIONAL ao raio (a mesma textura para todos os tamanhos: vários botões = 1 lote)
static func aro_prop(ci: CanvasItem, c: Vector2, r: float, fracao: float, cor: Color) -> void:
	ci.draw_texture_rect(anel(fracao), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, cor)

static func caixa_arredondada(ci: CanvasItem, r: Rect2, cor: Color, raio: float, cheio := true, largura := 1.0) -> void:
	var k := [cor, int(raio), cheio, int(maxf(1.0, largura))]
	var sb: StyleBoxFlat = _caixas.get(k)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(int(raio))
		if cheio:
			sb.bg_color = cor
		else:
			sb.draw_center = false
			sb.border_color = cor
			sb.set_border_width_all(int(maxf(1.0, largura)))
		sb.anti_aliasing = true
		if _caixas.size() > 256:
			_caixas.clear()
		_caixas[k] = sb
	ci.draw_style_box(sb, r)

# ======================================================================
# BOTÃO DO MENU: barra à esquerda, canto direito inclinado, título + subtítulo (ex.: "Jogar / Mundo livre")
class BotaoMenu extends Control:
	signal apertado
	var titulo := ""
	var sub := ""
	var primario := false
	var tam := 4.2           # tamanho da letra em vh
	var largura_min := 34.0  # vh
	var _aperto := false
	func _init(t := "", s := "", prim := false, tamanho := 4.2, lmin := 34.0) -> void:
		titulo = t
		sub = s
		primario = prim
		tam = tamanho
		largura_min = lmin
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
	func _ready() -> void:
		get_viewport().size_changed.connect(_medir)
		_medir()
	func _medir() -> void:
		var v := UI.vh(self)
		var ft := UI.fonte(800)
		var w := ft.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam * v)).x
		if sub != "":
			w = maxf(w, UI.fonte(400, 0.0, false).get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam * 0.5 * v)).x)
		var h := tam * v * 1.15 + 2.4 * v + (tam * 0.5 * v * 1.3 if sub != "" else 0.0)
		custom_minimum_size = Vector2(maxf(largura_min * v, w + 7.4 * v), h)
		queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_aperto = true
				queue_redraw()
			elif _aperto:
				_aperto = false
				queue_redraw()
				if Rect2(Vector2.ZERO, size).has_point(e.position):
					apertado.emit()
			accept_event()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and _aperto:
			_aperto = false
			queue_redraw()
	func _draw() -> void:
		var v := UI.vh(self)
		var s := size
		var corte := 2.6 * v
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x - corte, s.y), Vector2(0, s.y)])
		if primario:
			UI.degrade_h(self, pts, Color(1.0, 0.478, 0.102, 0.96), Color(0.745, 0.235, 0.039, 0.92), 0.0, s.x)
		else:
			draw_colored_polygon(pts, Color(0.157, 0.055, 0.016, 0.45))
		if _aperto:
			draw_colored_polygon(pts, Color(1, 1, 1, 0.18))
		draw_rect(Rect2(0, 0, 1.0 * v, s.y), Color("#ffe2b0") if primario else Color(1.0, 0.667, 0.353, 0.55))
		var cor := Color.WHITE if primario else UI.TEXTO
		var ft := UI.fonte(800)
		var tp := int(tam * v)
		var y := 1.2 * v + tp * 0.92
		draw_string(ft, Vector2(2.4 * v + 1, y + 1.5), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, Color(0, 0, 0, 0.55))
		draw_string(ft, Vector2(2.4 * v, y), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, cor)
		if sub != "":
			var ts := int(tam * 0.5 * v)
			draw_string(UI.fonte(400, 0.0, false), Vector2(2.4 * v, y + ts * 1.35), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(cor.r, cor.g, cor.b, 0.72))

# ======================================================================
# SELETOR: [ Toque | Giroscópio ] · o escolhido fica em degradê laranja
class Seletor extends Control:
	signal escolheu(valor)
	var opcoes: Array = []    # [[valor, texto], ...]
	var valor = null
	var tam := 3.2            # vh
	var altura := 5.4         # vh
	var raio := 1.0           # vh
	var borda := true
	func _init(ops: Array = [], v = null, tamanho := 3.2, alt := 5.4) -> void:
		opcoes = ops
		valor = v
		tam = tamanho
		altura = alt
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _ready() -> void:
		get_viewport().size_changed.connect(_medir)
		_medir()
	func _medir() -> void:
		custom_minimum_size.y = altura * UI.vh(self)
		queue_redraw()
	func definir(v) -> void:
		valor = v
		queue_redraw()
	# escolhe ao SOLTAR o dedo (se ele quase não andou): rolar a lista por cima não muda a opção
	var _p0 := Vector2.ZERO
	var _apertou := false
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and opcoes.size() > 0:
			if e.pressed:
				_p0 = e.position
				_apertou = true
				return
			if not _apertou or e.position.distance_to(_p0) > 1.5 * UI.vh(self):
				_apertou = false
				return
			_apertou = false
			var i := clampi(int(e.position.x / (size.x / opcoes.size())), 0, opcoes.size() - 1)
			accept_event()
			if opcoes[i][0] != valor:
				valor = opcoes[i][0]
				queue_redraw()
				escolheu.emit(valor)
	func _draw() -> void:
		var v := UI.vh(self)
		var r := Rect2(Vector2.ZERO, size)
		var rd := raio * v
		if borda:
			UI.caixa_arredondada(self, r, UI.FUNDO_SEG, rd)
		var n := opcoes.size()
		if n == 0:
			return
		var w := size.x / n
		var ft := UI.fonte(700)
		var tp := int(tam * v)
		for i in n:
			var cel := Rect2(i * w, 0, w, size.y)
			var on: bool = opcoes[i][0] == valor
			if on:
				var g := cel.grow(-0.15 * v) if borda else cel.grow(-0.35 * v)
				var pts := PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)])
				UI.degrade_h(self, pts, UI.LARANJA, UI.LARANJA_ESCURO, g.position.x, g.end.x)
				if not borda:
					draw_rect(g, Color("#ffd9a0"), false, maxf(1.0, 0.25 * v))
			elif not borda:
				draw_rect(cel.grow(-0.35 * v), Color(1.0, 0.63, 0.27, 0.07))
			var txt: String = opcoes[i][1]
			var tw := ft.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tp).x
			draw_string(ft, Vector2(cel.position.x + (w - tw) * 0.5, size.y * 0.5 + tp * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tp,
				Color.WHITE if on else Color(UI.TEXTO.r, UI.TEXTO.g, UI.TEXTO.b, 1.0 if borda else 0.75))
		if borda:
			UI.caixa_arredondada(self, r, UI.BORDA, rd, false, 0.35 * v)

# ======================================================================
# DESLIZANTE: trilho cinza + bolinha laranja com borda branca
class Deslizante extends Control:
	signal mudou(valor: int)
	var minimo := 0
	var maximo := 100
	var passo := 5
	var valor := 50
	var _arrastando := false
	func _init(mn := 0, mx := 100, ps := 5, v := 50) -> void:
		minimo = mn
		maximo = mx
		passo = ps
		valor = v
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _ready() -> void:
		get_viewport().size_changed.connect(_medir)
		_medir()
	func _medir() -> void:
		custom_minimum_size.y = 4.4 * UI.vh(self)
		queue_redraw()
	func definir(v: int) -> void:
		valor = v
		queue_redraw()
	func _x_para_valor(x: float) -> void:
		var m := 1.8 * UI.vh(self)
		var t := clampf((x - m) / maxf(1.0, size.x - 2.0 * m), 0.0, 1.0)
		var nv := clampi(int(round((minimo + t * (maximo - minimo)) / float(passo))) * passo, minimo, maximo)
		if nv != valor:
			valor = nv
			queue_redraw()
			mudou.emit(valor)
	# só começa a mexer com um arraste para o LADO (ou um toque parado); arrastar para cima/baixo rola a lista
	var _p0 := Vector2.ZERO
	var _apertado := false
	func _gui_input(e: InputEvent) -> void:
		var lim := 1.2 * UI.vh(self)
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_p0 = e.position
				_apertado = true
				_arrastando = false
			else:
				if _apertado and not _arrastando and e.position.distance_to(_p0) < lim:
					_x_para_valor(e.position.x)          # toque: pula para o ponto
					accept_event()
				_apertado = false
				_arrastando = false
		elif e is InputEventMouseMotion and _apertado:
			var d: Vector2 = e.position - _p0
			if not _arrastando and absf(d.x) > lim and absf(d.x) > absf(d.y) * 1.3:
				_arrastando = true
			if _arrastando:
				_x_para_valor(e.position.x)
				accept_event()
	func _draw() -> void:
		var v := UI.vh(self)
		var m := 1.8 * v
		var cy := size.y * 0.5
		UI.caixa_arredondada(self, Rect2(0, cy - 0.45 * v, size.x, 0.9 * v), Color(1, 1, 1, 0.25), 0.5 * v)
		var t := float(valor - minimo) / maxf(1.0, float(maximo - minimo))
		var c := Vector2(m + t * (size.x - 2.0 * m), cy)
		draw_circle(c, 1.8 * v, Color.WHITE)
		draw_circle(c, 1.4 * v, UI.LARANJA)

# ======================================================================
# PASSO: ‹ valor › (anti-aliasing, anisotrópica, limite de FPS)
class Passo extends Control:
	signal escolheu(valor)
	var opcoes: Array = []
	var valor = null
	func _init(ops: Array = [], v = null) -> void:
		opcoes = ops
		valor = v
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _ready() -> void:
		get_viewport().size_changed.connect(_medir)
		_medir()
	func _medir() -> void:
		custom_minimum_size.y = 5.4 * UI.vh(self)
		queue_redraw()
	func definir(v) -> void:
		valor = v
		queue_redraw()
	func _indice() -> int:
		for i in opcoes.size():
			if opcoes[i][0] == valor:
				return i
		return 0
	var _p0 := Vector2.ZERO
	var _apertou := false
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			_p0 = e.position
			_apertou = true
			return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and _apertou:
			_apertou = false
			if e.position.distance_to(_p0) > 1.5 * UI.vh(self):
				return
			accept_event()
			var lado := size.y * 1.1
			var d := 0
			if e.position.x < lado:
				d = -1
			elif e.position.x > size.x - lado:
				d = 1
			if d != 0:
				var i := clampi(_indice() + d, 0, opcoes.size() - 1)
				if opcoes[i][0] != valor:
					valor = opcoes[i][0]
					queue_redraw()
					escolheu.emit(valor)
	func _draw() -> void:
		var v := UI.vh(self)
		var lado := size.y * 1.1
		var ft := UI.fonte(800)
		var tp := int(3.2 * v)
		for k in 2:
			var r := Rect2((0.0 if k == 0 else size.x - lado), 0, lado, size.y).grow(-0.35 * v)
			draw_rect(r, Color(1.0, 0.63, 0.27, 0.12))
			var s := "‹" if k == 0 else "›"
			var sw := ft.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tp * 1.4)).x
			draw_string(ft, Vector2(r.get_center().x - sw * 0.5, size.y * 0.5 + tp * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tp * 1.4), UI.TEXTO)
		var txt: String = opcoes[_indice()][1] if opcoes.size() > 0 else ""
		var tw := ft.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tp).x
		draw_string(ft, Vector2((size.x - tw) * 0.5, size.y * 0.5 + tp * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, Color.WHITE)

# ======================================================================
# ABAS: Controles | Câmera | HUD | Gráficos | Vídeo e som | Ajuda
class Abas extends Control:
	signal escolheu(indice: int)
	var nomes: Array = []
	var atual := 0
	var _x: Array = []
	func _init(n: Array = []) -> void:
		nomes = n
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _ready() -> void:
		get_viewport().size_changed.connect(_medir)
		_medir()
	func _medir() -> void:
		custom_minimum_size.y = 6.6 * UI.vh(self)
		queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			accept_event()
			for i in _x.size():
				var r: Rect2 = _x[i]
				if r.has_point(e.position) and i != atual:
					atual = i
					queue_redraw()
					escolheu.emit(i)
	func _draw() -> void:
		var v := UI.vh(self)
		var ft := UI.fonte(800)
		var tp := int(3.1 * v)
		var x := 0.0
		var h := 5.4 * v
		_x.clear()
		for i in nomes.size():
			var txt: String = nomes[i]
			var w := ft.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tp).x + 4.8 * v
			var r := Rect2(x, 0, w, h)
			_x.append(r)
			var on := i == atual
			UI.caixa_arredondada(self, r, Color(1.0, 0.478, 0.102, 0.3) if on else Color(1, 1, 1, 0.07), 0.8 * v)
			if on:
				draw_rect(Rect2(x, h - 0.5 * v, w, 0.5 * v), UI.LARANJA)
			draw_string(ft, Vector2(x + 2.4 * v, h * 0.5 + tp * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, Color.WHITE if on else UI.TEXTO)
			x += w + 0.8 * v
		draw_rect(Rect2(0, h + 1.0 * v, size.x, 0.3 * v), Color(1, 1, 1, 0.18))

const UI := preload("res://menu/ui.gd")
