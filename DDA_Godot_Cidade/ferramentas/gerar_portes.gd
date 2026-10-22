extends SceneTree
# GERA AS POSTURAS DE "PORTE" DAS ARMAS (como o personagem SEGURA cada tipo de arma andando/parado, sem mirar) e
# junta em jogador/sobrevivente/animacoes.res. O jogo toca essas posturas só nos BRAÇOS, por cima de qualquer
# caminhada (jogador/camada_postura.gd), então valem para parado, andando, agachado e trotando.
# Cada postura parte da animação "parado" (respiração) e põe a ARMA num lugar do corpo (PORTES: empunhadura,
# direção do cano/lâmina, "cima" da arma); a mão direita vai até a empunhadura por IK de dois ossos (braço +
# antebraço, cotovelo puxado para o "polo") e gira para a arma apontar para onde foi pedido. A mão esquerda vai
# para o seu lugar na arma (apoio da pistola, cabo do taco...) ou fica como na animação base.
# O encaixe da arma na mão é o mesmo do jogo (jogador/modelo_sobrevivente.gd _criar_ponto_arma: medido na pose
# "mirar", cano para +Z). Espaço do esqueleto: frente = +Z, cima = +Y, ESQUERDA do personagem = +X.
# NÃO roda dentro do jogo. Como usar (na pasta do jogo):
#   ENTRA=<animacoes.res> SAIDA=<arquivo .res> godot --headless -s ferramentas/gerar_portes.gd
const FPS := 30.0

# nome: {mao: empunhadura da mão direita (m), cano: direção da arma (ou derivada das duas mãos), cima: "cima" da
#        arma, polo_d / polo_e: para onde vão os cotovelos, esq: ponto da mão esquerda na arma (m, absoluto),
#        sentido: 1 = a arma vai da mão direita PARA a esquerda (lança), -1 = vai para o lado contrário (taco),
#        palma_esq / dedos_esq: orientação da mão esquerda (dedos_esq vazio = abraça o cabo)}
# O braço do personagem alcança ~0,5 m do ombro ao punho (ombros em x ±0,18, y 1,43, z -0,15 na pose "parado").
const PORTES := {
	# pistola baixa, nas duas mãos, cano para a frente e para baixo (posição de "pronto")
	"porte_pistola": {"mao": Vector3(-0.05, 1.1, 0.24), "cano": Vector3(0.1, -0.6, 0.8), "cima": Vector3(0, 1, 0.3),
		"polo_d": Vector3(-0.9, -0.6, -0.4), "esq": Vector3(0.0, 1.07, 0.21), "polo_e": Vector3(0.9, -0.7, -0.3),
		"palma_esq": Vector3(-0.7, 0.5, 0.0), "dedos_esq": Vector3(-0.3, -0.5, 0.8)},
	# faca/facão/pé de cabra: uma mão, na frente do quadril direito, ponta para a frente e um pouco para cima
	"porte_branca": {"mao": Vector3(-0.18, 1.02, 0.22), "cano": Vector3(0.15, 0.3, 0.94), "cima": Vector3(0, 1, 0),
		"polo_d": Vector3(-0.9, -0.5, -0.3)},
	# taco/machado/cano/lança: duas mãos no cabo na frente do peito, cabeça para cima e para a direita (pronto para bater)
	"porte_2m": {"mao": Vector3(-0.08, 1.2, 0.17), "esq": Vector3(0.0, 1.08, 0.15), "sentido": -1.0, "cima": Vector3(0, 0, 1),
		"polo_d": Vector3(-0.9, -0.7, -0.2), "polo_e": Vector3(0.8, -0.8, 0.0)},
}

var sk: Skeleton3D
var ap: AnimationPlayer
var corpo: Node3D

