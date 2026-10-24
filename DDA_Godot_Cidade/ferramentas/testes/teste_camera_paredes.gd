extends SceneTree
# TESTE: A CÂMERA NÃO ATRAVESSA PAREDE (0.81). Em lugares apertados (patamar da escada de um prédio, corredor da
# delegacia), girando a câmera em volta, de pé e mirando, nos dois ombros: a câmera nunca fica dentro de nada e a
# linha do personagem até ela não passa por parede.
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

var m
var j

func _girar(nome: String) -> Array:
	var esp: PhysicsDirectSpaceState3D = j.get_world_3d().direct_space_state
	var esf := SphereShape3D.new()
	esf.radius = 0.08
	var pq := PhysicsShapeQueryParameters3D.new()
	pq.shape = esf
	pq.collision_mask = 1
	var ruins := 0
	var total := 0
	for mira in [false, true]:
		j._mirar_ligado = mira
		for lado in [1.0, -1.0]:
			j.ombro = lado
			for k in 8:
				j.cam_yaw = k * TAU / 8.0
				j.cam_pit = 0.15
				await q(12)
				var cam: Vector3 = j.camera.global_position
				var piv: Vector3 = j._pivo.global_position
				pq.transform = Transform3D(Basis.IDENTITY, cam)
				var dentro := not esp.intersect_shape(pq, 1).is_empty()
				var rq := PhysicsRayQueryParameters3D.create(piv, cam, 1, [j.get_rid()])
				var corta := not esp.intersect_ray(rq).is_empty()
				total += 1
				if dentro or corta:
					ruins += 1
					if ruins <= 3:
						print("    %s: giro %d mira %s ombro %d -> câmera %s %s" % [nome, k, mira, lado, "DENTRO" if dentro else "", "ATRÁS DA PAREDE" if corta else ""])
	j._mirar_ligado = false
	return [ruins, total]

# 0.89: TREMOR. Com tudo parado (ou girando devagar) a câmera não pode ficar pulando de um quadro para o outro.
# Mede o maior passo da câmera entre dois quadros: parada (deveria ser ~0) e girando 0.01 rad por quadro.
func _tremor(nome: String) -> Array:
	var pior_parado := 0.0
	var pior_giro := 0.0
	var vai_volta := 0                      # tremor de verdade: a distância encolhe e estica e encolhe de novo
	for mira in [false, true]:
		j._mirar_ligado = mira
		for k in 8:
			j.cam_yaw = k * TAU / 8.0
			j.cam_pit = 0.15
			await q(25)
			var antes: Vector3 = j.camera.global_position
			for f in 30:
				await q(1)
				var agora: Vector3 = j.camera.global_position
				pior_parado = maxf(pior_parado, agora.distance_to(antes))
				antes = agora
			# girando devagar: o passo esperado é ~ distância * 0.01; um pulo bem maior que isso é tremor
			var d_prev: float = (j.camera.global_position - j._pivo.global_position).length()
			var sinal_ant := 0
			for f in 40:
				j.cam_yaw += 0.01
				await q(1)
				var d: float = (j.camera.global_position - j._pivo.global_position).length()
				pior_giro = maxf(pior_giro, absf(d - d_prev))
				var sn := 0 if absf(d - d_prev) < 0.02 else (1 if d > d_prev else -1)
				if sn != 0:
					if sinal_ant != 0 and sn != sinal_ant:
						vai_volta += 1
					sinal_ant = sn
				d_prev = d
	j._mirar_ligado = false
	print("    %s: tremor parada %.3f m · maior pulo girando %.3f m · vai-e-volta %d" % [nome, pior_parado, pior_giro, vai_volta])
	return [pior_parado, pior_giro, vai_volta]

func _r():
	await q(20)
	m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.vagos.ativo = false
	j = m.jogador
	var cid = m.cidade
	var I = load("res://mundo/interior.gd")
	# 1. patamar da escada de um prédio com andares
	var feito := 0
	for i in cid.predio_info.size():
		var e: Dictionary = cid.predio_info[i]
		if not bool(e["entra"]) or Vector2(e["x"], e["z"]).distance_to(Vector2(436, 1500)) > 2500:
			continue
		var it = I.preparar(e, i, cid)
		if it.extras < 1:
			continue
		var c := Vector2(e["x"], e["z"])
		m.mundo.forcar(c)
		j.teleportar(Vector3(c.x + float(e["sx"]) * 0.5 + 6.0, m.mundo.altura(c.x, c.y) + 0.2, c.y), 0.0)
		m.interiores.abrir_agora(c)
		await q(10)
		var no: Node3D = m.interiores.abertos.get(i)
		if no == null:
			continue
		var es: Dictionary = it._esc()
		var w := (float(es["a"][0]) + float(es["b"][1])) * 0.5
		var p2: Vector2 = it._xz(-float(es["o"]) + 0.7, w)          # no patamar do fundo, entre a parede e a escada
		j.teleportar(no.global_transform * Vector3(p2.x, 0.1, p2.y), 0.0)
		await q(20)
		var r1: Array = await _girar("patamar")
		print("  patamar da escada (prédio %d): %d de %d posições ruins" % [i, r1[0], r1[1]])
		ok(r1[0] == 0, "patamar da escada: câmera não atravessa parede")
		var t1: Array = await _tremor("patamar")
		ok(t1[0] < 0.01, "patamar: câmera parada não treme (%.3f m)" % t1[0])
		ok(t1[2] <= 2, "patamar: girando, a câmera não fica indo e voltando (%d vezes)" % t1[2])
		m.interiores.fechar(i)
		feito += 1
		if feito >= 1:
			break
	# 2. corredor da delegacia (3 m de largura)
	var L = load("res://mundo/locais.gd")
	var c2 := Vector2(L.LOCAIS[28][1], L.LOCAIS[28][2])
	m.mundo.forcar(c2)
	var borda: Vector2 = L.local_para_mundo(28, Vector2(0, 25.0))
	j.teleportar(Vector3(borda.x, m.mundo.altura(borda.x, borda.y) + 0.2, borda.y), 0.0)
	await q(5)
	m.locais.abrir_agora(c2)
	await q(10)
	var nl: Node3D = m.locais.abertos.get(28)
	j.teleportar(nl.global_transform * Vector3(-14, 0.1, -9.5), 0.0)
	await q(20)
	var r2: Array = await _girar("corredor")
	print("  corredor da delegacia: %d de %d posições ruins" % [r2[0], r2[1]])
	ok(r2[0] == 0, "corredor: câmera não atravessa parede")
	var t2: Array = await _tremor("corredor")
	ok(t2[0] < 0.01, "corredor: câmera parada não treme (%.3f m)" % t2[0])
	ok(t2[2] <= 2, "corredor: girando, a câmera não fica indo e voltando (%d vezes)" % t2[2])
	print("falhas: ", falhas)
	quit()
