extends Node
# REDE (autoload "Rede") · base do MULTIJOGADOR do MODO LIVRE: mesmo Wi-Fi, IP, CÓDIGO/CONVITE ou pela INTERNET.
# Um aparelho CRIA a partida (é o "host": manda na hora, no clima e na semente do loot) e os outros ENTRAM.
# Usa o multijogador de alto nível da Godot (ENet + RPC). O host repassa as mensagens entre os clientes.
#
#   Rede.criar_partida("Nome")          -> abre a partida (porta PORTA) e anuncia na rede local
#   Rede.procurar(true)                 -> escuta os anúncios; sinal partida_achada(ip, nome, jogadores)
#   Rede.entrar("192.168.0.10", "Nome") -> conecta; quando o host aceita: sinal pronto. Aceita também
#                                          "IP:porta", "endereco.com:porta" (túnel, ex.: playit.gg),
#                                          o CÓDIGO ("K7G2Q-0M4XA") ou a mensagem de convite colada inteira
#   Rede.sair()                         -> fecha tudo (volta ao jogo sozinho)
# DE LONGE (internet): ao criar a partida o host pede ao roteador para abrir a porta (UPnP) e descobre o IP
# da internet -> sinal internet(ok, ip, motivo). Os CÓDIGOS (codigos()) e o CONVITE (convite()) juntam
# IP + porta em 10 letras para mandar no WhatsApp. Se o roteador não deixar (ou internet do celular/4G, que
# quase nunca deixa), use uma VPN gratuita nos dois aparelhos (Tailscale ou ZeroTier): o código "VPN" funciona.
#
# PELA INTERNET COM A CONTA (0.33): o host aceita também conexões WEBRTC (rede/rtc.gd + rede/peer_misto.gd):
# o amigo toca na "Partida de Fulano" e Rede.entrar_amigo(uid) conecta direto, sem abrir porta nem VPN.
#
# 0.85 · PELA INTERNET SEM WebRTC (rede/turn.gd + rede/ponte_turn.gd): o host ganha um endereço público num
# RETRANSMISSOR (TURN, rede/turn.cfg) e o amigo conecta o ENet normal nele (entrar_amigo(uid, nome, true)).
#
# SERVIDOR DEDICADO (0.50, rede/servidor.gd): o PC abre a partida SEM ser jogador (servidor_dedicado = true):
# não entra na lista de jogadores, não manda posição/roupa e a partida já começa aberta (quem entra vai direto
# para a cidade). Os celulares entram pelo IP do PC (mesmo Wi-Fi, porta aberta no roteador ou Tailscale).
#
# O que passa pela rede está em rede/sessao_rede.gd (estado dos jogadores, tiros, ações, roupa, clima).
# Mexa AQUI para: porta, limite de jogadores, versão do protocolo, anúncio na rede local.

signal pronto                                  # conectado e aceito (no host: assim que cria a partida)
signal falhou(motivo: String)                  # não deu para criar/entrar
signal caiu(motivo: String)                    # a partida acabou (host saiu, conexão perdida, expulso)
signal jogador_entrou(id: int, nome: String)
signal jogador_saiu(id: int)
signal partida_achada(ip: String, nome: String, jogadores: int)
signal internet(ok: bool, ip: String, motivo: String)    # resultado do UPnP (só no host)
signal estado_recebido(id: int, d: Array)      # posição/animação de um jogador (sessao_rede.gd)
signal comecou                                 # o host tocou em COMEÇAR (a sala vira partida)
signal evento_recebido(id: int, tipo: String, d: Dictionary)   # tiro, ação, roupa, mundo... (sessao_rede.gd)
signal infectados_recebidos(d: PackedFloat32Array)             # cliente: posição dos infectados que o host manda
signal voz_recebida(id: int, d: PackedByteArray)                # 0.97: pedaço de voz de um jogador (rede/voz.gd)

const PORTA := 24560                           # partida (UDP, ENet)
const PORTA_ANUNCIO := 24561                   # anúncio "tem partida aqui" na rede local (UDP broadcast)
const MAX_JOGADORES := 10                      # no máximo 10 na sala (host + 9)
const PROTOCOLO := 3                           # aumente quando mudar o formato das mensagens (3: mundo sincronizado)
const ANUNCIO_A_CADA := 1.0                    # segundos

