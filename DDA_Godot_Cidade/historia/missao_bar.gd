extends Node
# 1.14 · MISSÃO 2 "PÂNICO MIDIÁTICO" (Livro 1, Cap. 2) · DIA -5, logo depois da corrida.
#   NA CHEGADA (cena): "Quase te peguei dessa vez." / "Você está melhorando, mas ainda precisa de mais prática."
#   SIGA O GREG (jogo): ele vai na frente no JDM até o bar dos corredores (GPS); o Dominic vai no Kiri.
#   O BAR: fachada com letreiro de neon na rua; ao entrar, o interior (historia/cenario.gd): balcão, garrafas, sinuca,
#     o barman, clientes e a TV na parede com o noticiário. Sente com o Greg na MESA DO CANTO.
#   A CENA DO BAR: "Então, você e a Mavie?" ... a TV interrompe (Tóquio, Paris, Nova York) e a câmera se aproxima
#     devagar dela; "Provavelmente só mais um pânico midiático. A mídia vive de medo." Ninguém ri. Só o noticiário
#     ficando mais urgente. A tela escurece: "TRÊS DIAS DEPOIS".
# rodar(h) devolve true quando a missão termina (h = historia/historia.gd).
# Mexa AQUI para: onde fica o bar (BAR_ALVO), as falas e os planos das cenas.

const Atores := preload("res://historia/atores.gd")
const VeiculoCls := preload("res://mundo/veiculo.gd")
const PilotoCls := preload("res://historia/piloto_ia.gd")
const AreaCls := preload("res://historia/area_liberada.gd")
const LuzCls := preload("res://historia/iluminacao.gd")
const CenarioCls := preload("res://historia/cenario.gd")
const RotaGps := preload("res://hud/rota_gps.gd")
const Sons := preload("res://audio/sons.gd")

const DE_CORRIDA := Vector2(-1400.0, 2200.0)   # o mesmo percurso da Missão 1 (para achar a linha de chegada)
const ATE_CORRIDA := Vector2(-1700.0, -600.0)
const BAR_ALVO := Vector2(-2000.0, -480.0)     # o bar dos corredores, a umas quadras da chegada
const CORREDOR := 28.0

var h = null
var main = null
var caminho := PackedVector2Array()
var medidor: Node = null
var piloto: Node = null
var kiri: VehicleBody3D = null
var jdm: VehicleBody3D = null
var greg: Node3D = null
var dom: Node3D = null
var area: Node3D = null
var luz: Node3D = null
var bar: Node3D = null
var fachada: Node3D = null
var porta_rua := Vector3.ZERO
var giro_rua := 0.0
var gente: Array = []
var _colisao_greg: Node3D = null

func rodar(hist) -> bool:
	h = hist
	main = h.main
	if main.clima != null:
		main.clima.definir_hora(20.7)
		main.clima.forcar_tempo("nublado", true)
		main.clima.parado = true
	var corrida := RotaGps.rota(DE_CORRIDA, ATE_CORRIDA)
	var fim: Vector2 = corrida[corrida.size() - 1] if corrida.size() > 1 else ATE_CORRIDA
	caminho = RotaGps.rota(fim, BAR_ALVO)
	if caminho.size() < 2:
		push_error("bar: sem caminho")
		return false
	medidor = PilotoCls.new()
	medidor.definir(caminho)
	add_child(medidor)
	area = AreaCls.new()
	area.dados_cidade = main.cidade.dados_cidade
	area.mundo = main.mundo
	main.jogo.add_child(area)
	area.corredor(caminho, CORREDOR, "corrida")
	luz = LuzCls.new()
	luz.cidade = main.cidade
	luz.mundo = main.mundo
	main.jogo.add_child(luz)
	luz.acender(caminho, [_v3(fim), _v3(caminho[caminho.size() - 1])])
	_montar_fachada(caminho[caminho.size() - 1])
	bar = CenarioCls.new()
	bar.name = "Bar"
	main.jogo.add_child(bar)
	bar.montar_bar()
	_gente_do_bar()
	_montar_carros()
	await _na_chegada()
	await _seguir_greg()
	await _entrar_no_bar()
	await _cena_do_bar()
	_limpar()
	return true

func _v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, main.mundo.altura(p.x, p.y) + y, p.y)

func _ponto(s: float, lado := 0.0, y := 0.0) -> Vector3:
	var p: Vector2 = medidor.ponto_em(s)
	var d: Vector2 = medidor.direcao_em(s)
	var q := p + Vector2(d.y, -d.x) * lado
	return Vector3(q.x, main.mundo.altura(q.x, q.y) + y, q.y)

