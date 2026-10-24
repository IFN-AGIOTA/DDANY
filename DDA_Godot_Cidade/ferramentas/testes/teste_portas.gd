extends SceneTree
# TESTE DAS PORTAS (0.73): abre um prédio, ABRIR/FECHAR pelo PEGAR, botão com o texto certo, BARRICAR com tábuas,
# barricada não abre, pé de cabra tira a tábua, estado salvo, infectado do outro lado arromba, prédio reaberto
# continua com a porta quebrada. FOTO=<prefixo> salva imagens.
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
var olhar_para = null
func foto(nome: String) -> void:
	var p := OS.get_environment("FOTO")
	if p == "": return
	if olhar_para != null:
		var j = current_scene.jogador
		var d: Vector3 = olhar_para.global_position - j.global_position
		j.cam_yaw = atan2(-d.x, -d.z)
		j.rotation.y = j.cam_yaw
		j.cam_pit = 0.15
		await q(15)
	await q(3)
	root.get_texture().get_image().save_png(p + "_" + nome + ".png")
func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.clima.definir_hora(12.0)
	m.clima.set("parado", true)
	m.vagos.ativo = false
	var j = m.jogador
	var inv = j.inventario
	var P = load("res://mundo/porta.gd")
	var I = load("res://inventario/item.gd")
	# prédio com entrada mais perto do nascimento
	var melhor := -1
	var md := 1e9
	for i in m.cidade.predio_info.size():
		var inf: Dictionary = m.cidade.predio_info[i]
		if not inf.get("entra", false) or inf.get("ruina", false): continue
		var d := Vector2(inf["x"], inf["z"]).distance_to(m.SPAWN)
		if d < md and d > 60.0:
			md = d
			melhor = i
	var inf: Dictionary = m.cidade.predio_info[melhor]
	var c := Vector3(inf["x"], 0.6, inf["z"])
	j.teleportar(c + Vector3(0, 0.1, 0), 0.0)
	m.mundo.forcar(Vector2(c.x, c.z))
	m.interiores.abrir_agora(Vector2(c.x, c.z))
	await q(30)
	var minhas := []
	for k in P.todas:
		if str(k).begins_with("p%d:" % melhor): minhas.append(P.todas[k])
	var nf := 0
	var nq := 0
	for pt in minhas:
		if pt.fechada(): nf += 1
		if pt.quebrada: nq += 1
	print("prédio %d: %d portas (%d fechadas, %d quebradas)" % [melhor, minhas.size(), nf, nq])
	ok(minhas.size() > 0, "o prédio tem portas")
	# uma porta de dentro (não dupla) que não está quebrada
	var pt = null
	for x in minhas:
		if not x.quebrada and not x.dupla: pt = x
	if pt == null:
		for x in minhas:
			if not x.quebrada: pt = x
	ok(pt != null, "achou uma porta inteira")
	if pt.aberta: pt.definir_aberta(false)
	await q(40)
	# jogador 1 m na frente dela
	var lado: Vector3 = pt.global_transform * Vector3(0, 0, 1.0)
	j.teleportar(Vector3(lado.x, pt.global_position.y + 0.05, lado.z), 0.0)
	await q(20)
	ok(P.perto(j.global_position) == pt, "porta é a mais perto")
	olhar_para = pt
	m.tela_inventario._t_scan = 0.0
	await q(3)
	print("botão: ", m.controles.textos.get("PEGAR"), " oculto ", m.controles.ocultos.get("PEGAR"))
	ok(not m.controles.ocultos.get("PEGAR", true) and str(m.controles.textos.get("PEGAR")).begins_with("ABRIR"), "botão PEGAR = ABRIR PORTA")
	j._pegar_do_chao()
	await q(40)
	ok(pt.aberta and pt._dobradicas[0].rotation.y > 1.5, "abriu (giro %.2f)" % pt._dobradicas[0].rotation.y)
	await foto("aberta")
	j._pegar_do_chao()
	await q(40)
	ok(not pt.aberta and absf(pt._dobradicas[0].rotation.y) < 0.01, "fechou")
	# barricar
	var tb = I.novo("tabuas", 2)
	var g = inv.grades_do_jogador()[0]
	for gg in inv.grades_do_jogador():
		var v: Vector3i = gg.achar_vaga(tb)
		if v.x >= 0:
			gg.colocar(tb, v.x, v.y, v.z == 1)
			break
	ok(inv.contar("tabuas") == 2, "tem 2 tábuas")
	inv.usar(tb)
	await q(5)
	ok(pt.tabuas == 1 and inv.contar("tabuas") == 1, "pregou 1 tábua (%d) e gastou (%d)" % [pt.tabuas, inv.contar("tabuas")])
	inv.usar(tb)
	await q(5)
	ok(pt.tabuas == 2 and inv.contar("tabuas") == 0, "pregou a 2ª")
	await foto("barricada")
	j._pegar_do_chao()
	await q(10)
	ok(not pt.aberta and pt.tabuas == 2, "barricada não abre e sem ferramenta não tira")
	# ferramenta
	var pc = I.novo("pe_de_cabra")
	for gg in inv.grades_do_jogador():
		var v: Vector3i = gg.achar_vaga(pc)
		if v.x >= 0:
			gg.colocar(pc, v.x, v.y, v.z == 1)
			break
	if inv.contar("pe_de_cabra") == 0:
		inv.slots["ombro"] = pc
		pc.slot = "ombro"
	j._pegar_do_chao()
	await q(5)
	ok(pt.tabuas == 1 and inv.contar("tabuas") == 1, "pé de cabra tirou 1 tábua (volta para o inventário)")
	# estado guardado
	ok(m.loot_mundo.portas.get(pt.id, []).size() >= 3 and int(m.loot_mundo.portas[pt.id][1]) == 1, "estado guardado no loot")
	var sv: Dictionary = m.loot_mundo.salvar()
	ok(sv.has("portas") and sv["portas"].has(pt.id), "vai no jogo salvo")
	# infectado do outro lado arromba
	m.vagos.ativo = true
	var outro: Vector3 = pt.global_transform * Vector3(0, 0, -2.2)
	m.vagos._criar(Vector3(outro.x, pt.global_position.y + 0.05, outro.z), Vector3.INF)
	var v = m.vagos.vivos.back()
	await q(5)
	var t0 := Time.get_ticks_msec()
	while not pt.quebrada and Time.get_ticks_msec() - t0 < 60000:
		if is_instance_valid(v):
			v._alvo = j
			v._ultimo_visto = j.global_position
			v._t_sem_ver = 0.0
			v.perseguir()
		await q(10)
		if is_instance_valid(v) and (Time.get_ticks_msec() - t0) % 3000 < 200:
			print("  inf estado %d fis %s pos %s porta %.2f preso %d tab %d vida %.0f" % [v.estado, v._fisica, v.global_position.snapped(Vector3.ONE*0.1), Vector2(v.global_position.x - pt.global_position.x, v.global_position.z - pt.global_position.z).length(), v._n_preso, pt.tabuas, pt.vida])
	print("tábuas %d vida %.0f quebrada %s" % [pt.tabuas, pt.vida, pt.quebrada])
	ok(pt.quebrada, "o infectado arrombou a porta barricada")
	await foto("quebrada")
	# fecha e abre o prédio: o estado volta
	m.vagos.ativo = false
	var id: String = pt.id
	m.interiores.fechar(melhor)
	await q(5)
	m.interiores.abrir_agora(Vector2(c.x, c.z))
	await q(10)
	var pt2 = P.todas.get(id)
	ok(pt2 != null and pt2.quebrada, "reabriu o prédio: a porta continua quebrada")
	print("falhas: ", falhas)
	quit()
