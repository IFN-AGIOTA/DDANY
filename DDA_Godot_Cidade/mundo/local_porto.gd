extends "res://mundo/local_igreja.gd"
# 1.07 · PORTO DE CONTÊINERES e HANGAR DE CARGA (mundo/locais.gd tipos "porto" e "hangar"), como as fotos de referência:
# cais com PORTÊINERES azuis, pátio de contêineres empilhados e o NAVIO porta-contêineres atracado.
# Usa as peças do mundo/local.gd, mundo/local_novos.gd e mundo/local_igreja.gd e funciona igual: tudo vira uma malha +
# um corpo de colisão, loot próprio (tabelas "porto_*" e "carga_*" em mundo/loot_mundo.gd), pontos de infectados e
# lugares altos para vigiar (o alto dos guindastes; a ponte de comando do navio).
# O NAVIO e o cais ficam ATRÁS do terreno (z < -45 local), em cima do mar: o terreno foi escolhido com o fundo virado
# para o mar (ferramentas/escolher_portos.gd).
# Peça nova: _escada_zigue (escada de 2 faixas em zigue-zague com patamares, igual às escadas de incêndio), usada na
# torre de cada guindaste e no casario do navio.
# Coordenadas LOCAIS: x = ao longo da frente, z = profundidade, +Z = FRENTE (o lado da rua), y = 0 no chão do terreno.
# Mexa AQUI para: a planta, os contêineres, o navio, os guindastes e o hangar. Onde ficam: mundo/locais.gd.

const AZUL_GUINDASTE := Color(0.13, 0.32, 0.68)
const AMARELO_SEG := Color(0.92, 0.72, 0.1)
const CASCO := Color(0.1, 0.13, 0.26)
const CASCO_BAIXO := Color(0.52, 0.12, 0.1)
const CONVES := Color(0.38, 0.22, 0.17)
const CORES_CONTEINER := [Color(0.72, 0.14, 0.12), Color(0.15, 0.3, 0.6), Color(0.85, 0.55, 0.12), Color(0.2, 0.45, 0.3),
	Color(0.85, 0.85, 0.82), Color(0.55, 0.32, 0.18), Color(0.45, 0.47, 0.5), Color(0.15, 0.55, 0.65), Color(0.6, 0.18, 0.35)]
const Y_AGUA := -1.05                  # o mar no espaço do local (cidade.Y_MAR - cidade.Y_CALCADA)
const NOMES_NAVIO := ["NOVA AURORA", "ATLANTIC STAR"]

# ---------- peças ----------
# escada em ZIGUE-ZAGUE de 2 faixas (F m cada), lances de "sobe" m alternando de faixa, PATAMAR de 1,2 m em cada ponta e
# em cada nível uma galeria com o vão em cima do lance que chega (a cabeça não bate); grade por fora.
# o = canto do começo (no chão do 1º nível); ao longo de +X (eixo_x) ou +Z; "lado" (+1/-1) = para que lado fica a
# 2ª faixa. A faixa 0 sobe para +eixo e a 1 volta.
func _escada_zigue(o: Vector3, eixo_x: bool, lado: float, niveis: int, sobe: float, cor: Color, cor_piso: Color, sem_grade_fim := false) -> void:
	var F := 1.15
	var PT := 1.2
	var C := sobe / 0.6
	var comp := C + 2.0 * PT
	var ax := Vector2(1, 0) if eixo_x else Vector2(0, 1)
	var tr := (Vector2(0, 1) if eixo_x else Vector2(1, 0)) * lado
	var o2 := Vector2(o.x, o.z)
	for k in niveis:
		var f := k % 2
		var sd := 1.0 if f == 0 else -1.0
		var c_f: Vector2 = o2 + tr * (F * 0.5 + f * F)
		var ini: Vector2 = c_f + ax * (PT if f == 0 else PT + C)
		var dir: Vector2 = ax * sd
		var fora_f: Vector2 = -tr if f == 0 else tr                       # lado de fora desta faixa
		var lat := Vector2(-dir.y, dir.x)
		_escada(ini, dir, F, o.y + k * sobe, sobe, C, cor, 1 if lat.dot(fora_f) > 0.0 else -1)
	var ret := Rect2(o2, Vector2.ZERO).expand(o2 + ax * comp + tr * 2.0 * F)
	for j in range(1, niveis + 1):
		var y: float = o.y + j * sobe
		var fh := (j - 1) % 2
		var b0: Vector2 = o2 + tr * fh * F + ax * PT
		var vao := Rect2(b0, Vector2.ZERO).expand(b0 + tr * F + ax * C)
		_laje(ret, y - 0.15, 0.15, [vao], cor_piso, true)
		# grade: as 2 bordas compridas por fora, as pontas e a borda do vão (entre as faixas)
		_grade(o2, o2 + ax * comp, y, METAL_ESC)
		_grade(o2 + tr * 2.0 * F, o2 + tr * 2.0 * F + ax * comp, y, METAL_ESC)
		_grade(o2, o2 + tr * 2.0 * F, y, METAL_ESC)
		if not (sem_grade_fim and j == niveis):
			_grade(o2 + ax * comp, o2 + ax * comp + tr * 2.0 * F, y, METAL_ESC)
		var meio: Vector2 = o2 + tr * F
		_grade(meio + ax * PT, meio + ax * (PT + C), y, METAL_ESC)
	# pilares nos cantos
	for q in [o2, o2 + ax * comp, o2 + tr * 2.0 * F, o2 + ax * comp + tr * 2.0 * F]:
		resto.caixa(Vector3(q.x, o.y + niveis * sobe * 0.5, q.y), Vector3(0.14, niveis * sobe, 0.14), METAL_ESC)

# contêiner de 12 m (40 pés) ao longo de X, apoiado em y; leve (corpo + molduras das pontas + portas)
func _cont40(p: Vector3, cor: Color, portas_x := 1.0) -> void:
	resto.caixa(p + Vector3(0, 1.3, 0), Vector3(12.1, 2.58, 2.42), cor)
	for s in [-1.0, 1.0]:
		resto.caixa(p + Vector3(s * 6.04, 1.3, 0), Vector3(0.1, 2.6, 2.46), cor * 0.7)
	resto.caixa(p + Vector3(portas_x * 6.1, 1.3, 0), Vector3(0.03, 2.3, 0.05), Color(0.15, 0.15, 0.15))
	for k in 4:
		resto.caixa(p + Vector3(-4.5 + k * 3.0, 1.3, 1.22), Vector3(0.08, 2.4, 0.03), cor * 0.82)

