extends Node3D
# ÁRVORES (1.20; 1.21: o sistema de detalhe no jeito da UNREAL ENGINE 5; 1.22: TODAS AS ÁRVORES NUMA CHAMADA DE
# DESENHO SÓ, estudos/ESTUDO_AAA.md 1.14): as árvores da cidade inteira (as 13 mil dos lugares guardados na 1.19 + o
# Central Park bem denso + as dos pontos turísticos).
# Modelos REALISTAS gerados pelo EZ-Tree (ferramentas/arvores_ez/, MIT; texturas CC0: mundo/arvores/texturas/LICENCA.txt),
# 24 variações (carvalho, freixo, olmo, álamo, pinheiro e secas):
#   mundo/arvores/modelos/<nome>.res  a árvore COMPLETA (casca + folhas) · ferramentas/preparar_arvores.gd
#   mundo/arvores/lod1/<nome>.res     a SIMPLIFICADA (~27% dos triângulos) · ferramentas/preparar_arvores_lod.gd
#   mundo/arvores/voxels.json         os VOXELS de cada árvore (24, 8 e 4 bolhas de folhagem/galho) · idem
#   mundo/arvores/geometria.res       a completa e a simplificada de todos os modelos numa TEXTURA, em CLUSTERS de
#   mundo/arvores/clusters.json       CLUSTER triângulos (onde começa cada um) · idem
#   mundo/arvores/texturas/camadas_cor.res / camadas_normal.res   as cascas e folhas (vira uma Texture2DArray) · idem
#   mundo/arvores/arvores.json        altura, raio da copa, raio do tronco, tipo...
# OS NÍVEIS (pelo TAMANHO DA ÁRVORE NA TELA, em pixels de altura, como o Nanite: muda com a resolução e o zoom):
#   0 COMPLETA      >= PX[0] px · folhas com vento · a sombra dela é feita com a simplificada ("shadow proxy")
#   1 SIMPLIFICADA  PX[1]..PX[0] · menos galhos e 1/4 das folhas (maiores); o vento vai sumindo · sombra
#   2 VOXELS        PX[2]..PX[1] · 24 bolhas de folhagem (as "voxels" do Nanite Foliage da 5.7)
#   3 VOXELS GROSSOS < PX[2] · 8 bolhas até ~400 m; depois, até o alcance, 4 bolhas (o "HLOD"), com dissolve na troca
#   As trocas são em DISSOLVE pontilhado (o mesmo ruído nos dois níveis, um ao contrário do outro).
# UMA CHAMADA DE DESENHO (1.22, o jeito do Nanite: "clusters" + a GPU busca os vértices):
#   Tudo é UM MultiMesh com UMA malha (CLUSTER triângulos "vazios": 3 x CLUSTER vértices sem posição) e UM material.
#   Cada instância é um pedaço de árvore ou um grupo de árvores em voxel (INSTANCE_CUSTOM.y = o tipo):
#     0/1  um CLUSTER da completa/simplificada de uma árvore: a transformação é a da árvore; o shader pega o vértice
#          VERTEX_ID do cluster INSTANCE_CUSTOM.x na textura da geometria (posição, normal, UV, camada da textura)
#     2    um cluster da simplificada que só aparece na SOMBRA (a sombra da completa)
#     3/4  um GRUPO de árvores em voxel (2 finas ou 8 grossas): os números delas estão na textura "lista" (refeita
#          aqui na CPU); a posição e a cor de cada árvore vêm da textura "arvs"
#     5    um GRUPO de até 16 árvores em voxel de bem longe: um pedaço seguido da textura "arvs" (as árvores ficam
#          lá em ordem de bloco de BLOCO m e, dentro do bloco, de altura: só o começo de cada bloco que já está no
#          tamanho dos voxels de longe vai para a GPU)
#   A CPU monta a lista de instâncias: as de perto quando a câmera anda MOVER m (ou vira VIRAR, ou o zoom muda), os
#   voxels a cada MOVER_V m; só o que está NA FRENTE da câmera (o "corte pela visão") e no tamanho certo. A GPU
#   confere cada árvore pelo tamanho na tela (o shader esconde quem não é daquele nível). A sombra do sol é
#   reconhecida pela projeção ortográfica: nela só vão as simplificadas.
# COLISÃO: o tronco de cada árvore vira um obstáculo (caixa) da física perto do jogador (mundo/colisao_mundo.gd).
# Quem usa: mundo/cidade.gd (planta: lugares guardados + mundo/central_park.gd + mundo/pontos_turisticos.gd) e
# menu/aplicar_opcoes.gd ("Distância dos detalhes" muda os limiares e até onde vão os voxels).
# Mexa AQUI para: limiares, faixa do dissolve, alcance, vento, cor das folhas.

