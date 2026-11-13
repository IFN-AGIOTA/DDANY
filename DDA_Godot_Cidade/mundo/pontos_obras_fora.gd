extends "res://mundo/pontos_obras.gd"
# CONSTRUÇÕES DOS PONTOS TURÍSTICOS (1.21) · FORA DO MIOLO DE MIDTOWN. Quem chama: mundo/pontos_turisticos.gd (montar
# usa ESTE script, que estende o pontos_obras.gd: os tipos que não estão aqui vão para o de Manhattan).
# Coordenadas LOCAIS como no pontos_obras.gd: y = 0 no chão do terreno, +Z = a frente, W x D = o terreno.
#   liberty       · ESTÁTUA DA LIBERDADE: o Forte Wood (estrela de 11 pontas, dá para subir pela escadaria), a base
#                   de concreto, o pedestal de granito com a loggia, e a estátua de cobre verde (manto, a tocha
#                   dourada no braço direito erguido, a coroa de 7 raios, a tábua no braço esquerdo): 95 m
#   washington_sq · WASHINGTON SQUARE PARK: o ARCO de mármore no fim da 5ª Avenida (o caminho passa por baixo), a
#                   fonte redonda no meio, os caminhos em estrela, os gramados com cerquinha, os olmos (o "Olmo do
#                   Enforcado" no canto), bancos, postes e as mesas de xadrez
#   coney         · CONEY ISLAND: o calçadão de madeira e a areia, a RODA-GIGANTE (cabines coloridas), a
#                   MONTANHA-RUSSA de madeira (dá para subir os trilhos pela estação: a subida é uma rampa), a TORRE
#                   DO PARAQUEDAS (o "guarda-chuva" de aço), o portal CONEY ISLAND, barracas e o carrinho de bate-bate
#   yankee        · YANKEE STADIUM: a fachada de calcário com os arcos e as letras douradas, as arquibancadas azuis
#                   (de subir), o campo (grama, terra, bases, montinho), o friso branco no teto, as torres de luz e o
#                   placar no fundo; os portões (atrás da casa base e nas laterais) levam ao campo por baixo das arquibancadas
#   unisphere     · UNISPHERE (Flushing Meadows): o globo de aço inox (meridianos, paralelos, os continentes em placas,
#                   inclinado), os 3 anéis das órbitas, a base de tripé, o espelho d'água redondo com os jatos

const COBRE_VERDE := Color(0.4, 0.62, 0.54)
const GRANITO_ROSA := Color(0.64, 0.59, 0.55)
const AZUL_YANKEE := Color(0.09, 0.16, 0.36)
const AREIA := Color(0.86, 0.79, 0.62)

func _montar_tipo(tipo: String) -> void:
	match tipo:
		"liberty": _liberty()
		"washington_sq": _washington_sq()
		"coney": _coney()
		"yankee": _yankee()
		"unisphere": _unisphere()
		_: super._montar_tipo(tipo)

# anel de colisão (caixas) no chão: centro, raio, quantas, largura, altura
func _anel_col(c: Vector3, raio: float, n: int, larg: float, alt: float) -> void:
	for k in n:
		var a := (k + 0.5) * TAU / n
		var corda := 2.0 * raio * sin(PI / n) + 0.05
		_col(c + Vector3(cos(a) * raio, 0, sin(a) * raio), Vector3(corda, alt, larg), Basis(Vector3.UP, -a + PI * 0.5))

