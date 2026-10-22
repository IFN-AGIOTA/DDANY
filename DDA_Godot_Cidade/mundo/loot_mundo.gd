extends RefCounted
# LOOT DA CIDADE (estilo DayZ): o que aparece em cada móvel, no chão dos prédios e nos porta-malas dos carros.
# Cada lugar tem uma TABELA (abaixo). O conteúdo é sorteado na 1ª vez que o prédio é aberto, sempre igual para o
# mesmo lugar (semente = id do lugar), e depois fica GUARDADO: o que você pegou não volta, o que você deixou fica.
# Cidade abandonada: muita coisa já foi saqueada (CHANCE_VAZIO).
# Mexa AQUI para: o que aparece em cada lugar, raridade (peso), quantidades, estado dos itens e quão vazia a cidade está.

const ItemCls := preload("res://inventario/item.gd")
const GradeCls := preload("res://inventario/grade.gd")
const ItemMundoCls := preload("res://inventario/item_mundo.gd")
const Itens := preload("res://inventario/itens.gd")

const CHANCE_VAZIO := 0.35            # móvel já saqueado
const CHANCE_CHAO := 0.45             # chance de cada ponto livre do chão ter alguma coisa
const MAX_CHAO := 4                   # itens soltos por prédio

# [id, peso (raridade relativa), qtd mínima, qtd máxima]
const TABELAS := {
	"casa_sala": [["revista", 4, 1, 1], ["ursinho", 2, 1, 1], ["celular", 3, 1, 1], ["dinheiro", 3, 2, 12], ["bone", 2, 1, 1],
		["barra", 3, 1, 2], ["salgadinho", 3, 1, 1], ["refrigerante", 3, 1, 1], ["isqueiro", 2, 1, 1], ["lanterna", 2, 1, 1],
		["mun_9mm", 1, 4, 12], ["taco", 1, 1, 1]],
	"casa_quarto": [["camiseta", 5, 1, 1], ["moletom", 4, 1, 1], ["jeans", 4, 1, 1], ["gorro", 3, 1, 1], ["bone", 2, 1, 1],
		["jaqueta", 2, 1, 1], ["capa_chuva", 1, 1, 1], ["mochila_escolar", 2, 1, 1], ["mochila_trilha", 1, 1, 1], ["pochete", 2, 1, 1], ["trapos", 3, 1, 3],
		["kit_costura", 2, 1, 1], ["pistola", 1, 1, 1], ["pente_pistola", 1, 1, 1], ["mun_9mm", 2, 5, 15], ["dinheiro", 2, 2, 10],
		["revista", 2, 1, 1], ["ursinho", 2, 1, 1], ["lanterna_cabeca", 1, 1, 1], ["taco", 1, 1, 1]],
	"casa_cozinha": [["feijao", 5, 1, 1], ["atum", 4, 1, 1], ["sardinha", 4, 1, 1], ["pessego", 3, 1, 1], ["biscoito", 4, 1, 1], ["leite_condensado", 2, 1, 1],
		["barra", 2, 1, 3], ["agua", 3, 1, 1], ["refrigerante", 3, 1, 1], ["suco", 3, 1, 1], ["faca", 2, 1, 1], ["isqueiro", 2, 1, 1],
		["fita", 1, 1, 1], ["garrafa_vazia", 2, 1, 1], ["carvao", 1, 1, 1]],
	"geladeira": [["agua", 5, 1, 1], ["refrigerante", 5, 1, 1], ["suco", 4, 1, 1], ["maca", 3, 1, 1], ["pessego", 2, 1, 1]],
	"banheiro": [["bandagem", 4, 1, 2], ["analgesico", 4, 1, 1], ["vitaminas", 3, 1, 1], ["antibiotico", 1, 1, 1],
		["trapos", 3, 1, 2], ["kit_medico", 1, 1, 1], ["carvao", 2, 1, 1], ["pastilha", 2, 2, 6]],
	"mercado": [["feijao", 6, 1, 1], ["atum", 5, 1, 1], ["sardinha", 5, 1, 1], ["pessego", 4, 1, 1], ["biscoito", 5, 1, 1], ["leite_condensado", 3, 1, 1],
		["barra", 4, 1, 3], ["salgadinho", 4, 1, 1], ["agua", 6, 1, 1], ["refrigerante", 5, 1, 1], ["suco", 4, 1, 1], ["maca", 2, 1, 1],
		["fita", 2, 1, 1], ["isqueiro", 2, 1, 1], ["lanterna", 1, 1, 1], ["kit_costura", 1, 1, 1]],
	"farmacia": [["bandagem", 6, 1, 4], ["analgesico", 5, 1, 1], ["vitaminas", 5, 1, 1], ["antibiotico", 3, 1, 1], ["soro", 2, 1, 1],
		["kit_medico", 2, 1, 1], ["trapos", 2, 1, 3], ["agua", 2, 1, 1], ["barra", 2, 1, 2], ["carvao", 3, 1, 1],
		["pastilha", 3, 2, 8], ["tala", 1, 1, 1]],
	"loja": [["lanterna", 3, 1, 1], ["lanterna_cabeca", 2, 1, 1], ["isqueiro", 3, 1, 1], ["fita", 3, 1, 1], ["corda", 2, 1, 1],
		["radio", 2, 1, 1], ["kit_costura", 2, 1, 1], ["pochete", 2, 1, 1], ["mochila_escolar", 2, 1, 1], ["mochila_trilha", 1, 1, 1],
		["pe_de_cabra", 1, 1, 1], ["machado", 1, 1, 1], ["facao", 1, 1, 1], ["celular", 2, 1, 1], ["barra", 2, 1, 2], ["refrigerante", 2, 1, 1]],
	"loja_roupas": [["camiseta", 5, 1, 1], ["moletom", 5, 1, 1], ["jeans", 5, 1, 1], ["calca", 3, 1, 1], ["jaqueta", 3, 1, 1],
		["capa_chuva", 3, 1, 1], ["gorro", 4, 1, 1], ["bone", 4, 1, 1], ["mochila_escolar", 2, 1, 1], ["mochila_trilha", 2, 1, 1],
		["pochete", 2, 1, 1]],
	"balcao": [["dinheiro", 5, 2, 20], ["revista", 2, 1, 1], ["celular", 2, 1, 1], ["barra", 3, 1, 2], ["refrigerante", 2, 1, 1],
		["isqueiro", 2, 1, 1], ["pistola", 1, 1, 1], ["mun_9mm", 2, 4, 12], ["fita", 1, 1, 1]],
	"escritorio": [["revista", 4, 1, 1], ["celular", 3, 1, 1], ["dinheiro", 3, 2, 10], ["barra", 2, 1, 2], ["fita", 2, 1, 1],
		["lanterna", 2, 1, 1], ["radio", 1, 1, 1], ["analgesico", 1, 1, 1], ["refrigerante", 2, 1, 1]],
	"armas_policia": [["pistola", 4, 1, 1], ["pente_pistola", 5, 1, 1], ["mun_9mm", 6, 10, 40], ["espingarda", 2, 1, 1],
		["mun_12", 4, 4, 16], ["m4", 1, 1, 1], ["mp5", 1, 1, 1], ["pente_mp5", 2, 1, 1], ["pente_stanag", 2, 1, 1], ["mun_556", 2, 10, 40], ["colete_policia", 2, 1, 1],
		["capacete", 1, 1, 1], ["lanterna", 2, 1, 1], ["kit_armas", 2, 1, 1], ["bandagem", 2, 1, 2], ["silenciador", 1, 1, 1],
		["ak", 1, 1, 1], ["pente_ak", 1, 1, 1], ["mun_762", 1, 8, 30], ["mira_acog", 1, 1, 1]],
	"deposito": [["corda", 3, 1, 1], ["fita", 3, 1, 1], ["cano", 3, 1, 1], ["pe_de_cabra", 2, 1, 1], ["machado", 2, 1, 1], ["facao", 2, 1, 1],
		["lanterna", 2, 1, 1], ["trapos", 3, 1, 4], ["agua", 2, 1, 1], ["feijao", 2, 1, 1], ["kit_armas", 1, 1, 1],
		["mochila_trilha", 1, 1, 1], ["mun_308", 1, 3, 10], ["rifle_caca", 1, 1, 1], ["galho", 3, 1, 4], ["isqueiro", 1, 1, 1],
		["luneta", 1, 1, 1], ["mun_762", 1, 5, 15]],
	"carro": [["agua", 3, 1, 1], ["refrigerante", 2, 1, 1], ["biscoito", 2, 1, 1], ["barra", 2, 1, 2], ["lanterna", 2, 1, 1],
		["fita", 2, 1, 1], ["corda", 2, 1, 1], ["pe_de_cabra", 2, 1, 1], ["kit_medico", 1, 1, 1], ["bandagem", 2, 1, 2],
		["mochila_escolar", 2, 1, 1], ["jaqueta", 1, 1, 1], ["capa_chuva", 1, 1, 1], ["taco", 1, 1, 1], ["espingarda", 1, 1, 1],
		["mun_12", 1, 4, 10], ["rifle_caca", 1, 1, 1], ["mun_308", 1, 3, 8], ["kit_armas", 1, 1, 1], ["dinheiro", 1, 2, 10],
		["ak", 1, 1, 1], ["pente_ak", 1, 1, 1], ["mun_762", 1, 5, 20], ["mochila_trilha", 1, 1, 1]],
	# caixa de SUPRIMENTO MILITAR (missões do rádio no modo livre)
	"militar": [["m4", 3, 1, 1], ["ak", 3, 1, 1], ["mp5", 2, 1, 1], ["pente_mp5", 3, 1, 1], ["pente_stanag", 4, 1, 1], ["pente_ak", 4, 1, 1], ["mun_556", 5, 20, 60],
		["mun_762", 5, 20, 50], ["colete", 3, 1, 1], ["colete_policia", 2, 1, 1], ["capacete", 3, 1, 1], ["mochila_combate", 2, 1, 1],
		["kit_medico", 4, 1, 1], ["soro", 2, 1, 1], ["antibiotico", 3, 1, 1], ["mira_acog", 2, 1, 1], ["silenciador", 2, 1, 1],
		["luneta", 1, 1, 1], ["rifle_caca", 1, 1, 1], ["mun_308", 2, 5, 15], ["kit_armas", 3, 1, 1], ["agua", 3, 1, 1], ["feijao", 3, 1, 1], ["facao", 2, 1, 1],
		["leite_condensado", 2, 1, 1]],
	# itens soltos no chão dos prédios, por uso do prédio
	"chao_residencial": [["galho", 2, 1, 3], ["garrafa_vazia", 2, 1, 1], ["revista", 3, 1, 1], ["trapos", 3, 1, 2], ["barra", 2, 1, 1], ["refrigerante", 2, 1, 1], ["agua", 1, 1, 1],
		["cano", 1, 1, 1], ["faca", 1, 1, 1], ["mun_9mm", 1, 3, 8], ["celular", 2, 1, 1], ["ursinho", 1, 1, 1]],
	"chao_comercio": [["garrafa_vazia", 3, 1, 1], ["galho", 1, 1, 2], ["refrigerante", 3, 1, 1], ["salgadinho", 3, 1, 1], ["biscoito", 2, 1, 1], ["dinheiro", 3, 1, 8],
		["revista", 2, 1, 1], ["cano", 2, 1, 1], ["trapos", 2, 1, 2], ["agua", 1, 1, 1]],
	"chao_saude": [["bandagem", 4, 1, 2], ["trapos", 3, 1, 2], ["analgesico", 2, 1, 1], ["soro", 1, 1, 1], ["agua", 1, 1, 1]],
	"chao_policia": [["mun_9mm", 4, 3, 12], ["mun_12", 2, 2, 6], ["pente_pistola", 1, 1, 1], ["bandagem", 2, 1, 1],
		["lanterna", 2, 1, 1], ["cano", 1, 1, 1]],
}
const CHAO_DO_USO := {"residencial": "chao_residencial", "loja": "chao_comercio", "mercado": "chao_comercio",
	"restaurante": "chao_comercio", "escritorio": "chao_comercio", "farmacia": "chao_saude", "clinica": "chao_saude",
	"delegacia": "chao_policia"}

