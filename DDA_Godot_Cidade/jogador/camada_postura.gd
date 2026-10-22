extends SkeletonModifier3D
# CAMADA DE POSTURA (0.59): COMO o personagem segura a arma que está na mão (pistola baixa nas duas mãos, faca
# pronta, taco/machado/lança nas duas mãos), só nos BRAÇOS, por cima de qualquer caminhada, parado ou agachado.
# As posturas (porte_pistola, porte_branca, porte_2m) estão em jogador/sobrevivente/animacoes.res, geradas por
# ferramentas/gerar_portes.gd. Quem escolhe a postura e liga/desliga é o jogador/animador_modelo.gd (postura()):
# some ao mirar, atirar, recarregar, golpear, correr de verdade ou tocar uma ação.
# Roda depois do AnimationPlayer e ANTES da camada de ação e do IK do fuzil. Fuzis não usam (o IK cuida deles).
# Mexa AQUI para: quais ossos cada postura usa e a velocidade de entrar/sair.

const BRACO_D := ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
const BRACO_E := ["clavicle_l", "upperarm_l", "lowerarm_l", "hand_l"]
const DEDOS := ["index", "middle", "pinky", "ring", "thumb"]
const SO_DIREITA := ["porte_branca"]       # a mão esquerda fica livre (balança andando)
const ENTRA := 6.0                         # velocidade da mistura (por segundo)

var _sk: Skeleton3D
var _ap: AnimationPlayer
var _nome := ""
var _anim: Animation = null
var _faixas := {}                          # osso -> trilha de rotação
var _t := 0.0
var peso := 0.0
var alvo := 0.0

func preparar(sk: Skeleton3D, ap: AnimationPlayer) -> void:
	_sk = sk
	_ap = ap
	active = false

# nome da postura ("" = nenhuma) e se ela deve aparecer agora (sai suave quando ligado = false)
func usar(nome: String, ligado: bool) -> void:
	var valido := nome != "" and _ap != null and _ap.has_animation(nome)
	if not valido:
		alvo = 0.0
	elif nome != _nome:
		if peso > 0.05 and _anim != null:
			alvo = 0.0                     # troca de arma: primeiro sai a postura antiga
		else:
			_trocar(nome)
			alvo = 1.0 if ligado else 0.0
	else:
		alvo = 1.0 if ligado else 0.0
	active = peso > 0.001 or alvo > 0.0

func _trocar(nome: String) -> void:
	_nome = nome
	_anim = _ap.get_animation(nome)
	_faixas.clear()
	var ossos: Array = BRACO_D.duplicate()
	if not (nome in SO_DIREITA):
		ossos.append_array(BRACO_E)
	for i in _sk.get_bone_count():
		var o := _sk.get_bone_name(i)
		var usa := o in ossos
		for d in DEDOS:
			if o.begins_with(d) and (o.ends_with("_r") or not (nome in SO_DIREITA)):
				usa = true
		if not usa:
			continue
		var idx := _anim.find_track(NodePath("Armature/Skeleton3D:" + o), Animation.TYPE_ROTATION_3D)
		if idx >= 0:
			_faixas[i] = idx

func _process_modification() -> void:
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	peso = move_toward(peso, alvo, dt * ENTRA)
	if _anim == null or peso <= 0.001:
		return
	_t = fmod(_t + dt, maxf(_anim.length, 0.01))
	var w := smoothstep(0.0, 1.0, peso)
	for b in _faixas:
		var q: Quaternion = _anim.rotation_track_interpolate(_faixas[b], _t)
		_sk.set_bone_pose_rotation(b, _sk.get_bone_pose_rotation(b).slerp(q, w))