const DIR := "res://mundo/arvores/"
const BLOCO := 250.0                     # os grupos de bem longe: por bloco
const CEL := 32.0                        # grade para achar as árvores perto
const MOVER := 4.0                       # as listas de perto são refeitas quando a câmera anda isso
const FOLGA := 8.0                       # ... e pegam a mais (cobre o andar até refazer)
const PX := [520.0, 220.0, 64.0]         # altura na tela (px) das trocas 0|1, 1|2 e 2|3 (720p, câmera do jogo: uma
                                         # árvore de 15 m troca a ~27 m, ~64 m e ~220 m)
const FAIXA := 0.08                      # o dissolve vai de limiar x (1 - FAIXA) a limiar x (1 + FAIXA) (sem o TAA da
                                         # Unreal o pontilhado aparece: faixa curta = poucas árvores trocando de cada vez)
const QUALIDADE := [1.7, 1.3, 1.0, 0.78] # por "Distância dos detalhes" (0..3): multiplica os limiares (maior = troca antes)
const ALCANCE := [650.0, 1000.0, 1500.0, 2200.0]      # até onde vão os voxels (some com dissolve)
const PX_VENTO := 160.0                  # abaixo disso as folhas param de mexer
const K_FINO := 24                       # bolhas do voxel fino, do grosso e do de bem longe (ferramentas/preparar_arvores_lod.gd)
const K_GROSSO := 8
const K_LONGE := 4
const CORTE_FAIXA := 40.0                # dissolve (m) entre os voxels grossos de perto e os de bem longe
# CORTE PELA VISÃO (como a Unreal descarta os grupos fora da câmera): as listas só pegam as árvores na frente da câmera
# (o campo de visão + MARGEM_VISAO de cada lado) e as que estão a menos de PERTO_SEMPRE (a sombra delas pode cair na
# tela); a câmera virando VIRAR refaz as listas
const MARGEM_VISAO := 0.45               # rad (~26°)
const PERTO_SEMPRE := 24.0
const VIRAR := 0.2                       # rad (~11°)
const MOVER_V := 10.0                    # as listas de voxels são refeitas quando a câmera anda isso
const FOLGA_V := 14.0
const TRONCO_ALTURA := 4.0               # altura da caixa de colisão do tronco
# A CHAMADA ÚNICA
const CLUSTER := 128                     # triângulos por cluster (e por grupo de voxels: 64 bolhas)
const GEO_W := 1024                      # largura (texels) das texturas de dados
const LISTA_W := 1024
const LISTA_H := 16                      # até 16 mil árvores nas listas de voxels de perto
const CAMADAS := ["casca_carvalho", "casca_betula", "casca_pinheiro", "folha_freixo", "folha_alamo", "folha_carvalho",
	"folha_pinheiro"]                    # as camadas da Texture2DArray (as 3 primeiras têm normal)
const POR_GRUPO := {3: 2, 4: 8, 5: 16}   # árvores por grupo de voxels (64 bolhas / bolhas por árvore)

# ---------------------------------------------------------------------------------------------------------------
# MODELOS (static: os mesmos para todo mundo; carregados uma vez)
# ---------------------------------------------------------------------------------------------------------------
static var _info := {}                   # nome -> {tipo, seca, altura, raio_copa, raio_tronco, lado, casca, folha, cor_folha}
static var _nomes: Array = []
static var _malhas := {}
static var _tex_voxels: ImageTexture = null
static var _tex_geo: ImageTexture = null
static var _clusters := {}               # nome -> [[primeiro, quantos] da completa, [..] da simplificada]
static var _mat: ShaderMaterial = null

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

static func cor_folha(nome: String) -> Color:
	var c = info()[nome].get("cor_folha", "ffffff")
	return Color.html(String(c))

static func clusters() -> Dictionary:
	if _clusters.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "clusters.json"))
		if d is Dictionary:
			_clusters = d["modelos"]
	return _clusters

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

# (o servidor dedicado não desenha: a exportação dele não leva a geometria nem as camadas, e aqui fica sem elas)
static func tex_geo() -> ImageTexture:
	if _tex_geo == null and ResourceLoader.exists(DIR + "geometria.res"):
		var img: Image = load(DIR + "geometria.res")
		_tex_geo = ImageTexture.create_from_image(img)
	return _tex_geo

