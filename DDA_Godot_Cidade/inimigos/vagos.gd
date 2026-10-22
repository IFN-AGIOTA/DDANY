extends Node
# VAGOS · gerente dos INFECTADOS (inimigos/vago.gd + modelo inimigos/modelo_infectado.gd).
# Nome: os arquivos ficaram "vago/vagos" (vem do HTML), mas na LORE "Vagos" é a GANGUE de Edy e V;
# no jogo (textos da tela) eles são chamados de INFECTADOS.
# - Mantém até max_ativos Vagos vivos em volta do jogador: nascem a 55-120 m, na rua/calçada ou em terreno
#   aberto (nunca dentro de prédio, carro ou água) e de preferência FORA da visão da câmera.
#   Mais Vagos perto do centro (DOWNTOWN). 15% das vezes vem uma pequena HORDA de 4 a 7 juntos.
#   Nascem aos poucos (um a cada INTERVALO_SURGIR) para não travar o celular.
# - Somem quando ficam a mais de 160 m (vivos e corpos). No máximo MAX_CORPOS corpos no chão (some o mais velho).
# - AUDIÇÃO: tiros (sinal armas.barulho) e os passos do jogador (a cada 0,5 s: correndo 18 m, trote 8 m,
#   andando 4 m, agachado 1,5 m). Quem ouve vai investigar; quem está muito perto já sai correndo atrás.
# - Alguém perseguindo = a música aperta (Musica.adicionar_tensao).
# - ativo = false: some com todos e para de criar (a história usa antes do surto).
# - clima (opcional): objeto com escuridao() -> 0..1; à noite os Vagos enxergam menos.
#
# Uso (main.gd, _criar_jogo):
#   vagos = VagosCls.new(); vagos.name = "Vagos"; jogo.add_child(vagos)
#   vagos.ligar(cidade, mundo, jogador, jogador.armas)
#
# Mexa AQUI para: quantos aparecem (MAX_ATIVOS_PADRAO e a escala pela "Densidade" dos gráficos),
# distâncias de nascer/sumir, chance e tamanho das hordas, alcance do barulho dos passos.
# (velocidade, vida e dano de cada Vago ficam em inimigos/vago.gd)

signal abatido(cabeca: bool)            # um Vago morreu (cabeca = tiro na cabeça)
signal atacou_jogador(dano: float)      # um Vago acertou o jogador (útil para HUD, tremer a tela e testes)

const Locais := preload("res://mundo/locais.gd")
const VagoCls := preload("res://inimigos/vago.gd")

const MAX_ATIVOS_PADRAO := 14
const ESCALA_DIFICULDADE := [0.7, 1.0, 1.35]   # Opções › Dificuldade (fácil, normal, difícil)
const DANO_DIFICULDADE := [0.7, 1.0, 1.3]
const DIST_MIN := 55.0
const DIST_MAX := 120.0
const DIST_SUMIR := 160.0
const MAX_CORPOS := 8
const CHANCE_HORDA := 0.15
const HORDA_MIN := 4
const HORDA_MAX := 7
const INTERVALO_SURGIR := 0.3
const RAIO_CENTRO := 3500.0             # até essa distância do DOWNTOWN aparecem mais Vagos
const FRACAO_LONGE := 0.65              # longe do centro: essa fração de max_ativos
const RUIDO_CORRENDO := 18.0
const RUIDO_TROTE := 8.0
const RUIDO_ANDANDO := 4.0
const RUIDO_AGACHADO := 1.5

var max_ativos := MAX_ATIVOS_PADRAO
var mult_dano := 1.0                    # dificuldade: força das mordidas
var ativo := true:
	set(v):
		ativo = v
		if not v:
			limpar()
var clima = null
var mato = null                        # mundo/mato.gd (agachado no capim alto = quase invisível)
var abates := 0
var cidade = null
var mundo = null
var jogador: Node3D = null
var armas = null
var vivos: Array = []
var corpos: Array = []

var _fila: Array = []                   # [posição, destino do grupo] esperando para nascer
var _t_surgir := 0.0
var _t_ruido := 0.0
var _t_sep := 0.0
var _thread: Thread = null
var _musica: Node = null

