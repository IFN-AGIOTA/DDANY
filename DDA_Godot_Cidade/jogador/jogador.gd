extends CharacterBody3D
# JOGADOR EM 3ª PESSOA · soldado original do HTML, armas, correr, agachar, mirar e pular.
# Números do HTML: andar 1,7 · trote 3,9 · correr 7,2 m/s · pulo 5,2 · gravidade 15.
# Novos: AGACHADO (1,0 / 1,8 m/s, mira mais firme, alvo menor) e MIRAR (câmera aproxima, 2,2 m/s, mira mais firme).
# Correr cancela agachar e mirar. Pular agachado = levantar.
# Câmera igual à do menu: FOV 42, 2,35 m atrás, alvo a 1,52 m, personagem à esquerda (~34% da largura);
# o recuo das armas mexe a câmera como no HTML.
#
# INVENTÁRIO (estilo DayZ): nó "Inventario" criado no _ready (inventario/inventario.gd). A arma usada é a que está
# nas MÃOS; atalhos 1..8, botão ARMA (coldre <-> ombro) e PEGAR passam por ele.
#
# ÁGUA (0.72): na água rasa anda mais devagar; na funda NADA (animação "nadar", arma guardada, sem mirar/atirar/
# agachar/pular). Nadar gasta ESTAMINA (mais com peso e nadando rápido = botão correr); parado boiando ela volta,
# se não estiver pesado demais. Estamina zerada = AFUNDA: a cabeça vai para baixo d'água, o fôlego acaba e você se
# afoga (jogador/sobrevivencia.gd). Solte peso ou nade para a margem. Profundidade do mar/lagos: mundo/colisao_mundo.gd.
#
# MODELO 3D: o nó "Modelo" é o encaixe. Se existir res://modelos/personagem.glb (ou .tscn/.fbx) ele substitui o
# soldado original, com as animações (ver modelos/LEIA-ME.txt). Por código: jogador.trocar_modelo(no).

signal pulou

const GRAVIDADE := 15.0
const VEL_DEVAGAR := 1.0             # 0.59: joystick bem de leve (caminhada devagar)
const VEL_ANDAR := 2.0               # joystick até a metade (caminhada apressada) · PC: segurar ALT
const VEL_TROTE := 3.9
const VEL_CORRIDA := 7.2
const VEL_AGACHADO := 1.0
const VEL_AGACHADO_RAPIDO := 1.8
const VEL_MIRANDO := 2.2
const VEL_MIRANDO_LADO := 1.1         # 0.61: mirando e andando de lado (passos laterais) ou de costas
const MIRA_NEUTRA := 0.12            # inclinação da câmera em que a arma fica reta (a câmera fica acima do ombro)
const FORCA_PULO := 5.2
# 0.72 · água
const NADO_ALTURA := 0.66            # nadando, a origem (pés) fica isso abaixo da superfície (corpo deitado na linha d'água)
const FUNDO_NADAR := 1.35            # água mais funda que isso (da superfície ao chão) = nada
const FUNDO_ANDAR := 1.15            # nadando, o chão a menos que isso da superfície = volta a andar
const AFUNDAR := 1.2                 # afundando: o corpo desce isso (cabeça embaixo d'água)
const VEL_NADO := 1.4
const VEL_NADO_RAPIDO := 2.3
const ALTURA_EM_PE := 1.8
const ALTURA_AGACHADO := 1.3
const EXTENSOES_MODELO := ["tscn", "scn", "glb", "gltf", "fbx"]
const SonsCorpo := preload("res://audio/sons_corpo.gd")
const Sons := preload("res://audio/sons.gd")
const SonsBaixados := preload("res://audio/sons_baixados.gd")
const InventarioCls := preload("res://inventario/inventario.gd")
const SobrevivenciaCls := preload("res://jogador/sobrevivencia.gd")

