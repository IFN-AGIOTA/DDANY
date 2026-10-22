extends SceneTree
# CONVERTE CAPTURA DE MOVIMENTO REAL (banco da Carnegie Mellon University, CMU Graphics Lab Motion Capture Database,
# em BVH na conversão "MotionBuilder-friendly" de Bruce Hahne / cgspeed) para o esqueleto do personagem do jogo
# (jogador/sobrevivente/corpo.scn) e junta em jogador/sobrevivente/animacoes.res (nomes em português, tabela CLIPES).
# Licença dos dados: livre para pesquisa e uso comercial (só não pode revender os arquivos de captura como estão).
# Como funciona (igual a retarget_kaykit.gd): o quadro 0 de cada BVH da CMU é uma pose T; o personagem do jogo também
# está em pose T no repouso. Para cada osso mapeado (MAPA), a rotação "a mais" em relação à pose T, no mundo, vai para
# o osso equivalente. O quadril sobe/desce escalado pela altura do quadril. Dedos ficam como numa animação base do jogo.
# Locomoção: acha sozinha o trecho que fecha um ciclo de passos (começo ~ fim), vira o movimento para a frente do
# personagem, tira o avanço (a animação fica no lugar) e distribui o pequeno erro do laço para não "pular".
# NÃO roda dentro do jogo. Como usar (na pasta do jogo):
#   BVH=<pasta com os .bvh> SAIDA=<arquivo .res> godot --headless -s ferramentas/retarget_cmu.gd
#   MODO=analise BVH=<pasta> godot --headless -s ferramentas/retarget_cmu.gd   (só mostra duração e velocidade)
# Os .bvh: https://github.com/una-dinosauria/cmu-mocap (data/007/07_04.bvh ...) · índice: cmu-mocap-index-text.txt
const FPS := 30.0

# osso da CMU -> osso do jogo
const MAPA := {"Hips": "pelvis", "LowerBack": "spine_01", "Spine": "spine_02", "Spine1": "spine_03",
	"Neck": "neck_01", "Head": "Head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r"}

# [arquivo, nome no jogo, laço, de (s), até (s), ciclo mín (s), ciclo máx (s), base dos dedos, volta (s)]
# laço = true: procura dentro de [de, até] o melhor ciclo com duração entre mín e máx.
# laço = false: usa exatamente [de, até] e, se volta > 0, acrescenta esse tempo voltando à pose do começo.
const CLIPES := [
	# locomoção (laço)
	["07_04", "andar_lento", true, 0.5, 6.0, 1.9, 2.8, "parado", 0.0],          # devagar ~1 m/s
	["08_01", "andar_normal", true, 0.3, 3.5, 0.9, 1.4, "parado", 0.0],         # normal ~1,6 m/s
	["07_12", "andar_rapido", true, 0.3, 3.5, 0.8, 1.3, "parado", 0.0],         # apressado ~1,9 m/s
	["77_30", "andar_espreita", true, 0.5, 9.0, 1.4, 3.2, "parado", 0.0],       # agachado, com cuidado
	["77_19", "mancar", true, 0.5, 8.0, 1.1, 2.4, "parado", 0.0],               # perna machucada
	# ações (uma vez; o último número = segundos para voltar à pose do começo)
	["79_15", "comer", false, 0.4, 3.3, 0.0, 0.0, "parado", 0.5],
	["80_40", "beber", false, 1.4, 3.9, 0.0, 0.0, "parado", 0.35],
	["79_15", "tomar_remedio", false, 0.4, 1.7, 0.0, 0.0, "parado", 0.45],
]

var sk_u: Skeleton3D
var base: AnimationLibrary
var gu_t: Array = []           # globais do repouso do jogo
var rest_u: Array = []

