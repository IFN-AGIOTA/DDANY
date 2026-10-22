extends SceneTree
# ESCOLHE ONDE FICAM OS LOCAIS ESPECIAIS (0.68): postos de gasolina, hospitais, supermercados e armazéns.
# Procura terrenos livres (sem rua, calçada, água ou parque, fora do aeroporto) com uma RUA na frente e longe uns
# dos outros, e imprime a lista LOCAIS para colar em mundo/locais.gd. Feito uma vez (fora do jogo): o jogo não gasta
# tempo procurando e todo aparelho tem os locais nos mesmos lugares.
# Rodar, dentro da pasta DDA_Godot_Cidade:  godot --headless -s ferramentas/escolher_locais.gd
# Esta pasta (ferramentas/) não vai para o APK.

const Locais := preload("res://mundo/locais.gd")
const SPAWN := Vector2(6230.0, 590.0)          # igual a main.gd
const QUANTOS := {"posto": 12, "hospital": 4, "supermercado": 6, "armazem": 6}
const PERTO_SPAWN := {"posto": 1, "hospital": 1, "supermercado": 1, "armazem": 1}   # um de cada perto da base
const RAIO_SPAWN := 2600.0
const DIST_MIN := 650.0                        # entre dois locais quaisquer
const DIST_MESMO := 2000.0                     # entre dois do mesmo tipo
const FRENTE_MAX := 9.0                        # a rua (com calçada) tem de estar a até isso da frente do terreno

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
	for tipo in QUANTOS:
		for k in PERTO_SPAWN[tipo]:
			ordem.append([tipo, true])
	for tipo in ["hospital", "supermercado", "armazem", "posto"]:
		for k in QUANTOS[tipo] - PERTO_SPAWN[tipo]:
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
	print("const LOCAIS := [")
	for e in escolhidos:
		print("\t[\"%s\", %.1f, %.1f, %d],     # %d m da base" % [e[0], e[1], e[2], e[3], int(Vector2(e[1], e[2]).distance_to(SPAWN))])
	print("]")
	quit()

func _embaralhar(a: Array, r: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _longe(p: Vector2, tipo: String, escolhidos: Array) -> bool:
	for e in escolhidos:
		var d := p.distance_to(Vector2(e[1], e[2]))
		if d < DIST_MIN or (e[0] == tipo and d < DIST_MESMO):
			return false
	return true

# 0..3 = para que lado fica a frente (a rua) · -1 = não serve
func _giro_valido(tipo: String, p: Vector2) -> int:
	if p.x > 5600.0 and p.y > -1600.0 and p.y < 2600.0:
		return -1                                  # aeroporto / base militar
	var tam: Vector2 = Locais.TAMANHO[tipo]
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
