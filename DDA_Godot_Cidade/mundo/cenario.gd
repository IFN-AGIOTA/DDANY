extends RefCounted
# MODELOS BAIXADOS DO CENÁRIO (0.69): postes, semáforos, placas, hidrante, lixeiras, caixas de energia, bueiros,
# sacos de lixo, barris, pneus, caixotes, banco, carro coberto e a VEGETAÇÃO (árvores, arbustos, samambaias, flores,
# capim e pedras). Arquivos em mundo/cenario/ (licenças e endereços em mundo/cenario/LICENCA.txt):
#   rua/*.obj ......... Quaternius · "Street Pack" (CC0)
#   natureza/*.gltf ... Quaternius · "Stylized Nature MegaKit" (CC0)
#   *.glb ............. Poly Haven (CC0), simplificados por ferramentas/preparar_cenario.py
# malha(nome) devolve UMA malha (todas as peças juntas), com a ORIGEM EMBAIXO NO MEIO, no tamanho pedido (ALTURA) e
# virada como os modelos feitos por código (braço do poste/semáforo para +X), pronta para MultiMesh: os materiais
# aceitam a cor de cada instância (tom, sujeira, outono). Feita uma vez e guardada.
# Quem usa: mundo/abandono.gd (rua) e mundo/cidade.gd (árvores e plantas dos parques e terrenos).
# Mexa AQUI para: qual arquivo é cada modelo, o tamanho e o giro.

const PASTA := "res://mundo/cenario/"

# nome: [arquivo, altura em metros (0 = tamanho real), giro extra em graus, braço para +X]
const MODELOS := {
	# ---- rua (Quaternius) ----
	"poste_duplo": ["rua/Streetlight_Double.obj", 7.5, 0.0, false],
	"poste_jardim": ["rua/Streetlight_Single.obj", 4.2, 0.0, false],
	"semaforo_braco": ["rua/TrafficLight_2.obj", 6.2, 0.0, true],
	"placa_pare": ["rua/Sign_Stop.obj", 2.7, 0.0, false],
	"placa_proibido": ["rua/Sign_NoParking.obj", 2.7, 0.0, false],
	"placa_atencao": ["rua/Sign_Triangle.obj", 2.7, 0.0, false],
	# ---- rua (Poly Haven) ----
	"hidrante": ["hidrante.glb", 0.0, 0.0, false],
	"barreira": ["barreira.glb", 0.0, 0.0, false],
	"lixeira": ["lixeira.glb", 0.0, 0.0, false],
	"caixa_energia": ["caixa_energia.glb", 0.0, 0.0, false],
	"bueiro": ["bueiro.glb", 0.0, 0.0, false],
	"saco_lixo": ["saco_lixo.glb", 0.0, 0.0, false],
	"barril": ["barril.glb", 0.0, 0.0, false],
	"pneu": ["pneu.glb", 0.0, 0.0, false],
	"caixote": ["caixote.glb", 0.0, 0.0, false],
	"carro_coberto": ["carro_coberto.glb", 0.0, 0.0, false],
	"caixa_papelao": ["caixa_papelao.glb", 0.0, 0.0, false],
	# ---- natureza (Quaternius) ----
	"arvore_1": ["natureza/CommonTree_1.gltf", 7.0, 0.0, false],
	"arvore_3": ["natureza/CommonTree_3.gltf", 8.5, 0.0, false],
	"arvore_4": ["natureza/CommonTree_4.gltf", 8.5, 0.0, false],
	"arvore_seca_1": ["natureza/DeadTree_1.gltf", 7.0, 0.0, false],
	"arvore_seca_2": ["natureza/DeadTree_2.gltf", 8.0, 0.0, false],
	"pinheiro_1": ["natureza/Pine_1.gltf", 8.0, 0.0, false],
	"pinheiro_2": ["natureza/Pine_2.gltf", 8.0, 0.0, false],
	"arvore_grande": ["natureza/TwistedTree_1.gltf", 13.0, 0.0, false],
	"arbusto": ["natureza/Bush_Common.gltf", 1.3, 0.0, false],
	"arbusto_leve": ["natureza/Bush_Leve.gltf", 1.3, 0.0, false],          # 240 triângulos: o mato em volta do jogador
	"arbusto_flores": ["natureza/Bush_Common_Flowers.gltf", 1.3, 0.0, false],
	"samambaia": ["natureza/Fern_1.gltf", 0.7, 0.0, false],
	"planta": ["natureza/Plant_1_Big.gltf", 1.2, 0.0, false],
	"flores": ["natureza/Flower_3_Group.gltf", 0.8, 0.0, false],
	"capim_alto": ["natureza/Grass_Common_Tall.gltf", 1.1, 0.0, false],
	"capim": ["natureza/Grass_Wispy_Tall.gltf", 0.9, 0.0, false],
	"pedra_1": ["natureza/Rock_Medium_1.gltf", 1.2, 0.0, false],
	"pedra_3": ["natureza/Rock_Medium_3.gltf", 1.3, 0.0, false],
}

