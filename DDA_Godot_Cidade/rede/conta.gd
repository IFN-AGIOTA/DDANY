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
#   · SERVIDORES (0.51): o servidor do PC (rede/servidor.gd, conta de convidado) publica servidores/{uid} a cada
#     45 s. A tela Multijogador lista os servidores ligados para QUALQUER conta (não precisa ser amigo) e entra pela
#     internet com WebRTC (rede/rtc.gd), sem abrir porta.
# Configuração: rede/firebase_config.cfg (vazia = sem conta; o resto do jogo funciona igual).
# Regras do banco (segurança): rede/firebase_regras.json. Passo a passo: LEIA-ME, seção "CONTA (FIREBASE)".
# Mexa AQUI para: tempo de publicação, tamanho do código de amigo, o que vai em cada convite.

signal mudou                                   # entrou, saiu, perfil ou amigos mudaram
signal login_codigo(codigo: String, site: String)   # mostre o código e o site para a pessoa
signal login_erro(motivo: String)
signal aviso(texto: String)
signal convites_mudaram(lista: Array)          # [{"uid", "nome", "codigos", "n", "versao"}, ...]
signal chamado(convite: Dictionary)            # um amigo me CHAMOU para a sala dele agora (main.gd mostra o aviso)
signal pedidos_mudaram                         # pedidos de amizade recebidos mudaram
signal amigos_atualizados                      # status (online, ícone, recorde) dos amigos chegou
signal resposta(amigo_uid: String, aceitou: bool)   # host: o amigo chamado aceitou/recusou
signal servidores_mudaram                      # lista de servidores do PC ligados mudou (servidores)

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
var servidores: Array = []                     # servidores do PC ligados: [{"uid", "nome", "codigos", "n", "versao", "rtc", ...}]
var nome_servidor := ""                        # este aparelho é um servidor do PC com este nome (rede/servidor.gd)
var _t_servidores := 0.0
var entrando := false                          # login em andamento
var avatar := 0                                # ícone do perfil (menu/avatar.gd)
var recorde_tempo := 0.0                       # melhor tempo vivo (s) e mais abates (vêm do Config, vão para a conta)
var recorde_abates := 0
var pedidos := {}                              # uid -> {"nome", "codigo", "avatar"} (pedidos de amizade recebidos)
var status_amigos := {}                        # uid -> {"nome", "avatar", "visto", "estado", "mutuo", "recorde_tempo"}
var _chamados_vistos := {}                     # host -> "chamou" já mostrado
var _t_presenca := 0.0
var _ultimo_estado := ""
var _t_chamados := 2.0
const PRESENCA_A_CADA := 60.0                  # segundos entre "estou online"
const ONLINE_ATE := 150.0                      # visto há menos que isso = online
const CHAMADO_VALE := 45.0                     # um chamado mais velho que isso não vira aviso

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
	Config.mudou.connect(func(k):
		if k == "rec_tempo" or k == "rec_abates":
			_sincronizar_recordes())
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
	avatar = int(perfil.get("avatar", randi() % 12))
	recorde_tempo = maxf(float(perfil.get("recorde_tempo", 0.0)), float(Config.valor("rec_tempo")))
	recorde_abates = maxi(int(perfil.get("recorde_abates", 0)), int(Config.valor("rec_abates")))
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
	await _db(HTTPClient.METHOD_PUT, "usuarios/" + uid, {"nome": nome, "codigo": codigo_amigo, "avatar": avatar,
		"recorde_tempo": recorde_tempo, "recorde_abates": recorde_abates, "visto": {".sv": "timestamp"}, "estado": _estado()})
	if str(Config.valor("nome_rede")) == "":
		Config.definir("nome_rede", nome)
	var a = await _db(HTTPClient.METHOD_GET, "amigos/" + uid)
	amigos = a if a is Dictionary else {}
	logado = uid != "" and _id_token != ""
	entrando = false
	mudou.emit()
	atualizar_convites()
	atualizar_pedidos()
	atualizar_amigos()