var ligado := false                            # tem partida aberta/conectada (e aceita)
var endereco_tunel := ""                       # servidor do PC: endereço público de um túnel UDP (playit.gg), 0.55
var servidor_dedicado := false                 # este aparelho é o SERVIDOR do PC (rede/servidor.gd): não é jogador
var nome := "Sobrevivente"
var jogadores := {}                            # id -> {"nome": String}  (inclui o próprio)
var mundo := {}                                # o que o host mandou ao aceitar: {"semente": int, "clima": {...}, "comecou": bool}
var partida_comecou := false                   # false = ainda na SALA (esperando o host começar)

var _anuncio: PacketPeerUDP = null             # host: manda o anúncio
var _escuta: PacketPeerUDP = null              # menu: escuta anúncios
var _t_anuncio := 0.0
var _host_nome := ""
var ip_internet := ""                          # host: IP da internet com a porta aberta pelo UPnP ("" = não)
var internet_motivo := ""                      # host: por que não abriu (ou "abrindo…")
var _upnp: UPNP = null
var _thread: Thread = null
const ALFABETO := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # base 32 sem I, L, O, U (não confunde ao digitar)
const RtcCls := preload("res://rede/rtc.gd")
const TurnCls := preload("res://rede/turn.gd")
const PonteCls := preload("res://rede/ponte_turn.gd")
var ponte: Node = null                         # 0.85: host: ponte pelo retransmissor (rede/ponte_turn.gd)
var _turn_sessao := ""                         # 0.85: amigo: pedido de entrada pelo retransmissor em andamento
const PeerMistoCls := preload("res://rede/peer_misto.gd")
var rtc: Node                                  # rede/rtc.gd (WebRTC pela internet)
var _com_rtc := false                          # host: aceita amigos pelo WebRTC

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # a rede continua com o jogo pausado
	rtc = RtcCls.new()
	rtc.name = "Rtc"
	add_child(rtc)
	rtc.cliente_falhou.connect(_falhar)
	multiplayer.peer_connected.connect(_peer_conectou)
	multiplayer.peer_disconnected.connect(_peer_saiu)
	multiplayer.connected_to_server.connect(_conectou_no_host)
	multiplayer.connection_failed.connect(func():
		if not _tentando_direto:
			_falhar("Não deu para conectar (confira o IP e a rede Wi-Fi)."))
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
	# 0.86 · LIGAÇÃO DIRETA: antes de abrir o ENet, descobre o endereço público da PORTA do jogo (STUN); o amigo
	# conecta direto nele (furando o NAT) e só usa o retransmissor se não der
	direto_publico = ""
	var cfg_t := TurnCls.config()
	if not cfg_t.is_empty():
		direto_publico = TurnCls.endereco_publico(cfg_t["stun"][0], int(cfg_t["stun"][1]), PORTA, 1.2)
		_stun = cfg_t["stun"]
		for res in cfg_t.get("reservas", []):     # 0.87: o retransmissor próprio não respondeu: pergunta à reserva
			if direto_publico != "":
				break
			direto_publico = TurnCls.endereco_publico(res["stun"][0], int(res["stun"][1]), PORTA, 1.2)
			_stun = res["stun"]
		print("REDE: endereço público da partida (ligação direta): ", direto_publico if direto_publico != "" else "não achei")
	var p := ENetMultiplayerPeer.new()
	var e := p.create_server(PORTA, MAX_JOGADORES - 1)
	if e != OK:
		_falhar("Não deu para abrir a partida (porta %d ocupada?)." % PORTA)
		return
	_enet = p
	_iniciar_ponte()                            # 0.85: internet pelo retransmissor (sem WebRTC)
	_com_rtc = RtcCls.disponivel() and (not servidor_dedicado or Conta.logado)   # servidor do PC: com a conta de convidado (0.51)
	if _com_rtc:
		multiplayer.multiplayer_peer = PeerMistoCls.new(p, rtc.comecar_host())   # Wi-Fi/código + internet (WebRTC)
	else:
		multiplayer.multiplayer_peer = p
	ligado = true
	_host_nome = nome
	jogadores = {} if servidor_dedicado else {1: {"nome": nome, "avatar": Conta.avatar, "uid": Conta.uid}}
	mundo = {"semente": semente_loot, "comecou": servidor_dedicado, "pvp": str(Config.valor("pvp"))}   # 0.71: regra do PvP
	partida_comecou = servidor_dedicado         # servidor: a partida já começa aberta (entra direto na cidade)
	_anuncio = PacketPeerUDP.new()
	_anuncio.set_broadcast_enabled(true)
	_anuncio.set_dest_address("255.255.255.255", PORTA_ANUNCIO)
	_abrir_porta_internet()
	pronto.emit()

