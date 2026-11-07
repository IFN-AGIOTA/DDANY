extends SceneTree
# 1.11 · MONTA AS ROUPAS (jogador/roupas/<peça>_<m|f>.res) a partir do que ferramentas/roupas_mh/ajustar_roupas.py
# deixou em ENTRADA (um .json por peça e corpo: vértices já no corpo UBC, UV, ossos/pesos e a pele que fica coberta).
#   ENTRADA=/pasta/saida godot --headless -s res://ferramentas/preparar_roupas.gd
# Cada peça: o simplificador do Godot (meshoptimizer) reduz até ALVO triângulos; a malha final ainda ganha LODs (de
# longe ela fica mais leve sozinha). A lista de vértices do corpo escondidos vai em mesh.get_meta("esconde").
# As texturas já estão em jogador/roupas/texturas/<peça>.png (o .py reduz para 512).
const PASTA := "res://jogador/roupas/"
const ALVO_PADRAO := 6000
const ALVO := {"cabeca": 2500, "rosto": 2000, "pes": 3000, "luvas": 1500}
const SHADER := preload("res://jogador/roupa.gdshader")
const FORMATO := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT

func _initialize():
	var ent := OS.get_environment("ENTRADA")
	var so := OS.get_environment("SO")                 # opcional: só estas peças (separadas por vírgula)
	var alvos := {}
	var fa := FileAccess.open(ent + "/alvos.json", FileAccess.READ)
	if fa != null:
		alvos = JSON.parse_string(fa.get_as_text())
	var d := DirAccess.open(ent)
	var n := 0
	for f in d.get_files():
		if not f.ends_with(".json") or f == "alvos.json":
			continue
		var nm := f.get_basename()
		var peca := nm.substr(0, nm.length() - 2)
		if so != "" and not (peca in so.split(",")):
			continue
		var j = JSON.parse_string(FileAccess.get_file_as_string(ent + "/" + f))
		var alvo: int = int(alvos.get(peca, ALVO_PADRAO))
		var m := _malha(j, alvo)
		ResourceSaver.save(m, PASTA + nm + ".res", ResourceSaver.FLAG_COMPRESS)
		n += 1
		print("ROUPA ", nm, " tris ", m.surface_get_array_index_len(0) / 3, " lods ", m.surface_get_array_len(0))
	print("ROUPAS PRONTAS: ", n)
	quit()

