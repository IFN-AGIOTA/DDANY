extends SceneTree
# Monta os INFECTADOS com o manequim da "Universal Animation Library" do Quaternius (CC0):
# manequim masculino (UAL2) e feminino (UAL2 Female Mannequin), proporção humana, malha simplificada,
# pintado por região (pele, camisa, calça, sapato, cabelo, olhos), roupa rasgada e sangue.
# Animações: UAL2 (zumbi: andar, parado, arranhar; levar golpe) + UAL1 versão Unreal (correr, morrer, tiro).
# NÃO roda dentro do jogo. Como usar (só para refazer ou mudar os infectados):
#   1. baixe as duas bibliotecas (opengameart.org/content/universal-animation-library-2 e .../universal-animation-library);
#   2. crie um projeto Godot vazio e copie para res://m/: UAL2_Standard.glb como ual2.glb,
#      Mannequin_F.glb como mf.glb e "Unreal Engine/AL_Standard.fbx" (da biblioteca 1) como ual1ue.fbx;
#   3. copie este arquivo para esse projeto e rode: godot --headless --import
#      e depois  SAIDA=<pasta inimigos/infectados/ do jogo>/ godot --headless -s preparar_infectados.gd
var SAIDA := ""
const ANIMS2 := {"Zombie_Walk_Fwd": "andar", "Zombie_Idle": "parado", "Zombie_Scratch": "ataque", "Hit_Knockback": "golpe_forte"}
const ANIMS1 := {"Rig|Sprint": "correr", "Rig|Death01": "morte", "Rig|Hit_Chest": "golpe", "Rig|Jog_Fwd": "trote"}
const PELES := [Color(0.50, 0.55, 0.45), Color(0.58, 0.58, 0.50), Color(0.44, 0.48, 0.42), Color(0.40, 0.37, 0.33), Color(0.55, 0.50, 0.45), Color(0.33, 0.30, 0.26)]
const CAMISAS := [Color(0.42, 0.40, 0.36), Color(0.28, 0.32, 0.40), Color(0.48, 0.22, 0.20), Color(0.62, 0.60, 0.55), Color(0.22, 0.28, 0.22), Color(0.36, 0.30, 0.40), Color(0.15, 0.15, 0.17), Color(0.55, 0.45, 0.28), Color(0.70, 0.70, 0.72), Color(0.20, 0.30, 0.45)]
const CALCAS := [Color(0.20, 0.25, 0.36), Color(0.25, 0.27, 0.30), Color(0.33, 0.29, 0.22), Color(0.15, 0.15, 0.16), Color(0.38, 0.36, 0.30), Color(0.28, 0.30, 0.24)]
const CABELOS := [Color(0.08, 0.06, 0.05), Color(0.22, 0.14, 0.08), Color(0.35, 0.28, 0.18), Color(0.45, 0.43, 0.40), Color(0.12, 0.10, 0.08)]
const SAPATOS := [Color(0.1, 0.09, 0.08), Color(0.3, 0.22, 0.15), Color(0.55, 0.55, 0.55)]
const SANGUE := Color(0.26, 0.02, 0.02)
const N_HOMENS := 8
const N_MULHERES := 4

func _initialize():
	SAIDA = OS.get_environment("SAIDA")
	_anims()
	var k := 0
	for i in N_HOMENS:
		_variante("res://m/ual2.glb", "homem_%d" % i, k)
		k += 1
	for i in N_MULHERES:
		_variante("res://m/mf.glb", "mulher_%d" % i, k)
		k += 1
	quit()

func _anims() -> void:
	var lib := AnimationLibrary.new()
	var a2: AnimationPlayer = load("res://m/ual2.glb").instantiate().find_children("*", "AnimationPlayer", true, false)[0]
	for nome in ANIMS2:
		var a: Animation = a2.get_animation(nome).duplicate(true)
		a.loop_mode = Animation.LOOP_LINEAR if ANIMS2[nome] in ["andar", "parado"] else Animation.LOOP_NONE
		lib.add_animation(ANIMS2[nome], a)
	var a1: AnimationPlayer = load("res://m/ual1ue.fbx").instantiate().find_children("*", "AnimationPlayer", true, false)[0]
	var rx := Quaternion(Vector3.RIGHT, -PI / 2.0)
	for nome in ANIMS1:
		var a: Animation = a1.get_animation(nome).duplicate(true)
		for t in a.get_track_count():
			var p := String(a.track_get_path(t)).replace("Rig/Skeleton3D", "Armature/Skeleton3D")
			a.track_set_path(t, NodePath(p))
			var osso := p.get_slice(":", 1)
			for kk in a.track_get_key_count(t):
				var v = a.track_get_key_value(t, kk)
				if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					v = v * 100.0
					if osso == "root":
						v = rx * v
					a.track_set_key_value(t, kk, v)
				elif a.track_get_type(t) == Animation.TYPE_ROTATION_3D and osso == "root":
					a.track_set_key_value(t, kk, rx * v)
		a.loop_mode = Animation.LOOP_LINEAR if ANIMS1[nome] in ["correr", "trote"] else Animation.LOOP_NONE
		lib.add_animation(ANIMS1[nome], a)
	print("anims: ", ResourceSaver.save(lib, SAIDA + "animacoes.res"), " ", lib.get_animation_list())

