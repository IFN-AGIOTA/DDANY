extends Node3D
# PONTOS TURÍSTICOS DE NOVA YORK (1.21): os lugares mais visitados da cidade de verdade, feitos olhando as fotos
# deles e encaixados no nosso mapa onde ficam em Nova York (a ilha do meio é Manhattan: a 5ª Avenida é a borda leste
# do Central Park, Midtown logo abaixo dele, Wall Street e o WTC na ponta sul; a ilhota a sudoeste é a da Estátua
# da Liberdade; Brooklyn/Queens a leste, o Bronx a nordeste). O lugar de cada um foi escolhido pelo
# ferramentas/escolher_pontos.py: um quarteirão inteiro (sem rua no meio) perto do lugar "de verdade", tirando o
# mínimo de prédios.
#   - Os PRÉDIOS que estavam no terreno saem (mundo/cidade.gd _buildings: "ponto"); os jogos salvos são convertidos
#     (remapa_v8, MAPA_PREDIOS 9 em menu/salvamento.gd). O terreno vira chão de concreto (lote) ou fica parque.
#   - As construções: mundo/pontos_obras.gd (Manhattan) e mundo/pontos_obras_fora.gd (Estátua da Liberdade, Washington
#     Square, Coney Island, Yankee Stadium, Unisphere). As fachadas dos arranha-céus têm as janelas desenhadas pelo
#     shader (FACHADA: andares, janelas quebradas, algumas luzes de sobreviventes à noite) e aparecem de longe.
#   - No MAPA cada um tem o nome (hud/mapa.gd) e, ao chegar perto, aparece o aviso com o nome e o bairro.
#   - Colisão: um StaticBody3D com as caixas de tudo (sempre na cena).
# Mexa AQUI para: a lista (lugar, tamanho, giro, nome) e os materiais. Desenho de cada um: pontos_obras*.gd.

const CP := preload("res://mundo/central_park.gd")
const Mat := preload("res://mundo/materiais_cidade.gd")

# [tipo, x, z, largura (x), profundidade (z), giro (rad: para onde fica a frente; 0 = sul +Z), nome, bairro, chão]
# chão: "lote" = concreto na altura da calçada · "parque" = fica a grama
const LISTA := [
	["liberty", -3010.0, 4700.0, 140.0, 140.0, 0.6, "ESTÁTUA DA LIBERDADE", "Liberty Island", "parque"],
	["empire", -1292.0, 998.0, 140.0, 70.0, PI * 0.5, "EMPIRE STATE BUILDING", "Midtown · 5ª Avenida", "lote"],
	["times_square", -2084.0, 250.0, 130.0, 170.0, 0.0, "TIMES SQUARE", "Midtown · Broadway", "lote"],
	["chrysler", -766.0, 470.0, 60.0, 60.0, 0.0, "CHRYSLER BUILDING", "Midtown · Lexington", "lote"],
	["grand_central", -924.0, 602.0, 150.0, 90.0, 0.0, "GRAND CENTRAL TERMINAL", "Midtown · rua 42", "lote"],
	["rockefeller", -1582.0, 266.0, 110.0, 140.0, PI * 0.5, "ROCKEFELLER CENTER", "Midtown · 5ª Avenida", "lote"],
	["st_patrick", -1114.0, 104.0, 110.0, 60.0, -PI * 0.5, "CATEDRAL DE ST. PATRICK", "Midtown · 5ª Avenida", "lote"],
	["wtc", -2084.0, 3732.0, 200.0, 140.0, 0.0, "ONE WORLD TRADE CENTER E MEMORIAL 11/9", "Lower Manhattan", "lote"],
	["flatiron", -1318.0, 1494.0, 90.0, 60.0, 0.0, "FLATIRON BUILDING", "Madison Square", "lote"],
	["wall_street", -1604.0, 4160.0, 80.0, 80.0, 0.0, "WALL STREET · BOLSA DE NOVA YORK", "Financial District", "lote"],
	["washington_sq", -1486.0, 2188.0, 150.0, 150.0, PI, "WASHINGTON SQUARE PARK", "Greenwich Village", "lote"],
	["vessel", -2724.0, 776.0, 90.0, 90.0, 0.0, "THE VESSEL · HUDSON YARDS", "Hudson Yards", "lote"],
	["un", -382.0, 660.0, 230.0, 110.0, 0.0, "SEDE DA ONU", "Turtle Bay · East River", "lote"],
	["guggenheim", -1120.0, -1050.0, 70.0, 70.0, -PI * 0.5, "MUSEU GUGGENHEIM", "Upper East Side · 5ª Avenida", "lote"],
	["coney", 1852.0, 4384.0, 330.0, 110.0, 0.0, "CONEY ISLAND", "Brooklyn", "lote"],
	["yankee", 244.0, -2884.0, 230.0, 230.0, 0.0, "YANKEE STADIUM", "Bronx", "lote"],
	["unisphere", 3408.0, -464.0, 140.0, 140.0, 0.0, "UNISPHERE · FLUSHING MEADOWS", "Queens", "lote"],
]
const MARGEM_PREDIO := 2.0              # prédio a menos que isso do terreno também sai
const RAIO_AVISO := 25.0                # chegou a isso do terreno: aviso com o nome
const ENTORNO := 30.0                   # o chão em volta (até isso do terreno, fora da rua) também vira calçada