# ---------------------------------------------------------------------------------------------------------------
# ESTÁTUA DA LIBERDADE (a frente +Z olha para a entrada do porto)
# ---------------------------------------------------------------------------------------------------------------
func _liberty() -> void:
	alcance = 0.0
	var gr := Color(0.66, 0.63, 0.58)
	var n := 11
	var r_out := 44.0
	var r_in := 32.0
	var hf := 7.0
	# o passeio de pedra em volta do forte
	_cil("pedra_chao", Vector3(0, 0.03, 0), 54.0, 0.06, 40, Color(0.56, 0.54, 0.5))
	# o FORTE WOOD: o miolo (11 lados) e as 11 pontas da estrela (cada uma um prisma: a colisão fica certinha)
	var dentro := PackedVector2Array()
	var fora := PackedVector2Array()
	for k in n:
		var a := PI * 0.5 + k * TAU / n                           # o vértice de dentro da frente (+Z) é um "vão"
		dentro.append(Vector2(cos(a), sin(a)) * r_in)
		var a2 := a + PI / n
		fora.append(Vector2(cos(a2), sin(a2)) * r_out)
	_prisma("granito", dentro, 0.0, hf, gr)
	for k in n:
		_prisma("granito", PackedVector2Array([dentro[k], fora[k], dentro[(k + 1) % n]]), 0.0, hf, gr)
	_cil("gramado", Vector3(0, hf + 0.04, 0), r_in - 4.0, 0.08, n * 2, Color(0.3, 0.46, 0.2))
	_cil("pedra_chao", Vector3(0, hf + 0.02, 0), r_in - 0.3, 0.06, n * 2, Color(0.6, 0.58, 0.54))
	# o parapeito do forte (a mureta em volta das pontas)
	for k in n:
		for par in [[dentro[k], fora[k]], [fora[k], dentro[(k + 1) % n]]]:
			var p0: Vector2 = par[0]
			var p1: Vector2 = par[1]
			if k == 0 and p0 == dentro[0]:
				continue                                          # a escadaria chega aqui
			if k == n - 1 and p1 == dentro[0]:
				continue
			var m := (p0 + p1) * 0.5
			var dd := p1 - p0
			_bc("granito", Vector3(m.x, hf + 0.5, m.y), Vector3(dd.length(), 1.0, 0.6), gr * 1.04, Basis(Vector3.UP, -atan2(dd.y, dd.x)))
	# a ESCADARIA da frente (no "vão" da estrela): sobe os 7 m até o alto do forte
	_bc("granito", Vector3(0, hf * 0.5, 34.5), Vector3(10.0, hf, 6.0), gr)
	_escada("granito", Vector3(0, 0, 51.5), Vector2(0, -1), 9.0, hf, 14.0, gr * 0.95)
	for s: float in [-1.0, 1.0]:
		_balaustrada("granito", Vector3(s * 4.8, 0, 51.5), Vector3(s * 4.8, hf, 37.5), gr)
	_letreiro("ESTÁTUA DA LIBERDADE · 1886", Vector3(0, 1.4, 52.6), 0.0, 64, 0.02, Color(0.2, 0.2, 0.2))
	# a BASE (concreto, em degraus) e o PEDESTAL de granito
	var cc := Color(0.72, 0.7, 0.66)
	_bloco("concreto", 0, 0, hf, 30, 30, 4, cc)
	_bloco("concreto", 0, 0, hf + 4.0, 27, 27, 4, cc * 1.02)
	_bloco("concreto", 0, 0, hf + 8.0, 24, 24, 5, cc)
	var y := hf + 13.0                                            # 20 m
	_bloco("granito", 0, 0, y, 20, 20, 4, GRANITO_ROSA)
	_bloco("granito", 0, 0, y + 4.0, 17, 17, 12, GRANITO_ROSA)
	_bloco("granito", 0, 0, y + 16.0, 16, 16, 6, GRANITO_ROSA * 0.92)
	for lado in 4:
		var a := lado * PI * 0.5
		var nrm := Vector3(sin(a), 0, cos(a))
		var tg := Vector3(cos(a), 0, -sin(a))
		var b := Basis(Vector3.UP, a)
		# a loggia: o vão escuro com 4 colunas e o escudo redondo embaixo
		_b("vidro_escuro", nrm * 8.06 + Vector3(0, y + 19.0, 0), Vector3(11.0, 4.6, 0.1), Color(0.08, 0.08, 0.09), b)
		for f in 4:
			_cil("granito", nrm * 8.4 + tg * (-4.5 + f * 3.0) + Vector3(0, y + 19.0, 0), 0.42, 5.6, 8, GRANITO_ROSA * 1.05)
		_cil("granito", nrm * 8.6 + Vector3(0, y + 10.0, 0), 2.0, 0.3, 16, GRANITO_ROSA * 1.08, b * Basis(Vector3.RIGHT, PI * 0.5))
		for f in 2:
			_b("granito", nrm * 8.55 + tg * (f * 2.0 - 1.0) * 7.2 + Vector3(0, y + 9.0, 0), Vector3(1.6, 10.0, 0.3), GRANITO_ROSA * 1.04, b)
	_b("granito", Vector3(0, y + 22.5, 0), Vector3(19.0, 1.0, 19.0), GRANITO_ROSA * 1.05)
	_bloco("granito", 0, 0, y + 23.0, 17, 17, 3, GRANITO_ROSA)
	_b("granito", Vector3(0, y + 26.4, 0), Vector3(17.8, 0.8, 17.8), GRANITO_ROSA * 1.06)
	# a ESTÁTUA (cobre verde): o manto, o tronco, a cabeça com a coroa, a tocha e a tábua
	var yb := y + 26.8
	var cv := COBRE_VERDE
	_cil("cobre", Vector3(0, yb + 0.6, 0), 6.2, 1.2, 14, cv * 0.85)
	for k in 6:                                                   # as correntes quebradas aos pés
		var a := k * TAU / 6.0
		_b("cobre", Vector3(cos(a) * 5.0, yb + 1.3, sin(a) * 5.0), Vector3(1.4, 0.3, 0.5), cv * 0.7, Basis(Vector3.UP, a))
	_cil("cobre", Vector3(0, yb + 1.2 + 11.4, 0), 5.6, 22.8, 16, cv, Basis.IDENTITY, 3.9)
	for k in 14:                                                  # as dobras do manto
		var a := (k + 0.3) * TAU / 14.0
		_tubo("cobre", Vector3(cos(a) * 5.45, yb + 1.3, sin(a) * 5.45), Vector3(cos(a + 0.15) * 3.8, yb + 23.5, sin(a + 0.15) * 3.8), 0.42, cv * (0.9 + 0.1 * (k % 2)), 5)
	_b("cobre", Vector3(-1.7, yb + 7.5, 4.3), Vector3(2.4, 11.0, 1.4), cv * 1.02, Basis(Vector3.RIGHT, -0.16))      # o joelho
	_b("cobre", Vector3(-1.4, yb + 1.6, 5.9), Vector3(1.6, 0.9, 2.6), cv * 0.9)                                      # o pé
	_cil("cobre", Vector3(0, yb + 27.4, 0), 3.9, 7.4, 14, cv, Basis.IDENTITY, 3.2)                                   # o tronco
	_tubo("cobre", Vector3(3.0, yb + 31.0, 1.2), Vector3(-3.2, yb + 22.0, 3.0), 0.85, cv * 1.06, 6)                  # a toga
	_b("cobre", Vector3(0, yb + 31.2, 0), Vector3(8.2, 1.8, 4.2), cv)                                                  # ombros
	_cil("cobre", Vector3(0, yb + 32.8, 0), 1.2, 1.8, 10, cv)                                                        # pescoço
	_cil("cobre", Vector3(0, yb + 35.2, 0.1), 1.75, 3.8, 12, cv, Basis.IDENTITY, 1.45)                               # cabeça
	_b("cobre", Vector3(0, yb + 35.1, 1.75), Vector3(0.45, 1.0, 0.45), cv * 1.05)                                     # nariz
	_b("cobre", Vector3(0, yb + 35.9, 1.5), Vector3(2.2, 0.35, 0.5), cv * 0.95)                                       # testa
	_cil("cobre", Vector3(0, yb + 35.3, -1.5), 1.2, 1.6, 8, cv * 0.95, Basis(Vector3.RIGHT, PI * 0.5))               # o coque
	_cil("cobre", Vector3(0, yb + 37.1, 0), 2.05, 1.0, 14, cv * 1.05)                                                # a coroa
	for k in 7:                                                   # os 7 raios
		var a := PI * 0.5 + (k - 3) * 0.5
		var dr := Vector3(cos(a), 0.6, sin(a)).normalized()
		var base := Vector3(cos(a) * 1.9, yb + 37.3, sin(a) * 1.9)
		_tubo("cobre", base, base + dr * 4.2, 0.36, cv * 1.07, 4)
	for k in 6:                                                   # as janelinhas da coroa (o mirante)
		var a := PI * 0.5 + (k - 2.5) * 0.3
		_b("vidro", Vector3(cos(a) * 2.07, yb + 37.0, sin(a) * 2.07), Vector3(0.5, 0.55, 0.08), Color(0.7, 0.65, 0.45), Basis(Vector3.UP, -a + PI * 0.5))
	# o braço DIREITO erguido com a tocha (lado -X: ela olha para +Z)
	var omb := Vector3(-3.8, yb + 31.2, 0.2)
	var coto := Vector3(-4.7, yb + 37.6, 0.0)
	var mao := Vector3(-4.4, yb + 43.2, -0.3)
	_tubo("cobre", omb, coto, 1.1, cv, 8)
	_tubo("cobre", coto, mao, 0.9, cv, 8)
	_b("cobre", mao + Vector3(0, -0.2, 0), Vector3(1.6, 1.4, 1.4), cv)
	_cil("cobre", mao + Vector3(0, 1.1, 0), 0.6, 2.6, 8, cv * 1.05)
	_cil("ouro", mao + Vector3(0, 2.7, 0), 0.9, 0.9, 12, OURO, Basis.IDENTITY, 1.45)
	_cil("ouro", mao + Vector3(0, 3.2, 0), 1.7, 0.25, 14, OURO)
	_cil("vidro", mao + Vector3(0, 4.3, 0), 1.05, 2.0, 8, Color(1.0, 0.72, 0.28), Basis.IDENTITY, 0.08)              # a chama
	# o braço ESQUERDO segura a TÁBUA (JULY IV MDCCLXXVI) contra o corpo
	var omb2 := Vector3(3.8, yb + 30.8, 0.2)
	var coto2 := Vector3(4.5, yb + 26.0, 1.3)
	var mao2 := Vector3(3.3, yb + 27.2, 3.3)
	_tubo("cobre", omb2, coto2, 0.95, cv, 8)
	_tubo("cobre", coto2, mao2, 0.8, cv, 8)
	_b("cobre", Vector3(4.4, yb + 28.8, 2.5), Vector3(0.7, 7.2, 4.1), cv * 1.1, Basis(Vector3.UP, 0.55) * Basis(Vector3.BACK, -0.12) * Basis(Vector3.RIGHT, 0.32))
	_col(Vector3(0, yb + 12.0, 0), Vector3(10.0, 24.0, 10.0))
	# o mastro da bandeira, os postes, bancos e as árvores em volta do passeio
	_cil("ferro", Vector3(0, 12.5, -58.0), 0.12, 25.0, 6, Color(0.75, 0.75, 0.78))
	_b("madeira", Vector3(1.6, 23.5, -58.0), Vector3(3.2, 1.9, 0.04), Color(0.7, 0.15, 0.15))
	for k in 14:
		var a := (k + 0.5) * TAU / 14.0
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.3:
			continue
		_poste(Vector3(cos(a) * 50.0, 0, sin(a) * 50.0))
		_banco(Vector3(cos(a + 0.12) * 52.5, 0, sin(a + 0.12) * 52.5), -(a + 0.12) - PI * 0.5)
	for k in 26:
		var a := (k + 0.5) * TAU / 26.0
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.35:
			continue
		var rr := 60.0 + (k % 3) * 2.5
		_arvore(["olmo_3", "freixo_m", "carvalho_m", "olmo_4"][k % 4], Vector3(cos(a) * rr, 0, sin(a) * rr), 0.85 + 0.1 * (k % 2))
	parque.pontos_altos["liberty_forte"] = T * Vector3(0, hf, 28.0)
	parque.pontos_altos["liberty_escada"] = T * Vector3(0, 0, 53.0)

# ---------------------------------------------------------------------------------------------------------------
# WASHINGTON SQUARE PARK (+Z = norte: a 5ª Avenida chega no arco)
# ---------------------------------------------------------------------------------------------------------------
static func _no_circulo(o: Vector2, d: Vector2, raio: float) -> Vector2:
	var b := o.dot(d)
	var t := -b + sqrt(maxf(b * b - o.length_squared() + raio * raio, 0.0))
	return o + d * t

