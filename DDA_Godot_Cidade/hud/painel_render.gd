extends CanvasLayer
# PAINEL DE DEPURAÇÃO DA RENDERIZAÇÃO (1.23 · estudos/ESTUDO_AAA.md 1.15): liga/desliga com F3 (no celular, o comando
# /render do modo desenvolvedor). Só existe enquanto está aberto: fechado, não custa nada (main.gd cria e apaga).
# Mostra, 4 vezes por segundo:
#   - FPS, tempo do quadro, do processo e da física
#   - desenho: chamadas, objetos e triângulos do quadro (contadores da própria Godot)
#   - memória: vídeo, texturas, malhas e processador
#   - chunks (mundo/chunks.gd): carregados, à vista, fora da câmera (escondidos), na fila; nós na cena; quanto tempo a
#     camada de visibilidade e a carga gastaram
#   - oclusão: quantos objetos a oclusão está escondendo agora (a cada 3 s, UM quadro sem oclusão para comparar)
#   - árvores (mundo/arvores.gd): grupos, desenhos e instâncias, e o tempo de refazer as listas
#   - a GRADE dos chunks em volta da câmera: verde = à vista, cinza = fora da câmera (escondido), amarelo = na fila,
#     escuro = não carregado; o traço branco é para onde a câmera olha
# F4 (com o painel aberto) liga/desliga a camada de visibilidade dos chunks, para comparar na hora.
# Mexa AQUI para: o que aparece no painel e as cores da grade.

var main = null                     # main.gd
var _rotulo: Label
var _grade: Control
var _t := 0.0
var _t_ocl := 0.0
var _ocl_passo := 0                 # 0 = parado; 1..4 = medindo a oclusão
var _ocl_ob_sem := 0
var ocl_escondidos := -1            # objetos que a oclusão esconde (última medida; -1 = ainda não mediu)

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0, 0, 0, 0.62)
	est.set_content_margin_all(8)
	fundo.add_theme_stylebox_override("panel", est)
	fundo.position = Vector2(8, 8)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	fundo.add_child(caixa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 13)
	_rotulo.add_theme_color_override("font_color", Color(0.92, 0.96, 0.9))
	caixa.add_child(_rotulo)
	_grade = Control.new()
	_grade.custom_minimum_size = Vector2(170, 170)
	_grade.draw.connect(_desenhar_grade)
	caixa.add_child(_grade)
	_atualizar()

func _exit_tree() -> void:
	if _ocl_passo > 0:
		RenderingServer.viewport_set_use_occlusion_culling(get_viewport().get_viewport_rid(), _ocl_ligada())

# a opção "Ocultar o que está atrás" (menu/aplicar_opcoes.gd põe na janela do jogo)
func _ocl_ligada() -> bool:
	return get_viewport().use_occlusion_culling

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F4:
		var ch = _chunks()
		if ch != null:
			ch.camada_visibilidade = not ch.camada_visibilidade
			_atualizar()

func _chunks():
	return main.get("chunks") if main != null else null

func _process(dt: float) -> void:
	_medir_oclusao(dt)
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.25
	_atualizar()

