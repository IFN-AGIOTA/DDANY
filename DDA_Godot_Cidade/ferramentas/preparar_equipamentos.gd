extends SceneTree
# Converte os modelos baixados (todos low poly) em peças do jogo:
#   - 1 malha por peça, cores "assadas" nos vértices (sem textura), material de cor por vértice;
#   - tamanho real (m) e direção padrão: armas com o cano/lâmina para +Z e a origem na empunhadura;
#     equipamentos com a frente para +Z (frente do corpo) e a origem na base (onde encaixa no corpo);
#   - armas de fogo: nó "Cano" na ponta, "Acc_cano" (silenciador) e "Acc_mira" (mira/luneta) escondidos.
# Saída: SAIDA_ARMAS/<id>.scn e SAIDA_EQUIP/<id>.res (malhas).
# NÃO roda dentro do jogo. Como usar (para refazer ou trocar modelos):
#   1. baixe os pacotes listados em armas/modelos/LICENCA.txt e equipamentos/modelos/LICENCA.txt;
#   2. crie um projeto Godot vazio: as armas do Ultimate Gun Pack (FBX + Accessories) em res://src/armas/ e
#      Knife, Axe_Small, Backpack (Survival Pack), taco.glb, cano.obj, survival-spear-head.obj, helmet.obj (+png),
#      bone.fbx (snapback) e backpack.obj (camping) em res://src/todos/;
#   3. godot --headless --import  e depois
#      SAIDA_ARMAS=<jogo>/armas/modelos/ SAIDA_EQUIP=<jogo>/equipamentos/modelos/ godot --headless -s preparar_equipamentos.gd
var SAIDA_ARMAS := ""
var SAIDA_EQUIP := ""

# id: [arquivo, giro (graus), comprimento (m), fração da empunhadura a partir da traseira]
const ARMAS := {
	"pistola": ["res://src/armas/Pistol_1.fbx", Vector3(0, -90, 0), 0.22, 0.2],
	"m4": ["res://src/armas/AssaultRifle2_1.fbx", Vector3(0, -90, 0), 0.86, 0.33],
	"ak": ["res://src/armas/AssaultRifle_2.fbx", Vector3(0, -90, 0), 0.88, 0.33],
	"espingarda": ["res://src/armas/Shotgun_3.fbx", Vector3(0, -90, 0), 1.05, 0.3],
	"rifle_caca": ["res://src/armas/SniperRifle_6.fbx", Vector3(0, -90, 0), 1.1, 0.3],
}
# armas brancas: lâmina/cabeça para +Z; [arquivo, giro, comprimento, fração da empunhadura, cores por altura]
const BRANCAS := {
	"faca": ["res://src/todos/Knife.fbx", Vector3(90, 0, 0), 0.3, 0.2, []],
	"machado": ["res://src/todos/Axe_Small.fbx", Vector3(90, 0, 0), 0.55, 0.12, []],
	"taco": ["res://src/todos/taco.glb", Vector3(90, 0, 0), 0.85, 0.12, []],
	"cano": ["res://src/todos/cano.obj", Vector3(90, 0, 0), 0.75, 0.15, [[1.0, Color(0.36, 0.37, 0.38)]]],
	"lanca": ["res://src/todos/survival-spear-head.obj", Vector3(90, 0, 0), 1.6, 0.35,
		[[0.86, Color(0.42, 0.29, 0.17)], [0.9, Color(0.55, 0.5, 0.42)], [1.0, Color(0.62, 0.63, 0.65)]]],
}
# acessórios: [arquivo, giro, comprimento]
const ACESSORIOS := {
	"silenciador": ["res://src/armas/Silencer_1.fbx", Vector3(0, -90, 0), 0.16],
	"mira_acog": ["res://src/armas/Scope_2.fbx", Vector3(0, -90, 0), 0.13],
	"luneta": ["res://src/armas/Scope_1.fbx", Vector3(0, -90, 0), 0.33],
}
# equipamentos: [arquivo, giro, medida (m), eixo da medida (0 x, 1 y, 2 z), cor por cima (ou null)]
const EQUIP := {
	"capacete": ["res://src/todos/helmet.obj", Vector3(0, 0, 0), 0.28, 0, null],
	"bone": ["res://src/todos/bone.fbx", Vector3(0, 0, 0), 0.25, 0, Color(0.2, 0.26, 0.45)],
	"mochila_trilha": ["res://src/todos/Backpack.fbx", Vector3(0, 180, 0), 0.62, 1, null],
	"mochila_combate": ["res://src/todos/Backpack.fbx", Vector3(0, 180, 0), 0.55, 1, "combate"],
	"mochila_escolar": ["res://src/todos/backpack.obj", Vector3(0, 180, 0), 0.42, 1, Color(0.2, 0.3, 0.55)],
}

var _mat: StandardMaterial3D

