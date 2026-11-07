extends SceneTree
# TESTE: IGREJA e PREFEITURA (1.06, mundo/local_igreja.gd). Com o jogo de verdade:
#   · os 5 locais novos estão na lista (1 prefeitura no centro, 4 igrejas) e montam com loot, infectados e escadas
#   · IGREJA: da rua, sobe ANDANDO a escadaria, entra, sobe a escada do coro, entra na torre e sobe a escada em
#     caracol até o campanário (sem pular); lá em cima o SINO: PEGAR = tocar, e o barulho chama um infectado longe
#   · PREFEITURA: da praça, sobe a escadaria, entra, sobe a escada do saguão até o 2º andar e a escada do terraço
#   · o save de antes (mapa dos prédios 4) é convertido (remapa_v4: os prédios dos terrenos novos saem)
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
	var quadros := 0                      # em quadros de física (tempo do jogo)
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

# anda por uma lista de pontos LOCAIS do local (y = altura do piso); devolve o índice onde parou (-1 = chegou)
func _caminho(no: Node3D, pts: Array, rotulo: String) -> int:
	for k in pts.size():
		var p: Vector3 = no.global_transform * (pts[k] as Vector3)
		if not await _andar(p, 14.0):
			var lp: Vector3 = no.global_transform.affine_inverse() * j.global_position
			print("    %s: parou indo ao ponto %d %s (está em %s)" % [rotulo, k, str(pts[k]), str(lp.snapped(Vector3.ONE * 0.1))])
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
	# ---- os locais novos ----
	var igrejas: Array = []
	var pref := -1
	for i in L.LOCAIS.size():
		if L.LOCAIS[i][0] == "igreja":
			igrejas.append(i)
		elif L.LOCAIS[i][0] == "prefeitura":
			pref = i
	var dc: float = Vector2(L.LOCAIS[pref][1], L.LOCAIS[pref][2]).distance_to(m.cidade.DOWNTOWN) if pref >= 0 else INF
	ok(igrejas.size() == 4 and pref >= 0 and dc < 400.0 and pref >= L.N_LOCAIS_105, "4 igrejas e a prefeitura (a %d m do centro), no fim da lista" % int(dc))
	for i in igrejas + [pref]:
		var e: Array = L.LOCAIS[i]
		var prep = LocalCls.preparar(String(e[0]), i, int(e[3]), Vector2(e[1], e[2]))
		ok(prep.cont.size() >= 12 and prep.infectados.size() >= 8 and prep.escadas.size() >= 4 and prep.col.size() > 100,
			"%s %d monta (%d caixas de loot, %d infectados, %d escadas, %d colisões)" % [e[0], i, prep.cont.size(), prep.infectados.size(), prep.escadas.size(), prep.col.size()])
	# ---- save antigo: os prédios dos terrenos novos saem ----
	var r4: PackedInt32Array = m.cidade.remapa_v4
	var sairam := 0
	for v in r4:
		if v < 0:
			sairam += 1
	ok(r4.size() == m.cidade.predio_info.size() + sairam and sairam > 0, "save de antes: %d prédios saíram para a igreja/prefeitura (remapa_v4 com %d)" % [sairam, r4.size()])
	# ---- IGREJA: da rua até o sino ----
	var ig: int = igrejas[0]
	var no: Node3D = await _abrir(ig, Vector3(0, 0, 31))
	ok(no != null, "a igreja abre perto")
	if no != null:
		var P := 2.4
		var yco := P + 6.0
		var ate_coro := [Vector3(0, 0, 29), Vector3(0, P, 20.5), Vector3(0, P, 13.0), Vector3(0, P, 7.0), Vector3(0, P, -10.5),
			Vector3(-10.0, P, -10.5), Vector3(-10.0, P, -3.0), Vector3(-10.0, yco, 9.4), Vector3(-5.0, yco, 9.4)]
		var parou := await _caminho(no, ate_coro, "igreja")
		var yl: float = (no.global_transform.affine_inverse() * j.global_position).y
		ok(parou < 0 and absf(yl - yco) < 0.4, "igreja: da rua sobe a escadaria, entra e sobe ao coro andando (altura %.1f, coro %.1f)" % [yl, yco])
		# a torre: porta do lado, patamar 0, lances em caracol
		var prep = LocalCls.preparar("igreja", ig, int(L.LOCAIS[ig][3]), Vector2(L.LOCAIS[ig][1], L.LOCAIS[ig][2]))
		var torre: Array = [Vector3(-2.6, yco, 9.4)]
		var y_fim := yco
		for es in prep.escadas:
			if float(es[3]) >= yco - 0.01 and absf(float(es[2]) - 1.15) < 0.01:
				var ini: Vector2 = es[0]
				var dir: Vector2 = es[1]
				var fim: Vector2 = ini + dir * (float(es[5]) + 0.575)
				torre.append(Vector3(ini.x, float(es[3]), ini.y) + Vector3(dir.x, 0, dir.y) * 0.2)
				torre.append(Vector3(fim.x, float(es[3]) + float(es[4]), fim.y))
				y_fim = float(es[3]) + float(es[4])
		var sino: Vector3 = prep.sinos[0]
		torre.append(Vector3(sino.x - 1.0, y_fim, sino.z))
		parou = await _caminho(no, torre, "torre")
		yl = (no.global_transform.affine_inverse() * j.global_position).y
		ok(parou < 0 and absf(yl - y_fim) < 0.4 and j.is_on_floor(), "igreja: sobe a torre andando até o campanário (%d lances, altura %.1f m)" % [(torre.size() - 2) / 2, yl])
		# o sino
		var SinoCls = load("res://mundo/sino.gd")
		var sn = SinoCls.perto(j.global_position)
		ok(sn != null and sn.acao(null) == "TOCAR\nSINO", "no campanário o botão PEGAR vira \"TOCAR SINO\"")
		# um infectado a ~90 m na rua, distraído: ouve o sino e vai ver
		m.vagos.max_ativos = 4
		var longe: Vector3 = no.global_transform * Vector3(4, 0, 95)
		var v = m.vagos._criar(Vector3(longe.x, m.mundo.altura(longe.x, longe.z), longe.z), Vector3.INF)
		await q(5)
		if v != null:
			v.vagar()
		var antes: int = m.vagos.barulhos_pedidos
		if sn != null:
			j._pegar_do_chao()
		await q(20)
		var V = load("res://inimigos/vago.gd")
		var foi: bool = v != null and is_instance_valid(v) and v.estado in [V.INVESTIGANDO, V.DESCONFIADO]
		ok(m.vagos.barulhos_pedidos > antes and foi, "tocar o sino faz barulho e um infectado a 90 m vem ver (estado %s)" % (str(v.estado) if v != null and is_instance_valid(v) else "?"))
		m.vagos.max_ativos = 0
		m.locais.fechar(ig)
		await q(5)
	# ---- PREFEITURA: da praça até o terraço ----
	var pn: Node3D = await _abrir(pref, Vector3(0, 0, 21.0))
	ok(pn != null, "a prefeitura abre perto")
	if pn != null:
		var P := 1.5
		var y2 := P + 5.0
		var yt := P + 10.0
		var pts := [Vector3(0, 0, 19.0), Vector3(0, P, 13.5), Vector3(0, P, 7.0), Vector3(0, P, 5.5), Vector3(10.0, P, 5.5),
			Vector3(10.0, y2, -5.2), Vector3(10.0, y2, -16.0), Vector3(14.0, y2, -16.0), Vector3(28.0, y2, -16.0), Vector3(28.0, y2, -9.0),
			Vector3(32.5, y2, -9.0), Vector3(32.5, yt, -18.9), Vector3(30.5, yt, -19.0), Vector3(28.5, yt, -18.8), Vector3(24.0, yt, -18.5)]
		var parou := await _caminho(pn, pts, "prefeitura")
		var yl: float = (pn.global_transform.affine_inverse() * j.global_position).y
		ok(parou < 0 and absf(yl - yt) < 0.4, "prefeitura: da praça sobe a escadaria, a escada do saguão e a do terraço andando (altura %.1f, terraço %.1f)" % [yl, yt])
		m.locais.fechar(pref)
	print("falhas: ", falhas)
	quit()
