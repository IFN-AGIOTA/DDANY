extends "res://mundo/local_novos.gd"
# 1.06 · IGREJA e PREFEITURA DE NOVA YORK (mundo/locais.gd tipos "igreja" e "prefeitura"), no estilo NEOCLÁSSICO
# das fotos de referência: escadaria larga, pórtico de colunas com frontão e inscrição, cúpula, torre do sino.
# Usa as peças do mundo/local.gd e do mundo/local_novos.gd (paredes com vãos, lajes, escadas, móveis, sacos de areia,
# jipe, caminhão e barracas do Exército) e funciona igual: tudo vira uma malha + um corpo de colisão, loot próprio
# (tabelas "igreja_*" e "prefeitura_*" em mundo/loot_mundo.gd), pontos de infectados e lugares altos para vigiar
# (a torre do sino; o terraço da prefeitura).
# Peças novas daqui: _face (triângulo/quadrilátero solto), _prisma (frontão e telhado de duas águas), _coluna,
# _cupula, _vitral (janela em arco com vitral), _balaustrada e a escada em caracol quadrada da torre (_torre_sino).
# O SINO (mundo/sino.gd): PEGAR perto dele = tocar; o barulho chama os infectados de longe.
# Coordenadas LOCAIS: x = ao longo da frente, z = profundidade, +Z = FRENTE (o lado da rua), y = 0 no chão.
# Mexa AQUI para: a planta, os cômodos, os enfeites e as alturas. Onde ficam: mundo/locais.gd.

const PEDRA := Color(0.9, 0.88, 0.82)            # reboco claro (as fotos: branco/creme)
const PEDRA_ESC := Color(0.74, 0.71, 0.64)       # frisos, capitéis e cornijas
const GRANITO := Color(0.5, 0.49, 0.47)          # embasamento e degraus
const ARDOSIA := Color(0.3, 0.32, 0.34)          # telhados
const COBRE := Color(0.36, 0.52, 0.46)           # cúpulas (cobre velho, verde)
const MADEIRA := Color(0.36, 0.22, 0.13)
const DOURADO := Color(0.78, 0.62, 0.25)
const VITRAIS := [Color(0.22, 0.32, 0.72), Color(0.7, 0.16, 0.14), Color(0.85, 0.6, 0.15), Color(0.2, 0.5, 0.3), Color(0.5, 0.25, 0.6)]

var sinos: Array = []                            # 1.06: [Vector3 local] onde fica o sino (mundo/sino.gd)
var nome_igreja := ""

# ======================================================================================================
# PEÇAS
# ======================================================================================================
# face solta (3 ou 4 pontos) com a normal "nn" para fora (acerta a ordem dos pontos sozinha)
func _face(c, pts: Array, nn: Vector3, cor: Color) -> void:
	var a: Vector3 = pts[0]
	var b: Vector3 = pts[1]
	var d: Vector3 = pts[2]
	if (b - a).cross(d - a).dot(nn) < 0.0:
		pts = pts.duplicate()
		pts.reverse()
	var p0: Vector3 = pts[0]
	var p1: Vector3 = pts[1]
	var p2: Vector3 = pts[2]
	var p3: Vector3 = pts[3] if pts.size() > 3 else pts[2]
	c._quad(p0, p1, p2, p3, nn.normalized(), cor, Vector2(0, 0), Vector2(p0.distance_to(p1), 0), Vector2(p0.distance_to(p1), p1.distance_to(p2)), Vector2(0, p1.distance_to(p2)))

# prisma triangular (frontão / telhado de duas águas): base em y = o.y, largura "larg" atravessada, cumeeira "alt"
# acima, esticado "comp" ao longo de Z (eixo_z) ou de X
func _prisma(c, o: Vector3, larg: float, alt: float, comp: float, eixo_z: bool, cor: Color, cor_lado := Color(-1, 0, 0)) -> void:
	var ct := cor if cor_lado.r < 0.0 else cor_lado       # cor dos triângulos das pontas
	var ax := Vector3(0, 0, 1) if eixo_z else Vector3(1, 0, 0)
	var tr := Vector3(1, 0, 0) if eixo_z else Vector3(0, 0, 1)
	var h := comp * 0.5
	var w := larg * 0.5
	var pts := []
	for s in [-1.0, 1.0]:
		var base: Vector3 = o + ax * h * s
		pts.append([base - tr * w, base + tr * w, base + Vector3.UP * alt])
	# pontas
	_face(c, [pts[1][0], pts[1][1], pts[1][2]], ax, ct)
	_face(c, [pts[0][0], pts[0][1], pts[0][2]], -ax, ct)
	# águas
	var n1 := (tr * alt + Vector3.UP * w).normalized()
	var n2 := (-tr * alt + Vector3.UP * w).normalized()
	_face(c, [pts[0][1], pts[1][1], pts[1][2], pts[0][2]], n1, cor)
	_face(c, [pts[0][0], pts[1][0], pts[1][2], pts[0][2]], n2, cor)

# coluna clássica: base (plinto), fuste redondo, capitel; colisão de caixa
func _coluna(p: Vector2, y0: float, h: float, raio: float, c = null) -> void:
	if c == null:
		c = fora
	c.caixa(Vector3(p.x, y0 + 0.2, p.y), Vector3(raio * 2.6, 0.4, raio * 2.6), PEDRA_ESC)
	c.cilindro(Vector3(p.x, y0 + 0.5, p.y), raio * 1.15, 0.2, 12, PEDRA_ESC)
	c.cilindro(Vector3(p.x, y0 + h * 0.5 + 0.25, p.y), raio, h - 1.0, 12, PEDRA, Basis.IDENTITY, raio * 0.88)
	c.cilindro(Vector3(p.x, y0 + h - 0.6, p.y), raio * 0.95, 0.2, 12, PEDRA_ESC, Basis.IDENTITY, raio * 1.2)
	c.caixa(Vector3(p.x, y0 + h - 0.32, p.y), Vector3(raio * 2.5, 0.35, raio * 2.5), PEDRA_ESC)
	col.append([Vector3(p.x, y0 + h * 0.5, p.y), Vector3(raio * 2.0, h, raio * 2.0), 0.0, Basis.IDENTITY])

# cúpula (meia esfera em anéis) com o centro da base em "o"
func _cupula(c, o: Vector3, raio: float, cor: Color, aneis := 6, lados := 16) -> void:
	for k in aneis:
		var a0 := PI * 0.5 * k / aneis
		var a1 := PI * 0.5 * (k + 1) / aneis
		var y0 := sin(a0) * raio
		var y1 := sin(a1) * raio
		c.cilindro(o + Vector3(0, (y0 + y1) * 0.5, 0), cos(a0) * raio, y1 - y0, lados, cor, Basis.IDENTITY, maxf(cos(a1) * raio, 0.01))

# janela de vitral com o alto em arco, numa parede ao longo de X (normal Z) ou de Z (normal X). "p" = centro do vão
# no chão da janela (y = peitoril); o vão na parede é feito por quem chama (_parede com [s0, s1, yb, yc, "vitral"])
func _vitral(p: Vector3, larg: float, alt: float, esp: float, normal_z: bool, cor: Color) -> void:
	var gb := Basis(Vector3.RIGHT, PI * 0.5) if normal_z else Basis(Vector3.FORWARD, PI * 0.5)
	var tam := Vector3(larg, alt, 0.06) if normal_z else Vector3(0.06, alt, larg)
	resto.caixa(p + Vector3(0, alt * 0.5, 0), tam, cor)                                       # o vidro
	# chumbo do vitral (grade escura)
	var tam_h := Vector3(larg, 0.05, 0.08) if normal_z else Vector3(0.08, 0.05, larg)
	for k in range(1, 4):
		resto.caixa(p + Vector3(0, alt * k / 4.0, 0), tam_h, Color(0.12, 0.12, 0.13))
	resto.caixa(p + Vector3(0, alt * 0.5, 0), Vector3(0.05, alt, 0.08) if normal_z else Vector3(0.08, alt, 0.05), Color(0.12, 0.12, 0.13))
	col.append([p + Vector3(0, alt * 0.5, 0), Vector3(larg, alt, 0.2) if normal_z else Vector3(0.2, alt, larg), 0.0, Basis.IDENTITY])
	# arco: disco de vidro (metade de baixo dentro do vão, a de cima por cima da parede) e a moldura de pedra
	var r_arco := larg * 0.5
	paredes.cilindro(p + Vector3(0, alt, 0), r_arco + 0.18, esp + 0.03, 12, PEDRA_ESC, gb)
	resto.cilindro(p + Vector3(0, alt, 0), r_arco, esp + 0.07, 12, cor * 0.9, gb)
	# peitoril de pedra
	paredes.caixa(p + Vector3(0, -0.08, 0), Vector3(larg + 0.4, 0.16, esp + 0.2) if normal_z else Vector3(esp + 0.2, 0.16, larg + 0.4), PEDRA_ESC)

# balaustrada de a até b (de ya até yb: pode subir junto da escadaria), com corrimão e colisão em pedaços retos
func _balaustrada(a: Vector2, b: Vector2, ya: float, yb: float, h := 1.0) -> void:
	var L := a.distance_to(b)
	if L < 0.1:
		return
	var n := maxi(2, int(L / 0.45))
	for k in n + 1:
		var t := float(k) / n
		var q := a.lerp(b, t)
		var y := lerpf(ya, yb, t)
		fora.cilindro(Vector3(q.x, y + h * 0.45, q.y), 0.07, h * 0.8, 6, PEDRA, Basis.IDENTITY, 0.05)
	var d3 := Vector3(b.x - a.x, yb - ya, b.y - a.y)
	var g := atan2(b.x - a.x, b.y - a.y)
	var bb := Basis(Vector3.UP, g) * Basis(Vector3.RIGHT, -atan2(yb - ya, L))
	var m := (a + b) * 0.5
	fora.caixa(Vector3(m.x, (ya + yb) * 0.5 + h * 0.92, m.y), Vector3(0.22, 0.14, d3.length() + 0.1), PEDRA_ESC, bb)
	fora.caixa(Vector3(m.x, (ya + yb) * 0.5 + 0.05, m.y), Vector3(0.24, 0.1, d3.length() + 0.1), PEDRA_ESC, bb)
	var pedacos := maxi(1, int(ceil(L / 0.9)))
	for k in pedacos:
		var t := (k + 0.5) / pedacos
		var q := a.lerp(b, t)
		col.append([Vector3(q.x, lerpf(ya, yb, t) + h * 0.5, q.y), Vector3(0.24, h + 0.2, L / pedacos), 0.0, Basis(Vector3.UP, g)])

