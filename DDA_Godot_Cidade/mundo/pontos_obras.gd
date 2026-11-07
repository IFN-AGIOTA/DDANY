extends "res://mundo/central_park_obras.gd"
# CONSTRUÇÕES DOS PONTOS TURÍSTICOS (1.21) · MANHATTAN. Quem chama: mundo/pontos_turisticos.gd (montar). Usa as peças
# do mundo/central_park_obras.gd (_b, _bc, _cil, _escada, _balaustrada, _figura...) e os materiais de
# pontos_turisticos.gd (fachadas com janelas pelo shader, telões, aço). Coordenadas LOCAIS: y = 0 no chão do terreno
# (calçada), +Z = a FRENTE (o giro da lista vira para a rua certa); W x D = o terreno nesse giro.
#   empire        · EMPIRE STATE BUILDING: base de 5 andares, os recuos art déco, o corpo com as nervuras, o deck
#                   do 86º, o mastro e a antena (443 m), luzes coloridas no alto à noite
#   chrysler      · CHRYSLER BUILDING: tijolo branco, as águias nos cantos, a coroa de aço em arcos e a agulha (319 m)
#   wtc           · ONE WORLD TRADE CENTER (os 8 triângulos que giram o quadrado, a agulha: 541 m) e o MEMORIAL 11/9
#                   (as 2 piscinas quadradas com a água caindo e o vazio no meio, as placas de bronze, carvalhos)
#   rockefeller   · ROCKEFELLER CENTER: o 30 Rock (259 m, deck "Top of the Rock"), a pista de patinação com o
#                   Prometeu dourado, as bandeiras, o Channel Gardens e o pinheiro gigante de Natal (apagado)
#   st_patrick    · CATEDRAL DE ST. PATRICK: neogótica de mármore branco, 2 torres com agulhas de 100 m, rosácea,
#                   arcobotantes e pináculos
#   grand_central · GRAND CENTRAL TERMINAL: fachada com os 3 janelões, colunas, o relógio e as estátuas; DÁ PARA
#                   ENTRAR no MAIN CONCOURSE (o salão com o teto de estrelas, o balcão de informações com o relógio
#                   de 4 faces, as escadarias dos dois lados e os guichês)
#   times_square  · TIMES SQUARE: as torres cobertas de TELÕES (imagens que trocam; uns queimados), a escadaria
#                   vermelha (dá para subir), o One Times Square com a bola de Ano-Novo, a faixa de notícias,
#                   táxis largados
#   flatiron      · FLATIRON BUILDING: o "ferro de passar" (triângulo com a ponta para o norte)
#   wall_street   · BOLSA DE NOVA YORK (colunas, frontão, a bandeira gigante rasgada) e o TOURO DE WALL STREET
#   vessel        · THE VESSEL (Hudson Yards): a colmeia de escadas cor de cobre
#   un            · SEDE DA ONU: o Secretariado de vidro verde, a Assembleia Geral com a cúpula e as bandeiras
#   guggenheim    · MUSEU GUGGENHEIM: a espiral branca, a claraboia e o anexo
# As de fora de Manhattan ficam em mundo/pontos_obras_fora.gd.

const PT := preload("res://mundo/pontos_turisticos.gd")
const CPCls := preload("res://mundo/central_park.gd")
const CALCARIO := Color(0.8, 0.76, 0.67)
const MARMORE := Color(0.88, 0.86, 0.82)
const BRANCO := Color(0.9, 0.9, 0.87)
const OURO := Color(0.85, 0.66, 0.25)
const AMARELO_TAXI := Color(0.95, 0.75, 0.1)
const VERDE_COBRE := Color(0.42, 0.62, 0.55)

var W := 100.0                                   # terreno no giro (local x)
var D := 100.0                                   # (local z)
var alcance := 1400.0                            # até onde aparece (0 = sempre; os arranha-céus)

func montar(tipo: String, pos: Vector3, giro: float, extra: Dictionary) -> void:
	T = Transform3D(Basis(Vector3.UP, giro), pos)
	cs = {}
	alcance = 1400.0
	W = float(extra.get("largura", 100.0))
	D = float(extra.get("fundo", 100.0))
	if absf(sin(giro)) > 0.7:
		var t := W
		W = D
		D = t
	_montar_tipo(tipo)
	_fim("PT_" + tipo)

func _montar_tipo(tipo: String) -> void:
	match tipo:
		"empire": _empire()
		"chrysler": _chrysler()
		"wtc": _wtc()
		"rockefeller": _rockefeller()
		"st_patrick": _st_patrick()
		"grand_central": _grand_central()
		"times_square": _times_square()
		"flatiron": _flatiron()
		"wall_street": _wall_street()
		"vessel": _vessel()
		"un": _un()
		"guggenheim": _guggenheim()

func _fim(nome: String) -> void:
	var am: ArrayMesh = null
	for m in cs:
		var c: Malhas.Construtor = cs[m]
		if c.vazio():
			continue
		am = c.malha(PT.mat(m), am)
	if am != null:
		parque.por_malha(nome, am, T, alcance)

# ---------------------------------------------------------------------------------------------------------------
# PEÇAS A MAIS
# ---------------------------------------------------------------------------------------------------------------
# bloco de arranha-céu (com colisão): centro da base em (x, y0, z)
func _bloco(m: String, x: float, z: float, y0: float, w: float, d: float, h: float, cor: Color, colisao := true) -> void:
	_b(m, Vector3(x, y0 + h * 0.5, z), Vector3(w, h, d), cor)
	if colisao:
		_col(Vector3(x, y0 + h * 0.5, z), Vector3(w, h, d))

# prisma (planta em pts, de y0 a y1) com tampa; colisão convexa
func _prisma(m: String, pts: PackedVector2Array, y0: float, y1: float, cor: Color, colisao := true) -> void:
	var c := _c(m)
	var n := pts.size()
	var horario := Geometry2D.is_polygon_clockwise(pts)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var l := a.distance_to(b)
		var q0 := Vector3(a.x, y0, a.y)
		var q1 := Vector3(b.x, y0, b.y)
		var q2 := Vector3(b.x, y1, b.y)
		var q3 := Vector3(a.x, y1, a.y)
		var nn := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		# (o _quad quer os 4 cantos no sentido anti-horário visto de fora: começa embaixo à esquerda)
		if horario:
			nn = -nn
			c._quad(q0, q1, q2, q3, nn, cor, Vector2(0, y1 - y0), Vector2(l, y1 - y0), Vector2(l, 0), Vector2(0, 0))
		else:
			c._quad(q1, q0, q3, q2, nn, cor, Vector2(l, y1 - y0), Vector2(0, y1 - y0), Vector2(0, 0), Vector2(l, 0))
	var idx := Geometry2D.triangulate_polygon(pts)
	for k in range(0, idx.size(), 3):
		var tri := [pts[idx[k]], pts[idx[k + 1]], pts[idx[k + 2]]]
		var cr: float = (tri[1].x - tri[0].x) * (tri[2].y - tri[0].y) - (tri[1].y - tri[0].y) * (tri[2].x - tri[0].x)
		var ordem := [0, 1, 2] if cr >= 0.0 else [0, 2, 1]
		for o in ordem:
			c.v.append(Vector3(tri[o].x, y1, tri[o].y))
			c.n.append(Vector3.UP)
			c.c.append(cor)
			c.uv.append(Vector2(tri[o].x, tri[o].y))
	if colisao:
		var vs := PackedVector3Array()
		for p in pts:
			vs.append(T * Vector3(p.x, y0, p.y))
			vs.append(T * Vector3(p.x, y1, p.y))
		parque.col_convexo(vs)

# tubo (cilindro) de a até b
func _tubo(m: String, a: Vector3, b: Vector3, r: float, cor: Color, lados := 6) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_cil(m, (a + b) * 0.5, r, l, lados, cor, Basis(x, y, z))

