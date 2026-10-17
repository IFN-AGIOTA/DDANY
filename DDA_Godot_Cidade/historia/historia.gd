extends CanvasLayer
# HISTÓRIA · ATO 1 — segue o livro "Dias de um Apocalipse" (Livro 1), adaptado para o jogo a pé.
# Menu principal › "História · Ato 1":
#   PRÓLOGO "Antes do Fim" (tela preta)
#   CAPÍTULO 1 · A Última Corrida: noite, cidade inteira (sem carros largados e sem infectados); no livro é de
#     carro, aqui é a pé: pontos de controle contra o relógio até a linha "A Morte do Medo".
#   CAPÍTULO 2 · Pânico Midiático: o bar depois da corrida; Greg fala da Mavie; a TV dá as notícias.
#   CAPÍTULO 3 · A Manhã Sem Sol: três dias depois, manhã do 4º dia, céu fechado. A cidade começa a trincar
#     (carros abandonados, poucos infectados ainda). Dominic pega a jaqueta, a mochila e o revólver do pai e vai
#     até o prédio do Greg; Mavie chega ferida; um vulto manca no fim da rua; os três correm para o carro do Greg
#     rumo ao aeroporto (o jato do Dominic). FIM DO ATO 1 (o livro segue com a fuga de jato: Nebraska, Califórnia).
# Depois do Ato 1 o jogo continua em mundo aberto, na cidade caída.
# NOMES DA LORE: "Vagos" é a GANGUE de Edy e V (Los Angeles); os mortos-vivos são os INFECTADOS.
# Estrutura: a história é uma lista de ETAPAS; cada etapa tem um "começo" (_ir) e o que precisa acontecer
# para passar à próxima (_process). Falas: dizer([[quem, texto], ...], depois). Títulos: titulo(grande, pequeno).
# Objetivo no mapa/bússola: mapa.definir_objetivo(pos, nome).
# Mexa AQUI para: falas (FALAS), ordem das etapas, pontos da corrida e tempos.

signal etapa_mudou(etapa: String)

const CutsceneCls := preload("res://historia/cutscene.gd")
const Cenas := preload("res://historia/cenas.gd")
const AberturaCls := preload("res://historia/abertura.gd")

