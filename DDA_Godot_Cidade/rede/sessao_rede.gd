extends Node
# SESSÃO DE REDE · liga o JOGO EM ANDAMENTO à partida multijogador (rede/rede.gd). Criada pelo main.gd dentro
# do nó "Jogo" quando a partida é em rede. Cada aparelho simula o SEU jogador e manda para os outros:
#   · ESTADO (15 vezes por segundo, pode perder pacote): posição, giro, velocidade, agachado/mirando/morto,
#     arma das mãos e mira  -> os outros mostram um rede/jogador_remoto.gd;
#   · EVENTOS (sempre chegam): "cheguei" (terminou de carregar: os outros respondem), "roupa" (o que está vestido), "acao" (recarregar, golpe, comer...),
#     "tiro" (som + traçante + os infectados de quem ouviu escutam), "mundo" (só o host: hora e clima).
# O HOST manda no mundo: a semente do loot (todo mundo acha as mesmas coisas nos mesmos lugares) e a hora/clima
# (os clientes não trocam o tempo sozinhos).
# MUNDO SINCRONIZADO (0.44):
#   · INFECTADOS: só o host cria e controla (nascem em volta de TODOS e caçam qualquer um). 10x/s ele manda a cada
#     amigo os que estão perto dele (Rede.enviar_infectados); o amigo mostra cópias (vago.gd "remoto").
#     "inf_ani" (ataque, levar golpe, morte) · "inf_dano" (tiro/golpe de um amigo -> host aplica) ·
#     "mordida" (infectado do host mordeu um amigo -> o aparelho dele leva o dano; 0.89: com o tipo do golpe),
#     "agarrado" (0.89: um infectado do host segurou o amigo: ele anda devagar um instante).
#   · ITENS NO CHÃO: cada um tem um uid (inventario/item_mundo.gd). "item_solto" = alguém largou (aparece para
#     todos) · "item_pego" = alguém pegou (some para todos). Os que nascem iguais em todo aparelho (chão dos
#     prédios, base) já têm uid fixo; os pegos ficam em loot_mundo.pegos e não voltam a aparecer.
#   · CAIXAS, MÓVEIS E PORTA-MALAS: quando o conteúdo muda aqui, "grade" manda o conteúdo novo para todos.
#   · Quem chega recebe do host "mundo_itens": as grades mexidas, os pegos e os itens largados.
#   · 0.72: o LOOT QUE VOLTA (mundo/loot_mundo.gd) segue a hora do host; quando uma grade é reabastecida aqui, o
#     conteúdo novo vai para todos ("grade") e eles não reabastecem de novo. O chão novo tem uid próprio por ciclo.
#   · 0.73: PORTAS (mundo/porta.gd): abrir, fechar, barricar, tirar tábua e quebrar vão para todos ("porta"); quem
#     chega recebe as portas mexidas junto com "mundo_itens".
#   · 0.90 BASE: "base_nova" (peças prontas), "base_tira" (desmontou/quebrou), "base_vida", "base_agua" (coletor);
#     quem chega recebe "base_tudo" do host. As peças vão no jogo salvo do host (mundo/construcao.gd).
#   · 0.91 TROCAS do Lucas (npc/trocas.gd): "troca_pedido" (amigo -> host), "troca_resp" (host -> quem pediu),
#     "trocas_lista" (host -> todos; quem chega recebe). HOSPITAL = zona neutra e TRÉGUA ao sair (npc/hospitais.gd):
#     o bit 256 do estado diz que o jogador está protegido (não fere e não é ferido).
# AINDA NÃO: dano entre jogadores, salvar a partida em rede, missões do rádio (cada um tem as suas), infectados
# não entram em prédio atrás de um amigo (o host não tem as paredes do interior onde o amigo está).
# Mexa AQUI para: o que vai em cada mensagem e de quanto em quanto tempo.

