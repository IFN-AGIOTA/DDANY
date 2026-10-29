extends SceneTree
# TESTE: DIRETOR DE IA (1.00, inimigos/diretor.gd). Com o jogo de verdade, numa rua aberta:
#   intensidade (mordida, infectado morrendo perto, não cai enquanto te caçam, cai depois) · fases crescendo -> pico ->
#   esfriando -> alívio -> crescendo (pelo tempo e por andar) · no alívio: menos infectados, nada novo perto, sem
#   evento ao longe e sem horda · horda: grupos atrás de você vêm na sua direção, viram infectados de verdade que vão
#   até você · o relógio da horda solta uma sozinha · abrigado (prédio) não vem horda · opção Ritmo desligada.
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
var D
var Cfg

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
		if bom and D.exposto(_boneco(Vector3(p.x, 0, p.z))):
			_dir_rua = dir
			return Vector3(p.x, m.mundo.altura(p.x, p.z), p.z)
	return base
var _dir_rua := Vector3(1, 0, 0)

var _bon: Node3D = null
func _boneco(p: Vector3) -> Node3D:
	if _bon == null:
		_bon = Node3D.new()
		root.add_child(_bon)
	_bon.global_position = p
	return _bon

func _intens() -> float:
	return float(D.intensidades.get(j.get_instance_id(), 0.0))

