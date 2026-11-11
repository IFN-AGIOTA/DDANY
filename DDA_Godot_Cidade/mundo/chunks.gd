extends Node
# CHUNKS: o mundo dividido em quadrados de TAM_CHUNK (500 m). Só ficam na cena os chunks perto da CÂMERA:
# do chunk dela até RAIO chunks para cada lado (um quadrado de (2 x RAIO + 1)² chunks). O resto sai da cena
# (remove_child): a placa de vídeo e o "culling" da Godot nem sabem que existe.
#   ALIMENTAR (carregar): um chunk entrou no raio -> os nós dele voltam para a cena.
#   DIMINUIR (descarregar): um chunk passou de RAIO + 1 (folga para não ficar carrega/descarrega na divisa) -> sai.
# A cidade é montada uma vez (mundo/cidade.gd) em pedaços que cabem nos chunks: prédios 500 m, chão e lotes
# 2000 m, fachadas 500 m, árvores/carros/oclusores 250 m. Coisas enormes (mar, céu, sol) ficam sempre.
# O trabalho é espalhado: no máximo ORCAMENTO_US por quadro, os chunks mais perto (e na frente) primeiro. Se a câmera
# pular longe (renascer, carregar o jogo) carrega tudo na hora (forcar).
# Raio: Opções › Gráficos › "Raio de chunks" (AUTO = segue a "Distância de visão"). A câmera não enxerga além
# do raio (menu/aplicar_opcoes.gd ajusta o "far" e a neblina).
# PAUSA FORA DOS CHUNKS: o que se mexe no mundo (infectados e corpos, fogueiras, jogadores remotos:
# grupo GRUPO_PAUSA) fica PAUSADO (process_mode desligado: não pensa, não anima, não toca som) quando está fora dos
# chunks ativos. Ativo = a até RAIO chunks da câmera; no HOST do multijogador também em volta de cada amigo
# (centros_extra), porque os infectados perto dele precisam continuar vivos. Quem tem pausar_por_chunk(bool)
# decide sozinho o que para (o jogador remoto para só a animação: a posição continua chegando).
# 1.00 (estudos/ESTUDO_AAA.md 1.13, como o World Partition da Epic): o trabalho de cada quadro tem um ORÇAMENTO EM
#   TEMPO (ORCAMENTO_US, no mínimo MIN_OPS operações) e pode parar no MEIO de um chunk (continua no quadro seguinte);
#   com a mesma distância, os chunks NA FRENTE da câmera entram antes dos de trás.
# 1.23 · SISTEMA DE VISIBILIDADE E RENDERIZAÇÃO (estudos/ESTUDO_AAA.md 1.15). Medido antes: cada objeto NA CENA custa
#   ~80 ns de processador por quadro para a Godot descartar, mesmo sem aparecer (escondido ainda ~36 ns), e o jogo
#   deixava ~15 mil na cena; a maioria (postes, hidrantes, bancos, carros...) tem alcance de 200 a 900 m e ficava
#   carregada a até 3,5 km. Agora:
#   1. CARGA EM ANÉIS (carregar ≠ mostrar): cada nó vai para o ANEL do alcance dele: só entra na cena quando a câmera
#      está a até ANEL chunks do chunk dele (anel = 1 + (alcance máximo + MARGEM) / TAM_CHUNK; sem alcance = o raio).
#      Um hidrante (200 m) fica nos 3 x 3 chunks em volta; um prédio, no raio inteiro. Prioridade: perto > meio > longe.
#      O alcance máximo considera as opções (o maior fator de "Detalhes dos modelos"/"Distância dos detalhes"), então
#      nada que poderia aparecer fica de fora.
#   2. CONTÊINER POR CHUNK E ANEL: os nós que cabem num chunk (com MARGEM) ficam num Node3D "Chunk_x_z_anel": pôr/tirar
#      o chunk é UMA operação (antes, uma por nó). Os que atravessam vários chunks (chão de 2 km, pontes) seguem
#      contados um a um (ficam enquanto qualquer chunk deles estiver carregado).
#   3. CAMADA DE VISIBILIDADE POR CHUNK: a caixa de cada chunk é testada contra a câmera (os 4 planos dos lados, com
#      folga fixa + folga que cresce com a distância); o chunk todo fora da câmera é ESCONDIDO (os contêineres dele).
#      Cache: só recalcula quando a câmera anda VIS_MOVER m, vira VIS_VIRAR ou muda o zoom; mostrar é NA HORA (nada
#      some na tela), esconder vai no orçamento VIS_ORCAMENTO_US. Os chunks em volta da câmera (até 1) nunca somem
#      (a sombra do sol vem deles). Dentro dos chunks visíveis, a Godot ainda descarta cada objeto pela câmera e pela
#      OCLUSÃO nativa (mundo/oclusao.gd).
#   Painel de depuração: F3 (hud/painel_render.gd) mostra tudo isso; estatisticas() dá os números.
# Mexa AQUI para: tamanho do chunk, folga, orçamentos, margens da camada de visibilidade, de quanto em quanto tempo
# confere a pausa.

