extends RefCounted
# 1.08 · COMBOIOS DO EXÉRCITO abandonados pelas ruas (a evacuação do Dia -1: "dirijam-se ao sul"). Entram junto com os
# carros largados (mundo/abandono.gd, etapa "Comboios do Exército"): mesma semente em todo aparelho (o multijogador não
# manda nada), MultiMesh por bloco com a versão simples de longe, OBSTÁCULOS de colisão e a lista de CARROS (o
# porta-malas vira uma caixa "militar": mundo/interiores.gd; o HUMVEE e o CAMINHÃO podem funcionar: mundo/veiculos.gd).
#   · COMBOIOS colunas de 4 a 9 veículos numa avenida (pista da direita), espaçadas, com alguns queimados e
#     atravessados; ~40% com um TANQUE; às vezes um bloqueio de barreiras e sacos de areia na frente.
#   · Tipos: "humvee" (jipe), "mrap" (blindado), "caminhao_exercito" (lona), "caminhao_tanque" (combustível), "tanque".
#   · CENTROS: o meio de cada comboio (inimigos/soldados.gd põe os SOLDADOS INFECTADOS perto).
#   · O TANQUE tem caixotes de munição atrás e o cesto atrás da torre (degraus de até 0,8 m; o pulo sobe 0,9 m): dá
#     para subir no casco e na torre pulando.
# Os modelos são feitos aqui (caixas e cilindros), com a frente em +X como os carros do abandono.
# Mexa AQUI para: quantos comboios (N), o tamanho, as chances e os modelos.

const Malhas := preload("res://mundo/malhas.gd")
const Locais := preload("res://mundo/locais.gd")

const N := 30
const DIST_ENTRE := 550.0               # entre dois comboios
const TRECHO_MIN := 110.0               # trecho de avenida (entre dois cruzamentos) que cabe um comboio
const LONGE_CRUZAMENTO := 28.0          # o 1º veículo para antes do cruzamento (fora da faixa de pedestres)
const MAX_NA_PISTA := 1                 # carros largados que podem estar na pista escolhida (senão procura outra)
const MODELOS := ["humvee", "mrap", "caminhao_exercito", "caminhao_tanque", "tanque", "sacos_areia"]
# tamanho da caixa de colisão (comprimento x altura x largura) e o comprimento para o porta-malas
const TAM := {"humvee": Vector3(4.9, 1.95, 2.2), "mrap": Vector3(6.4, 2.9, 2.5), "caminhao_exercito": Vector3(8.0, 3.3, 2.5),
	"caminhao_tanque": Vector3(8.0, 3.0, 2.5), "tanque": Vector3(7.9, 2.4, 3.6)}
const NOMES := {"humvee": "HUMVEE", "mrap": "BLINDADO", "caminhao_exercito": "CAMINHÃO DO EXÉRCITO", "caminhao_tanque": "CAMINHÃO-TANQUE",
	"tanque": "TANQUE"}
const CORES := [Color(0.3, 0.34, 0.22), Color(0.28, 0.31, 0.2), Color(0.58, 0.52, 0.38), Color(0.35, 0.37, 0.28)]
const QUEIMADO := Color(0.13, 0.11, 0.1)
const SEQUENCIA := ["humvee", "mrap", "caminhao_exercito", "caminhao_exercito", "tanque", "caminhao_tanque", "caminhao_exercito", "mrap", "humvee"]

