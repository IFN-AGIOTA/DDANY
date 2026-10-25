extends Node3D
# LUZ E SOM DOS LOCAIS ESPECIAIS (0.77) · criado por mundo/locais.gd quando um local especial (posto, hospital, ...)
# é montado perto do jogador (e some junto com ele).
#   - GERADOR: alguns locais ainda têm um gerador funcionando (CHANCE_GERADOR, sempre os mesmos: vem do índice do
#     local). Com gerador: ronco dele num canto do terreno e, à NOITE (clima escuro), lâmpadas acesas por dentro
#     (luz fria de hospital/supermercado, amarelada no posto e no armazém) — uma delas pisca, como lâmpada velha.
#     Visto de longe, um local aceso à noite chama a atenção (e os outros jogadores sabem que tem gente por perto).
#   - SEM GERADOR: escuro; só o vento batendo em alguma chapa solta (rangido) de vez em quando.
#   - Hospital com gerador: o BIPE de um aparelho esquecido ligado, num quarto.
#   - 0.78: delegacia e quartel com gerador: o CHIADO de um rádio esquecido ligado (estática baixinha).
#   - Zumbido das lâmpadas acesas (bem baixo, só de perto).
#   - 0.92: cada luz tem a LÂMPADA desenhada (antes era luz saindo do nada): calha com tubo fluorescente presa no
#     teto (hospital, mercado, delegacia, escola, quartel) ou lâmpada pendurada no fio (posto, armazém, cobertura); o
#     tubo/bulbo brilha junto com a luz (apagado de dia, piscando na lâmpada velha).
# Os sons são feitos por código (nada baixado). Poucas luzes (no máximo LUZES_MAX por local, sem sombra, somem de
# longe): leve no celular.
# Mexa AQUI para: chance do gerador, cor/força/alcance das luzes, quais sons e o volume.

const Sons := preload("res://audio/sons.gd")

const CHANCE_GERADOR := 0.6
const LUZES_MAX := 4
const ALCANCE := 11.0
const SUMIR_LONGE := 70.0               # a luz apaga (some) a essa distância da câmera

var tipo := "posto"
var indice := 0
var volumes: Array = []                 # mundo/locais.gd casca(): [centro local, tamanho, cor]
var clima = null                        # mundo/clima.gd (escuridao)
var tem_gerador := false

var _luzes: Array[OmniLight3D] = []
var _brilhos: Array[StandardMaterial3D] = []   # 0.92: o tubo/bulbo de cada luz (mesma ordem de _luzes)
var _pisca: OmniLight3D = null
var _energia := 0.0
var _t := 0.0
var _t_pisca := 0.0
var _zumbido: AudioStreamPlayer3D = null
var _bipe: AudioStreamPlayer3D = null
var _t_bipe := 0.0
var _t_rangido := 0.0
var _rng := RandomNumberGenerator.new()

static var _wavs := {}

