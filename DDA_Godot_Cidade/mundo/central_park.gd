extends Node3D
# CENTRAL PARK (1.20): o maior parque de Nova York, refeito com as fotos do parque de verdade. O desenho (onde fica
# cada lago, gramado, praça, pista, caminho, construção, poste, banco e árvore) está em data/central_park.json, gravado
# por ferramentas/central_park/desenho.py (lá estão as explicações e as medidas). Aqui o jogo monta tudo:
#   - LAGOS: The Lake, The Pond, Turtle Pond e Conservatory Water entram no lugar do lago antigo do mapa (que ficava
#     escondido embaixo da grama): aplicar_dados() muda data/city.json na memória ANTES de a cidade e a física lerem
#     (mundo/cidade.gd _comecar); o chão do parque é recortado em volta deles (recortar_lagos) e dá para nadar.
#   - CHÃO: gramados (grama baixa), praças (pedra; a da Bethesda de tijolo vermelho), pistas (asfalto) e caminhos.
#   - MURO baixo de pedra no contorno, com pilares nas entradas; POSTES (o modelo do Central Park, com o vidro que acende
#     à noite) e BANCOS de ripas verdes ao longo dos caminhos e da Mall; ROCHAS de xisto cinza aflorando.
#   - CONSTRUÇÕES (mundo/central_park_obras.gd): Bethesda Terrace e a Fonte do Anjo, Bow Bridge, Gapstow Bridge,
#     Belvedere Castle na Vista Rock, Loeb Boathouse, Naumburg Bandshell, Cleopatra's Needle, Wollman Rink, o Carrossel,
#     o mosaico IMAGINE, o Delacorte Theater, as estátuas da Mall, a Alice, a fonte do Cherry Hill e os campos de beisebol.
#   - ÁRVORES: ~12 mil (mundo/arvores.gd), MATA DENSA: 4 fileiras de olmos na Mall, o Ramble bem fechado.
#   - FÍSICA: um StaticBody3D com as caixas de colisão de tudo (sempre na cena); postes, bancos e troncos viram
#     obstáculos (mundo/colisao_mundo.gd, perto do jogador).
# O desenho é igual em todo aparelho (o mesmo arquivo): nada vai pela rede.
# Mexa AQUI para: materiais, postes, bancos, muro e chão. Construções: mundo/central_park_obras.gd. Lugares e
# quantidades: ferramentas/central_park/desenho.py (e rodar de novo).

const Malhas := preload("res://mundo/malhas.gd")
const Mat := preload("res://mundo/materiais_cidade.gd")
const ARQ := "res://data/central_park.json"
const Y := 0.4                          # chão do parque (= Y_PARQUE da cidade)
const BLOCO := 250.0                    # postes, bancos, chão: um pedaço por bloco (chunks e culling)
const ALCANCE_POSTE := 220.0
const ALCANCE_BANCO := 110.0
const ALCANCE_DETALHE := 260.0          # pedras e enfeites pequenos
const PEDRA := Color(0.74, 0.66, 0.52)  # arenito da Bethesda (bege)
const XISTO := Color(0.42, 0.41, 0.4)   # pedra cinza do Central Park (muros, pontes de pedra, rochas)
const FERRO := Color(0.07, 0.09, 0.075)
const VERDE_BANCO := Color(0.13, 0.24, 0.16)

static var _dados := {}
static var _masc := PackedByteArray()
static var _m := {}                     # x0, z0, cel, w, h
static var _parques: Array = []         # PackedVector2Array (as duas metades)
static var _caixa := Rect2()

static func dados() -> Dictionary:
	if _dados.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(ARQ))
		if d is Dictionary:
			_dados = d
			for p in d["parques"]:
				var pp := PackedVector2Array()
				for q in p:
					pp.append(Vector2(q[0], q[1]))
				_parques.append(pp)
				var r := Rect2(pp[0], Vector2.ZERO)
				for q in pp:
					r = r.expand(q)
				_caixa = r if _caixa.size == Vector2.ZERO else _caixa.merge(r)
			var m: Dictionary = d["mascara"]
			_m = m
			_masc = String(m["dados"]).to_ascii_buffer()
			for i in _masc.size():
				_masc[i] -= 48                                  # '0'..'5' -> 0..5
	return _dados

# dentro do Central Park (as duas metades; a rua do meio não conta)
static func dentro(p: Vector2) -> bool:
	dados()
	if not _caixa.has_point(p):
		return false
	for pp in _parques:
		if Geometry2D.is_point_in_polygon(p, pp):
			return true
	return false

