extends RefCounted
# MATERIAIS DA CIDADE (shaders feitos para rodar leve no celular, renderizador Compatibility):
#   mar/lagos ...... ondas animadas (normal map), reflexo do céu, brilho do sol, cor rasa perto da costa e espuma
#   terra .......... chão urbano com variação + praias de areia junto da água
#   parque ......... grama com manchas
#   asfalto ........ asfalto com desgaste · calçada com placas · faixas (branco/amarelo)
#   prédios ........ janelas por andar, térreo com lojas, platibanda, tipos: tijolo, pedra, concreto e vidro
# Todos os pisos usam "camada": um pequeno empurrão na profundidade para as camadas (mar, terra, parque,
# calçada, asfalto, faixas) não piscarem umas por cima das outras ao longe.
# Mexa AQUI para: cores e aparência do mar, chão, ruas e prédios.

# ---------- trecho comum: camada + ruído ----------
const COMUM := """
uniform float camada = 0.0;
varying vec3 wp;
// "aleatório" sem sin(): sin() de número grande (coordenadas de milhares de metros) perde a precisão na placa do
// celular (Mali) e o resultado vira quase constante -> bolinhas iguais em grade e listras. Números pequenos (mod) e
// só multiplicações = igual no celular e no PC.
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
float fbm(vec2 p) { return ruido(p) * 0.55 + ruido(p * 2.3) * 0.3 + ruido(p * 5.1) * 0.15; }
"""
const VERTICE_CAMADA := """
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// empurra a camada um tiquinho para a frente na profundidade (testado: + = por cima neste renderizador)
	// 0.82: 3e-7 -> 1.2e-6 (a profundidade de 24 bits do celular não separava as camadas: piscava)
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z += camada * 1.2e-6 * POSITION.w;
}
"""