# ======================================================================================================
# PORTO (160 x 90 em terra + o cais e o navio em cima do mar): portaria com cancela e guarita, ADMINISTRAÇÃO do porto
# (2 andares), galpão de carga, estacionamento, PÁTIO DE CONTÊINERES (blocos de pilhas de 1 a 4, corredores para
# atravessar escondido; alguns abertos com loot), torres de luz, carretas porta-contêiner e uma empilhadeira de
# contêiner; no CAIS: trilhos, 3 PORTÊINERES azuis (escada em zigue-zague até o alto do pórtico, 28 m), cabeços com as
# amarras e o NAVIO PORTA-CONTÊINERES atracado (140 m): escada de acesso do cais ao convés, contêineres no convés,
# CASARIO de 5 andares com a escada por fora até a PONTE DE COMANDO, chaminé e baleeira. A história: a evacuação pelo
# mar — fila de embarque, malas largadas no cais, "EMBARQUE SUSPENSO" — e o navio nunca saiu.
# ======================================================================================================
func _porto() -> void:
	var nome_navio: String = NOMES_NAVIO[_numero_do_tipo() % NOMES_NAVIO.size()]
	var n_term := _numero_do_tipo() + 1
	dentro = Rect2(44, 16, 32, 24)                      # o galpão de carga
	# ---- chão: asfalto do pátio, concreto do cais, faixas ----
	_chao(Rect2(-80, -30, 160, 75), ASFALTO * 1.05)
	_chao(Rect2(-80, -45, 160, 15), CONCRETO * 1.0)
	for x in [-6.0, 6.0]:
		_faixa(Vector2(x, 44), Vector2(x, -28), 0.15, AMARELO_SEG)
	for z in [1.0, -11.2]:
		_faixa(Vector2(-74, z), Vector2(74, z), 0.12, FAIXA)
	_faixa(Vector2(-80, -29.5), Vector2(80, -29.5), 0.3, AMARELO_SEG)
	# trilhos dos guindastes
	for z in [-33.0, -50.5]:
		for dz in [-0.6, 0.6]:
			fora.caixa(Vector3(0, 0.04, z + dz), Vector3(160, 0.08, 0.14), METAL * 0.8, Basis.IDENTITY, true)
	# ---- o CAIS sobre o mar (do fundo do terreno até a beira, com a parede até a água) ----
	_bx(fora, Vector3(0, -1.6, -46.0), Vector3(160.0, 3.2, 14.0), CONCRETO)
	fora.caixa(Vector3(0, -0.02, -46.0), Vector3(160.0, 0.06, 14.0), CONCRETO * 1.02, Basis.IDENTITY, true)
	fora.caixa(Vector3(0, -0.05, -52.85), Vector3(160.0, 0.12, 0.3), AMARELO_SEG)                       # borda pintada
	for k in 16:                                                                                         # defensas de borracha
		resto.cilindro(Vector3(-75 + k * 10.0, -0.9, -53.25), 0.45, 2.2, 10, Color(0.08, 0.08, 0.09), Basis(Vector3.FORWARD, PI * 0.5))
	for k in 12:                                                                                         # cabeços de amarração
		var xb := -66.0 + k * 12.0
		resto.cilindro(Vector3(xb, 0.4, -52.3), 0.35, 0.8, 10, Color(0.12, 0.12, 0.13))
		resto.cilindro(Vector3(xb, 0.85, -52.3), 0.5, 0.12, 10, Color(0.12, 0.12, 0.13))
		_col(Vector3(xb, 0.45, -52.3), Vector3(0.8, 0.9, 0.8))
	# ---- portaria, cerca, administração, galpão ----
	_cerca(Vector2(-80, 44.5), Vector2(-10, 44.5))
	_cerca(Vector2(10, 44.5), Vector2(80, 44.5))
	_cerca(Vector2(-79.5, 44.5), Vector2(-79.5, -30))
	_cerca(Vector2(79.5, 44.5), Vector2(79.5, -30))
	_guarita(Vector2(13.0, 40.0))
	resto.caixa(Vector3(0, 1.0, 40.0), Vector3(14.0, 0.12, 0.12), Color(0.85, 0.85, 0.85), Basis(Vector3.BACK, 0.35))  # cancela levantada
	resto.caixa(Vector3(-7.0, 0.5, 40.0), Vector3(0.5, 1.0, 0.5), Color(0.85, 0.2, 0.1))
	_placa(Vector3(-16.0, 4.0, 44.0), Vector3(10.0, 2.2, 0.3), Color(0.12, 0.25, 0.5), Color(0.9, 0.9, 0.88))
	_texto(Vector3(-16.0, 4.3, 44.17), 0.0, "PORTO DE NOVA YORK", Color(0.95, 0.95, 0.92), 56)
	_texto(Vector3(-16.0, 3.4, 44.17), 0.0, "TERMINAL DE CONTÊINERES %d" % n_term, Color(0.95, 0.95, 0.92), 34)
	fora.cilindro(Vector3(-21.5, 2.0, 44.0), 0.12, 4.0, 6, METAL_ESC)
	fora.cilindro(Vector3(-10.5, 2.0, 44.0), 0.12, 4.0, 6, METAL_ESC)
	_porto_administracao(Rect2(-74, 20, 22, 18))
	_porto_galpao(Rect2(44, 16, 32, 24))
	_vagas(-44.0, -14.0, 32.0, 5.0)
	_carro(Vector2(-40.0, 34.5), 0.0, Color(0.3, 0.32, 0.35))
	_carro(Vector2(-29.0, 34.5), 0.05, Color(0.6, 0.6, 0.62))
	_carro(Vector2(-22.0, 30.0), 0.9, Color(0.5, 0.1, 0.1), "carro", true)
	# ---- PÁTIO DE CONTÊINERES: 3 blocos x 2 lados x 5 baias, 3 fileiras, pilhas de 0 a 4 ----
	for zb in [3.0, -9.2, -21.4]:
		for lado in [-1.0, 1.0]:
			for baia in 5:
				var xc: float = lado * (11.0 + 6.3 + baia * 12.6)
				for fil in 3:
					var zc: float = zb + 1.22 + fil * 2.74
					var h := r.randi_range(0, 4) if r.randf() < 0.9 else 0
					if baia == 2 and fil == 1:
						h = 0                                                        # passagem no meio do bloco
					for k in h:
						_cont40(Vector3(xc, k * 2.6, zc), CORES_CONTEINER[r.randi() % CORES_CONTEINER.size()], lado)
					if h > 0:
						col.append([Vector3(xc, h * 1.3, zc), Vector3(12.1, h * 2.6, 2.42), 0.0, Basis.IDENTITY])
				# um contêiner aberto no chão virado para o corredor, com loot
				if baia % 2 == 0:
					var zl: float = zb - 2.0 if zb > -20.0 else zb + 10.4
					if absf(zl - 13.0) > 1.0:
						_conteiner(Vector2(xc, zl), PI * 0.5 * lado, CORES_CONTEINER[(baia + int(zb)) % CORES_CONTEINER.size()], "porto_conteiner" if baia != 4 else "porto_apreendido", 0.0, true)
	_pontos_em(Rect2(-74, -1, 148, 3), 0.0, 5, "patio")
	_pontos_em(Rect2(-74, -13, 148, 3), 0.0, 4, "patio")
	# torres de luz, carretas porta-contêiner, empilhadeira de contêiner
	for p in [Vector2(-40, -27), Vector2(40, -27), Vector2(0, 15)]:
		fora.cilindro(Vector3(p.x, 12.5, p.y), 0.35, 25.0, 8, Color(0.6, 0.62, 0.64), Basis.IDENTITY, 0.22)
		fora.caixa(Vector3(p.x, 25.2, p.y), Vector3(3.0, 1.0, 0.4), METAL_ESC)
		for k in 4:
			resto.caixa(Vector3(p.x - 1.1 + k * 0.73, 25.2, p.y + 0.25), Vector3(0.55, 0.6, 0.1), Color(0.9, 0.9, 0.8))
		_col(Vector3(p.x, 3.0, p.y), Vector3(0.8, 6.0, 0.8))
	_carreta_conteiner(Vector2(-2.0, -18.0), 0.0, CORES_CONTEINER[1])
	_carreta_conteiner(Vector2(2.0, 8.0), PI, CORES_CONTEINER[0])
	_carreta_conteiner(Vector2(-30.0, -38.0), PI * 0.5, CORES_CONTEINER[3])
	_reach_stacker(Vector2(30.0, -37.0), -PI * 0.5)
	# ---- GUINDASTES (portêineres) no cais ----
	for xg in [5.0, 35.0, 62.0]:
		_porteiner(xg)
	# ---- a FILA DE EMBARQUE no cais: grades, malas largadas, a placa ----
	for k in 4:
		_grade(Vector2(-44.0 + k * 0.0, -40.0 - k * 2.2), Vector2(-32.0, -40.0 - k * 2.2), 0.0)
	for k in 26:
		var pm := Vector2(r.randf_range(-46, -30), r.randf_range(-48.5, -38))
		var tm := Vector3(r.randf_range(0.4, 0.75), r.randf_range(0.25, 0.6), r.randf_range(0.2, 0.35))
		resto.caixa(Vector3(pm.x, tm.y * 0.5, pm.y), tm, CORES_CONTEINER[r.randi() % CORES_CONTEINER.size()] * 0.8, Basis(Vector3.UP, r.randf() * 3.0))
	for k in 4:
		_loot(Vector3(-44.0 + k * 3.5, 0.1, -46.0 - (k % 2) * 1.5), "porto_bagagem", "MALAS LARGADAS", Vector2i(6, 4))
	resto.caixa(Vector3(-36.0, 1.6, -38.6), Vector3(4.6, 1.6, 0.08), Color(0.95, 0.95, 0.92))
	fora.cilindro(Vector3(-38.2, 0.9, -38.6), 0.06, 1.8, 5, METAL_ESC)
	fora.cilindro(Vector3(-33.8, 0.9, -38.6), 0.06, 1.8, 5, METAL_ESC)
	_texto(Vector3(-36.0, 2.0, -38.53), 0.0, "EVACUAÇÃO PELO MAR", Color(0.12, 0.2, 0.45), 30)
	_texto(Vector3(-36.0, 1.4, -38.53), 0.0, "EMBARQUE SUSPENSO", Color(0.75, 0.08, 0.06), 40)
	_pontos_em(Rect2(-46, -50, 16, 10), 0.0, 3, "cais")
	# ---- o NAVIO atracado ----
	_navio(nome_navio)
	# infectados: no pátio, no cais, no navio, na administração
	for p in [Vector3(0, 0, 1), Vector3(-30, 0, -11), Vector3(30, 0, 1), Vector3(-50, 0, -11), Vector3(55, 0, -11), Vector3(-38, 0, -44),
			Vector3(-25, 0, -42), Vector3(20, 0, -40), Vector3(50, 0, -42), Vector3(-63, 0, 15), Vector3(60, 0, 28),
			Vector3(0, 9, -55.2), Vector3(30, 9, -55.2), Vector3(-40, 9, -55.2), Vector3(60, 9, -66), Vector3(-57, 24, -66)]:
		infectados.append(p)

