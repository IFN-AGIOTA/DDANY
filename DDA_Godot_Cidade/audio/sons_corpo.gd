extends RefCounted
# SONS DO CORPO sintetizados por código (sem arquivos): PASSOS (4 variações, seco e molhado) e DOR (gemido
# curto quando o jogador leva um golpe/mordida). Gerados uma vez, na primeira vez que alguém pede.
# Usados por jogador/jogador.gd (passos e dor) e inimigos/vago.gd (passos dos infectados correndo).
# Mexa AQUI para: o timbre dos passos e da dor.

const TAXA := 22050
static var _cache := {}

static func passo(i: int, molhado := false) -> AudioStreamWAV:
	var k := "passo%d%s" % [i % 4, "m" if molhado else ""]
	if not _cache.has(k):
		_cache[k] = _wav(_passo(i % 4, molhado))
	return _cache[k]

static func dor(i: int) -> AudioStreamWAV:
	var k := "dor%d" % (i % 3)
	if not _cache.has(k):
		_cache[k] = _wav(_dor(i % 3))
	return _cache[k]

# pisada: baque grave do calcanhar + raspada de sola (ruído filtrado); molhado = mais agudo e "chapinhado"
static func _passo(v: int, molhado: bool) -> PackedFloat32Array:
	var dur := 0.22
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 400 + v * 31 + (7 if molhado else 0)
	var lp := 0.0
	var lp2 := 0.0
	var corte := 0.18 + v * 0.03
	for i in n:
		var t := float(i) / TAXA
		var ruido := r.randf_range(-1.0, 1.0)
		lp += (ruido - lp) * corte
		lp2 += (lp - lp2) * (0.5 if molhado else 0.25)
		var baque := sin(TAU * (70.0 + v * 9.0) * t) * exp(-t * 40.0)
		var raspa := (lp2 if not molhado else (ruido - lp) * 0.6) * exp(-t * (28.0 if molhado else 22.0))
		var segundo := 0.0
		var t2 := t - 0.035                              # ponta do pé logo depois do calcanhar
		if t2 > 0.0:
			segundo = lp * exp(-t2 * 45.0) * 0.5
		a[i] = (baque * 0.9 + raspa * 1.4 + segundo) * minf(1.0, t * 900.0)
	return a

# gemido de dor: voz curta (formantes de "ah"/"uh") com altura caindo
static func _dor(v: int) -> PackedFloat32Array:
	var dur := 0.42 + v * 0.06
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var f0: float = [150.0, 128.0, 170.0][v]
	var formantes: Array = [[700.0, 1150.0], [450.0, 900.0], [620.0, 1250.0]][v]
	var fase := 0.0
	var r := RandomNumberGenerator.new()
	r.seed = 77 + v
	for i in n:
		var t := float(i) / TAXA
		var f: float = f0 * (1.15 - 0.35 * t / dur) * (1.0 + 0.02 * sin(TAU * 7.0 * t))
		fase += f / TAXA
		var s := 0.0
		for h in range(1, 14):
			var fh: float = f * h
			var amp: float = exp(-pow((fh - formantes[0]) / 160.0, 2.0)) + 0.6 * exp(-pow((fh - formantes[1]) / 220.0, 2.0)) + 0.05 / h
			s += sin(TAU * fase * h) * amp
		s += r.randf_range(-1.0, 1.0) * 0.12                 # ar/rouquidão
		var e := minf(1.0, t * 30.0) * pow(maxf(0.0, 1.0 - t / dur), 1.5)
		a[i] = s * e
	return a

static func _wav(x: PackedFloat32Array) -> AudioStreamWAV:
	var pico := 0.0001
	for v in x:
		pico = maxf(pico, absf(v))
	var dados := PackedByteArray()
	dados.resize(x.size() * 2)
	for i in x.size():
		dados.encode_s16(i * 2, int(clampf(x[i] / pico * 0.9, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.data = dados
	return w
