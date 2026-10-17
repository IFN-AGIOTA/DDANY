extends CanvasLayer
# MAPA · MINIMAPA · BÚSSOLA (HUD de navegação)
#  - MINIMAPA (canto de cima, à esquerda, abaixo do FPS): redondo, gira com o jogador (frente = para cima),
#    ~250 m do centro até a borda, "N" na borda apontando o norte. Tocar/clicar nele abre o MAPA.
#  - MAPA (tecla M ou tocar no minimapa): tela cheia. Arrastar = mover · pinça / rodinha / + − = zoom ·
#    ⌖ = voltar para o jogador (e seguir) · X / M / Esc = fechar. O jogo NÃO pausa; os controles ficam
#    bloqueados (controles.set_bloqueado) enquanto ele está aberto.
#  - BÚSSOLA (faixa no alto, no meio): N, NE, L, SE, S, SO, O, NO, marcas a cada 15° e o rumo em graus.
#  - OBJETIVO: definir_objetivo(Vector2(x, z), "nome") / limpar_objetivo(). Aparece no minimapa (seta na borda
#    quando está fora do alcance), no mapa e na bússola, com a distância em metros.
# A IMAGEM DO MAPA é desenhada UMA vez ao começar (SubViewport: água, terra, parques, calçadas, ruas e prédios
# de mundo/cidade.gd, ~4,4 m por pixel no PC e ~5,9 no celular, com mipmaps) e fica guardada; o minimapa só gira/recorta essa imagem num
# shader (nada de imagem refeita por quadro). No mapa com muito zoom, ruas e prédios perto são redesenhados em
# vetor por cima (ficam nítidos).
# Coordenadas: x = leste, z = sul (NORTE = -Z). Rumo = graus no sentido horário a partir do norte (= -cam_yaw).
# Opções › HUD › Minimapa (Config "map"): oculto = some o minimapa (a bússola fica).
# Mexa AQUI para: cores do mapa, tamanho/alcance do minimapa, limites do zoom, aparência da bússola.
# Quem usa: main.gd (cria e chama ligar) e menu/aplicar_opcoes.gd (aplicar_estilo).

const UI := preload("res://menu/ui.gd")

const RAIO_MINI := 250.0            # metros do centro até a borda do minimapa
const TAM_MINI := 22.0              # diâmetro do minimapa (vh = 1% da altura da tela)
const TEX_MAX := 4096               # lado maior da imagem do mapa no PC (px) · 4096 ≈ 4,4 m por pixel (~44 MB)
const TEX_MAX_CELULAR := 3072       # no celular · 3072 ≈ 5,9 m por pixel (~25 MB com mipmaps)
const MARGEM := 700.0               # mar em volta da terra na imagem (m)
const CALCADA := 5.0                # igual a mundo/cidade.gd
const MPP_MIN := 0.6                # zoom máximo do mapa (metros por pixel da tela)
const MPP_INICIAL := 5.0            # zoom ao abrir o mapa pela primeira vez
const CEL_GRADE := 250.0            # grade dos vetores (ruas/prédios) do zoom alto
const VAO_BUSSOLA := 70.0           # graus mostrados para cada lado do centro da bússola

const COR_AGUA := Color(0.075, 0.13, 0.21)
const COR_TERRA := Color(0.235, 0.222, 0.198)
const COR_PARQUE := Color(0.14, 0.25, 0.13)
const COR_CALCADA := Color(0.32, 0.31, 0.29)
const COR_RUA := Color(0.47, 0.47, 0.46)
const COR_PREDIO := Color(0.125, 0.125, 0.135)
const COR_RUINA := Color(0.26, 0.15, 0.11)
const COR_JOGADOR := Color(0.40, 0.88, 1.0)
const COR_OBJETIVO := Color(1.0, 0.706, 0.0)
const COR_FUNDO := Color(0.03, 0.05, 0.08, 0.6)
const RUMOS := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]

const SHADER_MINI := """
shader_type canvas_item;
uniform sampler2D mapa : filter_linear_mipmap, repeat_disable;
uniform float pronto = 0.0;
uniform vec2 centro;            // jogador em UV da imagem
uniform vec2 eixo_x;            // direita da tela (UV por raio)
uniform vec2 eixo_y;            // baixo da tela (UV por raio)
uniform vec4 cor_fora : source_color;
uniform float px = 160.0;       // diâmetro em pixels (borda suave)
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 uv = centro + eixo_x * p.x + eixo_y * p.y;
	vec3 c = cor_fora.rgb;
	if (pronto > 0.5 && uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		c = texture(mapa, uv).rgb;
	}
	c *= mix(1.0, 0.72, smoothstep(0.62, 1.0, r));
	float a = 1.0 - smoothstep(1.0 - 3.0 / px, 1.0, r);
	COLOR = vec4(c, a * 0.9 * COLOR.a);
}
"""

# imagem do mapa guardada entre partidas (a cidade é a mesma)
static var _cache_tex: Texture2D = null
static var _cache_ret := Rect2()
static var _cache_id := 0

var cidade: Node = null
var jogador: Node = null
var controles: Node = null
var visivel_hud := true             # false = esconde tudo (ex.: inventário aberto)
var escala := 1.0                   # Opções › HUD › Tamanho geral
var opacidade := 1.0                # Opções › HUD › Opacidade
var aberto := false                 # mapa em tela cheia

var _tex: Texture2D = null
var _ret := Rect2()                 # área do mundo coberta pela imagem (x, z, largura, altura em m)
var _mostrar_mini := true
var _obj := false
var _obj_pos := Vector2.ZERO
var _obj_nome := ""
var _pos := Vector2.ZERO            # quem está olhando (jogador, ou a câmera do VOO)
var _rumo := 0.0                    # rad, horário a partir do norte

