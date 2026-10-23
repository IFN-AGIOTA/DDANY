extends SceneTree
# TESTE: INFECTADOS x PAREDES DOS PRÉDIOS (0.80)
#   1-2. indo para o outro lado de um prédio (perto, com física; longe, sem física): nunca fica dentro dele
#   3.   preso dentro de um prédio, com o jogador longe: não sai atravessando a parede
#   4.   PERCEPÇÃO: atrás da parede não vê (mesmo perto e de frente); no aberto vê; passos atrás da parede = ouve
#        e vai ver o lugar (não sabe onde você está)
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
var inf

func _limpar() -> void:
	for v in m.vagos.vivos.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	m.vagos.vivos.clear()

func _criar(p: Vector3):
	_limpar()
	await q(2)
	m.vagos._criar(p + Vector3(0, 0.05, 0), Vector3.INF)
	var v = m.vagos.vivos.back()
	v.tipo = "comum"
	return v

# anda até "alvo" (indo ver um barulho); devolve quantos quadros ficou dentro da planta do prédio idx
func _andar(alvo: Vector3, quadros: int, idx: int, deve_ficar_dentro := false) -> Array:
	var cid = m.cidade
	var inf_p: Dictionary = cid.predio_info[idx]
	var dentro := 0
	var fora := 0
	var fisica := 0
	for k in quadros:
		await physics_frame
		j.sobrevivencia.vida = 100.0
		if k % 20 == 0:
			inf.investigar(alvo)
		var p: Vector3 = inf.global_position
		var dx := absf(p.x - float(inf_p["x"])) - float(inf_p["sx"]) * 0.5
		var dz := absf(p.z - float(inf_p["z"])) - float(inf_p["sz"]) * 0.5
		if dx < -0.25 and dz < -0.25:
			dentro += 1
		else:
			fora += 1
		if inf._fisica:
			fisica += 1
	return [dentro, fora, fisica]

