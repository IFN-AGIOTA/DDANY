extends SceneTree
# TESTE: MUNDOS DO MULTIJOGADOR (1.03, menu/mundos_rede.gd), num processo só (o aparelho é o host):
#   · o save antigo (um mundo só, 0.77-1.02) vira o mundo "Mundo salvo", com a mesma semente e o dia
#   · CRIAR SALA abre "Seus mundos": criar um mundo com nome abre a sala com ele (o nome vai para quem entra)
#   · tudo o que acontece no mundo A (personagem, onde estava, porta, item pego, base) fica nele; o mundo B começa do
#     zero; voltando ao A, está tudo lá; o nome repetido é recusado; APAGAR (dois toques) tira da lista
var falhas := 0
var Rede
var MR = load("res://menu/mundos_rede.gd")
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

var m

# abre a tela Multijogador > CRIAR SALA e devolve a tela
func _tela_mundos():
	m._abrir_multijogador()
	await q(5)
	var t = m.tela_multi
	t.modo = "mundos"
	t._montar()
	await q(3)
	return t

# começa a partida (o host toca COMEÇAR) e espera o jogo ficar pronto
func _comecar() -> void:
	var t0 := Time.get_ticks_msec()
	while not Rede.ligado and Time.get_ticks_msec() - t0 < 10000:
		await q(2)
	Rede.comecar_partida()
	await q(10)
	if m.jogo == null:
		m._jogar()
	while m.jogador == null or m.carregamento != null:
		await q(5)
	await q(60)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.vagos.max_ativos = 0

func _sair() -> void:
	m.salvar_jogo()
	m._abrir_menu()
	await q(20)

