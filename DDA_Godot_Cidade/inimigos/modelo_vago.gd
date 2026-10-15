extends Node3D
# MODELO DO VAGO (infectado): humano feito de caixas, com roupas civis rasgadas e animação por código.
# Cada parte do corpo é UMA malha (caixas juntadas com mundo/malhas.gd) e todas usam o MESMO material
# (cor por vértice) = poucas chamadas de desenho no celular (~11 por Vago, contando a sombra falsa).
# As roupas são sorteadas: civil (camisa/camiseta e calça), jaqueta aberta, moletom com capuz, policial,
# médico/enfermeiro (pijama cirúrgico ou jaleco branco) e operário (colete refletivo e capacete).
# Pele cinza-esverdeada, olhos amarelados, manchas de sangue escuro, corpo curvado e uma perna que manca.
# Até MAX_VARIANTES conjuntos de malhas ficam guardados e são reaproveitados (não gera malha a cada Vago).
#
# Animações (sem esqueleto, só girando os pivôs): parado balançando, andar arrastado, correr com os braços
# para a frente, ataque (ergue os braços e desce), tranco ao levar tiro e queda ao morrer (fica no chão).
# A frente do modelo é -Z (igual à Godot). Altura ~1,75 m.
#
# Mexa AQUI para: cores das roupas/pele (listas no topo), quantas variações de roupa (MAX_VARIANTES),
# postura (CURVA), velocidade das animações (ver atualizar()).

const Malhas := preload("res://mundo/malhas.gd")

const MAX_VARIANTES := 16
const ALT_QUADRIL := 0.97        # altura da junta do quadril (m)
const CURVA := 0.24              # quanto o tronco fica curvado para a frente (rad)
const DUR_ATAQUE := 0.95         # preparo 0,4 s + golpe + volta
const PREPARO := 0.4

const PELES := [Color(0.47, 0.52, 0.42), Color(0.55, 0.57, 0.48), Color(0.42, 0.47, 0.41), Color(0.52, 0.5, 0.45),
	Color(0.44, 0.5, 0.46), Color(0.38, 0.4, 0.34)]
const CAMISAS := [Color(0.42, 0.4, 0.36), Color(0.3, 0.34, 0.4), Color(0.45, 0.25, 0.22), Color(0.55, 0.53, 0.47),
	Color(0.24, 0.3, 0.25), Color(0.36, 0.31, 0.38), Color(0.6, 0.58, 0.55), Color(0.5, 0.42, 0.3), Color(0.2, 0.2, 0.22)]
const CALCAS := [Color(0.2, 0.25, 0.34), Color(0.26, 0.28, 0.32), Color(0.33, 0.29, 0.22), Color(0.17, 0.17, 0.18),
	Color(0.38, 0.35, 0.28), Color(0.27, 0.31, 0.27)]
const JAQUETAS := [Color(0.3, 0.22, 0.15), Color(0.16, 0.17, 0.19), Color(0.28, 0.32, 0.24), Color(0.35, 0.3, 0.24),
	Color(0.22, 0.26, 0.33)]
const MOLETONS := [Color(0.33, 0.33, 0.35), Color(0.2, 0.24, 0.3), Color(0.38, 0.2, 0.18), Color(0.25, 0.3, 0.22),
	Color(0.15, 0.15, 0.16)]
const CABELOS := [Color(0.1, 0.08, 0.06), Color(0.22, 0.15, 0.09), Color(0.35, 0.3, 0.22), Color(0.4, 0.4, 0.38),
	Color(0.05, 0.05, 0.05)]
const SANGUE := Color(0.24, 0.02, 0.02)
const SANGUE_SECO := Color(0.17, 0.05, 0.04)
const TIPOS := ["civil", "civil", "civil", "civil", "jaqueta", "jaqueta", "moletom", "moletom", "policia", "medico", "operario"]

static var _variantes: Array = []
static var _mat: StandardMaterial3D = null
static var _sombra_malha: PlaneMesh = null

# pivôs
var queda: Node3D                # gira o corpo inteiro ao morrer (pivô nos pés)
var quadril: Node3D
var tronco: Node3D
var cabeca: Node3D
var ombro: Array[Node3D] = []    # 0 = esquerdo (-X) · 1 = direito (+X)
var cotovelo: Array[Node3D] = []
var coxa: Array[Node3D] = []
var joelho: Array[Node3D] = []
var sombra: MeshInstance3D

# jeito de cada um (sorteado)
var _perna_ruim := 0             # perna que manca
var _manca := 0.55               # amplitude da perna ruim
var _braco_erguido: Array[float] = [0.0, 0.0]
var _inclina := 0.0              # tronco torto para um lado
var _cab_incl := 0.0             # cabeça caída para um lado
var _fase_idle := 0.0

# estado da animação
var _t := 0.0
var _ph := 0.0
var _mv := 0.0
var _corr := 0.0
var _at := -1.0                  # -1 = sem ataque · 0..DUR_ATAQUE
var _fl := 0.0                   # tranco do tiro (1 -> 0)
var _fl_lado := 0.0
var _esp := 0.0                  # espasmo da cabeça
var _esp_t := 3.0
var _esp_dir := Vector3.ZERO
var morto := false
var _mt := 0.0
var _para_tras := true
var _pose_final := {}

