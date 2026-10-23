extends SceneTree
# TESTE: INFECTADOS NÃO ATRAVESSAM OBJETOS (0.79). Um infectado PERSEGUINDO o jogador dentro de um local especial
# (delegacia: do saguão até o arsenal; posto: de fora até a loja) nunca pode ficar dentro de parede/móvel/carro.
# Também confere as consultas de quem anda sem física: carro que funciona e construções dos locais.
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

# [local, onde fica o jogador (local), onde nasce o infectado (local)]
const CASOS := [[28, Vector3(-8, 0, -15), Vector3(0, 0, -3), "delegacia: saguão -> arsenal"],
	[28, Vector3(16, 4.6, -6), Vector3(6, 0, 8), "delegacia: estacionamento -> dormitório (escada)"],
	[0, Vector3(-14, 0, -9), Vector3(-14, 0, 12), "posto: pátio -> loja"]]

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.clima.definir_hora(13.0)
	m.vagos.ativo = false
	var L = load("res://mundo/locais.gd")
	var j = m.jogador
	var esfera := SphereShape3D.new()
	esfera.radius = 0.12
	var pq := PhysicsShapeQueryParameters3D.new()
	pq.shape = esfera
	pq.collision_mask = 1
	for caso in CASOS:
		var i: int = caso[0]
		print("== ", caso[3])
		var c := Vector2(L.LOCAIS[i][1], L.LOCAIS[i][2])
		m.mundo.forcar(c)
		var borda: Vector2 = L.local_para_mundo(i, Vector2(0, (L.TAMANHO[L.LOCAIS[i][0]] as Vector2).y * 0.5 + 2.0))
		j.teleportar(Vector3(borda.x, m.mundo.altura(borda.x, borda.y) + 0.1, borda.y), 0.0)
		m.locais.abrir_agora(c)
		await q(20)
		var no: Node3D = m.locais.abertos.get(i)
		var corpo: StaticBody3D = no.get_node("Colisao")
		j.teleportar(no.global_transform * (caso[1] as Vector3) + Vector3(0, 0.1, 0), 0.0)
		j.sobrevivencia.vida = 100.0
		await q(30)
		# limpa os infectados do local e cria um só
		for v in m.vagos.vivos.duplicate():
			v.queue_free()
		m.vagos.vivos.clear()
		await q(2)
		m.vagos.ativo = true
		m.vagos.max_ativos = 0                     # não nasce nenhum outro
		var ini: Vector3 = no.global_transform * (caso[2] as Vector3)
		m.vagos._criar(ini + Vector3(0, 0.05, 0), Vector3.INF)
		var inf = m.vagos.vivos.back()
		inf.perseguir()
		var dentro := 0
		var max_seguidos := 0
		var seguidos := 0
		var com_fisica := 0
		var dmin := INF
		var n := 0
		while n < 600 and is_instance_valid(inf):
			await physics_frame
			n += 1
			j.sobrevivencia.vida = 100.0
			inf.perseguir()
			inf._t_sem_ver = 0.0                   # sabe onde o jogador está (ouviu): vai direto atrás dele
			if inf._fisica:
				com_fisica += 1
			pq.transform = Transform3D(Basis.IDENTITY, inf.global_position + Vector3(0, 0.9, 0))
			var bate := false
			for r in j.get_world_3d().direct_space_state.intersect_shape(pq, 4):
				if r["collider"] == corpo:
					bate = true
			if bate:
				dentro += 1
				seguidos += 1
				max_seguidos = maxi(max_seguidos, seguidos)
			else:
				seguidos = 0
			dmin = minf(dmin, inf.global_position.distance_to(j.global_position))
			if n % 120 == 0 and OS.get_environment("DBG") != "":
				print("  dbg estado %d vel_alvo %.1f destino %s pos %s alvo %s proc %s modo %s" % [inf.estado, inf._vel_alvo, str(inf._destino), str(inf.global_position), str(inf._alvo), inf.is_physics_processing(), inf.process_mode])
		print("  quadros: %d · com física: %d · dentro de algo: %d (seguidos %d) · chegou a %.1f m do jogador" % [n, com_fisica, dentro, max_seguidos, dmin])
		ok(com_fisica > n * 0.9, "perseguindo perto = com física")
		ok(max_seguidos <= 3, "não atravessou parede/móvel")
		if is_instance_valid(inf):
			inf.queue_free()
		m.vagos.vivos.clear()
		m.locais.fechar(i)
		await q(5)
	# quem anda sem física: carro que funciona e construções dos locais
	var V = load("res://mundo/veiculo.gd")
	var carro = V.new()
	m.jogo.add_child(carro)
	carro.global_position = j.global_position + Vector3(10, 0, 0)
	m.veiculos.nos["teste"] = carro
	await q(2)
	var pc: Vector3 = carro.global_position
	ok(m.vagos.dentro_de_veiculo(pc.x, pc.z + 1.5) and not m.vagos.dentro_de_veiculo(pc.x + 3.0, pc.z), "carro que funciona bloqueia quem anda sem física")
	m.veiculos.nos.erase("teste")
	carro.queue_free()
	var v0: Vector3 = L.casca("delegacia")[0][0]
	var cd: Vector2 = L.local_para_mundo(28, Vector2(v0.x, v0.z))
	ok(L.em_construcao(cd) and not L.em_construcao(cd + Vector2(400, 400)), "construção do local bloqueia quem anda sem física")
	print("falhas: ", falhas)
	quit()
