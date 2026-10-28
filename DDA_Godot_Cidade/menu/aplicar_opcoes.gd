extends Node
# APLICA AS OPÇÕES (menu/config.gd) no jogo: câmera, sensibilidade, vibração, HUD, som, tela,
# resolução (com resolução dinâmica), anti-aliasing, limite de FPS, sombras, neblina, distância de visão,
# brilho/contraste/saturação e vinheta; 0.84: texturas, filtragem anisotrópica, modelos, efeitos, fios e halos. Roda de novo sempre que uma opção muda.
# Mexa AQUI para: o que cada opção faz de verdade no jogo (números de distância, neblina etc.).

const FiltroCls := preload("res://menu/filtro_tela.gd")

const DIST_CAMERA := {"near": 2.35, "mid": 3.3, "far": 4.4}          # mesmos números do HTML
const LADO := {"left": 0.17, "center": 0.0, "right": -0.17}      # 0.99: câmera de ombro (m de lado por m de distância)
const RESOLUCAO := [0.5, 0.65, 0.8, 1.0]
const ALCANCE := [900.0, 1800.0, 3200.0, 5000.0]                     # distância de visão (m)
const NEVOA_DIST := [2.2, 1.45, 1.0, 0.75]
const NEVOA := [1.9, 1.0, 0.45]                                      # densa / normal / limpa
const NEVOA_BASE := 0.0006                                          # neblina "normal" (antes 0.00025: cidade limpa demais)
const ChunksCls := preload("res://mundo/chunks.gd")

# raio de chunks de 500 m (mundo/chunks.gd): "chk" 0 = AUTO (segue a Distância de visão) ou o número de chunks
static func raio_chunks() -> int:
	var k := int(Config.g.get("chk", 0))
	return k if k > 0 else ChunksCls.raio_auto(int(Config.g["dist"]))

# até onde a câmera enxerga: a Distância de visão, mas nunca além dos chunks carregados
static func alcance_visao() -> float:
	return minf(ALCANCE[clampi(int(Config.g["dist"]), 0, 3)], raio_chunks() * ChunksCls.TAM_CHUNK)
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]

var main: Node = null              # main.gd (tem jogador, controles, hud, cidade quando o jogo está rodando)
var filtro: CanvasLayer
var _dinamica := 1.0               # fator da resolução dinâmica
var _t_fps := 0.0
var _fps_soma := 0.0
var _fps_n := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	filtro = FiltroCls.new()
	filtro.name = "FiltroTela"
	add_child(filtro)
	Config.mudou.connect(aplicar)
	aplicar()

# 0.89: opções que só mexem na câmera/controle do jogador. Trocar uma delas (tecla F = 1ª/3ª pessoa, botão do meio =
# ombro, sensibilidade...) NÃO reaplica gráficos, texturas, modelos, luzes e chunks: antes cada troca de câmera
# travava o jogo por ~0,5 s.
const SO_JOGADOR := ["mira_ferro", "cam", "pos", "dist", "fov", "sens", "inv", "msens", "msens_mira", "minv", "gsens", "gyro_inv",
	"gyro_zero", "ctrl", "vib"]

func aplicar(chave := "") -> void:
	if chave in SO_JOGADOR:
		_aplicar_jogador()
		return
	if chave.begins_with("z_"):
		return                          # 0.89: regras dos infectados (lidas na hora por inimigos/regras_infectados.gd)
	if chave.begins_with("voz_"):
		return                          # 0.97: botões do chat de voz (rede/voz.gd lê na hora; nada a reaplicar)
	if chave in ["avisos", "icone_mun"]:
		return                          # 0.99: a HUD (armas/hud_combate.gd) lê na hora
	var o: Dictionary = Config.o
	var g: Dictionary = Config.g
	# som e tela (valem no menu também)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, not bool(o["som"]))
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, float(o["vol"]) / 100.0)))
	var bm := AudioServer.get_bus_index("Musica")          # música procedural (audio/musica_procedural.gd)
	if bm != -1:
		AudioServer.set_bus_mute(bm, not bool(o.get("mus", true)))
		AudioServer.set_bus_volume_db(bm, linear_to_db(maxf(0.0001, float(o.get("mvol", 70)) / 100.0)))
	var bs := AudioServer.get_bus_index("SFX")             # efeitos (criado em audio/musica_procedural.gd)
	if bs != -1:
		AudioServer.set_bus_volume_db(bs, linear_to_db(maxf(0.0001, float(o.get("svol", 100)) / 100.0)))
	var bu := AudioServer.get_bus_index("UI")              # sons do menu (audio/sons.gd): mesmo volume dos efeitos
	if bu != -1:
		AudioServer.set_bus_volume_db(bu, linear_to_db(maxf(0.0001, float(o.get("svol", 100)) / 100.0)))
	DisplayServer.screen_set_keep_on(bool(o["awake"]))
	Engine.max_fps = int(g["cap"]) if int(g["cap"]) > 0 else (60 if OS.has_feature("mobile") else 0)   # celular: no máximo 60 (esquenta menos)
	var vp := get_viewport()
	vp.msaa_3d = MSAA[clampi(int(g["aa"]), 0, 3)]
	vp.use_occlusion_culling = bool(g.get("ocl", true))     # não desenha o que está escondido atrás dos prédios
	vp.mesh_lod_threshold = [6.0, 3.0, 1.5, 1.0][clampi(int(g.get("models", 2)), 0, 3)]   # 0.84: modelos com LOD simplificam antes
	vp.texture_mipmap_bias = [1.0, 0.5, 0.0, 0.0][clampi(int(g.get("tex", 3)), 0, 3)]     # 0.84: detalhe das texturas
	_aplicar_resolucao()
	_modo_desenho(g)
	filtro.definir(float(g["bri"]) / 100.0, float(g["con"]) / 100.0, float(g["sat"]) / 100.0, bool(g["vig"]))
	if main == null:
		return
	_aplicar_jogador()
	var j = main.get("jogador")
	if j != null and is_instance_valid(j):
		j.camera.far = alcance_visao()
		var sf = j.find_child("SombraFalsa", true, false)
		if sf != null:
			sf.visible = int(g["shad"]) >= 1
	_aplicar_resto(o, g, j)

