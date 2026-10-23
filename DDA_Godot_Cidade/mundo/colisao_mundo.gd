extends Node3D
# COLISÃO DO MUNDO, só em volta do jogador ("streaming").
# A cidade inteira é visual (malhas + MultiMesh); aqui criamos colisão apenas onde o jogador está:
#  - CHÃO: um HeightMapShape3D de ~96 m centrado no jogador. A altura de cada ponto vem dos MESMOS dados
#    que desenham o chão (rua 0.6 · calçada 0.55 · parque 0.4 · lago 0.2 · terra 0.0 · mar -0.5), então o pé encosta no que se vê.
#    O recálculo roda aos poucos (poucas linhas por quadro) para não travar o celular.
#    0.72 · ÁGUA FUNDA: no mar e nos lagos o chão de física fica ABAIXO da superfície (rampa a partir da margem até
#    PROF_MAR / PROF_LAGO), então dá para entrar andando e, mais para dentro, NADAR (jogador/jogador.gd).
#    nivel_agua(x, z) diz a altura da superfície (ou -INF se não é água).
#  - PRÉDIOS: um pequeno conjunto (pool) de caixas reaproveitadas, posicionadas só nos prédios próximos
#    (menos os que estão com o interior montado: esses têm paredes de verdade, ver mundo/interiores.gd).
#  - OBSTÁCULOS: carros, barreiras, caçambas e entulho perto do jogador (outro pool de caixas giradas).
# Camadas de física: 1 = mundo · 2 = jogador · 3 = inimigos (futuro).
# 0.74 · MULTIJOGADOR (host): criar_extra(amigo) faz uma cópia leve que segue o amigo (chão, prédios e obstáculos de
# física perto DELE, com os mesmos dados da cidade): os infectados perto do amigo andam com física, batem nas paredes e
# portas dos prédios abertos lá. tem_chao_fisico() vale para todas as cópias.

const ALT_MAR := -0.5
const ALT_TERRA := 0.0
const ALT_LAGO := 0.2
const ALT_PARQUE := 0.4
const ALT_RUA := 0.6
const ALT_CALCADA := 0.55
const CALCADA := 5.0         # largura da calçada (igual a mundo/cidade.gd)
const BASE_PREDIO := 0.6
const PROF_MAR := 3.4        # 0.72: fundo do mar (m abaixo da superfície), longe da margem
const PROF_LAGO := 2.4       # 0.72: fundo dos lagos
const RAMPA_AGUA := 7.0      # 0.72: metros da margem até a profundidade toda

const ESPACO := 2.0          # metros entre amostras do chão
const MEIO := 24
const N := 49                # = 2 * MEIO + 1 amostras por lado (96 m de chão)
const RECENTRAR := 16.0      # quando o jogador se afasta tanto do centro, recalcula o chão
const LINHAS_POR_QUADRO := 4
const CEL_RUA := 64.0
const CEL_PARQUE := 128.0
const CEL_PREDIO := 100.0
const RAIO_PREDIOS := 40.0
const POOL := 48
const POOL_OBST := 40
const CEL_OBST := 50.0
const RAIO_OBST := 30.0

var alvo: Node3D = null      # quem a colisão acompanha (o jogador)

var _t_pts: Array[PackedVector2Array] = []
var _t_box: Array[Rect2] = []
var _l_pts: Array[PackedVector2Array] = []
var _l_box: Array[Rect2] = []
var _p_pts: Array[PackedVector2Array] = []
var _p_box: Array[Rect2] = []
var _p_hash := {}            # Vector2i -> PackedInt32Array (parques)
var _r_hash := {}            # Vector2i -> PackedFloat32Array (ax, az, bx, bz, meia-largura)
var _pred := PackedFloat32Array()   # x, z, tam_x, tam_z, altura (5 por prédio)
var _pred_hash := {}         # Vector2i -> PackedInt32Array

