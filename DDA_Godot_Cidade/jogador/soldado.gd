extends Node3D
# SOLDADO ORIGINAL do jogo em HTML (camuflagem urbana), peça por peça, com a mesma animação por código:
# passada com joelho e tornozelo, corrida, pulo, pouso amortecido, inclinação nas curvas, e braços por IK
# segurando a arma (pistola/M4) nas poses "baixa" (pronta) e "erguida" (mirando).
# Novo em relação ao HTML: pose AGACHADO (coxas à frente, joelhos dobrados, tronco inclinado).
# Medidas iguais às do HTML. Dentro do nó "Corpo" a frente é +Z (como no HTML); o Corpo é girado 180°
# para o soldado olhar para -Z, que é a frente na Godot.

const L_BRACO := 0.29
const POSE := {   # no espaço do tronco: lo = arma baixa [x,y,z,rot_x] · hi = mirando · r/l = mão direita/esquerda
	"pistola": {"lo": [-0.10, 0.30, 0.30, 0.55], "hi": [-0.06, 0.47, 0.38], "r": [-0.012, -0.045, -0.01], "l": [0.04, -0.05, 0.015]},
	"m4": {"lo": [-0.06, 0.33, 0.12, 0.40], "hi": [-0.07, 0.45, 0.16], "r": [0.0, -0.10, -0.06], "l": [0.0, -0.04, 0.24]},
}

var corpo: Node3D
var hips: Node3D
var tor: Node3D
var head: Node3D
var legs: Array = []      # {p, k, an}
var arms: Array = []      # {p, e, s}
var armas_seguradas := {} # tipo -> Node3D (a arma fica presa ao tronco)

# estado da animação (mesmos nomes do HTML: foot.ph, mv, rn, acc, tn, land)
var ph := 0.0
var mv := 0.0
var rn := 0.0
var lsp := 0.0
var acc := 0.0
var lh := 0.0
var tn := 0.0
var land := 0.0
var agach := 0.0
var morte := 0.0
var _no_chao_ant := true
var _vy_ant := 0.0
var _t := 0.0

var _cache := {}
var _tex_camo: ImageTexture
var _m := {}

func _ready() -> void:
	_montar()

# ---------- materiais ----------
func _mat(cor: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rough
	m.metallic = metal
	return m

func _camo_tex() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color("#7c838a"))
	var pal := [Color("#8c9298"), Color("#656b72"), Color("#3e434a"), Color("#202328"), Color("#b4b9be")]
	var s := 20260
	for n in 150:
		s = (s * 16807) % 2147483647
		var c: Color = pal[int(float(s) / 2147483647.0 * 5.0)]
		s = (s * 16807) % 2147483647
		var x := int(float(s) / 2147483647.0 * 16.0) * 4
		s = (s * 16807) % 2147483647
		var y := int(float(s) / 2147483647.0 * 16.0) * 4
		s = (s * 16807) % 2147483647
		var w := 4 * (1 + int(float(s) / 2147483647.0 * 3.0))
		s = (s * 16807) % 2147483647
		var h := 4 * (1 + int(float(s) / 2147483647.0 * 2.0))
		img.fill_rect(Rect2i(x, y, w, h), c)
	return ImageTexture.create_from_image(img)

# camuflagem com repetição proporcional ao tamanho da peça (como no HTML)
func _camo(w: float, h: float) -> StandardMaterial3D:
	var kx := maxf(0.25, roundf(w / 0.45 * 10.0) / 10.0)
	var ky := maxf(0.25, roundf(h / 0.45 * 10.0) / 10.0)
	var chave := "%s_%s" % [kx, ky]
	if not _cache.has(chave):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex_camo
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_scale = Vector3(kx * 3.0, ky * 2.0, 1.0)   # BoxMesh: cada face ocupa 1/3 x 1/2 do UV
		m.roughness = 0.95
		_cache[chave] = m
	return _cache[chave]

# ---------- peças ----------
func B(w: float, h: float, d: float, m: Material, x: float, y: float, z: float, p: Node3D) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	o.mesh = bm
	o.material_override = m
	o.position = Vector3(x, y, z)
	p.add_child(o)
	return o

