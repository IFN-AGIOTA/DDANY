extends RefCounted
# CLIENTE TURN EM GDSCRIPT (0.85) · RFC 5766/8656 (TURN) e 5389 (STUN), por UDP.
# Substitui o WebRTC (biblioteca nativa que não inicia no Android) no multijogador pela internet:
#   · o HOST pede ao retransmissor (Metered, rede/turn.cfg) um ENDEREÇO PÚBLICO (Allocate) e libera o IP de cada
#     amigo (CreatePermission). O que o amigo manda para esse endereço chega aqui (Data/ChannelData) e o que o
#     host manda vai pelo retransmissor (Send/ChannelData). rede/ponte_turn.gd liga isso ao ENet do jogo.
#   · o AMIGO não precisa de TURN: descobre o próprio IP da internet com um pedido STUN (ip_publico) e conecta o
#     ENet normal no endereço do retransmissor.
# Funciona no 4G e com CGNAT dos dois lados (os dados passam pelo retransmissor) e não precisa de servidor próprio.
# Uso: alocar(host, porta, usuario, senha) -> sinal pronto(ip, porta) · permitir(ip) · enviar(ip, porta, dados)
#      sinal recebido(ip, porta, dados) · poll() a cada quadro (rede/ponte_turn.gd chama) · fechar()
# Mexa AQUI para: tempos de renovação e de repetição dos pedidos.

signal pronto(ip: String, porta: int)          # endereço público (relay) criado
signal falhou(motivo: String)
signal recebido(ip: String, porta: int, dados: PackedByteArray)

const MAGIC := 0x2112A442
# tipos de mensagem
const BINDING := 0x0001
const ALLOCATE := 0x0003
const REFRESH := 0x0004
const SEND_IND := 0x0016
const DATA_IND := 0x0017
const CREATE_PERMISSION := 0x0008
const CHANNEL_BIND := 0x0009
# atributos
const A_MAPPED := 0x0001
const A_USERNAME := 0x0006
const A_INTEGRITY := 0x0008
const A_ERROR := 0x0009
const A_CHANNEL := 0x000C
const A_LIFETIME := 0x000D
const A_PEER := 0x0012
const A_DATA := 0x0013
const A_REALM := 0x0014
const A_NONCE := 0x0015
const A_RELAYED := 0x0016
const A_TRANSPORT := 0x0019
const A_XOR_MAPPED := 0x0020

const VIDA := 600                              # pedimos 10 min de alocação; renovamos bem antes
const RENOVAR := 240.0                         # s: alocação, permissões e canais renovados a cada 4 min
const REPETIR := 0.6                           # s entre repetições de um pedido sem resposta (UDP perde pacote)
const TENTATIVAS := 7

var udp := PacketPeerUDP.new()
var servidor_ip := ""
var servidor_porta := 0
var usuario := ""
var senha := ""
var realm := PackedByteArray()
var nonce := PackedByteArray()
var _chave := PackedByteArray()
var relay_ip := ""
var relay_porta := 0
var ip_mapeado := ""                           # o IP deste aparelho visto pelo retransmissor
var ativo := false
var _pendentes := {}                           # id da transação (hex) -> {msg, tipo, attrs, t, n, extra}
var _permitidos := {}                          # ip -> true
var _canais := {}                              # "ip:porta" -> número do canal (0x4000..)
var _canal_de := {}                            # número -> [ip, porta]
var _prox_canal := 0x4000
var _t_renovar := 0.0
var _rng := RandomNumberGenerator.new()

# ---------------- bytes ----------------
static func _u16(b: PackedByteArray, i: int) -> int:
	return (b[i] << 8) | b[i + 1]

static func _u32(b: PackedByteArray, i: int) -> int:
	return (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3]

static func _p16(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 8) & 0xFF, v & 0xFF])

static func _p32(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF])

static func _attr(tipo: int, valor: PackedByteArray) -> PackedByteArray:
	var r := _p16(tipo) + _p16(valor.size()) + valor
	while r.size() % 4 != 0:
		r.append(0)
	return r

static func _ip_bytes(ip: String) -> PackedByteArray:
	var r := PackedByteArray()
	for p in ip.split("."):
		r.append(int(p) & 0xFF)
	return r

# XOR-PEER-ADDRESS / XOR-MAPPED / XOR-RELAYED (IPv4)
static func _xor_end(ip: String, porta: int) -> PackedByteArray:
	var b := _ip_bytes(ip)
	var ipn := (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]
	return PackedByteArray([0, 1]) + _p16(porta ^ (MAGIC >> 16)) + _p32(ipn ^ MAGIC)

