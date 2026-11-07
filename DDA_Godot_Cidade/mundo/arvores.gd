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
#   0 COMPLETA      >= PX[0] px · a árvore inteira (1,4 a 5,2 mil triângulos), folhas com vento, sombra
#   1 SIMPLIFICADA  PX[1]..PX[0] · menos galhos e 1/4 das folhas (maiores): ~27% dos triângulos, casca e folhas numa
#                   chamada só, sombra; o vento vai sumindo (como a Unreal, que para a animação das árvores pequenas)
#   2 VOXELS        PX[2]..PX[1] · a árvore vira um VOLUME de 24 bolhas (as "voxels" do Nanite Foliage da 5.7): de
#                   qualquer lado a silhueta e a massa da copa continuam certas (nada de foto plana virando com você)
#   3 VOXELS GROSSOS < PX[2] · 8 bolhas, até ~400 m (onde acabam as listas de perto); depois, até o alcance, o
#     "HLOD": 4 bolhas (só a copa), em blocos fixos, com dissolve na troca (o mesmo custo dos impostores de antes)
#   As trocas não "estalam": numa FAIXA em volta de cada limiar os dois níveis aparecem pontilhados um no lugar do outro
#   (o "dithered LOD transition" da Unreal; o padrão é o mesmo nos dois: nenhum ponto fica sem árvore ou com duas).
#   Os níveis 0 e 1 são listas de PERTO refeitas aqui (CPU) quando a câmera anda MOVER m, vira VIRAR ou o zoom muda
#   (um MultiMesh por modelo e nível; só as árvores NA FRENTE da câmera: o "corte pela visão"). Os VOXELS até ~400 m
#   também são duas listas da CPU (fino e grosso, refeitas a cada MOVER_V m); depois disso, os voxels grossos ficam em
#   MultiMesh FIXOS por bloco de BLOCO m (o HLOD; os chunks tiram da cena os de longe). Em todos, o shader decide cada
#   árvore pelo tamanho na tela (a GPU confere, como as instâncias do Nanite).
#   "centro" (a câmera) e "escala_px" (pixels por metro a 1 m) vão para os materiais a cada quadro; na sombra vale a
#   mesma conta (a árvore não muda de nível na sombra).
#   SOMBRA: a da completa é feita com a simplificada (lista "s", só sombra: o "shadow proxy"); a simplificada faz a
#   dela; os voxels não fazem sombra. Nos blocos fixos as árvores vão para a GPU em ordem de altura e só o começo da
#   lista que já pode ser voxel grosso naquela distância (MultiMesh.visible_instance_count, _contagens).
# COLISÃO: o tronco de cada árvore vira um obstáculo (caixa) da física perto do jogador (mundo/colisao_mundo.gd).
# Quem usa: mundo/cidade.gd (planta: lugares guardados + mundo/central_park.gd + mundo/pontos_turisticos.gd) e
# menu/aplicar_opcoes.gd ("Distância dos detalhes" muda os limiares e até onde vão os voxels).
# Mexa AQUI para: limiares, faixa do dissolve, alcance, vento, cor das folhas.

const DIR := "res://mundo/arvores/"
const BLOCO := 250.0                     # voxels: um MultiMesh por bloco
const CEL := 32.0                        # grade para achar as árvores perto
const MOVER := 4.0                       # as listas de perto são refeitas quando a câmera anda isso
const FOLGA := 8.0                       # ... e pegam a mais (cobre o andar até refazer)
const PX := [520.0, 220.0, 64.0]         # altura na tela (px) das trocas 0|1, 1|2 e 2|3 (720p, câmera do jogo: uma
                                         # árvore de 15 m troca a ~27 m, ~64 m e ~220 m)
const FAIXA := 0.08                      # o dissolve vai de limiar x (1 - FAIXA) a limiar x (1 + FAIXA) (sem o TAA da
                                         # Unreal o pontilhado aparece: faixa curta = poucas árvores trocando de cada vez)
