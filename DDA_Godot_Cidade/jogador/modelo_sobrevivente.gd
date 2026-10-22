extends Node3D
# SOBREVIVENTE: o personagem do jogador (modo livre e história).
# Corpo: homem dos "Universal Base Characters" do Quaternius (CC0): pele com textura, olhos, sobrancelhas, cabelos e
# barba, preparado por ferramentas/preparar_personagem.gd para jogador/sobrevivente/corpo.scn (as animações também
# foram convertidas para o esqueleto dele).
# Animações (jogador/sobrevivente/animacoes.res, mesmo esqueleto): parado, andar, correr, pular, cair, mirar,
# atirar, morrer, agachado, andar agachado (+ soco, golpe, rolar, pegar... para usar depois).
# O jogador/animador_modelo.gd escolhe a animação pelo estado (nomes exatos em NOMES_ANIM).
#
# ROUPA DE VERDADE: cada vértice do corpo sabe a que PARTE pertence (rosto, pescoço, tronco, braço, antebraço, mão,
# quadril, coxa, canela, pé). Cada roupa é uma "casca" feita dessas partes, um pouco por fora do corpo (acompanha a
# animação), com a cor do item; a pele que fica embaixo é escondida (não atravessa a roupa).
# vestir(inventario) lê o que está equipado (cabeça, camisa, colete, calça, mochila):
#   camisa -> camiseta (manga curta), moletom (manga comprida), jaqueta/capa (manga comprida, mais grossa)
#   calça -> calça (quadril até o tornozelo) · sem camisa: regata · sem calça: short · botas sempre
#   cabeça -> topo da cabeça (cabelo coberto) + o MODELO 3D do capacete/boné/gorro/lanterna
#   colete -> "casca" feita do próprio tronco do corpo, um pouco maior (acompanha a animação), com bolsos
#   mochila/pochete -> MODELO 3D nas costas/cintura (equipamentos/modelos_equip.gd)
#   arma do OMBRO (fuzil, espingarda...) aparece pendurada nas costas e a do COLDRE na cintura, quando
#   não estão na mão
# Sem nada: regata clara, short escuro e botas. Para um item novo aparecer, coloque a cor dele nas tabelas.
# Chapéu/capacete/gorro escondem o cabelo. CABELOS = penteado e barba que o personagem usa.
# A arma da mão fica presa ao osso da MÃO DIREITA (acompanha as animações).
# Mexa AQUI para: cores da pele/cabelo/roupas, tabelas de roupas e onde a arma fica.

const Malhas := preload("res://mundo/malhas.gd")
const Equip := preload("res://equipamentos/modelos_equip.gd")
const ModelosArmas := preload("res://armas/modelos_armas.gd")
const IkFuzil := preload("res://jogador/ik_fuzil.gd")
const CamadaAcao := preload("res://jogador/camada_acao.gd")
const CamadaPostura := preload("res://jogador/camada_postura.gd")
const PASTA := "res://jogador/sobrevivente/"
const NOMES_ANIM := {"parado": "parado", "andar": "andar", "correr": "correr", "pular": "pular", "cair": "cair",
	"mirar": "mirar", "atirar": "atirar", "morrer": "morrer", "agachado": "agachado", "andar_agachado": "andar_agachado"}

enum { ROSTO, CABELO, PESCOCO, TRONCO, BRACO, ANTEBRACO, MAO, QUADRIL, COXA, CANELA, PE, OLHOS }
# roupa -> [partes do corpo, grossura (m)]
const ROUPAS := {"regata": [[TRONCO], 0.006], "camiseta": [[TRONCO, BRACO], 0.007], "manga_longa": [[TRONCO, BRACO, ANTEBRACO], 0.009],
	"jaqueta": [[TRONCO, BRACO, ANTEBRACO], 0.022], "short": [[QUADRIL, COXA], 0.011], "calca": [[QUADRIL, COXA, CANELA], 0.013],
	"botas": [[PE, CANELA], 0.011]}