static func retangulo(i: int, margem := 0.0) -> Rect2:
	var e: Array = LISTA[i]
	return Rect2(float(e[1]) - float(e[3]) * 0.5, float(e[2]) - float(e[4]) * 0.5, float(e[3]), float(e[4])).grow(margem)

# o prédio (planta) cai em algum ponto turístico?
static func em(planta: Rect2) -> bool:
	for i in LISTA.size():
		if retangulo(i, MARGEM_PREDIO).intersects(planta):
			return true
	return false

static func indice_em(p: Vector2, margem := 0.0) -> int:
	for i in LISTA.size():
		if retangulo(i, margem).has_point(p):
			return i
	return -1

# ---------------------------------------------------------------------------------------------------------------
# MATERIAIS (os do Central Park + fachadas com janelas, telões de LED e aço inox)
# ---------------------------------------------------------------------------------------------------------------
# FACHADA: janelas pela altura do mundo (os andares batem entre blocos diferentes) e pela largura da face (UV.x);
# o resto é a parede (cor do vértice + textura). Janelas quebradas (pretas) e, à noite, umas poucas acesas.
const SHADER_FACHADA := """
shader_type spatial;
uniform vec3 cor_vidro : source_color = vec3(0.12, 0.15, 0.18);
uniform vec2 janela = vec2(1.4, 2.1);
uniform vec2 passo = vec2(2.6, 3.8);
uniform float y0 = 6.0;
uniform float reflexo = 0.35;
uniform float forca = 0.5;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
global uniform float noite;
global uniform float molhado;
varying vec3 wp;
varying vec3 nw;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash(vec2 p) { p = mod(p, 4096.0); vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
void fragment() {
	float vert = 1.0 - step(0.6, abs(nw.y));
	vec2 u = vec2(UV.x, wp.y - y0);
	vec2 cel = floor(u / passo);
	vec2 g = fract(u / passo) * passo - passo * 0.5;
	float jan = step(abs(g.x), janela.x * 0.5) * step(abs(g.y), janela.y * 0.5) * vert * step(0.0, u.y);
	vec3 m = max(textureLod(tex, vec2(0.5), 10.0).rgb, vec3(0.04));
	vec3 parede = COLOR.rgb * mix(vec3(1.0), texture(tex, vec2(UV.x, wp.y) / 3.0).rgb / m, forca);
	float h = hash(cel + vec2(floor(wp.x * 0.07), floor(wp.z * 0.07)) * 17.0);
	vec3 vidro = cor_vidro * (0.7 + 0.6 * h);
	vec3 c = mix(parede, vidro, jan);
	c = mix(c, vec3(0.012), jan * step(0.93, h));
	ALBEDO = c * mix(1.0, 0.75, molhado);
	ROUGHNESS = mix(0.85, 0.12, jan);
	METALLIC = jan * reflexo;
	SPECULAR = mix(0.25, 0.6, jan);
	EMISSION = vec3(1.0, 0.78, 0.45) * jan * step(0.988, h) * noite * 2.2;
}
"""

