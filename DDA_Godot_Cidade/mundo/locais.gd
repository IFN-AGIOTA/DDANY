extends Node
# LOCAIS ESPECIAIS (0.68): POSTOS DE GASOLINA, HOSPITAIS, SUPERMERCADOS e ARMAZÉNS. São as ZONAS DE PvP do mapa:
# prédios grandes e caprichados (mundo/local.gd), loot melhor e próprio de cada lugar (mundo/loot_mundo.gd, tabelas
# "posto_*", "hospital_*", "super_*", "armazem_*"), mais infectados e um aviso na tela quando você entra.
#   - ONDE FICAM: lista LOCAIS abaixo (feita por ferramentas/escolher_locais.gd: terreno livre com rua na frente,
#     longe uns dos outros, um de cada perto da base). Os prédios comuns que estavam no terreno saem (mundo/cidade.gd).
#   - DE LONGE: uma "casca" simples (caixas) montada junto com a cidade (cidade.locais_casca).
#   - DE PERTO (até RAIO_ABRIR m da borda do terreno): o local inteiro é montado (numa thread, como os interiores)
#     com móveis, colisão, loot e infectados; a casca some. Longe de novo (RAIO_FECHAR): desmonta e guarda o chão.
#   - No mapa: cada local aparece com a cor e o nome (hud/mapa.gd).
#   - 0.72: os infectados VOLTAM: a cada CICLO_INFECTADOS horas de jogo o local enche de novo quando você chega
#     (se os de antes já morreram ou foram embora). O loot volta pelo ciclo do mundo/loot_mundo.gd (CICLO_LOCAL).
# Mexa AQUI para: quantos/onde (LOCAIS), nomes, cores no mapa, distâncias e quantos infectados.

const LocalCls := preload("res://mundo/local.gd")
const Malhas := preload("res://mundo/malhas.gd")
const Mat := preload("res://mundo/materiais_cidade.gd")

const TAMANHO := {"posto": Vector2(46, 36), "hospital": Vector2(72, 54), "supermercado": Vector2(66, 56), "armazem": Vector2(66, 50)}
const NOMES := {"posto": "POSTO DE GASOLINA", "hospital": "HOSPITAL", "supermercado": "SUPERMERCADO", "armazem": "ARMAZÉM"}
const CORES_MAPA := {"posto": Color(0.95, 0.45, 0.15), "hospital": Color(0.9, 0.2, 0.2), "supermercado": Color(0.3, 0.75, 0.35), "armazem": Color(0.35, 0.6, 0.95)}
const SIGLAS := {"posto": "P", "hospital": "H", "supermercado": "S", "armazem": "A"}

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
]

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

# volumes grandes de cada tipo (para a casca de longe e o mapa): [centro local, tamanho, cor]
static func casca(tipo: String) -> Array:
	match tipo:
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
	return []

# está dentro de um prédio de algum local (volumes grandes da casca)? Para não nascer infectado/caixa dentro das paredes
static var _volumes: Array[Rect2] = []

static func em_construcao(p: Vector2, margem := 0.0) -> bool:
	if _volumes.is_empty():
		for i in LOCAIS.size():
			for v in casca(LOCAIS[i][0]):
				var c3: Vector3 = v[0]
				var t3: Vector3 = v[1]
				if t3.y < 2.5:
					continue
				var a := local_para_mundo(i, Vector2(c3.x, c3.z) - Vector2(t3.x, t3.z) * 0.5)
				var b := local_para_mundo(i, Vector2(c3.x, c3.z) + Vector2(t3.x, t3.z) * 0.5)
				_volumes.append(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()))
	for r in _volumes:
		if r.grow(margem).has_point(p):
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

# casca de longe de um local (nó da cidade; os chunks põem/tiram da cena)
static func montar_casca(i: int, y: float) -> MeshInstance3D:
	var e: Array = LOCAIS[i]
	var c := Malhas.Construtor.new()
	for v in casca(e[0]):
		c.caixa(v[0], v[1], v[2])
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
var hud = null                         # armas/hud_combate.gd (aviso ao entrar)
var abertos := {}                      # índice -> Node3D
var ativo := true
var centros_extra := Callable()        # 0.74: host: posições dos amigos (abre também os locais perto deles)
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
	# entrou numa zona de PvP: aviso
	var agora := em(p, 4.0)
	if agora != _dentro:
		_dentro = agora
		if agora >= 0 and hud != null and hud.has_method("mostrar_aviso"):
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
		_tarefa = WorkerThreadPool.add_task(func(): _tarefa_res = LocalCls.preparar(e[0], i, int(e[3]), Vector2(e[1], e[2])), false, "local")
		return
	_terminar(i, LocalCls.preparar(e[0], i, int(e[3]), Vector2(e[1], e[2])))

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
	if mundo != null:
		mundo.locais_abertos[i] = true          # 0.74: aberto tem colisão de verdade (o tiro de longe não usa a casca)
	var casca_no = cidade.locais_casca[i] if i < cidade.locais_casca.size() else null
	if casca_no != null and is_instance_valid(casca_no):
		casca_no.visible = false
	if loot != null:
		loot.espalhar_chao("L%d" % i, String(LOCAIS[i][0]), no.get_meta("pontos_chao"), no)
	_infestar(i, no, prep.infectados)

func _infestar(i: int, no: Node3D, pontos: Array) -> void:
	if vagos == null or not bool(vagos.get("ativo")):
		return
	var c := ciclo_infectados(i)
	if int(_infestados.get(i, -1)) >= c:
		return
	_infestados[i] = c
	var t: Vector2 = TAMANHO[LOCAIS[i][0]]
	var ainda: int = vagos.vivos_perto(no.global_position, maxf(t.x, t.y) * 0.5 + 10.0)
	var falta := pontos.size() - ainda          # só completa o que falta (os de antes ainda estão por aí)
	for lp in pontos:
		if falta <= 0:
			break
		var gp: Vector3 = no.global_transform * (lp as Vector3)
		if jogador != null and gp.distance_to(jogador.global_position) < PERTO_INFECTADO:
			continue
		vagos._criar(gp + Vector3(0, 0.05, 0), Vector3.INF)
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
