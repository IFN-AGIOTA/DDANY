extends SceneTree
# MEDE A VELOCIDADE DE VERDADE de cada animação de andar/correr (para os pés não "patinarem" no chão): toca a
# animação no esqueleto do personagem e vê quanto o pé que está APOIADO (o mais baixo) anda para trás por segundo.
# O resultado vai para a tabela REF do jogador/animador_modelo.gd (velocidade em que cada animação casa com o chão).
# NÃO roda dentro do jogo:  godot --headless -s ferramentas/medir_passos.gd
const ANIMS := ["andar_lado_esq", "andar_lado_dir", "andar", "andar_lento", "andar_normal", "andar_rapido", "trote", "correr", "correr_fuzil",
	"andar_agachado", "andar_espreita", "mancar", "andar_tras", "correr_dir", "correr_esq"]
const FPS := 60.0

func _initialize():
	var corpo: Node3D = load("res://jogador/sobrevivente/corpo.scn").instantiate()
	var sk: Skeleton3D = corpo.find_children("*", "Skeleton3D", true, false)[0]
	var arq := OS.get_environment("LIB")
	var lib: AnimationLibrary = load(arq if arq != "" else "res://jogador/sobrevivente/animacoes.res")
	var pes := [sk.find_bone("ball_l"), sk.find_bone("ball_r")]
	for nome in ANIMS:
		if not lib.has_animation(nome):
			continue
		var an := lib.get_animation(nome)
		var n := int(an.length * FPS)
		var pos: Array = []
		for f in n + 1:
			var g := _globais(sk, an, f / FPS)
			pos.append([(g[pes[0]] as Transform3D).origin, (g[pes[1]] as Transform3D).origin])
		# pé APOIADO = na parte mais baixa do movimento dele (20% de baixo da altura que ele sobe). Em cada pé pega o
		# trecho seguido mais longo de apoio: o quanto o pé anda (para trás) nesse trecho / o tempo = velocidade
		var soma := Vector2.ZERO
		var nk := 0
		for k in 2:
			var mn := INF
			var mx := -INF
			for q in pos:
				mn = minf(mn, q[k].y)
				mx = maxf(mx, q[k].y)
			var lim := mn + (mx - mn) * 0.2 + 0.004
			var melhor := [0, 0]
			var ini := -1
			for f in pos.size():
				var baixo: bool = pos[f][k].y < lim
				if baixo and ini < 0:
					ini = f
				if (not baixo or f == pos.size() - 1) and ini >= 0:
					var fim := f if baixo else f - 1
					if fim - ini > melhor[1] - melhor[0]:
						melhor = [ini, fim]
					ini = -1
			if melhor[1] - melhor[0] >= 3:
				var d: Vector3 = pos[melhor[1]][k] - pos[melhor[0]][k]
				soma -= Vector2(d.x, d.z) / ((melhor[1] - melhor[0]) / FPS)
				nk += 1
		var v := soma / maxf(nk, 1)
		print("%-16s %.2f m/s  (direção x=%.2f z=%.2f)" % [nome, v.length(), v.x, v.y])
	quit()

# posições no espaço do esqueleto (FK pelas trilhas da animação; ossos sem trilha ficam no repouso)
func _globais(sk: Skeleton3D, a: Animation, t: float) -> Array:
	var g: Array = []
	g.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		var caminho := NodePath("Armature/Skeleton3D:" + sk.get_bone_name(b))
		var r := sk.get_bone_rest(b)
		var q := r.basis.get_rotation_quaternion()
		var o := r.origin
		var ir := a.find_track(caminho, Animation.TYPE_ROTATION_3D)
		if ir >= 0:
			q = a.rotation_track_interpolate(ir, t)
		var ip := a.find_track(caminho, Animation.TYPE_POSITION_3D)
		if ip >= 0:
			o = a.position_track_interpolate(ip, t)
		var l := Transform3D(Basis(q), o)
		var pai := sk.get_bone_parent(b)
		g[b] = l if pai < 0 else (g[pai] as Transform3D) * l
	return g