# ---------- modelos (frente em +X) ----------
static func modelo(nome: String) -> ArrayMesh:
	var c := Malhas.Construtor.new()
	var vidro := Color(0.08, 0.09, 0.1)
	var pneu := Color(0.05, 0.05, 0.05)
	var ferro := Color(0.12, 0.12, 0.12)
	var roda := Basis(Vector3.RIGHT, PI * 0.5)
	match nome:
		"humvee":
			c.caixa(Vector3(0, 0.95, 0), Vector3(4.9, 0.75, 2.18), Color.WHITE)                       # corpo largo e baixo
			c.caixa(Vector3(1.55, 1.42, 0), Vector3(1.7, 0.22, 2.0), Color(0.95, 0.95, 0.95), Basis(Vector3.BACK, -0.08))   # capô
			c.caixa(Vector3(-0.55, 1.7, 0), Vector3(2.5, 0.78, 2.06), Color(0.97, 0.97, 0.97))       # cabine
			c.caixa(Vector3(0.71, 1.7, 0), Vector3(0.04, 0.5, 1.8), vidro)                            # para-brisa
			for z in [-1.04, 1.04]:
				c.caixa(Vector3(-0.4, 1.75, z), Vector3(1.6, 0.42, 0.04), vidro)
			c.caixa(Vector3(2.47, 0.95, 0), Vector3(0.08, 0.5, 1.5), Color(0.15, 0.15, 0.13))         # grade
			for z in [-0.7, 0.7]:
				c.caixa(Vector3(2.47, 1.12, z), Vector3(0.05, 0.14, 0.24), Color(1.4, 1.4, 1.2))
			c.cilindro(Vector3(-0.7, 2.18, 0), 0.55, 0.18, 10, Color(0.9, 0.9, 0.9))                 # anel da torreta
			c.caixa(Vector3(-0.55, 2.42, 0), Vector3(0.12, 0.45, 0.9), Color(0.9, 0.9, 0.9))          # escudo
			c.cilindro(Vector3(-0.1, 2.45, 0), 0.04, 1.1, 6, ferro, Basis(Vector3.FORWARD, PI * 0.5)) # metralhadora
			c.cilindro(Vector3(-2.5, 1.35, 0), 0.4, 0.22, 10, pneu, Basis(Vector3.FORWARD, PI * 0.5)) # estepe
			c.caixa(Vector3(2.0, 2.15, 0.9), Vector3(0.04, 1.6, 0.04), ferro)                         # antena
			for x in [1.6, -1.6]:
				for z in [1.0, -1.0]:
					c.cilindro(Vector3(x, 0.45, z), 0.45, 0.34, 10, pneu, roda)
		"mrap":
			c.caixa(Vector3(0, 0.9, 0), Vector3(6.0, 0.5, 2.3), Color(0.85, 0.85, 0.85))              # casco em V (embaixo)
			c.caixa(Vector3(-0.4, 1.95, 0), Vector3(4.8, 1.7, 2.5), Color.WHITE)                      # caixa blindada
			c.caixa(Vector3(2.35, 1.55, 0), Vector3(1.5, 1.0, 2.4), Color(0.96, 0.96, 0.96))          # capô alto
			c.caixa(Vector3(1.97, 2.35, 0), Vector3(0.04, 0.6, 2.0), vidro, Basis(Vector3.BACK, -0.25))
			for z in [-1.26, 1.26]:
				c.caixa(Vector3(0.8, 2.3, z), Vector3(1.2, 0.5, 0.04), vidro)
				c.caixa(Vector3(-1.2, 2.3, z), Vector3(0.6, 0.4, 0.04), vidro)
			c.caixa(Vector3(3.12, 1.4, 0), Vector3(0.1, 0.7, 2.0), Color(0.15, 0.15, 0.13))
			for z in [-0.85, 0.85]:
				c.caixa(Vector3(3.12, 1.85, z), Vector3(0.06, 0.16, 0.3), Color(1.4, 1.4, 1.2))
			c.cilindro(Vector3(-0.8, 2.95, 0), 0.6, 0.2, 10, Color(0.9, 0.9, 0.9))
			c.caixa(Vector3(-0.6, 3.25, 0), Vector3(0.14, 0.5, 1.0), Color(0.9, 0.9, 0.9))
			c.cilindro(Vector3(-0.05, 3.28, 0), 0.05, 1.2, 6, ferro, Basis(Vector3.FORWARD, PI * 0.5))
			c.caixa(Vector3(-2.85, 1.9, 0), Vector3(0.08, 1.4, 1.0), Color(0.9, 0.9, 0.9))            # porta de trás
			for x in [2.0, -0.6, -2.2]:
				for z in [1.08, -1.08]:
					c.cilindro(Vector3(x, 0.6, z), 0.6, 0.4, 12, pneu, roda)
		"caminhao_exercito":
			c.caixa(Vector3(0, 1.05, 0), Vector3(8.0, 0.4, 2.3), Color(0.8, 0.8, 0.8))                # chassi
			c.caixa(Vector3(2.9, 1.95, 0), Vector3(2.0, 1.7, 2.4), Color.WHITE)                       # cabine
			c.caixa(Vector3(3.91, 2.3, 0), Vector3(0.04, 0.7, 2.1), vidro)
			c.caixa(Vector3(3.95, 1.3, 0), Vector3(0.1, 0.6, 2.2), Color(0.15, 0.15, 0.13))
			c.caixa(Vector3(-1.1, 1.6, 0), Vector3(5.4, 0.7, 2.5), Color(0.95, 0.95, 0.95))           # carroceria
			c.caixa(Vector3(-1.1, 2.75, 0), Vector3(5.4, 1.6, 2.55), Color(1.15, 1.15, 1.05))         # lona
			for k in 4:
				c.caixa(Vector3(-3.4 + k * 1.5, 3.57, 0), Vector3(0.08, 0.06, 2.58), Color(0.9, 0.9, 0.85))
			for x in [2.8, -1.4, -2.8]:
				for z in [1.05, -1.05]:
					c.cilindro(Vector3(x, 0.55, z), 0.55, 0.4, 12, pneu, roda)
		"caminhao_tanque":
			c.caixa(Vector3(0, 1.05, 0), Vector3(8.0, 0.4, 2.3), Color(0.8, 0.8, 0.8))
			c.caixa(Vector3(2.9, 1.95, 0), Vector3(2.0, 1.7, 2.4), Color.WHITE)
			c.caixa(Vector3(3.91, 2.3, 0), Vector3(0.04, 0.7, 2.1), vidro)
			c.cilindro(Vector3(-1.1, 2.2, 0), 1.15, 5.4, 14, Color(0.95, 0.95, 0.95), Basis(Vector3.FORWARD, PI * 0.5))     # o tanque
			for x in [-3.85, 1.65]:
				c.cilindro(Vector3(x, 2.2, 0), 1.2, 0.1, 14, Color(0.8, 0.8, 0.8), Basis(Vector3.FORWARD, PI * 0.5))
			c.caixa(Vector3(-1.1, 2.0, 1.16), Vector3(1.6, 0.5, 0.04), Color(1.4, 0.9, 0.2))           # placa de inflamável
			c.caixa(Vector3(-1.1, 2.0, -1.16), Vector3(1.6, 0.5, 0.04), Color(1.4, 0.9, 0.2))
			for x in [2.8, -1.4, -2.8]:
				for z in [1.05, -1.05]:
					c.cilindro(Vector3(x, 0.55, z), 0.55, 0.4, 12, pneu, roda)
		"tanque":
			c.caixa(Vector3(0, 1.05, 0), Vector3(7.4, 0.9, 2.4), Color.WHITE)                         # casco
			c.caixa(Vector3(3.9, 1.0, 0), Vector3(1.0, 0.6, 2.4), Color(0.95, 0.95, 0.95), Basis(Vector3.BACK, 0.5))       # frente inclinada
			for z in [-1.45, 1.45]:
				c.caixa(Vector3(0, 0.55, z), Vector3(7.8, 1.0, 0.7), Color(0.16, 0.16, 0.15))            # esteiras
				c.caixa(Vector3(0, 1.25, z), Vector3(7.6, 0.45, 0.8), Color(0.9, 0.9, 0.9))              # saias
				for k in 7:
					c.cilindro(Vector3(-3.0 + k * 1.0, 0.45, z * 1.08), 0.38, 0.12, 10, Color(0.2, 0.2, 0.19), roda)
			c.caixa(Vector3(-0.6, 2.0, 0), Vector3(3.8, 1.0, 3.0), Color(0.97, 0.97, 0.97))           # torre
			c.caixa(Vector3(1.4, 1.95, 0), Vector3(0.6, 0.8, 2.4), Color(0.95, 0.95, 0.95), Basis(Vector3.BACK, 0.35))
			c.cilindro(Vector3(4.1, 2.05, 0), 0.13, 5.2, 8, Color(0.9, 0.9, 0.9), Basis(Vector3.FORWARD, PI * 0.5), 0.1)   # canhão
			c.cilindro(Vector3(2.0, 2.05, 0), 0.22, 1.0, 8, Color(0.9, 0.9, 0.9), Basis(Vector3.FORWARD, PI * 0.5))
			c.cilindro(Vector3(-0.9, 2.62, 0.6), 0.35, 0.2, 10, Color(0.9, 0.9, 0.9))                 # escotilha
			c.cilindro(Vector3(-0.9, 2.95, 0.6), 0.04, 0.9, 6, ferro, Basis(Vector3.FORWARD, PI * 0.5))
			c.caixa(Vector3(-2.95, 1.8, 0), Vector3(0.8, 0.6, 2.8), Color(0.85, 0.85, 0.82))          # cesto de trás (degrau para a torre)
			# caixotes de munição largados atrás (o degrau para subir: colisão em _veiculo)
			var cx := Color(0.24, 0.26, 0.17)
			c.caixa(Vector3(-4.45, 0.35, -0.9), Vector3(0.9, 0.7, 1.0), cx, Basis(Vector3.UP, 0.08))
			c.caixa(Vector3(-4.5, 0.2, 0.3), Vector3(0.7, 0.4, 0.9), cx * 0.9, Basis(Vector3.UP, -0.2))
			c.caixa(Vector3(-4.45, 0.72, -0.9), Vector3(0.5, 0.06, 0.5), Color(0.5, 0.45, 0.3))
		"sacos_areia":
			var areia := Color(0.55, 0.5, 0.38)
			for k in 3:
				var s := 0.3 if k % 2 == 1 else 0.0
				for i in 5:
					c.caixa(Vector3(-1.2 + s + i * 0.6, 0.14 + k * 0.26, 0), Vector3(0.62, 0.26, 0.4), areia * (0.9 + 0.1 * ((i + k) % 2)))
	return c.malha()

