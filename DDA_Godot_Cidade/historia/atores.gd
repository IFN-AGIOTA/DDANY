extends Node3D
# 1.13 · ATOR DO MODO HISTÓRIA (Dominic, Greg, Mavie e figurantes): o MESMO corpo padrão do jogo
# (jogador/modelo_sobrevivente.gd, masculino ou feminino) com a aparência e a roupa de cada um (FICHAS, conforme a
# Bíblia), roupa tingida (jaqueta de couro preta...) e, no Dominic, os ÓCULOS ESCUROS DE AVIADOR (feitos em código,
# presos ao osso da cabeça). Anda até um ponto, toca uma animação (sentado, acenar, sim, dirigindo...), olha para algo.
# vestir_jogador(jogador, "dominic"): o próprio jogador vira o Dominic no modo história.
# Mexa AQUI para: a cara e a roupa de cada personagem (FICHAS) e o tamanho/posição dos óculos.

const ModeloCls := preload("res://jogador/modelo_sobrevivente.gd")
const ItemCls := preload("res://inventario/item.gd")

# quem -> aparência + roupas [item, cor] por encaixe
const FICHAS := {
	# cabelo BRANCO de nascença (cor 6), pele mais clara que o normal, jaqueta de couro preta, calça e botas pretas
	"dominic": {"ap": {"sexo": "m", "pele": 0, "cabelo": "Hair_SimpleParted", "barba": false, "cor": 6},
		"roupa": {"camisa": ["jaqueta", Color(0.26, 0.25, 0.25)], "calca": ["jeans_escuro", Color(0.24, 0.24, 0.26)],
			"pes": ["coturno", Color(0.3, 0.3, 0.3)]}, "oculos": true},
	# negro, cabelo curto, bigode e cavanhaque, jaqueta preta, calça cargo preta, botas verde-oliva
	"greg": {"ap": {"sexo": "m", "pele": 4, "cabelo": "Hair_Buzzed", "barba": true, "cor": 1},
		"roupa": {"camisa": ["jaqueta", Color(0.28, 0.28, 0.3)], "calca": ["calca", Color(0.3, 0.3, 0.32)],
			"pes": ["coturno", Color(0.26, 0.28, 0.16)]}},
	"mavie": {"ap": {"sexo": "f", "pele": 1, "cabelo": "Hair_Long", "barba": false, "cor": 0},
		"roupa": {"camisa": ["camiseta_feminina", Color(0.55, 0.62, 0.7)], "calca": ["jeans", Color(1, 1, 1)],
			"pes": ["tenis_branco", Color(1, 1, 1)]}},
	"garoto": {"ap": {"sexo": "m", "pele": 2, "cabelo": "Hair_Buzzed", "barba": false, "cor": 1},
		"roupa": {"camisa": ["moletom", Color(0.55, 0.15, 0.12)], "calca": ["jeans", Color(1, 1, 1)],
			"pes": ["tenis_basquete", Color(1, 1, 1)]}},
	"corredor": {"ap": {"sexo": "m", "pele": 3, "cabelo": "Hair_SimpleParted", "barba": true, "cor": 0},
		"roupa": {"camisa": ["camiseta_estampada", Color(1, 1, 1)], "calca": ["jeans", Color(1, 1, 1)],
			"pes": ["tenis_branco", Color(1, 1, 1)]}},
	"corredora": {"ap": {"sexo": "f", "pele": 2, "cabelo": "Hair_Buns", "barba": false, "cor": 4},
		"roupa": {"camisa": ["top_esporte", Color(0.15, 0.15, 0.16)], "calca": ["legging", Color(1, 1, 1)],
			"pes": ["tenis_azul", Color(1, 1, 1)]}},
	"policial": {"ap": {"sexo": "m", "pele": 2, "cabelo": "Hair_Buzzed", "barba": false, "cor": 1},
		"roupa": {"camisa": ["camisa_botao", Color(0.16, 0.2, 0.34)], "calca": ["calca_social", Color(0.12, 0.14, 0.22)],
			"pes": ["sapato_preto", Color(1, 1, 1)], "colete": ["colete_policia", Color(1, 1, 1)],
			"cabeca": ["bone_militar", Color(0.1, 0.12, 0.2)]}},
}

var quem := ""
var modelo: Node3D
var _alvo := Vector3.INF
var _vel := 1.4
var _anim_andar := "andar_normal"
var _depois := "parado"
var olhar_para = null                   # Vector3 ou Node3D: gira o corpo para ele (parado)

static func criar(pai: Node, nome: String, pos: Vector3, giro := 0.0) -> Node3D:
	var a = load("res://historia/atores.gd").new()
	a.quem = nome
	a.name = "Ator_" + nome
	pai.add_child(a)
	a.global_position = pos
	a.rotation.y = giro
	return a

func _ready() -> void:
	var f: Dictionary = FICHAS.get(quem, FICHAS["corredor"])
	modelo = ModeloCls.new()
	modelo.name = "Sobrevivente"
	modelo.aparencia = f["ap"]
	add_child(modelo)
	vestir_modelo(modelo, quem)