@export_group("Câmera")
@export var distancia_camera := 2.35
@export var lateral_camera := 0.32      # 0,32 = personagem à esquerda · 0 = centro · -0,32 = direita
@export var fov_camera := 42.0
@export var altura_alvo := 1.52
@export var altura_alvo_agachado := 1.02
@export var distancia_mirando := 1.6
@export var fov_mirando := 34.0
@export var ombro_mirando := 0.55      # mirando, a câmera vai para cima do ombro direito (metros)
@export var sensibilidade := 1.0
@export var inverter_y := false         # Opções › Controles › Eixo vertical
var giroscopio := false                 # Opções › Controles › Giroscópio (olhar mexendo o celular)
var giro_sens := 1.0
var giro_inv := false
var giro_zero := Vector3.ZERO
@export_group("Modelo")
@export var giro_modelo_importado := 180.0   # modelos glTF olham para +Z; se andar de costas, troque 180 <-> 0
@export var escala_modelo := 1.0

var controles = null                # controles.gd (toque/teclado)
var inventario: Node = null         # inventario/inventario.gd
var sobrevivencia: Node = null      # jogador/sobrevivencia.gd (vida, sangue, fome, sede, temperatura)
var mundo = null                    # colisao_mundo.gd (altura do chão e raio dos tiros)
var ativo := true
var _agachar_ant := -1               # 0.64: agachar "segurar": último estado da tecla (só age quando muda)
var _t_agachar := 0.0
var _som_passo: AudioStreamPlayer
var _som_voz: AudioStreamPlayer
var _dist_passo := 0.0
var _n_passo := 0
var _t_dor := 0.0
var morto := false
var agachado := false
var mancando := false                # perna quebrada (o animador troca a caminhada por "mancar")
var mirando := false                # mira (aproxima a câmera); ligada pelo botão MIRAR ou botão direito do mouse
var atirando := false               # atirou há pouco / arma erguida (o corpo vira para a mira)
var cam_yaw := 0.0                  # 0 = olhando para -Z
var cam_pit := 0.05                 # positivo = câmera acima olhando para baixo (-0,35 a 1,15)
var mira_pitch := 0.0                # 0.61: para onde a arma aponta (+ = para cima), a partir da câmera (camada_mira.gd)
var sens_mouse := 1.0                # 0.62: Opções › Teclado e mouse (menu/aplicar_opcoes.gd)
var sens_mouse_mira := 0.7
var inverter_y_mouse := false       # 0.62: eixo vertical do mouse invertido
var vel_horizontal := 0.0
var nadando := false                # 0.72: na água funda
var afundando := false              # 0.72: nadando sem estamina (cabeça embaixo d'água)
var nivel_agua := -INF              # 0.72: superfície da água aqui (-INF = seco)
var prof_agua := 0.0                # 0.72: metros de água acima dos pés (andando) · nadando = fundo do lugar
var _t_agua := 0.0
var _fundo := 0.0                   # da superfície até o chão, aqui
var _tela_agua: ColorRect = null    # câmera embaixo d'água: tela azul-esverdeada
var fator_agachado := 0.0           # 0 em pé · 1 agachado (suavizado, para a câmera)
var fator_mira := 0.0

var _mirar_ligado := false
var primeira_pessoa := false          # 0.65: câmera nos olhos (Opções › Câmera, tecla F ou botão CAM)
var _fp := 0.0                        # 0 = 3ª pessoa · 1 = 1ª pessoa (suavizado na troca)
var _near_3p := 0.05
var _pulo_ant := false
var _y_cam := 0.0

@onready var camera: Camera3D = $PivoCamera/Braco/Ponta/Camera
@onready var animador: Node = $Animador
@onready var armas: Node = $Armas
@onready var _slot: Node3D = $Modelo
@onready var _pivo: Node3D = $PivoCamera
@onready var _braco: SpringArm3D = $PivoCamera/Braco
@onready var _colisao: CollisionShape3D = $Colisao
@onready var _capsula: CapsuleShape3D = $Colisao.shape

