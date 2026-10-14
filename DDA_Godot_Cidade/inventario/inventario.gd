extends Node
# INVENTÁRIO DO JOGADOR (estilo DayZ). Filho do Jogador; é ele que move TODOS os itens (do corpo, das
# mochilas, das caixas do mundo e do chão), para as regras ficarem num lugar só:
#   - cada item ocupa w x h células; dá para girar; pilhas iguais se juntam (munição, ataduras)
#   - roupa/mochila COM coisas dentro não entra em outra grade (só no corpo, na mão ou no chão)
#   - nada entra dentro de si mesmo
#   - trocar o que está na MÃO devolve o item antigo ao coldre/ombro, ao lugar de onde o novo veio,
#     a qualquer vaga do inventário ou, por último, ao chão
# Atalhos (1..8) só apontam para itens que o jogador carrega (como na barra do DayZ).

signal mudou
signal aviso(texto: String)

const Itens := preload("res://inventario/itens.gd")
const ItemCls := preload("res://inventario/item.gd")
const ItemMundo := preload("res://inventario/item_mundo.gd")

const CONTEINERES_CORPO := ["camisa", "calca", "colete", "cinto", "mochila"]   # ordem na coluna da direita
const ARMAS_CORPO := ["coldre", "ombro"]
const RAIO_PERTO := 2.2                # alcance para ver/pegar coisas do mundo (m)
const N_ATALHOS := 8

var slots := {}                        # slot -> item.gd ou null
var atalhos: Array = []                # N_ATALHOS itens (ou null)
var jogador: Node3D

func _ready() -> void:
	jogador = get_parent() as Node3D
	for s in Itens.SLOTS:
		slots[s] = null
	atalhos.resize(N_ATALHOS)

# ---------- equipamento inicial ----------
func equipamento_inicial() -> void:
	var jaq = ItemCls.novo("jaqueta")
	var calca = ItemCls.novo("calca")
	var colete = ItemCls.novo("colete")
	var pochete = ItemCls.novo("pochete")
	for par in [["camisa", jaq], ["calca", calca], ["colete", colete], ["cinto", pochete]]:
		slots[par[0]] = par[1]
		par[1].slot = par[0]
	_por(jaq.conteudo, ItemCls.novo("bandagem", 4))
	_por(jaq.conteudo, ItemCls.novo("vitaminas"))
	_por(jaq.conteudo, ItemCls.novo("fita"))
	_por(jaq.conteudo, ItemCls.novo("lanterna"))
	_por(calca.conteudo, ItemCls.novo("mun_9mm", 48))
	_por(calca.conteudo, ItemCls.novo("faca"))
	_por(colete.conteudo, ItemCls.novo("mun_556", 60))
	_por(colete.conteudo, ItemCls.novo("mun_556", 60))
	_por(pochete.conteudo, ItemCls.novo("agua"))
	var pistola = ItemCls.novo("pistola")
	var m4 = ItemCls.novo("m4")
	slots["maos"] = pistola
	pistola.slot = "maos"
	slots["ombro"] = m4
	m4.slot = "ombro"
	atalhos[0] = pistola
	atalhos[1] = m4
	atalhos[2] = jaq.conteudo.itens[0]      # ataduras
	mudou.emit()

func _por(g, it) -> void:
	var v: Vector3i = g.achar_vaga(it)
	if v.x >= 0:
		g.colocar(it, v.x, v.y, v.z == 1)

# ---------- consultas ----------
func grades_do_jogador() -> Array:
	var r := []
	for s in CONTEINERES_CORPO:
		var it = slots[s]
		if it != null and it.conteudo != null:
			r.append(it.conteudo)
	return r

# o item está com o jogador (vestido, na mão ou dentro de algo que ele veste)?
func do_jogador(it) -> bool:
	var a = it
	for _i in 16:
		if a == null:
			return false
		if a.slot != "":
			return true
		if a.onde == null:
			return false
		var d = a.onde.dono
		if not (d is RefCounted):
			return false          # caixa do mundo (Node) ou grade sem dono
		a = d
	return false

func peso_total() -> float:
	var p := 0.0
	for s in slots:
		if slots[s] != null:
			p += slots[s].peso()
	return p

