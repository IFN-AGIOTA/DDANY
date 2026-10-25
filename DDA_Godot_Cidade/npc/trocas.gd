extends Node
# TROCAS ENTRE JOGADORES (0.91) · o LUCAS, no rádio do hospital, é o intermediário (a tela: npc/tela_trocas.gd).
#   1. O VENDEDOR escolhe PARA QUEM (lista de nomes: quem está na partida e quem já passou por ela), os ITENS e o
#      PREÇO em dólares e entrega ao Lucas: os itens saem do inventário e ficam com ele, NAQUELE hospital.
#   2. O COMPRADOR vê no Lucas (de qualquer hospital) a lista do que cada um quer vender para ele. Para ACEITAR tem que
#      estar no hospital da oferta e ter o dinheiro: o dinheiro sai, os itens entram. Ou RECUSA (pode de longe).
#   3. O VENDEDOR vê no MAPA (e num aviso) que vendeu (ou que recusaram) e vai até aquele hospital buscar o DINHEIRO
#      (ou os itens de volta) com o Lucas. Enquanto ninguém aceitou, ele pode CANCELAR e levar os itens de volta.
# QUEM MANDA é o HOST: o registro (ofertas) fica nele, vai no jogo salvo do mundo dele, e é ele que confere cada pedido
# (a oferta ainda está aberta? é para você? você é o dono? o dinheiro veio certo?) antes de mexer. Os pedidos vão por
# "troca_pedido" (amigo -> host), a resposta por "troca_resp" (host -> quem pediu) e o registro inteiro por
# "trocas_lista" (host -> todos), que é de onde cada aparelho tira os avisos e as marcas do mapa.
# Sozinho (sem rede) não tem com quem trocar. Mexa AQUI para: limites (MAX_*) e as regras de cada pedido.

const ItemCls := preload("res://inventario/item.gd")
const Precos := preload("res://npc/precos.gd")
const Locais := preload("res://mundo/locais.gd")

const MAX_ABERTAS := 6                  # ofertas abertas por vendedor
const MAX_ITENS := 12                   # itens por oferta
const MAX_PRECO := 100000

signal mudou                            # o registro mudou (a tela do Lucas refaz)
signal resposta(r: Dictionary)          # resposta de um pedido meu

var gerente = null                      # npc/hospitais.gd
var ofertas: Array = []                 # [{i, de, dn, para, pn, h, itens, p, e, c}] · e = aberta/vendida/recusada
var conhecidos := {}                    # chave -> nome (todo mundo que já esteve na partida)
var _n := 0
var _pedidos := {}                      # número do pedido -> {"dinheiro": pago} (para devolver se der errado)
var _vistos := {}                       # avisos já mostrados ("id:estado")
var _t := 0.0

func _rede():
	return get_node_or_null("/root/Rede")

func em_rede() -> bool:
	var r = _rede()
	return r != null and bool(r.ligado)

func eh_host() -> bool:
	var r = _rede()
	return r != null and bool(r.ligado) and r.eh_host()

# quem sou eu (a mesma chave que o host calcula para mim)
func minha_chave() -> String:
	var r = _rede()
	if r == null or not bool(r.ligado):
		return ""
	return chave_de(r.meu_id())

func chave_de(peer: int) -> String:
	var r = _rede()
	var j: Dictionary = r.jogadores.get(peer, {})
	var uid := str(j.get("uid", ""))
	return uid if uid != "" else "nome:" + str(j.get("nome", "?")).to_lower()

func meu_nome() -> String:
	var r = _rede()
	return r.nome_de(r.meu_id()) if r != null else ""

# ---------- o que a tela mostra ----------
func para_mim() -> Array:
	var eu := minha_chave()
	return ofertas.filter(func(o): return o["para"] == eu and o["e"] == "aberta")

func minhas() -> Array:
	var eu := minha_chave()
	return ofertas.filter(func(o): return o["de"] == eu)

# nomes para quem dá para vender (todos menos eu), os que estão na partida primeiro
func nomes() -> Array:
	var eu := minha_chave()
	var r = _rede()
	var on := {}
	if r != null:
		for id in r.jogadores:
			if id != r.meu_id():
				on[chave_de(id)] = true
	var l: Array = []
	for k in conhecidos:
		if k != eu:
			l.append([k, str(conhecidos[k]), on.has(k)])
	l.sort_custom(func(a, b): return (a[2] and not b[2]) or (a[2] == b[2] and str(a[1]) < str(b[1])))
	return l

# ---------- pedidos (vêm da tela) ----------
# itens: lista de item.gd (já tirados do inventário pela tela) · volta pelo sinal "resposta"
func pedir(tipo: String, d: Dictionary, pago := 0) -> void:
	_n += 1
	var n := _n
	_pedidos[n] = {"dinheiro": pago, "itens": d.get("itens", []) if tipo == "nova" else []}
	if eh_host():
		_responder(n, _atender(_rede().meu_id(), tipo, d))
	else:
		_rede().enviar_evento("troca_pedido", {"t": tipo, "d": d, "n": n}, 1)

