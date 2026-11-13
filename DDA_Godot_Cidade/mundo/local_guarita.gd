extends "res://mundo/local_porto.gd"
# 1.08 · GUARITA DE OBSERVAÇÃO (mundo/locais.gd tipo "guarita"), no meio dos campos (parques): o posto avançado que o
# Exército montou para vigiar a evacuação — torre de aço de 9 m com a escada em zigue-zague, a cabine com o parapeito de
# sacos de areia, holofote e binóculo de tripé; embaixo, a barraca, a fogueira apagada, caixas, rede de camuflagem,
# um jipe e o cercado de HESCO. Usa as peças do mundo/local.gd, local_novos.gd e local_porto.gd (escada em zigue-zague).
# Coordenadas LOCAIS: x = ao longo da frente, z = profundidade, +Z = FRENTE (o caminho/rua), y = 0 no chão.
# Mexa AQUI para: a torre, o acampamento e o loot ("guarita_*" em mundo/loot_mundo.gd). Onde ficam: mundo/locais.gd
# (ferramentas/escolher_guaritas.gd).

const CAMUFLAGEM := Color(0.3, 0.34, 0.22)
const ACO := Color(0.42, 0.44, 0.4)

# ======================================================================================================
# GUARITA (30 x 30): torre de 4 pernas (cabine 4,6 x 4,6 a 9 m, telhado a 11,6 m) com a escada em zigue-zague de 3 lances
# encostada; cercado de HESCO em L com a entrada para o caminho; barraca, fogueira, caixas, rede de camuflagem e um jipe.
# ======================================================================================================
func _guarita_obs() -> void:
	var yp := 9.0
	var m := 2.3                                   # meia cabine
	var ct := Vector2(4.0, -4.0)                   # centro da torre
	dentro = Rect2(ct.x - m, ct.y - m, m * 2.0, m * 2.0)
	_chao(Rect2(-15, -15, 30, 30), Color(0.42, 0.38, 0.3))           # terra batida
	# ---- a torre: 4 pernas de aço com travas em X, a cabine e o telhado ----
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pp := ct + Vector2(sx * (m - 0.2), sz * (m - 0.2))
			_bx(fora, Vector3(pp.x, yp * 0.5, pp.y), Vector3(0.3, yp, 0.3), ACO)
			fora.caixa(Vector3(pp.x, 0.2, pp.y), Vector3(0.8, 0.4, 0.8), CONCRETO)       # sapata
			fora.cilindro(Vector3(pp.x, yp + 1.3, pp.y), 0.06, 2.6, 5, METAL_ESC)        # postes do telhado
	for nivel in [3.0, 6.0]:
		for s in [-1.0, 1.0]:
			fora.caixa(Vector3(ct.x + s * (m - 0.2), nivel, ct.y), Vector3(0.12, 0.12, m * 2.0), ACO)
			fora.caixa(Vector3(ct.x, nivel, ct.y + s * (m - 0.2)), Vector3(m * 2.0, 0.12, 0.12), ACO)
	for s in [-1.0, 1.0]:
		_viga(Vector3(ct.x + s * (m - 0.2), 0.3, ct.y - m + 0.2), Vector3(ct.x + s * (m - 0.2), 3.0, ct.y + m - 0.2), 0.1, ACO * 0.9)
		_viga(Vector3(ct.x - m + 0.2, 3.0, ct.y + s * (m - 0.2)), Vector3(ct.x + m - 0.2, 6.0, ct.y + s * (m - 0.2)), 0.1, ACO * 0.9)
		_viga(Vector3(ct.x + s * (m - 0.2), 6.0, ct.y - m + 0.2), Vector3(ct.x + s * (m - 0.2), yp, ct.y + m - 0.2), 0.1, ACO * 0.9)
	_bx(fora, Vector3(ct.x, yp - 0.1, ct.y), Vector3(m * 2.0, 0.2, m * 2.0), MADEIRA_CLARA * 0.75)               # piso da cabine
	fora.caixa(Vector3(ct.x, yp + 2.65, ct.y), Vector3(m * 2.0 + 0.6, 0.14, m * 2.0 + 0.6), CAMUFLAGEM)            # telhado
	_col(Vector3(ct.x, yp + 2.65, ct.y), Vector3(m * 2.0 + 0.6, 0.14, m * 2.0 + 0.6))
	# parapeito de sacos de areia nos 4 lados, aberto no canto onde a escada chega (-x, +z)
	_sacos(Vector2(ct.x - m + 1.6, ct.y + m - 0.25), Vector2(ct.x + m - 0.2, ct.y + m - 0.25), 3, yp)
	_sacos(Vector2(ct.x + m - 0.25, ct.y - m + 0.2), Vector2(ct.x + m - 0.25, ct.y + m - 0.2), 3, yp)
	_sacos(Vector2(ct.x - m + 0.2, ct.y - m + 0.25), Vector2(ct.x + m - 0.2, ct.y - m + 0.25), 3, yp)
	_sacos(Vector2(ct.x - m + 0.25, ct.y - m + 0.2), Vector2(ct.x - m + 0.25, ct.y + m - 1.6), 3, yp)
	# dentro da cabine: holofote, binóculo de tripé, rádio, a caixa militar, cartuchos no chão
	_bx(resto, Vector3(ct.x + 1.2, yp + 1.15, ct.y - 1.2), Vector3(0.5, 0.4, 0.55), METAL_ESC)
	resto.cilindro(Vector3(ct.x + 1.2, yp + 1.15, ct.y - 0.9), 0.2, 0.08, 10, Color(0.9, 0.9, 0.8), Basis(Vector3.RIGHT, PI * 0.5))
	resto.cilindro(Vector3(ct.x + 1.2, yp + 0.47, ct.y - 1.2), 0.04, 0.95, 5, METAL_ESC)
	for k in 3:
		var a := k * TAU / 3.0
		_viga(Vector3(ct.x - 1.0, yp + 1.2, ct.y + 0.6), Vector3(ct.x - 1.0 + cos(a) * 0.4, yp, ct.y + 0.6 + sin(a) * 0.4), 0.03, METAL_ESC)
	resto.caixa(Vector3(ct.x - 1.0, yp + 1.3, ct.y + 0.6), Vector3(0.18, 0.12, 0.3), Color(0.12, 0.13, 0.12))         # binóculo
	_caixa_militar(Vector3(ct.x + 0.6, yp, ct.y - 1.4), 0.0, "guarita_torre")
	_bx(resto, Vector3(ct.x + 1.5, yp + 0.3, ct.y + 1.3), Vector3(0.6, 0.6, 0.5), CAMUFLAGEM * 0.8)
	for k in 12:
		resto.cilindro(Vector3(ct.x + r.randf_range(-1.5, 1.5), yp + 0.03, ct.y + r.randf_range(-1.5, 1.5)), 0.02, 0.06, 5, DOURADO, Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.UP, r.randf() * 3.0))
	_ponto(Vector3(ct.x - 0.5, yp, ct.y - 0.6), "torre")
	# ---- a escada em zigue-zague (3 lances de 3 m) encostada no lado -x da torre, chegando no canto -x +z ----
	var comp := 3.0 / 0.6 + 2.4
	var e0 := Vector3(ct.x - m - 2.3, 0.0, ct.y + m - comp)
	_escada_zigue(e0, false, 1.0, 3, 3.0, ACO, MADEIRA_CLARA * 0.7, false, true)   # encostada na torre (sem grade desse lado)
	_bx(fora, Vector3(ct.x - m - 0.1, yp - 0.1, ct.y + m - 0.6), Vector3(0.6, 0.2, 1.2), MADEIRA_CLARA * 0.7)        # degrau da porta
	# ---- o cercado de HESCO em L, a entrada virada para +Z ----
	_hesco(Vector2(-13.0, -13.0), Vector2(13.0, -13.0))
	_hesco(Vector2(13.0, -13.0), Vector2(13.0, 6.0))
	_hesco(Vector2(-13.0, -13.0), Vector2(-13.0, 2.0))
	_sacos(Vector2(-12.0, 12.0), Vector2(-4.0, 12.0), 2)
	_sacos(Vector2(4.0, 12.0), Vector2(12.0, 12.0), 2)
	_barreira(Vector2(-1.5, 13.5), 0.4)
	# ---- o acampamento: barraca, fogueira apagada, caixas, rede de camuflagem, jipe, latas ----
	_tenda(Vector2(-7.5, -6.0), 0.0)
	var fg := Vector2(-6.5, 4.0)
	for k in 8:
		var a := k * TAU / 8.0
		resto.caixa(Vector3(fg.x + cos(a) * 0.6, 0.1, fg.y + sin(a) * 0.6), Vector3(0.25, 0.2, 0.2), Color(0.45, 0.44, 0.42), Basis(Vector3.UP, a))
	resto.caixa(Vector3(fg.x, 0.05, fg.y), Vector3(0.8, 0.1, 0.8), Color(0.08, 0.07, 0.06))
	for k in 3:
		resto.caixa(Vector3(fg.x + 0.1 * k, 0.12, fg.y - 0.1 * k), Vector3(0.9, 0.08, 0.08), Color(0.2, 0.14, 0.1), Basis(Vector3.UP, k * 1.1))
	for p in [Vector2(-9.0, 4.5), Vector2(-4.0, 3.0), Vector2(-6.0, 6.2)]:
		_bx(resto, Vector3(p.x, 0.22, p.y), Vector3(0.5, 0.44, 0.5), CAMUFLAGEM * 0.9)                                # caixotes de sentar
	_caixa_militar(Vector3(-11.0, 0, 1.0), PI * 0.5, "guarita_acampamento")
	_caixa_militar(Vector3(-3.5, 0, -10.5), 0.0, "militar")
	# rede de camuflagem em cima do jipe (estacas e a lona inclinada)
	var cj := Vector2(7.0, 7.5)
	_jipe(cj, PI * 0.5)
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			fora.cilindro(Vector3(cj.x + s * 3.0, 1.3, cj.y + t * 2.2), 0.05, 2.6, 5, MADEIRA_CLARA * 0.6)
	resto.caixa(Vector3(cj.x, 2.65, cj.y), Vector3(6.4, 0.05, 4.8), CAMUFLAGEM, Basis(Vector3.BACK, 0.06))
	for k in 18:
		resto.caixa(Vector3(cj.x + r.randf_range(-3, 3), 2.7, cj.y + r.randf_range(-2.2, 2.2)), Vector3(r.randf_range(0.4, 1.0), 0.04, r.randf_range(0.3, 0.8)), CAMUFLAGEM * r.randf_range(0.7, 1.2), Basis(Vector3.UP, r.randf() * 3.0))
	for k in 10:
		resto.cilindro(Vector3(r.randf_range(-11, 11), 0.06, r.randf_range(-11, 11)), 0.04, 0.12, 6, Color(0.5, 0.5, 0.48), Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.UP, r.randf() * 3.0))
	# placa
	resto.caixa(Vector3(9.0, 1.3, 13.6), Vector3(3.0, 1.0, 0.06), Color(0.92, 0.9, 0.85))
	fora.cilindro(Vector3(7.7, 0.7, 13.6), 0.05, 1.4, 5, METAL_ESC)
	fora.cilindro(Vector3(10.3, 0.7, 13.6), 0.05, 1.4, 5, METAL_ESC)
	_texto(Vector3(9.0, 1.45, 13.65), 0.0, "POSTO DE OBSERVAÇÃO", Color(0.15, 0.2, 0.15), 26)
	_texto(Vector3(9.0, 1.1, 13.65), 0.0, "ÁREA MILITAR · NÃO ENTRE", Color(0.7, 0.08, 0.06), 22)
	_pontos_em(Rect2(-12, -12, 24, 24), 0.0, 5, "acampamento")
	for p in [Vector3(-2, 0, 8), Vector3(9, 0, -9), Vector3(-10, 0, -10), Vector3(0, 0, 0)]:
		infectados.append(p)
