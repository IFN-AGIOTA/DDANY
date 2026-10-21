extends Node
# AMBIENTE DA CIDADE (modo livre): de tempos em tempos, longe e baixinho,
#   · uma SIRENE (trecho de 5–9 s, entrando e saindo devagar)
#   · uma rajada de TIROS distantes (outros sobreviventes... ou não): gravações "de longe" (0.49)
# e o tempo todo (0.49), em laço, devagar entre um e outro:
#   · PÁSSAROS de dia (somem com chuva), GRILOS à noite, VENTO forte na chuva/tempestade
#   · dentro de prédio tudo fica mais baixo (mundo/clima.gd sabe se tem teto em cima)
# Usa os sons gravados de audio/sons (audio/sons_baixados.gd). Fica mudo dentro de cutscene/história e com
# o jogador morto. Vai para o barramento "SFX" (volume dos efeitos nas Opções).
# Mexa AQUI para: intervalos e volumes.

const SonsBaixados := preload("res://audio/sons_baixados.gd")
const Sons := preload("res://audio/sons.gd")
const VOL_PASSAROS := -17.0
const VOL_GRILOS := -19.0
const VOL_VENTO := -14.0
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
var _arma_rajada := "ak"
var _lacos := {}                       # nome -> AudioStreamPlayer (pássaros, grilos, vento)

func ligar(m) -> void:
	main = m
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_sirene = AudioStreamPlayer.new()
	_sirene.bus = bus
	add_child(_sirene)
	_tiros = AudioStreamPlayer.new()
	_tiros.bus = bus
	add_child(_tiros)
	for nome in ["mundo/passaros", "mundo/grilos", "mundo/vento"]:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.stream = Sons.stream(nome, true)
		p.volume_db = -80.0
		add_child(p)
		_lacos[nome] = p

func _process(dt: float) -> void:
	_ambiente(dt)
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
		_arma_rajada = ["ak", "m4", "pistola", "espingarda", "rifle_caca"][randi() % 5]
	if _rajada > 0:
		_t_rajada -= dt
		if _t_rajada <= 0.0:
			_rajada -= 1
			_t_rajada = randf_range(0.15, 0.9)
			var s := Sons.sortear("armas/longe_" + _arma_rajada)
			if s != null:
				_tiros.stream = s
				_tiros.pitch_scale = randf_range(0.85, 0.97)        # mais grave = mais longe
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

# laços do ambiente: cada um vai devagar até o volume que a hora/tempo pedem (-80 = parado)
func _ambiente(dt: float) -> void:
	var cl = main.get("clima") if main != null else null
	var ativo: bool = main != null and main.jogador != null and not bool(main.jogador.morto) and cl != null
	var alvo := {"mundo/passaros": -80.0, "mundo/grilos": -80.0, "mundo/vento": -80.0}
	if ativo:
		var h: float = float(cl.hora)
		var chuva: float = float(cl.chuva)
		var coberto: bool = bool(cl.get("_coberto"))
		var dentro := -12.0 if coberto else 0.0
		var dia := smoothstep(5.0, 6.5, h) * (1.0 - smoothstep(18.5, 19.8, h))
		var noite := 1.0 - smoothstep(4.5, 5.5, h) + smoothstep(19.5, 20.5, h)
		if dia * (1.0 - chuva) > 0.05:
			alvo["mundo/passaros"] = VOL_PASSAROS + linear_to_db(maxf(0.001, dia * (1.0 - chuva))) + dentro
		if noite * (1.0 - chuva * 0.8) > 0.05:
			alvo["mundo/grilos"] = VOL_GRILOS + linear_to_db(maxf(0.001, minf(1.0, noite) * (1.0 - chuva * 0.8))) + dentro
		if chuva > 0.25 or String(cl.estado) == "tempestade":
			alvo["mundo/vento"] = VOL_VENTO + linear_to_db(maxf(0.001, maxf(chuva, 0.6 if String(cl.estado) == "tempestade" else 0.0))) + dentro
	for nome in _lacos:
		var p: AudioStreamPlayer = _lacos[nome]
		if p.stream == null:
			continue
		var a: float = alvo[nome]
		p.volume_db = move_toward(p.volume_db, a, dt * (6.0 if a > p.volume_db else 10.0))
		if p.volume_db > -60.0 and not p.playing:
			p.play(randf() * 5.0)
		elif p.volume_db <= -60.0 and p.playing:
			p.stop()
