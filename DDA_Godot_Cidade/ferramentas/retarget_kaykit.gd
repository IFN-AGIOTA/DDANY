extends SceneTree
# CONVERTE ANIMAÇÕES do KayKit Character Animations (Kay Lousberg, CC0, esqueleto "Rig_Medium") para o esqueleto do
# jogo (Universal Animation Library do Quaternius: pelvis, spine_01..03, upperarm_l...). Junta tudo em
# jogador/sobrevivente/animacoes.res, com nomes em português (veja CONVERTER).
# Como funciona (retarget por rotação no mundo): os dois esqueletos estão em pose T no repouso; para cada osso
# mapeado, a rotação "a mais" que ele tem em relação à pose T (no mundo) é aplicada ao osso equivalente do jogo.
# O quadril também se move (subir/descer ao andar), escalado pela altura do quadril. Ossos sem par (dedos,
# pescoço, clavícula, spine_02) ficam como numa animação base do jogo (dedos fechados segurando a arma, etc.).
# NÃO roda dentro do jogo. Como usar: num projeto temporário com
#   res://m/ual2.glb (esqueleto do jogo), res://m/anims_jogo.res (cópia de jogador/sobrevivente/animacoes.res)
#   res://kk/Rig_Medium_*.glb (Animations/gltf/Rig_Medium do pacote KayKit)
# rode  godot --headless --import  e depois  SAIDA=<arquivo .res> godot --headless -s retarget_kaykit.gd
const FPS := 30.0

# osso KayKit -> osso do jogo
const MAPA := {"hips": "pelvis", "spine": "spine_01", "chest": "spine_03", "head": "Head",
	"upperarm.l": "upperarm_l", "lowerarm.l": "lowerarm_l", "hand.l": "hand_l",
	"upperarm.r": "upperarm_r", "lowerarm.r": "lowerarm_r", "hand.r": "hand_r",
	"upperleg.l": "thigh_l", "lowerleg.l": "calf_l", "foot.l": "foot_l", "toes.l": "ball_l",
	"upperleg.r": "thigh_r", "lowerleg.r": "calf_r", "foot.r": "foot_r", "toes.r": "ball_r"}

# [arquivo, animação KayKit, nome no jogo, base para dedos/pescoço ("parado" mão aberta, "parado_arma" segurando), laço]
const CONVERTER := [
	# locomoção em direções (com a corrida de frente e o andar do jogo = 8 direções)
	["MovementAdvanced", "Running_Strafe_Left", "correr_esq", "parado", true],
	["MovementAdvanced", "Running_Strafe_Right", "correr_dir", "parado", true],
	["MovementAdvanced", "Walking_Backwards", "andar_tras", "parado", true],
	["MovementAdvanced", "Running_HoldingRifle", "correr_fuzil", "parado_arma", true],
	["MovementAdvanced", "Sneaking", "andar_furtivo", "parado", true],
	["MovementAdvanced", "Dodge_Left", "esquiva_esq", "parado", false],
	["MovementAdvanced", "Dodge_Right", "esquiva_dir", "parado", false],
	["MovementAdvanced", "Dodge_Backward", "esquiva_tras", "parado", false],
	["MovementAdvanced", "Crawling", "rastejar", "parado", true],
	["MovementBasic", "Walking_A", "andar_kk", "parado", true],
	# armas de fogo
	["CombatRanged", "Ranged_2H_Aiming", "mirar_fuzil", "parado_arma", true],
	["CombatRanged", "Ranged_2H_Shoot", "atirar_fuzil", "parado_arma", false],
	["CombatRanged", "Ranged_2H_Reload", "recarregar_fuzil", "parado_arma", false],
	["CombatRanged", "Ranged_1H_Reload", "recarregar_pistola_kk", "parado_arma", false],
	["CombatRanged", "Ranged_1H_Aiming", "mirar_pistola_kk", "parado_arma", true],
	# corpo a corpo
	["CombatMelee", "Melee_2H_Attack_Chop", "golpe_2m", "parado_arma", false],
	["CombatMelee", "Melee_2H_Attack_Slice", "golpe_2m_lado", "parado_arma", false],
	["CombatMelee", "Melee_2H_Idle", "parado_2m", "parado_arma", true],
	["CombatMelee", "Melee_1H_Attack_Slice_Horizontal", "golpe_1m", "parado_arma", false],
	["CombatMelee", "Melee_1H_Attack_Slice_Diagonal", "golpe_1m_diag", "parado_arma", false],
	["CombatMelee", "Melee_1H_Attack_Stab", "facada", "parado_arma", false],
	["CombatMelee", "Melee_Unarmed_Attack_Kick", "chute", "parado", false],
	["CombatMelee", "Melee_Block", "bloquear", "parado", false],
	# geral
	["General", "PickUp", "pegar_chao", "parado", false],
	["General", "Use_Item", "usar_item", "parado", false],
	["General", "Hit_A", "levar_golpe_a", "parado", false],
	["General", "Hit_B", "levar_golpe_b", "parado", false],
	["General", "Death_A", "morrer_a", "parado", false],
	["General", "Death_B", "morrer_b", "parado", false],
	["General", "Throw", "arremessar", "parado", false],
	["General", "Interact", "interagir_kk", "parado", false],
	["General", "Idle_B", "parado_olhar", "parado", true],
	["Tools", "Lockpicking", "arrombar", "parado", true],
	["Simulation", "Waving", "acenar", "parado", true],
	["Simulation", "Sit_Floor_Down", "sentar_chao", "parado", false],
	["Simulation", "Sit_Floor_Idle", "sentado_chao", "parado", true],
	["Simulation", "Sit_Floor_StandUp", "levantar_chao", "parado", false],
	["Simulation", "Lie_Idle", "deitado", "parado", true],
]

