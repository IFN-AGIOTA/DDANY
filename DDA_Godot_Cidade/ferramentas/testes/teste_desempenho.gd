extends SceneTree
# TESTE DE DESEMPENHO (1.00 · estudos/ESTUDO_AAA.md 1.1 "medir antes de mexer"): mede os contadores da Godot que
# NÃO dependem do aparelho (chamadas de desenho, objetos na tela, triângulos, nós na cena, nós rodando todo quadro)
# em 3 lugares fixos, sempre do mesmo jeito (meio-dia, tempo limpo, sem infectados), e compara com a referência
# gravada em ferramentas/testes/desempenho_base.json. Piorou mais que TOLERANCIA = FALHA (alguma mudança pesou).
# O tempo de quadro e o custo dos infectados só são mostrados (dependem da máquina).
# Gravar a referência nova (depois de uma mudança que pesa de propósito):
#   GRAVAR=1 godot --rendering-driver opengl3 -s res://ferramentas/testes/teste_desempenho.gd
const BASE := "res://ferramentas/testes/desempenho_base.json"
const TOLERANCIA := 0.12              # até 12% a mais passa (o resto é piora de verdade)
const FOLGA := {"chamadas": 12, "objetos": 12, "triangulos": 8000, "nos": 400, "processando": 4}
const LUGARES := [
	# nome, onde (x, z) ou vazio = onde o jogo começa, giro da câmera, inclinação
	["base militar (início)", Vector2.INF, PI * 0.75, 0.0],
	["centro da cidade", Vector2(436, 1500), 0.0, 0.0],
	["centro olhando a avenida", Vector2(436, 1500), 1.2, -0.15],
	["olhando a Ponte do Brooklyn", Vector2.ZERO, 0.0, -0.05],     # 1.16 (o lugar sai de mundo/pontes.gd)
	["Central Park (The Mall)", Vector2(-1642, -790), -0.05, 0.0],    # 1.20: a alameda dos olmos (mata densa em volta)
	["Central Park (Bethesda)", Vector2(-1612, -1392), PI, 0.08], # 1.20: a praça, a fonte e o terraço
]
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

func _mediana(l: Array) -> float:
	l.sort()
	return float(l[l.size() / 2])

