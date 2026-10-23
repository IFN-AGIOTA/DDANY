extends SceneTree
# TESTE DA TROCA DE OMBRO (0.79): o botão OMBRO / botão do meio do mouse passa a câmera para o outro lado do
# personagem (e mirando, para cima do outro ombro), devagar; fica guardado em Opções (Posição do personagem).
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
func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.vagos.ativo = false
	var j = m.jogador
	var Config = root.get_node("Config")
	Config.definir("pos", "left")
	await q(40)
	var x0: float = j.camera.position.x
	ok(x0 > 0.2, "começa no ombro direito (câmera à direita: %.2f)" % x0)
	m.controles.ombro_pedido.emit()
	await q(3)
	var x_meio: float = j.camera.position.x
	await q(60)
	var x1: float = j.camera.position.x
	ok(x1 < -0.2 and x_meio > x1, "trocou para o esquerdo devagar (%.2f -> %.2f -> %.2f)" % [x0, x_meio, x1])
	ok(Config.valor("pos") == "right", "guardado nas opções (pos = %s)" % Config.valor("pos"))
	j._mirar_ligado = true
	await q(60)
	ok(j.camera.position.x < -0.3, "mirando: em cima do ombro esquerdo (%.2f)" % j.camera.position.x)
	j._mirar_ligado = false
	m.controles._acao("ombro", true)                 # a tecla (botão do meio do mouse) faz o mesmo
	await q(60)
	ok(j.camera.position.x > 0.2, "tecla de volta para o direito (%.2f)" % j.camera.position.x)
	ok(load("res://jogador/teclas.gd").codigo("ombro") == "m:%d" % MOUSE_BUTTON_MIDDLE, "tecla padrão: botão do meio do mouse")
	print("falhas: ", falhas)
	quit()