const TAM_CHUNK := 500.0
const FOLGA := 1                       # descarrega só em ANEL + FOLGA
const ORCAMENTO_US := 1500             # 1.00: até 1,5 ms por quadro pondo/tirando nós
const MIN_OPS := 8
const MAX_CHUNKS_POR_NO := 25          # nó que encosta em mais chunks que isso fica sempre na cena (1.23: 25; o chão de 2 km entra)
const RAIO_AUTO := [2, 4, 7, 10]       # AUTO: por "Distância de visão" (900, 1800, 3200, 5000 m)
const MARGEM := 30.0                   # 1.23: nó que passa até isto da borda do chunk dele ainda vai no contêiner
const FATOR_ALCANCE := 1.3             # 1.23: o maior multiplicador de alcance das opções
const ANEL_TODO := 1 << 20             # sem alcance: o raio inteiro
# camada de visibilidade (1.23)
const VIS_MOVER := 8.0                 # m: a câmera andou isso -> recalcula
const VIS_VIRAR := 0.07                # rad (~4°): virou isso -> recalcula (a folga de ângulo cobre ~8°)
const VIS_FOLGA := 40.0                # m de folga nos planos da câmera...
const VIS_FOLGA_ANG := 0.14            # ... + isso x a distância (~8°): girar entre dois cálculos não mostra buraco
const VIS_ORCAMENTO_US := 400          # esconder no máximo isso por quadro (mostrar é na hora)

const GRUPO_PAUSA := "pausa_por_chunk"
const PAUSA_A_CADA := 0.5              # segundos

var raio := 4
var centros_extra := Callable()       # host: -> Array[Vector3] (posição dos amigos) · rede/sessao_rede.gd
var pausados := 0                      # quantos estão pausados agora (estatística/testes)
var _t_pausa := 0.0
var cidade: Node3D
var camada_visibilidade := true        # 1.23: esconder os chunks fora da câmera (o painel F3 e os testes comparam)

# carga (1.23: por UNIDADE = chunk + anel)
var _unid := {}                        # Vector3i(x, z, anel) -> [contêiner (Node3D ou null), grandes (Array)]
var _aneis := {}                       # Vector2i -> Array[int] (os anéis que esse chunk tem)
var _cont := {}                        # nó grande -> em quantas unidades carregadas ele está
var _carregados := {}                  # Vector3i -> true
var _centro := Vector2i(1 << 30, 1 << 30)
var _fila: Array = []                  # [Vector3i, carregar?, passo] pendentes (passo 0 = contêiner, 1.. = grandes)
var _sempre := 0
var us_maior := 0                      # 1.00: (testes) o quadro mais caro de _processar no orçamento
var _dir := Vector2.ZERO               # 1.00: para onde a câmera olha (no chão)

