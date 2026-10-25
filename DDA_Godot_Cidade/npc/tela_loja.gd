extends "res://npc/tela_npc.gd"
# LOJA DA MÔNICA (0.91) · abas COMPRAR (o estoque dela neste hospital, só seu: npc/loja.gd) e VENDER (os itens das
# suas roupas e mochila; ela paga npc/precos.gd VENDA). Confere tudo antes: se você tem o dinheiro, se o item cabe
# (comprar), se o item pode ser vendido (cheio de coisas dentro, dinheiro e cartões dos bunkers não).

const Loja := preload("res://npc/loja.gd")
const Itens := preload("res://inventario/itens.gd")

var hospital := -1

func _montar(aba: int) -> void:
	if aba == 0:
		_comprar()
	else:
		_vender()

func _comprar() -> void:
	var esp: Array = Loja.especialidade(hospital)
	texto("Especialidade deste hospital: %s (mais itens e 20%% mais barato). O estoque é só seu e muda a cada dia do jogo (%s)." % [esp[0], gerente.tempo_ate_renovar()])
	var est: Array = gerente.estoque(hospital)
	var tem := false
	for k in est.size():
		var e: Dictionary = est[k]
		if gerente.comprado(hospital, k):
			continue
		tem = true
		var it = ItemCls.novo(str(e["id"]), int(e["q"]))
		if it == null:
			continue
		it.estado = float(e["e"])
		var nome: String = it.nome() + (" x%d" % int(e["q"]) if int(e["q"]) > 1 else "")
		var det: String = Itens.nome_estado(it.estado) + (" · ESPECIALIDADE" if bool(e.get("esp", false)) else "")
		var preco := int(e["preco"])
		var pode: bool = gerente.dinheiro() >= preco
		linha(it, nome, det, "COMPRAR " + Precos.texto(preco), _compra.bind(k), false, UI.LARANJA if pode else Color(0.45, 0.4, 0.38))
	if not tem:
		texto("Você já levou tudo o que ela tinha para você hoje. Volte amanhã.")

func _compra(k: int) -> void:
	var est: Array = gerente.estoque(hospital)
	if k >= est.size() or gerente.comprado(hospital, k):
		return
	var e: Dictionary = est[k]
	var preco := int(e["preco"])
	var tenho: int = gerente.dinheiro()
	if tenho < preco:
		avisar("MÔNICA: \"Isso custa %s e você só tem %s.\"" % [Precos.texto(preco), Precos.texto(tenho)], true)
		return
	var it = ItemCls.novo(str(e["id"]), int(e["q"]))
	it.estado = float(e["e"])
	if not gerente.cabe(it):
		avisar("MÔNICA: \"Não cabe na sua mochila. Abre espaço primeiro.\"", true)
		return
	if not gerente.tirar_dinheiro(preco):
		avisar("FALTA DINHEIRO", true)
		return
	gerente.jogador.inventario._guardar_auto(it)
	gerente.jogador.inventario._depois()
	gerente.marcar_comprado(hospital, k)
	npc.modelo.gesto("npc_sim")
	refazer()
	avisar("COMPROU %s POR %s" % [it.nome(), Precos.texto(preco)])

func _vender() -> void:
	texto("A Mônica paga 40% do valor (menos se estiver gasto). Dinheiro e cartões dos bunkers ela não compra; mochila e roupa só vazias.")
	var tem := false
	for it in gerente.meus_itens():
		if not Precos.negocia(it.id) or it.tem_conteudo():
			continue
		tem = true
		var nome: String = it.nome() + (" x%d" % it.qtd if it.qtd > 1 else "")
		linha(it, nome, Itens.nome_estado(it.estado), "VENDER " + Precos.texto(Precos.venda(it)), _venda.bind(it), false, Color(0.25, 0.6, 0.3))
	if not tem:
		texto("Você não tem nada que ela compre (só o que está nas suas roupas e mochila; o que está na mão ou vestido, não).")

func _venda(it) -> void:
	if not gerente.jogador.inventario.do_jogador(it) or it.tem_conteudo():
		refazer()
		return
	var v := Precos.venda(it)
	var inv = gerente.jogador.inventario
	inv.retirar(it)
	gerente.dar_dinheiro(v)
	inv._depois()
	npc.modelo.gesto("npc_sim")
	refazer()
	avisar("VENDEU %s POR %s" % [it.nome(), Precos.texto(v)])