func _ready() -> void:
	camera.fov = fov_camera
	_near_3p = camera.near
	_braco.add_excluded_object(get_rid())
	_y_cam = global_position.y
	_capsula = _capsula.duplicate()
	_colisao.shape = _capsula
	var sold := _slot.get_node_or_null("Soldado")
	animador.configurar(sold)
	armas.anexar(sold, null)
	inventario = InventarioCls.new()
	inventario.name = "Inventario"
	add_child(inventario)
	inventario.equipamento_inicial()
	sobrevivencia = SobrevivenciaCls.new()
	sobrevivencia.name = "Sobrevivencia"
	add_child(sobrevivencia)
	# animações das ações (jogador/animador_modelo.gd): pegar do chão, comer/curar, levar golpe
	inventario.animar.connect(func(n: String): animador.acao(n, 1.35 if n.begins_with("pegar") else 1.0, true))
	sobrevivencia.atingido.connect(func(_o: Vector3):
		if not morto:
			animador.acao(["levar_golpe_a", "levar_golpe_b"][randi() % 2], 1.3, false))
	armas.ligar_inventario(inventario)
	_carregar_modelo_do_projeto()
	# sons do corpo: passos e dor (audio/sons_corpo.gd)
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_som_passo = AudioStreamPlayer.new()
	_som_passo.bus = bus
	add_child(_som_passo)
	_som_voz = AudioStreamPlayer.new()
	_som_voz.bus = bus
	add_child(_som_voz)
	# 0.49: coração (vida baixa / sangrando muito) e fôlego (correu muito): laços que sobem e descem devagar
	_som_coracao = AudioStreamPlayer.new()
	_som_coracao.bus = bus
	_som_coracao.volume_db = -80.0
	add_child(_som_coracao)
	_som_folego = AudioStreamPlayer.new()
	_som_folego.bus = bus
	_som_folego.volume_db = -80.0
	add_child(_som_folego)
	pulou.connect(func(): Sons.tocar("jogador/pulo", -12.0))
	sobrevivencia.ferido.connect(_doeu)
	sobrevivencia.morreu.connect(func(_c):
		var m := SonsBaixados.sortear("jogador/morte")
		if m != null and _som_voz != null:
			_som_voz.stream = m
			_som_voz.pitch_scale = 1.0
			_som_voz.volume_db = 0.0
			_som_voz.play())

func ligar_controles(c) -> void:
	controles = c
	c.agachar_pedido.connect(alternar_agachar)
	c.mirar_pedido.connect(func(): _mirar_ligado = not _mirar_ligado)
	c.camera_pedida.connect(alternar_camera)
	c.recarregar_pedido.connect(func():
		if not nadando:
			armas.recarregar())
	c.trocar_arma_pedido.connect(func(): armas.proxima_arma())
	c.atalho_pedido.connect(_usar_atalho)
	c.pegar_pedido.connect(_pegar_do_chao)

func _usar_atalho(i: int) -> void:
	if ativo and not morto and not nadando:
		inventario.usar_atalho(i)

func _pegar_do_chao() -> void:
	if ativo and not morto:
		inventario.pegar(inventario.item_mais_proximo())

# usa res://modelos/personagem.(tscn|scn|glb|gltf|fbx) se existir; senão fica o soldado original
func _carregar_modelo_do_projeto() -> void:
	for ext in EXTENSOES_MODELO:
		var caminho: String = "res://modelos/personagem." + str(ext)
		if ResourceLoader.exists(caminho):
			var res = load(caminho)
			if res is PackedScene:
				var no := (res as PackedScene).instantiate()
				if no is Node3D:
					trocar_modelo(no as Node3D, true)
					animador.importar_animacoes("res://modelos/animacoes")
					return

# põe um modelo novo no encaixe (apaga o anterior), liga o animador e passa as armas para a mão dele
func trocar_modelo(no: Node3D, importado := true) -> void:
	for f in _slot.get_children():
		_slot.remove_child(f)
		f.queue_free()
	if importado:
		no.rotation_degrees.y = giro_modelo_importado
		no.scale = Vector3.ONE * escala_modelo
	_slot.add_child(no)
	animador.configurar(no)
	armas.anexar(no, animador.ponto_arma())

# MODO LIVRE: troca o soldado pelo sobrevivente (jogador/modelo_sobrevivente.gd), que mostra no corpo a roupa
# equipada no inventário
func usar_sobrevivente() -> void:
	var m = load("res://jogador/modelo_sobrevivente.gd").new()
	m.name = "Sobrevivente"
	trocar_modelo(m, true)
	animador.nomes_exatos = m.NOMES_ANIM
	animador.atualizar_mapa()
	m.vestir(inventario)
	if not inventario.mudou.is_connected(_vestir):
		inventario.mudou.connect(_vestir)

