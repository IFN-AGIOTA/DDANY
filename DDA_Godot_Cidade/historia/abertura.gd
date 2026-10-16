extends Node
# ABERTURA DA HISTÓRIA (o "teaser trailer" refeito dentro do jogo), ~74 s. Passa uma vez, na primeira vez que a
# história começa (Config "abertura_vista"); dá para PULAR. Mesma sequência do teaser:
#   0 s    logo INFINITY STUDIO sobre os prédios na neblina, céu rosado
#   4 s    avenida vazia na hora azul, câmera andando devagar
#   15 s   clarão · centro da cidade visto do alto, arranha-céus na névoa
#   26 s   câmera caída, torta, rente ao chão, neblina grossa · pausa
#   29 s   clarão · pôr do sol rosa e laranja atrás dos prédios, a câmera vai tombando
#   41 s   clarão girando · olhando para cima entre as torres
#   47 s   clarão · na chuva, um prédio tomba sobre a avenida
#   52 s   topo do prédio mais alto, antenas · a câmera sobe e aparece o título
#          DIAS DE UM / APOCALIPSE / Nova York, com a mancha de tinta
#   65 s   clarão · tela preta até a música acabar
# Música: audio/abertura.ogg (feita por ferramentas/compor_abertura.py, com o rádio ao fundo). Os clarões
# (CLAROES) batem com as pancadas da música.
# Mexa AQUI para: lugares e movimentos de câmera (TOMADAS / _tomada), cores (GRADES) e textos do título.

signal terminou

const UI := preload("res://menu/ui.gd")
const MUSICA := "res://audio/abertura.ogg"
const LOGO := "res://historia/abertura/logo_infinity_studio.png"
const FONTE_TITULO := "res://menu/fontes/anton-400-normal.woff2"            # Anton (OFL): letra grossa do teaser
const FONTE_CURSIVA := "res://menu/fontes/great-vibes-400-normal.woff2"     # Great Vibes (OFL): "Nova York"
const FIM := 73.5
const CLAROES := [15.0, 29.0, 41.0, 47.0, 51.0, 65.0]
const TELHADO := Vector3(-1460.0, 163.6, -138.0)        # topo da torre da ponta leste do centro (163 m, vista livre)
const PREDIO_QUEDA := Vector3(-1245.0, 0.6, -198.0)      # onde o prédio que tomba fica (beira da avenida)

# correção de cor de cada tomada: [saturação, tinta (multiplica), exposição, contraste]
const GRADES := {
	"azul": [0.55, Color(0.80, 0.92, 1.10), 1.25, 1.08],
	"rosa": [0.85, Color(1.06, 0.92, 1.00), 1.1, 1.05],
	"cinza": [0.45, Color(0.92, 0.95, 1.02), 1.15, 1.1],
}

const SHADER_POS := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform float saturacao = 0.6;
uniform vec4 tinta : source_color = vec4(0.8, 0.9, 1.1, 1.0);
uniform float exposicao = 1.2;
uniform float contraste = 1.05;
uniform float clarao = 0.0;
uniform float tempo = 0.0;
void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb * exposicao;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturacao) * tinta.rgb;
	c = (c - 0.5) * contraste + 0.5;
	c += vec3(0.0, 0.01, 0.035) * (1.0 - l);                  // sombras puxando para o azul
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * 1.1;                                 // vinheta
	float g = fract(sin(dot(SCREEN_UV * 731.0 + tempo * 13.0, vec2(12.9898, 78.233))) * 43758.5453);
	c += (g - 0.5) * 0.045;                                     // grão de filme
	c = mix(c, vec3(1.0, 0.98, 0.95), clamp(clarao, 0.0, 1.0));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

var main = null
var cam: Camera3D
var pulando := false
var _player: AudioStreamPlayer
var _t := 0.0
var _ui: CanvasLayer
var _pos: ColorRect
var _mat_pos: ShaderMaterial
var _preto: ColorRect
var _barras: Array[ColorRect] = []
var _logo: TextureRect
var _titulo: Control
var _mancha: TextureRect
var _txt_apoc: Label
var _txt_dias: Label
var _txt_ny: Label
var _pular: Button
var _cenario: Node3D
var _predio_queda: Node3D
var _poeira: CPUParticles3D
var _escondidos: Array = []
var _hora_antes := 20.6
var _pos_jogador := Vector3.ZERO
var _tomada_atual := ""
var _rng := RandomNumberGenerator.new()

# ---------- começo e fim ----------
func tocar(m) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 2024
	_preparar()
	_player.play()
	while not pulando:
		await get_tree().process_frame
		_t = _player.get_playback_position() if _player.playing else _t + get_process_delta_time()
		if _t >= FIM or (not _player.playing and _t > 5.0):
			break
		_quadro(_t)
	await _encerrar()
	terminou.emit()

