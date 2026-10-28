extends CanvasLayer
# TELA DE CARREGAMENTO (0.99): aparece ao entrar no jogo (Jogar, Continuar, Multijogador) e ao Recomeçar pela pausa.
# Fundo: a última imagem da tela (o pôr do sol do menu ou o jogo) desfocada, escura e chegando bem devagar, com
# brasas subindo. Em cima: o título e o modo; embaixo: a ETAPA de verdade que está sendo montada (as da cidade vêm de
# mundo/cidade.gd etapas(), as do jogo de main.gd ETAPAS_JOGO), a barra com a porcentagem e uma DICA que troca
# sozinha (tocar na tela passa para a próxima).
# Quem usa (main.gd): abrir -> etapa(texto, peso) antes de cada parte -> terminar() (espera a vista ficar pronta,
# enche a barra e some devagar). Cada etapa espera 1 quadro, para a tela ser desenhada antes da parte pesada.
# Mexa AQUI para: a aparência, as DICAS, o tempo de cada dica e quanto tempo a vista leva para "assentar".

signal sumiu

const UI := preload("res://menu/ui.gd")
const TEMPO_DICA := 7.0                 # s em cada dica
const ENTRAR := 0.35                    # s do fade de entrada
const SAIR := 0.7                       # s do fade de saída
const QUADROS_VISTA := 6                # quadros desenhando o jogo por baixo antes de sumir (shaders, prédios perto)
const MAX_VISTA := 6.0                  # s no máximo esperando a vista

const DICAS := [
	"Agachado você faz bem menos barulho e os infectados demoram mais para te ver.",
	"Tiro na cabeça dá o TRIPLO de dano.",
	"O silenciador deixa o tiro quase 5 vezes mais baixo.",
	"Os infectados vão atrás do barulho: um tiro de fuzil é ouvido a mais de 100 m.",
	"Correndo, os infectados te ouvem a 20 m. Andando, a 7 m. Agachado, a 2,5 m.",
	"À noite eles enxergam pouco, mas a sua lanterna acesa te entrega de longe.",
	"Mordida sempre passa o vírus. Antibióticos curam a infecção das feridas e a cólera, não o vírus.",
	"Sangrando? Atadura ou trapos estancam. O soro devolve o sangue perdido.",
	"A fome zera em cerca de 1 hora de jogo e a sede em uns 40 minutos. Correr gasta mais.",
	"Chuva molha e esfria. Abaixo de 35 °C você perde vida e a mira treme.",
	"Água suja faz mal: arraste as pastilhas purificadoras em cima dela antes de beber.",
	"Tábuas com pregos barricam portas e janelas, até 3 por porta.",
	"Com um infectado caído na sua frente, EMPURRAR vira PISÃO.",
	"Com arma de fogo, MIRAR leva a arma ao rosto: a massa da mira mostra onde o tiro vai.",
	"Os hospitais são ZONAS NEUTRAS. A Mônica compra e vende; o Lucas faz trocas pelo rádio.",
	"Só uns 4% dos carros largados ainda funcionam. Gasolina se acha nas bombas dos postos.",
	"Os cartões dos bunkers aparecem nas caixas militares dos quartéis e dos postos militares dos hospitais.",
	"Lugares saqueados ganham loot novo com o tempo: prédios em uns 32 minutos, locais especiais em uns 20.",
	"Com o MARTELO você constrói a sua base. A CAMA da base vira o seu lugar de renascer.",
	"O coletor da base junta água da chuva para encher as suas garrafas.",
	"O jogo salva sozinho a cada 2 minutos e quando você pausa.",
	"Morto pelos infectados, há 1% de chance de levantar MUTADO: eles te ignoram, mas arma de fogo não serve mais.",
	"No multijogador o chat de voz é por proximidade: só quem está a até 45 m te ouve.",
	"Nem todo perigo é infectado: os Vagos, a gangue de Edy e V, também disputam Nova York.",
	"Postos, hospitais, supermercados e armazéns têm loot melhor, mas lá vale tiro entre jogadores.",
	"Itens têm estado: PERFEITO, GASTO, DANIFICADO... Fita adesiva e kit de costura consertam roupas.",
]

