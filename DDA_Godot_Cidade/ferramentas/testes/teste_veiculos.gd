extends SceneTree
# TESTE DOS VEÍCULOS (0.76): acha um carro que funciona perto do nascimento, abastece com um GALÃO, entra pelo PEGAR,
# acelera (joystick), vira, para, sai (fica estacionado e guardado no loot), entra de novo e atropela um infectado.
# FOTO=<prefixo> salva imagens.
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
func seg(s: float):                                      # tempo de JOGO (quadros de física), não do relógio
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame
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
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.clima.definir_hora(12.0)
	m.clima.set("parado", true)
	m.vagos.ativo = false
	var j = m.jogador
	var inv = j.inventario
	var vm = m.veiculos
	var I = load("res://inventario/item.gd")
	ok(vm._ids.size() > 50, "carros que funcionam na cidade: %d" % vm._ids.size())
	# o mais perto do nascimento (num lugar plano: rua)
	var melhor := ""
	var md := 1e9
	for vid in vm._ids:
		var c: Array = vm.ab.carros[vm._ids[vid]]
		var d: float = Vector2(c[0].x, c[0].z).distance_to(m.SPAWN)
		if d < md and d > 40.0:
			md = d
			melhor = vid
	var car: Array = vm.ab.carros[vm._ids[melhor]]
	print("carro ", melhor, " (", car[2], ") a ", int(md), " m do nascimento")
	var lado: Vector3 = car[0] + Basis(Vector3.UP, float(car[1])) * Vector3(0, 0, 2.6)
	m.mundo.forcar(Vector2(lado.x, lado.z))
	j.teleportar(Vector3(lado.x, m.mundo.altura(lado.x, lado.z) + 0.05, lado.z), 0.0)
	await q(30)
	ok(vm.perto == melhor, "perto do carro: botão ENTRAR (%s)" % vm.perto)
	m.tela_inventario._t_scan = 0.0
	await q(3)
	ok(str(m.controles.textos.get("PEGAR", "")).begins_with("ENTRAR") and not m.controles.ocultos.get("PEGAR", true), "PEGAR = ENTRAR NO CARRO")
	# abastece com um galão cheio
	var g = I.novo("galao")
	g.carga = 1.0
	for gg in inv.grades_do_jogador():
		var v: Vector3i = gg.achar_vaga(g)
		if v.x >= 0:
			gg.colocar(g, v.x, v.y, v.z == 1)
			break
	ok(inv.nome_acao(g) == "ABASTECER", "galão: botão ABASTECER")
	inv.usar(g)
	var veic = vm.nos.get(melhor)
	ok(veic != null and veic.combustivel >= 9.9 and g.carga < 0.01, "abasteceu: %.1f L no tanque, galão %.1f L" % [veic.combustivel if veic else -1.0, g.carga * 10.0])
	# entra
	j._pegar_do_chao()
	await q(10)
	ok(j.veiculo == veic and veic.ligado, "entrou e o motor ligou")
	ok(not j._slot.visible and m.controles.ocultos.get("ATIRAR", false), "boneco some e botões de arma somem")
	var p0: Vector3 = veic.global_position
	var inicio: Transform3D = veic.global_transform          # a reta do começo (o atropelamento é feito aqui)
	var c0: float = veic.combustivel
	m.controles.mover = Vector2(0, 1)
	await seg(4.0)
	var kmh: float = veic.velocidade_kmh()
	print("depois de 4 s acelerando: %.0f km/h, andou %.1f m, gasolina %.3f -> %.3f" % [kmh, veic.global_position.distance_to(p0), c0, veic.combustivel])
	ok(kmh > 20.0, "acelerou (%.0f km/h)" % kmh)
	ok(veic.global_position.distance_to(p0) > 15.0, "andou")
	ok(veic.combustivel < c0, "gastou gasolina")
	ok(j.global_position.distance_to(veic.global_position) < 1.2, "o jogador vai junto")
	await foto("dirigindo")
	var giro0: float = veic.rotation.y
	m.controles.mover = Vector2(1, 0.6)
	await seg(1.5)
	ok(absf(angle_difference(giro0, veic.rotation.y)) > 0.2, "virou (%.2f rad)" % angle_difference(giro0, veic.rotation.y))
	m.controles.mover = Vector2(0, -1)
	var n_f := 0
	while n_f < 240 and veic.linear_velocity.dot(veic.global_basis.z) > 0.8:
		await physics_frame
		n_f += 1                              # "para trás" andando para a frente = freio
	m.controles.mover = Vector2.ZERO
	await seg(1.0)
	ok(veic.velocidade_kmh() < 8.0, "freou (%.0f km/h)" % veic.velocidade_kmh())
	# sai
	j._pegar_do_chao()
	await q(10)
	ok(j.veiculo == null and j._slot.visible, "saiu do carro")
	ok(j.global_position.distance_to(veic.global_position) > 1.2, "saiu do lado do carro (%.1f m)" % j.global_position.distance_to(veic.global_position))
	ok(m.loot_mundo.veiculos.has(melhor), "carro estacionado guardado")
	var sv: Dictionary = JSON.parse_string(JSON.stringify(m.loot_mundo.salvar()))
	ok(sv.get("veiculos", {}).has(melhor), "vai no jogo salvo")
	await foto("estacionado")
	# entra de novo e atropela um infectado
	await q(20)
	ok(vm.perto == melhor, "perto do carro estacionado de novo")
	j._pegar_do_chao()
	await q(10)
	await foto("reentrou")
	if OS.get_environment("DBG") != "":
		var e0: Vector3 = veic.global_position
		var sp = veic.get_world_3d().direct_space_state
		var qq := PhysicsRayQueryParameters3D.create(e0 + Vector3(0, 0.3, 0), e0 + Vector3(0, -3, 0), 1, [veic.get_rid()])
		var rr: Dictionary = sp.intersect_ray(qq)
		print("  dbg embaixo do carro: ", rr.get("collider"), " em ", rr.get("position"), " · chão ", m.mundo.altura(e0.x, e0.z))
	veic.global_transform = inicio                           # volta para a reta do começo, parado
	veic.linear_velocity = Vector3.ZERO
	veic.angular_velocity = Vector3.ZERO
	await q(20)
	m.vagos.ativo = true
	var frente: Vector3 = veic.global_basis.z
	var alvo: Vector3 = veic.global_position + frente * 14.0      # perto: em 22 m o carro às vezes já desviou de lado
	m.vagos._criar(Vector3(alvo.x, m.mundo.altura(alvo.x, alvo.z) + 0.05, alvo.z), Vector3.INF)
	var inf = m.vagos.vivos.back()
	inf.set_physics_process(false)
	inf.set_process(false)
	m.controles.mover = Vector2(0, 1)
	var n_dbg := 0
	while n_dbg < 480 and is_instance_valid(inf) and inf.estado != 4:
		await physics_frame
		n_dbg += 1
		if n_dbg % 30 == 0 and OS.get_environment("DBG") != "":
			var dd: Vector3 = inf.global_position - veic.global_position
			print("  dbg frz %s lig %s slp %s ef %.0f br %.1f jv %s mot %s comb %.1f" % [veic.freeze, veic.ligado, veic.sleeping, veic.engine_force, veic.brake, j.veiculo == veic, veic.motorista != null, veic.combustivel]); print("  dbg dist %.1f frente %.2f vel %.0f inf_y %.2f car_y %.2f" % [Vector2(dd.x, dd.z).length(), Vector2(dd.x, dd.z).normalized().dot(Vector2(veic.global_basis.z.x, veic.global_basis.z.z)), veic.velocidade_kmh(), inf.global_position.y, veic.global_position.y])
	m.controles.mover = Vector2.ZERO
	ok(not is_instance_valid(inf) or inf.estado == 4 or inf.vida < 100.0, "atropelou o infectado")
	m.vagos.ativo = false
	j._pegar_do_chao()
	await q(10)
	print("falhas: ", falhas)
	quit()