func C(rt: float, rb: float, h: float, m: Material, x: float, y: float, z: float, p: Node3D, rx := 0.0, rz := 0.0) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	o.mesh = cm
	o.material_override = m
	o.position = Vector3(x, y, z)
	o.rotation = Vector3(rx, 0.0, rz)
	p.add_child(o)
	return o

func G(x: float, y: float, z: float, p: Node3D) -> Node3D:
	var g := Node3D.new()
	g.rotation_order = EULER_ORDER_XYZ    # mesma ordem de rotação do three.js
	g.position = Vector3(x, y, z)
	p.add_child(g)
	return g

func _montar() -> void:
	_tex_camo = _camo_tex()
	var skin := _mat(Color("#d8a77d"))
	var black := _mat(Color("#15171a"), 0.6)
	var vest := _mat(Color("#2c3036"), 0.9)
	var vest2 := _mat(Color("#3a4047"), 0.9)
	var glove := _mat(Color("#1b1c1f"), 0.8)
	var boot := _mat(Color("#111111"), 0.55)
	var sole := _mat(Color("#070707"), 1.0)
	var metal := _mat(Color("#2b2d32"), 0.35, 0.6)
	var patch := _mat(Color("#59623f"), 1.0)
	var tan := _mat(Color("#6b6350"), 1.0)
	var paint1 := _mat(Color("#14181a"), 1.0)
	var paint2 := _mat(Color("#4b5148"), 1.0)
	var lens := _mat(Color("#0a1a2c"), 0.08, 0.3)
	corpo = Node3D.new()
	corpo.name = "Corpo"
	corpo.rotation.y = PI
	add_child(corpo)
	# quadril, cinto e bolsas
	hips = G(0, 0.92, 0, corpo)
	B(0.36, 0.2, 0.22, _camo(0.36, 0.2), 0, 0, 0, hips)
	B(0.38, 0.06, 0.25, black, 0, 0.1, 0, hips)
	B(0.07, 0.05, 0.02, metal, 0, 0.1, 0.13, hips)
	B(0.1, 0.12, 0.05, vest2, -0.16, 0.02, -0.14, hips)
	B(0.08, 0.1, 0.05, vest2, 0.14, 0.02, -0.14, hips)
	# pernas: coxa, bolso cargo, coldre, joelheira, bota de combate
	for s in [1.0, -1.0]:
		var p := G(s * 0.1, -0.08, 0, hips)
		B(0.17, 0.46, 0.2, _camo(0.17, 0.46), 0, -0.23, 0, p)
		B(0.045, 0.15, 0.13, _camo(0.05, 0.15), s * 0.105, -0.2, 0, p)
		if s == 1.0:
			B(0.05, 0.2, 0.13, black, 0.12, -0.3, 0.02, p)
			B(0.04, 0.05, 0.1, metal, 0.12, -0.17, 0.02, p)
		var k := G(0, -0.46, 0, p)
		B(0.14, 0.3, 0.16, _camo(0.14, 0.3), 0, -0.15, 0, k)
		B(0.15, 0.15, 0.07, vest, 0, -0.02, 0.095, k)
		B(0.15, 0.04, 0.07, black, 0, 0.06, 0.095, k)
		var an := G(0, -0.33, 0, k)
		B(0.155, 0.21, 0.185, boot, 0, 0.085, 0, an)
		B(0.14, 0.06, 0.13, boot, 0, 0.01, 0.14, an)
		B(0.15, 0.04, 0.34, sole, 0, -0.04, 0.07, an)
		legs.append({"p": p, "k": k, "an": an})
	# tronco: jaqueta camuflada, colete de placas, porta-carregadores, patches, mochila, rádio
	tor = G(0, 0.1, 0, hips)
	B(0.42, 0.5, 0.24, _camo(0.42, 0.5), 0, 0.25, 0, tor)
	B(0.44, 0.36, 0.07, vest, 0, 0.3, 0.145, tor)
	B(0.44, 0.36, 0.07, vest, 0, 0.3, -0.145, tor)
	B(0.46, 0.11, 0.27, vest, 0, 0.08, 0, tor)
	for x in [-0.14, 0.14]:
		B(0.09, 0.035, 0.29, vest, x, 0.505, 0, tor)
	for x in [-0.13, 0.0, 0.13]:
		B(0.1, 0.14, 0.055, vest2, x, 0.17, 0.2, tor)
	for y in [0.22, 0.3, 0.38]:
		B(0.4, 0.012, 0.012, black, 0, y, 0.185, tor)
	B(0.12, 0.07, 0.045, vest2, 0.1, 0.42, 0.185, tor)
	B(0.12, 0.035, 0.006, patch, -0.1, 0.45, 0.182, tor)
	var sl := B(0.025, 0.62, 0.01, black, 0, 0.32, 0.222, tor)
	sl.rotation.z = 0.55
	B(0.34, 0.4, 0.18, _camo(0.34, 0.4), 0, 0.32, -0.27, tor)
	B(0.34, 0.06, 0.19, vest2, 0, 0.54, -0.27, tor)
	C(0.06, 0.06, 0.4, tan, 0, 0.6, -0.27, tor, 0.0, PI / 2.0)
	B(0.07, 0.15, 0.05, black, 0.21, 0.36, -0.25, tor)
	C(0.006, 0.006, 0.38, black, 0.21, 0.58, -0.25, tor)
	# pescoço, gola e cabeça
	C(0.065, 0.07, 0.09, skin, 0, 0.54, 0, tor)
	C(0.085, 0.095, 0.1, black, 0, 0.56, 0, tor)
	head = G(0, 0.64, 0, tor)
	var hd := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.105
	sm.height = 0.21
	sm.radial_segments = 14
	sm.rings = 8
	hd.mesh = sm
	hd.material_override = skin
	hd.scale = Vector3(0.95, 1.18, 1.05)
	hd.position.y = 0.1
	head.add_child(hd)
	B(0.02, 0.05, 0.03, skin, 0.105, 0.1, 0, head)
	B(0.02, 0.05, 0.03, skin, -0.105, 0.1, 0, head)
	# pintura camuflada no rosto
	B(0.04, 0.012, 0.01, paint1, -0.052, 0.06, 0.09, head)
	B(0.04, 0.012, 0.01, paint1, 0.052, 0.06, 0.09, head)
	B(0.045, 0.014, 0.01, paint2, -0.058, 0.035, 0.078, head)
	B(0.045, 0.014, 0.01, paint2, 0.058, 0.035, 0.078, head)
	B(0.012, 0.05, 0.01, paint1, 0, 0.085, 0.108, head)
	B(0.07, 0.014, 0.01, paint2, 0, 0.0, 0.09, head)
	# óculos balísticos
	B(0.23, 0.035, 0.22, black, 0, 0.105, -0.005, head)
	B(0.16, 0.055, 0.04, black, 0, 0.105, 0.098, head)
	B(0.14, 0.04, 0.012, lens, 0, 0.105, 0.12, head)
	# capacete com capa camuflada, suporte de NVG, tubo de visão noturna e jugular
	var hm := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.14
	hs.height = 0.14
	hs.is_hemisphere = true
	hs.radial_segments = 18
	hs.rings = 6
	hm.mesh = hs
	hm.material_override = _camo(0.3, 0.3)
	hm.scale = Vector3(1.0, 0.95, 1.12)
	hm.position = Vector3(0, 0.15, -0.005)
	head.add_child(hm)
	B(0.06, 0.045, 0.04, metal, 0, 0.25, 0.12, head)
	C(0.025, 0.025, 0.06, black, 0, 0.275, 0.145, head, PI / 2.0)
	B(0.012, 0.12, 0.012, black, 0.095, 0.03, 0.04, head)
	B(0.012, 0.12, 0.012, black, -0.095, 0.03, 0.04, head)
	B(0.09, 0.02, 0.05, black, 0, -0.01, 0.07, head)
	# braços: manga camuflada, patch, cotoveleira, luvas táticas  (s = 1: braço esquerdo · s = -1: direito)
	for s in [1.0, -1.0]:
		var p := G(s * 0.275, 0.47, 0, tor)
		B(0.12, 0.3, 0.13, _camo(0.12, 0.3), 0, -0.14, 0, p)
		B(0.006, 0.08, 0.07, patch, s * 0.063, -0.09, 0, p)
		var e := G(0, -0.29, 0, p)
		B(0.105, 0.27, 0.115, _camo(0.105, 0.27), 0, -0.125, 0, e)
		B(0.11, 0.07, 0.05, black, 0, -0.01, -0.06, e)
		B(0.1, 0.09, 0.115, glove, 0, -0.29, 0, e)
		B(0.1, 0.03, 0.1, black, 0, -0.25, 0.01, e)
		arms.append({"p": p, "e": e, "s": s})
	# sombra falsa (barata no celular)
	var sombra := MeshInstance3D.new()
	sombra.name = "SombraFalsa"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.5, 1.5)
	var smat := StandardMaterial3D.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0.55))
	gr.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	smat.albedo_texture = gt
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	pm.material = smat
	sombra.mesh = pm
	sombra.position.y = 0.06
	sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sombra)