# TELÃO de LED (Times Square; material "telao"): COLOR.r = semente, COLOR.g/b = largura/altura do telão / 64 (a caixa não escurece
# embaixo: ao 0). Imagens que trocam (cores, faixas, "letras"); uns telões queimados (pretos, piscando).
const SHADER_TELA := """
shader_type spatial;
render_mode unshaded;
global uniform float noite;
float hash(vec2 p) { p = mod(p, 4096.0); vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec3 paleta(float t) { return 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + t)); }
void fragment() {
	float s = COLOR.r;
	vec2 tam = max(COLOR.gb * 64.0, vec2(0.5));
	vec2 uv = clamp(UV / tam, 0.0, 1.0);
	float t = TIME * 0.35 + s * 40.0;
	float cena = floor(t * 0.2);
	float k = hash(vec2(cena, s * 97.0));
	vec3 a = paleta(k);
	vec3 b = paleta(k + 0.45);
	vec3 c;
	if (k < 0.33) {
		c = mix(a, b, smoothstep(0.2, 0.8, uv.x + 0.25 * sin(uv.y * 6.0 + t * 2.0)));
	} else if (k < 0.66) {
		float faixa = step(0.5, fract(uv.y * 6.0 - t * 0.6));
		c = mix(a * 0.4, b, faixa);
		vec2 bl = floor(uv * vec2(14.0, 5.0));
		c = mix(c, vec3(1.0), step(0.72, hash(bl + cena)) * step(0.3, uv.y) * step(uv.y, 0.55));
	} else {
		float r = length(uv - vec2(0.5 + 0.2 * sin(t), 0.5));
		c = mix(b, a, smoothstep(0.1, 0.5, r));
		c = mix(c, vec3(0.05), step(0.45, abs(uv.y - 0.5)));
	}
	vec2 px = fract(UV * 6.0);
	c *= 0.82 + 0.18 * step(0.15, px.x) * step(0.15, px.y);
	float morto = step(0.86, s);
	float pisca = step(0.5, fract(TIME * (3.0 + s * 7.0)));
	c = mix(c, vec3(0.02) + vec3(0.25) * pisca * step(0.93, s), morto);
	ALBEDO = c * (0.75 + 0.25 * noite);
}
"""

# o teto do MAIN CONCOURSE da Grand Central: verde-azulado com as constelações douradas (estrelas acesas)
const SHADER_CEU_GC := """
shader_type spatial;
render_mode cull_disabled;
float hash(vec2 p) { p = mod(p, 4096.0); vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
void fragment() {
	vec2 u = UV;
	vec3 c = vec3(0.2, 0.38, 0.38) * (0.85 + 0.15 * hash(floor(u * 0.5)));
	vec2 g = floor(u * 1.2);
	vec2 f = fract(u * 1.2) - 0.5;
	float h = hash(g);
	float estrela = (1.0 - smoothstep(0.02, 0.09, length(f))) * step(0.82, h);
	float linha = (1.0 - smoothstep(0.0, 0.04, abs(fract(u.x * 0.06 + u.y * 0.03) - 0.5))) * 0.35;
	c = mix(c, vec3(0.85, 0.72, 0.35), clamp(estrela + linha * step(0.5, fract(u.y * 0.02)), 0.0, 1.0));
	ALBEDO = c;
	EMISSION = vec3(0.9, 0.8, 0.5) * estrela * 0.6;
	ROUGHNESS = 0.8;
}
"""