const RemotoCls := preload("res://rede/jogador_remoto.gd")
const ItemMundo := preload("res://inventario/item_mundo.gd")
const ItemCls := preload("res://inventario/item.gd")
const LootMundo := preload("res://mundo/loot_mundo.gd")
const Locais := preload("res://mundo/locais.gd")
const MensagensCls := preload("res://hud/mensagens.gd")
const PortaCls := preload("res://mundo/porta.gd")
const Hospitais := preload("res://npc/hospitais.gd")
const INFECTADOS_POR_SEG := 10.0
const RAIO_INFECTADOS := 170.0                # host manda a cada amigo os infectados até essa distância dele
const ENVIOS_POR_SEG := 15.0
const MUNDO_A_CADA := 5.0                     # host: hora/clima para todos (segundos)
const SLOTS_ROUPA := ["cabeca", "camisa", "colete", "cinto", "ombro", "coldre", "calca", "mochila"]
const DIST_SOM_TIRO := 450.0                  # mais longe que isso não se ouve o tiro do outro

var main: Node
var jogador: Node
var remotos := {}                             # id -> jogador_remoto.gd
var _t_envio := 0.0
var _t_mundo := 0.0
var _t_inf := 0.0
var _sig := {}                                # id da grade -> assinatura do conteúdo (o que todos já sabem)
var _mexidas := {}                            # grades que mudaram desde o sorteio (vão para quem chega)
var _cont_uid := 0
var _colisoes := {}                           # 0.74: host: id -> colisão que segue o amigo (mundo/colisao_mundo.gd)

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
	jogador.sobrevivencia.morreu.connect(_morri)
	# 0.71: mensagens rápidas (botão MSG / tecla T)
	_mensagens = MensagensCls.new()
	_mensagens.name = "Mensagens"
	_mensagens.controles = main.controles
	add_child(_mensagens)
	_mensagens.escolheu.connect(_mandar_mensagem)
	if main.controles != null:
		main.controles.ocultos["MSG"] = false
		main.controles.mensagem_pedida.connect(_mensagens.abrir)
	for id in Rede.jogadores:
		if id != Rede.meu_id():
			_criar(id)
	if Rede.eh_cliente():
		_aplicar_mundo(Rede.mundo)
	# "cheguei": os outros respondem com a roupa deles (e o host com o mundo). Antes disso este aparelho ainda
	# estava montando a cidade e não tinha sessão para receber nada.
	_ligar_mundo()
	Rede.enviar_evento("cheguei", {})
	_roupa_enviada = {}
	_mandar_roupa()

func _exit_tree() -> void:
	for s in [[Rede.estado_recebido, _estado], [Rede.evento_recebido, _evento], [Rede.jogador_entrou, _entrou], [Rede.jogador_saiu, _saiu],
			[Rede.infectados_recebidos, _infectados]]:
		if (s[0] as Signal).is_connected(s[1]):
			(s[0] as Signal).disconnect(s[1])
	if main != null and main.controles != null and is_instance_valid(main.controles):
		main.controles.ocultos["MSG"] = true
	ItemMundo.ao_soltar = Callable()
	ItemMundo.ao_pegar = Callable()
	ItemMundo.por_uid.clear()
	if main != null:
		for c in _colisoes.values():
			if main.mundo != null and is_instance_valid(main.mundo):
				main.mundo.remover_extra(c)
		_colisoes.clear()
		for n in ["interiores", "locais", "chunks"]:
			var o = main.get(n)
			if o != null and is_instance_valid(o):
				o.centros_extra = Callable()
	if main != null and main.loot_mundo != null:
		main.loot_mundo.grade_criada = Callable()
		main.loot_mundo.grade_reabastecida = Callable()
		main.loot_mundo.porta_mudou = Callable()
	if main != null and main.get("veiculos") != null and is_instance_valid(main.veiculos):
		main.veiculos.mudou = Callable()

# ---------- jogadores ----------
func _criar(id: int) -> Node3D:
	if remotos.has(id):
		return remotos[id]
	var r := RemotoCls.new()
	r.name = "Remoto_%d" % id
	r.id = id
	r.sessao = self
	r.nome = Rede.nome_de(id)
	main.jogo.add_child(r)
	r.definir_nome(r.nome)
	# 0.74: host: chão e prédios de física em volta do amigo (os infectados de lá andam com física)
	if Rede.eh_host() and main.mundo != null and main.mundo.has_method("criar_extra"):
		_colisoes[id] = main.mundo.criar_extra(r)
	r.visible = false                         # aparece no 1º estado (antes disso não se sabe onde está)
	remotos[id] = r
	return r

func _entrou(id: int, _nome: String) -> void:
	_criar(id)
	if main.hud != null:
		main.hud.mostrar_aviso("%s ENTROU NA PARTIDA" % Rede.nome_de(id).to_upper())