const FALAS := {
	"prologo": ["No começo, ninguém sabia o que estava acontecendo.",
		"Não havia sirenes gritando pelas ruas. Não havia alertas piscando nas telas. Não havia ninguém dizendo “corram”.",
		"Apenas um estranho silêncio… aquele tipo de silêncio que vem antes da tempestade.",
		"Foi assim que o mundo começou a cair — quieto.",
		"É nesse mundo quebrado que três nomes ainda tentam lutar: Dominic, Greg e Mavie.",
		"Quando o mundo acaba, não há mais certo ou errado. Só o que precisa ser feito."],
	"pre": [["", "As luzes de Nova York ardiam como brasas no asfalto molhado. Era mais uma noite de corrida ilegal. A última."],
		["DOMINIC", "Vamos ver se você consegue me acompanhar hoje."], ["GREG", "Não vou te dar essa vitória fácil, amigo."],
		["", "Cruze a cidade pelos pontos de controle e passe a linha que os corredores chamam de “A Morte do Medo”."]],
	"pos": [["GREG", "Quase te peguei dessa vez!"], ["DOMINIC", "Você está melhorando, mas ainda precisa de mais prática."]],
	"bar": [["", "No bar de sempre, o cheiro de gasolina ainda impregnava as roupas. Na mesa do canto, a TV passava as notícias."],
		["DOMINIC", "Então, você e Mavie?"],
		["GREG", "Ainda não sei. Às vezes acho que ela sente o mesmo… outras vezes, nem tanto."],
		["DOMINIC", "Bom, se você esperar o mundo acabar, vai perder sua chance."],
		["TV", "“Relatos de ataques violentos estão surgindo em várias cidades ao redor do mundo. As autoridades investigam uma possível mutação viral associada a um comportamento agressivo extremo...”"],
		["", "Tóquio. Paris. Nova York. Pessoas correndo, sirenes, sangue."],
		["GREG", "Você acha que isso é sério?"],
		["DOMINIC", "Provavelmente só mais um pânico midiático. A mídia vive de medo. Vamos aproveitar a noite."],
		["", "Mas nenhuma risada veio. Só o silêncio. E o som do noticiário ficando cada vez mais urgente."]],
	"tres_dias": ["Três dias se passaram desde a corrida.",
		"O mundo parecia dividido entre os que zombavam da “nova gripe” e os que já trancavam portas, empilhando comida e carregando armas.",
		"Na manhã do quarto dia, o sol não nasceu. Apenas se escondeu atrás de nuvens densas.",
		"Uma mensagem da central de aviação: “Aeroporto sob risco de fechamento. Todos os voos privados devem ser finalizados até as 18h de amanhã.”",
		"O jato. Era a rota de fuga."],
	"acordar": [["", "Dominic vestiu a jaqueta de couro, pegou a mochila e o revólver que o pai tinha deixado para trás quando sumiu."],
		["", "Vá até o prédio do Greg (marcado no mapa). As ruas já não são as mesmas: cuidado."]],
	"greg": [["GREG", "Do jeito que dá pra ficar. A cidade vai fechar. Meu plano é ir pra Los Angeles. Meu primo tem uma propriedade nos arredores."],
		["DOMINIC", "O aeroporto ainda tá liberado. Meu jato tá lá. Podemos usá-lo."],
		["GREG", "Você tem um jato?"],
		["DOMINIC", "Dinheiro das corridas. Nunca soube onde guardar, então... comprei um avião. Ironia, né?"],
		["GREG", "Irônico seria se você soubesse pilotar."],
		["DOMINIC", "E eu sei. Mas só se você não me distrair no rádio."],
		["", "Batidas desesperadas na porta do prédio. Gritos."],
		["MAVIE", "Greg! Me ajuda, por favor! Eles... estavam em todos os lados..."],
		["", "Um corte no braço, o rosto sujo de fuligem. Greg a abraça com força."],
		["", "No fim da rua, um vulto surge mancando, com o corpo contorcido."],
		["DOMINIC", "Temos que ir agora."]],
	"carro": [["", "Chegue ao carro do Greg (marcado no mapa). Os infectados estão chegando."]],
	"fuga": [["RÁDIO", "“Evacuação imediata. Dirijam-se ao sul. Evacuação aérea restrita. Estabeleçam abrigo. Repetindo…”"],
		["DOMINIC", "Se isso for o fim do mundo… pelo menos estamos juntos."],
		["GREG", "Ainda não acabou. Não enquanto estivermos vivos."]],
}
const LARGADA := Vector2(-1350.0, 512.0)     # Algonquin (Manhattan de Liberty City), como no HTML
const N_PONTOS := 6
const PASSO_CORRIDA := 230.0                 # metros entre os pontos de controle
const RAIO_PONTO := 9.0
const CASA_DOMINIC := Vector2(-1100.0, 150.0)  # onde o capítulo 3 começa
const DIST_GREG := 450.0                     # o prédio do Greg fica a ~450 m

var main = null
var etapa := ""                  # "", "prologo", "corrida", "pos", "bar", "cap3", "greg", "carro", "fim", "livre"
var ativa := false
var _fila: Array = []
var _depois: Callable = Callable()
var _digitando := 0.0
var _texto := ""
var _cheio := false
var _ui: Control
var _caixa: Panel
var _quem: Label
var _fala: Label
var _tela_preta: ColorRect
var _titulo: Label
var _sub: Label
var _obj: Label
var _toast: Label
var _toast_t := 0.0
var _anel: MeshInstance3D
var _pontos: Array[Vector2] = []
var _ponto := 0
var _tempo := 0.0
var _limite := 0.0
var _correndo := false
var _t_check := 0.0
var _escondeu := false
var _casa := Vector2.ZERO        # onde Dominic começa o capítulo 3
var _predio_greg := Vector2.ZERO # porta do prédio do Greg (na rua)
var _carro_greg := Vector2.ZERO
var _max_orig := -1
var cs: Node3D = null            # historia/cutscene.gd (cenas de cinema; roteiro em historia/cenas.gd)
var _inicio := Vector2.ZERO      # largada da corrida
var _dir_corrida := Vector2.RIGHT              # quantos infectados o jogo livre usa (volta no fim do ato)

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_ui()

