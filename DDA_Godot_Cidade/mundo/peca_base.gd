extends Node3D
# PEÇA DA BASE (0.90) · uma coisa construída pelo jogador (mundo/construcao.gd cria, guarda e manda pela rede).
# Tipos (números em construcao.gd PECAS): PAREDE de tábuas · PAREDE COM PORTA (porta de verdade, mundo/porta.gd:
# abre, fecha, barrica) · BARRICADA BAIXA (os infectados tombam por cima, como na cerca do Project Zomboid) ·
# CAIXOTE (guarda itens; a grade fica no loot: vai no jogo salvo e na rede) · CAMA (você renasce nela) ·
# COLETOR DE CHUVA (junta água limpa na chuva; PEGAR enche uma garrafa vazia).
# Os infectados batem nela (inimigos/vago.gd) até quebrar. A origem fica no chão, no meio da peça; -Z = frente.
# Mexa AQUI para: o desenho de cada peça e a colisão.

const PortaCls := preload("res://mundo/porta.gd")
const CaixaMundo := preload("res://inventario/caixa_mundo.gd")
const Sons := preload("res://audio/sons.gd")

const MADEIRA := Color(0.56, 0.42, 0.26)
const MADEIRA_ESCURA := Color(0.4, 0.29, 0.17)
const AGUA_MAX := 20

var id := ""
var tipo := "parede"
var tam := Vector3(2.0, 2.4, 0.16)
var vida := 100.0
var vida_max := 100.0
var agua := 0                          # coletor: goles guardados
var fantasma := false                  # só o desenho (a peça que você está pondo): sem colisão e transparente
var mat_fantasma: Material = null
var gerente = null                     # mundo/construcao.gd
var porta = null                       # PAREDE COM PORTA: a porta (mundo/porta.gd)
var caixa = null                       # CAIXOTE: o contêiner (inventario/caixa_mundo.gd)

var _corpo: StaticBody3D = null
static var _malhas := {}
static var _mats := {}

static func _mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats[k] = m
	return _mats[k]

static func _malha(t: Vector3) -> BoxMesh:
	var k := str(t.snapped(Vector3.ONE * 0.01))
	if not _malhas.has(k):
		var b := BoxMesh.new()
		b.size = t
		_malhas[k] = b
	return _malhas[k]

func _ready() -> void:
	add_to_group("pecas_base")
	if not fantasma:
		_corpo = StaticBody3D.new()
		_corpo.collision_layer = 1
		_corpo.collision_mask = 0
		add_child(_corpo)
	match tipo:
		"parede":
			_tabuas_parede(-tam.x * 0.5, tam.x * 0.5, tam.y)
			_col(Vector3(0, tam.y * 0.5, 0), Vector3(tam.x, tam.y, tam.z))
		"porta":
			var vao := 1.1
			var lado := (tam.x - vao) * 0.5
			_tabuas_parede(-tam.x * 0.5, -vao * 0.5, tam.y)
			_tabuas_parede(vao * 0.5, tam.x * 0.5, tam.y)
			_caixa(Vector3(0, 2.25, 0), Vector3(vao + 0.1, 0.3, tam.z), MADEIRA_ESCURA)       # verga
			_col(Vector3(-(vao + lado) * 0.5, tam.y * 0.5, 0), Vector3(lado, tam.y, tam.z))
			_col(Vector3((vao + lado) * 0.5, tam.y * 0.5, 0), Vector3(lado, tam.y, tam.z))
			_col(Vector3(0, 2.25, 0), Vector3(vao, 0.3, tam.z))
			if not fantasma:
				porta = PortaCls.new()
				porta.id = "c" + id
				porta.largura = vao - 0.04
				porta.altura = 2.08
				porta.parede = tam.z
				porta.cor = MADEIRA_ESCURA
				if gerente != null and gerente.loot != null and gerente.loot.portas.has(porta.id):
					porta.aplicar(gerente.loot.portas[porta.id])
				add_child(porta)
		"cerca":
			for k in 3:
				_caixa(Vector3(0, 0.25 + k * 0.3, 0), Vector3(tam.x, 0.2, 0.05), MADEIRA * (0.85 + 0.05 * k))
			for x in [-tam.x * 0.5 + 0.06, tam.x * 0.5 - 0.06]:
				_caixa(Vector3(x, tam.y * 0.5, 0.06), Vector3(0.1, tam.y, 0.1), MADEIRA_ESCURA)
			_col(Vector3(0, tam.y * 0.5, 0), Vector3(tam.x, tam.y, tam.z))
		"caixa":
			if fantasma:
				_caixa(Vector3(0, tam.y * 0.5, 0), tam, MADEIRA)
			else:
				caixa = CaixaMundo.new()
				caixa.nome = "CAIXOTE DA BASE"
				caixa.tamanho = Vector2i(8, 6)
				caixa.medidas = tam
				caixa.modelo = ""
				caixa.cor = MADEIRA
				caixa.id_loot = "b" + id
				if gerente != null and gerente.loot != null:
					caixa.grade = gerente.loot.grade("b" + id, "nada", "CAIXOTE DA BASE", Vector2i(8, 6), 1.0)
				add_child(caixa)
		"cama":
			_caixa(Vector3(0, 0.15, 0), Vector3(tam.x, 0.3, tam.z), MADEIRA_ESCURA)          # estrado
			_caixa(Vector3(0, 0.36, 0.05), Vector3(tam.x - 0.12, 0.12, tam.z - 0.25), Color(0.5, 0.52, 0.45))   # colchão de trapos
			_caixa(Vector3(0, 0.45, -tam.z * 0.5 + 0.25), Vector3(tam.x - 0.3, 0.1, 0.3), Color(0.72, 0.7, 0.62))  # travesseiro
			_col(Vector3(0, 0.22, 0), Vector3(tam.x, 0.44, tam.z))
		"coletor":
			var barril := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.36
			cm.bottom_radius = 0.33
			cm.height = 0.8
			barril.mesh = cm
			barril.position.y = 0.4
			_por(barril, Color(0.22, 0.38, 0.55))
			var funil := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.5
			fm.bottom_radius = 0.2
			fm.height = 0.3
			funil.mesh = fm
			funil.position.y = 0.95
			_por(funil, Color(0.25, 0.25, 0.27))
			for x in [-0.42, 0.42]:
				_caixa(Vector3(x, 0.55, 0), Vector3(0.06, 1.1, 0.06), MADEIRA_ESCURA)
			_col(Vector3(0, 0.55, 0), Vector3(0.8, 1.1, 0.8))

