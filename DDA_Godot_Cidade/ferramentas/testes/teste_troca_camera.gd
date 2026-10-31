extends SceneTree
# TESTE: TROCAR DE CÂMERA NÃO TRAVA (0.89). Trocar 1ª/3ª pessoa (F) e de ombro (botão do meio) só mexe na câmera:
# antes reaplicava TODAS as opções (texturas, modelos, luzes, chunks...) e o jogo dava uma travada a cada troca.
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

func _medir(f: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	f.call()
	return (Time.get_ticks_usec() - t0) / 1000.0

func _r():
	var Config = root.get_node("Config")
	await q(20)
	var m = current_scene
	m._jogar()
	await q(60)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var j = m.jogador
	await q(30)
	var pior := 0.0
	for i in 4:
		pior = maxf(pior, _medir(func(): j.alternar_camera()))
		await q(20)
		pior = maxf(pior, _medir(func(): j.trocar_ombro()))
		await q(20)
	var gfx := _medir(func(): Config.aplicar_graficos(Config.g))
	print("  troca de câmera/ombro: pior %.1f ms · reaplicar os gráficos: %.1f ms" % [pior, gfx])
	ok(pior < 4.0, "trocar de câmera ou de ombro leva menos de 4 ms (%.1f ms)" % pior)
	ok(j.primeira_pessoa == false and int(Config.o.get("cam", 0)) == 0, "voltou para a 3ª pessoa depois de 4 trocas")
	j.alternar_camera()
	await q(5)
	ok(j.primeira_pessoa, "a troca ainda liga a 1ª pessoa")
	j.alternar_camera()
	print("falhas: ", falhas)
	quit()
