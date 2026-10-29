extends Node
# CHUNKS: o mundo dividido em quadrados de TAM_CHUNK (500 m). Só ficam na cena os chunks perto da CÂMERA:
# do chunk dela até RAIO chunks para cada lado (um quadrado de (2 x RAIO + 1)² chunks). O resto sai da cena
# (remove_child): a placa de vídeo e o "culling" da Godot nem sabem que existe.
#   ALIMENTAR (carregar): um chunk entrou no raio -> os nós dele voltam para a cena.
#   DIMINUIR (descarregar): um chunk passou de RAIO + 1 (folga para não ficar carrega/descarrega na divisa) -> sai.
# A cidade é montada uma vez (mundo/cidade.gd) em pedaços que cabem nos chunks: prédios 500 m, chão e lotes
# 500 m, fachadas 500 m, árvores/carros/oclusores 250 m. Cada nó vai para TODO chunk que a caixa (AABB) dele
# encosta e fica na cena enquanto QUALQUER um deles estiver carregado (contador). Coisas enormes (mar, céu, sol)
# e nós que cobrem chunks demais ficam sempre.
# O trabalho é espalhado: no máximo OPS_POR_QUADRO nós por quadro, os chunks mais perto primeiro. Se a câmera
# pular longe (renascer, carregar o jogo) carrega tudo na hora (forcar).
# Raio: Opções › Gráficos › "Raio de chunks" (AUTO = segue a "Distância de visão"). A câmera não enxerga além
# do raio (menu/aplicar_opcoes.gd ajusta o "far" e a neblina).
# PAUSA FORA DOS CHUNKS: o que se mexe no mundo (infectados e corpos, fogueiras, jogadores remotos:
# grupo GRUPO_PAUSA) fica PAUSADO (process_mode desligado: não pensa, não anima, não toca som) quando está fora dos
# chunks ativos. Ativo = a até RAIO chunks da câmera; no HOST do multijogador também em volta de cada amigo
# (centros_extra), porque os infectados perto dele precisam continuar vivos. Quem tem pausar_por_chunk(bool)
# decide sozinho o que para (o jogador remoto para só a animação: a posição continua chegando).
# 1.00 (estudos/ESTUDO_AAA.md 1.13, como o World Partition da Epic): o trabalho de cada quadro tem um ORÇAMENTO EM
#   TEMPO (ORCAMENTO_US, no mínimo MIN_OPS nós) e pode parar no MEIO de um chunk (continua no quadro seguinte); com
#   a mesma distância, os chunks NA FRENTE da câmera entram antes dos de trás. (A cidade inteira já fica montada
#   na memória: "carregar" aqui é só pôr de volta na cena.)
# Mexa AQUI para: tamanho do chunk, folga, quantos nós por quadro, de quanto em quanto tempo confere a pausa.

const TAM_CHUNK := 500.0
const FOLGA := 1                       # descarrega só em RAIO + FOLGA
const OPS_POR_QUADRO := 90             # (antes de 1.00: o limite era só este)
const ORCAMENTO_US := 1500              # 1.00: até 1,5 ms por quadro pondo/tirando nós
const MIN_OPS := 8
const MAX_CHUNKS_POR_NO := 16          # nó que encosta em mais chunks que isso fica sempre na cena
const RAIO_AUTO := [2, 4, 7, 10]       # AUTO: por "Distância de visão" (900, 1800, 3200, 5000 m)

const GRUPO_PAUSA := "pausa_por_chunk"
const PAUSA_A_CADA := 0.5              # segundos

var raio := 4
var centros_extra := Callable()       # host: -> Array[Vector3] (posição dos amigos) · rede/sessao_rede.gd
var pausados := 0                      # quantos estão pausados agora (estatística/testes)
var _t_pausa := 0.0
var cidade: Node3D
var _chunks := {}                      # Vector2i -> Array[Node3D] (nós que encostam nesse chunk)
var _cont := {}                        # Node3D -> em quantos chunks carregados ele está
var _carregados := {}                  # Vector2i -> true
var _centro := Vector2i(1 << 30, 1 << 30)
var _fila: Array = []                  # [Vector2i, carregar?] pendentes, mais perto primeiro
var _sempre := 0
var us_maior := 0                      # 1.00: (testes) o quadro mais caro de _processar no orçamento
var _dir := Vector2.ZERO               # 1.00: para onde a câmera olha (no chão)

