extends Node
# PRÉDIOS POR DENTRO PERTO DO JOGADOR (streaming): a cidade tem ~13 mil prédios com entrada; montar todos pesaria
# demais no celular. Então só os mais perto do jogador ganham o interior de verdade (mundo/interior.gd):
#   - a até RAIO_ABRIR metros (da parede, não do centro) o prédio "abre": o bloco do prédio some e entra o térreo
#     com portas, cômodos, móveis, colisão e loot; a mais de RAIO_FECHAR ele "fecha" de novo.
#   - no máximo MAX_ABERTOS ao mesmo tempo e UM montado por vez (sem travadas).
#   - o que ficou no chão do prédio volta para o loot guardado (mundo/loot_mundo.gd) quando ele fecha.
#   - PORTA-MALAS: carros a até RAIO_CARRO metros ganham um contêiner invisível atrás (loot de carro).
# Mexa AQUI para: distâncias, quantos prédios abertos de uma vez.

const InteriorCls := preload("res://mundo/interior.gd")
const CaixaMundoCls := preload("res://inventario/caixa_mundo.gd")

const RAIO_ABRIR := 42.0
const RAIO_FECHAR := 62.0
const MAX_ABERTOS := 5
const CEL := 100.0
const RAIO_CARRO := 14.0
const CEL_CARRO := 50.0

var cidade = null
var mundo = null
var jogador: Node3D = null
var loot = null
var abertos := {}                     # índice do prédio -> Node3D do interior
var vagos = null                      # inimigos/vagos.gd: às vezes há infectados presos dentro do prédio
const CHANCE_INFESTADO := 0.33
var _infestados := {}                 # prédios já sorteados nesta partida
var ativo := true
var _hash := {}                       # Vector2i -> PackedInt32Array (prédios com entrada)
var _hash_carros := {}                # Vector2i -> PackedInt32Array (carros)
var _malas := {}                      # índice do carro -> CaixaMundo
var _t := 0.0
var ms_ultimo := 0.0                  # tempo para montar o último interior (diagnóstico)
var usar_thread := true               # a parte pesada (paredes, móveis) roda numa thread: o jogo não trava
var _tarefa := -1                     # id da tarefa no WorkerThreadPool
var _tarefa_i := -1
var _tarefa_res = null

func ligar(cid, mun, jog: Node3D, lm) -> void:
	cidade = cid
	mundo = mun
	jogador = jog
	loot = lm
	_hash.clear()
	for i in cidade.predio_info.size():
		var inf: Dictionary = cidade.predio_info[i]
		if not inf.get("entra", false) or inf.get("ruina", false):
			continue
		var k := Vector2i(floori(float(inf["x"]) / CEL), floori(float(inf["z"]) / CEL))
		if not _hash.has(k):
			_hash[k] = PackedInt32Array()
		_hash[k].append(i)
	_hash_carros.clear()
	if cidade.abandono != null:
		var cs: Array = cidade.abandono.carros
		for i in cs.size():
			var p: Vector3 = cs[i][0]
			var k := Vector2i(floori(p.x / CEL_CARRO), floori(p.z / CEL_CARRO))
			if not _hash_carros.has(k):
				_hash_carros[k] = PackedInt32Array()
			_hash_carros[k].append(i)

static func _dist_ret(p: Vector2, inf: Dictionary) -> float:
	var dx := maxf(absf(p.x - float(inf["x"])) - float(inf["sx"]) * 0.5, 0.0)
	var dz := maxf(absf(p.y - float(inf["z"])) - float(inf["sz"]) * 0.5, 0.0)
	return sqrt(dx * dx + dz * dz)

# prédio i aberto e o ponto p (x, z) dentro dele? (usado por outros sistemas: chuva, infectados)
func dentro_de_aberto(p: Vector2) -> bool:
	for i in abertos:
		if _dist_ret(p, cidade.predio_info[i]) <= 0.0:
			return true
	return false