const AGUA := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform sampler2D mascara : filter_linear_mipmap;
uniform sampler2D ondas_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ondas_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 mundo = vec2(11000.0, 8600.0);
uniform vec3 cor_funda : source_color = vec3(0.035, 0.11, 0.15);
uniform vec3 cor_rasa : source_color = vec3(0.10, 0.34, 0.36);
uniform vec3 cor_ceu : source_color = vec3(0.95, 0.68, 0.48);
uniform float completa = 1.0;            // Opções › Água: 0 = simples (sem ondas e espuma)
""" + COMUM + VERTICE_CAMADA + """
void fragment() {
	vec2 uv = (wp.xz + mundo) / (2.0 * mundo);
	float raso = textureLod(mascara, uv, 3.2).r;          // perto da terra (largo)
	float costa = textureLod(mascara, uv, 1.2).r;         // bem na beira
	vec2 t = vec2(TIME * 0.018, TIME * 0.011);
	vec3 na = texture(ondas_a, wp.xz / 70.0 + t).rgb;
	vec3 nb = texture(ondas_b, wp.xz / 23.0 - t * 1.9).rgb;
	float dist = length(wp - CAMERA_POSITION_WORLD);
	NORMAL_MAP = normalize(mix(na, nb, 0.45));
	NORMAL_MAP_DEPTH = mix(0.9, 0.25, clamp(dist / 2500.0, 0.0, 1.0)) * completa;
	vec3 cor = mix(cor_funda, cor_rasa, smoothstep(0.04, 0.55, raso));
	// espuma batendo na costa (vai e volta)
	float onda = 0.5 + 0.5 * sin(TIME * 1.3 - costa * 18.0 + na.x * 5.0);
	float espuma = smoothstep(0.22, 0.48, costa) * onda * (0.6 + 0.4 * ruido(wp.xz * 0.15 + TIME * 0.2));
	espuma *= (1.0 - smoothstep(600.0, 1800.0, dist)) * completa;
	// reflexo do céu nas bordas (fresnel)
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	cor = mix(cor, cor_ceu * 0.85, fr * 0.65);
	ALBEDO = mix(cor, vec3(0.9, 0.88, 0.82), clamp(espuma, 0.0, 1.0) * 0.75);
	ROUGHNESS = 0.06 + espuma * 0.7;
	SPECULAR = 0.65;
	METALLIC = 0.0;
}
"""

# ---------- trecho dos pisos: chuva (molhado/poças), sombra perto dos prédios, rachaduras e folhas ----------
# molhado (0..1) vem do clima (mundo/clima.gd) · ao_caixas = plantas dos prédios mais perto do jogador
# (mundo/mato.gd manda até 24), para escurecer o chão junto das paredes (o "AO" que o renderizador do celular
# não tem). Tudo que é detalhe fino some com a distância (fica leve e não "chuvisca" ao longe).
const CHAO := """
global uniform float molhado;
uniform float detalhe = 1.0;            // Opções › Gráficos › Detalhes dos shaders: 0 = sem os detalhes finos
uniform vec4 ao_caixas[24];
uniform int ao_n = 0;
float sombra_predios(vec2 p, float dist) {
	if (dist > 70.0 || ao_n == 0) return 1.0;
	float a = 1.0;
	for (int i = 0; i < 24; i++) {
		if (i >= ao_n) break;
		vec2 d = abs(p - ao_caixas[i].xy) - ao_caixas[i].zw;
		float dd = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
		a = min(a, smoothstep(-0.1, 2.4, dd));
	}
	return mix(a, 1.0, smoothstep(45.0, 70.0, dist));
}
// rachaduras: bordas de células (voronoi). Devolve 0..1 (1 = em cima da rachadura)
float rachas(vec2 p, float largura) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.31));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return 1.0 - smoothstep(0.0, largura, d2 - d1);
}
// folhas secas, papéis e lixinho espalhados (mais onde "dens" é alto). rgb = cor, a = quanto cobre
vec4 folhas(vec2 p, float dens) {
	vec2 c = floor(p * 2.6);
	float h = hash(c + 3.7);
	if (h > dens) return vec4(0.0);
	vec2 o = vec2(hash(c + 11.1), hash(c + 5.3)) * 0.6 + 0.2;
	float r = 0.05 + 0.06 * hash(c + 2.9);
	float m = 1.0 - smoothstep(r * 0.7, r, length(fract(p * 2.6) - o) / 2.6);
	float t = hash(c + 8.8);
	vec3 cf = t < 0.35 ? vec3(0.36, 0.20, 0.07) : (t < 0.65 ? vec3(0.50, 0.33, 0.10) : (t < 0.85 ? vec3(0.28, 0.24, 0.12) : vec3(0.55, 0.54, 0.50)));
	return vec4(cf, m * 0.85);
}
// poças: onde o chão é mais baixo (ruído). Secas = mancha escura; com chuva = água que reflete o céu
float pocas(vec2 p) { return smoothstep(0.60, 0.64, fbm(p * 0.11 + 4.0)); }
void molhar(inout vec3 c, inout float rough, inout float spec, float poca) {
	c *= mix(1.0, 0.92, poca);                                    // marca de poça seca
	c *= mix(1.0, 0.62, molhado);                                 // chão molhado escurece
	rough = mix(rough, 0.38, molhado);
	float agua = poca * smoothstep(0.15, 0.6, molhado);
	// 0.92: poça ESCURA e lisa (antes refletia o céu cinza tão forte que parecia gelo/neve)
	c = mix(c, c * 0.18, agua);
	rough = mix(rough, 0.24, agua);
	spec = mix(spec, 0.28, agua);
}
"""

# TERRA (e LOTES): mistura SUAVE de 5 materiais, sem quadriculado. Quem decide quanto de cada um:
#   1) SPLATMAP (textura "splat", 1 pixel = 20 m, lida borrada pelos mipmaps e com a posição mexida por ruído):
#      r = urbano -> concreto · g = grama · b = entulho/terra (ruínas)
#   2) VERTEX PAINT (só nos lotes, "pintura" = 1): COLOR.rgb = pesos pintados nos vértices (concreto em cima do lote,
#      terra/mato no pé da rampa), misturados com o splatmap
#   3) INCLINAÇÃO/ALTURA (procedural): rampa (íngreme) -> pedra/terra; baixo (perto da água, pé das rampas) -> lama;
#      beira d'água -> areia (máscara terra/água)
# HEIGHT BLENDING: cada material tem um "relevo" (placas de concreto altas e juntas baixas, tufos de grama, pedrinhas):
# na transição ganha quem é mais alto, então a grama nasce nas rachaduras e as pedras furam a terra (sem degradê
# borrado). Detalhe fino só de perto (longe = só as cores misturadas).
const TERRA := """
shader_type spatial;
uniform sampler2D mascara : filter_linear_mipmap;
uniform sampler2D splat : filter_linear_mipmap;
uniform vec2 mundo = vec2(11000.0, 8600.0);
uniform float pintura = 0.0;             // 1 = usa as cores dos vértices (lotes)
uniform vec3 cor_concreto : source_color = vec3(0.47, 0.45, 0.42);
uniform vec3 cor_terra : source_color = vec3(0.37, 0.30, 0.22);
uniform vec3 cor_grama : source_color = vec3(0.24, 0.40, 0.17);
uniform vec3 cor_pedra : source_color = vec3(0.40, 0.38, 0.36);
uniform vec3 cor_areia : source_color = vec3(0.80, 0.70, 0.52);
uniform vec3 cor_lama : source_color = vec3(0.20, 0.16, 0.11);
// texturas de verdade (Poly Haven, CC0: mundo/texturas/LICENCA.txt) · cada uma com um tamanho e um giro diferentes
// (a repetição não "alinha" entre elas) e a cor variando em manchas grandes (não se vê o ladrilho de longe)
uniform sampler2D tex_concreto : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_terra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_grama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_areia : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_lama : source_color, filter_linear_mipmap, repeat_enable;
// 0.84: Opções › Gráficos · "Filtragem anisotrópica" (1 = desligada; 2..16: o chão de longe fica nítido: várias
// amostras ao longo da direção em que a textura "estica") e "Detalhes das texturas" (vies_tex > 0 = mais borrado e leve)
uniform float aniso = 1.0;
uniform float vies_tex = 0.0;
""" + COMUM + CHAO + VERTICE_CAMADA + """
vec2 giro(vec2 p, float a) { return vec2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a)); }
// dx/dy = derivadas do uv calculadas FORA dos "if" (dentro deles a placa não garante as derivadas)
vec3 amostra(sampler2D t, vec2 p, vec2 dx, vec2 dy) {
	dx *= exp2(vies_tex);
	dy *= exp2(vies_tex);
	if (aniso <= 1.01) return textureGrad(t, p, dx, dy).rgb;
	float lx = length(dx);
	float ly = length(dy);
	vec2 maior = lx > ly ? dx : dy;
	float razao = clamp(max(lx, ly) / max(min(lx, ly), 1e-7), 1.0, aniso);
	int n = int(clamp(floor(log2(aniso)) + 1.0, 1.0, 4.0));
	n = min(n, int(ceil(razao)));
	vec2 dx2 = lx > ly ? dx / razao : dx;
	vec2 dy2 = lx > ly ? dy : dy / razao;
	vec3 s = vec3(0.0);
	for (int i = 0; i < n; i++) {
		float o = (float(i) + 0.5) / float(n) - 0.5;
		s += textureGrad(t, p + maior * o, dx2, dy2).rgb;
	}
	return s / float(n);
}
// relevo pela própria textura: mais claro que a média = mais alto (pedrinhas, placas), mais escuro = mais baixo (juntas)
float relevo(vec3 c, float media, float desvio) { return clamp(0.5 + (dot(c, vec3(0.3, 0.59, 0.11)) - media) / (desvio * 3.0), 0.0, 1.0); }
void fragment() {
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float perto = (1.0 - smoothstep(35.0, 90.0, dist)) * detalhe;
	vec2 dwx = dFdx(wp.xz);
	vec2 dwy = dFdy(wp.xz);
	// ---- normal de verdade pela própria geometria (rampas dos lotes): inclinação
	vec3 nw = normalize(cross(dFdy(wp), dFdx(wp)));
	if (nw.y < 0.0) nw = -nw;
	float inclin = smoothstep(0.1, 0.3, length(nw.xz));
	if (pintura > 0.5) NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	// ---- 1) splatmap: lido borrado (mip ~0,9 de 40 m = ~70 m) e com a posição torta (ruído de ~25 m)
	vec2 torto = (vec2(ruido(wp.xz * 0.011), ruido(wp.xz * 0.011 + 13.7)) - 0.5) * 50.0;
	vec2 uv = (wp.xz + torto + mundo) / (2.0 * mundo);
	vec4 sp = textureLod(splat, uv, 0.9);
	float urb = sp.r;
	float m1 = ruido(wp.xz * 0.006 + 3.0);                            // manchas grandes (uma conta só para várias coisas)
	float m2 = ruido(wp.xz * 0.013 + 7.0);
	float grama = max(sp.g * 1.2, 0.18 + 0.5 * smoothstep(0.45, 0.8, m1));   // mato toma conta
	float terra = 0.22 + sp.b * 0.9 + 0.35 * smoothstep(0.5, 0.75, m2);
	float concreto = urb * 1.1;
	// ---- 2) vertex paint (lotes)
	vec3 pv = vec3(concreto, grama, terra);
	pv = mix(pv, COLOR.rgb * vec3(1.2, 0.9, 0.9) + vec3(0.0, grama * 0.35, 0.1), clamp(pintura * COLOR.a, 0.0, 1.0));
	concreto = pv.r;
	grama = pv.g;
	terra = pv.b;
	// ---- 3) inclinação e altura
	float pedra = inclin * 1.4;
	concreto *= 1.0 - inclin * 0.7;
	float baixo = 1.0 - smoothstep(-0.05, 0.35, wp.y);                // chão baixo (pé das rampas, terrenos)
	float beira = textureLod(mascara, (wp.xz + mundo) / (2.0 * mundo), 1.0).r;
	float areia = (1.0 - smoothstep(0.80, 0.96, beira)) * 2.0;
	// ---- texturas (só busca areia/lama onde podem aparecer) e relevo de cada material para o height blending
	float n1 = ruido(wp.xz * 0.9);
	float n2 = ruido(wp.xz * 2.7 + 5.0);
	// LOD: de longe (além de ~250 m) a textura vira a cor MÉDIA dela (nem busca: mais leve e sem "chiado")
	vec3 t_conc = vec3(0.464, 0.421, 0.349);
	vec3 t_terr = vec3(0.417, 0.352, 0.265);
	vec3 t_gram = vec3(0.431, 0.377, 0.243);
	vec3 t_arei = vec3(0.51, 0.448, 0.358);
	float com_tex = 1.0 - smoothstep(170.0, 250.0, dist);
	if (com_tex > 0.0) {
		t_conc = mix(t_conc, amostra(tex_concreto, giro(wp.xz, 0.37) / 4.5, giro(dwx, 0.37) / 4.5, giro(dwy, 0.37) / 4.5), com_tex);
		t_terr = mix(t_terr, amostra(tex_terra, giro(wp.xz, 2.3) / 3.2, giro(dwx, 2.3) / 3.2, giro(dwy, 2.3) / 3.2), com_tex);
		t_gram = mix(t_gram, amostra(tex_grama, giro(wp.xz, 1.1) / 3.6, giro(dwx, 1.1) / 3.6, giro(dwy, 1.1) / 3.6), com_tex);
		if (areia > 0.01) t_arei = mix(t_arei, amostra(tex_areia, giro(wp.xz, 0.7) / 5.0, giro(dwx, 0.7) / 5.0, giro(dwy, 0.7) / 5.0), com_tex);
	}
	float rach = 0.0;
	if (perto > 0.001) rach = rachas(wp.xz * 0.22, 0.025) * perto * smoothstep(0.52, 0.7, fbm(wp.xz * 0.045 + 5.0));   // rachaduras tortas, só em partes
	float h_conc = relevo(t_conc, 0.426, 0.086) - rach * 0.4;
	float h_gram = mix(relevo(t_gram, 0.378, 0.031), smoothstep(0.3, 0.8, n2), 0.4);   // tufos
	float h_terr = relevo(t_terr, 0.362, 0.067);
	float h_pedr = 0.3 + 0.6 * smoothstep(0.45, 0.7, ruido(wp.xz * 4.0));   // pedras furando a terra
	float h_arei = relevo(t_arei, 0.456, 0.053);
	float a0 = concreto + h_conc * 0.6;
	float a1 = grama + h_gram * 0.6;
	float a2 = terra + h_terr * 0.6;
	float a3 = pedra + h_pedr * 0.6;
	float a4 = areia + h_arei * 0.6 * min(areia, 1.0);   // areia só perto da água (longe dela o relevo não a faz "furar")
	float topo = max(max(max(a0, a1), max(a2, a3)), a4) - 0.22;
	vec4 w = max(vec4(a0, a1, a2, a3) - topo, vec4(0.0));
	float w4 = max(a4 - topo, 0.0);
	float soma = w.x + w.y + w.z + w.w + w4 + 1e-4;
	// ---- cor de cada material: textura x variação grande (manchas de dezenas de metros)
	vec3 c_conc = t_conc * (0.85 + 0.3 * ruido(wp.xz * 0.05)) * (1.0 - rach * 0.22);
	vec3 c_gram = t_gram * vec3(0.72, 1.0, 0.72) * (0.85 + 0.3 * n2);              // puxa para o verde dos parques
	c_gram = mix(c_gram, t_gram * 1.05, smoothstep(0.5, 0.8, m2) * 0.8);           // seca
	vec3 c_terr = t_terr * (0.85 + 0.3 * m1);
	vec3 c_pedr = t_terr * vec3(0.95, 0.97, 1.05) * (0.75 + 0.45 * n2);              // pedra: terra mais cinza e com pedras
	vec3 c_arei = t_arei * 1.3;
	vec3 cor = (c_conc * w.x + c_gram * w.y + c_terr * w.z + c_pedr * w.w + c_arei * w4) / soma;
	// lama: chão baixo e úmido (pé das rampas, perto da água, poças com chuva)
	float lama = clamp(baixo * 0.35 + (1.0 - beira) * 0.4, 0.0, 1.0) * (1.0 - w4 / soma) * smoothstep(0.35, 0.7, ruido(wp.xz * 0.05 + 1.0));
	vec3 c_lama = cor_lama;
	if (lama > 0.01 && com_tex > 0.0) c_lama = mix(c_lama, amostra(tex_lama, giro(wp.xz, 1.9) / 3.5, giro(dwx, 1.9) / 3.5, giro(dwy, 1.9) / 3.5) * 0.75, com_tex);
	cor = mix(cor, c_lama, lama * (0.5 + 0.5 * molhado));
	if (perto > 0.001) {
		vec4 fo = folhas(wp.xz + vec2(n1, n2) * 0.6, 0.02 + 0.06 * w.x / soma) * perto * (1.0 - w4 / soma);
		cor = mix(cor, fo.rgb, fo.a);
	}
	float rough = 0.95;
	float spec = 0.3;
	molhar(cor, rough, spec, pocas(wp.xz) * (1.0 - w4 / soma));
	cor *= sombra_predios(wp.xz, dist);
	ALBEDO = cor * mix(1.0, 0.85, molhado * w4 / soma);
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""

const PARQUE := """
shader_type spatial;
uniform vec3 cor_grama : source_color = vec3(0.24, 0.40, 0.17);
""" + COMUM + CHAO + VERTICE_CAMADA + """
void fragment() {
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float perto = (1.0 - smoothstep(35.0, 90.0, dist)) * detalhe;
	float n = fbm(wp.xz * 0.05);
	float m = fbm(wp.xz * 0.008);
	vec3 cor = cor_grama * (0.7 + 0.5 * n);
	cor = mix(cor, vec3(0.42, 0.40, 0.18), smoothstep(0.55, 0.85, m) * 0.7);     // grama seca (sem ninguém cuidar)
	cor = mix(cor, vec3(0.33, 0.27, 0.18), smoothstep(0.62, 0.72, fbm(wp.xz * 0.04 + 9.0)) * 0.8);   // terra pisada
	cor *= 0.88 + 0.22 * ruido(wp.xz * 1.7);
	if (perto > 0.001) {
		vec4 fo = folhas(wp.xz, 0.05 + 0.25 * smoothstep(0.45, 0.8, fbm(wp.xz * 0.02 + 3.0))) * perto;
		cor = mix(cor, fo.rgb, fo.a);
	}
	float rough = 1.0;
	float spec = 0.25;
	molhar(cor, rough, spec, pocas(wp.xz * 0.8) * 0.8);
	ALBEDO = cor;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""

const ASFALTO := """
shader_type spatial;
uniform vec3 cor : source_color = vec3(0.16, 0.16, 0.17);
""" + COMUM + CHAO + VERTICE_CAMADA + """
void fragment() {
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float perto = (1.0 - smoothstep(40.0, 110.0, dist)) * detalhe;
	float n = fbm(wp.xz * 0.35);
	float m = fbm(wp.xz * 0.012);
	vec3 c = cor * (0.85 + 0.3 * n) * (0.9 + 0.2 * m);
	// remendos (asfalto novo, mais escuro, ou velho, mais claro) em retângulos
	vec2 cr = floor(wp.xz / 7.0);
	vec2 fr = fract(wp.xz / 7.0);
	float hr = hash(cr + 1.3);
	vec2 tr = vec2(0.25 + 0.5 * hash(cr + 2.1), 0.2 + 0.5 * hash(cr + 4.2));
	float remendo = step(hr, 0.16) * step(abs(fr.x - 0.5), tr.x * 0.5) * step(abs(fr.y - 0.5), tr.y * 0.5);
	c *= mix(1.0, hash(cr + 6.6) < 0.5 ? 0.72 : 1.25, remendo);
	// manchas de óleo
	vec2 co = floor(wp.xz / 4.0);
	float oleo = step(hash(co + 9.1), 0.12) * (1.0 - smoothstep(0.3, 1.3, length(fract(wp.xz / 4.0) * 4.0 - 2.0 - vec2(hash(co), hash(co + 1.0)) + 0.5) * (0.8 + 0.4 * ruido(wp.xz * 2.0))));
	c *= 1.0 - oleo * 0.45;
	// buracos: borda clara quebrada, fundo escuro (enchem de água na chuva)
	vec2 cb = floor(wp.xz / 9.0);
	vec2 pb = fract(wp.xz / 9.0) * 9.0 - 4.5 + (vec2(hash(cb + 3.3), hash(cb + 7.7)) - 0.5) * 5.0;
	float rb = 0.45 + 0.6 * hash(cb + 5.5);
	float db = length(pb * vec2(1.0, 1.3)) + (ruido(wp.xz * 3.0) - 0.5) * 0.35;
	float buraco = step(hash(cb + 8.4), 0.10) * (1.0 - smoothstep(rb - 0.08, rb, db)) * perto;
	float borda = step(hash(cb + 8.4), 0.10) * (1.0 - smoothstep(rb, rb + 0.25, db)) * (1.0 - buraco) * perto;
	c = mix(c, c * 1.5, borda * 0.6);
	c = mix(c, vec3(0.06, 0.055, 0.05), buraco);
	// rachaduras (rede fina) só onde o asfalto está mais gasto
	float r = smoothstep(0.97, 1.0, 1.0 - abs(ruido(wp.xz * 0.08) - 0.5) * 2.0) * (1.0 - smoothstep(80.0, 250.0, dist));
	if (perto > 0.001) {
		float gasto = smoothstep(0.4, 0.7, fbm(wp.xz * 0.03 + 1.7));
		r = max(r, rachas(wp.xz * 0.32, 0.03) * gasto * perto);
		vec4 fo = folhas(wp.xz, 0.04 + 0.12 * gasto) * perto;
		c = mix(c, fo.rgb * 0.8, fo.a);
	}
	c *= 1.0 - r * 0.45;
	float rough = 0.92;
	float spec = 0.35;
	molhar(c, rough, spec, max(pocas(wp.xz) * 0.9, buraco));
	c *= sombra_predios(wp.xz, dist);
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""

const CALCADA := """
shader_type spatial;
uniform vec3 cor : source_color = vec3(0.56, 0.54, 0.50);
""" + COMUM + CHAO + VERTICE_CAMADA + """
void fragment() {
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float perto = (1.0 - smoothstep(30.0, 120.0, dist)) * detalhe;
	vec2 placa = floor(wp.xz / 1.6);
	vec2 g = abs(fract(wp.xz / 1.6) - 0.5);
	float junta = smoothstep(0.47, 0.5, max(g.x, g.y)) * perto;
	vec3 c = cor * (0.88 + 0.18 * fbm(wp.xz * 0.6));
	c *= 0.9 + 0.16 * hash(placa + 0.5) * perto;                                       // cada placa num tom
	c = mix(c, c * 0.8, step(hash(placa + 4.4), 0.08) * perto);                         // placas soltas/sujas
	c = mix(c * (1.0 - junta * 0.25), vec3(0.22, 0.28, 0.13), junta * 0.7 * smoothstep(0.35, 0.65, fbm(wp.xz * 0.08)));   // musgo nas juntas
	float ao = sombra_predios(wp.xz, dist);
	if (perto > 0.001) {
		float r = rachas(wp.xz * 0.55, 0.03) * perto * smoothstep(0.5, 0.7, fbm(wp.xz * 0.04 + 5.0));
		c *= 1.0 - r * 0.3;
		c *= 1.0 - 0.3 * smoothstep(0.62, 0.8, fbm(wp.xz * 0.25 + 2.0)) * perto;           // manchas
		vec4 fo = folhas(wp.xz, 0.05 + 0.3 * (1.0 - ao)) * perto;                           // o vento junta folhas nas paredes
		c = mix(c, fo.rgb, fo.a);
	}
	float rough = 0.9;
	float spec = 0.3;
	molhar(c, rough, spec, pocas(wp.xz * 1.3) * 0.7);
	ALBEDO = c * ao;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""

const FAIXA := """
shader_type spatial;
global uniform float molhado;
""" + COMUM + VERTICE_CAMADA + """
void fragment() {
	float gasta = smoothstep(0.35, 0.75, fbm(wp.xz * 0.4));                              // tinta descascada
	ALBEDO = mix(COLOR.rgb * (0.85 + 0.15 * ruido(wp.xz * 2.0)), vec3(0.17), gasta * 0.65) * mix(1.0, 0.65, molhado);
	ROUGHNESS = mix(0.7, 0.35, molhado);
}
"""

# PICHAÇÕES no térreo (prédios de longe e paredes de fora dos interiores): "tags" em ~45% dos trechos de 4 m
const GRAFITE := """
vec3 grafite(vec3 c, float u, float v, float sg, float forca) {
	float cg = floor(u / 4.0);
	float hg = hash(vec2(cg, sg * 23.0));
	if (hg > 0.45 || forca <= 0.0 || v > 3.4 || v < 0.2) return c;
	float gu = fract(u / 4.0) * 4.0;
	vec2 q = vec2(gu - 2.0, v - 1.6) / vec2(1.55, 0.75);
	float caixa_g = 1.0 - smoothstep(0.8, 1.0, max(abs(q.x), abs(q.y)));
	vec2 s = vec2(gu * 1.4, v * 2.2) + hg * 91.0;
	float traco = 1.0 - smoothstep(0.05, 0.1, abs(ruido(s) - 0.5));
	float cheio = smoothstep(0.62, 0.66, ruido(s * 0.8 + 3.0)) * step(0.65, hash(vec2(cg, sg + 4.0)));
	float hc = hash(vec2(cg, sg * 5.0 + 1.0));
	vec3 tinta = hc < 0.2 ? vec3(0.75, 0.1, 0.08) : (hc < 0.4 ? vec3(0.1, 0.25, 0.7) : (hc < 0.55 ? vec3(0.04) : (hc < 0.7 ? vec3(0.85, 0.85, 0.8) : (hc < 0.85 ? vec3(0.2, 0.6, 0.2) : vec3(0.85, 0.3, 0.6)))));
	vec3 contorno = hc < 0.4 ? vec3(0.88, 0.88, 0.84) : vec3(0.04);
	float g = caixa_g * forca;
	c = mix(c, tinta * (0.75 + 0.25 * ruido(s * 4.0)), cheio * g * 0.9);
	return mix(c, cheio > 0.5 ? contorno : tinta, traco * g * 0.85);
}
"""

# prédios (MultiMesh): INSTANCE_CUSTOM = (largura x, altura, largura z, tipo + semente/2 + 0,5 se não dá para entrar)
# 1.00: prédio em que NÃO dá para entrar = térreo com PORTAS DE AÇO baixadas; em que dá = vitrines/portas escuras, sem
# tábuas (o mesmo sinal na cidade inteira: mundo/cidade.gd dado_predio)
# tipo: 0 concreto · 1 tijolo · 2 pedra clara · 3 vidro (torres) · 4 ruína (queimada)
# Cidade abandonada: sujeira escorrendo, janelas quebradas (pretas), vitrines tapadas com tábuas.
# COLOR.a < 1 = bloco que começa acima do chão (casca de prédio com interior): a = 1 - altura_da_base / 40
const PREDIO := """
shader_type spatial;
uniform float detalhe = 1.0;               // 0 = sem janelas (leve) · 1 = completo
global uniform float molhado;              // chuva (mundo/clima.gd): paredes escurecem
global uniform float noite;                // 0 dia · 1 noite (mundo/clima.gd): luzes de sobreviventes nas janelas
// 0.92: TEXTURAS das paredes e do telhado (Poly Haven, CC0), postas por material(): tijolo (tipo 1), concreto
// (0, 3, 4), pedra (2). De perto têm detalhe; de longe (TEX_LONGE) viram a cor lisa de antes (sem chiado e mais leve)
uniform float com_textura = 1.0;
uniform sampler2D tex_tijolo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_concreto : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_pedra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_telhado : source_color, filter_linear_mipmap, repeat_enable;
const float TEX_LONGE = 320.0;
vec3 det(sampler2D t, vec2 p, vec2 dx, vec2 dy, float forca) {
	vec3 m = max(textureLod(t, vec2(0.5), 10.0).rgb, vec3(0.04));
	return mix(vec3(1.0), textureGrad(t, p, dx, dy).rgb / m, forca);
}
varying vec3 lp;
varying flat vec3 tam;                     // flat = igual no prédio todo (interpolado, o sorteio por janela "chiava")
varying flat float tipo;
varying flat float sem;
varying flat float fechado;                // 1.00: 1 = não dá para entrar (térreo com portas de aço)
varying vec3 nl;
// "aleatório" sem sin(): sin() de número grande (coordenadas de milhares de metros) perde a precisão na placa do
// celular (Mali) e o resultado vira quase constante -> bolinhas iguais em grade e listras. Números pequenos (mod) e
// só multiplicações = igual no celular e no PC.
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
""" + GRAFITE + """
void vertex() {
	tam = INSTANCE_CUSTOM.xyz;
	tipo = floor(INSTANCE_CUSTOM.w);
	float fw = fract(INSTANCE_CUSTOM.w);
	fechado = step(0.5, fw);
	sem = fract(fw * 2.0);
	// a base desce 0,8 m para dentro do chão (o prédio nunca fica "flutuando" sobre o lote/terra); lp é calculado
	// DEPOIS, então a grade de janelas continua no mesmo lugar (bate com as escadas de incêndio)
	if (VERTEX.y < 0.0) VERTEX.y -= 0.8 / max(tam.y, 1.0);
	lp = VERTEX * tam;
	lp.y += tam.y * 0.5 + (1.0 - COLOR.a) * 40.0;   // altura a partir do chão
	nl = NORMAL;
}
void fragment() {
	vec3 base = COLOR.rgb;
	float dist = length(VERTEX);
	vec3 px = fwidth(lp);                      // quantos metros cabem em 1 pixel (fora do "if": derivada segura)
	vec2 uvp = abs(nl.x) > 0.5 ? lp.zy : lp.xy;       // 0.92: parede (u, v) e telhado (x, z) para as texturas
	vec2 dpx = dFdx(uvp);
	vec2 dpy = dFdy(uvp);
	vec2 dtx = dFdx(lp.xz);
	vec2 dty = dFdy(lp.xz);
	float com_tex = com_textura * (1.0 - smoothstep(TEX_LONGE * 0.5, TEX_LONGE, dist));
	if (nl.y > 0.5) {
		// telhado: laje escura com manchas + borda (platibanda)
		vec2 b = 0.5 * tam.xz - abs(lp.xz);
		float borda = 1.0 - smoothstep(0.4, 0.9, min(b.x, b.y));
		vec3 dtel = vec3(1.0);
		if (com_tex > 0.0) dtel = mix(vec3(1.0), det(tex_telhado, lp.xz / 5.0, dtx / 5.0, dty / 5.0, 0.9), com_tex);
		ALBEDO = mix(vec3(0.24, 0.23, 0.22) * (0.85 + 0.3 * hash(floor(lp.xz * 0.5) + sem)), base * 0.8, borda) * dtel;
		ROUGHNESS = 0.95;
	} else {
		float u = abs(nl.x) > 0.5 ? lp.z : lp.x;
		float v = lp.y;
		float andar = tipo > 2.5 ? 3.8 : 3.3;
		float coluna = tipo > 2.5 ? 1.9 : 2.7;
		float fu = fract(u / coluna);
		float fv = fract((v - 4.6) / andar);
		vec2 cel = vec2(floor(u / coluna), floor((v - 4.6) / andar));
		float corpo = step(4.6, v) * step(v, tam.y - 1.3);
		float janela = corpo * step(0.2, fu) * step(fu, 0.8) * step(0.22, fv) * step(fv, 0.86);
		if (tipo > 2.5) janela = corpo * step(0.06, fu) * step(0.08, fv);           // vidro: quase tudo é janela
		// "MIPMAP" das janelas: quando a grade fica menor que ~2 pixels, troca pela cobertura MÉDIA da janela
		// (é o que o mipmap faz com uma textura: sem chiado/serrilhado na média distância)
		float pxg = max((abs(nl.x) > 0.5 ? px.z : px.x) / coluna, px.y / andar);
		janela = mix(janela, corpo * (tipo > 2.5 ? 0.86 : 0.38), smoothstep(0.3, 0.6, pxg));
		float longe = smoothstep(450.0, 1400.0, dist);
		janela = mix(janela, 0.0, longe) * detalhe;
		// vidro: escuro, refletindo o céu mais em cima; algumas janelas acesas (quente)
		vec3 vidro = mix(vec3(0.08, 0.10, 0.13), vec3(0.45, 0.38, 0.36), clamp(v / max(tam.y, 1.0), 0.0, 1.0) * 0.6);
		float h = hash(cel + sem * 91.0);
		if (h < 0.22) vidro = vec3(0.015, 0.015, 0.02);                     // quebrada: buraco escuro
		else if (h > 0.86) vidro *= 0.55;
		// cortinas, persianas e janelas tapadas com jornal/papelão (só nas inteiras)
		float wu = clamp((fu - 0.2) / 0.6, 0.0, 1.0);
		float wv = clamp((fv - 0.22) / 0.64, 0.0, 1.0);
		float nitido = 1.0 - smoothstep(50.0, 150.0, dist);                 // detalhe fino só de perto (sem chiado)
		if (h >= 0.22 && tipo < 2.5) {
			float hc = hash(cel + sem * 53.0 + 7.0);
			float tc = hash(cel + sem * 17.0);
			vec3 tecido = hc < 0.3 ? vec3(0.55, 0.47, 0.36) : (hc < 0.5 ? vec3(0.42, 0.18, 0.14) : (hc < 0.7 ? vec3(0.25, 0.32, 0.38) : vec3(0.62, 0.6, 0.55)));
			if (tc < 0.25) vidro = mix(vidro, tecido * (0.85 + 0.15 * sin(wu * 18.0) * nitido), clamp(step(wu, 0.22 + 0.2 * hc) + step(0.78 - 0.2 * hc, wu), 0.0, 1.0));
			else if (tc < 0.42) vidro = mix(vidro, vec3(0.55, 0.54, 0.5) * (0.85 + 0.15 * step(0.5, fract(wv * 8.0)) * nitido), step(0.7 - 0.6 * hc, wv));
			else if (tc < 0.5) vidro = vec3(0.6, 0.58, 0.5) * (0.8 + 0.2 * ruido(vec2(wu, wv) * 3.0 + sem) * nitido);
		}
		// luz de sobrevivente (vela/lampião) em pouquíssimas janelas, à noite, em alguns prédios
		// 0.92: mais prédios habitados (35%) e mais janelas acesas neles (a cidade à noite não ficava quase toda preta)
		float habitado = step(hash(vec2(sem * 71.0, 2.0)), 0.35);
		float luz = habitado * step(tipo > 2.5 ? 0.993 : 0.94, hash(cel + sem * 29.0 + 3.0)) * step(0.22, h) * step(tipo, 3.5);
		vec3 parede = base * (0.9 + 0.12 * hash(vec2(cel.y, sem)));
		if (com_tex > 0.0) {
			vec3 dpar;
			if (tipo > 0.5 && tipo < 1.5) dpar = det(tex_tijolo, uvp / 1.4, dpx / 1.4, dpy / 1.4, 0.95);
			else if (tipo > 1.5 && tipo < 2.5) dpar = det(tex_pedra, uvp / 2.6, dpx / 2.6, dpy / 2.6, 0.8);
			else dpar = det(tex_concreto, uvp / 3.0, dpx / 3.0, dpy / 3.0, 0.85);
			parede *= mix(vec3(1.0), dpar, com_tex);
		}
		// sujeira escorrendo das janelas e manchas de umidade (cidade abandonada)
		parede *= 0.8 + 0.2 * ruido(vec2(u * 0.55 + sem * 40.0, v * 0.035));
		parede *= 1.0 - 0.18 * smoothstep(0.55, 0.85, ruido(vec2(u * 0.12, v * 0.09) + sem * 7.0));
		// faixa entre andares e térreo com lojas (vitrine escura + toldo)
		float laje = corpo * step(0.92, fv) * (1.0 - longe) * detalhe;
		parede *= 1.0 - laje * 0.18;
		vec3 c = mix(parede, vidro, janela);
		float hera = 0.0;
		if (dist < 450.0 && detalhe > 0.0) {     // lojas, letreiros, grafite e hera só de perto (economiza GPU)
			vec3 c_antes = c;
			float terreo = step(v, 4.6) * detalhe;
			float vitrine = terreo * step(0.6, v) * step(v, 3.4) * step(0.12, fract(u / 6.0)) * step(fract(u / 6.0), 0.88);
			// cada loja (trecho de 6 m): toldo, PLACA com letreiro ou nada (caiu)
			float seg = floor(u / 6.0);
			float fs = fract(u / 6.0);
			float hs = hash(vec2(seg, sem * 3.3));
			float faixa_alta = terreo * step(3.4, v) * step(v, 4.2);
			float toldo = faixa_alta * step(hs, 0.38) * step(v, 4.0);
			float placa = faixa_alta * step(0.38, hs) * step(hs, 0.8) * step(0.1, fs) * step(fs, 0.9) * step(3.5, v) * step(v, 4.15);
			if (hash(vec2(seg, sem + 8.0)) < 0.2) placa *= step(fs, 0.5 + 0.3 * hs);                   // placa quebrada
			float hp = hash(vec2(seg, sem * 7.7));
			vec3 cor_placa = hp < 0.25 ? vec3(0.45, 0.08, 0.06) : (hp < 0.5 ? vec3(0.06, 0.18, 0.12) : (hp < 0.7 ? vec3(0.05, 0.08, 0.22) : (hp < 0.85 ? vec3(0.05) : vec3(0.78, 0.76, 0.7))));
			vec3 cor_letra = hp < 0.85 ? (hash(vec2(seg, 2.2)) < 0.5 ? vec3(0.9, 0.88, 0.8) : vec3(0.9, 0.75, 0.2)) : vec3(0.5, 0.06, 0.05);
			float lu = (fs - 0.1) / 0.8 * 4.8;
			float lv = (v - 3.5) / 0.65;
			float lc = floor(lu / 0.42);
			vec2 pix = floor(vec2(fract(lu / 0.42) * 4.0, lv * 7.0));
			float letra = step(1.0, pix.y) * step(pix.y, 5.0) * step(pix.x, 2.0) * step(0.42, hash(vec2(lc * 7.0 + pix.x, pix.y) + seg * 3.1 + sem));
			letra *= step(0.15, hash(vec2(lc, seg + sem)));                                            // espaços
			cor_placa = mix(cor_placa, cor_letra, letra) * (0.6 + 0.4 * ruido(vec2(u * 3.0, v * 9.0)));   // desbotada
			float ht = hash(vec2(floor(u / 6.0), sem));
			vec3 cor_toldo = ht < 0.33 ? vec3(0.32, 0.12, 0.10) : (ht < 0.66 ? vec3(0.12, 0.22, 0.16) : vec3(0.14, 0.15, 0.22));
			vec3 cor_vitrine = vec3(0.07, 0.07, 0.08);          // dá para entrar: vitrine e porta abertas (escuras)
			if (fechado > 0.5) {
				// 1.00: NÃO dá para entrar: porta de aço de enrolar baixada (frisos, ferrugem), em todo o térreo
				float friso = step(0.45, fract(v / 0.1));
				cor_vitrine = vec3(0.33, 0.34, 0.35) * (0.82 + 0.2 * friso) * (0.8 + 0.25 * ruido(vec2(u * 0.6, v * 0.3) + sem * 5.0));
				cor_vitrine = mix(cor_vitrine, vec3(0.36, 0.19, 0.09), smoothstep(0.55, 0.85, ruido(vec2(u * 0.8, v * 1.2) + sem * 11.0)) * 0.65);
				cor_vitrine *= 1.0 - 0.45 * max(step(fs, 0.14), step(0.86, fs));      // trilhos dos lados
			}
			c = mix(c, cor_vitrine, vitrine * (1.0 - longe));
			c = mix(c, cor_toldo, toldo * (1.0 - longe));
			c = mix(c, cor_placa, placa * (1.0 - longe));
			c = grafite(c, u, v, sem, (1.0 - smoothstep(50.0, 110.0, dist)) * detalhe * step(tipo, 3.5));
			// HERA subindo pelas paredes (~40% dos prédios), de 2 a 12 m, em manchas
			float tem_hera = step(hash(vec2(sem * 37.0, 5.1)), 0.4) * (1.0 - longe) * detalhe;
			float alt_hera = 2.0 + 10.0 * ruido(vec2(u * 0.16, sem * 31.0));
			hera = (1.0 - smoothstep(alt_hera - 2.0, alt_hera, v)) * smoothstep(0.42, 0.6, ruido(vec2(u, v) * 1.6 + sem * 9.0) + 0.3 * (1.0 - v / alt_hera));
			hera *= tem_hera * smoothstep(0.3, 0.6, ruido(vec2(u * 0.09, sem * 3.0)));
			c = mix(c, mix(vec3(0.07, 0.13, 0.04), vec3(0.20, 0.28, 0.09), ruido(vec2(u, v) * 5.0)), hera);
			float some = smoothstep(330.0, 450.0, dist);             // some aos poucos (sem "pulo" na distância)
			c = mix(c, c_antes, some);
			hera *= 1.0 - some;
		}
		// sombra no pé da parede (forte nos primeiros 2 m) + o resto do térreo
		c *= (0.6 + 0.4 * smoothstep(0.0, 2.2, v)) * (0.85 + 0.15 * smoothstep(0.0, 7.0, v));
		c *= mix(1.0, 0.7 + 0.12 * ruido(vec2(u * 0.5, v * 0.05)), molhado);       // chuva: parede molhada, escorrida
		if (tipo > 3.5) {
			// ruína: fuligem subindo das janelas, sem vidro, buracos
			float fumo = smoothstep(0.3, 0.8, ruido(vec2(u * 0.25 + sem * 9.0, v * 0.06)));
			c = mix(c, vec3(0.05, 0.045, 0.04), fumo * 0.75);
			c = mix(c, vec3(0.02), janela);
		}
		ALBEDO = c;
		janela *= 1.0 - hera;
		ROUGHNESS = mix(0.9, 0.25, janela);
		SPECULAR = mix(0.3, 0.7, janela);
		float tremula = 0.75 + 0.25 * sin(TIME * (5.0 + 6.0 * h) + h * 40.0) * sin(TIME * 2.3 + sem * 9.0);
		EMISSION = vec3(1.0, 0.55, 0.2) * 2.6 * tremula * luz * janela * noite;
	}
}
"""

# INTERIORES (mundo/interior.gd): dentro do prédio o sol quase não entra e a luz ambiente é fraca;
# a lanterna e outras luzes (não direcionais) iluminam normal. padrao: 0 liso · 1 cerâmica · 2 tábuas ·
# 3 papel de parede (só do lado de dentro) · 4 concreto. Sujeira, manchas e umidade em tudo.
const INTERIOR := """
shader_type spatial;
uniform vec4 caixa = vec4(0.0, 0.0, 10.0, 10.0);   // centro x, z e meia-largura x, z (por dentro)
uniform float padrao = 0.0;
uniform float sol_dentro = 0.12;
uniform float semente = 0.0;                  // a mesma do prédio (hera do lado de fora parecida com a de longe)
uniform float sujeira = 1.0;                  // 0.68: força das manchas/sujeira (locais especiais usam menos)
uniform float forca_hera = 1.0;               // 0.68: quanto de hera pode subir pelas paredes de fora
uniform float camada = 0.0;                   // 0.78: chão pintado dos locais especiais (por cima do lote ao longe)
// 0.92: TEXTURAS de verdade (Poly Haven, CC0: mundo/texturas/LICENCA.txt), postas por material() · papel = 1: papel de
// parede velho por dentro (casas e apartamentos) · 0: reboco gasto (locais especiais) · com_textura = 0: o desenho antigo
uniform float papel = 0.0;
uniform float com_textura = 1.0;
uniform sampler2D tex_papel : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_reboco : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_ceramica : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_madeira : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_concreto : source_color, filter_linear_mipmap, repeat_enable;
// lado de FORA das paredes do prédio com interior: a mesma textura do prédio visto de longe (tipo, como em PREDIO)
uniform float tipo_predio = -1.0;
uniform sampler2D tex_tijolo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_pedra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_predio : source_color, filter_linear_mipmap, repeat_enable;
global uniform float molhado;
varying vec3 wp;
varying float dentro;
// detalhe da textura em volta de 1 (a cor média dela vira 1): a cor de cada parede/piso continua a do desenho
vec3 det(sampler2D t, vec2 p, vec2 dx, vec2 dy, float forca) {
	vec3 m = max(textureLod(t, vec2(0.5), 10.0).rgb, vec3(0.04));
	return mix(vec3(1.0), textureGrad(t, p, dx, dy).rgb / m, forca);
}
// "aleatório" sem sin(): sin() de número grande (coordenadas de milhares de metros) perde a precisão na placa do
// celular (Mali) e o resultado vira quase constante -> bolinhas iguais em grade e listras. Números pequenos (mod) e
// só multiplicações = igual no celular e no PC.
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
""" + GRAFITE + """
varying float vertical;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertical = step(abs(NORMAL.y), 0.5);
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z += camada * 1.2e-6 * POSITION.w;
}
void fragment() {
	vec2 d = abs(wp.xz - caixa.xy) - caixa.zw;
	dentro = 1.0 - smoothstep(-0.02, 0.06, max(d.x, d.y));
	vec3 c = COLOR.rgb;
	vec2 u = UV;
	vec2 dux = dFdx(u);                        // derivadas fora dos "if" (dentro deles a placa não garante)
	vec2 duy = dFdy(u);
	if (com_textura > 0.5 && padrao > 0.5) {
		// 0.92: texturas: 1 cerâmica (ladrilhos de 0,5 m) · 2 tábuas · 3 papel de parede ou reboco · 4 concreto
		if (padrao < 1.5) c *= det(tex_ceramica, u / 2.0, dux / 2.0, duy / 2.0, 0.9);
		else if (padrao < 2.5) c *= det(tex_madeira, u / 2.4, dux / 2.4, duy / 2.4, 0.9);
		else if (padrao < 3.5) {
			vec3 dpa = papel > 0.5 ? det(tex_papel, u / 2.2, dux / 2.2, duy / 2.2, 0.75) : det(tex_reboco, u / 4.5, dux / 4.5, duy / 4.5, 0.22);
			vec3 dfo;
			if (tipo_predio > 0.5 && tipo_predio < 1.5) dfo = det(tex_tijolo, u / 1.4, dux / 1.4, duy / 1.4, 0.95);
			else if (tipo_predio > 1.5 && tipo_predio < 2.5) dfo = det(tex_pedra, u / 2.6, dux / 2.6, duy / 2.6, 0.8);
			else if (tipo_predio > -0.5) dfo = det(tex_predio, u / 3.0, dux / 3.0, duy / 3.0, 0.85);
			else dfo = det(tex_reboco, u / 4.5, dux / 4.5, duy / 4.5, 0.22);
			c *= mix(dfo, dpa, dentro);
		} else c *= det(tex_concreto, u / 4.0, dux / 4.0, duy / 4.0, 0.8);
	} else if (padrao > 0.5 && padrao < 1.5) {
		vec2 g = fract(u / 0.5);
		float junta = step(0.94, max(g.x, g.y));
		float xadrez = mod(floor(u.x / 0.5) + floor(u.y / 0.5), 2.0);
		c *= (0.9 + 0.12 * xadrez) * (1.0 - junta * 0.35);
	} else if (padrao > 1.5 && padrao < 2.5) {
		float tabua = floor(u.y / 0.18);
		float emenda = step(0.93, fract(u.y / 0.18)) + step(0.985, fract(u.x / 2.4 + hash(vec2(tabua, 1.0))));
		c *= (0.8 + 0.3 * hash(vec2(tabua, 7.0))) * (0.9 + 0.1 * ruido(vec2(u.x * 3.0, tabua))) * (1.0 - clamp(emenda, 0.0, 1.0) * 0.4);
	} else if (padrao > 2.5 && padrao < 3.5) {
		float faixa = step(0.5, fract(u.x / 0.3));
		c *= mix(1.0, 0.93 + 0.07 * faixa, dentro);
		c *= 1.0 - dentro * 0.25 * smoothstep(0.6, 0.9, ruido(u * vec2(0.8, 0.5)));          // papel descascando / umidade
	} else if (padrao > 3.5) {
		c *= mix(1.0, 0.85 + 0.25 * ruido(u * 2.0), sujeira);
	}
	c *= mix(1.0, 0.78 + 0.3 * ruido(u * 1.3 + wp.xz * 0.05), sujeira);                    // sujeira
	if (padrao > 2.5 && padrao < 3.5) {
		// lado de FORA das paredes: hera e chuva (igual ao prédio visto de longe)
		float fora = 1.0 - dentro;
		float v = wp.y - 0.6;
		float tem_hera = step(hash(vec2(semente * 37.0, 5.1)), 0.4);
		float alt_hera = 2.0 + 10.0 * ruido(vec2(u.x * 0.16, semente * 31.0));
		float hera = (1.0 - smoothstep(alt_hera - 2.0, alt_hera, v)) * smoothstep(0.42, 0.6, ruido(vec2(u.x, v) * 1.6 + semente * 9.0) + 0.3 * (1.0 - v / alt_hera));
		hera *= tem_hera * fora * smoothstep(0.3, 0.6, ruido(vec2(u.x * 0.09, semente * 3.0))) * forca_hera;
		c = mix(c, mix(vec3(0.07, 0.13, 0.04), vec3(0.20, 0.28, 0.09), ruido(vec2(u.x, v) * 5.0)), hera);
		c = mix(c, grafite(c, u.x, v, semente, 1.0 - smoothstep(50.0, 110.0, length(wp - CAMERA_POSITION_WORLD))), fora * step(v, 3.5));
		c *= mix(1.0, (0.6 + 0.4 * smoothstep(0.0, 2.2, v)) * mix(1.0, 0.72, molhado), fora);
	}
	c *= 1.0 - 0.35 * smoothstep(0.7, 0.95, ruido(wp.xz * 0.35 + 3.0)) * step(padrao, 2.5) * step(0.5, padrao);   // manchas no piso
	// sombra nos cantos: rodapé (parede encontrando o piso) e junto do teto, em cada andar (4,6 m)
	float va = mod(wp.y - 0.6, 4.6);
	float canto = (0.62 + 0.38 * smoothstep(0.0, 0.9, va)) * (0.8 + 0.2 * (1.0 - smoothstep(3.3, 3.98, va)));
	c *= mix(1.0, canto, dentro * vertical);
	// 0.92: sombra onde o piso encontra as paredes de fora e nos cantos das paredes (a luz de dentro não chega lá)
	vec2 ate_parede = caixa.zw - abs(wp.xz - caixa.xy);
	float no_piso = (1.0 - vertical) * step(0.5, padrao) * step(padrao, 2.5);
	c *= mix(1.0, 0.55 + 0.45 * smoothstep(0.0, 0.9, min(ate_parede.x, ate_parede.y)), dentro * no_piso);
	c *= mix(1.0, 0.62 + 0.38 * smoothstep(0.0, 0.7, max(ate_parede.x, ate_parede.y)), dentro * vertical * step(min(ate_parede.x, ate_parede.y), 0.12));
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	AO = mix(1.0, 0.45, dentro);
}
void light() {
	float f = LIGHT_IS_DIRECTIONAL ? mix(1.0, sol_dentro, dentro) : 1.0;
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI * f;
}
"""

static var _shaders := {}             # o mesmo código vira o MESMO shader (compila uma vez só; importante no celular)

static func shader(codigo: String) -> Shader:
	if _shaders.has(codigo):
		return _shaders[codigo]
	var s := Shader.new()
	s.code = codigo
	_shaders[codigo] = s
	return s

# texturas do chão (shader TERRA): mundo/texturas/ (Poly Haven, CC0)
static func texturas_chao() -> Dictionary:
	var d := {}
	for k in ["concreto", "terra", "grama", "areia", "lama"]:
		d["tex_" + k] = load("res://mundo/texturas/chao_%s.jpg" % k)
	return d

# 0.92: texturas dos prédios e dos interiores (mundo/texturas/, Poly Haven, CC0), postas em todo material desses shaders
const TEX_PREDIO := {"tex_tijolo": "predio_tijolo", "tex_concreto": "predio_concreto", "tex_pedra": "predio_pedra", "tex_telhado": "predio_telhado"}
const TEX_INTERIOR := {"tex_papel": "interior_papel", "tex_reboco": "interior_reboco", "tex_ceramica": "interior_ceramica",
	"tex_madeira": "interior_madeira", "tex_concreto": "interior_concreto", "tex_tijolo": "predio_tijolo", "tex_pedra": "predio_pedra",
	"tex_predio": "predio_concreto"}
static var _tex := {}

static func _textura(nome: String) -> Texture2D:
	if not _tex.has(nome):
		_tex[nome] = load("res://mundo/texturas/%s.jpg" % nome)
	return _tex[nome]

# carrega todas de uma vez na thread principal (os interiores são montados numa thread: lá só pegam do cache)
static func aquecer_texturas() -> void:
	for lista in [TEX_PREDIO, TEX_INTERIOR]:
		for k in lista:
			_textura(lista[k])

static func material(codigo: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(codigo)
	var lista: Dictionary = TEX_PREDIO if codigo == PREDIO else (TEX_INTERIOR if codigo == INTERIOR else {})
	for k in lista:
		m.set_shader_parameter(k, _textura(lista[k]))
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

static func ondas(semente: int, freq: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = semente
	n.frequency = freq
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 6.0
	t.generate_mipmaps = true
	t.noise = n
	return t
