extends SceneTree
# TESTE: ROUPAS 3D (1.11). Com o jogo de verdade:
#   · cada item de jogador/roupas_tabela.gd existe em inventario/itens.gd, num encaixe que existe, tem as malhas dos dois
#     corpos (jogador/roupas/<peça>_m/_f.res, com a pele que cobre), ícone e modelo no chão
#   · o loot das roupas novas só usa itens que existem; a rede manda os encaixes novos (rosto, luvas, calçado)
#   · vestido no jogador (homem e mulher): a peça aparece presa ao esqueleto, a pele embaixo some (máscara ligada),
#     a calça "entra" na bota, o colete fica por fora da jaqueta (camadas), o macacão (corpo inteiro) esconde a calça, chapéu esconde o cabelo; tirar tudo volta ao
#     corpo original (sem máscara)
#   · o inventário tem os encaixes CALÇADO e LUVAS e o jogo começa de botina
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

func _r():
	await q(20)
	var m = current_scene
	var Tab = load("res://jogador/roupas_tabela.gd")
	var Itens = load("res://inventario/itens.gd")
	var Sob = load("res://jogador/modelo_sobrevivente.gd")
	var MI = load("res://inventario/modelos_itens.gd")
	var ItemCls = load("res://inventario/item.gd")
	var Sess = load("res://rede/sessao_rede.gd")
	# ---- dados ----
	var ruins: Array = []
	for id in Tab.PECAS:
		var d: Dictionary = Itens.def(id)
		if d.is_empty() or not Itens.SLOTS.has(str(d.get("slot", ""))):
			ruins.append(id + " (item/encaixe)")
			continue
		for sx in ["m", "f"]:
			var mm = Sob.malha_roupa(Tab.peca(id, sx), sx)
			if mm == null or not mm.has_meta("esconde") or mm.get_surface_count() != 1:
				ruins.append(id + " (malha " + sx + ")")
		if not ResourceLoader.exists("res://inventario/icones/" + id + ".png"):
			ruins.append(id + " (ícone)")
		var chao = MI.instancia(id)
		if chao == null:
			ruins.append(id + " (modelo no chão)")
		else:
			chao.free()
	ok(ruins.is_empty(), "%d roupas com item, malha masculina e feminina, ícone e modelo no chão %s" % [Tab.PECAS.size(), str(ruins)])
	var loot_ruim: Array = []
	for t in Tab.LOOT:
		for e in Tab.LOOT[t]:
			if Itens.def(e[0]).is_empty():
				loot_ruim.append(e[0])
	ok(loot_ruim.is_empty() and Tab.LOOT.has("loja_roupas") and Tab.LOOT.has("quartel_alojamento"), "loot das roupas novas (lojas, casas, quartéis...) só com itens que existem")
	ok("pes" in Sess.SLOTS_ROUPA and "luvas" in Sess.SLOTS_ROUPA and "rosto" in Sess.SLOTS_ROUPA, "a rede manda calçado, luvas e rosto")
	# ---- no jogo ----
	m._jogar()
	await q(60)
	if m.tela_login != null:
		m.tela_login.queue_free()
		m.tela_login = null
	var j = m.jogador
	j.sobrevivencia.imortal = true
	m.vagos.max_ativos = 0
	var inv = j.inventario
	ok(inv.slots.has("pes") and inv.slots.has("luvas"), "o inventário tem os encaixes CALÇADO e LUVAS")
	ok(inv.slots.get("pes") != null and inv.slots["pes"].id == "botina", "o jogo começa de botina")
	var sob = j.get_node("Modelo/Sobrevivente")
	await q(3)
	ok(sob._roupas_3d.has("camisa") and sob._roupas_3d.has("calca") and sob._roupas_3d.has("pes") and sob._roupas_3d.has("colete"),
		"começa vestido em 3D: jaqueta, calça, colete e botina (%s)" % str(sob._roupas_3d.keys()))
	ok(bool(sob._mat.get_shader_parameter("usa_mascara")), "a pele embaixo da roupa some (máscara ligada)")
	var mi_calca: MeshInstance3D = sob._roupas_3d["calca"][1]
	var corte = mi_calca.material_override.get_shader_parameter("corte_y") if mi_calca.material_override != null else -10.0
	ok(float(corte) > 0.05 and mi_calca.skeleton != NodePath(""), "a calça entra na bota (corta abaixo de %.2f m) e está presa ao esqueleto" % float(corte))
	var mi_col: MeshInstance3D = sob._roupas_3d["colete"][1]
	ok(mi_col.material_override != null and bool(mi_col.material_override.get_shader_parameter("usa_baixo")),
		"o colete fica por fora da jaqueta (camadas: espessura da jaqueta por baixo)")
	# troca peças: macacão (corpo inteiro), chapéu, luvas, máscara
	for par in [["camisa", "macacao_mecanico"], ["cabeca", "chapeu"], ["luvas", "luvas"], ["rosto", "bandana"]]:
		var it = ItemCls.novo(par[1])
		var velho = inv.slots.get(par[0])
		inv.slots[par[0]] = it
		it.slot = par[0]
		if velho != null:
			velho.slot = ""
	inv.mudou.emit()
	await q(3)
	ok(sob._roupas_3d.has("camisa") and sob._roupas_3d["camisa"][0] == "elvs_male_coveralls_1" and not sob._roupas_3d.has("calca"),
		"o macacão (corpo inteiro) aparece e a calça some embaixo dele")
	ok(sob._roupas_3d.has("cabeca") and sob._roupas_3d.has("luvas") and sob._roupas_3d.has("rosto"), "chapéu, luvas e bandana aparecem")
	var cabelo_visivel := false
	for c in sob.PENTEADOS:
		var h = sob.esqueleto.get_node_or_null(c)
		if h != null and h.visible and c != "Hair_Beard":
			cabelo_visivel = true
	ok(not cabelo_visivel, "o chapéu esconde o cabelo")
	# tira tudo: corpo original
	for s in ["camisa", "calca", "colete", "pes", "cabeca", "luvas", "rosto"]:
		if inv.slots.get(s) != null:
			inv.slots[s].slot = ""
		inv.slots[s] = null
	inv.mudou.emit()
	await q(3)
	ok(sob._roupas_3d.is_empty() and not bool(sob._mat.get_shader_parameter("usa_mascara")), "sem roupa: corpo original, nada escondido")
	# mulher: todas as roupas vestem sem erro (uma por vez, em cada encaixe)
	var mulher = Sob.new()
	mulher.aparencia = {"sexo": "f"}
	m.add_child(mulher)
	await q(2)
	var sem: Array = []
	for id in Tab.PECAS:
		var it = ItemCls.novo(id)
		var sl := str(Itens.def(id).get("slot", ""))
		var eq = _Eq.new()
		eq.slots[sl] = it
		mulher.vestir(eq)
		if not mulher._roupas_3d.has(sl):
			sem.append(id)
	ok(sem.is_empty(), "no corpo feminino todas as %d roupas aparecem %s" % [Tab.PECAS.size(), str(sem)])
	mulher.queue_free()
	print("falhas: ", falhas)
	quit()

class _Eq extends RefCounted:
	var slots := {}