var modo := "MUNDO LIVRE"               # escrito embaixo do título (main.gd troca: CONTINUANDO, MULTIJOGADOR...)
var total := 1.0                        # soma dos pesos de todas as etapas (main.gd)
var feito := 0.0                        # soma dos pesos das etapas já terminadas
var texto_etapa := "Preparando"
var peso_vista := 0.0                  # peso de "Preparando a vista" (main.gd ETAPAS_JOGO)
var tempos: Array = []                  # [texto, ms] de cada etapa (aparece no console no fim; ajuda a acertar os pesos)

var _alfa := 0.0
var _saindo := false
var _peso_atual := 0.0
var _t_etapa := 0
var _barra := 0.0                       # o que a barra mostra (anda suave até "feito")
var _dica := -1
var _t_dica := 0.0
var _t := 0.0
var _brasas: Array = []                 # [x 0..1, y 0..1, velocidade, fase, tamanho]
var _raiz: Control
var _fundo: TextureRect
var _desenho: Control
var _rotulo_etapa: Label
var _rotulo_pct: Label
var _rotulo_dica: Label
var _caixa_dica: Control
var _rotulo_modo: Label

func _ready() -> void:
	layer = 60                          # por cima de tudo (menu, HUD, pausa)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dica = randi() % DICAS.size()
	for i in 46:
		_brasas.append([randf(), randf(), randf_range(0.02, 0.07), randf() * TAU, randf_range(0.12, 0.38)])
	_montar(_foto_da_tela())
	get_viewport().size_changed.connect(func(): _montar(_fundo.texture if _fundo != null else null))

# a última imagem desenhada, pequena (o desfoque fica barato e bonito)
func _foto_da_tela() -> Texture2D:
	var tex := get_viewport().get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGB8)
	var w := 192
	var h := maxi(8, int(w * float(img.get_height()) / maxf(1.0, img.get_width())))
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)

const SHADER_FUNDO := """
shader_type canvas_item;
uniform float tem_foto = 1.0;
uniform float t = 0.0;
// foto pequena desfocada (9 amostras), escurecida e puxada para o âmbar; sem foto: degradê do pôr do sol
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 1.6;
	vec3 c = vec3(0.0);
	for (int x = -1; x <= 1; x++)
		for (int y = -1; y <= 1; y++)
			c += texture(TEXTURE, UV + vec2(float(x), float(y)) * px).rgb;
	c /= 9.0;
	vec3 sem = mix(vec3(0.55, 0.22, 0.07), vec3(0.08, 0.03, 0.01), smoothstep(0.1, 0.95, UV.y));
	sem += vec3(0.35, 0.16, 0.04) * exp(-12.0 * distance(UV, vec2(0.38, 0.42)) * distance(UV, vec2(0.38, 0.42)));
	c = mix(sem, c, tem_foto);
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(vec3(l) * vec3(1.15, 0.78, 0.5), c, 0.6) * 0.62;
	// escurece embaixo (textos) e nas bordas
	c *= mix(1.0, 0.35, smoothstep(0.45, 1.0, UV.y));
	vec2 e = UV - 0.5;
	c *= 1.0 - 0.85 * smoothstep(0.3, 0.8, length(e * vec2(1.0, 1.3)));
	COLOR = vec4(c, 1.0);
}
"""

