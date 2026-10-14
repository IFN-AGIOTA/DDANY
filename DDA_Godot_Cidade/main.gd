@tool
extends Node3D
# MAIN · só LIGA as partes do jogo (cada sistema mora no seu arquivo; veja o MAPA no LEIA-ME.txt).
# Fluxo: MENU PRINCIPAL (cena 3D do pôr do sol) -> Jogar -> cidade + jogo na BASE MILITAR do aeroporto.
# No jogo: II / P / Esc = PAUSA (Continuar · Opções · Voltar ao início · Menu principal).
# Mexa AQUI para: onde o jogador nasce (SPAWN) e a ordem em que as telas/sistemas são criados.

const MILBASE := Vector2(6230.0, 690.0)     # centro da base militar (aeroporto), como no jogo em HTML
const SPAWN := Vector2(6230.0, 590.0)       # onde o jogador nasce (virado para o sul)

const CidadeCls := preload("res://mundo/cidade.gd")
const ColisaoMundoCls := preload("res://mundo/colisao_mundo.gd")
const EstandeCls := preload("res://mundo/estande_tiro.gd")
const LootCls := preload("res://mundo/loot.gd")
const ControlesCls := preload("res://jogador/controles.gd")
const CameraVooCls := preload("res://jogador/camera_voo.gd")
const HudCls := preload("res://armas/hud_combate.gd")
const TelaInventarioCls := preload("res://inventario/tela_inventario.gd")
const CenaMenuCls := preload("res://menu/cena_menu.gd")
const MenuPrincipalCls := preload("res://menu/menu_principal.gd")
const OpcoesCls := preload("res://menu/opcoes.gd")
const PausaCls := preload("res://menu/pausa.gd")
const EditorHudCls := preload("res://menu/editor_hud.gd")
const AplicarOpcoesCls := preload("res://menu/aplicar_opcoes.gd")
const JOGADOR_CENA := preload("res://jogador/jogador.tscn")

var cidade: Node3D
var jogo: Node3D                            # tudo do jogo em andamento (apagado ao voltar ao menu)
var jogador: CharacterBody3D
var controles: CanvasLayer
var mundo: Node3D
var hud: CanvasLayer
var estande: Node3D
var tela_inventario: CanvasLayer
var voo: Camera3D
var cena_menu: Node3D
var menu: CanvasLayer
var opcoes: CanvasLayer
var pausa: CanvasLayer
var aplicador: Node
var _tempo_jogo := 0.0

# Preview dentro do editor (não é salvo na cena; leva alguns segundos e pesa no celular)
@export var preview_no_editor := false:
	set(v):
		preview_no_editor = v
		if not (Engine.is_editor_hint() and is_inside_tree()):
			return
		if v and not _cidade().is_built:
			_cidade().construir()
		elif not v and cidade != null and cidade.is_built:
			cidade.limpar()

# Marque para gerar res://cidade.scn: a cidade vira uma cena de verdade, editável com as ferramentas da Godot
@export var gerar_cena_salva := false:
	set(v):
		if v and Engine.is_editor_hint() and is_inside_tree():
			_cidade().salvar_cena()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS          # main cuida das telas; o jogo em si pausa (nó "Jogo")
	aplicador = AplicarOpcoesCls.new()
	aplicador.name = "AplicarOpcoes"
	aplicador.main = self
	add_child(aplicador)
	_abrir_menu()

# nó "Cidade" (construções). No editor é criado sem dono, então não é salvo na cena.
func _cidade() -> Node3D:
	if cidade == null:
		cidade = CidadeCls.new()
		cidade.name = "Cidade"
		add_child(cidade)
	return cidade

# ---------- telas ----------
func _abrir_menu() -> void:
	_fechar_jogo()
	if cidade != null:
		cidade.visible = false
	cena_menu = CenaMenuCls.new()
	cena_menu.name = "CenaMenu"
	add_child(cena_menu)
	menu = MenuPrincipalCls.new()
	menu.name = "MenuPrincipal"
	add_child(menu)
	menu.jogar.connect(_jogar)
	menu.historia.connect(func(): menu.avisar("A História · Ato 1 ainda não chegou na versão Godot. Use Jogar (mundo livre)."))
	menu.opcoes.connect(_abrir_opcoes)

func _jogar() -> void:
	menu.mostrar_carregando()
	await get_tree().process_frame          # deixa o "CARREGANDO" aparecer antes de montar a cidade
	await get_tree().process_frame
	menu.queue_free()
	menu = null
	cena_menu.queue_free()
	cena_menu = null
	if not _cidade().is_built:
		cidade.construir()
	cidade.visible = true
	_criar_jogo()

