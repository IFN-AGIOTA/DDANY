extends Node
# SESSÃO DE REDE · liga o JOGO EM ANDAMENTO à partida multijogador (rede/rede.gd). Criada pelo main.gd dentro
# do nó "Jogo" quando a partida é em rede. Cada aparelho simula o SEU jogador e manda para os outros:
#   · ESTADO (15 vezes por segundo, pode perder pacote): posição, giro, velocidade, agachado/mirando/morto,
#     arma das mãos e mira  -> os outros mostram um rede/jogador_remoto.gd;
#   · EVENTOS (sempre chegam): "cheguei" (terminou de carregar: os outros respondem), "roupa" (o que está vestido), "acao" (recarregar, golpe, comer...),
#     "tiro" (som + traçante + os infectados de quem ouviu escutam), "mundo" (só o host: hora e clima).
# O HOST manda no mundo: a semente do loot (todo mundo acha as mesmas coisas nos mesmos lugares) e a hora/clima
# (os clientes não trocam o tempo sozinhos).
# AINDA NÃO SINCRONIZADO (próximos passos, ver LEIA-ME): infectados (cada aparelho tem os seus), itens pegos/
# largados e caixas, dano entre jogadores, salvar a partida em rede.
# Mexa AQUI para: o que vai em cada mensagem e de quanto em quanto tempo.

const RemotoCls := preload("res://rede/jogador_remoto.gd")
const ENVIOS_POR_SEG := 15.0
const MUNDO_A_CADA := 5.0                     # host: hora/clima para todos (segundos)
const SLOTS_ROUPA := ["cabeca", "camisa", "colete", "cinto", "ombro", "coldre", "calca", "mochila"]
const DIST_SOM_TIRO := 450.0                  # mais longe que isso não se ouve o tiro do outro

var main: Node
var jogador: Node
var remotos := {}                             # id -> jogador_remoto.gd
var _t_envio := 0.0
var _t_mundo := 0.0

func ligar(m: Node) -> void:
	main = m
	jogador = m.jogador
	Rede.estado_recebido.connect(_estado)
	Rede.evento_recebido.connect(_evento)
	Rede.jogador_entrou.connect(_entrou)
	Rede.jogador_saiu.connect(_saiu)
	jogador.inventario.mudou.connect(_mandar_roupa)
	jogador.animador.tocou_acao.connect(func(n, v, c): Rede.enviar_evento("acao", {"n": n, "v": v, "c": c}))
	jogador.armas.disparou.connect(_mandar_tiro)
	for id in Rede.jogadores:
		if id != Rede.meu_id():
			_criar(id)
	if Rede.eh_cliente():
		_aplicar_mundo(Rede.mundo)
	# "cheguei": os outros respondem com a roupa deles (e o host com o mundo). Antes disso este aparelho ainda
	# estava montando a cidade e não tinha sessão para receber nada.
	Rede.enviar_evento("cheguei", {})
	_roupa_enviada = {}
	_mandar_roupa()

func _exit_tree() -> void:
	for s in [[Rede.estado_recebido, _estado], [Rede.evento_recebido, _evento], [Rede.jogador_entrou, _entrou], [Rede.jogador_saiu, _saiu]]:
		if (s[0] as Signal).is_connected(s[1]):
			(s[0] as Signal).disconnect(s[1])

# ---------- jogadores ----------
func _criar(id: int) -> Node3D:
	if remotos.has(id):
		return remotos[id]
	var r := RemotoCls.new()
	r.name = "Remoto_%d" % id
	r.id = id
	r.nome = Rede.nome_de(id)
	main.jogo.add_child(r)
	r.definir_nome(r.nome)
	r.visible = false                         # aparece no 1º estado (antes disso não se sabe onde está)
	remotos[id] = r
	return r

func _entrou(id: int, _nome: String) -> void:
	_criar(id)
	if main.hud != null:
		main.hud.mostrar_aviso("%s ENTROU NA PARTIDA" % Rede.nome_de(id).to_upper())

func _saiu(id: int) -> void:
	if remotos.has(id):
		var nm: String = remotos[id].nome
		remotos[id].queue_free()
		remotos.erase(id)
		if main.hud != null:
			main.hud.mostrar_aviso("%s SAIU" % nm.to_upper())

# ---------- envio ----------
func _physics_process(dt: float) -> void:
	if not Rede.ligado or jogador == null or not is_instance_valid(jogador):
		return
	_t_envio -= dt
	if _t_envio <= 0.0:
		_t_envio = 1.0 / ENVIOS_POR_SEG
		Rede.enviar_estado(estado_local())
	if Rede.eh_host():
		_t_mundo -= dt
		if _t_mundo <= 0.0:
			_t_mundo = MUNDO_A_CADA
			_mandar_mundo()