# banco de igreja (assento + encosto + laterais), ao longo de X, virado para -Z (o altar)
func _banco_igreja(p: Vector3, comp: float, tombado := false) -> void:
	var b := Basis(Vector3.UP, r.randf_range(-0.03, 0.03))
	if tombado:
		b = Basis(Vector3.UP, r.randf_range(-0.5, 0.5)) * Basis(Vector3.RIGHT, -PI * 0.5)
	var o := p + (Vector3(0, 0.3, 0) if tombado else Vector3.ZERO)
	resto.caixa(o + b * Vector3(0, 0.45, 0), Vector3(comp, 0.07, 0.45), MADEIRA, b)
	resto.caixa(o + b * Vector3(0, 0.75, 0.24), Vector3(comp, 0.6, 0.06), MADEIRA * 0.9, b)
	resto.caixa(o + b * Vector3(0, 0.12, -0.15), Vector3(comp, 0.05, 0.25), MADEIRA * 0.8, b)    # genuflexório
	for s in [-0.5, 0.5]:
		resto.caixa(o + b * Vector3(s * comp, 0.5, 0.05), Vector3(0.07, 1.0, 0.6), MADEIRA * 0.85, b)
	col.append([o + b * Vector3(0, 0.5, 0.05), Vector3(comp, 1.0, 0.6), 0.0, b])

# ======================================================================================================
# IGREJA (48 x 66): nave alta (13 m) com colunatas, transepto e CÚPULA no cruzeiro, altar na abside, sacristia;
# PÓRTICO de 6 colunas com frontão e a inscrição, ESCADARIA larga até o embasamento de 2,4 m; CORO (mezanino) em cima
# da entrada com o órgão; TORRE DO SINO por cima da fachada: escada em caracol quadrada (em volta de um núcleo de
# pedra) do coro até o campanário (o lugar mais alto do bairro para vigiar) e o SINO (tocar = chamar os infectados).
# Por dentro virou ABRIGO: colchões nas naves laterais, caixas de doação, velas, o mural de recados e bancos
# empilhados barrando a porta do transepto oeste.
# ======================================================================================================
const NOMES_IGREJA := ["IGREJA DE SÃO PATRÍCIO", "IGREJA DE SANTO ANTÔNIO", "IGREJA DE NOSSA SENHORA DA PAZ", "IGREJA DE SÃO JOSÉ"]