func _giro(s: float) -> float:
	var d: Vector2 = medidor.direcao_em(s)
	return atan2(d.x, d.y)

# a fachada do bar no prédio mais perto do fim do caminho, virada para a rua
func _montar_fachada(rua: Vector2) -> void:
	var f := CenarioCls.fachada_perto(main.cidade, rua, 90.0, h.preencher.lotes_perto(rua, 90.0))
	var mp: Vector2 = f[0]
	var mn: Vector2 = f[1]
	giro_rua = atan2(mn.x, mn.y)
	var p3 := _v3(mp)
	fachada = CenarioCls.fachada(main.jogo, p3 + Vector3(mn.x, 0, mn.y) * 0.02, giro_rua, "BAR · A MORTE DO MEDO")
	porta_rua = p3 + Vector3(mn.x, 0, mn.y) * 1.4

# o barman, uns clientes no balcão e na sinuca (o bar está vivo: é o Dia -5)
func _gente_do_bar() -> void:
	var p: Dictionary = bar.pontos
	var barman := Atores.criar(bar, "corredor", p["atras_balcao"], -PI * 0.5)
	barman.tocar("parado")
	gente.append(barman)
	for k in 2:
		var cli := Atores.criar(bar, "corredora" if k == 0 else "corredor", (p["balcao"] as Vector3) + Vector3(-0.2, 0.32, -1.6 + k * 2.4), PI * 0.5)
		cli.tocar("sentado")
		gente.append(cli)
	var jog := Atores.criar(bar, "corredor", (p["sinuca"] as Vector3) + Vector3(-1.8, 0, 0.2), PI * 0.5)
	jog.tocar("parado")
	gente.append(jog)
	var amiga := Atores.criar(bar, "corredora", (p["mesa_2"] as Vector3) + Vector3(0, 0, -0.85), 0.0)
	amiga.tocar("sentado")
	gente.append(amiga)

func _montar_carros() -> void:
	kiri = _carro("kiri86", "KiriDominic", 6.0, 2.4)
	jdm = _carro("jdm99", "JdmGreg", 6.0, -2.4)
	greg = Atores.criar(main.jogo, "greg", _ponto(9.0, -4.2), _giro(6.0) + PI * 0.5)
	h.teleportar(_ponto(9.0, 4.4, 0.1), _giro(6.0) - PI * 0.5)
	piloto = PilotoCls.new()
	piloto.carro = jdm
	piloto.definir(caminho)
	piloto.vel_max = 14.0
	add_child(piloto)
	_colisao_greg = main.mundo.criar_extra(jdm)

func _carro(tipo: String, nome: String, s: float, lado: float) -> VehicleBody3D:
	var v = VeiculoCls.new()
	v.tipo = tipo
	v.historia = true
	v.combustivel = VeiculoCls.TANQUE
	v.id = "historia_" + tipo
	v.name = nome
	main.jogo.add_child(v)
	v.freeze = true
	v.global_transform = Transform3D(Basis(Vector3.UP, _giro(s)), _ponto(s, lado, 0.15))
	return v

# ---------- NA CHEGADA ----------
func _na_chegada() -> void:
	h.esconder_hud(true)
	var pj: Vector3 = main.jogador.global_position
	var pg: Vector3 = greg.global_position
	greg.olhar_para = main.jogador
	greg.tocar("acenar")
	var meio := (pj + pg) * 0.5
	var lado := (pg - pj).normalized().cross(Vector3.UP)
	await h.cena.tocar([
		{"de": meio + lado * 9.0 + Vector3(0, 3.0, 0), "para": meio + lado * 6.0 + Vector3(0, 1.8, 0), "olha": meio + Vector3(0, 1.2, 0), "fov": 45,
			"escuro": true, "titulo": ["MISSÃO 2", "PÂNICO MIDIÁTICO"], "dur": 4.0},
		{"de": pj + (pj - pg).normalized() * 1.6 + lado * 0.7 + Vector3(0, 1.65, 0), "olha": pg + Vector3(0, 1.55, 0), "fov": 34,
			"fala": ["Greg", "Quase te peguei dessa vez."], "tremor": 0.12},
		{"de": pg + (pg - pj).normalized() * 1.6 - lado * 0.7 + Vector3(0, 1.65, 0), "olha": pj + Vector3(0, 1.6, 0), "fov": 34,
			"fala": ["Dominic", "Você está melhorando, mas ainda precisa de mais prática."], "tremor": 0.12},
		{"de": meio + lado * 3.2 + Vector3(0, 1.5, 0), "para": meio + lado * 2.6 + Vector3(0, 1.4, 0), "olha": meio + Vector3(0, 1.3, 0), "fov": 40,
			"fala": ["Greg", "O bar de sempre. A primeira rodada é por minha conta."],
			"acao": func(): greg.tocar("sim")},
	])
	h.esconder_hud(false)

