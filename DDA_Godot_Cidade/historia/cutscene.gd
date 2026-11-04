extends CanvasLayer
# 1.13 · MOTOR DE CUTSCENES DO MODO HISTÓRIA (cenas no próprio jogo, em tempo real, como em Uncharted 4).
# Uma cena é uma lista de PLANOS (Dictionary); tocar(planos) toca um por um e devolve quando acaba (ou foi pulada):
#   "dur": segundos (se tiver fala e não tiver dur, dura a fala + 0,6 s)
#   "de"/"para": posição da câmera no começo/fim do plano (Vector3) · "olha"/"olha_para": para onde ela olha
#      (Vector3 ou Node3D, que é seguido) · "fov"/"fov_para": lente (graus) · "curva": "suave" (padrão) ou "linear"
#   "tremor": 0..1 (câmera na mão) · "lento": velocidade do tempo (câmera lenta, ex.: 0.25)
#   "fala": ["Dominic", "texto"] (legenda + som de fala de historia/vozes.gd) · "titulo": [texto grande, texto menor]
#   "frase": texto do prólogo (grande, no meio, em silêncio) · "acao": Callable chamado no começo do plano
#   "escuro": true = começa no preto e clareia · "escurece": true = termina no preto · "barras": false = sem faixas
#   "corte": true = corte seco (sem fusão) para um impacto de propósito
#   "celular": [quem mandou, texto] = aviso de mensagem no celular (canto de cima, à direita) · 1.14
# 1.13.1 · TRANSIÇÕES SUAVES (antes os planos trocavam de uma vez): a câmera do jogo DESLIZA até o 1º plano; entre um
#   plano e outro, FUSÃO (o último quadro do plano anterior some devagar por cima do novo); no fim, o deslize de volta
#   para o jogo é mais longo e suave.
# Tudo pode ser PULADO: segurar a tela/qualquer tecla por 0,8 s (a barrinha enche). Pulando, as "acao" que faltavam
# rodam na ordem (o mundo fica como se a cena tivesse passado) e a câmera volta para o jogador.
# No fim, a câmera da cena DESLIZA até a câmera do jogo (sem corte, sem tela preta), como em Uncharted 4.
# Mexa AQUI para: o tamanho das faixas pretas, o visual da legenda, o tempo para pular e o deslize de volta.

const UI := preload("res://menu/ui.gd")
const VozesCls := preload("res://historia/vozes.gd")

const BARRA := 0.12              # altura de cada faixa preta (fração da tela): ~2,39:1 numa tela 16:9
const SEGURAR_PULAR := 0.8
const DESLIZE_VOLTA := 1.1
const DESLIZE_ENTRADA := 1.0     # 1.13.1: do jogo até o 1º plano
const FUSAO := 0.6               # 1.13.1: fusão entre os planos (s)

signal acabou

var camera: Camera3D
var vozes: Node
var tocando := false
var pulando := false
var cor_nomes := {"DOMINIC": Color(0.93, 0.95, 1.0), "GREG": Color(1.0, 0.78, 0.45), "MAVIE": Color(0.98, 0.62, 0.74)}

