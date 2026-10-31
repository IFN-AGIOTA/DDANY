extends Node
# LOCAIS ESPECIAIS (0.68): POSTOS DE GASOLINA, HOSPITAIS, SUPERMERCADOS e ARMAZÉNS — e, desde a 0.78, DELEGACIAS,
# ESCOLAS, ESTAÇÕES DO METRÔ (elevadas) e QUARTÉIS DA GUARDA NACIONAL (na base). São as ZONAS DE PvP do mapa:
# prédios grandes e caprichados (mundo/local.gd), loot melhor e próprio de cada lugar (mundo/loot_mundo.gd, tabelas
# "posto_*", "hospital_*", "super_*", "armazem_*"), mais infectados e um aviso na tela quando você entra.
#   - ONDE FICAM: lista LOCAIS abaixo (feita por ferramentas/escolher_locais.gd: terreno livre com rua na frente,
#     longe uns dos outros, um de cada perto da base). Os prédios comuns que estavam no terreno saem (mundo/cidade.gd).
#   - DE LONGE: uma "casca" simples (caixas) montada junto com a cidade (cidade.locais_casca).
#   - DE PERTO (até RAIO_ABRIR m da borda do terreno): o local inteiro é montado (numa thread, como os interiores)
#     com móveis, colisão, loot e infectados; a casca some. Longe de novo (RAIO_FECHAR): desmonta e guarda o chão.
#   - No mapa: cada local aparece com a cor e o nome (hud/mapa.gd).
#   - 0.77: LUZ E SOM (mundo/ambiente_local.gd): alguns têm gerador ligado (luzes à noite, uma piscando, zumbido,
#     ronco do gerador, bipe no hospital); os outros ficam no escuro, com rangidos.
#   - 0.72: os infectados VOLTAM: a cada CICLO_INFECTADOS horas de jogo o local enche de novo quando você chega
#     (se os de antes já morreram ou foram embora). O loot volta pelo ciclo do mundo/loot_mundo.gd (CICLO_LOCAL).
#   - 0.83: BUNKERS (tipo "bunker", mundo/local_bunker.gd): um por ilha, 5 andares no subsolo, escuro, muito loot,
#     sem infectados. A porta só abre com o cartão do mesmo número (mundo/porta_bunker.gd). O cartão aparece nas
#     ÁREAS MILITARES (quartéis e postos militares dos hospitais: CHANCE em mundo/loot_mundo.gd tentar_cartao).
#   - 0.91: os HOSPITAIS são ZONAS NEUTRAS (npc/hospitais.gd): sem PvP, sem infectados (não enchem de novo e os
#     guardas derrubam quem entra) e com os sobreviventes do livro (montados pelo ao_abrir).
# Mexa AQUI para: quantos/onde (LOCAIS), nomes, cores no mapa, distâncias e quantos infectados.

const LocalCls := preload("res://mundo/local.gd")
const AmbienteCls := preload("res://mundo/ambiente_local.gd")
const Malhas := preload("res://mundo/malhas.gd")
const Mat := preload("res://mundo/materiais_cidade.gd")
const ModeloInfectado := preload("res://inimigos/modelo_infectado.gd")     # 1.08: semente de soldado

const TAMANHO := {"posto": Vector2(46, 36), "hospital": Vector2(72, 54), "supermercado": Vector2(66, 56), "armazem": Vector2(66, 50),
	"delegacia": Vector2(56, 44), "escola": Vector2(70, 54), "metro": Vector2(64, 28), "quartel": Vector2(64, 50),
	"bunker": Vector2(28, 22), "igreja": Vector2(48, 66), "prefeitura": Vector2(96, 76),
	"porto": Vector2(160, 90), "hangar": Vector2(90, 70), "guarita": Vector2(30, 30)}
const NOMES := {"posto": "POSTO DE GASOLINA", "hospital": "HOSPITAL", "supermercado": "SUPERMERCADO", "armazem": "ARMAZÉM",
	"delegacia": "DELEGACIA", "escola": "ESCOLA", "metro": "ESTAÇÃO DO METRÔ", "quartel": "QUARTEL DA GUARDA NACIONAL",
	"bunker": "BUNKER", "igreja": "IGREJA", "prefeitura": "PREFEITURA DE NOVA YORK",
	"porto": "PORTO DE CONTÊINERES", "hangar": "HANGAR DE CARGA", "guarita": "GUARITA DE OBSERVAÇÃO"}
const CORES_MAPA := {"posto": Color(0.95, 0.45, 0.15), "hospital": Color(0.9, 0.2, 0.2), "supermercado": Color(0.3, 0.75, 0.35), "armazem": Color(0.35, 0.6, 0.95),
	"delegacia": Color(0.25, 0.4, 0.95), "escola": Color(0.95, 0.8, 0.2), "metro": Color(0.7, 0.45, 0.9), "quartel": Color(0.5, 0.65, 0.3),
	"bunker": Color(0.85, 0.85, 0.8), "igreja": Color(0.92, 0.88, 0.72), "prefeitura": Color(0.95, 0.75, 0.45),
	"porto": Color(0.3, 0.55, 0.85), "hangar": Color(0.85, 0.5, 0.2), "guarita": Color(0.45, 0.55, 0.28)}