var _raiz: Control
var _mini: ColorRect
var _mat: ShaderMaterial
var _sobre: Control
var _camada: CanvasLayer
var _tela: ColorRect                # fundo (mar) do mapa aberto
var _mundo: Node2D                  # imagem + vetores, em metros (mover/zoom = só muda a transformação)
var _ui: Control                    # jogador, objetivo, botões, títulos
var _area_vet := Rect2()            # área do mundo já desenhada em vetor (zoom alto)
var _fonte: Font
var _mini_c := Vector2.ZERO
var _mini_r := 0.0

# mapa aberto
var _centro := Vector2.ZERO         # ponto do mundo no meio da tela
var _mpp := MPP_INICIAL             # metros por pixel
var _seguir := true
var _toques := {}                   # índice do dedo -> posição

# geração da imagem e vetores do zoom alto
var _img: Image = null
var _tarefa := -1
var _grade_predios := {}            # Vector2i -> PackedInt32Array (índices em cidade.predios)
var _grade_ruas := {}               # Vector2i -> PackedFloat32Array (ax, az, bx, bz, meia largura, último trecho)
var _ruina := PackedByteArray()

func _ready() -> void:
	layer = 6
	_fonte = UI.fonte(800, 0.0, false)
	_raiz = Control.new()
	_raiz.name = "Hud"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_MINI
	_mat.shader = sh
	_mat.set_shader_parameter("cor_fora", COR_AGUA)
	_mini = ColorRect.new()
	_mini.name = "Minimapa"
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.material = _mat
	_raiz.add_child(_mini)
	_sobre = Control.new()
	_sobre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sobre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sobre.draw.connect(_desenhar_hud)
	_raiz.add_child(_sobre)
	# mapa em tela cheia: camada própria, por cima de tudo do jogo
	_camada = CanvasLayer.new()
	_camada.name = "MapaAberto"
	_camada.layer = 15
	_camada.visible = false
	add_child(_camada)
	_tela = ColorRect.new()
	_tela.color = COR_AGUA
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_tela)
	_mundo = Node2D.new()
	_mundo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mundo.draw.connect(_desenhar_mundo)
	_tela.add_child(_mundo)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_desenhar_mapa)
	_tela.add_child(_ui)
	var cfg := get_node_or_null("/root/Config")
	if cfg != null:
		_mostrar_mini = bool(cfg.valor("map"))
		cfg.mudou.connect(_config_mudou)

func _exit_tree() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1

func _config_mudou(k: String) -> void:
	if k == "map":
		_mostrar_mini = bool(get_node("/root/Config").valor("map"))

# ---------- API ----------
func ligar(c: Node, j: Node, ctrl: Node) -> void:
	cidade = c
	jogador = j
	controles = ctrl
	if _cache_tex != null and _cache_id == c.get_instance_id():
		_tex = _cache_tex
		_ret = _cache_ret
		_usar_textura()
	else:
		_gerar_textura()

# Opções › HUD: tamanho e opacidade (só minimapa e bússola; o mapa aberto fica sempre inteiro)
func aplicar_estilo(esc: float, opac: float) -> void:
	escala = esc
	opacidade = opac
	if _raiz != null:
		_raiz.modulate.a = opac

# pos = (x, z) do mundo
func definir_objetivo(pos: Vector2, nome := "") -> void:
	_obj = true
	_obj_pos = pos
	_obj_nome = nome

func limpar_objetivo() -> void:
	_obj = false
	_obj_nome = ""

func tem_objetivo() -> bool:
	return _obj

func abrir_mapa() -> void:
	if aberto or controles == null:
		return
	aberto = true
	controles.set_bloqueado(true)
	_toques.clear()
	_seguir = true
	_centro = _pos
	_limitar()
	_camada.visible = true
	_raiz.visible = false
	_atualizar_mundo()
	_ui.queue_redraw()

# restaurar = false quando outra tela (inventário) já assumiu os controles
func fechar_mapa(restaurar := true) -> void:
	if not aberto:
		return
	aberto = false
	_toques.clear()
	_camada.visible = false
	if restaurar and controles != null:
		controles.set_bloqueado(false)

func alternar_mapa() -> void:
	if aberto:
		fechar_mapa()
	elif _pode_abrir():
		abrir_mapa()

func _pode_abrir() -> bool:
	return controles != null and jogador != null and visivel_hud and not bool(controles.bloqueado) and not bool(controles.editando)

# ---------- imagem do mapa (uma vez) ----------
func _gerar_textura() -> void:
	var dados = cidade.get("dados_cidade")
	if dados == null:
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for l in dados["lands"]:
		var f: Array = l[1]
		for i in range(0, f.size() - 1, 2):
			mn = mn.min(Vector2(f[i], f[i + 1]))
			mx = mx.max(Vector2(f[i], f[i + 1]))
	mn -= Vector2(MARGEM, MARGEM)
	mx += Vector2(MARGEM, MARGEM)
	var lado := TEX_MAX_CELULAR if OS.has_feature("mobile") else TEX_MAX
	var mpp := maxf(mx.x - mn.x, mx.y - mn.y) / float(lado)
	var px := Vector2i(ceili((mx.x - mn.x) / mpp), ceili((mx.y - mn.y) / mpp))
	_ret = Rect2(mn, Vector2(px) * mpp)
	var vp := SubViewport.new()
	vp.size = px
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var no := Node2D.new()
	no.scale = Vector2.ONE / mpp
	no.position = -mn / mpp
	no.draw.connect(_desenhar_cidade.bind(no, dados))
	vp.add_child(no)
	add_child(vp)
	await RenderingServer.frame_post_draw
	_img = vp.get_texture().get_image()
	vp.queue_free()
	if _img == null or _img.is_empty():
		push_warning("mapa: não deu para ler a imagem do mapa")
		return
	_tarefa = WorkerThreadPool.add_task(_preparar_imagem, true, "mapa")

# (outra thread) mipmaps = mapa afastado sem serrilhado · RGB8 = sem o canal alfa (menos memória)
func _preparar_imagem() -> void:
	_img.convert(Image.FORMAT_RGB8)
	_img.generate_mipmaps()