# ---------- SIGA O GREG ----------
func _seguir_greg() -> void:
	# o Greg entra no carro dele e sai na frente; o Dominic entra no Kiri
	greg.queue_free()
	greg = Atores.criar(jdm, "greg", Vector3.ZERO)
	_sentar(greg, jdm)
	jdm.motorista = greg
	jdm.can_sleep = false
	jdm.freeze = false
	jdm.ligar_motor()
	kiri.freeze = false
	h.objetivo("Entre no Kiri", Vector2(kiri.global_position.x, kiri.global_position.z), "KIRI")
	await h.esperar_interacao("ENTRAR NO\nKIRI", kiri.global_position, 3.4)
	var j = main.jogador
	kiri.motorista = j
	j.entrar_veiculo(kiri)
	main.veiculos.dirigindo = kiri
	kiri.can_sleep = false
	kiri.ligar_motor()
	dom = Atores.criar(kiri, "dominic", Vector3.ZERO)
	_sentar(dom, kiri)
	piloto.ligado = true
	var fim: Vector2 = caminho[caminho.size() - 1]
	h.objetivo("Siga o Greg até o bar", fim, "BAR")
	# espera chegar: o Greg espera se o Dominic ficar para trás (elástico)
	while true:
		await get_tree().process_frame
		dom.visible = not j.primeira_pessoa
		var pj: Vector3 = j.global_position
		var mj: Array = medidor.medir(Vector2(pj.x, pj.z))
		piloto.progresso_jogador = float(mj[0])
		if piloto.progresso() >= medidor.total() - 8.0:
			piloto.ligado = false
			jdm.controlar(0.0, 0.0, true)
		if Vector2(pj.x - fim.x, pj.z - fim.y).length() < 22.0:
			break
	h.objetivo("Estacione e entre no bar", Vector2(porta_rua.x, porta_rua.z), "BAR")
	# espera o Dominic sair do carro
	while j.veiculo != null:
		await get_tree().process_frame
	main.veiculos.dirigindo = null
	dom.queue_free()
	dom = null
	# o Greg já desceu e está na porta
	greg.queue_free()
	greg = Atores.criar(main.jogo, "greg", porta_rua + Vector3.UP * 0.02 + Basis(Vector3.UP, giro_rua) * Vector3(-1.6, 0, 0.4), giro_rua + PI)
	greg.olhar_para = main.jogador
	greg.tocar("acenar")

func _sentar(ator: Node3D, carro) -> void:
	var olho: Vector3 = VeiculoCls.MODELOS[carro.tipo]["olho"]
	ator.position = Vector3(olho.x, olho.y - 1.18, olho.z + 0.06)
	ator.rotation = Vector3.ZERO
	ator.tocar("dirigindo", 0.0)

# ---------- ENTRAR NO BAR ----------
func _entrar_no_bar() -> void:
	await h.esperar_interacao("ENTRAR NO\nBAR", porta_rua, 2.6)
	h.objetivo("")
	# o Greg entra na frente e já está na mesa do canto
	greg.queue_free()
	var p: Dictionary = bar.pontos
	greg = Atores.criar(bar, "greg", p["cadeira_greg"], PI)
	greg.tocar("sentado")
	await h.entrar(bar, "dentro", PI)
	h.objetivo("Sente com o Greg na mesa do canto")
	await h.esperar_interacao("SENTAR", p["cadeira_dom"], 1.8)