var _barra_cima: ColorRect
var _barra_baixo: ColorRect
var _veu: ColorRect
var _fusao: TextureRect           # 1.13.1: o último quadro do plano anterior, sumindo devagar
var _legenda: RichTextLabel
var _titulo: Label
var _sub: Label
var _frase: Label
var _cel: PanelContainer           # 1.14: aviso de mensagem no celular
var _cel_quem: Label
var _cel_txt: Label
var _pular: Control
var _seg := 0.0
var _pedido_pular := false
var _barras := 0.0
var _cam_jogo: Camera3D
var pular_teste := false         # testes: como se alguém segurasse a tela
var n_cenas := 0                 # quantas cenas já começaram (testes)

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.name = "CameraCena"
	camera.near = 0.05
	camera.far = 4000.0
	add_child(camera)
	vozes = VozesCls.new()
	vozes.name = "Vozes"
	add_child(vozes)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	_fusao = TextureRect.new()
	_fusao.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fusao.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fusao.stretch_mode = TextureRect.STRETCH_SCALE
	_fusao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fusao.modulate.a = 0.0
	raiz.add_child(_fusao)
	_veu = _rect(raiz, Color(0, 0, 0, 0))
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barra_cima = _rect(raiz, Color.BLACK)
	_barra_baixo = _rect(raiz, Color.BLACK)
	var v := UI.vh(self)
	_legenda = RichTextLabel.new()
	_legenda.bbcode_enabled = true
	_legenda.fit_content = true
	_legenda.scroll_active = false
	_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legenda.add_theme_font_override("normal_font", UI.fonte(700, 0.0, false))
	_legenda.add_theme_font_override("bold_font", UI.fonte(900, 0.0, false))
	_legenda.add_theme_font_size_override("normal_font_size", int(3.0 * v))
	_legenda.add_theme_font_size_override("bold_font_size", int(3.0 * v))
	_legenda.add_theme_constant_override("outline_size", int(0.5 * v))
	_legenda.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	raiz.add_child(_legenda)
	_titulo = UI.rotulo("", 9.0 * v, UI.AMBAR, 900, 0.18 * 9.0 * v, true)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_constant_override("outline_size", int(0.8 * v))
	_titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	raiz.add_child(_titulo)
	_sub = UI.rotulo("", 2.8 * v, Color(1, 0.92, 0.82), 700, 0.35 * 2.8 * v, false)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(_sub)
	_frase = UI.rotulo("", 4.2 * v, Color(1, 0.95, 0.9), 400, 0.0, true)
	_frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.add_child(_frase)
	_cel = PanelContainer.new()
	var sbc := StyleBoxFlat.new()
	sbc.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	sbc.set_corner_radius_all(int(1.4 * v))
	sbc.content_margin_left = 1.6 * v
	sbc.content_margin_right = 1.6 * v
	sbc.content_margin_top = 1.0 * v
	sbc.content_margin_bottom = 1.0 * v
	_cel.add_theme_stylebox_override("panel", sbc)
	_cel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cel.add_child(vb)
	_cel_quem = UI.rotulo("", 1.9 * v, Color(0.6, 0.8, 1.0), 800, 0.0, false)
	_cel_txt = UI.rotulo("", 2.2 * v, Color(1, 1, 1), 500, 0.0, false)
	_cel_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cel_txt.custom_minimum_size.x = 38.0 * v
	vb.add_child(_cel_quem)
	vb.add_child(_cel_txt)
	_cel.modulate.a = 0.0
	raiz.add_child(_cel)
	_pular = Control.new()
	_pular.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pular.draw.connect(_desenhar_pular)
	raiz.add_child(_pular)
	for n in [_legenda, _titulo, _sub, _frase]:
		n.modulate.a = 0.0
	_posicionar()
	get_viewport().size_changed.connect(_posicionar)