static func _ler_xor_end(v: PackedByteArray) -> Array:
	if v.size() < 8 or v[1] != 1:
		return ["", 0]
	var porta := _u16(v, 2) ^ (MAGIC >> 16)
	var ipn := _u32(v, 4) ^ MAGIC
	return ["%d.%d.%d.%d" % [(ipn >> 24) & 0xFF, (ipn >> 16) & 0xFF, (ipn >> 8) & 0xFF, ipn & 0xFF], porta]

func _novo_id() -> PackedByteArray:
	var r := PackedByteArray()
	for i in 12:
		r.append(_rng.randi() & 0xFF)
	return r

# monta a mensagem STUN; com_auth = USERNAME, REALM, NONCE e MESSAGE-INTEGRITY (HMAC-SHA1)
func _montar(tipo: int, id: PackedByteArray, attrs: PackedByteArray, com_auth: bool) -> PackedByteArray:
	var corpo := attrs
	if com_auth and not nonce.is_empty():
		corpo = corpo + _attr(A_USERNAME, usuario.to_utf8_buffer()) + _attr(A_REALM, realm) + _attr(A_NONCE, nonce)
		var cab := _p16(tipo) + _p16(corpo.size() + 24) + _p32(MAGIC) + id
		var h := HMACContext.new()
		h.start(HashingContext.HASH_SHA1, _chave)
		h.update(cab + corpo)
		corpo = corpo + _attr(A_INTEGRITY, h.finish())
	return _p16(tipo) + _p16(corpo.size()) + _p32(MAGIC) + id + corpo

static func ler(m: PackedByteArray) -> Dictionary:
	if m.size() < 20 or _u32(m, 4) != MAGIC:
		return {}
	var tam := _u16(m, 2)
	var attrs := {}
	var i := 20
	while i + 4 <= mini(m.size(), 20 + tam):
		var t := _u16(m, i)
		var l := _u16(m, i + 2)
		if not attrs.has(t):
			attrs[t] = m.slice(i + 4, i + 4 + l)
		i += 4 + l + ((4 - l % 4) % 4)
	return {"tipo": _u16(m, 0), "id": m.slice(8, 20), "attrs": attrs}

static func erro_de(d: Dictionary) -> int:
	var e: PackedByteArray = d["attrs"].get(A_ERROR, PackedByteArray())
	return (e[2] & 7) * 100 + e[3] if e.size() >= 4 else 0

# ---------------- conexão ----------------
func alocar(host: String, porta: int, u: String, s: String) -> void:
	_rng.randomize()
	usuario = u
	senha = s
	servidor_ip = host if host.is_valid_ip_address() else IP.resolve_hostname(host, IP.TYPE_IPV4)
	servidor_porta = porta
	if servidor_ip == "":
		falhou.emit("não achei o retransmissor %s" % host)
		return
	udp.close()
	udp.bind(0)
	udp.set_dest_address(servidor_ip, servidor_porta)
	_pedir(ALLOCATE, _attr(A_TRANSPORT, _p32(17 << 24)) + _attr(A_LIFETIME, _p32(VIDA)), false)

func _pedir(tipo: int, attrs: PackedByteArray, com_auth := true, extra := {}) -> void:
	var id := _novo_id()
	var m := _montar(tipo, id, attrs, com_auth)
	_pendentes[id.hex_encode()] = {"msg": m, "tipo": tipo, "attrs": attrs, "t": REPETIR, "n": 0, "extra": extra,
		"auth": com_auth and not nonce.is_empty()}
	udp.put_packet(m)

func permitir(ip: String) -> void:
	if not ip.is_valid_ip_address() or ":" in ip:
		return
	_permitidos[ip] = true
	if ativo:
		_pedir(CREATE_PERMISSION, _attr(A_PEER, _xor_end(ip, 0)))

func enviar(ip: String, porta: int, dados: PackedByteArray) -> void:
	if not ativo:
		return
	var k := "%s:%d" % [ip, porta]
	var c: int = _canais.get(k, 0)
	if c > 0:
		var r := _p16(c) + _p16(dados.size()) + dados        # ChannelData (4 bytes de cabeçalho)
		while r.size() % 4 != 0:
			r.append(0)
		udp.put_packet(r)
		return
	# ainda sem canal: Send indication (não precisa de senha)
	udp.put_packet(_montar(SEND_IND, _novo_id(), _attr(A_PEER, _xor_end(ip, porta)) + _attr(A_DATA, dados), false))
	if not _canais.has(k) and _prox_canal <= 0x7FFE:
		_canais[k] = 0                                  # pedido de canal em andamento
		var n := _prox_canal
		_prox_canal += 1
		_pedir(CHANNEL_BIND, _attr(A_CHANNEL, _p16(n) + _p16(0)) + _attr(A_PEER, _xor_end(ip, porta)), true, {"canal": n, "k": k, "ip": ip, "porta": porta})