func _r():
	await q(20)
	m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	j = m.jogador
	Cfg = root.get_node("Config")
	Cfg.o["z_ritmo"] = 2
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	m.clima.hora = 12.0
	m.vagos._garantir_horda()
	D = m.vagos.diretor
	ok(D != null and D.get_parent() == m.vagos, "o Diretor nasce junto com a horda")
	D._t_horda = 9999.0
	await q(10)
	_limpar()
	var rua := _rua_aberta()
	_ir(rua)
	await q(30)
	print("  rua aberta em ", rua)

	# ---- 1. intensidade ----
	D.intensidades.clear()
	D.ferido(j, 12.0)
	ok(absf(_intens() - 0.3) < 0.01, "mordida de 12 de dano: intensidade 0,30 (%.2f)" % _intens())
	var antes := _intens()
	await seg(1.0)
	ok(absf(_intens() - antes) < 0.01, "logo depois da mordida ainda não cai (%.2f)" % _intens())
	await seg(3.5)
	ok(_intens() < antes - 0.05, "sem ninguém atacando, cai sozinha (%.2f -> %.2f)" % [antes, _intens()])
	# infectado caçando perto: não cai
	var V = load("res://inimigos/vago.gd")
	var pz: Vector3 = rua + _dir_rua * 12.0
	pz.y = m.mundo.altura(pz.x, pz.z)
	var cacador = m.vagos._criar(pz, Vector3.INF)
	cacador._alertar(j)
	await q(5)
	D.intensidades[j.get_instance_id()] = 0.5
	await seg(4.0)
	ok(cacador.esta_cacando() and _intens() >= 0.5, "com infectado te caçando a menos de 25 m, a intensidade não cai (%.2f)" % _intens())
	_limpar()
	await q(3)
	# infectado morrendo perto
	D.intensidades[j.get_instance_id()] = 0.0
	var p3: Vector3 = rua + _dir_rua * 3.0
	p3.y = m.mundo.altura(p3.x, p3.z)
	var morre = m.vagos._criar(p3, Vector3.INF)
	await q(3)
	morre.receber_tiro(9999.0, morre.global_position, Vector3(1, 0, 0), 1, j)
	await q(2)
	ok(_intens() > 0.06 and _intens() < 0.13, "infectado morto a 3 m: intensidade sobe um pouco (%.2f)" % _intens())
	_limpar()

	# ---- 2. fases ----
	D.fase = D.CRESCENDO
	D.ferido(j, 40.0)
	await q(3)
	ok(D.fase == D.PICO, "passou de 0,85: PICO (%s · %s)" % [D.nome_fase(), D.motivo])
	await seg(5.5)
	ok(D.fase == D.ESFRIANDO, "3-5 s depois do pico: ESFRIANDO (%s)" % D.nome_fase())
	ok(D.teto_reais(22) == 14 and D.dist_min_nascer() >= 60.0 and not D.pode_evento(), "esfriando: no máximo 14 de 22, nada novo a menos de 60 m, sem evento ao longe")
	D.intensidades[j.get_instance_id()] = 0.3
	await q(3)
	ok(D.fase == D.ALIVIO, "intensidade abaixo de 0,35 e ninguém caçando: ALÍVIO (%s)" % D.motivo)
	ok(D._t_fase >= 29.0 and D._t_fase <= 45.0, "o alívio dura 30-45 s (%.1f)" % D._t_fase)
	# no alívio, o relógio da horda não anda
	D._t_horda = 0.2
	var h0: int = D.hordas
	await seg(1.0)
	ok(D.hordas == h0 and D._t_horda > 0.1, "no alívio não vem horda")
	# grupo virtual a 40 m não vira infectado de verdade no alívio (a 75 m sim)
	m.vagos.max_ativos = 22
	var hd = m.vagos.horda
	var guarda: Array = hd.grupos.duplicate()
	hd.grupos.clear()
	var g40: Vector3 = rua - _dir_rua * 40.0
	hd.grupos.append({"p": Vector2(g40.x, g40.z), "n": 3, "d": Vector2.INF, "v": 0.4, "t": 0.0})
	await seg(1.0)
	var da_horda: int = m.vagos.vivos.filter(func(v): return is_instance_valid(v) and v.da_horda).size()
	ok(da_horda == 0 and hd.total_virtuais() == 3, "alívio: grupo a 40 m continua virtual (%d de verdade)" % da_horda)
	# andou 150 m: o alívio acaba antes
	m.vagos.max_ativos = 0
	hd.grupos = guarda
	var longe := rua
	for k in 60:
		var a := k * 0.4
		var tl := rua + Vector3(cos(a), 0, sin(a)) * 170.0
		if m.vagos._livre(tl.x, tl.z):
			longe = Vector3(tl.x, m.mundo.altura(tl.x, tl.z), tl.z)
			break
	_ir(longe)
	await q(10)
	ok(D.fase == D.CRESCENDO and D.motivo.begins_with("andou"), "andou 170 m no alívio: volta ao CRESCENDO (%s)" % D.motivo)
	_ir(rua)
	await q(30)
	_limpar()

	# ---- 3. horda do Diretor ----
	D._t_horda = 9999.0
	D._parar_horda()
	D.fase = D.CRESCENDO
	D.intensidades.clear()
	j.cam_yaw = 0.0                                 # olhando para -Z: "atrás" é +Z
	await q(2)
	var antes_h: int = D.hordas
	var tam: int = D.tamanho_horda()
	var foi: bool = D.soltar_horda(j, 1)
	var marcados := 0
	var atras := 0
	for g in hd.grupos:
		if g.has("diretor"):
			marcados += int(g["n"])
			if float((g["p"] as Vector2).y) > rua.z:
				atras += int(g["n"])
	ok(foi and D.hordas == antes_h + 1 and D.horda_ativa(), "a horda saiu (%d infectados marcados, tamanho %d)" % [marcados, tam])
	ok(marcados >= tam and atras == marcados, "todos vêm de trás de você (%d de %d)" % [atras, marcados])
	var d_ok := true
	for g in hd.grupos:
		if g.has("diretor"):
			var dd: Vector2 = g["d"]
			if dd == Vector2.INF or dd.distance_to(Vector2(rua.x, rua.z)) > 8.0:
				d_ok = false
	ok(d_ok, "os grupos da horda vão até onde você está (erro de até 5 m)")
	# um grupo da horda chega a 80 m: vira infectados de verdade que vêm até você
	m.vagos.max_ativos = 22
	var um: Dictionary = {}
	for g in hd.grupos:
		if g.has("diretor"):
			um = g
			break
	var p80: Vector3 = rua + Vector3(0, 0, 80.0)
	for k in 30:
		var t := rua + Vector3(sin(k * 0.21) * 30.0, 0, 80.0)
		if m.vagos._livre(t.x, t.z):
			p80 = t
			break
	um["p"] = Vector2(p80.x, p80.z)
	await seg(2.0)
	var vindo := 0
	for v in D.membros:
		if is_instance_valid(v) and (v.estado == V.INVESTIGANDO or v.esta_cacando()) and Vector2(v._destino.x - rua.x, v._destino.z - rua.z).length() < 12.0:
			vindo += 1
	ok(D.membros.size() > 0 and vindo == D.membros.size(), "viraram infectados de verdade indo até você (%d de %d)" % [vindo, D.membros.size()])
	D._parar_horda()
	ok(not D.horda_ativa() and D.membros.is_empty(), "a horda para de te seguir depois de um tempo")
	m.vagos.max_ativos = 0
	_limpar()

	# ---- 4. o relógio solta a horda sozinho (na rua) e não solta abrigado ----
	var pr: PackedFloat32Array = m.mundo._pred
	var predio := Vector3(pr[0], 0.0, pr[1])
	ok(not D.exposto(_boneco(predio)), "dentro de prédio você está abrigado (sem horda)")
	m.mundo.abertos[0] = true
	ok(not D.exposto(_boneco(predio)), "dentro de prédio ABERTO (interior) também")
	m.mundo.abertos.erase(0)
	ok(D.exposto(j), "na rua você está exposto")
	D._parar_horda()
	D.fase = D.CRESCENDO
	D._t_horda = 0.3
	var h1: int = D.hordas
	await seg(1.0)
	ok(D.hordas == h1 + 1, "o relógio da horda soltou uma sozinho")
	var iv: Vector2 = D.intervalo_horda()
	ok(D._t_horda >= iv.x - 1.0 and D._t_horda <= iv.y, "a próxima vem em %d s (entre %d e %d)" % [int(D._t_horda), int(iv.x), int(iv.y)])
	D._parar_horda()

	# ---- 5. opção Ritmo: Sem Diretor ----
	Cfg.o["z_ritmo"] = 0
	D.fase = D.ALIVIO
	await q(3)
	D.ferido(j, 50.0)
	await q(3)
	ok(D.fase == D.CRESCENDO and D.intensidade() == 0.0 and D.teto_reais(22) == 22, "Ritmo: Sem Diretor = sem fases nem intensidade")
	Cfg.o["z_ritmo"] = 2
	print("  ", D.estado_texto())

	# ---- 6. orçamento em milissegundos (inimigos/vagos.gd) ----
	D._t_horda = 9999.0
	D.fase = D.CRESCENDO
	_limpar()
	m.vagos.max_ativos = 22
	m.vagos.teto_custo = -1
	var hd2 = m.vagos.horda
	hd2.grupos.clear()
	j.cam_yaw = 0.0                                  # olhando para -Z: os de +Z ficam fora da tela
	await q(3)
	for k in 14:
		var pt := rua + Vector3(randf_range(-30.0, 30.0), 0, randf_range(55.0, 90.0))
		if m.vagos._livre(pt.x, pt.z):
			var vv = m.vagos._criar(Vector3(pt.x, m.mundo.altura(pt.x, pt.z), pt.z), Vector3.INF, true)
			vv.vagar()
	await q(10)
	var reais0: int = m.vagos.vivos.size()
	print("  custo dos infectados: %.2f ms por quadro (%d de verdade)" % [m.vagos.custo_ms, reais0])
	ok(m.vagos.custo_ms > 0.0, "o custo dos infectados é medido")
	var orc0: float = m.vagos.orcamento_ms
	m.vagos.orcamento_ms = 0.0001                    # orçamento estourado
	await seg(3.5)
	ok(m.vagos.teto_custo >= m.vagos.MIN_REAIS and m.vagos.teto_custo < 22, "passou do orçamento: cabem menos de verdade (%d)" % m.vagos.teto_custo)
	ok(m.vagos.vivos.size() < reais0 and hd2.total_virtuais() > 0, "os menos importantes (longe, fora da tela) voltaram a ser grupo (%d -> %d)" % [reais0, m.vagos.vivos.size()])
	ok(m.vagos.vagas_reais() <= 0, "e não nasce mais ninguém enquanto isso")
	var teto1: int = m.vagos.teto_custo
	m.vagos.orcamento_ms = 1000.0                    # folga
	await seg(3.5)
	ok(m.vagos.teto_custo == -1 or m.vagos.teto_custo >= teto1 + 2, "com folga, o limite volta a subir (%d -> %d)" % [teto1, m.vagos.teto_custo])
	m.vagos.orcamento_ms = orc0

	# ---- 7. a horda de longe aparece como silhuetas (inimigos/horda_longe.gd) ----
	_limpar()
	m.vagos.max_ativos = 0
	var hl = m.vagos.horda_longe
	ok(hl != null, "o jogo tem as silhuetas da horda de longe")
	var hd3 = m.vagos.horda
	hd3.grupos.clear()
	j.cam_yaw = atan2(-_dir_rua.x, -_dir_rua.z)
	j.cam_pit = -0.05
	var g150 := rua + _dir_rua * 150.0
	var g60 := rua + _dir_rua * 60.0
	var g400 := rua + _dir_rua * 400.0
	hd3.grupos.append({"p": Vector2(g150.x, g150.z), "n": 8, "d": Vector2(rua.x, rua.z), "v": 0.4, "t": 0.0})
	hd3.grupos.append({"p": Vector2(g60.x, g60.z), "n": 5, "d": Vector2.INF, "v": 0.4, "t": 0.0})
	hd3.grupos.append({"p": Vector2(g400.x, g400.z), "n": 6, "d": Vector2.INF, "v": 0.4, "t": 0.0})
	hl.atualizar()
	var perto150 := 0
	for i in hl.mm.visible_instance_count:
		var t: Transform3D = hl.mm.get_instance_transform(i)
		if Vector2(t.origin.x - g150.x, t.origin.z - g150.z).length() < 6.0:
			perto150 += 1
	ok(hl.mostrados == 8 and perto150 == 8, "o grupo a 150 m aparece (8 silhuetas); o de 60 m (vira de verdade) e o de 400 m não (%d)" % hl.mostrados)
	ok(hl.mm.get_instance_custom_data(0).r > 0.5, "o grupo andando anima o andar")
	if OS.get_environment("FOTO") != "":
		for g in hd3.grupos:
			g["d"] = Vector2.INF
		hd3.grupos[0]["p"] = Vector2(rua.x, rua.z) + Vector2(_dir_rua.x, _dir_rua.z) * 110.0
		hd3.grupos[0]["n"] = 14
		hl.atualizar()
		await q(20)
		root.get_texture().get_image().save_png(OS.get_environment("FOTO") + "_horda_longe.png")
	hd3.grupos.clear()
	hl.atualizar()
	ok(hl.mostrados == 0 and hl.mm.visible_instance_count == 0, "sem grupos longe, nenhuma silhueta")

	print("falhas: ", falhas)
	quit()
