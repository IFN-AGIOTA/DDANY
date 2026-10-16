extends Node
# REDE (autoload "Rede") · base do MULTIJOGADOR do MODO LIVRE, na mesma rede Wi-Fi (LAN) ou por IP.
# Um aparelho CRIA a partida (é o "host": manda na hora, no clima e na semente do loot) e os outros ENTRAM.
# Usa o multijogador de alto nível da Godot (ENet + RPC). O host repassa as mensagens entre os clientes.
#
#   Rede.criar_partida("Nome")          -> abre a partida (porta PORTA) e anuncia na rede local
#   Rede.procurar(true)                 -> escuta os anúncios; sinal partida_achada(ip, nome, jogadores)
#   Rede.entrar("192.168.0.10", "Nome") -> conecta; quando o host aceita: sinal pronto
#   Rede.sair()                         -> fecha tudo (volta ao jogo sozinho)
#
# O que passa pela rede está em rede/sessao_rede.gd (estado dos jogadores, tiros, ações, roupa, clima).
# Mexa AQUI para: porta, limite de jogadores, versão do protocolo, anúncio na rede local.

signal pronto                                  # conectado e aceito (no host: assim que cria a partida)
signal falhou(motivo: String)                  # não deu para criar/entrar
signal caiu(motivo: String)                    # a partida acabou (host saiu, conexão perdida, expulso)
signal jogador_entrou(id: int, nome: String)
signal jogador_saiu(id: int)
signal partida_achada(ip: String, nome: String, jogadores: int)
signal estado_recebido(id: int, d: Array)      # posição/animação de um jogador (sessao_rede.gd)
signal evento_recebido(id: int, tipo: String, d: Dictionary)   # tiro, ação, roupa, mundo... (sessao_rede.gd)

const PORTA := 24560                           # partida (UDP, ENet)
const PORTA_ANUNCIO := 24561                   # anúncio "tem partida aqui" na rede local (UDP broadcast)
const MAX_JOGADORES := 8
const PROTOCOLO := 1                           # aumente quando mudar o formato das mensagens
const ANUNCIO_A_CADA := 1.0                    # segundos

var ligado := false                            # tem partida aberta/conectada (e aceita)
var nome := "Sobrevivente"
var jogadores := {}                            # id -> {"nome": String}  (inclui o próprio)
var mundo := {}                                # o que o host mandou ao aceitar: {"semente": int, "clima": {...}}

var _anuncio: PacketPeerUDP = null             # host: manda o anúncio
var _escuta: PacketPeerUDP = null              # menu: escuta anúncios
var _t_anuncio := 0.0
var _host_nome := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # a rede continua com o jogo pausado
	multiplayer.peer_connected.connect(_peer_conectou)
	multiplayer.peer_disconnected.connect(_peer_saiu)
	multiplayer.connected_to_server.connect(_conectou_no_host)
	multiplayer.connection_failed.connect(func(): _falhar("Não deu para conectar (confira o IP e a rede Wi-Fi)."))
	multiplayer.server_disconnected.connect(func(): _encerrar("A partida acabou (o host saiu ou a conexão caiu)."))

func eh_host() -> bool:
	return ligado and multiplayer.is_server()

func eh_cliente() -> bool:
	return ligado and not multiplayer.is_server()

func meu_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

func nome_de(id: int) -> String:
	return str(jogadores.get(id, {}).get("nome", "Jogador %d" % id))

# ---------- criar / entrar / sair ----------
func criar_partida(meu_nome: String, semente_loot: int) -> void:
	sair()
	nome = _limpar_nome(meu_nome)
	var p := ENetMultiplayerPeer.new()
	var e := p.create_server(PORTA, MAX_JOGADORES - 1)
	if e != OK:
		_falhar("Não deu para abrir a partida (porta %d ocupada?)." % PORTA)
		return
	multiplayer.multiplayer_peer = p
	ligado = true
	_host_nome = nome
	jogadores = {1: {"nome": nome}}
	mundo = {"semente": semente_loot}
	_anuncio = PacketPeerUDP.new()
	_anuncio.set_broadcast_enabled(true)
	_anuncio.set_dest_address("255.255.255.255", PORTA_ANUNCIO)
	pronto.emit()

func entrar(ip: String, meu_nome: String) -> void:
	sair()
	nome = _limpar_nome(meu_nome)
	ip = ip.strip_edges()
	if not ip.is_valid_ip_address():
		_falhar("IP inválido: \"%s\"." % ip)
		return
	var p := ENetMultiplayerPeer.new()
	var e := p.create_client(ip, PORTA)
	if e != OK:
		_falhar("Não deu para conectar em %s." % ip)
		return
	multiplayer.multiplayer_peer = p           # "ligado" só quando o host aceitar (_aceito)

