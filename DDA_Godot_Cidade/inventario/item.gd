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
var municao := 0              # armas: balas no pente encaixado (ou no tambor) · pentes: balas guardadas
var estado := 1.0             # 1 = perfeito ... 0 = arruinado (veja Itens.nome_estado)
var pente_id := ""            # armas com pente: qual pente está encaixado ("" = sem pente)
var acessorios := {}          # armas: encaixe ("cano"/"mira") -> id do acessório
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
var uid := ""                 # multijogador: identidade do item no CHÃO (inventario/item_mundo.gd); "" = não está na rede

static func novo(tipo: String, quantidade := 1) -> RefCounted:
	var d := Itens.def(tipo)
	if d.is_empty():
		push_error("item desconhecido: " + tipo)
		return null
	var it = load("res://inventario/item.gd").new()
	it.id = tipo
	it.qtd = clampi(quantidade, 1, int(d.get("max", 1)))
	it.municao = int(d.get("pente", 0))
	it.pente_id = String(d.get("usa_pente", ""))
	if d.has("cap"):
		it.municao = int(d["cap"])
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

func eh_arma_de_fogo() -> bool:
	return def().has("municao") and def().has("arma")

func eh_pente() -> bool:
	return def().has("pente_de")

func usa_pente() -> String:
	return String(def().get("usa_pente", ""))

# balas que cabem: pente = "cap" · arma sem pente = "pente" · arma com pente = capacidade do pente encaixado
func capacidade() -> int:
	var d := def()
	if d.has("cap"):
		return int(d["cap"])
	if d.has("usa_pente"):
		return int(Itens.def(pente_id).get("cap", 0)) if pente_id != "" else 0
	return int(d.get("pente", 0))

func tem_conteudo() -> bool:
	return conteudo != null and not conteudo.itens.is_empty()

# peso total (kg), contando o que tem dentro
func peso() -> float:
	var p := float(def().get("peso", 0.0)) * qtd
	if conteudo != null:
		p += conteudo.peso()
	var mid: String = def().get("municao", def().get("pente_de", ""))
	if mid != "":
		p += float(Itens.def(mid).get("peso", 0.0)) * municao
	if pente_id != "":
		p += float(Itens.def(pente_id).get("peso", 0.0))
	for k in acessorios:
		p += float(Itens.def(acessorios[k]).get("peso", 0.0))
	return p

# texto pequeno no canto do ícone (quantidade / balas)
func rotulo() -> String:
	if eh_arma_de_fogo():
		if usa_pente() != "" and pente_id == "":
			return "—"
		return str(municao)
	if eh_pente():
		return "%d/%d" % [municao, capacidade()]
	if max_pilha() > 1:
		return str(qtd)
	return ""

# ---------- salvar / carregar (jogo salvo e loot guardado dos prédios) ----------
func para_dict() -> Dictionary:
	var d := {"id": id, "q": qtd, "x": x, "y": y}
	if rot:
		d["r"] = 1
	if municao != 0:
		d["m"] = municao
	if estado < 1.0:
		d["e"] = snappedf(estado, 0.01)
	if pente_id != "":
		d["p"] = pente_id
	if not acessorios.is_empty():
		d["a"] = acessorios.duplicate()
	if conteudo != null and not conteudo.itens.is_empty():
		var lista := []
		for o in conteudo.itens:
			lista.append(o.para_dict())
		d["c"] = lista
	return d

static func de_dict(d: Dictionary) -> RefCounted:
	var it = novo(String(d.get("id", "")), int(d.get("q", 1)))
	if it == null:
		return null
	it.qtd = int(d.get("q", 1))
	it.x = int(d.get("x", 0))
	it.y = int(d.get("y", 0))
	it.rot = d.has("r")
	it.municao = int(d.get("m", 0))
	it.estado = float(d.get("e", 1.0))
	it.pente_id = String(d.get("p", ""))
	it.acessorios = (d.get("a", {}) as Dictionary).duplicate()
	if it.conteudo != null:
		for od in d.get("c", []):
			var o = de_dict(od)
			if o != null and it.conteudo.cabe(o, o.x, o.y, o.rot):
				it.conteudo.colocar(o, o.x, o.y, o.rot)
	return it
