extends "res://npc/tela_npc.gd"
# TROCAS DO LUCAS (0.91) · as regras e a rede ficam em npc/trocas.gd; aqui é só a tela.
#   PARA VOCÊ ...... o que cada jogador quer te vender (itens + preço): ACEITAR (no hospital da oferta, com o
#                    dinheiro) ou RECUSAR.
#   VENDER ......... escolha PARA QUEM, marque os ITENS, ajuste o PREÇO e ENTREGUE AO LUCAS (os itens ficam com ele).
#   SUAS OFERTAS ... o que você ofereceu: esperando (CANCELAR), VENDIDO (RECEBER o dinheiro) ou RECUSADO (PEGAR os
#                    itens de volta) · sempre no hospital onde você deixou.

const Itens := preload("res://inventario/itens.gd")

var hospital := -1
var trocas = null                       # npc/trocas.gd
var _para := ""
var _sel: Array = []
var _preco := 0
var _esperando := false

func _ready() -> void:
	trocas.mudou.connect(func(): if not _esperando: refazer())
	trocas.resposta.connect(_resp)

func _montar(aba: int) -> void:
	if not trocas.em_rede():
		texto("LUCAS: \"Eu passo as ofertas pelo rádio para os outros sobreviventes. Sozinho aqui não tem com quem trocar: jogue no MULTIJOGADOR.\"")
		return
	match aba:
		0: _para_voce()
		1: _vender()
		2: _suas()

func _aqui(o: Dictionary) -> bool:
	return int(o["h"]) == hospital

func _onde(o: Dictionary) -> String:
	return "AQUI" if _aqui(o) else "NO HOSPITAL (%s)" % gerente.nome_hospital(int(o["h"]))

func _itens_de(o: Dictionary) -> void:
	for di in o.get("itens", []):
		var it = ItemCls.de_dict(di)
		if it != null:
			linha(it, it.nome() + (" x%d" % it.qtd if it.qtd > 1 else ""), Itens.nome_estado(it.estado) + " · valor de loja " + Precos.texto(Precos.valor(it)), "", func(): pass)

# ---------- PARA VOCÊ ----------
func _para_voce() -> void:
	var l: Array = trocas.para_mim()
	if l.is_empty():
		texto("Ninguém te ofereceu nada ainda. Quando alguém oferecer, o Lucas avisa pelo rádio e aparece no seu mapa.")
		return
	for o in l:
		titulo_secao("%s VENDE POR %s · %s" % [str(o["dn"]).to_upper(), Precos.texto(int(o["p"])), _onde(o)])
		_itens_de(o)
		botoes([["ACEITAR (%s)" % Precos.texto(int(o["p"])), _aceitar.bind(o), true], ["RECUSAR", _recusar.bind(o)]])

func _aceitar(o: Dictionary) -> void:
	if _esperando:
		return
	var preco := int(o["p"])
	if not _aqui(o):
		avisar("LUCAS: \"Os itens estão no HOSPITAL (%s). Vai até lá que o Lucas de lá te entrega.\"" % gerente.nome_hospital(int(o["h"])), true)
		return
	var tenho: int = gerente.dinheiro()
	if tenho < preco:
		avisar("LUCAS: \"Custa %s e você só tem %s. Faltam %s.\"" % [Precos.texto(preco), Precos.texto(tenho), Precos.texto(preco - tenho)], true)
		return
	if preco > 0 and not gerente.tirar_dinheiro(preco):
		avisar("FALTA DINHEIRO", true)
		return
	_esperando = true
	avisar("LUCAS: \"Deixa eu confirmar pelo rádio...\"")
	trocas.pedir("aceitar", {"i": o["i"], "pago": preco}, preco)

func _recusar(o: Dictionary) -> void:
	if _esperando:
		return
	_esperando = true
	trocas.pedir("recusar", {"i": o["i"]})

