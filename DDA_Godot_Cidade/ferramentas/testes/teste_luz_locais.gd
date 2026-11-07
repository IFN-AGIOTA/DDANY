extends SceneTree
# TESTE DA LUZ E SOM DOS LOCAIS (0.77): à noite, um local com gerador tem luzes acesas (e o ronco tocando); um sem
# gerador fica apagado. FOTO=<prefixo> salva a imagem de dentro do local aceso.
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func q(n):
	for i in n:
		await physics_frame
		await process_frame
func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.clima.definir_hora(23.5)
	m.clima.set("parado", true)
	m.vagos.ativo = false
	var L = load("res://mundo/locais.gd")
	var com := -1
	var sem := -1
	for i in L.LOCAIS.size():
		var r := RandomNumberGenerator.new()
		r.seed = i * 9133 + 17
		var g := r.randf() < 0.6
		if g and com < 0 and L.LOCAIS[i][0] == "supermercado": com = i
		if not g and sem < 0: sem = i
	print("local com gerador: ", com, " · sem: ", sem)
	var j = m.jogador
	for caso in [[com, true], [sem, false]]:
		var i: int = caso[0]
		var e: Array = L.LOCAIS[i]
		var v0: Vector3 = L.casca(e[0])[0][0]
		var c: Vector2 = L.local_para_mundo(i, Vector2(v0.x, v0.z))
		m.mundo.forcar(c)
		j.teleportar(Vector3(c.x, m.cidade.Y_CALCADA + 0.1, c.y), 0.0)
		m.locais.abrir_agora(c)
		await q(90)
		var no = m.locais.abertos.get(i)
		var amb = no.get_node_or_null("Ambiente") if no != null else null
		ok(amb != null, "local %d montado com ambiente" % i)
		if amb == null: continue
		var acesas := 0
		for l in amb._luzes:
			if l.visible and l.light_energy > 0.04: acesas += 1
		if caso[1]:
			ok(amb.tem_gerador and acesas >= 1, "com gerador, à noite: %d luzes acesas" % acesas)
			var p := OS.get_environment("FOTO")
			if p != "":
				j.cam_pit = 0.1
				await q(10)
				root.get_texture().get_image().save_png(p + "_local_aceso.png")
			m.clima.definir_hora(13.0)
			await q(90)
			var dia := 0
			for l in amb._luzes:
				if l.visible: dia += 1
			ok(dia == 0, "de dia as luzes apagam")
			m.clima.definir_hora(23.5)
		else:
			ok(not amb.tem_gerador and acesas == 0, "sem gerador: escuro")
		m.locais.fechar(i)
		await q(5)
	print("FPS ", Engine.get_frames_per_second(), " · falhas: ", falhas)
	quit()