func sair() -> void:
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	ligado = false
	jogadores = {}
	mundo = {}
	if _anuncio != null:
		_anuncio.close()
		_anuncio = null

# endereços IPv4 deste aparelho na rede local (para o host dizer aos amigos)
func meus_ips() -> PackedStringArray:
	var r := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			r.append(a)
	return r

# ---------- procurar partidas na rede local ----------
func procurar(ligar: bool) -> void:
	if _escuta != null:
		_escuta.close()
		_escuta = null
	if not ligar:
		return
	_escuta = PacketPeerUDP.new()
	if _escuta.bind(PORTA_ANUNCIO) != OK:
		_escuta = null

func _process(dt: float) -> void:
	if _anuncio != null and eh_host():
		_t_anuncio -= dt
		if _t_anuncio <= 0.0:
			_t_anuncio = ANUNCIO_A_CADA
			var msg := JSON.stringify({"jogo": "DDA", "p": PROTOCOLO, "v": Config.VERSAO, "nome": _host_nome, "n": jogadores.size()})
			_anuncio.put_packet(msg.to_utf8_buffer())
	if _escuta != null:
		while _escuta.get_available_packet_count() > 0:
			var pk := _escuta.get_packet()
			var ip := _escuta.get_packet_ip()
			var d = JSON.parse_string(pk.get_string_from_utf8())
			if d is Dictionary and d.get("jogo") == "DDA" and int(d.get("p", 0)) == PROTOCOLO:
				partida_achada.emit(ip, str(d.get("nome", "?")), int(d.get("n", 1)))

# ---------- entrada na partida (aperto de mão) ----------
func _conectou_no_host() -> void:
	_ola.rpc_id(1, nome, PROTOCOLO, Config.VERSAO)

@rpc("any_peer", "call_remote", "reliable")
func _ola(n: String, protocolo: int, versao: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if protocolo != PROTOCOLO or versao != Config.VERSAO:
		_recusado.rpc_id(id, "Versão diferente: o host está na %s." % Config.VERSAO)
		_derrubar_depois(id)
		return
	var nm := _limpar_nome(n)
	jogadores[id] = {"nome": nm}
	var cl = _clima_atual()
	if cl != null:
		mundo["clima"] = cl
	_aceito.rpc_id(id, jogadores, mundo)
	_entrou.rpc(id, nm)                        # avisa todo mundo (inclusive quem entrou)
	jogador_entrou.emit(id, nm)

@rpc("authority", "call_remote", "reliable")
func _aceito(lista: Dictionary, dados_mundo: Dictionary) -> void:
	jogadores = lista
	mundo = dados_mundo
	ligado = true
	pronto.emit()

@rpc("authority", "call_remote", "reliable")
func _recusado(motivo: String) -> void:
	_falhar(motivo)

@rpc("authority", "call_remote", "reliable")
func _entrou(id: int, nm: String) -> void:
	if id == meu_id():
		return
	jogadores[id] = {"nome": nm}
	jogador_entrou.emit(id, nm)

func _peer_conectou(_id: int) -> void:
	pass                                       # só vale depois do _ola

func _peer_saiu(id: int) -> void:
	if jogadores.erase(id):
		jogador_saiu.emit(id)

func _derrubar_depois(id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)

# ---------- mensagens do jogo (rede/sessao_rede.gd) ----------
# estado: chega rápido e pode perder pacote (o próximo corrige)
func enviar_estado(d: Array) -> void:
	if ligado:
		_estado.rpc(d)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _estado(d: Array) -> void:
	estado_recebido.emit(multiplayer.get_remote_sender_id(), d)

# evento: chega sempre e na ordem (tiro, ação, roupa, clima...). para = 0: todos
func enviar_evento(tipo: String, d: Dictionary, para := 0) -> void:
	if not ligado:
		return
	if para == 0:
		_evento.rpc(tipo, d)
	else:
		_evento.rpc_id(para, tipo, d)

@rpc("any_peer", "call_remote", "reliable", 2)
func _evento(tipo: String, d: Dictionary) -> void:
	var de := multiplayer.get_remote_sender_id()
	if tipo == "mundo" and de != 1:
		return                                 # só o host manda no mundo
	evento_recebido.emit(de, tipo, d)

# ---------- ajudantes ----------
func _clima_atual():
	var m = get_tree().current_scene
	var cl = m.get("clima") if m != null else null
	return cl.salvar() if cl != null and is_instance_valid(cl) else null

func _limpar_nome(n: String) -> String:
	n = n.strip_edges().replace("\n", " ")
	if n == "":
		n = "Sobrevivente"
	return n.left(16)

func _falhar(motivo: String) -> void:
	sair()
	falhou.emit(motivo)

func _encerrar(motivo: String) -> void:
	var estava := ligado
	sair()
	if estava:
		caiu.emit(motivo)
	else:
		falhou.emit(motivo)
