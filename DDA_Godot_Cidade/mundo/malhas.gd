extends RefCounted
# CONSTRUTOR DE MALHAS: junta muitas caixas/cilindros coloridos numa malha só (1 chamada de desenho no celular).
# Usado por carros, móveis, entulho, interiores e infectados.
#   var c := Malhas.Construtor.new()
#   c.caixa(Vector3(0, 0.5, 0), Vector3(1, 1, 1), Color.RED)
#   var malha := c.malha(material)
# UV de cada face = tamanho em metros (texturas e shaders repetem certo em qualquer tamanho).
# SOMBRA PINTADA (AO): a parte de baixo de cada caixa sai mais escura (o renderizador do celular não faz
# sombra de contato). "ao" = quanto escurece embaixo (0 = desliga).

class Construtor:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var ao := 0.28

	func vazio() -> bool:
		return v.is_empty()

	func _quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, nn: Vector3, cor: Color, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, cores := []) -> void:
		# a b c d em volta da face; os triângulos saem no sentido horário visto de fora (frente na Godot)
		# cores (opcional) = cor de cada canto a, b, c, d
		var ca: Color = cores[0] if cores.size() == 4 else cor
		var cb: Color = cores[1] if cores.size() == 4 else cor
		var ccc: Color = cores[2] if cores.size() == 4 else cor
		var cd: Color = cores[3] if cores.size() == 4 else cor
		for p in [[a, ua, ca], [cc, uc, ccc], [b, ub, cb], [a, ua, ca], [d, ud, cd], [cc, uc, ccc]]:
			v.append(p[0])
			n.append(nn)
			c.append(p[2])
			uv.append(p[1])

	# caixa com centro, tamanho, cor e (opcional) rotação; faces: todas ou só algumas (sem_baixo para pisos)
	func caixa(centro: Vector3, tam: Vector3, cor: Color, base := Basis.IDENTITY, sem_baixo := false, sem_cima := false) -> void:
		var h := tam * 0.5
		var cs := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
			Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
		var p := []
		for q in cs:
			p.append(centro + base * q)
		var ex := base.x.normalized()
		var ey := base.y.normalized()
		var ez := base.z.normalized()
		# embaixo mais escuro (em caixas altas, como paredes, bem menos: o degradê pegaria a parede toda)
		var f := 1.0 - ao * clampf(1.5 / maxf(tam.y, 0.01), 0.25, 1.0)
		var cb := Color(cor.r * f, cor.g * f, cor.b * f, cor.a)
		var lat := [cb, cb, cor, cor]
		# +Z
		_quad(p[4], p[5], p[6], p[7], ez, cor, Vector2(0, tam.y), Vector2(tam.x, tam.y), Vector2(tam.x, 0), Vector2(0, 0), lat)
		# -Z
		_quad(p[1], p[0], p[3], p[2], -ez, cor, Vector2(0, tam.y), Vector2(tam.x, tam.y), Vector2(tam.x, 0), Vector2(0, 0), lat)
		# +X
		_quad(p[5], p[1], p[2], p[6], ex, cor, Vector2(0, tam.y), Vector2(tam.z, tam.y), Vector2(tam.z, 0), Vector2(0, 0), lat)
		# -X
		_quad(p[0], p[4], p[7], p[3], -ex, cor, Vector2(0, tam.y), Vector2(tam.z, tam.y), Vector2(tam.z, 0), Vector2(0, 0), lat)
		if not sem_cima:
			_quad(p[7], p[6], p[2], p[3], ey, cor, Vector2(0, 0), Vector2(tam.x, 0), Vector2(tam.x, tam.z), Vector2(0, tam.z))
		if not sem_baixo:
			_quad(p[0], p[1], p[5], p[4], -ey, cb, Vector2(0, 0), Vector2(tam.x, 0), Vector2(tam.x, tam.z), Vector2(0, tam.z))

	# cilindro em pé (eixo Y local) com tampas
	func cilindro(centro: Vector3, raio: float, altura: float, lados: int, cor: Color, base := Basis.IDENTITY, raio_topo := -1.0) -> void:
		var rt := raio if raio_topo < 0.0 else raio_topo
		var hy := altura * 0.5
		for i in lados:
			var a0 := TAU * i / lados
			var a1 := TAU * (i + 1) / lados
			var b0 := centro + base * Vector3(cos(a0) * raio, -hy, sin(a0) * raio)
			var b1 := centro + base * Vector3(cos(a1) * raio, -hy, sin(a1) * raio)
			var t0 := centro + base * Vector3(cos(a0) * rt, hy, sin(a0) * rt)
			var t1 := centro + base * Vector3(cos(a1) * rt, hy, sin(a1) * rt)
			var nn := (base * Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))).normalized()
			var u0 := raio * a0
			var u1 := raio * a1
			_quad(b1, b0, t0, t1, nn, cor, Vector2(u1, altura), Vector2(u0, altura), Vector2(u0, 0), Vector2(u1, 0))
			var ct := centro + base * Vector3(0, hy, 0)
			var cb := centro + base * Vector3(0, -hy, 0)
			var up := (base * Vector3.UP).normalized()
			for q in [[ct, 1.0, t0, t1], [cb, -1.0, b1, b0]]:
				v.append(q[0]); v.append(q[2]); v.append(q[3])
				for k in 3:
					n.append(up * q[1])
					c.append(cor)
					uv.append(Vector2.ZERO)

	func malha(mat: Material = null, ja: ArrayMesh = null) -> ArrayMesh:
		var m := ja if ja != null else ArrayMesh.new()
		if v.is_empty():
			return m
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if mat != null:
			m.surface_set_material(m.get_surface_count() - 1, mat)
		return m

