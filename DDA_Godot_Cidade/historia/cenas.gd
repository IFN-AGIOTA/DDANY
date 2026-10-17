extends RefCounted
# ROTEIRO DAS CUTSCENES do Ato 1 (o "como" fica em historia/cutscene.gd; as falas vêm do livro).
# Cada cena recebe cs (cutscene.gd) e h (historia.gd, com os lugares calculados da história).
# Câmera: cs.camera(de, para, olhando_de, olhando_para, segundos, fov) · cs.cortar(pos, alvo)
# Atores: cs.pessoa(id, "dominic"/"greg"/"mavie"/"garoto"/"bartender", arma, pos, giro) · cs.infectado(...) ·
#         cs.carro(...) · cs.andar(id, destino, vel) · cs.pose(id, "acenar"...) · cs.embarcar(pessoa, carro, lugar)
# Falas: await cs.fala("GREG", "texto")  ·  Tempo: await cs.esperar(s)
# Mexa AQUI para: enquadramentos, movimentos e a ordem de cada cena.

const UP := Vector3.UP

static func _chao(h, p: Vector2) -> Vector3:
	return Vector3(p.x, h.main.mundo.altura(p.x, p.y), p.y)

static func _giro(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)

# ---------- CAPÍTULO 1: a largada ----------
static func largada(cs, h, inicio: Vector2, dir: Vector2) -> void:
	var lado := Vector2(-dir.y, dir.x)
	var pd := _chao(h, inicio - lado * 1.3)
	var pg := _chao(h, inicio + lado * 1.3)
	var pk := _chao(h, inicio + dir * 7.0)
	var giro := _giro(dir)
	var d3 := Vector3(dir.x, 0, dir.y)
	var l3 := Vector3(lado.x, 0, lado.y)
	h.main.mundo.forcar(inicio)
	cs.pessoa("dominic", "dominic", "", pd, giro)
	cs.pessoa("greg", "greg", "", pg, giro)
	cs.pessoa("garoto", "garoto", "", pk, giro + PI)
	cs.pose("garoto", "segurar_luz")
	var centro := (pd + pg) * 0.5 + Vector3(0, 1.2, 0)
	# plano aberto girando em volta dos dois
	cs.camera(centro + d3 * 9.0 + l3 * 6.0 + UP * 3.5, centro + d3 * 7.0 - l3 * 6.0 + UP * 2.0, centro, centro, 7.0, 45.0)
	await cs.fala("", "As luzes de Nova York ardiam como brasas no asfalto molhado. Era mais uma noite de corrida ilegal. A última.")
	cs.camera(pd + d3 * 2.2 - l3 * 0.8 + UP * 1.65, pd + d3 * 1.8 - l3 * 0.6 + UP * 1.6, pd + UP * 1.6, pd + UP * 1.6, 3.5, 35.0)
	await cs.fala("DOMINIC", "Vamos ver se você consegue me acompanhar hoje.")
	cs.camera(pg + d3 * 2.2 + l3 * 0.8 + UP * 1.6, pg + d3 * 1.8 + l3 * 0.6 + UP * 1.6, pg + UP * 1.55, pg + UP * 1.55, 3.0, 35.0)
	await cs.fala("GREG", "Não vou te dar essa vitória fácil, amigo.")
	# o garoto com a luz
	cs.camera(pk - d3 * 4.0 + UP * 0.6, pk - d3 * 3.0 + UP * 0.8, pk + UP * 2.0, pk + UP * 2.2, 2.5, 40.0)
	await cs.esperar(1.6)
	cs.pose("garoto", "")
	await cs.fala("", "A luz caiu.", 1.2)
	# disparam
	cs.andar("dominic", pd + d3 * 40.0, 7.2)
	cs.andar("greg", pg + d3 * 40.0, 7.0)
	cs.andar("garoto", pk + l3 * 3.0, 3.0)
	cs.camera(centro - d3 * 3.0 + UP * 0.4, centro + d3 * 6.0 + UP * 1.0, centro + d3 * 6.0, centro + d3 * 30.0, 3.0, 55.0)
	await cs.fala("", "Cruze a cidade pelos pontos de controle e passe a linha que os corredores chamam de “A Morte do Medo”.", 3.5)