var semente := 1234                   # muda o loot do mundo inteiro (salvo junto com o jogo)
var _grades := {}                     # id do lugar -> grade (já sorteada; o que o jogador mexeu fica aqui)
var _chao := {}                       # id do prédio -> [[item.gd, Vector3 local], ...] (itens soltos ainda não pegos)
# multijogador (rede/sessao_rede.gd): uids dos itens fixos (chão dos prédios "p12:3", base "base:2") que alguém já
# pegou: não aparecem mais em nenhum aparelho · grade_criada avisa a sessão quando um móvel é sorteado (conteúdo base)
var pegos := {}
var grade_criada := Callable()

# grade de um móvel / porta-malas (sorteada na 1ª vez, depois a mesma)
func grade(id: String, tabela: String, nome: String, tam: Vector2i):
	if _grades.has(id):
		var g0 = _grades[id]
		g0.nome = nome
		return g0
	var g = GradeCls.new(tam.x, tam.y, nome, null)
	var r := RandomNumberGenerator.new()
	r.seed = hash(id) ^ semente
	if r.randf() >= CHANCE_VAZIO:
		var n := r.randi_range(1, clampi(tam.x * tam.y / 5, 1, 4))
		for k in n:
			# só sorteia o que cabe no móvel; se a grade já estiver cheia, tenta outro item (até 3 vezes)
			for tentativa in 3:
				var it = _sortear(tabela, r, tam)
				if it == null:
					break
				var v: Vector3i = g.achar_vaga(it)
				if v.x >= 0:
					g.colocar(it, v.x, v.y, v.z == 1)
					break
	_grades[id] = g
	if grade_criada.is_valid():
		grade_criada.call(id, g)
	return g