# anel de caixas (círculo) no plano horizontal
func _anel(m: String, c: Vector3, r: float, n: int, larg: float, alt: float, cor: Color) -> void:
	for k in n:
		var a0 := k * TAU / n
		var a1 := (k + 1) * TAU / n
		var am := (a0 + a1) * 0.5
		var corda := 2.0 * r * sin(PI / n) + 0.02
		_b(m, c + Vector3(cos(am) * r, 0, sin(am) * r), Vector3(corda, alt, larg), cor, Basis(Vector3.UP, -am + PI * 0.5))

# letreiro (Label3D) na posição local, virado para "giro" local (0 = olhando para +Z)
func _letreiro(txt: String, p: Vector3, giro: float, tam: int, px: float, cor: Color, deitado := false) -> void:
	var lb := Label3D.new()
	lb.text = txt
	lb.font_size = tam
	lb.pixel_size = px
	lb.modulate = cor
	lb.outline_size = 0
	lb.position = T * p
	if deitado:
		lb.rotation = Vector3(-PI * 0.5, T.basis.get_euler().y + giro, 0)
	else:
		lb.rotation = Vector3(0, T.basis.get_euler().y + giro, 0)
	lb.visibility_range_end = 600.0
	parque.visuais.append(lb)

func _arvore(modelo: String, p: Vector3, s := 1.0) -> void:
	parque.arvores.append([modelo, T * p, r.randf() * TAU, s])

# poste do Central Park e banco (MultiMesh do parque: aqui só a lista; o pontos_turisticos.gd monta)
func _poste(p: Vector3) -> void:
	parque.postes.append(T * p)

func _banco(p: Vector3, giro: float) -> void:
	parque.bancos.append([T * p, T.basis.get_euler().y + giro])

# piso (laje fina) do terreno
func _piso(m: String, x0: float, z0: float, x1: float, z1: float, cor: Color, y := 0.03) -> void:
	_b(m, Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.06, z1 - z0), cor)

# nervuras verticais numa face (art déco): ao longo de x, na face z = zf, de y0 a y1
func _nervuras_x(m: String, x0: float, x1: float, zf: float, y0: float, y1: float, passo: float, cor: Color, prof := 0.5) -> void:
	var n := int((x1 - x0) / passo)
	for k in range(1, n):
		var x := x0 + k * (x1 - x0) / n
		_b(m, Vector3(x, (y0 + y1) * 0.5, zf), Vector3(0.45, y1 - y0, prof), cor)

func _nervuras_z(m: String, z0: float, z1: float, xf: float, y0: float, y1: float, passo: float, cor: Color, prof := 0.5) -> void:
	var n := int((z1 - z0) / passo)
	for k in range(1, n):
		var z := z0 + k * (z1 - z0) / n
		_b(m, Vector3(xf, (y0 + y1) * 0.5, z), Vector3(prof, y1 - y0, 0.45), cor)

# ---------------------------------------------------------------------------------------------------------------
# EMPIRE STATE BUILDING (frente +Z = 5ª Avenida)
# ---------------------------------------------------------------------------------------------------------------
func _empire() -> void:
	alcance = 0.0
	var c := CALCARIO
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.55, 0.53, 0.5))
	# base de 5 andares (enche o terreno) e os recuos
	_bloco("fachada_pedra", 0, 0, 0, 60, 128, 24, c)
	_b("pedra", Vector3(0, 24.4, 0), Vector3(61, 0.8, 129), c * 1.05)
	var niveis := [[24.0, 54.0, 112.0, 58.0], [82.0, 50.0, 100.0, 20.0], [102.0, 46.0, 88.0, 20.0], [122.0, 40.0, 64.0, 156.0],
		[278.0, 33.0, 46.0, 34.0], [312.0, 27.0, 36.0, 14.0]]
	for nv in niveis:
		var y0: float = nv[0]
		var w: float = nv[1]
		var d: float = nv[2]
		var h: float = nv[3]
		_bloco("fachada_pedra", 0, 0, y0, w, d, h, c)
		_b("pedra", Vector3(0, y0 + h + 0.3, 0), Vector3(w + 0.6, 0.6, d + 0.6), c * 1.04)
		# nervuras verticais de metal (as faixas que sobem o prédio inteiro)
		_nervuras_x("aco", -w * 0.5, w * 0.5, d * 0.5 + 0.2, y0, y0 + h, 3.2, Color(0.55, 0.55, 0.57), 0.35)
		_nervuras_x("aco", -w * 0.5, w * 0.5, -d * 0.5 - 0.2, y0, y0 + h, 3.2, Color(0.55, 0.55, 0.57), 0.35)
		_nervuras_z("aco", -d * 0.5, d * 0.5, w * 0.5 + 0.2, y0, y0 + h, 3.2, Color(0.55, 0.55, 0.57), 0.35)
		_nervuras_z("aco", -d * 0.5, d * 0.5, -w * 0.5 - 0.2, y0, y0 + h, 3.2, Color(0.55, 0.55, 0.57), 0.35)
	# 86º andar: o deck de observação com o parapeito
	var yd := 326.0
	_bloco("fachada_pedra", 0, 0, yd, 22, 28, 8, c)
	_anel("pedra", Vector3(0, yd + 1.0, 0), 17.0, 20, 0.5, 2.0, c * 0.95)
	# o mastro (antes do dirigível) e a antena
	var ym := yd + 8.0
	_cil("pedra", Vector3(0, ym + 9.0, 0), 7.0, 18.0, 8, c, Basis.IDENTITY, 5.2)
	for k in 8:
		var a := k * TAU / 8.0
		_b("aco", Vector3(cos(a) * 6.3, ym + 9.0, sin(a) * 6.3), Vector3(0.5, 18.0, 0.5), Color(0.75, 0.75, 0.78), Basis(Vector3.UP, -a))
	_cil("vidro", Vector3(0, ym + 21.0, 0), 5.0, 6.0, 8, Color(0.95, 0.45, 0.85))            # luzes do alto (coloridas à noite)
	_cil("aco", Vector3(0, ym + 27.0, 0), 4.6, 6.0, 8, Color(0.75, 0.75, 0.78), Basis.IDENTITY, 2.0)
	_cil("aco", Vector3(0, ym + 33.0, 0), 1.6, 8.0, 8, Color(0.7, 0.7, 0.72), Basis.IDENTITY, 0.9)
	_cil("ferro", Vector3(0, ym + 37.0 + 31.0, 0), 0.7, 62.0, 6, Color(0.6, 0.6, 0.62), Basis.IDENTITY, 0.12)
	_col(Vector3(0, ym + 20.0, 0), Vector3(12, 40, 12))
	# entrada da 5ª Avenida: marquise e o letreiro
	_b("aco", Vector3(0, 7.5, D * 0.5 - 4.0), Vector3(14, 0.6, 3.0), Color(0.3, 0.3, 0.32))
	_b("vidro_escuro", Vector3(0, 4.0, 64.05), Vector3(10, 7.0, 0.1), Color(0.1, 0.1, 0.12))
	_letreiro("EMPIRE STATE", Vector3(0, 9.6, 64.2), 0.0, 96, 0.02, Color(0.9, 0.8, 0.5))
	parque.pontos_altos["empire_deck"] = T * Vector3(0, yd + 8.0, 0)

