extends SceneTree
# 0.91 · acrescenta à biblioteca dos manequins (inimigos/infectados/animacoes.res, a mesma dos infectados) as animações
# dos SOBREVIVENTES DO HOSPITAL (npc/modelo_npc.gd), da "Universal Animation Library" 1 e 2 do Quaternius (CC0):
#   UAL2: Idle_FoldArms -> npc_bracos (Carlos, de guarda) · Idle_TalkingPhone -> npc_radio (Lucas no rádio) ·
#         Yes -> npc_sim · Idle_No -> npc_nao
#   UAL1 (versão Unreal): Idle -> npc_parado · Idle_Talking -> npc_falando · Sitting_Idle -> npc_sentado
# NÃO roda dentro do jogo. Como usar: no projeto de apoio de ferramentas/preparar_infectados.gd (com res://m/ual2.glb
# e res://m/ual1ue.fbx), rode  ENTRADA=<animacoes.res atual> SAIDA=<arquivo novo> godot --headless -s este_arquivo
# e copie o arquivo novo (já salvo com compressão) por cima de inimigos/infectados/animacoes.res.
func _initialize():
	var lib: AnimationLibrary = load(OS.get_environment("ENTRADA")).duplicate(true)
	var a2: AnimationPlayer = load("res://m/ual2.glb").instantiate().find_children("*", "AnimationPlayer", true, false)[0]
	for par in [["Idle_FoldArms", "npc_bracos", true], ["Idle_TalkingPhone", "npc_radio", true], ["Yes", "npc_sim", false], ["Idle_No", "npc_nao", false]]:
		var a: Animation = a2.get_animation(par[0]).duplicate(true)
		a.loop_mode = Animation.LOOP_LINEAR if par[2] else Animation.LOOP_NONE
		if lib.has_animation(par[1]): lib.remove_animation(par[1])
		lib.add_animation(par[1], a)
		print(par[1], " ", a.length, " trilhas ", a.get_track_count())
	var a1: AnimationPlayer = load("res://m/ual1ue.fbx").instantiate().find_children("*", "AnimationPlayer", true, false)[0]
	var rx := Quaternion(Vector3.RIGHT, -PI / 2.0)
	for par in [["Rig|Idle", "npc_parado"], ["Rig|Idle_Talking", "npc_falando"], ["Rig|Sitting_Idle", "npc_sentado"]]:
		var a: Animation = a1.get_animation(par[0]).duplicate(true)
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
		a.loop_mode = Animation.LOOP_LINEAR
		if lib.has_animation(par[1]): lib.remove_animation(par[1])
		lib.add_animation(par[1], a)
		print(par[1], " ", a.length, " trilhas ", a.get_track_count())
	print("salvo: ", ResourceSaver.save(lib, OS.get_environment("SAIDA"), ResourceSaver.FLAG_COMPRESS))
	quit()