# [pos, yaw, vel, bits, arma, aim, since]  (o jogador_remoto.gd lê nesta ordem)
func estado_local() -> Array:
	var j = jogador
	var bits := (1 if j.agachado else 0) | (2 if j.mirando else 0) | (4 if j.morto else 0) | (0 if j.is_on_floor() else 8)
	return [j.global_position, j.rotation.y, j.velocity, bits, str(j.armas.atual), snappedf(j.armas.aim, 0.01), minf(j.armas.since, 9.0)]

func _mandar_roupa(para := 0) -> void:
	var inv = jogador.inventario
	var na_mao = inv.slots.get("maos")
	var d := {}
	for s in SLOTS_ROUPA:
		var it = inv.slots.get(s)
		d[s] = it.id if it != null and it != na_mao else ""     # arma que está na mão não aparece no corpo
	# OTIMIZAÇÃO: o inventário muda o tempo todo (balas, comida...); só manda quando a ROUPA mudou
	# (ou quando é para alguém específico, que acabou de chegar)
	if para == 0 and d == _roupa_enviada:
		return
	if para == 0:
		_roupa_enviada = d
	Rede.enviar_evento("roupa", d, para)

var _roupa_enviada := {}

func _mandar_tiro(arma: String) -> void:
	var cam: Camera3D = jogador.camera
	var cn = jogador.armas.cano()
	var de: Vector3 = cn.global_position if cn != null else jogador.global_position + Vector3(0, 1.4, 0)
	var para := cam.global_position - cam.global_basis.z * 80.0
	var silenciada: bool = jogador.armas.item_arma != null and jogador.armas.item_arma.acessorios.has("cano")
	Rede.enviar_evento("tiro", {"a": arma, "de": de, "para": para, "s": silenciada})

func _mandar_mundo(para := 0) -> void:
	if main.clima != null:
		Rede.enviar_evento("mundo", {"clima": main.clima.salvar()}, para)

# ---------- recebimento ----------
func _estado(id: int, d: Array) -> void:
	if not Rede.jogadores.has(id):
		return
	var r := _criar(id)
	r.visible = true
	r.receber_estado(d)

func _evento(id: int, tipo: String, d: Dictionary) -> void:
	match tipo:
		"cheguei":                             # quem chegou terminou de carregar: mostra a minha roupa (e o mundo)
			_mandar_roupa(id)
			if Rede.eh_host():
				_mandar_mundo(id)
		"roupa":
			if Rede.jogadores.has(id):
				_criar(id).vestir(d)
		"acao":
			if remotos.has(id):
				remotos[id].tocar_acao(str(d.get("n", "")), float(d.get("v", 1.0)), bool(d.get("c", true)))
		"tiro":
			_tiro_remoto(id, d)
		"mundo":
			_aplicar_mundo(d)

func _tiro_remoto(id: int, d: Dictionary) -> void:
	var r = remotos.get(id)
	var arma := str(d.get("a", ""))
	var W: Dictionary = jogador.armas.WDEF.get(arma, {})
	if r == null or W.is_empty():
		return
	var de: Vector3 = d.get("de", r.cano())
	var para: Vector3 = d.get("para", de)
	var dist := de.distance_to(jogador.global_position)
	if dist < DIST_SOM_TIRO:
		var silenciada := bool(d.get("s", false))
		var vol := -20.0 * log(maxf(1.0, dist / 6.0)) / log(10.0) - (12.0 if silenciada else 0.0)
		jogador.armas.sons.tocar("tiro_silenciado" if silenciada else "tiro_" + arma, vol)
		jogador.armas.efeitos.tracante(de, para, float(W.get("v", 400.0)), float(W.get("tl", 5.0)), 0, Vector3.UP)
	# os infectados DESTE aparelho também ouvem o tiro do outro
	if main.vagos != null:
		main.vagos.barulho(r.global_position, float(W.get("ruido", 30.0)) * (0.22 if d.get("s", false) else 1.0), false)

func _aplicar_mundo(d: Dictionary) -> void:
	if not Rede.eh_cliente() or main.clima == null or not d.has("clima"):
		return
	var c: Dictionary = d["clima"]
	var cl = main.clima
	if not _mundo_recebido:
		_mundo_recebido = true
		cl.carregar(c)                        # 1ª vez: copia tudo
	else:
		# depois: só corrige a hora se escapou e troca o tempo com a transição normal (sem pulo no céu)
		var dh := absf(angle_difference(float(c.get("hora", cl.hora)) * TAU / 24.0, cl.hora * TAU / 24.0)) * 24.0 / TAU
		if dh > 0.05:
			cl.definir_hora(float(c.get("hora", cl.hora)))
		cl.dia = int(c.get("dia", cl.dia))
		if str(c.get("estado", cl.estado)) != cl.estado:
			cl.forcar_tempo(str(c["estado"]))
	cl.set("_t_estado", 1.0e9)                # o tempo só muda quando o host mandar

var _mundo_recebido := false
