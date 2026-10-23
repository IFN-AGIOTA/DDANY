extends RefCounted
# MODELOS 3D REALISTAS DOS ITENS (o que aparece no CHÃO e nas fotos do inventário). Baixados com licença livre
# (CC0, quase todos do Poly Haven; créditos no menu Créditos e em inventario/modelos/LICENCA.txt) e preparados
# por ferramentas/preparar_itens_realistas.py: tamanho real, em pé, origem embaixo no meio.
# Itens que não estão aqui continuam como caixinha da cor da categoria (inventario/item_mundo.gd) ou peça
# feita por código (abaixo: refrigerante e frascos de remédio).
# Mexa AQUI para: qual modelo cada item usa, o tamanho e se fica deitado no chão.

const PASTA := "res://inventario/modelos/"
const Malhas := preload("res://mundo/malhas.gd")
# id do item: [modelo, escala, deitado (gira 90° para ficar de lado no chão)]
const ITENS := {
	"kit_medico": ["kit_medico", 1.0, false],
	"fita": ["fita", 1.0, false],
	"bandagem": ["fita", 0.8, false],
	"feijao": ["lata_feijao", 1.0, false],
	"pessego": ["lata_tomate", 1.0, false],
	"atum": ["lata_peixe", 1.0, false],
	"sardinha": ["lata_sardinha", 1.0, false],
	"leite_condensado": ["lata_leite", 1.0, false],
	"suco": ["caixa_leite", 1.0, false],
	"maca": ["maca", 1.0, false],
	"agua": ["garrafa_termica", 1.0, true],
	"agua_suja": ["garrafa_termica", 1.0, true],
	"garrafa_vazia": ["garrafa_termica", 1.0, true],
	"lanterna": ["lanterna", 1.0, false],
	"isqueiro": ["isqueiro", 1.0, false],
	"radio": ["radio", 0.75, false],
	"mun_9mm": ["municao", 0.6, false],
	"mun_556": ["municao", 0.7, false],
	"mun_762": ["municao", 0.7, false],
	"mun_12": ["municao", 0.7, false],
	"mun_308": ["municao", 0.7, false],
	"pente_pistola": ["pente_pistola", 1.0, true],
	"pente_mp5": ["pente_pistola", 1.6, true],
	"kit_armas": ["caixa_ferramentas", 0.75, false],
	"kit_costura": ["pote_plastico", 0.8, false],
	"galho": ["galho", 0.85, false],
}

static var _cenas := {}
static var _mats := {}

static func tem(id: String) -> bool:
	return ITENS.has(id) or id in ["refrigerante", "analgesico", "vitaminas", "antibiotico", "carvao", "pastilha", "tabuas"]

static func cena(nome: String) -> PackedScene:
	if not _cenas.has(nome):
		var c := PASTA + nome + ".glb"
		_cenas[nome] = load(c) if ResourceLoader.exists(c) else null
	return _cenas[nome]

# modelo pronto para pôr no chão (origem embaixo) ou null; deitar = false deixa em pé (fotos do inventário)
static func instancia(id: String, deitar := true) -> Node3D:
	if ITENS.has(id):
		var d: Array = ITENS[id]
		var ps := cena(d[0])
		if ps == null:
			return null
		var n: Node3D = ps.instantiate()
		Malhas.culling_fechadas(n)                 # malha fechada: só a frente dos triângulos (back-face culling)
		var raiz := Node3D.new()
		raiz.name = "Modelo_" + id
		raiz.add_child(n)
		n.scale = Vector3.ONE * float(d[1])
		if d[2] and deitar:
			# deitado: o comprido (Y) vira X e a peça encosta no chão
			var ab := _aabb(n)
			n.rotation.z = PI * 0.5
			n.position.y = -ab.position.x * float(d[1])
			n.position.x = ab.size.y * 0.5 * float(d[1])        # centraliza o comprimento
		_sem_sombra(raiz)
		return raiz
	return _por_codigo(id)

static func _aabb(n: Node3D) -> AABB:
	var ab := AABB()
	var prim := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
		ab = a if prim else ab.merge(a)
		prim = false
	return ab

static func _sem_sombra(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _mat(cor: Color, metal := 0.0, rug := 0.5) -> StandardMaterial3D:
	var k := "%s/%.2f/%.2f" % [cor.to_html(), metal, rug]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.metallic = metal
		m.roughness = rug
		_mats[k] = m
	return _mats[k]

static func _cil(pai: Node3D, r: float, h: float, y: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position.y = y + h * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)

# lata de refrigerante e frascos de remédio (cilindros simples, com tampa e rótulo)
static func _por_codigo(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Modelo_" + id
	match id:
		"refrigerante":
			var alu := _mat(Color(0.75, 0.76, 0.78), 0.9, 0.3)
			_cil(n, 0.031, 0.008, 0.0, alu)
			_cil(n, 0.033, 0.106, 0.008, _mat(Color(0.62, 0.05, 0.05), 0.5, 0.35))
			_cil(n, 0.03, 0.008, 0.114, alu)
		"analgesico", "vitaminas", "antibiotico", "carvao", "pastilha":
			var tampa: Color = {"analgesico": Color(0.9, 0.9, 0.9), "vitaminas": Color(0.95, 0.55, 0.1),
				"antibiotico": Color(0.15, 0.35, 0.8), "carvao": Color(0.12, 0.12, 0.12), "pastilha": Color(0.2, 0.6, 0.3)}[id]
			var frasco := Color(0.55, 0.3, 0.08) if id != "carvao" else Color(0.9, 0.9, 0.88)
			_cil(n, 0.022, 0.06, 0.0, _mat(frasco, 0.0, 0.25))
			_cil(n, 0.0225, 0.03, 0.017, _mat(Color(0.95, 0.95, 0.92), 0.0, 0.7))        # rótulo
			_cil(n, 0.024, 0.018, 0.06, _mat(tampa, 0.0, 0.5))
		"tabuas":
			# 0.73: três tábuas empilhadas, com as pontas dos pregos aparecendo
			var mad := _mat(Color(0.58, 0.44, 0.28), 0.0, 0.85)
			var prego := _mat(Color(0.55, 0.55, 0.57), 0.8, 0.4)
			for k in 3:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.12, 0.024, 0.9)
				mi.mesh = bm
				mi.material_override = mad
				mi.position = Vector3((k - 1) * 0.02, 0.012 + k * 0.025, (k - 1) * 0.03)
				mi.rotation.y = (k - 1) * 0.08
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				n.add_child(mi)
				for z in [-0.38, 0.38]:
					var pm := MeshInstance3D.new()
					var pb := BoxMesh.new()
					pb.size = Vector3(0.008, 0.02, 0.008)
					pm.mesh = pb
					pm.material_override = prego
					pm.position = mi.position + Vector3(0.0, 0.02, z)
					n.add_child(pm)
		_:
			n.free()
			return null
	return n
