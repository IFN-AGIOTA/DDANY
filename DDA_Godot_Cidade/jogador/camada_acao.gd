extends SkeletonModifier3D
# CAMADA DE AÇÃO (parte de CIMA do corpo): toca uma animação só no tronco, cabeça e braços POR CIMA da animação
# das pernas. Assim dá para recarregar, golpear, comer ou levar um golpe ANDANDO, sem as pernas pararem.
# Roda depois do AnimationPlayer e antes do IK do fuzil (jogador/ik_fuzil.gd). Quem manda tocar é
# jogador/animador_modelo.gd (acao()). Mexa AQUI para: quais ossos são "parte de cima" e o tempo de entrada/saída.

const OSSOS_CIMA := ["spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
	"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
const DEDOS := ["index", "middle", "pinky", "ring", "thumb"]
const ENTRA := 0.12                    # segundos para a ação entrar/sair (mistura)

var anim: Animation = null
var t := 0.0
var vel := 1.0
var duracao := 0.0
var _faixas := {}                      # osso -> índice da trilha de rotação
var _sk: Skeleton3D

func preparar(sk: Skeleton3D) -> void:
	_sk = sk
	active = false

func tocar(a: Animation, velocidade := 1.0) -> void:
	anim = a
	t = 0.0
	vel = velocidade
	duracao = a.length / maxf(velocidade, 0.05)
	_faixas.clear()
	for i in _sk.get_bone_count():
		var nome := _sk.get_bone_name(i)
		var cima := nome in OSSOS_CIMA
		for d in DEDOS:
			if nome.begins_with(d):
				cima = true
		if not cima:
			continue
		var idx := a.find_track(NodePath("Armature/Skeleton3D:" + nome), Animation.TYPE_ROTATION_3D)
		if idx >= 0:
			_faixas[i] = idx
	active = true

func parar() -> void:
	active = false
	anim = null

func tocando() -> bool:
	return active and anim != null

func _process_modification() -> void:
	if anim == null:
		active = false
		return
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	t += dt * vel
	var tr := t / maxf(vel, 0.05)
	if t >= anim.length:
		parar()
		return
	# entra e sai suave
	var peso := clampf(minf(tr / ENTRA, (duracao - tr) / ENTRA), 0.0, 1.0)
	for b in _faixas:
		var q: Quaternion = anim.rotation_track_interpolate(_faixas[b], t)
		var atual := _sk.get_bone_pose_rotation(b)
		_sk.set_bone_pose_rotation(b, atual.slerp(q, peso))