func _regiao(osso: String) -> String:
	if osso == "Head" or osso == "neck_01": return "cabeca"
	if osso.begins_with("hand") or osso.begins_with("index") or osso.begins_with("middle") or osso.begins_with("pinky") or osso.begins_with("ring") or osso.begins_with("thumb"): return "mao"
	if osso.begins_with("lowerarm"): return "antebraco"
	if osso.begins_with("upperarm") or osso.begins_with("clavicle") or osso.begins_with("spine"): return "tronco"
	if osso == "pelvis" or osso.begins_with("thigh"): return "coxa"
	if osso.begins_with("calf"): return "canela"
	if osso.begins_with("foot") or osso.begins_with("ball"): return "pe"
	return "tronco"

func _variante(arquivo: String, nome: String, k: int) -> void:
	var n: Node3D = load(arquivo).instantiate()
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var r := RandomNumberGenerator.new()
	r.seed = k * 7919 + 3
	var pele: Color = PELES[r.randi() % PELES.size()]
	var camisa: Color = CAMISAS[r.randi() % CAMISAS.size()] * r.randf_range(0.85, 1.1)
	var calca: Color = CALCAS[r.randi() % CALCAS.size()] * r.randf_range(0.85, 1.1)
	var sapato: Color = SAPATOS[r.randi() % SAPATOS.size()]
	var cabelo: Color = CABELOS[r.randi() % CABELOS.size()]
	var careca := r.randf() < (0.35 if k < N_HOMENS else 0.0)
	var cab_longo := k >= N_HOMENS
	var manga_curta := r.randf() < 0.45
	var bermuda := r.randf() < 0.2
	var ruido := FastNoiseLite.new()
	ruido.seed = k * 31 + 7
	ruido.frequency = 2.2
	var rasgo := FastNoiseLite.new()
	rasgo.seed = k * 17 + 2
	rasgo.frequency = 4.0
	# referências no espaço da malha: cabeça e para onde ele olha (pé -> dedos)
	var ph := sk.get_bone_global_rest(sk.find_bone("Head")).origin
	var frente := (sk.get_bone_global_rest(sk.find_bone("ball_l")).origin - sk.get_bone_global_rest(sk.find_bone("foot_l")).origin)
	frente.y = 0.0
	frente = frente.normalized()
	var m: Mesh = mi.mesh
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var C := PackedColorArray()
	var B := PackedInt32Array()
	var W := PackedFloat32Array()
	var I := PackedInt32Array()
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var oito: bool = (m.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
		var nb := 8 if oito else 4
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var base := V.size()
		for vi in vs.size():
			# 4 ossos mais fortes
			var par := []
			for j in nb:
				par.append([ws[vi * nb + j], bs[vi * nb + j]])
			par.sort_custom(func(x, y): return x[0] > y[0])
			var soma := 0.0
			for j in 4: soma += par[j][0]
			for j in 4:
				B.append(par[j][1])
				W.append(par[j][0] / maxf(soma, 0.0001))
			var p: Vector3 = vs[vi]
			var reg := _regiao(sk.get_bone_name(par[0][1]))
			var cor := pele
			var rr := rasgo.get_noise_3d(p.x * 10.0, p.y * 10.0, p.z * 10.0)
			match reg:
				"cabeca":
					var d := p - ph
					var na_frente := d.dot(frente)
					# cabelo: em cima e atrás da cabeça
					if not careca and (d.y > 0.12 - (0.06 if cab_longo else 0.0) and na_frente < 0.05 or (d.y > 0.17)):
						cor = cabelo
					if not careca and cab_longo and na_frente < -0.02 and d.y > -0.02:
						cor = cabelo
					# olhos fundos: duas manchas escuras na frente do rosto; boca escura
					var lado := frente.cross(Vector3.UP)
					for sx in [-1.0, 1.0]:
						var olho: Vector3 = ph + frente * 0.09 + Vector3.UP * 0.105 + lado * sx * 0.032
						if p.distance_to(olho) < 0.02:
							cor = Color(0.07, 0.04, 0.03)
					if p.distance_to(ph + frente * 0.095 + Vector3.UP * 0.035) < 0.018:
						cor = Color(0.18, 0.03, 0.03)
				"mao": cor = pele
				"antebraco": cor = pele if manga_curta else camisa
				"tronco": cor = camisa
				"coxa": cor = calca
				"canela": cor = pele if bermuda else calca
				"pe": cor = sapato
			# roupa rasgada: aparece a pele
			if reg in ["tronco", "coxa", "canela", "antebraco"] and cor != pele and rr > 0.42:
				cor = pele * 0.9
			# sujeira e sangue
			cor = cor * (0.85 + 0.2 * ruido.get_noise_3d(p.x * 30.0, p.y * 30.0, p.z * 30.0))
			var sg := smoothstep(0.25, 0.5, ruido.get_noise_3d(p.x * 4.0 + 50.0, p.y * 4.0, p.z * 4.0))
			if reg == "cabeca" and (p - ph).dot(frente) > 0.05 and (p - ph).y < 0.08:
				sg = maxf(sg, 0.6 * smoothstep(-0.3, 0.3, ruido.get_noise_3d(p.x * 20.0, p.y * 20.0, 9.0)))   # boca suja de sangue
			cor = cor.lerp(SANGUE, sg * 0.85)
			cor.a = 1.0
			C.append(cor)
		V.append_array(vs)
		N.append_array(a[Mesh.ARRAY_NORMAL])
		for idx in a[Mesh.ARRAY_INDEX]:
			I.append(idx + base)
	# simplificar (menos triângulos) com o gerador de LOD da Godot e usar um nível intermediário
	var im := ImporterMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V
	arr[Mesh.ARRAY_NORMAL] = N
	arr[Mesh.ARRAY_COLOR] = C
	arr[Mesh.ARRAY_BONES] = B
	arr[Mesh.ARRAY_WEIGHTS] = W
	arr[Mesh.ARRAY_INDEX] = I
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(25.0, 60.0, [])
	var ag: Array = im.get_surface_arrays(0)
	V = ag[Mesh.ARRAY_VERTEX]
	N = ag[Mesh.ARRAY_NORMAL]
	C = ag[Mesh.ARRAY_COLOR]
	B = ag[Mesh.ARRAY_BONES]
	W = ag[Mesh.ARRAY_WEIGHTS]
	I = ag[Mesh.ARRAY_INDEX]
	var alvo := 4500 if k < N_HOMENS else 6000            # triângulos
	var melhor := I
	for lod in im.get_surface_lod_count(0):
		var li := im.get_surface_lod_indices(0, lod)
		if li.size() / 3 >= alvo:
			melhor = li
	# tira os vértices que sobraram sem uso (arquivo menor)
	var novo_idx := {}
	var V2 := PackedVector3Array()
	var N2 := PackedVector3Array()
	var C2 := PackedColorArray()
	var B2 := PackedInt32Array()
	var W2 := PackedFloat32Array()
	var I2 := PackedInt32Array()
	for idx in melhor:
		if not novo_idx.has(idx):
			novo_idx[idx] = V2.size()
			V2.append(V[idx]); N2.append(N[idx]); C2.append(C[idx])
			for j in 4:
				B2.append(B[idx * 4 + j]); W2.append(W[idx * 4 + j])
		I2.append(novo_idx[idx])
	arr[Mesh.ARRAY_VERTEX] = V2
	arr[Mesh.ARRAY_NORMAL] = N2
	arr[Mesh.ARRAY_COLOR] = C2
	arr[Mesh.ARRAY_BONES] = B2
	arr[Mesh.ARRAY_WEIGHTS] = W2
	arr[Mesh.ARRAY_INDEX] = I2
	V = V2
	var nova := ArrayMesh.new()
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	nova.resource_name = nome
	mi.mesh = nova
	mi.skin = mi.skin.duplicate(true) if mi.skin else null
	mi.name = "Corpo"
	for c in n.find_children("*", "", true, false):
		c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	print(nome, " -> ", ResourceSaver.save(ps, SAIDA + nome + ".scn"), " tris ", I.size() / 3, " -> ", melhor.size() / 3, " verts ", V.size(), " frente ", frente)
	n.free()
