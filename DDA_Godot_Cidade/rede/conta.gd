extends Node
# CONTA (autoload "Conta") · login com GOOGLE (ou convidado), AMIGOS e PARTIDAS DOS AMIGOS, pelo FIREBASE.
# Tudo por HTTP (sem plugin): funciona no Android e no PC.
#   · LOGIN GOOGLE "por código" (o mesmo das TVs): o jogo mostra um código, a pessoa abre google.com/device
#     (no celular ou em qualquer aparelho), digita o código e escolhe a conta. O jogo fica perguntando ao Google
#     até confirmar e então entra no Firebase com essa conta. A sessão fica salva (user://conta.cfg).
#   · CONVIDADO: conta anônima do Firebase (sem Google), também tem código de amigo.
#   · AMIGOS: cada conta tem um CÓDIGO DE AMIGO (6 letras). Adicionar = digitar o código do outro. Quando OS DOIS
#     se adicionam, um vê as partidas do outro.
#   · PARTIDAS DOS AMIGOS: quem cria a partida (rede/rede.gd) publica os códigos dela para os amigos (a cada
#     45 s enquanto estiver aberta; apaga ao fechar). Na tela Multijogador aparece "Partida de Fulano" e é só tocar.
# Configuração: rede/firebase_config.cfg (vazia = sem conta; o resto do jogo funciona igual).
# Regras do banco (segurança): rede/firebase_regras.json. Passo a passo: LEIA-ME, seção "CONTA (FIREBASE)".
# Mexa AQUI para: tempo de publicação, tamanho do código de amigo, o que vai em cada convite.

signal mudou                                   # entrou, saiu, perfil ou amigos mudaram
signal login_codigo(codigo: String, site: String)   # mostre o código e o site para a pessoa
signal login_erro(motivo: String)
signal aviso(texto: String)
signal convites_mudaram(lista: Array)          # [{"uid", "nome", "codigos", "n", "versao"}, ...]

const CONFIG := "res://rede/firebase_config.cfg"
const SALVO := "user://conta.cfg"
const SEGREDO := "res://rede/firebase_segredo.cfg"
const PUBLICAR_A_CADA := 45.0                  # segundos
const VALIDADE_CONVITE := 150.0                # convite mais velho que isso = partida fechada
const ALFABETO := "23456789ABCDEFGHJKMNPQRSTVWXYZ"

var configurado := false
var logado := false
var uid := ""
var nome := ""
var email := ""
var tipo := ""                                 # "google" ou "convidado"
var codigo_amigo := ""
var amigos := {}                               # uid -> {"nome", "codigo"}
var convites: Array = []
var entrando := false                          # login em andamento

var _api_key := ""
var _db_url := ""
var _client_id := ""
var _client_secret := ""
var _url_oauth := "https://oauth2.googleapis.com"
var _url_ident := "https://identitytoolkit.googleapis.com"
var _url_token := "https://securetoken.googleapis.com"
var _id_token := ""
var _refresh := ""
var _expira := 0.0                             # unix (s)
var _login_id := 0
var _t_publicar := 0.0
var _publicado := false                        # tem convite nosso no ar

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	var arq := OS.get_environment("DDA_FIREBASE_CFG")   # testes: outra configuração (servidor falso)
	if cf.load(arq if arq != "" else CONFIG) == OK:
		_api_key = str(cf.get_value("firebase", "api_key", "")).strip_edges()
		_db_url = str(cf.get_value("firebase", "database_url", "")).strip_edges().trim_suffix("/")
		_client_id = str(cf.get_value("google", "client_id", "")).strip_edges()
		_client_secret = str(cf.get_value("google", "client_secret", "")).strip_edges()
		var seg := ConfigFile.new()              # a chave secreta mora num arquivo fora do git (rede/firebase_segredo.cfg)
		if _client_secret == "" and seg.load(SEGREDO) == OK:
			_client_secret = str(seg.get_value("google", "client_secret", "")).strip_edges()
		for par in [["oauth", "_url_oauth"], ["identidade", "_url_ident"], ["token", "_url_token"]]:
			var v := str(cf.get_value("servidores", par[0], "")).strip_edges().trim_suffix("/")
			if v != "":
				set(par[1], v)
	configurado = _api_key != "" and _db_url != ""
	if not configurado:
		return
	Rede.pronto.connect(func(): _t_publicar = 0.0)
	Rede.internet.connect(func(_a, _b, _c): _t_publicar = 0.0)
	Rede.jogador_entrou.connect(func(_a, _b): _t_publicar = minf(_t_publicar, 2.0))
	Rede.jogador_saiu.connect(func(_a): _t_publicar = minf(_t_publicar, 2.0))
	var s := ConfigFile.new()
	if s.load(SALVO) == OK and str(s.get_value("conta", "refresh", "")) != "":
		_refresh = str(s.get_value("conta", "refresh", ""))
		uid = str(s.get_value("conta", "uid", ""))
		tipo = str(s.get_value("conta", "tipo", ""))
		email = str(s.get_value("conta", "email", ""))
		_voltar_sessao()