# ---------- CAPÍTULO 1: a chegada ----------
static func chegada(cs, h, fim: Vector2, dir: Vector2) -> void:
	var lado := Vector2(-dir.y, dir.x)
	var d3 := Vector3(dir.x, 0, dir.y)
	var l3 := Vector3(lado.x, 0, lado.y)
	var pf := _chao(h, fim)
	h.main.mundo.forcar(fim)
	cs.pessoa("dominic", "dominic", "", pf - d3 * 2.0, _giro(dir))
	cs.pessoa("greg", "greg", "", pf - d3 * 26.0 + l3 * 1.5, _giro(dir))
	cs.cortar(pf + d3 * 6.0 + l3 * 3.0 + UP * 1.5, pf - d3 * 6.0 + UP * 1.2, 45.0)
	await cs.fala("", "A MORTE DO MEDO.", 1.5)
	cs.andar("greg", pf - d3 * 1.0 + l3 * 1.4, 6.5)
	cs.camera(pf + d3 * 6.0 + l3 * 3.0 + UP * 1.5, pf + d3 * 3.0 + l3 * 4.0 + UP * 1.7, pf - d3 * 12.0 + UP * 1.2, pf + UP * 1.4, 3.5, 45.0)
	await cs.esperar(3.2)
	cs.olhar("greg", cs.pos("dominic"))
	cs.olhar("dominic", cs.pos("greg"))
	cs.pose("greg", "acenar")
	await cs.fala("GREG", "Quase te peguei dessa vez!")
	cs.pose("greg", "")
	cs.cortar(cs.pos("greg") + l3 * 1.8 + UP * 1.6, cs.pos("dominic") + UP * 1.6, 38.0)
	await cs.fala("DOMINIC", "Você está melhorando, mas ainda precisa de mais prática.")
	# o abraço
	cs.andar("greg", cs.pos("dominic") + l3 * 0.55, 1.5)
	cs.pose("greg", "abraco")
	cs.pose("dominic", "abraco")
	var meio: Vector3 = (cs.pos("dominic") + cs.pos("greg")) * 0.5
	cs.camera(meio + d3 * 3.5 + UP * 1.7, meio + d3 * 2.6 + l3 * 1.0 + UP * 1.6, meio + UP * 1.4, meio + UP * 1.4, 4.0, 40.0)
	await cs.fala("", "Eles se abraçaram como velhos soldados. Aquela vitória não importava tanto quanto a amizade entre eles.")

# ---------- CAPÍTULO 2: o bar ----------
static func bar(cs, h, falas: Array) -> void:
	var base: Vector3 = h.main.jogador.global_position + Vector3(0, -80.0, 0)   # sala fechada, longe de tudo
	var bar: Dictionary = cs.cenario_bar(base)
	cs.pessoa("dominic", "dominic", "", base + Vector3(1.5, 0, 1.4), -PI * 0.5)
	cs.pessoa("greg", "greg", "", base + Vector3(2.9, 0, 1.4), PI * 0.5)
	cs.pessoa("bartender", "bartender", "", base + Vector3(-1.0, 0, -3.2), 0.0)
	cs.pose("dominic", "sentado")
	cs.pose("greg", "sentado")
	var mesa := base + Vector3(2.2, 1.2, 1.4)
	cs.camera(base + Vector3(-3.5, 2.4, 3.2), base + Vector3(-2.5, 2.0, 3.4), mesa, mesa, 6.0, 50.0)
	var tela: StandardMaterial3D = bar["tela"]
	var luz: OmniLight3D = bar["luz_tv"]
	for l in falas:
		var quem: String = l[0]
		var texto: String = l[1]
		match quem:
			"DOMINIC":
				cs.cortar(base + Vector3(3.5, 1.45, 2.0), base + Vector3(1.5, 1.35, 1.4), 38.0)
			"GREG":
				cs.cortar(base + Vector3(0.9, 1.45, 0.8), base + Vector3(2.9, 1.35, 1.4), 38.0)
			"TV":
				cs.camera(base + Vector3(2.4, 1.6, 1.6), base + Vector3(3.3, 1.9, 1.5), base + Vector3(4.6, 2.1, 1.4), base + Vector3(4.6, 2.1, 1.4), 4.0, 40.0)
		# a TV pisca com o noticiário
		tela.albedo_color = Color(randf_range(0.4, 0.9), randf_range(0.1, 0.3), randf_range(0.1, 0.2))
		luz.light_energy = randf_range(0.6, 1.4)
		await cs.fala(quem, texto)
		if cs.pulando:
			return
	cs.camera(base + Vector3(-1.0, 2.6, 3.6), base + Vector3(-3.0, 2.8, 3.6), mesa, mesa, 3.0, 50.0)
	await cs.esperar(2.0)