const SIGLAS := {"igreja": "I", "prefeitura": "PF", "porto": "PT", "hangar": "HG", "guarita": "G", "posto": "P", "hospital": "H", "supermercado": "S", "armazem": "A", "delegacia": "D", "escola": "E", "metro": "M", "quartel": "Q", "bunker": "B"}
# 0.78: os 28 primeiros são os da 0.68 (a ordem não pode mudar: o loot salvo é "L<índice>_..."); os novos vêm depois
const N_LOCAIS_068 := 28

# [tipo, x, z, giro (frente para: 0 = sul +Z, 1 = leste +X, 2 = norte -Z, 3 = oeste -X)] · ferramentas/escolher_locais.gd
const LOCAIS := [
	["posto", 5591.0, 407.0, 3],
	["hospital", 5543.5, 1138.5, 1],
	["supermercado", 5494.0, -428.5, 0],
	["armazem", 4875.5, 527.5, 3],
	["hospital", -6120.5, -1676.0, 2],
	["hospital", 1331.0, -3891.5, 2],
	["hospital", -771.5, 4085.5, 0],
	["supermercado", -1599.0, -2486.0, 2],
	["supermercado", -740.0, -278.0, 0],
	["supermercado", 3435.5, 1150.5, 0],
	["supermercado", -5107.0, -2705.5, 3],
	["supermercado", -4178.0, -852.0, 1],
	["armazem", 2618.5, 1156.5, 2],
	["armazem", -3762.0, -2187.0, 2],
	["armazem", -833.5, -1936.0, 2],
	["armazem", -5103.0, 1100.5, 3],
	["armazem", 119.0, -4046.5, 3],
	["posto", -2630.5, 894.0, 0],
	["posto", -1631.5, 3504.5, 2],
	["posto", 1585.0, 826.5, 1],
	["posto", -5945.0, -663.5, 2],
	["posto", 802.0, -2322.0, 3],
	["posto", 1185.5, -4627.5, 0],
	["posto", -5474.0, -3762.0, 3],
	["posto", 3242.5, 4247.0, 1],
	["posto", -8136.5, 1964.5, 1],
	["posto", -2534.5, -2065.0, 1],
	["posto", -4897.0, 3363.0, 3],
	# 0.78 (ferramentas/escolher_locais.gd NOVOS=1): delegacias, escolas, estações do metrô e quartéis (na base)
	["delegacia", 4848.5, -207.0, 3],
	["escola", 4684.0, 1154.5, 0],
	["metro", 4223.0, 683.0, 2],
	["quartel", 6079.5, 531.5, 1],
	["quartel", 6725.5, 696.5, 2],
	["delegacia", -6405.0, 3178.0, 1],
	["delegacia", -2580.5, 2239.5, 0],
	["delegacia", 436.5, 1676.5, 1],
	["escola", -2971.0, -962.0, 3],
	["escola", 957.5, -760.0, 3],
	["escola", 5144.5, -1009.0, 1],
	["metro", -714.0, 2598.0, 3],
	["metro", -4247.0, -4053.5, 0],
	["metro", -1636.0, 407.0, 3],
	# 0.83 (ferramentas/escolher_bunkers.gd): BUNKERS, um por ilha, em terreno vazio (nenhum prédio saiu). A ordem
	# aqui é o NÚMERO do bunker (e do cartão): 1, 2, 3, 4.
	["bunker", 1784.5, -3733.5, 0],
	["bunker", -2751.5, 387.0, 3],
	["bunker", 3897.5, 1122.5, 0],
	["bunker", 532.5, -1086.0, 1],
	# 1.06 (ferramentas/escolher_locais.gd NOVOS=2): PREFEITURA (no centro, perto dos arranha-céus) e IGREJAS (uma por
	# ilha). Montados em mundo/local_igreja.gd.
	["prefeitura", -1610.0, -122.5, 3],
	["igreja", 1445.0, -3431.0, 0],
	["igreja", -2604.5, 1514.0, 3],
	["igreja", 3623.0, 1640.0, 3],
	["igreja", 603.5, -1608.5, 1],
	# 1.07 (ferramentas/escolher_portos.gd): PORTOS (na costa: o cais e o navio ficam atrás do terreno, em cima do mar)
	# e HANGARES DE CARGA. Montados em mundo/local_porto.gd.
	["porto", -400.0, -1200.0, 3],
	["porto", -1800.0, 4440.0, 1],
	["hangar", -902.0, 3465.0, 1],
	["hangar", 2025.0, 1575.0, 1],
	["hangar", -4261.0, -2895.5, 2],
	# 1.08 (ferramentas/escolher_guaritas.gd): GUARITAS DE OBSERVAÇÃO no meio dos campos (parques; nenhum prédio sai).
	# Montadas em mundo/local_guarita.gd.
	["guarita", -1695.5, -740.5, 3],
	["guarita", -1731.5, -1620.5, 1],
	["guarita", -2921.0, 4666.0, 0],
	["guarita", 2084.0, -3261.5, 1],
	["guarita", -1311.0, 269.5, 0],
	["guarita", -2932.5, 1088.0, 0],
	["guarita", -5791.5, -1062.0, 1],
	["guarita", -1425.5, -3462.5, 3],
]
# 1.06: os locais até aqui (índice < N_LOCAIS_105) já existiam na 1.05; os prédios que saíram para os de depois
# entram na conversão do save (mundo/cidade.gd remapa_v4)
const N_LOCAIS_105 := 46
const N_LOCAIS_106 := 51                 # 1.07: até aqui existiam na 1.06 (os portos tiram prédios: mundo/cidade.gd remapa_v5)
const N_LOCAIS_107 := 56                 # 1.08: até aqui existiam na 1.07 (as guaritas ficam nos parques: não tiram prédio)

