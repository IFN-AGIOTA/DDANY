extends VehicleBody3D
# VEÍCULO DIRIGÍVEL (0.76) · um carro largado que FUNCIONA (sedã, táxi ou van; mundo/veiculos.gd escolhe quais e cuida
# de entrar/sair, guardar e a rede). Física de carro da Godot (VehicleBody3D, 4 rodas, tração atrás, direção na frente);
# o desenho é o mesmo modelo dos carros da rua (mundo/abandono.gd), virado para +Z (a frente do VehicleBody3D).
#   - dirigir: acelerar/ré, virar, freio de mão; COMBUSTÍVEL (litros) gasta com a distância e com o motor ligado;
#     sem gasolina o motor morre. Bater forte estraga o MOTOR (estado 0..1: menos força; 0 = não liga) e machuca.
#   - atropelar infectados (e jogadores no PvP) com velocidade machuca/derruba; o motor faz barulho (os infectados
#     perto ouvem) e tem som próprio (feito por código, mais agudo com a velocidade).
# 1.13 · CARROS DO MODO HISTÓRIA ("kiri86" do Dominic, "jdm99" do Greg): o desenho é o MODELO BAIXADO
#   (historia/carros/*.glb, Daniel Zhabotinsky, CC-BY), com INTERIOR: as rodas do modelo giram e esterçam (vão dentro
#   das rodas da física), o volante gira com a direção e, em 1ª PESSOA, a câmera fica no banco do motorista (painel,
#   volante e retrovisor à vista). Mais rápidos que os carros largados (VEL_MAX própria). MODELOS diz onde fica cada peça.
# 1.15 · DUKE '69: os carros que FUNCIONAM no modo livre (os sedãs, táxis e vans de antes, VIRA_DUKE) são o Duke '69
#   (mundo/carros/duke69.glb, Daniel Zhabotinsky, CC-BY), com o mesmo interior e as rodas/volante que giram; a
#   pintura é a cor do carro largado que ele substitui (o resto do modelo fica como veio).
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
	# 1.13: os carros da história (medidas tiradas do modelo; [7] = velocidade máxima em m/s)
	"kiri86": [0.71, 1.32, -1.14, 0.285, Vector3(1.7, 1.25, 4.3), 1100.0, 1.55, 40.0],
	"jdm99": [0.76, 1.32, -1.40, 0.325, Vector3(1.9, 1.3, 4.6), 1300.0, 1.85, 42.0],
	# 1.15: o Duke '69 (muscle car pesado, motor forte)
	"duke69": [0.78, 1.63, -1.30, 0.315, Vector3(1.9, 1.3, 5.2), 1550.0, 1.75, 34.0],
}
const VIRA_DUKE := ["sedan", "taxi", "van"]     # 1.15: estes, quando funcionam, são o Duke '69
# 1.13: modelo baixado de cada carro da história · frente do arquivo = +X (gira -90° em Y) · rodas e volante (nomes dos
# nós no .glb) · olho = onde fica a cabeça do motorista (no sistema do carro: frente +Z, esquerda +X)
const MODELOS := {
	"kiri86": {"arquivo": "res://historia/carros/kiri86.glb", "rodas": ["kiri86_Wheel_FL", "kiri86_Wheel_FR", "kiri86_Wheel_RL", "kiri86_Wheel_RR"],
		"volante": "kiri86_Steering_Wheel", "olho": Vector3(0.33, 1.13, -0.16)},
	"jdm99": {"arquivo": "res://historia/carros/jdm99.glb", "rodas": ["Gallo99_WheelStock_FL", "Gallo99_WheelStock_FR", "Gallo99_WheelStock_RL", "Gallo99_WheelStock_RR"],
		"volante": "Gallo99_Steering_Wheel", "olho": Vector3(0.35, 1.12, -0.24),
		"pincas": ["Gallo99_CaliperStock_FL", "Gallo99_CaliperStock_FR", "Gallo99_CaliperStock_RL", "Gallo99_CaliperStock_RR"]},
	# 1.15: "pintura" = o material da lataria (pintado com a cor do carro)
	"duke69": {"arquivo": "res://mundo/carros/duke69.glb", "rodas": ["Duke69_WhellStock_FL", "Duke69_WhellStock_FR", "Duke69_WhellStock_RL", "Duke69_WhellStock_RR"],
		"volante": "Duke69_Steering_Wheel", "olho": Vector3(0.36, 1.14, -0.12), "pintura": "Duke69_bodymat"},
}
const NOMES := {"sedan": "CARRO", "taxi": "TÁXI", "van": "VAN", "humvee": "HUMVEE", "caminhao_exercito": "CAMINHÃO DO EXÉRCITO",
	"duke69": "DUKE '69"}

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
var _vel_max := VEL_MAX                 # 1.13: carros da história são mais rápidos
var _rodas: Array = []                  # VehicleWheel3D (frente esq, frente dir, trás esq, trás dir)
var _volante: Node3D = null             # 1.13: volante do modelo (gira com a direção)
var _volante_base := Basis()
var _eixo_volante := Vector3.BACK
var cam_interior: Camera3D = null       # 1.13: câmera no banco do motorista (1ª pessoa)
var historia := false                   # 1.13: carro do modo história (sem combustível, sem dano no motor)