func _terminar_textura() -> void:
	WorkerThreadPool.wait_for_task_completion(_tarefa)
	_tarefa = -1
	_tex = ImageTexture.create_from_image(_img)
	_img = null
	_cache_tex = _tex
	_cache_ret = _ret
	_cache_id = cidade.get_instance_id() if cidade != null else 0
	_usar_textura()

func _usar_textura() -> void:
	_mat.set_shader_parameter("mapa", _tex)
	_mat.set_shader_parameter("pronto", 1.0)
	_mundo.queue_redraw()

static func _pts(f: Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in range(0, f.size() - 1, 2):
		o.append(Vector2(f[i], f[i + 1]))
	return o

# desenha a cidade inteira em metros (o Node2D da SubViewport converte para pixels)
func _desenhar_cidade(ci: CanvasItem, dados) -> void:
	var rid := ci.get_canvas_item()
	ci.draw_rect(_ret.grow(50.0), COR_AGUA)
	for l in dados["lands"]:
		_poligono(rid, _pts(l[1]), COR_AGUA if int(l[0]) == 1 else COR_TERRA)
	for f in dados["parks"]:
		_poligono(rid, _pts(f), COR_PARQUE)
	var ruas: Array = dados["roads"]
	for passo in 2:
		var cor := COR_CALCADA if passo == 0 else COR_RUA
		for rd in ruas:
			var hw: float = float(rd[0]) * 0.5 + (CALCADA if passo == 0 else 0.0)
			var pts := _pts(rd[1])
			for i in pts.size():
				ci.draw_circle(pts[i], hw, cor)
				if i > 0:
					ci.draw_line(pts[i - 1], pts[i], cor, hw * 2.0)
	_preparar_ruinas()
	var pr: PackedFloat32Array = cidade.predios
	for i in pr.size() / 5:
		var k := i * 5
		ci.draw_rect(Rect2(pr[k] - pr[k + 2] * 0.5, pr[k + 1] - pr[k + 3] * 0.5, pr[k + 2], pr[k + 3]), _cor_predio(i, pr[k + 4]))

func _poligono(rid: RID, p: PackedVector2Array, cor: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(p)
	if idx.is_empty():
		push_warning("mapa: polígono não triangulado (ignorado)")
		return
	RenderingServer.canvas_item_add_triangle_array(rid, idx, p, PackedColorArray([cor]))

func _preparar_ruinas() -> void:
	var n: int = cidade.predios.size() / 5
	if _ruina.size() == n:
		return
	_ruina.resize(n)
	_ruina.fill(0)
	var info = cidade.get("predio_info")
	if info is Array and info.size() == n:
		for i in n:
			if bool(info[i].get("ruina", false)):
				_ruina[i] = 1

func _cor_predio(i: int, h: float) -> Color:
	if _ruina[i] == 1:
		return COR_RUINA
	return COR_PREDIO.darkened(clampf(h / 160.0, 0.0, 1.0) * 0.3)   # torres um pouco mais escuras

# grade (lazy) para redesenhar ruas/prédios em vetor no zoom alto
func _montar_grades() -> void:
	if not _grade_predios.is_empty() or cidade == null:
		return
	_preparar_ruinas()
	var pr: PackedFloat32Array = cidade.predios
	for i in pr.size() / 5:
		var ch := Vector2i(floori(pr[i * 5] / CEL_GRADE), floori(pr[i * 5 + 1] / CEL_GRADE))
		if not _grade_predios.has(ch):
			_grade_predios[ch] = PackedInt32Array()
		_grade_predios[ch].append(i)
	for rd in cidade.dados_cidade["roads"]:
		var hw: float = float(rd[0]) * 0.5
		var pts := _pts(rd[1])
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var m := hw + CALCADA
			for cx in range(floori((minf(a.x, b.x) - m) / CEL_GRADE), floori((maxf(a.x, b.x) + m) / CEL_GRADE) + 1):
				for cz in range(floori((minf(a.y, b.y) - m) / CEL_GRADE), floori((maxf(a.y, b.y) + m) / CEL_GRADE) + 1):
					var ch := Vector2i(cx, cz)
					if not _grade_ruas.has(ch):
						_grade_ruas[ch] = PackedFloat32Array()
					_grade_ruas[ch].append_array(PackedFloat32Array([a.x, a.y, b.x, b.y, hw, 1.0 if i == pts.size() - 2 else 0.0]))

# ---------- quadro a quadro ----------
var _t_sobre := 0.0
var _pos_desenho := Vector2(INF, INF)
var _rumo_desenho := 0.0
var _c_desenho := Vector2.ZERO

func _process(_dt: float) -> void:
	if _tarefa >= 0 and WorkerThreadPool.is_task_completed(_tarefa):
		_terminar_textura()
	if jogador == null or controles == null or not is_instance_valid(jogador):
		_raiz.visible = false
		return
	_observador()
	if aberto and (not visivel_hud or bool(controles.editando)):
		fechar_mapa()
	if aberto:
		if _seguir:
			_centro = _pos
		_atualizar_mundo()
		_ui.queue_redraw()
		return
	_raiz.visible = visivel_hud and not bool(controles.bloqueado)
	if not _raiz.visible:
		return
	var vs := _raiz.get_viewport_rect().size
	var vh := vs.y / 100.0 * escala
	var topo := 12.0
	var info: Label = controles.get("info")
	if info != null and info.visible and info.text != "":
		topo = info.position.y + info.size.y
	topo += 1.8 * vh                    # espaço para o "N" da borda
	_mini_r = TAM_MINI * vh * 0.5
	_mini_c = Vector2(16.0 + _mini_r, topo + _mini_r)
	_mini.visible = _mostrar_mini
	# OTIMIZAÇÃO: minimapa e bússola só são refeitos quando o jogador anda/gira ou a cada 0,25 s (marcadores)
	_t_sobre -= _dt
	var mexeu := _pos.distance_squared_to(_pos_desenho) > 0.25 or absf(angle_difference(_rumo, _rumo_desenho)) > 0.006 \
		or _mini_c != _c_desenho
	if not mexeu and _t_sobre > 0.0:
		return
	_t_sobre = 0.25
	_pos_desenho = _pos
	_rumo_desenho = _rumo
	_c_desenho = _mini_c
	if _mostrar_mini:
		_mini.position = _mini_c - Vector2(_mini_r, _mini_r)
		_mini.size = Vector2(_mini_r, _mini_r) * 2.0
		var frente := Vector2(sin(_rumo), -cos(_rumo))
		var direita := Vector2(cos(_rumo), sin(_rumo))
		var tam := _ret.size if _ret.size.x > 0.0 else Vector2.ONE
		_mat.set_shader_parameter("centro", (_pos - _ret.position) / tam)
		_mat.set_shader_parameter("eixo_x", direita * RAIO_MINI / tam)
		_mat.set_shader_parameter("eixo_y", -frente * RAIO_MINI / tam)
		_mat.set_shader_parameter("px", _mini_r * 2.0)
	_sobre.queue_redraw()

# posição e rumo de quem olha: o jogador, ou a câmera livre durante o VOO
func _observador() -> void:
	if bool(controles.get("modo_voo")):
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var b := cam.global_transform.basis
			var f := -b.z
			if Vector2(f.x, f.z).length() < 0.05:
				f = b.y
			_pos = Vector2(cam.global_position.x, cam.global_position.z)
			_rumo = atan2(f.x, -f.z)
			return
	var p: Vector3 = jogador.global_position
	_pos = Vector2(p.x, p.z)
	_rumo = -float(jogador.get("cam_yaw"))

# rumo (graus 0..360, horário a partir do norte) de um ponto do mundo visto de _pos
func _rumo_para(w: Vector2) -> float:
	var d := w - _pos
	return fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)

static func _metros(d: float) -> String:
	return "%d m" % int(round(d))

# ---------- entrada ----------
func _input(e: InputEvent) -> void:
	if controles == null or jogador == null:
		return
	if aberto:
		_entrada_mapa(e)
		return
	if e is InputEventKey:
		var k := e as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_M and _pode_abrir():
			abrir_mapa()
			get_viewport().set_input_as_handled()
	elif e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _raiz.visible and _mini.visible and _mostrar_mini and _pode_abrir() \
				and t.position.distance_to(_mini_c) <= _mini_r * 1.05:
			abrir_mapa()
			get_viewport().set_input_as_handled()

func _entrada_mapa(e: InputEvent) -> void:
	var vs := _tela.get_viewport_rect().size
	if e is InputEventKey:
		var k := e as InputEventKey
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_M, KEY_ESCAPE:
				fechar_mapa()
				get_viewport().set_input_as_handled()
			KEY_TAB, KEY_I:
				fechar_mapa()           # deixa a tecla seguir: o inventário abre
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_zoom_em(vs * 0.5, 1.0 / 1.6)
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_em(vs * 0.5, 1.6)
				get_viewport().set_input_as_handled()
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			if _toques.is_empty():
				var b := _botao_em(t.position)
				if b != "":
					_apertar(b)
					get_viewport().set_input_as_handled()
					return
			_toques[t.index] = t.position
		else:
			_toques.erase(t.index)
	elif e is InputEventScreenDrag:
		var g := e as InputEventScreenDrag
		if _toques.has(g.index):
			if _toques.size() == 1:
				_centro -= g.relative * _mpp
				_seguir = false
				_limitar()
				_toques[g.index] = g.position
			else:
				var ks: Array = _toques.keys()
				var a0: Vector2 = _toques[ks[0]]
				var b0: Vector2 = _toques[ks[1]]
				_toques[g.index] = g.position
				var a1: Vector2 = _toques[ks[0]]
				var b1: Vector2 = _toques[ks[1]]
				var d0 := maxf(10.0, a0.distance_to(b0))
				var d1 := maxf(10.0, a1.distance_to(b1))
				var w := _tela_para_mundo((a0 + b0) * 0.5)
				_mpp = clampf(_mpp * d0 / d1, MPP_MIN, _mpp_max())
				_centro = w - ((a1 + b1) * 0.5 - vs * 0.5) * _mpp
				_seguir = false
				_limitar()
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_em(mb.position, 1.0 / 1.2)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_em(mb.position, 1.2)
	elif e is InputEventMagnifyGesture:
		var mg := e as InputEventMagnifyGesture
		_zoom_em(mg.position, 1.0 / maxf(0.1, mg.factor))
	elif e is InputEventPanGesture:
		_centro += (e as InputEventPanGesture).delta * _mpp * 8.0
		_seguir = false
		_limitar()
	elif not (e is InputEventMouseMotion):
		return
	get_viewport().set_input_as_handled()      # com o mapa aberto, toque/mouse não chegam ao jogo

func _zoom_em(tela: Vector2, fator: float) -> void:
	var w := _tela_para_mundo(tela)
	_mpp = clampf(_mpp * fator, MPP_MIN, _mpp_max())
	if not _seguir:
		_centro = w - (tela - _tela.get_viewport_rect().size * 0.5) * _mpp
	_limitar()

func _mpp_max() -> float:
	var vs := _tela.get_viewport_rect().size
	return maxf(MPP_MIN * 2.0, maxf(_ret.size.x / vs.x, _ret.size.y / vs.y) * 1.1)

func _limitar() -> void:
	_mpp = clampf(_mpp, MPP_MIN, _mpp_max())
	if _ret.size.x > 0.0:
		_centro = _centro.clamp(_ret.position, _ret.end)

func _tela_para_mundo(s: Vector2) -> Vector2:
	return _centro + (s - _tela.get_viewport_rect().size * 0.5) * _mpp

func _mundo_para_tela(w: Vector2) -> Vector2:
	return _tela.get_viewport_rect().size * 0.5 + (w - _centro) / _mpp

# botões do mapa aberto: [id, centro, raio]
func _botoes() -> Array:
	var vs := _tela.get_viewport_rect().size
	var vh := vs.y / 100.0
	var x := vs.x - 7.5 * vh
	var r := 4.4 * vh
	return [["fechar", Vector2(x, 7.5 * vh), r], ["mais", Vector2(x, vs.y * 0.5 - 12.0 * vh), r],
		["menos", Vector2(x, vs.y * 0.5), r], ["centro", Vector2(x, vs.y * 0.5 + 12.0 * vh), r]]

func _botao_em(p: Vector2) -> String:
	for b in _botoes():
		if p.distance_to(b[1]) <= float(b[2]) * 1.2:
			return b[0]
	return ""

func _apertar(id: String) -> void:
	var vs := _tela.get_viewport_rect().size
	match id:
		"fechar": fechar_mapa()
		"mais": _zoom_em(vs * 0.5, 1.0 / 1.6)
		"menos": _zoom_em(vs * 0.5, 1.6)
		"centro":
			_seguir = true
			_centro = _pos
			_limitar()

# ---------- desenho: texto e símbolos ----------
# OTIMIZAÇÃO: os textos vão para uma FILA e são desenhados todos juntos no fim (_soltar_textos). Texto no meio de
# linhas/círculos troca de textura (a fonte) e quebra o lote do desenho 2D: a bússola fazia ~25 chamadas de desenho.
var _fila_txt: Array = []

func _texto(ci: CanvasItem, txt: String, centro: Vector2, tam: int, cor: Color, alinhar := 0) -> void:
	var w := _fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var x := centro.x - w * 0.5
	if alinhar < 0:
		x = centro.x
	elif alinhar > 0:
		x = centro.x - w
	_fila_txt.append([ci, Vector2(x, centro.y + tam * 0.36), txt, tam, cor])

# contornos de todos primeiro, depois o preenchimento (mesma textura: um lote só)
func _soltar_textos() -> void:
	for e in _fila_txt:
		var cor: Color = e[4]
		(e[0] as CanvasItem).draw_string_outline(_fonte, e[1], e[2], HORIZONTAL_ALIGNMENT_LEFT, -1, e[3], maxi(3, int(e[3]) / 5), Color(0, 0, 0, 0.75 * cor.a))
	for e in _fila_txt:
		(e[0] as CanvasItem).draw_string(_fonte, e[1], e[2], HORIZONTAL_ALIGNMENT_LEFT, -1, e[3], e[4])
	_fila_txt.clear()

func _largura(txt: String, tam: int) -> float:
	return _fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x

# seta do jogador (ponta para cima quando ang = 0; ang no sentido horário)
func _seta(ci: CanvasItem, c: Vector2, ang: float, tam: float, cor: Color) -> void:
	var base := [Vector2(0, -1.0), Vector2(0.75, 0.85), Vector2(0, 0.48), Vector2(-0.75, 0.85)]
	var pts := PackedVector2Array()
	for v in base:
		pts.append(c + (v as Vector2).rotated(ang) * tam)
	var contorno := pts.duplicate()
	contorno.append(pts[0])
	ci.draw_polyline(contorno, Color(0, 0, 0, 0.85), maxf(3.0, tam * 0.28), true)
	ci.draw_colored_polygon(pts, cor)

# losango do objetivo
func _losango(ci: CanvasItem, c: Vector2, tam: float, cor: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -tam), c + Vector2(tam * 0.75, 0), c + Vector2(0, tam), c + Vector2(-tam * 0.75, 0)])
	var contorno := pts.duplicate()
	contorno.append(pts[0])
	ci.draw_polyline(contorno, Color(0, 0, 0, 0.85 * cor.a), maxf(2.5, tam * 0.3), true)
	ci.draw_colored_polygon(pts, cor)
	ci.draw_circle(c, tam * 0.22, Color(0.1, 0.06, 0.0, cor.a))