# 0.83: ÁREAS MILITARES onde o CARTÃO DE ACESSO de um bunker pode aparecer (CHANCE_CARTAO a cada ciclo do loot, numa
# das caixas militares): os quartéis e o posto militar na frente de cada hospital. Só existe 1 cartão de cada bunker
# (mundo/loot_mundo.gd tentar_cartao).
const AREAS_MILITARES := ["quartel", "hospital", "prefeitura", "guarita"]   # 1.06: o posto do Exército na frente da prefeitura · 1.08: guaritas
# 1.08: onde parte dos infectados que nascem são SOLDADOS (farda e capacete: inimigos/modelo_infectado.gd SOLDADOS)
const COM_SOLDADOS := {"quartel": 0.6, "prefeitura": 0.35, "guarita": 0.8}
const TABELAS_MILITARES := ["militar", "militar_med", "quartel_arsenal"]

# número do bunker (1, 2, 3...) do local i (0 = não é bunker)
static func numero_bunker(i: int) -> int:
	if i < 0 or i >= LOCAIS.size() or LOCAIS[i][0] != "bunker":
		return 0
	var n := 0
	for k in i + 1:
		if LOCAIS[k][0] == "bunker":
			n += 1
	return n

static func quantos_bunkers() -> int:
	var n := 0
	for e in LOCAIS:
		if e[0] == "bunker":
			n += 1
	return n

# nome para o mapa e os avisos ("BUNKER 3")
static func nome(i: int) -> String:
	var n := numero_bunker(i)
	return "BUNKER %d" % n if n > 0 else String(NOMES[LOCAIS[i][0]])

const RAIO_ABRIR := 140.0              # da borda do terreno
const RAIO_FECHAR := 200.0
const MAX_ABERTOS := 2
const PERTO_INFECTADO := 14.0          # não nasce infectado mais perto que isso de você
const CICLO_INFECTADOS := 4.0          # 0.72: horas de jogo (4 h = 8 min de verdade)

# terreno no MUNDO (alinhado aos eixos)
static func retangulo(i: int, margem := 0.0) -> Rect2:
	var e: Array = LOCAIS[i]
	var t: Vector2 = TAMANHO[e[0]]
	if int(e[3]) % 2 == 1:
		t = Vector2(t.y, t.x)
	return Rect2(Vector2(e[1], e[2]) - t * 0.5, t).grow(margem)

static func local_para_mundo(i: int, p: Vector2) -> Vector2:
	var e: Array = LOCAIS[i]
	return Vector2(e[1], e[2]) + p.rotated(-int(e[3]) * PI * 0.5)

# índice do local cujo terreno contém p (-1 = nenhum)
static func em(p: Vector2, margem := 0.0) -> int:
	for i in LOCAIS.size():
		if retangulo(i, margem).has_point(p):
			return i
	return -1

