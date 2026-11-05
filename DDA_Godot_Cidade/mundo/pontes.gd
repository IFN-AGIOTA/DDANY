extends RefCounted
# PONTES DE NOVA YORK (1.15) · feitas do zero em código, no estilo das de verdade:
#   · PONTE DO BROOKLYN (Manhattan sul -> Brooklyn): torres de PEDRA com os dois arcos góticos, 4 cabos, os pendurais
#     retos e os ESTAIS em leque (a "teia"), o PASSEIO de madeira elevado no meio e as treliças cor de areia.
#   · PONTE DE MANHATTAN (ao lado da do Brooklyn): torres de AÇO AZUL com o arco no alto e as bolas no topo, 4 cabos,
#     a treliça funda azul embaixo da pista e a entrada sobre arcadas de pedra.
#   · PONTE GEORGE WASHINGTON (Manhattan norte -> ilha do norte): torres de aço CINZA VAZADAS (treliça) com o arco
#     grande entre as pernas, 4 cabos grossos (2 de cada lado), o andar de baixo em treliça e o FAROLZINHO VERMELHO.
#   · PONTE DE QUEENSBORO (Manhattan -> ilha do meio): treliça em balanço com os picos sobre os pilares e os pináculos.
#   · PONTE MACOMBS (Nova Jersey -> Manhattan) e PONTE WILLIS (ilha do meio -> Brooklyn): treliças de aço menores.
# As ruas que passavam rentes ao mar viraram pontes de verdade, com o tabuleiro SUBINDO em rampa (no máximo 6 a 7,5%)
# até 9 a 24 m acima da água; a Ponte de Manhattan e duas emendas são RUAS NOVAS (o GPS agora passa de uma ilha à outra).
# Aqui fica TUDO das pontes:
#   · DADOS (onde, altura, rampas, torres, âncoras, pilares) e o PERFIL (altura do tabuleiro a cada 2 m);
#   · altura(x, z): a altura do tabuleiro (ou -INF): mundo/colisao_mundo.gd (o "chão" de quem está na ponte), os
#     carros largados em cima (mundo/abandono.gd) e quem nasce/cai ali;
#   · recortar(rua): tira das ruas o pedaço que virou ponte (o asfalto rente ao mar e o chão de física dele);
#   · montar(cidade): o desenho (pedaços de PEDACO m, com a versão simples de longe), a COLISÃO (tabuleiro, grades,
#     torres) e as LUZES (colar de lâmpadas nos cabos e a luz vermelha no alto das torres, só à noite).
# Mexa AQUI para: onde ficam e a altura das pontes, o desenho de cada uma, as cores e as luzes.

const Malhas := preload("res://mundo/malhas.gd")
const Mat := preload("res://mundo/materiais_cidade.gd")
const LuzesRua := preload("res://mundo/luzes_rua.gd")

const Y_RUA := 0.6
const MEIA_RUA := 18.0                 # rua de 36 m
const MEIA := 23.0                     # + calçadas de 5 m = tabuleiro de 46 m
const PASSO := 2.0                     # m entre as amostras do perfil
const SUAVE := 30.0                    # m: as duas médias móveis que arredondam o começo e o topo da rampa
const PEDACO := 320.0                  # o desenho vai em pedaços deste comprimento (chunks de 500 m)
const PERTO := 950.0                   # até aqui o desenho completo; depois, o simples
const ALCANCE_LUZ := 2600.0

# RUAS NOVAS (no FIM da lista de ruas: os números das outras não mudam). Os prédios em cima delas saem (os jogos
# salvos são convertidos: cidade.remapa_v6, menu/salvamento.gd MAPA_PREDIOS 7).
const RUAS_NOVAS := [
	[36.0, [-175.0, 3081.0, 119.0, 3081.0]],     # Manhattan sul: a avenida até a entrada da Ponte do Brooklyn
	[36.0, [-31.0, 2781.0, 1375.0, 2806.0]],     # a PONTE DE MANHATTAN inteira (com as entradas nas duas margens)
	[36.0, [738.0, -1038.0, 756.0, -981.0]],     # ilha do meio: emenda as ruas do norte com as do sul (Queensboro <-> Willis)
]

# pts: o eixo (as mesmas pontas das ruas) · ini/fim: onde a ponte começa e acaba (m pelo eixo; antes e depois é rua)
# alto: altura máxima do tabuleiro · rampa: subida máxima de cada lado · torres/ancoras/pilares: m pelo eixo
const DADOS := [
	{"nome": "PONTE DO BROOKLYN", "estilo": "brooklyn", "pts": [119.0, 3081.0, 1400.0, 3081.0],
		"ini": 25.0, "fim": 1180.0, "alto": 21.0, "rampa": [0.06, 0.07],
		"torres": [461.0, 861.0], "ancoras": [283.0, 1150.0], "passeio": [200.0, 1110.0]},
	{"nome": "PONTE DE MANHATTAN", "estilo": "manhattan", "pts": [-31.0, 2781.0, 1375.0, 2806.0],
		"ini": 28.0, "fim": 1378.0, "alto": 24.0, "rampa": [0.06, 0.06],
		"torres": [470.0, 930.0], "ancoras": [245.0, 1150.0]},
	{"nome": "PONTE GEORGE WASHINGTON", "estilo": "gwb", "pts": [-1188.0, -3438.0, -262.0, -3944.0, 69.0, -3969.0],
		"ini": 25.0, "fim": 1359.0, "alto": 24.0, "rampa": [0.075, 0.06],
		"torres": [345.0, 830.0], "ancoras": [175.0, 960.0], "farol": [222.0, -52.0]},
	{"nome": "PONTE DE QUEENSBORO", "estilo": "queensboro",
		"pts": [-344.0, -1469.0, -131.0, -1494.0, -31.0, -1481.0, 156.0, -1469.0, 475.0, -1494.0],
		"ini": 25.0, "fim": 798.0, "alto": 15.0, "rampa": [0.06, 0.06],
		"pilares": [60.0, 214.0, 315.0, 503.0, 625.0, 748.0], "picos": [214.0, 315.0, 503.0, 625.0]},
	{"nome": "PONTE MACOMBS", "estilo": "trelica", "cor": [0.25, 0.38, 0.32],
		"pts": [-3588.0, -1981.0, -3419.0, -1988.0, -3262.0, -1994.0, -3194.0, -1944.0, -3119.0, -1869.0],
		"ini": 25.0, "fim": 492.0, "alto": 9.0, "rampa": [0.06, 0.06], "pilares": [220.0, 326.0, 411.0, 439.0]},
	{"nome": "PONTE WILLIS", "estilo": "trelica", "cor": [0.46, 0.24, 0.17],
		"pts": [881.0, -244.0, 1431.0, -231.0, 1638.0, -231.0],
		"ini": 25.0, "fim": 733.0, "alto": 8.0, "rampa": [0.06, 0.06], "pilares": [351.0, 433.0, 599.0, 681.0]},
]

# ======================= UMA PONTE: o eixo e o perfil =======================
class Ponte:
	var idx := 0
	var nome := ""
	var estilo := ""
	var dados: Dictionary = {}
	var pts := PackedVector2Array()
	var acc := PackedFloat32Array()        # distância pelo eixo em cada ponto
	var comp := 0.0
	var ini := 0.0
	var fim := 0.0
	var alto := 0.0
	var perfil := PackedFloat32Array()     # altura do tabuleiro a cada PASSO m (de 0 a comp)
	var caixa := Rect2()

	func _init(d: Dictionary, i: int) -> void:
		idx = i
		dados = d
		nome = d["nome"]
		estilo = d["estilo"]
		var f: Array = d["pts"]
		for k in range(0, f.size() - 1, 2):
			pts.append(Vector2(f[k], f[k + 1]))
		acc.append(0.0)
		for k in range(1, pts.size()):
			acc.append(acc[k - 1] + pts[k - 1].distance_to(pts[k]))
		comp = acc[acc.size() - 1]
		ini = d["ini"]
		fim = d["fim"]
		alto = d["alto"]
		_perfil(float(d["rampa"][0]), float(d["rampa"][1]))
		caixa = Rect2(ponto(ini), Vector2.ZERO)
		var s := ini
		while s < fim:
			caixa = caixa.expand(ponto(s))
			s += 10.0
		caixa = caixa.expand(ponto(fim)).grow(MEIA + 4.0)

	# rampa reta (subida g) que começa 2·SUAVE depois de "ini" e desce até 2·SUAVE antes de "fim", cortada em "alto";
	# depois, duas médias móveis de SUAVE m: o começo fica liso e exatamente na altura da rua em "ini" e "fim"
	func _perfil(g0: float, g1: float) -> void:
		var n := int(ceil(comp / PASSO)) + 1
		var a := PackedFloat32Array()
		a.resize(n)
		for k in n:
			var s := k * PASSO
			var y := 0.0
			if s > ini and s < fim:
				y = minf(alto - Y_RUA, minf(g0 * maxf(0.0, s - ini - 2.0 * SUAVE), g1 * maxf(0.0, fim - 2.0 * SUAVE - s)))
			a[k] = y
		var r := int(SUAVE / PASSO)
		for passada in 2:
			var b := PackedFloat32Array()
			b.resize(n)
			for k in n:
				var soma := 0.0
				var cont := 0
				for j in range(k - r, k + r + 1):
					soma += a[clampi(j, 0, n - 1)]
					cont += 1
				b[k] = soma / cont
			a = b
		perfil = PackedFloat32Array()
		perfil.resize(n)
		for k in n:
			var s := k * PASSO
			perfil[k] = Y_RUA + (a[k] if s >= ini and s <= fim else 0.0)

	func h(s: float) -> float:
		var f := clampf(s, 0.0, comp) / PASSO
		var k := mini(int(f), perfil.size() - 2)
		return lerpf(perfil[k], perfil[k + 1], f - k)

	func seg(s: float) -> int:
		for i in pts.size() - 2:
			if s < acc[i + 1]:
				return i
		return pts.size() - 2

	func ponto(s: float) -> Vector2:
		s = clampf(s, 0.0, comp)
		var i := seg(s)
		var L := acc[i + 1] - acc[i]
		return pts[i].lerp(pts[i + 1], (s - acc[i]) / L if L > 0.0 else 0.0)

	func direcao(s: float) -> Vector2:
		var i := seg(clampf(s, 0.0, comp))
		return (pts[i + 1] - pts[i]).normalized()

	# lateral "esquerda" (como nas ruas: Vector2(-d.y, d.x)); nos cantos do eixo, a do meio (chanfro) já esticada
	func lateral(s: float) -> Vector2:
		var i := seg(clampf(s, 0.0, comp))
		var d := (pts[i + 1] - pts[i]).normalized()
		var n := Vector2(-d.y, d.x)
		var outro := -1
		if i > 0 and absf(s - acc[i]) < 0.01:
			outro = i - 1
		elif i < pts.size() - 2 and absf(s - acc[i + 1]) < 0.01:
			outro = i + 1
		if outro >= 0:
			var d2 := (pts[outro + 1] - pts[outro]).normalized()
			var m := (n + Vector2(-d2.y, d2.x)).normalized()
			return m / maxf(m.dot(n), 0.5)
		return n

	# ponto do mundo: s pelo eixo, "lat" para o lado (esquerda +), altura y
	func p3(s: float, lat: float, y: float) -> Vector3:
		var p := ponto(s)
		var n := lateral(s)
		return Vector3(p.x + n.x * lat, y, p.y + n.y * lat)

	# quadro local em s: x = lateral (esquerda), y = cima, z = para trás (destro); origem no eixo, y = 0
	func quadro(s: float) -> Transform3D:
		var d := direcao(s)
		var n := Vector2(-d.y, d.x)
		var p := ponto(s)
		return Transform3D(Basis(Vector3(n.x, 0, n.y), Vector3.UP, Vector3(-d.x, 0, -d.y)), Vector3(p.x, 0, p.y))

	# projeção no eixo: (s, deslocamento lateral com sinal)
	func projetar(p: Vector2) -> Vector2:
		var melhor := INF
		var r := Vector2(-1.0, INF)
		for i in pts.size() - 1:
			var a := pts[i]
			var ab := pts[i + 1] - a
			var l2 := ab.length_squared()
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
			var q := a + ab * t
			var dd := p.distance_squared_to(q)
			if dd < melhor:
				melhor = dd
				var d := ab.normalized()
				r = Vector2(acc[i] + t * sqrt(l2), (p - q).dot(Vector2(-d.y, d.x)))
		return r

	# amostras do eixo de s0 a s1 (passo máximo), com os cantos do eixo incluídos
	func amostras(s0: float, s1: float, passo: float) -> PackedFloat32Array:
		var o := PackedFloat32Array()
		for i in pts.size() - 1:
			var a0 := maxf(s0, acc[i])
			var a1 := minf(s1, acc[i + 1])
			if a1 < a0 - 0.001:
				continue
			var n := maxi(1, int(ceil((a1 - a0) / passo)))
			for k in n + 1:
				var s := a0 + (a1 - a0) * k / n
				if not o.is_empty() and absf(o[o.size() - 1] - s) < 0.01:
					continue
				o.append(s)
		return o

	func sobre_agua(s: float, cid) -> bool:
		return cid != null and not cid._em_terra(ponto(s))

