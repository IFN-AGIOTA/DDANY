extends Node
# CHAT DE VOZ POR PROXIMIDADE (0.97) · só no multijogador. Criado por rede/sessao_rede.gd (ligar).
#   - MICROFONE ABERTO: fala quando detecta voz (volume acima de LIMIAR; segura FOLGA s depois de parar, para não
#     cortar o fim das palavras). Só manda se tem alguém perto (até ALCANCE m) e você não está morto.
#   - A voz dos outros sai DA BOCA de cada um (som 3D): perto = alto, longe = baixo, a mais de ALCANCE m não ouve.
#   - Em cima do amigo que está falando aparece ")))" junto do nome.
#   - DOIS BOTÕES (jogador/controles.gd; teclas J e K no PC): MIC = muta/desmuta o SEU microfone · VOZES = muta/desmuta
#     os outros jogadores. Os dois ficam guardados nas opções (Config "voz_mic" e "voz_ouvir").
#   - Celular: na 1ª vez pede a permissão do MICROFONE (Android). Sem permissão o MIC fica mudo (o resto funciona).
# Formato: 16 000 amostras/s, mono, μ-law 8 bits (G.711), pacotes de 40 ms (640 bytes) ≈ 16 KB/s só enquanto fala.
# Vai pela rede no canal rápido (rede/rede.gd enviar_voz: pode perder pacote, a voz segue).
# Mexa AQUI para: alcance, sensibilidade do microfone (LIMIAR), volume das vozes.

const TAXA := 16000
const QUADRO := 640                     # amostras por pacote (40 ms)
const ALCANCE := 45.0                   # metros
const LIMIAR := 0.012                   # volume (RMS) que conta como fala
const FOLGA := 0.45                     # s que continua mandando depois de parar de falar
const VOLUME_DB := 4.0                  # volume das vozes
const BUFFER := 0.5                     # s guardados para tocar (segura atrasos da rede)
const PERMISSAO := "android.permission.RECORD_AUDIO"

var sessao = null                       # rede/sessao_rede.gd
var mic_ligado := true                  # botão MIC
var ouvir := true                       # botão VOZES
var falando := false                    # mandando voz agora (o botão MIC acende)
var permitido := true                   # Android: deu a permissão do microfone?

var _bus := -1
var _captura: AudioEffectCapture = null
var _mic: AudioStreamPlayer = null
var _fase := 0.0                        # reamostragem (taxa da placa -> TAXA)
var _soma := 0.0
var _n := 0
var _amostras := PackedFloat32Array()
var _t_fala := 0.0
var _vozes := {}                        # id -> {"p": AudioStreamPlayer3D, "pb": playback, "t": s desde o último pacote}
static var _enc: PackedByteArray = PackedByteArray()     # magnitude (0..8158) -> byte μ-law sem o sinal
static var _dec: PackedFloat32Array = PackedFloat32Array()  # byte -> amostra (-1..1)

func ligar(s) -> void:
	sessao = s
	_tabelas()
	mic_ligado = bool(Config.valor("voz_mic"))
	ouvir = bool(Config.valor("voz_ouvir"))
	Rede.voz_recebida.connect(_recebeu)
	if OS.has_feature("android"):
		permitido = PERMISSAO in OS.get_granted_permissions()
		get_tree().on_request_permissions_result.connect(_permissao)
	_atualizar_mic()

func _exit_tree() -> void:
	if Rede.voz_recebida.is_connected(_recebeu):
		Rede.voz_recebida.disconnect(_recebeu)
	_parar_mic()

# ---------- botões ----------
func alternar_mic() -> void:
	mic_ligado = not mic_ligado
	Config.definir("voz_mic", mic_ligado)
	_atualizar_mic()
	_aviso("MICROFONE LIGADO" if mic_ligado and permitido else ("MICROFONE MUDO" if not mic_ligado else "SEM PERMISSÃO DO MICROFONE"))

