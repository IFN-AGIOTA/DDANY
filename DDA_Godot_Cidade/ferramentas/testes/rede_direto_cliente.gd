extends SceneTree
# TESTE DA LIGAÇÃO DIRETA (0.86), parte do AMIGO (atrás do outro NAT de mentira): descobre o próprio endereço público
# (STUN), "pede para entrar" (DDA_TROCA/pedido.txt), recebe a resposta e entra: direto ou pelo retransmissor.
const Turn := preload("res://rede/turn.gd")
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func _r():
	for i in 30: await process_frame
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	var R = root.get_node("Rede")
	var dir := OS.get_environment("DDA_TROCA")
	await create_timer(6.0).timeout
	var cfg := Turn.config()
	var porta_local := randi_range(40000, 60999)
	var meu: String = await Turn.endereco_publico_async(R, cfg["stun"][0], int(cfg["stun"][1]), porta_local)
	print("CLI: meu endereço público ", meu)
	var f := FileAccess.open(dir + "/pedido.txt", FileAccess.WRITE)
	f.store_string(meu)
	f.close()
	var t := 0.0
	while not FileAccess.file_exists(dir + "/resposta.txt") and t < 40.0:
		await create_timer(0.2).timeout
		t += 0.2
	var r = JSON.parse_string(FileAccess.get_file_as_string(dir + "/resposta.txt"))
	R.entrar_direto_ou_relay(str(r.get("direto", "")), str(r.get("relay", "")), porta_local)
	t = 0.0
	while not R.partida_comecou and t < 40.0:
		await create_timer(0.5).timeout
		t += 0.5
	print("CLI: via %s" % R.via)
	print("CLI: ligado %s · semente %s · começou %s" % [R.ligado, str(R.mundo.get("semente", "?")), R.partida_comecou])
	m._jogar()
	await create_timer(14.0).timeout
	quit()