var _chao_forma: CollisionShape3D
var _mapa: HeightMapShape3D
var _centro := Vector2(1.0e9, 1.0e9)
var _novo_centro := Vector2.ZERO
var _novo_dados := PackedFloat32Array()
var _linha := -1             # -1 = nenhum recálculo em andamento
var _pool: Array[StaticBody3D] = []
var _pool_forma: Array[BoxShape3D] = []
var _pool_uso := 0
var _ult_pred := Vector2(1.0e9, 1.0e9)
# obstáculos (carros, barreiras, caçambas, entulho): x, z, giro, tam_x, tam_y, tam_z, y_centro
var _obst := PackedFloat32Array()
var _obst_hash := {}
var _obst_cs := PackedFloat32Array()        # por obstáculo: cos, sin, raio
var _pool_obst: Array[StaticBody3D] = []
var _pool_obst_forma: Array[BoxShape3D] = []
var _obst_uso := 0
var _ult_obst := Vector2(1.0e9, 1.0e9)
var abertos := {}            # prédios com interior montado (a colisão/tiro usa as paredes de verdade)
# 0.74: LOCAIS ESPECIAIS de longe (casca, mundo/locais.gd): o tiro de longe para neles; os abertos (perto) já têm
# colisão de verdade e ficam de fora
var _locais: Array = []      # [[índice, AABB], ...]
var locais_abertos := {}

func configurar_locais(vols: Array) -> void:
	_locais = vols

# ---------- 0.74: cópias que seguem os amigos (só no host) ----------
var extras: Array = []

func criar_extra(quem: Node3D) -> Node3D:
	var c = get_script().new()
	c.name = "ColisaoAmigo"
	c.alvo = quem
	for campo in ["_t_pts", "_t_box", "_l_pts", "_l_box", "_p_pts", "_p_box", "_p_hash", "_r_hash", "_pred", "_pred_hash",
			"_lote", "_lote_w", "_lote_h", "_lote_cel", "_lote_origem", "_lote_rampa", "_locais"]:
		c.set(campo, get(campo))
	c.abertos = abertos                   # o MESMO dicionário (prédios abertos não viram caixa em nenhuma cópia)
	c.locais_abertos = locais_abertos
	get_parent().add_child(c)
	c.configurar_obstaculos(_obst)
	extras.append(c)
	return c

func remover_extra(c: Node3D) -> void:
	extras.erase(c)
	if is_instance_valid(c):
		c.queue_free()

# os prédios abertos mudaram: refaz a colisão dos prédios perto (aqui e nas cópias)
func refazer_predios() -> void:
	_ult_pred = Vector2(1.0e9, 1.0e9)
	for e in extras:
		if is_instance_valid(e):
			e._ult_pred = Vector2(1.0e9, 1.0e9)

func _ready() -> void:
	process_physics_priority = -10     # roda antes do jogador
	var chao := StaticBody3D.new()
	chao.name = "Chao"
	chao.collision_layer = 1
	chao.collision_mask = 0
	_mapa = HeightMapShape3D.new()
	_mapa.map_width = N
	_mapa.map_depth = N
	_chao_forma = CollisionShape3D.new()
	_chao_forma.shape = _mapa
	chao.add_child(_chao_forma)
	add_child(chao)
	for i in POOL:
		var sb := StaticBody3D.new()
		sb.name = "Predio%d" % i
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(0.0, -10000.0, 0.0)
		add_child(sb)
		_pool.append(sb)
		_pool_forma.append(bs)