func _rect(pai: Control, cor: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = cor
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(r)
	return r

func _posicionar() -> void:
	var vs := get_viewport().get_visible_rect().size
	var v := vs.y / 100.0
	var h := vs.y * BARRA * _barras
	_barra_cima.position = Vector2.ZERO
	_barra_cima.size = Vector2(vs.x, h)
	_barra_baixo.position = Vector2(0, vs.y - h)
	_barra_baixo.size = Vector2(vs.x, h)
	_legenda.position = Vector2(vs.x * 0.12, vs.y * (1.0 - BARRA) - 9.0 * v)
	_legenda.size = Vector2(vs.x * 0.76, 8.0 * v)
	_titulo.position = Vector2(0, vs.y * 0.36)
	_titulo.size = Vector2(vs.x, 12.0 * v)
	_sub.position = Vector2(0, vs.y * 0.36 + 12.5 * v)
	_sub.size = Vector2(vs.x, 4.0 * v)
	_frase.position = Vector2(vs.x * 0.15, vs.y * 0.42)
	_frase.size = Vector2(vs.x * 0.7, 16.0 * v)
	_cel.position = Vector2(vs.x - 46.0 * v, vs.y * BARRA + 2.0 * v)
	_pular.position = Vector2(vs.x - 26.0 * v, vs.y - 6.5 * v)
	_pular.size = Vector2(24.0 * v, 5.0 * v)

# ---------- tocar ----------
# manter_escuro: a cena termina no preto e FICA no preto (a próxima cena/cartela continua dali, sem piscar o jogo)
func tocar(planos: Array, manter_escuro := false) -> void:
	n_cenas += 1
	tocando = true
	pulando = false
	_pedido_pular = false
	_seg = 0.0
	var vp := get_viewport()
	_cam_jogo = vp.get_camera_3d()
	if _cam_jogo != null and _cam_jogo != camera:
		camera.global_transform = _cam_jogo.global_transform
		camera.fov = _cam_jogo.fov
	camera.make_current()
	var com_barras: bool = planos.is_empty() or planos[0].get("barras", true)
	_animar_barras(1.0 if com_barras else 0.0, 0.6)
	# 1.13.1: entra deslizando da câmera do jogo até o 1º plano (a não ser que ele comece no preto)
	if not planos.is_empty() and _cam_jogo != null and not bool(planos[0].get("escuro", false)) and planos[0].has("de"):
		await _deslizar_ate(planos[0])
	var i := 0
	while i < planos.size():
		var p: Dictionary = planos[i]
		if _pedido_pular:
			break
		if i > 0 and not bool(p.get("corte", false)) and not bool(p.get("escuro", false)) and _veu.color.a < 0.5:
			_fundir()
		await _plano(p)
		i += 1
	if _pedido_pular:
		pulando = true
		vozes.parar()
		Engine.time_scale = 1.0
		for k in range(i, planos.size()):        # o mundo fica como se a cena tivesse passado
			var a = planos[k].get("acao")
			if a is Callable and (a as Callable).is_valid():
				a.call()
			var a2 = planos[k].get("depois")
			if a2 is Callable and (a2 as Callable).is_valid():
				a2.call()
		_veu.color.a = 0.0
		_fusao.modulate.a = 0.0
	Engine.time_scale = 1.0
	_esconder_textos(0.25)
	if _veu.color.a > 0.5:
		# terminou no preto: troca a câmera escondido e só depois clareia (sem deslize nenhum)
		_animar_barras(0.0, 0.5)
		_trocar_para_jogo()
		if not manter_escuro:
			await clarear(0.9)
	else:
		await _voltar_ao_jogo()
	tocando = false
	acabou.emit()

# o mesmo véu preto para tudo (cenas, cartelas, teleportes): nunca dois véus brigando
func escurecer(t := 0.6) -> void:
	if _veu.color.a >= 0.999:
		return
	var tw := create_tween()
	tw.tween_property(_veu, "color:a", 1.0, t).set_trans(Tween.TRANS_SINE)
	await tw.finished

func clarear(t := 0.9) -> void:
	if _veu.color.a <= 0.001:
		return
	var tw := create_tween()
	tw.tween_property(_veu, "color:a", 0.0, t).set_trans(Tween.TRANS_SINE)
	await tw.finished

func escuro() -> bool:
	return _veu.color.a > 0.5

func _trocar_para_jogo() -> void:
	if _cam_jogo != null and is_instance_valid(_cam_jogo) and _cam_jogo != camera:
		_cam_jogo.make_current()
	elif get_viewport().get_camera_3d() == camera:
		camera.clear_current(false)

# 1.13.1: fusão: guarda o quadro atual e deixa ele sumir devagar por cima do plano novo
func _fundir() -> void:
	var vp := get_viewport()
	var img := vp.get_texture().get_image() if vp != null else null
	if img == null:
		return
	_fusao.texture = ImageTexture.create_from_image(img)
	_fusao.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fusao, "modulate:a", 0.0, FUSAO).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# 1.13.1: a câmera sai de onde a do jogo está e desliza até o começo do 1º plano
func _deslizar_ate(p: Dictionary) -> void:
	var de := camera.global_transform
	var fov0 := camera.fov
	var pos: Vector3 = _ponto(p["de"])
	var alvo_t := Transform3D(Basis(), pos)
	if p.get("olha") != null:
		var olha := _ponto(p["olha"])
		if olha.distance_squared_to(pos) > 0.0001:
			alvo_t = alvo_t.looking_at(olha, Vector3.UP)
	var fov1: float = float(p.get("fov", fov0))
	var t := 0.0
	var t_ant := Time.get_ticks_usec()
	while t < DESLIZE_ENTRADA and not _pedido_pular:
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		t += minf(0.1, (agora - t_ant) / 1000000.0)
		t_ant = agora
		var x := clampf(t / DESLIZE_ENTRADA, 0.0, 1.0)
		var w := x * x * x * (x * (x * 6.0 - 15.0) + 10.0)       # mais suave que o smoothstep (começa e para devagar)
		camera.global_transform = Transform3D(de.basis.slerp(alvo_t.basis, w).orthonormalized(), de.origin.lerp(alvo_t.origin, w))
		camera.fov = lerpf(fov0, fov1, w)