func definir_avatar(i: int) -> void:
	if not logado:
		return
	avatar = i
	mudou.emit()
	await _db(HTTPClient.METHOD_PATCH, "usuarios/" + uid, {"avatar": avatar})

func _sincronizar_recordes() -> void:
	var t := float(Config.valor("rec_tempo"))
	var a := int(Config.valor("rec_abates"))
	if not logado or (t <= recorde_tempo and a <= recorde_abates):
		return
	recorde_tempo = maxf(recorde_tempo, t)
	recorde_abates = maxi(recorde_abates, a)
	await _db(HTTPClient.METHOD_PATCH, "usuarios/" + uid, {"recorde_tempo": recorde_tempo, "recorde_abates": recorde_abates})

# o que estou fazendo agora (aparece para os amigos)
func _estado() -> String:
	if Rede.ligado:
		return "online" if not Rede.partida_comecou else "jogando online"
	var m = get_tree().current_scene if is_inside_tree() else null
	if m != null and m.get("jogo") != null:
		return "jogando sozinho"
	return "no menu"

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
	var av := int(p.get("avatar", 0)) if p is Dictionary else 0
	if amigos.has(outro):
		aviso.emit("%s já está na sua lista." % nm)
		return
	if await _db_ok(HTTPClient.METHOD_PUT, "amigos/%s/%s" % [uid, outro], {"nome": nm, "codigo": codigo, "avatar": av}):
		amigos[outro] = {"nome": nm, "codigo": codigo, "avatar": av}
		var ja = await _db(HTTPClient.METHOD_GET, "amigos/%s/%s" % [outro, uid])   # a pessoa já tinha me adicionado?
		if ja is Dictionary:
			aviso.emit("Agora você e %s são amigos!" % nm)
		else:
			await _db(HTTPClient.METHOD_PUT, "pedidos/%s/%s" % [outro, uid], {"nome": nome, "codigo": codigo_amigo, "avatar": avatar,
				"t": {".sv": "timestamp"}})
			aviso.emit("Pedido de amizade enviado para %s. Quando aceitar, vocês podem se chamar." % nm)
		mudou.emit()
		atualizar_amigos()
		_t_publicar = minf(_t_publicar, 1.0)
	else:
		aviso.emit("Não deu para adicionar agora. Tente de novo.")

# ---------- pedidos de amizade ----------
func atualizar_pedidos() -> void:
	if not logado:
		return
	var d = await _db(HTTPClient.METHOD_GET, "pedidos/" + uid)
	pedidos = {}
	if d is Dictionary:
		for de in d:
			if amigos.has(de):                  # já é amigo: o pedido não serve mais
				_db(HTTPClient.METHOD_DELETE, "pedidos/%s/%s" % [uid, de])
				continue
			var x = d[de]
			if x is Dictionary:
				pedidos[de] = {"nome": str(x.get("nome", "?")), "codigo": str(x.get("codigo", "")), "avatar": int(x.get("avatar", 0))}
	pedidos_mudaram.emit()

func aceitar_pedido(de: String) -> void:
	var p: Dictionary = pedidos.get(de, {})
	if p.is_empty():
		return
	if await _db_ok(HTTPClient.METHOD_PUT, "amigos/%s/%s" % [uid, de], {"nome": p["nome"], "codigo": p["codigo"], "avatar": p["avatar"]}):
		amigos[de] = {"nome": p["nome"], "codigo": p["codigo"], "avatar": p["avatar"]}
		aviso.emit("Agora você e %s são amigos!" % p["nome"])
	await _db(HTTPClient.METHOD_DELETE, "pedidos/%s/%s" % [uid, de])
	pedidos.erase(de)
	pedidos_mudaram.emit()
	mudou.emit()
	atualizar_amigos()

func recusar_pedido(de: String) -> void:
	pedidos.erase(de)
	pedidos_mudaram.emit()
	await _db(HTTPClient.METHOD_DELETE, "pedidos/%s/%s" % [uid, de])