# dados = conteúdo de data/city.json · predios = x, z, tam_x, tam_z, altura (5 floats por prédio)
# pode ser chamada de novo (a história tira os carros largados antes do colapso e põe de volta depois)
func configurar_obstaculos(lista: PackedFloat32Array) -> void:
	_obst = lista
	# OTIMIZAÇÃO: cos/sin do giro e o raio de cada obstáculo calculados uma vez (antes: a cada consulta)
	var n := lista.size() / 7
	_obst_cs.resize(n * 3)
	for i in n:
		var o := i * 7
		_obst_cs[i * 3] = cos(lista[o + 2])
		_obst_cs[i * 3 + 1] = sin(lista[o + 2])
		_obst_cs[i * 3 + 2] = 0.5 * sqrt(lista[o + 3] * lista[o + 3] + lista[o + 5] * lista[o + 5])
	_obst_hash.clear()
	_ult_obst = Vector2(1.0e9, 1.0e9)
	var tmp := {}
	for i in range(lista.size() / 7):
		var key := Vector2i(floori(lista[i * 7] / CEL_OBST), floori(lista[i * 7 + 1] / CEL_OBST))
		if not tmp.has(key):
			tmp[key] = []
		tmp[key].append(i)
	for k in tmp:
		_obst_hash[k] = PackedInt32Array(tmp[k])
	if not _pool_obst.is_empty():
		for k in _obst_uso:
			_pool_obst[k].position = Vector3(0.0, -10000.0, 0.0)
		_obst_uso = 0
		return
	for i in POOL_OBST:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(0.0, -10000.0, 0.0)
		add_child(sb)
		_pool_obst.append(sb)
		_pool_obst_forma.append(bs)

func _atualizar_obstaculos(p: Vector2, forcado: bool) -> void:
	if _pool_obst.is_empty() or (not forcado and p.distance_to(_ult_obst) < 3.0):
		return
	_ult_obst = p
	var cx := floori(p.x / CEL_OBST)
	var cz := floori(p.y / CEL_OBST)
	var cand: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not _obst_hash.has(key):
				continue
			for idx in _obst_hash[key]:
				var d2 := p.distance_squared_to(Vector2(_obst[idx * 7], _obst[idx * 7 + 1]))
				if d2 < RAIO_OBST * RAIO_OBST:
					cand.append([d2, idx])
	if cand.size() > POOL_OBST:
		cand.sort_custom(func(a, b): return a[0] < b[0])
	var n := mini(cand.size(), POOL_OBST)
	for k in n:
		var o := int(cand[k][1]) * 7
		_pool_obst[k].transform = Transform3D(Basis(Vector3.UP, _obst[o + 2]), Vector3(_obst[o], _obst[o + 6], _obst[o + 1]))
		_pool_obst_forma[k].size = Vector3(_obst[o + 3], _obst[o + 4], _obst[o + 5])
	for k in range(n, _obst_uso):
		_pool_obst[k].position = Vector3(0.0, -10000.0, 0.0)
	_obst_uso = n

func configurar(dados: Dictionary, predios: PackedFloat32Array) -> void:
	for l in dados["lands"]:
		var p := _pts(l[1])
		if int(l[0]) == 1:
			_l_pts.append(p)
			_l_box.append(_caixa(p))
		else:
			_t_pts.append(p)
			_t_box.append(_caixa(p))
	var tmp_p := {}
	var ip := 0
	for f in dados["parks"]:
		var p := _pts(f)
		var r := _caixa(p)
		_p_pts.append(p)
		_p_box.append(r)
		_indexar(tmp_p, r, CEL_PARQUE, ip)
		ip += 1
	for k in tmp_p:
		_p_hash[k] = PackedInt32Array(tmp_p[k])
	var tmp_r := {}
	for rd in dados["roads"]:
		var hw: float = float(rd[0]) * 0.5
		var f: Array = rd[1]
		for k in range(0, f.size() - 3, 2):
			var ax: float = f[k]
			var az: float = f[k + 1]
			var bx: float = f[k + 2]
			var bz: float = f[k + 3]
			var m := hw + CALCADA
			var r := Rect2(minf(ax, bx) - m, minf(az, bz) - m, absf(bx - ax) + 2.0 * m, absf(bz - az) + 2.0 * m)
			var seg := [ax, az, bx, bz, hw]
			var c0 := Vector2i(floori(r.position.x / CEL_RUA), floori(r.position.y / CEL_RUA))
			var c1 := Vector2i(floori(r.end.x / CEL_RUA), floori(r.end.y / CEL_RUA))
			for cx in range(c0.x, c1.x + 1):
				for cz in range(c0.y, c1.y + 1):
					var key := Vector2i(cx, cz)
					if not tmp_r.has(key):
						tmp_r[key] = []
					tmp_r[key].append_array(seg)
	for k in tmp_r:
		_r_hash[k] = PackedFloat32Array(tmp_r[k])
	_pred = predios
	var tmp_b := {}
	for i in range(_pred.size() / 5):
		var key := Vector2i(floori(_pred[i * 5] / CEL_PREDIO), floori(_pred[i * 5 + 1] / CEL_PREDIO))
		if not tmp_b.has(key):
			tmp_b[key] = []
		tmp_b[key].append(i)
	for k in tmp_b:
		_pred_hash[k] = PackedInt32Array(tmp_b[k])

