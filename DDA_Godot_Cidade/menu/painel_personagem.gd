extends HBoxContainer
# 1.10 · SEU PERSONAGEM (no PERFIL: menu/tela_perfil.gd): escolher HOMEM ou MULHER, o tom da PELE, o CABELO, a BARBA
# (só homem) e a COR DO CABELO. À esquerda, o personagem do MODO LIVRE em 3D (inventario/boneco_3d.gd), girando
# devagar (arraste para girar), com o que ele está usando no jogo salvo (menu/salvamento.gd): chapéu/capacete,
# mochila, pochete, armas nas costas/coldre e a arma da mão; 1.11: e as ROUPAS 3D (camisa, calça, calçado, luvas...).
# Sem jogo salvo: o equipamento com que o jogo começa.
# Cada toque já vale: grava em Config "aparencia" e o boneco muda na hora (o do menu principal também). No jogo, o
# jogador (jogador/jogador.gd usar_sobrevivente), o boneco do inventário e a cópia que os amigos veem (rede) usam ela.
# Mexa AQUI para: o layout do painel. As listas (peles, cabelos, cores) ficam em jogador/modelo_sobrevivente.gd.

const UI := preload("res://menu/ui.gd")
const Sob := preload("res://jogador/modelo_sobrevivente.gd")
const BonecoCls := preload("res://inventario/boneco_3d.gd")
const Salvamento := preload("res://menu/salvamento.gd")
const ItemCls := preload("res://inventario/item.gd")

const PELE_BASE := Color(0.66, 0.45, 0.31)     # cor média da textura da pele (para pintar os quadradinhos)
const CABELO_BASE := 0.55                       # cinza médio da textura do cabelo

var ap := {}
var boneco                                      # inventario/boneco_3d.gd
var tem_save := false
var _inv: _InvSalvo
var _sexo: UI.Seletor
var _cabelo: UI.Passo
var _barba: UI.Seletor
var _linha_barba: Control
var _pele: _Amostras
var _cor: _Amostras
var _v := 7.0

# o boneco só precisa de "slots" e do sinal "mudou" (não dá para arrastar itens aqui)
class _InvSalvo extends RefCounted:
	signal mudou
	var slots := {}

func _ready() -> void:
	_v = UI.vh(self)
	add_theme_constant_override("separation", int(3.0 * _v))
	ap = Sob.normalizar(Config.valor("aparencia"))
	_inv = _InvSalvo.new()
	tem_save = _carregar_roupa(_inv)
	boneco = BonecoCls.new(_inv)
	boneco.name = "Boneco"
	boneco.aparencia = ap
	boneco.giro_sozinho = 0.35
	boneco.custom_minimum_size = Vector2(34.0 * _v, 62.0 * _v)
	add_child(boneco)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.custom_minimum_size.x = 76.0 * _v
	col.add_theme_constant_override("separation", int(1.0 * _v))
	add_child(col)
	col.add_child(_txt("Assim você aparece no MODO LIVRE (e para os amigos no multijogador). " + \
		("Ele está com o equipamento do seu jogo salvo" if tem_save else "Ainda sem jogo salvo: o equipamento com que o jogo começa") + \
		" (arraste o personagem para girar)."))
	col.add_child(_rot("CORPO"))
	_sexo = UI.Seletor.new([["m", "MASCULINO"], ["f", "FEMININO"]], ap["sexo"], 3.0, 6.0)
	_sexo.escolheu.connect(_trocar_sexo)
	col.add_child(_sexo)
	col.add_child(_rot("PELE"))
	var cp: Array = []
	for p in Sob.PELES:
		cp.append(Color(minf(PELE_BASE.r * p[1].r, 1.0), minf(PELE_BASE.g * p[1].g, 1.0), minf(PELE_BASE.b * p[1].b, 1.0)))
	_pele = _Amostras.new(cp, int(ap["pele"]))
	_pele.escolheu.connect(func(i): _mudar("pele", i))
	col.add_child(_pele)
	col.add_child(_rot("CABELO"))
	var ops: Array = []
	for c in Sob.CABELOS_ORDEM:
		ops.append([c, Sob.CABELOS_NOMES[c]])
	_cabelo = UI.Passo.new(ops, ap["cabelo"])
	_cabelo.escolheu.connect(func(c): _mudar("cabelo", c))
	col.add_child(_cabelo)
	col.add_child(_rot("COR DO CABELO"))
	var cc: Array = []
	for c in Sob.CORES_CABELO:
		var k: Color = c[1]
		cc.append(Color(minf(k.r * CABELO_BASE, 1.0), minf(k.g * CABELO_BASE, 1.0), minf(k.b * CABELO_BASE, 1.0)))
	_cor = _Amostras.new(cc, int(ap["cor"]))
	_cor.escolheu.connect(func(i): _mudar("cor", i))
	col.add_child(_cor)
	var lb := VBoxContainer.new()
	lb.add_theme_constant_override("separation", int(1.0 * _v))
	lb.add_child(_rot("BARBA"))
	_barba = UI.Seletor.new([[true, "COM BARBA"], [false, "SEM BARBA"]], ap["barba"], 2.8, 5.6)
	_barba.escolheu.connect(func(b): _mudar("barba", b))
	lb.add_child(_barba)
	col.add_child(lb)
	_linha_barba = lb
	_linha_barba.visible = ap["sexo"] == "m"

