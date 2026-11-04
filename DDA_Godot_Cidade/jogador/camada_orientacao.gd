extends SkeletonModifier3D
# 1.12 · ORIENTAÇÃO DAS PERNAS E INCLINAÇÃO ("orientation warping" e "lean", como na Unreal 5):
#   · andando na DIAGONAL (mirando ou em 1ª pessoa o tronco fica na mira): a animação mais perto (frente, lado, costas)
#     toca e o QUADRIL gira o que falta para os passos irem na direção certa; a coluna gira de volta, então o tronco
#     (e a arma) continuam apontando para a mira;
#   · nas CURVAS o tronco inclina para dentro, mais quanto mais rápido (correndo é bem visível).
# angulo e inclinacao vêm do jogador/animador_modelo.gd; aqui só suaviza e aplica. Depois da inércia, antes do resto.
# Mexa AQUI para: os limites e a suavização.

const MAX_ANGULO := 1.0       # rad (57°)
const MAX_INCLINA := 0.2      # rad (11°)

var angulo := 0.0             # rad: + = os passos vão para a DIREITA da direção da animação
var inclinacao := 0.0         # rad: + = o tronco inclina para a direita
var _ang := 0.0
var _inc := 0.0
var _pelvis := -1
var _coluna := -1
var aplicado := 0.0

func preparar(sk: Skeleton3D) -> void:
	_pelvis = sk.find_bone("pelvis")
	_coluna = sk.find_bone("spine_01")
	active = true

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _pelvis < 0 or _coluna < 0:
		return
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	_ang = lerp_angle(_ang, clampf(angulo, -MAX_ANGULO, MAX_ANGULO), minf(1.0, dt * 10.0))
	_inc = lerpf(_inc, clampf(inclinacao, -MAX_INCLINA, MAX_INCLINA), minf(1.0, dt * 6.0))
	aplicado = _ang
	if absf(_ang) < 0.002 and absf(_inc) < 0.002:
		return
	# espaço do esqueleto: frente = +Z, esquerda do personagem = +X. Passos para a direita = girar em Y por -ângulo.
	var gp := sk.get_bone_global_pose(_pelvis)
	var gc := sk.get_bone_global_pose(_coluna)
	var pai_p := sk.get_bone_parent(_pelvis)
	var gpai := sk.get_bone_global_pose(pai_p) if pai_p >= 0 else Transform3D.IDENTITY
	var yaw := Basis(Vector3.UP, -_ang)
	var nova_p := yaw * gp.basis
	sk.set_bone_pose_rotation(_pelvis, (gpai.basis.inverse() * nova_p).get_rotation_quaternion())
	# a coluna volta para onde estava (tronco na mira) e inclina para dentro da curva
	var nova_c := Basis(Vector3.BACK, _inc) * gc.basis       # em +Z por +ângulo: a cabeça vai para -X (direita)
	sk.set_bone_pose_rotation(_coluna, (nova_p.inverse() * nova_c).get_rotation_quaternion())