# itens soltos no chão de um prédio (pontos = meta "pontos_chao" do interior: [[Vector3 local, cômodo], ...])
func espalhar_chao(id: String, uso: String, pontos: Array, pai: Node3D) -> void:
	if not _chao.has(id):
		var lista := []
		var r := RandomNumberGenerator.new()
		r.seed = hash(id + "chao") ^ semente
		var tabela: String = CHAO_DO_USO.get(uso, "chao_residencial")
		for p in pontos:
			if lista.size() >= MAX_CHAO:
				break
			if r.randf() < CHANCE_CHAO:
				var it = _sortear(tabela, r)
				if it != null:
					it.uid = "%s:%d" % [id, lista.size()]     # igual em todos os aparelhos (mesma semente)
					lista.append([it, p[0]])
		_chao[id] = lista
	for par in _chao[id]:
		var it = par[0]
		if it.no_mundo != null or it.onde != null or it.slot != "" or pegos.has(it.uid):
			continue
		ItemMundoCls.soltar(pai, it, pai.global_transform * (par[1] as Vector3), false)
	_chao[id] = []                    # agora os itens estão no mundo; ao fechar o prédio, guardar_chao devolve

# o prédio vai fechar: guarda o que ainda está no chão dele (posição local)
func guardar_chao(id: String, pai: Node3D) -> void:
	var lista := []
	for n in pai.get_children():
		if n.is_in_group("itens_chao") and not n.is_queued_for_deletion() and n.item != null:
			var it = n.item
			it.no_mundo = null
			lista.append([it, pai.global_transform.affine_inverse() * n.global_position])
	_chao[id] = lista