# põe a roupa (e os óculos) de "quem" num modelo_sobrevivente.gd já na cena
static func vestir_modelo(m: Node3D, nome: String) -> void:
	var f: Dictionary = FICHAS.get(nome, {})
	var slots := {}
	var roupa: Dictionary = f.get("roupa", {})
	for s in roupa:
		var it = ItemCls.novo(str(roupa[s][0]))
		if it != null:
			slots[s] = it
	m.vestir(_Inv.new(slots))
	for s in roupa:
		var r = m.get("_roupas_3d").get(s)
		if r is Array and r.size() > 1 and r[1] != null:
			var mat = (r[1] as MeshInstance3D).material_override
			if mat is ShaderMaterial:
				mat = (mat as ShaderMaterial).duplicate()
				mat.set_shader_parameter("cor", roupa[s][1])
				(r[1] as MeshInstance3D).material_override = mat
	if bool(f.get("oculos", false)):
		_oculos(m)

# "inventário" de mentira: só os encaixes (modelo_sobrevivente.vestir lê .slots)
class _Inv:
	var slots := {}
	func _init(s: Dictionary) -> void:
		slots = s

# ÓCULOS ESCUROS DE AVIADOR: duas lentes em gota (espelhadas), ponte e hastes finas, no osso da cabeça
static func _oculos(m: Node3D) -> void:
	var ba: BoneAttachment3D = m.call("_anexo", "Head")
	if ba == null or ba.get_node_or_null("Oculos") != null:
		return
	var raiz := Node3D.new()
	raiz.name = "Oculos"
	ba.add_child(raiz)
	var lente := StandardMaterial3D.new()
	lente.albedo_color = Color(0.05, 0.06, 0.07)
	lente.metallic = 0.9
	lente.roughness = 0.08
	var armacao := StandardMaterial3D.new()
	armacao.albedo_color = Color(0.75, 0.68, 0.45)
	armacao.metallic = 1.0
	armacao.roughness = 0.3
	var am := ArrayMesh.new()
	# lente em gota: polígono achatado (largura 5,4 cm, altura 4,4 cm), levemente curvado
	for lado in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var centro := Vector3(0.036 * lado, 0.0, 0.0)
		var pts: Array = []
		var n := 18
		for i in n:
			var a := TAU * i / n
			var x := cos(a) * 0.031
			var y := sin(a) * 0.022
			if y < 0.0:
				y *= 1.3                                       # gota: mais funda embaixo, puxada para o nariz
				x -= lado * 0.006 * absf(sin(a))
			pts.append(centro + Vector3(x, y, -absf(x) * 0.15))
		st.set_normal(Vector3(0, 0, 1))
		for i in n:
			st.add_vertex(centro)
			st.add_vertex(pts[i])
			st.add_vertex(pts[(i + 1) % n])
		st.generate_normals()
		var malha := st.commit()
		var mi := MeshInstance3D.new()
		mi.mesh = malha
		mi.material_override = lente
		raiz.add_child(mi)
		var mi2 := MeshInstance3D.new()                      # o verso (lente vista de dentro / do lado)
		mi2.mesh = malha
		mi2.material_override = lente
		mi2.scale = Vector3(1, 1, -1)
		raiz.add_child(mi2)
	# ponte e hastes
	for p in [[Vector3(0, 0.012, 0.001), Vector3(0.016, 0.0025, 0.003)], [Vector3(-0.069, 0.008, -0.062), Vector3(0.003, 0.003, 0.13)],
			[Vector3(0.069, 0.008, -0.062), Vector3(0.003, 0.003, 0.13)]]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[1]
		b.mesh = bm
		b.material_override = armacao
		b.position = p[0]
		raiz.add_child(b)
	# posição nos olhos (espaço do osso da cabeça; ajustado olhando as fotos)
	raiz.position = OCULOS_POS
	raiz.rotation = OCULOS_GIRO

const OCULOS_POS := Vector3(0.0, 0.078, 0.106)
const OCULOS_GIRO := Vector3(0.0, 0.0, 0.0)

# o jogador vira o personagem (modo história)
static func vestir_jogador(jogador: Node3D, nome: String) -> void:
	var m = load("res://jogador/modelo_sobrevivente.gd").new()
	m.name = "Sobrevivente"
	m.aparencia = FICHAS[nome]["ap"]
	jogador.trocar_modelo(m, true)
	jogador.animador.nomes_exatos = m.NOMES_ANIM
	jogador.animador.atualizar_mapa()
	vestir_modelo(m, nome)

# ---------- comandos ----------
func tocar(anim: String, mistura := 0.3) -> void:
	_alvo = Vector3.INF
	_depois = anim
	if modelo != null and modelo.anim != null and modelo.anim.has_animation(anim):
		modelo.anim.play(anim, mistura)

func andar_ate(p: Vector3, correndo := false, depois := "parado") -> void:
	_alvo = p
	_vel = 4.6 if correndo else 1.45
	_anim_andar = "correr" if correndo else "andar_normal"
	_depois = depois
	if modelo != null and modelo.anim != null:
		modelo.anim.play(_anim_andar, 0.25)

func chegou() -> bool:
	return _alvo == Vector3.INF

func _process(dt: float) -> void:
	if _alvo != Vector3.INF:
		var d := _alvo - global_position
		d.y = 0.0
		var l := d.length()
		if l < 0.15:
			_alvo = Vector3.INF
			tocar(_depois)
		else:
			var passo := minf(l, _vel * dt)
			global_position += d / l * passo
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, dt * 8.0))
	elif olhar_para != null:
		var p: Vector3 = olhar_para.global_position if olhar_para is Node3D else olhar_para
		var d2 := p - global_position
		if Vector2(d2.x, d2.z).length() > 0.2:
			rotation.y = lerp_angle(rotation.y, atan2(d2.x, d2.z), minf(1.0, dt * 4.0))
