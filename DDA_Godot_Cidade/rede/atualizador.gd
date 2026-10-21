extends Node
# ATUALIZADOR (autoload: o PRIMEIRO da lista em project.godot). Vem DENTRO do APK e NÃO pode ser trocado por pacote,
# por isso é pequeno e só faz o essencial:
#   1) ao abrir o jogo, ANTES dos outros scripts carregarem, aplica o PACOTE baixado (user://atualizacao/pacote.pck):
#      os arquivos dele substituem os do APK (scripts, texturas, modelos, sons, cenas...). Assim um conserto chega sem
#      reinstalar o jogo. Pacote novo baixado nesta sessão fica em "pacote_novo.pck" e entra no lugar na próxima abertura.
#   2) SEGURANÇA: se o jogo não chegar ao menu com o pacote (pacote com defeito), o pacote é apagado e marcado como
#      "ruim" (não é baixado de novo); o jogo volta a ser o do APK. Também apaga o pacote quando o APK é atualizado.
#   3) liga o resto (procurar atualização, baixar, avisar na tela) em rede/atualizacoes.gd, que o pacote PODE trocar.
#   4) ASSINATURA: o manifesto só vale se estiver assinado com a CHAVE PRIVADA dos pacotes (fica só com o dono, fora
#      do GitHub). A chave PÚBLICA abaixo confere. Quem mexer no repositório sem a chave não consegue mandar pacote
#      nem link de APK para os aparelhos.
# Mexa AQUI para: CODIGO_APK (tem de ser igual a version/code do export_presets.cfg a cada APK novo).

const CODIGO_APK := 44
const CHAVE_PUBLICA := """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAoX/PSEJ5Pqhsjhx4Mnwv
jMdXyJEEo0S0+H1rPQ89ELIKcsW5jdkQmdDGJqz8CxXtKDziiGYVMI9Gi+ZFJOj6
XOUxa3DlMfvmJ/yegVcd43RgWEDDszhoLRQ3FY5AcoeN/hTm3G2TPQXUwyEHVZAg
CrgInU1MGz1daI9JDWZwVQTnwURq3wXQLSlI9i2BlctrLTPAgCZLA1TkNn8VXuW5
PRRt/X0m7++ft2DjUGI6jBJtNS+aW739cBoDad2A1QznoBRXRDWfWq1BLaUmdA50
2Tt/7WjFmmLeq7lujNL3tNJA0oiCfhjtPWpa1lfp5WDhewm8nNkAFfcsv8VVKDmK
CvPWu610yOmJNZ3op4oW4GwGQxdAG8oQkx5tQWUm7g/CEW31Etop5BSruuO88bOo
6w0hKTV5NocrmWmMNDR9/5nQyS3JLodZtUgi0v2xuaXlTHYgygBNP9pyoDH5zWl3
5rKtDXtzNYzFyo7RcnGOeMsSxLlGl5oqCcf23FYKu597AgMBAAE=
-----END PUBLIC KEY-----"""
const PASTA := "user://atualizacao/"
const PACOTE := PASTA + "pacote.pck"
const PACOTE_NOVO := PASTA + "pacote_novo.pck"
const PACOTE_ANTERIOR := PASTA + "pacote_anterior.pck"   # o que funcionava antes do último (volta para ele se o novo falhar)
const ESTADO := PASTA + "estado.json"
const ESPERA_MENU := 60.0                 # até quanto tempo confere se o jogo abriu bem com o pacote (a cada 1 s)

var pacote_ativo := ""                    # versão do pacote carregado agora ("" = só o APK)
var estado := {}                          # {"versao", "base", "testando", "ruim", "novo_versao", "remover"}
var aviso := ""                           # o que aconteceu ao abrir (para mostrar no menu)

# rodando pelo EDITOR da Godot (testando no PC) ou no PC (servidor) não usa pacote: senão o pacote publicado cobriria o que está sendo
# editado. DDA_TESTAR_PACOTE=1 liga mesmo assim (testes do sistema de atualização).
# Só no CELULAR (Android): o servidor do PC (rede/servidor.gd) é um programa à parte, sempre gerado inteiro.
static func ligado() -> bool:
	return OS.get_environment("DDA_TESTAR_PACOTE") == "1" or (OS.has_feature("android") and not OS.has_feature("editor"))