# ---------- multijogador: conteúdo das grades pela rede ----------
# "assinatura" curta do conteúdo (muda quando alguém põe/tira/gira/gasta algo)
static func assinatura(g) -> String:
	var s := PackedStringArray()
	for it in g.itens:
		s.append("%s,%d,%d,%d,%d,%d" % [it.id, it.qtd, it.x, it.y, int(it.rot), it.municao])
	return "|".join(s)

static func conteudo(g) -> Array:
	var l := []
	for it in g.itens:
		l.append(it.para_dict())
	return l

# troca o conteúdo da grade "id" pelo que veio da rede (cria a grade se este aparelho ainda não abriu o lugar)
func definir_conteudo(id: String, larg: int, alt: int, nome: String, itens: Array):
	var g = _grades.get(id)
	if g == null:
		g = GradeCls.new(larg, alt, nome, null)
		_grades[id] = g
	for it in g.itens.duplicate():
		g.remover(it)
	for od in itens:
		var it = ItemCls.de_dict(od)
		if it != null:
			g.colocar(it, it.x, it.y, it.rot)
	return g

func _sortear(tabela: String, r: RandomNumberGenerator, tam := Vector2i(99, 99)):
	var t: Array = []
	for e in TABELAS.get(tabela, []):            # só o que cabe no móvel (deitado ou em pé)
		var d := Itens.def(e[0])
		var w := int(d.get("w", 1))
		var h := int(d.get("h", 1))
		if (w <= tam.x and h <= tam.y) or (h <= tam.x and w <= tam.y):
			t.append(e)
	var total := 0.0
	for e in t:
		total += float(e[1])
	if total <= 0.0:
		return null
	var x := r.randf() * total
	for e in t:
		x -= float(e[1])
		if x <= 0.0:
			if Itens.def(e[0]).is_empty():
				return null
			var it = ItemCls.novo(e[0], r.randi_range(int(e[2]), int(e[3])))
			_estado_inicial(it, r)
			return it
	return null