const TIPO_CAMISA := {"camiseta": "camiseta", "moletom": "manga_longa", "jaqueta": "jaqueta", "capa_chuva": "jaqueta"}
const CABELOS := ["Hair_Buzzed", "Hair_Beard"]
const PENTEADOS := ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Beard"]

const PELE := Color(0.72, 0.55, 0.43)
const CABELO_COR := Color(0.32, 0.22, 0.15)            # multiplica a textura cinza do cabelo (castanho escuro)
const REGATA := Color(0.78, 0.76, 0.70)
const SHORT := Color(0.18, 0.18, 0.20)
const BOTAS := Color(0.16, 0.12, 0.09)
# item -> [cor, manga comprida?]
const CAMISAS := {"camiseta": [Color(0.32, 0.36, 0.30), false], "moletom": [Color(0.30, 0.30, 0.33), true],
	"jaqueta": [Color(0.27, 0.31, 0.23), true], "capa_chuva": [Color(0.74, 0.60, 0.14), true]}
const CALCAS := {"calca": Color(0.31, 0.33, 0.25), "jeans": Color(0.20, 0.26, 0.40)}
const COLETES := {"colete": Color(0.27, 0.29, 0.22), "colete_policia": Color(0.11, 0.12, 0.15)}
const CABECA := {"capacete": Color(0.25, 0.27, 0.22), "gorro": Color(0.14, 0.14, 0.17), "bone": Color(0.18, 0.24, 0.44)}

# pele com textura; as partes cobertas pela roupa somem (esconde[parte] = 1)
const SHADER := """
shader_type spatial;
uniform sampler2D pele : source_color, filter_linear_mipmap;
uniform sampler2D normal_pele : hint_normal, filter_linear_mipmap;
uniform sampler2D rugosidade : hint_default_white, filter_linear_mipmap;
uniform float esconde[12];
varying flat float regiao;          // flat: cada triângulo pega UMA parte (sem faixas misturadas na divisa)
void vertex() { regiao = COLOR.r; }
void fragment() {
	int r = clamp(int(regiao * 15.0 + 0.5), 0, 11);
	if (esconde[r] > 0.5) { discard; }
	ALBEDO = texture(pele, UV).rgb;
	NORMAL_MAP = texture(normal_pele, UV).rgb;
	ROUGHNESS = texture(rugosidade, UV).r;
}
"""

static var _cena: PackedScene = null
static var _anims: AnimationLibrary = null
static var _shader: Shader = null

var corpo: Node3D
var esqueleto: Skeleton3D
var anim: AnimationPlayer
var _mat: ShaderMaterial
var _cores: Array = []
var _ponto_arma: Node3D
# FUZIS (m4, ak, espingarda, rifle de caça) são segurados com as DUAS mãos: o fuzil fica preso ao peito e
# as mãos vão até ele por IK (cinemática inversa, jogador/ik_fuzil.gd). Arma baixa (diagonal na frente do corpo) ou no ombro mirando.
const FUZIS := ["m4", "ak", "espingarda", "rifle_caca"]
var _ponto_fuzil: Node3D
var camada                             # jogador/camada_acao.gd: ações só na parte de cima (recarregar andando...)
var postura                            # jogador/camada_postura.gd: como segura a arma (pistola, faca, taco...)
var _ik: IkFuzil
var _mira := 0.0
var _pecas := {}                       # chave ("cabeca", "mochila", "cinto", "ombro", "coldre") -> [id, nó]
var _colete: MeshInstance3D
var _colete_id := ""
var _corpo_mi: MeshInstance3D
var _roupas := {}                      # tipo -> MeshInstance3D (casca da roupa)
static var _malhas_roupa := {}
static var _mats_roupa := {}

