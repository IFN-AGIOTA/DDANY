extends SceneTree
# TESTE: CONSTRUIR A BASE (0.90). Sem martelo/tábuas não deixa; com eles, a peça fantasma aparece na frente
# (verde/vermelha), a obra leva o tempo e paga as tábuas. A PAREDE bloqueia e um infectado bate até quebrar; a
# PAREDE COM PORTA tem porta de verdade; a BARRICADA BAIXA eles pulam; o CAIXOTE guarda itens no loot; a CAMA vira
# o ponto de renascer; o COLETOR enche na chuva e enche a garrafa; DESMONTAR devolve tábuas; tudo vai no jogo salvo.
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
var cons

# põe a peça "tipo" na frente do jogador (vira para "yaw") e espera a obra
func construir(tipo: String) -> Node3D:
	var antes: Array = cons.pecas.keys()
	var y0: float = j.cam_yaw
	for k in 4:
		j.cam_yaw = y0 + k * PI * 0.5
		cons.comecar(tipo)
		await q(4)
		if cons._valido:
			break
		cons.cancelar()
	if cons.tipo_pondo == "":
		return null
	cons.confirmar()
	await q(int(cons.TEMPO_CONSTRUIR * 60.0) + 30)
	for k in cons.pecas:
		if not k in antes:
			return cons.pecas[k]
	return null

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
	cons = m.construcao
	var Item = load("res://inventario/item.gd")
	var inv = j.inventario
	inv.aviso.connect(func(t): print("    aviso: ", t))
	ok(cons != null, "main criou a construção")
	# sem martelo: não começa
	for id_t in ["martelo", "tabuas", "trapos"]:
		inv.consumir(id_t, inv.contar(id_t))
	cons._escolheu("parede")
	ok(cons.tipo_pondo == "", "sem martelo não dá para construir")
	inv._guardar_ou_largar(Item.novo("martelo", 1))
	cons._escolheu("parede")
	ok(cons.tipo_pondo == "", "com martelo e sem tábuas também não")
	for k in 4:
		inv._guardar_ou_largar(Item.novo("tabuas", 10))
	inv._guardar_ou_largar(Item.novo("trapos", 4))
	ok(inv.contar("tabuas") == 40, "40 tábuas no inventário (tem %d)" % inv.contar("tabuas"))
	cons.abrir_menu()
	await q(2)
	ok(cons._menu != null and m.controles.bloqueado, "menu CONSTRUIR abre (e trava os controles)")
	cons.fechar_menu()
	await q(2)
	# um lugar aberto na rua
	var achou := false
	var base0 := Vector3.ZERO
	var tentativas := [Vector2(6230, 590), Vector2(6200, 640), Vector2(6150, 560), Vector2(6300, 700), Vector2(6100, 500)]
	for c in tentativas:
		for dx in range(-40, 41, 10):
			m.mundo.forcar(c + Vector2(dx, 0))
			j.teleportar(Vector3(c.x + dx, m.mundo.altura(c.x + dx, c.y) + 0.2, c.y), 0.0)
			await q(12)
			j.cam_yaw = 0.0
			cons.comecar("parede")
			await q(3)
			var v: bool = cons._valido
			cons.cancelar()
			if v:
				# também precisa caber a 90° e dos lados (as outras peças)
				achou = true
				base0 = j.global_position
				break
		if achou:
			break
	ok(achou, "achou um lugar aberto para a base (%s)" % str(base0))
	if not achou:
		print("falhas: ", falhas)
		quit()
		return
	ok(cons._fantasma == null and not j.construindo, "cancelar tira o fantasma")
	# PAREDE
	var t0: int = inv.contar("tabuas")
	var parede = await construir("parede")
	ok(parede != null, "a PAREDE ficou pronta depois da obra")
	ok(inv.contar("tabuas") == t0 - 3, "pagou 3 tábuas (%d -> %d)" % [t0, inv.contar("tabuas")])
	ok(cons.tipo_pondo == "parede" and j.construindo, "com material sobrando, segue com outra parede na mão")
	cons.cancelar()
	if parede == null:
		print("falhas: ", falhas)
		quit()
		return
	# o fantasma não cabe em cima dela
	ok(not cons.cabe("parede", parede.global_position, parede.rotation.y), "não cabe outra peça no mesmo lugar")
	# bloqueia: raio passa pela parede?
	var de: Vector3 = parede.global_transform * Vector3(0, 1.0, 1.5)
	var para: Vector3 = parede.global_transform * Vector3(0, 1.0, -1.5)
	var rq := PhysicsRayQueryParameters3D.create(de, para, 1)
	var hit: Dictionary = j.get_world_3d().direct_space_state.intersect_ray(rq)
	ok(not hit.is_empty(), "a parede tem colisão (bloqueia)")
	ok(cons.dentro(parede.global_position.x, parede.global_position.z), "infectados sabem que ali tem peça (dentro)")
	# infectado bate na parede até quebrar
	var fora: Vector3 = parede.global_transform * Vector3(0, 0.05, 1.0)
	var vz = m.vagos._criar(fora, Vector3.INF)
	await q(3)
	vz._trocar_modo(true)
	vz.estado = vz.PERSEGUINDO
	var quer: Vector3 = parede.global_position - fora
	quer.y = 0.0
	var vida0: float = parede.vida
	var bateu := false
	for k in 300:
		if not is_instance_valid(parede) or parede.vida <= 0.0:
			break
		vz.global_position = fora
		if vz._base_no_caminho(fora, quer):
			bateu = true
		parede.vida = minf(parede.vida, 30.0) if k == 3 else parede.vida
		await q(1)
	ok(bateu and vida0 > 0.0, "o infectado bate na parede")
	ok(not cons.pecas.has(parede.id if is_instance_valid(parede) else "x"), "de tanto bater, a parede quebra e sai")
	for x in m.vagos.vivos.duplicate():
		x.queue_free()
	m.vagos.vivos.clear()
	await q(3)
	# PAREDE COM PORTA
	var pp = await construir("porta")
	cons.cancelar()
	ok(pp != null and pp.porta != null, "PAREDE COM PORTA tem uma porta de verdade")
	if pp != null and pp.porta != null:
		var PortaCls = load("res://mundo/porta.gd")
		ok(PortaCls.todas.get(pp.porta.id) == pp.porta, "a porta entra na lista das portas (id %s)" % pp.porta.id)
		cons.desmontar_mais_perto()
		await q(3)
	# BARRICADA BAIXA: topo para pular
	var ce = await construir("cerca")
	cons.cancelar()
	ok(ce != null, "BARRICADA BAIXA pronta")
	if ce != null:
		var tp: float = cons.topo(ce.global_position.x, ce.global_position.z)
		ok(absf(tp - (ce.global_position.y + 1.0)) < 0.05, "a barricada tem topo para os infectados pularem")
		ok(cons.no_caminho(ce.global_transform * Vector3(0, 0, 0.8), -ce.global_transform.basis.z) == null, "baixa: eles não ficam batendo, pulam")
		cons.desmontar_mais_perto()
		await q(3)
	# CAIXOTE: guarda itens no loot
	var cx = await construir("caixa")
	cons.cancelar()
	ok(cx != null and cx.caixa != null and cx.caixa.grade != null, "CAIXOTE com grade 8x6")
	var id_cx := ""
	if cx != null and cx.caixa != null:
		id_cx = cx.id
		var it = Item.novo("trapos", 1)
		var vg: Vector3i = cx.caixa.grade.achar_vaga(it)
		cx.caixa.grade.colocar(it, vg.x, vg.y, vg.z == 1)
		ok(m.loot_mundo._grades.has("b" + cx.id), "a grade do caixote fica no loot (vai no jogo salvo e na rede)")
		var msg: String = cons.desmontar_mais_perto()
		ok(msg.contains("ESVAZIE") and cons.pecas.has(cx.id), "caixote com itens não desmonta (%s)" % msg)
		j.cam_yaw = PI * 0.5
		await q(3)
	# CAMA: renascer nela
	var cama = await construir("cama")
	cons.cancelar()
	ok(cama != null, "CAMA pronta (custa trapos também: sobraram %d)" % inv.contar("trapos"))
	if cama != null:
		ok(cama.acao(inv) == "MINHA\nCAMA", "PEGAR perto diz MINHA CAMA")
		cama.usar(inv)
		ok(cons.minha_cama == cama.id, "virou a sua cama")
		var longe: Vector3 = j.global_position + Vector3(150, 0, 0)
		m.mundo.forcar(Vector2(longe.x, longe.z))
		j.teleportar(Vector3(longe.x, m.mundo.altura(longe.x, longe.z) + 0.2, longe.z), 0.0)
		await q(5)
		j.morto = true
		m._renascer()
		await q(5)
		var dc := Vector2(j.global_position.x - cama.global_position.x, j.global_position.z - cama.global_position.z).length()
		ok(dc < 3.0, "morreu longe e renasceu na cama (a %.1f m)" % dc)
	# COLETOR: chuva e garrafa (morreu: renasceu sem nada, pega martelo e tábuas de novo)
	inv._guardar_ou_largar(Item.novo("martelo", 1))
	inv._guardar_ou_largar(Item.novo("tabuas", 10))
	j.cam_yaw = PI
	await q(3)
	var col = await construir("coletor")
	cons.cancelar()
	ok(col != null, "COLETOR DE CHUVA pronto")
	if col != null:
		ok(col.usar(inv).contains("VAZIO"), "vazio no começo")
		m.clima.chuva = 1.0
		cons._t_chuva = 0.0
		await q(3)
		ok(col.agua >= 1, "com chuva, juntou água (%d)" % col.agua)
		inv._guardar_ou_largar(Item.novo("garrafa_vazia", 1))
		var ag0: int = inv.contar("agua")
		var r: String = col.usar(inv)
		ok(inv.contar("agua") == ag0 + 1, "encheu a garrafa (%s)" % r)
	# JOGO SALVO
	var id_col: String = col.id if col != null else ""
	var n0: int = cons.pecas.size()
	var cama_id: String = cons.minha_cama
	var Salv = load("res://menu/salvamento.gd")
	Salv.salvar(m)
	var d = JSON.parse_string(FileAccess.get_file_as_string(Salv.ARQUIVO))
	ok(d is Dictionary and d.has("construcao") and (d["construcao"]["pecas"] as Array).size() == n0, "o jogo salvo leva as %d peças" % n0)
	for k in cons.pecas.keys():
		cons.remover(k)
	await q(3)
	ok(cons.pecas.is_empty(), "limpou a base")
	cons.carregar(d["construcao"])
	await q(3)
	ok(cons.pecas.size() == n0 and cons.minha_cama == cama_id, "carregou de volta (%d peças, cama %s)" % [cons.pecas.size(), cons.minha_cama])
	# DESMONTAR devolve tábuas
	var c2 = cons.pecas.get(id_col)
	ok(c2 != null, "o coletor voltou do jogo salvo")
	if true:
		if c2 != null:
			j.teleportar(c2.global_position + Vector3(1.2, 0.1, 0), 0.0)
			await q(5)
			var tb: int = inv.contar("tabuas")
			var p_perto = cons.mais_perto(j.global_position, 2.5)
			var msg2: String = cons.desmontar_mais_perto()
			ok(inv.contar("tabuas") > tb and not cons.pecas.has(p_perto.id), "DESMONTAR devolve tábuas (%s)" % msg2)
	print("falhas: ", falhas)
	quit()
