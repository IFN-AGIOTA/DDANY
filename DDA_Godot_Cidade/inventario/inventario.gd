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
signal animar(nome: String)          # pede uma animação ao corpo do jogador (pegar do chão, comer, curar...)

const Sons := preload("res://audio/sons.gd")
const Itens := preload("res://inventario/itens.gd")
const ItemCls := preload("res://inventario/item.gd")
const ItemMundo := preload("res://inventario/item_mundo.gd")
const GradeCls := preload("res://inventario/grade.gd")
const FogueiraCls := preload("res://mundo/fogueira.gd")

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
	_por(calca.conteudo, ItemCls.novo("mun_9mm", 36))
	_por(calca.conteudo, ItemCls.novo("pente_pistola"))
	_por(calca.conteudo, ItemCls.novo("faca"))
	_por(colete.conteudo, ItemCls.novo("bandagem", 2))
	_por(colete.conteudo, ItemCls.novo("radio"))
	_por(pochete.conteudo, ItemCls.novo("agua"))
	# começa só com a pistola: fuzis, munição de fuzil e equipamento melhor são achados na cidade
	# (armários da polícia, depósitos, carros e as caixas de SUPRIMENTO MILITAR que o rádio anuncia)
	var pistola = ItemCls.novo("pistola")
	slots["maos"] = pistola
	pistola.slot = "maos"
	atalhos[0] = pistola
	atalhos[1] = null
	atalhos[2] = jaq.conteudo.itens[0]      # ataduras
	mudou.emit()

# ---------- salvar / carregar ----------
func salvar() -> Dictionary:
	var sl := {}
	for s in slots:
		if slots[s] != null:
			sl[s] = slots[s].para_dict()
	var at := []
	for a in atalhos:
		at.append(_caminho(a) if a != null else [])
	return {"slots": sl, "atalhos": at}

func carregar(d: Dictionary) -> void:
	for s in slots:
		if slots[s] != null:
			slots[s].slot = ""
		slots[s] = null
	var sl: Dictionary = d.get("slots", {})
	for s in sl:
		if slots.has(s):
			var it = ItemCls.de_dict(sl[s])
			if it != null:
				slots[s] = it
				it.slot = s
	var at: Array = d.get("atalhos", [])
	for i in N_ATALHOS:
		atalhos[i] = _achar_caminho(at[i]) if i < at.size() else null
	mudou.emit()

# caminho de um item no corpo: [slot, índice na grade, índice na grade de dentro...]
func _caminho(it) -> Array:
	var c := []
	var a = it
	for _i in 8:
		if a == null:
			return []
		if a.slot != "":
			c.push_front(a.slot)
			return c
		var g = a.onde
		if g == null:
			return []
		c.push_front(g.itens.find(a))
		a = g.dono
		if not (a is RefCounted):
			return []
	return []

func _achar_caminho(c) -> Variant:
	if not (c is Array) or c.is_empty() or not slots.has(c[0]):
		return null
	var it = slots[c[0]]
	for k in range(1, c.size()):
		if it == null or it.conteudo == null:
			return null
		var i := int(c[k])
		if i < 0 or i >= it.conteudo.itens.size():
			return null
		it = it.conteudo.itens[i]
	return it

# tira tudo do corpo (morte: vai tudo para o chão junto do corpo)
func esvaziar() -> Array:
	var r := []
	for s in slots:
		if slots[s] != null:
			r.append(slots[s])
			slots[s].slot = ""
			slots[s] = null
	for i in N_ATALHOS:
		atalhos[i] = null
	mudou.emit()
	return r

# equipamento de quem acabou de renascer (como no DayZ: quase nada)
func equipamento_renascer() -> void:
	var cam = ItemCls.novo("camiseta")
	var jeans = ItemCls.novo("jeans")
	cam.estado = randf_range(0.5, 0.9)
	jeans.estado = randf_range(0.5, 0.9)
	slots["camisa"] = cam
	cam.slot = "camisa"
	slots["calca"] = jeans
	jeans.slot = "calca"
	_por(cam.conteudo, ItemCls.novo("trapos", 2))
	_por(jeans.conteudo, ItemCls.novo("lanterna"))
	_por(jeans.conteudo, ItemCls.novo("maca"))
	atalhos[0] = cam.conteudo.itens[0] if not cam.conteudo.itens.is_empty() else null
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
		ItemMundo.pegou(it)                  # multijogador: some do chão dos outros também
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
	Sons.tocar("inventario/pegar", -12.0)
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
	if s != "maos":
		Sons.tocar("inventario/vestir", -6.0)      # na mão: o som é o de sacar (armas/armas.gd)
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
	Sons.tocar("inventario/vestir", -9.0, 0.92)
	_depois()
	return true

