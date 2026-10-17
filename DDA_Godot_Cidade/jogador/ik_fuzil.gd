extends SkeletonModifier3D
# FUZIL NAS DUAS MÃOS (usado por jogador/modelo_sobrevivente.gd): roda DEPOIS da animação, a cada quadro.
#   1) põe o fuzil no lugar: BAIXO (atravessado na frente da barriga, cano para baixo e para a esquerda),
#      preso ao PEITO, ou MIRANDO (coronha no ombro direito, mira na altura do olho, cano para a frente),
#      preso ao OMBRO. "mira" (0..1) mistura as duas;
#   2) leva cada mão ao seu lugar na arma com IK de dois ossos (braço + antebraço), com o cotovelo puxado
#      para um "polo" (direito: para fora e para baixo; esquerdo: para baixo), e gira a mão para pegar a arma:
#      direita na empunhadura (igual à pistola), esquerda espalmada embaixo do guarda-mão;
#   3) mirando, abaixa um pouco a cabeça para encostar o rosto na coronha.
# Tudo no espaço do esqueleto (frente = +Z, cima = +Y). Mexa AQUI para: posição do fuzil e das mãos.

var ponto: Node3D                      # onde o fuzil fica pendurado (filho do esqueleto)
var mira := 0.0
var mao_esq_z := 0.25                  # onde a mão esquerda segura (distância da empunhadura, no cano)
# posições (relativas ao peito/ombro na pose atual da animação)
var baixo := Transform3D.IDENTITY      # relativo ao osso do peito (spine_03)
var mirando := Transform3D.IDENTITY    # relativo ao ombro direito (upperarm_r)
var mao_dir := Transform3D.IDENTITY    # punho direito no espaço da arma
var dir_lado := -1.0                   # x do lado direito do corpo (-1 ou 1)

var _i := {}
var _mao_esq_local := Basis.IDENTITY     # eixos (palma, dedos, lado) da mão esquerda no espaço do osso dela