# ---------- interface usada pelo jogador / armas ----------
# a arma vai presa ao tronco (no HTML: SD.tor.add(arma)); os braços a seguram por IK
func segurar_arma(tipo: String, no: Node3D) -> void:
	armas_seguradas[tipo] = no
	no.rotation_order = EULER_ORDER_XYZ
	tor.add_child(no)

func pegar_ponto_arma() -> Node3D:
	return tor

# ---------- animação (porte do footVisual + weaponPose do HTML) ----------
func atualizar_procedural(dt: float, j) -> void:
	if legs.size() < 2:
		return
	_t += dt
	var sp: float = j.vel_horizontal
	var no_chao: bool = j.is_on_floor()
	var air := 0.0 if no_chao else 1.0
	if no_chao and not _no_chao_ant:
		land = clampf(-_vy_ant / 9.0, 0.0, 1.0)     # amortece o pouso conforme a velocidade da queda
	_no_chao_ant = no_chao
	_vy_ant = j.velocity.y
	var k8 := minf(1.0, dt * 8.0)
	var dd := maxf(dt, 0.0001)
	mv += (clampf(sp, 0.0, 1.0) - mv) * k8
	var rr := clampf((sp - 2.4) / 3.2, 0.0, 1.0)
	rn += (rr * rr * (3.0 - 2.0 * rr) - rn) * k8
	var R := rn
	acc += (clampf((sp - lsp) / dd, -20.0, 20.0) - acc) * minf(1.0, dt * 6.0)
	lsp = sp
	var h: float = j.rotation.y
	tn += (clampf(wrapf(h - lh, -PI, PI) / dd, -6.0, 6.0) - tn) * minf(1.0, dt * 6.0)
	lh = h
	if land > 0.0:
		land = maxf(0.0, land - dt * 3.5)
	if sp > 0.3:
		ph += dt * TAU * clampf(0.65 + sp * 0.17, 0.7, 1.85)
	agach += ((1.0 if j.agachado else 0.0) - agach) * minf(1.0, dt * 10.0)
	var ag := agach * (1.0 - air)
	var ls := land
	var Sw := lerpf(0.4, 0.72, clampf((sp - 1.7) / 5.5, 0.0, 1.0)) * mv
	var sph := sin(ph)
	var hy: Array[float] = []
	for i in 2:
		var l: Dictionary = legs[i]
		var p2 := ph + (PI if i == 1 else 0.0)
		var s := sin(p2)
		var cs := cos(p2)
		var th := -s * Sw * (0.75 if s > 0.0 else 1.1)
		var kn := 0.04 + (0.1 + 0.12 * R) * mv * maxf(0.0, -cs) + (0.5 + 1.45 * R) * mv * pow(maxf(0.0, cs), 1.4)
		th = lerpf(th, 0.3 if i == 1 else -0.75, air)
		kn = lerpf(kn, 0.55 if i == 1 else 0.95, air)
		th -= 0.55 * ls * (0.8 if i == 1 else 1.0)
		kn += 1.1 * ls
		# agachado: coxas à frente, joelhos bem dobrados, passada curta
		var thc := -1.15 - s * Sw * 0.45 + (0.18 if i == 1 else 0.0)
		var knc := 1.95 + 0.35 * mv * maxf(0.0, cs)
		th = lerpf(th, thc, ag)
		kn = lerpf(kn, knc, ag)
		(l["p"] as Node3D).rotation.x = th
		(l["k"] as Node3D).rotation.x = kn
		var st := clampf(0.5 - cs * 1.5, 0.0, 1.0)       # 1 = pé apoiado
		var an := -(th + kn) * st * (1.0 - air) - kn * 0.35 * (1.0 - st) + (0.15 + 0.45 * R) * mv * maxf(0.0, -s) * st - 0.25 * mv * maxf(0.0, s) * st + air * 0.3
		an = lerpf(an, -(th + kn), ag)                   # agachado: pé chapado no chão
		(l["an"] as Node3D).rotation.x = an
		hy.append(0.08 + 0.46 * cos(th) + 0.39 * cos(th + kn))
	hips.position.y = maxf(hy[0], hy[1]) - 0.01 + R * 0.05 * maxf(0.0, cos(ph * 2.0)) * mv * (1.0 - air)
	hips.position.x = sph * 0.012 * mv * (1.0 - R) * (1.0 - air)
	hips.rotation.y = sph * 0.14 * (0.5 + R) * mv * (1.0 - air)
	hips.rotation.z = sph * 0.035 * (1.0 + R) * mv * (1.0 - air) + sin(_t * 0.5) * 0.015 * (1.0 - mv)
	tor.rotation.x = 0.05 + R * 0.2 + clampf(acc * 0.012, -0.12, 0.2) + ls * 0.25 + air * 0.05 + ag * 0.32
	tor.rotation.y = -hips.rotation.y * 1.6
	tor.rotation.z = -hips.rotation.z * 0.8 - clampf(tn * sp * 0.012, -0.2, 0.2)
	tor.position.y = 0.1 + sin(_t * 1.7) * 0.004 * (1.0 - mv)
	head.rotation.x = -tor.rotation.x * 0.75 + sin(ph * 2.0) * 0.015 * mv
	head.rotation.y = -tor.rotation.y * 0.6 + sin(_t * 0.6) * 0.05 * (1.0 - mv)
	head.rotation.z = -tor.rotation.z * 0.5
	# morte: tomba para trás
	morte += ((1.0 if j.morto else 0.0) - morte) * minf(1.0, dt * 6.0)
	corpo.rotation.x = morte * PI * 0.5
	corpo.position.y = morte * 0.15
	_pose_arma(j, R, air)

