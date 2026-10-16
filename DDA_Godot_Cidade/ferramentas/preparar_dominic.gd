extends SceneTree
# RIG DO DOMINIC: prende o modelo feito no Blender (ferramentas/dominic/modelar_dominic.py -> exportar_dominic.py,
# em pose "A", como a referência) ao ESQUELETO DO JOGO (manequim da Universal Animation Library 2, em pose T),
# sem mudar o esqueleto, para usar TODAS as animações de jogador/sobrevivente/animacoes.res.
#   1) põe os braços do esqueleto na pose A do Dominic (direção de cada braço medida no modelo);
#   2) "veste" o manequim nessa pose e, para cada vértice do Dominic, copia os pesos dos ossos do vértice do
#      manequim mais perto (cabeça, óculos e tranças ficam 100% no osso da cabeça);
#   3) cria um Skin novo cujo "bind" é a pose A (o esqueleto continua com o repouso em T e as animações iguais).
# Saída: personagens/dominic/dominic.scn (mesma árvore do manequim: Armature/Skeleton3D/Corpo).
# NÃO roda dentro do jogo. Como usar: projeto temporário com res://m/ual2.glb e res://m/dominic_v2.glb,
#   godot --headless --import ; SAIDA=<pasta personagens/dominic/ do jogo>/ godot --headless -s preparar_dominic.gd
var SAIDA := ""
const CELULA := 0.04
const RIGIDAS := ["oculos", "trancas"]           # peças inteiras presas à cabeça

func _initialize():
	SAIDA = OS.get_environment("SAIDA")
	_rodar.call_deferred()

