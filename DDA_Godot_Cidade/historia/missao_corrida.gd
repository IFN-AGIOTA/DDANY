extends Node
# 1.13 · PRÓLOGO + MISSÃO 1 "A ÚLTIMA CORRIDA" (Livro 1, Prólogo e Cap. 1) · DIA -5, noite, neblina.
#   PRÓLOGO (cena): Nova York viva à noite, as frases do prólogo em silêncio, Dominic, Greg e Mavie, o título.
#   LARGADA (cena): o garoto com o bastão de luz, plano e contraplano dos dois, a garrafa caindo em CÂMERA LENTA.
#   CORRIDA (jogo): Dominic no Kiri '86 contra o Greg no JDM Sport '99, 2,8 km de Chinatown até o centro. O GPS
#     mostra o percurso; os PONTOS DE CONTROLE (colunas de luz) seguem em ordem; as ruas que saem do percurso estão
#     fechadas por cavaletes e cones (historia/area_liberada.gd). O Greg é o piloto do jogo (historia/piloto_ia.gd),
#     com "elástico": a corrida fica apertada até o fim.
#   MEIO DA CORRIDA: uma viatura de giroflex ligado num cruzamento (a cidade está mais tensa do que parece) e, numa curva,
#     o Greg derrapando ao lado em câmera lenta.
#   CHEGADA: a linha "A Morte do Medo" em câmera lenta. Perdeu: tenta de novo da largada (no livro o Dominic vence).
# rodar(h) devolve true quando a missão termina (h = historia/historia.gd).
# Mexa AQUI para: o percurso (DE/ATE), os pontos de controle, os textos e os planos das cenas.

const Atores := preload("res://historia/atores.gd")
const VeiculoCls := preload("res://mundo/veiculo.gd")
const PilotoCls := preload("res://historia/piloto_ia.gd")
const AreaCls := preload("res://historia/area_liberada.gd")
const RotaGps := preload("res://hud/rota_gps.gd")
const Sons := preload("res://audio/sons.gd")

const DE := Vector2(-1400.0, 2200.0)     # largada (sul de Manhattan: "Chinatown")
const ATE := Vector2(-1700.0, -600.0)    # chegada perto do centro: a reta "A Morte do Medo"
const PONTOS := 8                        # pontos de controle até a chegada
const RAIO_PONTO := 22.0
const CORREDOR := 32.0                   # m de cada lado do percurso
const LONGE := 55.0                      # fora do percurso: aviso; mais 4 s: volta para a pista
const FRASES := [
	"No começo, ninguém sabia o que estava acontecendo.",
	"Apenas um estranho silêncio… aquele tipo de silêncio que vem antes da tempestade.",
	"As notícias chegaram devagar. Um ataque aqui, outro ali.",
	"Não era um vírus comum. Era algo novo. Algo sem nome.",
]

var h = null
var main = null
var caminho := PackedVector2Array()
var piloto: Node = null             # Greg
var medidor: Node = null            # mede o jogador no mesmo caminho
var kiri: VehicleBody3D = null
var jdm: VehicleBody3D = null
var greg: Node3D = null
var dom_ator: Node3D = null
var area: Node3D = null
var garoto: Node3D = null
var publico: Array = []
var _colisao_greg: Node3D = null
var _marca: MeshInstance3D = null
var _viatura: Node3D = null

func rodar(hist) -> bool:
	h = hist
	main = h.main
	_preparar_noite()
	caminho = RotaGps.rota(DE, ATE)
	if caminho.size() < 2:
		push_error("corrida: sem caminho")
		return false
	medidor = PilotoCls.new()
	medidor.definir(caminho)
	add_child(medidor)
	area = AreaCls.new()
	area.name = "AreaLiberada"
	area.dados_cidade = main.cidade.dados_cidade
	area.mundo = main.mundo
	main.jogo.add_child(area)
	area.corredor(caminho, CORREDOR, "corrida")
	_montar_carros()
	_montar_largada()
	if not bool(h.progresso.get("prologo", false)):
		await _prologo()
		h.progresso["prologo"] = true
		h.salvar()
	while true:
		print("HIST: largada")
		await _largada()
		print("HIST: corrida")
		var venceu: bool = await _correr()
		if venceu:
			break
		await h.cartela("O GREG VENCEU", "Tente de novo · a corrida recomeça da largada", 2.6)
		_posicionar_carros()
	await _chegada()
	_limpar()
	return true