func _ready() -> void:
	_rng.seed = indice * 9133 + 17
	tem_gerador = _rng.randf() < CHANCE_GERADOR and tipo != "bunker"      # 0.83: bunker sempre no escuro
	_t_rangido = _rng.randf_range(4.0, 12.0)
	if not tem_gerador:
		return
	# lâmpadas: espalhadas no maior volume (o prédio), perto do teto; no posto, também embaixo da cobertura
	var predio: Array = []
	var cobertura: Array = []
	for v in volumes:
		var t: Vector3 = v[1]
		if t.y >= 2.5 and (predio.is_empty() or t.x * t.z > (predio[1] as Vector3).x * (predio[1] as Vector3).z):
			predio = v
		elif t.y < 1.0 and t.x * t.z > 100.0:
			cobertura = v
	var pontos: Array = []
	if not predio.is_empty():
		var c: Vector3 = predio[0]
		var t: Vector3 = predio[1]
		var y := c.y - t.y * 0.5 + minf(t.y - 0.6, 3.6)          # perto do teto do térreo
		var n := 3 if cobertura.is_empty() else 2
		for k in n:
			var f := (k + 0.5) / n
			var eixo_x := t.x >= t.z
			var p := Vector3(c.x + (t.x * (f - 0.5) * 0.8 if eixo_x else 0.0), y, c.z + (0.0 if eixo_x else t.z * (f - 0.5) * 0.8))
			pontos.append(p)
	if not cobertura.is_empty():
		var c2: Vector3 = cobertura[0]
		var t2: Vector3 = cobertura[1]
		for k in 2:
			pontos.append(Vector3(c2.x + t2.x * (k - 0.5) * 0.5, c2.y - t2.y * 0.5 - 0.3, c2.z))
	var cor := Color(0.85, 0.93, 1.0) if tipo in ["hospital", "supermercado", "delegacia", "escola", "quartel"] else Color(1.0, 0.86, 0.62)
	for k in mini(pontos.size(), LUZES_MAX):
		var l := OmniLight3D.new()
		l.position = pontos[k]
		l.light_color = cor
		l.omni_range = ALCANCE
		l.omni_attenuation = 1.2
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = SUMIR_LONGE - 15.0
		l.distance_fade_length = 15.0
		l.visible = false
		add_child(l)
		_luzes.append(l)
		_brilhos.append(_lampada(l.position, cor, cor.b > 0.9 and k < (3 if cobertura.is_empty() else 2)))
	if not _luzes.is_empty():
		_pisca = _luzes[_rng.randi() % _luzes.size()]
		_zumbido = _som("zumbido", _luzes[0].position, -24.0, 10.0)
	# o gerador: num canto do terreno, roncando baixo
	var canto := Vector3.ZERO
	if not predio.is_empty():
		var cc: Vector3 = predio[0]
		var tt: Vector3 = predio[1]
		canto = Vector3(cc.x + tt.x * 0.5 + 1.5, 0.6, cc.z - tt.z * 0.5 + 1.5)
	var ger := _som("gerador", canto, -14.0, 14.0)
	ger.play()
	if tipo == "hospital" and not predio.is_empty():
		_bipe = _som("bipe", (predio[0] as Vector3) + Vector3(_rng.randf_range(-8, 8), -(predio[1] as Vector3).y * 0.5 + 1.2, 0.0), -16.0, 9.0)
	if tipo in ["delegacia", "quartel"] and not predio.is_empty():
		var ch := _som("chiado", (predio[0] as Vector3) + Vector3(_rng.randf_range(-5, 5), -(predio[1] as Vector3).y * 0.5 + 1.2, 0.0), -20.0, 8.0)
		ch.play()

# a lâmpada da luz em "p": calha com tubo fluorescente (tubo = true) presa por dois arames, ou bulbo pendurado no fio
# · devolve o material do tubo/bulbo (o brilho acende junto com a luz)
func _lampada(p: Vector3, cor: Color, tubo: bool) -> StandardMaterial3D:
	var brilho := StandardMaterial3D.new()
	brilho.albedo_color = Color(0.92, 0.92, 0.9)
	brilho.emission_enabled = true
	brilho.emission = cor
	brilho.emission_energy_multiplier = 0.0
	brilho.roughness = 0.3
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.56, 0.55)
	metal.roughness = 0.6
	metal.metallic = 0.4
	var no := Node3D.new()
	no.position = p
	add_child(no)
	if tubo:
		_peca(no, Vector3(0, 0.36, 0), _caixa(Vector3(1.3, 0.05, 0.22)), metal)       # calha
		_peca(no, Vector3(0, 0.31, 0), _cilindro(0.025, 1.2), brilho)                 # tubo (deitado: _peca)
		for x in [-0.5, 0.5]:
			_peca(no, Vector3(x, 0.52, 0), _caixa(Vector3(0.01, 0.3, 0.01)), metal)   # arames até o teto
	else:
		_peca(no, Vector3(0, 0.36, 0), _caixa(Vector3(0.012, 0.38, 0.012)), metal)      # fio
		_peca(no, Vector3(0, 0.17, 0), _cilindro(0.04, 0.07), metal)                  # bocal
		var bulbo := SphereMesh.new()
		bulbo.radius = 0.065
		bulbo.height = 0.15
		bulbo.radial_segments = 10
		bulbo.rings = 6
		_peca(no, Vector3(0, 0.08, 0), bulbo, brilho)
	return brilho

