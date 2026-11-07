extends Node3D
# ÁRVORES (1.20; 1.21: o sistema de detalhe no jeito da UNREAL ENGINE 5, estudos/ESTUDO_AAA.md 1.14): as árvores da
# cidade inteira (as 13 mil dos lugares guardados na 1.19 + o Central Park bem denso + as dos pontos turísticos).
# Modelos REALISTAS gerados pelo EZ-Tree (ferramentas/arvores_ez/, MIT; texturas CC0: mundo/arvores/texturas/LICENCA.txt),
# 24 variações (carvalho, freixo, olmo, álamo, pinheiro e secas):
#   mundo/arvores/modelos/<nome>.res  a árvore COMPLETA (casca + folhas) · ferramentas/preparar_arvores.gd
#   mundo/arvores/lod1/<nome>.res     a SIMPLIFICADA (~37% dos triângulos, 1 superfície) · ferramentas/preparar_arvores_lod.gd
#   mundo/arvores/voxels.json         os VOXELS de cada árvore (40 e 12 bolhas de folhagem/galho) · idem
#   mundo/arvores/arvores.json        altura, raio da copa, raio do tronco, tipo...
# COMO DESENHA (4 níveis; a troca é pelo TAMANHO DA ÁRVORE NA TELA, em pixels de altura, como o Nanite escolhe o
# detalhe pelo erro na tela: muda sozinho com a resolução e com o zoom da luneta):
#   0 COMPLETA      >= PX[0] px · a árvore inteira (2 a 5 mil triângulos), folhas com vento, sombra
#   1 SIMPLIFICADA  PX[1]..PX[0] · menos galhos e 1/3 das folhas (maiores), casca e folhas numa chamada só, sombra; o
#                   vento vai sumindo (como a Unreal, que para a animação das árvores pequenas na tela)
#   2 VOXELS        PX[2]..PX[1] · a árvore vira um VOLUME de 40 bolhas (as "voxels" do Nanite Foliage da 5.7): de
#                   qualquer lado a silhueta e a massa da copa continuam certas (nada de foto plana virando com você)
#   3 VOXELS GROSSOS < PX[2] até o alcance · 12 bolhas
#   As trocas não "estalam": numa FAIXA em volta de cada limiar os dois níveis aparecem pontilhados um no lugar do outro
#   (o "dithered LOD transition" da Unreal; o padrão é o mesmo nos dois: nenhum ponto fica sem árvore ou com duas).
#   Os níveis 0 e 1 são listas de PERTO refeitas aqui (CPU) quando a câmera anda MOVER m ou o zoom muda (um MultiMesh
#   por modelo e nível); os voxels são MultiMesh FIXOS por bloco de BLOCO m (os chunks tiram da cena os de longe) e o
#   próprio shader esconde quem não está no tamanho dele (a GPU decide, como as instâncias do Nanite).
#   "centro" (a câmera) e "escala_px" (pixels por metro a 1 m) vão para os materiais a cada quadro; na sombra vale a
#   mesma conta (a árvore não muda de nível na sombra).
# COLISÃO: o tronco de cada árvore vira um obstáculo (caixa) da física perto do jogador (mundo/colisao_mundo.gd).
# Quem usa: mundo/cidade.gd (planta: lugares guardados + mundo/central_park.gd + mundo/pontos_turisticos.gd) e
# menu/aplicar_opcoes.gd ("Distância dos detalhes" muda os limiares e até onde vão os voxels).
# Mexa AQUI para: limiares, faixa do dissolve, alcance, vento, cor das folhas.

const DIR := "res://mundo/arvores/"
const BLOCO := 250.0                     # voxels: um MultiMesh por bloco
const CEL := 32.0                        # grade para achar as árvores perto
const MOVER := 4.0                       # as listas de perto são refeitas quando a câmera anda isso
const FOLGA := 8.0                       # ... e pegam a mais (cobre o andar até refazer)
const PX := [300.0, 110.0, 32.0]         # altura na tela (px) das trocas 0|1, 1|2 e 2|3
const FAIXA := 0.08                      # o dissolve vai de limiar x (1 - FAIXA) a limiar x (1 + FAIXA) (sem o TAA da
                                         # Unreal o pontilhado aparece: faixa curta = poucas árvores trocando de cada vez)