# ---------- noite de corrida ----------
func _preparar_noite() -> void:
	if main.clima != null:
		main.clima.definir_hora(20.4)                 # fim do crepúsculo: a cidade acesa, o céu ainda azul-escuro
		main.clima.forcar_tempo("nublado", true)
		main.clima.parado = true
	var amb = main.cidade.get("ambiente")
	if amb != null:
		amb.fog_density = maxf(float(amb.fog_density), 0.0028)        # neblina leve rastejando pelas ruas

# ---------- carros e gente ----------
func _ponto(s: float, lado := 0.0, y := 0.4) -> Vector3:
	var p: Vector2 = medidor.ponto_em(s)
	var d: Vector2 = medidor.direcao_em(s)
	var esq := Vector2(d.y, -d.x)                     # esquerda de quem olha para d (frente +Z, esquerda +X)
	var q := p + esq * lado
	return Vector3(q.x, main.mundo.altura(q.x, q.y) + y, q.y)

func _giro(s: float) -> float:
	var d: Vector2 = medidor.direcao_em(s)
	return atan2(d.x, d.y)

func _montar_carros() -> void:
	kiri = VeiculoCls.new()
	kiri.tipo = "kiri86"
	kiri.historia = true
	kiri.combustivel = VeiculoCls.TANQUE
	kiri.id = "historia_kiri"
	kiri.name = "KiriDominic"
	main.jogo.add_child(kiri)
	jdm = VeiculoCls.new()
	jdm.tipo = "jdm99"
	jdm.historia = true
	jdm.combustivel = VeiculoCls.TANQUE
	jdm.id = "historia_jdm"
	jdm.name = "JdmGreg"
	main.jogo.add_child(jdm)
	# o Greg dirigindo (e o Dominic, visto de fora; some em 1ª pessoa)
	greg = Atores.criar(jdm, "greg", Vector3.ZERO)
	_sentar(greg, jdm)
	dom_ator = Atores.criar(kiri, "dominic", Vector3.ZERO)
	_sentar(dom_ator, kiri)
	piloto = PilotoCls.new()
	piloto.name = "PilotoGreg"
	piloto.carro = jdm
	piloto.definir(caminho)
	piloto.vel_max = 40.0
	add_child(piloto)
	jdm.motorista = greg
	_colisao_greg = main.mundo.criar_extra(jdm)      # chão de física em volta do carro do Greg
	_posicionar_carros()

func _sentar(ator: Node3D, carro) -> void:
	var olho: Vector3 = VeiculoCls.MODELOS[carro.tipo]["olho"]
	ator.position = Vector3(olho.x, olho.y - 1.18, olho.z + 0.06)
	ator.rotation = Vector3.ZERO
	ator.tocar("dirigindo", 0.0)

func _posicionar_carros() -> void:
	for c in [kiri, jdm]:
		c.linear_velocity = Vector3.ZERO
		c.angular_velocity = Vector3.ZERO
	var g := _giro(14.0)
	# o jogador (e o chão de física, que acompanha ele) vai para a largada ANTES dos carros: sem chão, eles caem
	if main.jogador.veiculo != null:
		main.jogador.sair_veiculo(_ponto(14.0, 2.4, 1.0))
	h.teleportar(_ponto(14.0, 2.4, 0.2), g)
	# os carros ficam presos (sem física) durante as cenas e soltam no "vai" (_soltar)
	for c in [kiri, jdm]:
		c.freeze = true
	kiri.global_transform = Transform3D(Basis(Vector3.UP, g), _ponto(14.0, 2.4, 0.15))
	jdm.global_transform = Transform3D(Basis(Vector3.UP, g), _ponto(14.0, -2.4, 0.15))
	if _colisao_greg != null:
		_colisao_greg.forcar(Vector2(jdm.global_position.x, jdm.global_position.z))
	_entrar(kiri)
	piloto.ligado = false
	medidor.definir(caminho)
	piloto.definir(caminho)
	jdm.can_sleep = false
	jdm.ligar_motor()