# volumes grandes de cada tipo (para a casca de longe e o mapa): [centro local, tamanho, cor] (caixa)
# 1.06: + forma opcional no 4º campo: "cil" (cilindro em pé no tamanho da caixa; 5º campo = raio de cima, em fração),
# "cupula" (meia esfera com a base em y - tam.y/2), "prisma_z"/"prisma_x" (telhado de duas águas com a cumeeira ao
# longo de Z/X). Para o resto (tiro de longe, não nascer dentro) vale a caixa.
static func casca(tipo: String) -> Array:
	match tipo:
		# 1.08 (mundo/local_guarita.gd): as 4 pernas da torre, a cabine e o telhado
		"guarita":
			var aco := Color(0.42, 0.44, 0.4)
			var l: Array = []
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					l.append([Vector3(4.0 + sx * 2.1, 4.5, -4.0 + sz * 2.1), Vector3(0.3, 9.0, 0.3), aco])
			l.append([Vector3(4, 9.6, -4), Vector3(4.6, 1.2, 4.6), Color(0.55, 0.5, 0.38)])
			l.append([Vector3(4, 11.65, -4), Vector3(5.2, 0.14, 5.2), Color(0.3, 0.34, 0.22)])
			return l
		# 1.06 (mundo/local_igreja.gd)
		"igreja":
			var pd := Color(0.9, 0.88, 0.82)
			var ard := Color(0.3, 0.32, 0.34)
			var ig := [[Vector3(0, 1.2, -4.75), Vector3(26, 2.4, 51.5), Color(0.5, 0.49, 0.47)],
				[Vector3(0, 1.2, -17), Vector3(37, 2.4, 11), Color(0.5, 0.49, 0.47)],
				[Vector3(0, 8.9, 1.5), Vector3(22.5, 13.0, 27.5), pd],
				[Vector3(0, 8.9, -17), Vector3(36.5, 13.0, 10.5), pd],
				[Vector3(0, 7.9, -26), Vector3(14.5, 11.0, 8.5), pd],
				[Vector3(0, 17.65, -1.9), Vector3(23.4, 4.5, 20.6), ard, "prisma_z"],
				[Vector3(0, 17.4, -17), Vector3(37.4, 4.0, 10.6), ard, "prisma_x"],
				[Vector3(0, 14.7, -26), Vector3(14.6, 2.6, 8.6), ard, "prisma_z"],
				[Vector3(0, 11.95, 17.75), Vector3(20.6, 1.4, 6.2), Color(0.74, 0.71, 0.64)],
				[Vector3(0, 14.7, 17.8), Vector3(20.6, 3.8, 6.2), ard, "prisma_z"],
				[Vector3(0, 15.4, 11.7), Vector3(7.2, 14.0, 6.6), pd],
				[Vector3(0, 25.4, 11.7), Vector3(7.2, 6.0, 6.6), pd],
				[Vector3(0, 34.4, 11.7), Vector3(6.4, 9.0, 6.4), ard, "cil", 0.02],
				[Vector3(0, 20.1, -17), Vector3(12.4, 3.0, 12.4), pd, "cil"],
				[Vector3(0, 24.85, -17), Vector3(12.2, 6.1, 12.2), Color(0.36, 0.52, 0.46), "cupula"]]
			for x in [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5]:
				ig.append([Vector3(x, 6.9, 19.6), Vector3(1.2, 9.0, 1.2), pd, "cil"])
			return ig
		"prefeitura":
			var pp := Color(0.86, 0.83, 0.76)
			var pf := [[Vector3(0, 0.75, -9), Vector3(69, 1.5, 35), Color(0.5, 0.49, 0.47)],
				[Vector3(0, 0.75, 11.25), Vector3(25, 1.5, 6.5), Color(0.5, 0.49, 0.47)],
				[Vector3(0, 6.5, -9), Vector3(68.3, 10.0, 34.3), pp],
				[Vector3(0, 11.2, 11.1), Vector3(25.6, 1.4, 6.7), Color(0.74, 0.71, 0.64)],
				[Vector3(0, 13.6, 11.15), Vector3(25.6, 3.4, 6.7), Color(0.3, 0.32, 0.34), "prisma_z"],
				[Vector3(0, 15.2, -9), Vector3(17.2, 5.0, 17.2), pp, "cil"],
				[Vector3(0, 22.15, -9), Vector3(16.6, 8.3, 16.6), Color(0.36, 0.52, 0.46), "cupula"],
				[Vector3(0, 27.2, -9), Vector3(3.2, 2.8, 3.2), pp, "cil"]]
			for x in [-10.5, -7.5, -4.5, -1.5, 1.5, 4.5, 7.5, 10.5]:
				pf.append([Vector3(x, 6.0, 12.8), Vector3(1.2, 9.0, 1.2), pp, "cil"])
			return pf
		# 1.07 (mundo/local_porto.gd): o navio e os guindastes ficam atrás do terreno (z < -45), em cima do mar
		"porto":
			var az := Color(0.13, 0.32, 0.68)
			var pt := [[Vector3(-63, 4, 29), Vector3(22, 8, 18), Color(0.82, 0.8, 0.74)],
				[Vector3(60, 4.5, 28), Vector3(32, 9, 24), Color(0.62, 0.66, 0.7)],
				[Vector3(60, 10.1, 28), Vector3(32.6, 2.2, 24.6), Color(0.53, 0.56, 0.6), "prisma_x"],
				[Vector3(0, -1.6, -46), Vector3(160, 3.2, 14), Color(0.6, 0.59, 0.56)],
				[Vector3(-4, 0.5, -66), Vector3(132, 17, 24), Color(0.1, 0.13, 0.26)],
				[Vector3(2.4, 14.1, -66.5), Vector3(100.3, 9.6, 20.6), Color(0.55, 0.3, 0.25)],
				[Vector3(-57, 16.5, -66), Vector3(14, 15, 18), Color(0.92, 0.92, 0.9)],
				[Vector3(-57, 25.65, -66), Vector3(14.8, 3.3, 18.8), Color(0.92, 0.92, 0.9)],
				[Vector3(-67, 20, -66), Vector3(4.6, 22, 6), Color(0.65, 0.13, 0.11)]]
			for zb in [3.0, -9.2, -21.4]:
				for s in [-1.0, 1.0]:
					pt.append([Vector3(s * 42.5, 3.4, zb + 4.1), Vector3(63, 6.8, 8.2), Color(0.5, 0.35, 0.3) if s < 0 else Color(0.3, 0.4, 0.5)])
			for xg in [5.0, 35.0, 62.0]:
				for x in [xg - 8.0, xg + 8.0]:
					for z in [-33.0, -50.5]:
						pt.append([Vector3(x, 14, z), Vector3(1.4, 28, 1.4), az])
					pt.append([Vector3(x, 27.25, -41.75), Vector3(1.5, 1.5, 17.5), az])
				pt.append([Vector3(xg, 31.5, -53.5), Vector3(5.4, 1.6, 77), az])
				pt.append([Vector3(xg, 34.1, -24), Vector3(7, 3.6, 9), Color(0.9, 0.9, 0.88)])
				pt.append([Vector3(xg, 39.4, -41), Vector3(4.4, 14, 1.0), az])
			return pt
		"hangar":
			return [[Vector3(0, 0.6, -14), Vector3(64, 1.2, 34), Color(0.42, 0.41, 0.39)],
				[Vector3(0, 6.2, -14), Vector3(64.3, 10, 34.3), Color(0.68, 0.7, 0.72)],
				[Vector3(0, 12.5, -14), Vector3(64, 2.6, 34), Color(0.56, 0.58, 0.6)],
				[Vector3(-38, 5.0, 14), Vector3(8, 0.4, 6), Color(0.75, 0.3, 0.08)],
				[Vector3(-28, 2.05, 9.2), Vector3(2.55, 3.5, 12), Color(0.85, 0.85, 0.83)],
				[Vector3(-12, 2.05, 9.2), Vector3(2.55, 3.5, 12), Color(0.85, 0.85, 0.83)],
				[Vector3(12, 2.05, 9.2), Vector3(2.55, 3.5, 12), Color(0.85, 0.85, 0.83)]]
		"posto":
			return [[Vector3(-6, 2.6, -11), Vector3(30.3, 5.2, 12.3), Color(0.76, 0.74, 0.68)],
				[Vector3(2, 5.65, 6.5), Vector3(24, 0.9, 13), Color(0.72, 0.12, 0.1)],
				[Vector3(19.5, 5.0, 15), Vector3(2.8, 10.0, 0.5), Color(0.85, 0.85, 0.83)]]
		"hospital":
			return [[Vector3(0, 5.15, -14), Vector3(60.3, 10.3, 24.3), Color(0.84, 0.82, 0.76)],
				[Vector3(1.35, 10.8, -20.5), Vector3(3.9, 3.0, 10.2), Color(0.6, 0.59, 0.56)],
				[Vector3(0, 4.2, 1.0), Vector3(12, 0.4, 6), Color(0.82, 0.82, 0.8)],
				[Vector3(23, 4.8, 2.5), Vector3(12, 0.4, 9), Color(0.82, 0.82, 0.8)]]
		"supermercado":
			return [[Vector3(0, 3.75, -9.5), Vector3(56.3, 7.5, 25.3), Color(0.78, 0.76, 0.7)],
				[Vector3(0, 5.0, 3.3), Vector3(30, 2.2, 0.3), Color(0.12, 0.45, 0.22)]]
		"armazem":
			return [[Vector3(-2, 4.7, -10), Vector3(52.3, 9.4, 26.3), Color(0.58, 0.63, 0.66)],
				[Vector3(29.6, 2.6, -18), Vector3(2.44, 5.2, 6.06), Color(0.4, 0.3, 0.25)],
				[Vector3(29.6, 2.6, 12.4), Vector3(2.44, 5.2, 6.06), Color(0.5, 0.4, 0.3)],
				[Vector3(-19.75, 2.4, 9.6), Vector3(2.55, 3.6, 12), Color(0.85, 0.85, 0.83)]]
		# 0.78 (mundo/local_novos.gd)
		"delegacia":
			return [[Vector3(0, 5.15, -10), Vector3(40.3, 10.3, 20.3), Color(0.55, 0.34, 0.26)],
				[Vector3(1.4, 10.7, -14.6), Vector3(3.7, 3.0, 8.9), Color(0.6, 0.59, 0.56)],
				[Vector3(0, 3.35, 1.25), Vector3(7.0, 0.3, 2.5), Color(0.42, 0.41, 0.39)]]
		"escola":
			return [[Vector3(0, 5.15, -17), Vector3(60.3, 10.3, 16.3), Color(0.62, 0.42, 0.32)],
				[Vector3(-5.8, 10.7, -16.35), Vector3(3.5, 3.0, 9.6), Color(0.6, 0.59, 0.56)],
				[Vector3(20, 12.0, -17), Vector3(3.8, 4.0, 3.8), Color(0.45, 0.35, 0.25)],
				[Vector3(16, 1.45, 19), Vector3(11.0, 2.9, 2.5), Color(0.92, 0.66, 0.08)]]
		"metro":
			var m := [[Vector3(-5, 5.6, -2), Vector3(54, 0.8, 12), Color(0.42, 0.41, 0.39)],
				[Vector3(-5, 10.1, -6.5), Vector3(40, 0.2, 3.8), Color(0.55, 0.58, 0.56)],
				[Vector3(-5, 10.1, 2.5), Vector3(40, 0.2, 3.8), Color(0.55, 0.58, 0.56)],
				[Vector3(-5, 6.55, -6.5), Vector3(54, 1.1, 3), Color(0.63, 0.62, 0.59)],
				[Vector3(-5, 6.55, 2.5), Vector3(54, 1.1, 3), Color(0.63, 0.62, 0.59)],
				[Vector3(-4.8, 8.47, -3.5), Vector3(44.4, 2.74, 2.9), Color(0.68, 0.7, 0.72)],
				[Vector3(27, 1.8, -2), Vector3(10, 3.0, 12), Color(0.42, 0.41, 0.39)]]
			for k in 6:
				for z in [-7.5, 3.5]:
					m.append([Vector3(-30 + k * 10, 2.6, z), Vector3(0.6, 5.2, 0.6), Color(0.24, 0.32, 0.27)])
			return m
		"bunker":
			return [[Vector3(0, 1.6, -5.0), Vector3(10.0, 3.2, 8.0), Color(0.5, 0.5, 0.48)]]
		"quartel":
			var cq := Color(0.5, 0.52, 0.42)
			var hs := Color(0.62, 0.55, 0.4)
			return [[Vector3(-13, 1.95, -15.5), Vector3(30.3, 3.9, 11.3), cq],
				[Vector3(18, 1.95, -15), Vector3(20.3, 3.9, 12.3), cq],
				[Vector3(-27, 4.25, 19), Vector3(3.8, 8.5, 3.8), Color(0.45, 0.36, 0.25)],
				[Vector3(27, 4.25, 19), Vector3(3.8, 8.5, 3.8), Color(0.45, 0.36, 0.25)],
				[Vector3(-18.15, 1.05, 24.3), Vector3(27.7, 2.1, 1.4), hs],
				[Vector3(18.15, 1.05, 24.3), Vector3(27.7, 2.1, 1.4), hs],
				[Vector3(-11.65, 1.05, -24.3), Vector3(40.7, 2.1, 1.4), hs],
				[Vector3(22.15, 1.05, -24.3), Vector3(19.7, 2.1, 1.4), hs],
				[Vector3(-31.3, 1.05, -14.15), Vector3(1.4, 2.1, 21.7), hs],
				[Vector3(-31.3, 1.05, 12.15), Vector3(1.4, 2.1, 25.7), hs],
				[Vector3(31.3, 1.05, 0), Vector3(1.4, 2.1, 50.0), hs],
				[Vector3(19, 1.7, 4), Vector3(2.4, 3.4, 7.5), Color(0.27, 0.31, 0.2)],
				[Vector3(25, 1.7, 4.5), Vector3(2.4, 3.4, 7.5), Color(0.27, 0.31, 0.2)]]
	return []

