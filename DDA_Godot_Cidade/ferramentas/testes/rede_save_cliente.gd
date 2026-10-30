extends SceneTree
# TESTE DO SALVAR EM REDE (0.77), AMIGO · FASE=1: mexe no personagem e salva · FASE=2: confere que voltou e que
# recebeu do host a porta mexida e o item pego.
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func _r():
	for i in 30: await process_frame
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	await create_timer(6.0).timeout
	root.get_node("Rede").entrar("127.0.0.1", "Cli")
	var t := 0.0
	while not root.get_node("Rede").partida_comecou and t < 60.0:
		await create_timer(0.5).timeout
		t += 0.5
	m._jogar()
	while m.jogador == null: await process_frame
	var j = m.jogador
	if OS.get_environment("FASE") == "1":
		j.sobrevivencia.fome = 44.0
		j.teleportar(j.global_position + Vector3(-11.0, 0.2, 6.0), 0.0)     # 1.03: a posição volta na fase 2
		await create_timer(2.0).timeout
		var it = load("res://inventario/item.gd").novo("galao")
		for g in j.inventario.grades_do_jogador():
			var v: Vector3i = g.achar_vaga(it)
			if v.x >= 0:
				g.colocar(it, v.x, v.y, v.z == 1)
				break
		await create_timer(1.0).timeout
		m.salvar_jogo()
		print("CLI1: salvo · ligado ", root.get_node("Rede").ligado, " · jogo ", m.jogo != null, " · mundo ", str(root.get_node("Rede").mundo.get("mundo_nome", "")),
			" · direto ", load("res://menu/salvamento.gd").salvar_rede(m), " · em ", j.global_position.snapped(Vector3.ONE * 0.1))
	else:
		var MR = load("res://menu/mundos_rede.gd")
		var pos: Array = MR.ler(str(root.get_node("Rede").mundo.get("mundo_id", ""))).get("personagem", {}).get("pos", [])
		await create_timer(4.0).timeout
		var volta: bool = pos.size() >= 3 and j.global_position.distance_to(Vector3(pos[0], pos[1], pos[2])) < 1.5
		print("CLI2: posição volta ", volta, " · mundo ", str(root.get_node("Rede").mundo.get("mundo_nome", "")))
		print("CLI2: fome ", snappedf(j.sobrevivencia.fome, 0.1), " · galão ", j.inventario.contar("galao"), " · porta do host ",
			m.loot_mundo.portas.has("p1:1"), " · pego do host ", m.loot_mundo.pegos.has("teste:7"), " · em ", j.global_position.snapped(Vector3.ONE * 0.1))
	await create_timer(3.0).timeout
	quit()
