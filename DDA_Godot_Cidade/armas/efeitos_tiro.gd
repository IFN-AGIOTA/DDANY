extends Node3D
# EFEITOS DOS TIROS (porte do HTML): traçantes que voam até o alvo, clarão do cano, faíscas,
# fumacinha no impacto (terra, concreto, água, sangue) e marcas de bala nas paredes.
# Tudo em "pools" (objetos reaproveitados): nada é criado durante o tiroteio, bom para o celular.
# Fica solto no mundo (top_level), não segue o jogador.

const N_TRACANTES := 24
const N_FAISCAS := 12
const N_MARCAS := 40
const N_FUMACA := 28

var _trac: Array = []    # {no, on, s, d, len, v, L, h, fx, k, hit, n, alvo_cb}
var _ti := 0
var _fais: Array = []    # {no, vida}
var _si := 0
var _marcas: Array[MeshInstance3D] = []
var _di := 0
var _fum: Array = []     # {no, vida, total, cresce, sobe}
var _fi := 0
var _clarao: MeshInstance3D
var _luz_tiro: OmniLight3D
const N_SANGUE := 14
var _sangue: Array[MeshInstance3D] = []
var _bi := 0
var _clarao_t := 0.0
var _clarao_cano: Node3D = null
var _clarao_tam := 1.0
var _mat_fum: Array[StandardMaterial3D] = []
var camera: Camera3D = null      # para engrossar a traçante com a distância
var detalhe_marcas := true

func _tex_radial(c0: Color, c1: Color) -> GradientTexture2D:
	var gr := Gradient.new()
	gr.set_color(0, c0)
	gr.set_color(1, c1)
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	return gt