# ======================= consultas (estáticas: servem a todos) =======================
static var lista: Array = []

static func preparar() -> void:
	if not lista.is_empty():
		return
	for i in DADOS.size():
		lista.append(Ponte.new(DADOS[i], i))

# altura do tabuleiro em (x, z), ou -INF se não está em cima de uma ponte (calçadas incluídas)
static func altura(x: float, z: float) -> float:
	var r := consultar(x, z)
	return r.y if r.x >= 0.0 else -INF

# Vector3(índice da ponte ou -1, altura do tabuleiro, deslocamento lateral)
static func consultar(x: float, z: float) -> Vector3:
	preparar()
	var p := Vector2(x, z)
	for pt in lista:
		if not (pt as Ponte).caixa.has_point(p):
			continue
		var q: Vector2 = pt.projetar(p)
		if absf(q.y) <= MEIA + 0.3 and q.x >= pt.ini and q.x <= pt.fim:
			return Vector3(pt.idx, pt.h(q.x), q.y)
	return Vector3(-1.0, -INF, 0.0)

static func ponte(i: int) -> Ponte:
	preparar()
	return lista[i]

# tira de uma rua o pedaço que virou ponte · devolve os pedaços que continuam no chão: [pontos, corte_no_começo, corte_no_fim]
static func recortar(pts: PackedVector2Array) -> Array:
	preparar()
	var pedacos: Array = []
	var atual := PackedVector2Array()
	var corte_ini := false
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var t := _corte(a, b)
		if atual.is_empty():
			atual.append(a)
		if t.x < 0.0:
			atual.append(b)
			continue
		if t.x > 0.001:
			atual.append(a.lerp(b, t.x))
		if atual.size() >= 2 and atual[0].distance_to(atual[atual.size() - 1]) > 0.5:
			pedacos.append([atual, corte_ini, true])
		atual = PackedVector2Array()
		corte_ini = true
		if t.y < 0.999:
			atual.append(a.lerp(b, t.y))
			atual.append(b)
	if atual.size() >= 2 and atual[0].distance_to(atual[atual.size() - 1]) > 0.5:
		pedacos.append([atual, corte_ini, false])
	return pedacos

# pedaço (t0, t1) do trecho a-b que está em cima de uma ponte, ou (-1, -1)
static func _corte(a: Vector2, b: Vector2) -> Vector2:
	for pt in lista:
		var cx: Rect2 = (pt as Ponte).caixa
		if not cx.intersects(Rect2(a, Vector2.ZERO).expand(b).grow(1.0)):
			continue
		var qa: Vector2 = pt.projetar(a)
		var qb: Vector2 = pt.projetar(b)
		if pt.ponto(qa.x).distance_to(a) > 1.5 or pt.ponto(qb.x).distance_to(b) > 1.5 or absf(qa.x - qb.x) < 0.5:
			continue
		var s0 := maxf(minf(qa.x, qb.x), pt.ini)
		var s1 := minf(maxf(qa.x, qb.x), pt.fim)
		if s1 <= s0:
			continue
		var ta := (s0 - qa.x) / (qb.x - qa.x)
		var tb := (s1 - qa.x) / (qb.x - qa.x)
		return Vector2(clampf(minf(ta, tb), 0.0, 1.0), clampf(maxf(ta, tb), 0.0, 1.0))
	return Vector2(-1.0, -1.0)

# prédio (planta x, z, tamanho) em cima de uma RUA NOVA (rua de 36 m + calçada + margem): sai para dar lugar a ela
static func em_rua_nova(x: float, z: float, sx: float, sz: float) -> bool:
	var ret := Rect2(x - sx * 0.5, z - sz * 0.5, sx, sz)
	for rd in RUAS_NOVAS:
		var f: Array = rd[1]
		var alc: float = float(rd[0]) * 0.5 + 5.0 + 0.5
		for k in range(0, f.size() - 3, 2):
			if _dist_seg_ret(Vector2(f[k], f[k + 1]), Vector2(f[k + 2], f[k + 3]), ret) < alc:
				return true
	return false

static func _dist_seg_ret(a: Vector2, b: Vector2, r: Rect2) -> float:
	var m := INF
	var n := maxi(2, int(a.distance_to(b) / 2.0))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		m = minf(m, p.distance_to(q))
		if m <= 0.0:
			break
	return m

# carro largado em cima da Ponte do Brooklyn: fica fora do canteiro do meio (o passeio elevado e o pilar das torres)
const CANTEIRO_BROOKLYN := 5.8
static func ajustar_carro(p: Vector2) -> Vector2:
	var q := consultar(p.x, p.y)
	if q.x < 0.0:
		return p
	var pt: Ponte = lista[int(q.x)]
	if pt.estilo != "brooklyn" or absf(q.z) >= CANTEIRO_BROOKLYN:
		return p
	var pr := pt.projetar(p)
	var lado := 1.0 if q.z >= 0.0 else -1.0
	var c := pt.ponto(pr.x)
	return c + pt.lateral(pr.x).normalized() * lado * CANTEIRO_BROOKLYN