func entrar(endereco: String, meu_nome: String) -> void:
	sair()
	nome = _limpar_nome(meu_nome)
	var alvo := resolver_endereco(endereco)
	if alvo.is_empty():
		_falhar("Não entendi \"%s\": use o código (ex.: K7G2Q-0M4XA), um IP ou endereço:porta." % endereco.strip_edges().left(40))
		return
	var p := ENetMultiplayerPeer.new()
	var e := p.create_client(alvo[0], int(alvo[1]))
	if e != OK:
		_falhar("Não deu para conectar em %s:%d." % [alvo[0], alvo[1]])
		return
	multiplayer.multiplayer_peer = p           # "ligado" só quando o host aceitar (_aceito)

# entra na partida de um AMIGO da conta pela internet: 0.85 pelo RETRANSMISSOR (por_turn, quando o host aceita)
# ou, se não, pelo WebRTC (rede/rtc.gd)
func entrar_amigo(host_uid: String, meu_nome: String, por_turn := false) -> void:
	sair()
	nome = _limpar_nome(meu_nome)
	if not Conta.logado:
		_falhar("Entre na sua conta para jogar com amigos pela internet.")
		return
	if por_turn and not TurnCls.config().is_empty():
		_entrar_por_turn(host_uid)
		return
	if not RtcCls.disponivel():
		_falhar("Este aparelho não tem a conexão pela internet (WebRTC).")
		return
	multiplayer.multiplayer_peer = rtc.conectar(host_uid)   # "ligado" só quando o host aceitar (_aceito)

# ---------- 0.86 · LIGAÇÃO DIRETA (furar o NAT, como o Radmin/Tailscale fazem por dentro) ----------
# HOST: o roteador só deixa entrar resposta de quem a porta do jogo já "chamou". Então, quando o amigo pede para
# entrar, o host manda alguns pacotes para o endereço público dele (ENetConnection.socket_send, da porta do ENet)
# enquanto o amigo tenta conectar: os dois roteadores abrem o caminho e a ligação fica direta, sem retransmissor.
# A cada MANTER s o host manda um pedido STUN da mesma porta: o roteador não esquece o endereço público.
# Não funciona com NAT "simétrico" (alguns 4G): aí o amigo cai no retransmissor sozinho.
const MANTER := 15.0
const FURAR_POR := 8.0                         # s mandando pacotes para o amigo
const TENTAR_DIRETO := 6.0                     # s que o amigo tenta a ligação direta antes do retransmissor
signal sincronizando(texto: String)            # amigo: o que está acontecendo (a tela mostra)
var _enet: ENetMultiplayerPeer = null          # host: o ENet do jogo (o soquete dele fura o NAT)
var direto_publico := ""                       # host: "ip:porta" público da porta do jogo ("" = não achou)
var _stun: Array = []
var _stun_ip := ""
var _t_manter := 0.0
var _furos: Array = []                         # [[ip, porta, tempo restante], ...]
var via := ""                                  # amigo: "direta" ou "retransmissor" (a tela mostra)
var _tentando_direto := false                  # amigo: falha da tentativa direta não é falha da entrada

func _manter_nat(dt: float) -> void:
	if _enet == null or not eh_host() or _enet.host == null:
		return
	if direto_publico != "" and not _stun.is_empty():
		_t_manter -= dt
		if _t_manter <= 0.0:
			_t_manter = MANTER
			if _stun_ip == "":
				_stun_ip = _stun[0] if String(_stun[0]).is_valid_ip_address() else IP.resolve_hostname(_stun[0], IP.TYPE_IPV4)
			if _stun_ip != "":
				_enet.host.socket_send(_stun_ip, int(_stun[1]), TurnCls.pedido_binding())
	for f in _furos.duplicate():
		f[2] -= dt
		if f[2] <= 0.0:
			_furos.erase(f)
			continue
		_enet.host.socket_send(f[0], f[1], PackedByteArray([0x44, 0x44, 0x41, 0x21]))   # "DDA!" (o ENet do amigo ignora)

