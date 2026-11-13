extends SceneTree
# 1.12 · BIBLIOTECA DE POSES DO MOVIMENTO (para jogador/base_movimento.gd, o "motion matching" do jogo).
# Toca cada animação de locomoção do personagem (homem e mulher) e grava, a cada 1/30 s, onde estão os PÉS e para onde
# eles se movem (em relação ao quadril, no espaço do personagem). O jogo usa isso para, a cada troca, escolher o QUADRO
# da animação nova que continua o passo do jeito que ele está (pé de apoio, pé no ar), em vez de recomeçar do início.
# Saída: jogador/sobrevivente/base_movimento_m.json e base_movimento_f.json
#   godot --headless -s res://ferramentas/gerar_base_movimento.gd
# Rodar de novo sempre que mudar as animações de andar/correr (animacoes.res / animacoes_f.res).

const PASTA := "res://jogador/sobrevivente/"
const HZ := 30.0
# animação -> [direção (lado +direita, frente), velocidade em que os pés acompanham o chão (m/s)]
const CLIPES := {
	"parado": [Vector2(0, 0), 0.0], "agachado": [Vector2(0, 0), 0.0],
	"andar_lento": [Vector2(0, 1), 0.95], "andar_normal": [Vector2(0, 1), 1.6], "andar_rapido": [Vector2(0, 1), 1.95],
	"trote": [Vector2(0, 1), 3.35], "correr": [Vector2(0, 1), 6.4], "correr_fuzil": [Vector2(0, 1), 7.0],
	"andar_tras": [Vector2(0, -1), 0.75], "andar_lado_dir": [Vector2(1, 0), 0.5], "andar_lado_esq": [Vector2(-1, 0), 0.5],
	"andar_agachado": [Vector2(0, 1), 0.76], "mancar": [Vector2(0, 1), 0.8],
}
const OSSOS := ["foot_l", "foot_r"]

func _initialize():
	for sx in [["m", "corpo.scn", "animacoes.res"], ["f", "corpo_f.scn", "animacoes_f.res"]]:
		var corpo: Node3D = load(PASTA + sx[1]).instantiate()
		root.add_child(corpo)
		var sk: Skeleton3D = corpo.find_child("Skeleton3D", true, false)
		var ap := AnimationPlayer.new()
		corpo.add_child(ap)
		ap.root_node = NodePath("..")
		ap.add_animation_library("", load(PASTA + sx[2]))
		var ib := []
		for o in OSSOS:
			ib.append(sk.find_bone(o))
		var pelvis := sk.find_bone("pelvis")
		var saida := {"hz": HZ, "ossos": OSSOS, "clipes": {}}
		for nome in CLIPES:
			if not ap.has_animation(nome):
				print("FALTA ", nome)
				continue
			var a := ap.get_animation(nome)
			ap.play(nome)
			var n := maxi(2, int(round(a.length * HZ)))
			var pos := []
			for k in n + 1:
				ap.seek(minf(k / HZ, a.length), true)
				sk.force_update_all_bone_transforms()
				var p0 := sk.get_bone_global_pose(pelvis).origin
				var f := []
				for b in ib:
					var p: Vector3 = sk.get_bone_global_pose(b).origin
					f.append([p.x - p0.x, p.y, p.z - p0.z])
				pos.append(f)
			var quadros := []
			for k in n:
				# posição dos dois pés (3 + 3) e a velocidade deles por segundo de animação (3 + 3)
				var q := []
				for o in ib.size():
					q.append_array(pos[k][o])
				for o in ib.size():
					for e in 3:
						q.append((pos[k + 1][o][e] - pos[k][o][e]) * HZ)
				quadros.append(q.map(func(x): return snappedf(x, 0.0001)))
			saida["clipes"][nome] = {"dir": [CLIPES[nome][0].x, CLIPES[nome][0].y], "ref": CLIPES[nome][1],
				"duracao": a.length, "quadros": quadros}
			print(sx[0], " ", nome, " quadros ", quadros.size())
		var f := FileAccess.open(PASTA + "base_movimento_%s.json" % sx[0], FileAccess.WRITE)
		f.store_string(JSON.stringify(saida))
		f.close()
		corpo.queue_free()
	print("BASE PRONTA")
	quit()