# visibilidade (1.23)
var _caixa := {}                       # Vector2i -> AABB (tudo que está nos contêineres do chunk)
var _conts_chunk := {}                 # Vector2i -> Array[Node3D] (os contêineres do chunk, um por anel)
var _na_cena := {}                     # Vector2i -> nós dos contêineres do chunk que estão na cena (só os chunks com algum)
var _escondido := {}                   # Vector2i -> true (chunks escondidos agora)
var _esconder: Array = []              # chunks esperando para esconder (no orçamento)
var _a_esconder := {}                  # Vector2i -> true (os que estão em _esconder)
var _vis_pos := Vector3(1.0e9, 0.0, 1.0e9)
var _vis_frente := Vector3.ZERO
var _vis_fov := 0.0
var _vis_sujo := true
var us_visibilidade := 0               # µs do último cálculo
var us_vis_maior := 0
var calculos_vis := 0
var chunks_visiveis := 0               # chunks carregados à vista
var chunks_fora := 0                   # chunks carregados fora da câmera (escondidos)
var nos_visiveis := 0                  # nós dos contêineres à vista

# estatística (FPS/depuração e testes)
var nos_na_cena := 0
var nos_total := 0

func configurar(c: Node3D, r: int) -> void:
	cidade = c
	raio = maxi(1, r)
	_unid.clear()
	_aneis.clear()
	_cont.clear()
	_carregados.clear()
	_caixa.clear()
	_conts_chunk.clear()
	_escondido.clear()
	_esconder.clear()
	_a_esconder.clear()
	_na_cena.clear()
	_fila.clear()
	_sempre = 0
	nos_total = 0
	var n_cont := 0
	for n in c.built:
		if not is_instance_valid(n) or not (n is GeometryInstance3D or n is OccluderInstance3D):
			continue                       # sol, céu, ambiente: não são "pedaços" do mundo
		var a := _caixa_do_no(n as VisualInstance3D)
		if a.size == Vector3.ZERO or not a.size.is_finite():
			_sempre += 1                   # mar, céu, sol... ficam sempre
			continue
		var c0 := Vector2i(floori(a.position.x / TAM_CHUNK), floori(a.position.z / TAM_CHUNK))
		var c1 := Vector2i(floori(a.end.x / TAM_CHUNK), floori(a.end.z / TAM_CHUNK))
		if (c1.x - c0.x + 1) * (c1.y - c0.y + 1) > MAX_CHUNKS_POR_NO:
			_sempre += 1
			continue
		var anel := anel_de(n)
		var meio := a.get_center()
		var k := Vector2i(floori(meio.x / TAM_CHUNK), floori(meio.z / TAM_CHUNK))
		var area := Rect2(Vector2(k) * TAM_CHUNK - Vector2.ONE * MARGEM, Vector2.ONE * (TAM_CHUNK + 2.0 * MARGEM))
		if n.get_parent() != null:
			n.get_parent().remove_child(n)  # começa fora da cena; o primeiro atualizar() traz o que está perto
		nos_total += 1
		if area.encloses(Rect2(a.position.x, a.position.z, a.size.x, a.size.z)):
			# cabe no chunk: vai no contêiner (chunk, anel)
			var u: Array = _unidade(k, anel)
			if u[0] == null:
				var ct := Node3D.new()
				ct.name = "Chunk_%d_%d_%d" % [k.x, k.y, mini(anel, 99)]
				u[0] = ct
				if not _conts_chunk.has(k):
					_conts_chunk[k] = []
				_conts_chunk[k].append(ct)
				n_cont += 1
			(u[0] as Node3D).add_child(n)
			_caixa[k] = a if not _caixa.has(k) else (_caixa[k] as AABB).merge(a)
		else:
			# atravessa chunks: contado um a um, em cada chunk que encosta
			_cont[n] = 0
			for x in range(c0.x, c1.x + 1):
				for z in range(c0.y, c1.y + 1):
					(_unidade(Vector2i(x, z), anel)[1] as Array).append(n)
	nos_na_cena = 0
	_centro = Vector2i(1 << 30, 1 << 30)
	_vis_sujo = true
	print("Chunks: ", _aneis.size(), " de ", TAM_CHUNK, " m · ", nos_total, " nós (", n_cont, " contêineres, ", _cont.size(),
		" atravessam chunks, ", _sempre, " sempre na cena) · raio ", raio)