func _vestir() -> void:
	var m = _slot.get_node_or_null("Sobrevivente")
	if m != null:
		m.vestir(inventario)

# mordida/golpe de um infectado (inimigos/vago.gd chama aqui)
var servidor := false               # é o "jogador" invisível do servidor do PC (rede/servidor.gd): não leva dano

func receber_ataque(dano: float, chance_sangrar: float, origem: Vector3) -> void:
	if servidor:
		return
	if sobrevivencia != null:
		sobrevivencia.receber_ataque(dano, chance_sangrar, origem)

# PASSOS: um a cada passada (mais longa correndo), mais baixo agachado, "chapinhando" com o chão molhado
func _passos(delta: float) -> void:
	_t_dor = maxf(0.0, _t_dor - delta)
	if morto or not is_on_floor() or vel_horizontal < 0.5 or _som_passo == null:
		_dist_passo = minf(_dist_passo, 0.5)
		return
	_dist_passo += vel_horizontal * delta
	var passada := 0.6 + 0.22 * vel_horizontal
	if _dist_passo < passada:
		return
	_dist_passo = 0.0
	_n_passo += 1
	if _clima == null or not is_instance_valid(_clima):
		_clima = get_tree().current_scene.get("clima") if get_tree().current_scene != null else null
	var cl = _clima
	var molhado: bool = (cl != null and is_instance_valid(cl) and float(cl.molhado) > 0.4) or prof_agua > 0.08
	# 0.49: o som muda com o chão (colisao_mundo.tipo_piso): asfalto/calçada, grama/terra, dentro de prédio
	var piso := "concreto"
	if mundo != null and mundo.has_method("tipo_piso"):
		piso = mundo.tipo_piso(global_position.x, global_position.z)
	var gravado: AudioStream = null
	if piso == "madeira" and _piso_ant != "madeira" and _piso_ant != "":
		Sons.tocar("mundo/rangido", -14.0)                 # entrou no prédio: o assoalho range
	_piso_ant = piso
	if piso == "madeira":
		gravado = Sons.sortear("jogador/passo_madeira")
		molhado = false                                   # dentro do prédio não chapinha
	elif piso == "grama" and not molhado:
		gravado = Sons.sortear("jogador/passo_grama")
	if gravado == null:
		gravado = SonsBaixados.sortear("jogador/passo")
	_som_passo.stream = gravado if gravado != null and not molhado else SonsCorpo.passo(_n_passo, molhado)
	_som_passo.pitch_scale = randf_range(0.9, 1.1)
	_som_passo.volume_db = (-14.0 if agachado else (-3.0 if vel_horizontal > 5.0 else -8.0)) + (4.0 if prof_agua > 0.3 else 0.0)
	_som_passo.play()

# ---------- ÁGUA (0.72) ----------
# 10 vezes por segundo: tem água aqui? quão funda? entra/sai do nado
func _agua(delta: float) -> void:
	_t_agua -= delta
	if _t_agua <= 0.0:
		_t_agua = 0.1
		nivel_agua = mundo.nivel_agua(global_position.x, global_position.z) if mundo != null and mundo.has_method("nivel_agua") else -INF
		_fundo = 0.0
		if nivel_agua > -INF:
			var q := PhysicsRayQueryParameters3D.create(Vector3(global_position.x, nivel_agua + 0.3, global_position.z),
				Vector3(global_position.x, nivel_agua - 8.0, global_position.z), 1, [get_rid()])
			var r := get_world_3d().direct_space_state.intersect_ray(q)
			_fundo = nivel_agua - ((r["position"] as Vector3).y if not r.is_empty() else nivel_agua - 8.0)
	var era := nadando
	if nivel_agua <= -INF or morto:
		nadando = false
	elif not nadando and _fundo > FUNDO_NADAR and global_position.y < nivel_agua - NADO_ALTURA + 0.25:
		nadando = true
	elif nadando and _fundo < FUNDO_ANDAR:
		nadando = false
	prof_agua = maxf(0.0, nivel_agua - global_position.y) if nivel_agua > -INF else 0.0
	# afunda sem estamina; volta a boiar quando ela sobe um pouco
	if nadando and sobrevivencia != null:
		if not afundando and sobrevivencia.estamina <= 0.5:
			afundando = true
			sobrevivencia.aviso.emit("VOCÊ ESTÁ AFUNDANDO! SOLTE PESO OU NADE PARA A MARGEM")
		elif afundando and sobrevivencia.estamina > 12.0:
			afundando = false
	else:
		afundando = false
	if nadando != era:
		armas.esconder_arma(nadando)
		Sons.tocar("impactos/bala_agua", -4.0 if nadando else -12.0, 0.55)
		if nadando and velocity.y < -4.0:
			Sons.tocar("impactos/bala_agua", 0.0, 0.4)           # caiu de cima: tchibum