static func _caixa(t: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = t
	return b

static func _cilindro(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c

func _peca(pai: Node3D, pos: Vector3, malha: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.position = pos
	if malha is CylinderMesh and (malha as CylinderMesh).height > 0.5:
		mi.rotation.z = PI * 0.5                                  # o tubo fica deitado
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = SUMIR_LONGE
	pai.add_child(mi)

func _som(nome: String, pos: Vector3, vol: float, alcance: float) -> AudioStreamPlayer3D:
	var s := AudioStreamPlayer3D.new()
	s.stream = _wav(nome)
	s.position = pos
	s.volume_db = vol
	s.unit_size = alcance * 0.35
	s.max_distance = alcance * 3.0
	s.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(s)
	return s

func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = 1.0
		var noite := 1.0
		if clima != null and clima.has_method("escuridao"):
			noite = smoothstep(0.25, 0.6, float(clima.escuridao()))
		_energia = noite if tem_gerador else 0.0
		for l in _luzes:
			l.visible = _energia > 0.02
		if _energia <= 0.02:
			for b in _brilhos:
				b.emission_energy_multiplier = 0.0           # de dia: lâmpada apagada
		if _zumbido != null:
			if _energia > 0.02 and not _zumbido.playing:
				_zumbido.play()
			elif _energia <= 0.02 and _zumbido.playing:
				_zumbido.stop()
		if not tem_gerador:
			_t_rangido -= 1.0
			if _t_rangido <= 0.0:
				_t_rangido = _rng.randf_range(8.0, 22.0)
				Sons.em("mundo/rangido", global_position + Vector3(_rng.randf_range(-10, 10), 3.0, _rng.randf_range(-10, 10)), -10.0, 30.0, _rng.randf_range(0.6, 0.9))
	if _energia <= 0.02:
		return
	for l in _luzes:
		if l != _pisca:
			l.light_energy = 1.1 * _energia
	# a lâmpada velha: fica acesa, de repente pisca algumas vezes
	if _pisca != null:
		_t_pisca -= dt
		if _t_pisca <= 0.0:
			_t_pisca = _rng.randf_range(0.04, 0.12) if _rng.randf() < 0.85 else _rng.randf_range(1.5, 5.0)
			_pisca.light_energy = (1.1 if _rng.randf() < 0.55 else 0.05) * _energia
	for k in _brilhos.size():                     # o tubo/bulbo brilha junto com a sua luz
		_brilhos[k].emission_energy_multiplier = _luzes[k].light_energy * 2.2 if _luzes[k].visible else 0.0
	if _bipe != null:
		_t_bipe -= dt
		if _t_bipe <= 0.0:
			_t_bipe = 1.6
			_bipe.play()

# ---------- sons feitos por código ----------
static func _wav(nome: String) -> AudioStreamWAV:
	if _wavs.has(nome):
		return _wavs[nome]
	var taxa := 22050
	var n := taxa                       # 1 s
	var laco := true
	if nome == "bipe":
		n = int(taxa * 0.18)
		laco = false
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = hash(nome)
	var ruido := 0.0
	for i in n:
		var t := float(i) / taxa
		var x := 0.0
		match nome:
			"zumbido":                  # lâmpada fluorescente: 120 Hz e harmônicos, bem fino
				x = 0.35 * sin(TAU * 120.0 * t) + 0.18 * sin(TAU * 240.0 * t) + 0.08 * sin(TAU * 360.0 * t)
			"gerador":                  # motor a diesel: batidas a 25 Hz + ronco grave + ruído
				ruido = ruido * 0.92 + (r.randf() * 2.0 - 1.0) * 0.08
				var pulso := 1.0 if fmod(t * 25.0, 1.0) < 0.22 else 0.0
				x = 0.45 * sin(TAU * 50.0 * t) + 0.3 * pulso + 0.9 * ruido
			"chiado":                   # rádio fora de sintonia: ruído com o volume ondulando
				ruido = ruido * 0.35 + (r.randf() * 2.0 - 1.0) * 0.65
				x = ruido * (0.35 + 0.25 * sin(TAU * 0.7 * t) + 0.15 * sin(TAU * 3.1 * t))
			"bipe":                     # monitor: um bipe de 1 kHz com ataque e queda suaves
				var env := minf(1.0, t / 0.01) * minf(1.0, (float(n) / taxa - t) / 0.03)
				x = 0.6 * sin(TAU * 1000.0 * t) * env
		dados.encode_s16(i * 2, int(clampf(x, -1.0, 1.0) * 22000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.data = dados
	if laco:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	_wavs[nome] = w
	return w