func _unidade(k: Vector2i, anel: int) -> Array:
	var u := Vector3i(k.x, k.y, anel)
	if not _unid.has(u):
		_unid[u] = [null, []]
		if not _aneis.has(k):
			_aneis[k] = []
		_aneis[k].append(anel)
	return _unid[u]

# a caixa do nó no mundo (a cidade fica na origem)
func _caixa_do_no(n: VisualInstance3D) -> AABB:
	var a := n.get_aabb()
	if a.size == Vector3.ZERO or not a.size.is_finite():
		return AABB()
	return n.global_transform * a if n.is_inside_tree() else n.transform * a

# 1.23: até onde o nó pode aparecer (m; 0 = sem limite), já com o maior fator das opções
static func alcance_de(n: Node) -> float:
	if n.has_meta("alcance_carga"):
		return float(n.get_meta("alcance_carga"))            # dito por quem montou (ex.: troca perto/longe da rua)
	if n.has_meta("alc"):
		return float((n.get_meta("alc") as Vector2).y) * FATOR_ALCANCE    # o original guardado por abandono.aplicar_modelos
	if n.has_meta("alcance"):
		return float(n.get_meta("alcance")) * FATOR_ALCANCE  # vegetação (cidade.aplicar_detalhes multiplica até 1,3)
	if n is GeometryInstance3D and (n as GeometryInstance3D).visibility_range_end > 0.0:
		return (n as GeometryInstance3D).visibility_range_end * FATOR_ALCANCE
	return 0.0

# 1.23: o anel (em chunks) até onde o nó precisa estar na cena: com a câmera em qualquer ponto do chunk dela, o ponto
# mais perto do chunk do nó (+ MARGEM) fica a pelo menos (distância - 1) x TAM_CHUNK - MARGEM
static func anel_de(n: Node) -> int:
	var al := alcance_de(n)
	if al <= 0.0:
		return ANEL_TODO
	return 1 + int(floor((al + MARGEM) / TAM_CHUNK))

# devolve tudo para a cidade (a cidade continua inteira para o menu/próxima partida)
func _exit_tree() -> void:
	if cidade == null or not is_instance_valid(cidade):
		return
	for u in _unid:
		var dados: Array = _unid[u]
		var ct = dados[0]
		if ct != null and is_instance_valid(ct):
			for n in (ct as Node3D).get_children():
				ct.remove_child(n)
				cidade.add_child(n)
			if ct.get_parent() != null:
				ct.get_parent().remove_child(ct)
			ct.free()
	for n in _cont:
		if is_instance_valid(n) and n.get_parent() == null:
			cidade.add_child(n)
	_unid.clear()
	_cont.clear()
	_conts_chunk.clear()

func definir_raio(r: int) -> void:
	r = maxi(1, r)
	if r == raio:
		return
	raio = r
	_refazer_fila(_centro)
	_vis_sujo = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # segue a câmera também na pausa e no voo
	process_priority = 100                      # 1.23: depois de quem mexe na câmera (a visibilidade usa a câmera final)

func _process(_dt: float) -> void:
	if cidade == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var f := -cam.global_basis.z
		_dir = Vector2(f.x, f.z).normalized() if Vector2(f.x, f.z).length_squared() > 0.0001 else Vector2.ZERO
		atualizar(cam.global_position)
		_visibilidade(cam)
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
	_vis_sujo = true