func _igreja() -> void:
	var P := 2.4                         # embasamento (o piso da igreja)
	var HN := 13.0                       # altura da nave
	var E := 0.5                         # paredes grossas
	var nave := Rect2(-11, -22, 22, 37)  # x -11..11, z -22..15
	nome_igreja = NOMES_IGREJA[_numero_do_tipo() % NOMES_IGREJA.size()]
	dentro = Rect2(-18, -30, 36, 45)
	# ---- chão do terreno: adro de pedra, caminhos, canteiros, grade com portão ----
	_chao(Rect2(-24, 21, 48, 12), CONCRETO * 1.12)
	_chao(Rect2(-24, -33, 48, 54), CONCRETO * 0.95)
	for s in [-1.0, 1.0]:
		fora.caixa(Vector3(s * 16.5, 0.12, 26.5), Vector3(11.0, 0.24, 9.0), Color(0.3, 0.42, 0.22))       # canteiros
		fora.caixa(Vector3(s * 21.0, 0.12, 2.0), Vector3(5.0, 0.24, 24.0), Color(0.3, 0.42, 0.22))
		_grade(Vector2(s * 9.5, 32.5), Vector2(s * 23.5, 32.5), 0.0, METAL_ESC)
		_grade(Vector2(s * 23.5, 32.5), Vector2(s * 23.5, -32.5), 0.0, METAL_ESC)
		fora.caixa(Vector3(s * 9.5, 1.3, 32.5), Vector3(0.7, 2.6, 0.7), PEDRA_ESC)                      # pilares do portão
		fora.caixa(Vector3(s * 9.5, 2.7, 32.5), Vector3(0.9, 0.2, 0.9), PEDRA_ESC)
		_col(Vector3(s * 9.5, 1.3, 32.5), Vector3(0.7, 2.6, 0.7))
		# portão de ferro aberto (uma folha para cada lado)
		resto.caixa(Vector3(s * 8.6, 1.1, 31.6), Vector3(0.06, 2.0, 1.8), METAL_ESC, Basis(Vector3.UP, s * 0.3))
	_grade(Vector2(-23.5, -32.5), Vector2(23.5, -32.5), 0.0, METAL_ESC)
	_poste(Vector2(-11.5, 30.0), 0.0, 5.0)
	_poste(Vector2(11.5, 30.0), 0.0, 5.0)
	# estátua no canteiro (santo no pedestal)
	fora.caixa(Vector3(-16.5, 1.0, 26.5), Vector3(1.4, 1.6, 1.4), PEDRA_ESC)
	fora.cilindro(Vector3(-16.5, 2.65, 26.5), 0.35, 1.7, 8, PEDRA * 0.95, Basis.IDENTITY, 0.25)
	fora.cilindro(Vector3(-16.5, 3.65, 26.5), 0.2, 0.32, 8, PEDRA * 0.95)
	_col(Vector3(-16.5, 1.7, 26.5), Vector3(1.4, 3.4, 1.4))
	# ---- EMBASAMENTO (piso da igreja em y = P) ----
	for rb in [Rect2(-13, -30.5, 26, 51.5), Rect2(-18.5, -22.5, 37, 11)]:
		var cb: Vector2 = rb.get_center()
		_bx(fora, Vector3(cb.x, P * 0.5, cb.y), Vector3(rb.size.x, P, rb.size.y), GRANITO)
	fora.caixa(Vector3(0, P - 0.06, -4.75), Vector3(26.3, 0.14, 51.8), PEDRA_ESC)            # friso do embasamento
	# ESCADARIA da frente (16 m de largura) até o pórtico
	_escada(Vector2(0, 28.0), Vector2(0, -1), 16.0, 0.0, P, 7.0, GRANITO * 1.15)
	for s in [-1.0, 1.0]:
		_balaustrada(Vector2(s * 8.3, 28.2), Vector2(s * 8.3, 21.0), 0.0, P)
		_balaustrada(Vector2(s * 8.3, 21.0), Vector2(s * 12.8, 21.0), P, P)
		_balaustrada(Vector2(s * 12.8, 21.0), Vector2(s * 12.8, 15.4), P, P)
		fora.caixa(Vector3(s * 8.3, 0.6, 28.4), Vector3(0.8, 1.2, 0.8), PEDRA_ESC)
	# escadas laterais do transepto (portas de lado), descendo para a frente ao longo de X = ±15
	for s in [-1.0, 1.0]:
		_escada(Vector2(s * 15.0, -4.5), Vector2(0, -1), 3.0, 0.0, P, 7.0, GRANITO * 1.1)
		_balaustrada(Vector2(s * 16.65, -4.5), Vector2(s * 16.65, -11.5), 0.0, P)
	# ---- NAVE: paredes (porta principal e 2 portas menores na fachada, vitrais nos lados) ----
	var yb := P + 3.2                     # peitoril dos vitrais
	var hv := 5.6
	var vaos_lado: Array = []
	for zc in [10.5, 4.5, -1.5, -7.5]:
		vaos_lado.append(zc)
	# fachada (z = 15): porta grande no meio, 2 menores; rosácea em cima
	_parede(paredes, Vector2(-11 - E * 0.5, 15), Vector2(11 + E * 0.5, 15), P, HN, E, PEDRA, PEDRA, [[4.5, 8.0, 0.0, 4.2], [9.5, 13.0, 0.0, 5.4], [14.5, 18.0, 0.0, 4.2]], 1)
	paredes.cilindro(Vector3(0, P + 5.4, 15), 1.85, E + 0.03, 12, PEDRA_ESC, Basis(Vector3.RIGHT, PI * 0.5))      # arco da porta
	resto.cilindro(Vector3(0, P + 5.4, 15), 1.85 - 0.18, E + 0.07, 12, Color(0.2, 0.14, 0.1), Basis(Vector3.RIGHT, PI * 0.5))
	resto.cilindro(Vector3(0, P + 9.0, 15), 1.7, E + 0.08, 16, VITRAIS[0], Basis(Vector3.RIGHT, PI * 0.5))     # rosácea
	paredes.cilindro(Vector3(0, P + 9.0, 15), 1.95, E + 0.04, 16, PEDRA_ESC, Basis(Vector3.RIGHT, PI * 0.5))
	for k in 8:
		var a := k * TAU / 8.0
		resto.caixa(Vector3(cos(a) * 0.8, P + 9.0 + sin(a) * 0.8, 15), Vector3(0.08, 1.6, E + 0.1), Color(0.12, 0.12, 0.13), Basis(Vector3.BACK, a))
	# folhas da porta grande abertas para dentro (escuras, de madeira com ferragens)
	for s in [-1.0, 1.0]:
		resto.caixa(Vector3(s * 2.55, P + 2.7, 14.0), Vector3(0.12, 5.4, 1.85), MADEIRA * 0.8, Basis(Vector3.UP, s * 0.35))
	# laterais da nave (x = ±11), do transepto (z = -12) até a fachada
	for s in [-1.0, 1.0]:
		var a := Vector2(s * 11.0, 15.0 + E * 0.5) if s > 0 else Vector2(s * 11.0, -12.0)
		var b := Vector2(s * 11.0, -12.0) if s > 0 else Vector2(s * 11.0, 15.0 + E * 0.5)
		var vs: Array = []
		for zc in vaos_lado:
			var sc: float = (a.y - zc) if s > 0 else (zc - a.y)
			vs.append([sc - 0.9, sc + 0.9, yb - P, yb - P + hv, "vitral"])
		_parede(paredes, a, b, P, HN, E, PEDRA, PEDRA * 0.97, vs, 1)
		for k in vaos_lado.size():
			_vitral(Vector3(s * 11.0, yb, vaos_lado[k]), 1.8, hv, E, false, VITRAIS[(k + (1 if s > 0 else 3)) % VITRAIS.size()])
		# pilastras por fora entre os vitrais e a cornija no alto
		for zc in [13.5, 7.5, 1.5, -4.5, -10.5]:
			fora.caixa(Vector3(s * (11.0 + E * 0.5 + 0.12), P + HN * 0.5, zc), Vector3(0.25, HN, 0.9), PEDRA_ESC)
		fora.caixa(Vector3(s * (11.0 + E * 0.5 + 0.2), P + HN - 0.25, 1.5), Vector3(0.45, 0.5, 27.6), PEDRA_ESC)
	# ---- TRANSEPTO (x -18..18, z -22..-12): portas laterais (a oeste, barrada com bancos), rosáceas nas pontas ----
	for s in [-1.0, 1.0]:
		var x_fim: float = s * 18.0
		# frente do braço (z = -12, de x = ±11 até ±18) com a porta lateral
		var a := Vector2(s * 11.0, -12.0)
		var b := Vector2(x_fim + s * E * 0.5, -12.0)
		_parede(paredes, a if s > 0 else b, b if s > 0 else a, P, HN, E, PEDRA, PEDRA * 0.97, [[2.5, 5.5, 0.0, 3.6]] if s > 0 else [[1.75, 4.75, 0.0, 3.6]], 1)
		# fundo do braço (z = -22)
		_parede(paredes, Vector2(x_fim + s * E * 0.5, -22.0) if s > 0 else Vector2(s * 7.0, -22.0), Vector2(s * 7.0, -22.0) if s > 0 else Vector2(x_fim + s * E * 0.5, -22.0), P, HN, E, PEDRA, PEDRA * 0.97, [], 1)
		# ponta (x = ±18) com vitral grande
		var pa := Vector2(x_fim, -12.0) if s > 0 else Vector2(x_fim, -22.0)
		var pb := Vector2(x_fim, -22.0) if s > 0 else Vector2(x_fim, -12.0)
		_parede(paredes, pa, pb, P, HN, E, PEDRA, PEDRA * 0.97, [[4.0, 6.0, yb - P, yb - P + hv + 1.0, "vitral"]], 1)
		_vitral(Vector3(x_fim, yb, -17.0), 2.0, hv + 1.0, E, false, VITRAIS[(2 if s > 0 else 4)])
		resto.cilindro(Vector3(x_fim, P + HN - 2.2, -17.0), 1.1, E + 0.08, 12, VITRAIS[1], Basis(Vector3.FORWARD, PI * 0.5))
	# portas laterais: a leste aberta, a oeste barrada por dentro com bancos empilhados
	resto.caixa(Vector3(15.0, P + 1.8, -12.6), Vector3(3.0, 3.6, 0.1), MADEIRA * 0.8, Basis(Vector3.UP, 0.9))
	for k in 4:
		_banco_igreja(Vector3(-15.0 + r.randf_range(-0.4, 0.4), P + k * 0.55, -13.4 - k * 0.3), 3.6, k % 2 == 1)
	_col(Vector3(-15.0, P + 1.6, -13.0), Vector3(3.2, 3.2, 0.6))
	_texto(Vector3(-15.0, P + 4.3, -11.72), 0.0, "NÃO ABRAM", PICHE, 72)
	# ---- ABSIDE (x -7..7, z -30..-22), mais baixa, com o altar ----
	_parede(paredes, Vector2(-7.0, -22.0), Vector2(-7.0, -30.0 - E * 0.5), P, HN - 2.0, E, PEDRA, PEDRA * 0.97, [], -1)
	_parede(paredes, Vector2(7.0, -30.0 - E * 0.5), Vector2(7.0, -22.0), P, HN - 2.0, E, PEDRA, PEDRA * 0.97, [[1.5, 2.6, 0.0, 2.5]], -1)
	_parede(paredes, Vector2(7.0 + E * 0.5, -30.0), Vector2(-7.0 - E * 0.5, -30.0), P, HN - 2.0, E, PEDRA, PEDRA * 0.97,
		[[3.25, 4.85, yb - P + 1.0, yb - P + 5.0, "vitral"], [9.65, 11.25, yb - P + 1.0, yb - P + 5.0, "vitral"]], 1)
	_vitral(Vector3(3.2, yb + 1.0, -30.0), 1.6, 4.0, E, true, VITRAIS[2])
	_bx(paredes, Vector3(0, P + HN - 1.0, -22.0), Vector3(14.5, 2.0, E), PEDRA)            # arco por cima da abside (mais baixa)
	_vitral(Vector3(-3.2, yb + 1.0, -30.0), 1.6, 4.0, E, true, VITRAIS[0])
	# ---- SACRISTIA (x 7..13, z -30..-22.5): porta pela abside ----
	_parede(paredes, Vector2(13.0, -30.0), Vector2(13.0, -22.25), P, 4.0, E, PEDRA, PEDRA * 0.97, [[3.0, 4.2, 1.2, 2.4, "janela"]], -1)
	_parede(paredes, Vector2(13.0 + E * 0.5, -30.0), Vector2(7.0, -30.0), P, 4.0, E, PEDRA, PEDRA * 0.97, [], 1)
	_laje(Rect2(7.0, -30.0, 6.0, 7.75), P + 4.0, 0.3, [], ARDOSIA, true)
	_movel("armario_remedios", Vector3(12.4, P, -27.0), -PI * 0.5, "igreja_sacristia", "ARMÁRIO DA SACRISTIA")
	_movel("mesa_escritorio", Vector3(9.5, P, -28.6), 0.0, "igreja_sacristia", "GAVETA DA SACRISTIA")
	_movel("arara", Vector3(8.0, P, -24.0), PI * 0.5)
	_pontos_em(Rect2(7.6, -29.4, 4.8, 6.4), P, 2, "sacristia")
	# ---- forro, piso, telhados e a CÚPULA ----
	var cor_piso := Color(0.8, 0.74, 0.6)
	piso.caixa(Vector3(0, P + 0.02, -3.5), Vector3(21.5, 0.04, 36.5), cor_piso, Basis.IDENTITY, true)
	piso.caixa(Vector3(0, P + 0.02, -17.0), Vector3(35.5, 0.04, 9.5), cor_piso, Basis.IDENTITY, true)
	piso.caixa(Vector3(0, P + 0.02, -26.0), Vector3(13.5, 0.04, 7.5), cor_piso, Basis.IDENTITY, true)
	fora.caixa(Vector3(0, P + 0.045, -3.0), Vector3(2.0, 0.01, 34.0), Color(0.45, 0.16, 0.14), Basis.IDENTITY, true)   # tapete vermelho do corredor
	teto.caixa(Vector3(0, P + HN - 0.1, -1.8), Vector3(22.0, 0.2, 20.4), Color(0.92, 0.9, 0.84), Basis.IDENTITY, false, true)
	_laje(Rect2(-11.0, 8.4, 22.0, 6.6), P + HN - 0.3, 0.3, [Rect2(-3.6, 8.4, 7.2, 6.6)], ARDOSIA * 1.2, true)
	for s in [-1.0, 1.0]:
		fora.caixa(Vector3(s * 7.3, P + HN + 0.5, 15.0), Vector3(7.4, 1.0, 0.4), PEDRA)
		fora.caixa(Vector3(s * 11.0, P + HN + 0.5, 11.7), Vector3(0.4, 1.0, 6.6), PEDRA)
	teto.caixa(Vector3(0, P + HN - 0.1, -17.0), Vector3(36.0, 0.2, 10.0), Color(0.92, 0.9, 0.84), Basis.IDENTITY, false, true)
	teto.caixa(Vector3(0, P + HN - 2.1, -26.0), Vector3(14.0, 0.2, 8.0), Color(0.92, 0.9, 0.84), Basis.IDENTITY, false, true)
	teto.cilindro(Vector3(0, P + HN - 0.25, -17.0), 4.5, 0.1, 16, Color(0.55, 0.62, 0.78))     # céu pintado no cruzeiro
	_prisma(fora, Vector3(0, P + HN, -1.9), 23.4, 4.5, 20.6, true, ARDOSIA, PEDRA)
	_prisma(fora, Vector3(0, P + HN, -17.0), 37.4, 4.0, 10.6, false, ARDOSIA, PEDRA)
	_prisma(fora, Vector3(0, P + HN - 2.0, -26.0), 14.6, 2.6, 8.6, true, ARDOSIA, PEDRA)
	var yc := P + HN + 3.2
	fora.cilindro(Vector3(0, yc + 1.5, -17.0), 6.2, 3.0, 16, PEDRA)                             # tambor
	for k in 8:
		var a := k * TAU / 8.0 + 0.2
		resto.caixa(Vector3(cos(a) * 6.25, yc + 1.6, -17.0 + sin(a) * 6.25), Vector3(0.9, 1.6, 0.9), Color(0.15, 0.18, 0.25), Basis(Vector3.UP, -a))
	fora.cilindro(Vector3(0, yc + 3.1, -17.0), 6.6, 0.3, 16, PEDRA_ESC)
	_cupula(fora, Vector3(0, yc + 3.2, -17.0), 6.1, COBRE)
	fora.cilindro(Vector3(0, yc + 3.2 + 6.1 + 1.0, -17.0), 1.0, 2.0, 8, PEDRA)                  # lanterna da cúpula
	fora.cilindro(Vector3(0, yc + 3.2 + 6.1 + 2.4, -17.0), 1.2, 0.8, 8, COBRE, Basis.IDENTITY, 0.05)
	_cruz(Vector3(0, yc + 3.2 + 6.1 + 2.8, -17.0), 1.6)
	# ---- PÓRTICO: 6 colunas, entablamento com a inscrição e o FRONTÃO ----
	for x in [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5]:
		_coluna(Vector2(x, 19.6), P, 9.0, 0.6)
	for x in [-9.5, 9.5]:
		fora.caixa(Vector3(x, P + 4.5, 15.6), Vector3(1.2, 9.0, 1.2), PEDRA)                      # pilastras nos cantos
	piso.caixa(Vector3(0, P + 0.02, 18.0), Vector3(19.0, 0.04, 6.0), Color(0.68, 0.66, 0.62), Basis.IDENTITY, true)
	fora.caixa(Vector3(0, P + 9.55, 17.75), Vector3(20.0, 1.1, 5.9), PEDRA_ESC)               # arquitrave + friso
	fora.caixa(Vector3(0, P + 10.25, 17.8), Vector3(20.6, 0.3, 6.2), PEDRA_ESC * 0.95)        # cornija
	teto.caixa(Vector3(0, P + 8.95, 17.75), Vector3(19.6, 0.1, 5.6), Color(0.85, 0.83, 0.78), Basis.IDENTITY, false, true)
	_texto(Vector3(0, P + 9.55, 20.72), 0.0, nome_igreja, Color(0.25, 0.22, 0.18), 70)
	_prisma(fora, Vector3(0, P + 10.4, 17.8), 20.6, 3.8, 6.2, true, ARDOSIA, PEDRA)
	fora.cilindro(Vector3(0, P + 11.8, 20.92), 0.9, 0.12, 12, DOURADO, Basis(Vector3.RIGHT, PI * 0.5))   # medalhão
	_cruz(Vector3(0, P + 14.2, 20.6), 1.2)
	for s in [-1.0, 1.0]:                                                                      # estátuas nas pontas do frontão
		fora.cilindro(Vector3(s * 9.6, P + 11.2, 20.5), 0.32, 1.5, 8, PEDRA * 0.95, Basis.IDENTITY, 0.22)
		fora.cilindro(Vector3(s * 9.6, P + 12.1, 20.5), 0.18, 0.3, 8, PEDRA * 0.95)
	# ---- CORO (mezanino em cima da entrada, y = P + 6) com o órgão e a escada ----
	var yco := P + 6.0
	_laje(Rect2(-10.75, 8.4, 21.5, 6.35), yco - 0.3, 0.3, [], Color(0.45, 0.32, 0.22))
	_escada(Vector2(-10.0, -2.0), Vector2(0, 1), 1.4, P, 6.0, 10.4, MADEIRA * 1.1, 1)
	_balaustrada(Vector2(-9.1, 8.4), Vector2(10.75, 8.4), yco, yco)
	for x in [-7.0, 7.0]:
		_coluna(Vector2(x, 8.4), P, 5.7, 0.35, paredes)
	for k in 11:                                                                               # tubos do órgão
		var hx := 2.0 + absf(5 - k) * -0.25 + 3.2
		fora.cilindro(Vector3(-5.5 + k * 0.55 + (6.0 if k > 5 else 0.0), yco + hx * 0.5 + 0.9, 14.4), 0.16, hx, 6, Color(0.7, 0.68, 0.6))
	resto.caixa(Vector3(5.5, yco + 0.5, 13.6), Vector3(2.4, 1.0, 1.2), MADEIRA)               # console do órgão
	_movel("caixas", Vector3(8.5, yco, 12.5), 0.3, "igreja_abrigo", "CAIXAS NO CORO")
	_pontos_em(Rect2(-8.0, 9.2, 16.0, 4.6), yco, 3, "coro")
	# ---- TORRE DO SINO (sobe do coro, por cima da fachada) ----
	_torre_sino(Rect2(-3.6, 8.4, 7.2, 6.6), yco, P + HN + 7.0)
	# ---- dentro: colunatas, bancos, altar, púlpito, confessionários, o abrigo ----
	for s in [-1.0, 1.0]:
		for z in [6.0, 1.5, -3.0, -7.5]:
			_coluna(Vector2(s * 7.0, z), P, HN - 1.2, 0.42, paredes)
		paredes.caixa(Vector3(s * 7.0, P + HN - 0.7, -0.8), Vector3(0.7, 1.0, 15.6), PEDRA_ESC)   # arquitrave das colunatas
	for k in 12:
		var z := 5.4 - k * 1.25
		for s in [-1.0, 1.0]:
			if k == 9 and s < 0:
				continue                                                   # um banco tirado (está barrando a porta)
			_banco_igreja(Vector3(s * 4.0, P, z), 4.6, k == 4 and s > 0)
	# altar (presbitério elevado com 3 degraus) e o crucifixo
	_bx(piso, Vector3(0, P + 0.3, -26.0), Vector3(13.6, 0.6, 7.6), Color(0.6, 0.55, 0.5))
	_escada(Vector2(0, -21.0), Vector2(0, -1), 8.0, P, 0.6, 1.2, Color(0.6, 0.55, 0.5))
	_bx(resto, Vector3(0, P + 1.1, -25.6), Vector3(3.2, 1.0, 1.2), Color(0.85, 0.83, 0.78))
	resto.caixa(Vector3(0, P + 1.62, -25.6), Vector3(3.4, 0.05, 1.3), Color(0.92, 0.9, 0.86))
	for x in [-1.3, 1.3]:
		resto.cilindro(Vector3(x, P + 1.85, -25.8), 0.04, 0.45, 6, DOURADO)
		resto.cilindro(Vector3(x, P + 2.12, -25.8), 0.03, 0.12, 5, Color(0.95, 0.93, 0.85))
	resto.caixa(Vector3(0, P + 4.8, -29.65), Vector3(5.0, 6.0, 0.2), DOURADO * 0.9)            # retábulo
	resto.caixa(Vector3(0, P + 4.8, -29.55), Vector3(4.2, 5.2, 0.1), Color(0.45, 0.2, 0.15))
	resto.caixa(Vector3(0, P + 5.0, -29.4), Vector3(0.3, 4.0, 0.2), MADEIRA)                   # cruz grande
	resto.caixa(Vector3(0, P + 6.0, -29.4), Vector3(2.4, 0.3, 0.2), MADEIRA)
	# velas acesas no chão do presbitério (o abrigo)
	for k in 14:
		var pv := Vector2(r.randf_range(-5.5, 5.5), r.randf_range(-23.0, -22.0))
		resto.cilindro(Vector3(pv.x, P + 0.6 + 0.08, pv.y), 0.035, 0.16 * r.randf_range(0.5, 1.4), 5, Color(0.95, 0.93, 0.85))
	# púlpito
	resto.cilindro(Vector3(7.8, P + 1.6, -11.0), 0.9, 1.1, 8, MADEIRA)
	resto.cilindro(Vector3(7.8, P + 0.55, -11.0), 0.35, 1.1, 8, MADEIRA * 0.85)
	_col(Vector3(7.8, P + 1.0, -11.0), Vector3(1.6, 2.0, 1.6))
	# confessionários nos braços do transepto
	for s in [-1.0, 1.0]:
		var pc := Vector3(s * 16.6, P, -20.6)
		_bx(resto, pc + Vector3(0, 1.4, 0), Vector3(2.6, 2.8, 1.4), MADEIRA * 0.9)
		resto.caixa(pc + Vector3(0, 2.85, 0), Vector3(2.8, 0.15, 1.6), MADEIRA * 0.7)
		_loot(pc + Vector3(0, 0.1, 1.0), "igreja_abrigo", "CONFESSIONÁRIO", Vector2i(4, 3))
	# o ABRIGO: colchões e cobertores nas naves laterais e no transepto, caixas de doação, galões, o mural de recados
	for s in [-1.0, 1.0]:
		for k in 5:
			_movel("colchao", Vector3(s * 8.7, P, 11.0 - k * 4.2), PI * 0.5 + r.randf_range(-0.2, 0.2))
			resto.caixa(Vector3(s * 8.7 + r.randf_range(-0.3, 0.3), P + 0.22, 11.0 - k * 4.2 + 0.3), Vector3(0.9, 0.05, 1.4), VITRAIS[(k + 2) % VITRAIS.size()] * 0.7, Basis(Vector3.UP, r.randf() * 0.6))
		_ponto(Vector3(s * 9.0, P, 5.0), "abrigo")
		_ponto(Vector3(s * 9.2, P, -4.0), "abrigo")
	for k in 3:
		_movel("caixas", Vector3(-13.0 + k * 2.2, P, -20.6), 0.0, "igreja_doacoes", "DOAÇÕES")
	_movel("colchao", Vector3(12.5, P, -15.5), 0.0, "igreja_abrigo", "MOCHILA ESQUECIDA")
	_movel("colchao", Vector3(14.5, P, -15.5), 0.1)
	for k in 6:
		resto.cilindro(Vector3(10.0 + k * 0.6, P + 0.25, -21.3), 0.15, 0.5, 8, Color(0.75, 0.8, 0.85))      # galões de água vazios
	# mural de recados ao lado da porta (papéis e as frases)
	resto.caixa(Vector3(8.8, P + 2.0, 14.65), Vector3(3.0, 1.8, 0.05), Color(0.55, 0.4, 0.28))
	for k in 16:
		resto.caixa(Vector3(7.5 + (k % 6) * 0.48, P + 1.35 + (k / 6) * 0.5, 14.6), Vector3(0.3, 0.38, 0.01), Moveis.BRANCO * r.randf_range(0.75, 1.0), Basis(Vector3.BACK, r.randf_range(-0.2, 0.2)))
	_texto(Vector3(8.8, P + 3.2, 14.58), PI, "PROCURO MINHA FILHA · ANA · 7 ANOS", Color(0.2, 0.2, 0.25), 18)
	_texto(Vector3(8.8, P + 0.95, 14.58), PI, "FOMOS PARA O SUL. — MÃE", Color(0.2, 0.2, 0.25), 18)
	_texto(Vector3(-8.8, P + 3.2, 14.58), PI, "QUEM FOR MORDIDO SAI.", PICHE, 30)
	_bagunca(Rect2(-10, -12, 20, 24), P, 30)
	_pontos_em(Rect2(-6.5, -11.0, 13.0, 18.0), P, 6, "nave")
	_pontos_em(Rect2(-17.0, -21.0, 34.0, 8.0), P, 4, "transepto")
	# infectados: os refugiados que viraram (na nave, no transepto, no coro e no adro)
	for p in [Vector3(-2, P, 2), Vector3(2.5, P, -5), Vector3(-9, P, -2), Vector3(9, P, 8), Vector3(0, P, -14), Vector3(-13, P, -16),
			Vector3(14, P, -18), Vector3(0, P + 0.6, -24), Vector3(-5, yco, 11), Vector3(15, 0, 24), Vector3(-19, 0, 10)]:
		infectados.append(p)
	# carro abandonado na frente e um furgão de doações
	_carro(Vector2(-18.0, 29.0), PI * 0.5 + 0.2, Color(0.4, 0.42, 0.45))
	_furgao(Vector2(17.5, -24.0), 0.0, Color(0.85, 0.85, 0.82), "igreja_doacoes", "FURGÃO DE DOAÇÕES")

