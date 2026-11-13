extends SceneTree
# 1.20 · PREPARA AS ÁRVORES DO JOGO a partir dos .glb que ferramentas/arvores_ez/gerar.mjs fez (EZ-Tree):
#   - junta casca + folhas numa malha só (2 superfícies), no tamanho do jogo (altura de variantes.json), com a base do
#     tronco no ponto (0, 0, 0); escala da textura da casca dentro das UVs; tangentes (normal map); normais das folhas
#     "redondas" (de dentro da copa para fora: a luz fica macia como numa copa de verdade)
#   - grava mundo/arvores/modelos/<nome>.res
#   - grava mundo/arvores/arvores.json (altura, raio da copa, raio do tronco, tipos)
#   (1.21: as "fotos" dos impostores saíram: de longe a árvore agora é de VOXELS; os níveis de detalhe saem do
#   ferramentas/preparar_arvores_lod.gd, que se roda DEPOIS deste)
# Rodar:
#   GLB=<pasta dos .glb> godot --headless --path . -s res://ferramentas/preparar_arvores.gd
#   godot --headless --path . -s res://ferramentas/preparar_arvores_lod.gd
const Arv := preload("res://mundo/arvores.gd")
const SAIDA := "res://mundo/arvores/"

func _initialize() -> void:
	_r.call_deferred()

func _r() -> void:
	var dir_glb := OS.get_environment("GLB")
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ferramentas/arvores_ez/variantes.json"))
	var geradas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir_glb + "/variantes_geradas.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA + "modelos"))
	var modelos: Array = []
	for v in cfg["variantes"]:
		var nome := String(v["nome"])
		var g: Dictionary = geradas[nome]
		var am := _malha(dir_glb + "/" + nome + ".glb", g, float(v["altura"]))
		if am == null:
			print("FALHOU ", nome)
			continue
		var e: Dictionary = am.get_meta("info")
		e["nome"] = nome
		e["tipo"] = String(v["tipo"])
		e["seca"] = bool(v.get("seca", false))
		e["casca"] = String(g["casca"])
		e["folha"] = String(g["folha"])
		e["cor_folha"] = Color.hex(int(g["folha_tint"]) << 8 | 0xff).to_html(false)
		am.remove_meta("info")
		ResourceSaver.save(am, SAIDA + "modelos/%s.res" % nome, ResourceSaver.FLAG_COMPRESS)
		modelos.append(e)
		print("ARVORE %s · %d triângulos · altura %.1f m · copa %.1f m · tronco %.2f m" % [nome, e["tris"], e["altura"], e["raio_copa"], e["raio_tronco"]])
	var f := FileAccess.open(SAIDA + "arvores.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"_leia": "1.20 · gerado por ferramentas/preparar_arvores.gd (não editar à mão)", "modelos": modelos}, "\t"))
	f.close()
	print("PRONTO: %d modelos" % modelos.size())
	quit()

# lê o .glb (GLTFDocument, sem importar no projeto) e devolve a malha pronta (meta "info" com as medidas)
func _malha(arq: String, g: Dictionary, altura: float) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(arq, st) != OK:
		return null
	var cena := doc.generate_scene(st)
	var partes := {}                             # "casca" / "folhas" -> [arrays em coordenadas da cena]
	for n in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var t: Transform3D = _global(mi, cena)
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var qual := "folhas" if mat != null and String(mat.resource_name).begins_with("folha") else "casca"
			var a := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			for i in vs.size():
				vs[i] = t * vs[i]
				if ns.size() == vs.size():
					ns[i] = (t.basis * ns[i]).normalized()
			a[Mesh.ARRAY_VERTEX] = vs
			a[Mesh.ARRAY_NORMAL] = ns
			partes[qual] = a
	cena.free()
	if not partes.has("casca"):
		return null
	# medidas: base do tronco, altura e centro
	var vc: PackedVector3Array = partes["casca"][Mesh.ARRAY_VERTEX]
	var y0 := INF
	var y1 := -INF
	for p in vc:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	if partes.has("folhas"):
		for p in partes["folhas"][Mesh.ARRAY_VERTEX]:
			y1 = maxf(y1, p.y)
	var h := y1 - y0
	var base := Vector2.ZERO
	var nb := 0
	for p in vc:
		if p.y < y0 + h * 0.02:
			base += Vector2(p.x, p.z)
			nb += 1
	base /= maxf(nb, 1)
	var s := altura / h
	var off := Vector3(-base.x, -y0, -base.y)
	var rt := 0.0
	var rc := 0.0
	var am := ArrayMesh.new()
	var tris := 0
	for qual in ["casca", "folhas"]:
		if not partes.has(qual):
			continue
		var a: Array = partes[qual]
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		for i in vs.size():
			vs[i] = (vs[i] + off) * s
			var dh := Vector2(vs[i].x, vs[i].z).length()
			rc = maxf(rc, dh)
			if qual == "casca" and vs[i].y < 0.25:
				rt = maxf(rt, dh)
		if qual == "casca":
			var esc := Vector2(float(g["escala_tex"]["x"]), 1.0 / maxf(float(g["escala_tex"]["y"]), 0.01))
			for i in uv.size():
				uv[i] *= esc
		else:
			var centro := Vector3(0, altura * 0.62, 0)
			for i in vs.size():
				var radial := (vs[i] - centro).normalized()
				ns[i] = (radial * 0.75 + ns[i] * 0.25).normalized()
		var stt := SurfaceTool.new()
		stt.begin(Mesh.PRIMITIVE_TRIANGLES)
		var idx = a[Mesh.ARRAY_INDEX]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_NORMAL] = ns
		arr[Mesh.ARRAY_TEX_UV] = uv
		if idx != null and (idx as PackedInt32Array).size() > 0:
			arr[Mesh.ARRAY_INDEX] = idx
			tris += (idx as PackedInt32Array).size() / 3
		else:
			tris += vs.size() / 3
		stt.create_from_arrays(arr)
		if qual == "casca":
			stt.generate_tangents()
		stt.commit(am)
	am.set_meta("info", {"altura": snappedf(altura, 0.01), "raio_copa": snappedf(rc, 0.01), "raio_tronco": snappedf(maxf(rt, 0.1), 0.01),
		"lado": snappedf(maxf(rc * 2.0, altura) * 1.04, 0.01), "tris": tris})
	return am

func _global(n: Node3D, raiz: Node) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != raiz:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