func _initialize():
	SAIDA_ARMAS = OS.get_environment("SAIDA_ARMAS")
	SAIDA_EQUIP = OS.get_environment("SAIDA_EQUIP")
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.75
	var acc := {}
	for id in ACESSORIOS:
		var d: Array = ACESSORIOS[id]
		var g := _geometria(d[0], d[1], {})
		g = _normalizar(g, d[2], 0.0, true)
		acc[id] = _malha(g)
	for id in ARMAS:
		var d: Array = ARMAS[id]
		var g := _geometria(d[0], d[1], {})
		if id == "rifle_caca":
			g = _sem_luneta(g)
		_arma_de_fogo(id, g, d[2], d[3], acc)
	for id in BRANCAS:
		var d: Array = BRANCAS[id]
		var g := _geometria(d[0], d[1], {"faixas": d[4]})
		g = _normalizar(g, d[2], d[3], false)
		var raiz := Node3D.new()
		raiz.name = "Arma_" + id
		var mi := MeshInstance3D.new()
		mi.name = "Malha"
		mi.mesh = _malha(g)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
		_salvar(raiz, SAIDA_ARMAS + id + ".scn")
	for id in ACESSORIOS:
		ResourceSaver.save(acc[id], SAIDA_EQUIP + id + ".res")
	for id in EQUIP:
		var d: Array = EQUIP[id]
		var g := _geometria(d[0], d[1], {"cor": d[4] if d[4] is Color else null, "combate": d[4] is String})
		g = _equip(g, d[2], d[3])
		var e := ResourceSaver.save(_malha(g), SAIDA_EQUIP + id + ".res")
		print(id, " -> ", e, " tris ", g["v"].size() / 3)
	quit()

# todas as malhas do arquivo, em triângulos soltos, já giradas; cor = cor do material (ou da textura no UV)
func _geometria(arquivo: String, giro: Vector3, op: Dictionary) -> Dictionary:
	var res = load(arquivo)
	var raiz: Node3D
	if res is Mesh:
		raiz = Node3D.new()
		var m := MeshInstance3D.new()
		m.mesh = res
		raiz.add_child(m)
	else:
		raiz = res.instantiate()
	root.add_child(raiz)
	var b := Basis.from_euler(giro * PI / 180.0)
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var C := PackedColorArray()
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var no: Node = mi
		while no != raiz and no is Node3D:
			t = (no as Node3D).transform * t
			no = no.get_parent()
		var m: Mesh = mi.mesh
		for s in m.get_surface_count():
			var a: Array = m.surface_get_arrays(s)
			var mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = m.surface_get_material(s)
			var cor := Color(0.6, 0.6, 0.6)
			var img: Image = null
			if mat is StandardMaterial3D:
				cor = mat.albedo_color
				if mat.albedo_texture != null:
					img = mat.albedo_texture.get_image()
					if img != null and img.is_compressed():
						img.decompress()
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var ns = a[Mesh.ARRAY_NORMAL]
			var uvs = a[Mesh.ARRAY_TEX_UV]
			var idx = a[Mesh.ARRAY_INDEX]
			var lista: PackedInt32Array = idx if idx != null else PackedInt32Array(range(vs.size()))
			for i in lista:
				V.append(b * (t * vs[i]))
				N.append((b * (t.basis * (ns[i] if ns != null else Vector3.UP))).normalized())
				var c := cor
				if img != null and uvs != null:
					var uv: Vector2 = uvs[i]
					var px := Vector2i(clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1), clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1))
					c = img.get_pixelv(px) * cor
				C.append(c)
	raiz.queue_free()
	var g := {"v": V, "n": N, "c": C}
	if op.get("cor") is Color:
		var base: Color = op["cor"]
		for i in C.size():
			var l: float = C[i].get_luminance()
			C[i] = base * (0.6 + 0.6 * l)
	if op.get("combate", false):
		for i in C.size():
			var l: float = C[i].get_luminance()
			C[i] = Color(0.2, 0.21, 0.17) * (0.6 + 0.9 * l)
	var faixas: Array = op.get("faixas", [])
	if not faixas.is_empty():
		var a := _aabb(V)
		for i in V.size():
			var f := (V[i].y - a.position.y) / maxf(a.size.y, 0.0001)
			for fx in faixas:
				if f <= fx[0]:
					C[i] = fx[1]
					break
	return g

func _aabb(V: PackedVector3Array) -> AABB:
	var a := AABB(V[0], Vector3.ZERO)
	for v in V:
		a = a.expand(v)
	return a

# escala para o comprimento (eixo Z), centraliza em X e Y e põe a origem na empunhadura
func _normalizar(g: Dictionary, comp: float, frac: float, acessorio: bool) -> Dictionary:
	var V: PackedVector3Array = g["v"]
	var a := _aabb(V)
	var k := comp / maxf(a.size.z, 0.0001)
	var o: Vector3
	if acessorio:
		o = Vector3(a.get_center().x, a.position.y, a.position.z)    # acessório: origem embaixo, atrás
	else:
		o = Vector3(a.get_center().x, a.get_center().y, a.position.z + a.size.z * frac)
	for i in V.size():
		V[i] = (V[i] - o) * k
	g["v"] = V
	return g

