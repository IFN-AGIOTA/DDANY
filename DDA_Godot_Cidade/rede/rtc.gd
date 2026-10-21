extends Node
# CONEXÃO PELA INTERNET COM WEBRTC (como as chamadas de vídeo): os celulares se acham pelo FIREBASE e depois
# falam DIRETO, atravessando roteador e 4G na maioria das redes, sem abrir porta. Usado por rede/rede.gd:
#   · HOST: com a conta aberta, vigia sinal/{meu uid} no banco. Quando um AMIGO deixa uma "oferta" lá, responde
#     e o amigo entra pela parte WebRTC do rede/peer_misto.gd.
#   · AMIGO: conectar(uid do host) cria a oferta, grava em sinal/{host}/{eu}/c e espera a resposta em .../h.
# SERVIDOR DO PC (0.51): rede/servidor.gd entra como convidado e publica servidores/{uid}; aceita oferta de qualquer
# jogador (não só amigos). As regras do banco deixam qualquer conta mandar oferta para um servidor publicado.
# Servidores STUN públicos do Google descobrem o endereço de cada um. Redes muito fechadas (alguns 4G e redes de
# empresa) só passam com um servidor TURN (retransmissão): dá para pôr um em rede/firebase_config.cfg [webrtc].
# Banco: sinal/{host}/{amigo} = {c: {id, sessao, sdp, cand: [[midia, indice, nome], ...], t}, h: {sessao, sdp, cand}}
# (regras em rede/firebase_regras.json). Mexa AQUI para: tempos, servidores STUN/TURN.

signal cliente_falhou(motivo: String)
signal diagnostico(texto: String)              # 0.53: o que aconteceu na conexão (o servidor do PC escreve no console)

const STUN := ["stun:stun.l.google.com:19302"]   # a biblioteca do celular (libjuice) usa UM servidor STUN só
const OLHAR_A_CADA := 1.2                     # segundos entre consultas ao banco
const DESISTIR := 40.0                        # amigo: sem conectar nesse tempo, desiste
const VALIDADE := 60.0                        # host: oferta mais velha que isso é ignorada
const CANAIS := [MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, MultiplayerPeer.TRANSFER_MODE_RELIABLE]  # canais 1 e 2 das RPCs

var _ice := {}
var tem_turn := false                         # tem retransmissor configurado (rede/turn.cfg)
var _diag := {}                               # amigo: até onde chegou (aparece na mensagem de falha)
var _tipos := {}                              # amigo: caminhos achados por mim {"host": n, "srflx": n, "relay": n}

# tipo do caminho de um candidato ICE: host (rede local), srflx (internet direta), relay (retransmissor)
static func tipo_cand(n: String) -> String:
	var i := n.find(" typ ")
	return n.substr(i + 5).get_slice(" ", 0) if i >= 0 else "?"

static func resumo_tipos(lista: Array) -> String:
	var c := {"host": 0, "srflx": 0, "relay": 0}
	for x in lista:
		var t := tipo_cand(str(x[2]) if x is Array and x.size() == 3 else str(x))
		c[t] = int(c.get(t, 0)) + 1
	return "rede local %d · internet %d · retransmissor %d" % [c["host"], c["srflx"], c["relay"]]
