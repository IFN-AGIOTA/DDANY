extends Node
# AMBIENTE DA CIDADE (modo livre): de tempos em tempos, longe e baixinho,
#   · uma SIRENE (trecho de 5–9 s, entrando e saindo devagar)
#   · uma rajada de TIROS distantes (outros sobreviventes... ou não)
# Usa os sons gravados de audio/sons (audio/sons_baixados.gd). Fica mudo dentro de cutscene/história e com
# o jogador morto. Vai para o barramento "SFX" (volume dos efeitos nas Opções).
# Mexa AQUI para: intervalos e volumes.

const SonsBaixados := preload("res://audio/sons_baixados.gd")
const INTERVALO_SIRENE := Vector2(80.0, 200.0)
const INTERVALO_TIROS := Vector2(110.0, 260.0)
const VOL_SIRENE := -20.0
const VOL_TIROS := -23.0

var main = null
var _t_sirene := 40.0
var _t_tiros := 70.0
var _sirene: AudioStreamPlayer
var _tiros: AudioStreamPlayer
var _rajada := 0
var _t_rajada := 0.0

func ligar(m) -> void:
	main = m
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_sirene = AudioStreamPlayer.new()
	_sirene.bus = bus
	add_child(_sirene)
	_tiros = AudioStreamPlayer.new()
	_tiros.bus = bus
	add_child(_tiros)

func _process(dt: float) -> void:
	if main == null or main.jogador == null or bool(main.jogador.morto):
		return
	if main.get("historia") != null and bool(main.historia.ativa):
		return
	_t_sirene -= dt
	if _t_sirene <= 0.0:
		_t_sirene = randf_range(INTERVALO_SIRENE.x, INTERVALO_SIRENE.y)
		_tocar_sirene()
	_t_tiros -= dt
	if _t_tiros <= 0.0:
		_t_tiros = randf_range(INTERVALO_TIROS.x, INTERVALO_TIROS.y)
		_rajada = randi_range(1, 5)
		_t_rajada = 0.0
	if _rajada > 0:
		_t_rajada -= dt
		if _t_rajada <= 0.0:
			_rajada -= 1
			_t_rajada = randf_range(0.15, 0.9)
			var s := SonsBaixados.som(["armas/tiro_fuzil", "armas/tiro_pistola", "armas/tiro_fuzil2"][randi() % 3])
			if s != null:
				_tiros.stream = s
				_tiros.pitch_scale = randf_range(0.72, 0.85)        # mais grave = mais longe
				_tiros.volume_db = VOL_TIROS + randf_range(-3.0, 2.0)
				_tiros.play()

func _tocar_sirene() -> void:
	var s := SonsBaixados.som("ambiente/sirene")
	if s == null:
		return
	_sirene.stream = s
	_sirene.volume_db = -60.0
	_sirene.pitch_scale = randf_range(0.92, 1.04)
	var dur := randf_range(5.0, 9.0)
	_sirene.play(randf_range(0.0, maxf(0.0, s.get_length() - dur - 0.5)))
	var tw := create_tween()
	tw.tween_property(_sirene, "volume_db", VOL_SIRENE, 1.8)
	tw.tween_interval(maxf(0.5, dur - 3.6))
	tw.tween_property(_sirene, "volume_db", -60.0, 1.8)
	tw.tween_callback(_sirene.stop)
