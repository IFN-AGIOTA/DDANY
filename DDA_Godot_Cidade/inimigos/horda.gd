extends Node
# HORDA (0.89 · estilo PROJECT ZOMBOID): a POPULAÇÃO de infectados da cidade inteira, que continua existindo longe de
# você. Criada por inimigos/vagos.gd (só no jogo solo e no HOST do multijogador).
#   · A cidade é dividida em quadras de CEL m. Quando um jogador chega a GERAR m de uma quadra, ela ganha a sua
#     população (mais no centro, menos nos parques, nada na água; x opção População; cresce até 1,5x no dia 28).
#   · Longe de todos, os infectados são "virtuais": só GRUPOS no mapa (posição, quantos, para onde vão), baratos.
#     Perto (REAL m) o grupo vira infectados de verdade (inimigos/vago.gd), até o limite do aparelho (POR_VEZ a cada
#     A_CADA s, para não travar o celular); o resto espera.
#     Quem se afasta (SUMIR m) e não está caçando volta a ser virtual NO MESMO LUGAR: a horda que você puxou com
#     tiros continua ali, e ela fica guardada no jogo salvo.
#   · Grupos parados se JUNTAM (até 20, "rally" do Project Zomboid) e andam à toa juntos; a cada 12 h parte deles
#     MIGRA pela cidade. Barulho (tiros, carro, alarme) puxa os grupos até SEGUIR_SOM m.
#   · METAGAME: de tempos em tempos acontecem TIROS AO LONGE e ALARMES em outro bairro (as hordas vão para lá e
#     passam por você) e, uma vez por jogo, o HELICÓPTERO: passa em cima de você por alguns minutos fazendo um barulho
#     enorme e trazendo as hordas da região.
#   · Quadra que perdeu infectados e ficou SEM_VER_H horas sem ninguém por perto volta a ganhar 10% a cada 72 h.
# 1.00 · DIRETOR DE IA (inimigos/diretor.gd): no esfriando/alívio nada novo nasce perto e não há eventos ao longe;
#   os grupos marcados "diretor" são a horda que ele mandou atrás de você (ele corrige o caminho deles).
# Mexa AQUI para: tamanho das quadras, distâncias (gerar / virar real / sumir), densidade por bairro, eventos.
# (os números do estilo Project Zomboid ficam em inimigos/regras_infectados.gd)

const Regras := preload("res://inimigos/regras_infectados.gd")
const SonsBaixados := preload("res://audio/sons_baixados.gd")

const CEL := 100.0                    # m: quadra da população
const GERAR := 450.0                  # quadras até essa distância de um jogador ganham a população
const REAL := 95.0                    # grupo a menos disso de um jogador vira infectados de verdade
const SUMIR := 150.0                  # infectado de verdade (sem caçar) além disso de todos volta a ser grupo
const SIMULAR := 1300.0               # grupos além disso de todos ficam parados (ninguém vê)
const PERTO_NA_TELA := 62.0           # não aparece do nada na sua frente: na tela, só se estiver mais longe que isso
const DENS_CENTRO := 14.0             # infectados por quadra (100 x 100 m) no centro ...
const DENS_LONGE := 4.0               # ... e longe dele
const DENS_PARQUE := 1.2
const RAIO_CENTRO := 3500.0
const VEL_GRUPO := 0.4                # m/s andando à toa
const VEL_SOM := 0.95                 # m/s indo atrás de um barulho
const VEL_MIGRAR := 0.6
const FATIA := 120                    # grupos simulados por quadro (o resto no próximo)
const POR_VEZ := 2                    # no máximo tantos infectados de verdade nascem de cada vez (não trava o celular)
const A_CADA := 0.25                  # s entre uma leva e outra (e entre as conferências de quem volta a ser grupo)
const EVENTO_H := Vector2(1.5, 4.0)   # de quanto em quanto tempo (horas do jogo) acontece um evento ao longe
const HELI_DIA := Vector2(2, 6)       # o helicóptero passa uma vez, num dia entre esses
const HELI_DURA := 150.0              # s (de verdade) que ele fica rondando
const HELI_RAIO := 160.0              # barulho do helicóptero