# ---------- começo ----------
func iniciar(m) -> void:
	main = m
	ativa = true
	_cidade_inteira(true)
	if main.clima != null:
		main.clima.definir_hora(20.6)
		main.clima.forcar_tempo("limpo", true)
		main.clima.parado = true
	# na PRIMEIRA vez: a abertura (o teaser refeito no jogo, historia/abertura.gd)
	if not Config.valor("abertura_vista"):
		var ab: Node = AberturaCls.new()
		ab.name = "Abertura"
		main.jogo.add_child(ab)
		await ab.tocar(main)
		ab.queue_free()
		Config.definir("abertura_vista", true)
	_ir("prologo")

func _ir(e: String) -> void:
	etapa = e
	etapa_mudou.emit(e)
	match e:
		"prologo":
			_cheio = true
			dizer(FALAS["prologo"], func():
				_cheio = false
				titulo("CAPÍTULO 1", "A Última Corrida", func():
					_preparar_corrida()
					await _cena(func(): await Cenas.largada(cs, self, _inicio, _dir_corrida))
					_largar()))
		"pos":
			var fim: Vector2 = _pontos[_pontos.size() - 1]
			var antes: Vector2 = _pontos[_pontos.size() - 2] if _pontos.size() > 1 else _inicio
			await _cena(func(): await Cenas.chegada(cs, self, fim, (fim - antes).normalized()))
			_ir("bar")
		"bar":
			titulo("CAPÍTULO 2", "Pânico Midiático", func():
				await _cena(func(): await Cenas.bar(cs, self, FALAS["bar"]))
				_ir("cap3"))
		"cap3":
			titulo("CAPÍTULO 3", "A Manhã Sem Sol", func():
				_cheio = true
				dizer(FALAS["tres_dias"], func():
					_cheio = false
					_comecar_cap3()
					dizer(FALAS["acordar"], func(): _ir("greg"))))
		"greg":
			_locais()
			if main.mapa != null:
				main.mapa.definir_objetivo(_predio_greg, "PRÉDIO DO GREG")
			_obj_texto("Vá até o prédio do Greg")
		"carro":
			_locais()
			await _cena(func(): await Cenas.greg_mavie(cs, self, FALAS["greg"]))
			# a partir daqui Greg e Mavie andam com você (npc/companheiro.gd)
			if main.get("companheiros") != null:
				main.companheiros.chegar(["greg", "mavie"])
			if main.mapa != null:
				main.mapa.definir_objetivo(_carro_greg, "CARRO DO GREG")
			_obj_texto("Chegue ao carro do Greg")
			_infectados_na_rua()
			dizer(FALAS["carro"])
		"fim":
			_obj_texto("")
			if main.mapa != null:
				main.mapa.limpar_objetivo()
			await _cena(func(): await Cenas.fuga(cs, self, FALAS["fuga"]))
			titulo("FIM DO ATO 1", "Continua: Rota de Fuga — o jato, Nebraska, Califórnia…", func():
				_mostrar_toast("MUNDO ABERTO", "a cidade caiu · sobreviva")
				if main.vagos != null:
					main.vagos.max_ativos = _max_orig if _max_orig > 0 else main.vagos.MAX_ATIVOS_PADRAO
				if main.clima != null:
					main.clima.parado = false
				_ir("livre"))
		"livre":
			ativa = false
			_obj_texto("")