func google_disponivel() -> bool:
	return configurado and _client_id != ""

# ---------- login ----------
func entrar_google() -> void:
	if not google_disponivel():
		login_erro.emit("Login com Google ainda não configurado (rede/firebase_config.cfg, veja o LEIA-ME).")
		return
	_login_id += 1
	var meu := _login_id
	entrando = true
	mudou.emit()
	var r := await _http(HTTPClient.METHOD_POST, _url_oauth + "/device/code", {"client_id": _client_id, "scope": "openid email profile"}, true)
	if meu != _login_id:
		return
	if not r["ok"] or not (r["dados"] is Dictionary) or not r["dados"].has("device_code"):
		_falha_login("O Google não respondeu ao pedido de login (%s)." % _erro_de(r))
		return
	var d: Dictionary = r["dados"]
	login_codigo.emit(str(d["user_code"]), str(d.get("verification_url", d.get("verification_uri", "https://www.google.com/device"))))
	var intervalo := float(d.get("interval", 5))
	var fim := Time.get_unix_time_from_system() + float(d.get("expires_in", 900))
	while Time.get_unix_time_from_system() < fim:
		await get_tree().create_timer(intervalo, true).timeout
		if meu != _login_id:
			return
		var t := await _http(HTTPClient.METHOD_POST, _url_oauth + "/token", {"client_id": _client_id, "client_secret": _client_secret,
			"device_code": str(d["device_code"]), "grant_type": "urn:ietf:params:oauth:grant-type:device_code"}, true)
		if meu != _login_id:
			return
		if t["ok"] and t["dados"] is Dictionary and t["dados"].has("id_token"):
			await _firebase_google(str(t["dados"]["id_token"]))
			return
		var err := str(t["dados"].get("error", "")) if t["dados"] is Dictionary else ""
		if err == "authorization_pending":
			continue
		if err == "slow_down":
			intervalo += 5.0
			continue
		_falha_login("Login recusado (%s)." % ("você não autorizou" if err == "access_denied" else _erro_de(t)))
		return
	_falha_login("O código expirou. Tente de novo.")

func cancelar_login() -> void:
	_login_id += 1
	entrando = false
	mudou.emit()

func entrar_convidado() -> void:
	if not configurado:
		login_erro.emit("Contas ainda não configuradas (rede/firebase_config.cfg, veja o LEIA-ME).")
		return
	_login_id += 1
	entrando = true
	mudou.emit()
	var r := await _http(HTTPClient.METHOD_POST, _url_ident + "/v1/accounts:signUp?key=" + _api_key, {"returnSecureToken": true})
	if not r["ok"]:
		_falha_login("Não deu para criar a conta de convidado (%s)." % _erro_de(r))
		return
	tipo = "convidado"
	email = ""
	await _comecar_sessao(r["dados"], "")

func sair_da_conta() -> void:
	await retirar_partida()
	_login_id += 1
	logado = false
	entrando = false
	uid = ""
	nome = ""
	email = ""
	codigo_amigo = ""
	amigos = {}
	convites = []
	_id_token = ""
	_refresh = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SALVO))
	mudou.emit()
	convites_mudaram.emit(convites)

func _firebase_google(id_token_google: String) -> void:
	var r := await _http(HTTPClient.METHOD_POST, _url_ident + "/v1/accounts:signInWithIdp?key=" + _api_key, {
		"postBody": "id_token=%s&providerId=google.com" % id_token_google, "requestUri": "http://localhost",
		"returnIdpCredential": true, "returnSecureToken": true})
	if not r["ok"]:
		_falha_login("O Firebase recusou a conta Google (%s). Confira o LEIA-ME (Google ativado e ID do cliente da TV liberado)." % _erro_de(r))
		return
	tipo = "google"
	email = str(r["dados"].get("email", ""))
	await _comecar_sessao(r["dados"], str(r["dados"].get("displayName", r["dados"].get("fullName", ""))))

