extends Node
# SONS DAS ARMAS sintetizados por código, como no HTML (ruído filtrado + "tum" grave).
# Gerados uma vez ao abrir o jogo; não precisa de arquivos de áudio.
# Para trocar por sons gravados: substitua os streams em "sons" (ex.: sons["tiro_m4"] = load("res://sons/m4.wav")).

const TAXA := 22050
const N_CANAIS := 6

var sons := {}
var _canais: Array[AudioStreamPlayer] = []
var _ci := 0
var volume_db := 0.0

func _ready() -> void:
	sons["tiro_pistola"] = _tiro(false)
	sons["tiro_m4"] = _tiro(true)
	sons["clique_380"] = _clique(380.0, 0.09)
	sons["clique_620"] = _clique(620.0, 0.09)
	sons["clique_300"] = _clique(300.0, 0.1)
	sons["clique_900"] = _clique(900.0, 0.06)
	sons["clique_520"] = _clique(520.0, 0.07)
	for i in N_CANAIS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_canais.append(p)

func tocar(nome: String, vol_db := 0.0) -> void:
	if not sons.has(nome):
		return
	_ci = (_ci + 1) % _canais.size()
	var p := _canais[_ci]
	p.stream = sons[nome]
	p.volume_db = volume_db + vol_db
	p.play()

func _wav(amostras: PackedFloat32Array) -> AudioStreamWAV:
	var dados := PackedByteArray()
	dados.resize(amostras.size() * 2)
	for i in amostras.size():
		dados.encode_s16(i * 2, int(clampf(amostras[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	return w

# rampa exponencial (igual ao exponentialRampToValueAtTime do WebAudio)
static func _exp(v0: float, v1: float, t: float, T: float) -> float:
	return v0 * pow(v1 / v0, clampf(t / T, 0.0, 1.0))

func _tiro(m4: bool) -> AudioStreamWAV:
	var n := int(TAXA * 0.3)
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 if m4 else 1717
	var lp := 0.0
	var fase := 0.0
	var f0 := 3200.0 if m4 else 4200.0
	var g0 := 0.5 if m4 else 0.42
	var dur := 0.16 if m4 else 0.22
	var o0 := 170.0 if m4 else 130.0
	for i in n:
		var t := float(i) / TAXA
		var fc := _exp(f0, 400.0, t, 0.14)
		var k := 1.0 - exp(-TAU * fc / TAXA)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		var g := _exp(g0, 0.001, t, dur) if t < dur else 0.0
		var fo := _exp(o0, 45.0, t, 0.12)
		fase += fo / TAXA
		var tri := 4.0 * absf(fase - floorf(fase + 0.5)) - 1.0
		var og := _exp(0.5, 0.001, t, 0.14) if t < 0.14 else 0.0
		a[i] = (lp * g * 1.8 + tri * og) * 0.85
	return _wav(a)

func _clique(freq: float, vol: float) -> AudioStreamWAV:
	var n := int(TAXA * 0.06)
	var a := PackedFloat32Array()
	a.resize(n)
	var fase := 0.0
	for i in n:
		var t := float(i) / TAXA
		fase += _exp(freq, freq * 0.5, t, 0.04) / TAXA
		var sq := 1.0 if fmod(fase, 1.0) < 0.5 else -1.0
		a[i] = sq * (_exp(vol, 0.001, t, 0.05) if t < 0.05 else 0.0) * 2.5
	return _wav(a)