# ----- MULTIJOGADOR (rede/sessao_rede.gd) -----
# HOST (rede_host): os infectados de verdade nascem em volta de TODOS os jogadores e caçam qualquer um deles;
#   10 vezes por segundo a sessão manda a posição dos que estão perto de cada amigo (estado_rede).
# CLIENTE (espelho): não cria nem pensa; mostra cópias (vago.gd "remoto") do que o host manda.
var rede_host := false
var sem_jogador := false                # servidor do PC (rede/servidor.gd): o "jogador" daqui não é gente; só os amigos contam
var espelho := false
var sessao: Node = null                 # rede/sessao_rede.gd
var por_id := {}                        # id de rede -> vago
var _prox_id := 1
const TIPOS_REDE := ["comum", "corredor", "pesado", "gritador"]

func ligar(c, m, j, a) -> void:
	cidade = c
	mundo = m
	jogador = j
	armas = a
	if armas != null and armas.has_signal("barulho"):
		armas.barulho.connect(barulho)
	var cfg := get_node_or_null("/root/Config")
	if cfg != null:
		var g: Dictionary = cfg.get("g")
		# quantos infectados: DIFICULDADE (Opções), não mais a densidade gráfica
		var dif := clampi(int(cfg.call("valor", "dif")), 0, 2)
		max_ativos = int(round(MAX_ATIVOS_PADRAO * float(ESCALA_DIFICULDADE[dif])))
		mult_dano = float(DANO_DIFICULDADE[dif])
	_musica = get_node_or_null("/root/Musica")
	if VagoCls.sons.is_empty() and _thread == null:
		_thread = Thread.new()
		_thread.start(_gerar_sons)

func _gerar_sons() -> void:
	var r := VagoCls.sintetizar_sons()
	call_deferred("_sons_prontos", r)

func _sons_prontos(r: Dictionary) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	VagoCls.definir_sons(r)

func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null

# os Vagos voltam a nascer ao carregar: não há o que salvar por enquanto
func salvar() -> Dictionary:
	return {"abates": abates}

func carregar(d: Dictionary) -> void:
	abates = int(d.get("abates", abates))

func limpar() -> void:
	for v in vivos:
		if is_instance_valid(v):
			v.queue_free()
	for v in corpos:
		if is_instance_valid(v):
			v.queue_free()
	vivos.clear()
	corpos.clear()
	_fila.clear()

func escuridao() -> float:
	if clima != null and clima.has_method("escuridao"):
		return clampf(float(clima.escuridao()), 0.0, 1.0)
	return 0.0

# quem este infectado vai caçar: o jogador ou outro jogador da partida (o mais perto, de pé)
func alvo_para(v: Node3D) -> Node3D:
	var p := v.global_position
	var melhor: Node3D = null if sem_jogador else jogador
	var md := INF if sem_jogador else p.distance_squared_to(jogador.global_position)
	for c in remotos():
		if not is_instance_valid(c) or c.morto or not c.visible:
			continue
		var d := p.distance_squared_to(c.global_position)
		if d < md * 0.7:                        # prefere o jogador se estiverem parecidos
			md = d
			melhor = c
	return melhor if melhor != null else jogador

# barulho em qualquer lugar (tiros do jogador; outros sistemas podem chamar também: alarme de carro, etc.)
func barulho(posicao: Vector3, raio: float, do_jogador := true) -> void:
	for v in vivos:
		v.ouvir(posicao, raio, do_jogador)

func _vago_acertou(_v: Node, dano: float) -> void:
	if _v.get("_alvo") == null or _v._alvo == jogador:      # mordida num amigo: o aparelho dele que treme
		atacou_jogador.emit(dano)