func _montar(foto: Texture2D) -> void:
	if _raiz != null:
		_raiz.queue_free()
	var v := UI.vh(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP       # o jogo por baixo não recebe toques enquanto carrega
	_raiz.gui_input.connect(_toque)
	_raiz.modulate.a = _alfa
	add_child(_raiz)
	_fundo = TextureRect.new()
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.stretch_mode = TextureRect.STRETCH_SCALE
	_fundo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fundo.texture = foto if foto != null else UI.disco()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_FUNDO
	sm.shader = sh
	sm.set_shader_parameter("tem_foto", 1.0 if foto != null else 0.0)
	_fundo.material = sm
	_raiz.add_child(_fundo)
	_desenho = _Desenho.new()
	_desenho.tela = self
	_desenho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_desenho)
	# título (canto de cima à esquerda) e o modo
	var tit := VBoxContainer.new()
	tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tit.add_theme_constant_override("separation", 0)
	tit.position = Vector2(6.0 * v, 5.0 * v)
	var d1 := UI.rotulo("DIAS DE UM", 2.6 * v, Color("#ffb866"), 900, 0.42 * 2.6 * v, true)
	tit.add_child(d1)
	var d2 := UI.titulo_degrade("APOCALIPSE", 9.0 * v, -0.01 * 9.0 * v)
	var m2 := MarginContainer.new()
	m2.add_theme_constant_override("margin_top", int(-0.14 * 9.0 * v))
	m2.add_theme_constant_override("margin_bottom", int(-0.1 * 9.0 * v))
	m2.add_child(d2)
	tit.add_child(m2)
	_rotulo_modo = UI.rotulo(modo, 2.3 * v, Color(1, 0.91, 0.82, 0.7), 800, 0.3 * 2.3 * v, true)
	tit.add_child(_rotulo_modo)
	_raiz.add_child(tit)
	# dica
	_caixa_dica = VBoxContainer.new()
	_caixa_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa_dica.add_theme_constant_override("separation", int(0.8 * v))
	var larg := minf(get_viewport().get_visible_rect().size.x * 0.55, 120.0 * v)
	_presa_embaixo(_caixa_dica, 6.0 * v, -21.0 * v, larg)
	_caixa_dica.grow_vertical = Control.GROW_DIRECTION_BEGIN      # texto maior cresce para cima
	_caixa_dica.size.x = larg
	_caixa_dica.add_child(UI.rotulo("DICA DE SOBREVIVÊNCIA", 2.0 * v, UI.AMBAR, 900, 0.3 * 2.0 * v, true))
	_rotulo_dica = UI.rotulo("", 3.1 * v, UI.TEXTO, 700)
	_rotulo_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo_dica.custom_minimum_size.x = larg
	_caixa_dica.add_child(_rotulo_dica)
	_raiz.add_child(_caixa_dica)
	# etapa e porcentagem (em cima da barra)
	_rotulo_etapa = UI.rotulo("", 3.0 * v, Color.WHITE, 800, 0.05 * 3.0 * v, true)
	_presa_embaixo(_rotulo_etapa, 10.5 * v, -9.0 * v, 100.0 * v)
	_rotulo_etapa.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_raiz.add_child(_rotulo_etapa)
	_rotulo_pct = UI.rotulo("0%", 4.2 * v, UI.AMBAR, 900, 0.05 * 4.2 * v, true)
	_rotulo_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rotulo_pct.anchor_left = 1.0
	_rotulo_pct.anchor_right = 1.0
	_rotulo_pct.anchor_top = 1.0
	_rotulo_pct.anchor_bottom = 1.0
	_rotulo_pct.offset_left = -36.0 * v
	_rotulo_pct.offset_right = -6.0 * v
	_rotulo_pct.offset_top = -9.0 * v
	_rotulo_pct.offset_bottom = -9.0 * v
	_rotulo_pct.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_raiz.add_child(_rotulo_pct)
	_mostrar_dica()
	_atualizar_textos()