# som das braçadas (mais rápido nadando rápido)
var _t_bracada := 0.0
func _bracadas(delta: float) -> void:
	_t_bracada -= delta * clampf(0.4 + vel_horizontal / 1.5, 0.4, 1.8)
	if _t_bracada <= 0.0:
		_t_bracada = 1.8
		if _som_passo != null:
			_som_passo.stream = SonsCorpo.passo(_n_passo, true)
			_n_passo += 1
			_som_passo.pitch_scale = randf_range(0.6, 0.75)
			_som_passo.volume_db = -10.0
			_som_passo.play()

# câmera embaixo d'água (afundando, ou olhando de baixo): tela azul-esverdeada
func _tela_submersa() -> void:
	var sub: bool = nivel_agua > -INF and camera.global_position.y < nivel_agua - 0.05 and not morto
	if sub and _tela_agua == null:
		var cl := CanvasLayer.new()
		cl.layer = 3
		add_child(cl)
		_tela_agua = ColorRect.new()
		_tela_agua.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tela_agua.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tela_agua.color = Color(0.04, 0.18, 0.2, 0.82)
		cl.add_child(_tela_agua)
	if _tela_agua != null:
		_tela_agua.visible = sub

var _clima = null                   # mundo/clima.gd (guardado: antes procurava a cada passo)

# ---------- coração e fôlego (0.49) ----------
var _som_coracao: AudioStreamPlayer
var _som_folego: AudioStreamPlayer
var _piso_ant := ""                  # chão do último passo (som ao entrar em prédio)
var fadiga := 0.0                   # 0..1: sobe correndo, desce parado/andando

func _sons_corpo(delta: float) -> void:
	if _som_coracao == null:
		return
	var correndo := vel_horizontal > 5.0 and is_on_floor() and not morto
	fadiga = clampf(fadiga + (delta / 25.0 if correndo else -delta / 12.0), 0.0, 1.0)
	var perigo := 0.0
	if sobrevivencia != null and not morto:
		perigo = maxf(1.0 - clampf((float(sobrevivencia.vida) - 10.0) / 30.0, 0.0, 1.0),
			1.0 - clampf((float(sobrevivencia.sangue) - 2500.0) / 1500.0, 0.0, 1.0))
	_laco(_som_coracao, perigo, "jogador/coracao_rapido" if perigo > 0.6 else "jogador/coracao_lento", -26.0, -6.0, delta)
	_laco(_som_folego, smoothstep(0.45, 0.9, fadiga) * (0.0 if morto else 1.0), "jogador/respiracao", -30.0, -12.0, delta)

# liga/desliga um laço suave: f = 0..1 (0 = mudo)
func _laco(p: AudioStreamPlayer, f: float, nome: String, vmin: float, vmax: float, delta: float) -> void:
	if f <= 0.01:
		if p.playing:
			p.volume_db -= delta * 30.0
			if p.volume_db < -60.0:
				p.stop()
		return
	var alvo := lerpf(vmin, vmax, f)
	if not p.playing or (p.stream != null and p.get_meta("som", "") != nome):
		p.stream = Sons.stream(nome, true)
		p.set_meta("som", nome)
		if not p.playing:
			p.volume_db = -50.0
		p.play()
	p.volume_db = move_toward(p.volume_db, alvo, delta * 20.0)

func _doeu(dano: float) -> void:
	if dano < 2.0 or _t_dor > 0.0 or _som_voz == null:
		return
	_t_dor = 0.7
	var gravada := SonsBaixados.sortear("jogador/dor")
	_som_voz.stream = gravada if gravada != null else SonsCorpo.dor(randi())
	_som_voz.pitch_scale = randf_range(0.93, 1.07)
	_som_voz.volume_db = -4.0
	_som_voz.play()