func _r():
	await q(20)
	m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.clima.definir_hora(13.0)
	m.clima.set("parado", true)
	m.vagos.ativo = true
	m.vagos.max_ativos = 0
	j = m.jogador
	var cid = m.cidade
	# um prédio grande, comum (sem interior), longe dos locais e com rua dos dois lados (x)
	var idx := -1
	var perto := Vector2(436.5, 1500.0)
	var md := INF
	for i in cid.predio_info.size():
		var e: Dictionary = cid.predio_info[i]
		if float(e["sx"]) < 24.0 or float(e["sz"]) < 20.0 or bool(e["entra"]) or bool(e.get("ruina", false)):
			continue
		var c := Vector2(float(e["x"]), float(e["z"]))
		var lado_a := c + Vector2(float(e["sx"]) * 0.5 + 4.0, 0)
		var lado_b := c - Vector2(float(e["sx"]) * 0.5 + 4.0, 0)
		if m.mundo.dentro_de_predio(lado_a.x, lado_a.y, 1.0, true) or m.mundo.dentro_de_predio(lado_b.x, lado_b.y, 1.0, true):
			continue
		var d := c.distance_to(perto)
		if d < md:
			md = d
			idx = i
	var e: Dictionary = cid.predio_info[idx]
	var c := Vector3(float(e["x"]), 0, float(e["z"]))
	var meia := float(e["sx"]) * 0.5
	print("prédio %d em %s (%.0f x %.0f)" % [idx, str(c), float(e["sx"]), float(e["sz"])])
	var y := func(p: Vector3) -> Vector3: return Vector3(p.x, m.mundo.altura(p.x, p.z), p.z)
	# 1. perto (com física): jogador de um lado, infectado do outro, indo para onde o jogador está
	m.mundo.forcar(Vector2(c.x, c.z))
	j.teleportar(y.call(c + Vector3(meia + 3.0, 0, 0)) + Vector3(0, 0.1, 0), 0.0)
	await q(30)
	inf = await _criar(y.call(c - Vector3(meia + 3.0, 0, 0)))
	var r1: Array = await _andar(j.global_position, 600, idx)
	print("  1. perto: dentro do prédio %d quadros · com física %d" % [r1[0], r1[2]])
	ok(r1[0] == 0, "1. indo para o outro lado do prédio (perto): não atravessou")
	# 2. longe (sem física): jogador 70 m longe do prédio
	j.teleportar(y.call(c + Vector3(meia + 70.0, 0, 0)) + Vector3(0, 0.1, 0), 0.0)
	await q(30)
	inf = await _criar(y.call(c - Vector3(meia + 3.0, 0, 0)))
	var r2: Array = await _andar(y.call(c + Vector3(meia + 3.0, 0, 0)), 900, idx)
	print("  2. longe: dentro do prédio %d quadros · com física %d" % [r2[0], r2[2]])
	ok(r2[0] == 0, "2. indo para o outro lado do prédio (longe, sem física): não atravessou")
	# 3. preso dentro do prédio, jogador longe, querendo ir para fora
	inf = await _criar(y.call(c))
	var r3: Array = await _andar(y.call(c + Vector3(meia + 10.0, 0, 0)), 600, idx)
	print("  3. preso: dentro %d · fora %d" % [r3[0], r3[1]])
	ok(r3[1] == 0, "3. preso dentro do prédio: não saiu pela parede")
	# 4. percepção (jogador perto, parado de pé)
	var pa: Vector3 = y.call(c + Vector3(meia + 1.2, 0, 0))            # colado na parede, do lado de fora
	j.teleportar(pa + Vector3(0, 0.1, 0), 0.0)
	await q(20)
	inf = await _criar(y.call(c + Vector3(meia - 2.0, 0, 0)))       # dentro (do outro lado da parede), 3 m
	inf.rotation.y = atan2(-1.0, 0.0)                               # olhando para o jogador (+X)
	inf.vagar()
	var viu := false
	for k in 180:
		await physics_frame
		j.sobrevivencia.vida = 100.0
		if inf.esta_cacando():
			viu = true
	ok(not viu, "4a. jogador a 3 m, atrás da parede, de frente: NÃO percebe")
	inf = await _criar(y.call(c + Vector3(meia + 9.0, 0, 0)))       # mesmo lado, no aberto, a ~8 m
	inf.rotation.y = atan2(1.0, 0.0)                                # olhando para o jogador (-X)
	inf.vagar()
	viu = false
	for k in 180:
		await physics_frame
		j.sobrevivencia.vida = 100.0
		if inf.esta_cacando():
			viu = true
			break
	ok(viu, "4b. no aberto, de frente a 8 m: vê e persegue")
	# passos atrás da parede: ouve (vai ver o lugar), não persegue
	inf = await _criar(y.call(c + Vector3(meia - 2.0, 0, 0)))
	inf.vagar()
	m.vagos.barulho(pa, m.vagos.RUIDO_CORRENDO, true)
	await q(3)
	ok(inf.estado in [inf.DESCONFIADO, inf.INVESTIGANDO] and not inf.esta_cacando(), "4c. ouviu passos atrás da parede: vai ver (estado %d), não persegue" % inf.estado)
	# 4d. já perseguindo, colado do outro lado da parede: não morde através dela
	inf = await _criar(y.call(c + Vector3(meia - 0.5, 0, 0)))       # 1,7 m do jogador, parede no meio
	inf.perseguir()
	inf._t_sem_ver = 3.0
	j.sobrevivencia.vida = 100.0
	var vida0: float = j.sobrevivencia.vida
	for k in 240:
		await physics_frame
	ok(j.sobrevivencia.vida >= vida0 - 0.01, "4d. colado na parede, perseguindo: não morde através dela (vida %.0f)" % j.sobrevivencia.vida)
	_limpar()
	print("falhas: ", falhas)
	quit()