func preparar(sk: Skeleton3D, anim: AnimationPlayer) -> void:
	for n in ["spine_03", "neck_01", "Head", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l"]:
		_i[n] = sk.find_bone(n)
	dir_lado = signf(sk.get_bone_global_rest(_i["upperarm_r"]).origin.x)
	# eixos reais da mão esquerda (cada personagem tem o osso da mão orientado de um jeito): na pose T a palma
	# olha para baixo e os dedos apontam do punho para o dedo médio
	var gm := sk.get_bone_global_rest(_i["hand_l"])
	var med := sk.find_bone("middle_01_l")
	var dedos_g := (sk.get_bone_global_rest(med).origin - gm.origin).normalized() if med >= 0 else Vector3(-dir_lado, 0, 0)
	var palma_g := (Vector3.DOWN - dedos_g * Vector3.DOWN.dot(dedos_g)).normalized()
	var inv := gm.basis.orthonormalized().inverse()
	var dl := (inv * dedos_g).normalized()
	var pl := (inv * palma_g).normalized()
	_mao_esq_local = Basis(pl, dl, pl.cross(dl))
	# a mão direita segura o fuzil como segura a pistola na animação de mirar (cano para +Z, empunhadura na palma)
	anim.play("mirar")
	anim.seek(0.4, true)
	var gh := sk.get_bone_global_pose(_i["hand_r"])
	var b := gh.basis.orthonormalized()
	mao_dir = Transform3D(b, -(b.y * 0.075 - b.z * 0.012) + Vector3(0, -0.02, 0))
	anim.play("parado")
	anim.seek(0.0, true)
	var d := dir_lado
	# BAIXO: empunhadura na frente do quadril direito, cano para baixo, para a frente e cruzando para a esquerda
	var cano := Vector3(-d * 0.62, -0.42, 0.66).normalized()
	var cima := (Vector3.UP - cano * cano.dot(Vector3.UP)).normalized()
	baixo = Transform3D(Basis(cima.cross(cano), cima, cano), Vector3(d * 0.1, -0.27, 0.27))
	# MIRANDO: coronha no ombro (a coronha fica ~0,28 m atrás da empunhadura), cano reto para a frente
	mirando = Transform3D(Basis.IDENTITY, Vector3(-d * 0.12, 0.04, 0.33))

func _mao_esq() -> Transform3D:
	# esquerda espalmada embaixo do guarda-mão: palma para cima, dedos para a frente e para a direita
	var d := dir_lado
	var dedos := Vector3(d * 0.45, 0.1, 0.88).normalized()
	var palma := Vector3(d * 0.35, 1.0, 0.0)
	palma = (palma - dedos * palma.dot(dedos)).normalized()
	# na mão esquerda o eixo X local aponta para o lado da palma (espelho da direita)
	var b := Basis(palma, dedos, palma.cross(dedos)) * _mao_esq_local.inverse()
	var contato := Vector3(0, -0.05, mao_esq_z)
	return Transform3D(b, contato - dedos * 0.075 - palma * 0.035)

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or ponto == null or _i.is_empty():
		return
	var peito := sk.get_bone_global_pose(_i["spine_03"]).origin
	var ombro := sk.get_bone_global_pose(_i["upperarm_r"]).origin
	var tb := Transform3D(baixo.basis, peito + baixo.origin)
	var tm := Transform3D(mirando.basis, ombro + mirando.origin)
	var t := tb.interpolate_with(tm, smoothstep(0.0, 1.0, mira))
	ponto.transform = t
	if mira > 0.01:
		_inclinar_cabeca(sk, mira)
	_dois_ossos(sk, "r", t * mao_dir, Vector3(dir_lado * 0.45, -0.55, -0.1))
	_dois_ossos(sk, "l", t * _mao_esq(), Vector3(-dir_lado * 0.15, -0.8, 0.1))

# encosta o rosto na coronha: cabeça um pouco para baixo e para o lado da arma
func _inclinar_cabeca(sk: Skeleton3D, f: float) -> void:
	var i: int = _i["Head"]
	var pai := sk.get_bone_parent(i)
	var g := sk.get_bone_global_pose(i)
	var giro := Basis(Vector3.RIGHT, 0.22 * f) * Basis(Vector3.BACK, -dir_lado * 0.12 * f)
	var ng := giro * g.basis
	var gp := sk.get_bone_global_pose(pai).basis
	sk.set_bone_pose_rotation(i, (gp.inverse() * ng).get_rotation_quaternion())

# IK analítico de dois ossos: ombro A, cotovelo B, punho C -> punho no alvo, cotovelo para o polo
func _dois_ossos(sk: Skeleton3D, lado: String, alvo: Transform3D, polo_rel: Vector3) -> void:
	var ia: int = _i["upperarm_" + lado]
	var ib: int = _i["lowerarm_" + lado]
	var ic: int = _i["hand_" + lado]
	var ga := sk.get_bone_global_pose(ia)
	var gb := sk.get_bone_global_pose(ib)
	var gc := sk.get_bone_global_pose(ic)
	var a := ga.origin
	var l1 := a.distance_to(gb.origin)
	var l2 := gb.origin.distance_to(gc.origin)
	var para := alvo.origin - a
	var d := clampf(para.length(), 0.02, (l1 + l2) * 0.999)
	var eixo := para.normalized()
	var polo := polo_rel - eixo * polo_rel.dot(eixo)
	if polo.length() < 0.001:
		polo = Vector3.DOWN
	polo = polo.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * d * l1), -1.0, 1.0)
	var cotovelo := a + eixo * (l1 * ca) + polo * (l1 * sqrt(1.0 - ca * ca))
	var punho := a + eixo * d
	var q1 := Quaternion((gb.origin - a).normalized(), (cotovelo - a).normalized())
	var nba := Basis(q1) * ga.basis.orthonormalized()
	var filho := Basis(q1) * (gc.origin - gb.origin)
	var q2 := Quaternion(filho.normalized(), (punho - cotovelo).normalized())
	var nbb := Basis(q2) * Basis(q1) * gb.basis.orthonormalized()
	var gp := sk.get_bone_global_pose(sk.get_bone_parent(ia)).basis.orthonormalized()
	sk.set_bone_pose_rotation(ia, (gp.inverse() * nba).get_rotation_quaternion())
	sk.set_bone_pose_rotation(ib, (nba.inverse() * nbb).get_rotation_quaternion())
	sk.set_bone_pose_rotation(ic, (nbb.inverse() * alvo.basis.orthonormalized()).get_rotation_quaternion())
