extends VehicleBody3D
# VEÍCULO DIRIGÍVEL (0.76) · um carro largado que FUNCIONA (sedã, táxi ou van; mundo/veiculos.gd escolhe quais e cuida
# de entrar/sair, guardar e a rede). Física de carro da Godot (VehicleBody3D, 4 rodas, tração atrás, direção na frente);
# o desenho é o mesmo modelo dos carros da rua (mundo/abandono.gd), virado para +Z (a frente do VehicleBody3D).
#   - dirigir: acelerar/ré, virar, freio de mão; COMBUSTÍVEL (litros) gasta com a distância e com o motor ligado;
#     sem gasolina o motor morre. Bater forte estraga o MOTOR (estado 0..1: menos força; 0 = não liga) e machuca.
#   - atropelar infectados (e jogadores no PvP) com velocidade machuca/derruba; o motor faz barulho (os infectados
#     perto ouvem) e tem som próprio (feito por código, mais agudo com a velocidade).
# Mexa AQUI para: força, velocidade, direção, tanque, consumo, dano das batidas e do atropelamento.

const Abandono := preload("res://mundo/abandono.gd")
const Sons := preload("res://audio/sons.gd")

const TANQUE := 30.0                    # litros
const LITROS_POR_KM := 1.6              # consumo andando
const LITROS_MINUTO := 0.03             # motor ligado (marcha lenta), por minuto
const FORCA := 4200.0
const FORCA_RE := 2000.0
const FREIO := 60.0
const VEL_MAX := 24.0                   # m/s (~86 km/h)
const GIRO_MAX := 0.5                   # rad
const BARULHO := 38.0                   # metros: os infectados ouvem o motor
const DANO_ATROPELAR := 9.0             # por m/s de velocidade

# rodas e corpo de cada tipo (no sistema do carro: frente = +Z) · [rodas x, rodas z frente, z trás, raio, caixa, massa,
# força do motor (x FORCA)]
# 1.08: o HUMVEE e o CAMINHÃO DO EXÉRCITO dos comboios (mundo/comboios.gd): pesados, motor mais forte
const TIPOS := {
	"sedan": [0.86, 1.4, -1.35, 0.34, Vector3(1.85, 1.1, 4.4), 1250.0, 1.0],
	"taxi": [0.86, 1.4, -1.35, 0.34, Vector3(1.85, 1.1, 4.4), 1250.0, 1.0],
	"van": [0.9, 1.6, -1.6, 0.36, Vector3(2.0, 1.8, 4.9), 1900.0, 1.0],
	"humvee": [1.0, 1.6, -1.6, 0.45, Vector3(2.2, 1.9, 4.9), 2400.0, 1.9],
	"caminhao_exercito": [1.05, 2.8, -2.1, 0.55, Vector3(2.5, 3.2, 8.0), 4500.0, 2.9],
}
const NOMES := {"sedan": "CARRO", "taxi": "TÁXI", "van": "VAN", "humvee": "HUMVEE", "caminhao_exercito": "CAMINHÃO DO EXÉRCITO"}

var id := ""                            # mundo/veiculos.gd ("v123_-456": posição de onde estava largado)
var tipo := "sedan"
var cor := Color.WHITE
var combustivel := 0.0                  # litros
var motor := 1.0                        # estado do motor (0..1)
var ligado := false
var motorista: Node3D = null            # jogador dirigindo (null = estacionado)
var remoto := false                     # cópia de um carro que um amigo está dirigindo (posição pela rede)
var mundo = null                        # mundo/colisao_mundo.gd (barulho)
var vagos = null                        # inimigos/vagos.gd (atropelar, barulho)
var ao_bater := Callable()              # (dano) -> machuca o motorista

var _acel := 0.0
var _giro := 0.0
var _freio_mao := false
var _som: AudioStreamPlayer3D
var _t_barulho := 0.0
var _t_atropelo := 0.0
var _vel_ant := Vector3.ZERO
var _corpo: CollisionShape3D
var _forca_x := 1.0                     # 1.08: força do motor deste tipo

