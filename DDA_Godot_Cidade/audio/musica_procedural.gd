extends Node
# MÚSICA PROCEDURAL DE SUSPENSE E TERROR (autoload "Musica"). Nunca repete igual: um "compositor" escolhe a
# escala sombria, a nota central, o andamento e quais instrumentos tocam, conforme a TENSÃO (0 a 1):
#   calma (0 - 0,3) ...... drone grave, vento, caixinha de música e piano desafinado esparsos, sinos distantes
#   suspense (0,3 - 0,6)  + cordas dissonantes, coro sombrio, coração batendo devagar
#   tensão (0,6 - 1) ..... + violinos em tremolo, baixo pulsante, tambores, coração acelerado
#   susto ................ prato ao contrário subindo -> grito de violinos + tambor -> silêncio
# A tensão sobe com tiros e corrida (ligado em main.gd) e desce sozinha. Outros sistemas podem chamar:
#   Musica.adicionar_tensao(0.3) · Musica.susto() · Musica.definir_modo("menu"/"jogo")
# MÚSICAS COMPOSTAS (audio/faixas.gd): de tempos em tempos uma das 5 faixas toca inteira por cima (a parte
# procedural dá lugar a ela e volta quando acaba). Qual toca depende do momento:
#   menu = as calmas em sequência · jogo calmo de dia = Nova York Silenciosa, Dias de Chuva, Último Abrigo ·
#   de noite = Noite sem Luz · tensão alta (perseguição, tiros) = Correria (entra na hora).
#   Musica.tocar_faixa("chuva") toca uma na hora · Musica.noite é ligado pelo main.gd (relógio do clima).
# Os instrumentos são gerados em audio/instrumentos.gd numa thread (a música começa ~1 s depois de abrir).
# Tudo passa pelo barramento de áudio "Musica" (com reverb de salão), com volume em Opções › Vídeo e som.
# Mexa AQUI para: escalas, andamento, probabilidade de cada instrumento e o volume de cada um (VOL).

const Instrumentos := preload("res://audio/instrumentos.gd")
const Faixas := preload("res://audio/faixas.gd")

const BUS := "Musica"
const N_VOZES := 64
const LA := 55.0                                  # nota central base (Lá grave)

# escalas sombrias (semitons a partir da nota central)
const ESCALAS := {
	"frigio": [0, 1, 3, 5, 7, 8, 10],
	"locrio": [0, 1, 3, 5, 6, 8, 10],
	"menor_harmonica": [0, 2, 3, 5, 7, 8, 11],
	"diminuta": [0, 2, 3, 5, 6, 8, 9, 11],
	"tons_inteiros": [0, 2, 4, 6, 8, 10],
}
# para onde a nota central pode ir a cada seção (meio tom abaixo, trítono, terça menor...)
const MUDANCAS := [0, -1, 1, 6, -3, 3, -5]

# volume de cada instrumento (dB)
const VOL := {
	"drone": -12.0, "vento": -22.0, "cordas": -13.0, "tremolo": -17.0, "caixinha": -15.0, "piano": -13.0,
	"sino": -14.0, "coracao": -6.0, "tambor": -8.0, "baixo": -12.0, "coro": -16.0, "reverso": -14.0, "grito": -13.0,
	"violao": -11.0, "pad": -17.0, "metal": -14.0, "caixa": -13.0, "chimbal": -25.0,
}
const ESPERA_FAIXA := Vector2(60.0, 150.0)       # segundos de música procedural entre uma faixa e outra (jogo)

var tensao := 0.0                  # tensão atual (segue o alvo devagar)
var base_tensao := 0.15            # piso da tensão (menu = mais calmo)
var _alvo_extra := 0.0             # tensão vinda do jogo (tiros etc.), desce sozinha
var modo := "menu"
var pronto := false

var _amostras := {}
var _vozes: Array[AudioStreamPlayer] = []
var _vi := 0
var _drone: Array[AudioStreamPlayer] = []      # dois para trocar de nota com fade cruzado
var _drone_ativo := 0
var _vento: AudioStreamPlayer
var _thread: Thread
var _rng := RandomNumberGenerator.new()

