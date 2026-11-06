extends SceneTree
# TESTE: PONTES DE NOVA YORK (1.15, mundo/pontes.gd). Com o jogo de verdade:
#   · as 6 pontes montam (desenho, colisão e luzes); as 3 ruas novas estão no fim da lista; saíram 15 prédios (os das
#     ruas novas) e a tabela dos jogos salvos (remapa_v6) leva os números da 1.14 para os de agora
#   · o asfalto rente ao mar sumiu (o chão de física embaixo da ponte é o mar) e o tabuleiro sobe em rampa (até 7,5%)
#   · GPS: de Manhattan até o Brooklyn, a ilha do norte e Nova Jersey (antes não achava caminho para o leste)
#   · a pé: sobe a rampa da Ponte do Brooklyn, passa entre as ancoragens e pelo ARCO da torre; sobe a rampa do PASSEIO
#     elevado e passa pela passagem do pilar do meio
#   · parado no meio do vão fica em cima do tabuleiro; caindo na água embaixo, NADA (a ponte não empurra para cima)
#   · os carros largados em cima ficam NO tabuleiro (fora do canteiro do meio no Brooklyn); infectado nasce em cima
#   · DIRIGINDO: atravessa a Ponte de Manhattan inteira, de Manhattan ao Brooklyn
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
func seg(s: float):
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame

var m
var j
var P

func _andar(para: Vector3, tempo: float) -> bool:
	var quadros := 0
	while quadros < int(tempo * 60.0):
		quadros += 1
		var d: Vector3 = para - j.global_position
		if Vector2(d.x, d.z).length() < 0.5:
			break
		j.cam_yaw = atan2(-d.x, -d.z)
		j.controles.mover = Vector2(0, 1.0)
		await physics_frame
	j.controles.mover = Vector2.ZERO
	var d2: Vector3 = para - j.global_position
	return Vector2(d2.x, d2.z).length() < 1.0

