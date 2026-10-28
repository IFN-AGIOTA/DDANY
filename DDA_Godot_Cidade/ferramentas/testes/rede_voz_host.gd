extends SceneTree
# TESTE DE REDE DO CHAT DE VOZ (0.97), parte do HOST: ouve a voz do amigo (rede_voz_cliente.gd) saindo dele (som 3D
# no boneco, ")))" no nome) e depois muta as VOZES: o que chega não toca mais.
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
	m.jogador.sobrevivencia.imortal = true
	var s = m.sessao_rede
	var voz = s.voz
	var t := 0.0
	while voz.recebidos == 0 and t < 120.0:
		await create_timer(0.1).timeout
		t += 0.1
	var viu_falando := false
	var quieto := 0.0
	while quieto < 1.5 and t < 200.0:
		var r0 = s.remotos.values()[0]
		viu_falando = viu_falando or r0.falando
		var antes: int = voz.recebidos
		await create_timer(0.1).timeout
		t += 0.1
		quieto = quieto + 0.1 if voz.recebidos == antes else 0.0
	var r = s.remotos.values()[0]
	var som: AudioStreamPlayer3D = null
	for c in r.get_children():
		if c is AudioStreamPlayer3D and c.stream is AudioStreamGenerator:
			som = c
	print("HOST: ouviu %d pacotes · som 3D no amigo %s (até %d m) · ))) no nome %s" % [voz.recebidos, som != null, int(som.max_distance) if som != null else 0, viu_falando])
	var n1: int = voz.recebidos
	voz.alternar_ouvir()
	await create_timer(12.0).timeout
	print("HOST: com VOZES mudas tocou mais %d · guardado %s" % [voz.recebidos - n1, str(root.get_node("Config").valor("voz_ouvir"))])
	voz.alternar_ouvir()
	await create_timer(20.0).timeout                     # o amigo termina antes (ele sai primeiro)
	print("HOST: depois de desmutar tocou mais %d" % (voz.recebidos - n1))
	quit()