func _preparar() -> void:
	for nome in ["controles", "hud", "hud_status", "mapa"]:
		var n = main.get(nome)
		if n != null and is_instance_valid(n) and n.visible:
			n.visible = false
			_escondidos.append(n)
	var j = main.jogador
	_pos_jogador = j.global_position
	j.ativo = false
	j.visible = false
	j.velocity = Vector3.ZERO
	if main.vagos != null:
		main.vagos.process_mode = Node.PROCESS_MODE_DISABLED
		for c in main.vagos.get_children():
			if c is Node3D:
				c.visible = false
	if main.clima != null:
		_hora_antes = main.clima.hora
		main.clima.parado = true
		main.clima.som_mudo = true
	Musica.suspender(true)
	cam = Camera3D.new()
	cam.near = 0.1
	cam.far = 4000.0
	main.jogo.add_child(cam)
	cam.make_current()
	_player = AudioStreamPlayer.new()
	_player.stream = load(MUSICA)
	var bus := AudioServer.get_bus_index("Musica")
	_player.volume_db = AudioServer.get_bus_volume_db(bus) if bus >= 0 and not AudioServer.is_bus_mute(bus) else 0.0
	add_child(_player)
	_montar_cenario()
	_montar_ui()

func _encerrar() -> void:
	_preto.color.a = 1.0
	_titulo.visible = false
	_logo.visible = false
	await get_tree().process_frame
	_player.stop()
	if _cenario != null:
		_cenario.queue_free()
	var j = main.jogador
	j.global_position = _pos_jogador
	j.ativo = true
	j.visible = true
	j.camera.make_current()
	cam.queue_free()
	if main.vagos != null:
		main.vagos.process_mode = Node.PROCESS_MODE_INHERIT
		for c in main.vagos.get_children():
			if c is Node3D:
				c.visible = true
	for n in _escondidos:
		if is_instance_valid(n):
			n.visible = true
	if main.clima != null:
		main.clima.nevoa_extra = 1.0
		main.clima.som_mudo = false
		main.clima.forcar_tempo("limpo", true)
		main.clima.definir_hora(_hora_antes)
	Musica.suspender(false)
	_ui.queue_free()

# ---------- cada quadro ----------
func _quadro(t: float) -> void:
	var s := _tomada(t)
	if s["nome"] != _tomada_atual:
		_tomada_atual = s["nome"]
		_entrar_tomada(s)
	# câmera (com tremido de câmera na mão)
	var tremor: float = s.get("tremor", 0.0)
	var p: Vector3 = s["pos"] + Vector3(_ruido(t * 1.3, 1.0), _ruido(t * 1.1, 2.0), _ruido(t * 0.9, 3.0)) * tremor
	cam.fov = s["fov"]
	cam.global_position = p
	cam.look_at(s["alvo"], Vector3.UP)
	var giro: float = s.get("giro", 0.0)
	# o clarão do segundo 41 gira a imagem
	if t > 40.75 and t < 41.35:
		giro += smoothstep(40.75, 41.35, t) * 160.0
	cam.rotate_object_local(Vector3.BACK, deg_to_rad(giro))
	# prédio tombando
	if _predio_queda != null:
		_predio_queda.visible = t > 46.5 and t < 52.2
		var q := clampf((t - 47.0) / 5.0, 0.0, 1.0)
		_predio_queda.rotation.x = deg_to_rad(12.0 + 48.0 * q * q)
		_poeira.emitting = _predio_queda.visible
	# cor, clarões, preto, logo e título
	var g: Array = GRADES[s["grade"]]
	_mat_pos.set_shader_parameter("saturacao", g[0])
	_mat_pos.set_shader_parameter("tinta", g[1])
	_mat_pos.set_shader_parameter("exposicao", g[2])
	_mat_pos.set_shader_parameter("contraste", g[3])
	_mat_pos.set_shader_parameter("tempo", t)
	_mat_pos.set_shader_parameter("clarao", _clarao(t))
	var preto := 0.0
	preto = maxf(preto, 1.0 - smoothstep(0.0, 1.2, t))                    # abre do escuro
	preto = maxf(preto, smoothstep(27.6, 28.3, t) * (0.0 if t >= 29.0 else 1.0))   # a pausa antes da pancada
	preto = maxf(preto, smoothstep(65.25, 65.7, t))                        # depois do último clarão
	_preto.color.a = preto
	_logo.modulate.a = smoothstep(0.6, 1.4, t) * (1.0 - smoothstep(3.1, 3.7, t))
	_logo.scale = Vector2.ONE * (1.0 + t * 0.012)
	_titulo.visible = t > 52.8 and t < 65.3
	if _titulo.visible:
		var a := smoothstep(53.0, 54.4, t)
		_titulo.modulate.a = a
		_mancha.scale = Vector2.ONE * lerpf(0.55, 1.0, smoothstep(53.0, 54.0, t))
		_mancha.modulate.a = smoothstep(53.0, 53.6, t)
		_txt_apoc.modulate.a = smoothstep(53.6, 54.6, t)
		_txt_dias.modulate.a = smoothstep(54.2, 55.2, t)
		_txt_ny.modulate.a = smoothstep(54.6, 55.8, t)
	_ajustar_ui()