# conta quantos locais do mesmo tipo vêm antes deste (nome de cada igreja)
func _numero_do_tipo() -> int:
	var Locais = load("res://mundo/locais.gd")
	var n := 0
	for k in mini(idx, Locais.LOCAIS.size()):
		if Locais.LOCAIS[k][0] == tipo:
			n += 1
	return n

func _cruz(p: Vector3, h: float) -> void:
	fora.caixa(p + Vector3(0, h * 0.5, 0), Vector3(0.14, h, 0.14), DOURADO)
	fora.caixa(p + Vector3(0, h * 0.68, 0), Vector3(h * 0.55, 0.14, 0.14), DOURADO)

# TORRE DO SINO: base (ret) por cima do coro (y0) até o campanário (y_sino). Dentro, escada em CARACOL QUADRADA em
# volta de um núcleo de pedra (não tem vão para cair): lances encostados nas paredes, patamares nos cantos. Porta no
# fundo da torre (do coro). No campanário: 4 arcos abertos com parapeito, o SINO e, em cima, a agulha com a cruz.
func _torre_sino(ret: Rect2, y0: float, y_sino: float) -> void:
	var E := 0.4
	var i0 := ret.grow(-E)                         # vão de dentro
	var x0 := i0.position.x
	var x1 := i0.end.x
	var z0 := i0.position.y
	var z1 := i0.end.y
	var L := 1.15                                  # largura dos lances / tamanho dos patamares
	var subida := y_sino - y0
	# paredes da torre (do coro até o campanário); a porta fica no lado oeste (-X), em cima do piso do coro, de frente
	# para o 1º patamar (canto do fundo)
	var a0 := ret.position
	var a1 := Vector2(ret.end.x, ret.position.y)
	var a2 := ret.end
	var a3 := Vector2(ret.position.x, ret.end.y)
	var h_corpo := y_sino - y0
	_parede(paredes, a1, a0, y0, h_corpo, E, PEDRA, PEDRA * 0.95, [], 1)
	_parede(paredes, a2, a1, y0, h_corpo, E, PEDRA, PEDRA * 0.95, [], 1)
	_parede(paredes, a3, a2, y0, h_corpo, E, PEDRA, PEDRA * 0.95, [], 1)
	_parede(paredes, a0, a3, y0, h_corpo, E, PEDRA, PEDRA * 0.95, [[E, E + L, 0.0, 2.3]], 1)
	# relógios nas 3 faces de fora (acima do telhado)
	var yr := y_sino - 2.4
	var cx := ret.get_center()
	for f in [[Vector3(cx.x, yr, ret.end.y + 0.05), Basis(Vector3.RIGHT, PI * 0.5)], [Vector3(ret.end.x + 0.05, yr, cx.y), Basis(Vector3.FORWARD, PI * 0.5)],
			[Vector3(ret.position.x - 0.05, yr, cx.y), Basis(Vector3.FORWARD, PI * 0.5)]]:
		fora.cilindro(f[0], 1.35, 0.12, 16, Color(0.92, 0.9, 0.82), f[1])
		fora.cilindro(f[0], 1.5, 0.08, 16, DOURADO, f[1])
	resto.caixa(Vector3(cx.x, yr + 0.45, ret.end.y + 0.14), Vector3(0.07, 0.9, 0.03), Color(0.1, 0.1, 0.1))
	resto.caixa(Vector3(cx.x + 0.3, yr, ret.end.y + 0.14), Vector3(0.6, 0.06, 0.03), Color(0.1, 0.1, 0.1), Basis(Vector3.BACK, 0.4))
	# núcleo de pedra no meio (do coro até o campanário)
	var nucleo := Rect2(x0 + L, z0 + L, (x1 - x0) - 2.0 * L, (z1 - z0) - 2.0 * L)
	var nc := nucleo.get_center()
	_bx(paredes, Vector3(nc.x, y0 + subida * 0.5, nc.y), Vector3(nucleo.size.x, subida, nucleo.size.y), PEDRA_ESC)
	# lances: fundo (+X), direita (+Z), frente (-X), esquerda (-Z)... até a altura do campanário
	var lados := [[Vector2(x0 + L, z0 + L * 0.5), Vector2(1, 0), (x1 - x0) - 2.0 * L], [Vector2(x1 - L * 0.5, z0 + L), Vector2(0, 1), (z1 - z0) - 2.0 * L],
		[Vector2(x1 - L, z1 - L * 0.5), Vector2(-1, 0), (x1 - x0) - 2.0 * L], [Vector2(x0 + L * 0.5, z1 - L), Vector2(0, -1), (z1 - z0) - 2.0 * L]]
	var cantos := [Vector2(x0 + L * 0.5, z0 + L * 0.5), Vector2(x1 - L * 0.5, z0 + L * 0.5), Vector2(x1 - L * 0.5, z1 - L * 0.5), Vector2(x0 + L * 0.5, z1 - L * 0.5)]
	var total := 0.0
	var n_lances := 0
	while total < subida - 0.01:
		total += float(lados[n_lances % 4][2]) * 0.6
		n_lances += 1
	var k_esc := subida / total
	var y := y0
	_bx(piso, Vector3(cantos[0].x, y0 - 0.1, cantos[0].y), Vector3(L, 0.2, L), Color(0.5, 0.45, 0.4))
	for k in n_lances:
		var ld: Array = lados[k % 4]
		var dy := float(ld[2]) * 0.6 * k_esc
		_escada(ld[0], ld[1], L, y, dy, float(ld[2]), Color(0.55, 0.52, 0.48))
		y += dy
		var cn: Vector2 = cantos[(k + 1) % 4]
		_bx(piso, Vector3(cn.x, y - 0.1, cn.y), Vector3(L, 0.2, L), Color(0.5, 0.45, 0.4))
	# chão do campanário: vão em cima dos 2 últimos lances e do patamar entre eles (senão a cabeça bate na laje:
	# ali o piso fica só ~2 m abaixo); grade na borda do vão (do lado do sino); chega-se pelo canto do último patamar
	var vaos: Array = []
	for k in [n_lances - 2, n_lances - 1]:
		var ld: Array = lados[k % 4]
		var ini: Vector2 = ld[0]
		var dirl: Vector2 = ld[1]
		var fim: Vector2 = ini + dirl * (float(ld[2]) + (L if k == n_lances - 2 else 0.0))
		var lat := Vector2(-dirl.y, dirl.x) * L * 0.5
		var b0 := Vector2(minf(minf(ini.x, fim.x), minf(ini.x + lat.x, ini.x - lat.x)), minf(minf(ini.y, fim.y), minf(ini.y + lat.y, ini.y - lat.y)))
		var b1 := Vector2(maxf(maxf(ini.x, fim.x), maxf(ini.x + lat.x, ini.x - lat.x)), maxf(maxf(ini.y, fim.y), maxf(ini.y + lat.y, ini.y - lat.y)))
		vaos.append(Rect2(b0, b1 - b0).grow(0.05))
		# grade na borda de dentro (virada para o núcleo/sino)
		var dentro_v: Vector2 = (nucleo.get_center() - (ini + fim) * 0.5)
		var lado_n := Vector2(-dirl.y, dirl.x)
		if lado_n.dot(dentro_v) < 0.0:
			lado_n = -lado_n
		var ga: Vector2 = ini + lado_n * L * 0.5
		var gb2: Vector2 = ini + dirl * float(ld[2]) + lado_n * L * 0.5
		_grade(ga, gb2, y_sino)
	_laje(ret.grow(-0.05), y_sino - 0.3, 0.3, vaos, Color(0.5, 0.45, 0.4))
	# CAMPANÁRIO: pilares nos cantos, arcos abertos com parapeito, cornija; o SINO pendurado na viga
	var hc := 6.0
	for cn in [a0, a1, a2, a3]:
		var pc: Vector2 = cn                        # no canto de fora (para dentro só 0,1 m: o patamar de chegada fica livre)
		_bx(paredes, Vector3(pc.x, y_sino + hc * 0.5, pc.y), Vector3(1.0, hc, 1.0), PEDRA)
	for k in 4:
		var pa: Vector2 = [a0, a1, a2, a3][k]
		var pb: Vector2 = [a1, a2, a3, a0][k]
		var m := (pa + pb) * 0.5
		var em_x := absf(pb.x - pa.x) > 0.5
		var lw := pa.distance_to(pb) - 1.0
		_balaustrada(m - (pb - pa).normalized() * lw * 0.5, m + (pb - pa).normalized() * lw * 0.5, y_sino, y_sino, 1.05)
		paredes.caixa(Vector3(m.x, y_sino + hc - 0.9, m.y), Vector3(lw, 1.8, E) if em_x else Vector3(E, 1.8, lw), PEDRA)
		var dl := (pb - pa).normalized()
		for s in [-1.0, 1.0]:                                   # cantos chanfrados (cara de arco)
			var q: Vector2 = m + dl * (lw * 0.5 - 0.45) * s
			var giro_c := Basis(Vector3.BACK, PI * 0.25) if em_x else Basis(Vector3.RIGHT, PI * 0.25)
			paredes.caixa(Vector3(q.x, y_sino + hc - 1.8, q.y), Vector3(1.0, 1.0, E) if em_x else Vector3(E, 1.0, 1.0), PEDRA, giro_c)
	fora.caixa(Vector3(cx.x, y_sino + hc + 0.2, cx.y), Vector3(ret.size.x + 0.6, 0.4, ret.size.y + 0.6), PEDRA_ESC)
	_col(Vector3(cx.x, y_sino + hc + 0.2, cx.y), Vector3(ret.size.x + 0.6, 0.4, ret.size.y + 0.6))
	teto.caixa(Vector3(cx.x, y_sino + hc - 0.02, cx.y), Vector3(ret.size.x - 0.2, 0.04, ret.size.y - 0.2), Color(0.4, 0.32, 0.25))
	# o sino (no meio, fora do vão da escada) e a viga
	var ps := Vector3(cx.x - 0.6, y_sino, cx.y - 0.3)
	resto.caixa(Vector3(cx.x, y_sino + hc - 0.6, cx.y - 0.3), Vector3(ret.size.x - 0.8, 0.3, 0.3), MADEIRA)
	resto.cilindro(ps + Vector3(0, hc - 1.15, 0), 0.08, 0.6, 5, METAL_ESC)
	resto.cilindro(ps + Vector3(0, hc - 2.0, 0), 0.45, 1.1, 12, Color(0.55, 0.42, 0.2), Basis.IDENTITY, 0.32)
	resto.cilindro(ps + Vector3(0, hc - 2.9, 0), 0.85, 0.7, 12, Color(0.55, 0.42, 0.2), Basis.IDENTITY, 0.45)
	resto.cilindro(ps + Vector3(0, hc - 3.3, 0), 0.08, 0.5, 5, METAL_ESC)
	sinos.append(ps + Vector3(0, 1.0, 0))
	_caixa_militar(Vector3(cx.x + 0.9, y_sino, cx.y - 1.2), PI, "igreja_torre")    # alguém vigiava daqui
	resto.caixa(Vector3(cx.x - 1.6, y_sino + 0.25, cx.y + 1.4), Vector3(0.8, 0.5, 0.5), Color(0.25, 0.3, 0.22))
	_ponto(Vector3(cx.x - 1.8, y_sino, cx.y - 1.9), "torre")
	# agulha (oito lados) com a cruz
	var ya := y_sino + hc + 0.4
	fora.cilindro(Vector3(cx.x, ya + 0.6, cx.y), ret.size.x * 0.5 - 0.2, 1.2, 8, PEDRA)
	fora.cilindro(Vector3(cx.x, ya + 1.2 + 4.5, cx.y), ret.size.x * 0.5 - 0.4, 9.0, 8, ARDOSIA, Basis.IDENTITY, 0.05)
	_cruz(Vector3(cx.x, ya + 10.2, cx.y), 2.0)