# ---------- host: confere e faz ----------
func _atender(peer: int, tipo: String, d: Dictionary) -> Dictionary:
	var r = _rede()
	var eu := chave_de(peer)
	conhecidos[eu] = r.nome_de(peer)
	var res := {"ok": false, "t": tipo}
	match tipo:
		"nova":
			var itens: Array = d.get("itens", [])
			var para := str(d.get("para", ""))
			var preco := int(d.get("p", -1))
			var h := int(d.get("h", -1))
			var abertas := ofertas.filter(func(o): return o["de"] == eu and o["e"] == "aberta").size()
			if itens.is_empty() or itens.size() > MAX_ITENS:
				res["msg"] = "ESCOLHA DE 1 A %d ITENS" % MAX_ITENS
			elif para == "" or para == eu or not conhecidos.has(para):
				res["msg"] = "ESCOLHA PARA QUEM VENDER"
			elif preco < 0 or preco > MAX_PRECO:
				res["msg"] = "PREÇO INVÁLIDO"
			elif h < 0 or h >= Locais.LOCAIS.size() or Locais.LOCAIS[h][0] != "hospital":
				res["msg"] = "SÓ NO HOSPITAL"
			elif abertas >= MAX_ABERTAS:
				res["msg"] = "VOCÊ JÁ TEM %d OFERTAS ABERTAS" % MAX_ABERTAS
			else:
				var o := {"i": "%d_%d" % [Time.get_ticks_msec() % 100000000, randi() % 100000], "de": eu, "dn": r.nome_de(peer),
					"para": para, "pn": str(conhecidos[para]), "h": h, "itens": itens, "p": preco, "e": "aberta", "c": ""}
				ofertas.append(o)
				res["ok"] = true
				res["msg"] = "O LUCAS GUARDOU OS ITENS · OFERTA PARA %s POR %s" % [str(o["pn"]).to_upper(), Precos.texto(preco)]
			if not res["ok"]:
				res["itens"] = itens                         # devolve o que ia ficar com o Lucas
		"aceitar":
			var o = _achar(str(d.get("i", "")))
			var pago := int(d.get("pago", 0))
			if o == null or o["e"] != "aberta":
				res["msg"] = "ESSA OFERTA NÃO ESTÁ MAIS ABERTA"
			elif o["para"] != eu:
				res["msg"] = "ESSA OFERTA NÃO É PARA VOCÊ"
			elif pago != int(o["p"]):
				res["msg"] = "O DINHEIRO NÃO BATE COM O PREÇO"
			else:
				o["e"] = "vendida"
				o["c"] = r.nome_de(peer)
				res["ok"] = true
				res["itens"] = o["itens"]
				res["msg"] = "COMPROU DE %s POR %s" % [str(o["dn"]).to_upper(), Precos.texto(int(o["p"]))]
				o["itens"] = []
			if not res["ok"]:
				res["dinheiro"] = pago                      # devolve o dinheiro
		"recusar":
			var o = _achar(str(d.get("i", "")))
			if o == null or o["e"] != "aberta" or o["para"] != eu:
				res["msg"] = "ESSA OFERTA NÃO ESTÁ MAIS ABERTA"
			else:
				o["e"] = "recusada"
				res["ok"] = true
				res["msg"] = "VOCÊ RECUSOU A OFERTA DE %s" % str(o["dn"]).to_upper()
		"cancelar", "receber":
			var o = _achar(str(d.get("i", "")))
			if o == null or o["de"] != eu:
				res["msg"] = "OFERTA NÃO ENCONTRADA"
			elif tipo == "cancelar" and o["e"] != "aberta":
				res["msg"] = "JÁ RESPONDERAM ESSA OFERTA"
			elif tipo == "receber" and o["e"] == "aberta":
				res["msg"] = "AINDA NINGUÉM RESPONDEU"
			else:
				if o["e"] == "vendida":
					res["dinheiro"] = int(o["p"])
					res["msg"] = "O LUCAS TE ENTREGOU %s (VENDA PARA %s)" % [Precos.texto(int(o["p"])), str(o["c"]).to_upper()]
				else:
					res["itens"] = o["itens"]
					res["msg"] = "OS ITENS VOLTARAM PARA VOCÊ"
				ofertas.erase(o)
				res["ok"] = true
	_espalhar()
	return res

func _achar(id: String):
	for o in ofertas:
		if o["i"] == id:
			return o
	return null

func _espalhar() -> void:
	if eh_host():
		_rede().enviar_evento("trocas_lista", {"l": ofertas, "c": conhecidos})
		_ver_avisos()
		mudou.emit()