# ---------------------------------------------------------------------------------------------------------------
# CHRYSLER BUILDING
# ---------------------------------------------------------------------------------------------------------------
func _chrysler() -> void:
	alcance = 0.0
	var c := BRANCO
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.5, 0.49, 0.47))
	_bloco("fachada_branca", 0, 0, 0, 56, 56, 20, c)
	_bloco("fachada_branca", 0, 0, 20, 48, 48, 40, c)
	_bloco("fachada_branca", 0, 0, 60, 40, 40, 30, c)
	_bloco("fachada_branca", 0, 0, 90, 32, 32, 110, c)
	# faixas escuras nos cantos (tijolo cinza) e as águias de aço do 61º andar
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_b("concreto", Vector3(sx * 15.6, 145.0, sz * 15.6), Vector3(1.4, 110.0, 1.4), Color(0.35, 0.36, 0.38))
			var p := Vector3(sx * 17.5, 201.0, sz * 17.5)
			_b("aco", p, Vector3(1.2, 1.2, 4.0), Color(0.82, 0.82, 0.85), Basis(Vector3.UP, atan2(sx, sz)) * Basis(Vector3.RIGHT, 0.25))
	# a COROA: 7 degraus de aço em arcos (sol nascente) com janelas triangulares
	var y := 200.0
	for k in 7:
		var s := 30.0 - k * 3.4
		var h := 8.0
		_b("aco", Vector3(0, y + h * 0.5, 0), Vector3(s, h, s), Color(0.8, 0.8, 0.83))
		for lado in 4:
			var a := lado * PI * 0.5
			var nrm := Vector3(sin(a), 0, cos(a))
			var tg := Vector3(cos(a), 0, -sin(a))
			# o arco (meia-lua) por cima do degrau
			for f in 9:
				var ang := PI * (f + 0.5) / 9.0
				var p := nrm * (s * 0.5 + 0.05) + tg * cos(ang) * s * 0.42 + Vector3(0, y + h + sin(ang) * s * 0.28, 0)
				_b("aco", p, Vector3(1.6, 0.9, 0.3), Color(0.85, 0.85, 0.88), Basis(Vector3.UP, a) * Basis(Vector3.BACK, ang - PI * 0.5))
			# janelas triangulares (escuras; acesas à noite)
			for f in 3:
				var off := (f - 1) * s * 0.28
				_b("vidro", nrm * (s * 0.5 + 0.08) + tg * off + Vector3(0, y + h * 0.55, 0), Vector3(1.4, 2.6, 0.1), Color(0.9, 0.85, 0.6), Basis(Vector3.UP, a) * Basis(Vector3.BACK, PI * 0.25))
		y += h
	_cil("aco", Vector3(0, y + 30.0, 0), 2.2, 60.0, 8, Color(0.85, 0.85, 0.88), Basis.IDENTITY, 0.05)    # a agulha
	_col(Vector3(0, 230.0, 0), Vector3(24, 60, 24))
	_letreiro("CHRYSLER", Vector3(0, 7.0, 28.2), 0.0, 80, 0.02, Color(0.9, 0.9, 0.85))

# ---------------------------------------------------------------------------------------------------------------
# ONE WORLD TRADE CENTER e o MEMORIAL 11/9 (frente +Z)
# ---------------------------------------------------------------------------------------------------------------
func _wtc() -> void:
	alcance = 0.0
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.6, 0.59, 0.56))
	# a torre: pódio (aletas de vidro) e o corpo de 8 triângulos (o quadrado de baixo vira um quadrado girado em cima)
	var tc := Vector3(-W * 0.5 + 40.0, 0, -8.0)
	_bloco("fachada_vidro", tc.x, tc.z, 0, 61, 61, 56, Color(0.7, 0.72, 0.74))
	for k in 30:
		var x := -29.0 + k * 2.0
		for lado: float in [-1.0, 1.0]:
			_b("aco", tc + Vector3(x, 28.0, lado * 30.7), Vector3(0.3, 50.0, 0.8), Color(0.82, 0.84, 0.86))
			_b("aco", tc + Vector3(lado * 30.7, 28.0, x), Vector3(0.8, 50.0, 0.3), Color(0.82, 0.84, 0.86))
	var y0 := 56.0
	var y1 := 417.0
	var r0 := 61.0 / sqrt(2.0)
	var r1 := r0 * 0.72
	var cv := _c("fachada_vidro")
	var cor := Color(0.82, 0.86, 0.9)
	for i in 4:
		var b0 := tc + Vector3(cos(PI * 0.25 + i * PI * 0.5) * r0, y0, sin(PI * 0.25 + i * PI * 0.5) * r0)
		var b1 := tc + Vector3(cos(PI * 0.25 + (i + 1) * PI * 0.5) * r0, y0, sin(PI * 0.25 + (i + 1) * PI * 0.5) * r0)
		var t0 := tc + Vector3(cos(i * PI * 0.5) * r1, y1, sin(i * PI * 0.5) * r1)
		var t1 := tc + Vector3(cos((i + 1) * PI * 0.5) * r1, y1, sin((i + 1) * PI * 0.5) * r1)
		_tri_fachada(cv, b0, b1, t1, cor)          # triângulo de pé (base embaixo)
		_tri_fachada(cv, t0, t1, b0, cor)          # triângulo de ponta-cabeça
	_cil("aco", tc + Vector3(0, y1 + 1.5, 0), r1, 3.0, 4, Color(0.75, 0.77, 0.8))
	_cil("aco", tc + Vector3(0, y1 + 3.0 + 60.0, 0), 2.4, 120.0, 8, Color(0.85, 0.85, 0.88), Basis.IDENTITY, 0.35)   # agulha
	for k in 6:
		_cil("aco", tc + Vector3(0, y1 + 10.0 + k * 9.0, 0), 3.4 - k * 0.3, 0.6, 12, Color(0.8, 0.8, 0.82))
	_col(tc + Vector3(0, (y0 + y1) * 0.5, 0), Vector3(48, y1 - y0, 48))
	_letreiro("ONE WORLD TRADE CENTER", tc + Vector3(0, 9.0, 31.2), 0.0, 64, 0.02, Color(0.9, 0.9, 0.9))
	# o MEMORIAL: 2 piscinas (onde ficavam as Torres Gêmeas), com os nomes no bronze e a água caindo no vazio
	for e in [[Vector2(28.0, -30.0), 0], [Vector2(66.0, 34.0), 1]]:
		var c2: Vector2 = e[0]
		_piscina_memorial(Vector3(c2.x, 0, c2.y))
	# carvalhos em fileiras na praça
	for k in 14:
		var x := -W * 0.5 + 78.0 + (k % 7) * 16.0
		var z := -D * 0.5 + 10.0 + (k / 7) * (D - 20.0)
		_arvore("carvalho_m", Vector3(x, 0, z), 0.8)
	for k in 6:
		_poste(Vector3(-W * 0.5 + 75.0 + k * 22.0, 0, 0.0))
	parque.pontos_altos["wtc"] = T * (tc + Vector3(0, 0, 32.0))

func _tri_fachada(c: Malhas.Construtor, a: Vector3, b: Vector3, cc: Vector3, cor: Color) -> void:
	var nn := (b - a).cross(cc - a).normalized()
	var hd := Vector3(nn.z, 0, -nn.x).normalized()
	var ua := Vector2(a.dot(hd), 0)
	var ub := Vector2(b.dot(hd), 0)
	var uc := Vector2(cc.dot(hd), 0)
	for p in [[a, ua], [b, ub], [cc, uc]]:
		c.v.append(p[0])
		c.n.append(nn)
		c.c.append(cor)
		c.uv.append(p[1])
	# o outro lado (a face fica visível de fora qualquer que seja a ordem)
	for p in [[a, ua], [cc, uc], [b, ub]]:
		c.v.append(p[0])
		c.n.append(-nn)
		c.c.append(cor)
		c.uv.append(p[1])