# está dentro de um prédio de algum local (volumes grandes da casca)? Para não nascer infectado/caixa dentro das paredes
# e (0.79) para os infectados sem física não atravessarem as construções. Grade de 100 m (é chamada muitas vezes).
const CEL_VOL := 100.0
static var _vol_hash := {}            # Vector2i -> Array[Rect2]

static func em_construcao(p: Vector2, margem := 0.0) -> bool:
	if _vol_hash.is_empty():
		for i in LOCAIS.size():
			for v in casca(LOCAIS[i][0]):
				var c3: Vector3 = v[0]
				var t3: Vector3 = v[1]
				if t3.y < 2.5:
					continue
				var a := local_para_mundo(i, Vector2(c3.x, c3.z) - Vector2(t3.x, t3.z) * 0.5)
				var b := local_para_mundo(i, Vector2(c3.x, c3.z) + Vector2(t3.x, t3.z) * 0.5)
				var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())
				for cz in range(floori(r.position.y / CEL_VOL), floori(r.end.y / CEL_VOL) + 1):
					for cx in range(floori(r.position.x / CEL_VOL), floori(r.end.x / CEL_VOL) + 1):
						var k := Vector2i(cx, cz)
						if not _vol_hash.has(k):
							_vol_hash[k] = []
						_vol_hash[k].append(r)
	var k0 := Vector2i(floori(p.x / CEL_VOL), floori(p.y / CEL_VOL))
	var alcance := ceili(margem / CEL_VOL)
	for dz in range(-alcance, alcance + 1):
		for dx in range(-alcance, alcance + 1):
			var lista = _vol_hash.get(k0 + Vector2i(dx, dz))
			if lista == null:
				continue
			for r in lista:
				if (r as Rect2).grow(margem).has_point(p):
					return true
	return false