func _abrir_opcoes() -> void:
	if opcoes != null:
		return
	opcoes = OpcoesCls.new()
	opcoes.name = "Opcoes"
	add_child(opcoes)
	opcoes.fechar.connect(_fechar_opcoes)
	opcoes.editar_hud.connect(_editar_hud)
	if pausa != null:
		pausa.visible = false

func _fechar_opcoes() -> void:
	if opcoes != null:
		opcoes.queue_free()
		opcoes = null
	if pausa != null:
		pausa.visible = true

func _editar_hud() -> void:
	opcoes.visible = false
	if pausa != null:
		pausa.visible = false
	var ed = EditorHudCls.new()
	ed.name = "EditorHud"
	add_child(ed)
	ed.abrir(controles)
	ed.concluido.connect(func():
		if opcoes != null:
			opcoes.visible = true
			opcoes.mensagem("Posições da HUD salvas."))

func _pausar() -> void:
	if pausa != null or jogo == null:
		return
	if tela_inventario != null and tela_inventario.aberto:
		tela_inventario.fechar()
	get_tree().paused = true
	pausa = PausaCls.new()
	pausa.name = "Pausa"
	pausa.estatisticas = _estatisticas()
	add_child(pausa)
	pausa.continuar.connect(_continuar)
	pausa.opcoes.connect(_abrir_opcoes)
	pausa.reiniciar.connect(func():
		_continuar()
		_fechar_jogo()
		_criar_jogo())
	pausa.menu_principal.connect(func():
		_continuar()
		_abrir_menu())

func _continuar() -> void:
	if opcoes != null:
		return
	if pausa != null:
		pausa.queue_free()
		pausa = null
	get_tree().paused = false

func _estatisticas() -> Array:
	var s := int(_tempo_jogo)
	var r := [["tempo de jogo", "%d:%02d" % [s / 60, s % 60]]]
	if estande != null:
		r.append(["acertos no estande", str(estande.get("acertos"))])
		r.append(["tiros na cabeça", str(estande.get("cabecas"))])
		r.append(["alvos derrubados", str(estande.get("abates"))])
	return r

# ---------- jogo: colisão do mundo + jogador + controles + HUD + inventário ----------
func _criar_jogo() -> void:
	_tempo_jogo = 0.0
	jogo = Node3D.new()
	jogo.name = "Jogo"
	jogo.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(jogo)
	controles = ControlesCls.new()
	controles.name = "Controles"
	jogo.add_child(controles)
	controles.pausa_pedida.connect(_pausar)
	mundo = ColisaoMundoCls.new()
	mundo.name = "ColisaoMundo"
	jogo.add_child(mundo)
	mundo.configurar(cidade.dados_cidade, cidade.predios)
	jogador = JOGADOR_CENA.instantiate()
	jogador.name = "Jogador"
	jogador.mundo = mundo
	jogo.add_child(jogador)
	jogador.ligar_controles(controles)
	hud = HudCls.new()
	hud.name = "HudCombate"
	jogo.add_child(hud)
	hud.ligar(jogador.armas, jogador)
	estande = EstandeCls.new()
	estande.name = "EstandeTiro"
	estande.mundo = mundo
	jogo.add_child(estande)
	estande.montar(SPAWN + Vector2(0.0, 40.0), SPAWN)   # alvos ao sul do ponto de partida (para onde o jogador olha)
	var y: float = mundo.altura(SPAWN.x, SPAWN.y)
	mundo.forcar(SPAWN)
	jogador.teleportar(Vector3(SPAWN.x, y + 0.05, SPAWN.y), PI)   # virado para o sul (+Z), como no jogo em HTML
	mundo.alvo = jogador
	tela_inventario = TelaInventarioCls.new()
	tela_inventario.name = "TelaInventario"
	jogo.add_child(tela_inventario)
	tela_inventario.ligar(jogador.inventario, controles)
	LootCls.espalhar(jogo, mundo, SPAWN)
	voo = CameraVooCls.new()
	voo.name = "CameraVoo"
	jogo.add_child(voo)
	voo.ligar(jogador, controles, mundo, tela_inventario)
	jogador.camera.make_current()
	aplicador.aplicar()

func _fechar_jogo() -> void:
	if jogo != null:
		jogo.queue_free()
	jogo = null
	jogador = null
	controles = null
	mundo = null
	hud = null
	estande = null
	tela_inventario = null
	voo = null

func _process(dt: float) -> void:
	if Engine.is_editor_hint() or controles == null or not is_instance_valid(controles) or get_tree().paused:
		return
	_tempo_jogo += dt
	if voo.ativo:
		return
	var p := jogador.global_position
	controles.info.text = "FPS %d · x %d z %d · %d km/h" % [Engine.get_frames_per_second(), int(p.x), int(p.z), int(jogador.vel_horizontal * 3.6)]