func _process(dt: float) -> void:
	if jogador == null or not is_instance_valid(jogador) or mundo == null:
		return
	if espelho:
		_processar_espelho(dt)
		return
	var pj := jogador.global_position
	# vivos longe demais somem
	var lim2 := DIST_SUMIR * DIST_SUMIR
	for i in range(vivos.size() - 1, -1, -1):
		var v = vivos[i]
		if not is_instance_valid(v):
			vivos.remove_at(i)
			continue
		var p: Vector3 = v.global_position
		if _longe_de_todos(p, lim2):
			vivos.remove_at(i)
			por_id.erase(v.id_rede)
			v.queue_free()
	for i in range(corpos.size() - 1, -1, -1):
		var v = corpos[i]
		if not is_instance_valid(v):
			corpos.remove_at(i)
			continue
		var p: Vector3 = v.global_position
		if _longe_de_todos(p, lim2):
			corpos.remove_at(i)
			por_id.erase(v.id_rede)
			v.queue_free()
	# nascer aos poucos (só com ativo = true)
	_t_surgir -= dt
	if ativo and _t_surgir <= 0.0 and not (sem_jogador and _centros().is_empty()):   # servidor vazio: ninguém nasce
		_t_surgir = INTERVALO_SURGIR
		if not _fila.is_empty():
			var f: Array = _fila.pop_front()
			_criar(f[0], f[1])
		else:
			# multijogador: nasce em volta do jogador que está com menos infectados perto
			var centro := _centro_para_nascer()
			if _perto_de(centro) < alvo_ativos_em(centro):
				_planejar(centro)
	# passos do jogador
	_t_ruido -= dt
	if _t_ruido <= 0.0:
		_t_ruido = 0.5
		_ruido_jogador()
		_ruido_remotos()
	# separação (não se amontoarem) e música
	_t_sep -= dt
	if _t_sep <= 0.0:
		_t_sep = 0.1
		_separar()
	if _musica != null:
		for v in vivos:
			if v.esta_cacando():
				_musica.adicionar_tensao(dt * 0.06)
				break

# quantos Vagos vivos queremos agora em volta de pj (mais perto do centro, mais deles)
func alvo_ativos_em(pj: Vector3) -> int:
	var dc: Vector2 = Vector2(pj.x, pj.z) - cidade.DOWNTOWN
	var perto := clampf(1.0 - dc.length() / RAIO_CENTRO, 0.0, 1.0)
	# a cada dia sobrevivido a cidade fica mais perigosa (+8% por dia, até +60%)
	var dia: int = int(clima.dia) if clima != null else 1
	var mais := 1.0 + minf(0.08 * float(dia - 1), 0.6)
	return int(round(max_ativos * lerpf(FRACAO_LONGE, 1.0, perto) * mais))

func _ruido_jogador() -> void:
	if sem_jogador or bool(jogador.get("morto")):
		return
	var vel: float = jogador.get("vel_horizontal")
	if vel < 0.3:
		return
	var raio := RUIDO_ANDANDO
	if bool(jogador.get("agachado")):
		raio = RUIDO_AGACHADO
	elif vel > 5.5:
		raio = RUIDO_CORRENDO
	elif vel > 2.5:
		raio = RUIDO_TROTE
	barulho(jogador.global_position, raio, true)

func _separar() -> void:
	var n := vivos.size()
	for i in n:
		var a = vivos[i]
		var pa: Vector3 = a.global_position
		var sep := Vector3.ZERO
		for k in n:
			if k == i:
				continue
			var pb: Vector3 = vivos[k].global_position
			var dx := pa.x - pb.x
			var dz := pa.z - pb.z
			var d2 := dx * dx + dz * dz
			if d2 < 1.44 and d2 > 0.0001:
				var d := sqrt(d2)
				sep += Vector3(dx / d, 0.0, dz / d) * (1.2 - d) / 1.2
		if sep.length_squared() > 1.0:
			sep = sep.normalized()
		a.separacao = sep * 0.9

# ---------- onde nascer ----------
func _livre(x: float, z: float) -> bool:
	var W: int = cidade.W
	var H: int = cidade.H
	var c := int((x + cidade.WORLD.x) / cidade.CELL)
	var r := int((z + cidade.WORLD.y) / cidade.CELL)
	if c < 0 or r < 0 or c >= W or r >= H:
		return false
	var k := r * W + c
	if cidade.road[k] == 0 and cidade.land[k] == 0:
		return false
	var h: float = mundo.altura(x, z)
	if h < 0.0 or absf(h - 0.2) < 0.01:      # mar ou lago
		return false
	if mundo.dentro_de_predio(x, z, 1.5) or mundo.dentro_de_obstaculo(x, z, 0.6) or Locais.em_construcao(Vector2(x, z), 1.5):
		return false
	return true