# roda uma cutscene (historia/cenas.gd) e espera ela acabar
func _cena(f: Callable) -> void:
	if cs == null:
		cs = CutsceneCls.new()
		cs.name = "Cutscene"
		cs.main = main
		main.jogo.add_child(cs)
	await cs.tocar(f)

# cidade antes do surto: sem carros largados, sem entulho, sem infectados
func _cidade_inteira(inteira: bool) -> void:
	var cid = main.cidade
	for d in cid.detalhes_abandono:
		if is_instance_valid(d):
			d.visible = not inteira
	if cid.abandono != null:
		main.mundo.configurar_obstaculos(PackedFloat32Array() if inteira else cid.abandono.obstaculos)
	var v = main.get("vagos")
	if v != null:
		v.ativo = not inteira

# capítulo 3: manhã nublada do 4º dia; a cidade começa a trincar (poucos infectados ainda)
func _comecar_cap3() -> void:
	_cidade_inteira(false)
	if main.vagos != null:
		if _max_orig < 0:
			_max_orig = main.vagos.max_ativos
		main.vagos.max_ativos = 4
	if main.clima != null:
		main.clima.definir_hora(9.0)
		main.clima.forcar_tempo("nublado", true)
		main.clima.parado = false
	# Dominic: jaqueta de couro, mochila e o revólver herdado do pai (no jogo: pistola)
	var j = main.jogador
	var inv = j.inventario
	inv.esvaziar()
	var I = load("res://inventario/item.gd")
	var jaq = I.novo("jaqueta")
	var calca = I.novo("jeans")
	var moch = I.novo("mochila_escolar")
	var arma = I.novo("pistola")
	for par in [["camisa", jaq], ["calca", calca], ["mochila", moch], ["coldre", arma]]:
		inv.slots[par[0]] = par[1]
		par[1].slot = par[0]
	inv._por(jaq.conteudo, I.novo("mun_9mm", 12))
	inv._por(jaq.conteudo, I.novo("bandagem", 2))
	inv._por(calca.conteudo, I.novo("lanterna"))
	inv._por(moch.conteudo, I.novo("agua"))
	inv._por(moch.conteudo, I.novo("barra", 2))
	inv.atalhos[0] = arma
	inv.mudou.emit()
	_locais()
	main.mundo.forcar(_casa)
	j.teleportar(Vector3(_casa.x, main.mundo.altura(_casa.x, _casa.y) + 0.1, _casa.y), 0.0)

# lugares do capítulo 3 (sempre os mesmos: dependem só da cidade)
func _locais() -> void:
	if _casa != Vector2.ZERO:
		return
	var cid = main.cidade
	_casa = _rua_perto(CASA_DOMINIC)
	# prédio do Greg: residencial com entrada, a ~DIST_GREG m da casa do Dominic
	var melhor := -1
	var md := 1e9
	for i in cid.predio_info.size():
		var inf: Dictionary = cid.predio_info[i]
		if inf.get("uso", "") != "residencial" or not inf.get("entra", false) or inf.get("ruina", false):
			continue
		var d: float = absf(Vector2(inf["x"], inf["z"]).distance_to(_casa) - DIST_GREG)
		if d < md:
			md = d
			melhor = i
	var pg := _casa + Vector2(DIST_GREG, 0.0)
	if melhor >= 0:
		pg = Vector2(cid.predio_info[melhor]["x"], cid.predio_info[melhor]["z"])
	_predio_greg = _rua_perto(pg)
	# carro do Greg: o carro mais perto do prédio (fora do ônibus)
	_carro_greg = _predio_greg + Vector2(25.0, 0.0)
	if cid.abandono != null:
		var mc := 1e9
		for c in cid.abandono.carros:
			if c[2] == "onibus":
				continue
			var q: Vector3 = c[0]
			var d := Vector2(q.x, q.z).distance_to(_predio_greg)
			if d > 20.0 and d < mc:
				mc = d
				_carro_greg = Vector2(q.x, q.z)