func montar(semente: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = semente
	if _mat == null:
		_mat = Malhas.mat_cores(0.92)
	var v: Dictionary
	if _variantes.size() < MAX_VARIANTES and (_variantes.size() < 6 or r.randf() < 0.5):
		v = _criar_variante(r.randi())
		_variantes.append(v)
	else:
		v = _variantes[r.randi() % _variantes.size()]
	_perna_ruim = r.randi() % 2
	_manca = r.randf_range(0.35, 0.75)
	_braco_erguido = [r.randf_range(0.0, 1.0), r.randf_range(0.0, 1.0)]
	_braco_erguido[r.randi() % 2] *= 0.3
	_inclina = r.randf_range(-0.09, 0.09)
	_cab_incl = r.randf_range(-0.3, 0.3)
	_fase_idle = r.randf() * TAU
	_ph = r.randf() * TAU
	scale = Vector3.ONE * r.randf_range(0.94, 1.05)

	queda = _pivo(self, Vector3.ZERO)
	quadril = _pivo(queda, Vector3(0, ALT_QUADRIL, 0))
	tronco = _pivo(quadril, Vector3.ZERO)
	_parte(tronco, v["tronco"])
	cabeca = _pivo(tronco, Vector3(0, 0.6, 0))
	_parte(cabeca, v["cabeca"])
	for lado in 2:
		var s := -1.0 if lado == 0 else 1.0
		var o := _pivo(tronco, Vector3(s * 0.245, 0.49, 0.0))
		_parte(o, v["braco%d" % lado])
		var c := _pivo(o, Vector3(0, -0.29, 0))
		_parte(c, v["antebraco%d" % lado])
		ombro.append(o)
		cotovelo.append(c)
		var cx := _pivo(quadril, Vector3(s * 0.095, -0.02, 0.0))
		_parte(cx, v["coxa%d" % lado])
		var j := _pivo(cx, Vector3(0, -0.44, 0))
		_parte(j, v["canela%d" % lado])
		coxa.append(cx)
		joelho.append(j)
	# sombra falsa (barata, ajuda a "assentar" o corpo no chão)
	if _sombra_malha == null:
		_sombra_malha = PlaneMesh.new()
		_sombra_malha.size = Vector2(1.1, 1.1)
		var sm := StandardMaterial3D.new()
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(0, 0, 0, 0.5))
		gr.set_color(1, Color(0, 0, 0, 0))
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		sm.albedo_texture = gt
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_sombra_malha.material = sm
	sombra = MeshInstance3D.new()
	sombra.mesh = _sombra_malha
	sombra.position.y = 0.04
	sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sombra.visibility_range_end = 60.0
	add_child(sombra)
	atualizar(0.0, 0.0)

