extends SceneTree
# TESTE: JANELAS DE VERDADE + EMPURRÃO/PISÃO (0.90). Num prédio aberto: acha uma janela do térreo com vidro,
# quebra (vidro some, a colisão sai), pula para o outro lado, barrica com tábua (volta a fechar) e um infectado
# quebra a tábua batendo e depois PULA a janela para dentro (cai e levanta). Empurrão: o infectado da frente
# cambaleia/cai; com ele no chão, o botão vira PISÃO (tira vida). E a horda vai no jogo salvo.
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

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	var PortaCls = load("res://mundo/porta.gd")
	var cid = m.cidade
	var I = load("res://mundo/interior.gd")
	# um prédio com janela de vidro no térreo
	var jan = null
	for i in cid.predio_info.size():
		var e: Dictionary = cid.predio_info[i]
		if not bool(e["entra"]) or Vector2(e["x"], e["z"]).distance_to(Vector2(6230, 590)) > 1500:
			continue
		var c := Vector2(e["x"], e["z"])
		m.mundo.forcar(c)
		j.teleportar(Vector3(c.x + float(e["sx"]) * 0.5 + 5.0, m.mundo.altura(c.x, c.y) + 0.2, c.y), 0.0)
		m.interiores.abrir_agora(c)
		await q(8)
		for k in PortaCls.todas:
			var pt = PortaCls.todas[k]
			if is_instance_valid(pt) and pt.get("janela") == true and pt.vidro and pt.tabuas == 0 and str(k).begins_with("j%d:" % i):
				jan = pt
				break
		if jan != null:
			break
		m.interiores.fechar(i)
	ok(jan != null, "achou uma janela de vidro no térreo de um prédio aberto")
	if jan == null:
		print("falhas: ", falhas)
		quit()
		return
	var fora: Vector3 = jan.global_transform * Vector3(0, 0.1, 0.9)
	j.teleportar(fora, 0.0)
	await q(5)
	ok(jan.fechada() and jan._corpo.collision_layer == 1, "com vidro: fechada (colisão no vão)")
	ok(jan.acao(j.inventario) == "QUEBRAR\nJANELA", "o botão diz QUEBRAR JANELA")
	jan.usar(j.inventario)
	await q(2)
	ok(not jan.vidro and jan._corpo.collision_layer == 0, "quebrou: sem vidro e sem colisão")
	ok(m.loot_mundo.portas.has(jan.id) and m.loot_mundo.portas[jan.id][0] == false, "o estado da janela ficou guardado (jogo salvo/rede)")
	ok(jan.acao(j.inventario) == "PULAR\nJANELA", "agora o botão diz PULAR JANELA")
	var lado0: float = (jan.global_transform.affine_inverse() * j.global_position).z
	jan.usar(j.inventario)
	await q(70)
	var lado1: float = (jan.global_transform.affine_inverse() * j.global_position).z
	ok(lado0 > 0.0 and lado1 < 0.0, "pulou para o outro lado (de %.2f para %.2f)" % [lado0, lado1])
	# barricar por dentro
	var msg: String = jan.barricar(j.global_position)
	ok(msg.contains(" BARRICADA (") and jan.fechada() and jan._corpo.collision_layer == 1, "barricou com tábua: fecha de novo (%s)" % msg)
	# infectado lá fora quebra a tábua e pula para dentro
	var v = m.vagos._criar(fora + Vector3(0, 0.05, 0), Vector3.INF)
	await q(3)
	v._trocar_modo(true)
	var dentro: Vector3 = jan.global_transform * Vector3(0, 0, -2.0)
	var quer: Vector3 = (dentro - v.global_position)
	quer.y = 0.0
	for k in 40:
		if not jan.fechada():
			break
		v.global_position = fora + Vector3(0, 0.05, 0)
		v._porta_no_caminho(v.global_position, quer)
		await q(2)
	ok(not jan.fechada(), "o infectado quebrou a tábua batendo")
	v.global_position = jan.global_transform * Vector3(0, 0.05, 0.8)
	var pulou: bool = v._porta_no_caminho(v.global_position, quer)
	ok(pulou and v._pulando > 0.0, "janela aberta: o infectado pula para dentro")
	await q(60)
	var lado_v: float = (jan.global_transform.affine_inverse() * v.global_position).z
	ok(lado_v < 0.0, "ele caiu do lado de dentro (z local %.2f, estado %s)" % [lado_v, v.NOMES[v.estado]])
	for x in m.vagos.vivos.duplicate():
		x.queue_free()
	m.vagos.vivos.clear()
	await q(3)
	# empurrão e pisão (num lugar aberto)
	var p0: Vector3 = j.global_position
	j.teleportar(fora + jan.global_transform.basis.z * 6.0, 0.0)
	await q(10)
	j.cam_yaw = 0.0
	var frente := Vector3(-sin(j.cam_yaw), 0, -cos(j.cam_yaw))
	var caiu := false
	for t in 8:
		var z = m.vagos._criar(j.global_position + frente * 1.0, Vector3.INF)
		z.rotation.y = j.cam_yaw + PI
		await q(3)
		j.sobrevivencia.estamina = 100.0
		j._t_empurrao = 0.0
		j.empurrar()
		await q(2)
		if z.estado == z.CAIDO:
			caiu = true
		if caiu:
			var vida0: float = z.vida
			j._t_empurrao = 0.0
			j.sobrevivencia.estamina = 100.0
			z.global_position = j.global_position + frente * 0.9
			await q(2)
			j.empurrar()
			await q(2)
			ok(z.vida < vida0 or z.estado == z.MORTO, "com ele no chão, o botão vira PISÃO (vida %.0f -> %.0f)" % [vida0, z.vida])
			break
		z.queue_free()
		m.vagos.vivos.erase(z)
	ok(caiu, "empurrão derruba o infectado (em até 8 tentativas)")
	j.sobrevivencia.estamina = 3.0
	j._t_empurrao = 0.0
	j.empurrar()
	ok(j.sobrevivencia.estamina == 3.0, "sem fôlego não empurra")
	# a horda vai no jogo salvo (conserto da 0.90)
	m.vagos._garantir_horda()
	await q(5)
	var Salv = load("res://menu/salvamento.gd")
	Salv.salvar(m)
	var d = JSON.parse_string(FileAccess.get_file_as_string(Salv.ARQUIVO))
	ok(d is Dictionary and d.has("vagos") and (d["vagos"] as Dictionary).has("horda"), "o jogo salvo leva a horda da cidade")
	print("falhas: ", falhas)
	quit()
