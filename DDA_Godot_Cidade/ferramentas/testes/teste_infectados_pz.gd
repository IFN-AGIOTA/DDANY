extends SceneTree
# TESTE: INFECTADOS NO ESTILO PROJECT ZOMBOID (0.89). Numa rua aberta, com o jogo de verdade:
#   velocidades (lento / rápido / corredor / rastejante) · visão (de frente, de costas, no escuro) · audição (tiro e
#   passos) · cheiro · memória · manada · derrubar e levantar (e não levantar com você em cima) · fingindo de morto ·
#   tombar por cima de barreira baixa · horda virtual (aparece perto, puxada por tiro, volta a ser grupo longe e vai no
#   jogo salvo) · puxar para o chão · ferimentos (rastejante não morde) · o vírus (febre e morte, e levanta infectado).
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
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await physics_frame

var m
var j
var V
var Cfg

func _limpar() -> void:
	for v in m.vagos.vivos.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	m.vagos.vivos.clear()
	m.vagos.por_id.clear()

# ponto de rua livre a "d" m do jogador na direção "dir" (procura um que dê)
func _ponto(base: Vector3, dir: Vector3, d: float) -> Vector3:
	for k in 24:
		var dd := dir.rotated(Vector3.UP, k * 0.26 * (1 if k % 2 == 0 else -1))
		var p := base + dd * d
		if m.vagos._livre(p.x, p.z):
			return Vector3(p.x, m.mundo.altura(p.x, p.z), p.z)
	return base + dir * d

func _novo(p: Vector3, classe := "lento", olhando_para := Vector3.INF):
	Cfg.o["z_vel"] = {"lento": "lentos", "rapido": "rapidos", "corredor": "corredores"}.get(classe, "lentos")
	var v = m.vagos._criar(p, Vector3.INF)
	if classe == "rastejante":
		v._virar_rastejante()
	elif v.classe != classe:
		v.classe = classe
		v.tipo = classe
		v._definir_velocidades()
	if olhando_para != Vector3.INF:
		var d: Vector3 = olhando_para - p
		v.rotation.y = atan2(-d.x, -d.z)
	v.vagar()
	v._espera = 99.0
	return v

# ponto aberto: rua reta de 40 m para os dois lados (para correr e olhar sem prédio no meio)
func _rua_aberta() -> Vector3:
	var c = m.cidade
	var base: Vector3 = j.global_position
	for tent in 400:
		var a := randf() * TAU
		var p := base + Vector3(cos(a), 0, sin(a)) * randf_range(50.0, 900.0)
		var dir := Vector3(1, 0, 0) if tent % 2 == 0 else Vector3(0, 0, 1)
		var bom := true
		for k in range(-12, 13):
			var x := p + dir * (k * 3.5)
			if not m.vagos._livre(x.x, x.z) or m.mundo.dentro_de_obstaculo(x.x, x.z, 1.2):
				bom = false
				break
		if bom:
			_dir_rua = dir
			return Vector3(p.x, m.mundo.altura(p.x, p.z), p.z)
	return base
var _dir_rua := Vector3(1, 0, 0)

func _ir(p: Vector3) -> void:
	m.mundo.forcar(Vector2(p.x, p.z))
	j.teleportar(p + Vector3(0, 0.15, 0), 0.0)
	j.velocity = Vector3.ZERO