static func modelo_longe(nome: String) -> ArrayMesh:
	var c := Malhas.Construtor.new()
	match nome:
		"humvee":
			c.caixa(Vector3(0, 1.1, 0), Vector3(4.9, 1.6, 2.2), Color.WHITE)
		"mrap":
			c.caixa(Vector3(0, 1.6, 0), Vector3(6.2, 2.6, 2.5), Color.WHITE)
		"caminhao_exercito":
			c.caixa(Vector3(2.9, 1.7, 0), Vector3(2.0, 2.2, 2.4), Color.WHITE)
			c.caixa(Vector3(-1.1, 2.2, 0), Vector3(5.4, 2.6, 2.5), Color(1.1, 1.1, 1.0))
		"caminhao_tanque":
			c.caixa(Vector3(2.9, 1.7, 0), Vector3(2.0, 2.2, 2.4), Color.WHITE)
			c.caixa(Vector3(-1.1, 2.2, 0), Vector3(5.4, 2.2, 2.3), Color(0.95, 0.95, 0.95))
		"tanque":
			c.caixa(Vector3(0, 0.95, 0), Vector3(7.8, 1.5, 3.6), Color.WHITE)
			c.caixa(Vector3(-4.45, 0.35, -0.9), Vector3(0.9, 0.7, 1.0), Color(0.6, 0.62, 0.5))
			c.caixa(Vector3(-0.6, 2.0, 0), Vector3(3.8, 1.0, 3.0), Color.WHITE)
			c.caixa(Vector3(4.1, 2.05, 0), Vector3(5.2, 0.25, 0.25), Color.WHITE)
		"sacos_areia":
			c.caixa(Vector3(0, 0.4, 0), Vector3(3.0, 0.8, 0.4), Color(0.55, 0.5, 0.38))
	return c.malha()