# ---------- desenho: minimapa + bússola ----------
func _desenhar_hud() -> void:
	var vs := _sobre.get_viewport_rect().size
	var vh := vs.y / 100.0 * escala
	_fila_txt.clear()
	if _mostrar_mini:
		_desenhar_minimapa(vh)
	_desenhar_bussola(vs, vh)
	_soltar_textos()

func _desenhar_minimapa(vh: float) -> void:
	var c := _mini_c
	var r := _mini_r
	var ci := _sobre
	UI.aro(ci, c, r + 0.9 * vh, 0.9 * vh, COR_FUNDO)                       # (texturas: entram num lote só)
	var gf := maxf(1.5, 0.2 * vh)
	UI.aro(ci, c, r + gf * 0.5, gf, Color(1, 1, 1, 0.28))
	var esc := r / RAIO_MINI
	var frente := Vector2(sin(_rumo), -cos(_rumo))
	var direita := Vector2(cos(_rumo), sin(_rumo))
	# objetivo: no mapa (dentro do alcance) ou seta na borda
	if _obj:
		var d := _obj_pos - _pos
		var p := Vector2(d.dot(direita), -d.dot(frente)) * esc
		if p.length() <= r - 1.4 * vh:
			_losango(ci, c + p, 1.5 * vh, COR_OBJETIVO)
		else:
			var dir := p.normalized()
			var ponta := c + dir * (r - 0.3 * vh)
			var tri := PackedVector2Array([ponta, ponta - dir * 1.9 * vh + dir.orthogonal() * 1.1 * vh, ponta - dir * 1.9 * vh - dir.orthogonal() * 1.1 * vh])
			var cont := tri.duplicate()
			cont.append(tri[0])
			ci.draw_polyline(cont, Color(0, 0, 0, 0.8), maxf(2.0, 0.3 * vh), true)
			ci.draw_colored_polygon(tri, COR_OBJETIVO)
	# jogador no centro (frente = para cima)
	_seta(ci, c, 0.0, 1.5 * vh, COR_JOGADOR)
	# "N" na borda, onde fica o norte
	var n := Vector2(-sin(_rumo), -cos(_rumo))
	var pn := c + n * r
	UI.circulo(ci, pn, 1.55 * vh, Color(0.03, 0.05, 0.08, 0.92))
	var gn := maxf(1.5, 0.22 * vh)
	UI.aro(ci, pn, 1.55 * vh + gn * 0.5, gn, Color(1.0, 0.42, 0.2, 0.95))
	_texto(ci, "N", pn, int(2.0 * vh), Color(1.0, 0.55, 0.3))
	# distância do objetivo embaixo do minimapa
	if _obj:
		var txt := _metros((_obj_pos - _pos).length())
		if _obj_nome != "":
			txt = _obj_nome + " · " + txt
		_texto(ci, txt, Vector2(16.0, c.y + r + 2.6 * vh), int(1.9 * vh), COR_OBJETIVO, -1)

