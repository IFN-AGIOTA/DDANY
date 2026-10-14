extends RefCounted
# MODELOS 3D DAS ARMAS (iguais aos do HTML). Origem = empunhadura · frente (cano) = +Z.
# Cada arma tem um nó filho "Cano" na ponta, de onde saem o clarão e a traçante.

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

static func construir(tipo: String) -> Node3D:
	var g := Node3D.new()
	g.name = "Arma_" + tipo
	var metal := _mat(Color("#2b2d32"), 0.3, 0.7)
	var black := _mat(Color("#121417"), 0.6)
	var grey := _mat(Color("#4a4f57"), 0.5, 0.3)
	var red := _mat(Color("#ff2a1a"), 1.0, 0.0, true)
	var cano := Node3D.new()
	cano.name = "Cano"
	g.add_child(cano)
	if tipo == "pistola":
		_B(g, 0.034, 0.042, 0.2, metal, 0, 0.03, 0.07)
		_B(g, 0.03, 0.022, 0.17, black, 0, 0, 0.06)
		_C(g, 0.008, 0.008, 0.03, metal, 0, 0.03, 0.19)
		_B(g, 0.03, 0.1, 0.045, black, 0, -0.05, -0.005, 0.2)
		_B(g, 0.02, 0.012, 0.055, black, 0, -0.018, 0.055)
		_B(g, 0.01, 0.014, 0.012, grey, 0, 0.056, 0.16)
		_B(g, 0.018, 0.014, 0.012, grey, 0, 0.056, -0.02)
		cano.position = Vector3(0, 0.03, 0.2)
	else:
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
	return g