# ---------------------------------------------------------------------------------------------------------------
# O MATERIAL ÚNICO
# ---------------------------------------------------------------------------------------------------------------
const SHADER := """
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;
uniform sampler2D geo : filter_nearest;
uniform sampler2D arvs : filter_nearest;
uniform sampler2D lista : filter_nearest;
uniform sampler2D voxels : filter_nearest;
uniform sampler2DArray cores : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray normais : filter_linear_mipmap, repeat_enable;
uniform vec3 centro = vec3(0.0, -100000.0, 0.0);
uniform float escala_px = 600.0;
uniform vec3 limiares = vec3(520.0, 220.0, 64.0);
uniform float faixa = 0.08;
uniform float alcance = 1500.0;
uniform float dist_corte = 0.0;
uniform float corte_faixa = 40.0;
uniform float px_vento = 160.0;
global uniform float vento;
varying flat vec2 lod;
varying flat float tipo;
varying flat float camada;
varying flat vec4 cor;
varying vec2 uvq;
varying float alt_v;
float lod_px(vec3 o, float altura) {
	return altura * escala_px / max(distance(o + vec3(0.0, altura * 0.5, 0.0), centro), 0.5);
}
// o nível 0..3: abaixo de pmin (com a faixa) some, acima de pmax some (o vizinho fica com o resto)
vec2 lod_fator(vec3 o, float altura, int nivel) {
	float px = lod_px(o, altura);
	float pmin = nivel == 0 ? limiares.x : (nivel == 1 ? limiares.y : (nivel == 2 ? limiares.z : 0.0));
	float pmax = nivel == 0 ? 0.0 : (nivel == 1 ? limiares.x : (nivel == 2 ? limiares.y : limiares.z));
	float a = pmin > 0.0 ? smoothstep(pmin * (1.0 - faixa), pmin * (1.0 + faixa), px) : 1.0;
	float b = pmax > 0.0 ? 1.0 - smoothstep(pmax * (1.0 - faixa), pmax * (1.0 + faixa), px) : 1.0;
	if (nivel == 3) {
		a *= 1.0 - smoothstep(alcance * 0.88, alcance, distance(o, centro));
	}
	return vec2(a, b);
}
bool lod_some(vec2 f, vec2 frag) {
	float t = clamp(fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715)))), 0.002, 0.998);
	return (f.x < 1.0 && f.x <= t) || (f.y < 1.0 && f.y <= 1.0 - t);
}
vec4 busca(sampler2D t, int i) {
	return texelFetch(t, ivec2(i % 1024, i / 1024), 0);
}
vec3 oct(vec2 e) {
	vec3 v = vec3(e.x, 1.0 - abs(e.x) - abs(e.y), e.y);
	if (v.y < 0.0) {
		v.xz = vec2((1.0 - abs(e.y)) * (e.x >= 0.0 ? 1.0 : -1.0), (1.0 - abs(e.x)) * (e.y >= 0.0 ? 1.0 : -1.0));
	}
	return normalize(v);
}
float hv(vec2 p) { p = mod(p, 4096.0); vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float rv(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hv(i), hv(i + vec2(1.0, 0.0)), f.x), mix(hv(i + vec2(0.0, 1.0)), hv(i + vec2(1.0, 1.0)), f.x), f.y); }
void vertex() {
	bool sombra = PROJECTION_MATRIX[3][3] > 0.5;              // a sombra do sol é ortográfica (a câmera não)
	int kind = int(INSTANCE_CUSTOM.y + 0.5);
	VERTEX = vec3(0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 1.0, 0.0);
	lod = vec2(1.0);
	tipo = 0.0;
	camada = 0.0;
	cor = vec4(0.0);
	uvq = vec2(0.0);
	alt_v = 0.0;
	if (kind <= 2) {
		// ---- um CLUSTER da completa / simplificada ----
		bool mostra = kind == 1 || (kind == 0 && !sombra) || (kind == 2 && sombra);
		vec3 o = MODEL_MATRIX[3].xyz;
		float altura = INSTANCE_CUSTOM.w;
		vec2 f = mostra ? lod_fator(o, altura, kind == 1 ? 1 : 0) : vec2(0.0);
		int vid = int(INSTANCE_CUSTOM.x + 0.5) * 384 + VERTEX_ID;
		vec4 t0 = f.x > 0.0 && f.y > 0.0 ? busca(geo, vid * 2) : vec4(-1.0);
		if (t0.w > -0.5) {
			vec4 t1 = busca(geo, vid * 2 + 1);
			vec3 p = t0.xyz;
			if (t0.w > 2.5) {
				float fv = smoothstep(px_vento * 0.7, px_vento, lod_px(o, altura));
				if (fv > 0.0) {
					float fase = o.x * 0.37 + o.z * 0.23;
					float forca = (0.25 + vento) * clamp(p.y * 0.08, 0.0, 1.5) * fv;
					p.x += (sin(TIME * 1.9 + fase + p.y * 0.6) * 0.05 + sin(TIME * 0.7 + fase) * 0.09) * forca;
					p.z += cos(TIME * 1.6 + fase * 1.3 + p.x * 0.5) * 0.05 * forca;
				}
			}
			vec3 w = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
			VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
			vec3 nw = normalize(mat3(MODEL_MATRIX) * oct(t1.xy));
			NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
			vec3 tw = abs(nw.y) < 0.99 ? normalize(cross(vec3(0.0, 1.0, 0.0), nw)) : vec3(1.0, 0.0, 0.0);
			TANGENT = normalize((VIEW_MATRIX * vec4(tw, 0.0)).xyz);
			BINORMAL = normalize((VIEW_MATRIX * vec4(cross(nw, tw), 0.0)).xyz);
			lod = f;
			camada = t0.w;
			cor = COLOR;
			uvq = t1.zw;
			alt_v = p.y;
		}
	} else if (!sombra) {
		// ---- um GRUPO de árvores em voxel ----
		int por = kind == 3 ? 24 : (kind == 4 ? 8 : 4);
		int linha = kind == 3 ? 0 : (kind == 4 ? 2 : 4);
		int s = VERTEX_ID / 6;
		int canto = VERTEX_ID - s * 6;
		int tl = s / por;
		int sp = s - tl * por;
		int n = int(INSTANCE_CUSTOM.z + 0.5);
		if (tl < n) {
			int ini = int(INSTANCE_CUSTOM.x + 0.5);
			int ti = kind == 5 ? ini + tl : int(busca(lista, ini + tl).r + 0.5);
			vec4 r0 = busca(arvs, ti * 5);
			vec4 r1 = busca(arvs, ti * 5 + 1);
			vec4 r2 = busca(arvs, ti * 5 + 2);
			vec4 cc = busca(arvs, ti * 5 + 3);
			vec4 cu = busca(arvs, ti * 5 + 4);
			vec3 o = vec3(r0.w, r1.w, r2.w);
			float altura = cu.w;
			vec2 f = lod_fator(o, altura, kind == 3 ? 2 : 3);
			if (kind >= 4) {
				float sd = smoothstep(dist_corte - corte_faixa, dist_corte, distance(o.xz, centro.xz));
				if (kind == 4) {
					f.y *= 1.0 - sd;                          // os grossos de perto somem depois do corte
				} else {
					f.x *= sd;                                // os de bem longe aparecem depois do corte
				}
			}
			int m = int(cu.x + 0.5);
			vec4 a = texelFetch(voxels, ivec2(sp, m * 6 + linha), 0);
			if (f.x > 0.0 && f.y > 0.0 && a.w > 0.0) {
				vec4 b = texelFetch(voxels, ivec2(sp, m * 6 + linha + 1), 0);
				mat4 mm = mat4(vec4(r0.x, r1.x, r2.x, 0.0), vec4(r0.y, r1.y, r2.y, 0.0), vec4(r0.z, r1.z, r2.z, 0.0), vec4(o, 1.0));
				vec3 c = (mm * vec4(a.xyz, 1.0)).xyz;
				float esc = length(vec3(r0.x, r1.x, r2.x));
				vec3 cv = (VIEW_MATRIX * vec4(c, 1.0)).xyz;
				int ci = canto == 0 ? 0 : (canto == 1 ? 2 : (canto == 2 ? 1 : (canto == 3 ? 0 : (canto == 4 ? 3 : 2))));
				vec2 q = vec2(ci == 1 || ci == 2 ? 1.0 : -1.0, ci >= 2 ? 1.0 : -1.0);
				if (b.a < -0.01) {
					vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
					vec3 lado = cross(up, vec3(0.0, 0.0, 1.0));
					float ll = length(lado);
					lado = ll > 0.05 ? lado / ll : vec3(1.0, 0.0, 0.0);
					VERTEX = cv + lado * q.x * a.w * esc + up * q.y * (-b.a) * length(vec3(r0.y, r1.y, r2.y));
				} else {
					VERTEX = cv + vec3(q * a.w * esc, 0.0);
				}
				lod = f;
				tipo = 1.0;
				camada = b.a;
				cor = vec4(b.rgb * mix(vec3(1.0), cc.rgb, clamp(b.a, 0.0, 1.0)), fract(float(sp) * 0.137 + o.x * 0.0113 + o.z * 0.0071));
				uvq = q;
			}
		}
	}
}
void fragment() {
	if (lod_some(lod, FRAGCOORD.xy)) {
		discard;
	}
	vec3 c;
	float alfa = 1.0;
	NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	if (tipo < 0.5) {
		vec4 t = texture(cores, vec3(uvq, camada));
		if (camada < 2.5) {
			c = t.rgb * mix(vec3(1.0), cor.rgb, 0.25);
			NORMAL_MAP = texture(normais, vec3(uvq, camada)).rgb;
			ROUGHNESS = 0.92;
			SPECULAR = 0.15;
		} else {
			c = t.rgb * cor.rgb * (0.82 + 0.18 * clamp(alt_v * 0.08, 0.0, 1.0));
			alfa = t.a;
			ROUGHNESS = 0.8;
			SPECULAR = 0.2;
			BACKLIGHT = c * 0.35;
		}
	} else {
		c = cor.rgb;
		vec2 q = uvq;
		if (camada < -0.01) {
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
			float vazado = camada < 0.5 ? 0.3 : 0.0;
			if (d2 + (0.5 - folhas) * 0.75 + vazado > 0.82) {
				discard;
			}
			vec2 inc = (vec2(n1, n2) - 0.5) * 0.7;
			NORMAL = normalize(vec3(q + inc, sqrt(max(1.0 - d2, 0.0)) + 0.35));
			c *= 0.78 + 0.42 * n2;
		}
		ROUGHNESS = 0.85;
		SPECULAR = 0.12;
		BACKLIGHT = c * 0.3;
	}
	ALBEDO = c;
	ALPHA = alfa;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

const CASCAS := {"oak": "carvalho", "birch": "betula", "pine": "pinheiro", "willow": "carvalho"}
const FOLHAS := {"ash": "freixo", "aspen": "alamo", "oak": "carvalho", "pine": "pinheiro"}

static func material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("geo", tex_geo())
		_mat.set_shader_parameter("voxels", tex_voxels())
		_mat.set_shader_parameter("cores", _camadas("cor"))
		_mat.set_shader_parameter("normais", _camadas("normal"))
		_mat.set_shader_parameter("px_vento", PX_VENTO)
		_mat.set_shader_parameter("faixa", FAIXA)
		_mat.set_shader_parameter("corte_faixa", CORTE_FAIXA)
	return _mat

# as texturas de casca e folha numa Texture2DArray (a pilha 512 x 512n vira n camadas com mipmaps)
static func _camadas(qual: String) -> Texture2DArray:
	if not ResourceLoader.exists(DIR + "texturas/camadas_%s.res" % qual):
		return null
	var pilha: Image = load(DIR + "texturas/camadas_%s.res" % qual)
	var lado := pilha.get_width()
	var imgs: Array[Image] = []
	for i in pilha.get_height() / lado:
		var im := pilha.get_region(Rect2i(0, i * lado, lado, lado))
		im.generate_mipmaps()
		imgs.append(im)
	var t := Texture2DArray.new()
	t.create_from_images(imgs)
	return t

# a malha única: CLUSTER triângulos sem posição (o shader monta tudo pelo VERTEX_ID)
static var _malha_cluster: ArrayMesh = null
static func malha_cluster() -> ArrayMesh:
	if _malha_cluster == null:
		var vs := PackedVector3Array()
		vs.resize(CLUSTER * 3)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vs
		_malha_cluster = ArrayMesh.new()
		_malha_cluster.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_malha_cluster.custom_aabb = AABB(Vector3(-12.0, -1.0, -12.0), Vector3(24.0, 28.0, 24.0))
	return _malha_cluster

# ---------------------------------------------------------------------------------------------------------------
# AS ÁRVORES PLANTADAS
# ---------------------------------------------------------------------------------------------------------------
var _var := PackedInt32Array()            # índice do modelo (ordem de nomes())
var _pos := PackedVector3Array()
var _alt := PackedFloat32Array()          # altura de verdade (já com a escala)
var _reg := PackedFloat32Array()          # 20 floats por árvore: transform (12) + cor (4) + custom (4: modelo, 0, 0, altura)
var _grade := {}                          # Vector2i -> PackedInt32Array
var _alt_max := 1.0
var _ord := PackedInt32Array()            # árvore -> posição dela na textura "arvs" (ordem de bloco e altura)
var _blocos: Array = []                   # [Rect2, primeira (em "arvs"), quantas, alturas em ordem, y médio]
var unica: MultiMeshInstance3D = null     # A chamada de desenho de todas as árvores
var _tex_lista: ImageTexture = null
var _buf_perto := PackedFloat32Array()    # instâncias da completa/simplificada (refeitas a cada MOVER m)
var _buf_voxel := PackedFloat32Array()    # instâncias dos grupos de voxels (a cada MOVER_V m)
var _ult := Vector3(1.0e9, 0.0, 1.0e9)
var _ult_v := Vector3(1.0e9, 0.0, 1.0e9)
var _ult_esc := 0.0
var _ult_frente := Vector2.ZERO
var _raio_v := 0.0                        # até onde as listas de voxels de perto cobrem (m, no chão)
var frente := Vector2.ZERO                # para onde a câmera olha (no chão; zero = todas as direções)
var meia_visao := PI                      # metade do campo de visão na horizontal + a margem (rad)
var escala_px := 600.0                    # pixels de altura por metro a 1 m da câmera (resolução e campo de visão)
var qualidade: float = QUALIDADE[2]
var alcance: float = ALCANCE[2]
var longe: Array = []                     # (1.22: vazio; a cidade não adota nada: tudo é a "unica")
var obstaculos := PackedFloat32Array()    # troncos no formato do mundo/colisao_mundo.gd (7 floats cada)
var contagem := {}                        # nome -> quantas (estatística e testes)
var sombra := true
var por_nivel := [0, 0, 0, 0]             # (testes) árvores na completa, simplificada, voxels finos, voxels grossos de perto
var instancias := 0                       # (testes) instâncias (clusters + grupos) na chamada única

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

# depois de plantar todas: a textura "arvs" (as árvores em ordem de bloco e altura), os blocos e a chamada única
func montar() -> Array:
	var blocos := {}
	for i in _var.size():
		var p := _pos[i]
		var k := Vector2i(floori(p.x / BLOCO), floori(p.z / BLOCO))
		if not blocos.has(k):
			blocos[k] = []
		blocos[k].append(i)
	var ordem := PackedInt32Array()
	_ord.resize(_var.size())
	for k in blocos:
		var lista: Array = blocos[k]
		lista.sort_custom(func(a, b): return _alt[a] < _alt[b])
		var alts := PackedFloat32Array()
		var y_med := 0.0
		for i in lista:
			alts.append(_alt[i])
			y_med += _pos[i].y
		_blocos.append([Rect2(k.x * BLOCO, k.y * BLOCO, BLOCO, BLOCO), ordem.size(), lista.size(), alts, y_med / maxf(lista.size(), 1)])
		for i in lista:
			_ord[i] = ordem.size()
			ordem.append(i)
	var arvs := PackedFloat32Array()
	arvs.resize(ordem.size() * 20)
	for n in ordem.size():
		var i := ordem[n]
		for q in 20:
			arvs[n * 20 + q] = _reg[i * 20 + q]
	var linhas := maxi(int(ceil(float(arvs.size() / 4) / GEO_W)), 1)
	arvs.resize(linhas * GEO_W * 4)
	var img := Image.create_from_data(GEO_W, linhas, false, Image.FORMAT_RGBAF, arvs.to_byte_array())
	var lista_img := Image.create(LISTA_W, LISTA_H, false, Image.FORMAT_RF)
	_tex_lista = ImageTexture.create_from_image(lista_img)
	var mat := material()
	mat.set_shader_parameter("arvs", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("lista", _tex_lista)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = malha_cluster()
	mm.custom_aabb = AABB(Vector3(-20000.0, -500.0, -20000.0), Vector3(40000.0, 1500.0, 40000.0))
	unica = MultiMeshInstance3D.new()
	unica.name = "ArvoresUnica"
	unica.multimesh = mm
	unica.material_override = mat
	unica.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(unica)
	_limiares()
	return longe

# "Distância dos detalhes" (0..3)
func aplicar_alcance(nivel: int) -> void:
	qualidade = QUALIDADE[clampi(nivel, 0, 3)]
	alcance = ALCANCE[clampi(nivel, 0, 3)]
	_limiares()
	_ult = Vector3(1.0e9, 0.0, 1.0e9)
	_ult_v = Vector3(1.0e9, 0.0, 1.0e9)

func _limiares() -> void:
	var m := material()
	m.set_shader_parameter("limiares", Vector3(PX[0], PX[1], PX[2]) * qualidade)
	m.set_shader_parameter("alcance", alcance)

func aplicar_sombra(ligada: bool) -> void:
	sombra = ligada
	if unica != null:
		unica.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ligada else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ult = Vector3(1.0e9, 0.0, 1.0e9)

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _var.is_empty() or unica == null:
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

# a câmera em "c": manda para o material e, se andou (ou virou, ou o zoom mudou), refaz as instâncias
func atualizar(c: Vector3, forcar := false) -> void:
	var m := material()
	m.set_shader_parameter("centro", c)
	m.set_shader_parameter("escala_px", escala_px)
	var virou := frente != Vector2.ZERO and (_ult_frente == Vector2.ZERO or absf(_ult_frente.angle_to(frente)) > VIRAR)
	if virou:
		_ult_frente = frente
	var zoom := absf(escala_px - _ult_esc) >= _ult_esc * 0.03
	if zoom:
		_ult_esc = escala_px
	var mudou := false
	if forcar or virou or zoom or Vector2(c.x - _ult_v.x, c.z - _ult_v.z).length() >= MOVER_V:
		_voxels(c)
		mudou = true
	if forcar or virou or zoom or Vector2(c.x - _ult.x, c.z - _ult.z).length() >= MOVER:
		_perto(c)
		mudou = true
	if mudou and unica != null:
		var tudo := _buf_perto + _buf_voxel
		instancias = tudo.size() / 20
		unica.multimesh.instance_count = instancias
		if instancias > 0:
			unica.multimesh.buffer = tudo

# na frente da câmera? (as de perto de PERTO_SEMPRE ficam sempre: a sombra delas pode cair na tela)
func _na_visao(dx: float, dz: float, dh2: float, cos_visao: float) -> bool:
	if frente == Vector2.ZERO or meia_visao >= PI or dh2 <= PERTO_SEMPRE * PERTO_SEMPRE:
		return true
	return (dx * frente.x + dz * frente.y) >= cos_visao * sqrt(dh2)

# a completa e a simplificada: um registro por CLUSTER (a transformação da árvore, o número do cluster e o tipo)
func _perto(c: Vector3) -> void:
	_ult = c
	var t0: float = PX[0] * qualidade
	var t1: float = PX[1] * qualidade
	var k0 := escala_px / (t0 * (1.0 - FAIXA))        # completa: d <= altura x k0 (+ FOLGA)
	var k0b := escala_px / (t0 * (1.0 + FAIXA))       # simplificada começa em d >= altura x k0b (- FOLGA)
	var k1 := escala_px / (t1 * (1.0 - FAIXA))        # ... e vai até d <= altura x k1 (+ FOLGA)
	var r := _alt_max * k1 + FOLGA
	var r2 := r * r
	var cos_visao := cos(meia_visao)
	var cl := clusters()
	var lista := nomes()
	_b = PackedFloat32Array()
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
				if dh2 > r2 or not _na_visao(dx, dz, dh2, cos_visao):
					continue
				var h := _alt[i]
				var dy := p.y + h * 0.5 - c.y
				var d := sqrt(dh2 + dy * dy)
				var em0 := d <= h * k0 + FOLGA
				var em1 := d >= h * k0b - FOLGA and d <= h * k1 + FOLGA
				if not em0 and not em1:
					continue
				var faixas: Array = cl.get(lista[_var[i]], [])
				if faixas.size() < 2:
					continue
				var rec := _reg.slice(i * 20, i * 20 + 20)
				if em0:
					por_nivel[0] += 1
					_clusters_de(rec, faixas[0], 0.0)
					if sombra:
						_clusters_de(rec, faixas[1], 2.0)           # a sombra da completa: a simplificada
				if em1:
					por_nivel[1] += 1
					_clusters_de(rec, faixas[1], 1.0)
	_buf_perto = _b

var _b := PackedFloat32Array()            # (a lista sendo montada)
func _clusters_de(rec: PackedFloat32Array, faixa_c: Array, tipo: float) -> void:
	var r := rec.duplicate()
	r[17] = tipo
	var ini := int(faixa_c[0])
	for k in int(faixa_c[1]):
		r[16] = float(ini + k)
		_b.append_array(r)

# os GRUPOS de voxels: os de perto (fino e grosso; a lista de árvores vai na textura "lista") e os de bem longe (os
# começos dos blocos da textura "arvs")
func _voxels(c: Vector3) -> void:
	_ult_v = c
	var t1: float = PX[1] * qualidade
	var t2: float = PX[2] * qualidade
	var kv_ini := escala_px / (t1 * (1.0 + FAIXA))       # o fino começa em d >= altura x kv_ini
	var kv_fim := escala_px / (t2 * (1.0 - FAIXA))       # ... e vai até d <= altura x kv_fim
	var kg_ini := escala_px / (t2 * (1.0 + FAIXA))       # o grosso começa em d >= altura x kg_ini
	var r := _alt_max * kv_fim + FOLGA_V
	_raio_v = r - FOLGA_V
	material().set_shader_parameter("dist_corte", _raio_v)
	var r2 := r * r
	var cos_visao := cos(meia_visao)
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
				if dh2 > r2 or not _na_visao(dx, dz, dh2, cos_visao):
					continue
				var h := _alt[i]
				var dy := p.y + h * 0.5 - c.y
				var d := sqrt(dh2 + dy * dy)
				if d >= h * kv_ini - FOLGA_V and d <= h * kv_fim + FOLGA_V:
					fino.append(float(_ord[i]))
				if d >= h * kg_ini - FOLGA_V:
					grosso.append(float(_ord[i]))
	# a lista (fino e depois grosso) e os grupos
	var lista := fino + grosso
	if lista.size() > LISTA_W * LISTA_H:
		lista.resize(LISTA_W * LISTA_H)
	por_nivel[2] = fino.size()
	por_nivel[3] = grosso.size()
	var buf := PackedFloat32Array()
	var rec := PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0])
	for parte in 2:
		var ini := 0 if parte == 0 else fino.size()
		var n := mini(fino.size() if parte == 0 else grosso.size(), lista.size() - ini)
		var por: int = POR_GRUPO[3 + parte]
		rec[17] = float(3 + parte)
		var g := 0
		while g < n:
			rec[16] = float(ini + g)
			rec[18] = float(mini(por, n - g))
			buf.append_array(rec)
			g += por
	if lista.size() > 0:
		var dados := lista.duplicate()
		dados.resize(LISTA_W * LISTA_H)
		_tex_lista.update(Image.create_from_data(LISTA_W, LISTA_H, false, Image.FORMAT_RF, dados.to_byte_array()))
	# os de bem longe: blocos depois do corte, até o alcance, na frente da câmera; só o começo de cada bloco (as mais
	# baixas) que já está no tamanho dos voxels grossos no canto mais longe do bloco
	rec[17] = 5.0
	var por_l: int = POR_GRUPO[5]
	var k_ini := t2 * (1.0 + FAIXA) / maxf(escala_px, 1.0)
	for b in _blocos:
		var ret: Rect2 = b[0]
		var fx := maxf(absf(c.x - ret.position.x), absf(c.x - ret.end.x))
		var fz := maxf(absf(c.z - ret.position.y), absf(c.z - ret.end.y))
		var longe_h := sqrt(fx * fx + fz * fz)
		if longe_h + MOVER_V <= _raio_v - CORTE_FAIXA:
			continue                                        # o bloco inteiro está antes do corte
		var px_ := clampf(c.x, ret.position.x, ret.end.x)
		var pz_ := clampf(c.z, ret.position.y, ret.end.y)
		var perto_h := Vector2(px_ - c.x, pz_ - c.z).length()
		if perto_h > alcance + MOVER_V:
			continue
		var cen := ret.get_center()
		var dcx := cen.x - c.x
		var dcz := cen.y - c.z
		var dc := sqrt(dcx * dcx + dcz * dcz)
		var raio_b := BLOCO * 0.72
		if frente != Vector2.ZERO and meia_visao < PI and dc > raio_b:
			var ang := acos(clampf((dcx * frente.x + dcz * frente.y) / dc, -1.0, 1.0))
			if ang > meia_visao + asin(clampf(raio_b / dc, 0.0, 1.0)):
				continue
		var dy: float = absf(c.y - float(b[4])) + 25.0
		var alts: PackedFloat32Array = b[3]
		var n := alts.bsearch(sqrt(longe_h * longe_h + dy * dy) * k_ini, false)
		var ini: int = b[1]
		var g := 0
		while g < n:
			rec[16] = float(ini + g)
			rec[18] = float(mini(por_l, n - g))
			buf.append_array(rec)
			g += por_l
	_buf_voxel = buf

# quantas árvores de verdade (completas + simplificadas) estão nas listas de perto agora (testes)
func perto_agora() -> int:
	return por_nivel[0] + por_nivel[1]