var gerente: Node = null              # inimigos/vagos.gd
var grupos: Array = []                # {"p": Vector2, "n": int, "d": Vector2 (destino) ou Vector2.INF, "v": m/s, "t": s parado}
var quadras := {}                     # chave -> {"base": int, "mortos": int, "visto": h, "resp": h}
var heli_feito := false
var heli_dia := -1
var _heli_t := 0.0                    # > 0 = helicóptero rondando agora
var _heli_pos := Vector3.ZERO
var _heli_som: AudioStreamPlayer3D = null
var _prox_evento := -1.0              # hora do jogo do próximo evento ao longe
var _i := 0
var _t_quadras := 0.0
var _t_juntar := 0.0
var _t_reais := 0.0
var _ult_redistribuir := -1.0
var _rng := RandomNumberGenerator.new()
static var _wav_heli: AudioStreamWAV = null

func _ready() -> void:
	_rng.randomize()

# hora do jogo (horas desde o começo; igual ao relógio do loot)
func hora() -> float:
	var c = gerente.clima if gerente != null else null
	if c == null:
		return Time.get_ticks_msec() / 1000.0 / 60.0     # sem relógio (testes): 1 "hora" por minuto
	return (float(c.dia) - 1.0) * 24.0 + float(c.hora)

func dia() -> float:
	var c = gerente.clima if gerente != null else null
	return float(c.dia) if c != null else 1.0

static func chave(x: float, z: float) -> int:
	return (floori(x / CEL) + 1000) * 10000 + (floori(z / CEL) + 1000)

static func centro_quadra(k: int) -> Vector2:
	return Vector2((float(k / 10000) - 1000.0 + 0.5) * CEL, (float(k % 10000) - 1000.0 + 0.5) * CEL)

func total_virtuais() -> int:
	var n := 0
	for g in grupos:
		n += int(g["n"])
	return n

# ---------- quadro a quadro (chamado por vagos.gd) ----------
func processar(dt: float) -> void:
	if gerente == null or gerente.cidade == null:
		return
	var centros: Array = gerente._centros()
	if centros.is_empty():
		return
	_t_quadras -= dt
	if _t_quadras <= 0.0:
		_t_quadras = 1.5
		_cuidar_quadras(centros)
	_t_juntar -= dt
	if _t_juntar <= 0.0:
		_t_juntar = 6.0
		_juntar_grupos(centros)
	_simular(dt, centros)
	_t_reais -= dt
	if _t_reais <= 0.0:
		_t_reais = A_CADA
		_virar_reais(centros)
		_recolher_longe(centros)
	_metagame(dt, centros)

# gera a população das quadras perto de alguém e marca quem passou por lá (para o "reaparecer")
func _cuidar_quadras(centros: Array) -> void:
	var h := hora()
	var raio_q := int(ceil(GERAR / CEL))
	for c in centros:
		var cp: Vector3 = c
		var cx := floori(cp.x / CEL)
		var cz := floori(cp.z / CEL)
		for dz in range(-raio_q, raio_q + 1):
			for dx in range(-raio_q, raio_q + 1):
				var k := (cx + dx + 1000) * 10000 + (cz + dz + 1000)
				var meio := centro_quadra(k)
				var d := meio.distance_to(Vector2(cp.x, cp.z))
				if d > GERAR + CEL * 0.7:
					continue
				if not quadras.has(k):
					_gerar_quadra(k, h)
				var q: Dictionary = quadras[k]
				if d < REAL + CEL * 0.5:
					q["visto"] = h
	# 0.89 · REAPARECER (respawn do Project Zomboid): quadra que perdeu gente e ninguém viu por SEM_VER_H horas
	if not Regras.reaparecem():
		return
	for k in quadras:
		var q: Dictionary = quadras[k]
		if int(q["mortos"]) <= 0:
			continue
		if h - float(q["visto"]) < Regras.SEM_VER_H or h - float(q["resp"]) < Regras.REAPARECER_H:
			continue
		var n := mini(int(q["mortos"]), maxi(1, int(round(float(q["base"]) * Regras.REAPARECER_FRACAO * Regras.crescimento(dia())))))
		q["mortos"] = int(q["mortos"]) - n
		q["resp"] = h
		var p := _ponto_livre_em(centro_quadra(k), CEL * 0.5)
		if p != Vector2.INF:
			grupos.append({"p": p, "n": n, "d": Vector2.INF, "v": VEL_GRUPO, "t": 0.0})