func _soltar() -> void:
	main.mundo.forcar(Vector2(kiri.global_position.x, kiri.global_position.z))
	if _colisao_greg != null:
		_colisao_greg.forcar(Vector2(jdm.global_position.x, jdm.global_position.z))
	for c in [kiri, jdm]:
		c.linear_velocity = Vector3.ZERO
		c.angular_velocity = Vector3.ZERO
		c.freeze = false
		c.sleeping = false

func _entrar(v) -> void:
	var j = main.jogador
	if j.veiculo != v:
		if j.veiculo != null:
			j.sair_veiculo(j.global_position)
		v.motorista = j
		j.entrar_veiculo(v)
	j.prender_no_carro = true
	main.controles.ocultos["PEGAR"] = true          # na corrida não dá para sair do carro: o botão some
	main.veiculos.dirigindo = v
	v.can_sleep = false
	v.ligar_motor()

func _montar_largada() -> void:
	garoto = Atores.criar(main.jogo, "garoto", _ponto(30.0, 0.0, 0.0), _giro(30.0) + PI)
	garoto.tocar("parado")
	var lados := [[-7.5, "corredor"], [-8.0, "corredora"], [7.8, "corredor"], [8.2, "corredora"], [-7.0, "corredor"], [7.2, "corredora"]]
	for i in lados.size():
		var s := 18.0 + i * 5.0
		var a := Atores.criar(main.jogo, lados[i][1], _ponto(s, lados[i][0], 0.0), _giro(s) - PI * 0.5 * signf(lados[i][0]))
		a.olhar_para = garoto
		a.tocar("parado" if i % 2 == 0 else "acenar")
		publico.append(a)

# ---------- PRÓLOGO ----------
func _prologo() -> void:
	h.esconder_hud(true)
	var dt: Vector2 = preload("res://mundo/cidade.gd").DOWNTOWN
	var c := Vector3(dt.x, 0, dt.y)
	var mavie := Atores.criar(main.jogo, "mavie", Vector3(dt.x + 40.0, main.mundo.altura(dt.x + 40.0, dt.y + 60.0), dt.y + 60.0), PI * 0.8)
	mavie.tocar("parado")
	var pk: Vector3 = kiri.global_position
	var pj: Vector3 = jdm.global_position
	var fk: Vector3 = kiri.global_basis.z
	var planos: Array = [
		{"de": c + Vector3(-420, 360, 520), "para": c + Vector3(-300, 260, 380), "olha": c + Vector3(0, 60, 0), "fov": 50, "dur": 6.5,
			"escuro": true, "frase": FRASES[0]},
		{"de": c + Vector3(260, 140, 300), "para": c + Vector3(150, 90, 180), "olha": c + Vector3(-40, 40, -60), "fov": 45, "dur": 6.0,
			"frase": FRASES[1]},
		{"de": c + Vector3(-120, 30, 220), "para": c + Vector3(-60, 18, 120), "olha": c + Vector3(0, 25, -80), "fov": 55, "dur": 5.5,
			"frase": FRASES[2], "tremor": 0.3},
		{"de": c + Vector3(70, 95, -150), "para": c + Vector3(35, 70, -95), "olha": c + Vector3(0, 45, 0), "fov": 42, "dur": 5.5, "frase": FRASES[3]},
		# os três
		{"de": pk + fk * 4.5 + Vector3(-1.4, 1.2, 0), "para": pk + fk * 3.2 + Vector3(-1.0, 1.15, 0), "olha": dom_ator, "fov": 30, "dur": 4.5,
			"frase": "Dominic, um homem com cicatrizes que nem o tempo apagou."},
		{"de": pj + fk * 4.5 + Vector3(1.4, 1.2, 0), "para": pj + fk * 3.2 + Vector3(1.0, 1.15, 0), "olha": greg, "fov": 30, "dur": 4.5,
			"frase": "Greg, cujo coração é pesado demais para carregar sozinho."},
		{"de": mavie.global_position + Vector3(2.5, 1.6, -2.5), "para": mavie.global_position + Vector3(1.6, 1.6, -1.6), "olha": mavie.global_position + Vector3(0, 1.5, 0),
			"fov": 32, "dur": 5.0, "frase": "E Mavie, que carrega a esperança nos olhos — mesmo quando o corpo ameaça ceder."},
		{"de": c + Vector3(0, 420, 300), "para": c + Vector3(0, 480, 340), "olha": c, "fov": 48, "dur": 4.0,
			"frase": "Quando o mundo acaba, não há mais certo ou errado. Só o que precisa ser feito."},
		{"de": c + Vector3(0, 480, 340), "olha": c, "fov": 48, "dur": 4.2, "titulo": ["DIAS DE UM APOCALIPSE", "NOVA YORK"], "escurece": true,
			"acao": func(): Sons.tocar("partida/entrada", -6.0)},
	]
	await h.cena.tocar(planos)
	mavie.queue_free()
	h.esconder_hud(false)