# anda pelo eixo da ponte de s0 a s1 no deslocamento lat; devolve o s onde parou (ou s1) e a menor folga até o tabuleiro
func _percorrer(pt, s0: float, s1: float, lat: float, rotulo: String, y_ref: Callable) -> float:
	var s := s0
	var menor := INF
	while s < s1:
		s = minf(s + 25.0, s1)
		var alvo: Vector3 = pt.p3(s, lat, 0.0)
		if not await _andar(alvo, 14.0):
			var pr: Vector2 = pt.projetar(Vector2(j.global_position.x, j.global_position.z))
			print("    %s: parou em s=%.0f lat=%.1f y=%.1f (alvo s=%.0f)" % [rotulo, pr.x, pr.y, j.global_position.y, s])
			for cc in j.get_slide_collision_count():
				var o = j.get_slide_collision(cc).get_collider()
				print("      bate em %s" % (str(o.name) if o != null else "?"))
			return pr.x
		var pr2: Vector2 = pt.projetar(Vector2(j.global_position.x, j.global_position.z))
		menor = minf(menor, j.global_position.y - float(y_ref.call(pr2.x)))
	print("    %s: chegou em s=%.0f (menor altura sobre o piso %.2f m)" % [rotulo, s1, menor])
	return s1

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
	P = load("res://mundo/pontes.gd")
	var C = m.cidade
	print("== montagem")
	ok(P.lista.size() == 6, "6 pontes (%d)" % P.lista.size())
	var corpos := 0
	var luzes := 0
	for n in C.nos_pontes:
		if n is StaticBody3D and n.has_meta("ponte"):
			corpos += 1
		if n is MultiMeshInstance3D:
			luzes += (n as MultiMeshInstance3D).multimesh.instance_count
	ok(corpos == 6, "colisão das 6 pontes (%d)" % corpos)
	ok(luzes == 0, "pontes apagadas (a cidade está sem energia): %d luzes" % luzes)
	var ruas: Array = C.dados_cidade["roads"]
	ok(ruas.size() == C.n_ruas_antigas + P.RUAS_NOVAS.size(), "ruas novas no fim da lista (%d + %d)" % [C.n_ruas_antigas, ruas.size() - C.n_ruas_antigas])
	ok(int(C.removidos.get("ponte", -1)) == 15, "prédios que saíram para as ruas novas: %d (15)" % int(C.removidos.get("ponte", -1)))
	var menos := 0
	var cresce := true
	var ult := -1
	for v in C.remapa_v6:
		if v < 0:
			menos += 1
		else:
			cresce = cresce and v > ult
			ult = v
	ok(C.remapa_v6.size() == C.predios.size() / 5 + 15 and menos == 15 and cresce, "remapa_v6: %d prédios da 1.14 -> %d agora (%d saíram), em ordem" % [C.remapa_v6.size(), C.predios.size() / 5, menos])
	print("== altura e chão")
	var pb = P.ponte(0)
	var hm: float = pb.h(700.0)
	ok(hm > 19.0, "Ponte do Brooklyn no meio do vão a %.1f m" % hm)
	var meio: Vector3 = pb.p3(700.0, -10.0, 0.0)
	ok(absf(m.mundo.altura(meio.x, meio.z) - hm) < 0.05, "altura() em cima da ponte = tabuleiro")
	ok(m.mundo.altura_chao(meio.x, meio.z) < 0.0 and m.mundo.nivel_agua(meio.x, meio.z) > -1.0, "embaixo da ponte é o mar (sem o asfalto rente à água)")
	var rampa := 0.0
	for pt in P.lista:
		var s: float = pt.ini
		while s < pt.fim:
			rampa = maxf(rampa, absf(pt.h(s + 2.0) - pt.h(s)) / 2.0)
			s += 2.0
	ok(rampa <= 0.0751, "rampa mais íngreme: %.1f%%" % (rampa * 100.0))
	print("== GPS entre as ilhas")
	var G = load("res://hud/rota_gps.gd")
	G.montar(C.dados_cidade)
	for alvo in [[Vector2(3000, 1500), "Brooklyn"], [Vector2(1000, -4300), "ilha do norte"], [Vector2(-6500, 0), "Nova Jersey"], [Vector2(5000, 500), "Queens"]]:
		var rt: PackedVector2Array = G.rota(C.DOWNTOWN, alvo[0])
		var por_ponte := ""
		for k in rt.size() - 1:
			var L: float = rt[k].distance_to(rt[k + 1])
			for u in range(0, int(L / 10.0) + 1):
				var p: Vector2 = rt[k].lerp(rt[k + 1], u * 10.0 / maxf(L, 0.01))
				var c: Vector3 = P.consultar(p.x, p.y)
				if c.x >= 0.0 and not (P.ponte(int(c.x)).nome in por_ponte):
					por_ponte += (", " if por_ponte != "" else "") + P.ponte(int(c.x)).nome
		ok(rt.size() > 2 and rt[rt.size() - 1].distance_to(alvo[0]) < 400.0, "GPS do centro até %s: %.1f km%s" % [alvo[1], G.comprimento(rt) / 1000.0, (" por: " + por_ponte) if por_ponte != "" else ""])
		if alvo[1] == "Brooklyn":
			ok(por_ponte != "", "a rota até o Brooklyn passa por uma ponte")
	print("== carros largados e infectado")
	var em_cima := 0
	var no_canteiro := 0
	var embaixo := 0
	for c in m.cidade.abandono.carros:
		var p: Vector3 = c[0]
		var q3: Vector3 = P.consultar(p.x, p.z)
		if q3.x < 0.0:
			continue
		if absf(p.y - q3.y) < 0.2:
			em_cima += 1
		else:
			embaixo += 1
		if int(q3.x) == 0 and absf(q3.z) < P.CANTEIRO_BROOKLYN - 0.1:
			no_canteiro += 1
	ok(em_cima > 150 and embaixo == 0, "carros largados nas pontes: %d no tabuleiro, %d fora dele" % [em_cima, embaixo])
	ok(no_canteiro == 0, "nenhum no canteiro do meio do Brooklyn (%d)" % no_canteiro)
	print("== parado no vão e caindo na água")
	m.mundo.forcar(Vector2(meio.x, meio.z))
	j.teleportar(Vector3(meio.x, hm + 0.3, meio.z), 0.0)
	await seg(2.0)
	ok(absf(j.global_position.y - hm) < 0.3 and j.is_on_floor(), "fica em pé no tabuleiro (y %.2f, tabuleiro %.2f)" % [j.global_position.y, hm])
	m.vagos.max_ativos = 5
	var vg = m.vagos._criar(Vector3(meio.x + 6.0, m.mundo.altura(meio.x + 6.0, meio.z) + 0.05, meio.z), Vector3.INF, true)
	await q(5)
	ok(vg != null and is_instance_valid(vg) and absf(vg.global_position.y - hm) < 1.5, "infectado nasce em cima da ponte (y %.1f)" % (vg.global_position.y if vg != null else -99.0))
	if vg != null and is_instance_valid(vg):
		vg.queue_free()
	m.vagos.max_ativos = 0
	var agua: Vector3 = pb.p3(700.0, 0.0, 0.0)
	j.teleportar(Vector3(agua.x, -0.6, agua.z), 0.0)
	await seg(3.0)
	ok(j.nadando and j.global_position.y < 1.0, "embaixo da ponte nada (nadando %s, y %.2f)" % [str(j.nadando), j.global_position.y])
	print("== a pé pela Ponte do Brooklyn")
	# passa pela brecha do bloqueio do Exército (a 4 m do meio) e depois segue pela pista a 10 m do meio
	var ini: Vector3 = pb.p3(5.0, -4.0, 0.0)
	m.mundo.forcar(Vector2(ini.x, ini.z))
	j.teleportar(Vector3(ini.x, m.mundo.altura(ini.x, ini.z) + 0.1, ini.z), 0.0)
	await q(20)
	var chegou: float = await _percorrer(pb, 5.0, 80.0, -4.0, "brecha do bloqueio do Exército", func(s): return pb.h(s))
	ok(chegou >= 79.0, "passou pela brecha do bloqueio (%.0f m)" % chegou)
	chegou = await _percorrer(pb, 80.0, 500.0, -10.0, "pista (rampa, ancoragens e o arco da torre)", func(s): return pb.h(s))
	ok(chegou >= 499.0, "andou da rua até depois da torre (%.0f m)" % chegou)
	ok(j.global_position.y > pb.h(500.0) - 0.3, "em cima do tabuleiro depois da torre (y %.1f)" % j.global_position.y)
	var sp0: float = pb.dados["passeio"][0]
	var sp1: float = pb.dados["passeio"][1]
	var pi0: Vector3 = pb.p3(sp0 - 60.0, 0.0, 0.0)
	j.teleportar(Vector3(pi0.x, pb.h(sp0 - 60.0) + 0.3, pi0.z), 0.0)
	await q(20)
	var yp := func(s): return P._y_passeio(pb, s, sp0, sp1)
	chegou = await _percorrer(pb, sp0 - 60.0, 490.0, 0.0, "passeio elevado (rampa e a passagem da torre)", yp)
	ok(chegou >= 489.0, "andou pelo passeio até depois da torre (%.0f m)" % chegou)
	ok(absf(j.global_position.y - float(yp.call(490.0))) < 0.5, "em cima do passeio (y %.1f, passeio %.1f)" % [j.global_position.y, yp.call(490.0)])
	print("== dirigindo pela Ponte de Manhattan")
	var pm = P.ponte(1)
	var vm = m.veiculos
	# a metade direita sem os carros do engarrafamento (um ônibus atravessado fecha várias faixas; aqui só interessa
	# o tabuleiro aguentar o carro)
	var ob: PackedFloat32Array = m.cidade.abandono.obstaculos
	var tirados := 0
	for k in range(0, ob.size(), 7):
		var pr0: Vector2 = pm.projetar(Vector2(ob[k], ob[k + 1]))
		if pr0.x > -5.0 and pr0.x < pm.comp + 5.0 and pr0.y < 1.0 and pm.ponto(pr0.x).distance_to(Vector2(ob[k], ob[k + 1])) < 26.0:
			m.mundo.desligar_obstaculo(k / 7)
			tirados += 1
	print("    obstáculos tirados da pista: ", tirados)
	var vid: String = vm._ids.keys()[0]
	var p0: Vector3 = pm.p3(2.0, -8.0, 0.6)
	var d0: Vector2 = pm.direcao(2.0)
	m.loot_mundo.veiculos[vid] = {"t": "sedan", "cor": "aa2222", "p": [p0.x, p0.y + 0.4, p0.z], "g": atan2(d0.x, d0.y), "c": 30.0, "m": 1.0}
	var lado: Vector3 = p0 + Vector3(-d0.y, 0, d0.x) * 3.0
	m.mundo.forcar(Vector2(lado.x, lado.z))
	j.teleportar(Vector3(lado.x, m.mundo.altura(lado.x, lado.z) + 0.1, lado.z), 0.0)
	await q(30)
	print("    ", vm.entrar(vid))
	var veic = vm.dirigindo
	ok(veic != null, "entrou no carro na cabeceira da Ponte de Manhattan")
	if veic != null:
		var t := 0
		var s_ant := 0.0
		var abaixo := 0
		var vira := 1.0
		var testou := false
		var maior_s := 0.0
		while t < 60 * 120:
			t += 1
			var pv: Vector2 = Vector2(veic.global_position.x, veic.global_position.z)
			var pr: Vector2 = pm.projetar(pv)
			maior_s = maxf(maior_s, pr.x)
			if pr.x > pm.comp - 3.0:
				break
			# volante: mira um ponto 25 m à frente, na pista da direita (lat -8)
			var alvo: Vector3 = pm.p3(minf(pr.x + 25.0, pm.comp), -8.0, 0.0)
			var quer: Vector2 = (Vector2(alvo.x, alvo.z) - pv).normalized()
			var fr: Vector3 = veic.global_basis.z
			var tem: Vector2 = Vector2(fr.x, fr.z).normalized()
			var erro: float = tem.angle_to(quer)
			var kmh: float = veic.velocidade_kmh()
			m.controles.mover = Vector2(clampf(erro * 2.5, -1.0, 1.0) * vira, 1.0 if kmh < 60.0 else 0.0)
			if not testou and t == 90:
				# descobre para que lado o volante vira (teste rápido no começo)
				testou = true
			if pr.x > pm.ini + 30.0 and pr.x < pm.fim - 30.0 and absf(pr.y) < 20.0 and veic.global_position.y < pm.h(pr.x) - 2.0:
				abaixo += 1
			await physics_frame
			if t % 600 == 0:
				print("    %.0f s: s=%.0f lat=%.1f y=%.1f (tabuleiro %.1f) %.0f km/h" % [t / 60.0, pr.x, pr.y, veic.global_position.y, pm.h(pr.x), kmh])
				if absf(pr.x - s_ant) < 3.0:
					vira = -vira               # parado ou rodando: o volante deve estar ao contrário
				s_ant = pr.x
		m.controles.mover = Vector2.ZERO
		ok(maior_s > pm.comp - 5.0, "atravessou a Ponte de Manhattan dirigindo (%.0f de %.0f m)" % [maior_s, pm.comp])
		ok(abaixo == 0, "o carro não caiu do tabuleiro (%d quadros abaixo)" % abaixo)
	print("falhas: ", falhas)
	quit()
