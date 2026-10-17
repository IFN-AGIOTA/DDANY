extends Node
# CLIMA · DIA/NOITE, CHUVA, TEMPERATURA e LANTERNA.
#  - DIA E NOITE: a hora anda sozinha (um dia inteiro = DURACAO_DIA segundos de verdade). O sol cruza o céu
#    e muda de cor: madrugada azul, amanhecer laranja, dia branco-quente, entardecer laranja/vermelho e noite
#    com LUAR azulado fraco (escuro, mas dá para ver as ruas no celular). Céu, luz ambiente, neblina,
#    exposição e o reflexo do mar acompanham. O céu só é atualizado a cada TICK_CEU segundos (mexer no céu
#    obriga a Godot a redesenhar o reflexo do céu, que pesa no celular; o sol anda tão devagar que não se nota).
#  - TEMPO: estados limpo / nublado / chuva / tempestade, que trocam sozinhos depois de alguns minutos e
#    passam devagar de um para o outro. Nublado escurece o sol e deixa céu/neblina cinzas; chuva engrossa a
#    neblina. Chuva visível = 1 malha só com até 1500 riscos que caem e "dão a volta" em volta da câmera
#    (tudo no shader, sem custo de CPU). Som de chuva e trovões sintetizados por código (sem arquivos).
#    Na tempestade: relâmpago (luz extra piscando) e trovão depois (mais longe = mais atrasado e grave).
#  - TEMPERATURA do ar (°C) pela hora e pela chuva · exposto(pos) diz se tem teto em cima (para molhar).
#  - LANTERNA: "lanterna" nas MÃOS ou "lanterna_cabeca" na CABEÇA acende uma luz que aponta para onde a
#    câmera olha (sem sombra, para o celular aguentar).
#  - salvar() / carregar(d) para o save · restaurar() devolve sol e céu da cidade como estavam.
# Uso (main.gd): clima = ClimaCls.new(); jogo.add_child(clima); clima.ligar(cidade, jogador).
# Mexa AQUI para: duração do dia, hora inicial, cores do céu em cada hora (tabela HORAS), força do luar,
# quanto tempo dura cada tempo (TEMPOS) e a chance de um virar o outro (PROXIMO), quantidade/velocidade da
# chuva, frequência dos trovões, temperatura e a força/alcance da lanterna.

const DURACAO_DIA := 2880.0          # segundos de verdade por dia de jogo (48 min)
const HORA_INICIAL := 8.0
const TICK_CEU := 0.5                # de quanto em quanto tempo céu/sol/neblina são atualizados (s)
const TICK_LANTERNA := 0.2           # de quanto em quanto tempo olha o inventário (s)
const TICK_ABRIGO := 0.25            # de quanto em quanto tempo vê se tem teto em cima da câmera (s)
const REFLEXO_LIMIAR := 0.03         # quanto céu/sol precisam mudar para refazer o reflexo do céu
const REFLEXO_MIN_S := 15.0          # e no mínimo esse tempo entre um e outro (cada refação trava alguns ms)

# sol: nasce às 6h e se põe às 19h30; altura máxima (graus) ao meio-dia
const NASCER := 6.0
const POR := 19.5
const SOL_ALTURA_MAX := 65.0
const LUA_COR := Color(0.62, 0.72, 1.0)
const LUA_ENERGIA := 0.12            # luar (0.08 - 0.12: escuro mas dá para ver)

# cada hora-chave: cor/força do sol, céu (topo e horizonte), neblina, luz ambiente, exposição e escuridão.
# amb_cor/amb_ceu: parte da luz ambiente vem de uma cor fixa (amb_cor) para a noite não ficar preta.
const HORAS := [
	{"h": 0.0, "sol": Color(1.0, 0.7, 0.5), "e": 0.0, "topo": Color(0.012, 0.018, 0.045), "hor": Color(0.05, 0.065, 0.11),
		"nev": Color(0.045, 0.06, 0.10), "amb": 1.0, "amb_cor": Color(0.25, 0.28, 0.40), "amb_ceu": 0.2, "exp": 1.5, "nd": 1.3, "esc": 1.0},
	{"h": 4.6, "sol": Color(1.0, 0.7, 0.5), "e": 0.0, "topo": Color(0.012, 0.018, 0.045), "hor": Color(0.05, 0.065, 0.11),
		"nev": Color(0.045, 0.06, 0.10), "amb": 1.0, "amb_cor": Color(0.25, 0.28, 0.40), "amb_ceu": 0.2, "exp": 1.5, "nd": 1.3, "esc": 1.0},
	{"h": 5.5, "sol": Color(1.0, 0.55, 0.40), "e": 0.0, "topo": Color(0.06, 0.09, 0.20), "hor": Color(0.36, 0.30, 0.38),
		"nev": Color(0.30, 0.27, 0.33), "amb": 1.0, "amb_cor": Color(0.27, 0.27, 0.34), "amb_ceu": 0.5, "exp": 1.35, "nd": 1.6, "esc": 0.65},
	{"h": 6.5, "sol": Color(1.0, 0.56, 0.30), "e": 0.7, "topo": Color(0.18, 0.28, 0.50), "hor": Color(0.98, 0.62, 0.40),
		"nev": Color(0.86, 0.60, 0.46), "amb": 0.9, "amb_cor": Color(0.20, 0.17, 0.16), "amb_ceu": 0.9, "exp": 1.1, "nd": 1.7, "esc": 0.15},
	{"h": 8.0, "sol": Color(1.0, 0.86, 0.70), "e": 1.05, "topo": Color(0.22, 0.38, 0.66), "hor": Color(0.86, 0.80, 0.72),
		"nev": Color(0.80, 0.76, 0.70), "amb": 0.9, "amb_cor": Color(0.0, 0.0, 0.0), "amb_ceu": 1.0, "exp": 1.05, "nd": 1.15, "esc": 0.0},
	{"h": 12.0, "sol": Color(1.0, 0.96, 0.88), "e": 1.25, "topo": Color(0.20, 0.40, 0.76), "hor": Color(0.74, 0.81, 0.88),
		"nev": Color(0.74, 0.79, 0.84), "amb": 0.9, "amb_cor": Color(0.0, 0.0, 0.0), "amb_ceu": 1.0, "exp": 1.0, "nd": 1.0, "esc": 0.0},
	{"h": 16.0, "sol": Color(1.0, 0.89, 0.74), "e": 1.2, "topo": Color(0.21, 0.37, 0.68), "hor": Color(0.86, 0.78, 0.66),
		"nev": Color(0.84, 0.75, 0.63), "amb": 0.9, "amb_cor": Color(0.0, 0.0, 0.0), "amb_ceu": 1.0, "exp": 1.03, "nd": 1.0, "esc": 0.0},
	{"h": 18.0, "sol": Color(1.0, 0.78, 0.56), "e": 1.15, "topo": Color(0.20, 0.33, 0.60), "hor": Color(0.98, 0.66, 0.42),
		"nev": Color(0.92, 0.64, 0.45), "amb": 0.9, "amb_cor": Color(0.0, 0.0, 0.0), "amb_ceu": 1.0, "exp": 1.05, "nd": 1.0, "esc": 0.0},
	{"h": 19.1, "sol": Color(1.0, 0.42, 0.22), "e": 0.75, "topo": Color(0.13, 0.17, 0.36), "hor": Color(0.92, 0.40, 0.26),
		"nev": Color(0.66, 0.38, 0.32), "amb": 0.95, "amb_cor": Color(0.16, 0.12, 0.14), "amb_ceu": 0.85, "exp": 1.15, "nd": 1.05, "esc": 0.3},
	{"h": 20.2, "sol": Color(1.0, 0.42, 0.22), "e": 0.0, "topo": Color(0.035, 0.05, 0.13), "hor": Color(0.17, 0.15, 0.26),
		"nev": Color(0.13, 0.12, 0.20), "amb": 1.0, "amb_cor": Color(0.26, 0.27, 0.38), "amb_ceu": 0.4, "exp": 1.4, "nd": 1.15, "esc": 0.75},
	{"h": 21.5, "sol": Color(1.0, 0.7, 0.5), "e": 0.0, "topo": Color(0.012, 0.018, 0.045), "hor": Color(0.05, 0.065, 0.11),
		"nev": Color(0.045, 0.06, 0.10), "amb": 1.0, "amb_cor": Color(0.25, 0.28, 0.40), "amb_ceu": 0.2, "exp": 1.5, "nd": 1.3, "esc": 1.0},
]

