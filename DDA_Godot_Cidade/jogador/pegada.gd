extends RefCounted
# PEGADA (1.14.2): COMO cada mão segura cada arma. Antes a arma ficava presa à mão como se fosse um cano saindo
# pela ponta dos dedos (a faca e a pistola na ponta dos dedos, a mão aberta). Agora:
#   · a mão DIREITA fecha em volta da EMPUNHADURA/CABO: o cabo atravessa a palma (do indicador ao mindinho), os
#     dedos dão a volta e o polegar fica do outro lado (os dedos fecham em jogador/camada_dedos.gd);
#   · a mão ESQUERDA: no fuzil, espalmada embaixo do guarda-mão; na pistola, do lado esquerdo da empunhadura, por cima
#     dos dedos da direita; nas armas brancas de duas mãos, fechada no cabo acima da direita.
# Espaço da ARMA (armas/modelos_armas.gd): origem = empunhadura (arma de fogo: 4 cm abaixo do cano, na frente da
# empunhadura · arma branca: no meio do cabo), frente (cano/lâmina) = +Z, cima = +Y, ESQUERDA da arma = +X.
# Espaço da MÃO direita (osso hand_r, igual no homem e na mulher): +X = costas da mão, +Y = para os dedos,
# +Z = lado do polegar/indicador.
# Mexa AQUI para: onde a mão segura cada arma (G), a inclinação do cabo (A), onde a esquerda apoia (ESQ) e o
# "vão" da mão fechada (CANAL).

# o vão da mão fechada (onde o cabo passa), no espaço do osso da mão direita
const CANAL := Vector3(-0.034, 0.092, 0.0)
# arma de fogo: a mão fica ALINHADA COM O CANO (dedos para a frente, o antebraço atrás, na linha do cano); a
# empunhadura inclinada atravessa o punho fechado meio de viés (como na pegada de verdade). Antes a mão seguia a
# inclinação da empunhadura e o antebraço subia para o rosto (na mira da espingarda tampava a tela).
const DEDOS_FOGO := Vector3(0, -0.06, 1.0)

# tipo -> [G = meio do cabo na mão direita, A = direção do cabo do indicador para o mindinho]
const DIREITA := {
	"pistola": [Vector3(0, -0.034, -0.014), Vector3(0, -1.0, -0.24)],
	"mp5": [Vector3(0, -0.056, -0.03), Vector3(0, -1.0, -0.36)],
	"m4": [Vector3(0, -0.058, -0.032), Vector3(0, -1.0, -0.36)],
	"ak": [Vector3(0, -0.056, -0.03), Vector3(0, -1.0, -0.36)],
	"espingarda": [Vector3(0, -0.05, -0.05), Vector3(0, -0.8, -0.6)],
	"rifle_caca": [Vector3(0, -0.046, -0.05), Vector3(0, -0.8, -0.6)],
}
const FOGO := ["pistola", "mp5", "m4", "ak", "espingarda", "rifle_caca"]
# fuzis: onde a palma da esquerda encosta embaixo do guarda-mão (y = altura do fundo do guarda-mão, z = onde segura)
const ESQ := {
	"mp5": Vector3(0, 0.0, 0.17), "m4": Vector3(0, 0.002, 0.24), "ak": Vector3(0, 0.0, 0.26),
	"espingarda": Vector3(0, -0.016, 0.36), "rifle_caca": Vector3(0, -0.012, 0.32),
}
# armas brancas: onde fica o meio da mão DIREITA no cabo (z a partir da origem; o resto fica na origem)
const BRANCA_DIR := {"taco": 0.04, "machado": 0.07, "cano": 0.06, "lanca": 0.0}
# armas brancas de DUAS mãos: o meio da mão ESQUERDA no cabo, ABAIXO da direita (do lado do pomo), como na postura
# "porte_2m" (as duas mãos fechadas, palmas de lados opostos, os dois polegares para a cabeça da arma)
const DUAS_MAOS := {"taco": Vector3(0, 0, -0.05), "machado": Vector3(0, 0, -0.02), "cano": Vector3(0, 0, -0.04),
	"lanca": Vector3(0, 0, -0.3)}

static func eh_fogo(tipo: String) -> bool:
	return tipo in FOGO

static func duas_maos(tipo: String) -> bool:
	return DUAS_MAOS.has(tipo)

