extends CanvasLayer
# LOGO DA PRODUTORA (0.93): a primeira coisa ao abrir o jogo. Tela preta, a logo da INFINITY STUDIO aparece devagar
# (fade in), fica um pouco e some (fade out); depois o preto se desfaz em cima do menu. Um toque/clique/tecla pula.
# Criada por main.gd (_ready), que só abre o menu quando esta tela avisa "acabou".
# Mexa AQUI para: a imagem (menu/logo_produtora.png) e os tempos.

signal acabou

const IMAGEM := preload("res://menu/logo_produtora.png")
const ENTRAR := 1.2        # segundos do fade in
const FICAR := 2.0         # segundos com a logo parada
const SAIR := 1.2          # segundos do fade out
const REVELAR := 0.6       # segundos do preto sumindo em cima do menu

var _fundo: ColorRect
var _logo: TextureRect
var _tw: Tween
var _saindo := false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fundo = ColorRect.new()
	_fundo.color = Color.BLACK
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)
	_logo = TextureRect.new()
	_logo.texture = IMAGEM
	_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate.a = 0.0
	add_child(_logo)
	_tw = create_tween()
	_tw.tween_interval(0.3)
	_tw.tween_property(_logo, "modulate:a", 1.0, ENTRAR).set_trans(Tween.TRANS_SINE)
	_tw.tween_interval(FICAR)
	_tw.tween_property(_logo, "modulate:a", 0.0, SAIR).set_trans(Tween.TRANS_SINE)
	_tw.tween_callback(_revelar)

# a logo já sumiu: avisa o main.gd (abre o menu por baixo) e desfaz o preto
func _revelar() -> void:
	if _saindo:
		return
	_saindo = true
	_logo.modulate.a = 0.0
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	acabou.emit()
	var tw := create_tween()
	tw.tween_property(_fundo, "color:a", 0.0, REVELAR)
	tw.tween_callback(queue_free)

# pular: qualquer toque, clique ou tecla
func _input(e: InputEvent) -> void:
	if _saindo:
		return
	if (e is InputEventMouseButton or e is InputEventScreenTouch or e is InputEventKey or e is InputEventJoypadButton) and e.is_pressed():
		get_viewport().set_input_as_handled()
		if _tw != null:
			_tw.kill()
		var tw := create_tween()
		tw.tween_property(_logo, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_revelar)
