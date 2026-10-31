extends SceneTree
# TESTE DE REDE DAS TROCAS DO LUCAS (0.91), parte do HOST: fica no hospital, espera a oferta do amigo
# (rede_trocas_cliente.gd), confere que o PvP não vale lá, ACEITA a 1ª (paga e recebe os itens) e RECUSA a 2ª.
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func _r():
	for i in 30: await process_frame
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	root.get_node("Rede").criar_partida("Host", 77)
	await create_timer(1.0).timeout
	root.get_node("Rede").comecar_partida()
	m._jogar()
	while m.jogador == null: await process_frame
	m.vagos.ativo = false
	var j = m.jogador
	j.sobrevivencia.imortal = true
	var H = m.hospitais
	var T = H.trocas
	var Locais = load("res://mundo/locais.gd")
	var hi: int = H.hospitais()[0]
	var p2: Vector2 = Locais.local_para_mundo(hi, Vector2(0, -6.0))
	m.mundo.forcar(p2)
	m.locais.abrir_agora(p2)
	j.teleportar(Vector3(p2.x, m.cidade.Y_CALCADA + 0.3, p2.y), 0.0)
	H.dar_dinheiro(1000)
	var t := 0.0
	while t < 150.0 and T.para_mim().is_empty():
		await create_timer(0.5).timeout
		t += 0.5
	if T.para_mim().is_empty():
		print("HOST: nenhuma oferta chegou")
		quit()
		return
	var o: Dictionary = T.para_mim()[0]
	print("HOST: oferta de %s · %d itens · US$ %d · notas no mapa %d" % [o["dn"], (o["itens"] as Array).size(), int(o["p"]), T.notas().size()])
	var rid: int = m.sessao_rede.remotos.keys()[0]
	var r = m.sessao_rede.remotos[rid]
	print("HOST: amigo protegido (zona neutra) ", r.protegido, " · meu tiro nele vale ", m.sessao_rede.mandar_pvp(rid, 30.0, false, Vector3.FORWARD, false))
	var res = []
	T.resposta.connect(func(x): res.append(x))
	var din0: int = H.dinheiro()
	var facas0: int = j.inventario.contar("faca")
	H.tirar_dinheiro(int(o["p"]))
	T.pedir("aceitar", {"i": o["i"], "pago": int(o["p"])}, int(o["p"]))
	await create_timer(0.5).timeout
	print("HOST: comprou ", res.size() > 0 and res[0]["ok"], " · faca ", j.inventario.contar("faca") > facas0, " · tábuas ", j.inventario.contar("tabuas"), " · pagou ", din0 - H.dinheiro())
	t = 0.0
	while t < 60.0 and T.para_mim().is_empty():
		await create_timer(0.5).timeout
		t += 0.5
	if not T.para_mim().is_empty():
		T.pedir("recusar", {"i": T.para_mim()[0]["i"]})
		await create_timer(0.5).timeout
		print("HOST: recusou a 2ª ", res.size() > 1 and res[1]["ok"])
	await create_timer(15.0).timeout
	print("HOST: registro no fim: %d ofertas" % T.ofertas.size())
	quit()