# 0.74: volumes grandes de todos os locais no MUNDO (caixas alinhadas), para o tiro de longe (mundo/colisao_mundo.gd
# raio): [[índice do local, AABB], ...]. y = altura do chão do terreno
static func volumes_mundo(y: float) -> Array:
	var r := []
	for i in LOCAIS.size():
		var e: Array = LOCAIS[i]
		for v in casca(e[0]):
			var c3: Vector3 = v[0]
			var t3: Vector3 = v[1]
			var c := local_para_mundo(i, Vector2(c3.x, c3.z))
			var t := Vector2(t3.z, t3.x) if int(e[3]) % 2 == 1 else Vector2(t3.x, t3.z)
			r.append([i, AABB(Vector3(c.x - t.x * 0.5, y + c3.y - t3.y * 0.5, c.y - t.y * 0.5), Vector3(t.x, t3.y, t.y))])
	return r

# telhado de duas águas da casca (base em "o", cumeeira ao longo de Z ou X)
static func _casca_prisma(c, o: Vector3, t: Vector3, eixo_z: bool, cor: Color) -> void:
	var ax := Vector3(0, 0, t.z * 0.5) if eixo_z else Vector3(t.x * 0.5, 0, 0)
	var tr := Vector3(t.x * 0.5, 0, 0) if eixo_z else Vector3(0, 0, t.z * 0.5)
	var topo := Vector3.UP * t.y
	for s in [-1.0, 1.0]:
		var b: Vector3 = o + ax * s
		var nn: Vector3 = ax.normalized() * s
		var pts := [b - tr, b + tr, b + topo]
		if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(nn) < 0.0:
			pts.reverse()
		c._quad(pts[0], pts[1], pts[2], pts[2], nn, cor, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	for s in [-1.0, 1.0]:
		var nn: Vector3 = (tr.normalized() * t.y * s + Vector3.UP * tr.length()).normalized()
		var pts := [o - ax + tr * s, o + ax + tr * s, o + ax + topo, o - ax + topo]
		if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(nn) < 0.0:
			pts.reverse()
		c._quad(pts[0], pts[1], pts[2], pts[3], nn, cor, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

# casca de longe de um local (nó da cidade; os chunks põem/tiram da cena)
static func montar_casca(i: int, y: float) -> MeshInstance3D:
	var e: Array = LOCAIS[i]
	var c := Malhas.Construtor.new()
	for v in casca(e[0]):
		var f := String(v[3]) if v.size() > 3 else ""
		var o: Vector3 = v[0]
		var t: Vector3 = v[1]
		match f:
			"cil":
				c.cilindro(o, t.x * 0.5, t.y, 12, v[2], Basis.IDENTITY, t.x * 0.5 * (float(v[4]) if v.size() > 4 else 1.0))
			"cupula":
				for k in 5:
					var a0 := PI * 0.5 * k / 5.0
					var a1 := PI * 0.5 * (k + 1) / 5.0
					var yb := o.y - t.y * 0.5
					c.cilindro(Vector3(o.x, yb + (sin(a0) + sin(a1)) * 0.5 * t.y, o.z), cos(a0) * t.x * 0.5, (sin(a1) - sin(a0)) * t.y, 12, v[2], Basis.IDENTITY, maxf(cos(a1) * t.x * 0.5, 0.01))
			"prisma_z", "prisma_x":
				_casca_prisma(c, o - Vector3(0, t.y * 0.5, 0), t, f == "prisma_z", v[2])
			_:
				c.caixa(o, t, v[2])
	var mi := MeshInstance3D.new()
	mi.name = "LocalCasca_%d" % i
	mi.mesh = c.malha(Mat.material(Mat.INTERIOR, {"caixa": Vector4(0, 0, -1, -1), "padrao": 4.0, "sujeira": 0.45}))
	mi.transform = Transform3D(LocalCls.base_giro(int(e[3])), Vector3(e[1], y, e[2]))
	mi.visibility_range_end = 3500.0
	return mi

# ---------------------------------------------------------------------------------------------------
var cidade = null
var jogador: Node3D = null
var loot = null
var vagos = null
var mundo = null                       # 0.74: mundo/colisao_mundo.gd (casca no tiro de longe)
var clima = null                       # 0.77: mundo/clima.gd (as luzes acendem à noite)
var hud = null                         # armas/hud_combate.gd (aviso ao entrar)
var abertos := {}                      # índice -> Node3D
var ativo := true
var centros_extra := Callable()        # 0.74: host: posições dos amigos (abre também os locais perto deles)
var ao_abrir := Callable()             # 0.91: (índice, nó) depois de montar um local (npc/hospitais.gd põe os NPCs)
var usar_thread := true
var _infestados := {}                  # local -> ciclo em que foi enchido (nesta partida)
var _dentro := -1
var _t := 0.0
var _tarefa := -1
var _tarefa_i := -1
var _tarefa_res = null

func ligar(cid, jog: Node3D, lm) -> void:
	cidade = cid
	jogador = jog
	loot = lm

static func _dist(p: Vector2, i: int) -> float:
	var r := retangulo(i)
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)

func _process(dt: float) -> void:
	if not ativo or jogador == null or cidade == null:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.25
	if _tarefa >= 0:
		if not WorkerThreadPool.is_task_completed(_tarefa):
			_t = 0.03
			return
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
		_terminar(_tarefa_i, _tarefa_res)
		_tarefa_res = null
	var p := Vector2(jogador.global_position.x, jogador.global_position.z)
	var centros: Array[Vector2] = [p]
	if centros_extra.is_valid():
		for q in centros_extra.call():
			centros.append(Vector2((q as Vector3).x, (q as Vector3).z))
	for i in abertos.keys():
		var dmin := INF
		for pc in centros:
			dmin = minf(dmin, _dist(pc, i))
		if dmin > RAIO_FECHAR:
			fechar(i)
	var melhor := -1
	var md := RAIO_ABRIR
	for i in LOCAIS.size():
		if abertos.has(i):
			continue
		for pc in centros:
			var d := _dist(pc, i)
			if d < md:
				md = d
				melhor = i
	if melhor >= 0 and abertos.size() < MAX_ABERTOS + centros.size() - 1:
		abrir(melhor)
	# 0.83: lá embaixo de um bunker: escuro total (mundo/clima.gd)
	if clima != null:
		var sub := false
		var ib := em(p, 8.0)
		if ib >= 0 and LOCAIS[ib][0] == "bunker" and jogador.global_position.y < cidade.Y_CALCADA - 4.0:
			sub = true
		clima.set("subsolo", sub)
	# entrou numa zona de PvP: aviso
	var agora := em(p, 4.0)
	if agora != _dentro:
		_dentro = agora
		if agora >= 0 and LOCAIS[agora][0] == "bunker" and hud != null and hud.has_method("mostrar_aviso"):
			hud.mostrar_aviso("%s · ÁREA RESTRITA · a porta só abre com o CARTÃO DE ACESSO %d" % [nome(agora), numero_bunker(agora)], 5.0)
		elif agora >= 0 and LOCAIS[agora][0] == "hospital":
			pass                                       # 0.91: zona neutra (o aviso é do npc/hospitais.gd)
		elif agora >= 0 and hud != null and hud.has_method("mostrar_aviso"):
			hud.mostrar_aviso("%s · ZONA DE PvP · loot raro, cuidado com outros sobreviventes" % NOMES[LOCAIS[agora][0]], 5.0)
			var mus := get_node_or_null("/root/Musica")
			if mus != null:
				mus.adicionar_tensao(0.15)

func abrir(i: int, ja := false) -> void:
	if abertos.has(i) or _tarefa >= 0:
		return
	var e: Array = LOCAIS[i]
	if usar_thread and not ja:
		_tarefa_i = i
		# 0.91: os valores vão prontos no bind (a função anônima que lia "e" na thread recebeu, uma vez, um número
		# no lugar do tipo do local)
		_tarefa = WorkerThreadPool.add_task(_preparar_na_thread.bind(String(e[0]), i, int(e[3]), Vector2(e[1], e[2])), false, "local")
		return
	_terminar(i, LocalCls.preparar(String(e[0]), i, int(e[3]), Vector2(e[1], e[2])))

func _preparar_na_thread(t: String, i: int, gi: int, c: Vector2) -> void:
	_tarefa_res = LocalCls.preparar(t, i, gi, c)

# abre já, sem thread (nascer/carregar o jogo dentro de um local)
func abrir_agora(p: Vector2) -> void:
	for i in LOCAIS.size():
		if _dist(p, i) <= 30.0:
			if _tarefa >= 0:
				WorkerThreadPool.wait_for_task_completion(_tarefa)
				_tarefa = -1
				_terminar(_tarefa_i, _tarefa_res)
				_tarefa_res = null
			abrir(i, true)

func _terminar(i: int, prep) -> void:
	if prep == null or abertos.has(i):
		return
	var no: Node3D = prep.criar(loot, cidade.Y_CALCADA)
	add_child(no)
	abertos[i] = no
	var amb = AmbienteCls.new()              # 0.77: luz e som
	amb.name = "Ambiente"
	amb.tipo = LOCAIS[i][0]
	amb.indice = i
	amb.volumes = casca(LOCAIS[i][0])
	amb.clima = clima
	no.add_child(amb)
	if mundo != null:
		mundo.locais_abertos[i] = true          # 0.74: aberto tem colisão de verdade (o tiro de longe não usa a casca)
	var casca_no = cidade.locais_casca[i] if i < cidade.locais_casca.size() else null
	if casca_no != null and is_instance_valid(casca_no):
		casca_no.visible = false
	if loot != null:
		loot.espalhar_chao("L%d" % i, String(LOCAIS[i][0]), no.get_meta("pontos_chao"), no)
		# 0.83: área militar: chance de aparecer o cartão de um bunker numa das caixas militares
		if LOCAIS[i][0] in AREAS_MILITARES and loot.has_method("tentar_cartao"):
			var grades: Array = []
			for k in prep.cont.size():
				if String(prep.cont[k]["loot"]) in TABELAS_MILITARES:
					grades.append("L%d_%d" % [i, k])
			loot.tentar_cartao("L%d" % i, grades, quantos_bunkers())
	_infestar(i, no, prep.infectados)
	if ao_abrir.is_valid():
		ao_abrir.call(i, no)

func _infestar(i: int, no: Node3D, pontos: Array) -> void:
	if vagos == null or not bool(vagos.get("ativo")) or LOCAIS[i][0] == "hospital":   # 0.91: hospital = zona neutra
		return
	var c := ciclo_infectados(i)
	if int(_infestados.get(i, -1)) >= c:
		return
	_infestados[i] = c
	var t: Vector2 = TAMANHO[LOCAIS[i][0]]
	var ainda: int = vagos.vivos_perto(no.global_position, maxf(t.x, t.y) * 0.5 + 10.0)
	var falta := pontos.size() - ainda          # só completa o que falta (os de antes ainda estão por aí)
	var soldados: float = COM_SOLDADOS.get(LOCAIS[i][0], 0.0)
	for lp in pontos:
		if falta <= 0:
			break
		var gp: Vector3 = no.global_transform * (lp as Vector3)
		if jogador != null and gp.distance_to(jogador.global_position) < PERTO_INFECTADO:
			continue
		# 1.08: nas áreas do Exército, parte deles é SOLDADO (farda camuflada e capacete)
		vagos._criar(gp + Vector3(0, 0.05, 0), Vector3.INF, false, "", ModeloInfectado.semente_soldado() if randf() < soldados else -1)
		falta -= 1

func ciclo_infectados(i: int) -> int:
	var h: float = loot.horas() if loot != null else 0.0
	return floori((h + fposmod(i * 0.618034, 1.0) * CICLO_INFECTADOS) / CICLO_INFECTADOS)

func fechar(i: int) -> void:
	if not abertos.has(i):
		return
	var no: Node3D = abertos[i]
	abertos.erase(i)
	if mundo != null:
		mundo.locais_abertos.erase(i)
	if loot != null and is_instance_valid(no):
		loot.guardar_chao("L%d" % i, no)
	if is_instance_valid(no):
		no.queue_free()
	var casca_no = cidade.locais_casca[i] if i < cidade.locais_casca.size() else null
	if casca_no != null and is_instance_valid(casca_no):
		casca_no.visible = true

func fechar_todos() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
		_tarefa_res = null
	for i in abertos.keys():
		fechar(i)

func _exit_tree() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
