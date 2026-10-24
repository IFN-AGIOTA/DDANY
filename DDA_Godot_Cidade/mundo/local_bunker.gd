extends "res://mundo/local_novos.gd"
# BUNKER (0.83): um por ilha (mundo/locais.gd, tipo "bunker"), todos com a MESMA estrutura (só muda o NÚMERO pintado).
#   - EM CIMA (o terreno de 28 x 22): a "cabeça" de concreto do bunker com a PORTA BLINDADA, o leitor de cartão, o
#     número grande pintado, respiros, sacos de areia e a cerca. A porta só abre com o CARTÃO DE ACESSO do mesmo
#     número (item "cartao_bunker_N": mundo/porta_bunker.gd faz a checagem e a descida pelo elevador).
#   - EMBAIXO (5 andares, 22 m a 38 m abaixo da rua): NÍVEL 1 controle (chegada do elevador, guarita, armários,
#     sala de comando), NÍVEL 2 alojamento e refeitório, NÍVEL 3 enfermaria e laboratório, NÍVEL 4 depósito de
#     suprimentos, NÍVEL 5 arsenal. Escadas em zigue-zague no canto leste ligam todos. TOTALMENTE ESCURO (sem luz
#     nenhuma: mundo/clima.gd "subsolo" apaga o sol e a luz ambiente lá embaixo; só a lanterna ilumina).
#   - Muito loot (tabelas "bunker_*" em mundo/loot_mundo.gd, quase nunca vazio) e nenhum infectado (por enquanto).
#   - UMA DRAW CALL: tudo (em cima e embaixo, inclusive o número) vai para uma malha só, com um material só.
# Mexa AQUI para: a planta, os andares, os móveis e o loot de cada sala. Onde ficam: mundo/locais.gd (LOCAIS).

const Y0 := -22.0                       # piso do NÍVEL 1 (relativo à rua)
const PE_B := 3.4
const LAJE_B := 0.5
const ANDAR_B := PE_B + LAJE_B          # 3,9 m de um piso ao outro
const NIVEIS := 5
const B := Rect2(-15, -12, 30, 24)      # planta dos andares de baixo
const LA := 10.5                        # pistas das escadas (x)
const LB := 13.5
const ESC_Z := 3.25                     # as escadas vão de z = -3,25 até +3,25
const CINZA := Color(0.5, 0.5, 0.48)
const CINZA_ESC := Color(0.3, 0.3, 0.3)
const PRETO_AMARELO := [Color(0.08, 0.08, 0.08), Color(0.85, 0.65, 0.1)]
const CORES_NUM := [Color(0.78, 0.16, 0.12), Color(0.9, 0.7, 0.12), Color(0.27, 0.66, 0.27), Color(0.24, 0.47, 0.86)]

var numero := 1
var elevadores: Array = []              # [ponto local, "desce"/"sobe", destino local, direção do olhar (Vector2 local)]

static func y_nivel(k: int) -> float:
	return Y0 - k * ANDAR_B

func _bunker() -> void:
	numero = load("res://mundo/locais.gd").numero_bunker(idx)
	r.seed = 830                       # a mesma estrutura em todos
	# tudo numa malha só (uma draw call)
	fora = resto
	paredes = resto
	piso = resto
	teto = resto
	concreto = resto
	chao = resto
	dentro = Rect2()
	_superficie()
	for k in NIVEIS:
		_nivel(k)
	_escadas()

func _criar_malha() -> void:
	var am := ArrayMesh.new()
	resto.malha(Mat.material(Mat.INTERIOR, {"caixa": Vector4(0, 0, -1, -1), "padrao": 4.0, "sujeira": 0.55}), am)
	_malha = am