# ---------- rede (rede/sessao_rede.gd chama) ----------
func receber(de: int, tipo: String, d: Dictionary) -> void:
	match tipo:
		"troca_pedido":
			if eh_host():
				var res := _atender(de, str(d.get("t", "")), d.get("d", {}))
				res["n"] = int(d.get("n", 0))
				_rede().enviar_evento("troca_resp", res, de)
		"troca_resp":
			if de == 1:
				_responder(int(d.get("n", 0)), d)
		"trocas_lista":
			if de == 1:
				ofertas = d.get("l", [])
				conhecidos = d.get("c", {})
				_ver_avisos()
				mudou.emit()

# quem chegou recebe o registro
func mandar_para(peer: int) -> void:
	if eh_host():
		conhecidos[chave_de(peer)] = _rede().nome_de(peer)
		_rede().enviar_evento("trocas_lista", {"l": ofertas, "c": conhecidos})

# a resposta chegou: entrega o que veio (itens/dinheiro) ou devolve o que eu tinha dado
func _responder(n: int, res: Dictionary) -> void:
	var p: Dictionary = _pedidos.get(n, {})
	_pedidos.erase(n)
	var inv = gerente.jogador.inventario if gerente != null else null
	if inv != null:
		var itens: Array = res.get("itens", [])
		var no_chao := false
		for di in itens:
			var it = ItemCls.de_dict(di) if di is Dictionary else di
			if it != null:
				if not inv._guardar_auto(it):
					inv._soltar_no_chao(it)
					no_chao = true
		if int(res.get("dinheiro", 0)) > 0:
			gerente.dar_dinheiro(int(res["dinheiro"]))
		if no_chao:
			res["msg"] = str(res.get("msg", "")) + " · SEM ESPAÇO: ALGUNS ITENS FICARAM NO CHÃO"
		inv._depois()
	resposta.emit(res)

# ---------- avisos e mapa ----------
# [posição no mapa, texto, cor] do que está esperando por mim
func notas() -> Array:
	var l: Array = []
	var eu := minha_chave()
	if eu == "":
		return l
	for o in ofertas:
		var h := int(o["h"])
		if h < 0 or h >= Locais.LOCAIS.size():
			continue
		var pos := Vector2(Locais.LOCAIS[h][1], Locais.LOCAIS[h][2])
		if o["para"] == eu and o["e"] == "aberta":
			l.append([pos, "OFERTA DE %s · %s" % [str(o["dn"]).to_upper(), Precos.texto(int(o["p"]))], Color(1.0, 0.75, 0.2)])
		elif o["de"] == eu and o["e"] == "vendida":
			l.append([pos, "VENDIDO · BUSCAR %s" % Precos.texto(int(o["p"])), Color(0.4, 1.0, 0.45)])
		elif o["de"] == eu and o["e"] == "recusada":
			l.append([pos, "RECUSARAM · BUSCAR ITENS", Color(1.0, 0.45, 0.35)])
	return l

func _ver_avisos() -> void:
	var eu := minha_chave()
	if eu == "" or gerente == null:
		return
	for o in ofertas:
		var k := "%s:%s" % [o["i"], o["e"]]
		if _vistos.has(k):
			continue
		_vistos[k] = true
		var hn := "HOSPITAL (%s)" % gerente.nome_hospital(int(o["h"]))
		if o["para"] == eu and o["e"] == "aberta":
			gerente.avisar("LUCAS (RÁDIO): %s QUER TE VENDER %d ITENS POR %s · NO %s" % [str(o["dn"]).to_upper(), (o["itens"] as Array).size(), Precos.texto(int(o["p"])), hn])
		elif o["de"] == eu and o["e"] == "vendida":
			gerente.avisar("LUCAS (RÁDIO): %s COMPROU SEUS ITENS · BUSQUE %s NO %s (ESTÁ NO MAPA)" % [str(o["c"]).to_upper(), Precos.texto(int(o["p"])), hn])
		elif o["de"] == eu and o["e"] == "recusada":
			gerente.avisar("LUCAS (RÁDIO): %s RECUSOU A SUA OFERTA · OS ITENS TE ESPERAM NO %s" % [str(o["pn"]).to_upper(), hn])

# host: todo mundo que entra fica conhecido (aparece na lista de nomes)
func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 2.0
	if not eh_host():
		return
	var r = _rede()
	var novo := false
	for id in r.jogadores:
		var k := chave_de(id)
		if not conhecidos.has(k) or conhecidos[k] != r.nome_de(id):
			conhecidos[k] = r.nome_de(id)
			novo = true
	if novo:
		_espalhar()

# ---------- jogo salvo (só o host guarda: o registro é do mundo dele) ----------
func salvar() -> Dictionary:
	return {"l": ofertas, "c": conhecidos}

func carregar(d: Dictionary) -> void:
	ofertas = d.get("l", [])
	conhecidos = d.get("c", {})
	for o in ofertas:                                   # já vistos: não avisa de novo ao carregar
		_vistos["%s:%s" % [o["i"], o["e"]]] = true