static func _no_quadrado(o: Vector2, d: Vector2, q: float) -> Vector2:
	var t := INF
	if absf(d.x) > 0.0001:
		t = minf(t, (signf(d.x) * q - o.x) / d.x)
	if absf(d.y) > 0.0001:
		t = minf(t, (signf(d.y) * q - o.y) / d.y)
	return o + d * t

func _washington_sq() -> void:
	alcance = 1800.0
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.52, 0.5, 0.47))
	var rp := 30.0                                                # a praça da fonte
	var q := minf(W, D) * 0.5 - 5.0                               # borda dos gramados
	var larg := 6.0                                               # caminhos
	var gramados: Array = []
	for k in 8:
		var a0 := k * PI * 0.25
		var a1 := a0 + PI * 0.25
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var o0 := Vector2(-d0.y, d0.x) * (larg * 0.5)
		var o1 := Vector2(d1.y, -d1.x) * (larg * 0.5)
		var pts := PackedVector2Array()
		var s0 := _no_circulo(o0, d0, rp)
		pts.append(s0)
		pts.append(_no_quadrado(o0, d0, q))
		pts.append(_no_quadrado(o1, d1, q))
		var e1 := _no_circulo(o1, d1, rp)
		pts.append(e1)
		var ae := atan2(e1.y, e1.x)
		var as0 := atan2(s0.y, s0.x)
		var dif := wrapf(ae - as0, 0.0, TAU)
		for f in range(1, 5):
			var a := ae - dif * f / 5.0
			pts.append(Vector2(cos(a), sin(a)) * rp)
		gramados.append(pts)
		_prisma("gramado", pts, 0.0, 0.14, Color(0.3, 0.46, 0.2), false)
		# a cerquinha de ferro em volta do gramado
		var cen := Vector2(0, 0)
		for p in pts:
			cen += p
		cen /= pts.size()
		for i in pts.size():
			var p0 := pts[i]
			var p1 := pts[(i + 1) % pts.size()]
			var m := (p0 + p1) * 0.5
			var dd := p1 - p0
			var m2 := m + (cen - m).normalized() * 0.4
			_b("ferro", Vector3(m2.x, 0.4, m2.y), Vector3(dd.length(), 0.06, 0.05), FERRO, Basis(Vector3.UP, -atan2(dd.y, dd.x)))
			_b("ferro", Vector3(m2.x, 0.22, m2.y), Vector3(dd.length(), 0.36, 0.02), FERRO * 1.3, Basis(Vector3.UP, -atan2(dd.y, dd.x)))
	# a FONTE: bacia redonda com a borda de granito (o pessoal sentava ali), os jatos no meio
	_anel("granito", Vector3(0, 0.35, 0), 15.0, 36, 1.0, 0.7, Color(0.52, 0.5, 0.48))
	_anel_col(Vector3(0, 0.35, 0), 15.0, 18, 1.0, 0.7)
	_cil("agua_fonte", Vector3(0, 0.22, 0), 14.6, 0.1, 36, Color(1, 1, 1))
	_cil("agua_fonte", Vector3(0, 2.4, 0), 0.6, 4.6, 8, Color(1, 1, 1), Basis.IDENTITY, 0.15)
	for k in 12:
		var a := k * TAU / 12.0
		_cil("agua_fonte", Vector3(cos(a) * 6.0, 1.0, sin(a) * 6.0), 0.18, 1.6, 6, Color(1, 1, 1), Basis.IDENTITY, 0.05)
	# o ARCO de mármore (o caminho do norte passa por baixo)
	var za := q - 7.0
	var ca := Color(0.9, 0.89, 0.85)
	_parede_arcos("pedra", -9.3, 9.3, za, 6.4, 18.0, [[0.0, 9.0, 8.4]], ca)
	_b("pedra", Vector3(0, 18.6, za), Vector3(19.8, 1.2, 7.2), ca * 1.04)
	_bloco("pedra", 0, za, 19.2, 18.6, 6.4, 4.3, ca)
	_b("pedra", Vector3(0, 23.7, za), Vector3(19.2, 0.4, 6.8), ca * 1.05)
	for s: float in [-1.0, 1.0]:
		for f: float in [-1.0, 1.0]:
			_b("pedra", Vector3(s * 8.2, 9.0, za + f * 3.3), Vector3(1.6, 18.0, 0.4), ca * 1.03)                       # pilastras
			_b("pedra", Vector3(s * 5.6, 14.6, za + f * 3.25), Vector3(2.6, 2.4, 0.3), ca * 0.97)                     # anjos (relevo)
		# as estátuas de Washington (norte) nos pedestais
		_bc("pedra", Vector3(s * 5.6, 1.3, za + 4.4), Vector3(3.0, 2.6, 2.4), ca * 0.95)
		_figura("pedra", Vector3(s * 5.6, 2.6, za + 4.4), 4.4, ca * 0.92, 0.0, true)
	_letreiro("WASHINGTON SQUARE", Vector3(0, 21.4, za + 3.25), 0.0, 72, 0.025, Color(0.45, 0.43, 0.4))
	_letreiro("WASHINGTON SQUARE", Vector3(0, 21.4, za - 3.25), PI, 72, 0.025, Color(0.45, 0.43, 0.4))
	# os olmos nos gramados (sorteados dentro de cada um) e o grande, no canto noroeste (+X +Z)
	for g in gramados:
		var pts2: PackedVector2Array = g
		var feitas := 0
		var tent := 0
		while feitas < 5 and tent < 60:
			tent += 1
			var p := Vector2(r.randf_range(-q, q), r.randf_range(-q, q))
			if not Geometry2D.is_point_in_polygon(p, pts2):
				continue
			if p.length() < rp + 4.0 or Geometry2D.get_closest_point_to_segment(p, Vector2(0, za - 6.0), Vector2(0, za + 6.0)).distance_to(p) < 12.0:
				continue
			_arvore(["olmo_1", "olmo_2", "olmo_3", "olmo_4", "freixo_m"][feitas % 5], Vector3(p.x, 0.14, p.y), r.randf_range(0.8, 1.05))
			feitas += 1
	_arvore("olmo_2", Vector3(q - 10.0, 0.14, q - 16.0), 1.35)
	# bancos em volta da praça e nos caminhos, postes
	for k in 16:
		var a := (k + 0.5) * TAU / 16.0
		_banco(Vector3(cos(a) * (rp - 1.4), 0, sin(a) * (rp - 1.4)), -a - PI * 0.5)
	for k in 8:
		var a := k * PI * 0.25
		var dd := Vector2(cos(a), sin(a))
		for t: float in [rp + 10.0, rp + 26.0]:
			var p := dd * t + Vector2(-dd.y, dd.x) * 3.6
			_poste(Vector3(p.x, 0, p.y))
	# as mesas de xadrez (canto sudoeste: +X -Z)
	for k in 8:
		var p := Vector3(q - 14.0 - (k % 4) * 3.4, 0, -q + 9.0 + (k / 4) * 3.6)
		_bc("concreto", p + Vector3(0, 0.38, 0), Vector3(0.9, 0.76, 0.9), Color(0.6, 0.58, 0.55))
		for f in 2:
			_b("concreto", p + Vector3(0, 0.77, 0), Vector3(0.6, 0.02, 0.6), Color(0.15, 0.15, 0.15) if f == 0 else Color(0.85, 0.85, 0.8))
		_cil("concreto", p + Vector3(0.9, 0.24, 0), 0.22, 0.48, 8, Color(0.6, 0.58, 0.55))
		_cil("concreto", p + Vector3(-0.9, 0.24, 0), 0.22, 0.48, 8, Color(0.6, 0.58, 0.55))
	# a estátua de Garibaldi (leste: -X)
	_bc("granito", Vector3(-rp - 8.0, 1.4, 6.0), Vector3(2.6, 2.8, 2.6), Color(0.45, 0.44, 0.43))
	_figura("bronze", Vector3(-rp - 8.0, 2.8, 6.0), 2.8, BRONZE, -PI * 0.5, false)
	parque.pontos_altos["washington_arco"] = T * Vector3(0, 0.1, za - 8.0)
	parque.pontos_altos["washington_rua"] = T * Vector3(0, 0.1, za + 9.0)