func _porto_administracao(B: Rect2) -> void:
	var A := 4.0
	var cor := Color(0.82, 0.8, 0.74)
	var porta := [9.0, 11.0, 0.0, 2.5]
	_perimetro(B, 0.0, A, cor, Color(0.9, 0.88, 0.84), [_janelas(B.size.x, 2.8, 1.6, 1.0, 2.6, [porta]), _janelas(B.size.y, 2.8, 1.6, 1.0, 2.6, []),
		_janelas(B.size.x, 2.8, 1.6, 1.0, 2.6, [], 0.7), _janelas(B.size.y, 2.8, 1.6, 1.0, 2.6, [_porta(4.0)])])
	_perimetro(B, A, A, cor, Color(0.9, 0.88, 0.84), [_janelas(B.size.x, 2.8, 1.6, 1.0, 2.6, []), _janelas(B.size.y, 2.8, 1.6, 1.0, 2.6, []),
		_janelas(B.size.x, 2.8, 1.6, 1.0, 2.6, []), _janelas(B.size.y, 2.8, 1.6, 1.0, 2.6, [])])
	var c := B.get_center()
	var vao := Rect2(B.end.x - 3.0, B.position.y + 1.0, 1.6, 7.0)
	piso.caixa(Vector3(c.x, 0.02, c.y), Vector3(B.size.x - 0.3, 0.04, B.size.y - 0.3), Color(0.66, 0.66, 0.62), Basis.IDENTITY, true)
	_laje(B.grow(-0.05), A - 0.4, 0.4, [vao], Color(0.6, 0.55, 0.45))
	_laje(B.grow(-0.05), 2.0 * A - 0.4, 0.4, [], CONCRETO, true)
	_escada(Vector2(vao.position.x + 0.8, vao.end.y), Vector2(0, -1), 1.4, 0.0, A, 6.7, CONCRETO, -1)
	_grade(Vector2(vao.position.x, vao.position.y), Vector2(vao.position.x, vao.end.y), A)
	_parede(paredes, Vector2(B.position.x, c.y), Vector2(B.end.x - 3.4, c.y), 0.0, A - 0.4, DIV, Color.WHITE, cor, [_porta(6.0), _porta(14.0)])
	for k in 4:
		_movel("mesa_escritorio", Vector3(B.position.x + 3.0 + k * 4.0, 0.0, B.end.y - 3.0), PI, "porto_escritorio", "MESA")
	_movel("balcao", Vector3(c.x - 2.0, 0.0, B.end.y - 6.5), 0.0, "porto_escritorio", "BALCÃO DA ALFÂNDEGA")
	_movel("arquivo", Vector3(B.position.x + 1.0, 0.0, B.position.y + 1.2), 0.0, "porto_escritorio", "ARQUIVO")
	for k in 3:
		_movel("mesa_escritorio", Vector3(B.position.x + 3.0 + k * 5.0, A, c.y + 3.0), 0.0, "porto_escritorio", "MESA DO CONTROLE")
	_movel("estante_livros", Vector3(B.position.x + 1.0, A, B.position.y + 2.0), PI * 0.5, "porto_escritorio", "ESTANTE")
	_texto(Vector3(c.x, A + 2.6, B.end.y + 0.17), 0.0, "ADMINISTRAÇÃO DO PORTO", Color(0.12, 0.2, 0.45), 40)
	_pontos_em(B.grow(-2.0), 0.0, 3, "escritorio")
	_pontos_em(B.grow(-2.0), A, 3, "escritorio")

func _porto_galpao(B: Rect2) -> void:
	var H := 9.0
	var cor := Color(0.62, 0.66, 0.7)
	_perimetro(B, 0.0, H, cor, Color(0.6, 0.62, 0.64), [[[4.0, 10.0, 0.0, 6.0], [B.size.x - 10.0, B.size.x - 4.0, 0.0, 6.0]], [_porta(6.0)], [], []])
	_prisma(fora, Vector3(B.get_center().x, H, B.get_center().y), B.size.y + 0.6, 2.2, B.size.x + 0.6, false, cor * 0.85, cor)
	concreto.caixa(Vector3(B.get_center().x, 0.02, B.get_center().y), Vector3(B.size.x - 0.3, 0.04, B.size.y - 0.3), CONCRETO, Basis.IDENTITY, true)
	teto.caixa(Vector3(B.get_center().x, H - 0.05, B.get_center().y), Vector3(B.size.x - 0.3, 0.1, B.size.y - 0.3), cor * 0.7, Basis.IDENTITY, false, true)
	for k in 3:
		_porta_palete(Vector2(B.position.x + 6.0 + k * 9.0, B.position.y + 3.0), 0.0, "porto_carga")
		_porta_palete(Vector2(B.position.x + 6.0 + k * 9.0, B.position.y + 9.5), PI, "porto_carga")
	_empilhadeira(Vector2(B.position.x + 20.0, B.end.y - 6.0), 0.4)
	for k in 6:
		_palete(Vector2(B.position.x + 3.0 + k * 2.0, B.end.y - 3.0), 0.0, r.randi_range(1, 3))
	_texto(Vector3(B.get_center().x, H - 1.2, B.end.y + 0.17), 0.0, "ARMAZÉM 3 · CARGA GERAL", Color(0.15, 0.15, 0.18), 46)
	_pontos_em(B.grow(-3.0), 0.0, 4, "galpao")