func _piscina_memorial(c: Vector3) -> void:
	var s := 46.0
	var h := s * 0.5
	# o parapeito de bronze com os nomes (inclinado) em cima da mureta de granito (com colisão: ninguém cai)
	for k in 4:
		var a := k * PI * 0.5
		var nrm := Vector3(sin(a), 0, cos(a))
		_b("bronze", c + nrm * (h + 1.0) + Vector3(0, 0.95, 0), Vector3(s + 4.0, 0.12, 1.4) if k % 2 == 0 else Vector3(1.4, 0.12, s + 4.0), Color(0.22, 0.2, 0.16))
		_bc("granito", c + nrm * (h + 1.0) + Vector3(0, 0.45, 0), Vector3(s + 4.0, 0.9, 1.2) if k % 2 == 0 else Vector3(1.2, 0.9, s + 4.0), Color(0.18, 0.18, 0.19))
	# a PISCINA: o buraco (as paredes com a água caindo, o espelho d'água e o vazio do meio) é desenhado pelo shader
	# num quadrado no chão (mundo/pontos_turisticos.gd SHADER_PISCINA: o chão da cidade fica inteiro)
	var cq := _c("piscina_memorial")
	cq.ao = 0.0
	var y := 0.09
	cq._quad(c + Vector3(-h, y, h), c + Vector3(h, y, h), c + Vector3(h, y, -h), c + Vector3(-h, y, -h), Vector3.UP, Color(1, 1, 1),
		Vector2(-h, h), Vector2(h, h), Vector2(h, -h), Vector2(-h, -h))

# ---------------------------------------------------------------------------------------------------------------
# ROCKEFELLER CENTER (frente +Z = 5ª Avenida)
# ---------------------------------------------------------------------------------------------------------------
func _rockefeller() -> void:
	alcance = 0.0
	var c := CALCARIO
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.55, 0.54, 0.51))
	# o 30 ROCK no fundo: lâmina com recuos dos lados
	var zt := -D * 0.5 + 22.0
	_bloco("fachada_pedra", 0, zt, 0, 76, 34, 40, c)
	_bloco("fachada_pedra", 0, zt, 40, 64, 30, 60, c)
	_bloco("fachada_pedra", 0, zt, 100, 52, 26, 80, c)
	_bloco("fachada_pedra", 0, zt, 180, 40, 24, 60, c)
	_bloco("fachada_pedra", 0, zt, 240, 30, 22, 19, c)
	for nv in [[0.0, 40.0, 76.0, 34.0], [40.0, 100.0, 64.0, 30.0], [100.0, 180.0, 52.0, 26.0], [180.0, 240.0, 40.0, 24.0]]:
		_nervuras_x("pedra", -float(nv[2]) * 0.5, float(nv[2]) * 0.5, zt + float(nv[3]) * 0.5 + 0.2, float(nv[0]), float(nv[1]), 2.4, c * 1.05, 0.4)
	# Top of the Rock: os decks com o vidro
	for k in 3:
		_b("vidro_escuro", Vector3(0, 240.0 + k * 6.5 + 1.0, zt), Vector3(31.0 - k * 4.0, 2.0, 23.0 - k * 3.0), Color(0.3, 0.4, 0.45))
	_letreiro("30 ROCKEFELLER PLAZA", Vector3(0, 12.0, zt + 17.2), 0.0, 72, 0.02, Color(0.85, 0.75, 0.45))
	# a pista de patinação, o PROMETEU dourado no fundo dela e a fonte
	var zp := zt + 36.0
	_b("concreto", Vector3(0, 0.12, zp), Vector3(36, 0.2, 22), Color(0.9, 0.92, 0.95))
	_balaustrada("pedra", Vector3(-19.0, 0.0, zp + 11.5), Vector3(19.0, 0.0, zp + 11.5), c)
	_balaustrada("pedra", Vector3(-19.0, 0.0, zp - 11.5), Vector3(-19.0, 0.0, zp + 11.5), c)
	_balaustrada("pedra", Vector3(19.0, 0.0, zp - 11.5), Vector3(19.0, 0.0, zp + 11.5), c)
	_bc("granito", Vector3(0, 2.0, zp - 13.0), Vector3(14, 4.0, 3.0), Color(0.35, 0.33, 0.3))
	_figura("ouro", Vector3(0, 4.0, zp - 13.0), 5.5, OURO, 0.0, false)                        # Prometeu
	_anel("ouro", Vector3(0, 6.5, zp - 13.6), 3.4, 18, 0.3, 0.4, OURO)                          # o anel do zodíaco
	# as bandeiras em volta da pista
	for k in 24:
		var t := float(k) / 23.0
		var p := Vector3(-21.0 + t * 42.0, 0, zp + 13.5) if k < 12 else Vector3((-21.0 if k < 18 else 21.0), 0, zp + 12.0 - (k % 6) * 4.5)
		_cil("ferro", p + Vector3(0, 5.0, 0), 0.06, 10.0, 5, Color(0.6, 0.6, 0.62))
		_b("madeira", p + Vector3(0.9, 9.0, 0), Vector3(1.8, 1.1, 0.03), Color.from_hsv(fmod(k * 0.13, 1.0), 0.7, 0.75))
	# Channel Gardens: os canteiros até a 5ª Avenida e os 2 prédios baixos dos lados
	for s: float in [-1.0, 1.0]:
		_bloco("fachada_pedra", s * 30.0, D * 0.5 - 18.0, 0, 22, 30, 26, c)
	for k in 4:
		_b("pedra", Vector3(0, 0.45, D * 0.5 - 6.0 - k * 7.0), Vector3(4.0, 0.9, 5.5), c * 0.9)
		_b("madeira", Vector3(0, 1.0, D * 0.5 - 6.0 - k * 7.0), Vector3(3.6, 0.3, 5.0), Color(0.2, 0.35, 0.15))
	# o PINHEIRO gigante de Natal (ninguém acendeu este ano)
	_arvore("pinheiro_g", Vector3(0, 0, zp + 16.5), 1.45)
	parque.pontos_altos["rockefeller"] = T * Vector3(0, 0, zp + 14.0)

