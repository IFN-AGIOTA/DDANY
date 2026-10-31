extends Node
# OPÇÕES DO JOGO (autoload "Config"): valores, padrões, predefinições de gráficos e gravação em user://opcoes.cfg.
# Mesmos nomes e padrões do jogo em HTML (OPT_DEF / GFX_PRESETS). Quem APLICA no jogo é menu/aplicar_opcoes.gd.
# Mexa AQUI para: valores padrão, predefinições (Leve/Médio/Alto/Ultra) e a versão mostrada no menu.

signal mudou(chave: String)          # "gfx" quando os gráficos foram aplicados; "hud" quando a HUD foi editada

const VERSAO := "1.07"
const ARQUIVO := "user://opcoes.cfg"

const PADRAO := {
	"ctrl": "touch", "gsens": 25, "gyro_inv": false, "gyro_zero": Vector3.ZERO,
	"sens": 100, "inv": false, "gas": "manual", "vib": true,
	# 0.62 · TECLADO E MOUSE (Opções › Teclado e mouse; jogador/teclas.gd e jogador/controles.gd)
	"entrada": "auto",                    # "auto" (troca sozinho), "pc" (teclado e mouse) ou "toque"
	"msens": 100, "msens_mira": 70,       # sensibilidade do mouse (%) e mirando (% dela)
	"minv": false,                        # eixo vertical do mouse invertido
	"mirar_modo": "segurar", "agachar_modo": "alternar", "correr_modo": "segurar",
	"roda_mouse": true,                   # rodinha do mouse troca de arma
	"dicas_teclas": true,                 # mostra "E  PEGAR" etc. na tela
	"teclas": {},                         # teclas trocadas: ação -> código (jogador/teclas.gd)
	"mira_ferro": true,                   # 0.98: em 3ª pessoa, MIRAR com arma de fogo entra na mira de ferro
	"cam": 0, "dist": "near", "pos": "left", "fov": 42,
	"map": true, "op": 100, "sc": 100, "avisos": false, "icone_mun": false,
	"fps": false, "som": true, "vol": 100, "awake": false, "mus": true, "mvol": 70,
	"svol": 100,                          # volume dos efeitos (tiros, passos, infectados, chuva)
	"dif": 1,                             # dificuldade do modo livre: 0 fácil, 1 normal, 2 difícil
	"pvp": "zonas",                       # 0.71: PvP quando VOCÊ cria a partida: "zonas", "tudo" ou "desligado"
	# 0.89 · INFECTADOS no estilo Project Zomboid (Opções › Infectados; números em inimigos/regras_infectados.gd)
	"z_pop": 1,                           # população: 0 pouca, 1 normal, 2 muita, 3 insana
	"z_vel": "lentos",                    # "lentos" (lore), "rapidos", "corredores" ou "misto"
	"z_forca": 1, "z_resist": 1,          # 0 fraca/frágil, 1 normal, 2 sobre-humana/resistente
	"z_cog": 0,                           # 0 só batem nas portas · 1 abrem portas (sem tábuas)
	"z_mem": 2,                           # memória: 0 nenhuma, 1 curta, 2 normal, 3 longa
	"z_visao": 1, "z_audicao": 1,         # 0 ruim, 1 normal, 2 águia/exata
	"z_trans": 0,                         # vírus: 0 sangue e saliva, 1 só mordida, 2 desligado
	"z_morte": 2,                         # o vírus mata em: 0 6-12 h, 1 1-2 dias, 2 2-3 dias, 3 uma semana
	"z_derrubar": true,                   # 3 infectados juntos te puxam para o chão
	"z_reaparecer": true,                 # lugar esvaziado volta a ter infectados (72 h)
	"z_ativos": "ambos",                  # "ambos", "dia" ou "noite"
	"z_mutados": 1,                       # 1.00: mutados (inimigos/diretor.gd): 0 não, 1 raros, 2 frequentes
	"z_ritmo": 2,                         # 1.00: Diretor de IA (inimigos/diretor.gd): 0 desligado, 1 calmo, 2 normal, 3 intenso
	"rec_tempo": 0.0, "rec_abates": 0,    # recordes (tela de morte)
	"voz_mic": true, "voz_ouvir": true,   # 0.97: chat de voz: seu microfone ligado · ouvir os outros (rede/voz.gd)
	"nome_rede": "", "ip_rede": "",       # multijogador: seu nome e o último IP digitado (menu/tela_multijogador.gd)
}

