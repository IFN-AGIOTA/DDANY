extends SceneTree
# TESTE: MOVIMENTO ESTILO MOTION MATCHING (1.12). Sem o jogo inteiro: o sobrevivente + o animador, tocando uma
# sequência de velocidades (parado -> andar devagar -> normal -> apressado -> trote -> correr -> andar -> parar) a 60 qps:
#   · a biblioteca (base_movimento_m/f.json) carrega com as 13 animações
#   · a busca escolhe animações certas para cada velocidade (parado, caminhadas, trote, corrida) e entra no MEIO do
#     passo quando precisa (não sempre do início)
#   · os PÉS dão menos TRANCO nas trocas que no jeito antigo (mudança brusca da velocidade do pé, na pose da tela)
#   · a inércia some sozinha; mirando na diagonal as pernas giram e o tronco fica na mira; correndo em curva inclina
#   · a busca é rápida (< 1 ms)
var falhas := 0
func ok(c: bool, msg: String) -> void:
	if c: print("  ok   ", msg)
	else:
		falhas += 1
		print("  FALHA ", msg)
func _initialize():
	_r.call_deferred()

const SEQ := [[0.0, 0.8], [1.0, 0.8], [1.6, 0.8], [2.2, 0.8], [3.4, 0.8], [6.4, 1.0], [1.6, 0.8], [0.0, 1.0]]

func _rodar(mm: bool, sexo := "m") -> Dictionary:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var s = load("res://jogador/modelo_sobrevivente.gd").new()
	s.aparencia = {"sexo": sexo}
	raiz.add_child(s)
	var an = load("res://jogador/animador_modelo.gd").new()
	raiz.add_child(an)
	an.configurar(s)
	an.nomes_exatos = s.NOMES_ANIM
	an.atualizar_mapa()
	an.usar_mm = mm
	await process_frame
	var sk: Skeleton3D = s.esqueleto
	var pe := [sk.find_bone("foot_l"), sk.find_bone("foot_r")]
	var pel := sk.find_bone("pelvis")
	# a pose que vai para a tela (com as camadas: inércia, orientação) só existe no fim da atualização do esqueleto
	var med := {"ant": [], "ant2": [], "tr": []}
	var medir := func():
		var p0 := sk.get_bone_global_pose(pel).origin
		var agora := []
		for b in pe:
			agora.append(sk.get_bone_global_pose(b).origin - Vector3(p0.x, 0, p0.z))
		# TRANCO: mudança brusca na velocidade do pé (p - 2·p_ant + p_ant2). O passo normal é suave; um "pulo" de
		# pose numa troca aparece como um pico
		var j := 0.0
		if not (med["ant2"] as Array).is_empty():
			for i in 2:
				j = maxf(j, (agora[i] - 2.0 * med["ant"][i] + med["ant2"][i]).length())
		(med["tr"] as Array).append(j)
		med["ant2"] = med["ant"]
		med["ant"] = agora
	sk.skeleton_updated.connect(medir)
	var nomes := {}
	var meio := 0
	var trocas := []
	var fr := 0
	var dt := 1.0 / 60.0
	for passo in SEQ:
		var v: float = passo[0]
		var n := int(passo[1] / dt)
		for k in n:
			an._dir = Vector2(0.0, v)
			var antes: String = an._nome_atual
			an.atualizar_estado(dt, v, true, 0.0, false, false, false, false)
			if an._nome_atual != antes:
				trocas.append(fr)
				if an._ap.current_animation_position > 0.05:
					meio += 1
			fr += 1
			nomes[an._nome_atual] = true
			await process_frame
	sk.skeleton_updated.disconnect(medir)
	# o maior tranco nos 12 quadros depois de cada troca
	var maior := 0.0
	var trs: Array = med["tr"]
	for t in trocas:
		for i in range(t, mini(t + 12, trs.size())):
			maior = maxf(maior, trs[i])
	var r := {"maior": maior, "nomes": nomes.keys(), "meio": meio, "trocas": an.trocas_mm}
	# diagonal mirando + curva correndo (só no modo novo)
	if mm:
		# quadril: a frente dele (para onde os passos vão) aponta para o movimento; tronco: fica na mira (+Z)
		var erro_quadril := 0.0
		for dd in [Vector2(1.1, 1.1), Vector2(-1.1, 1.1)]:
			for k in 70:
				an._dir = dd
				an.atualizar_estado(dt, 1.55, true, 0.0, true, false, false, false)
				await process_frame
			var tr := {"f": Vector3.ZERO, "p": Vector3.ZERO}
			var ler := func():
				tr["f"] = sk.get_bone_global_pose(sk.find_bone("spine_03")).basis.z
				tr["p"] = sk.get_bone_global_pose(pel).basis.z
			sk.skeleton_updated.connect(ler)
			await process_frame
			sk.skeleton_updated.disconnect(ler)
			var f: Vector3 = tr["f"]
			var f0: Vector3 = sk.get_bone_global_rest(sk.find_bone("spine_03")).basis.z
			r["tronco"] = maxf(float(r.get("tronco", 0.0)), absf(rad_to_deg(Vector2(f.x, f.z).angle_to(Vector2(f0.x, f0.z)))))
			# no espaço do esqueleto: frente = +Z, direita do personagem = -X
			var pq: Vector3 = tr["p"]
			var p0: Vector3 = sk.get_bone_global_rest(pel).basis.z
			var giro := Vector2(pq.x, pq.z).angle_to(Vector2(p0.x, p0.z))     # quanto o quadril girou
			var esperado := Vector2(0, 1).angle_to(Vector2(-dd.x, dd.y))
			erro_quadril = maxf(erro_quadril, absf(rad_to_deg(wrapf(giro + esperado, -PI, PI))))
			r["diag_nome"] = an._nome_atual
			r["diag_ang"] = s.orientacao.aplicado
		r["erro_quadril"] = erro_quadril
		an._giro = 2.0
		for k in 40:
			an._dir = Vector2(0, 6.0)
			an._giro = 2.0
			an.atualizar_estado(dt, 6.0, true, 0.0, false, false, false, false)
			await process_frame
		r["inclina"] = s.orientacao._inc
		r["inercia_ok"] = not s.inercia.em_transicao() or s.inercia._t < s.inercia.DURACAO
	raiz.queue_free()
	await process_frame
	return r

