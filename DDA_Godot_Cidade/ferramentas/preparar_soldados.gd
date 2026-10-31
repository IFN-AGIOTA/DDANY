extends SceneTree
# 1.08 · SOLDADOS INFECTADOS: faz inimigos/infectados/soldado_0..2.scn a partir de 3 infectados homens que já existem
# (homem_*.scn, feitos por ferramentas/preparar_infectados.gd a partir do manequim do Quaternius, CC0): a camisa e a calça
# viram FARDA CAMUFLADA (manchas pela posição de cada vértice), o sapato vira COTURNO e ganham o CAPACETE (o mesmo do
# jogador, equipamentos/modelos/capacete.res, preso no osso da cabeça). A cabeça e as mãos ficam como estavam. A parte do
# corpo vem do osso mais forte de cada vértice (igual a ferramentas/preparar_infectados.gd), e a sujeira, os rasgos e o
# SANGUE são refeitos com as mesmas sementes de lá (homem_K usou K), então ficam nos mesmos lugares.
# Rodar, dentro da pasta DDA_Godot_Cidade:  godot --headless -s ferramentas/preparar_soldados.gd
# Esta pasta (ferramentas/) não vai para o APK.

const PASTA := "res://inimigos/infectados/"
const BASES := ["homem_1", "homem_3", "homem_6"]
const K_BASES := [1, 3, 6]                         # o k de cada um em preparar_infectados.gd (as sementes)
const CAMO := [Color(0.33, 0.36, 0.24), Color(0.22, 0.25, 0.16), Color(0.4, 0.33, 0.22), Color(0.12, 0.12, 0.1)]
const COTURNO := Color(0.1, 0.09, 0.07)
const SANGUE := Color(0.26, 0.02, 0.02)
const CAPACETE := ["Head", Vector3(0, 0.05, 0.005), Vector3(8, 0, 0), 0.85]   # igual a equipamentos/modelos_equip.gd

func _initialize() -> void:
	var camo := FastNoiseLite.new()
	camo.seed = 1080
	camo.frequency = 3.2
	for k in BASES.size():
		var kb: int = K_BASES[k]
		var ruido := FastNoiseLite.new()
		ruido.seed = kb * 31 + 7
		ruido.frequency = 2.2
		var rasgo := FastNoiseLite.new()
		rasgo.seed = kb * 17 + 2
		rasgo.frequency = 4.0
		var raiz: Node = (load(PASTA + BASES[k] + ".scn") as PackedScene).instantiate()
		var mi: MeshInstance3D = raiz.find_children("*", "MeshInstance3D", true, false)[0]
		var am: ArrayMesh = mi.mesh
		var arr := am.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var sk: Skeleton3D = raiz.find_children("*", "Skeleton3D", true, false)[0]
		var trocados := 0
		for i in v.size():
			var reg := _regiao(sk.get_bone_name(ossos[i * 4]))          # o 1º osso é o mais forte
			if reg == "cabeca" or reg == "mao":
				continue                                                  # rosto, cabelo, olhos, boca e mãos: ficam
			var p := v[i]
			if reg in ["tronco", "antebraco", "coxa", "canela"] and rasgo.get_noise_3d(p.x * 10.0, p.y * 10.0, p.z * 10.0) > 0.42:
				continue                                                  # rasgo (aparece a pele): fica
			var nova: Color
			if reg == "pe":
				nova = COTURNO
			else:
				var n := camo.get_noise_3d(p.x, p.y, p.z) * 0.5 + 0.5
				var n2 := camo.get_noise_3d(p.x + 17.0, p.y * 1.3, p.z - 9.0) * 0.5 + 0.5
				var tom := 0 if n < 0.42 else (1 if n < 0.6 else (2 if n2 < 0.55 else 3))
				nova = CAMO[tom]
			# a mesma sujeira e o mesmo sangue do infectado de antes
			nova = nova * (0.85 + 0.2 * ruido.get_noise_3d(p.x * 30.0, p.y * 30.0, p.z * 30.0))
			var sg := smoothstep(0.25, 0.5, ruido.get_noise_3d(p.x * 4.0 + 50.0, p.y * 4.0, p.z * 4.0))
			nova = nova.lerp(SANGUE, sg * 0.85)
			nova.a = 1.0
			c[i] = nova
			trocados += 1
		arr[Mesh.ARRAY_COLOR] = c
		var nm := ArrayMesh.new()
		var flags := am.surface_get_format(0) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		nm.surface_set_material(0, am.surface_get_material(0))
		mi.mesh = nm
		# o capacete no osso da cabeça
		var ba := BoneAttachment3D.new()
		ba.name = "Capacete"
		ba.bone_name = CAPACETE[0]
		sk.add_child(ba)
		ba.owner = raiz
		var hm := MeshInstance3D.new()
		hm.name = "Malha"
		hm.mesh = load("res://equipamentos/modelos/capacete.res")
		var ang: Vector3 = CAPACETE[2]
		hm.transform = Transform3D(Basis.from_euler(ang * PI / 180.0).scaled(Vector3.ONE * float(CAPACETE[3])), CAPACETE[1])
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.33, 0.22)
		mat.roughness = 0.8
		hm.material_override = mat
		ba.add_child(hm)
		hm.owner = raiz
		var pc := PackedScene.new()
		pc.pack(raiz)
		var saida := PASTA + "soldado_%d.scn" % k
		var err := ResourceSaver.save(pc, saida)
		print("SOLDADO %s <- %s · %d vértices de roupa trocados · salvo %s" % [saida, BASES[k], trocados, error_string(err)])
	quit()

# igual a ferramentas/preparar_infectados.gd
static func _regiao(osso: String) -> String:
	if osso == "Head" or osso == "neck_01": return "cabeca"
	if osso.begins_with("hand") or osso.begins_with("index") or osso.begins_with("middle") or osso.begins_with("pinky") or osso.begins_with("ring") or osso.begins_with("thumb"): return "mao"
	if osso.begins_with("lowerarm"): return "antebraco"
	if osso.begins_with("upperarm") or osso.begins_with("clavicle") or osso.begins_with("spine"): return "tronco"
	if osso == "pelvis" or osso.begins_with("thigh"): return "coxa"
	if osso.begins_with("calf"): return "canela"
	if osso.begins_with("foot") or osso.begins_with("ball"): return "pe"
	return "tronco"