func _saiu(id: int) -> void:
	if _colisoes.has(id):
		main.mundo.remover_extra(_colisoes[id])
		_colisoes.erase(id)
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
	if _t_envio <= 0.0 and not Rede.servidor_dedicado:      # o servidor do PC não é jogador: não manda posição
		_t_envio = 1.0 / ENVIOS_POR_SEG
		Rede.enviar_estado(estado_local())
	if Rede.eh_host():
		_t_mundo -= dt
		if _t_mundo <= 0.0:
			_t_mundo = MUNDO_A_CADA
			_mandar_mundo()
		# infectados: a cada amigo, os que estão perto DELE (o aparelho dele mostra as cópias)
		_t_inf -= dt
		if _t_inf <= 0.0 and main.vagos != null:
			_t_inf = 1.0 / INFECTADOS_POR_SEG
			for id in remotos:
				var rm = remotos[id]
				if is_instance_valid(rm) and rm.visible:
					Rede.enviar_infectados(id, main.vagos.estado_rede(rm.global_position, RAIO_INFECTADOS))

# [pos, yaw, vel, bits, arma, aim, since, mira_pitch]  (o jogador_remoto.gd lê nesta ordem)
func estado_local() -> Array:
	var j = jogador
	var bits := (1 if j.agachado else 0) | (2 if j.mirando else 0) | (4 if j.morto else 0) | (0 if j.is_on_floor() else 8) \
		| (16 if j.mancando else 0) | (32 if j.nadando else 0) | (64 if j.afundando else 0) | (128 if j.veiculo != null else 0) \
		| (256 if _protegido() else 0)
	var carro: Array = ["", Vector3.ZERO]
	if j.veiculo != null and is_instance_valid(j.veiculo):
		carro = [str(j.veiculo.id), j.veiculo.rotation]     # 0.76: dirigindo: qual carro e como ele está virado
	return [j.global_position, j.rotation.y, j.velocity, bits, str(j.armas.atual), snappedf(j.armas.aim, 0.01), minf(j.armas.since, 9.0),
		snappedf(j.mira_pitch, 0.02), carro[0], carro[1]]

func _mandar_roupa(para := 0) -> void:
	if Rede.servidor_dedicado:
		return
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
				_mandar_mundo_itens(id)
				if main.get("construcao") != null:
					Rede.enviar_evento("base_tudo", {"l": main.construcao.estado()}, id)
				if main.get("hospitais") != null:
					main.hospitais.trocas.mandar_para(id)
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
		"inf_dano":
			_inf_dano(id, d)
		"inf_ani":
			if id == 1 and main.vagos != null:
				main.vagos.receber_ani_rede(int(d.get("i", 0)), str(d.get("a", "")), d.get("d", {}))
		"pvp":
			_pvp_recebido(id, d)
		"msg":
			_mostrar_mensagem(id, int(d.get("i", 0)))
		"abate":
			_abate(id, d)
		"mordida":
			if id == 1 and not jogador.morto:
				jogador.receber_ataque(float(d.get("d", 10.0)), float(d.get("c", 0.3)), d.get("o", jogador.global_position), str(d.get("t", "")))
				if main.vagos != null:
					main.vagos.atacou_jogador.emit(float(d.get("d", 10.0)))
					main.vagos._contar_golpe(str(d.get("o", "")))       # 0.89: puxar para o chão também no aparelho do amigo
		"agarrado":
			if id == 1 and not jogador.morto:
				jogador.agarrar(float(d.get("t", 0.9)))
		"item_solto":
			_item_solto(d)
		"item_pego":
			_item_pego(str(d.get("u", "")))
		"grade":
			_grade_recebida(d)
		"porta":
			_porta_recebida(str(d.get("i", "")), d.get("e", []))
		"veiculo":
			if main.get("veiculos") != null:
				if str(d.get("k", "")) == "entrou":
					main.veiculos.remoto_entrou(str(d.get("i", "")), id)
				else:
					main.veiculos.remoto_saiu(str(d.get("i", "")), d.get("e", {}))
		"mundo_itens":
			if id == 1:
				_aplicar_mundo_itens(d)
		"troca_pedido", "troca_resp", "trocas_lista":    # 0.91: trocas do Lucas (npc/trocas.gd)
			if main.get("hospitais") != null:
				main.hospitais.trocas.receber(id, tipo, d)
		"base_nova", "base_tira", "base_vida", "base_agua", "base_tudo":    # 0.90: construir base (mundo/construcao.gd)
			if main.get("construcao") != null and (tipo != "base_tudo" or id == 1):
				main.construcao.receber(tipo, d)

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
		# 0.49: som 3D na posição do amigo (vem do lado certo); de longe, a gravação "de longe" (abafada, com eco)
		jogador.armas.sons.tocar_em("tiro_silenciado" if silenciada else "tiro_" + arma, de, dist)
		jogador.armas.efeitos.tracante(de, para, float(W.get("v", 400.0)), float(W.get("tl", 5.0)), 0, Vector3.UP)
	# os infectados DESTE aparelho também ouvem o tiro do outro
	if main.vagos != null:
		main.vagos.barulho(r.global_position, float(W.get("ruido", 30.0)) * jogador.armas.MULT_RUIDO_TIRO * (0.22 if d.get("s", false) else 1.0), false)

