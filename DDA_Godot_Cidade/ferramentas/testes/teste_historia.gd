extends SceneTree
# TESTE: MODO HISTÓRIA (1.13) · o jogo de verdade, Prólogo + Missão 1 "A Última Corrida":
#   · o mundo ANTES DO CAOS: sem infectados, sem as peças de abandono (carros largados, lixo...), o jogador é o Dominic
#   · o GPS (hud/rota_gps.gd) acha a rota pelas ruas, ela fica dentro do percurso da corrida e não passa por bloqueio
#   · a ÁREA LIBERADA tem bloqueios nas ruas que saem do percurso (com colisão)
#   · as cenas podem ser PULADAS (segurar) e o controle volta
#   · os dois carros (Kiri '86 e JDM Sport '99) andam; o Greg é o piloto do jogo
#   · um piloto de teste dirige o Kiri até a chegada: a missão termina e o progresso fica salvo (user://historia.json)
#   · voltando ao menu, a cidade fica como era (o abandono volta) para o modo livre
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)
func _initialize():
	root.size = Vector2i(1280, 720)
	var arq := "user://historia.json"
	if FileAccess.file_exists(arq):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(arq))
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func q(n):
	for i in n:
		await process_frame
func _pular(h) -> void:
	h.cena.pular_teste = true
	var t0 := Time.get_ticks_msec()
	while h.cena.tocando and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	h.cena.pular_teste = false

func _r():
	await q(30)
	var m = current_scene
	if m.tela_login != null:
		m.tela_login._sair()
	m._jogar_historia()
	var t0 := Time.get_ticks_msec()
	while (m.historia == null or m.historia.missao == null) and Time.get_ticks_msec() - t0 < 300000:
		await process_frame
	var h = m.historia
	ok(h != null and h.missao != null, "o modo história abre e a Missão 1 começa")
	if h == null:
		quit(); return
	ok(not m.vagos.ativo, "sem infectados")
	var esc := 0
	for n in m.cidade.detalhes_abandono:
		if is_instance_valid(n) and not n.visible:
			esc += 1
	ok(esc > 50, "as peças de abandono somem antes do caos (%d escondidas)" % esc)
	var sob = m.jogador.get_node_or_null("Slot/Sobrevivente")
	if sob == null:
		for c in m.jogador.find_children("Sobrevivente", "", true, false): sob = c
	ok(sob != null and sob.cor_cabelo().r > 1.5, "o jogador é o Dominic (cabelo branco)")
	ok(m.missoes == null and m.hospitais == null and m.eventos == null, "o modo livre fica de fora (missões do rádio, eventos, hospitais)")
	# prólogo: pula
	while not h.cena.tocando: await process_frame
	var tp := Time.get_ticks_msec()
	await _pular(h)
	ok(not h.cena.tocando and Time.get_ticks_msec() - tp < 15000, "o Prólogo pode ser pulado (segurando)")
	var mis = h.missao
	# GPS e área
	var R = load("res://hud/rota_gps.gd")
	ok(mis.caminho.size() > 5 and mis.medidor.total() > 2000.0, "o percurso da corrida sai do GPS pelas ruas (%d m)" % int(mis.medidor.total()))
	var fora := 0.0
	for p in mis.caminho:
		fora = maxf(fora, R.distancia(mis.caminho, p))
	var bl: Array = mis.area.bloqueios
	ok(bl.size() >= 8, "bloqueios nas ruas que saem do percurso (%d)" % bl.size())
	var perto := 0.0
	for b in bl:
		perto = maxf(perto, R.distancia(mis.caminho, Vector2(b[0].x, b[0].z)))
	ok(perto < 40.0, "os bloqueios ficam na borda do percurso (o mais longe a %.0f m)" % perto)
	var r2 = R.rota(mis.caminho[0], mis.caminho[mis.caminho.size() - 1])
	var maior := 0.0
	for p in r2:
		maior = maxf(maior, R.distancia(mis.caminho, p))
	ok(r2.size() > 1 and maior < 45.0, "a linha do GPS fica dentro da área (no máximo %.0f m do percurso)" % maior)
	# largada: pula
	while not h.cena.tocando: await process_frame
	await _pular(h)
	await q(10)
	ok(not m.controles.bloqueado, "depois da cena o controle volta")
	ok(m.jogador.veiculo == mis.kiri and mis.kiri.tipo == "kiri86", "o Dominic está no Kiri '86")
	ok(mis.kiri.cam_interior != null and mis.jdm.cam_interior != null, "os dois carros têm câmera no banco do motorista (interior)")
	# corrida: piloto de teste no Kiri
	var P = load("res://historia/piloto_ia.gd")
	var p = P.new()
	p.carro = mis.kiri
	p.definir(mis.caminho)
	p.vel_max = 36.0
	mis.add_child(p)
	p.ligado = true
	mis.piloto.vel_max = 24.0          # o Greg mais devagar no teste: quem tem que ganhar é o Dominic
	m.jogador.piloto_externo = true
	m.jogador.primeira_pessoa = true
	await q(20)
	ok(get_root().get_viewport().get_camera_3d() == mis.kiri.cam_interior, "em 1ª pessoa a câmera vai para dentro do carro")
	m.jogador.primeira_pessoa = false
	var t_corrida := Time.get_ticks_msec()
	var greg_andou := false
	var n0: int = h.cena.n_cenas
	while is_instance_valid(mis) and h.cena.n_cenas == n0 and Time.get_ticks_msec() - t_corrida < 600000:
		if mis.piloto.progresso() > 150.0:
			greg_andou = true
		await process_frame
	ok(greg_andou, "o Greg (piloto do jogo) corre")
	ok(h.cena.n_cenas > n0, "a corrida chega ao fim (cena da chegada)")
	# chegada e fim: pula as cenas até voltar ao menu
	var tf := Time.get_ticks_msec()
	while m.historia != null and Time.get_ticks_msec() - tf < 120000:
		if is_instance_valid(h) and h.cena.tocando:
			h.cena.pular_teste = true
		await process_frame
	var d = load("res://historia/historia.gd").ler()
	ok(bool(d.get("ato1_corrida", false)), "a Missão 1 fica salva como concluída (%s)" % str(d))
	ok(m.menu != null, "no fim volta para o menu")
	var vis := 0
	for n in m.cidade.detalhes_abandono:
		if is_instance_valid(n) and n.visible:
			vis += 1
	ok(vis >= esc, "a cidade volta como era para o modo livre (%d peças de abandono à vista)" % vis)
	print("falhas: ", falhas)
	quit()
