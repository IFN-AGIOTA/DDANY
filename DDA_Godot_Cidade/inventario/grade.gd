extends RefCounted
# GRADE DE CÉLULAS (bolsos de roupa, mochila, caixa no mundo ou o "chão" perto do jogador).
# Só sabe onde cada item está e se cabe; quem decide as regras de mover é o inventario.gd.

var largura := 1
var altura := 1
var nome := ""
var dono:                     # item.gd (roupa/mochila) ou Node (caixa no mundo) a quem a grade pertence
	get:
		return _dono.get_ref() if _dono != null else null
	set(v):
		_dono = weakref(v) if v != null else null
var _dono: WeakRef = null
var chao := false             # grade "virtual" do chão: só mostra os itens jogados perto, não é dona deles
var itens: Array = []

func _init(w := 1, h := 1, n := "", d = null) -> void:
	largura = w
	altura = h
	nome = n
	dono = d

func celulas_usadas() -> int:
	var n := 0
	for it in itens:
		n += it.largura() * it.altura()
	return n

func peso() -> float:
	var p := 0.0
	for it in itens:
		p += it.peso()
	return p

func item_em(cx: int, cy: int):
	for it in itens:
		if cx >= it.x and cx < it.x + it.largura() and cy >= it.y and cy < it.y + it.altura():
			return it
	return null

# o item cabe com o canto em (cx, cy)? "ignorar" = o próprio item quando ele só muda de lugar na mesma grade
func cabe(it, cx: int, cy: int, girado: bool, ignorar = null) -> bool:
	var t: Vector2i = it.tam(girado)
	if cx < 0 or cy < 0 or cx + t.x > largura or cy + t.y > altura:
		return false
	for o in itens:
		if o == ignorar:
			continue
		if cx < o.x + o.largura() and cx + t.x > o.x and cy < o.y + o.altura() and cy + t.y > o.y:
			return false
	return true

# primeira vaga livre (de cima para baixo, da esquerda para a direita; tenta girado também)
# devolve Vector3i(x, y, girado 0/1) ou Vector3i(-1, -1, 0) se não couber
func achar_vaga(it, ignorar = null) -> Vector3i:
	for g in [it.rot, not it.rot]:
		var t: Vector2i = it.tam(g)
		if t.x > largura or t.y > altura:
			continue
		for cy in range(0, altura - t.y + 1):
			for cx in range(0, largura - t.x + 1):
				if cabe(it, cx, cy, g, ignorar):
					return Vector3i(cx, cy, 1 if g else 0)
	return Vector3i(-1, -1, 0)

func colocar(it, cx: int, cy: int, girado: bool) -> void:
	it.x = cx
	it.y = cy
	it.rot = girado
	if not chao:
		it.onde = self
	if not itens.has(it):
		itens.append(it)

func remover(it) -> void:
	itens.erase(it)
	if it.onde == self:
		it.onde = null

# grade do chão: arruma os itens do chão em uma grade que cresce para baixo (só para mostrar)
func empacotar(lista: Array) -> void:
	itens.clear()
	var ordenados := lista.duplicate()
	ordenados.sort_custom(func(a, b): return a.tam(false).x * a.tam(false).y > b.tam(false).x * b.tam(false).y)
	altura = 3
	for it in ordenados:
		var v := achar_vaga(it)
		while v.x < 0 and altura < 60:
			altura += 1
			v = achar_vaga(it)
		if v.x >= 0:
			colocar(it, v.x, v.y, v.z == 1)
	var fundo := 0
	for it in itens:
		fundo = maxi(fundo, it.y + it.altura())
	altura = maxi(3, fundo + 2)       # sempre sobra espaço para largar coisas