func _initialize():
	var pasta := OS.get_environment("BVH")
	var nu: Node = load("res://jogador/sobrevivente/corpo.scn").instantiate()
	sk_u = nu.find_children("*", "Skeleton3D", true, false)[0]
	for b in sk_u.get_bone_count():
		rest_u.append(sk_u.get_bone_rest(b))
	gu_t = globais(sk_u.get_bone_count(), func(b): return sk_u.get_bone_parent(b), rest_u)
	base = load("res://jogador/sobrevivente/animacoes.res")
	if OS.get_environment("MODO") == "analise":
		for f in DirAccess.get_files_at(pasta):
			if f.ends_with(".bvh"):
				analisar(pasta.path_join(f))
		quit()
		return
	var lib := base.duplicate(true) as AnimationLibrary
	var so := OS.get_environment("SO")
	for c in CLIPES:
		if so != "" and not (c[1] in so.split(",")):
			continue
		var bvh := ler_bvh(pasta.path_join(c[0] + ".bvh"))
		if bvh.is_empty():
			print("NÃO ACHEI ", c[0]); continue
		var a := converter(bvh, c)
		if lib.has_animation(c[1]):
			lib.remove_animation(c[1])
		lib.add_animation(c[1], a)
	var saida := OS.get_environment("SAIDA")
	print("salvou ", ResourceSaver.save(lib, saida), " ", lib.get_animation_list().size(), " animações -> ", saida)
	quit()

# ---------- BVH ----------
func ler_bvh(arq: String) -> Dictionary:
	var f := FileAccess.open(arq, FileAccess.READ)
	if f == null:
		return {}
	var nomes: Array = []
	var pais: Array = []
	var offs: Array = []
	var canais: Array = []           # por junta: ["Zrotation", ...]
	var pilha: Array = []
	var ult := -1
	var quadros: Array = []
	var dt := 1.0 / 120.0
	var em_movimento := false
	var fim_site := false
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "":
			continue
		if em_movimento:
			if l.begins_with("Frames:"):
				continue
			if l.begins_with("Frame Time:"):
				dt = float(l.get_slice(":", 1))
				continue
			quadros.append(PackedFloat32Array(Array(l.split_floats(" ", false))))
			continue
		var p := l.split(" ", false)
		match p[0]:
			"ROOT", "JOINT":
				nomes.append(p[1])
				pais.append(pilha.back() if not pilha.is_empty() else -1)
				offs.append(Vector3.ZERO)
				canais.append([])
				ult = nomes.size() - 1
			"End":
				fim_site = true
			"{":
				pilha.append(ult if not fim_site else -2)
			"}":
				pilha.pop_back()
				fim_site = false
			"OFFSET":
				if not fim_site:
					offs[ult] = Vector3(float(p[1]), float(p[2]), float(p[3]))
			"CHANNELS":
				canais[ult] = p.slice(2)
			"MOTION":
				em_movimento = true
	# a pilha guarda -2 dentro de "End Site": conserta os pais (o pai real é o último índice >= 0)
	return {"nomes": nomes, "pais": pais, "offs": offs, "canais": canais, "quadros": quadros, "dt": dt}

# locais (Transform3D) de todas as juntas no quadro (com interpolação entre quadros)
func locais_bvh(bvh: Dictionary, t: float) -> Array:
	var q: Array = bvh["quadros"]
	var fq := t / float(bvh["dt"])
	var i0 := clampi(int(floor(fq)), 0, q.size() - 1)
	var i1 := mini(i0 + 1, q.size() - 1)
	var w := clampf(fq - i0, 0.0, 1.0)
	var l0 := _locais_quadro(bvh, q[i0])
	if i1 == i0 or w < 0.001:
		return l0
	var l1 := _locais_quadro(bvh, q[i1])
	var out: Array = []
	for j in l0.size():
		var a: Transform3D = l0[j]
		var b: Transform3D = l1[j]
		out.append(Transform3D(Basis(a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), w)), a.origin.lerp(b.origin, w)))
	return out

func _locais_quadro(bvh: Dictionary, v: PackedFloat32Array) -> Array:
	var out: Array = []
	var k := 0
	for j in (bvh["nomes"] as Array).size():
		var pos: Vector3 = bvh["offs"][j]
		var rot := Basis.IDENTITY
		for c in bvh["canais"][j]:
			var x := v[k]
			k += 1
			match String(c):
				"Xposition": pos.x = x
				"Yposition": pos.y = x
				"Zposition": pos.z = x
				"Xrotation": rot = rot * Basis(Vector3.RIGHT, deg_to_rad(x))
				"Yrotation": rot = rot * Basis(Vector3.UP, deg_to_rad(x))
				"Zrotation": rot = rot * Basis(Vector3.BACK, deg_to_rad(x))
		out.append(Transform3D(rot, pos))
	return out

