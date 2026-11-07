extends SceneTree
# TESTE DO LOOT QUE VOLTA (0.72, sem tela): ciclo de cada lugar, item do jogador fica, local especial mais rápido,
# chão com uid novo por ciclo, salvar/carregar com o ciclo.
var h := 5.0
var _feito := false
func _process(_dt):
	if _feito: return false
	_feito = true
	_teste()
	return false
func _teste():
	var LM = load("res://mundo/loot_mundo.gd")
	var lm = LM.new()
	lm.semente = 42
	lm.relogio = func() -> float: return h
	var falhas := 0
	var id := "p5_1"
	var g = lm.grade(id, "mercado", "PRATELEIRA", Vector2i(6, 4), 0.0)
	var n0: int = g.itens.size()
	print("sorteio 1: ", n0)
	for it in g.itens.duplicate(): g.remover(it)
	g = lm.grade(id, "mercado", "PRATELEIRA", Vector2i(6, 4), 0.0)
	if g.itens.size() != 0: falhas += 1; print("FALHA: voltou no mesmo ciclo")
	h += 16.5
	g = lm.grade(id, "mercado", "PRATELEIRA", Vector2i(6, 4), 0.0)
	print("depois de 16.5 h: ", g.itens.size())
	if g.itens.size() == 0: falhas += 1; print("FALHA: não voltou")
	# item do jogador fica e conta
	var meu = load("res://inventario/item.gd").novo("pistola", 1)
	for it in g.itens.duplicate(): g.remover(it)
	var v: Vector3i = g.achar_vaga(meu); g.colocar(meu, v.x, v.y, v.z == 1)
	h += 16.5
	g = lm.grade(id, "mercado", "PRATELEIRA", Vector2i(6, 4), 0.0)
	if not g.itens.has(meu): falhas += 1; print("FALHA: apagou o item do jogador")
	if g.itens.size() > 4: falhas += 1; print("FALHA: passou do máximo")
	print("com item do jogador: ", g.itens.size())
	# local especial: ciclo mais curto
	var gl = lm.grade("L3_2", "posto_loja", "BALCÃO", Vector2i(6, 4), 0.0)
	for it in gl.itens.duplicate(): gl.remover(it)
	h += 10.5
	gl = lm.grade("L3_2", "posto_loja", "BALCÃO", Vector2i(6, 4), 0.0)
	if gl.itens.size() == 0: falhas += 1; print("FALHA: local não voltou em 10.5 h")
	# chão
	var pai := Node3D.new(); root.add_child(pai)
	var pontos := []
	for k in 20: pontos.append([Vector3(k * 1.5, 0, 0), 0])
	lm.espalhar_chao("p5", "residencial", pontos, pai)
	var soltos := 0
	var uids := []
	for c in pai.get_children():
		if c.is_in_group("itens_chao"): soltos += 1; uids.append(c.item.uid)
	print("chão 1: ", soltos, " ", uids)
	for c in pai.get_children(): pai.remove_child(c); c.free()       # pegou tudo
	lm.guardar_chao("p5", pai)
	lm.espalhar_chao("p5", "residencial", pontos, pai)
	if pai.get_child_count() != 0: falhas += 1; print("FALHA: chão voltou no mesmo ciclo")
	lm.guardar_chao("p5", pai)
	h += 16.5
	lm.espalhar_chao("p5", "residencial", pontos, pai)
	uids = []
	for c in pai.get_children(): uids.append(c.item.uid)
	print("chão depois: ", uids)
	if uids.is_empty() or not str(uids[0]).count(":") == 2: falhas += 1; print("FALHA: chão novo sem uid do ciclo")
	# salvar/carregar mantém o ciclo
	g = lm.grade(id, "mercado", "PRATELEIRA", Vector2i(6, 4), 0.0)
	var sv: Dictionary = JSON.parse_string(JSON.stringify(lm.salvar()))
	var lm2 = LM.new(); lm2.relogio = func() -> float: return h
	lm2.carregar(sv)
	var g2 = lm2.grade(id, "mercado", "PRATELEIRA", Vector2i(6, 4), 0.0)
	if g2.itens.size() != g.itens.size(): falhas += 1; print("FALHA: carregar mudou a grade ", g2.itens.size(), " ", g.itens.size())
	print("falhas: ", falhas)
	quit()