func _ready() -> void:
	if historia:
		add_to_group("historia_ocupa")         # 1.14: não nasce prédio de preenchimento em cima (historia/preenchimento.gd)
	if tipo in VIRA_DUKE:
		tipo = "duke69"                        # 1.15 (também os salvos antes e a cópia de um amigo dirigindo)
	var d: Array = TIPOS.get(tipo, TIPOS["sedan"])
	mass = float(d[5])
	_forca_x = float(d[6])
	if d.size() > 7:
		_vel_max = float(d[7])
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
	var modelo: Node3D = null
	if MODELOS.has(tipo):
		modelo = (load(MODELOS[tipo]["arquivo"]) as PackedScene).instantiate()
		modelo.name = "Modelo"
		modelo.rotation.y = -PI * 0.5       # o arquivo tem a frente em +X; aqui a frente é +Z
		add_child(modelo)
		if MODELOS[tipo].has("pintura"):
			_pintar(modelo, str(MODELOS[tipo]["pintura"]), cor_pintura(cor))
	else:
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
		_rodas.append(w)
	if modelo != null:
		_montar_modelo(modelo)
	_som = AudioStreamPlayer3D.new()
	_som.stream = _motor_wav()
	_som.unit_size = 8.0
	_som.max_distance = 120.0
	_som.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_som)
	if remoto:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

# 1.13: as rodas do modelo vão para dentro das rodas da física (giram e esterçam com elas) e o volante ganha um eixo
func _montar_modelo(modelo: Node3D) -> void:
	var info: Dictionary = MODELOS[tipo]
	var nomes: Array = info["rodas"]
	var pincas: Array = info.get("pincas", [])
	for k in 4:
		var no := modelo.find_child(str(nomes[k]), true, false) as Node3D
		if no == null:
			continue
		var w: VehicleWheel3D = _rodas[k]
		# centro da roda no sistema do carro
		var mis := no.find_children("*", "MeshInstance3D", true, false)
		if mis.is_empty():
			continue
		var mi: MeshInstance3D = mis[0]
		var c_local := mi.get_aabb().get_center()
		var c_carro: Vector3 = (modelo.transform * _no_ate(modelo, mi)) * c_local
		var mi2 := mi.duplicate() as MeshInstance3D
		no.queue_free()
		w.add_child(mi2)
		mi2.transform = Transform3D(modelo.basis * _no_ate(modelo, mi).basis, -(c_carro - w.position) * 0.0)
		mi2.position = mi2.transform.basis * -c_local
		w.position = Vector3(c_carro.x, c_carro.y + 0.1, c_carro.z)
		if k < pincas.size():
			var pc := modelo.find_child(str(pincas[k]), true, false) as Node3D
			if pc != null:
				pc.visible = false              # a pinça do freio ficaria girando junto: some (quase não aparece)
	var vol := modelo.find_child(str(info["volante"]), true, false) as Node3D
	if vol != null:
		var mv := vol.find_children("*", "MeshInstance3D", true, false)
		if not mv.is_empty():
			var mim: MeshInstance3D = mv[0]
			var cl := mim.get_aabb().get_center()
			var tr_carro: Transform3D = modelo.transform * _no_ate(modelo, mim)
			var c := tr_carro * cl
			# o volante gira em volta do eixo da coluna (no modelo, a coluna aponta para o motorista: -X do arquivo)
			var piv := Node3D.new()
			piv.name = "Volante"
			add_child(piv)
			piv.position = c
			var mi3 := mim.duplicate() as MeshInstance3D
			piv.add_child(mi3)
			mi3.transform = Transform3D(tr_carro.basis, tr_carro.basis * -cl)
			vol.queue_free()
			_volante = piv
			_volante_base = piv.basis
			_eixo_volante = (modelo.basis * Vector3(1, 0.35, 0)).normalized()     # coluna inclinada
	cam_interior = Camera3D.new()
	cam_interior.name = "CameraInterior"
	cam_interior.fov = 72.0
	cam_interior.near = 0.03
	cam_interior.position = info["olho"]
	cam_interior.rotation.y = PI                 # a câmera olha para -Z; a frente do carro é +Z
	add_child(cam_interior)

