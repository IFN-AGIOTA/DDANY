extends "res://mundo/local.gd"
# LOCAIS ESPECIAIS NOVOS (0.78): DELEGACIA, ESCOLA, ESTAÇÃO DO METRÔ (elevada) e QUARTEL DA GUARDA NACIONAL.
# Usa as mesmas peças do mundo/local.gd (paredes com vãos, lajes, escadas, móveis, carros, sacos de areia...) e funciona
# igual: tudo vira uma malha + um corpo de colisão, loot próprio (tabelas "delegacia_*", "escola_*", "metro_*",
# "quartel_*" em mundo/loot_mundo.gd), pontos de infectados e lugares altos para vigiar.
# Coordenadas LOCAIS: x = ao longo da frente, z = profundidade, +Z = FRENTE (o lado da rua), y = 0 no piso.
# Mexa AQUI para: a planta, os cômodos, os móveis e os enfeites dos 4 locais novos. Onde ficam: mundo/locais.gd.

const TIJOLO := Color(0.55, 0.33, 0.25)
const AZUL_POLICIA := Color(0.1, 0.18, 0.4)
const VERDE_EL := Color(0.24, 0.32, 0.27)        # ferro pintado do elevado de Nova York
const INOX := Color(0.68, 0.7, 0.72)
const AREIA := Color(0.62, 0.55, 0.4)            # HESCO / lona do exército
const PICHE := Color(0.75, 0.08, 0.06)           # tinta spray vermelha