# estatística (FPS/depuração e testes)
var nos_na_cena := 0
var nos_total := 0

func configurar(c: Node3D, r: int) -> void:
	cidade = c
	raio = maxi(1, r)
	_chunks.clear()
	_cont.clear()
	_sempre = 0
	for n in c.built:
		if not is_instance_valid(n) or not (n is GeometryInstance3D or n is OccluderInstance3D):
			continue                       # sol, céu, ambiente: não são "pedaços" do mundo
		var ks := _chunks_do_no(n as VisualInstance3D)
		if ks.is_empty():
			_sempre += 1                   # mar, céu, sol... ficam sempre
			continue
		_cont[n] = 0
		for k in ks:
			if not _chunks.has(k):
				_chunks[k] = []
			_chunks[k].append(n)
	nos_total = _cont.size()
	# começa com tudo fora da cena; o primeiro atualizar() traz o que está perto
	for n in _cont:
		if n.is_inside_tree():
			cidade.remove_child(n)
	_carregados.clear()
	nos_na_cena = 0
	_centro = Vector2i(1 << 30, 1 << 30)
	print("Chunks: ", _chunks.size(), " de ", TAM_CHUNK, " m · ", nos_total, " nós (", _sempre, " sempre na cena) · raio ", raio)

# devolve tudo para a cidade (a cidade continua inteira para o menu/próxima partida)
func _exit_tree() -> void:
	if cidade == null or not is_instance_valid(cidade):
		return
	for n in _cont:
		if is_instance_valid(n) and not n.is_inside_tree():
			cidade.add_child(n)
	_cont.clear()
	_chunks.clear()

func definir_raio(r: int) -> void:
	r = maxi(1, r)
	if r == raio:
		return
	raio = r
	_refazer_fila(_centro)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # segue a câmera também na pausa e no voo

func _process(_dt: float) -> void:
	if cidade == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var f := -cam.global_basis.z
		_dir = Vector2(f.x, f.z).normalized() if Vector2(f.x, f.z).length_squared() > 0.0001 else Vector2.ZERO
		atualizar(cam.global_position)
	_t_pausa -= _dt
	if _t_pausa <= 0.0:
		_t_pausa = PAUSA_A_CADA
		_atualizar_pausa()

# chamar todo quadro com a posição da câmera (o _process já faz isso com a câmera ativa)
func atualizar(pos: Vector3) -> void:
	var c := Vector2i(floori(pos.x / TAM_CHUNK), floori(pos.z / TAM_CHUNK))
	if c != _centro:
		var pulo := maxi(absi(c.x - _centro.x), absi(c.y - _centro.y))
		_refazer_fila(c)
		if pulo > 1:
			_processar(1 << 30)            # pulou longe: carrega tudo agora (sem buraco na tela)
			return
	_processar(1 << 30, ORCAMENTO_US)

func forcar(pos: Vector3) -> void:
	_centro = Vector2i(1 << 30, 1 << 30)
	atualizar(pos)
	_processar(1 << 30)

# ---------- chunks: quais devem estar ativos ----------
func _refazer_fila(c: Vector2i) -> void:
	_centro = c
	# 1.00: um chunk pela metade termina agora (senão ficaria marcado como pronto sem todos os nós)
	if not _fila.is_empty() and (_fila[0] as Array).size() > 2:
		_fila = [_fila[0]]
		_processar(1 << 30)
	_fila.clear()
	# 1. carregar: os que estão no raio e ainda não foram carregados (mais perto primeiro)
	var novos := []
	for dz in range(-raio, raio + 1):
		for dx in range(-raio, raio + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if _chunks.has(k) and not _carregados.has(k):
				novos.append(k)
	# mais perto primeiro; com a mesma distância, o que está na frente da câmera (1.00)
	var dir := _dir
	var chave := func(k: Vector2i) -> float:
		var d := Vector2(k - c)
		return d.length_squared() - (0.75 * d.normalized().dot(dir) if d != Vector2.ZERO else 0.0)
	novos.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return chave.call(a) < chave.call(b))
	for k in novos:
		_fila.append([k, true])
	# 2. descarregar: os que passaram do raio + folga
	for k in _carregados.keys():
		if maxi(absi(k.x - c.x), absi(k.y - c.y)) > raio + FOLGA:
			_fila.append([k, false])