# preso no canto de baixo à esquerda: "x" da esquerda, base a "y" do fundo da tela (negativo = para cima)
static func _presa_embaixo(c: Control, x: float, y: float, larg: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 0.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = x
	c.offset_right = x + larg
	c.offset_top = y
	c.offset_bottom = y

func _toque(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		_proxima_dica()

func _proxima_dica() -> void:
	_dica = (_dica + 1) % DICAS.size()
	_t_dica = 0.0
	_mostrar_dica()

func _mostrar_dica() -> void:
	if _rotulo_dica != null:
		_rotulo_dica.text = DICAS[_dica]

func _atualizar_textos() -> void:
	if _rotulo_etapa == null:
		return
	var pontos := int(_t * 2.5) % 4
	_rotulo_etapa.text = texto_etapa + ".".repeat(pontos)
	_rotulo_pct.text = "%d%%" % int(round(fracao() * 100.0))
	_rotulo_modo.text = modo

func fracao() -> float:
	return clampf(_barra / maxf(total, 0.001), 0.0, 1.0)

# ---------- quem carrega (main.gd) ----------
# começa a parte "texto" (com o peso dela); devolve depois de 1 quadro, já com a tela desenhada
func etapa(texto: String, peso: float) -> void:
	while _alfa < 1.0 and not _saindo:  # a tela termina de aparecer antes de começar o trabalho pesado
		await get_tree().process_frame
	_fechar_etapa()
	texto_etapa = texto
	_peso_atual = peso
	_t_etapa = Time.get_ticks_msec()
	_barra = feito                      # trabalho pesado não deixa animar: a barra mostra o que já foi feito
	_atualizar_textos()
	await get_tree().process_frame

func _fechar_etapa() -> void:
	if _peso_atual > 0.0 or _t_etapa > 0:
		tempos.append([texto_etapa, Time.get_ticks_msec() - _t_etapa])
	feito += _peso_atual
	_peso_atual = 0.0

# tudo montado: deixa o jogo desenhar alguns quadros por baixo (shaders, prédios e chão perto), enche a barra e some
func terminar() -> void:
	await etapa("Preparando a vista", peso_vista)
	var t0 := Time.get_ticks_msec()
	for i in QUADROS_VISTA:
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > MAX_VISTA * 1000.0:
			break
	_fechar_etapa()
	feito = total
	var linha := PackedStringArray()
	for e in tempos:
		linha.append("%s %d" % [e[0], e[1]])
	print("CARREGAMENTO (ms): ", " · ".join(linha))
	texto_etapa = "Pronto"
	var t1 := Time.get_ticks_msec()
	while _barra < total - 0.001 and Time.get_ticks_msec() - t1 < 600:
		await get_tree().process_frame
	_saindo = true
	while _alfa > 0.0:
		await get_tree().process_frame
	sumiu.emit()
	queue_free()

func _process(dt: float) -> void:
	_t += dt
	_alfa = clampf(_alfa + (-dt / SAIR if _saindo else dt / ENTRAR), 0.0, 1.0)
	if _raiz != null:
		_raiz.modulate.a = _alfa
	_barra = move_toward(_barra, feito, maxf(total, 0.001) * dt * 1.6)
	_t_dica += dt
	if _t_dica >= TEMPO_DICA:
		_proxima_dica()
	if _rotulo_dica != null:            # a dica aparece e some devagar
		_rotulo_dica.modulate.a = clampf(minf(_t_dica / 0.4, (TEMPO_DICA - _t_dica) / 0.4), 0.0, 1.0)
	if _fundo != null:                  # o fundo chega bem devagar
		var s := 1.04 + _t * 0.006
		_fundo.pivot_offset = _fundo.size * 0.5
		_fundo.scale = Vector2(s, s)
	_atualizar_textos()
	if _desenho != null:
		_desenho.queue_redraw()

# barra, girador e brasas
class _Desenho extends Control:
	const UId := preload("res://menu/ui.gd")
	var tela
	func _draw() -> void:
		var v: float = UId.vh(self)
		var tam := size
		var t: float = tela._t
		# brasas subindo
		for b in tela._brasas:
			var y: float = fposmod(b[1] - t * b[2], 1.0)
			var x: float = b[0] + sin(t * 0.7 + b[3]) * 0.012
			var a: float = smoothstep(0.0, 0.25, y) * (0.35 + 0.35 * sin(t * 3.0 + b[3]))
			draw_circle(Vector2(x * tam.x, y * tam.y), b[4] * v, Color(1.0, 0.55, 0.18, a))
		# barra
		var x0 := 6.0 * v
		var x1 := tam.x - 6.0 * v
		var y := tam.y - 7.0 * v
		var h := 0.8 * v
		draw_rect(Rect2(x0, y, x1 - x0, h), Color(1, 1, 1, 0.12))
		var f: float = tela.fracao()
		var xf := lerpf(x0, x1, f)
		UId.degrade_h(self, PackedVector2Array([Vector2(x0, y), Vector2(xf, y), Vector2(xf, y + h), Vector2(x0, y + h)]),
			UId.LARANJA_ESCURO, UId.AMBAR, x0, maxf(xf, x0 + 1.0))
		# brilho correndo na ponta da barra
		draw_circle(Vector2(xf, y + h * 0.5), h * 1.3, Color(1.0, 0.8, 0.35, 0.35 + 0.25 * sin(t * 6.0)))
		# girador (três arcos) antes do nome da etapa
		var c := Vector2(x0 + 1.8 * v, y - 4.6 * v)
		for i in 3:
			var a0 := t * 2.4 + i * TAU / 3.0
			draw_arc(c, 1.6 * v, a0, a0 + 1.3, 18, Color(1.0, 0.71, 0.0, 0.85), 0.45 * v, true)
		draw_arc(c, 0.7 * v, -t * 3.0, -t * 3.0 + 3.6, 14, Color(1, 0.91, 0.82, 0.6), 0.3 * v, true)
