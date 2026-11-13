extends SceneTree
# TESTE: 1.00 · ABRIR PRÉDIO AOS POUCOS (mundo/interiores.gd FATIA_US, mundo/interior.gd tarefas). Para os mesmos
# prédios: montar tudo de uma vez x montar em fatias (o jeito do jogo andando pela cidade). No fim os dois têm as
# mesmas portas, janelas e caixas de loot; aos poucos, o quadro mais pesado fica bem mais leve; a colisão não usa
# mais um nó para cada caixa (centenas de nós a menos); fechar no meio da montagem não perde o loot do chão.
# O mesmo prédio abre sempre com os mesmos móveis (antes o embaralhar usava o sorteio global).
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

func _contar(no: Node) -> Dictionary:
	var c := {"porta": 0, "janela": 0, "caixa": 0, "forma": 0, "nos": 0, "chao": 0, "onde": 0}
	for x in no.find_children("*", "", true, false):
		c["nos"] += 1
		if x is CollisionShape3D and x.get_parent().name == "Colisao":
			c["forma"] += 1                   # (as das portas e janelas continuam: elas se mexem)
		var s = x.get_script()
		if s != null:
			var f: String = s.resource_path.get_file()
			if f == "porta.gd": c["porta"] += 1
			elif f == "janela.gd": c["janela"] += 1
			elif f == "caixa_mundo.gd":
				c["caixa"] += 1
				c["onde"] += int(round(((x as Node3D).position.x * 3.0 + (x as Node3D).position.z) * 10.0))
			elif f == "item_mundo.gd": c["chao"] += 1
	return c

# abre "aos poucos" como o _process do jogo: espera a thread e chama _terminar (que monta em fatias)
func _abrir_fatiado(it, i: int, esperar_fim := true) -> void:
	it.abrir(i)
	while it._tarefa >= 0 and not WorkerThreadPool.is_task_completed(it._tarefa):
		await process_frame
	if it._tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(it._tarefa)
	var res = it._tarefa_res
	it._tarefa = -1
	it._tarefa_res = null
	it._terminar(i, res)
	while esperar_fim and it._montando >= 0:
		await process_frame

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var it = m.interiores
	var c = m.cidade
	var base := Vector2(436, 1500)
	m.mundo.forcar(base)
	m.jogador.teleportar(Vector3(base.x, m.mundo.altura(base.x, base.y) + 0.1, base.y), 0.0)
	await q(60)
	it.ativo = false                         # só o teste abre e fecha
	it.fechar_todos()
	await q(5)
	var lista: Array = []
	for i in c.predio_info.size():
		var inf: Dictionary = c.predio_info[i]
		if inf["entra"] and not inf["ruina"] and Vector2(inf["x"] - base.x, inf["z"] - base.y).length() < 300.0:
			lista.append(i)
		if lista.size() >= 5:
			break
	var soma_junto := 0.0
	var maior_fatiado := 0.0
	var iguais := true
	var sem_formas := true
	var nos_max := 0
	for i in lista:
		# 1) tudo de uma vez
		it.usar_fatias = false
		it.abrir(i, true)
		var t_junto: float = it.ms_ultimo
		var a: Dictionary = _contar(it.abertos[i])
		it.fechar(i)
		await q(3)
		# 2) aos poucos (thread + fatias), como no jogo
		it.usar_fatias = true
		it.ms_maior_fatia = 0.0
		await _abrir_fatiado(it, i)
		var b: Dictionary = _contar(it.abertos[i]) if it.abertos.has(i) else {}
		var pior: float = maxf(it.ms_ultimo, it.ms_maior_fatia)
		print("  prédio %d: junto %.1f ms · aos poucos: 1º quadro %.1f ms, maior fatia %.1f ms · junto %s · aos poucos %s" % [i, t_junto, it.ms_ultimo, it.ms_maior_fatia, a, b])
		soma_junto += t_junto
		maior_fatiado = maxf(maior_fatiado, pior)
		for k in ["porta", "janela", "caixa", "chao", "onde"]:
			if b.get(k, -1) != a[k]:
				iguais = false
		if a["forma"] > 0 or b.get("forma", 1) > 0:
			sem_formas = false
		nos_max = maxi(nos_max, int(b.get("nos", 0)))
		it.fechar(i)
		await q(3)
	var media_junto := soma_junto / lista.size()
	ok(lista.size() == 5 and iguais, "aos poucos termina com as mesmas portas, janelas e caixas de loot, nos mesmos lugares (o prédio sai sempre igual)")
	ok(maior_fatiado < media_junto * 0.75, "o quadro mais pesado aos poucos (%.1f ms) é bem mais leve que montar de uma vez (média %.1f ms)" % [maior_fatiado, media_junto])
	# (1.06: a numeração dos prédios mudou e a amostra trouxe um prédio com 158 caixas de loot, cada uma um nó: 469)
	ok(sem_formas and nos_max < 520, "colisão sem um nó por caixa (no máximo %d nós por prédio; antes ~900)" % nos_max)
	# fechar no meio da montagem: o loot do chão não é "guardado vazio"
	var i2: int = lista[0]
	it.abrir(i2, true)
	var chao0: int = _contar(it.abertos[i2])["chao"]
	it.fechar(i2)
	await q(3)
	it.usar_fatias = true
	await _abrir_fatiado(it, i2, false)
	var montando: bool = it._montando == i2 and it._sem_chao.has(i2)
	it.fechar(i2)
	await q(5)
	it.abrir(i2, true)
	var chao1: int = _contar(it.abertos[i2])["chao"]
	print("  fechou no meio da montagem: %s · itens no chão antes %d, depois %d" % [montando, chao0, chao1])
	ok(montando and chao1 == chao0, "fechar no meio da montagem não perde o loot do chão (%d -> %d)" % [chao0, chao1])
	ok(not it._sem_chao.has(i2) and it._montando == -1, "e não deixa a montagem pendurada")
	print("falhas: ", falhas)
	quit()