# 1.13: 1ª pessoa dirigindo um carro com interior: a câmera vai para o banco do motorista (olhando em volta com o
# mesmo "olhar" do jogador, limitado); 3ª pessoa: volta a câmera do jogador. Não briga com a câmera das cutscenes.
func _process(_dt: float) -> void:
	if cam_interior == null:
		return
	var vp := get_viewport()
	var atual := vp.get_camera_3d() if vp != null else null
	var m = motorista
	var quer: bool = m != null and is_instance_valid(m) and m.get("primeira_pessoa") == true
	if quer:
		var cj: Camera3D = m.get("camera")
		if atual == cj or atual == cam_interior:
			if atual != cam_interior:
				cam_interior.make_current()
			# olhar em volta: o quanto a câmera do jogador está girada em relação à traseira do carro
			_luz_painel(true)
			var rel := wrapf(float(m.get("cam_yaw")) - (rotation.y + PI), -PI, PI)
			cam_interior.rotation = Vector3(clampf(-(float(m.get("cam_pit")) - 0.3) * 0.6, -0.5, 0.35), PI + clampf(rel, -2.2, 2.2), 0.0)
	else:
		_luz_painel(false)
	if not quer and atual == cam_interior:
		var cj2 = m.get("camera") if m != null and is_instance_valid(m) else null
		if cj2 != null:
			(cj2 as Camera3D).make_current()
		else:
			cam_interior.clear_current(false)

# 1.13: luz fraca e quente do painel, só com a câmera dentro do carro (à noite o interior ficava todo preto)
var _luz: OmniLight3D = null
func _luz_painel(ligar: bool) -> void:
	if not ligar:
		if _luz != null:
			_luz.visible = false
		return
	if _luz == null:
		_luz = OmniLight3D.new()
		_luz.name = "LuzPainel"
		_luz.light_color = Color(1.0, 0.88, 0.72)
		_luz.light_energy = 0.28
		_luz.omni_range = 1.6
		_luz.shadow_enabled = false
		var olho: Vector3 = MODELOS[tipo]["olho"]
		_luz.position = olho + Vector3(-0.2, -0.15, 0.55)
		add_child(_luz)
	_luz.visible = true

