extends SkeletonModifier3D
# FUZIL NAS DUAS MÃOS (usado por jogador/modelo_sobrevivente.gd): roda DEPOIS da animação, a cada quadro.
#   1) põe o fuzil no lugar: BAIXO (atravessado na frente da barriga, cano para baixo e para a esquerda),
#      preso ao PEITO, ou MIRANDO (coronha no ombro direito, mira na altura do olho, cano para a frente),
#      preso ao OMBRO. "mira" (0..1) mistura as duas;
#   2) leva cada mão ao seu lugar na arma com IK de dois ossos (braço + antebraço), com o cotovelo puxado
#      para um "polo" (direito: para fora e para baixo; esquerdo: para baixo), e gira a mão para pegar a arma:
#      direita na empunhadura (igual à pistola), esquerda espalmada embaixo do guarda-mão;
#   3) mirando, abaixa um pouco a cabeça para encostar o rosto na coronha.
#   4) 0.98 · 1ª PESSOA (fp): a arma fica presa à CÂMERA (armas/mira_ferro.gd): embaixo à direita sem mirar e, mirando
#      (ads), com o olho na câmera e a linha alça -> massa no centro da tela. As mãos vão até ela do mesmo jeito.
#      A pistola também entra aqui em 1ª pessoa (duas mãos: a esquerda por baixo da empunhadura).
#   5) 0.98 · GUARDA em 1ª pessoa sem arma de fogo (punhos / arma branca): as mãos sobem na frente, à vista (punhos:
#      as duas; arma branca: a direita, com a arma para cima e para a frente). No golpe a guarda sai (animação).
# Tudo no espaço do esqueleto (frente = +Z, cima = +Y). Mexa AQUI para: posição do fuzil e das mãos.

const MiraFerro := preload("res://armas/mira_ferro.gd")

var ponto: Node3D                      # onde o fuzil fica pendurado (filho do esqueleto)
var mira := 0.0
var pitch := 0.0                       # 0.61: inclinação da mira (+ = para cima), igual à do tronco (camada_mira.gd)
var mao_esq_z := 0.25                  # onde a mão esquerda segura (distância da empunhadura, no cano)
# posições (relativas ao peito/ombro na pose atual da animação)
var baixo := Transform3D.IDENTITY      # relativo ao osso do peito (spine_03)
var mirando := Transform3D.IDENTITY    # relativo ao ombro direito (upperarm_r)
var mao_dir := Transform3D.IDENTITY    # punho direito no espaço da arma
var dir_lado := -1.0                   # x do lado direito do corpo (-1 ou 1)
# 0.98 · 1ª pessoa / mira de ferro (jogador/modelo_sobrevivente.gd preenche)
var camera: Camera3D = null
var fp := 0.0                          # 0 = 3ª pessoa · 1 = 1ª pessoa (arma presa à câmera)
var ads := 0.0                         # 0 = sem mirar · 1 = mirando pela mira de ferro
var tipo := ""                         # arma na mão (para a tabela da mira de ferro)
var luneta := ""                       # 0.99: luneta encaixada (o olho vai para trás da ocular)
var pistola := false                   # pistola nas duas mãos: a esquerda por baixo da empunhadura
var guarda := 0.0                      # 0.98: 0..1 guarda em 1ª pessoa (sem arma de fogo)
var guarda_punhos := false             # as duas mãos (punhos) · false = arma branca na direita
const GUARDA_DIR := Vector3(0.15, -0.19, 0.36)   # mão direita no quadro da câmera (x lado direito, y cima, z frente)
const GUARDA_ESQ := Vector3(-0.14, -0.20, 0.34)

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
	if pistola:
		# 0.98: pistola: a esquerda em CONCHA por baixo do carregador (fica abaixo da linha de mira, não tampa)
		dedos = Vector3(d * 0.25, 0.25, 0.93).normalized()
		palma = Vector3(d * 0.2, 1.0, 0.0)
	palma = (palma - dedos * palma.dot(dedos)).normalized()
	# na mão esquerda o eixo X local aponta para o lado da palma (espelho da direita)
	var b := Basis(palma, dedos, palma.cross(dedos)) * _mao_esq_local.inverse()
	var contato := Vector3(0, -0.05, mao_esq_z)
	if pistola:
		contato = Vector3(-d * 0.005, -0.125, -0.01)      # 0.98: por baixo do fundo do carregador
	return Transform3D(b, contato - dedos * 0.075 - palma * 0.035)

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or ponto == null or _i.is_empty():
		return
	if guarda > 0.001:
		_guarda(sk)
		return
	var peito := sk.get_bone_global_pose(_i["spine_03"]).origin
	var ombro := sk.get_bone_global_pose(_i["upperarm_r"]).origin
	var tb := Transform3D(baixo.basis, peito + baixo.origin)
	var giro := Basis(Vector3.RIGHT, -pitch)          # o fuzil gira em volta do ombro junto com o tronco
	var tm := Transform3D(giro * mirando.basis, ombro + giro * mirando.origin)
	var t := tb.interpolate_with(tm, smoothstep(0.0, 1.0, mira))
	if fp > 0.001 and camera != null and is_instance_valid(camera) and MiraFerro.tem(tipo):
		# 0.98: 1ª pessoa: a arma presa à câmera (quadril <-> mira de ferro)
		var w := MiraFerro.transform_arma(tipo, camera.global_transform, ads, luneta)
		var t_fp := sk.global_transform.affine_inverse() * w
		t = t.interpolate_with(t_fp, smoothstep(0.0, 1.0, fp))
	ponto.transform = t
	if mira > 0.01:
		_inclinar_cabeca(sk, mira)
	# 0.98: pistola: a mão do personagem é grande para ela; mais baixa na empunhadura deixa a alça e a massa livres
	var md := mao_dir if not pistola else Transform3D(mao_dir.basis, mao_dir.origin + Vector3(0, -0.035, -0.012))
	_dois_ossos(sk, "r", t * md, Vector3(dir_lado * 0.45, -0.55, -0.1))
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
# 0.98: GUARDA (1ª pessoa, punhos ou arma branca): as mãos num ponto preso à câmera
func _guarda(sk: Skeleton3D) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var d := dir_lado
	# quadro da câmera no espaço do esqueleto, virado como o esqueleto (+Z = frente)
	var f := sk.global_transform.affine_inverse() * camera.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var k := smoothstep(0.0, 1.0, guarda)
	var incl := 0.35 if guarda_punhos else 1.0        # punho para a frente · arma branca para cima e para a frente
	var pd := Vector3(d * GUARDA_DIR.x, GUARDA_DIR.y, GUARDA_DIR.z)
	var alvo_d := f * Transform3D(Basis(Vector3.RIGHT, -incl), pd) * mao_dir
	var atual_d := sk.get_bone_global_pose(_i["hand_r"])
	_dois_ossos(sk, "r", atual_d.interpolate_with(alvo_d, k), Vector3(d * 0.45, -0.55, -0.1))
	if guarda_punhos:
		# esquerda: o espelho da direita
		var s := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
		var me := Transform3D(s * mao_dir.basis * s, Vector3(-mao_dir.origin.x, mao_dir.origin.y, mao_dir.origin.z))
		var pe := Vector3(d * GUARDA_ESQ.x, GUARDA_ESQ.y, GUARDA_ESQ.z)
		var alvo_e := f * Transform3D(Basis(Vector3.RIGHT, -incl), pe) * me
		var atual_e := sk.get_bone_global_pose(_i["hand_l"])
		_dois_ossos(sk, "l", atual_e.interpolate_with(alvo_e, k), Vector3(-d * 0.45, -0.55, -0.1))

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