func _por(mi: MeshInstance3D, c: Color) -> void:
	mi.material_override = mat_fantasma if fantasma else _mat(c)
	mi.visibility_range_end = 120.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if fantasma else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)

func _caixa(pos: Vector3, t: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _malha(t)
	mi.position = pos
	_por(mi, c)

# tábuas deitadas de a até b (ao longo de X), com dois caibros em pé
func _tabuas_parede(a: float, b: float, h: float) -> void:
	var n := int(round(h / 0.4))
	for k in n:
		_caixa(Vector3((a + b) * 0.5, 0.2 + k * 0.4, 0), Vector3(b - a, 0.37, tam.z * 0.6), MADEIRA * (0.82 + 0.06 * (k % 3)))
	for x in [a + 0.06, b - 0.06]:
		_caixa(Vector3(x, h * 0.5, -tam.z * 0.45), Vector3(0.1, h, 0.08), MADEIRA_ESCURA)

func _col(pos: Vector3, t: Vector3) -> void:
	if _corpo == null:
		return
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = t
	cs.shape = bs
	cs.position = pos
	_corpo.add_child(cs)

# ---------- infectados batendo (inimigos/vago.gd) ----------
func golpear(dano: float) -> void:
	if fantasma or vida <= 0.0:
		return
	Sons.em("impactos/bala_madeira", global_position + Vector3(0, 1.0, 0), -2.0, 35.0, randf_range(0.55, 0.7))
	vida -= dano
	if gerente != null:
		gerente.peca_levou_dano(self)

# ---------- PEGAR perto (texto do botão e o que faz) ----------
func acao(_inv) -> String:
	match tipo:
		"cama":
			return "MINHA\nCAMA" if gerente == null or gerente.minha_cama != id else ""
		"coletor":
			return "ENCHER\nGARRAFA (%d)" % agua
	return ""

func usar(inv) -> String:
	match tipo:
		"cama":
			if gerente != null:
				gerente.minha_cama = id
			return "VOCÊ VAI RENASCER NESTA CAMA"
		"coletor":
			if agua <= 0:
				return "O COLETOR ESTÁ VAZIO (ENCHE COM A CHUVA)"
			var g = null
			for id_g in ["garrafa_vazia", "agua_suja"]:
				for gr in inv.grades_do_jogador():
					for it in gr.itens:
						if it.id == id_g and g == null:
							g = it
				if g != null:
					break
			if g == null:
				return "PRECISA DE UMA GARRAFA VAZIA (OU DE ÁGUA SUJA PARA TROCAR)"
			g.id = "agua"
			g.estado = 1.0
			agua -= 1
			if gerente != null:
				gerente.agua_mudou(self)
			inv._depois()
			Sons.tocar("inventario/beber", -6.0)
			return "ENCHEU A GARRAFA COM ÁGUA DA CHUVA (LIMPA)"
	return ""