# ---------- A CENA DO BAR ----------
func _cena_do_bar() -> void:
	h.esconder_hud(true)
	h.objetivo("")
	var p: Dictionary = bar.pontos
	main.jogador.visible = false
	dom = Atores.criar(bar, "dominic", p["cadeira_dom"], 0.0)
	dom.tocar("sentado")
	var pd: Vector3 = p["cadeira_dom"]
	var pg: Vector3 = p["cadeira_greg"]
	var tv: Vector3 = p["tv"]
	var cab_d := pd + Vector3(0, 1.25, 0)
	var cab_g := pg + Vector3(0, 1.25, 0)
	var tv_olha := tv + Vector3(0, 0, -0.02)
	await h.cena.tocar([
		# plano geral do bar (onde estamos): fumaça de cigarro, o balcão, a TV ao fundo
		{"de": (p["porta"] as Vector3) + Vector3(3.5, 2.6, 0.3), "para": (p["porta"] as Vector3) + Vector3(2.5, 2.2, 1.2), "olha": (p["mesa_canto"] as Vector3) + Vector3(0, 1.0, 0),
			"fov": 52, "dur": 4.0, "escuro": true, "titulo": ["", "O bar de sempre · as paredes sujas, os copos mal lavados"]},
		# plano e contraplano por cima do ombro (a linha entre os dois: a câmera fica sempre do mesmo lado)
		{"de": cab_d + Vector3(0.45, 0.15, -0.55), "olha": cab_g, "fov": 36, "fala": ["Dominic", "Então, você e a Mavie?"]},
		{"de": cab_g + Vector3(0.45, 0.15, 0.55), "olha": cab_d, "fov": 36, "fala": ["Greg", "Ainda não sei. Às vezes acho que ela sente o mesmo… outras vezes, nem tanto."]},
		{"de": cab_d + Vector3(0.45, 0.15, -0.55), "para": cab_d + Vector3(0.4, 0.12, -0.45), "olha": cab_g, "fov": 34,
			"fala": ["Dominic", "Bom, se você esperar o mundo acabar, vai perder sua chance."]},
		# a TV chama a atenção: corte no som do bar, a câmera se aproxima devagar da tela
		{"de": tv_olha + Vector3(0.6, -0.3, -3.6), "para": tv_olha + Vector3(0.15, -0.05, -1.3), "olha": tv_olha, "fov": 40, "fov_para": 32,
			"fala": ["TV", "Relatos de ataques violentos estão surgindo em várias cidades ao redor do mundo..."], "dur": 6.0},
		{"de": tv_olha + Vector3(0.1, -0.02, -1.25), "para": tv_olha + Vector3(0.03, 0.0, -0.95), "olha": tv_olha, "fov": 32,
			"fala": ["TV", "As autoridades investigam uma possível mutação viral associada a um comportamento agressivo extremo."], "dur": 6.5},
		{"de": cab_g + Vector3(0.45, 0.15, 0.55), "olha": cab_d, "fov": 34, "fala": ["Greg", "Você acha que isso é sério?"]},
		{"de": cab_d + Vector3(-0.6, 0.1, -0.7), "para": cab_d + Vector3(-0.5, 0.08, -0.6), "olha": cab_d + Vector3(0, -0.05, 0), "fov": 30,
			"fala": ["Dominic", "Provavelmente só mais um pânico midiático. A mídia vive de medo. Vamos aproveitar a noite."]},
		# nenhuma risada veio: só o silêncio, e o noticiário ficando mais urgente
		{"de": (p["mesa_canto"] as Vector3) + Vector3(2.4, 1.6, -2.2), "para": (p["mesa_canto"] as Vector3) + Vector3(2.0, 1.5, -1.6),
			"olha": (p["mesa_canto"] as Vector3) + Vector3(0, 1.0, 0), "fov": 40, "dur": 4.5, "frase": "Mas nenhuma risada veio. Só o silêncio."},
		{"de": tv_olha + Vector3(0, 0, -1.0), "para": tv_olha + Vector3(0, 0, -0.75), "olha": tv_olha, "fov": 30, "dur": 3.5,
			"fala": ["TV", "URGENTE: Nova York confirma os primeiros casos. A população deve evitar aglomerações."], "escurece": true},
		{"de": tv_olha + Vector3(0, 0, -0.75), "olha": tv_olha, "dur": 3.2, "titulo": ["TRÊS DIAS DEPOIS", ""], "barras": false},
	], true)
	main.jogador.visible = true

func _limpar() -> void:
	var j = main.jogador
	if j.veiculo != null:
		j.sair_veiculo(j.global_position)
	if main.veiculos != null and main.veiculos.dirigindo != null:
		main.veiculos.dirigindo = null
	if _colisao_greg != null:
		main.mundo.remover_extra(_colisao_greg)
	h.limpar_interacoes()
	h.dentro_de = null
	for n in [kiri, jdm, greg, dom, area, luz, bar, fachada]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	gente.clear()
