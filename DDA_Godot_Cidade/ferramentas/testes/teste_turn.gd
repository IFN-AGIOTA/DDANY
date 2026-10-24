extends SceneTree
# TESTE: CLIENTE TURN EM GDSCRIPT (0.85, rede/turn.gd) contra o retransmissor de mentira (ferramentas/testes/turn_falso.py,
# porta em DDA_TURN_PORTA). Confere: endereço público (com o desafio da senha), permissão, amigo -> host (Data),
# host -> amigo (Send e depois Canal), renovação com "nonce velho" (438), descoberta do IP (STUN) e senha errada.
const Turn := preload("res://rede/turn.gd")
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)
func _initialize():
	_r.call_deferred()
func _esperar(cond: Callable, seg: float, t) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seg * 1000.0):
		t.poll(0.016)
		if cond.call():
			return true
		await process_frame
		OS.delay_msec(5)
	return false

func _r():
	var porta := int(OS.get_environment("DDA_TURN_PORTA"))
	var t = Turn.new()
	var st := {"pronto": false, "falhou": "", "rec": []}
	t.pronto.connect(func(ip, p): st["pronto"] = true)
	t.falhou.connect(func(m): st["falhou"] = m)
	t.recebido.connect(func(ip, p, d): st["rec"].append([ip, p, d.get_string_from_utf8()]))
	t.alocar("127.0.0.1", porta, "teste", "segredo")
	await _esperar(func(): return st["pronto"] or st["falhou"] != "", 5.0, t)
	ok(st["pronto"] and t.relay_ip == "127.0.0.1" and t.relay_porta > 0, "endereço público: %s:%d (mapeado %s)" % [t.relay_ip, t.relay_porta, t.ip_mapeado])
	# amigo: soquete comum
	var amigo := PacketPeerUDP.new()
	amigo.bind(0, "127.0.0.1")
	amigo.set_dest_address(t.relay_ip, t.relay_porta)
	amigo.put_packet("antes da permissão".to_utf8_buffer())
	await _esperar(func(): return false, 0.4, t)
	ok(st["rec"].is_empty(), "sem permissão o retransmissor descarta")
	t.permitir("127.0.0.1")
	await _esperar(func(): return false, 0.4, t)
	for i in 3:
		amigo.put_packet(("amigo %d" % i).to_utf8_buffer())
	await _esperar(func(): return st["rec"].size() >= 3, 3.0, t)
	ok(st["rec"].size() == 3 and st["rec"][2][2] == "amigo 2", "amigo -> host: %d pacotes" % st["rec"].size())
	var de: Array = st["rec"][0] if not st["rec"].is_empty() else ["", 0]
	var chegou: Array = []
	for i in 6:
		t.enviar(de[0], de[1], ("host %d" % i).to_utf8_buffer())
		await _esperar(func(): return false, 0.15, t)
		while amigo.get_available_packet_count() > 0:
			chegou.append(amigo.get_packet().get_string_from_utf8())
	ok(chegou.size() == 6 and chegou[5] == "host 5", "host -> amigo: %d pacotes (%s)" % [chegou.size(), str(chegou)])
	ok(t._canais.get("%s:%d" % [de[0], de[1]], 0) >= 0x4000, "canal ligado (ChannelData, cabeçalho de 4 bytes)")
	# canal nos dois sentidos depois de ligado
	amigo.put_packet("pelo canal".to_utf8_buffer())
	await _esperar(func(): return st["rec"].size() >= 4, 2.0, t)
	ok(st["rec"].size() >= 4 and st["rec"][3][2] == "pelo canal", "amigo -> host pelo canal")
	# renovação: o retransmissor de mentira responde 438 (nonce velho) na 1ª e o cliente repete com o novo
	var nonce_antes: String = t.nonce.get_string_from_utf8()
	t._t_renovar = 0.0
	await _esperar(func(): return t.nonce.get_string_from_utf8() != nonce_antes and t._pendentes.is_empty(), 4.0, t)
	ok(t.nonce.get_string_from_utf8() == "nonce-2" and t._pendentes.is_empty(), "renovação com nonce novo (438)")
	t.enviar(de[0], de[1], "depois da renovação".to_utf8_buffer())
	await _esperar(func(): return amigo.get_available_packet_count() > 0, 2.0, t)
	ok(amigo.get_available_packet_count() > 0 and amigo.get_packet().get_string_from_utf8() == "depois da renovação", "continua passando depois da renovação")
	# STUN: o amigo descobre o próprio IP (pela porta que o ENet vai usar)
	var meu_ip: String = Turn.ip_publico("127.0.0.1", porta, 45123)
	ok(meu_ip == "127.0.0.1", "STUN: meu IP visto pelo retransmissor = %s" % meu_ip)
	t.fechar()
	# senha errada: desiste e avisa
	var t2 = Turn.new()
	var st2 := {"falhou": ""}
	t2.falhou.connect(func(m): st2["falhou"] = m)
	t2.alocar("127.0.0.1", porta, "teste", "errada")
	await _esperar(func(): return st2["falhou"] != "", 6.0, t2)
	ok(st2["falhou"].contains("401"), "senha errada: avisa (%s)" % st2["falhou"])
	print("falhas: ", falhas)
	quit()