func _ready() -> void:
	var d: Array = TIPOS.get(tipo, TIPOS["sedan"])
	mass = float(d[5])
	_forca_x = float(d[6])
	collision_layer = 1                 # mundo: o jogador, os infectados e os tiros batem nele
	collision_mask = 1 | 4 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.2, 0.1)      # baixo: não capota fácil nas curvas
	var caixa: Vector3 = d[4]
	_corpo = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(caixa.x, caixa.y * 0.75, caixa.z)
	_corpo.shape = bs
	_corpo.position = Vector3(0, 0.35 + caixa.y * 0.4, 0)
	add_child(_corpo)
	# desenho: o mesmo modelo dos carros largados, com a cor deste
	var mi := MeshInstance3D.new()
	mi.mesh = Abandono.modelo(tipo)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = cor
	mat.roughness = 0.55
	mat.metallic = 0.25
	mi.material_override = mat
	mi.rotation.y = -PI * 0.5               # o modelo tem a frente em +X; aqui a frente é +Z
	add_child(mi)
	for k in 4:
		var w := VehicleWheel3D.new()
		var frente := k < 2
		w.position = Vector3(float(d[0]) * (1.0 if k % 2 == 0 else -1.0), float(d[3]) + 0.12, float(d[1]) if frente else float(d[2]))
		w.wheel_radius = float(d[3])
		w.wheel_rest_length = 0.15
		w.suspension_travel = 0.22
		w.suspension_stiffness = 45.0 if tipo in ["sedan", "taxi"] else 55.0
		w.suspension_max_force = mass * 9.0
		w.damping_compression = 2.6
		w.damping_relaxation = 3.2
		w.wheel_friction_slip = 2.6
		w.wheel_roll_influence = 0.05
		w.use_as_traction = not frente
		w.use_as_steering = frente
		add_child(w)
	_som = AudioStreamPlayer3D.new()
	_som.stream = _motor_wav()
	_som.unit_size = 8.0
	_som.max_distance = 120.0
	_som.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_som)
	if remoto:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

# ---------- comandos (jogador/jogador.gd chama a cada quadro físico enquanto dirige) ----------
func controlar(acel: float, giro: float, freio_mao: bool) -> void:
	_acel = clampf(acel, -1.0, 1.0)
	_giro = clampf(giro, -1.0, 1.0)
	_freio_mao = freio_mao

func ligar_motor() -> String:
	if motor <= 0.0:
		return "O MOTOR ESTÁ QUEBRADO"
	if combustivel <= 0.05:
		return "SEM GASOLINA · USE UM GALÃO (USAR perto do carro)"
	ligado = true
	_som.play()
	return ""

func desligar_motor() -> void:
	ligado = false
	_acel = 0.0
	_giro = 0.0
	_som.stop()

# capotado/tombado (entrar desvira: mundo/veiculos.gd)
func virado() -> bool:
	return global_basis.y.y < 0.5

func desvirar() -> void:
	var yaw := atan2(global_basis.z.x, global_basis.z.z)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3(0, 0.6, 0))

func velocidade_kmh() -> float:
	return linear_velocity.length() * 3.6

