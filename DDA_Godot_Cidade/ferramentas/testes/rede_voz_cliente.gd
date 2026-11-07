extends SceneTree
# TESTE DE REDE DO CHAT DE VOZ (0.97), parte do AMIGO: chega perto do host e "fala" (um som de teste no lugar do
# microfone): silêncio não manda nada; voz manda; longe não manda; com o MIC mudo não manda.
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func fala(seg: float, amp: float) -> void:
	var voz = current_scene.sessao_rede.voz
	var fase := 0.0
	for k in int(seg / 0.04):
		var buf := PackedVector2Array()
		for i in 1920:
			fase += TAU * 220.0 / 48000.0
			var x := sin(fase) * amp
			buf.append(Vector2(x, x))
		voz.processar(buf, 48000.0)
		await create_timer(0.04).timeout
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
	m.vagos.ativo = false
	var j = m.jogador
	j.sobrevivencia.imortal = true
	var s = m.sessao_rede
	t = 0.0
	while s.remotos.is_empty() and t < 60.0:
		await create_timer(0.5).timeout
		t += 0.5
	var voz = s.voz
	voz._parar_mic()                                   # o microfone de verdade (máquina de teste, sem som) fica de fora
	print("CLI: voz criada ", voz != null, " · botões ", not m.controles.ocultos.get("MIC", true), " ", not m.controles.ocultos.get("VOZES", true))
	var host = s.remotos.values()[0]
	t = 0.0
	while not host.visible and t < 30.0:                # a posição dele chegou pela rede
		await create_timer(0.25).timeout
		t += 0.25
	await create_timer(1.0).timeout
	j.teleportar(host.global_position + Vector3(3, 0.3, 0), 0.0)
	await create_timer(3.0).timeout
	print("CLI: perto do host %.1f m" % j.global_position.distance_to(host.global_position))
	await fala(2.0, 0.0005)
	print("CLI: silêncio mandou ", voz.enviados)
	await fala(3.0, 0.3)
	var n1: int = voz.enviados
	print("CLI: voz mandou ", n1, " · falando ", voz.falando)
	await create_timer(5.0).timeout                    # o host muta as VOZES aqui
	await fala(3.0, 0.3)
	var n2: int = voz.enviados
	# longe (80 m, o alcance é 45): não manda
	j.teleportar(host.global_position + Vector3(80, 0.3, 0), 0.0)
	await create_timer(1.0).timeout
	await fala(1.0, 0.3)
	print("CLI: longe mandou ", voz.enviados - n2)
	j.teleportar(host.global_position + Vector3(3, 0.3, 0), 0.0)
	await create_timer(1.0).timeout
	voz.alternar_mic()
	await fala(2.0, 0.3)
	print("CLI: mic mudo mandou ", voz.enviados - n2, " · guardado ", root.get_node("Config").valor("voz_mic"))
	voz.alternar_mic()
	await create_timer(4.0).timeout
	quit()