func _r():
	var B = load("res://jogador/base_movimento.gd")
	for sx in ["m", "f"]:
		var b = B.carregar(sx)
		ok(b != null and b.clipes.size() == 13, "biblioteca %s com as 13 animações de locomoção" % sx)
	var velho: Dictionary = await _rodar(false)
	var novo: Dictionary = await _rodar(true)
	print("  antigo: maior tranco do pé nas trocas %.3f m · animações %s" % [velho["maior"], str(velho["nomes"])])
	print("  novo:   maior tranco do pé nas trocas %.3f m · animações %s · %d trocas, %d no meio do passo" % [novo["maior"], str(novo["nomes"]), novo["trocas"], novo["meio"]])
	var nn: Array = novo["nomes"]
	ok(nn.has("parado") and (nn.has("andar_lento") or nn.has("andar_normal")) and nn.has("trote") and (nn.has("correr") or nn.has("correr_fuzil")),
		"a busca escolhe parado, caminhada, trote e corrida pela velocidade")
	ok(int(novo["meio"]) >= 2, "entra no meio do passo nas trocas (%d vezes)" % int(novo["meio"]))
	ok(float(novo["maior"]) < float(velho["maior"]), "os pés dão menos tranco que no jeito antigo (%.3f < %.3f m)" % [novo["maior"], velho["maior"]])
	ok(float(novo["maior"]) < 0.03, "nenhum tranco grande de pé nas trocas (%.3f m)" % novo["maior"])
	ok(absf(float(novo["diag_ang"])) > 0.3 and float(novo["tronco"]) < 12.0,
		"mirando na diagonal: pernas giram %.0f° (%s) e o tronco fica na mira (%.1f°)" % [rad_to_deg(novo["diag_ang"]), novo["diag_nome"], novo["tronco"]])
	ok(float(novo["erro_quadril"]) < 15.0, "nas duas diagonais o quadril (os passos) aponta para o movimento (erro %.0f°)" % novo["erro_quadril"])
	ok(float(novo["inclina"]) < -0.05, "correndo em curva para a esquerda o tronco inclina para dentro (%.2f rad)" % novo["inclina"])
	var fem: Dictionary = await _rodar(true, "f")
	ok(float(fem["maior"]) < 0.03 and (fem["nomes"] as Array).has("trote"), "no corpo feminino também (%.3f m)" % fem["maior"])
	# tempo da busca
	var b = B.carregar("m")
	var q: PackedFloat32Array = b.quadro("andar_normal", 0.3)
	var t0 := Time.get_ticks_usec()
	for k in 50:
		b.buscar(["parado", "andar_lento", "andar_normal", "andar_rapido", "trote", "correr", "andar_tras", "andar_lado_dir", "andar_lado_esq"],
			Vector2(0.4, 2.0), q, 1.1)
	var us := float(Time.get_ticks_usec() - t0) / 50.0
	ok(us < 1000.0, "a busca leva %.0f µs (10 vezes por segundo)" % us)
	print("falhas: ", falhas)
	quit()