# ======================================================================================================
# DELEGACIA (56 x 44): prédio de tijolo de 2 andares (40 x 20) com as lâmpadas verdes na porta, recepção com balcão
# alto, sala dos investigadores, vestiário, CELAS (uma trancada, com um infectado preso), ARSENAL, sala de provas,
# interrogatório; em cima, sala do delegado (cofre), central de rádio, dormitório, arquivo e copa; TELHADO com
# ninho de sacos de areia. Fora: estacionamento das viaturas (porta-malas com loot), barreiras e sacos na entrada,
# furgão da tática no pátio. Na fachada, a pichação: "NÃO SÃO MONSTROS. SÃO O QUE SOBROU."
# ======================================================================================================
func _delegacia() -> void:
	var B := Rect2(-20, -20, 40, 20)
	var cor_d := Color(0.8, 0.8, 0.74)
	var bege := Color(0.78, 0.74, 0.62)
	dentro = B.grow(-ESP * 0.5)
	var xi := -19.85
	var xf := 19.85
	# ---- chão de fora ----
	_chao(Rect2(-28, 0, 56, 4), CONCRETO * 1.05)
	_chao(Rect2(-28, 4, 56, 18), ASFALTO)
	_chao(Rect2(-28, -22, 56, 2), CONCRETO_ESC)
	_chao(Rect2(20, -20, 8, 20), ASFALTO * 1.1)
	_chao(Rect2(-28, -20, 8, 20), CONCRETO_ESC)
	_vagas(-26.0, -6.6, 6.5, 5.0)
	_vagas(6.6, 26.0, 6.5, 5.0)
	_vagas(-26.0, -6.6, 16.5, 5.0)
	_vagas(6.6, 26.0, 16.5, 5.0)
	# ---- paredes de fora (2 andares) ----
	var porta_frente := [18.0, 22.0, 0.0, 3.0]
	var frente0 := _janelas(40.0, 3.2, 1.6, 1.0, 2.6, [porta_frente])
	var dir0 := _janelas(20.0, 3.2, 1.4, 1.2, 2.6, [_porta(9.5)], 0.6)
	var fundo0 := [_porta(4.0), [10.0, 11.2, 2.0, 2.8, "janela"], [22.0, 23.2, 2.0, 2.8, "janela"]]
	var esq0 := _janelas(20.0, 3.2, 1.4, 1.2, 2.6, [_porta(10.5)], 0.6)
	_perimetro(B, 0.0, ANDAR, TIJOLO, cor_d, [frente0, dir0, fundo0, esq0])
	var j1 := [_janelas(40.0, 3.2, 1.6, 1.0, 2.6, []), _janelas(20.0, 3.2, 1.6, 1.0, 2.6, []), _janelas(40.0, 3.2, 1.6, 1.0, 2.6, [], 0.7), _janelas(20.0, 3.2, 1.6, 1.0, 2.6, [])]
	_perimetro(B, ANDAR, ANDAR, TIJOLO, cor_d, j1)
	fora.caixa(Vector3(0, ANDAR - 0.1, 0.17), Vector3(40.4, 0.25, 0.1), bege)                          # friso de pedra
	fora.caixa(Vector3(0, ANDAR * 2.0 - 0.15, 0.17), Vector3(40.4, 0.3, 0.12), bege)
	# ---- lajes, escadas e telhado ----
	var buraco_a := Rect2(-2.2, -18.0, 1.4, 7.0)
	var buraco_b := Rect2(0.8, -18.0, 1.4, 7.0)
	piso.caixa(Vector3(0, 0.02, -10), Vector3(39.7, 0.04, 19.7), Color(0.66, 0.66, 0.62), Basis.IDENTITY, true)
	_laje(B.grow(-0.05), PE, LAJE, [buraco_a], Color(0.6, 0.55, 0.45))
	_laje(B.grow(-0.05), ANDAR + PE, LAJE, [buraco_b], CONCRETO, true)
	var yt := ANDAR * 2.0
	_escada(Vector2(-1.5, -11.0), Vector2(0, -1), 1.4, 0.0, ANDAR, 7.0, CONCRETO, 1)
	_escada(Vector2(1.5, -18.0), Vector2(0, 1), 1.4, ANDAR, ANDAR, 7.0, CONCRETO, -1)
	_grade(Vector2(-0.8, -18.0), Vector2(-0.8, -11.0), ANDAR)
	_grade(Vector2(-2.2, -18.0), Vector2(-2.2, -11.0), ANDAR)
	_grade(Vector2(-2.2, -11.0), Vector2(-0.8, -11.0), ANDAR)
	_grade(Vector2(0.8, -18.0), Vector2(0.8, -11.0), yt)
	_grade(Vector2(2.2, -18.0), Vector2(2.2, -11.0), yt)
	_grade(Vector2(0.8, -18.0), Vector2(2.2, -18.0), yt)
	_mureta(B.grow(ESP * 0.5), yt, 1.1, [])
	var casa := Rect2(-0.2, -18.8, 3.2, 8.4)
	_perimetro(casa, yt, 2.8, CONCRETO, CONCRETO, [[[0.3, 2.9, 0.0, 2.5]], [], [], []], fora)
	fora.caixa(Vector3(casa.get_center().x, yt + 2.95, casa.get_center().y), Vector3(casa.size.x + 0.5, 0.3, casa.size.y + 0.5), CONCRETO_ESC)
	_col(Vector3(casa.get_center().x, yt + 2.95, casa.get_center().y), Vector3(casa.size.x + 0.5, 0.3, casa.size.y + 0.5))
	# telhado: ninho de sacos de areia virado para o estacionamento, caixas de munição, antena, ar-condicionado
	_sacos(Vector2(-9.0, -1.2), Vector2(-3.0, -1.2), 3, yt)
	_sacos(Vector2(-9.0, -1.2), Vector2(-9.0, -3.6), 3, yt)
	_sacos(Vector2(13.0, -1.2), Vector2(18.5, -1.2), 3, yt)
	_caixa_militar(Vector3(-6.0, yt, -3.2), 0.2, "armas_policia")
	for p in [Vector2(-14, -14), Vector2(10, -15), Vector2(15, -8)]:
		_bx(fora, Vector3(p.x, yt + 0.7, p.y), Vector3(2.2, 1.4, 1.6), Color(0.6, 0.62, 0.62))
	fora.cilindro(Vector3(-17, yt + 3.0, -17), 0.07, 6.0, 5, METAL_ESC)
	fora.caixa(Vector3(-17, yt + 5.0, -17), Vector3(1.2, 0.05, 0.05), METAL_ESC)
	_ponto(Vector3(-6, yt, -6), "telhado")
	_ponto(Vector3(12, yt, -5), "telhado")
	# ---- TÉRREO: paredes de dentro ----
	_parede(paredes, Vector2(xi, -8), Vector2(xf, -8), 0.0, PE, DIV, Color.WHITE, cor_d, [_porta(6.85), [16.85, 22.85, 0.0, 99.0], _porta(32.85)])
	_parede(paredes, Vector2(xi, -11), Vector2(xf, -11), 0.0, PE, DIV, Color.WHITE, cor_d, [_porta(3.85), _porta(11.85, 1.3), [16.25, 23.45, 0.0, 99.0], _porta(27.85), _porta(35.85)])
	for x in [-12.0, -4.0, 4.0]:
		_parede(paredes, Vector2(x, -19.85), Vector2(x, -11), 0.0, PE, DIV, Color.WHITE, cor_d, [])
	_parede(paredes, Vector2(12, -19.85), Vector2(12, -11), 0.0, PE, DIV, Color.WHITE, cor_d, [[2.5, 5.5, 1.0, 2.2, "janela"]])     # "espelho" do interrogatório
	for x in [-6.0, 6.0]:
		_parede(paredes, Vector2(x, -8), Vector2(x, -0.15), 0.0, PE, DIV, Color.WHITE, cor_d, [])
	# recepção: balcão alto, bancos, bandeira, sacos de areia na porta (resistiram aqui no começo)
	_movel("balcao", Vector3(-1.25, 0, -5.0), 0.0, "balcao", "RECEPÇÃO")
	_movel("balcao", Vector3(1.25, 0, -5.0), 0.0, "delegacia_escritorio", "RECEPÇÃO")
	_bx(resto, Vector3(0, 1.25, -5.45), Vector3(5.0, 0.12, 0.3), MADEIRA_CLARA * 0.8)
	_movel("cadeiras_espera", Vector3(-4.6, 0, -1.0), PI)
	_movel("cadeiras_espera", Vector3(4.6, 0, -1.0), PI)
	_movel("planta", Vector3(-5.4, 0, -7.3), 0.0)
	fora.cilindro(Vector3(5.4, 1.4, -7.4), 0.025, 2.8, 4, METAL)
	resto.caixa(Vector3(5.4, 2.3, -7.05), Vector3(0.02, 0.8, 0.7), AZUL_POLICIA)
	_movel("barricada", Vector3(-3.4, 0, -0.9), 0.0)
	_pontos_em(Rect2(-5.5, -7.5, 11, 5), 0.0, 3, "recepcao")
	# sala dos investigadores
	for p in [Vector2(-16.5, -5.6), Vector2(-11.0, -5.6), Vector2(-16.5, -2.4), Vector2(-11.0, -2.4)]:
		_movel("mesa_escritorio", Vector3(p.x, 0, p.y), 0.0, "delegacia_escritorio")
	for z in [-7.0, -6.3, -5.6]:
		_movel("arquivo", Vector3(-19.5, 0, z), PI * 0.5, "delegacia_escritorio")
	_movel("quadro", Vector3(-7.5, 1.6, -7.8), 0.0)
	_pontos_em(Rect2(-19.5, -7.5, 13, 7), 0.0, 2, "investigadores")
	# vestiário: armários dos policiais e banco
	_armarios(Vector2(6.6, -7.55), Vector2(19.4, -7.55), 0.0, "delegacia_vestiario", Color(0.3, 0.36, 0.42))
	_bx(resto, Vector3(13.0, 0.25, -4.5), Vector3(8.0, 0.5, 0.45), MADEIRA_CLARA)
	_movel("pia", Vector3(19.3, 0, -2.0), -PI * 0.5, "banheiro")
	_pontos_em(Rect2(6.5, -3.9, 12.5, 3.2), 0.0, 2, "vestiario")
	# celas (3): grades de ferro na frente; a do meio trancada (tem um infectado lá dentro)
	_parede(paredes, Vector2(-17.2, -19.85), Vector2(-17.2, -15.5), 0.0, PE, DIV, CONCRETO, CONCRETO, [])
	_parede(paredes, Vector2(-14.6, -19.85), Vector2(-14.6, -15.5), 0.0, PE, DIV, CONCRETO, CONCRETO, [])
	_barras(Vector2(-19.85, -15.5), Vector2(-17.2, -15.5), 0.0, 2.6, Vector2(0.9, 1.9))
	_barras(Vector2(-17.2, -15.5), Vector2(-14.6, -15.5), 0.0, 2.6)
	_barras(Vector2(-14.6, -15.5), Vector2(-12.07, -15.5), 0.0, 2.6, Vector2(0.8, 1.8))
	for x in [-18.5, -15.9, -13.3]:
		_bx(resto, Vector3(x, 0.25, -19.2), Vector3(2.0, 0.5, 0.9), CONCRETO * 1.1)                       # cama de concreto
		resto.caixa(Vector3(x, 0.55, -19.2), Vector3(1.8, 0.1, 0.8), Color(0.3, 0.32, 0.36))
		_movel("vaso", Vector3(x + 0.85, 0, -16.2), PI)
	_loot(Vector3(-18.5, 0.1, -18.2), "lixo", "CELA", Vector2i(3, 2))
	_loot(Vector3(-13.3, 0.1, -18.2), "lixo", "CELA", Vector2i(3, 2))
	_texto(Vector3(-15.9, 1.7, -19.82), 0.0, "|||| |||| |||| ||", Color(0.85, 0.85, 0.8), 40)
	# arsenal: armários de armas, caixa de munição, grade na porta
	for x in [-10.4, -8.0, -5.6]:
		_movel("armario_armas", Vector3(x, 0, -19.55), 0.0, "delegacia_arsenal", "ARMÁRIO DO ARSENAL")
	_movel("armario_armas", Vector3(-11.6, 0, -15.0), PI * 0.5, "armas_policia")
	_caixa_militar(Vector3(-6.0, 0, -13.2), 0.0, "delegacia_arsenal")
	_barras(Vector2(-8.65, -11.12), Vector2(-7.35, -11.12), 0.0, 2.5, Vector2(0.05, 1.25))    # portão de grade aberto
	# sala de provas
	_movel("prateleira", Vector3(6.0, 0, -19.5), 0.0, "delegacia_provas", "PRATELEIRA DE PROVAS")
	_movel("prateleira", Vector3(10.0, 0, -19.5), 0.0, "delegacia_provas", "PRATELEIRA DE PROVAS")
	_movel("prateleira", Vector3(11.55, 0, -15.0), -PI * 0.5, "delegacia_provas", "PRATELEIRA DE PROVAS")
	_movel("caixas", Vector3(5.2, 0, -15.0), PI * 0.5, "delegacia_provas", "CAIXAS DE PROVAS")
	# interrogatório: mesa de ferro, 2 cadeiras, luminária pendurada
	_bx(resto, Vector3(16.0, 0.75, -15.5), Vector3(1.6, 0.06, 0.9), METAL)
	_col(Vector3(16.0, 0.4, -15.5), Vector3(1.6, 0.8, 0.9))
	_movel("cadeira", Vector3(16.0, 0, -16.5), 0.0)
	_movel("cadeira", Vector3(16.0, 0, -14.5), PI)
	resto.cilindro(Vector3(16.0, 3.2, -15.5), 0.25, 0.15, 10, METAL_ESC)
	_movel("arquivo", Vector3(19.5, 0, -18.5), -PI * 0.5, "delegacia_escritorio")
	_pontos_em(Rect2(-19.5, -10.8, 39, 2.6), 0.0, 4, "corredor")
	_pontos_em(Rect2(4.5, -18.5, 7, 5), 0.0, 2, "provas")
	_bagunca(Rect2(-19.5, -19.5, 39, 19), 0.0, 40)
	# ---- 1º ANDAR ----
	var y1 := ANDAR
	_parede(paredes, Vector2(xi, -11), Vector2(xf, -11), y1, PE, DIV, Color.WHITE, cor_d, [_porta(7.85), [16.25, 23.45, 0.0, 99.0], _porta(31.85)])
	for x in [-4.0, 4.0]:
		_parede(paredes, Vector2(x, -19.85), Vector2(x, -11), y1, PE, DIV, Color.WHITE, cor_d, [])
	for x in [-6.0, 6.0]:
		_parede(paredes, Vector2(x, -11), Vector2(x, -0.15), y1, PE, DIV, Color.WHITE, cor_d, [_porta(5.5)])
	# sala do delegado: mesa, estante, sofá, cofre e a pichação
	_movel("mesa_escritorio", Vector3(-13.0, y1, -6.5), 0.0, "delegacia_escritorio")
	_movel("estante_livros", Vector3(-13.0, y1, -10.6), 0.0)
	_movel("arquivo", Vector3(-19.5, y1, -8.5), PI * 0.5, "escritorio")
	_movel("sofa", Vector3(-11.0, y1, -0.75), PI)
	_movel("planta", Vector3(-7.0, y1, -10.3), 0.0)
	_bx(resto, Vector3(-19.2, y1 + 0.55, -2.0), Vector3(0.9, 1.1, 0.9), Color(0.2, 0.22, 0.2))            # cofre
	resto.cilindro(Vector3(-18.74, y1 + 0.65, -2.0), 0.12, 0.04, 10, METAL, Basis(Vector3.FORWARD, PI * 0.5))
	_loot(Vector3(-18.3, y1 + 0.1, -2.0), "cofre", "COFRE DO DELEGADO", Vector2i(4, 3))
	_pontos_em(Rect2(-19.5, -10.5, 13, 9.5), y1, 2, "delegado")
	# central de rádio / sala de operações
	_movel("bancada", Vector3(0.0, y1, -10.55), 0.0, "central_radio", "CENTRAL DE RÁDIO")
	for x in [-1.0, 0.6]:
		resto.caixa(Vector3(x, y1 + 1.15, -10.6), Vector3(0.6, 0.35, 0.4), Moveis.PRETO)
	for p in [Vector2(-3.5, -6.8), Vector2(2.6, -6.8), Vector2(-3.5, -3.0), Vector2(2.6, -3.0)]:
		_movel("mesa_escritorio", Vector3(p.x, y1, p.y), 0.0, "escritorio")
	_pontos_em(Rect2(-5.5, -10.5, 11, 9.5), y1, 2, "operacoes")
	# dormitório
	for x in [8.2, 11.0, 13.8, 16.6]:
		_movel("cama", Vector3(x, y1, -9.75), 0.0, "delegacia_vestiario", "CAMA")
	_movel("guarda_roupa", Vector3(19.5, y1, -4.0), -PI * 0.5, "delegacia_vestiario", "ARMÁRIO")
	_movel("colchao", Vector3(10.0, y1, -3.0), 0.3)
	_pontos_em(Rect2(6.5, -7.5, 13, 6.5), y1, 2, "dormitorio")
	# arquivo morto
	var x2 := -19.0
	while x2 < -5.5:
		_movel("arquivo", Vector3(x2, y1, -19.5), 0.0, "escritorio")
		_movel("arquivo", Vector3(x2, y1, -15.2), 0.0 if int(x2) % 2 == 0 else PI, "escritorio")
		x2 += 1.4
	_movel("caixas", Vector3(-9.0, y1, -12.3), 0.0, "delegacia_provas", "CAIXAS DO ARQUIVO")
	# copa
	_movel("bancada", Vector3(7.0, y1, -19.5), 0.0, "casa_cozinha", "ARMÁRIO DA COPA")
	_movel("geladeira", Vector3(9.6, y1, -19.5), 0.0, "geladeira")
	_movel("mesa_jantar", Vector3(13.0, y1, -15.5), 0.0)
	_movel("sofa", Vector3(17.5, y1, -19.3), 0.0)
	_pontos_em(Rect2(-19.5, -18.6, 13.5, 2.6), y1, 2, "arquivo")
	_pontos_em(Rect2(4.5, -18.5, 15, 6.5), y1, 2, "copa")
	_bagunca(Rect2(-19.5, -19.5, 39, 19), y1, 30)
	# ---- fachada: marquise, lâmpadas verdes, letreiro e a pichação ----
	fora.caixa(Vector3(0, 3.35, 1.25), Vector3(7.0, 0.3, 2.5), CONCRETO_ESC)
	_col(Vector3(0, 3.35, 1.25), Vector3(7.0, 0.3, 2.5))
	for x in [-3.2, 3.2]:
		fora.cilindro(Vector3(x, 1.0, 0.45), 0.05, 2.0, 5, METAL_ESC)
		fora.cilindro(Vector3(x, 2.3, 0.45), 0.2, 0.45, 10, Color(0.2, 0.75, 0.3))
	fora.caixa(Vector3(0, 4.05, 0.22), Vector3(12.0, 0.9, 0.12), AZUL_POLICIA)
	_texto(Vector3(0, 4.05, 0.3), 0.0, "DELEGACIA · 41º DISTRITO", Color(0.92, 0.92, 0.9), 56)
	_texto(Vector3(-12.0, 2.0, 0.19), 0.0, "NÃO SÃO MONSTROS.\nSÃO O QUE SOBROU.", PICHE, 52)
	# ---- fora: viaturas, furgão da tática, barreiras e sacos de areia na entrada ----
	_viatura(Vector2(-17.6, 9.0), 0.04)
	_viatura(Vector2(-9.4, 19.0), PI - 0.05)
	_viatura(Vector2(11.0, 9.5), 0.35)
	_viatura(Vector2(22.2, 19.0), PI + 0.1)
	_carro(Vector2(3.5, 15.5), 1.3, Color(0.2, 0.2, 0.22), "carro", true)
	_sacos(Vector2(-5.5, 2.4), Vector2(-1.6, 2.4))
	_sacos(Vector2(1.6, 2.4), Vector2(5.5, 2.4))
	for k in 3:
		_barreira(Vector2(-7.0 + k * 7.0, 5.0 + (k % 2) * 1.5), PI * 0.5)
	_furgao(Vector2(24.0, -11.0), 0.0, Moveis.PRETO * 1.6, "viatura", "FURGÃO DA TÁTICA")
	_cerca(Vector2(20.2, -21.5), Vector2(27.8, -21.5))
	_cerca(Vector2(27.8, -21.5), Vector2(27.8, -1.0))
	_cacamba(Vector2(-24.0, -14.0), PI * 0.5)
	for k in 4:
		_barril(Vector2(-25.5 + (k % 2) * 0.7, -6.0 + (k / 2) * 0.7), [Color(0.2, 0.3, 0.55), Color(0.55, 0.18, 0.12)][k % 2], k == 3)
	for p in [Vector2(-27, 3), Vector2(27, 3), Vector2(-27, 21), Vector2(27, 21)]:
		_poste(p, 0.0, 7.5)
	_pontos_em(Rect2(-26, 5, 52, 16), 0.0, 4, "estacionamento")
	_pontos_em(Rect2(20.5, -19, 7, 18), 0.0, 1, "patio")
	_bagunca(Rect2(-27, 0, 54, 21), 0.0, 22)
	infectados = [Vector3(0, 0, -3.5), Vector3(-10, 0, -9.5), Vector3(10, 0, -9.5), Vector3(-15.9, 0, -18.0), Vector3(-8, 0, -14.5),
		Vector3(8, 0, -14.5), Vector3(-12, y1, -5), Vector3(12, y1, -5), Vector3(0, y1, -5.5), Vector3(-6, 0, 12), Vector3(16, 0, 13)]