func fechar() -> void:
	if ativo:
		udp.put_packet(_montar(REFRESH, _novo_id(), _attr(A_LIFETIME, _p32(0)), true))   # devolve o endereço
	ativo = false
	udp.close()
	_pendentes.clear()
	_canais.clear()
	_canal_de.clear()

func poll(dt: float) -> void:
	while udp.get_available_packet_count() > 0:
		var p := udp.get_packet()
		if p.size() >= 4 and (p[0] & 0xC0) == 0x40:          # ChannelData
			var c := _u16(p, 0)
			var l := _u16(p, 2)
			if _canal_de.has(c) and p.size() >= 4 + l:
				var e: Array = _canal_de[c]
				recebido.emit(e[0], e[1], p.slice(4, 4 + l))
			continue
		_resposta(ler(p))
	for id in _pendentes.keys():
		var q: Dictionary = _pendentes[id]
		q["t"] -= dt
		if q["t"] <= 0.0:
			q["n"] += 1
			if q["n"] >= TENTATIVAS:
				_pendentes.erase(id)
				if q["tipo"] == ALLOCATE:
					falhou.emit("o retransmissor não respondeu")
				continue
			q["t"] = REPETIR * (1 << mini(q["n"], 3))
			udp.put_packet(q["msg"])
	if ativo:
		_t_renovar -= dt
		if _t_renovar <= 0.0:
			_t_renovar = RENOVAR
			_pedir(REFRESH, _attr(A_LIFETIME, _p32(VIDA)))
			for ip in _permitidos:
				_pedir(CREATE_PERMISSION, _attr(A_PEER, _xor_end(ip, 0)))
			for k in _canais:
				var n: int = _canais[k]
				if n > 0:
					var e: Array = _canal_de[n]
					_pedir(CHANNEL_BIND, _attr(A_CHANNEL, _p16(n) + _p16(0)) + _attr(A_PEER, _xor_end(e[0], e[1])), true, {"canal": n, "k": k, "ip": e[0], "porta": e[1]})

func _resposta(d: Dictionary) -> void:
	if d.is_empty():
		return
	var tipo: int = d["tipo"]
	if tipo == DATA_IND:
		var pe := _ler_xor_end(d["attrs"].get(A_PEER, PackedByteArray()))
		if pe[0] != "" and d["attrs"].has(A_DATA):
			recebido.emit(pe[0], pe[1], d["attrs"][A_DATA])
		return
	var id: String = (d["id"] as PackedByteArray).hex_encode()
	if not _pendentes.has(id):
		return
	var q: Dictionary = _pendentes[id]
	_pendentes.erase(id)
	var classe := tipo & 0x0110                     # 0x0100 = sucesso, 0x0110 = erro
	if classe == 0x0110:
		var e := erro_de(d)
		if e == 401 or e == 438:                        # precisa de senha / nonce velho: repete com o novo
			var novo: PackedByteArray = d["attrs"].get(A_NONCE, nonce)
			var mudou := novo != nonce
			nonce = novo
			realm = d["attrs"].get(A_REALM, realm)
			_chave = ("%s:%s:%s" % [usuario, realm.get_string_from_utf8(), senha]).md5_buffer()
			var rep := int(q["extra"].get("_rep", 0))
			# 1ª vez sem senha, ou nonce trocado: repete (com senha errada o servidor responde 401 de novo e desiste)
			if (not q["auth"] or mudou or e == 438) and rep < 3:
				var ex: Dictionary = q["extra"].duplicate()
				ex["_rep"] = rep + 1
				_pedir(q["tipo"], q["attrs"], true, ex)
				return
		if q["tipo"] == ALLOCATE:
			falhou.emit("o retransmissor recusou (%d)" % e)
		elif q["tipo"] == CHANNEL_BIND:
			_canais.erase(q["extra"]["k"])
		return
	match q["tipo"]:
		ALLOCATE:
			var r := _ler_xor_end(d["attrs"].get(A_RELAYED, PackedByteArray()))
			var mp := _ler_xor_end(d["attrs"].get(A_XOR_MAPPED, PackedByteArray()))
			relay_ip = r[0]
			relay_porta = r[1]
			ip_mapeado = mp[0]
			ativo = relay_ip != ""
			_t_renovar = RENOVAR
			if not ativo:
				falhou.emit("o retransmissor não deu endereço")
				return
			for ip in _permitidos:
				_pedir(CREATE_PERMISSION, _attr(A_PEER, _xor_end(ip, 0)))
			pronto.emit(relay_ip, relay_porta)
		CHANNEL_BIND:
			var x: Dictionary = q["extra"]
			_canais[x["k"]] = x["canal"]
			_canal_de[x["canal"]] = [x["ip"], x["porta"]]