func _pose_arma(j, R: float, air: float) -> void:
	var ar = j.get("armas")
	var tipo := ""
	if ar != null:
		tipo = ar.atual
	for t in armas_seguradas:
		(armas_seguradas[t] as Node3D).visible = (t == tipo)
	if tipo == "" or not armas_seguradas.has(tipo) or not POSE.has(tipo):
		# sem arma: braços balançam como no HTML
		for i in 2:
			var a: Dictionary = arms[i]
			var sa := sin(ph + (PI if i == 1 else 0.0) + PI)
			var p: Node3D = a["p"]
			p.rotation = Vector3(lerpf(-0.5, -0.25, R) - sa * (0.12 + 0.5 * R) * mv - 0.35 * air, 0.0, -a["s"] * (0.32 - 0.12 * R) + a["s"] * air * 0.45)
			(a["e"] as Node3D).rotation = Vector3(-1.05 - R * 0.5 - 0.25 * R * mv * maxf(0.0, sa), 0.0, 0.0)
		return
	var P: Dictionary = POSE[tipo]
	var g: Node3D = armas_seguradas[tipo]
	var aim: float = ar.aim
	var dr: float = ar.draw
	var rec: float = ar.rec
	var re := 0.0
	if ar.rel > 0.0:
		re = sin((1.0 - ar.rel / ar.rel_tot) * PI)
	var pit := clampf(j.cam_pit - ar.kick, -0.45, 1.1)
	var lo: Array = P["lo"]
	var hi: Array = P["hi"]
	g.position = Vector3(lerpf(lo[0], hi[0], aim), lerpf(lo[1], hi[1], aim) - dr * 0.25, lerpf(lo[2], hi[2], aim) - rec * 0.05)
	g.rotation = Vector3(lerpf(lo[3], pit * 0.95 - tor.rotation.x, aim) + dr * 0.7 - rec * 0.1, 0.0, re * 0.45)
	var gt := g.transform
	var r: Array = P["r"]
	var l: Array = P["l"]
	_ik(arms[1], gt * Vector3(r[0], r[1], r[2]))    # mão direita (empunhadura)
	_ik(arms[0], gt * Vector3(l[0], l[1], l[2]))    # mão esquerda (apoio)

