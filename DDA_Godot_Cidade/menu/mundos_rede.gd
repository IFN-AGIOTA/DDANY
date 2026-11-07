extends RefCounted
# MUNDOS DO MULTIJOGADOR (1.03, como os mundos do Minecraft). Cada mundo é um arquivo user://mundos/<id>.json:
#   {"versao", "id", "nome", "meu", "host", "criado", "jogado", "semente", "dia", "minutos", "mundo", "personagem"}
#   · MEU (meu = true): mundo que ESTE aparelho hospeda. Tem a semente e o MUNDO (o que foi saqueado e pego, portas,
#     carros, a base, a horda, hora/tempo) e o PERSONAGEM do host nele (o que carrega, vida/fome..., onde estava).
#     Aparece na lista "Seus mundos" da tela Multijogador (CRIAR SALA): escolher um abre a sala com ele.
#   · DE AMIGO (meu = false): só o PERSONAGEM deste aparelho no mundo de outra pessoa (o mundo fica com ela). O id
#     vem do host ao entrar (rede/rede.gd mundo["mundo_id"]): entrar de novo no mesmo mundo traz o personagem de volta.
# O jogo salva sozinho (a cada 2 min, ao pausar, ao voltar ao menu, ao morrer) em menu/salvamento.gd salvar_rede.
# O save da 0.77-1.02 (user://save_rede.json, um mundo só) vira o mundo "Mundo salvo" na primeira vez (migrar).
# Mexa AQUI para: onde ficam os arquivos, tamanho do nome, o que aparece na lista.

const PASTA := "user://mundos"
const VERSAO := 1
const NOME_MAX := 24
const ANTIGO := "user://save_rede.json"            # 0.77-1.02: um mundo só
const ANTIGO_GUARDADO := "user://save_rede_antigo.json"

static func _caminho(id: String) -> String:
	return PASTA.path_join(id + ".json")

static func _garantir_pasta() -> void:
	if not DirAccess.dir_exists_absolute(PASTA):
		DirAccess.make_dir_recursive_absolute(PASTA)

static func limpar_nome(n: String) -> String:
	var s := n.strip_edges().replace("\n", " ")
	return s.left(NOME_MAX)

static func novo_id() -> String:
	return "%08x%04x" % [int(Time.get_unix_time_from_system()) & 0xffffffff, randi() & 0xffff]

static func ler(id: String) -> Dictionary:
	if id == "" or not FileAccess.file_exists(_caminho(id)):
		return {}
	var f := FileAccess.open(_caminho(id), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary and int(d.get("versao", 0)) == VERSAO else {}

static func gravar(d: Dictionary) -> bool:
	if str(d.get("id", "")) == "":
		return false
	_garantir_pasta()
	d["versao"] = VERSAO
	# grava num arquivo ao lado e troca (o celular pode fechar no meio: o mundo antigo não estraga)
	var tmp := _caminho(str(d["id"])) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return DirAccess.rename_absolute(tmp, _caminho(str(d["id"]))) == OK

static func apagar(id: String) -> void:
	if id != "" and FileAccess.file_exists(_caminho(id)):
		DirAccess.remove_absolute(_caminho(id))

# cria um mundo NOVO deste aparelho (semente nova) e devolve ele
static func criar(nome: String) -> Dictionary:
	migrar()
	var n := limpar_nome(nome)
	if n == "":
		n = nome_sugerido()
	var agora := int(Time.get_unix_time_from_system())
	var d := {"id": novo_id(), "nome": n, "meu": true, "criado": agora, "jogado": agora, "semente": randi(),
		"dia": 1, "minutos": 0}
	gravar(d)
	return d

# os mundos que ESTE aparelho hospeda, o jogado por último primeiro
static func lista() -> Array:
	migrar()
	var r: Array = []
	if not DirAccess.dir_exists_absolute(PASTA):
		return r
	for arq in DirAccess.get_files_at(PASTA):
		if not arq.ends_with(".json"):
			continue
		var d := ler(arq.get_basename())
		if not d.is_empty() and bool(d.get("meu", false)):
			r.append(d)
	r.sort_custom(func(a, b): return int(a.get("jogado", 0)) > int(b.get("jogado", 0)))
	return r

static func por_nome(nome: String) -> Dictionary:
	for d in lista():
		if str(d["nome"]).to_lower() == limpar_nome(nome).to_lower():
			return d
	return {}

static func nome_sugerido() -> String:
	var usados := {}
	for d in lista():
		usados[str(d["nome"]).to_lower()] = true
	var k := 1
	while usados.has(("mundo %d" % k).to_lower()):
		k += 1
	return "Mundo %d" % k

# texto da linha do mundo na lista ("Dia 3 · 42 min · jogado há 2 h")
static func resumo(d: Dictionary) -> String:
	var t := "Dia %d · %d min jogados" % [int(d.get("dia", 1)), int(d.get("minutos", 0))]
	var dif := int(Time.get_unix_time_from_system()) - int(d.get("jogado", 0))
	if dif < 120:
		t += " · agora há pouco"
	elif dif < 3600:
		t += " · jogado há %d min" % (dif / 60)
	elif dif < 86400:
		t += " · jogado há %d h" % (dif / 3600)
	else:
		t += " · jogado há %d dia(s)" % (dif / 86400)
	return t

# 0.77-1.02 guardavam UM mundo (e um personagem) em user://save_rede.json: vira o mundo "Mundo salvo". Sem mundo
# (só o personagem, de quem entrava na sala dos outros), o personagem vira o "personagem antigo": o primeiro mundo de
# amigo que você entrar sem personagem salvo recebe ele (não perde o que carregava).
static func migrar() -> void:
	if not FileAccess.file_exists(ANTIGO):
		return
	var f := FileAccess.open(ANTIGO, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if f != null:
		f.close()
	if d is Dictionary:
		var m: Dictionary = d.get("mundo", {})
		var pj: Dictionary = d.get("personagem", {})
		if not m.is_empty() and m.has("semente"):
			var agora := int(Time.get_unix_time_from_system())
			gravar({"id": novo_id(), "nome": "Mundo salvo", "meu": true, "criado": agora, "jogado": agora,
				"semente": int(m["semente"]), "dia": int(m.get("clima", {}).get("dia", 1)),
				"minutos": int(float(pj.get("tempo_jogo", 0.0)) / 60.0), "mundo": m, "personagem": pj})
		elif not pj.is_empty():
			gravar({"id": "_antigo", "nome": "personagem antigo", "meu": false, "personagem": pj})
	DirAccess.rename_absolute(ANTIGO, ANTIGO_GUARDADO)   # guardado (não apaga), e não migra de novo

# personagem antigo (sem mundo) para um mundo de amigo que ainda não tem personagem: usa uma vez só
static func pegar_personagem_antigo() -> Dictionary:
	var a := ler("_antigo")
	if a.is_empty():
		return {}
	apagar("_antigo")
	return a.get("personagem", {})