func _perto(n: Node3D) -> bool:
	var d := n.global_position - jogador.global_position
	return Vector2(d.x, d.z).length() <= RAIO_PERTO and absf(d.y) < 2.5

func itens_perto() -> Array:
	var r := []
	for n in get_tree().get_nodes_in_group("itens_chao"):
		if is_instance_valid(n) and not n.is_queued_for_deletion() and n.item != null and _perto(n):
			r.append(n.item)
	return r

func conteineres_perto() -> Array:
	var r := []
	for n in get_tree().get_nodes_in_group("conteineres_mundo"):
		if is_instance_valid(n) and not n.is_queued_for_deletion() and _perto(n):
			r.append(n)
	return r

# item do chão mais perto (botão PEGAR)
func item_mais_proximo(raio := 1.6):
	var melhor = null
	var md := raio
	for n in get_tree().get_nodes_in_group("itens_chao"):
		if not is_instance_valid(n) or n.is_queued_for_deletion() or n.item == null:
			continue
		var d: Vector3 = n.global_position - jogador.global_position
		var l: float = Vector2(d.x, d.z).length()
		if l <= md and absf(d.y) < 2.0:
			md = l
			melhor = n.item
	return melhor

# muda quando aparece/some algo perto (a tela refaz a coluna da esquerda)
func assinatura_perto() -> String:
	var s := ""
	for it in itens_perto():
		s += str(it.get_instance_id()) + ","
	s += "|"
	for c in conteineres_perto():
		s += str(c.get_instance_id()) + ","
	return s

# ---------- regras ----------
func pode_ir_para_grade(it, g, cx: int, cy: int, girado: bool) -> bool:
	if g == null:
		return false
	if g.chao:
		return true
	if it.tem_conteudo():
		return false              # mochila/roupa cheia não vai dentro de outra coisa
	var d = g.dono
	for _i in 16:                 # nada entra dentro de si mesmo
		if d == it:
			return false
		if not (d is RefCounted) or d.onde == null:
			break
		d = d.onde.dono
	return g.cabe(it, cx, cy, girado, it if it.onde == g else null)

# pilha do mesmo tipo na célula (cx, cy) que ainda aceita unidades
func alvo_pilha(it, g, cx: int, cy: int):
	if g == null or g.chao:
		return null
	var o = g.item_em(cx, cy)
	if o != null and o.empilha_com(it) and o.qtd < o.max_pilha():
		return o
	return null

func pode_equipar(it, s: String) -> bool:
	if not slots.has(s) or it == null:
		return false
	if s == "maos":
		return true
	return it.def().get("slot", "") == s

# ---------- mover ----------
# tira o item de onde ele estiver (grade, corpo ou chão)
func retirar(it) -> void:
	if it.onde != null:
		it.onde.remover(it)
	if it.slot != "":
		if slots.get(it.slot) == it:
			slots[it.slot] = null
		it.slot = ""
	if it.no_mundo != null:
		var n: Node = it.no_mundo
		it.no_mundo = null
		if is_instance_valid(n):
			n.queue_free()

func _origem(it) -> Dictionary:
	return {"g": it.onde, "x": it.x, "y": it.y, "rot": it.rot, "slot": it.slot, "chao": it.no_mundo != null}

func mover_para_grade(it, g, cx: int, cy: int, girado: bool) -> bool:
	if g.chao:
		return largar(it)
	if not pode_ir_para_grade(it, g, cx, cy, girado):
		return false
	retirar(it)
	g.colocar(it, cx, cy, girado)
	_depois()
	return true

func juntar(it, alvo) -> bool:
	var n := mini(it.qtd, alvo.max_pilha() - alvo.qtd)
	if n <= 0 or not alvo.empilha_com(it):
		return false
	alvo.qtd += n
	it.qtd -= n
	if it.qtd <= 0:
		retirar(it)
	_depois()
	return true

func equipar(it, s: String) -> bool:
	if not pode_equipar(it, s):
		return false
	var antigo = slots[s]
	if antigo == it:
		return false
	var orig := _origem(it)
	retirar(it)
	if antigo != null:
		retirar(antigo)
	slots[s] = it
	it.slot = s
	if antigo != null:
		_guardar_em_algum_lugar(antigo, orig)
	_depois()
	return true