# ---------- em cima: a cabeça do bunker ----------
func _superficie() -> void:
	resto.caixa(Vector3(0, 0.025, -1.0), Vector3(16, 0.05, 15), CONCRETO_ESC, Basis.IDENTITY, true)       # laje de concreto no chão
	resto.caixa(Vector3(0, 0.03, 2.5), Vector3(4.0, 0.05, 6.0), CONCRETO_ESC * 0.9, Basis.IDENTITY, true)
	# bloco de concreto (10 x 8 x 3,2) com a frente em z = -1
	_bx(resto, Vector3(0, 1.6, -5.0), Vector3(10.0, 3.2, 8.0), CINZA)
	resto.caixa(Vector3(0, 3.3, -5.0), Vector3(10.6, 0.2, 8.6), CINZA * 0.85)                          # beiral
	# porta blindada (recuada) com moldura listrada e o leitor de cartão
	resto.caixa(Vector3(0, 1.3, -0.98), Vector3(2.2, 2.6, 0.06), Color(0.32, 0.34, 0.3))
	for k in 6:
		resto.caixa(Vector3(0, 0.3 + k * 0.42, -0.94), Vector3(2.0, 0.04, 0.02), Color(0.22, 0.24, 0.21))
	for k in 12:
		var c: Color = PRETO_AMARELO[k % 2]
		var s := -1.35 + k * 0.225
		resto.caixa(Vector3(s, 2.75, -0.96), Vector3(0.225, 0.2, 0.05), c)
	for lado in [-1.0, 1.0]:
		for k in 12:
			resto.caixa(Vector3(lado * 1.25, 0.11 + k * 0.22, -0.96), Vector3(0.2, 0.22, 0.05), PRETO_AMARELO[(k + int(lado > 0)) % 2])
	resto.caixa(Vector3(1.75, 1.3, -0.95), Vector3(0.22, 0.32, 0.08), Color(0.12, 0.12, 0.13))         # leitor
	resto.caixa(Vector3(1.75, 1.36, -0.9), Vector3(0.12, 0.03, 0.02), Color(0.1, 0.1, 0.1))            # fenda do cartão
	resto.caixa(Vector3(1.75, 1.22, -0.9), Vector3(0.05, 0.05, 0.02), Color(0.75, 0.1, 0.08))          # luz vermelha
	# o NÚMERO grande pintado em cima da porta e nas laterais, com a faixa da cor do bunker
	var cor_n: Color = CORES_NUM[(numero - 1) % CORES_NUM.size()]
	resto.caixa(Vector3(0, 3.0, -0.97), Vector3(4.0, 0.08, 0.03), cor_n)
	_digito(numero, Vector3(-2.9, 2.0, -0.96), 0.9, Basis.IDENTITY, Color(0.92, 0.92, 0.86))
	_digito(numero, Vector3(2.9, 2.0, -0.96), 0.9, Basis.IDENTITY, Color(0.92, 0.92, 0.86))
	_digito(numero, Vector3(5.03, 1.7, -5.0), 1.4, Basis(Vector3.UP, PI * 0.5), Color(0.92, 0.92, 0.86))
	_digito(numero, Vector3(-5.03, 1.7, -5.0), 1.4, Basis(Vector3.UP, -PI * 0.5), Color(0.92, 0.92, 0.86))
	_digito(numero, Vector3(0, 3.41, -5.0), 3.0, Basis(Vector3.RIGHT, -PI * 0.5), cor_n)                # no teto (visto de cima)
	# respiros e antena no teto
	for x in [-3.0, 3.0]:
		resto.cilindro(Vector3(x, 3.9, -7.0), 0.35, 1.2, 8, METAL_ESC)
		resto.caixa(Vector3(x, 4.55, -7.0), Vector3(0.9, 0.12, 0.9), METAL_ESC)
	resto.cilindro(Vector3(4.0, 5.4, -8.2), 0.05, 4.0, 5, METAL_ESC)
	# sacos de areia e barreiras na frente
	_sacos(Vector2(-4.8, 0.6), Vector2(-2.2, 0.6))
	_sacos(Vector2(2.2, 0.6), Vector2(4.8, 0.6))
	_barreira(Vector2(-3.5, 5.0), 0.0)
	_barreira(Vector2(3.5, 5.0), 0.0)
	# cerca em volta do terreno, com o portão aberto na frente
	var m := Rect2(-13.5, -10.5, 27, 21)
	_alambrado(Vector2(m.position.x, m.end.y), Vector2(-2.2, m.end.y))
	_alambrado(Vector2(2.2, m.end.y), Vector2(m.end.x, m.end.y))
	_alambrado(Vector2(m.end.x, m.end.y), Vector2(m.end.x, m.position.y))
	_alambrado(Vector2(m.end.x, m.position.y), Vector2(m.position.x, m.position.y))
	_alambrado(Vector2(m.position.x, m.position.y), Vector2(m.position.x, m.end.y))
	resto.caixa(Vector3(-2.2, 1.0, m.end.y + 1.0), Vector3(0.06, 2.0, 2.0), Color(0.5, 0.52, 0.55), Basis(Vector3.UP, 0.5))   # portão aberto
	# a porta: desce pelo elevador até o NÍVEL 1 (chegada na cabine, olhando para +X)
	elevadores.append([Vector3(0, 0, -0.5), "desce", Vector3(-13.0, y_nivel(0), 10.2), Vector2(1, 0)])
	_ponto(Vector3(-6.0, 0, 3.0), "fora")

