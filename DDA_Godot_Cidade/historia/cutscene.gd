extends Node3D
# SISTEMA DE CUTSCENES (cenas de cinema da história), feito no próprio mundo do jogo:
#   - faixas pretas em cima e embaixo, legenda com o nome de quem fala, botão PULAR (e toque = próxima fala)
#   - câmera própria que desliza de um ponto a outro olhando para um alvo (camera(...)), ou corta (cortar(...))
#   - ATORES: pessoas (Dominic: modelo 3D em npc/ator_rigado.gd; Greg, Mavie...: npc/modelo_humano.gd), infectados (inimigos/modelo_vago.gd) e carros,
#     que andam/correm até um ponto (andar), fazem poses (pose) e golpes; carros com gente dentro
#   - CENÁRIOS montados na hora (o bar do Capítulo 2) e escurecer/clarear a tela
# Enquanto a cena roda: a HUD some, o jogador fica parado e escondido, os infectados de verdade ficam congelados.
# As cenas em si (o roteiro) ficam em historia/cenas.gd. Uso: await cs.tocar(func(): await Cenas.bar(cs))
# Mexa AQUI para: tamanho das faixas, legenda, velocidade da câmera, botão PULAR.

const HumanoCls := preload("res://npc/modelo_humano.gd")
const AtorRigadoCls := preload("res://npc/ator_rigado.gd")
const ModeloVagoCls := preload("res://inimigos/modelo_vago.gd")
const Abandono := preload("res://mundo/abandono.gd")
const Malhas := preload("res://mundo/malhas.gd")
const CORES := {"DOMINIC": Color(0.85, 0.9, 1.0), "GREG": Color(0.6, 0.9, 0.6), "MAVIE": Color(1.0, 0.7, 0.7),
	"TV": Color(1.0, 0.85, 0.4), "RÁDIO": Color(1.0, 0.85, 0.4), "GAROTO": Color(1, 1, 1)}

var main = null
var rodando := false
var pulando := false
var cam: Camera3D
var atores := {}                     # id -> {"no", "modelo", "tipo", "destino", "vel", "v"}
var _cam_de := Vector3.ZERO
var _cam_para := Vector3.ZERO
var _alvo_de := Vector3.ZERO
var _alvo_para := Vector3.ZERO
var _cam_t := 1.0
var _cam_dur := 1.0
var _avancar := false
var _ui: CanvasLayer
var _faixa_cima: ColorRect
var _faixa_baixo: ColorRect
var _legenda: RichTextLabel
var _preto: ColorRect
var _pular: Button
var _faixa := 0.0
var _cenario: Node3D = null
var _escondidos: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.1
	cam.far = 3000.0
	add_child(cam)
	_montar_ui()

# roda uma cena (função com awaits) cuidando de esconder/mostrar tudo
func tocar(cena: Callable) -> void:
	rodando = true
	pulando = false
	_comecar()
	await cena.call()
	await _terminar()
	rodando = false

func _comecar() -> void:
	_escondidos.clear()
	for nome in ["controles", "hud", "hud_status", "mapa"]:
		var n = main.get(nome)
		if n != null and is_instance_valid(n) and n.visible:
			n.visible = false
			_escondidos.append(n)
	var j = main.jogador
	j.ativo = false
	j.visible = false
	j.velocity = Vector3.ZERO
	if main.vagos != null:
		main.vagos.process_mode = Node.PROCESS_MODE_DISABLED
		_mostrar_filhos(main.vagos, false)
	if main.companheiros != null:
		main.companheiros.process_mode = Node.PROCESS_MODE_DISABLED
		_mostrar_filhos(main.companheiros, false)
	cam.make_current()
	_ui.visible = true
	_pular.visible = true
	_preto.color.a = 0.0

