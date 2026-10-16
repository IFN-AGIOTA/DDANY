extends RefCounted
# MODELOS 3D DOS EQUIPAMENTOS de vestir (aparecem no corpo do sobrevivente e no chão).
#   BAIXADOS (low poly, licença livre, créditos no menu Créditos e em equipamentos/LICENCA.txt), convertidos por
#   ferramentas/preparar_equipamentos.gd para equipamentos/modelos/<id>.res:
#     capacete, boné, mochila de trilha, mochila de combate, mochila escolar
#   FEITOS POR CÓDIGO (não achamos modelo livre bom): gorro, lanterna de cabeça, pochete.
#   COLETES: são feitos a partir do próprio tronco do corpo (jogador/modelo_sobrevivente.gd), para acompanhar a animação.
# Cada peça: origem na BASE (onde encosta no corpo), frente para +Z (frente do corpo).
# ENCAIXE: em qual osso do sobrevivente vai e a posição em relação a ele (espaço do esqueleto, sem a rotação do osso).
# Mexa AQUI para: trocar um modelo, cores das peças feitas por código e onde cada uma fica no corpo.

const Malhas := preload("res://mundo/malhas.gd")
const PASTA := "res://equipamentos/modelos/"
const BAIXADOS := ["capacete", "bone", "mochila_trilha", "mochila_combate", "mochila_escolar"]
# id: [osso, posição, giro em Y (graus), escala]
const ENCAIXE := {
	"capacete": ["Head", Vector3(0, 0.1, 0.0), 0.0, 1.0],
	"bone": ["Head", Vector3(0, 0.15, 0.0), 0.0, 1.0],
	"gorro": ["Head", Vector3(0, 0.13, -0.005), 0.0, 1.0],
	"lanterna_cabeca": ["Head", Vector3(0, 0.14, 0.0), 0.0, 1.0],
	"mochila_trilha": ["spine_03", Vector3(0, -0.32, -0.15), 0.0, 0.85],
	"mochila_combate": ["spine_03", Vector3(0, -0.3, -0.15), 0.0, 0.88],
	"mochila_escolar": ["spine_03", Vector3(0, -0.3, -0.15), 0.0, 1.0],
	"pochete": ["pelvis", Vector3(0, 0.02, 0.0), 0.0, 1.0],
}

static var _cache := {}
static var _mat: StandardMaterial3D = null

static func tem(id: String) -> bool:
	return ENCAIXE.has(id)

static func malha(id: String) -> Mesh:
	if _cache.has(id):
		return _cache[id]
	var m: Mesh = null
	if id in BAIXADOS and ResourceLoader.exists(PASTA + id + ".res"):
		m = load(PASTA + id + ".res")
	else:
		m = _por_codigo(id)
	_cache[id] = m
	return m

static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = Malhas.mat_cores(0.8)
	return _mat

static func _por_codigo(id: String) -> Mesh:
	var c := Malhas.Construtor.new()
	c.ao = 0.1
	match id:
		"gorro":
			var cor_la := Color(0.16, 0.16, 0.19)
			c.cilindro(Vector3(0, 0.03, 0), 0.112, 0.06, 12, cor_la * 0.8)                       # barra dobrada
			c.cilindro(Vector3(0, 0.09, 0), 0.108, 0.06, 12, cor_la, Basis.IDENTITY, 0.085)
			c.cilindro(Vector3(0, 0.14, 0), 0.085, 0.04, 12, cor_la, Basis.IDENTITY, 0.04)
			c.caixa(Vector3(0, 0.17, 0), Vector3(0.04, 0.03, 0.04), cor_la * 1.2)
		"lanterna_cabeca":
			var tira := Color(0.08, 0.08, 0.09)
			for i in 14:
				var a := TAU * i / 14.0
				c.caixa(Vector3(sin(a) * 0.102, 0.0, cos(a) * 0.102), Vector3(0.048, 0.025, 0.008), tira, Basis(Vector3.UP, a))
			c.caixa(Vector3(0, 0.0, 0.112), Vector3(0.05, 0.036, 0.03), Color(0.2, 0.2, 0.22))     # lanterna
			c.caixa(Vector3(0, 0.0, 0.128), Vector3(0.034, 0.024, 0.004), Color(0.95, 0.92, 0.7))  # lente
		"pochete":
			var tecido := Color(0.15, 0.17, 0.14)
			c.caixa(Vector3(0, 0.0, 0.16), Vector3(0.22, 0.1, 0.07), tecido)
			c.caixa(Vector3(0, 0.035, 0.196), Vector3(0.2, 0.012, 0.004), Color(0.08, 0.08, 0.08))  # zíper
			for i in 16:                                                                            # cinta
				var a := TAU * i / 16.0
				c.caixa(Vector3(sin(a) * 0.155, 0.0, cos(a) * 0.12), Vector3(0.065, 0.03, 0.008), tecido * 0.7, Basis(Vector3.UP, a))
		_:
			return null
	return c.malha(_material())

# peça pronta para pôr num nó (MeshInstance3D) ou null
static func instancia(id: String) -> MeshInstance3D:
	var m := malha(id)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Equip_" + id
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