const QUALIDADE := [1.7, 1.3, 1.0, 0.78] # por "Distância dos detalhes" (0..3): multiplica os limiares (maior = troca antes)
const ALCANCE := [650.0, 1000.0, 1500.0, 2200.0]      # até onde vão os voxels grossos (some com dissolve)
const PX_VENTO := 160.0                  # abaixo disso as folhas param de mexer
const K_FINO := 24                       # bolhas do voxel fino e do grosso (ferramentas/preparar_arvores_lod.gd)
const K_GROSSO := 8
const K_LONGE := 4                       # o de bem longe (blocos fixos: o "HLOD")
const CORTE_FAIXA := 40.0                # dissolve (m) entre os voxels grossos de perto e os de bem longe
# CORTE PELA VISÃO (como a Unreal descarta os grupos fora da câmera): as listas de perto só pegam as árvores na frente
# da câmera (o campo de visão + MARGEM_VISAO de cada lado) e as que estão a menos de PERTO_SEMPRE (a sombra delas
# pode cair na tela); a câmera virando VIRAR refaz as listas
const MARGEM_VISAO := 0.45               # rad (~26°)
const PERTO_SEMPRE := 24.0
const VIRAR := 0.2                       # rad (~11°)
const MOVER_V := 10.0                    # as listas de voxels de perto são refeitas quando a câmera anda isso
const FOLGA_V := 14.0
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