func _rodar() -> void:
	var n: Node3D = load("res://m/ual2.glb").instantiate()
	root.add_child(n)
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = null
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if m.skin != null and mi == null:
			mi = m
		elif m != mi:
			m.get_parent().remove_child(m)
			m.free()
	# ---- peças do Dominic (espaço da cena = espaço do esqueleto; os dois olham para +Z)
	var pecas: Node3D = load("res://m/dominic_v2.glb").instantiate()
	root.add_child(pecas)
	var partes := {}
	for pm in pecas.find_children("*", "MeshInstance3D", true, false):
		var nome: String = pm.get_parent().name if String(pm.name).begins_with("Mesh") else pm.name
		partes[String(pm.name)] = pm
	# ---- 1) pose A: direção dos braços do Dominic
	for lado in ["l", "r"]:
		var nome_braco := "braco_e" if lado == "l" else "braco_d"
		var pm: MeshInstance3D = _achar(partes, nome_braco)
		var pts := _pontos(pm, pecas)
		var sinal := 1.0 if lado == "l" else -1.0
		# eixo do braço: do ponto mais perto do corpo ao mais longe
		var perto := Vector3.ZERO
		var longe := Vector3.ZERO
		var np := 0
		var nl := 0
		var xs: Array = pts.map(func(p): return absf(p.x))
		xs.sort()
		var x_min: float = xs[0]
		var x_max: float = xs[xs.size() - 1]
		for p in pts:
			var f: float = (absf(p.x) - x_min) / maxf(x_max - x_min, 0.001)
			if f < 0.15:
				perto += p; np += 1
			elif f > 0.85:
				longe += p; nl += 1
		var alvo: Vector3 = (longe / nl - perto / np).normalized()
		var ub := sk.find_bone("upperarm_" + lado)
		var hb := sk.find_bone("hand_" + lado)
		var g_ub := sk.get_bone_global_rest(ub)
		var atual := (sk.get_bone_global_rest(hb).origin - g_ub.origin).normalized()
		var giro := Quaternion(atual, alvo)
		var pai := sk.get_bone_parent(ub)
		var g_pai := sk.get_bone_global_rest(pai)
		var nova_g := Basis(giro) * g_ub.basis
		sk.set_bone_pose_rotation(ub, (g_pai.basis.inverse() * nova_g).get_rotation_quaternion())
		print("braço ", lado, ": ", atual, " -> ", alvo)
	# pernas: a coxa do esqueleto aponta para a perna do Dominic (do quadril ao tornozelo)
	for lado in ["l", "r"]:
		var pm2: MeshInstance3D = _achar(partes, "perna_e" if lado == "l" else "perna_d")
		var pts2 := _pontos(pm2, pecas)
		var ys: Array = pts2.map(func(p): return p.y)
		ys.sort()
		var y0: float = ys[0]
		var y1: float = ys[ys.size() - 1]
		var cima := Vector3.ZERO
		var baixo := Vector3.ZERO
		var nc := 0
		var nb2 := 0
		for p in pts2:
			var f: float = (p.y - y0) / maxf(y1 - y0, 0.001)
			if f > 0.85:
				cima += p; nc += 1
			elif f > 0.12 and f < 0.2:
				baixo += p; nb2 += 1
		var alvo2: Vector3 = (baixo / nb2 - cima / nc).normalized()
		var tb := sk.find_bone("thigh_" + lado)
		var fb := sk.find_bone("foot_" + lado)
		var g_tb := sk.get_bone_global_rest(tb)
		var atual2 := (sk.get_bone_global_rest(fb).origin - g_tb.origin).normalized()
		var g_pai2 := sk.get_bone_global_rest(sk.get_bone_parent(tb))
		var nova2 := Basis(Quaternion(atual2, alvo2)) * g_tb.basis
		sk.set_bone_pose_rotation(tb, (g_pai2.basis.inverse() * nova2).get_rotation_quaternion())
		print("perna ", lado, ": ", atual2, " -> ", alvo2)
	sk.force_update_all_bone_transforms()
	var gp: Array = []
	for b in sk.get_bone_count():
		gp.append(sk.get_bone_global_pose(b))
	# ---- 2) manequim na pose A: posição de cada vértice e seus pesos (índices de OSSO)
	var skin: Skin = mi.skin
	var bind_osso := {}
	for i in skin.get_bind_count():
		var bn := String(skin.get_bind_name(i))
		bind_osso[i] = sk.find_bone(bn) if bn != "" else skin.get_bind_bone(i)
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
			var p := Vector3.ZERO
			for j in 4:
				var w: float = par[j][0] / maxf(soma, 0.0001)
				var ob: int = bind_osso[par[j][1]]
				B0.append(ob)
				W0.append(w)
				p += w * ((gp[ob] as Transform3D) * skin.get_bind_pose(par[j][1]) * vs[vi])
			V0.append(p)
	var grade := {}
	for i in V0.size():
		var k := Vector3i((V0[i] / CELULA).floor())
		if not grade.has(k):
			grade[k] = PackedInt32Array()
		grade[k].append(i)
	var cabeca := sk.find_bone("Head")
	var z_queixo := _queixo(partes, pecas)
	# ---- peças do Dominic com pesos
	var sup := {"Dominic": {}, "Dominic_Lente": {}}
	for k in sup:
		sup[k] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array()}
	var dmax := 0.0
	for nome in partes:
		var pm: MeshInstance3D = partes[nome]
		var t := _transf(pm, pecas)
		var rigida := false
		for r in RIGIDAS:
			if String(nome).begins_with(r):
				rigida = true
		var mm: Mesh = pm.mesh
		for s in mm.get_surface_count():
			var mat = mm.surface_get_material(s)
			var mnome: String = mat.resource_name if mat != null else "Dominic"
			if not sup.has(mnome):
				mnome = "Dominic"
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
				if rigida or mnome == "Dominic_Lente" or (String(nome).begins_with("cabeca") and p.y > z_queixo + 0.01):
					for j in 4:
						d["b"].append(cabeca if j == 0 else 0)
						d["w"].append(1.0 if j == 0 else 0.0)
					continue
				var perto := _mais_perto(p, V0, grade)
				dmax = maxf(dmax, p.distance_to(V0[perto]))
				for j in 4:
					d["b"].append(B0[perto * 4 + j])
					d["w"].append(W0[perto * 4 + j])
			for idx in a[Mesh.ARRAY_INDEX]:
				d["i"].append(idx + base)
	print("distância máxima até o manequim: ", dmax)
	# ---- 3) malha final e Skin com o bind na pose A
	var nova := ArrayMesh.new()
	for nome in ["Dominic", "Dominic_Lente"]:
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
		if nome == "Dominic_Lente":
			mat.albedo_color = Color(0.02, 0.025, 0.03)
			mat.metallic = 0.7
			mat.roughness = 0.12
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		else:
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.85
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		nova.surface_set_material(nova.get_surface_count() - 1, mat)
		print(nome, ": ", d["v"].size(), " vértices, ", d["i"].size() / 3, " triângulos")
	nova.resource_name = "dominic"
	var sk_novo := Skin.new()
	for b in sk.get_bone_count():
		sk_novo.add_bind(b, (gp[b] as Transform3D).affine_inverse())
	mi.mesh = nova
	mi.skin = sk_novo
	mi.transform = Transform3D.IDENTITY
	mi.name = "Corpo"
	sk.reset_bone_poses()
	pecas.queue_free()
	root.remove_child(n)
	for c in n.find_children("*", "", true, false):
		c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	DirAccess.make_dir_recursive_absolute(SAIDA)
	print("dominic -> ", ResourceSaver.save(ps, SAIDA + "dominic.scn"))
	n.free()
	quit()

func _achar(partes: Dictionary, nome: String) -> MeshInstance3D:
	for k in partes:
		if String(k).begins_with(nome):
			return partes[k]
	return null

func _transf(pm: Node, ate: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var no: Node = pm
	while no != ate and no is Node3D:
		t = (no as Node3D).transform * t
		no = no.get_parent()
	return t

func _pontos(pm: MeshInstance3D, ate: Node) -> Array:
	var t := _transf(pm, ate)
	var out: Array = []
	for s in pm.mesh.get_surface_count():
		for v in pm.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(t * v)
	return out

# altura do queixo: o ponto mais baixo da frente do rosto (o pescoço fica atrás)
func _queixo(partes: Dictionary, ate: Node) -> float:
	var pts := _pontos(_achar(partes, "cabeca"), ate)
	var zmax := -1e9
	for p in pts:
		zmax = maxf(zmax, p.z)
	var q := 1e9
	for p in pts:
		if p.z > zmax - 0.03 and absf(p.x) < 0.03:
			q = minf(q, p.y)
	return q

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