# ---------------------------------------------------------------------------------------------------------------
# CATEDRAL DE ST. PATRICK (frente +Z = 5ª Avenida; a nave vai para -Z)
# ---------------------------------------------------------------------------------------------------------------
func _st_patrick() -> void:
	var c := MARMORE
	var zf := D * 0.5 - 8.0                           # fachada
	var zb := -D * 0.5 + 6.0                          # fundo (abside)
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.55, 0.54, 0.51))
	var nave_l := zf - zb
	# nave alta, naves laterais e o transepto
	_bloco("pedra", 0, (zf + zb) * 0.5, 0, 16, nave_l, 33, c)
	for s: float in [-1.0, 1.0]:
		_bloco("pedra", s * 13.5, (zf + zb) * 0.5 - 4.0, 0, 11, nave_l - 8.0, 20, c * 0.97)
	_bloco("pedra", 0, zb + 30.0, 0, W - 4.0, 16, 33, c)
	# telhados (2 águas, verde-escuro)
	var tel := Color(0.25, 0.32, 0.3)
	_b("telhado", Vector3(-4.6, 36.5, (zf + zb) * 0.5), Vector3(10.5, 0.4, nave_l), tel, Basis(Vector3.BACK, 0.62))
	_b("telhado", Vector3(4.6, 36.5, (zf + zb) * 0.5), Vector3(10.5, 0.4, nave_l), tel, Basis(Vector3.BACK, -0.62))
	_b("telhado", Vector3(0, 36.5, zb + 30.0 - 4.6), Vector3(W - 4.0, 0.4, 10.5), tel, Basis(Vector3.RIGHT, -0.62))
	_b("telhado", Vector3(0, 36.5, zb + 30.0 + 4.6), Vector3(W - 4.0, 0.4, 10.5), tel, Basis(Vector3.RIGHT, 0.62))
	# arcobotantes e pináculos dos lados, e os janelões góticos
	var n := 8
	for k in n:
		var z := zf - 12.0 - k * (nave_l - 20.0) / (n - 1)
		for s: float in [-1.0, 1.0]:
			_b("pedra", Vector3(s * 19.6, 12.0, z), Vector3(1.6, 24.0, 2.0), c * 0.95)
			_cil("pedra", Vector3(s * 19.6, 26.0, z), 0.9, 4.0, 4, c, Basis(Vector3.UP, PI * 0.25), 0.05)
			_b("pedra", Vector3(s * 14.0, 26.0, z), Vector3(11.0, 1.0, 1.2), c * 0.95, Basis(Vector3.BACK, s * 0.55))
			_b("vidro", Vector3(s * 19.05, 10.0, z - (nave_l - 20.0) / (n - 1) * 0.5), Vector3(0.1, 11.0, 2.6), Color(0.5, 0.35, 0.7))
			_b("vidro", Vector3(s * 8.05, 26.0, z - (nave_l - 20.0) / (n - 1) * 0.5), Vector3(0.1, 8.0, 2.2), Color(0.35, 0.45, 0.8))
	# a FACHADA: 2 torres com as agulhas de 100 m, rosácea, portais em arco ogival
	for s: float in [-1.0, 1.0]:
		_bloco("pedra", s * 13.0, zf - 4.0, 0, 13, 13, 56, c)
		_cil("pedra", Vector3(s * 13.0, 56.0 + 22.0, zf - 4.0), 6.0, 44.0, 8, c * 1.02, Basis(Vector3.UP, PI / 8.0), 0.4)
		_cil("pedra", Vector3(s * 13.0, 100.5, zf - 4.0), 0.4, 1.4, 6, c)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				_cil("pedra", Vector3(s * 13.0 + sx * 6.0, 60.0, zf - 4.0 + sz * 6.0), 0.8, 8.0, 4, c, Basis(Vector3.UP, PI * 0.25), 0.05)
		for jy: float in [20.0, 34.0, 46.0]:
			_b("vidro_escuro", Vector3(s * 13.0, jy, zf + 2.56), Vector3(2.6, 8.0, 0.1), Color(0.08, 0.08, 0.1))
	_b("pedra", Vector3(0, 30.0, zf + 1.5), Vector3(14.0, 8.0, 1.0), c, Basis(Vector3.BACK, 0.0))
	_cil("vidro", Vector3(0, 24.0, zf + 2.2), 4.2, 0.2, 20, Color(0.6, 0.3, 0.55), Basis(Vector3.RIGHT, PI * 0.5))   # rosácea
	_cil("pedra", Vector3(0, 24.0, zf + 2.15), 4.7, 0.25, 20, c, Basis(Vector3.RIGHT, PI * 0.5))
	for k in 3:
		var x := (k - 1) * 6.5
		var larg := 4.4 if k == 1 else 3.2
		_b("madeira", Vector3(x, 3.5, zf + 2.55), Vector3(larg, 7.0, 0.12), Color(0.35, 0.25, 0.18))
		for f in 7:
			var a := PI * (f + 0.5) / 7.0
			_b("pedra", Vector3(x + cos(a) * larg * 0.6, 7.0 + sin(a) * larg * 0.9, zf + 2.6), Vector3(0.6, 0.6, 0.4), c * 1.05)
	_cil("pedra", Vector3(0, 46.0, zb + 30.0), 3.0, 12.0, 8, c, Basis.IDENTITY, 0.2)            # agulha do cruzeiro
	_escada("pedra", Vector3(0, 0, zf + 7.5), Vector2(0, -1), 24.0, 0.45, 4.0, c * 0.95)

# ---------------------------------------------------------------------------------------------------------------
# GRAND CENTRAL TERMINAL (frente +Z = rua 42) · o MAIN CONCOURSE é de entrar
# ---------------------------------------------------------------------------------------------------------------
func _grand_central() -> void:
	alcance = 2500.0
	var c := Color(0.82, 0.78, 0.69)
	var hw := 66.0                                   # meia largura do prédio
	var zf := 30.0                                   # fachada (rua 42): é a parede da frente do salão
	var zb := -38.0                                  # fundo
	var hh := 38.0                                   # altura do salão
	var sx := 44.0                                   # meia largura do salão (por dentro)
	var sz := 19.4                                   # meia profundidade do salão
	var zc := zf - sz - 0.6                          # centro do salão
	var zt := zc - sz - 0.6                          # parede do fundo do salão
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.5, 0.49, 0.47))
	# os dois blocos dos lados (maciços, com janelas) e o bloco do fundo (as plataformas, fechadas)
	for s: float in [-1.0, 1.0]:
		_bloco("fachada_pedra", s * (hw + sx + 1.2) * 0.5, (zf + zb) * 0.5, 0, hw - sx - 1.2, zf - zb, hh - 6.0, c)
	_bloco("fachada_pedra", 0, (zb + zt - 0.6) * 0.5, 0, (sx + 1.2) * 2.0, zt - 0.6 - zb, hh, c)
	# o SALÃO (Main Concourse): chão de mármore, paredes de dentro, teto verde com as estrelas
	_b("pedra_chao", Vector3(0, 0.04, zc), Vector3(sx * 2.0, 0.08, sz * 2.0), Color(0.75, 0.68, 0.55))
	for s: float in [-1.0, 1.0]:
		_bc("pedra", Vector3(s * (sx + 0.6), hh * 0.5, zc), Vector3(1.2, hh, sz * 2.0 + 2.4), c * 0.95)
	var arcos := [[-22.0, 10.0, 12.0], [0.0, 10.0, 12.0], [22.0, 10.0, 12.0]]
	_parede_arcos("pedra", -sx, sx, zf, 1.2, hh, arcos, c * 0.95)                 # frente: as 3 entradas
	_parede_arcos("pedra", -sx, sx, zt, 1.2, hh, arcos, c * 0.95)                 # fundo (janelões fechados)
	_b("ceu_gc", Vector3(0, hh - 0.6, zc), Vector3(sx * 2.0, 0.2, sz * 2.0), Color(1, 1, 1))
	_b("pedra", Vector3(0, hh, zc), Vector3(sx * 2.0 + 2.4, 1.2, sz * 2.0 + 2.4), c)
	_col(Vector3(0, hh, zc), Vector3(sx * 2.0, 1.2, sz * 2.0))
	# os janelões: vidro com a grade de ferro no arco de cima (as portas ficam embaixo, abertas na frente)
	for x: float in [-22.0, 0.0, 22.0]:
		for zz: float in [zf, zt]:
			var y0 := 6.0 if zz == zf else 0.0
			_b("vidro_escuro", Vector3(x, (y0 + 17.0) * 0.5, zz), Vector3(9.8, 17.0 - y0, 0.08), Color(0.35, 0.4, 0.42))
			for k in 6:
				_b("ferro", Vector3(x - 4.0 + k * 1.6, (y0 + 17.0) * 0.5, zz), Vector3(0.12, 17.0 - y0, 0.2), FERRO)
			_b("ferro", Vector3(x, y0 + 0.1, zz), Vector3(10.0, 0.3, 0.3), FERRO)
			if zz == zt:
				_col(Vector3(x, 8.5, zz), Vector3(10.0, 17.0, 1.2))
			else:
				_b("madeira", Vector3(x, 5.6, zz + 0.3), Vector3(9.6, 0.6, 0.3), Color(0.25, 0.22, 0.18))    # verga das portas
	# a fachada: colunas aos pares entre os janelões, cornija, ático, o relógio e as estátuas
	for xc: float in [-33.0, -11.0, 11.0, 33.0]:
		for d2: float in [-1.8, 1.8]:
			_cil("pedra", Vector3(xc + d2, 14.0, zf + 1.8), 1.1, 22.0, 12, c * 1.04)
			_b("pedra", Vector3(xc + d2, 25.4, zf + 1.8), Vector3(2.6, 1.0, 2.6), c * 1.06)
			_b("pedra", Vector3(xc + d2, 3.0, zf + 1.8), Vector3(2.6, 0.6, 2.6), c * 0.95)
		_col(Vector3(xc, 14.0, zf + 1.8), Vector3(6.0, 22.0, 2.4))
	_b("pedra", Vector3(0, 27.5, zf + 1.6), Vector3(sx * 2.0 + 2.0, 3.0, 3.0), c)              # cornija
	_b("pedra", Vector3(0, 33.0, zf + 1.0), Vector3(40.0, 8.0, 2.0), c * 0.98)                 # ático
	_cil("vidro", Vector3(0, 33.0, zf + 2.2), 2.2, 0.3, 24, Color(0.95, 0.85, 0.5), Basis(Vector3.RIGHT, PI * 0.5))
	_cil("bronze", Vector3(0, 33.0, zf + 2.1), 2.6, 0.3, 24, Color(0.35, 0.45, 0.38), Basis(Vector3.RIGHT, PI * 0.5))
	for s: float in [-1.0, 0.0, 1.0]:
		_figura("bronze", Vector3(s * 7.0, 37.0, zf + 1.0), 6.5 if s == 0.0 else 5.5, Color(0.36, 0.45, 0.38), 0.0, true)
	_letreiro("GRAND CENTRAL TERMINAL", Vector3(0, 27.4, zf + 3.15), 0.0, 72, 0.03, c * 0.7)
	# dentro: o balcão de informações com o relógio de 4 faces, as escadarias de mármore e os guichês
	_cil("madeira", Vector3(0, 1.3, zc), 3.4, 2.6, 8, Color(0.55, 0.42, 0.3))
	_cil("bronze", Vector3(0, 2.8, zc), 2.0, 0.4, 8, OURO)
	_cil("bronze", Vector3(0, 3.6, zc), 0.25, 1.4, 6, OURO)
	_cil("vidro", Vector3(0, 4.6, zc), 0.8, 0.9, 12, Color(1.0, 0.9, 0.6))
	_col(Vector3(0, 1.3, zc), Vector3(6.0, 2.6, 6.0))
	for s: float in [-1.0, 1.0]:
		_escada("pedra", Vector3(s * (sx - 12.0), 0.0, zc), Vector2(s, 0), 10.0, 6.0, 9.0, Color(0.78, 0.7, 0.58))
		_bc("pedra", Vector3(s * (sx - 1.5), 5.85, zc), Vector3(3.0, 0.3, sz * 2.0), c)      # balcão (mezanino)
		_balaustrada("pedra", Vector3(s * (sx - 3.0), 6.0, zc - sz), Vector3(s * (sx - 3.0), 6.0, zc - 5.0), c, 1.0)
		_balaustrada("pedra", Vector3(s * (sx - 3.0), 6.0, zc + 5.0), Vector3(s * (sx - 3.0), 6.0, zc + sz), c, 1.0)
	for k in 10:
		_b("madeira", Vector3(-20.0 + k * 4.4, 1.6, zt + 0.9), Vector3(3.6, 3.2, 0.4), Color(0.5, 0.38, 0.25))
		_b("vidro_escuro", Vector3(-20.0 + k * 4.4, 2.2, zt + 1.15), Vector3(2.4, 1.2, 0.05), Color(0.15, 0.15, 0.15))
	_col(Vector3(0, 1.6, zt + 0.9), Vector3(44.0, 3.2, 0.4))
	_letreiro("TRENS · TRACKS 11-42", Vector3(0, 4.4, zt + 0.7), 0.0, 48, 0.02, Color(0.9, 0.8, 0.5))
	for x3: float in [-24.0, 0.0, 24.0]:
		_cil("ouro", Vector3(x3, hh - 6.0, zc), 1.4, 2.0, 10, OURO)                       # lustres
		_cil("ferro", Vector3(x3, hh - 3.0, zc), 0.05, 4.4, 4, FERRO)
	_letreiro("MAIN CONCOURSE", Vector3(0, 7.5, zf - 0.7), PI, 64, 0.02, Color(0.3, 0.25, 0.18))
	parque.pontos_altos["grand_central"] = T * Vector3(0, 0.1, zc + 5.0)
	parque.pontos_altos["grand_central_rua"] = T * Vector3(0, 0.1, zf + 8.0)

