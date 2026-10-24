extends SkeletonModifier3D
# CABEÇA OCULTA (0.65 · 1ª PESSOA): com a câmera nos olhos, o osso "Head" encolhe quase a zero. Assim cabelo, barba,
# olhos, o rosto e o que está preso na cabeça (boné, capacete, lanterna de cabeça) não ficam na frente da câmera,
# e o resto do corpo (braços, mãos, arma, pernas, roupa) continua aparecendo, como no DayZ.
# Quem liga é o jogador/modelo_sobrevivente.gd (primeira_pessoa). Roda depois das animações e da camada de mira.

var ligado := false
var _i := -1

func preparar(sk: Skeleton3D) -> void:
	_i = sk.find_bone("Head")
	active = true

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _i < 0 or not ligado:
		return
	sk.set_bone_pose_scale(_i, Vector3.ONE * 0.001)
