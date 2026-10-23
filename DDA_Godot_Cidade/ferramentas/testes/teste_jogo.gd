extends SceneTree
# TESTE GERAL DO JOGO (0.74): pistola, recarga, encher pente, silenciador, desmontar, corpo a corpo, mordida,
# atadura, comer, salvar/carregar o inventário, morrer e renascer. Imprime "falhas: N" no fim.
# Rodar: ferramentas/testes/rodar.sh (ou godot --rendering-driver opengl3 -s res://ferramentas/testes/teste_jogo.gd)
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c:
		print("  ok   ", msg)
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
	var j = m.jogador
	var inv = j.inventario
	var ar = j.armas
	var I = load("res://inventario/item.gd")
	ok(ar.atual == "pistola", "começa com pistola (" + ar.atual + ")")
	ok(ar.item_arma.pente_id == "pente_pistola" and ar.item_arma.municao == 12, "pistola com pente cheio")
	# atira 12 vezes
	ar.item_arma.municao = 0
	ar.recarregar()
	ok(ar._pente_novo != null, "recarga achou pente cheio no bolso")
	await q(90)
	ok(ar.item_arma.municao == 12, "trocou o pente (" + str(ar.item_arma.municao) + ")")
	var vazio = null
	for g in inv.grades_do_jogador():
		for o in g.itens:
			if o.id == "pente_pistola":
				vazio = o
	ok(vazio != null and vazio.municao == 0, "pente vazio voltou para o bolso")
	inv.usar(vazio)
	var t_ench := Time.get_ticks_msec()
	while vazio.municao < 12 and Time.get_ticks_msec() - t_ench < 15000:
		await process_frame                  # 0.65: o pente enche bala por bala, com tempo
	ok(vazio.municao == 12, "ENCHER pente com munição solta (" + str(vazio.municao) + ")")
	# silenciador
	var sil = I.novo("silenciador")
	ok(inv.pode_combinar(sil, ar.item_arma), "silenciador encaixa na pistola")
	var jaq = inv.slots["camisa"]
	jaq.conteudo.colocar(sil, 5, 3, false)
	inv.combinar(sil, ar.item_arma)
	ok(ar.item_arma.acessorios.get("cano") == "silenciador", "silenciador encaixado")
	ok(ar.nos["pistola"].get_node("Acc_cano").visible, "silenciador aparece no modelo")
	# desmontar
	inv.desmontar(ar.item_arma)
	ok(ar.item_arma.pente_id == "" and ar.item_arma.acessorios.is_empty(), "desmontou")
	# corpo a corpo: mãos vazias
	inv.desequipar(inv.slots["maos"])
	await q(3)
	ok(ar.atual == "punhos", "mãos vazias = punhos (" + ar.atual + ")")
	var faca = null
	for g in inv.grades_do_jogador():
		for o in g.itens:
			if o.id == "faca":
				faca = o
	inv.equipar(faca, "maos")
	await q(3)
	ok(ar.atual == "faca", "faca na mão")
	await q(10)
	ar._pend = true
	ar._pend_t = 0.35
	await q(3)
	ok(ar.golpe > 0.0 or ar.since < 1.0, "golpe de faca")
	await q(30)
	# sobrevivência
	var sv = j.sobrevivencia
	var f0: float = sv.fome
	j.receber_ataque(12.0, 1.0, Vector3.ZERO)
	ok(sv.vida < 100.0 and sv.sangramentos >= 0, "levou mordida: vida %.1f sangr %d" % [sv.vida, sv.sangramentos])
	sv.sangramentos = 1
	var band = I.novo("bandagem", 2)
	jaq.conteudo.colocar(band, 0, 3, false)
	inv.usar(band)
	ok(sv.sangramentos == 0, "atadura estancou")
	var lata = I.novo("feijao")
	sv.fome = 20.0
	jaq.conteudo.colocar(lata, 4, 0, false)
	inv.usar(lata)
	ok(sv.fome > 50.0, "comeu: fome %.0f" % sv.fome)
	# salvar/carregar inventário
	var d: Dictionary = inv.salvar()
	var txt := JSON.stringify(d)
	inv.carregar(JSON.parse_string(txt))
	ok(inv.slots["camisa"] != null and inv.slots["camisa"].conteudo.itens.size() > 0, "inventário salvo e carregado")
	# morte
	sv.vida = 1.0
	j.receber_ataque(50.0, 0.0, Vector3.ZERO)
	await q(10)
	ok(j.morto, "morreu")
	await create_timer(3.0).timeout
	ok(m.tela_morte != null, "tela de morte")
	m._renascer()
	await q(10)
	ok(not j.morto and inv.slots["camisa"] != null and inv.slots["camisa"].id == "camiseta", "renasceu com camiseta")
	print("FPS ", Engine.get_frames_per_second(), " · falhas: ", falhas)
	quit()
