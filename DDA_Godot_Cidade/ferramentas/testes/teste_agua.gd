extends SceneTree
# TESTE DA ÁGUA (0.72): acha mar fundo e uma margem perto do nascimento; nada, boia, afunda sem estamina, perde o
# fôlego, se afoga, volta a boiar; anda na água rasa; infectado para na margem. FOTO=<prefixo> salva imagens.
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
func foto(nome: String) -> void:
	var p := OS.get_environment("FOTO")
	if p == "": return
	await q(3)
	root.get_texture().get_image().save_png(p + "_" + nome + ".png")
func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	var j = m.jogador
	var mw = m.mundo
	m.vagos.ativo = false
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.clima.definir_hora(12.0)
	m.clima.set("parado", true)
	var sv = j.sobrevivencia
	# acha mar fundo (tudo água num raio de 40 m) e uma margem perto do nascimento
	var fundo := Vector3.INF
	var raso := Vector3.INF
	var c0: Vector2 = m.SPAWN
	for r in range(100, 6000, 60):
		for k in 24:
			var a := TAU * k / 24.0
			var p := c0 + Vector2(cos(a), sin(a)) * r
			if mw.nivel_agua(p.x, p.y) != -0.5:
				continue
			if fundo == Vector3.INF:
				var todos := true
				for kk in 8:
					var b := TAU * kk / 8.0
					if mw.nivel_agua(p.x + cos(b) * 40.0, p.y + sin(b) * 40.0) != -0.5:
						todos = false
						break
				if todos:
					fundo = Vector3(p.x, -0.5, p.y)
			if raso == Vector3.INF:
				for kk in 8:
					var b := TAU * kk / 8.0
					if mw.nivel_agua(p.x + cos(b) * 4.0, p.y + sin(b) * 4.0) == -INF:
						raso = Vector3(p.x, -0.5, p.y)
						break
		if fundo != Vector3.INF and raso != Vector3.INF:
			break
	print("mar fundo ", fundo, " · margem ", raso)
	ok(fundo != Vector3.INF, "achou mar fundo")
	# ---- mar fundo: nada ----
	j.teleportar(fundo + Vector3(0, 0.05, 0), 0.0)
	mw.forcar(Vector2(fundo.x, fundo.z))
	await q(90)
	print("y %.2f nível %.2f fundo %.2f nadando %s" % [j.global_position.y, j.nivel_agua, j._fundo, j.nadando])
	ok(j.nadando, "no mar fundo: nadando")
	ok(absf(j.global_position.y - (-0.5 - j.NADO_ALTURA)) < 0.15, "boiando na linha d'água (y %.2f)" % j.global_position.y)
	ok(j.armas.escondida, "arma guardada nadando")
	ok(j.animador._nome_atual == "nadar", "animação nadar (" + j.animador._nome_atual + ")")
	ok(sv.molhado > 0.99, "roupa encharcada")
	await foto("nadando")
	j.cam_yaw = j.rotation.y + PI * 0.5
	j.cam_pit = 0.25
	await q(20)
	await foto("nadando_lado")
	j.cam_yaw = j.rotation.y
	j.cam_pit = 0.05
	# boiando parado e leve: a estamina volta
	sv.estamina = 50.0
	await q(60)
	ok(sv.estamina > 50.0, "boiando parado descansa (%.1f)" % sv.estamina)
	# sem estamina: afunda, perde o fôlego e se afoga
	var vida0: float = sv.vida
	for i in 60 * 11:
		sv.estamina = 0.0
		await physics_frame
	print("afundando %s fôlego %.1f vida %.1f y %.2f" % [j.afundando, sv.folego, sv.vida, j.global_position.y])
	ok(j.afundando, "sem estamina: afunda")
	ok(sv.folego <= 0.0, "fôlego acabou")
	ok(sv.vida < vida0, "afogando: perde vida")
	ok(j._tela_agua != null and j._tela_agua.visible, "tela embaixo d'água")
	await foto("afundando")
	sv.estamina = 40.0
	await q(80)
	ok(not j.afundando and sv.folego > 0.0, "voltou a boiar e respirar")
	# ---- margem: anda na água rasa ----
	if raso != Vector3.INF:
		j.teleportar(raso + Vector3(0, 0.05, 0), 0.0)
		mw.forcar(Vector2(raso.x, raso.z))
		await q(90)
		print("margem: y %.2f fundo %.2f nadando %s prof %.2f" % [j.global_position.y, j._fundo, j.nadando, j.prof_agua])
		ok(not j.nadando, "na margem: em pé (não nada)")
		ok(j.global_position.y < -0.5, "na margem: pé abaixo da superfície")
		await foto("margem")
	# ---- infectado não entra na água ----
	m.vagos.ativo = true
	var terra := Vector3.INF
	if raso != Vector3.INF:
		for kk in 16:
			var b := TAU * kk / 16.0
			var tx: float = raso.x + cos(b) * 8.0
			var tz: float = raso.z + sin(b) * 8.0
			if mw.nivel_agua(tx, tz) == -INF:
				terra = Vector3(tx, mw.altura(tx, tz), tz)
				break
	if terra != Vector3.INF:
		m.vagos._criar(terra, Vector3.INF)
		var v = m.vagos.vivos.back()
		await q(5)
		v._destino = fundo
		v._vel_alvo = 1.5
		for i in 6:
			v._destino = fundo
			v._vel_alvo = 1.5
			await q(30)
		var gp: Vector3 = v.global_position
		print("infectado em ", gp, " nível ", mw.nivel_agua(gp.x, gp.z))
		ok(gp.y > -0.6, "infectado ficou na margem (y %.2f)" % gp.y)
	print("falhas: ", falhas)
	quit()