# pose parada do MENU PRINCIPAL (porte do menuPose do HTML): peso numa perna, respirando, M4 baixa,
# cabeça virada para o sol. t = tempo em segundos.
func pose_menu(t: float, tipo := "m4") -> void:
	if legs.size() < 2:
		return
	var th := [0.05, -0.06]
	var kn := [0.12, 0.05]
	var hy: Array[float] = []
	for i in 2:
		var l: Dictionary = legs[i]
		(l["p"] as Node3D).rotation = Vector3(th[i], 0.0, 0.0)
		(l["k"] as Node3D).rotation.x = kn[i]
		(l["an"] as Node3D).rotation.x = -(th[i] + kn[i])
		hy.append(0.08 + 0.46 * cos(th[i]) + 0.39 * cos(th[i] + kn[i]))
	hips.position = Vector3(0.0, maxf(hy[0], hy[1]) - 0.01, 0.0)
	hips.rotation = Vector3(0.0, 0.04, sin(t * 0.4) * 0.01)
	var br := sin(t * 1.6)
	tor.position.y = 0.1 + br * 0.004
	tor.rotation = Vector3(0.07 + br * 0.006, -0.04, 0.0)
	head.rotation = Vector3(-0.06 + sin(t * 0.35) * 0.012, 0.38 + sin(t * 0.27) * 0.04, 0.0)
	for k in armas_seguradas:
		(armas_seguradas[k] as Node3D).visible = (k == tipo)
	if not armas_seguradas.has(tipo) or not POSE.has(tipo):
		return
	var P: Dictionary = POSE[tipo]
	var g: Node3D = armas_seguradas[tipo]
	var lo: Array = P["lo"]
	g.position = Vector3(lo[0], lo[1], lo[2])
	g.rotation = Vector3(lo[3], 0.0, 0.0)
	var gt := g.transform
	var r: Array = P["r"]
	var le: Array = P["l"]
	_ik(arms[1], gt * Vector3(r[0], r[1], r[2]))
	_ik(arms[0], gt * Vector3(le[0], le[1], le[2]))