# ---------- status dos amigos (online, ícone, recorde, se já aceitou) ----------
func atualizar_amigos() -> void:
	if not logado:
		return
	var novo := {}
	for f in amigos.keys():
		var p = await _db(HTTPClient.METHOD_GET, "usuarios/" + f)
		var m = await _db(HTTPClient.METHOD_GET, "amigos/%s/%s" % [f, uid])
		var d: Dictionary = p if p is Dictionary else {}
		novo[f] = {"nome": str(d.get("nome", amigos.get(f, {}).get("nome", "?"))), "avatar": int(d.get("avatar", 0)),
			"visto": float(d.get("visto", 0)), "estado": str(d.get("estado", "")), "mutuo": m is Dictionary,
			"recorde_tempo": float(d.get("recorde_tempo", 0.0)), "recorde_abates": int(d.get("recorde_abates", 0))}
	status_amigos = novo
	amigos_atualizados.emit()

# [0 offline · 1 online · 2 jogando, texto]
func status_de(f: String) -> Array:
	var s: Dictionary = status_amigos.get(f, {})
	if s.is_empty():
		return [0, "…"]
	if not bool(s.get("mutuo", false)):
		return [0, "pedido enviado · aguardando aceitar"]
	var seg := Time.get_unix_time_from_system() - float(s.get("visto", 0)) / 1000.0
	if seg < ONLINE_ATE:
		var e := str(s.get("estado", "online"))
		return [2 if e.begins_with("jogando") else 1, e]
	if float(s.get("visto", 0)) <= 0.0:
		return [0, "offline"]
	if seg < 3600.0:
		return [0, "visto há %d min" % int(seg / 60.0)]
	if seg < 86400.0:
		return [0, "visto há %d h" % int(seg / 3600.0)]
	return [0, "visto há %d dias" % int(seg / 86400.0)]

# ---------- chamar amigo para a sala (host) e responder ----------
func chamar(f: String) -> bool:
	if not logado or not Rede.eh_host():
		return false
	var conv := _convite()
	conv["chamou"] = {".sv": "timestamp"}
	var ok := await _db_ok(HTTPClient.METHOD_PUT, "convites/%s/%s" % [f, uid], conv)
	if not ok:
		aviso.emit("%s ainda não aceitou seu pedido de amizade." % status_amigos.get(f, amigos.get(f, {})).get("nome", "?"))
	_publicado = true
	return ok

func responder(c: Dictionary, aceitou: bool) -> void:
	if logado:
		await _db(HTTPClient.METHOD_PUT, "respostas/%s/%s" % [str(c["uid"]), uid], {"r": "aceitou" if aceitou else "recusou", "t": {".sv": "timestamp"}})

# host: lê quem aceitou/recusou (e apaga)
func ler_respostas() -> void:
	if not logado or not Rede.eh_host():
		return
	var d = await _db(HTTPClient.METHOD_GET, "respostas/" + uid)
	if not (d is Dictionary):
		return
	await _db(HTTPClient.METHOD_DELETE, "respostas/" + uid)
	for f in d:
		var x = d[f]
		if x is Dictionary:
			resposta.emit(f, str(x.get("r", "")) == "aceitou")

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
			var item := {"uid": host, "nome": str(c.get("nome", "?")), "codigos": c.get("codigos", []), "rtc": bool(c.get("rtc", false)), "turn": bool(c.get("turn", false)),
				"n": int(c.get("n", 1)), "versao": str(c.get("versao", "")), "avatar": int(c.get("avatar", 0)),
				"chamou": float(c.get("chamou", 0)), "comecou": bool(c.get("comecou", false))}
			lista.append(item)
			# CHAMADO novo (o host tocou em CHAMAR há pouco): vira aviso na tela (main.gd)
			var ch: float = item["chamou"]
			if ch > float(_chamados_vistos.get(host, 0.0)) and agora - ch < CHAMADO_VALE * 1000.0:
				_chamados_vistos[host] = ch
				if not Rede.ligado:
					chamado.emit(item)
	convites = lista
	convites_mudaram.emit(convites)