func teleportar(pos: Vector3, yaw_camera: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	cam_yaw = yaw_camera
	rotation.y = yaw_camera
	_y_cam = pos.y

func alternar_agachar() -> void:
	if morto:
		return
	if agachado:
		_levantar()
	else:
		agachado = true
		_aplicar_capsula()

func _levantar() -> bool:
	if not agachado:
		return true
	if not _cabe_em_pe():
		return false          # tem teto em cima: continua agachado
	agachado = false
	_aplicar_capsula()
	return true

func _aplicar_capsula() -> void:
	var h := ALTURA_AGACHADO if agachado else ALTURA_EM_PE
	_capsula.height = h
	_colisao.position.y = h * 0.5

func _cabe_em_pe() -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = _capsula.radius - 0.02
	cap.height = ALTURA_EM_PE
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, ALTURA_EM_PE * 0.5 + 0.03, 0.0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _physics_process(delta: float) -> void:
	if not ativo:
		return
	var ix := 0.0
	var iy := 0.0
	var sprint := false
	var quer_pular := false
	if controles != null:
		var m: Vector2 = controles.vetor_mover()
		ix = m.x
		iy = m.y
		sprint = controles.correndo()
		quer_pular = controles.pulando()
		armas.gatilho = controles.atirando()
		# agachar no modo "segurar" (Opções › Teclado e mouse): segue a tecla
		# (embaixo de teto baixo não dá para levantar: tenta de novo a cada 0,25 s, não todo quadro)
		var seg: int = controles.agachar_segurado()
		_t_agachar -= delta
		if seg >= 0 and (seg == 1) != agachado and not morto and (seg != _agachar_ant or _t_agachar <= 0.0):
			_t_agachar = 0.25
			alternar_agachar()
		_agachar_ant = seg
	if morto or (sobrevivencia != null and (sobrevivencia.desmaiado > 0.0 or sobrevivencia.parado > 0.0)):
		ix = 0.0
		iy = 0.0
		quer_pular = false
		sprint = false
		armas.gatilho = false
	_agua(delta)
	if nadando:
		quer_pular = false
		_mirar_ligado = false
		armas.gatilho = false
		if agachado:
			agachado = false
			_aplicar_capsula()
	if sobrevivencia != null and not sobrevivencia.pode_correr():
		sprint = false                   # sem estamina ou perna quebrada
	var perna: bool = sobrevivencia != null and sobrevivencia.perna_quebrada
	mancando = perna
	if perna:
		quer_pular = false
	var mag := minf(1.0, Vector2(ix, iy).length())
	# correr cancela agachar e mirar
	if sprint and mag >= 0.05:
		if agachado and not _levantar():
			sprint = false
		_mirar_ligado = false
	mirando = (_mirar_ligado or (controles != null and controles.mirando_segurado())) and not morto and not nadando
	if mirando:
		sprint = false
	var dir := Vector3.ZERO
	if mag > 0.001:
		dir = (Basis(Vector3.UP, cam_yaw) * Vector3(ix, 0.0, -iy)).normalized()
	var vmax := 0.0
	if mag >= 0.05:
		if agachado:
			vmax = VEL_AGACHADO_RAPIDO if mag > 0.55 else VEL_AGACHADO
		elif sprint:
			vmax = VEL_CORRIDA
		else:
			vmax = VEL_TROTE if mag > 0.72 else (VEL_ANDAR if mag > 0.35 else VEL_DEVAGAR)
			if controles != null and controles.andando_pc() and mag > 0.35:
				vmax = VEL_ANDAR
		if mirando:
			# mirando: de lado (passo lateral) e de costas é mais devagar; de frente até VEL_MIRANDO
			var de_lado := absf(ix) / maxf(mag, 0.001)
			var de_costas := maxf(-iy, 0.0) / maxf(mag, 0.001)
			vmax = minf(vmax, lerpf(VEL_MIRANDO, VEL_MIRANDO_LADO, smoothstep(0.4, 0.9, maxf(de_lado, de_costas))))
		if perna:
			vmax = minf(vmax, 0.9)          # mancando
		if nadando:
			vmax = (VEL_NADO_RAPIDO if sprint else VEL_NADO) * (0.45 if afundando else 1.0)
		elif prof_agua > 0.35:
			vmax = minf(vmax, lerpf(3.2, 1.1, clampf((prof_agua - 0.35) / 0.8, 0.0, 1.0)))   # andando na água
	var no_chao := is_on_floor()
	var k := minf(1.0, delta * (9.0 if no_chao else (2.0 if nadando else 2.5)))
	velocity.x += (dir.x * vmax - velocity.x) * k
	velocity.z += (dir.z * vmax - velocity.z) * k
	if nadando:
		# boia: o corpo vai para a linha d'água (afundando, mais para baixo); sem gravidade nem pulo
		var alvo_y := nivel_agua - NADO_ALTURA - (AFUNDAR if afundando else 0.0)
		velocity.y = clampf((alvo_y - global_position.y) * 3.0, -2.5, 1.5)
	elif no_chao:
		if quer_pular and not _pulo_ant:
			if agachado:
				_levantar()             # pular agachado = levantar
				velocity.y = 0.0
			else:
				velocity.y = FORCA_PULO
				pulou.emit()
		else:
			velocity.y = 0.0
	else:
		velocity.y -= GRAVIDADE * delta
	_pulo_ant = quer_pular
	var vy_antes := velocity.y
	var no_ar := not no_chao
	move_and_slide()
	if no_ar and is_on_floor() and sobrevivencia != null:
		sobrevivencia.queda(vy_antes)    # dano de queda / perna quebrada
		if vy_antes < -3.0:
			Sons.tocar("jogador/aterrissar", clampf(-22.0 - vy_antes * 1.6, -18.0, -2.0))
	vel_horizontal = Vector2(velocity.x, velocity.z).length()
	if nadando:
		_bracadas(delta)
	_passos(delta)
	_sons_corpo(delta)
	atirando = armas.since < 1.6 or armas.aim > 0.5
	if not morto:
		if mirando or atirando:
			rotation.y = lerp_angle(rotation.y, cam_yaw + armas.ky, minf(1.0, delta * 14.0))   # corpo vira para a mira
		elif vel_horizontal > 0.4 and not primeira_pessoa:    # 1ª pessoa: _camera_primeira_pessoa vira o corpo
			rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), minf(1.0, delta * 10.0))