# ---------- LARGADA ----------
func _largada() -> void:
	print("HIST: _largada começa")
	h.esconder_hud(true)
	var pk: Vector3 = kiri.global_position
	var pj: Vector3 = jdm.global_position
	var fk: Vector3 = kiri.global_basis.z
	var esq: Vector3 = kiri.global_basis.x
	var pg: Vector3 = garoto.global_position
	var meio := (pk + pj) * 0.5
	garoto.tocar("parado")
	var planos: Array = [
		{"de": meio + fk * 24.0 + Vector3(0, 9, 0), "para": meio + fk * 13.0 + Vector3(0, 2.8, 0), "olha": meio + Vector3(0, 0.8, 0), "fov": 50, "dur": 5.0,
			"escuro": true, "titulo": ["DIA -5 · 20:24", "CHINATOWN · A ÚLTIMA CORRIDA"]},
		# plano e contraplano (a câmera fica do mesmo lado da linha entre os dois: a regra dos 180°)
		{"de": pk + esq * 1.7 + fk * 1.2 + Vector3(0, 1.25, 0), "para": pk + esq * 1.5 + fk * 0.9 + Vector3(0, 1.2, 0), "olha": dom_ator.global_position + Vector3(0, 1.05, 0),
			"fov": 32, "fala": ["Dominic", "Vamos ver se você consegue me acompanhar hoje."], "tremor": 0.15},
		{"de": pj - esq * 1.7 + fk * 1.2 + Vector3(0, 1.25, 0), "para": pj - esq * 1.5 + fk * 0.9 + Vector3(0, 1.2, 0), "olha": greg.global_position + Vector3(0, 1.05, 0),
			"fov": 32, "fala": ["Greg", "Não vou te dar essa vitória fácil, amigo."], "tremor": 0.15},
		{"de": pg + fk * -6.0 + Vector3(0, 0.6, 0), "para": pg + fk * -4.5 + Vector3(0, 0.9, 0), "olha": pg + Vector3(0, 1.6, 0), "fov": 40, "dur": 2.4,
			"acao": func(): garoto.tocar("acenar")},
		# a garrafa cai: câmera lenta e silêncio, depois o mundo explode em movimento
		{"de": pg + fk * 3.0 + esq * 3.0 + Vector3(0, 1.0, 0), "para": pg + fk * 3.2 + esq * 2.2 + Vector3(0, 1.2, 0), "olha": meio + Vector3(0, 0.7, 0),
			"fov": 38, "dur": 2.2, "lento": 0.25, "acao": func(): garoto.tocar("sim")},
	]
	await h.cena.tocar(planos)
	garoto.tocar("acenar")
	h.esconder_hud(false)
	_soltar()
	Sons.tocar("partida/entrada", -10.0)