# "Um vulto surgiu no final da rua, mancando": alguns infectados aparecem e vêm atrás do barulho
func _infectados_na_rua() -> void:
	if main.vagos == null:
		return
	main.vagos.max_ativos = 7
	var pj: Vector3 = main.jogador.global_position
	main.vagos.barulho(pj, 70.0, true)

# ---------- corrida (Capítulo 1) ----------
func _preparar_corrida() -> void:
	var cid = main.cidade
	_pontos.clear()
	var p := _rua_perto(LARGADA)
	var dir := Vector2(1.0, -0.35).normalized()      # rumo ao leste/norte, como no HTML (Algonquin -> Broker)
	var j = main.jogador
	main.mundo.forcar(p)
	j.teleportar(Vector3(p.x, main.mundo.altura(p.x, p.y) + 0.1, p.y), atan2(-dir.x, -dir.y))
	_inicio = p
	_dir_corrida = dir
	var atual := p
	for k in N_PONTOS:
		var alvo := _rua_perto(atual + dir * PASSO_CORRIDA)
		if alvo.distance_to(atual) < 60.0:
			alvo = _rua_perto(atual + dir.rotated(0.6) * PASSO_CORRIDA)
		_pontos.append(alvo)
		dir = (alvo - atual).normalized().rotated(randf_range(-0.35, 0.35))
		atual = alvo
	var total := 0.0
	var ant := p
	for q in _pontos:
		total += ant.distance_to(q) * 1.25         # as ruas não são em linha reta
		ant = q
	_limite = total / 6.0 + 25.0
	_ponto = 0
	_tempo = 0.0
	if _anel == null:
		_anel = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = RAIO_PONTO
		cm.bottom_radius = RAIO_PONTO
		cm.height = 160.0
		cm.cap_top = false
		cm.cap_bottom = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.7, 0.0, 0.42)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_fog = true
		mat.no_depth_test = false
		cm.material = mat
		_anel.mesh = cm
		_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.jogo.add_child(_anel)
	_anel.visible = false

# rua mais perto de p (máscara de ruas da cidade, células de 20 m)
func _rua_perto(p: Vector2) -> Vector2:
	var cid = main.cidade
	var c0 := int((p.x + cid.WORLD.x) / cid.CELL)
	var l0 := int((p.y + cid.WORLD.y) / cid.CELL)
	for r in 40:
		for dl in range(-r, r + 1):
			for dc in range(-r, r + 1):
				if maxi(absi(dl), absi(dc)) != r:
					continue
				var c := c0 + dc
				var l := l0 + dl
				if c >= 0 and c < cid.W and l >= 0 and l < cid.H and cid.road[l * cid.W + c] == 1:
					return Vector2((c + 0.5) * cid.CELL - cid.WORLD.x, (l + 0.5) * cid.CELL - cid.WORLD.y)
	return p

func _largar() -> void:
	etapa = "corrida"
	_correndo = true
	_tempo = 0.0
	_ponto = 0
	_atualizar_ponto()
	_mostrar_toast("VAI!", "%d pontos · %d s" % [N_PONTOS, int(_limite)])

func _atualizar_ponto() -> void:
	var q := _pontos[_ponto]
	_anel.global_position = Vector3(q.x, 80.0, q.y)
	_anel.visible = true
	if main.mapa != null:
		main.mapa.definir_objetivo(q, "PONTO %d" % (_ponto + 1) if _ponto < N_PONTOS - 1 else "A MORTE DO MEDO")

