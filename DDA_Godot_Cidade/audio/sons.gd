extends Node
# SONS (central, 0.49): toca qualquer som de audio/sons/ pelo NOME do grupo; sorteia uma das variações
# (nome_0.ogg, nome_1.ogg... ou nome.ogg) e mexe um pouco no tom para não repetir igual.
#   Sons.ui("clique")                          menu e telas (barramento "UI": sem eco, volume dos EFEITOS)
#   Sons.tocar("inventario/comer", -3.0)       perto do jogador, sem posição (barramento "SFX", com eco da cidade)
#   Sons.em("impactos/bala_metal", pos, -6.0)  num ponto do mundo (3D: some com a distância e vem do lado certo)
#   Sons.stream("mundo/fogo", true)            o arquivo (em laço) para quem tem o próprio player (fogo, coração)
# Os arquivos são feitos por ferramentas/preparar_sons.py a partir dos downloads (licenças: audio/sons/LICENCA.txt).
# NÃO é autoload: o nó se cria sozinho na primeira vez que alguém toca um som (assim vem num pacote de atualização
# sem mexer no project.godot). Fica na raiz e continua tocando na pausa (menu de pausa também faz clique).
# Mexa AQUI para: quantos sons ao mesmo tempo, volume geral do menu, quanto o tom varia.

const PASTA := "res://audio/sons/"
const N_UI := 6
const N_2D := 12
const N_3D := 16
const VOL_UI := -4.0
const VARIA_TOM := 0.06
const REPETE_MIN := 0.035                 # o mesmo som não toca 2x em menos que isso (chumbos da espingarda)

static var _no: Node
static var _cache := {}                   # nome -> Array[AudioStream]
static var _ultimo := {}                  # nome -> tempo da última vez

var _ui: Array[AudioStreamPlayer] = []
var _p2: Array[AudioStreamPlayer] = []
var _p3: Array[AudioStreamPlayer3D] = []
var _i_ui := 0
var _i2 := 0
var _i3 := 0

# ---------- quem usa chama estas ----------
static func ui(nome: String, vol_db := 0.0) -> void:
	var s := sortear("ui/" + nome)
	if s != null and _pode(nome):
		_garantir().call_deferred("_tocar_ui", s, vol_db)

static func tocar(nome: String, vol_db := 0.0, tom := 1.0) -> void:
	var s := sortear(nome)
	if s != null and _pode(nome):
		_garantir().call_deferred("_tocar_2d", s, vol_db, tom)

static func em(nome: String, pos: Vector3, vol_db := 0.0, alcance := 60.0, tom := 1.0) -> void:
	var s := sortear(nome)
	if s != null and _pode(nome):
		_garantir().call_deferred("_tocar_3d", s, pos, vol_db, alcance, tom)

static func existe(nome: String) -> bool:
	return not _lista(nome).is_empty()

static func sortear(nome: String) -> AudioStream:
	var l := _lista(nome)
	return l[randi() % l.size()] if not l.is_empty() else null

static func stream(nome: String, laco := false) -> AudioStream:
	var s := sortear(nome)
	if s is AudioStreamOggVorbis and laco:
		(s as AudioStreamOggVorbis).loop = true
	return s

# ---------- arquivos ----------
static func _lista(nome: String) -> Array:
	if _cache.has(nome):
		return _cache[nome]
	var l: Array = []
	var um := PASTA + nome + ".ogg"
	if ResourceLoader.exists(um):
		l.append(load(um))
	var i := 0
	while i < 32:
		var c := PASTA + "%s_%d.ogg" % [nome, i]
		if not ResourceLoader.exists(c):
			break
		l.append(load(c))
		i += 1
	_cache[nome] = l
	return l

static func _pode(nome: String) -> bool:
	var t := Time.get_ticks_msec() / 1000.0
	if t - float(_ultimo.get(nome, -10.0)) < REPETE_MIN:
		return false
	_ultimo[nome] = t
	return true

static func _garantir() -> Node:
	if _no != null and is_instance_valid(_no):
		return _no
	var arvore := Engine.get_main_loop() as SceneTree
	_no = (load("res://audio/sons.gd") as GDScript).new()
	_no.name = "Sons"
	arvore.root.add_child.call_deferred(_no)
	return _no

# ---------- o nó ----------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus_ui := _bus_ui()
	var sfx := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in N_UI:
		var p := AudioStreamPlayer.new()
		p.bus = bus_ui
		add_child(p)
		_ui.append(p)
	for i in N_2D:
		var p := AudioStreamPlayer.new()
		p.bus = sfx
		add_child(p)
		_p2.append(p)
	for i in N_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = sfx
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz = 6000.0       # de longe fica abafado
		p.attenuation_filter_db = -18.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		_p3.append(p)

# barramento do menu: sem efeitos (o SFX tem eco de cidade), segue o volume dos EFEITOS (menu/aplicar_opcoes.gd)
static func _bus_ui() -> String:
	var i := AudioServer.get_bus_index("UI")
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "UI")
		AudioServer.set_bus_send(i, "Master")
		var sfx := AudioServer.get_bus_index("SFX")
		if sfx != -1:
			AudioServer.set_bus_volume_db(i, AudioServer.get_bus_volume_db(sfx))
	return "UI"

func _livre(lista: Array, i: int) -> int:
	for k in lista.size():
		var j := (i + 1 + k) % lista.size()
		if not lista[j].playing:
			return j
	return (i + 1) % lista.size()           # todos ocupados: corta o mais antigo da roda

func _tocar_ui(s: AudioStream, vol: float) -> void:
	_i_ui = _livre(_ui, _i_ui)
	var p := _ui[_i_ui]
	p.stream = s
	p.volume_db = VOL_UI + vol
	p.pitch_scale = randf_range(1.0 - VARIA_TOM * 0.5, 1.0 + VARIA_TOM * 0.5)
	p.play()

func _tocar_2d(s: AudioStream, vol: float, tom: float) -> void:
	_i2 = _livre(_p2, _i2)
	var p := _p2[_i2]
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = tom * randf_range(1.0 - VARIA_TOM, 1.0 + VARIA_TOM)
	p.play()

func _tocar_3d(s: AudioStream, pos: Vector3, vol: float, alcance: float, tom: float) -> void:
	_i3 = _livre(_p3, _i3)
	var p := _p3[_i3]
	p.stream = s
	p.global_position = pos
	p.volume_db = vol
	p.unit_size = maxf(1.0, alcance * 0.08)
	p.max_distance = alcance
	p.pitch_scale = tom * randf_range(1.0 - VARIA_TOM, 1.0 + VARIA_TOM)
	p.play()