# ---------- CAPÍTULO 3: no prédio do Greg, a Mavie chega ----------
static func greg_mavie(cs, h, falas: Array) -> void:
	var g: Vector2 = h._predio_greg
	h.main.mundo.forcar(g)
	var pj: Vector3 = h.main.jogador.global_position
	var dir := Vector2(pj.x - g.x, pj.z - g.y)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2(1, 0)
	var lado := Vector2(-dir.y, dir.x)
	var d3 := Vector3(dir.x, 0, dir.y)
	var l3 := Vector3(lado.x, 0, lado.y)
	var pgr := _chao(h, g)
	var pdo := _chao(h, g + dir * 1.8)
	cs.pessoa("greg", "greg", "taco", pgr, _giro(dir))
	cs.pessoa("dominic", "dominic", "", pdo, _giro(-dir))
	var meio := (pgr + pdo) * 0.5 + UP * 1.4
	cs.camera(meio + l3 * 6.0 + UP * 1.2, meio + l3 * 4.0 + d3 * 1.0 + UP * 0.6, meio, meio, 5.0, 45.0)
	var mavie_veio := false
	for l in falas:
		var quem: String = l[0]
		var texto: String = l[1]
		if quem == "GREG":
			cs.cortar(pdo + l3 * 0.9 + UP * 1.65, pgr + UP * 1.55, 38.0)
		elif quem == "DOMINIC":
			cs.cortar(pgr + l3 * 0.9 + UP * 1.6, pdo + UP * 1.6, 38.0)
		elif quem == "MAVIE" and not mavie_veio:
			mavie_veio = true
			var pm := _chao(h, g - lado * 24.0)
			cs.pessoa("mavie", "mavie", "", pm, _giro(lado))
			cs.andar("mavie", pgr - l3 * 1.0, 5.0)
			cs.olhar("greg", pm)
			cs.olhar("dominic", pm)
			cs.camera(pgr + l3 * 2.0 + UP * 1.6, pgr + l3 * 1.0 + d3 * 2.0 + UP * 1.6, pm + UP * 1.3, pgr - l3 * 1.0 + UP * 1.3, 4.5, 45.0)
		elif texto.begins_with("Um corte"):
			cs.pose("greg", "abraco")
			cs.pose("mavie", "abraco")
			cs.andar("greg", pgr - l3 * 0.5, 1.2)
		elif texto.begins_with("No fim da rua"):
			var pv := _chao(h, g + lado * 38.0 + dir * 2.0)
			cs.infectado("vulto", pv, _giro(-lado), 11)
			cs.andar("vulto", pv - l3 * 30.0, 0.8)
			cs.camera(pdo + UP * 1.7 - l3 * 1.0, pdo + UP * 1.7 + l3 * 1.0, pv + UP * 1.2, pv + UP * 1.1, 4.0, 22.0)
		elif quem == "":
			pass
		await cs.fala(quem, texto)
		if cs.pulando:
			return
	cs.pose("greg", "")
	cs.pose("mavie", "")

# direção em que a rua continua por mais tempo a partir de p (o carro sai por ela, sem cair no mar)
static func _direcao_da_rua(h, p: Vector2) -> Vector2:
	var cid = h.main.cidade
	var melhor := Vector2(1, 0)
	var mn := -1
	for k in 16:
		var d := Vector2(cos(TAU * k / 16.0), sin(TAU * k / 16.0))
		var n := 0
		for passo in range(1, 9):
			var q := p + d * passo * 20.0
			var c := int((q.x + cid.WORLD.x) / cid.CELL)
			var l := int((q.y + cid.WORLD.y) / cid.CELL)
			if c < 0 or c >= cid.W or l < 0 or l >= cid.H or cid.road[l * cid.W + c] != 1:
				break
			n += 1
		if n > mn:
			mn = n
			melhor = d
	return melhor

# ---------- FIM DO ATO 1: a fuga no carro do Greg ----------
static func fuga(cs, h, falas: Array) -> void:
	var c: Vector2 = h._carro_greg
	h.main.mundo.forcar(c)
	var dir := _direcao_da_rua(h, c)
	var d3 := Vector3(dir.x, 0, dir.y)
	var l3 := Vector3(-dir.y, 0, dir.x)
	var pc := _chao(h, c - dir * 6.0)
	cs.carro("carro", pc, atan2(-dir.y, dir.x), Color(0.15, 0.18, 0.28))
	for par in [["greg", "greg", "motorista"], ["dominic", "dominic", "passageiro"], ["mavie", "mavie", "atras"]]:
		cs.pessoa(par[0], par[1], "", pc, 0.0)
		cs.embarcar(par[0], "carro", par[2])
	# infectados chegando por trás
	for k in 3:
		var pv := pc - d3 * (14.0 + k * 4.0) + l3 * (k - 1) * 2.5
		cs.infectado("v%d" % k, pv, atan2(-d3.x, -d3.z), 20 + k)
		cs.andar("v%d" % k, pc + d3 * 10.0, 2.8)
	cs.cortar(pc + d3 * 7.0 + l3 * 3.5 + UP * 1.3, pc + UP * 1.0, 40.0)
	await cs.fala("", "Greg girou a chave na ignição, e o motor rugiu como uma fera despertando.", 3.0)
	cs.andar("carro", pc + d3 * 150.0, 13.0)
	cs.camera(pc + d3 * 7.0 + l3 * 3.5 + UP * 1.3, pc + d3 * 9.0 + l3 * 5.0 + UP * 2.5, pc + d3 * 4.0 + UP * 1.0, pc + d3 * 60.0 + UP * 1.0, 5.0, 45.0)
	for l in falas:
		await cs.fala(l[0], l[1])
		if cs.pulando:
			return
	await cs.esperar(1.0)