func _initialize():
	var lib: AnimationLibrary = load(OS.get_environment("ENTRA")).duplicate(true)
	corpo = load("res://jogador/sobrevivente/corpo.scn").instantiate()
	root.add_child(corpo)
	sk = corpo.find_children("*", "Skeleton3D", true, false)[0]
	for a in corpo.find_children("*", "AnimationPlayer", true, false):
		a.free()
	ap = AnimationPlayer.new()
	corpo.add_child(ap)
	ap.root_node = ap.get_path_to(corpo)
	ap.add_animation_library("", lib)
	# encaixe da arma na mão direita (igual a modelo_sobrevivente.gd): na pose "mirar" a arma tem a base identidade
	var hr := sk.find_bone("hand_r")
	var gh := _pose_global(lib.get_animation("mirar"), 0.4)[hr] as Transform3D
	var palma := gh.origin + gh.basis.y.normalized() * 0.07 - gh.basis.z.normalized() * 0.01
	var ponto := gh.affine_inverse() * Transform3D(Basis.IDENTITY, palma)     # arma no espaço da mão
	# eixos reais da mão esquerda (igual a ik_fuzil.gd): palma para baixo e dedos para o dedo médio na pose T
	var hl := sk.find_bone("hand_l")
	var gm := sk.get_bone_global_rest(hl)
	var med := sk.find_bone("middle_01_l")
	var dedos_g := (sk.get_bone_global_rest(med).origin - gm.origin).normalized()
	var palma_g := (Vector3.DOWN - dedos_g * Vector3.DOWN.dot(dedos_g)).normalized()
	var inv := gm.basis.orthonormalized().inverse()
	var dl := (inv * dedos_g).normalized()
	var pl := (inv * palma_g).normalized()
	var mao_esq_local := Basis(pl, dl, pl.cross(dl))
	var base: Animation = lib.get_animation("parado")
	var empunhar: Animation = lib.get_animation("parado_arma")        # dedos fechados segurando
	for nome in PORTES:
		var p: Dictionary = PORTES[nome]
		var novo := Animation.new()
		novo.length = base.length
		novo.loop_mode = Animation.LOOP_LINEAR
		var trilhas := {}
		for b in sk.get_bone_count():
			var t := novo.add_track(Animation.TYPE_ROTATION_3D)
			novo.track_set_path(t, NodePath("Armature/Skeleton3D:" + sk.get_bone_name(b)))
			trilhas[b] = t
		var n := int(round(base.length * FPS))
		for f in n:
			var tt := f / FPS
			var loc := _locais(base, tt)
			# dedos: segurando (da pose de empunhar a pistola)
			for b in sk.get_bone_count():
				var bn := sk.get_bone_name(b)
				var dedo := false
				for d in ["index", "middle", "pinky", "ring", "thumb"]:
					if bn.begins_with(d):
						dedo = true
				if dedo and (bn.ends_with("_r") or p.has("esq")):
					loc[b] = _rot_local(empunhar, b, 0.0)
			var g := _globais(loc, base, tt)
			# arma no lugar pedido
			var z: Vector3
			if p.has("cano"):
				z = (p["cano"] as Vector3).normalized()
			else:
				z = (((p["esq"] as Vector3) - (p["mao"] as Vector3)) * float(p["sentido"])).normalized()
			var x: Vector3 = (p["cima"] as Vector3).cross(z).normalized()
			var arma := Transform3D(Basis(x, z.cross(x), z), p["mao"])
			var mao_d := arma * ponto.affine_inverse()
			_ik(loc, g, "upperarm_r", "lowerarm_r", "hand_r", mao_d.origin, p["polo_d"], mao_d.basis, base, tt)
			if p.has("esq"):
				g = _globais(loc, base, tt)
				var alvo_e: Vector3 = p["esq"]
				var pe: Vector3
				var de: Vector3
				if p.has("dedos_esq"):
					pe = (p["palma_esq"] as Vector3).normalized()
					de = p["dedos_esq"]
				else:
					# abraça o cabo: palma virada para o cabo (para a direita), dedos em volta, para baixo
					pe = Vector3(-1, 0, 0)
					pe = (pe - z * pe.dot(z)).normalized()
					de = z.cross(pe)
					if de.y > 0.0:
						de = -de
				de = (de - pe * de.dot(pe)).normalized()
				var bas_e := Basis(pe, de, pe.cross(de)) * mao_esq_local.inverse()
				var punho := alvo_e - de * 0.07 - pe * 0.03       # o punho fica atrás do meio da palma
				_ik(loc, g, "upperarm_l", "lowerarm_l", "hand_l", punho, p["polo_e"], bas_e, base, tt)
			if f == 0:
				var gf := _globais(loc, base, tt)
				var am: Transform3D = (gf[sk.find_bone("hand_r")] as Transform3D) * ponto
				print("  %s: empunhadura %s (pedido %s) · cano %s (pedido %s) · mão esq %s · ombro d %s" % [nome,
					am.origin.snapped(Vector3.ONE * 0.01), p["mao"], am.basis.z.normalized().snapped(Vector3.ONE * 0.01), z.snapped(Vector3.ONE * 0.01),
					(gf[sk.find_bone("hand_l")] as Transform3D).origin.snapped(Vector3.ONE * 0.01), (gf[sk.find_bone("upperarm_r")] as Transform3D).origin.snapped(Vector3.ONE * 0.01)])
			for b in sk.get_bone_count():
				novo.rotation_track_insert_key(trilhas[b], tt, (loc[b] as Quaternion).normalized())
		if lib.has_animation(nome):
			lib.remove_animation(nome)
		lib.add_animation(nome, novo)
		print(nome, " (", snappedf(novo.length, 0.01), " s)")
	var saida := OS.get_environment("SAIDA")
	print("salvou ", ResourceSaver.save(lib, saida), " -> ", saida)
	quit()

