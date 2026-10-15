extends CanvasLayer
# HISTÓRIA · ATO 1 (porte do HTML v1.1.27, adaptado para a pé). Menu principal › "História · Ato 1".
#   Prólogo (tela preta) -> CAPÍTULO 1 · A Última Corrida: à noite, cidade ainda inteira (sem carros largados,
#   sem Vagos), corrida contra o relógio pelos pontos de controle até a linha "A Morte do Medo" -> fim da Parte 1.
#   -> INTERLÚDIO · O Colapso (provisório, até a Parte 2 ser escrita): a cidade cai, os Vagos aparecem e o
#   objetivo vira sobreviver e chegar à base militar do aeroporto.
# Estrutura: a história é uma lista de ETAPAS; cada etapa tem um "começo" (função) e o que precisa acontecer
# para passar à próxima. Falas: dizer([[quem, texto], ...], depois). Títulos: titulo(grande, pequeno, depois).
# Objetivo no mapa/bússola: mapa.definir_objetivo(pos, nome).
# Mexa AQUI para: falas (FALAS), ordem das etapas, pontos da corrida e tempos.

signal etapa_mudou(etapa: String)

const FALAS := {
	"prologo": ["No começo, ninguém sabia o que estava acontecendo.", "Não havia sirenes. Não havia alertas nas telas. Ninguém dizendo “corram”.",
		"Foi assim que o mundo começou a cair — quieto."],
	"pre": [["DOMINIC", "Vamos ver se você consegue me acompanhar hoje."], ["GREG", "Não vou te dar essa vitória fácil, amigo."],
		["", "Liberty City arde como brasa no asfalto molhado. Seu objetivo: cruzar a cidade correndo e passar a linha chamada “A Morte do Medo”."]],
	"pos": [["GREG", "Quase te peguei dessa vez!"], ["DOMINIC", "Você está melhorando, mas ainda precisa de mais prática."],
		["", "Era a última corrida. Ninguém ali sabia ainda."]],
	# INTERLÚDIO PROVISÓRIO (a Parte 2 — o bar e as notícias — ainda vai ser escrita)
	"colapso": ["Semanas depois.", "As ruas que vocês atravessavam correndo agora estão paradas. Carros abandonados. Prédios queimados.",
		"Os que ficaram doentes não morreram. Eles vagam. Por isso as pessoas começaram a chamá-los de Vagos.",
		"No rádio, uma voz repete a mesma coisa: “Abrigo na base militar do aeroporto”."],
	"sobreviver": [["", "Você precisa de comida, água e algo para se defender. Procure dentro das casas, lojas e carros."]],
	"base": [["", "Tem o suficiente para a viagem. Siga para a base militar do aeroporto (marcada no mapa)."]],
	"fim_ato": [["", "Os portões estão fechados. Do outro lado, ninguém responde."], ["", "Seja lá o que tenha acontecido aqui... você está sozinho agora."]],
}
const LARGADA := Vector2(-1350.0, 512.0)     # Algonquin, como no HTML
const N_PONTOS := 6
const PASSO_CORRIDA := 230.0                 # metros entre os pontos de controle
const RAIO_PONTO := 9.0
const MILBASE := Vector2(6230.0, 690.0)

var main = null
var etapa := ""                  # "", "prologo", "corrida", "pos", "colapso", "sobreviver", "base", "livre"
var ativa := false
var _fila: Array = []
var _depois: Callable = Callable()
var _digitando := 0.0
var _texto := ""
var _cheio := false
var _ui: Control
var _caixa: Panel
var _quem: Label
var _fala: Label
var _tela_preta: ColorRect
var _titulo: Label
var _sub: Label
var _obj: Label
var _toast: Label
var _toast_t := 0.0
var _anel: MeshInstance3D
var _pontos: Array[Vector2] = []
var _ponto := 0
var _tempo := 0.0
var _limite := 0.0
var _correndo := false
var _t_check := 0.0
var _escondeu := false

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_ui()

# ---------- começo ----------
func iniciar(m) -> void:
	main = m
	ativa = true
	_cidade_inteira(true)
	if main.clima != null:
		main.clima.definir_hora(20.6)
		main.clima.forcar_tempo("limpo", true)
		main.clima.parado = true
	_ir("prologo")