func largar(it) -> bool:
	if it.no_mundo != null:
		return false
	retirar(it)
	_soltar_no_chao(it)
	Sons.tocar("inventario/largar", -6.0)
	_depois()
	return true

# pegar do chão / de uma caixa (duplo toque na coluna da esquerda ou botão PEGAR)
func pegar(it) -> bool:
	if it == null or do_jogador(it):
		return false
	animar.emit("pegar_chao" if it.no_mundo != null else "pegar")
	Sons.tocar("inventario/pegar", -5.0)
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

# 0.59: animação de usar cada item (jogador/animador_modelo.gd acao()): comer, beber, tomar remédio, curativo
const COMPRIMIDOS := ["analgesico", "vitaminas", "antibiotico", "carvao"]
func _anim_de_uso(it) -> String:
	match String(it.def().get("cat", "")):
		"comida": return "comer"
		"bebida": return "beber"
	if it.id in COMPRIMIDOS:
		return "tomar_remedio"
	return "usar_item"

func usar(it) -> void:
	var d: Dictionary = it.def()
	if it.id == "agua_suja" and perto_do_fogo():
		it.id = "agua"                  # perto da fogueira, USAR = FERVER
		aviso.emit("FERVEU A ÁGUA")
		_depois()
		return
	if d.get("consome", false):
		animar.emit(_anim_de_uso(it) + ":" + it.id)          # o corpo mostra o item na mão (animador acao())
		var sv = jogador.get("sobrevivencia")
		if sv != null and d.has("efeito"):
			var r: String = sv.aplicar(d["efeito"], it.id, it.estado)
			if r != "":
				aviso.emit(r)           # ex.: "NADA PARA CONSERTAR" (o item não é gasto)
				return
		aviso.emit(String(d.get("usar", "Usou " + it.nome())).to_upper())
		match String(d.get("cat", "")):
			"comida":
				Sons.tocar("inventario/comer", -4.0)
			"bebida":
				Sons.tocar("inventario/beber", -5.0)
			_:
				Sons.tocar("inventario/atadura" if it.id in ["bandagem", "trapos", "kit_medico", "tala"] else "inventario/pegar", -5.0)
		if d.has("vira") and it.qtd <= 1:
			it.id = d["vira"]           # a garrafa fica vazia no mesmo lugar
			it.estado = maxf(it.estado, 0.5)
			_depois()
			return
		it.qtd -= 1
		if it.qtd <= 0:
			retirar(it)
		_depois()
	elif it.id == "garrafa_vazia":
		encher_garrafa(it)

	elif it.eh_pente():
		encher_pente(it)
	elif it.eh_arma_de_fogo() and (it.pente_id != "" or not it.acessorios.is_empty()) and it.slot == "maos":
		desmontar(it)
	elif it.slot != "maos":
		equipar(it, "maos")

# texto do botão USAR para este item (a tela do inventário mostra)
func nome_acao(it) -> String:
	if it == null:
		return "USAR"
	var d: Dictionary = it.def()
	if it.id == "garrafa_vazia":
		return "ENCHER"
	if it.id == "agua_suja" and perto_do_fogo():
		return "FERVER"
	if d.get("consome", false):
		return {"comida": "COMER", "bebida": "BEBER"}.get(d.get("cat", ""), "USAR")
	if it.eh_pente():
		return "ENCHER"
	if it.eh_arma_de_fogo() and (it.pente_id != "" or not it.acessorios.is_empty()) and it.slot == "maos":
		return "DESMONTAR"
	return "NA MÃO"

# ---------- água e fogo ----------
func perto_do_fogo() -> bool:
	for f in get_tree().get_nodes_in_group("fogueiras"):
		if is_instance_valid(f) and f.acesa and (f as Node3D).global_position.distance_to(jogador.global_position) < 4.5:
			return true
	return false

# de onde dá para pegar água aqui: "limpa" (pia/torneira dos prédios), "suja" (lago), "salgada" (mar) ou ""
# torneiras: só ~30% ainda têm água (sorteado por prédio/móvel), e cada uma dá poucas garrafas
const CHANCE_TORNEIRA := 0.3
const ENCHIDAS_TORNEIRA := 3
var _torneiras := {}                  # chave do móvel -> garrafas que ainda dá para encher
var _torneira_atual := ""

func _torneira(c) -> String:
	var chave: String = String(c.get("id_loot")) if String(c.get("id_loot")) != "" else str(Vector3i((c as Node3D).global_position.round()))
	if not _torneiras.has(chave):
		var sem := 0
		var cena = get_tree().current_scene
		if cena != null and cena.get("loot_mundo") != null:
			sem = int(cena.loot_mundo.semente)
		var r := RandomNumberGenerator.new()
		r.seed = hash(chave) ^ sem
		_torneiras[chave] = ENCHIDAS_TORNEIRA if r.randf() < CHANCE_TORNEIRA else 0
	return chave

