extends Node
# DIRETOR DE IA (1.00 · como o "AI Director" do Left 4 Dead, estudos/ESTUDO_AAA.md 2.1): cuida do RITMO, não da
# dificuldade. Mede a INTENSIDADE de cada jogador e alterna tensão e alívio, para nunca ser luta o tempo todo nem
# calmaria demais. Criado por inimigos/vagos.gd junto com a horda (só no jogo solo e no HOST do multijogador).
#   · INTENSIDADE (0 a 1, de cada jogador): sobe quando ele leva mordida (pelo dano), quando é puxado para o chão e
#     quando um infectado morre perto dele (quanto mais perto, mais sobe). Cai sozinha com o tempo, MAS NÃO CAI
#     enquanto tem infectado caçando ele por perto. Vale a do jogador mais tenso da partida.
#   · FASES:
#       CRESCENDO  população normal; de tempos em tempos manda uma HORDA atrás de você.
#       PICO       a intensidade passou de PICO: continua igual por PICO_DURA s.
#       ESFRIANDO  nada novo nasce perto (só a mais de LONGE_ALIVIO m) e não vem horda: a luta de agora acaba sozinha.
#       ALÍVIO     ALIVIO_DURA s com a cidade calma (menos infectados de verdade, nada novo perto, sem horda e sem
#                  tiros/alarmes ao longe). Acaba antes se você andar ALIVIO_ANDOU m. Depois, volta ao crescendo.
#   · HORDA DO DIRETOR (só no crescendo e com você "exposto": fora da base, de prédio, de local fechado, da zona
#     neutra do hospital, de carro e da água): de HORDA_S em HORDA_S s junta os grupos da população que estão de
#     HORDA_DIST m, na maioria (HORDA_DE_TRAS) ATRÁS de você, e eles vêm na sua direção, seguindo você por
#     HORDA_SEGUE s. Se não tem gente bastante ali, nasce um grupo novo onde você não vê. Começa com HORDA_TAM.x e
#     cresce a cada horda (até HORDA_TAM.y). Você ouve os gemidos chegando, do lado de onde vêm.
# A opção Opções › Infectados › Ritmo (z_ritmo) desliga o Diretor ou muda a frequência das hordas.
# "motivo" guarda a frase da última troca de fase (para depurar, como as "ações" do L4D).
# Mexa AQUI para: quanto cada coisa aumenta a intensidade, o pico, quanto dura cada fase, as hordas.

const Regras := preload("res://inimigos/regras_infectados.gd")
const Locais := preload("res://mundo/locais.gd")
const Hospitais := preload("res://npc/hospitais.gd")
const SonsBaixados := preload("res://audio/sons_baixados.gd")

const CRESCENDO := 0
const PICO := 1
const ESFRIANDO := 2
const ALIVIO := 3
const NOMES := ["crescendo", "pico", "esfriando", "alívio"]

# ----- intensidade -----
const DANO_X := 2.5                   # mordida de 10 de dano = +0,25
const DERRUBADO_X := 1.0              # puxado para o chão = pico na hora
const MORTE_RAIO := 15.0              # infectado morrendo até essa distância de você ...
const MORTE_X := 0.12                 # ... sobe até isso (colado em você)
const ATAQUE_PERTO := 25.0            # infectado caçando você a menos disso = a intensidade não cai
const ESPERA_CAIR := 2.0              # s depois do último ataque perto até começar a cair
const CAI := 0.05                     # por segundo

# ----- fases -----
const LIMIAR_PICO := 0.85
const PICO_DURA := Vector2(3.0, 5.0)
const FIM_ESFRIAR := 0.35             # esfriando: abaixo disso (e ninguém caçando perto) vira alívio
const ALIVIO_DURA := Vector2(30.0, 45.0)
const ALIVIO_ANDOU := 150.0
const LONGE_ALIVIO := 60.0            # esfriando/alívio: infectado novo só nasce mais longe que isso
const TETO_ALIVIO := 0.6              # esfriando/alívio: no máximo 60% dos infectados de verdade