func _comecar_sessao(d: Dictionary, nome_google: String) -> void:
	_id_token = str(d.get("idToken", ""))
	_refresh = str(d.get("refreshToken", ""))
	uid = str(d.get("localId", ""))
	_expira = Time.get_unix_time_from_system() + float(d.get("expiresIn", 3600)) - 60.0
	_guardar()
	await _carregar_perfil(nome_google)

func _voltar_sessao() -> void:
	entrando = true
	if not await _renovar():
		entrando = false
		_refresh = ""
		mudou.emit()
		return
	await _carregar_perfil("")

func _carregar_perfil(nome_google: String) -> void:
	var p = await _db(HTTPClient.METHOD_GET, "usuarios/" + uid)
	var perfil: Dictionary = p if p is Dictionary else {}
	codigo_amigo = str(perfil.get("codigo", ""))
	nome = str(perfil.get("nome", ""))
	if nome == "":
		nome = str(Config.valor("nome_rede")) if str(Config.valor("nome_rede")) != "" else (nome_google if nome_google != "" else "Sobrevivente")
	if codigo_amigo == "":
		for tentativa in 6:                   # reserva um código livre (a regra do banco não deixa pegar um usado)
			var c := ""
			for i in 6:
				c += ALFABETO[randi() % ALFABETO.length()]
			if await _db_ok(HTTPClient.METHOD_PUT, "codigos/" + c, uid):
				codigo_amigo = c
				break
	await _db(HTTPClient.METHOD_PUT, "usuarios/" + uid, {"nome": nome, "codigo": codigo_amigo})
	if str(Config.valor("nome_rede")) == "":
		Config.definir("nome_rede", nome)
	var a = await _db(HTTPClient.METHOD_GET, "amigos/" + uid)
	amigos = a if a is Dictionary else {}
	logado = uid != "" and _id_token != ""
	entrando = false
	mudou.emit()
	atualizar_convites()

func definir_nome(n: String) -> void:
	n = n.strip_edges().left(16)
	if not logado or n == "" or n == nome:
		return
	nome = n
	await _db(HTTPClient.METHOD_PATCH, "usuarios/" + uid, {"nome": nome})
	mudou.emit()

# ---------- amigos ----------
func adicionar_amigo(codigo: String) -> void:
	codigo = codigo.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if not logado:
		aviso.emit("Entre na sua conta primeiro.")
		return
	if codigo.length() != 6:
		aviso.emit("O código de amigo tem 6 letras/números.")
		return
	if codigo == codigo_amigo:
		aviso.emit("Esse é o seu próprio código.")
		return
	var outro = await _db(HTTPClient.METHOD_GET, "codigos/" + codigo)
	if not (outro is String) or outro == "":
		aviso.emit("Código %s não encontrado." % codigo)
		return
	var p = await _db(HTTPClient.METHOD_GET, "usuarios/" + outro)
	var nm := str(p.get("nome", "?")) if p is Dictionary else "?"
	if await _db_ok(HTTPClient.METHOD_PUT, "amigos/%s/%s" % [uid, outro], {"nome": nm, "codigo": codigo}):
		amigos[outro] = {"nome": nm, "codigo": codigo}
		mudou.emit()
		aviso.emit("%s adicionado! Para verem as partidas um do outro, peça para essa pessoa adicionar o seu código: %s" % [nm, codigo_amigo])
		_t_publicar = minf(_t_publicar, 1.0)
	else:
		aviso.emit("Não deu para adicionar agora. Tente de novo.")

func remover_amigo(outro: String) -> void:
	if not logado or not amigos.has(outro):
		return
	await _db(HTTPClient.METHOD_DELETE, "convites/%s/%s" % [outro, uid])
	await _db(HTTPClient.METHOD_DELETE, "amigos/%s/%s" % [uid, outro])
	amigos.erase(outro)
	mudou.emit()

# ---------- partidas dos amigos ----------
func atualizar_convites() -> void:
	if not logado:
		return
	var d = await _db(HTTPClient.METHOD_GET, "convites/" + uid)
	var lista: Array = []
	var agora := Time.get_unix_time_from_system() * 1000.0
	if d is Dictionary:
		for host in d:
			var c = d[host]
			if not (c is Dictionary) or not amigos.has(host):
				continue
			if agora - float(c.get("t", 0)) > VALIDADE_CONVITE * 1000.0:
				continue
			lista.append({"uid": host, "nome": str(c.get("nome", "?")), "codigos": c.get("codigos", []),
				"n": int(c.get("n", 1)), "versao": str(c.get("versao", ""))})
	convites = lista
	convites_mudaram.emit(convites)