# densidade da quadra pelos mapas da cidade (terra, parque, rua) e pela distância do centro
func densidade(k: int) -> float:
	var cid = gerente.cidade
	var m := centro_quadra(k)
	var terra := 0
	var parque := 0
	var n := 0
	for i in 5:
		for j in 5:
			var x := m.x - CEL * 0.5 + (i + 0.5) * CEL / 5.0
			var z := m.y - CEL * 0.5 + (j + 0.5) * CEL / 5.0
			var c := int((x + cid.WORLD.x) / cid.CELL)
			var r := int((z + cid.WORLD.y) / cid.CELL)
			n += 1
			if c < 0 or r < 0 or c >= cid.W or r >= cid.H:
				continue
			var kk: int = r * cid.W + c
			if cid.land[kk] == 1 or cid.road[kk] == 1:
				terra += 1
				if cid.park[kk] == 1:
					parque += 1
	if terra == 0:
		return 0.0
	var perto := clampf(1.0 - (m - cid.DOWNTOWN).length() / RAIO_CENTRO, 0.0, 1.0)
	var f_terra := float(terra) / float(n)
	var f_parque := float(parque) / float(terra)
	return f_terra * (lerpf(DENS_LONGE, DENS_CENTRO, perto) * (1.0 - f_parque) + DENS_PARQUE * f_parque)

func _gerar_quadra(k: int, h: float) -> void:
	var base := int(round(densidade(k) * Regras.mult_pop() * Regras.crescimento(dia()) * gerente.mult_populacao()))
	quadras[k] = {"base": base, "mortos": 0, "visto": -999.0, "resp": h}
	var falta := base
	var meio := centro_quadra(k)
	var tentativas := 0
	while falta > 0 and tentativas < 20:
		tentativas += 1
		# grupos pequenos espalhados (o "rally" junta com o tempo); de vez em quando um grupo grande
		var n := mini(falta, _rng.randi_range(1, 4) if _rng.randf() < 0.8 else _rng.randi_range(6, 12))
		var p := _ponto_livre_em(meio, CEL * 0.5)
		if p == Vector2.INF:
			continue
		grupos.append({"p": p, "n": n, "d": Vector2.INF, "v": VEL_GRUPO, "t": _rng.randf_range(0.0, 60.0)})
		falta -= n

func _ponto_livre_em(meio: Vector2, raio: float) -> Vector2:
	for t in 8:
		var p := meio + Vector2(_rng.randf_range(-raio, raio), _rng.randf_range(-raio, raio))
		if gerente._livre(p.x, p.y):
			return p
	return Vector2.INF

# grupos parados perto se juntam (até GRUPO_MAX); os que não cabem se afastam um pouco.
# Só os perto de alguém, e cada um só olha os vizinhos (tabela por quadradinhos de GRUPO_JUNTAR m).
func _juntar_grupos(centros: Array) -> void:
	var tab := {}
	var lista: Array = []
	for g in grupos:
		if g["d"] != Vector2.INF or not _perto_de_alguem(g["p"], SIMULAR, centros):
			continue
		var p: Vector2 = g["p"]
		var k := Vector2i(floori(p.x / Regras.GRUPO_JUNTAR), floori(p.y / Regras.GRUPO_JUNTAR))
		if not tab.has(k):
			tab[k] = []
		tab[k].append(g)
		lista.append([k, g])
	for x in lista:
		var a: Dictionary = x[1]
		if a["d"] != Vector2.INF:
			continue
		var k: Vector2i = x[0]
		var feito := false
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if feito:
					break
				for b in tab.get(k + Vector2i(dx, dz), []):
					if b == a or b["d"] != Vector2.INF:
						continue
					var d: float = (a["p"] as Vector2).distance_to(b["p"])
					if d > Regras.GRUPO_JUNTAR:
						continue
					if int(a["n"]) + int(b["n"]) <= Regras.GRUPO_MAX:
						# o menor anda até o maior e junta quando chegar
						var menor: Dictionary = b if int(a["n"]) >= int(b["n"]) else a
						var maior: Dictionary = a if menor == b else b
						menor["d"] = maior["p"]
						menor["v"] = VEL_GRUPO
						menor["juntar"] = true
						feito = true
						break
					elif d < Regras.GRUPO_SEPARAR:
						var fora: Vector2 = ((b["p"] as Vector2) - (a["p"] as Vector2)).normalized()
						b["d"] = (b["p"] as Vector2) + fora * (Regras.GRUPO_SEPARAR - d + 3.0)
						b["v"] = VEL_GRUPO
						feito = true
						break

