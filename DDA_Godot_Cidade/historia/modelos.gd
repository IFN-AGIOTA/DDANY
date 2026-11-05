extends RefCounted
# 1.14.1 · MODELOS BAIXADOS DO MODO HISTÓRIA (Kenney, CC0 · licenças em historia/modelos/*/LICENCA.txt):
#   historia/modelos/moveis/   "Furniture Kit": banquetas, cadeiras, sofá, cama, cozinha, luminárias, plantas...
#   historia/modelos/comida/   "Food Kit": garrafas, copos, canecas, latas
#   historia/modelos/veiculos/ "Car Kit": viatura de polícia, ambulância, táxi, cone
# Os modelos vêm pequenos (uma cadeira tem 0,47) e com a origem num canto: criar() põe o modelo com o MEIO DA BASE na
# posição pedida e no tamanho de verdade (medida em metros no eixo escolhido: 1 = altura, 2 = comprimento).
# Mexa AQUI para: o tamanho de cada coisa (quem chama passa a medida) e a viatura (barra de luzes, giroflex).

const PASTA := "res://historia/modelos/"

static var _cache := {}              # nome -> [PackedScene, AABB]
static var _tintas := {}             # [material, tinta] -> material tingido (um só por par)

static func _junta(n: Node, t: Transform3D, acc: Array) -> void:
	var tt := t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a: AABB = tt * (n as MeshInstance3D).mesh.get_aabb()
		if acc.is_empty():
			acc.append(a)
		else:
			acc[0] = (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_junta(c, tt, acc)

static func info(nome: String) -> Array:
	if _cache.has(nome):
		return _cache[nome]
	var cena: PackedScene = load(PASTA + nome + ".glb")
	var n := cena.instantiate()
	var acc: Array = []
	_junta(n, Transform3D(), acc)
	n.free()
	var r := [cena, acc[0] if not acc.is_empty() else AABB(Vector3.ZERO, Vector3.ONE)]
	_cache[nome] = r
	return r

# põe o modelo "pasta/nome" em pai (posição LOCAL de pai), girado em Y, com "medida" metros no eixo (1 = Y, 2 = Z)
# tinta: multiplica as cores do modelo (os móveis da Kenney são brancos/rosados; num bar escuro, madeira e couro)
static func criar(pai: Node, nome: String, pos: Vector3, giro: float, medida: float, eixo := 1, tinta := Color(1, 1, 1)) -> Node3D:
	var inf := info(nome)
	var a: AABB = inf[1]
	var esc := medida / maxf(a.size[eixo], 0.001)
	var raiz := Node3D.new()
	raiz.name = nome.get_file()
	pai.add_child(raiz)
	raiz.position = pos
	raiz.rotation.y = giro
	var n: Node3D = (inf[0] as PackedScene).instantiate()
	n.scale = Vector3.ONE * esc
	n.position = -Vector3(a.position.x + a.size.x * 0.5, a.position.y, a.position.z + a.size.z * 0.5) * esc
	raiz.add_child(n)
	raiz.set_meta("tam", a.size * esc)
	if tinta != Color(1, 1, 1):
		_tingir(n, tinta)
	return raiz

static func _tingir(n: Node, tinta: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m is StandardMaterial3D:
				var k := [m, tinta]
				if not _tintas.has(k):
					var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					d.albedo_color = d.albedo_color * tinta
					_tintas[k] = d
				mi.set_surface_override_material(i, _tintas[k])
	for c in n.get_children():
		_tingir(c, tinta)

# tamanho (m) de um modelo criado
static func tamanho(no: Node3D) -> Vector3:
	return no.get_meta("tam", Vector3.ONE)

# VIATURA DE POLÍCIA de verdade (Car Kit "police", 4,6 m) com o giroflex: 2 luzes que piscam (vermelha e azul).
# t = onde (global), virada para +Z de t. Devolve [nó, [luz vermelha, luz azul]] (quem chama faz piscar ou não)
static func viatura(pai: Node, t: Transform3D, alcance := 12.0, energia := 2.6) -> Array:
	var raiz := Node3D.new()
	raiz.name = "Viatura"
	pai.add_child(raiz)
	raiz.global_transform = t
	var carro := criar(raiz, "veiculos/police", Vector3.ZERO, 0.0, 4.6, 2)
	var alto: float = tamanho(carro).y
	var luzes: Array = []
	for k in 2:
		var o := OmniLight3D.new()
		o.light_color = Color(1, 0.1, 0.1) if k == 0 else Color(0.15, 0.3, 1.0)
		o.omni_range = alcance
		o.light_energy = energia
		o.position = Vector3((k - 0.5) * 0.6, alto + 0.25, 0.0)
		raiz.add_child(o)
		luzes.append(o)
	return [raiz, luzes]

# a malha (uma só) de um modelo simples, já na escala e com a base no chão: para MultiMesh (cones)
static func malha(nome: String, medida: float, eixo := 1) -> Array:
	var inf := info(nome)
	var a: AABB = inf[1]
	var esc := medida / maxf(a.size[eixo], 0.001)
	var n := (inf[0] as PackedScene).instantiate()
	var achou: Array = []
	_primeira_malha(n, Transform3D(), achou)
	n.free()
	if achou.is_empty():
		return [null, Transform3D()]
	var ajuste := Transform3D(Basis.from_scale(Vector3.ONE * esc), -Vector3(a.position.x + a.size.x * 0.5, a.position.y, a.position.z + a.size.z * 0.5) * esc)
	return [achou[0], ajuste * achou[1]]

static func _primeira_malha(n: Node, t: Transform3D, achou: Array) -> void:
	if not achou.is_empty():
		return
	var tt := t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		achou.append((n as MeshInstance3D).mesh)
		achou.append(tt)
		return
	for c in n.get_children():
		_primeira_malha(c, tt, achou)