func publicar_partida() -> void:
	if not logado or not Rede.eh_host():
		return
	var conv := {"nome": nome, "codigos": Rede.codigos(), "n": Rede.jogadores.size(), "versao": Config.VERSAO,
		"t": {".sv": "timestamp"}}
	for outro in amigos:
		await _db(HTTPClient.METHOD_PUT, "convites/%s/%s" % [outro, uid], conv)   # só vale se a pessoa também me adicionou
	_publicado = true

func retirar_partida() -> void:
	if not _publicado or not logado:
		return
	_publicado = false
	for outro in amigos:
		await _db(HTTPClient.METHOD_DELETE, "convites/%s/%s" % [outro, uid])

func _process(dt: float) -> void:
	if not logado:
		return
	if Rede.eh_host():
		_t_publicar -= dt
		if _t_publicar <= 0.0:
			_t_publicar = PUBLICAR_A_CADA
			publicar_partida()
	elif _publicado:
		retirar_partida()

# ---------- Firebase por HTTP ----------
func _renovar() -> bool:
	if _refresh == "":
		return false
	var r := await _http(HTTPClient.METHOD_POST, _url_token + "/v1/token?key=" + _api_key, {"grant_type": "refresh_token", "refresh_token": _refresh}, true)
	if not r["ok"] or not (r["dados"] is Dictionary):
		return false
	var d: Dictionary = r["dados"]
	_id_token = str(d.get("id_token", ""))
	_refresh = str(d.get("refresh_token", _refresh))
	uid = str(d.get("user_id", uid))
	_expira = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600)) - 60.0
	_guardar()
	return _id_token != ""

# banco (Realtime Database REST). Volta o valor (GET) ou null
func _db(metodo: int, caminho: String, corpo = null):
	var r := await _db_req(metodo, caminho, corpo)
	return r["dados"] if r["ok"] else null

func _db_ok(metodo: int, caminho: String, corpo = null) -> bool:
	var r := await _db_req(metodo, caminho, corpo)
	return r["ok"]

func _db_req(metodo: int, caminho: String, corpo) -> Dictionary:
	if Time.get_unix_time_from_system() > _expira and not await _renovar():
		return {"ok": false, "codigo": 401, "dados": null}
	return await _http(metodo, "%s/%s.json?auth=%s" % [_db_url, caminho, _id_token], corpo)

func _http(metodo: int, url: String, corpo = null, formulario := false) -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = 15.0
	add_child(h)
	var cab := PackedStringArray()
	var txt := ""
	if corpo != null:
		if formulario:
			cab.append("Content-Type: application/x-www-form-urlencoded")
			var partes := PackedStringArray()
			for k in corpo:
				partes.append("%s=%s" % [str(k).uri_encode(), str(corpo[k]).uri_encode()])
			txt = "&".join(partes)
		else:
			cab.append("Content-Type: application/json")
			txt = JSON.stringify(corpo)
	if h.request(url, cab, metodo, txt) != OK:
		h.queue_free()
		return {"ok": false, "codigo": 0, "dados": null}
	var r: Array = await h.request_completed
	h.queue_free()
	var bruto: PackedByteArray = r[3]
	var dados = JSON.parse_string(bruto.get_string_from_utf8()) if bruto.size() > 0 else null
	var cod: int = r[1]
	return {"ok": r[0] == HTTPRequest.RESULT_SUCCESS and cod >= 200 and cod < 300, "codigo": cod, "dados": dados}

func _erro_de(r: Dictionary) -> String:
	if int(r["codigo"]) == 0:
		return "sem internet?"
	var d = r["dados"]
	if d is Dictionary:
		var e = d.get("error")
		if e is Dictionary:
			return str(e.get("message", r["codigo"]))
		if e != null:
			return str(d.get("error_description", e))
	return "erro %d" % int(r["codigo"])

func _falha_login(motivo: String) -> void:
	entrando = false
	mudou.emit()
	login_erro.emit(motivo)

func _guardar() -> void:
	var s := ConfigFile.new()
	s.set_value("conta", "refresh", _refresh)
	s.set_value("conta", "uid", uid)
	s.set_value("conta", "tipo", tipo)
	s.set_value("conta", "email", email)
	s.save(SALVO)
