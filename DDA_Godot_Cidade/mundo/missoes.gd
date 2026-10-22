extends Node
# MISSÕES DO RÁDIO (modo livre): quem carrega um RÁDIO ouve, de tempos em tempos, o aviso de um
# SUPRIMENTO MILITAR lançado na cidade (a 0,7–1,6 km). O lugar vira o OBJETIVO no mapa e na bússola.
# Lá tem uma caixa militar com coisas boas (tabela "militar" de mundo/loot_mundo.gd), um sinalizador vermelho
# piscando e, quando você chega perto, uma HORDA de infectados que foi atraída pelo barulho do lançamento.
# A missão some se você não for em 20 min (alguém pegou antes).
# Mexa AQUI para: de quanto em quanto tempo vem um aviso, distância, tamanho da horda e quantos itens.

const CaixaMundoCls := preload("res://inventario/caixa_mundo.gd")

const PRIMEIRA := 120.0                    # segundos até o primeiro aviso (se tiver rádio)
const INTERVALO := Vector2(420.0, 720.0)   # entre um suprimento e o próximo
const DURACAO := 1200.0                    # depois disso a missão expira
const DIST := Vector2(700.0, 1600.0)
const HORDA := Vector2i(4, 7)
const ITENS := Vector2i(4, 6)
const DIRECOES := ["NORTE", "NORDESTE", "LESTE", "SUDESTE", "SUL", "SUDOESTE", "OESTE", "NOROESTE"]

var main = null
var encontrados := 0                       # quantos suprimentos o jogador já achou (aparece na tela de morte)
var _t := PRIMEIRA
var _ativa := false
var _pos := Vector3.ZERO
var _t_missao := 0.0
var _horda_feita := false
var _caixa: Node3D = null
var _luz: OmniLight3D = null
var _rng := RandomNumberGenerator.new()

func ligar(m) -> void:
	main = m
	_rng.randomize()

func _process(dt: float) -> void:
	if main == null or main.jogador == null or bool(main.jogador.morto):
		return
	var j: Node3D = main.jogador
	if _ativa:
		_t_missao += dt
		if _luz != null:
			_luz.light_energy = 2.5 if fmod(_t_missao, 1.2) < 0.6 else 0.4    # sinalizador piscando
		var d := Vector2(j.global_position.x - _pos.x, j.global_position.z - _pos.z).length()
		if not _horda_feita and d < 140.0:
			_horda_feita = true
			_soltar_horda()
		if d < 4.0:
			_concluir()
		elif _t_missao > DURACAO:
			_aviso("RÁDIO: o suprimento já foi levado por alguém...")
			_encerrar(true)
		return
	_t -= dt
	if _t <= 0.0:
		_t = _rng.randf_range(INTERVALO.x, INTERVALO.y)
		if main.jogador.inventario.radio_ligado():      # 0.65: rádio LIGADO e com pilha
			_nova()

func _nova() -> void:
	var cid = main.cidade
	var pj: Vector3 = main.jogador.global_position
	for tentativa in 300:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(DIST.x, DIST.y)
		var p := Vector2(pj.x + cos(a) * r, pj.z + sin(a) * r)
		var c := int((p.x + cid.WORLD.x) / cid.CELL)
		var l := int((p.y + cid.WORLD.y) / cid.CELL)
		if c < 0 or c >= cid.W or l < 0 or l >= cid.H or cid.road[l * cid.W + c] != 1:
			continue
		if main.mundo.dentro_de_predio(p.x, p.y, 2.0, true) or main.mundo.dentro_de_obstaculo(p.x, p.y, 1.5):
			continue
		_pos = Vector3(p.x, main.mundo.altura(p.x, p.y), p.y)
		_ativa = true
		_t_missao = 0.0
		_horda_feita = false
		_criar_caixa()
		if main.mapa != null:
			main.mapa.definir_objetivo(p, "SUPRIMENTO MILITAR")
		var ang := fposmod(atan2(p.x - pj.x, -(p.y - pj.z)), TAU)       # 0 = norte (-Z)
		var dir: String = DIRECOES[int(round(ang / (TAU / 8.0))) % 8]
		_aviso("RÁDIO: suprimento militar lançado a %.1f km, %s" % [r / 1000.0, dir])
		return

func _criar_caixa() -> void:
	var caixa = CaixaMundoCls.new()
	caixa.name = "SuprimentoMilitar"
	caixa.nome = "SUPRIMENTO MILITAR"
	caixa.tamanho = Vector2i(8, 6)
	caixa.medidas = Vector3(1.3, 0.8, 0.8)
	caixa.cor = Color(0.22, 0.28, 0.18)
	main.jogo.add_child(caixa)
	caixa.global_position = _pos
	caixa.rotation.y = _rng.randf() * TAU
	var loot = main.loot_mundo
	var n := _rng.randi_range(ITENS.x, ITENS.y)
	for k in n:
		var it = loot._sortear("militar", _rng, caixa.tamanho) if loot != null else null
		if it != null:
			caixa.guardar(it)
	# sinalizador: haste com luz vermelha piscando (dá para ver de longe à noite)
	var haste := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.04
	hm.bottom_radius = 0.04
	hm.height = 2.2
	haste.mesh = hm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.05)
	mat.emission_energy_multiplier = 3.0
	haste.material_override = mat
	caixa.add_child(haste)
	haste.position = Vector3(0.75, 1.1, 0)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.2, 0.1)
	_luz.omni_range = 18.0
	caixa.add_child(_luz)
	_luz.position = Vector3(0.75, 2.3, 0)
	_caixa = caixa

func _soltar_horda() -> void:
	var vg = main.get("vagos")
	if vg == null or not bool(vg.get("ativo")):
		return
	var n := _rng.randi_range(HORDA.x, HORDA.y)
	for k in n:
		for t in 6:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(8.0, 22.0)
			var q := Vector3(_pos.x + cos(a) * r, 0.0, _pos.z + sin(a) * r)
			if vg._livre(q.x, q.z):
				q.y = main.mundo.altura(q.x, q.z)
				vg._criar(q, _pos)
				break

func _concluir() -> void:
	encontrados += 1
	preload("res://audio/sons.gd").tocar("partida/objetivo", -3.0)
	_aviso("SUPRIMENTO ENCONTRADO!")
	_encerrar(false)

func _encerrar(tirar_caixa: bool) -> void:
	_ativa = false
	if main.mapa != null:
		main.mapa.limpar_objetivo()
	if _luz != null and is_instance_valid(_luz):
		_luz.queue_free()
	_luz = null
	if tirar_caixa and _caixa != null and is_instance_valid(_caixa):
		_caixa.queue_free()
	_caixa = null

func _aviso(t: String) -> void:
	if main.hud != null and main.hud.has_method("mostrar_aviso"):
		main.hud.mostrar_aviso(t, 5.0)

func salvar() -> Dictionary:
	return {"encontrados": encontrados}

func carregar(d: Dictionary) -> void:
	encontrados = int(d.get("encontrados", 0))
