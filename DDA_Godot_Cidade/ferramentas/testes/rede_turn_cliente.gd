extends SceneTree
# TESTE DE REDE PELO RETRANSMISSOR (0.85), parte do AMIGO: lê o endereço público do host (DDA_ARQ), descobre o próprio
# IP (STUN, como no jogo), conecta o ENet nele (Rede.entrar_relay) e anda ~80 m para o host ver.
const Turn := preload("res://rede/turn.gd")
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func _r():
	for i in 30: await process_frame
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	var R = root.get_node("Rede")
	var arq := OS.get_environment("DDA_ARQ")
	var t := 0.0
	while (not FileAccess.file_exists(arq) or FileAccess.get_file_as_string(arq) == "") and t < 40.0:
		await create_timer(0.3).timeout
		t += 0.3
	var relay := FileAccess.get_file_as_string(arq)
	var cfg := Turn.config()
	var porta_local := randi_range(40000, 60999)
	var ip: String = await Turn.ip_publico_async(R, cfg["stun"][0], int(cfg["stun"][1]), porta_local)
	print("CLI: endereço do host ", relay, " · meu IP (STUN) ", ip)
	R.entrar_relay(relay, porta_local)
	t = 0.0
	while not R.partida_comecou and t < 40.0:
		await create_timer(0.5).timeout
		t += 0.5
	print("CLI: ligado %s · semente %s · começou %s" % [R.ligado, str(R.mundo.get("semente", "?")), R.partida_comecou])
	m._jogar()
	while m.jogador == null: await process_frame
	await create_timer(3.0).timeout
	var j = m.jogador
	var p: Vector3 = j.global_position + Vector3(80, 0, 0)
	j.teleportar(Vector3(p.x, m.mundo.altura(p.x, p.z) + 0.1, p.z), 0.0)
	await create_timer(3.0).timeout
	var host_visto: bool = m.sessao_rede != null and not m.sessao_rede.remotos.is_empty()
	print("CLI: vê o host %s" % host_visto)
	await create_timer(20.0).timeout
	quit()
