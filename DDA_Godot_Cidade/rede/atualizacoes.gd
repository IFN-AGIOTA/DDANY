extends Node
# ATUALIZAÇÕES · criado pelo rede/atualizador.gd (este arquivo PODE ser trocado por um pacote).
# Ao abrir o jogo lê o MANIFESTO no GitHub (atualizacoes/atualizacao.json, repositório público IFN-AGIOTA/DDANY):
#   {"apk": {"codigo": 44, "versao": "0.48", "url": ".../DiasDeUmApocalipse.apk", "notas": "..."},
#    "pacote": {"base": 43, "versao": "0.47.1", "url": ".../pacote_0.47.1.pck", "sha256": "...", "tamanho": 1234,
#               "notas": "..."}   ou   "pacote": null}
#   · APK mais novo que este -> aviso no menu com o botão BAIXAR (abre o link: o Android baixa e pergunta se instala;
#     o save e a conta continuam). Precisa de APK quando muda algo do Android (permissões, plugins, a Godot).
#   · PACOTE para ESTE APK ("base" = Atualizador.CODIGO_APK) e ainda não instalado -> baixa sozinho em segundo plano,
#     confere tamanho e SHA-256 e avisa: "vale quando abrir o jogo de novo" (botão FECHAR O JOGO).
#     Consertos, ajustes, coisas novas e remoções (trocando o arquivo por outro) chegam assim, sem reinstalar.
#   · "pacote": null (ou de outro APK) com um pacote instalado -> o pacote é tirado na próxima abertura.
# Os pacotes e o manifesto são feitos pela ferramenta ferramentas/gerar_pacote.gd (ver LEIA-ME).
# Mexa AQUI para: endereço do manifesto, textos e o visual do aviso.

const UI := preload("res://menu/ui.gd")
const RAMO := "claude/dayz-inventory-system-pckjpx"
const MANIFESTO := "https://raw.githubusercontent.com/IFN-AGIOTA/DDANY/refs/heads/" + RAMO + "/atualizacoes/atualizacao.json"
const ESPERA := 3.0                           # segundos depois de abrir para procurar (não atrapalha o carregamento)

var boot: Node                                # rede/atualizador.gd
var manifesto := {}
var _http: HTTPRequest
var _baixando := {}                           # o pacote sendo baixado
var _ui: CanvasLayer
var _caixa: PanelContainer
var _pendente := {}                           # aviso esperando o menu aparecer: {"tipo", ...}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	boot = get_parent()
	if not boot.ligado():
		return                                # rodando pelo editor: sem atualizações
	var cfg := get_node_or_null("/root/Config")
	print("Atualizações: jogo ", cfg.VERSAO if cfg != null else "?", " · APK ", boot.CODIGO_APK, " · pacote '", boot.pacote_ativo, "'")
	var url := OS.get_environment("DDA_MANIFESTO")          # testes: outro endereço
	await get_tree().create_timer(ESPERA).timeout
	if boot.aviso != "":
		_mostrar({"tipo": "info", "texto": boot.aviso})
	_buscar(url if url != "" else MANIFESTO)

func _buscar(url: String) -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_manifesto_chegou)
	var sep := "&" if "?" in url else "?"
	if _http.request(url + sep + "t=%d" % int(Time.get_unix_time_from_system())) != OK:
		_http.queue_free()

func _manifesto_chegou(res: int, codigo: int, _h: PackedStringArray, corpo: PackedByteArray) -> void:
	_http.queue_free()
	if res != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		return                                # sem internet: tenta na próxima abertura
	var d = JSON.parse_string(corpo.get_string_from_utf8())
	if not (d is Dictionary):
		return
	manifesto = d
	var apk = d.get("apk")
	if apk is Dictionary and int(apk.get("codigo", 0)) > boot.CODIGO_APK:
		print("Atualizações: APK novo ", apk.get("versao", ""))
		_mostrar({"tipo": "apk", "versao": str(apk.get("versao", "")), "url": str(apk.get("url", "")), "notas": str(apk.get("notas", ""))})
		return                                # pacotes são para o APK novo
	var p = d.get("pacote")
	if not (p is Dictionary) or int(p.get("base", -1)) != boot.CODIGO_APK:
		boot.pedir_remocao()                  # tirado do ar (ou era de outro APK)
		return
	var v := str(p.get("versao", ""))
	if v == "" or v == boot.versao_instalada() or v == boot.versao_ruim():
		return
	_baixar(p)

# ---------- pacote ----------
func _baixar(p: Dictionary) -> void:
	_baixando = p
	_http = HTTPRequest.new()
	_http.timeout = 300.0
	_http.download_file = boot.PASTA + "baixando.pck"
	add_child(_http)
	_http.request_completed.connect(_pacote_chegou)
	if _http.request(str(p.get("url", ""))) != OK:
		_http.queue_free()
		_baixando = {}

