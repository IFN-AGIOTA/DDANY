extends SceneTree
# TESTE: ESCADAS DE INCÊNDIO (1.04, mundo/escadas_incendio.gd). Com o jogo de verdade:
#   · quase todo prédio tem 2 escadas (só fica com menos quem tem os lados colados em outros prédios)
#   · SOBE ANDANDO (sem pular) da calçada até o TELHADO e anda em cima dele, e DESCE de volta, em prédios de cada tipo:
#     baixo aberto (telhado com mureta: ela abre onde a escada chega), alto aberto ("casca") e fechado (caixa);
#     um deles de PERNA QUEBRADA
#   · o telhado do corpo das torres escalonadas tem chão (antes a caixa ia até o alto do topo estreito)
#   · o desenho aparece perto da câmera (pedaços montados aos poucos)
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
var E

func _andar(para: Vector3, tempo: float, forca := 1.0) -> bool:
	var quadros := 0                      # 1.04: em quadros de física (tempo do jogo), não de relógio: não falha com a CPU ocupada
	while quadros < int(tempo * 60.0):
		quadros += 1
		var d: Vector3 = para - j.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			break
		j.cam_yaw = atan2(-d.x, -d.z)
		j.controles.mover = Vector2(0, forca)
		await physics_frame
	j.controles.mover = Vector2.ZERO
	var d2: Vector3 = para - j.global_position
	return Vector2(d2.x, d2.z).length() < 0.6

# o caminho de uma escada (na fachada: x ao longo, z para fora): do chão ao telhado, lance por lance
func _caminho(pl: Dictionary) -> Array:
	var nv: PackedFloat32Array = pl["niveis"]
	var pts: Array = []
	var fim: float = E.A + 0.55
	pts.append(E._mundo(pl, -fim, nv[0], E._faixa(0)))
	for k in nv.size() - 1:
		var s := 1.0 if k % 2 == 0 else -1.0
		pts.append(E._mundo(pl, s * fim, nv[k + 1], E._faixa(k)))
		if k + 1 < nv.size() - 1:
			pts.append(E._mundo(pl, s * fim, nv[k + 1], E._faixa(k + 1)))
	var s_ult := 1.0 if (nv.size() - 2) % 2 == 0 else -1.0
	pts.append(E._mundo(pl, s_ult * fim, nv[nv.size() - 1], 0.2))
	pts.append(E._mundo(pl, s_ult * fim, nv[nv.size() - 1], -2.0))         # 2 m para dentro do telhado
	return pts

