extends RefCounted
# 1.13 · GPS (igual ao do GTA V): a ROTA PELAS RUAS até um ponto, desenhada como uma linha colorida no minimapa e no
# mapa (hud/mapa.gd definir_rota). As ruas de data/city.json viram um GRAFO (nós = pontos das ruas e cruzamentos,
# arestas = trechos de rua) e o caminho mais curto sai do A* da Godot (AStar2D, em C++: leva menos de 1 ms).
#   · os encontros em "T" (a ponta de uma rua encostando no meio de outra) também ligam;
#   · ÁREA LIBERADA (modo história, historia/area_liberada.gd): limitar_area(polígono) desliga tudo fora dela, então a
#     linha nunca manda o jogador para um bloqueio; limitar_area([]) libera tudo de novo;
#   · rota(de, ate): lista de pontos (x, z) do lugar do jogador até o destino, sempre pela rua.
# O grafo é montado uma vez por jogo (static) e serve a todos.
# Mexa AQUI para: a distância de ligação dos "T" e o quanto o caminho prefere ruas largas.

const LIGA_T := 24.0          # m: ponta de rua a até isso do meio de outra rua = cruzamento em "T"
const CEL := 200.0            # grade para achar a rua mais perto

static var _grafo: AStar2D = null
static var _seg := PackedInt32Array()        # pares de nós (a, b) de cada trecho
static var _hash := {}                       # Vector2i -> índices de trecho
static var _area := PackedVector2Array()
static var _desligados := PackedInt32Array()

static func pronto() -> bool:
	return _grafo != null

static func montar(dados_cidade) -> void:
	if _grafo != null or dados_cidade == null:
		return
	var g := AStar2D.new()
	var ids := {}                            # Vector2 (arredondado) -> id
	var ruas: Array = dados_cidade["roads"]
	var trechos: Array = []                  # [a, b, meia largura]
	var pontas: Array = []                   # [id, rua] das pontas de cada rua
	for ri in ruas.size():
		var f: Array = ruas[ri][1]
		var hw := float(ruas[ri][0]) * 0.5
		var ant := -1
		for i in range(0, f.size() - 1, 2):
			var p := Vector2(float(f[i]), float(f[i + 1]))
			var k := Vector2i(roundi(p.x), roundi(p.y))
			var id: int
			if ids.has(k):
				id = ids[k]
			else:
				id = g.get_available_point_id()
				g.add_point(id, p, 1.0)
				ids[k] = id
			if ant >= 0 and ant != id:
				trechos.append([ant, id, hw, ri])
			if i == 0 or i >= f.size() - 2:
				pontas.append([id, ri])
			ant = id
	# encontros em "T": a ponta solta encosta no meio de um trecho de outra rua -> parte o trecho e liga
	var cortes := {}                         # índice do trecho -> Array de [t, id]
	_indexar(g, trechos)
	var grau := {}
	for s0 in trechos:
		grau[s0[0]] = int(grau.get(s0[0], 0)) + 1
		grau[s0[1]] = int(grau.get(s0[1], 0)) + 1
	for pt in pontas:
		var id: int = pt[0]
		var p := g.get_point_position(id)
		if int(grau.get(id, 0)) > 1:
			continue
		var melhor := -1
		var md := LIGA_T
		var mt := 0.0
		for si in _perto(p):
			var s: Array = trechos[si]
			if int(s[3]) == int(pt[1]) or int(s[0]) == id or int(s[1]) == id:
				continue
			var a := g.get_point_position(int(s[0]))
			var b := g.get_point_position(int(s[1]))
			var ab := b - a
			var l2 := ab.length_squared()
			if l2 < 1.0:
				continue
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d < md:
				md = d
				melhor = si
				mt = t
		if melhor < 0:
			continue
		if mt < 0.02 or mt > 0.98:              # encosta na ponta do trecho: liga direto nela
			var s2: Array = trechos[melhor]
			trechos.append([id, int(s2[0]) if mt < 0.5 else int(s2[1]), float(s2[2]), -1])
			continue
		if not cortes.has(melhor):
			cortes[melhor] = []
		var a2 := g.get_point_position(int(trechos[melhor][0]))
		var b2 := g.get_point_position(int(trechos[melhor][1]))
		var nid := g.get_available_point_id()
		g.add_point(nid, a2.lerp(b2, mt), 1.0)
		(cortes[melhor] as Array).append([mt, nid])
		trechos.append([id, nid, float(trechos[melhor][2]), -1])
	# liga tudo (os trechos cortados viram vários)
	var seg := PackedInt32Array()
	for si in trechos.size():
		var s: Array = trechos[si]
		var cadeia: Array = [int(s[0])]
		if cortes.has(si):
			var cs: Array = cortes[si]
			cs.sort_custom(func(x, y): return x[0] < y[0])
			for c in cs:
				cadeia.append(int(c[1]))
		cadeia.append(int(s[1]))
		for i in cadeia.size() - 1:
			var a: int = cadeia[i]
			var b: int = cadeia[i + 1]
			if a != b and not g.are_points_connected(a, b):
				g.connect_points(a, b, true)
				seg.append(a)
				seg.append(b)
	_grafo = g
	_seg = seg
	_hash.clear()
	for i in range(0, _seg.size(), 2):
		var a := g.get_point_position(_seg[i])
		var b := g.get_point_position(_seg[i + 1])
		for c in _celulas(a, b):
			if not _hash.has(c):
				_hash[c] = PackedInt32Array()
			var arr: PackedInt32Array = _hash[c]
			arr.append(i / 2)
			_hash[c] = arr