# ---------------------------------------------------------------------------------------------------------------
# CONEY ISLAND (+Z = sul: o calçadão e a areia)
# ---------------------------------------------------------------------------------------------------------------
func _coney() -> void:
	alcance = 2500.0
	var hw := W * 0.5
	var hd := D * 0.5
	_piso("pedra_chao", -hw, -hd, hw, hd, Color(0.5, 0.48, 0.46))
	# a AREIA e o CALÇADÃO de madeira (o famoso "boardwalk"), com rampa do lado da rua e guarda-corpo do lado da areia
	var zb0 := hd - 44.0
	var zb1 := zb0 + 12.0
	var yb := 0.6
	_piso("areia", -hw, zb1, hw, hd, AREIA, 0.07)
	_b("madeira", Vector3(0, yb - 0.15, (zb0 + zb1) * 0.5), Vector3(W, 0.3, zb1 - zb0), Color(0.55, 0.42, 0.3))
	_col(Vector3(0, yb - 0.15, (zb0 + zb1) * 0.5), Vector3(W, 0.3, zb1 - zb0))
	for k in int(W / 2.0):
		_b("madeira", Vector3(-hw + 1.0 + k * 2.0, yb + 0.005, (zb0 + zb1) * 0.5), Vector3(0.06, 0.01, zb1 - zb0), Color(0.3, 0.22, 0.15))
	var inc := atan2(yb, 3.0)
	_b("madeira", Vector3(0, yb * 0.5 - 0.1, zb0 - 1.5), Vector3(W, 0.2, sqrt(9.0 + yb * yb)), Color(0.5, 0.4, 0.3), Basis(Vector3.RIGHT, inc))
	_col(Vector3(0, yb * 0.5 - 0.15, zb0 - 1.5), Vector3(W, 0.3, sqrt(9.0 + yb * yb)), Basis(Vector3.RIGHT, inc))
	var nseg := int(W / 30.0)
	for k in nseg:
		var x0 := -hw + k * W / nseg
		var x1 := x0 + W / nseg
		# a descida para a areia no meio de cada trecho (rampa); guarda-corpo no resto
		var xm := (x0 + x1) * 0.5
		for par in [[x0 + 0.2, xm - 2.5], [xm + 2.5, x1 - 0.2]]:
			var a: float = par[0]
			var b: float = par[1]
			_b("madeira", Vector3((a + b) * 0.5, yb + 1.0, zb1 - 0.15), Vector3(b - a, 0.12, 0.12), Color(0.85, 0.83, 0.78))
			_b("madeira", Vector3((a + b) * 0.5, yb + 0.55, zb1 - 0.15), Vector3(b - a, 0.08, 0.06), Color(0.85, 0.83, 0.78))
			_col(Vector3((a + b) * 0.5, yb + 0.55, zb1 - 0.15), Vector3(b - a, 1.1, 0.2))
			var np := int((b - a) / 2.5)
			for f in range(np + 1):
				_b("madeira", Vector3(a + (b - a) * f / maxf(np, 1), yb + 0.5, zb1 - 0.15), Vector3(0.14, 1.0, 0.14), Color(0.85, 0.83, 0.78))
		_b("madeira", Vector3(xm, yb * 0.5 - 0.1, zb1 + 1.5), Vector3(5.0, 0.2, sqrt(9.0 + yb * yb)), Color(0.5, 0.4, 0.3), Basis(Vector3.RIGHT, -inc))
		_col(Vector3(xm, yb * 0.5 - 0.15, zb1 + 1.5), Vector3(5.0, 0.3, sqrt(9.0 + yb * yb)), Basis(Vector3.RIGHT, -inc))
		_poste(Vector3(x0 + 4.0, yb, zb0 + 0.8))
		_banco(Vector3(x0 + 9.0, yb, zb1 - 1.4), 0.0)
		_banco(Vector3(x0 + 21.0, yb, zb1 - 1.4), 0.0)
	# o posto de salva-vidas na areia
	for x: float in [-hw * 0.5, hw * 0.4]:
		var p := Vector3(x, 0, hd - 12.0)
		for f in 4:
			_tubo("madeira", p + Vector3((f % 2) * 2.0 - 1.0, 0, (f / 2) * 2.0 - 1.0), p + Vector3(((f % 2) * 2.0 - 1.0) * 0.6, 2.6, ((f / 2) * 2.0 - 1.0) * 0.6), 0.08, Color(0.92, 0.92, 0.9), 4)
		_b("madeira", p + Vector3(0, 2.7, 0), Vector3(1.6, 0.12, 1.6), Color(0.92, 0.92, 0.9))
		_b("madeira", p + Vector3(0, 3.2, -0.7), Vector3(1.6, 1.0, 0.1), Color(0.85, 0.15, 0.12))
	# a RODA-GIGANTE (oeste do meio)
	_roda_gigante(Vector3(-hw + 120.0, 0, -6.0))
	# a TORRE DO PARAQUEDAS (oeste, no calçadão)
	_paraquedas(Vector3(-hw + 32.0, 0, zb0 - 18.0))
	# a MONTANHA-RUSSA de madeira (leste)
	_montanha_russa(Vector3(hw - 85.0, 0, -hd + 30.0))
	# o portal CONEY ISLAND (do lado da rua, norte)
	var xp := -hw + 175.0
	for s: float in [-1.0, 1.0]:
		_bc("ferro", Vector3(xp + s * 7.0, 4.5, -hd + 4.0), Vector3(0.8, 9.0, 0.8), Color(0.75, 0.1, 0.1))
	_b("madeira", Vector3(xp, 9.5, -hd + 4.0), Vector3(16.0, 2.6, 0.5), Color(0.95, 0.85, 0.3))
	for k in 24:
		_b("vidro", Vector3(xp - 7.6 + k * 0.66, 10.95, -hd + 4.0), Vector3(0.18, 0.18, 0.6), Color(1.0, 0.9, 0.6))
	_letreiro("CONEY ISLAND", Vector3(xp, 9.5, -hd + 3.7), PI, 128, 0.02, Color(0.75, 0.1, 0.1))
	_letreiro("CONEY ISLAND", Vector3(xp, 9.5, -hd + 4.3), 0.0, 128, 0.02, Color(0.75, 0.1, 0.1))
	# as barracas ao longo do calçadão (cachorro-quente, fritas, sorvete, tiro ao alvo)
	var nomes := ["HOT DOGS", "FRITAS", "SORVETE", "TIRO AO ALVO", "ALGODÃO-DOCE", "LIMONADA", "PIZZA", "CERVEJA", "PESCARIA", "SOUVENIRS"]
	var xs := [-116.0, -107.0, -98.0, -89.0, -80.0, -71.0, 22.0, 31.0, 40.0, 49.0]
	for k in nomes.size():
		var x: float = xs[k]
		var cor := Color.from_hsv(fmod(k * 0.17, 1.0), 0.65, 0.85)
		var p := Vector3(x, 0, zb0 - 7.0)
		_bc("madeira", p + Vector3(0, 1.6, 0), Vector3(6.0, 3.2, 4.0), Color(0.92, 0.9, 0.85))
		_b("vidro_escuro", p + Vector3(0, 1.8, 2.02), Vector3(4.6, 1.2, 0.05), Color(0.1, 0.1, 0.1))
		_b("madeira", p + Vector3(0, 1.0, 2.2), Vector3(5.6, 0.1, 0.5), cor * 0.8)
		for f in 6:
			_b("madeira", p + Vector3(-2.6 + f * 1.04, 3.3, 2.6), Vector3(1.04, 0.06, 1.8), cor if f % 2 == 0 else Color(0.95, 0.95, 0.92), Basis(Vector3.RIGHT, 0.35))
		_letreiro(String(nomes[k]), p + Vector3(0, 3.9, 2.05), 0.0, 48, 0.02, cor * 0.6)
	# o carrinho de bate-bate (pavilhão coberto, lados abertos)
	var pb := Vector3(-hw + 155.0, 0, -hd + 26.0)
	_b("concreto", pb + Vector3(0, 0.08, 0), Vector3(26.0, 0.16, 16.0), Color(0.35, 0.35, 0.38))
	for s: float in [-1.0, 1.0]:
		for f: float in [-1.0, 1.0]:
			_bc("ferro", pb + Vector3(s * 12.5, 2.5, f * 7.5), Vector3(0.4, 5.0, 0.4), Color(0.85, 0.75, 0.2))
	_b("telhado", pb + Vector3(0, 5.2, 0), Vector3(27.0, 0.4, 17.0), Color(0.75, 0.2, 0.2))
	_b("ferro", pb + Vector3(0, 4.6, 0), Vector3(25.0, 0.06, 15.0), Color(0.2, 0.2, 0.22))
	for k in 9:
		var p := pb + Vector3(r.randf_range(-11.0, 11.0), 0, r.randf_range(-6.0, 6.0))
		var g := r.randf() * TAU
		_bc("vidro", p + Vector3(0, 0.45, 0), Vector3(1.4, 0.6, 2.0), Color.from_hsv(r.randf(), 0.8, 0.8), Basis(Vector3.UP, g))
		_cil("ferro", p + Vector3(0, 2.6, 0), 0.03, 3.8, 4, FERRO)
	_letreiro("BATE-BATE", pb + Vector3(0, 6.0, 8.6), 0.0, 96, 0.025, Color(1.0, 0.85, 0.2))
	parque.pontos_altos["coney_calcadao"] = T * Vector3(0, yb, (zb0 + zb1) * 0.5)

