extends SceneTree
# TESTE: MENUS QUE NÃO "SOBEM SOZINHOS" (1.12.2). O Perfil se refaz quando a lista de amigos atualiza (de 20 em 20 s)
# e o Multijogador quando acha/perde partidas no Wi-Fi ou chegam convites. Antes a rolagem voltava para o topo.
#   · Perfil: rolado para baixo, refazer a tela mantém a rolagem; "SEU PERSONAGEM" fica EMBAIXO (depois da conta)
#   · Multijogador: idem na mesma tela; trocar de tela (modo) começa do topo
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)
func _initialize():
	root.size = Vector2i(1280, 600)
	change_scene_to_file("res://main.tscn")
	_r.call_deferred()
func q(n):
	for i in n:
		await process_frame

func _secoes(tudo: Node) -> Array:
	var r := []
	for c in tudo.get_children():
		if c.name == "PainelPersonagem":
			r.append("PAINEL")
		for l in c.find_children("*", "Label", true, false):
			r.append((l as Label).text)
	return r

func _r():
	await q(40)
	var m = current_scene
	if m.tela_login != null:
		m.tela_login._sair()
	await q(5)
	# ---- PERFIL (sem conta e com conta + amigos simulados, sem internet)
	for logado in [false, true]:
		await _perfil(logado)
	await _multi()
	print("falhas: ", falhas)
	quit()

func _perfil(logado: bool) -> void:
	var C = root.get_node("Conta")
	var guarda := [C.logado, C.nome, C.amigos.duplicate(), C.status_amigos.duplicate(), C.codigo_amigo]
	if logado:
		C.logado = true
		C.nome = "TESTE"
		C.codigo_amigo = "ABC123"
		for k in 6:
			C.amigos["u%d" % k] = {"nome": "Amigo %d" % k, "codigo": "X", "avatar": k}
	var tag := "com conta" if logado else "sem conta"
	var p = load("res://menu/tela_perfil.gd").new()
	root.add_child(p)
	await q(10)
	var sc: ScrollContainer = p._rolar
	var tudo: Node = sc.get_child(0)
	var s := _secoes(tudo)
	var i_pers := s.find("SEU PERSONAGEM")
	var i_painel := s.find("PAINEL")
	var i_conta := maxi(s.find("CONTA"), s.find("AMIGOS (%d)" % root.get_node("Conta").amigos.size()))
	ok(i_pers >= 0 and i_painel > i_pers and i_conta >= 0 and i_pers > i_conta,
		"Perfil %s: SEU PERSONAGEM fica embaixo, depois da conta" % tag)
	var maxr := int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page)
	ok(maxr > 50, "Perfil %s: dá para rolar (%d px)" % [tag, maxr])
	sc.scroll_vertical = maxr
	await q(3)
	var antes := sc.scroll_vertical
	p._remontar()                       # o que acontece quando a lista de amigos atualiza
	await q(10)
	ok(p._rolar != sc and absi(p._rolar.scroll_vertical - antes) <= 2,
		"Perfil %s: refeito, a rolagem fica no lugar (%d -> %d)" % [tag, antes, p._rolar.scroll_vertical])
	p._remontar()
	await q(10)
	ok(absi(p._rolar.scroll_vertical - antes) <= 2, "Perfil %s: e de novo (%d)" % [tag, p._rolar.scroll_vertical])
	if logado and OS.get_environment("FOTO") != "":
		p._rolar.scroll_vertical = 0
		await q(4)
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("FOTO") + "_topo.png")
		p._rolar.scroll_vertical = 9999
		await q(4)
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("FOTO") + "_baixo.png")
	p.queue_free()
	await q(3)
	C.logado = guarda[0]
	C.nome = guarda[1]
	C.amigos = guarda[2]
	C.status_amigos = guarda[3]
	C.codigo_amigo = guarda[4]

func _multi() -> void:
	# ---- MULTIJOGADOR
	var t = load("res://menu/tela_multijogador.gd").new()
	root.add_child(t)
	await q(10)
	for modo in ["inicio", "mundos", "entrar"]:
		t.modo = modo
		for k in 14:                      # muitas partidas achadas no Wi-Fi: a lista passa da tela
			t._achadas["10.0.0.%d" % k] = ["Sala %d" % k, 1, Time.get_ticks_msec()]
		t._montar()
		await q(10)
		var a: ScrollContainer = t._area
		var mx := int(a.get_v_scroll_bar().max_value - a.get_v_scroll_bar().page)
		if mx <= 10:
			print("  (Multijogador '%s' cabe na tela: nada para rolar)" % modo)
			continue
		a.scroll_vertical = mx
		await q(3)
		var r0 := a.scroll_vertical
		t._montar()                      # achou/perdeu partida no Wi-Fi, convite...
		await q(10)
		ok(absi(t._area.scroll_vertical - r0) <= 2, "Multijogador '%s': refeito, a rolagem fica (%d -> %d)" % [modo, r0, t._area.scroll_vertical])
	# trocar de tela começa do topo
	t._area.scroll_vertical = 9999
	t.modo = "entrar" if t.modo != "entrar" else "inicio"
	t._montar()
	await q(10)
	ok(t._area.scroll_vertical == 0, "Multijogador: outra tela começa do topo (%d)" % t._area.scroll_vertical)
	t.queue_free()
	await q(3)