func _perto_de_alguem(p: Vector2, raio: float, centros: Array) -> bool:
	for c in centros:
		var cp: Vector3 = c
		if Vector2(cp.x - p.x, cp.z - p.y).length_squared() < raio * raio:
			return true
	return false

func _dist_menor(p: Vector2, centros: Array) -> float:
	var m := INF
	for c in centros:
		var cp: Vector3 = c
		m = minf(m, Vector2(cp.x - p.x, cp.z - p.y).length())
	return m

# anda com uma fatia dos grupos por quadro (o tempo de cada um é acumulado)
func _simular(dt: float, centros: Array) -> void:
	var n := grupos.size()
	if n == 0:
		return
	var h := hora()
	if _ult_redistribuir < 0.0:
		_ult_redistribuir = h
	var redistribuir := h - _ult_redistribuir >= Regras.REDISTRIBUIR_H
	if redistribuir:
		_ult_redistribuir = h
	var juntou := false
	for c in mini(FATIA, n):
		_i = (_i + 1) % n
		var g: Dictionary = grupos[_i]
		var passo := clampf(dt * float(n) / float(mini(FATIA, n)), 0.0, 5.0)
		var p: Vector2 = g["p"]
		if redistribuir and _rng.randf() < 0.45:
			# 0.89 · MIGRAÇÃO: parte das hordas vai para outro canto da cidade
			var a := _rng.randf() * TAU
			g["d"] = p + Vector2(cos(a), sin(a)) * _rng.randf_range(150.0, 600.0)
			g["v"] = VEL_MIGRAR
		if not _perto_de_alguem(p, SIMULAR, centros):
			continue
		var d: Vector2 = g["d"]
		if d == Vector2.INF:
			g["t"] = float(g["t"]) + passo
			if float(g["t"]) > 45.0 and _rng.randf() < 0.02 * passo:
				# anda um pouco à toa (juntos)
				var a := _rng.randf() * TAU
				g["d"] = p + Vector2(cos(a), sin(a)) * _rng.randf_range(8.0, 30.0)
				g["v"] = VEL_GRUPO
				g["t"] = 0.0
			continue
		var para := d - p
		var L := para.length()
		var anda := float(g["v"]) * passo
		if L <= anda:
			g["p"] = d
			g["d"] = Vector2.INF
			g["t"] = 0.0
			if g.get("juntar", false):
				g.erase("juntar")
				juntou = true
		else:
			g["p"] = p + para / L * anda
	if juntou:
		_fundir_iguais()

# grupos parados que chegaram no mesmo lugar viram um só (tabela por quadradinhos de 3 m)
func _fundir_iguais() -> void:
	var novos: Array = []
	var tab := {}
	for g in grupos:
		if g["d"] != Vector2.INF:
			novos.append(g)
			continue
		var p: Vector2 = g["p"]
		var k := Vector2i(floori(p.x / 3.0), floori(p.y / 3.0))
		var junto := false
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if junto:
					break
				for o in tab.get(k + Vector2i(dx, dz), []):
					if (o["p"] as Vector2).distance_to(p) < 2.5 and int(o["n"]) + int(g["n"]) <= Regras.GRUPO_MAX:
						o["n"] = int(o["n"]) + int(g["n"])
						junto = true
						break
		if not junto:
			novos.append(g)
			if not tab.has(k):
				tab[k] = []
			tab[k].append(g)
	grupos = novos