# cerca de a até b (postes a cada 3 m e 5 fios de arame)
func _alambrado(a: Vector2, b: Vector2) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var s := 0.0
	while s <= L + 0.01:
		var p := a + d * s
		resto.cilindro(Vector3(p.x, 1.1, p.y), 0.04, 2.2, 5, METAL_ESC)
		s += 3.0
	var mm := (a + b) * 0.5
	var em_x := absf(d.x) > 0.5
	for h in [0.35, 0.8, 1.25, 1.7, 2.15]:                                    # arames (dá para ver através)
		resto.caixa(Vector3(mm.x, h, mm.y), Vector3(L, 0.03, 0.03) if em_x else Vector3(0.03, 0.03, L), METAL_ESC)
	col.append([Vector3(mm.x, 1.1, mm.y), Vector3(L, 2.2, 0.1) if em_x else Vector3(0.1, 2.2, L), 0.0, Basis.IDENTITY])

# número de 7 segmentos (tinta) com altura h, centrado em p, virado para +Z de "base"
const SEGMENTOS := [[1, 1, 1, 1, 1, 1, 0], [0, 1, 1, 0, 0, 0, 0], [1, 1, 0, 1, 1, 0, 1], [1, 1, 1, 1, 0, 0, 1],
	[0, 1, 1, 0, 0, 1, 1], [1, 0, 1, 1, 0, 1, 1], [1, 0, 1, 1, 1, 1, 1], [1, 1, 1, 0, 0, 0, 0], [1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 0, 1, 1]]
func _digito(n: int, p: Vector3, h: float, base: Basis, cor: Color) -> void:
	var w := h * 0.55
	var e := h * 0.12
	var s: Array = SEGMENTOS[clampi(n, 0, 9)]
	# a (cima), b (dir. cima), c (dir. baixo), d (baixo), e (esq. baixo), f (esq. cima), g (meio)
	var pecas := [[Vector3(0, h * 0.5, 0), Vector3(w, e, 0.02)], [Vector3(w * 0.5, h * 0.25, 0), Vector3(e, h * 0.5, 0.02)],
		[Vector3(w * 0.5, -h * 0.25, 0), Vector3(e, h * 0.5, 0.02)], [Vector3(0, -h * 0.5, 0), Vector3(w, e, 0.02)],
		[Vector3(-w * 0.5, -h * 0.25, 0), Vector3(e, h * 0.5, 0.02)], [Vector3(-w * 0.5, h * 0.25, 0), Vector3(e, h * 0.5, 0.02)],
		[Vector3(0, 0, 0), Vector3(w, e, 0.02)]]
	for k in 7:
		if s[k] == 1:
			resto.caixa(p + base * (pecas[k][0] as Vector3), pecas[k][1], cor, base)

