extends CharacterBody3D
# JOGADOR EM 3ª PESSOA · soldado original do HTML, armas, correr, agachar, mirar e pular.
# Números do HTML: andar 1,7 · trote 3,9 · correr 7,2 m/s · pulo 5,2 · gravidade 15.
# Novos: AGACHADO (1,0 / 1,8 m/s, mira mais firme, alvo menor) e MIRAR (câmera aproxima, 2,2 m/s, mira mais firme).
# Correr cancela agachar e mirar. Pular agachado = levantar.
# Câmera igual à do menu: FOV 42, 2,35 m atrás, alvo a 1,52 m, personagem à esquerda (~34% da largura);
# o recuo das armas mexe a câmera como no HTML.
#
# MODELO 3D: o nó "Modelo" é o encaixe. Se existir res://modelos/personagem.glb (ou .tscn/.fbx) ele substitui o
# soldado original, com as animações (ver modelos/LEIA-ME.txt). Por código: jogador.trocar_modelo(no).

signal pulou

const GRAVIDADE := 15.0
const VEL_ANDAR := 1.7
const VEL_TROTE := 3.9
const VEL_CORRIDA := 7.2
const VEL_AGACHADO := 1.0
const VEL_AGACHADO_RAPIDO := 1.8
const VEL_MIRANDO := 2.2
const FORCA_PULO := 5.2
const ALTURA_EM_PE := 1.8
const ALTURA_AGACHADO := 1.3
const EXTENSOES_MODELO := ["tscn", "scn", "glb", "gltf", "fbx"]

@export_group("Câmera")
@export var distancia_camera := 2.35
@export var lateral_camera := 0.32      # 0,32 = personagem à esquerda · 0 = centro · -0,32 = direita
@export var fov_camera := 42.0
@export var altura_alvo := 1.52
@export var altura_alvo_agachado := 1.02
@export var distancia_mirando := 1.6
@export var fov_mirando := 34.0
@export var ombro_mirando := 0.55      # mirando, a câmera vai para cima do ombro direito (metros)
@export var sensibilidade := 1.0
@export_group("Modelo")
@export var giro_modelo_importado := 180.0   # modelos glTF olham para +Z; se andar de costas, troque 180 <-> 0
@export var escala_modelo := 1.0

var controles = null                # controles.gd (toque/teclado)
var mundo = null                    # colisao_mundo.gd (altura do chão e raio dos tiros)
var ativo := true
var morto := false
var agachado := false
var mirando := false                # mira (aproxima a câmera); ligada pelo botão MIRAR ou botão direito do mouse
var atirando := false               # atirou há pouco / arma erguida (o corpo vira para a mira)
var cam_yaw := 0.0                  # 0 = olhando para -Z
var cam_pit := 0.05                 # positivo = câmera acima olhando para baixo (-0,35 a 1,15)
var vel_horizontal := 0.0
var fator_agachado := 0.0           # 0 em pé · 1 agachado (suavizado, para a câmera)
var fator_mira := 0.0

var _mirar_ligado := false
var _pulo_ant := false
var _y_cam := 0.0

@onready var camera: Camera3D = $PivoCamera/Braco/Ponta/Camera
@onready var animador: Node = $Animador
@onready var armas: Node = $Armas
@onready var _slot: Node3D = $Modelo
@onready var _pivo: Node3D = $PivoCamera
@onready var _braco: SpringArm3D = $PivoCamera/Braco
@onready var _colisao: CollisionShape3D = $Colisao
@onready var _capsula: CapsuleShape3D = $Colisao.shape

func _ready() -> void:
	camera.fov = fov_camera
	_braco.add_excluded_object(get_rid())
	_y_cam = global_position.y
	_capsula = _capsula.duplicate()
	_colisao.shape = _capsula
	var sold := _slot.get_node_or_null("Soldado")
	animador.configurar(sold)
	armas.anexar(sold, null)
	_carregar_modelo_do_projeto()

func ligar_controles(c) -> void:
	controles = c
	c.agachar_pedido.connect(alternar_agachar)
	c.mirar_pedido.connect(func(): _mirar_ligado = not _mirar_ligado)
	c.recarregar_pedido.connect(func(): armas.recarregar())
	c.trocar_arma_pedido.connect(func(): armas.proxima_arma())
	c.arma_pedida.connect(func(t: String): armas.selecionar(t))

# usa res://modelos/personagem.(tscn|scn|glb|gltf|fbx) se existir; senão fica o soldado original
func _carregar_modelo_do_projeto() -> void:
	for ext in EXTENSOES_MODELO:
		var caminho: String = "res://modelos/personagem." + str(ext)
		if ResourceLoader.exists(caminho):
			var res = load(caminho)
			if res is PackedScene:
				var no := (res as PackedScene).instantiate()
				if no is Node3D:
					trocar_modelo(no as Node3D, true)
					animador.importar_animacoes("res://modelos/animacoes")
					return

# põe um modelo novo no encaixe (apaga o anterior), liga o animador e passa as armas para a mão dele
func trocar_modelo(no: Node3D, importado := true) -> void:
	for f in _slot.get_children():
		_slot.remove_child(f)
		f.queue_free()
	if importado:
		no.rotation_degrees.y = giro_modelo_importado
		no.scale = Vector3.ONE * escala_modelo
	_slot.add_child(no)
	animador.configurar(no)
	armas.anexar(no, animador.ponto_arma())

