extends SceneTree
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func q(n):
	for i in n:
		await physics_frame
		await process_frame
func foto(nome):
	await q(4)
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("PASTA") + nome)
func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	var c = m.clima
	c.parado = true
	c.chuva = 0.0
	c._alvo_chuva = 0.0
	c.nuvens = 0.1
	c._alvo_nuvens = 0.1
	m.controles.visible = false
	for n in ["hud", "mapa", "hud_status"]:
		var x = m.get(n)
		if x != null: x.visible = false
	# rua aberta
	var p := Vector2(6230, 590)
	m.mundo.forcar(p)
	j.teleportar(Vector3(p.x, m.mundo.altura(p.x, p.y) + 0.2, p.y), 0.0)
	for e in [[12.0, "luz_meiodia.png", 0.8], [18.3, "luz_tarde.png", 2.3], [21.5, "luz_noite.png", 0.8]]:
		c.hora = e[0]
		j.cam_yaw = e[2]
		await q(80)
		await foto(e[1])
	# noite com lanterna
	var it = load("res://inventario/item.gd").novo("lanterna", 1)
	it.carga = 1.0
	j.inventario._guardar_auto(it)
	j.inventario.equipar(it, "maos")
	c.hora = 23.0
	await q(60)
	await foto("luz_lanterna.png")
	j.inventario.desequipar(it)
	# chuva de tarde
	c.hora = 16.0
	c.chuva = 1.0
	c._alvo_chuva = 1.0
	c.nuvens = 1.0
	c._alvo_nuvens = 1.0
	c.molhado = 1.0
	await q(120)
	await foto("luz_chuva.png")
	c.chuva = 0.0
	c._alvo_chuva = 0.0
	c.nuvens = 0.1
	c._alvo_nuvens = 0.1
	c.molhado = 0.0
	# dentro do hospital, de dia
	c.hora = 14.0
	var Locais = load("res://mundo/locais.gd")
	var hi: int = m.hospitais.hospitais()[0]
	var p2: Vector2 = Locais.local_para_mundo(hi, Vector2(-18.0, -5.0))
	m.mundo.forcar(p2)
	m.locais.abrir_agora(p2)
	j.teleportar(Vector3(p2.x, m.cidade.Y_CALCADA + 0.3, p2.y), 0.0)
	j.cam_yaw = PI * 0.5
	await q(80)
	await foto("luz_dentro.png")
	# perto de prédios (tijolo, concreto, pedra), de dia
	c.hora = 15.0
	var p4 := Vector2(6230, 590)
	for tp in [1, 0, 2]:
		var mais := Vector2.INF
		var md := 1e9
		for e in m.cidade.predio_info:
			var cc := Vector2(e["x"], e["z"])
			var dd := cc.distance_to(p4)
			var vista := cc + Vector2(-3.0, float(e["sz"]) * 0.5 + 12.0)
			if dd < md and int(e["tipo"]) == tp and not bool(e["ruina"]) and not bool(e["entra"]) and float(e["sx"]) > 12.0 and float(e["sz"]) > 12.0 \
					and not m.mundo.dentro_de_predio(vista.x, vista.y, 3.0) and not m.mundo.dentro_de_predio(vista.x, vista.y - 6.0, 1.0):
				md = dd
				mais = vista
		print("PREDIO tipo ", tp, " em ", mais, " dist ", md, " altura ", m.mundo.altura(mais.x, mais.y))
		if mais != Vector2.INF:
			m.mundo.forcar(mais)
			j.teleportar(Vector3(mais.x, m.mundo.altura(mais.x, mais.y) + 0.2, mais.y), 0.0)
			j.cam_yaw = 0.25
			for k in 8:
				m.mundo.forcar(mais)
				await q(50)
			await foto("luz_predio_%d.png" % tp)
	# horizonte
	var p3 := Vector2(6000, 900)
	m.mundo.forcar(p3)
	j.teleportar(Vector3(p3.x, m.mundo.altura(p3.x, p3.y) + 0.2, p3.y), 0.0)
	j.cam_yaw = 2.6
	c.hora = 17.0
	await q(100)
	await foto("luz_longe.png")
	quit()
