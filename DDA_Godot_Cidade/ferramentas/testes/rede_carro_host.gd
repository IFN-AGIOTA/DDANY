extends SceneTree
# TESTE DE REDE DOS VEÍCULOS (0.76), parte do HOST: espera o amigo (rede_carro_cliente.gd) entrar num carro, confere
# que a cópia do carro aparece e anda aqui e que, quando ele sai, o carro fica estacionado (loot "veiculos").
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
	var t := 0.0
	var r = null
	while t < 150.0:
		await create_timer(0.25).timeout
		t += 0.25
		if m.sessao_rede != null and not m.sessao_rede.remotos.is_empty():
			r = m.sessao_rede.remotos.values()[0]
			if r.dirigindo_id != "" and r._carro != null:
				break
	if r == null or r.dirigindo_id == "":
		print("HOST: o amigo não entrou em carro nenhum")
		quit()
		return
	var vid: String = r.dirigindo_id
	var p0: Vector3 = r._carro.global_position
	print("HOST: amigo dirigindo ", vid, " · boneco escondido: ", not r._slot.visible)
	await create_timer(3.0).timeout
	if r._carro != null and is_instance_valid(r._carro):
		print("HOST: a cópia do carro andou %.1f m" % r._carro.global_position.distance_to(p0))
	t = 0.0
	while t < 30.0 and r.dirigindo_id != "":
		await create_timer(0.25).timeout
		t += 0.25
	await create_timer(1.0).timeout
	print("HOST: depois de sair: estacionado guardado ", m.loot_mundo.veiculos.has(vid), " · cópia sumiu ", r._carro == null)
	await create_timer(4.0).timeout
	quit()
