extends SceneTree
# TESTE DO SALVAR EM REDE (0.77), HOST · FASE=1: cria o mundo "Teste A" (1.03), mexe no personagem e no mundo e salva
# · FASE=2: abre outra sala escolhendo o "Teste A" e confere que o personagem (e onde ele estava) e o mundo voltaram
# (rodar.sh rede_save roda as duas fases com rede_save_cliente.gd).
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func _r():
	for i in 30: await process_frame
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	var fase := OS.get_environment("FASE")
	var S = load("res://menu/salvamento.gd")
	var MR = load("res://menu/mundos_rede.gd")
	var md: Dictionary = MR.criar("Teste A") if fase == "1" else MR.por_nome("Teste A")
	print("HOST%s: mundo \"%s\" · %d mundo(s) na lista" % [fase, md.get("nome", "?"), MR.lista().size()])
	root.get_node("Rede").criar_partida("Host", int(md["semente"]), str(md["id"]), str(md["nome"]))
	await create_timer(1.0).timeout
	root.get_node("Rede").comecar_partida()
	m._jogar()
	while m.jogador == null: await process_frame
	m.vagos.ativo = false
	var j = m.jogador
	var lm = m.loot_mundo
	if fase == "1":
		print("HOST1: semente ", lm.semente)
		j.sobrevivencia.fome = 33.0
		var it = load("res://inventario/item.gd").novo("tabuas", 2)
		for g in j.inventario.grades_do_jogador():
			var v: Vector3i = g.achar_vaga(it)
			if v.x >= 0:
				g.colocar(it, v.x, v.y, v.z == 1)
				break
		lm.mudar_porta("p1:1", [true, 0, false, 1.0])
		await create_timer(2.0).timeout
		j.teleportar(j.global_position + Vector3(14.0, 0.2, 9.0), 0.0)      # anda um pouco (a posição volta na fase 2)
		lm.pegos["teste:7"] = true
		var t := 0.0
		while t < 120.0 and (m.sessao_rede == null or m.sessao_rede.remotos.is_empty() or not m.sessao_rede.remotos.values()[0].visible):
			await create_timer(0.5).timeout
			t += 0.5
		await create_timer(8.0).timeout                  # o amigo entra e salva
		m.salvar_jogo()
		print("HOST1: salvo em ", j.global_position.snapped(Vector3.ONE * 0.1))
	else:
		var pos: Array = MR.ler(str(md["id"])).get("personagem", {}).get("pos", [])
		var volta: bool = pos.size() >= 3 and j.global_position.distance_to(Vector3(pos[0], pos[1], pos[2])) < 1.0
		print("HOST2: posição volta ", volta)
		print("HOST2: semente ", lm.semente, " · fome ", snappedf(j.sobrevivencia.fome, 0.1), " · tábuas ", j.inventario.contar("tabuas"),
			" · porta ", lm.portas.has("p1:1"), " · pego ", lm.pegos.has("teste:7"), " · em ", j.global_position.snapped(Vector3.ONE * 0.1))
		var t2 := 0.0
		while t2 < 120.0 and (m.sessao_rede == null or m.sessao_rede.remotos.is_empty() or not m.sessao_rede.remotos.values()[0].visible):
			await create_timer(0.5).timeout
			t2 += 0.5
		await create_timer(10.0).timeout
	quit()
