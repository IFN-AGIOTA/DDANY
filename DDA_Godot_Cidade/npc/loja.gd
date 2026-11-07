extends RefCounted
# LOJA DA MÔNICA (0.91) · o que ela tem para vender em cada hospital (a tela: npc/tela_loja.gd).
#   - TODOS OS TIPOS de item (armas, munição, remédios, comida, bebida, ferramentas, roupas, mochilas...), mas cada
#     hospital tem uma ESPECIALIDADE (mais itens dela e mais baratos): ESPECIALIDADES, na ordem dos hospitais.
#   - O estoque é DIFERENTE PARA CADA JOGADOR (sorteado com a chave dele + o hospital + o dia do jogo) e se renova a
#     cada DIA do jogo (48 min). O que você comprou some do seu estoque até o dia seguinte (vai no jogo salvo).
#   - Ela também COMPRA os seus itens (npc/precos.gd VENDA: 40% do preço, menos se estiver gasto).
# Mexa AQUI para: quantos itens, especialidades, o desconto e o que ela não vende.

const Itens := preload("res://inventario/itens.gd")
const Precos := preload("res://npc/precos.gd")
const Locais := preload("res://mundo/locais.gd")

const POR_CATEGORIA := 1                 # itens de cada categoria (todos os tipos)
const DA_ESPECIALIDADE := 7              # itens a mais da especialidade
const DESCONTO := 0.8                    # especialidade: 20% mais barato
const SOBRE := 1.15                      # o resto: 15% mais caro
const CATEGORIAS := ["arma", "branca", "municao", "pente", "acessorio", "medico", "comida", "bebida", "ferramenta", "roupa", "mochila"]
# [nome, categorias] na ordem dos hospitais em mundo/locais.gd
const ESPECIALIDADES := [["REMÉDIOS E COMIDA", ["medico", "comida", "bebida"]],
	["ARMAS E MUNIÇÃO", ["arma", "municao", "pente", "acessorio", "branca"]],
	["ROUPAS E MOCHILAS", ["roupa", "mochila"]],
	["FERRAMENTAS E CONSTRUÇÃO", ["ferramenta", "branca", "bebida"]]]
const NAO_VENDE := ["dinheiro", "cartao_bunker_1", "cartao_bunker_2", "cartao_bunker_3", "cartao_bunker_4", "agua_suja",
	"garrafa_vazia", "celular", "revista", "ursinho", "galho"]
# quantidade por linha (munição, tábuas...)
const PACOTE := {"municao": [10, 30], "tabuas": [3, 6], "trapos": [2, 4], "bandagem": [1, 3], "pastilha": [3, 6], "barra": [1, 3]}

# número do hospital (0, 1, 2, 3) pelo índice do local
static func numero(i_local: int) -> int:
	var n := 0
	for k in Locais.LOCAIS.size():
		if Locais.LOCAIS[k][0] == "hospital":
			if k == i_local:
				return n
			n += 1
	return 0

static func especialidade(i_local: int) -> Array:
	return ESPECIALIDADES[numero(i_local) % ESPECIALIDADES.size()]

static func _ids_da(cat: String) -> Array:
	var l: Array = []
	for id in Itens.DB:
		if str(Itens.DB[id].get("cat", "")) == cat and not id in NAO_VENDE:
			l.append(id)
	return l

# estoque de "chave" (o jogador) no hospital i_local no dia "dia": [{id, q, e, preco}]
static func estoque(i_local: int, chave: String, dia: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%d|%d" % [chave, i_local, dia])
	var esp: Array = especialidade(i_local)[1]
	var l: Array = []
	var cats: Array = CATEGORIAS.duplicate()
	for k in DA_ESPECIALIDADE:
		cats.append(esp[r.randi() % esp.size()])
	for cat in cats:
		var ids := _ids_da(cat)
		if ids.is_empty():
			continue
		var id: String = ids[r.randi() % ids.size()]
		var q := 1
		var pac: Array = PACOTE.get(id, PACOTE.get(cat, [1, 1]))
		q = r.randi_range(int(pac[0]), int(pac[1]))
		q = mini(q, maxi(1, int(Itens.def(id).get("max", 1))))
		var e := snappedf(r.randf_range(0.6, 1.0), 0.01)
		var mult := DESCONTO if cat in esp else SOBRE
		var preco := maxi(1, int(round(Precos.cheio(id) * q * lerpf(0.35, 1.0, e) * mult)))
		l.append({"id": id, "q": q, "e": e, "preco": preco, "esp": cat in esp})
	return l