# tira do corpo: roupas/mochilas vão para o inventário; o que está na MÃO volta ao coldre/ombro se der
func desequipar(it) -> bool:
	if it.slot == "":
		return false
	var orig := _origem(it)
	var da_mao: bool = it.slot == "maos"
	retirar(it)
	if da_mao:
		_guardar_em_algum_lugar(it, {"g": null, "slot": "", "chao": false})
	elif not _guardar_auto(it):
		slots[orig["slot"]] = it          # não cabe em lugar nenhum: continua vestido
		it.slot = orig["slot"]
		aviso.emit("SEM ESPAÇO")
		return false
	_depois()
	return true

func largar(it) -> bool:
	if it.no_mundo != null:
		return false
	retirar(it)
	_soltar_no_chao(it)
	_depois()
	return true

# pegar do chão / de uma caixa (duplo toque na coluna da esquerda ou botão PEGAR)
func pegar(it) -> bool:
	if it == null or do_jogador(it):
		return false
	var pref: String = it.def().get("slot", "")
	if pref != "" and slots.get(pref) == null:
		retirar(it)
		slots[pref] = it
		it.slot = pref
		aviso.emit(it.nome())
		_depois()
		return true
	var antes: int = it.qtd
	if _empilhar_no_jogador(it):
		retirar(it)
		aviso.emit(it.nome())
		_depois()
		return true
	if not it.tem_conteudo():
		for g in grades_do_jogador():
			var v: Vector3i = g.achar_vaga(it)
			if v.x >= 0:
				retirar(it)
				g.colocar(it, v.x, v.y, v.z == 1)
				aviso.emit(it.nome())
				_depois()
				return true
	if slots["maos"] == null:
		retirar(it)
		slots["maos"] = it
		it.slot = "maos"
		aviso.emit(it.nome())
		_depois()
		return true
	aviso.emit("SEM ESPAÇO")
	if it.qtd != antes:
		_depois()
	return false

# duplo toque: chão/caixa -> pega · corpo -> guarda · inventário -> veste / usa / pega na mão
func acao_rapida(it) -> void:
	if it == null:
		return
	if not do_jogador(it):
		pegar(it)
	elif it.slot != "":
		desequipar(it)
	elif it.def().get("consome", false):
		usar(it)
	else:
		var pref: String = it.def().get("slot", "")
		if pref != "" and slots.get(pref) == null:
			equipar(it, pref)
		else:
			equipar(it, "maos")

func usar(it) -> void:
	var d: Dictionary = it.def()
	if d.get("consome", false):
		aviso.emit(String(d.get("usar", "Usou " + it.nome())).to_upper())
		it.qtd -= 1
		if it.qtd <= 0:
			retirar(it)
		_depois()
	elif it.slot != "maos":
		equipar(it, "maos")

# divide uma pilha ao meio (a metade nova vai para a mesma grade ou outra vaga do inventário)
func dividir(it) -> bool:
	if it.qtd < 2:
		return false
	var novo = ItemCls.novo(it.id, it.qtd / 2)
	var grades := []
	if it.onde != null:
		grades.append(it.onde)
	if do_jogador(it):
		grades.append_array(grades_do_jogador())
	for g in grades:
		var v: Vector3i = g.achar_vaga(novo)
		if v.x >= 0:
			it.qtd -= novo.qtd
			g.colocar(novo, v.x, v.y, v.z == 1)
			_depois()
			return true
	aviso.emit("SEM ESPAÇO")
	return false

# ---------- mão / armas / atalhos ----------
func usar_atalho(i: int) -> void:
	if i < 0 or i >= N_ATALHOS:
		return
	var it = atalhos[i]
	if it == null:
		return
	if it.slot == "maos":
		desequipar(it)                # apertar de novo guarda (coldre/ombro)
	elif it.def().get("consome", false):
		usar(it)
	else:
		equipar(it, "maos")

func atribuir_atalho(it, i: int) -> bool:
	if it == null or i < 0 or i >= N_ATALHOS or not do_jogador(it):
		return false
	for k in N_ATALHOS:
		if atalhos[k] == it:
			atalhos[k] = null
	atalhos[i] = it
	mudou.emit()
	return true