func _limites_bussola(vs: Vector2) -> Vector2:
	var esq := 16.0
	var info: Label = controles.get("info")
	if info != null and info.visible and info.text != "":
		esq = info.position.x + _largura_label(info) + 12.0
	var dir := vs.x - 16.0
	var botoes = controles.get("botoes")
	if botoes is Array:
		for b in botoes:
			if b["canto"] != "tr" or bool(b["voo"]):
				continue
			var off: Vector2 = b["off"]
			var r: float = b["r"]
			if off.y - r < vs.y * 0.16:
				dir = minf(dir, vs.x - off.x - r - 12.0)
	return Vector2(esq, dir)

func _largura_label(l: Label) -> float:
	var f := l.get_theme_font("font")
	var t := l.get_theme_font_size("font_size")
	return f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x if f != null else l.size.x

var _tr_pts: Array = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
var _tr_cor: Array = [PackedColorArray(), PackedColorArray(), PackedColorArray()]

func _tracos(k: int, a: Vector2, b: Vector2, cor: Color) -> void:
	var p: PackedVector2Array = _tr_pts[k]
	p.append(a)
	p.append(b)
	_tr_pts[k] = p
	var c: PackedColorArray = _tr_cor[k]
	c.append(cor)
	_tr_cor[k] = c

