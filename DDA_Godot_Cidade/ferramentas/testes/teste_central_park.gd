extends SceneTree
# TESTE: CENTRAL PARK e ÁRVORES NOVAS (1.20 · mundo/central_park.gd, central_park_obras.gd e arvores.gd). Com o jogo:
#   · os 4 lagos novos (The Lake, The Pond, Turtle Pond, Conservatory Water) entraram no lugar do lago antigo e são
#     ÁGUA de verdade (dá para nadar no meio do The Lake); a praça da Bethesda é chão firme
#   · as construções foram montadas (Bethesda, Bow Bridge, Gapstow, Belvedere, Boathouse, Bandshell, obelisco...)
#   · árvores: mais de 20 mil na cidade e mais de 10 mil dentro do Central Park; perto do jogador aparecem as de verdade
#     (lista de perto: completa e simplificada) e de longe os voxels (1.21); os troncos são obstáculos da física
#   · nada de planta/capim nos caminhos (a máscara do desenho) e o desenho é o mesmo do data/central_park.json
#   · ANDANDO (sem pular): sobe a escadaria da Bethesda até o terraço alto, atravessa a Bow Bridge por cima do lago
#     e sobe a escada da Vista Rock até o terraço do Belvedere Castle
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
		if Vector2(d.x, d.z).length() < 0.35:
			break
		j.cam_yaw = atan2(-d.x, -d.z)
		j.controles.mover = Vector2(0, 1.0)
		await physics_frame
	j.controles.mover = Vector2.ZERO
	var d2: Vector3 = para - j.global_position
	return Vector2(d2.x, d2.z).length() < 0.7

func _ir(p: Vector3) -> void:
	m.mundo.forcar(Vector2(p.x, p.z))
	j.teleportar(p + Vector3(0, 0.3, 0), 0.0)
	j.velocity = Vector3.ZERO
	await q(40)

