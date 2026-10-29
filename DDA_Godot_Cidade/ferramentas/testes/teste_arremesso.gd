extends SceneTree
# TESTE: ARREMESSO (1.00, armas/arremesso.gd). Com o jogo de verdade, numa rua aberta:
#   tijolo na mão + MIRAR = arco e anel onde cai · soltar o ATIRAR joga (sai 1 da pilha) · cai perto do anel, faz
#   barulho e fica no chão (dá para pegar) · o infectado perto do barulho vai ver (e não te vê) · garrafa de vidro
#   quebra (não fica no chão) e chama direto · acertar um infectado machuca e o alerta · arremesso de um amigo (rede):
#   voa e faz barulho, mas não deixa item nem machuca · garrafa de metal também serve · itens novos têm ícone e loot.
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
var A
var V
var Item

func _limpar() -> void:
	for v in m.vagos.vivos.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	m.vagos.vivos.clear()
	m.vagos.por_id.clear()

func _ir(p: Vector3) -> void:
	m.mundo.forcar(Vector2(p.x, p.z))
	j.teleportar(p + Vector3(0, 0.15, 0), 0.0)
	j.velocity = Vector3.ZERO

func _rua_aberta() -> Vector3:
	var base: Vector3 = j.global_position
	for tent in 600:
		var a := randf() * TAU
		var p := base + Vector3(cos(a), 0, sin(a)) * randf_range(50.0, 900.0)
		var dir := Vector3(1, 0, 0) if tent % 2 == 0 else Vector3(0, 0, 1)
		var bom := true
		for k in range(-4, 16):
			var x := p + dir * (k * 3.5)
			if not m.vagos._livre(x.x, x.z) or m.mundo.dentro_de_obstaculo(x.x, x.z, 1.5):
				bom = false
				break
		if bom:
			_dir = dir
			return Vector3(p.x, m.mundo.altura(p.x, p.z), p.z)
	return base
var _dir := Vector3(1, 0, 0)

func _na_mao(id: String, n := 1):
	var it = Item.novo(id, n)
	var velho = j.inventario.slots.get("maos")
	if velho != null:
		j.inventario.retirar(velho)
	j.inventario.slots["maos"] = it
	it.slot = "maos"
	j.inventario._depois()
	return it

func _itens_chao(id: String, perto: Vector3, raio: float) -> int:
	var n := 0
	for no in root.get_tree().get_nodes_in_group("itens_chao"):
		if is_instance_valid(no) and no.item != null and no.item.id == id and (no as Node3D).global_position.distance_to(perto) < raio:
			n += 1
	return n

func _infectado_em(p: Vector3, olhando: Vector3):
	var v = m.vagos._criar(Vector3(p.x, m.mundo.altura(p.x, p.z), p.z), Vector3.INF)
	var d: Vector3 = olhando - p
	v.rotation.y = atan2(-d.x, -d.z)
	v.vagar()
	v._espera = 99.0
	return v