func _process(dt: float) -> void:
	# durante uma cutscene ela cuida da tela; a história só espera
	if cs != null and cs.rodando:
		_ui.visible = false
		return
	_ui.visible = true
	if main != null and main.controles != null and is_instance_valid(main.controles):
		var cena := _caixa.visible or _titulo.visible
		if cena != _escondeu:
			_escondeu = cena
			main.controles.visible = not cena
	_toast_t -= dt
	_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	_processar_fala(dt)
	if main == null or main.jogador == null or not is_instance_valid(main.jogador) or get_tree().paused:
		return
	var j = main.jogador
	var p := Vector2(j.global_position.x, j.global_position.z)
	if _correndo:
		if main.clima != null:
			main.clima.definir_hora(20.6)          # a corrida é à noite
		_tempo += dt
		var resta := maxf(0.0, _limite - _tempo)
		_obj_texto("%d/%d · %d s" % [_ponto + 1, N_PONTOS, ceili(resta)])
		if p.distance_to(_pontos[_ponto]) < RAIO_PONTO + 2.0:
			_ponto += 1
			_limite += 6.0
			if _ponto >= N_PONTOS:
				_correndo = false
				_anel.visible = false
				_obj_texto("")
				if main.mapa != null:
					main.mapa.limpar_objetivo()
				_ir("pos")
				return
			_mostrar_toast("PONTO %d/%d" % [_ponto, N_PONTOS], "+6 s")
			_atualizar_ponto()
		elif resta <= 0.0:
			_correndo = false
			_anel.visible = false
			_mostrar_toast("TEMPO ESGOTADO", "tente de novo")
			await get_tree().create_timer(1.9).timeout
			_preparar_corrida()
			_largar()
		return
	_t_check -= dt
	if _t_check > 0.0:
		return
	_t_check = 0.5
	if etapa == "greg" and p.distance_to(_predio_greg) < 12.0:
		_ir("carro")
	elif etapa == "carro" and p.distance_to(_carro_greg) < 5.0 and not _caixa.visible:
		_ir("fim")

# ---------- falas e títulos ----------
func dizer(linhas: Array, depois := Callable()) -> void:
	_fila.clear()
	for l in linhas:
		_fila.append(l if l is Array else ["", l])
	_depois = depois
	get_tree().paused = true
	_proxima()

func _proxima() -> void:
	if _digitando > 0.0 and _digitando < _texto.length():
		_digitando = _texto.length()                # toque durante a digitação: mostra tudo
		return
	if _fila.is_empty():
		_caixa.visible = false
		_tela_preta.visible = false
		get_tree().paused = false
		var d := _depois
		_depois = Callable()
		if d.is_valid():
			d.call()
		return
	var l: Array = _fila.pop_front()
	_quem.text = l[0]
	_texto = l[1]
	_digitando = 0.001
	_fala.text = ""
	_caixa.visible = true
	_tela_preta.visible = _cheio and l[0] == ""
	_ajustar_caixa()

func _processar_fala(dt: float) -> void:
	if _digitando <= 0.0 or not _caixa.visible:
		return
	_digitando = minf(_digitando + dt * 45.0, float(_texto.length()))
	_fala.text = _texto.substr(0, int(_digitando))

func titulo(grande: String, pequeno: String, depois := Callable()) -> void:
	get_tree().paused = true
	_tela_preta.visible = true
	_titulo.text = grande
	_sub.text = pequeno
	_titulo.visible = true
	_sub.visible = true
	await get_tree().create_timer(2.8, true, false, true).timeout
	_titulo.visible = false
	_sub.visible = false
	_tela_preta.visible = false
	get_tree().paused = false
	if depois.is_valid():
		depois.call()

func _mostrar_toast(t: String, sub: String) -> void:
	_toast.text = t + "\n" + sub
	_toast_t = 2.2

func _obj_texto(t: String) -> void:
	_obj.text = t
	_obj.visible = t != ""

func _input(e: InputEvent) -> void:
	if not _caixa.visible:
		return
	var tocar := false
	if e is InputEventScreenTouch and e.pressed:
		tocar = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tocar = true
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_SPACE, KEY_E, KEY_KP_ENTER]:
		tocar = true
	if tocar:
		get_viewport().set_input_as_handled()
		_proxima()