func _process(dt: float) -> void:
	if not ativo or jogador == null or cidade == null:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.2
	if _tarefa >= 0:
		if not WorkerThreadPool.is_task_completed(_tarefa):
			_t = 0.03
			return
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
		_terminar(_tarefa_i, _tarefa_res)
		_tarefa_res = null
	var p := Vector2(jogador.global_position.x, jogador.global_position.z)
	# fecha os que ficaram longe
	for i in abertos.keys():
		if _dist_ret(p, cidade.predio_info[i]) > RAIO_FECHAR:
			fechar(i)
	# o mais perto que ainda não está aberto
	var melhor := -1
	var md := RAIO_ABRIR
	var c := Vector2i(floori(p.x / CEL), floori(p.y / CEL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := c + Vector2i(dx, dz)
			if not _hash.has(k):
				continue
			for i in _hash[k]:
				if abertos.has(i):
					continue
				var d := _dist_ret(p, cidade.predio_info[i])
				if d < md:
					md = d
					melhor = i
	if melhor >= 0:
		if abertos.size() >= MAX_ABERTOS:
			# troca o aberto mais longe, se o novo estiver mais perto
			var longe := -1
			var dl := md
			for i in abertos:
				var d := _dist_ret(p, cidade.predio_info[i])
				if d > dl:
					dl = d
					longe = i
			if longe >= 0:
				fechar(longe)
		if abertos.size() < MAX_ABERTOS:
			abrir(melhor)
	_porta_malas(p)

func abrir(i: int, ja := false) -> void:
	if abertos.has(i) or _tarefa >= 0:
		return
	var inf: Dictionary = cidade.predio_info[i]
	if usar_thread and not ja:
		_tarefa_i = i
		_tarefa = WorkerThreadPool.add_task(func(): _tarefa_res = InteriorCls.preparar(inf, i, cidade), false, "interior")
		return
	_terminar(i, InteriorCls.preparar(inf, i, cidade))

# abre já, sem thread (ao nascer/carregar dentro de um prédio)
func abrir_agora(p: Vector2) -> void:
	for i in _perto(p, 4.0):
		abrir(i, true)

func _perto(p: Vector2, raio: float) -> Array:
	var r := []
	var c := Vector2i(floori(p.x / CEL), floori(p.y / CEL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := c + Vector2i(dx, dz)
			if _hash.has(k):
				for i in _hash[k]:
					if _dist_ret(p, cidade.predio_info[i]) <= raio:
						r.append(i)
	return r

func _terminar(i: int, prep) -> void:
	if prep == null or abertos.has(i):
		return
	var t0 := Time.get_ticks_usec()
	var inf: Dictionary = cidade.predio_info[i]
	var no: Node3D = prep.criar(loot)
	add_child(no)
	abertos[i] = no
	cidade.esconder_predio(i, true)
	mundo.abertos[i] = true
	mundo.set("_ult_pred", Vector2(1.0e9, 1.0e9))      # refaz a colisão dos prédios perto (sem o bloco deste)
	if loot != null and no.has_meta("pontos_chao"):
		loot.espalhar_chao("p%d" % i, String(inf.get("uso", "")), no.get_meta("pontos_chao"), no)
	_infestar(i, no)
	ms_ultimo = (Time.get_ticks_usec() - t0) / 1000.0

# um ou dois infectados presos lá dentro (saquear não é sempre seguro)
func _infestar(i: int, no: Node3D) -> void:
	if vagos == null or _infestados.has(i) or not no.has_meta("pontos_chao") or not bool(vagos.get("ativo")):
		return
	_infestados[i] = true
	var r := RandomNumberGenerator.new()
	r.seed = i * 7349 + (loot.semente if loot != null else 0)
	if r.randf() >= CHANCE_INFESTADO:
		return
	var pontos: Array = no.get_meta("pontos_chao")
	var n := 1 if r.randf() < 0.65 else 2
	for k in n:
		if pontos.is_empty():
			break
		var lp: Vector3 = pontos[r.randi() % pontos.size()][0]
		var gp: Vector3 = no.global_transform * lp
		if jogador != null and gp.distance_to(jogador.global_position) < 7.0:
			continue
		vagos._criar(gp + Vector3(0, 0.05, 0), Vector3.INF)

func fechar(i: int) -> void:
	if not abertos.has(i):
		return
	var no: Node3D = abertos[i]
	abertos.erase(i)
	if loot != null and is_instance_valid(no):
		loot.guardar_chao("p%d" % i, no)
	if is_instance_valid(no):
		no.queue_free()
	cidade.esconder_predio(i, false)
	mundo.abertos.erase(i)
	mundo.set("_ult_pred", Vector2(1.0e9, 1.0e9))

func fechar_todos() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
		_tarefa_res = null
	for i in abertos.keys():
		fechar(i)

# contêiner invisível atrás dos carros perto do jogador
func _porta_malas(p: Vector2) -> void:
	if cidade.abandono == null or loot == null:
		return
	var cs: Array = cidade.abandono.carros
	for i in _malas.keys():
		var q: Vector3 = cs[i][0]
		if Vector2(q.x, q.z).distance_to(p) > RAIO_CARRO + 6.0:
			var n = _malas[i]
			_malas.erase(i)
			if is_instance_valid(n):
				n.queue_free()
	var c := Vector2i(floori(p.x / CEL_CARRO), floori(p.y / CEL_CARRO))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := c + Vector2i(dx, dz)
			if not _hash_carros.has(k):
				continue
			for i in _hash_carros[k]:
				if _malas.has(i):
					continue
				var q: Vector3 = cs[i][0]
				if Vector2(q.x, q.z).distance_to(p) > RAIO_CARRO:
					continue
				var nome: String = cs[i][2]
				var comp: float = {"sedan": 4.4, "taxi": 4.4, "van": 4.9, "onibus": 11.0}.get(nome, 4.4)
				var cx = CaixaMundoCls.new()
				cx.invisivel = true
				cx.nome = "ÔNIBUS" if nome == "onibus" else "PORTA-MALAS"
				cx.tamanho = Vector2i(6, 4) if nome != "onibus" else Vector2i(8, 5)
				cx.grade = loot.grade("c%d" % i, "carro", cx.nome, cx.tamanho)
				add_child(cx)
				cx.global_position = q + Basis(Vector3.UP, float(cs[i][1])) * Vector3(-comp * 0.5 - 0.4, 0.0, 0.0)
				_malas[i] = cx

func _exit_tree() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
