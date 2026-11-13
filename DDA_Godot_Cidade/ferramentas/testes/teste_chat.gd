extends SceneTree
# TESTE: CHAT DE TEXTO e MODO DESENVOLVEDOR (1.09). Com o jogo de verdade (solo):
#   · Enter/CHAT abre, o personagem fica parado, a mensagem aparece com o nome e o chat fecha
#   · sem o modo ligado, "/dar" não faz nada ("comando desconhecido") e nada vira comando
#   · "INFINITYDEV" liga o modo (e não aparece como mensagem); "/" mostra TODOS os comandos; "/da" filtra; depois do
#     nome, as opções da parte seguinte ("/dar band" -> bandagem)
#   · comandos de verdade: /dar, /kit, /cartao, /dinheiro, /curar, /deus, /hora, /clima, /tp (local e x z), /comboio,
#     /spawn (soldado), /matar, /infectados, /itens, /locais, /ajuda, /limpar, /devoff
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

var m
var ch

func _mandar(t: String) -> void:
	if not ch.aberto:
		ch.abrir()
	ch._campo.text = t
	ch._enviar()

func _tem(txt: String) -> bool:
	for l in ch._linhas:
		if String(l[0]).contains(txt):
			return true
	return false

func _r():
	await q(20)
	m = current_scene
	m._jogar()
	await q(60)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	m.vagos.diretor._t_horda = 9999.0
	ch = m.chat
	ok(ch != null and ch.dev != null and not ch.dev.ativo, "o chat existe no jogo solo e o modo desenvolvedor começa desligado")
	# ---- abrir pelo botão/tecla ----
	m.controles.chat_pedido.emit()
	await q(3)
	ok(ch.aberto and ch._campo.has_focus() and m.controles.bloqueado, "CHAT/Enter abre o campo (com o foco) e o personagem fica parado")
	ch._campo.text = "oi pessoal"
	ch._enviar()
	await q(3)
	ok(not ch.aberto and not m.controles.bloqueado and _tem("oi pessoal"), "a mensagem aparece na tela e o chat fecha")
	# ---- sem o modo: comando não funciona ----
	var bandagens0: int = j.inventario.contar("bandagem")
	_mandar("/dar bandagem 3")
	await q(2)
	ok(j.inventario.contar("bandagem") == bandagens0 and _tem("Comando desconhecido"), "sem o modo ligado, /dar não faz nada")
	# ---- liga ----
	var n_linhas: int = ch._linhas.size()
	await q(50)                                   # (espera passar o tempo entre mensagens)
	_mandar("INFINITYDEV")
	await q(2)
	ok(ch.dev.ativo and not _tem("INFINITYDEV") and _tem("MODO DESENVOLVEDOR LIGADO"), "INFINITYDEV liga o modo (e não vira mensagem para ninguém)")
	# ---- a lista ----
	ch.abrir("/")
	await q(3)
	ok(ch._painel_sug.visible and ch._sug_cmds.size() == mini(12, ch.dev.COMANDOS.size()) and ch.dev.sugestoes("/").size() == ch.dev.COMANDOS.size(),
		"\"/\" mostra a lista com todos os comandos (%d)" % ch.dev.sugestoes("/").size())
	ch._preencher("/da")
	await q(2)
	ok(ch._sug_cmds.size() == 1 and ch._sug_cmds[0] == "/dar ", "\"/da\" filtra: só /dar")
	ch._preencher("/dar band")
	await q(2)
	ok(ch._sug_cmds.has("/dar bandagem "), "depois do nome, as opções da parte seguinte (\"/dar band\" -> bandagem)")
	ch.fechar()
	# ---- comandos ----
	_mandar("/dar bandagem 3")
	await q(2)
	ok(j.inventario.contar("bandagem") == bandagens0 + 3, "/dar bandagem 3")
	_mandar("/kit medico")
	_mandar("/cartao 2")
	_mandar("/dinheiro 250")
	await q(2)
	ok(j.inventario.contar("kit_medico") >= 1 and j.inventario.contar("cartao_bunker_2") >= 1 and j.inventario.contar("dinheiro") >= 250, "/kit medico, /cartao 2 e /dinheiro 250")
	j.sobrevivencia.fome = 10.0
	j.sobrevivencia.perna_quebrada = true
	_mandar("/curar")
	await q(2)
	ok(j.sobrevivencia.fome >= 99.0 and not j.sobrevivencia.perna_quebrada, "/curar")
	var deus0: bool = j.sobrevivencia.imortal
	_mandar("/deus")
	ok(j.sobrevivencia.imortal != deus0, "/deus liga/desliga")
	j.sobrevivencia.imortal = true
	_mandar("/hora 6")
	_mandar("/clima chuva")
	await q(2)
	ok(absf(m.clima.hora - 6.0) < 0.2 and m.clima.estado == "chuva", "/hora 6 e /clima chuva")
	var L = load("res://mundo/locais.gd")
	_mandar("/tp igreja 2")
	await q(20)
	var ig := -1
	var k := 0
	for i in L.LOCAIS.size():
		if L.LOCAIS[i][0] == "igreja":
			k += 1
			if k == 2:
				ig = i
	var pj: Vector3 = j.global_position
	ok(Vector2(pj.x, pj.z).distance_to(Vector2(L.LOCAIS[ig][1], L.LOCAIS[ig][2])) < 60.0, "/tp igreja 2 (está a %d m dela)" % int(Vector2(pj.x, pj.z).distance_to(Vector2(L.LOCAIS[ig][1], L.LOCAIS[ig][2]))))
	_mandar("/tp 1000 -500")
	await q(20)
	ok(Vector2(j.global_position.x, j.global_position.z).distance_to(Vector2(1000, -500)) < 2.0, "/tp 1000 -500")
	_mandar("/comboio 3")
	await q(20)
	var c3: Vector3 = m.cidade.abandono.centros_comboio[2][0]
	ok(Vector2(j.global_position.x, j.global_position.z).distance_to(Vector2(c3.x, c3.z)) < 15.0, "/comboio 3")
	var vivos0: int = m.vagos.vivos.size()
	_mandar("/spawn 3 soldado")
	await q(10)
	var soldados := 0
	for v in m.vagos.vivos:
		if is_instance_valid(v) and v.soldado() and v.global_position.distance_to(j.global_position) < 20.0:
			soldados += 1
	ok(m.vagos.vivos.size() >= vivos0 + 3 and soldados >= 3, "/spawn 3 soldado (%d soldados perto)" % soldados)
	_mandar("/matar 30")
	await q(30)
	var perto := 0
	for v in m.vagos.vivos:
		if is_instance_valid(v) and v.global_position.distance_to(j.global_position) < 25.0:
			perto += 1
	ok(perto == 0, "/matar 30 (sobraram %d perto)" % perto)
	_mandar("/infectados off")
	ok(not m.vagos.ativo, "/infectados off")
	_mandar("/infectados on")
	_mandar("/itens bandag")
	ok(_tem("bandagem"), "/itens filtra")
	_mandar("/locais hangar")
	ok(_tem("hangar:"), "/locais hangar")
	_mandar("/ajuda dar")
	ok(_tem("/dar <item>"), "/ajuda dar")
	_mandar("/naoexiste")
	ok(_tem("Comando desconhecido: /naoexiste"), "comando que não existe avisa")
	ch.fechar()
	_mandar("/limpar")
	ok(ch._linhas.is_empty(), "/limpar")
	_mandar("/devoff")
	await q(2)
	ok(not ch.dev.ativo, "/devoff desliga")
	ch.fechar()
	print("falhas: ", falhas)
	quit()