# ---------- embaixo: um nível ----------
func _nivel(k: int) -> void:
	var y := y_nivel(k)
	var cor_p := Color(0.46, 0.47, 0.45)
	_perimetro(B, y, PE_B, cor_p, cor_p, [[], [], [], []], resto)
	# piso (com o buraco da escada que desce daqui) e teto do último nível de cima
	var buracos: Array = []
	if k < NIVEIS - 1:
		buracos.append(_buraco_escada(k))
	_laje(B, y - LAJE_B, LAJE_B, buracos, Color(0.36, 0.37, 0.36), false, CINZA_ESC)
	if k == 0:
		_laje(B, y + PE_B, LAJE_B, [], CINZA, false, CINZA_ESC)
	# faixa amarela no rodapé e o número do nível pintado na parede da escada
	resto.caixa(Vector3(B.end.x - 0.17, y + 1.6, 0.0), Vector3(0.02, 0.9, 0.9), Color(0.85, 0.65, 0.1))
	_digito(k + 1, Vector3(B.end.x - 0.16, y + 1.6, 0.0), 0.6, Basis(Vector3.UP, -PI * 0.5), Color(0.08, 0.08, 0.08))
	# parede que separa o hall da escada (x > 8,5) das salas, com 2 portas
	_parede(resto, Vector2(8.5, B.position.y + 0.15), Vector2(8.5, B.end.y - 0.15), y, PE_B, DIV, cor_p, cor_p, [_porta(5.0), _porta(19.0)])
	match k:
		0: _controle(y)
		1: _alojamento(y)
		2: _enfermaria(y)
		3: _deposito(y)
		4: _arsenal(y)
	_pontos_em(Rect2(B.position.x + 1.0, B.position.y + 1.0, 21.0, B.size.y - 2.0), y, 6, "bunker")
	_bagunca(Rect2(B.position.x + 0.5, B.position.y + 0.5, B.size.x - 1.0, B.size.y - 1.0), y, 10)

func _buraco_escada(k: int) -> Rect2:
	var x := LA if k % 2 == 0 else LB
	return Rect2(x - 0.7, -ESC_Z, 1.4, ESC_Z * 2.0)

# a escada k liga o nível k+1 (embaixo) ao nível k (em cima). Pista A (x = 10,5) sobe para -Z, B (13,5) para +Z.
func _escadas() -> void:
	for k in NIVEIS - 1:
		var y_baixo := y_nivel(k + 1)
		if k % 2 == 0:
			_escada(Vector2(LA, ESC_Z), Vector2(0, -1), 1.3, y_baixo, ANDAR_B, ESC_Z * 2.0, CINZA, -1)
		else:
			_escada(Vector2(LB, -ESC_Z), Vector2(0, 1), 1.3, y_baixo, ANDAR_B, ESC_Z * 2.0, CINZA, 1)
	# grades em volta dos buracos (cada nível: o buraco da escada que desce dali; a entrada fica livre)
	for k in NIVEIS:
		var y := y_nivel(k)
		_grade(Vector2(12.0, -ESC_Z - 0.2), Vector2(12.0, ESC_Z + 0.2), y)                  # entre as pistas
		if k == NIVEIS - 1:
			continue
		var x := LA if k % 2 == 0 else LB
		var fora_x := x - 0.75 if k % 2 == 0 else x + 0.75
		_grade(Vector2(fora_x, -ESC_Z), Vector2(fora_x, ESC_Z), y)
		var fundo := ESC_Z if k % 2 == 0 else -ESC_Z                                       # a ponta de baixo da escada
		_grade(Vector2(x - 0.75, fundo), Vector2(x + 0.75, fundo), y)

