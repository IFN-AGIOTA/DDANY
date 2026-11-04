extends Node
# 1.13 · "SOM DE FALA" DOS PERSONAGENS (no lugar de voz, estilo os robôs de Stray): cada fala vira um murmúrio de
# bipes sintetizados na hora (AudioStreamGenerator, sem arquivo de som), uma sílaba para cada pedaço do texto, no
# mesmo ritmo em que a legenda aparece. Pergunta sobe no fim, grito é mais alto e rápido, reticências espaçam.
# Cada personagem tem um timbre (TIMBRES): para saber quem fala de olhos fechados. Rádio/TV: o mesmo som, filtrado.
# falar(texto, quem) começa; a legenda (historia/cutscene.gd) lê "progresso" (0..1) para ir mostrando as letras.
# Mexa AQUI para: o timbre de cada um (altura, variação, velocidade, brilho) e o volume.

const TAXA := 22050.0
# quem -> [altura base (Hz), variação (semitons), sílabas por segundo, brilho 0..1, tremor 0..1]
const TIMBRES := {
	"dominic": [118.0, 3.0, 7.0, 0.30, 0.0],      # grave, calmo
	"greg": [150.0, 5.0, 8.6, 0.45, 0.0],         # médio, quente, com balanço
	"mavie": [235.0, 5.0, 8.0, 0.35, 0.25],       # aguda, suave, às vezes trêmula
	"garoto": [270.0, 6.0, 9.5, 0.55, 0.0],
	"policial": [130.0, 2.0, 9.0, 0.65, 0.0],     # seco, firme
	"seguranca": [125.0, 2.5, 7.5, 0.5, 0.0],
	"tv": [165.0, 3.5, 9.0, 0.6, 0.0],
	"radio": [140.0, 2.5, 8.5, 0.7, 0.0],
	"": [170.0, 4.0, 8.5, 0.45, 0.0],
}

var volume_db := 0.0
var _p: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _silabas: Array = []         # [f0, f1, duração (s), amplitude] · f0 = 0: pausa
var _i := 0
var _t := 0.0                    # tempo dentro da sílaba
var _fase := 0.0
var _timbre: Array = TIMBRES[""]
var _filtro := false             # rádio/TV
var _lp := 0.0
var _hp := 0.0
var _total := 0.0
var _feito := 0.0
var falando := false
var progresso := 1.0             # 0..1 da fala atual

func _ready() -> void:
	_p = AudioStreamPlayer.new()
	var g := AudioStreamGenerator.new()
	g.mix_rate = TAXA
	g.buffer_length = 0.15
	_p.stream = g
	_p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_p)

# texto curto -> sílabas; devolve a duração (s)
func falar(texto: String, quem := "") -> float:
	quem = quem.to_lower()
	_timbre = TIMBRES.get(quem, TIMBRES[""])
	_filtro = quem in ["tv", "radio"]
	_silabas.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(texto + quem)
	var base: float = _timbre[0]
	var var_st: float = _timbre[1]
	var ritmo: float = _timbre[2]
	var grito := texto.ends_with("!") or texto == texto.to_upper() and texto.length() > 3
	var pergunta := texto.strip_edges().ends_with("?")
	var palavras := texto.split(" ", false)
	var n_pal := palavras.size()
	for wi in n_pal:
		var w: String = palavras[wi]
		var letras := 0
		for ch in w:
			if ch.to_lower() != ch.to_upper() or ch.is_valid_int():
				letras += 1
		var n := clampi(int(ceil(letras / 2.6)), 1, 5) if letras > 0 else 0
		for k in n:
			var st := rng.randf_range(-var_st, var_st)
			if pergunta and wi == n_pal - 1 and k == n - 1:
				st = var_st + 4.0                                  # sobe no fim
			var f0 := base * pow(2.0, st / 12.0)
			var f1 := f0 * pow(2.0, rng.randf_range(-2.0, 2.0) / 12.0)
			if pergunta and wi == n_pal - 1 and k == n - 1:
				f1 = f0 * pow(2.0, 3.0 / 12.0)
			var dur := 1.0 / ritmo * rng.randf_range(0.75, 1.2) * (0.8 if grito else 1.0)
			_silabas.append([f0 * (1.12 if grito else 1.0), f1 * (1.12 if grito else 1.0), dur, 1.0 if grito else 0.75])
		# pausa entre palavras (e maior depois de vírgula, ponto e reticências)
		var pausa := 0.035
		if w.ends_with("...") or w.ends_with("…"):
			pausa = 0.42
		elif w.ends_with(",") or w.ends_with(";"):
			pausa = 0.16
		elif w.ends_with(".") or w.ends_with("!") or w.ends_with("?"):
			pausa = 0.26
		_silabas.append([0.0, 0.0, pausa, 0.0])
	_total = 0.0
	for s in _silabas:
		_total += float(s[2])
	_i = 0
	_t = 0.0
	_feito = 0.0
	falando = not _silabas.is_empty()
	progresso = 0.0 if falando else 1.0
	_p.volume_db = volume_db + (3.0 if grito else 0.0) + linear_to_db(maxf(0.0001, float(Config.g.get("vvoz", 100)) / 100.0))
	if float(Config.g.get("vvoz", 100)) <= 0.0:
		_p.volume_db = -80.0                       # desligado: fica só a legenda
	if falando and not _p.playing:
		_p.play()
		_pb = _p.get_stream_playback()
	return _total

func parar() -> void:
	_silabas.clear()
	falando = false
	progresso = 1.0

func _process(_dt: float) -> void:
	if _pb == null or not _p.playing:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var brilho: float = _timbre[3]
	var tremor: float = _timbre[4]
	for f in n:
		var amostra := 0.0
		if falando and _i < _silabas.size():
			var s: Array = _silabas[_i]
			var dur: float = s[2]
			if float(s[0]) > 0.0:
				var x := _t / dur
				var freq: float = lerpf(s[0], s[1], x)
				if tremor > 0.0:
					freq *= 1.0 + tremor * 0.03 * sin(_t * TAU * 7.0)
				_fase = fmod(_fase + freq / TAXA, 1.0)
				var ph := _fase * TAU
				# "bipe" de robô: senoide + harmônicos + um pouco de onda quadrada (brilho)
				var onda := sin(ph) * 0.62 + sin(ph * 2.0) * 0.22 + sin(ph * 3.0) * 0.08 * (1.0 + brilho)
				onda += (1.0 if sin(ph) >= 0.0 else -1.0) * 0.12 * brilho
				var env := minf(1.0, _t / 0.012) * minf(1.0, (dur - _t) / 0.03)
				env *= 0.85 + 0.15 * sin(x * PI)
				amostra = onda * env * float(s[3]) * 0.32
			_t += 1.0 / TAXA
			_feito += 1.0 / TAXA
			if _t >= dur:
				_t = 0.0
				_i += 1
			progresso = clampf(_feito / maxf(_total, 0.001), 0.0, 1.0)
			if _i >= _silabas.size():
				falando = false
				progresso = 1.0
		if _filtro:
			# rádio/TV: corta graves e agudos (som de alto-falante pequeno) e um chiado leve
			_lp += (amostra - _lp) * 0.35
			_hp += (_lp - _hp) * 0.08
			amostra = (_lp - _hp) * 1.6 + randf_range(-1.0, 1.0) * 0.012
		buf[f] = Vector2(amostra, amostra)
	_pb.push_buffer(buf)