# tempos: nuvens e chuva-alvo, duração (min..max, segundos de verdade)
const TEMPOS := {
	"limpo": {"nuvens": 0.0, "chuva": 0.0, "dur": Vector2(360.0, 900.0)},
	"nublado": {"nuvens": 0.75, "chuva": 0.0, "dur": Vector2(240.0, 600.0)},
	"chuva": {"nuvens": 0.92, "chuva": 0.55, "dur": Vector2(180.0, 480.0)},
	"tempestade": {"nuvens": 1.0, "chuva": 1.0, "dur": Vector2(120.0, 300.0)},
}
# chance de cada tempo virar o próximo
const PROXIMO := {
	"limpo": {"limpo": 0.3, "nublado": 0.7},
	"nublado": {"limpo": 0.4, "chuva": 0.45, "tempestade": 0.15},
	"chuva": {"nublado": 0.5, "tempestade": 0.25, "limpo": 0.25},
	"tempestade": {"chuva": 0.7, "nublado": 0.3},
}
const VEL_NUVENS := 1.0 / 90.0       # quanto as nuvens mudam por segundo (0..1 em 1,5 min)
const VEL_CHUVA := 1.0 / 120.0       # idem para a chuva (0..1 em 2 min)

# chuva visível
const GOTAS := 1500                  # máximo de riscos de chuva
const CAIXA_CHUVA := Vector3(20.0, 15.0, 20.0)   # volume em volta da câmera onde a chuva aparece (m)
const VEL_GOTA := 11.0               # m/s
const TROVAO_INTERVALO := Vector2(10.0, 35.0)    # segundos entre relâmpagos na tempestade

# temperatura (°C)
const TEMP_MEDIA := 15.5
const TEMP_VARIACAO := 6.5           # 22 °C às 15h e 9 °C às 3h com céu limpo
const TEMP_CHUVA := 6.0              # quanto a chuva forte esfria

# lanterna
const LANTERNA_COR := Color(1.0, 0.93, 0.80)
const LANTERNA_ENERGIA := 3.0
const LANTERNA_ALCANCE := 35.0
const LANTERNA_ANGULO := 28.0
const CABECA_ENERGIA := 1.9
const CABECA_ALCANCE := 28.0
const CABECA_ANGULO := 32.0

const TAXA := 22050                  # taxa dos sons sintetizados

