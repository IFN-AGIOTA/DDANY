extends RefCounted
# LOOT ESPALHADO NO MUNDO: itens jogados no chão e caixas/armários com coisas dentro.
# Mexa AQUI para: o que aparece, onde e em que quantidade. (Os TIPOS de item ficam em inventario/itens.gd.)
# Posições são relativas ao centro passado (x = leste, y = sul, em metros).

const CaixaMundoCls := preload("res://inventario/caixa_mundo.gd")
const ItemMundoCls := preload("res://inventario/item_mundo.gd")
const ItemCls := preload("res://inventario/item.gd")

# itens soltos: [id, quantidade, posição]
const CHAO_BASE := [
	["mochila_escolar", 1, Vector2(1.4, 1.6)], ["ursinho", 1, Vector2(1.0, 2.1)], ["feijao", 1, Vector2(1.8, 2.2)],
	["agua", 1, Vector2(1.2, 2.5)], ["mun_9mm", 24, Vector2(1.9, 1.3)], ["corda", 1, Vector2(0.8, 1.4)],
]

# caixas: nome, tamanho da grade, posição e conteúdo [id, quantidade]
const CAIXAS_BASE := [
	{"nome": "CAIXA MILITAR", "tamanho": Vector2i(8, 6), "pos": Vector2(-1.2, 2.0),
		"itens": [["bone", 1], ["bandagem", 3], ["mun_9mm", 30], ["pente_pistola", 1], ["vitaminas", 1], ["isqueiro", 1], ["feijao", 1]]},
]

# loot de teste ao lado de onde o jogador nasce (base militar)
static func espalhar(pai: Node, mundo, centro: Vector2) -> void:
	for c in CHAO_BASE:
		var p: Vector2 = centro + c[2]
		ItemMundoCls.soltar(pai, ItemCls.novo(c[0], c[1]), Vector3(p.x, mundo.altura(p.x, p.y), p.y))
	for d in CAIXAS_BASE:
		var caixa = CaixaMundoCls.new()
		caixa.name = String(d["nome"]).replace(" ", "_")
		caixa.nome = d["nome"]
		caixa.tamanho = d["tamanho"]
		var pc: Vector2 = centro + d["pos"]
		pai.add_child(caixa)
		caixa.global_position = Vector3(pc.x, mundo.altura(pc.x, pc.y), pc.y)
		for c in d["itens"]:
			caixa.guardar(ItemCls.novo(c[0], c[1]))
