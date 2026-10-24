extends SceneTree
# TESTE DE REDE PELO RETRANSMISSOR (0.85), parte do HOST: abre a partida; a ponte (rede/ponte_turn.gd) pega o endereço
# público no retransmissor de mentira (DDA_TURN) e o grava em DDA_ARQ para o amigo; libera o IP dele (o convite pelo
# Firebase faz isso no jogo de verdade) e confere se o amigo entrou e anda na cidade.
# Rodar: ferramentas/testes/rodar.sh rede_turn
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func _r():
	for i in 30: await process_frame
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	var R = root.get_node("Rede")
	R.criar_partida("Host", 77)
	var t := 0.0
	while (R.ponte == null or R.ponte.endereco == "") and t < 15.0:
		await create_timer(0.2).timeout
		t += 0.2
	print("HOST: ponte ", R.ponte != null, " · endereço público ", R.ponte.endereco if R.ponte != null else "-", " · aceita_turn ", R.aceita_turn())
	R.ponte.permitir("127.0.0.1")
	var f := FileAccess.open(OS.get_environment("DDA_ARQ"), FileAccess.WRITE)
	f.store_string(R.ponte.endereco)
	f.close()
	await create_timer(1.0).timeout
	R.comecar_partida()
	m._jogar()
	while m.jogador == null: await process_frame
	t = 0.0
	while t < 90.0:
		await create_timer(0.5).timeout
		t += 0.5
		if m.sessao_rede != null and not m.sessao_rede.remotos.is_empty():
			var r0 = m.sessao_rede.remotos.values()[0]
			if r0.visible and r0.global_position.distance_to(m.jogador.global_position) > 30.0: break
	var visto := false
	var longe := 0
	if m.sessao_rede != null and not m.sessao_rede.remotos.is_empty():
		var r = m.sessao_rede.remotos.values()[0]
		visto = r.visible
		longe = int(r.global_position.distance_to(m.jogador.global_position))
	print("HOST: amigo pelo retransmissor: %s · jogadores %d · amigo andou até %d m · espelhos %d" % [visto, R.jogadores.size(), longe, R.ponte._espelhos.size()])
	var b0: int = R.ponte.bytes_recebidos + R.ponte.bytes_enviados
	await create_timer(10.0).timeout
	var kb := float(R.ponte.bytes_recebidos + R.ponte.bytes_enviados - b0) / 1024.0
	print("HOST: tráfego pelo retransmissor com 1 amigo: %.1f KB em 10 s (~%.1f MB por hora)" % [kb, kb * 360.0 / 1024.0])
	quit()
