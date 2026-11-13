extends CanvasLayer
# HUD DE SOBREVIVÊNCIA (estilo DayZ): ícones no canto de baixo à esquerda que mudam de cor
# (branco = bem · amarelo = atenção · laranja · vermelho = perigo) com setas ▲▼ mostrando se está subindo/caindo:
#   VIDA (cruz) · SANGUE (gota) · FOME (talheres) · SEDE (copo) · TEMPERATURA (termômetro) · MOLHADO (nuvem)
#   + gotas vermelhas = quantos SANGRAMENTOS · cruz verde = INFECÇÃO · osso = PERNA QUEBRADA
#   + PULMÃO = estamina (0.65: ícone, sem barra) e um "vírus" colorido por DOENÇA (sem textos)
#   + tela preta quando desmaia
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

# OTIMIZAÇÃO: frio e golpe sozinhos não precisam ler a tela (que no celular copia a imagem inteira):
# só pintam a borda por cima, com a mesma cor final. O filtro que lê a tela fica só para "fraco" (sem cor).
const SHADER_BORDA := """
shader_type canvas_item;
uniform float golpe = 0.0;
uniform float frio = 0.0;
void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(d * vec2(1.4, 1.0)));
	float a1 = v * golpe * 0.75;
	float a2 = v * frio * 0.3;
	float a = 1.0 - (1.0 - a1) * (1.0 - a2);
	vec3 cor = (vec3(0.6, 0.0, 0.0) * a1 * (1.0 - a2) + vec3(0.6, 0.8, 1.0) * a2) / max(a, 0.0001);
	COLOR = vec4(cor, a);
}
"""
var _borda: ColorRect
var _mat_borda: ShaderMaterial
var _ult := Vector3(-1, -1, -1)       # últimos (golpe, fraco, frio) mandados para os shaders

var sv = null                        # jogador/sobrevivencia.gd
var jogador: Node = null
var escala := 1.0
var _tela: Control
var _filtro: ColorRect
var _mat: ShaderMaterial
var _golpe := 0.0
var _fonte: Font
var _t := 0.0
var _apagao: ColorRect

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
	_borda = ColorRect.new()
	_borda.set_anchors_preset(Control.PRESET_FULL_RECT)
	_borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat_borda = ShaderMaterial.new()
	var sb := Shader.new()
	sb.code = SHADER_BORDA
	_mat_borda.shader = sb
	_borda.material = _mat_borda
	_borda.visible = false
	add_child(_borda)
	_apagao = ColorRect.new()
	_apagao.color = Color(0, 0, 0, 0)
	_apagao.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apagao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_apagao)
	_tela = Control.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)

var _origens: Array = []               # [posição de onde veio o golpe, tempo restante]
var _t_desenho := 0.0

func ligar(j: Node) -> void:
	jogador = j
	sv = j.get("sobrevivencia")
	if sv != null:
		sv.ferido.connect(func(d): _golpe = clampf(_golpe + 0.35 + d * 0.03, 0.0, 1.0))
		sv.atingido.connect(func(o: Vector3): _origens.append([o, 1.4]))

func aplicar_estilo(esc: float, opacidade: float) -> void:
	escala = esc
	_tela.modulate.a = opacidade