# a PISCINA do Memorial 11/9 sem cavar o chão: o quadrado no chão desenha o buraco por "interior mapping" (o raio da
# câmera entra no quadrado e bate nas paredes de granito com a cortina de água, no espelho d'água que corre para o
# meio, e no VAZIO quadrado do meio, que desce mais e some no escuro). UV = posição no quadrado (m, centro = 0).
const SHADER_PISCINA := """
shader_type spatial;
uniform float meia = 23.0;
uniform float fundo = 7.0;
uniform float vazio = 7.5;
uniform float fundo_vazio = 7.0;
global uniform float noite;
varying vec3 centro;
varying vec3 cam;
float hash(vec2 p) { p = mod(p, 4096.0); vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float ruido(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y); }
float caixa(vec3 p, vec3 d, float m, float yf) {
	float sx = d.x >= 0.0 ? 1.0 : -1.0;
	float sz = d.z >= 0.0 ? 1.0 : -1.0;
	float tx = (sx * m - p.x) / (abs(d.x) > 1e-5 ? d.x : sx * 1e-5);
	float tz = (sz * m - p.z) / (abs(d.z) > 1e-5 ? d.z : sz * 1e-5);
	float tf = (yf - p.y) / d.y;
	return min(min(tx, tz), tf);
}
vec3 cortina(vec3 q, float topo, float alt, float claro) {
	float h = clamp((topo - q.y) / alt, 0.0, 1.0);
	float faixa = ruido(vec2((q.x + q.z) * 2.6, q.y * 0.9 + TIME * 3.0)) * 0.6 + ruido(vec2((q.x - q.z) * 7.0, q.y * 2.0 + TIME * 5.0)) * 0.4;
	vec3 agua = vec3(0.78, 0.82, 0.86) * (0.5 + 0.5 * faixa) * claro;
	return mix(agua, vec3(0.07, 0.075, 0.08), 0.15 + 0.55 * h);
}
void vertex() {
	centro = VERTEX - vec3(UV.x, 0.0, UV.y);
	cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}
void fragment() {
	vec3 p = vec3(UV.x, 0.0, UV.y);
	vec3 d = normalize(p - (cam - centro));
	vec3 cor = vec3(0.05);
	float prof = 0.0;
	if (d.y < -0.0005) {
		float t = caixa(p, d, meia, -fundo);
		vec3 q = p + d * t;
		prof = -q.y;
		if (q.y < -fundo + 0.01) {
			if (max(abs(q.x), abs(q.z)) < vazio) {
				float t2 = caixa(q, d, vazio, -fundo - fundo_vazio);
				vec3 q2 = q + d * t2;
				prof = -q2.y;
				cor = q2.y < -fundo - fundo_vazio + 0.01 ? vec3(0.005) : cortina(q2, -fundo, fundo_vazio, 0.55) * (1.0 - clamp((-fundo - q2.y) / fundo_vazio, 0.0, 1.0));
			} else {
				vec2 rumo = -normalize(q.xz + vec2(0.001));
				float o = ruido(q.xz * 1.2 + rumo * TIME * 1.4) * 0.6 + ruido(q.xz * 4.0 + rumo * TIME * 2.5) * 0.4;
				cor = vec3(0.13, 0.17, 0.2) * (0.7 + 0.6 * o);
				float e = max(abs(q.x), abs(q.z));
				cor = mix(cor, vec3(0.6, 0.65, 0.7) * (0.6 + 0.4 * o), (1.0 - smoothstep(0.0, 1.6, e - vazio)) * 0.6);
				cor = mix(cor, vec3(0.75, 0.8, 0.85) * (0.6 + 0.4 * o), smoothstep(meia - 1.8, meia, e) * 0.7);
			}
		} else {
			cor = cortina(q, 0.0, fundo, 1.0);
		}
	}
	cor *= 1.0 - 0.45 * clamp(prof / (fundo + fundo_vazio), 0.0, 1.0);
	ALBEDO = cor * (1.0 - 0.6 * noite);
	EMISSION = cor * noite * 0.55;                // à noite as luzes dentro da piscina acendem a cortina d'água
	ROUGHNESS = 0.35;
	SPECULAR = 0.25;
}
"""

static var _mats := {}

