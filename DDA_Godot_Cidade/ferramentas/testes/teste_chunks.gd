extends SceneTree
# TESTE: 1.00 · CHUNKS COM ORÇAMENTO EM TEMPO (mundo/chunks.gd, estudos/ESTUDO_AAA.md 1.13). Andando de um chunk
# para o outro: cada quadro gasta pouco (pode parar no meio de um chunk) · no fim, toda unidade (chunk + anel) que
# devia estar carregada está inteira na cena e nenhuma de fora ficou · com a mesma distância, o chunk da frente da
# câmera entra antes do de trás · trocar de chunk no meio de um carregamento não deixa chunk pela metade.
# 1.23 (estudos/ESTUDO_AAA.md 1.15) · ANÉIS: nenhum objeto que poderia aparecer (dentro do alcance dele, com o maior
# fator das opções) fica fora da cena; os de alcance curto NÃO ficam carregados longe · CAMADA DE VISIBILIDADE: girando
# a câmera (devagar e 180° de uma vez), nenhum objeto dentro da câmera e do alcance fica escondido; olhando para um
# lado, chunks do outro lado somem; desligada, nada fica escondido.
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

# [contêineres/nós que deviam estar na cena e não estão, que estão sem dever]
func _conferir(ch) -> Array:
	var faltam := 0
	var sobram := 0
	for u in ch._unid:
		var carregado: bool = ch._carregados.has(u)
		var dados: Array = ch._unid[u]
		var ct = dados[0]
		if ct != null and is_instance_valid(ct):
			if carregado and not ct.is_inside_tree():
				faltam += 1
			if not carregado and ct.is_inside_tree():
				sobram += 1
		if carregado:
			for n in dados[1]:
				if is_instance_valid(n) and not n.is_inside_tree():
					faltam += 1
	for n in ch._cont:
		if is_instance_valid(n) and int(ch._cont[n]) == 0 and n.is_inside_tree():
			sobram += 1
	return [faltam, sobram]

# todos os nós cuidados pelos chunks: [nó, contêiner ou null]
func _todos(ch) -> Array:
	var r := []
	for u in ch._unid:
		var dados: Array = ch._unid[u]
		if dados[0] != null:
			for n in (dados[0] as Node3D).get_children():
				r.append([n, dados[0]])
	for n in ch._cont:
		r.append([n, null])
	return r

# o nó poderia aparecer daqui? (alcance de agora: visibility_range_end; os da troca perto/longe, o "alcance_carga")
func _no_alcance(n: Node, cam_pos: Vector3, ch) -> bool:
	var al := 0.0
	if n is GeometryInstance3D and (n as GeometryInstance3D).visibility_range_end > 0.0:
		al = (n as GeometryInstance3D).visibility_range_end
	elif n.has_meta("alcance_carga"):
		al = float(n.get_meta("alcance_carga")) / ch.FATOR_ALCANCE
	# (sem alcance ou alcance maior: vale o raio de chunks, como antes; a câmera não enxerga além dele)
	var lim: float = (ch.raio - 1) * ch.TAM_CHUNK
	al = lim if al <= 0.0 else minf(al, lim)
	var a: AABB = (n as VisualInstance3D).transform * (n as VisualInstance3D).get_aabb()
	var p := Vector3(clampf(cam_pos.x, a.position.x, a.end.x), cam_pos.y, clampf(cam_pos.z, a.position.z, a.end.z))
	return Vector2(p.x - cam_pos.x, p.z - cam_pos.z).length() <= al

func _na_camera(a: AABB, planos: Array) -> bool:
	for pl in planos:
		var p: Plane = pl
		var v := Vector3(a.position.x if p.normal.x > 0.0 else a.end.x, a.position.y if p.normal.y > 0.0 else a.end.y, a.position.z if p.normal.z > 0.0 else a.end.z)
		if p.distance_to(v) > 0.0:
			return false
	return true

