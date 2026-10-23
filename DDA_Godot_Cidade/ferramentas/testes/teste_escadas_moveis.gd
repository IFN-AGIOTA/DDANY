extends SceneTree
# TESTE DO PREENCHIMENTO DOS PRÉDIOS E DAS ESCADAS (0.81)
#   PRÉDIOS COM INTERIOR (mundo/interior.gd): em prédios de 2 e 3 andares, de onde cada lance da escada chega dá para
#   andar (cápsula do jogador, grade de 0,5 m) até os cômodos daquele andar; nenhum móvel cruza parede; nenhuma
#   divisória encosta na fachada em cima de porta/janela.
#   LOCAIS ESPECIAIS (mundo/local.gd): o topo de cada escada tem chão livre na frente (não dá de cara com parede).
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

var espaco: PhysicsDirectSpaceState3D
var pq: PhysicsShapeQueryParameters3D
var rq: PhysicsRayQueryParameters3D

# dá para ficar de pé em p (mundo)? chão logo abaixo e a cápsula não bate em nada
func _de_pe(p: Vector3) -> bool:
	rq.from = p + Vector3(0, 0.45, 0)
	rq.to = p + Vector3(0, -0.5, 0)
	var r := espaco.intersect_ray(rq)
	if r.is_empty():
		return false
	var chao: Vector3 = r["position"]
	pq.transform = Transform3D(Basis.IDENTITY, chao + Vector3(0, 1.15, 0))
	return espaco.intersect_shape(pq, 1).is_empty()

