extends SceneTree
# 1.10 · PERSONAGEM FEMININO e TODOS OS CABELOS ("Universal Base Characters" do Quaternius, CC0, versão Standard):
#   1) jogador/sobrevivente/corpo_f.scn = a mulher "Superhero" + cabelos (escondidos, o jogo escolhe um), com a PARTE
#      DO CORPO em COLOR.r de cada vértice (igual ao homem: ferramentas/preparar_personagem.gd), para as roupas.
#   2) jogador/sobrevivente/animacoes_f.res = as animações do homem (animacoes.res) convertidas para o esqueleto dela
#      (mesmos ossos; o repouso e as medidas mudam): rotação "a mais" em relação à pose de repouso, osso a osso.
#   3) jogador/sobrevivente/corpo.scn (homem) ganha os cabelos que faltavam (Buns, BuzzedFemale, Long).
#   As texturas (pele clara e escura dos dois, cabelo 1 e 2) vão para jogador/sobrevivente/texturas/.
# NÃO roda dentro do jogo. Como usar (dentro da pasta DDA_Godot_Cidade):
#   copie para res://_ubc_tmp/ a pasta "Base Characters/Godot - UE", "Hairstyles/Rigged to Head Bone/glTF (Godot
#   -Unreal)" e as peles claras de "Base Characters/Textures" do pacote Universal Base Characters [Standard];
#   godot --headless --import ; godot --headless -s ferramentas/preparar_personagem_f.gd ; apague res://_ubc_tmp/
const FPS := 30.0
const TMP := "res://_ubc_tmp/"
const TEX := "res://jogador/sobrevivente/texturas/"
const PASTA := "res://jogador/sobrevivente/"
const CABELOS := ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Beard", "Hair_Buns", "Hair_BuzzedFemale", "Hair_Long"]
const TEX_CABELO := {"Hair_Buns": "T_Hair_2", "Hair_Long": "T_Hair_2"}     # os outros usam T_Hair_1
const COPIAR := ["T_Superhero_Female_Dark_BaseColor.png", "T_Superhero_Female_Normal.png",
	"T_Superhero_Female_Roughness.png", "T_Hair_2_BaseColor.png", "T_Hair_2_Normal.png"]

func _initialize():
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
	# texturas para a pasta do jogo (a importação delas é feita pelo editor/--import depois)
	for f in COPIAR:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP + f), ProjectSettings.globalize_path(TEX + f))
	print("texturas copiadas: ", COPIAR.size(), " (rode --import de novo antes de usar)")
	# ---- 1) mulher
	var n: Node3D = load(TMP + "Superhero_Female_FullBody.gltf").instantiate()
	root.add_child(n)
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var corpo: MeshInstance3D = sk.get_node("Superhero_Female")
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
	for k in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		a[k] = null                         # canais extras do glTF (não usados): sem o formato deles a malha não monta
	var nova := ArrayMesh.new()
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
	var mat_corpo := StandardMaterial3D.new()
	mat_corpo.albedo_texture = load(TEX + "T_Superhero_Female_Dark_BaseColor.png")
	mat_corpo.normal_enabled = true
	mat_corpo.normal_texture = load(TEX + "T_Superhero_Female_Normal.png")
	mat_corpo.roughness_texture = load(TEX + "T_Superhero_Female_Roughness.png")
	mat_corpo.resource_name = "Pele"
	nova.surface_set_material(0, mat_corpo)
	nova.resource_name = "corpo_f"
	corpo.mesh = nova
	corpo.name = "Corpo"
	_material(sk.get_node("Eyes"), "T_Eye_Brown.png", "T_Eye_Normal.png")
	_material(sk.get_node("Eyebrows"), "T_Hair_2_BaseColor.png", "T_Hair_2_Normal.png")
	for c in CABELOS:
		_por_cabelo(sk, c)
	for c in n.find_children("*", "", true, false):
		c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	print("corpo_f -> ", ResourceSaver.save(ps, PASTA + "corpo_f.scn"), " tris ", nova.surface_get_array_index_len(0) / 3)
	# ---- 2) animações do homem -> esqueleto dela
	var nh: Node3D = load(PASTA + "corpo.scn").instantiate()
	root.add_child(nh)
	var sh: Skeleton3D = nh.find_children("*", "Skeleton3D", true, false)[0]
	var lib_h: AnimationLibrary = load(PASTA + "animacoes.res")
	var lib := AnimationLibrary.new()
	for nome in lib_h.get_animation_list():
		lib.add_animation(nome, converter(lib_h.get_animation(nome), sh, sk))
	print("animacoes_f -> ", ResourceSaver.save(lib, PASTA + "animacoes_f.res", ResourceSaver.FLAG_COMPRESS), " ", lib.get_animation_list().size())
	# ---- 3) homem: os cabelos que faltavam
	var faltam := 0
	for c in CABELOS:
		if sh.get_node_or_null(c) == null:
			_por_cabelo(sh, c)
			faltam += 1
	for c in nh.find_children("*", "", true, false):
		if c.owner == null or c.owner != nh:
			c.owner = nh
	var ph := PackedScene.new()
	ph.pack(nh)
	print("corpo (homem) + ", faltam, " cabelos -> ", ResourceSaver.save(ph, PASTA + "corpo.scn"))
	quit()

# um cabelo preso ao osso da cabeça, no esqueleto "sk", escondido (o jogo escolhe qual mostrar)
func _por_cabelo(sk: Skeleton3D, c: String) -> void:
	var h: Node = load(TMP + "%s.gltf" % c).instantiate()
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
	var t: String = TEX_CABELO.get(c, "T_Hair_1")
	_material(hm, t + "_BaseColor.png", t + "_Normal.png")
	hm.skeleton = NodePath("..")
	h.free()

func _material(mi: MeshInstance3D, cor: String, normal: String) -> void:
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = load(TEX + cor) if ResourceLoader.exists(TEX + cor) else load(TMP + cor)
	mt.normal_enabled = true
	mt.normal_texture = load(TEX + normal) if ResourceLoader.exists(TEX + normal) else load(TMP + normal)
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

# a mesma conversão de ferramentas/preparar_personagem.gd (esqueleto su -> sb)
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
		var d: Vector3 = (gu[pu] as Transform3D).origin - (gu_t[pu] as Transform3D).origin
		var pos: Vector3 = (gb_t[pb] as Transform3D).origin + d * escala
		var pai_p := sb.get_bone_parent(pb)
		if pai_p >= 0:
			var gp_pai: Transform3D = gb_t[pai_p]
			gp_pai.basis = gb[pai_p] as Basis
			pos = gp_pai.affine_inverse() * pos
		novo.position_track_insert_key(tp, t, pos)
	return novo