# ---------- servidores do PC ----------
func atualizar_servidores() -> void:
	if not logado:
		return
	var d = await _db(HTTPClient.METHOD_GET, "servidores")
	var lista: Array = []
	var agora := Time.get_unix_time_from_system() * 1000.0
	if d is Dictionary:
		for host in d:
			var c = d[host]
			if not (c is Dictionary) or host == uid or agora - float(c.get("t", 0)) > VALIDADE_CONVITE * 1000.0:
				continue
			lista.append({"uid": host, "nome": str(c.get("nome", "Servidor")), "codigos": c.get("codigos", []),
				"rtc": bool(c.get("rtc", false)), "turn": bool(c.get("turn", false)), "n": int(c.get("n", 0)), "versao": str(c.get("versao", "")),
				"avatar": 0, "comecou": true, "servidor": true})
	lista.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
	servidores = lista
	servidores_mudaram.emit()

func publicar_servidor() -> void:
	if not logado or not Rede.eh_host():
		return
	await _db(HTTPClient.METHOD_PUT, "servidores/" + uid, {"nome": nome_servidor, "codigos": Rede.codigos(), "n": Rede.jogadores.size(),
		"versao": Config.VERSAO, "rtc": Rede.aceita_rtc(), "turn": Rede.aceita_turn(), "t": {".sv": "timestamp"}})
	_publicado = true

func retirar_servidor() -> void:
	if logado:
		await _db(HTTPClient.METHOD_DELETE, "servidores/" + uid)

func _convite() -> Dictionary:
	return {"nome": nome, "avatar": avatar, "codigos": Rede.codigos(), "n": Rede.jogadores.size(), "versao": Config.VERSAO,
		"rtc": Rede.aceita_rtc(), "turn": Rede.aceita_turn(), "comecou": Rede.partida_comecou, "t": {".sv": "timestamp"}}

func publicar_partida() -> void:
	if not logado or not Rede.eh_host():
		return
	var conv := _convite()
	for outro in amigos:
		await _db(HTTPClient.METHOD_PATCH, "convites/%s/%s" % [outro, uid], conv)   # PATCH: não apaga o "chamou"; só vale se a pessoa também me adicionou
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
	_t_presenca -= dt
	var e := _estado()
	if _t_presenca <= 0.0 or e != _ultimo_estado:   # de minuto em minuto, ou na hora que muda (entrou na sala, começou...)
		_t_presenca = PRESENCA_A_CADA
		_ultimo_estado = e
		_db(HTTPClient.METHOD_PATCH, "usuarios/" + uid, {"visto": {".sv": "timestamp"}, "estado": e})
	_t_chamados -= dt
	if _t_chamados <= 0.0:
		_t_chamados = 5.0
		if not Rede.ligado:
			atualizar_convites()               # também acha os CHAMADOS novos
		if int(Time.get_ticks_msec() / 5000) % 6 == 0:
			atualizar_pedidos()
	if not Rede.ligado:
		_t_servidores -= dt
		if _t_servidores <= 0.0:
			_t_servidores = 15.0
			atualizar_servidores()
	if Rede.eh_host():
		_t_publicar -= dt
		if _t_publicar <= 0.0:
			_t_publicar = PUBLICAR_A_CADA
			if Rede.servidor_dedicado:
				publicar_servidor()            # servidor do PC: na lista pública de servidores (não nos convites)
			else:
				publicar_partida()
	elif _publicado:
		if nome_servidor != "":
			_publicado = false
			retirar_servidor()
		else:
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

# para outros sistemas (rede/rtc.gd): ler, gravar e apagar no banco com a conta aberta
func db_get(caminho: String):
	return await _db(HTTPClient.METHOD_GET, caminho)

func db_put(caminho: String, valor) -> bool:
	return await _db_ok(HTTPClient.METHOD_PUT, caminho, valor)

func db_del(caminho: String) -> bool:
	return await _db_ok(HTTPClient.METHOD_DELETE, caminho)

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