static var _cache := {}
static var _existe := {}

static func tem(nome: String) -> bool:
	if not _existe.has(nome):
		_existe[nome] = MODELOS.has(nome) and ResourceLoader.exists(PASTA + MODELOS[nome][0])
	return _existe[nome]

static func malha(nome: String) -> ArrayMesh:
	if _cache.has(nome):
		return _cache[nome]
	var m := _montar(nome)
	_cache[nome] = m
	return m

static func _montar(nome: String) -> ArrayMesh:
	var e: Array = MODELOS[nome]
	var res = load(PASTA + e[0])
	# pedaços: [malha, transformação]
	var pedacos: Array = []
	if res is Mesh:
		pedacos.append([res, Transform3D.IDENTITY])
	elif res is PackedScene:
		var raiz: Node = res.instantiate()
		_coletar(raiz, Transform3D.IDENTITY, pedacos)
		raiz.free()
	# junta tudo (uma superfície por material) já com as transformações
	var arrays_por_sup: Array = []
	for p in pedacos:
		var mesh: Mesh = p[0]
		var t: Transform3D = p[1]
		for s in mesh.get_surface_count():
			var a: Array = mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] = t * v[i]
			a[Mesh.ARRAY_VERTEX] = v
			if a[Mesh.ARRAY_NORMAL] != null:
				var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				for i in n.size():
					n[i] = (t.basis * n[i]).normalized()
				a[Mesh.ARRAY_NORMAL] = n
			a[Mesh.ARRAY_TANGENT] = null
			var mat := mesh.surface_get_material(s)
			if mat == null and mesh is ArrayMesh:
				mat = (mesh as ArrayMesh).surface_get_material(s)
			arrays_por_sup.append([a, mat])
	# medidas: origem embaixo no meio, altura pedida, giro e braço para +X
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for par in arrays_por_sup:
		for v in (par[0][Mesh.ARRAY_VERTEX] as PackedVector3Array):
			mn = mn.min(v)
			mx = mx.max(v)
	var esc := 1.0 if float(e[1]) <= 0.0 else float(e[1]) / maxf(mx.y - mn.y, 0.001)
	var giro := deg_to_rad(float(e[2]))
	var centro := Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5)
	if bool(e[3]):
		# braço (semáforo): a origem vai para o pé do poste e a ponta do braço fica em +X
		var topo := _media(arrays_por_sup, mn.y + (mx.y - mn.y) * 0.8, true)
		var pe := _media(arrays_por_sup, mn.y + (mx.y - mn.y) * 0.1, false)
		var braco := Vector2(topo.x - pe.x, topo.z - pe.z)
		if braco.length() > 0.001:
			giro += atan2(braco.y, braco.x)
		centro = Vector3(pe.x, mn.y, pe.z)
	var final := Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * esc), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -centro)
	var am := ArrayMesh.new()
	for par in arrays_por_sup:
		var a: Array = par[0]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		for i in v.size():
			v[i] = final * v[i]
		a[Mesh.ARRAY_VERTEX] = v
		if a[Mesh.ARRAY_NORMAL] != null:
			var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			for i in nn.size():
				nn[i] = (Basis(Vector3.UP, giro) * nn[i]).normalized()
			a[Mesh.ARRAY_NORMAL] = nn
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(am.get_surface_count() - 1, _material(par[1]))
	return am

# média dos vértices acima (acima = true) ou abaixo de uma altura
static func _media(sups: Array, y: float, acima: bool) -> Vector3:
	var soma := Vector3.ZERO
	var n := 0
	for par in sups:
		for v in (par[0][Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if (v.y > y) == acima:
				soma += v
				n += 1
	return soma / maxf(n, 1)

static func _coletar(n: Node, t: Transform3D, saida: Array) -> void:
	var tt := t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		# material trocado no nó (surface override) vale mais que o da malha
		if mi.get_surface_override_material_count() > 0:
			var copia := (mesh as ArrayMesh).duplicate() as ArrayMesh
			for s in copia.get_surface_count():
				var mo := mi.get_surface_override_material(s)
				if mo != null:
					copia.surface_set_material(s, mo)
			mesh = copia
		saida.append([mesh, tt])
	for c in n.get_children():
		_coletar(c, tt, saida)

# material que aceita a cor de cada instância do MultiMesh (multiplica a textura/cor do modelo)
static func _material(m: Material) -> Material:
	var sm: StandardMaterial3D
	if m is StandardMaterial3D:
		sm = (m as StandardMaterial3D).duplicate()
	else:
		sm = StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	sm.vertex_color_is_srgb = true
	sm.metallic = minf(sm.metallic, 0.4)
	sm.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if sm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or sm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR       # folhas: recorte (mais leve e sem erro de ordem)
		sm.alpha_scissor_threshold = 0.5
	return sm