# os voxels de todos os modelos numa textura (6 linhas por modelo: fino [centro + raio], fino [cor + é folha],
# grosso, grosso, longe, longe; uma coluna por bolha)
static func tex_voxels() -> ImageTexture:
	if _tex_voxels != null:
		return _tex_voxels
	var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "voxels.json"))
	var lista := nomes()
	var img := Image.create(K_FINO, maxi(lista.size(), 1) * 6, false, Image.FORMAT_RGBAH)
	img.fill(Color(0, 0, 0, 0))
	if d is Dictionary:
		for m in lista.size():
			var e: Dictionary = d["modelos"].get(lista[m], {})
			for k in 3:
				var bolhas: Array = e.get(["fino", "grosso", "longe"][k], [])
				for i in mini(bolhas.size(), K_FINO):
					var v: Array = bolhas[i]
					img.set_pixel(i, m * 6 + k * 2, Color(float(v[0]), float(v[1]), float(v[2]), float(v[3])))
					img.set_pixel(i, m * 6 + k * 2 + 1, Color(float(v[4]), float(v[5]), float(v[6]), float(v[7])))
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
uniform float dist_corte = 0.0;
uniform float corte_faixa = 40.0;
uniform int lado_corte = 0;              // 1: some depois do corte (voxels grossos de perto) · 2: aparece depois (de longe)
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
	if (lado_corte > 0) {
		float s = smoothstep(dist_corte - corte_faixa, dist_corte, distance(o.xz, centro.xz));
		if (lado_corte == 1) {
			b *= 1.0 - s;
		} else {
			a *= s;
		}
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
# fica "redonda", de volume), recortado em "folhinhas" por ruído (a borda fica rendada e a cor varia: copa, não bola
# lisa). O tronco (folha < 0) é uma faixa em pé (sempre na vertical, virada para a câmera) com a normal de cilindro;
# os galhos das secas (folha = 0) são bolhas bem vazadas. A bolha i do modelo m vem da textura (linha m * 6 + "linha");
# bolha com raio 0 = não existe (o quadrado some).
const SHADER_VOXEL := """
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;
uniform sampler2D voxels : filter_nearest;
uniform int linha = 0;
""" + _LOD + """
varying flat vec2 lod;
varying flat vec4 cor;
varying flat float tipo;
varying vec2 q;
float hv(vec2 p) { p = mod(p, 4096.0); vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float rv(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hv(i), hv(i + vec2(1.0, 0.0)), f.x), mix(hv(i + vec2(0.0, 1.0)), hv(i + vec2(1.0, 1.0)), f.x), f.y); }
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 f = lod_fator(o, INSTANCE_CUSTOM.w);
	lod = f;
	q = UV * 2.0 - 1.0;
	cor = vec4(0.0);
	tipo = 1.0;
	VERTEX = vec3(0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	if (f.x > 0.0 && f.y > 0.0) {
		int m = int(INSTANCE_CUSTOM.x + 0.5);
		int i = int(UV2.x + 0.5);
		vec4 a = texelFetch(voxels, ivec2(i, m * 6 + linha), 0);
		if (a.w > 0.0) {
			vec4 b = texelFetch(voxels, ivec2(i, m * 6 + linha + 1), 0);
			vec3 c = (MODEL_MATRIX * vec4(a.xyz, 1.0)).xyz;
			float esc = length(MODEL_MATRIX[0].xyz);
			vec3 cv = (VIEW_MATRIX * vec4(c, 1.0)).xyz;
			tipo = b.a;
			if (b.a < -0.01) {
				// tronco: faixa em pé (o "em cima" do mundo visto da câmera)
				vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
				vec3 lado = cross(up, vec3(0.0, 0.0, 1.0));
				float ll = length(lado);
				lado = ll > 0.05 ? lado / ll : vec3(1.0, 0.0, 0.0);
				VERTEX = cv + lado * q.x * a.w * esc + up * q.y * (-b.a) * length(MODEL_MATRIX[1].xyz);
			} else {
				VERTEX = cv + vec3(q * a.w * esc, 0.0);
			}
			cor = vec4(b.rgb * mix(vec3(1.0), COLOR.rgb, clamp(b.a, 0.0, 1.0)), fract(float(i) * 0.137 + o.x * 0.0113 + o.z * 0.0071));
		}
	}
}
void fragment() {
	if (lod_some(lod, FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = cor.rgb;
	if (tipo < -0.01) {
		if (abs(q.x) > 0.92) {
			discard;
		}
		NORMAL = normalize(vec3(q.x, 0.0, sqrt(max(1.0 - q.x * q.x, 0.0))));
		c *= 0.8 + 0.25 * rv(vec2(q.x * 3.0, q.y * 6.0) + cor.a * 40.0);
	} else {
		float d2 = dot(q, q);
		vec2 g = q * 3.6 + cor.a * 53.0;
		float n1 = rv(g);
		float n2 = rv(g * 2.7 + 7.0);
		float folhas = n1 * 0.6 + n2 * 0.4;
		float vazado = tipo < 0.5 ? 0.3 : 0.0;              // galhos das secas: bem mais vazado
		if (d2 + (0.5 - folhas) * 0.75 + vazado > 0.82) {
			discard;
		}
		vec2 inc = (vec2(n1, n2) - 0.5) * 0.7;
		NORMAL = normalize(vec3(q + inc, sqrt(max(1.0 - d2, 0.0)) + 0.35));
		c *= 0.78 + 0.42 * n2;
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.12;
	BACKLIGHT = c * 0.3;
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

# a SOMBRA da completa: a malha simplificada desenhada só na sombra (o "shadow proxy" dos jogos AAA: no chão ninguém
# vê a diferença e custa ~1/4); mesmo shader da simplificada, com os limiares do nível 0
static func mat_sombra(casca: String, folha: String) -> ShaderMaterial:
	var nc := String(CASCAS.get(casca, "carvalho"))
	var nf := String(FOLHAS.get(folha, "carvalho"))
	var k := "sombra_%s_%s" % [nc, nf]
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _shader(SHADER_SIMPLES)
		m.set_shader_parameter("tex_casca", load(DIR + "texturas/casca_%s.jpg" % nc))
		m.set_shader_parameter("tex_folha", load(DIR + "texturas/folha_%s.png" % nf))
		m.set_shader_parameter("px_vento", PX_VENTO)
		_mats[k] = m
	return _mats[k]

# nivel: 2 = fino (de perto), 3 = grosso (de perto), 4 = de bem longe (os blocos fixos)
static func mat_voxel(nivel: int) -> ShaderMaterial:
	var k: String = {2: "voxel_fino", 3: "voxel_grosso", 4: "voxel_longe"}[nivel]
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _shader(SHADER_VOXEL)
		m.set_shader_parameter("voxels", tex_voxels())
		m.set_shader_parameter("linha", (nivel - 2) * 2)
		m.set_shader_parameter("lado_corte", {2: 0, 3: 1, 4: 2}[nivel])
		m.set_shader_parameter("corte_faixa", CORTE_FAIXA)
		_mats[k] = m
	return _mats[k]

# o nível de cada material (para os limiares): casca_/folha_ = 0, simples_ = 1, voxel_fino = 2, voxel_grosso = 3
static func _nivel_mat(k: String) -> int:
	if k.begins_with("casca_") or k.begins_with("folha_") or k.begins_with("sombra_"):
		return 0
	if k.begins_with("simples_"):
		return 1
	if k == "voxel_fino":
		return 2
	if k == "voxel_grosso" or k == "voxel_longe":
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
var _blocos_longe: Array = []             # [MultiMeshInstance3D, Rect2 do bloco, alturas em ordem, y médio]
var _voxel_perto: Array = []              # as 2 listas de voxels de perto (fino, grosso)
var _ult_v := Vector3(1.0e9, 0.0, 1.0e9)
var _raio_v := 0.0                        # até onde as listas de voxels de perto cobrem (m, no chão)
var _perto := {}                          # "nivel_modelo" -> MultiMeshInstance3D (níveis 0 e 1)
var _ult := Vector3(1.0e9, 0.0, 1.0e9)
var _ult_esc := 0.0
var _ult_frente := Vector2.ZERO
var frente := Vector2.ZERO                # para onde a câmera olha (no chão; zero = todas as direções)
var meia_visao := PI                      # metade do campo de visão na horizontal + a margem (rad)
var escala_px := 600.0                    # pixels de altura por metro a 1 m da câmera (resolução e campo de visão)
var qualidade: float = QUALIDADE[2]
var alcance: float = ALCANCE[2]
var longe: Array = []                     # MultiMeshInstance3D dos voxels (a cidade adota: os chunks cuidam)
var obstaculos := PackedFloat32Array()    # troncos no formato do mundo/colisao_mundo.gd (7 floats cada)
var contagem := {}                        # nome -> quantas (estatística e testes)
var sombra := true
var por_nivel := [0, 0, 0, 0]             # (testes) quantas árvores estão nas listas de perto de cada nível

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

# depois de plantar todas: os MultiMesh dos voxels GROSSOS de longe (um por bloco; quem chama adota os nós: os chunks
# cuidam) e as 2 listas de voxels de perto (fino e grosso, montadas aqui na CPU: _listas_voxel)
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
		var y_med := 0.0
		for i in idx:
			y_med += _pos[i].y
		y_med /= maxf(idx.size(), 1)
		# as árvores do bloco das mais baixas para as mais altas: numa distância só as mais baixas já viraram voxel
		# grosso, e só esse começo da lista vai para a GPU (_contagens)
		var ordem: Array = Array(idx)
		ordem.sort_custom(func(a, b): return _alt[a] < _alt[b])
		var buf := PackedFloat32Array()
		buf.resize(idx.size() * 20)
		var alts := PackedFloat32Array()
		var j := 0
		for i in ordem:
			for q in 20:
				buf[j + q] = _reg[i * 20 + q]
			j += 20
			alts.append(_alt[i])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = malha_voxel(K_LONGE)
		mm.instance_count = idx.size()
		mm.buffer = buf
		var mi := MultiMeshInstance3D.new()
		mi.name = "ArvoresLonge_%d_%d" % [k.x, k.y]
		mi.multimesh = mm
		mi.material_override = mat_voxel(4)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		longe.append(mi)
		_blocos_longe.append([mi, Rect2(k.x * BLOCO, k.y * BLOCO, BLOCO, BLOCO), alts, y_med])
	for grosso in [false, true]:
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.use_colors = true
		mm2.use_custom_data = true
		mm2.mesh = malha_voxel(K_GROSSO if grosso else K_FINO)
		var mi2 := MultiMeshInstance3D.new()
		mi2.name = "ArvoresVoxelPerto_" + ("g" if grosso else "f")
		mi2.multimesh = mm2
		mi2.material_override = mat_voxel(3 if grosso else 2)
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi2.visible = false
		add_child(mi2)
		_voxel_perto.append(mi2)
	_limiares()
	return longe

# "Distância dos detalhes" (0..3)
func aplicar_alcance(nivel: int) -> void:
	qualidade = QUALIDADE[clampi(nivel, 0, 3)]
	alcance = ALCANCE[clampi(nivel, 0, 3)]
	_limiares()
	_ult = Vector3(1.0e9, 0.0, 1.0e9)
	_ult_v = Vector3(1.0e9, 0.0, 1.0e9)

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
	for e in _blocos_longe:
		if is_instance_valid(e[0]):
			(e[0] as MultiMeshInstance3D).visibility_range_end = alcance + RAIO_BLOCO

# OS BLOCOS DE LONGE (como o "cull distance" e o HLOD da Unreal): o bloco que está inteiro dentro das listas de voxels
# de perto some (elas já desenham as árvores dele); nos outros, só vai para a GPU o começo da lista (as mais baixas)
# que pode já ser voxel grosso na distância do canto mais longe (MultiMesh.visible_instance_count)
const RAIO_BLOCO := BLOCO * 0.72 + 20.0
func _contagens(c: Vector3) -> void:
	var t2: float = PX[2] * qualidade
	var k_ini := t2 * (1.0 + FAIXA) / maxf(escala_px, 1.0)          # o grosso começa em d = altura / k_ini
	for e in _blocos_longe:
		var mi: MultiMeshInstance3D = e[0]
		if not is_instance_valid(mi):
			continue
		var r: Rect2 = e[1]
		var fx := maxf(absf(c.x - r.position.x), absf(c.x - r.end.x))
		var fz := maxf(absf(c.z - r.position.y), absf(c.z - r.end.y))
		var longe_h := sqrt(fx * fx + fz * fz)
		if longe_h + MOVER_V <= _raio_v - CORTE_FAIXA:
			mi.visible = false                                        # o bloco inteiro está antes do corte
			continue
		mi.visible = true
		var dy: float = absf(c.y - float(e[3])) + 25.0
		var alts: PackedFloat32Array = e[2]
		var n := alts.bsearch(sqrt(longe_h * longe_h + dy * dy) * k_ini, false)
		mi.multimesh.visible_instance_count = -1 if n >= alts.size() else n

# AS LISTAS DE VOXELS DE PERTO (até onde os voxels finos podem ir: ~400 m): na CPU, só as árvores na frente da câmera
# que estão (ou vão estar até a próxima vez) no nível de cada lista; refeitas quando a câmera anda MOVER_V m ou vira
func _listas_voxel(c: Vector3) -> void:
	_ult_v = c
	var t1: float = PX[1] * qualidade
	var t2: float = PX[2] * qualidade
	var kv_ini := escala_px / (t1 * (1.0 + FAIXA))       # o fino começa em d >= altura x kv_ini
	var kv_fim := escala_px / (t2 * (1.0 - FAIXA))       # ... e vai até d <= altura x kv_fim
	var kg_ini := escala_px / (t2 * (1.0 + FAIXA))       # o grosso começa em d >= altura x kg_ini
	var r := _alt_max * kv_fim + FOLGA_V
	_raio_v = r - FOLGA_V
	var r2 := r * r
	var cos_visao := cos(meia_visao)
	var com_visao := frente != Vector2.ZERO and meia_visao < PI
	var fino := PackedFloat32Array()
	var grosso := PackedFloat32Array()
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
				var dh2 := dx * dx + dz * dz
				if dh2 > r2:
					continue
				if com_visao and dh2 > PERTO_SEMPRE * PERTO_SEMPRE and (dx * frente.x + dz * frente.y) < cos_visao * sqrt(dh2):
					continue
				var h := _alt[i]
				var dy := p.y + h * 0.5 - c.y
				var d := sqrt(dh2 + dy * dy)
				if d >= h * kv_ini - FOLGA_V and d <= h * kv_fim + FOLGA_V:
					fino.append_array(_reg.slice(i * 20, i * 20 + 20))
				if d >= h * kg_ini - FOLGA_V:
					grosso.append_array(_reg.slice(i * 20, i * 20 + 20))
	por_nivel[2] = fino.size() / 20
	por_nivel[3] = grosso.size() / 20
	for nome_m in ["voxel_grosso", "voxel_longe"]:
		if _mats.has(nome_m):
			(_mats[nome_m] as ShaderMaterial).set_shader_parameter("dist_corte", _raio_v)
	var aabb := AABB(Vector3(c.x - r - 15.0, c.y - 200.0, c.z - r - 15.0), Vector3(2.0 * r + 30.0, 400.0, 2.0 * r + 30.0))
	for k in 2:
		if k >= _voxel_perto.size():
			break
		var mi: MultiMeshInstance3D = _voxel_perto[k]
		var buf: PackedFloat32Array = fino if k == 0 else grosso
		mi.visible = buf.size() > 0
		mi.multimesh.instance_count = buf.size() / 20
		if buf.size() > 0:
			mi.multimesh.buffer = buf
		mi.multimesh.custom_aabb = aabb
	_contagens(c)

func aplicar_sombra(ligada: bool) -> void:
	sombra = ligada
	for k in _perto:
		if String(k).begins_with("1_"):
			_perto[k].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ligada else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ult = Vector3(1.0e9, 0.0, 1.0e9)                     # as listas "s" (sombra da completa) entram/saem

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _var.is_empty():
		return
	var tela := get_viewport().get_visible_rect().size
	var fov := deg_to_rad(cam.fov)
	if cam.keep_aspect == Camera3D.KEEP_WIDTH:
		fov = 2.0 * atan(tan(fov * 0.5) * tela.y / maxf(tela.x, 1.0))
	escala_px = tela.y / (2.0 * tan(fov * 0.5))
	var hfov := 2.0 * atan(tan(fov * 0.5) * tela.x / maxf(tela.y, 1.0))
	meia_visao = minf(hfov * 0.5 + MARGEM_VISAO, PI)
	var f3 := -cam.global_transform.basis.z
	frente = Vector2(f3.x, f3.z).normalized() if Vector2(f3.x, f3.z).length() > 0.05 else Vector2.ZERO
	atualizar(cam.global_position)

# a câmera em "c": manda para os materiais e, se andou (ou o zoom mudou), refaz as listas de perto
func atualizar(c: Vector3, forcar := false) -> void:
	for k in _mats:
		var m = _mats[k]
		if m is ShaderMaterial and _nivel_mat(String(k)) >= 0:
			m.set_shader_parameter("centro", c)
			m.set_shader_parameter("escala_px", escala_px)
	var virou := frente != Vector2.ZERO and (_ult_frente == Vector2.ZERO or _ult_frente.angle_to(frente) > VIRAR or _ult_frente.angle_to(frente) < -VIRAR)
	if virou:
		_ult_frente = frente
	var zoom := absf(escala_px - _ult_esc) >= _ult_esc * 0.03
	if zoom:
		_ult_esc = escala_px
	if forcar or virou or zoom or Vector2(c.x - _ult_v.x, c.z - _ult_v.z).length() >= MOVER_V:
		_listas_voxel(c)
	if not forcar and not virou and not zoom and Vector2(c.x - _ult.x, c.z - _ult.z).length() < MOVER:
		return
	_ult = c
	# até onde vai cada lista (a mesma conta do shader, com a FOLGA de andar até a próxima vez)
	var t0: float = PX[0] * qualidade
	var t1: float = PX[1] * qualidade
	var k0 := escala_px / (t0 * (1.0 - FAIXA))        # nível 0: d <= altura x k0 (+ FOLGA)
	var k0b := escala_px / (t0 * (1.0 + FAIXA))       # nível 1 começa em d >= altura x k0b (- FOLGA)
	var k1 := escala_px / (t1 * (1.0 - FAIXA))        # nível 1 vai até d <= altura x k1 (+ FOLGA)
	var r := _alt_max * k1 + FOLGA
	var r2 := r * r
	var cos_visao := cos(meia_visao)
	var com_visao := frente != Vector2.ZERO and meia_visao < PI
	var listas := {}
	por_nivel[0] = 0
	por_nivel[1] = 0
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
				var dh2 := dx * dx + dz * dz
				if dh2 > r2:
					continue
				if com_visao and dh2 > PERTO_SEMPRE * PERTO_SEMPRE and (dx * frente.x + dz * frente.y) < cos_visao * sqrt(dh2):
					continue                             # atrás / do lado de fora da visão
				var h := _alt[i]
				var dy := p.y + h * 0.5 - c.y
				var d := sqrt(dh2 + dy * dy)
				var v := _var[i]
				if d <= h * k0 + FOLGA:
					var ch := "0_%d" % v
					if not listas.has(ch):
						listas[ch] = PackedFloat32Array()
					listas[ch].append_array(_reg.slice(i * 20, i * 20 + 20))
					por_nivel[0] += 1
					if sombra:
						var chs := "s_%d" % v
						if not listas.has(chs):
							listas[chs] = PackedFloat32Array()
						listas[chs].append_array(_reg.slice(i * 20, i * 20 + 20))
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
			var tipo_lista := String(ch).get_slice("_", 0)
			var nv := 0 if tipo_lista == "s" else int(tipo_lista)
			var v := int(String(ch).get_slice("_", 1))
			var e: Dictionary = _info[lista[v]]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			if tipo_lista == "s":
				var ams: ArrayMesh = malha_lod1(lista[v]).duplicate()
				ams.surface_set_material(0, mat_sombra(String(e["casca"]), String(e["folha"])))
				mm.mesh = ams
			elif nv == 0:
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
			mi.name = "ArvoresPerto%s_%s" % [tipo_lista, String(lista[v])]
			mi.multimesh = mm
			if tipo_lista == "s":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			elif nv == 0:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # a sombra é a da lista "s"
			else:
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
		if _perto[ch].visible and not String(ch).begins_with("s_"):
			n += _perto[ch].multimesh.instance_count
	return n
