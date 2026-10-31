extends SceneTree
# TESTE: NÃO CAIR NO VOID (0.99.3).
#   1. chegada segura: teleportado para um lugar cujo chão só aparece depois (como o piso de um prédio por dentro), o
#      jogador fica parado no ar esperando e, quando o chão aparece, fica em pé nele;
#   2. sem chão perto, mas com o chão da cidade lá embaixo: depois da espera ele cai até o chão (não some);
#   3. resgate: caindo pelo buraco abaixo de Y_VOID, volta para o último lugar seguro em pé;
#   4. "Continuar" de verdade (com a tela de carregamento): volta ao jogo salvo e fica em pé onde salvou.
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
func fisica(n):
	for i in n:
		await physics_frame

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
	m.vagos.limpar()
	var base: Vector3 = j.global_position
	var chao: float = m.mundo.altura(base.x, base.z)
	# 1. o chão aparece depois
	var alto := Vector3(base.x + 12.0, chao + 40.0, base.z)
	j.teleportar(alto, 0.0)
	await fisica(40)
	ok(absf(j.global_position.y - alto.y) < 0.01, "chegou num lugar sem chão: fica parado esperando (y %.2f)" % j.global_position.y)
	var piso := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(6, 0.4, 6)
	forma.shape = caixa
	piso.add_child(forma)
	m.jogo.add_child(piso)
	piso.global_position = alto - Vector3(0, 0.3, 0)
	await fisica(40)
	ok(j.is_on_floor() and absf(j.global_position.y - (alto.y - 0.1)) < 0.2, "o chão apareceu: fica em pé nele (y %.2f)" % j.global_position.y)
	piso.queue_free()
	await fisica(5)
	# 2. sem chão perto, com o chão da cidade lá embaixo: espera e depois cai até ele
	j.teleportar(alto, 0.0)
	await fisica(int(j.ESPERA_CHAO * 60.0) + 200)
	ok(j.is_on_floor() and absf(j.global_position.y - chao) < 1.0, "sem chão perto: depois da espera cai até o chão da cidade (y %.2f, chão %.2f)" % [j.global_position.y, chao])
	# 3. resgate do void
	j.teleportar(Vector3(base.x, chao + 0.05, base.z), 0.0)
	await fisica(90)
	var seguro: Vector3 = j.ponto_seguro
	ok(seguro != Vector3.INF and seguro.distance_to(Vector3(base.x, chao, base.z)) < 1.0, "em pé, o ponto seguro fica anotado")
	j.global_position = Vector3(base.x + 300.0, -50.0, base.z + 300.0)   # caiu por um buraco no mundo
	j.velocity = Vector3(0, -20, 0)
	var antes: int = j.resgates
	await fisica(120)
	ok(j.resgates == antes + 1 and j.global_position.distance_to(seguro) < 1.5 and j.global_position.y > chao - 0.5, "caiu no void: volta para o último lugar seguro (%s)" % str(j.global_position))
	await fisica(30)
	ok(j.is_on_floor(), "depois do resgate fica em pé")
	# 4. "Continuar" de verdade, com a tela de carregamento
	var longe := Vector2(base.x - 40.0, base.z + 25.0)
	m.mundo.forcar(longe)
	j.teleportar(Vector3(longe.x, m.mundo.altura(longe.x, longe.y) + 0.05, longe.y), 0.0)
	await fisica(60)
	var salvo: Vector3 = j.global_position
	m.salvar_jogo()
	m._abrir_menu()
	await q(10)
	m.carregar_em_etapas = true
	m._jogar(true)
	var t0 := Time.get_ticks_msec()
	while m.carregamento == null and Time.get_ticks_msec() - t0 < 20000:      # a tela aparece
		await process_frame
	while (m.carregamento != null or m.get_node_or_null("TelaCarregamento") != null or m.jogador == null) and Time.get_ticks_msec() - t0 < 400000:
		await process_frame
	j = m.jogador
	var menor := INF
	for i in 180:
		await physics_frame
		menor = minf(menor, j.global_position.y)
	ok(j.global_position.distance_to(salvo) < 1.0 and j.is_on_floor() and menor > salvo.y - 1.0, "Continuar: volta onde salvou, em pé, sem cair (menor y %.2f, salvo %.2f)" % [menor, salvo.y])
	print("falhas: ", falhas)
	quit()
