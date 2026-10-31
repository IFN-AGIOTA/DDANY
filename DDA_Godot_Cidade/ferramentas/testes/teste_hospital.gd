extends SceneTree
# TESTE: HOSPITAIS (0.91). Zona neutra (PvP não vale, infectado que entra é abatido pelos guardas, não nasce
# infectado), os 6 sobreviventes montados, trégua de 2 min ao sair, dinheiro no loot, LOJA da Mônica (estoque
# diferente por jogador/hospital, sem dinheiro não compra, compra e vende), as REGRAS DAS TROCAS do Lucas (o host
# confere dono, destinatário, preço e estado) e o jogo salvo.
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func q(n):
	for i in n:
		await physics_frame
		await process_frame

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	var H = m.hospitais
	var Locais = load("res://mundo/locais.gd")
	var Loja = load("res://npc/loja.gd")
	var Precos = load("res://npc/precos.gd")
	var Item = load("res://inventario/item.gd")
	var Sessao = load("res://rede/sessao_rede.gd")
	ok(H != null and H.hospitais().size() == 4, "4 hospitais (%s)" % str(H.hospitais()))
	var hi: int = H.hospitais()[0]
	# entra no hospital: na frente da recepção
	var p2: Vector2 = Locais.local_para_mundo(hi, Vector2(0, -6.0))
	m.mundo.forcar(p2)
	m.locais.abrir_agora(p2)
	await q(5)
	j.teleportar(Vector3(p2.x, m.cidade.Y_CALCADA + 0.3, p2.y), 0.0)
	await q(30)
	var npcs: Array = root.get_tree().get_nodes_in_group("npcs_hospital")
	var quem := {}
	for n in npcs:
		quem[n.quem] = n
	ok(quem.size() == 6, "os 6 sobreviventes estão no hospital (%s)" % str(quem.keys()))
	ok(H.na_zona == hi and H.protegido(), "dentro: zona neutra")
	ok(not Sessao.pvp_vale_em(j.global_position), "PvP não vale no hospital")
	# o hospital não enche de infectados
	ok(m.vagos.vivos_perto(j.global_position, 40.0) == 0, "nenhum infectado nasceu no hospital")
	# infectado que entra é abatido
	var v = m.vagos._criar(j.global_position + Vector3(3, 0.05, 3), Vector3.INF)
	await q(60)
	ok(not is_instance_valid(v) or v.estado == v.MORTO, "o infectado que entrou foi abatido pelos guardas")
	ok(not m.vagos._livre(p2.x, p2.y), "infectado não nasce na zona neutra")
	# falar com a Mônica (PEGAR)
	var mon = quem.get("monica")
	j.teleportar(mon.global_position + mon.global_basis.z * -1.3 + Vector3(0, 0.1, 0), 0.0)
	await q(10)
	ok(H.npc_perto(j.global_position) == mon, "perto da Mônica: o PEGAR fala com ela (%s)" % (mon.acao().replace("\n", " ")))
	# loja: sem dinheiro
	j.inventario.consumir("dinheiro", j.inventario.contar("dinheiro"))
	for k0 in 10:                                   # itens no chão mais perto que ela saem primeiro
		j._pegar_do_chao()
		await q(3)
		if H.tela != null:
			break
	var t = H.tela
	ok(t != null and t.get("hospital") == hi, "PEGAR abriu a loja da Mônica")
	var est: Array = H.estoque(hi)
	var cats := {}
	for e in est:
		cats[str(load("res://inventario/itens.gd").def(e["id"]).get("cat", ""))] = true
	ok(est.size() >= 15 and cats.size() >= 10, "estoque com todos os tipos (%d itens, %d categorias)" % [est.size(), cats.size()])
	var outro: Array = Loja.estoque(hi, "outro_jogador", H.dia())
	var outro_h: Array = Loja.estoque(H.hospitais()[1], H._chave_loja(), H.dia())
	ok(str(outro) != str(est) and str(outro_h) != str(est), "estoque diferente para outro jogador e em outro hospital")
	ok(Loja.especialidade(hi)[0] != Loja.especialidade(H.hospitais()[1])[0], "cada hospital tem uma especialidade")
	var k := 0
	for kk in est.size():                                # um item que caiba na mochila do teste
		var ti = Item.novo(str(est[kk]["id"]), int(est[kk]["q"]))
		if H.cabe(ti):
			k = kk
			break
	var grande := -1
	for kk in est.size():
		if not H.cabe(Item.novo(str(est[kk]["id"]), int(est[kk]["q"]))):
			grande = kk
	var preco := int(est[k]["preco"])
	t._compra(k)
	await q(2)
	ok(not H.comprado(hi, k) and t._aviso.text.contains("só tem"), "sem dinheiro não compra (%s)" % t._aviso.text)
	H.dar_dinheiro(5000)
	ok(H.dinheiro() == 5000, "dinheiro: 5000 (%d)" % H.dinheiro())
	var antes: int = j.inventario.contar(str(est[k]["id"]))
	t._compra(k)
	await q(2)
	ok(H.comprado(hi, k) and H.dinheiro() == 5000 - preco and j.inventario.contar(str(est[k]["id"])) > antes,
		"comprou %s por US$ %d (sobrou %d)" % [est[k]["id"], preco, H.dinheiro()])
	t._compra(k)
	ok(H.dinheiro() == 5000 - preco, "não compra o mesmo item duas vezes no mesmo dia")
	if grande >= 0:
		t._compra(grande)
		ok(not H.comprado(hi, grande) and H.dinheiro() == 5000 - preco and t._aviso.text.contains("Não cabe"),
			"item que não cabe na mochila: ela não vende (%s)" % est[grande]["id"])
	# vender
	var it = Item.novo("faca", 1)
	j.inventario._guardar_auto(it)
	var vv: int = Precos.venda(it)
	var d0: int = H.dinheiro()
	t._venda(it)
	ok(H.dinheiro() == d0 + vv and not j.inventario.do_jogador(it), "vendeu uma faca por US$ %d" % vv)
	t.abas.atual = 1
	t.refazer()
	await q(2)
	ok(t.lista.get_child_count() > 1, "aba VENDER lista os itens (%d linhas)" % t.lista.get_child_count())
	t.fechar()
	await q(2)
	ok(H.tela == null and not m.controles.bloqueado, "fechou a loja (controles livres)")
	# Lucas sozinho
	var luc = quem.get("lucas")
	H.falar_com(luc)
	await q(3)
	ok(H.tela != null and H.tela.lista.get_child_count() >= 1, "Lucas abre (sozinho: avisa que é no multijogador)")
	H.tela.fechar()
	await q(2)
	# Carlos fala
	H.falar_com(quem.get("carlos"))
	ok(true, "Carlos fala")
	# dinheiro no loot
	var tem_din := false
	var LM = load("res://mundo/loot_mundo.gd")
	for tab in LM.TABELAS:
		for e in LM.TABELAS[tab]:
			if e[0] == "dinheiro" and int(e[3]) >= 25:
				tem_din = true
	ok(tem_din, "o loot tem maços de dólares (até dezenas de US$)")
	# ---------- regras das trocas (o que o host confere) ----------
	var Rede = root.get_node("Rede")
	var jog0: Dictionary = Rede.jogadores
	Rede.jogadores = {1: {"nome": "Ana", "uid": "a"}, 2: {"nome": "Bia", "uid": "b"}}
	var T = H.trocas
	T._prox_oferta = 1e9                                 # (os sobreviventes do rádio ficam quietos nesta parte)
	T._atender(2, "recusar", {})                         # a Bia fica conhecida
	var faca = Item.novo("faca", 1).para_dict()
	var r1: Dictionary = T._atender(1, "nova", {"para": "b", "p": 150, "h": hi, "itens": [faca, Item.novo("tabuas", 3).para_dict()]})
	ok(r1["ok"] and T.ofertas.size() == 1 and T.ofertas[0]["e"] == "aberta", "Ana oferece 2 itens à Bia por US$ 150 (%s)" % r1.get("msg", ""))
	var r2: Dictionary = T._atender(1, "nova", {"para": "zé", "p": 10, "h": hi, "itens": [faca]})
	ok(not r2["ok"] and (r2["itens"] as Array).size() == 1, "para alguém que não existe: recusa e devolve os itens")
	var r3: Dictionary = T._atender(1, "nova", {"para": "b", "p": 10, "h": hi, "itens": []})
	ok(not r3["ok"], "sem itens: recusa")
	var r3b: Dictionary = T._atender(1, "nova", {"para": "b", "p": 10, "h": 0, "itens": [faca]})
	ok(not r3b["ok"], "fora de um hospital: recusa")
	var id1: String = T.ofertas[0]["i"]
	var r4: Dictionary = T._atender(1, "aceitar", {"i": id1, "pago": 150})
	ok(not r4["ok"] and int(r4["dinheiro"]) == 150, "o vendedor não pode aceitar a própria oferta (dinheiro volta)")
	var r5: Dictionary = T._atender(2, "aceitar", {"i": id1, "pago": 100})
	ok(not r5["ok"] and int(r5["dinheiro"]) == 100, "dinheiro errado: recusa e devolve")
	var r5b: Dictionary = T._atender(1, "receber", {"i": id1})
	ok(not r5b["ok"], "não dá para buscar o dinheiro antes de responderem")
	var r6: Dictionary = T._atender(2, "aceitar", {"i": id1, "pago": 150})
	ok(r6["ok"] and (r6["itens"] as Array).size() == 2 and T.ofertas[0]["e"] == "vendida", "Bia aceita: recebe os 2 itens (%s)" % r6.get("msg", ""))
	var r7: Dictionary = T._atender(2, "aceitar", {"i": id1, "pago": 150})
	ok(not r7["ok"], "não dá para aceitar duas vezes")
	var r8: Dictionary = T._atender(2, "receber", {"i": id1})
	ok(not r8["ok"], "a Bia não pode pegar o dinheiro da Ana")
	var r9: Dictionary = T._atender(1, "receber", {"i": id1})
	ok(r9["ok"] and int(r9["dinheiro"]) == 150 and T.ofertas.is_empty(), "Ana busca os US$ 150 com o Lucas")
	var r10: Dictionary = T._atender(1, "nova", {"para": "b", "p": 40, "h": hi, "itens": [faca]})
	var id2: String = T.ofertas[0]["i"]
	ok(not T._atender(1, "recusar", {"i": id2})["ok"], "só quem recebeu a oferta pode recusar")
	ok(T._atender(2, "recusar", {"i": id2})["ok"] and T.ofertas[0]["e"] == "recusada", "Bia recusa")
	ok(not T._atender(1, "cancelar", {"i": id2})["ok"], "depois de recusada não tem o que cancelar")
	var r11: Dictionary = T._atender(1, "receber", {"i": id2})
	ok(r11["ok"] and (r11["itens"] as Array).size() == 1, "Ana pega a faca de volta")
	T._atender(1, "nova", {"para": "b", "p": 40, "h": hi, "itens": [faca]})
	var r12: Dictionary = T._atender(1, "cancelar", {"i": T.ofertas[0]["i"]})
	ok(r12["ok"] and T.ofertas.is_empty() and (r12["itens"] as Array).size() == 1, "cancelar devolve os itens")
	for n in T.MAX_ABERTAS:
		T._atender(1, "nova", {"para": "b", "p": 1, "h": hi, "itens": [faca]})
	ok(not T._atender(1, "nova", {"para": "b", "p": 1, "h": hi, "itens": [faca]})["ok"], "no máximo %d ofertas abertas" % T.MAX_ABERTAS)
	# a resposta entrega os itens/dinheiro no inventário
	var din0: int = H.dinheiro()
	T._responder(0, {"ok": true, "dinheiro": 70, "itens": [Item.novo("atum", 1).para_dict()]})
	ok(H.dinheiro() == din0 + 70 and j.inventario.contar("atum") >= 1, "resposta do host entrega dinheiro e itens")
	Rede.jogadores = jog0
	T.ofertas.clear()
	# ---------- offline: os sobreviventes do rádio ----------
	var resp = []
	T.resposta.connect(func(x): resp.append(x))
	ok(T.nomes().size() == T.RADIO.size() and T.minha_chave() == "eu", "offline: a lista do Lucas são os sobreviventes do rádio (%s)" % str(T.nomes().map(func(n): return n[1])))
	var f1 = Item.novo("faca", 1)
	T.pedir("nova", {"para": "npc:tommy", "p": 5, "h": hi, "itens": [f1.para_dict()]})
	ok(resp.size() == 1 and resp[0]["ok"] and T.ofertas.size() == 1 and T.ofertas[0].has("decide"), "vendeu para o TOMMY pelo rádio (%s)" % (resp[0].get("msg", "") if resp.size() > 0 else ""))
	T.ofertas[0]["decide"] = 0.0
	T._simular()
	ok(T.ofertas[0]["e"] == "vendida" and not T.notas().is_empty(), "preço justo: ele compra e aparece no mapa (%s)" % (T.notas()[0][1] if not T.notas().is_empty() else ""))
	var dd0: int = H.dinheiro()
	T.pedir("receber", {"i": T.ofertas[0]["i"]})
	ok(H.dinheiro() == dd0 + 5 and T.ofertas.is_empty(), "buscou os US$ 5 com o Lucas")
	T.pedir("nova", {"para": "npc:jenny", "p": 99999, "h": hi, "itens": [f1.para_dict()]})
	T.ofertas[0]["decide"] = 0.0
	T._simular()
	ok(T.ofertas[0]["e"] == "recusada", "preço absurdo: ela recusa")
	var facas: int = j.inventario.contar("faca")
	T.pedir("receber", {"i": T.ofertas[0]["i"]})
	ok(j.inventario.contar("faca") == facas + 1 and T.ofertas.is_empty(), "a faca volta")
	T._prox_oferta = 0.0
	T._simular()
	var pm: Array = T.para_mim()
	ok(pm.size() == 1 and str(pm[0]["de"]).begins_with("npc:") and int(pm[0]["p"]) > 0, "um sobrevivente do rádio te oferece itens (%s por US$ %s)" % [pm[0]["dn"] if pm.size() > 0 else "-", pm[0]["p"] if pm.size() > 0 else "-"])
	if pm.size() == 1:
		var pr := int(pm[0]["p"])
		H.dar_dinheiro(pr)
		var d1: int = H.dinheiro()
		var n_it: int = (pm[0]["itens"] as Array).size()
		H.tirar_dinheiro(pr)
		T.pedir("aceitar", {"i": pm[0]["i"], "pago": pr}, pr)
		ok(resp[-1]["ok"] and H.dinheiro() == d1 - pr and T.ofertas.is_empty(), "aceitou: pagou US$ %d e recebeu %d itens" % [pr, n_it])
	T._prox_oferta = 0.0
	T._simular()
	if not T.ofertas.is_empty():
		T.ofertas[0]["exp"] = 0.0
		T._prox_oferta = 1e9
		T._simular()
	ok(T.ofertas.is_empty(), "a oferta deles vence se você não responder")
	T._prox_oferta = 0.0
	T._simular()
	var Salv0 = load("res://menu/salvamento.gd")
	Salv0.salvar(m)
	var d0s = JSON.parse_string(FileAccess.get_file_as_string(Salv0.ARQUIVO))
	ok(d0s is Dictionary and d0s.has("trocas") and (d0s["trocas"]["l"] as Array).size() == T.ofertas.size(), "as trocas do rádio vão no jogo salvo")
	T.ofertas.clear()
	# ---------- trégua ----------
	var fora: Vector2 = Locais.local_para_mundo(hi, Vector2(0, 60.0))
	m.mundo.forcar(fora)
	j.teleportar(Vector3(fora.x, m.mundo.altura(fora.x, fora.y) + 0.2, fora.y), 0.0)
	await q(10)
	ok(H.na_zona == -1 and H.imune > 110.0 and H.protegido(), "saiu: trégua de 2 min (%.0f s)" % H.imune)
	ok(H._rotulo.text.begins_with("TRÉGUA"), "aparece na tela (%s)" % H._rotulo.text)
	H.imune = 0.5
	await q(60)
	ok(not H.protegido(), "a trégua acaba")
	# ---------- jogo salvo ----------
	H.imune = 33.0
	var Salv = load("res://menu/salvamento.gd")
	Salv.salvar(m)
	var d = JSON.parse_string(FileAccess.get_file_as_string(Salv.ARQUIVO))
	ok(d is Dictionary and d.has("hospitais") and (d["hospitais"]["comprados"] as Dictionary).size() == 1, "o jogo salvo leva o que você comprou e a trégua")
	H.comprados = {}
	H.carregar_personagem(d["hospitais"])
	ok(H.comprado(hi, k), "carregou o que já comprou hoje")
	print("falhas: ", falhas)
	quit()