func _ir(e: String) -> void:
	etapa = e
	etapa_mudou.emit(e)
	match e:
		"prologo":
			_cheio = true
			dizer(FALAS["prologo"], func():
				_cheio = false
				titulo("CAPÍTULO 1", "A Última Corrida", func():
					_preparar_corrida()
					dizer(FALAS["pre"], func(): _largar())))
		"pos":
			_mostrar_toast("A MORTE DO MEDO", "linha de chegada")
			await get_tree().create_timer(1.8, true, false, true).timeout
			dizer(FALAS["pos"], func():
				titulo("FIM DA PARTE 1", "Continua: o bar e as notícias… (Parte 2)", func(): _ir("colapso")))
		"colapso":
			_cheio = true
			dizer(FALAS["colapso"], func():
				_cheio = false
				_colapso()
				titulo("INTERLÚDIO", "O Colapso", func(): _ir("sobreviver")))
		"sobreviver":
			if main.mapa != null:
				main.mapa.limpar_objetivo()
			_obj_texto("Encontre comida, água e uma arma")
			dizer(FALAS["sobreviver"])
		"base":
			if main.mapa != null:
				main.mapa.definir_objetivo(MILBASE, "BASE MILITAR")
			_obj_texto("Chegue à base militar do aeroporto")
			dizer(FALAS["base"])
		"fim":
			_obj_texto("")
			if main.mapa != null:
				main.mapa.limpar_objetivo()
			dizer(FALAS["fim_ato"], func():
				titulo("FIM DO ATO 1", "O mundo continua aberto. Sobreviva.", func(): _ir("livre")))
		"livre":
			ativa = false
			_obj_texto("")

# cidade de antes do colapso: sem carros largados, sem entulho, sem Vagos
func _cidade_inteira(inteira: bool) -> void:
	var cid = main.cidade
	for d in cid.detalhes_abandono:
		if is_instance_valid(d):
			d.visible = not inteira
	if cid.abandono != null:
		main.mundo.configurar_obstaculos(PackedFloat32Array() if inteira else cid.abandono.obstaculos)
	var v = main.get("vagos")
	if v != null:
		v.ativo = not inteira

func _colapso() -> void:
	_cidade_inteira(false)
	if main.clima != null:
		main.clima.parado = false
		main.clima.definir_hora(7.5)
		main.clima.forcar_tempo("nublado", true)
	# começa de novo, só com o básico, perto da largada
	var j = main.jogador
	j.inventario.esvaziar()
	j.inventario.equipamento_renascer()
	var p := _rua_perto(LARGADA + Vector2(260.0, 180.0))
	main.mundo.forcar(p)
	j.teleportar(Vector3(p.x, main.mundo.altura(p.x, p.y) + 0.1, p.y), randf() * TAU)
	_mostrar_toast("O COLAPSO", "a cidade não é mais a mesma")

# ---------- corrida (Capítulo 1) ----------
func _preparar_corrida() -> void:
	var cid = main.cidade
	_pontos.clear()
	var p := _rua_perto(LARGADA)
	var dir := Vector2(1.0, -0.35).normalized()      # rumo ao leste/norte, como no HTML (Algonquin -> Broker)
	var j = main.jogador
	main.mundo.forcar(p)
	j.teleportar(Vector3(p.x, main.mundo.altura(p.x, p.y) + 0.1, p.y), atan2(-dir.x, -dir.y))
	var atual := p
	for k in N_PONTOS:
		var alvo := _rua_perto(atual + dir * PASSO_CORRIDA)
		if alvo.distance_to(atual) < 60.0:
			alvo = _rua_perto(atual + dir.rotated(0.6) * PASSO_CORRIDA)
		_pontos.append(alvo)
		dir = (alvo - atual).normalized().rotated(randf_range(-0.35, 0.35))
		atual = alvo
	var total := 0.0
	var ant := p
	for q in _pontos:
		total += ant.distance_to(q) * 1.25         # as ruas não são em linha reta
		ant = q
	_limite = total / 6.0 + 25.0
	_ponto = 0
	_tempo = 0.0
	if _anel == null:
		_anel = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = RAIO_PONTO
		cm.bottom_radius = RAIO_PONTO
		cm.height = 160.0
		cm.cap_top = false
		cm.cap_bottom = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.7, 0.0, 0.42)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_fog = true
		mat.no_depth_test = false
		cm.material = mat
		_anel.mesh = cm
		_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.jogo.add_child(_anel)
	_anel.visible = false

# rua mais perto de p (máscara de ruas da cidade, células de 20 m)
func _rua_perto(p: Vector2) -> Vector2:
	var cid = main.cidade
	var c0 := int((p.x + cid.WORLD.x) / cid.CELL)
	var l0 := int((p.y + cid.WORLD.y) / cid.CELL)
	for r in 40:
		for dl in range(-r, r + 1):
			for dc in range(-r, r + 1):
				if maxi(absi(dl), absi(dc)) != r:
					continue
				var c := c0 + dc
				var l := l0 + dl
				if c >= 0 and c < cid.W and l >= 0 and l < cid.H and cid.road[l * cid.W + c] == 1:
					return Vector2((c + 0.5) * cid.CELL - cid.WORLD.x, (l + 0.5) * cid.CELL - cid.WORLD.y)
	return p