# índice provisório (durante a montagem, com a lista de trechos ainda em Array)
static var _hash_m := {}
static func _indexar(g: AStar2D, trechos: Array) -> void:
	_hash_m.clear()
	for si in trechos.size():
		var a := g.get_point_position(int(trechos[si][0]))
		var b := g.get_point_position(int(trechos[si][1]))
		for c in _celulas(a, b):
			if not _hash_m.has(c):
				_hash_m[c] = []
			(_hash_m[c] as Array).append(si)

static func _perto(p: Vector2) -> Array:
	var r: Array = []
	var c := Vector2i(floori(p.x / CEL), floori(p.y / CEL))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			r.append_array(_hash_m.get(c + Vector2i(dx, dz), []))
	return r

static func _celulas(a: Vector2, b: Vector2) -> Array:
	var r: Array = []
	var n := maxi(1, int(a.distance_to(b) / (CEL * 0.5)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var c := Vector2i(floori(p.x / CEL), floori(p.y / CEL))
		if not r.has(c):
			r.append(c)
	return r

# trecho de rua mais perto de p (que não esteja desligado): [índice, ponto na rua] ou [-1, p]
static func _rua_perto(p: Vector2) -> Array:
	var melhor := -1
	var md := INF
	var mp := p
	var c := Vector2i(floori(p.x / CEL), floori(p.y / CEL))
	for raio in 4:
		for dx in range(-raio, raio + 1):
			for dz in range(-raio, raio + 1):
				if maxi(absi(dx), absi(dz)) != raio:
					continue
				for si in _hash.get(c + Vector2i(dx, dz), PackedInt32Array()):
					var ia := _seg[si * 2]
					var ib := _seg[si * 2 + 1]
					if _grafo.is_point_disabled(ia) or _grafo.is_point_disabled(ib):
						continue
					var a := _grafo.get_point_position(ia)
					var b := _grafo.get_point_position(ib)
					var ab := b - a
					var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
					var q := a + ab * t
					var d := p.distance_squared_to(q)
					if d < md:
						md = d
						melhor = si
						mp = q
		if melhor >= 0 and raio >= 1:
			break
	return [melhor, mp]

# o caminho pelas ruas de "de" até "ate" (pontos x, z); vazio = não há caminho
static func rota(de: Vector2, ate: Vector2) -> PackedVector2Array:
	if _grafo == null:
		return PackedVector2Array()
	var ra := _rua_perto(de)
	var rb := _rua_perto(ate)
	if int(ra[0]) < 0 or int(rb[0]) < 0:
		return PackedVector2Array()
	var s := _grafo.get_available_point_id()
	_grafo.add_point(s, ra[1], 1.0)
	var e := s + 1
	_grafo.add_point(e, rb[1], 1.0)
	for par in [[s, int(ra[0])], [e, int(rb[0])]]:
		var si: int = par[1]
		_grafo.connect_points(par[0], _seg[si * 2], true)
		_grafo.connect_points(par[0], _seg[si * 2 + 1], true)
	if int(ra[0]) == int(rb[0]):
		_grafo.connect_points(s, e, true)
	var cam := _grafo.get_point_path(s, e)
	_grafo.remove_point(s)
	_grafo.remove_point(e)
	var r := PackedVector2Array()
	if cam.is_empty():
		return r
	r.append(de)
	for p in cam:
		if r[r.size() - 1].distance_squared_to(p) > 0.25:
			r.append(p)
	return r

# comprimento de um caminho (m)
static func comprimento(cam: PackedVector2Array) -> float:
	var t := 0.0
	for i in cam.size() - 1:
		t += cam[i].distance_to(cam[i + 1])
	return t

# distância do ponto p até o caminho (m)
static func distancia(cam: PackedVector2Array, p: Vector2) -> float:
	var md := INF
	for i in cam.size() - 1:
		var a := cam[i]
		var ab := cam[i + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		md = minf(md, p.distance_to(a + ab * t))
	return md

# ---------- área liberada (modo história) ----------
# desliga os pontos do grafo fora do polígono (x, z); vazio = libera tudo
static func limitar_area(poli: PackedVector2Array) -> void:
	if _grafo == null:
		return
	for id in _desligados:
		if _grafo.has_point(id):
			_grafo.set_point_disabled(id, false)
	_desligados = PackedInt32Array()
	_area = poli
	if poli.size() < 3:
		return
	for id in _grafo.get_point_ids():
		if not Geometry2D.is_point_in_polygon(_grafo.get_point_position(id), poli):
			_grafo.set_point_disabled(id, true)
			_desligados.append(id)

# CORREDOR (a corrida): desliga os pontos a mais de "dist" metros do caminho
static func limitar_corredor(cam: PackedVector2Array, dist: float) -> void:
	if _grafo == null:
		return
	limitar_area(PackedVector2Array())
	for id in _grafo.get_point_ids():
		if distancia(cam, _grafo.get_point_position(id)) > dist:
			_grafo.set_point_disabled(id, true)
			_desligados.append(id)

# ruas que SAEM do corredor: [ponto na borda, direção (de dentro para fora), largura da rua]
static func saidas_do_corredor(dados_cidade, cam: PackedVector2Array, dist: float) -> Array:
	var r: Array = []
	for rd in dados_cidade["roads"]:
		var f: Array = rd[1]
		for i in range(0, f.size() - 3, 2):
			var a := Vector2(float(f[i]), float(f[i + 1]))
			var b := Vector2(float(f[i + 2]), float(f[i + 3]))
			var da := distancia(cam, a)
			var db := distancia(cam, b)
			if (da <= dist) == (db <= dist):
				continue
			var dentro := a if da <= dist else b
			var fora := b if da <= dist else a
			# acha o ponto da borda (busca binária)
			var lo := 0.0
			var hi := 1.0
			for k in 14:
				var m := (lo + hi) * 0.5
				if distancia(cam, dentro.lerp(fora, m)) <= dist:
					lo = m
				else:
					hi = m
			r.append([dentro.lerp(fora, lo), (fora - dentro).normalized(), float(rd[0])])
	return r

# trechos de rua que CRUZAM a borda da área: [ponto da borda, direção da rua, largura] (onde vão os bloqueios)
static func saidas_da_area(dados_cidade, poli: PackedVector2Array) -> Array:
	var r: Array = []
	if poli.size() < 3:
		return r
	for rd in dados_cidade["roads"]:
		var f: Array = rd[1]
		for i in range(0, f.size() - 3, 2):
			var a := Vector2(float(f[i]), float(f[i + 1]))
			var b := Vector2(float(f[i + 2]), float(f[i + 3]))
			var ina := Geometry2D.is_point_in_polygon(a, poli)
			var inb := Geometry2D.is_point_in_polygon(b, poli)
			if ina == inb:
				continue
			for j in poli.size():
				var c := poli[j]
				var d := poli[(j + 1) % poli.size()]
				var x = Geometry2D.segment_intersects_segment(a, b, c, d)
				if x != null:
					var dir := (b - a).normalized() if ina else (a - b).normalized()   # de dentro para fora
					r.append([x, dir, float(rd[0])])
	return r