static func mat_cores(rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	return m

# BACK-FACE CULLING nos modelos baixados: quase todos vêm marcados "dupla face" (a placa pinta os dois lados de
# cada triângulo). Numa malha FECHADA o lado de dentro nunca aparece, então liga o culling (metade do trabalho).
# Malha com borda solta (plano, folha, fita) continua dupla face. Mexe no material compartilhado: basta 1 vez por cena.
static var _cull_visto := {}

static func culling_fechadas(no: Node) -> void:
	var abertos := {}
	var fechados := {}
	for mi in no.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in m.get_surface_count():
			var mat := (mi as MeshInstance3D).get_active_material(s) as BaseMaterial3D
			if mat == null or mat.cull_mode != BaseMaterial3D.CULL_DISABLED or _cull_visto.has(mat.get_instance_id()):
				continue
			if _superficie_fechada(m, s):
				fechados[mat] = true
			else:
				abertos[mat] = true
	for mat in fechados:
		_cull_visto[mat.get_instance_id()] = true
		if not abertos.has(mat) and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			mat.cull_mode = BaseMaterial3D.CULL_BACK
	for mat in abertos:
		_cull_visto[mat.get_instance_id()] = true

# fechada = toda aresta (vértices soldados pela posição) é de exatamente 2 triângulos
static func _superficie_fechada(m: Mesh, s: int) -> bool:
	if m.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
		return false
	var arr := m.surface_get_arrays(s)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if ix.is_empty():
		ix.resize(v.size())
		for i in v.size():
			ix[i] = i
	var id_pos := {}
	var solda := PackedInt32Array()
	solda.resize(v.size())
	for i in v.size():
		var k := Vector3i((v[i] * 10000.0).round())
		if not id_pos.has(k):
			id_pos[k] = id_pos.size()
		solda[i] = id_pos[k]
	var arestas := {}
	for t in range(0, ix.size() - 2, 3):
		for e in [[ix[t], ix[t + 1]], [ix[t + 1], ix[t + 2]], [ix[t + 2], ix[t]]]:
			var a := solda[e[0]]
			var b := solda[e[1]]
			if a == b:
				continue
			var k := Vector2i(mini(a, b), maxi(a, b))
			arestas[k] = arestas.get(k, 0) + 1
	for k in arestas:
		if arestas[k] != 2:
			return false
	return not arestas.is_empty()