func _medir() -> Dictionary:
	await q(30)
	var dc: Array = []
	var ob: Array = []
	var pr: Array = []
	var t0 := Time.get_ticks_usec()
	var n := 40
	for i in n:
		await process_frame
		dc.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		ob.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		pr.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var quadro := float(Time.get_ticks_usec() - t0) / n / 1000.0
	var procs := 0
	for no in root.find_children("*", "", true, false):
		if no.is_processing() or no.is_physics_processing():
			procs += 1
	return {"chamadas": int(_mediana(dc)), "objetos": int(_mediana(ob)), "triangulos": int(_mediana(pr)),
		"nos": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "processando": procs, "quadro_ms": snappedf(quadro, 0.1)}

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
	m.vagos.ativo = false                      # sem infectados: o mesmo resultado toda vez
	m.clima.hora = 12.0
	m.clima.forcar_tempo("limpo", true)
	var medidas := {}
	var Pontes = load("res://mundo/pontes.gd")
	for l in LUGARES:
		var c: Vector2 = l[1]
		var giro := float(l[2])
		if c == Vector2.ZERO:                    # 150 m antes da Ponte do Brooklyn, olhando para ela
			var br = Pontes.ponte(0)
			c = br.ponto(maxf(br.ini - 150.0, 1.0))
			var db: Vector2 = br.direcao(br.ini)
			giro = atan2(-db.x, -db.y)
		if c != Vector2.INF:
			m.mundo.forcar(c)
			j.teleportar(Vector3(c.x, m.mundo.altura(c.x, c.y) + 0.1, c.y), 0.0)
			await q(120)
		else:
			await q(120)                         # 1.16: o início também espera os prédios em volta "abrirem" (interiores
			                                     # montados um por vez): sem isso a 1ª medida variava de 179 a 224 chamadas
		j.cam_yaw = giro
		j.cam_pit = float(l[3])
		await q(60)
		medidas[l[0]] = await _medir()
		print("  %s: %s" % [l[0], medidas[l[0]]])
	# 1.16: as otimizações continuam valendo
	var Cen = load("res://mundo/cenario.gd")
	var lv: Dictionary = Cen.leves
	ok(lv.has("poste_duplo") and float(lv["poste_duplo"][1]) < 0.6 * float(lv["poste_duplo"][0]), "poste duplo leve: %s" % str(lv.get("poste_duplo")))
	ok(lv.has("poste_jardim") and float(lv["poste_jardim"][1]) < 0.7 * float(lv["poste_jardim"][0]), "poste do jardim leve: %s" % str(lv.get("poste_jardim")))
	var tp: Array = Pontes.triangulos
	ok(tp[1] > 0 and tp[1] < tp[0] * 0.8, "pontes: versão média com menos triângulos (%d de %d)" % [tp[1], tp[0]])
	var V = load("res://mundo/veiculo.gd")
	ok(V.malha_duke_parado() != V.malha_duke(), "Dukes parados com níveis de detalhe")
	# árvore/poste perto pelo ponto mais perto: num canto do bloco (longe do centro) o modelo inteiro aparece
	var ab = m.cidade.abandono
	var par: Array = []
	for k in ab._troca:
		for pp in ab._troca[k]:
			if (pp[2] as Rect2).size.length() > 160.0:
				par = pp
				break
		if not par.is_empty():
			break
	if par.is_empty():
		ok(false, "achei um bloco grande de árvores/postes para testar a troca perto/longe")
	else:
		var r: Rect2 = par[2]
		var canto := r.position + Vector2(2.0, 2.0)
		m.mundo.forcar(canto)
		j.teleportar(Vector3(canto.x, m.mundo.altura(canto.x, canto.y) + 0.1, canto.y), 0.0)
		await q(60)
		var cam_d := Vector2(j.get_viewport().get_camera_3d().global_position.x, j.get_viewport().get_camera_3d().global_position.z).distance_to(r.get_center())
		ok(par[0].visible and not par[1].visible, "%s no canto do bloco (centro a %.0f m): modelo inteiro, sem o de longe" % [str(par[0].name), cam_d])
		var longe := r.get_center() + Vector2(600, 0)
		ab.atualizar_perto(Vector3(longe.x, 0, longe.y))
		ok(not par[0].visible and par[1].visible, "de longe volta para a versão simples")
	# custo dos infectados (só mostra: depende da máquina)
	m.vagos.ativo = true
	m.vagos.max_ativos = 0
	var p0: Vector3 = j.global_position
	for k in 16:
		var a := k * TAU / 16.0
		var p := p0 + Vector3(cos(a), 0, sin(a)) * randf_range(8.0, 30.0)
		if m.vagos._livre(p.x, p.z):
			m.vagos._criar(Vector3(p.x, m.mundo.altura(p.x, p.z), p.z), Vector3.INF)
	await q(120)
	print("  infectados: %d de verdade custam %.2f ms por quadro (orçamento %.1f ms)" % [m.vagos.vivos.size(), m.vagos.custo_ms, m.vagos.orcamento_ms])
	var arq := ProjectSettings.globalize_path(BASE)
	if OS.get_environment("GRAVAR") == "1" or not FileAccess.file_exists(arq):
		var f := FileAccess.open(arq, FileAccess.WRITE)
		f.store_string(JSON.stringify(medidas, "\t"))
		f.close()
		print("  referência gravada em ", BASE)
	else:
		var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arq))
		for lugar in medidas:
			if not base.has(lugar):
				continue
			for k in FOLGA:
				var agora := float(medidas[lugar][k])
				var antes := float(base[lugar][k])
				var limite := antes * (1.0 + TOLERANCIA) + float(FOLGA[k])
				ok(agora <= limite, "%s · %s: %d (referência %d, limite %d)" % [lugar, k, int(agora), int(antes), int(limite)])
	print("falhas: ", falhas)
	quit()
