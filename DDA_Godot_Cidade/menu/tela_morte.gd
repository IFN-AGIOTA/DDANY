extends CanvasLayer
# TELA DE MORTE: "VOCÊ MORREU", a causa, quanto tempo sobreviveu e os abates.
# RENASCER = começa de novo em outro ponto da cidade só com o básico (como no DayZ); tudo o que você
# carregava fica no chão, junto do corpo. MENU PRINCIPAL = volta ao menu.
# Mexa AQUI para: textos e botões da tela de morte.

signal renascer
signal menu_principal

const UI := preload("res://menu/ui.gd")

var causa := ""
var tempo_vivo := 0.0
var abates := 0
var _raiz: Control
var _a := 0.0

func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()

func _montar() -> void:
	var v := UI.vh(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.modulate.a = 0.0
	add_child(_raiz)
	var veu := ColorRect.new()
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.color = Color(0.06, 0.0, 0.0, 0.78)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(veu)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(1.6 * v))
	_raiz.add_child(col)
	var t := UI.rotulo("VOCÊ MORREU", 11.0 * v, Color(0.9, 0.12, 0.08), 900, 0.0, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var motivo: String = {"infectados": "Os infectados pegaram você.", "fome": "Morreu de fome.", "sede": "Morreu de sede.",
		"frio": "Morreu de frio.", "sangue": "Perdeu sangue demais.", "infecção": "A infecção venceu.", "queda": "A queda foi alta demais."}.get(causa, "")
	var s := int(tempo_vivo)
	var linha := "%s   Sobreviveu %d min %02d s · %d abates" % [motivo, s / 60, s % 60, abates]
	var l := UI.rotulo(linha, 3.0 * v, Color(1, 1, 1, 0.85), 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	var dica := UI.rotulo("Suas coisas ficaram no chão, onde você caiu.", 2.4 * v, Color(1, 1, 1, 0.55), 400)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(dica)
	for par in [["Renascer", true, renascer], ["Menu principal", false, menu_principal]]:
		var b := UI.BotaoMenu.new(par[0], "", par[1], 3.5, 30.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var sinal: Signal = par[2]
		b.apertado.connect(func(): sinal.emit())
		col.add_child(b)

func _process(dt: float) -> void:
	_a = minf(1.0, _a + dt * 0.8)
	_raiz.modulate.a = _a