func alternar_ouvir() -> void:
	ouvir = not ouvir
	Config.definir("voz_ouvir", ouvir)
	if not ouvir:
		for id in _vozes:
			_vozes[id]["p"].stop()
	_aviso("VOZES DOS JOGADORES LIGADAS" if ouvir else "VOZES DOS JOGADORES MUDAS")

func _aviso(t: String) -> void:
	var m = sessao.main if sessao != null else null
	if m != null and m.hud != null:
		m.hud.mostrar_aviso(t, 2.0)

func _permissao(nome: String, ok: bool) -> void:
	if nome == PERMISSAO:
		permitido = ok
		_atualizar_mic()
		if not ok:
			_aviso("SEM PERMISSÃO DO MICROFONE: SÓ VOCÊ NÃO FALA (OUVIR CONTINUA)")

# ---------- microfone ----------
func _atualizar_mic() -> void:
	if not mic_ligado:
		_parar_mic()
		return
	if OS.has_feature("android") and not permitido and ProjectSettings.get_setting("audio/driver/enable_input", false):
		OS.request_permission(PERMISSAO)       # resposta em _permissao
		return
	_ligar_mic()

var sem_app_novo := false               # o app instalado é antigo (sem microfone): precisa do APK novo para FALAR
func _ligar_mic() -> void:
	if _mic != null:
		return
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		if not sem_app_novo:
			sem_app_novo = true
			_aviso("PARA FALAR, INSTALE O APP NOVO (0.97). OUVIR OS OUTROS JÁ FUNCIONA")
		return
	_bus = AudioServer.get_bus_index("Microfone")
	if _bus < 0:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, "Microfone")
		_captura = AudioEffectCapture.new()
		_captura.buffer_length = 0.5
		AudioServer.add_bus_effect(_bus, _captura)
		AudioServer.set_bus_mute(_bus, true)          # o seu microfone não sai no seu alto-falante
	else:
		_captura = AudioServer.get_bus_effect(_bus, 0) as AudioEffectCapture
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "Microfone"
	add_child(_mic)
	_mic.play()
	_captura.clear_buffer()

func _parar_mic() -> void:
	if _mic != null:
		_mic.stop()
		_mic.queue_free()
		_mic = null
	falando = false
	_amostras.clear()

func _process(dt: float) -> void:
	# botões: acesos/apagados
	var c = sessao.main.controles if sessao != null and sessao.main != null else null
	if c != null:
		c.textos["MIC"] = "MIC" if mic_ligado and permitido and not sem_app_novo else "MUDO"
		c.indicadores["MIC"] = falando
		c.textos["VOZES"] = "VOZES" if ouvir else "SEM VOZ"
		c.indicadores["VOZES"] = not ouvir
	if _mic != null and _captura != null:
		var n := _captura.get_frames_available()
		if n > 0:
			processar(_captura.get_buffer(n), AudioServer.get_mix_rate())
	# quem falou há pouco: ")))" em cima
	for id in _vozes.keys():
		var v: Dictionary = _vozes[id]
		v["t"] += dt
		var r = _remoto(id)
		if r == null:
			if is_instance_valid(v["p"]):
				v["p"].queue_free()
			_vozes.erase(id)
			continue
		r.falando = v["t"] < 0.35 and ouvir

# amostras da placa (estéreo, na taxa dela) -> pacotes de 40 ms a 16 kHz (também usado pelos testes)
func processar(buf: PackedVector2Array, taxa_placa: float) -> void:
	if not mic_ligado:
		return
	var passo := taxa_placa / TAXA
	for f in buf:
		_soma += (f.x + f.y) * 0.5
		_n += 1
		_fase += 1.0
		if _fase >= passo:
			_fase -= passo
			_amostras.append(_soma / _n)
			_soma = 0.0
			_n = 0
			if _amostras.size() >= QUADRO:
				_quadro(_amostras)
				_amostras = PackedFloat32Array()

