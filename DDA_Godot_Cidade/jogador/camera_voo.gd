extends Camera3D
# VOO: câmera livre sobre a cidade (para inspecionar). Botão VOO / tecla V liga e desliga.
# Ao sair, o jogador desce onde a câmera estiver. SOBE / DESCE (Q/E) e VEL (velocidade).
# Mexa AQUI para: velocidades, altura inicial, sensibilidade do olhar no voo.

const VELOCIDADES := [60.0, 200.0, 600.0]

var ativo := false
var yaw := 0.0
var pitch := -0.45
var vel_i := 1
var jogador: CharacterBody3D
var controles: CanvasLayer
var mundo: Node3D
var tela_inventario: CanvasLayer

func _ready() -> void:
	near = 2.0
	far = 9000.0

func ligar(j: CharacterBody3D, c: CanvasLayer, m: Node3D, tela: CanvasLayer) -> void:
	jogador = j
	controles = c
	mundo = m
	tela_inventario = tela
	c.voo_pedido.connect(alternar)
	c.vel_pedida.connect(func(): vel_i = (vel_i + 1) % VELOCIDADES.size())

func alternar() -> void:
	ativo = not ativo
	controles.set_modo_voo(ativo)
	if ativo:
		position = jogador.global_position + Vector3(0.0, 60.0, 0.0)
		yaw = jogador.cam_yaw
		pitch = -0.6
		if tela_inventario != null and tela_inventario.aberto:
			tela_inventario.fechar()
		jogador.ativo = false
		mundo.alvo = null
		make_current()
	else:
		var p := position
		var y: float = mundo.altura(p.x, p.z)
		mundo.forcar(Vector2(p.x, p.z))
		jogador.teleportar(Vector3(p.x, y + 0.05, p.z), yaw)
		jogador.ativo = true
		mundo.alvo = jogador
		jogador.camera.make_current()

func _process(delta: float) -> void:
	if not ativo or controles == null:
		return
	var olhar: Vector2 = controles.consumir_olhar() + controles.consumir_olhar_mouse() * 0.6   # mouse preso (modo PC)
	yaw -= olhar.x * 0.004
	pitch = clampf(pitch - olhar.y * 0.004, -1.5, 1.5)
	var mv: Vector2 = controles.vetor_mover()
	var b := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	basis = b
	position += (-b.z * mv.y + b.x * mv.x + Vector3.UP * controles.vertical()) * VELOCIDADES[vel_i] * delta
	position.y = maxf(position.y, 3.0)
	controles.info.text = "VOO · FPS %d · vel %d m/s · alt %d m" % [Engine.get_frames_per_second(), int(VELOCIDADES[vel_i]), int(position.y)]
