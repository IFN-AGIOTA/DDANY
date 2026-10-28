extends SceneTree
# TESTE: TELA DE CARREGAMENTO (0.99). Jogar com a montagem em etapas (como no jogo de verdade): a tela cobre tudo
# antes de o menu sumir, mostra as etapas na ordem com a barra só andando para a frente, as dicas trocam, nada do jogo
# anda enquanto monta, e no fim ela some sozinha com o jogador já no chão e o jogo andando. Depois, "Voltar ao início"
# pela pausa usa a mesma tela. 0.99.1: nenhuma parada (quadro sem desenhar a tela) passa de 1,5 s.
# Com FOTOS=<pasta> salva fotos da tela (para conferir a aparência).
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()

var _fotos := OS.get_environment("FOTOS")
var _n_foto := 0
func _foto(nome: String) -> void:
	if _fotos == "":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	_n_foto += 1
	img.save_png("%s/%02d_%s.png" % [_fotos, _n_foto, nome])

func _r():
	for i in 20:
		await process_frame
	var m = current_scene
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	for i in 10:
		await process_frame
	m.carregar_em_etapas = true
	m._jogar()
	var etapas: Array = []
	var fracoes: Array = []
	var cobriu_antes_do_menu_sumir := true
	var jogo_andou_montando := false
	var fotos_tiradas := {}
	var apareceu := false
	var maior_parada := 0.0
	var t0 := Time.get_ticks_msec()
	var c = null
	while Time.get_ticks_msec() - t0 < 400000:
		await process_frame
		if c == null and m.carregamento != null:
			c = m.carregamento
			apareceu = true
		if c == null:
			continue
		if not is_instance_valid(c):
			break
		if m.menu == null and c._alfa < 0.999 and not c._saindo:
			cobriu_antes_do_menu_sumir = false
		if m.jogo != null and m.carregamento != null and m.jogo.process_mode != Node.PROCESS_MODE_DISABLED:
			jogo_andou_montando = true
		if etapas.is_empty() or etapas[-1] != c.texto_etapa:
			etapas.append(c.texto_etapa)
		fracoes.append(c.fracao())
		maior_parada = maxf(maior_parada, c.maior_quadro)
		for marca in [["inicio", 0.02], ["meio", 0.45], ["fim", 0.9]]:
			if c.fracao() >= marca[1] and not fotos_tiradas.has(marca[0]) and c._alfa >= 1.0:
				fotos_tiradas[marca[0]] = true
				await _foto(marca[0])
	print("  etapas: ", " > ".join(etapas))
	ok(apareceu, "a tela de carregamento apareceu")
	ok(cobriu_antes_do_menu_sumir, "a tela cobre tudo antes de o menu sumir")
	ok(etapas.size() >= 25, "mostrou as etapas uma a uma (%d)" % etapas.size())
	ok("Ruas e avenidas" in etapas and "Acordando os infectados" in etapas and "Preparando a vista" in etapas, "etapas da cidade, do jogo e a vista")
	var anda := true
	for i in range(1, fracoes.size()):
		if fracoes[i] < fracoes[i - 1] - 0.0001:
			anda = false
	ok(anda and fracoes.size() > 0 and fracoes[-1] > 0.99, "a barra só anda para a frente e chega a 100%% (%.2f)" % (fracoes[-1] if fracoes.size() > 0 else 0.0))
	ok(not jogo_andou_montando, "nada do jogo anda enquanto monta")
	ok(maior_parada < 1.5, "a tela nunca fica parada muito tempo (maior parada %.2f s)" % maior_parada)
	ok(m.carregamento == null and not is_instance_valid(c), "a tela some sozinha no fim")
	ok(m.jogo != null and m.jogo.process_mode == Node.PROCESS_MODE_PAUSABLE and m.jogador != null, "o jogo está montado e andando")
	var p0: Vector3 = m.jogador.global_position
	for i in 30:
		await process_frame
	ok(absf(m.jogador.global_position.y - p0.y) < 0.5 and m.jogador.is_on_floor(), "o jogador está no chão (y %.2f)" % m.jogador.global_position.y)
	await _foto("jogo")
	# dicas: trocam sozinhas e com toque
	var T = load("res://menu/tela_carregamento.gd")
	ok(T.DICAS.size() >= 20, "%d dicas" % T.DICAS.size())
	# Voltar ao início pela pausa: mesma tela
	m._pausar()
	await process_frame
	m._recomecar()
	var viu := false
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 200000:
		await process_frame
		if m.carregamento != null:
			viu = true
			var d = m.carregamento
			if d._dica >= 0 and not fotos_tiradas.has("recomecar") and d._alfa >= 1.0:
				fotos_tiradas["recomecar"] = true
				await _foto("recomecar")
		elif viu and m.get_node_or_null("TelaCarregamento") == null and m.jogo != null and m.jogo.process_mode == Node.PROCESS_MODE_PAUSABLE:
			break
	for i in 30:
		await process_frame
	ok(viu and m.jogador != null and m.jogo.process_mode == Node.PROCESS_MODE_PAUSABLE, "Voltar ao início usa a tela de carregamento e o jogo volta")
	print("falhas: ", falhas)
	quit()