# 0.92 · MODO DE DESENHO (só no PC exportado): ULTRA = o renderizador completo da Godot (Forward+, Vulkan), escrito
# no override.cfg ao lado do .exe (a Godot lê ao abrir; se a placa não tiver Vulkan ela volta sozinha para o leve).
# LEVE = apaga o arquivo. No celular e no editor/testes nunca mexe.
const ARQ_OVERRIDE := "override.cfg"
static func ultra() -> bool:
	return RenderingServer.get_rendering_device() != null     # só os renderizadores de Vulkan têm "rendering device"

func _modo_desenho(g: Dictionary) -> void:
	if not OS.has_feature("pc") or not OS.has_feature("template"):
		return
	var arq := OS.get_executable_path().get_base_dir().path_join(ARQ_OVERRIDE)
	if int(g.get("rend", 0)) == 1:
		if not FileAccess.file_exists(arq):
			var f := FileAccess.open(arq, FileAccess.WRITE)
			if f != null:
				f.store_string("[rendering]\n\nrenderer/rendering_method=\"forward_plus\"\nrendering_device/fallback_to_opengl3=true\n")
	elif FileAccess.file_exists(arq):
		DirAccess.remove_absolute(arq)

# efeitos que só o modo ULTRA tem (no leve o renderizador não faz)
func _efeitos_ultra(cid) -> void:
	if not ultra() or cid.ambiente == null:
		return
	var env: Environment = cid.ambiente
	env.ssao_enabled = true                       # sombra nos cantos e onde as coisas se encostam
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true                       # luz que rebate nas paredes (cor do chão/prédio no vizinho)
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.7
	env.ssr_enabled = true                        # reflexos de verdade no chão molhado, poças e vidros
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 2.0
	env.glow_enabled = true                       # brilho em volta das luzes (janelas acesas, postes, lanterna, sol)
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_sky_affect = 0.25                     # (no Forward+ a neblina embranquecia o céu inteiro)
	env.volumetric_fog_enabled = true             # neblina de verdade: dá para ver o facho da lanterna e dos postes
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_albedo = Color(0.85, 0.85, 0.88)
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_ambient_inject = 0.2
	env.volumetric_fog_gi_inject = 0.0
	if cid.sol != null:
		cid.sol.shadow_blur = 1.5
		cid.sol.light_volumetric_fog_energy = 0.6

func _aplicar_jogador() -> void:
	if main == null:
		return
	var o: Dictionary = Config.o
	var j = main.get("jogador")
	if j != null and is_instance_valid(j):
		j.sensibilidade = float(o["sens"]) / 100.0
		j.inverter_y = bool(o["inv"])
		j.giroscopio = o["ctrl"] == "gyro"
		j.giro_sens = 25.0 / maxf(1.0, float(o.get("gsens", 25)))
		j.giro_inv = bool(o.get("gyro_inv", false))
		j.giro_zero = o.get("gyro_zero", Vector3.ZERO)
		j.distancia_camera = DIST_CAMERA.get(o["dist"], 2.35)
		j.lateral_camera = LADO.get(o["pos"], 0.17)
		j.ombro = -1.0 if o["pos"] == "right" else 1.0         # 0.79: lado da câmera (e do ombro ao mirar)
		j.fov_camera = float(o["fov"])
		j.primeira_pessoa = int(o.get("cam", 0)) == 1     # 0.65: 1ª pessoa
		j.mira_ferro_3p = bool(o.get("mira_ferro", true))   # 0.98: mirar em 3ª pessoa = mira de ferro
		j.armas.vibrar = bool(o["vib"])
		j.sens_mouse = float(o.get("msens", 100)) / 100.0
		j.sens_mouse_mira = float(o.get("msens_mira", 70)) / 100.0
		j.inverter_y_mouse = bool(o.get("minv", false))

