extends SubViewportContainer
# PERSONAGEM 3D NO INVENTÁRIO (coluna do meio, entre os encaixes do corpo), em tempo real:
#   uma cópia do sobrevivente (jogador/modelo_sobrevivente.gd) num "estúdio" só dele, vestida com o que está
#   equipado agora (roupas, colete, chapéu, mochila, armas no ombro/coldre) e com o item das MÃOS na mão.
#   Muda na hora em que você equipa/tira algo. Parado, respirando (animação "parado").
#   ARRASTAR o dedo/mouse em cima dele = girar o personagem.
#   SOLTAR um item em cima dele = vestir no lugar certo (ou pôr na mão, se for arma/ferramenta).
# Só existe com a tela do inventário aberta (não gasta nada no jogo). No modo história (soldado antigo) a tela
# continua com a silhueta.
# Mexa AQUI para: câmera, luz e ângulo inicial do personagem.

const Sob := preload("res://jogador/modelo_sobrevivente.gd")
const ModelosArmas := preload("res://armas/modelos_armas.gd")

var inv = null                         # inventario.gd
var _vp: SubViewport
var _giro: Node3D
var _sob: Node3D
var _cam: Camera3D
var _arma: Node3D
var _arma_chave := ""
var _angulo := 0.45                    # um pouco de lado (3/4), mostra a mochila e a arma nas costas
var _arrastando := false

func _init(inventario) -> void:
	inv = inventario

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	_vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 1.2
	_vp.add_child(sol)
	sol.look_at_from_position(Vector3(-1.5, 3.0, 2.5), Vector3.ZERO)
	var contorno := DirectionalLight3D.new()
	contorno.light_energy = 0.55
	contorno.light_color = Color(0.85, 0.9, 1.0)
	_vp.add_child(contorno)
	contorno.look_at_from_position(Vector3(2.0, 2.0, -3.0), Vector3.ZERO)
	_cam = Camera3D.new()
	_cam.fov = 28.0
	_vp.add_child(_cam)
	_giro = Node3D.new()
	_vp.add_child(_giro)
	_sob = Sob.new()
	_sob.name = "Sobrevivente"
	_giro.add_child(_sob)
	_giro.rotation.y = _angulo
	resized.connect(_enquadrar)
	inv.mudou.connect(_atualizar)
	_enquadrar()
	_atualizar()

# o corpo inteiro cabe na altura do quadro (e na largura, se o quadro for estreito)
func _enquadrar() -> void:
	var asp := size.x / maxf(size.y, 1.0)
	var alt := 2.05                                         # metros que precisam caber na vertical
	var larg := 1.25                                        # e na horizontal (braços, fuzil, mochila)
	var meia := maxf(alt * 0.5, larg * 0.5 / maxf(asp, 0.01))
	var dist := meia / tan(deg_to_rad(_cam.fov * 0.5))
	_cam.position = Vector3(0, 0.95, dist)
	_cam.look_at(Vector3(0, 0.92, 0))

func _atualizar() -> void:
	if not is_instance_valid(_sob) or not _sob.is_inside_tree():
		return
	_sob.vestir(inv)
	# item da mão: arma de verdade na mão (com silenciador/mira se encaixados)
	var it = inv.slots.get("maos")
	var tipo: String = String(it.def().get("arma", "")) if it != null else ""
	var chave := tipo
	if it != null:
		for k in it.acessorios:
			chave += "_" + String(k)
	if chave == _arma_chave:
		return
	_arma_chave = chave
	if _arma != null and is_instance_valid(_arma):
		_arma.queue_free()
	_arma = null
	if tipo == "":
		return
	_arma = ModelosArmas.construir(tipo)
	for enc in ["cano", "mira"]:
		var a := _arma.get_node_or_null("Acc_" + enc)
		if a != null:
			a.visible = it.acessorios.has(enc)
	_sob.segurar_arma(tipo, _arma)

# girar arrastando
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = e.pressed
		accept_event()
	elif e is InputEventScreenTouch:
		_arrastando = e.pressed
		accept_event()
	elif (e is InputEventMouseMotion or e is InputEventScreenDrag) and _arrastando:
		_angulo += e.relative.x * 0.012
		_giro.rotation.y = _angulo
		accept_event()

# soltar um item em cima do personagem = vestir/segurar
func _can_drop_data(_p: Vector2, d: Variant) -> bool:
	if typeof(d) != TYPE_DICTIONARY or not d.has("item") or d.has("atalho"):
		return false
	return _lugar(d["item"]) != ""

func _drop_data(_p: Vector2, d: Variant) -> void:
	var it = d["item"]
	var s := _lugar(it)
	if s != "":
		inv.equipar(it, s)

func _lugar(it) -> String:
	var pref: String = it.def().get("slot", "")
	if pref != "" and inv.slots.get(pref) != it and inv.pode_equipar(it, pref):
		return pref
	if inv.slots.get("maos") != it and inv.pode_equipar(it, "maos"):
		return "maos"
	return ""
