extends RefCounted
# PREÇOS (0.91) · quanto vale cada item em DÓLARES (o item "dinheiro": cada um = US$ 1). Usado pela loja da MÔNICA
# (npc/loja.gd) e pela tela de trocas do LUCAS (npc/tela_trocas.gd, só para mostrar o "valor de loja").
#   - PRECO: o preço CHEIO de 1 unidade (munição, tábuas e galhos: por unidade). Item que não está aqui vale
#     o padrão da categoria (POR_CATEGORIA).
#   - Comprar da Mônica: preço cheio x estado do item da loja x desconto do hospital (a especialidade sai mais barata).
#   - Vender para a Mônica: VENDA (40%) do preço cheio x estado (gasto vale menos). Ela não compra dinheiro nem
#     os cartões dos bunkers (NAO_NEGOCIA).
# Mexa AQUI para: o preço de cada item e quanto a Mônica paga.

const Itens := preload("res://inventario/itens.gd")

const VENDA := 0.4
const NAO_NEGOCIA := ["dinheiro", "cartao_bunker_1", "cartao_bunker_2", "cartao_bunker_3", "cartao_bunker_4"]
const POR_CATEGORIA := {"arma": 400, "branca": 50, "municao": 3, "pente": 60, "acessorio": 300, "medico": 30,
	"comida": 18, "bebida": 15, "ferramenta": 30, "roupa": 40, "mochila": 100, "diverso": 5}
const PRECO := {
	"pistola": 260, "mp5": 620, "m4": 950, "ak": 880, "espingarda": 520, "rifle_caca": 720,
	"faca": 60, "taco": 45, "machado": 140, "cano": 25, "lanca": 20, "facao": 90, "pe_de_cabra": 80,
	"mun_9mm": 2, "mun_556": 3, "mun_762": 3, "mun_12": 4, "mun_308": 6,
	"pente_pistola": 50, "pente_stanag": 80, "pente_mp5": 70, "pente_ak": 75,
	"silenciador": 420, "mira_acog": 320, "luneta": 460,
	"bandagem": 15, "trapos": 6, "analgesico": 25, "soro": 70, "kit_medico": 130, "vitaminas": 20,
	"antibiotico": 160, "carvao": 30, "pastilha": 6, "tala": 25,
	"feijao": 22, "atum": 18, "sardinha": 16, "pessego": 20, "leite_condensado": 18, "biscoito": 14, "barra": 8,
	"salgadinho": 10, "maca": 8,
	"agua": 20, "agua_suja": 4, "garrafa_vazia": 3, "refrigerante": 12, "suco": 14,
	"fita": 15, "kit_armas": 80, "kit_costura": 40, "lanterna": 50, "lanterna_cabeca": 70, "martelo": 60, "corda": 25,
	"radio": 120, "mascara_gas": 150, "pilha": 15, "isqueiro": 15, "galao": 70, "tabuas": 8, "galho": 2,
	"ursinho": 5, "revista": 3, "celular": 5,
	"capacete": 200, "gorro": 20, "bone": 15, "camiseta": 15, "moletom": 40, "jaqueta": 90, "capa_chuva": 60,
	"colete": 180, "colete_policia": 350, "calca": 50, "jeans": 40,
	"pochete": 40, "mochila_escolar": 80, "mochila_trilha": 200, "mochila_combate": 320,
}

# preço cheio de 1 unidade
static func cheio(id: String) -> int:
	if PRECO.has(id):
		return int(PRECO[id])
	return int(POR_CATEGORIA.get(str(Itens.def(id).get("cat", "diverso")), 5))

static func negocia(id: String) -> bool:
	return not id in NAO_NEGOCIA and not Itens.def(id).is_empty()

# quanto vale o item (a pilha toda, com o estado) · o que vem junto (balas no pente, acessórios na arma) também conta
static func valor(it) -> int:
	var v: float = float(cheio(it.id)) * it.qtd * lerpf(0.35, 1.0, clampf(it.estado, 0.0, 1.0))
	if it.municao > 0:
		var mid: String = str(it.def().get("municao", it.def().get("pente_de", "")))
		if mid != "":
			v += cheio(mid) * it.municao
	if it.pente_id != "":
		v += cheio(it.pente_id)
	for e in it.acessorios:
		v += cheio(str(it.acessorios[e]))
	return maxi(1, int(round(v)))

# quanto a Mônica paga
static func venda(it) -> int:
	return maxi(1, int(round(valor(it) * VENDA)))

static func texto(v: int) -> String:
	return "US$ %d" % v
