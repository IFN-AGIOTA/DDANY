extends SceneTree
# TESTE: MENU LEVE (1.02). No menu principal e com o jogo rodando:
#   · mexer no volume só mexe no som (antes, com o jogo rodando, cada passo do deslizante levava ~0,6 s);
#   · "Restaurar tudo" e trocar opções que não mudam os gráficos não refazem os objetos da rua;
#   · quando os gráficos mudam de verdade, refazer os objetos da rua é rápido (antes ~0,55 s);
#   · as Opções montam só a aba aberta (as outras na primeira vez) e abrem rápido;
#   · com as Opções na tela o 3D não é desenhado (e volta ao fechar);
#   · o arquivo de opções é gravado depois do último passo (não a cada passo), e já ao fechar as Opções.
var falhas := 0
var Config
var UI = preload("res://menu/ui.gd")
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

func _ms(f: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	f.call()
	return (Time.get_ticks_usec() - t0) / 1000.0

func _paginas_montadas(op) -> int:
	var n := 0
	for p in op._paginas:
		if p != null:
			n += 1
	return n

func _volume(m, onde: String) -> void:
	var pior := 0.0
	for i in 20:
		var v := (i * 5) % 100
		pior = maxf(pior, _ms(func(): Config.definir("mvol", v)))
		await q(1)
	ok(pior < 20.0, "%s: cada passo do volume da música leva %.2f ms no pior caso" % [onde, pior])
	var bm := AudioServer.get_bus_index("Musica")
	if bm != -1:
		Config.definir("mvol", 40)
		ok(absf(AudioServer.get_bus_volume_db(bm) - linear_to_db(0.4)) < 0.1, "%s: e o volume da música muda de verdade" % onde)
	var restaurar := _ms(func():
		for k in Config.o:
			Config.mudou.emit(k)
		Config.mudou.emit("gfx"))
	ok(restaurar < 100.0, "%s: \"Restaurar tudo\" sem mudar os gráficos: %.1f ms" % [onde, restaurar])

func _r():
	Config = root.get_node("Config")
	await q(30)
	var m = current_scene
	var vp: Viewport = root.get_viewport()
	var mvol0 = Config.valor("mvol")

	# ---- menu principal ----
	var abrir := _ms(func(): m._abrir_opcoes())
	await q(3)
	var op = m.opcoes
	ok(abrir < 80.0, "abrir as Opções: %.1f ms" % abrir)
	ok(_paginas_montadas(op) == 1, "só a aba aberta foi montada (%d de %d)" % [_paginas_montadas(op), op._paginas.size()])
	ok(vp.disable_3d, "com as Opções na tela o 3D não é desenhado")
	op._trocar_aba(5)
	await q(2)
	ok(_paginas_montadas(op) == 2 and op._paginas[5].visible and not op._paginas[0].visible,
		"trocar de aba monta a nova e esconde a outra")
	var ds: Array = []
	for d in op._paginas[5].find_children("*", "", true, false):
		if is_instance_of(d, UI.Deslizante):
			ds.append(d)
	ok(ds.size() >= 3, "a aba Vídeo e som tem os deslizantes de volume (%d)" % ds.size())
	await _volume(m, "MENU")
	# gravar depois
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Config.ARQUIVO))
	Config.definir("mvol", 55)
	ok(not FileAccess.file_exists(Config.ARQUIVO), "o passo do deslizante não grava o arquivo na hora")
	await q(3)
	var t0 := Time.get_ticks_msec()
	while not FileAccess.file_exists(Config.ARQUIVO) and Time.get_ticks_msec() - t0 < 3000:
		await q(1)
	var depois := Time.get_ticks_msec() - t0
	ok(FileAccess.file_exists(Config.ARQUIVO) and depois < 2000, "grava sozinho logo depois do último passo (%d ms)" % depois)
	var cf := ConfigFile.new()
	cf.load(Config.ARQUIVO)
	ok(int(cf.get_value("opcoes", "mvol", -1)) == 55, "com o valor certo")
	Config.definir("mvol", 60)
	m._fechar_opcoes()
	cf.load(Config.ARQUIVO)
	ok(int(cf.get_value("opcoes", "mvol", -1)) == 60, "fechar as Opções grava na hora o que faltava")
	await q(3)
	ok(not vp.disable_3d, "fechou as Opções: o 3D volta")

	# ---- jogo rodando ----
	m._jogar()
	await q(60)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	await q(120)
	m._abrir_opcoes()
	await q(3)
	m.opcoes._trocar_aba(5)
	await q(2)
	await _volume(m, "JOGO")
	var ab = m.cidade.abandono
	var nivel := int(Config.g.get("models", 2))
	var refazer := _ms(func(): ab.aplicar_modelos((nivel + 1) % 4))
	ab.aplicar_modelos(nivel)
	ok(refazer < 150.0, "mudar \"Detalhes dos modelos\" de verdade refaz os objetos da rua em %.1f ms (%d objetos)" % [refazer, ab.nos.size()])
	# o aplicador volta a aplicar quando muda de verdade
	var g2: Dictionary = Config.g.duplicate()
	g2["models"] = (nivel + 1) % 4
	var algum = null
	for n in ab.nos:
		if is_instance_valid(n) and not (n in ab.nos_fios) and not (n in ab.nos_halos) and n.has_meta("alc"):
			algum = n
			break
	var antes: float = algum.visibility_range_end if algum != null else 0.0
	Config.aplicar_graficos(g2)
	ok(algum != null and absf(algum.visibility_range_end - antes) > 0.01, "APLICAR com outro nível de modelos ainda muda o alcance dos objetos")
	g2["models"] = nivel
	Config.aplicar_graficos(g2)
	m._fechar_opcoes()
	await q(3)
	ok(not vp.disable_3d, "no jogo, fechar as Opções também traz o 3D de volta")
	Config.definir("mvol", mvol0)
	Config.salvar_pendente()
	print("falhas: ", falhas)
	quit()