func _aplicar_mundo(d: Dictionary) -> void:
	if not Rede.eh_cliente() or main.clima == null or not d.has("clima"):
		return
	var c: Dictionary = d["clima"]
	var cl = main.clima
	if not _mundo_recebido:
		_mundo_recebido = true
		cl.carregar(c)                        # 1ª vez: copia tudo
		if main.loot_mundo != null:
			main.loot_mundo.sincronizar_ciclos()   # 0.72: a hora pulou; o que já abriu aqui não "volta" por isso
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

# =====================================================================================================
# MUNDO SINCRONIZADO: infectados, itens no chão e caixas
# =====================================================================================================
func _ligar_mundo() -> void:
	Rede.infectados_recebidos.connect(_infectados)
	var v = main.vagos
	if v != null:
		v.sessao = self
		if Rede.eh_host():
			v.rede_host = true
		else:
			v.espelho = true                   # cliente: os infectados são do host
			v.limpar()
	# host: os chunks em volta de cada amigo também ficam "ativos" (não pausa os infectados perto dele)
	var perto_amigos := func() -> Array:
		var l := []
		for rm in remotos.values():
			if is_instance_valid(rm) and rm.visible:
				l.append(rm.global_position)
		return l
	if Rede.eh_host() and main.get("chunks") != null:
		main.chunks.centros_extra = perto_amigos
	# 0.74: host: prédios e locais perto dos amigos também abrem aqui (infectados presos lá dentro, paredes e portas)
	if Rede.eh_host():
		if main.get("interiores") != null:
			main.interiores.centros_extra = perto_amigos
		if main.get("locais") != null:
			main.locais.centros_extra = perto_amigos
	ItemMundo.ao_soltar = _item_solto_aqui
	ItemMundo.ao_pegar = _item_pego_aqui
	var lm = main.loot_mundo
	if lm != null:
		lm.grade_criada = func(gid: String, g) -> void: _sig[gid] = LootMundo.assinatura(g)
		lm.grade_reabastecida = func(gid: String, g) -> void:
			_sig[gid] = LootMundo.assinatura(g)
			_mexidas[gid] = true
			Rede.enviar_evento("grade", {"i": gid, "w": g.largura, "h": g.altura, "n": g.nome, "l": LootMundo.conteudo(g)})
		lm.porta_mudou = func(pid: String, e: Array) -> void: Rede.enviar_evento("porta", {"i": pid, "e": e})
	if main.get("veiculos") != null:
		main.veiculos.mudou = func(k: String, vid: String, e: Dictionary) -> void: Rede.enviar_evento("veiculo", {"k": k, "i": vid, "e": e})
		for gid in lm._grades:
			_sig[gid] = LootMundo.assinatura(lm._grades[gid])
			if Rede.eh_host():
				_mexidas[gid] = true             # 0.77: mundo salvo carregado: quem chegar recebe como está
		# caixas da base (mundo/loot.gd): entram na lista das grades com o nome "base_N"
		for c in get_tree().get_nodes_in_group("conteineres_mundo"):
			var cid := String(c.get("id_loot"))
			if cid.begins_with("base_") and c.grade != null:
				lm._grades[cid] = c.grade
				_sig[cid] = LootMundo.assinatura(c.grade)
	jogador.inventario.mudou.connect(_checar_grades)