# animações do próprio esqueleto do jogo (Quaternius UAL1/UAL2, glb): entram direto, só com nome novo
# [arquivo, animação, nome no jogo, laço]
const DIRETAS := [
	["res://m/ual1ue.fbx", "Pistol_Reload", "recarregar_pistola", false],
	["res://m/ual1ue.fbx", "Punch_Cross", "soco_cruzado", false],
	["res://m/ual1ue.fbx", "Hit_Head", "levar_golpe_cabeca", false],
	["res://m/ual1ue.fbx", "Idle_Torch_Loop", "parado_lanterna", true],
	["res://m/ual1ue.fbx", "Idle_Talking_Loop", "conversar", true],
	["res://m/ual1ue.fbx", "Sitting_Idle_Loop", "sentado", true],
	["res://m/ual1ue.fbx", "Sitting_Enter", "sentar", false],
	["res://m/ual1ue.fbx", "Sitting_Exit", "levantar", false],
	["res://m/ual1ue.fbx", "Sitting_Talking_Loop", "sentado_conversa", true],
	["res://m/ual1ue.fbx", "Driving_Loop", "dirigindo", true],
	["res://m/ual1ue.fbx", "Fixing_Kneeling", "consertar", true],
	["res://m/ual1ue.fbx", "Push_Loop", "empurrar", true],
	["res://m/ual1ue.fbx", "Sword_Attack", "golpe_espada", false],
	["res://m/ual1ue.fbx", "Walk_Formal_Loop", "andar_calmo", true],
	["res://m/ual1ue.fbx", "Jog_Fwd_Loop", "trote", true],
	["res://m/ual1ue.fbx", "Pistol_Aim_Up", "mirar_cima", true],
	["res://m/ual1ue.fbx", "Pistol_Aim_Down", "mirar_baixo", true],
	["res://m/ual2.glb", "Consume", "consumir", false],
	["res://m/ual2.glb", "Chest_Open", "abrir_bau", false],
	["res://m/ual2.glb", "Melee_Hook", "soco_gancho", false],
	["res://m/ual2.glb", "Sword_Regular_A", "golpe_1m_a", false],
	["res://m/ual2.glb", "Sword_Regular_B", "golpe_1m_b", false],
	["res://m/ual2.glb", "TreeChopping_Loop", "machadada", true],
	["res://m/ual2.glb", "Hit_Knockback", "empurrado", false],
	["res://m/ual2.glb", "LayToIdle", "levantar_do_chao", false],
	["res://m/ual2.glb", "Idle_FoldArms_Loop", "bracos_cruzados", true],
	["res://m/ual2.glb", "Idle_TalkingPhone_Loop", "falar_radio", true],
	["res://m/ual2.glb", "Idle_Lantern_Loop", "segurar_lanterna", true],
	["res://m/ual2.glb", "Walk_Carry_Loop", "andar_carregando", true],
	["res://m/ual2.glb", "OverhandThrow", "arremesso_alto", false],
	["res://m/ual2.glb", "Yes", "sim", false],
	["res://m/ual2.glb", "Idle_No_Loop", "nao", true],
	["res://m/ual2.glb", "ClimbUp_1m", "escalar", false],
	["res://m/ual2.glb", "Slide_Loop", "deslizar", true],
]

var sk_u: Skeleton3D
var base: AnimationLibrary