func _pts(f: Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in range(0, f.size() - 1, 2):
		o.append(Vector2(f[i], f[i + 1]))
	return o

func _caixa(p: PackedVector2Array) -> Rect2:
	var r := Rect2(p[0], Vector2.ZERO)
	for v in p:
		r = r.expand(v)
	return r

func _indexar(tmp: Dictionary, r: Rect2, cel: float, idx: int) -> void:
	var c0 := Vector2i(floori(r.position.x / cel), floori(r.position.y / cel))
	var c1 := Vector2i(floori(r.end.x / cel), floori(r.end.y / cel))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var key := Vector2i(cx, cz)
			if not tmp.has(key):
				tmp[key] = []
			tmp[key].append(idx)

# altura do chão (m) num ponto do mundo, igual às alturas usadas para desenhar a cidade
func altura(x: float, z: float) -> float:
	var r := altura_rua(x, z)
	if r > -100.0:
		return r
	var b := altura_sem_rua(x, z)
	return maxf(b, altura_lote(x, z, b))

# ---------- LOTES (mundo/cidade.gd _lotes): células de 20 m com prédio ficam na altura da calçada, com rampa ----------
var _lote := PackedByteArray()
var _lote_w := 0
var _lote_h := 0
var _lote_cel := 20.0
var _lote_origem := Vector2.ZERO
var _lote_rampa := 2.0

func configurar_lotes(mascara: PackedByteArray, w: int, h: int, cel: float, metade_mundo: Vector2, rampa: float) -> void:
	_lote = mascara
	_lote_w = w
	_lote_h = h
	_lote_cel = cel
	_lote_origem = metade_mundo
	_lote_rampa = rampa
	_centro = Vector2(1.0e9, 1.0e9)                 # refaz o chão em volta do jogador

func _eh_lote(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < _lote_w and r < _lote_h and _lote[r * _lote_w + c] == 1

# ALT_CALCADA em cima do lote; na rampa desce em linha reta até "base"; fora: -1000
func altura_lote(x: float, z: float, base: float) -> float:
	if _lote.is_empty():
		return -1000.0
	var fx := (x + _lote_origem.x) / _lote_cel
	var fz := (z + _lote_origem.y) / _lote_cel
	var c := floori(fx)
	var r := floori(fz)
	if _eh_lote(c, r):
		return ALT_CALCADA
	var d := _lote_rampa
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if not _eh_lote(c + dc, r + dr):
				continue
			var qx := clampf(fx, c + dc, c + dc + 1) - fx
			var qz := clampf(fz, r + dr, r + dr + 1) - fz
			d = minf(d, Vector2(qx, qz).length() * _lote_cel)
	if d >= _lote_rampa:
		return -1000.0
	return lerpf(ALT_CALCADA, minf(base, ALT_TERRA), d / _lote_rampa)

# só ruas e calçadas: ALT_RUA, ALT_CALCADA ou -1000 (não é rua)
func altura_rua(x: float, z: float) -> float:
	var key := Vector2i(floori(x / CEL_RUA), floori(z / CEL_RUA))
	var calcada := false
	if _r_hash.has(key):
		var s: PackedFloat32Array = _r_hash[key]
		for i in range(0, s.size(), 5):
			var dx := s[i + 2] - s[i]
			var dz := s[i + 3] - s[i + 1]
			var l2 := dx * dx + dz * dz
			var t := 0.0
			if l2 > 0.0001:
				t = clampf(((x - s[i]) * dx + (z - s[i + 1]) * dz) / l2, 0.0, 1.0)
			var qx := s[i] + dx * t - x
			var qz := s[i + 1] + dz * t - z
			var d2 := qx * qx + qz * qz
			if d2 <= s[i + 4] * s[i + 4]:
				return ALT_RUA          # ruas valem também sobre a água (pontes)
			if d2 <= (s[i + 4] + CALCADA) * (s[i + 4] + CALCADA):
				calcada = true
	if calcada:
		return ALT_CALCADA
	return -1000.0

# 0.49: de que é o chão aqui (som dos passos): "concreto" (rua, calçada, lote), "grama" (parque, terreno),
# "madeira" (dentro de prédio) ou "agua"
func tipo_piso(x: float, z: float) -> String:
	if dentro_de_predio(x, z, 0.0, true):
		return "madeira"
	if altura_rua(x, z) > -100.0 or altura_lote(x, z, ALT_TERRA) >= ALT_CALCADA - 0.01:
		return "concreto"
	var b := altura_sem_rua(x, z)
	if b == ALT_MAR or b == ALT_LAGO:
		return "agua"
	return "grama"

# 0.72: altura da superfície da água em (x, z): ALT_MAR, ALT_LAGO ou -INF (não é água: terra, rua, ponte, lote)
func nivel_agua(x: float, z: float) -> float:
	var a := altura(x, z)
	if a == ALT_MAR:
		return ALT_MAR
	if absf(a - ALT_LAGO) < 0.0005:
		return ALT_LAGO
	return -INF

# 0.72: no mapa de alturas pronto (N x N), afunda o mar e os lagos pela distância até a margem (2 passadas de
# "distância chanfrada" na grade: barato). Fora da grade conta como água (longe da margem).
func _aprofundar(d: PackedFloat32Array) -> void:
	var tem := false
	var dist := PackedFloat32Array()
	dist.resize(N * N)
	for i in N * N:
		var v := d[i]
		var agua := v == ALT_MAR or absf(v - ALT_LAGO) < 0.0005
		dist[i] = 1.0e6 if agua else 0.0
		tem = tem or agua
	if not tem:
		return
	const D1 := ESPACO
	const D2 := ESPACO * 1.41421
	for r in N:
		for c in N:
			var i := r * N + c
			var m := dist[i]
			if m == 0.0:
				continue
			if c > 0:
				m = minf(m, dist[i - 1] + D1)
			if r > 0:
				m = minf(m, dist[i - N] + D1)
				if c > 0:
					m = minf(m, dist[i - N - 1] + D2)
				if c < N - 1:
					m = minf(m, dist[i - N + 1] + D2)
			dist[i] = m
	for r in range(N - 1, -1, -1):
		for c in range(N - 1, -1, -1):
			var i := r * N + c
			var m := dist[i]
			if m == 0.0:
				continue
			if c < N - 1:
				m = minf(m, dist[i + 1] + D1)
			if r < N - 1:
				m = minf(m, dist[i + N] + D1)
				if c < N - 1:
					m = minf(m, dist[i + N + 1] + D2)
				if c > 0:
					m = minf(m, dist[i + N - 1] + D2)
			dist[i] = m
	for i in N * N:
		if dist[i] > 0.0:
			var prof := PROF_MAR if d[i] == ALT_MAR else PROF_LAGO
			d[i] -= prof * clampf((dist[i] - 1.0) / RAMPA_AGUA, 0.0, 1.0)

# terra, parque, lago ou mar (ignorando as ruas)
func altura_sem_rua(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var terra := false
	for i in _t_box.size():
		if _t_box[i].has_point(p) and Geometry2D.is_point_in_polygon(p, _t_pts[i]):
			terra = true
			break
	if not terra:
		return ALT_MAR
	var pk := Vector2i(floori(x / CEL_PARQUE), floori(z / CEL_PARQUE))
	if _p_hash.has(pk):
		for i in _p_hash[pk]:
			if _p_box[i].has_point(p) and Geometry2D.is_point_in_polygon(p, _p_pts[i]):
				return ALT_PARQUE
	for i in _l_box.size():
		if _l_box[i].has_point(p) and Geometry2D.is_point_in_polygon(p, _l_pts[i]):
			return ALT_LAGO
	return ALT_TERRA

# calcula tudo de uma vez (usar ao nascer/teleportar)
func forcar(pos: Vector2) -> void:
	_iniciar_calculo(pos)
	_calcular_linhas(N)
	_atualizar_predios(pos, true)
	_atualizar_obstaculos(pos, true)

func _iniciar_calculo(pos: Vector2) -> void:
	_novo_centro = Vector2(roundf(pos.x / ESPACO) * ESPACO, roundf(pos.y / ESPACO) * ESPACO)
	_novo_dados.resize(N * N)
	_linha = 0

func _calcular_linhas(max_linhas: int) -> void:
	var feitas := 0
	while _linha >= 0 and _linha < N and feitas < max_linhas:
		var z := _novo_centro.y + (_linha - MEIO) * ESPACO
		for i in N:
			_novo_dados[_linha * N + i] = altura(_novo_centro.x + (i - MEIO) * ESPACO, z)
		_linha += 1
		feitas += 1
	if _linha >= N:
		_aprofundar(_novo_dados)
		_mapa.map_data = _novo_dados
		_chao_forma.transform = Transform3D(Basis.from_scale(Vector3(ESPACO, 1.0, ESPACO)), Vector3(_novo_centro.x, 0.0, _novo_centro.y))
		_centro = _novo_centro
		_linha = -1

func _physics_process(_delta: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	var g := alvo.global_position
	var p := Vector2(g.x, g.z)
	if p.distance_to(_centro) > 40.0:
		forcar(p)
		return
	if _linha >= 0:
		_calcular_linhas(LINHAS_POR_QUADRO)
	elif p.distance_to(_centro) > RECENTRAR:
		_iniciar_calculo(p)
		_calcular_linhas(LINHAS_POR_QUADRO)
	_atualizar_predios(p, false)
	_atualizar_obstaculos(p, false)

func _atualizar_predios(p: Vector2, forcado: bool) -> void:
	if not forcado and p.distance_to(_ult_pred) < 3.0:
		return
	_ult_pred = p
	var cx := floori(p.x / CEL_PREDIO)
	var cz := floori(p.y / CEL_PREDIO)
	var cand: Array = []
	var r2 := RAIO_PREDIOS * RAIO_PREDIOS
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not _pred_hash.has(key):
				continue
			var lst: PackedInt32Array = _pred_hash[key]
			for idx in lst:
				if abertos.has(idx):
					continue
				var o := idx * 5
				var ex := maxf(absf(p.x - _pred[o]) - _pred[o + 2] * 0.5, 0.0)
				var ez := maxf(absf(p.y - _pred[o + 1]) - _pred[o + 3] * 0.5, 0.0)
				var d2 := ex * ex + ez * ez
				if d2 < r2:
					cand.append([d2, idx])
	if cand.size() > POOL:
		cand.sort_custom(func(a, b): return a[0] < b[0])
	var n := mini(cand.size(), POOL)
	for k in n:
		var o := int(cand[k][1]) * 5
		_pool[k].position = Vector3(_pred[o], BASE_PREDIO + _pred[o + 4] * 0.5, _pred[o + 1])
		_pool_forma[k].size = Vector3(_pred[o + 2], _pred[o + 4], _pred[o + 3])
	for k in range(n, _pool_uso):
		_pool[k].position = Vector3(0.0, -10000.0, 0.0)
	_pool_uso = n

# RAIO pelos dados da cidade (prédios e chão de qualquer distância, sem física). Usado pelos tiros:
# a colisão de física só existe perto do jogador, mas a M4 alcança 260 m.
# devolve {hit, pos, n, dist, predio}
func raio(o: Vector3, d: Vector3, alcance: float) -> Dictionary:
	var res := {"hit": false, "pos": o + d * alcance, "n": Vector3.UP, "dist": alcance, "predio": false}
	var melhor := alcance
	# chão: plano na altura do terreno (2 iterações bastam: as alturas variam menos de 1 m)
	if d.y < -0.0001:
		var hg := altura(o.x, o.z)
		var t := (o.y - hg) / -d.y
		for it in 2:
			if t <= 0.0 or t > melhor:
				break
			var p := o + d * t
			hg = altura(p.x, p.z)
			t = (o.y - hg) / -d.y
		if t > 0.0 and t <= melhor:
			melhor = t
			res = {"hit": true, "pos": o + d * t, "n": Vector3.UP, "dist": t, "predio": false}
	# prédios: células da grade que o raio atravessa (+ vizinhas, porque um prédio passa da borda da célula)
	var celulas := {}
	var passos := int(ceil(melhor / (CEL_PREDIO * 0.5)))
	for s in passos + 1:
		var p := o + d * minf(s * CEL_PREDIO * 0.5, melhor)
		var cx := floori(p.x / CEL_PREDIO)
		var cz := floori(p.z / CEL_PREDIO)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				celulas[Vector2i(cx + dx, cz + dz)] = true
	var inv := Vector3(1.0 / d.x if absf(d.x) > 1e-9 else 1e18, 1.0 / d.y if absf(d.y) > 1e-9 else 1e18, 1.0 / d.z if absf(d.z) > 1e-9 else 1e18)
	for key in celulas:
		if not _pred_hash.has(key):
			continue
		var lista: PackedInt32Array = _pred_hash[key]
		for idx in lista:
			if abertos.has(idx):
				continue             # prédio aberto: o tiro bate nas paredes de verdade (física)
			var b: int = idx * 5
			var mn := Vector3(_pred[b] - _pred[b + 2] * 0.5, BASE_PREDIO, _pred[b + 1] - _pred[b + 3] * 0.5)
			var mx := Vector3(_pred[b] + _pred[b + 2] * 0.5, BASE_PREDIO + _pred[b + 4], _pred[b + 1] + _pred[b + 3] * 0.5)
			var t1 := (mn - o) * inv
			var t2 := (mx - o) * inv
			var tmin := Vector3(minf(t1.x, t2.x), minf(t1.y, t2.y), minf(t1.z, t2.z))
			var tmax := Vector3(maxf(t1.x, t2.x), maxf(t1.y, t2.y), maxf(t1.z, t2.z))
			var entra := maxf(tmin.x, maxf(tmin.y, tmin.z))
			var sai := minf(tmax.x, minf(tmax.y, tmax.z))
			if sai < maxf(entra, 0.0) or entra < 0.0 or entra >= melhor:
				continue
			var n := Vector3.ZERO
			if entra == tmin.x:
				n.x = -signf(d.x)
			elif entra == tmin.y:
				n.y = -signf(d.y)
			else:
				n.z = -signf(d.z)
			melhor = entra
			res = {"hit": true, "pos": o + d * entra, "n": n, "dist": entra, "predio": true}
	# 0.74: cascas dos locais especiais fechados
	var fim := o + d * melhor
	for par in _locais:
		if locais_abertos.has(par[0]):
			continue
		var ab: AABB = par[1]
		if ab.has_point(o):
			continue
		var hit = ab.intersects_segment(o, fim)
		if hit == null:
			continue
		var hp: Vector3 = hit
		var t := o.distance_to(hp)
		if t >= melhor:
			continue
		var nn := Vector3.UP
		var rel := (hp - ab.get_center()) / (ab.size * 0.5)
		var ax := rel.abs()
		if ax.x >= ax.y and ax.x >= ax.z:
			nn = Vector3(signf(rel.x), 0, 0)
		elif ax.z >= ax.y:
			nn = Vector3(0, 0, signf(rel.z))
		else:
			nn = Vector3(0, signf(rel.y), 0)
		melhor = t
		fim = hp
		res = {"hit": true, "pos": hp, "n": nn, "dist": t, "predio": true}
	return res

# ---------- consultas para os inimigos (inimigos/vago.gd e inimigos/vagos.gd) ----------
# true se (x, z) cai dentro da planta de um prédio FECHADO (+ margem). Os prédios "abertos" ficam de fora
# (eles têm paredes e portas de verdade, de física), a não ser que com_abertos = true.
func dentro_de_predio(x: float, z: float, margem := 0.0, com_abertos := false) -> bool:
	var cx := floori(x / CEL_PREDIO)
	var cz := floori(z / CEL_PREDIO)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not _pred_hash.has(key):
				continue
			var lista: PackedInt32Array = _pred_hash[key]
			for idx in lista:
				var o := idx * 5
				if absf(x - _pred[o]) < _pred[o + 2] * 0.5 + margem and absf(z - _pred[o + 1]) < _pred[o + 3] * 0.5 + margem:
					if abertos.has(idx) and not com_abertos:
						continue
					return true
	return false

# índices dos prédios cuja planta fica a menos de "raio" m de (x, z) (para a sombra no chão: mundo/mato.gd)
func predios_perto(x: float, z: float, raio: float) -> PackedInt32Array:
	var o := PackedInt32Array()
	var c0 := Vector2i(floori((x - raio - 60.0) / CEL_PREDIO), floori((z - raio - 60.0) / CEL_PREDIO))
	var c1 := Vector2i(floori((x + raio + 60.0) / CEL_PREDIO), floori((z + raio + 60.0) / CEL_PREDIO))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var key := Vector2i(cx, cz)
			if not _pred_hash.has(key):
				continue
			for idx: int in _pred_hash[key]:
				var k: int = idx * 5
				var dx := maxf(absf(x - _pred[k]) - _pred[k + 2] * 0.5, 0.0)
				var dz := maxf(absf(z - _pred[k + 1]) - _pred[k + 3] * 0.5, 0.0)
				if dx * dx + dz * dz < raio * raio:
					o.append(idx)
	return o

# true se (x, z) cai dentro de um obstáculo (carro, barreira, caçamba, entulho), em qualquer distância
func dentro_de_obstaculo(x: float, z: float, margem := 0.0) -> bool:
	var cx := floori(x / CEL_OBST)
	var cz := floori(z / CEL_OBST)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not _obst_hash.has(key):
				continue
			var lista: PackedInt32Array = _obst_hash[key]
			for idx in lista:
				var o := idx * 7
				var ox := x - _obst[o]
				var oz := z - _obst[o + 1]
				var rr := _obst_cs[idx * 3 + 2] + margem
				if ox * ox + oz * oz > rr * rr:
					continue                    # longe do círculo que cobre o obstáculo: nem testa o retângulo
				var co := _obst_cs[idx * 3]
				var se := _obst_cs[idx * 3 + 1]
				var lx := ox * co - oz * se
				var lz := ox * se + oz * co
				if absf(lx) < _obst[o + 3] * 0.5 + margem and absf(lz) < _obst[o + 5] * 0.5 + margem:
					return true
	return false

# true se o chão de física (mapa de alturas em volta do jogador) cobre (x, z) com folga
func tem_chao_fisico(x: float, z: float) -> bool:
	var lim := (MEIO - 3) * ESPACO
	if absf(x - _centro.x) < lim and absf(z - _centro.y) < lim:
		return true
	for e in extras:                      # 0.74: perto de um amigo (host)
		if is_instance_valid(e) and absf(x - e._centro.x) < lim and absf(z - e._centro.y) < lim:
			return true
	return false

# true se (x, z) está a menos de "margem" metros de um prédio com interior aberto (paredes de física)
func perto_de_aberto(x: float, z: float, margem := 8.0) -> bool:
	for idx in abertos:
		var o: int = int(idx) * 5
		if absf(x - _pred[o]) < _pred[o + 2] * 0.5 + margem and absf(z - _pred[o + 1]) < _pred[o + 3] * 0.5 + margem:
			return true
	return false
