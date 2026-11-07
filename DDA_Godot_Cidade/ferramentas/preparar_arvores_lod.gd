extends SceneTree
# 1.21 · OS NÍVEIS DE DETALHE DAS ÁRVORES, no jeito da Unreal Engine 5 (estudos/ESTUDO_AAA.md 1.14). A partir dos
# modelos completos (mundo/arvores/modelos/<nome>.res, do ferramentas/preparar_arvores.gd) grava:
#   - mundo/arvores/lod1/<nome>.res: a árvore SIMPLIFICADA (meio caminho), numa superfície só (casca com UV2.x = 1). Na casca saem os galhos finos (de longe nem
#     aparecem, e ficam atrás das folhas) e o meshoptimizer da Godot (ImporterMesh.generate_lods) junta o resto; das
#     folhas fica 1 cartão a cada 4, cada um maior (a copa continua com a mesma "massa" de folhas: é o que o
#     SpeedTree/Unreal fazem nas folhagens).
#   - mundo/arvores/voxels.json: os "VOXELS" de cada árvore para longe (como os do Nanite Foliage da 5.7: a árvore vira
#     um volume, não uma foto plana). As folhas (e os galhos das secas) são agrupadas (k-means, pelo tamanho de cada
#     cartão/triângulo) em 24 bolhas (o fino), em 8 (o grosso) e em 4 (o de bem longe, só a copa); o tronco ganha 2 (1) delas. Cada bolha: centro e
#     raio (m, no espaço do modelo), cor (a média da textura, mais escura no miolo e embaixo da copa) e se é folha
#     (1: recebe a cor de cada árvore), galho (0) ou o tronco (negativo: a meia altura da faixa em pé).
# Rodar (não precisa de tela):  godot --headless --path . -s res://ferramentas/preparar_arvores_lod.gd
const Arv := preload("res://mundo/arvores.gd")
const SAIDA := "res://mundo/arvores/"
const FICA_FOLHAS := 4                      # LOD1: fica 1 cartão de folhas a cada 4
const CRESCE_FOLHA := 1.75                  # ... e ele cresce isso (em volta do centro do cartão)
const ALVO_CASCA := 0.3                     # LOD1: fração dos triângulos da casca
const TIRA_GALHOS := [0.72, 0.55]            # LOD1: fração dos triângulos que pode sair nos galhos finos [com folhas, seca]
const AREA_GALHOS := [0.32, 0.18]           # ... sem passar desta fração da área da casca
const K_FINO := 24
const K_GROSSO := 8
const K_LONGE := 4                          # o de bem longe (os blocos fixos, o "HLOD"): só a copa
const TRONCO_FINO := 2
const TRONCO_GROSSO := 1

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA + "lod1"))
	var saida := {}
	var cores_tex := {}
	for nome in Arv.nomes():
		var e: Dictionary = Arv.info()[nome]
		var am: ArrayMesh = Arv.malha(nome)
		var casca: Array = am.surface_get_arrays(0)
		var folhas: Array = am.surface_get_arrays(1) if am.get_surface_count() > 1 else []
		# ---------- LOD1 ----------
		var lod1 := ArrayMesh.new()
		var tri0 := 0
		var tri1 := 0
		var ic: PackedInt32Array = casca[Mesh.ARRAY_INDEX]
		tri0 += ic.size() / 3
		# 1º: tira os galhos FINOS (os triângulos de aresta mais curta: a volta de um galho fino é pequena), até sobrar
		# TIRA_GALHOS dos triângulos ou sair AREA_GALHOS da área; 2º: o meshoptimizer junta o resto ao longo dos galhos
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, _sem_galhos_finos(casca, 0.0 if folhas.is_empty() else 1.0))
		im.generate_lods(25.0, 60.0, [])
		var arr_c: Array = im.get_surface_arrays(0)
		var melhor: PackedInt32Array = arr_c[Mesh.ARRAY_INDEX]
		for l in im.get_surface_lod_count(0):
			var li: PackedInt32Array = im.get_surface_lod_indices(0, l)
			if li.size() >= int(ic.size() * ALVO_CASCA * 0.8) and li.size() < melhor.size():
				melhor = li
		# a simplificada é UMA superfície só (casca + folhas: 1 chamada de desenho por modelo): UV2.x = 1 na casca
		var cv: PackedVector3Array = arr_c[Mesh.ARRAY_VERTEX]
		var cn: PackedVector3Array = arr_c[Mesh.ARRAY_NORMAL]
		var cu: PackedVector2Array = arr_c[Mesh.ARRAY_TEX_UV]
		var v2 := PackedVector3Array()
		var n2 := PackedVector3Array()
		var u2 := PackedVector2Array()
		var w2 := PackedVector2Array()
		var i2 := PackedInt32Array()
		var novo_i := {}
		for x in melhor:
			if not novo_i.has(x):
				novo_i[x] = v2.size()
				v2.append(cv[x])
				n2.append(cn[x])
				u2.append(cu[x])
				w2.append(Vector2(1, 0))
			i2.append(int(novo_i[x]))
		tri1 += melhor.size() / 3
		if not folhas.is_empty():
			var vs: PackedVector3Array = folhas[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = folhas[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = folhas[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = folhas[Mesh.ARRAY_INDEX]
			tri0 += idx.size() / 3
			var ncart := vs.size() / 4
			for k in ncart:
				if k % FICA_FOLHAS != 0:
					continue
				var c := (vs[k * 4] + vs[k * 4 + 1] + vs[k * 4 + 2] + vs[k * 4 + 3]) * 0.25
				var b := v2.size()
				for q in 4:
					v2.append(c + (vs[k * 4 + q] - c) * CRESCE_FOLHA)
					n2.append(ns[k * 4 + q])
					u2.append(uv[k * 4 + q])
					w2.append(Vector2(0, 0))
				for q in 6:
					i2.append(b + idx[k * 6 + q] - k * 4)
					if q % 3 == 2:
						tri1 += 1
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v2
		arr[Mesh.ARRAY_NORMAL] = n2
		arr[Mesh.ARRAY_TEX_UV] = u2
		arr[Mesh.ARRAY_TEX_UV2] = w2
		arr[Mesh.ARRAY_INDEX] = i2
		lod1.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		ResourceSaver.save(lod1, SAIDA + "lod1/%s.res" % nome, ResourceSaver.FLAG_COMPRESS)
		# ---------- VOXELS ----------
		var nome_c := String(Arv.CASCAS.get(String(e["casca"]), "carvalho"))
		var nome_f := String(Arv.FOLHAS.get(String(e["folha"]), "carvalho"))
		if not cores_tex.has("c_" + nome_c):
			cores_tex["c_" + nome_c] = _media(SAIDA + "texturas/casca_%s.jpg" % nome_c)
		if not cores_tex.has("f_" + nome_f):
			cores_tex["f_" + nome_f] = _media(SAIDA + "texturas/folha_%s.png" % nome_f)
		var cor_c: Color = cores_tex["c_" + nome_c] * 0.85
		var cor_f: Color = cores_tex["f_" + nome_f]
		var h := float(e["altura"])
		var rc := float(e["raio_copa"])
		var rt := float(e["raio_tronco"])
		# amostras: centro de cada cartão de folhas (peso = área) ou de cada triângulo da casca
		var pf := PackedVector3Array()
		var wf := PackedFloat32Array()
		var meio_cartao := 0.0
		if not folhas.is_empty():
			var vs3: PackedVector3Array = folhas[Mesh.ARRAY_VERTEX]
			for k in vs3.size() / 4:
				var a := vs3[k * 4]
				var c2 := vs3[k * 4 + 2]
				pf.append((vs3[k * 4] + vs3[k * 4 + 1] + c2 + vs3[k * 4 + 3]) * 0.25)
				var area := (vs3[k * 4 + 1] - a).cross(vs3[k * 4 + 3] - a).length()
				wf.append(area)
				meio_cartao += a.distance_to(c2) * 0.5
			meio_cartao /= maxf(vs3.size() / 4, 1)
		var pc := PackedVector3Array()
		var wc := PackedFloat32Array()
		var ic2: PackedInt32Array = casca[Mesh.ARRAY_INDEX]
		var vc0: PackedVector3Array = casca[Mesh.ARRAY_VERTEX]
		for t in ic2.size() / 3:
			var a := vc0[ic2[t * 3]]
			var b := vc0[ic2[t * 3 + 1]]
			var c3 := vc0[ic2[t * 3 + 2]]
			pc.append((a + b + c3) / 3.0)
			wc.append((b - a).cross(c3 - a).length() * 0.5)
		var r := {"fino": [], "grosso": [], "longe": []}
		for nivel in ["fino", "grosso", "longe"]:
			var k_total: int = {"fino": K_FINO, "grosso": K_GROSSO, "longe": K_LONGE}[nivel]
			var n_tronco: int = {"fino": TRONCO_FINO, "grosso": TRONCO_GROSSO, "longe": 0}[nivel]
			var lista: Array = []
			if pf.size() > 0:
				var y_copa := INF
				for p in pf:
					y_copa = minf(y_copa, p.y)
				for g in _kmeans(pf, wf, k_total - n_tronco, 7 + k_total):
					var cen: Vector3 = g[0]
					var raio: float = clampf(float(g[1]) * 1.35 + meio_cartao * 0.6, 0.35, rc * 0.7)
					var fora := clampf(Vector2(cen.x, cen.z).length() / maxf(rc, 0.5), 0.0, 1.0)
					var ao := lerpf(0.62 + 0.38 * fora, 1.0, 0.25) * (0.78 + 0.22 * clampf(cen.y / h, 0.0, 1.0))
					lista.append([cen.x, cen.y, cen.z, raio, cor_f.r * ao, cor_f.g * ao, cor_f.b * ao, 1.0])
				# o tronco: de baixo até a copa
				# (o tronco é uma faixa em pé: a "folha" negativa guarda a meia altura dela)
				for q in n_tronco:
					var y := y_copa * (q + 0.5) / n_tronco
					var rr := maxf(rt * 1.3, 0.2)
					lista.append([0.0, y, 0.0, rr, cor_c.r, cor_c.g, cor_c.b, -(y_copa * 0.5 / n_tronco + 0.3)])
			else:
				# seca: só os galhos (a casca inteira agrupada)
				for g in _kmeans(pc, wc, k_total, 11 + k_total):
					var cen2: Vector3 = g[0]
					var raio2: float = clampf(float(g[1]) * 1.1, 0.18, rc * 0.5)
					var ao2 := 0.8 + 0.2 * clampf(cen2.y / h, 0.0, 1.0)
					lista.append([cen2.x, cen2.y, cen2.z, raio2, cor_c.r * ao2, cor_c.g * ao2, cor_c.b * ao2, 0.0])
			for v in lista:
				for q in v.size():
					v[q] = snappedf(float(v[q]), 0.001)
			r[nivel] = lista
		saida[nome] = r
		print("LOD %s · completa %d · simplificada %d triângulos (%d%%) · voxels %d/%d/%d" % [nome, tri0, tri1, 100 * tri1 / maxi(tri0, 1), r["fino"].size(), r["grosso"].size(), r["longe"].size()])
	var f := FileAccess.open(SAIDA + "voxels.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"_leia": "1.21 · gerado por ferramentas/preparar_arvores_lod.gd (não editar à mão): por modelo, as bolhas [x, y, z, raio, r, g, b, folha]", "modelos": saida}))
	f.close()
	print("PRONTO")
	quit()

# a casca sem os galhos finos (os triângulos ficam; só o índice muda)
func _sem_galhos_finos(arr: Array, com_folhas: float) -> Array:
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var n := ix.size() / 3
	var ordem: Array = []
	var area_total := 0.0
	for t in n:
		var a := vs[ix[t * 3]]
		var b := vs[ix[t * 3 + 1]]
		var c := vs[ix[t * 3 + 2]]
		var ar := (b - a).cross(c - a).length() * 0.5
		area_total += ar
		ordem.append([minf(a.distance_to(b), minf(b.distance_to(c), c.distance_to(a))), ar, t])
	ordem.sort_custom(func(x, y): return x[0] < y[0])
	var k := 0 if com_folhas > 0.5 else 1
	var sai := {}
	var area := 0.0
	for e in ordem:
		if sai.size() >= int(n * float(TIRA_GALHOS[k])) or area + float(e[1]) > area_total * float(AREA_GALHOS[k]):
			break
		area += float(e[1])
		sai[int(e[2])] = true
	var novo := PackedInt32Array()
	for t in n:
		if not sai.has(t):
			novo.append_array(PackedInt32Array([ix[t * 3], ix[t * 3 + 1], ix[t * 3 + 2]]))
	var r := arr.duplicate()
	r[Mesh.ARRAY_INDEX] = novo
	return r

# cor média de uma textura (só os pixels que aparecem)
func _media(arq: String) -> Color:
	var img := Image.load_from_file(ProjectSettings.globalize_path(arq))
	if img == null:
		return Color(0.4, 0.45, 0.3)
	img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	var soma := Color(0, 0, 0, 0)
	var n := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				soma += Color(c.r, c.g, c.b, 0)
				n += 1.0
	return Color(soma.r / maxf(n, 1.0), soma.g / maxf(n, 1.0), soma.b / maxf(n, 1.0))

# k-means com peso (início k-means++ com semente fixa: o resultado é sempre o mesmo) -> [[centro, raio rms], ...]
func _kmeans(p: PackedVector3Array, w: PackedFloat32Array, k: int, semente: int) -> Array:
	var n := p.size()
	if n == 0:
		return []
	k = mini(k, n)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var cs := PackedVector3Array([p[rng.randi() % n]])
	var d2 := PackedFloat32Array()
	d2.resize(n)
	while cs.size() < k:
		var tot := 0.0
		for i in n:
			var m := INF
			for c in cs:
				m = minf(m, p[i].distance_squared_to(c))
			d2[i] = m * w[i]
			tot += d2[i]
		var alvo := rng.randf() * tot
		var esc := n - 1
		for i in n:
			alvo -= d2[i]
			if alvo <= 0.0:
				esc = i
				break
		cs.append(p[esc])
	var dono := PackedInt32Array()
	dono.resize(n)
	for it in 14:
		for i in n:
			var m := INF
			for j in k:
				var dd := p[i].distance_squared_to(cs[j])
				if dd < m:
					m = dd
					dono[i] = j
		var soma := PackedVector3Array()
		soma.resize(k)
		var peso := PackedFloat32Array()
		peso.resize(k)
		for i in n:
			soma[dono[i]] += p[i] * w[i]
			peso[dono[i]] += w[i]
		for j in k:
			if peso[j] > 0.0:
				cs[j] = soma[j] / peso[j]
	var rms := PackedFloat32Array()
	rms.resize(k)
	var peso2 := PackedFloat32Array()
	peso2.resize(k)
	for i in n:
		rms[dono[i]] += p[i].distance_squared_to(cs[dono[i]]) * w[i]
		peso2[dono[i]] += w[i]
	var r: Array = []
	for j in k:
		if peso2[j] > 0.0:
			r.append([cs[j], sqrt(rms[j] / peso2[j])])
	return r