const QUALIDADE := [1.7, 1.3, 1.0, 0.78] # por "Distância dos detalhes" (0..3): multiplica os limiares (maior = troca antes)
const ALCANCE := [900.0, 1400.0, 2000.0, 2800.0]      # até onde vão os voxels grossos (some com dissolve)
const PX_VENTO := 160.0                  # abaixo disso as folhas param de mexer
const K_FINO := 40                       # bolhas do voxel fino e do grosso (ferramentas/preparar_arvores_lod.gd)
const K_GROSSO := 12
const TRONCO_ALTURA := 4.0               # altura da caixa de colisão do tronco

# ---------------------------------------------------------------------------------------------------------------
# MODELOS (static: os mesmos para todo mundo; carregados uma vez)
# ---------------------------------------------------------------------------------------------------------------
static var _info := {}                   # nome -> {tipo, seca, altura, raio_copa, raio_tronco, lado, casca, folha, cor_folha}
static var _nomes: Array = []
static var _malhas := {}
static var _mats := {}
static var _tex_voxels: ImageTexture = null

static func info() -> Dictionary:
	if _info.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "arvores.json"))
		if d is Dictionary:
			for e in d["modelos"]:
				_info[String(e["nome"])] = e
				_nomes.append(String(e["nome"]))
	return _info

static func nomes() -> Array:
	info()
	return _nomes

static func do_tipo(tipo: String) -> Array:
	var r: Array = []
	for n in nomes():
		if String(_info[n]["tipo"]) == tipo:
			r.append(n)
	return r

static func malha(nome: String) -> ArrayMesh:
	if not _malhas.has(nome):
		_malhas[nome] = load(DIR + "modelos/%s.res" % nome)
	return _malhas[nome]

static func malha_lod1(nome: String) -> ArrayMesh:
	if not _malhas.has("lod1_" + nome):
		_malhas["lod1_" + nome] = load(DIR + "lod1/%s.res" % nome)
	return _malhas["lod1_" + nome]

static func cor_folha(nome: String) -> Color:
	var c = info()[nome].get("cor_folha", "ffffff")
	return Color.html(String(c))

# os voxels de todos os modelos numa textura (4 linhas por modelo: fino [centro + raio], fino [cor + é folha],
# grosso, grosso; uma coluna por bolha)
static func tex_voxels() -> ImageTexture:
	if _tex_voxels != null:
		return _tex_voxels
	var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "voxels.json"))
	var lista := nomes()
	var img := Image.create(K_FINO, maxi(lista.size(), 1) * 4, false, Image.FORMAT_RGBAH)
	img.fill(Color(0, 0, 0, 0))
	if d is Dictionary:
		for m in lista.size():
			var e: Dictionary = d["modelos"].get(lista[m], {})
			for k in 2:
				var bolhas: Array = e.get("fino" if k == 0 else "grosso", [])
				for i in mini(bolhas.size(), K_FINO):
					var v: Array = bolhas[i]
					img.set_pixel(i, m * 4 + k * 2, Color(float(v[0]), float(v[1]), float(v[2]), float(v[3])))
					img.set_pixel(i, m * 4 + k * 2 + 1, Color(float(v[4]), float(v[5]), float(v[6]), float(v[7])))
	_tex_voxels = ImageTexture.create_from_image(img)
	return _tex_voxels