# o que tem no chão em (x, z): 0 mata · 1 gramado · 2 praça/caminho/pista · 3 água · 4 construção · 5 fora do parque
static func chao(x: float, z: float) -> int:
	dados()
	if _masc.is_empty():
		return 5
	var c := int((x - float(_m["x0"])) / float(_m["cel"]))
	var r := int((z - float(_m["z0"])) / float(_m["cel"]))
	if c < 0 or r < 0 or c >= int(_m["w"]) or r >= int(_m["h"]):
		return 5
	return _masc[r * int(_m["w"]) + c]

# plantas soltas, capim e mato não nascem em caminho, água nem construção (e arbusto não nasce no gramado)
static func bloqueia_planta(x: float, z: float, arbusto := false) -> bool:
	var k := chao(x, z)
	return k == 2 or k == 3 or k == 4 or (arbusto and k == 1)

static func _poli(lista: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for q in lista:
		p.append(Vector2(float(q[0]), float(q[1])))
	return p

# troca o lago antigo do mapa pelos lagos novos (antes de a cidade, a física e o mapa lerem os dados)
static func aplicar_dados(data: Dictionary) -> void:
	var d := dados()
	if d.is_empty():
		return
	var lands: Array = data["lands"]
	var antigo := int(d["lago_antigo"])
	if antigo >= 0 and antigo < lands.size() and int(lands[antigo][0]) == 1:
		lands.remove_at(antigo)
	for nome in d["lagos"]:
		var f: Array = []
		for q in d["lagos"][nome]:
			f.append(float(q[0]))
			f.append(float(q[1]))
		f.append(float(d["lagos"][nome][0][0]))
		f.append(float(d["lagos"][nome][0][1]))
		lands.append([1, f])

# recorta os lagos de dentro de um polígono de parque (sem buraco: corta o parque em duas metades por uma linha que
# passa no meio de cada lago; cada metade fica com uma "mordida" na borda, que a triangulação aceita)
static func recortar_lagos(poli: PackedVector2Array, lagos: Array) -> Array:
	var pecas: Array = [poli]
	for lg in lagos:
		var lp: PackedVector2Array = lg
		var rb := Rect2(lp[0], Vector2.ZERO)
		for q in lp:
			rb = rb.expand(q)
		var novas: Array = []
		for pc in pecas:
			var p: PackedVector2Array = pc
			var rp := Rect2(p[0], Vector2.ZERO)
			for q in p:
				rp = rp.expand(q)
			if not rp.intersects(rb):
				novas.append(p)
				continue
			var cx := rb.get_center().x
			var g := 1.0e5
			for metade in [PackedVector2Array([Vector2(-g, -g), Vector2(cx, -g), Vector2(cx, g), Vector2(-g, g)]),
					PackedVector2Array([Vector2(cx, -g), Vector2(g, -g), Vector2(g, g), Vector2(cx, g)])]:
				for q in Geometry2D.intersect_polygons(p, metade):
					for r in Geometry2D.clip_polygons(q, lp):
						if not Geometry2D.is_polygon_clockwise(r) or Geometry2D.triangulate_polygon(r).size() > 0:
							novas.append(r)
		pecas = novas
	return pecas

static func lagos_poligonos() -> Array:
	var r: Array = []
	for nome in dados()["lagos"]:
		r.append(_poli(dados()["lagos"][nome]))
	return r

# ---------------------------------------------------------------------------------------------------------------
# MATERIAIS
# ---------------------------------------------------------------------------------------------------------------
const SHADER_OBRA := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float escala = 3.0;
uniform float forca = 0.7;
uniform float musgo = 0.5;
uniform float brilho = 0.0;
uniform float rugosidade = 0.85;
uniform float metal = 0.0;
global uniform float noite;
global uniform float molhado;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { p = mod(p, 4096.0); vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float ruido(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y); }
void fragment() {
	vec3 m = max(textureLod(tex, vec2(0.5), 10.0).rgb, vec3(0.04));
	vec3 det = mix(vec3(1.0), texture(tex, UV / escala).rgb / m, forca);
	vec3 c = COLOR.rgb * det;
	float y = wp.y - 0.4;
	c *= mix(1.0, 0.62 + 0.38 * smoothstep(0.0, 1.4, y), musgo);
	c = mix(c, vec3(0.13, 0.17, 0.08), musgo * 0.45 * (1.0 - smoothstep(0.0, 1.0, y)) * smoothstep(0.35, 0.75, ruido(wp.xz * 1.7 + wp.y)));
	c *= 0.86 + 0.24 * ruido(wp.xz * 0.6 + wp.y * 0.4) * musgo;
	c *= mix(1.0, 0.72, molhado);
	ALBEDO = c;
	ROUGHNESS = mix(rugosidade, 0.35, molhado);
	METALLIC = metal;
	SPECULAR = 0.3;
	EMISSION = COLOR.rgb * brilho * (0.15 + 2.6 * noite);
}
"""

# ferro rendado: CÍRCULOS ENTRELAÇADOS (guarda-corpo da Bow Bridge) ou TELA de alambrado (campos de beisebol);
# o que não é ferro some (discard). UV em metros.
const SHADER_RENDA := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 cor : source_color = vec3(0.86, 0.84, 0.76);
uniform float tipo = 0.0;
global uniform float molhado;
void fragment() {
	vec2 u = UV;
	float d;
	if (tipo < 0.5) {
		float r = 0.19;
		float y = u.y - 0.55;
		float d1 = abs(length(vec2(mod(u.x, 0.30) - 0.15, y)) - r);
		float d2 = abs(length(vec2(mod(u.x + 0.15, 0.30) - 0.15, y)) - r);
		d = min(d1, d2);
		d = min(d, abs(u.y - 0.12));
		d = min(d, abs(u.y - 0.98));
		if (d > 0.022) discard;
	} else {
		vec2 g = vec2(u.x + u.y, u.x - u.y) / 0.07;
		vec2 f = abs(fract(g) - 0.5);
		d = min(f.x, f.y);
		if (d > 0.09) discard;
	}
	ALBEDO = cor * mix(1.0, 0.75, molhado);
	ROUGHNESS = 0.5;
	METALLIC = 0.4;
}
"""

const SHADER_AGUA_FONTE := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 cor : source_color = vec3(0.16, 0.22, 0.14);
void fragment() {
	vec2 p = UV;
	float o = sin(p.x * 3.1 + TIME * 0.7) * sin(p.y * 2.7 - TIME * 0.5);
	ALBEDO = cor * (0.85 + 0.15 * o);
	ROUGHNESS = 0.32;
	METALLIC = 0.0;
	SPECULAR = 0.4;
	NORMAL_MAP = vec3(0.5 + 0.04 * o, 0.5 + 0.04 * cos(p.x * 2.0 + TIME), 1.0);
}
"""

# teto da arcada da Bethesda: azulejos Minton (desenho repetido de 4 cores em quadrados de 0,6 m), cobertos de pó
const SHADER_AZULEJO := """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	vec2 u = UV / 0.6;
	vec2 g = fract(u) - 0.5;
	vec2 q = abs(g);
	float rombo = step(q.x + q.y, 0.36);
	float cruz = step(min(q.x, q.y), 0.06) * step(max(q.x, q.y), 0.42);
	float anel = step(abs(length(g) - 0.3), 0.04);
	vec3 c = vec3(0.78, 0.66, 0.42);
	c = mix(c, vec3(0.62, 0.24, 0.16), rombo);
	c = mix(c, vec3(0.16, 0.3, 0.45), cruz);
	c = mix(c, vec3(0.86, 0.78, 0.55), anel);
	float borda = step(0.47, max(q.x, q.y));
	c = mix(c, vec3(0.3, 0.22, 0.15), borda);
	ALBEDO = c * 0.8;
	ROUGHNESS = 0.6;
	SPECULAR = 0.35;
}
"""

# tijolo vermelho em espinha de peixe (praça da Bethesda), com as faixas claras em volta da fonte
const SHADER_TIJOLO := """
shader_type spatial;
uniform vec2 centro = vec2(-1600.0, -1360.0);
uniform float camada = 3.3;
global uniform float molhado;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z += camada * 1.2e-6 * POSITION.w;
}
float hash(vec2 p) { p = mod(p, 4096.0); vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
void fragment() {
	vec2 q = (wp.xz - centro);
	vec2 r = vec2(q.x + q.y, q.x - q.y) * 0.7071 / 0.1;
	float linha = floor(r.y);
	float bloco = floor((r.x + mod(linha, 2.0) * 1.0) / 2.0);
	vec2 f = vec2(fract((r.x + mod(linha, 2.0) * 1.0) / 2.0), fract(r.y));
	float junta = step(0.94, max(f.x * 1.0, f.y)) + step(f.x, 0.03);
	vec3 tij = vec3(0.56, 0.28, 0.22) * (0.8 + 0.3 * hash(vec2(bloco, linha)));
	float dist = length(q);
	float faixa = (1.0 - smoothstep(0.4, 0.6, abs(dist - 17.5))) + (1.0 - smoothstep(0.4, 0.6, abs(dist - 22.0)));
	faixa += (1.0 - smoothstep(0.35, 0.55, abs(mod(q.x + 13.0, 26.0) - 13.0))) * step(22.0, dist) * 0.8;
	vec3 c = mix(tij, vec3(0.76, 0.69, 0.56), clamp(faixa, 0.0, 1.0));
	c = mix(c, vec3(0.42, 0.40, 0.37), clamp(junta, 0.0, 1.0) * 0.8);
	c *= 0.85 + 0.25 * hash(floor(wp.xz * 0.5));
	c *= mix(1.0, 0.7, molhado);
	ALBEDO = c;
	ROUGHNESS = mix(0.9, 0.3, molhado);
	SPECULAR = 0.25;
}
"""

static var _mats := {}

static func mat(nome: String) -> Material:
	if _mats.has(nome):
		return _mats[nome]
	var m: ShaderMaterial
	match nome:
		"pedra", "xisto", "concreto", "tijolo_parede", "madeira", "ferro", "bronze", "telhado", "vidro", "granito", "ferro_creme", "vidro_escuro":
			m = ShaderMaterial.new()
			m.shader = Mat.shader(SHADER_OBRA)
			var tex: String = {"pedra": "predio_pedra", "xisto": "predio_pedra", "concreto": "predio_concreto",
				"tijolo_parede": "predio_tijolo", "madeira": "interior_madeira", "ferro": "predio_concreto",
				"bronze": "predio_concreto", "telhado": "predio_telhado", "vidro": "predio_concreto", "granito": "predio_pedra",
				"ferro_creme": "predio_concreto", "vidro_escuro": "predio_concreto"}[nome]
			m.set_shader_parameter("tex", load("res://mundo/texturas/%s.jpg" % tex))
			m.set_shader_parameter("escala", {"pedra": 2.6, "xisto": 1.6, "tijolo_parede": 1.4, "madeira": 2.2, "telhado": 3.0, "granito": 1.2}.get(nome, 4.0))
			m.set_shader_parameter("forca", {"ferro": 0.15, "bronze": 0.35, "vidro": 0.05, "xisto": 0.95, "granito": 0.5, "ferro_creme": 0.2, "vidro_escuro": 0.05}.get(nome, 0.75))
			m.set_shader_parameter("musgo", {"ferro": 0.15, "bronze": 0.2, "vidro": 0.0, "telhado": 0.1, "ferro_creme": 0.25, "vidro_escuro": 0.0}.get(nome, 0.55))
			m.set_shader_parameter("rugosidade", {"ferro": 0.55, "bronze": 0.45, "vidro": 0.15, "ferro_creme": 0.5, "vidro_escuro": 0.12}.get(nome, 0.88))
			m.set_shader_parameter("metal", {"ferro": 0.35, "bronze": 0.6, "ferro_creme": 0.2, "vidro_escuro": 0.3}.get(nome, 0.0))
			if nome == "vidro":
				m.set_shader_parameter("brilho", 1.0)
		"renda", "tela":
			m = ShaderMaterial.new()
			m.shader = Mat.shader(SHADER_RENDA)
			m.set_shader_parameter("tipo", 0.0 if nome == "renda" else 1.0)
			m.set_shader_parameter("cor", Color(0.86, 0.84, 0.76) if nome == "renda" else Color(0.45, 0.47, 0.46))
		"agua_fonte":
			m = ShaderMaterial.new()
			m.shader = Mat.shader(SHADER_AGUA_FONTE)
		"azulejo":
			m = ShaderMaterial.new()
			m.shader = Mat.shader(SHADER_AZULEJO)
		"piso_tijolo":
			m = ShaderMaterial.new()
			m.shader = Mat.shader(SHADER_TIJOLO)
		"gramado":
			m = Mat.material(Mat.PARQUE, {"camada": 3.2, "cor_grama": Color(0.29, 0.45, 0.19)})
		"pedra_chao":
			m = Mat.material(Mat.CALCADA, {"camada": 3.3, "cor": Color(0.5, 0.48, 0.45)})
		"mall":
			m = Mat.material(Mat.CALCADA, {"camada": 3.3, "cor": Color(0.36, 0.35, 0.34)})
		"asfalto":
			m = Mat.material(Mat.ASFALTO, {"camada": 3.4, "cor": Color(0.2, 0.2, 0.21)})
		"caminho":
			m = Mat.material(Mat.ASFALTO, {"camada": 3.35, "cor": Color(0.27, 0.27, 0.27)})
		"terra":
			m = Mat.material(Mat.TERRA, {"camada": 3.3})
	_mats[nome] = m
	return m

# ---------------------------------------------------------------------------------------------------------------
# MONTAGEM (mundo/cidade.gd: etapa "Central Park")
# ---------------------------------------------------------------------------------------------------------------
var visuais: Array = []                    # nós de desenho (a cidade adota: os chunks cuidam)
var obstaculos := PackedFloat32Array()     # postes e bancos (formato do mundo/colisao_mundo.gd)
var corpo: StaticBody3D                    # toda a colisão das construções, muros e rochas
var construcoes := {}                      # tipo -> quantas (testes)
var escadas: Array = []                    # [início, direção, largura, y0, dy, comprimento] (testes de subir)
var pontos_altos := {}                     # nome -> Vector3 (testes: topo da Bethesda, castelo, ponte...)

func montar(cidade: Node) -> void:
	var d := dados()
	if d.is_empty():
		return
	corpo = StaticBody3D.new()
	corpo.name = "CentralParkColisao"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	_chao(d)
	await cidade.pausa()
	_muro(d)
	_rochas(d)
	await cidade.pausa()
	_postes_e_bancos(d)
	await cidade.pausa()
	var Obras = load("res://mundo/central_park_obras.gd")
	var obras = Obras.new(self)
	for e in d["estruturas"]:
		obras.montar(String(e[0]), Vector3(float(e[1]), Y, float(e[2])), float(e[3]), e[4])
		construcoes[String(e[0])] = int(construcoes.get(String(e[0]), 0)) + 1
		await cidade.pausa()
	print("Central Park: %d construções · %d obstáculos · %d formas de colisão" % [construcoes.size(), obstaculos.size() / 7, corpo.get_child_count()])

# uma caixa de colisão (centro e tamanho no mundo, girada "b")
func col(c: Vector3, tam: Vector3, b := Basis.IDENTITY) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	cs.transform = Transform3D(b, c)
	corpo.add_child(cs)

# desenho: uma malha num nó (adotado pela cidade); "alcance" = até onde aparece (0 = sempre)
func por_malha(nome: String, malha: Mesh, t: Transform3D, alcance := 0.0, sombra := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = malha
	mi.transform = t
	if alcance > 0.0:
		mi.visibility_range_end = alcance
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visuais.append(mi)
	return mi

# ---------- CHÃO: gramados, praças, pistas e caminhos (um pedaço por bloco) ----------
func _chao(d: Dictionary) -> void:
	var blocos := {}                       # [material, bloco] -> PackedVector3Array
	var por := func(matn: String, a: Vector3, b: Vector3, c: Vector3) -> void:
		var k := [matn, Vector2i(floori((a.x + b.x + c.x) / 3.0 / BLOCO), floori((a.z + b.z + c.z) / 3.0 / BLOCO))]
		if not blocos.has(k):
			blocos[k] = PackedVector3Array()
		var cr := (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
		if cr >= 0.0:                                 # virado para cima (igual ao mundo/cidade.gd _tri)
			blocos[k].append_array(PackedVector3Array([a, b, c]))
		else:
			blocos[k].append_array(PackedVector3Array([a, c, b]))
	for nome in d["gramados"]:
		var p := _poli(d["gramados"][nome])
		var idx := Geometry2D.triangulate_polygon(p)
		for i in range(0, idx.size(), 3):
			por.call("gramado", _v3(p[idx[i]], 0.03), _v3(p[idx[i + 1]], 0.03), _v3(p[idx[i + 2]], 0.03))
	for e in d["pracas"]:
		var p := _poli(e[1])
		var piso := String(e[2])
		var matn := "piso_tijolo" if piso == "tijolo" else ("terra" if piso == "terra" else "pedra_chao")
		var idx := Geometry2D.triangulate_polygon(p)
		for i in range(0, idx.size(), 3):
			por.call(matn, _v3(p[idx[i]], 0.06), _v3(p[idx[i + 1]], 0.06), _v3(p[idx[i + 2]], 0.06))
	for c in d["pistas"]:
		_faixa(por, _poli(c), 4.5, "asfalto", 0.08)
	for c in d["caminhos"]:
		_faixa(por, _poli(c), 2.0, "caminho", 0.05)
	_faixa(por, _poli(d["mall"]), 6.0, "mall", 0.07)
	for k in blocos:
		var v: PackedVector3Array = blocos[k]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		var n := PackedVector3Array()
		var uv := PackedVector2Array()
		n.resize(v.size())
		n.fill(Vector3.UP)
		for q in v:
			uv.append(Vector2(q.x, q.z))
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(0, mat(String(k[0])))
		var mi := por_malha("CP_chao_%s_%d_%d" % [k[0], k[1].x, k[1].y], am, Transform3D.IDENTITY, 0.0, false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _v3(p: Vector2, dy: float) -> Vector3:
	return Vector3(p.x, Y + dy, p.y)

# faixa contínua ao longo da linha (cantos com "mitra": sem buraco nas curvas)
func _faixa(por: Callable, pts: PackedVector2Array, meia: float, matn: String, dy: float) -> void:
	var n := pts.size()
	if n < 2:
		return
	var esq := PackedVector2Array()
	var dir := PackedVector2Array()
	for i in n:
		var t := Vector2.ZERO
		if i > 0:
			t += (pts[i] - pts[i - 1]).normalized()
		if i < n - 1:
			t += (pts[i + 1] - pts[i]).normalized()
		t = t.normalized() if t.length() > 0.001 else Vector2.RIGHT
		var nn := Vector2(-t.y, t.x)
		esq.append(pts[i] + nn * meia)
		dir.append(pts[i] - nn * meia)
	for i in n - 1:
		por.call(matn, _v3(esq[i], dy), _v3(dir[i], dy), _v3(esq[i + 1], dy))
		por.call(matn, _v3(esq[i + 1], dy), _v3(dir[i], dy), _v3(dir[i + 1], dy))
	# pontas redondas (encontros de caminhos)
	for p: Vector2 in [pts[0], pts[n - 1]]:
		for k in 10:
			var a0 := k * TAU / 10.0
			var a1 := (k + 1) * TAU / 10.0
			por.call(matn, _v3(p, dy), _v3(p + Vector2(cos(a0), sin(a0)) * meia, dy), _v3(p + Vector2(cos(a1), sin(a1)) * meia, dy))

# ---------- MURO baixo de pedra no contorno (abre onde um caminho ou pista cruza; pilares nas pontas) ----------
const SEM_MURO := [Rect2(-1668, -1300, 136, 14)]          # a frente da Bethesda (o terraço alto encosta na rua)

func _muro(d: Dictionary) -> void:
	var c := Malhas.Construtor.new()
	var linhas: Array = []                                # todos os caminhos/pistas (para achar onde cruzam o muro)
	for k in ["caminhos", "pistas"]:
		for l in d[k]:
			linhas.append(_poli(l))
	linhas.append(_poli(d["mall"]))
	for m in d["muros"]:
		var pts := _poli(m)
		var centro := Vector2.ZERO
		for q in pts:
			centro += q
		centro /= pts.size()
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var comp := a.distance_to(b)
			if comp < 1.0:
				continue
			var u := (b - a) / comp
			var nn := Vector2(-u.y, u.x)
			if nn.dot(centro - (a + b) * 0.5) < 0.0:
				nn = -nn
			var a2 := a + nn * 1.2
			var b2 := b + nn * 1.2
			var cortes: Array = []
			for l in linhas:
				var pl: PackedVector2Array = l
				for j in pl.size() - 1:
					var x = Geometry2D.segment_intersects_segment(pl[j], pl[j + 1], a2 - u * 3.0, b2 + u * 3.0)
					if x != null:
						var t: float = (x - a2).dot(u)
						cortes.append(Vector2(t - 6.5, t + 6.5))
				for ponta: Vector2 in [pl[0], pl[pl.size() - 1]]:
					var t := (ponta - a2).dot(u)
					if absf((ponta - a2).dot(nn)) < 8.0 and t > -6.0 and t < comp + 6.0:
						cortes.append(Vector2(t - 6.5, t + 6.5))
			cortes.sort_custom(func(x, y): return x.x < y.x)
			var t0 := 0.0
			var trechos: Array = []
			for ct: Vector2 in cortes:
				if ct.x > t0:
					trechos.append(Vector2(t0, minf(ct.x, comp)))
				t0 = maxf(t0, ct.y)
			if t0 < comp:
				trechos.append(Vector2(t0, comp))
			for tr: Vector2 in trechos:
				if tr.y - tr.x < 1.0:
					continue
				var p0 := a2 + u * tr.x
				var p1 := a2 + u * tr.y
				var meio := (p0 + p1) * 0.5
				var pulou := false
				for r in SEM_MURO:
					if r.has_point(meio):
						pulou = true
				if pulou:
					continue
				var l := p0.distance_to(p1)
				var bb := Basis(Vector3.UP, atan2(-u.y, u.x))
				c.caixa(Vector3(meio.x, Y + 0.45, meio.y), Vector3(l, 0.9, 0.55), XISTO * 1.05, bb)
				c.caixa(Vector3(meio.x, Y + 0.95, meio.y), Vector3(l, 0.12, 0.7), PEDRA * 0.9, bb)     # capa do muro
				col(Vector3(meio.x, Y + 0.5, meio.y), Vector3(l, 1.0, 0.6), bb)
				for ponta: Vector2 in [p0, p1]:
					if (ponta == p0 and tr.x > 0.5) or (ponta == p1 and tr.y < comp - 0.5):
						c.caixa(Vector3(ponta.x, Y + 0.85, ponta.y), Vector3(0.9, 1.7, 0.9), XISTO * 1.1, bb)
						c.caixa(Vector3(ponta.x, Y + 1.75, ponta.y), Vector3(1.05, 0.14, 1.05), PEDRA * 0.95, bb)
						col(Vector3(ponta.x, Y + 0.85, ponta.y), Vector3(0.9, 1.7, 0.9), bb)
	por_malha("CP_muro", c.malha(mat("xisto")), Transform3D.IDENTITY, 900.0)

# ---------- ROCHAS de xisto (blocos tortos aflorando da grama) ----------
func _rochas(d: Dictionary) -> void:
	var c := Malhas.Construtor.new()
	var r := RandomNumberGenerator.new()
	r.seed = 1858
	for e in d["rochas"]:
		var p := Vector2(float(e[0]), float(e[1]))
		var tam := float(e[2])
		_rocha(c, r, p, tam, 0.0)
	por_malha("CP_rochas", c.malha(mat("xisto")), Transform3D.IDENTITY, 700.0)

# uma rocha: vários blocos inclinados; "base" = altura extra (Vista Rock)
func _rocha(c: Malhas.Construtor, r: RandomNumberGenerator, p: Vector2, tam: float, base: float) -> void:
	var n := 4 + int(tam / 3.0)
	for k in n:
		var a := r.randf() * TAU
		var dist := r.randf() * tam * 0.45
		var q := p + Vector2(cos(a), sin(a)) * dist
		var w := r.randf_range(0.35, 0.65) * tam
		var h := r.randf_range(0.12, 0.3) * tam * (1.0 - dist / tam * 0.8) + base
		var bb := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(-0.25, 0.25)) * Basis(Vector3.FORWARD, r.randf_range(-0.2, 0.2))
		var cor := XISTO * r.randf_range(0.8, 1.05)
		cor.a = 1.0
		c.caixa(Vector3(q.x, Y + h * 0.5 - 0.3, q.y), Vector3(w, h, w * r.randf_range(0.6, 1.0)), cor, bb)
		if k < 3:
			col(Vector3(q.x, Y + h * 0.5 - 0.3, q.y), Vector3(w * 0.85, h, w * 0.7), bb)

# ---------- POSTES (o "B" do Central Park) e BANCOS (ripas verdes, braços de ferro) ----------
static func malha_poste() -> ArrayMesh:
	var f := Malhas.Construtor.new()
	f.cilindro(Vector3(0, 0.3, 0), 0.24, 0.6, 8, FERRO, Basis.IDENTITY, 0.17)          # base
	f.cilindro(Vector3(0, 0.7, 0), 0.17, 0.2, 8, FERRO)
	f.cilindro(Vector3(0, 2.15, 0), 0.11, 2.7, 8, FERRO, Basis.IDENTITY, 0.075)       # coluna
	f.cilindro(Vector3(0, 3.55, 0), 0.1, 0.12, 8, FERRO)
	f.cilindro(Vector3(0, 3.66, 0), 0.06, 0.1, 6, FERRO)
	f.cilindro(Vector3(0, 4.33, 0), 0.03, 0.12, 6, FERRO)                            # ponta
	f.cilindro(Vector3(0, 4.22, 0), 0.24, 0.1, 10, FERRO, Basis.IDENTITY, 0.06)       # chapéu
	var am := f.malha(mat("ferro"))
	var g := Malhas.Construtor.new()
	g.cilindro(Vector3(0, 3.93, 0), 0.2, 0.52, 10, Color(1.0, 0.9, 0.7), Basis.IDENTITY, 0.23)   # o vidro
	g.malha(mat("vidro"), am)
	return am

static func malha_banco() -> ArrayMesh:
	var c := Malhas.Construtor.new()
	var l := 1.9
	for k in 5:
		c.caixa(Vector3(0, 0.44, 0.06 - k * 0.09), Vector3(l, 0.035, 0.07), VERDE_BANCO)                   # assento
	for k in 4:
		var y := 0.6 + k * 0.1
		c.caixa(Vector3(0, y, -0.36 - k * 0.025), Vector3(l, 0.07, 0.03), VERDE_BANCO, Basis(Vector3.RIGHT, -0.25))    # encosto
	for x: float in [-l * 0.5 + 0.08, 0.0, l * 0.5 - 0.08]:
		c.caixa(Vector3(x, 0.22, -0.12), Vector3(0.05, 0.44, 0.5), FERRO)
		c.caixa(Vector3(x, 0.66, -0.4), Vector3(0.05, 0.5, 0.05), FERRO, Basis(Vector3.RIGHT, -0.25))
	for x: float in [-l * 0.5 + 0.04, l * 0.5 - 0.04]:
		c.caixa(Vector3(x, 0.62, -0.05), Vector3(0.06, 0.05, 0.52), FERRO)                               # braços
	return c.malha(mat("madeira"))

func _postes_e_bancos(d: Dictionary) -> void:
	var grupos := {"poste": {}, "banco": {}}
	for p in d["postes"]:
		var k := Vector2i(floori(float(p[0]) / BLOCO), floori(float(p[1]) / BLOCO))
		if not grupos["poste"].has(k):
			grupos["poste"][k] = []
		grupos["poste"][k].append(Transform3D(Basis.IDENTITY, Vector3(float(p[0]), Y, float(p[1]))))
		obstaculos.append_array(PackedFloat32Array([float(p[0]), float(p[1]), 0.0, 0.35, 3.0, 0.35, Y + 1.5]))
	for b in d["bancos"]:
		var k := Vector2i(floori(float(b[0]) / BLOCO), floori(float(b[1]) / BLOCO))
		if not grupos["banco"].has(k):
			grupos["banco"][k] = []
		grupos["banco"][k].append(Transform3D(Basis(Vector3.UP, float(b[2])), Vector3(float(b[0]), Y, float(b[1]))))
		obstaculos.append_array(PackedFloat32Array([float(b[0]), float(b[1]), float(b[2]), 1.9, 0.9, 0.6, Y + 0.45]))
	for tipo in grupos:
		var malha: ArrayMesh = malha_poste() if tipo == "poste" else malha_banco()
		for k in grupos[tipo]:
			var lista: Array = grupos[tipo][k]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = malha
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, lista[i])
			var mi := MultiMeshInstance3D.new()
			mi.name = "CP_%s_%d_%d" % [tipo, k.x, k.y]
			mi.multimesh = mm
			mi.visibility_range_end = ALCANCE_POSTE if tipo == "poste" else ALCANCE_BANCO
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tipo == "poste" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			visuais.append(mi)

# ---------- MAPA (hud/mapa.gd): gramados mais claros, praças, caminhos e pistas ----------
static func desenhar_mapa(ci: CanvasItem, cor_parque: Color, cor_caminho: Color) -> void:
	var d := dados()
	if d.is_empty():
		return
	var rid := ci.get_canvas_item()
	for nome in d["gramados"]:
		var p := _poli(d["gramados"][nome])
		var idx := Geometry2D.triangulate_polygon(p)
		if not idx.is_empty():
			RenderingServer.canvas_item_add_triangle_array(rid, idx, p, PackedColorArray([cor_parque.lightened(0.18)]))
	var cc := cor_parque.lerp(cor_caminho, 0.7)
	for e in d["pracas"]:
		var p := _poli(e[1])
		var idx := Geometry2D.triangulate_polygon(p)
		if not idx.is_empty():
			RenderingServer.canvas_item_add_triangle_array(rid, idx, p, PackedColorArray([cc]))
	for c in d["pistas"]:
		ci.draw_polyline(_poli(c), cc, 9.0)
	for c in d["caminhos"]:
		ci.draw_polyline(_poli(c), cc, 4.0)
	ci.draw_polyline(_poli(d["mall"]), cc, 12.0)

# ---------- ÁRVORES (mundo/arvores.gd): a lista do desenho ----------
static func plantar_arvores(cidade: Node, arv: Node) -> void:
	var d := dados()
	if d.is_empty():
		return
	var n := 0
	for a in d["arvores"]:
		n += 1
		if n % 2048 == 0:
			await cidade.pausa()
		var tom := float(a[5])
		var cor := Color(1, 1, 1) * absf(tom)
		if tom < 0.0:
			cor = Color(1.0, 0.7, 0.4) * absf(tom)                     # outono
		cor.a = 1.0
		arv.plantar(String(a[0]), Vector3(float(a[1]), Y, float(a[2])), float(a[3]), float(a[4]), 1.0, cor)
