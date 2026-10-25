extends SceneTree
# TESTE: TELA DE NOVIDADES (0.96). A lista (gerada do LEIA-ME) começa pela versão instalada e vai da mais nova para
# a mais antiga, sem listas de arquivos; o botão do menu abre a tela, "mostrar mais antigas" acrescenta e Voltar fecha.
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
		await process_frame
func _r():
	var Lista = load("res://menu/novidades_lista.gd")
	var Ger = load("res://ferramentas/gerar_novidades.gd")
	var L: Array = Lista.LISTA
	ok(L.size() >= 70, "%d atualizações na lista" % L.size())
	ok(str(L[0][0]) == Config.VERSAO, "a primeira é a versão instalada (%s)" % L[0][0])
	var ordem := true
	var vazias := 0
	var com_arquivos := 0
	for i in L.size():
		if i > 0 and Ger._num(str(L[i][0])) >= Ger._num(str(L[i - 1][0])):
			ordem = false
		if (L[i][2] as Array).is_empty():
			vazias += 1
		for t in L[i][2]:
			if str(t).to_upper().contains("ARQUIVOS MEXIDOS"):
				com_arquivos += 1
	ok(ordem, "da mais nova para a mais antiga")
	ok(vazias == 0 and com_arquivos == 0, "todas com texto e sem listas de arquivos (%d vazias, %d com arquivos)" % [vazias, com_arquivos])
	await q(60)
	var m = current_scene
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	await q(5)
	m.menu._abrir_novidades()
	await q(10)
	var t = m.menu.get_node_or_null("Novidades")
	ok(t != null and t._mostradas == t.POR_VEZ, "o botão abre a tela com as %d mais novas" % (t._mostradas if t != null else 0))
	# arrastar com o DEDO em cima dos cartões rola a lista (0.96.1)
	var rolar: ScrollContainer = null
	for c in t._raiz.get_children():
		if c is ScrollContainer:
			rolar = c
	var vs := root.get_visible_rect().size
	var p0 := Vector2(vs.x * 0.5, vs.y * 0.8)
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = p0
	ev.pressed = true
	Input.parse_input_event(ev)
	await q(2)
	for k in 12:
		var dr := InputEventScreenDrag.new()
		dr.index = 0
		dr.position = p0 - Vector2(0, 25.0 * (k + 1))
		dr.relative = Vector2(0, -25.0)
		dr.velocity = Vector2(0, -600.0)
		Input.parse_input_event(dr)
		await q(1)
	var solta := InputEventScreenTouch.new()
	solta.index = 0
	solta.position = p0 - Vector2(0, 300.0)
	solta.pressed = false
	Input.parse_input_event(solta)
	await q(10)
	ok(rolar != null and rolar.scroll_vertical > 100, "arrastar o dedo rola a lista (desceu %d px)" % (rolar.scroll_vertical if rolar != null else 0))
	var antes: int = t._mostradas
	ok(antes == t.POR_VEZ, "arrastar não apertou nenhum botão (%d cartões)" % antes)
	# um TOQUE rápido no botão "Mostrar mais antigas" (lá embaixo) ainda funciona
	rolar.scroll_vertical = 9999999
	await q(5)
	var bm: Control = t._mais
	var c := bm.get_global_rect().get_center()
	var tp := InputEventScreenTouch.new()
	tp.index = 0
	tp.position = c
	tp.pressed = true
	Input.parse_input_event(tp)
	await q(2)
	var tr := InputEventScreenTouch.new()
	tr.index = 0
	tr.position = c
	tr.pressed = false
	Input.parse_input_event(tr)
	await q(5)
	ok(t._mostradas == 2 * t.POR_VEZ, "um toque em \"Mostrar mais antigas\" acrescenta (%d cartões)" % t._mostradas)
	t._sair()
	await q(5)
	ok(m.menu.get_node_or_null("Novidades") == null, "Voltar fecha")
	print("[teste_novidades] falhas: ", falhas)
	print("TUDO CERTO" if falhas == 0 else "ALGUM TESTE FALHOU")
	quit()
