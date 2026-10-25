extends SceneTree
# TESTE: JOGADOR MUTADO (0.94). Chance de 1% só nas mortes pelos infectados; levanta mutado no mesmo lugar com tudo;
# garras no lugar dos punhos, arma de fogo travada; os infectados param de caçar e não atacam; mais rápido; corpo
# escuro e curvado; bit 512 na rede; vai no jogo salvo; os NPCs do hospital não negociam; morrer de novo = humano.
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
func seg(s: float):
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await process_frame

func _r():
	var Mut = load("res://jogador/mutacao.gd")
	# chance
	var n := 0
	for i in 200000:
		if Mut.sorteia("infectados", 0):
			n += 1
	ok(n > 1600 and n < 2400, "chance de ~1%% (%d em 200000)" % n)
	var outros := 0
	for i in 5000:
		if Mut.sorteia("queda", 0) or Mut.sorteia("baleado por X", 0) or Mut.sorteia("infectados", 1):
			outros += 1
	ok(outros == 0, "queda, tiro e quem já é mutado nunca mutam")
	await q(20)
	var m = current_scene
	m._jogar()
	await q(40)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var j = m.jogador
	var s = j.sobrevivencia
	s.imortal = true
	m.vagos.max_ativos = 0
	m.clima.parado = true
	m.clima.hora = 13.0
	ok(j.armas.atual == "pistola" and not j.mutado, "começa humano, com a pistola")
	var peso_antes: float = j.inventario.peso_total()
	# infectado na frente: caça o humano
	var frente: Vector3 = -j.global_basis.z
	var v = m.vagos._criar(j.global_position + frente * 6.0 + Vector3(0, 0.05, 0), Vector3.INF)
	await q(5)
	v._alertar(j)                                      # o jogador fez barulho perto dele
	await seg(1.0)
	ok(v != null and v.esta_cacando(), "humano: o infectado caça (estado %s)" % (str(v.estado) if v != null else "?"))
	# morre pelos infectados com a mutação forçada
	Mut.forcar = true
	s.imortal = false
	s._morrer("infectados")
	await q(5)
	ok(j.morto and m.tela_morte == null, "caído, sem tela de morte")
	await seg(Mut.TEMPO_LEVANTAR + 1.0)
	ok(not j.morto and s.mutacao == 1 and j.mutado and s.vida >= 99.0, "levantou MUTADO (vida %.0f)" % s.vida)
	ok(peso_antes > 0.0 and absf(j.inventario.peso_total() - peso_antes) < 0.01, "ficou com tudo o que carregava (%.1f kg)" % peso_antes)
	ok(j.inventario.slots.get("maos") != null and j.armas.atual == "punhos", "a pistola continua na mão, mas travada (%s)" % j.armas.atual)
	ok(j.armas.nome_atual() == "GARRAS" and float(j.armas.def_corpo()["dano"]) >= 25.0, "punhos viraram GARRAS (dano %.0f)" % float(j.armas.def_corpo()["dano"]))
	# infectado: perde o interesse e não ataca
	var vida0: float = s.vida
	v.global_position = j.global_position + frente * 1.2
	await seg(5.0)
	ok(is_instance_valid(v) and not v.esta_cacando(), "mutado: o infectado não caça (estado %s)" % str(v.estado))
	ok(s.vida >= vida0 - 0.5, "mutado: o infectado não ataca (vida %.1f -> %.1f)" % [vida0, s.vida])
	ok(m.vagos.ignorado(j) and m.vagos.alvo_para(v) == j, "os infectados ignoram o mutado")
	var v2 = m.vagos._criar(j.global_position + frente * 2.0 + Vector3(0, 0.05, 0), Vector3.INF)
	await seg(3.0)
	ok(v2 != null and not v2.esta_cacando(), "infectado novo também não vê o mutado")
	# números
	ok(absf(j._mult_mut("vel") - 1.22) < 0.01 and absf(j._mult_mut("pulo") - 1.4) < 0.01, "corre e pula mais")
	s.vida = 100.0
	s._dano(10.0, "teste")
	ok(absf(s.vida - 95.5) < 0.01, "leva menos dano (10 -> %.1f)" % (100.0 - s.vida))
	s.pegar_virus()
	await q(5)
	ok(s.virus < 0.0, "não pega o vírus")
	# visual
	var mod = j._slot.get_node_or_null("Sobrevivente")
	ok(mod != null and float(mod._mat.get_shader_parameter("mutado")) > 0.99 and mod.mutado_camada.ligado, "corpo escuro, com veios e curvado")
	# rede e jogo salvo
	var ses = load("res://rede/sessao_rede.gd").new()
	ses.jogador = j
	ses.main = m
	var bits := int(ses.estado_local()[3])
	ses.free()
	ok(bits & 512 != 0, "bit 512 (mutado) no estado da rede")
	var dados: Dictionary = s.salvar()
	ok(int(dados.get("mutacao", 0)) == 1, "a mutação vai no jogo salvo")
	# hospital: não negociam
	var H = m.hospitais
	var Locais = load("res://mundo/locais.gd")
	var hi: int = H.hospitais()[0]
	var p2: Vector2 = Locais.local_para_mundo(hi, Vector2(0, -6.0))
	m.mundo.forcar(p2)
	m.locais.abrir_agora(p2)
	await q(5)
	j.teleportar(Vector3(p2.x, m.cidade.Y_CALCADA + 0.3, p2.y), 0.0)
	await q(30)
	var mon = null
	for nn in root.get_tree().get_nodes_in_group("npcs_hospital"):
		if nn.quem == "monica":
			mon = nn
	if mon != null:
		H.falar_com(mon)
		await q(3)
		ok(H.tela == null, "a Mônica não negocia com o mutado")
	# morrer de novo = volta humano
	s.imortal = false
	Mut.forcar = true                                   # mesmo forçado: quem já é mutado morre de verdade
	s._morrer("infectados")
	await seg(3.5)
	ok(m.tela_morte != null, "mutado morreu: tela de morte de verdade")
	Mut.forcar = false
	m._renascer()
	await q(10)
	ok(s.mutacao == 0 and not j.mutado and float(mod._mat.get_shader_parameter("mutado")) < 0.01, "renasceu HUMANO normal")
	s.carregar(dados)
	await q(5)
	ok(s.mutacao == 1 and float(mod._mat.get_shader_parameter("mutado")) > 0.99, "carregar o jogo salvo volta o mutado")
	print("[teste_mutado] falhas: ", falhas)
	print("TUDO CERTO" if falhas == 0 else "ALGUM TESTE FALHOU")
	quit()