# ---------------------------------------------------------------------------------------------------------------
# TIMES SQUARE (frente +Z = sul): torres cobertas de telões em volta da praça, a escadaria vermelha e o One Times Square
# ---------------------------------------------------------------------------------------------------------------
func _times_square() -> void:
	alcance = 0.0
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.4, 0.39, 0.38))
	_piso("concreto", -16.0, -D * 0.5 + 30.0, 16.0, D * 0.5 - 30.0, Color(0.55, 0.32, 0.3), 0.07)   # a praça de pedestres
	var ct := _c("telao")
	ct.ao = 0.0
	var seed := 0
	# 4 torres (2 de cada lado), com os telões virados para a praça
	var torres := [[-W * 0.5 + 22.0, -D * 0.5 + 34.0, 40.0, 62.0, 150.0], [-W * 0.5 + 22.0, D * 0.5 - 40.0, 40.0, 74.0, 120.0],
		[W * 0.5 - 22.0, -D * 0.5 + 34.0, 40.0, 62.0, 190.0], [W * 0.5 - 22.0, D * 0.5 - 40.0, 40.0, 74.0, 135.0]]
	for t in torres:
		var x: float = t[0]
		var z: float = t[1]
		var w: float = t[2]
		var d: float = t[3]
		var h: float = t[4]
		_bloco("fachada_escritorio", x, z, 0, w, d, h, Color(0.45, 0.47, 0.5))
		var face := x + (w * 0.5 + 0.35) * (1.0 if x < 0.0 else -1.0)        # a face virada para a praça
		var lado := 1.0 if x < 0.0 else -1.0
		var y := 6.0
		while y < 70.0:
			var hs := 10.0 + r.randf() * 16.0
			var zs := z + r.randf_range(-d * 0.25, d * 0.25)
			var ls := d * r.randf_range(0.45, 0.85)
			seed += 1
			var cor := Color(fmod(seed * 0.618, 1.0), ls / 64.0, hs / 64.0)
			ct.caixa(Vector3(face, y + hs * 0.5, zs), Vector3(0.4, hs, ls), cor, Basis(Vector3.UP, PI * 0.5 * lado))
			_b("ferro", Vector3(face - lado * 0.3, y + hs * 0.5, zs), Vector3(0.3, hs + 0.6, ls + 0.6), Color(0.08, 0.08, 0.09))
			y += hs + 2.0
		# telões nas pontas (sul/norte) também
		var zp := z + (d * 0.5 + 0.35) * (1.0 if z < 0.0 else -1.0)
		seed += 1
		ct.caixa(Vector3(x, 30.0, zp), Vector3(w * 0.8, 24.0, 0.4), Color(fmod(seed * 0.618, 1.0), w * 0.8 / 64.0, 24.0 / 64.0))
	# ONE TIMES SQUARE: a torre estreita no meio (sul) com os telões empilhados e a bola de Ano-Novo
	var zo := D * 0.5 - 12.0
	_bloco("fachada_branca", 0, zo, 0, 14, 18, 110, Color(0.8, 0.8, 0.78))
	var yy := 4.0
	for k in 5:
		seed += 1
		var hs2 := 12.0 + (k % 2) * 6.0
		ct.caixa(Vector3(0, yy + hs2 * 0.5, zo - 9.3), Vector3(14.4, hs2, 0.4), Color(fmod(seed * 0.618, 1.0), 14.4 / 64.0, hs2 / 64.0))
		yy += hs2 + 1.5
	_b("vidro", Vector3(0, yy + 1.2, zo - 9.4), Vector3(14.0, 1.4, 0.2), Color(1.0, 0.3, 0.2))          # faixa de notícias
	_letreiro("ALERTA: EVACUEM MANHATTAN · DIRIJAM-SE AO SUL", Vector3(0, yy + 1.2, zo - 9.6), PI, 48, 0.012, Color(1.0, 0.85, 0.3))
	_cil("aco", Vector3(0, 116.0, zo), 0.3, 12.0, 6, Color(0.6, 0.6, 0.62))
	_cil("vidro", Vector3(0, 121.5, zo), 1.9, 3.8, 12, Color(0.9, 0.9, 1.0))                            # a bola
	# a ESCADARIA VERMELHA (TKTS): dá para subir e sentar
	var ze := -D * 0.5 + 40.0
	_escada("vidro", Vector3(0, 0, ze + 12.0), Vector2(0, -1), 18.0, 5.0, 14.0, Color(0.85, 0.12, 0.1))
	_bc("vidro", Vector3(0, 2.5, ze - 4.0), Vector3(18.0, 5.0, 4.0), Color(0.75, 0.1, 0.08))
	_letreiro("TKTS", Vector3(0, 3.0, ze - 6.05), PI, 96, 0.03, Color(1, 1, 1))
	# letreiros de néon e a estátua (George M. Cohan)
	_letreiro("TIMES SQUARE", Vector3(-W * 0.5 + 42.4, 82.0, -D * 0.5 + 34.0), PI * 0.5, 128, 0.06, Color(1.0, 0.4, 0.2))
	_letreiro("BROADWAY", Vector3(W * 0.5 - 42.4, 76.0, D * 0.5 - 40.0), -PI * 0.5, 128, 0.06, Color(0.3, 0.8, 1.0))
	_letreiro("NOVA YORK NUNCA DORME", Vector3(W * 0.5 - 42.4, 76.0, -D * 0.5 + 34.0), -PI * 0.5, 96, 0.05, Color(1.0, 0.9, 0.3))
	_bc("granito", Vector3(0, 1.2, D * 0.5 - 34.0), Vector3(2.4, 2.4, 2.4), Color(0.4, 0.4, 0.4))
	_figura("bronze", Vector3(0, 2.4, D * 0.5 - 34.0), 2.4, BRONZE_ESCURO, PI, true)
	# táxis amarelos largados na praça
	for k in 5:
		var p := Vector3(r.randf_range(-12.0, 12.0), 0, r.randf_range(-D * 0.5 + 60.0, D * 0.5 - 40.0))
		var g := r.randf() * TAU
		_bc("madeira", p + Vector3(0, 0.75, 0), Vector3(1.9, 1.0, 4.6), AMARELO_TAXI, Basis(Vector3.UP, g))
		_b("vidro_escuro", p + Vector3(0, 1.5, 0), Vector3(1.6, 0.6, 2.4), Color(0.1, 0.12, 0.14), Basis(Vector3.UP, g))
	for k in 8:
		_poste(Vector3(-17.0 if k % 2 == 0 else 17.0, 0, -D * 0.5 + 40.0 + (k / 2) * 26.0))
	parque.pontos_altos["times_square"] = T * Vector3(0, 5.0, ze - 3.0)

