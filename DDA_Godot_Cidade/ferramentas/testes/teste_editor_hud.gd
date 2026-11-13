extends SceneTree
# TESTE: EDITOR DA HUD (0.97.1), aberto pelo MENU e pela PAUSA do jogo. Os botões ficam por cima de tudo (o menu não
# cobre mais), o painel não cobre nenhum botão, os botões da construção seguem o do lugar deles e não aparecem
# soltos, Voltar/Esc conclui (salva) e tudo volta ao normal.
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
	for i in n: await process_frame
func _conferir(m, onde: String) -> void:
	var ed = m.get_node_or_null("EditorHud")
	ok(ed != null, onde + ": editor aberto")
	if ed == null:
		return
	var c = ed.controles
	ok(c.layer > m.menu.layer if m.menu != null else c.layer > 30, onde + ": os botões ficam por cima de tudo (camada %d)" % c.layer)
	var painel: Rect2 = Rect2(ed._painel.position, ed._painel.size)
	var cobertos := []
	for b in c.botoes:
		if c._visivel(b) and painel.grow(-2.0).has_point(c._centro(b)):
			cobertos.append(b["id"])
	ok(cobertos.is_empty(), onde + ": o painel não cobre nenhum botão %s" % str(cobertos))
	var soltos := []
	for id in c.NO_LUGAR_DE:
		if c._visivel(c._botao(id)):
			soltos.append(id)
	ok(soltos.is_empty(), onde + ": OK/GIRAR/CANCELAR não aparecem soltos no editor")
func _r():
	await q(60)
	var m = current_scene
	if m.tela_login != null: m.tela_login._sair()
	await q(5)
	var Cfg = root.get_node("Config")
	Cfg.definir_hud({})
	# pelo MENU
	m._abrir_opcoes()
	await q(5)
	m._editar_hud()
	await q(15)
	await _conferir(m, "menu")
	var c = m.get_node("EditorHud").controles
	c.layout["ATIRAR"] = [500.0, 300.0, 70.0]
	c.aplicar_layout(c.layout, c.escala, 1.0)
	ok(c._centro(c._botao("OK")) == c._centro(c._botao("ATIRAR")) and c._botao("OK")["r"] == c._botao("ATIRAR")["r"], "o OK (construção) segue o ATIRAR")
	m._voltar()
	await q(5)
	ok(m.get_node_or_null("EditorHud") == null and m.opcoes != null and m.opcoes.visible, "Voltar conclui o editor e volta às Opções")
	ok(Cfg.hud_pos.has("ATIRAR"), "Voltar salvou as posições")
	m._fechar_opcoes()
	# pela PAUSA do jogo
	m._jogar()
	while m.jogador == null: await process_frame
	await q(30)
	var camada0: int = m.controles.layer
	ok(m.controles._centro(m.controles._botao("OK")) == m.controles._centro(m.controles._botao("ATIRAR")), "no jogo o OK está no lugar do ATIRAR movido")
	m._pausar()
	await q(3)
	m._abrir_opcoes()
	await q(3)
	m._editar_hud()
	await q(15)
	await _conferir(m, "jogo")
	# 1.08: os AVISOS são um item do editor (mover e redimensionar), embaixo no meio por padrão, e não são botão
	var ce = m.get_node("EditorHud").controles
	var av: Dictionary = ce._botao("AVISOS")
	var vs: Vector2 = ce.get_viewport().get_visible_rect().size
	ok(not av.is_empty() and ce._visivel(av), "AVISOS aparece no editor da HUD")
	ok(absf(ce._centro(av).x - vs.x * 0.5) < 1.0 and ce._centro(av).y > vs.y * 0.8, "AVISOS: por padrão embaixo, no meio da tela (%s)" % str(ce._centro(av)))
	ce.layout["AVISOS"] = [-200.0, 300.0, 45.0]
	ce.aplicar_layout(ce.layout, ce.escala, 1.0)
	ok(absf(ce._centro(av).x - (vs.x * 0.5 + 200.0 * ce.escala)) < 1.0 and absf(ce.tamanho_do("AVISOS") - 1.5) < 0.01, "AVISOS: muda de lugar e de tamanho")
	m.get_node("EditorHud")._concluir()
	await q(5)
	ok(not m.controles._visivel(m.controles._botao("AVISOS")) and m.controles._botao_no_toque(m.controles._centro(m.controles._botao("AVISOS"))).get("id", "") != "AVISOS", "fora do editor os AVISOS não são botão")
	ok(m.controles._botao("AVISOS")["r"] > 40.0, "o tamanho dos AVISOS ficou salvo")
	ok(m.controles.layer == camada0 and not m.controles.editando, "concluir volta a camada dos botões (%d) e sai da edição" % m.controles.layer)
	m._fechar_opcoes()
	m._continuar()
	await q(5)
	ok(not paused and not m.controles.bloqueado, "volta a jogar")
	Cfg.definir_hud({})
	print("[teste_editor_hud] falhas: ", falhas)
	print("TUDO CERTO" if falhas == 0 else "ALGUM TESTE FALHOU")
	quit()