# host
var _peer_host: WebRTCMultiplayerPeer = null
var _clientes := {}                           # uid do amigo -> {"sessao", "id", "conn", "h": {...}, "lidos": int, "t_ok": float}
var _t_olhar := 0.0
# amigo
var _peer_cli: WebRTCMultiplayerPeer = null
var _conn: WebRTCPeerConnection = null
var _host_uid := ""
var _minha_sessao := ""
var _c := {}                                  # o que eu gravo em .../c
var _lidos := 0
var _resposta := false
var _t_cli := 0.0
var _gravando := {}                           # caminho -> true enquanto um PUT está no ar
var _pendente := {}                           # caminho -> último valor que falta gravar

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var servidores: Array = [{"urls": STUN}]
	# RETRANSMISSOR (TURN), 0.52: rede/turn.cfg [turn] urls (várias, separadas por vírgula), usuario, senha.
	# Sem ele, 4G e redes com CGNAT dos dois lados não conectam (o WebRTC não consegue "furar" os dois roteadores).
	# Fica fora do git (.gitignore) mas vai dentro do APK, do servidor do PC e dos pacotes. Modelo: rede/turn_exemplo.cfg
	var cf := ConfigFile.new()
	var urls := ""
	var usuario := ""
	var senha := ""
	if cf.load("res://rede/turn.cfg") == OK:
		urls = str(cf.get_value("turn", "urls", ""))
		usuario = str(cf.get_value("turn", "usuario", ""))
		senha = str(cf.get_value("turn", "senha", ""))
	elif cf.load("res://rede/firebase_config.cfg") == OK:        # jeito antigo (um endereço só)
		urls = str(cf.get_value("webrtc", "turn", ""))
		usuario = str(cf.get_value("webrtc", "turn_usuario", ""))
		senha = str(cf.get_value("webrtc", "turn_senha", ""))
	var lista: Array = []                     # lista COMUM: o WebRTC recusa PackedStringArray (initialize dá erro)
	for u in urls.split(",", false):
		u = u.strip_edges()
		# libjuice (WebRTC do jogo) só fala UDP: TURN por TCP/TLS e STUN extra atrapalham (0.54)
		if u.begins_with("turn:") and not "transport=tcp" in u:
			lista.append(u)
	if not lista.is_empty() and usuario.strip_edges() != "":
		servidores.append({"urls": lista, "username": usuario.strip_edges(), "credential": senha.strip_edges()})
		tem_turn = true
	_ice = {"iceServers": servidores}

# o WebRTC existe nesta plataforma? (addons/webrtc_native: Android arm64, Linux e Windows x86_64)
static func disponivel() -> bool:
	var c := WebRTCPeerConnection.new()
	var ok := c.initialize({}) == OK
	c.close()
	return ok

func _nova_conexao() -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	var e := c.initialize(_ice)
	_diag["config"] = "ok" if e == OK else "RECUSADA(%d)" % e
	if e != OK:                                  # configuração recusada: tenta só com o STUN (melhor que nada)
		push_warning("WebRTC: configuração ICE recusada (%d); seguindo sem retransmissor" % e)
		c = WebRTCPeerConnection.new()
		c.initialize({"iceServers": [{"urls": STUN}]})
	return c

# ---------------- HOST ----------------
func comecar_host() -> WebRTCMultiplayerPeer:
	parar()
	_peer_host = WebRTCMultiplayerPeer.new()
	_peer_host.create_server(CANAIS)
	return _peer_host

func _vigiar_host() -> void:
	if not Conta.logado:
		return
	var d = await Conta.db_get("sinal/" + Conta.uid)
	if _peer_host == null or not (d is Dictionary):
		return
	var agora := Time.get_unix_time_from_system() * 1000.0
	for cli in d:
		var e = d[cli]
		var c = e.get("c") if e is Dictionary else null
		if not (c is Dictionary) or not (Conta.amigos.has(cli) or Rede.servidor_dedicado):   # servidor do PC: aceita qualquer um
			continue
		var sessao := str(c.get("sessao", ""))
		if agora - float(c.get("t", 0)) > VALIDADE * 1000.0:
			if not _clientes.has(cli) or _clientes[cli]["sessao"] != sessao:
				Conta.db_del("sinal/%s/%s" % [Conta.uid, cli])   # oferta velha: limpa
			continue
		if not _clientes.has(cli) or _clientes[cli]["sessao"] != sessao:
			_atender(cli, c)
		if not _clientes.has(cli) or _clientes[cli]["sessao"] != sessao:
			continue
		var k: Dictionary = _clientes[cli]
		var cand: Array = c.get("cand", []) if c.get("cand") is Array else []
		while k["lidos"] < cand.size():
			var x = cand[k["lidos"]]
			if x is Array and x.size() == 3:
				(k["conn"] as WebRTCPeerConnection).add_ice_candidate(str(x[0]), int(x[1]), str(x[2]))
			k["lidos"] += 1

