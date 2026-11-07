extends SceneTree
# GERA menu/novidades_lista.gd (a lista da tela NOVIDADES do menu) a partir dos blocos "ATUALIZAÇÃO X · TÍTULO" da
# seção 2 do LEIA-ME.txt. Fica só o que muda para o jogador: as listas de ARQUIVOS e as linhas de TESTES ficam de
# fora, e os nomes de arquivo entre parênteses somem. Rodar a cada atualização, depois de escrever o bloco novo:
#   godot --headless -s res://ferramentas/gerar_novidades.gd

const SAIDA := "res://menu/novidades_lista.gd"

func _initialize() -> void:
	var f := FileAccess.open("res://LEIA-ME.txt", FileAccess.READ)
	var linhas := f.get_as_text().split("\n")
	f.close()
	var cab := RegEx.new()
	cab.compile("^(GRANDE )?ATUALIZAÇÃO ([0-9]+\\.[0-9]+(\\.[0-9]+)?)\\s*(·\\s*)?(.*)$")
	var arquivo := RegEx.new()
	arquivo.compile("\\s*\\([^()]*\\.(gd|res|tscn|png|txt|cfg|json)[^()]*\\)")
	var lista: Array = []
	var atual = null
	var cortado := false
	var pulando := -1                        # indentação da linha de teste que está sendo pulada
	var em_branco := false
	for i in linhas.size():
		var l: String = linhas[i].rstrip(" \r")
		if l.begins_with("3. CONTROLES"):
			break
		var m := cab.search(l)
		if m != null:
			atual = [m.get_string(2), _titulo(m.get_string(5)), []]
			lista.append(atual)
			cortado = false
			pulando = -1
			em_branco = false
			continue
		if atual == null or cortado:
			continue
		if l.strip_edges() == "":
			em_branco = true
			continue
		var ind := l.length() - l.lstrip(" ").length()
		var t := l.strip_edges()
		# depois de uma linha em branco, texto sem recuo que não é item = acabou o bloco
		if em_branco and ind == 0 and not (t.begins_with("-") or t.begins_with("·")):
			cortado = true
			continue
		em_branco = false
		var tu := t.to_upper()
		if tu.begins_with("ARQUIVOS") or tu.begins_with("· ARQUIVOS") or tu.begins_with("- ARQUIVOS"):
			cortado = true
			continue
		if pulando >= 0:
			if ind > pulando:
				continue
			pulando = -1
		# linha de testes: um item que começa com "Teste..." (as linhas que continuam o item vão junto)
		if tu.begins_with("· TESTE") or tu.begins_with("- TESTE") or tu.begins_with("· TESTAD") or tu.begins_with("- TESTAD") \
				or (ind <= 2 and (tu.begins_with("TESTADO") or tu.begins_with("TESTES"))):
			pulando = ind
			continue
		(atual[2] as Array).append([ind, arquivo.sub(t, "", true)])
	# texto de cada uma: itens ("·" / "-") viram "•", as linhas que continuam o item são juntadas a ele
	var saida: Array = []
	for a in lista:
		var itens: Array = []
		var base := 99
		for p in a[2]:
			base = mini(base, int(p[0]))
		for p in a[2]:
			var t: String = p[1]
			var novo := t.begins_with("·") or t.begins_with("-")
			if novo or itens.is_empty():
				var recuo := int(p[0]) - base
				var marca := "• " if recuo <= 1 else "    – "
				itens.append(marca + (t.substr(1).strip_edges() if novo else t))
			else:
				itens[itens.size() - 1] += " " + t
		saida.append([a[0], a[1], itens])
	saida.sort_custom(func(x, y): return _num(x[0]) > _num(y[0]))
	var g := FileAccess.open(SAIDA, FileAccess.WRITE)
	g.store_string("extends RefCounted\n# LISTA DAS NOVIDADES (tela menu/tela_novidades.gd): GERADA por ferramentas/gerar_novidades.gd a partir do\n# LEIA-ME.txt. Não edite à mão: escreva o bloco no LEIA-ME e rode a ferramenta.\n# [versão, título, [itens]] da mais nova para a mais antiga\n\nconst LISTA := " + var_to_str(saida) + "\n")
	g.close()
	print("NOVIDADES: %d atualizações -> %s (mais nova %s, mais antiga %s)" % [saida.size(), SAIDA, saida[0][0], saida[-1][0]])
	quit()

static func _titulo(t: String) -> String:
	t = t.strip_edges()
	for fim in ["(resumo do que mudou)"]:
		t = t.replace(fim, "").strip_edges()
	return t if t != "" else "GRANDE ATUALIZAÇÃO"

# "0.92.1" -> 0.920001 (para ordenar)
static func _num(v: String) -> float:
	var p := v.split(".")
	var n := 0.0
	if p.size() > 0: n += float(p[0]) * 1000000.0
	if p.size() > 1: n += float(p[1]) * 1000.0
	if p.size() > 2: n += float(p[2])
	return n
