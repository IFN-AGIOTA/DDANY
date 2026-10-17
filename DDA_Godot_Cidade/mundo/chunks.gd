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
# pular longe (renascer, cutscene, carregar o jogo) carrega tudo na hora (forcar).
# Raio: Opções › Gráficos › "Raio de chunks" (AUTO = segue a "Distância de visão"). A câmera não enxerga além
# do raio (menu/aplicar_opcoes.gd ajusta o "far" e a neblina).
# Mexa AQUI para: tamanho do chunk, folga, quantos nós por quadro.

const TAM_CHUNK := 500.0
const FOLGA := 1                       # descarrega só em RAIO + FOLGA
const OPS_POR_QUADRO := 90
const MAX_CHUNKS_POR_NO := 9           # nó que encosta em mais chunks que isso fica sempre na cena
const RAIO_AUTO := [2, 4, 7, 10]       # AUTO: por "Distância de visão" (900, 1800, 3200, 5000 m)

var raio := 4
var cidade: Node3D
var _chunks := {}                      # Vector2i -> Array[Node3D] (nós que encostam nesse chunk)
var _cont := {}                        # Node3D -> em quantos chunks carregados ele está
var _carregados := {}                  # Vector2i -> true
var _centro := Vector2i(1 << 30, 1 << 30)
var _fila: Array = []                  # [Vector2i, carregar?] pendentes, mais perto primeiro
var _sempre := 0

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
	process_mode = Node.PROCESS_MODE_ALWAYS     # segue a câmera também na pausa, no voo e nas cutscenes

func _process(_dt: float) -> void:
	if cidade == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		atualizar(cam.global_position)

# chamar todo quadro com a posição da câmera (o _process já faz isso com a câmera ativa)
func atualizar(pos: Vector3) -> void:
	var c := Vector2i(floori(pos.x / TAM_CHUNK), floori(pos.z / TAM_CHUNK))
	if c != _centro:
		var pulo := maxi(absi(c.x - _centro.x), absi(c.y - _centro.y))
		_refazer_fila(c)
		if pulo > 1:
			_processar(1 << 30)            # pulou longe: carrega tudo agora (sem buraco na tela)
			return
	_processar(OPS_POR_QUADRO)

func forcar(pos: Vector3) -> void:
	_centro = Vector2i(1 << 30, 1 << 30)
	atualizar(pos)
	_processar(1 << 30)

# ---------- chunks: quais devem estar ativos ----------
func _refazer_fila(c: Vector2i) -> void:
	_centro = c
	_fila.clear()
	# 1. carregar: os que estão no raio e ainda não foram carregados (mais perto primeiro)
	var novos := []
	for dz in range(-raio, raio + 1):
		for dx in range(-raio, raio + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if _chunks.has(k) and not _carregados.has(k):
				novos.append(k)
	novos.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - c).length_squared() < (b - c).length_squared())
	for k in novos:
		_fila.append([k, true])
	# 2. descarregar: os que passaram do raio + folga
	for k in _carregados.keys():
		if maxi(absi(k.x - c.x), absi(k.y - c.y)) > raio + FOLGA:
			_fila.append([k, false])

func _processar(orcamento: int) -> void:
	while not _fila.is_empty() and orcamento > 0:
		var item: Array = _fila.pop_front()
		var k: Vector2i = item[0]
		if item[1]:
			if _carregados.has(k):
				continue
			_carregados[k] = true
			for n in _chunks[k]:
				_cont[n] += 1
				if _cont[n] == 1 and is_instance_valid(n):
					cidade.add_child(n)
					nos_na_cena += 1
				orcamento -= 1
		else:
			if not _carregados.has(k):
				continue
			_carregados.erase(k)
			for n in _chunks[k]:
				_cont[n] -= 1
				if _cont[n] == 0 and is_instance_valid(n) and n.is_inside_tree():
					cidade.remove_child(n)
					nos_na_cena -= 1
				orcamento -= 1

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
