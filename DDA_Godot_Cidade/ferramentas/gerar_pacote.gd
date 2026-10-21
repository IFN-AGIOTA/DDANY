extends SceneTree
# GERAR PACOTE / PUBLICAR APK no manifesto de atualizações (rede/atualizacoes.gd lê pelo GitHub).
# NÃO roda dentro do jogo. Saída: pasta "atualizacoes/" na raiz do repositório (fora da pasta do jogo), que vai
# para o GitHub junto com o commit:
#   atualizacoes/atualizacao.json   (o manifesto)
#   atualizacoes/pacote_X.pck       (cada pacote)
#
# PACOTE (conserto/ajuste/coisa nova sem reinstalar):
#   MODO=pacote VERSAO=0.47.1 NOTAS="Conserta X" ARQUIVOS="inimigos/vago.gd,mundo/cidade.gd" \
#     godot --headless -s res://ferramentas/gerar_pacote.gd
#   · cada arquivo listado entra no pacote no lugar do do APK. Scripts e cenas vão em texto + um ".remap" que aponta
#     para eles (o APK tem os scripts compilados .gdc). Texturas/modelos/sons: o ".import" e o arquivo importado
#     (.godot/imported/...): importe no editor antes.
#   · o pacote novo SUBSTITUI o anterior (só um fica valendo): ponha também os arquivos dos pacotes anteriores
#     do mesmo APK (ex.: o 0.49 leva os sons E o conserto do chão da 0.48.1).
#   · menu/config.gd entra sempre: ponha nele VERSAO = a mesma versão do pacote (no multijogador os dois aparelhos
#     precisam estar na mesma versão).
#   · REMOVER algo: troque o arquivo por um que não faz nada (ex.: tire a arma da lista de loot) e mande no pacote.
#   · não serve para: permissões/ícone/nome do app, plugins (WebRTC), versão da Godot, o rede/atualizador.gd e o
#     project.godot -> para isso, APK novo.
# APK novo (depois de exportar o APK e subir DiasDeUmApocalipse.apk na raiz do repositório):
#   MODO=apk VERSAO=0.48 NOTAS="..." godot --headless -s res://ferramentas/gerar_pacote.gd
#   · usa o version/code do export_presets.cfg (tem de ser igual ao rede/atualizador.gd CODIGO_APK) e tira o pacote
#     do manifesto (pacotes valem só para o APK em que foram feitos).
# Para TIRAR o pacote do ar (deu problema): MODO=tirar ... -> "pacote": null (os aparelhos apagam na próxima abertura).
# ASSINATURA: todo manifesto sai assinado com a chave PRIVADA dos pacotes (CHAVE_PACOTES=caminho do .pem; padrão
# ../chaves_privadas/chave_pacotes.pem, fora do GitHub). Sem ela não gera nada: o jogo ignora manifesto sem assinatura.

const RAMO := "claude/dayz-inventory-system-pckjpx"
const URL_BASE := "https://raw.githubusercontent.com/IFN-AGIOTA/DDANY/refs/heads/" + RAMO + "/"
const Atualizador := preload("res://rede/atualizador.gd")

