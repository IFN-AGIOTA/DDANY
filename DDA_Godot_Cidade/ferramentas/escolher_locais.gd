extends SceneTree
# ESCOLHE ONDE FICAM OS LOCAIS ESPECIAIS (0.68): postos de gasolina, hospitais, supermercados e armazéns.
# Procura terrenos livres (sem rua, calçada, água ou parque, fora do aeroporto) com uma RUA na frente e longe uns
# dos outros, e imprime a lista LOCAIS para colar em mundo/locais.gd. Feito uma vez (fora do jogo): o jogo não gasta
# tempo procurando e todo aparelho tem os locais nos mesmos lugares.
# Rodar, dentro da pasta DDA_Godot_Cidade:  godot --headless -s ferramentas/escolher_locais.gd
# 0.78: com NOVOS=1 os locais que já existem (mundo/locais.gd LOCAIS) ficam onde estão e só os tipos de QUANTOS_NOVOS
# (delegacia, escola, metrô, quartel) são escolhidos: as linhas impressas vão no FIM da lista LOCAIS (a ordem dos
# antigos não pode mudar). O QUARTEL fica só dentro da base militar do aeroporto (onde o jogador nasce), longe do
# ponto de partida, com o portão virado para ele.
# Esta pasta (ferramentas/) não vai para o APK.

const Locais := preload("res://mundo/locais.gd")
const SPAWN := Vector2(6230.0, 590.0)          # igual a main.gd
const QUANTOS := {"posto": 12, "hospital": 4, "supermercado": 6, "armazem": 6}
const PERTO_SPAWN := {"posto": 1, "hospital": 1, "supermercado": 1, "armazem": 1}   # um de cada perto da base
const RAIO_SPAWN := 2600.0
const DIST_MIN := 650.0                        # entre dois locais quaisquer
const DIST_MESMO := 2000.0                     # entre dois do mesmo tipo
const FRENTE_MAX := 9.0                        # a rua (com calçada) tem de estar a até isso da frente do terreno
const QUANTOS_NOVOS := {"delegacia": 4, "escola": 4, "metro": 4, "quartel": 2}
const PERTO_SPAWN_NOVOS := {"delegacia": 1, "escola": 1, "metro": 1, "quartel": 2}
const QUARTEL_DIST_SPAWN := 160.0             # o quartel não fica em cima do ponto de partida / estande de tiro
const QUARTEL_DIST_MIN := 300.0               # quartel x outros locais (a base é menor que a cidade)
# 1.06: com NOVOS=2, a IGREJA (uma por ilha com ruas) e a PREFEITURA (a mais perto do centro, mundo/cidade.gd DOWNTOWN).
# As linhas impressas vão no FIM da lista LOCAIS (depois dos bunkers).
const ILHAS := [0, 1, 3, 4]                   # índices em data/city.json "lands" (terra com ruas), como os bunkers
const DIST_MIN_V2 := 450.0

var C

func _initialize() -> void:
	C = load("res://mundo/cidade.gd").new()
	C.W = int(C.WORLD.x * 2.0 / C.CELL)
	C.H = int(C.WORLD.y * 2.0 / C.CELL)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/city.json"))
	C._ligar_pontas(data)
	C.dados_cidade = data
	C._ground(data)
	C._roads(data)
	C._preparar_filtro(data)
	var rng := RandomNumberGenerator.new()
	rng.seed = 680
	var cands := []
	var z: float = -C.WORLD.y + 60.0
	while z < C.WORLD.y - 60.0:
		var x: float = -C.WORLD.x + 60.0
		while x < C.WORLD.x - 60.0:
			cands.append(Vector2(x + rng.randf_range(-8, 8), z + rng.randf_range(-8, 8)))
			x += 24.0
		z += 24.0
	var escolhidos := []
	var ordem := []
	if OS.get_environment("NOVOS") == "2":
		_novos_106(data, cands, rng)
		return
	var novos := OS.get_environment("NOVOS") == "1"
	var quantos: Dictionary = QUANTOS_NOVOS if novos else QUANTOS
	var perto: Dictionary = PERTO_SPAWN_NOVOS if novos else PERTO_SPAWN
	if novos:
		for e in Locais.LOCAIS:
			escolhidos.append((e as Array).duplicate())
	var ja := escolhidos.size()
	for tipo in quantos:
		for k in perto[tipo]:
			ordem.append([tipo, true])
	for tipo in quantos:
		for k in quantos[tipo] - perto[tipo]:
			ordem.append([tipo, false])
	for o in ordem:
		var tipo: String = o[0]
		var lista := cands.duplicate()
		if o[1]:
			lista.sort_custom(func(a, b): return a.distance_squared_to(SPAWN) < b.distance_squared_to(SPAWN))
		else:
			_embaralhar(lista, rng)
		var achou := false
		for p in lista:
			if o[1] and p.distance_to(SPAWN) > RAIO_SPAWN:
				break
			if not _longe(p, tipo, escolhidos):
				continue
			var giro := _giro_valido(tipo, p)
			if giro < 0:
				continue
			escolhidos.append([tipo, snappedf(p.x, 0.5), snappedf(p.y, 0.5), giro])
			achou = true
			break
		if not achou:
			print("NÃO ACHEI lugar para ", tipo)
	print("const LOCAIS := [" if not novos else "\t# 0.78 (ferramentas/escolher_locais.gd NOVOS=1)")
	for e in escolhidos.slice(ja):
		print("\t[\"%s\", %.1f, %.1f, %d],     # %d m da base" % [e[0], e[1], e[2], e[3], int(Vector2(e[1], e[2]).distance_to(SPAWN))])
	if not novos:
		print("]")
	quit()