func globais_bvh(bvh: Dictionary, t: float) -> Array:
	return globais((bvh["nomes"] as Array).size(), func(j): return bvh["pais"][j], locais_bvh(bvh, t))

func globais(n: int, pai_de: Callable, locais: Array) -> Array:
	var g: Array = []
	g.resize(n)
	for b in n:
		var pai: int = pai_de.call(b)
		g[b] = locais[b] if pai < 0 else (g[pai] as Transform3D) * (locais[b] as Transform3D)
	return g

func idx(bvh: Dictionary, nome: String) -> int:
	return (bvh["nomes"] as Array).find(nome)

func duracao(bvh: Dictionary) -> float:
	return ((bvh["quadros"] as Array).size() - 1) * float(bvh["dt"])

# frente do corpo (no chão) pelos pés: direção média pé -> ponta do pé
func frente_pes(g: Array, pe_e: int, pt_e: int, pe_d: int, pt_d: int) -> Vector3:
	var v: Vector3 = ((g[pt_e] as Transform3D).origin - (g[pe_e] as Transform3D).origin) + ((g[pt_d] as Transform3D).origin - (g[pe_d] as Transform3D).origin)
	v.y = 0.0
	return v.normalized()

func girar_para_frente(dir: Vector3) -> Basis:
	# gira em Y para que dir vire +Z (a frente do personagem do jogo)
	return Basis(Vector3.UP, -atan2(dir.x, dir.z))

# ---------- análise ----------
func analisar(arq: String) -> void:
	var bvh := ler_bvh(arq)
	var d := duracao(bvh)
	var g0 := globais_bvh(bvh, 0.0)
	var h := idx(bvh, "Hips")
	var chao := minf((g0[idx(bvh, "LeftToeBase")] as Transform3D).origin.y, (g0[idx(bvh, "RightToeBase")] as Transform3D).origin.y)
	var alt := (g0[h] as Transform3D).origin.y - chao
	var escala := ((gu_t[sk_u.find_bone("pelvis")] as Transform3D).origin.y - 0.02) / alt
	# caminho percorrido pelo quadril (no chão), em trechos de 1 s: velocidade de cada trecho
	var vels: Array = []
	var t := 1.0 / 120.0
	var ant: Vector3 = (globais_bvh(bvh, t)[h] as Transform3D).origin
	while t + 0.25 <= d:
		t += 0.25
		var p: Vector3 = (globais_bvh(bvh, t)[h] as Transform3D).origin
		vels.append(snappedf(Vector2(p.x - ant.x, p.z - ant.z).length() * escala / 0.25, 0.1))
		ant = p
	print("%s: %.1f s · m/s a cada 0,25 s: %s" % [arq.get_file(), d, str(vels.slice(0, 48))])