func _clarao(t: float) -> float:
	var v := 0.0
	for c in CLAROES:
		var c2: float = c
		if t >= c2 - 0.18 and t < c2:
			v = maxf(v, (t - (c2 - 0.18)) / 0.18)
		elif t >= c2:
			v = maxf(v, exp(-(t - c2) * 5.0))
	return v

func _ruido(x: float, semente: float) -> float:
	return sin(x * 1.7 + semente * 3.1) * 0.6 + sin(x * 3.9 + semente * 7.3) * 0.3 + sin(x * 8.3 + semente) * 0.1

func _entrar_tomada(s: Dictionary) -> void:
	var c = main.clima
	if c != null:
		c.forcar_tempo(s["tempo"], true)
		c.nevoa_extra = s["nevoa"]
		c.definir_hora(s["hora"])
	var p: Vector3 = s["pos"]
	main.mundo.forcar(Vector2(p.x, p.z))
	main.jogador.global_position = Vector3(p.x, main.mundo.altura(p.x, p.z), p.z)

# ---------- as tomadas (lugares do centro de Nova York) ----------
func _tomada(t: float) -> Dictionary:
	if t < 3.8:          # logo: prédios na neblina, céu rosado
		var u := t / 3.8
		return {"nome": "logo", "pos": Vector3(-1655.0 + 8.0 * u, 3.0, -171.0), "alvo": Vector3(-1460.0, 70.0, -140.0),
			"fov": 55.0, "hora": 19.35, "tempo": "nublado", "nevoa": 3.0, "grade": "rosa"}
	if t < 15.0:         # avenida vazia na hora azul, câmera andando
		var u := (t - 3.8) / 11.2
		return {"nome": "avenida", "pos": Vector3(-1140.0 + 30.0 * u, 5.0 + 0.8 * u, -493.0),
			"alvo": Vector3(-950.0 + 30.0 * u, 14.0, -497.0), "fov": 52.0, "hora": 20.05, "tempo": "limpo",
			"nevoa": 2.2, "grade": "azul"}
	if t < 25.8:         # centro visto do alto
		var u := (t - 15.0) / 10.8
		return {"nome": "centro", "pos": Vector3(-1285.0 - 25.0 * u, 24.0 + 3.0 * u, -8.0 - 22.0 * u),
			"alvo": Vector3(-1560.0, 62.0, -115.0), "fov": 48.0, "hora": 20.15, "tempo": "limpo", "nevoa": 3.0,
			"grade": "azul"}
	if t < 29.0:         # caído no chão, câmera torta
		var u := (t - 25.8) / 3.2
		return {"nome": "chao", "pos": Vector3(-1470.0 - 6.0 * u, 0.95, -31.0), "alvo": Vector3(-1620.0, 9.0, -27.0),
			"fov": 60.0, "giro": 14.0, "tremor": 0.06, "hora": 20.3, "tempo": "nublado", "nevoa": 5.0,
			"grade": "azul"}
	if t < 41.0:         # pôr do sol, a câmera vai tombando
		var u := (t - 29.0) / 12.0
		return {"nome": "por_do_sol", "pos": Vector3(-1484.0 - 18.0 * u, 7.0 + 2.0 * u, -17.0),
			"alvo": Vector3(-1700.0, 40.0 - 6.0 * u, -17.0), "fov": 50.0, "giro": -22.0 * u * u, "hora": 19.22,
			"tempo": "limpo", "nevoa": 2.4, "grade": "rosa"}
	if t < 47.0:         # olhando para cima entre as torres
		var u := (t - 41.0) / 6.0
		return {"nome": "torres", "pos": Vector3(-1578.0 + 22.0 * u, 1.7, -116.5),
			"alvo": Vector3(-1540.0 + 22.0 * u, 165.0, -114.0), "fov": 64.0, "giro": 6.0 - 4.0 * u,
			"tremor": 0.03, "hora": 20.0, "tempo": "nublado", "nevoa": 2.5, "grade": "azul"}
	if t < 52.0:         # na chuva, o prédio tomba sobre a avenida
		var u := (t - 47.0) / 5.0
		return {"nome": "queda", "pos": Vector3(-1330.0 + 10.0 * u, 2.2, -171.0),
			"alvo": PREDIO_QUEDA + Vector3(-10.0, 38.0, 14.0), "fov": 55.0, "tremor": 0.08 * u, "hora": 20.4,
			"tempo": "chuva", "nevoa": 2.0, "grade": "azul"}
	# topo do prédio mais alto: a câmera sobe entre as antenas e mostra a cidade
	var u := clampf((t - 52.0) / 13.0, 0.0, 1.0)
	var k := u * u * (3.0 - 2.0 * u)
	return {"nome": "telhado", "pos": TELHADO + Vector3(7.0 - 1.0 * k, 2.6 + 5.0 * k, -0.5),
		"alvo": TELHADO + Vector3(330.0, -24.0 + 10.0 * k, -50.0), "fov": 55.0, "hora": 19.05, "tempo": "nublado",
		"nevoa": 2.2, "grade": "cinza"}