# orcamento = quantos nós no máximo; limite_us > 0 = para quando passar desse tempo (1.00), mesmo no meio de um chunk
func _processar(orcamento: int, limite_us := 0) -> void:
	var t0 := Time.get_ticks_usec()
	var feitos := 0
	while not _fila.is_empty() and orcamento > 0:
		var item: Array = _fila[0]
		var k: Vector2i = item[0]
		var carregar: bool = item[1]
		if item.size() < 3:                    # começando este chunk
			if carregar == _carregados.has(k):
				_fila.pop_front()
				continue
			if carregar:
				_carregados[k] = true
			else:
				_carregados.erase(k)
			item.append(0)
		var lista: Array = _chunks[k]
		var i: int = item[2]
		while i < lista.size() and orcamento > 0:
			var n = lista[i]
			i += 1
			if carregar:
				_cont[n] += 1
				if _cont[n] == 1 and is_instance_valid(n):
					cidade.add_child(n)
					nos_na_cena += 1
			else:
				_cont[n] -= 1
				if _cont[n] == 0 and is_instance_valid(n) and n.is_inside_tree():
					cidade.remove_child(n)
					nos_na_cena -= 1
			orcamento -= 1
			feitos += 1
			if limite_us > 0 and feitos >= MIN_OPS and Time.get_ticks_usec() - t0 > limite_us:
				orcamento = 0
		item[2] = i
		if i >= lista.size():
			_fila.pop_front()
	if limite_us > 0 and feitos > 0:
		us_maior = maxi(us_maior, Time.get_ticks_usec() - t0)

# chunks que a caixa do nó encosta ([] = fica sempre na cena)
func _chunks_do_no(n: VisualInstance3D) -> Array:
	var a := n.get_aabb()
	if a.size == Vector3.ZERO or not a.size.is_finite():
		return []
	var g := n.global_transform * a if n.is_inside_tree() else n.transform * a
	var c0 := Vector2i(floori(g.position.x / TAM_CHUNK), floori(g.position.z / TAM_CHUNK))
	var c1 := Vector2i(floori(g.end.x / TAM_CHUNK), floori(g.end.z / TAM_CHUNK))
	if (c1.x - c0.x + 1) * (c1.y - c0.y + 1) > MAX_CHUNKS_POR_NO:
		return []
	var o := []
	for x in range(c0.x, c1.x + 1):
		for z in range(c0.y, c1.y + 1):
			o.append(Vector2i(x, z))
	return o

static func raio_auto(dist: int) -> int:
	return RAIO_AUTO[clampi(dist, 0, 3)]

# ---------- pausa de quem está fora dos chunks ativos ----------
func _chunk_de(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / TAM_CHUNK), floori(p.z / TAM_CHUNK))

func ativo_em(p: Vector3, extras := []) -> bool:
	var k := _chunk_de(p)
	if maxi(absi(k.x - _centro.x), absi(k.y - _centro.y)) <= raio:
		return true
	for c in extras:
		var kc := _chunk_de(c)
		if maxi(absi(k.x - kc.x), absi(k.y - kc.y)) <= raio:
			return true
	return false

func _atualizar_pausa() -> void:
	var extras: Array = centros_extra.call() if centros_extra.is_valid() else []
	var n_p := 0
	for n in get_tree().get_nodes_in_group(GRUPO_PAUSA):
		if not (n is Node3D) or not n.is_inside_tree():
			continue
		var pausar := not ativo_em((n as Node3D).global_position, extras)
		if pausar:
			n_p += 1
		if n.has_method("pausar_por_chunk"):
			n.pausar_por_chunk(pausar)
		else:
			var modo := Node.PROCESS_MODE_DISABLED if pausar else Node.PROCESS_MODE_INHERIT
			if n.process_mode != modo:
				n.process_mode = modo
	pausados = n_p