func _physics_process(dt: float) -> void:
	if remoto:
		return
	var vel := linear_velocity
	var frente := global_basis.z
	var v_frente := vel.dot(frente)
	# motor e freio
	if ligado and motorista != null:
		var f := 0.0
		if _acel > 0.05:
			f = FORCA * _forca_x * _acel * (0.35 + 0.65 * motor) * clampf(1.0 - v_frente / VEL_MAX, 0.0, 1.0)
		elif _acel < -0.05:
			if v_frente > 1.0:
				brake = FREIO * -_acel             # andando para a frente: o "para trás" freia
			else:
				f = -FORCA_RE * _forca_x * -_acel * (0.35 + 0.65 * motor)
		engine_force = f
		if _acel >= -0.05 or v_frente <= 1.0:
			brake = (FREIO * 1.6 if _freio_mao else 0.0) + (0.0 if absf(_acel) > 0.05 else 3.0)
		var lim := GIRO_MAX * lerpf(1.0, 0.22, clampf(absf(v_frente) / VEL_MAX, 0.0, 1.0))
		steering = move_toward(steering, -_giro * lim, dt * 2.5)
		# combustível
		combustivel = maxf(0.0, combustivel - (absf(v_frente) * dt / 1000.0) * LITROS_POR_KM - dt * LITROS_MINUTO / 60.0)
		if combustivel <= 0.0:
			desligar_motor()
		_t_barulho -= dt
		if _t_barulho <= 0.0:
			_t_barulho = 1.0
			if vagos != null:
				vagos.barulho(global_position, BARULHO * (0.6 + 0.4 * clampf(absf(v_frente) / 15.0, 0.0, 1.0)), true)
		_som.pitch_scale = 0.7 + absf(v_frente) / VEL_MAX * 1.3
		_som.volume_db = -6.0 + 6.0 * clampf(absf(_acel), 0.0, 1.0)
	else:
		engine_force = 0.0
		brake = 40.0 if motorista == null else 3.0          # sem motorista: freio de mão puxado
		steering = move_toward(steering, 0.0, dt)
	# batidas: perda brusca de velocidade
	var dv := (vel - _vel_ant).length()
	_vel_ant = vel
	if dv > 7.0 and dt > 0.0:
		var forca := (dv - 7.0)
		motor = maxf(0.0, motor - forca * 0.04)
		Sons.em("impactos/bala_metal", global_position + Vector3(0, 0.8, 0), clampf(-10.0 + forca * 2.0, -10.0, 6.0), 60.0, 0.5)
		if ao_bater.is_valid():
			ao_bater.call(forca * 3.0)
		if motor <= 0.0 and ligado:
			desligar_motor()
	# atropelar
	_t_atropelo -= dt
	if _t_atropelo <= 0.0 and vel.length() > 4.0:
		_t_atropelo = 0.1
		_atropelar(vel)

func _atropelar(vel: Vector3) -> void:
	if vagos == null:
		return
	var p := global_position
	var frente := global_basis.z * signf(vel.dot(global_basis.z))
	for v in vagos.vivos.duplicate():
		if not is_instance_valid(v) or v.get("estado") == 4:
			continue
		var d: Vector3 = v.global_position - p
		d.y = 0.0
		if d.length() > 3.0 or d.normalized().dot(frente) < 0.3:
			continue
		var dano := vel.length() * DANO_ATROPELAR
		if v.has_method("receber_golpe"):
			v.receber_golpe(dano, frente, motorista)
			if v.has_method("derrubar") and int(v.get("estado")) != 4:
				v.derrubar()                         # 0.89: quem não morre vai para o chão
		linear_velocity *= 0.93
		motor = maxf(0.0, motor - 0.01)

# som do motor feito por código: um laço curto (dente de serra grave + ruído), o tom muda com a velocidade
static var _wav_cache: AudioStreamWAV = null

static func _motor_wav() -> AudioStreamWAV:
	if _wav_cache != null:
		return _wav_cache
	var taxa := 22050
	var n := taxa / 2
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var fase := 0.0
	var ruido := 0.0
	for i in n:
		var f := 55.0
		fase = fmod(fase + f / taxa, 1.0)
		ruido = ruido * 0.9 + (randf() * 2.0 - 1.0) * 0.1
		var pulso := 1.0 if fmod(fase * 4.0, 1.0) < 0.18 else 0.0           # "batidas" dos cilindros
		var x := (fase * 2.0 - 1.0) * 0.35 + pulso * 0.35 + ruido * 0.6
		var s := int(clampf(x, -1.0, 1.0) * 20000.0)
		dados.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.stereo = false
	w.data = dados
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_wav_cache = w
	return w

# ---------- estado (guardar / rede) ----------
func estado() -> Dictionary:
	var p := global_position
	return {"t": tipo, "cor": cor.to_html(false), "p": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
		"g": snappedf(rotation.y, 0.001), "c": snappedf(combustivel, 0.01), "m": snappedf(motor, 0.01)}
