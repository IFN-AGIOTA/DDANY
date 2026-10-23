extends SceneTree
# TESTE DOS LOCAIS NOVOS (0.78): delegacia, escola, estação do metrô e quartel. Para o primeiro de cada tipo: monta,
# confere colisão/loot/letreiros, se nenhum ponto de infectado ou de loot ficou DENTRO de parede/móvel, e anda com o
# jogador pelas escadas (até o andar de cima, o telhado, a plataforma do metrô, a rampa caída, a torre de vigia).
# FOTO=<prefixo> salva fotos de cada local (de fora, de cima e de dentro).
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

# [tipo, [[nome, início local (x, y, z), direção local (x, z), altura que tem de chegar], ...]]
const SUBIDAS := {
	"delegacia": [["escada do térreo", Vector3(-1.5, 0.0, -9.8), Vector2(0, -1), 4.4], ["escada do telhado", Vector3(1.5, 4.65, -19.0), Vector2(0, 1), 9.0]],
	"escola": [["escada do térreo", Vector3(-8.2, 0.0, -11.4), Vector2(0, -1), 4.4], ["escada do telhado", Vector3(-5.8, 4.65, -21.0), Vector2(0, 1), 9.0]],
	"metro": [["escada da frente", Vector3(11.6, 0.0, 5.2), Vector2(-1, 0), 6.9], ["escada de trás", Vector3(-15.6, 0.0, -9.2), Vector2(1, 0), 6.9],
		["rampa caída", Vector3(31.0, 0.0, -2.0), Vector2(-1, 0), 5.6], ["degraus trilho -> plataforma", Vector3(20.8, 6.05, -1.2), Vector2(0, -1), 6.9]],
	"quartel": [["torre de vigia", Vector3(-27.0, 0.0, 7.5), Vector2(0, 1), 5.8], ["escada do alojamento", Vector3(-5.0, 0.0, -22.2), Vector2(-1, 0), 3.7]],
}

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.clima.definir_hora(13.0)
	m.clima.set("parado", true)
	m.vagos.ativo = false
	var L = load("res://mundo/locais.gd")
	var j = m.jogador
	var foto := OS.get_environment("FOTO")
	var feitos := {}
	for i in L.LOCAIS.size():
		var tipo: String = L.LOCAIS[i][0]
		if not SUBIDAS.has(tipo) or feitos.has(tipo) or (OS.get_environment("TIPO") != "" and OS.get_environment("TIPO") != tipo):
			continue
		feitos[tipo] = true
		print("== ", tipo, " (local ", i, ")")
		var c: Vector2 = Vector2(L.LOCAIS[i][1], L.LOCAIS[i][2])
		m.mundo.forcar(c)
		var borda: Vector2 = L.local_para_mundo(i, Vector2(0, (L.TAMANHO[tipo] as Vector2).y * 0.5 + 2.0))
		j.teleportar(Vector3(borda.x, m.mundo.altura(borda.x, borda.y) + 0.1, borda.y), 0.0)
		m.locais.abrir_agora(c)
		await q(30)
		var no: Node3D = m.locais.abertos.get(i)
		ok(no != null, "montado")
		if no == null:
			continue
		var corpo: StaticBody3D = no.get_node("Colisao")
		var n_col := corpo.get_child_count()
		var n_cont := 0
		var n_txt := 0
		for f in no.get_children():
			if f is Label3D: n_txt += 1
			elif f.get("grade") != null: n_cont += 1
		print("  colisão: ", n_col, " caixas · loot: ", n_cont, " lugares · letreiros: ", n_txt)
		ok(n_col > 150 and n_cont >= 12, "colisão e loot")
		ok(n_txt >= 1, "letreiro/pichação")
		# pontos de infectados e de loot solto: nada dentro de parede ou móvel
		var prep = load("res://mundo/local.gd").preparar(tipo, i, int(L.LOCAIS[i][3]), c)
		var esfera := SphereShape3D.new()
		esfera.radius = 0.28
		var pq := PhysicsShapeQueryParameters3D.new()
		pq.shape = esfera
		pq.collision_mask = 1
		var espaco: PhysicsDirectSpaceState3D = j.get_world_3d().direct_space_state
		var ruins := []
		var pts: Array = []
		for p in prep.infectados:
			pts.append(["infectado", p])
		for p in prep.pontos:
			pts.append(["loot " + String(p[1]), p[0]])
		for e in pts:
			for h in [0.5, 1.2]:
				pq.transform = Transform3D(Basis.IDENTITY, no.global_transform * ((e[1] as Vector3) + Vector3(0, h, 0)))
				var bate := false
				for r in espaco.intersect_shape(pq, 8):
					if r["collider"] == corpo:
						bate = true
				if bate:
					ruins.append("%s %s" % [e[0], str(e[1])])
					break
		ok(ruins.is_empty(), "%d pontos de infectado/loot livres%s" % [pts.size(), "" if ruins.is_empty() else " · DENTRO DE ALGO: " + ", ".join(ruins)])
		# subidas
		for s in SUBIDAS[tipo]:
			var ini: Vector3 = no.global_transform * (s[1] as Vector3)
			var d2: Vector2 = s[2]
			var d3: Vector3 = no.global_transform.basis * Vector3(d2.x, 0, d2.y)
			j.teleportar(ini + Vector3(0, 0.15, 0), atan2(-d3.x, -d3.z))
			if j.morto or j.sobrevivencia.desmaiado > 0.0:
				print("  (jogador morto/desmaiado antes da subida)")
			j.sobrevivencia.vida = 100.0
			j.sobrevivencia.desmaiado = 0.0
			j.sobrevivencia.parado = 0.0
			await q(5)
			var y0: float = no.global_position.y
			var maxy := -INF
			m.controles.mover = Vector2(0, 1)
			for k in 300:
				await physics_frame
				maxy = maxf(maxy, j.global_position.y - y0)
			m.controles.mover = Vector2.ZERO
			var andou := Vector2(j.global_position.x - ini.x, j.global_position.z - ini.z).length()
			ok(maxy >= float(s[3]), "%s: subiu até %.2f m (precisa %.1f) · andou %.1f m" % [s[0], maxy, float(s[3]), andou])
		# fotos: de fora (da rua), de cima e do alto da primeira subida
		if foto != "":
			var cam := Camera3D.new()
			root.add_child(cam)
			cam.fov = 70.0
			cam.near = 0.3                     # igual à câmera do jogador (com 0,05 o chão do lote "fura" o asfalto)
			cam.far = 3000.0
			var t: Vector2 = L.TAMANHO[tipo]
			var poses := [
				[Vector3(t.x * 0.15, 9.0, t.y * 0.5 + 26.0), Vector3(0, 3.0, -4.0)],
				[Vector3(-t.x * 0.65, 30.0, t.y * 0.75), Vector3(0, 0.0, -2.0)],
				[Vector3(t.x * 0.55, 14.0, -t.y * 0.55 - 8.0), Vector3(0, 2.0, 0.0)],
			]
			for k in poses.size():
				cam.global_position = no.global_transform * (poses[k][0] as Vector3)
				cam.look_at(no.global_transform * (poses[k][1] as Vector3))
				cam.make_current()
				await q(12)
				root.get_texture().get_image().save_png("%s_%s_%d.png" % [foto, tipo, k])
			cam.queue_free()
			j.teleportar(no.global_transform * ((SUBIDAS[tipo][0][1] as Vector3) + Vector3(0, 0.15, 0)), 0.0)
			j.get_viewport().get_camera_3d()
			await q(5)
			var cj: Camera3D = j.get_node_or_null("Camera3D")
			if cj == null:
				for f in j.find_children("*", "Camera3D", true, false):
					cj = f
			if cj != null:
				cj.make_current()
			await q(10)
			root.get_texture().get_image().save_png("%s_%s_jogador.png" % [foto, tipo])
		m.locais.fechar(i)
		await q(5)
	ok(feitos.size() == 4 or OS.get_environment("TIPO") != "", "os 4 tipos novos estão na lista LOCAIS")
	# jogo salvo da 0.68..0.77: a numeração dos prédios mudou (saíram os do terreno dos locais novos)
	var cid = m.cidade
	var r3: PackedInt32Array = cid.remapa_v3
	var saiu := 0
	var ultimo := -1
	var crescente := true
	for k in r3:
		if k < 0:
			saiu += 1
		else:
			crescente = crescente and k > ultimo
			ultimo = k
	print("prédios: ", cid.predio_info.size(), " · na 0.77: ", r3.size(), " · saíram para os locais novos: ", saiu)
	ok(saiu > 0 and r3.size() - saiu == cid.predio_info.size() and crescente, "tabela 0.77 -> 0.78 dos prédios bate")
	var Sv = load("res://menu/salvamento.gd")
	var velho := -1
	for k in r3.size():
		if r3[k] >= 0 and r3[k] != k:
			velho = k
			break
	var conv: Dictionary = Sv._remapear_loot({"grades": {"p%d_2" % velho: [], "L3_1": []}, "portas": {"p%d:1" % velho: 1}, "chao": {}}, r3)
	ok(conv["grades"].has("p%d_2" % r3[velho]) and conv["grades"].has("L3_1") and conv["portas"].has("p%d:1" % r3[velho]),
		"loot/porta do prédio %d (0.77) vai para o %d" % [velho, r3[velho]])
	ok(Sv._remapear_id("p%d:0" % velho, r3) == "p%d:0" % r3[velho] and Sv._remapear_id("c12", r3) == "c12", "ids do chão e dos carros")
	print("FPS ", Engine.get_frames_per_second(), " · falhas: ", falhas)
	quit()
