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
#   6) 1.14.2 · PEGADA CERTA (jogador/pegada.gd): a mão direita fecha em volta da empunhadura/cabo de cada arma (antes a
#      arma saía pela ponta dos dedos). Modo "mao" (arma branca e pistola em 3ª pessoa, presas no osso da mão): a arma
#      continua indo para onde a animação manda, e a mão gira/ajusta para segurá-la direito; a pistola ganha a mão
#      esquerda de apoio e as armas brancas de duas mãos (taco, machado, cano, lança), a esquerda no cabo.
# Tudo no espaço do esqueleto (frente = +Z, cima = +Y). Mexa AQUI para: posição do fuzil e das mãos.

const MiraFerro := preload("res://armas/mira_ferro.gd")
const Pegada := preload("res://jogador/pegada.gd")

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
var modo := ""                         # 1.14.2: "fuzil" (arma no encaixe do fuzil) · "mao" (arma presa na mão) · ""
var ponto_antigo := Transform3D.IDENTITY   # 1.14.2: o encaixe antigo da arma na mão (medido na pose de mirar)
var giro_correcao := 0.0              # (testes) quanto a mão girou da animação até a pegada certa (rad)
const DIST_MIRA := 30.0                # 1.14.3: distância do ponto mirado (o centro da tela) para alinhar o cano
var _pref_e := Vector3.ZERO            # 1.14.2: para onde os dedos da esquerda apontam (arma branca de duas mãos)
var usar_esquerda := true              # 1.14.2: a mão esquerda vai para a arma (não, recarregando)
const GUARDA_DIR := Vector3(0.15, -0.19, 0.36)   # mão direita no quadro da câmera (x lado direito, y cima, z frente)
const GUARDA_ESQ := Vector3(-0.14, -0.20, 0.34)

var _i := {}
var _braco_e := 0.5                      # 1.14.2: comprimento do braço esquerdo (ombro -> punho)
var _mao_esq_local := Basis.IDENTITY     # eixos (palma, dedos, lado) da mão esquerda no espaço do osso dela