func _roda_gigante(c: Vector3) -> void:
	var rr := 21.0
	var yc := 25.0
	var hub := c + Vector3(0, yc, 0)
	var branco := Color(0.92, 0.92, 0.9)
	# as duas torres em "A"
	for s: float in [-1.0, 1.0]:
		for f: float in [-1.0, 1.0]:
			_tubo("ferro", c + Vector3(f * 12.0, 0, s * 4.5), hub + Vector3(0, 0, s * 2.2), 0.45, branco, 6)
			_col(c + Vector3(f * 12.0, 1.5, s * 4.5), Vector3(1.0, 3.0, 1.0))
		_tubo("ferro", c + Vector3(-8.0, 8.5, s * 3.7), c + Vector3(8.0, 8.5, s * 3.7), 0.3, branco, 6)
	_cil("ferro", hub, 1.4, 5.0, 12, Color(0.7, 0.7, 0.72), Basis(Vector3.RIGHT, PI * 0.5))
	# os aros (fora e dentro), os raios e as lâmpadas
	var nn := 32
	for s: float in [-1.6, 1.6]:
		for k in nn:
			var a0 := k * TAU / nn
			var a1 := (k + 1) * TAU / nn
			_tubo("ferro", hub + Vector3(cos(a0) * rr, sin(a0) * rr, s), hub + Vector3(cos(a1) * rr, sin(a1) * rr, s), 0.22, branco, 4)
			_tubo("ferro", hub + Vector3(cos(a0) * 13.0, sin(a0) * 13.0, s), hub + Vector3(cos(a1) * 13.0, sin(a1) * 13.0, s), 0.16, branco, 4)
			_b("vidro", hub + Vector3(cos(a0) * (rr + 0.3), sin(a0) * (rr + 0.3), s * 1.15), Vector3(0.25, 0.25, 0.25), Color(1.0, 0.85, 0.5) if k % 2 == 0 else Color(1.0, 0.35, 0.6))
		for k in 16:
			var a := k * TAU / 16.0
			_tubo("ferro", hub + Vector3(0, 0, s * 1.2), hub + Vector3(cos(a) * rr, sin(a) * rr, s), 0.14, branco, 4)
	# as 24 cabines (penduradas, coloridas)
	for k in 24:
		var a := k * TAU / 24.0
		var p := hub + Vector3(cos(a) * (rr - 0.6), sin(a) * (rr - 0.6) - 1.7, 0)
		var cor: Color = [Color(0.85, 0.15, 0.15), Color(0.15, 0.4, 0.8), Color(0.95, 0.75, 0.15), Color(0.2, 0.65, 0.3)][k % 4]
		_b("vidro", p, Vector3(2.0, 2.0, 2.4), cor)
		_b("ferro", p + Vector3(0, 1.15, 0), Vector3(2.2, 0.2, 2.6), branco)
		_b("vidro_escuro", p + Vector3(0, 0.3, 0), Vector3(2.04, 0.8, 1.8), Color(0.1, 0.1, 0.1))
	# a estação (embarque) e o letreiro
	_bc("concreto", c + Vector3(0, 0.5, 0), Vector3(10.0, 1.0, 6.0), Color(0.6, 0.58, 0.55))
	_letreiro("RODA-GIGANTE · 1920", c + Vector3(0, 2.4, 3.2), 0.0, 64, 0.02, Color(0.95, 0.85, 0.3))

func _paraquedas(c: Vector3) -> void:
	var cor := Color(0.72, 0.2, 0.13)
	var h := 60.0
	var b0 := 8.0
	var b1 := 3.0
	var nv := 8
	for k in 4:
		var sx := 1.0 if k % 2 == 0 else -1.0
		var sz := 1.0 if k < 2 else -1.0
		_tubo("ferro", c + Vector3(sx * b0, 0, sz * b0), c + Vector3(sx * b1, h, sz * b1), 0.4, cor, 6)
		_col(c + Vector3(sx * b0, 2.0, sz * b0), Vector3(1.2, 4.0, 1.2))
	# os quadros e as diagonais em cada nível
	for v in nv:
		var ya := h * v / nv
		var yz := h * (v + 1) / nv
		var la := lerpf(b0, b1, float(v) / nv)
		var lz := lerpf(b0, b1, float(v + 1) / nv)
		for lado in 4:
			var a := lado * PI * 0.5
			var tg := Vector3(cos(a), 0, sin(a))
			var nr := Vector3(-sin(a), 0, cos(a))
			var p0 := c + nr * la + tg * la + Vector3(0, ya, 0)
			var p1 := c + nr * la - tg * la + Vector3(0, ya, 0)
			var q0 := c + nr * lz + tg * lz + Vector3(0, yz, 0)
			var q1 := c + nr * lz - tg * lz + Vector3(0, yz, 0)
			_tubo("ferro", q0, q1, 0.18, cor, 4)
			_tubo("ferro", p0, q1, 0.12, cor, 4)
			_tubo("ferro", p1, q0, 0.12, cor, 4)
	# o mastro de cima e o "guarda-chuva" (12 braços) com os cabos
	_tubo("ferro", c + Vector3(0, h, 0), c + Vector3(0, h + 14.0, 0), 0.6, cor, 8)
	var rr := 17.0
	for k in 12:
		var a := k * TAU / 12.0
		var ponta := c + Vector3(cos(a) * rr, h + 7.5, sin(a) * rr)
		_tubo("ferro", c + Vector3(0, h + 13.0, 0), ponta, 0.22, cor, 4)
		_tubo("ferro", c + Vector3(cos(a) * b1, h, sin(a) * b1), ponta, 0.14, cor, 4)
		var a2 := (k + 1) * TAU / 12.0
		_tubo("ferro", ponta, c + Vector3(cos(a2) * rr, h + 7.5, sin(a2) * rr), 0.16, cor, 4)
		_tubo("ferro", ponta, ponta + Vector3(0, -12.0, 0), 0.03, Color(0.3, 0.3, 0.3), 3)          # os cabos dos paraquedas
		_b("vidro", ponta + Vector3(0, 0.3, 0), Vector3(0.4, 0.4, 0.4), Color(1.0, 0.3, 0.2))
	_b("vidro", c + Vector3(0, h + 14.4, 0), Vector3(0.6, 0.6, 0.6), Color(1.0, 0.2, 0.15))
	_letreiro("TORRE DO PARAQUEDAS · 1939", c + Vector3(0, 2.5, b0 + 0.5), 0.0, 64, 0.02, Color(0.9, 0.9, 0.85))