# ---------- CORRIDA ----------
func _correr() -> bool:
	piloto.ligado = true
	var total: float = medidor.total()
	var cps: Array = []
	for k in PONTOS:
		cps.append(total * float(k + 1) / float(PONTOS))
	var prox := 0
	h.objetivo("Chegue primeiro na \"A Morte do Medo\"", caminho[caminho.size() - 1], "A MORTE DO MEDO", main.mapa.COR_ROTA_CORRIDA)
	_marcar(cps[0])
	var t_fora := 0.0
	var viu_viatura := false
	var viu_derrapada := false
	var s_jog := 0.0
	var dica := 0
	while true:
		await get_tree().process_frame
		var dtt := get_process_delta_time()
		dom_ator.visible = not main.jogador.primeira_pessoa
		var pj: Vector3 = main.jogador.global_position
		var m: Array = medidor.medir(Vector2(pj.x, pj.z), dica)
		dica = int(m[1])
		s_jog = maxf(s_jog, float(m[0]) if float(m[2]) < LONGE else s_jog)
		piloto.progresso_jogador = s_jog
		var s_greg: float = piloto.progresso()
		# pontos de controle (em ordem)
		if prox < cps.size() and s_jog >= float(cps[prox]) - RAIO_PONTO:
			prox += 1
			Sons.ui("clique")
			if prox < cps.size():
				_marcar(cps[prox])
		var pos := "1º" if s_jog >= s_greg else "2º"
		h.info("%s LUGAR · PONTO %d/%d · faltam %s" % [pos, mini(prox + 1, PONTOS), PONTOS, _km(total - s_jog)])
		# fora do percurso
		if float(m[2]) > LONGE:
			t_fora += dtt
			h.objetivo("VOLTE PARA A CORRIDA")
			if t_fora > 4.0:
				await _voltar_pista(s_jog)
				t_fora = 0.0
		elif t_fora > 0.0:
			t_fora = 0.0
			h.objetivo("Chegue primeiro na \"A Morte do Medo\"", caminho[caminho.size() - 1], "A MORTE DO MEDO", main.mapa.COR_ROTA_CORRIDA)
		# capotou: desvira
		if kiri.virado():
			await get_tree().create_timer(1.5, false).timeout
			if kiri.virado():
				kiri.desvirar()
		# meio da corrida: a viatura no cruzamento (a cidade está mais tensa)
		if not viu_viatura and s_jog > total * 0.38:
			viu_viatura = true
			_viatura_no_caminho(s_jog + 140.0)
		# o Greg derrapa ao lado numa curva: um instante de câmera lenta
		if not viu_derrapada and s_jog > total * 0.55 and absf(s_jog - s_greg) < 18.0 and kiri.linear_velocity.length() > 12.0:
			viu_derrapada = true
			Engine.time_scale = 0.45
			await get_tree().create_timer(0.55, false, false, true).timeout
			Engine.time_scale = 1.0
		# chegada
		if s_greg >= total - 4.0 and s_jog < total - 4.0:
			_limpar_corrida()
			return false
		if s_jog >= total - 30.0 and s_jog >= s_greg:
			await _foto_chegada()
			_limpar_corrida()
			return true
	return false

func _km(m: float) -> String:
	return "%d m" % int(maxf(m, 0.0)) if m < 1000.0 else ("%.1f km" % (m / 1000.0)).replace(".", ",")

func _limpar_corrida() -> void:
	piloto.ligado = false
	h.objetivo("")
	h.info("")
	if _marca != null:
		_marca.queue_free()
		_marca = null

# coluna de luz no próximo ponto de controle
func _marcar(s: float) -> void:
	if _marca == null:
		_marca = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 7.0
		cm.bottom_radius = 7.0
		cm.height = 30.0
		cm.cap_top = false
		cm.cap_bottom = false
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.35, 0.75, 1.0, 0.16)
		cm.material = mat
		_marca.mesh = cm
		_marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.jogo.add_child(_marca)
	_marca.global_position = _ponto(s, 0.0, 15.0)