# grupo perto de alguém vira infectados de verdade (os mais perto primeiro), até o limite do aparelho
func _virar_reais(centros: Array) -> void:
	var livres: int = mini(gerente.vagas_reais(), POR_VEZ)
	if livres <= 0:
		return
	var dir = gerente.get("diretor")
	var longe_min: float = dir.dist_min_nascer() if dir != null else 0.0
	var perto: Array = []
	for i in grupos.size():
		var g: Dictionary = grupos[i]
		var dmin := _dist_menor(g["p"], centros)
		if dmin < REAL and (dmin >= longe_min or g.has("diretor")):
			perto.append([dmin, i])
	if perto.is_empty():
		return
	perto.sort_custom(func(a, b): return a[0] < b[0])
	var tirar := {}
	for x in perto:
		if livres <= 0:
			break
		var g: Dictionary = grupos[x[1]]
		var p: Vector2 = g["p"]
		if not gerente._livre(p.x, p.y):
			var q := _ponto_livre_em(p, 12.0)
			if q == Vector2.INF:
				continue
			p = q
		var p3 := Vector3(p.x, gerente.mundo.altura(p.x, p.y), p.y)
		if float(x[0]) < PERTO_NA_TELA and gerente._visivel(p3):
			continue                                        # não "nasce" na sua frente: espera sair da tela
		var n := mini(int(g["n"]), livres)
		var destino := Vector3.INF
		if g["d"] != Vector2.INF:
			var d2: Vector2 = g["d"]
			destino = Vector3(d2.x, 0.0, d2.y)
		var r := 1.5 + sqrt(float(n)) * 1.1
		var feitos := 0
		for k in n:
			for t in 4:
				var q := p + Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r, r))
				if gerente._livre(q.x, q.y):
					var nv = gerente._criar(Vector3(q.x, gerente.mundo.altura(q.x, q.y), q.y), destino, true)
					if dir != null and g.has("diretor"):
						dir.novo_membro(nv)
					feitos += 1
					break
		livres -= feitos
		g["n"] = int(g["n"]) - feitos
		if int(g["n"]) <= 0:
			tirar[x[1]] = true
	if not tirar.is_empty():
		var novos: Array = []
		for i in grupos.size():
			if not tirar.has(i):
				novos.append(grupos[i])
		grupos = novos

# infectado de verdade da horda longe de todos (e sem caçar) volta a ser grupo no mesmo lugar
func _recolher_longe(centros: Array) -> void:
	for i in range(gerente.vivos.size() - 1, -1, -1):
		var v = gerente.vivos[i]
		if not is_instance_valid(v) or not bool(v.get("da_horda")) or v.esta_cacando():
			continue
		var p: Vector3 = v.global_position
		if _dist_menor(Vector2(p.x, p.z), centros) < SUMIR:
			continue
		recolher(v)
		gerente.vivos.remove_at(i)
		gerente.por_id.erase(v.id_rede)
		v.queue_free()

func recolher(v: Node) -> void:
	var p: Vector3 = v.global_position
	var p2 := Vector2(p.x, p.z)
	var dest := Vector2.INF
	if int(v.estado) == 1:                 # investigando: continua indo para o barulho
		var d: Vector3 = v._destino
		dest = Vector2(d.x, d.z)
	for g in grupos:
		if (g["p"] as Vector2).distance_to(p2) < 12.0 and int(g["n"]) < Regras.GRUPO_MAX:
			g["n"] = int(g["n"]) + 1
			if dest != Vector2.INF and g["d"] == Vector2.INF:
				g["d"] = dest
				g["v"] = VEL_SOM
			return
	grupos.append({"p": p2, "n": 1, "d": dest, "v": VEL_SOM if dest != Vector2.INF else VEL_GRUPO, "t": 0.0})

# barulho: os grupos que ouvem (até SEGUIR_SOM m) vão até lá (com erro, igual ao infectado de verdade)
func barulho(pos: Vector3, raio: float) -> void:
	var r := minf(raio * Regras.mult_audicao(), Regras.SEGUIR_SOM)
	if r < 25.0:
		return                                              # passos e coisas baixas: grupo longe nem nota
	var p := Vector2(pos.x, pos.z)
	for g in grupos:
		var d: float = (g["p"] as Vector2).distance_to(p)
		if d > r:
			continue
		var erro := minf(d * 0.12, 10.0) * Regras.erro_audicao()
		g["d"] = p + Vector2(_rng.randf_range(-erro, erro), _rng.randf_range(-erro, erro))
		g["v"] = VEL_SOM
		g.erase("juntar")