# roupa do jogo salvo do modo livre (user://save.json); sem save: o equipamento inicial
static func _carregar_roupa(inv) -> bool:
	var iv = Salvamento.ler().get("inventario", {})
	var sl: Dictionary = iv.get("slots", {}) if iv is Dictionary and iv.get("slots") is Dictionary else {}
	for s in sl:
		var it = ItemCls.de_dict(sl[s])
		if it != null:
			inv.slots[s] = it
	if not inv.slots.is_empty():
		return true
	for par in [["camisa", "jaqueta"], ["calca", "calca"], ["colete", "colete"], ["cinto", "pochete"], ["pes", "botina"], ["maos", "pistola"]]:
		inv.slots[par[0]] = ItemCls.novo(par[1])
	return false

func _trocar_sexo(s: String) -> void:
	var antes: Dictionary = Sob.APARENCIA_PADRAO if ap["sexo"] == "m" else Sob.APARENCIA_PADRAO_F
	var depois: Dictionary = Sob.APARENCIA_PADRAO if s == "m" else Sob.APARENCIA_PADRAO_F
	ap["sexo"] = s
	if ap["cabelo"] == antes["cabelo"]:          # o penteado padrão de um vira o padrão do outro
		ap["cabelo"] = depois["cabelo"]
	ap["barba"] = depois["barba"]
	_cabelo.definir(ap["cabelo"])
	_barba.definir(ap["barba"])
	_linha_barba.visible = s == "m"
	_gravar()

func _mudar(k: String, valor) -> void:
	ap[k] = valor
	_gravar()

func _gravar() -> void:
	ap = Sob.normalizar(ap)
	Config.definir("aparencia", ap.duplicate())
	boneco.trocar_aparencia(ap.duplicate())

func _rot(t: String) -> Label:
	return UI.rotulo(t, 2.6 * _v, UI.TITULO_SECAO, 900, 0.12 * 2.6 * _v, true)

func _txt(t: String) -> Label:
	var l := UI.rotulo(t, 2.3 * _v, Color(1, 0.91, 0.82, 0.75), 400)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 30.0 * _v
	return l

# fileira de quadradinhos de cor (pele, cor do cabelo): toque escolhe
class _Amostras extends Control:
	signal escolheu(i: int)
	var cores: Array = []
	var atual := 0
	func _init(c: Array, i: int) -> void:
		cores = c
		atual = i
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _ready() -> void:
		var v := UI.vh(self)
		custom_minimum_size = Vector2(cores.size() * 7.4 * v, 6.4 * v)
	func _lado() -> float:
		return minf(size.y, size.x / maxf(cores.size(), 1) - 1.2 * UI.vh(self))
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			var passo := _lado() + 1.2 * UI.vh(self)
			var i := int(e.position.x / passo)
			if i >= 0 and i < cores.size():
				accept_event()
				if i != atual:
					atual = i
					queue_redraw()
					UI.Sons.ui("alternar")
					escolheu.emit(i)
	func _draw() -> void:
		var v := UI.vh(self)
		var l := _lado()
		for i in cores.size():
			var r := Rect2(i * (l + 1.2 * v), (size.y - l) * 0.5, l, l)
			UI.caixa_arredondada(self, r, cores[i], 0.8 * v)
			if i == atual:
				UI.caixa_arredondada(self, r.grow(0.35 * v), UI.LARANJA, 1.0 * v, false, 0.5 * v)