func _pivo(pai: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	pai.add_child(n)
	return n

func _parte(pai: Node3D, malha: ArrayMesh) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.visibility_range_end = 140.0
	pai.add_child(mi)

# posição (global) do centro da cabeça: a colisão da cabeça (tiro x3) acompanha a animação
func pos_cabeca() -> Vector3:
	return cabeca.global_transform * Vector3(0, 0.12, -0.01)

# ---------- comandos da animação ----------
func atacar() -> void:
	_at = 0.0

func levar_golpe(forca: float, lado: float = 0.0) -> void:
	_fl = clampf(_fl + forca, 0.0, 1.3)
	_fl_lado = lado

func morrer(para_tras: bool) -> void:
	if morto:
		return
	morto = true
	_mt = 0.0
	_para_tras = para_tras
	var r := randf()
	var s := 1.0 if randf() < 0.5 else -1.0
	if para_tras:
		# de costas: joelhos um pouco dobrados, braços abertos, cabeça virada para o lado
		_pose_final = {"coxa": [0.35 + r * 0.4, 0.1], "joelho": [-0.7 - r * 0.5, -0.15], "coxa_z": [-0.15, 0.2],
			"ombro": [0.3, 1.2 * r], "ombro_z": [-1.1 - r * 0.4, 0.9 + r * 0.5], "cotovelo": [0.5, 0.9],
			"cab_x": 0.15, "cab_y": 0.9 * s, "tronco_x": 0.05}
	else:
		# de bruços: um braço acima da cabeça, o outro junto do corpo, cabeça de lado
		_pose_final = {"coxa": [0.05, -0.1], "joelho": [-0.25, -0.05 - r * 0.4], "coxa_z": [-0.12, 0.1],
			"ombro": [2.6, 0.2], "ombro_z": [-0.4, 0.25], "cotovelo": [0.6, 0.2],
			"cab_x": -0.3, "cab_y": 1.0 * s, "tronco_x": 0.0}

# ---------- animação (chamar todo quadro, ou a cada poucos quadros de longe) ----------
func atualizar(dt: float, vel: float) -> void:
	_t += dt
	if morto:
		_animar_morte(dt)
		return
	var corre_alvo := clampf((vel - 1.8) / 2.4, 0.0, 1.0)
	_corr = lerpf(_corr, corre_alvo, minf(1.0, dt * 5.0))
	_mv = lerpf(_mv, clampf(vel / 0.5, 0.0, 1.0), minf(1.0, dt * 6.0))
	var passo := lerpf(0.4, 1.05, _corr)                 # metros por meia passada
	_ph = fmod(_ph + dt * vel / passo * PI, TAU)
	_fl *= exp(-dt * 6.0)
	# espasmo: de vez em quando a cabeça dá um tranco
	_esp_t -= dt
	if _esp_t <= 0.0:
		_esp_t = randf_range(1.5, 6.0)
		_esp = 1.0
		_esp_dir = Vector3(randf_range(-0.5, 0.5), randf_range(-0.8, 0.8), randf_range(-0.6, 0.6))
	_esp *= exp(-dt * 9.0)
	var s := sin(_ph)
	var c := cos(_ph)
	var idle := sin(_t * 0.9 + _fase_idle)
	var nao_corre := 1.0 - _corr
	# ----- pernas -----
	var amp := lerpf(0.34, 0.9, _corr) * _mv
	for lado in 2:
		var ph := _ph + PI * lado
		var sl := sin(ph)
		var cl := cos(ph)
		var ruim := lado == _perna_ruim
		var a := amp * (lerpf(_manca, 1.0, _corr) if ruim else 1.0)
		coxa[lado].rotation.x = sl * a + _corr * 0.18
		coxa[lado].rotation.y = (0.22 if ruim else 0.0) * nao_corre * (1.0 if lado == 1 else -1.0)
		coxa[lado].rotation.z = (0.05 if lado == 1 else -0.05)
		var flex := lerpf(0.35 if ruim else 0.55, 1.6, _corr)
		joelho[lado].rotation.x = -(maxf(0.0, cl) * flex * _mv + 0.1 + 0.25 * _corr * _mv)
	# sobe e desce + manca (afunda quando pisa na perna ruim)
	var bob := (absf(c) - 0.6) * lerpf(0.03, 0.07, _corr) * _mv
	var ruim_pisa := maxf(0.0, -sin(_ph + PI * _perna_ruim)) * 0.035 * _mv * nao_corre
	quadril.position.y = ALT_QUADRIL - 0.035 - 0.07 * _corr + bob - ruim_pisa
	quadril.rotation.y = -s * 0.1 * _mv
	quadril.rotation.z = ruim_pisa * (1.5 if _perna_ruim == 0 else -1.5)
	# ----- tronco -----
	var tr_x := -(CURVA + 0.4 * _corr) + idle * 0.03 * (1.0 - _mv)
	var tr_z := _inclina + s * 0.09 * _mv * nao_corre + sin(_t * 0.6 + _fase_idle) * 0.035
	var tr_y := s * lerpf(0.14, 0.25, _corr) * _mv
	# ----- cabeça -----
	var cb_x := 0.18 - 0.42 * _corr + sin(_t * 1.3 + _fase_idle) * 0.05
	var cb_z := _cab_incl * (1.0 - 0.6 * _corr) + sin(_t * 0.8) * 0.06
	var cb_y := sin(_t * 0.37 + _fase_idle) * 0.3 * (1.0 - _mv) * nao_corre
	cb_x += _esp_dir.x * _esp
	cb_y += _esp_dir.y * _esp
	cb_z += _esp_dir.z * _esp
	# ----- braços -----
	var sh_x: Array[float] = [0.0, 0.0]
	var sh_z: Array[float] = [0.0, 0.0]
	var el_x: Array[float] = [0.0, 0.0]
	for lado in 2:
		var sg := -1.0 if lado == 0 else 1.0
		var ph_b := _ph + PI * lado + PI                  # braço vai com a perna do outro lado
		# andando: um braço meio erguido para a frente, o outro pendurado balançando
		var anda_x := _braco_erguido[lado] * 0.95 + 0.12 + sin(ph_b) * 0.22 * _mv + idle * 0.05
		var anda_el := 0.25 + _braco_erguido[lado] * 0.35
		# correndo: os dois braços esticados para a frente, se debatendo
		var corre_x := 1.25 + sin(ph_b) * 0.4
		var corre_el := 0.15 + maxf(0.0, cos(ph_b)) * 0.35
		sh_x[lado] = lerpf(anda_x, corre_x, _corr)
		el_x[lado] = lerpf(anda_el, corre_el, _corr)
		sh_z[lado] = sg * (0.1 + 0.08 * _corr + absf(idle) * 0.03)
	# ----- ataque: ergue os dois braços e desce com o corpo -----
	if _at >= 0.0:
		_at += dt
		var w := 1.0
		var at_sh := 0.0
		var at_el := 0.0
		var at_tr := 0.0
		var at_cb := 0.0
		if _at < PREPARO:
			var k := smoothstep(0.0, 1.0, _at / PREPARO)
			at_sh = lerpf(0.8, 2.5, k)
			at_el = lerpf(0.3, 1.0, k)
			at_tr = lerpf(-0.2, 0.12, k)
			at_cb = lerpf(0.0, -0.35, k)
			w = minf(1.0, _at / 0.12)
		elif _at < PREPARO + 0.18:
			var k := (_at - PREPARO) / 0.18
			k = k * k
			at_sh = lerpf(2.5, 0.35, k)
			at_el = lerpf(1.0, 0.15, k)
			at_tr = lerpf(0.12, -0.75, k)
			at_cb = lerpf(-0.35, 0.35, k)
		else:
			at_sh = 0.35
			at_el = 0.15
			at_tr = -0.75
			at_cb = 0.35
			w = clampf(1.0 - (_at - PREPARO - 0.18) / (DUR_ATAQUE - PREPARO - 0.18), 0.0, 1.0)
		if _at >= DUR_ATAQUE:
			_at = -1.0
		for lado in 2:
			var atraso := 0.15 * lado                     # um braço um pouco depois do outro
			sh_x[lado] = lerpf(sh_x[lado], at_sh - atraso, w)
			el_x[lado] = lerpf(el_x[lado], at_el, w)
			sh_z[lado] = lerpf(sh_z[lado], (-1.0 if lado == 0 else 1.0) * 0.25, w)
		tr_x = lerpf(tr_x, at_tr, w)
		cb_x = lerpf(cb_x, at_cb, w)
	# ----- tranco do tiro -----
	if _fl > 0.01:
		tr_x += _fl * 0.55
		tr_z += _fl * _fl_lado * 0.3
		cb_x -= _fl * 0.7
		for lado in 2:
			sh_z[lado] += (-1.0 if lado == 0 else 1.0) * _fl * 0.5
			sh_x[lado] -= _fl * 0.4
	tronco.rotation = Vector3(tr_x, tr_y, tr_z)
	cabeca.rotation = Vector3(cb_x, cb_y, cb_z)
	for lado in 2:
		ombro[lado].rotation = Vector3(sh_x[lado], 0.0, sh_z[lado])
		cotovelo[lado].rotation.x = el_x[lado]

func _animar_morte(dt: float) -> void:
	_mt += dt
	var k := minf(1.0, dt * 7.0)
	var pf := _pose_final
	# 1) joelhos cedem · 2) o corpo tomba (acelerando, como na gravidade) · 3) pequeno quique e fica parado
	var a := clampf((_mt - 0.12) / 0.6, 0.0, 1.0)
	var ang := PI * 0.5 * a * a
	if _mt > 0.72:
		var u := _mt - 0.72
		ang -= sin(u * 16.0) * exp(-u * 9.0) * 0.07
	var sgn := 1.0 if _para_tras else -1.0
	queda.rotation.x = ang * sgn
	queda.position.y = 0.11 * sin(ang)
	queda.position.z = 0.15 * a * sgn                     # cai um pouco além dos pés
	var cede := clampf(_mt / 0.25, 0.0, 1.0) * (1.0 - a)
	quadril.position.y = lerpf(quadril.position.y, ALT_QUADRIL - 0.12 * cede, k)
	for lado in 2:
		coxa[lado].rotation.x = lerpf(coxa[lado].rotation.x, float(pf["coxa"][lado]) + cede * 0.4, k)
		coxa[lado].rotation.y = lerpf(coxa[lado].rotation.y, 0.0, k)
		coxa[lado].rotation.z = lerpf(coxa[lado].rotation.z, float(pf["coxa_z"][lado]), k)
		joelho[lado].rotation.x = lerpf(joelho[lado].rotation.x, float(pf["joelho"][lado]) - cede * 0.7, k)
		var o := ombro[lado]
		o.rotation.x = lerp_angle(o.rotation.x, float(pf["ombro"][lado]), k * 0.8)
		o.rotation.z = lerpf(o.rotation.z, float(pf["ombro_z"][lado]), k * 0.8)
		cotovelo[lado].rotation.x = lerpf(cotovelo[lado].rotation.x, float(pf["cotovelo"][lado]), k)
	tronco.rotation = tronco.rotation.lerp(Vector3(float(pf["tronco_x"]), 0.0, 0.0), k)
	cabeca.rotation = cabeca.rotation.lerp(Vector3(float(pf["cab_x"]), float(pf["cab_y"]), 0.0), k * 0.6)
	sombra.scale = Vector3(1.0, 1.0, 1.0 + a * 0.9)
	sombra.position.z = 0.75 * a * sgn

# ---------- malhas (uma variação = um conjunto de roupas/pele) ----------
static func _tom(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0))

