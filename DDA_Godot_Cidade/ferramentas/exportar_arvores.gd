extends SceneTree
# 1.19 · GRAVA ONDE FICAVAM AS ÁRVORES (as árvores saíram do jogo para serem refeitas com outros modelos).
# Monta a cidade (sem tela) e escreve data/arvores_lugares.json com cada lugar que mundo/cidade.gd e mundo/abandono.gd
# guardaram no lugar de plantar a árvore. A lista é a mesma toda vez (os sorteios da cidade não mudam).
# Rodar:  godot --headless -s res://ferramentas/exportar_arvores.gd     (DENSIDADE=0|1|2, padrão 1 = média)
# ATENÇÃO: as árvores da RUA dependem de Opções › "Densidade do cenário" (os carros largados vêm antes no mesmo
# sorteio); o arquivo é da densidade MÉDIA (a padrão). As dos parques e dos terrenos não mudam. No jogo,
# cidade.lugares_das_arvores() dá sempre os lugares da cidade montada (com a densidade de quem joga).
# Formato: {"campos": [...], "total": N, "por_origem": {...}, "lugares": [[origem, modelo, x, y, z, giro, escala,
#   escala_altura, cor], ...]}
#   origem: "rua" (calçadas, mundo/abandono.gd) · "parque" (parques) · "terreno" (árvores secas nos terrenos vazios)
#   modelo: o modelo de antes (arvore_1, arvore_3, arvore_4, arvore_seca_1/2, pinheiro_1/2, arvore_grande; nas ruas
#   arvore_1, arvore_4 e arvore_seca_2) · giro em radianos (em volta do eixo vertical) · cor = tom da copa (hex)
const SAIDA := "res://data/arvores_lugares.json"

func _initialize() -> void:
	var den := int(OS.get_environment("DENSIDADE")) if OS.get_environment("DENSIDADE") != "" else 1
	var cfg = root.get_node_or_null("Config")
	if cfg != null:
		cfg.g["den"] = den                       # mundo/cidade.gd _abandono_comecar lê daqui
	var C = load("res://mundo/cidade.gd").new()
	root.add_child(C)
	await process_frame                          # dentro da árvore: a cidade lê a densidade do Config
	await C.construir()
	var lugares: Array = C.lugares_das_arvores()
	var por := {}
	for l in lugares:
		por[l[0]] = int(por.get(l[0], 0)) + 1
	var d := {"campos": ["origem", "modelo", "x", "y", "z", "giro", "escala", "escala_altura", "cor"],
		"densidade_do_cenario": ["baixa", "média", "alta"][clampi(den, 0, 2)],
		"total": lugares.size(), "por_origem": por, "lugares": lugares}
	var f := FileAccess.open(SAIDA, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	print("ÁRVORES: %d lugares gravados em %s (%s)" % [lugares.size(), SAIDA, str(por)])
	quit()