# shd/tex/models/detd/fx: 0..3 · shad: 0..2 · den: 0..2 · fog: 0 densa, 1 normal, 2 limpa · dist/res: 0..3
# chk: raio de chunks de 500 m (0 = AUTO, segue "dist"; mundo/chunks.gd)
# ocl: ocultar o que está atrás dos prédios (occlusion culling, mundo/oclusao.gd)
# aa: 0 desligado, 1 MSAA 2x, 2 MSAA 4x, 3 MSAA 8x · aniso: 1, 2, 4, 8, 16 · cap: 0 = sem limite
const GFX_PRESETS := {
	"auto": {"shd": 3, "res": 3, "dyn": true, "dist": 2, "fx": 2, "models": 2, "tex": 3, "aniso": 2, "aa": 0, "cap": 0,
		"shad": 1, "den": 1, "detd": 2, "wtr": true, "wire": true, "halo": true, "fog": 1, "rp": 35, "chk": 0, "ocl": true},
	"low": {"shd": 1, "res": 1, "dyn": false, "dist": 0, "fx": 0, "models": 0, "tex": 1, "aniso": 1, "aa": 0, "cap": 0,
		"shad": 0, "den": 0, "detd": 0, "wtr": false, "wire": false, "halo": false, "fog": 0, "rp": 35, "chk": 0, "ocl": false},
	"mid": {"shd": 2, "res": 2, "dyn": true, "dist": 1, "fx": 1, "models": 1, "tex": 2, "aniso": 2, "aa": 0, "cap": 0,
		"shad": 1, "den": 1, "detd": 1, "wtr": true, "wire": true, "halo": true, "fog": 1, "rp": 35, "chk": 0, "ocl": true},
	"high": {"shd": 3, "res": 3, "dyn": false, "dist": 2, "fx": 3, "models": 3, "tex": 3, "aniso": 8, "aa": 2, "cap": 0,
		"shad": 1, "den": 2, "detd": 2, "wtr": true, "wire": true, "halo": true, "fog": 1, "rp": 35, "chk": 0, "ocl": true},
	"ultra": {"shd": 3, "res": 3, "dyn": false, "dist": 3, "fx": 3, "models": 3, "tex": 3, "aniso": 16, "aa": 3, "cap": 0,
		"shad": 2, "den": 2, "detd": 3, "wtr": true, "wire": true, "halo": true, "fog": 2, "rp": 35, "chk": 0, "ocl": true},
}
const GFX_COR := {"bri": 100, "con": 100, "sat": 100, "vig": false, "rend": 0}   # 0.92: rend = modo de desenho (0 leve · 1 ultra, só PC)

var o := {}                           # opções (controles, câmera, HUD, vídeo e som)
var g := {}                           # gráficos (aplicados pelo botão APLICAR)
var hud_pos := {}                     # posições/tamanhos da HUD editada: id -> [canto, off_x, off_y, raio]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	o = PADRAO.duplicate()
	g = gfx_padrao()
	carregar()
	set_process(false)

func gfx_padrao() -> Dictionary:
	var d: Dictionary = GFX_PRESETS["auto"].duplicate()
	d.merge(GFX_COR)
	return d

func valor(k: String):
	return o.get(k, PADRAO.get(k))

func definir(k: String, v) -> void:
	if o.get(k) == v:
		return
	o[k] = v
	salvar_depois()
	mudou.emit(k)

# 1.02 · GRAVAR DEPOIS: arrastar um deslizante (volume, sensibilidade...) gravava o arquivo no disco a cada passo. Agora
# grava SALVAR_EM s depois do último passo (ou já, ao fechar as Opções, sair do jogo ou o celular trocar de app).
const SALVAR_EM := 0.5
var _t_salvar := -1.0
func salvar_depois() -> void:
	_t_salvar = SALVAR_EM
	set_process(true)

func salvar_pendente() -> void:
	if _t_salvar >= 0.0:
		salvar()

func _process(dt: float) -> void:
	if _t_salvar < 0.0:
		set_process(false)
		return
	_t_salvar -= dt
	if _t_salvar < 0.0:
		salvar()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		salvar_pendente()

func aplicar_graficos(novo: Dictionary) -> void:
	g = novo.duplicate()
	salvar()
	mudou.emit("gfx")

# nome da predefinição que bate com os gráficos (ou "custom")
static func preset_de(d: Dictionary) -> String:
	for nome in ["auto", "low", "mid", "high", "ultra"]:
		var p: Dictionary = GFX_PRESETS[nome]
		var igual := true
		for k in p:
			if d.get(k) != p[k]:
				igual = false
				break
		if igual:
			return nome
	return "custom"

func definir_hud(pos: Dictionary) -> void:
	hud_pos = pos.duplicate(true)
	salvar()
	mudou.emit("hud")

func restaurar_tudo() -> void:
	o = PADRAO.duplicate()
	g = gfx_padrao()
	salvar()
	for k in o:
		mudou.emit(k)
	mudou.emit("gfx")

func carregar() -> void:
	var cf := ConfigFile.new()
	if cf.load(ARQUIVO) != OK:
		return
	for k in PADRAO:
		var v = cf.get_value("opcoes", k, PADRAO[k])
		if typeof(v) == typeof(PADRAO[k]) or (typeof(v) in [TYPE_INT, TYPE_FLOAT] and typeof(PADRAO[k]) in [TYPE_INT, TYPE_FLOAT]):
			o[k] = v
	var gp := gfx_padrao()
	for k in gp:
		var v = cf.get_value("graficos", k, gp[k])
		if typeof(v) == typeof(gp[k]) or (typeof(v) in [TYPE_INT, TYPE_FLOAT] and typeof(gp[k]) in [TYPE_INT, TYPE_FLOAT]):
			g[k] = v
	hud_pos = cf.get_value("hud", "posicoes", {})

func salvar() -> void:
	var cf := ConfigFile.new()
	for k in o:
		cf.set_value("opcoes", k, o[k])
	for k in g:
		cf.set_value("graficos", k, g[k])
	cf.set_value("hud", "posicoes", hud_pos)
	cf.save(ARQUIVO)
	_t_salvar = -1.0