func teleportar(pos: Vector3, yaw_camera: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	cam_yaw = yaw_camera
	rotation.y = yaw_camera
	_y_cam = pos.y

func alternar_agachar() -> void:
	if morto:
		return
	if agachado:
		_levantar()
	else:
		agachado = true
		_aplicar_capsula()

func _levantar() -> bool:
	if not agachado:
		return true
	if not _cabe_em_pe():
		return false          # tem teto em cima: continua agachado
	agachado = false
	_aplicar_capsula()
	return true

func _aplicar_capsula() -> void:
	var h := ALTURA_AGACHADO if agachado else ALTURA_EM_PE
	_capsula.height = h
	_colisao.position.y = h * 0.5

func _cabe_em_pe() -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = _capsula.radius - 0.02
	cap.height = ALTURA_EM_PE
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, ALTURA_EM_PE * 0.5 + 0.03, 0.0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _physics_process(delta: float) -> void:
	if not ativo:
		return
	var ix := 0.0
	var iy := 0.0
	var sprint := false
	var quer_pular := false
	if controles != null:
		var m: Vector2 = controles.vetor_mover()
		ix = m.x
		iy = m.y
		sprint = controles.correndo()
		quer_pular = controles.pulando()
		armas.gatilho = controles.atirando()
	if morto:
		ix = 0.0
		iy = 0.0
		quer_pular = false
		sprint = false
		armas.gatilho = false
	var mag := minf(1.0, Vector2(ix, iy).length())
	# correr cancela agachar e mirar
	if sprint and mag >= 0.05:
		if agachado and not _levantar():
			sprint = false
		_mirar_ligado = false
	mirando = (_mirar_ligado or (controles != null and controles.mirando_segurado())) and not morto
	if mirando:
		sprint = false
	var dir := Vector3.ZERO
	if mag > 0.001:
		dir = (Basis(Vector3.UP, cam_yaw) * Vector3(ix, 0.0, -iy)).normalized()
	var vmax := 0.0
	if mag >= 0.05:
		if agachado:
			vmax = VEL_AGACHADO_RAPIDO if mag > 0.55 else VEL_AGACHADO
		elif sprint:
			vmax = VEL_CORRIDA
		else:
			vmax = VEL_TROTE if mag > 0.55 else VEL_ANDAR
		if mirando:
			vmax = minf(vmax, VEL_MIRANDO)
	var no_chao := is_on_floor()
	var k := minf(1.0, delta * (9.0 if no_chao else 2.5))
	velocity.x += (dir.x * vmax - velocity.x) * k
	velocity.z += (dir.z * vmax - velocity.z) * k
	if no_chao:
		if quer_pular and not _pulo_ant:
			if agachado:
				_levantar()             # pular agachado = levantar
				velocity.y = 0.0
			else:
				velocity.y = FORCA_PULO
				pulou.emit()
		else:
			velocity.y = 0.0
	else:
		velocity.y -= GRAVIDADE * delta
	_pulo_ant = quer_pular
	move_and_slide()
	vel_horizontal = Vector2(velocity.x, velocity.z).length()
	atirando = armas.since < 1.6 or armas.aim > 0.5
	if not morto:
		if mirando or atirando:
			rotation.y = lerp_angle(rotation.y, cam_yaw + armas.ky, minf(1.0, delta * 14.0))   # corpo vira para a mira
		elif vel_horizontal > 0.4:
			rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), minf(1.0, delta * 10.0))

func _process(delta: float) -> void:
	if not ativo:
		return
	if controles != null:
		var r: Vector2 = controles.consumir_olhar()
		var s := sensibilidade * (0.6 if mirando else 1.0)     # mirando: olhar mais preciso
		cam_yaw -= r.x * 0.006 * s
		cam_pit = clampf(cam_pit + r.y * 0.004 * s, -0.35, 1.15)
		controles.indicadores["AGACHAR"] = agachado
		controles.indicadores["MIRAR"] = mirando
		controles.textos["ARMA"] = armas.WDEF[armas.atual]["nome"]
	fator_agachado = lerpf(fator_agachado, 1.0 if agachado else 0.0, minf(1.0, delta * 10.0))
	fator_mira = lerpf(fator_mira, 1.0 if mirando else 0.0, minf(1.0, delta * 12.0))
	# câmera: pivô na altura do ombro, gira com a mira (+ recuo da arma); o braço (SpringArm3D) bate nos prédios
	_y_cam = lerpf(_y_cam, global_position.y, 1.0 - exp(-12.0 * delta))
	var alvo_y := lerpf(altura_alvo, altura_alvo_agachado, fator_agachado) + 0.1 * fator_mira
	_pivo.global_position = Vector3(global_position.x, _y_cam + alvo_y, global_position.z)
	_pivo.rotation = Vector3(-(cam_pit - armas.kick), cam_yaw + armas.ky, 0.0)
	var fov_base := lerpf(fov_camera, fov_mirando, fator_mira)
	var fov_alvo := fov_base + 5.0 * clampf((vel_horizontal - 3.0) / 4.0, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, fov_alvo, minf(1.0, delta * 4.0 + 0.02))
	var dist := lerpf(distancia_camera, distancia_mirando, fator_mira)
	_braco.spring_length = dist
	var asp := get_viewport().get_visible_rect().size.aspect()
	var meia_largura := tan(deg_to_rad(camera.fov) * 0.5) * asp
	var frac := _braco.get_hit_length() / maxf(dist, 0.01)
	camera.position.x = lerpf(dist * meia_largura * lateral_camera, ombro_mirando, fator_mira) * frac
	animador.atualizar(delta, self)