func _rot_local(a: Animation, b: int, t: float) -> Quaternion:
	var i := a.find_track(NodePath("Armature/Skeleton3D:" + sk.get_bone_name(b)), Animation.TYPE_ROTATION_3D)
	if i >= 0:
		return a.rotation_track_interpolate(i, t)
	return sk.get_bone_rest(b).basis.get_rotation_quaternion()

func _locais(a: Animation, t: float) -> Array:
	var out: Array = []
	for b in sk.get_bone_count():
		out.append(_rot_local(a, b, t))
	return out

func _globais(loc: Array, a: Animation, t: float) -> Array:
	var g: Array = []
	g.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		var o := sk.get_bone_rest(b).origin
		var ip := a.find_track(NodePath("Armature/Skeleton3D:" + sk.get_bone_name(b)), Animation.TYPE_POSITION_3D)
		if ip >= 0:
			o = a.position_track_interpolate(ip, t)
		var l := Transform3D(Basis(loc[b] as Quaternion), o)
		var pai := sk.get_bone_parent(b)
		g[b] = l if pai < 0 else (g[pai] as Transform3D) * l
	return g

func _pose_global(a: Animation, t: float) -> Array:
	return _globais(_locais(a, t), a, t)

# IK de dois ossos: braço + antebraço chegam em "alvo" (posição do punho), cotovelo para o lado do polo;
# depois a mão fica com a base pedida (no espaço do esqueleto)
func _ik(loc: Array, g: Array, o1: String, o2: String, o3: String, alvo: Vector3, polo: Vector3, bas_mao: Basis, a: Animation, t: float) -> void:
	var b1 := sk.find_bone(o1)
	var b2 := sk.find_bone(o2)
	var b3 := sk.find_bone(o3)
	var s: Vector3 = (g[b1] as Transform3D).origin
	var l1 := sk.get_bone_rest(b2).origin.length()
	var l2 := sk.get_bone_rest(b3).origin.length()
	var v := alvo - s
	var d := clampf(v.length(), 0.05, (l1 + l2) * 0.999)
	var nn := v.normalized()
	var aa := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var hh := sqrt(maxf(l1 * l1 - aa * aa, 0.0))
	var pp := polo.normalized()
	pp = (pp - nn * pp.dot(nn)).normalized()
	var cotovelo := s + nn * aa + pp * hh
	var punho := s + nn * d
	# braço: gira a base global para o osso apontar para o cotovelo
	var g1: Basis = (g[b1] as Transform3D).basis.orthonormalized()
	var eixo1: Vector3 = (g1 * sk.get_bone_rest(b2).origin).normalized()
	var r1 := Basis(Quaternion(eixo1, (cotovelo - s).normalized()))
	var ng1 := r1 * g1
	var pai1 := sk.get_bone_parent(b1)
	var gp1: Basis = (g[pai1] as Transform3D).basis.orthonormalized()
	loc[b1] = (gp1.inverse() * ng1).get_rotation_quaternion()
	# antebraço
	var g2 := ng1 * Basis(loc[b2] as Quaternion)
	var eixo2: Vector3 = (g2 * sk.get_bone_rest(b3).origin).normalized()
	var r2 := Basis(Quaternion(eixo2, (punho - cotovelo).normalized()))
	var ng2 := r2 * g2
	loc[b2] = (ng1.inverse() * ng2).get_rotation_quaternion()
	# mão
	loc[b3] = (ng2.inverse() * bas_mao.orthonormalized()).get_rotation_quaternion()