func _mat_brilho(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true     # sem isto a Godot ignora a escala do nó
	m.disable_fog = true
	m.vertex_color_use_as_albedo = false
	return m

func _quad(m: Material, tam: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func _ready() -> void:
	top_level = true
	# traçantes: caixa fina de 1 m que é esticada até o comprimento certo
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(1.0, 0.9, 0.63, 0.9)
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	tm.disable_fog = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	for i in N_TRACANTES:
		var piv := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = tm
		mi.position = Vector3(0, 0, -0.5)   # a caixa vai de 0 até -1 em Z (frente do look_at)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piv.add_child(mi)
		piv.visible = false
		add_child(piv)
		_trac.append({"no": piv, "on": false})
	var tf := _tex_radial(Color(1.0, 0.9, 0.63, 1.0), Color(1.0, 0.55, 0.16, 0.0))
	for i in N_FAISCAS:
		_fais.append({"no": _quad(_mat_brilho(tf), 1.0), "vida": 0.0})
	_clarao = _quad(_mat_brilho(_tex_radial(Color(1.0, 0.92, 0.67, 1.0), Color(1.0, 0.51, 0.12, 0.0))), 1.0)
	# luz do clarão: ilumina paredes, chão e infectados por um instante (à noite faz muita diferença)
	_luz_tiro = OmniLight3D.new()
	_luz_tiro.light_color = Color(1.0, 0.75, 0.4)
	_luz_tiro.omni_range = 7.0
	_luz_tiro.light_energy = 0.0
	_luz_tiro.shadow_enabled = false
	_luz_tiro.visible = false
	add_child(_luz_tiro)
	# manchas de sangue no chão (pool próprio, somem devagar)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = _tex_radial(Color(0.32, 0.02, 0.02, 0.9), Color(0.25, 0.0, 0.0, 0.0))
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	sm.roughness = 0.35
	sm.render_priority = 1
	for i in N_SANGUE:
		var mi := _quad(sm, 1.0)
		_sangue.append(mi)
	# marcas de bala (ficam coladas na superfície)
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = _tex_radial(Color(0.06, 0.06, 0.06, 0.9), Color(0.06, 0.06, 0.06, 0.0))
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	dm.render_priority = 1
	for i in N_MARCAS:
		var mi := _quad(dm, 0.2)
		_marcas.append(mi)
	# fumaça: um material por "nuvem" (a opacidade de cada uma muda sozinha)
	var tsm := _tex_radial(Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.0))
	for i in N_FUMACA:
		var m := StandardMaterial3D.new()
		m.albedo_texture = tsm
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		_mat_fum.append(m)
		_fum.append({"no": _quad(m, 1.0), "vida": 0.0, "total": 1.0, "cresce": 1.0, "sobe": 0.0})

# dispara uma traçante do cano até o ponto final. k = tipo do impacto (0 nada · 1 terra · 2 água · 3 concreto · 4 alvo)
func tracante(origem: Vector3, fim: Vector3, vel: float, comp: float, k: int, normal: Vector3) -> void:
	_ocioso = false
	var d := fim - origem
	var L := d.length()
	if L < 0.01:
		if k != 0:
			impacto(fim, normal, k)
		return
	var q: Dictionary = {}
	for t in _trac:
		if not t["on"]:
			q = t
			break
	if q.is_empty():
		_ti = (_ti + 1) % _trac.size()
		q = _trac[_ti]
	q["on"] = true
	q["s"] = origem
	q["d"] = d / L
	q["len"] = L
	q["v"] = vel
	q["L"] = comp
	q["h"] = 0.0
	q["fx"] = false
	q["k"] = k
	q["hit"] = fim
	q["n"] = normal
	(q["no"] as Node3D).visible = true

func clarao(cano: Node3D, tamanho: float) -> void:
	_ocioso = false
	_clarao_cano = cano
	_clarao_tam = tamanho
	_clarao_t = 0.055

func impacto(p: Vector3, n: Vector3, k: int) -> void:
	_ocioso = false
	_som_impacto(p, k)
	if k == 4:
		# sangue: borrifo escuro + gotas + mancha no chão embaixo
		fumaca(p, Color(0.42, 0.03, 0.03), 0.3, 0.45)
		fumaca(p + Vector3(randf_range(-0.15, 0.15), -0.1, randf_range(-0.15, 0.15)), Color(0.3, 0.02, 0.02), 0.18, 0.6)
		_mancha_sangue(p)
		return
	if k == 2:
		var c := Color(0.81, 0.9, 1.0)
		fumaca(Vector3(p.x, p.y + 0.15, p.z), c, 0.6, 0.7)    # água espirrando
		fumaca(Vector3(p.x + randf_range(-0.3, 0.3), p.y + 0.15, p.z + randf_range(-0.3, 0.3)), c, 0.6, 0.7)
		return
	_si = (_si + 1) % _fais.size()
	var s: Dictionary = _fais[_si]
	s["vida"] = 0.09
	(s["no"] as Node3D).position = p + n * 0.1
	(s["no"] as Node3D).visible = true
	fumaca(p + n * 0.2, Color(0.73, 0.66, 0.55) if k == 1 else Color(0.74, 0.74, 0.74), 0.45, 0.6)
	if not detalhe_marcas:
		return
	_di = (_di + 1) % _marcas.size()
	var m := _marcas[_di]
	var z := n.normalized()
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.FORWARD
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	m.global_transform = Transform3D(Basis(x, y, z).rotated(z, randf() * TAU), p + z * 0.03)
	m.visible = true

func _mancha_sangue(p: Vector3) -> void:
	if not is_inside_tree():
		return
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -3.0, 0), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	_bi = (_bi + 1) % _sangue.size()
	var mi := _sangue[_bi]
	var n: Vector3 = r["normal"]
	var pos: Vector3 = r["position"] + n * 0.02 + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
	var z := n.normalized()
	var x := (Vector3.UP if absf(z.y) < 0.95 else Vector3.FORWARD).cross(z).normalized()
	var y := z.cross(x)
	var tam := randf_range(0.35, 0.7)
	var b := Basis(x, y, z).rotated(z, randf() * TAU)
	mi.global_transform = Transform3D(Basis(b.x * tam, b.y * tam, b.z), pos)
	mi.visible = true

func fumaca(p: Vector3, cor: Color, tam: float, vida: float) -> void:
	_ocioso = false
	# de noite a fumaça/poeira não pode "brilhar" (ela não recebe luz): escurece junto com a cena
	var cl = get_tree().current_scene.get("clima") if get_tree() != null and get_tree().current_scene != null else null
	if cl != null and is_instance_valid(cl):
		var esc := clampf(float(cl.escuridao()), 0.0, 1.0)
		cor = Color(cor.r * (1.0 - 0.75 * esc), cor.g * (1.0 - 0.75 * esc), cor.b * (1.0 - 0.75 * esc))
	_fi = (_fi + 1) % _fum.size()
	var f: Dictionary = _fum[_fi]
	f["vida"] = vida
	f["total"] = vida
	f["cresce"] = tam
	f["sobe"] = randf_range(0.3, 0.7)
	var no: MeshInstance3D = f["no"]
	no.position = p
	no.scale = Vector3.ONE * tam * 0.4
	_mat_fum[_fi].albedo_color = Color(cor.r, cor.g, cor.b, 1.0)
	no.visible = true