# só as faixas e a câmera (sem planos): para conversas curtas dentro do jogo
func barras(ligar: bool) -> void:
	_animar_barras(1.0 if ligar else 0.0, 0.5)

func _animar_barras(alvo: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(x):
		_barras = x
		_posicionar(), _barras, alvo, t).set_trans(Tween.TRANS_SINE)

func _ponto(x) -> Vector3:
	if x is Node3D:
		return (x as Node3D).global_position
	if x is Callable:
		return x.call()
	return x

func _plano(p: Dictionary) -> void:
	var a = p.get("acao")
	if a is Callable and (a as Callable).is_valid():
		a.call()
	var fala = p.get("fala")
	var dur_fala := 0.0
	if fala is Array and fala.size() >= 2:
		dur_fala = vozes.falar(str(fala[1]), str(fala[0]))
		_mostrar_fala(str(fala[0]), str(fala[1]))
	var dur: float = float(p.get("dur", dur_fala + 0.6 if dur_fala > 0.0 else 2.0))
	if p.has("titulo"):
		var tt = p["titulo"]
		_titulo.text = str(tt[0]) if tt is Array else str(tt)
		_sub.text = str(tt[1]) if tt is Array and tt.size() > 1 else ""
		_fade(_titulo, 1.0, 0.8)
		_fade(_sub, 1.0, 1.2)
	if p.has("frase"):
		_frase.text = str(p["frase"])
		_fade(_frase, 1.0, 0.9)
	if p.has("celular"):
		_cel_quem.text = "MENSAGEM · " + str(p["celular"][0]).to_upper()
		_cel_txt.text = str(p["celular"][1])
		_cel.position.y = UI.vh(self) * 100.0 * BARRA + UI.vh(self) * 2.0
		_fade(_cel, 1.0, 0.35)
		UI.Sons.ui("aviso", -6.0)
	if bool(p.get("escuro", false)):
		_veu.color.a = 1.0
		create_tween().tween_property(_veu, "color:a", 0.0, minf(1.2, dur * 0.5))
	if bool(p.get("escurece", false)):
		var tw := create_tween()
		tw.tween_interval(maxf(0.0, dur - 0.9))
		tw.tween_property(_veu, "color:a", 1.0, 0.9)
	Engine.time_scale = float(p.get("lento", 1.0))
	var de = p.get("de", camera.global_position)
	var para = p.get("para", de)
	var olha = p.get("olha", null)
	var olha_para = p.get("olha_para", olha)
	var fov0: float = float(p.get("fov", camera.fov))
	var fov1: float = float(p.get("fov_para", fov0))
	var tremor: float = float(p.get("tremor", 0.0))
	var suave: bool = str(p.get("curva", "suave")) == "suave"
	var t := 0.0
	var t_ant := Time.get_ticks_usec()
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.6
	while t < dur:
		if _pedido_pular:
			return
		var x := clampf(t / maxf(dur, 0.001), 0.0, 1.0)
		var w := x * x * (3.0 - 2.0 * x) if suave else x
		var pos := _ponto(de).lerp(_ponto(para), w)
		camera.global_position = pos
		if olha != null:
			var alvo := _ponto(olha).lerp(_ponto(olha_para), w)
			if alvo.distance_squared_to(pos) > 0.0001:
				camera.look_at(alvo, Vector3.UP)
		if tremor > 0.0:
			var tt := Time.get_ticks_msec() / 1000.0
			camera.rotate_object_local(Vector3.RIGHT, ruido.get_noise_2d(tt * 40.0, 3.0) * 0.012 * tremor)
			camera.rotate_object_local(Vector3.UP, ruido.get_noise_2d(7.0, tt * 40.0) * 0.016 * tremor)
		camera.fov = lerpf(fov0, fov1, w)
		if fala is Array and _legenda.modulate.a > 0.0:
			_legenda.visible_ratio = clampf(vozes.progresso * 1.05, 0.0, 1.0)
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		t += minf(0.1, (agora - t_ant) / 1000000.0)     # tempo de verdade (a câmera lenta não estica o plano)
		t_ant = agora
	Engine.time_scale = 1.0
	var d2 = p.get("depois")
	if d2 is Callable and (d2 as Callable).is_valid():
		d2.call()
	if fala is Array:
		_fade(_legenda, 0.0, 0.2)
	if p.has("titulo"):
		_fade(_titulo, 0.0, 0.6)
		_fade(_sub, 0.0, 0.6)
	if p.has("frase"):
		_fade(_frase, 0.0, 0.6)
	if p.has("celular"):
		_fade(_cel, 0.0, 0.4)

