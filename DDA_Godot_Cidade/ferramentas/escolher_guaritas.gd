extends SceneTree
# ESCOLHE ONDE FICAM AS GUARITAS DE OBSERVAÇÃO (1.08): no MEIO DOS CAMPOS (parques de data/city.json), dos maiores para
# os menores: 2 nos 2 maiores, 1 nos outros, até N. O terreno (30 x 30) tem de ser todo parque e terra (sem rua nem
# água) e fica longe dos outros locais e das outras guaritas. Nenhum prédio sai (parque não tem prédio).
# Imprime as linhas para pôr no FIM da lista LOCAIS de mundo/locais.gd.
# Rodar, dentro da pasta DDA_Godot_Cidade:  godot --headless -s ferramentas/escolher_guaritas.gd
# Esta pasta (ferramentas/) não vai para o APK.

const Locais := preload("res://mundo/locais.gd")
const N := 8
const TAM := Vector2(30, 30)
const DIST_LOCAIS := 350.0
const DIST_ENTRE := 700.0

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
	var parques: Array = []
	for pk in data["parks"]:
		var poli: PackedVector2Array = C._pts(pk)
		var r := Rect2(poli[0], Vector2.ZERO)
		for q in poli:
			r = r.expand(q)
		parques.append([r.get_area(), poli, r])
	parques.sort_custom(func(a, b): return a[0] > b[0])
	var outros: Array = []
	for e in Locais.LOCAIS:
		outros.append(Vector2(e[1], e[2]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1080
	var achadas: Array = []
	for ip in parques.size():
		if achadas.size() >= N:
			break
		var quer := 2 if ip < 2 else 1
		var poli: PackedVector2Array = parques[ip][1]
		var r: Rect2 = parques[ip][2]
		var meio := r.get_center()
		var cands: Array = []
		var z := r.position.y + 15.0
		while z < r.end.y - 15.0:
			var x := r.position.x + 15.0
			while x < r.end.x - 15.0:
				var p := Vector2(x + rng.randf_range(-3, 3), z + rng.randf_range(-3, 3))
				if Geometry2D.is_point_in_polygon(p, poli):
					cands.append(p)
				x += 10.0
			z += 10.0
		# o mais perto do meio do parque primeiro ("no meio dos campos")
		cands.sort_custom(func(a, b): return a.distance_to(meio) < b.distance_to(meio))
		var nesse := 0
		for p in cands:
			if nesse >= quer or achadas.size() >= N:
				break
			if not _terreno_ok(p, poli):
				continue
			var longe := true
			for o in outros:
				if p.distance_to(o) < DIST_LOCAIS:
					longe = false
					break
			for a in achadas:
				if p.distance_to(Vector2(a[1], a[2])) < DIST_ENTRE:
					longe = false
					break
			if not longe:
				continue
			achadas.append(["guarita", snappedf(p.x, 0.5), snappedf(p.y, 0.5), rng.randi() % 4])
			nesse += 1
	print("\t# 1.08 (ferramentas/escolher_guaritas.gd): GUARITAS DE OBSERVAÇÃO no meio dos campos (parques)")
	for a in achadas:
		print("\t[\"guarita\", %.1f, %.1f, %d]," % [a[1], a[2], a[3]])
	if achadas.size() < N:
		print("SÓ ACHEI ", achadas.size())
	quit()

# o terreno 30 x 30 (com folga de 5 m) inteiro dentro do parque, em terra, sem rua nem água
func _terreno_ok(p: Vector2, poli: PackedVector2Array) -> bool:
	var t := TAM + Vector2(10, 10)
	var x := p.x - t.x * 0.5
	while x <= p.x + t.x * 0.5 + 0.01:
		var z := p.y - t.y * 0.5
		while z <= p.y + t.y * 0.5 + 0.01:
			var q := Vector2(x, z)
			if not Geometry2D.is_point_in_polygon(q, poli):
				return false
			var cc := int((x + C.WORLD.x) / C.CELL)
			var rr := int((z + C.WORLD.y) / C.CELL)
			if cc < 0 or rr < 0 or cc >= C.W or rr >= C.H or C.land[rr * C.W + cc] == 0 or C.road[rr * C.W + cc] == 1:
				return false
			z += 10.0
		x += 10.0
	return C._predio_ruim(p.x, p.y, TAM.x, TAM.y) == ""
