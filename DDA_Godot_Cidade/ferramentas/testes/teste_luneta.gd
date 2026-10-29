extends SceneTree
# TESTE: LUNETAS (0.99; 0.99.2 leve, uma câmera só). Rifle de caça com luneta e M4A1 com mira 4x: MIRAR em 1ª
# pessoa leva a luneta ao olho e troca para a vista da luneta: a câmera do jogo aproxima pelo aumento, a arma some da
# frente do olho, o vidro fica no centro da tela, NÃO existe 2ª câmera e o quadro não fica mais pesado que sem mirar;
# o olhar fica mais lento; ao parar de mirar tudo volta. Em 3ª pessoa MIRAR também vai para a luneta; com "por cima do
# ombro", aproxima como antes.
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
func _medir(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		await process_frame
	return float(Time.get_ticks_usec() - t0) / n / 1000.0

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
		var t_sem := await _medir(40)
		j._mirar_ligado = true
		await q(50)
		var v = j.vista_luneta
		ok(v != null and j.em_luneta() and v.ativa and v.visible, "%s: mirando, olha pela luneta" % par[0])
		if v == null:
			continue
		var l: Dictionary = MF.LUNETAS[par[1]]
		var base: float = j.fov_camera + 18.0
		var esperado := rad_to_deg(2.0 * atan(tan(deg_to_rad(base) * 0.5) / float(l["aumento"])))
		ok(absf(j.camera.fov - esperado) < 0.05, "%s: a câmera do jogo aproxima %.0fx (FOV %.1f°)" % [par[0], l["aumento"], j.camera.fov])
		ok(v.find_children("*", "SubViewport", true, false).is_empty() and v.find_children("*", "Camera3D", true, false).is_empty(), "%s: sem 2ª câmera (a cidade é desenhada uma vez só)" % par[0])
		var mod = j._slot.get_child(0)
		ok(not mod._ponto_fuzil.visible, "%s: a arma some da frente do olho" % par[0])
		ok(v.centro.distance_to(tela * 0.5) < 1.0 and v.raio > tela.y * 0.3 and v.raio < tela.y * 0.48, "%s: o vidro no centro da tela (raio %.0f px)" % [par[0], v.raio])
		ok(j._sens_luneta() < 0.5, "%s: olhar mais lento pela luneta (x%.2f)" % [par[0], j._sens_luneta()])
		var t_com := await _medir(40)
		ok(t_com < t_sem * 1.25, "%s: pela luneta o quadro não fica mais pesado (%.1f ms sem mirar · %.1f ms pela luneta)" % [par[0], t_sem, t_com])
		j._mirar_ligado = false
		await q(30)
		ok(not v.ativa and not v.visible and mod._ponto_fuzil.visible and j.camera.fov > esperado * 2.0, "%s: parou de mirar: volta ao normal (FOV %.0f°, arma à vista)" % [par[0], j.camera.fov])
	# 3ª pessoa
	j.primeira_pessoa = false
	await q(30)
	j._mirar_ligado = true
	await q(50)
	ok(j.em_luneta() and j.vista_luneta.ativa, "3ª pessoa: MIRAR vai para a luneta")
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