func _initialize():
	var saida := OS.get_environment("SAIDA")
	var nu: Node = load("res://m/ual2.glb").instantiate()
	sk_u = nu.find_children("*", "Skeleton3D", true, false)[0]
	base = load("res://m/anims_jogo.res")
	var lib := base.duplicate(true) as AnimationLibrary
	var cache := {}
	for c in CONVERTER:
		var arq := "res://kk/Rig_Medium_%s.glb" % c[0]
		if not cache.has(arq):
			cache[arq] = load(arq).instantiate()
		var nk: Node = cache[arq]
		var sk_k: Skeleton3D = nk.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = nk.find_children("*", "AnimationPlayer", true, false)[0]
		var nome_kk := ""
		for n in ap.get_animation_list():
			if String(n) == c[1] or String(n) == c[1] + "_Medium":
				nome_kk = n
		if nome_kk == "":
			print("NÃO ACHEI ", c[1])
			continue
		var a := converter(sk_k, ap.get_animation(nome_kk), c[3], c[4])
		if lib.has_animation(c[2]):
			lib.remove_animation(c[2])
		lib.add_animation(c[2], a)
		print(c[2], " <- ", nome_kk, " (", snappedf(a.length, 0.01), " s)")
	for d in DIRETAS:
		if not cache.has(d[0]):
			cache[d[0]] = load(d[0]).instantiate()
		var apd: AnimationPlayer = (cache[d[0]] as Node).find_children("*", "AnimationPlayer", true, false)[0]
		var nd: String = d[1]
		var fbx: bool = String(d[0]).ends_with(".fbx")
		if fbx:
			nd = "Rig|" + nd
		if not apd.has_animation(nd):
			nd = nd.trim_suffix("_Loop")
		if not apd.has_animation(nd):
			print("NÃO ACHEI ", d[1]); continue
		var a2: Animation = apd.get_animation(nd).duplicate(true)
		var rx := Quaternion(Vector3.RIGHT, -PI / 2.0)
		for i in a2.get_track_count():
			var cam := String(a2.track_get_path(i))
			var osso := cam.get_slice(":", 1)
			a2.track_set_path(i, NodePath("Armature/Skeleton3D:" + osso))
			if fbx:
				# o FBX do UAL1 (nomes da Unreal) vem em centímetros e com a raiz deitada (igual a preparar_jogador.gd)
				for kk in a2.track_get_key_count(i):
					var v = a2.track_get_key_value(i, kk)
					if a2.track_get_type(i) == Animation.TYPE_POSITION_3D:
						v = v * 100.0
						if osso == "root":
							v = rx * v
						a2.track_set_key_value(i, kk, v)
					elif a2.track_get_type(i) == Animation.TYPE_ROTATION_3D and osso == "root":
						a2.track_set_key_value(i, kk, rx * v)
		a2.loop_mode = Animation.LOOP_LINEAR if d[3] else Animation.LOOP_NONE
		if lib.has_animation(d[2]):
			lib.remove_animation(d[2])
		lib.add_animation(d[2], a2)
	print("salvou ", ResourceSaver.save(lib, saida), " ", lib.get_animation_list().size(), " animações")
	quit()

# pose local (Transform3D) de cada osso do KayKit no tempo t
func pose_kk(sk: Skeleton3D, a: Animation, faixas: Dictionary, t: float) -> Array:
	var locais: Array = []
	for b in sk.get_bone_count():
		var tr := sk.get_bone_rest(b)
		var nome := sk.get_bone_name(b)
		var q := tr.basis.get_rotation_quaternion()
		var p := tr.origin
		if faixas.has(nome + ":r"):
			q = a.rotation_track_interpolate(faixas[nome + ":r"], t)
		if faixas.has(nome + ":p"):
			p = a.position_track_interpolate(faixas[nome + ":p"], t)
		locais.append(Transform3D(Basis(q), p))
	return globais(sk, locais)

func globais(sk: Skeleton3D, locais: Array) -> Array:
	var g: Array = []
	g.resize(locais.size())
	for b in sk.get_bone_count():
		var pai := sk.get_bone_parent(b)
		g[b] = locais[b] if pai < 0 else (g[pai] as Transform3D) * (locais[b] as Transform3D)
	return g