# ---------------------------------------------------------------------------------------------------------------
# MATERIAIS (completa: 3 cascas + 4 folhas · simplificada: 1 por par casca/folha · voxels: 2)
# ---------------------------------------------------------------------------------------------------------------
# o que todo nível tem: o tamanho na tela e o dissolve da troca
#   px_min: abaixo disso (com a faixa) o nível some (0 = não some) · px_max: acima disso some (0 = não some)
#   alcance: some com a distância (só os voxels grossos) · o dissolve: lod.x sobe na troca de baixo (aparece onde
#   passa do ruído), lod.y desce na de cima (aparece onde passa do ruído invertido: o nível vizinho fica com o resto)
const _LOD := """
uniform vec3 centro = vec3(0.0, -100000.0, 0.0);
uniform float escala_px = 600.0;
uniform float px_min = 0.0;
uniform float px_max = 0.0;
uniform float faixa = 0.16;
uniform float alcance = 0.0;
global uniform float vento;
float lod_px(vec3 o, float altura) {
	return altura * escala_px / max(distance(o + vec3(0.0, altura * 0.5, 0.0), centro), 0.5);
}
vec2 lod_fator(vec3 o, float altura) {
	float px = lod_px(o, altura);
	float a = px_min > 0.0 ? smoothstep(px_min * (1.0 - faixa), px_min * (1.0 + faixa), px) : 1.0;
	float b = px_max > 0.0 ? 1.0 - smoothstep(px_max * (1.0 - faixa), px_max * (1.0 + faixa), px) : 1.0;
	if (alcance > 0.0) {
		a *= 1.0 - smoothstep(alcance * 0.88, alcance, distance(o, centro));
	}
	return vec2(a, b);
}
bool lod_some(vec2 f, vec2 frag) {
	float t = clamp(fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715)))), 0.002, 0.998);
	return (f.x < 1.0 && f.x <= t) || (f.y < 1.0 && f.y <= 1.0 - t);
}
"""