# ---------- colocação (chamada por mundo/abandono.gd) ----------
# ab = mundo/abandono.gd (usa _por, _obstaculo, obstaculos e carros); devolve, por comboio:
# [centro, direção da fila, lado do meio da rua (Vector3), meio comprimento da fila, distância até o meio da rua]
static func colocar(ab) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1081
	var cid = ab.cid
	# trechos de avenida compridos (fora dos locais especiais e da base do aeroporto)
	var cands: Array = []
	for rd in cid.dados_cidade["roads"]:
		var larg: float = float(rd[0])
		if larg < 9.0:
			continue
		var pts: PackedVector2Array = cid._pts(rd[1])
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var L := a.distance_to(b)
			if L < TRECHO_MIN:
				continue
			var m := (a + b) * 0.5
			if m.x > 5600.0 and m.y > -1600.0 and m.y < 2600.0:
				continue
			if Locais.em(m, 60.0) >= 0 or Locais.em(a, 30.0) >= 0 or Locais.em(b, 30.0) >= 0:
				continue
			cands.append([a, b, larg * 0.5])
	# sorteio estável (embaralha com a semente) e espalha: um comboio a cada DIST_ENTRE m
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cands[i]
		cands[i] = cands[j]
		cands[j] = t
	var escolhidos: Array = []
	for cd in cands:
		if escolhidos.size() >= N:
			break
		var m: Vector2 = (cd[0] + cd[1]) * 0.5
		var longe := true
		for e in escolhidos:
			if m.distance_to((e[0] + e[1]) * 0.5) < DIST_ENTRE:
				longe = false
				break
		if not longe:
			continue
		# uma pista livre (sem a fila de carros largados), sorteando qual delas tentar primeiro
		var sentido := 1.0 if rng.randf() < 0.5 else -1.0
		if _na_pista(ab, cd[0], cd[1], cd[2], sentido) > MAX_NA_PISTA:
			sentido = -sentido
			if _na_pista(ab, cd[0], cd[1], cd[2], sentido) > MAX_NA_PISTA:
				continue
		escolhidos.append([cd[0], cd[1], cd[2]] if sentido > 0.0 else [cd[1], cd[0], cd[2]])
	var centros: Array = []
	for cd in escolhidos:
		var c := _comboio(ab, rng, cd[0], cd[1], cd[2])
		if not c.is_empty():
			centros.append(c)
	return centros

