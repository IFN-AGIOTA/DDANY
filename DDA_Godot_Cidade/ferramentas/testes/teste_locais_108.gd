extends SceneTree
# TESTE: GUARITAS, COMBOIOS DO EXÉRCITO e SOLDADOS INFECTADOS (1.08). Com o jogo de verdade:
#   · 8 GUARITAS no fim da lista dos locais, no meio de parques (terra, sem rua); cada uma monta com loot, infectados e
#     a escada; numa delas, do caminho até a CABINE da torre (9 m) pela escada em zigue-zague, andando, sem pular
#   · COMBOIOS: ~30 colunas nas avenidas, os veículos no FIM da lista de carros (os índices dos carros de antes não
#     mudam: o porta-malas salvo continua no lugar), com tanques; o porta-malas de um veículo do comboio é a CARGA
#     militar (tabela "comboio"); dá para subir no TANQUE pulando (caixotes, casco, cesto, torre)
#   · o HUMVEE funciona: entra, acelera e anda
#   · chegando perto de um comboio nascem SOLDADOS infectados (farda e capacete) em volta, mais fortes que os outros
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
func seg(t: float):
	var fim := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < fim:
		await physics_frame

var m
var j

func _andar(para: Vector3, tempo: float, pular := false) -> bool:
	var quadros := 0
	var b: Dictionary = m.controles._botao("PULAR")
	while quadros < int(tempo * 60.0):
		quadros += 1
		var d: Vector3 = para - j.global_position
		if Vector2(d.x, d.z).length() < 0.3:
			break
		j.cam_yaw = atan2(-d.x, -d.z)
		j.controles.mover = Vector2(0, 0.7 if pular else 1.0)
		if pular and not b.is_empty():
			b["toque"] = 99 if quadros % 30 < 3 else -1           # aperta PULAR de vez em quando
		await physics_frame
	j.controles.mover = Vector2.ZERO
	if not b.is_empty():
		b["toque"] = -1
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
	j.teleportar(Vector3(w.x, m.mundo.altura(w.x, w.z) + 0.3, w.z), 0.0)
	j.velocity = Vector3.ZERO
	await q(20)
	m.locais.abrir_agora(c)
	await q(20)
	return m.locais.abertos.get(i)

func _y_local(no: Node3D) -> float:
	return (no.global_transform.affine_inverse() * j.global_position).y