# host: um amigo (IP e porta da internet dele) pediu para entrar. Libera no retransmissor, começa a furar o NAT e
# devolve a resposta para ele: {"relay": endereço no retransmissor, "direto": endereço público da partida}
func atender_amigo(ip: String, porta: int) -> Dictionary:
	if ponte != null:
		ponte.permitir(ip)
	if direto_publico != "" and porta > 0 and ip.is_valid_ip_address():
		_furos.append([ip, porta, FURAR_POR])
	return {"relay": String(ponte.endereco) if ponte != null else "", "direto": direto_publico}

# amigo: tenta DIRETO no host por TENTAR_DIRETO s (da mesma porta do pedido); se não der, vai pelo retransmissor
func entrar_direto_ou_relay(direto: String, relay: String, porta_local: int) -> void:
	via = ""
	if direto.contains(":"):
		sincronizando.emit("Ligação direta com o host…")
		var p := ENetMultiplayerPeer.new()
		var dp := direto.split(":")
		if p.create_client(dp[0], int(dp[1]), 0, 0, 0, porta_local) == OK:
			# o peer já vai para o multijogador (ele precisa ver o host "conectar" para o aperto de mão funcionar)
			_tentando_direto = true
			multiplayer.multiplayer_peer = p
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < int(TENTAR_DIRETO * 1000.0) and multiplayer.multiplayer_peer == p:
				if p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
					_tentando_direto = false
					via = "direta"
					print("REDE: LIGAÇÃO DIRETA com o host ", direto)
					sincronizando.emit("Conectado: ligação direta (sem retransmissor).")
					return
				await get_tree().process_frame
			_tentando_direto = false
			if multiplayer.multiplayer_peer != p:
				return                                  # saiu/cancelou no meio
			multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
			p.close()
			await get_tree().create_timer(0.2).timeout   # solta a porta local
	if relay.contains(":"):
		via = "retransmissor"
		print("REDE: entrando pelo retransmissor ", relay)
		sincronizando.emit("Conectando pelo retransmissor…")
		entrar_relay(relay, porta_local)
		return
	_falhar("Não deu para ligar direto com o host e ele não tem retransmissor.")

# 0.85: conecta o ENet no endereço público do host no retransmissor ("ip:porta"), da porta local do pedido
func entrar_relay(relay: String, porta_local: int) -> void:
	var rp := relay.split(":")
	var p := ENetMultiplayerPeer.new()
	var e := p.create_client(rp[0], int(rp[1]), 0, 0, 0, porta_local)
	if e != OK:
		_falhar("Não deu para conectar no retransmissor (%d)." % e)
		return
	multiplayer.multiplayer_peer = p           # "ligado" só quando o host aceitar (_aceito)

# o host aceita amigos pela internet (WebRTC ou, 0.85, retransmissor)?
func aceita_rtc() -> bool:
	return eh_host() and (_com_rtc or aceita_turn())

# 0.85: o host já tem o endereço público no retransmissor?
func aceita_turn() -> bool:
	return eh_host() and ponte != null and String(ponte.get("endereco")) != ""

func _iniciar_ponte() -> void:
	if ponte != null:
		ponte.parar()
		ponte.queue_free()
		ponte = null
	var cfg := TurnCls.config()
	if cfg.is_empty():
		return
	ponte = PonteCls.new()
	ponte.name = "PonteTurn"
	ponte.aceita_qualquer = servidor_dedicado
	add_child(ponte)
	ponte.pronto.connect(func(end: String):
		print("PONTE: endereço público no retransmissor ", end)
		if Conta.logado:
			Conta.publicar_partida() if not servidor_dedicado else Conta.publicar_servidor())
	ponte.falhou.connect(func(m: String): push_warning("PONTE: " + m))
	ponte.iniciar(PORTA, cfg)

