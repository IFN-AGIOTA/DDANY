extends CanvasLayer
# HUD DE SOBREVIVÊNCIA (estilo DayZ): ícones no canto de baixo à esquerda que mudam de cor
# (branco = bem · amarelo = atenção · laranja · vermelho = perigo) com setas ▲▼ mostrando se está subindo/caindo:
#   VIDA (cruz) · SANGUE (gota) · FOME (talheres) · SEDE (copo) · TEMPERATURA (termômetro) · MOLHADO (nuvem)
#   + gotas vermelhas = quantos SANGRAMENTOS · cruz verde = INFECÇÃO.
# Também: tela pisca em vermelho ao levar um golpe; com pouca vida/sangue a tela perde a cor e escurece nas bordas.
# Mexa AQUI para: posição/tamanho dos ícones, cores e limites de cada estado.

const BRANCO := Color(0.95, 0.95, 0.92)
const AMARELO := Color(1.0, 0.85, 0.25)
const LARANJA := Color(1.0, 0.55, 0.15)
const VERMELHO := Color(0.95, 0.18, 0.12)

const SHADER_TELA := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float golpe = 0.0;     // pisca vermelho
uniform float fraco = 0.0;     // pouca vida/sangue: sem cor e bordas escuras
uniform float frio = 0.0;      // bordas azuladas
void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), fraco * 0.85);
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(d * vec2(1.4, 1.0)));
	c *= 1.0 - v * (0.75 * fraco);
	c = mix(c, vec3(0.6, 0.0, 0.0), v * golpe * 0.75);
	c = mix(c, vec3(0.6, 0.8, 1.0), v * frio * 0.3);
	COLOR = vec4(c, 1.0);
}
"""

var sv = null                        # jogador/sobrevivencia.gd
var jogador: Node = null
var escala := 1.0
var _tela: Control
var _filtro: ColorRect
var _mat: ShaderMaterial
var _golpe := 0.0
var _fonte: Font
var _t := 0.0

func _ready() -> void:
	layer = 4
	_fonte = ThemeDB.fallback_font
	_filtro = ColorRect.new()
	_filtro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_TELA
	_mat.shader = sh
	_filtro.material = _mat
	_filtro.visible = false
	add_child(_filtro)
	_tela = Control.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)

func ligar(j: Node) -> void:
	jogador = j
	sv = j.get("sobrevivencia")
	if sv != null:
		sv.ferido.connect(func(d): _golpe = clampf(_golpe + 0.35 + d * 0.03, 0.0, 1.0))

func aplicar_estilo(esc: float, opacidade: float) -> void:
	escala = esc
	_tela.modulate.a = opacidade

func _process(dt: float) -> void:
	if sv == null:
		return
	_t += dt
	_golpe = maxf(0.0, _golpe - dt * 1.6)
	var fraco := clampf((40.0 - sv.vida) / 40.0, 0.0, 1.0)
	fraco = maxf(fraco, clampf((3000.0 - sv.sangue) / 2500.0, 0.0, 1.0))
	if jogador.morto:
		fraco = 1.0
	var frio := clampf((35.6 - sv.temperatura) / 1.5, 0.0, 1.0)
	_filtro.visible = _golpe > 0.01 or fraco > 0.01 or frio > 0.01
	_mat.set_shader_parameter("golpe", _golpe)
	_mat.set_shader_parameter("fraco", fraco)
	_mat.set_shader_parameter("frio", frio)
	var c = jogador.get("controles")
	_tela.visible = bool(jogador.ativo) and not (c != null and bool(c.bloqueado)) and not jogador.morto
	_tela.queue_redraw()

func _cor(valor: float, a: float, b: float, c: float) -> Color:
	# valor alto = bom; a > b > c são os limites amarelo/laranja/vermelho
	if valor > a:
		return BRANCO
	if valor > b:
		return AMARELO
	if valor > c:
		return LARANJA
	return VERMELHO

func _desenhar() -> void:
	var vs := _tela.get_viewport_rect().size
	var u := vs.y / 100.0 * escala
	var lado := 5.2 * u
	var x := 2.0 * u
	var y := vs.y - lado - 2.2 * u
	var pisca := 0.55 + 0.45 * sin(_t * 8.0)
	var itens := [
		["vida", _cor(sv.vida, 75.0, 50.0, 25.0)],
		["sangue", _cor(sv.sangue, 4200.0, 3400.0, 2600.0)],
		["fome", _cor(sv.fome, 40.0, 20.0, 5.0)],
		["sede", _cor(sv.sede, 40.0, 20.0, 5.0)],
		["temperatura", BRANCO if absf(sv.temperatura - 36.6) < 0.8 else (Color(0.5, 0.75, 1.0) if sv.temperatura < 36.6 else LARANJA)],
	]
	if sv.molhado > 0.15:
		itens.append(["molhado", Color(0.55, 0.75, 1.0)])
	for e in itens:
		var cor: Color = e[1]
		if cor == VERMELHO:
			cor.a = pisca
		var r := Rect2(x, y, lado, lado)
		_tela.draw_rect(r, Color(0, 0, 0, 0.42))
		_icone(e[0], r.grow(-lado * 0.18), cor)
		var t: int = sv.tendencias.get(e[0], 0)
		if t != 0:
			var s := lado * 0.13
			var cx := r.end.x - s * 1.4
			var cy := r.position.y + s * 1.6
			var pts := PackedVector2Array([Vector2(cx - s, cy + s * 0.6 * t), Vector2(cx + s, cy + s * 0.6 * t), Vector2(cx, cy - s * 0.8 * t)])
			_tela.draw_colored_polygon(pts, cor)
		x += lado + 0.8 * u
	# sangramentos e infecção
	for k in mini(sv.sangramentos, 5):
		_gota(Vector2(x + lado * 0.3 + k * lado * 0.42, y + lado * 0.5), lado * 0.22, Color(VERMELHO, pisca))
	if sv.sangramentos > 0:
		x += lado * 0.42 * mini(sv.sangramentos, 5) + lado * 0.4
	if sv.infeccao > 0.0:
		var c := Vector2(x + lado * 0.4, y + lado * 0.5)
		var s2 := lado * 0.28
		var verde := Color(0.4, 0.9, 0.35)
		_tela.draw_rect(Rect2(c.x - s2 * 0.3, c.y - s2, s2 * 0.6, s2 * 2.0), verde)
		_tela.draw_rect(Rect2(c.x - s2, c.y - s2 * 0.3, s2 * 2.0, s2 * 0.6), verde)

func _gota(c: Vector2, r: float, cor: Color) -> void:
	_tela.draw_circle(c + Vector2(0, r * 0.3), r * 0.75, cor)
	_tela.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, r * 0.1), c + Vector2(r * 0.7, r * 0.1), c + Vector2(0, -r * 1.1)]), cor)

# ícones desenhados por código (área a)
func _icone(nome: String, a: Rect2, cor: Color) -> void:
	var p := a.position
	var w := a.size.x
	var h := a.size.y
	match nome:
		"vida":
			_tela.draw_rect(Rect2(p.x + w * 0.36, p.y, w * 0.28, h), cor)
			_tela.draw_rect(Rect2(p.x, p.y + h * 0.36, w, h * 0.28), cor)
		"sangue":
			_gota(a.get_center() + Vector2(0, h * 0.08), w * 0.5, cor)
		"fome":
			_tela.draw_rect(Rect2(p.x + w * 0.15, p.y, w * 0.12, h), cor)
			for k in 3:
				_tela.draw_rect(Rect2(p.x + w * (0.05 + k * 0.1), p.y, w * 0.05, h * 0.35), cor)
			_tela.draw_rect(Rect2(p.x + w * 0.62, p.y + h * 0.45, w * 0.13, h * 0.55), cor)
			_tela.draw_circle(Vector2(p.x + w * 0.68, p.y + h * 0.25), w * 0.18, cor)
		"sede":
			_tela.draw_colored_polygon(PackedVector2Array([p + Vector2(w * 0.12, 0), p + Vector2(w * 0.88, 0), p + Vector2(w * 0.75, h), p + Vector2(w * 0.25, h)]), cor)
			_tela.draw_rect(Rect2(p.x + w * 0.22, p.y + h * 0.08, w * 0.56, h * 0.22), Color(0, 0, 0, 0.45))
		"temperatura":
			_tela.draw_rect(Rect2(p.x + w * 0.4, p.y, w * 0.2, h * 0.7), cor)
			_tela.draw_circle(Vector2(p.x + w * 0.5, p.y + h * 0.78), w * 0.22, cor)
			var nivel := clampf((sv.temperatura - 34.0) / 5.0, 0.0, 1.0)
			_tela.draw_rect(Rect2(p.x + w * 0.45, p.y + h * 0.7 * (1.0 - nivel), w * 0.1, h * 0.7 * nivel), Color(0.9, 0.2, 0.15))
		"molhado":
			_tela.draw_circle(p + Vector2(w * 0.35, h * 0.35), w * 0.22, cor)
			_tela.draw_circle(p + Vector2(w * 0.62, h * 0.3), w * 0.26, cor)
			_tela.draw_rect(Rect2(p.x + w * 0.15, p.y + h * 0.35, w * 0.7, h * 0.2), cor)
			for k in 3:
				_tela.draw_line(p + Vector2(w * (0.25 + k * 0.22), h * 0.65), p + Vector2(w * (0.2 + k * 0.22), h * 0.95), cor, maxf(1.5, w * 0.06))