# um infectado morreu aqui (para o "reaparecer")
func morreu_em(pos: Vector3) -> void:
	var k := chave(pos.x, pos.z)
	if quadras.has(k):
		quadras[k]["mortos"] = int(quadras[k]["mortos"]) + 1

# ---------- METAGAME: tiros e alarmes ao longe, helicóptero ----------
func _metagame(dt: float, centros: Array) -> void:
	var h := hora()
	if _prox_evento < 0.0:
		_prox_evento = h + _rng.randf_range(EVENTO_H.x, EVENTO_H.y)
	var dir = gerente.get("diretor")
	if h >= _prox_evento and not bool(gerente.get("sem_jogador")) and (dir == null or dir.pode_evento()):
		_prox_evento = h + _rng.randf_range(EVENTO_H.x, EVENTO_H.y)
		evento_ao_longe(centros[_rng.randi() % centros.size()])
	if heli_dia < 0:
		heli_dia = _rng.randi_range(HELI_DIA.x, HELI_DIA.y)
	if not heli_feito and _heli_t <= 0.0 and int(dia()) >= heli_dia and gerente.clima != null \
			and float(gerente.clima.hora) > 9.0 and float(gerente.clima.hora) < 17.0:
		comecar_helicoptero()
	if _heli_t > 0.0:
		_helicoptero(dt, centros)

# tiros ou um alarme num ponto a 250-650 m: as hordas de lá (e do caminho) vão para o lugar
func evento_ao_longe(c: Vector3) -> Vector3:
	var a := _rng.randf() * TAU
	var p := c + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(250.0, 650.0)
	var sirene := _rng.randf() < 0.3
	barulho(p, 300.0 if sirene else 160.0)
	gerente.barulho_real(p, 300.0 if sirene else 160.0)
	# o som chega baixinho, da direção certa
	var som := AudioStreamPlayer3D.new()
	var jog = gerente.jogador
	if jog == null or not is_instance_valid(jog) or bool(gerente.get("sem_jogador")):
		return p
	var dir: Vector3 = p - jog.global_position
	dir.y = 0.0
	som.position = jog.global_position + dir.normalized() * 40.0 + Vector3(0, 6, 0)
	som.max_distance = 400.0
	som.unit_size = 18.0
	som.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	if sirene:
		som.stream = SonsBaixados.som("ambiente/sirene")
		som.volume_db = -10.0
	else:
		var arma: String = ["pistola", "ak", "espingarda", "m4", "rifle_caca"][_rng.randi() % 5]
		som.stream = SonsBaixados.som("armas/longe_%s_%d" % [arma, _rng.randi() % 2])
		som.volume_db = -6.0
	if som.stream == null:
		som.free()
		return p
	gerente.add_child(som)
	som.play()
	som.finished.connect(som.queue_free)
	if not sirene:
		# rajada: mais 1 a 4 tiros
		for i in _rng.randi_range(1, 4):
			var t := get_tree().create_timer(_rng.randf_range(0.4, 2.5) * (i + 1))
			t.timeout.connect(som.play)        # 0.94: ligado ao próprio som (se ele já sumiu, a ligação some junto)
	return p

func comecar_helicoptero() -> void:
	heli_feito = true
	_heli_t = HELI_DURA
	var j = gerente.jogador
	var base: Vector3 = j.global_position if j != null and is_instance_valid(j) else Vector3.ZERO
	_heli_pos = base + Vector3(-300.0, 90.0, -200.0)
	if _heli_som == null and not bool(gerente.get("sem_jogador")):
		_heli_som = AudioStreamPlayer3D.new()
		_heli_som.stream = _som_helicoptero()
		_heli_som.max_distance = 900.0
		_heli_som.unit_size = 60.0
		_heli_som.volume_db = 2.0
		_heli_som.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		gerente.add_child(_heli_som)
		_heli_som.play()