func _terminar() -> void:
	if not pulando:
		await escurecer(0.4)
	for id in atores.keys():
		remover(id)
	if _cenario != null:
		_cenario.queue_free()
		_cenario = null
	for n in _escondidos:
		if is_instance_valid(n):
			n.visible = true
	_escondidos.clear()
	var j = main.jogador
	j.ativo = true
	j.visible = true
	j.camera.make_current()
	if main.vagos != null:
		main.vagos.process_mode = Node.PROCESS_MODE_INHERIT
		_mostrar_filhos(main.vagos, true)
	if main.companheiros != null:
		main.companheiros.process_mode = Node.PROCESS_MODE_INHERIT
		_mostrar_filhos(main.companheiros, true)
		main.companheiros.reagrupar()
	_legenda.text = ""
	_pular.visible = false
	_faixa = 0.0
	_ajustar_faixas()
	await clarear(0.5)
	_ui.visible = false

# vagos.gd e companheiros.gd são Node: esconde os filhos 3D (infectados, Greg, Mavie)
static func _mostrar_filhos(n: Node, v: bool) -> void:
	for c in n.get_children():
		if c is Node3D:
			c.visible = v

# ---------- atores ----------
func pessoa(id: String, quem: String, arma: String, pos: Vector3, yaw: float) -> Node3D:
	# quem já tem modelo 3D de verdade (Dominic) usa npc/ator_rigado.gd; os outros, o boneco de caixas
	var m = AtorRigadoCls.new() if AtorRigadoCls.tem_modelo(quem) else HumanoCls.new()
	add_child(m)
	m.montar(quem, arma)
	m.global_position = pos
	m.rotation.y = yaw
	atores[id] = {"no": m, "modelo": m, "tipo": "pessoa", "destino": null, "vel": 0.0, "v": 0.0}
	return m

func infectado(id: String, pos: Vector3, yaw: float, semente := 7) -> Node3D:
	var m = ModeloVagoCls.new()
	add_child(m)
	m.montar(semente)
	m.global_position = pos
	m.rotation.y = yaw
	atores[id] = {"no": m, "modelo": m, "tipo": "vago", "destino": null, "vel": 0.0, "v": 0.0}
	return m

func carro(id: String, pos: Vector3, yaw: float, cor: Color) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var mi := MeshInstance3D.new()
	mi.mesh = Abandono.modelo("sedan")
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = cor
	mat.roughness = 0.35
	mat.metallic = 0.3
	mi.material_override = mat
	n.add_child(mi)
	n.global_position = pos
	n.rotation.y = yaw
	atores[id] = {"no": n, "modelo": null, "tipo": "carro", "destino": null, "vel": 0.0, "v": 0.0}
	return n

# põe uma pessoa sentada dentro do carro (lugar: "motorista", "passageiro", "atras")
func embarcar(id_pessoa: String, id_carro: String, lugar: String) -> void:
	var a: Dictionary = atores[id_pessoa]
	var c: Node3D = atores[id_carro]["no"]
	var m: Node3D = a["no"]
	m.get_parent().remove_child(m)
	c.add_child(m)
	var off := {"motorista": Vector3(0.2, 0.25, -0.42), "passageiro": Vector3(0.2, 0.25, 0.42), "atras": Vector3(-0.9, 0.25, 0.0)}
	m.position = off.get(lugar, Vector3.ZERO)
	m.rotation = Vector3(0, -PI * 0.5, 0)          # o carro anda para +X; a pessoa olha para -Z
	m.pose = "dirigindo" if lugar == "motorista" else "sentado"
	a["no"] = c
	a["tipo"] = "passageiro"

func remover(id: String) -> void:
	if not atores.has(id):
		return
	var n: Node3D = atores[id]["no"]
	var m = atores[id]["modelo"]
	if is_instance_valid(n) and atores[id]["tipo"] != "passageiro":
		n.queue_free()
	elif m != null and is_instance_valid(m):
		m.queue_free()
	atores.erase(id)

func no(id: String) -> Node3D:
	return atores[id]["no"]

