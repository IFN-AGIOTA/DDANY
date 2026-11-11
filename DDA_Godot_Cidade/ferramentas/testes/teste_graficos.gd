extends SceneTree
# TESTE: OPÇÕES DE GRÁFICOS QUE ESTAVAM "EM BREVE" (0.84) — cada uma muda alguma coisa de verdade no jogo:
#   texturas e filtragem anisotrópica (shader do chão), modelos (alcance dos objetos da rua), efeitos (fumaça no
#   horizonte e poeira/marcas dos tiros), fios de poste e (1.15) a cidade sem energia: nenhum halo de luz
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

func _aplicar(m, mudar: Dictionary) -> void:
	var g: Dictionary = root.get_node("Config").g.duplicate()
	for k in mudar:
		g[k] = mudar[k]
	root.get_node("Config").aplicar_graficos(g)

func _r():
	await q(20)
	var m = current_scene
	m._jogar()
	await q(30)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	m.vagos.ativo = false
	var cid = m.cidade
	var ab = cid.abandono
	var LR = load("res://mundo/luzes_rua.gd")
	# ---- texturas e anisotrópica ----
	await _aplicar(m, {"tex": 0, "aniso": 1})
	await q(2)
	var m0: ShaderMaterial = cid.mats_chao[0]
	var v0: float = m0.get_shader_parameter("vies_tex")
	await _aplicar(m, {"tex": 3, "aniso": 16})
	await q(2)
	ok(v0 > 1.0 and float(m0.get_shader_parameter("vies_tex")) == 0.0 and float(m0.get_shader_parameter("aniso")) == 16.0,
		"texturas/anisotrópica mudam o shader do chão (vies %.1f -> %.1f, aniso %s)" % [v0, m0.get_shader_parameter("vies_tex"), m0.get_shader_parameter("aniso")])
	# ---- modelos ----
	var no = null
	for n in ab.nos:
		if n.name.begins_with("sedan") and n.visibility_range_end > 0.0:
			no = n
			break
	await _aplicar(m, {"models": 0})
	await q(2)
	var a0: float = no.visibility_range_end
	await _aplicar(m, {"models": 3})
	await q(2)
	ok(a0 > 0.0 and no.visibility_range_end > a0 * 2.0, "modelos: alcance dos carros %.0f -> %.0f m" % [a0, no.visibility_range_end])
	# ---- 1.00: leitura do prédio (sem entrada = térreo com portas de aço, no 4º dado do shader PREDIO) ----
	var certos := 0
	var conferidos := 0
	var n_fechados := 0
	for info in cid.predio_info:
		if info["ruina"] or int(info["idx"]) < 0 or not cid._mm_predios.has(info["bloco"]):
			continue
		var mmp: MultiMesh = cid._mm_predios[info["bloco"]]
		var w: float = mmp.get_instance_custom_data(int(info["idx"])).a
		var fech := fposmod(w, 1.0) >= 0.5
		conferidos += 1
		if fech:
			n_fechados += 1
		if fech == (not info["entra"]) and floori(w) == int(info["tipo"]) and absf(fposmod(fposmod(w, 1.0) * 2.0, 1.0) - float(info["sem"])) < 0.02:      # (o dado vai em meia precisão)
			certos += 1
		if conferidos >= 4000:
			break
	# 1.17: os prédios FECHADOS saíram da cidade: todo prédio inteiro que ficou dá para entrar (térreo aberto)
	ok(conferidos > 1000 and certos == conferidos and n_fechados == 0, "só ficam prédios com entrada: térreo aberto e dado certo (%d de %d certos, %d fechados)" % [certos, conferidos, n_fechados])
	var sem_entrada := 0
	for info in cid.predio_info:
		if not info["ruina"] and not info["entra"]:
			sem_entrada += 1
	var fechados_fora := int(cid.removidos.get("fechado", -1))
	ok(sem_entrada == 0 and fechados_fora > 3000, "1.17: nenhum prédio inteiro sem entrada (%d); %d fechados saíram" % [sem_entrada, fechados_fora])
	# jogo salvo da 1.15..1.16: remapa_v7 leva os números de antes para os de agora (os fechados viram -1), em ordem
	var r7: PackedInt32Array = cid.remapa_v7
	var menos7 := 0
	var ult7 := -1
	var cresce7 := true
	for v in r7:
		if v < 0:
			menos7 += 1
		else:
			cresce7 = cresce7 and v == ult7 + 1
			ult7 = v
	var pontos_fora := int(cid.removidos.get("ponto", 0))          # 1.21: os dos pontos turísticos também saem
	ok(r7.size() == cid.predio_info.size() + fechados_fora + pontos_fora and menos7 == fechados_fora + pontos_fora and cresce7 and ult7 == cid.predio_info.size() - 1,
		"remapa_v7: %d prédios da 1.16 -> %d agora (%d saíram: %d fechados + %d dos pontos turísticos), em ordem e sem buraco" % [r7.size(), cid.predio_info.size(), menos7, fechados_fora, pontos_fora])
	ok(load("res://menu/salvamento.gd").MAPA_PREDIOS == 9, "MAPA_PREDIOS = 9 (saves da 1.15/1.16 e da 1.17..1.20 são convertidos)")
	# um save da 1.16 com loot num prédio que ficou e num fechado que saiu: o primeiro muda de número, o segundo some
	var Sv = load("res://menu/salvamento.gd")
	var ficou := -1
	var saiu := -1
	for k in r7.size():
		if r7[k] >= 0 and r7[k] != k and ficou < 0:
			ficou = k
		if r7[k] < 0 and saiu < 0:
			saiu = k
	var velho_save := {"grades": {"p%d_0" % ficou: {"itens": []}, "p%d_1" % saiu: {"itens": []}}, "portas": {"p%d:0" % ficou: 1}}
	var conv: Dictionary = Sv._remapear_loot(velho_save, Sv._remapa_de(m, 7))
	ok(ficou >= 0 and saiu >= 0 and conv["grades"].has("p%d_0" % r7[ficou]) and conv["grades"].size() == 1 and conv["portas"].has("p%d:0" % r7[ficou]),
		"save da 1.16: loot do prédio %d vai para o %d; o do fechado %d some" % [ficou, r7[ficou] if ficou >= 0 else -1, saiu])
	# ---- 1.19: nada em pé no meio do asfalto; nenhuma árvore (só os lugares guardados) ----
	var no_asf := 0
	for nome in ab._inst:
		if nome in ab.FORA_DO_ASFALTO:
			for kk in ab._inst[nome]:
				for e in ab._inst[nome][kk]:
					var tr: Transform3D = e[0]
					if tr.basis.y.normalized().y > 0.9 and cid.no_asfalto(tr.origin.x, tr.origin.z):
						no_asf += 1
	var tirados := 0
	for nome in ab.tirados_na_rua:
		tirados += int(ab.tirados_na_rua[nome])
	ok(no_asf == 0 and tirados > 500, "1.19: nada em pé no asfalto (%d) · saíram do meio da rua %d" % [no_asf, tirados])
	# 1.20: as árvores voltaram (EZ-Tree, mundo/arvores.gd) nos lugares guardados; as antigas (Quaternius) não
	var nos_antigos := 0
	var longe := 0
	for nd in cid.find_children("*", "GeometryInstance3D", true, false):
		var nm := str(nd.name)
		if nm.begins_with("arvore") or nm.begins_with("Veg_arvore") or nm.begins_with("Veg_pinheiro"):
			nos_antigos += 1
		elif nm.begins_with("ArvoresLonge_") or nm.begins_with("ArvoresPerto") or nm == "ArvoresUnica":
			longe += 1                            # (os nós antigos: a 1.23 tirou a chamada única do mundo inteiro)
	var lug: Array = cid.lugares_das_arvores()
	# 1.23: em grupos por chunk (até 3 desenhos por grupo, cada um com a caixa de verdade, nenhum do tamanho do mundo)
	var grupos_ok := cid.arvores != null and cid.arvores._g_chave.size() > 50
	var caixa_max := 0.0
	if cid.arvores != null:
		for cx in cid.arvores._g_caixa:
			caixa_max = maxf(caixa_max, maxf((cx as AABB).size.x, (cx as AABB).size.z))
	ok(nos_antigos == 0 and longe == 0 and grupos_ok and caixa_max < 700.0 and cid.arvores.quantas() > lug.size() and lug.size() > 10000
		and ResourceLoader.exists("res://data/arvores_lugares.json"),
		"1.20/1.23: árvores novas plantadas (%d; %d lugares guardados), em %d grupos por chunk (maior caixa %.0f m), nenhuma das antigas" % [cid.arvores.quantas() if cid.arvores != null else 0, lug.size(), cid.arvores._g_chave.size() if cid.arvores != null else 0, caixa_max])
	ok(not ResourceLoader.exists("res://mundo/cenario/natureza/CommonTree_1.gltf") and not ResourceLoader.exists("res://historia/historia.gd"),
		"1.19: arquivos das árvores e do modo história apagados")
	# ---- halos (1.16: os fios de poste saíram, e a opção também) ----
	var halos: Array = get_nodes_in_group("halos_luz")
	print("  blocos com halos %d · halos %d" % [ab.nos_halos.size(), ab.halos.size()])
	ok(get_nodes_in_group("fios_poste").is_empty() and ab.get("fios") == null and ab.get("nos_fios") == null, "1.16: sem fios entre os postes")
	ok(not ("wire" in load("res://menu/config.gd").GFX_PRESETS["auto"]), "1.16: a opção \"Fios de poste\" saiu dos presets")
	# 1.15: a cidade está sem energia: nenhum poste, semáforo ou ponte acende; nem velas nas janelas dos prédios
	ok(ab.nos_halos.is_empty() and halos.is_empty(), "sem energia: nenhum halo de poste, semáforo ou ponte (%d)" % halos.size())
	var velas = m.cidade.mat_predio.get_shader_parameter("velas")
	ok(velas == null or float(velas) == 0.0, "sem velas nas janelas dos prédios comuns")
	# ---- efeitos ----
	var fu = m.jogo.get_node("Fumaca")
	await _aplicar(m, {"fx": 0})
	await q(2)
	var vis0 := 0
	for c in fu.get_children():
		if c.visible:
			vis0 += 1
	var ef = m.jogador.armas.efeitos
	var nfx0: int = ef.nivel_fx
	await _aplicar(m, {"fx": 3})
	await q(2)
	var vis3 := 0
	for c in fu.get_children():
		if c.visible:
			vis3 += 1
	ok(vis0 == 0 and vis3 == fu.colunas and nfx0 == 0 and ef.nivel_fx == 3, "efeitos: fumaça no horizonte %d -> %d colunas · tiros %d -> %d" % [vis0, vis3, nfx0, ef.nivel_fx])
	# foto de noite numa rua (halos, fios e o chão com anisotrópica)
	if OS.get_environment("FOTO") != "":
		var e: Array = ab.halos[ab.halos.size() / 3]
		var p: Vector3 = e[0]
		m.mundo.forcar(Vector2(p.x, p.z))
		m.jogador.teleportar(Vector3(p.x + 8.0, m.mundo.altura(p.x + 8.0, p.z) + 0.1, p.z), 0.0)
		await q(60)
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.far = 900.0
		cam.make_current()
		cam.global_position = p + Vector3(25, -4.0, 12)
		cam.look_at(p + Vector3(0, -3.0, 0))
		await q(10)
		root.get_texture().get_image().save_png(OS.get_environment("FOTO") + "_noite.png")
		m.clima.definir_hora(12.0)
		await q(70)
		root.get_texture().get_image().save_png(OS.get_environment("FOTO") + "_dia.png")
		cam.global_position = p + Vector3(6, -5.5, 6)
		cam.look_at(p + Vector3(-60, -7.0, -40))
		for af in [1, 16]:
			await _aplicar(m, {"aniso": af, "tex": 3})
			await q(6)
			root.get_texture().get_image().save_png(OS.get_environment("FOTO") + "_chao_%d.png" % af)
	print("falhas: ", falhas)
	quit()
