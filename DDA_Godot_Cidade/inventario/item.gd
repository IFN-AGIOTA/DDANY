extends RefCounted
# UM ITEM (instância). O tipo vem de itens.gd (DB). Um item está em UM lugar por vez:
#   onde ......... a grade (grade.gd) em que ele está guardado, ou null
#   slot ......... o lugar do corpo em que está vestido/na mão ("maos", "mochila", ...), ou ""
#   no_mundo ..... o nó 3D (item_mundo.gd) quando está jogado no chão, ou null
# Quem move itens de um lugar para outro é o inventario.gd (ele cuida de tirar do lugar antigo).

const Itens := preload("res://inventario/itens.gd")
const GradeCls := preload("res://inventario/grade.gd")

var id := ""
var qtd := 1
var municao := 0              # armas: balas no pente
var x := 0                    # posição na grade (célula do canto de cima à esquerda)
var y := 0
var rot := false              # girado 90° na grade (troca largura e altura)
var conteudo = null           # grade.gd com o que está dentro (roupas e mochilas)
var onde:                     # referência fraca (a grade já guarda o item; evita ciclo que vaza memória)
	get:
		return _onde.get_ref() if _onde != null else null
	set(v):
		_onde = weakref(v) if v != null else null
var _onde: WeakRef = null
var slot := ""
var no_mundo: Node = null

static func novo(tipo: String, quantidade := 1) -> RefCounted:
	var d := Itens.def(tipo)
	if d.is_empty():
		push_error("item desconhecido: " + tipo)
		return null
	var it = load("res://inventario/item.gd").new()
	it.id = tipo
	it.qtd = clampi(quantidade, 1, int(d.get("max", 1)))
	it.municao = int(d.get("pente", 0))
	if d.has("grade"):
		var g: Array = d["grade"]
		it.conteudo = GradeCls.new(int(g[0]), int(g[1]), d["nome"], it)
	return it

func def() -> Dictionary:
	return Itens.def(id)

func nome() -> String:
	return def().get("nome", id)

func largura() -> int:
	return int(def()["h"]) if rot else int(def()["w"])

func altura() -> int:
	return int(def()["w"]) if rot else int(def()["h"])

func tam(girado: bool) -> Vector2i:
	var d := def()
	return Vector2i(int(d["h"]), int(d["w"])) if girado else Vector2i(int(d["w"]), int(d["h"]))

func max_pilha() -> int:
	return int(def().get("max", 1))

func empilha_com(outro) -> bool:
	return outro != null and outro != self and outro.id == id and max_pilha() > 1

func eh_arma() -> bool:
	return def().has("arma")

func tem_conteudo() -> bool:
	return conteudo != null and not conteudo.itens.is_empty()

# peso total (kg), contando o que tem dentro
func peso() -> float:
	var p := float(def().get("peso", 0.0)) * qtd
	if conteudo != null:
		p += conteudo.peso()
	if eh_arma():
		var m: Dictionary = Itens.def(def().get("municao", ""))
		p += float(m.get("peso", 0.0)) * municao
	return p

# texto pequeno no canto do ícone (quantidade / balas)
func rotulo() -> String:
	if eh_arma():
		return str(municao)
	if max_pilha() > 1:
		return str(qtd)
	return ""
