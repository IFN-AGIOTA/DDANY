extends SceneTree
# TESTE DA LIGAÇÃO DIRETA (0.86), parte do HOST (rodado por ferramentas/testes/rede_nat.sh, atrás de um NAT de mentira):
# abre a partida (descobre o endereço público da porta do jogo e pega o retransmissor), espera o pedido do amigo
# (DDA_TROCA/pedido.txt = "ip:porta"), atende como no convite de verdade (Rede.atender_amigo) e responde em resposta.txt.
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func _r():
	for i in 30: await process_frame
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	var R = root.get_node("Rede")
	var dir := OS.get_environment("DDA_TROCA")
	R.criar_partida("Host", 77)
	var t := 0.0
	while (R.ponte == null or R.ponte.endereco == "") and t < 15.0:
		await create_timer(0.2).timeout
		t += 0.2
	print("HOST: direto %s · retransmissor %s" % [R.direto_publico, R.ponte.endereco if R.ponte != null else "-"])
	t = 0.0
	while not FileAccess.file_exists(dir + "/pedido.txt") and t < 60.0:
		await create_timer(0.2).timeout
		t += 0.2
	var pedido := FileAccess.get_file_as_string(dir + "/pedido.txt").strip_edges()
	var r: Dictionary = R.atender_amigo(pedido.get_slice(":", 0), int(pedido.get_slice(":", 1)))
	print("HOST: pedido de ", pedido, " -> ", r)
	var f := FileAccess.open(dir + "/resposta.txt", FileAccess.WRITE)
	f.store_string(JSON.stringify(r))
	f.close()
	await create_timer(1.0).timeout
	R.comecar_partida()
	m._jogar()
	while m.jogador == null: await process_frame
	t = 0.0
	while t < 60.0 and R.jogadores.size() < 2:
		await create_timer(0.5).timeout
		t += 0.5
	await create_timer(8.0).timeout
	var visto: bool = m.sessao_rede != null and not m.sessao_rede.remotos.is_empty()
	print("HOST: amigo entrou: %s · jogadores %d · espelhos no retransmissor %d" % [visto and R.jogadores.size() == 2, R.jogadores.size(), R.ponte._espelhos.size() if R.ponte != null else -1])
	await create_timer(4.0).timeout
	quit()