func _mostrar_fala(quem: String, texto: String) -> void:
	var nome := quem.to_upper()
	var cor: Color = cor_nomes.get(nome, Color(1.0, 0.85, 0.55))
	_legenda.text = "[center]" + ("[b][color=#%s]%s[/color][/b]  " % [cor.to_html(false), nome] if nome != "" else "") + "— " + texto + "[/center]"
	_legenda.visible_ratio = 0.0
	_legenda.modulate.a = 1.0

func _fade(n: CanvasItem, alvo: float, t: float) -> void:
	create_tween().tween_property(n, "modulate:a", alvo, t)

func _esconder_textos(t: float) -> void:
	for n in [_legenda, _titulo, _sub, _frase, _cel]:
		_fade(n, 0.0, t)

# a câmera da cena desliza até a do jogo e devolve o controle
func _voltar_ao_jogo() -> void:
	_animar_barras(0.0, 0.5)
	var vp := get_viewport()
	if _cam_jogo == null or not is_instance_valid(_cam_jogo) or _cam_jogo == camera:
		return
	var de := camera.global_transform
	var fov0 := camera.fov
	var t := 0.0
	while t < DESLIZE_VOLTA:
		await get_tree().process_frame
		t += get_process_delta_time()
		if not is_instance_valid(_cam_jogo):
			return
		var x := clampf(t / DESLIZE_VOLTA, 0.0, 1.0)
		var w := x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
		var alvo := _cam_jogo.global_transform
		camera.global_transform = Transform3D(de.basis.slerp(alvo.basis, w).orthonormalized(), de.origin.lerp(alvo.origin, w))
		camera.fov = lerpf(fov0, _cam_jogo.fov, w)
	if is_instance_valid(_cam_jogo):
		_cam_jogo.make_current()
	if vp.get_camera_3d() == camera:
		camera.clear_current(false)

# ---------- pular (segurar) ----------
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_toques[e.index] = true
		else:
			_toques.erase(e.index)
	if not tocando:
		return
	if e is InputEventScreenTouch or e is InputEventScreenDrag or e is InputEventMouseButton or e is InputEventKey or e is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not tocando:
		if _seg > 0.0:
			_seg = 0.0
			_pular.queue_redraw()             # apaga a barrinha "SEGURE PARA PULAR"
		return
	var segurando := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _algum_toque() or Input.is_anything_pressed() or pular_teste
	var dr := dt / maxf(Engine.time_scale, 0.05)
	_seg = _seg + dr if segurando else maxf(0.0, _seg - dr * 2.0)
	if _seg >= SEGURAR_PULAR and not _pedido_pular:
		_pedido_pular = true
	_pular.queue_redraw()

var _toques := {}
func _algum_toque() -> bool:
	return not _toques.is_empty()

func _desenhar_pular() -> void:
	if not tocando or _seg <= 0.02:
		return
	var v := UI.vh(self)
	var r := _pular.size
	var f := clampf(_seg / SEGURAR_PULAR, 0.0, 1.0)
	_pular.draw_string(UI.fonte(800), Vector2(0, r.y * 0.45), "SEGURE PARA PULAR", HORIZONTAL_ALIGNMENT_LEFT, -1, int(2.0 * v), Color(1, 1, 1, 0.85))
	_pular.draw_rect(Rect2(0, r.y * 0.65, r.x, 0.5 * v), Color(1, 1, 1, 0.2))
	_pular.draw_rect(Rect2(0, r.y * 0.65, r.x * f, 0.5 * v), UI.AMBAR)