# ---------- conversão ----------
func converter(bvh: Dictionary, c: Array) -> Animation:
	var laco: bool = c[2]
	var t0: float = maxf(c[3], 1.0 / 60.0)
	var t1: float = minf(c[4], duracao(bvh))
	var h := idx(bvh, "Hips")
	var pe_e := idx(bvh, "LeftFoot")
	var pt_e := idx(bvh, "LeftToeBase")
	var pe_d := idx(bvh, "RightFoot")
	var pt_d := idx(bvh, "RightToeBase")
	var nj := (bvh["nomes"] as Array).size()
	# amostra a 30 quadros/s
	var amostras: Array = []          # globais por quadro
	var tempos: Array = []
	var t := t0
	while t <= t1 + 0.0001:
		amostras.append(globais_bvh(bvh, t))
		tempos.append(t)
		t += 1.0 / FPS
	var ia := 0
	var ib := amostras.size() - 1
	if laco:
		var melhor := INF
		var lmin := int(round(float(c[5]) * FPS))
		var lmax := int(round(float(c[6]) * FPS))
		for i in amostras.size():
			for j in range(i + lmin, mini(i + lmax, amostras.size() - 1) + 1):
				var e := _diferenca(bvh, amostras[i], amostras[j], amostras[i + 1], amostras[mini(j + 1, amostras.size() - 1)])
				if e < melhor:
					melhor = e
					ia = i
					ib = j
		print("%s: ciclo %.2f..%.2f s (%.2f s) erro %.3f" % [c[1], tempos[ia], tempos[ib], tempos[ib] - tempos[ia], melhor])
	# pose T (quadro 0) da CMU e repouso do jogo, os dois virados para +Z
	var g_t := globais_bvh(bvh, 0.0)
	var a_t := girar_para_frente(frente_pes(g_t, pe_e, pt_e, pe_d, pt_d))
	var a_u := girar_para_frente(frente_pes(gu_t, sk_u.find_bone("foot_l"), sk_u.find_bone("ball_l"), sk_u.find_bone("foot_r"), sk_u.find_bone("ball_r")))
	# direção do movimento (locomoção) ou dos pés no começo (ações no lugar)
	var desl: Vector3 = (amostras[ib][h] as Transform3D).origin - (amostras[ia][h] as Transform3D).origin
	desl.y = 0.0
	var r := girar_para_frente(desl.normalized() if laco and desl.length() > 0.2 else frente_pes(amostras[ia], pe_e, pt_e, pe_d, pt_d))
	# altura do quadril -> escala
	var chao := minf((g_t[pt_e] as Transform3D).origin.y, (g_t[pt_d] as Transform3D).origin.y)
	# chão da animação: o ponto mais baixo das pontas dos pés no trecho (alguns arquivos têm a raiz deslocada no quadro 0)
	var chao_anim := INF
	for g in amostras:
		chao_anim = minf(chao_anim, minf((g[pt_e] as Transform3D).origin.y, (g[pt_d] as Transform3D).origin.y))
	var pelvis := sk_u.find_bone("pelvis")
	var escala := ((gu_t[pelvis] as Transform3D).origin.y - 0.02) / ((g_t[h] as Transform3D).origin.y - chao)
	# dedos/ossos sem par: pose local da animação base do jogo
	var ab: Animation = base.get_animation(c[7])
	var local_base: Array = []
	for b in sk_u.get_bone_count():
		var q := (rest_u[b] as Transform3D).basis.get_rotation_quaternion()
		var it := ab.find_track(NodePath("Armature/Skeleton3D:" + sk_u.get_bone_name(b)), Animation.TYPE_ROTATION_3D)
		if it >= 0:
			q = ab.rotation_track_interpolate(it, 0.0)
		local_base.append(q)
	var por_u := {}
	for k in MAPA:
		var jk := idx(bvh, k)
		if jk >= 0:
			por_u[sk_u.find_bone(MAPA[k])] = jk
	var n := ib - ia + 1
	var dur: float = tempos[ib] - tempos[ia]
	# quadril: centro horizontal médio do trecho (sem o avanço)
	var p_ini: Vector3 = (amostras[ia][h] as Transform3D).origin
	var avanco: Vector3 = desl if laco else Vector3.ZERO
	var locais_q: Array = []          # [quadro][osso] Quaternion
	var pos_q: Array = []
	var media := Vector3.ZERO
	for f in n:
		var g: Array = amostras[ia + f]
		var gu: Array = []
		gu.resize(sk_u.get_bone_count())
		var lq: Array = []
		lq.resize(sk_u.get_bone_count())
		for b in sk_u.get_bone_count():
			var pai := sk_u.get_bone_parent(b)
			var gpai: Basis = (gu[pai] as Basis) if pai >= 0 else Basis.IDENTITY
			var bas: Basis
			if por_u.has(b):
				var jk: int = por_u[b]
				var ga: Basis = r * (g[jk] as Transform3D).basis.orthonormalized()
				var gt: Basis = a_t * (g_t[jk] as Transform3D).basis.orthonormalized()
				var delta: Basis = ga * gt.inverse()
				bas = a_u.inverse() * delta * a_u * (gu_t[b] as Transform3D).basis.orthonormalized()
			else:
				bas = gpai * Basis(local_base[b] as Quaternion)
			gu[b] = bas
			lq[b] = (gpai.inverse() * bas).get_rotation_quaternion()
		locais_q.append(lq)
		var dk: Vector3 = (g[h] as Transform3D).origin - p_ini - avanco * (float(f) / maxf(n - 1, 1))
		dk = r * dk
		var y := ((g[h] as Transform3D).origin.y - chao_anim) - ((g_t[h] as Transform3D).origin.y - chao)
		var p := Vector3(dk.x, 0.0, dk.z) * escala
		media += p
		pos_q.append(Vector3(p.x, y * escala, p.z))
	media /= float(n)
	var volta: float = c[8]
	if not laco and volta > 0.0:
		var nv := int(round(volta * FPS))
		var q_fim: Array = locais_q[n - 1]
		var p_fim: Vector3 = pos_q[n - 1]
		for k in range(1, nv + 1):
			var w := smoothstep(0.0, 1.0, float(k) / nv)
			var lq: Array = []
			for b in sk_u.get_bone_count():
				lq.append((q_fim[b] as Quaternion).slerp(locais_q[0][b], w))
			locais_q.append(lq)
			pos_q.append(p_fim.lerp(pos_q[0], w))
		n += nv
		dur += nv / FPS
	var novo := Animation.new()
	novo.length = dur
	novo.loop_mode = Animation.LOOP_LINEAR if laco else Animation.LOOP_NONE
	var trilhas := {}
	for b in sk_u.get_bone_count():
		var tr := novo.add_track(Animation.TYPE_ROTATION_3D)
		novo.track_set_path(tr, NodePath("Armature/Skeleton3D:" + sk_u.get_bone_name(b)))
		trilhas[b] = tr
	var tp := novo.add_track(Animation.TYPE_POSITION_3D)
	novo.track_set_path(tp, NodePath("Armature/Skeleton3D:pelvis"))
	var pai_p := sk_u.get_bone_parent(pelvis)
	var ultimo := n - 1 if laco else n           # no laço o último quadro = o primeiro (não grava)
	for f in ultimo:
		var tt := f / FPS
		var w := float(f) / maxf(n - 1, 1)
		for b in sk_u.get_bone_count():
			var q: Quaternion = locais_q[f][b]
			if laco:
				# distribui a diferença fim -> começo ao longo do ciclo (o laço fecha sem pulo)
				var erro: Quaternion = (locais_q[n - 1][b] as Quaternion).inverse() * (locais_q[0][b] as Quaternion)
				q = q * Quaternion.IDENTITY.slerp(erro, w)
			novo.rotation_track_insert_key(trilhas[b], tt, q.normalized())
		var pv: Vector3 = pos_q[f] - Vector3(media.x, 0, media.z)
		if laco:
			pv += ((pos_q[0] as Vector3) - (pos_q[n - 1] as Vector3)) * Vector3(0, 1, 0) * w
		var pos_u: Vector3 = (gu_t[pelvis] as Transform3D).origin + a_u.inverse() * pv
		if pai_p >= 0:
			pos_u = (gu_t[pai_p] as Transform3D).affine_inverse() * pos_u
		novo.position_track_insert_key(tp, tt, pos_u)
	print("%s <- %s (%.2f s, %d quadros)" % [c[1], c[0], dur, ultimo])
	return novo

# quanto duas poses (e o jeito que estão se mexendo) diferem: rotações locais das pernas, braços e tronco
func _diferenca(bvh: Dictionary, ga: Array, gb: Array, ga2: Array, gb2: Array) -> float:
	var e := 0.0
	for nome in ["LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "Spine"]:
		var j := idx(bvh, nome)
		var pai: int = bvh["pais"][j]
		var la: Basis = (ga[pai] as Transform3D).basis.inverse() * (ga[j] as Transform3D).basis
		var lb: Basis = (gb[pai] as Transform3D).basis.inverse() * (gb[j] as Transform3D).basis
		e += la.get_rotation_quaternion().angle_to(lb.get_rotation_quaternion())
		var la2: Basis = (ga2[pai] as Transform3D).basis.inverse() * (ga2[j] as Transform3D).basis
		var lb2: Basis = (gb2[pai] as Transform3D).basis.inverse() * (gb2[j] as Transform3D).basis
		e += 0.5 * la2.get_rotation_quaternion().angle_to(lb2.get_rotation_quaternion())
	return e
