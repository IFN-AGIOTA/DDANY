extends SceneTree
# TESTE DE REDE DOS VEÍCULOS (0.76), parte do AMIGO: entra na partida, vai até o carro que funciona mais perto,
# abastece, entra, acelera 4 s e sai.
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func _r():
	for i in 30: await process_frame
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	await create_timer(8.0).timeout
	root.get_node("Rede").entrar("127.0.0.1", "Cli")
	var t := 0.0
	while not root.get_node("Rede").partida_comecou and t < 60.0:
		await create_timer(0.5).timeout
		t += 0.5
	m._jogar()
	while m.jogador == null: await process_frame
	var j = m.jogador
	var vm = m.veiculos
	var melhor := ""
	var md := 1e9
	for vid in vm._ids:
		var c: Array = vm.ab.carros[vm._ids[vid]]
		var d: float = Vector2(c[0].x, c[0].z).distance_to(m.SPAWN)
		if d < md and d > 40.0:
			md = d
			melhor = vid
	var car: Array = vm.ab.carros[vm._ids[melhor]]
	var lado: Vector3 = car[0] + Basis(Vector3.UP, float(car[1])) * Vector3(0, 0, 2.6)
	m.mundo.forcar(Vector2(lado.x, lado.z))
	j.teleportar(Vector3(lado.x, m.mundo.altura(lado.x, lado.z) + 0.05, lado.z), 0.0)
	await create_timer(2.0).timeout
	var v = vm._montar(melhor)
	v.combustivel = 20.0
	j._pegar_do_chao()
	await create_timer(1.0).timeout
	print("CLI: dirigindo ", j.veiculo != null)
	m.controles.mover = Vector2(0, 1)
	await create_timer(4.0).timeout
	m.controles.mover = Vector2(0, -1)
	await create_timer(2.0).timeout
	m.controles.mover = Vector2.ZERO
	await create_timer(1.0).timeout
	j._pegar_do_chao()
	print("CLI: saiu ", j.veiculo == null)
	await create_timer(6.0).timeout
	quit()