# ----- hordas -----
const HORDA_S := Vector2(120.0, 240.0)        # s entre uma horda e outra (Ritmo normal, dificuldade normal)
const HORDA_PRIMEIRA := 90.0                  # a primeira não vem antes disso (mais o sorteio)
const HORDA_TAM := Vector2i(6, 20)            # infectados: a 1ª tem 6, cada horda +2, até 20
const HORDA_CRESCE := 2
const HORDA_DE_TRAS := 0.75
const HORDA_CONE := 70.0                      # graus para cada lado da direção escolhida
const HORDA_DIST := Vector2(100.0, 230.0)     # de onde saem os grupos (fora do alcance de virar "de verdade")
const HORDA_VEL := 1.2                        # m/s dos grupos virtuais vindo
const HORDA_SEGUE := 75.0                     # s seguindo você
const HORDA_A_CADA := 4.0                     # s entre uma correção do caminho e outra
const HORDA_ERRO := 5.0                       # m de erro (não sabem o ponto exato)
const MULT_RITMO := [0.0, 1.8, 1.0, 0.6]      # Ritmo: desligado · calmo · normal · intenso
const MULT_DIFICULDADE := [1.4, 1.0, 0.75]    # fácil · normal · difícil

var gerente: Node = null              # inimigos/vagos.gd
var fase := CRESCENDO
var motivo := "começou"
var hordas := 0                       # quantas hordas o Diretor já mandou
var intensidades := {}                # id do jogador -> 0..1
var _calmo := {}                      # id do jogador -> s desde o último ataque perto
var _t_fase := 0.0                    # pico/alívio: quanto falta
var _alivio_de := Vector3.INF         # onde o alívio começou (andou bastante = acaba antes)
var _t_horda := -1.0                  # s até a próxima horda (conta só no crescendo e com alguém exposto)
var _horda_alvo: Node3D = null
var _horda_t := 0.0                   # > 0 = a horda está seguindo alguém
var _t_seguir := 0.0
var membros: Array = []               # infectados de verdade da horda do Diretor
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

static func ritmo() -> int:
	return clampi(int(Regras.valor("z_ritmo", 2)), 0, 3)

func ligado() -> bool:
	return ritmo() > 0

func intensidade() -> float:
	var m := 0.0
	for k in intensidades:
		m = maxf(m, float(intensidades[k]))
	return m

func nome_fase() -> String:
	return NOMES[fase]

func estado_texto() -> String:
	return "%s · intensidade %.2f · horda em %ds · %s" % [nome_fase(), intensidade(), int(maxf(_t_horda, 0.0)), motivo]

# ---------- o que aconteceu (chamado por vagos.gd) ----------
func ferido(quem, dano: float) -> void:
	_somar(quem, dano / 100.0 * DANO_X)

func derrubado(quem) -> void:
	_somar(quem, DERRUBADO_X)

func morte_perto(p: Vector3) -> void:
	for c in _jogadores():
		var d := Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length()
		if d < MORTE_RAIO:
			_somar(c, MORTE_X * (1.0 - d / MORTE_RAIO))

func _somar(quem, x: float) -> void:
	if quem == null or not is_instance_valid(quem) or not ligado():
		return
	var id: int = (quem as Object).get_instance_id()
	intensidades[id] = clampf(float(intensidades.get(id, 0.0)) + x, 0.0, 1.0)
	_calmo[id] = 0.0

# ---------- o que o resto do jogo pergunta ----------
# quantos infectados de verdade podem existir agora (o limite do aparelho no crescendo; menos no alívio)
func teto_reais(maximo: int) -> int:
	if fase == ESFRIANDO or fase == ALIVIO:
		return int(ceil(maximo * TETO_ALIVIO))
	return maximo

# infectado novo da população não nasce mais perto que isso de alguém
func dist_min_nascer() -> float:
	return LONGE_ALIVIO if fase == ESFRIANDO or fase == ALIVIO else 0.0