func _malha(j: Dictionary, alvo: int) -> ArrayMesh:
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var UV := PackedVector2Array()
	var Bo := PackedInt32Array()
	var Wo := PackedFloat32Array()
	for v in j["V"]:
		V.append(Vector3(v[0], v[1], v[2]))
	for v in j["N"]:
		N.append(Vector3(v[0], v[1], v[2]))
	for v in j["UV"]:
		UV.append(Vector2(v[0], 1.0 - v[1]))
	for b in j["B"]:
		for k in 4:
			Bo.append(int(b[k]))
	for w in j["W"]:
		for k in 4:
			Wo.append(float(w[k]))
	var I := PackedInt32Array(j["I"])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V
	arr[Mesh.ARRAY_NORMAL] = N
	arr[Mesh.ARRAY_TEX_UV] = UV
	arr[Mesh.ARRAY_BONES] = Bo
	arr[Mesh.ARRAY_WEIGHTS] = Wo
	arr[Mesh.ARRAY_INDEX] = I
	# altura de cada vértice em pé (UV2.x): dá para "cortar" a calça dentro da bota (jogador/roupa.gdshader)
	var UV2 := PackedVector2Array()
	for v in V:
		UV2.append(Vector2(v.y, 0.0))
	arr[Mesh.ARRAY_TEX_UV2] = UV2
	# camadas (ferramentas/roupas_mh/camadas.py): CUSTOM0 = (distância até a pele, vértice do corpo mais perto)
	var C0 := PackedFloat32Array()
	var dvs: Array = j.get("dv", [])
	var ibs: Array = j.get("ib", [])
	for k in V.size():
		C0.append_array([float(dvs[k]) if k < dvs.size() else 0.0, float(ibs[k]) if k < ibs.size() else 0.0, 0.0, 0.0])
	arr[Mesh.ARRAY_CUSTOM0] = C0
	# 1) reduz: escolhe o primeiro LOD com até "alvo" triângulos
	if I.size() / 3 > alvo:
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, "", FORMATO)
		im.generate_lods(25.0, 60.0, [])
		var melhor := I
		for l in im.get_surface_lod_count(0):
			var li := im.get_surface_lod_indices(0, l)
			melhor = li
			if li.size() / 3 <= alvo:
				break
		arr[Mesh.ARRAY_INDEX] = melhor
	arr = _compactar(arr)
	var y0 := 1e9
	var y1 := -1e9
	for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	# 2) malha final com LODs
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var tex_p: String = PASTA + "texturas/" + str(j["nome"]).split("__")[0] + ".png"
	if ResourceLoader.exists(tex_p):
		var t: Texture2D = load(tex_p)
		mat.set_shader_parameter("textura", t)
		var img := t.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			mat.set_shader_parameter("alfa", img.detect_alpha() != Image.ALPHA_NONE)
	var c: PackedStringArray = str(j.get("cor", "1 1 1")).split(" ", false)
	if c.size() >= 3:
		mat.set_shader_parameter("cor", Color(float(c[0]), float(c[1]), float(c[2])))
	var im2 := ImporterMesh.new()
	im2.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mat, "", FORMATO)
	im2.generate_lods(25.0, 60.0, [])
	var m := im2.get_mesh()
	m.set_meta("esconde", PackedInt32Array(j["esconde"]))
	m.set_meta("peca", str(j["nome"]))
	m.set_meta("y", Vector2(y0, y1))                  # altura mais baixa e mais alta (a boca da bota = y.y)
	m.set_meta("grossura", float(j.get("grossura", 0.0)))   # longe da pele no tronco (percentil 85): o colete passa por fora
	m.set_meta("perto", float(j.get("perto", 0.0)))         # parte mais perto da pele no tronco (percentil 5)
	m.set_meta("esp", PackedByteArray(j.get("esp", [])))    # espessura (mm) em cada vértice do corpo: a peça de cima passa por fora
	return m

# tira os vértices que nenhum triângulo usa mais
func _compactar(arr: Array) -> Array:
	var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var novo := {}
	var mapa := PackedInt32Array()
	mapa.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	mapa.fill(-1)
	var ordem := PackedInt32Array()
	for i in I:
		if mapa[i] < 0:
			mapa[i] = ordem.size()
			ordem.append(i)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var V := PackedVector3Array(); var N := PackedVector3Array(); var UV := PackedVector2Array()
	var Bo := PackedInt32Array(); var Wo := PackedFloat32Array(); var UV2 := PackedVector2Array()
	var UV20: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	var C00: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	var C0 := PackedFloat32Array()
	var V0: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var N0: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var UV0: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var B0: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var W0: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	for i in ordem:
		V.append(V0[i]); N.append(N0[i]); UV.append(UV0[i]); UV2.append(UV20[i])
		C0.append_array([C00[i * 4], C00[i * 4 + 1], C00[i * 4 + 2], C00[i * 4 + 3]])
		for k in 4:
			Bo.append(B0[i * 4 + k]); Wo.append(W0[i * 4 + k])
	var I2 := PackedInt32Array()
	I2.resize(I.size())
	for k in I.size():
		I2[k] = mapa[I[k]]
	out[Mesh.ARRAY_VERTEX] = V
	out[Mesh.ARRAY_NORMAL] = N
	out[Mesh.ARRAY_TEX_UV] = UV
	out[Mesh.ARRAY_TEX_UV2] = UV2
	out[Mesh.ARRAY_CUSTOM0] = C0
	out[Mesh.ARRAY_BONES] = Bo
	out[Mesh.ARRAY_WEIGHTS] = Wo
	out[Mesh.ARRAY_INDEX] = I2
	return out