# um comboio no trecho a->b (pista da direita); devolve [centro, direção, lado do meio, meio comprimento, até o meio]
static func _comboio(ab, rng: RandomNumberGenerator, a: Vector2, b: Vector2, hw: float) -> Array:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var nrm := Vector2(-d.y, d.x)
	var faixa := nrm * (-hw * 0.45)           # pista da direita
	var n := rng.randi_range(4, 9)
	var com_tanque := rng.randf() < 0.4
	var lista: Array = SEQUENCIA.slice(0, n)
	if not com_tanque:
		for k in lista.size():
			if lista[k] == "tanque":
				lista[k] = "caminhao_exercito"
	elif not ("tanque" in lista):
		lista[lista.size() - 1] = "tanque"
	# do começo do trecho para a frente: o 1º veículo é o da FRENTE do comboio
	var s := L - LONGE_CRUZAMENTO
	var cor: Color = CORES[rng.randi() % CORES.size()]
	var obst := _obst_perto(ab, (a + b) * 0.5, L * 0.5 + 10.0)
	var soma := Vector3.ZERO
	var postos := 0
	var s_ini := s
	var s_fim := s
	for k in lista.size():
		var nome: String = lista[k]
		var tam: Vector3 = TAM[nome]
		s -= tam.x * 0.5
		if s < 22.0:
			break
		var p: Vector2 = a + d * s + faixa + nrm * rng.randf_range(-0.4, 0.4)
		s -= tam.x * 0.5 + rng.randf_range(4.0, 9.0)
		var giro := _giro(d) + rng.randf_range(-0.06, 0.06)
		if nome != "tanque" and rng.randf() < 0.15:
			giro += rng.randf_range(0.45, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)      # atravessado
		if _ocupado(ab, obst, p, maxf(tam.x, tam.z) * 0.5 + 0.6):
			continue
		var queimado := rng.randf() < 0.25
		var cv: Color = (QUEIMADO * rng.randf_range(0.8, 1.3)) if queimado else cor * rng.randf_range(0.85, 1.1)
		cv.a = 1.0
		_veiculo(ab, nome, p, giro, cv, "queimado" if queimado else "")
		soma += Vector3(p.x, ab.Y, p.y)
		postos += 1
		s_fim = s
	if postos == 0:
		return []
	# bloqueio na frente (barreiras e sacos de areia atravessando a pista)
	if rng.randf() < 0.4:
		var f: Vector2 = a + d * (L - LONGE_CRUZAMENTO + 7.0) + faixa
		for q in [-1.6, 1.6]:
			var pb: Vector2 = f + nrm * q
			if not _ocupado(ab, obst, pb, 1.6):
				ab._por("barreira", Transform3D(Basis(Vector3.UP, _giro(nrm)), Vector3(pb.x, ab.Y, pb.y)), Color(0.75, 0.75, 0.72))
				ab._obstaculo(Vector3(pb.x, ab.Y, pb.y), _giro(nrm), Vector3(3.0, 0.85, 0.62))
		var ps: Vector2 = f + d * 2.5
		if not _ocupado(ab, obst, ps, 1.6):
			ab._por("sacos_areia", Transform3D(Basis(Vector3.UP, _giro(nrm)), Vector3(ps.x, ab.Y, ps.y)), Color.WHITE)
			ab._obstaculo(Vector3(ps.x, ab.Y, ps.y), _giro(nrm), Vector3(3.0, 0.8, 0.45))
	return [soma / postos, Vector3(d.x, 0, d.y), Vector3(nrm.x, 0, nrm.y), (s_ini - s_fim) * 0.5, hw * 0.45]