# carreta porta-contêiner (cavalo mecânico + chassi + contêiner de 12 m), ao longo de Z girado de g
func _carreta_conteiner(p: Vector2, g: float, cor: Color) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, 0, p.y)
	_cavalo(o + b * Vector3(0, 0, 8.4), g, Color(0.9, 0.88, 0.82))
	resto.caixa(o + b * Vector3(0, 1.1, 0), Vector3(2.4, 0.25, 12.4), METAL_ESC, b)
	for z in [-5.2, -4.0]:
		for x in [-1.0, 1.0]:
			resto.cilindro(o + b * Vector3(x, 0.5, z), 0.5, 0.3, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	var bc := b * Basis(Vector3.UP, PI * 0.5)
	resto.caixa(o + Vector3(0, 1.25 + 1.3, 0), Vector3(12.1, 2.58, 2.42), cor, bc)
	col.append([o + Vector3(0, 1.9, 0) + b * Vector3(0, 0, 2.0), Vector3(2.5, 3.8, 16.6), 0.0, b])
	_loot(o + b * Vector3(1.9, 0.1, -3.0), "porto_conteiner", "CONTÊINER NA CARRETA", Vector2i(8, 5))

# cavalo mecânico (cabine de caminhão), virado para +Z girado de g
func _cavalo(o: Vector3, g: float, cor: Color) -> void:
	var b := Basis(Vector3.UP, g)
	resto.caixa(o + b * Vector3(0, 1.0, -0.6), Vector3(2.4, 0.4, 5.0), METAL_ESC, b)
	resto.caixa(o + b * Vector3(0, 2.1, 0.9), Vector3(2.45, 2.2, 2.0), cor, b)
	resto.caixa(o + b * Vector3(0, 2.55, 1.91), Vector3(2.2, 0.9, 0.04), Color(0.12, 0.15, 0.18), b)
	resto.caixa(o + b * Vector3(0, 1.4, 1.95), Vector3(2.3, 0.7, 0.1), Color(0.6, 0.6, 0.6), b)
	for s in [-1.0, 1.0]:
		resto.cilindro(o + b * Vector3(s * 1.0, 3.0, -0.1), 0.08, 1.8, 6, Color(0.7, 0.7, 0.72))
	for z in [1.0, -1.8, -3.0]:
		for x in [-1.0, 1.0]:
			resto.cilindro(o + b * Vector3(x, 0.5, z), 0.5, 0.32, 8, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	col.append([o + b * Vector3(0, 1.6, -0.3), Vector3(2.5, 3.2, 5.6), 0.0, b])

# empilhadeira de contêiner ("reach stacker") com um contêiner na lança
func _reach_stacker(p: Vector2, g: float) -> void:
	var b := Basis(Vector3.UP, g)
	var o := Vector3(p.x, 0, p.y)
	resto.caixa(o + b * Vector3(0, 1.3, 0), Vector3(3.6, 1.6, 9.0), AMARELO_SEG, b)
	resto.caixa(o + b * Vector3(0, 3.0, -2.0), Vector3(1.8, 1.8, 1.8), Color(0.2, 0.22, 0.25), b)
	var lanca := b * Basis(Vector3.RIGHT, 0.35)
	resto.caixa(o + b * Vector3(0, 4.6, 2.5), Vector3(1.0, 1.0, 9.0), AMARELO_SEG * 0.9, lanca)
	resto.caixa(o + b * Vector3(0, 7.6, 6.6), Vector3(2.6, 0.4, 12.2), Color(0.2, 0.2, 0.22), b * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.UP, -PI * 0.5))
	resto.caixa(o + b * Vector3(0, 6.1, 6.6), Vector3(2.42, 2.58, 12.1), CORES_CONTEINER[2], b)
	for z in [-3.0, 3.0]:
		for x in [-1.7, 1.7]:
			resto.cilindro(o + b * Vector3(x, 0.8, z), 0.8, 0.6, 10, Color(0.08, 0.08, 0.09), b * Basis(Vector3.FORWARD, PI * 0.5))
	col.append([o + b * Vector3(0, 1.8, 0), Vector3(3.6, 3.6, 9.0), 0.0, b])
	col.append([o + b * Vector3(0, 6.1, 6.6), Vector3(2.42, 2.6, 12.1), 0.0, b])

# PORTÊINER (guindaste de cais) com as pernas em x ± 8 e nos trilhos z = -33 (terra) e -50,5 (água); lança de z = -15
# a -92 (por cima do navio); escada em zigue-zague ao lado da perna de terra até o pórtico (28 m) e passarela por cima
# da viga do pórtico. Em cima: caixa militar? não — caixa de ferramentas do operador.
func _porteiner(xg: float) -> void:
	var yp := 28.0                                 # alto do pórtico
	var zt := -33.0
	var za := -50.5
	for x in [xg - 8.0, xg + 8.0]:
		for z in [zt, za]:
			_bx(fora, Vector3(x, yp * 0.5, z), Vector3(1.4, yp, 1.4), AZUL_GUINDASTE)
			resto.caixa(Vector3(x, 0.6, z), Vector3(2.2, 1.2, 4.0), AMARELO_SEG * 0.9)                     # truque com as rodas
		# travessas e diagonais entre a perna de terra e a de água
		for y in [10.0, 20.0]:
			fora.caixa(Vector3(x, y, (zt + za) * 0.5), Vector3(0.8, 0.8, za - zt), AZUL_GUINDASTE * 0.9)
		var dz := za - zt
		var ang := atan2(10.0, absf(dz))
		fora.caixa(Vector3(x, 5.0, (zt + za) * 0.5), Vector3(0.5, 0.5, sqrt(dz * dz + 100.0)), AZUL_GUINDASTE * 0.85, Basis(Vector3.RIGHT, ang))
	# vigas do pórtico
	for z in [zt, za]:
		_bx(fora, Vector3(xg, yp - 0.75, z), Vector3(17.4, 1.5, 1.5), AZUL_GUINDASTE)
	for x in [xg - 8.0, xg + 8.0]:
		_bx(fora, Vector3(x, yp - 0.75, (zt + za) * 0.5), Vector3(1.5, 1.5, absf(za - zt)), AZUL_GUINDASTE)
	# lança (2 vigas) de z = -15 a -92, casa de máquinas, torre em A e os tirantes
	var yl := yp + 3.5
	for s in [-1.0, 1.0]:
		_bx(fora, Vector3(xg + s * 2.2, yl, -53.5), Vector3(1.0, 1.6, 77.0), AZUL_GUINDASTE)
	for k in 14:
		fora.caixa(Vector3(xg, yl - 0.5, -17.0 - k * 5.5), Vector3(4.4, 0.3, 0.3), AZUL_GUINDASTE * 0.85)
	for s in [-1.0, 1.0]:
		fora.caixa(Vector3(xg + s * 2.2, yp + 1.7, zt), Vector3(0.7, 3.4, 0.7), AZUL_GUINDASTE)
		fora.caixa(Vector3(xg + s * 2.2, yp + 1.7, za), Vector3(0.7, 3.4, 0.7), AZUL_GUINDASTE)
	_bx(fora, Vector3(xg, yl + 2.6, -24.0), Vector3(7.0, 3.6, 9.0), Color(0.9, 0.9, 0.88))
	fora.caixa(Vector3(xg, yl + 2.6, -19.45), Vector3(7.02, 0.6, 0.1), AZUL_GUINDASTE)
	var topo := Vector3(xg, yl + 16.0, -41.0)
	for s in [-1.0, 1.0]:
		var pe := Vector3(xg + s * 2.2, yl + 0.8, -35.0)
		var pe2 := Vector3(xg + s * 2.2, yl + 0.8, -47.0)
		for q in [pe, pe2]:
			_viga(q, topo + Vector3(s * 0.8, 0, 0), 0.6, AZUL_GUINDASTE)
		_viga(topo + Vector3(s * 0.8, 0, 0), Vector3(xg + s * 2.2, yl + 0.8, -88.0), 0.18, METAL_ESC)    # tirantes
		_viga(topo + Vector3(s * 0.8, 0, 0), Vector3(xg + s * 2.2, yl + 0.8, -16.0), 0.18, METAL_ESC)
	# carrinho e o spreader com um contêiner pendurado em cima do navio; cabine do operador
	resto.caixa(Vector3(xg, yl - 1.2, -70.0), Vector3(5.0, 1.0, 4.0), Color(0.3, 0.3, 0.32))
	resto.caixa(Vector3(xg + 1.3, yl - 2.6, -68.0), Vector3(2.0, 2.0, 2.4), Color(0.85, 0.85, 0.82))
	resto.caixa(Vector3(xg + 1.3, yl - 2.6, -66.75), Vector3(1.8, 1.2, 0.05), Color(0.12, 0.15, 0.2))
	for dx in [-1.5, 1.5]:
		resto.caixa(Vector3(xg + dx, yl - 6.0, -70.0), Vector3(0.05, 9.0, 0.05), METAL_ESC)
	resto.caixa(Vector3(xg, yl - 10.6, -70.0), Vector3(12.4, 0.4, 2.6), AMARELO_SEG, Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.UP, -PI * 0.5))
	resto.caixa(Vector3(xg, yl - 12.2, -70.0), Vector3(12.1, 2.58, 2.42), CORES_CONTEINER[int(xg) % CORES_CONTEINER.size()])
	# a ESCADA (zigue-zague, 8 lances de 3,5 m) do lado de terra, encostada na perna x - 8, até o pórtico
	var e0 := Vector3(xg - 8.0 - 0.9 - (3.5 / 0.6 + 2.4), 0.0, zt - 1.15)
	_escada_zigue(e0, true, 1.0, 8, 3.5, METAL, METAL_ESC, true)
	# ponte da escada até a viga e a passarela em cima da viga do pórtico (z = -33), com grade dos dois lados
	_bx(fora, Vector3(xg - 8.0 - 0.45, yp - 0.15, zt), Vector3(1.0, 0.3, 2.3), METAL_ESC)
	_grade(Vector2(xg - 8.9, zt - 0.8), Vector2(xg + 8.7, zt - 0.8), yp)
	_grade(Vector2(xg - 8.9, zt + 0.8), Vector2(xg + 8.7, zt + 0.8), yp)
	_grade(Vector2(xg + 8.7, zt - 0.8), Vector2(xg + 8.7, zt + 0.8), yp)
	_caixa_militar(Vector3(xg + 4.0, yp, zt), 0.0, "porto_guindaste")
	_ponto(Vector3(xg + 1.0, yp, zt), "guindaste")
	_texto(Vector3(xg, yp - 0.75, za - 0.78), PI, "QC-%02d" % (int(absf(xg)) % 97), Color(0.95, 0.95, 0.92), 90)