# a montanha-russa: caminho fechado (estádio: 2 retas e 2 curvas) com as alturas; os pilares de madeira, os trilhos,
# a estação e a colisão do leito (dá para andar nos trilhos: a subida é uma rampa)
const ALT_ESTACAO := 2.7

func _montanha_russa(c: Vector3) -> void:
	var meia := 46.0                                  # meia reta (x)
	var raio := 17.0                                  # curvas (z)
	var branco := Color(0.88, 0.86, 0.8)
	var trilho := Color(0.45, 0.42, 0.4)
	var per := 4.0 * meia + TAU * raio
	var npt := int(per / 4.0)
	var pts: Array = []
	for i in npt:
		var s := per * i / npt
		var p := Vector2.ZERO
		if s < 2.0 * meia:                                                # reta de cima (norte, -z): de -x para +x
			p = Vector2(-meia + s, -raio)
		elif s < 2.0 * meia + PI * raio:                                  # curva leste
			var a := (s - 2.0 * meia) / raio
			p = Vector2(meia + sin(a) * raio, -cos(a) * raio)
		elif s < 4.0 * meia + PI * raio:                                  # reta de baixo: de +x para -x
			p = Vector2(meia - (s - 2.0 * meia - PI * raio), raio)
		else:                                                             # curva oeste
			var a2 := (s - 4.0 * meia - PI * raio) / raio
			p = Vector2(-meia - sin(a2) * raio, cos(a2) * raio)
		# altura: a estação (3 m) no começo, a SUBIDA até 26 m (reta norte), a queda na curva e os morros
		var t := s / per
		var y := ALT_ESTACAO
		if t < 0.3:
			y = lerpf(ALT_ESTACAO, 26.0, t / 0.3)
		elif t < 0.36:
			y = lerpf(26.0, 2.5, smoothstep(0.0, 1.0, (t - 0.3) / 0.06))
		elif t < 0.72:
			var u := (t - 0.36) / 0.36
			y = 2.5 + (1.0 - u) * 15.0 * absf(sin(u * PI * 3.0)) + u * 0.5
		elif t < 0.78:
			y = lerpf(3.0, ALT_ESTACAO, (t - 0.72) / 0.06)
		pts.append(Vector3(p.x, y, p.y))
	for i in npt:
		var a: Vector3 = c + pts[i]
		var b: Vector3 = c + pts[(i + 1) % npt]
		var d := b - a
		var dh := Vector3(d.x, 0, d.z).normalized()
		var lado := Vector3(-dh.z, 0, dh.x)
		var bb := Basis.looking_at(d.normalized(), Vector3.UP)
		# o leito (dormentes) e os 2 trilhos; colisão do leito
		_b("madeira", (a + b) * 0.5, Vector3(2.6, 0.25, d.length() + 0.05), branco * 0.9, bb)
		for s2: float in [-0.6, 0.6]:
			_b("ferro", (a + b) * 0.5 + lado * s2 + Vector3(0, 0.2, 0), Vector3(0.18, 0.18, d.length() + 0.05), trilho, bb)
		_col((a + b) * 0.5 - bb.y * 0.1, Vector3(2.6, 0.3, d.length() + 0.1), bb)
		# o pilar (cavalete) a cada ponto: 2 postes, travessas a cada 4 m e o "X"
		var y: float = a.y
		if y > 1.2:
			for s3: float in [-1.6, 1.6]:
				_b("madeira", Vector3(a.x, y * 0.5 - 0.1, a.z) + lado * s3, Vector3(0.3, y, 0.3), branco)
			var yy := 3.5
			while yy < y - 0.5:
				_b("madeira", Vector3(a.x, yy, a.z), Vector3(3.6, 0.22, 0.22), branco * 0.95, Basis(Vector3.UP, atan2(-lado.z, lado.x)))
				yy += 4.0
			if i % 2 == 0 and y > 5.0:
				var p0 := Vector3(a.x, 0.5, a.z) - lado * 1.6
				var p1 := Vector3(a.x, y - 0.6, a.z) + lado * 1.6
				_tubo("madeira", p0, p1, 0.1, branco * 0.92, 4)
				_tubo("madeira", Vector3(a.x, 0.5, a.z) + lado * 1.6, Vector3(a.x, y - 0.6, a.z) - lado * 1.6, 0.1, branco * 0.92, 4)
	# os carrinhos parados na estação (vermelhos)
	for k in 3:
		_b("vidro", c + Vector3(-42.0 + k * 2.6, ALT_ESTACAO + 0.75, raio), Vector3(2.3, 0.9, 1.6), Color(0.8, 0.1, 0.1))
	# a ESTAÇÃO: plataforma na altura do leito, com escada (dá para subir nos trilhos)
	var pe := c + Vector3(-37.0, 0, raio + 3.8)
	var hp := ALT_ESTACAO + 0.12
	_bc("concreto", pe + Vector3(0, hp * 0.5, 0), Vector3(14.0, hp, 5.0), Color(0.62, 0.6, 0.57))
	_b("telhado", pe + Vector3(0, 6.5, -1.5), Vector3(15.0, 0.3, 9.0), Color(0.75, 0.15, 0.15))
	for s4: float in [-1.0, 1.0]:
		_b("madeira", pe + Vector3(s4 * 7.0, 4.6, 2.0), Vector3(0.3, 3.8, 0.3), branco)
	_escada("concreto", pe + Vector3(11.0, 0, 0.5), Vector2(-1, 0), 2.4, hp, 4.0, Color(0.6, 0.58, 0.55))
	_letreiro("MONTANHA-RUSSA · 1927", pe + Vector3(0, 7.4, 3.0), 0.0, 96, 0.025, Color(0.95, 0.9, 0.85))
	var topo: Vector3 = c + pts[int(npt * 0.29)]
	parque.pontos_altos["coney_montanha"] = T * (topo + Vector3(0, 0.3, 0))
	parque.pontos_altos["coney_estacao"] = T * (pe + Vector3(0, 2.8, 0))

