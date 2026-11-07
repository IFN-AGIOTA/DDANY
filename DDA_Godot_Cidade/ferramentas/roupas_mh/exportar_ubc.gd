extends SceneTree
# exporta o corpo do jogo (homem e mulher) para o ajuste das roupas: SAIDA=<MH_PASTA>/ubc godot --headless -s res://ferramentas/roupas_mh/exportar_ubc.gd
func _initialize():
	for sx in [["m", "corpo.scn"], ["f", "corpo_f.scn"]]:
		var n = load("res://jogador/sobrevivente/" + sx[1]).instantiate()
		var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
		var mi: MeshInstance3D = sk.get_node("Corpo")
		var a = mi.mesh.surface_get_arrays(0)
		var d := {}
		d["V"] = Array(a[Mesh.ARRAY_VERTEX]).map(func(v): return [v.x, v.y, v.z])
		d["N"] = Array(a[Mesh.ARRAY_NORMAL]).map(func(v): return [v.x, v.y, v.z])
		d["C"] = Array(a[Mesh.ARRAY_COLOR]).map(func(c): return c.r)
		d["B"] = Array(a[Mesh.ARRAY_BONES])
		d["W"] = Array(a[Mesh.ARRAY_WEIGHTS])
		d["I"] = Array(a[Mesh.ARRAY_INDEX])
		var ossos := []
		for i in sk.get_bone_count():
			var g := sk.get_bone_global_rest(i)
			ossos.append({"nome": sk.get_bone_name(i), "pai": sk.get_bone_parent(i), "o": [g.origin.x, g.origin.y, g.origin.z]})
		d["ossos"] = ossos
		# skin: bind de cada índice -> nome do osso
		var sk_res: Skin = mi.skin
		var binds := []
		for b in sk_res.get_bind_count():
			var t := sk_res.get_bind_pose(b)
			binds.append({"nome": sk_res.get_bind_name(b), "osso": sk_res.get_bind_bone(b), "t": [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]})
		d["binds"] = binds
		d["mi_t"] = [mi.transform.origin.x, mi.transform.origin.y, mi.transform.origin.z]
		var f := FileAccess.open(OS.get_environment("SAIDA") + "/ubc_" + sx[0] + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		print(sx[0], " verts ", d["V"].size(), " tris ", d["I"].size() / 3, " binds ", binds.size(), " nb ", d["W"].size() / d["V"].size())
		n.free()
	quit()