# ---------- cenário extra: antenas no telhado e o prédio que tomba ----------
func _montar_cenario() -> void:
	_cenario = Node3D.new()
	_cenario.name = "CenarioAbertura"
	main.jogo.add_child(_cenario)
	var metal := _mat(Color(0.32, 0.33, 0.35), 0.5, 0.6)
	var escuro := _mat(Color(0.14, 0.14, 0.15), 0.8)
	var luz := _mat(Color(1.0, 0.15, 0.1), 0.5)
	luz.emission_enabled = true
	luz.emission = Color(1.0, 0.1, 0.05)
	luz.emission_energy_multiplier = 3.0
	# antenas com luz vermelha na ponta
	for a in [[Vector3(11, 0, -6), 14.0], [Vector3(10, 0, 4.5), 9.0], [Vector3(11.5, 0, -1.5), 11.0], [Vector3(9.5, 0, 8), 7.0]]:
		var h: float = a[1]
		var base: Vector3 = TELHADO + a[0]
		_caixa(base + Vector3(0, h * 0.5, 0), Vector3(0.18, h, 0.18), metal)
		for k in 3:
			var y := h * (0.35 + 0.22 * k)
			_caixa(base + Vector3(0, y, 0), Vector3(1.4 - k * 0.35, 0.06, 0.06), metal)
		_esfera(base + Vector3(0, h + 0.15, 0), 0.18, luz)
	# pratos de satélite
	for d in [[Vector3(10, 0, -9), -60.0], [Vector3(11, 0, 10.5), -120.0]]:
		var p: Vector3 = TELHADO + d[0]
		_caixa(p + Vector3(0, 0.6, 0), Vector3(0.15, 1.2, 0.15), metal)
		var prato := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.1
		cm.bottom_radius = 0.25
		cm.height = 0.45
		cm.radial_segments = 16
		prato.mesh = cm
		prato.material_override = _mat(Color(0.75, 0.75, 0.72), 0.6)
		_cenario.add_child(prato)
		prato.global_position = p + Vector3(0, 1.5, 0)
		prato.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(d[1]), 0)
	# caixa d'água de Nova York (madeira, pernas de ferro)
	var cx: Vector3 = TELHADO + Vector3(-4, 0, -8)
	for i in 4:
		var ang := TAU * i / 4.0 + 0.78
		_caixa(cx + Vector3(cos(ang) * 1.6, 2.0, sin(ang) * 1.6), Vector3(0.2, 4.0, 0.2), escuro)
	var tanque := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 2.2
	tm.bottom_radius = 2.2
	tm.height = 4.0
	tanque.mesh = tm
	tanque.material_override = _mat(Color(0.36, 0.26, 0.18), 0.9)
	_cenario.add_child(tanque)
	tanque.global_position = cx + Vector3(0, 6.0, 0)
	var teto := MeshInstance3D.new()
	var tt := CylinderMesh.new()
	tt.top_radius = 0.05
	tt.bottom_radius = 2.4
	tt.height = 1.4
	teto.mesh = tt
	teto.material_override = escuro
	_cenario.add_child(teto)
	teto.global_position = cx + Vector3(0, 8.7, 0)
	# ar-condicionado e casa de máquinas
	_caixa(TELHADO + Vector3(-8, 1.6, 7), Vector3(5.0, 3.2, 4.0), _mat(Color(0.45, 0.44, 0.42), 0.9))
	for i in 4:
		_caixa(TELHADO + Vector3(-10.5, 0.6, -6 + i * 2.2), Vector3(1.4, 1.2, 1.6), _mat(Color(0.55, 0.56, 0.56), 0.7))
	# mureta em volta (o prédio tem 26 x 28 m)
	var mureta := _mat(Color(0.4, 0.39, 0.37), 0.95)
	_caixa(TELHADO + Vector3(0, 0.55, -13.5), Vector3(25.0, 1.1, 0.4), mureta)
	_caixa(TELHADO + Vector3(0, 0.55, 13.5), Vector3(25.0, 1.1, 0.4), mureta)
	_caixa(TELHADO + Vector3(-12.5, 0.55, 0), Vector3(0.4, 1.1, 27.0), mureta)
	_caixa(TELHADO + Vector3(12.5, 0.55, 0), Vector3(0.4, 1.1, 27.0), mureta)
	# o prédio que tomba: gira em volta da quina de baixo, do lado da avenida (+Z)
	_predio_queda = Node3D.new()
	_cenario.add_child(_predio_queda)
	_predio_queda.global_position = PREDIO_QUEDA + Vector3(0, -12.0, 12.0)
	var corpo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(22.0, 110.0, 24.0)
	corpo.mesh = bm
	var mp := StandardMaterial3D.new()
	mp.albedo_texture = _textura_janelas()
	mp.uv1_triplanar = true
	mp.uv1_scale = Vector3(1.0, 1.0, 1.0) / 28.0          # 8 andares de janelas a cada 28 m
	mp.roughness = 0.9
	mp.albedo_color = Color(0.75, 0.74, 0.76)
	corpo.material_override = mp
	_predio_queda.add_child(corpo)
	corpo.position = Vector3(0, 55.0, -12.0)
	_predio_queda.visible = false
	_poeira = CPUParticles3D.new()
	_poeira.amount = 160
	_poeira.lifetime = 4.0
	_poeira.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_poeira.emission_box_extents = Vector3(18, 2, 14)
	_poeira.direction = Vector3(0, 1, 0)
	_poeira.spread = 70.0
	_poeira.initial_velocity_min = 2.0
	_poeira.initial_velocity_max = 6.0
	_poeira.gravity = Vector3(0, 0.3, 0)
	_poeira.scale_amount_min = 4.0
	_poeira.scale_amount_max = 9.0
	var pm := QuadMesh.new()
	pm.size = Vector2(1, 1)
	var mpo := StandardMaterial3D.new()
	mpo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mpo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mpo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mpo.albedo_texture = _textura_fumaca()
	mpo.albedo_color = Color(0.55, 0.57, 0.62, 0.35)
	mpo.vertex_color_use_as_albedo = true
	pm.material = mpo
	_poeira.mesh = pm
	_poeira.emitting = false
	_cenario.add_child(_poeira)
	_poeira.global_position = PREDIO_QUEDA + Vector3(0, 2, 6)
	_montar_locais()