# 0.85 · AMIGO: entra pelo retransmissor do host (o ENet normal, no endereço público dele)
#   1. descobre o próprio IP da internet (STUN) com a porta que o ENet vai usar
#   2. pede para entrar (sinal/{host}/{eu}/c = {modo turn, sessao, ip}) e espera a resposta (h.relay)
#   3. conecta o ENet nesse endereço, da mesma porta
func _entrar_por_turn(host_uid: String) -> void:
	var cfg := TurnCls.config()
	var sessao := str(randi()) + str(Time.get_ticks_usec())
	_turn_sessao = sessao
	var porta_local := randi_range(40000, 60999)
	sincronizando.emit("Descobrindo o seu endereço na internet…")
	var meu: String = await TurnCls.endereco_publico_async(self, cfg["stun"][0], int(cfg["stun"][1]), porta_local)
	for res in cfg.get("reservas", []):           # 0.87: o retransmissor próprio não respondeu: pergunta à reserva
		if meu != "" or sessao != _turn_sessao:
			break
		meu = await TurnCls.endereco_publico_async(self, res["stun"][0], int(res["stun"][1]), porta_local)
	var ip := meu.get_slice(":", 0)
	if sessao != _turn_sessao:
		return
	if ip == "":
		_turn_sessao = ""
		_falhar("Não deu para falar com o retransmissor (esta rede bloqueia UDP?).")
		return
	var caminho := "sinal/%s/%s" % [host_uid, Conta.uid]
	sincronizando.emit("Sincronizando com o host…")
	if not await Conta.db_put(caminho + "/c", {"modo": "turn", "sessao": sessao, "ip": ip, "porta": int(meu.get_slice(":", 1)), "t": {".sv": "timestamp"}}):
		if sessao == _turn_sessao:
			_turn_sessao = ""
			_falhar("Não deu para chamar o host (sem internet?).")
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		await get_tree().create_timer(1.2).timeout
		if sessao != _turn_sessao:
			return
		var h = await Conta.db_get(caminho + "/h")
		if sessao != _turn_sessao:
			return
		if h is Dictionary and str(h.get("sessao", "")) == sessao and str(h.get("relay", "")).contains(":"):
			Conta.db_del(caminho + "/c")
			_turn_sessao = ""
			entrar_direto_ou_relay(str(h.get("direto", "")), str(h["relay"]), porta_local)
			return
	Conta.db_del(caminho + "/c")
	_turn_sessao = ""
	_falhar("O host não respondeu pela internet (está na sala? na mesma versão?).")

func sair() -> void:
	_enet = null
	_furos.clear()
	if rtc != null:
		rtc.parar()
	_com_rtc = false
	_turn_sessao = ""                          # cancela um pedido de entrada pelo retransmissor
	if ponte != null:
		ponte.parar()
		ponte.queue_free()
		ponte = null
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	ligado = false
	partida_comecou = false
	jogadores = {}
	mundo = {}
	if _anuncio != null:
		_anuncio.close()
		_anuncio = null
	_fechar_porta_internet()

# endereços IPv4 deste aparelho na rede local (para o host dizer aos amigos)
func meus_ips() -> PackedStringArray:
	var r := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			r.append(a)
	return r

# ---------- internet: abrir a porta no roteador (UPnP), numa thread (a busca demora ~2 s) ----------
func _abrir_porta_internet() -> void:
	ip_internet = ""
	internet_motivo = "abrindo a porta no roteador…"
	_esperar_thread()
	_thread = Thread.new()
	_thread.start(_upnp_abrir)

