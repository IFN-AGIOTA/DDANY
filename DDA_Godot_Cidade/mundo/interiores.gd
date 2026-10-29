extends Node
# PRÉDIOS POR DENTRO PERTO DO JOGADOR (streaming): a cidade tem ~13 mil prédios com entrada; montar todos pesaria
# demais no celular. Então só os mais perto do jogador ganham o interior de verdade (mundo/interior.gd):
#   - a até RAIO_ABRIR metros (da parede, não do centro) o prédio "abre": o bloco do prédio some e entra o térreo
#     com portas, cômodos, móveis, colisão e loot; a mais de RAIO_FECHAR ele "fecha" de novo.
#   - no máximo MAX_ABERTOS ao mesmo tempo e UM montado por vez (sem travadas).
#   - o que ficou no chão do prédio volta para o loot guardado (mundo/loot_mundo.gd) quando ele fecha.
#   - PORTA-MALAS: carros a até RAIO_CARRO metros ganham um contêiner invisível atrás (loot de carro).
#   - 0.74 · MULTIJOGADOR (host): também abre os prédios perto de cada AMIGO (centros_extra, ligado por
#     rede/sessao_rede.gd), para os infectados presos lá dentro existirem e baterem nas paredes de verdade.
#   - 0.72: os INFECTADOS presos lá dentro voltam: a cada CICLO_INFECTADOS horas de jogo o prédio sorteia de novo
#     (se os de antes já morreram ou foram embora). O loot volta sozinho (mundo/loot_mundo.gd, CICLO).
# Mexa AQUI para: distâncias, quantos prédios abertos de uma vez, de quanto em quanto tempo os infectados voltam.

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
const CHANCE_DORMINDO := 0.45        # 1.00: dos infestados, quantos têm um GRUPO DORMINDO (2 a 4 juntos num cômodo)
const CICLO_INFECTADOS := 6.0         # 0.72: horas de jogo (6 h = 12 min de verdade)
var _infestados := {}                 # prédio -> ciclo em que foi sorteado (nesta partida)
var ativo := true
var centros_extra := Callable()       # 0.74: host: posições dos amigos (Array de Vector3)
var _hash := {}                       # Vector2i -> PackedInt32Array (prédios com entrada)
var _hash_carros := {}                # Vector2i -> PackedInt32Array (carros)
var _malas := {}                      # índice do carro -> CaixaMundo
var _t := 0.0
var ms_ultimo := 0.0                  # tempo para montar o último interior (diagnóstico; 1.00: só o 1º quadro)
# 1.00 · MONTAR AOS POUCOS (estudos/ESTUDO_AAA.md 1.12/1.13): o que é da thread principal (caixas de loot dos móveis,
# portas, janelas, o loot do chão e os infectados de dentro) é feito em fatias de até FATIA_US por quadro
const FATIA_US := 2500
var usar_fatias := true
var ms_maior_fatia := 0.0             # (testes) o quadro mais pesado montando aos poucos
var _montando := -1                   # prédio sendo montado aos poucos (-1 = nenhum)
var _sem_chao := {}                   # prédios cujo loot do chão ainda não foi espalhado (fechar não guarda nada)
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
	var centros: Array[Vector2] = [p]
	if centros_extra.is_valid():
		for q in centros_extra.call():
			centros.append(Vector2((q as Vector3).x, (q as Vector3).z))
	var max_abertos := mini(MAX_ABERTOS + 2 * (centros.size() - 1), 11)
	# fecha os que ficaram longe (de todos)
	for i in abertos.keys():
		if _dist_centros(centros, cidade.predio_info[i]) > RAIO_FECHAR:
			fechar(i)
	# o mais perto (de alguém) que ainda não está aberto
	var melhor := -1
	var md := RAIO_ABRIR
	for pc in centros:
		var c := Vector2i(floori(pc.x / CEL), floori(pc.y / CEL))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var k := c + Vector2i(dx, dz)
				if not _hash.has(k):
					continue
				for i in _hash[k]:
					if abertos.has(i):
						continue
					var d := _dist_ret(pc, cidade.predio_info[i])
					if d < md:
						md = d
						melhor = i
	if melhor >= 0:
		if abertos.size() >= max_abertos:
			# troca o aberto mais longe, se o novo estiver mais perto
			var longe := -1
			var dl := md
			for i in abertos:
				var d := _dist_centros(centros, cidade.predio_info[i])
				if d > dl:
					dl = d
					longe = i
			if longe >= 0:
				fechar(longe)
		if abertos.size() < max_abertos:
			abrir(melhor)
	_porta_malas(p)

static func _dist_centros(centros: Array[Vector2], inf: Dictionary) -> float:
	var m := INF
	for pc in centros:
		m = minf(m, _dist_ret(pc, inf))
	return m

func abrir(i: int, ja := false) -> void:
	if abertos.has(i) or _tarefa >= 0 or (_montando >= 0 and not ja):
		return
	var inf: Dictionary = cidade.predio_info[i]
	if usar_thread and not ja:
		_tarefa_i = i
		_tarefa = WorkerThreadPool.add_task(func(): _tarefa_res = InteriorCls.preparar(inf, i, cidade), false, "interior")
		return
	_terminar(i, InteriorCls.preparar(inf, i, cidade), ja)

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