func _process(dt: float) -> void:
	if sv == null:
		return
	_t += dt
	for o in _origens:
		o[1] -= dt
	while not _origens.is_empty() and _origens[0][1] <= 0.0:
		_origens.pop_front()
	_golpe = maxf(0.0, _golpe - dt * 1.6)
	var fraco := clampf((40.0 - sv.vida) / 40.0, 0.0, 1.0)
	fraco = maxf(fraco, clampf((3000.0 - sv.sangue) / 2500.0, 0.0, 1.0))
	if jogador.morto:
		fraco = 1.0
	var frio := clampf((35.6 - sv.temperatura) / 1.5, 0.0, 1.0)
	_apagao.color.a = move_toward(_apagao.color.a, 1.0 if sv.desmaiado > 0.0 else 0.0, dt * 2.0)
	_filtro.visible = fraco > 0.01
	_borda.visible = not _filtro.visible and (_golpe > 0.01 or frio > 0.01)
	var agora := Vector3(snappedf(_golpe, 0.01), snappedf(fraco, 0.01), snappedf(frio, 0.01))
	if agora != _ult:                       # só manda para o shader quando mudou
		_ult = agora
		var m: ShaderMaterial = _mat if _filtro.visible else _mat_borda
		m.set_shader_parameter("golpe", _golpe)
		m.set_shader_parameter("frio", frio)
		if _filtro.visible:
			m.set_shader_parameter("fraco", fraco)
	var c = jogador.get("controles")
	_tela.visible = bool(jogador.ativo) and not (c != null and bool(c.bloqueado)) and not jogador.morto
	# redesenha ~10 vezes por segundo (os ícones mudam devagar); todo quadro só com aviso piscando ou golpe
	_t_desenho -= dt
	if _t_desenho <= 0.0 or not _origens.is_empty() or sv.sangramentos > 0 or _golpe > 0.0:
		_t_desenho = 0.1
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

# arcos vermelhos na borda de um círculo em volta do centro: de que lado veio cada golpe
func _desenhar_origens(vs: Vector2) -> void:
	if _origens.is_empty() or jogador == null:
		return
	var yaw: float = float(jogador.get("cam_yaw"))
	var f := Vector2(-sin(yaw), -cos(yaw))              # frente da câmera (no chão)
	var r := Vector2(cos(yaw), -sin(yaw))               # direita da câmera
	var p: Vector3 = jogador.global_position
	var c := vs * 0.5
	var raio := vs.y * 0.33
	for e in _origens:
		var o: Vector3 = e[0]
		var d := Vector2(o.x - p.x, o.z - p.z)
		if d.length_squared() < 0.0001:
			continue
		var ang := atan2(d.dot(r), d.dot(f))            # 0 = à frente, positivo = à direita
		var a := -PI * 0.5 + ang
		var alfa := clampf(float(e[1]), 0.0, 1.0)
		_tela.draw_arc(c, raio, a - 0.38, a + 0.38, 24, Color(0.9, 0.08, 0.05, 0.75 * alfa), vs.y * 0.018, true)
		_tela.draw_arc(c, raio + vs.y * 0.022, a - 0.22, a + 0.22, 16, Color(0.9, 0.08, 0.05, 0.4 * alfa), vs.y * 0.01, true)

func _desenhar() -> void:
	var vs := _tela.get_viewport_rect().size
	_desenhar_origens(vs)
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
	# 0.65 · HUD MÍNIMA: sem barras nem textos, só ícones que mudam de cor
	# estamina = ícone de pulmão (só aparece quando não está cheia)
	if sv.estamina < sv.estamina_max - 1.0 or sv.estamina_max < 99.0:
		var cor_e := _cor(sv.estamina, 60.0, 35.0, 12.0)
		if cor_e == VERMELHO:
			cor_e.a = pisca
		var r := Rect2(x, y, lado, lado)
		_tela.draw_rect(r, Color(0, 0, 0, 0.42))
		_icone("estamina", r.grow(-lado * 0.18), cor_e)
		x += lado + 0.8 * u
	# doenças = um ícone de "vírus" cada (gripe azul, cólera marrom, intoxicação roxa)
	for d in [["gripe", sv.gripe >= 1.0, Color(0.55, 0.75, 1.0)], ["colera", sv.colera > 0.0, Color(0.75, 0.55, 0.25)],
			["intoxicacao", sv.intoxicacao > 0.0, Color(0.75, 0.45, 0.95)], ["gas", float(sv.get("gas")) > 0.0, Color(0.7, 0.95, 0.2)]]:
		if not d[1]:
			continue
		var r := Rect2(x, y, lado, lado)
		_tela.draw_rect(r, Color(0, 0, 0, 0.42))
		_icone(d[0] if _tex(d[0]) != null else "doenca", r.grow(-lado * 0.16), Color(d[2], pisca))
		x += lado + 0.8 * u
	# perna quebrada, sangramentos (um ícone por sangramento, até 3) e infecção: ícones soltos, sem fundo
	var extras: Array = []
	if sv.perna_quebrada:
		extras.append(["perna", Color(0.95, 0.9, 0.8, pisca)])
	for k in mini(sv.sangramentos, 3):
		extras.append(["sangramento", Color(VERMELHO, pisca)])
	if sv.infeccao > 0.0:
		extras.append(["infeccao", Color(0.4, 0.9, 0.35)])
	for e in extras:
		var r := Rect2(x, y, lado, lado)
		_tela.draw_rect(r, Color(0, 0, 0, 0.42))
		_icone(e[0], r.grow(-lado * 0.16), e[1])
		x += lado + 0.8 * u