const SHADER_CASCA := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_enable;
""" + _LOD + """
varying flat vec2 lod;
void vertex() {
	vec2 f = lod_fator(MODEL_MATRIX[3].xyz, INSTANCE_CUSTOM.w);
	lod = f;
	if (f.x <= 0.0 || f.y <= 0.0) {
		VERTEX = vec3(0.0);                       // não é este nível: some inteira (não chega no fragmento)
	}
}
void fragment() {
	if (lod_some(lod, FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = texture(tex, UV).rgb;
	ALBEDO = c * mix(vec3(1.0), COLOR.rgb, 0.25);
	NORMAL_MAP = texture(tex_normal, UV).rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
"""

# folhas: dos dois lados, recorte pela transparência, vento (as pontas mexem mais; some quando a árvore fica pequena
# na tela), cor de cada árvore (COLOR)
const SHADER_FOLHA := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_corte = 0.5;
uniform float px_vento = 160.0;
""" + _LOD + """
varying flat vec2 lod;
varying float h;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 f = lod_fator(o, INSTANCE_CUSTOM.w);
	lod = f;
	if (f.x <= 0.0 || f.y <= 0.0) {
		VERTEX = vec3(0.0);
	} else {
		float fv = smoothstep(px_vento * 0.7, px_vento, lod_px(o, INSTANCE_CUSTOM.w));
		if (fv > 0.0) {
			float fase = o.x * 0.37 + o.z * 0.23;
			float t = TIME;
			float forca = (0.25 + vento) * clamp(VERTEX.y * 0.08, 0.0, 1.5) * fv;
			VERTEX.x += (sin(t * 1.9 + fase + VERTEX.y * 0.6) * 0.05 + sin(t * 0.7 + fase) * 0.09) * forca;
			VERTEX.z += cos(t * 1.6 + fase * 1.3 + VERTEX.x * 0.5) * 0.05 * forca;
		}
	}
	h = VERTEX.y;
}
void fragment() {
	if (lod_some(lod, FRAGCOORD.xy)) {
		discard;
	}
	vec4 t = texture(tex, UV);
	vec3 c = t.rgb * COLOR.rgb;
	c *= 0.82 + 0.18 * clamp(h * 0.08, 0.0, 1.0);          // por dentro e embaixo da copa, mais escuro
	ALBEDO = c;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_corte;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	BACKLIGHT = c * 0.35;
}
"""

# a SIMPLIFICADA: casca e folhas na mesma malha (UV2.x = 1 na casca: textura da casca, sem recorte)
const SHADER_SIMPLES := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex_folha : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_casca : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha_corte = 0.5;
uniform float px_vento = 160.0;
""" + _LOD + """
varying flat vec2 lod;
varying float h;
varying float casca;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 f = lod_fator(o, INSTANCE_CUSTOM.w);
	lod = f;
	casca = UV2.x;
	if (f.x <= 0.0 || f.y <= 0.0) {
		VERTEX = vec3(0.0);
	} else if (UV2.x < 0.5) {
		float fv = smoothstep(px_vento * 0.7, px_vento, lod_px(o, INSTANCE_CUSTOM.w));
		if (fv > 0.0) {
			float fase = o.x * 0.37 + o.z * 0.23;
			float forca = (0.25 + vento) * clamp(VERTEX.y * 0.08, 0.0, 1.5) * fv;
			VERTEX.x += (sin(TIME * 1.9 + fase + VERTEX.y * 0.6) * 0.05 + sin(TIME * 0.7 + fase) * 0.09) * forca;
		}
	}
	h = VERTEX.y;
}
void fragment() {
	if (lod_some(lod, FRAGCOORD.xy)) {
		discard;
	}
	if (casca > 0.5) {
		vec3 c = texture(tex_casca, UV).rgb;
		ALBEDO = c * mix(vec3(1.0), COLOR.rgb, 0.25);
		ROUGHNESS = 0.92;
		SPECULAR = 0.15;
	} else {
		vec4 t = texture(tex_folha, UV);
		vec3 c = t.rgb * COLOR.rgb * (0.82 + 0.18 * clamp(h * 0.08, 0.0, 1.0));
		ALBEDO = c;
		ALPHA = t.a;
		ROUGHNESS = 0.8;
		SPECULAR = 0.2;
		BACKLIGHT = c * 0.35;
	}
	ALPHA_SCISSOR_THRESHOLD = alpha_corte;
}
"""

# os VOXELS: cada bolha é um quadrado virado para a câmera (na sombra, para a luz) com a normal de uma esfera (a luz
# fica "redonda", de volume) e a borda recortada com ruído (não fica bola lisa). A bolha i do modelo m vem da textura
# (linha m * 4 + "linha"); bolha com raio 0 = não existe (o quadrado some).
const SHADER_VOXEL := """
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;
uniform sampler2D voxels : filter_nearest;
uniform int linha = 0;
""" + _LOD + """
varying flat vec2 lod;
varying flat vec4 cor;
varying vec2 q;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 f = lod_fator(o, INSTANCE_CUSTOM.w);
	lod = f;
	q = UV * 2.0 - 1.0;
	cor = vec4(0.0);
	VERTEX = vec3(0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	if (f.x > 0.0 && f.y > 0.0) {
		int m = int(INSTANCE_CUSTOM.x + 0.5);
		int i = int(UV2.x + 0.5);
		vec4 a = texelFetch(voxels, ivec2(i, m * 4 + linha), 0);
		if (a.w > 0.0) {
			vec4 b = texelFetch(voxels, ivec2(i, m * 4 + linha + 1), 0);
			vec3 c = (MODEL_MATRIX * vec4(a.xyz, 1.0)).xyz;
			float esc = length(MODEL_MATRIX[0].xyz);
			VERTEX = (VIEW_MATRIX * vec4(c, 1.0)).xyz + vec3(q * a.w * esc, 0.0);
			cor = vec4(b.rgb * mix(vec3(1.0), COLOR.rgb, b.a), fract(float(i) * 0.137 + o.x * 0.0113 + o.z * 0.0071));
		}
	}
}
void fragment() {
	if (lod_some(lod, FRAGCOORD.xy)) {
		discard;
	}
	float d2 = dot(q, q);
	vec2 g = floor(q * 3.0 + 3.0);
	float borda = 0.7 + 0.3 * fract(sin(dot(g + cor.a * 17.0, vec2(12.9898, 78.233))) * 43758.5453);
	if (d2 > borda) {
		discard;
	}
	NORMAL = normalize(vec3(q, sqrt(max(1.0 - d2, 0.0)) + 0.35));
	ALBEDO = cor.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.12;
	BACKLIGHT = cor.rgb * 0.3;
}
"""

const CASCAS := {"oak": "carvalho", "birch": "betula", "pine": "pinheiro", "willow": "carvalho"}
const FOLHAS := {"ash": "freixo", "aspen": "alamo", "oak": "carvalho", "pine": "pinheiro"}

static func _shader(codigo: String) -> Shader:
	var k := "sh_" + str(codigo.hash())
	if not _mats.has(k):
		var s := Shader.new()
		s.code = codigo
		_mats[k] = s
	return _mats[k]

static func mat_casca(tipo: String) -> ShaderMaterial:
	var nome := String(CASCAS.get(tipo, "carvalho"))
	var k := "casca_" + nome
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _shader(SHADER_CASCA)
		m.set_shader_parameter("tex", load(DIR + "texturas/casca_%s.jpg" % nome))
		m.set_shader_parameter("tex_normal", load(DIR + "texturas/casca_%s_normal.jpg" % nome))
		_mats[k] = m
	return _mats[k]

static func mat_folha(tipo: String) -> ShaderMaterial:
	var nome := String(FOLHAS.get(tipo, "carvalho"))
	var k := "folha_" + nome
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _shader(SHADER_FOLHA)
		m.set_shader_parameter("tex", load(DIR + "texturas/folha_%s.png" % nome))
		m.set_shader_parameter("px_vento", PX_VENTO)
		_mats[k] = m
	return _mats[k]

static func mat_simples(casca: String, folha: String) -> ShaderMaterial:
	var nc := String(CASCAS.get(casca, "carvalho"))
	var nf := String(FOLHAS.get(folha, "carvalho"))
	var k := "simples_%s_%s" % [nc, nf]
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _shader(SHADER_SIMPLES)
		m.set_shader_parameter("tex_casca", load(DIR + "texturas/casca_%s.jpg" % nc))
		m.set_shader_parameter("tex_folha", load(DIR + "texturas/folha_%s.png" % nf))
		m.set_shader_parameter("px_vento", PX_VENTO)
		_mats[k] = m
	return _mats[k]

static func mat_voxel(grosso: bool) -> ShaderMaterial:
	var k := "voxel_grosso" if grosso else "voxel_fino"
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _shader(SHADER_VOXEL)
		m.set_shader_parameter("voxels", tex_voxels())
		m.set_shader_parameter("linha", 2 if grosso else 0)
		_mats[k] = m
	return _mats[k]

# o nível de cada material (para os limiares): casca_/folha_ = 0, simples_ = 1, voxel_fino = 2, voxel_grosso = 3
static func _nivel_mat(k: String) -> int:
	if k.begins_with("casca_") or k.begins_with("folha_"):
		return 0
	if k.begins_with("simples_"):
		return 1
	if k == "voxel_fino":
		return 2
	if k == "voxel_grosso":
		return 3
	return -1

# a malha dos voxels: K quadrados (UV = canto, UV2.x = número da bolha); o shader põe cada um no lugar
static var _malha_voxel := {}
static func malha_voxel(k: int) -> ArrayMesh:
	if _malha_voxel.has(k):
		return _malha_voxel[k]
	var vs := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var ns := PackedVector3Array()
	var ix := PackedInt32Array()
	for i in k:
		var b := vs.size()
		for c in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			vs.append(Vector3(c.x - 0.5, c.y, 0.0))
			uv.append(c)
			uv2.append(Vector2(i, 0))
			ns.append(Vector3.BACK)
		ix.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = ix
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.custom_aabb = AABB(Vector3(-12.0, -1.0, -12.0), Vector3(24.0, 28.0, 24.0))
	_malha_voxel[k] = am
	return am

# ---------------------------------------------------------------------------------------------------------------
# AS ÁRVORES PLANTADAS
# ---------------------------------------------------------------------------------------------------------------
var _var := PackedInt32Array()            # índice do modelo (ordem de nomes())
var _pos := PackedVector3Array()
var _alt := PackedFloat32Array()          # altura de verdade (já com a escala)
var _reg := PackedFloat32Array()          # 20 floats por árvore: transform (12) + cor (4) + custom (4: modelo, 0, 0, altura)
var _grade := {}                          # Vector2i -> PackedInt32Array
var _alt_max := 1.0
var _alt_min := 1.0e9
var _blocos_longe: Array = []             # [MultiMeshInstance3D, grosso?] (o alcance de cada um segue os limiares)
var _perto := {}                          # "nivel_modelo" -> MultiMeshInstance3D (níveis 0 e 1)
var _ult := Vector3(1.0e9, 0.0, 1.0e9)
var _ult_esc := 0.0
var escala_px := 600.0                    # pixels de altura por metro a 1 m da câmera (resolução e campo de visão)
var qualidade: float = QUALIDADE[2]
var alcance: float = ALCANCE[2]
var longe: Array = []                     # MultiMeshInstance3D dos voxels (a cidade adota: os chunks cuidam)
var obstaculos := PackedFloat32Array()    # troncos no formato do mundo/colisao_mundo.gd (7 floats cada)
var contagem := {}                        # nome -> quantas (estatística e testes)
var sombra := true
var por_nivel := [0, 0]                   # (testes) quantas árvores estão nas listas de perto de cada nível

func quantas() -> int:
	return _var.size()

# planta uma árvore do modelo "nome" em p (chão), girada "giro", escala s (e sh na altura), cor das folhas "tom"
func plantar(nome: String, p: Vector3, giro: float, s: float, sh := 1.0, tom := Color(1, 1, 1)) -> void:
	var lista := nomes()
	var vi := lista.find(nome)
	if vi < 0:
		return
	var e: Dictionary = _info[nome]
	var i := _var.size()
	_var.append(vi)
	_pos.append(p)
	var alt := float(e["altura"]) * s * sh
	_alt.append(alt)
	_alt_max = maxf(_alt_max, alt)
	_alt_min = minf(_alt_min, alt)
	var b := Basis(Vector3.UP, giro).scaled(Vector3(s, s * sh, s))
	var c := cor_folha(nome) * tom
	c.a = 1.0
	_reg.append_array(PackedFloat32Array([b.x.x, b.y.x, b.z.x, p.x, b.x.y, b.y.y, b.z.y, p.y, b.x.z, b.y.z, b.z.z, p.z,
		c.r, c.g, c.b, 1.0, float(vi), 0.0, 0.0, alt]))
	var k := Vector2i(floori(p.x / CEL), floori(p.z / CEL))
	if not _grade.has(k):
		_grade[k] = PackedInt32Array()
	_grade[k].append(i)
	contagem[nome] = int(contagem.get(nome, 0)) + 1
	# tronco (colisão): caixa do tamanho do tronco perto do chão
	var rt := float(e.get("raio_tronco", 0.3)) * s * 1.6
	if rt > 0.12:
		obstaculos.append_array(PackedFloat32Array([p.x, p.z, giro, rt, TRONCO_ALTURA, rt, p.y + TRONCO_ALTURA * 0.5]))

# depois de plantar todas: os MultiMesh dos voxels (fino e grosso, um de cada por bloco); quem chama adota os nós
func montar() -> Array:
	var blocos := {}
	for i in _var.size():
		var p := _pos[i]
		var k := Vector2i(floori(p.x / BLOCO), floori(p.z / BLOCO))
		if not blocos.has(k):
			blocos[k] = PackedInt32Array()
		blocos[k].append(i)
	for k in blocos:
		var idx: PackedInt32Array = blocos[k]
		var buf := PackedFloat32Array()
		buf.resize(idx.size() * 20)
		var j := 0
		for i in idx:
			for q in 20:
				buf[j + q] = _reg[i * 20 + q]
			j += 20
		for grosso in [false, true]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = malha_voxel(K_GROSSO if grosso else K_FINO)
			mm.instance_count = idx.size()
			mm.buffer = buf
			var mi := MultiMeshInstance3D.new()
			mi.name = "ArvoresLonge_%d_%d_%s" % [k.x, k.y, "g" if grosso else "f"]
			mi.multimesh = mm
			mi.material_override = mat_voxel(grosso)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			longe.append(mi)
			_blocos_longe.append([mi, grosso])
	_limiares()
	return longe

# "Distância dos detalhes" (0..3)
func aplicar_alcance(nivel: int) -> void:
	qualidade = QUALIDADE[clampi(nivel, 0, 3)]
	alcance = ALCANCE[clampi(nivel, 0, 3)]
	_limiares()
	_ult = Vector3(1.0e9, 0.0, 1.0e9)

# os limiares de cada nível nos materiais
func _limiares() -> void:
	var t0: float = PX[0] * qualidade
	var t1: float = PX[1] * qualidade
	var t2: float = PX[2] * qualidade
	for k in _mats.keys():
		var m = _mats[k]
		if not (m is ShaderMaterial):
			continue
		var nv := _nivel_mat(String(k))
		if nv < 0:
			continue
		m.set_shader_parameter("faixa", FAIXA)
		m.set_shader_parameter("px_min", [t0, t1, t2, 0.0][nv])
		m.set_shader_parameter("px_max", [0.0, t0, t1, t2][nv])
		m.set_shader_parameter("alcance", alcance if nv == 3 else 0.0)
	_alcances_blocos()

# o MultiMesh de voxels de um bloco só fica na cena enquanto alguma árvore dele PODE estar no nível dele (como o
# "cull distance" por cluster das folhagens da Unreal): o fino some nos blocos longe, o grosso nos que estão perto
# (a GPU não processa as árvores que o shader só iria esconder)
const RAIO_BLOCO := BLOCO * 0.72 + 20.0
func _alcances_blocos() -> void:
	if _blocos_longe.is_empty():
		return
	var t1: float = PX[1] * qualidade
	var t2: float = PX[2] * qualidade
	var fino := Vector2(_alt_min * escala_px / (t1 * (1.0 + FAIXA)), _alt_max * escala_px / (t2 * (1.0 - FAIXA)))
	var grosso := Vector2(_alt_min * escala_px / (t2 * (1.0 + FAIXA)), alcance)
	for e in _blocos_longe:
		var mi: MultiMeshInstance3D = e[0]
		if not is_instance_valid(mi):
			continue
		var faixa_d: Vector2 = grosso if e[1] else fino
		mi.visibility_range_begin = maxf(faixa_d.x - RAIO_BLOCO, 0.0)
		mi.visibility_range_end = faixa_d.y + RAIO_BLOCO

func aplicar_sombra(ligada: bool) -> void:
	sombra = ligada
	for k in _perto:
		_perto[k].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ligada else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _var.is_empty():
		return
	var tela := get_viewport().get_visible_rect().size
	var fov := deg_to_rad(cam.fov)
	if cam.keep_aspect == Camera3D.KEEP_WIDTH:
		fov = 2.0 * atan(tan(fov * 0.5) * tela.y / maxf(tela.x, 1.0))
	escala_px = tela.y / (2.0 * tan(fov * 0.5))
	atualizar(cam.global_position)

# a câmera em "c": manda para os materiais e, se andou (ou o zoom mudou), refaz as listas de perto
func atualizar(c: Vector3, forcar := false) -> void:
	for k in _mats:
		var m = _mats[k]
		if m is ShaderMaterial and _nivel_mat(String(k)) >= 0:
			m.set_shader_parameter("centro", c)
			m.set_shader_parameter("escala_px", escala_px)
	if not forcar and Vector2(c.x - _ult.x, c.z - _ult.z).length() < MOVER and absf(escala_px - _ult_esc) < _ult_esc * 0.03:
		return
	if absf(escala_px - _ult_esc) >= _ult_esc * 0.03:
		_ult_esc = escala_px
		_alcances_blocos()                                # o zoom mudou: os alcances dos blocos também
	_ult = c
	# até onde vai cada lista (a mesma conta do shader, com a FOLGA de andar até a próxima vez)
	var t0: float = PX[0] * qualidade
	var t1: float = PX[1] * qualidade
	var k0 := escala_px / (t0 * (1.0 - FAIXA))        # nível 0: d <= altura x k0 (+ FOLGA)
	var k0b := escala_px / (t0 * (1.0 + FAIXA))       # nível 1 começa em d >= altura x k0b (- FOLGA)
	var k1 := escala_px / (t1 * (1.0 - FAIXA))        # nível 1 vai até d <= altura x k1 (+ FOLGA)
	var r := _alt_max * k1 + FOLGA
	var r2 := r * r
	var listas := {}
	por_nivel = [0, 0]
	var c0 := Vector2i(floori((c.x - r) / CEL), floori((c.z - r) / CEL))
	var c1 := Vector2i(floori((c.x + r) / CEL), floori((c.z + r) / CEL))
	for gx in range(c0.x, c1.x + 1):
		for gz in range(c0.y, c1.y + 1):
			var kg := Vector2i(gx, gz)
			if not _grade.has(kg):
				continue
			for i in _grade[kg]:
				var p := _pos[i]
				var dx := p.x - c.x
				var dz := p.z - c.z
				if dx * dx + dz * dz > r2:
					continue
				var h := _alt[i]
				var dy := p.y + h * 0.5 - c.y
				var d := sqrt(dx * dx + dy * dy + dz * dz)
				var v := _var[i]
				if d <= h * k0 + FOLGA:
					var ch := "0_%d" % v
					if not listas.has(ch):
						listas[ch] = PackedFloat32Array()
					listas[ch].append_array(_reg.slice(i * 20, i * 20 + 20))
					por_nivel[0] += 1
				if d >= h * k0b - FOLGA and d <= h * k1 + FOLGA:
					var ch1 := "1_%d" % v
					if not listas.has(ch1):
						listas[ch1] = PackedFloat32Array()
					listas[ch1].append_array(_reg.slice(i * 20, i * 20 + 20))
					por_nivel[1] += 1
	var lista := nomes()
	for ch in _perto.keys():
		if not listas.has(ch):
			_perto[ch].visible = false
	for ch in listas:
		var buf: PackedFloat32Array = listas[ch]
		var mi: MultiMeshInstance3D = _perto.get(ch)
		if mi == null:
			var nv := int(String(ch).get_slice("_", 0))
			var v := int(String(ch).get_slice("_", 1))
			var e: Dictionary = _info[lista[v]]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			if nv == 0:
				var am: ArrayMesh = malha(lista[v]).duplicate()
				am.surface_set_material(0, mat_casca(String(e["casca"])))
				if am.get_surface_count() > 1:
					am.surface_set_material(1, mat_folha(String(e["folha"])))
				mm.mesh = am
			else:
				var am1: ArrayMesh = malha_lod1(lista[v]).duplicate()
				am1.surface_set_material(0, mat_simples(String(e["casca"]), String(e["folha"])))
				mm.mesh = am1
			mi = MultiMeshInstance3D.new()
			mi.name = "ArvoresPerto%d_%s" % [nv, String(lista[v])]
			mi.multimesh = mm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_perto[ch] = mi
			_limiares()                                  # material novo: recebe os limiares
		mi.visible = true
		mi.multimesh.instance_count = buf.size() / 20
		mi.multimesh.buffer = buf
		# a caixa (AABB) cobre o círculo de perto inteiro (a Godot não precisa recalcular a cada troca)
		mi.multimesh.custom_aabb = AABB(Vector3(c.x - r - 15.0, c.y - 80.0, c.z - r - 15.0), Vector3(2.0 * r + 30.0, 160.0, 2.0 * r + 30.0))
		mi.global_transform = Transform3D.IDENTITY

# quantas árvores de verdade (completas + simplificadas) estão nas listas de perto agora (testes)
func perto_agora() -> int:
	var n := 0
	for ch in _perto:
		if _perto[ch].visible:
			n += _perto[ch].multimesh.instance_count
	return n