# ---------------------------------------------------------------------------------------------------------------
# YANKEE STADIUM (+Z = sul: a casa base; o campo central fica ao norte)
# ---------------------------------------------------------------------------------------------------------------
func _yankee() -> void:
	alcance = 2500.0
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.5, 0.49, 0.47))
	var rc := 70.0                                     # campo (do centro até o muro)
	var rf := 110.0                                    # fachada
	var n := 40
	var calcario := Color(0.84, 0.8, 0.7)
	var portoes := [0, n / 4, 3 * n / 4]                # atrás da casa base e nas laterais (1ª e 3ª base)
	# o CAMPO: a pista de terra em volta, a grama, a terra do "infield", o losango, as bases e o montinho
	_cil("terra", Vector3(0, 0.05, 0), rc + 0.2, 0.1, n * 2, Color(0.55, 0.4, 0.28))
	_cil("gramado", Vector3(0, 0.08, 0), rc - 4.5, 0.12, n * 2, Color(0.25, 0.5, 0.2))
	var casa := Vector3(0, 0, 55.0)
	var monte := casa + Vector3(0, 0, -18.44)
	_cil("terra", monte + Vector3(0, 0.15, 0), 29.0, 0.06, 40, Color(0.6, 0.43, 0.3))
	_b("gramado", monte + Vector3(0, 0.2, 1.0), Vector3(25.0, 0.04, 25.0), Color(0.27, 0.53, 0.22), Basis(Vector3.UP, PI * 0.25))
	_cil("terra", casa + Vector3(0, 0.2, 0), 4.0, 0.06, 20, Color(0.6, 0.43, 0.3))
	_cil("terra", monte + Vector3(0, 0.3, 0), 2.7, 0.3, 16, Color(0.6, 0.43, 0.3), Basis.IDENTITY, 1.4)
	var d1 := Vector3(1, 0, -1).normalized()
	var d3 := Vector3(-1, 0, -1).normalized()
	for bp in [casa + d1 * 27.43, casa + d1 * 27.43 + d3 * 27.43, casa + d3 * 27.43]:
		_b("concreto", bp + Vector3(0, 0.26, 0), Vector3(0.4, 0.08, 0.4), Color(0.95, 0.95, 0.95), Basis(Vector3.UP, PI * 0.25))
	_b("concreto", casa + Vector3(0, 0.25, 0), Vector3(0.45, 0.05, 0.45), Color(0.95, 0.95, 0.95))
	for dd: Vector3 in [d1, d3]:
		_b("concreto", casa + dd * 48.5 + Vector3(0, 0.15, 0), Vector3(0.1, 0.03, 97.0), Color(0.95, 0.95, 0.95), Basis(Vector3.UP, atan2(dd.x, dd.z)))
		_cil("ferro", casa + dd * 97.0 + Vector3(0, 9.0, 0), 0.2, 18.0, 6, Color(0.95, 0.85, 0.2))                    # postes de foul
	# as ARQUIBANCADAS (40 fatias): "infield" alto (3 m -> 30 m) e as do fundo baixas ("bleachers"); o muro azul do
	# campo, a fachada de calcário com os arcos; os portões (sem fachada nem muro: passa por baixo da arquibancada)
	for k in n:
		var a := (k + 0.5) * TAU / n
		var u := Vector3(sin(a), 0, cos(a))
		var bg := Basis(Vector3.UP, a)
		var fundo := absf(wrapf(a, -PI, PI)) > 2.1
		var r1 := 92.0 if fundo else 106.0
		var h := 12.0 if fundo else 30.0
		var r0 := rc + 0.5
		var incl := atan2(h - 3.0, r1 - r0)
		var lp := Vector2(r1 - r0, h - 3.0).length()
		var bs := bg * Basis(Vector3.RIGHT, -incl)
		for pz in 3:                                   # em 3 pedaços (a fatia abre para fora: sem frestas na colisão)
			var ta := pz / 3.0
			var tb := (pz + 1) / 3.0
			var meio := u * lerpf(r0, r1, (ta + tb) * 0.5) + Vector3(0, lerpf(3.0, h, (ta + tb) * 0.5), 0)
			var ch := 2.0 * lerpf(r0, r1, tb) * sin(PI / n) + 0.12
			_b("concreto", meio, Vector3(ch, 0.5, lp / 3.0 + 0.05), Color(0.55, 0.55, 0.56), bs)
			_col(meio, Vector3(ch, 0.5, lp / 3.0 + 0.05), bs)
		var nf := int(lp / 2.2)
		for f in nf:
			var t := (f + 0.5) / nf
			var rr := lerpf(r0, r1, t)
			var c2 := 2.0 * rr * sin(PI / n) + 0.1
			_b("concreto", u * rr + Vector3(0, lerpf(3.0, h, t) + 0.35, 0), Vector3(c2, 0.45, 0.8), AZUL_YANKEE * (0.95 + 0.1 * (f % 2)), bg)
		if not fundo:
			# a faixa do 2º anel (o "balcão") e o alto plano até a fachada
			_b("concreto", u * lerpf(r0, r1, 0.45) + Vector3(0, lerpf(3.0, h, 0.45) + 1.2, 0), Vector3(2.0 * lerpf(r0, r1, 0.45) * sin(PI / n) + 0.1, 1.6, 0.6), Color(0.85, 0.85, 0.83), bg)
			_bc("concreto", u * (r1 + rf) * 0.5 + Vector3(0, h - 0.25, 0), Vector3(2.0 * (r1 + rf) * 0.5 * sin(PI / n) + 0.2, 0.5, rf - r1), Color(0.5, 0.5, 0.5), bg)
		var portao := portoes.has(k)
		if not portao:
			_bc("concreto", u * (rc + 0.25) + Vector3(0, 1.5, 0), Vector3(2.0 * rc * sin(PI / n) + 0.1, 3.0, 0.5), AZUL_YANKEE * 0.8, bg)
		# a fachada (calcário, com os arcos escuros)
		var hfac := 16.0 if fundo else 32.0
		var cf := 2.0 * rf * sin(PI / n) + 0.15
		if portao:
			for s: float in [-1.0, 1.0]:
				_bc("pedra", u * rf + bg * Vector3(s * (cf * 0.5 - 1.0), 0, 0) + Vector3(0, hfac * 0.5, 0), Vector3(2.0, hfac, 1.4), calcario, bg)
			_bc("pedra", u * rf + Vector3(0, hfac - 6.0, 0), Vector3(cf, 12.0, 1.4), calcario, bg)
			_b("vidro_escuro", u * (rf + 0.72) + Vector3(0, hfac - 6.0, 0), Vector3(cf - 6.0, 6.0, 0.08), Color(0.12, 0.13, 0.14), bg)
		else:
			_bc("pedra", u * rf + Vector3(0, hfac * 0.5, 0), Vector3(cf, hfac, 1.4), calcario, bg)
			for f in 3:
				var x := (f - 1) * cf / 3.0
				_b("vidro_escuro", u * (rf + 0.72) + bg * Vector3(x, 0, 0) + Vector3(0, hfac * 0.42, 0), Vector3(cf / 3.0 - 1.6, hfac * 0.62, 0.08), Color(0.12, 0.13, 0.14), bg)
				for g in 5:
					var ang := PI * (g + 0.5) / 5.0
					var pa := u * (rf + 0.78) + bg * Vector3(x + cos(ang) * (cf / 6.0 - 0.8), 0, 0) + Vector3(0, hfac * 0.73 + sin(ang) * 1.6, 0)
					_b("pedra", pa, Vector3(0.9, 0.5, 0.2), calcario * 1.06, bg * Basis(Vector3.BACK, ang - PI * 0.5))
		_b("pedra", u * (rf + 0.4) + Vector3(0, hfac + 0.4, 0), Vector3(cf + 0.3, 0.8, 2.2), calcario * 1.05, bg)
		# o TETO com o FRISO branco (só no "infield")
		if not fundo:
			var rt0 := 95.0
			_b("concreto", u * (rt0 + rf) * 0.5 + Vector3(0, 40.0, 0), Vector3(2.0 * (rt0 + rf) * 0.5 * sin(PI / n) + 0.2, 0.6, rf - rt0), Color(0.75, 0.75, 0.74), bg)
			_b("concreto", u * (rf - 1.0) + Vector3(0, 36.0, 0), Vector3(0.6, 8.0, 0.6), Color(0.85, 0.85, 0.84), bg)
			var cfr := 2.0 * rt0 * sin(PI / n) + 0.1
			_b("concreto", u * rt0 + Vector3(0, 39.2, 0), Vector3(cfr, 1.0, 0.4), Color(0.95, 0.95, 0.94), bg)
			for g in 4:
				var x2 := -cfr * 0.5 + (g + 0.5) * cfr / 4.0
				_b("concreto", u * rt0 + bg * Vector3(x2 - cfr / 8.0, 0, 0) + Vector3(0, 37.6, 0), Vector3(0.18, 2.4, 0.3), Color(0.95, 0.95, 0.94), bg)
				for e in 4:
					var ang2 := PI * (e + 0.5) / 4.0
					_b("concreto", u * rt0 + bg * Vector3(x2 + cos(ang2) * cfr / 8.0, 0, 0) + Vector3(0, 38.7 - sin(ang2) * 1.2, 0), Vector3(cfr / 9.0, 0.16, 0.3), Color(0.95, 0.95, 0.94), bg * Basis(Vector3.BACK, PI * 0.5 - ang2))
			if k % 5 == 2:                                                      # torres de luz
				_b("ferro", u * (rt0 + 3.0) + Vector3(0, 44.0, 0), Vector3(6.0, 4.0, 0.6), Color(0.3, 0.3, 0.32), bg)
				_b("vidro", u * (rt0 + 2.65) + Vector3(0, 44.0, 0), Vector3(5.6, 3.6, 0.1), Color(1.0, 1.0, 0.92), bg)
				_tubo("ferro", u * (rt0 + 3.0) + Vector3(0, 40.0, 0), u * (rt0 + 3.0) + Vector3(0, 42.0, 0), 0.2, Color(0.3, 0.3, 0.32), 4)
	# o PLACAR no campo central (telão virado para o campo) e as letras douradas em cima do portão principal
	var up := Vector3(0, 0, -98.0)
	for s: float in [-1.0, 1.0]:
		_bc("ferro", up + Vector3(s * 12.0, 12.0, 0), Vector3(1.2, 24.0, 1.2), Color(0.2, 0.2, 0.22))
	_bc("ferro", up + Vector3(0, 28.0, 0), Vector3(36.0, 14.0, 2.0), Color(0.08, 0.08, 0.09))
	var ct := _c("telao")
	ct.ao = 0.0
	ct.caixa(up + Vector3(0, 28.0, 1.05), Vector3(32.0, 11.0, 0.1), Color(0.37, 32.0 / 64.0, 11.0 / 64.0))
	_letreiro("YANKEES", up + Vector3(0, 36.4, 1.1), 0.0, 128, 0.04, Color(0.95, 0.95, 0.95))
	_letreiro("YANKEE STADIUM", Vector3(0, 27.0, rf + 1.6), 0.0, 128, 0.07, OURO)
	var ug := Vector3(sin(PI / n), 0, cos(PI / n))           # o meio do portão atrás da casa base (fatia 0)
	parque.pontos_altos["yankee_campo"] = T * (monte + Vector3(0, 0.6, 0))
	parque.pontos_altos["yankee_portao"] = T * (ug * (rf + 4.0) + Vector3(0, 0.1, 0))
	parque.pontos_altos["yankee_tunel"] = T * (ug * (rc - 6.0) + Vector3(0, 0.1, 0))