func _desenhar_bussola(vs: Vector2, vh: float) -> void:
	var ci := _sobre
	var lim := _limites_bussola(vs)
	var cx := vs.x * 0.5
	var meia := minf(23.0 * vh, minf(cx - lim.x, lim.y - cx))
	if meia < 12.0 * vh:
		cx = (lim.x + lim.y) * 0.5
		meia = minf(23.0 * vh, (lim.y - lim.x) * 0.5)
	if meia < 6.0 * vh:
		return
	var alt := 5.0 * vh
	var y0 := 1.4 * vh
	UI.caixa_arredondada(ci, Rect2(cx - meia, y0, meia * 2.0, alt), COR_FUNDO, alt * 0.3)
	var graus := fposmod(rad_to_deg(_rumo), 360.0)
	var ppg := meia / VAO_BUSSOLA
	var g0 := int(ceil((graus - VAO_BUSSOLA) / 5.0)) * 5
	var g := g0
	while float(g) <= graus + VAO_BUSSOLA:
		var dx := (float(g) - graus) * ppg
		var a := 1.0 - smoothstep(0.7, 1.0, absf(dx) / meia)
		var gm := posmod(g, 360)
		var x := cx + dx
		if gm % 45 == 0:
			var rotulo: String = RUMOS[gm / 45]
			var norte := gm == 0
			var cor := Color(1.0, 0.55, 0.3, a) if norte else Color(1, 1, 1, a * (1.0 if gm % 90 == 0 else 0.78))
			_texto(ci, rotulo, Vector2(x, y0 + alt * 0.4), int((2.6 if gm % 90 == 0 else 2.1) * vh), cor)
			_tracos(0, Vector2(x, y0 + alt * 0.72), Vector2(x, y0 + alt * 0.95), Color(1, 1, 1, a * 0.9))
		elif gm % 15 == 0:
			_tracos(1, Vector2(x, y0 + alt * 0.66), Vector2(x, y0 + alt * 0.95), Color(1, 1, 1, a * 0.65))
		else:
			_tracos(2, Vector2(x, y0 + alt * 0.82), Vector2(x, y0 + alt * 0.95), Color(1, 1, 1, a * 0.4))
		g += 5
	# os tracinhos como RETÂNGULOS (retângulos seguidos entram num lote só; draw_line era 1 chamada cada)
	for k in 3:
		var w: float = [maxf(1.5, 0.22 * vh), maxf(1.0, 0.16 * vh), maxf(1.0, 0.14 * vh)][k]
		var pts: PackedVector2Array = _tr_pts[k]
		for i in range(0, pts.size(), 2):
			ci.draw_rect(Rect2(pts[i].x - w * 0.5, pts[i].y, w, pts[i + 1].y - pts[i].y), _tr_cor[k][i / 2])
		_tr_pts[k] = PackedVector2Array()
		_tr_cor[k] = PackedColorArray()
	# objetivo na bússola
	var caixa_txt := Rect2()
	var txt_rumo := "%d°" % (int(round(graus)) % 360)
	var tr := int(2.1 * vh)
	var wr := _largura(txt_rumo, tr) + 1.6 * vh
	caixa_txt = Rect2(cx - wr * 0.5, y0 + alt + 0.4 * vh, wr, 2.9 * vh)
	if _obj:
		var dg := wrapf(_rumo_para(_obj_pos) - graus, -180.0, 180.0)
		var dist := _metros((_obj_pos - _pos).length())
		var td := int(1.9 * vh)
		if absf(dg) <= VAO_BUSSOLA * 0.92:
			var x := cx + dg * ppg
			_losango(ci, Vector2(x, y0 + alt * 0.12), 1.15 * vh, COR_OBJETIVO)
			var wd := _largura(dist, td)
			var px := x
			if absf(px - cx) < (wr + wd) * 0.5 + 0.6 * vh:
				px = cx + signf(dg if dg != 0.0 else 1.0) * ((wr + wd) * 0.5 + 0.6 * vh)
			_texto(ci, dist, Vector2(px, caixa_txt.get_center().y), td, COR_OBJETIVO)
		else:
			var lado := signf(dg)
			var px := cx + lado * (meia + 1.4 * vh)
			var tri := PackedVector2Array([Vector2(px + lado * 0.9 * vh, y0 + alt * 0.5), Vector2(px - lado * 0.5 * vh, y0 + alt * 0.5 - 1.1 * vh), Vector2(px - lado * 0.5 * vh, y0 + alt * 0.5 + 1.1 * vh)])
			ci.draw_colored_polygon(tri, COR_OBJETIVO)
			_texto(ci, dist, Vector2(cx + lado * (meia - 3.0 * vh), caixa_txt.get_center().y), td, COR_OBJETIVO)
	# marcador do centro e rumo em graus
	var tri_c := PackedVector2Array([Vector2(cx, y0 + alt * 0.62), Vector2(cx - 0.8 * vh, y0 + alt + 0.3 * vh), Vector2(cx + 0.8 * vh, y0 + alt + 0.3 * vh)])
	ci.draw_colored_polygon(tri_c, COR_OBJETIVO)
	UI.caixa_arredondada(ci, caixa_txt, COR_FUNDO, 0.6 * vh)
	_texto(ci, txt_rumo, caixa_txt.get_center(), tr, Color(1, 1, 1, 0.95))