# ---------- 1ª PESSOA (0.65) ----------
# A câmera vai para os OLHOS do personagem (jogador/modelo_sobrevivente.gd pos_olhos) e a cabeça some
# (jogador/cabeca_oculta.gd): você vê os próprios braços, mãos, arma e pernas, como no DayZ. O corpo sempre vira
# para onde você olha. Dá para olhar mais para cima e para baixo. Mirando, o campo de visão fecha (zoom).
func _pit_min() -> float:
	return -1.25 if primeira_pessoa else -0.35

func _pit_max() -> float:
	return 1.3 if primeira_pessoa else 1.15

func alternar_camera() -> void:
	Config.definir("cam", 0 if primeira_pessoa else 1)     # menu/aplicar_opcoes.gd liga primeira_pessoa

func _camera_primeira_pessoa(delta: float, fov_alvo: float) -> void:
	_fp = move_toward(_fp, 1.0 if primeira_pessoa else 0.0, delta * 5.0)
	var m = _slot.get_child(0) if _slot.get_child_count() > 0 else null
	if m != null and m.has_method("primeira_pessoa"):
		m.primeira_pessoa(_fp > 0.5)
	if not primeira_pessoa:
		cam_pit = clampf(cam_pit, -0.35, 1.15)
	if _fp <= 0.0:
		camera.near = _near_3p
		return
	var olhos: Vector3 = m.pos_olhos() if m != null and m.has_method("pos_olhos") else global_position + Vector3(0, 1.65, 0)
	var k := smoothstep(0.0, 1.0, _fp)
	_pivo.global_position = _pivo.global_position.lerp(olhos, k)
	_braco.spring_length = lerpf(_braco.spring_length, 0.0, k)
	camera.position.x = lerpf(camera.position.x, 0.0, k)
	camera.near = lerpf(_near_3p, 0.03, k)
	var fov_fp := lerpf(fov_camera + 18.0, (fov_camera + 18.0) * 0.55 / armas.zoom_mira(), fator_mira)
	camera.fov = lerpf(camera.fov, lerpf(fov_alvo, fov_fp, k), minf(1.0, delta * 6.0 + 0.02))
	if not morto:
		rotation.y = lerp_angle(rotation.y, cam_yaw, minf(1.0, delta * 16.0))   # o corpo vira para onde você olha

