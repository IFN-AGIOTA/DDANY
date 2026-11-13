extends SceneTree
# ESCOLHE ONDE FICAM OS BUNKERS (0.83): UM POR ILHA (polígonos de terra de data/city.json que têm ruas).
# Cada bunker precisa de um terreno VAZIO (nenhum prédio em cima: assim os números dos prédios não mudam e os jogos
# salvos continuam valendo), com rua na frente, fora de parque/água/aeroporto e longe dos outros locais.
# Imprime as linhas para pôr no FIM da lista LOCAIS de mundo/locais.gd (a ordem dos outros não pode mudar).
# Rodar, dentro da pasta DDA_Godot_Cidade (precisa da cidade montada):
#   xvfb-run godot --rendering-driver opengl3 -s ferramentas/escolher_bunkers.gd
# Esta pasta (ferramentas/) não vai para o APK.

const Locais := preload("res://mundo/locais.gd")
const ILHAS := [0, 1, 3, 4]                    # índices em data/city.json "lands" (terra com ruas)
const DIST_MIN := 450.0                        # dos outros locais
const FRENTE_MAX := 9.0
const PASSO := 16.0

func _initialize() -> void:
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()

func _r() -> void:
	for i in 20:
		await process_frame
	var m = current_scene
	m._jogar()
	for i in 30:
		await process_frame
	print("prédios: ", m.cidade.predio_info.size())
	var C = m.cidade
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/city.json"))
	var tam: Vector2 = Locais.TAMANHO["bunker"]
	var plantas := {}                          # grade de 100 m -> [Rect2] (busca rápida)
	for e in C.predio_info:
		var pr := Rect2(float(e["x"]) - float(e["sx"]) * 0.5, float(e["z"]) - float(e["sz"]) * 0.5, float(e["sx"]), float(e["sz"]))
		for gz in range(floori(pr.position.y / 100.0), floori(pr.end.y / 100.0) + 1):
			for gx in range(floori(pr.position.x / 100.0), floori(pr.end.x / 100.0) + 1):
				var k := Vector2i(gx, gz)
				if not plantas.has(k):
					plantas[k] = []
				plantas[k].append(pr)
	var outros: Array = []
	for e in Locais.LOCAIS:
		if e[0] != "bunker":
			outros.append(Vector2(e[1], e[2]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 830
	var n := 0
	for il in ILHAS:
		var p: Array = data["lands"][il][1]
		var poli := PackedVector2Array()
		for k in range(0, p.size(), 2):
			poli.append(Vector2(p[k], p[k + 1]))
		var cx := 0.0
		var cz := 0.0
		for q in poli:
			cx += q.x
			cz += q.y
		var meio := Vector2(cx, cz) / poli.size()
		var r := Rect2(poli[0], Vector2.ZERO)
		for q in poli:
			r = r.expand(q)
		var cands: Array = []
		var z := r.position.y
		while z < r.end.y:
			var x := r.position.x
			while x < r.end.x:
				var c := Vector2(x + rng.randf_range(-4, 4), z + rng.randf_range(-4, 4))
				if Geometry2D.is_point_in_polygon(c, poli):
					cands.append(c)
				x += PASSO
			z += PASSO
		# o mais perto do "meio" da ilha primeiro (longe da costa), com um pouco de sorte
		cands.sort_custom(func(a, b): return a.distance_to(meio) < b.distance_to(meio))
		var achou := false
		for c in cands:
			if c.x > 5600.0 and c.y > -1600.0 and c.y < 2600.0:
				continue                              # aeroporto / base militar
			var longe := true
			for o in outros:
				if c.distance_to(o) < DIST_MIN:
					longe = false
					break
			if not longe:
				continue
			var giro := _giro(C, c, tam, plantas)
			if giro < 0:
				continue
			n += 1
			print("\t[\"bunker\", %.1f, %.1f, %d],     # BUNKER %d (ilha %d)" % [snappedf(c.x, 0.5), snappedf(c.y, 0.5), giro, n, il])
			outros.append(c)
			achou = true
			break
		if not achou:
			print("NÃO ACHEI lugar na ilha ", il)
	quit()

func _giro(C, p: Vector2, tam: Vector2, plantas: Dictionary) -> int:
	for giro in 4:
		var t := tam if giro % 2 == 0 else Vector2(tam.y, tam.x)
		var ret := Rect2(p - t * 0.5, t).grow(5.0)
		var livre := true
		for gz in range(floori(ret.position.y / 100.0), floori(ret.end.y / 100.0) + 1):
			for gx in range(floori(ret.position.x / 100.0), floori(ret.end.x / 100.0) + 1):
				for pl in plantas.get(Vector2i(gx, gz), []):
					if (pl as Rect2).intersects(ret):
						livre = false
		if not livre or C._predio_ruim(p.x, p.y, t.x + 4.0, t.y + 4.0) != "" or not _sem_parque(C, p, t):
			continue
		var dir: Vector2 = [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)][giro]
		for d in [3.0, 6.0, FRENTE_MAX]:
			var c: Vector2 = p + dir * d * 0.5
			var t2: Vector2 = t + dir.abs() * d
			if C._predio_ruim(c.x, c.y, t2.x, t2.y) == "rua":
				return giro
	return -1

func _sem_parque(C, p: Vector2, t: Vector2) -> bool:
	var x := p.x - t.x * 0.5
	while x <= p.x + t.x * 0.5:
		var z := p.y - t.y * 0.5
		while z <= p.y + t.y * 0.5:
			var cc := int((x + C.WORLD.x) / C.CELL)
			var rr := int((z + C.WORLD.y) / C.CELL)
			if cc < 0 or rr < 0 or cc >= C.W or rr >= C.H or C.park[rr * C.W + cc] == 1 or C.land[rr * C.W + cc] == 0:
				return false
			z += 6.0
		x += 6.0
	return true