func _largar() -> void:
	etapa = "corrida"
	_correndo = true
	_tempo = 0.0
	_ponto = 0
	_atualizar_ponto()
	_mostrar_toast("VAI!", "%d pontos · %d s" % [N_PONTOS, int(_limite)])

func _atualizar_ponto() -> void:
	var q := _pontos[_ponto]
	_anel.global_position = Vector3(q.x, 80.0, q.y)
	_anel.visible = true
	if main.mapa != null:
		main.mapa.definir_objetivo(q, "PONTO %d" % (_ponto + 1) if _ponto < N_PONTOS - 1 else "A MORTE DO MEDO")

func _process(dt: float) -> void:
	if main != null and main.controles != null and is_instance_valid(main.controles):
		var cena := _caixa.visible or _titulo.visible
		if cena != _escondeu:
			_escondeu = cena
			main.controles.visible = not cena
	_toast_t -= dt
	_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	_processar_fala(dt)
	if main == null or main.jogador == null or not is_instance_valid(main.jogador) or get_tree().paused:
		return
	var j = main.jogador
	var p := Vector2(j.global_position.x, j.global_position.z)
	if _correndo:
		if main.clima != null:
			main.clima.definir_hora(20.6)          # a corrida é à noite
		_tempo += dt
		var resta := maxf(0.0, _limite - _tempo)
		_obj_texto("%d/%d · %d s" % [_ponto + 1, N_PONTOS, ceili(resta)])
		if p.distance_to(_pontos[_ponto]) < RAIO_PONTO + 2.0:
			_ponto += 1
			_limite += 6.0
			if _ponto >= N_PONTOS:
				_correndo = false
				_anel.visible = false
				_obj_texto("")
				if main.mapa != null:
					main.mapa.limpar_objetivo()
				_ir("pos")
				return
			_mostrar_toast("PONTO %d/%d" % [_ponto, N_PONTOS], "+6 s")
			_atualizar_ponto()
		elif resta <= 0.0:
			_correndo = false
			_anel.visible = false
			_mostrar_toast("TEMPO ESGOTADO", "tente de novo")
			await get_tree().create_timer(1.9).timeout
			_preparar_corrida()
			_largar()
		return
	_t_check -= dt
	if _t_check > 0.0:
		return
	_t_check = 0.5
	if etapa == "sobreviver" and _tem_o_basico():
		_ir("base")
	elif etapa == "base" and p.distance_to(MILBASE) < 120.0:
		_ir("fim")

func _tem_o_basico() -> bool:
	var inv = main.jogador.inventario
	var comida := false
	var agua := false
	var arma := false
	var lista: Array = []
	for s in inv.slots:
		if inv.slots[s] != null:
			lista.append(inv.slots[s])
	for g in inv.grades_do_jogador():
		lista.append_array(g.itens)
	for it in lista:
		var cat: String = it.def().get("cat", "")
		comida = comida or cat == "comida"
		agua = agua or cat == "bebida"
		arma = arma or it.eh_arma()
	return comida and agua and arma

# ---------- falas e títulos ----------
func dizer(linhas: Array, depois := Callable()) -> void:
	_fila.clear()
	for l in linhas:
		_fila.append(l if l is Array else ["", l])
	_depois = depois
	get_tree().paused = true
	_proxima()

func _proxima() -> void:
	if _digitando > 0.0 and _digitando < _texto.length():
		_digitando = _texto.length()                # toque durante a digitação: mostra tudo
		return
	if _fila.is_empty():
		_caixa.visible = false
		_tela_preta.visible = false
		get_tree().paused = false
		var d := _depois
		_depois = Callable()
		if d.is_valid():
			d.call()
		return
	var l: Array = _fila.pop_front()
	_quem.text = l[0]
	_texto = l[1]
	_digitando = 0.001
	_fala.text = ""
	_caixa.visible = true
	_tela_preta.visible = _cheio and l[0] == ""
	_ajustar_caixa()

func _processar_fala(dt: float) -> void:
	if _digitando <= 0.0 or not _caixa.visible:
		return
	_digitando = minf(_digitando + dt * 45.0, float(_texto.length()))
	_fala.text = _texto.substr(0, int(_digitando))