# tiros e alarmes ao longe (horda.gd) só fora do alívio
func pode_evento() -> bool:
	return fase == CRESCENDO or fase == PICO

# ---------- quadro a quadro (chamado por vagos.gd) ----------
func processar(dt: float) -> void:
	if not ligado():
		fase = CRESCENDO
		intensidades.clear()
		_parar_horda()
		return
	var js := _jogadores()
	_cair(dt, js)
	_fases(dt, js)
	_hordas(dt, js)

func _jogadores() -> Array:
	var l: Array = []
	if not bool(gerente.get("sem_jogador")) and gerente.jogador != null and is_instance_valid(gerente.jogador):
		l.append(gerente.jogador)
	for r in gerente.remotos():
		if is_instance_valid(r) and r.visible:
			l.append(r)
	return l

# a intensidade cai sozinha, menos enquanto tem infectado caçando o jogador por perto
func _cair(dt: float, js: Array) -> void:
	var atacados := {}
	for v in gerente.vivos:
		if not is_instance_valid(v) or not v.esta_cacando():
			continue
		var a = v.get("_alvo")
		if a == null or not is_instance_valid(a):
			continue
		if v.global_position.distance_squared_to(a.global_position) < ATAQUE_PERTO * ATAQUE_PERTO:
			atacados[(a as Object).get_instance_id()] = true
	var vistos := {}
	for c in js:
		var id: int = (c as Object).get_instance_id()
		vistos[id] = true
		if atacados.has(id):
			_calmo[id] = 0.0
			continue
		_calmo[id] = float(_calmo.get(id, 99.0)) + dt
		if float(_calmo[id]) > ESPERA_CAIR:
			intensidades[id] = maxf(0.0, float(intensidades.get(id, 0.0)) - CAI * dt)
	for id in intensidades.keys():
		if not vistos.has(id):
			intensidades.erase(id)           # saiu da partida
			_calmo.erase(id)
	_atacado_agora = not atacados.is_empty()

var _atacado_agora := false

func _mudar(f: int, porque: String) -> void:
	fase = f
	motivo = porque
	if f == PICO:
		_t_fase = _rng.randf_range(PICO_DURA.x, PICO_DURA.y)
	elif f == ALIVIO:
		_t_fase = _rng.randf_range(ALIVIO_DURA.x, ALIVIO_DURA.y)
		_alivio_de = _pos_principal()

func _fases(dt: float, _js: Array) -> void:
	var i := intensidade()
	match fase:
		CRESCENDO:
			if i >= LIMIAR_PICO:
				_mudar(PICO, "intensidade %.2f passou do pico" % i)
		PICO:
			_t_fase -= dt
			if _t_fase <= 0.0:
				_mudar(ESFRIANDO, "o pico durou o bastante")
		ESFRIANDO:
			if i < FIM_ESFRIAR and not _atacado_agora:
				_mudar(ALIVIO, "a luta acabou (intensidade %.2f)" % i)
		ALIVIO:
			_t_fase -= dt
			var p := _pos_principal()
			if _t_fase <= 0.0:
				_mudar(CRESCENDO, "o alívio acabou")
			elif _alivio_de != Vector3.INF and p != Vector3.INF and Vector2(p.x - _alivio_de.x, p.z - _alivio_de.z).length() > ALIVIO_ANDOU:
				_mudar(CRESCENDO, "andou %d m no alívio" % int(ALIVIO_ANDOU))

func _pos_principal() -> Vector3:
	var js := _jogadores()
	return (js[0] as Node3D).global_position if not js.is_empty() else Vector3.INF

# ---------- hordas ----------
func intervalo_horda() -> Vector2:
	var dif := 1
	var cfg := get_node_or_null("/root/Config")
	if cfg != null:
		dif = clampi(int(cfg.call("valor", "dif")), 0, 2)
	return HORDA_S * float(MULT_RITMO[ritmo()]) * float(MULT_DIFICULDADE[dif])

