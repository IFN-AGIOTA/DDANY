extends SceneTree
# TESTE: PONTOS TURÍSTICOS DE NOVA YORK (1.21 · mundo/pontos_turisticos.gd, pontos_obras.gd, pontos_obras_fora.gd).
# Com o jogo:
#   · os 17 foram montados, com colisão, e cada um aparece no mapa
#   · nenhum prédio da cidade ficou no terreno de um ponto turístico; a tabela remapa_v8 converte os jogos salvos da
#     1.17..1.20 (prédio que saiu = o loot some; os outros ganham o número novo) e a ordem dos que ficaram não muda
#   · o aviso com o nome aparece ao chegar perto
#   · ANDANDO (sem pular): sobe as escadarias (Estátua da Liberdade, TKTS da Times Square, St. Patrick, as duas do
#     salão da Grand Central, a estação da montanha-russa de Coney Island), entra na Grand Central pela rua 42 até o
#     balcão de informações, entra no Yankee Stadium pelo portão e chega no campo, passa por baixo do arco da
#     Washington Square; e a mureta do Memorial 11/9 não deixa cair na piscina
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
	m.vagos.ativo = false
	var cid = m.cidade
	var pt = cid.pontos
	var PT = load("res://mundo/pontos_turisticos.gd")
	print("TESTE PONTOS TURÍSTICOS (1.21)")
	ok(pt != null and is_instance_valid(pt), "o nó dos pontos turísticos existe")
	ok(pt.construcoes.size() == PT.LISTA.size() and PT.LISTA.size() == 17, "construídos: %d de %d · %s" % [pt.construcoes.size(), PT.LISTA.size(), str(pt.construcoes.keys())])
	ok(pt.corpo.get_child_count() > 400, "colisão: %d formas" % pt.corpo.get_child_count())
	ok(PT.pontos_mapa().size() == 17, "no mapa: %d nomes" % PT.pontos_mapa().size())
	# ---- prédios fora dos terrenos ----
	var dentro := 0
	for info in cid.predio_info:
		var r := Rect2(float(info["x"]) - float(info["sx"]) * 0.5, float(info["z"]) - float(info["sz"]) * 0.5, float(info["sx"]), float(info["sz"]))
		if PT.em(r):
			dentro += 1
	ok(dentro == 0 and int(cid.removidos.get("ponto", 0)) > 50, "nenhum prédio no terreno de um ponto (%d); saíram %d" % [dentro, int(cid.removidos.get("ponto", 0))])
	# ---- jogos salvos da 1.17..1.20 (remapa_v8) ----
	var v8: PackedInt32Array = cid.remapa_v8
	var vivos := 0
	var ultimo := -1
	var ordem := true
	var um_saiu := -1
	var um_ficou := -1
	for i in v8.size():
		if v8[i] >= 0:
			vivos += 1
			ordem = ordem and v8[i] == ultimo + 1
			ultimo = v8[i]
			if um_ficou < 0 and i != v8[i]:
				um_ficou = i
		elif um_saiu < 0:
			um_saiu = i
	ok(vivos == cid.predio_info.size() and ordem and v8.size() - vivos > 50, "remapa_v8: %d prédios da 1.20 · %d ficaram (na mesma ordem: %s)" % [v8.size(), vivos, ordem])
	var Salv = load("res://menu/salvamento.gd")
	var tab: PackedInt32Array = Salv._remapa_de(m, 8)
	ok(tab == v8 and Salv._remapa_de(m, Salv.MAPA_PREDIOS).is_empty(), "save da 1.20 (mapa 8) converte com o remapa_v8; o da 1.21 (mapa %d) não converte" % Salv.MAPA_PREDIOS)
	ok(um_saiu >= 0 and Salv._remapear_id("p%d_2" % um_saiu, tab) == "" and Salv._remapear_id("p%d_2" % um_ficou, tab) == "p%d_2" % v8[um_ficou] and Salv._remapear_id("c55", tab) == "c55",
		"ids: o loot do prédio que saiu some (p%d), o do que ficou muda de número (p%d -> p%d), o de carro fica" % [um_saiu, um_ficou, v8[um_ficou] if um_ficou >= 0 else -1])
	# ---- o aviso ao chegar ----
	var i_emp := -1
	for i in PT.LISTA.size():
		if PT.LISTA[i][0] == "empire":
			i_emp = i
	var r_emp: Rect2 = PT.retangulo(i_emp)
	var p_emp := Vector2(r_emp.end.x + 10.0, r_emp.get_center().y)
	await _ir(Vector3(p_emp.x, m.mundo.altura(p_emp.x, p_emp.y), p_emp.y))
	await q(60)
	ok(pt._dentro == i_emp, "chegando no Empire State: o aviso é dele (%d)" % pt._dentro)
	# ---- escadarias ----
	var feitas := 0
	for e in pt.escadas:
		var ini: Vector2 = e[0]
		var dir: Vector2 = e[1]
		var y0: float = e[3]
		var dy: float = e[4]
		var comp: float = e[5]
		if dy < 2.0:
			continue
		var a := ini - dir * 2.0
		await _ir(Vector3(a.x, y0, a.y))
		var b := ini + dir * (comp + 0.6)
		var chegou := await _andar(Vector3(b.x, y0 + dy, b.y), 30.0)
		ok(chegou and j.global_position.y > y0 + dy - 0.4, "sobe a escada em %s (%.1f m): chegou %s, y %.2f" % [str(ini.snapped(Vector2.ONE)), dy, chegou, j.global_position.y])
		feitas += 1
	ok(feitas >= 5, "escadarias testadas: %d" % feitas)
	# ---- Grand Central: da rua 42 até o balcão ----
	await _ir(pt.pontos_altos["grand_central_rua"])
	var gc: Vector3 = pt.pontos_altos["grand_central"]
	ok(await _andar(gc, 30.0), "entra na Grand Central pela porta do meio até o balcão de informações (%s)" % str(j.global_position.snapped(Vector3.ONE * 0.1)))
	# ---- Yankee Stadium: portão, túnel e campo ----
	await _ir(pt.pontos_altos["yankee_portao"])
	var tun_ok := await _andar(pt.pontos_altos["yankee_tunel"], 40.0)
	var campo_ok := await _andar(pt.pontos_altos["yankee_campo"], 40.0)
	ok(tun_ok and campo_ok, "entra no Yankee Stadium pelo portão e chega no montinho (%s)" % str(j.global_position.snapped(Vector3.ONE * 0.1)))
	# ---- Washington Square: por baixo do arco ----
	await _ir(pt.pontos_altos["washington_rua"])
	ok(await _andar(pt.pontos_altos["washington_arco"], 25.0), "passa por baixo do arco da Washington Square")
	# ---- Memorial 11/9: a mureta segura ----
	var i_wtc := -1
	for i in PT.LISTA.size():
		if PT.LISTA[i][0] == "wtc":
			i_wtc = i
	var c_wtc := Vector3(float(PT.LISTA[i_wtc][1]), 0, float(PT.LISTA[i_wtc][2]))
	var piscina := c_wtc + Vector3(28.0, 0, -30.0)
	await _ir(Vector3(piscina.x, m.mundo.altura(piscina.x, piscina.z + 30.0), piscina.z + 30.0))
	await _andar(Vector3(piscina.x, 0.4, piscina.z), 8.0)
	ok(j.global_position.z > piscina.z + 23.0 and j.global_position.y > -0.5, "a mureta do Memorial segura (parou em z %.1f; a borda é %.1f)" % [j.global_position.z, piscina.z + 23.0])
	print("falhas: ", falhas)
	quit(1 if falhas > 0 else 0)