# transformação de "no" até "raiz" (sem a da raiz)
func _no_ate(raiz: Node3D, no: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = no
	while n != null and n != raiz:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

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
			f = FORCA * _forca_x * _acel * (0.35 + 0.65 * motor) * clampf(1.0 - v_frente / _vel_max, 0.0, 1.0)
		elif _acel < -0.05:
			if v_frente > 1.0:
				brake = FREIO * -_acel             # andando para a frente: o "para trás" freia
			else:
				f = -FORCA_RE * _forca_x * -_acel * (0.35 + 0.65 * motor)
		engine_force = f
		if _acel >= -0.05 or v_frente <= 1.0:
			brake = (FREIO * 1.6 if _freio_mao else 0.0) + (0.0 if absf(_acel) > 0.05 else 3.0)
		var lim := GIRO_MAX * lerpf(1.0, 0.22, clampf(absf(v_frente) / _vel_max, 0.0, 1.0))
		steering = move_toward(steering, -_giro * lim, dt * 2.5)
		# combustível
		if historia:
			combustivel = TANQUE
		combustivel = maxf(0.0, combustivel - (absf(v_frente) * dt / 1000.0) * LITROS_POR_KM - dt * LITROS_MINUTO / 60.0)
		if combustivel <= 0.0:
			desligar_motor()
		_t_barulho -= dt
		if _t_barulho <= 0.0:
			_t_barulho = 1.0
			if vagos != null:
				vagos.barulho(global_position, BARULHO * (0.6 + 0.4 * clampf(absf(v_frente) / 15.0, 0.0, 1.0)), true)
		_som.pitch_scale = 0.7 + absf(v_frente) / _vel_max * 1.3
		_som.volume_db = -6.0 + 6.0 * clampf(absf(_acel), 0.0, 1.0)
	else:
		engine_force = 0.0
		brake = 40.0 if motorista == null else 3.0          # sem motorista: freio de mão puxado
		steering = move_toward(steering, 0.0, dt)
	# batidas: perda brusca de velocidade
	var dv := (vel - _vel_ant).length()
	_vel_ant = vel
	if _volante != null:
		_volante.basis = _volante_base * Basis(_eixo_volante, steering * 3.2)
	if dv > 7.0 and dt > 0.0:
		var forca := (dv - 7.0)
		if not historia:
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


# ---------- 1.15: DUKE '69 ----------
# a cor da lataria (a do carro largado que ele substitui; sem transparência)
static func cor_pintura(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 1.0)

func _pintar(modelo: Node3D, material: String, c: Color) -> void:
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for k in m.get_surface_count():
			var mat := m.surface_get_material(k) as BaseMaterial3D
			if mat != null and mat.resource_name == material:
				var nova := mat.duplicate() as BaseMaterial3D
				nova.albedo_color = c
				nova.metallic = maxf(nova.metallic, 0.35)
				nova.roughness = minf(nova.roughness, 0.45)
				(mi as MeshInstance3D).set_surface_override_material(k, nova)

# o modelo inteiro numa malha só (as peças juntas, uma superfície por material), frente em +X como os carros
# largados: os Dukes PARADOS na rua (mundo/veiculos.gd, MultiMesh). A lataria pega a cor de cada instância.
static var _malha_duke: ArrayMesh = null
static func malha_duke() -> ArrayMesh:
	if _malha_duke != null:
		return _malha_duke
	var info: Dictionary = MODELOS["duke69"]
	var cena: Node3D = (load(info["arquivo"]) as PackedScene).instantiate()
	var grupos := {}                           # material -> SurfaceTool
	var ordem: Array = []
	for mi in cena.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var tr := _ate(cena, mi as Node3D)
		for k in m.get_surface_count():
			var mat: Material = m.surface_get_material(k)
			if not grupos.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				grupos[mat] = st
				ordem.append(mat)
			(grupos[mat] as SurfaceTool).append_from(m, k, tr)
	var am := ArrayMesh.new()
	for mat in ordem:
		(grupos[mat] as SurfaceTool).commit(am)
		var usar: Material = mat
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).resource_name == str(info["pintura"]):
			var p := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			p.albedo_color = Color.WHITE
			p.vertex_color_use_as_albedo = true        # a cor da instância (MultiMesh) pinta a lataria
			p.metallic = maxf(p.metallic, 0.35)
			p.roughness = minf(p.roughness, 0.45)
			usar = p
		am.surface_set_material(am.get_surface_count() - 1, usar)
	cena.free()
	_malha_duke = am
	return am

# versão simples de longe (a caixa do sedã esticada no tamanho do Duke, pintada pela instância)
static var _malha_duke_longe: ArrayMesh = null
static func malha_duke_longe() -> ArrayMesh:
	if _malha_duke_longe != null:
		return _malha_duke_longe
	var base: ArrayMesh = Abandono.modelo_longe("sedan")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in base.get_surface_count():
		st.append_from(base, k, Transform3D(Basis.from_scale(Vector3(5.2 / 4.4, 1.3 / 1.6, 1.96 / 1.85)), Vector3.ZERO))
	var am := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.5
	am.surface_set_material(0, mat)
	_malha_duke_longe = am
	return am

# transformação de "de" até o nó "no" (a cena não está na árvore)
static func _ate(de: Node3D, no: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = no
	while n != null and n != de:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