# grade de cela de a até b (barras a cada 0,2 m, cada uma com colisão: tiro passa entre elas); porta = trecho [s0, s1]
# sem barras (aberta)
func _barras(a: Vector2, b: Vector2, y: float, h: float, porta := Vector2(-1, -1)) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var s := 0.1
	while s < L - 0.05:
		if not (s > porta.x and s < porta.y):
			var p := a + d * s
			resto.cilindro(Vector3(p.x, y + h * 0.5, p.y), 0.022, h, 5, METAL_ESC)
			col.append([Vector3(p.x, y + h * 0.5, p.y), Vector3(0.06, h, 0.06), 0.0, Basis.IDENTITY])
		s += 0.2
	var m := (a + b) * 0.5
	var em_x := absf(d.x) > 0.5
	for yy in [0.05, h - 0.05, h * 0.45]:
		resto.caixa(Vector3(m.x, y + yy, m.y), Vector3(L, 0.06, 0.06) if em_x else Vector3(0.06, 0.06, L), METAL_ESC)
	if porta.x >= 0.0:
		var q := a + d * porta.x
		resto.caixa(Vector3(q.x, y + h * 0.5, q.y) + Vector3(-d.y, 0, d.x) * 0.45, Vector3(0.06, h, 0.9) if em_x else Vector3(0.9, h, 0.06), METAL_ESC * 1.3)   # porta aberta

# fileira de armários de metal (vestiário/corredor) de a até b, de costas para a parede; loot a cada 4 portas
func _armarios(a: Vector2, b: Vector2, g: float, loot: String, cor: Color, y := 0.0) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var bb := Basis(Vector3.UP, g)
	var n := int(L / 0.5)
	for k in n:
		var p := a + d * (k * 0.5 + 0.25)
		resto.caixa(Vector3(p.x, y + 0.95, p.y), Vector3(0.47, 1.9, 0.45) if absf(d.x) > 0.5 else Vector3(0.45, 1.9, 0.47), cor * (0.92 if k % 2 == 0 else 1.0))
		resto.caixa(Vector3(p.x, y + 1.6, p.y) + bb * Vector3(0, 0, 0.23), Vector3(0.2, 0.05, 0.01), METAL_ESC, bb)
		if k % 4 == 1:
			_loot(Vector3(p.x, y + 0.1, p.y) + bb * Vector3(0, 0, 0.7), loot, "ARMÁRIO", Vector2i(3, 4))
	var m := (a + b) * 0.5
	col.append([Vector3(m.x, y + 0.95, m.y), Vector3(L, 1.9, 0.45) if absf(d.x) > 0.5 else Vector3(0.45, 1.9, L), 0.0, Basis.IDENTITY])

# viatura (carro branco com faixa e giroflex) com porta-malas de loot da polícia
func _viatura(p: Vector2, g: float) -> void:
	_carro(p, g, Color(0.9, 0.9, 0.88), "viatura", false, "PORTA-MALAS DA VIATURA")
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, 0, p.y)
	resto.caixa(o + b * Vector3(0, 0.72, 0), Vector3(1.83, 0.18, 2.6), AZUL_POLICIA, b)
	resto.caixa(o + b * Vector3(-0.3, 1.47, -0.2), Vector3(0.55, 0.12, 0.28), Color(0.85, 0.1, 0.08), b)
	resto.caixa(o + b * Vector3(0.3, 1.47, -0.2), Vector3(0.55, 0.12, 0.28), Color(0.1, 0.25, 0.9), b)

