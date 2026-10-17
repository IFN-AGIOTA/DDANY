extends Control
# ÍCONE DE PERFIL (avatar) desenhado por código: círculo colorido com um símbolo. Usado no perfil, na lista de
# amigos, na sala do multijogador e no aviso de convite. O número escolhido fica na conta (rede/conta.gd: avatar).
# Mexa AQUI para: cores e símbolos (tabela ICONES). Novos ícones vão no FIM da lista (o número é salvo na conta).

const ICONES := [
	["mira", Color("#c9400a")], ["caveira", Color("#5b5f66")], ["estrela", Color("#b8860b")], ["raio", Color("#2f6db5")],
	["coracao", Color("#a3283b")], ["lua", Color("#3b3f8f")], ["escudo", Color("#2e7d4f")], ["chama", Color("#d4661c")],
	["radiacao", Color("#8a8a12")], ["folha", Color("#3f7f2a")], ["gota", Color("#1f7a8c")], ["coroa", Color("#7a3fa0")],
]

var indice := 0:
	set(v):
		indice = posmod(v, ICONES.size())
		queue_redraw()
var selecionado := false:
	set(v):
		selecionado = v
		queue_redraw()
var online := -1:                              # -1 sem bolinha · 0 offline · 1 online · 2 jogando
	set(v):
		online = v
		queue_redraw()

func _init(i := 0, tam := 48.0) -> void:
	indice = i
	custom_minimum_size = Vector2(tam, tam)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := Vector2(size.x, size.y) * 0.5
	var r := s * 0.5
	var cor: Color = ICONES[indice][1]
	draw_circle(c, r, cor.darkened(0.35))
	draw_circle(c, r * 0.9, cor)
	if selecionado:
		draw_arc(c, r - 1.5, 0, TAU, 48, Color("#ffe2b0"), maxf(2.0, s * 0.06), true)
	var b := Color(1, 0.96, 0.9)
	var k := r * 0.55
	match str(ICONES[indice][0]):
		"mira":
			draw_arc(c, k, 0, TAU, 32, b, s * 0.06, true)
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(c + d * k * 0.45, c + d * k * 1.25, b, s * 0.06)
			draw_circle(c, s * 0.04, b)
		"caveira":
			draw_circle(c + Vector2(0, -k * 0.15), k * 0.8, b)
			draw_rect(Rect2(c + Vector2(-k * 0.45, k * 0.3), Vector2(k * 0.9, k * 0.5)), b)
			draw_circle(c + Vector2(-k * 0.32, -k * 0.15), k * 0.22, cor)
			draw_circle(c + Vector2(k * 0.32, -k * 0.15), k * 0.22, cor)
			for x in [-0.2, 0.0, 0.2]:
				draw_line(c + Vector2(k * x, k * 0.45), c + Vector2(k * x, k * 0.8), cor, s * 0.03)
		"estrela":
			draw_colored_polygon(_estrela(c, k * 1.05, k * 0.45, 5), b)
		"raio":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.15, -1.05) * k, c + Vector2(-0.55, 0.1) * k, c + Vector2(-0.05, 0.1) * k,
				c + Vector2(-0.2, 1.05) * k, c + Vector2(0.55, -0.15) * k, c + Vector2(0.05, -0.15) * k]), b)
		"coracao":
			draw_circle(c + Vector2(-k * 0.42, -k * 0.2), k * 0.48, b)
			draw_circle(c + Vector2(k * 0.42, -k * 0.2), k * 0.48, b)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.88, -0.05) * k, c + Vector2(0.88, -0.05) * k, c + Vector2(0, 0.95) * k]), b)
		"lua":
			draw_circle(c, k * 0.9, b)
			draw_circle(c + Vector2(k * 0.4, -k * 0.25), k * 0.75, cor)
		"escudo":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, -0.85) * k, c + Vector2(0.8, -0.85) * k, c + Vector2(0.8, 0.1) * k,
				c + Vector2(0, 1.0) * k, c + Vector2(-0.8, 0.1) * k]), b)
			draw_line(c + Vector2(0, -0.6) * k, c + Vector2(0, 0.6) * k, cor, s * 0.05)
		"chama":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1.05) * k, c + Vector2(0.7, 0.1) * k, c + Vector2(0.55, 0.75) * k,
				c + Vector2(0, 1.0) * k, c + Vector2(-0.55, 0.75) * k, c + Vector2(-0.7, 0.1) * k, c + Vector2(-0.25, -0.2) * k]), b)
			draw_circle(c + Vector2(0, k * 0.45), k * 0.3, cor)
		"radiacao":
			draw_circle(c, k * 0.18, b)
			for i in 3:
				var a0 := -PI / 2 + i * TAU / 3 - 0.5
				var pts := PackedVector2Array()
				for j in 9:
					var a := a0 + 1.0 * j / 8.0
					pts.append(c + Vector2(cos(a), sin(a)) * k * 0.3)
				for j in 9:
					var a := a0 + 1.0 * (8 - j) / 8.0
					pts.append(c + Vector2(cos(a), sin(a)) * k * 1.0)
				draw_colored_polygon(pts, b)
		"folha":
			var pts := PackedVector2Array()
			for j in 17:
				var t := float(j) / 16.0
				pts.append(c + Vector2(sin(t * PI) * 0.6, -1.0 + t * 2.0) * k)
			for j in 17:
				var t := 1.0 - float(j) / 16.0
				pts.append(c + Vector2(-sin(t * PI) * 0.6, -1.0 + t * 2.0) * k)
			draw_colored_polygon(pts, b)
			draw_line(c + Vector2(0, -0.8) * k, c + Vector2(0, 1.0) * k, cor, s * 0.035)
		"gota":
			draw_circle(c + Vector2(0, k * 0.3), k * 0.62, b)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1.05) * k, c + Vector2(0.58, 0.15) * k, c + Vector2(-0.58, 0.15) * k]), b)
		"coroa":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.9, 0.6) * k, c + Vector2(-0.9, -0.5) * k, c + Vector2(-0.45, 0.0) * k,
				c + Vector2(0, -0.8) * k, c + Vector2(0.45, 0.0) * k, c + Vector2(0.9, -0.5) * k, c + Vector2(0.9, 0.6) * k]), b)
	if online >= 0:
		var p := c + Vector2(r, r) * 0.72
		draw_circle(p, s * 0.13, Color(0.08, 0.04, 0.02))
		draw_circle(p, s * 0.095, [Color(0.45, 0.45, 0.45), Color("#3ecf5a"), Color("#ffb400")][clampi(online, 0, 2)])

static func _estrela(c: Vector2, r1: float, r2: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := -PI / 2 + i * PI / n
		pts.append(c + Vector2(cos(a), sin(a)) * (r1 if i % 2 == 0 else r2))
	return pts