func pos(id: String) -> Vector3:
	return (atores[id]["no"] as Node3D).global_position

func andar(id: String, destino: Vector3, vel: float) -> void:
	atores[id]["destino"] = destino
	atores[id]["vel"] = vel

func pose(id: String, nome: String) -> void:
	var m = atores[id]["modelo"]
	if m != null and "pose" in m:
		m.pose = nome

func olhar(id: String, alvo: Vector3) -> void:
	var n: Node3D = atores[id]["no"]
	var d := alvo - n.global_position
	n.rotation.y = atan2(-d.x, -d.z) if atores[id]["tipo"] != "carro" else atan2(-d.z, d.x)

func golpear(id: String) -> void:
	var m = atores[id]["modelo"]
	if m != null:
		if m.has_method("golpear"):
			m.golpear()
		elif m.has_method("atacar"):
			m.atacar()

# ---------- câmera ----------
func camera(de: Vector3, para: Vector3, alvo_de: Vector3, alvo_para: Vector3, dur: float, fov := 50.0) -> void:
	_cam_de = de
	_cam_para = para
	_alvo_de = alvo_de
	_alvo_para = alvo_para
	_cam_t = 0.0
	_cam_dur = maxf(dur, 0.01)
	cam.fov = fov
	_atualizar_camera(0.0)

func cortar(posicao: Vector3, alvo: Vector3, fov := 50.0) -> void:
	camera(posicao, posicao, alvo, alvo, 0.01, fov)

func _atualizar_camera(dt: float) -> void:
	_cam_t = minf(_cam_t + dt / _cam_dur, 1.0)
	var k := _cam_t * _cam_t * (3.0 - 2.0 * _cam_t)
	var p := _cam_de.lerp(_cam_para, k)
	var a := _alvo_de.lerp(_alvo_para, k)
	cam.global_position = p
	if p.distance_to(a) > 0.01:
		cam.look_at(a, Vector3.UP)

# ---------- tempo, falas, tela ----------
func esperar(t: float) -> void:
	var r := t
	while r > 0.0 and not pulando:
		await get_tree().process_frame
		r -= get_process_delta_time()

# legenda: espera o tempo de leitura (ou um toque)
func fala(quem: String, texto: String, dur := -1.0) -> void:
	if pulando:
		return
	var cor: Color = CORES.get(quem, Color(1, 1, 1, 0.9))
	if quem != "":
		_legenda.text = "[center][color=#%s]%s[/color]  %s[/center]" % [cor.to_html(false), quem, texto]
	else:
		_legenda.text = "[center][i]%s[/i][/center]" % texto
	var t := dur if dur > 0.0 else clampf(1.4 + texto.length() * 0.055, 2.2, 7.0)
	_avancar = false
	while t > 0.0 and not pulando and not _avancar:
		await get_tree().process_frame
		t -= get_process_delta_time()
	_avancar = false
	_legenda.text = ""

func escurecer(dur: float) -> void:
	await _fade(1.0, dur)

func clarear(dur: float) -> void:
	await _fade(0.0, dur)

func _fade(alvo: float, dur: float) -> void:
	var de := _preto.color.a
	var t := 0.0
	while t < dur and not (pulando and alvo == 1.0):
		await get_tree().process_frame
		t += get_process_delta_time()
		_preto.color.a = lerpf(de, alvo, clampf(t / dur, 0.0, 1.0))
	_preto.color.a = alvo