# ---------- carga: quais unidades (chunk + anel) devem estar na cena ----------
func _refazer_fila(c: Vector2i) -> void:
	_centro = c
	# 1.00: uma unidade pela metade termina agora (senão ficaria marcada como pronta sem todos os nós)
	if not _fila.is_empty() and (_fila[0] as Array).size() > 2:
		_fila = [_fila[0]]
		_processar(1 << 30)
	_fila.clear()
	# 1. carregar: as que estão no anel delas e ainda não foram carregadas (mais perto primeiro)
	var novos := []
	for dz in range(-raio, raio + 1):
		for dx in range(-raio, raio + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			var an = _aneis.get(k)
			if an == null:
				continue
			var d := maxi(absi(dx), absi(dz))
			for anel in an:
				if d <= mini(anel, raio):
					var u := Vector3i(k.x, k.y, anel)
					if not _carregados.has(u):
						novos.append(u)
	# mais perto primeiro; com a mesma distância, o que está na frente da câmera (1.00)
	var dir := _dir
	var chave := func(u: Vector3i) -> float:
		var d := Vector2(u.x - c.x, u.y - c.y)
		return d.length_squared() - (0.75 * d.normalized().dot(dir) if d != Vector2.ZERO else 0.0)
	novos.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return chave.call(a) < chave.call(b))
	for u in novos:
		_fila.append([u, true])
	# 2. descarregar: as que passaram do anel + folga
	for u in _carregados.keys():
		if maxi(absi(u.x - c.x), absi(u.y - c.y)) > mini(u.z, raio) + FOLGA:
			_fila.append([u, false])

# orcamento = quantas operações no máximo; limite_us > 0 = para quando passar desse tempo (1.00), mesmo no meio de uma
# unidade (o contêiner é uma operação; cada nó que atravessa chunks é outra)
func _processar(orcamento: int, limite_us := 0) -> void:
	var t0 := Time.get_ticks_usec()
	var feitos := 0
	while not _fila.is_empty() and orcamento > 0:
		var item: Array = _fila[0]
		var u: Vector3i = item[0]
		var carregar: bool = item[1]
		if item.size() < 3:                    # começando esta unidade
			if carregar == _carregados.has(u):
				_fila.pop_front()
				continue
			if carregar:
				_carregados[u] = true
			else:
				_carregados.erase(u)
			item.append(0)
		var dados: Array = _unid[u]
		var i: int = item[2]
		if i == 0:
			var ct = dados[0]
			if ct != null and is_instance_valid(ct):
				var kc := Vector2i(u.x, u.y)
				if carregar and not ct.is_inside_tree():
					(ct as Node3D).visible = not _escondido.has(kc)
					cidade.add_child(ct)
					nos_na_cena += ct.get_child_count()
					_na_cena[kc] = int(_na_cena.get(kc, 0)) + ct.get_child_count()
				elif not carregar and ct.is_inside_tree():
					cidade.remove_child(ct)
					nos_na_cena -= ct.get_child_count()
					var resto: int = int(_na_cena.get(kc, 0)) - ct.get_child_count()
					if resto > 0:
						_na_cena[kc] = resto
					else:
						_na_cena.erase(kc)
				orcamento -= 1
				feitos += 1
				_vis_sujo = true
				if limite_us > 0 and Time.get_ticks_usec() - t0 > limite_us:
					orcamento = 0                  # um contêiner já pode ter centenas de nós: o tempo vale logo
			i = 1
		var lista: Array = dados[1]
		while i - 1 < lista.size() and orcamento > 0:
			var n = lista[i - 1]
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
		if limite_us > 0 and feitos >= MIN_OPS and Time.get_ticks_usec() - t0 > limite_us:
			orcamento = 0
		item[2] = i
		if i - 1 >= lista.size():
			_fila.pop_front()
	if limite_us > 0 and feitos > 0:
		us_maior = maxi(us_maior, Time.get_ticks_usec() - t0)

# ---------- 1.23: camada de visibilidade (chunks fora da câmera somem) ----------
func _visibilidade(cam: Camera3D) -> void:
	if not camada_visibilidade:
		if not _escondido.is_empty():
			for k in _escondido.keys():
				_mostrar(k)
		_esconder.clear()
		_a_esconder.clear()
		chunks_fora = 0
		_vis_sujo = true                       # ao religar, recalcula na hora
		return
	var pos := cam.global_position
	var fr := -cam.global_basis.z
	if _vis_sujo or pos.distance_squared_to(_vis_pos) > VIS_MOVER * VIS_MOVER or fr.dot(_vis_frente) < cos(VIS_VIRAR) \
			or absf(cam.fov - _vis_fov) > 0.5:
		_vis_sujo = false
		_vis_pos = pos
		_vis_frente = fr
		_vis_fov = cam.fov
		_calcular_visibilidade(cam, pos)
	# esconder no orçamento (o mais longe primeiro: está no fim da lista)
	if not _esconder.is_empty():
		var t0 := Time.get_ticks_usec()
		while not _esconder.is_empty():
			var k: Vector2i = _esconder.pop_back()
			if not _a_esconder.has(k):
				continue
			_a_esconder.erase(k)
			_aplicar(k, false)
			if Time.get_ticks_usec() - t0 > VIS_ORCAMENTO_US:
				break