# ---------- salvar ----------
func salvar() -> Dictionary:
	return {"etapa": etapa}

func carregar(d: Dictionary) -> void:
	var e: String = d.get("etapa", "")
	if e == "" or e == "livre":
		etapa = e
		return
	ativa = true
	if e in ["prologo", "corrida", "pos", "bar"]:
		iniciar(main)                                # os capítulos 1 e 2 recomeçam do início
	elif e == "cap3":
		_ir("cap3")
	else:
		# capítulo 3 em andamento: cidade já trincando, objetivo de volta
		_cidade_inteira(false)
		if main.vagos != null:
			main.vagos.max_ativos = 4 if e == "greg" else 7
		_ir(e)

# ---------- interface ----------
func _montar_ui() -> void:
	var v := get_viewport().get_visible_rect().size.y / 100.0
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_tela_preta = ColorRect.new()
	_tela_preta.color = Color(0, 0, 0, 1.0)
	_tela_preta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela_preta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela_preta.visible = false
	_ui.add_child(_tela_preta)
	_titulo = _rotulo(9.0 * v, Color(1.0, 0.72, 0.2))
	_titulo.set_anchors_preset(Control.PRESET_CENTER)
	_titulo.position.y -= 6.0 * v
	_sub = _rotulo(3.4 * v, Color(1, 1, 1, 0.8))
	_sub.set_anchors_preset(Control.PRESET_CENTER)
	_sub.position.y += 4.0 * v
	for l in [_titulo, _sub]:
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.grow_vertical = Control.GROW_DIRECTION_BOTH
		l.visible = false
		_ui.add_child(l)
	_caixa = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.03, 0.82)
	sb.border_color = Color(1.0, 0.6, 0.2, 0.5)
	sb.border_width_top = 2
	sb.set_corner_radius_all(4)
	_caixa.add_theme_stylebox_override("panel", sb)
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.visible = false
	_ui.add_child(_caixa)
	_quem = _rotulo(3.0 * v, Color(1.0, 0.72, 0.2))
	_quem.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_caixa.add_child(_quem)
	_fala = _rotulo(3.3 * v, Color(1, 1, 1, 0.95))
	_fala.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caixa.add_child(_fala)
	var dica := _rotulo(2.0 * v, Color(1, 1, 1, 0.45))
	dica.text = "toque para continuar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dica.name = "Dica"
	_caixa.add_child(dica)
	_obj = _rotulo(3.0 * v, Color(1.0, 0.8, 0.3))
	_obj.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_obj.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_obj.position.y = 15.0 * v
	_obj.visible = false
	_ui.add_child(_obj)
	_toast = _rotulo(5.0 * v, Color.WHITE)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast.position.y -= 18.0 * v
	_toast.modulate.a = 0.0
	_ui.add_child(_toast)

func _ajustar_caixa() -> void:
	var vs := get_viewport().get_visible_rect().size
	var v := vs.y / 100.0
	if _tela_preta.visible:
		_caixa.position = Vector2(vs.x * 0.15, vs.y * 0.38)
		_caixa.size = Vector2(vs.x * 0.7, 24.0 * v)
	else:
		_caixa.position = Vector2(vs.x * 0.12, vs.y - 27.0 * v)
		_caixa.size = Vector2(vs.x * 0.76, 22.0 * v)
	_quem.position = Vector2(2.5 * v, 1.5 * v)
	_quem.size = Vector2(_caixa.size.x - 5.0 * v, 4.0 * v)
	_fala.position = Vector2(2.5 * v, (5.5 if _quem.text != "" else 2.5) * v)
	_fala.size = Vector2(_caixa.size.x - 5.0 * v, 13.0 * v)
	var dica: Label = _caixa.get_node("Dica")
	dica.position = Vector2(2.5 * v, _caixa.size.y - 4.0 * v)
	dica.size = Vector2(_caixa.size.x - 5.0 * v, 3.0 * v)

func _rotulo(tam: float, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", int(tam))
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