func tamanho_horda() -> int:
	var n := float(HORDA_TAM.x + HORDA_CRESCE * hordas) * float(gerente.mult_populacao())
	return clampi(int(round(n)), 3, HORDA_TAM.y)

func _hordas(dt: float, js: Array) -> void:
	if _horda_t > 0.0:
		_horda_t -= dt
		if _horda_t <= 0.0 or _horda_alvo == null or not is_instance_valid(_horda_alvo) or _horda_alvo.get("morto") == true:
			_parar_horda()
		else:
			_t_seguir -= dt
			if _t_seguir <= 0.0:
				_t_seguir = HORDA_A_CADA
				_seguir()
	if gerente.horda == null:
		return
	if _t_horda < 0.0:
		var iv := intervalo_horda()
		_t_horda = HORDA_PRIMEIRA + _rng.randf_range(iv.x, iv.y) * 0.5
	if fase != CRESCENDO or _horda_t > 0.0:
		return
	var expostos: Array = []
	for c in js:
		if exposto(c):
			expostos.append(c)
	if expostos.is_empty():
		return                                  # todo mundo abrigado: o relógio da horda para
	_t_horda -= dt
	if _t_horda > 0.0:
		return
	var alvo: Node3D = expostos[_rng.randi() % expostos.size()]
	if soltar_horda(alvo):
		var iv := intervalo_horda()
		_t_horda = _rng.randf_range(iv.x, iv.y)
	else:
		_t_horda = 20.0                         # não deu (sem lugar): tenta de novo daqui a pouco

# o jogador está "na rua" (a horda pode vir)?
func exposto(c: Node3D) -> bool:
	if c == null or not is_instance_valid(c) or c.get("morto") == true or gerente.ignorado(c):
		return false
	if c.get("veiculo") != null or c.get("nadando") == true:
		return false
	var p := c.global_position
	var m = gerente.mundo
	if m != null and m.has_method("dentro_de_predio") and m.dentro_de_predio(p.x, p.z, 0.3, true):     # (com os abertos: é neles que se entra)
		return false
	if Locais.em_construcao(Vector2(p.x, p.z), 0.5):
		return false
	var cons = gerente.get("construcao")
	if cons != null and cons.dentro(p.x, p.z, 4.0):
		return false
	if Hospitais.zona(Vector2(p.x, p.z), Hospitais.MARGEM) >= 0:
		return false
	return true

# para onde o jogador está olhando (no chão)
func _frente(c: Node3D) -> Vector2:
	if c == gerente.jogador and c.get("cam_yaw") != null:
		var y := float(c.cam_yaw)
		return Vector2(-sin(y), -cos(y))
	var f := -c.global_basis.z
	var v := Vector2(f.x, f.z)
	return v.normalized() if v.length_squared() > 0.0001 else Vector2(0, -1)

