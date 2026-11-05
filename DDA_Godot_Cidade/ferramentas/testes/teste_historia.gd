extends SceneTree
# TESTE: MODO HISTÓRIA (1.13) · o jogo de verdade, Prólogo + Missão 1 "A Última Corrida":
#   · o mundo ANTES DO CAOS: sem infectados, sem as peças de abandono (carros largados, lixo...), o jogador é o Dominic
#   · o GPS (hud/rota_gps.gd) acha a rota pelas ruas, ela fica dentro do percurso da corrida e não passa por bloqueio
#   · a ÁREA LIBERADA tem bloqueios nas ruas que saem do percurso (com colisão)
#   · as cenas podem ser PULADAS (segurar) e o controle volta
#   · os dois carros (Kiri '86 e JDM Sport '99) andam; o Greg é o piloto do jogo
#   · um piloto de teste dirige o Kiri até a chegada: a missão termina e o progresso fica salvo (user://historia.json)
#   · (1.14) MISSÃO 2: entrar no Kiri pelo botão PEGAR, seguir o Greg até o bar, sair, entrar no bar (cenário),
#     sentar na mesa do canto (a cena da TV começa); depois o interlúdio; as duas ficam salvas
#   · voltando ao menu, a cidade fica como era (o abandono volta) para o modo livre
#   · (1.14.4) BLOQUEADO sem o modo desenvolvedor: sem botão no menu e não abre; com ele ligado, o botão aparece
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
	# 1.14.4: começa SEM o modo desenvolvedor (o modo história tem de estar bloqueado)
	if FileAccess.file_exists("user://dev.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://dev.cfg"))
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
func _esperar(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await process_frame

func _botao_historia(m) -> bool:
	if m.menu == null:
		return false
	for b in m.menu.find_children("*", "Control", true, false):
		if str(b.get("titulo")) == "História" and b.is_inside_tree():
			return true
	return false

func _r():
	await q(30)
	var m = current_scene
	if m.tela_login != null:
		m.tela_login._sair()
	await q(10)
	# 1.14.4: BLOQUEADO por padrão: sem o modo desenvolvedor não há botão e o modo história não abre
	ok(not _botao_historia(m), "sem o modo desenvolvedor o menu não mostra o botão HISTÓRIA")
	m._jogar_historia()
	await q(20)
	ok(m.historia == null and m.jogo == null, "sem o modo desenvolvedor o modo história não abre")
	var cf := ConfigFile.new()
	cf.set_value("dev", "ativo", true)                  # como o INFINITYDEV no chat (dev/modo_dev.gd)
	cf.save("user://dev.cfg")
	for n in [m.menu, m.cena_menu]:                     # (o menu volta a ser montado, como ao sair de um jogo)
		if n != null and is_instance_valid(n):
			n.queue_free()
	await q(2)
	m._abrir_menu()
	await q(10)
	ok(_botao_historia(m), "com o modo desenvolvedor o botão HISTÓRIA aparece no menu")
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
	ok(not h.cena.tocando and Time.get_ticks_msec() - tp < 25000, "o Prólogo pode ser pulado (segurando)")   # (folga: logo depois de carregar, o Xvfb fica bem lento; normal 7-8 s)
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
	mis.piloto.vel_max = 16.0          # o Greg mais devagar no teste: os dois pilotos do jogo empatam; aqui quem ganha é o Dominic
	mis.kiri.add_collision_exception_with(mis.jdm)    # (só no teste) os dois seguem a mesma linha: o Kiri passa "por dentro" do JDM
	m.jogador.piloto_externo = true
	m.jogador.primeira_pessoa = true
	await q(20)
	ok(get_root().get_viewport().get_camera_3d() == mis.kiri.cam_interior, "em 1ª pessoa a câmera vai para dentro do carro")
	m.jogador.primeira_pessoa = false
	var t_corrida := Time.get_ticks_msec()
	var greg_andou := false
	var n0: int = h.cena.n_cenas
	var tl0 := 0
	while is_instance_valid(mis) and h.cena.n_cenas == n0 and Time.get_ticks_msec() - t_corrida < 600000:
		if mis.piloto.progresso() > 150.0:
			greg_andou = true
		if Time.get_ticks_msec() - tl0 > 15000:
			tl0 = Time.get_ticks_msec()
			var pk: Vector3 = mis.kiri.global_position
			var md: Array = mis.medidor.medir(Vector2(pk.x, pk.z))
			print("  (corrida: Dominic %d m · Greg %d m · v %d · fora do percurso %.0f m · %s)" % [int(md[0]), int(mis.piloto.progresso()), int(mis.kiri.linear_velocity.length()), float(md[2]), h._sub.text])
		await process_frame
	print("  (cena que acabou a corrida: objetivo '%s')" % h._obj.text)
	ok(greg_andou, "o Greg (piloto do jogo) corre")
	ok(h.cena.n_cenas > n0, "a corrida chega ao fim (cena da chegada)")
	m.jogador.piloto_externo = false
	# MISSÃO 2 (1.14): cena da chegada, entrar no Kiri, seguir o Greg, entrar no bar, sentar
	var tb := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tb < 120000 and not (is_instance_valid(h.missao) and str(h.missao.get_script().resource_path).ends_with("missao_bar.gd")):
		if h.cena.tocando:
			h.cena.pular_teste = true
		await process_frame
	var bar = h.missao
	var tem_bar: bool = is_instance_valid(bar) and str(bar.get_script().resource_path).ends_with("missao_bar.gd")
	ok(tem_bar, "depois da corrida começa a Missão 2 (o bar)")
	if tem_bar:
		while bar.kiri == null and is_instance_valid(bar): await process_frame
		while not h.cena.tocando and Time.get_ticks_msec() - tb < 180000: await process_frame
		await _pular(h)
		await _esperar(1.0)
		m.jogador.teleportar(bar.kiri.global_position + bar.kiri.global_basis.x * 1.8 + Vector3(0, 0.3, 0), 0.0)
		await _esperar(1.0)
		ok(m.jogador.texto_interacao.begins_with("ENTRAR NO"), "o botão PEGAR vira \"ENTRAR NO KIRI\" perto do carro ('%s')" % m.jogador.texto_interacao.replace("\n", " "))
		m.jogador._pegar_do_chao()
		await _esperar(1.0)
		ok(m.jogador.veiculo == bar.kiri, "o Dominic entra no Kiri pela interação")
		var p2 = P.new()
		p2.carro = bar.kiri
		p2.definir(bar.caminho)
		p2.vel_max = 18.0
		bar.add_child(p2)
		p2.ligado = true
		m.jogador.piloto_externo = true
		var ts := Time.get_ticks_msec()
		var greg_seguiu := false
		while h._obj.text != "Estacione e entre no bar" and Time.get_ticks_msec() - ts < 300000:
			if bar.piloto != null and bar.piloto.progresso() > 100.0:
				greg_seguiu = true
			await process_frame
		ok(greg_seguiu, "o Greg vai na frente até o bar")
		ok(h._obj.text == "Estacione e entre no bar", "seguindo o Greg chega ao bar")
		p2.ligado = false
		m.jogador.piloto_externo = false
		bar.kiri.controlar(0, 0, true)
		await _esperar(2.0)
		m.jogador._pegar_do_chao()
		await _esperar(1.5)
		ok(m.jogador.veiculo == null, "sai do carro na porta do bar")
		m.jogador.teleportar(bar.porta_rua + Vector3(0, 0.2, 0), bar.giro_rua + PI)
		await _esperar(1.0)
		ok(m.jogador.texto_interacao.begins_with("ENTRAR NO"), "na porta, o botão vira \"ENTRAR NO BAR\"")
		m.jogador._pegar_do_chao()
		await _esperar(3.0)
		ok(h.dentro_de == bar.bar, "entra no cenário do bar")
		var cad: Vector3 = bar.bar.pontos["cadeira_dom"]
		ok(m.jogador.global_position.distance_to(cad) < 12.0, "dentro do bar, perto da mesa do canto")
		m.jogador.teleportar(cad + Vector3(0, 0.2, -0.4), 0.0)
		await _esperar(1.0)
		ok(m.jogador.texto_interacao == "SENTAR", "na mesa do canto o botão vira SENTAR ('%s')" % m.jogador.texto_interacao)
		var nc: int = h.cena.n_cenas
		m.jogador._pegar_do_chao()
		var tc := Time.get_ticks_msec()
		while h.cena.n_cenas == nc and not h.cena.tocando and Time.get_ticks_msec() - tc < 20000: await process_frame
		ok(h.cena.tocando or h.cena.n_cenas > nc, "sentar começa a cena da TV")
	# cena do bar, interlúdio e fim: pula as cenas até voltar ao menu
	var tf := Time.get_ticks_msec()
	var tl := 0
	while m.historia != null and Time.get_ticks_msec() - tf < 300000:
		if is_instance_valid(h) and h.cena.tocando:
			h.cena.pular_teste = true
		if Time.get_ticks_msec() - tl > 10000:
			tl = Time.get_ticks_msec()
			print("  (fim: cena %s · n %d · objetivo '%s')" % [h.cena.tocando if is_instance_valid(h) else "-", h.cena.n_cenas if is_instance_valid(h) else -1, h._obj.text if is_instance_valid(h) else ""])
		await process_frame
	var d = load("res://historia/historia.gd").ler()
	ok(bool(d.get("ato1_corrida", false)), "a Missão 1 fica salva como concluída (%s)" % str(d))
	ok(bool(d.get("ato1_bar", false)) and bool(d.get("ato1_tres_dias", false)), "a Missão 2 e o interlúdio ficam salvos como concluídos")
	ok(m.menu != null, "no fim volta para o menu")
	var vis := 0
	for n in m.cidade.detalhes_abandono:
		if is_instance_valid(n) and n.visible:
			vis += 1
	ok(vis >= esc, "a cidade volta como era para o modo livre (%d peças de abandono à vista)" % vis)
	print("falhas: ", falhas)
	quit()