# furgão (baú alto) com loot atrás
func _furgao(c: Vector2, g: float, cor: Color, loot: String, nome: String) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(c.x, 0, c.y)
	resto.caixa(o + b * Vector3(0, 1.45, -0.6), Vector3(2.2, 2.1, 4.2), cor, b)
	resto.caixa(o + b * Vector3(0, 1.05, 2.0), Vector3(2.1, 1.3, 1.6), cor, b)
	resto.caixa(o + b * Vector3(0, 1.35, 2.5), Vector3(2.0, 0.55, 0.8), Color(0.1, 0.12, 0.14), b)
	for x in [-1.0, 1.0]:
		for z in [-2.0, 2.0]:
			resto.cilindro(o + b * Vector3(x, 0.4, z), 0.4, 0.25, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	col.append([o + Vector3(0, 1.3, 0) + b * Vector3(0, 0, 0.0), Vector3(2.2, 2.6, 6.0), 0.0, b])
	_loot(o + b * Vector3(0, 0.1, -3.3), loot, nome, Vector2i(6, 5))

# ======================================================================================================
# ESCOLA (70 x 54): prédio de 2 andares (60 x 16) com corredor na frente e ARMÁRIOS dos alunos; térreo: secretaria,
# enfermaria, CANTINA (cozinha), BIBLIOTECA; em cima: salas de aula com carteiras e quadro, laboratório de ciências e
# a sala barricada onde um grupo se escondeu (colchões, carteiras empilhadas na porta). Telhado com caixa d'água.
# Fora: a QUADRA virou ABRIGO (barracas da Defesa Civil, alambrado, tabelas de basquete), ônibus escolar amarelo,
# mastro da bandeira e estacionamento.
# ======================================================================================================
func _escola() -> void:
	var B := Rect2(-30, -25, 60, 16)
	var cor_f := Color(0.62, 0.42, 0.32)
	var cor_d := Color(0.86, 0.84, 0.74)
	var verde_esc := Color(0.62, 0.72, 0.62)
	dentro = B.grow(-ESP * 0.5)
	var xi := -29.85
	var xf := 29.85
	# ---- chão de fora ----
	_chao(Rect2(-35, -9, 70, 5), CONCRETO * 1.05)
	_chao(Rect2(-35, -27, 70, 2), CONCRETO_ESC)
	_chao(Rect2(-33, -3, 28, 26), Color(0.24, 0.36, 0.3))                       # quadra
	_chao(Rect2(-3, -4, 38, 31), ASFALTO)
	_chao(Rect2(-35, -4, 2, 31), CONCRETO_ESC)
	_chao(Rect2(-5, -4, 2, 31), CONCRETO_ESC)
	_chao(Rect2(-33, 23, 30, 4), CONCRETO_ESC)
	var q := Rect2(-31, -1, 24, 22)                                                 # linhas da quadra
	for e in [[q.position, Vector2(q.end.x, q.position.y)], [Vector2(q.end.x, q.position.y), q.end], [q.end, Vector2(q.position.x, q.end.y)], [Vector2(q.position.x, q.end.y), q.position],
			[Vector2(q.position.x, q.get_center().y), Vector2(q.end.x, q.get_center().y)]]:
		_faixa(e[0], e[1], 0.1, BRANCO)
	_vagas(4.0, 32.0, -3.5, 5.0)
	# ---- paredes de fora (2 andares) ----
	var frente0 := _janelas(60.0, 3.0, 1.8, 1.0, 2.6, [[21.5, 24.5, 0.0, 3.0]])
	var dir0 := _janelas(16.0, 3.0, 1.6, 1.0, 2.6, [_porta(1.6)], 0.7)
	var fundo0 := _janelas(60.0, 3.0, 1.8, 1.0, 2.6, [_porta(22.0)])
	var esq0 := _janelas(16.0, 3.0, 1.6, 1.0, 2.6, [_porta(14.4)], 0.7)
	_perimetro(B, 0.0, ANDAR, cor_f, cor_d, [frente0, dir0, fundo0, esq0])
	var j1 := [_janelas(60.0, 3.0, 1.8, 1.0, 2.6, []), _janelas(16.0, 3.0, 1.6, 1.0, 2.6, []), _janelas(60.0, 3.0, 1.8, 1.0, 2.6, []), _janelas(16.0, 3.0, 1.6, 1.0, 2.6, [])]
	_perimetro(B, ANDAR, ANDAR, cor_f, cor_d, j1)
	fora.caixa(Vector3(0, ANDAR - 0.1, -8.83), Vector3(60.4, 0.25, 0.1), Color(0.8, 0.78, 0.7))
	# ---- lajes, escadas e telhado ----
	var buraco_a := Rect2(-8.9, -20.1, 1.4, 7.5)
	var buraco_b := Rect2(-6.5, -20.1, 1.4, 7.5)
	piso.caixa(Vector3(0, 0.02, -17), Vector3(59.7, 0.04, 15.7), Color(0.72, 0.7, 0.62), Basis.IDENTITY, true)
	_laje(B.grow(-0.05), PE, LAJE, [buraco_a], Color(0.7, 0.68, 0.6))
	_laje(B.grow(-0.05), ANDAR + PE, LAJE, [buraco_b], CONCRETO, true)
	var yt := ANDAR * 2.0
	_escada(Vector2(-8.2, -12.6), Vector2(0, -1), 1.4, 0.0, ANDAR, 7.5, CONCRETO, 1)
	_escada(Vector2(-5.8, -20.1), Vector2(0, 1), 1.4, ANDAR, ANDAR, 7.5, CONCRETO, -1)
	_grade(Vector2(-7.5, -20.1), Vector2(-7.5, -12.6), ANDAR)
	_grade(Vector2(-8.9, -20.1), Vector2(-8.9, -12.6), ANDAR)
	_grade(Vector2(-8.9, -12.6), Vector2(-7.5, -12.6), ANDAR)
	_grade(Vector2(-6.5, -20.1), Vector2(-6.5, -12.6), yt)
	_grade(Vector2(-5.1, -20.1), Vector2(-5.1, -12.6), yt)
	_grade(Vector2(-6.5, -20.1), Vector2(-5.1, -20.1), yt)
	_mureta(B.grow(ESP * 0.5), yt, 1.0, [])
	var casa := Rect2(-7.3, -20.9, 3.0, 9.1)
	_perimetro(casa, yt, 2.8, CONCRETO, CONCRETO, [[[0.3, 2.7, 0.0, 2.5]], [], [], []], fora)
	fora.caixa(Vector3(casa.get_center().x, yt + 2.95, casa.get_center().y), Vector3(casa.size.x + 0.5, 0.3, casa.size.y + 0.5), CONCRETO_ESC)
	_col(Vector3(casa.get_center().x, yt + 2.95, casa.get_center().y), Vector3(casa.size.x + 0.5, 0.3, casa.size.y + 0.5))
	# caixa d'água no telhado (de pé em 4 pernas) e ar-condicionado
	for p in [Vector2(18.6, -18.6), Vector2(21.4, -18.6), Vector2(18.6, -15.4), Vector2(21.4, -15.4)]:
		_bx(fora, Vector3(p.x, yt + 1.0, p.y), Vector3(0.2, 2.0, 0.2), METAL_ESC)
	fora.cilindro(Vector3(20, yt + 3.4, -17), 1.9, 2.8, 14, Color(0.45, 0.35, 0.25))
	fora.cilindro(Vector3(20, yt + 5.1, -17), 1.95, 0.6, 14, Color(0.3, 0.3, 0.32))
	_col(Vector3(20, yt + 3.4, -17), Vector3(3.6, 3.4, 3.6))
	for p in [Vector2(-22, -17), Vector2(5, -20), Vector2(10, -13)]:
		_bx(fora, Vector3(p.x, yt + 0.7, p.y), Vector3(2.2, 1.4, 1.6), Color(0.6, 0.62, 0.62))
	_sacos(Vector2(-16.0, -9.9), Vector2(-11.0, -9.9), 2, yt)
	_ponto(Vector3(-14, yt, -12), "telhado")
	_ponto(Vector3(12, yt, -17), "telhado")
	# ---- TÉRREO ----
	_parede(paredes, Vector2(xi, -12), Vector2(xf, -12), 0.0, PE, DIV, Color.WHITE, verde_esc, [_porta(4.85), _porta(14.85), [20.25, 25.45, 0.0, 99.0], _porta(29.85, 2.4), _porta(37.85, 2.4), _porta(50.85, 2.0)])
	for x in [-20.0, -10.0, -4.0, 12.0]:
		_parede(paredes, Vector2(x, -24.85), Vector2(x, -12), 0.0, PE, DIV, Color.WHITE, cor_d, [])
	_armarios_corredor(0.0)
	# secretaria
	_movel("balcao", Vector3(-25.0, 0, -14.2), 0.0, "escola_secretaria", "SECRETARIA")
	_movel("mesa_escritorio", Vector3(-27.0, 0, -19.5), 0.0, "escola_secretaria")
	_movel("mesa_escritorio", Vector3(-22.6, 0, -19.5), 0.0, "escola_secretaria")
	for x in [-28.8, -28.1, -27.4]:
		_movel("arquivo", Vector3(x, 0, -24.5), 0.0, "escritorio")
	_movel("quadro", Vector3(-24, 1.6, -24.8), 0.0)
	_pontos_em(Rect2(-29.5, -23.5, 9, 7), 0.0, 2, "secretaria")
	# enfermaria
	_movel("maca", Vector3(-17.8, 0, -22.6), 0.0)
	_movel("maca", Vector3(-14.4, 0, -22.6), 0.0)
	_movel("armario_remedios", Vector3(-11.5, 0, -24.6), 0.0, "escola_enfermaria", "ARMÁRIO DA ENFERMARIA")
	_movel("armario_remedios", Vector3(-19.6, 0, -16.0), PI * 0.5, "escola_enfermaria", "ARMÁRIO DA ENFERMARIA")
	_movel("pia", Vector3(-10.4, 0, -15.0), -PI * 0.5, "banheiro")
	_pontos_em(Rect2(-19.5, -21, 9, 7), 0.0, 1, "enfermaria")
	# cantina: mesas compridas, balcão de servir e cozinha
	for x in [-1.6, 3.2, 8.0]:
		for z in [-14.6, -17.8]:
			_mesa_cantina(Vector2(x, z))
	for x in [-1.6, 0.9, 3.4, 5.9]:
		_movel("balcao", Vector3(x, 0, -20.6), 0.0, "escola_cantina", "BALCÃO DA CANTINA")
	_movel("bancada", Vector3(-2.0, 0, -24.5), 0.0, "escola_cantina", "ARMÁRIO DA COZINHA")
	_movel("fogao_industrial", Vector3(1.4, 0, -24.4), 0.0)
	_movel("geladeira", Vector3(4.2, 0, -24.4), 0.0, "escola_cantina")
	_movel("freezer", Vector3(7.0, 0, -24.3), 0.0, "super_congelados", "FREEZER DA CANTINA")
	_movel("caixas", Vector3(10.6, 0, -23.8), 0.0, "escola_cantina", "DESPENSA")
	_pontos_em(Rect2(-3.5, -19.5, 15, 7), 0.0, 3, "cantina")
	# biblioteca
	var xb := 13.4
	while xb < 29.0:
		_movel("estante_livros", Vector3(xb, 0, -24.6), 0.0)
		xb += 1.7
	for x in [16.0, 20.0, 24.0]:
		_movel("estante_livros", Vector3(x, 0, -20.0), 0.0)
		_movel("estante_livros", Vector3(x, 0, -19.6), PI)
	_movel("mesa_jantar", Vector3(16.5, 0, -15.2), 0.0)
	_movel("mesa_jantar", Vector3(23.5, 0, -15.2), 0.0)
	for p in [Vector2(14.5, -23.6), Vector2(21.0, -18.6), Vector2(27.5, -23.6)]:
		_loot(Vector3(p.x, 0.1, p.y), "escola_biblioteca", "ESTANTE DE LIVROS", Vector2i(4, 3))
	_pontos_em(Rect2(12.5, -23, 17, 9), 0.0, 2, "biblioteca")
	_pontos_em(Rect2(-29.5, -11.6, 59, 2.3), 0.0, 4, "corredor")
	_bagunca(Rect2(-29.5, -24.5, 59, 15), 0.0, 40)
	# ---- 1º ANDAR: salas de aula, laboratório, sala barricada ----
	var y1 := ANDAR
	_parede(paredes, Vector2(xi, -12), Vector2(xf, -12), y1, PE, DIV, Color.WHITE, verde_esc, [_porta(7.85), _porta(17.85), [20.25, 25.45, 0.0, 99.0], _porta(35.85), _porta(46.85), _porta(57.85)])
	for x in [-20.0, -10.0, -4.0, 8.0, 19.0]:
		_parede(paredes, Vector2(x, -24.85), Vector2(x, -12), y1, PE, DIV, Color.WHITE, cor_d, [])
	_armarios_corredor(y1)
	_sala_aula(Rect2(-29.85, -24.85, 9.85, 12.85), y1, "AULA 21")
	_sala_aula(Rect2(-4.0, -24.85, 12.0, 12.85), y1, "AULA 23")
	_sala_aula(Rect2(19.0, -24.85, 10.85, 12.85), y1, "AULA 25")
	# sala 24: barricada (o grupo que se escondeu aqui)
	var sb := Rect2(8.0, -24.85, 11.0, 12.85)
	for k in 4:
		_movel("colchao", Vector3(9.8 + (k % 2) * 4.0, y1, -23.0 + (k / 2) * 3.4), r.randf_range(-0.2, 0.2), "escola_abrigo")
	for k in 6:
		var pc := Vector3(16.5 + r.randf_range(-0.6, 0.6), y1 + (k / 3) * 0.75, -12.9 + r.randf_range(-0.3, 0.3))
		resto.caixa(pc + Vector3(0, 0.38, 0), Vector3(0.7, 0.05, 0.5), MADEIRA_CLARA, Basis(Vector3.UP, r.randf() * 3.0) * Basis(Vector3.RIGHT, r.randf_range(-0.4, 0.4)))
		resto.caixa(pc + Vector3(0, 0.18, 0), Vector3(0.6, 0.36, 0.04), METAL_ESC, Basis(Vector3.UP, r.randf() * 3.0))
	_col(Vector3(16.6, y1 + 0.75, -12.9), Vector3(1.6, 1.5, 0.9))                        # carteiras empilhadas na porta
	resto.caixa(Vector3(sb.position.x + 0.1, y1 + 1.6, -18.5), Vector3(0.04, 1.2, 3.6), Color(0.12, 0.25, 0.18))   # quadro
	_texto(Vector3(sb.position.x + 0.14, y1 + 1.65, -18.5), PI * 0.5, "NÃO ABRAM.\nTEM INFECTADOS NO CORREDOR.\nDIA 3", Color(0.9, 0.9, 0.85), 22)
	for k in 5:
		resto.caixa(Vector3(10.0 + k * 0.4, y1 + 0.15, -14.0), Vector3(0.12, 0.3, 0.12), [Color(0.6, 0.2, 0.1), Color(0.2, 0.3, 0.6), Color(0.85, 0.8, 0.7)][k % 3])   # latas e garrafas
	_loot(Vector3(13.0, y1 + 0.1, -14.5), "escola_abrigo", "MANTIMENTOS DO GRUPO", Vector2i(6, 4))
	_pontos_em(Rect2(8.5, -24, 10, 8), y1, 2, "abrigo")
	# laboratório
	for x in [-17.0, -13.0]:
		for z in [-21.0, -17.0]:
			_movel("bancada", Vector3(x, y1, z), 0.0 if z < -18.0 else PI, "escola_lab", "BANCADA DO LABORATÓRIO")
	_movel("armario_remedios", Vector3(-11.0, y1, -24.6), 0.0, "escola_lab", "ARMÁRIO DE REAGENTES")
	_movel("armario_remedios", Vector3(-19.0, y1, -24.6), 0.0, "escola_lab", "ARMÁRIO DE REAGENTES")
	_movel("pia", Vector3(-10.4, y1, -20.0), -PI * 0.5, "banheiro")
	_pontos_em(Rect2(-19.5, -24, 9, 10), y1, 2, "laboratorio")
	_pontos_em(Rect2(-29.5, -11.6, 59, 2.3), y1, 3, "corredor")
	_bagunca(Rect2(-29.5, -24.5, 59, 15), y1, 30)
	# ---- fachada: marquise e letreiro ----
	fora.caixa(Vector3(-7.0, 3.3, -7.6), Vector3(6.0, 0.3, 2.8), CONCRETO_ESC)
	_col(Vector3(-7.0, 3.3, -7.6), Vector3(6.0, 0.3, 2.8))
	for x in [-9.7, -4.3]:
		_bx(fora, Vector3(x, 1.6, -6.4), Vector3(0.3, 3.2, 0.3), CONCRETO)
	fora.caixa(Vector3(-7.0, 7.4, -8.78), Vector3(11.0, 1.0, 0.12), Color(0.15, 0.25, 0.45))
	_texto(Vector3(-7.0, 7.4, -8.7), 0.0, "ESCOLA PÚBLICA 118", Color(0.95, 0.92, 0.8), 64)
	# ---- a quadra virou abrigo: alambrado, tabelas, barracas e faixa ----
	_cerca(Vector2(-33.0, -3.2), Vector2(-21.0, -3.2), 3.0)
	_cerca(Vector2(-17.0, -3.2), Vector2(-5.0, -3.2), 3.0)
	_cerca(Vector2(-33.0, -3.2), Vector2(-33.0, 23.0), 3.0)
	_cerca(Vector2(-5.0, -3.2), Vector2(-5.0, 8.0), 3.0)
	_cerca(Vector2(-5.0, 12.0), Vector2(-5.0, 23.0), 3.0)
	_cerca(Vector2(-33.0, 23.0), Vector2(-5.0, 23.0), 3.0)
	_cesta(Vector2(-19.0, -0.4), 0.0)
	_cesta(Vector2(-19.0, 20.4), PI)
	_tenda(Vector2(-27.5, 6.0), 0.0)
	_tenda(Vector2(-19.0, 9.0), 0.0)
	_tenda(Vector2(-10.5, 6.0), 0.0)
	_tenda(Vector2(-27.5, 16.0), 0.0)
	for k in 6:
		_movel("colchao", Vector3(-13.5 + (k % 3) * 1.4, 0, 14.0 + (k / 3) * 2.6), r.randf_range(-0.3, 0.3), "escola_abrigo")
	fora.caixa(Vector3(-19.0, 2.4, -3.25), Vector3(5.0, 1.0, 0.04), Color(0.9, 0.9, 0.86))
	_texto(Vector3(-19.0, 2.4, -3.2), 0.0, "ABRIGO · DEFESA CIVIL", Color(0.15, 0.25, 0.55), 40)
	# ônibus escolar, carros, mastro da bandeira e postes
	_onibus(Vector2(16.0, 19.0), PI * 0.5)
	_carro(Vector2(6.8, -0.5), 0.0, Color(0.3, 0.32, 0.36))
	_carro(Vector2(20.4, -0.6), 0.05, Color(0.55, 0.15, 0.12))
	_carro(Vector2(28.0, 9.5), 1.8, Color(0.62, 0.62, 0.6), "carro", true)
	fora.cilindro(Vector3(-1.0, 5.0, -6.0), 0.06, 10.0, 6, METAL)
	_col(Vector3(-1.0, 5.0, -6.0), Vector3(0.15, 10.0, 0.15))
	resto.caixa(Vector3(-0.1, 9.2, -6.0), Vector3(1.8, 1.0, 0.02), Color(0.7, 0.15, 0.15))
	for p in [Vector2(-34, -7), Vector2(34, -7), Vector2(2, 26), Vector2(34, 26)]:
		_poste(p, 0.0, 7.5)
	_cacamba(Vector2(32.0, -25.0), 0.0)
	_pontos_em(Rect2(-32, 0, 26, 22), 0.0, 4, "quadra")
	_pontos_em(Rect2(-2, -3, 34, 28), 0.0, 3, "patio")
	_bagunca(Rect2(-34, -8, 68, 34), 0.0, 25)
	infectados = [Vector3(-20, 0, -10.5), Vector3(15, 0, -10.5), Vector3(4, 0, -16), Vector3(20, 0, -17.5), Vector3(0, y1, -10.5),
		Vector3(-25, y1, -13), Vector3(25, y1, -18), Vector3(-19, 0, 13), Vector3(10, 0, 16), Vector3(26, 0, 4)]

# armários dos alunos no corredor (encostados na parede z = -12, fora das portas)
func _armarios_corredor(y: float) -> void:
	var trechos := [[-29.4, -26.2], [-23.8, -16.2], [-13.8, -10.3]] if y < 0.5 else [[-29.4, -23.2], [-20.8, -13.2], [-10.8, -10.3]]
	trechos += [[-3.6, -1.4], [1.4, 6.6], [9.4, 20.0], [22.0, 29.4]] if y < 0.5 else [[-3.6, 4.8], [7.2, 15.8], [18.2, 26.8]]
	var cores := [Color(0.2, 0.35, 0.6), Color(0.65, 0.2, 0.15), Color(0.25, 0.45, 0.3)]
	for k in trechos.size():
		var t: Array = trechos[k]
		if float(t[1]) - float(t[0]) < 1.0:
			continue
		_armarios(Vector2(float(t[0]), -11.6), Vector2(float(t[1]), -11.6), 0.0, "escola_armario", cores[k % 3], y)

# sala de aula: quadro na parede da esquerda, mesa do professor, carteiras em fileiras e um armário
func _sala_aula(ret: Rect2, y: float, nome: String) -> void:
	var x0 := ret.position.x
	resto.caixa(Vector3(x0 + 0.1, y + 1.6, ret.get_center().y), Vector3(0.04, 1.2, minf(ret.size.y - 3.0, 5.0)), Color(0.12, 0.25, 0.18))
	_texto(Vector3(x0 + 0.14, y + 1.9, ret.get_center().y), PI * 0.5, nome, Color(0.9, 0.9, 0.85), 30)
	_movel("mesa_escritorio", Vector3(x0 + 1.6, y, ret.get_center().y), PI * 0.5, "escola_sala")
	var x := x0 + 3.4
	while x < ret.end.x - 0.8:
		var z := ret.position.y + 1.2
		while z < ret.end.y - 1.6:
			if r.randf() < 0.85:
				_carteira(Vector2(x, z), y, -PI * 0.5 + r.randf_range(-0.12, 0.12), r.randf() < 0.08)
			z += 1.8
		x += 1.6
	_movel("aparador", Vector3(ret.end.x - 0.3, y, ret.position.y + 1.4), -PI * 0.5, "escola_sala")
	_loot(Vector3(ret.get_center().x, y + 0.1, ret.end.y - 1.2), "escola_sala", "MOCHILAS ESQUECIDAS", Vector2i(5, 3))
	_pontos_em(ret.grow(-1.0), y, 2, "sala")

# carteira (mesa + cadeira) virada para "g" (a frente da cadeira); tombada = caída no chão
func _carteira(p: Vector2, y: float, g: float, tombada := false) -> void:
	var b := Basis(Vector3.UP, g)
	if tombada:
		b = b * Basis(Vector3.RIGHT, PI * 0.5)
	var o := Vector3(p.x, y + (0.3 if tombada else 0.0), p.y)
	resto.caixa(o + b * Vector3(0, 0.74, 0.25), Vector3(0.65, 0.04, 0.45), MADEIRA_CLARA, b)          # tampo
	resto.caixa(o + b * Vector3(0, 0.37, 0.25), Vector3(0.6, 0.72, 0.04), METAL_ESC, b)                # pés
	resto.caixa(o + b * Vector3(0, 0.44, -0.25), Vector3(0.42, 0.04, 0.4), Color(0.3, 0.32, 0.45), b)   # assento
	resto.caixa(o + b * Vector3(0, 0.7, -0.46), Vector3(0.42, 0.45, 0.04), Color(0.3, 0.32, 0.45), b)   # encosto
	resto.caixa(o + b * Vector3(0, 0.22, -0.25), Vector3(0.38, 0.44, 0.38), METAL_ESC * 0.8, b)
	if not tombada:
		col.append([o + Vector3(0, 0.4, 0), Vector3(0.65, 0.8, 0.95), 0.0, Basis(Vector3.UP, g)])

# mesa comprida da cantina com bancos
func _mesa_cantina(p: Vector2) -> void:
	_bx(resto, Vector3(p.x, 0.74, p.y), Vector3(3.6, 0.05, 0.9), Color(0.75, 0.73, 0.68), false)
	resto.caixa(Vector3(p.x, 0.37, p.y), Vector3(3.2, 0.72, 0.1), METAL_ESC)
	for s in [-1.0, 1.0]:
		resto.caixa(Vector3(p.x, 0.43, p.y + s * 0.7), Vector3(3.4, 0.05, 0.32), Color(0.75, 0.73, 0.68))
	_col(Vector3(p.x, 0.4, p.y), Vector3(3.6, 0.8, 1.8))

# tabela de basquete (poste, tabela e aro) virada para +Z girado
func _cesta(p: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, 0, p.y)
	fora.cilindro(o + b * Vector3(0, 1.6, -0.5), 0.08, 3.2, 6, METAL_ESC)
	fora.caixa(o + b * Vector3(0, 3.05, 0.0), Vector3(1.8, 1.05, 0.06), Color(0.9, 0.9, 0.88), b)
	fora.cilindro(o + b * Vector3(0, 2.75, 0.3), 0.23, 0.03, 12, Color(0.85, 0.35, 0.1))
	col.append([o + b * Vector3(0, 1.6, -0.5), Vector3(0.2, 3.2, 0.2), 0.0, b])

# ônibus escolar amarelo (ao longo de Z local girado), com loot pela porta de trás
func _onibus(c: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(c.x, 0, c.y)
	var am := Color(0.92, 0.66, 0.08)
	resto.caixa(o + b * Vector3(0, 1.65, -0.6), Vector3(2.5, 2.3, 9.4), am, b)
	resto.caixa(o + b * Vector3(0, 1.25, 4.7), Vector3(2.4, 1.3, 1.4), am, b)                          # capô
	resto.caixa(o + b * Vector3(0, 2.2, -0.6), Vector3(2.52, 0.75, 9.0), Color(0.12, 0.13, 0.14), b)    # janelas
	resto.caixa(o + b * Vector3(0, 1.3, -0.6), Vector3(2.53, 0.1, 9.4), Moveis.PRETO, b)
	for z in [-3.6, 3.6]:
		for x in [-1.12, 1.12]:
			resto.cilindro(o + b * Vector3(x, 0.5, z), 0.5, 0.3, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	col.append([o + Vector3(0, 1.45, 0) + b * Vector3(0, 0, 0.1), Vector3(2.5, 2.9, 11.0), 0.0, b])
	_loot(o + b * Vector3(0, 0.1, -6.0), "onibus_escolar", "ÔNIBUS ESCOLAR", Vector2i(6, 5))

# ======================================================================================================
# ESTAÇÃO DO METRÔ ELEVADA (64 x 28): o "El" de Nova York — viaduto de ferro verde a 6 m do chão com 2 linhas e 2
# plataformas cobertas; um TREM de 3 vagões parado na linha de trás (dá para entrar: bolsas e mochilas largadas);
# escadarias da rua até cada plataforma, catracas, bilheteria embaixo; no fim da direita o viaduto CAIU e virou uma
# rampa de concreto até o chão (outro caminho para subir); na esquerda ele acaba cortado. Embaixo: banca de jornal,
# carros, um acampamento de quem morava ali e a sombra do viaduto.
# ======================================================================================================
const YT := 6.0            # trilhos (topo do tabuleiro)
const YP := 7.1            # plataformas e piso do trem

func _metro() -> void:
	var x0 := -32.0
	var x1 := 22.0
	var cx := (x0 + x1) * 0.5
	var L := x1 - x0
	dentro = Rect2(-27.0, -4.95, 44.4, 2.9)             # o trem (embaixo do viaduto é ao ar livre)
	# ---- chão ----
	_chao(Rect2(-32, -14, 64, 28), ASFALTO)
	_chao(Rect2(-32, 6.5, 64, 7.5), CONCRETO * 1.05, 0.025)
	_chao(Rect2(-32, -14, 64, 3.5), CONCRETO_ESC, 0.025)
	_faixa(Vector2(-32, -2.0), Vector2(32, -2.0), 0.15, AMARELO)
	# ---- pilares, vigas e tabuleiro ----
	var x := -30.0
	while x <= 20.5:
		for z in [-7.5, 3.5]:
			_bx(fora, Vector3(x, 2.6, z), Vector3(0.6, 5.2, 0.6), VERDE_EL)
			fora.caixa(Vector3(x, 0.15, z), Vector3(1.0, 0.3, 1.0), CONCRETO)
		fora.caixa(Vector3(x, 4.75, -2.0), Vector3(0.5, 0.9, 12.0), VERDE_EL * 0.9)
		for s in [-1.0, 1.0]:                                                           # mãos-francesas
			fora.caixa(Vector3(x, 4.2, -2.0 + s * 4.6), Vector3(0.2, 0.2, 2.2), VERDE_EL, Basis(Vector3.RIGHT, s * 0.6))
		x += 10.0
	for z in [-7.95, 3.95]:
		fora.caixa(Vector3(cx, 4.9, z), Vector3(L, 1.4, 0.4), VERDE_EL * 1.05)                     # vigas laterais
		var t := x0 + 0.5
		while t < x1:
			fora.caixa(Vector3(t, 4.9, z + signf(z) * 0.21), Vector3(0.1, 1.3, 0.04), VERDE_EL * 0.8)   # nervuras
			t += 1.5
	_bx(fora, Vector3(cx, 5.6, -2.0), Vector3(L, 0.8, 12.0), CONCRETO_ESC)
	# trilhos e dormentes (linhas em z -3,5 e -0,5)
	for zl in [-3.5, -0.5]:
		var t := x0 + 0.4
		while t < x1:
			fora.caixa(Vector3(t, YT + 0.06, zl), Vector3(0.25, 0.12, 2.4), Color(0.3, 0.24, 0.18))
			t += 1.1
		for s in [-0.72, 0.72]:
			fora.caixa(Vector3(cx, YT + 0.17, zl + s), Vector3(L, 0.12, 0.08), METAL)
		fora.caixa(Vector3(cx, YT + 0.15, zl + 1.15), Vector3(L, 0.1, 0.25), Color(0.5, 0.4, 0.25))    # terceiro trilho (coberto)
	# plataformas (1,1 m acima dos trilhos) com faixa amarela, cobertura e bancos
	for pl in [[-8.0, -5.0, -5.25], [1.0, 4.0, 1.25]]:
		var z0: float = pl[0]
		var z1: float = pl[1]
		var zc := (z0 + z1) * 0.5
		_bx(fora, Vector3(cx, YT + 0.55, zc), Vector3(L, 1.1, z1 - z0), CONCRETO * 1.05)
		_faixa(Vector2(x0, float(pl[2])), Vector2(x1, float(pl[2])), 0.45, AMARELO, YP + 0.02)
		fora.caixa(Vector3(-5.0, 10.1, zc), Vector3(40.0, 0.2, 3.8), Color(0.55, 0.58, 0.56))
		_col(Vector3(-5.0, 10.1, zc), Vector3(40.0, 0.2, 3.8))
		var zp := z0 + 0.6 if z0 < -6.0 else z1 - 0.6
		var t := -23.0
		while t <= 13.0:
			_bx(fora, Vector3(t, (YP + 10.0) * 0.5, zp), Vector3(0.2, 10.0 - YP, 0.2), VERDE_EL)
			t += 6.0
		for k in 5:
			var bx := -20.0 + k * 8.0
			_bx(resto, Vector3(bx, YP + 0.45, zp - signf(zp) * 0.55), Vector3(1.8, 0.08, 0.45), MADEIRA_CLARA)
			_bx(resto, Vector3(bx, YP + 0.22, zp - signf(zp) * 0.55), Vector3(0.1, 0.44, 0.4), METAL_ESC, false)
		_pontos_em(Rect2(x0 + 2, z0, L - 4, z1 - z0), YP, 3, "plataforma")
	# placas da estação (o "1" vermelho da linha) penduradas na cobertura
	for zc in [-6.5, 2.5]:
		for xs in [-18.0, 6.0]:
			fora.caixa(Vector3(xs, 9.3, zc), Vector3(3.4, 0.6, 0.08), Moveis.PRETO)
			for s in [-1.0, 1.0]:
				_texto(Vector3(xs, 9.3, zc + s * 0.05), 0.0 if s > 0.0 else PI, "RUA 125  (1)", Color(0.95, 0.95, 0.92), 40)
	# grades nas bordas de fora das plataformas (abertas onde as escadas chegam)
	_grade(Vector2(x0, -7.95), Vector2(-1.1, -7.95), YP)
	_grade(Vector2(1.1, -7.95), Vector2(x1, -7.95), YP)
	_grade(Vector2(x0, 3.95), Vector2(-5.1, 3.95), YP)
	_grade(Vector2(-2.9, 3.95), Vector2(x1, 3.95), YP)
	# catracas no alto das escadas
	for k in 3:
		_bx(resto, Vector3(-4.6 + k * 0.85, YP + 0.5, 3.0), Vector3(0.25, 1.0, 0.9), INOX, k != 1)
		_bx(resto, Vector3(-0.6 + k * 0.85, YP + 0.5, -7.0), Vector3(0.25, 1.0, 0.9), INOX, k != 1)
	# ---- escadarias da rua (paralelas à rua) ----
	_escada(Vector2(10.0, 5.2), Vector2(-1, 0), 2.0, 0.0, YP, 13.0, CONCRETO, 1)
	_bx(resto, Vector3(-4.0, YP - 0.15, 5.25), Vector3(2.2, 0.3, 2.5), CONCRETO)                     # patamar
	_grade(Vector2(-5.1, 6.4), Vector2(-2.9, 6.4), YP)
	_grade(Vector2(-5.1, 4.1), Vector2(-5.1, 6.4), YP)
	_escada(Vector2(-14.0, -9.2), Vector2(1, 0), 2.0, 0.0, YP, 13.0, CONCRETO, -1)
	_bx(resto, Vector3(0.0, YP - 0.15, -9.25), Vector3(2.2, 0.3, 2.5), CONCRETO)
	_grade(Vector2(-1.1, -10.4), Vector2(1.1, -10.4), YP)
	_grade(Vector2(1.1, -10.4), Vector2(1.1, -8.1), YP)
	# entrada na rua: postes com os globos verdes e a placa METRÔ
	for xg in [11.0, -15.0]:
		var zg := 6.6 if xg > 0.0 else -10.6
		fora.cilindro(Vector3(xg, 1.2, zg), 0.05, 2.4, 5, METAL_ESC)
		fora.cilindro(Vector3(xg, 2.55, zg), 0.2, 0.35, 10, Color(0.2, 0.75, 0.3))
	fora.caixa(Vector3(11.0, 3.2, 6.6), Vector3(1.6, 0.45, 0.06), Moveis.PRETO)
	_texto(Vector3(11.0, 3.2, 6.65), 0.0, "METRÔ", Color(0.95, 0.95, 0.92), 36)
	# bilheteria embaixo da escada da frente
	var bil := Rect2(12.5, 4.6, 3.0, 2.6)
	_perimetro(bil, 0.0, 2.6, INOX, Color(0.8, 0.78, 0.7), [[[0.4, 2.6, 1.0, 2.0, "janela"]], [[0.6, 1.8, 0.0, 2.2]], [], []], resto)
	fora.caixa(Vector3(bil.get_center().x, 2.75, bil.get_center().y), Vector3(3.4, 0.3, 3.0), CONCRETO_ESC)
	_col(Vector3(bil.get_center().x, 2.75, bil.get_center().y), Vector3(3.4, 0.3, 3.0))
	_bx(resto, Vector3(14.0, 0.45, 5.0), Vector3(2.2, 0.9, 0.5), MADEIRA_CLARA * 0.7)
	_loot(Vector3(14.0, 0.1, 5.8), "metro_bilheteria", "BILHETERIA", Vector2i(4, 2))
	# ---- o trem (3 vagões na linha de trás) ----
	for k in 3:
		_vagao(-27.0 + k * 15.0, -3.5, 14.4, k)
	# ---- pontas: cortado na esquerda, caído na direita (rampa até o chão) ----
	for zg in [-6.5, 2.5]:
		_grade(Vector2(x0 + 0.05, zg - 1.5), Vector2(x0 + 0.05, zg + 1.5), YP)
	_barreira(Vector2(x0 + 1.5, -3.5), 0.0)
	_barreira(Vector2(x0 + 1.5, -0.5), 0.0)
	for k in 7:
		fora.cilindro(Vector3(x0 - 0.2, 5.3 + r.randf_range(0.0, 0.6), -7.0 + k * 1.8), 0.02, 0.8, 4, METAL_ESC, Basis(Vector3.FORWARD, PI * 0.5 + r.randf_range(-0.4, 0.4)))
	for k in 5:
		_movel("entulho", Vector3(x0 + 2.0 + r.randf_range(0, 4), 0, -8.0 + k * 2.6), r.randf() * 3.0)
	var ang := atan2(YT - 0.2, 32.0 - x1)
	var comp := sqrt(pow(32.0 - x1, 2.0) + pow(YT - 0.2, 2.0))
	var br := Basis(Vector3.BACK, -ang)
	var meio := Vector3((x1 + 32.0) * 0.5, (YT + 0.2) * 0.5 - 0.4, -2.0)
	_bx(fora, meio, Vector3(comp + 0.3, 0.8, 12.0), CONCRETO_ESC, true, br)
	for s in [-0.72, 0.72]:
		fora.caixa(meio + br * Vector3(0, 0.46, -3.5 + s), Vector3(comp, 0.1, 0.08), METAL, br * Basis(Vector3.UP, r.randf_range(-0.03, 0.03)))
	for k in 4:
		_movel("entulho", Vector3(24.0 + k * 2.2, 0, 6.5 + r.randf_range(-1, 1)), r.randf() * 3.0)
	_escada(Vector2(20.8, -2.6), Vector2(0, -1), 1.0, YT, YP - YT, 2.3, CONCRETO, 0)     # degraus de serviço (trilho -> plataforma)
	_escada(Vector2(20.8, -1.6), Vector2(0, 1), 1.0, YT, YP - YT, 2.5, CONCRETO, 0)
	_escada(Vector2(-30.5, -2.6), Vector2(0, -1), 1.0, YT, YP - YT, 2.3, CONCRETO, 0)
	_escada(Vector2(-30.5, -1.6), Vector2(0, 1), 1.0, YT, YP - YT, 2.5, CONCRETO, 0)
	_pontos_em(Rect2(-29, -1.5, 49, 2), YT, 2, "trilhos")
	# ---- embaixo do viaduto: banca de jornal, carros, acampamento ----
	_bx(resto, Vector3(-21.0, 1.3, 9.5), Vector3(3.0, 2.6, 2.0), Color(0.2, 0.4, 0.28))
	resto.caixa(Vector3(-21.0, 2.7, 10.7), Vector3(3.4, 0.08, 1.0), Color(0.15, 0.3, 0.2), Basis(Vector3.RIGHT, 0.25))
	for k in 6:
		resto.caixa(Vector3(-22.2 + k * 0.48, 1.6, 10.52), Vector3(0.4, 0.55, 0.03), Color(r.randf(), r.randf(), r.randf()).lerp(Color.WHITE, 0.4))
	_loot(Vector3(-21.0, 0.1, 11.1), "metro_banca", "BANCA DE JORNAL", Vector2i(5, 3))
	_carro(Vector2(-8.0, -1.6), PI * 0.5 + 0.08, Color(0.3, 0.32, 0.36))
	_carro(Vector2(6.0, -2.6), PI * 0.5 - 0.1, Color(0.85, 0.7, 0.15), "carro", false, "PORTA-MALAS DO TÁXI")
	_carro(Vector2(26.0, -9.5), 0.4, Color(0.55, 0.15, 0.12), "carro", true)
	for k in 3:
		_movel("colchao", Vector3(-26.0 + k * 1.3, 0, -5.5), r.randf_range(-0.3, 0.3))
	resto.caixa(Vector3(-24.7, 1.0, -6.8), Vector3(4.2, 0.05, 2.6), Color(0.2, 0.3, 0.5), Basis(Vector3.RIGHT, 0.6))   # lona
	_barril(Vector2(-22.0, -4.0), Color(0.3, 0.25, 0.2))
	_carrinho(Vector2(-23.0, -2.6), 1.0)
	_cacamba(Vector2(-12.0, -12.3), 0.0)
	for p in [Vector2(-31, 13), Vector2(0, 13), Vector2(30, 13)]:
		_poste(p, 0.0, 7.0)
	_pontos_em(Rect2(-30, -7, 50, 10), 0.0, 3, "embaixo")
	_pontos_em(Rect2(-30, 7, 60, 6), 0.0, 2, "calcada")
	_bagunca(Rect2(-31, -13, 62, 26), 0.0, 25)
	_bagunca(Rect2(x0, -8, L, 3), YP, 10)
	_bagunca(Rect2(x0, 1, L, 3), YP, 10)
	infectados = [Vector3(-20, YP, -3.5), Vector3(-5, YP, -3.5), Vector3(10, YP, -3.5), Vector3(-15, YP, -6.5), Vector3(8, YP, 2.0),
		Vector3(-10, YT, -0.5), Vector3(-20, 0, -2), Vector3(0, 0, 9), Vector3(15, 0, -2), Vector3(27, 0, 10)]

# vagão do metrô (inox, faixa vermelha) de x0 a x0 + comp na linha z; portas abertas do lado da plataforma de trás
func _vagao(xa: float, z: float, comp: float, k: int) -> void:
	var w := 2.9
	var za := z - w * 0.5 + 0.05
	var zb := z + w * 0.5 - 0.05
	var h := 2.5
	var y0 := YP + 0.02
	# caixa de baixo (truques e rodas) e piso
	resto.caixa(Vector3(xa + comp * 0.5, YT + 0.6, z), Vector3(comp - 0.4, 0.75, w - 0.4), METAL_ESC)
	for xb in [xa + 2.2, xa + comp - 2.2]:
		for s in [-0.72, 0.72]:
			for dx in [-0.9, 0.9]:
				resto.cilindro(Vector3(xb + dx, YT + 0.6, z + s), 0.42, 0.12, 8, Moveis.PRETO, Basis(Vector3.RIGHT, PI * 0.5))
	_bx(resto, Vector3(xa + comp * 0.5, YP - 0.1, z), Vector3(comp, 0.24, w), Color(0.35, 0.33, 0.3))
	# paredes compridas (portas e janelas) e pontas (passagem entre vagões)
	var portas_tras: Array = []
	var portas_frente: Array = []
	for s in [1.8, 5.4, 9.0, 12.6]:
		portas_tras.append([s - 0.65, s + 0.65, 0.0, 2.0])
		portas_frente.append([s - 0.65, s + 0.65, 0.0, 2.0] if (s == 5.4 and k != 1) else [s - 0.65, s + 0.65, 0.9, 1.8, "janela"])
	for s in [3.6, 7.2, 10.8]:
		portas_tras.append([s - 0.9, s + 0.9, 0.9, 1.8, "janela"])
		portas_frente.append([s - 0.9, s + 0.9, 0.9, 1.8, "janela"])
	_parede(resto, Vector2(xa, za), Vector2(xa + comp, za), y0, h, 0.08, INOX, Color(0.82, 0.82, 0.8), portas_tras, -1)
	_parede(resto, Vector2(xa, zb), Vector2(xa + comp, zb), y0, h, 0.08, INOX, Color(0.82, 0.82, 0.8), portas_frente, 1)
	for xe in [xa + 0.04, xa + comp - 0.04]:
		_parede(resto, Vector2(xe, za), Vector2(xe, zb), y0, h, 0.08, INOX, INOX, [[1.0, 1.8, 0.0, 2.0]])
	_bx(fora, Vector3(xa + comp * 0.5, y0 + h + 0.1, z), Vector3(comp, 0.2, w), INOX * 0.9)
	resto.caixa(Vector3(xa + comp * 0.5, y0 + 0.75, za - 0.05), Vector3(comp, 0.18, 0.02), Color(0.75, 0.1, 0.08))   # faixa da linha
	resto.caixa(Vector3(xa + comp * 0.5, y0 + 0.75, zb + 0.05), Vector3(comp, 0.18, 0.02), Color(0.75, 0.1, 0.08))
	# bancos compridos entre as portas e balaústres
	for s in [3.6, 7.2, 10.8]:
		for zz in [za + 0.3, zb - 0.3]:
			_bx(resto, Vector3(xa + s, y0 + 0.23, zz), Vector3(1.9, 0.46, 0.45), Color(0.25, 0.4, 0.62))
		resto.cilindro(Vector3(xa + s, y0 + h * 0.5, z), 0.025, h, 5, INOX)
	# bolsas e mochilas largadas
	_loot(Vector3(xa + 4.5, y0 + 0.05, z), "metro_vagao", "BOLSAS NO VAGÃO", Vector2i(5, 4))
	_loot(Vector3(xa + 10.0, y0 + 0.05, z), "metro_vagao", "MOCHILAS NO VAGÃO", Vector2i(5, 4))
	_ponto(Vector3(xa + 7.2, y0, z), "vagao")
	_bagunca(Rect2(xa + 0.3, za + 0.3, comp - 0.6, w - 0.7), y0, 8)

# ======================================================================================================
# QUARTEL DA GUARDA NACIONAL (64 x 50), dentro da base militar do aeroporto: muro de HESCO (gaiolas de areia) com
# portão, guarita e cancela, 2 TORRES DE VIGIA nos cantos da frente, ALOJAMENTO com beliches e escada até o telhado,
# prédio do ARSENAL / rádio / enfermaria, heliponto vazio (o helicóptero foi levado — "VAGOS" pichado no muro),
# barracas, caminhões e jipes, caixas de suprimento. Loot militar de verdade: o lugar mais disputado perto da base.
# ======================================================================================================
func _quartel() -> void:
	var cor_f := Color(0.5, 0.52, 0.42)
	var cor_d := Color(0.72, 0.72, 0.64)
	var BA := Rect2(-28, -21, 30, 11)                  # alojamento
	var BS := Rect2(8, -21, 20, 12)                    # arsenal / rádio / enfermaria
	var H := 3.6
	dentro = BA.grow(-ESP * 0.5)
	# ---- chão ----
	_chao(Rect2(-32, -25, 64, 50), Color(0.42, 0.39, 0.32))
	_chao(Rect2(-4, -8, 8, 33), ASFALTO, 0.025)
	_chao(Rect2(-30, -9, 60, 3), ASFALTO, 0.025)
	_chao(Rect2(BA.position.x - 0.5, BA.position.y - 0.5, BA.size.x + 1, BA.size.y + 1), CONCRETO_ESC, 0.03)
	_chao(Rect2(BS.position.x - 0.5, BS.position.y - 0.5, BS.size.x + 1, BS.size.y + 1), CONCRETO_ESC, 0.03)
	# ---- muro de HESCO (aberturas: portão na frente, um rombo no fundo e um na esquerda) ----
	_hesco(Vector2(-31.3, 24.3), Vector2(-5.0, 24.3))
	_hesco(Vector2(5.0, 24.3), Vector2(31.3, 24.3))
	_hesco(Vector2(-31.3, -24.3), Vector2(8.0, -24.3))
	_hesco(Vector2(13.0, -24.3), Vector2(31.3, -24.3))
	_hesco(Vector2(-31.3, -24.3), Vector2(-31.3, -4.0))
	_hesco(Vector2(-31.3, 0.0), Vector2(-31.3, 24.3))
	_hesco(Vector2(31.3, -24.3), Vector2(31.3, 24.3))
	for k in 4:
		_movel("entulho", Vector3(9.0 + k * 1.2, 0, -24.3 + r.randf_range(-1, 1)), r.randf() * 3.0)
	_movel("entulho", Vector3(-31.0, 0, -2.0), 0.3)
	# portão: cancela levantada, guarita, sacos de areia e chicana de barreiras
	fora.caixa(Vector3(-4.2, 0.6, 24.3), Vector3(0.4, 1.2, 0.4), Color(0.85, 0.85, 0.8))
	resto.caixa(Vector3(-4.2, 2.9, 24.3), Vector3(0.12, 4.4, 0.12), VERMELHO, Basis(Vector3.BACK, 0.12))
	_col(Vector3(-4.2, 0.6, 24.3), Vector3(0.4, 1.2, 0.4))
	_guarita(Vector2(7.6, 21.0))
	_sacos(Vector2(-8.5, 21.0), Vector2(-4.8, 21.0))
	_sacos(Vector2(-8.5, 21.0), Vector2(-8.5, 18.5))
	for k in 4:
		_barreira(Vector2(-1.6 if k % 2 == 0 else 1.6, 18.5 - k * 3.2), PI * 0.5)
	fora.caixa(Vector3(-15.0, 1.4, 25.05), Vector3(7.5, 1.3, 0.08), Color(0.2, 0.26, 0.18))
	_texto(Vector3(-15.0, 1.45, 25.1), 0.0, "GUARDA NACIONAL\nPOSTO AVANÇADO · ÁREA MILITAR", Color(0.92, 0.9, 0.8), 32)
	# ---- ALOJAMENTO (beliches; banheiro na ponta; escada por fora até o telhado) ----
	var fa := _janelas(30.0, 3.0, 1.4, 1.1, 2.4, [_porta(15.0)])
	var la := _janelas(11.0, 3.0, 1.4, 1.1, 2.4, [_porta(5.5)])
	_perimetro(BA, 0.0, H, cor_f, cor_d, [fa, [], _janelas(30.0, 3.0, 1.4, 1.1, 2.4, [], 0.7), la])
	piso.caixa(Vector3(BA.get_center().x, 0.03, BA.get_center().y), Vector3(BA.size.x - 0.3, 0.04, BA.size.y - 0.3), Color(0.55, 0.55, 0.5), Basis.IDENTITY, true)
	_laje(BA.grow(ESP * 0.5), H, 0.3, [], CONCRETO, true)
	var ya := H + 0.3
	_mureta(BA.grow(ESP * 0.5), ya, 0.9, [[Vector2(-14.2, -21.15), Vector2(-12.4, -21.15)]])
	_parede(paredes, Vector2(-4.0, -20.85), Vector2(-4.0, -10.15), 0.0, H, DIV, Color.WHITE, cor_d, [_porta(5.3)])
	var xb := -26.4
	while xb < -5.5:
		_beliche(Vector3(xb, 0, -19.8), 0.0)
		if absf(xb + 13.0) > 2.0:
			_beliche(Vector3(xb, 0, -11.2), PI)
		xb += 3.0
	for k in 2:
		_movel("pia", Vector3(-3.6, 0, -19.0 + k * 1.3), PI * 0.5, "banheiro")
		_movel("vaso", Vector3(1.6, 0, -19.6 + k * 1.6), -PI * 0.5)
	_armarios(Vector2(-3.4, -10.6), Vector2(1.6, -10.6), PI, "quartel_alojamento", Color(0.3, 0.34, 0.26))
	_pontos_em(Rect2(-27.5, -18, 23, 5), 0.0, 4, "alojamento")
	_bagunca(Rect2(-27.5, -20.5, 31, 10), 0.0, 25)
	# escada de ferro pelos fundos até o telhado (sacos de areia lá em cima: vigia o pátio)
	_escada(Vector2(-6.0, -22.2), Vector2(-1, 0), 1.2, 0.0, ya, 6.5, METAL, 1)
	resto.caixa(Vector3(-13.3, ya - 0.06, -21.9), Vector3(1.8, 0.12, 1.8), METAL)
	_col(Vector3(-13.3, ya - 0.1, -21.9), Vector3(1.8, 0.2, 1.8))
	_grade(Vector2(-14.2, -22.8), Vector2(-12.4, -22.8), ya)
	_grade(Vector2(-14.2, -22.8), Vector2(-14.2, -21.15), ya)
	_sacos(Vector2(-22.0, -10.2), Vector2(-16.0, -10.2), 2, ya)
	_sacos(Vector2(-6.0, -10.2), Vector2(-1.0, -10.2), 2, ya)
	_caixa_militar(Vector3(-19.0, ya, -13.0), 0.3, "militar")
	_ponto(Vector3(-10, ya, -15), "telhado")
	_texto(Vector3(-20.0, 1.9, -9.83), 0.0, "VAGOS", PICHE, 90)
	# ---- ARSENAL / RÁDIO / ENFERMARIA ----
	var fs := [_porta(4.0, 1.4), [6.5, 8.5, 1.1, 2.4, "janela"], _porta(11.0), [13.0, 15.0, 1.1, 2.4, "janela"], _porta(17.0)]
	_perimetro(BS, 0.0, H, cor_f, cor_d, [fs, _janelas(12.0, 3.0, 1.4, 1.1, 2.4, []), [], []])
	piso.caixa(Vector3(BS.get_center().x, 0.03, BS.get_center().y), Vector3(BS.size.x - 0.3, 0.04, BS.size.y - 0.3), Color(0.55, 0.55, 0.5), Basis.IDENTITY, true)
	_laje(BS.grow(ESP * 0.5), H, 0.3, [], CONCRETO, true)
	_mureta(BS.grow(ESP * 0.5), H + 0.3, 0.6, [])
	for xw in [16.0, 22.0]:
		_parede(paredes, Vector2(xw, -20.85), Vector2(xw, -9.15), 0.0, H, DIV, Color.WHITE, cor_d, [])
	_barras(Vector2(11.3, -9.27), Vector2(12.7, -9.27), 0.0, 2.4, Vector2(0.05, 1.35))           # grade do arsenal (aberta)
	for x in [9.4, 11.8, 14.2]:
		_movel("armario_armas", Vector3(x, 0, -20.55), 0.0, "quartel_arsenal", "ARMÁRIO DO ARSENAL")
	_movel("armario_armas", Vector3(15.6, 0, -15.0), -PI * 0.5, "quartel_arsenal", "ARMÁRIO DO ARSENAL")
	_caixa_militar(Vector3(10.0, 0, -14.0), 0.0, "militar")
	_caixa_militar(Vector3(10.0, 0.74, -14.0), 0.1, "quartel_arsenal")
	_caixa_militar(Vector3(13.0, 0, -12.0), 0.4, "militar")
	_movel("bancada", Vector3(19.0, 0, -20.55), 0.0, "central_radio", "RÁDIOS DO QUARTEL")
	for xr in [18.2, 19.8]:
		resto.caixa(Vector3(xr, 1.15, -20.6), Vector3(0.6, 0.4, 0.4), VERDE_MIL * 0.8)
	_movel("mesa_escritorio", Vector3(19.0, 0, -15.0), 0.0, "escritorio")
	_movel("arquivo", Vector3(21.6, 0, -17.5), -PI * 0.5, "escritorio")
	_movel("maca", Vector3(24.0, 0, -19.6), 0.0)
	_movel("maca", Vector3(26.6, 0, -19.6), 0.0)
	_movel("armario_remedios", Vector3(27.6, 0, -14.5), -PI * 0.5, "militar_med", "ARMÁRIO DE PRIMEIROS SOCORROS")
	_movel("armario_remedios", Vector3(22.4, 0, -14.5), PI * 0.5, "militar_med", "ARMÁRIO DE PRIMEIROS SOCORROS")
	fora.cilindro(Vector3(26.0, H + 4.0, -19.0), 0.08, 8.0, 5, METAL_ESC)                          # antena do rádio
	for s in [-1.0, 1.0]:
		fora.caixa(Vector3(26.0, H + 6.5, -19.0), Vector3(2.0 if s > 0 else 0.05, 0.05, 0.05 if s > 0 else 2.0), METAL_ESC)
	_pontos_em(Rect2(8.5, -20, 7, 10), 0.0, 2, "arsenal")
	_pontos_em(Rect2(16.5, -20, 11, 10), 0.0, 2, "radio")
	_bagunca(Rect2(8.5, -20.5, 19, 11), 0.0, 15)
	# ---- torres de vigia ----
	_torre(Vector2(-27.0, 19.0))
	_torre(Vector2(27.0, 19.0))
	# ---- heliponto (vazio), barracas, caminhões, jipes e suprimentos ----
	chao.cilindro(Vector3(4.0, 0.04, 4.0), 6.8, 0.05, 28, Color(0.25, 0.27, 0.26))
	chao.cilindro(Vector3(4.0, 0.06, 4.0), 6.2, 0.05, 28, AMARELO)
	chao.cilindro(Vector3(4.0, 0.08, 4.0), 5.9, 0.05, 28, Color(0.25, 0.27, 0.26))
	for pc in [[Vector3(2.6, 0, 4), Vector3(0.6, 0.02, 4.4)], [Vector3(5.4, 0, 4), Vector3(0.6, 0.02, 4.4)], [Vector3(4, 0, 4), Vector3(2.4, 0.02, 0.6)]]:
		chao.caixa((pc[0] as Vector3) + Vector3(0, 0.11, 0), pc[1], BRANCO)
	for k in 8:
		var a := k * TAU / 8.0
		fora.caixa(Vector3(4.0 + cos(a) * 6.5, 0.12, 4.0 + sin(a) * 6.5), Vector3(0.25, 0.12, 0.25), Color(0.9, 0.6, 0.1))
	_tenda(Vector2(-25.0, 4.0), 0.0)
	_tenda(Vector2(-17.0, 4.0), 0.0)
	_caminhao_mil(Vector2(19.0, 4.0), 0.06)
	_caminhao_mil(Vector2(25.0, 4.5), -0.04)
	_jipe(Vector2(-12.0, 17.0), 0.35)
	_jipe(Vector2(13.0, 15.0), -0.5)
	for p in [Vector2(-8.0, -4.0), Vector2(-6.4, -4.0), Vector2(-7.2, -2.4)]:
		_palete(p, r.randf_range(-0.2, 0.2), 1)
	_caixa_militar(Vector3(-8.0, 0.74, -4.0), 0.1, "militar")
	_caixa_militar(Vector3(-6.4, 0.74, -4.0), -0.1, "militar_med")
	for k in 6:
		_barril(Vector2(28.5 + (k % 2) * 0.7, -6.0 + (k / 2) * 0.7), VERDE_MIL * 1.2, k == 5)
	_bx(resto, Vector3(5.5, 0.75, -6.8), Vector3(2.4, 1.5, 1.2), Color(0.4, 0.45, 0.32))             # gerador
	fora.cilindro(Vector3(-6.0, 5.0, 18.0), 0.06, 10.0, 6, METAL)                                       # mastro
	_col(Vector3(-6.0, 5.0, 18.0), Vector3(0.15, 10.0, 0.15))
	resto.caixa(Vector3(-5.1, 9.2, 18.0), Vector3(1.8, 1.0, 0.02), Color(0.2, 0.25, 0.45))
	for p in [Vector2(-29, -7), Vector2(29, -7), Vector2(-29, 12), Vector2(29, 12)]:
		_poste(p, 0.0, 8.0)
	_pontos_em(Rect2(-28, -6, 56, 20), 0.0, 5, "patio")
	_bagunca(Rect2(-30, -8, 60, 31), 0.0, 25)
	infectados = [Vector3(-20, 0, -15.5), Vector3(-8, 0, -15.5), Vector3(12, 0, -16), Vector3(19, 0, -13), Vector3(-25, 0, 0),
		Vector3(4, 0, 4), Vector3(0, 0, 21), Vector3(22, 0, 11), Vector3(-10, 0, 10)]

# fileira de HESCO (gaiolas de tela cheias de areia, 1,4 m) de a até b
func _hesco(a: Vector2, b: Vector2, h := 2.1) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var em_x := absf(d.x) > 0.5
	var n := maxi(1, int(round(L / 1.4)))
	var passo := L / n
	for k in n:
		var p := a + d * (passo * (k + 0.5))
		var t := Vector3(passo - 0.04, h, 1.4) if em_x else Vector3(1.4, h, passo - 0.04)
		resto.caixa(Vector3(p.x, h * 0.5, p.y), t, AREIA * r.randf_range(0.9, 1.05))
		resto.caixa(Vector3(p.x, h * 0.66, p.y), t * Vector3(1.01, 0.02, 1.01), METAL_ESC)
		resto.caixa(Vector3(p.x, h * 0.33, p.y), t * Vector3(1.01, 0.02, 1.01), METAL_ESC)
	var m := (a + b) * 0.5
	col.append([Vector3(m.x, h * 0.5, m.y), Vector3(L + 1.4, h, 1.4) if em_x else Vector3(1.4, h, L + 1.4), 0.0, Basis.IDENTITY])

# beliche (2 camas) com o armário/loot na frente
func _beliche(p: Vector3, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	for x in [-0.45, 0.45]:
		for z in [-0.95, 0.95]:
			resto.caixa(p + b * Vector3(x, 0.9, z), Vector3(0.05, 1.8, 0.05), VERDE_MIL * 0.8, b)
	for y in [0.45, 1.5]:
		resto.caixa(p + b * Vector3(0, y, 0), Vector3(0.95, 0.06, 2.0), METAL_ESC, b)
		resto.caixa(p + b * Vector3(0, y + 0.1, 0), Vector3(0.88, 0.14, 1.9), Color(0.33, 0.36, 0.26) * r.randf_range(0.9, 1.1), b)
	col.append([p + Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 2.0), 0.0, b])
	_loot(p + b * Vector3(0, 0.1, 1.5), "quartel_alojamento", "BELICHE", Vector2i(4, 3))

# torre de vigia de madeira e ferro: plataforma a 6 m com sacos de areia, telhado, escada por trás
func _torre(c: Vector2) -> void:
	var yp := 6.0
	var meia := 1.7
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bx(fora, Vector3(c.x + sx * (meia - 0.15), yp * 0.5, c.y + sz * (meia - 0.15)), Vector3(0.3, yp, 0.3), MADEIRA_CLARA * 0.7)
			fora.cilindro(Vector3(c.x + sx * (meia - 0.15), yp + 1.2, c.y + sz * (meia - 0.15)), 0.06, 2.4, 5, METAL_ESC)
	for s in [-1.0, 1.0]:                                                                # travas em X
		fora.caixa(Vector3(c.x + s * (meia - 0.15), yp * 0.5, c.y), Vector3(0.1, 0.12, meia * 2.6), MADEIRA_CLARA * 0.6, Basis(Vector3.RIGHT, 1.0))
	_bx(fora, Vector3(c.x, yp - 0.1, c.y), Vector3(meia * 2.0, 0.2, meia * 2.0), MADEIRA_CLARA * 0.8)
	fora.caixa(Vector3(c.x, yp + 2.45, c.y), Vector3(meia * 2.0 + 0.4, 0.12, meia * 2.0 + 0.4), Color(0.3, 0.33, 0.25))
	_col(Vector3(c.x, yp + 2.45, c.y), Vector3(meia * 2.0 + 0.4, 0.12, meia * 2.0 + 0.4))
	# sacos de areia em 3 lados; o de trás (onde a escada chega) aberto no meio
	_sacos(Vector2(c.x - meia + 0.2, c.y + meia - 0.25), Vector2(c.x + meia - 0.2, c.y + meia - 0.25), 3, yp)
	_sacos(Vector2(c.x - meia + 0.25, c.y - meia + 0.2), Vector2(c.x - meia + 0.25, c.y + meia - 0.2), 3, yp)
	_sacos(Vector2(c.x + meia - 0.25, c.y - meia + 0.2), Vector2(c.x + meia - 0.25, c.y + meia - 0.2), 3, yp)
	_bx(resto, Vector3(c.x + 1.0, yp + 1.15, c.y + 1.0), Vector3(0.45, 0.35, 0.5), METAL_ESC)              # holofote
	_escada(Vector2(c.x, c.y - meia - 9.0), Vector2(0, 1), 1.1, 0.0, yp, 9.0, MADEIRA_CLARA * 0.75, 1)
	_caixa_militar(Vector3(c.x - 0.6, yp, c.y), PI * 0.5, "militar")
	_ponto(Vector3(c.x + 0.4, yp, c.y - 0.6), "torre")

# jipe militar (caixas) com loot atrás
func _jipe(c: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(c.x, 0, c.y)
	var cor := Color(0.4, 0.42, 0.3)
	resto.caixa(o + b * Vector3(0, 0.85, 0), Vector3(2.1, 0.75, 4.6), cor, b)
	resto.caixa(o + b * Vector3(0, 1.55, -0.6), Vector3(2.0, 0.7, 2.4), cor * 0.9, b)
	resto.caixa(o + b * Vector3(0, 1.56, -0.6), Vector3(2.02, 0.45, 2.1), Color(0.1, 0.12, 0.1), b)
	for x in [-1.0, 1.0]:
		for z in [-1.5, 1.5]:
			resto.cilindro(o + b * Vector3(x, 0.45, z), 0.45, 0.35, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	col.append([o + Vector3(0, 1.0, 0), Vector3(2.1, 2.0, 4.6), 0.0, b])
	_loot(o + b * Vector3(0, 0.1, -2.9), "militar", "JIPE MILITAR", Vector2i(6, 4))