# braço com IK de dois ossos (ombro -> cotovelo -> mão). T no espaço do tronco.
func _ik(a: Dictionary, T: Vector3) -> void:
	var p: Node3D = a["p"]
	var e: Node3D = a["e"]
	var S := p.position
	var D := T - S
	var dist := D.length()
	if dist < 0.0001:
		return
	D /= dist
	var ddv := clampf(dist, 0.12, 2.0 * L_BRACO - 0.01)
	var hh := sqrt(maxf(0.0, L_BRACO * L_BRACO - ddv * ddv / 4.0))
	var P := Vector3(a["s"] * 0.55, -1.0, -0.25)
	P = (P - D * P.dot(D)).normalized()
	var E := S + D * (ddv / 2.0) + P * hh
	var U := (E - S).normalized()
	var qp := _arco(Vector3.DOWN, U)
	p.quaternion = qp
	var H := S + D * ddv
	var F := (H - E).normalized()
	F = qp.inverse() * F
	e.quaternion = _arco(Vector3.DOWN, F)

func _arco(de: Vector3, para: Vector3) -> Quaternion:
	var d := de.dot(para)
	if d > 0.99999:
		return Quaternion.IDENTITY
	if d < -0.99999:
		return Quaternion(Vector3.RIGHT, PI)
	return Quaternion(de, para)