static func _veiculo(ab, nome: String, p: Vector2, giro: float, cor: Color, estado: String) -> void:
	var tam: Vector3 = TAM[nome]
	var b := Basis(Vector3.UP, giro)
	var bk := Vector2i(floori(p.x / ab.BLOCO), floori(p.y / ab.BLOCO))
	var n_bloco: int = ab._inst[nome][bk].size() if ab._inst.has(nome) and ab._inst[nome].has(bk) else 0
	var n_obst: int = ab.obstaculos.size() / 7
	ab._por(nome, Transform3D(b, Vector3(p.x, ab.Y, p.y)), cor)
	if nome == "tanque":
		# casco (1,5 m), torre por cima (2,5 m), o cesto atrás da torre (2,1 m) e os caixotes no chão (0,7 m): sobe pulando
		ab._obstaculo(Vector3(p.x, ab.Y, p.y), giro, Vector3(tam.x, 1.5, tam.z))
		var pt: Vector3 = b * Vector3(-0.6, 0, 0)
		ab._obstaculo(Vector3(p.x + pt.x, ab.Y + 1.5, p.y + pt.z), giro, Vector3(3.8, 1.0, 3.0))
		var pk: Vector3 = b * Vector3(-2.95, 0, 0)
		ab._obstaculo(Vector3(p.x + pk.x, ab.Y + 1.5, p.y + pk.z), giro, Vector3(0.8, 0.6, 2.8))
		var pc: Vector3 = b * Vector3(-4.45, 0, -0.9)
		ab._obstaculo(Vector3(p.x + pc.x, ab.Y, p.y + pc.z), giro, Vector3(0.9, 0.7, 1.0))
	else:
		ab._obstaculo(Vector3(p.x, ab.Y, p.y), giro, tam)
	ab.carros.append([Vector3(p.x, ab.Y, p.y), giro, nome, cor, estado, n_obst, bk, n_bloco])

# quantos obstáculos (carros largados, barreiras...) estão na pista da direita de quem vai de a para b (sentido 1)
# ou de b para a (sentido -1), entre os dois cruzamentos
static func _na_pista(ab, a: Vector2, b: Vector2, hw: float, sentido: float) -> int:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var nrm := Vector2(-d.y, d.x)
	var off := -hw * 0.45 * sentido
	var n := 0
	var o: PackedFloat32Array = ab.obstaculos
	var m := (a + b) * 0.5
	var r := L * 0.5 + 5.0
	for i in range(0, o.size(), 7):
		if absf(o[i] - m.x) > r or absf(o[i + 1] - m.y) > r:
			continue
		var q := Vector2(o[i], o[i + 1]) - a
		var t := q.dot(d)
		if t < 10.0 or t > L - 10.0:
			continue
		if absf(q.dot(nrm) - off) < 2.8:
			n += 1
	return n

static func _giro(dir: Vector2) -> float:
	return atan2(-dir.y, dir.x)

# obstáculos (carros largados, barreiras...) perto do trecho, para o comboio não nascer em cima
static func _obst_perto(ab, c: Vector2, raio: float) -> PackedVector2Array:
	var r := PackedVector2Array()
	var o: PackedFloat32Array = ab.obstaculos
	for i in range(0, o.size(), 7):
		if absf(o[i] - c.x) < raio and absf(o[i + 1] - c.y) < raio:
			r.append(Vector2(o[i], o[i + 1]))
	return r

static func _ocupado(ab, obst: PackedVector2Array, p: Vector2, raio: float) -> bool:
	for q in obst:
		if q.distance_to(p) < raio + 1.6:
			return true
	# e o que este comboio já pôs (os últimos obstáculos)
	var o: PackedFloat32Array = ab.obstaculos
	var ini := maxi(0, o.size() - 7 * 14)
	for i in range(ini, o.size(), 7):
		if Vector2(o[i], o[i + 1]).distance_to(p) < raio + 1.0:
			return true
	return false