static func _sorteia(r: RandomNumberGenerator, lista: Array) -> Color:
	return _tom(lista[r.randi() % lista.size()], r.randf_range(0.85, 1.08))

static func _criar_variante(semente: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = semente
	var tipo: String = TIPOS[r.randi() % TIPOS.size()]
	var pele := _sorteia(r, PELES)
	var camisa := _sorteia(r, CAMISAS)
	var calca := _sorteia(r, CALCAS)
	var sapato := _tom(Color(0.12, 0.1, 0.09), r.randf_range(0.7, 1.6))
	var cabelo := _sorteia(r, CABELOS)
	var manga_longa := r.randf() < 0.45
	var manga := camisa
	var sobre := Color.BLACK               # jaqueta/moletom/colete por cima
	var tem_sobre := false
	match tipo:
		"jaqueta":
			sobre = _sorteia(r, JAQUETAS)
			tem_sobre = true
			manga = sobre
			manga_longa = true
		"moletom":
			camisa = _sorteia(r, MOLETONS)
			manga = camisa
			manga_longa = true
		"policia":
			camisa = _tom(Color(0.13, 0.16, 0.27), r.randf_range(0.85, 1.1))
			calca = _tom(Color(0.1, 0.11, 0.16), r.randf_range(0.85, 1.1))
			manga = camisa
			sapato = Color(0.05, 0.05, 0.05)
		"medico":
			if r.randf() < 0.5:
				camisa = _tom([Color(0.36, 0.55, 0.6), Color(0.35, 0.52, 0.42), Color(0.3, 0.38, 0.55)][r.randi() % 3], r.randf_range(0.8, 1.0))
				calca = camisa
			else:
				sobre = Color(0.78, 0.78, 0.74)   # jaleco branco (encardido)
				tem_sobre = true
				manga = sobre
				manga_longa = true
		"operario":
			camisa = _tom(Color(0.3, 0.32, 0.36), r.randf_range(0.8, 1.1))
			manga = camisa
			sobre = [Color(0.85, 0.45, 0.1), Color(0.7, 0.75, 0.15)][r.randi() % 2]
			tem_sobre = true
	var v := {}
	# ===== TRONCO (pivô na junta do quadril) =====
	var t := Malhas.Construtor.new()
	t.caixa(Vector3(0, 0.03, 0), Vector3(0.33, 0.17, 0.21), calca)                       # bacia
	if tipo != "moletom":
		t.caixa(Vector3(0, 0.115, 0), Vector3(0.34, 0.035, 0.215), _tom(Color(0.12, 0.09, 0.07), r.randf_range(0.6, 1.4)))   # cinto
	t.caixa(Vector3(0, 0.25, 0.005), Vector3(0.33, 0.24, 0.2), camisa)                    # barriga
	t.caixa(Vector3(0, 0.43, 0.0), Vector3(0.39, 0.2, 0.22), camisa)                     # peito
	t.caixa(Vector3(0, 0.535, 0.01), Vector3(0.29, 0.05, 0.18), camisa)                  # ombros
	t.caixa(Vector3(0, 0.585, -0.005), Vector3(0.11, 0.11, 0.11), pele)                 # pescoço
	# barra rasgada da camisa (tiras de comprimentos diferentes por cima da calça)
	for i in 6:
		var x := -0.145 + i * 0.058
		var comp := r.randf_range(0.02, 0.1)
		for zz in [-0.104, 0.104]:
			t.caixa(Vector3(x, 0.13 - comp * 0.5, zz), Vector3(0.05, comp + 0.02, 0.012), _tom(camisa, r.randf_range(0.8, 0.95)))
	# rasgos mostrando a pele e machucados
	for i in r.randi_range(1, 3):
		var z := -0.112 if r.randf() < 0.6 else 0.112
		t.caixa(Vector3(r.randf_range(-0.12, 0.12), r.randf_range(0.18, 0.45), z), Vector3(r.randf_range(0.04, 0.08), r.randf_range(0.03, 0.07), 0.004), _tom(pele, 0.85))
	# ferida aberta com costelas (alguns)
	if r.randf() < 0.3:
		var lx := r.randf_range(-0.12, 0.08)
		t.caixa(Vector3(lx, 0.36, -0.113), Vector3(0.1, 0.12, 0.004), Color(0.3, 0.04, 0.05))
		for k in 3:
			t.caixa(Vector3(lx, 0.32 + k * 0.035, -0.117), Vector3(0.085, 0.012, 0.006), Color(0.7, 0.66, 0.55))
	# roupa por cima
	match tipo:
		"jaqueta":
			for sx in [-1.0, 1.0]:
				t.caixa(Vector3(sx * 0.115, 0.33, -0.118), Vector3(0.15, 0.46, 0.022), sobre)     # frentes abertas
				t.caixa(Vector3(sx * 0.2, 0.33, 0.0), Vector3(0.025, 0.46, 0.24), sobre)          # laterais
				t.caixa(Vector3(sx * 0.07, 0.55, -0.11), Vector3(0.08, 0.06, 0.05), _tom(sobre, 0.85))  # gola
			t.caixa(Vector3(0, 0.33, 0.118), Vector3(0.4, 0.46, 0.022), sobre)                    # costas
			t.caixa(Vector3(0, 0.555, 0.06), Vector3(0.3, 0.05, 0.12), _tom(sobre, 0.85))
		"moletom":
			t.caixa(Vector3(0, 0.57, 0.105), Vector3(0.25, 0.12, 0.09), _tom(camisa, 0.9))       # capuz caído
			t.caixa(Vector3(0, 0.24, -0.108), Vector3(0.2, 0.09, 0.012), _tom(camisa, 0.8))      # bolso canguru
			for sx in [-0.035, 0.035]:
				t.caixa(Vector3(sx, 0.47, -0.115), Vector3(0.01, 0.1, 0.008), Color(0.75, 0.75, 0.72))   # cordões
			t.caixa(Vector3(0, 0.13, 0), Vector3(0.35, 0.05, 0.215), _tom(camisa, 0.85))         # punho da barra
		"policia":
			t.caixa(Vector3(-0.1, 0.46, -0.113), Vector3(0.045, 0.055, 0.006), Color(0.75, 0.62, 0.25))   # distintivo
			t.caixa(Vector3(0.11, 0.5, -0.115), Vector3(0.05, 0.08, 0.03), Color(0.06, 0.06, 0.06))       # rádio
			t.caixa(Vector3(0.185, 0.07, -0.02), Vector3(0.05, 0.14, 0.09), Color(0.05, 0.05, 0.05))      # coldre vazio
			t.caixa(Vector3(0, 0.115, 0), Vector3(0.35, 0.045, 0.225), Color(0.06, 0.06, 0.06))
			for sx in [-0.09, 0.09]:
				t.caixa(Vector3(sx, 0.4, -0.113), Vector3(0.07, 0.05, 0.006), _tom(camisa, 0.8))         # bolsos
		"medico":
			if tem_sobre:
				for sx in [-1.0, 1.0]:
					t.caixa(Vector3(sx * 0.11, 0.2, -0.118), Vector3(0.16, 0.66, 0.02), sobre)      # jaleco até a coxa
					t.caixa(Vector3(sx * 0.2, 0.2, 0.0), Vector3(0.025, 0.66, 0.24), sobre)
				t.caixa(Vector3(0, 0.2, 0.118), Vector3(0.4, 0.66, 0.02), sobre)
				t.caixa(Vector3(0, 0.505, -0.124), Vector3(0.02, 0.1, 0.01), Color(0.15, 0.15, 0.16))   # estetoscópio
			t.caixa(Vector3(0, 0.6, -0.065), Vector3(0.12, 0.04, 0.02), Color(0.55, 0.7, 0.75))         # máscara caída no pescoço
		"operario":
			for sx in [-1.0, 1.0]:
				t.caixa(Vector3(sx * 0.11, 0.33, -0.117), Vector3(0.14, 0.4, 0.02), sobre)
				t.caixa(Vector3(sx * 0.11, 0.3, -0.129), Vector3(0.14, 0.025, 0.005), Color(0.75, 0.75, 0.72))   # faixa refletiva
				t.caixa(Vector3(sx * 0.11, 0.4, -0.129), Vector3(0.14, 0.025, 0.005), Color(0.75, 0.75, 0.72))
			t.caixa(Vector3(0, 0.33, 0.117), Vector3(0.38, 0.4, 0.02), sobre)
			t.caixa(Vector3(0, 0.35, 0.129), Vector3(0.38, 0.025, 0.005), Color(0.75, 0.75, 0.72))
	# sangue: escorrendo da boca pelo peito, respingos, mancha nas costas
	var sang_z := -0.13 if (tem_sobre and tipo != "jaqueta") else -0.115
	if tipo == "jaqueta":
		sang_z = -0.113
	var comp_esc := r.randf_range(0.12, 0.3)
	t.caixa(Vector3(r.randf_range(-0.04, 0.04), 0.52 - comp_esc * 0.5, sang_z), Vector3(r.randf_range(0.04, 0.09), comp_esc, 0.005), SANGUE)
	for i in r.randi_range(2, 5):
		var cor := SANGUE if r.randf() < 0.5 else SANGUE_SECO
		var lado_z := -0.116 if r.randf() < 0.7 else 0.12
		t.caixa(Vector3(r.randf_range(-0.15, 0.15), r.randf_range(0.0, 0.5), lado_z), Vector3(r.randf_range(0.03, 0.1), r.randf_range(0.03, 0.1), 0.005), cor)
	t.caixa(Vector3(0, 0.585, -0.06), Vector3(0.08, 0.06, 0.004), SANGUE)                # pescoço
	v["tronco"] = t.malha(_mat)
	# ===== CABEÇA (pivô no topo do pescoço) =====
	var h := Malhas.Construtor.new()
	var pele_rosto := _tom(pele, 1.03)
	h.caixa(Vector3(0, 0.145, -0.005), Vector3(0.2, 0.2, 0.22), pele_rosto)            # crânio
	h.caixa(Vector3(0, 0.03, -0.03), Vector3(0.16, 0.06, 0.16), _tom(pele, 0.95))       # mandíbula (boca aberta)
	h.caixa(Vector3(0, 0.068, -0.112), Vector3(0.12, 0.04, 0.012), Color(0.08, 0.015, 0.015))    # boca escura
	h.caixa(Vector3(0, 0.083, -0.118), Vector3(0.1, 0.012, 0.006), Color(0.62, 0.58, 0.42))      # dentes de cima
	h.caixa(Vector3(0, 0.052, -0.114), Vector3(0.08, 0.01, 0.006), Color(0.55, 0.5, 0.36))       # dentes de baixo
	h.caixa(Vector3(0, 0.185, -0.117), Vector3(0.19, 0.026, 0.016), _tom(pele, 0.82))            # testa/sobrancelha
	for sx in [-1.0, 1.0]:
		h.caixa(Vector3(sx * 0.048, 0.155, -0.116), Vector3(0.065, 0.045, 0.006), Color(0.16, 0.12, 0.13))   # olheira funda
		var olho := Color(0.86, 0.82, 0.55) if r.randf() < 0.85 else Color(0.05, 0.04, 0.04)
		h.caixa(Vector3(sx * 0.048, 0.157, -0.12), Vector3(0.036, 0.02, 0.005), olho)
		h.caixa(Vector3(sx * 0.104, 0.14, 0.0), Vector3(0.02, 0.05, 0.04), _tom(pele, 0.9))         # orelhas
		h.caixa(Vector3(sx * 0.06, 0.112, -0.116), Vector3(0.05, 0.03, 0.006), _tom(pele, 0.78))    # bochecha funda
	h.caixa(Vector3(0, 0.125, -0.125), Vector3(0.034, 0.05, 0.026), _tom(pele, 0.93))           # nariz
	# sangue no queixo e no canto da boca
	h.caixa(Vector3(r.randf_range(-0.03, 0.03), 0.02, -0.112), Vector3(0.07, 0.05, 0.012), SANGUE)
	h.caixa(Vector3(r.randf_range(-0.05, 0.05), 0.09, -0.118), Vector3(0.025, 0.03, 0.005), SANGUE)
	if r.randf() < 0.5:
		h.caixa(Vector3(r.randf_range(-0.06, 0.06), 0.22, -0.116), Vector3(0.05, 0.05, 0.005), SANGUE_SECO)   # ferida na testa
	# cabelo / cabeça
	var estilo := r.randi() % 4
	if tipo == "policia" and r.randf() < 0.6:
		h.caixa(Vector3(0, 0.262, 0.0), Vector3(0.225, 0.06, 0.235), Color(0.1, 0.12, 0.2))        # quepe
		h.caixa(Vector3(0, 0.24, -0.14), Vector3(0.2, 0.014, 0.07), Color(0.04, 0.04, 0.05))       # aba
		h.caixa(Vector3(0, 0.27, -0.118), Vector3(0.05, 0.03, 0.006), Color(0.75, 0.62, 0.25))
	elif tipo == "operario" and r.randf() < 0.7:
		var cap: Color = [Color(0.85, 0.7, 0.1), Color(0.85, 0.85, 0.82), Color(0.8, 0.4, 0.1)][r.randi() % 3]
		h.caixa(Vector3(0, 0.27, 0.0), Vector3(0.235, 0.075, 0.245), cap)                       # capacete
		h.caixa(Vector3(0, 0.235, -0.01), Vector3(0.26, 0.012, 0.28), _tom(cap, 0.9))
		h.caixa(Vector3(0, 0.31, 0.0), Vector3(0.04, 0.02, 0.22), _tom(cap, 1.05))
	elif estilo == 0:                                       # cabelo curto
		h.caixa(Vector3(0, 0.255, 0.0), Vector3(0.21, 0.03, 0.23), cabelo)
		h.caixa(Vector3(0, 0.18, 0.105), Vector3(0.21, 0.15, 0.025), cabelo)
		for sx in [-1.0, 1.0]:
			h.caixa(Vector3(sx * 0.103, 0.205, 0.03), Vector3(0.02, 0.1, 0.16), cabelo)
	elif estilo == 1:                                       # cabelo longo e sujo
		h.caixa(Vector3(0, 0.257, 0.0), Vector3(0.215, 0.035, 0.235), cabelo)
		h.caixa(Vector3(0, 0.1, 0.108), Vector3(0.22, 0.34, 0.03), cabelo)
		for sx in [-1.0, 1.0]:
			h.caixa(Vector3(sx * 0.106, 0.13, 0.02), Vector3(0.025, 0.26, 0.18), cabelo)
			h.caixa(Vector3(sx * 0.07, 0.07, -0.08), Vector3(0.03, 0.18, 0.03), _tom(cabelo, 0.85))   # mechas na cara
	elif estilo == 2:                                       # careca com tufos e manchas
		h.caixa(Vector3(0.04, 0.252, 0.05), Vector3(0.09, 0.02, 0.1), cabelo)
		h.caixa(Vector3(-0.07, 0.2, 0.09), Vector3(0.06, 0.08, 0.04), cabelo)
		h.caixa(Vector3(-0.03, 0.248, -0.04), Vector3(0.07, 0.01, 0.06), Color(0.3, 0.2, 0.28))   # hematoma
	else:                                                   # cabelo arrancado de um lado
		h.caixa(Vector3(0.04, 0.255, 0.0), Vector3(0.13, 0.03, 0.23), cabelo)
		h.caixa(Vector3(0, 0.18, 0.105), Vector3(0.21, 0.15, 0.025), cabelo)
		h.caixa(Vector3(-0.06, 0.245, -0.02), Vector3(0.07, 0.012, 0.08), Color(0.32, 0.05, 0.05))
	v["cabeca"] = h.malha(_mat)
	# ===== BRAÇOS (pivô no ombro / cotovelo) =====
	for lado in 2:
		var b := Malhas.Construtor.new()
		b.caixa(Vector3(0, -0.01, 0), Vector3(0.13, 0.08, 0.13), manga)
		if manga_longa:
			b.caixa(Vector3(0, -0.145, 0), Vector3(0.115, 0.29, 0.12), manga)
		else:
			b.caixa(Vector3(0, -0.07, 0), Vector3(0.122, 0.14, 0.126), manga)
			b.caixa(Vector3(0, -0.19, 0), Vector3(0.092, 0.2, 0.098), pele)
			b.caixa(Vector3(0, -0.135, -0.05), Vector3(0.06, 0.03, 0.03), _tom(manga, 0.85))   # barra rasgada
		if r.randf() < 0.5:
			b.caixa(Vector3(0, r.randf_range(-0.22, -0.06), -0.063), Vector3(0.07, r.randf_range(0.04, 0.09), 0.005), SANGUE_SECO)
		v["braco%d" % lado] = b.malha(_mat)
		var a := Malhas.Construtor.new()
		if manga_longa:
			var arreg := r.randf() < 0.4                    # manga arregaçada/rasgada no antebraço
			var comp_m := 0.1 if arreg else 0.2
			a.caixa(Vector3(0, -comp_m * 0.5 + 0.01, 0), Vector3(0.108, comp_m, 0.112), manga)
			a.caixa(Vector3(0, -(comp_m + 0.25) * 0.5, 0), Vector3(0.085, 0.25 - comp_m, 0.09), pele)
		else:
			a.caixa(Vector3(0, -0.125, 0), Vector3(0.088, 0.25, 0.094), pele)
		a.caixa(Vector3(0, -0.29, -0.012), Vector3(0.084, 0.085, 0.045), _tom(pele, 0.95))   # mão
		# dedos em garra
		for f in 3:
			a.caixa(Vector3(-0.026 + f * 0.026, -0.345, -0.025), Vector3(0.02, 0.07, 0.02), _tom(pele, 0.9), Basis(Vector3.RIGHT, 0.5))
		a.caixa(Vector3(0.045 if lado == 0 else -0.045, -0.29, -0.04), Vector3(0.02, 0.06, 0.02), _tom(pele, 0.9))
		if r.randf() < 0.7:
			a.caixa(Vector3(0, -0.31, -0.012), Vector3(0.088, 0.06, 0.049), SANGUE)            # mão suja de sangue
		if r.randf() < 0.4:
			a.caixa(Vector3(0, -0.17, -0.047), Vector3(0.06, 0.05, 0.005), Color(0.32, 0.05, 0.05))   # mordida
		v["antebraco%d" % lado] = a.malha(_mat)
	# ===== PERNAS (pivô no quadril / joelho) =====
	var descalco := r.randf() < 0.15
	for lado in 2:
		var cx := Malhas.Construtor.new()
		cx.caixa(Vector3(0, -0.22, 0), Vector3(0.155, 0.46, 0.17), calca)
		if r.randf() < 0.6:
			cx.caixa(Vector3(0, -0.4, -0.087), Vector3(0.09, r.randf_range(0.04, 0.08), 0.005), _tom(pele, 0.85))   # joelho rasgado
		if r.randf() < 0.5:
			cx.caixa(Vector3(r.randf_range(-0.04, 0.04), r.randf_range(-0.3, -0.08), -0.087), Vector3(0.06, r.randf_range(0.05, 0.14), 0.005), SANGUE_SECO)
		if tipo == "policia":
			cx.caixa(Vector3(0.079 if lado == 1 else -0.079, -0.22, 0), Vector3(0.004, 0.44, 0.03), Color(0.55, 0.45, 0.2))   # listra
		v["coxa%d" % lado] = cx.malha(_mat)
		var cn := Malhas.Construtor.new()
		var curta := r.randf() < 0.25                       # calça rasgada na canela
		if curta:
			cn.caixa(Vector3(0, -0.1, 0), Vector3(0.135, 0.2, 0.145), calca)
			cn.caixa(Vector3(0, -0.3, 0), Vector3(0.1, 0.2, 0.11), pele)
			cn.caixa(Vector3(0.03, -0.215, -0.06), Vector3(0.05, 0.04, 0.03), _tom(calca, 0.85))
		else:
			cn.caixa(Vector3(0, -0.2, 0), Vector3(0.13, 0.4, 0.14), calca)
		if descalco:
			cn.caixa(Vector3(0, -0.44, -0.04), Vector3(0.1, 0.07, 0.22), _tom(pele, 0.8))
			cn.caixa(Vector3(0, -0.47, -0.04), Vector3(0.1, 0.012, 0.22), SANGUE_SECO)
		else:
			cn.caixa(Vector3(0, -0.435, -0.045), Vector3(0.12, 0.08, 0.25), sapato)
			cn.caixa(Vector3(0, -0.472, -0.045), Vector3(0.125, 0.014, 0.255), _tom(sapato, 0.6))
		v["canela%d" % lado] = cn.malha(_mat)
	return v