# nós dentro da câmera e do alcance que estão escondidos pela camada (deveria ser 0)
func _escondidos_na_tela(ch, cam: Camera3D) -> int:
	var planos: Array = cam.get_frustum()
	var ruins := 0
	for e in _todos(ch):
		var n: Node = e[0]
		var ct = e[1]
		if ct == null or not is_instance_valid(n) or not (n as Node3D).visible or not (ct as Node3D).is_inside_tree():
			continue
		if (ct as Node3D).visible:
			continue
		var a: AABB = (n as VisualInstance3D).transform * (n as VisualInstance3D).get_aabb()
		if _na_camera(a, planos) and _no_alcance(n, cam.global_position, ch):
			ruins += 1
	return ruins

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var ch = m.chunks
	var j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.ativo = false
	await q(30)
	ok(ch._fila.is_empty(), "no começo está tudo em dia")
	# anda 1 chunk para leste (o carregamento normal, no orçamento de tempo)
	var p0: Vector3 = j.global_position
	ch.us_maior = 0
	var p1 := p0 + Vector3(ch.TAM_CHUNK, 0, 0)
	m.mundo.forcar(Vector2(p1.x, p1.z))
	j.global_position = Vector3(p1.x, m.mundo.altura(p1.x, p1.z) + 0.2, p1.z)
	var quadros := 0
	while (quadros < 5 or not ch._fila.is_empty()) and quadros < 600:
		await process_frame
		quadros += 1
	print("  1 chunk andando: %d quadros, quadro mais caro %.2f ms (orçamento %.1f ms)" % [quadros, ch.us_maior / 1000.0, ch.ORCAMENTO_US / 1000.0])
	ok(ch.us_maior < ch.ORCAMENTO_US * 4, "cada quadro gasta pouco tirando/pondo nós (%.2f ms)" % (ch.us_maior / 1000.0))
	var c1: Array = _conferir(ch)
	ok(c1[0] == 0 and c1[1] == 0, "no fim nada falta e nada sobra (faltam %d, sobram %d)" % c1)
	# 1.23: anéis
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var fora_alcance := 0
	var longe_carregado := 0
	var curtos := 0
	for e in _todos(ch):
		var n: Node = e[0]
		if not is_instance_valid(n):
			continue
		var dentro: bool = (n as Node).is_inside_tree()
		if _no_alcance(n, cam.global_position, ch) and not dentro:
			fora_alcance += 1
		var al: float = ch.alcance_de(n)
		if al > 0.0 and al < 400.0:
			curtos += 1
			var a: AABB = (n as VisualInstance3D).transform * (n as VisualInstance3D).get_aabb()
			var p := Vector3(clampf(cam.global_position.x, a.position.x, a.end.x), 0.0, clampf(cam.global_position.z, a.position.z, a.end.z))
			if dentro and Vector2(p.x - cam.global_position.x, p.z - cam.global_position.z).length() > 3.0 * ch.TAM_CHUNK:
				longe_carregado += 1
	ok(fora_alcance == 0, "1.23: nenhum objeto que poderia aparecer daqui ficou fora da cena (%d)" % fora_alcance)
	ok(curtos > 1000 and longe_carregado == 0, "1.23: os de alcance curto (%d) não ficam na cena a mais de 1,5 km (%d ficaram)" % [curtos, longe_carregado])
	var est: Dictionary = ch.estatisticas()
	print("  estatísticas: ", est)
	ok(int(est["nos_na_cena"]) < int(est["nos_total"]) / 2, "1.23: menos da metade dos nós na cena (%d de %d)" % [est["nos_na_cena"], est["nos_total"]])
	# 1.23: camada de visibilidade girando a câmera
	var ruins_total := 0
	var fora_max := 0
	for g in 16:
		j.cam_yaw = g * TAU / 16.0
		await process_frame
		await process_frame
		cam = root.get_viewport().get_camera_3d()
		ruins_total += _escondidos_na_tela(ch, cam)
		fora_max = maxi(fora_max, ch.chunks_fora)
	ok(ruins_total == 0, "1.23: girando devagar, nada dentro da câmera ficou escondido (%d)" % ruins_total)
	ok(fora_max > 0, "1.23: olhando para um lado, chunks do outro lado somem (até %d)" % fora_max)
	# 180° de uma vez: no quadro seguinte nada da tela pode estar escondido
	var ruins_giro := 0
	for g in 4:
		j.cam_yaw = j.cam_yaw + PI
		await process_frame
		cam = root.get_viewport().get_camera_3d()
		ruins_giro += _escondidos_na_tela(ch, cam)
		await q(3)
	ok(ruins_giro == 0, "1.23: girando 180° de uma vez, nada da tela fica escondido no quadro seguinte (%d)" % ruins_giro)
	# desligada: nada fica escondido
	ch.camada_visibilidade = false
	await q(2)
	ok(ch._escondido.is_empty(), "1.23: com a camada desligada, nenhum chunk fica escondido")
	ch.camada_visibilidade = true
	await q(2)
	# ordem: com a mesma distância, a frente da câmera primeiro
	ch._dir = Vector2(0, -1)                         # olhando para o norte (-Z)
	var c := Vector2i(floori(p1.x / ch.TAM_CHUNK), floori(p1.z / ch.TAM_CHUNK))
	var salvo: Dictionary = ch._carregados.duplicate()
	for u in ch._carregados.keys():
		if Vector2i(u.x, u.y) == c + Vector2i(0, -1) or Vector2i(u.x, u.y) == c + Vector2i(0, 1):
			ch._carregados.erase(u)
	ch._refazer_fila(c)
	var ordem: Array = []
	for it in ch._fila:
		if it[1]:
			var k := Vector2i(it[0].x, it[0].y)
			if not ordem.has(k):
				ordem.append(k)
	ok(ordem.size() >= 2 and ordem.find(c + Vector2i(0, -1)) < ordem.find(c + Vector2i(0, 1)), "o chunk da frente entra antes do de trás (%s)" % [ordem])
	ch._fila.clear()
	ch._carregados = salvo
	ch.forcar(j.global_position)
	await q(3)
	# trocar de chunk no meio de um carregamento
	var p2 := p1 + Vector3(ch.TAM_CHUNK, 0, 0)
	j.global_position = Vector3(p2.x, m.mundo.altura(p2.x, p2.z) + 0.2, p2.z)
	await process_frame
	await process_frame
	var p3 := p2 + Vector3(0, 0, ch.TAM_CHUNK)
	j.global_position = Vector3(p3.x, m.mundo.altura(p3.x, p3.z) + 0.2, p3.z)
	var esp := 0
	while (esp < 5 or not ch._fila.is_empty()) and esp < 600:
		await process_frame
		esp += 1
	var c2: Array = _conferir(ch)
	ok(c2[0] == 0 and c2[1] == 0, "trocou de chunk no meio do carregamento: nada pela metade (faltam %d, sobram %d)" % c2)
	j.global_position = Vector3(p0.x, m.mundo.altura(p0.x, p0.z) + 0.2, p0.z)
	print("falhas: ", falhas)
	quit()
