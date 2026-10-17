extends Node3D
# ITEM JOGADO NO CHÃO. Aparece na coluna da ESQUERDA do inventário quando o jogador está perto.
# Armas usam o mesmo modelo 3D das armas do jogador; equipamentos com modelo 3D (capacete, boné, gorro,
# lanterna de cabeça, mochilas, pochete: equipamentos/modelos_equip.gd) aparecem com ele; comida, remédios,
# ferramentas e munição usam os modelos realistas de inventario/modelos_itens.gd; o resto vira uma caixinha
# da cor da categoria.
# Criar por código: ItemMundo.soltar(pai, item, posicao)

const Itens := preload("res://inventario/itens.gd")
const ModelosArmas := preload("res://armas/modelos_armas.gd")
const Equip := preload("res://equipamentos/modelos_equip.gd")
const ModelosItens := preload("res://inventario/modelos_itens.gd")

var item = null               # item.gd

# MULTIJOGADOR (rede/sessao_rede.gd liga os ganchos): cada item no chão tem um "uid" igual em todos os aparelhos.
#   ao_soltar(no): alguém LARGOU um item aqui -> a sessão dá um uid novo e avisa os outros (item_solto)
#   ao_pegar(item): alguém PEGOU um item do chão aqui -> a sessão avisa os outros (item_pego), que tiram o item
# Itens que nascem iguais em todo aparelho (chão dos prédios, loot da base) já vêm com uid fixo e não avisam.
static var por_uid := {}                     # uid -> nó (os itens no chão deste aparelho)
static var ao_soltar := Callable()
static var ao_pegar := Callable()

static func soltar(pai: Node, it, pos: Vector3, avisar := true) -> Node3D:
	var n: Node3D = load("res://inventario/item_mundo.gd").new()
	n.item = it
	it.no_mundo = n
	it.onde = null
	it.slot = ""
	pai.add_child(n)
	n.global_position = pos
	n.rotation.y = randf() * TAU
	if avisar and ao_soltar.is_valid():
		ao_soltar.call(n)
	if it.uid != "":
		por_uid[it.uid] = n
	return n

static func pegou(it) -> void:
	if it.uid != "":
		if ao_pegar.is_valid():
			ao_pegar.call(it)
		por_uid.erase(it.uid)

func _exit_tree() -> void:
	if item != null and item.uid != "" and por_uid.get(item.uid) == self:
		por_uid.erase(item.uid)

func _ready() -> void:
	add_to_group("itens_chao")
	name = "Item_" + item.id
	var d: Dictionary = item.def()
	if item.eh_arma():
		var m := ModelosArmas.construir(d["arma"])
		var cano := m.get_node_or_null("Cano")
		if cano != null:
			cano.free()
		m.rotation.z = PI * 0.5           # deitada de lado
		m.position.y = 0.03
		add_child(m)
		return
	var eq := Equip.instancia(item.id) if Equip.tem(item.id) else null
	if eq != null:
		if item.id.begins_with("mochila") or item.id == "pochete":
			eq.rotation.x = -PI * 0.5            # mochila deitada de costas no chão
			eq.position.y = 0.1
		add_child(eq)
		return
	var mod := ModelosItens.instancia(item.id) if ModelosItens.tem(item.id) else null
	if mod != null:
		add_child(mod)
		return
	var w := float(d["w"]) * 0.09
	var h := float(d["h"]) * 0.09
	var alto := 0.08
	if d.has("grade"):
		alto = 0.18
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, alto, h)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Itens.cor(item.id)
	mat.roughness = 0.9
	bm.material = mat
	mi.mesh = bm
	mi.position.y = alto * 0.5
	add_child(mi)