var _raiz := 0                     # semitons em relação ao Lá
var _escala: Array = ESCALAS["frigio"]
var _batida := 0.0                 # tempo até a próxima colcheia
var _passo := 0                    # contador de colcheias
var _melodia := 7                  # grau atual da caixinha (passeio aleatório)
var _silencio := 0.0               # depois de um susto, quase tudo para por um tempo
var _susto_t := -1.0               # contagem do prato ao contrário até o grito
var _proximo_susto := 90.0
# músicas compostas
var noite := false                 # ligado pelo main.gd
var faixa := ""                    # faixa tocando agora ("" = só a procedural)
var _eventos: Array = []
var _ev_i := 0
var _faixa_t := 0.0
var _espera_faixa := 4.0           # tempo até a próxima faixa
var _ultima_faixa := ""
var _fila_menu: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_criar_barramento()
	for i in N_VOZES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_vozes.append(p)
	for i in 2:
		var d := AudioStreamPlayer.new()
		d.bus = BUS
		d.volume_db = -80.0
		add_child(d)
		_drone.append(d)
	_vento = AudioStreamPlayer.new()
	_vento.bus = BUS
	add_child(_vento)
	_thread = Thread.new()
	_thread.start(_gerar)

func _gerar() -> void:
	var r := Instrumentos.gerar_todos()
	call_deferred("_gerado", r)

func _gerado(r: Dictionary) -> void:
	_thread.wait_to_finish()
	_amostras = r
	pronto = true
	for d in _drone:
		d.stream = _amostras["drone"]
	_vento.stream = _amostras["vento"]
	_vento.volume_db = VOL["vento"]
	_vento.play()
	_drone[0].volume_db = VOL["drone"]
	_drone[0].play()
	_nova_secao()

func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()

func _criar_barramento() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "Master")
	var rev := AudioEffectReverb.new()             # salão grande e escuro
	rev.room_size = 0.85
	rev.damping = 0.6
	rev.spread = 0.9
	rev.wet = 0.38
	rev.dry = 0.8
	AudioServer.add_bus_effect(i, rev)
	var lp := AudioEffectLowPassFilter.new()        # abafa nos momentos calmos (abre com a tensão)
	lp.cutoff_hz = 2500.0
	AudioServer.add_bus_effect(i, lp)

# ---------- controle pelo jogo ----------
func definir_modo(m: String) -> void:
	modo = m
	base_tensao = 0.12 if m == "menu" else 0.22
	_alvo_extra = 0.0
	parar_faixa()
	_espera_faixa = 3.0 if m == "menu" else _rng.randf_range(25.0, 50.0)
	_nova_secao()

# toca uma música composta inteira (ids em audio/faixas.gd)
func tocar_faixa(id: String) -> void:
	if not Faixas.FAIXAS.has(id):
		return
	faixa = id
	_ultima_faixa = id
	_eventos = Faixas.eventos(id)
	_ev_i = 0
	_faixa_t = 0.0
	if pronto:
		var tw := create_tween()                     # o zumbido procedural sai (está em outro tom)
		tw.tween_property(_drone[_drone_ativo], "volume_db", -40.0, 3.0)

func parar_faixa() -> void:
	if faixa == "":
		return
	faixa = ""
	_eventos.clear()
	_espera_faixa = _rng.randf_range(20.0, 40.0) if modo == "menu" else _rng.randf_range(ESPERA_FAIXA.x, ESPERA_FAIXA.y)
	if pronto:
		var tw := create_tween()
		tw.tween_property(_drone[_drone_ativo], "volume_db", VOL["drone"], 5.0)

func _escolher_faixa() -> String:
	if modo == "menu":
		if _fila_menu.is_empty():
			_fila_menu = ["nova_york", "chuva", "abrigo", "noite"]
			if _ultima_faixa != "":
				_fila_menu.erase(_ultima_faixa)
				_fila_menu.shuffle()
				_fila_menu.append(_ultima_faixa)
		return _fila_menu.pop_front()
	if tensao > 0.6:
		return "correria"
	if noite:
		return "noite"
	var op: Array = ["nova_york", "chuva", "abrigo"]
	op.erase(_ultima_faixa)
	return op[_rng.randi() % op.size()]

