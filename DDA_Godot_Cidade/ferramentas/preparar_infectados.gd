extends SceneTree
# Converte os personagens do Quaternius (CC0) em infectados: 1 malha (1 superfície, cor por vértice),
# pele de infectado, roupa suja, manchas de sangue. Salva cada um como .scn e as animações num .res.
# NÃO roda dentro do jogo. Como usar (só para refazer/adicionar modelos):
#   1. baixe o pacote (opengameart.org/content/animated-characters-pack) e crie um projeto Godot vazio
#      com os .fbx da pasta FBX em res://m/ ;
#   2. copie este arquivo para esse projeto, ajuste SAIDA para a pasta inimigos/infectados/ do jogo;
#   3. rode: godot --headless --import  e depois  godot --headless -s preparar_infectados.gd
const SAIDA := "/home/user/DDANY/DDA_Godot_Cidade/inimigos/infectados/"
const LISTA := ["Zombie_Male", "Zombie_Female", "Casual_Male", "Casual2_Male", "Casual3_Male", "Casual_Bald",
	"Casual_Female", "Casual2_Female", "Worker_Male", "Worker_Female", "Soldier_Male", "BlueSoldier_Male",
	"Doctor_Male_Young", "Doctor_Female_Old", "Suit_Male", "Chef_Male", "OldClassy_Male"]
const PELES := [Color(0.47, 0.52, 0.42), Color(0.55, 0.57, 0.48), Color(0.42, 0.47, 0.41), Color(0.52, 0.5, 0.45),
	Color(0.44, 0.5, 0.46), Color(0.38, 0.4, 0.34)]
const SANGUE := Color(0.24, 0.02, 0.02)
const ANIMS := {"Walk": "andar", "Idle": "parado", "Punch": "soco", "RecieveHit": "golpe", "Defeat": "morte"}

func _initialize():
	var ruido := FastNoiseLite.new()
	ruido.frequency = 1.6
	var k := 0
	for nome: String in LISTA:
		var n: Node3D = load("res://m/%s.fbx" % nome).instantiate()
		var mi: MeshInstance3D = n.find_child("*", true, false) as MeshInstance3D
		for c in n.find_children("*", "MeshInstance3D", true, false):
			mi = c
		var m: Mesh = mi.mesh
		var zumbi := nome.begins_with("Zombie")
		var r := RandomNumberGenerator.new()
		r.seed = k * 97 + 5
		var pele: Color = PELES[k % PELES.size()]
		ruido.seed = k * 13 + 1
		var V := PackedVector3Array()
		var N := PackedVector3Array()
		var C := PackedColorArray()
		var B := PackedInt32Array()
		var W := PackedFloat32Array()
		var I := PackedInt32Array()
		var oito := false
		for s in m.get_surface_count():
			var a: Array = m.surface_get_arrays(s)
			var fmt: int = m.surface_get_format(s)
			if fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
				oito = true
			var mat = m.surface_get_material(s)
			var nm: String = mat.resource_name if mat else ""
			var cor: Color = mat.albedo_color if mat is StandardMaterial3D else Color(0.5, 0.5, 0.5)
			var eh_pele := nm == "Skin"
			if nm == "Skin":
				cor = cor * r.randf_range(0.9, 1.1) if zumbi else pele
			elif nm == "Face" or nm == "Teeth":
				cor = Color(0.12, 0.11, 0.09)
			elif nm in ["Guts", "Brain"]:
				pass
			else:
				var l := cor.r * 0.3 + cor.g * 0.55 + cor.b * 0.15
				cor = cor.lerp(Color(l, l, l), 0.25) * 0.82          # roupa suja e desbotada
			cor.a = 1.0
			var base := V.size()
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			V.append_array(vs)
			N.append_array(a[Mesh.ARRAY_NORMAL])
			B.append_array(a[Mesh.ARRAY_BONES])
			W.append_array(a[Mesh.ARRAY_WEIGHTS])
			for v in vs:
				var p := v * 100.0
				var sangue := smoothstep(0.28, 0.45, ruido.get_noise_3d(p.x, p.y, p.z))
				if p.z < 1.0: sangue *= 0.4                       # menos nas pernas
				if eh_pele: sangue *= 0.7
				C.append(cor.lerp(SANGUE, sangue * 0.8))
			if a[Mesh.ARRAY_INDEX] != null:
				for idx in a[Mesh.ARRAY_INDEX]:
					I.append(idx + base)
			else:
				for i in vs.size():
					I.append(base + i)
		if oito:
			# 8 ossos por vértice -> os 4 mais fortes (mais leve no celular)
			var B4 := PackedInt32Array()
			var W4 := PackedFloat32Array()
			for v in V.size():
				var par := []
				for j in 8:
					par.append([W[v * 8 + j], B[v * 8 + j]])
				par.sort_custom(func(x, y): return x[0] > y[0])
				var soma := 0.0
				for j in 4: soma += par[j][0]
				for j in 4:
					B4.append(par[j][1])
					W4.append(par[j][0] / maxf(soma, 0.0001))
			B = B4
			W = W4
			oito = false
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = V
		arr[Mesh.ARRAY_NORMAL] = N
		arr[Mesh.ARRAY_COLOR] = C
		arr[Mesh.ARRAY_BONES] = B
		arr[Mesh.ARRAY_WEIGHTS] = W
		arr[Mesh.ARRAY_INDEX] = I
		var nova := ArrayMesh.new()
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if oito else 0)
		nova.resource_name = nome
		mi.mesh = nova
		mi.skin = mi.skin.duplicate(true)
		mi.name = "Corpo"
		var ap := n.find_child("AnimationPlayer", true, false)
		if k == 0:
			var lib := AnimationLibrary.new()
			for orig in ANIMS:
				var an: Animation = ap.get_animation("CharacterArmature|" + orig).duplicate(true)
				an.loop_mode = Animation.LOOP_LINEAR if orig in ["Walk", "Idle"] else Animation.LOOP_NONE
				lib.add_animation(ANIMS[orig], an)
			print("anims: ", ResourceSaver.save(lib, SAIDA + "animacoes.res"))
		ap.get_parent().remove_child(ap)
		ap.free()
		for c in n.find_children("*", "", true, false):
			c.owner = n
		var ps := PackedScene.new()
		ps.pack(n)
		var e := ResourceSaver.save(ps, SAIDA + nome.to_lower() + ".scn")
		print(nome, " -> ", e, " verts ", V.size(), " idx ", I.size(), " 8ossos ", oito)
		n.free()
		k += 1
	quit()