func _aplicar_resto(o: Dictionary, g: Dictionary, j) -> void:
	# 0.84: detalhes dos efeitos (fumaça no horizonte, poeira e marcas dos tiros)
	var jg = main.get("jogo")
	if jg != null and is_instance_valid(jg):
		var fu = jg.get_node_or_null("Fumaca")
		if fu != null and fu.has_method("aplicar"):
			fu.aplicar(int(g.get("fx", 2)))
	if j != null and is_instance_valid(j) and j.get("armas") != null and j.armas.get("efeitos") != null:
		j.armas.efeitos.nivel_fx = int(g.get("fx", 2))
	var c = main.get("controles")
	if c != null and is_instance_valid(c):
		c.aplicar_layout(Config.hud_pos, float(o["sc"]) / 100.0, float(o["op"]) / 100.0)
		c.set_info(bool(o["fps"]))
		c.configurar_teclado(o)
	var h = main.get("hud")
	if h != null and is_instance_valid(h):
		h.aplicar_estilo(float(o["sc"]) / 100.0, float(o["op"]) / 100.0)
	for nome in ["mapa", "hud_status"]:
		var x = main.get(nome)
		if x != null and is_instance_valid(x):
			x.aplicar_estilo(float(o["sc"]) / 100.0, float(o["op"]) / 100.0)
	var cid = main.get("cidade")
	if cid != null and is_instance_valid(cid):
		if cid.sol != null:
			cid.sol.shadow_enabled = int(g["shad"]) >= 2
		if cid.has_method("aplicar_detalhes"):
			cid.aplicar_detalhes(int(g["shd"]), int(g["detd"]), bool(g["wtr"]))     # janelas dos prédios · árvores/caixas d'água
		# 0.84: as opções que estavam "em breve"
		if cid.has_method("aplicar_texturas"):
			cid.aplicar_texturas(int(g.get("tex", 3)), int(g.get("aniso", 1)))   # texturas e filtragem anisotrópica do chão
		var ab = cid.get("abandono")
		if ab != null:
			ab.aplicar_modelos(int(g.get("models", 2)))                       # até onde os objetos da rua aparecem
			ab.aplicar_luzes(bool(g.get("wire", true)), bool(g.get("halo", true)))   # fios de poste · halos de luz
		_efeitos_ultra(cid)
		if cid.ambiente != null:
			# raio de chunks menor que a distância de visão: mais neblina, para a borda do mundo carregado não aparecer
			var corte: float = ALCANCE[clampi(int(g["dist"]), 0, 3)] / alcance_visao()
			cid.ambiente.fog_density = NEVOA_BASE * NEVOA[clampi(int(g["fog"]), 0, 2)] * NEVOA_DIST[clampi(int(g["dist"]), 0, 3)] * corte
		var ch = main.get("chunks")
		if ch != null and is_instance_valid(ch):
			ch.definir_raio(raio_chunks())

func _aplicar_resolucao() -> void:
	var g: Dictionary = Config.g
	var base: float = float(g["rp"]) / 100.0 if int(g["rp"]) > 35 else RESOLUCAO[clampi(int(g["res"]), 0, 3)]
	# celular: a tela já tem muitos pixels; no máximo 80% da resolução nativa (bem mais leve, quase igual de nítido)
	if OS.has_feature("mobile") and int(g["rp"]) <= 35:
		base = minf(base, 0.8)
	var f := _dinamica if bool(g["dyn"]) else 1.0
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = clampf(base * f, 0.25, 1.0)

# resolução dinâmica: baixa a resolução quando o FPS cai e sobe de novo quando sobra
func _process(dt: float) -> void:
	if not bool(Config.g.get("dyn", false)) or get_tree().paused:
		return
	_fps_soma += Engine.get_frames_per_second()
	_fps_n += 1
	_t_fps += dt
	if _t_fps < 1.5:
		return
	var media := _fps_soma / maxf(1.0, float(_fps_n))
	_t_fps = 0.0
	_fps_soma = 0.0
	_fps_n = 0
	var alvo := float(Config.g["cap"]) if int(Config.g["cap"]) > 0 else 60.0
	var antes := _dinamica
	if media < alvo * 0.75:
		_dinamica = maxf(0.6, _dinamica - 0.08)
	elif media > alvo * 0.95:
		_dinamica = minf(1.0, _dinamica + 0.04)
	if not is_equal_approx(antes, _dinamica):
		_aplicar_resolucao()