var _heli_barulho := 0.0
func _helicoptero(dt: float, centros: Array) -> void:
	_heli_t -= dt
	# ronda em cima de um dos jogadores (segue com atraso, em círculos)
	var alvo: Vector3 = centros[0]
	var ang := Time.get_ticks_msec() / 1000.0 * 0.15
	var quer := alvo + Vector3(cos(ang) * 60.0, 85.0, sin(ang) * 60.0)
	if _heli_t < 25.0:
		quer = _heli_pos + Vector3(400.0, 30.0, 300.0)            # vai embora
	_heli_pos = _heli_pos.move_toward(quer, dt * 22.0)
	if _heli_som != null:
		_heli_som.global_position = _heli_pos
		if _heli_t <= 0.0:
			_heli_som.queue_free()
			_heli_som = null
	_heli_barulho -= dt
	if _heli_barulho <= 0.0 and _heli_t > 25.0:
		_heli_barulho = 4.0
		var chao := Vector3(_heli_pos.x, 0.0, _heli_pos.z)
		barulho(chao, HELI_RAIO)
		gerente.barulho_real(chao, HELI_RAIO)

func helicoptero_no_ar() -> bool:
	return _heli_t > 0.0

# hélice batendo (pulsos de ar ~6 por segundo) + turbina: um laço de 2 s, feito uma vez só
static func _som_helicoptero() -> AudioStreamWAV:
	if _wav_heli != null:
		return _wav_heli
	var taxa := 22050
	var dur := 2.0
	var n := int(taxa * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var lp := 0.0
	var lp2 := 0.0
	var fase := 0.0
	for i in n:
		var t := float(i) / taxa
		var r := rng.randf_range(-1.0, 1.0)
		lp += (r - lp) * 0.08
		lp2 += (lp - lp2) * 0.1
		var pa := fmod(t * 6.0, 1.0)                         # 12 pulsos em 2 s (o laço fecha certinho)
		var pulso := exp(-pa * 9.0)
		fase += 1650.0 / taxa
		var turbina := sin(TAU * fase) * 0.05 + sin(TAU * fase * 1.51) * 0.03
		var s := lp2 * 5.0 * (0.25 + 0.75 * pulso) + turbina
		dados.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.stereo = false
	w.data = dados
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	_wav_heli = w
	return w

# ---------- jogo salvo ----------
func salvar(reais: Array) -> Dictionary:
	var gs := PackedFloat32Array()
	for g in grupos:
		var d: Vector2 = g["d"]
		gs.append_array([g["p"].x, g["p"].y, float(g["n"]), d.x if d != Vector2.INF else 1e9, d.y if d != Vector2.INF else 1e9])
	# os infectados de verdade da horda viram grupos no lugar onde estão (voltam ali ao carregar)
	for v in reais:
		if is_instance_valid(v) and bool(v.get("da_horda")) and int(v.estado) != 4:
			var p: Vector3 = v.global_position
			gs.append_array([p.x, p.z, 1.0, 1e9, 1e9])
	var qs := PackedFloat32Array()
	for k in quadras:
		var q: Dictionary = quadras[k]
		qs.append_array([float(k), float(q["base"]), float(q["mortos"]), float(q["visto"]), float(q["resp"])])
	return {"g": gs, "q": qs, "heli": heli_feito, "heli_dia": heli_dia, "ev": _prox_evento, "red": _ult_redistribuir}

func carregar(d: Dictionary) -> void:
	grupos.clear()
	quadras.clear()
	var gs := PackedFloat32Array(d.get("g", []))           # (no arquivo JSON vira lista comum)
	for i in range(0, gs.size() - 4, 5):
		var dd := Vector2.INF if gs[i + 3] > 1e8 else Vector2(gs[i + 3], gs[i + 4])
		grupos.append({"p": Vector2(gs[i], gs[i + 1]), "n": int(gs[i + 2]), "d": dd, "v": VEL_SOM if dd != Vector2.INF else VEL_GRUPO, "t": 0.0})
	var qs := PackedFloat32Array(d.get("q", []))
	for i in range(0, qs.size() - 4, 5):
		quadras[int(qs[i])] = {"base": int(qs[i + 1]), "mortos": int(qs[i + 2]), "visto": qs[i + 3], "resp": qs[i + 4]}
	_fundir_iguais()
	heli_feito = bool(d.get("heli", false))
	heli_dia = int(d.get("heli_dia", -1))
	_prox_evento = float(d.get("ev", -1.0))
	_ult_redistribuir = float(d.get("red", -1.0))
