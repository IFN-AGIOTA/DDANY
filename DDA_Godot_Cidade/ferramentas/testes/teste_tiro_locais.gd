extends SceneTree
# TESTE DO TIRO DE LONGE NOS LOCAIS ESPECIAIS (0.74): de 400 m, um tiro na direção de um posto/hospital/supermercado/
# armazém fechado para na casca dele (mundo/colisao_mundo.gd raio); aberto, a casca não conta (tem colisão de verdade).
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)
func _initialize():
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func _r():
	for i in 20:
		await process_frame
	var m = current_scene
	m._jogar()
	for i in 30:
		await process_frame
	var L = load("res://mundo/locais.gd")
	var mw = m.mundo
	var acertos := 0
	for i in L.LOCAIS.size():
		var e: Array = L.LOCAIS[i]
		var vols: Array = L.casca(e[0])
		var c3: Vector3 = vols[0][0]
		var c: Vector2 = L.local_para_mundo(i, Vector2(c3.x, c3.z))
		var alvo := Vector3(c.x, m.cidade.Y_CALCADA + 2.0, c.y)
		var o := alvo + Vector3(400.0, 0.0, 0.0)
		var r: Dictionary = mw.raio(o, (alvo - o).normalized(), 450.0)
		var no_local: bool = r["hit"] and L.retangulo(i, 3.0).has_point(Vector2(r["pos"].x, r["pos"].z))
		if no_local:
			acertos += 1
		elif not r["hit"] or r["dist"] > 395.0:
			print("  tiro passou pelo local %d (%s): %s" % [i, e[0], str(r)])
	print("tiros que pararam no local (ou num prédio antes dele): ", acertos, " de ", L.LOCAIS.size())
	# o 1º local: sem nada na frente, de 30 m
	var e0: Array = L.LOCAIS[0]
	var v0: Vector3 = L.casca(e0[0])[0][0]
	var c0: Vector2 = L.local_para_mundo(0, Vector2(v0.x, v0.z))
	var a0 := Vector3(c0.x, m.cidade.Y_CALCADA + 2.0, c0.y)
	var r0: Dictionary = mw.raio(a0 + Vector3(0, 0, 60.0), Vector3(0, 0, -1), 80.0)
	ok(r0["hit"] and r0["dist"] < 60.0, "tiro de fora para na casca do local 0 (%.1f m)" % float(r0["dist"]))
	mw.locais_abertos[0] = true
	var r1: Dictionary = mw.raio(a0 + Vector3(0, 0, 60.0), Vector3(0, 0, -1), 80.0)
	ok(not (r1["hit"] and r1.get("predio", false) and r1["dist"] < float(r0["dist"]) + 0.01 and L.retangulo(0, 1.0).has_point(Vector2(r1["pos"].x, r1["pos"].z))) or r1["dist"] > float(r0["dist"]) + 0.01, "local aberto: a casca não conta")
	mw.locais_abertos.erase(0)
	print("falhas: ", falhas)
	quit()