func converter(sk_k: Skeleton3D, a: Animation, nome_base: String, laco: bool) -> Animation:
	var fechar_bracos := 0.0 if nome_base == "parado_arma" else 18.0
	var faixas := {}
	for i in a.get_track_count():
		var cam := String(a.track_get_path(i))
		var osso := cam.get_slice(":", 1)
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			faixas[osso + ":r"] = i
		elif a.track_get_type(i) == Animation.TYPE_POSITION_3D:
			faixas[osso + ":p"] = i
	# pose T (repouso) dos dois
	var rest_k: Array = []
	for b in sk_k.get_bone_count():
		rest_k.append(sk_k.get_bone_rest(b))
	var gk_t := globais(sk_k, rest_k)
	var rest_u: Array = []
	for b in sk_u.get_bone_count():
		rest_u.append(sk_u.get_bone_rest(b))
	var gu_t := globais(sk_u, rest_u)
	var ik := {}
	for b in sk_k.get_bone_count():
		ik[sk_k.get_bone_name(b)] = b
	var hk := (gk_t[ik["hips"]] as Transform3D).origin.y
	var hu := (gu_t[sk_u.find_bone("pelvis")] as Transform3D).origin.y
	var escala := hu / maxf(hk, 0.001)
	# poses locais da animação base (dedos, pescoço, clavículas...)
	var ab: Animation = base.get_animation(nome_base)
	var local_base: Array = []
	for b in sk_u.get_bone_count():
		var tr: Transform3D = rest_u[b]
		var q := tr.basis.get_rotation_quaternion()
		var idx := ab.find_track(NodePath("Armature/Skeleton3D:" + sk_u.get_bone_name(b)), Animation.TYPE_ROTATION_3D)
		if idx >= 0:
			q = ab.rotation_track_interpolate(idx, 0.0)
		local_base.append(q)
	var novo := Animation.new()
	novo.length = a.length
	novo.loop_mode = Animation.LOOP_LINEAR if laco else Animation.LOOP_NONE
	var trilhas := {}
	for b in sk_u.get_bone_count():
		var t := novo.add_track(Animation.TYPE_ROTATION_3D)
		novo.track_set_path(t, NodePath("Armature/Skeleton3D:" + sk_u.get_bone_name(b)))
		trilhas[b] = t
	var tp := novo.add_track(Animation.TYPE_POSITION_3D)
	var pelvis := sk_u.find_bone("pelvis")
	novo.track_set_path(tp, NodePath("Armature/Skeleton3D:pelvis"))
	var por_u := {}
	for k in MAPA:
		if ik.has(k):
			por_u[sk_u.find_bone(MAPA[k])] = ik[k]
	var n := int(ceil(a.length * FPS)) + 1
	var p0 := Vector3.ZERO
	var deriva := Vector3.ZERO
	# deriva do quadril (anda para frente?): tira, a animação fica no lugar
	var gi := pose_kk(sk_k, a, faixas, 0.0)
	var gf := pose_kk(sk_k, a, faixas, a.length)
	deriva = Vector3((gf[ik["hips"]] as Transform3D).origin.x - (gi[ik["hips"]] as Transform3D).origin.x, 0,
		(gf[ik["hips"]] as Transform3D).origin.z - (gi[ik["hips"]] as Transform3D).origin.z)
	if not laco:
		deriva = Vector3.ZERO
	for f in n:
		var t := minf(f / FPS, a.length)
		var gk := pose_kk(sk_k, a, faixas, t)
		var gu: Array = []
		gu.resize(sk_u.get_bone_count())
		for b in sk_u.get_bone_count():
			var pai := sk_u.get_bone_parent(b)
			var gpai: Basis = (gu[pai] as Basis) if pai >= 0 else Basis.IDENTITY
			var bas: Basis
			if por_u.has(b):
				var bk: int = por_u[b]
				var delta: Basis = (gk[bk] as Transform3D).basis.orthonormalized() * (gk_t[bk] as Transform3D).basis.orthonormalized().inverse()
				bas = delta * (gu_t[b] as Transform3D).basis.orthonormalized()
				if fechar_bracos > 0.0 and sk_u.get_bone_name(b) in ["upperarm_l", "upperarm_r"]:
					# o KayKit anda com os braços bem abertos (personagem cabeçudo); aqui fecham um pouco
					var lado := 1.0 if sk_u.get_bone_name(b).ends_with("_l") else -1.0
					bas = Basis(Vector3(0, 0, 1), -lado * deg_to_rad(fechar_bracos)) * bas
			else:
				bas = gpai * Basis(local_base[b] as Quaternion)
			gu[b] = bas
			var loc: Basis = gpai.inverse() * bas
			novo.rotation_track_insert_key(trilhas[b], t, loc.get_rotation_quaternion())
		# quadril: deslocamento em relação à pose T, na escala do jogo (sem a deriva para frente)
		var dk: Vector3 = (gk[ik["hips"]] as Transform3D).origin - (gk_t[ik["hips"]] as Transform3D).origin - deriva * (t / maxf(a.length, 0.001))
		var pos_u: Vector3 = (gu_t[pelvis] as Transform3D).origin + dk * escala
		var pai_p := sk_u.get_bone_parent(pelvis)
		if pai_p >= 0:
			pos_u = (gu_t[pai_p] as Transform3D).affine_inverse() * pos_u
		novo.position_track_insert_key(tp, t, pos_u)
	return novo