static func mat(nome: String) -> Material:
	if _mats.has(nome):
		return _mats[nome]
	var m: Material = null
	if nome.begins_with("fachada_"):
		var sm := ShaderMaterial.new()
		sm.shader = Mat.shader(SHADER_FACHADA)
		var p: Dictionary = {
			"fachada_pedra": {"tex": "predio_pedra", "vidro": Color(0.1, 0.12, 0.14), "jan": Vector2(1.3, 2.2), "passo": Vector2(2.4, 3.9), "refl": 0.3, "forca": 0.55},
			"fachada_tijolo": {"tex": "predio_tijolo", "vidro": Color(0.1, 0.11, 0.12), "jan": Vector2(1.2, 2.0), "passo": Vector2(2.2, 3.6), "refl": 0.25, "forca": 0.5},
			"fachada_branca": {"tex": "predio_concreto", "vidro": Color(0.08, 0.1, 0.12), "jan": Vector2(1.2, 2.1), "passo": Vector2(2.2, 3.7), "refl": 0.25, "forca": 0.35},
			"fachada_vidro": {"tex": "predio_concreto", "vidro": Color(0.28, 0.4, 0.5), "jan": Vector2(1.45, 3.6), "passo": Vector2(1.55, 3.9), "refl": 0.75, "forca": 0.1},
			"fachada_vidro_verde": {"tex": "predio_concreto", "vidro": Color(0.2, 0.36, 0.33), "jan": Vector2(1.6, 3.2), "passo": Vector2(1.75, 3.6), "refl": 0.6, "forca": 0.1},
			"fachada_escritorio": {"tex": "predio_concreto", "vidro": Color(0.16, 0.2, 0.24), "jan": Vector2(2.6, 2.4), "passo": Vector2(3.2, 3.8), "refl": 0.5, "forca": 0.3},
		}.get(nome, {})
		sm.set_shader_parameter("tex", load("res://mundo/texturas/%s.jpg" % String(p.get("tex", "predio_concreto"))))
		sm.set_shader_parameter("cor_vidro", p.get("vidro", Color(0.12, 0.15, 0.18)))
		sm.set_shader_parameter("janela", p.get("jan", Vector2(1.4, 2.1)))
		sm.set_shader_parameter("passo", p.get("passo", Vector2(2.6, 3.8)))
		sm.set_shader_parameter("reflexo", p.get("refl", 0.35))
		sm.set_shader_parameter("forca", p.get("forca", 0.5))
		m = sm
	elif nome == "telao":
		var sm2 := ShaderMaterial.new()
		sm2.shader = Mat.shader(SHADER_TELA)
		m = sm2
	elif nome == "piscina_memorial":
		var sm7 := ShaderMaterial.new()
		sm7.shader = Mat.shader(SHADER_PISCINA)
		m = sm7
	elif nome == "areia":
		var sm8 := ShaderMaterial.new()
		sm8.shader = Mat.shader(CP.SHADER_OBRA)
		sm8.set_shader_parameter("tex", load("res://mundo/texturas/predio_concreto.jpg"))
		sm8.set_shader_parameter("escala", 3.0)
		sm8.set_shader_parameter("forca", 0.35)
		sm8.set_shader_parameter("musgo", 0.0)
		sm8.set_shader_parameter("rugosidade", 0.95)
		m = sm8
	elif nome == "ceu_gc":
		var sm5 := ShaderMaterial.new()
		sm5.shader = Mat.shader(SHADER_CEU_GC)
		m = sm5
	elif nome == "ouro":
		var sm6 := ShaderMaterial.new()
		sm6.shader = Mat.shader(CP.SHADER_OBRA)
		sm6.set_shader_parameter("tex", load("res://mundo/texturas/predio_concreto.jpg"))
		sm6.set_shader_parameter("escala", 3.0)
		sm6.set_shader_parameter("forca", 0.1)
		sm6.set_shader_parameter("musgo", 0.0)
		sm6.set_shader_parameter("rugosidade", 0.3)
		sm6.set_shader_parameter("metal", 0.85)
		m = sm6
	elif nome == "aco":
		var sm3 := ShaderMaterial.new()
		sm3.shader = Mat.shader(CP.SHADER_OBRA)
		sm3.set_shader_parameter("tex", load("res://mundo/texturas/predio_concreto.jpg"))
		sm3.set_shader_parameter("escala", 4.0)
		sm3.set_shader_parameter("forca", 0.08)
		sm3.set_shader_parameter("musgo", 0.05)
		sm3.set_shader_parameter("rugosidade", 0.22)
		sm3.set_shader_parameter("metal", 0.92)
		m = sm3
	elif nome == "cobre":
		var sm4 := ShaderMaterial.new()
		sm4.shader = Mat.shader(CP.SHADER_OBRA)
		sm4.set_shader_parameter("tex", load("res://mundo/texturas/predio_concreto.jpg"))
		sm4.set_shader_parameter("escala", 2.0)
		sm4.set_shader_parameter("forca", 0.45)
		sm4.set_shader_parameter("musgo", 0.0)
		sm4.set_shader_parameter("rugosidade", 0.6)
		sm4.set_shader_parameter("metal", 0.25)
		m = sm4
	else:
		m = CP.mat(nome)
	_mats[nome] = m
	return m

# ---------------------------------------------------------------------------------------------------------------
# MONTAGEM (mundo/cidade.gd: etapa "Pontos turísticos de Nova York")
# ---------------------------------------------------------------------------------------------------------------
var visuais: Array = []
var corpo: StaticBody3D
var construcoes := {}
var escadas: Array = []
var pontos_altos := {}
var obstaculos := PackedFloat32Array()          # postes e bancos (formato do mundo/colisao_mundo.gd)
var arvores: Array = []                          # [modelo, posição, giro, escala]: a cidade planta (mundo/arvores.gd)
var postes: Array = []                           # Vector3 (o poste do Central Park)
var bancos: Array = []                           # [Vector3, giro] (o banco do Central Park)
var _dentro := -1
var hud = null                                   # armas/hud_combate.gd (aviso ao chegar): main.gd liga