# ---------- lugares novos para ficar com a cara do teaser ----------
func _montar_locais() -> void:
	var folha := _mat(Color(0.13, 0.2, 0.12), 0.95)
	var tronco := _mat(Color(0.22, 0.17, 0.12), 0.95)
	var poste := _mat(Color(0.18, 0.18, 0.2), 0.6, 0.4)
	# AVENIDA (4-15 s): árvores e postes de luz laranja dos dois lados, globo luminoso num telhado
	for i in 11:
		var x := -1120.0 + i * 19.0
		for lado in [-1.0, 1.0]:
			var z: float = -493.0 + lado * 13.5
			if main.mundo.dentro_de_predio(x, z, 1.5, true):
				continue
			_arvore(Vector3(x + lado * 4.0, 0.6, z), folha, tronco, 1.0 + 0.15 * sin(i * 2.3 + lado))
			if i % 2 == 0:
				_poste_luz(Vector3(x + 9.0, 0.6, z - lado * 1.5), -lado, poste)
	# prédio de escritórios baixo com o globo no telhado (como o do teaser), à direita da avenida
	var esc := MeshInstance3D.new()
	var eb := BoxMesh.new()
	eb.size = Vector3(40.0, 20.0, 20.0)
	esc.mesh = eb
	var me := StandardMaterial3D.new()
	me.albedo_texture = _textura_janelas(0.45)
	me.uv1_triplanar = true
	me.uv1_scale = Vector3(1.0, 1.0, 1.0) / 22.0
	me.emission_enabled = true
	me.emission_texture = _textura_janelas(0.45, true)
	me.albedo_color = Color(0.5, 0.5, 0.52)
	me.emission = Color(0.9, 0.95, 0.7)
	me.emission_energy_multiplier = 0.22
	esc.material_override = me
	_cenario.add_child(esc)
	esc.global_position = Vector3(-1010.0, 10.6, -462.0)
	_globo(Vector3(-1010.0, 20.6, -462.0), "NEW YORK GLOBE")
	# CENTRO (15-26 s): prédio de colunas (como uma prefeitura) na praça, postes acesos
	_colunata(Vector3(-1385.0, 0.6, -40.0), deg_to_rad(63.0))
	for k in 6:
		_poste_luz(Vector3(-1335.0 - k * 9.0, 0.6, -20.0 - k * 6.0), 1.0, poste)
	# CHÃO (26-29 s): árvores na neblina
	for k in 4:
		_arvore(Vector3(-1500.0 - k * 22.0, 0.6, -41.0 + (k % 2) * 25.0), folha, tronco, 1.2)
	# PÔR DO SOL (29-41 s): outdoor de emergência à esquerda
	_outdoor(Vector3(-1528.0, 0.6, 4.0), PI * 0.5 + 0.35, "STAY INDOORS", "CITY EMERGENCY NOTICE")
	# TORRES (41-47 s): escadas de incêndio na fachada e um letreiro vermelho lá no alto
	for k in 12:
		_escada_incendio(Vector3(-1566.0 + k * 0.0, 3.0 + k * 3.6, -123.2), poste)
		_escada_incendio(Vector3(-1546.0, 3.0 + k * 3.6, -123.2), poste)
	var neon := _mat(Color(1.0, 0.1, 0.08), 0.5)
	neon.emission_enabled = true
	neon.emission = Color(1.0, 0.08, 0.05)
	neon.emission_energy_multiplier = 4.0
	_caixa(Vector3(-1540.0, 72.0, -123.0), Vector3(9.0, 0.8, 0.3), neon)

