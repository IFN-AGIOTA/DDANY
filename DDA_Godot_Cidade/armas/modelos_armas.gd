extends RefCounted
# MODELOS 3D DAS ARMAS (pistola e M4 iguais aos do HTML). Origem = empunhadura · frente (cano) = +Z.
# Cada arma de fogo tem um nó filho "Cano" na ponta (clarão e traçante) e acessórios escondidos
# "Acc_cano" (silenciador) e "Acc_mira" (mira/luneta), que aparecem quando estão encaixados.
# Armas brancas: o cabo fica na origem e a lâmina/cabeça vai para +Z.
# MODELOS BAIXADOS (licença livre; créditos no menu Créditos e em armas/modelos/LICENCA.txt):
#   1º armas/modelos/<tipo>.glb: REALISTAS (texturas de verdade), preparados por
#      ferramentas/preparar_itens_realistas.py com os nós "Cano" (boca do cano) e "Mira" (onde a mira encaixa);
#      aqui ganham "Acc_cano" (silenciador) e "Acc_mira" (mira 4x ou luneta) escondidos;
#   2º armas/modelos/<tipo>.scn: low poly antigos (só a lança ainda usa);
#   3º o modelo de caixas abaixo (cano de ferro).

static func _mat(cor: Color, rough: float, metal := 0.0, sem_luz := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rough
	m.metallic = metal
	if sem_luz:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func _B(g: Node3D, w: float, h: float, d: float, m: Material, x: float, y: float, z: float, rx := 0.0) -> void:
	var o := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	o.mesh = bm
	o.material_override = m
	o.position = Vector3(x, y, z)
	o.rotation.x = rx
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(o)

static func _C(g: Node3D, r0: float, r1: float, comp: float, m: Material, x: float, y: float, z: float) -> void:
	var o := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r0
	cm.bottom_radius = r1
	cm.height = comp
	cm.radial_segments = 8
	cm.rings = 1
	o.mesh = cm
	o.material_override = m
	o.position = Vector3(x, y, z)
	o.rotation.x = PI / 2.0      # cilindro deitado ao longo de Z
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(o)

static var _cenas := {}
static var _acess := {}
# quais acessórios cada arma de fogo aceita (o mesmo que "acess" em inventario/itens.gd)
const Malhas := preload("res://mundo/malhas.gd")
const SILENCIADOR := ["pistola", "mp5", "m4", "ak", "rifle_caca"]
const MIRA := {"m4": "mira_acog", "ak": "mira_acog", "rifle_caca": "luneta"}

static func construir(tipo: String) -> Node3D:
	if not _cenas.has(tipo):
		var glb := "res://armas/modelos/%s.glb" % tipo
		var scn := "res://armas/modelos/%s.scn" % tipo
		_cenas[tipo] = load(glb) if ResourceLoader.exists(glb) else (load(scn) if ResourceLoader.exists(scn) else null)
	if _cenas[tipo] != null:
		var n: Node3D = _cenas[tipo].instantiate()
		n.name = "Arma_" + tipo
		Malhas.culling_fechadas(n)                 # malha fechada: só a frente dos triângulos (back-face culling)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mira := n.get_node_or_null("Mira") as Node3D
		var cano := n.get_node_or_null("Cano") as Node3D
		if cano != null and tipo in SILENCIADOR and n.get_node_or_null("Acc_cano") == null:
			var sil := _peca("silenciador")
			sil.position = cano.position - Vector3(0, sil.mesh.get_aabb().size.y * 0.5, 0.01)
			_esconder_em(n, "Acc_cano", sil)
		if mira != null and MIRA.has(tipo) and n.get_node_or_null("Acc_mira") == null:
			var mi := _peca(MIRA[tipo])
			mi.position = mira.position
			_esconder_em(n, "Acc_mira", mi)
		return n
	return construir_caixas(tipo)

static func _peca(id: String) -> MeshInstance3D:
	if not _acess.has(id):
		_acess[id] = load("res://equipamentos/modelos/%s.res" % id)
	var mi := MeshInstance3D.new()
	mi.mesh = _acess[id]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _esconder_em(n: Node3D, nome: String, peca: Node3D) -> void:
	var a := Node3D.new()
	a.name = nome
	a.visible = false
	n.add_child(a)
	a.add_child(peca)

# modelo antigo, feito de caixas (reserva quando não há modelo baixado)
static func construir_caixas(tipo: String) -> Node3D:
	var g := Node3D.new()
	g.name = "Arma_" + tipo
	var metal := _mat(Color("#2b2d32"), 0.3, 0.7)
	var black := _mat(Color("#121417"), 0.6)
	var grey := _mat(Color("#4a4f57"), 0.5, 0.3)
	var red := _mat(Color("#ff2a1a"), 1.0, 0.0, true)
	var cano := Node3D.new()
	cano.name = "Cano"
	g.add_child(cano)
	var mad := _mat(Color("#5a3820"), 0.8)
	var aco := _mat(Color("#9aa0a6"), 0.35, 0.8)
	match tipo:
		"pistola":
			_B(g, 0.034, 0.042, 0.2, metal, 0, 0.03, 0.07)
			_B(g, 0.03, 0.022, 0.17, black, 0, 0, 0.06)
			_C(g, 0.008, 0.008, 0.03, metal, 0, 0.03, 0.19)
			_B(g, 0.03, 0.1, 0.045, black, 0, -0.05, -0.005, 0.2)
			_B(g, 0.02, 0.012, 0.055, black, 0, -0.018, 0.055)
			_B(g, 0.01, 0.014, 0.012, grey, 0, 0.056, 0.16)
			_B(g, 0.018, 0.014, 0.012, grey, 0, 0.056, -0.02)
			cano.position = Vector3(0, 0.03, 0.2)
			_acessorio(g, "Acc_cano", black, Vector3(0, 0.03, 0.27), 0.017, 0.14)
		"m4":
			_B(g, 0.05, 0.075, 0.3, metal, 0, 0.04, 0.02)
			_B(g, 0.05, 0.06, 0.22, black, 0, -0.015, 0)
			_B(g, 0.06, 0.065, 0.26, black, 0, 0.03, 0.3)
			_B(g, 0.062, 0.012, 0.26, grey, 0, 0.066, 0.3)
			_C(g, 0.011, 0.011, 0.2, metal, 0, 0.04, 0.53)
			_C(g, 0.017, 0.017, 0.065, black, 0, 0.04, 0.645)
			_B(g, 0.01, 0.045, 0.012, black, 0, 0.09, 0.5)
			_B(g, 0.036, 0.03, 0.09, black, 0, 0.095, 0.03)
			_B(g, 0.042, 0.042, 0.075, black, 0, 0.125, 0.04)
			_B(g, 0.03, 0.028, 0.006, red, 0, 0.125, 0.079)
			_B(g, 0.04, 0.14, 0.07, black, 0, -0.1, 0.09, -0.12)
			_B(g, 0.035, 0.1, 0.05, black, 0, -0.09, -0.06, 0.3)
			_C(g, 0.02, 0.02, 0.2, metal, 0, 0.025, -0.3)
			_B(g, 0.045, 0.09, 0.17, black, 0, 0, -0.4)
			cano.position = Vector3(0, 0.04, 0.69)
			_acessorio(g, "Acc_cano", black, Vector3(0, 0.04, 0.76), 0.022, 0.16)
			_acessorio(g, "Acc_mira", black, Vector3(0, 0.15, 0.06), 0.022, 0.14)
		"ak":
			_B(g, 0.05, 0.07, 0.34, metal, 0, 0.035, 0.05)
			_B(g, 0.055, 0.06, 0.24, mad, 0, 0.03, 0.33)
			_C(g, 0.011, 0.011, 0.26, metal, 0, 0.045, 0.56)
			_B(g, 0.01, 0.04, 0.012, black, 0, 0.08, 0.64)
			_B(g, 0.038, 0.16, 0.06, metal, 0, -0.1, 0.13, -0.35)
			_B(g, 0.035, 0.1, 0.05, mad, 0, -0.08, -0.06, 0.3)
			_B(g, 0.045, 0.1, 0.32, mad, 0, -0.02, -0.3, -0.12)
			cano.position = Vector3(0, 0.045, 0.7)
			_acessorio(g, "Acc_cano", black, Vector3(0, 0.045, 0.78), 0.022, 0.16)
			_acessorio(g, "Acc_mira", black, Vector3(0, 0.1, 0.08), 0.022, 0.14)
		"espingarda":
			_B(g, 0.05, 0.07, 0.26, metal, 0, 0.03, 0.05)
			_C(g, 0.014, 0.014, 0.5, metal, 0, 0.05, 0.42)
			_C(g, 0.017, 0.017, 0.42, black, 0, 0.015, 0.38)
			_B(g, 0.05, 0.05, 0.16, mad, 0, 0.0, 0.33)
			_B(g, 0.035, 0.1, 0.05, mad, 0, -0.08, -0.06, 0.3)
			_B(g, 0.048, 0.1, 0.34, mad, 0, -0.02, -0.3, -0.12)
			cano.position = Vector3(0, 0.05, 0.68)
		"rifle_caca":
			_B(g, 0.04, 0.06, 0.3, metal, 0, 0.035, 0.08)
			_C(g, 0.012, 0.012, 0.6, metal, 0, 0.045, 0.5)
			_B(g, 0.05, 0.06, 0.5, mad, 0, 0.0, 0.2)
			_C(g, 0.007, 0.007, 0.06, metal, 0.04, 0.05, 0.0)
			_B(g, 0.035, 0.1, 0.05, mad, 0, -0.07, -0.06, 0.3)
			_B(g, 0.05, 0.11, 0.36, mad, 0, -0.02, -0.32, -0.1)
			cano.position = Vector3(0, 0.045, 0.8)
			_acessorio(g, "Acc_mira", black, Vector3(0, 0.11, 0.1), 0.026, 0.3)
		"faca":
			_B(g, 0.025, 0.03, 0.11, black, 0, 0, 0.0)
			_B(g, 0.05, 0.035, 0.012, metal, 0, 0, 0.06)
			_B(g, 0.006, 0.03, 0.17, aco, 0, 0.004, 0.15)
		"taco":
			_C(g, 0.016, 0.02, 0.3, mad, 0, 0, 0.05)
			_C(g, 0.035, 0.02, 0.5, mad, 0, 0, 0.45)
		"machado":
			_C(g, 0.016, 0.016, 0.7, mad, 0, 0, 0.25)
			_B(g, 0.012, 0.16, 0.1, aco, 0, 0.06, 0.55)
			_B(g, 0.03, 0.05, 0.08, metal, 0, -0.03, 0.55)
		"cano":
			_C(g, 0.02, 0.02, 0.75, _mat(Color("#55575a"), 0.5, 0.6), 0, 0, 0.25)
			_C(g, 0.028, 0.028, 0.05, metal, 0, 0, 0.62)
		"lanca":
			_C(g, 0.016, 0.02, 1.5, mad, 0, 0, 0.45)
			_B(g, 0.006, 0.03, 0.17, aco, 0, 0.0, 1.27)
			_B(g, 0.03, 0.03, 0.08, _mat(Color("#8a8070"), 0.9), 0, 0, 1.14)
		"pe_de_cabra":
			_C(g, 0.012, 0.012, 0.65, _mat(Color("#7a1a14"), 0.5, 0.4), 0, 0, 0.25)
			_B(g, 0.02, 0.09, 0.03, _mat(Color("#7a1a14"), 0.5, 0.4), 0, 0.035, 0.58, 0.6)
	return g

# acessório escondido (armas.gd mostra quando está encaixado)
static func _acessorio(g: Node3D, nome: String, m: Material, pos: Vector3, raio: float, comp: float) -> void:
	var a := Node3D.new()
	a.name = nome
	a.visible = false
	g.add_child(a)
	_C(a, raio, raio, comp, m, pos.x, pos.y, pos.z)