func _voltar_pista(s: float) -> void:
	await h.escuro(0.4)
	kiri.linear_velocity = Vector3.ZERO
	kiri.angular_velocity = Vector3.ZERO
	kiri.global_transform = Transform3D(Basis(Vector3.UP, _giro(s)), _ponto(s, 0.0, 0.6))
	await h.clarear(0.5)

func _viatura_no_caminho(s: float) -> void:
	if _viatura != null:
		return
	var cor := Color(0.12, 0.13, 0.16)
	_viatura = Node3D.new()
	main.jogo.add_child(_viatura)
	var t := Transform3D(Basis(Vector3.UP, _giro(s) + 0.9), _ponto(s, 9.0, 0.0))
	var mi := MeshInstance3D.new()
	mi.mesh = preload("res://mundo/abandono.gd").modelo("sedan")
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = cor
	mi.material_override = mat
	mi.transform = t * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO)
	_viatura.add_child(mi)
	for k in 2:
		var o := OmniLight3D.new()
		o.light_color = Color(1, 0.1, 0.1) if k == 0 else Color(0.15, 0.3, 1.0)
		o.omni_range = 14.0
		o.light_energy = 3.0
		o.transform = t * Transform3D(Basis(), Vector3((k - 0.5) * 0.6, 1.9, 0))
		_viatura.add_child(o)
	var tw := _viatura.create_tween().set_loops()
	tw.tween_callback(func():
		if _viatura.get_child_count() > 2:
			_viatura.get_child(1).visible = not _viatura.get_child(1).visible
			_viatura.get_child(2).visible = not _viatura.get_child(1).visible)
	tw.tween_interval(0.16)
	h.info("UMA VIATURA DE GIROFLEX LIGADO... ACELERA!")

# a linha "A Morte do Medo" em câmera lenta
func _foto_chegada() -> void:
	var fim := _ponto(medidor.total() - 6.0, 0.0, 0.0)
	var esq: Vector3 = Basis(Vector3.UP, _giro(medidor.total() - 6.0)) * Vector3.RIGHT
	h.esconder_hud(true)
	await h.cena.tocar([
		{"de": fim + esq * 11.0 + Vector3(0, 1.2, 0), "para": fim + esq * 10.0 + Vector3(0, 1.0, 0), "olha": kiri, "fov": 42, "dur": 2.6, "lento": 0.3,
			"titulo": ["A MORTE DO MEDO", ""]},
	])
	h.esconder_hud(false)

# ---------- depois da linha ----------
func _chegada() -> void:
	kiri.controlar(0.0, 0.0, true)
	await h.esperar(0.6)
	h.esconder_hud(true)
	var pk: Vector3 = kiri.global_position
	var fk: Vector3 = kiri.global_basis.z
	await h.cena.tocar([
		{"de": pk + fk * 9.0 + Vector3(3, 2.0, 0), "para": pk + fk * 7.0 + Vector3(2, 1.6, 0), "olha": pk + Vector3(0, 0.9, 0), "fov": 40, "dur": 3.2,
			"fala": ["Dominic", "Ainda não foi dessa vez, Greg."]},
		{"de": pk + Vector3(0, 30, 6), "para": pk + Vector3(0, 60, 14), "olha": pk, "fov": 50, "dur": 3.5, "escurece": true,
			"titulo": ["MISSÃO 1 CONCLUÍDA", "Dia -5 · a noite em que o mundo ainda achava que era só mais uma noite"]},
	])
	h.esconder_hud(false)

func _limpar() -> void:
	var j = main.jogador
	j.prender_no_carro = false
	main.controles.ocultos.erase("PEGAR")
	if main.veiculos != null and main.veiculos.dirigindo == kiri:
		main.veiculos.dirigindo = null
	if j.veiculo != null:
		j.sair_veiculo(j.global_position)
	if _colisao_greg != null:
		main.mundo.remover_extra(_colisao_greg)
	for n in [kiri, jdm, garoto, area, _viatura, _marca]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	for a in publico:
		if is_instance_valid(a):
			a.queue_free()
	publico.clear()