# ---------------------------------------------------------------------------------------------------------------
# FLATIRON BUILDING (a ponta para o norte, -Z)
# ---------------------------------------------------------------------------------------------------------------
func _flatiron() -> void:
	alcance = 3000.0
	var c := Color(0.82, 0.72, 0.58)
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.5, 0.49, 0.47))
	var pts := PackedVector2Array([Vector2(-12.0, 26.0), Vector2(26.0, 26.0), Vector2(18.0, -26.0), Vector2(16.0, -27.0)])
	_prisma("fachada_pedra", pts, 0, 82.0, c)
	# a base rústica, a cornija pesada e o topo
	var base := PackedVector2Array([Vector2(-12.6, 26.6), Vector2(26.6, 26.6), Vector2(18.4, -26.4), Vector2(16.0, -27.6)])
	_prisma("pedra", base, 0, 8.0, c * 0.9, false)
	var top := PackedVector2Array([Vector2(-13.2, 27.2), Vector2(27.2, 27.2), Vector2(18.8, -26.8), Vector2(15.8, -28.2)])
	_prisma("pedra", top, 80.0, 82.5, c * 1.05, false)
	_prisma("fachada_pedra", PackedVector2Array([Vector2(-10.0, 24.0), Vector2(24.0, 24.0), Vector2(17.0, -22.0)]), 82.5, 87.0, c, false)
	_letreiro("FLATIRON", Vector3(7.0, 5.0, 26.8), 0.0, 72, 0.02, Color(0.3, 0.25, 0.2))

# ---------------------------------------------------------------------------------------------------------------
# WALL STREET: BOLSA DE NOVA YORK e o TOURO (frente +Z)
# ---------------------------------------------------------------------------------------------------------------
func _wall_street() -> void:
	alcance = 2500.0
	var c := Color(0.86, 0.84, 0.78)
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.48, 0.46, 0.44))
	var zf := 2.0
	_bloco("fachada_pedra", 0, zf - 20.0, 0, 52, 40, 32, c)
	_bc("pedra", Vector3(0, 3.0, zf + 2.0), Vector3(40, 6.0, 4.0), c * 0.95)                     # embasamento
	for k in 6:
		var x := -15.0 + k * 6.0
		_cil("pedra", Vector3(x, 6.0 + 8.5, zf + 2.5), 1.0, 17.0, 14, c * 1.03)
		_b("pedra", Vector3(x, 23.5, zf + 2.5), Vector3(2.4, 1.0, 2.4), c * 1.06)
	_b("pedra", Vector3(0, 25.0, zf + 2.5), Vector3(42.0, 2.0, 4.0), c)                         # arquitrave
	_letreiro("NEW YORK STOCK EXCHANGE", Vector3(0, 25.0, zf + 4.6), 0.0, 72, 0.025, Color(0.3, 0.28, 0.22))
	# o frontão triangular com as figuras
	var fr := PackedVector2Array([Vector2(-21.0, 0.0), Vector2(21.0, 0.0), Vector2(0.0, 7.0)])
	for k in 8:
		var t := (k + 0.5) / 8.0
		var x2 := -18.0 + t * 36.0
		var hh2 := 6.0 * (1.0 - absf(x2) / 21.0)
		_b("pedra", Vector3(x2, 26.0 + hh2 * 0.5, zf + 2.6), Vector3(4.6, hh2, 3.6), c)
		_figura("pedra", Vector3(x2, 26.0, zf + 4.2), hh2 * 0.8 + 0.4, c * 1.05, 0.0, true)
	# a bandeira gigante dos EUA atrás das colunas (rasgada)
	for k in 13:
		var cor := Color(0.65, 0.12, 0.12) if k % 2 == 0 else Color(0.9, 0.88, 0.85)
		_b("madeira", Vector3(2.0 + (k % 3) * 0.4, 21.0 - k * 1.0, zf + 0.6), Vector3(26.0 - (k % 4) * 2.5, 1.0, 0.04), cor)
	_b("madeira", Vector3(-6.0, 17.5, zf + 0.62), Vector3(10.0, 7.0, 0.04), Color(0.15, 0.2, 0.42))
	# o TOURO (bronze) e a menina que o encara
	var tb := Vector3(-4.0, 0, D * 0.5 - 14.0)
	_touro(tb, -0.4)
	_figura("bronze", tb + Vector3(5.0, 0, -5.5), 1.3, BRONZE_ESCURO * 1.2, 2.6, false)
	for k in 4:
		_poste(Vector3(-W * 0.5 + 8.0 + k * 21.0, 0, D * 0.5 - 4.0))
	parque.pontos_altos["touro"] = T * (tb + Vector3(0, 0, 6.0))