func _tocar_eventos(dt: float) -> void:
	_faixa_t += dt
	while _ev_i < _eventos.size() and _eventos[_ev_i][0] <= _faixa_t:
		var e: Array = _eventos[_ev_i]
		_ev_i += 1
		if e[1] == "fim":
			parar_faixa()
			return
		_tocar(e[1], e[2], e[3])

func adicionar_tensao(x: float) -> void:
	_alvo_extra = clampf(_alvo_extra + x, 0.0, 1.0)

func susto() -> void:
	if pronto and _susto_t < 0.0 and _silencio <= 0.0:
		_tocar("reverso", 0.0, 0.0)
		_susto_t = _amostras["reverso"].get_length() - 0.05

# ---------- composição ----------
func _nova_secao() -> void:
	_raiz = wrapi(_raiz + MUDANCAS[_rng.randi() % MUDANCAS.size()], -6, 7)
	var nomes := ESCALAS.keys()
	if tensao > 0.6:
		_escala = ESCALAS[["diminuta", "locrio", "tons_inteiros"][_rng.randi() % 3]]
	else:
		_escala = ESCALAS[nomes[_rng.randi() % nomes.size()]]
	if pronto:
		_trocar_drone()

func _trocar_drone() -> void:
	var antigo := _drone[_drone_ativo]
	_drone_ativo = 1 - _drone_ativo
	var novo := _drone[_drone_ativo]
	novo.pitch_scale = pow(2.0, _raiz / 12.0)
	novo.volume_db = -60.0
	novo.play(_rng.randf() * 3.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(novo, "volume_db", VOL["drone"], 4.0)
	tw.tween_property(antigo, "volume_db", -60.0, 4.0)
	tw.chain().tween_callback(antigo.stop)

# grau da escala -> semitons (graus podem passar de uma oitava)
func _grau(g: int) -> int:
	var n := _escala.size()
	return _escala[posmod(g, n)] + 12 * floori(float(g) / n) + _raiz

# toca uma amostra numa nota (semitons acima do Lá 55 Hz) com volume extra
func _tocar(nome: String, semitons: float, extra_db: float, desliza := 0.0) -> void:
	if not _amostras.has(nome):
		return
	var p := _vozes[_vi]
	_vi = (_vi + 1) % _vozes.size()
	p.stream = _amostras[nome]
	var base: float = Instrumentos.BASE[nome]
	var f := LA * pow(2.0, semitons / 12.0)
	p.pitch_scale = clampf(f / base, 0.125, 8.0) if base > 1.0 else 1.0
	p.volume_db = VOL[nome] + extra_db
	p.play()
	if desliza != 0.0:
		var tw := create_tween()
		tw.tween_property(p, "pitch_scale", p.pitch_scale * pow(2.0, desliza / 12.0), 2.5)

func _process(dt: float) -> void:
	if not pronto:
		return
	# tensão: piso do modo + o que veio do jogo, suavizada
	_alvo_extra = maxf(0.0, _alvo_extra - dt * 0.035)
	var alvo := clampf(base_tensao + _alvo_extra, 0.0, 1.0)
	tensao += (alvo - tensao) * minf(1.0, dt * (0.5 if alvo > tensao else 0.15))
	var lp := AudioServer.get_bus_effect(AudioServer.get_bus_index(BUS), 1) as AudioEffectLowPassFilter
	if lp != null:
		lp.cutoff_hz = lerpf(1800.0, 9000.0, tensao)
	_vento.volume_db = VOL["vento"] + lerpf(0.0, -6.0, tensao)
	if _silencio > 0.0:
		_silencio -= dt
	# susto: prato ao contrário termina -> grito + tambor -> silêncio
	if _susto_t >= 0.0:
		_susto_t -= dt
		if _susto_t < 0.0:
			_tocar("grito", 12.0 + _grau(0) % 12, 0.0, 12.0)
			_tocar("tambor", 0.0, 2.0)
			_tocar("sino", _grau(0) - 24 + 12, -2.0)
			_silencio = 6.0
	# sustos de vez em quando no jogo (mais frequentes com tensão alta)
	if modo == "jogo":
		_proximo_susto -= dt * (0.5 + tensao)
		if _proximo_susto <= 0.0:
			_proximo_susto = _rng.randf_range(70.0, 160.0)
			susto()
	# músicas compostas: na hora certa entra uma; a Correria entra assim que a tensão sobe
	if faixa != "":
		_tocar_eventos(dt)
		if faixa != "correria" and modo == "jogo" and tensao > 0.7:
			parar_faixa()
			tocar_faixa("correria")
		return
	_espera_faixa -= dt
	if modo == "jogo" and tensao > 0.7 and _ultima_faixa != "correria":
		_espera_faixa = 0.0
	if _espera_faixa <= 0.0 and _susto_t < 0.0:
		tocar_faixa(_escolher_faixa())
		return
	# relógio: colcheias, andamento sobe com a tensão (48 a 96 bpm)
	var bpm := lerpf(48.0, 96.0, tensao)
	_batida -= dt
	if _batida <= 0.0:
		_batida += 30.0 / bpm
		_colcheia()

func _chance(p: float) -> bool:
	return _rng.randf() < p

func _colcheia() -> void:
	var s := _passo
	_passo += 1
	var tempo_forte := s % 2 == 0
	var compasso := s % 8 == 0
	var t := tensao
	var calmo := _silencio > 0.0
	if s % 64 == 63:
		_nova_secao()
	if calmo:
		if compasso and _chance(0.2):
			_tocar("caixinha", _grau(_melodia) + 24, -6.0)
		return
	# --- caixinha de música: melodia esparsa (some quando a tensão sobe) ---
	if tempo_forte and _chance(0.32 * (1.0 - t * 0.8)):
		_melodia = clampi(_melodia + [-2, -1, -1, 1, 1, 2, 3][_rng.randi() % 7], 0, 14)
		_tocar("caixinha", _grau(_melodia) + 12, _rng.randf_range(-4.0, 0.0))
	# --- piano velho: notas graves soltas e díades dissonantes ---
	if compasso and _chance(0.35):
		var g := _rng.randi() % 7
		_tocar("piano", _grau(g) + 12, -2.0)
		if _chance(0.4 + t * 0.4):
			_tocar("piano", _grau(g) + 13, -6.0)       # meio tom acima: choque
	# --- sino distante ---
	if s % 32 == 0 and _chance(0.6):
		_tocar("sino", _grau(0) + 12, -3.0 + t * 3.0)
	# --- cordas: cluster lento (nota central + 2ª menor ou trítono) ---
	if t > 0.25 and s % 16 == 0 and _chance(0.75):
		_tocar("cordas", _grau(0) + 12, -2.0)
		_tocar("cordas", _grau(0) + 13 if _chance(0.5) else _grau(0) + 18, -5.0)
		if t > 0.5:
			_tocar("cordas", _grau(4) + 24, -6.0, -1.0 if _chance(0.5) else 0.0)
	# --- coro sombrio ---
	if t > 0.3 and t < 0.85 and s % 32 == 8 and _chance(0.6):
		_tocar("coro", _grau(0) + 24, 0.0)
		_tocar("coro", _grau(2) + 24, -4.0)
	# --- coração: uma batida por tempo (acelera junto com o andamento) ---
	if t > 0.32 and tempo_forte:
		_tocar("coracao", 0.0, lerpf(-14.0, 0.0, (t - 0.32) / 0.68))
	# --- violinos em tremolo ---
	if t > 0.55 and s % 8 == 4 and _chance(0.5):
		_tocar("tremolo", _grau(_rng.randi() % 5) + 36, lerpf(-6.0, 0.0, t))
	# --- baixo pulsante em colcheias (nota central e 2ª menor) ---
	if t > 0.6:
		var nota := _grau(0) if s % 8 != 6 else _grau(0) + 1
		_tocar("baixo", nota, lerpf(-8.0, 0.0, (t - 0.6) / 0.4) + (0.0 if tempo_forte else -4.0))
	# --- tambor grave no começo do compasso ---
	if t > 0.72 and compasso:
		_tocar("tambor", 0.0, lerpf(-6.0, 0.0, t))
