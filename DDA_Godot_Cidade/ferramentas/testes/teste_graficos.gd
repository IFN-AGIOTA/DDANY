extends SceneTree
# TESTE: OPÇÕES DE GRÁFICOS QUE ESTAVAM "EM BREVE" (0.84) — cada uma muda alguma coisa de verdade no jogo:
#   texturas e filtragem anisotrópica (shader do chão), modelos (alcance dos objetos da rua), efeitos (fumaça no
#   horizonte e poeira/marcas dos tiros), fios de poste e halos de luz (só à noite)
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

func _aplicar(m, mudar: Dictionary) -> void:
	var g: Dictionary = root.get_node("Config").g.duplicate()
	for k in mudar:
		g[k] = mudar[k]
	root.get_node("Config").aplicar_graficos(g)

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.vagos.ativo = false
	var cid = m.cidade
	var ab = cid.abandono
	var LR = load("res://mundo/luzes_rua.gd")
	# ---- texturas e anisotrópica ----
	await _aplicar(m, {"tex": 0, "aniso": 1})
	await q(2)
	var m0: ShaderMaterial = cid.mats_chao[0]
	var v0: float = m0.get_shader_parameter("vies_tex")
	await _aplicar(m, {"tex": 3, "aniso": 16})
	await q(2)
	ok(v0 > 1.0 and float(m0.get_shader_parameter("vies_tex")) == 0.0 and float(m0.get_shader_parameter("aniso")) == 16.0,
		"texturas/anisotrópica mudam o shader do chão (vies %.1f -> %.1f, aniso %s)" % [v0, m0.get_shader_parameter("vies_tex"), m0.get_shader_parameter("aniso")])
	# ---- modelos ----
	var no = null
	for n in ab.nos:
		if n.name.begins_with("sedan") and n.visibility_range_end > 0.0:
			no = n
			break
	await _aplicar(m, {"models": 0})
	await q(2)
	var a0: float = no.visibility_range_end
	await _aplicar(m, {"models": 3})
	await q(2)
	ok(a0 > 0.0 and no.visibility_range_end > a0 * 2.0, "modelos: alcance dos carros %.0f -> %.0f m" % [a0, no.visibility_range_end])
	# ---- fios e halos ----
	var fios: Array = get_nodes_in_group("fios_poste")
	var halos: Array = get_nodes_in_group("halos_luz")
	print("  blocos com fios %d · com halos %d · fios %d · halos %d" % [ab.nos_fios.size(), ab.nos_halos.size(), ab.fios.size(), ab.halos.size()])
	ok(ab.fios.size() > 500 and ab.halos.size() > 300, "a cidade tem fios entre os postes e halos")
	await _aplicar(m, {"wire": false, "halo": false})
	await q(2)
	var algum := false
	for n in ab.nos_fios + ab.nos_halos:
		if n.visible:
			algum = true
	ok(not algum, "fios e halos desligados somem")
	await _aplicar(m, {"wire": true, "halo": true})
	await q(2)
	ok(ab.nos_fios[0].visible and bool(LR.opcao_halos), "fios e halos ligados aparecem")
	m.clima.definir_hora(13.0)
	await q(70)
	var dia: float = LR.material().get_shader_parameter("noite")
	var vis_dia: bool = ab.nos_halos[0].visible
	m.clima.definir_hora(23.5)
	await q(70)
	var noite: float = LR.material().get_shader_parameter("noite")
	var vis_noite: bool = ab.nos_halos[0].visible
	ok(dia < 0.05 and noite > 0.6 and not vis_dia and vis_noite, "halos só à noite (dia %.2f · noite %.2f · desenhados de dia: %s)" % [dia, noite, vis_dia])
	# ---- efeitos ----
	var fu = m.jogo.get_node("Fumaca")
	await _aplicar(m, {"fx": 0})
	await q(2)
	var vis0 := 0
	for c in fu.get_children():
		if c.visible:
			vis0 += 1
	var ef = m.jogador.armas.efeitos
	var nfx0: int = ef.nivel_fx
	await _aplicar(m, {"fx": 3})
	await q(2)
	var vis3 := 0
	for c in fu.get_children():
		if c.visible:
			vis3 += 1
	ok(vis0 == 0 and vis3 == fu.colunas and nfx0 == 0 and ef.nivel_fx == 3, "efeitos: fumaça no horizonte %d -> %d colunas · tiros %d -> %d" % [vis0, vis3, nfx0, ef.nivel_fx])
	# foto de noite numa rua (halos, fios e o chão com anisotrópica)
	if OS.get_environment("FOTO") != "":
		var e: Array = ab.halos[ab.halos.size() / 3]
		var p: Vector3 = e[0]
		m.mundo.forcar(Vector2(p.x, p.z))
		m.jogador.teleportar(Vector3(p.x + 8.0, m.mundo.altura(p.x + 8.0, p.z) + 0.1, p.z), 0.0)
		await q(60)
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.far = 900.0
		cam.make_current()
		cam.global_position = p + Vector3(25, -4.0, 12)
		cam.look_at(p + Vector3(0, -3.0, 0))
		await q(10)
		root.get_texture().get_image().save_png(OS.get_environment("FOTO") + "_noite.png")
		m.clima.definir_hora(12.0)
		await q(70)
		root.get_texture().get_image().save_png(OS.get_environment("FOTO") + "_dia.png")
		cam.global_position = p + Vector3(6, -5.5, 6)
		cam.look_at(p + Vector3(-60, -7.0, -40))
		for af in [1, 16]:
			await _aplicar(m, {"aniso": af, "tex": 3})
			await q(6)
			root.get_texture().get_image().save_png(OS.get_environment("FOTO") + "_chao_%d.png" % af)
	print("falhas: ", falhas)
	quit()
