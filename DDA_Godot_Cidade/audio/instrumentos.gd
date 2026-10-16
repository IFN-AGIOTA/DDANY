extends RefCounted
# INSTRUMENTOS DA MÚSICA (sintetizados por código, sem arquivos de áudio). Cada um vira uma "amostra"
# (AudioStreamWAV) tocada numa nota base; as outras notas saem mudando o pitch_scale.
# Feitos uma vez, numa thread, ao abrir o jogo (ver musica_procedural.gd).
#   drone ........ zumbido grave contínuo (loop), 3 vozes desafinadas batendo entre si
#   vento ........ sussurro/vento de ruído filtrado (loop)
#   cordas ....... naipe de cordas lento (arco), com vibrato
#   tremolo ...... violinos agudos em tremolo nervoso
#   caixinha ..... caixinha de música desafinada
#   piano ........ piano velho desafinado (cordas duplas batendo)
#   sino ......... sino de igreja (parciais inarmônicos, cauda longa)
#   coracao ...... batida de coração (tum-tum)
#   tambor ....... tambor grave / impacto
#   baixo ........ baixo pulsante curto (ostinato de tensão)
#   coro ......... coro "aah" sombrio (formantes)
#   reverso ...... prato ao contrário (sobe antes do susto)
#   grito ........ cluster de violinos subindo (susto/stinger)
#   (usados nas MÚSICAS COMPOSTAS, audio/faixas.gd)
#   violao ....... violão de nylon dedilhado (corda pinçada, Karplus-Strong)
#   pad .......... teclado/sintetizador macio e longo (fundo dos acordes)
#   metal ........ metais curtos (trompa/trombone) para as frases de ação
#   caixa ........ caixa de bateria (estalo + esteira)
#   chimbal ...... chimbal fechado (ruído agudo bem curto)
# Mexa AQUI para: o timbre dos instrumentos (harmônicos, envelopes, duração) ou para criar um instrumento novo
# (escreva uma função que devolva amostras e acrescente em TODOS / gerar_todos).

const TAXA := 22050
const N_TAB := 2048

# nota base de cada amostra (Hz): usada para calcular o pitch_scale de qualquer nota
const BASE := {
	"drone": 55.0, "cordas": 220.0, "tremolo": 440.0, "caixinha": 880.0, "piano": 220.0, "sino": 220.0,
	"coro": 220.0, "baixo": 55.0, "grito": 440.0, "vento": 1.0, "coracao": 1.0, "tambor": 1.0, "reverso": 1.0,
	"violao": 220.0, "pad": 220.0, "metal": 220.0, "caixa": 1.0, "chimbal": 1.0,
}
const LOOP := ["drone", "vento"]

static func gerar_todos() -> Dictionary:
	var serra := _tabela_serra(18)
	var coro := _tabela_coro()
	var r := {}
	r["drone"] = _wav(_drone(serra), true)
	r["vento"] = _wav(_vento(), true)
	r["cordas"] = _wav(_cordas(serra))
	r["tremolo"] = _wav(_tremolo(serra))
	r["caixinha"] = _wav(_caixinha())
	r["piano"] = _wav(_piano())
	r["sino"] = _wav(_sino())
	r["coracao"] = _wav(_coracao())
	r["tambor"] = _wav(_tambor())
	r["baixo"] = _wav(_baixo(serra))
	r["coro"] = _wav(_coro(coro))
	r["reverso"] = _wav(_reverso())
	r["grito"] = _wav(_grito(serra))
	r["violao"] = _wav(_violao())
	r["pad"] = _wav(_pad(serra))
	r["metal"] = _wav(_metal(serra))
	r["caixa"] = _wav(_caixa())
	r["chimbal"] = _wav(_chimbal())
	return r

