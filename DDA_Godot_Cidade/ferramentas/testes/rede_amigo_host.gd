extends SceneTree
# TESTE DE REDE (0.74), parte do HOST: cria a partida e espera o amigo ir longe (rede_amigo_cliente.gd); confere se os
# prédios perto dele abriram aqui, se a colisão segue o amigo e se os infectados de lá andam com física.
# Rodar os dois juntos: ferramentas/testes/rodar.sh rede
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
	var t := 0.0
	while t < 120.0:
		await create_timer(0.5).timeout
		t += 0.5
		if m.sessao_rede != null and not m.sessao_rede.remotos.is_empty():
			var r0 = m.sessao_rede.remotos.values()[0]
			if r0.visible and r0.global_position.distance_to(m.jogador.global_position) > 200.0: break
	var r = m.sessao_rede.remotos.values()[0]
	print("HOST: amigo em ", r.global_position.snapped(Vector3.ONE), " a ", int(r.global_position.distance_to(m.jogador.global_position)), " m")
	await create_timer(6.0).timeout
	var pr := Vector2(r.global_position.x, r.global_position.z)
	var perto := 0
	for i in m.interiores.abertos:
		var inf: Dictionary = m.cidade.predio_info[i]
		if m.interiores._dist_ret(pr, inf) < 45.0: perto += 1
	print("HOST: prédios abertos perto do amigo: ", perto, " (abertos no total ", m.interiores.abertos.size(), ")")
	print("HOST: colisões extras: ", m.mundo.extras.size(), " · chão de física no amigo: ", m.mundo.tem_chao_fisico(pr.x, pr.y))
	var antes: int = m.vagos.vivos.size()
	for k in 3:
		m.vagos._criar(r.global_position + Vector3(8.0 + k, 0.0, 6.0), Vector3.INF)
	await create_timer(4.0).timeout
	var fis := 0
	var vivos_perto := 0
	for v in m.vagos.vivos:
		if is_instance_valid(v) and Vector2(v.global_position.x - pr.x, v.global_position.z - pr.y).length() < 40.0:
			vivos_perto += 1
			if v._fisica: fis += 1
	print("HOST: infectados perto do amigo: ", vivos_perto, " · com física: ", fis)
	# 1.09: a mensagem do chat que o amigo manda chega aqui (com o nome dele)
	var chegou := false
	for k in 40:
		await create_timer(0.25).timeout
		for l in m.chat._linhas:
			if String(l[0]).contains("ola host chat 109"):
				chegou = true
		if chegou:
			break
	print("HOST: chat do amigo chegou: ", chegou)
	await create_timer(5.0).timeout
	quit()