func preparar(sk: Skeleton3D, anim: AnimationPlayer) -> void:
	for n in ["spine_03", "neck_01", "Head", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l"]:
		_i[n] = sk.find_bone(n)
	dir_lado = signf(sk.get_bone_global_rest(_i["upperarm_r"]).origin.x)
	_braco_e = sk.get_bone_global_rest(_i["upperarm_l"]).origin.distance_to(sk.get_bone_global_rest(_i["lowerarm_l"]).origin) \
		+ sk.get_bone_global_rest(_i["lowerarm_l"]).origin.distance_to(sk.get_bone_global_rest(_i["hand_l"]).origin)
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

func _mao_esq(escala_z := 1.0) -> Transform3D:
	# 1.14.2: palma, dedos e contato de cada arma (jogador/pegada.gd): fuzil espalmada embaixo do guarda-mão, pistola do
	# lado esquerdo da empunhadura, arma branca de duas mãos fechada no cabo
	var e: Array = Pegada.mao_esq(tipo, dir_lado, fp > 0.5, ponto_antigo, _pref_e)
	var dedos: Vector3 = (e[1] as Vector3).normalized()
	var palma: Vector3 = e[0]
	palma = (palma - dedos * palma.dot(dedos)).normalized()
	var contato: Vector3 = e[2]
	contato.z *= escala_z
	# na mão esquerda o eixo X local aponta para o lado da palma (espelho da direita)
	var b := Basis(palma, dedos, palma.cross(dedos)) * _mao_esq_local.inverse()
	return Transform3D(b, contato - dedos * 0.075 - palma * 0.035)

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or ponto == null or _i.is_empty():
		return
	if modo != "fuzil":
		if guarda > 0.001:
			_guarda(sk)
		if modo == "mao":
			_corrigir(sk)
		return
	var peito := sk.get_bone_global_pose(_i["spine_03"]).origin
	var ombro := sk.get_bone_global_pose(_i["upperarm_r"]).origin
	var tb := Transform3D(baixo.basis, peito + baixo.origin)
	var giro := Basis(Vector3.RIGHT, -pitch)          # o fuzil gira em volta do ombro junto com o tronco
	var tm := Transform3D(giro * mirando.basis, ombro + giro * mirando.origin)
	var t := tb.interpolate_with(tm, smoothstep(0.0, 1.0, mira))
	t = _apontar(sk, t, smoothstep(0.0, 1.0, mira))
	if fp > 0.001 and camera != null and is_instance_valid(camera) and MiraFerro.tem(tipo):
		# 0.98: 1ª pessoa: a arma presa à câmera (quadril <-> mira de ferro)
		var w := MiraFerro.transform_arma(tipo, camera.global_transform, ads, luneta)
		var t_fp := sk.global_transform.affine_inverse() * w
		t = t.interpolate_with(t_fp, smoothstep(0.0, 1.0, fp))
	ponto.transform = t
	if mira > 0.01:
		_inclinar_cabeca(sk, mira)
	# 1.14.2: a mão direita fecha na empunhadura de cada arma (jogador/pegada.gd)
	_dois_ossos(sk, "r", t * Pegada.mao_dir(tipo), Vector3(dir_lado * 0.45, -0.55, -0.1))
	if usar_esquerda:
		_dois_ossos(sk, "l", _esq_ao_alcance(sk, t), Vector3(-dir_lado * 0.15, -0.8, 0.1))

# 1.14.2: a esquerda no ponto de apoio; se ele ficar além do braço (fuzil comprido, personagem de frente), a mão
# RECUA ao longo do guarda-mão até onde alcança (antes ficava solta no ar, antes da arma)
func _esq_ao_alcance(sk: Skeleton3D, t: Transform3D) -> Transform3D:
	var ombro := sk.get_bone_global_pose(_i["upperarm_l"]).origin
	var alc := _braco_e * 0.985
	var alvo := t * _mao_esq()
	if ombro.distance_to(alvo.origin) <= alc:
		return alvo
	var lo := 0.0
	var hi := 1.0
	for k in 10:
		var m := (lo + hi) * 0.5
		if ombro.distance_to((t * _mao_esq(m)).origin) <= alc:
			lo = m
		else:
			hi = m
	return t * _mao_esq(lo)

# 1.14.2 · ARMA NA MÃO PELA ANIMAÇÃO (arma branca, pistola em 3ª pessoa): a animação diz onde a arma vai (mão da
# animação x encaixe antigo); a arma vai para lá (o encaixe "ponto", no mesmo quadro: sem atraso) e a mão vai para a
# pegada certa nela, com o cotovelo do mesmo lado de antes. Nas armas brancas os dedos seguem o antebraço (do ombro
# para o cabo): o punho não torce. A esquerda: apoio da pistola / cabo das armas de duas mãos.
func _corrigir(sk: Skeleton3D) -> void:
	var gh := sk.get_bone_global_pose(_i["hand_r"])
	var w := gh * ponto_antigo
	w.basis = w.basis.orthonormalized()
	if Pegada.eh_fogo(tipo):
		w = _apontar(sk, w, smoothstep(0.0, 1.0, mira))
	ponto.transform = w
	var inv := w.basis.inverse()
	var ga := sk.get_bone_global_pose(_i["upperarm_r"]).origin
	var gb := sk.get_bone_global_pose(_i["lowerarm_r"]).origin
	var pref := Vector3.ZERO
	if not Pegada.eh_fogo(tipo):
		pref = inv * (w * Pegada.ponto_direita(tipo) - ga)
	var alvo_d := w * Pegada.mao_dir(tipo, ponto_antigo, pref)
	giro_correcao = gh.basis.orthonormalized().get_rotation_quaternion().angle_to(alvo_d.basis.orthonormalized().get_rotation_quaternion())
	_dois_ossos(sk, "r", alvo_d, gb - ga)
	_pref_e = Vector3.ZERO
	if usar_esquerda and (tipo == "pistola" or Pegada.duas_maos(tipo)):
		if Pegada.duas_maos(tipo):
			_pref_e = inv * (w * Pegada.ponto_esquerda(tipo) - sk.get_bone_global_pose(_i["upperarm_l"]).origin)
		_dois_ossos(sk, "l", _esq_ao_alcance(sk, w), Vector3(-dir_lado * 0.3, -0.8, -0.1))

# 1.14.3 · MIRANDO EM 3ª PESSOA o cano aponta para onde a MIRA DA TELA aponta (o tiro sai do centro da câmera): a câmera
# por cima do ombro olha um pouco para baixo e a arma ficava ~7° acima do alvo (parecia torta). Gira a arma em volta
# da empunhadura o mínimo para isso (sem girar em volta do cano).
func _apontar(sk: Skeleton3D, t: Transform3D, peso: float) -> Transform3D:
	if peso <= 0.001 or camera == null or not is_instance_valid(camera):
		return t
	var alvo := sk.global_transform.affine_inverse() * (camera.global_position - camera.global_basis.z * DIST_MIRA)
	var quer := (alvo - t.origin).normalized()
	var agora := t.basis.z.normalized()
	if quer.dot(agora) < 0.6:
		return t                        # muito diferente (virando o corpo): não força
	var q := Quaternion(agora, quer)
	return Transform3D(Basis(Quaternion.IDENTITY.slerp(q, peso)) * t.basis, t.origin)

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