# ---------------- STUN (o amigo descobre o próprio IP da internet) ----------------
# usa a porta local "porta_local" (a mesma que o ENet vai usar depois) · devolve "" se não deu
static func ip_publico(host: String, porta: int, porta_local: int, espera := 3.0) -> String:
	var ip := host if host.is_valid_ip_address() else IP.resolve_hostname(host, IP.TYPE_IPV4)
	if ip == "":
		return ""
	var u := PacketPeerUDP.new()
	if u.bind(porta_local) != OK:
		return ""
	u.set_dest_address(ip, porta)
	var r := RandomNumberGenerator.new()
	r.randomize()
	var id := PackedByteArray()
	for i in 12:
		id.append(r.randi() & 0xFF)
	var m := _p16(BINDING) + _p16(0) + _p32(MAGIC) + id
	var t0 := Time.get_ticks_msec()
	var proximo := 0
	var achou := ""
	while Time.get_ticks_msec() - t0 < int(espera * 1000.0) and achou == "":
		if Time.get_ticks_msec() >= proximo:
			u.put_packet(m)
			proximo = Time.get_ticks_msec() + 500
		while u.get_available_packet_count() > 0:
			var d := ler(u.get_packet())
			if not d.is_empty() and d["id"] == id:
				var a: Dictionary = d["attrs"]
				var e := _ler_xor_end(a.get(A_XOR_MAPPED, PackedByteArray()))
				achou = e[0]
		OS.delay_msec(20)
	u.close()
	return achou

# o mesmo, sem travar a tela (espera os quadros do "no")
static func ip_publico_async(no: Node, host: String, porta: int, porta_local: int, espera := 4.0) -> String:
	var ip := host if host.is_valid_ip_address() else IP.resolve_hostname(host, IP.TYPE_IPV4)
	if ip == "":
		return ""
	var u := PacketPeerUDP.new()
	if u.bind(porta_local) != OK:
		return ""
	u.set_dest_address(ip, porta)
	var r := RandomNumberGenerator.new()
	r.randomize()
	var id := PackedByteArray()
	for i in 12:
		id.append(r.randi() & 0xFF)
	var m := _p16(BINDING) + _p16(0) + _p32(MAGIC) + id
	var t0 := Time.get_ticks_msec()
	var proximo := 0
	var achou := ""
	while Time.get_ticks_msec() - t0 < int(espera * 1000.0) and achou == "" and is_instance_valid(no) and no.is_inside_tree():
		if Time.get_ticks_msec() >= proximo:
			u.put_packet(m)
			proximo = Time.get_ticks_msec() + 500
		while u.get_available_packet_count() > 0:
			var d := ler(u.get_packet())
			if not d.is_empty() and d["id"] == id:
				achou = _ler_xor_end((d["attrs"] as Dictionary).get(A_XOR_MAPPED, PackedByteArray()))[0]
		await no.get_tree().process_frame
	u.close()
	return achou

# endereço do retransmissor (UDP) e do STUN a partir de rede/turn.cfg ("turn:host:porta", "stun:host:porta")
static func config() -> Dictionary:
	# testes (ferramentas/testes/rede_turn_*.gd): DDA_TURN="ip:porta:usuario:senha" troca o retransmissor
	var env := OS.get_environment("DDA_TURN")
	if env != "":
		var x := env.split(":")
		return {"turn": [x[0], int(x[1])], "stun": [x[0], int(x[1])], "usuario": x[2], "senha": x[3]}
	var cf := ConfigFile.new()
	if cf.load("res://rede/turn.cfg") != OK:
		return {}
	var d := {"usuario": str(cf.get_value("turn", "usuario", "")).strip_edges(), "senha": str(cf.get_value("turn", "senha", "")).strip_edges()}
	for u in str(cf.get_value("turn", "urls", "")).split(",", false):
		u = u.strip_edges()
		if u.begins_with("turn:") and not "transport=tcp" in u and not d.has("turn"):
			var hp := u.substr(5).split("?")[0].split(":")
			d["turn"] = [hp[0], int(hp[1]) if hp.size() > 1 else 3478]
		elif u.begins_with("stun:") and not d.has("stun"):
			var hp2 := u.substr(5).split(":")
			d["stun"] = [hp2[0], int(hp2[1]) if hp2.size() > 1 else 3478]
	if not d.has("stun") and d.has("turn"):
		d["stun"] = d["turn"]
	return d if d.has("turn") and d["usuario"] != "" else {}
