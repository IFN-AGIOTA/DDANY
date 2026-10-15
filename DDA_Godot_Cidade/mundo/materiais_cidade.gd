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
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z += camada * 3e-7 * POSITION.w;
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

const TERRA := """
shader_type spatial;
uniform sampler2D mascara : filter_linear_mipmap;
uniform vec2 mundo = vec2(11000.0, 8600.0);
uniform vec3 cor_chao : source_color = vec3(0.42, 0.40, 0.37);
uniform vec3 cor_areia : source_color = vec3(0.80, 0.70, 0.52);
""" + COMUM + VERTICE_CAMADA + """
void fragment() {
	vec2 uv = (wp.xz + mundo) / (2.0 * mundo);
	float terra = textureLod(mascara, uv, 1.0).r;
	float n = fbm(wp.xz * 0.02);
	vec3 cor = cor_chao * (0.82 + 0.3 * n);
	cor = mix(cor, cor * vec3(0.95, 1.04, 0.86), smoothstep(0.6, 0.85, fbm(wp.xz * 0.004)));   // manchas de mato
	cor = mix(cor, cor * vec3(1.08, 0.98, 0.9), smoothstep(0.55, 0.8, fbm(wp.xz * 0.011 + 7.0)) * 0.5);   // terra batida
	float praia = 1.0 - smoothstep(0.80, 0.96, terra);
	ALBEDO = mix(cor, cor_areia * (0.9 + 0.15 * n), praia);
	ROUGHNESS = 0.95;
}
"""

const PARQUE := """
shader_type spatial;
uniform vec3 cor_grama : source_color = vec3(0.24, 0.40, 0.17);
""" + COMUM + VERTICE_CAMADA + """
void fragment() {
	float n = fbm(wp.xz * 0.05);
	float m = fbm(wp.xz * 0.008);
	vec3 cor = cor_grama * (0.75 + 0.45 * n);
	cor = mix(cor, vec3(0.42, 0.42, 0.18), smoothstep(0.6, 0.85, m) * 0.6);     // grama seca
	ALBEDO = cor;
	ROUGHNESS = 1.0;
}
"""

const ASFALTO := """
shader_type spatial;
uniform vec3 cor : source_color = vec3(0.16, 0.16, 0.17);
""" + COMUM + VERTICE_CAMADA + """
void fragment() {
	float n = fbm(wp.xz * 0.35);
	float m = fbm(wp.xz * 0.012);
	vec3 c = cor * (0.85 + 0.3 * n) * (0.9 + 0.2 * m);
	float rachado = smoothstep(0.97, 1.0, 1.0 - abs(ruido(wp.xz * 0.08) - 0.5) * 2.0);   // rachaduras finas
	c *= 1.0 - rachado * 0.35 * (1.0 - smoothstep(80.0, 250.0, length(wp - CAMERA_POSITION_WORLD)));
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
"""

const CALCADA := """
shader_type spatial;
uniform vec3 cor : source_color = vec3(0.56, 0.54, 0.50);
""" + COMUM + VERTICE_CAMADA + """
void fragment() {
	vec2 g = abs(fract(wp.xz / 1.6) - 0.5);
	float junta = smoothstep(0.47, 0.5, max(g.x, g.y)) * (1.0 - smoothstep(30.0, 120.0, length(wp - CAMERA_POSITION_WORLD)));
	ALBEDO = cor * (0.88 + 0.18 * fbm(wp.xz * 0.6)) * (1.0 - junta * 0.25);
	ROUGHNESS = 0.9;
}
"""

const FAIXA := """
shader_type spatial;
""" + COMUM + VERTICE_CAMADA + """
void fragment() {
	ALBEDO = COLOR.rgb * (0.85 + 0.15 * ruido(wp.xz * 2.0));
	ROUGHNESS = 0.7;
}
"""

# prédios (MultiMesh): INSTANCE_CUSTOM = (largura x, altura, largura z, tipo + semente)
# tipo: 0 concreto · 1 tijolo · 2 pedra clara · 3 vidro (torres)
const PREDIO := """
shader_type spatial;
uniform float detalhe = 1.0;               // 0 = sem janelas (leve) · 1 = completo
varying vec3 lp;
varying vec3 tam;
varying float tipo;
varying float sem;
varying vec3 nl;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	tam = INSTANCE_CUSTOM.xyz;
	tipo = floor(INSTANCE_CUSTOM.w);
	sem = fract(INSTANCE_CUSTOM.w);
	lp = VERTEX * tam;
	lp.y += tam.y * 0.5;                    // altura a partir da base
	nl = NORMAL;
}
void fragment() {
	vec3 base = COLOR.rgb;
	float dist = length(VERTEX);
	if (nl.y > 0.5) {
		// telhado: laje escura com manchas + borda (platibanda)
		vec2 b = 0.5 * tam.xz - abs(lp.xz);
		float borda = 1.0 - smoothstep(0.4, 0.9, min(b.x, b.y));
		ALBEDO = mix(vec3(0.24, 0.23, 0.22) * (0.85 + 0.3 * hash(floor(lp.xz * 0.5) + sem)), base * 0.8, borda);
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
		float longe = smoothstep(450.0, 1400.0, dist);
		janela = mix(janela, 0.0, longe) * detalhe;
		// vidro: escuro, refletindo o céu mais em cima; algumas janelas acesas (quente)
		vec3 vidro = mix(vec3(0.08, 0.10, 0.13), vec3(0.45, 0.38, 0.36), clamp(v / max(tam.y, 1.0), 0.0, 1.0) * 0.6);
		float h = hash(cel + sem * 91.0);
		if (h > 0.975 && dist < 700.0) vidro = vec3(0.95, 0.72, 0.38);
		else if (h > 0.86) vidro *= 0.55;
		vec3 parede = base * (0.9 + 0.12 * hash(vec2(cel.y, sem)));
		// faixa entre andares e térreo com lojas (vitrine escura + toldo)
		float laje = corpo * step(0.92, fv) * (1.0 - longe) * detalhe;
		parede *= 1.0 - laje * 0.18;
		vec3 c = mix(parede, vidro, janela);
		float terreo = step(v, 4.6) * detalhe;
		float vitrine = terreo * step(0.6, v) * step(v, 3.4) * step(0.12, fract(u / 6.0)) * step(fract(u / 6.0), 0.88);
		float toldo = terreo * step(3.4, v) * step(v, 4.0);
		float ht = hash(vec2(floor(u / 6.0), sem));
		vec3 cor_toldo = ht < 0.33 ? vec3(0.32, 0.12, 0.10) : (ht < 0.66 ? vec3(0.12, 0.22, 0.16) : vec3(0.14, 0.15, 0.22));
		c = mix(c, vec3(0.07, 0.07, 0.08), vitrine * (1.0 - longe));
		c = mix(c, cor_toldo, toldo * (1.0 - longe));
		c *= 0.72 + 0.28 * smoothstep(0.0, 6.0, v);                                // sombra perto do chão
		ALBEDO = c;
		ROUGHNESS = mix(0.9, 0.25, janela);
		SPECULAR = mix(0.3, 0.7, janela);
	}
}
"""

static func shader(codigo: String) -> Shader:
	var s := Shader.new()
	s.code = codigo
	return s

static func material(codigo: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(codigo)
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
