extends Node3D
# SOBREVIVENTE: o personagem do jogador no MODO LIVRE (o modo história continua com o soldado antigo).
# Corpo: manequim masculino de proporção humana da "Universal Animation Library 2" do Quaternius (CC0), SEM
# equipamento acoplado, convertido por ferramentas/preparar_jogador.gd para jogador/sobrevivente/corpo.scn.
# Animações (jogador/sobrevivente/animacoes.res, mesmo esqueleto): parado, andar, correr, pular, cair, mirar,
# atirar, morrer, agachado, andar agachado (+ soco, golpe, rolar, pegar... para usar depois).
# O jogador/animador_modelo.gd escolhe a animação pelo estado (nomes exatos em NOMES_ANIM).
#
# ROUPA APARECE NO CORPO: cada vértice sabe a que PARTE do corpo pertence (rosto, cabelo, pescoço, tronco,
# braço, antebraço, mão, quadril, coxa, canela, pé, olhos) e o shader pinta cada parte com uma cor.
# vestir(inventario) lê o que está equipado (cabeça, camisa, colete, calça, mochila) e troca as cores:
#   camisa -> tronco e braços (camiseta = manga curta) · calça -> quadril, coxas e canelas
#   colete -> tronco (os braços continuam com a camisa) · cabeça -> topo da cabeça (capacete, gorro, boné)
#   mochila -> peça 3D nas costas (presa ao osso do tronco)
# Sem nada: regata clara, short escuro e botas. Para um item novo aparecer, coloque a cor dele nas tabelas.
# As armas ficam presas ao peito (acompanham o tronco), apontando para a frente.
# Mexa AQUI para: cores da pele/cabelo/roupas, tabelas de roupas e onde a arma fica.

const Malhas := preload("res://mundo/malhas.gd")
const PASTA := "res://jogador/sobrevivente/"
const NOMES_ANIM := {"parado": "parado", "andar": "andar", "correr": "correr", "pular": "pular", "cair": "cair",
	"mirar": "mirar", "atirar": "atirar", "morrer": "morrer", "agachado": "agachado", "andar_agachado": "andar_agachado"}

enum { ROSTO, CABELO, PESCOCO, TRONCO, BRACO, ANTEBRACO, MAO, QUADRIL, COXA, CANELA, PE, OLHOS }

const PELE := Color(0.72, 0.55, 0.43)
const CABELO_COR := Color(0.12, 0.09, 0.07)
const REGATA := Color(0.78, 0.76, 0.70)
const SHORT := Color(0.18, 0.18, 0.20)
const BOTAS := Color(0.16, 0.12, 0.09)
# item -> [cor, manga comprida?]
const CAMISAS := {"camiseta": [Color(0.32, 0.36, 0.30), false], "moletom": [Color(0.30, 0.30, 0.33), true],
	"jaqueta": [Color(0.27, 0.31, 0.23), true], "capa_chuva": [Color(0.74, 0.60, 0.14), true]}
const CALCAS := {"calca": Color(0.31, 0.33, 0.25), "jeans": Color(0.20, 0.26, 0.40)}
const COLETES := {"colete": Color(0.21, 0.23, 0.19), "colete_policia": Color(0.11, 0.12, 0.15)}
const CABECA := {"capacete": Color(0.25, 0.27, 0.22), "gorro": Color(0.14, 0.14, 0.17), "bone": Color(0.18, 0.24, 0.44)}
const MOCHILA_COR := Color(0.24, 0.26, 0.20)