# OTIMIZAÇÃO: sem nenhum efeito na tela, não percorre as listas (antes: todo quadro, sempre)
var _ocioso := false

func _process(dt: float) -> void:
	if _ocioso:
		return
	var algum := false
	var cp := camera.global_position if camera != null else Vector3.ZERO
	for q in _trac:
		if not q["on"]:
			continue
		algum = true
		q["h"] += q["v"] * dt
		if not q["fx"] and q["h"] >= q["len"]:
			q["fx"] = true
			if q["k"] != 0:
				impacto(q["hit"], q["n"], q["k"])
		var hd: float = minf(q["h"], q["len"])
		var tl: float = maxf(0.0, q["h"] - q["L"])
		var no: Node3D = q["no"]
		if tl >= q["len"]:
			q["on"] = false
			no.visible = false
			continue
		var d: Vector3 = q["d"]
		var a: Vector3 = q["s"] + d * tl
		var w := 0.035 + a.distance_to(cp) * 0.0035
		var comp := maxf(0.05, hd - tl)
		var zf := -d                                       # o eixo -Z do pivô aponta para frente
		var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
		var bx := up.cross(zf).normalized()
		var by := zf.cross(bx)
		no.global_transform = Transform3D(Basis(bx * w, by * w, zf * comp), a)
	for s in _fais:
		var no: MeshInstance3D = s["no"]
		if not no.visible:
			continue
		algum = true
		s["vida"] -= dt
		if s["vida"] <= 0.0:
			no.visible = false
			continue
		var k: float = s["vida"] / 0.09
		no.scale = Vector3.ONE * (0.25 + k * 0.55)
	for i in _fum.size():
		var f: Dictionary = _fum[i]
		var no: MeshInstance3D = f["no"]
		if not no.visible:
			continue
		algum = true
		f["vida"] -= dt
		if f["vida"] <= 0.0:
			no.visible = false
			continue
		var e: float = 1.0 - f["vida"] / f["total"]
		no.scale = Vector3.ONE * f["cresce"] * (0.4 + e * 1.2)
		no.position.y += f["sobe"] * dt
		_mat_fum[i].albedo_color.a = (1.0 - e) * 0.8
	if _clarao_t > 0.0 and _clarao_cano != null and is_instance_valid(_clarao_cano) and _clarao_cano.is_visible_in_tree():
		_clarao_t -= dt
		_clarao.global_position = _clarao_cano.global_position
		_clarao.scale = Vector3.ONE * _clarao_tam * (0.6 + maxf(0.0, _clarao_t) / 0.055 * 0.6)
		_clarao.visible = true
		_luz_tiro.global_position = _clarao_cano.global_position
		_luz_tiro.light_energy = 2.2 * clampf(_clarao_t / 0.055, 0.0, 1.0) * _clarao_tam
		_luz_tiro.visible = true
		algum = true
	else:
		_clarao.visible = false
		_clarao_t = 0.0
		if _luz_tiro.visible:
			_luz_tiro.visible = false
	_ocioso = not algum

# 0.49: bala batendo (gravações, audio/sons/impactos): terra, água, concreto (às vezes metal: placas, postes,
# carros) e carne. Só perto da câmera (de longe não se ouve) e no máximo um por quadro por tipo (audio/sons.gd).
const SonsImp := preload("res://audio/sons.gd")
const DIST_SOM_IMPACTO := 55.0
func _som_impacto(p: Vector3, k: int) -> void:
	if camera == null or not is_instance_valid(camera) or camera.global_position.distance_to(p) > DIST_SOM_IMPACTO:
		return
	var nome := "impactos/bala"
	var vol := -4.0
	match k:
		1:
			nome = "impactos/bala_terra"
			vol = -8.0
		2:
			nome = "impactos/bala_agua"
			vol = -6.0
		4:
			nome = "impactos/bala_carne"
			vol = -3.0
		_:
			if randf() < 0.22:
				nome = "impactos/bala_metal"
				vol = -10.0
	SonsImp.em(nome, p, vol, 40.0)