# ---------- as salas ----------
# NÍVEL 1: cabine do elevador (canto sudoeste), guarita, armários, sala de comando (norte) e caixas militares
func _controle(y: float) -> void:
	var cor := Color(0.5, 0.5, 0.47)
	_parede(resto, Vector2(-11.0, 8.0), Vector2(-11.0, 11.85), y, PE_B, DIV, cor, cor, [[0.4, 3.0, 0.0, 2.6]])
	_parede(resto, Vector2(-14.85, 8.0), Vector2(-11.0, 8.0), y, PE_B, DIV, cor, cor, [])
	resto.caixa(Vector3(-13.0, y + 0.02, 10.0), Vector3(3.8, 0.04, 3.8), METAL_ESC, Basis.IDENTITY, true)     # piso da cabine
	resto.caixa(Vector3(-14.8, y + 1.3, 10.0), Vector3(0.05, 0.3, 0.2), Color(0.12, 0.12, 0.13))              # botões
	elevadores.append([Vector3(-13.8, y, 10.0), "sobe", Vector3(0, 0, 1.2), Vector2(0, 1)])
	_movel("balcao", Vector3(-7.0, y, 6.5), PI * 0.5, "bunker_controle", "GUARITA")
	_movel("cadeira", Vector3(-8.0, y, 6.5), -PI * 0.5)
	_armarios(Vector2(-14.5, -11.6), Vector2(-4.5, -11.6), 0.0, "bunker_alojamento", VERDE_MIL, y)
	# sala de comando (norte, x 0..8,5): parede com porta, consoles, mesa e arquivos
	_parede(resto, Vector2(0.0, -11.85), Vector2(0.0, -2.0), y, PE_B, DIV, cor, cor, [_porta(6.0)])
	_parede(resto, Vector2(0.0, -2.0), Vector2(8.42, -2.0), y, PE_B, DIV, cor, cor, [])
	for x in [1.8, 4.4, 7.0]:
		_movel("bancada", Vector3(x, y, -11.5), 0.0, "bunker_controle", "CONSOLE")
		resto.caixa(Vector3(x, y + 1.25, -11.6), Vector3(1.6, 0.6, 0.12), Color(0.08, 0.1, 0.09))           # telas apagadas
	_movel("mesa_escritorio", Vector3(4.0, y, -6.0), 0.0, "bunker_controle")
	_movel("arquivo", Vector3(7.9, y, -4.0), -PI * 0.5, "bunker_controle")
	_caixa_militar(Vector3(-4.0, y, 2.0), 0.2, "bunker_militar")
	_caixa_militar(Vector3(4.0, y, 9.5), -0.1, "bunker_militar")
	_movel("caixas", Vector3(-3.0, y, 10.5), 0.0, "bunker_deposito")

# NÍVEL 2: alojamento (beliches) e refeitório com cozinha
func _alojamento(y: float) -> void:
	var cor := Color(0.5, 0.5, 0.47)
	_parede(resto, Vector2(-14.85, 0.0), Vector2(8.42, 0.0), y, PE_B, DIV, cor, cor, [_porta(2.95), _porta(10.45)])
	var x := -13.4
	while x < 7.0:
		_beliche(Vector3(x, y, -10.4), 0.0)
		if absf(x + 4.4) > 1.0:
			_beliche(Vector3(x, y, -2.0), PI)
		x += 3.0
	_armarios(Vector2(5.6, -0.4), Vector2(8.2, -0.4), PI, "bunker_alojamento", VERDE_MIL, y)
	_movel("mesa_jantar", Vector3(-8.0, y, 6.0), 0.0)
	_movel("mesa_jantar", Vector3(-3.0, y, 6.0), 0.0)
	_movel("fogao_industrial", Vector3(2.0, y, 11.5), PI, "bunker_comida")
	_movel("geladeira", Vector3(4.0, y, 11.5), PI, "bunker_comida")
	_movel("prateleira", Vector3(6.6, y, 11.5), PI, "bunker_comida", "DESPENSA")
	_movel("prateleira", Vector3(8.0, y, 3.0), -PI * 0.5, "bunker_comida", "DESPENSA")
	_movel("pia", Vector3(0.0, y, 11.6), PI)