func _atender(cli: String, c: Dictionary) -> void:
	if _clientes.has(cli):
		var velho: Dictionary = _clientes[cli]
		if _peer_host.has_peer(int(velho["id"])):
			_peer_host.remove_peer(int(velho["id"]))
	var id := int(c.get("id", 0))
	if id < 2 or _peer_host.has_peer(id) or str(c.get("sdp", "")) == "":
		return
	var conn := _nova_conexao()
	var k := {"sessao": str(c.get("sessao", "")), "id": id, "conn": conn, "lidos": 0, "t_ok": -1.0,
		"h": {"sessao": str(c.get("sessao", "")), "sdp": "", "cand": []}}
	_clientes[cli] = k
	var caminho := "sinal/%s/%s/h" % [Conta.uid, cli]
	conn.session_description_created.connect(func(tipo: String, sdp: String):
		conn.set_local_description(tipo, sdp)
		k["h"]["sdp"] = sdp
		_gravar(caminho, k["h"]))
	conn.ice_candidate_created.connect(func(m: String, i: int, n: String):
		k["h"]["cand"].append([m, i, n])
		_gravar(caminho, k["h"]))
	_peer_host.add_peer(conn, id)
	conn.set_remote_description("offer", str(c.get("sdp", "")))
	k["estado"] = -1
	diagnostico.emit("WebRTC: pedido de conexão de %s (caminhos dele até agora: %s)" % [cli.left(6), resumo_tipos(c.get("cand", []) if c.get("cand") is Array else [])])

# ---------------- AMIGO ----------------
func conectar(host_uid: String) -> WebRTCMultiplayerPeer:
	parar()
	_host_uid = host_uid
	_minha_sessao = str(randi()) + str(Time.get_ticks_usec())
	var meu_id := randi_range(1000, 2147483000)
	_peer_cli = WebRTCMultiplayerPeer.new()
	_peer_cli.create_client(meu_id, CANAIS)
	_conn = _nova_conexao()
	_c = {"id": meu_id, "sessao": _minha_sessao, "sdp": "", "cand": [], "t": {".sv": "timestamp"}}
	_lidos = 0
	_resposta = false
	_t_cli = 0.0
	var caminho := "sinal/%s/%s/c" % [host_uid, Conta.uid]
	_conn.session_description_created.connect(func(tipo: String, sdp: String):
		_conn.set_local_description(tipo, sdp)
		_c["sdp"] = sdp
		_diag["oferta"] = "sim (%d caminhos dentro)" % sdp.count("a=candidate")
		_gravar(caminho, _c))
	_tipos = {}
	_diag = {"config": _diag.get("config", "?"), "oferta": "não", "banco_ok": 0, "banco_erro": 0}
	_conn.ice_candidate_created.connect(func(m: String, i: int, n: String):
		_c["cand"].append([m, i, n])
		var t := tipo_cand(n)
		_tipos[t] = int(_tipos.get(t, 0)) + 1
		_gravar(caminho, _c))
	_diag["add_peer"] = _peer_cli.add_peer(_conn, 1)
	_diag["create_offer"] = _conn.create_offer()
	return _peer_cli

func _vigiar_cliente() -> void:
	var h = await Conta.db_get("sinal/%s/%s/h" % [_host_uid, Conta.uid])
	if _conn == null or not (h is Dictionary) or str(h.get("sessao", "")) != _minha_sessao:
		return
	if not _resposta and str(h.get("sdp", "")) != "":
		_resposta = true
		_conn.set_remote_description("answer", str(h["sdp"]))
	if not _resposta:
		return
	var cand: Array = h.get("cand", []) if h.get("cand") is Array else []
	while _lidos < cand.size():
		var x = cand[_lidos]
		if x is Array and x.size() == 3:
			_conn.add_ice_candidate(str(x[0]), int(x[1]), str(x[2]))
		_lidos += 1