const SHADER_CHUVA := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 caixa = vec3(20.0, 15.0, 20.0);
uniform float quantidade = 0.0;              // 0..1 das gotas aparecem
uniform float velocidade = 11.0;
uniform vec2 vento = vec2(0.0);
uniform float comprimento = 0.75;
uniform vec4 cor : source_color = vec4(0.75, 0.78, 0.82, 0.35);
varying float alfa;
void vertex() {
	float r = UV2.x;
	alfa = 0.0;
	vec3 cam = CAMERA_POSITION_WORLD;
	if (r < quantidade) {
		float v = velocidade * (0.85 + 0.3 * fract(r * 37.13));
		vec3 queda = vec3(vento.x, -v, vento.y);
		vec3 dir = normalize(queda);
		vec3 canto = cam - caixa * 0.5;
		vec3 w = canto + mod(VERTEX + queda * TIME - canto, caixa);
		vec3 para_cam = cam - w;
		float dist = length(para_cam);
		vec3 lado = normalize(cross(dir, para_cam));
		float larg = clamp(dist * 0.0018, 0.008, 0.04);
		float comp = comprimento * (0.8 + 0.4 * fract(r * 91.7));
		vec3 p = w + lado * UV.x * larg + dir * (UV.y * comp);
		VERTEX = p - NODE_POSITION_WORLD;
		vec3 rel = abs(w - cam) / (caixa * 0.5);
		alfa = (1.0 - smoothstep(0.6, 1.0, max(rel.x, max(rel.y, rel.z)))) * smoothstep(0.5, 1.5, dist);
	} else {
		VERTEX = vec3(0.0);
	}
}
void fragment() {
	ALBEDO = cor.rgb;
	ALPHA = cor.a * alfa * sin(UV.y * 3.14159) * (1.0 - abs(UV.x) * 0.5);
}
"""

# ---------- estado público ----------
var hora := HORA_INICIAL             # 0..24
var dia := 1                         # quantos dias se passaram (conta ao passar da meia-noite)
var parado := false                  # história pode congelar a hora (e a troca automática do tempo)
var nevoa_extra := 1.0               # multiplica a neblina (a abertura da história usa mais neblina)
var som_mudo := false                # silencia chuva/trovão (abertura da história, que tem a própria música)
var chuva := 0.0                     # 0..1 (força da chuva agora)
var nuvens := 0.0                    # 0..1 (céu coberto)
var estado := "limpo"                # limpo · nublado · chuva · tempestade
var lanterna_acesa := false          # a lanterna (mão ou cabeça) está acesa agora
var molhado := 0.0                   # 0..1 chão e paredes molhados (molha rápido na chuva, seca devagar)
var neblina_manha := 0.0             # 0..1 neblina baixa do amanhecer agora (mais forte perto do mar/rios)

var cidade: Node3D
var jogador: Node3D

# ---------- interno ----------
var _t_estado := 600.0               # segundos até o próximo tempo
var _alvo_nuvens := 0.0
var _alvo_chuva := 0.0
var _escuridao := 0.0
var _t_ceu := 0.0
var _t_lanterna := 0.0
var _t_abrigo := 0.0
var _coberto := false                # câmera e jogador debaixo de teto (dentro de prédio)
var _chuva_visual := 0.0             # chuva mostrada (some dentro dos prédios)
var _amb_base := 0.9
var _nevoa_base := 0.0006
var _nevoa_posta := -1.0
var _rng := RandomNumberGenerator.new()
var _assinatura_reflexo: Array = []
var refletiu := 0                    # quantas vezes o reflexo do céu foi refeito (para testes)
var _ult_reflexo := -100000          # quando foi a última vez (ms)

var _ceu: ProceduralSkyMaterial
var _malha_chuva: MeshInstance3D
var _mat_chuva: ShaderMaterial
var _som_chuva: AudioStreamPlayer
var _som_trovao: AudioStreamPlayer
var _relampago: DirectionalLight3D
var _t_relampago := 20.0
var _flash := 0.0                    # força do relâmpago (0..1), cai rápido
var _piscadas: Array = []            # [tempo, força] das piscadas do relâmpago em andamento
var _t_flash := 0.0
var _trovao_em := -1.0               # segundos até o trovão tocar (-1 = nenhum)
var _trovao_vol := 0.0
var _lanterna_mao: SpotLight3D
var _lanterna_cabeca: SpotLight3D
var _tipo_lanterna := ""             # "" · "mao" · "cabeca"
var _tarefa_sons := -1
var _wav_chuva: AudioStreamWAV
var _wav_trovao: AudioStreamWAV
var _ligado := false
var _nevoa_dia := 0.6                # quanto de neblina vai ter na manhã de hoje (sorteado a cada dia)
var _dia_nevoa := -1
var _perto_agua := 0.0               # 0..1 quanto de água há em volta do jogador (costa, rios, lagos)
var _t_agua := 0.0

# ---------- API ----------
func ligar(c: Node3D, j: Node3D) -> void:
	cidade = c
	jogador = j
	_rng.randomize()
	if cidade.ambiente != null and cidade.ambiente.sky != null:
		_ceu = cidade.ambiente.sky.sky_material as ProceduralSkyMaterial
	_guardar_original()
	cidade.set_meta("_clima_dono", get_instance_id())
	# neblina: a base vem das Opções (menu/aplicar_opcoes.gd); o clima só multiplica por cima
	if cidade.ambiente != null:
		_nevoa_base = cidade.ambiente.fog_density
		var nv = cidade.get_meta("_clima_nevoa", [])
		if nv is Array and nv.size() == 2 and is_equal_approx(float(nv[1]), _nevoa_base):
			_nevoa_base = float(nv[0])          # o clima anterior ainda deixou a neblina dele
	_criar_chuva()
	_criar_luzes()
	_criar_sons()
	_escolher_duracao()
	_alvo_nuvens = TEMPOS[estado]["nuvens"]
	_alvo_chuva = TEMPOS[estado]["chuva"]
	nuvens = _alvo_nuvens
	chuva = _alvo_chuva
	_ligado = true
	_atualizar_ceu()
	_atualizar_lanterna()

var _globais := {}

func _global(nome: String, v: float) -> void:
	if absf(float(_globais.get(nome, -99.0)) - v) < 0.002:
		return
	_globais[nome] = v
	RenderingServer.global_shader_parameter_set(nome, v)

func definir_hora(h: float) -> void:
	hora = fposmod(h, 24.0)
	if _ligado:
		_atualizar_ceu()

# muda o tempo agora: "limpo", "nublado", "chuva" ou "tempestade". imediato = sem transição.
func forcar_tempo(novo: String, imediato := false) -> void:
	if not TEMPOS.has(novo):
		push_warning("clima: tempo desconhecido: " + novo)
		return
	estado = novo
	_escolher_duracao()
	_alvo_nuvens = TEMPOS[estado]["nuvens"]
	_alvo_chuva = TEMPOS[estado]["chuva"]
	if imediato:
		nuvens = _alvo_nuvens
		chuva = _alvo_chuva
		_chuva_visual = 0.0 if _coberto else chuva
	if _ligado:
		_atualizar_ceu()

# temperatura do ar (°C): mais quente às 15h, mais frio às 3h; nuvens e chuva esfriam
func temperatura_ar() -> float:
	var t := TEMP_MEDIA + TEMP_VARIACAO * cos(TAU * (hora - 15.0) / 24.0)
	return t - TEMP_CHUVA * chuva - 1.5 * nuvens * (1.0 - chuva)

# true se não tem nada em cima (raio de 40 m para cima, camada 1 = mundo)
func exposto(pos: Vector3) -> bool:
	return not _tem_teto(pos + Vector3(0.0, 1.9, 0.0))

# quanto está molhando nesta posição agora (0..1)
func molhando(pos: Vector3) -> float:
	if chuva <= 0.01:
		return 0.0
	return chuva if exposto(pos) else 0.0

# 0 = dia claro · 1 = noite fechada (visão dos zumbis, HUD)
func escuridao() -> float:
	return _escuridao

func salvar() -> Dictionary:
	return {"hora": hora, "dia": dia, "chuva": chuva, "nuvens": nuvens, "estado": estado,
		"t_estado": _t_estado, "parado": parado, "molhado": molhado}

func carregar(d: Dictionary) -> void:
	hora = fposmod(float(d.get("hora", HORA_INICIAL)), 24.0)
	dia = int(d.get("dia", 1))
	estado = str(d.get("estado", "limpo"))
	if not TEMPOS.has(estado):
		estado = "limpo"
	_alvo_nuvens = TEMPOS[estado]["nuvens"]
	_alvo_chuva = TEMPOS[estado]["chuva"]
	chuva = clampf(float(d.get("chuva", _alvo_chuva)), 0.0, 1.0)
	nuvens = clampf(float(d.get("nuvens", _alvo_nuvens)), 0.0, 1.0)
	_t_estado = float(d.get("t_estado", 300.0))
	parado = bool(d.get("parado", false))
	molhado = clampf(float(d.get("molhado", chuva)), 0.0, 1.0)
	if _ligado:
		_atualizar_ceu()

const CidadeCls := preload("res://mundo/cidade.gd")

# quanto de água (mar, rio, lago) existe num raio de ~350 m do jogador (0..1)
func _medir_agua() -> float:
	if jogador == null or cidade == null or cidade.land.is_empty():
		return 0.0
	var p := jogador.global_position
	var n := 0
	var agua := 0
	for r in [120.0, 240.0, 360.0]:
		for i in 12:
			var a := TAU * i / 12.0
			var x := int((p.x + cos(a) * r + CidadeCls.WORLD.x) / CidadeCls.CELL)
			var z := int((p.z + sin(a) * r + CidadeCls.WORLD.y) / CidadeCls.CELL)
			n += 1
			if x < 0 or z < 0 or x >= cidade.W or z >= cidade.H or cidade.land[z * cidade.W + x] == 0:
				agua += 1
	return clampf(float(agua) / float(n) * 2.5, 0.0, 1.0)

# devolve sol, céu, neblina e mar da cidade como estavam antes do clima (menu / sair do jogo)
func restaurar() -> void:
	if cidade == null or not is_instance_valid(cidade) or not cidade.has_meta("_clima_original"):
		return
	if int(cidade.get_meta("_clima_dono", 0)) != get_instance_id():
		return                                  # outro clima (jogo reiniciado) já está cuidando da cidade
	var o: Dictionary = cidade.get_meta("_clima_original")
	var env: Environment = cidade.ambiente
	if env != null:
		env.ambient_light_energy = o["amb"]
		env.ambient_light_color = o["amb_cor"]
		env.ambient_light_sky_contribution = o["amb_ceu"]
		env.fog_light_color = o["nev"]
		env.tonemap_exposure = o["exp"]
		if is_equal_approx(env.fog_density, _nevoa_posta):
			env.fog_density = _nevoa_base
	RenderingServer.global_shader_parameter_set("molhado", 0.0)
	RenderingServer.global_shader_parameter_set("noite", 0.0)
	_globais.clear()
	if _ceu != null:
		_ceu.sky_top_color = o["topo"]
		_ceu.sky_horizon_color = o["hor"]
		_ceu.ground_horizon_color = o["chao_hor"]
		_ceu.ground_bottom_color = o["chao_fundo"]
	var sol: DirectionalLight3D = cidade.sol
	if sol != null:
		sol.rotation = o["sol_rot"]
		sol.light_color = o["sol_cor"]
		sol.light_energy = o["sol_e"]
	for m in cidade.mats_agua:
		if is_instance_valid(m):
			m.set_shader_parameter("cor_ceu", o["mar_ceu"])
	_refletir_ceu([], true)
	cidade.remove_meta("_clima_dono")
	cidade.remove_meta("_clima_nevoa")

func _exit_tree() -> void:
	if _tarefa_sons != -1:
		WorkerThreadPool.wait_for_task_completion(_tarefa_sons)
		_tarefa_sons = -1
	restaurar()

# ---------- montagem ----------
func _guardar_original() -> void:
	if cidade.has_meta("_clima_original"):
		return                                  # já guardado por um clima anterior (valores da cidade)
	var o := {}
	var env: Environment = cidade.ambiente
	o["amb"] = env.ambient_light_energy if env != null else 0.9
	o["amb_cor"] = env.ambient_light_color if env != null else Color.BLACK
	o["amb_ceu"] = env.ambient_light_sky_contribution if env != null else 1.0
	o["nev"] = env.fog_light_color if env != null else Color.WHITE
	o["exp"] = env.tonemap_exposure if env != null else 1.0
	if _ceu != null:
		o["topo"] = _ceu.sky_top_color
		o["hor"] = _ceu.sky_horizon_color
		o["chao_hor"] = _ceu.ground_horizon_color
		o["chao_fundo"] = _ceu.ground_bottom_color
	var sol: DirectionalLight3D = cidade.sol
	if sol != null:
		o["sol_rot"] = sol.rotation
		o["sol_cor"] = sol.light_color
		o["sol_e"] = sol.light_energy
	o["mar_ceu"] = Color(0.95, 0.68, 0.48)
	if cidade.mats_agua.size() > 0 and is_instance_valid(cidade.mats_agua[0]):
		var v = cidade.mats_agua[0].get_shader_parameter("cor_ceu")
		if v is Color:
			o["mar_ceu"] = v
		elif v is Vector3:
			o["mar_ceu"] = Color(v.x, v.y, v.z)
	cidade.set_meta("_clima_original", o)

func _criar_chuva() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var vs := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in GOTAS:
		var p := Vector3(r.randf() * CAIXA_CHUVA.x, r.randf() * CAIXA_CHUVA.y, r.randf() * CAIXA_CHUVA.z)
		var q := (float(i) + 0.5) / float(GOTAS)        # ordem de entrada: com pouca chuva aparecem as primeiras
		var b := vs.size()
		for c in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
			vs.append(p)
			uv.append(c)
			uv2.append(Vector2(q, 0.0))
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.custom_aabb = AABB(-CAIXA_CHUVA, CAIXA_CHUVA * 2.0)
	var sh := Shader.new()
	sh.code = SHADER_CHUVA
	_mat_chuva = ShaderMaterial.new()
	_mat_chuva.shader = sh
	_mat_chuva.set_shader_parameter("caixa", CAIXA_CHUVA)
	_mat_chuva.set_shader_parameter("velocidade", VEL_GOTA)
	_mat_chuva.set_shader_parameter("quantidade", 0.0)
	_malha_chuva = MeshInstance3D.new()
	_malha_chuva.name = "Chuva"
	_malha_chuva.mesh = am
	_malha_chuva.material_override = _mat_chuva
	_malha_chuva.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_malha_chuva.visible = false
	add_child(_malha_chuva)

func _criar_luzes() -> void:
	_relampago = DirectionalLight3D.new()
	_relampago.name = "Relampago"
	_relampago.light_color = Color(0.78, 0.84, 1.0)
	_relampago.light_energy = 0.0
	_relampago.shadow_enabled = false
	_relampago.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # não mexe no céu (não redesenha reflexo)
	_relampago.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	_relampago.visible = false
	add_child(_relampago)
	_lanterna_mao = _nova_lanterna("LanternaMao", LANTERNA_ENERGIA, LANTERNA_ALCANCE, LANTERNA_ANGULO)
	_lanterna_cabeca = _nova_lanterna("LanternaCabeca", CABECA_ENERGIA, CABECA_ALCANCE, CABECA_ANGULO)

func _nova_lanterna(nome: String, energia: float, alcance: float, angulo: float) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.name = nome
	l.light_color = LANTERNA_COR
	l.light_energy = energia
	l.light_specular = 0.35
	l.spot_range = alcance
	l.spot_angle = angulo
	l.spot_angle_attenuation = 0.6
	l.spot_attenuation = 0.7
	l.shadow_enabled = false
	l.visible = false
	add_child(l)
	return l

func _criar_sons() -> void:
	var bus := "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	_som_chuva = AudioStreamPlayer.new()
	_som_chuva.name = "SomChuva"
	_som_chuva.bus = bus
	_som_chuva.volume_db = -80.0
	add_child(_som_chuva)
	_som_trovao = AudioStreamPlayer.new()
	_som_trovao.name = "SomTrovao"
	_som_trovao.bus = bus
	add_child(_som_trovao)
	_tarefa_sons = WorkerThreadPool.add_task(_gerar_sons, false, "clima: sons")

# roda numa thread: sintetiza o loop de chuva e o trovão
func _gerar_sons() -> void:
	_wav_chuva = _wav(_sintetizar_chuva(), true)
	_wav_trovao = _wav(_sintetizar_trovao(), false)

# ---------- quadro a quadro ----------
func _process(dt: float) -> void:
	if not _ligado:
		return
	if _tarefa_sons != -1 and WorkerThreadPool.is_task_completed(_tarefa_sons):
		WorkerThreadPool.wait_for_task_completion(_tarefa_sons)
		_tarefa_sons = -1
		_som_chuva.stream = _wav_chuva
		_som_trovao.stream = _wav_trovao
	if not parado:
		hora += dt * 24.0 / DURACAO_DIA
		if hora >= 24.0:
			hora -= 24.0
			dia += 1
		_t_estado -= dt
		if _t_estado <= 0.0:
			_proximo_tempo()
	nuvens = move_toward(nuvens, _alvo_nuvens, VEL_NUVENS * dt)
	# a chuva só engrossa com o céu fechado e para antes das nuvens abrirem
	var alvo_chuva := minf(_alvo_chuva, clampf((nuvens - 0.55) / 0.4, 0.0, 1.0))
	chuva = move_toward(chuva, alvo_chuva, VEL_CHUVA * dt)
	_t_abrigo -= dt
	if _t_abrigo <= 0.0:
		_t_abrigo = TICK_ABRIGO
		_ver_abrigo()
	_chuva_visual = move_toward(_chuva_visual, 0.0 if _coberto else chuva, dt * 1.5)
	# chão molhado: encharca em ~30 s de chuva e seca em ~4 min (sol seca mais rápido)
	if chuva > 0.08:
		molhado = move_toward(molhado, 1.0, dt * chuva / 30.0)
	else:
		molhado = move_toward(molhado, 0.0, dt / (240.0 if _escuridao > 0.5 else 160.0))
	# OTIMIZAÇÃO: os valores globais dos shaders só são mandados quando mudam de verdade (cada envio faz a
	# placa de vídeo receber de novo o bloco de valores globais)
	_global("molhado", molhado)
	_global("vento", 0.25 + 0.35 * nuvens + 0.9 * chuva)
	_global("noite", _escuridao)
	_t_ceu -= dt
	if _t_ceu <= 0.0:
		_t_ceu = TICK_CEU
		_atualizar_ceu()
	_atualizar_chuva()
	_atualizar_trovoes(dt)
	_t_lanterna -= dt
	if _t_lanterna <= 0.0:
		_t_lanterna = TICK_LANTERNA
		_atualizar_lanterna()
	_mover_lanterna()

func _escolher_duracao() -> void:
	var d: Vector2 = TEMPOS[estado]["dur"]
	_t_estado = _rng.randf_range(d.x, d.y)

func _proximo_tempo() -> void:
	var opcoes: Dictionary = PROXIMO[estado]
	var s := _rng.randf()
	var novo := estado
	for k in opcoes:
		s -= float(opcoes[k])
		novo = k
		if s <= 0.0:
			break
	forcar_tempo(novo)

# ---------- céu, sol, neblina (a cada TICK_CEU) ----------
func _amostra(h: float) -> Dictionary:
	var n := HORAS.size()
	var i := n - 1
	for k in n:
		if HORAS[k]["h"] <= h:
			i = k
	var a: Dictionary = HORAS[i]
	var b: Dictionary = HORAS[(i + 1) % n]
	var ha: float = a["h"]
	var hb: float = b["h"]
	if hb <= ha:
		hb += 24.0
	var hh := h if h >= ha else h + 24.0
	var t := clampf((hh - ha) / maxf(0.001, hb - ha), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var r := {}
	for key in a:
		var va = a[key]
		var vb = b[key]
		if va is Color:
			r[key] = (va as Color).lerp(vb, t)
		else:
			r[key] = lerpf(float(va), float(vb), t)
	return r

# altura do sol em graus (negativa à noite)
func _altura_sol(h: float) -> float:
	if h >= NASCER and h <= POR:
		return SOL_ALTURA_MAX * sin(PI * (h - NASCER) / (POR - NASCER))
	var noite := 24.0 - POR + NASCER
	var desde := fposmod(h - POR, 24.0)
	return -40.0 * sin(PI * desde / noite)

static func _cinza(c: Color, fator: float) -> Color:
	var l := c.r * 0.3 + c.g * 0.55 + c.b * 0.15
	return Color(l * fator, l * fator * 1.02, l * fator * 1.08)

func _atualizar_ceu() -> void:
	if cidade == null or not is_instance_valid(cidade):
		return
	var k := _amostra(hora)
	var n := nuvens
	var c := chuva
	# sol de dia, lua de noite (um some antes do outro aparecer)
	var alt := _altura_sol(hora)
	var parte_sol := clampf((alt + 3.0) / 6.0, 0.0, 1.0)
	var parte_lua := clampf((-alt - 3.0) / 6.0, 0.0, 1.0)
	var sol: DirectionalLight3D = cidade.sol
	var cor_luz: Color
	var energia: float
	if sol != null:
		if parte_sol > 0.0:
			var giro := -52.0 + (18.0 - hora) * (180.0 / (POR - NASCER))
			sol.rotation_degrees = Vector3(-maxf(alt, 1.5), giro, 0.0)
			cor_luz = k["sol"]
			energia = float(k["e"]) * parte_sol
		else:
			var noite := 24.0 - POR + NASCER
			var t := fposmod(hora - POR, 24.0) / noite
			sol.rotation_degrees = Vector3(-(20.0 + 35.0 * sin(PI * t)), 120.0 - 160.0 * t, 0.0)
			cor_luz = LUA_COR
			energia = LUA_ENERGIA * parte_lua
		# nublado: sol fraco e sem cor; chuva escurece mais
		cor_luz = cor_luz.lerp(_cinza(cor_luz, 1.0), n * 0.6)
		energia *= (1.0 - 0.62 * n) * (1.0 - 0.2 * c)
		sol.light_color = cor_luz
		sol.light_energy = energia
	var luz_dia := 1.0 - float(k["esc"])
	var topo: Color = k["topo"]
	var hor: Color = k["hor"]
	var nev: Color = k["nev"]
	topo = topo.lerp(_cinza(hor, 0.62), n * 0.85).darkened(0.25 * c)
	hor = hor.lerp(_cinza(hor, 0.80), n * 0.85).darkened(0.2 * c)
	nev = nev.lerp(_cinza(nev, 0.82), n * 0.85).darkened(0.15 * c)
	if _ceu != null:
		_ceu.sky_top_color = topo
		_ceu.sky_horizon_color = hor
		_ceu.ground_horizon_color = nev
		_ceu.ground_bottom_color = nev.darkened(0.12)
	var env: Environment = cidade.ambiente
	if env != null:
		_amb_base = float(k["amb"]) * (1.0 + 0.25 * n * luz_dia)
		env.ambient_light_energy = _amb_base + _flash * 0.9
		env.ambient_light_color = k["amb_cor"]
		env.ambient_light_sky_contribution = k["amb_ceu"]
		env.fog_light_color = nev
		env.tonemap_exposure = float(k["exp"]) * (1.0 + 0.06 * n * luz_dia)
		# a neblina das Opções é a base; se alguém (Opções) mudou, ela vira a nova base
		if not is_equal_approx(env.fog_density, _nevoa_posta):
			_nevoa_base = env.fog_density
		# NEBLINA DA MANHÃ (como no DayZ): do amanhecer até ~9h, mais grossa perto da água; cada dia sorteia a força
		if dia != _dia_nevoa:
			_dia_nevoa = dia
			var r := RandomNumberGenerator.new()
			r.seed = dia * 7919 + 11
			_nevoa_dia = r.randf_range(0.15, 1.0)
		_t_agua -= TICK_CEU
		if _t_agua <= 0.0:
			_t_agua = 4.0
			_perto_agua = _medir_agua()
		var manha := smoothstep(4.8, 6.2, hora) * (1.0 - smoothstep(7.8, 9.6, hora))
		neblina_manha = manha * _nevoa_dia * (0.45 + 0.55 * _perto_agua)
		_nevoa_posta = _nevoa_base * float(k["nd"]) * (1.0 + 0.6 * n + 2.6 * c) * (1.0 + 5.0 * neblina_manha) * nevoa_extra
		env.fog_density = _nevoa_posta
		# neblina da manhã é branco-acinzentada (não laranja como o horizonte do nascer do sol)
		var lum := nev.r * 0.3 + nev.g * 0.55 + nev.b * 0.15
		env.fog_light_color = nev.lerp(Color(lum * 1.0, lum * 1.03, lum * 1.08), neblina_manha * 0.8)
		cidade.set_meta("_clima_nevoa", [_nevoa_base, _nevoa_posta])
	for m in cidade.mats_agua:
		if is_instance_valid(m):
			m.set_shader_parameter("cor_ceu", hor)
	if sol != null:
		var dir := -sol.global_transform.basis.z
		_refletir_ceu([topo.r, topo.g, topo.b, hor.r, hor.g, hor.b, nev.r, nev.g, nev.b,
			cor_luz.r * energia, cor_luz.g * energia, cor_luz.b * energia, dir.x, dir.y, dir.z])
	_escuridao = clampf(float(k["esc"]) + (1.0 - float(k["esc"])) * (0.12 * n + 0.1 * c), 0.0, 1.0)
	if _mat_chuva != null:
		var b := lerpf(0.22, 0.78, luz_dia) * (1.0 - 0.25 * n)
		_mat_chuva.set_shader_parameter("cor", Color(b * 0.92, b * 0.96, b, lerpf(0.22, 0.32, c)))

# O reflexo do céu (luz que as paredes/vidros/chão refletem) NÃO se atualiza sozinho no renderizador
# Compatibility quando as cores do céu mudam. Trocar o process_mode do Sky obriga a refazer o reflexo
# (1 vez, no mesmo quadro). Só fazemos isso quando céu/sol mudaram o bastante (custa alguns ms no celular).
func _refletir_ceu(assinatura: Array, forcar := false) -> void:
	if _ceu == null or cidade.ambiente == null or cidade.ambiente.sky == null:
		return
	if not forcar and _assinatura_reflexo.size() == assinatura.size():
		var dif := 0.0
		for i in assinatura.size():
			dif = maxf(dif, absf(float(assinatura[i]) - float(_assinatura_reflexo[i])))
		if dif < REFLEXO_LIMIAR or Time.get_ticks_msec() - _ult_reflexo < int(REFLEXO_MIN_S * 1000.0):
			return
	_ult_reflexo = Time.get_ticks_msec()
	_assinatura_reflexo = assinatura
	var sky: Sky = cidade.ambiente.sky
	sky.process_mode = Sky.PROCESS_MODE_QUALITY if sky.process_mode == Sky.PROCESS_MODE_AUTOMATIC else Sky.PROCESS_MODE_AUTOMATIC
	refletiu += 1

# ---------- chuva e trovões ----------
func _ver_abrigo() -> void:
	if chuva <= 0.0 and _chuva_visual <= 0.0:
		_coberto = false
		return
	var cam := get_viewport().get_camera_3d()
	var cam_coberta := cam != null and _tem_teto(cam.global_position + Vector3(0.0, 0.1, 0.0))
	var jog_coberto := jogador != null and is_instance_valid(jogador) and not exposto(jogador.global_position)
	_coberto = cam_coberta and (jogador == null or jog_coberto)

func _tem_teto(origem: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var w := get_viewport().get_world_3d()
	if w == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(origem, origem + Vector3(0.0, 40.0, 0.0), 1)
	q.hit_from_inside = true
	q.hit_back_faces = true
	return not w.direct_space_state.intersect_ray(q).is_empty()

func _atualizar_chuva() -> void:
	var cam := get_viewport().get_camera_3d()
	var v := _chuva_visual
	_malha_chuva.visible = v > 0.005 and cam != null
	if _malha_chuva.visible:
		_malha_chuva.global_position = cam.global_position
		_mat_chuva.set_shader_parameter("quantidade", clampf(v * 1.05, 0.0, 1.0))
		var vento := 1.0 + 2.5 * maxf(0.0, chuva - 0.6) / 0.4
		_mat_chuva.set_shader_parameter("vento", Vector2(0.8, 0.45) * vento)
	# som: abafado dentro de prédio
	var vol := pow(chuva, 0.8) * (0.4 if _coberto else 1.0) * 0.85 * (0.0 if som_mudo else 1.0)
	if _som_chuva.stream != null:
		if vol > 0.004:
			_som_chuva.volume_db = linear_to_db(vol)
			_som_chuva.pitch_scale = 0.92 + 0.14 * chuva
			if not _som_chuva.playing:
				_som_chuva.play(_rng.randf() * 2.0)
		elif _som_chuva.playing:
			_som_chuva.stop()

func _atualizar_trovoes(dt: float) -> void:
	# relâmpago: piscadas rápidas (luz extra + luz ambiente), depois o trovão
	if estado == "tempestade" and chuva > 0.6:
		_t_relampago -= dt
		if _t_relampago <= 0.0:
			_t_relampago = _rng.randf_range(TROVAO_INTERVALO.x, TROVAO_INTERVALO.y)
			relampago()
	if _piscadas.size() > 0:
		_t_flash += dt
		var f := 0.0
		for p in _piscadas:
			var dtp: float = _t_flash - float(p[0])
			if dtp >= 0.0:
				f = maxf(f, float(p[1]) * exp(-dtp * 14.0))
		_flash = f
		if _t_flash > 1.5:
			_piscadas.clear()
			_flash = 0.0
		_relampago.visible = _flash > 0.01
		_relampago.light_energy = _flash * 1.8 * (1.0 if not _coberto else 0.4)
		if cidade != null and is_instance_valid(cidade) and cidade.ambiente != null:
			cidade.ambiente.ambient_light_energy = _amb_base + _flash * 0.9
	if _trovao_em >= 0.0:
		_trovao_em -= dt
		if _trovao_em < 0.0 and _som_trovao.stream != null:
			_som_trovao.volume_db = linear_to_db(_trovao_vol * (0.6 if _coberto else 1.0))
			_som_trovao.pitch_scale = _rng.randf_range(0.8, 1.08)
			_som_trovao.play()

# um relâmpago agora (a história pode chamar). perto = 0..1 (1 = clarão forte e trovão logo depois)
func relampago(perto := -1.0) -> void:
	if perto < 0.0:
		perto = _rng.randf()
	_t_flash = 0.0
	_piscadas = [[0.0, 0.5 + 0.5 * perto]]
	var t := 0.0
	for i in _rng.randi_range(1, 3):
		t += _rng.randf_range(0.07, 0.22)
		_piscadas.append([t, _rng.randf_range(0.4, 1.0) * (0.4 + 0.6 * perto)])
	_relampago.rotation_degrees = Vector3(-_rng.randf_range(35.0, 75.0), _rng.randf_range(0.0, 360.0), 0.0)
	_trovao_em = lerpf(4.0, 0.3, perto)
	_trovao_vol = lerpf(0.35, 1.0, perto)

# ---------- lanterna ----------
func _atualizar_lanterna() -> void:
	_tipo_lanterna = ""
	if jogador != null and is_instance_valid(jogador):
		var inv = jogador.get("inventario")
		if inv != null and is_instance_valid(inv):
			var s: Dictionary = inv.slots
			var mao = s.get("maos")
			var cab = s.get("cabeca")
			if mao != null and mao.id == "lanterna":
				_tipo_lanterna = "mao"
			elif cab != null and cab.id == "lanterna_cabeca":
				_tipo_lanterna = "cabeca"
	_lanterna_mao.visible = _tipo_lanterna == "mao"
	_lanterna_cabeca.visible = _tipo_lanterna == "cabeca"
	lanterna_acesa = _tipo_lanterna != ""

func _mover_lanterna() -> void:
	if _tipo_lanterna == "" or jogador == null or not is_instance_valid(jogador):
		return
	var cam: Camera3D = jogador.get("camera")
	if cam == null:
		return
	var b := cam.global_transform.basis
	var frente := -b.z
	var direita := b.x
	var base := jogador.global_position
	var l: SpotLight3D
	var pos: Vector3
	if _tipo_lanterna == "mao":
		l = _lanterna_mao
		pos = base + Vector3(0.0, 1.3, 0.0) + direita * 0.22 + Vector3(frente.x, 0.0, frente.z).normalized() * 0.45
	else:
		l = _lanterna_cabeca
		pos = base + Vector3(0.0, 1.72, 0.0) + Vector3(frente.x, 0.0, frente.z).normalized() * 0.22
	l.global_position = pos
	# aponta para onde a câmera olha (um pouco para baixo, para iluminar o chão à frente)
	var alvo := cam.global_position + frente * 25.0
	var d := alvo - pos
	if d.length_squared() > 0.01 and absf(d.normalized().dot(Vector3.UP)) < 0.99:
		l.look_at(alvo, Vector3.UP)

# ---------- sons sintetizados ----------
# chuva: chiado (ruído filtrado em 2 bandas) + pingos curtos aleatórios; loop emendado em cruz
func _sintetizar_chuva() -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = 7171
	var dur := 4.0
	var emenda := 4000
	var n := int(TAXA * dur) + emenda
	var a := PackedFloat32Array()
	a.resize(n)
	var l1 := 0.0
	var l2 := 0.0
	var grave := 0.0
	var corpo := 0.0
	var pingo := 0.0
	var pingo_f := 0.0
	var pingo_lp := 0.0
	for i in n:
		var w := r.randf_range(-1.0, 1.0)
		l1 += (w - l1) * 0.55
		l2 += (l1 - l2) * 0.55
		grave += (l2 - grave) * 0.02
		var chiado := l2 - grave                     # banda larga (~150 Hz .. 5 kHz)
		corpo += (w - corpo) * 0.06                  # "ronco" da chuva no chão (grave)
		if r.randf() < 70.0 / TAXA:                  # ~70 pingos por segundo
			pingo = r.randf_range(0.3, 1.0)
			pingo_f = r.randf_range(0.25, 0.6)
		pingo *= 0.9965
		pingo_lp += (r.randf_range(-1.0, 1.0) - pingo_lp) * pingo_f
		a[i] = chiado * 0.55 + corpo * 1.6 + pingo_lp * pingo * 0.35
	var m := n - emenda
	for i in emenda:
		var t := float(i) / emenda
		a[i] = lerpf(a[m + i], a[i], t)
	a.resize(m)
	return a

# trovão: estalo inicial + ronco grave que vai e volta e morre devagar
func _sintetizar_trovao() -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = 9393
	var dur := 6.0
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var marrom := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var est := 0.0
	# "rolos" do trovão: picos de volume espalhados
	var rolos: Array = []
	for i in 6:
		rolos.append([r.randf_range(0.1, 3.2), r.randf_range(0.4, 1.0), r.randf_range(0.3, 0.9)])
	for i in n:
		var t := float(i) / TAXA
		var w := r.randf_range(-1.0, 1.0)
		marrom = (marrom + w * 0.05) * 0.996
		lp += (marrom - lp) * 0.08
		lp2 += (lp - lp2) * 0.08
		var env := 0.0
		for ro in rolos:
			var dtr: float = t - float(ro[0])
			if dtr > 0.0:
				env += float(ro[1]) * (1.0 - exp(-dtr * 20.0)) * exp(-dtr / float(ro[2]))
		env += 0.35 * exp(-t / 2.2) * minf(1.0, t * 8.0)
		est += (w - est) * 0.5
		var estalo := est * exp(-t * 18.0) * 0.6
		a[i] = lp2 * 6.0 * env * minf(1.0, (dur - t) * 1.5) + estalo
	return a

static func _wav(a: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var pico := 0.0001
	for v in a:
		pico = maxf(pico, absf(v))
	var g := 0.9 / pico
	var dados := PackedByteArray()
	dados.resize(a.size() * 2)
	for i in a.size():
		dados.encode_s16(i * 2, int(clampf(a[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = a.size()
	return w
