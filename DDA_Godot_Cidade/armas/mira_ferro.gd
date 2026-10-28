extends RefCounted
# MIRA DE FERRO (0.98): onde ficam a ALÇA (atrás) e a MASSA (na frente) de cada arma de fogo, medidas nos modelos
# baixados (armas/modelos/<tipo>.glb, espaço da arma: empunhadura na origem, cano para +Z, cima +Y), e onde fica o
# OLHO de quem mira (encostado na coronha; na pistola, com os braços esticados).
# Em 1ª pessoa mirando, jogador/ik_fuzil.gd põe a arma de modo que o olho fique na câmera e a linha alça -> massa
# aponte para o centro da tela (onde o tiro vai); as mãos vão até ela. Sem mirar, a arma fica embaixo à direita
# (QUADRIL), com os braços à vista.
# Mexa AQUI para: alinhar a mira de uma arma (alça/massa), a distância do olho, o zoom e a posição sem mirar.
# 0.99 · LUNETAS (mira 4x e luneta do rifle): o olho fica atrás da OCULAR, na linha do tubo; o que aparece dentro do
# vidro (ampliado, com retículo e efeito de lente) é desenhado por armas/vista_luneta.gd. Tabelas LUNETAS e ENCAIXE.

# tipo -> [alça (y, z), massa (y, z), olho z, zoom]
const DADOS := {
	"pistola": [Vector2(0.0545, -0.01), Vector2(0.054, 0.15), -0.36, 1.15],
	"mp5": [Vector2(0.088, 0.02), Vector2(0.089, 0.36), -0.09, 1.25],
	"m4": [Vector2(0.094, -0.06), Vector2(0.098, 0.355), -0.13, 1.3],
	"ak": [Vector2(0.0875, 0.19), Vector2(0.0895, 0.53), -0.17, 1.3],
	"espingarda": [Vector2(0.0535, 0.05), Vector2(0.0535, 0.72), -0.12, 1.2],
	"rifle_caca": [Vector2(0.0745, 0.05), Vector2(0.0545, 0.745), -0.12, 1.35],
}
# sem mirar (1ª pessoa): onde a EMPUNHADURA fica em relação à câmera (x direita, y cima, -z frente) e um giro leve
# (x = cano para cima, y = cano para a esquerda/centro, z = inclinada), em radianos
const QUADRIL := {"pistola": [Vector3(0.17, -0.17, -0.36), Vector3(0.05, 0.12, 0.0)],
	"_fuzil": [Vector3(0.15, -0.21, -0.24), Vector3(0.03, 0.07, 0.05)]}

# lunetas (medidas nos modelos equipamentos/modelos/<id>.res, no espaço da peça: a ocular atrás em z 0, +Z para a
# frente): eixo do tubo (altura), raio do VIDRO da ocular, distância do olho até a ocular, aumento e o retículo
const LUNETAS := {
	"luneta": {"eixo_y": 0.0355, "ocular_z": 0.0, "vidro": 0.0165, "olho": 0.085, "aumento": 6.0, "reticulo": 0},
	"mira_acog": {"eixo_y": 0.014, "ocular_z": 0.0, "vidro": 0.0078, "olho": 0.045, "aumento": 4.0, "reticulo": 1},
}
# onde a peça da mira fica em cada arma (o nó "Mira" do modelo da arma)
const ENCAIXE := {"m4": Vector3(0, 0.0831, 0.0), "ak": Vector3(0, 0.0832, 0.0), "rifle_caca": Vector3(0, 0.0702, 0.0)}

static func tem_luneta(tipo: String, luneta: String) -> bool:
	return luneta != "" and LUNETAS.has(luneta) and ENCAIXE.has(tipo)

# centro da ocular, no espaço da arma
static func ocular(tipo: String, luneta: String) -> Vector3:
	var l: Dictionary = LUNETAS[luneta]
	return ENCAIXE[tipo] + Vector3(0, l["eixo_y"], l["ocular_z"])

static func tem(tipo: String) -> bool:
	return DADOS.has(tipo)

static func zoom(tipo: String, luneta := "") -> float:
	if tem_luneta(tipo, luneta):
		return 1.08                     # luneta: quase sem aproximar (o aumento é só dentro do vidro)
	return float(DADOS[tipo][3]) if DADOS.has(tipo) else 1.0

# o "olho" da arma: a câmera vista no espaço da arma (origem no olho, -Z ao longo da linha de mira, +Y para cima)
static func quadro_olho(tipo: String, luneta := "") -> Transform3D:
	var a: Vector3
	var m: Vector3
	var olho_z: float
	if tem_luneta(tipo, luneta):        # luneta: a linha é o eixo do tubo; o olho a "olho" m atrás da ocular
		a = ocular(tipo, luneta)
		m = a + Vector3(0, 0, 1)
		olho_z = a.z - float(LUNETAS[luneta]["olho"])
	else:
		var d: Array = DADOS[tipo]
		a = Vector3(0, (d[0] as Vector2).x, (d[0] as Vector2).y)
		m = Vector3(0, (d[1] as Vector2).x, (d[1] as Vector2).y)
		olho_z = float(d[2])
	var dir := (m - a).normalized()
	var olho := a + dir * ((olho_z - a.z) / dir.z)
	var z := -dir
	var y := (Vector3.UP - dir * dir.dot(Vector3.UP)).normalized()
	return Transform3D(Basis(y.cross(z), y, z), olho)

# onde a arma fica (global) para a câmera "cam": ads 0 = quadril (1ª pessoa sem mirar) · 1 = mirando
static func transform_arma(tipo: String, cam: Transform3D, ads: float, luneta := "") -> Transform3D:
	var mirando := cam * quadro_olho(tipo, luneta).affine_inverse()
	var q: Array = QUADRIL.get(tipo, QUADRIL["_fuzil"])
	# a arma olha para +Z: virada para a frente da câmera (-Z) e com o giro leve
	var quadril := cam * Transform3D(Basis.from_euler(q[1]) * Basis(Vector3.UP, PI), q[0])
	return quadril.interpolate_with(mirando, smoothstep(0.0, 1.0, ads))