# cidade abandonada: as coisas não estão novas; armas vêm com o pente pela metade (ou sem) e munição solta
func _estado_inicial(it, r: RandomNumberGenerator) -> void:
	var x := r.randf()
	it.estado = 1.0 if x < 0.3 else (r.randf_range(0.55, 0.95) if x < 0.75 else r.randf_range(0.2, 0.55))
	if it.eh_arma_de_fogo():
		if it.usa_pente() != "":
			if r.randf() < 0.4:
				it.pente_id = ""
				it.municao = 0
			else:
				it.municao = r.randi_range(0, it.capacidade())
		else:
			it.municao = r.randi_range(0, it.capacidade() / 2)
	elif it.eh_pente():
		it.municao = r.randi_range(0, it.capacidade())

# ---------- salvar ----------
# abertos = interiores.abertos (índice -> nó): o que está no chão dos prédios abertos AGORA também é salvo
# (sem mexer nos itens, que continuam no mundo)
func salvar(abertos := {}) -> Dictionary:
	var g := {}
	for id in _grades:
		var lista := []
		for it in _grades[id].itens:
			lista.append(it.para_dict())
		g[id] = lista
	var c := {}
	for id in _chao:
		var lista := []
		for par in _chao[id]:
			var p: Vector3 = par[1]
			lista.append([par[0].para_dict(), p.x, p.y, p.z])
		c[id] = lista
	for i in abertos:
		var no: Node3D = abertos[i]
		if not is_instance_valid(no):
			continue
		var lista := []
		for n in no.get_children():
			if n.is_in_group("itens_chao") and not n.is_queued_for_deletion() and n.item != null:
				var p: Vector3 = no.global_transform.affine_inverse() * n.global_position
				lista.append([n.item.para_dict(), p.x, p.y, p.z])
		c["p%d" % i] = lista
	return {"semente": semente, "grades": g, "chao": c}

func carregar(d: Dictionary) -> void:
	semente = int(d.get("semente", semente))
	_grades.clear()
	_chao.clear()
	var g: Dictionary = d.get("grades", {})
	for id in g:
		var gr = GradeCls.new(12, 12, "", null)
		for od in g[id]:
			var it = ItemCls.de_dict(od)
			if it != null:
				gr.colocar(it, it.x, it.y, it.rot)
		_grades[id] = gr
	var c: Dictionary = d.get("chao", {})
	for id in c:
		var lista := []
		for e in c[id]:
			var it = ItemCls.de_dict(e[0])
			if it != null:
				lista.append([it, Vector3(e[1], e[2], e[3])])
		_chao[id] = lista
