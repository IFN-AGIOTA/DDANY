extends SceneTree
# TESTE: 1.00 · MUTADOS (lore, Bíblia 2.7; inimigos/vago.gd classe "mutado", inimigos/diretor.gd soltar_mutado).
# Numa rua aberta: visual próprio (pele rachada, veios) · aguenta mais · corre como você · SALTA de longe · faz o
# estalo de dentes · fareja SANGUE de longe · o Diretor solta um onde você não vê, já vindo atrás de você · no
# máximo 1 com "Raros" · a opção "Não" desliga · a cópia da rede também vira mutado.
# 1.00 · DORMINDO (vago.gd DORMINDO, mundo/interiores.gd): não vê; passando perto devagar só geme (aviso); tiro
# perto acorda; colado acorda e vem; prédios infestados às vezes têm um grupo dormindo.
# FOTO=/caminho/base grava a foto do mutado ao lado de um infectado comum.
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
		for k in range(-12, 13):
			var x := p + dir * (k * 3.5)
			if not m.vagos._livre(x.x, x.z) or m.mundo.dentro_de_obstaculo(x.x, x.z, 1.5):
				bom = false
				break
		if bom:
			_dir = dir
			return Vector3(p.x, m.mundo.altura(p.x, p.z), p.z)
	return base
var _dir := Vector3(1, 0, 0)

