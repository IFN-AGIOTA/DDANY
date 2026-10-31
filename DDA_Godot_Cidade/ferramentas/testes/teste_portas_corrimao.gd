extends SceneTree
# TESTE: PORTAS QUE NÃO PRENDEM E CORRIMÃOS QUE SEGURAM (1.02)
#   PORTAS (mundo/porta.gd), na porta da rua onde o jogador travou (5472, 387), COM A PERNA QUEBRADA (sem pular):
#     · parado no vão, a porta abre: a folha passa por ele sem prender, e dá para sair andando dos dois lados;
#     · porta aberta só um pouco (25%): andar contra ela termina de abrir, e passa;
#     · as portas que nascem abertas (rua e de dentro) abrem pelo menos 85% (o vão nunca fica mais estreito que o corpo).
#   CORRIMÃOS: andando de lado contra o corrimão no meio da escada, não cai:
#     · escada de dentro dos prédios (mundo/interior.gd), lance A e lance B (o lado do vão entre os lances);
#     · escadas dos locais especiais com corrimão (mundo/local.gd).
#   1.03: e o corrimão não TRANCA ninguém: sobe do térreo ao 2º andar pela escada de dentro passando pelo patamar.
#   1.04: sobe e desce ANDANDO (sem pular) todas as escadas dos locais especiais (o topo trancava em 6 delas).
#   1.07: escadas iguais (mesma direção, largura, subida, comprimento e corrimão) no mesmo local só são andadas 2 vezes
#   (os 3 guindastes do porto têm 8 lances iguais cada: o teste passava dos 25 min); as rotas inteiras dos locais
#   novos são andadas nos testes deles (teste_locais_106/107/108).
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

# anda na direção de "para" por até "tempo" s; devolve quanto andou
func _andar(para: Vector3, tempo: float) -> float:
	var de: Vector3 = j.global_position
	var quadros := 0                      # 1.04: em quadros de física (tempo do jogo), não de relógio: não falha com a CPU ocupada
	while quadros < int(tempo * 60.0):
		quadros += 1
		j.cam_yaw = atan2(-(para - j.global_position).x, -(para - j.global_position).z)
		j.controles.mover = Vector2(0, 0.6)
		await physics_frame
		if Vector2(j.global_position.x - para.x, j.global_position.z - para.z).length() < 0.5:
			break
	j.controles.mover = Vector2.ZERO
	return Vector2(j.global_position.x - de.x, j.global_position.z - de.z).length()

# empurra de lado (contra o corrimão) por "tempo" s; devolve [quanto desceu, quanto saiu para o lado]
func _de_lado(em: Vector3, lado: Vector3, tempo: float) -> Array:
	j.teleportar(em + Vector3(0, 0.3, 0), 0.0)
	j.velocity = Vector3.ZERO
	await q(20)
	var y0: float = j.global_position.y
	var p0: Vector3 = j.global_position
	var quadros := 0
	var y_min := y0
	while quadros < int(tempo * 60.0):
		quadros += 1
		var alvo: Vector3 = j.global_position + lado * 5.0
		j.cam_yaw = atan2(-(alvo - j.global_position).x, -(alvo - j.global_position).z)
		j.controles.mover = Vector2(0, 0.6)
		await physics_frame
		y_min = minf(y_min, j.global_position.y)
	j.controles.mover = Vector2.ZERO
	var d: Vector3 = j.global_position - p0
	return [y0 - y_min, d.dot(lado), absf(y0 - em.y) < 0.7]       # [desceu, foi para o lado, começou em cima do degrau]