func fonte_de_agua() -> String:
	var seca := false
	for c in conteineres_perto():
		var n: String = String(c.nome)
		if "COZINHA" in n or "BANHEIRO" in n or "PIA" in n:
			if int(_torneiras.get(_torneira(c), 0)) > 0:
				_torneira_atual = _torneira(c)
				return "limpa"
			seca = true
	var mundo = jogador.get("mundo")
	if mundo == null:
		return ""
	var p := jogador.global_position
	var tipo := ""
	for k in 9:
		var a := TAU * k / 8.0
		var r := 0.0 if k == 8 else 2.5
		var h: float = mundo.altura(p.x + cos(a) * r, p.z + sin(a) * r)
		if absf(h - 0.2) < 0.01:
			return "suja"
		if h < -0.3:
			tipo = "salgada"
	return tipo if tipo != "" or not seca else "seca"

func encher_garrafa(g) -> void:
	match fonte_de_agua():
		"limpa":
			g.id = "agua"
			_torneiras[_torneira_atual] = int(_torneiras.get(_torneira_atual, 1)) - 1
			aviso.emit("ENCHEU COM ÁGUA DA TORNEIRA" if int(_torneiras[_torneira_atual]) > 0 else "ENCHEU · A TORNEIRA SECOU")
		"seca":
			aviso.emit("A TORNEIRA ESTÁ SECA")
		"suja":
			g.id = "agua_suja"
			aviso.emit("ENCHEU COM ÁGUA DO LAGO (SUJA)")
		"salgada":
			aviso.emit("ÁGUA DO MAR NÃO SERVE")
			return
		_:
			aviso.emit("PRECISA DE UM LAGO OU UMA PIA PERTO")
			return
	_depois()

# ---------- crafting (arrastar um item em cima de outro) ----------
# faca/machado + roupa = trapos · 2 trapos + galho = tala · faca + galho = lança · isqueiro + 3 galhos = fogueira
# pastilha + água suja = água
func _receita(it, alvo) -> String:
	var a: String = it.id
	var b: String = alvo.id
	var corta := ["faca", "facao", "machado"]
	if a in corta and alvo.def().get("cat", "") == "roupa" and not alvo.tem_conteudo() and alvo.slot == "":
		return "rasgar"
	if a in corta and b == "galho":
		return "lanca"
	if a == "trapos" and b == "galho" and it.qtd >= 2:
		return "tala"
	if a == "galho" and b == "trapos" and alvo.qtd >= 2:
		return "tala"
	if a == "isqueiro" and b == "galho" and alvo.qtd >= 3:
		return "fogueira"
	if a == "pastilha" and b == "agua_suja":
		return "purificar"
	return ""

func _fazer(receita: String, it, alvo) -> void:
	match receita:
		"rasgar":
			var n := clampi(int(alvo.def()["w"]) * int(alvo.def()["h"]) / 3, 1, 4)
			var orig := _origem(alvo)
			retirar(alvo)
			var t = ItemCls.novo("trapos", n)
			_guardar_em_algum_lugar(t, orig)
			aviso.emit("RASGOU EM %d TRAPOS" % n)
		"lanca":
			var orig := _origem(alvo)
			_gastar(alvo, 1)
			var l = ItemCls.novo("lanca")
			if it.id == "faca":
				retirar(it)                 # a faca vai amarrada na ponta
			_guardar_em_algum_lugar(l, orig)
			aviso.emit("FEZ UMA LANÇA")
		"tala":
			var tr = it if it.id == "trapos" else alvo
			var ga = alvo if it.id == "trapos" else it
			var orig := _origem(ga)
			_gastar(tr, 2)
			_gastar(ga, 1)
			_guardar_em_algum_lugar(ItemCls.novo("tala"), orig)
			aviso.emit("FEZ UMA TALA")
		"fogueira":
			_gastar(alvo, 3)
			var f = FogueiraCls.new()
			var pai := jogador.get_parent()
			pai.add_child(f)
			var fwd := -jogador.global_basis.z
			f.global_position = jogador.global_position + Vector3(fwd.x, 0.0, fwd.z).normalized() * 1.3
			aviso.emit("ACENDEU UMA FOGUEIRA")
		"purificar":
			alvo.id = "agua"
			_gastar(it, 1)
			aviso.emit("ÁGUA PURIFICADA")
	_depois()

func _gastar(it, n: int) -> void:
	it.qtd -= n
	if it.qtd <= 0:
		retirar(it)

