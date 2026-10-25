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
	t._acrescentar(t.POR_VEZ)
	await q(5)
	ok(t._mostradas == 2 * t.POR_VEZ, "mostrar mais antigas acrescenta")
	t._sair()
	await q(5)
	ok(m.menu.get_node_or_null("Novidades") == null, "Voltar fecha")
	print("[teste_novidades] falhas: ", falhas)
	print("TUDO CERTO" if falhas == 0 else "ALGUM TESTE FALHOU")
	quit()
