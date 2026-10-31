extends SceneTree
# ESCOLHE ONDE FICAM OS PORTOS e os HANGARES DE CARGA (1.07). Imprime as linhas para pôr no FIM da lista LOCAIS de
# mundo/locais.gd (a ordem dos outros não pode mudar).
#   PORTO: terreno em terra (sem rua, água nem parque dentro), RUA na frente e MAR atrás (o navio atraca no cais do
#   fundo: tem de haver mar aberto, não lago, de 10 a 45 m atrás do terreno, em todo o comprimento do navio).
#   HANGAR: terreno com rua na frente, como os outros locais.
#   Os dois: de preferência num terreno SEM PRÉDIO (assim os números dos prédios não mudam: os jogos salvos e o resto
#   continuam iguais); longe dos outros locais e um do outro.
# Rodar, dentro da pasta DDA_Godot_Cidade (precisa da cidade montada):
#   xvfb-run godot --rendering-driver opengl3 -s ferramentas/escolher_portos.gd
# Esta pasta (ferramentas/) não vai para o APK.

const Locais := preload("res://mundo/locais.gd")
const TAM_PORTO := Vector2(160, 90)
const TAM_HANGAR := Vector2(90, 70)
const N_PORTOS := 2
const N_HANGARES := 3
const DIST_MIN := 450.0                        # dos outros locais
const DIST_PORTOS := 3000.0                    # entre os dois portos
const DIST_HANGARES := 2200.0                  # entre os hangares
const FRENTE_MAX := 9.0