# ---------------- comum ----------------
func parar() -> void:
	if _host_uid != "" and Conta.logado:
		Conta.db_del("sinal/%s/%s/c" % [_host_uid, Conta.uid])
	if _peer_host != null and Conta.logado:
		Conta.db_del("sinal/" + Conta.uid)
	_peer_host = null
	_clientes.clear()
	_peer_cli = null
	_conn = null
	_host_uid = ""

func _process(dt: float) -> void:
	_t_olhar -= dt
	if _peer_host != null:
		# depois de conectado, apaga a troca de mensagens do banco
		for cli in _clientes.keys():
			var k: Dictionary = _clientes[cli]
			var conn: WebRTCPeerConnection = k["conn"]
			var est := conn.get_connection_state()
			if est != int(k.get("estado", -1)):
				k["estado"] = est
				var nomes := ["novo", "conectando", "CONECTADO", "desconectou", "FALHOU", "fechado"]
				diagnostico.emit("WebRTC %s: %s · meus caminhos: %s" % [cli.left(6), nomes[clampi(est, 0, 5)], resumo_tipos(k["h"]["cand"])])
			if est == WebRTCPeerConnection.STATE_CONNECTED and k["t_ok"] < 0.0:
				k["t_ok"] = 0.0
				Conta.db_del("sinal/%s/%s" % [Conta.uid, cli])
		if _t_olhar <= 0.0:
			_t_olhar = OLHAR_A_CADA
			_vigiar_host()
	elif _conn != null:
		_t_cli += dt
		if _conn.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED:
			if _host_uid != "":
				Conta.db_del("sinal/%s/%s/c" % [_host_uid, Conta.uid])
				_host_uid = ""
			return
		_diag["estado"] = _conn.get_connection_state()
		if _t_cli > DESISTIR:
			var resp := _resposta
			parar()
			var d := "[%s · resposta do servidor: %s · retransmissor: %s · config: %s · oferta: %s · banco: %d ok/%d erro · estado: %d]" % [
				resumo_tipos(_c.get("cand", [])), "sim" if resp else "NÃO", "sim" if tem_turn else "não", _diag.get("config", "?"),
				_diag.get("oferta", "?"), int(_diag.get("banco_ok", 0)), int(_diag.get("banco_erro", 0)), int(_diag.get("estado", -1))]
			d += " [add_peer %s · create_offer %s · %s]" % [_diag.get("add_peer", "?"), _diag.get("create_offer", "?"), OS.get_name()]
			var motivo := "Não deu para conectar pela internet."
			if not resp:
				motivo = "O servidor não respondeu (está ligado? na mesma versão?)."
			elif tem_turn and int(_tipos.get("relay", 0)) == 0:
				motivo = "Não deu para usar o retransmissor nesta rede (a senha mudou ou a rede bloqueia)."
			cliente_falhou.emit(motivo + " " + d)
			return
		if _t_olhar <= 0.0:
			_t_olhar = OLHAR_A_CADA
			_vigiar_cliente()

# grava o nó inteiro, um PUT por vez por caminho (o último valor sempre vence)
func _gravar(caminho: String, valor: Dictionary) -> void:
	_pendente[caminho] = valor.duplicate(true)
	if _gravando.get(caminho, false):
		return
	_gravando[caminho] = true
	while _pendente.has(caminho):
		var v = _pendente[caminho]
		_pendente.erase(caminho)
		if await Conta.db_put(caminho, v):
			_diag["banco_ok"] = int(_diag.get("banco_ok", 0)) + 1
		else:
			_diag["banco_erro"] = int(_diag.get("banco_erro", 0)) + 1
	_gravando[caminho] = false