# ---------- cenário do bar (Capítulo 2): sala fechada com balcão, mesa, TV e luz amarela ----------
func cenario_bar(centro: Vector3) -> Dictionary:
	_cenario = Node3D.new()
	add_child(_cenario)
	_cenario.global_position = centro
	var c := Malhas.Construtor.new()
	var madeira := Color(0.32, 0.2, 0.12)
	var parede := Color(0.36, 0.3, 0.25)
	c.caixa(Vector3(0, -0.05, 0), Vector3(10, 0.1, 8), Color(0.22, 0.16, 0.12))               # chão
	c.caixa(Vector3(0, 3.05, 0), Vector3(10, 0.1, 8), Color(0.15, 0.13, 0.12))                # teto
	c.caixa(Vector3(0, 1.5, -4.05), Vector3(10, 3.1, 0.1), parede)
	c.caixa(Vector3(0, 1.5, 4.05), Vector3(10, 3.1, 0.1), parede)
	c.caixa(Vector3(-5.05, 1.5, 0), Vector3(0.1, 3.1, 8), parede)
	c.caixa(Vector3(5.05, 1.5, 0), Vector3(0.1, 3.1, 8), parede)
	c.caixa(Vector3(0, 0.55, -2.6), Vector3(6.0, 1.1, 0.7), madeira)                          # balcão
	c.caixa(Vector3(0, 1.12, -2.6), Vector3(6.2, 0.05, 0.85), Color(0.18, 0.1, 0.06))
	for i in 12:                                                                                # garrafas
		c.caixa(Vector3(-2.7 + i * 0.5, 1.75, -3.85), Vector3(0.09, 0.3, 0.09), Color(0.2 + randf() * 0.5, 0.35 + randf() * 0.3, 0.15))
	c.caixa(Vector3(0, 1.55, -3.9), Vector3(6.0, 0.05, 0.25), madeira)
	c.caixa(Vector3(2.2, 0.74, 1.4), Vector3(1.2, 0.06, 0.9), madeira)                        # mesa do canto
	c.caixa(Vector3(2.2, 0.37, 1.4), Vector3(0.12, 0.72, 0.12), madeira)
	for x in [1.85, 2.55]:                                                                      # copos de cerveja
		c.caixa(Vector3(x, 0.86, 1.3), Vector3(0.08, 0.18, 0.08), Color(0.85, 0.6, 0.15))
	c.caixa(Vector3(4.6, 2.1, 1.4), Vector3(0.1, 0.75, 1.25), Color(0.05, 0.05, 0.06))        # TV na parede
	for x in [1.5, 2.9]:                                                                        # cadeiras
		c.caixa(Vector3(x, 0.45, 1.4), Vector3(0.45, 0.06, 0.45), madeira)
		c.caixa(Vector3(x + (-0.21 if x < 2.2 else 0.21), 0.75, 1.4), Vector3(0.05, 0.6, 0.45), madeira)
		for dx in [-0.18, 0.18]:
			for dz in [-0.18, 0.18]:
				c.caixa(Vector3(x + dx, 0.22, 1.4 + dz), Vector3(0.04, 0.44, 0.04), madeira)
	var mi := MeshInstance3D.new()
	mi.mesh = c.malha(Malhas.mat_cores(0.85))
	_cenario.add_child(mi)
	# tela da TV que pisca (noticiário)
	var tela := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.62)
	tela.mesh = q
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(0.6, 0.15, 0.1)
	tela.material_override = mt
	tela.position = Vector3(4.54, 2.1, 1.4)
	tela.rotation.y = -PI * 0.5
	_cenario.add_child(tela)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.75, 0.45)
	luz.light_energy = 2.2
	luz.omni_range = 9.0
	luz.position = Vector3(0, 2.7, 0.5)
	_cenario.add_child(luz)
	var luz_tv := OmniLight3D.new()
	luz_tv.light_color = Color(0.9, 0.3, 0.25)
	luz_tv.light_energy = 1.0
	luz_tv.omni_range = 4.0
	luz_tv.position = Vector3(4.0, 2.0, 1.4)
	_cenario.add_child(luz_tv)
	return {"tela": mt, "luz_tv": luz_tv}