# a cada 3 s: um quadro sem oclusão e um com, para saber quantos objetos ela está escondendo
func _medir_oclusao(dt: float) -> void:
	var vp := get_viewport().get_viewport_rid()
	if _ocl_passo == 0:
		_t_ocl -= dt
		if _t_ocl <= 0.0 and _ocl_ligada():
			_t_ocl = 3.0
			RenderingServer.viewport_set_use_occlusion_culling(vp, false)
			_ocl_passo = 1
		return
	_ocl_passo += 1
	if _ocl_passo == 3:
		_ocl_ob_sem = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		RenderingServer.viewport_set_use_occlusion_culling(vp, true)
	elif _ocl_passo >= 5:
		ocl_escondidos = maxi(0, _ocl_ob_sem - int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		_ocl_passo = 0

static func _mb(v: float) -> String:
	return "%.0f MB" % (v / 1048576.0)

func _atualizar() -> void:
	var t := PackedStringArray()
	t.append("RENDERIZAÇÃO  (F3 fecha · F4 camada de visibilidade)")
	t.append("FPS %d · processo %.1f ms · física %.1f ms" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	t.append("Desenho: %d chamadas · %d objetos · %.0f mil triângulos" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0])
	t.append("Memória: vídeo %s (texturas %s, malhas %s) · processador %s" % [_mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		_mb(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)), _mb(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		_mb(Performance.get_monitor(Performance.MEMORY_STATIC))])
	var ch = _chunks()
	if ch != null and ch.has_method("estatisticas"):
		var e: Dictionary = ch.estatisticas()
		t.append("Chunks (raio %d): %d carregados · %d à vista · %d fora da câmera · fila %d" % [ch.raio, e["chunks_carregados"], e["visiveis"], e["fora_da_camera"], e["fila"]])
		t.append("Nós dos chunks na cena: %d de %d (à vista %d) · sempre na cena %d" % [e["nos_na_cena"], e["nos_total"], e["nos_visiveis"], e["sempre"]])
		t.append("Visibilidade: %.2f ms (pior %.2f) · carga pior %.2f ms · camada %s" % [e["us_vis"] / 1000.0, e["us_vis_maior"] / 1000.0,
			e["us_carga_maior"] / 1000.0, "LIGADA" if e["camada"] else "desligada (F4)"])
	t.append("Oclusão: %s" % (("escondendo %d objetos" % ocl_escondidos) if ocl_escondidos >= 0 else "medindo...") if _ocl_ligada() else "desligada")
	var cid = main.get("cidade") if main != null else null
	var arv = cid.get("arvores") if cid != null else null
	if arv != null and is_instance_valid(arv) and arv.has_method("desenhos_ativos"):
		t.append("Árvores: %d grupos com algo · %d desenhos · %d instâncias · %.2f ms neste quadro (pior %.2f)" % [arv.grupos_ativos,
			arv.desenhos_ativos(), arv.instancias, arv.us_quadro / 1000.0, arv.us_quadro_maior / 1000.0])
	_rotulo.text = "\n".join(t)
	_grade.queue_redraw()

func _desenhar_grade() -> void:
	var ch = _chunks()
	var tam := _grade.size
	_grade.draw_rect(Rect2(Vector2.ZERO, tam), Color(0.05, 0.06, 0.05, 0.8))
	if ch == null or not ch.has_method("chunk_visivel"):
		return
	var r: int = ch.raio + ch.FOLGA
	var n := r * 2 + 1
	var cel := minf(tam.x, tam.y) / n
	var c: Vector2i = ch._centro
	var na_fila := {}
	for it in ch._fila:
		na_fila[Vector2i(it[0].x, it[0].y)] = true
	var carregado := {}
	for u in ch._carregados:
		carregado[Vector2i(u.x, u.y)] = true
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var k := c + Vector2i(dx, dz)
			var cor := Color(0.12, 0.13, 0.12)
			if na_fila.has(k):
				cor = Color(0.95, 0.8, 0.2)
			elif carregado.has(k):
				cor = Color(0.25, 0.75, 0.3) if ch.chunk_visivel(k) else Color(0.42, 0.44, 0.42)
			_grade.draw_rect(Rect2(Vector2(dx + r, dz + r) * cel + Vector2.ONE, Vector2.ONE * (cel - 2.0)), cor)
	var meio := Vector2(r + 0.5, r + 0.5) * cel
	_grade.draw_rect(Rect2(Vector2(r, r) * cel, Vector2.ONE * cel), Color.WHITE, false, 2.0)
	if ch._dir != Vector2.ZERO:
		_grade.draw_line(meio, meio + ch._dir * cel * 2.5, Color.WHITE, 2.0)
