extends SkeletonModifier3D
# CAMADA DOS DEDOS (1.14.2): FECHA A MÃO em volta do que ela segura. Roda por ÚLTIMO (depois das animações, das
# posturas e do IK das armas), só nos ossos dos dedos. Antes os dedos ficavam esticados e abertos (a arma parecia
# colada na mão).
# Cada falange dobra em volta do eixo "dedo x palma" (medido na pose de descanso, em que a palma olha para baixo):
# assim o dedo fecha para dentro da palma, nos dois lados e nos dois corpos (homem e mulher).
# PEGADAS (ângulos em radianos das falanges 1, 2 e 3):
#   pistola  · indicador quase reto (no gatilho), os outros três fechados na empunhadura, polegar do outro lado
#   fuzil    · igual, com o polegar dando a volta por cima do cabo (fica abaixo da linha de mira)
#   punho    · os quatro fechados no cabo (arma branca, cabo do fuzil na esquerda)
#   apoio    · meio fechados embaixo do guarda-mão (mão esquerda no fuzil)
#   apoio_pistola · a esquerda por cima dos dedos da direita
#   soco     · punho fechado (sem arma)
#   item     · em concha (lata, garrafa, remédio)
# Quem escolhe a pegada de cada mão é o jogador/modelo_sobrevivente.gd (pegada_d / pegada_e). Mexa AQUI nos ângulos.

const DEDOS := ["index", "middle", "ring", "pinky", "thumb"]
const PEGADAS := {
	"pistola": {"index": [0.22, 0.42, 0.3], "middle": [1.2, 1.4, 0.8], "ring": [1.25, 1.4, 0.8], "pinky": [1.3, 1.4, 0.8],
		"thumb": [0.65, 0.6, 0.45]},
	"fuzil": {"index": [0.22, 0.42, 0.3], "middle": [1.2, 1.4, 0.8], "ring": [1.25, 1.4, 0.8], "pinky": [1.3, 1.4, 0.8],
		"thumb": [1.15, 0.9, 0.6]},
	"punho": {"index": [1.15, 1.35, 0.8], "middle": [1.2, 1.4, 0.8], "ring": [1.25, 1.4, 0.8], "pinky": [1.3, 1.4, 0.8],
		"thumb": [0.55, 0.55, 0.4]},
	"apoio": {"index": [0.85, 0.95, 0.55], "middle": [0.95, 1.05, 0.6], "ring": [1.0, 1.05, 0.6], "pinky": [1.05, 1.05, 0.6],
		"thumb": [0.35, 0.3, 0.2]},
	"apoio_pistola": {"index": [0.95, 1.1, 0.6], "middle": [1.0, 1.15, 0.65], "ring": [1.05, 1.15, 0.65], "pinky": [1.1, 1.15, 0.65],
		"thumb": [0.15, 0.15, 0.1]},
	"soco": {"index": [1.45, 1.6, 1.1], "middle": [1.5, 1.6, 1.1], "ring": [1.5, 1.6, 1.1], "pinky": [1.55, 1.6, 1.1],
		"thumb": [0.75, 0.8, 0.6]},
	"item": {"index": [0.75, 0.9, 0.55], "middle": [0.8, 0.95, 0.6], "ring": [0.85, 0.95, 0.6], "pinky": [0.9, 0.95, 0.6],
		"thumb": [0.5, 0.4, 0.3]},
}
const VEL := 9.0                          # quão rápido a mão abre/fecha (por segundo)

var pegada_d := ""                        # mão direita ("" = como na animação)
var pegada_e := ""
var _ossos := {}                          # "r"/"l" -> [[índice, dedo, falange (0..2), eixo local, rotação de descanso]]
var _peso := {"r": 0.0, "l": 0.0}
var _atual := {"r": "", "l": ""}

func preparar(sk: Skeleton3D) -> void:
	for lado in ["r", "l"]:
		var lista: Array = []
		var mao := sk.find_bone("hand_" + lado)
		var mindinho := sk.find_bone("pinky_01_" + lado)
		for d in DEDOS:
			for k in 3:
				var i := sk.find_bone("%s_%02d_%s" % [d, k + 1, lado])
				if i < 0:
					continue
				var filho := sk.find_bone("%s_%02d_%s" % [d, k + 2, lado])
				if filho < 0:
					filho = sk.find_bone("%s_04_leaf_%s" % [d, lado])
				var g := sk.get_bone_global_rest(i)
				var f: Vector3 = ((sk.get_bone_global_rest(filho).origin if filho >= 0 else g.origin + g.basis.y) - g.origin).normalized()
				var n := Vector3.DOWN                   # na pose de descanso a palma olha para baixo
				if d == "thumb" and mindinho >= 0:
					# o polegar fecha atravessando a palma, na direção do mindinho
					var p := (sk.get_bone_global_rest(mindinho).origin - g.origin).normalized()
					n = (Vector3.DOWN * 0.6 + p).normalized()
				n = (n - f * n.dot(f)).normalized()
				var eixo := f.cross(n).normalized()      # girar em volta dele leva o dedo para a palma
				var local := (g.basis.orthonormalized().inverse() * eixo).normalized()
				lista.append([i, d, k, local, sk.get_bone_rest(i).basis.get_rotation_quaternion()])
		_ossos[lado] = lista
		if mao < 0:
			_ossos[lado] = []
	active = true

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _ossos.is_empty():
		return
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	for lado in ["r", "l"]:
		var quer: String = pegada_d if lado == "r" else pegada_e
		if quer != "" and PEGADAS.has(quer):
			if quer != _atual[lado]:
				# troca de pegada: a mão vai da pegada antiga para a nova (sem abrir no meio)
				_atual[lado] = quer
			_peso[lado] = move_toward(float(_peso[lado]), 1.0, dt * VEL)
		else:
			_peso[lado] = move_toward(float(_peso[lado]), 0.0, dt * VEL)
		var w: float = _peso[lado]
		if w <= 0.0 or _atual[lado] == "":
			continue
		var tab: Dictionary = PEGADAS[_atual[lado]]
		for o in _ossos[lado]:
			var ang: float = (tab[o[1]] as Array)[o[2]]
			var alvo: Quaternion = (o[4] as Quaternion) * Quaternion(o[3] as Vector3, ang)
			var agora := sk.get_bone_pose_rotation(o[0])
			sk.set_bone_pose_rotation(o[0], agora.slerp(alvo, w))
