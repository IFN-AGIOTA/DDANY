extends RefCounted
# MIRA DE FERRO (0.98): onde ficam a ALÇA (atrás) e a MASSA (na frente) de cada arma de fogo, medidas nos modelos
# baixados (armas/modelos/<tipo>.glb, espaço da arma: empunhadura na origem, cano para +Z, cima +Y), e onde fica o
# OLHO de quem mira (encostado na coronha; na pistola, com os braços esticados).
# Em 1ª pessoa mirando, jogador/ik_fuzil.gd põe a arma de modo que o olho fique na câmera e a linha alça -> massa
# aponte para o centro da tela (onde o tiro vai); as mãos vão até ela. Sem mirar, a arma fica embaixo à direita
# (QUADRIL), com os braços à vista.
# Mexa AQUI para: alinhar a mira de uma arma (alça/massa), a distância do olho, o zoom e a posição sem mirar.

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

static func tem(tipo: String) -> bool:
	return DADOS.has(tipo)

static func zoom(tipo: String) -> float:
	return float(DADOS[tipo][3]) if DADOS.has(tipo) else 1.0

# o "olho" da arma: a câmera vista no espaço da arma (origem no olho, -Z ao longo da linha de mira, +Y para cima)
static func quadro_olho(tipo: String) -> Transform3D:
	var d: Array = DADOS[tipo]
	var a := Vector3(0, (d[0] as Vector2).x, (d[0] as Vector2).y)
	var m := Vector3(0, (d[1] as Vector2).x, (d[1] as Vector2).y)
	var dir := (m - a).normalized()
	var olho := a + dir * ((float(d[2]) - a.z) / dir.z)
	var z := -dir
	var y := (Vector3.UP - dir * dir.dot(Vector3.UP)).normalized()
	return Transform3D(Basis(y.cross(z), y, z), olho)

# onde a arma fica (global) para a câmera "cam": ads 0 = quadril (1ª pessoa sem mirar) · 1 = mirando
static func transform_arma(tipo: String, cam: Transform3D, ads: float) -> Transform3D:
	var mirando := cam * quadro_olho(tipo).affine_inverse()
	var q: Array = QUADRIL.get(tipo, QUADRIL["_fuzil"])
	# a arma olha para +Z: virada para a frente da câmera (-Z) e com o giro leve
	var quadril := cam * Transform3D(Basis.from_euler(q[1]) * Basis(Vector3.UP, PI), q[0])
	return quadril.interpolate_with(mirando, smoothstep(0.0, 1.0, ads))