# A MÃO DIREITA no espaço da arma (o punho/osso hand_r), segurando direito.
# antigo = o encaixe antigo (arma no espaço da mão): nas armas brancas a mão gira o MÍNIMO em volta do cabo para
# chegar na pegada certa (a lâmina continua com o fio para onde a animação mandava)
# dedos_pref (arma branca): para onde os dedos devem apontar (no espaço da arma; o jogador/ik_fuzil.gd passa "do ombro
# para o cabo"): a mão gira em volta do cabo para os dedos seguirem o antebraço (o punho não torce, os braços não cruzam)
static func mao_dir(tipo: String, antigo := Transform3D.IDENTITY, dedos_pref := Vector3.ZERO) -> Transform3D:
	var g := Vector3.ZERO
	var a := Vector3(0, 0, -1)                     # arma branca: o cabo vai do polegar (lâmina) para o mindinho (pomo)
	var palma := Vector3(1, 0, 0)                  # para onde a palma olha (arma de fogo: o lado esquerdo da arma)
	if DIREITA.has(tipo):
		g = DIREITA[tipo][0]
		a = (DIREITA[tipo][1] as Vector3).normalized()
	else:
		g = Vector3(0, 0, float(BRANCA_DIR.get(tipo, 0.0)))
		if antigo != Transform3D.IDENTITY:
			palma = antigo.basis.orthonormalized().inverse() * Vector3(-1, 0, 0)
	palma = (palma - a * palma.dot(a))
	if palma.length() < 0.01:
		palma = Vector3(1, 0, 0) - a * a.x
	palma = palma.normalized()
	var x := -palma                                # costas da mão
	var z := -a                                    # polegar/indicador para cima do cabo
	var y := z.cross(x)                            # dedos
	if DIREITA.has(tipo):
		y = (DEDOS_FOGO - x * DEDOS_FOGO.dot(x)).normalized()
		z = x.cross(y)
	elif dedos_pref.length() > 0.001:
		var f := dedos_pref - a * dedos_pref.dot(a)
		if f.length() > 0.2 * dedos_pref.length():
			y = f.normalized()
			z = -a
			x = y.cross(z)
	var b := Basis(x, y, z)
	return Transform3D(b, g - b * CANAL)

# o meio do cabo/empunhadura na mão direita (espaço da arma)
static func ponto_direita(tipo: String) -> Vector3:
	if DIREITA.has(tipo):
		return DIREITA[tipo][0]
	return Vector3(0, 0, float(BRANCA_DIR.get(tipo, 0.0)))

# o meio da mão esquerda no cabo das armas brancas de duas mãos (espaço da arma)
static func ponto_esquerda(tipo: String) -> Vector3:
	return DUAS_MAOS.get(tipo, Vector3.ZERO)

# mão ESQUERDA (palma, dedos, ponto de contato) no espaço da arma. lado = x do lado DIREITO do corpo (-1 ou 1)
# devolve [palma, dedos, contato]: o punho fica em contato - dedos * 0,075 - palma * 0,035
static func mao_esq(tipo: String, lado: float, fp := false, antigo := Transform3D.IDENTITY, dedos_pref := Vector3.ZERO) -> Array:
	if tipo == "pistola":
		# do lado esquerdo da empunhadura, a palma virada para ela, os dedos por cima dos da direita, para a frente
		return [Vector3(lado, 0.15, 0.0), Vector3(lado * 0.1, -0.55, 0.83), Vector3(-lado * 0.03, -0.045, 0.012)]
	if DUAS_MAOS.has(tipo):
		# fechada no cabo, o polegar para a cabeça da arma; os dedos seguem o antebraço esquerdo (dedos_pref)
		var b := mao_dir(tipo, antigo).basis
		var dedos := b.y.normalized()
		var palma := b.x.normalized()
		var eixo := Vector3(0, 0, 1)
		var f := dedos_pref - eixo * dedos_pref.dot(eixo)
		if dedos_pref.length() > 0.001 and f.length() > 0.2 * dedos_pref.length():
			dedos = f.normalized()
			palma = dedos.cross(eixo)               # mão esquerda: polegar = palma x dedos = +Z (cabeça da arma)
		return [palma, dedos, (DUAS_MAOS[tipo] as Vector3) - dedos * 0.017]
	var c: Vector3 = ESQ.get(tipo, Vector3(0, 0, 0.25))
	if fp:
		c.z = minf(c.z, 0.27)                       # 1ª pessoa: a arma fica mais perto do corpo (o braço alcança)
	# espalmada embaixo do guarda-mão: palma para cima, dedos para a frente e para a direita (dão a volta nele)
	return [Vector3(lado * 0.3, 1.0, 0.0), Vector3(lado * 0.5, 0.05, 0.86), c]
