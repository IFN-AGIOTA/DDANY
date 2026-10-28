extends SceneTree
# TESTE: MIRA DE FERRO E 1ª PESSOA (0.98). Mirando em 1ª pessoa, a MASSA de cada arma cai no centro da tela (onde o
# tiro vai) e as mãos alcançam a arma; sem mirar a arma aparece embaixo à direita; em 3ª pessoa MIRAR entra na mira
# de ferro (e com a opção "por cima do ombro" não entra); sem arma de fogo, os punhos aparecem em guarda.
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
func _tela(cam: Camera3D, p: Vector3) -> Vector2:
	var vs := root.get_visible_rect().size
	return cam.unproject_position(p) / vs                # 0..1 (0,5 = centro)
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
	var inv = j.inventario
	var mod = j._slot.get_node("Sobrevivente")
	var cam: Camera3D = j.camera
	var ad = mod._anexo("hand_r")
	j.primeira_pessoa = true
	j.cam_pit = 0.0
	await q(30)
	for arma in ["pistola", "mp5", "m4", "ak", "espingarda", "rifle_caca"]:
		if arma != "pistola":
			inv.equipar(Item.novo(arma), "maos")
		j._mirar_ligado = false
		await q(40)
		var no: Node3D = mod._ponto_fuzil.get_node_or_null("Arma_" + arma)
		ok(no != null and no.visible, "%s: em 1ª pessoa fica nas duas mãos (encaixe do fuzil)" % arma)
		if no == null:
			continue
		var dq: Array = MF.DADOS[arma]
		var pq := _tela(cam, no.global_transform * Vector3(0, (dq[1] as Vector2).x, (dq[1] as Vector2).y))
		ok(pq.x > 0.5 and pq.y > 0.5 and pq.x < 1.0 and pq.y < 1.0, "%s: sem mirar fica embaixo à direita, à vista (massa em %.2f, %.2f)" % [arma, pq.x, pq.y])
		j._mirar_ligado = true
		await q(50)
		var dd: Array = MF.DADOS[arma]
		var massa: Vector3 = no.global_transform * Vector3(0, (dd[1] as Vector2).x, (dd[1] as Vector2).y)
		var pm := _tela(cam, massa)
		ok(j.em_mira_ferro() and absf(pm.x - 0.5) < 0.012 and absf(pm.y - 0.5) < 0.012, "%s: mirando, a massa no centro da tela (%.3f, %.3f)" % [arma, pm.x, pm.y])
		var alvo_d: Vector3 = (mod._ponto_fuzil.global_transform * mod._ik.mao_dir).origin
		ok(ad.global_position.distance_to(alvo_d) < 0.06, "%s: a mão direita alcança a arma (%.2f m)" % [arma, ad.global_position.distance_to(alvo_d)])
		ok(j.camera.fov < j.fov_camera + 18.0 - 3.0, "%s: mirando, a câmera aproxima (FOV %.0f)" % [arma, j.camera.fov])
	j._mirar_ligado = false
	await q(20)
	# 3ª pessoa: MIRAR entra na mira de ferro
	j.primeira_pessoa = false
	await q(30)
	ok(j._fp < 0.05, "3ª pessoa sem mirar: câmera atrás")
	j._mirar_ligado = true
	await q(40)
	ok(j._fp > 0.95 and j.em_mira_ferro(), "3ª pessoa: MIRAR entra na mira de ferro")
	j._mirar_ligado = false
	await q(30)
	ok(j._fp < 0.05, "parou de mirar: volta para a 3ª pessoa")
	j.mira_ferro_3p = false
	j._mirar_ligado = true
	await q(40)
	ok(j._fp < 0.05 and not j.em_mira_ferro(), "opção \"por cima do ombro\": MIRAR não vai para a mira de ferro")
	j._mirar_ligado = false
	j.mira_ferro_3p = true
	# sem arma de fogo: punhos em guarda à vista
	j.primeira_pessoa = true
	inv.desequipar(inv.slots["maos"])
	await q(60)
	var dedo = mod._anexo("middle_01_r")
	await q(3)
	var ph := _tela(cam, dedo.global_position)
	ok(j.armas.atual == "punhos" and ph.x > 0.0 and ph.x < 1.0 and ph.y > 0.0 and ph.y < 1.0, "punhos: a mão direita aparece na tela (dedos em %.2f, %.2f)" % [ph.x, ph.y])
	print("[teste_mira_ferro] falhas: ", falhas)
	print("TUDO CERTO" if falhas == 0 else "ALGUM TESTE FALHOU")
	quit()
