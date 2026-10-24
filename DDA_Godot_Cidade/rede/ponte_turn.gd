extends Node
# PONTE DO HOST PELO RETRANSMISSOR (0.85) · multijogador pela internet no estilo "convidar amigo" (host + convite),
# sem servidor próprio e sem WebRTC. Criado por rede/rede.gd quando o host abre a partida com a conta.
#   1. pega um endereço público no retransmissor TURN (rede/turn.gd, conta da Metered em rede/turn.cfg);
#   2. quando um amigo pede para entrar (pelo Firebase: rede/rtc.gd lê sinal/{host}/{amigo}/c com modo "turn" e o
#      IP dele), libera o IP do amigo no retransmissor e responde o endereço público (h.relay);
#   3. o amigo conecta o ENet NORMAL nesse endereço. Cada amigo que chega pelo retransmissor ganha aqui um "soquete
#      espelho" que conversa com o servidor ENet do próprio host em 127.0.0.1:PORTA — para o jogo ele é só mais um
#      cliente ENet (mesmo código de sempre: RPC, sala, mundo, PvP...).
# Mexa AQUI para: quanto tempo um amigo calado é esquecido.

const Turn := preload("res://rede/turn.gd")
const ESQUECER := 60.0                         # s sem pacote de um amigo: fecha o espelho dele

signal pronto(endereco: String)                # "ip:porta" do retransmissor
signal falhou(motivo: String)

var porta_jogo := 24560
var turn = Turn.new()
var endereco := ""                             # "ip:porta" público (vazio até o retransmissor responder)
var _espelhos := {}                            # "ip:porta" do amigo -> {"udp": PacketPeerUDP, "t": float}
var bytes_recebidos := 0                       # pelo retransmissor (o plano grátis da Metered conta entrada + saída)
var bytes_enviados := 0

var _lista: Array = []                         # 0.87: retransmissores a tentar (o seu primeiro, a Metered de reserva)
var servidor_usado := ""                       # qual deu certo (host:porta)

func iniciar(porta: int, cfg := {}) -> bool:
	porta_jogo = porta
	var c: Dictionary = cfg if not cfg.is_empty() else Turn.config()
	if c.is_empty():
		return false
	_lista = [c] + (c.get("reservas", []) as Array)
	_tentar(0)
	return true

func _tentar(i: int) -> void:
	if i >= _lista.size():
		falhou.emit("nenhum retransmissor respondeu")
		return
	var c: Dictionary = _lista[i]
	turn.fechar()
	turn = Turn.new()
	turn.pronto.connect(func(ip: String, p: int):
		endereco = "%s:%d" % [ip, p]
		servidor_usado = "%s:%d" % [c["turn"][0], int(c["turn"][1])]
		pronto.emit(endereco))
	turn.falhou.connect(func(m: String):
		push_warning("PONTE: retransmissor %s: %s" % [str(c["turn"][0]), m])
		if i + 1 < _lista.size():
			_tentar(i + 1)                         # o seu servidor caiu: vai para a reserva
		else:
			falhou.emit(m))
	turn.recebido.connect(_do_amigo)
	if i + 1 < _lista.size():
		turn.tentativas = 5                         # ~9 s sem resposta e já tenta a reserva
	turn.alocar(c["turn"][0], int(c["turn"][1]), c["usuario"], c["senha"])

# o amigo com esse IP da internet pode mandar pacotes para o nosso endereço público
func permitir(ip: String) -> void:
	turn.permitir(ip)

func _do_amigo(ip: String, porta: int, dados: PackedByteArray) -> void:
	var k := "%s:%d" % [ip, porta]
	if not _espelhos.has(k):
		var u := PacketPeerUDP.new()
		u.bind(0, "127.0.0.1")
		u.set_dest_address("127.0.0.1", porta_jogo)
		_espelhos[k] = {"udp": u, "t": 0.0, "ip": ip, "porta": porta}
	var e: Dictionary = _espelhos[k]
	e["t"] = 0.0
	bytes_recebidos += dados.size()
	(e["udp"] as PacketPeerUDP).put_packet(dados)

# ---------- convite pelo Firebase (sinal/{host}/{amigo}: c = pedido do amigo, h = nossa resposta) ----------
const OLHAR_A_CADA := 1.2
const VALIDADE := 60.0
var _t_olhar := 0.0
var _atendidos := {}                           # uid do amigo -> sessão já atendida
var aceita_qualquer := false                   # servidor do PC: aceita qualquer conta (não só amigos)

var _olhando := false

func _vigiar() -> void:
	if not Conta.logado or endereco == "" or _olhando:
		return
	_olhando = true
	var d = await Conta.db_get("sinal/" + Conta.uid)
	_olhando = false
	if not (d is Dictionary) or endereco == "":
		return
	var agora := Time.get_unix_time_from_system() * 1000.0
	for cli in d:
		var e = d[cli]
		var c = e.get("c") if e is Dictionary else null
		if not (c is Dictionary) or str(c.get("modo", "")) != "turn":
			continue
		if not (Conta.amigos.has(cli) or aceita_qualquer):
			continue
		var sessao := str(c.get("sessao", ""))
		if agora - float(c.get("t", 0)) > VALIDADE * 1000.0 or _atendidos.get(cli, "") == sessao:
			continue
		_atendidos[cli] = sessao
		# 0.86: Rede libera no retransmissor E começa a furar o NAT (ligação direta); a resposta leva os dois caminhos
		var r: Dictionary = Rede.atender_amigo(str(c.get("ip", "")), int(c.get("porta", 0)))
		Conta.db_put("sinal/%s/%s/h" % [Conta.uid, cli], {"sessao": sessao, "relay": endereco, "direto": r.get("direto", ""), "modo": "turn"})
		print("PONTE: %s pediu para entrar (%s:%d) -> retransmissor %s · direto %s" % [str(cli).left(6), str(c.get("ip", "")), int(c.get("porta", 0)), endereco, r.get("direto", "")])

func _process(dt: float) -> void:
	turn.poll(dt)
	_t_olhar -= dt
	if _t_olhar <= 0.0:
		_t_olhar = OLHAR_A_CADA
		_vigiar()
	for k in _espelhos.keys():
		var e: Dictionary = _espelhos[k]
		var u: PacketPeerUDP = e["udp"]
		while u.get_available_packet_count() > 0:
			var pk := u.get_packet()
			bytes_enviados += pk.size()
			turn.enviar(e["ip"], e["porta"], pk)     # resposta do jogo -> amigo, pelo retransmissor
		e["t"] += dt
		if e["t"] > ESQUECER:
			u.close()
			_espelhos.erase(k)

func parar() -> void:
	for k in _espelhos:
		(_espelhos[k]["udp"] as PacketPeerUDP).close()
	_espelhos.clear()
	turn.fechar()
	endereco = ""

func _exit_tree() -> void:
	parar()