# ---------- desenho: mapa aberto ----------
# mover/zoom só mudam a transformação do nó _mundo; ele só é redesenhado quando o zoom alto precisa de
# vetores de uma área nova (com folga de 15%), então arrastar o mapa não refaz milhares de prédios por quadro
func _atualizar_mundo() -> void:
	var vs := _tela.get_viewport_rect().size
	var k := 1.0 / _mpp
	_mundo.position = vs * 0.5 - _centro * k
	_mundo.scale = Vector2(k, k)
	var quer := _tex != null and _mpp < _ret.size.x / float(_tex.get_width()) * 0.5   # imagem ampliada 2x ou mais
	if quer:
		var vis := Rect2(_tela_para_mundo(Vector2.ZERO), vs * _mpp)
		if not _area_vet.encloses(vis):
			_area_vet = vis.grow(maxf(vis.size.x, vis.size.y) * 0.15)
			_mundo.queue_redraw()
	elif _area_vet.has_area():
		_area_vet = Rect2()
		_mundo.queue_redraw()

func _desenhar_mundo() -> void:
	if _tex == null:
		return
	_mundo.draw_texture_rect(_tex, _ret, false)
	if _area_vet.has_area():
		_desenhar_vetores(_mundo, _area_vet)

func _desenhar_mapa() -> void:
	var ci := _ui
	var vs := ci.get_viewport_rect().size
	var vh := vs.y / 100.0
	_fila_txt.clear()
	if _tex == null:
		_texto(ci, "PREPARANDO O MAPA...", vs * 0.5, int(3.0 * vh), UI.TEXTO)
	# objetivo
	if _obj:
		var po := _mundo_para_tela(_obj_pos)
		var dentro := Rect2(Vector2(4.0 * vh, 14.0 * vh), vs - Vector2(21.0 * vh, 24.0 * vh))   # fora dos botões e do título
		var dist := _metros((_obj_pos - _pos).length())
		var rot := (_obj_nome + " · " + dist) if _obj_nome != "" else dist
		var tr := int(2.2 * vh)
		var meia_txt := _largura(rot, tr) * 0.5 + 1.0 * vh
		if dentro.grow(2.0 * vh).has_point(po):
			_losango(ci, po, 2.0 * vh, COR_OBJETIVO)
			_texto(ci, rot, Vector2(clampf(po.x, meia_txt, vs.x - meia_txt), po.y - 3.6 * vh), tr, COR_OBJETIVO)
		else:
			var c := dentro.get_center()
			var dir := (po - c).normalized()
			var t := INF
			if absf(dir.x) > 0.001:
				t = minf(t, (dentro.size.x * 0.5) / absf(dir.x))
			if absf(dir.y) > 0.001:
				t = minf(t, (dentro.size.y * 0.5) / absf(dir.y))
			var pb := c + dir * t
			var tri := PackedVector2Array([pb + dir * 1.4 * vh, pb - dir * 1.2 * vh + dir.orthogonal() * 1.3 * vh, pb - dir * 1.2 * vh - dir.orthogonal() * 1.3 * vh])
			ci.draw_colored_polygon(tri, COR_OBJETIVO)
			var pt := pb - dir * 4.5 * vh
			_texto(ci, rot, Vector2(clampf(pt.x, meia_txt, vs.x - 16.0 * vh - meia_txt), pt.y), tr, COR_OBJETIVO)
	# jogador
	var pj := _mundo_para_tela(_pos)
	ci.draw_circle(pj, 3.4 * vh, Color(COR_JOGADOR.r, COR_JOGADOR.g, COR_JOGADOR.b, 0.15))
	_seta(ci, pj, _rumo, 2.5 * vh, COR_JOGADOR)
	# título, norte e dicas
	UI.caixa_arredondada(ci, Rect2(2.0 * vh, 2.0 * vh, 30.0 * vh, 9.6 * vh), COR_FUNDO, 1.0 * vh)
	ci.draw_string(UI.fonte(900), Vector2(3.4 * vh, 6.8 * vh), "MAPA", HORIZONTAL_ALIGNMENT_LEFT, -1, int(4.4 * vh), UI.AMBAR)
	_texto(ci, "x %d · z %d" % [int(_pos.x), int(_pos.y)], Vector2(3.4 * vh, 9.4 * vh), int(1.9 * vh), UI.TEXTO, -1)
	var rn := Vector2(26.5 * vh, 6.8 * vh)
	ci.draw_circle(rn, 3.4 * vh, Color(0, 0, 0, 0.35))
	ci.draw_arc(rn, 3.4 * vh, 0.0, TAU, 32, Color(1, 1, 1, 0.35), maxf(1.5, 0.2 * vh), true)
	ci.draw_colored_polygon(PackedVector2Array([rn + Vector2(0, -2.6 * vh), rn + Vector2(1.0 * vh, 0.4 * vh), rn + Vector2(-1.0 * vh, 0.4 * vh)]), Color(1.0, 0.42, 0.2))
	ci.draw_colored_polygon(PackedVector2Array([rn + Vector2(0, 2.6 * vh), rn + Vector2(1.0 * vh, 0.4 * vh), rn + Vector2(-1.0 * vh, 0.4 * vh)]), Color(1, 1, 1, 0.7))
	_texto(ci, "N", rn + Vector2(-2.6 * vh, -1.9 * vh), int(2.2 * vh), Color(1.0, 0.55, 0.3))
	if _obj:
		var txt := "OBJETIVO: " + ((_obj_nome + " · ") if _obj_nome != "" else "") + _metros((_obj_pos - _pos).length())
		var w := _largura(txt, int(2.2 * vh)) + 3.0 * vh
		UI.caixa_arredondada(ci, Rect2(vs.x * 0.5 - w * 0.5, 2.0 * vh, w, 4.6 * vh), COR_FUNDO, 1.0 * vh)
		_texto(ci, txt, Vector2(vs.x * 0.5, 4.3 * vh), int(2.2 * vh), COR_OBJETIVO)
	_escala_grafica(ci, vs, vh)
	_texto(ci, "arraste para mover · pinça, rodinha ou + − para zoom · ⌖ volta para você", Vector2(vs.x * 0.5, vs.y - 3.0 * vh), int(1.9 * vh), Color(1, 1, 1, 0.6))
	for b in _botoes():
		_desenhar_botao(ci, b[0], b[1], b[2], vh)
	_soltar_textos()