# 1.06: prefeitura (centro) e uma igreja por ilha
func _novos_106(data, cands: Array, rng: RandomNumberGenerator) -> void:
	var escolhidos: Array = []
	for e in Locais.LOCAIS:
		escolhidos.append((e as Array).duplicate())
	var ja := escolhidos.size()
	var ordem: Array = [["prefeitura", -1]]
	for il in ILHAS:
		ordem.append(["igreja", il])
	for o in ordem:
		var tipo: String = o[0]
		var lista: Array = []
		if int(o[1]) < 0:
			lista = cands.duplicate()
			lista.sort_custom(func(a, b): return a.distance_squared_to(C.DOWNTOWN) < b.distance_squared_to(C.DOWNTOWN))
		else:
			var poli: PackedVector2Array = C._pts(data["lands"][int(o[1])][1])
			for p in cands:
				if Geometry2D.is_point_in_polygon(p, poli):
					lista.append(p)
			# o mais perto do meio da ilha primeiro (longe da costa), com um pouco de sorte
			var meio := Vector2.ZERO
			for q in poli:
				meio += q
			meio /= poli.size()
			_embaralhar(lista, rng)
			lista.sort_custom(func(a, b): return a.distance_to(meio) * rng.randf_range(0.7, 1.3) < b.distance_to(meio) * rng.randf_range(0.7, 1.3))
		var achou := false
		for p in lista:
			var longe := true
			for e in escolhidos:
				if p.distance_to(Vector2(e[1], e[2])) < DIST_MIN_V2:
					longe = false
					break
			if not longe:
				continue
			var giro := _giro_valido(tipo, p)
			if giro < 0:
				continue
			escolhidos.append([tipo, snappedf(p.x, 0.5), snappedf(p.y, 0.5), giro])
			achou = true
			break
		if not achou:
			print("NÃO ACHEI lugar para ", tipo, " ", o[1])
	print("\t# 1.06 (ferramentas/escolher_locais.gd NOVOS=2): PREFEITURA (centro) e IGREJAS (uma por ilha)")
	for e in escolhidos.slice(ja):
		print("\t[\"%s\", %.1f, %.1f, %d],     # %d m do centro" % [e[0], e[1], e[2], e[3], int(Vector2(e[1], e[2]).distance_to(C.DOWNTOWN))])
	quit()

func _embaralhar(a: Array, r: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _longe(p: Vector2, tipo: String, escolhidos: Array) -> bool:
	if tipo == "quartel" and p.distance_to(SPAWN) < QUARTEL_DIST_SPAWN:
		return false
	for e in escolhidos:
		var d := p.distance_to(Vector2(e[1], e[2]))
		var minimo := QUARTEL_DIST_MIN if tipo == "quartel" or e[0] == "quartel" else DIST_MIN
		if d < minimo or (e[0] == tipo and d < (QUARTEL_DIST_MIN * 2.0 if tipo == "quartel" else DIST_MESMO)):
			return false
	return true

func _na_base(p: Vector2) -> bool:
	return p.x > 5600.0 and p.y > -1600.0 and p.y < 2600.0

# 0..3 = para que lado fica a frente (a rua) · -1 = não serve
func _giro_valido(tipo: String, p: Vector2) -> int:
	if _na_base(p) != (tipo == "quartel"):
		return -1                                  # aeroporto / base militar: só o quartel (e ele só lá)
	var tam: Vector2 = Locais.TAMANHO[tipo]
	if tipo == "quartel":
		return _giro_quartel(p, tam)
	var melhor := -1
	var melhor_d := INF
	for giro in 4:
		var t := tam if giro % 2 == 0 else Vector2(tam.y, tam.x)
		if C._predio_ruim(p.x, p.y, t.x + 4.0, t.y + 4.0) != "" or not _sem_parque(p, t):
			continue
		# frente para +Z, +X, -Z, -X: a rua tem de aparecer esticando o terreno até FRENTE_MAX para aquele lado
		var dir: Vector2 = [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)][giro]
		for d in [3.0, 6.0, FRENTE_MAX]:
			var c: Vector2 = p + dir * d * 0.5
			var t2: Vector2 = t + dir.abs() * d
			if C._predio_ruim(c.x, c.y, t2.x, t2.y) == "rua":
				if d < melhor_d:
					melhor_d = d
					melhor = giro
				break
	return melhor

func _sem_parque(p: Vector2, t: Vector2) -> bool:
	var x := p.x - t.x * 0.5
	while x <= p.x + t.x * 0.5:
		var z := p.y - t.y * 0.5
		while z <= p.y + t.y * 0.5:
			var cc := int((x + C.WORLD.x) / C.CELL)
			var rr := int((z + C.WORLD.y) / C.CELL)
			if cc < 0 or rr < 0 or cc >= C.W or rr >= C.H or C.park[rr * C.W + cc] == 1 or C.land[rr * C.W + cc] == 0:
				return false
			z += 10.0
		x += 10.0
	return true

# quartel (dentro da base, sem rua): terreno livre de água/rua/parque; o portão (frente) virado para o ponto de partida
func _giro_quartel(p: Vector2, tam: Vector2) -> int:
	var para := (SPAWN - p).normalized()
	var melhor := -1
	var melhor_v := -INF
	for giro in 4:
		var t := tam if giro % 2 == 0 else Vector2(tam.y, tam.x)
		if C._predio_ruim(p.x, p.y, t.x + 4.0, t.y + 4.0) != "" or not _sem_parque(p, t):
			continue
		var dir: Vector2 = [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)][giro]
		if dir.dot(para) > melhor_v:
			melhor_v = dir.dot(para)
			melhor = giro
	return melhor