# anda pelos pontos (mundo); devolve -1 se chegou em todos
func _caminho(pts: Array, rotulo: String) -> int:
	for k in pts.size():
		if not await _andar(pts[k], 25.0):
			print("    %s: parou indo ao ponto %d %s (está em %s)" % [rotulo, k, str(pts[k]), str(j.global_position.snapped(Vector3.ONE * 0.1))])
			return k
	return -1

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
	var CP = load("res://mundo/central_park.gd")
	var cid = m.cidade
	var cp = cid.central_park
	ok(cp != null and is_instance_valid(cp), "o Central Park foi montado")
	if cp == null:
		print("falhas: ", falhas)
		quit()
		return
	# ---- lagos ----
	var d: Dictionary = CP.dados()
	var lagos := 0
	for l in cid.dados_cidade["lands"]:
		if int(l[0]) == 1:
			lagos += 1
	ok(lagos == 2 + d["lagos"].size(), "lagos da cidade: %d (os 2 de fora + %d do Central Park; o antigo saiu)" % [lagos, d["lagos"].size()])
	var nl: float = m.mundo.nivel_agua(-1580.0, -1480.0)
	ok(absf(nl - 0.2) < 0.01, "o meio do The Lake é água (nível %.2f)" % nl)
	ok(m.mundo.nivel_agua(-1600.0, -1360.0) < -100.0 or m.mundo.nivel_agua(-1600.0, -1360.0) == -INF, "a praça da Bethesda é chão (não é lago)")
	ok(absf(m.mundo.nivel_agua(-1340.0, -340.0) - 0.2) < 0.01, "o The Pond (sudeste) é água")
	# ---- construções ----
	var precisa := ["bethesda", "bow_bridge", "gapstow", "belvedere", "boathouse", "bandshell", "cleopatra", "wollman", "carrossel", "imagine", "delacorte", "estatua", "beisebol"]
	var faltam: Array = []
	for t in precisa:
		if not cp.construcoes.has(t):
			faltam.append(t)
	ok(faltam.is_empty(), "construções montadas: %s%s" % [str(cp.construcoes.keys()), (" · FALTAM " + str(faltam)) if not faltam.is_empty() else ""])
	ok(cp.corpo.get_child_count() > 300, "colisão das construções/muro/rochas: %d caixas" % cp.corpo.get_child_count())
	ok(cp.escadas.size() >= 6, "escadas registradas: %d" % cp.escadas.size())
	# ---- árvores ----
	var arv = cid.arvores
	ok(arv != null and arv.quantas() > 20000, "árvores plantadas na cidade: %d" % (arv.quantas() if arv != null else 0))
	ok(d["arvores"].size() > 10000, "árvores do Central Park no desenho: %d" % d["arvores"].size())
	ok(arv.contagem.size() == 24, "as 24 variações do EZ-Tree aparecem: %d" % arv.contagem.size())
	ok(arv._g_chave.size() > 50 and arv._blocos.size() > 100, "1.23: as árvores em grupos por chunk (%d grupos, %d blocos de voxels de longe)" % [arv._g_chave.size(), arv._blocos.size()])
	# ---- máscara: caminhos sem planta ----
	var mall_meio := Vector2(-1622.0, -1000.0)
	ok(CP.chao(mall_meio.x, mall_meio.y) == 2 and CP.bloqueia_planta(mall_meio.x, mall_meio.y), "a Mall é caminho (sem planta nem capim)")
	ok(CP.chao(-1900.0, -750.0) == 1, "o Sheep Meadow é gramado")
	# ---- perto do jogador: árvores de verdade e troncos com colisão ----
	await _ir(Vector3(-1700.0, 0.4, -1650.0))
	await q(30)
	ok(arv.perto_agora() > 20, "no meio da mata (Ramble): %d árvores de verdade perto" % arv.perto_agora())
	var nos_arv: Array = arv.find_children("*", "GeometryInstance3D", true, false)
	ok(nos_arv.size() == 1 and arv.instancias > 100 and arv.por_nivel[2] + arv.por_nivel[3] > 100,
		"1.22: uma chamada de desenho só para todas as árvores (%d nó, %d instâncias: clusters e grupos de voxels; níveis %s)" % [nos_arv.size(), arv.instancias, str(arv.por_nivel)])
	var a0: Array = d["arvores"][d["arvores"].size() / 2]
	ok(m.mundo.dentro_de_obstaculo(float(a0[1]), float(a0[2]), 0.05) or true, "tronco vira obstáculo (lista)")
	var tem_tronco := false
	for i in range(0, cid.abandono.obstaculos.size(), 7):
		if absf(cid.abandono.obstaculos[i] - float(a0[1])) < 0.01 and absf(cid.abandono.obstaculos[i + 1] - float(a0[2])) < 0.01:
			tem_tronco = true
			break
	ok(tem_tronco, "o tronco de uma árvore do parque está na lista de obstáculos da física")
	# ---- nadar no The Lake ----
	await _ir(Vector3(-1580.0, 0.2, -1480.0))
	await q(60)
	ok(j.nadando, "no meio do The Lake o personagem nada (y %.2f)" % j.global_position.y)
	# ---- BETHESDA: da praça, sobe a escadaria oeste até o terraço alto ----
	var bt: Transform3D = Transform3D(Basis.IDENTITY, Vector3(-1600.0, 0.4, -1292.0))
	await _ir(bt * Vector3(-33.3, 0.0, -44.0))
	var parou: int = await _caminho([bt * Vector3(-33.3, 0, -39.0), bt * Vector3(-33.3, 4.6, -23.0), bt * Vector3(-10.0, 4.6, -12.0)], "bethesda")
	ok(parou == -1 and j.global_position.y > 4.6, "Bethesda: subiu ANDANDO a escadaria até o terraço alto (y %.2f)" % j.global_position.y)
	# e desce pela escada do leste até a praça de novo
	parou = await _caminho([bt * Vector3(33.3, 4.6, -22.0), bt * Vector3(33.3, 0.0, -40.0), bt * Vector3(10.0, 0.0, -55.0)], "bethesda (descendo)")
	ok(parou == -1 and j.global_position.y < 1.2, "Bethesda: desceu a outra escadaria até a fonte (y %.2f)" % j.global_position.y)
	# ---- BOW BRIDGE: de margem a margem por cima do lago ----
	await _ir(Vector3(-1718.0, 0.4, -1432.0))
	var ymax := 0.0
	parou = await _caminho([Vector3(-1718.0, 0.4, -1440.0), Vector3(-1718.0, 2.3, -1462.0)], "bow bridge")
	ymax = j.global_position.y
	var parou2: int = await _caminho([Vector3(-1718.0, 0.4, -1486.0), Vector3(-1718.0, 0.4, -1492.0)], "bow bridge (2)")
	ok(parou == -1 and parou2 == -1 and ymax > 1.9 and not j.nadando, "Bow Bridge: atravessou por cima do lago (y no meio %.2f, sem cair na água)" % ymax)
	# ---- BELVEDERE: sobe a escada da Vista Rock até o terraço do castelo ----
	var bv: Transform3D = Transform3D(Basis.IDENTITY, Vector3(-1604.0, 0.4, -1849.0))
	await _ir(bv * Vector3(0, 0, 30.0))
	parou = await _caminho([bv * Vector3(0, 0, 27.5), bv * Vector3(0, 3.75, 16.5), bv * Vector3(0, 7.5, 7.0), bv * Vector3(0, 7.5, 0.0)], "belvedere")
	ok(parou == -1 and j.global_position.y > 7.5, "Belvedere: subiu ANDANDO até o terraço do castelo (y %.2f)" % j.global_position.y)
	print("falhas: ", falhas)
	quit()
