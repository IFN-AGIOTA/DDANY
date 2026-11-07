extends CanvasLayer
# AVISO DE CONVITE: um amigo te CHAMOU para a sala dele (rede/conta.gd: sinal chamado). Aparece por cima de
# tudo (menu ou jogo sozinho), com o ícone e o nome de quem chamou, quantos estão na sala e uma barra de 30 s.
#   ENTRAR    -> responde "aceitou" ao host e vai para a sala (main.gd: _aceitar_chamado)
#   AGORA NÃO -> responde "recusou" (o host vê "recusou")
# Sem resposta em 30 s some sozinho (o host pode chamar de novo).
# Mexa AQUI para: tempo do aviso, textos e posição.

signal aceitou(convite: Dictionary)

const UI := preload("res://menu/ui.gd")
const AvatarCls := preload("res://menu/avatar.gd")
const DURA := 30.0

var convite := {}
var _t := DURA
var _barra: ColorRect
var _painel: PanelContainer

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var v := UI.vh(self)
	_painel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.04, 0.015, 0.97)
	sb.border_color = Color("#ff8a35")
	sb.set_border_width_all(int(maxf(2.0, 0.35 * v)))
	sb.set_corner_radius_all(int(1.6 * v))
	sb.content_margin_left = 2.0 * v
	sb.content_margin_right = 2.0 * v
	sb.content_margin_top = 1.6 * v
	sb.content_margin_bottom = 1.6 * v
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = int(2.0 * v)
	_painel.add_theme_stylebox_override("panel", sb)
	_painel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_painel.offset_left = -48.0 * v
	_painel.offset_right = 48.0 * v
	_painel.offset_top = 3.0 * v
	add_child(_painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(1.0 * v))
	_painel.add_child(col)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(1.8 * v))
	col.add_child(h)
	h.add_child(AvatarCls.new(int(convite.get("avatar", 0)), 10.0 * v))
	var tx := VBoxContainer.new()
	tx.add_theme_constant_override("separation", 0)
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tx)
	tx.add_child(UI.rotulo("%s te chamou para jogar!" % convite.get("nome", "?"), 3.6 * v, Color.WHITE, 900, 0.0, true))
	tx.add_child(UI.rotulo("Sala com %d/%d jogadores%s" % [int(convite.get("n", 1)), Rede.MAX_JOGADORES, " · já começou" if convite.get("comecou", false) else ""], 2.5 * v, Color(1, 0.91, 0.82, 0.8), 400))
	if get_tree().current_scene != null and get_tree().current_scene.get("jogo") != null:
		tx.add_child(UI.rotulo("Seu jogo sozinho fica salvo.", 2.2 * v, UI.AMBAR, 700))
	var bs := HBoxContainer.new()
	bs.add_theme_constant_override("separation", int(1.4 * v))
	bs.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(bs)
	var bn := UI.BotaoMenu.new("Agora não", "", false, 3.0, 16.0)
	bn.apertado.connect(func(): _responder(false))
	bs.add_child(bn)
	var be := UI.BotaoMenu.new("ENTRAR", "", true, 3.4, 18.0)
	be.apertado.connect(func(): _responder(true))
	bs.add_child(be)
	_barra = ColorRect.new()
	_barra.color = Color("#ff8a35")
	_barra.custom_minimum_size = Vector2(0, 0.6 * v)
	col.add_child(_barra)
	# entra deslizando de cima
	_painel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_painel, "modulate:a", 1.0, 0.25)

func _process(dt: float) -> void:
	_t -= dt
	if _barra != null:
		_barra.scale.x = clampf(_t / DURA, 0.0, 1.0)
	if _t <= 0.0:
		queue_free()

func _responder(sim: bool) -> void:
	Conta.responder(convite, sim)
	if sim:
		aceitou.emit(convite)
	queue_free()
