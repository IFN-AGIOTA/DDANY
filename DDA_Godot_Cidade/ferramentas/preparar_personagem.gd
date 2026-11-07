extends SceneTree
# PREPARA O PERSONAGEM DO JOGADOR: "Universal Base Characters" do Quaternius (CC0, homem "Superhero", pele, olhos,
# sobrancelhas e cabelo de verdade) no lugar do manequim antigo.
#   1) CORPO: jogador/sobrevivente/corpo.scn = o personagem + cabelos (escondidos, o jogo escolhe um) e barba.
#      Cada vértice do corpo guarda em COLOR.r a PARTE DO CORPO (rosto, pescoço, tronco, braço, antebraço, mão,
#      quadril, coxa, canela, pé), igual ao manequim antigo: o jogo usa isso para vestir as roupas (cascas por cima
#      do corpo) e esconder a pele que fica embaixo delas (jogador/modelo_sobrevivente.gd).
#   2) ANIMAÇÕES: as do jogo (feitas para o esqueleto do manequim: preparar_jogador.gd + retarget_kaykit.gd) são
#      convertidas para o esqueleto deste personagem (mesmos ossos, mas o repouso de alguns gira até 17° e as
#      medidas mudam): rotação "a mais" em relação à pose T, no mundo, osso a osso; o quadril escala pela altura.
# NÃO roda dentro do jogo. Como usar (projeto temporário):
#   res://ubc/  = pasta "Base Characters/Godot - UE" + "Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)"
#                 + "Base Characters/Textures" do pacote Universal Base Characters [Standard]
#   res://m/ual2.glb (esqueleto do manequim) e res://m/anims_ual.res (animacoes.res no esqueleto do manequim)
#   godot --headless --import ; SAIDA=<pasta jogador/sobrevivente/ do jogo>/ godot --headless -s preparar_personagem.gd
const FPS := 30.0
const TEX := "res://jogador/sobrevivente/texturas/"     # texturas copiadas para o jogo (mesmo caminho aqui e lá)
const PELE := TEX + "T_Superhero_Male_Dark.png"
const CABELOS := ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Beard"]
var SAIDA := ""

func _initialize():
	SAIDA = OS.get_environment("SAIDA")
	_rodar.call_deferred()

func _regiao(osso: String) -> int:
	if osso == "Head": return 0
	if osso == "neck_01": return 2
	if osso.begins_with("hand") or osso.begins_with("index") or osso.begins_with("middle") or osso.begins_with("pinky") or osso.begins_with("ring") or osso.begins_with("thumb"): return 6
	if osso.begins_with("lowerarm"): return 5
	if osso.begins_with("upperarm"): return 4
	if osso.begins_with("clavicle") or osso.begins_with("spine"): return 3
	if osso == "pelvis": return 7
	if osso.begins_with("thigh"): return 8
	if osso.begins_with("calf"): return 9
	if osso.begins_with("foot") or osso.begins_with("ball"): return 10
	return 3

