extends SceneTree
# TESTE (sem tela): 1.01 · ATRASO QUE SE ADAPTA (rede/jogador_remoto.gd _nova_amostra). Pacotes no ritmo (15/s):
# o atraso fica no mínimo (0,12 s). Pacotes chegando fora do ritmo (rede ruim): o atraso sobe (até 0,3 s). As
# amostras ficam sempre em ordem, mesmo quando o atraso volta a diminuir.
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)

func _initialize():
	var R = load("res://rede/jogador_remoto.gd").new()
	for k in 60:
		R._relogio = k / 15.0
		R._nova_amostra(Vector3(k, 0, 0), 0.0)
	ok(absf(R.atraso - R.ATRASO) < 0.01, "rede boa (15/s certinho): atraso no mínimo (%.3f s)" % R.atraso)
	var t := 60.0 / 15.0
	for k in 60:
		t += 1.0 / 15.0 + (0.12 if k % 3 == 0 else -0.04)        # chegam em rajadas e com buracos
		R._relogio = t
		R._nova_amostra(Vector3(k, 0, 0), 0.0)
	ok(R.atraso > 0.2 and R.atraso <= R.ATRASO_MAX, "rede ruim (pacotes fora do ritmo): o atraso sobe (%.3f s)" % R.atraso)
	var ordem := true
	for i in range(1, R._amostras.size()):
		if float(R._amostras[i][0]) <= float(R._amostras[i - 1][0]):
			ordem = false
	for k in 80:
		t += 1.0 / 15.0
		R._relogio = t
		R._nova_amostra(Vector3(k, 0, 0), 0.0)
		if float(R._amostras[-1][0]) <= float(R._amostras[-2][0]):
			ordem = false
	ok(ordem, "as amostras ficam sempre em ordem")
	ok(R.atraso < 0.2, "a rede melhorou: o atraso volta a cair (%.3f s)" % R.atraso)
	R.free()
	print("falhas: ", falhas)
	quit()
