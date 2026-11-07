extends SceneTree
# TESTE: BUNKERS (0.83)
#   1. 4 bunkers, números 1..4, um em cada ilha; nenhum prédio saiu do lugar (os jogos salvos continuam valendo)
#   2. itens das tabelas bunker_* e os 4 cartões existem (com modelo 3D)
#   3. o bunker é UMA malha com UMA superfície (uma draw call)
#   4. porta sem cartão: não abre · com o cartão: desce para o NÍVEL 1 e fica em pé no piso
#   5. lá embaixo: escuro total (sem sol, sem luz ambiente, tela preta sem lanterna)
#   6. escadas: cada uma tem rampa e espaço para a cabeça; os 5 níveis têm piso firme nos patamares
#   7. elevador: sobe de volta para a frente da porta e a luz volta
#   8. cartões: ~CHANCE_CARTAO (20%) por área e ciclo; nunca 2 do mesmo bunker; um cartão perdido pode voltar (1 vez)
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

const PREDIOS_ANTES := 18064           # número de prédios antes da 0.83 (bunkers em terreno vazio)

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.clima.definir_hora(13.0)
	m.clima.set("parado", true)
	m.vagos.ativo = true
	m.vagos.max_ativos = 0
	var j = m.jogador
	var L = load("res://mundo/locais.gd")
	var Itens = load("res://inventario/itens.gd")
	var ItemCls = load("res://inventario/item.gd")
	var Modelos = load("res://inventario/modelos_itens.gd")
	var LM = load("res://mundo/loot_mundo.gd")
	# ---- 1 ----
	var bunkers: Array = []
	for i in L.LOCAIS.size():
		if L.LOCAIS[i][0] == "bunker":
			bunkers.append(i)
	var nums: Array = []
	for i in bunkers:
		nums.append(L.numero_bunker(i))
	ok(bunkers.size() == 4 and nums == [1, 2, 3, 4], "1. 4 bunkers numerados %s" % str(nums))
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/city.json"))
	var ilhas := {}
	for i in bunkers:
		var p := Vector2(L.LOCAIS[i][1], L.LOCAIS[i][2])
		for il in data["lands"].size():
			var l: Array = data["lands"][il]
			if int(l[0]) != 0:
				continue
			var poli := PackedVector2Array()
			for k in range(0, (l[1] as Array).size(), 2):
				poli.append(Vector2(l[1][k], l[1][k + 1]))
			if Geometry2D.is_point_in_polygon(p, poli):
				ilhas[il] = true
	ok(ilhas.size() == 4, "1. um bunker em cada ilha (%s)" % str(ilhas.keys()))
	# 1.06: a igreja/prefeitura tiraram alguns (remapa_v4); os bunkers continuam sem tirar nenhum
	var sairam_106 := 0
	for v in m.cidade.remapa_v4:
		if v < 0:
			sairam_106 += 1
	ok(m.cidade.predio_info.size() + sairam_106 == PREDIOS_ANTES, "1. nenhum prédio saiu para os bunkers (%d + %d da 1.06)" % [m.cidade.predio_info.size(), sairam_106])
	# ---- 2 ----
	var faltando: Array = []
	for t in LM.TABELAS:
		if not (String(t).begins_with("bunker_") or t == "chao_bunker"):
			continue
		for e in LM.TABELAS[t]:
			if Itens.def(e[0]).is_empty():
				faltando.append(e[0])
	var modelos_ok := true
	for n in range(1, 5):
		if Itens.def("cartao_bunker_%d" % n).is_empty() or Modelos.instancia("cartao_bunker_%d" % n) == null:
			modelos_ok = false
	ok(faltando.is_empty(), "2. itens das tabelas dos bunkers existem %s" % str(faltando))
	ok(modelos_ok, "2. os 4 cartões existem e têm modelo 3D")
	# ---- abre o bunker 1 ----
	var ib: int = bunkers[0]
	var c := Vector2(L.LOCAIS[ib][1], L.LOCAIS[ib][2])
	m.mundo.forcar(c)
	var frente: Vector2 = L.local_para_mundo(ib, Vector2(0, 3.0))
	j.teleportar(Vector3(frente.x, m.mundo.altura(frente.x, frente.y) + 0.1, frente.y), 0.0)
	m.locais.abrir_agora(c)
	await q(30)
	var no: Node3D = m.locais.abertos.get(ib)
	ok(no != null, "bunker 1 montado")
	if no == null:
		print("falhas: ", falhas)
		quit()
		return
	var malha: MeshInstance3D = no.get_node("Malha")
	var sup: int = malha.mesh.get_surface_count()
	ok(sup == 1, "3. a estrutura é uma malha com uma superfície (%d)" % sup)
	var portas: Array = []
	for n in no.get_children():
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("porta_bunker.gd"):
			portas.append(n)
	ok(portas.size() == 2, "2 pontos de elevador (porta e cabine)")
	var porta = null
	var cabine = null
	for pb in portas:
		if pb.desce:
			porta = pb
		else:
			cabine = pb
	# ---- 4 ----
	var y_rua: float = m.cidade.Y_CALCADA
	j.teleportar(porta.global_position + Vector3(0, 0.1, 0) + no.global_transform.basis * Vector3(0, 0, 0.6), 0.0)
	await q(10)
	var msg: String = porta.usar(j.inventario, j)
	await q(5)
	ok(msg.begins_with("ACESSO NEGADO") and j.global_position.y > y_rua - 1.0, "4. sem cartão: não abre (%s)" % msg)
	var cartao = ItemCls.novo("cartao_bunker_1")
	j.inventario._por(j.inventario.grades_do_jogador()[0], cartao)
	ok(j.inventario.contar("cartao_bunker_1") == 1, "cartão no inventário")
	msg = porta.usar(j.inventario, j)
	await q(60)
	var y1: float = y_rua + load("res://mundo/local_bunker.gd").Y0
	ok(absf(j.global_position.y - y1) < 0.4, "4. com o cartão: desceu e ficou em pé no NÍVEL 1 (y %.2f, piso %.2f)" % [j.global_position.y, y1])
	# ---- 5 ----
	await q(20)
	var env: Environment = m.cidade.ambiente
	ok(bool(m.clima.subsolo) and env.ambient_light_energy == 0.0 and m.cidade.sol.light_energy == 0.0, "5. subsolo: sem sol e sem luz ambiente")
	var lant: bool = m.clima.get("_lanterna_mao") != null and m.clima._lanterna_mao.visible
	var img := root.get_texture().get_image()
	var soma := 0.0
	var nn := 0
	for py in range(int(img.get_height() * 0.3), int(img.get_height() * 0.7), 8):
		for px in range(int(img.get_width() * 0.3), int(img.get_width() * 0.7), 8):
			soma += img.get_pixel(px, py).get_luminance()
			nn += 1
	var lum := soma / maxf(nn, 1)
	print("  luminância no meio da tela: %.3f (lanterna acesa: %s)" % [lum, lant])
	if OS.get_environment("FOTO") != "":
		img.save_png(OS.get_environment("FOTO"))
	ok(lant or lum < 0.04, "5. tela escura sem lanterna")
	# ---- 6 ----
	var B = load("res://mundo/local_bunker.gd")
	var esp: PhysicsDirectSpaceState3D = j.get_world_3d().direct_space_state
	var bola := SphereShape3D.new()
	bola.radius = 0.22
	var pq := PhysicsShapeQueryParameters3D.new()
	pq.shape = bola
	pq.collision_mask = 1
	var ruins: Array = []
	var prep_escadas: Array = no.get_meta("escadas", [])
	for k in B.NIVEIS - 1:
		var x: float = B.LA if k % 2 == 0 else B.LB
		var z0: float = B.ESC_Z if k % 2 == 0 else -B.ESC_Z
		var z1: float = -z0
		var yb: float = B.y_nivel(k + 1)
		for s in 9:
			var t := s / 8.0
			var lp := Vector3(x, yb + B.ANDAR_B * t, lerpf(z0, z1, t))
			var gp: Vector3 = no.global_transform * lp
			var rq := PhysicsRayQueryParameters3D.create(gp + Vector3(0, 1.0, 0), gp + Vector3(0, -0.6, 0), 1)
			var h: Dictionary = esp.intersect_ray(rq)
			if h.is_empty() or absf((h["position"] as Vector3).y - gp.y) > 0.45:
				ruins.append("escada %d passo %d sem rampa" % [k, s])
				continue
			for alt in [1.0, 1.65]:
				pq.transform = Transform3D(Basis.IDENTITY, (h["position"] as Vector3) + Vector3(0, alt, 0))
				if not esp.intersect_shape(pq, 1).is_empty():
					ruins.append("escada %d passo %d bate a %.2f m" % [k, s, alt])
	for k in B.NIVEIS:
		for lp in [Vector3(12.0, B.y_nivel(k), 4.6), Vector3(12.0, B.y_nivel(k), -4.6), Vector3(0.0, B.y_nivel(k), 0.5)]:
			var gp: Vector3 = no.global_transform * lp
			var h: Dictionary = esp.intersect_ray(PhysicsRayQueryParameters3D.create(gp + Vector3(0, 1.0, 0), gp + Vector3(0, -1.0, 0), 1))
			if h.is_empty() or absf((h["position"] as Vector3).y - gp.y) > 0.1:
				ruins.append("nível %d sem piso em %s" % [k + 1, str(lp)])
	ok(ruins.is_empty(), "6. escadas e patamares dos 5 níveis %s" % str(ruins.slice(0, 6)))
	# fica em pé no NÍVEL 5 (o de baixo)
	j.teleportar(no.global_transform * Vector3(0.0, B.y_nivel(4) + 0.1, 0.5), 0.0)
	await q(40)
	ok(absf(j.global_position.y - (y_rua + B.y_nivel(4))) < 0.4, "6. em pé no NÍVEL 5 (y %.2f)" % j.global_position.y)
	# ---- 7 ----
	j.teleportar(cabine.global_position + Vector3(0, 0.1, 0), 0.0)
	await q(10)
	msg = cabine.usar(j.inventario, j)
	await q(40)
	ok(absf(j.global_position.y - y_rua) < 0.5, "7. elevador: voltou para a rua (y %.2f)" % j.global_position.y)
	await q(10)
	ok(not bool(m.clima.subsolo) and env.ambient_light_energy > 0.0 and env.ambient_light_source != Environment.AMBIENT_SOURCE_DISABLED, "7. a luz voltou")
	# ---- 8 ----
	var lm = LM.new()
	lm.semente = 4321
	var hh := [0.0]                          # (a função guarda uma cópia das variáveis: usa uma lista)
	lm.relogio = func() -> float: return hh[0]
	var areas := ["L900", "L901", "L902", "L903", "L904", "L905"]
	for a in areas:
		lm.grade(a + "_0", "militar", "CAIXA", Vector2i(8, 4))
	var tent := 0
	var sorteados: Array = []
	for ciclo in 120:
		hh[0] = ciclo * LM.CICLO_LOCAL + 0.5
		for a in areas:
			tent += 1
			var n: int = lm.tentar_cartao(a, [a + "_0"], 4)
			if n > 0:
				sorteados.append(n)
	var unicos := {}
	for n in sorteados:
		unicos[n] = true
	ok(sorteados.size() == 4 and unicos.size() == 4, "8. só 1 cartão de cada bunker (%s)" % str(sorteados))
	# taxa: com muitos bunkers (nunca acaba) ~CHANCE_CARTAO
	var lm2 = LM.new()
	lm2.semente = 99
	var hh2 := [0.0]
	lm2.relogio = func() -> float: return hh2[0]
	lm2.grade("L990_0", "militar", "CAIXA", Vector2i(8, 4))
	var ganhos := 0
	var tent2 := 0
	for ciclo in 400:
		hh2[0] = ciclo * LM.CICLO_LOCAL + 0.5
		for a in areas:
			tent2 += 1
			if lm2.tentar_cartao(a, ["L990_0"], 4) > 0:
				ganhos += 1
				var g = lm2._grades["L990_0"]
				for it in g.itens.duplicate():
					g.remover(it)
				lm2.cartoes.clear()
	var taxa := float(ganhos) / tent2
	var ch: float = load("res://mundo/loot_mundo.gd").CHANCE_CARTAO
	ok(absf(taxa - ch) < 0.03, "8. chance por área e ciclo ~%.0f%% (%.1f%%)" % [ch * 100.0, taxa * 100.0])
	# cartão perdido (sumiu do mundo): pode aparecer de novo, uma vez
	for a in areas:
		var g = lm._grades[a + "_0"]
		for it in g.itens.duplicate():
			if it.id == "cartao_bunker_2":
				g.remover(it)
	var de_novo: Array = []
	for ciclo in range(120, 400):
		hh[0] = ciclo * LM.CICLO_LOCAL + 0.5
		for a in areas:
			var n: int = lm.tentar_cartao(a, [a + "_0"], 4)
			if n > 0:
				de_novo.append(n)
	ok(de_novo == [2], "8. o cartão 2 perdido voltou uma vez (%s)" % str(de_novo))
	var sv: Dictionary = lm.salvar()
	ok((sv.get("cartoes", {}) as Dictionary).size() == 4, "8. cartões vão no jogo salvo")
	print("falhas: ", falhas)
	quit()