# ---------- pentes, munição e acessórios (estilo DayZ) ----------
# enche o pente com a munição solta que o jogador carrega
func encher_pente(p) -> bool:
	var falta: int = p.capacidade() - p.municao
	if falta <= 0:
		aviso.emit("PENTE CHEIO")
		return false
	var n := consumir(String(p.def()["pente_de"]), falta)
	if n <= 0:
		aviso.emit("SEM MUNIÇÃO " + String(Itens.def(p.def()["pente_de"]).get("sigla", "")))
		return false
	p.municao += n
	Sons.tocar("armas/bala_pente", -4.0)
	aviso.emit("PENTE %d/%d" % [p.municao, p.capacidade()])
	_depois()
	return true

# tira o pente e os acessórios da arma (vão para o inventário ou para o chão)
func desmontar(arma) -> void:
	if arma.pente_id != "":
		var pe = ItemCls.novo(arma.pente_id)
		pe.municao = arma.municao
		arma.municao = 0
		arma.pente_id = ""
		_guardar_ou_largar(pe)
	for k in arma.acessorios.keys():
		_guardar_ou_largar(ItemCls.novo(arma.acessorios[k]))
	arma.acessorios.clear()
	aviso.emit("ARMA DESMONTADA")
	_depois()

func _guardar_ou_largar(it) -> void:
	if not _guardar_auto(it):
		_soltar_no_chao(it)

# soltar o item "it" em cima de "alvo" faz algo? (munição -> pente/arma, pente -> arma, acessório -> arma)
func pode_combinar(it, alvo) -> bool:
	if it == null or alvo == null or it == alvo:
		return false
	if _receita(it, alvo) != "":
		return true
	var da: Dictionary = alvo.def()
	if it.def().get("cat", "") == "municao":
		if alvo.eh_pente():
			return da["pente_de"] == it.id and alvo.municao < alvo.capacidade()
		if alvo.eh_arma_de_fogo() and alvo.usa_pente() == "":
			return da.get("municao", "") == it.id and alvo.municao < alvo.capacidade()
		return false
	if it.eh_pente():
		return alvo.eh_arma_de_fogo() and alvo.usa_pente() == it.id
	var enc: String = it.def().get("encaixe", "")
	if enc != "":
		return alvo.eh_arma_de_fogo() and da.get("arma", "") in it.def().get("serve", []) and enc in da.get("acess", [])
	return false

func combinar(it, alvo) -> bool:
	if not pode_combinar(it, alvo):
		return false
	var rec := _receita(it, alvo)
	if rec != "":
		_fazer(rec, it, alvo)
		return true
	if it.def().get("cat", "") == "municao":
		var n := mini(it.qtd, alvo.capacidade() - alvo.municao)
		alvo.municao += n
		it.qtd -= n
		if it.qtd <= 0:
			retirar(it)
		aviso.emit("%d/%d" % [alvo.municao, alvo.capacidade()])
	elif it.eh_pente():
		var orig := _origem(it)
		retirar(it)
		var antigo = null
		if alvo.pente_id != "":
			antigo = ItemCls.novo(alvo.pente_id)
			antigo.municao = alvo.municao
		alvo.pente_id = it.id
		alvo.municao = it.municao
		if antigo != null:
			_guardar_em_algum_lugar(antigo, orig)
		aviso.emit("PENTE ENCAIXADO")
	else:
		var enc: String = it.def()["encaixe"]
		var orig := _origem(it)
		retirar(it)
		var antigo: String = alvo.acessorios.get(enc, "")
		alvo.acessorios[enc] = it.id
		if antigo != "":
			_guardar_em_algum_lugar(ItemCls.novo(antigo), orig)
		aviso.emit(it.nome() + " ENCAIXADO")
	_depois()
	return true

# recarga estilo DayZ: troca pelo pente mais cheio que você carrega (o vazio volta para o lugar dele);
# sem pente cheio, enche o pente encaixado com munição solta. Armas sem pente puxam munição solta.
# devolve quantas balas a arma vai ter (-1 = nada a fazer)
func pente_para_recarga(arma):
	var tipo: String = arma.usa_pente()
	var melhor = null
	for g in grades_do_jogador():
		for o in g.itens:
			if o.id == tipo and o.municao > arma.municao and (melhor == null or o.municao > melhor.municao):
				melhor = o
	return melhor

func trocar_pente(arma, novo) -> void:
	var orig := _origem(novo)
	retirar(novo)
	if arma.pente_id != "":
		var velho = ItemCls.novo(arma.pente_id)
		velho.municao = arma.municao
		_guardar_em_algum_lugar(velho, orig)
	arma.pente_id = novo.id
	arma.municao = novo.municao
	_depois()

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
