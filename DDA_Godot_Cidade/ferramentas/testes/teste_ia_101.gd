extends SceneTree
# TESTE: SEGUNDA LEVA DO ESTUDO (1.01). Com o jogo de verdade, numa rua aberta:
#   · VASCULHAR: o infectado que te perde de vista vai onde te viu e ainda olha 2-3 lugares perto (para o lado em
#     que você foi) antes de voltar a vagar; o "?" fica na cabeça enquanto procura.
#   · FILA DE BARULHOS: vários barulhos no mesmo lugar no mesmo quadro viram UM; a IA ouve no quadro seguinte.
#   · ÁREA DE TOQUE: num celular comum (420 dpi, 1080 de altura) o botão pequeno pega o dedo em 48 dp; o toque entre
#     dois botões vai para o mais perto.
#   · ANISOTROPIA: no PC fica a escolhida (no celular para em 2x).
#   · SINAIS DE ACERTO: os sons "acerto" e "acerto_forte" existem.
#   · ITEM NA MÃO mirando o arremesso.
#   1.04: o "!" some quando o infectado morre · 1ª pessoa olhando para baixo: a câmera vai à frente do peito.
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
var V
var _dir := Vector3(1, 0, 0)

func _limpar() -> void:
	for v in m.vagos.vivos.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	m.vagos.vivos.clear()
	m.vagos.por_id.clear()

