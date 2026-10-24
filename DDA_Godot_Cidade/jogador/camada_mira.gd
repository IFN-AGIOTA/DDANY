extends SkeletonModifier3D
# CAMADA DE MIRA (0.61): mirando com arma de fogo, o TRONCO inclina para cima/para baixo junto com a câmera (a arma
# aponta para onde a mira está, não sempre reto). A inclinação é dividida entre as três vértebras (spine_01..03);
# braços, cabeça e arma vão junto porque são filhos delas. Os fuzis (jogador/ik_fuzil.gd) recebem o mesmo ângulo.
# Quem passa o ângulo e o peso é o jogador/modelo_sobrevivente.gd (_process), lendo mira_pitch do jogador (local
# ou remoto). Roda depois da camada de ação e ANTES do IK do fuzil.
# Mexa AQUI para: quanto cada vértebra inclina e a velocidade de entrar/sair.

const OSSOS := ["spine_01", "spine_02", "spine_03"]
const FRACAO := [0.2, 0.35, 0.45]           # parte do ângulo em cada vértebra (soma 1)
const ENTRA := 8.0

var angulo := 0.0                          # radianos, + = para cima (alvo; suavizado em _angulo)
var ligado := false
var _angulo := 0.0
var _peso := 0.0
var _i: Array = []
var aplicado := 0.0                        # ângulo que está sendo usado agora (o IK do fuzil lê)

func preparar(sk: Skeleton3D) -> void:
	for o in OSSOS:
		_i.append(sk.find_bone(o))
	active = true

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _i.is_empty():
		return
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	_peso = move_toward(_peso, 1.0 if ligado else 0.0, dt * ENTRA)
	_angulo = lerpf(_angulo, angulo, minf(1.0, dt * 14.0))
	var a := _angulo * smoothstep(0.0, 1.0, _peso)
	aplicado = a
	if absf(a) < 0.001:
		return
	# frente do esqueleto = +Z: girar em X por -a leva a frente para cima
	for k in _i.size():
		var b: int = _i[k]
		if b < 0:
			continue
		var g := sk.get_bone_global_pose(b).basis
		var ng := Basis(Vector3.RIGHT, -a * float(FRACAO[k])) * g
		var gp := sk.get_bone_global_pose(sk.get_bone_parent(b)).basis
		sk.set_bone_pose_rotation(b, (gp.inverse() * ng).get_rotation_quaternion())