func _init() -> void:
	if not ligado():
		return
	DirAccess.make_dir_recursive_absolute(PASTA)
	estado = _ler()
	# o desenvolvedor tirou o pacote do ar (manifesto sem pacote): apaga
	if bool(estado.get("remover", false)):
		_apagar_pacote()
		estado.erase("remover")
	# pacote baixado na sessão anterior: entra no lugar agora (antes de carregar)
	if FileAccess.file_exists(PACOTE_NOVO):
		if FileAccess.file_exists(PACOTE_ANTERIOR):
			DirAccess.remove_absolute(PACOTE_ANTERIOR)
		estado.erase("anterior_versao")
		if FileAccess.file_exists(PACOTE) and int(estado.get("base", -1)) == CODIGO_APK and not bool(estado.get("falhou", false)):
			DirAccess.rename_absolute(PACOTE, PACOTE_ANTERIOR)          # guarda o que funcionava
			estado["anterior_versao"] = estado.get("versao", "")
		elif FileAccess.file_exists(PACOTE):
			DirAccess.remove_absolute(PACOTE)
		DirAccess.rename_absolute(PACOTE_NOVO, PACOTE)
		estado["versao"] = estado.get("novo_versao", "")
		estado["base"] = CODIGO_APK
		estado["testando"] = true
		estado.erase("novo_versao")
	if not FileAccess.file_exists(PACOTE):
		_gravar()
		return
	if int(estado.get("base", -1)) != CODIGO_APK:
		_apagar_pacote()                      # pacote era de outro APK
		_gravar()
		return
	if bool(estado.get("falhou", false)):
		# a última abertura com este pacote não chegou ao menu: desfaz (volta ao pacote anterior ou ao APK)
		estado["ruim"] = estado.get("versao", "")
		aviso = "A atualização %s deu problema e foi desfeita." % estado.get("versao", "")
		_apagar_pacote()
		estado.erase("falhou")
		if FileAccess.file_exists(PACOTE_ANTERIOR):
			DirAccess.rename_absolute(PACOTE_ANTERIOR, PACOTE)
			estado["versao"] = estado.get("anterior_versao", "")
			estado["base"] = CODIGO_APK
			estado.erase("anterior_versao")
		else:
			_gravar()
			return
	estado["falhou"] = true                   # vira false quando o menu abrir (_conferir)
	_gravar()
	if ProjectSettings.load_resource_pack(PACOTE, true):
		pacote_ativo = str(estado.get("versao", ""))
		print("Atualizador: pacote ", pacote_ativo, " carregado")
	else:
		_apagar_pacote()
		estado.erase("falhou")
		_gravar()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pacote_ativo != "":
		_conferir()
	elif ligado():
		estado.erase("falhou")
		_gravar()
	# o resto fica num script que o pacote pode trocar (se ele estiver com defeito, segue sem atualizações)
	var s = load("res://rede/atualizacoes.gd")
	if s is Script and (s as Script).can_instantiate():
		var m: Node = s.new()
		m.name = "Atualizacoes"
		add_child(m)

# o jogo abriu com o pacote? (cena principal viva e com o menu ou o jogo)
var _t_conferir := 0.0
func _conferir() -> void:
	var c := get_tree().current_scene
	if c != null and c.get_script() != null and c.has_method("_jogar"):
		estado.erase("falhou")                 # abriu bem: o pacote fica
		_gravar()
		return
	_t_conferir += 1.0
	if _t_conferir < ESPERA_MENU:
		get_tree().create_timer(1.0).timeout.connect(_conferir)
	# se nunca ficar ok, "falhou" continua true: na próxima abertura o pacote é desfeito

# ---------- usados por rede/atualizacoes.gd ----------
# o manifesto chega como {"dados": "<json>", "assinatura": "<base64>"}: devolve os dados só se a assinatura conferir
func abrir_manifesto(m: Dictionary):
	var dados = m.get("dados")
	var ass = m.get("assinatura")
	if not (dados is String) or not (ass is String):
		return null
	var chave := CryptoKey.new()
	if chave.load_from_string(CHAVE_PUBLICA, true) != OK:
		return null
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update((dados as String).to_utf8_buffer())
	if not Crypto.new().verify(HashingContext.HASH_SHA256, h.finish(), Marshalls.base64_to_raw(ass), chave):
		print("Atualizador: manifesto com assinatura inválida (ignorado)")
		return null
	var d = JSON.parse_string(dados)
	return d if d is Dictionary else null

func versao_instalada() -> String:
	if estado.has("novo_versao"):
		return str(estado["novo_versao"])
	return pacote_ativo

func versao_ruim() -> String:
	return str(estado.get("ruim", ""))

# o pacote baixado (já conferido) vale na próxima abertura
func instalar(caminho: String, versao: String) -> void:
	if FileAccess.file_exists(PACOTE_NOVO):
		DirAccess.remove_absolute(PACOTE_NOVO)
	DirAccess.rename_absolute(caminho, PACOTE_NOVO)
	estado["novo_versao"] = versao
	estado.erase("remover")
	_gravar()

func pedir_remocao() -> void:
	if pacote_ativo == "" and not estado.has("novo_versao"):
		return
	estado["remover"] = true
	estado.erase("novo_versao")
	if FileAccess.file_exists(PACOTE_NOVO):
		DirAccess.remove_absolute(PACOTE_NOVO)
	_gravar()

# ---------- arquivo de estado ----------
func _apagar_pacote() -> void:
	if FileAccess.file_exists(PACOTE):
		DirAccess.remove_absolute(PACOTE)
	if not bool(estado.get("falhou", false)) and FileAccess.file_exists(PACOTE_ANTERIOR):
		DirAccess.remove_absolute(PACOTE_ANTERIOR)              # remoção pedida/APK novo: o anterior também sai
		estado.erase("anterior_versao")
	estado.erase("versao")
	estado.erase("base")
	estado.erase("testando")
	pacote_ativo = ""

func _ler() -> Dictionary:
	if not FileAccess.file_exists(ESTADO):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(ESTADO))
	return d if d is Dictionary else {}

func _gravar() -> void:
	var f := FileAccess.open(ESTADO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(estado))