func _r():
	await q(20)
	m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	j = m.jogador
	V = load("res://inimigos/vago.gd")
	Cfg = root.get_node("Config")
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0                       # a horda não cria ninguém nos primeiros testes
	m.clima.hora = 12.0
	await q(10)
	_limpar()
	var rua := _rua_aberta()
	_ir(rua)
	await q(30)
	print("  rua aberta em ", rua, " direção ", _dir_rua)
	var R = load("res://inimigos/regras_infectados.gd")

	# ---- 1. velocidades ----
	var vel := {}
	for cl in ["lento", "rapido", "corredor", "rastejante"]:
		_limpar()
		_ir(rua)
		await q(5)
		var pz := rua + _dir_rua * 30.0
		pz.y = m.mundo.altura(pz.x, pz.z)
		var v = _novo(pz, cl, rua)
		await q(3)
		v._alertar(j)
		await seg(1.5)
		var a: Vector3 = v.global_position
		await seg(2.0)
		var b: Vector3 = v.global_position
		vel[cl] = Vector2(b.x - a.x, b.z - a.z).length() / 2.0
	print("  velocidades caçando: ", vel)
	ok(vel["lento"] > 0.7 and vel["lento"] < 1.4, "lento: mais devagar que você andando (2,0 m/s): %.2f" % vel["lento"])
	ok(vel["rapido"] > 1.9 and vel["rapido"] < 2.9, "rápido: andando você não escapa, no trote (3,9) sim: %.2f" % vel["rapido"])
	ok(vel["corredor"] > 4.6 and vel["corredor"] < 6.3, "corredor: só correndo (7,2) você escapa: %.2f" % vel["corredor"])
	ok(vel["rastejante"] > 0.1 and vel["rastejante"] < 0.4, "rastejante: ~1/5 de quem anda: %.2f" % vel["rastejante"])

	# ---- 2. visão ----
	_limpar()
	_ir(rua)
	await q(5)
	var p15 := rua + _dir_rua * 15.0
	p15.y = m.mundo.altura(p15.x, p15.z)
	j.agachado = false
	var p11 := rua + _dir_rua * 11.0
	p11.y = m.mundo.altura(p11.x, p11.z)
	var v1 = _novo(p11, "lento", rua)
	await seg(2.5)
	ok(v1.esta_cacando(), "de dia, de frente, a 11 m (você parado): te vê e vem (%s)" % V.NOMES[v1.estado])
	_limpar()
	var v1b = _novo(p15, "lento", rua)
	await seg(2.5)
	ok(not v1b.esta_cacando(), "a 15 m, você PARADO: passa despercebido (%s)" % V.NOMES[v1b.estado])
	_limpar()
	var v2 = _novo(p15, "lento", p15 + (p15 - rua))      # de costas para você
	await seg(2.5)
	ok(not v2.esta_cacando(), "de costas para você: não te vê (%s)" % V.NOMES[v2.estado])
	_limpar()
	m.clima.hora = 1.5
	await q(5)
	var p10 := rua + _dir_rua * 10.0
	p10.y = m.mundo.altura(p10.x, p10.z)
	var v3 = _novo(p10, "lento", rua)
	await seg(2.5)
	print("  escuridão de madrugada: %.2f · lanterna %s" % [m.vagos.escuridao(), m.clima.lanterna_acesa])
	ok(m.clima.lanterna_acesa or not v3.esta_cacando(), "de madrugada, sem luz, a 10 m de frente: não te vê (%s)" % V.NOMES[v3.estado])
	m.clima.hora = 12.0
	_limpar()

	# ---- 3. audição ----
	var p40 := rua + _dir_rua * 40.0
	p40.y = m.mundo.altura(p40.x, p40.z)
	var v4 = _novo(p40, "lento", p40 + _dir_rua * 10.0)  # de costas
	await q(5)
	m.vagos.barulho(rua, 75.0 * 1.4, true)               # tiro de pistola
	await q(3)
	ok(v4.estado == V.INVESTIGANDO and Vector2(v4._destino.x - rua.x, v4._destino.z - rua.z).length() < 12.0,
		"tiro a 40 m: vai ver o lugar do tiro (%s, erro %.1f m)" % [V.NOMES[v4.estado], Vector2(v4._destino.x - rua.x, v4._destino.z - rua.z).length()])
	_limpar()
	var p12 := rua + _dir_rua * 12.0
	p12.y = m.mundo.altura(p12.x, p12.z)
	var v5 = _novo(p12, "lento", p12 + _dir_rua * 10.0)
	await q(3)
	m.vagos.barulho(rua, m.vagos.raio_passos(2.0, false), true)     # passos andando
	await q(3)
	ok(v5.estado == V.VAGANDO, "passos andando a 12 m: não ouve (%s)" % V.NOMES[v5.estado])
	m.vagos.barulho(rua, m.vagos.raio_passos(7.0, false), true)     # correndo
	await q(3)
	ok(v5.estado != V.VAGANDO, "passos correndo a 12 m: ouve (%s)" % V.NOMES[v5.estado])
	_limpar()

	# ---- 4. cheiro (lore) ----
	var p3 := rua + _dir_rua * 3.0
	p3.y = m.mundo.altura(p3.x, p3.z)
	j.agachado = true
	var v6 = _novo(p3, "lento", p3 + _dir_rua * 10.0)  # de costas, você agachado parado
	await seg(1.5)
	ok(v6.estado == V.INVESTIGANDO or v6.esta_cacando(), "cheiro: de costas, a 3 m, ele sente você (%s)" % V.NOMES[v6.estado])
	j.agachado = false
	_limpar()

	# ---- 5. memória ----
	for mem in [0, 3]:
		Cfg.o["z_mem"] = mem
		_ir(rua)
		await q(5)
		var v7 = _novo(rua + _dir_rua * 8.0, "lento", rua)
		v7._alertar(j)
		await q(5)
		# você some: vai para longe, atrás de tudo
		_ir(rua - _dir_rua * 60.0 + Vector3(0, 0, 0))
		j.visible = true
		await seg(5.0)
		if mem == 0:
			ok(not v7.esta_cacando(), "memória NENHUMA: 5 s depois de te perder, desistiu (%s)" % V.NOMES[v7.estado])
		else:
			ok(v7.esta_cacando(), "memória LONGA: 5 s depois ainda te procura (%s)" % V.NOMES[v7.estado])
		_limpar()
	Cfg.o["z_mem"] = 2

	# ---- 6. manada ----
	_ir(rua)
	await q(5)
	var lider = _novo(rua + _dir_rua * 20.0, "lento", rua)
	var seguidor = _novo(rua + _dir_rua * 30.0, "lento", rua + _dir_rua * 60.0)   # de costas, longe de te ver
	lider._alertar(j)
	await seg(1.5)
	ok(seguidor.estado == V.INVESTIGANDO or seguidor.esta_cacando(), "manada: vê o outro caçando e vai atrás (%s)" % V.NOMES[seguidor.estado])
	_limpar()

	# ---- 7. derrubar / levantar / você em cima ----
	var v8 = _novo(rua + _dir_rua * 5.0, "lento", rua)
	await q(3)
	v8.derrubar(1.0)
	await q(2)
	ok(v8.estado == V.CAIDO, "derrubado: fica no chão")
	await seg(3.5)
	ok(v8.estado != V.CAIDO and v8.estado != V.LEVANTANDO, "levantou depois de uns segundos (%s)" % V.NOMES[v8.estado])
	_limpar()
	var v9 = _novo(rua + _dir_rua * 0.5, "lento", rua)
	await q(3)
	v9.derrubar(1.0)
	_ir(v9.global_position)
	await seg(3.0)
	ok(v9.estado == V.CAIDO, "com você em pé em cima dele, não levanta (%s)" % V.NOMES[v9.estado])
	_ir(rua)
	_limpar()
	# golpe forte acaba derrubando
	var caiu := false
	for t in 12:
		var v10 = _novo(rua + _dir_rua * 2.0, "lento", rua)
		await q(2)
		v10.receber_golpe(60.0, _dir_rua, j)
		await q(1)
		if v10.estado == V.CAIDO:
			caiu = true
		_limpar()
		if caiu:
			break
	ok(caiu, "golpe forte (taco/cano) às vezes derruba")

	# ---- 8. fingindo de morto ----
	var pf := rua + _dir_rua * 8.0
	pf.y = m.mundo.altura(pf.x, pf.z)
	var vf = _novo(pf, "lento", rua)
	vf.estado = V.FINGINDO
	vf.modelo.deitado()
	vf._colisao_deitado(true)
	await seg(1.5)
	ok(vf.estado == V.FINGINDO, "fingindo de morto: com você a 8 m, continua deitado")
	_ir(pf - _dir_rua * 1.6)
	await seg(2.5)
	ok(vf.estado == V.LEVANTANDO or vf.esta_cacando(), "você chegou perto: levanta e vem (%s)" % V.NOMES[vf.estado])
	_ir(rua)
	_limpar()

	# ---- 9. barreira baixa ----
	var mu = m.mundo
	var achou := false
	var o: PackedFloat32Array = mu._obst
	for i in range(0, o.size(), 7):
		var alto := o[i + 4]
		if alto < 0.4 or alto > 1.0 or Vector2(o[i], o[i + 1]).distance_to(Vector2(j.global_position.x, j.global_position.z)) > 600.0:
			continue
		var c := Vector3(o[i], 0, o[i + 1])
		var giro := o[i + 2]
		# atravessa pelo lado mais fino
		var eixo := Vector3(cos(giro), 0, -sin(giro)) if o[i + 3] < o[i + 5] else Vector3(sin(giro), 0, cos(giro))
		var fino := minf(o[i + 3], o[i + 5])
		var a2 := c - eixo * (fino * 0.5 + 1.2)
		var b2 := c + eixo * (fino * 0.5 + 1.6)
		if not m.vagos._livre(a2.x, a2.z) or not m.vagos._livre(b2.x, b2.z) or mu.dentro_de_obstaculo(a2.x, a2.z, 0.3) or mu.dentro_de_obstaculo(b2.x, b2.z, 0.3):
			continue
		a2.y = mu.altura(a2.x, a2.z)
		b2.y = mu.altura(b2.x, b2.z)
		_ir(b2 + eixo * 25.0)
		await q(10)
		var vb = _novo(a2, "lento", b2)
		vb.investigar(b2 + eixo * 3.0)
		var pulou := false
		for f in 300:
			await physics_frame
			if vb._pulando > 0.0 or vb.estado == V.CAIDO:
				pulou = true
			if (vb.global_position - c).dot(eixo) > fino * 0.5 + 0.3:
				break
		ok(pulou and (vb.global_position - c).dot(eixo) > fino * 0.5, "barreira baixa (%.1f m): tombou por cima e passou" % alto)
		achou = true
		_limpar()
		break
	if not achou:
		print("  (sem barreira baixa por perto para testar)")

	# ---- 10. horda virtual ----
	_ir(rua)
	m.vagos._garantir_horda()
	var hd = m.vagos.horda
	await seg(3.0)
	var virt: int = hd.total_virtuais()
	print("  horda: %d infectados virtuais em %d grupos, %d quadras" % [virt, hd.grupos.size(), hd.quadras.size()])
	ok(virt > 30, "a cidade em volta ganhou população virtual (%d)" % virt)
	m.vagos.max_ativos = 22
	await seg(4.0)
	var reais := 0
	for v in m.vagos.vivos:
		if bool(v.da_horda):
			reais += 1
	ok(reais > 0 and reais <= 22, "perto de você viram infectados de verdade, até o limite (%d)" % reais)
	# tiro: os grupos a até 100 m vêm (0.99: um grupo virtual posto a 60 m; antes dependia de sobrar um grupo perto
	# depois de os de perto virarem infectados de verdade, e às vezes não sobrava nenhum)
	var indo := 0
	var longe_g: Dictionary = {}
	for g in hd.grupos:
		if (g["p"] as Vector2).distance_to(Vector2(j.global_position.x, j.global_position.z)) > 200.0:
			longe_g = g
			break
	if not longe_g.is_empty():
		longe_g["p"] = Vector2(j.global_position.x + 60.0, j.global_position.z)
		longe_g["d"] = Vector2.INF
	m.vagos.barulho(j.global_position, 150.0, true)
	for g in hd.grupos:
		if g["d"] != Vector2.INF and (g["d"] as Vector2).distance_to(Vector2(j.global_position.x, j.global_position.z)) < 15.0:
			indo += 1
	ok(indo > 0, "tiro: grupos da horda vêm para o barulho (%d grupos)" % indo)
	# você vai embora: quem não está caçando volta a ser grupo
	var antes: int = hd.total_virtuais() + reais
	for v in m.vagos.vivos:
		if is_instance_valid(v):
			v.vagar()
	_ir(rua + Vector3(700, 0, 0))
	await seg(3.0)
	var depois_reais := 0
	for v in m.vagos.vivos:
		if is_instance_valid(v) and bool(v.da_horda) and v.global_position.distance_to(rua) < 100.0:
			depois_reais += 1
	ok(depois_reais == 0, "longe de você eles voltam a ser grupo (sobraram %d de verdade lá)" % depois_reais)
	# jogo salvo
	var salvo: Dictionary = m.vagos.salvar()
	var n_salvo := 0
	var gs: PackedFloat32Array = salvo["horda"]["g"]
	for i in range(0, gs.size() - 4, 5):
		n_salvo += int(gs[i + 2])
	hd.carregar(salvo["horda"])
	ok(n_salvo > 30 and hd.total_virtuais() >= n_salvo - 1, "horda no jogo salvo: %d infectados voltam onde estavam (%d)" % [n_salvo, hd.total_virtuais()])
	m.vagos.max_ativos = 0
	_limpar()
	_ir(rua)
	await q(5)

	# ---- 11. puxar para o chão ----
	j.sobrevivencia.imortal = false
	j.sobrevivencia.vida = 100.0
	var tres := []
	for k in 3:
		tres.append(_novo(rua + Vector3(k, 0, 1), "lento"))
	for v in tres:
		m.vagos._contar_golpe(v)
	await q(2)
	ok(j.morto and j.sobrevivencia.causa.contains("chão"), "três te acertando juntos: puxado para o chão (%s)" % j.sobrevivencia.causa)
	_limpar()
	j.morto = false
	j.sobrevivencia.reiniciar()

	# ---- 12. ferimentos e vírus ----
	Cfg.o["z_trans"] = 1                     # só mordida
	j.sobrevivencia.imortal = true
	var mordidas_tornozelo := 0
	for k in 60:
		j.sobrevivencia.virus = -1.0
		j.sobrevivencia.receber_ataque(5.0, 0.3, j.global_position + Vector3(0, 0, 1), "tornozelo")
		if j.sobrevivencia.virus >= 0.0:
			mordidas_tornozelo += 1
	ok(mordidas_tornozelo == 0, "rastejante (tornozelo) não morde: 60 golpes, vírus %d vezes" % mordidas_tornozelo)
	var pegou := false
	for k in 80:
		j.sobrevivencia.receber_ataque(5.0, 0.3, j.global_position - j.global_basis.z * -1.0, "")
		if j.sobrevivencia.virus >= 0.0:
			pegou = true
			break
	ok(pegou, "mordida (só mordida passa): em algum golpe pegou o vírus")
	Cfg.o["z_trans"] = 0
	var sv = j.sobrevivencia
	sv.virus = sv.virus_fim * 0.6
	await q(3)
	ok("FEBRE" in sv.doencas() and sv.temperatura > 37.7, "fase febril: FEBRE e temperatura %.1f" % sv.temperatura)
	sv.imortal = false
	sv.virus = sv.virus_fim + 0.01
	var pm: Vector3 = j.global_position
	var n_antes: int = m.vagos.vivos.size()
	await q(5)
	ok(j.morto and sv.causa == "o vírus", "o vírus mata (%s)" % sv.causa)
	await seg(9.0)
	var levantou := false
	for v in m.vagos.vivos:
		if is_instance_valid(v) and v.global_position.distance_to(pm) < 3.0:
			levantou = true
	ok(levantou, "quem morre pelo vírus levanta como infectado no mesmo lugar")
	print("falhas: ", falhas)
	quit()