func _visivel(p: Vector3) -> bool:
	if sem_jogador:
		return false                           # servidor: não tem câmera de ninguém (nasce em qualquer lugar fora de casa)
	if p.distance_to(jogador.global_position) > DIST_MAX + 40.0:
		return false                           # perto de um amigo: a câmera daqui nem vê
	var cam = jogador.get("camera")
	if cam == null or not (cam is Camera3D):
		return false
	return (cam as Camera3D).is_position_in_frustum(p + Vector3(0, 1.0, 0))

# ---------- multijogador ----------
func remotos() -> Array:
	if not rede_host or sessao == null or not is_instance_valid(sessao):
		return []
	return sessao.remotos.values()

# centros de todos os jogadores (este + os amigos que já apareceram)
func _centros() -> Array:
	var l := [] if sem_jogador else [jogador.global_position]
	for r in remotos():
		if is_instance_valid(r) and r.visible:
			l.append(r.global_position)
	return l

func _longe_de_todos(p: Vector3, lim2: float) -> bool:
	for c in _centros():
		if Vector2(p.x - c.x, p.z - c.z).length_squared() <= lim2:
			return false
	return true

func _perto_de(c: Vector3) -> int:
	var n := 0
	for v in vivos:
		var p: Vector3 = v.global_position
		if Vector2(p.x - c.x, p.z - c.z).length_squared() < DIST_SUMIR * DIST_SUMIR:
			n += 1
	return n + _fila.size()

func _centro_para_nascer() -> Vector3:
	var cs := _centros()
	var melhor: Vector3 = cs[0] if not cs.is_empty() else jogador.global_position
	var falta := alvo_ativos_em(melhor) - _perto_de(melhor)
	for c in _centros():
		var f := alvo_ativos_em(c) - _perto_de(c)
		if f > falta:
			falta = f
			melhor = c
	return melhor

# passos dos amigos (o host não tem o "jogador" deles: usa a velocidade que chega pela rede)
func _ruido_remotos() -> void:
	for r in remotos():
		if not is_instance_valid(r) or not r.visible or r.morto:
			continue
		var vel: float = r.vel_horizontal
		if vel < 0.3:
			continue
		var raio := RUIDO_ANDANDO
		if r.agachado:
			raio = RUIDO_AGACHADO
		elif vel > 5.5:
			raio = RUIDO_CORRENDO
		elif vel > 2.5:
			raio = RUIDO_TROTE
		barulho(r.global_position, raio, true)

# host: um Vago avisa uma animação (a sessão manda para todos)
func rede_ani(v: Node, tipo_ani: String, d: Dictionary) -> void:
	if rede_host and sessao != null and v.id_rede > 0:
		sessao.mandar_ani_infectado(v.id_rede, tipo_ani, d)

# cliente: um tiro/golpe DAQUI acertou uma cópia -> pede o dano ao host
func rede_dano(v: Node, dano: float, forma: int, dir: Vector3, golpe: bool) -> void:
	if espelho and sessao != null and v.id_rede > 0:
		sessao.pedir_dano_infectado(v.id_rede, dano, forma, dir, golpe)

# host: pacote com os infectados perto de "c" -> [id, x, y, z, giro, vel, estado, tipo, aparência] por infectado
func estado_rede(c: Vector3, raio: float) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	var r2 := raio * raio
	for v in vivos:
		if not is_instance_valid(v) or v.id_rede <= 0:
			continue
		var p: Vector3 = v.global_position
		if Vector2(p.x - c.x, p.z - c.z).length_squared() > r2:
			continue
		o.append_array(PackedFloat32Array([v.id_rede, p.x, p.y, p.z, v.rotation.y, v._vel_h, v.estado,
			TIPOS_REDE.find(v.tipo), v.semente_modelo]))
	return o

# cliente: chegou o pacote do host
func receber_estado_rede(d: PackedFloat32Array) -> void:
	for k in range(0, d.size() - 8, 9):
		var id := int(d[k])
		var pos := Vector3(d[k + 1], d[k + 2], d[k + 3])
		var v = por_id.get(id)
		if v == null or not is_instance_valid(v):
			v = VagoCls.new()
			v.gerente = self
			v.remoto = true
			v.id_rede = id
			v.tipo_fixo = TIPOS_REDE[clampi(int(d[k + 7]), 0, TIPOS_REDE.size() - 1)]
			v.semente_modelo = int(d[k + 8])
			v.position = pos
			v.rotation.y = d[k + 4]
			add_child(v)
			v.morreu.connect(_ao_morrer)
			vivos.append(v)
			por_id[id] = v
		if v.estado != VagoCls.MORTO:
			v.receber_rede(pos, d[k + 4], d[k + 5], int(d[k + 6]))