# junta os grupos da população atrás do jogador e manda vir; devolve false se não deu
func soltar_horda(alvo: Node3D, de_tras := -1) -> bool:
	var h = gerente.horda
	if h == null or alvo == null or not is_instance_valid(alvo):
		return false
	var pa := alvo.global_position
	var p2 := Vector2(pa.x, pa.z)
	var tras := (_rng.randf() < HORDA_DE_TRAS) if de_tras < 0 else (de_tras == 1)
	var frente := _frente(alvo)
	var dir := -frente if tras else frente.rotated(_rng.randf_range(-PI * 0.5, PI * 0.5))
	var cone := cos(deg_to_rad(HORDA_CONE))
	var tam := tamanho_horda()
	var cand: Array = []
	for g in h.grupos:
		if g.has("diretor"):
			continue
		var off: Vector2 = (g["p"] as Vector2) - p2
		var L := off.length()
		if L < HORDA_DIST.x or L > HORDA_DIST.y or off.dot(dir) < cone * L:
			continue
		cand.append([L, g])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var juntos := 0
	for x in cand:
		if juntos >= tam:
			break
		var g: Dictionary = x[1]
		var falta := tam - juntos
		if int(g["n"]) > falta + 2:
			# grupo grande: só uma parte vem
			g["n"] = int(g["n"]) - falta
			var novo := {"p": g["p"], "n": falta, "d": Vector2.INF, "v": HORDA_VEL, "t": 0.0, "diretor": true}
			h.grupos.append(novo)
			juntos += falta
		else:
			g["diretor"] = true
			juntos += int(g["n"])
	var de_onde := dir
	if juntos < tam:
		# pouca gente ali: nasce um grupo novo onde ninguém vê (longe e atrás)
		var meio := p2 + dir * _rng.randf_range(140.0, 190.0)
		var q: Vector2 = h._ponto_livre_em(meio, 30.0)
		if q != Vector2.INF:
			h.grupos.append({"p": q, "n": tam - juntos, "d": Vector2.INF, "v": HORDA_VEL, "t": 0.0, "diretor": true})
			juntos = tam
	if juntos <= 0:
		return false
	hordas += 1
	_horda_alvo = alvo
	_horda_t = HORDA_SEGUE
	_t_seguir = HORDA_A_CADA
	_seguir()
	_anunciar(alvo, de_onde)
	return true

# corrige o caminho de quem é da horda: vão para onde o jogador está agora (com erro)
func _seguir() -> void:
	if _horda_alvo == null or not is_instance_valid(_horda_alvo):
		return
	var pa := _horda_alvo.global_position
	for g in gerente.horda.grupos:
		if g.has("diretor"):
			g["d"] = Vector2(pa.x, pa.z) + Vector2(_rng.randf_range(-HORDA_ERRO, HORDA_ERRO), _rng.randf_range(-HORDA_ERRO, HORDA_ERRO))
			g["v"] = HORDA_VEL
			g.erase("juntar")
	for i in range(membros.size() - 1, -1, -1):
		var v = membros[i]
		if not is_instance_valid(v) or int(v.estado) == 4:
			membros.remove_at(i)
			continue
		if not v.esta_cacando():
			v.investigar(pa + Vector3(_rng.randf_range(-HORDA_ERRO, HORDA_ERRO), 0.0, _rng.randf_range(-HORDA_ERRO, HORDA_ERRO)))

# um grupo da horda do Diretor virou infectados de verdade (horda.gd)
func novo_membro(v: Node) -> void:
	if v != null and _horda_t > 0.0:
		membros.append(v)

func horda_ativa() -> bool:
	return _horda_t > 0.0

func _parar_horda() -> void:
	_horda_t = 0.0
	_horda_alvo = null
	membros.clear()
	if gerente != null and gerente.horda != null:
		for g in gerente.horda.grupos:
			g.erase("diretor")

# gemidos ao longe, do lado de onde a horda vem (só no aparelho de quem é o alvo; os amigos ouvem os infectados chegando)
func _anunciar(alvo: Node3D, dir: Vector2) -> void:
	var mus := get_node_or_null("/root/Musica")
	if alvo != gerente.jogador or bool(gerente.get("sem_jogador")):
		return
	if mus != null:
		mus.adicionar_tensao(0.25)
	for k in 3:
		var s := AudioStreamPlayer3D.new()
		s.stream = SonsBaixados.sortear("infectados/gemido")
		if s.stream == null:
			s.free()
			return
		var lado := dir.rotated(_rng.randf_range(-0.35, 0.35))
		s.position = alvo.global_position + Vector3(lado.x, 0.0, lado.y) * _rng.randf_range(28.0, 40.0) + Vector3(0, 1.5, 0)
		s.max_distance = 120.0
		s.unit_size = 14.0
		s.volume_db = -4.0
		s.pitch_scale = _rng.randf_range(0.8, 1.0)
		s.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		gerente.add_child(s)
		var t := get_tree().create_timer(0.2 + k * _rng.randf_range(0.6, 1.3))
		t.timeout.connect(s.play)
		s.finished.connect(s.queue_free)