func _process(delta: float) -> void:
	if not ativo:
		return
	if controles != null:
		var r: Vector2 = controles.consumir_olhar()
		var s := sensibilidade * (0.6 if mirando else 1.0)     # mirando: olhar mais preciso
		cam_yaw -= r.x * 0.006 * s
		cam_pit = clampf(cam_pit + r.y * 0.004 * s * (-1.0 if inverter_y else 1.0), _pit_min(), _pit_max())
		# 0.62: mouse preso (modo PC) com sensibilidade, sensibilidade mirando e eixo próprios (Opções › Teclado e mouse)
		var rm: Vector2 = controles.consumir_olhar_mouse()
		if rm != Vector2.ZERO:
			var sm := sens_mouse * (sens_mouse_mira if mirando else 1.0)
			cam_yaw -= rm.x * 0.0022 * sm
			cam_pit = clampf(cam_pit + rm.y * 0.0018 * sm * (-1.0 if inverter_y_mouse else 1.0), _pit_min(), _pit_max())
		if giroscopio:
			# celular deitado (paisagem): girar em pé = olhar para os lados, inclinar = olhar para cima/baixo
			var gv := Input.get_gyroscope() - giro_zero
			var gs := giro_sens * (-1.0 if giro_inv else 1.0)
			cam_yaw += gv.x * delta * gs
			cam_pit = clampf(cam_pit - gv.y * delta * gs * (-1.0 if inverter_y else 1.0), _pit_min(), _pit_max())
		controles.indicadores["AGACHAR"] = agachado
		controles.indicadores["MIRAR"] = mirando
		controles.textos["ARMA"] = armas.WDEF[armas.atual]["nome"] if armas.atual != "" else "ARMA"
		controles.icones["ARMA"] = armas.atual                    # 0.67: ícone da arma no botão (faca, pistola...)
	fator_agachado = lerpf(fator_agachado, 1.0 if agachado else 0.0, minf(1.0, delta * 10.0))
	fator_mira = lerpf(fator_mira, 1.0 if mirando else 0.0, minf(1.0, delta * 12.0))
	# câmera: pivô na altura do ombro, gira com a mira (+ recuo da arma); o braço (SpringArm3D) bate nos prédios
	_y_cam = lerpf(_y_cam, global_position.y, 1.0 - exp(-12.0 * delta))
	var alvo_y := lerpf(altura_alvo, altura_alvo_agachado, fator_agachado) + 0.1 * fator_mira
	_pivo.global_position = Vector3(global_position.x, _y_cam + alvo_y, global_position.z)
	_pivo.rotation = Vector3(-(cam_pit - armas.kick), cam_yaw + armas.ky, 0.0)
	mira_pitch = clampf(MIRA_NEUTRA * (1.0 - _fp) - cam_pit, -0.8, 0.6)
	var fov_base := lerpf(fov_camera, fov_mirando / armas.zoom_mira(), fator_mira)
	var fov_alvo := fov_base + 5.0 * clampf((vel_horizontal - 3.0) / 4.0, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, fov_alvo, minf(1.0, delta * 4.0 + 0.02))
	var dist := lerpf(distancia_camera, distancia_mirando, fator_mira)
	_braco.spring_length = dist
	var asp := get_viewport().get_visible_rect().size.aspect()
	var meia_largura := tan(deg_to_rad(camera.fov) * 0.5) * asp
	var frac := _braco.get_hit_length() / maxf(dist, 0.01)
	camera.position.x = lerpf(dist * meia_largura * lateral_camera, ombro_mirando, fator_mira) * frac
	_camera_primeira_pessoa(delta, fov_alvo)
	_tela_submersa()
	animador.atualizar(delta, self)
