extends SceneTree
# TESTE: PORTOS e HANGARES DE CARGA (1.07, mundo/local_porto.gd). Com o jogo de verdade:
#   · os locais novos estão no fim da lista (2 portos na costa, 3 hangares) e montam com loot, infectados e escadas
#   · PORTO: o navio fica em cima do MAR; do portão, anda até o cais, sobe a ESCADA DE ACESSO até o convés, anda até o
#     casario e sobe a escada por fora (5 lances) até a PONTE DE COMANDO; sobe a escada do GUINDASTE (8 lances) até a
#     passarela do pórtico, 28 m — tudo andando, sem pular
#   · HANGAR: do pátio sobe a escada da plataforma das docas, entra por uma doca aberta e sobe ao MEZANINO; a bomba de
#     diesel enche o galão (grupo "bombas")
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

func _andar(para: Vector3, tempo: float) -> bool:
	var quadros := 0
	while quadros < int(tempo * 60.0):
		quadros += 1
		var d: Vector3 = para - j.global_position
		if Vector2(d.x, d.z).length() < 0.3:
			break
		j.cam_yaw = atan2(-d.x, -d.z)
		j.controles.mover = Vector2(0, 1.0)
		await physics_frame
	j.controles.mover = Vector2.ZERO
	var d2: Vector3 = para - j.global_position
	return Vector2(d2.x, d2.z).length() < 0.6

func _caminho(no: Node3D, pts: Array, rotulo: String) -> int:
	for k in pts.size():
		var p: Vector3 = no.global_transform * (pts[k] as Vector3)
		if not await _andar(p, 16.0):
			var lp: Vector3 = no.global_transform.affine_inverse() * j.global_position
			print("    %s: parou indo ao ponto %d %s (está em %s)" % [rotulo, k, str(pts[k]), str(lp.snapped(Vector3.ONE * 0.1))])
			for cc in j.get_slide_collision_count():
				var o = j.get_slide_collision(cc).get_collider()
				print("      bate em %s" % (str(o.name) if o != null else "?"))
			return k
	return -1

func _abrir(i: int, chegada: Vector3) -> Node3D:
	var L = load("res://mundo/locais.gd")
	var e: Array = L.LOCAIS[i]
	var c := Vector2(e[1], e[2])
	m.mundo.forcar(c)
	var g := Basis(Vector3.UP, int(e[3]) * PI * 0.5)
	var w: Vector3 = Vector3(c.x, 0.55, c.y) + g * chegada
	j.teleportar(w + Vector3(0, 0.3, 0), 0.0)
	j.velocity = Vector3.ZERO
	await q(20)
	m.locais.abrir_agora(c)
	await q(20)
	return m.locais.abertos.get(i)

func _y_local(no: Node3D) -> float:
	return (no.global_transform.affine_inverse() * j.global_position).y

