extends Node3D
# FOGUEIRA (feita com isqueiro + 3 galhos no inventário). Fica acesa DURACAO segundos:
#   - luz alaranjada que tremula e chamas animadas
#   - esquenta quem está perto (jogador/sobrevivencia.gd: temperatura sobe e a roupa seca)
#   - perto dela, ÁGUA SUJA pode ser FERVIDA (vira água limpa) no inventário
# Depois vira brasa e some. Mexa AQUI para: duração, luz e tamanho.

const Malhas := preload("res://mundo/malhas.gd")
const Sons := preload("res://audio/sons.gd")
const DURACAO := 600.0

var acesa := true
var _t := 0.0
var _luz: OmniLight3D
var _som: AudioStreamPlayer3D                                # estalos do fogo (0.49), em laço
var _chamas: Array[MeshInstance3D] = []
static var _mat_fogo: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("pausa_por_chunk")    # fora dos chunks ativos fica pausada (mundo/chunks.gd)
	add_to_group("fogueiras")
	var c := Malhas.Construtor.new()
	for k in 7:                                              # pedras em volta
		var a := TAU * k / 7.0
		c.caixa(Vector3(cos(a) * 0.45, 0.06, sin(a) * 0.45), Vector3(0.18, 0.12, 0.15), Color(0.4, 0.39, 0.37), Basis(Vector3.UP, a))
	for k in 4:                                              # lenha cruzada
		c.caixa(Vector3(0, 0.08, 0), Vector3(0.7, 0.07, 0.07), Color(0.3, 0.2, 0.12), Basis(Vector3.UP, k * PI / 4.0))
	var mi := MeshInstance3D.new()
	mi.mesh = c.malha(Malhas.mat_cores())
	add_child(mi)
	if _mat_fogo == null:
		_mat_fogo = StandardMaterial3D.new()
		_mat_fogo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_fogo.albedo_color = Color(1.0, 0.55, 0.12, 0.85)
		_mat_fogo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_fogo.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 3:
		var ch := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.18 - k * 0.04
		cm.height = 0.5 - k * 0.1
		cm.radial_segments = 6
		cm.material = _mat_fogo
		ch.mesh = cm
		ch.position = Vector3(randf_range(-0.08, 0.08), 0.3, randf_range(-0.08, 0.08))
		ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ch)
		_chamas.append(ch)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.6, 0.25)
	_luz.light_energy = 2.0
	_luz.omni_range = 9.0
	_luz.position.y = 0.7
	add_child(_luz)
	_som = AudioStreamPlayer3D.new()
	_som.stream = Sons.stream("mundo/fogo", true)
	_som.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_som.volume_db = -4.0
	_som.unit_size = 2.5
	_som.max_distance = 28.0
	_som.position.y = 0.3
	add_child(_som)
	if _som.stream != null:
		_som.play(randf() * 4.0)

func _process(dt: float) -> void:
	_t += dt
	if not acesa:
		return
	var f := 0.85 + 0.15 * sin(_t * 13.0) + 0.1 * sin(_t * 7.3)
	_luz.light_energy = 2.0 * f
	for i in _chamas.size():
		_chamas[i].scale = Vector3(1.0, 0.8 + 0.35 * absf(sin(_t * (6.0 + i * 2.3) + i)), 1.0)
		_chamas[i].rotation.y = _t * (1.0 + i)
	if _t > DURACAO:
		acesa = false
		_luz.light_energy = 0.3
		_luz.light_color = Color(0.9, 0.3, 0.1)
		for ch in _chamas:
			ch.visible = false
		if _som != null:
			create_tween().tween_property(_som, "volume_db", -40.0, 6.0).finished.connect(_som.stop)
		get_tree().create_timer(120.0).timeout.connect(queue_free)