func _rodar() -> void:
	var n: Node3D = load("res://ubc/Superhero_Male_FullBody.gltf").instantiate()
	root.add_child(n)
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var corpo: MeshInstance3D = sk.get_node("SuperHero_Male")
	# ---- regiões no COLOR do corpo
	var m: Mesh = corpo.mesh
	var a: Array = m.surface_get_arrays(0)
	var nb := 8 if (m.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 4
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var ruido := FastNoiseLite.new()
	ruido.frequency = 3.0
	var C := PackedColorArray()
	var skin: Skin = corpo.skin
	for vi in vs.size():
		var melhor := 0
		var mw := -1.0
		for j in nb:
			if ws[vi * nb + j] > mw:
				mw = ws[vi * nb + j]
				melhor = bs[vi * nb + j]
		var bn := String(skin.get_bind_name(melhor))
		if bn == "":
			bn = sk.get_bone_name(skin.get_bind_bone(melhor))
		var p := vs[vi]
		C.append(Color(_regiao(bn) / 15.0, 0.5 + 0.5 * ruido.get_noise_3d(p.x * 20.0, p.y * 20.0, p.z * 20.0), 0.0, 1.0))
	a[Mesh.ARRAY_COLOR] = C
	var nova := ArrayMesh.new()
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
	var mat_corpo := StandardMaterial3D.new()
	mat_corpo.albedo_texture = load(PELE)
	mat_corpo.normal_enabled = true
	mat_corpo.normal_texture = load(TEX + "T_Superhero_Male_Normal.png")
	mat_corpo.roughness_texture = load(TEX + "T_Superhero_Male_Roughness.png")
	mat_corpo.resource_name = "Pele"
	nova.surface_set_material(0, mat_corpo)
	nova.resource_name = "corpo"
	corpo.mesh = nova
	corpo.name = "Corpo"
	# olhos e sobrancelhas com as texturas da pasta do jogo
	_material(sk.get_node("Eyes"), "T_Eye_Brown.png", "T_Eye_Normal.png")
	_material(sk.get_node("Eyebrows"), "T_Hair_1_BaseColor.png", "T_Hair_1_Normal.png")
	# ---- cabelos (presos ao osso da cabeça): entram no mesmo esqueleto, escondidos
	for c in CABELOS:
		var h: Node = load("res://ubc/%s.gltf" % c).instantiate()
		var hm: MeshInstance3D = h.find_children("*", "MeshInstance3D", true, false)[0]
		var hsk: Skeleton3D = h.find_children("*", "Skeleton3D", true, false)[0]
		var novo_skin := Skin.new()
		for i in hm.skin.get_bind_count():
			var bn := String(hm.skin.get_bind_name(i))
			if bn == "":
				bn = hsk.get_bone_name(hm.skin.get_bind_bone(i))
			novo_skin.add_named_bind(bn, hm.skin.get_bind_pose(i))
		hm.get_parent().remove_child(hm)
		hm.skin = novo_skin
		hm.name = c
		hm.visible = false
		sk.add_child(hm)
		_material(hm, "T_Hair_1_BaseColor.png", "T_Hair_1_Normal.png")
		hm.skeleton = NodePath("..")
		h.free()
	for c in n.find_children("*", "", true, false):
		c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	print("corpo -> ", ResourceSaver.save(ps, SAIDA + "corpo.scn"), " tris ", nova.surface_get_array_index_len(0) / 3)
	# ---- animações para este esqueleto
	var nu: Node = load("res://m/ual2.glb").instantiate()
	var su: Skeleton3D = nu.find_children("*", "Skeleton3D", true, false)[0]
	var lib_u: AnimationLibrary = load("res://m/anims_ual.res")
	var lib := AnimationLibrary.new()
	for nome in lib_u.get_animation_list():
		lib.add_animation(nome, converter(lib_u.get_animation(nome), su, sk))
	print("animações -> ", ResourceSaver.save(lib, SAIDA + "animacoes.res"), " ", lib.get_animation_list().size())
	quit()

func _material(mi: MeshInstance3D, cor: String, normal: String) -> void:
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = load(TEX + cor)
	mt.normal_enabled = true
	mt.normal_texture = load(TEX + normal)
	mt.roughness = 0.75
	mi.mesh = mi.mesh.duplicate()
	mi.mesh.surface_set_material(0, mt)

func _globais(sk: Skeleton3D, locais: Array) -> Array:
	var g: Array = []
	g.resize(locais.size())
	for b in sk.get_bone_count():
		var pai := sk.get_bone_parent(b)
		g[b] = locais[b] if pai < 0 else (g[pai] as Transform3D) * (locais[b] as Transform3D)
	return g

func converter(a: Animation, su: Skeleton3D, sb: Skeleton3D) -> Animation:
	var faixas := {}
	for i in a.get_track_count():
		var osso := String(a.track_get_path(i)).get_slice(":", 1)
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			faixas[osso + ":r"] = i
		elif a.track_get_type(i) == Animation.TYPE_POSITION_3D:
			faixas[osso + ":p"] = i
	var ru: Array = []
	for b in su.get_bone_count():
		ru.append(su.get_bone_rest(b))
	var gu_t := _globais(su, ru)
	var rb: Array = []
	for b in sb.get_bone_count():
		rb.append(sb.get_bone_rest(b))
	var gb_t := _globais(sb, rb)
	var par := {}
	for b in sb.get_bone_count():
		par[b] = su.find_bone(sb.get_bone_name(b))
	var pu := su.find_bone("pelvis")
	var pb := sb.find_bone("pelvis")
	var escala: float = (gb_t[pb] as Transform3D).origin.y / (gu_t[pu] as Transform3D).origin.y
	var novo := Animation.new()
	novo.length = a.length
	novo.loop_mode = a.loop_mode
	var trilhas := {}
	for b in sb.get_bone_count():
		var t := novo.add_track(Animation.TYPE_ROTATION_3D)
		novo.track_set_path(t, NodePath("Armature/Skeleton3D:" + sb.get_bone_name(b)))
		trilhas[b] = t
	var tp := novo.add_track(Animation.TYPE_POSITION_3D)
	novo.track_set_path(tp, NodePath("Armature/Skeleton3D:pelvis"))
	var n := maxi(2, int(ceil(a.length * FPS)) + 1)
	for f in n:
		var t := minf(f / FPS, a.length)
		var locais: Array = []
		for b in su.get_bone_count():
			var nome := su.get_bone_name(b)
			var r: Transform3D = ru[b]
			var q := r.basis.get_rotation_quaternion()
			var p := r.origin
			if faixas.has(nome + ":r"):
				q = a.rotation_track_interpolate(faixas[nome + ":r"], t)
			if faixas.has(nome + ":p") and (nome == "pelvis" or nome == "root"):
				p = a.position_track_interpolate(faixas[nome + ":p"], t)
			locais.append(Transform3D(Basis(q), p))
		var gu := _globais(su, locais)
		var gb: Array = []
		gb.resize(sb.get_bone_count())
		for b in sb.get_bone_count():
			var pai := sb.get_bone_parent(b)
			var gpai: Basis = (gb[pai] as Basis) if pai >= 0 else Basis.IDENTITY
			var ub: int = par[b]
			var bas: Basis
			if ub >= 0:
				var delta: Basis = (gu[ub] as Transform3D).basis.orthonormalized() * (gu_t[ub] as Transform3D).basis.orthonormalized().inverse()
				bas = delta * (gb_t[b] as Transform3D).basis.orthonormalized()
			else:
				bas = gpai * (rb[b] as Transform3D).basis
			gb[b] = bas
			novo.rotation_track_insert_key(trilhas[b], t, (gpai.inverse() * bas).get_rotation_quaternion())
		# quadril: deslocamento em relação ao repouso, na escala deste personagem (no espaço do pai do quadril)
		var d: Vector3 = (gu[pu] as Transform3D).origin - (gu_t[pu] as Transform3D).origin
		var pos: Vector3 = (gb_t[pb] as Transform3D).origin + d * escala
		var pai_p := sb.get_bone_parent(pb)
		if pai_p >= 0:
			var gp_pai: Transform3D = gb_t[pai_p]
			gp_pai.basis = gb[pai_p] as Basis
			pos = gp_pai.affine_inverse() * pos
		novo.position_track_insert_key(tp, t, pos)
	return novo
