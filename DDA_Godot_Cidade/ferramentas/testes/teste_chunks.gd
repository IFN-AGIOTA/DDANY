extends SceneTree
# TESTE: 1.00 · CHUNKS COM ORÇAMENTO EM TEMPO (mundo/chunks.gd, estudos/ESTUDO_AAA.md 1.13). Andando de um chunk
# para o outro: cada quadro gasta pouco (pode parar no meio de um chunk) · no fim, todo chunk do raio tem todos os
# nós na cena e nenhum de fora ficou · com a mesma distância, o chunk da frente da câmera entra antes do de trás ·
# trocar de chunk no meio de um carregamento não deixa chunk pela metade.
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

func _conferir(ch) -> Array:
	# [nós que deviam estar na cena e não estão, nós que estão sem nenhum chunk carregado]
	var faltam := 0
	var sobram := 0
	for k in ch._chunks:
		var carregado: bool = ch._carregados.has(k)
		for n in ch._chunks[k]:
			if not is_instance_valid(n):
				continue
			if carregado and not n.is_inside_tree():
				faltam += 1
	for n in ch._cont:
		if is_instance_valid(n) and int(ch._cont[n]) == 0 and n.is_inside_tree():
			sobram += 1
	return [faltam, sobram]

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var ch = m.chunks
	var j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.ativo = false
	await q(30)
	ok(ch._fila.is_empty(), "no começo está tudo em dia")
	# anda 1 chunk para leste (o carregamento normal, no orçamento de tempo)
	var p0: Vector3 = j.global_position
	ch.us_maior = 0
	var p1 := p0 + Vector3(ch.TAM_CHUNK, 0, 0)
	m.mundo.forcar(Vector2(p1.x, p1.z))
	j.global_position = Vector3(p1.x, m.mundo.altura(p1.x, p1.z) + 0.2, p1.z)
	var quadros := 0
	var no_meio := false
	while (quadros < 5 or not ch._fila.is_empty()) and quadros < 600:
		await process_frame
		quadros += 1
		if not ch._fila.is_empty() and (ch._fila[0] as Array).size() > 2 and int(ch._fila[0][2]) > 0 and int(ch._fila[0][2]) < (ch._chunks[ch._fila[0][0]] as Array).size():
			no_meio = true
	print("  1 chunk andando: %d quadros, quadro mais caro %.2f ms (orçamento %.1f ms)" % [quadros, ch.us_maior / 1000.0, ch.ORCAMENTO_US / 1000.0])
	ok(ch.us_maior < ch.ORCAMENTO_US * 4, "cada quadro gasta pouco tirando/pondo nós (%.2f ms)" % (ch.us_maior / 1000.0))
	var c1: Array = _conferir(ch)
	ok(c1[0] == 0 and c1[1] == 0, "no fim nada falta e nada sobra (faltam %d, sobram %d)" % c1)
	# ordem: com a mesma distância, a frente da câmera primeiro
	ch._dir = Vector2(0, -1)                         # olhando para o norte (-Z)
	var c := Vector2i(floori(p1.x / ch.TAM_CHUNK), floori(p1.z / ch.TAM_CHUNK))
	var salvo: Dictionary = ch._carregados.duplicate()
	ch._carregados.erase(c + Vector2i(0, -1))
	ch._carregados.erase(c + Vector2i(0, 1))
	ch._refazer_fila(c)
	var ordem: Array = []
	for it in ch._fila:
		if it[1]:
			ordem.append(it[0])
	ok(ordem.size() >= 2 and ordem.find(c + Vector2i(0, -1)) < ordem.find(c + Vector2i(0, 1)), "o chunk da frente entra antes do de trás (%s)" % [ordem])
	ch._fila.clear()
	ch._carregados = salvo
	ch.forcar(j.global_position)
	await q(3)
	# trocar de chunk no meio de um carregamento
	var p2 := p1 + Vector3(ch.TAM_CHUNK, 0, 0)
	j.global_position = Vector3(p2.x, m.mundo.altura(p2.x, p2.z) + 0.2, p2.z)
	await process_frame
	await process_frame
	var p3 := p2 + Vector3(0, 0, ch.TAM_CHUNK)
	j.global_position = Vector3(p3.x, m.mundo.altura(p3.x, p3.z) + 0.2, p3.z)
	var esp := 0
	while (esp < 5 or not ch._fila.is_empty()) and esp < 600:
		await process_frame
		esp += 1
	var c2: Array = _conferir(ch)
	ok(c2[0] == 0 and c2[1] == 0, "trocou de chunk no meio do carregamento: nada pela metade (faltam %d, sobram %d)" % c2)
	j.global_position = Vector3(p0.x, m.mundo.altura(p0.x, p0.z) + 0.2, p0.z)
	print("falhas: ", falhas)
	quit()