# cliente: o host mandou ataque/golpe/morte de um infectado
func receber_ani_rede(id: int, tipo_ani: String, d: Dictionary) -> void:
	var v = por_id.get(id)
	if v == null or not is_instance_valid(v):
		return
	if tipo_ani == "morrer":
		_matou_eu = int(d.get("por", 0)) == multiplayer.get_unique_id()
	v.ani_rede(tipo_ani, d)

var _matou_eu := false

# cliente: tira as cópias que o host parou de mandar (saíram de perto ou sumiram) e cuida da música
func _processar_espelho(dt: float) -> void:
	var cacando := false
	for i in range(vivos.size() - 1, -1, -1):
		var v = vivos[i]
		if not is_instance_valid(v):
			vivos.remove_at(i)
			continue
		if v.t_sem_rede > 1.5:
			vivos.remove_at(i)
			por_id.erase(v.id_rede)
			v.queue_free()
			continue
		if v.esta_cacando():
			cacando = true
	for i in range(corpos.size() - 1, -1, -1):
		if not is_instance_valid(corpos[i]):
			corpos.remove_at(i)
	if cacando and _musica != null:
		_musica.adicionar_tensao(dt * 0.06)

func _ponto(pj: Vector3) -> Vector3:
	for tentativa in 10:
		var a := randf() * TAU
		var d := randf_range(DIST_MIN, DIST_MAX)
		var p := Vector3(pj.x + cos(a) * d, 0.0, pj.z + sin(a) * d)
		if not _livre(p.x, p.z):
			continue
		p.y = mundo.altura(p.x, p.z)
		# as primeiras tentativas exigem ficar fora da tela; depois aceita na tela se for bem longe
		if _visivel(p) and (tentativa < 6 or d < 85.0):
			continue
		return p
	return Vector3.INF

func _planejar(pj: Vector3) -> void:
	var p := _ponto(pj)
	if p == Vector3.INF:
		return
	var chance := CHANCE_HORDA * (1.8 if escuridao() > 0.6 else 1.0)   # de noite vagam em bandos
	if randf() < chance:
		var n := randi_range(HORDA_MIN, HORDA_MAX)
		n = mini(n, alvo_ativos_em(p) + 4 - _perto_de(p))
		var a := randf() * TAU
		var destino := p + Vector3(cos(a), 0.0, sin(a)) * randf_range(10.0, 25.0)
		_fila.append([p, destino])
		for i in n - 1:
			for t in 4:
				var q := p + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
				if _livre(q.x, q.z):
					q.y = mundo.altura(q.x, q.z)
					_fila.append([q, destino])
					break
	else:
		_fila.append([p, Vector3.INF])

func _criar(p: Vector3, destino: Vector3) -> void:
	if espelho:
		return            # 0.70: no cliente quem cria é o host (prédio infestado, local, missão e evento chamam aqui)
	var v = VagoCls.new()
	v.gerente = self
	v.position = p + Vector3(0, 0.02, 0)
	v.rotation.y = randf() * TAU
	add_child(v)
	if destino != Vector3.INF:                 # horda: andam juntos para o mesmo lado
		v._destino = destino + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
		v._espera = 0.0
	v.morreu.connect(_ao_morrer)
	vivos.append(v)
	v.id_rede = _prox_id
	por_id[_prox_id] = v
	_prox_id += 1

func _ao_morrer(v: Node, cabeca: bool) -> void:
	vivos.erase(v)
	corpos.append(v)
	# multijogador: o abate conta para quem matou (host: "_quem_bateu" do Vago · cliente: o host diz "por")
	var meu := true
	if espelho:
		meu = _matou_eu
		_matou_eu = false
	elif rede_host:
		meu = int(v._quem_bateu) == 1
	if meu:
		abates += 1
		abatido.emit(cabeca)
	while corpos.size() > MAX_CORPOS:
		var velho = corpos.pop_front()
		if is_instance_valid(velho):
			velho.queue_free()
