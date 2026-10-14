@tool
extends Node3D
# MAIN · só LIGA as partes do jogo (cada sistema mora no seu arquivo; veja o MAPA no LEIA-ME.txt).
# O jogo começa na BASE MILITAR do aeroporto: soldado em 3ª pessoa com pistola e M4, de frente para um estande de tiro.
# Mexa AQUI para: onde o jogador nasce (SPAWN) e a ordem em que os sistemas são criados.

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
const JOGADOR_CENA := preload("res://jogador/jogador.tscn")

var cidade: Node3D
var jogador: CharacterBody3D
var controles: CanvasLayer
var mundo: Node3D
var hud: CanvasLayer
var estande: Node3D
var tela_inventario: CanvasLayer
var voo: Camera3D

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
	_cidade().construir()
	_criar_jogo()

# nó "Cidade" (construções). No editor é criado sem dono, então não é salvo na cena.
func _cidade() -> Node3D:
	if cidade == null:
		cidade = CidadeCls.new()
		cidade.name = "Cidade"
		add_child(cidade)
	return cidade

# ---------- jogo: colisão do mundo + jogador + controles + HUD + inventário ----------
func _criar_jogo() -> void:
	controles = ControlesCls.new()
	controles.name = "Controles"
	add_child(controles)
	mundo = ColisaoMundoCls.new()
	mundo.name = "ColisaoMundo"
	add_child(mundo)
	mundo.configurar(cidade.dados_cidade, cidade.predios)
	jogador = JOGADOR_CENA.instantiate()
	jogador.name = "Jogador"
	jogador.mundo = mundo
	add_child(jogador)
	jogador.ligar_controles(controles)
	hud = HudCls.new()
	hud.name = "HudCombate"
	add_child(hud)
	hud.ligar(jogador.armas, jogador)
	estande = EstandeCls.new()
	estande.name = "EstandeTiro"
	estande.mundo = mundo
	add_child(estande)
	estande.montar(SPAWN + Vector2(0.0, 40.0), SPAWN)   # alvos ao sul do ponto de partida (para onde o jogador olha)
	var y: float = mundo.altura(SPAWN.x, SPAWN.y)
	mundo.forcar(SPAWN)
	jogador.teleportar(Vector3(SPAWN.x, y + 0.05, SPAWN.y), PI)   # virado para o sul (+Z), como no jogo em HTML
	mundo.alvo = jogador
	tela_inventario = TelaInventarioCls.new()
	tela_inventario.name = "TelaInventario"
	add_child(tela_inventario)
	tela_inventario.ligar(jogador.inventario, controles)
	LootCls.espalhar(self, mundo, SPAWN)
	voo = CameraVooCls.new()
	voo.name = "CameraVoo"
	add_child(voo)
	voo.ligar(jogador, controles, mundo, tela_inventario)
	jogador.camera.make_current()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or controles == null or voo.ativo:
		return
	var p := jogador.global_position
	controles.info.text = "FPS %d · x %d z %d · %d km/h" % [Engine.get_frames_per_second(), int(p.x), int(p.z), int(jogador.vel_horizontal * 3.6)]