func _r():
	Rede = root.get_node("Rede")
	await q(30)
	m = current_scene
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	# começa limpo (só os mundos deste teste)
	for d in MR.lista():
		MR.apagar(str(d["id"]))
	MR.apagar("_antigo")

	# ---- 1. o save antigo vira um mundo ----
	var f := FileAccess.open("user://save_rede.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"versao": 1, "mundo": {"semente": 424242, "clima": {"dia": 4}, "loot": {}, "pegos": ["teste:velho"]},
		"personagem": {"tempo_jogo": 600.0}}))
	f.close()
	var l: Array = MR.lista()
	ok(l.size() == 1 and str(l[0]["nome"]) == "Mundo salvo" and int(l[0]["semente"]) == 424242 and int(l[0]["dia"]) == 4,
		"o mundo salvo das versões antigas aparece na lista como \"Mundo salvo\" (semente e dia iguais)")
	ok(not FileAccess.file_exists("user://save_rede.json") and FileAccess.file_exists("user://save_rede_antigo.json"),
		"o arquivo antigo fica guardado como cópia (não migra de novo)")
	MR.apagar(str(l[0]["id"]))

	# ---- 2. tela: CRIAR SALA > mundo novo com nome ----
	var t = await _tela_mundos()
	ok(t._nome_mundo != null and t._nome_mundo.placeholder_text == "Mundo 1", "CRIAR SALA abre \"Seus mundos\" com o campo do nome (sugere \"Mundo 1\")")
	t._nome_mundo.text = "Cidade dos Mortos"
	t._criar_mundo_novo()
	await _comecar()
	ok(str(Rede.mundo.get("mundo_nome", "")) == "Cidade dos Mortos" and str(Rede.mundo.get("mundo_id", "")) != "",
		"a sala abriu com o mundo \"Cidade dos Mortos\" (o nome e o id vão para quem entra)")
	var id_a := str(Rede.mundo["mundo_id"])
	var j = m.jogador
	var lm = m.loot_mundo
	ok(lm.semente == int(MR.ler(id_a)["semente"]), "a cidade usa a semente do mundo")
	# joga: fome, item, porta, item pego, lugar
	j.sobrevivencia.fome = 33.0
	var it = load("res://inventario/item.gd").novo("tabuas", 2)
	for g in j.inventario.grades_do_jogador():
		var v: Vector3i = g.achar_vaga(it)
		if v.x >= 0:
			g.colocar(it, v.x, v.y, v.z == 1)
			break
	lm.mudar_porta("p1:1", [true, 0, false, 1.0])
	lm.pegos["teste:7"] = true
	j.teleportar(j.global_position + Vector3(14.0, 0.2, 9.0), 0.0)
	await q(30)
	var onde_a: Vector3 = j.global_position
	await _sair()
	var da: Dictionary = MR.ler(id_a)
	ok(not da.is_empty() and bool(da["meu"]) and da.has("mundo") and da.has("personagem"), "saiu: o mundo A foi salvo (mundo e personagem)")

	# ---- 3. mundo B começa do zero ----
	t = await _tela_mundos()
	ok(t.get_node_or_null(".") != null and MR.lista().size() == 1, "a lista tem o mundo A")
	t._nome_mundo.text = "cidade dos mortos"
	t._criar_mundo_novo()
	ok(not Rede.ligado and MR.lista().size() == 1, "nome repetido é recusado (não cria outro \"Cidade dos Mortos\")")
	t._nome_mundo.text = "Segundo"
	t._criar_mundo_novo()
	await _comecar()
	var id_b := str(Rede.mundo["mundo_id"])
	j = m.jogador
	lm = m.loot_mundo
	ok(id_b != id_a and str(Rede.mundo["mundo_nome"]) == "Segundo", "o mundo \"Segundo\" é outro mundo")
	ok(j.sobrevivencia.fome > 60.0 and j.inventario.contar("tabuas") == 0 and not lm.portas.has("p1:1") and not lm.pegos.has("teste:7"),
		"no mundo B nada do A: fome %.0f, tábuas %d, porta %s, pego %s" % [j.sobrevivencia.fome, j.inventario.contar("tabuas"), lm.portas.has("p1:1"), lm.pegos.has("teste:7")])
	ok(j.global_position.distance_to(onde_a) > 5.0, "e começa na base (não no lugar onde parou no A)")
	j.sobrevivencia.fome = 77.0
	await _sair()

	# ---- 4. de volta ao A: tudo lá ----
	t = await _tela_mundos()
	var lista: Array = MR.lista()
	ok(lista.size() == 2 and str(lista[0]["nome"]) == "Segundo", "a lista mostra os 2 mundos (o jogado por último primeiro)")
	var md_a: Dictionary = MR.por_nome("Cidade dos Mortos")
	t._criar(md_a)
	await _comecar()
	j = m.jogador
	lm = m.loot_mundo
	ok(str(Rede.mundo["mundo_id"]) == id_a, "JOGAR no \"Cidade dos Mortos\" abre a sala com ele")
	ok(absf(j.sobrevivencia.fome - 33.0) < 1.5 and j.inventario.contar("tabuas") == 2,
		"o personagem do A voltou (fome %.1f, tábuas %d)" % [j.sobrevivencia.fome, j.inventario.contar("tabuas")])
	ok(lm.portas.has("p1:1") and lm.pegos.has("teste:7"), "o mundo do A voltou (porta aberta, item pego)")
	ok(j.global_position.distance_to(onde_a) < 1.0, "e ele está onde parou (%.2f m)" % j.global_position.distance_to(onde_a))
	await _sair()

	# ---- 5. apagar (dois toques) ----
	t = await _tela_mundos()
	var md_b: Dictionary = MR.por_nome("Segundo")
	t._apagar_id = str(md_b["id"])                  # 1º toque
	t._montar()
	await q(2)
	# 2º toque: o botão "Toque de novo" da linha do Segundo
	var apagou := false
	for b in t.find_children("*", "", true, false):
		if b.get("titulo") == "Toque de novo":
			b.apertado.emit()
			apagou = true
			break
	await q(2)
	ok(apagou and MR.por_nome("Segundo").is_empty() and not MR.por_nome("Cidade dos Mortos").is_empty(), "APAGAR com dois toques tira só aquele mundo")
	for d in MR.lista():
		MR.apagar(str(d["id"]))
	print("falhas: ", falhas)
	quit()