func _ready() -> void:
	if _cena == null:
		_cena = load(PASTA + "corpo.scn")
		_anims = load(PASTA + "animacoes.res")
		_shader = Shader.new()
		_shader.code = SHADER
	corpo = _cena.instantiate()
	add_child(corpo)
	esqueleto = corpo.find_child("Skeleton3D", true, false)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_corpo_mi = esqueleto.get_node("Corpo") as MeshInstance3D
	var mp: StandardMaterial3D = _corpo_mi.mesh.surface_get_material(0)
	_mat.set_shader_parameter("pele", mp.albedo_texture)
	_mat.set_shader_parameter("normal_pele", mp.normal_texture)
	_mat.set_shader_parameter("rugosidade", mp.roughness_texture)
	_corpo_mi.material_override = _mat
	# cabelo, barba e sobrancelhas: a textura é cinza, a cor vem daqui
	for c in PENTEADOS + ["Eyebrows"]:
		var h := esqueleto.get_node_or_null(c) as MeshInstance3D
		if h != null:
			var mh: StandardMaterial3D = (h.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
			mh.albedo_color = CABELO_COR
			h.material_override = mh
			if c != "Eyebrows":
				h.visible = c in CABELOS
	for mi in corpo.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	corpo.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", _anims)
	anim.play("parado")
	_criar_ponto_arma()
	_criar_ponto_fuzil()
	vestir(null)

# ---------- roupa ----------
func vestir(inventario) -> void:
	var slots: Dictionary = inventario.slots if inventario != null else {}
	var usar := {}                                            # tipo de roupa -> cor
	var it = slots.get("camisa")
	if it != null and CAMISAS.has(it.id):
		usar[TIPO_CAMISA.get(it.id, "camiseta")] = CAMISAS[it.id][0]
	else:
		usar["regata"] = REGATA
	it = slots.get("calca")
	if it != null and CALCAS.has(it.id):
		usar["calca"] = CALCAS[it.id]
	else:
		usar["short"] = SHORT
	usar["botas"] = BOTAS
	var esconde: Array = []
	esconde.resize(12)
	esconde.fill(0.0)
	for tipo in ROUPAS:
		var vai: bool = usar.has(tipo)
		if vai and not _roupas.has(tipo):
			_roupas[tipo] = _criar_roupa(tipo)
		if _roupas.has(tipo):
			var mi: MeshInstance3D = _roupas[tipo]
			mi.visible = vai
			if vai:
				mi.material_override = _mat_roupa(usar[tipo])
				for reg in ROUPAS[tipo][0]:
					esconde[reg] = 1.0
	esconde[CANELA] = 1.0 if usar.has("calca") else 0.0   # com short a canela aparece (a bota cobre só embaixo)
	_mat.set_shader_parameter("esconde", PackedFloat32Array(esconde))
	# chapéu, capacete e gorro escondem o cabelo (a barba fica)
	var cab = slots.get("cabeca")
	var cobre: bool = cab != null and cab.id in ["capacete", "gorro", "bone"]
	for c in PENTEADOS:
		var h := esqueleto.get_node_or_null(c) as Node3D
		if h != null:
			h.visible = c in CABELOS and (c == "Hair_Beard" or not cobre)
	# peças 3D
	_peca("cabeca", slots.get("cabeca"))
	_peca("mochila", slots.get("mochila"))
	_peca("cinto", slots.get("cinto"))
	var colete = slots.get("colete")
	_vestir_colete(colete.id if colete != null and COLETES.has(colete.id) else "")
	var na_mao = slots.get("maos")
	var ombro = slots.get("ombro")
	var coldre = slots.get("coldre")
	_arma_no_corpo("ombro", ombro if ombro != null and ombro != na_mao and ombro.eh_arma() else null, slots.get("mochila") != null)
	_arma_no_corpo("coldre", coldre if coldre != null and coldre != na_mao and coldre.eh_arma() else null, false)

func _mat_roupa(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats_roupa.has(k):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = c
		m.roughness = 0.92
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats_roupa[k] = m
	return _mats_roupa[k]

# casca de uma roupa: as faces das partes do corpo, empurradas um pouco para fora, presas aos mesmos ossos
func _criar_roupa(tipo: String) -> MeshInstance3D:
	if not _malhas_roupa.has(tipo):
		_malhas_roupa[tipo] = _malha_roupa(tipo)
	var mi := MeshInstance3D.new()
	mi.name = "Roupa_" + tipo
	mi.mesh = _malhas_roupa[tipo]
	mi.skin = _corpo_mi.skin
	esqueleto.add_child(mi)
	mi.skeleton = NodePath("..")
	return mi

func _malha_roupa(tipo: String) -> ArrayMesh:
	var a: Array = _corpo_mi.mesh.surface_get_arrays(0)
	var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var C: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var B: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var I: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var nb := W.size() / V.size()
	var regs: Array = ROUPAS[tipo][0]
	var grosso: float = ROUPAS[tipo][1]
	# botas: o pé e só a parte de baixo da canela
	var y_tornozelo := -1e9
	if tipo == "botas":
		for i in V.size():
			if int(C[i].r * 15.0 + 0.5) == PE:
				y_tornozelo = maxf(y_tornozelo, V[i].y)
	var novo := {}
	var V2 := PackedVector3Array()
	var N2 := PackedVector3Array()
	var C2 := PackedColorArray()
	var B2 := PackedInt32Array()
	var W2 := PackedFloat32Array()
	var I2 := PackedInt32Array()
	for t in range(0, I.size(), 3):
		var ok := true
		for j in 3:
			var vi: int = I[t + j]
			var rg := int(C[vi].r * 15.0 + 0.5)
			if not regs.has(rg):
				ok = false
			elif tipo == "botas" and rg == CANELA and V[vi].y > y_tornozelo + 0.1:
				ok = false
		if not ok:
			continue
		for j in 3:
			var vi: int = I[t + j]
			if not novo.has(vi):
				novo[vi] = V2.size()
				var g := grosso * (1.4 if tipo == "botas" and V[vi].y < 0.04 else 1.0)
				V2.append(V[vi] + N[vi] * g)
				N2.append(N[vi])
				var v := 0.86 + 0.28 * C[vi].g
				C2.append(Color(v, v, v))
				for k in nb:
					B2.append(B[vi * nb + k])
					W2.append(W[vi * nb + k])
			I2.append(novo[vi])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V2
	arr[Mesh.ARRAY_NORMAL] = N2
	arr[Mesh.ARRAY_COLOR] = C2
	arr[Mesh.ARRAY_BONES] = B2
	arr[Mesh.ARRAY_WEIGHTS] = W2
	arr[Mesh.ARRAY_INDEX] = I2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
	return m

func cor_da_regiao(r: int) -> Color:
	return _cores[r] if r < _cores.size() else Color.BLACK

# ---------- peças 3D presas aos ossos ----------
func _peca(chave: String, item) -> void:
	var id: String = item.id if item != null else ""
	var atual: Array = _pecas.get(chave, ["", null])
	if atual[0] == id:
		return
	if atual[1] != null and is_instance_valid(atual[1]):
		atual[1].queue_free()
	_pecas[chave] = ["", null]
	if id == "" or not Equip.tem(id):
		return
	var mi := Equip.instancia(id)
	if mi == null:
		return
	var enc: Array = Equip.ENCAIXE[id]
	_anexo(enc[0]).add_child(mi)
	mi.transform = _no_osso(enc[0], Transform3D(Basis.from_euler(enc[2] * PI / 180.0).scaled(Vector3.ONE * enc[3]), enc[1]))
	_pecas[chave] = [id, mi]

# arma pendurada: ombro = nas costas, na diagonal (por cima da mochila) · coldre = na cintura, cano para baixo
func _arma_no_corpo(chave: String, item, com_mochila: bool) -> void:
	var id: String = item.def().get("arma", "") if item != null else ""
	var atual: Array = _pecas.get(chave, ["", null])
	if atual[0] == id + str(com_mochila):
		return
	if atual[1] != null and is_instance_valid(atual[1]):
		atual[1].queue_free()
	_pecas[chave] = ["", null]
	if id == "":
		return
	var n := ModelosArmas.construir(id)
	for nome in ["Cano", "Acc_cano", "Acc_mira"]:
		var x := n.get_node_or_null(nome)
		if x != null:
			x.visible = nome == "Cano"
	var dir := 1.0 if esqueleto.get_bone_global_rest(esqueleto.find_bone("upperarm_r")).origin.x > 0.0 else -1.0
	var osso := "spine_03" if chave == "ombro" else "pelvis"
	var t: Transform3D
	if chave == "ombro":
		var z := Vector3(-0.45 * dir, 1.0, 0.0).normalized()        # cano para cima, na diagonal
		var x := Vector3(0, 0, -1)                                  # o lado da arma virado para trás
		t = Transform3D(Basis(x, z.cross(x), z), Vector3(0.0, -0.12, -0.3 if com_mochila else -0.16))
	else:
		var z := Vector3(0, -1, 0.1).normalized()                   # cano para baixo
		var x := Vector3(dir, 0, 0)
		t = Transform3D(Basis(x, z.cross(x), z), Vector3(dir * 0.19, 0.0, 0.03))
	_anexo(osso).add_child(n)
	n.transform = _no_osso(osso, t)
	_pecas[chave] = [id + str(com_mochila), n]

# COLETE: "casca" do tronco do próprio corpo, empurrada para fora, presa aos mesmos ossos (deforma junto)
static var _cascas := {}
func _vestir_colete(id: String) -> void:
	if id == _colete_id:
		return
	_colete_id = id
	if _colete != null:
		_colete.queue_free()
		_colete = null
	if id == "":
		return
	if not _cascas.has(id):
		_cascas[id] = _fazer_casca(id)
	var corpo_mi: MeshInstance3D = _corpo_mi
	_colete = MeshInstance3D.new()
	_colete.name = "Colete"
	_colete.mesh = _cascas[id]
	_colete.skin = corpo_mi.skin
	esqueleto.add_child(_colete)
	_colete.skeleton = NodePath("..")

func _fazer_casca(id: String) -> ArrayMesh:
	var corpo_mi: MeshInstance3D = _corpo_mi
	var a: Array = corpo_mi.mesh.surface_get_arrays(0)
	var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var C: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var B: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var I: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var nb := W.size() / V.size()
	var base: Color = COLETES[id]
	var grosso := 0.03 if id == "colete_policia" else 0.026
	var novo := {}
	var V2 := PackedVector3Array()
	var N2 := PackedVector3Array()
	var C2 := PackedColorArray()
	var B2 := PackedInt32Array()
	var W2 := PackedFloat32Array()
	var I2 := PackedInt32Array()
	var regiao := func(i: int) -> int: return int(C[i].r * 15.0 + 0.5)
	# altura do peito (para os bolsos do colete tático)
	var y_min := 1e9
	var y_max := -1e9
	for i in V.size():
		if regiao.call(i) == TRONCO:
			y_min = minf(y_min, V[i].y)
			y_max = maxf(y_max, V[i].y)
	for t in range(0, I.size(), 3):
		var ok := true
		for j in 3:
			var rg: int = regiao.call(I[t + j])
			if rg != TRONCO and rg != QUADRIL:
				ok = false
		if not ok:
			continue
		# do quadril, só a parte de cima (cintura)
		var cy := (V[I[t]].y + V[I[t + 1]].y + V[I[t + 2]].y) / 3.0
		if cy < y_min + (y_max - y_min) * 0.05:
			continue
		for j in 3:
			var vi: int = I[t + j]
			if not novo.has(vi):
				novo[vi] = V2.size()
				var p: Vector3 = V[vi] + N[vi] * grosso
				V2.append(p)
				N2.append(N[vi])
				var f := (p.y - y_min) / maxf(y_max - y_min, 0.001)
				var c := base * (0.9 + 0.2 * C[vi].g)
				if id == "colete" and p.z > 0.05 and f > 0.25 and f < 0.55 and absf(p.x) < 0.14:
					c = base * 0.75                                    # fileira de bolsos na frente
				C2.append(c)
				for k in nb:
					B2.append(B[vi * nb + k])
					W2.append(W[vi * nb + k])
			I2.append(novo[vi])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V2
	arr[Mesh.ARRAY_NORMAL] = N2
	arr[Mesh.ARRAY_COLOR] = C2
	arr[Mesh.ARRAY_BONES] = B2
	arr[Mesh.ARRAY_WEIGHTS] = W2
	arr[Mesh.ARRAY_INDEX] = I2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0)
	m.surface_set_material(0, Malhas.mat_cores(0.8))
	return m

# ---------- armas (jogador/armas: armas.anexar chama segurar_arma) ----------
func _criar_ponto_arma() -> void:
	# a arma fica NA MÃO DIREITA (acompanha as animações). O encaixe é medido na pose de MIRAR: nela o cano
	# aponta para a frente do corpo (+Z do esqueleto) e a empunhadura fica na palma.
	var ba := _anexo("hand_r")
	_ponto_arma = Node3D.new()
	_ponto_arma.name = "PontoArma"
	ba.add_child(_ponto_arma)
	var i := esqueleto.find_bone("hand_r")
	anim.play("mirar")
	anim.seek(0.4, true)
	var gh := esqueleto.get_bone_global_pose(i)
	var palma := gh.origin + gh.basis.y.normalized() * 0.07 - gh.basis.z.normalized() * 0.01
	_ponto_arma.transform = gh.affine_inverse() * Transform3D(Basis.IDENTITY, palma)
	anim.play("parado")

func segurar_arma(tipo: String, no: Node3D) -> void:
	if tipo in FUZIS:
		_ponto_fuzil.add_child(no)
	else:
		_ponto_arma.add_child(no)

func _criar_ponto_fuzil() -> void:
	# postura da arma, depois camada de ação, depois IK do fuzil (os modificadores rodam na ordem dos filhos)
	postura = CamadaPostura.new()
	postura.name = "CamadaPostura"
	esqueleto.add_child(postura)
	postura.preparar(esqueleto, anim)
	camada = CamadaAcao.new()
	camada.name = "CamadaAcao"
	esqueleto.add_child(camada)
	camada.preparar(esqueleto)
	# preso ao ESQUELETO (sempre de frente), não ao peito: a animação de mirar (de pistola) gira o tronco para o
	# lado e o fuzil ficaria atravessado. jogador/ik_fuzil.gd põe o fuzil no lugar e leva as mãos até ele.
	_ponto_fuzil = Node3D.new()
	_ponto_fuzil.name = "PontoFuzil"
	esqueleto.add_child(_ponto_fuzil)
	_ik = IkFuzil.new()
	_ik.name = "IkFuzil"
	_ik.ponto = _ponto_fuzil
	esqueleto.add_child(_ik)
	_ik.preparar(esqueleto, anim)
	_ik.active = false

func _process(dt: float) -> void:
	# IK só com um fuzil visível na mão
	var arma: Node3D = null
	for c in _ponto_fuzil.get_children():
		if c is Node3D and c.visible:
			arma = c
	_ik.active = arma != null
	if arma == null:
		return
	# a mão esquerda segura mais ou menos no meio do caminho entre a empunhadura e a boca do cano
	var cano := arma.get_node_or_null("Cano") as Node3D
	_ik.mao_esq_z = clampf(cano.position.z * 0.5, 0.22, 0.38) if cano != null else 0.25
	var j = get_parent().get_parent() if get_parent() != null else null
	var alvo := 0.0
	if j != null and j.get("armas") != null:
		alvo = clampf(float(j.armas.aim), 0.0, 1.0)
	_mira = move_toward(_mira, alvo, dt * 5.0)
	_ik.mira = _mira

func pegar_ponto_arma() -> Node3D:
	return _ponto_arma

# BoneAttachment3D num osso (um só por osso)
func _anexo(osso: String) -> BoneAttachment3D:
	var nome := "Anexo_" + osso
	var ba := esqueleto.get_node_or_null(nome) as BoneAttachment3D
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = nome
		esqueleto.add_child(ba)
		ba.bone_name = osso
	return ba

# transforma uma posição "do corpo" (espaço do esqueleto, relativa ao osso, sem a rotação dele) para o
# espaço local do osso em repouso
func _no_osso(osso: String, t: Transform3D) -> Transform3D:
	var g := esqueleto.get_bone_global_rest(esqueleto.find_bone(osso))
	var alvo := Transform3D(t.basis, g.origin + t.origin)
	return g.affine_inverse() * alvo