func _predio_perto(x: float, z: float) -> Array:
	var P: PackedFloat32Array = main.cidade.predios
	var melhor: Array = []
	var dmin := 1e9
	for idx in main.mundo.predios_perto(x, z, 60.0):
		var d := Vector2(P[idx * 5] - x, P[idx * 5 + 1] - z).length()
		if d < dmin:
			dmin = d
			melhor = [P[idx * 5], P[idx * 5 + 1], P[idx * 5 + 2], P[idx * 5 + 3], P[idx * 5 + 4]]
	return melhor

func _arvore(p: Vector3, folha: Material, tronco: Material, esc: float) -> void:
	var t := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.18 * esc
	c.bottom_radius = 0.26 * esc
	c.height = 3.2 * esc
	t.mesh = c
	t.material_override = tronco
	_cenario.add_child(t)
	t.global_position = p + Vector3(0, 1.6 * esc, 0)
	for k in 3:
		var f := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = (2.2 - k * 0.4) * esc
		sm.height = sm.radius * 1.6
		sm.radial_segments = 8
		sm.rings = 5
		f.mesh = sm
		f.material_override = folha
		_cenario.add_child(f)
		f.global_position = p + Vector3(sin(k * 2.1) * 0.8, (3.6 + k * 1.1) * esc, cos(k * 2.1) * 0.8)

func _poste_luz(p: Vector3, lado: float, m: Material) -> void:
	_caixa(p + Vector3(0, 4.0, 0), Vector3(0.18, 8.0, 0.18), m)
	_caixa(p + Vector3(0, 7.9, lado * 1.0), Vector3(0.12, 0.12, 2.0), m)
	var lamp := _mat(Color(1.0, 0.6, 0.25), 0.5)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.55, 0.2)
	lamp.emission_energy_multiplier = 5.0
	_caixa(p + Vector3(0, 7.75, lado * 1.9), Vector3(0.45, 0.15, 0.7), lamp)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 1.6
	l.omni_range = 16.0
	_cenario.add_child(l)
	l.global_position = p + Vector3(0, 7.0, lado * 1.9)

func _globo(topo: Vector3, texto: String) -> void:
	var base := _mat(Color(0.25, 0.25, 0.27), 0.6, 0.5)
	_caixa(topo + Vector3(0, 2.0, 0), Vector3(0.6, 4.0, 0.6), base)
	var g := _mat(Color(0.35, 0.45, 0.6), 0.35, 0.6)
	g.emission_enabled = true
	g.emission = Color(0.25, 0.35, 0.55)
	g.emission_energy_multiplier = 0.6
	_esfera(topo + Vector3(0, 8.0, 0), 5.5, g)
	var anel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 5.7
	tm.outer_radius = 6.2
	anel.mesh = tm
	anel.material_override = base
	_cenario.add_child(anel)
	anel.global_position = topo + Vector3(0, 8.0, 0)
	var l := Label3D.new()
	l.text = texto
	l.font_size = 160
	l.pixel_size = 0.02
	l.modulate = Color(1.0, 0.25, 0.2)
	l.outline_size = 0
	l.shaded = false
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_cenario.add_child(l)
	l.global_position = topo + Vector3(-6.5, 8.0, 0)
	l.rotation.y = -PI * 0.5                      # virado para quem vem pela avenida (de oeste)

func _colunata(c: Vector3, giro: float) -> void:
	var no := Node3D.new()
	_cenario.add_child(no)
	no.global_position = c
	no.rotation.y = giro
	no.scale = Vector3.ONE * 1.25
	var pedra := _mat(Color(0.62, 0.6, 0.56), 0.9)
	var parede := _mat(Color(0.48, 0.46, 0.43), 0.9)
	var partes := [[Vector3(0, 0.6, 0), Vector3(56, 1.2, 18), pedra],         # escadaria/base
		[Vector3(0, 9.0, -4), Vector3(52, 16, 9), parede],                     # corpo do prédio
		[Vector3(0, 17.6, 1), Vector3(56, 1.4, 16), pedra],                    # cornija
		[Vector3(0, 19.5, 1), Vector3(40, 2.4, 14), pedra]]                    # ático
	for pt in partes:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = pt[1]
		mi.mesh = b
		mi.material_override = pt[2]
		no.add_child(mi)
		mi.position = pt[0]
	for k in 14:
		var col := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.7
		cm.bottom_radius = 0.8
		cm.height = 15.6
		cm.radial_segments = 10
		col.mesh = cm
		col.material_override = pedra
		no.add_child(col)
		col.position = Vector3(-24.0 + k * 48.0 / 13.0, 9.0, 4.5)
	var janela := _mat(Color(1.0, 0.75, 0.4), 0.6)
	janela.emission_enabled = true
	janela.emission = Color(1.0, 0.7, 0.35)
	janela.emission_energy_multiplier = 1.5
	for k in 5:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(2.0, 3.0, 0.2)
		mi.mesh = b
		mi.material_override = janela
		no.add_child(mi)
		mi.position = Vector3(-18.0 + k * 9.0, 6.0, 0.6)