# ---------- infectados ----------
func _infectados(d: PackedFloat32Array) -> void:
	if main.vagos != null and main.vagos.espelho:
		main.vagos.receber_estado_rede(d)

# host: avisa uma animação de um infectado a todos
func mandar_ani_infectado(id_inf: int, tipo_ani: String, d: Dictionary) -> void:
	Rede.enviar_evento("inf_ani", {"i": id_inf, "a": tipo_ani, "d": d})

# cliente: meu tiro/golpe acertou a cópia de um infectado -> o host aplica
func pedir_dano_infectado(id_inf: int, dano: float, forma: int, dir: Vector3, golpe: bool) -> void:
	Rede.enviar_evento("inf_dano", {"i": id_inf, "dn": dano, "f": forma, "d": dir, "g": golpe}, 1)

func _inf_dano(de: int, d: Dictionary) -> void:
	if not Rede.eh_host() or main.vagos == null:
		return
	var v = main.vagos.por_id.get(int(d.get("i", 0)))
	if v == null or not is_instance_valid(v):
		return
	var quem = remotos.get(de)
	var dir: Vector3 = d.get("d", Vector3.FORWARD)
	if int(d.get("f", 0)) == -1:
		v.empurrado(dir, quem)                        # 0.90: empurrão do amigo
	elif bool(d.get("g", false)):
		v.receber_golpe(float(d.get("dn", 0.0)), dir, quem)
	else:
		v.receber_tiro(float(d.get("dn", 0.0)), v.global_position, dir, int(d.get("f", 0)), quem)

# ---------- itens no chão ----------
# alguém largou um item AQUI: ganha um uid novo (deste aparelho) e aparece para todos
func _item_solto_aqui(n: Node3D) -> void:
	if not Rede.ligado:
		return
	var it = n.item
	_cont_uid += 1
	it.uid = "%d:%d" % [Rede.meu_id(), _cont_uid]
	Rede.enviar_evento("item_solto", {"u": it.uid, "it": it.para_dict(), "p": n.global_position})

# alguém pegou um item do chão AQUI: some para todos
func _item_pego_aqui(it) -> void:
	if not Rede.ligado:
		return
	if main.loot_mundo != null:
		main.loot_mundo.pegos[it.uid] = true
	Rede.enviar_evento("item_pego", {"u": it.uid})

func _item_solto(d: Dictionary) -> void:
	var u := str(d.get("u", ""))
	if u == "" or ItemMundo.por_uid.has(u):
		return
	var it = ItemCls.de_dict(d.get("it", {}))
	if it == null:
		return
	it.uid = u
	ItemMundo.soltar(main.jogo, it, d.get("p", Vector3.ZERO), false)
	jogador.inventario.mudou.emit()                # a coluna "chão" do inventário se atualiza

func _item_pego(u: String) -> void:
	if u == "":
		return
	if main.loot_mundo != null:
		main.loot_mundo.pegos[u] = true
	var n = ItemMundo.por_uid.get(u)
	ItemMundo.por_uid.erase(u)
	if n != null and is_instance_valid(n) and not n.is_queued_for_deletion():
		if n.item != null:
			n.item.no_mundo = null
		n.queue_free()
		jogador.inventario.mudou.emit()

# ---------- caixas, móveis e porta-malas ----------
# depois de qualquer mexida no inventário: alguma grade mudou? manda o conteúdo novo para todos
func _checar_grades() -> void:
	var lm = main.loot_mundo
	if lm == null or not Rede.ligado:
		return
	for gid in lm._grades:
		var g = lm._grades[gid]
		var s := LootMundo.assinatura(g)
		if not _sig.has(gid):
			_sig[gid] = s
		elif _sig[gid] != s:
			_sig[gid] = s
			_mexidas[gid] = true
			Rede.enviar_evento("grade", {"i": gid, "w": g.largura, "h": g.altura, "n": g.nome, "l": LootMundo.conteudo(g)})

func _grade_recebida(d: Dictionary) -> void:
	var lm = main.loot_mundo
	if lm == null:
		return
	var gid := str(d.get("i", ""))
	var g = lm.definir_conteudo(gid, int(d.get("w", 4)), int(d.get("h", 4)), str(d.get("n", "")), d.get("l", []))
	_sig[gid] = LootMundo.assinatura(g)
	_mexidas[gid] = true
	jogador.inventario.mudou.emit()                # se a caixa estiver aberta na tela, mostra o novo conteúdo

