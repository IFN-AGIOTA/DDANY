extends SceneTree
# TESTE (sem tela, sem carregar o jogo): 1.00 · VALIDAR NO HOST (rede/sessao_rede.gd dano_valido). Pedido de dano de
# um amigo só vale se ele estava perto o bastante, o dano cabe numa arma de verdade e não veio pedido demais.
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)

func _initialize():
	var S = load("res://rede/sessao_rede.gd").new()
	var a := Vector3(100, 0, 100)
	ok(S.dano_valido(2, a, a + Vector3(0, 0, 60), false, 34.0), "tiro de pistola a 60 m: vale")
	ok(S.dano_valido(2, a, a + Vector3(0, 0, 440), false, 285.0), "rifle na cabeça a 440 m: vale")
	ok(not S.dano_valido(2, a, a + Vector3(0, 0, 900), false, 34.0), "tiro a 900 m (mais que qualquer arma): jogado fora")
	ok(not S.dano_valido(2, a, a + Vector3(0, 0, 10), false, 5000.0), "dano 5000: jogado fora")
	ok(S.dano_valido(2, a, a + Vector3(2, 0, 1), true, 85.0), "machadada a 2 m: vale")
	ok(not S.dano_valido(2, a, a + Vector3(0, 0, 20), true, 46.0), "golpe a 20 m (não alcança): jogado fora")
	ok(not S.dano_valido(3, Vector3.INF, a, false, 20.0), "de quem não está na partida: jogado fora")
	var antes: int = S.rejeitados
	var aceitos := 0
	for i in 60:
		if S.dano_valido(4, a, a + Vector3(0, 0, 30), false, 21.0):
			aceitos += 1
	ok(aceitos < 60 and aceitos <= S.MAX_PEDIDOS_S * 2 and S.rejeitados > antes, "60 pedidos no mesmo segundo: só %d valem" % aceitos)
	S.free()
	print("falhas: ", falhas)
	quit()