var enviados := 0                       # pacotes mandados (testes)
func _quadro(a: PackedFloat32Array) -> void:
	var soma := 0.0
	for x in a:
		soma += x * x
	var rms := sqrt(soma / a.size())
	if rms > LIMIAR:
		_t_fala = FOLGA
	else:
		_t_fala -= float(a.size()) / TAXA
	falando = _t_fala > 0.0
	if not falando or not _tem_alguem_perto():
		return
	Rede.enviar_voz(codificar(a))
	enviados += 1

func _tem_alguem_perto() -> bool:
	if sessao == null or sessao.jogador == null or bool(sessao.jogador.morto):
		return false
	var p: Vector3 = sessao.jogador.global_position
	for id in sessao.remotos:
		var r = sessao.remotos[id]
		if is_instance_valid(r) and r.visible and p.distance_to(r.global_position) <= ALCANCE + 5.0:
			return true
	return false

# ---------- vozes dos outros ----------
var recebidos := 0                      # pacotes tocados (testes)
func _recebeu(id: int, d: PackedByteArray) -> void:
	if not ouvir:
		return
	var r = _remoto(id)
	if r == null:
		return
	var v: Dictionary = _vozes.get(id, {})
	if v.is_empty() or not is_instance_valid(v["p"]):
		var p := AudioStreamPlayer3D.new()
		var g := AudioStreamGenerator.new()
		g.mix_rate = TAXA
		g.buffer_length = BUFFER
		p.stream = g
		p.position = Vector3(0, 1.65, 0)          # a boca
		p.unit_size = 4.0
		p.max_distance = ALCANCE
		p.volume_db = VOLUME_DB
		p.attenuation_filter_cutoff_hz = 20500.0
		r.add_child(p)
		p.play()
		v = {"p": p, "pb": p.get_stream_playback(), "t": 0.0}
		_vozes[id] = v
	var pl: AudioStreamPlayer3D = v["p"]
	if not pl.playing:
		pl.play()
		v["pb"] = pl.get_stream_playback()
	var pb: AudioStreamGeneratorPlayback = v["pb"]
	var amostras := decodificar(d)
	if pb.get_frames_available() >= amostras.size():
		pb.push_buffer(amostras)
	v["t"] = 0.0
	recebidos += 1

func _remoto(id: int):
	if sessao == null or not sessao.remotos.has(id):
		return null
	var r = sessao.remotos[id]
	return r if is_instance_valid(r) else null

# ---------- μ-law (G.711) ----------
static func _tabelas() -> void:
	if not _dec.is_empty():
		return
	_enc.resize(8159)
	for s in 8159:
		var v := s + 33
		var e := 7
		while e > 0 and v < (32 << e):
			e -= 1
		var m := (v >> (e + 1)) & 0x0F
		_enc[s] = (e << 4) | m
	_dec.resize(256)
	for b in 256:
		var u := (~b) & 0xFF
		var e := (u >> 4) & 7
		var m := u & 0x0F
		var s := (((m << 1) + 33) << e) - 33
		_dec[b] = float(-s if (u & 0x80) != 0 else s) / 8158.0

static func codificar(a: PackedFloat32Array) -> PackedByteArray:
	_tabelas()
	var r := PackedByteArray()
	r.resize(a.size())
	for i in a.size():
		var s := int(clampf(a[i], -1.0, 1.0) * 8158.0)
		var sinal := 0
		if s < 0:
			sinal = 0x80
			s = -s
		r[i] = (~(sinal | _enc[mini(s, 8158)])) & 0xFF
	return r

static func decodificar(d: PackedByteArray) -> PackedVector2Array:
	_tabelas()
	var r := PackedVector2Array()
	r.resize(d.size())
	for i in d.size():
		var x := _dec[d[i]]
		r[i] = Vector2(x, x)
	return r