func _terminar(i: int, prep, ja := false) -> void:
	if prep == null or abertos.has(i):
		return
	var t0 := Time.get_ticks_usec()
	var inf: Dictionary = cidade.predio_info[i]
	var tarefas: Array = []
	var no: Node3D = prep.criar(loot, tarefas)     # paredes, móveis e colisão já; o resto vira tarefa
	add_child(no)
	abertos[i] = no
	cidade.esconder_predio(i, true)
	mundo.abertos[i] = true
	mundo.refazer_predios()      # refaz a colisão dos prédios perto (sem o bloco deste)
	_sem_chao[i] = true
	tarefas.append(func():
		if loot != null and no.has_meta("pontos_chao"):
			loot.espalhar_chao("p%d" % i, String(inf.get("uso", "")), no.get_meta("pontos_chao"), no)
		_sem_chao.erase(i))
	tarefas.append(func(): _infestar(i, no))
	if ja or not usar_fatias:
		for f in tarefas:
			f.call()
		ms_ultimo = (Time.get_ticks_usec() - t0) / 1000.0
		return
	ms_ultimo = (Time.get_ticks_usec() - t0) / 1000.0
	# o resto aos poucos (ele abre a ~40 m: ninguém chega antes de terminar)
	_montando = i
	await get_tree().process_frame
	var ini := Time.get_ticks_usec()
	for f in tarefas:
		if not is_instance_valid(no) or abertos.get(i) != no:
			break                            # fechou no meio
		f.call()
		var gasto := Time.get_ticks_usec() - ini
		if gasto > FATIA_US:
			ms_maior_fatia = maxf(ms_maior_fatia, gasto / 1000.0)
			await get_tree().process_frame
			ini = Time.get_ticks_usec()
	ms_maior_fatia = maxf(ms_maior_fatia, (Time.get_ticks_usec() - ini) / 1000.0)
	_montando = -1

# um ou dois infectados presos lá dentro (saquear não é sempre seguro)
func _infestar(i: int, no: Node3D) -> void:
	if vagos == null or not no.has_meta("pontos_chao") or not bool(vagos.get("ativo")):
		return
	var c := ciclo_infectados(i)
	if int(_infestados.get(i, -1)) >= c:
		return
	_infestados[i] = c
	var inf: Dictionary = cidade.predio_info[i]
	if vagos.vivos_perto(no.global_position, maxf(float(inf["sx"]), float(inf["sz"])) * 0.5 + 6.0) > 0:
		return                            # os de antes ainda estão por aí
	var r := RandomNumberGenerator.new()
	r.seed = i * 7349 + (loot.semente if loot != null else 0) + c * 104729
	if r.randf() >= CHANCE_INFESTADO:
		return
	var pontos: Array = no.get_meta("pontos_chao")
	# 1.00 · GRUPO DORMINDO (The Last of Us): 2 a 4 em pé, quietos, juntos no mesmo cômodo (vago.gd DORMINDO)
	if r.randf() < CHANCE_DORMINDO and not pontos.is_empty():
		var lp0: Vector3 = pontos[r.randi() % pontos.size()][0]
		var n_d := r.randi_range(2, 4)
		for k in n_d:
			var lp := lp0 + Vector3(r.randf_range(-1.4, 1.4), 0.0, r.randf_range(-1.4, 1.4))
			var gp: Vector3 = no.global_transform * lp
			if jogador != null and gp.distance_to(jogador.global_position) < 7.0:
				continue
			var vd = vagos._criar(gp + Vector3(0, 0.05, 0), Vector3.INF)
			if vd != null:
				vd.rotation.y = r.randf() * TAU
				vd.dormir()
		return
	var n := 1 if r.randf() < 0.65 else 2
	for k in n:
		if pontos.is_empty():
			break
		var lp: Vector3 = pontos[r.randi() % pontos.size()][0]
		var gp: Vector3 = no.global_transform * lp
		if jogador != null and gp.distance_to(jogador.global_position) < 7.0:
			continue
		vagos._criar(gp + Vector3(0, 0.05, 0), Vector3.INF)

func ciclo_infectados(i: int) -> int:
	var h: float = loot.horas() if loot != null else 0.0
	return floori((h + fposmod(i * 0.618034, 1.0) * CICLO_INFECTADOS) / CICLO_INFECTADOS)

func fechar(i: int) -> void:
	if not abertos.has(i):
		return
	var no: Node3D = abertos[i]
	abertos.erase(i)
	if loot != null and is_instance_valid(no) and not _sem_chao.has(i):      # (1.00: ainda montando = nada a guardar)
		loot.guardar_chao("p%d" % i, no)
	_sem_chao.erase(i)
	if is_instance_valid(no):
		no.queue_free()
	cidade.esconder_predio(i, false)
	mundo.abertos.erase(i)
	mundo.refazer_predios()

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