# NÍVEL 3: enfermaria (macas e armários de remédios) e laboratório
func _enfermaria(y: float) -> void:
	var cor := Color(0.78, 0.8, 0.78)
	_parede(resto, Vector2(-3.0, -11.85), Vector2(-3.0, 11.85), y, PE_B, DIV, cor, cor, [_porta(6.0), _porta(18.0)])
	for z in [-9.5, -5.5, -1.5, 2.5, 6.5]:
		_movel("maca", Vector3(-13.6, y, z), PI * 0.5)
	for z in [-10.0, -8.5, 2.0, 9.5]:
		_movel("armario_remedios", Vector3(-4.0, y, z), -PI * 0.5, "bunker_med", "ARMÁRIO DE REMÉDIOS")
	_movel("armario_remedios", Vector3(-8.0, y, 11.6), PI, "bunker_med", "ARMÁRIO DE REMÉDIOS")
	# laboratório
	for z in [-11.5, 11.5]:
		_movel("bancada", Vector3(1.0, y, z), 0.0 if z < 0.0 else PI, "bunker_med", "BANCADA DO LABORATÓRIO")
		_movel("bancada", Vector3(4.6, y, z), 0.0 if z < 0.0 else PI, "bunker_med", "BANCADA DO LABORATÓRIO")
	_movel("arquivo", Vector3(7.9, y, -9.5), -PI * 0.5, "bunker_controle")
	_caixa_militar(Vector3(3.0, y, 0.0), PI * 0.5, "bunker_militar")

# NÍVEL 4: depósito de suprimentos (fileiras de prateleiras e caixas)
func _deposito(y: float) -> void:
	for z in [-9.0, -4.5, 0.0, 4.5]:
		for x in [-12.0, -9.4, -4.0, -1.4, 3.8]:
			_movel("prateleira", Vector3(x, y, z), 0.0, "bunker_deposito", "PRATELEIRA DE SUPRIMENTOS")
	for x in [-12.0, -6.0, 0.0]:
		_caixa_militar(Vector3(x, y, 9.5), 0.0, "bunker_militar")
	_movel("caixas", Vector3(5.5, y, 9.5), 0.3, "bunker_comida")
	_movel("caixas", Vector3(6.5, y, -11.0), 0.0, "bunker_deposito")

# NÍVEL 5: arsenal (armários de armas, caixas militares, cofre) e o gerador desligado
func _arsenal(y: float) -> void:
	var cor := Color(0.45, 0.47, 0.43)
	_parede(resto, Vector2(-14.85, 2.0), Vector2(8.42, 2.0), y, PE_B, DIV, cor, cor, [_porta(10.0)])
	_barras(Vector2(-6.0, 1.9), Vector2(-3.0, 1.9), y, 2.4, Vector2(0.8, 2.2))
	for x in [-13.6, -11.6, -9.6, -7.6, -5.6, -3.6, -1.6, 0.4]:
		_movel("armario_armas", Vector3(x, y, -11.6), 0.0, "bunker_arsenal", "ARMÁRIO DO ARSENAL")
	for z in [-7.0, -3.0]:
		_caixa_militar(Vector3(-10.0, y, z), 0.0, "bunker_militar")
		_caixa_militar(Vector3(-4.0, y, z), 0.0, "bunker_arsenal")
	_movel("arquivo", Vector3(5.5, y, -11.4), 0.0, "cofre", "COFRE")
	_movel("armario_armas", Vector3(7.9, y, -10.0), -PI * 0.5, "bunker_arsenal", "ARMÁRIO DO ARSENAL")
	# sala do gerador (sul): o gerador grande, desligado, e tambores de diesel
	_bx(resto, Vector3(-8.0, y + 1.1, 8.0), Vector3(4.5, 2.2, 2.2), Color(0.3, 0.36, 0.28))
	resto.caixa(Vector3(-8.0, y + 2.4, 8.0), Vector3(0.5, 0.4, 0.5), METAL_ESC)
	for x in [-2.0, -1.0, 0.0]:
		for z in [9.8, 10.8]:
			resto.cilindro(Vector3(x, y + 0.45, z), 0.3, 0.9, 10, Color(0.45, 0.12, 0.08))
	_col(Vector3(-1.0, y + 0.45, 10.3), Vector3(3.0, 0.9, 2.0))
	_caixa_militar(Vector3(4.0, y, 9.0), 0.0, "bunker_militar")