func _ir(p: Vector3) -> void:
	m.mundo.forcar(Vector2(p.x, p.z))
	j.teleportar(Vector3(p.x, m.mundo.altura(p.x, p.z) + 0.3, p.z), 0.0)
	j.velocity = Vector3.ZERO
	await q(30)

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
	var Comboios = load("res://mundo/comboios.gd")
	var Modelo = load("res://inimigos/modelo_infectado.gd")
	# ---------------- GUARITAS ----------------
	var guaritas: Array = []
	for i in L.LOCAIS.size():
		if L.LOCAIS[i][0] == "guarita":
			guaritas.append(i)
	ok(guaritas.size() == 8 and guaritas[0] >= L.N_LOCAIS_107, "8 guaritas, no fim da lista dos locais")
	var cid = m.cidade
	for i in guaritas:
		var e: Array = L.LOCAIS[i]
		var prep = LocalCls.preparar(String(e[0]), i, int(e[3]), Vector2(e[1], e[2]))
		ok(prep.cont.size() >= 3 and prep.infectados.size() >= 4 and prep.escadas.size() >= 3 and prep.col.size() > 20,
			"guarita %d monta (%d caixas de loot, %d infectados, %d escadas, %d colisões)" % [i, prep.cont.size(), prep.infectados.size(), prep.escadas.size(), prep.col.size()])
		var kc: int = int((e[2] + cid.WORLD.y) / cid.CELL) * cid.W + int((e[1] + cid.WORLD.x) / cid.CELL)
		ok(cid.park[kc] == 1 and cid.road[kc] == 0 and cid._em_terra(Vector2(e[1], e[2])), "guarita %d no meio de um parque (terra, sem rua)" % i)
	var gi: int = guaritas[0]
	var gn: Node3D = await _abrir(gi, Vector3(2.5, 0, 17.0))
	ok(gn != null, "a guarita abre perto")
	if gn != null:
		var gp := [Vector3(2.5, 0, 10.0), Vector3(-2.0, 0, 7.0), Vector3(-2.0, 0, -10.0), Vector3(-0.025, 0, -9.6),
			Vector3(-0.025, 3.0, -2.3), Vector3(1.125, 3.0, -2.3), Vector3(1.125, 6.0, -8.5), Vector3(-0.025, 6.0, -8.5),
			Vector3(-0.025, 9.0, -2.3), Vector3(1.3, 9.0, -2.3), Vector3(3.0, 9.0, -3.0), Vector3(4.0, 9.0, -4.0)]
		var parou := await _caminho(gn, gp, "guarita")
		var yl := _y_local(gn)
		ok(parou < 0 and absf(yl - 9.0) < 0.4, "guarita: do caminho sobe a escada (3 lances) e entra na CABINE da torre (altura %.1f)" % yl)
		m.locais.fechar(gi)
		await q(5)
	# ---------------- COMBOIOS ----------------
	var ab = cid.abandono
	var centros: Array = ab.centros_comboio
	ok(centros.size() >= 20, "comboios do Exército nas avenidas: %d" % centros.size())
	var prim := -1
	var ult_civil := -1
	var n_mil := 0
	var tanques: Array = []
	var humvees: Array = []
	for k in ab.carros.size():
		var nome: String = ab.carros[k][2]
		if Comboios.TAM.has(nome):
			n_mil += 1
			if prim < 0:
				prim = k
			if nome == "tanque":
				tanques.append(k)
		else:
			ult_civil = k
	ok(n_mil >= 100 and prim > ult_civil, "%d veículos do Exército, todos no fim da lista de carros (o 1º é o %d; o último carro comum, %d)" % [n_mil, prim, ult_civil])
	ok(tanques.size() >= 5, "tanques: %d" % tanques.size())
	# o porta-malas de um veículo do comboio é a carga militar
	var cv: Array = ab.carros[prim]
	await _ir(cv[0] + Basis(Vector3.UP, float(cv[1])) * Vector3(0, 0, 3.5))
	m.interiores._porta_malas(Vector2(j.global_position.x, j.global_position.z))
	var mala = m.interiores._malas.get(prim)
	ok(mala != null and mala.nome == Comboios.NOMES[cv[2]], "o porta-malas do %s é a carga dele (\"%s\")" % [cv[2], mala.nome if mala != null else "-"])
	# sobe no tanque pulando: caixotes (0,7 m) -> casco (1,5 m) -> cesto (2,1 m) -> torre (2,5 m)
	var tq: Array = ab.carros[tanques[0]]
	var bt := Basis(Vector3.UP, float(tq[1]))
	var p0: Vector3 = tq[0]
	await _ir(p0 + bt * Vector3(-6.2, 0, -0.9))
	var y_chao: float = j.global_position.y
	var degraus := [Vector3(-4.45, 0, -0.9), Vector3(-3.6, 0, -0.9), Vector3(-2.95, 0, -0.6), Vector3(-1.2, 0, 0.3)]
	for dg in degraus:
		await _andar(p0 + bt * dg, 3.0, true)
		await seg(0.4)
	await seg(1.2)                                       # o último pulo termina
	var subiu: float = j.global_position.y - ab.Y
	ok(subiu > 2.3 and j.is_on_floor(), "sobe no TANQUE pulando (caixotes, casco, cesto, torre): em pé a %.1f m do asfalto" % subiu)
	# ---------------- HUMVEE QUE FUNCIONA ----------------
	var vm = m.veiculos
	var mil := ""
	var n_func_mil := 0
	for vid in vm._ids:
		var c: Array = ab.carros[vm._ids[vid]]
		if c[2] in ["humvee", "caminhao_exercito"]:
			n_func_mil += 1
			if c[2] == "humvee" and mil == "":
				mil = vid
	ok(n_func_mil >= 5 and mil != "", "humvees e caminhões do Exército que funcionam: %d" % n_func_mil)
	if mil != "":
		var car: Array = ab.carros[vm._ids[mil]]
		await _ir(car[0] + Basis(Vector3.UP, float(car[1])) * Vector3(0, 0, 2.8))
		ok(vm.perto == mil, "perto do humvee: botão ENTRAR (%s)" % vm.perto)
		j._pegar_do_chao()
		await q(10)
		var veic = vm.nos.get(mil)
		if veic != null:
			veic.combustivel = 20.0
			veic.ligar_motor()
			var p1: Vector3 = veic.global_position
			m.controles.mover = Vector2(0, 1)
			var vmax := 0.0
			var fim := Time.get_ticks_msec() + 4000
			while Time.get_ticks_msec() < fim:
				await physics_frame
				vmax = maxf(vmax, veic.velocidade_kmh())
			m.controles.mover = Vector2.ZERO
			ok(veic.tipo == "humvee" and veic.global_position.distance_to(p1) > 8.0 and vmax > 15.0, "o HUMVEE anda (%.1f m em 4 s, até %.0f km/h)" % [veic.global_position.distance_to(p1), vmax])
			vm.sair()
			await q(10)
		else:
			ok(false, "entrou no humvee")
	# ---------------- SOLDADOS ----------------
	m.vagos.max_ativos = 60
	var cc: Array = centros[centros.size() / 2]
	var centro: Vector3 = cc[0]
	await _ir(centro + (cc[1] as Vector3) * (float(cc[3]) + 45.0) + (cc[2] as Vector3) * float(cc[4]))
	var soldados := 0
	var outros_vida := -1.0
	var vida_sold := -1.0
	for t in 12:
		await seg(0.5)
		soldados = 0
		for v in m.vagos.vivos:
			if is_instance_valid(v) and v.soldado() and Vector2(v.global_position.x - centro.x, v.global_position.z - centro.z).length() < float(cc[3]) + 15.0:
				soldados += 1
				vida_sold = v.vida
		if soldados >= 2:
			break
	ok(soldados >= 2, "perto de um comboio nascem SOLDADOS infectados em volta: %d" % soldados)
	var vg = load("res://inimigos/vago.gd")
	var Regras = load("res://inimigos/regras_infectados.gd")
	outros_vida = vg.VIDA * Regras.mult_vida()
	ok(vida_sold > outros_vida * 1.2, "o soldado aguenta mais (vida %.0f, os outros %.0f)" % [vida_sold, outros_vida])
	var semente: int = Modelo.semente_soldado()
	ok(Modelo.eh_soldado(semente) and float(semente) == float(int(float(semente))) and semente < 16777216, "a semente de soldado cabe exata no pacote de rede (float)")
	print("falhas: ", falhas)
	quit()