func _mutado(p: Vector3, olhando: Vector3):
	var v = m.vagos._criar(Vector3(p.x, m.mundo.altura(p.x, p.z), p.z), Vector3.INF, false, "mutado")
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
	V = load("res://inimigos/vago.gd")
	Cfg = root.get_node("Config")
	var R = load("res://inimigos/regras_infectados.gd")
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	m.vagos._garantir_horda()
	var D = m.vagos.diretor
	D._t_horda = 9999.0
	D._t_especial = 9999.0
	m.clima.hora = 12.0
	await q(10)
	_limpar()
	var rua := _rua_aberta()
	_ir(rua)
	await q(30)
	j.cam_yaw = atan2(-_dir.x, -_dir.z)
	await q(3)
	print("  rua aberta em ", rua)

	# ---- 1. visual e força ----
	var p8 := rua + _dir * 8.0
	var mu = _mutado(p8, rua)
	var comum = m.vagos._criar(Vector3(p8.x, rua.y, p8.z) + _dir.cross(Vector3.UP) * 1.6, Vector3.INF)
	comum.vagar()
	comum._espera = 99.0
	comum.rotation.y = mu.rotation.y
	await q(10)
	var mi: MeshInstance3D = mu.modelo.corpo.find_children("*", "MeshInstance3D", true, false)[0]
	ok(mu.classe == "mutado" and mu.modelo.mutado and mi.material_override == mu.modelo.material_mutado(), "o mutado tem pele própria (rachada, veios escuros)")
	ok((mi.mesh as Mesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV != 0, "a pele usa a posição de descanso (não escorre com a animação)")
	ok(mu.vida >= 200.0 and mu.vida > comum.vida * 2.0, "aguenta bem mais que o comum (%.0f x %.0f)" % [mu.vida, comum.vida])
	if OS.get_environment("FOTO") != "":
		j.cam_pit = -0.05
		await q(20)
		root.get_texture().get_image().save_png(OS.get_environment("FOTO") + "_mutado.png")
	_limpar()

	# ---- 2. corre como você, salta e estala os dentes ----
	var p30 := rua + _dir * 30.0
	var m2 = _mutado(p30, rua)
	await q(3)
	m2._alertar(j)
	await seg(1.0)
	var a: Vector3 = m2.global_position
	await seg(0.6)
	var b: Vector3 = m2.global_position
	var vel := Vector2(b.x - a.x, b.z - a.z).length() / 0.6
	ok(vel > 6.2, "caçando, corre como você no sprint (%.1f m/s)" % vel)
	var saltou := false
	var alto := 0.0
	var estalou := false
	for k in 240:
		await physics_frame
		if m2._investida > 0.0:
			saltou = true
		alto = maxf(alto, m2.modelo.position.y)
		if m2._som_estalo != null and m2._som_estalo.playing:
			estalou = true
		if saltou and estalou and alto > 0.3:
			break
	ok(saltou and alto > 0.3, "salta em cima de você de longe (arco de %.2f m)" % alto)
	ok(estalou, "faz o estalo de dentes vindo atrás de você")
	_limpar()

	# ---- 3. fareja sangue de longe ----
	j.sobrevivencia.sangramentos = 1
	var p30b := rua + _dir * 30.0
	var m3 = _mutado(p30b, p30b + _dir * 10.0)          # de costas: não te vê
	var c3 = m.vagos._criar(Vector3(p30b.x, rua.y, p30b.z) + _dir.cross(Vector3.UP) * 2.0, Vector3.INF)
	c3.rotation.y = m3.rotation.y
	c3.vagar()
	c3._espera = 99.0
	await seg(1.5)
	ok(m3.estado == V.INVESTIGANDO or m3.esta_cacando(), "você sangrando: o mutado a 30 m fareja e vem (%s)" % V.NOMES[m3.estado])
	ok(c3.estado == V.VAGANDO, "o infectado comum ao lado não sente nada (%s)" % V.NOMES[c3.estado])
	j.sobrevivencia.sangramentos = 0
	_limpar()

	# ---- 4. o Diretor solta um onde você não vê ----
	Cfg.o["z_mutados"] = 1
	D.fase = D.CRESCENDO
	var m4 = D.soltar_mutado(j)
	await q(3)
	ok(m4 != null and m4.classe == "mutado", "o Diretor soltou um mutado")
	if m4 != null:
		var d4: float = Vector2(m4.global_position.x - rua.x, m4.global_position.z - rua.z).length()
		ok(d4 >= 40.0 and d4 <= 90.0 and not m.vagos._visivel(m4.global_position), "a %.0f m, fora da sua vista" % d4)
		ok(m4.estado == V.INVESTIGANDO and Vector2(m4._destino.x - rua.x, m4._destino.z - rua.z).length() < 8.0, "e já vem farejando você")
	D._t_especial = 0.1
	var n0: int = D.mutados_soltos
	await seg(1.0)
	ok(D.mutados_soltos == n0 and m.vagos.mutados_vivos() == 1, "com \"Raros\", no máximo 1 vivo")
	_limpar()
	Cfg.o["z_mutados"] = 0
	D._t_especial = 0.1
	await seg(1.0)
	ok(D.mutados_soltos == n0 and m.vagos.mutados_vivos() == 0, "Mutados: Não = nenhum")
	Cfg.o["z_mutados"] = 1

	# ---- 5. rede: a cópia do cliente também vira mutado ----
	ok(m.vagos.TIPOS_REDE.find("mutado") >= 0, "o tipo \"mutado\" vai pela rede")
	var copia = V.new()
	copia.gerente = m.vagos
	copia.remoto = true
	copia.tipo_fixo = "mutado"
	copia.position = rua + _dir * 12.0
	m.vagos.add_child(copia)
	await q(3)
	ok(copia.modelo.mutado, "a cópia (cliente) tem o visual do mutado")
	copia.ani_rede("salto", {})
	var alto_c := 0.0
	for k in 40:
		await process_frame
		alto_c = maxf(alto_c, copia.modelo.position.y)
	ok(alto_c > 0.3, "e salta junto quando o host avisa (%.2f m)" % alto_c)
	copia.queue_free()
	await q(3)

	# ---- 6. dormindo ----
	_ir(rua)
	await q(5)
	var p8d := rua + _dir * 8.0
	var dm = m.vagos._criar(Vector3(p8d.x, rua.y, p8d.z), Vector3.INF)
	dm.rotation.y = atan2(_dir.x, _dir.z)               # de frente para você
	await q(2)
	dm.dormir()
	await seg(1.5)
	ok(dm.estado == V.DORMINDO and dm._marca != null and dm._marca.visible and dm._marca.text == "zz", "dormindo em pé (marcador zz)")
	ok(dm.estado == V.DORMINDO, "de frente a 8 m, de dia: não te vê")
	m.vagos.barulho(rua, m.vagos.raio_passos(7.0, false), true)      # correndo a 8 m (longe)
	await q(3)
	ok(dm.estado == V.DORMINDO, "passos correndo a 8 m: continua dormindo")
	var p4 := rua + _dir * 4.0
	_ir(Vector3(p4.x, rua.y, p4.z))
	await seg(0.6)
	ok(dm.estado == V.DORMINDO and dm._t_aviso > 0.0, "você parado a 4 m: ele geme e se mexe (aviso), mas não acorda")
	_ir(rua)
	await q(5)
	m.vagos.barulho(rua + _dir * 2.0, 75.0 * 1.4, true)               # tiro perto
	await q(3)
	ok(dm.estado == V.INVESTIGANDO or dm.esta_cacando(), "tiro perto: acorda bravo (você a 8 m: vem atrás de você) (%s)" % V.NOMES[dm.estado])
	dm.queue_free()
	m.vagos.vivos.erase(dm)
	var dm2 = m.vagos._criar(Vector3(p8d.x, rua.y, p8d.z), Vector3.INF)
	await q(2)
	dm2.dormir()
	await q(3)
	var p1 := rua + _dir * 6.5
	_ir(Vector3(p1.x, rua.y, p1.z))
	await seg(0.8)
	ok(dm2.esta_cacando(), "colado nele: acorda bravo e vem (%s)" % V.NOMES[dm2.estado])
	_limpar()
	_ir(rua)
	await q(5)
	# prédios infestados: às vezes um grupo dormindo
	var it = m.interiores
	it.ativo = false
	it.fechar_todos()
	it._infestados.clear()
	var c = m.cidade
	var abertos := 0
	var dentro := 0
	var dormindo := 0
	for i in c.predio_info.size():
		var inf: Dictionary = c.predio_info[i]
		if not inf["entra"] or inf["ruina"] or Vector2(inf["x"] - 436.0, inf["z"] - 1500.0).length() > 600.0:   # (o centro: cheio de prédios)
			continue
		it.abrir(i, true)
		abertos += 1
		for v in m.vagos.vivos:
			if is_instance_valid(v):
				dentro += 1
				if v.estado == V.DORMINDO:
					dormindo += 1
		_limpar()                                  # (infectado por perto não deixa o vizinho ser infestado)
		it.fechar(i)
		if abertos >= 40:
			break
	print("  %d prédios abertos: %d infectados dentro, %d dormindo" % [abertos, dentro, dormindo])
	ok(dormindo >= 2, "prédios infestados têm grupos dormindo (%d)" % dormindo)
	print("falhas: ", falhas)
	quit()