# ======================= DESENHO (montado uma vez, na tela de carregamento) =======================
# Cores: o "a" (alfa) diz o material no shader da ponte: 1 = aço pintado (ferrugem) · 0,75 = pedra · 0,5 = concreto
# · 0,25 = madeira
const A_ACO := 1.0
const A_PEDRA := 0.75
const A_CONCRETO := 0.5
const A_MADEIRA := 0.25
const CONCRETO := Color(0.6, 0.58, 0.55, A_CONCRETO)
const CONCRETO_ESC := Color(0.42, 0.41, 0.4, A_CONCRETO)
const LUZ_QUENTE := Color(1.0, 0.86, 0.6, 0.0)
const LUZ_BRANCA := Color(0.95, 0.95, 1.0, 0.0)
const LUZ_TORRE := Color(1.0, 0.12, 0.08, 0.6)      # a > 0,5: pisca (shader dos halos de mundo/luzes_rua.gd)

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tex_pedra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_concreto : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_madeira : source_color, filter_linear_mipmap, repeat_enable;
global uniform float molhado;
varying vec3 wp;
float hash(vec2 p) {
	p = mod(p, 4096.0);
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
// detalhe da textura em volta de 1 (a cor média dela vira 1): a cor de cada peça continua a do desenho
vec3 det(sampler2D t, vec2 p, float forca) {
	vec3 m = max(textureLod(t, vec2(0.5), 10.0).rgb, vec3(0.04));
	return mix(vec3(1.0), texture(t, p).rgb / m, forca);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 c = COLOR.rgb;
	float k = COLOR.a;
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float perto = 1.0 - smoothstep(150.0, 600.0, dist);
	float rough = 0.88;
	float met = 0.0;
	if (k > 0.875) {
		// aço pintado: tinta desbotada e ferrugem escorrendo
		float n = ruido(vec2(wp.x + wp.z, wp.y) * 0.7);
		float f = smoothstep(0.6, 0.92, ruido(vec2((wp.x - wp.z) * 1.3, wp.y * 0.15)));
		c *= 0.86 + 0.26 * n;
		c = mix(c, vec3(0.3, 0.16, 0.08), f * 0.5 * perto);
		rough = 0.62;
		met = 0.3;
	} else if (k > 0.625) {
		c *= det(tex_pedra, UV / 6.5, 0.75 * (0.35 + 0.65 * perto));
		// fuligem embaixo e escorridos
		c *= 0.82 + 0.18 * smoothstep(-2.0, 12.0, wp.y) * (0.8 + 0.2 * ruido(vec2(wp.x + wp.z, wp.y * 0.08) * 2.0));
		rough = 0.93;
	} else if (k > 0.375) {
		c *= det(tex_concreto, UV / 4.0, 0.75 * (0.35 + 0.65 * perto));
		rough = 0.9;
	} else {
		c *= det(tex_madeira, UV / 2.0, 0.9);
		rough = 0.82;
	}
	ALBEDO = c * (1.0 - 0.22 * molhado);
	ROUGHNESS = mix(rough, 0.3, molhado * 0.7);
	METALLIC = met;
}
"""

static var _mat: ShaderMaterial = null
static func material() -> ShaderMaterial:
	if _mat == null:
		var s := Shader.new()
		s.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = s
		_mat.set_shader_parameter("tex_pedra", Mat._textura("predio_pedra"))
		_mat.set_shader_parameter("tex_concreto", Mat._textura("predio_concreto"))
		_mat.set_shader_parameter("tex_madeira", Mat._textura("interior_madeira"))
	return _mat

# uma ponte em construção: um construtor por pedaço (perto e longe), asfalto, calçada, faixas, colisão e luzes
class Obra:
	var pt
	var cid
	var n := 1
	var perto: Array = []
	var longe: Array = []
	var asfalto: Array = []
	var calcada: Array = []
	var fx_v: Array = []
	var fx_c: Array = []
	var col := PackedVector3Array()
	var caixas: Array = []                 # [Transform3D, Vector3 tamanho]
	var luzes: Array = []                  # [Vector3, Color]
	var terra := PackedByteArray()         # por amostra de PASSO m: 1 = em terra
	func _init(p, c) -> void:
		pt = p
		cid = c
		n = maxi(1, int(ceil((pt.fim - pt.ini) / PEDACO)))
		for i in n:
			for lst in [perto, longe, asfalto, calcada]:
				var k = load("res://mundo/malhas.gd").Construtor.new()
				k.ao = 0.16
				lst.append(k)
			fx_v.append(PackedVector3Array())
			fx_c.append(PackedColorArray())
		var m := int(ceil(pt.comp / PASSO)) + 1
		terra.resize(m)
		for i in m:
			terra[i] = 1 if (c == null or c._em_terra(pt.ponto(i * PASSO))) else 0
		# faixa de terra curta no meio da água (banco de areia) conta como água: sem muro nem cabeceira ali
		var i := 0
		while i < m:
			if terra[i] == 1:
				var j := i
				while j < m and terra[j] == 1:
					j += 1
				if i > 0 and j < m and (j - i) * PASSO < 80.0:
					for k2 in range(i, j):
						terra[k2] = 0
				i = j
			else:
				i += 1
	func k(s: float) -> int:
		return clampi(int((s - pt.ini) / PEDACO), 0, n - 1)
	func c(s: float):
		return perto[k(s)]
	func cl(s: float):
		return longe[k(s)]
	func em_terra(s: float) -> bool:
		return terra[clampi(int(round(s / PASSO)), 0, terra.size() - 1)] == 1
	# colisão: retângulo (dois triângulos)
	func col_quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3) -> void:
		col.append_array(PackedVector3Array([a, b, cc, a, cc, d]))
	func col_caixa(t: Transform3D, centro: Vector3, tam: Vector3) -> void:
		caixas.append([Transform3D(t.basis, t * centro), tam])
	func luz(p: Vector3, cor: Color) -> void:
		luzes.append([p, cor])

# ---------- primitivas ----------
# retângulo a-b-c-d; a frente fica para o lado de "n" (vira sozinho)
static func _q(c, a: Vector3, b: Vector3, cc: Vector3, d: Vector3, n: Vector3, cor: Color) -> void:
	var nn := (b - a).cross(cc - b)
	if nn.dot(n) < 0.0:
		var t := b
		b = d
		d = t
		nn = -nn
	var lu := a.distance_to(b)
	var lv := b.distance_to(cc)
	c._quad(a, b, cc, d, nn.normalized(), cor, Vector2(0, lv), Vector2(lu, lv), Vector2(lu, 0), Vector2(0, 0))

# barra (viga, diagonal, pendural) de a até b, seção larg x alt
static func _barra(c, a: Vector3, b: Vector3, larg: float, alt: float, cor: Color) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.02:
		return
	var x := d / L
	var ref := Vector3.UP if absf(x.y) < 0.9 else Vector3.FORWARD
	var z := x.cross(ref).normalized()
	var y := z.cross(x)
	c.caixa((a + b) * 0.5, Vector3(L, alt, larg), cor, Basis(x, y, z))

# cabo/tubo passando pelos pontos (lados = 4 a 8)
static func _tubo(c, pts: PackedVector3Array, raio: float, lados: int, cor: Color) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var x := (b - a).normalized()
		var ref := Vector3.UP if absf(x.y) < 0.9 else Vector3.FORWARD
		var u := x.cross(ref).normalized()
		var v := u.cross(x)
		for j in lados:
			var a0 := TAU * j / lados
			var a1 := TAU * (j + 1) / lados
			var o0 := (u * cos(a0) + v * sin(a0)) * raio
			var o1 := (u * cos(a1) + v * sin(a1)) * raio
			_q(c, a + o0, b + o0, b + o1, a + o1, (o0 + o1).normalized(), cor)

# caixa no quadro local t
static func _cx(c, t: Transform3D, centro: Vector3, tam: Vector3, cor: Color) -> void:
	c.caixa(t * centro, tam, cor, t.basis)

# PAINEL COM ARCO no quadro local: parede de x0 a x1, de y0 (onde o arco nasce) a y1, espessura de z0 a z1, com a
# abertura do arco de y0 até "topo" (ogiva = arco gótico pontudo · senão, arco redondo/abatido); faz as duas faces e
# o intradorso (a parte de baixo do arco)
static func _arco(c, t: Transform3D, x0: float, x1: float, y0: float, y1: float, topo: float, z0: float, z1: float, cor: Color, ogiva := true) -> void:
	var n := 16
	var meio := (x0 + x1) * 0.5
	var semi := (x1 - x0) * 0.5
	var alt := topo - y0
	# ogiva: dois arcos de círculo que se cruzam no alto (centro de cada um deslocado "e" para o outro lado)
	var e := (alt * alt - semi * semi) / (2.0 * semi)
	var raio := semi + e
	var curva := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n                     # 0 = pé esquerdo, 1 = pé direito
		var x := x0 + (x1 - x0) * u
		var y: float
		if ogiva and e > 0.0:
			var xc := (meio + e) if x <= meio else (meio - e)
			y = y0 + sqrt(maxf(0.0, raio * raio - (x - xc) * (x - xc)))
		else:
			var dx := (x - meio) / semi
			y = y0 + alt * sqrt(maxf(0.0, 1.0 - dx * dx))
		curva.append(Vector2(x, y))
	for i in n:
		var a := curva[i]
		var b := curva[i + 1]
		for z in [z0, z1]:
			var nz := Vector3(0, 0, 1) if z == z1 else Vector3(0, 0, -1)
			_q(c, t * Vector3(a.x, a.y, z), t * Vector3(b.x, b.y, z), t * Vector3(b.x, y1, z), t * Vector3(a.x, y1, z), t.basis * nz, cor)
		# intradorso (virado para baixo/para dentro do arco)
		var meio_ab := (a + b) * 0.5
		var nin := Vector3(-(b.y - a.y), b.x - a.x, 0).normalized()
		if nin.y > 0.0:
			nin = -nin
		_q(c, t * Vector3(a.x, a.y, z0), t * Vector3(b.x, b.y, z0), t * Vector3(b.x, b.y, z1), t * Vector3(a.x, a.y, z1), t.basis * nin, cor * 0.85)
	# topo do painel
	_q(c, t * Vector3(x0, y1, z0), t * Vector3(x1, y1, z0), t * Vector3(x1, y1, z1), t * Vector3(x0, y1, z1), t.basis * Vector3.UP, cor)

# ---------- montagem ----------
# devolve os nós (desenho por pedaço, colisão e luzes) para mundo/cidade.gd pôr na cena
static func montar(cid) -> Array:
	preparar()
	var nos: Array = []
	for pt in lista:
		var o := Obra.new(pt, cid)
		_tabuleiro(o)
		match pt.estilo:
			"brooklyn":
				_brooklyn(o)
			"manhattan":
				_manhattan(o)
			"gwb":
				_gwb(o)
			"queensboro":
				_queensboro(o)
			_:
				_trelica(o)
		nos.append_array(_nos(o, cid))
		if cid != null and cid.has_method("pausa"):
			await cid.pausa()
	return nos

static func _nos(o: Obra, cid) -> Array:
	var r: Array = []
	var pt: Ponte = o.pt
	var mat := material()
	var m_asf: Material = null
	var m_calc: Material = null
	if cid != null and cid.mats_chao.size() >= 4:
		m_calc = cid.mats_chao[2]
		m_asf = cid.mats_chao[3]
	else:
		m_asf = Malhas.mat_cores()
		m_calc = Malhas.mat_cores()
	var m_fx := Mat.material(Mat.FAIXA, {"camada": 5.0})
	for i in o.n:
		var am: ArrayMesh = o.perto[i].malha(mat)
		o.asfalto[i].malha(m_asf, am)
		o.calcada[i].malha(m_calc, am)
		var v: PackedVector3Array = o.fx_v[i]
		if not v.is_empty():
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			var nn := PackedVector3Array()
			nn.resize(v.size())
			nn.fill(Vector3.UP)
			arr[Mesh.ARRAY_VERTEX] = v
			arr[Mesh.ARRAY_NORMAL] = nn
			arr[Mesh.ARRAY_COLOR] = o.fx_c[i]
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(am.get_surface_count() - 1, m_fx)
		var mi := MeshInstance3D.new()
		mi.name = "Ponte%d_perto_%d" % [pt.idx, i]
		mi.mesh = am
		mi.visibility_range_end = PERTO
		mi.visibility_range_end_margin = 40.0
		r.append(mi)
		var ml: ArrayMesh = o.longe[i].malha(mat)
		var ml_i := MeshInstance3D.new()
		ml_i.name = "Ponte%d_longe_%d" % [pt.idx, i]
		ml_i.mesh = ml
		ml_i.visibility_range_begin = PERTO - 40.0
		ml_i.visibility_range_begin_margin = 40.0
		ml_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.append(ml_i)
	# colisão
	var corpo := StaticBody3D.new()
	corpo.name = "Ponte%d_colisao" % pt.idx
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(o.col)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	corpo.add_child(cs)
	for e in o.caixas:
		var b := BoxShape3D.new()
		b.size = e[1]
		var cb := CollisionShape3D.new()
		cb.shape = b
		cb.transform = e[0]
		corpo.add_child(cb)
	corpo.set_meta("ponte", pt.nome)
	r.append(corpo)
	r.append_array(_halos(o.luzes, pt.idx))
	return r

# luzes (halos de mundo/luzes_rua.gd: só aparecem à noite; cor.a > 0,5 pisca)
static func _halos(luzes: Array, idx: int) -> Array:
	var r: Array = []
	if luzes.is_empty():
		return r
	var por_bloco := {}
	for e in luzes:
		var p: Vector3 = e[0]
		var k := Vector2i(floori(p.x / 500.0), floori(p.z / 500.0))
		if not por_bloco.has(k):
			por_bloco[k] = []
		por_bloco[k].append(e)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = LuzesRua.material()
	for k in por_bloco:
		var lista_b: Array = por_bloco[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = lista_b.size()
		for i in lista_b.size():
			var cor: Color = lista_b[i][1]
			var tam := 3.6 if cor.a > 0.5 else 2.4
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * tam), lista_b[i][0]))
			if cor.a > 0.5:
				cor.a = 0.51 + fposmod((lista_b[i][0] as Vector3).x * 0.013, 0.48)
			mm.set_instance_custom_data(i, cor)
		var mi := MultiMeshInstance3D.new()
		mi.name = "Ponte%d_luzes_%d_%d" % [idx, k.x, k.y]
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = ALCANCE_LUZ
		mi.add_to_group("halos_luz")
		mi.visible = LuzesRua.opcao_halos and LuzesRua._noite > 0.0
		LuzesRua._halos.append(mi)
		r.append(mi)
	return r

# lâmpada acesa ou queimada (sempre a mesma: sorteio pela posição)
static func _acesa(p: Vector3, chance: float) -> bool:
	return absi(hash(Vector2i(roundi(p.x * 3.0), roundi(p.z * 3.0)))) % 1000 < int(chance * 1000.0)

static func _tri(c, a: Vector3, b: Vector3, cc: Vector3, n: Vector3, cor: Color) -> void:
	var nn := (b - a).cross(cc - b)
	if nn.dot(n) < 0.0:
		var t := b
		b = cc
		cc = t
		nn = -nn
	nn = nn.normalized()
	for p in [a, cc, b]:
		c.v.append(p)
		c.n.append(nn)
		c.c.append(cor)
		c.uv.append(Vector2(p.x + p.z, p.y))

static func _fora(pt: Ponte, s: float, lado: float) -> Vector3:
	var n: Vector2 = pt.lateral(s).normalized() * lado
	return Vector3(n.x, 0, n.y)

# ---------- TABULEIRO (todas): asfalto, calçadas, faixas, a laje, os muros das rampas em terra e a colisão ----------
static func _tabuleiro(o: Obra) -> void:
	var pt: Ponte = o.pt
	var est: String = pt.estilo
	var pedra: bool = est == "brooklyn" or est == "manhattan"
	var cor_muro: Color = Color(0.64, 0.58, 0.49, A_PEDRA) if pedra else CONCRETO
	if est == "manhattan":
		cor_muro = Color(0.6, 0.55, 0.48, A_PEDRA)
	var cor_laje: Color = CONCRETO_ESC
	var ss: PackedFloat32Array = pt.amostras(pt.ini, pt.fim, 6.0)
	var esp := 1.3
	var ult_terra := o.em_terra(pt.ini)
	for i in ss.size() - 1:
		var s0: float = ss[i]
		var s1: float = ss[i + 1]
		var sm := (s0 + s1) * 0.5
		var k := o.k(sm)
		var c = o.perto[k]
		var h0: float = pt.h(s0)
		var h1: float = pt.h(s1)
		_q(o.asfalto[k], pt.p3(s0, -MEIA_RUA, h0), pt.p3(s1, -MEIA_RUA, h1), pt.p3(s1, MEIA_RUA, h1), pt.p3(s0, MEIA_RUA, h0), Vector3.UP, Color.WHITE)
		for lado in [-1.0, 1.0]:
			_q(o.calcada[k], pt.p3(s0, lado * MEIA_RUA, h0), pt.p3(s1, lado * MEIA_RUA, h1), pt.p3(s1, lado * MEIA, h1), pt.p3(s0, lado * MEIA, h0), Vector3.UP, Color.WHITE)
		# colisão: o tabuleiro e a mureta/grade de 1,25 m dos dois lados
		o.col_quad(pt.p3(s0, -MEIA - 0.3, h0), pt.p3(s1, -MEIA - 0.3, h1), pt.p3(s1, MEIA + 0.3, h1), pt.p3(s0, MEIA + 0.3, h0))
		for lado in [-1.0, 1.0]:
			var l: float = lado * (MEIA + 0.3)
			o.col_quad(pt.p3(s0, l, h0), pt.p3(s1, l, h1), pt.p3(s1, l, h1 + 1.25), pt.p3(s0, l, h0 + 1.25))
		var terra := o.em_terra(sm)
		if terra != ult_terra and maxf(h0, h1) > 1.5:
			# encontro (a cabeceira de pedra/concreto onde a ponte sai da margem)
			var sb := s0
			var tq: Transform3D = pt.quadro(sb)
			var hb := pt.h(sb)
			_cx(c, tq, Vector3(0, (hb - esp - 5.0) * 0.5, 0), Vector3(2.0 * MEIA + 2.0, hb - esp + 5.0, 5.0), cor_muro)
			_cx(o.cl(sb), tq, Vector3(0, (hb - esp - 5.0) * 0.5, 0), Vector3(2.0 * MEIA + 2.0, hb - esp + 5.0, 5.0), cor_muro)
			o.col_caixa(tq, Vector3(0, (hb - esp - 5.0) * 0.5, 0), Vector3(2.0 * MEIA + 2.0, hb - esp + 5.0, 5.0))
		ult_terra = terra
		if terra:
			if maxf(h0, h1) < 0.9:
				continue
			# rampa em terra: muro dos dois lados até o chão (com mureta) e a colisão dele
			for lado in [-1.0, 1.0]:
				var l: float = lado * (MEIA + 0.3)
				var fo: Vector3 = _fora(pt, sm, lado)
				_q(c, pt.p3(s0, l, -0.8), pt.p3(s1, l, -0.8), pt.p3(s1, l, h1 + 1.1), pt.p3(s0, l, h0 + 1.1), fo, cor_muro)
				_q(c, pt.p3(s0, l - lado * 0.45, h0), pt.p3(s1, l - lado * 0.45, h1), pt.p3(s1, l - lado * 0.45, h1 + 1.1), pt.p3(s0, l - lado * 0.45, h0 + 1.1), -fo, cor_muro)
				_q(c, pt.p3(s0, l - lado * 0.45, h0 + 1.1), pt.p3(s1, l - lado * 0.45, h1 + 1.1), pt.p3(s1, l + lado * 0.1, h1 + 1.2), pt.p3(s0, l + lado * 0.1, h0 + 1.2), Vector3.UP, cor_muro * 1.06)
				o.col_quad(pt.p3(s0, l, -0.8), pt.p3(s1, l, -0.8), pt.p3(s1, l, h1), pt.p3(s0, l, h0))
				_q(o.cl(sm), pt.p3(s0, l, -0.8), pt.p3(s1, l, -0.8), pt.p3(s1, l, h1 + 1.1), pt.p3(s0, l, h0 + 1.1), fo, cor_muro)
			continue
		# sobre a água: a laje por baixo e a borda (o resto é de cada estilo)
		_q(c, pt.p3(s0, -MEIA, h0 - esp), pt.p3(s1, -MEIA, h1 - esp), pt.p3(s1, MEIA, h1 - esp), pt.p3(s0, MEIA, h0 - esp), Vector3.DOWN, cor_laje)
		for lado in [-1.0, 1.0]:
			var fo: Vector3 = _fora(pt, sm, lado)
			_q(c, pt.p3(s0, lado * MEIA, h0 - esp), pt.p3(s1, lado * MEIA, h1 - esp), pt.p3(s1, lado * MEIA, h1 + 0.05), pt.p3(s0, lado * MEIA, h0 + 0.05), fo, cor_laje * 1.1)
	# muro de concreto das rampas: pilastras a cada 15 m e a faixa no alto (não fica um paredão liso)
	if not pedra:
		var sc: float = pt.ini + 7.5
		while sc < pt.fim - 7.5:
			var hs: float = pt.h(sc)
			if o.em_terra(sc) and hs > 2.5:
				var tq: Transform3D = pt.quadro(sc)
				for lado in [-1.0, 1.0]:
					_cx(o.c(sc), tq, Vector3(lado * (MEIA + 0.55), (hs - 0.8) * 0.5, 0), Vector3(0.5, hs + 0.8, 1.1), cor_muro * 0.9)
					_cx(o.c(sc), tq, Vector3(lado * (MEIA + 0.4), hs - 0.25, 0), Vector3(0.3, 0.5, 15.2), cor_muro * 0.85)
			sc += 15.0
	# ARCADAS (relevo) nos muros de pedra das rampas: arco escuro a cada 22 m onde o muro passa de 6 m
	if pedra:
		var s := pt.ini + 11.0
		while s < pt.fim - 11.0:
			var hs: float = pt.h(s)
			if o.em_terra(s) and o.em_terra(s - 9.0) and o.em_terra(s + 9.0) and hs > 6.0:
				for lado in [-1.0, 1.0]:
					var l: float = lado * (MEIA + 0.33)
					var fo: Vector3 = _fora(pt, s, lado)
					var y_m := hs * 0.55
					var largura := 7.0
					var esc := Color(0.24, 0.22, 0.2, A_PEDRA)
					var c = o.c(s)
					_q(c, pt.p3(s - largura, l, 0.0), pt.p3(s + largura, l, 0.0), pt.p3(s + largura, l, y_m), pt.p3(s - largura, l, y_m), fo, esc)
					var nseg := 8
					for j in nseg:
						var a0 := PI * j / nseg
						var a1 := PI * (j + 1) / nseg
						var alto_arco := minf(largura, hs - 1.5 - y_m)
						_tri(c, pt.p3(s, l, y_m), pt.p3(s + cos(a0) * largura, l, y_m + sin(a0) * alto_arco), pt.p3(s + cos(a1) * largura, l, y_m + sin(a1) * alto_arco), fo, esc)
					# pedra de fecho e a faixa (cornija) no alto do muro
					_q(c, pt.p3(s - 11.0, l + lado * 0.05, hs - 0.6), pt.p3(s + 11.0, l + lado * 0.05, pt.h(s + 11.0) - 0.6), pt.p3(s + 11.0, l + lado * 0.05, pt.h(s + 11.0) - 0.2), pt.p3(s - 11.0, l + lado * 0.05, hs - 0.2), fo, cor_muro * 0.85)
			s += 22.0
	# FAIXAS pintadas (as mesmas funções das ruas, levantadas até o tabuleiro)
	if o.cid != null and o.cid.has_method("_faixas_trecho"):
		for i in pt.pts.size() - 1:
			var a0: float = maxf(pt.ini, pt.acc[i])
			var a1: float = minf(pt.fim, pt.acc[i + 1])
			if a1 - a0 < 4.0:
				continue
			var ga := 0.0
			var gb := 0.0
			if absf(a0 - pt.acc[i]) < 0.01 and i > 0:
				ga = (pt.pts[i] - pt.pts[i - 1]).angle_to(pt.pts[i + 1] - pt.pts[i])
			if absf(a1 - pt.acc[i + 1]) < 0.01 and i + 1 < pt.pts.size() - 1:
				gb = (pt.pts[i + 1] - pt.pts[i]).angle_to(pt.pts[i + 2] - pt.pts[i + 1])
			var v := PackedVector3Array()
			var cc := PackedColorArray()
			o.cid._faixas_trecho(v, cc, pt.ponto(a0), pt.ponto(a1), MEIA_RUA, false, false, ga, gb)
			for t in range(0, v.size() - 2, 3):
				var kk := o.k(pt.projetar(Vector2(v[t].x, v[t].z)).x)
				for j in 3:
					var q: Vector3 = v[t + j]
					q.y += pt.h(pt.projetar(Vector2(q.x, q.z)).x) - Y_RUA
					o.fx_v[kk].append(q)
					o.fx_c[kk].append(cc[t + j])
	# LONGE: tabuleiro inteiro em tiras de 24 m (topo, laje e bordas)
	var sl: PackedFloat32Array = pt.amostras(pt.ini, pt.fim, 24.0)
	for i in sl.size() - 1:
		var s0: float = sl[i]
		var s1: float = sl[i + 1]
		var sm := (s0 + s1) * 0.5
		var cl = o.cl(sm)
		var h0: float = pt.h(s0)
		var h1: float = pt.h(s1)
		_q(cl, pt.p3(s0, -MEIA, h0), pt.p3(s1, -MEIA, h1), pt.p3(s1, MEIA, h1), pt.p3(s0, MEIA, h0), Vector3.UP, Color(0.2, 0.2, 0.21, A_CONCRETO))
		_q(cl, pt.p3(s0, -MEIA, h0 - esp), pt.p3(s1, -MEIA, h1 - esp), pt.p3(s1, MEIA, h1 - esp), pt.p3(s0, MEIA, h0 - esp), Vector3.DOWN, cor_laje)
		for lado in [-1.0, 1.0]:
			var fo: Vector3 = _fora(pt, sm, lado)
			_q(cl, pt.p3(s0, lado * MEIA, h0 - esp), pt.p3(s1, lado * MEIA, h1 - esp), pt.p3(s1, lado * MEIA, h1 + 1.0), pt.p3(s0, lado * MEIA, h0 + 1.0), fo, cor_laje)

# ---------- TRELIÇA de um lado (corda de baixo, de cima, montantes e diagonais) ----------
# tipo: "warren" (diagonais em zigue-zague) · "x" (as duas diagonais) · "pratt" (diagonais descendo para o meio)
static func _trelica_lateral(o: Obra, s0: float, s1: float, lat: float, y_b: Callable, y_c: Callable, painel: float, cor: Color, tipo: String, evitar: Array, raio_evitar: float, grossa := 1.0) -> void:
	var pt: Ponte = o.pt
	var n := maxi(1, int(round((s1 - s0) / painel)))
	var dp := (s1 - s0) / n
	var ant_b := Vector3.ZERO
	var ant_c := Vector3.ZERO
	var ant_ok := false
	var meio_s := (s0 + s1) * 0.5
	for i in n + 1:
		var s := s0 + dp * i
		var ok := true
		for e in evitar:
			if absf(s - float(e)) < raio_evitar:
				ok = false
		var pb: Vector3 = pt.p3(s, lat, float(y_b.call(s)))
		var pc: Vector3 = pt.p3(s, lat, float(y_c.call(s)))
		if ok:
			var c = o.c(s - dp * 0.5 if i > 0 else s)
			if pc.y - pb.y > 0.3:
				_barra(c, pb, pc, 0.3 * grossa, 0.3 * grossa, cor)
			if i > 0 and ant_ok:
				_barra(c, ant_b, pb, 0.45 * grossa, 0.5 * grossa, cor)
				_barra(c, ant_c, pc, 0.45 * grossa, 0.55 * grossa, cor)
				match tipo:
					"x":
						_barra(c, ant_b, pc, 0.22 * grossa, 0.22 * grossa, cor)
						_barra(c, ant_c, pb, 0.22 * grossa, 0.22 * grossa, cor)
					"pratt":
						if s <= meio_s:
							_barra(c, ant_c, pb, 0.24 * grossa, 0.24 * grossa, cor)
						else:
							_barra(c, ant_b, pc, 0.24 * grossa, 0.24 * grossa, cor)
					_:
						if i % 2 == 0:
							_barra(c, ant_b, pc, 0.24 * grossa, 0.24 * grossa, cor)
						else:
							_barra(c, ant_c, pb, 0.24 * grossa, 0.24 * grossa, cor)
		ant_b = pb
		ant_c = pc
		ant_ok = ok
	# longe: uma faixa nos dois sentidos (um pouco mais escura: "furada")
	var passo := maxf(dp, 18.0)
	var nl := maxi(1, int(round((s1 - s0) / passo)))
	for i in nl:
		var a := s0 + (s1 - s0) * i / nl
		var b := s0 + (s1 - s0) * (i + 1) / nl
		var cl = o.cl((a + b) * 0.5)
		var fo: Vector3 = _fora(pt, (a + b) * 0.5, signf(lat) if lat != 0.0 else 1.0)
		var q0: Vector3 = pt.p3(a, lat, float(y_b.call(a)))
		var q1: Vector3 = pt.p3(b, lat, float(y_b.call(b)))
		var q2: Vector3 = pt.p3(b, lat, float(y_c.call(b)))
		var q3: Vector3 = pt.p3(a, lat, float(y_c.call(a)))
		_q(cl, q0, q1, q2, q3, fo, cor * 0.78)
		_q(cl, q0, q1, q2, q3, -fo, cor * 0.7)

# ---------- CABOS PRINCIPAIS ----------
# curva do cabo: parábola no vão do meio (a flecha é a maior possível deixando "folga" sobre onde o pendural
# termina) e quase reta nos vãos laterais (da âncora até a sela no alto da torre)
static func _cabo(pt: Ponte, torres: Array, ancoras: Array, y_sela: Array, y_anc: Array, fim_pend: Callable, folga: float) -> Dictionary:
	var t1: float = torres[0]
	var t2: float = torres[1]
	var y1: float = y_sela[0]
	var y2: float = y_sela[1]
	var flecha := INF
	var s := t1 + 4.0
	while s < t2 - 4.0:
		var u := (s - t1) / (t2 - t1)
		var lin := lerpf(y1, y2, u)
		flecha = minf(flecha, (lin - float(fim_pend.call(s)) - folga) / (4.0 * u * (1.0 - u)))
		s += 4.0
	return {"t1": t1, "t2": t2, "Y1": y1, "Y2": y2, "flecha": maxf(flecha, 0.0), "a1": float(ancoras[0]), "a2": float(ancoras[1]),
		"A1": float(y_anc[0]), "A2": float(y_anc[1])}

static func _y_cabo(cb: Dictionary, s: float) -> float:
	if s <= cb["t1"]:
		var L: float = cb["t1"] - cb["a1"]
		var u: float = clampf((s - cb["a1"]) / L, 0.0, 1.0)
		return lerpf(cb["A1"], cb["Y1"], u) - 0.08 * L * u * (1.0 - u)
	if s >= cb["t2"]:
		var L: float = cb["a2"] - cb["t2"]
		var u: float = clampf((s - cb["t2"]) / L, 0.0, 1.0)
		return lerpf(cb["Y2"], cb["A2"], u) - 0.08 * L * u * (1.0 - u)
	var u: float = (s - cb["t1"]) / (cb["t2"] - cb["t1"])
	return lerpf(cb["Y1"], cb["Y2"], u) - 4.0 * cb["flecha"] * u * (1.0 - u)

# desenha o cabo (tubo), os pendurais (de passo em passo, menos colado nas torres) e o colar de luzes
static func _desenhar_cabo(o: Obra, cb: Dictionary, lat: float, raio: float, cor: Color, passo: float, fim_pend: Callable, luzes: bool, pend_laterais := true) -> void:
	var pt: Ponte = o.pt
	var ss: Array = []
	var s: float = cb["a1"]
	while s < cb["a2"]:
		ss.append(s)
		s += 7.0
	ss.append(cb["a2"])
	for st in [cb["t1"], cb["t2"]]:
		ss.append(st)
	ss.sort()
	var pedaco := PackedVector3Array()
	var k_ant := -1
	for sv in ss:
		var p: Vector3 = pt.p3(sv, lat, _y_cabo(cb, sv))
		var k := o.k(sv)
		if k != k_ant and pedaco.size() >= 1:
			pedaco.append(p)
			_tubo(o.perto[k_ant], pedaco, raio, 6, cor)
			pedaco = PackedVector3Array()
		pedaco.append(p)
		k_ant = k
	if pedaco.size() >= 2:
		_tubo(o.perto[k_ant], pedaco, raio, 6, cor)
	# longe: tubo de 4 lados a cada ~21 m
	var nl := maxi(2, int((cb["a2"] - cb["a1"]) / 21.0))
	for i in nl:
		var a: float = lerpf(cb["a1"], cb["a2"], float(i) / nl)
		var b: float = lerpf(cb["a1"], cb["a2"], float(i + 1) / nl)
		_tubo(o.cl((a + b) * 0.5), PackedVector3Array([pt.p3(a, lat, _y_cabo(cb, a)), pt.p3(b, lat, _y_cabo(cb, b))]), raio * 2.2, 4, cor)
	# pendurais
	s = cb["a1"] + passo
	while s < cb["a2"] - 3.0:
		var lateral_vao: bool = s < cb["t1"] or s > cb["t2"]
		if absf(s - cb["t1"]) > 11.0 and absf(s - cb["t2"]) > 11.0 and (pend_laterais or not lateral_vao):
			var yt := _y_cabo(cb, s)
			var yb: float = fim_pend.call(s)
			if yt - yb > 0.8:
				_barra(o.c(s), pt.p3(s, lat, yb), pt.p3(s, lat, yt), 0.15, 0.15, cor * 0.9)
		s += passo
	# colar de lâmpadas no cabo (à noite)
	if luzes:
		s = cb["a1"] + 6.0
		while s < cb["a2"] - 4.0:
			var p: Vector3 = pt.p3(s, lat, _y_cabo(cb, s) + raio + 0.25)
			if _acesa(p, 0.78):
				o.luz(p, LUZ_QUENTE)
			s += 11.0

# ---------- ANCORAGEM: bloco de baixo (o tabuleiro passa por cima) e os dois blocos dos lados, onde os cabos entram ----------
static func _ancoragem(o: Obra, sa: float, cor: Color, comp: float, larg_lado: float, acima: float) -> void:
	var pt: Ponte = o.pt
	var t: Transform3D = pt.quadro(sa)
	var ha: float = pt.h(sa)
	var esc := Color(cor.r * 0.82, cor.g * 0.82, cor.b * 0.82, cor.a)
	for c in [o.c(sa), o.cl(sa)]:
		_cx(c, t, Vector3(0, (-4.5 + ha - 1.3) * 0.5, 0), Vector3(2.0 * MEIA + 2.0 * larg_lado + 1.0, ha - 1.3 + 4.5, comp), cor)
		for lado in [-1.0, 1.0]:
			var x: float = lado * (MEIA + 0.5 + larg_lado * 0.5)
			_cx(c, t, Vector3(x, (ha - 1.3 + ha + acima) * 0.5, 0), Vector3(larg_lado, acima + 1.3, comp), cor)
			_cx(c, t, Vector3(x, ha + acima + 0.4, 0), Vector3(larg_lado + 1.0, 0.8, comp + 1.0), esc)
	var c0 = o.c(sa)
	for lado in [-1.0, 1.0]:
		var x: float = lado * (MEIA + 0.5 + larg_lado * 0.5)
		# almofadas (painéis rebaixados) nas faces e a faixa no meio da altura
		for fz in [-1.0, 1.0]:
			_cx(c0, t, Vector3(x, ha + acima * 0.45, fz * (comp * 0.5 + 0.05)), Vector3(larg_lado * 0.6, acima * 0.55, 0.12), esc)
		_cx(c0, t, Vector3(x + lado * (larg_lado * 0.5 + 0.05), ha + acima * 0.45, 0), Vector3(0.12, acima * 0.55, comp * 0.7), esc)
		_cx(c0, t, Vector3(x, ha - 2.5, 0), Vector3(larg_lado + 0.6, 0.7, comp + 0.6), esc)
		o.col_caixa(t, Vector3(x, (ha - 1.3 + ha + acima) * 0.5, 0), Vector3(larg_lado, acima + 1.3, comp))
	o.col_caixa(t, Vector3(0, (-4.5 + ha - 1.3) * 0.5, 0), Vector3(2.0 * MEIA + 2.0 * larg_lado + 1.0, ha - 1.3 + 4.5, comp))

# ======================= PONTE DO BROOKLYN =======================
const B_PEDRA := Color(0.74, 0.64, 0.5, A_PEDRA)
const B_PEDRA_ESC := Color(0.6, 0.51, 0.4, A_PEDRA)
const B_ACO := Color(0.66, 0.58, 0.44, A_ACO)           # o "bege Brooklyn" das treliças
const B_CABO := Color(0.58, 0.55, 0.49, A_ACO)
const B_MADEIRA := Color(0.56, 0.46, 0.36, A_MADEIRA)
const B_ALTURA := 52.0                                  # topo da torre acima do tabuleiro
const B_SELA := 48.0

static func _brooklyn(o: Obra) -> void:
	var pt: Ponte = o.pt
	var d: Dictionary = pt.dados
	var torres: Array = d["torres"]
	var ancoras: Array = d["ancoras"]
	var sp0: float = d["passeio"][0]
	var sp1: float = d["passeio"][1]
	for st in torres:
		_torre_brooklyn(o, st)
	for sa in ancoras:
		_ancoragem(o, sa, B_PEDRA, 40.0, 12.0, 8.0)
	# treliças de fora (das ancoragens às ancoragens) e as do canteiro do meio (debaixo do passeio)
	var yb := func(s: float) -> float: return pt.h(s) - 3.4
	var yc := func(s: float) -> float: return pt.h(s) + 1.3
	for lado in [-1.0, 1.0]:
		_trelica_lateral(o, ancoras[0] + 20.0, ancoras[1] - 20.0, lado * (MEIA - 0.15), yb, yc, 5.0, B_ACO, "warren", torres, 9.6)
	var yp := func(s: float) -> float: return _y_passeio(pt, s, sp0, sp1) - 0.3
	var yd := func(s: float) -> float: return pt.h(s)
	for lado in [-1.0, 1.0]:
		_trelica_lateral(o, sp0 - 40.0, sp1 + 40.0, lado * 3.8, yd, yp, 6.0, B_ACO, "warren", torres, 9.6, 0.8)
	# vigas transversais embaixo (a cada 10 m, sobre a água)
	var s: float = float(ancoras[0]) + 25.0
	while s < ancoras[1] - 25.0:
		var ok := true
		for st in torres:
			if absf(s - float(st)) < 10.0:
				ok = false
		if ok and not o.em_terra(s):
			_barra(o.c(s), pt.p3(s, -MEIA, pt.h(s) - 3.2), pt.p3(s, MEIA, pt.h(s) - 3.2), 0.35, 0.7, B_ACO * 0.9)
		s += 10.0
	_passeio(o, sp0, sp1, torres)
	# os 4 cabos (2 de fora, em cima da treliça; 2 de dentro, na beira do passeio), os pendurais e os ESTAIS em leque
	var fim_fora := func(s2: float) -> float: return pt.h(s2) + 1.3
	var fim_dentro := func(s2: float) -> float: return _y_passeio(pt, s2, sp0, sp1) + 0.9
	for pl in [[-23.4, true], [23.4, true], [-3.5, false], [3.5, false]]:
		var lat: float = pl[0]
		var fora: bool = pl[1]
		var fim_p: Callable = fim_fora if fora else fim_dentro
		var y_anc: Array = [pt.h(ancoras[0]) + (7.5 if fora else 1.5), pt.h(ancoras[1]) + (7.5 if fora else 1.5)]
		var cb := _cabo(pt, torres, ancoras, [pt.h(torres[0]) + B_SELA, pt.h(torres[1]) + B_SELA], y_anc, fim_p, 3.0)
		_desenhar_cabo(o, cb, lat, 0.34, B_CABO, 5.0, fim_p, fora)
		for st in torres:
			var ys := _y_cabo(cb, float(st)) - 1.2
			for dir in [-1.0, 1.0]:
				for k in range(1, 10):
					var sd: float = float(st) + dir * (10.0 + k * 12.5)
					if sd < cb["a1"] + 6.0 or sd > cb["a2"] - 6.0:
						continue
					_barra(o.c(sd), pt.p3(float(st) + dir * 8.5, lat, ys), pt.p3(sd, lat, float(fim_p.call(sd))), 0.13, 0.13, B_CABO * 0.92)

static func _y_passeio(pt: Ponte, s: float, sp0: float, sp1: float) -> float:
	var sobe := clampf((s - (sp0 - 55.0)) / 55.0, 0.0, 1.0)
	var desce := clampf(((sp1 + 55.0) - s) / 55.0, 0.0, 1.0)
	return pt.h(s) + 0.01 + 5.49 * minf(sobe, desce)

# o PASSEIO de madeira elevado no meio (de pedestres e bicicletas), com grade, postes de luz e as rampas nas pontas
static func _passeio(o: Obra, sp0: float, sp1: float, torres: Array) -> void:
	var pt: Ponte = o.pt
	var ss: PackedFloat32Array = pt.amostras(sp0 - 55.0, sp1 + 55.0, 4.0)
	var meia := 3.5
	var ferro := Color(0.14, 0.15, 0.15, A_ACO)
	for i in ss.size() - 1:
		var s0: float = ss[i]
		var s1: float = ss[i + 1]
		var sm := (s0 + s1) * 0.5
		var y0 := _y_passeio(pt, s0, sp0, sp1)
		var y1 := _y_passeio(pt, s1, sp0, sp1)
		var c = o.c(sm)
		_q(c, pt.p3(s0, -meia, y0), pt.p3(s1, -meia, y1), pt.p3(s1, meia, y1), pt.p3(s0, meia, y0), Vector3.UP, B_MADEIRA)
		_q(c, pt.p3(s0, -meia, y0 - 0.45), pt.p3(s1, -meia, y1 - 0.45), pt.p3(s1, meia, y1 - 0.45), pt.p3(s0, meia, y0 - 0.45), Vector3.DOWN, B_ACO * 0.8)
		o.col_quad(pt.p3(s0, -meia, y0), pt.p3(s1, -meia, y1), pt.p3(s1, meia, y1), pt.p3(s0, meia, y0))
		var na_torre := false
		for st in torres:
			if absf(sm - float(st)) < 9.5:
				na_torre = true
		for lado in [-1.0, 1.0]:
			var fo: Vector3 = _fora(pt, sm, lado)
			_q(c, pt.p3(s0, lado * meia, y0 - 0.45), pt.p3(s1, lado * meia, y1 - 0.45), pt.p3(s1, lado * meia, y1), pt.p3(s0, lado * meia, y0), fo, B_ACO * 0.85)
			if na_torre:
				continue
			# grade: corrimão, travessa do meio e os pés
			_barra(c, pt.p3(s0, lado * meia, y0 + 1.1), pt.p3(s1, lado * meia, y1 + 1.1), 0.08, 0.1, ferro)
			_barra(c, pt.p3(s0, lado * meia, y0 + 0.55), pt.p3(s1, lado * meia, y1 + 0.55), 0.05, 0.05, ferro)
			_barra(c, pt.p3(s0, lado * meia, y0), pt.p3(s0, lado * meia, y0 + 1.1), 0.07, 0.07, ferro)
			o.col_quad(pt.p3(s0, lado * meia, y0), pt.p3(s1, lado * meia, y1), pt.p3(s1, lado * meia, y1 + 1.15), pt.p3(s0, lado * meia, y0 + 1.15))
	# postes de ferro antigos com a lanterna (alternando os lados)
	var s := sp0 + 6.0
	var lado := 1.0
	while s < sp1 - 6.0:
		var perto_torre := false
		for st in torres:
			if absf(s - float(st)) < 13.0:
				perto_torre = true
		if not perto_torre:
			var y := _y_passeio(pt, s, sp0, sp1)
			var pe: Vector3 = pt.p3(s, lado * (meia - 0.35), y)
			var c = o.c(s)
			c.cilindro(pe + Vector3(0, 2.0, 0), 0.09, 4.0, 6, ferro, Basis.IDENTITY, 0.06)
			c.cilindro(pe + Vector3(0, 0.25, 0), 0.18, 0.5, 6, ferro)
			c.caixa(pe + Vector3(0, 4.25, 0), Vector3(0.42, 0.55, 0.42), Color(0.9, 0.85, 0.6, A_ACO))
			c.cilindro(pe + Vector3(0, 4.6, 0), 0.32, 0.18, 6, ferro, Basis.IDENTITY, 0.05)
			o.caixas.append([Transform3D(Basis.IDENTITY, pe + Vector3(0, 2.0, 0)), Vector3(0.25, 4.0, 0.25)])
			var lz := pe + Vector3(0, 4.25, 0)
			if _acesa(lz, 0.55):
				o.luz(lz, LUZ_QUENTE)
		lado = -lado
		s += 24.0

static func _torre_brooklyn(o: Obra, st: float) -> void:
	var pt: Ponte = o.pt
	var t: Transform3D = pt.quadro(st)
	var ht: float = pt.h(st)
	var top := ht + B_ALTURA
	var c = o.c(st)
	var cl = o.cl(st)
	var P := B_PEDRA
	var PE := B_PEDRA_ESC
	var mola := ht + 19.0                    # onde os arcos nascem
	var bico := ht + 35.0                    # o bico dos arcos góticos
	for k in [c, cl]:
		# caixão (embasamento) na água, com o rodapé na linha d'água
		_cx(k, t, Vector3(0, (-4.5 + ht - 1.3) * 0.5, 0), Vector3(64.0, ht - 1.3 + 4.5, 22.0), P)
		_cx(k, t, Vector3(0, 0.2, 0), Vector3(67.0, 2.6, 25.0), PE)
		# os pilares de fora e o do meio (com a passagem do passeio embaixo)
		for lado in [-1.0, 1.0]:
			_cx(k, t, Vector3(lado * 26.9, (ht - 1.3 + top) * 0.5, 0), Vector3(6.8, top - ht + 1.3, 18.0), P)
			_cx(k, t, Vector3(lado * 3.15, ht + 5.6, 0), Vector3(1.7, 11.2, 18.0), P)
			_arco(k, t, 4.0 if lado > 0.0 else -23.5, 23.5 if lado > 0.0 else -4.0, mola, top - 6.0, bico, -9.0, 9.0, P, true)
		_cx(k, t, Vector3(0, (ht + 11.2 + top) * 0.5, 0), Vector3(8.0, top - ht - 11.2, 18.0), P)
		_cx(k, t, Vector3(0, top - 3.0, 0), Vector3(47.0, 6.0, 18.0), P)
		# cornijas: a de cima (larga) e a de baixo dela
		_cx(k, t, Vector3(0, top + 0.5, 0), Vector3(62.6, 1.0, 20.4), PE)
		_cx(k, t, Vector3(0, top - 7.2, 0), Vector3(61.4, 0.8, 19.4), PE)
	# detalhes de perto: faixa na altura em que os arcos nascem (só nos pilares), frisos verticais e as selas dos cabos
	for lado in [-1.0, 1.0]:
		_cx(c, t, Vector3(lado * 26.9, mola - 0.3, 0), Vector3(7.4, 0.7, 18.7), PE)
		for fz in [-1.0, 1.0]:
			for fx in [-1.6, 1.6]:
				_cx(c, t, Vector3(lado * 26.9 + fx, (ht + 1.0 + mola - 1.2) * 0.5, fz * 9.05), Vector3(0.9, mola - ht - 3.2, 0.12), PE)
				_cx(c, t, Vector3(lado * 26.9 + fx, (mola + 1.0 + top - 8.5) * 0.5, fz * 9.05), Vector3(0.9, top - 8.5 - mola - 1.0, 0.12), PE)
			# janelinhas góticas no alto do pilar
			_arco(c, t, lado * 26.9 - 1.3, lado * 26.9 + 1.3, top - 15.0, top - 10.5, top - 12.2, fz * 9.0 - 0.05 * fz, fz * 9.0 + 0.06 * fz, PE * 0.6, true)
		_cx(c, t, Vector3(lado * 3.15, mola - 0.3, 0), Vector3(2.1, 0.7, 18.7), PE)
		_cx(c, t, Vector3(lado * 23.4, top + 1.6, 0), Vector3(2.2, 1.4, 6.0), PE)
		_cx(c, t, Vector3(lado * 3.5, top + 1.6, 0), Vector3(2.2, 1.4, 6.0), PE)
	_cx(c, t, Vector3(0, mola - 0.3, 0), Vector3(8.6, 0.7, 18.7), PE)
	# colisão: pilares, as paredes da passagem do passeio e o embasamento
	for lado in [-1.0, 1.0]:
		o.col_caixa(t, Vector3(lado * 26.9, (ht - 1.3 + top) * 0.5, 0), Vector3(6.8, top - ht + 1.3, 18.0))
		o.col_caixa(t, Vector3(lado * 3.15, ht + 5.6, 0), Vector3(1.7, 11.2, 18.0))
	o.col_caixa(t, Vector3(0, (ht + 11.2 + top) * 0.5, 0), Vector3(8.0, top - ht - 11.2, 18.0))
	o.col_caixa(t, Vector3(0, (-4.5 + ht - 1.3) * 0.5, 0), Vector3(64.0, ht - 1.3 + 4.5, 22.0))
	for lado in [-1.0, 1.0]:
		o.luz(t * Vector3(lado * 29.0, top + 1.6, 0), LUZ_TORRE)

# ======================= PONTE DE MANHATTAN =======================
const M_AZUL := Color(0.27, 0.45, 0.66, A_ACO)
const M_AZUL_ESC := Color(0.19, 0.33, 0.5, A_ACO)
const M_PEDRA := Color(0.68, 0.61, 0.51, A_PEDRA)
const M_CABO := Color(0.28, 0.4, 0.54, A_ACO)
const M_ALTURA := 58.0

static func _manhattan(o: Obra) -> void:
	var pt: Ponte = o.pt
	var d: Dictionary = pt.dados
	var torres: Array = d["torres"]
	var ancoras: Array = d["ancoras"]
	for st in torres:
		_torre_manhattan(o, st)
	for sa in ancoras:
		_ancoragem(o, sa, M_PEDRA, 44.0, 13.0, 9.0)
	# a TRELIÇA funda azul dos dois lados (é ela que segura a pista) e o contraventamento embaixo
	var yb := func(s: float) -> float: return pt.h(s) - 6.5
	var yc := func(s: float) -> float: return pt.h(s) + 1.7
	for lado in [-1.0, 1.0]:
		_trelica_lateral(o, ancoras[0] + 22.0, ancoras[1] - 22.0, lado * (MEIA - 0.1), yb, yc, 7.5, M_AZUL, "warren", torres, 6.0, 1.15)
	var s: float = float(ancoras[0]) + 30.0
	while s < ancoras[1] - 30.0:
		var ok := true
		for st in torres:
			if absf(s - float(st)) < 8.0:
				ok = false
		if ok:
			_barra(o.c(s), pt.p3(s, -MEIA, pt.h(s) - 6.3), pt.p3(s, MEIA, pt.h(s) - 6.3), 0.4, 0.6, M_AZUL_ESC)
			_barra(o.c(s), pt.p3(s, -MEIA, pt.h(s) - 6.3), pt.p3(s + 15.0, MEIA, pt.h(s + 15.0) - 6.3), 0.3, 0.3, M_AZUL_ESC)
		s += 15.0
	# 4 cabos (2 de cada lado), pendurais e o colar de luzes
	var fim_p := func(s2: float) -> float: return pt.h(s2) + 1.7
	for lat in [-24.6, -23.4, 23.4, 24.6]:
		var y_anc: Array = [pt.h(ancoras[0]) + 8.5, pt.h(ancoras[1]) + 8.5]
		var cb := _cabo(pt, torres, ancoras, [pt.h(torres[0]) + M_ALTURA, pt.h(torres[1]) + M_ALTURA], y_anc, fim_p, 3.0)
		_desenhar_cabo(o, cb, lat, 0.32, M_CABO, 6.0, fim_p, absf(lat) > 24.0)
	_postes(o, 36.0)

static func _torre_manhattan(o: Obra, st: float) -> void:
	var pt: Ponte = o.pt
	var t: Transform3D = pt.quadro(st)
	var ht: float = pt.h(st)
	var top := ht + M_ALTURA
	var base := ht - 7.5
	var c = o.c(st)
	var cl = o.cl(st)
	var AZ := M_AZUL
	var AZE := M_AZUL_ESC
	var trechos := [[base, 24.0, 6.2, 10.0], [base + 24.0, 22.0, 5.6, 9.0], [base + 46.0, top - base - 46.0, 5.0, 8.0]]
	for k in [c, cl]:
		_cx(k, t, Vector3(0, (-4.5 + base) * 0.5, 0), Vector3(64.0, base + 4.5, 17.0), M_PEDRA)
		_cx(k, t, Vector3(0, 0.2, 0), Vector3(67.0, 2.6, 20.0), M_PEDRA * 0.85)
		for lado in [-1.0, 1.0]:
			var x: float = lado * 26.6
			for tr in trechos:
				_cx(k, t, Vector3(x, float(tr[0]) + float(tr[1]) * 0.5, 0), Vector3(tr[2], tr[1], tr[3]), AZ)
			_cx(k, t, Vector3(x, top + 0.8, 0), Vector3(5.8, 1.6, 8.8), AZE)
		# o ARCO no alto entre as pernas e a viga de baixo
		_arco(k, t, -24.0, 24.0, ht + 38.0, top, ht + 50.5, -2.6, 2.6, AZ, false)
		_cx(k, t, Vector3(0, base + 1.5, 0), Vector3(48.0, 3.0, 4.0), AZ)
	for lado in [-1.0, 1.0]:
		var x: float = lado * 26.6
		for tr in trechos:
			var y0: float = tr[0]
			var a: float = tr[1]
			var w: float = tr[2]
			var p: float = tr[3]
			# painéis rebaixados nas faces e a faixa (anel) no alto de cada trecho
			for fz in [-1.0, 1.0]:
				for fx in [-1.0, 1.0]:
					_cx(c, t, Vector3(x + fx * w * 0.24, y0 + a * 0.5, fz * (p * 0.5 + 0.05)), Vector3(w * 0.2, a - 2.4, 0.12), AZE)
			for fx in [-1.0, 1.0]:
				_cx(c, t, Vector3(x + fx * (w * 0.5 + 0.05), y0 + a * 0.5, 0), Vector3(0.12, a - 2.4, p * 0.55), AZE)
			_cx(c, t, Vector3(x, y0 + a - 0.6, 0), Vector3(w + 0.7, 1.2, p + 0.7), AZE)
		# coroa: pirâmide e a BOLA no alto
		c.cilindro(t * Vector3(x, top + 2.6, 0), 2.4, 2.0, 8, AZ, t.basis, 0.7)
		for b in [[3.9, 0.9], [4.4, 1.35], [5.0, 1.55], [5.6, 1.35], [6.1, 0.9]]:
			c.cilindro(t * Vector3(x, top + float(b[0]), 0), float(b[1]), 0.6, 10, AZE, t.basis)
		c.cilindro(t * Vector3(x, top + 7.0, 0), 0.12, 1.4, 6, AZE, t.basis)
		# ornamento: o "chapéu" com friso entre a perna e o arco
		_cx(c, t, Vector3(lado * 24.6, ht + 38.0, 0), Vector3(2.0, 2.0, 6.0), AZE)
		o.col_caixa(t, Vector3(x, (base + top) * 0.5, 0), Vector3(6.2, top - base, 10.0))
		o.luz(t * Vector3(x, top + 7.9, 0), LUZ_TORRE)
	o.col_caixa(t, Vector3(0, (-4.5 + base) * 0.5, 0), Vector3(64.0, base + 4.5, 17.0))

# postes de luz na beira das calçadas, alternando os lados
static func _postes(o: Obra, intervalo: float) -> void:
	var pt: Ponte = o.pt
	var ferro := Color(0.16, 0.17, 0.18, A_ACO)
	var s: float = pt.ini + 30.0
	var lado := 1.0
	while s < pt.fim - 30.0:
		var hs: float = pt.h(s)
		var pe: Vector3 = pt.p3(s, lado * (MEIA_RUA + 1.2), hs)
		var braco: Vector3 = pt.p3(s, lado * (MEIA_RUA - 1.8), hs + 8.6)
		var c = o.c(s)
		_barra(c, pe, pe + Vector3(0, 8.9, 0), 0.22, 0.22, ferro)
		_barra(c, pe + Vector3(0, 8.7, 0), braco, 0.12, 0.12, ferro)
		c.caixa(braco + Vector3(0, -0.12, 0), Vector3(0.7, 0.22, 0.7), Color(0.25, 0.25, 0.26, A_ACO))
		o.caixas.append([Transform3D(Basis.IDENTITY, pe + Vector3(0, 4.4, 0)), Vector3(0.3, 8.8, 0.3)])
		var lz := braco + Vector3(0, -0.35, 0)
		if _acesa(lz, 0.6):
			o.luz(lz, LUZ_QUENTE)
		lado = -lado
		s += intervalo

# ======================= PONTE GEORGE WASHINGTON =======================
const G_CINZA := Color(0.56, 0.58, 0.6, A_ACO)
const G_CINZA_ESC := Color(0.4, 0.42, 0.44, A_ACO)
const G_CABO := Color(0.5, 0.51, 0.52, A_ACO)
const G_ALTURA := 76.0
const G_PERNA := 27.0

static func _gwb(o: Obra) -> void:
	var pt: Ponte = o.pt
	var d: Dictionary = pt.dados
	var torres: Array = d["torres"]
	var ancoras: Array = d["ancoras"]
	for st in torres:
		_torre_gwb(o, st)
	for sa in ancoras:
		_ancoragem(o, sa, Color(0.6, 0.58, 0.54, A_CONCRETO), 34.0, 8.0, 6.0)
	# o andar de baixo: treliça dos dois lados e a laje dele
	var yb := func(s: float) -> float: return pt.h(s) - 9.0
	var yc := func(s: float) -> float: return pt.h(s) - 1.0
	for lado in [-1.0, 1.0]:
		_trelica_lateral(o, ancoras[0] + 26.0, ancoras[1] - 26.0, lado * (MEIA - 0.1), yb, yc, 8.0, G_CINZA, "warren", torres, 7.0, 1.1)
	var ss: PackedFloat32Array = pt.amostras(float(ancoras[0]) + 26.0, float(ancoras[1]) - 26.0, 8.0)
	for i in ss.size() - 1:
		var s0: float = ss[i]
		var s1: float = ss[i + 1]
		var c = o.c((s0 + s1) * 0.5)
		_q(c, pt.p3(s0, -MEIA, pt.h(s0) - 8.6), pt.p3(s1, -MEIA, pt.h(s1) - 8.6), pt.p3(s1, MEIA, pt.h(s1) - 8.6), pt.p3(s0, MEIA, pt.h(s0) - 8.6), Vector3.DOWN, CONCRETO_ESC)
		_q(c, pt.p3(s0, -MEIA, pt.h(s0) - 8.3), pt.p3(s1, -MEIA, pt.h(s1) - 8.3), pt.p3(s1, MEIA, pt.h(s1) - 8.3), pt.p3(s0, MEIA, pt.h(s0) - 8.3), Vector3.UP, Color(0.2, 0.2, 0.21, A_CONCRETO))
		# grade de cima: os pés a cada 8 m e os dois corrimãos
		for lado in [-1.0, 1.0]:
			_barra(c, pt.p3(s0, lado * (MEIA - 0.2), pt.h(s0) + 1.15), pt.p3(s1, lado * (MEIA - 0.2), pt.h(s1) + 1.15), 0.1, 0.14, G_CINZA)
			_barra(c, pt.p3(s0, lado * (MEIA - 0.2), pt.h(s0) + 0.6), pt.p3(s1, lado * (MEIA - 0.2), pt.h(s1) + 0.6), 0.08, 0.1, G_CINZA)
			_barra(c, pt.p3(s0, lado * (MEIA - 0.2), pt.h(s0)), pt.p3(s0, lado * (MEIA - 0.2), pt.h(s0) + 1.15), 0.12, 0.12, G_CINZA)
	# 4 cabos grossos, 2 de cada lado
	var fim_p := func(s2: float) -> float: return pt.h(s2) + 0.6
	for lat in [-25.6, -24.0, 24.0, 25.6]:
		var y_anc: Array = [pt.h(ancoras[0]) + 8.5, pt.h(ancoras[1]) + 8.5]
		var cb := _cabo(pt, torres, ancoras, [pt.h(torres[0]) + G_ALTURA - 1.0, pt.h(torres[1]) + G_ALTURA - 1.0], y_anc, fim_p, 3.0)
		_desenhar_cabo(o, cb, lat, 0.5, G_CABO, 6.0, fim_p, absf(lat) > 25.0, false)
	if d.has("farol"):
		_farol(o, float(d["farol"][0]), float(d["farol"][1]))

static func _torre_gwb(o: Obra, st: float) -> void:
	var pt: Ponte = o.pt
	var t: Transform3D = pt.quadro(st)
	var ht: float = pt.h(st)
	var top := ht + G_ALTURA
	var base := ht - 10.5
	var c = o.c(st)
	var cl = o.cl(st)
	var CZ := G_CINZA
	var cantos := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for k in [c, cl]:
		_cx(k, t, Vector3(0, (-4.5 + base) * 0.5, 0), Vector3(70.0, base + 4.5, 22.0), CONCRETO)
		_cx(k, t, Vector3(0, base + 1.5, 0), Vector3(48.0, 3.0, 8.0), CZ)
	for lado in [-1.0, 1.0]:
		var xc: float = lado * G_PERNA
		var canto := func(q: Vector2, y: float) -> Vector3:
			var u := (y - base) / (top - base)
			return Vector3(xc + q.x * lerpf(4.6, 3.6, u), y, q.y * lerpf(6.2, 5.0, u))
		# longe: a perna cheia
		_cx(cl, t, Vector3(xc, (base + top) * 0.5, 0), Vector3(8.4, top - base, 11.2), G_CINZA_ESC)
		# perto: TRELIÇA de aço (4 colunas de canto, travessas e X em cada face, a cada ~7 m)
		for q in cantos:
			_barra(c, t * canto.call(q, base), t * canto.call(q, top), 1.25, 1.25, CZ)
		var npain := 12
		for i in npain:
			var y0: float = base + (top - base) * i / npain
			var y1: float = base + (top - base) * (i + 1) / npain
			for f in 4:
				var qa: Vector2 = cantos[f]
				var qb: Vector2 = cantos[(f + 1) % 4]
				var a0: Vector3 = t * canto.call(qa, y0)
				var b0: Vector3 = t * canto.call(qb, y0)
				var a1: Vector3 = t * canto.call(qa, y1)
				var b1: Vector3 = t * canto.call(qb, y1)
				_barra(c, a1, b1, 0.55, 0.8, CZ)
				_barra(c, a0, b1, 0.32, 0.32, CZ)
				_barra(c, b0, a1, 0.32, 0.32, CZ)
		_cx(c, t, Vector3(xc, top + 0.9, 0), Vector3(8.0, 1.8, 10.6), G_CINZA_ESC)
		o.col_caixa(t, Vector3(xc, (base + top) * 0.5, 0), Vector3(9.0, top - base, 12.0))
		o.luz(t * Vector3(xc, top + 2.2, 0), LUZ_TORRE)
	# PORTAL: a viga treliçada no alto e o ARCO grande embaixo dela (o desenho que todo mundo conhece)
	var vb := top - 10.0
	var nseg := 18
	for fz in [-4.4, 4.4]:
		for k in [c, cl]:
			_barra(k, t * Vector3(-23.0, top - 0.8, fz), t * Vector3(23.0, top - 0.8, fz), 1.0, 1.4, CZ)
			_barra(k, t * Vector3(-23.0, vb, fz), t * Vector3(23.0, vb, fz), 1.0, 1.1, CZ)
		for i in 9:
			var x0 := -23.0 + 46.0 * i / 9.0
			var x1 := -23.0 + 46.0 * (i + 1) / 9.0
			_barra(c, t * Vector3(x1, vb, fz), t * Vector3(x1, top - 0.8, fz), 0.5, 0.5, CZ)
			_barra(c, t * Vector3(x0, vb if i % 2 == 0 else top - 0.8, fz), t * Vector3(x1, top - 0.8 if i % 2 == 0 else vb, fz), 0.4, 0.4, CZ)
		# arco: nervura de fora e de dentro, montantes radiais e os montantes até a viga
		var y_mola := ht + 26.0
		var ant_f := Vector3.ZERO
		var ant_d := Vector3.ZERO
		for i in nseg + 1:
			var a := PI * float(i) / nseg
			var xf := -cos(a) * 23.0
			var yf := y_mola + sin(a) * (vb - 1.0 - y_mola)
			var xd := -cos(a) * 20.6
			var yd := y_mola + sin(a) * (vb - 3.8 - y_mola)
			var pf: Vector3 = t * Vector3(xf, yf, fz)
			var pd: Vector3 = t * Vector3(xd, yd, fz)
			if i > 0:
				_barra(c, ant_f, pf, 1.0, 1.0, CZ)
				_barra(c, ant_d, pd, 0.7, 0.7, CZ)
				_barra(cl, ant_f, pf, 1.6, 1.6, CZ)
				_barra(c, ant_f, pd, 0.32, 0.32, CZ)
			_barra(c, pf, pd, 0.4, 0.4, CZ)
			if i > 0 and i < nseg and i % 2 == 0:
				_barra(c, pf, t * Vector3(xf, vb, fz), 0.45, 0.45, CZ)
			ant_f = pf
			ant_d = pd
	# travessas entre as duas faces do portal
	for i in 7:
		var x := -21.0 + 42.0 * i / 6.0
		_barra(c, t * Vector3(x, top - 0.8, -4.4), t * Vector3(x, top - 0.8, 4.4), 0.5, 0.6, CZ)
	o.col_caixa(t, Vector3(0, (-4.5 + base) * 0.5, 0), Vector3(70.0, base + 4.5, 22.0))

# o FAROLZINHO VERMELHO (Little Red Lighthouse) no pé da torre do lado de Manhattan
static func _farol(o: Obra, s: float, lat: float) -> void:
	var pt: Ponte = o.pt
	var p: Vector3 = pt.p3(s, lat, 0.0)
	var c = o.c(s)
	var verm := Color(0.74, 0.12, 0.08, A_ACO)
	var preto := Color(0.1, 0.1, 0.1, A_ACO)
	var branco := Color(0.9, 0.9, 0.86, A_ACO)
	c.cilindro(p + Vector3(0, -1.5, 0), 5.2, 4.0, 12, Color(0.42, 0.4, 0.37, A_PEDRA), Basis.IDENTITY, 4.4)
	c.cilindro(p + Vector3(0, 0.7, 0), 3.1, 0.6, 14, Color(0.6, 0.58, 0.55, A_CONCRETO))
	c.cilindro(p + Vector3(0, 6.9, 0), 2.6, 12.0, 16, verm, Basis.IDENTITY, 1.9)
	c.cilindro(p + Vector3(0, 13.05, 0), 2.5, 0.3, 16, preto)
	for i in 12:
		var a := TAU * i / 12.0
		c.caixa(p + Vector3(cos(a) * 2.35, 13.7, sin(a) * 2.35), Vector3(0.06, 1.0, 0.06), preto)
	c.cilindro(p + Vector3(0, 14.2, 0), 2.4, 0.06, 16, preto)
	c.cilindro(p + Vector3(0, 13.9, 0), 1.25, 1.6, 10, Color(0.16, 0.18, 0.2, A_ACO))
	c.cilindro(p + Vector3(0, 15.0, 0), 1.45, 0.7, 10, verm * 0.75, Basis.IDENTITY, 0.25)
	c.cilindro(p + Vector3(0, 15.6, 0), 0.08, 0.8, 6, preto)
	# porta e janelinhas (viradas para a rua)
	var fo := Vector3((p - pt.p3(s, 0.0, 0.0)).x, 0, (p - pt.p3(s, 0.0, 0.0)).z).normalized()
	var b := Basis.looking_at(fo, Vector3.UP)
	c.caixa(p + fo * 2.55 + Vector3(0, 2.1, 0), Vector3(1.2, 2.2, 0.15), branco, b)
	for y in [5.5, 8.6, 11.2]:
		c.caixa(p - fo * 2.2 + Vector3(0, y, 0), Vector3(0.6, 0.9, 0.15), preto, b)
	var cl = o.cl(s)
	cl.cilindro(p + Vector3(0, 6.9, 0), 2.6, 12.0, 8, verm, Basis.IDENTITY, 1.9)
	o.caixas.append([Transform3D(Basis.IDENTITY, p + Vector3(0, 6.5, 0)), Vector3(4.6, 13.0, 4.6)])
	o.luz(p + Vector3(0, 13.9, 0), Color(1.0, 0.95, 0.8, 0.6))

# ======================= PONTE DE QUEENSBORO (treliça em balanço) =======================
const Q_ACO := Color(0.58, 0.56, 0.5, A_ACO)
const Q_PEDRA := Color(0.62, 0.56, 0.47, A_PEDRA)

static func _queensboro(o: Obra) -> void:
	var pt: Ponte = o.pt
	var d: Dictionary = pt.dados
	var pilares: Array = d["pilares"]
	var picos: Array = d["picos"]
	for sp in pilares:
		_pilar(o, float(sp), Q_PEDRA, 54.0, 12.0, float(sp) in picos)
	var pico := func(s: float) -> float:
		var m := 0.0
		for p in picos:
			m = maxf(m, pow(maxf(0.0, 1.0 - absf(s - float(p)) / 95.0), 1.4))
		return m
	var yb := func(s: float) -> float: return pt.h(s) - 1.2
	var yc := func(s: float) -> float: return pt.h(s) + 9.0 + 25.0 * float(pico.call(s))
	var s0: float = float(pilares[0])
	var s1: float = float(pilares[pilares.size() - 1])
	for lado in [-1.0, 1.0]:
		_trelica_lateral(o, s0, s1, lado * 23.6, yb, yc, 9.0, Q_ACO, "x", [], 0.0, 1.2)
	# os PINÁCULOS em cima dos montantes dos picos e o contraventamento por cima da pista
	for p in picos:
		var sp := float(p)
		for lado in [-1.0, 1.0]:
			var topo: Vector3 = pt.p3(sp, lado * 23.6, float(yc.call(sp)))
			var c = o.c(sp)
			_barra(c, topo, topo + Vector3(0, 6.0, 0), 0.9, 0.9, Q_ACO)
			c.cilindro(topo + Vector3(0, 7.2, 0), 0.7, 2.4, 6, Q_ACO, Basis.IDENTITY, 0.05)
			o.luz(topo + Vector3(0, 8.6, 0), LUZ_TORRE)
	var s := s0 + 9.0
	while s < s1 - 9.0:
		var yt: float = yc.call(s)
		if yt - pt.h(s) > 12.0:
			var c = o.c(s)
			_barra(c, pt.p3(s, -23.6, yt - 0.4), pt.p3(s, 23.6, yt - 0.4), 0.45, 0.7, Q_ACO)
			_barra(c, pt.p3(s, -23.6, yt - 0.4), pt.p3(s + 9.0, 23.6, float(yc.call(s + 9.0)) - 0.4), 0.3, 0.3, Q_ACO)
		s += 18.0
	# luzes ao longo da corda de cima
	s = s0 + 4.0
	while s < s1 - 4.0:
		for lado in [-1.0, 1.0]:
			var p: Vector3 = pt.p3(s, lado * 23.6, float(yc.call(s)) + 0.6)
			if _acesa(p, 0.6):
				o.luz(p, LUZ_QUENTE)
		s += 18.0

# pilar de pedra (ou concreto) debaixo do tabuleiro; com_torres: as torrezinhas de pedra com pirâmide dos dois lados
static func _pilar(o: Obra, sp: float, cor: Color, larg: float, prof: float, com_torres: bool) -> void:
	var pt: Ponte = o.pt
	var t: Transform3D = pt.quadro(sp)
	var hp: float = pt.h(sp)
	var esc := Color(cor.r * 0.82, cor.g * 0.82, cor.b * 0.82, cor.a)
	for k in [o.c(sp), o.cl(sp)]:
		_cx(k, t, Vector3(0, (-4.5 + hp - 1.4) * 0.5, 0), Vector3(larg, hp - 1.4 + 4.5, prof), cor)
		if com_torres:
			for lado in [-1.0, 1.0]:
				_cx(k, t, Vector3(lado * (larg * 0.5 - 2.5), (hp - 1.4 + hp + 7.0) * 0.5, 0), Vector3(5.0, 8.4, prof), cor)
	_cx(o.c(sp), t, Vector3(0, 0.2, 0), Vector3(larg + 3.0, 2.6, prof + 3.0), esc)
	_cx(o.c(sp), t, Vector3(0, hp - 2.2, 0), Vector3(larg + 1.0, 0.8, prof + 1.0), esc)
	if com_torres:
		for lado in [-1.0, 1.0]:
			var x: float = lado * (larg * 0.5 - 2.5)
			_cx(o.c(sp), t, Vector3(x, hp + 7.2, 0), Vector3(5.6, 0.6, prof + 0.6), esc)
			o.c(sp).cilindro(t * Vector3(x, hp + 9.0, 0), 2.9, 3.0, 4, esc, t.basis * Basis(Vector3.UP, PI * 0.25), 0.1)
			o.col_caixa(t, Vector3(x, (hp - 1.4 + hp + 7.0) * 0.5, 0), Vector3(5.0, 8.4, prof))
	o.col_caixa(t, Vector3(0, (-4.5 + hp - 1.4) * 0.5, 0), Vector3(larg, hp - 1.4 + 4.5, prof))

# ======================= TRELIÇAS MENORES (Macombs, Willis) =======================
static func _trelica(o: Obra) -> void:
	var pt: Ponte = o.pt
	var d: Dictionary = pt.dados
	var pilares: Array = d["pilares"]
	var cf: Array = d.get("cor", [0.3, 0.35, 0.32])
	var cor := Color(cf[0], cf[1], cf[2], A_ACO)
	for sp in pilares:
		_pilar(o, float(sp), CONCRETO, 50.0, 6.0, false)
	for i in pilares.size() - 1:
		var a: float = pilares[i]
		var b: float = pilares[i + 1]
		if o.em_terra((a + b) * 0.5) or b - a < 20.0:
			continue
		# treliça de arco (camelo): sobe no meio do vão, as pontas inclinadas
		var vao := b - a
		var yb := func(s: float) -> float: return pt.h(s) - 0.9
		var yc := func(s: float) -> float:
			var u := clampf((s - a) / vao, 0.0, 1.0)
			var ponta := clampf(minf(u, 1.0 - u) * vao / 9.0, 0.0, 1.0)
			return pt.h(s) - 0.9 + (7.0 + 4.0 * sin(PI * u)) * ponta
		var painel := vao / maxf(2.0, round(vao / 8.5))
		for lado in [-1.0, 1.0]:
			_trelica_lateral(o, a, b, lado * 23.6, yb, yc, painel, cor, "pratt", [], 0.0, 1.0)
		var s := a + painel
		while s < b - painel * 0.9:
			_barra(o.c(s), pt.p3(s, -23.6, float(yc.call(s)) - 0.3), pt.p3(s, 23.6, float(yc.call(s)) - 0.3), 0.35, 0.5, cor)
			s += painel
