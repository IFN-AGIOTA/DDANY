extends SkeletonModifier3D
# CAMADA DO MUTADO (0.94): o corpo do jogador MUTADO fica CURVADO (lore: "costelas e mandíbula deformadas", anda como
# bicho): coluna dobrada para a frente, ombros erguidos e para a frente, braços soltos na frente do corpo e a cabeça
# erguida para olhar adiante. Vale em cima de qualquer animação (andar, correr, golpe...). Quem liga é o
# jogador/modelo_sobrevivente.gd (definir_mutacao). Roda depois da camada de mira (mesmo jeito: gira na pose global
# do esqueleto, frente = +Z; ângulo + em X dobra para a frente).
# Mexa AQUI para: quanto cada osso dobra.

# osso -> ângulo (radianos) em volta do eixo X do esqueleto
const CURVA := {"spine_01": 0.22, "spine_02": 0.28, "spine_03": 0.22, "neck_01": -0.26, "Head": -0.34,
	"clavicle_l": -0.16, "clavicle_r": -0.16, "upperarm_l": -0.38, "upperarm_r": -0.38, "lowerarm_l": -0.3, "lowerarm_r": -0.3}
const ENTRA := 1.5                         # velocidade de curvar/desentortar (por segundo)

var ligado := false
var _peso := 0.0
var _ossos: Array = []                     # [índice, ângulo] na ordem da corrente (pai antes do filho)

func preparar(sk: Skeleton3D) -> void:
	for o in CURVA:
		var b := sk.find_bone(o)
		if b >= 0:
			_ossos.append([b, float(CURVA[o])])
	active = true

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _ossos.is_empty():
		return
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	_peso = move_toward(_peso, 1.0 if ligado else 0.0, dt * ENTRA)
	var p := smoothstep(0.0, 1.0, _peso)
	if p < 0.001:
		return
	for par in _ossos:
		var b: int = par[0]
		var g := sk.get_bone_global_pose(b).basis
		var ng := Basis(Vector3.RIGHT, float(par[1]) * p) * g
		var pai := sk.get_bone_parent(b)
		var gp := sk.get_bone_global_pose(pai).basis if pai >= 0 else Basis.IDENTITY
		sk.set_bone_pose_rotation(b, (gp.inverse() * ng).get_rotation_quaternion())
