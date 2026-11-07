extends SceneTree
# Corpo do SOBREVIVENTE (jogador no modo livre): manequim masculino da Universal Animation Library 2 (Quaternius,
# CC0), SEM equipamento. Cada vértice guarda a PARTE DO CORPO em COLOR.r (região/15) e uma variação em COLOR.g;
# o shader do jogo pinta cada região conforme a roupa vestida (jogador/modelo_sobrevivente.gd).
# Animações: UAL1 versão Unreal (parado, andar, correr, pular, mirar, atirar, morrer, agachado...).
# NÃO roda dentro do jogo. Como usar: igual a ferramentas/preparar_infectados.gd (mesmo projeto temporário
# com ual2.glb e ual1ue.fbx em res://m/), rodando com SAIDA=<pasta jogador/sobrevivente/ do jogo>/
var SAIDA := ""
# regiões: 0 rosto/pele da cabeça · 1 cabelo (topo) · 2 pescoço · 3 tronco · 4 braço · 5 antebraço · 6 mão
#          7 quadril · 8 coxa · 9 canela · 10 pé · 11 olhos
const ANIMS1 := {"Rig|Idle": "parado", "Rig|Walk": "andar", "Rig|Sprint": "correr", "Rig|Jog_Fwd": "trote",
	"Rig|Jump_Start": "pular", "Rig|Jump": "cair", "Rig|Jump_Land": "aterrissar", "Rig|Pistol_Aim_Neutral": "mirar",
	"Rig|Pistol_Shoot": "atirar", "Rig|Pistol_Idle": "parado_arma", "Rig|Death01": "morrer", "Rig|Crouch_Idle": "agachado",
	"Rig|Crouch_Fwd": "andar_agachado", "Rig|Punch_Jab": "soco", "Rig|Hit_Chest": "golpe", "Rig|Roll": "rolar",
	"Rig|Interact": "interagir", "Rig|PickUp_Table": "pegar"}
const LOOP := ["parado", "andar", "correr", "trote", "cair", "mirar", "parado_arma", "agachado", "andar_agachado"]

func _initialize():
	SAIDA = OS.get_environment("SAIDA")
	_anims()
	_corpo()
	quit()

func _anims() -> void:
	var lib := AnimationLibrary.new()
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
		a.loop_mode = Animation.LOOP_LINEAR if ANIMS1[nome] in LOOP else Animation.LOOP_NONE
		lib.add_animation(ANIMS1[nome], a)
	print("anims: ", ResourceSaver.save(lib, SAIDA + "animacoes.res"), " ", lib.get_animation_list())

func _regiao(osso: String) -> int:
	if osso == "Head": return 0
	if osso == "neck_01": return 2
	if osso.begins_with("hand") or osso.begins_with("index") or osso.begins_with("middle") or osso.begins_with("pinky") or osso.begins_with("ring") or osso.begins_with("thumb"): return 6
	if osso.begins_with("lowerarm"): return 5
	if osso.begins_with("upperarm"): return 4
	if osso.begins_with("clavicle") or osso.begins_with("spine"): return 3
	if osso == "pelvis": return 7
	if osso.begins_with("thigh"): return 8
	if osso.begins_with("calf"): return 9
	if osso.begins_with("foot") or osso.begins_with("ball"): return 10
	return 3

func _corpo() -> void:
	var n: Node3D = load("res://m/ual2.glb").instantiate()
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var ph := sk.get_bone_global_rest(sk.find_bone("Head")).origin
	var frente := Vector3(0, 0, 1)
	var ruido := FastNoiseLite.new()
	ruido.frequency = 3.0
	var m: Mesh = mi.mesh
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var C := PackedColorArray()
	var B := PackedInt32Array()
	var W := PackedFloat32Array()
	var I := PackedInt32Array()
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var nb := 8 if (m.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 4
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var base := V.size()
		for vi in vs.size():
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
			if reg == 0:
				var d := p - ph
				var nf := d.dot(frente)
				if d.y > 0.175 or (d.y > 0.14 and nf < 0.02) or (nf < -0.04 and d.y > 0.07):
					reg = 1
				var lado := frente.cross(Vector3.UP)
				for sx in [-1.0, 1.0]:
					if p.distance_to(ph + frente * 0.09 + Vector3.UP * 0.105 + lado * sx * 0.032) < 0.016:
						reg = 11
			C.append(Color(reg / 15.0, 0.5 + 0.5 * ruido.get_noise_3d(p.x * 20.0, p.y * 20.0, p.z * 20.0), 0.0, 1.0))
		V.append_array(vs)
		N.append_array(a[Mesh.ARRAY_NORMAL])
		for idx in a[Mesh.ARRAY_INDEX]:
			I.append(idx + base)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V
	arr[Mesh.ARRAY_NORMAL] = N
	arr[Mesh.ARRAY_COLOR] = C
	arr[Mesh.ARRAY_BONES] = B
	arr[Mesh.ARRAY_WEIGHTS] = W
	arr[Mesh.ARRAY_INDEX] = I
	var nova := ArrayMesh.new()
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	nova.resource_name = "sobrevivente"
	mi.mesh = nova
	mi.skin = mi.skin.duplicate(true) if mi.skin else null
	mi.name = "Corpo"
	for c in n.find_children("*", "", true, false):
		c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	print("corpo -> ", ResourceSaver.save(ps, SAIDA + "corpo.scn"), " verts ", V.size(), " tris ", I.size() / 3)
	n.free()
