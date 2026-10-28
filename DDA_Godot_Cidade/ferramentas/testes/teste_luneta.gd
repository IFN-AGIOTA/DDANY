extends SceneTree
# TESTE: LUNETAS COM EFEITO DE LENTE (0.99). Rifle de caça com luneta e M4A1 com mira 4x: MIRAR em 1ª pessoa põe o
# olho atrás da ocular; o vidro (vista ampliada) fica no centro da tela, em cima da ocular 3D, a 2ª câmera olha
# pelo tubo (para onde a arma aponta) com o campo de visão dividido pelo aumento, o olhar fica mais lento, e ao parar
# de mirar a 2ª câmera desliga. Em 3ª pessoa MIRAR também vai para a luneta; com "por cima do ombro", aproxima como antes.
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
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	m.vagos.limpar()
	var MF = load("res://armas/mira_ferro.gd")
	var Item = load("res://inventario/item.gd")
	var tela: Vector2 = root.get_visible_rect().size
	j.primeira_pessoa = true
	for par in [["rifle_caca", "luneta"], ["m4", "mira_acog"]]:
		var it = Item.novo(par[0])
		it.acessorios["mira"] = par[1]
		j.inventario.equipar(it, "maos")
		j._mirar_ligado = false
		j.cam_pit = 0.0
		await q(30)
		ok(j.luneta_montada() == par[1] and not j.em_luneta(), "%s: luneta encaixada, sem mirar não olha por ela" % par[0])
		j._mirar_ligado = true
		await q(50)
		var v = j.vista_luneta
		ok(v != null and j.em_luneta() and v.alfa > 0.99 and v.visible, "%s: mirando, olha pela luneta" % par[0])
		if v == null:
			continue
		ok(v.centro.distance_to(tela * 0.5) < 3.0, "%s: o vidro no centro da tela (%.1f, %.1f)" % [par[0], v.centro.x, v.centro.y])
		var arma: Node3D = j.armas.nos[par[0]]
		var oc: Vector2 = j.camera.unproject_position(arma.global_transform * MF.ocular(par[0], par[1]))
		ok(oc.distance_to(v.centro) < 3.0, "%s: o vidro em cima da ocular 3D" % par[0])
		ok(v.raio > tela.y * 0.12 and v.raio < tela.y * 0.35, "%s: tamanho do vidro (raio %.0f px)" % [par[0], v.raio])
		var tubo: Vector3 = (arma.global_transform.basis * Vector3(0, 0, 1)).normalized()
		var olhar: Vector3 = -v._cam.global_basis.z
		ok(rad_to_deg(tubo.angle_to(olhar)) < 0.3 and rad_to_deg(olhar.angle_to(-j.camera.global_basis.z)) < 0.5, "%s: a 2ª câmera olha pelo tubo, para onde a arma aponta" % par[0])
		var l: Dictionary = MF.LUNETAS[par[1]]
		var esperado := rad_to_deg(2.0 * atan(float(l["vidro"]) / float(l["olho"]) / float(l["aumento"])))
		ok(absf(v._cam.fov - esperado) < 0.01 and v._sv.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "%s: aumento %.0fx (campo %.2f°)" % [par[0], l["aumento"], v._cam.fov])
		ok(j._sens_luneta() < 0.5, "%s: olhar mais lento pela luneta (x%.2f)" % [par[0], j._sens_luneta()])
		j._mirar_ligado = false
		await q(30)
		ok(not v.visible and v._sv.render_target_update_mode == SubViewport.UPDATE_DISABLED, "%s: parou de mirar: a 2ª câmera desliga" % par[0])
	# 3ª pessoa
	j.primeira_pessoa = false
	await q(30)
	j._mirar_ligado = true
	await q(50)
	ok(j.em_luneta() and j.vista_luneta.visible, "3ª pessoa: MIRAR vai para a luneta")
	j._mirar_ligado = false
	await q(30)
	j.mira_ferro_3p = false
	j._mirar_ligado = true
	await q(40)
	ok(not j.em_luneta() and not j.vista_luneta.visible and j._fp < 0.05 and j.camera.fov < j.fov_mirando - 5.0, "\"por cima do ombro\": a luneta aproxima como antes (FOV %.0f)" % j.camera.fov)
	j._mirar_ligado = false
	j.mira_ferro_3p = true
	print("falhas: ", falhas)
	quit()
