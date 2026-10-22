extends SkeletonModifier3D
# CAMADA DE POSTURA (0.59): COMO o personagem segura a arma que está na mão (pistola baixa nas duas mãos, faca
# pronta, taco/machado/lança nas duas mãos) e, com a pistola, MIRANDO enquanto anda (0.60) — só nos BRAÇOS, por
# cima de qualquer caminhada, parado ou agachado.
# As posturas (porte_pistola, porte_branca, porte_2m, mira_pistola) estão em jogador/sobrevivente/animacoes.res,
# geradas por ferramentas/gerar_portes.gd. Quem escolhe a postura e liga/desliga é o jogador/animador_modelo.gd
# (_atualizar_postura): trocar de postura (porte -> mira) mistura uma na outra; sem postura os braços voltam à
# animação de baixo. Roda depois do AnimationPlayer e ANTES da camada de ação e do IK do fuzil.
# Mexa AQUI para: quais ossos cada postura usa e a velocidade de entrar/sair.

const BRACO_D := ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
const BRACO_E := ["clavicle_l", "upperarm_l", "lowerarm_l", "hand_l"]
const DEDOS := ["index", "middle", "pinky", "ring", "thumb"]
const SO_DIREITA := ["porte_branca"]       # a mão esquerda fica livre (balança andando)
const ENTRA := 6.0                         # velocidade da mistura (por segundo)
# posturas de MIRA: os braços ficam na direção do CORPO TODO (espaço do esqueleto), não do peito; assim a arma
# continua apontando para a frente com o tronco curvado (agachado) ou balançando (andando)
const NO_MUNDO := ["mira_pistola"]
const CORRENTE := ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l"]

var _sk: Skeleton3D
var _ap: AnimationPlayer
var _camadas: Array = []                   # [{nome, anim, faixas, peso}] · a última é a atual
var _t := 0.0
var _quer := ""                            # postura pedida agora ("" = nenhuma)

func preparar(sk: Skeleton3D, ap: AnimationPlayer) -> void:
	_sk = sk
	_ap = ap
	active = false

# postura pedida ("" ou ligado = false: nenhuma; os braços voltam suave para a animação de baixo)
func usar(nome: String, ligado: bool) -> void:
	var quer := nome if ligado and nome != "" and _ap != null and _ap.has_animation(nome) else ""
	var atual: String = _camadas.back()["nome"] if not _camadas.is_empty() else ""
	if quer != "" and quer != atual:
		_camadas.append(_nova(quer))
	active = not _camadas.is_empty()
	_quer = quer

func peso() -> float:
	var p := 0.0
	for c in _camadas:
		p = maxf(p, float(c["peso"]))
	return p

func _nova(nome: String) -> Dictionary:
	var anim := _ap.get_animation(nome)
	var faixas := {}
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
		var idx := anim.find_track(NodePath("Armature/Skeleton3D:" + o), Animation.TYPE_ROTATION_3D)
		if idx >= 0:
			faixas[i] = idx
	return {"nome": nome, "anim": anim, "faixas": faixas, "peso": 0.0}

func _process_modification() -> void:
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	_t += dt
	# a atual sobe (se pedida); as outras descem e saem da lista
	for k in range(_camadas.size() - 1, -1, -1):
		var c: Dictionary = _camadas[k]
		var alvo := 1.0 if (k == _camadas.size() - 1 and c["nome"] == _quer) else 0.0
		c["peso"] = move_toward(float(c["peso"]), alvo, dt * ENTRA)
		if float(c["peso"]) <= 0.0 and alvo == 0.0:
			_camadas.remove_at(k)
	if _camadas.is_empty():
		active = false
		return
	# aplica da mais antiga para a atual: cada uma mistura por cima do resultado da anterior
	for c in _camadas:
		var a: Animation = c["anim"]
		var w := smoothstep(0.0, 1.0, float(c["peso"]))
		var tt := fmod(_t, maxf(a.length, 0.01))
		var no_mundo: bool = c["nome"] in NO_MUNDO
		var cache := {}
		for b in c["faixas"]:
			var q: Quaternion = a.rotation_track_interpolate(c["faixas"][b], tt)
			if no_mundo and _sk.get_bone_name(b) in CORRENTE:
				# rotação no esqueleto que o osso tem na postura -> local em relação ao pai como ele está AGORA
				var pai := _sk.get_bone_parent(b)
				var g_pai := _sk.get_bone_global_pose(pai).basis.orthonormalized()
				var g_quer := _global_na_postura(a, pai, tt, cache) * Basis(q)
				q = (g_pai.inverse() * g_quer).get_rotation_quaternion()
			_sk.set_bone_pose_rotation(b, _sk.get_bone_pose_rotation(b).slerp(q, w))

# rotação do osso no espaço do esqueleto, na postura (cadeia de rotações locais da animação, do osso raiz até ele)
func _global_na_postura(a: Animation, b: int, tt: float, cache: Dictionary) -> Basis:
	if b < 0:
		return Basis.IDENTITY
	if cache.has(b):
		return cache[b]
	var i := a.find_track(NodePath("Armature/Skeleton3D:" + _sk.get_bone_name(b)), Animation.TYPE_ROTATION_3D)
	var q := a.rotation_track_interpolate(i, tt) if i >= 0 else _sk.get_bone_rest(b).basis.get_rotation_quaternion()
	var g := _global_na_postura(a, _sk.get_bone_parent(b), tt, cache) * Basis(q)
	cache[b] = g
	return g
