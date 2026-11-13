extends SceneTree
# 0.90 · acrescenta "pisar" (Jump_Land da UAL1, Quaternius CC0: o pisão no infectado caído) à biblioteca do jogador
# (jogador/sobrevivente/animacoes.res). NÃO roda dentro do jogo. Como usar: no projeto de apoio de
# ferramentas/preparar_infectados.gd (com res://m/ual1ue.fbx), rode
#   ENTRADA=<animacoes.res atual> SAIDA=<arquivo novo> godot --headless -s este_arquivo
# e copie o arquivo novo (já salvo com compressão) por cima de jogador/sobrevivente/animacoes.res.
func _initialize():
	var lib: AnimationLibrary = load(OS.get_environment("ENTRADA")).duplicate(true)
	var a1: AnimationPlayer = load("res://m/ual1ue.fbx").instantiate().find_children("*", "AnimationPlayer", true, false)[0]
	var rx := Quaternion(Vector3.RIGHT, -PI / 2.0)
	var ossos := {}
	var ref: Animation = lib.get_animation("soco")
	for t in ref.get_track_count():
		ossos[String(ref.track_get_path(t))] = true
	for par in [["Rig|Jump_Land", "pisar"]]:
		var a: Animation = a1.get_animation(par[0]).duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
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
		a.loop_mode = Animation.LOOP_NONE
		if lib.has_animation(par[1]): lib.remove_animation(par[1])
		lib.add_animation(par[1], a)
		print(par[1], " ", a.length, " trilhas ", a.get_track_count())
	print("salvo: ", ResourceSaver.save(lib, OS.get_environment("SAIDA"), ResourceSaver.FLAG_COMPRESS))
	quit()
