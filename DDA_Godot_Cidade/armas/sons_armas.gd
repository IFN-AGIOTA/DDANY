extends Node
# SONS DOS TIROS. 0.49: GRAVAÇÕES DE VERDADE (The Free Firearm Sound Library, CC0) em audio/sons/armas:
#   tiro_<arma>_N (perto, várias por arma, sorteadas) e longe_<arma>_N (de longe: amigos e tiros distantes).
#   1911 e Walther (pistola) · AR-15 (M4) · AK-47 · Benelli Nova e Mossberg (espingarda) · Tikka e Savage (rifle)
#   · Ruger .22 abafado (silenciado). Feitos por ferramentas/preparar_sons.py.
# Os sintetizados por código (como no HTML) ficam só de reserva, se faltar arquivo.
# Recarga, gatilho em seco, cápsulas, sacar: armas/armas.gd (_som_recarga, _depois_do_tiro) via audio/sons.gd.

const TAXA := 22050
const N_CANAIS := 10

var sons := {}
var _mp5 := false
var _canais: Array[AudioStreamPlayer] = []
var _ci := 0
var volume_db := 0.0
const SonsBaixados := preload("res://audio/sons_baixados.gd")
const Sons := preload("res://audio/sons.gd")
const TOM := {"tiro_ak": 0.9, "tiro_m4": 1.04}
const VOL_GRAVADO := {"tiro_rifle_caca": -3.0, "tiro_silenciado": -2.0}   # iguala o volume entre as armas

# tiro de OUTRO jogador / ao longe: gravação de longe se estiver a mais de PERTO_LONGE m (3D, vem do lado certo)
const PERTO_LONGE := 70.0
func tocar_em(nome: String, pos: Vector3, dist: float) -> void:
	var arma := nome.trim_prefix("tiro_")
	if nome != "tiro_silenciado" and dist > PERTO_LONGE and Sons.existe("armas/longe_" + arma):
		Sons.em("armas/longe_" + arma, pos, 6.0, 900.0)
	else:
		Sons.em("armas/" + nome, pos, 4.0 if nome != "tiro_silenciado" else -2.0, 260.0 if nome != "tiro_silenciado" else 45.0)

func _ready() -> void:
	sons["tiro_pistola"] = _tiro(4200.0, 0.42, 0.22, 130.0, 1717)
	sons["tiro_m4"] = _tiro(3200.0, 0.5, 0.16, 170.0, 4242)
	sons["tiro_ak"] = _tiro(2700.0, 0.62, 0.2, 140.0, 777)
	sons["tiro_espingarda"] = _tiro(2000.0, 0.75, 0.32, 105.0, 1212)
	sons["tiro_rifle_caca"] = _tiro(3000.0, 0.72, 0.3, 118.0, 3030)
	sons["tiro_silenciado"] = _tiro(1300.0, 0.3, 0.07, 240.0, 99, 0.35)
	sons["golpe"] = _vulto()
	sons["impacto"] = _tiro(700.0, 0.6, 0.08, 90.0, 55, 0.7)
	sons["clique_380"] = _clique(380.0, 0.09)
	sons["clique_620"] = _clique(620.0, 0.09)
	sons["clique_300"] = _clique(300.0, 0.1)
	sons["clique_900"] = _clique(900.0, 0.06)
	sons["clique_520"] = _clique(520.0, 0.07)
	sons["acerto"] = _acerto(150.0, 0.07, 0.6, 31)            # 1.01: tiro pegou (baque surdo, baixinho)
	sons["acerto_forte"] = _acerto(230.0, 0.1, 0.9, 47)       # 1.01: tiro na cabeça ou abate (mais seco e mais alto)
	for i in N_CANAIS:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"   # com eco de cidade
		add_child(p)
		_canais.append(p)

func tocar(nome: String, vol_db := 0.0) -> void:
	if nome == "tiro_mp5":
		nome = "tiro_pistola"             # 9 mm: as gravações da pistola, mais agudas (abaixo)
		_mp5 = true
	else:
		_mp5 = false
	var gravado := Sons.sortear("armas/" + nome) if nome.begins_with("tiro_") else null
	if gravado == null and not sons.has(nome):
		return
	_ci = (_ci + 1) % _canais.size()
	var p := _canais[_ci]
	p.stream = gravado if gravado != null else sons[nome]
	p.volume_db = volume_db + vol_db + (VOL_GRAVADO.get(nome, 0.0) if gravado != null else 0.0)
	p.pitch_scale = randf_range(0.96, 1.04) if gravado != null else float(TOM.get(nome, 1.0))
	if _mp5:
		p.pitch_scale *= 1.12
	if nome == "impacto":                 # golpe corpo a corpo acertando: um dos sons gravados de impacto
		var b := SonsBaixados.sortear("impactos/soco")
		if b != null:
			p.stream = b
			p.pitch_scale = randf_range(0.85, 1.15)
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

func _tiro(f0: float, g0: float, dur: float, o0: float, semente: int, grave := 0.5) -> AudioStreamWAV:
	var n := int(TAXA * maxf(0.3, dur + 0.12))
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var lp := 0.0
	var fase := 0.0
	for i in n:
		var t := float(i) / TAXA
		var fc := _exp(f0, 400.0, t, 0.14)
		var k := 1.0 - exp(-TAU * fc / TAXA)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		var g := _exp(g0, 0.001, t, dur) if t < dur else 0.0
		var fo := _exp(o0, 45.0, t, 0.12)
		fase += fo / TAXA
		var tri := 4.0 * absf(fase - floorf(fase + 0.5)) - 1.0
		var og := _exp(grave, 0.001, t, 0.14) if t < 0.14 else 0.0
		a[i] = (lp * g * 1.8 + tri * og) * 0.85
	return _wav(a)

# "vuuush" do golpe corpo a corpo (ruído que sobe e desce)
func _vulto() -> AudioStreamWAV:
	var n := int(TAXA * 0.26)
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / n
		var fc := 300.0 + 1800.0 * sin(t * PI)
		var k := 1.0 - exp(-TAU * fc / TAXA)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		lp2 += (lp - lp2) * k
		a[i] = (lp - lp2) * sin(t * PI) * 1.6
	return _wav(a)

# 1.01 · SOM DE ACERTO (estudos/ESTUDO_AAA.md 6, Swink: imagem + som + vibração no acerto): um baque curto, um tom
# grave que cai rápido com um pouco de ruído abafado por cima. Toca na hora, sem esperar o som do impacto chegar.
func _acerto(freq: float, dur: float, vol: float, semente: int) -> AudioStreamWAV:
	var n := int(TAXA * (dur + 0.03))
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var lp := 0.0
	var fase := 0.0
	for i in n:
		var t := float(i) / TAXA
		fase += _exp(freq, freq * 0.45, t, dur) / TAXA
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.18
		var g := _exp(vol, 0.001, t, dur) if t < dur else 0.0
		a[i] = (sin(TAU * fase) * 0.8 + lp * 0.9) * g
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