func _touro(p: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var cor := Color(0.36, 0.28, 0.18)
	_b("bronze", p + b * Vector3(0, 1.6, 0), Vector3(1.9, 1.7, 4.4), cor, b)                      # corpo
	_b("bronze", p + b * Vector3(0, 2.2, -0.6), Vector3(2.1, 1.3, 2.4), cor, b)                   # cupim/ombros
	_b("bronze", p + b * Vector3(0, 1.4, -2.7), Vector3(1.1, 1.1, 1.4), cor, b * Basis(Vector3.RIGHT, 0.5))   # cabeça baixa
	for s: float in [-1.0, 1.0]:
		_tubo("bronze", p + b * Vector3(s * 0.45, 1.9, -3.0), p + b * Vector3(s * 1.4, 2.6, -3.6), 0.12, OURO * 0.8)    # chifres
		for f: float in [-1.0, 1.0]:
			_tubo("bronze", p + b * Vector3(s * 0.6, 1.1, f * 1.6), p + b * Vector3(s * 0.65, 0.0, f * 1.6 - (0.6 if f < 0.0 else -0.2)), 0.2, cor)
	_tubo("bronze", p + b * Vector3(0, 2.0, 2.2), p + b * Vector3(0.6, 3.0, 3.0), 0.08, cor)         # rabo levantado
	_bc("granito", p + Vector3(0, 0.1, 0), Vector3(3.2, 0.2, 5.8), Color(0.3, 0.3, 0.31), b)
	_col(p + Vector3(0, 1.5, 0), Vector3(2.2, 3.0, 5.0), b)

# ---------------------------------------------------------------------------------------------------------------
# THE VESSEL (Hudson Yards): a colmeia de escadas cor de cobre (mais larga em cima)
# ---------------------------------------------------------------------------------------------------------------
func _vessel() -> void:
	alcance = 2500.0
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.6, 0.58, 0.55))
	var cobre := Color(0.62, 0.38, 0.24)
	var niveis := 15
	var lados := 16
	for k in niveis:
		var y := 2.0 + k * 3.0
		var rr := 8.0 + k * 0.95
		for i in lados:
			var a := (i + (k % 2) * 0.5) * TAU / lados
			var p := Vector3(cos(a) * rr, y, sin(a) * rr)
			_b("cobre", p, Vector3(3.0, 0.35, 2.4), cobre, Basis(Vector3.UP, -a))           # patamar
			# lances de escada para os 2 patamares de cima (o "X" da colmeia)
			if k < niveis - 1:
				for s: float in [-0.5, 0.5]:
					var a2 := a + s * TAU / lados
					var r2 := rr + 0.95
					var q := Vector3(cos(a2) * r2, y + 3.0, sin(a2) * r2)
					var meio := (p + q) * 0.5
					var dd := q - p
					var bb := Basis.looking_at(dd.normalized(), Vector3.UP)
					_b("cobre", meio, Vector3(1.6, 0.3, dd.length()), cobre * 0.9, bb)
					_b("cobre", meio + bb.x * 0.85 + Vector3(0, 0.5, 0), Vector3(0.12, 1.1, dd.length()), cobre * 1.15, bb)
	_col(Vector3(0, 23.0, 0), Vector3(16.0, 46.0, 16.0))
	for k in 8:
		var a3 := k * TAU / 8.0
		_arvore("freixo_p", Vector3(cos(a3) * 36.0, 0, sin(a3) * 36.0), 0.9)
	parque.pontos_altos["vessel"] = T * Vector3(0, 0, 30.0)

# ---------------------------------------------------------------------------------------------------------------
# SEDE DA ONU (o rio fica em +X): Secretariado (vidro verde), Assembleia Geral e as bandeiras
# ---------------------------------------------------------------------------------------------------------------
func _un() -> void:
	alcance = 0.0
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.55, 0.55, 0.53))
	var xs := W * 0.5 - 40.0
	_bloco("fachada_vidro_verde", xs, 0, 0, 22, 87, 155, Color(0.75, 0.8, 0.78))
	for s: float in [-1.0, 1.0]:
		_b("pedra", Vector3(xs, 77.5, s * 43.8), Vector3(22.4, 155.0, 0.8), MARMORE)       # as pontas de mármore
	_b("concreto", Vector3(xs, 156.0, 0), Vector3(22.4, 2.0, 87.4), Color(0.5, 0.52, 0.5))
	# Assembleia Geral: prédio baixo de teto côncavo e a cupulazinha
	var xa := xs - 70.0
	_bloco("pedra", xa, 18.0, 0, 34, 70, 20, MARMORE)
	_b("concreto", Vector3(xa, 20.5, 18.0), Vector3(34.4, 1.0, 70.4), Color(0.55, 0.55, 0.53))
	_cil("cobre", Vector3(xa, 24.0, 18.0), 9.0, 7.0, 16, Color(0.4, 0.42, 0.42), Basis.IDENTITY, 2.0)
	_bloco("fachada_vidro", xs - 30.0, -26.0, 0, 30, 20, 14, Color(0.7, 0.72, 0.74))
	# as bandeiras dos países (fileira em frente: -X) e o letreiro
	for k in 36:
		var z := -D * 0.5 + 6.0 + k * (D - 12.0) / 35.0
		var p := Vector3(-W * 0.5 + 8.0, 0, z)
		_cil("ferro", p + Vector3(0, 5.5, 0), 0.06, 11.0, 5, Color(0.65, 0.65, 0.68))
		_b("madeira", p + Vector3(0.9, 10.0, 0), Vector3(1.8, 1.1, 0.03), Color.from_hsv(fmod(k * 0.271, 1.0), 0.75, 0.8))
	_letreiro("NAÇÕES UNIDAS", Vector3(-W * 0.5 + 14.0, 2.0, 0), -PI * 0.5, 96, 0.03, Color(0.9, 0.9, 0.9))
	# a escultura do revólver com o cano amarrado (Non-Violence)
	_b("bronze", Vector3(-W * 0.5 + 24.0, 1.6, -30.0), Vector3(1.2, 1.4, 3.6), Color(0.4, 0.33, 0.2))
	_cil("bronze", Vector3(-W * 0.5 + 24.0, 2.0, -27.0), 0.7, 1.0, 10, Color(0.4, 0.33, 0.2), Basis(Vector3.RIGHT, PI * 0.5))

# ---------------------------------------------------------------------------------------------------------------
# MUSEU GUGGENHEIM (frente +Z = 5ª Avenida / Central Park): a espiral branca
# ---------------------------------------------------------------------------------------------------------------
func _guggenheim() -> void:
	alcance = 2500.0
	var bco := Color(0.92, 0.91, 0.87)
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.6, 0.59, 0.57))
	var cg := Vector3(-6.0, 0, 4.0)
	_cil("concreto", cg + Vector3(0, 2.5, 0), 12.0, 5.0, 32, bco)
	_col(cg + Vector3(0, 13.0, 0), Vector3(30.0, 26.0, 30.0))
	for k in 4:
		var rr := 13.5 + k * 1.6
		var y := 5.4 + k * 5.2
		_cil("concreto", cg + Vector3(0, y + 2.2, 0), rr, 4.4, 36, bco, Basis.IDENTITY, rr + 0.6)
		_cil("vidro_escuro", cg + Vector3(0, y + 4.7, 0), rr - 0.6, 0.6, 36, Color(0.15, 0.17, 0.18))   # a faixa de vidro
	_cil("vidro", cg + Vector3(0, 27.0, 0), 9.0, 2.0, 24, Color(0.85, 0.9, 0.95), Basis.IDENTITY, 6.0)     # claraboia
	_cil("concreto", cg + Vector3(14.0, 4.0, -10.0), 7.5, 8.0, 24, bco)                            # a rotunda pequena
	_bloco("fachada_pedra", 18.0, -18.0, 0, 26, 22, 30, Color(0.8, 0.78, 0.72))                    # o anexo
	_letreiro("SOLOMON R. GUGGENHEIM MUSEUM", cg + Vector3(0, 4.0, 12.1), 0.0, 48, 0.02, Color(0.15, 0.15, 0.15))
	parque.pontos_altos["guggenheim"] = T * Vector3(0, 0, 25.0)