func _calcular_visibilidade(cam: Camera3D, pos: Vector3) -> void:
	var t0 := Time.get_ticks_usec()
	var planos := cam.get_frustum()            # perto, longe, esquerda, cima, direita, baixo (normal para fora)
	var lados := [planos[2], planos[3], planos[4], planos[5]]
	var c := _centro
	var vis := 0
	var fora := 0
	var nv := 0
	var novos_esc := []
	# só os chunks com contêiner na cena (os de fora da cena entram com o estado guardado e marcam "sujo")
	for k in _na_cena:
		var d := maxi(absi(k.x - c.x), absi(k.y - c.y))
		var alvo := true
		if d > 1:                                    # os chunks em volta da câmera nunca somem (sombra do sol)
			var a: AABB = _caixa[k]
			var folga := VIS_FOLGA + (a.get_center() - pos).length() * VIS_FOLGA_ANG
			for pl in lados:
				var p: Plane = pl
				var v := Vector3(a.position.x if p.normal.x > 0.0 else a.end.x, a.position.y if p.normal.y > 0.0 else a.end.y,
					a.position.z if p.normal.z > 0.0 else a.end.z)
				if p.distance_to(v) > folga:
					alvo = false
					break
		var agora := not _escondido.has(k)
		if alvo:
			_a_esconder.erase(k)
			if not agora:
				_mostrar(k)                              # mostrar é na hora: nada some da tela
			vis += 1
			nv += int(_na_cena[k])
		else:
			fora += 1
			if agora and not _a_esconder.has(k):
				_a_esconder[k] = true
				novos_esc.append([d, k])
	# os chunks que saíram da cena e ficaram escondidos voltam ao normal (entram de novo no estado certo)
	for k in _escondido.keys():
		if not _na_cena.has(k):
			_aplicar(k, true)
	# os mais perto vão para o fim (escondidos por último); a lista é tirada pelo fim
	novos_esc.sort_custom(func(a, b): return a[0] < b[0])
	for e in novos_esc:
		_esconder.append(e[1])
	chunks_visiveis = vis
	chunks_fora = fora
	nos_visiveis = nv
	calculos_vis += 1
	us_visibilidade = Time.get_ticks_usec() - t0
	us_vis_maior = maxi(us_vis_maior, us_visibilidade)

func _mostrar(k: Vector2i) -> void:
	_a_esconder.erase(k)
	_aplicar(k, true)

func _aplicar(k: Vector2i, v: bool) -> void:
	if v:
		_escondido.erase(k)
	else:
		_escondido[k] = true
	for ct in _conts_chunk.get(k, []):
		(ct as Node3D).visible = v

# o chunk k está à vista agora? (fora = escondido pela camada de visibilidade)
func chunk_visivel(k: Vector2i) -> bool:
	return not _escondido.has(k)

# números para o painel (hud/painel_render.gd) e os testes
func estatisticas() -> Dictionary:
	var chunks := {}
	for u in _carregados:
		chunks[Vector2i(u.x, u.y)] = true
	return {"chunks_carregados": chunks.size(), "unidades": _carregados.size(), "visiveis": chunks_visiveis,
		"fora_da_camera": chunks_fora, "nos_na_cena": nos_na_cena, "nos_visiveis": nos_visiveis, "nos_total": nos_total,
		"sempre": _sempre, "fila": _fila.size(), "us_vis": us_visibilidade, "us_vis_maior": us_vis_maior,
		"us_carga_maior": us_maior, "camada": camada_visibilidade}

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