const SHADER := """
shader_type spatial;
uniform vec4 cores[12];
varying flat float regiao;          // flat: cada triângulo pega UMA parte (sem faixas misturadas na divisa)
void vertex() { regiao = COLOR.r; }
void fragment() {
	int r = clamp(int(regiao * 15.0 + 0.5), 0, 11);
	ALBEDO = cores[r].rgb * (0.86 + 0.28 * COLOR.g);
	ROUGHNESS = 0.85;
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
var _mochila: MeshInstance3D

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
	for mi in corpo.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	corpo.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", _anims)
	anim.play("parado")
	_criar_ponto_arma()
	vestir(null)

# ---------- roupa ----------
func vestir(inventario) -> void:
	_cores = []
	_cores.resize(12)
	for i in 12:
		_cores[i] = PELE
	_cores[CABELO] = CABELO_COR
	_cores[OLHOS] = Color(0.06, 0.05, 0.05)
	_cores[TRONCO] = REGATA
	_cores[QUADRIL] = SHORT
	_cores[COXA] = SHORT
	_cores[PE] = BOTAS
	var slots: Dictionary = inventario.slots if inventario != null else {}
	var it = slots.get("camisa")
	if it != null and CAMISAS.has(it.id):
		var c: Color = CAMISAS[it.id][0]
		_cores[TRONCO] = c
		_cores[BRACO] = c
		if CAMISAS[it.id][1]:
			_cores[ANTEBRACO] = c
	it = slots.get("calca")
	if it != null and CALCAS.has(it.id):
		for reg in [QUADRIL, COXA, CANELA]:
			_cores[reg] = CALCAS[it.id]
	it = slots.get("colete")
	if it != null and COLETES.has(it.id):
		_cores[TRONCO] = COLETES[it.id]
	it = slots.get("cabeca")
	if it != null and CABECA.has(it.id):
		_cores[CABELO] = CABECA[it.id]
	var cores := PackedColorArray()
	for c in _cores:
		cores.append(c)
	_mat.set_shader_parameter("cores", cores)
	_por_mochila(slots.get("mochila") != null)

func cor_da_regiao(r: int) -> Color:
	return _cores[r] if r < _cores.size() else Color.BLACK

func _por_mochila(tem: bool) -> void:
	if tem and _mochila == null:
		var c := Malhas.Construtor.new()
		c.caixa(Vector3(0, 0, 0), Vector3(0.3, 0.4, 0.16), MOCHILA_COR)
		c.caixa(Vector3(0, -0.1, -0.1), Vector3(0.24, 0.16, 0.06), MOCHILA_COR * 0.85)     # bolso (para trás)
		c.caixa(Vector3(0, 0.21, 0.0), Vector3(0.28, 0.05, 0.15), MOCHILA_COR * 0.75)     # tampa
		for sx in [-0.09, 0.09]:
			c.caixa(Vector3(sx, 0.05, 0.1), Vector3(0.04, 0.34, 0.03), MOCHILA_COR * 0.6) # alças
		_mochila = MeshInstance3D.new()
		_mochila.mesh = c.malha(Malhas.mat_cores())
		var ba := _anexo("spine_03")
		ba.add_child(_mochila)
		# nas costas: no espaço do esqueleto a frente é +Z, então atrás = -Z
		_mochila.transform = _no_osso("spine_03", Transform3D(Basis.IDENTITY, Vector3(0, -0.1, -0.17)))
	if _mochila != null:
		_mochila.visible = tem

# ---------- armas (jogador/armas: armas.anexar chama segurar_arma) ----------
func _criar_ponto_arma() -> void:
	var ba := _anexo("spine_03")
	_ponto_arma = Node3D.new()
	_ponto_arma.name = "PontoArma"
	ba.add_child(_ponto_arma)
	# na frente do peito, um pouco para a direita, apontando para a frente (+Z do esqueleto = -Z da arma)
	var dir := 1.0 if esqueleto.get_bone_global_rest(esqueleto.find_bone("upperarm_r")).origin.x > 0.0 else -1.0
	_ponto_arma.transform = _no_osso("spine_03", Transform3D(Basis(Vector3.UP, PI), Vector3(dir * 0.13, -0.08, 0.32)))

func segurar_arma(_tipo: String, no: Node3D) -> void:
	_ponto_arma.add_child(no)

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
