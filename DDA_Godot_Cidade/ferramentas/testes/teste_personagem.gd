extends SceneTree
# TESTE: PERSONAGEM MASCULINO/FEMININO (1.10). Com o jogo de verdade:
#   · aparência fora da lista volta ao padrão (normalizar) e a rede só aceita as chaves dela (Rede._so_aparencia)
#   · o PERFIL tem o painel SEU PERSONAGEM com o boneco 3D vestido com o jogo salvo; trocar para FEMININO grava em
#     Config "aparencia" e troca o corpo do boneco e o do menu principal; o painel sobrevive ao _montar (amigos)
#   · no jogo, o jogador nasce MULHER com o penteado e a cor escolhidos; capacete esconde o cabelo; o boneco do
#     inventário também é mulher; anima (andar) e segura a arma no osso da mão
#   · CORPO ORIGINAL (1.10): mesmo vestido no inventário, nenhuma casca de roupa/colete e nada da pele escondido
#   · trocar pele/cabelo/cor na hora (definir_aparencia) e não trocar o sexo assim (devolve false)
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

func _cabelo_visivel(sob) -> Array:
	var r := []
	for c in sob.PENTEADOS:
		var h = sob.esqueleto.get_node_or_null(c)
		if h != null and h.visible:
			r.append(c)
	return r

func _r():
	await q(20)
	var m = current_scene
	var Cfg = root.get_node("Config")
	var Rd = root.get_node("Rede")
	var Sob = load("res://jogador/modelo_sobrevivente.gd")
	var antes_cfg = Cfg.valor("aparencia")
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	# ---- conferências ----
	var n: Dictionary = Sob.normalizar({"sexo": "x", "pele": 99, "cabelo": "Chapeu", "barba": true, "cor": -3})
	ok(n["sexo"] == "m" and n["pele"] == Sob.PELES.size() - 1 and n["cabelo"] == "Hair_Buzzed" and n["cor"] == 0, "aparência fora da lista volta ao padrão")
	ok(not Sob.normalizar({"sexo": "f", "barba": true})["barba"], "mulher não fica com barba")
	var so: Dictionary = Rd._so_aparencia({"sexo": "f", "cabelo": "Hair_Long", "lixo": [1, 2], "cor": {"a": 1}})
	ok(so.size() == 2 and so["sexo"] == "f", "da rede só entram as chaves da aparência, com valores simples")
	# ---- perfil ----
	Cfg.definir("aparencia", {})
	m._abrir_perfil()
	await q(30)
	var p = m.tela_perfil.painel_personagem
	ok(p != null and p.is_inside_tree() and p.boneco._sob.sexo() == "m", "o Perfil tem o painel SEU PERSONAGEM (boneco 3D, homem de sempre)")
	ok(p._inv.slots.has("camisa") and p._inv.slots.has("calca"), "o boneco do Perfil está vestido (jogo salvo ou a roupa inicial: %s)" % str(p._inv.slots.keys()))
	p._sexo.definir("f")
	p._trocar_sexo("f")
	await q(5)
	var ap: Dictionary = Cfg.valor("aparencia")
	ok(ap.get("sexo") == "f" and ap.get("cabelo") == "Hair_Long" and not ap.get("barba"), "FEMININO grava no Config (cabelo comprido, sem barba)")
	ok(p.boneco._sob.sexo() == "f" and is_instance_valid(p.boneco._sob), "o boneco do Perfil virou mulher")
	var sm = m.get_node_or_null("CenaMenu")
	if sm == null:
		for c in m.find_children("*", "Node3D", true, false):
			if c.get("soldado") != null:
				sm = c
				break
	ok(sm != null and is_instance_valid(sm.soldado) and sm.soldado.sexo() == "f", "o personagem do menu principal também virou mulher")
	p._mudar("cabelo", "Hair_Buns")
	p._mudar("cor", 3)
	await q(3)
	ok(_cabelo_visivel(p.boneco._sob) == ["Hair_Buns"], "trocar o cabelo muda o boneco na hora (coque)")
	var pa = p
	m.tela_perfil._montar()
	await q(3)
	ok(m.tela_perfil.painel_personagem == pa and pa.is_inside_tree(), "o painel não é refeito quando o Perfil se remonta (amigos atualizando)")
	m.tela_perfil._sair()
	await q(3)
	# ---- no jogo ----
	m._jogar()
	await q(60)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	var sob = j.get_node("Modelo/Sobrevivente")
	ok(sob.sexo() == "f" and _cabelo_visivel(sob) == ["Hair_Buns"], "no jogo o jogador é mulher, de coque")
	var cor: Color = (sob.esqueleto.get_node("Hair_Buns").material_override as StandardMaterial3D).albedo_color
	ok(cor.is_equal_approx(Sob.CORES_CABELO[3][1]), "com a cor de cabelo escolhida (loiro)")
	var ItemCls = load("res://inventario/item.gd")
	var cap = ItemCls.novo("capacete")
	j.inventario._guardar_auto(cap)
	j.inventario.equipar(cap, "cabeca")
	await q(3)
	ok(_cabelo_visivel(sob).is_empty(), "o capacete esconde o cabelo dela")
	# corpo original: nenhuma casca de roupa/colete, nada da pele escondido (mesmo com jaqueta/calça/colete equipados)
	var cascas := 0
	for c in sob.esqueleto.get_children():
		if (str(c.name).begins_with("Roupa_") or str(c.name) == "Colete") and c.visible:
			cascas += 1
	var esc = sob._mat.get_shader_parameter("esconde")
	var esc_soma := 0.0
	if esc != null:
		for x in esc:
			esc_soma += float(x)
	ok(cascas == 0 and esc_soma == 0.0 and j.inventario.slots.get("camisa") != null, "corpo original do pack: sem cascas de roupa nem pele cortada (%d cascas)" % cascas)
	ok(sob.definir_aparencia({"sexo": "f", "cabelo": "Hair_Long", "pele": 4, "cor": 1}) and not sob.definir_aparencia({"sexo": "m"}),
		"pele/cabelo/cor trocam na hora; o sexo não (é outro corpo)")
	# anima e a arma vai na mão dela
	var mao = sob.esqueleto.find_bone("hand_r")
	var p0: Vector3 = sob.esqueleto.get_bone_global_pose(mao).origin
	sob.anim.play("andar")
	await q(20)
	var p1: Vector3 = sob.esqueleto.get_bone_global_pose(mao).origin
	ok(p0.distance_to(p1) > 0.02, "o corpo dela anima (a mão mexeu %.2f m andando)" % p0.distance_to(p1))
	var pa_arma = sob.pegar_ponto_arma()
	ok(pa_arma != null and pa_arma.get_parent() is BoneAttachment3D and pa_arma.get_parent().bone_name == "hand_r", "a arma fica presa à mão direita dela")
	# boneco do inventário
	var bon = null
	for c in m.find_children("*", "SubViewportContainer", true, false):
		if c.get("_sob") != null and c != p.boneco:
			bon = c
	if bon == null:
		var B = load("res://inventario/boneco_3d.gd")
		bon = B.new(j.inventario)
		m.add_child(bon)
		await q(3)
	ok(bon._sob.sexo() == "f", "o boneco do inventário também é mulher")
	print("falhas: ", falhas)
	Cfg.definir("aparencia", antes_cfg if antes_cfg is Dictionary else {})
	Cfg.salvar_pendente()
	quit()