func _escala_grafica(ci: CanvasItem, vs: Vector2, vh: float) -> void:
	var m := 50.0
	for v in [50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0]:
		if v / _mpp <= 18.0 * vh:
			m = v
	var w := m / _mpp
	var p := Vector2(3.0 * vh, vs.y - 4.0 * vh)
	UI.caixa_arredondada(ci, Rect2(p.x - 1.0 * vh, p.y - 4.6 * vh, w + 2.0 * vh, 5.8 * vh), COR_FUNDO, 0.8 * vh)
	ci.draw_line(p, p + Vector2(w, 0), Color.WHITE, maxf(2.0, 0.35 * vh))
	ci.draw_line(p + Vector2(0, -1.0 * vh), p + Vector2(0, 0.2 * vh), Color.WHITE, maxf(2.0, 0.3 * vh))
	ci.draw_line(p + Vector2(w, -1.0 * vh), p + Vector2(w, 0.2 * vh), Color.WHITE, maxf(2.0, 0.3 * vh))
	var txt := ("%d km" % int(m / 1000.0)) if m >= 1000.0 else ("%d m" % int(m))
	_texto(ci, txt, p + Vector2(w * 0.5, -2.4 * vh), int(1.9 * vh), Color.WHITE)

func _desenhar_botao(ci: CanvasItem, id: String, c: Vector2, r: float, vh: float) -> void:
	ci.draw_circle(c, r, Color(0.03, 0.05, 0.08, 0.72))
	ci.draw_arc(c, r, 0.0, TAU, 40, Color(UI.AMBAR.r, UI.AMBAR.g, UI.AMBAR.b, 0.9), maxf(2.0, 0.4 * vh), true)
	var s := r * 0.42
	var e := maxf(2.5, 0.5 * vh)
	var cor := Color(1, 1, 1, 0.95)
	match id:
		"fechar":
			ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), cor, e, true)
			ci.draw_line(c + Vector2(s, -s), c + Vector2(-s, s), cor, e, true)
		"mais":
			ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), cor, e)
			ci.draw_line(c + Vector2(0, -s), c + Vector2(0, s), cor, e)
		"menos":
			ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), cor, e)
		"centro":
			ci.draw_arc(c, s * 0.75, 0.0, TAU, 24, cor if not _seguir else UI.AMBAR, e * 0.8, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * s * 0.45, c + d * s * 1.15, cor, e * 0.8)

# zoom alto: ruas e prédios da área visível em vetor (nítidos), por cima da imagem
func _desenhar_vetores(ci: CanvasItem, area: Rect2) -> void:
	_montar_grades()
	var c0 := Vector2i(floori(area.position.x / CEL_GRADE), floori(area.position.y / CEL_GRADE))
	var c1 := Vector2i(floori(area.end.x / CEL_GRADE), floori(area.end.y / CEL_GRADE))
	for passo in 2:
		var cor := COR_CALCADA if passo == 0 else COR_RUA
		var extra := CALCADA if passo == 0 else 0.0
		for cx in range(c0.x, c1.x + 1):
			for cz in range(c0.y, c1.y + 1):
				var segs = _grade_ruas.get(Vector2i(cx, cz))
				if segs == null:
					continue
				var s: PackedFloat32Array = segs
				for i in range(0, s.size(), 6):
					var a := Vector2(s[i], s[i + 1])
					var b := Vector2(s[i + 2], s[i + 3])
					var hw := s[i + 4] + extra
					ci.draw_circle(a, hw, cor)
					if s[i + 5] > 0.5:
						ci.draw_circle(b, hw, cor)
					ci.draw_line(a, b, cor, hw * 2.0)
	var pr: PackedFloat32Array = cidade.predios
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var lista = _grade_predios.get(Vector2i(cx, cz))
			if lista == null:
				continue
			for i in (lista as PackedInt32Array):
				var k := i * 5
				ci.draw_rect(Rect2(pr[k] - pr[k + 2] * 0.5, pr[k + 1] - pr[k + 3] * 0.5, pr[k + 2], pr[k + 3]), _cor_predio(i, pr[k + 4]))