func _upnp_abrir() -> void:
	var u := UPNP.new()
	var r := u.discover(2000, 2, "InternetGatewayDevice")
	var ok := false
	var ip := ""
	var motivo := ""
	if r != UPNP.UPNP_RESULT_SUCCESS or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
		motivo = "o roteador não respondeu (UPnP desligado, ou internet do celular/4G)"
	elif u.add_port_mapping(PORTA, PORTA, "Dias de um Apocalipse", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		motivo = "o roteador recusou abrir a porta %d" % PORTA
	else:
		ip = u.query_external_address()
		if ip == "" or not ip.is_valid_ip_address():
			motivo = "porta aberta, mas o roteador não disse o IP da internet"
		elif _ip_interno(ip):
			motivo = "a operadora divide o IP (CGNAT: %s): de fora não chega" % ip
			u.delete_port_mapping(PORTA, "UDP")
			ip = ""
		else:
			ok = true
	_upnp_fim.call_deferred(ok, ip, motivo, u if ok else null)

func _upnp_fim(ok: bool, ip: String, motivo: String, u: UPNP) -> void:
	_esperar_thread()
	if not eh_host():                          # saiu enquanto abria: fecha de novo
		if u != null:
			_upnp = u
			_fechar_porta_internet()
		return
	_upnp = u
	ip_internet = ip
	internet_motivo = motivo
	internet.emit(ok, ip, motivo)

func _fechar_porta_internet() -> void:
	ip_internet = ""
	if _upnp == null:
		return
	var u := _upnp
	_upnp = null
	_esperar_thread()
	_thread = Thread.new()
	_thread.start(func(): u.delete_port_mapping(PORTA, "UDP"))

func _esperar_thread() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null

func _exit_tree() -> void:
	sair()
	_esperar_thread()

# ---------- códigos e convite ----------
# código = IPv4 (4 bytes) + porta (2 bytes) em base 32 -> "XXXXX-XXXXX"
static func codificar(ip: String, porta := PORTA) -> String:
	var p := ip.split(".")
	if p.size() != 4:
		return ""
	var n := 0
	for b in p:
		n = (n << 8) | (int(b) & 255)
	n = (n << 16) | (porta & 65535)
	var t := ""
	for i in 10:
		t = ALFABETO[n & 31] + t
		n >>= 5
	return t.left(5) + "-" + t.right(5)

static func decodificar(cod: String) -> Array:
	var t := cod.to_upper().replace("-", "").replace(" ", "").replace("O", "0").replace("I", "1").replace("L", "1")
	if t.length() != 10:
		return []
	var n := 0
	for ch in t:
		var k := ALFABETO.find(ch)
		if k < 0:
			return []
		n = (n << 5) | k
	var porta := n & 65535
	n >>= 16
	return ["%d.%d.%d.%d" % [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255], porta]

# entende código, convite colado, "ip", "ip:porta", "endereco:porta" -> [ip, porta] ([] = não entendeu)
func resolver_endereco(txt: String) -> Array:
	txt = txt.strip_edges()
	var re := RegEx.create_from_string("\\b([0-9A-Za-z]{5})-([0-9A-Za-z]{5})\\b")
	var m := re.search(txt)
	if m != null:
		var d := decodificar(m.get_string(1) + m.get_string(2))
		if not d.is_empty():
			return d
	if txt.length() == 10 and not "." in txt:   # código digitado sem o tracinho
		var d2 := decodificar(txt)
		if not d2.is_empty():
			return d2
	var host := txt
	var porta := PORTA
	var re2 := RegEx.create_from_string("^([A-Za-z0-9.\\-]+)(?::(\\d{1,5}))?$")
	var m2 := re2.search(txt)
	if m2 == null:
		return []
	host = m2.get_string(1)
	if m2.get_string(2) != "":
		porta = int(m2.get_string(2))
	if host.is_valid_ip_address():
		return [host, porta]
	if host.count(".") == 0 and host != "localhost":
		return []
	var ip := IP.resolve_hostname(host, IP.TYPE_IPV4)
	return [ip, porta] if ip != "" else []

# códigos desta partida, do que funciona de mais longe para o mais perto: [[tipo, código, ip], ...]
func codigos() -> Array:
	var r := []
	if endereco_tunel != "":                     # túnel (playit.gg): funciona de qualquer rede, inclusive 4G
		r.append(["Túnel", endereco_tunel, endereco_tunel])
	if ip_internet != "":
		r.append(["Internet", codificar(ip_internet), ip_internet])
	for ip in meus_ips():
		var tipo := "VPN (Tailscale/ZeroTier)" if _faixa(ip, "100.64.0.0", 10) or ip.begins_with("10.147.") or ip.begins_with("10.244.") else "Mesmo Wi-Fi"
		r.append([tipo, codificar(ip), ip])
	return r

func convite() -> String:
	var t := "Bora sobreviver em Nova York! Entre na minha partida de Dias de um Apocalipse (versão %s):\n" % Config.VERSAO
	for c in codigos():
		t += "%s: %s\n" % [c[0], c[1]]
	t += "No jogo: Multijogador > Entrar > cole esta mensagem ou digite o código."
	return t

static func _faixa(ip: String, base: String, bits: int) -> bool:
	var a := _num(ip)
	var b := _num(base)
	var m := (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF
	return a >= 0 and (a & m) == (b & m)

static func _num(ip: String) -> int:
	var p := ip.split(".")
	if p.size() != 4:
		return -1
	return (int(p[0]) << 24) | (int(p[1]) << 16) | (int(p[2]) << 8) | int(p[3])

static func _ip_interno(ip: String) -> bool:
	return _faixa(ip, "10.0.0.0", 8) or _faixa(ip, "172.16.0.0", 12) or _faixa(ip, "192.168.0.0", 16) or _faixa(ip, "100.64.0.0", 10)

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
	_manter_nat(dt)
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
var _ola_peer: Object = null                   # 0.86: o "olá" já foi para este peer (a ligação direta chama na mão)

func _conectou_no_host() -> void:
	if _ola_peer == multiplayer.multiplayer_peer:
		return
	_ola_peer = multiplayer.multiplayer_peer
	_ola.rpc_id(1, nome, PROTOCOLO, Config.VERSAO, Conta.avatar, Conta.uid)

# ---------- sala ----------
# host: a sala vira partida (todos vão para a cidade)
func comecar_partida() -> void:
	if not eh_host() or partida_comecou:
		return
	partida_comecou = true
	mundo["comecou"] = true
	_comecou.rpc()
	comecou.emit()

@rpc("authority", "call_remote", "reliable")
func _comecou() -> void:
	partida_comecou = true
	mundo["comecou"] = true
	comecou.emit()

# host: tira alguém da sala
func expulsar(id: int) -> void:
	if eh_host() and id != 1:
		_recusado.rpc_id(id, "O host tirou você da sala.")
		_derrubar_depois(id)

func avatar_de(id: int) -> int:
	return int(jogadores.get(id, {}).get("avatar", 0))

@rpc("any_peer", "call_remote", "reliable")
func _ola(n: String, protocolo: int, versao: String, av := 0, conta_uid := "") -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if protocolo != PROTOCOLO or versao != Config.VERSAO:
		_recusado.rpc_id(id, "Versão diferente: o host está na %s." % Config.VERSAO)
		_derrubar_depois(id)
		return
	if jogadores.size() >= MAX_JOGADORES:     # sala cheia (também vale para quem entra pela internet/WebRTC)
		_recusado.rpc_id(id, "A sala está cheia (%d/%d)." % [jogadores.size(), MAX_JOGADORES])
		_derrubar_depois(id)
		return
	var nm := _limpar_nome(n)
	jogadores[id] = {"nome": nm, "avatar": av, "uid": conta_uid}
	var cl = _clima_atual()
	if cl != null:
		mundo["clima"] = cl
	_aceito.rpc_id(id, jogadores, mundo)
	_entrou.rpc(id, nm, av, conta_uid)         # avisa todo mundo (inclusive quem entrou)
	jogador_entrou.emit(id, nm)

@rpc("authority", "call_remote", "reliable")
func _aceito(lista: Dictionary, dados_mundo: Dictionary) -> void:
	jogadores = lista
	mundo = dados_mundo
	partida_comecou = bool(mundo.get("comecou", true))
	ligado = true
	pronto.emit()

@rpc("authority", "call_remote", "reliable")
func _recusado(motivo: String) -> void:
	_falhar(motivo)

@rpc("authority", "call_remote", "reliable")
func _entrou(id: int, nm: String, av := 0, conta_uid := "") -> void:
	if id == meu_id():
		return
	jogadores[id] = {"nome": nm, "avatar": av, "uid": conta_uid}
	jogador_entrou.emit(id, nm)

func _peer_conectou(_id: int) -> void:
	pass                                       # só vale depois do _ola

func _peer_saiu(id: int) -> void:
	if jogadores.erase(id):
		jogador_saiu.emit(id)

func _derrubar_depois(id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		multiplayer.multiplayer_peer.disconnect_peer(id)

# ---------- mensagens do jogo (rede/sessao_rede.gd) ----------
# estado: chega rápido e pode perder pacote (o próximo corrige)
func enviar_estado(d: Array) -> void:
	if ligado:
		_estado.rpc(d)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _estado(d: Array) -> void:
	estado_recebido.emit(multiplayer.get_remote_sender_id(), d)

# infectados: só o HOST manda, para cada amigo os que estão perto dele (pode perder pacote: o próximo corrige)
func enviar_infectados(para: int, d: PackedFloat32Array) -> void:
	if ligado and eh_host():
		_infectados.rpc_id(para, d)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _infectados(d: PackedFloat32Array) -> void:
	infectados_recebidos.emit(d)

# 0.97 · VOZ (rede/voz.gd): 40 ms de voz em μ-law, no canal rápido (pode perder pacote: a voz segue)
func enviar_voz(d: PackedByteArray) -> void:
	if ligado:
		_voz.rpc(d)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _voz(d: PackedByteArray) -> void:
	if d.size() <= 2048:
		voz_recebida.emit(multiplayer.get_remote_sender_id(), d)

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