# busca andando (BFS) no plano y a partir de "ini"; devolve as células alcançadas
func _alcance(ini: Vector3, rect: Rect2, y: float, raiz: Node3D) -> Dictionary:
	var vis := {}
	var fila: Array[Vector2i] = []
	var passo := 0.5
	var c0 := Vector2i(roundi(ini.x / passo), roundi(ini.z / passo))
	fila.append(c0)
	vis[c0] = true
	var n := 0
	while not fila.is_empty() and n < 6000:
		var c: Vector2i = fila.pop_front()
		n += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if vis.has(v):
				continue
			var pl := Vector3(v.x * passo, y, v.y * passo)
			if not rect.has_point(Vector2(pl.x, pl.z)):
				continue
			if _de_pe(raiz.global_transform * pl):
				vis[v] = true
				fila.append(v)
	return vis

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.vagos.ativo = false
	var j = m.jogador
	espaco = j.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.26
	cap.height = 1.3
	pq = PhysicsShapeQueryParameters3D.new()
	pq.shape = cap
	pq.collision_mask = 1
	rq = PhysicsRayQueryParameters3D.new()
	rq.collision_mask = 1
	var cid = m.cidade
	var I = load("res://mundo/interior.gd")
	# ---- prédios com interior ----
	var lista := []
	for i in cid.predio_info.size():
		var e: Dictionary = cid.predio_info[i]
		if bool(e["entra"]) and Vector2(e["x"], e["z"]).distance_to(Vector2(436, 1500)) < 2500:
			lista.append(i)
	var com_escada := 0
	var nivel_ruim := 0
	var niveis := 0
	var cruzando := 0
	var encontros_ruins := 0
	var moveis := 0
	var vistos := 0
	for i in lista:
		var e: Dictionary = cid.predio_info[i]
		var it = I.preparar(e, i, cid)
		vistos += 1
		# móveis x paredes e divisórias x aberturas (no térreo, que tem as mesmas regras dos andares)
		for o in it.ocupado:
			moveis += 1
			for mu in it._muros:
				if float(mu[1]) < 1.0 and (mu[0] as Rect2).intersects((o as Rect2).grow(-0.03)):
					cruzando += 1
					break
		for mu in it._muros:
			var rr: Rect2 = mu[0]
			if minf(rr.size.x, rr.size.y) > 0.2 or float(mu[1]) > 0.1:
				continue                               # só paredes de dentro (finas) que vão do chão
			for f in 4:
				var nn: Vector2 = it._n(f)
				var face: float = it._meia(f) - it.ESP
				for ponta in [rr.position, rr.end]:
					if absf((ponta as Vector2).dot(nn) - face) < 0.12 and not it._encontro_livre(f, rr.get_center() - nn * rr.get_center().dot(nn) + nn * face):
						encontros_ruins += 1
						if encontros_ruins <= 6:
							print("  encontro ruim: prédio %d (%.0fx%.0f, %s, escada %s) fachada %d parede %s vãos %s" % [i, e["sx"], e["sz"], e["uso"], it._escada, f, str(rr), str(it._vaos.get(f))])
		if it.extras < 1 or com_escada >= 8:
			continue
		com_escada += 1
		# monta de verdade e anda a partir de cada chegada da escada
		var c := Vector2(e["x"], e["z"])
		m.mundo.forcar(c)
		j.teleportar(Vector3(c.x + float(e["sx"]) * 0.5 + 6.0, m.mundo.altura(c.x, c.y) + 0.2, c.y), 0.0)
		m.interiores.abrir_agora(c)
		await q(10)
		var no: Node3D = m.interiores.abertos.get(i)
		if no == null:
			print("  (interior %d não abriu)" % i)
			continue
		var es: Dictionary = it._esc()
		var ret := Rect2(-it.hx + 0.3, -it.hz + 0.3, it.hx * 2.0 - 0.6, it.hz * 2.0 - 0.6)
		for k in range(1, it.extras + 1):
			var veio_a := (k - 1) % 2 == 0
			var faixa: Array = es["a"] if veio_a else es["b"]
			var w := (float(faixa[0]) + float(faixa[1])) * 0.5
			var d: float = float(es["d1"]) + 0.6 if veio_a else float(es["d0"]) - 0.6
			var p2: Vector2 = it._xz(d, w)
			var y: float = k * it.ALTURA_ANDAR
			var alc := _alcance(Vector3(p2.x, y, p2.y), ret, y, no)
			var salas := 0
			for cm in it.comodos:
				var cc: Vector2 = (cm[0] as Rect2).get_center()
				for v in alc:
					if Vector2(v.x * 0.5, v.y * 0.5).distance_to(cc) < 1.6:
						salas += 1
						break
			niveis += 1
			var bom: bool = alc.size() > 40 and salas >= 1
			if not bom:
				nivel_ruim += 1
				print("  prédio %d andar %d (chegou pelo lance %s): %d células, %d cômodos alcançados" % [i, k, "A" if veio_a else "B", alc.size(), salas])
		m.interiores.fechar(i)
		await q(3)
	print("prédios vistos: %d · com escada testados: %d (andares: %d) · móveis: %d" % [vistos, com_escada, niveis, moveis])
	ok(com_escada >= 4, "achou prédios com escada para testar")
	ok(nivel_ruim == 0, "de onde a escada chega dá para ir aos cômodos (%d andares presos)" % nivel_ruim)
	ok(cruzando == 0, "nenhum móvel cruza parede (%d)" % cruzando)
	ok(encontros_ruins == 0, "nenhuma divisória encosta em porta/janela da fachada (%d)" % encontros_ruins)
	# ---- locais especiais: topo de cada escada ----
	var L = load("res://mundo/locais.gd")
	var feitos := {}
	var ruins := []
	for li in L.LOCAIS.size():
		var tipo: String = L.LOCAIS[li][0]
		if feitos.has(tipo):
			continue
		feitos[tipo] = true
		var c := Vector2(L.LOCAIS[li][1], L.LOCAIS[li][2])
		m.mundo.forcar(c)
		var borda: Vector2 = L.local_para_mundo(li, Vector2(0, (L.TAMANHO[tipo] as Vector2).y * 0.5 + 3.0))
		j.teleportar(Vector3(borda.x, m.mundo.altura(borda.x, borda.y) + 0.2, borda.y), 0.0)
		m.locais.abrir_agora(c)
		await q(10)
		var no: Node3D = m.locais.abertos.get(li)
		var prep = load("res://mundo/local.gd").preparar(tipo, li, int(L.LOCAIS[li][3]), c)
		for es in prep.escadas:
			var ini: Vector2 = es[0]
			var dir: Vector2 = es[1]
			var topo := ini + dir * float(es[5])
			var y := float(es[3]) + float(es[4])
			var livre := false
			for extra in [0.7, 1.1]:                 # um passo depois do último degrau
				var pl: Vector2 = topo + dir * float(extra)
				if _de_pe(no.global_transform * Vector3(pl.x, y, pl.y)):
					livre = true
					break
			if not livre:
				ruins.append("%s: escada de %s subindo %s" % [tipo, str(ini), str(dir)])
		m.locais.fechar(li)
		await q(3)
	for x in ruins:
		print("  ESCADA SEM SAÍDA NO TOPO: ", x)
	ok(ruins.is_empty(), "topo de toda escada dos locais especiais tem chão livre (%d sem saída)" % ruins.size())
	print("falhas: ", falhas)
	quit()