# ---------- utilidades ----------
static func _wav(a: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var pico := 0.0001
	for v in a:
		pico = maxf(pico, absf(v))
	var g := 0.9 / pico
	var dados := PackedByteArray()
	dados.resize(a.size() * 2)
	for i in a.size():
		dados.encode_s16(i * 2, int(clampf(a[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = a.size()
	return w

# um ciclo de onda dente-de-serra suave (soma de harmônicos), lido por tabela = barato de gerar
static func _tabela_serra(harm: int) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(N_TAB + 1)
	for i in N_TAB:
		var s := 0.0
		for k in range(1, harm + 1):
			s += sin(TAU * k * i / N_TAB) / k
		t[i] = s * 0.55
	t[N_TAB] = t[0]
	return t

# vogal "a" (formantes ~700, 1220, 2600 Hz) para nota de 220 Hz
static func _tabela_coro() -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(N_TAB + 1)
	var f0 := 220.0
	for i in N_TAB:
		var s := 0.0
		for k in range(1, 16):
			var f := f0 * k
			var amp := exp(-pow((f - 700.0) / 130.0, 2.0)) + 0.6 * exp(-pow((f - 1220.0) / 160.0, 2.0)) + 0.25 * exp(-pow((f - 2600.0) / 220.0, 2.0)) + 0.15 / k
			s += sin(TAU * k * i / N_TAB) * amp
		t[i] = s
	t[N_TAB] = t[0]
	return t

static func _ler(tab: PackedFloat32Array, fase: float) -> float:
	var p := fase * N_TAB
	var i := int(p)
	var f := p - i
	return tab[i] + (tab[i + 1] - tab[i]) * f

static func _env(t: float, ataque: float, dur: float, solta: float) -> float:
	if t < ataque:
		return t / ataque
	if t > dur - solta:
		return maxf(0.0, (dur - t) / solta)
	return 1.0

# ---------- instrumentos ----------
static func _drone(tab: PackedFloat32Array) -> PackedFloat32Array:
	# 4 s, frequências com número inteiro de ciclos para o loop não estalar
	var dur := 4.0
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var fs := [55.0, 55.25, 110.5, 82.5]
	var gs := [1.0, 0.8, 0.35, 0.18]
	var lp := 0.0
	for i in n:
		var t := float(i) / TAXA
		var s := 0.0
		for v in 4:
			s += _ler(tab, fmod(fs[v] * t, 1.0)) * gs[v]
		s *= 0.75 + 0.25 * sin(TAU * 0.5 * t)          # pulsação lenta (2 ciclos no loop)
		lp += (s - lp) * 0.08                             # escurece (passa-baixa)
		a[i] = lp
	# suaviza a emenda do filtro no fim do loop
	var m := 600
	for i in m:
		var k := float(i) / m
		a[n - m + i] = lerpf(a[n - m + i], a[i], k)
	return a

static func _vento() -> PackedFloat32Array:
	var dur := 6.0
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	var l1 := 0.0
	var l2 := 0.0
	var grave := 0.0
	for i in n:
		var t := float(i) / TAXA
		var r := rng.randf_range(-1.0, 1.0)
		var corte := 0.09 + 0.12 * (0.5 + 0.5 * sin(TAU * t / 3.0))   # "uivo" abre e fecha (~350-1000 Hz)
		l1 += (r - l1) * corte
		l2 += (l1 - l2) * corte
		grave += (l2 - grave) * 0.012                                  # tira o ronco grave (passa-faixa)
		a[i] = (l2 - grave) * (0.6 + 0.4 * sin(TAU * t / 6.0 + 1.0))
	var m := 4000                                          # emenda do loop em cruz
	for i in m:
		var k := float(i) / m
		a[i] = lerpf(a[n - m + i], a[i], k)
	a.resize(n - m)
	return a

static func _cordas(tab: PackedFloat32Array) -> PackedFloat32Array:
	var dur := 3.2
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var fases := [0.0, 0.33, 0.66]
	var det := [1.0, 1.004, 0.996]
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / TAXA
		var vib := 1.0 + 0.004 * sin(TAU * 5.3 * t) * minf(1.0, t)
		var s := 0.0
		for v in 3:
			fases[v] = fmod(fases[v] + 220.0 * det[v] * vib / TAXA, 1.0)
			s += _ler(tab, fases[v])
		s += rng.randf_range(-1.0, 1.0) * 0.04            # chiado do arco
		lp += (s - lp) * 0.25
		a[i] = lp * _env(t, 0.9, dur, 1.2)
	return a

static func _tremolo(tab: PackedFloat32Array) -> PackedFloat32Array:
	var dur := 2.6
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var f1 := 0.0
	var f2 := 0.5
	for i in n:
		var t := float(i) / TAXA
		f1 = fmod(f1 + 440.0 * (1.0 + 0.006 * sin(TAU * 6.1 * t)) / TAXA, 1.0)
		f2 = fmod(f2 + 440.0 * 1.007 / TAXA, 1.0)
		var trem := 0.55 + 0.45 * absf(sin(TAU * 7.0 * t))   # arco indo e voltando rápido
		a[i] = (_ler(tab, f1) + _ler(tab, f2) * 0.7) * trem * _env(t, 0.25, dur, 0.8)
	return a

static func _caixinha() -> PackedFloat32Array:
	var dur := 2.6
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var f := 880.0 * 0.992                                # levemente desafinada
	for i in n:
		var t := float(i) / TAXA
		var s := sin(TAU * f * t) * exp(-t * 2.2)
		s += 0.45 * sin(TAU * f * 3.98 * t) * exp(-t * 6.0)
		s += 0.18 * sin(TAU * f * 9.1 * t) * exp(-t * 14.0)
		s *= minf(1.0, t * 400.0)
		a[i] = s
	return a

static func _piano() -> PackedFloat32Array:
	var dur := 3.4
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var f := 220.0
	var parc := [[1.0, 1.0, 1.6], [2.004, 0.5, 2.4], [3.01, 0.3, 3.2], [4.03, 0.18, 4.0], [5.06, 0.1, 5.0]]
	for i in n:
		var t := float(i) / TAXA
		var s := 0.0
		for p in parc:
			# duas cordas por nota, uma desafinada: o "batimento" do piano velho
			s += (sin(TAU * f * p[0] * t) + sin(TAU * f * p[0] * 1.0035 * t)) * p[1] * exp(-t * p[2])
		s *= minf(1.0, t * 300.0)
		a[i] = s
	return a

static func _sino() -> PackedFloat32Array:
	var dur := 5.5
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var f := 220.0
	var parc := [[0.56, 1.0, 0.55], [0.92, 0.8, 0.8], [1.19, 0.7, 1.0], [1.71, 0.5, 1.4], [2.0, 0.6, 1.2], [2.74, 0.35, 2.0], [3.0, 0.3, 2.3], [3.76, 0.2, 3.0], [4.07, 0.18, 3.2]]
	for i in n:
		var t := float(i) / TAXA
		var s := 0.0
		for p in parc:
			s += sin(TAU * f * p[0] * t) * p[1] * exp(-t * p[2])
		a[i] = s * minf(1.0, t * 500.0)
	return a

static func _coracao() -> PackedFloat32Array:
	var dur := 0.75
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / TAXA
		var s := 0.0
		for b in [[0.0, 1.0], [0.24, 0.7]]:               # "tum" ... "tum"
			var u: float = t - b[0]
			if u > 0.0:
				var fase := TAU * (48.0 * u + 30.0 * (1.0 - exp(-u * 30.0)) / 30.0)
				s += sin(fase) * exp(-u * 14.0) * b[1] * minf(1.0, u * 300.0)
		a[i] = s
	return a

static func _tambor() -> PackedFloat32Array:
	var dur := 1.6
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var lp := 0.0
	var fase := 0.0
	for i in n:
		var t := float(i) / TAXA
		fase += (42.0 + 80.0 * exp(-t * 18.0)) / TAXA
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.12
		a[i] = sin(TAU * fase) * exp(-t * 2.6) + lp * exp(-t * 9.0) * 0.6
	return a

static func _baixo(tab: PackedFloat32Array) -> PackedFloat32Array:
	var dur := 0.55
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var fase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / TAXA
		fase = fmod(fase + 55.0 / TAXA, 1.0)
		var corte := 0.04 + 0.3 * exp(-t * 14.0)            # abre no ataque e fecha (pluck)
		lp += (_ler(tab, fase) - lp) * corte
		a[i] = lp * exp(-t * 4.5) * minf(1.0, t * 400.0)
	return a

static func _coro(tab: PackedFloat32Array) -> PackedFloat32Array:
	var dur := 4.2
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var fases := [0.0, 0.25, 0.5, 0.75]
	var det := [1.0, 1.006, 0.994, 1.012]
	for i in n:
		var t := float(i) / TAXA
		var s := 0.0
		for v in 4:
			var vib := 1.0 + 0.005 * sin(TAU * (4.6 + v * 0.4) * t + v)
			fases[v] = fmod(fases[v] + 220.0 * det[v] * vib / TAXA, 1.0)
			s += _ler(tab, fases[v])
		a[i] = s * _env(t, 1.2, dur, 1.5)
	return a

static func _reverso() -> PackedFloat32Array:
	var dur := 2.8
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var hp := 0.0
	var ant := 0.0
	for i in n:
		var t := float(i) / TAXA
		var r := rng.randf_range(-1.0, 1.0)
		hp = 0.92 * (hp + r - ant)                          # passa-alta: chiado de prato
		ant = r
		var e := pow(t / dur, 3.0)                          # cresce até o fim (som "ao contrário")
		a[i] = hp * e * (1.0 if t < dur - 0.02 else (dur - t) / 0.02)
	return a

static func _grito(tab: PackedFloat32Array) -> PackedFloat32Array:
	var dur := 3.0
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var fases := [0.0, 0.2, 0.4, 0.6, 0.8]
	var semis := [0.0, 1.0, 6.0, 7.0, 13.0]                  # cluster dissonante (2ª menor e trítono)
	for i in n:
		var t := float(i) / TAXA
		var sobe := pow(2.0, (t / dur) * 1.0)               # sobe uma oitava (glissando)
		var trem := 0.6 + 0.4 * absf(sin(TAU * (8.0 + t * 6.0) * t))
		var s := 0.0
		for v in 5:
			var f: float = 440.0 * pow(2.0, semis[v] / 12.0) * sobe * (1.0 + 0.01 * sin(TAU * 6.0 * t + v))
			fases[v] = fmod(fases[v] + f / TAXA, 1.0)
			s += _ler(tab, fases[v])
		a[i] = s * trem * _env(t, 0.15, dur, 0.6)
	return a

# ---------- instrumentos das músicas compostas ----------
static func _violao() -> PackedFloat32Array:
	# Karplus-Strong: um "fio" de ruído que se repete e vai sendo filtrado = corda pinçada
	var dur := 2.6
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var tam := int(round(TAXA / 220.0 - 0.5))                 # o filtro de média soma meia amostra ao período
	var buf := PackedFloat32Array()
	buf.resize(tam)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lp := 0.0
	for i in tam:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3        # dedo (não palheta): ataque mais macio
		buf[i] = lp
	var pos := 0
	for i in n:
		var j := (pos + 1) % tam
		var s := buf[pos]
		buf[pos] = 0.497 * (s + buf[j])
		a[i] = s
		pos = j
	var lp1 := 0.0                                           # nylon: som mais escuro, que escurece com o tempo
	var lp2 := 0.0
	for i in n:
		var t := float(i) / TAXA
		var corte := 0.12 + 0.25 * exp(-t * 6.0)
		lp1 += (a[i] - lp1) * corte
		lp2 += (lp1 - lp2) * corte
		a[i] = lp2 * minf(1.0, float(n - i) / (TAXA * 0.15))
	return a

static func _pad(tab: PackedFloat32Array) -> PackedFloat32Array:
	var dur := 4.5
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var fases := [0.0, 0.31, 0.62, 0.17]
	var det := [1.0, 1.003, 0.997, 0.5]
	var g := [1.0, 0.9, 0.9, 0.5]
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / TAXA
		var s := 0.0
		for v in 4:
			fases[v] = fmod(fases[v] + 220.0 * det[v] / TAXA, 1.0)
			s += _ler(tab, fases[v]) * g[v]
		var corte := 0.05 + 0.03 * sin(TAU * 0.3 * t)        # filtro "respirando"
		lp += (s - lp) * corte
		lp2 += (lp - lp2) * corte
		a[i] = lp2 * _env(t, 1.1, dur, 1.6)
	return a

static func _metal(tab: PackedFloat32Array) -> PackedFloat32Array:
	var dur := 0.9
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var f1 := 0.0
	var f2 := 0.5
	var lp := 0.0
	for i in n:
		var t := float(i) / TAXA
		f1 = fmod(f1 + 220.0 / TAXA, 1.0)
		f2 = fmod(f2 + 220.0 * 1.005 / TAXA, 1.0)
		var corte := 0.06 + 0.35 * exp(-t * 9.0) * minf(1.0, t * 60.0)   # "bwah": abre e fecha
		lp += (_ler(tab, f1) + _ler(tab, f2) - lp) * corte
		a[i] = lp * _env(t, 0.02, dur, 0.45)
	return a

static func _caixa() -> PackedFloat32Array:
	var dur := 0.45
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var hp := 0.0
	var ant := 0.0
	for i in n:
		var t := float(i) / TAXA
		var r := rng.randf_range(-1.0, 1.0)
		hp = 0.7 * (hp + r - ant)
		ant = r
		var tom := sin(TAU * (190.0 * t + 40.0 * (1.0 - exp(-t * 40.0)) / 40.0)) * exp(-t * 22.0)
		a[i] = (tom * 0.8 + hp * exp(-t * 11.0)) * minf(1.0, t * 800.0)
	return a

static func _chimbal() -> PackedFloat32Array:
	var dur := 0.12
	var n := int(TAXA * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var hp := 0.0
	var ant := 0.0
	for i in n:
		var t := float(i) / TAXA
		var r := rng.randf_range(-1.0, 1.0)
		hp = 0.5 * (hp + r - ant)
		ant = r
		a[i] = hp * exp(-t * 45.0)
	return a
