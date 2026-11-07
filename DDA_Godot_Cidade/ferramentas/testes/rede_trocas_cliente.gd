extends SceneTree
# TESTE DE REDE DAS TROCAS DO LUCAS (0.91), parte do AMIGO: vai ao hospital, oferece uma faca e 3 tábuas ao host
# por US$ 120, espera vender (aviso + mapa), busca o dinheiro com o Lucas; depois oferece um atum, o host recusa e
# ele pega o atum de volta.
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func espera(cond: Callable, maxs: float) -> bool:
	var t := 0.0
	while t < maxs and not cond.call():
		await create_timer(0.25).timeout
		t += 0.25
	return cond.call()
func _r():
	for i in 30: await process_frame
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	await create_timer(8.0).timeout
	root.get_node("Rede").entrar("127.0.0.1", "Cli")
	var t := 0.0
	while not root.get_node("Rede").partida_comecou and t < 60.0:
		await create_timer(0.5).timeout
		t += 0.5
	m._jogar()
	while m.jogador == null: await process_frame
	var j = m.jogador
	j.sobrevivencia.imortal = true
	var H = m.hospitais
	var T = H.trocas
	var Item = load("res://inventario/item.gd")
	var Locais = load("res://mundo/locais.gd")
	var hi: int = H.hospitais()[0]
	var p2: Vector2 = Locais.local_para_mundo(hi, Vector2(1.5, -6.0))
	m.mundo.forcar(p2)
	m.locais.abrir_agora(p2)
	j.teleportar(Vector3(p2.x, m.cidade.Y_CALCADA + 0.3, p2.y), 0.0)
	await espera(func(): return T.nomes().size() > 0, 30.0)
	var host := ""
	for n in T.nomes():
		if str(n[1]) == "Host":
			host = n[0]
	print("CLI: nomes na lista do Lucas ", T.nomes().map(func(n): return n[1]), " · protegido ", H.protegido())
	var res = []
	T.resposta.connect(func(x): res.append(x))
	# 1ª oferta: faca + 3 tábuas por US$ 120
	var inv = j.inventario
	var faca = Item.novo("faca", 1)
	var tab = Item.novo("tabuas", 3)
	inv._guardar_auto(faca)
	inv._guardar_auto(tab)
	var dicts := [faca.para_dict(), tab.para_dict()]
	inv.retirar(faca)
	inv.retirar(tab)
	inv._depois()
	T.pedir("nova", {"para": host, "p": 120, "h": hi, "itens": dicts})
	await espera(func(): return res.size() >= 1, 10.0)
	print("CLI: oferta entregue ao Lucas ", res.size() > 0 and res[0]["ok"])
	var vendida := await espera(func(): return T.minhas().filter(func(o): return o["e"] == "vendida").size() > 0, 60.0)
	var notas: Array = T.notas()
	print("CLI: vendeu ", vendida, " · mapa: ", notas[0][1] if not notas.is_empty() else "nada")
	var din0: int = H.dinheiro()
	T.pedir("receber", {"i": T.minhas()[0]["i"]})
	await espera(func(): return res.size() >= 2, 10.0)
	print("CLI: buscou com o Lucas US$ %d" % (H.dinheiro() - din0))
	# 2ª oferta: um atum por US$ 50 (o host recusa)
	var atum = Item.novo("atum", 1)
	inv._guardar_auto(atum)
	var at0: int = inv.contar("atum")
	var da: Dictionary = atum.para_dict()
	inv.retirar(atum)
	inv._depois()
	T.pedir("nova", {"para": host, "p": 50, "h": hi, "itens": [da]})
	await espera(func(): return T.minhas().filter(func(o): return o["e"] == "recusada").size() > 0, 60.0)
	T.pedir("receber", {"i": T.minhas()[0]["i"]})
	await espera(func(): return res.size() >= 4, 10.0)
	print("CLI: recusaram e o atum voltou ", inv.contar("atum") == at0, " · ofertas minhas ", T.minhas().size())
	await create_timer(3.0).timeout
	quit()