func _pacote_chegou(res: int, codigo: int, _h: PackedStringArray, _c: PackedByteArray) -> void:
	_http.queue_free()
	var arq: String = boot.PASTA + "baixando.pck"
	var p := _baixando
	_baixando = {}
	if res != HTTPRequest.RESULT_SUCCESS or codigo != 200 or not FileAccess.file_exists(arq):
		return
	var ok := true
	var f := FileAccess.open(arq, FileAccess.READ)
	if f == null or (p.has("tamanho") and f.get_length() != int(p["tamanho"])):
		ok = false
	f = null
	if ok and p.has("sha256") and FileAccess.get_sha256(arq) != str(p["sha256"]):
		ok = false
	if not ok:
		DirAccess.remove_absolute(arq)        # veio corrompido: tenta de novo na próxima abertura
		return
	boot.instalar(arq, str(p.get("versao", "")))
	print("Atualizações: pacote ", p.get("versao", ""), " baixado (vale na próxima abertura)")
	_mostrar({"tipo": "pacote", "versao": str(p.get("versao", "")), "notas": str(p.get("notas", ""))})

func progresso() -> float:
	if _baixando.is_empty() or _http == null or not is_instance_valid(_http):
		return -1.0
	var tot := _http.get_body_size()
	return float(_http.get_downloaded_bytes()) / float(tot) if tot > 0 else 0.0

# ---------- aviso na tela (só no menu; no meio do jogo espera) ----------
func _mostrar(a: Dictionary) -> void:
	_pendente = a

func _process(_dt: float) -> void:
	if _pendente.is_empty() or _caixa != null:
		return
	var c := get_tree().current_scene
	if c == null or c.get("menu") == null or not is_instance_valid(c.menu):
		return
	_abrir(_pendente)
	_pendente = {}

func _abrir(a: Dictionary) -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 65
	add_child(_ui)
	var v := UI.vh(_ui)
	_caixa = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.04, 0.015, 0.97)
	sb.border_color = Color("#ff8a35")
	sb.set_border_width_all(int(maxf(2.0, 0.35 * v)))
	sb.set_corner_radius_all(int(1.6 * v))
	sb.content_margin_left = 2.2 * v
	sb.content_margin_right = 2.2 * v
	sb.content_margin_top = 1.6 * v
	sb.content_margin_bottom = 1.6 * v
	_caixa.add_theme_stylebox_override("panel", sb)
	_caixa.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caixa.offset_left = -52.0 * v
	_caixa.offset_right = 52.0 * v
	_caixa.offset_top = -22.0 * v
	_caixa.offset_bottom = -3.0 * v
	_caixa.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(_caixa)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(1.0 * v))
	_caixa.add_child(col)
	var titulo := ""
	var texto := ""
	match a["tipo"]:
		"apk":
			titulo = "NOVA VERSÃO %s DISPONÍVEL" % a["versao"]
			texto = "Toque em BAIXAR: o Android baixa e pergunta se quer instalar. Seu jogo salvo e sua conta continuam."
		"pacote":
			titulo = "ATUALIZAÇÃO %s BAIXADA" % a["versao"]
			texto = "Ela entra quando você abrir o jogo de novo."
		_:
			titulo = "ATUALIZAÇÃO"
			texto = str(a.get("texto", ""))
	col.add_child(UI.rotulo(titulo, 3.4 * v, UI.AMBAR, 900))
	var notas := str(a.get("notas", ""))
	if notas != "":
		col.add_child(UI.rotulo(notas, 2.4 * v, Color(1, 0.93, 0.85), 500, 0.0, true))
	col.add_child(UI.rotulo(texto, 2.2 * v, Color(1, 0.91, 0.82, 0.8), 400, 0.0, true))
	var bs := HBoxContainer.new()
	bs.add_theme_constant_override("separation", int(1.4 * v))
	bs.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(bs)
	var depois := UI.BotaoMenu.new("Depois" if a["tipo"] != "info" else "OK", "", false, 3.0, 16.0)
	depois.apertado.connect(_fechar)
	bs.add_child(depois)
	if a["tipo"] == "apk":
		var b := UI.BotaoMenu.new("BAIXAR", "", true, 3.4, 18.0)
		b.apertado.connect(func():
			OS.shell_open(str(a["url"]))
			_fechar())
		bs.add_child(b)
	elif a["tipo"] == "pacote":
		var b := UI.BotaoMenu.new("FECHAR O JOGO", "", true, 3.4, 22.0)
		b.apertado.connect(func(): get_tree().quit())
		bs.add_child(b)

func _fechar() -> void:
	if _ui != null:
		_ui.queue_free()
	_ui = null
	_caixa = null