# ======================================================================================================
# PREFEITURA DE NOVA YORK (96 x 76), no centro: palácio neoclássico de 2 andares (68 x 34) em cima de um embasamento
# de 1,5 m, PÓRTICO de 8 colunas com frontão e a inscrição, ROTUNDA no meio com a CÚPULA e os relógios, escadaria
# larga, praça com chafariz, mastros (bandeira de Nova York) e estátua.
# Térreo: saguão da rotunda (vão aberto até o 2º andar, 2 escadas), atendimento ao público, escritórios, PLENÁRIO
# em degraus e o ARQUIVO. 2º andar: galeria em volta do vão, GABINETE DO PREFEITO (cofre), CENTRO DE COMANDO DE
# CRISE (mesa com o mapa, rádios, o quadro da evacuação), escritórios e dormitório improvisado. Escada até o
# TERRAÇO (vigia a praça; ninho de sacos de areia que os soldados deixaram).
# Na frente, o POSTO DO EXÉRCITO abandonado da evacuação: sacos de areia, barreiras em zigue-zague, barracas,
# caminhão e jipe militares, caixas — e as faixas "EVACUAÇÃO — DIRIJAM-SE AO SUL" (a frase do rádio no Livro 1).
# ======================================================================================================
const AZUL_NY := Color(0.1, 0.2, 0.55)
const LARANJA_NY := Color(0.9, 0.45, 0.1)