func _outdoor(p: Vector3, giro: float, grande: String, pequeno: String) -> void:
	var no := Node3D.new()
	_cenario.add_child(no)
	no.global_position = p
	no.rotation.y = giro
	var ferro := _mat(Color(0.2, 0.2, 0.22), 0.7, 0.4)
	for x in [-3.0, 3.0]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.4, 9.0, 0.4)
		mi.mesh = b
		mi.material_override = ferro
		no.add_child(mi)
		mi.position = Vector3(x, 4.5, 0)
	var painel := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(12.0, 5.0, 0.3)
	painel.mesh = pb
	painel.material_override = _mat(Color(0.86, 0.72, 0.22), 0.8)
	no.add_child(painel)
	painel.position = Vector3(0, 11.0, 0)
	for par in [[grande, 150, 12.0], [pequeno, 60, 9.0]]:
		var l := Label3D.new()
		l.text = par[0]
		l.font_size = par[1]
		l.pixel_size = 0.02
		l.modulate = Color(0.06, 0.06, 0.06)
		l.outline_size = 0
		l.shaded = true
		no.add_child(l)
		l.position = Vector3(0, float(par[2]), 0.17)

func _escada_incendio(p: Vector3, m: Material) -> void:
	_caixa(p + Vector3(0, 0, 0.7), Vector3(4.0, 0.1, 1.4), m)                  # plataforma
	_caixa(p + Vector3(0, 0.55, 1.4), Vector3(4.0, 0.06, 0.06), m)             # grade
	for x in [-2.0, 0.0, 2.0]:
		_caixa(p + Vector3(x, 0.3, 1.4), Vector3(0.05, 0.6, 0.05), m)
	var deg := MeshInstance3D.new()                                           # escada inclinada até o andar de cima
	var b := BoxMesh.new()
	b.size = Vector3(0.8, 0.08, 4.4)
	deg.mesh = b
	deg.material_override = m
	_cenario.add_child(deg)
	deg.global_position = p + Vector3(0.6, 1.8, 0.7)
	deg.rotation = Vector3(0, PI * 0.5, deg_to_rad(-55.0))