func montar(cidade: Node) -> void:
	corpo = StaticBody3D.new()
	corpo.name = "PontosColisao"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var Obras = load("res://mundo/pontos_obras_fora.gd")     # (estende o pontos_obras.gd: Manhattan + fora)
	var obras = Obras.new(self)
	for i in LISTA.size():
		var e: Array = LISTA[i]
		var y: float = cidade.Y_CALCADA if String(e[8]) == "lote" else cidade.Y_PARQUE
		obras.montar(String(e[0]), Vector3(float(e[1]), y, float(e[2])), float(e[5]), {"largura": float(e[3]), "fundo": float(e[4])})
		construcoes[String(e[0])] = int(construcoes.get(String(e[0]), 0)) + 1
		await cidade.pausa()
	_postes_e_bancos()
	print("Pontos turísticos: %d construídos · %d formas de colisão · %d árvores · %d postes · %d bancos" % [construcoes.size(),
		corpo.get_child_count(), arvores.size(), postes.size(), bancos.size()])

# postes e bancos (as malhas do Central Park), um MultiMesh por ponto turístico, e os obstáculos deles
func _postes_e_bancos() -> void:
	var grupos := {"poste": {}, "banco": {}}
	for p: Vector3 in postes:
		var k := indice_em(Vector2(p.x, p.z), 4.0)
		if not grupos["poste"].has(k):
			grupos["poste"][k] = []
		grupos["poste"][k].append(Transform3D(Basis.IDENTITY, p))
		obstaculos.append_array(PackedFloat32Array([p.x, p.z, 0.0, 0.35, 3.0, 0.35, p.y + 1.5]))
	for b in bancos:
		var p2: Vector3 = b[0]
		var k2 := indice_em(Vector2(p2.x, p2.z), 4.0)
		if not grupos["banco"].has(k2):
			grupos["banco"][k2] = []
		grupos["banco"][k2].append(Transform3D(Basis(Vector3.UP, float(b[1])), p2))
		obstaculos.append_array(PackedFloat32Array([p2.x, p2.z, float(b[1]), 1.9, 0.9, 0.6, p2.y + 0.45]))
	for tipo in grupos:
		var malha: ArrayMesh = CP.malha_poste() if tipo == "poste" else CP.malha_banco()
		for k in grupos[tipo]:
			var lista: Array = grupos[tipo][k]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = malha
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, lista[i])
			var mi := MultiMeshInstance3D.new()
			mi.name = "PT_%s_%d" % [tipo, k]
			mi.multimesh = mm
			mi.visibility_range_end = CP.ALCANCE_POSTE if tipo == "poste" else CP.ALCANCE_BANCO
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tipo == "poste" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			visuais.append(mi)

func col(c: Vector3, tam: Vector3, b := Basis.IDENTITY) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	cs.transform = Transform3D(b, c)
	corpo.add_child(cs)

# colisão convexa (pontos no mundo): o Flatiron, rampas tortas...
func col_convexo(vs: PackedVector3Array) -> void:
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	sh.points = vs
	cs.shape = sh
	corpo.add_child(cs)

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

# aviso ao chegar perto de um ponto turístico (o jogador; a cada 0,5 s)
var _t := 0.0
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var main = get_tree().current_scene
	var j = main.get("jogador") if main != null else null
	var p: Vector3 = j.global_position if j != null and is_instance_valid(j) else cam.global_position
	var agora := indice_em(Vector2(p.x, p.z), RAIO_AVISO)
	if agora != _dentro:
		_dentro = agora
		if agora >= 0 and hud != null and is_instance_valid(hud) and hud.has_method("mostrar_aviso"):
			hud.mostrar_aviso("%s · %s" % [LISTA[agora][6], LISTA[agora][7]], 5.0)

# ---------------------------------------------------------------------------------------------------------------
# MAPA (hud/mapa.gd): o terreno de cada um (desenho da cidade) e o nome com uma estrela (com zoom)
# ---------------------------------------------------------------------------------------------------------------
const COR_MAPA := Color(1.0, 0.82, 0.35)

static func desenhar_terrenos(ci: CanvasItem, cor_calcada: Color) -> void:
	for i in LISTA.size():
		ci.draw_rect(retangulo(i), cor_calcada.lerp(COR_MAPA, 0.22))

static func pontos_mapa() -> Array:
	var r: Array = []
	for e in LISTA:
		r.append([Vector2(float(e[1]), float(e[2])), String(e[6])])
	return r