func titulo(grande: String, pequeno: String, depois := Callable()) -> void:
	get_tree().paused = true
	_tela_preta.visible = true
	_titulo.text = grande
	_sub.text = pequeno
	_titulo.visible = true
	_sub.visible = true
	await get_tree().create_timer(2.8, true, false, true).timeout
	_titulo.visible = false
	_sub.visible = false
	_tela_preta.visible = false
	get_tree().paused = false
	if depois.is_valid():
		depois.call()

func _mostrar_toast(t: String, sub: String) -> void:
	_toast.text = t + "\n" + sub
	_toast_t = 2.2

func _obj_texto(t: String) -> void:
	_obj.text = t
	_obj.visible = t != ""

func _input(e: InputEvent) -> void:
	if not _caixa.visible:
		return
	var tocar := false
	if e is InputEventScreenTouch and e.pressed:
		tocar = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tocar = true
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_SPACE, KEY_E, KEY_KP_ENTER]:
		tocar = true
	if tocar:
		get_viewport().set_input_as_handled()
		_proxima()

# ---------- salvar ----------
func salvar() -> Dictionary:
	return {"etapa": etapa}

func carregar(d: Dictionary) -> void:
	var e: String = d.get("etapa", "")
	if e == "" or e == "livre":
		etapa = e
		return
	ativa = true
	if e in ["prologo", "corrida", "pos"]:
		iniciar(main)                                # o capítulo 1 recomeça do início
	elif e == "colapso" or e == "sobreviver":
		_ir("sobreviver")
	else:
		_ir(e)

# ---------- interface ----------
func _montar_ui() -> void:
	var v := get_viewport().get_visible_rect().size.y / 100.0
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_tela_preta = ColorRect.new()
	_tela_preta.color = Color(0, 0, 0, 1.0)
	_tela_preta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela_preta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela_preta.visible = false
	_ui.add_child(_tela_preta)
	_titulo = _rotulo(9.0 * v, Color(1.0, 0.72, 0.2))
	_titulo.set_anchors_preset(Control.PRESET_CENTER)
	_titulo.position.y -= 6.0 * v
	_sub = _rotulo(3.4 * v, Color(1, 1, 1, 0.8))
	_sub.set_anchors_preset(Control.PRESET_CENTER)
	_sub.position.y += 4.0 * v
	for l in [_titulo, _sub]:
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.grow_vertical = Control.GROW_DIRECTION_BOTH
		l.visible = false
		_ui.add_child(l)
	_caixa = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.03, 0.82)
	sb.border_color = Color(1.0, 0.6, 0.2, 0.5)
	sb.border_width_top = 2
	sb.set_corner_radius_all(4)
	_caixa.add_theme_stylebox_override("panel", sb)
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.visible = false
	_ui.add_child(_caixa)
	_quem = _rotulo(3.0 * v, Color(1.0, 0.72, 0.2))
	_quem.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_caixa.add_child(_quem)
	_fala = _rotulo(3.3 * v, Color(1, 1, 1, 0.95))
	_fala.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caixa.add_child(_fala)
	var dica := _rotulo(2.0 * v, Color(1, 1, 1, 0.45))
	dica.text = "toque para continuar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dica.name = "Dica"
	_caixa.add_child(dica)
	_obj = _rotulo(3.0 * v, Color(1.0, 0.8, 0.3))
	_obj.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_obj.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_obj.position.y = 15.0 * v
	_obj.visible = false
	_ui.add_child(_obj)
	_toast = _rotulo(5.0 * v, Color.WHITE)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast.position.y -= 18.0 * v
	_toast.modulate.a = 0.0
	_ui.add_child(_toast)

func _ajustar_caixa() -> void:
	var vs := get_viewport().get_visible_rect().size
	var v := vs.y / 100.0
	if _tela_preta.visible:
		_caixa.position = Vector2(vs.x * 0.15, vs.y * 0.38)
		_caixa.size = Vector2(vs.x * 0.7, 24.0 * v)
	else:
		_caixa.position = Vector2(vs.x * 0.12, vs.y - 27.0 * v)
		_caixa.size = Vector2(vs.x * 0.76, 22.0 * v)
	_quem.position = Vector2(2.5 * v, 1.5 * v)
	_quem.size = Vector2(_caixa.size.x - 5.0 * v, 4.0 * v)
	_fala.position = Vector2(2.5 * v, (5.5 if _quem.text != "" else 2.5) * v)
	_fala.size = Vector2(_caixa.size.x - 5.0 * v, 13.0 * v)
	var dica: Label = _caixa.get_node("Dica")
	dica.position = Vector2(2.5 * v, _caixa.size.y - 4.0 * v)
	dica.size = Vector2(_caixa.size.x - 5.0 * v, 3.0 * v)

func _rotulo(tam: float, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", int(tam))
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