# viga reta de a até b (caixa girada), sem colisão
func _viga(a: Vector3, b: Vector3, grossura: float, cor: Color) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.01:
		return
	var z := d / L
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x)
	fora.caixa((a + b) * 0.5, Vector3(grossura, grossura, L), cor, Basis(x, y, z))

# O NAVIO (140 m) atracado ao longo do cais: costado do lado do cais em z = -54, boca de 24 m, convés a 9 m.
func _navio(nome: String) -> void:
	var zc := -54.0                                # costado do lado do cais
	var zf := -78.0                                # costado do lado do mar
	var zm := (zc + zf) * 0.5
	var yd := 9.0                                  # convés principal
	var yb := -8.0                                 # quilha (debaixo d'água)
	# casco: parte de baixo vermelha, faixa preta na linha d'água, costado azul-escuro; proa em cunha, popa reta
	fora.caixa(Vector3(-4.0, (yb + Y_AGUA + 0.3) * 0.5, zm), Vector3(132.0, Y_AGUA + 0.3 - yb, 24.0), CASCO_BAIXO)
	fora.caixa(Vector3(-4.0, Y_AGUA + 0.5, zm), Vector3(132.04, 0.4, 24.04), Color(0.06, 0.06, 0.07))
	fora.caixa(Vector3(-4.0, (Y_AGUA + 0.7 + yd) * 0.5, zm), Vector3(132.0, yd - Y_AGUA - 0.7, 24.0), CASCO)
	col.append([Vector3(-4.0, (yb + yd) * 0.5, zm), Vector3(132.0, yd - yb, 24.0), 0.0, Basis.IDENTITY])
	var xp := 62.0
	var ponta := Vector3(74.0, yd, zm)
	for f in [[yb, yd]]:
		var y0: float = f[0]
		var y1: float = f[1]
		_face(fora, [Vector3(xp, y0, zc), Vector3(ponta.x, y0, zm), Vector3(ponta.x, y1, zm), Vector3(xp, y1, zc)], Vector3(0.7, 0, 0.7).normalized(), CASCO)
		_face(fora, [Vector3(xp, y0, zf), Vector3(ponta.x, y0, zm), Vector3(ponta.x, y1, zm), Vector3(xp, y1, zf)], Vector3(0.7, 0, -0.7).normalized(), CASCO)
		_face(fora, [Vector3(xp, y1, zc), Vector3(ponta.x, y1, zm), Vector3(xp, y1, zf)], Vector3.UP, CONVES)
	col.append([Vector3(xp + 4.0, (yb + yd) * 0.5, zm), Vector3(8.0, yd - yb, 12.0), 0.0, Basis.IDENTITY])
	# convés e a borda (balaustrada baixa de ferro) com a abertura da escada de acesso
	fora.caixa(Vector3(-4.0, yd + 0.02, zm), Vector3(131.8, 0.06, 23.8), CONVES, Basis.IDENTITY, true)
	_grade(Vector2(-70.0, zc - 0.1), Vector2(-16.4, zc - 0.1), yd)
	_grade(Vector2(-13.6, zc - 0.1), Vector2(xp, zc - 0.1), yd)
	_grade(Vector2(-70.0, zf + 0.1), Vector2(xp, zf + 0.1), yd)
	_grade(Vector2(-70.0, zc - 0.1), Vector2(-70.0, zf + 0.1), yd)
	_grade(Vector2(xp, zc - 0.1), Vector2(ponta.x - 0.5, zm), yd)
	_grade(Vector2(xp, zf + 0.1), Vector2(ponta.x - 0.5, zm), yd)
	# nome no costado (do lado do cais, perto da proa) e na popa
	_texto(Vector3(40.0, 5.5, zc + 0.03), 0.0, nome, Color(0.95, 0.95, 0.92), 260)
	_texto(Vector3(-70.03, 5.5, zm), -PI * 0.5, nome, Color(0.95, 0.95, 0.92), 150)
	_texto(Vector3(-70.03, 3.8, zm), -PI * 0.5, "NOVA YORK", Color(0.95, 0.95, 0.92), 110)
	for k in 7:                                                                       # marcas de calado na proa
		fora.caixa(Vector3(60.5, Y_AGUA + 0.6 + k * 1.0, zc + 0.03), Vector3(0.6, 0.08, 0.02), Color(0.95, 0.95, 0.92))
	# CONTÊINERES no convés: 8 baias (x -48..52) x 8 fileiras (z -56,4..-76,7), pilhas de 2 a 5 em cima da tampa do porão
	for baia in 8:
		var xb := -41.7 + baia * 12.6
		fora.caixa(Vector3(xb, yd + 0.3, zm - 0.5), Vector3(12.4, 0.6, 20.6), Color(0.3, 0.32, 0.3))
		for fil in 8:
			var zf2 := -57.6 - fil * 2.52
			var h := r.randi_range(2, 5)
			if baia == 3 and fil == 0:
				h = 1                                                                 # dá para subir num degrau? não: só mais baixo
			for k in h:
				var cor: Color = CORES_CONTEINER[r.randi() % CORES_CONTEINER.size()]
				resto.caixa(Vector3(xb, yd + 0.6 + k * 2.6 + 1.3, zf2), Vector3(12.1, 2.58, 2.42), cor)
				resto.caixa(Vector3(xb + 6.06, yd + 0.6 + k * 2.6 + 1.3, zf2), Vector3(0.06, 2.6, 2.46), cor * 0.7)
			col.append([Vector3(xb, yd + 0.6 + h * 1.3, zf2), Vector3(12.1, h * 2.6, 2.42), 0.0, Basis.IDENTITY])
		col.append([Vector3(xb, yd + 0.3, zm - 0.5), Vector3(12.4, 0.6, 20.6), 0.0, Basis.IDENTITY])
	# contêineres abertos no convés (do lado do cais) com loot
	_loot(Vector3(-16.0, yd + 0.1, -55.3), "porto_conteiner", "CARGA DO CONVÉS", Vector2i(8, 5))
	_loot(Vector3(28.0, yd + 0.1, -55.3), "porto_apreendido", "CARGA LACRADA", Vector2i(8, 5))
	_pontos_em(Rect2(-48, -56.1, 100, 1.4), yd, 5, "conves")
	# castelo de proa: guinchos, cabrestante, mastro
	for z in [zc - 3.0, zf + 3.0]:
		resto.cilindro(Vector3(58.0, yd + 0.6, z), 0.8, 1.2, 10, Color(0.6, 0.12, 0.1), Basis(Vector3.FORWARD, PI * 0.5))
		_col(Vector3(58.0, yd + 0.6, z), Vector3(1.4, 1.2, 1.6))
	fora.cilindro(Vector3(64.0, yd + 6.0, zm), 0.25, 12.0, 6, Color(0.85, 0.85, 0.82))
	# amarras: do convés até os cabeços do cais
	for xa in [-54.0, -30.0, 30.0, 54.0]:
		_viga(Vector3(xa + (2.0 if xa > 0 else -2.0), yd + 0.6, zc + 0.1), Vector3(xa, 0.85, -52.3), 0.08, Color(0.75, 0.65, 0.45))
	# ESCADA DE ACESSO do cais (y 0) até o convés (y 9): ao longo de +X em z = -51,9, plataforma e a ponte até o convés
	_escada(Vector2(-30.0, -51.9), Vector2(1, 0), 1.4, 0.0, yd, 15.0, METAL, 1)
	_bx(fora, Vector3(-14.0, yd - 0.15, -52.1), Vector3(2.2, 0.3, 2.2), METAL_ESC)
	_bx(fora, Vector3(-15.0, yd - 0.1, -53.5), Vector3(2.6, 0.2, 1.7), METAL_ESC)
	_grade(Vector2(-13.0, -51.0), Vector2(-13.0, -53.2), yd)
	_grade(Vector2(-16.2, -51.0), Vector2(-13.0, -51.0), yd)
	for x in [-14.8, -13.2]:
		fora.cilindro(Vector3(x, yd * 0.5, -51.1), 0.08, yd, 5, METAL_ESC)
	# CASARIO (x -64..-50, z -75..-57): 5 andares de 3 m com janelas, a PONTE DE COMANDO em cima (y 24..27) e as asas
	var cas := Rect2(-64.0, -75.0, 14.0, 18.0)
	var yp := yd + 15.0
	_bx(paredes, Vector3(cas.get_center().x, (yd + yp) * 0.5, cas.get_center().y), Vector3(cas.size.x, yp - yd, cas.size.y), Color(0.92, 0.92, 0.9))
	for nv in 5:
		var yj := yd + nv * 3.0 + 1.6
		for k in 6:
			resto.caixa(Vector3(-62.5 + k * 2.4, yj, cas.end.y + 0.02), Vector3(1.0, 0.8, 0.04), Color(0.12, 0.15, 0.2))
			resto.caixa(Vector3(-62.5 + k * 2.4, yj, cas.position.y - 0.02), Vector3(1.0, 0.8, 0.04), Color(0.12, 0.15, 0.2))
		for k in 6:
			resto.caixa(Vector3(cas.end.x + 0.02, yj, -73.0 + k * 3.0), Vector3(0.04, 0.8, 1.0), Color(0.12, 0.15, 0.2))
	# a escada por fora do casario, do lado do cais (zigue-zague de 5 lances de 3 m): galerias de z -57 a -54,7
	_escada_zigue(Vector3(-63.6, yd, -54.7), true, -1.0, 5, 3.0, METAL, METAL_ESC)
	# ponte de comando
	var vp := [[1.2, 3.4, 0.9, 2.4, "janela"], [4.4, 6.6, 0.9, 2.4, "janela"], [7.6, 9.8, 0.9, 2.4, "janela"], [10.8, 13.0, 0.9, 2.4, "janela"]]
	var porta := [[2.2, 3.3, 0.0, 2.2]]
	_perimetro(cas, yp, 3.0, Color(0.92, 0.92, 0.9), Color(0.85, 0.85, 0.82), [porta, vp, [], vp], fora)
	piso.caixa(Vector3(cas.get_center().x, yp + 0.02, cas.get_center().y), Vector3(cas.size.x - 0.4, 0.04, cas.size.y - 0.4), Color(0.4, 0.42, 0.45), Basis.IDENTITY, true)
	_laje(cas.grow(0.4), yp + 3.0, 0.3, [], Color(0.85, 0.85, 0.82), true)
	var cp := Vector3(cas.end.x - 1.4, yp, cas.get_center().y)
	_bx(resto, cp + Vector3(0, 0.55, 0), Vector3(1.2, 1.1, 8.0), Color(0.25, 0.27, 0.3))                               # console
	for k in 5:
		resto.caixa(cp + Vector3(0.2, 1.15, -3.0 + k * 1.5), Vector3(0.6, 0.05, 1.0), Color(0.05, 0.1, 0.08))
	resto.cilindro(cp + Vector3(-1.5, 1.0, 0), 0.4, 0.06, 12, MADEIRA, Basis(Vector3.FORWARD, PI * 0.5))               # o leme
	_bx(resto, Vector3(-60.0, yp + 0.5, -70.0), Vector3(2.4, 1.0, 1.4), MADEIRA)                                       # mesa de cartas
	resto.caixa(Vector3(-60.0, yp + 1.02, -70.0), Vector3(2.2, 0.01, 1.2), Color(0.85, 0.82, 0.7))
	_loot(Vector3(-60.0, yp + 0.1, -68.8), "porto_navio", "MESA DE CARTAS", Vector2i(6, 4))
	_movel("armario_armas", Vector3(-63.3, yp, -62.0), PI * 0.5, "porto_navio", "ARMÁRIO DO COMANDANTE")
	_texto(Vector3(-57.0, yp + 2.7, cas.end.y + 0.03), 0.0, nome, Color(0.15, 0.2, 0.4), 40)
	_pontos_em(cas.grow(-1.5), yp, 2, "ponte")
	# asa da ponte do lado do cais (o fim da escada já é a galeria do nível 5) e grade
	_bx(fora, Vector3(-53.0, yp - 0.15, -55.85), Vector3(6.0, 0.3, 2.3), METAL_ESC)
	_grade(Vector2(-56.1, -54.7), Vector2(-50.0, -54.7), yp)
	_grade(Vector2(-50.0, -54.7), Vector2(-50.0, -57.0), yp)
	# radar, chaminé, baleeira
	fora.cilindro(Vector3(-57.0, yp + 5.0, -66.0), 0.2, 4.0, 6, METAL_ESC)
	fora.caixa(Vector3(-57.0, yp + 7.0, -66.0), Vector3(0.2, 0.2, 3.0), METAL_ESC, Basis(Vector3.UP, 0.6))
	_bx(fora, Vector3(-67.0, yd + 11.0, -66.0), Vector3(4.6, 22.0, 6.0), CORES_CONTEINER[0] * 0.9)
	fora.caixa(Vector3(-67.0, yd + 18.0, -66.0), Vector3(4.65, 1.2, 6.05), Color(0.92, 0.92, 0.9))
	fora.caixa(Vector3(-67.0, yd + 22.05, -66.0), Vector3(4.66, 0.1, 6.06), Color(0.05, 0.05, 0.05))
	resto.caixa(Vector3(-57.0, yd + 6.5, -76.6), Vector3(7.0, 2.0, 2.4), Color(0.95, 0.45, 0.08))
	for x in [-60.0, -54.0]:
		resto.caixa(Vector3(x, yd + 6.5, -76.0), Vector3(0.2, 3.0, 0.2), METAL_ESC)