func _r():
	await q(20)
	m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	j = m.jogador
	A = j.arremesso
	V = load("res://inimigos/vago.gd")
	Item = load("res://inventario/item.gd")
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	if m.vagos.get("diretor") != null:
		m.vagos.diretor._t_horda = 9999.0
	m.clima.hora = 12.0
	await q(10)
	_limpar()
	var rua := _rua_aberta()
	_ir(rua)
	await q(30)
	j.cam_yaw = atan2(-_dir.x, -_dir.z)
	await q(5)
	print("  rua aberta em ", rua, " olhando para ", _dir)
	ok(A != null and A.get_parent() == j, "o jogador tem o nó de arremesso")

	# ---- 1. arco e anel ----
	var tij = _na_mao("tijolo", 2)
	await q(2)
	ok(A.item_na_mao() == tij and A.pode(), "tijolo na mão: pronto para arremessar")
	j._mirar_ligado = true
	await q(6)
	var anel: Vector3 = A._alvo.global_position
	var d_anel := Vector2(anel.x - rua.x, anel.z - rua.z)
	ok(A._arco.visible and A._alvo.visible, "segurando MIRAR: aparece o arco e o anel onde cai")
	ok(d_anel.length() > 8.0 and d_anel.length() < 35.0 and d_anel.normalized().dot(Vector2(_dir.x, _dir.z)) > 0.8,
		"o anel fica na sua frente, a %.1f m" % d_anel.length())
	j._mirar_ligado = false
	await q(3)
	ok(not A._arco.visible, "soltou o MIRAR: o arco some")

	# ---- 2. joga o tijolo: barulho chama o infectado, o tijolo fica no chão ----
	var alem := anel + _dir * 9.0
	var v1 = _infectado_em(alem, alem + _dir * 10.0)         # de costas para você
	await q(5)
	var n_antes: int = A.arremessos
	A._segurando = true                                          # estava segurando o ATIRAR...
	await q(3)                                                   # ... e soltou (o gatilho é falso aqui)
	ok(A.arremessos == n_antes + 1 or A._fila.size() == 1, "soltou o ATIRAR: arremessou")
	ok(tij.qtd == 1 and j.inventario.slots.get("maos") == tij, "sai um tijolo da pilha (sobra %d na mão)" % tij.qtd)
	await seg(2.5)
	ok(A.arremessos == n_antes + 1, "o tijolo saiu da mão")
	ok(A.ultima_batida != Vector3.INF and A.ultima_batida.distance_to(anel) < 2.5, "caiu onde o anel mostrava (%.2f m do anel)" % A.ultima_batida.distance_to(anel))
	ok(_itens_chao("tijolo", A.ultima_batida, 4.0) == 1, "o tijolo ficou no chão (dá para pegar de volta)")
	var foco: Vector3 = v1._foco if v1.estado == V.DESCONFIADO else v1._destino
	ok((v1.estado == V.DESCONFIADO or v1.estado == V.INVESTIGANDO) and Vector2(foco.x - A.ultima_batida.x, foco.z - A.ultima_batida.z).length() < 6.0,
		"o infectado a 9 m ouviu e foi ver o barulho (%s)" % V.NOMES[v1.estado])
	ok(not v1.esta_cacando(), "e não te descobriu")
	_limpar()

	# ---- 3. garrafa de vidro: quebra e chama direto ----
	var gv = _na_mao("garrafa_vidro", 1)
	j._mirar_ligado = true
	await q(6)
	anel = A._alvo.global_position
	j._mirar_ligado = false
	var v2 = _infectado_em(anel + _dir * 14.0, anel + _dir * 30.0)
	await q(5)
	A._segurando = true
	await q(3)
	await seg(2.5)
	ok(j.inventario.slots.get("maos") == null, "a garrafa saiu da mão (era a única)")
	ok(_itens_chao("garrafa_vidro", A.ultima_batida, 5.0) == 0, "a garrafa de vidro quebrou (não fica no chão)")
	ok(v2.estado == V.INVESTIGANDO and Vector2(v2._destino.x - A.ultima_batida.x, v2._destino.z - A.ultima_batida.z).length() < 7.0,
		"vidro quebrando (32 m) faz o infectado a 14 m ir direto ver (%s)" % V.NOMES[v2.estado])
	_limpar()

	# ---- 4. acertar um infectado ----
	var p6 := rua + _dir * 6.0
	var v3 = _infectado_em(p6, p6 + _dir * 10.0)
	await q(3)
	var vida0: float = v3.vida
	var pj := {"no": null, "p": v3.global_position, "v": -_dir * 12.0, "id": "tijolo", "item": Item.novo("tijolo", 1), "t": 0.0, "bateu": false,
		"def": Item.novo("tijolo", 1).def()["arremesso"], "giro": Vector3.ZERO}
	A._bateu(pj, {"position": v3.global_position + Vector3(0, 1.6, 0), "normal": _dir, "collider": v3}, _dir * 12.0)
	await q(3)
	ok(v3.vida < vida0 and (v3.esta_cacando() or v3._depois_levantar == V.PERSEGUINDO), "tijolo na cabeça machuca (%.0f -> %.0f) e ele te descobre (às vezes cai e levanta vindo)" % [vida0, v3.vida])
	_limpar()

	# ---- 5. arremesso de um amigo (rede): voa e faz barulho, mas não deixa item nem machuca ----
	var v4 = _infectado_em(rua + _dir * 25.0, rua + _dir * 40.0)
	await q(3)
	var de := rua + Vector3(0, 1.6, 0)
	var antes_chao := _itens_chao("tijolo", rua, 60.0)
	A.lancar("tijolo", de, (_dir + Vector3.UP * 0.28).normalized() * 15.0, null)
	await seg(2.5)
	ok(_itens_chao("tijolo", rua, 60.0) == antes_chao, "o tijolo do amigo não vira item aqui (o dele aparece pela rede)")
	ok(v4.estado == V.DESCONFIADO or v4.estado == V.INVESTIGANDO, "mas os infectados daqui ouvem a batida (%s)" % V.NOMES[v4.estado])
	_limpar()

	# ---- 6. garrafa de metal (vazia) também serve; itens novos ----
	_na_mao("garrafa_vazia", 1)
	await q(2)
	ok(A.item_na_mao() != null, "a garrafa vazia de metal também dá para arremessar")
	var Itens = load("res://inventario/itens.gd")
	ok(ResourceLoader.exists("res://inventario/icones/tijolo.png") and ResourceLoader.exists("res://inventario/icones/garrafa_vidro.png"), "tijolo e garrafa de vidro têm ícone")
	var Loot = load("res://mundo/loot_mundo.gd")
	var no_lixo := false
	for e in Loot.TABELAS["lixo"]:
		if e[0] == "garrafa_vidro":
			no_lixo = true
	ok(no_lixo and Itens.def("tijolo").has("arremesso"), "aparecem no loot (lixo, chão dos prédios...)")
	print("falhas: ", falhas)
	quit()