func _rua_aberta() -> Vector3:
	var base: Vector3 = j.global_position
	for tent in 600:
		var a := randf() * TAU
		var p := base + Vector3(cos(a), 0, sin(a)) * randf_range(50.0, 900.0)
		var dir := Vector3(1, 0, 0) if tent % 2 == 0 else Vector3(0, 0, 1)
		var bom := true
		for k in range(-6, 22):
			var x := p + dir * (k * 3.0)
			if not m.vagos._livre(x.x, x.z) or m.mundo.dentro_de_obstaculo(x.x, x.z, 1.5):
				bom = false
				break
		if bom:
			_dir = dir
			return Vector3(p.x, m.mundo.altura(p.x, p.z), p.z)
	return base

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
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	m.vagos.diretor._t_horda = 9999.0
	m.vagos.diretor._t_especial = 9999.0
	m.clima.hora = 12.0
	seed(5)
	await q(10)
	_limpar()
	var rua := _rua_aberta()
	m.mundo.forcar(Vector2(rua.x, rua.z))
	j.teleportar(rua + Vector3(0, 0.15, 0), 0.0)
	await q(30)
	print("  rua aberta em ", rua, " ao longo de ", _dir)

	# ---- 1. VASCULHAR ----
	var pv: Vector3 = rua + _dir * 8.0
	var v = m.vagos._criar(Vector3(pv.x, m.mundo.altura(pv.x, pv.z), pv.z), Vector3.INF)
	v.tipo_fixo = "rapido"
	await q(3)
	v._t_manada = 999.0
	# viu você indo para a frente da rua e você sumiu (foi para longe, fora da vista)
	var visto: Vector3 = rua + _dir * 16.0
	v._penultimo = rua + _dir * 12.0
	v._ultimo_visto = Vector3(visto.x, m.mundo.altura(visto.x, visto.z), visto.z)
	j.teleportar(rua - _dir * 70.0 + Vector3(0, 0.15, 0), 0.0)
	await q(3)
	v.perseguir()
	v._t_sem_ver = 999.0
	await q(10)
	ok(v.estado == V.INVESTIGANDO and v._vasculhar >= 2 and v._vasculhar <= 3,
		"perdeu você: vai onde te viu e ainda vai olhar %d lugares (%s)" % [v._vasculhar, V.NOMES[v.estado]])
	ok(Vector2(v._destino.x - visto.x, v._destino.z - visto.z).length() < 1.0, "primeiro vai até onde te viu")
	var destinos: Array = [v._destino]
	var t0 := Time.get_ticks_msec()
	Engine.time_scale = 4.0
	var marca_ok := true
	while Time.get_ticks_msec() - t0 < 30000 and v.estado == V.INVESTIGANDO:
		await q(5)
		v._t_manada = 999.0
		if v._destino.distance_to(destinos[-1]) > 1.0:
			destinos.append(v._destino)
		if v._marca != null and v._marca.visible and v._marca.text != "?":
			marca_ok = false
	Engine.time_scale = 1.0
	ok(destinos.size() >= 3, "olhou %d lugares antes de desistir (onde te viu + os a mais)" % destinos.size())
	var adiante := 0
	for i in range(1, destinos.size()):
		var d: Vector3 = destinos[i] - visto
		if Vector2(d.x, d.z).normalized().dot(Vector2(_dir.x, _dir.z)) > 0.0:
			adiante += 1
	ok(adiante >= 1, "procura para o lado em que você foi (%d de %d lugares adiante)" % [adiante, destinos.size() - 1])
	var longe := 0.0
	for d in destinos:
		longe = maxf(longe, Vector2((d as Vector3).x - visto.x, (d as Vector3).z - visto.z).length())
	ok(longe < 40.0, "fica por perto (o mais longe a %.0f m de onde te viu)" % longe)
	ok(v.estado == V.VAGANDO, "depois desiste e volta a vagar (%s)" % V.NOMES[v.estado])
	ok(marca_ok, "enquanto procura, o \"?\" fica na cabeça")
	# barulho comum (não perdeu ninguém): só vai ver e volta, sem vasculhar
	v.investigar(v.global_position + _dir * 3.0)
	ok(v._vasculhar == 0, "barulho comum: só vai ver o que foi (não vasculha)")
	_limpar()
	j.teleportar(rua + Vector3(0, 0.15, 0), 0.0)
	await q(10)

	# ---- 2. FILA DE BARULHOS ----
	var pb: Vector3 = rua + _dir * 10.0
	var v2 = m.vagos._criar(Vector3(pb.x, m.mundo.altura(pb.x, pb.z), pb.z) + _dir * 4.0, Vector3.INF)
	await q(3)
	v2.vagar()
	v2._espera = 99.0
	var ped0: int = m.vagos.barulhos_pedidos
	var fei0: int = m.vagos.barulhos_feitos
	for i in 6:
		m.vagos.barulho(pb + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 10.0 + i * 3.0, false)
	m.vagos.barulho(pb + Vector3(80, 0, 0), 5.0, false)
	ok(v2.estado == V.VAGANDO, "no mesmo quadro ninguém ouviu ainda (a fila solta no começo do próximo)")
	await q(2)
	ok(m.vagos.barulhos_pedidos - ped0 == 7 and m.vagos.barulhos_feitos - fei0 == 2,
		"7 barulhos pedidos viraram %d (6 juntos + 1 longe)" % (m.vagos.barulhos_feitos - fei0))
	ok(v2.estado == V.DESCONFIADO or v2.estado == V.INVESTIGANDO, "e o infectado ouviu o junto, com o raio do maior (%s)" % V.NOMES[v2.estado])
	_limpar()

	# ---- 3. ÁREA DE TOQUE ----
	var C = load("res://jogador/controles.gd")
	var r48: float = C.raio_toque_min(420.0, 1080.0, 720.0)
	ok(absf(r48 - 42.0) < 0.5, "celular de 420 dpi: área mínima de %.1f px de raio na tela do jogo (48 dp)" % r48)
	ok(C.raio_toque_min(0.0, 1080.0, 720.0) == 0.0, "sem saber o dpi, não muda nada")
	var c = j.controles
	c._raio_min = r48
	var mic: Dictionary = c._botao("MIC")
	var vozes: Dictionary = c._botao("VOZES")
	c.ocultos["MIC"] = false
	c.ocultos["VOZES"] = false
	var cm: Vector2 = c._centro(mic)
	var cv: Vector2 = c._centro(vozes)
	var desenho: float = float(mic["r"])
	ok(c.raio_toque(mic) >= r48 and c.raio_toque(mic) > desenho * 1.15, "o MIC (desenho de %.0f px) pega o dedo até %.0f px" % [desenho, c.raio_toque(mic)])
	var fora_do_desenho: Vector2 = cm + Vector2(0.0, desenho * 1.15 + 4.0)     # logo abaixo (do lado tem outro botão)
	ok(c._botao_no_toque(fora_do_desenho).get("id", "") == "MIC", "tocar logo fora do desenho ainda aperta o MIC")
	var entre: Vector2 = cm.lerp(cv, 0.6)
	ok(c._botao_no_toque(entre).get("id", "") == "VOZES", "entre MIC e VOZES vale o mais perto do dedo (VOZES)")
	ok(c._botao_no_toque(Vector2(5, 5)).is_empty(), "longe de tudo: nenhum botão")
	c.ocultos["MIC"] = true
	c.ocultos["VOZES"] = true
	c._raio_min = 0.0

	# ---- 4. ANISOTROPIA ----
	var AO = load("res://menu/aplicar_opcoes.gd")
	ok(AO.aniso_efetivo(16) == (2 if OS.has_feature("mobile") else 16) and AO.aniso_efetivo(1) == 1, "anisotropia: 16x no PC continua 16x (no celular, 2x)")

	# ---- 5. SINAIS DE ACERTO ----
	var sons = j.armas.sons
	ok(sons.sons.has("acerto") and sons.sons.has("acerto_forte"), "sons de acerto existem (comum e cabeça/abate)")
	ok(j.armas.VIBRA_ABATE > 0, "abate vibra %d ms (o celular)" % j.armas.VIBRA_ABATE)

	# ---- 6. ITEM NA MÃO mirando o arremesso ----
	var Item = load("res://inventario/item.gd")
	var it = Item.novo("tijolo", 1)
	var velho = j.inventario.slots.get("maos")
	if velho != null:
		j.inventario.retirar(velho)
	j.inventario.slots["maos"] = it
	it.slot = "maos"
	j.inventario._depois()
	await q(2)
	j._mirar_ligado = true
	await q(8)
	var mod = j.animador._modelo
	ok(mod != null and mod._item_mao != null and is_instance_valid(mod._item_mao) and mod._id_item == "tijolo", "mirando com o tijolo: ele aparece na mão")
	var no_antes = mod._item_mao if mod != null else null
	await q(8)
	ok(mod != null and mod._item_mao == no_antes, "e não é recriado a cada quadro")
	j._mirar_ligado = false
	await q(30)
	ok(mod != null and (mod._item_mao == null or not is_instance_valid(mod._item_mao)), "soltou o MIRAR: sai da mão")

	# ---- 7. (1.04) o "!" some quando o infectado morre ----
	var pm: Vector3 = j.global_position + Vector3(4, 0, 0)
	var vm = m.vagos._criar(Vector3(pm.x, m.mundo.altura(pm.x, pm.z), pm.z), Vector3.INF)
	await q(3)
	vm.perseguir()
	await q(5)
	var tinha: bool = vm._marca != null and vm._marca.visible and vm._marca.text == "!"
	vm._morrer(false, Vector3.FORWARD)
	await q(10)
	ok(tinha and not vm._marca.visible, "o \"!\" em cima do infectado some quando ele morre (antes ficava no corpo)")
	_limpar()

	# ---- 8. (1.04) 1ª pessoa olhando para baixo: a câmera vai à frente do peito ----
	root.get_node("Config").definir("cam", 1)
	await q(40)
	var frente_de := func() -> float:
		var d: Vector3 = j.camera.global_position - j.global_position
		return Vector2(d.x, d.z).dot(Vector2(-sin(j.cam_yaw), -cos(j.cam_yaw)))
	j.cam_pit = 0.0
	await q(20)
	var reto: float = frente_de.call()
	j.cam_pit = j._pit_max()
	await q(30)
	var baixo: float = frente_de.call()
	ok(baixo - reto > 0.25, "1ª pessoa olhando reto para baixo: a câmera vai %.2f m à frente (peito e pescoço ficam atrás dela)" % (baixo - reto))
	j.cam_pit = 0.0
	root.get_node("Config").definir("cam", 0)
	root.get_node("Config").salvar_pendente()
	await q(10)
	print("falhas: ", falhas)
	quit()