func limpar_atalho(i: int) -> void:
	if i >= 0 and i < N_ATALHOS:
		atalhos[i] = null
		mudou.emit()

# botão ARMA / rodinha do mouse: alterna entre as armas do coldre e do ombro
func trocar_arma() -> void:
	for s in ARMAS_CORPO:
		var a = slots[s]
		if a != null and a.eh_arma():
			equipar(a, "maos")
			return

func arma_na_mao():
	var it = slots["maos"]
	if it != null and it.eh_arma():
		return it
	return null

# ---------- munição (recarregar puxa do inventário) ----------
func contar(id: String) -> int:
	var n := 0
	for g in grades_do_jogador():
		for it in g.itens:
			if it.id == id:
				n += it.qtd
	var m = slots["maos"]
	if m != null and m.id == id:
		n += m.qtd
	return n

func consumir(id: String, quanto: int) -> int:
	var tirado := 0
	var fontes := []
	var m = slots["maos"]
	if m != null and m.id == id:
		fontes.append(m)
	for g in grades_do_jogador():
		for it in g.itens:
			if it.id == id:
				fontes.append(it)
	fontes.sort_custom(func(a, b): return a.qtd < b.qtd)   # gasta as pilhas pequenas primeiro
	for it in fontes:
		if tirado >= quanto:
			break
		var n := mini(it.qtd, quanto - tirado)
		it.qtd -= n
		tirado += n
		if it.qtd <= 0:
			retirar(it)
	if tirado > 0:
		_depois()
	return tirado

# ---------- internos ----------
func _empilhar_no_jogador(it) -> bool:
	if it.max_pilha() <= 1:
		return false
	for g in grades_do_jogador():
		for o in g.itens:
			if o.empilha_com(it) and o.qtd < o.max_pilha():
				var n := mini(it.qtd, o.max_pilha() - o.qtd)
				o.qtd += n
				it.qtd -= n
				if it.qtd <= 0:
					return true
	return false

func _guardar_auto(it) -> bool:
	if _empilhar_no_jogador(it):
		return true
	if it.tem_conteudo():
		return false
	for g in grades_do_jogador():
		if g == it.conteudo:
			continue
		var v: Vector3i = g.achar_vaga(it)
		if v.x >= 0:
			g.colocar(it, v.x, v.y, v.z == 1)
			return true
	return false

# para onde vai o item que saiu da mão/slot numa troca
func _guardar_em_algum_lugar(it, orig: Dictionary) -> void:
	var pref: String = it.def().get("slot", "")
	if pref != "" and slots.get(pref) == null:
		slots[pref] = it
		it.slot = pref
		return
	var s: String = orig.get("slot", "")
	if s != "" and slots.get(s) == null and pode_equipar(it, s):
		slots[s] = it
		it.slot = s
		return
	var g = orig.get("g")
	if g != null and not g.chao:
		if pode_ir_para_grade(it, g, orig["x"], orig["y"], orig["rot"]):
			g.colocar(it, orig["x"], orig["y"], orig["rot"])
			return
		if not it.tem_conteudo():
			var v: Vector3i = g.achar_vaga(it)
			if v.x >= 0 and pode_ir_para_grade(it, g, v.x, v.y, v.z == 1):
				g.colocar(it, v.x, v.y, v.z == 1)
				return
	if orig.get("chao", false):
		_soltar_no_chao(it)
		return
	if _guardar_auto(it):
		return
	_soltar_no_chao(it)

func _soltar_no_chao(it) -> void:
	var pai := jogador.get_parent()
	var a := randf() * TAU
	var r := randf_range(0.35, 0.8)
	var p := jogador.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	var mundo = jogador.get("mundo")
	var no_chao: bool = jogador.has_method("is_on_floor") and jogador.is_on_floor()
	if not no_chao and mundo != null and mundo.has_method("altura"):
		p.y = mundo.altura(p.x, p.z)      # no ar (pulando): cai no chão de baixo
	ItemMundo.soltar(pai, it, p)

func _depois() -> void:
	for i in N_ATALHOS:
		var a = atalhos[i]
		if a != null and (a.qtd <= 0 or not do_jogador(a)):
			atalhos[i] = null
	mudou.emit()