func _subir_e_descer(i: int, rotulo: String) -> void:
	var inf: Dictionary = m.cidade.predio_info[i]
	var pl: Dictionary = E.planos(i)[0]
	var pts := _caminho(pl)
	var c := Vector2(float(inf["x"]), float(inf["z"]))
	m.mundo.forcar(c)
	var p0: Vector3 = pts[0]
	var antes: Vector3 = p0 + (pl["e"] as Vector3) * -2.0
	j.teleportar(Vector3(antes.x, m.mundo.altura(antes.x, antes.z) + 0.3, antes.z), 0.0)
	j.velocity = Vector3.ZERO
	await q(30)
	m.cidade.escadas_incendio.montar_fisica_agora()
	await q(10)
	var nv: PackedFloat32Array = pl["niveis"]
	var subiu := true
	for k in pts.size():
		if not await _andar(pts[k], 12.0):
			subiu = false
			print("    %s: parou indo ao ponto %d de %d (altura %.1f, queria %.1f)" % [rotulo, k, pts.size() - 1, j.global_position.y, (pts[k] as Vector3).y])
			break
	var R: float = nv[nv.size() - 1]
	var no_teto: bool = subiu and absf(j.global_position.y - R) < 0.4 and j.is_on_floor()
	ok(no_teto, "%s (%d andares de escada): sobe andando da calçada até o telhado e fica em pé nele (y %.1f, telhado %.1f)" % [rotulo, nv.size() - 1, j.global_position.y, R])
	if not no_teto:
		return
	# anda em cima do telhado e volta
	var meio := Vector3(c.x, R, c.y)
	await _andar(meio.lerp(j.global_position, 0.5), 6.0)
	ok(absf(j.global_position.y - R) < 0.4, "%s: anda em cima do telhado" % rotulo)
	var desceu := true
	for k in range(pts.size() - 1, -1, -1):
		if not await _andar(pts[k], 12.0):
			desceu = false
			print("    %s: parou descendo no ponto %d (altura %.1f)" % [rotulo, k, j.global_position.y])
			break
	ok(desceu and absf(j.global_position.y - nv[0]) < 0.6, "%s: desce de volta até a calçada" % rotulo)

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
	E = load("res://mundo/escadas_incendio.gd")
	var cid = m.cidade
	# ---- quantas por prédio ----
	var n2 := 0
	var n1 := 0
	var n0 := 0
	var total := 0
	for i in cid.predio_info.size():
		var inf: Dictionary = cid.predio_info[i]
		if bool(inf["ruina"]) or not inf.has("t"):
			continue
		total += 1
		var n: int = E.planos(i).size()
		if n >= 2: n2 += 1
		elif n == 1: n1 += 1
		else: n0 += 1
	print("  prédios: %d · com 2 escadas: %d (%.1f%%) · com 1: %d · sem: %d" % [total, n2, 100.0 * n2 / total, n1, n0])
	ok(float(n2) / total > 0.9 and float(n0) / total < 0.03, "quase todo prédio tem 2 escadas de incêndio")
	# ---- escolhe prédios de cada tipo perto do centro ----
	var achar := func(cond: Callable) -> int:
		var melhor := -1
		var md := INF
		for i in cid.predio_info.size():
			var inf: Dictionary = cid.predio_info[i]
			if bool(inf["ruina"]) or not inf.has("t") or E.planos(i).is_empty() or not cond.call(inf, i):
				continue
			var d := Vector2(float(inf["x"]), float(inf["z"])).distance_to(Vector2(436, 1500))
			if d < md:
				md = d
				melhor = i
		return melhor
	var I = load("res://mundo/interior.gd")
	var baixo: int = achar.call(func(inf, i): return bool(inf["entra"]) and I.altura_telhado(inf) > 0.0)
	var alto_aberto: int = achar.call(func(inf, i): return bool(inf["entra"]) and I.altura_telhado(inf) < 0.0 and float(inf["h"]) > 20.0 and float(inf["h"]) < 40.0)
	var fechado: int = achar.call(func(inf, i): return not bool(inf["entra"]) and float(inf["h"]) > 15.0 and float(inf["h"]) < 30.0)
	ok(baixo >= 0 and alto_aberto >= 0 and fechado >= 0, "achou prédios de cada tipo (baixo aberto %d, alto aberto %d, fechado %d)" % [baixo, alto_aberto, fechado])
	if baixo >= 0:
		await _subir_e_descer(baixo, "prédio baixo aberto (telhado com mureta)")
	if alto_aberto >= 0:
		await _subir_e_descer(alto_aberto, "prédio alto aberto (casca)")
	if fechado >= 0:
		j.sobrevivencia.perna_quebrada = true
		await _subir_e_descer(fechado, "prédio fechado, DE PERNA QUEBRADA")
		j.sobrevivencia.perna_quebrada = false
	# ---- torre escalonada: o telhado do corpo tem chão ----
	if not cid.predio_topos.is_empty():
		var ti: int = cid.predio_topos.keys()[0]
		var inf: Dictionary = cid.predio_info[ti]
		var tp: Array = cid.predio_topos[ti]
		var y_corpo: float = 0.6 + float(tp[2])
		var canto := Vector3(float(inf["x"]) + float(inf["sx"]) * 0.45, y_corpo + 1.0, float(inf["z"]) + float(inf["sz"]) * 0.45)
		m.mundo.forcar(Vector2(canto.x, canto.z))
		j.teleportar(canto, 0.0)
		await q(60)
		ok(absf(j.global_position.y - y_corpo) < 0.5 and j.is_on_floor(), "torre escalonada: dá para ficar no telhado do corpo, ao lado do topo (y %.1f, corpo %.1f)" % [j.global_position.y, y_corpo])
	# ---- desenho ----
	var esc = m.cidade.escadas_incendio
	await q(120)
	ok(esc != null and esc.instancias > 0 and esc._cels.size() > 0, "o desenho aparece perto da câmera (%d pedaços, %d peças)" % [esc._cels.size(), esc.instancias])
	print("falhas: ", falhas)
	quit()