# ---------------------------------------------------------------------------------------------------------------
# UNISPHERE (Flushing Meadows · Queens): o globo de aço da Feira Mundial de 1964
# ---------------------------------------------------------------------------------------------------------------
# os continentes (células de 10° x 10°: 36 colunas de -180 a 180, 17 linhas de 90N a -80S)
const TERRAS := [
	"............###.....................",
	"......#####.####....##.#######......",
	".#########..###...##################",
	"..#########.......##################",
	"....#######......###################",
	".....######......########.#######...",
	"......####.......#########.######...",
	".......###......##########.####.....",
	"..........##.....######.....##.##...",
	"..........#####...#####......#.###..",
	"..........#####...#####......#####..",
	"...........###....###........#####..",
	"...........###.....#.........####...",
	"...........##...................#.#.",
	"...........#........................",
	"............#.......................",
	"####################################",
]

func _unisphere() -> void:
	alcance = 2500.0
	var aco := Color(0.78, 0.8, 0.82)
	_piso("pedra_chao", -W * 0.5, -D * 0.5, W * 0.5, D * 0.5, Color(0.56, 0.55, 0.53))
	# o espelho d'água: borda de granito, a água e os jatos
	var rp := 46.0
	_anel("granito", Vector3(0, 0.35, 0), rp, 48, 1.2, 0.7, Color(0.55, 0.54, 0.52))
	_anel_col(Vector3(0, 0.35, 0), rp, 24, 1.2, 0.7)
	_cil("agua_fonte", Vector3(0, 0.3, 0), rp - 0.5, 0.1, 48, Color(1, 1, 1))
	for k in 32:
		var a := k * TAU / 32.0
		_cil("agua_fonte", Vector3(cos(a) * (rp - 5.0), 2.3, sin(a) * (rp - 5.0)), 0.22, 4.0, 6, Color(1, 1, 1), Basis.IDENTITY, 0.04)
	# a base: a ilhota de concreto, o tripé e a coluna
	_cil("concreto", Vector3(0, 0.3, 0), 9.0, 0.6, 24, Color(0.62, 0.61, 0.6))
	var yc := 24.5
	var rg := 18.5
	_cil("aco", Vector3(0, 3.5, 0), 1.3, 6.4, 12, aco, Basis.IDENTITY, 0.9)
	for k in 3:
		var a := k * TAU / 3.0
		_tubo("aco", Vector3(cos(a) * 7.0, 0.6, sin(a) * 7.0), Vector3(0, 6.6, 0), 0.55, aco, 8)
		_col(Vector3(cos(a) * 6.5, 1.0, sin(a) * 6.5), Vector3(1.2, 2.0, 1.2))
	_col(Vector3(0, 3.2, 0), Vector3(3.0, 6.4, 3.0))
	# o GLOBO inclinado (23,5°): meridianos, paralelos e as placas dos continentes
	var bg := Basis(Vector3.BACK, 0.41)
	var cg := Vector3(0, yc, 0)
	var esf := func(lat: float, lon: float, rr: float) -> Vector3:
		return cg + bg * Vector3(cos(lat) * cos(lon) * rr, sin(lat) * rr, cos(lat) * sin(lon) * rr)
	for m in 24:
		var lon := m * TAU / 24.0
		for i in 12:
			var la0 := -PI * 0.5 + i * PI / 12.0
			var la1 := la0 + PI / 12.0
			_tubo("aco", esf.call(la0, lon, rg), esf.call(la1, lon, rg), 0.16, aco, 4)
	for p in range(-5, 6):
		var lat := p * PI / 12.0
		for i in 24:
			var lo0 := i * TAU / 24.0
			_tubo("aco", esf.call(lat, lo0, rg), esf.call(lat, lo0 + TAU / 24.0, rg), 0.14, aco, 4)
	var cp := _c("aco")
	for row in TERRAS.size():
		var linha: String = TERRAS[row]
		for col in linha.length():
			if linha[col] != "#":
				continue
			var la_a := deg_to_rad(90.0 - row * 10.0)
			var la_b := la_a - deg_to_rad(10.0)
			var lo_a := deg_to_rad(-180.0 + col * 10.0)
			var lo_b := lo_a + deg_to_rad(10.0)
			var q0: Vector3 = esf.call(la_a, lo_a, rg + 0.25)
			var q1: Vector3 = esf.call(la_a, lo_b, rg + 0.25)
			var q2: Vector3 = esf.call(la_b, lo_b, rg + 0.25)
			var q3: Vector3 = esf.call(la_b, lo_a, rg + 0.25)
			var nn := ((q0 + q2) * 0.5 - cg).normalized()
			var cor := aco * (1.05 + 0.04 * float((row + col) % 2))
			cp._quad(q0, q1, q2, q3, nn, cor, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
			cp._quad(q0, q3, q2, q1, -nn, cor * 0.8, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0))
	# os 3 anéis das órbitas (cada um com o satélite)
	for e in [[23.0, 0.5, 0.0], [21.5, -0.6, 1.2], [24.5, 0.25, 2.3]]:
		var ro: float = e[0]
		var ba := Basis(Vector3.UP, float(e[2])) * Basis(Vector3.RIGHT, float(e[1]))
		for i in 36:
			var a0 := i * TAU / 36.0
			var a1 := a0 + TAU / 36.0
			_tubo("aco", cg + ba * Vector3(cos(a0) * ro, 0, sin(a0) * ro), cg + ba * Vector3(cos(a1) * ro, 0, sin(a1) * ro), 0.18, aco, 4)
		_cil("aco", cg + ba * Vector3(ro, 0, 0), 0.7, 1.0, 8, aco * 1.05)
		_tubo("aco", cg + ba * Vector3(ro, 0, 0), cg + bg * (ba * Vector3(1, 0, 0)).normalized() * rg, 0.08, aco, 3)
	# em volta: bancos, postes e as árvores dos cantos
	for k in 16:
		var a := (k + 0.5) * TAU / 16.0
		_banco(Vector3(cos(a) * (rp + 5.0), 0, sin(a) * (rp + 5.0)), -a - PI * 0.5)
		if k % 2 == 0:
			_poste(Vector3(cos(a + 0.2) * (rp + 8.0), 0, sin(a + 0.2) * (rp + 8.0)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for k in 4:
				var p := Vector3(sx * (W * 0.5 - 8.0 - (k % 2) * 9.0), 0, sz * (D * 0.5 - 8.0 - (k / 2) * 9.0))
				_arvore(["freixo_m", "olmo_3", "carvalho_m2", "freixo_m2"][k], p, 0.9)
	_letreiro("UNISPHERE · 1964", Vector3(0, 1.4, rp + 0.8), 0.0, 64, 0.02, Color(0.25, 0.25, 0.25))
	parque.pontos_altos["unisphere"] = T * Vector3(0, 0.1, rp + 6.0)