# ======================================================================================================
# HANGAR DE CARGA PARA CAMINHÕES (90 x 70): galpão de aço de 64 x 34 com telhado DENTE DE SERRA, piso na altura das
# carrocerias (1,2 m) com 8 DOCAS na frente (portas de enrolar: abertas, meias e fechadas), carretas encostadas,
# cavalos mecânicos no pátio, BALANÇA de caminhões com a cabine, BOMBA DE DIESEL (enche o galão), lava-jato de
# caminhão, portaria. Dentro: porta-paletes, empilhadeiras, paletes, MEZANINO do escritório (escada) e a sala dos
# motoristas embaixo. A história: a última carga de comida que não saiu.
# ======================================================================================================
func _hangar() -> void:
	var D := 1.2                                     # piso das docas
	var H := 10.0
	var B := Rect2(-32, -31, 64, 34)
	var cor := Color(0.68, 0.7, 0.72)
	var x0 := B.position.x
	var x1 := B.end.x
	var z0 := B.position.y
	var z1 := B.end.y
	dentro = B.grow(-0.2)
	# ---- chão e portaria ----
	_chao(Rect2(-45, 3, 90, 32), ASFALTO * 1.05)
	_chao(Rect2(-45, -35, 90, 38), CONCRETO * 0.95)
	for k in 8:
		_faixa(Vector2(x0 + 4.0 + k * 8.0 - 1.9, 4.0), Vector2(x0 + 4.0 + k * 8.0 - 1.9, 18.0), 0.14, AMARELO_SEG)
	_cerca(Vector2(-45, 34.5), Vector2(-8, 34.5))
	_cerca(Vector2(8, 34.5), Vector2(45, 34.5))
	_guarita(Vector2(11.0, 31.0))
	resto.caixa(Vector3(0, 1.0, 31.0), Vector3(14.0, 0.12, 0.12), Color(0.85, 0.85, 0.85))
	_placa(Vector3(-20.0, 4.0, 34.0), Vector3(12.0, 2.0, 0.3), Color(0.75, 0.3, 0.08), Color(0.95, 0.95, 0.92))
	_texto(Vector3(-20.0, 4.2, 34.17), 0.0, "TRANSPORTADORA ATLÂNTICO", Color(0.97, 0.97, 0.95), 46)
	_texto(Vector3(-20.0, 3.45, 34.17), 0.0, "CENTRO DE CARGAS · NOVA YORK", Color(0.97, 0.97, 0.95), 28)
	# ---- embasamento das docas e as paredes ----
	_bx(concreto, Vector3(B.get_center().x, D * 0.5, B.get_center().y), Vector3(B.size.x, D, B.size.y), CONCRETO_ESC)
	concreto.caixa(Vector3(B.get_center().x, D + 0.02, B.get_center().y), Vector3(B.size.x - 0.3, 0.04, B.size.y - 0.3), CONCRETO, Basis.IDENTITY, true)
	var docas: Array = []
	for k in 8:
		docas.append([4.0 + k * 8.0 - 1.9, 4.0 + k * 8.0 + 1.9, 0.0, 4.4])
	_perimetro(B, D, H, cor, Color(0.62, 0.64, 0.66), [docas, [_porta(10.0)], [], [_porta(8.0)]])
	# portas de enrolar: 0 aberta, 1 meia, 2 fechada
	for k in 8:
		var xd: float = x0 + 4.0 + k * 8.0
		var est: int = [0, 1, 0, 2, 0, 1, 2, 0][k]
		if est > 0:
			var hp := 4.4 if est == 2 else 2.0
			resto.caixa(Vector3(xd, D + 4.4 - hp * 0.5, z1), Vector3(3.8, hp, 0.08), Color(0.75, 0.75, 0.72))
			for kk in int(hp / 0.25):
				resto.caixa(Vector3(xd, D + 4.4 - 0.12 - kk * 0.25, z1 + 0.05), Vector3(3.8, 0.02, 0.02), Color(0.55, 0.55, 0.52))
			col.append([Vector3(xd, D + 4.4 - hp * 0.5, z1), Vector3(3.8, hp, 0.2), 0.0, Basis.IDENTITY])
		resto.caixa(Vector3(xd, D + 4.7, z1 + 0.25), Vector3(4.2, 0.5, 0.5), Color(0.4, 0.42, 0.45))
		for s in [-1.0, 1.0]:
			resto.caixa(Vector3(xd + s * 1.7, D - 0.4, z1 + 0.15), Vector3(0.3, 0.5, 0.3), Color(0.08, 0.08, 0.09))     # para-choques
		resto.caixa(Vector3(xd, D + 0.02, z1 - 1.0), Vector3(2.0, 0.04, 2.0), Color(0.45, 0.47, 0.5))                  # nivelador
		_texto(Vector3(xd, D + 5.3, z1 + 0.06), 0.0, str(k + 1), Color(0.15, 0.15, 0.18), 60)
	# ---- telhado DENTE DE SERRA: 6 dentes ao longo de Z (face de vidro em pé virada para a frente) ----
	var nd := 6
	var pz := B.size.y / nd
	for k in nd:
		var za := z0 + k * pz
		var zb := za + pz
		var yt := D + H
		_face(fora, [Vector3(x0, yt, za), Vector3(x1, yt, za), Vector3(x1, yt + 2.6, zb), Vector3(x0, yt + 2.6, zb)], Vector3(0, pz, -2.6).normalized(), cor * 0.82)
		_face(fora, [Vector3(x0, yt, zb), Vector3(x1, yt, zb), Vector3(x1, yt + 2.6, zb), Vector3(x0, yt + 2.6, zb)], Vector3(0, 0, 1), Color(0.35, 0.45, 0.5))
		for s in [x0, x1]:
			_face(fora, [Vector3(s, yt, za), Vector3(s, yt, zb), Vector3(s, yt + 2.6, zb)], Vector3(sign(s), 0, 0), cor * 0.9)
	teto.caixa(Vector3(B.get_center().x, D + H - 0.05, B.get_center().y), Vector3(B.size.x - 0.3, 0.1, B.size.y - 0.3), cor * 0.7, Basis.IDENTITY, false, true)
	# ---- plataforma das docas por fora das portas (z 3..5, na altura das carrocerias) e as escadas nas pontas ----
	_bx(concreto, Vector3(0, D * 0.5, z1 + 1.0), Vector3(70.0, D, 2.0), CONCRETO_ESC)
	concreto.caixa(Vector3(0, D + 0.02, z1 + 1.0), Vector3(70.0, 0.04, 2.0), CONCRETO, Basis.IDENTITY, true)
	fora.caixa(Vector3(0, D - 0.05, z1 + 2.02), Vector3(70.0, 0.1, 0.06), AMARELO_SEG)
	for s in [-1.0, 1.0]:
		_escada(Vector2(s * 33.9, z1 + 4.0), Vector2(0, -1), 2.2, 0.0, D, 2.0, CONCRETO, 1 if s < 0 else -1)
	# ---- dentro: porta-paletes, empilhadeiras, paletes ----
	for k in 4:
		_porta_palete(Vector2(x0 + 22.0 + k * 9.5, z0 + 3.0), 0.0, "carga_paletes", 6.0)
		_porta_palete(Vector2(x0 + 22.0 + k * 9.5, z0 + 12.0), PI, "carga_paletes", 6.0)
		_porta_palete(Vector2(x0 + 22.0 + k * 9.5, z0 + 13.6), 0.0, "carga_paletes", 6.0)
	_empilhadeira(Vector2(x0 + 30.0, z1 - 8.0), 0.3)
	_empilhadeira(Vector2(x0 + 48.0, z1 - 6.0), -1.2)
	for k in 10:
		_palete(Vector2(x0 + 22.0 + (k % 5) * 2.4, z1 - 3.5 - (k / 5) * 2.0), 0.0, r.randi_range(1, 3))
	for k in 3:
		_loot(Vector3(x0 + 24.0 + k * 3.0, D + 0.1, z1 - 2.5), "carga_paletes", "CARGA NA DOCA", Vector2i(8, 6))
	_texto(Vector3(x0 + 40.0, D + 6.5, z0 + 0.2), 0.0, "ÚLTIMA CARGA: ALIMENTOS · DESTINO: ABRIGOS DA DEFESA CIVIL", Color(0.7, 0.1, 0.08), 40)
	# ---- MEZANINO do escritório (x -31..-15, z -30..-20) com escada, e a SALA DOS MOTORISTAS embaixo ----
	var mz := Rect2(x0 + 1.0, z0 + 1.0, 16.0, 10.0)
	var ym := D + 3.6
	_laje(mz, ym - 0.3, 0.3, [], Color(0.55, 0.45, 0.35))
	for p in [Vector2(mz.end.x, mz.end.y), Vector2(mz.end.x, mz.position.y), Vector2(mz.position.x + 8.0, mz.end.y)]:
		_bx(fora, Vector3(p.x - 0.2, D + (ym - D) * 0.5, p.y - 0.2), Vector3(0.3, ym - D, 0.3), METAL_ESC)
	_perimetro(mz, ym, 2.8, Color(0.85, 0.85, 0.82), Color(0.85, 0.85, 0.82), [[[3.0, 6.0, 1.0, 2.2, "janela"], [9.0, 12.0, 1.0, 2.2, "janela"], [13.4, 14.6, 0.0, 2.2]], [[2.0, 8.0, 1.0, 2.2, "janela"]], [], []])
	_laje(mz.grow(0.1), ym + 2.8, 0.15, [], Color(0.6, 0.6, 0.6), true)
	_escada(Vector2(mz.position.x + 14.0, mz.end.y + 6.2), Vector2(0, -1), 1.2, D, ym - D, 6.2, METAL, 1)   # chega na porta
	_movel("mesa_escritorio", Vector3(mz.position.x + 3.0, ym, mz.position.y + 3.0), 0.0, "carga_escritorio", "MESA DO DESPACHANTE")
	_movel("mesa_escritorio", Vector3(mz.position.x + 8.0, ym, mz.position.y + 3.0), 0.0, "carga_escritorio", "MESA")
	_movel("arquivo", Vector3(mz.position.x + 12.0, ym, mz.position.y + 0.8), 0.0, "carga_escritorio", "ARQUIVO")
	_bx(resto, Vector3(mz.position.x + 14.0, ym + 0.6, mz.position.y + 0.9), Vector3(1.0, 1.2, 0.9), Color(0.25, 0.27, 0.28))
	_loot(Vector3(mz.position.x + 14.0, ym + 0.1, mz.position.y + 1.8), "carga_cofre", "COFRE DA TRANSPORTADORA", Vector2i(5, 4))
	_pontos_em(mz.grow(-1.5), ym, 2, "escritorio")
	_movel("sofa", Vector3(mz.position.x + 3.0, D, mz.end.y - 2.0), PI)
	_movel("mesa_centro", Vector3(mz.position.x + 3.0, D, mz.end.y - 4.0), 0.0)
	_movel("geladeira", Vector3(mz.position.x + 8.0, D, mz.position.y + 0.6), 0.0, "carga_motoristas", "GELADEIRA DOS MOTORISTAS")
	_movel("mesa_jantar", Vector3(mz.position.x + 11.0, D, mz.position.y + 5.0), 0.0)
	_movel("armario_armas", Vector3(mz.position.x + 0.6, D, mz.position.y + 5.0), PI * 0.5, "carga_motoristas", "ARMÁRIOS DOS MOTORISTAS")
	_pontos_em(mz.grow(-1.5), D, 2, "motoristas")
	_pontos_em(Rect2(x0 + 20.0, z0 + 2.0, 40.0, 28.0), D, 6, "galpao")
	# ---- PÁTIO: carretas nas docas, cavalos mecânicos, caminhão inteiro, balança, bomba de diesel, lava-jato ----
	for k in [0, 2, 5]:
		var xd: float = x0 + 4.0 + k * 8.0
		_carreta(Vector2(xd, z1 + 8.2), 0.0)
	_cavalo(Vector3(-30.0, 0, 26.0), PI * 0.5, Color(0.75, 0.12, 0.1))
	_cavalo(Vector3(-22.0, 0, 27.0), PI * 0.5 + 0.1, Color(0.15, 0.3, 0.6))
	_cavalo(Vector3(26.0, 0, 22.0), PI, Color(0.9, 0.88, 0.82))
	# balança de caminhões com a cabine
	fora.caixa(Vector3(38.0, 0.06, 2.0), Vector3(3.6, 0.12, 18.0), Color(0.4, 0.42, 0.45), Basis.IDENTITY, true)
	_guarita(Vector2(42.5, 2.0))
	_texto(Vector3(38.0, 0.14, 11.2), 0.0, "BALANÇA", AMARELO_SEG, 40)
	# bomba de diesel com cobertura (PEGAR com um galão = encher; mundo/veiculos.gd)
	fora.caixa(Vector3(-38.0, 5.0, 14.0), Vector3(8.0, 0.4, 6.0), Color(0.75, 0.3, 0.08))
	for x in [-41.0, -35.0]:
		_bx(fora, Vector3(x, 2.5, 14.0), Vector3(0.4, 5.0, 0.4), METAL)
	_bomba(Vector2(-38.0, 14.0), Color(0.75, 0.3, 0.08))
	_texto(Vector3(-38.0, 4.5, 17.05), 0.0, "DIESEL", Color(0.97, 0.97, 0.95), 50)
	# lava-jato de caminhão (pórtico com escovas)
	for x in [36.0, 44.0]:
		_bx(fora, Vector3(x, 3.0, -12.0), Vector3(0.5, 6.0, 0.5), METAL)
	fora.caixa(Vector3(40.0, 6.1, -12.0), Vector3(8.5, 0.5, 0.6), METAL)
	for x in [37.2, 42.8]:
		resto.cilindro(Vector3(x, 3.0, -12.0), 0.55, 5.0, 10, Color(0.2, 0.35, 0.7))
	_pontos_em(Rect2(-40, 6, 80, 22), 0.0, 4, "patio")
	# infectados: no pátio, nas docas, no galpão, no mezanino
	for p in [Vector3(-10, 0, 20), Vector3(15, 0, 24), Vector3(30, 0, 8), Vector3(-36, 0, 22), Vector3(-5, D, -2), Vector3(10, D, -15),
			Vector3(20, D, -25), Vector3(-10, D, -20), Vector3(-22, ym, -24), Vector3(-25, D, -15), Vector3(0, D, 1)]:
		infectados.append(p)