# 1.07: a mesma escada (direção, largura, subida, comprimento, corrimão) já foi testada 2 vezes neste local?
func _repetida(iguais: Dictionary, es: Array) -> bool:
	var chave := "%s|%.2f|%.2f|%.2f|%d" % [str((es[1] as Vector2).snapped(Vector2.ONE * 0.01)), float(es[2]), float(es[4]), float(es[5]), int(es[6]) if es.size() > 6 else 0]
	iguais[chave] = int(iguais.get(chave, 0)) + 1
	return int(iguais[chave]) > 2

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
	j.sobrevivencia.perna_quebrada = true

	# ---------- PORTAS ----------
	var c := Vector2(5472, 387)
	m.mundo.forcar(c)
	j.teleportar(Vector3(c.x, m.mundo.altura(c.x, c.y) + 0.2, c.y), 0.0)
	await q(120)
	var p = null
	for x in root.get_tree().get_nodes_in_group("portas"):
		if str(x.get("id")) == "p%d:0" % m.cidade.remapa_v5[m.cidade.remapa_v4[9195]]:     # 1.07: número de antes da igreja/prefeitura e dos portos
			p = x
	ok(p != null, "achou a porta da rua onde o jogador travou")
	if p != null:
		var b: Basis = p.global_basis
		var meio: Vector3 = p.global_position
		var presos := 0
		var casos := 0
		for prof in [0.0, -0.3]:
			for lat in [-0.5, 0.5]:
				for lado_saida in [1.0, -1.0]:
					p.definir_aberta(false)
					p._k = 0.0
					p._girar()
					await q(5)
					j.teleportar(meio + b.z * prof + b.x * lat + Vector3(0, 0.15, 0), 0.0)
					await q(15)
					p.definir_aberta(true)                       # abre com ele no vão
					await q(40)
					var andou := await _andar(meio + b.z * 3.0 * lado_saida, 2.5)
					casos += 1
					if andou < 1.5:
						presos += 1
						print("    preso: no vão (%.1f, %.1f) saindo para %s, andou %.2f m" % [prof, lat, "fora" if lado_saida > 0 else "dentro", andou])
		ok(presos == 0, "porta abrindo com o jogador no vão: sai andando, de perna quebrada (%d de %d presos)" % [presos, casos])
		ok(p._corpos[0].collision_layer == 1, "depois que ele sai, a folha volta a ser sólida")
		# meio aberta: andar contra ela termina de abrir
		p.definir_aberta(true)
		p.abertura = 0.25
		p._k = 0.25
		p._girar()
		await q(5)
		j.teleportar(meio + b.z * 2.5 + Vector3(0, 0.15, 0), 0.0)
		await q(15)
		var andou2 := await _andar(meio - b.z * 2.5, 6.0)
		ok(andou2 > 4.0, "porta quase fechada (25%%): andando contra ela, passa (andou %.1f de 5 m)" % andou2)
		ok(p.abertura == 1.0, "e ela terminou de abrir")
	# as que nascem abertas abrem pelo menos 85%
	var I = load("res://mundo/interior.gd")
	var cid = m.cidade
	var abertas := 0
	var estreitas := 0
	var vistos := 0
	for i in cid.predio_info.size():
		var e: Dictionary = cid.predio_info[i]
		if not bool(e["entra"]) or Vector2(e["x"], e["z"]).distance_to(Vector2(436, 1500)) > 1200:
			continue
		var it = I.preparar(e, i, cid)
		vistos += 1
		for pt in it.portas:
			if pt["estado"] == "aberta":
				abertas += 1
				if float(pt["abertura"]) < 0.85:
					estreitas += 1
		if vistos >= 60:
			break
	ok(abertas > 20 and estreitas == 0, "portas que nascem abertas abrem pelo menos 85%% (%d abertas em %d prédios, %d estreitas)" % [abertas, vistos, estreitas])

	# ---------- CORRIMÃO: escada de dentro ----------
	j.sobrevivencia.perna_quebrada = false          # (mancando ele nem chega na beirada em 2,5 s)
	var testados := 0
	var caiu := 0
	var trancou := 0
	for i in cid.predio_info.size():
		if testados >= 3:
			break
		var e: Dictionary = cid.predio_info[i]
		if not bool(e["entra"]) or Vector2(e["x"], e["z"]).distance_to(Vector2(436, 1500)) > 2500:
			continue
		var it = I.preparar(e, i, cid)
		if it.extras < 2:
			continue
		var cc := Vector2(e["x"], e["z"])
		m.mundo.forcar(cc)
		j.teleportar(Vector3(cc.x + float(e["sx"]) * 0.5 + 6.0, m.mundo.altura(cc.x, cc.y) + 0.2, cc.y), 0.0)
		m.interiores.abrir_agora(cc)
		await q(10)
		var no: Node3D = m.interiores.abertos.get(i)
		if no == null:
			continue
		testados += 1
		var es: Dictionary = it._esc()
		var borda := float(es["a"][0])
		for lance in [0, 1]:                              # lance A sai do térreo, lance B do 1º andar
			var faixa: Array = es["a"] if lance == 0 else es["b"]
			var w_meio := (float(faixa[0]) + float(faixa[1])) * 0.5
			var d := (float(es["d0"]) + float(es["d1"])) * 0.5
			var y: float = lance * float(it.ALTURA_ANDAR) + float(it.ALTURA_ANDAR) * 0.5
			var p_l: Vector2 = it._xz(d, w_meio)
			var p_b: Vector2 = it._xz(d, borda)
			var em: Vector3 = no.global_transform * Vector3(p_l.x, y, p_l.y)
			var para_borda: Vector3 = no.global_transform * Vector3(p_b.x, y, p_b.y) - em
			para_borda.y = 0.0
			var r := await _de_lado(em, para_borda.normalized(), 2.5)
			if not r[2]:
				caiu += 1
				print("    não ficou no degrau: prédio %d lance %s" % [i, "AB"[lance]])
			if r[2] and float(r[0]) > 1.2:
				caiu += 1
				print("    caiu: prédio %d lance %s desceu %.1f m (foi %.1f m para o lado)" % [i, "AB"[lance], r[0], r[1]])
		# 1.03: o caminho todo: sobe o lance A, atravessa o patamar e sobe o lance B (o corrimão não pode trancar)
		var wa := (float(es["a"][0]) + float(es["a"][1])) * 0.5
		var wb := (float(es["b"][0]) + float(es["b"][1])) * 0.5
		var H := float(it.ALTURA_ANDAR)
		var pontos := [[float(es["d0"]) - 0.4, wa], [float(es["d1"]) + 0.6, wa], [float(es["d1"]) + 0.6, wb], [float(es["d0"]) - 0.4, wb]]
		var p0: Vector2 = it._xz(pontos[0][0], pontos[0][1])
		j.teleportar(no.global_transform * Vector3(p0.x, 0.3, p0.y), 0.0)
		await q(20)
		var chegou := true
		for k in range(1, pontos.size()):
			var pk: Vector2 = it._xz(pontos[k][0], pontos[k][1])
			var alvo: Vector3 = no.global_transform * Vector3(pk.x, 0.0, pk.y)
			await _andar(alvo, 8.0)
			if Vector2(j.global_position.x - alvo.x, j.global_position.z - alvo.z).length() > 0.8:
				chegou = false
				print("    trancou: prédio %d indo ao ponto %d da escada (parou a %.1f m, altura %.1f)" % [i, k, Vector2(j.global_position.x - alvo.x, j.global_position.z - alvo.z).length(), j.global_position.y - no.global_position.y])
				break
		var no_2o: bool = absf(j.global_position.y - no.global_position.y - 2.0 * H) < 0.6
		if not chegou or not no_2o:
			trancou += 1
		m.interiores.fechar(i)
		await q(3)
	ok(trancou == 0, "subindo a escada de dentro do térreo ao 2º andar, o corrimão não tranca o patamar (%d trancados)" % trancou)
	ok(testados >= 2 and caiu == 0, "escada de dentro: andando contra o corrimão no meio do lance não cai no vão (%d prédios, %d quedas)" % [testados, caiu])

	# ---------- CORRIMÃO: locais especiais ----------
	var L = load("res://mundo/locais.gd")
	var feitos := {}
	var escadas := 0
	var quedas := 0
	var andadas := 0
	var trancadas := 0
	for li in L.LOCAIS.size():
		var tipo: String = L.LOCAIS[li][0]
		if feitos.has(tipo):
			continue
		feitos[tipo] = true
		var prep = load("res://mundo/local.gd").preparar(tipo, li, int(L.LOCAIS[li][3]), Vector2(L.LOCAIS[li][1], L.LOCAIS[li][2]))
		var com: Array = []
		for es in prep.escadas:
			if es.size() > 6 and int(es[6]) != 0:
				com.append(es)
		if prep.escadas.is_empty():
			continue
		var cl := Vector2(L.LOCAIS[li][1], L.LOCAIS[li][2])
		m.mundo.forcar(cl)
		var borda_l: Vector2 = L.local_para_mundo(li, Vector2(0, (L.TAMANHO[tipo] as Vector2).y * 0.5 + 3.0))
		j.teleportar(Vector3(borda_l.x, m.mundo.altura(borda_l.x, borda_l.y) + 0.2, borda_l.y), 0.0)
		m.locais.abrir_agora(cl)
		await q(10)
		var no: Node3D = m.locais.abertos.get(li)
		if no == null:
			continue
		# 1.04: sobe e desce ANDANDO cada escada do local (sem pular): do 1º degrau até depois do topo e de volta
		var iguais := {}
		for es in prep.escadas:
			if _repetida(iguais, es):
				continue
			var ini2: Vector2 = es[0]
			var dir2: Vector2 = es[1]
			var pe: Vector2 = ini2 + dir2 * 0.3
			var alto: Vector2 = ini2 + dir2 * (float(es[5]) + 1.2)
			j.teleportar(no.global_transform * Vector3(pe.x, float(es[3]) + 0.4, pe.y), 0.0)
			j.velocity = Vector3.ZERO
			await q(20)
			var a_alto: Vector3 = no.global_transform * Vector3(alto.x, float(es[3]) + float(es[4]), alto.y)
			await _andar(a_alto, 16.0)
			var subiu: bool = Vector2(j.global_position.x - a_alto.x, j.global_position.z - a_alto.z).length() < 0.8
			var a_pe: Vector3 = no.global_transform * Vector3(pe.x, float(es[3]), pe.y)
			await _andar(a_pe, 16.0)
			var desceu: bool = Vector2(j.global_position.x - a_pe.x, j.global_position.z - a_pe.z).length() < 0.8
			andadas += 1
			if not subiu or not desceu:
				trancadas += 1
				print("    %s: escada de %s %s" % [tipo, str(ini2), "não chega no topo" if not subiu else "não desce"])
		iguais.clear()
		for es in com:
			if _repetida(iguais, es):
				continue
			var ini: Vector2 = es[0]
			var dir: Vector2 = es[1]
			var lat := Vector2(-dir.y, dir.x) * float(es[6])
			var meio_l: Vector2 = ini + dir * float(es[5]) * 0.5
			var y := float(es[3]) + float(es[4]) * 0.5
			var em: Vector3 = no.global_transform * Vector3(meio_l.x, y, meio_l.y)
			var ld: Vector3 = no.global_basis * Vector3(lat.x, 0.0, lat.y)
			escadas += 1
			var r := await _de_lado(em, ld.normalized(), 2.5)
			if not r[2]:
				quedas += 1
				print("    não ficou no degrau: %s escada de %s" % [tipo, str(ini)])
			elif float(r[0]) > 1.2:
				quedas += 1
				print("    caiu: %s escada de %s desceu %.1f m (foi %.1f m para o lado)" % [tipo, str(ini), r[0], r[1]])
		m.locais.fechar(li)
		await q(3)
	ok(escadas >= 2 and quedas == 0, "escadas dos locais especiais: o corrimão segura (%d escadas, %d quedas)" % [escadas, quedas])
	ok(andadas >= 15 and trancadas == 0, "sobe e desce andando todas as escadas dos locais especiais, sem pular (%d escadas, %d trancadas)" % [andadas, trancadas])
	print("falhas: ", falhas)
	quit()
