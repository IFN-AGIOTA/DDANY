extends SceneTree
# Monta o DOMINIC jogável: pega as peças feitas no Blender (ferramentas/criar_dominic.py -> dominic_pecas.glb)
# e prende no ESQUELETO do manequim da Universal Animation Library 2 (o mesmo do sobrevivente), para usar as
# mesmas animações (jogador/sobrevivente/animacoes.res).
#   - peças de roupa/pele ("Dom_Corpo"): cada vértice copia os pesos dos ossos do vértice do manequim mais perto;
#   - cabelo, tranças, óculos e boca ("Dom_Cabeca", "Dom_Lente"): presos 100% ao osso da cabeça.
# Saída: personagens/dominic/dominic.scn (mesma árvore de nós do manequim: Armature/Skeleton3D/Corpo).
# NÃO roda dentro do jogo. Como usar: no mesmo projeto temporário de ferramentas/preparar_jogador.gd (ual2.glb
# em res://m/), copie dominic_pecas.glb para res://m/, rode  godot --headless --import  e depois
#   SAIDA=<pasta personagens/dominic/ do jogo>/ godot --headless -s preparar_dominic.gd
var SAIDA := ""
const CELULA := 0.04

func _initialize():
	SAIDA = OS.get_environment("SAIDA")
	var n: Node3D = load("res://m/ual2.glb").instantiate()
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	for outro in n.find_children("*", "MeshInstance3D", true, false):
		if outro != mi:
			outro.get_parent().remove_child(outro)
			outro.free()
	# ---- manequim: posições e pesos (4 maiores) de cada vértice
	var V0 := PackedVector3Array()
	var B0 := PackedInt32Array()
	var W0 := PackedFloat32Array()
	var m: Mesh = mi.mesh
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var nb := 8 if (m.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 4
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		for vi in vs.size():
			var par := []
			for j in nb:
				par.append([ws[vi * nb + j], bs[vi * nb + j]])
			par.sort_custom(func(x, y): return x[0] > y[0])
			var soma := 0.0
			for j in 4: soma += par[j][0]
			for j in 4:
				B0.append(par[j][1])
				W0.append(par[j][0] / maxf(soma, 0.0001))
			V0.append(vs[vi])
	var grade := {}
	for i in V0.size():
		var k := Vector3i((V0[i] / CELULA).floor())
		if not grade.has(k):
			grade[k] = PackedInt32Array()
		grade[k].append(i)
	# índice do osso da cabeça dentro do "skin" do manequim
	var cabeca := -1
	for b in mi.skin.get_bind_count():
		var nome := String(mi.skin.get_bind_name(b))
		if nome == "":
			nome = sk.get_bone_name(mi.skin.get_bind_bone(b))
		if nome == "Head":
			cabeca = b
	print("bind da cabeça: ", cabeca)
	# ---- peças do Blender
	var pecas: Node3D = load("res://m/dominic_pecas.glb").instantiate()
	root.add_child(pecas)
	var sup := {"Dom_Corpo": {}, "Dom_Cabeca": {}, "Dom_Lente": {}}
	for nome in sup:
		sup[nome] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array()}
	var dist_max := 0.0
	var dist_maos := 0.0
	for pm in pecas.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var no: Node = pm
		while no != pecas and no is Node3D:
			t = (no as Node3D).transform * t
			no = no.get_parent()
		var mm: Mesh = pm.mesh
		for s in mm.get_surface_count():
			var mat = mm.surface_get_material(s)
			var mnome: String = mat.resource_name if mat != null else "Dom_Corpo"
			if not sup.has(mnome):
				mnome = "Dom_Corpo"
			var d: Dictionary = sup[mnome]
			var a: Array = mm.surface_get_arrays(s)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var cs = a[Mesh.ARRAY_COLOR]
			var base: int = d["v"].size()
			for vi in vs.size():
				var p := t * vs[vi]
				d["v"].append(p)
				d["n"].append((t.basis * ns[vi]).normalized())
				d["c"].append(cs[vi] if cs != null else Color.WHITE)
				if mnome != "Dom_Corpo":
					for j in 4:
						d["b"].append(cabeca if j == 0 else 0)
						d["w"].append(1.0 if j == 0 else 0.0)
					continue
				var perto := _mais_perto(p, V0, grade)
				var dd := p.distance_to(V0[perto])
				dist_max = maxf(dist_max, dd)
				if pm.name.begins_with("Maos"):
					dist_maos = maxf(dist_maos, dd)
				for j in 4:
					d["b"].append(B0[perto * 4 + j])
					d["w"].append(W0[perto * 4 + j])
			for idx in a[Mesh.ARRAY_INDEX]:
				d["i"].append(idx + base)
	print("distância máxima até o manequim: ", dist_max, " · mãos (devia ser ~0): ", dist_maos)
	# ---- malha final
	var nova := ArrayMesh.new()
	var contorno := ShaderMaterial.new()
	contorno.shader = Shader.new()
	contorno.shader.code = CONTORNO
	for nome in ["Dom_Corpo", "Dom_Cabeca", "Dom_Lente"]:
		var d: Dictionary = sup[nome]
		if d["v"].is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = d["v"]
		arr[Mesh.ARRAY_NORMAL] = d["n"]
		arr[Mesh.ARRAY_COLOR] = d["c"]
		arr[Mesh.ARRAY_BONES] = d["b"]
		arr[Mesh.ARRAY_WEIGHTS] = d["w"]
		arr[Mesh.ARRAY_INDEX] = d["i"]
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := StandardMaterial3D.new()
		mat.resource_name = nome
		if nome == "Dom_Lente":
			mat.albedo_color = Color(0.03, 0.035, 0.04)
			mat.metallic = 0.7
			mat.roughness = 0.12
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		else:
			mat.vertex_color_use_as_albedo = true
			mat.vertex_color_is_srgb = true          # as cores do criar_dominic.py foram escolhidas "de olho" (sRGB)
			mat.roughness = 0.82
			if nome == "Dom_Corpo":
				mat.next_pass = contorno
			else:
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		nova.surface_set_material(nova.get_surface_count() - 1, mat)
		print(nome, ": ", d["v"].size(), " vértices, ", d["i"].size() / 3, " triângulos")
	nova.resource_name = "dominic"
	mi.mesh = nova
	mi.skin = mi.skin.duplicate(true) if mi.skin else null
	mi.name = "Corpo"
	for c in n.find_children("*", "", true, false):
		c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	print("dominic -> ", ResourceSaver.save(ps, SAIDA + "dominic.scn"))
	pecas.queue_free()
	n.free()
	quit()

# contorno escuro fino (o traço da ilustração): a malha é desenhada de novo, um pouco "inflada" e do avesso
const CONTORNO := """
shader_type spatial;
render_mode unshaded, cull_front;
uniform float grossura = 0.003;
void vertex() { VERTEX += NORMAL * grossura; }
void fragment() { ALBEDO = vec3(0.015, 0.015, 0.02); }
"""

func _mais_perto(p: Vector3, V0: PackedVector3Array, grade: Dictionary) -> int:
	var k := Vector3i((p / CELULA).floor())
	var melhor := -1
	var md := 1e9
	for raio in [1, 2, 4, 8]:
		for x in range(-raio, raio + 1):
			for y in range(-raio, raio + 1):
				for z in range(-raio, raio + 1):
					if raio > 1 and absi(x) < raio and absi(y) < raio and absi(z) < raio:
						continue
					var lst = grade.get(k + Vector3i(x, y, z))
					if lst == null:
						continue
					for i in lst:
						var d := p.distance_squared_to(V0[i])
						if d < md:
							md = d
							melhor = i
		if melhor >= 0:
			return melhor
	return 0
