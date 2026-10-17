extends MultiplayerPeerExtension
# PEER MISTO (só no HOST): junta duas "portas" numa só para o multijogador da Godot:
#   · ENet  -> quem entra pelo mesmo Wi-Fi, IP ou CÓDIGO (rede/rede.gd);
#   · WebRTC -> quem entra pela INTERNET com a conta (amigos), sem abrir porta (rede/rtc.gd).
# Para o resto do jogo é um servidor normal (id 1): os pacotes de cada jogador vão e vêm pela porta dele.
# Mexa AQUI só se mudar o jeito de conectar; o jogo em si não sabe que existem duas portas.

var enet: ENetMultiplayerPeer
var rtc: WebRTCMultiplayerPeer
var _dono := {}                               # id do jogador -> enet ou rtc
var _fila: Array = []                         # pacotes recebidos: [peer, canal, modo, PackedByteArray]
var _alvo := 0
var _modo := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _canal := 0
var _recusar := false

func _init(e: ENetMultiplayerPeer, r: WebRTCMultiplayerPeer) -> void:
	enet = e
	rtc = r
	for p in [enet, rtc]:
		p.peer_connected.connect(_entrou.bind(p))
		p.peer_disconnected.connect(_saiu)

func _entrou(id: int, p: MultiplayerPeer) -> void:
	_dono[id] = p
	peer_connected.emit(id)

func _saiu(id: int) -> void:
	_dono.erase(id)
	peer_disconnected.emit(id)

func _poll() -> void:
	for p in [enet, rtc]:
		p.poll()
		while p.get_available_packet_count() > 0:
			var de: int = p.get_packet_peer()
			var ch: int = p.get_packet_channel()
			var md: int = p.get_packet_mode()
			_fila.append([de, ch, md, p.get_packet()])

func _get_available_packet_count() -> int:
	return _fila.size()

func _get_packet_script() -> PackedByteArray:
	return _fila.pop_front()[3] if not _fila.is_empty() else PackedByteArray()

func _get_packet_peer() -> int:
	return _fila[0][0] if not _fila.is_empty() else 0

func _get_packet_channel() -> int:
	return _fila[0][1] if not _fila.is_empty() else 0

func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return _fila[0][2] if not _fila.is_empty() else MultiplayerPeer.TRANSFER_MODE_RELIABLE

func _put_packet_script(buf: PackedByteArray) -> Error:
	if _alvo > 0:
		var p: MultiplayerPeer = _dono.get(_alvo)
		return _enviar(p, _alvo, buf) if p != null else ERR_UNAVAILABLE
	# 0 = todos · negativo = todos menos um
	for p in [enet, rtc]:
		var alvo := _alvo if _alvo < 0 and _dono.get(-_alvo) == p else 0
		if _tem_jogador(p):
			_enviar(p, alvo, buf)
	return OK

func _tem_jogador(p: MultiplayerPeer) -> bool:
	for id in _dono:
		if _dono[id] == p:
			return true
	return false

func _enviar(p: MultiplayerPeer, alvo: int, buf: PackedByteArray) -> Error:
	p.transfer_mode = _modo
	p.transfer_channel = _canal
	p.set_target_peer(alvo)
	return p.put_packet(buf)

func _set_target_peer(id: int) -> void:
	_alvo = id

func _set_transfer_mode(m: MultiplayerPeer.TransferMode) -> void:
	_modo = m

func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _modo

func _set_transfer_channel(c: int) -> void:
	_canal = c

func _get_transfer_channel() -> int:
	return _canal

func _get_max_packet_size() -> int:
	return 1 << 24

func _get_unique_id() -> int:
	return 1

func _is_server() -> bool:
	return true

func _is_server_relay_supported() -> bool:
	return true

func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return MultiplayerPeer.CONNECTION_CONNECTED

func _disconnect_peer(id: int, force: bool) -> void:
	var p: MultiplayerPeer = _dono.get(id)
	if p != null:
		p.disconnect_peer(id, force)

func _close() -> void:
	enet.close()
	rtc.close()
	_dono.clear()
	_fila.clear()

func _set_refuse_new_connections(v: bool) -> void:
	_recusar = v
	enet.refuse_new_connections = v
	rtc.refuse_new_connections = v

func _is_refusing_new_connections() -> bool:
	return _recusar