func _r():
	await q(20)
	m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	m.vagos.diretor._t_horda = 9999.0
	m.clima.hora = 12.0
	var L = load("res://mundo/locais.gd")
	var LocalCls = load("res://mundo/local.gd")
	var portos: Array = []
	var hangares: Array = []
	for i in L.LOCAIS.size():
		if L.LOCAIS[i][0] == "porto":
			portos.append(i)
		elif L.LOCAIS[i][0] == "hangar":
			hangares.append(i)
	ok(portos.size() == 2 and hangares.size() == 3 and portos[0] >= L.N_LOCAIS_106, "2 portos e 3 hangares, no fim da lista")
	for i in portos + hangares:
		var e: Array = L.LOCAIS[i]
		var prep = LocalCls.preparar(String(e[0]), i, int(e[3]), Vector2(e[1], e[2]))
		var min_esc := 4 if e[0] == "porto" else 3                          # hangar: 2 da plataforma das docas + a do mezanino
		ok(prep.cont.size() >= 12 and prep.infectados.size() >= 8 and prep.escadas.size() >= min_esc and prep.col.size() > 100,
			"%s %d monta (%d caixas de loot, %d infectados, %d escadas, %d colisões)" % [e[0], i, prep.cont.size(), prep.infectados.size(), prep.escadas.size(), prep.col.size()])
	# o navio em cima do mar: o meio do casco (z -66 local) não é terra
	for i in portos:
		var pm: Vector2 = L.local_para_mundo(i, Vector2(0, -66))
		var pm2: Vector2 = L.local_para_mundo(i, Vector2(-60, -66))
		var pm3: Vector2 = L.local_para_mundo(i, Vector2(60, -66))
		ok(not m.cidade._em_terra(pm) and not m.cidade._em_terra(pm2) and not m.cidade._em_terra(pm3), "porto %d: o navio está em cima do mar" % i)
	# ---- PORTO: do portão até a ponte de comando e o alto do guindaste ----
	var pt: int = portos[0]
	var no: Node3D = await _abrir(pt, Vector3(-4.5, 0, 43.0))
	ok(no != null, "o porto abre perto")
	if no != null:
		var yd := 9.0
		var L0 := -55.275
		var L1 := -56.425
		var ate_conves := [Vector3(-4.5, 0, 30), Vector3(-4.5, 0, -28.5), Vector3(-20.0, 0, -28.5), Vector3(-20.0, 0, -49.0),
			Vector3(-31.0, 0, -51.9), Vector3(-14.6, yd, -51.9), Vector3(-14.4, yd, -53.4), Vector3(-14.4, yd, -55.2)]
		var parou := await _caminho(no, ate_conves, "porto (até o convés)")
		var yl := _y_local(no)
		ok(parou < 0 and absf(yl - yd) < 0.4, "porto: do portão até o cais e pela escada de acesso até o CONVÉS do navio (altura %.1f, convés %.1f)" % [yl, yd])
		if parou < 0:
			var ate_ponte := [Vector3(-49.0, yd, -55.2), Vector3(-49.5, yd, L1), Vector3(-63.0, yd, L1), Vector3(-63.0, yd, L0)]
			for k in 5:
				var y1 := yd + (k + 1) * 3.0
				if k % 2 == 0:
					ate_ponte.append(Vector3(-56.8, y1, L0))
					ate_ponte.append(Vector3(-56.8, y1, L1))
				else:
					ate_ponte.append(Vector3(-63.0, y1, L1))
					ate_ponte.append(Vector3(-63.0, y1, L0))
			ate_ponte.pop_back()
			ate_ponte.append(Vector3(-56.8, yd + 15.0, L1))
			ate_ponte.append(Vector3(-61.25, yd + 15.0, L1))
			ate_ponte.append(Vector3(-61.25, yd + 15.0, -59.0))
			parou = await _caminho(no, ate_ponte, "porto (casario)")
			yl = _y_local(no)
			ok(parou < 0 and absf(yl - (yd + 15.0)) < 0.4, "porto: sobe a escada do casario (5 lances) e entra na PONTE DE COMANDO (altura %.1f)" % yl)
		# guindaste do x = 5: torre de escada com o começo em x -12,13
		var xg := 5.0
		var z0 := -34.15
		var la := z0 + 0.575
		var lb := z0 + 1.725
		var gpts := [Vector3(-4.5, 0, -29.0)]
		j.teleportar(no.global_transform * Vector3(-4.5, 0.3, -29.0), 0.0)
		await q(20)
		gpts.append(Vector3(-13.0, 0, -29.0))
		gpts.append(Vector3(-13.0, 0, la))
		gpts.append(Vector3(-12.6, 0, la))
		for k in 8:
			var y1 := (k + 1) * 3.5
			if k % 2 == 0:
				gpts.append(Vector3(-4.5, y1, la))
				gpts.append(Vector3(-4.5, y1, lb))
			else:
				gpts.append(Vector3(-11.5, y1, lb))
				gpts.append(Vector3(-11.5, y1, la))
		gpts.append(Vector3(-4.3, 28.0, la))
		gpts.append(Vector3(-3.5, 28.0, -33.0))
		gpts.append(Vector3(xg - 4.0, 28.0, -33.0))
		parou = await _caminho(no, gpts, "guindaste")
		yl = _y_local(no)
		ok(parou < 0 and absf(yl - 28.0) < 0.4, "porto: sobe a escada do GUINDASTE (8 lances) até a passarela do pórtico, a 28 m (altura %.1f)" % yl)
		m.locais.fechar(pt)
		await q(5)
	# ---- HANGAR: do pátio até o mezanino ----
	var hg: int = hangares[0]
	var hn: Node3D = await _abrir(hg, Vector3(-30.0, 0, 21.0))
	ok(hn != null, "o hangar abre perto")
	if hn != null:
		var D := 1.2
		var ym := D + 3.6
		var hp := [Vector3(-33.9, 0, 8.0), Vector3(-33.9, D, 4.0), Vector3(4.0, D, 4.0), Vector3(4.0, D, -2.0), Vector3(4.0, D, -8.0),
			Vector3(-17.0, D, -8.0), Vector3(-17.0, D, -12.6),
			Vector3(-17.0, ym, -20.6), Vector3(-20.0, ym, -24.0)]
		var parou := await _caminho(hn, hp, "hangar")
		var yl := _y_local(hn)
		ok(parou < 0 and absf(yl - ym) < 0.4, "hangar: do pátio sobe à doca, entra por uma doca aberta e sobe ao MEZANINO (altura %.1f)" % yl)
		var bombas := 0
		for b in root.get_tree().get_nodes_in_group("bombas"):
			if hn.is_ancestor_of(b):
				bombas += 1
		ok(bombas == 1, "hangar: a bomba de diesel enche o galão (%d no grupo \"bombas\")" % bombas)
		m.locais.fechar(hg)
	print("falhas: ", falhas)
	quit()