func _mat(cor: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rough
	m.metallic = metal
	return m

func _caixa(p: Vector3, tam: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = m
	_cenario.add_child(mi)
	mi.global_position = p

func _esfera(p: Vector3, r: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = m
	_cenario.add_child(mi)
	mi.global_position = p

# fachada: concreto com janelas escuras e algumas acesas
func _textura_janelas(acesas := 0.28, so_luz := false) -> ImageTexture:
	var im := Image.create(128, 128, false, Image.FORMAT_RGB8)
	im.fill(Color(0, 0, 0) if so_luz else Color(0.30, 0.30, 0.32))
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for jy in 8:
		for jx in 8:
			var c := Color(0, 0, 0) if so_luz else Color(0.06, 0.07, 0.09)
			if r.randf() < acesas:
				c = Color(0.9, 0.85, 0.55)
			im.fill_rect(Rect2i(jx * 16 + 3, jy * 16 + 4, 10, 9), c)
	return ImageTexture.create_from_image(im)

func _textura_fumaca() -> ImageTexture:
	var im := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			im.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(im)

# mancha de tinta preta (respingos) atrás do título, feita uma vez
func _textura_mancha() -> ImageTexture:
	var w := 900
	var h := 420
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var gotas: Array = []
	# borrão principal (vários círculos sobrepostos, mais denso à esquerda e no meio)
	for i in 140:
		var c := Vector2(r.randf_range(0.22, 0.78) * w, r.randf_range(0.32, 0.7) * h)
		gotas.append([c, r.randf_range(10.0, 42.0)])
	# respingos espalhados
	for i in 260:
		var ang := r.randf() * TAU
		var dist := r.randf_range(0.2, 1.0)
		var c := Vector2(w * 0.5 + cos(ang) * dist * w * 0.48, h * 0.5 + sin(ang) * dist * h * 0.48)
		gotas.append([c, r.randf_range(1.5, 9.0) * (1.2 - dist)])
	# escorridos para baixo
	for i in 14:
		var x := r.randf_range(0.3, 0.75) * w
		var y0 := r.randf_range(0.55, 0.7) * h
		var comp := r.randf_range(30.0, 110.0)
		for k in int(comp / 3.0):
			gotas.append([Vector2(x + sin(k * 0.3) * 1.5, y0 + k * 3.0), 3.5 - k * 3.0 / comp * 2.0])
	for g in gotas:
		var c: Vector2 = g[0]
		var rr: float = maxf(1.0, g[1])
		for y in range(maxi(0, int(c.y - rr)), mini(h, int(c.y + rr) + 1)):
			for x in range(maxi(0, int(c.x - rr)), mini(w, int(c.x + rr) + 1)):
				var d := Vector2(x, y).distance_to(c)
				if d <= rr:
					var a := clampf(rr - d, 0.0, 1.0)
					var antes := im.get_pixel(x, y).a
					im.set_pixel(x, y, Color(0.02, 0.02, 0.02, maxf(antes, a * 0.96)))
	return ImageTexture.create_from_image(im)

# ---------- interface: correção de cor, clarão, barras, logo, título e PULAR ----------
func _montar_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 40
	add_child(_ui)
	_pos = ColorRect.new()
	_pos.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER_POS
	_mat_pos = ShaderMaterial.new()
	_mat_pos.shader = sh
	_pos.material = _mat_pos
	_ui.add_child(_pos)
	_logo = TextureRect.new()
	_logo.texture = load(LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_logo)
	_titulo = Control.new()
	_titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titulo.visible = false
	_ui.add_child(_titulo)
	_mancha = TextureRect.new()
	_mancha.texture = _textura_mancha()
	_mancha.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mancha.stretch_mode = TextureRect.STRETCH_SCALE
	_mancha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titulo.add_child(_mancha)
	_txt_apoc = UI.rotulo("APOCALIPSE", 40.0, Color(1, 1, 1), 900)
	_txt_apoc.add_theme_font_override("font", load(FONTE_TITULO))
	_txt_dias = UI.rotulo("D I A S   D E   U M", 12.0, Color(1, 1, 1, 0.92), 700)
	_txt_ny = UI.rotulo("Nova York", 14.0, Color(1, 1, 1, 0.95), 400)
	_txt_ny.add_theme_font_override("font", load(FONTE_CURSIVA))
	for l in [_txt_apoc, _txt_dias, _txt_ny]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 3)
		_titulo.add_child(l)
	for i in 2:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(b)
		_barras.append(b)
	_preto = ColorRect.new()
	_preto.color = Color(0, 0, 0, 1)
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_preto)
	_pular = Button.new()
	_pular.text = "PULAR ▶▶"
	_pular.focus_mode = Control.FOCUS_NONE
	_pular.modulate.a = 0.55
	_pular.pressed.connect(func(): pulando = true)
	_ui.add_child(_pular)
	_ajustar_ui()

func _ajustar_ui() -> void:
	var vs := get_viewport().get_visible_rect().size
	var u := vs.y / 100.0
	var hb := vs.y * 0.06
	_barras[0].position = Vector2.ZERO
	_barras[0].size = Vector2(vs.x, hb)
	_barras[1].position = Vector2(0, vs.y - hb)
	_barras[1].size = Vector2(vs.x, hb)
	var lw := vs.x * 0.36
	_logo.size = Vector2(lw, lw * 88.0 / 609.0)
	_logo.pivot_offset = _logo.size * 0.5
	_logo.position = vs * 0.5 - _logo.size * 0.5
	var mw := vs.x * 0.6
	_mancha.size = Vector2(mw, mw * 420.0 / 900.0)
	_mancha.pivot_offset = _mancha.size * 0.5
	_mancha.position = Vector2(vs.x * 0.5 - mw * 0.5, vs.y * 0.43 - _mancha.size.y * 0.5)
	_txt_apoc.add_theme_font_size_override("font_size", int(17.0 * u))
	_txt_apoc.position = Vector2(0, vs.y * 0.43 - 11.0 * u)
	_txt_apoc.size = Vector2(vs.x, 20.0 * u)
	_txt_dias.add_theme_font_size_override("font_size", int(3.2 * u))
	_txt_dias.position = Vector2(0, vs.y * 0.43 - 15.5 * u)
	_txt_dias.size = Vector2(vs.x, 5.0 * u)
	_txt_ny.add_theme_font_size_override("font_size", int(8.5 * u))
	_txt_ny.add_theme_constant_override("outline_size", int(0.8 * u))
	_txt_ny.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_txt_ny.position = Vector2(vs.x * 0.06, vs.y * 0.43 + 6.5 * u)
	_txt_ny.size = Vector2(vs.x, 12.0 * u)
	_pular.add_theme_font_size_override("font_size", int(2.6 * u))
	_pular.position = Vector2(vs.x - 20.0 * u, hb + 1.5 * u)
	_pular.size = Vector2(17.0 * u, 6.0 * u)

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		pulando = true
		get_viewport().set_input_as_handled()