# ---------- quadro a quadro ----------
func _process(dt: float) -> void:
	if not rodando:
		return
	_faixa = move_toward(_faixa, 1.0, dt * 2.5)
	for n in _escondidos:                      # ninguém mostra a HUD no meio da cena
		if is_instance_valid(n) and n.visible:
			n.visible = false
	_ajustar_faixas()
	_atualizar_camera(dt)
	for id in atores:
		var a: Dictionary = atores[id]
		var n: Node3D = a["no"]
		if not is_instance_valid(n):
			continue
		var vel := 0.0
		if a["destino"] != null and a["tipo"] != "passageiro":
			var d: Vector3 = (a["destino"] as Vector3) - n.global_position
			d.y = 0.0
			var dist := d.length()
			if dist < 0.08:
				a["destino"] = null
			else:
				vel = minf(float(a["vel"]), dist * 4.0)
				n.global_position += d / dist * minf(vel * dt, dist)
				var yaw := atan2(-d.x, -d.z) if a["tipo"] != "carro" else atan2(-d.z, d.x)
				n.rotation.y = lerp_angle(n.rotation.y, yaw, minf(1.0, dt * 8.0))
				if main != null and main.mundo != null and a["tipo"] != "cenario":
					var y: float = main.mundo.altura(n.global_position.x, n.global_position.z)
					if absf(y - n.global_position.y) < 1.0:
						n.global_position.y = y
		a["v"] = lerpf(float(a["v"]), vel, minf(1.0, dt * 6.0))
		var m = a["modelo"]
		if m != null and is_instance_valid(m):
			m.atualizar(dt, float(a["v"]))

# ---------- interface ----------
func _montar_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 22
	_ui.visible = false
	add_child(_ui)
	_faixa_cima = ColorRect.new()
	_faixa_baixo = ColorRect.new()
	for f in [_faixa_cima, _faixa_baixo]:
		f.color = Color.BLACK
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(f)
	_legenda = RichTextLabel.new()
	_legenda.bbcode_enabled = true
	_legenda.fit_content = true
	_legenda.scroll_active = false
	_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legenda.add_theme_color_override("default_color", Color(1, 1, 1, 0.95))
	_ui.add_child(_legenda)
	_preto = ColorRect.new()
	_preto.color = Color(0, 0, 0, 0)
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_preto)
	_pular = Button.new()
	_pular.text = "PULAR ▶▶"
	_pular.focus_mode = Control.FOCUS_NONE
	_pular.pressed.connect(func(): pulando = true)
	_ui.add_child(_pular)
	# toque em qualquer lugar = próxima fala
	var toque := Control.new()
	toque.set_anchors_preset(Control.PRESET_FULL_RECT)
	toque.mouse_filter = Control.MOUSE_FILTER_PASS
	toque.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_avancar = true)
	_ui.add_child(toque)
	_ui.move_child(_pular, -1)
	_ajustar_faixas()

func _ajustar_faixas() -> void:
	var vs := get_viewport().get_visible_rect().size
	var h := vs.y * 0.12 * _faixa
	_faixa_cima.position = Vector2.ZERO
	_faixa_cima.size = Vector2(vs.x, h)
	_faixa_baixo.position = Vector2(0, vs.y - h)
	_faixa_baixo.size = Vector2(vs.x, h)
	var u := vs.y / 100.0
	_legenda.add_theme_font_size_override("normal_font_size", int(3.3 * u))
	_legenda.add_theme_font_size_override("italics_font_size", int(3.3 * u))
	_legenda.position = Vector2(vs.x * 0.1, vs.y - h - 9.5 * u + 2.0 * u * _faixa)
	_legenda.size = Vector2(vs.x * 0.8, 10.0 * u)
	_pular.add_theme_font_size_override("font_size", int(2.6 * u))
	_pular.position = Vector2(vs.x - 20.0 * u, 2.0 * u)
	_pular.size = Vector2(17.0 * u, 6.0 * u)

func _input(e: InputEvent) -> void:
	if not rodando:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE:
			pulando = true
		elif e.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_avancar = true
		get_viewport().set_input_as_handled()