func _equip(g: Dictionary, medida: float, eixo: int) -> Dictionary:
	var V: PackedVector3Array = g["v"]
	var a := _aabb(V)
	var k := medida / maxf(a.size[eixo], 0.0001)
	var o := Vector3(a.get_center().x, a.position.y, a.get_center().z)    # origem: embaixo, no meio
	for i in V.size():
		V[i] = (V[i] - o) * k
	g["v"] = V
	return g

# tira a luneta embutida: triângulos acima do topo do cano (a luneta é acessório no jogo)
func _sem_luneta(g: Dictionary) -> Dictionary:
	var V: PackedVector3Array = g["v"]
	var a := _aabb(V)
	var topo_cano := -1e9
	for v in V:
		if v.z > a.end.z - a.size.z * 0.2:
			topo_cano = maxf(topo_cano, v.y)
	var lim := topo_cano + a.size.y * 0.06
	var V2 := PackedVector3Array()
	var N2 := PackedVector3Array()
	var C2 := PackedColorArray()
	for t in range(0, V.size(), 3):
		var cy := (V[t].y + V[t + 1].y + V[t + 2].y) / 3.0
		if cy > lim:
			continue
		for j in 3:
			V2.append(V[t + j]); N2.append(g["n"][t + j]); C2.append(g["c"][t + j])
	print("rifle_caca: tirou ", (V.size() - V2.size()) / 3, " triângulos da luneta")
	return {"v": V2, "n": N2, "c": C2}

func _arma_de_fogo(id: String, g: Dictionary, comp: float, frac: float, acc: Dictionary) -> void:
	var V: PackedVector3Array = g["v"]
	var a := _aabb(V)
	var k := comp / a.size.z
	# ponta do cano: média dos vértices nos últimos 3% do comprimento
	var soma := Vector3.ZERO
	var n := 0
	for v in V:
		if v.z > a.end.z - a.size.z * 0.03:
			soma += v
			n += 1
	var ponta := soma / maxf(n, 1)
	var alt_cano := ponta.y
	var o := Vector3(a.get_center().x, alt_cano - 0.04 / k, a.position.z + a.size.z * frac)
	for i in V.size():
		V[i] = (V[i] - o) * k
	g["v"] = V
	a = _aabb(V)
	var raiz := Node3D.new()
	raiz.name = "Arma_" + id
	var mi := MeshInstance3D.new()
	mi.name = "Malha"
	mi.mesh = _malha(g)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)
	var cano := Node3D.new()
	cano.name = "Cano"
	cano.position = Vector3(0, (alt_cano - o.y) * k, a.end.z)
	raiz.add_child(cano)
	if id != "espingarda":
		var ac := Node3D.new()
		ac.name = "Acc_cano"
		ac.visible = false
		var m1 := MeshInstance3D.new()
		m1.mesh = acc["silenciador"]
		m1.position = cano.position - Vector3(0, (acc["silenciador"] as ArrayMesh).get_aabb().size.y * 0.5, 0.01)
		ac.add_child(m1)
		raiz.add_child(ac)
	if id in ["m4", "ak", "rifle_caca"]:
		# topo do corpo na região do meio
		var topo := -1e9
		for v in V:
			if v.z > a.position.z + a.size.z * 0.3 and v.z < a.position.z + a.size.z * 0.55:
				topo = maxf(topo, v.y)
		var am := Node3D.new()
		am.name = "Acc_mira"
		am.visible = false
		var luneta := id == "rifle_caca"
		var m2 := MeshInstance3D.new()
		m2.name = "Luneta" if luneta else "Mira"
		m2.mesh = acc["luneta" if luneta else "mira_acog"]
		m2.position = Vector3(0, topo - 0.004, a.position.z + a.size.z * (0.3 if luneta else 0.36))
		am.add_child(m2)
		raiz.add_child(am)
	print(id, " tris ", V.size() / 3, " compr ", a.size.z, " cano ", cano.position)
	_salvar(raiz, SAIDA_ARMAS + id + ".scn")

func _malha(g: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var V: PackedVector3Array = g["v"]
	for i in V.size():
		st.set_color(g["c"][i])
		st.set_normal(g["n"][i])
		st.add_vertex(V[i])
	st.index()
	var m := st.commit()
	if V.size() / 3 > 3000:
		# pesada demais: simplifica com o gerador de LOD da Godot (alvo ~1500 triângulos)
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(0))
		im.generate_lods(25.0, 60.0, [])
		var arr := im.get_surface_arrays(0)
		for lod in im.get_surface_lod_count(0):
			var li := im.get_surface_lod_indices(0, lod)
			if li.size() / 3 >= 1500:
				arr[Mesh.ARRAY_INDEX] = li
		m = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		print("  simplificada: ", V.size() / 3, " -> ", arr[Mesh.ARRAY_INDEX].size() / 3, " triângulos")
	m.surface_set_material(0, _mat)
	return m

func _salvar(raiz: Node3D, caminho: String) -> void:
	for c in raiz.find_children("*", "", true, false):
		c.owner = raiz
	var ps := PackedScene.new()
	ps.pack(raiz)
	ResourceSaver.save(ps, caminho)
	raiz.free()