# host -> quem acabou de chegar: grades mexidas, itens que já foram pegos e itens largados no chão
func _mandar_mundo_itens(para: int) -> void:
	var lm = main.loot_mundo
	var gr := {}
	if lm != null:
		for gid in _mexidas:
			var g = lm._grades.get(gid)
			if g != null:
				gr[gid] = [g.largura, g.altura, g.nome, LootMundo.conteudo(g)]
	var soltos := []
	for u in ItemMundo.por_uid:
		var n = ItemMundo.por_uid[u]
		if n != null and is_instance_valid(n) and n.get_parent() == main.jogo and n.item != null:
			soltos.append([u, n.item.para_dict(), n.global_position])
	Rede.enviar_evento("mundo_itens", {"grades": gr, "pegos": lm.pegos.keys() if lm != null else [], "soltos": soltos,
		"portas": lm.portas if lm != null else {}, "veiculos": lm.veiculos if lm != null else {}}, para)

func _aplicar_mundo_itens(d: Dictionary) -> void:
	var lm = main.loot_mundo
	if lm != null:
		var gr: Dictionary = d.get("grades", {})
		for gid in gr:
			var e: Array = gr[gid]
			var g = lm.definir_conteudo(gid, int(e[0]), int(e[1]), str(e[2]), e[3])
			_sig[gid] = LootMundo.assinatura(g)
			_mexidas[gid] = true
	for u in d.get("pegos", []):
		_item_pego(str(u))
	var ps: Dictionary = d.get("portas", {})
	for pid in ps:
		_porta_recebida(str(pid), ps[pid])
	var vs: Dictionary = d.get("veiculos", {})
	if main.get("veiculos") != null:
		for vid in vs:
			main.veiculos.remoto_saiu(str(vid), vs[vid])
	for e in d.get("soltos", []):
		_item_solto({"u": e[0], "it": e[1], "p": e[2]})

# ---------- portas (0.73) ----------
# alguém mexeu numa porta: guarda (sem mandar de volta) e, se ela está montada aqui, mostra igual
func _porta_recebida(pid: String, e: Array) -> void:
	if pid == "" or e.size() < 3 or main.loot_mundo == null:
		return
	main.loot_mundo.portas[pid] = e
	var pt = PortaCls.todas.get(pid)
	if pt != null and is_instance_valid(pt):
		pt.aplicar(e)

# ---------- PvP (0.71) ----------
# Regra (escolha do HOST em Opções › Vídeo e som › "PvP no multijogador", vai em Rede.mundo["pvp"]):
#   "zonas" (padrão) = só vale dentro das ZONAS DE PvP (postos, supermercados, armazéns...: mundo/locais.gd)
#   "tudo" = na cidade inteira · "desligado" = ninguém fere ninguém
# 0.91: nos HOSPITAIS (zona neutra) nunca vale, e quem saiu de lá está na TRÉGUA (não fere nem é ferido) por 2 min.
# Quem decide é o aparelho de quem LEVA o tiro (pela posição dele): sem trapaça de quem atira.
const PVP_ZONA_MARGEM := 4.0
const ABATE_JANELA := 12.0                    # morreu até 12 s depois de levar tiro de alguém = abate dele
var _t_aviso_pvp := 0.0
var _ultimo_atirador := 0
var _t_ultimo_tiro := -100.0
var _ultima_arma := ""
var _ultima_cabeca := false

static func modo_pvp() -> String:
	return str(Rede.mundo.get("pvp", "zonas"))

static func pvp_vale_em(p: Vector3) -> bool:
	if Hospitais.zona(Vector2(p.x, p.z)) >= 0:
		return false                                  # 0.91: zona neutra
	match modo_pvp():
		"tudo":
			return true
		"desligado":
			return false
	var i := Locais.em(Vector2(p.x, p.z), PVP_ZONA_MARGEM)
	return i >= 0 and Locais.LOCAIS[i][0] != "hospital"

# 0.91: eu estou na zona neutra ou na trégua
func _protegido() -> bool:
	return main.get("hospitais") != null and main.hospitais.protegido()

