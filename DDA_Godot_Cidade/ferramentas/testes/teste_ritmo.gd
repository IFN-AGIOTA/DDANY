extends SceneTree
# TESTE (sem tela, sem carregar o jogo): 1.00 · RITMO ESTÁVEL (menu/aplicar_opcoes.gd _vigiar_ritmo). No celular, sem
# limite escolhido, se nem com a resolução no mínimo ele segura 60 FPS por 3 conferências seguidas, trava em 45.
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)

func _initialize():
	var cfg = root.get_node("Config")
	var cap0 = cfg.g.get("cap", 0)
	var fps0 := Engine.max_fps
	cfg.g["cap"] = 0
	var A = load("res://menu/aplicar_opcoes.gd").new()
	A._dinamica = 0.6
	A._vigiar_ritmo(40.0, false)
	A._vigiar_ritmo(40.0, false)
	A._vigiar_ritmo(40.0, false)
	ok(not A.ritmo_estavel, "no PC nunca trava em 45 sozinho")
	A._dinamica = 0.9
	for i in 5:
		A._vigiar_ritmo(40.0, true)
	ok(not A.ritmo_estavel, "celular com a resolução ainda alta: primeiro baixa a resolução")
	A._dinamica = 0.6
	A._vigiar_ritmo(40.0, true)
	A._vigiar_ritmo(55.0, true)
	A._vigiar_ritmo(40.0, true)
	A._vigiar_ritmo(40.0, true)
	ok(not A.ritmo_estavel, "uma conferência boa no meio zera a contagem")
	A._vigiar_ritmo(40.0, true)
	ok(A.ritmo_estavel and Engine.max_fps == 45, "3 seguidas abaixo de 50 com a resolução no mínimo: trava em 45 (%d)" % Engine.max_fps)
	var B = load("res://menu/aplicar_opcoes.gd").new()
	cfg.g["cap"] = 30
	B._dinamica = 0.6
	for i in 5:
		B._vigiar_ritmo(20.0, true)
	ok(not B.ritmo_estavel, "quem escolheu um limite nas opções manda (não mexe)")
	cfg.g["cap"] = cap0
	Engine.max_fps = fps0
	A.free()
	B.free()
	print("falhas: ", falhas)
	quit()