func _gota(c: Vector2, r: float, cor: Color) -> void:
	_tela.draw_circle(c + Vector2(0, r * 0.3), r * 0.75, cor)
	_tela.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, r * 0.1), c + Vector2(r * 0.7, r * 0.1), c + Vector2(0, -r * 1.1)]), cor)

# ÍCONES (0.66): imagens do pacote game-icons.net (CC BY 3.0, créditos em hud/icones/LICENCA.txt e na tela de
# Créditos), brancas, pintadas com a cor do estado. Sem a imagem, usa o desenho por código de antes.
const PASTA_ICONES := "res://hud/icones/"
static var _texturas := {}

static func _tex(nome: String) -> Texture2D:
	if not _texturas.has(nome):
		var c := PASTA_ICONES + nome + ".png"
		_texturas[nome] = load(c) if ResourceLoader.exists(c) else null
	return _texturas[nome]

func _icone(nome: String, a: Rect2, cor: Color) -> void:
	var t := _tex(nome)
	if t != null:
		_tela.draw_texture_rect(t, Rect2(a.position + Vector2(1.5, 1.5), a.size), false, Color(0, 0, 0, 0.6 * cor.a))   # sombra
		_tela.draw_texture_rect(t, a, false, cor)
		return
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
		"estamina":                     # pulmões
			_tela.draw_rect(Rect2(p.x + w * 0.46, p.y, w * 0.08, h * 0.45), cor)
			_tela.draw_circle(Vector2(p.x + w * 0.28, p.y + h * 0.62), w * 0.22, cor)
			_tela.draw_circle(Vector2(p.x + w * 0.72, p.y + h * 0.62), w * 0.22, cor)
			_tela.draw_rect(Rect2(p.x + w * 0.08, p.y + h * 0.4, w * 0.36, h * 0.25), cor)
			_tela.draw_rect(Rect2(p.x + w * 0.56, p.y + h * 0.4, w * 0.36, h * 0.25), cor)
		"doenca":                       # "vírus": bolinha com espinhos
			var c := a.get_center()
			for k in 8:
				var ang := TAU * k / 8.0
				_tela.draw_line(c, c + Vector2(cos(ang), sin(ang)) * w * 0.5, cor, maxf(1.5, w * 0.09))
			_tela.draw_circle(c, w * 0.3, cor)
		"molhado":
			_tela.draw_circle(p + Vector2(w * 0.35, h * 0.35), w * 0.22, cor)
			_tela.draw_circle(p + Vector2(w * 0.62, h * 0.3), w * 0.26, cor)
			_tela.draw_rect(Rect2(p.x + w * 0.15, p.y + h * 0.35, w * 0.7, h * 0.2), cor)
			for k in 3:
				_tela.draw_line(p + Vector2(w * (0.25 + k * 0.22), h * 0.65), p + Vector2(w * (0.2 + k * 0.22), h * 0.95), cor, maxf(1.5, w * 0.06))
