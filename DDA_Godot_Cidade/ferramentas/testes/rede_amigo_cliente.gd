extends SceneTree
# TESTE DE REDE (0.74), parte do AMIGO: entra na partida do host (127.0.0.1), vai para um prédio a ~600 m e conta
# as cópias de infectados que o host manda perto dele.
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
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
	# prédio com entrada a ~600 m do nascimento
	var melhor := -1
	var md := 1e9
	for i in m.cidade.predio_info.size():
		var inf: Dictionary = m.cidade.predio_info[i]
		if not inf.get("entra", false) or inf.get("ruina", false): continue
		var d := absf(Vector2(inf["x"], inf["z"]).distance_to(m.SPAWN) - 600.0)
		if d < md:
			md = d
			melhor = i
	var inf: Dictionary = m.cidade.predio_info[melhor]
	var w := Vector2(inf["x"], inf["z"])
	await create_timer(1.0).timeout
	m.mundo.forcar(w)
	m.interiores.abrir_agora(w)
	j.teleportar(Vector3(w.x, 0.6, w.y), 0.0)
	print("CLI: dentro do prédio ", melhor, " em ", w)
	await create_timer(9.0).timeout
	var n := 0
	for k in m.vagos.por_id:
		var v = m.vagos.por_id[k]
		if is_instance_valid(v) and v.global_position.distance_to(j.global_position) < 40.0: n += 1
	print("CLI: cópias de infectados perto: ", n)
	await create_timer(6.0).timeout
	quit()