# ---------- VENDER ----------
func _vender() -> void:
	titulo_secao("1. PARA QUEM")
	var nomes: Array = trocas.nomes()
	if nomes.is_empty():
		texto("Ainda não passou mais ninguém por esta partida. Quem entrar aparece aqui (e continua na lista depois que sair).")
	for n in nomes:
		var esc: bool = n[0] == _para
		linha(null, str(n[1]).to_upper(), "está na partida" if n[2] else "fora da partida (vê a oferta quando voltar)",
			"ESCOLHIDO" if esc else "ESCOLHER", _escolher.bind(str(n[0])), esc)
	titulo_secao("2. ITENS QUE VOCÊ QUER VENDER (marque)")
	var tem := false
	for it in gerente.meus_itens():
		if it.id == "dinheiro" or it.tem_conteudo():
			continue
		tem = true
		var marc: bool = it in _sel
		linha(it, it.nome() + (" x%d" % it.qtd if it.qtd > 1 else ""), Itens.nome_estado(it.estado) + " · valor de loja " + Precos.texto(Precos.valor(it)),
			"MARCADO" if marc else "MARCAR", _marcar.bind(it), marc)
	if not tem:
		texto("Nada para vender: só o que está nas suas roupas e mochila (vazias por dentro).")
	titulo_secao("3. PREÇO")
	var loja := 0
	for it in _sel:
		loja += Precos.valor(it)
	texto("Preço pedido: %s · %d itens marcados (valor de loja %s)" % [Precos.texto(_preco), _sel.size(), Precos.texto(loja)], UI.AMBAR)
	botoes([["-100", _somar.bind(-100)], ["-10", _somar.bind(-10)], ["+10", _somar.bind(10)], ["+100", _somar.bind(100)], ["+1000", _somar.bind(1000)], ["ZERAR", _somar.bind(-999999)]])
	titulo_secao("4. ENTREGAR")
	botoes([["ENTREGAR AO LUCAS", _enviar, true]])

func _escolher(k: String) -> void:
	_para = k
	refazer()

func _marcar(it) -> void:
	if it in _sel:
		_sel.erase(it)
	elif _sel.size() >= trocas.MAX_ITENS:
		avisar("NO MÁXIMO %d ITENS POR OFERTA" % trocas.MAX_ITENS, true)
		return
	else:
		_sel.append(it)
	refazer()

func _somar(n: int) -> void:
	_preco = clampi(_preco + n, 0, trocas.MAX_PRECO)
	refazer()

func _enviar() -> void:
	if _esperando:
		return
	if _para == "":
		avisar("ESCOLHA PARA QUEM VENDER (1)", true)
		return
	var inv = gerente.jogador.inventario
	_sel = _sel.filter(func(it): return inv.do_jogador(it) and not it.tem_conteudo())
	if _sel.is_empty():
		avisar("MARQUE PELO MENOS UM ITEM (2)", true)
		return
	if trocas.minhas().filter(func(o): return o["e"] == "aberta").size() >= trocas.MAX_ABERTAS:
		avisar("VOCÊ JÁ TEM %d OFERTAS ESPERANDO RESPOSTA" % trocas.MAX_ABERTAS, true)
		return
	var dicts: Array = []
	for it in _sel:
		dicts.append(it.para_dict())
		inv.retirar(it)
	inv._depois()
	_esperando = true
	avisar("LUCAS: \"Pode deixar comigo...\"")
	trocas.pedir("nova", {"para": _para, "p": _preco, "h": hospital, "itens": dicts})
	_sel.clear()

# ---------- SUAS OFERTAS ----------
func _suas() -> void:
	var l: Array = trocas.minhas()
	if l.is_empty():
		texto("Você não tem ofertas. Em VENDER, escolha para quem, os itens e o preço.")
		return
	for o in l:
		var est := {"aberta": "ESPERANDO RESPOSTA", "vendida": "VENDIDO PARA %s" % str(o.get("c", "")).to_upper(), "recusada": "RECUSADO"}
		titulo_secao("PARA %s · %s · %s · %s" % [str(o["pn"]).to_upper(), Precos.texto(int(o["p"])), est.get(o["e"], ""), _onde(o)])
		_itens_de(o)
		if not _aqui(o):
			texto("Para mexer nesta oferta, vá ao HOSPITAL (%s): está marcado no seu mapa quando houver resposta." % gerente.nome_hospital(int(o["h"])))
			continue
		match str(o["e"]):
			"aberta": botoes([["CANCELAR E PEGAR OS ITENS", _pedir_volta.bind(o, "cancelar")]])
			"vendida": botoes([["RECEBER %s" % Precos.texto(int(o["p"])), _pedir_volta.bind(o, "receber"), true]])
			"recusada": botoes([["PEGAR OS ITENS DE VOLTA", _pedir_volta.bind(o, "receber"), true]])

func _pedir_volta(o: Dictionary, tipo: String) -> void:
	if _esperando:
		return
	_esperando = true
	trocas.pedir(tipo, {"i": o["i"]})

func _resp(res: Dictionary) -> void:
	_esperando = false
	if res.get("ok", false):
		npc.modelo.gesto("npc_sim")
	avisar(str(res.get("msg", "")), not res.get("ok", false))
	refazer()
