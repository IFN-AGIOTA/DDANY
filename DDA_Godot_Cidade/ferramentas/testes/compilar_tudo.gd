extends SceneTree
# COMPILA TODOS OS SCRIPTS DO JOGO (0.74): carrega cada .gd do projeto (menos ferramentas/) e lista os que têm erro.
# Rápido, sem tela: godot --headless -s res://ferramentas/testes/compilar_tudo.gd

func _initialize() -> void:
	var lista: Array[String] = []
	_achar("res://", lista)
	var ruins: Array[String] = []
	for f in lista:
		var s = load(f)
		if s == null or not (s as Script).can_instantiate():
			ruins.append(f)
	print("scripts: %d · com erro: %s" % [lista.size(), str(ruins)])
	print("falhas: %d" % ruins.size())
	quit(1 if not ruins.is_empty() else 0)

func _achar(pasta: String, lista: Array[String]) -> void:
	for d in DirAccess.get_directories_at(pasta):
		if d.begins_with(".") or d in ["ferramentas", "addons"]:
			continue
		_achar(pasta.path_join(d), lista)
	for f in DirAccess.get_files_at(pasta):
		if f.ends_with(".gd"):
			lista.append(pasta.path_join(f))