func _prefeitura() -> void:
	var P := 1.5                          # embasamento
	var A := 5.0                          # andar (piso a piso)
	var B := Rect2(-34, -26, 68, 34)      # o palácio
	var x0 := B.position.x
	var x1 := B.end.x
	var z0 := B.position.y
	var z1 := B.end.y
	var pedra2 := Color(0.86, 0.83, 0.76)
	dentro = B.grow(-ESP * 0.5)
	# ---- chão: praça de pedra, canteiros, estacionamento atrás ----
	_chao(Rect2(-48, 14, 96, 24), CONCRETO * 1.12)
	_chao(Rect2(-48, -38, 96, 52), CONCRETO * 0.95)
	_chao(Rect2(-30, -38, 60, 10), ASFALTO)
	_vagas(-28.0, 28.0, -38.0, 5.0)
	for s in [-1.0, 1.0]:
		fora.caixa(Vector3(s * 31.0, 0.12, 21.0), Vector3(26.0, 0.24, 6.0), Color(0.3, 0.42, 0.22))
		fora.caixa(Vector3(s * 42.0, 0.12, -6.0), Vector3(8.0, 0.24, 36.0), Color(0.3, 0.42, 0.22))
	# ---- EMBASAMENTO e ESCADARIAS ----
	_bx(fora, Vector3(0, P * 0.5, -9.0), Vector3(69.0, P, 35.0), GRANITO)
	_bx(fora, Vector3(0, P * 0.5, 11.0), Vector3(25.0, P, 6.0), GRANITO)
	_escada(Vector2(0, 18.3), Vector2(0, -1), 22.0, 0.0, P, 4.3, GRANITO * 1.15)
	for s in [-1.0, 1.0]:
		_balaustrada(Vector2(s * 11.3, 18.4), Vector2(s * 11.3, 14.0), 0.0, P)
		_balaustrada(Vector2(s * 12.5, 14.0), Vector2(s * 12.5, 8.5), P, P)
		fora.caixa(Vector3(s * 11.3, 0.6, 18.6), Vector3(0.8, 1.2, 0.8), PEDRA_ESC)
	_escada(Vector2(20.0, -29.0), Vector2(0, 1), 2.4, 0.0, P, 2.5, GRANITO * 1.1, 1)
	# ---- PAREDES DE FORA (2 andares) ----
	var porta_frente := [32.0, 36.0, 0.0, 4.4]
	var frente0 := _janelas(68.0, 3.4, 1.5, 1.2, 3.8, [porta_frente])
	var dir0 := _janelas(34.0, 3.4, 1.5, 1.2, 3.8, [])
	var fundo0 := _janelas(68.0, 3.4, 1.5, 1.2, 3.8, [[13.0, 15.0, 0.0, 2.6]], 0.8)
	var esq0 := _janelas(34.0, 3.4, 1.5, 1.2, 3.8, [])
	_perimetro(B, P, A, pedra2, Color(0.9, 0.88, 0.82), [frente0, dir0, fundo0, esq0])
	var j1 := [_janelas(68.0, 3.4, 1.5, 1.2, 3.8, []), _janelas(34.0, 3.4, 1.5, 1.2, 3.8, []), _janelas(68.0, 3.4, 1.5, 1.2, 3.8, [], 0.85), _janelas(34.0, 3.4, 1.5, 1.2, 3.8, [])]
	_perimetro(B, P + A, A, pedra2, Color(0.9, 0.88, 0.82), j1)
	# frontõezinhos em cima das janelas da frente do 2º andar, frisos, cornija, pilastras
	for v in j1[0]:
		var xm: float = x0 + (float(v[0]) + float(v[1])) * 0.5
		if absf(xm) < 12.6:
			continue
		_prisma(fora, Vector3(xm, P + A + 4.0, z1 + 0.25), 2.0, 0.55, 0.3, true, PEDRA_ESC)
	for y in [P + A, P + 2.0 * A]:
		fora.caixa(Vector3(0, y - 0.15, -9.0), Vector3(68.8, 0.35, 34.8), PEDRA_ESC, Basis.IDENTITY, true)
	fora.caixa(Vector3(0, P + 2.0 * A + 0.2, -9.0), Vector3(69.4, 0.4, 35.4), PEDRA_ESC)
	for k in 11:
		var xp := x0 + 0.3 + k * 6.74
		if absf(xp) < 12.6:
			continue
		fora.caixa(Vector3(xp, P + A, z1 + 0.22), Vector3(0.7, 2.0 * A, 0.16), PEDRA_ESC)
	# balaustrada em volta do terraço
	_balaustrada(Vector2(x0 + 0.3, z1 - 0.3), Vector2(x1 - 0.3, z1 - 0.3), P + 2.0 * A, P + 2.0 * A)
	_balaustrada(Vector2(x1 - 0.3, z1 - 0.3), Vector2(x1 - 0.3, z0 + 0.3), P + 2.0 * A, P + 2.0 * A)
	_balaustrada(Vector2(x1 - 0.3, z0 + 0.3), Vector2(x0 + 0.3, z0 + 0.3), P + 2.0 * A, P + 2.0 * A)
	_balaustrada(Vector2(x0 + 0.3, z0 + 0.3), Vector2(x0 + 0.3, z1 - 0.3), P + 2.0 * A, P + 2.0 * A)
	# ---- PÓRTICO: 8 colunas, entablamento com a inscrição, frontão com o brasão ----
	for x in [-10.5, -7.5, -4.5, -1.5, 1.5, 4.5, 7.5, 10.5]:
		_coluna(Vector2(x, 12.8), P, 9.0, 0.6)
	piso.caixa(Vector3(0, P + 0.02, 11.0), Vector3(24.0, 0.04, 6.0), Color(0.72, 0.7, 0.66), Basis.IDENTITY, true)
	fora.caixa(Vector3(0, P + 9.55, 11.1), Vector3(25.0, 1.1, 6.4), PEDRA_ESC)
	fora.caixa(Vector3(0, P + 10.25, 11.15), Vector3(25.6, 0.3, 6.7), PEDRA_ESC * 0.95)
	teto.caixa(Vector3(0, P + 8.95, 11.1), Vector3(24.6, 0.1, 6.0), Color(0.85, 0.83, 0.78), Basis.IDENTITY, false, true)
	_texto(Vector3(0, P + 9.55, 14.32), 0.0, "PREFEITURA DE NOVA YORK", Color(0.25, 0.22, 0.18), 80)
	_prisma(fora, Vector3(0, P + 10.4, 11.15), 25.6, 3.4, 6.7, true, ARDOSIA, pedra2)
	fora.cilindro(Vector3(0, P + 11.6, 14.52), 1.0, 0.12, 12, DOURADO, Basis(Vector3.RIGHT, PI * 0.5))
	for s in [-1.0, 1.0]:
		fora.caixa(Vector3(s * 0.55, P + 11.6, 14.6), Vector3(0.9, 0.35, 0.05), DOURADO, Basis(Vector3.BACK, s * 0.4))   # asas da águia
	# faixas da evacuação penduradas no pórtico (entre as colunas, lá em cima)
	for s in [-1.0, 1.0]:
		resto.caixa(Vector3(s * 6.0, P + 6.9, 12.85), Vector3(2.6, 3.4, 0.04), Color(0.92, 0.9, 0.85))
		_texto(Vector3(s * 6.0, P + 7.6, 12.9), 0.0, "EVACUAÇÃO", Color(0.7, 0.08, 0.06), 46)
		_texto(Vector3(s * 6.0, P + 6.7, 12.9), 0.0, "DIRIJAM-SE", Color(0.15, 0.15, 0.18), 34)
		_texto(Vector3(s * 6.0, P + 6.1, 12.9), 0.0, "AO SUL", Color(0.15, 0.15, 0.18), 46)
	# ---- ROTUNDA: tambor com relógios, CÚPULA, lanterna e a bandeira ----
	var yt := P + 2.0 * A
	var cr := Vector3(0, yt, -9.0)
	fora.cilindro(cr + Vector3(0, 0.6, 0), 9.4, 1.2, 20, PEDRA_ESC)
	fora.cilindro(cr + Vector3(0, 3.7, 0), 8.6, 5.0, 20, pedra2)
	for k in 12:
		var a := k * TAU / 12.0
		if k % 3 == 0:
			continue
		resto.caixa(cr + Vector3(cos(a) * 8.62, 3.6, sin(a) * 8.62), Vector3(1.0, 2.4, 0.3), Color(0.14, 0.17, 0.22), Basis(Vector3.UP, -a + PI * 0.5))
	for k in 4:                                                                  # 4 relógios
		var a := k * TAU / 4.0
		var pr := cr + Vector3(cos(a) * 8.65, 3.8, sin(a) * 8.65)
		var bb := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
		fora.cilindro(pr, 1.5, 0.12, 16, Color(0.93, 0.91, 0.84), bb)
		fora.cilindro(pr - Vector3(cos(a), 0, sin(a)) * 0.03, 1.7, 0.1, 16, DOURADO, bb)
	fora.cilindro(cr + Vector3(0, 6.35, 0), 9.0, 0.3, 20, PEDRA_ESC)
	_cupula(fora, cr + Vector3(0, 6.5, 0), 8.3, COBRE, 7, 20)
	fora.cilindro(cr + Vector3(0, 6.5 + 8.3 + 1.4, 0), 1.6, 2.8, 8, pedra2)
	_cupula(fora, cr + Vector3(0, 6.5 + 8.3 + 2.8, 0), 1.7, COBRE, 3, 8)
	fora.cilindro(cr + Vector3(0, 6.5 + 8.3 + 4.5 + 3.0, 0), 0.07, 6.0, 5, METAL_ESC)
	_bandeira_ny(cr + Vector3(0.05, 6.5 + 8.3 + 4.5 + 5.2, 0), 2.6)
	_col(cr + Vector3(0, 2.6, 0), Vector3(17.2, 5.2, 17.2))
	# ---- LAJES: 2º andar (vão da rotunda e 2 escadas), terraço (escada) ----
	var vao_rot := Rect2(-7.0, -16.0, 14.0, 12.0)
	var esc_e := Rect2(-11.0, -4.6, 2.0, 8.8)
	var esc_d := Rect2(9.0, -4.6, 2.0, 8.8)
	var esc_t := Rect2(31.5, -18.4, 2.0, 8.5)
	piso.caixa(Vector3(0, P + 0.02, -9.0), Vector3(67.6, 0.04, 33.6), Color(0.76, 0.72, 0.64), Basis.IDENTITY, true)
	_laje(B.grow(-0.05), P + A - 0.5, 0.5, [vao_rot, esc_e, esc_d], Color(0.55, 0.4, 0.28))
	_laje(B.grow(-0.05), P + 2.0 * A - 0.5, 0.5, [esc_t], CONCRETO, true)
	teto.cilindro(Vector3(0, P + 2.0 * A - 0.56, -10.0), 5.5, 0.04, 20, Color(0.55, 0.62, 0.78))   # céu pintado em cima do saguão
	# as 2 escadas do saguão (sobem para o fundo) e a do terraço
	_escada(Vector2(-10.0, 4.0), Vector2(0, -1), 1.8, P, A, 8.3, Color(0.8, 0.78, 0.72), 1)
	_escada(Vector2(10.0, 4.0), Vector2(0, -1), 1.8, P, A, 8.3, Color(0.8, 0.78, 0.72), -1)
	_escada(Vector2(32.5, -10.0), Vector2(0, -1), 1.8, P + A, A, 8.3, CONCRETO, 1)
	# balaustradas em volta do vão da rotunda e das escadas (2º andar)
	var y2 := P + A
	_balaustrada(Vector2(-7.0, -16.0), Vector2(7.0, -16.0), y2, y2)
	_balaustrada(Vector2(-7.0, -4.0), Vector2(7.0, -4.0), y2, y2)
	_balaustrada(Vector2(-7.0, -16.0), Vector2(-7.0, -4.0), y2, y2)
	_balaustrada(Vector2(7.0, -16.0), Vector2(7.0, -4.0), y2, y2)
	for s in [-1.0, 1.0]:
		_balaustrada(Vector2(s * 9.0, 4.2), Vector2(s * 9.0, -4.0), y2, y2)
		_balaustrada(Vector2(s * 9.0, 4.2), Vector2(s * 11.0, 4.2), y2, y2)
		_balaustrada(Vector2(s * 11.0, 4.2), Vector2(s * 11.0, -4.0), y2, y2)
	# casinha da escada no terraço: a escada chega no fundo (sul) e sai pela porta do oeste; grade no vão
	var casa := Rect2(29.4, -20.4, 4.6, 11.2)
	_perimetro(casa, yt, 2.8, CONCRETO, CONCRETO, [[], [], [], [[0.6, 2.6, 0.0, 2.4]]], fora)
	_grade(Vector2(31.5, -17.0), Vector2(31.5, -9.9), yt)
	fora.caixa(Vector3(casa.get_center().x, yt + 2.95, casa.get_center().y), Vector3(casa.size.x + 0.4, 0.3, casa.size.y + 0.4), CONCRETO_ESC)
	_col(Vector3(casa.get_center().x, yt + 2.95, casa.get_center().y), Vector3(casa.size.x + 0.4, 0.3, casa.size.y + 0.4))
	# ---- TÉRREO: paredes de dentro ----
	_parede(paredes, Vector2(-12.0, z0), Vector2(-12.0, z1), P, A - 0.5, DIV, Color.WHITE, Color(0.9, 0.88, 0.82), [_porta(10.0), _porta(28.0)])
	_parede(paredes, Vector2(12.0, z0), Vector2(12.0, z1), P, A - 0.5, DIV, Color.WHITE, Color(0.9, 0.88, 0.82), [_porta(10.0), _porta(28.0)])
	_parede(paredes, Vector2(x0, -8.0), Vector2(-12.0, -8.0), P, A - 0.5, DIV, Color.WHITE, Color(0.88, 0.86, 0.8), [_porta(11.0)])
	_parede(paredes, Vector2(12.0, -4.0), Vector2(x1, -4.0), P, A - 0.5, DIV, Color.WHITE, Color(0.88, 0.86, 0.8), [_porta(4.0), _porta(16.0)])
	# saguão: piso de mármore em xadrez, balcão de informações, bancos, retratos
	for k in 36:
		var q := Vector2(-5.0 + (k % 6) * 2.0, -15.0 + (k / 6) * 2.0)
		if (k % 6 + k / 6) % 2 == 0:
			piso.caixa(Vector3(q.x, P + 0.045, q.y), Vector3(2.0, 0.01, 2.0), Color(0.3, 0.28, 0.27), Basis.IDENTITY, true)
	_movel("balcao", Vector3(0, P, -18.5), 0.0, "escritorio", "BALCÃO DE INFORMAÇÕES")
	_movel("cadeiras_espera", Vector3(-6.0, P, 5.5), PI)
	_movel("cadeiras_espera", Vector3(6.0, P, 5.5), PI)
	for s in [-1.0, 1.0]:
		resto.caixa(Vector3(s * 11.85, P + 2.6, -10.0), Vector3(0.05, 1.6, 1.2), MADEIRA * 1.2)              # retratos
		resto.caixa(Vector3(s * 11.82, P + 2.6, -10.0), Vector3(0.05, 1.3, 0.9), Color(0.35, 0.3, 0.25))
		_movel("planta", Vector3(s * 7.5, P, 6.5), 0.0)
	_texto(Vector3(0, P + 3.6, -21.5), 0.0, "CIDADE DE NOVA YORK", DOURADO * 0.8, 60)
	paredes.caixa(Vector3(0, P + 2.25, -21.8), Vector3(14.0, 4.5, 0.2), Color(0.86, 0.83, 0.76))
	_col(Vector3(0, P + 2.25, -21.8), Vector3(14.0, 4.5, 0.2))
	# ATENDIMENTO AO PÚBLICO (oeste, frente): balcões com divisórias, cadeiras de espera, senhas
	for k in 4:
		_movel("balcao", Vector3(-30.0 + k * 4.4, P, -4.5), 0.0, "escritorio", "GUICHÊ %d" % (k + 1))
	_movel("cadeiras_espera", Vector3(-24.0, P, 2.5), PI)
	_movel("cadeiras_espera", Vector3(-18.0, P, 2.5), PI)
	_texto(Vector3(-23.0, P + 3.4, -7.9), 0.0, "ATENDIMENTO AO CIDADÃO", Color(0.15, 0.2, 0.35), 40)
	_pontos_em(Rect2(-33, -7, 20, 14), P, 3, "atendimento")
	# ESCRITÓRIOS (oeste, fundo)
	for k in 6:
		var px := -31.0 + (k % 3) * 6.5
		var pz := -23.5 + (k / 3) * 7.0
		_movel("mesa_escritorio", Vector3(px, P, pz), 0.0, "escritorio", "MESA")
		_movel("cadeira", Vector3(px, P, pz + 1.1), PI)
	_movel("arquivo", Vector3(-13.0, P, -25.2), 0.0, "escritorio", "ARQUIVO")
	_movel("arquivo", Vector3(-14.4, P, -25.2), 0.0)
	_bagunca(Rect2(-33, -25, 20, 16), P, 30)
	_pontos_em(Rect2(-33, -25, 20, 16), P, 3, "escritorio")
	# PLENÁRIO (leste, fundo): mesa da presidência, 3 fileiras em degraus, galeria do público
	_bx(resto, Vector3(23.0, P + 0.4, -24.0), Vector3(12.0, 0.8, 3.0), MADEIRA * 0.8)
	_escada(Vector2(23.0, -21.6), Vector2(0, -1), 3.0, P, 0.8, 0.9, MADEIRA * 0.8)
	_bx(resto, Vector3(23.0, P + 1.3, -24.4), Vector3(9.0, 1.0, 0.9), MADEIRA)
	resto.caixa(Vector3(23.0, P + 3.6, -25.85), Vector3(3.0, 2.6, 0.06), AZUL_NY)
	_texto(Vector3(23.0, P + 3.6, -25.8), 0.0, "CONSELHO MUNICIPAL", Color(0.95, 0.85, 0.5), 30)
	for k in 3:
		var zf := -17.5 + k * 3.0
		var yf := P + k * 0.35
		if k > 0:
			_bx(piso, Vector3(23.0, P + k * 0.35 * 0.5, zf), Vector3(20.0, k * 0.35, 3.0), MADEIRA * 0.7)
		for x in [16.0, 20.5, 25.5, 30.0]:
			_bx(resto, Vector3(x, yf + 0.4, zf - 0.6), Vector3(3.6, 0.8, 0.6), MADEIRA)
			_movel("cadeira", Vector3(x, yf, zf + 0.3), PI)
	_movel("mesa_escritorio", Vector3(16.0, P, -24.0), 0.0, "prefeitura_gabinete", "MESA DO PRESIDENTE DO CONSELHO")
	_pontos_em(Rect2(13, -20, 20, 14), P, 3, "plenario")
	# ARQUIVO (leste, frente): estantes em fileiras
	for k in 5:
		_movel("estante_livros", Vector3(15.0 + k * 3.8, P, -2.5), 0.0, "escritorio", "ESTANTE DO ARQUIVO")
		_movel("arquivo", Vector3(15.0 + k * 3.8, P, 6.8), PI, "escritorio", "ARQUIVO")
	_bagunca(Rect2(13, -3, 20, 10), P, 40)
	_pontos_em(Rect2(13, -2, 20, 8), P, 2, "arquivo")
	# ---- 2º ANDAR: paredes de dentro ----
	_parede(paredes, Vector2(-12.0, z0), Vector2(-12.0, z1), y2, A - 0.5, DIV, Color.WHITE, Color(0.9, 0.88, 0.82), [_porta(10.0), _porta(28.0)])
	_parede(paredes, Vector2(12.0, z0), Vector2(12.0, z1), y2, A - 0.5, DIV, Color.WHITE, Color(0.9, 0.88, 0.82), [_porta(10.0), _porta(28.0)])
	_parede(paredes, Vector2(x0, -8.0), Vector2(-12.0, -8.0), y2, A - 0.5, DIV, Color.WHITE, Color(0.88, 0.86, 0.8), [_porta(17.0)])
	_parede(paredes, Vector2(12.0, -8.0), Vector2(x1, -8.0), y2, A - 0.5, DIV, Color.WHITE, Color(0.88, 0.86, 0.8), [_porta(4.0)])
	# GABINETE DO PREFEITO (oeste, frente): mesa grande, cofre, bandeiras, sofá, estantes
	_movel("tapete", Vector3(-23.0, y2, 0.0), 0.0)
	_movel("mesa_escritorio", Vector3(-23.0, y2, -3.0), 0.0, "prefeitura_gabinete", "MESA DO PREFEITO")
	_movel("cadeira", Vector3(-23.0, y2, -4.2), 0.0)
	_movel("sofa", Vector3(-30.0, y2, 3.0), PI * 0.5)
	_movel("mesa_centro", Vector3(-28.0, y2, 3.0), 0.0)
	_movel("estante_livros", Vector3(-33.4, y2, -4.0), PI * 0.5, "escritorio", "ESTANTE")
	_bx(resto, Vector3(-14.0, y2 + 0.6, -6.9), Vector3(1.0, 1.2, 0.9), Color(0.25, 0.27, 0.28))                    # cofre
	resto.cilindro(Vector3(-14.0, y2 + 0.7, -6.43), 0.15, 0.06, 8, Color(0.7, 0.7, 0.68), Basis(Vector3.RIGHT, PI * 0.5))
	_loot(Vector3(-14.0, y2 + 0.1, -6.0), "prefeitura_cofre", "COFRE DO PREFEITO", Vector2i(5, 4))
	for s in [-1.0, 1.0]:
		resto.cilindro(Vector3(-23.0 + s * 3.0, y2 + 1.3, -7.4), 0.03, 2.6, 5, DOURADO)
	_bandeira_ny(Vector3(-25.95, y2 + 2.1, -7.4), 1.2)
	_texto(Vector3(-23.0, y2 + 3.4, -7.85), 0.0, "GABINETE DO PREFEITO", DOURADO * 0.8, 34)
	_pontos_em(Rect2(-33, -6, 18, 12), y2, 2, "gabinete")
	# CENTRO DE COMANDO DE CRISE (oeste, fundo): mesa com o mapa, rádios, telas, o quadro da evacuação, colchonetes
	var cm := Vector3(-23.0, y2, -17.0)
	_bx(resto, cm + Vector3(0, 0.45, 0), Vector3(7.0, 0.9, 3.4), MADEIRA * 0.9)
	resto.caixa(cm + Vector3(0, 0.915, 0), Vector3(6.6, 0.02, 3.0), Color(0.82, 0.8, 0.7))                         # o mapa
	for k in 9:
		resto.caixa(cm + Vector3(-3.0 + k * 0.75, 0.93, r.randf_range(-1.2, 1.2)), Vector3(0.05, 0.01, r.randf_range(1.0, 2.4)), Color(0.3, 0.3, 0.32), Basis(Vector3.UP, r.randf_range(-0.6, 0.6)))
	resto.caixa(cm + Vector3(-1.5, 0.93, 0.4), Vector3(1.2, 0.01, 0.8), Color(0.7, 0.15, 0.12))                    # zonas marcadas
	resto.caixa(cm + Vector3(2.0, 0.93, -0.8), Vector3(0.9, 0.01, 1.1), Color(0.7, 0.15, 0.12))
	_texto(cm + Vector3(0, 0.96, 1.2), 0.0, "NOVA YORK", Color(0.2, 0.2, 0.25), 30)
	for k in 6:
		var pr := Vector3(-33.2, y2, -24.5 + k * 2.6)
		_bx(resto, pr + Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 2.2), Color(0.45, 0.46, 0.48))                     # bancada dos rádios
		resto.caixa(pr + Vector3(0.1, 1.15, 0), Vector3(0.6, 0.5, 0.9), Color(0.18, 0.2, 0.18))
		resto.caixa(pr + Vector3(0.15, 1.6, 0.0), Vector3(0.06, 0.55, 0.8), Color(0.06, 0.08, 0.1))
	_movel("mesa_escritorio", Vector3(-15.0, y2, -24.5), 0.0, "prefeitura_crise", "MESA DO COMANDO")
	_movel("mesa_escritorio", Vector3(-15.0, y2, -19.5), 0.0, "prefeitura_crise", "MESA DO COMANDO")
	_movel("caixas", Vector3(-18.0, y2, -25.0), 0.0, "prefeitura_crise", "SUPRIMENTOS")
	resto.caixa(Vector3(-23.0, y2 + 2.1, -25.85), Vector3(6.0, 2.2, 0.05), Color(0.94, 0.94, 0.92))                # o quadro
	_texto(Vector3(-23.0, y2 + 2.8, -25.8), 0.0, "EVACUAÇÃO · ZONA SUL", Color(0.7, 0.1, 0.08), 34)
	_texto(Vector3(-23.0, y2 + 2.2, -25.8), 0.0, "PONTES FECHADAS ÀS 06:00", Color(0.15, 0.2, 0.45), 26)
	_texto(Vector3(-23.0, y2 + 1.7, -25.8), 0.0, "HOSPITAIS = QUARENTENA", Color(0.15, 0.2, 0.45), 26)
	_texto(Vector3(-23.0, y2 + 1.25, -25.8), 0.0, "SEM CONTATO COM A GUARDA DESDE ONTEM", Color(0.7, 0.1, 0.08), 20)
	for k in 3:
		_movel("colchao", Vector3(-30.0 + k * 2.4, y2, -11.0), 0.0)
	_texto(Vector3(-23.0, y2 + 3.4, -8.15), PI, "COMANDO DE CRISE", Color(0.7, 0.1, 0.08), 34)
	_pontos_em(Rect2(-33, -25, 18, 14), y2, 3, "crise")
	# leste do 2º andar: escritórios (frente) e o DORMITÓRIO improvisado (fundo)
	for k in 4:
		_movel("mesa_escritorio", Vector3(16.0 + k * 4.6, y2, -1.0), 0.0, "escritorio", "MESA")
	_movel("estante_livros", Vector3(33.4, y2, 2.0), -PI * 0.5, "escritorio", "ESTANTE")
	_pontos_em(Rect2(13, -6, 18, 12), y2, 2, "escritorio")
	for k in 4:
		_beliche(Vector3(15.0 + k * 3.2, y2, -24.0), 0.0)
	for k in 3:
		_movel("colchao", Vector3(16.0 + k * 2.4, y2, -14.0), 0.0)
	_movel("caixas", Vector3(28.0, y2, -25.0), 0.0, "prefeitura_crise", "CAIXAS DE SUPRIMENTOS")
	_pontos_em(Rect2(13, -25, 16, 14), y2, 2, "dormitorio")
	# ---- TERRAÇO: ninho de sacos de areia virado para a praça, caixa militar, antenas ----
	_sacos(Vector2(-20.0, 6.0), Vector2(-14.0, 6.0), 3, yt)
	_sacos(Vector2(-20.0, 6.0), Vector2(-20.0, 3.0), 3, yt)
	_sacos(Vector2(14.0, 6.0), Vector2(20.0, 6.0), 3, yt)
	_caixa_militar(Vector3(-17.0, yt, 3.5), 0.1, "militar")
	_caixa_militar(Vector3(17.0, yt, 3.5), -0.1, "militar")
	for p in [Vector2(-28, -20), Vector2(24, 0), Vector2(-26, -2)]:
		_bx(fora, Vector3(p.x, yt + 0.7, p.y), Vector3(2.2, 1.4, 1.6), Color(0.6, 0.62, 0.62))
	fora.cilindro(Vector3(28.0, yt + 4.0, -22.0), 0.08, 8.0, 5, METAL_ESC)
	_ponto(Vector3(-17.0, yt, 1.5), "terraco")
	_ponto(Vector3(17.0, yt, 1.5), "terraco")
	# ---- PRAÇA: chafariz, mastros, estátua, bancos, postes ----
	var cf := Vector2(0, 27.5)
	fora.cilindro(Vector3(cf.x, 0.35, cf.y), 4.6, 0.7, 20, PEDRA_ESC)
	fora.cilindro(Vector3(cf.x, 0.62, cf.y), 4.15, 0.1, 20, Color(0.18, 0.28, 0.27))                               # água parada
	fora.cilindro(Vector3(cf.x, 1.4, cf.y), 0.55, 2.2, 10, PEDRA)
	fora.cilindro(Vector3(cf.x, 2.55, cf.y), 1.5, 0.3, 12, PEDRA_ESC, Basis.IDENTITY, 0.6)
	for k in 8:                                                                  # a borda do chafariz (8 pedaços)
		var a := k * TAU / 8.0
		col.append([Vector3(cf.x + cos(a) * 4.1, 0.4, cf.y + sin(a) * 4.1), Vector3(0.6, 0.8, 3.5), 0.0, Basis(Vector3.UP, -a)])
	_col(Vector3(cf.x, 1.3, cf.y), Vector3(1.2, 2.6, 1.2))
	for s in [-1.0, 1.0]:
		fora.caixa(Vector3(s * 15.0, 0.3, 22.0), Vector3(1.4, 0.6, 1.4), PEDRA_ESC)
		fora.cilindro(Vector3(s * 15.0, 6.0, 22.0), 0.08, 11.4, 6, Color(0.82, 0.82, 0.8))
		_col(Vector3(s * 15.0, 1.0, 22.0), Vector3(1.4, 2.0, 1.4))
	_bandeira_ny(Vector3(-15.0 + 0.05, 10.6, 22.0), 2.4)
	fora.caixa(Vector3(15.0 + 1.2, 10.6, 22.0), Vector3(2.4, 1.5, 0.03), Color(0.92, 0.92, 0.92))                   # bandeira branca (rendição?)
	fora.caixa(Vector3(-30.0, 1.25, 27.0), Vector3(2.4, 2.5, 2.4), PEDRA_ESC)
	fora.cilindro(Vector3(-30.0, 3.6, 27.0), 0.45, 2.2, 8, Color(0.3, 0.36, 0.3), Basis.IDENTITY, 0.32)             # estátua de bronze
	fora.cilindro(Vector3(-30.0, 4.95, 27.0), 0.26, 0.45, 8, Color(0.3, 0.36, 0.3))
	fora.caixa(Vector3(-29.6, 4.3, 27.0), Vector3(0.9, 0.16, 0.16), Color(0.3, 0.36, 0.3), Basis(Vector3.BACK, 0.6))
	_col(Vector3(-30.0, 2.4, 27.0), Vector3(2.4, 4.8, 2.4))
	for p in [Vector2(-8, 21), Vector2(8, 21), Vector2(-22, 31), Vector2(22, 31)]:
		_bx(resto, Vector3(p.x, 0.25, p.y), Vector3(2.2, 0.5, 0.6), MADEIRA)
	for p in [Vector2(-20, 15.5), Vector2(20, 15.5), Vector2(-40, 36), Vector2(40, 36)]:
		_poste(p, 0.0, 6.0)
	# ---- POSTO DO EXÉRCITO da evacuação (perto da rua) ----
	_sacos(Vector2(-34.0, 35.0), Vector2(-7.0, 35.0), 3)
	_sacos(Vector2(7.0, 35.0), Vector2(34.0, 35.0), 3)
	_barreira(Vector2(-3.5, 36.6), 0.0)
	_barreira(Vector2(3.5, 33.6), 0.0)
	_barreira(Vector2(-3.5, 31.0), PI * 0.5)
	_tenda(Vector2(-40.0, 22.0), 0.0)
	_tenda(Vector2(40.0, 22.0), 0.0)
	_caminhao_mil(Vector2(-41.0, 9.0), 0.1)
	_jipe(Vector2(38.0, 31.0), PI * 0.5 + 0.3)
	_caixa_militar(Vector3(-34.0, 0, 30.0), 0.3, "militar")
	_caixa_militar(Vector3(33.0, 0, 28.0), -0.2, "militar_med")
	resto.caixa(Vector3(-12.0, 1.4, 36.2), Vector3(4.2, 1.4, 0.08), Color(0.92, 0.9, 0.85))
	_texto(Vector3(-12.0, 1.55, 36.26), 0.0, "CONTROLE DE EVACUAÇÃO", Color(0.7, 0.08, 0.06), 32)
	_texto(Vector3(-12.0, 1.05, 36.26), 0.0, "EXÉRCITO DOS EUA", Color(0.15, 0.2, 0.15), 24)
	_carro(Vector2(26.0, 18.0), 0.4, Color(0.15, 0.15, 0.17))
	_carro(Vector2(-24.0, 17.5), -1.1, Color(0.5, 0.1, 0.1), "carro", true)
	_pontos_em(Rect2(-36, 24, 72, 10), 0.0, 4, "praca")
	# infectados: funcionários e soldados que viraram (praça, posto do Exército, saguão, escritórios, 2º andar)
	for p in [Vector3(-6, 0, 30), Vector3(10, 0, 25), Vector3(-36, 0, 18), Vector3(36, 0, 18), Vector3(0, P, -6), Vector3(4, P, 2),
			Vector3(-24, P, -15), Vector3(-26, P, 0), Vector3(22, P, -14), Vector3(24, P, 2), Vector3(-22, y2, -14), Vector3(-24, y2, 0),
			Vector3(22, y2, -18), Vector3(0, y2, -18), Vector3(-18, yt, 0)]:
		infectados.append(p)

# bandeira de Nova York (faixas verticais azul, branca e laranja), presa pelo lado de "o" (mastro em x)
func _bandeira_ny(o: Vector3, larg: float) -> void:
	var alt := larg * 0.62
	var f := larg / 3.0
	var cores := [AZUL_NY, Color(0.95, 0.95, 0.93), LARANJA_NY]
	for k in 3:
		fora.caixa(o + Vector3(f * (k + 0.5), 0, 0), Vector3(f, alt, 0.03), cores[k])