# eu acertei o jogador "alvo_id": manda o dano para o aparelho dele (falso = o PvP não vale onde ele está)
func mandar_pvp(alvo_id: int, dano: float, cabeca: bool, direcao: Vector3, golpe: bool) -> bool:
	var r = remotos.get(alvo_id)
	if r != null and (_protegido() or r.protegido):          # 0.91: trégua do hospital
		var agora0 := Time.get_ticks_msec() / 1000.0
		if agora0 - _t_aviso_pvp > 4.0 and main.hud != null:
			_t_aviso_pvp = agora0
			main.hud.mostrar_aviso("TRÉGUA DO HOSPITAL: VOCÊ NÃO PODE FERIR NINGUÉM AINDA" if _protegido() else "%s ESTÁ NA TRÉGUA DO HOSPITAL: NÃO FERE" % r.nome.to_upper())
		return false
	if r == null or not pvp_vale_em(r.global_position):
		var agora := Time.get_ticks_msec() / 1000.0
		if agora - _t_aviso_pvp > 4.0 and main.hud != null:
			_t_aviso_pvp = agora
			main.hud.mostrar_aviso("PvP DESLIGADO AQUI" if modo_pvp() == "desligado" else "FORA DA ZONA DE PvP: NÃO FERE")
		return false
	Rede.enviar_evento("pvp", {"dn": dano, "c": cabeca, "d": direcao, "g": golpe, "a": str(jogador.armas.atual),
		"o": jogador.global_position}, alvo_id)
	return true

func _pvp_recebido(de: int, d: Dictionary) -> void:
	if jogador == null or jogador.morto or not pvp_vale_em(jogador.global_position):
		return
	if _protegido() or (remotos.has(de) and remotos[de].protegido):
		return                                        # 0.91: trégua (vale para os dois lados)
	_ultimo_atirador = de
	_t_ultimo_tiro = Time.get_ticks_msec() / 1000.0
	_ultima_arma = str(d.get("a", ""))
	_ultima_cabeca = bool(d.get("c", false))
	jogador.sobrevivencia.levar_tiro_pvp(float(d.get("dn", 0.0)), _ultima_cabeca, d.get("o", jogador.global_position),
		Rede.nome_de(de), bool(d.get("g", false)))

# morri: se foi tiro/golpe de alguém há pouco, avisa todo mundo (e ele ganha o abate)
func _morri(_causa: String) -> void:
	if Time.get_ticks_msec() / 1000.0 - _t_ultimo_tiro > ABATE_JANELA or _ultimo_atirador == 0:
		return
	var d := {"q": _ultimo_atirador, "a": _ultima_arma, "c": _ultima_cabeca}
	Rede.enviar_evento("abate", d)
	_abate(Rede.meu_id(), d)

func _abate(vitima: int, d: Dictionary) -> void:
	var quem := int(d.get("q", 0))
	var arma := str(d.get("a", ""))
	var nome_arma: String = jogador.armas.WDEF[arma]["nome"] if jogador.armas.WDEF.has(arma) else ""
	var txt := "%s MATOU %s%s%s" % [Rede.nome_de(quem).to_upper(), Rede.nome_de(vitima).to_upper(),
		(" · " + nome_arma) if nome_arma != "" else "", " · NA CABEÇA" if bool(d.get("c", false)) else ""]
	if quem == Rede.meu_id():
		txt = "VOCÊ MATOU %s%s" % [Rede.nome_de(vitima).to_upper(), " · NA CABEÇA" if bool(d.get("c", false)) else ""]
		main.abates += 1
	elif vitima == Rede.meu_id():
		txt = "%s MATOU VOCÊ" % Rede.nome_de(quem).to_upper()
	if main.hud != null:
		main.hud.mostrar_aviso(txt, 6.0)

# ---------- mensagens rápidas (0.71) ----------
var _mensagens
var _t_msg := 0.0

func _mandar_mensagem(i: int) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _t_msg < 1.5:
		return                                # sem metralhar mensagem
	_t_msg = agora
	Rede.enviar_evento("msg", {"i": i})
	_mostrar_mensagem(Rede.meu_id(), i)

func _mostrar_mensagem(de: int, i: int) -> void:
	if main.hud != null:
		main.hud.mostrar_aviso(MensagensCls.texto(Rede.nome_de(de), i), 6.0)
	preload("res://audio/sons.gd").tocar("ui/aviso", -6.0)