var C
var plantas := {}                              # grade de 100 m -> [Rect2] dos prédios

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
	C = m.cidade
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
		outros.append(Vector2(e[1], e[2]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1070
	# ---- PORTOS: perto da costa ----
	var achados: Array = []                       # [prédios que saem, sorteio, p, giro]
	var z: float = -C.WORLD.y + 100.0
	while z < C.WORLD.y - 100.0:
		var x: float = -C.WORLD.x + 100.0
		while x < C.WORLD.x - 100.0:
			var p := Vector2(x, z)
			if _costa(p) and not _na_base(p) and _longe(p, outros, DIST_MIN):
				for giro in 4:
					if _porto_ok(p, giro):
						achados.append([_predios_em(p, giro, TAM_PORTO), rng.randf(), p, giro])
			x += 20.0
		z += 20.0
	achados.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	print("candidatos a porto: ", achados.size())
	var portos: Array = []
	for a in achados:
		if portos.size() >= N_PORTOS:
			break
		if not _longe(a[2], outros, DIST_MIN):
			continue
		var perto := false
		for q in portos:
			if (a[2] as Vector2).distance_to(q[2]) < DIST_PORTOS:
				perto = true
		if perto:
			continue
		portos.append(a)
		outros.append(a[2])
	# ---- HANGARES ----
	var hs: Array = []
	z = -C.WORLD.y + 60.0
	while z < C.WORLD.y - 60.0:
		var x: float = -C.WORLD.x + 60.0
		while x < C.WORLD.x - 60.0:
			var p := Vector2(x + rng.randf_range(-6, 6), z + rng.randf_range(-6, 6))
			if C._em_terra(p) and not _na_base(p) and _longe(p, outros, DIST_MIN):
				var giro := _giro_rua(p, TAM_HANGAR)
				if giro >= 0:
					hs.append([_predios_em(p, giro, TAM_HANGAR), rng.randf(), p, giro])
			x += 40.0
		z += 40.0
	hs.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	print("candidatos a hangar: ", hs.size())
	var hangares: Array = []
	for a in hs:
		if hangares.size() >= N_HANGARES:
			break
		if not _longe(a[2], outros, DIST_MIN):
			continue
		var perto := false
		for q in hangares:
			if (a[2] as Vector2).distance_to(q[2]) < DIST_HANGARES:
				perto = true
		if perto:
			continue
		hangares.append(a)
		outros.append(a[2])
	print("\t# 1.07 (ferramentas/escolher_portos.gd): PORTOS (na costa, navio atrás) e HANGARES DE CARGA")
	for a in portos:
		print("\t[\"porto\", %.1f, %.1f, %d],     # %d prédios saem" % [snappedf(a[2].x, 0.5), snappedf(a[2].y, 0.5), a[3], a[0]])
	for a in hangares:
		print("\t[\"hangar\", %.1f, %.1f, %d],     # %d prédios saem" % [snappedf(a[2].x, 0.5), snappedf(a[2].y, 0.5), a[3], a[0]])
	if portos.size() < N_PORTOS or hangares.size() < N_HANGARES:
		print("NÃO ACHEI TODOS (portos %d, hangares %d)" % [portos.size(), hangares.size()])
	quit()

# terreno -> mundo (como mundo/locais.gd local_para_mundo)
static func _mundo(p: Vector2, giro: int, l: Vector2) -> Vector2:
	return p + l.rotated(-giro * PI * 0.5)

func _na_base(p: Vector2) -> bool:
	return p.x > 5600.0 and p.y > -1600.0 and p.y < 2600.0

func _longe(p: Vector2, lista: Array, d: float) -> bool:
	for o in lista:
		if p.distance_to(o) < d:
			return false
	return true

# em terra e com mar a até ~120 m (filtro rápido pela máscara de 20 m)
func _costa(p: Vector2) -> bool:
	var cc := int((p.x + C.WORLD.x) / C.CELL)
	var rr := int((p.y + C.WORLD.y) / C.CELL)
	if cc < 6 or rr < 6 or cc >= C.W - 6 or rr >= C.H - 6 or C.land[rr * C.W + cc] == 0:
		return false
	for d in [3, 6]:
		for o in [Vector2i(d, 0), Vector2i(-d, 0), Vector2i(0, d), Vector2i(0, -d)]:
			if C.land[(rr + o.y) * C.W + cc + o.x] == 0:
				return true
	return false

func _mar(q: Vector2) -> bool:
	if C._em_terra(q):
		return false
	for l in C._f_lagos:
		if (l[0] as Rect2).has_point(q) and Geometry2D.is_point_in_polygon(q, l[1]):
			return false
	return true

func _sem_parque(p: Vector2, t: Vector2) -> bool:
	var x := p.x - t.x * 0.5
	while x <= p.x + t.x * 0.5:
		var z := p.y - t.y * 0.5
		while z <= p.y + t.y * 0.5:
			var cc := int((x + C.WORLD.x) / C.CELL)
			var rr := int((z + C.WORLD.y) / C.CELL)
			if cc < 0 or rr < 0 or cc >= C.W or rr >= C.H or C.park[rr * C.W + cc] == 1:
				return false
			z += 10.0
		x += 10.0
	return true

func _rua_na_frente(p: Vector2, t: Vector2, giro: int) -> bool:
	var dir: Vector2 = [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)][giro]
	for d in [3.0, 6.0, FRENTE_MAX]:
		var c: Vector2 = p + dir * d * 0.5
		var t2: Vector2 = t + dir.abs() * d
		if C._predio_ruim(c.x, c.y, t2.x, t2.y) == "rua":
			return true
	return false

func _porto_ok(p: Vector2, giro: int) -> bool:
	var t := TAM_PORTO if giro % 2 == 0 else Vector2(TAM_PORTO.y, TAM_PORTO.x)
	if C._predio_ruim(p.x, p.y, t.x, t.y) != "" or not _sem_parque(p, t):
		return false
	# mar atrás do cais em todo o comprimento do navio (o fundo do terreno é z = -45 local)
	for s in range(-70, 71, 14):
		for d in [10.0, 18.0, 27.0, 36.0, 46.0]:
			if not _mar(_mundo(p, giro, Vector2(s, -TAM_PORTO.y * 0.5 - d))):
				return false
	return _rua_na_frente(p, t, giro)

# 0..3 = frente para a rua (como ferramentas/escolher_locais.gd) · -1 = não serve
func _giro_rua(p: Vector2, tam: Vector2) -> int:
	for giro in 4:
		var t := tam if giro % 2 == 0 else Vector2(tam.y, tam.x)
		if C._predio_ruim(p.x, p.y, t.x + 4.0, t.y + 4.0) != "" or not _sem_parque(p, t):
			continue
		if _rua_na_frente(p, t, giro):
			return giro
	return -1

# quantos prédios saem (a planta encosta no terreno + 3 m, como em mundo/cidade.gd)
func _predios_em(p: Vector2, giro: int, tam: Vector2) -> int:
	var t := tam if giro % 2 == 0 else Vector2(tam.y, tam.x)
	var ret := Rect2(p - t * 0.5, t).grow(3.0)
	var n := 0
	for gz in range(floori(ret.position.y / 100.0), floori(ret.end.y / 100.0) + 1):
		for gx in range(floori(ret.position.x / 100.0), floori(ret.end.x / 100.0) + 1):
			for pr in plantas.get(Vector2i(gx, gz), []):
				if (pr as Rect2).intersects(ret):
					n += 1
	return n