func _initialize() -> void:
	var modo := OS.get_environment("MODO")
	var versao := OS.get_environment("VERSAO")
	var notas := OS.get_environment("NOTAS")
	var saida := OS.get_environment("SAIDA")
	var base := OS.get_environment("URL_BASE")    # testes: outro endereço (o padrão é o GitHub)
	if base == "":
		base = URL_BASE
	if saida == "":
		saida = ProjectSettings.globalize_path("res://").path_join("../atualizacoes").simplify_path()
	DirAccess.make_dir_recursive_absolute(saida)
	var codigo := _codigo_apk()
	if codigo != Atualizador.CODIGO_APK:
		printerr("ERRO: export_presets.cfg version/code = %d, mas rede/atualizador.gd CODIGO_APK = %d. Deixe iguais." % [codigo, Atualizador.CODIGO_APK])
		quit(1)
		return
	var chave := _chave()
	if chave == null:
		quit(1)
		return
	var man_arq := saida.path_join("atualizacao.json")
	var fora = JSON.parse_string(FileAccess.get_file_as_string(man_arq)) if FileAccess.file_exists(man_arq) else {}
	var man = JSON.parse_string(fora["dados"]) if fora is Dictionary and fora.get("dados") is String else {}
	if not (man is Dictionary):
		man = {}
	match modo:
		"pacote":
			if versao == "":
				printerr("ERRO: falta VERSAO")
				quit(1)
				return
			var lista := PackedStringArray()
			for a in OS.get_environment("ARQUIVOS").split(",", false):
				lista.append(a.strip_edges())
			if not "menu/config.gd" in lista:
				lista.append("menu/config.gd")
			if not ("VERSAO := \"%s\"" % versao) in FileAccess.get_file_as_string("res://menu/config.gd"):
				print("AVISO: menu/config.gd não está com VERSAO = \"%s\"" % versao)
			var nome := "pacote_%s.pck" % versao
			var caminho := saida.path_join(nome)
			var n := _montar(caminho, lista)
			if n < 0:
				quit(1)
				return
			var f := FileAccess.open(caminho, FileAccess.READ)
			var tam := f.get_length()
			f = null
			man["pacote"] = {"base": codigo, "versao": versao, "url": base + "atualizacoes/" + nome,
				"sha256": FileAccess.get_sha256(caminho), "tamanho": tam, "notas": notas, "arquivos": lista}
			print("pacote %s: %d arquivos, %d bytes -> %s" % [versao, n, tam, caminho])
		"apk":
			man["apk"] = {"codigo": codigo, "versao": versao, "url": base + "DiasDeUmApocalipse.apk", "notas": notas}
			man["pacote"] = null
			print("APK %s (código %d) publicado no manifesto" % [versao, codigo])
		"tirar":
			man["pacote"] = null
			print("pacote tirado do ar")
		_:
			printerr("MODO=pacote, apk ou tirar")
			quit(1)
			return
	var dados := JSON.stringify(man, "  ")
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(dados.to_utf8_buffer())
	var saida_man := {"dados": dados, "assinatura": Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, h.finish(), chave))}
	if man.get("apk") is Dictionary:
		saida_man["apk"] = man["apk"]         # só para o APK 0.47 (antes da assinatura) achar o APK novo
	var mf := FileAccess.open(man_arq, FileAccess.WRITE)
	mf.store_string(JSON.stringify(saida_man, "  "))
	mf = null
	print("manifesto: ", man_arq)
	quit()

func _chave() -> CryptoKey:
	var arq := OS.get_environment("CHAVE_PACOTES")
	if arq == "":
		arq = ProjectSettings.globalize_path("res://").path_join("../chaves_privadas/chave_pacotes.pem").simplify_path()
	var k := CryptoKey.new()
	if not FileAccess.file_exists(arq) or k.load(arq) != OK:
		printerr("ERRO: sem a chave privada dos pacotes (", arq, "). Ponha CHAVE_PACOTES=caminho do chave_pacotes.pem")
		return null
	var pub := CryptoKey.new()
	pub.load_from_string(k.save_to_string(true), true)
	if pub.save_to_string(true).strip_edges() != Atualizador.CHAVE_PUBLICA.strip_edges():
		printerr("ERRO: essa chave não é a do jogo (rede/atualizador.gd CHAVE_PUBLICA)")
		return null
	return k

func _codigo_apk() -> int:
	var cf := ConfigFile.new()
	if cf.load("res://export_presets.cfg") != OK:
		return -1
	return int(cf.get_value("preset.0.options", "version/code", -1))

# monta o .pck: devolve quantos arquivos entraram (-1 = erro)
func _montar(caminho: String, lista: PackedStringArray) -> int:
	var pk := PCKPacker.new()
	if pk.pck_start(caminho) != OK:
		printerr("ERRO: não deu para criar ", caminho)
		return -1
	var tmp := OS.get_user_data_dir().path_join("gerar_pacote_tmp")
	DirAccess.make_dir_recursive_absolute(tmp)
	var n := 0
	for rel in lista:
		var res := "res://" + rel
		if not FileAccess.file_exists(res):
			printerr("ERRO: não existe ", res)
			return -1
		if FileAccess.file_exists(res + ".import"):
			# recurso importado: o .import (que aponta para o arquivo pronto) + os arquivos de .godot/imported
			pk.add_file(res + ".import", ProjectSettings.globalize_path(res + ".import"))
			n += 1
			var cf := ConfigFile.new()
			cf.load(res + ".import")
			for d in cf.get_value("deps", "dest_files", []):
				pk.add_file(str(d), ProjectSettings.globalize_path(str(d)))
				n += 1
		else:
			# script/cena/dados em texto + ".remap" apontando para ele (o APK tem o .gdc/.scn e um .remap antigo)
			pk.add_file(res, ProjectSettings.globalize_path(res))
			var rm := tmp.path_join(rel.replace("/", "__") + ".remap")
			var f := FileAccess.open(rm, FileAccess.WRITE)
			f.store_string("[remap]\n\npath=\"%s\"\n" % res)
			f = null
			pk.add_file(res + ".remap", rm)
			n += 2
	pk.flush()
	return n
