extends CharacterBody3D
# VAGO = um INFECTADO (na lore, "Vagos" é a gangue; o nome do arquivo ficou do HTML). Criado e controlado pelo gerente inimigos/vagos.gd (não precisa de cena .tscn).
# Estados (0.65, estilo DayZ, com marcador em cima da cabeça):
#   VAGANDO (anda devagar à toa)
#   -> DESCONFIADO "hm?" (ouviu passos, viu um vulto ou movimento: PARA, vira para lá e fica olhando 1,5–3 s;
#      se continuar vendo/ouvindo, a suspeita sobe até perseguir; se não, vai ver o que era)
#   -> INVESTIGANDO "?" (anda até o lugar e olha em volta) -> PERSEGUINDO "!" (corre atrás do jogador)
#   -> ATACANDO (prepara 0,4 s e golpeia) · MORTO.
# Reage a SOM (passos conforme a velocidade, tiros, tosse, grito do gritador), LUZ (lanterna à noite) e
# MOVIMENTO (parado você é visto bem mais perto; correndo, de mais longe e até de lado, fora do cone).
# 0.80 · PERCEPÇÃO: VISÃO só com LINHA DE VISÃO livre (paredes, móveis e carros pela física; prédios e locais
# fechados de longe pelos dados do mapa: _linha_livre) — atrás da parede ele não vê, nem colado nela. AUDIÇÃO é um
# CÍRCULO do tamanho do barulho; com parede no meio o som sai abafado (círculo x ABAFADO). Ouvir NUNCA diz onde
# você está: ele vai até o lugar do barulho (com erro, maior de longe) e só persegue se te VIR. Perdeu de vista:
# segue a posição exata só por MEMORIA s, depois vai ao último lugar visto/ouvido. Ataca só com a linha livre.
# Sentidos: AUDIÇÃO (o gerente avisa tiros e passos do jogador) e VISÃO (cone de 110° à frente, 38 m de dia,
# ~14 m à noite, menos se o jogador estiver agachado; o raio de visão bate nas paredes = camada 1).
# Fora de vista por ~TEMPO_ESQUECER ele PERDE você: vai até o último lugar onde te viu, olha em volta e volta a vagar.
# Movimento (barato para o celular): anda "por conta" na altura do chão (mundo.altura), batendo e deslizando
# nas plantas dos prédios e nos obstáculos (carros, barreiras) pelos dados do mapa, sem motor de física.
# Só perto do jogador (~20 m) E perto de um prédio/local com interior aberto usa a física de verdade
# (move_and_slide nas paredes/portas/móveis; altura por um raio para baixo). 0.79: PERSEGUINDO alguém a menos de
# ~26 m, sempre com física (não atravessa nada). Sem física, desvia também das construções dos locais especiais
# e dos carros que funcionam.
# Tiros: receber_tiro(dano, ponto, direcao, forma, atirador) igual aos alvos do estande; forma 1 = cabeça (x3).
# Golpes corpo a corpo: receber_golpe(dano, direcao, atacante) (empurra e atordoa um pouco).
# Ataque no jogador: jogador.receber_ataque(dano, chance_sangrar, origem) se o jogador tiver esse método.
# Colisão: camada 3 (valor 4) · máscara 1. Forma 0 = corpo (cápsula) · forma 1 = cabeça (esfera).
# Sons sintetizados por código uma vez só (gemidos, rosnado do ataque, baque) e divididos entre todos.
#
# TIPOS (sorteados ao nascer, TIPOS abaixo): comum · CORREDOR (rápido e frágil) · PESADO (aguenta muito e bate
# forte) · GRITADOR (quando vê você, grita e chama os outros num raio grande).
# À noite, a LANTERNA acesa faz o jogador ser visto de longe (mínimo 30 m).
# Golpe corpo a corpo atordoa conforme a força, e depois de atordoado ele fica ~1 s sem poder ser atordoado
# de novo (não dá para travar um infectado só batendo).
# Mexa AQUI para: velocidade, vida, dano, alcance da visão/ataque, tempo para desistir, chance de loot,
# quanto tempo o corpo fica no chão (constantes logo abaixo) e os TIPOS.

signal morreu(vago: Node, cabeca: bool)

const ModeloCls := preload("res://inimigos/modelo_infectado.gd")   # manequins do Quaternius
const ItemMundo := preload("res://inventario/item_mundo.gd")
const ItemCls := preload("res://inventario/item.gd")
const SonsCorpo := preload("res://audio/sons_corpo.gd")
const SonsBaixados := preload("res://audio/sons_baixados.gd")
const PortaCls := preload("res://mundo/porta.gd")
const DANO_PORTA := 2.2                # 0.73: golpe na porta = mordida x isso (porta 100, tábua 140)

# ----- números do Vago -----
const VIDA := 100.0
const CABECA_X := 3.0                 # tiro na cabeça = dano x3 (igual ao estande)
const VEL_VAGAR_MIN := 0.55           # andando à toa (m/s)
const VEL_VAGAR_MAX := 0.9
const VEL_INVESTIGAR := 1.2
const VEL_CORRER := 5.2               # perseguindo (o jogador correndo faz 7,2)
const DIST_ATAQUE := 1.4
const PREPARO_ATAQUE := 0.4           # tempo entre começar o golpe e acertar
const RECARGA_ATAQUE := 1.3
const DANO_MIN := 8.0
const DANO_MAX := 14.0
const CHANCE_SANGRAR := 0.3
const VISAO_DIA := 38.0
const VISAO_NOITE := 14.0
const ANGULO_VISAO := 110.0           # graus (cone à frente)
const FATOR_AGACHADO := 0.55
const TEMPO_ESQUECER := 8.0           # segundos sem ver o jogador até desistir
const DIST_FISICA := 20.0             # física de verdade só a menos disso do jogador e perto de interior aberto
const DIST_FISICA_CACANDO := 26.0     # 0.79: perseguindo/atacando, física de verdade a menos disso (bate em tudo)
const CHANCE_LOOT := 0.25
const LOOT := ["bandagem", "feijao", "agua", "mun_9mm"]
const VISAO_LANTERNA := 30.0          # de noite, com a lanterna acesa, é visto pelo menos daqui
const IMUNE_ATORDOAR := 1.0           # depois de atordoado por golpe, fica esse tempo sem atordoar de novo
const RAIO_GRITO := 55.0
# tipo: [chance, vida, velocidade (x), dano (x), escala do corpo]
const TIPOS := {
	"comum": [0.65, 100.0, 1.0, 1.0, 1.0],
	"corredor": [0.15, 70.0, 1.22, 0.85, 0.95],
	"pesado": [0.12, 220.0, 0.72, 1.45, 1.12],
	"gritador": [0.08, 90.0, 1.0, 1.0, 1.0],
}
const TEMPO_CORPO := 90.0             # o corpo fica no chão esse tempo e depois afunda
const ALCANCE_SOM := 40.0

const VAGANDO := 0
const INVESTIGANDO := 1
const PERSEGUINDO := 2
const ATACANDO := 3
const MORTO := 4
const DESCONFIADO := 5                 # 0.65: parado, olhando para o que ouviu/viu ("hm?")
const NOMES := ["vagando", "investigando", "perseguindo", "atacando", "morto", "desconfiado"]
const TEMPO_DESCONFIAR := Vector2(1.5, 3.0)
const VISAO_PARADO := 0.6              # jogador parado: visto só a 60% da distância
const VISAO_CORRENDO := 1.25           # correndo: de mais longe
const PERIFERIA_CORRENDO := 9.0        # correndo perto assim, é notado mesmo fora do cone de visão
const RUIDO_INVESTIGAR := 28.0         # barulho deste raio para cima (tiro) faz ir ver direto, sem parar no "hm?"
# 0.80 · PERCEPÇÃO = LINHA DE VISÃO + CÍRCULO DE AUDIÇÃO
const PERTO_SENTIR := 1.6              # mais perto que isso nota você mesmo fora do cone (mas a parede ainda tapa)
const MEMORIA := 0.6                   # depois de perder de vista, ainda segue a posição exata por esse tempo
const ABAFADO := 0.5                   # barulho do outro lado de parede/prédio: o círculo de audição cai a isso
const VISTO_ATAQUE := 0.35             # só ataca quem viu há menos disso (e com a linha livre no golpe)

# sons (gerados uma vez; o gerente chama sintetizar_sons() numa thread e depois definir_sons())
const TAXA_SOM := 16000
static var sons := {}

var gerente: Node = null              # inimigos/vagos.gd (jogador, mundo, clima)
var estado := VAGANDO
var vida := VIDA
var modelo: Node3D
var som: AudioStreamPlayer3D
var separacao := Vector3.ZERO         # empurrão para não se amontoar (o gerente calcula)
var morto_ha := 0.0
var dist_jogador := 999.0
var tipo := "comum"
var _mult_dano := 1.0
var _imune := 0.0
var _gritou := false
var som2: AudioStreamPlayer3D          # segundo canal: o baque do tiro não corta o gemido
var _t_passo := 0.0
var _dt_longe := 0.0
var _q_longe := 0
var _n_passo := 0

var _forma_corpo: CollisionShape3D
var _forma_cabeca: CollisionShape3D
var _fisica := false
var _destino := Vector3.ZERO
var _vel_alvo := 0.0
var _vel_vagar := 0.8
var _vel_correr := VEL_CORRER
var _fator_andar := 1.0                # jeito de andar do modelo (inimigos/modelo_infectado.gd fator_vel)
var _espera := 0.0
var _olhando := false
var _t_sentidos := 0.0
var _t_sem_ver := 99.0
var _ultimo_visto := Vector3.ZERO
var _suspeita := 0.0
var _foco := Vector3.ZERO               # 0.65: para onde ele está olhando desconfiado
var _t_desconfiar := 0.0
var _t_alerta := 0.0                    # mostra o "!" um pouco depois de começar a perseguir
var _marca: Label3D = null              # "hm?" / "?" / "!" em cima da cabeça
var _t_ataque := 0.0
var _golpeou := false
var _recarga := 0.0
var _atordoado := 0.0
var _empurrao := Vector3.ZERO
var _t_grunhido := 3.0
var _t_desvio := 0.0
var _dir_desvio := Vector3.ZERO
var _lado := 1.0
var _contorno := false
var _t_contorno := 0.0
var _dir_contorno := Vector3.ZERO
var _t_preso := 0.5
var _pos_preso := Vector3.ZERO
var _n_preso := 0
var _t_predio := 0.0
var _t_chao := 0.0
var _t_modo := 0.0
var _y_chao := 0.0
var _seco := Vector3.INF               # 0.72: último ponto em terra (não entram na água funda: param na margem)
const Y_AGUA := -0.12                  # 0.72: chão abaixo disso = fundo do mar/lago (mundo/colisao_mundo.gd)
var _vel_xz := Vector3.ZERO
var _vel_h := 0.0
var _quadro := 0
var _dt_anim := 0.0
var _consulta: PhysicsRayQueryParameters3D
var _alvo: Node3D = null              # jogador ou outro jogador da partida (gerente.alvo_para)
# ----- multijogador (inimigos/vagos.gd + rede/sessao_rede.gd) -----
# HOST: o Vago de verdade (IA, vida); avisa os outros de ataque/golpe/morte (gerente.rede_ani).
# CLIENTE: "remoto" = cópia que só segue a posição que o host manda (sem IA); tiros e golpes daqui viram pedido
# de dano para o host (gerente.rede_dano), e a reação aparece na hora.
var remoto := false
var id_rede := 0
var semente_modelo := -1              # aparência (igual em todos os aparelhos)
var tipo_fixo := ""
var _rede_pos := Vector3.ZERO
var _rede_yaw := 0.0
var _rede_vel := 0.0
var _rede_estado := 0
var t_sem_rede := 0.0                 # cliente: tempo sem notícia do host (some se passar de ~1,5 s)
var _quem_bateu := 1                  # host: id de rede de quem deu o último golpe/tiro (1 = o próprio host)

func _ready() -> void:
	add_to_group("pausa_por_chunk")    # fora dos chunks ativos fica pausado (mundo/chunks.gd)
	collision_layer = 4                # camada 3 = inimigos
	collision_mask = 1                 # só o mundo (passa por outros Vagos e pelo jogador)
	# "flutuando": a cápsula não encosta no chão (contato com o mapa de alturas custa caro com muitos Vagos);
	# a altura vem de um raio para baixo 5x por segundo. Bate só em paredes, prédios, carros e móveis.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	max_slides = 3
	# forma 0 = corpo · forma 1 = cabeça (os tiros usam o índice da forma)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.3
	_forma_corpo = CollisionShape3D.new()
	_forma_corpo.shape = cap
	_forma_corpo.position = Vector3(0, 0.88, 0)         # de 0,23 m a 1,53 m do chão
	add_child(_forma_corpo)
	var esf := SphereShape3D.new()
	esf.radius = 0.14
	_forma_cabeca = CollisionShape3D.new()
	_forma_cabeca.shape = esf
	_forma_cabeca.position = Vector3(0, 1.62, 0.0)
	add_child(_forma_cabeca)
	modelo = ModeloCls.new()
	modelo.name = "Modelo"
	add_child(modelo)
	if semente_modelo < 0:
		semente_modelo = randi() % 16000000
	modelo.montar(semente_modelo)
	# tipo de infectado
	if tipo_fixo != "" and TIPOS.has(tipo_fixo):
		tipo = tipo_fixo
	else:
		var x := randf()
		for t in TIPOS:
			x -= float(TIPOS[t][0])
			if x <= 0.0:
				tipo = t
				break
	var td: Array = TIPOS[tipo]
	vida = float(td[1])
	_mult_dano = float(td[3])
	modelo.scale *= float(td[4])
	som = AudioStreamPlayer3D.new()
	som.max_distance = ALCANCE_SOM
	som.unit_size = 5.0
	som.position.y = 1.6
	som.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(som)
	som2 = AudioStreamPlayer3D.new()
	som2.max_distance = ALCANCE_SOM
	som2.unit_size = 5.0
	som2.position.y = 1.2
	som2.bus = som.bus
	add_child(som2)
	_consulta = PhysicsRayQueryParameters3D.new()
	_consulta.collision_mask = 1
	_fator_andar = modelo.fator_vel() if modelo.has_method("fator_vel") else 1.0
	_vel_vagar = randf_range(VEL_VAGAR_MIN, VEL_VAGAR_MAX) * _fator_andar
	_vel_correr = VEL_CORRER * randf_range(0.88, 1.04) * float(TIPOS[tipo][2])
	_vel_vagar *= float(TIPOS[tipo][2])
	_t_grunhido = randf_range(1.0, 10.0)
	_t_sentidos = randf() * 0.25
	_lado = 1.0 if randf() < 0.5 else -1.0
	_y_chao = global_position.y
	_destino = global_position
	_espera = randf_range(0.0, 3.0)
	_rede_pos = global_position
	_rede_yaw = rotation.y

# ---------- multijogador: cópia que segue o host ----------
func receber_rede(pos: Vector3, yaw: float, vel: float, est: int) -> void:
	_rede_pos = pos
	_rede_yaw = yaw
	_rede_vel = vel
	_rede_estado = est
	t_sem_rede = 0.0

# o host mandou uma animação: "atacar", "golpe" (forca, lado) ou "morrer" (cabeça, direção)
func ani_rede(tipo_ani: String, d: Dictionary) -> void:
	match tipo_ani:
		"atacar":
			if estado != MORTO:
				modelo.atacar()
				_tocar("rosnado", randf_range(1.0, 1.25), 1.0)
		"golpe":
			if estado != MORTO:
				modelo.levar_golpe(float(d.get("f", 0.6)), float(d.get("l", 1.0)))
		"morrer":
			if estado != MORTO:
				var dr: Vector3 = d.get("d", Vector3.FORWARD)
				_morrer(bool(d.get("c", false)), dr)

func _seguir_rede(dt: float) -> void:
	t_sem_rede += dt
	var p := global_position
	if p.distance_squared_to(_rede_pos) > 64.0:
		global_position = _rede_pos                     # muito longe (pulou): vai direto
	else:
		global_position = p.lerp(_rede_pos, minf(1.0, dt * 10.0))
	rotation.y = lerp_angle(rotation.y, _rede_yaw, minf(1.0, dt * 10.0))
	_vel_h = _rede_vel
	estado = _rede_estado if _rede_estado != MORTO else estado
	var j = gerente.jogador if gerente != null else null
	if j != null and is_instance_valid(j):
		var pj: Vector3 = j.global_position
		dist_jogador = Vector2(pj.x - p.x, pj.z - p.z).length()
	_t_grunhido -= dt
	if _t_grunhido <= 0.0:
		_t_grunhido = randf_range(2.0, 5.0) if esta_cacando() else randf_range(4.0, 12.0)
		if dist_jogador < ALCANCE_SOM + 5.0:
			_tocar("gemido%d" % (randi() % 4), randf_range(0.85, 1.15), 0.0)

# ---------- ordens do gerente ----------
# barulho em "pos" com alcance "raio" (do_jogador = foi o jogador que fez: tiro, passos)
func ouvir(pos: Vector3, raio: float, do_jogador: bool) -> void:
	if estado == MORTO or remoto:          # cópia: quem ouve é o Vago do host
		return
	var d := global_position.distance_to(pos)
	if d > raio:
		return
	# 0.80 · CÍRCULO DE AUDIÇÃO: com parede/prédio no meio o som chega abafado (círculo menor)
	if not _linha_livre(global_position + Vector3(0, 1.55, 0), pos + Vector3(0, 1.0, 0)):
		if d > raio * ABAFADO:
			return
	var erro := minf(d * 0.12, 8.0)                  # de longe ele só sabe mais ou menos de onde veio
	var onde := pos + Vector3(randf_range(-erro, erro), 0.0, randf_range(-erro, erro))
	if estado == PERSEGUINDO or estado == ATACANDO:
		# já está atrás de alguém que sumiu de vista: o barulho mostra para onde ir (não a posição exata agora)
		if do_jogador and _t_sem_ver >= MEMORIA:
			_ultimo_visto = onde
			_t_sem_ver = clampf(_t_sem_ver, MEMORIA + 0.01, TEMPO_ESQUECER * 0.5)
		return
	# ouvir não é ver: vai até o lugar do barulho e só persegue se te VIR lá
	if raio >= RUIDO_INVESTIGAR or estado == INVESTIGANDO or d < 4.0:
		investigar(onde)                                # tiro/grito (ou passos bem perto): vai ver direto
	else:
		desconfiar(onde)                                # passos: para e escuta ("hm?")

# DESCONFIADO (0.65): para, vira para "pos" e escuta/olha um pouco antes de decidir
func desconfiar(pos: Vector3) -> void:
	if estado == MORTO or esta_cacando():
		return
	_foco = pos
	if estado != DESCONFIADO:
		estado = DESCONFIADO
		_t_desconfiar = randf_range(TEMPO_DESCONFIAR.x, TEMPO_DESCONFIAR.y)
		if dist_jogador < ALCANCE_SOM:
			_tocar("gemido%d" % (randi() % 4), randf_range(1.3, 1.45), -3.0)    # "hm?"
	else:
		_t_desconfiar = maxf(_t_desconfiar, 1.0)       # mais um sinal: continua olhando

func investigar(pos: Vector3) -> void:
	if estado == MORTO:
		return
	estado = INVESTIGANDO
	_destino = pos
	_espera = 0.0
	_olhando = false

func perseguir() -> void:
	if estado == MORTO or estado == PERSEGUINDO or estado == ATACANDO:
		return
	estado = PERSEGUINDO
	_suspeita = 1.0
	_t_alerta = 1.6
	if tipo == "gritador" and not _gritou:
		_gritou = true                                  # grita uma vez: os outros num raio grande vêm ver
		_tocar("rosnado", 1.45, 6.0)
		if gerente != null:
			gerente.barulho(global_position, RAIO_GRITO, false)
	elif randf() < 0.7:
		_tocar("rosnado", randf_range(0.85, 1.1), 2.0)
	_t_grunhido = randf_range(2.0, 4.0)

func vagar() -> void:
	if estado == MORTO:
		return
	estado = VAGANDO
	_suspeita = 0.0
	_espera = randf_range(1.0, 4.0)
	_destino = global_position

func esta_cacando() -> bool:
	return estado == PERSEGUINDO or estado == ATACANDO

# ---------- tiros e golpes ----------
func receber_tiro(dano: float, _ponto: Vector3, direcao: Vector3, forma: int, atirador: Node) -> Dictionary:
	if estado == MORTO:
		return {"cabeca": false, "morto": false}
	var cabeca := forma == 1
	var lado := signf(global_basis.x.dot(direcao))
	if remoto:                                          # cópia: a vida é do host
		modelo.levar_golpe(0.9 if cabeca else 0.6, lado)
		_tocar("baque", randf_range(0.9, 1.15), -2.0, true)
		if gerente != null:
			gerente.rede_dano(self, dano, forma, direcao, false)
		return {"cabeca": cabeca, "morto": false}
	_quem_bateu = int(atirador.get("id")) if atirador != null and atirador.get("id") != null else 1
	vida -= dano * (CABECA_X if cabeca else 1.0)
	modelo.levar_golpe(0.9 if cabeca else 0.6, lado)
	_tocar("baque", randf_range(0.9, 1.15), -2.0, true)
	if gerente != null and vida > 0.0:
		gerente.rede_ani(self, "golpe", {"f": 0.9 if cabeca else 0.6, "l": lado})
	if vida <= 0.0:
		_morrer(cabeca, direcao)
		return {"cabeca": cabeca, "morto": true}
	_atordoado = maxf(_atordoado, 0.22)
	_cancelar_ataque()
	_alertar(atirador)
	return {"cabeca": cabeca, "morto": false}

func receber_golpe(dano: float, direcao: Vector3, atacante: Node) -> Dictionary:
	if estado == MORTO:
		return {"cabeca": false, "morto": false}
	if remoto:
		modelo.levar_golpe(1.0, signf(global_basis.x.dot(direcao)))
		_tocar("baque", randf_range(0.75, 0.95), 0.0, true)
		if gerente != null:
			gerente.rede_dano(self, dano, 0, direcao, true)
		return {"cabeca": false, "morto": false}
	_quem_bateu = int(atacante.get("id")) if atacante != null and atacante.get("id") != null else 1
	vida -= dano
	if gerente != null and vida > 0.0:
		gerente.rede_ani(self, "golpe", {"f": 1.0, "l": signf(global_basis.x.dot(direcao))})
	var d := Vector3(direcao.x, 0.0, direcao.z)
	if d.length_squared() > 0.0001:
		_empurrao = d.normalized() * 3.2
	modelo.levar_golpe(1.0, signf(global_basis.x.dot(direcao)))
	_tocar("baque", randf_range(0.75, 0.95), 0.0, true)
	if vida <= 0.0:
		_morrer(false, direcao)
		return {"cabeca": false, "morto": true}
	if _imune <= 0.0:
		_atordoado = maxf(_atordoado, (0.2 + dano / 200.0) * (0.6 if tipo == "pesado" else 1.0))
		_imune = IMUNE_ATORDOAR
		if not (estado == ATACANDO and _t_ataque > 0.25):  # já no meio da mordida: não para
			_cancelar_ataque()
	_alertar(atacante)
	return {"cabeca": false, "morto": false}

func _alertar(quem: Node) -> void:
	if quem == null or not is_instance_valid(quem) or not (quem is Node3D):
		return
	var p: Vector3 = (quem as Node3D).global_position
	if gerente != null and (quem == gerente.jogador or quem.is_in_group("jogadores_remotos")):
		_alvo = quem as Node3D
		_ultimo_visto = p
		_t_sem_ver = 0.0
		perseguir()
	elif not esta_cacando():
		investigar(p)

func _cancelar_ataque() -> void:
	if estado == ATACANDO and not _golpeou:
		estado = PERSEGUINDO
		_recarga = maxf(_recarga, 0.35)

func _morrer(cabeca: bool, direcao: Vector3) -> void:
	estado = MORTO
	vida = 0.0
	velocity = Vector3.ZERO
	_vel_xz = Vector3.ZERO
	_forma_corpo.set_deferred("disabled", true)
	_forma_cabeca.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)
	var frente := -global_basis.z
	modelo.morrer(Vector3(direcao.x, 0.0, direcao.z).dot(frente) <= 0.0)   # tiro de frente: cai de costas
	_tocar("gemido%d" % (randi() % 4), randf_range(0.6, 0.72), 0.0)
	if not remoto:
		if gerente != null:
			gerente.rede_ani(self, "morrer", {"c": cabeca, "d": direcao, "por": _quem_bateu})
		if randf() < CHANCE_LOOT:
			_soltar_loot()
	morreu.emit(self, cabeca)

func _soltar_loot() -> void:
	if gerente == null:
		return
	var pai: Node = gerente.get_parent() if gerente.get_parent() != null else gerente
	var id: String = LOOT[randi() % LOOT.size()]
	var qtd := randi_range(5, 15) if id == "mun_9mm" else 1
	var it = ItemCls.novo(id, qtd)
	if it == null:
		return
	var a := randf() * TAU
	var p := global_position + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.5, 0.9)
	if gerente.mundo != null:
		p.y = gerente.mundo.altura(p.x, p.z)
	ItemMundo.soltar(pai, it, p)

# ---------- animação (só nos quadros desenhados; com nível de detalhe pela distância e pela câmera) ----------
# perto: todo quadro · 25-50 m: a cada 2 · mais longe: a cada 4 · fora da câmera: a cada 8 · > 145 m: nada.
# A esfera da cabeça (tiro na cabeça x3) só acompanha a animação até 70 m (de mais longe ninguém acerta mesmo).
var _cam: Camera3D = null

func _process(dt: float) -> void:
	if estado == MORTO or gerente == null:
		return
	_dt_anim += dt
	_quadro += 1
	if dist_jogador > 145.0:                 # depois de ~140 m o modelo nem aparece
		return
	var a_cada := 1 if dist_jogador < 25.0 else (2 if dist_jogador < 50.0 else 4)
	if dist_jogador > 6.0:
		if _cam == null or not is_instance_valid(_cam):
			_cam = get_viewport().get_camera_3d()
		if _cam != null and not _cam.is_position_in_frustum(global_position + Vector3(0, 1.0, 0)):
			a_cada = 8
	_atualizar_marca(dt)
	if _quadro % a_cada != 0:
		return
	modelo.atualizar(_dt_anim, _vel_h)
	_dt_anim = 0.0
	if dist_jogador < 70.0:
		_forma_cabeca.position = to_local(modelo.pos_cabeca())

# ---------- marcador do estado em cima da cabeça (0.65) ----------
# "hm?" desconfiado · "?" investigando · "!" começou a perseguir. Só perto (até 35 m).
func _atualizar_marca(dt: float) -> void:
	_t_alerta = maxf(0.0, _t_alerta - dt)
	var txt := ""
	if dist_jogador < 35.0:
		match estado:
			DESCONFIADO: txt = "hm?"
			INVESTIGANDO: txt = "?"
			PERSEGUINDO, ATACANDO:
				if _t_alerta > 0.0:
					txt = "!"
	if txt == "":
		if _marca != null:
			_marca.visible = false
		return
	if _marca == null:
		_marca = Label3D.new()
		_marca.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marca.no_depth_test = true
		_marca.fixed_size = true
		_marca.pixel_size = 0.0018
		_marca.font_size = 34
		_marca.outline_size = 10
		_marca.position = Vector3(0, 2.15, 0)
		add_child(_marca)
	_marca.visible = true
	_marca.text = txt
	_marca.modulate = Color(1.0, 0.25, 0.15) if txt == "!" else (Color(1.0, 0.85, 0.3) if txt == "hm?" else Color(1, 1, 1, 0.85))

# ---------- quadro a quadro ----------
func _physics_process(dt: float) -> void:
	if gerente == null or gerente.jogador == null:
		return
	if estado == MORTO:
		_corpo(dt)
		return
	if remoto:
		_seguir_rede(dt)
		return
	if _alvo == null or not is_instance_valid(_alvo):
		_alvo = gerente.alvo_para(self)
	var j: Node3D = _alvo
	var mundo = gerente.mundo
	var p := global_position
	var pj := j.global_position
	dist_jogador = Vector2(pj.x - p.x, pj.z - p.z).length()
	# longe e sem caçar: a lógica roda 1 a cada 4 quadros (com o tempo acumulado) — bem mais leve no celular
	if dist_jogador > 60.0 and estado != PERSEGUINDO and estado != ATACANDO:
		_dt_longe += dt
		_q_longe += 1
		if _q_longe % 4 != 0:
			return
		dt = _dt_longe
	_dt_longe = 0.0
	# física só onde existe chão de física (perto do jogador)
	_t_modo -= dt
	if _t_modo <= 0.0:
		_t_modo = 0.5
		# 0.79: correndo atrás de alguém perto, SEMPRE com física (antes só perto de prédio aberto: atravessava os
		# móveis e paredes dos locais especiais, os carros que funcionam, cercas, grades...)
		var folga := 4.0 if _fisica else 0.0
		# 0.80: dentro de um prédio FECHADO (caixa de colisão inteira) nunca liga a física: ela o empurraria para fora
		# atravessando a parede. Fica "pelos dados" (preso lá dentro) até o prédio abrir (paredes e portas de verdade).
		var quer_fisica: bool = not mundo.dentro_de_predio(p.x, p.z, 0.1) and mundo.tem_chao_fisico(p.x, p.z) and (
			(esta_cacando() and dist_jogador < DIST_FISICA_CACANDO + folga)
			or (dist_jogador < DIST_FISICA + folga and mundo.perto_de_aberto(p.x, p.z, 10.0 if _fisica else 8.0)))
		if quer_fisica != _fisica:
			_trocar_modo(quer_fisica)
	# sentidos: 4-5 vezes por segundo, cada Vago num momento diferente
	_t_sem_ver += dt
	_t_sentidos -= dt
	if _t_sentidos <= 0.0:
		_t_sentidos = randf_range(0.2, 0.26)
		if not esta_cacando() or randf() < 0.15:          # caçando, só às vezes troca de alvo
			var novo: Node3D = gerente.alvo_para(self)
			if novo != _alvo:
				_alvo = novo
				j = novo
		_olhar(j)
	_atordoado = maxf(0.0, _atordoado - dt)
	_imune = maxf(0.0, _imune - dt)
	_recarga = maxf(0.0, _recarga - dt)
	_decidir(dt, j)
	_mover(dt)
	# (a animação roda em _process: só nos quadros que vão para a tela)
	# passos de quem vem correndo (dá para ouvir chegando por trás)
	if _vel_h > 2.0 and dist_jogador < 25.0 and som2 != null:
		_t_passo -= dt
		if _t_passo <= 0.0:
			_t_passo = clampf(1.5 / _vel_h, 0.24, 0.5)
			if not som2.playing:
				_n_passo += 1
				var pg := SonsBaixados.sortear("infectados/passo")
				som2.stream = pg if pg != null else SonsCorpo.passo(_n_passo)
				som2.pitch_scale = randf_range(0.8, 0.95) * (0.85 if tipo == "pesado" else 1.0)
				som2.volume_db = -4.0
				som2.play()
	# gemidos
	_t_grunhido -= dt
	if _t_grunhido <= 0.0:
		_t_grunhido = randf_range(2.0, 5.0) if esta_cacando() else randf_range(4.0, 12.0)
		if dist_jogador < ALCANCE_SOM + 5.0:
			_tocar("gemido%d" % (randi() % 4), randf_range(0.85, 1.15), 0.0)

func _trocar_modo(fisica: bool) -> void:
	_fisica = fisica
	velocity = Vector3(_vel_xz.x, 0.0, _vel_xz.z)
	_y_chao = global_position.y
	_t_chao = 0.0
	_pos_preso = global_position

func _olhar(j: Node3D) -> void:
	if bool(j.get("morto")):
		return
	var cacando := esta_cacando()
	var alcance := lerpf(VISAO_DIA, VISAO_NOITE, gerente.escuridao())
	if bool(j.get("agachado")):
		alcance *= FATOR_AGACHADO
		if j == gerente.jogador and gerente.mato != null and gerente.mato.no_capim:
			alcance *= 0.5                              # escondido no capim alto dos parques
	if j == gerente.jogador and gerente.clima != null and gerente.clima.lanterna_acesa and gerente.escuridao() > 0.5:
		alcance = maxf(alcance, VISAO_LANTERNA)         # a luz da lanterna denuncia de longe
	# 0.65 · MOVIMENTO: parado é difícil de notar; correndo chama atenção de longe
	var vj := float(j.get("vel_horizontal")) if j.get("vel_horizontal") != null else 0.0
	if not cacando:
		if vj < 0.3:
			alcance *= VISAO_PARADO
		elif vj > 5.0:
			alcance *= VISAO_CORRENDO
	if cacando:
		alcance *= 1.35                                 # já está de olho nele
	var visto := false
	if dist_jogador <= alcance:
		var p := global_position
		var pj := j.global_position
		var no_cone := cacando or dist_jogador < PERTO_SENTIR or estado == DESCONFIADO and dist_jogador < alcance * 0.7
		if not no_cone and dist_jogador > 0.01:
			var para := Vector3(pj.x - p.x, 0.0, pj.z - p.z) / dist_jogador
			no_cone = (-global_basis.z).dot(para) >= cos(deg_to_rad(ANGULO_VISAO * 0.5))
		if not no_cone and vj > 5.0 and dist_jogador < PERIFERIA_CORRENDO:
			no_cone = true                              # movimento rápido com o canto do olho
		if no_cone:                                     # 0.80: sempre com a linha de visão livre (nem colado vê através da parede)
			visto = _linha_livre(p + Vector3(0, 1.55, 0), pj + Vector3(0, 0.8 if bool(j.get("agachado")) else 1.3, 0))
	if visto:
		_ultimo_visto = j.global_position
		_t_sem_ver = 0.0
		if not cacando:
			_suspeita += 1.0 if dist_jogador < alcance * 0.45 else 0.34
			if _suspeita >= 1.0:
				perseguir()
			else:
				desconfiar(_ultimo_visto)               # viu algo de relance: "hm?"
	else:
		_suspeita = maxf(0.0, _suspeita - 0.08)

# 0.80: nada entre "de" e "ate"? Física (paredes, portas, móveis, carros perto) + prédios e cascas dos locais
# fechados pelos dados do mapa (de longe não há física)
func _linha_livre(de: Vector3, ate: Vector3) -> bool:
	_consulta.from = de
	_consulta.to = ate
	if not get_world_3d().direct_space_state.intersect_ray(_consulta).is_empty():
		return false
	var v := ate - de
	var L := v.length()
	if L < 0.05 or gerente == null or gerente.mundo == null:
		return true
	var mu = gerente.mundo
	if mu.dentro_de_predio(de.x, de.z, 0.0) != mu.dentro_de_predio(ate.x, ate.z, 0.0):
		return false                                    # um dentro de um prédio fechado e o outro fora: parede no meio
	var r: Dictionary = mu.raio(de, v / L, L)
	if not bool(r["hit"]) or float(r["dist"]) >= L - 0.2:
		return true
	return not (bool(r.get("predio", false)) or (r["n"] as Vector3) != Vector3.UP)    # o chão não tapa

func _decidir(dt: float, j: Node3D) -> void:
	var p := global_position
	match estado:
		DESCONFIADO:
			_vel_alvo = 0.0
			_t_desconfiar -= dt
			if _t_desconfiar <= 0.0:
				investigar(_foco)                       # não viu mais nada: vai até lá ver
		VAGANDO:
			if _espera > 0.0:
				_espera -= dt
				_vel_alvo = 0.0
				if _espera <= 0.0:
					_novo_destino_vagar()
			elif _dist_xz(p, _destino) < 1.2:
				_espera = randf_range(1.5, 6.0)
				_vel_alvo = 0.0
			else:
				_vel_alvo = _vel_vagar
		INVESTIGANDO:
			if _olhando:
				_vel_alvo = 0.0
				_espera -= dt
				if _espera <= 0.0:
					vagar()
			elif _dist_xz(p, _destino) < 1.8:
				_olhando = true                         # chegou: fica olhando em volta um pouco
				_espera = randf_range(3.0, 6.0)
				_vel_alvo = 0.0
			else:
				_vel_alvo = VEL_INVESTIGAR * _fator_andar
		PERSEGUINDO:
			if bool(j.get("morto")):
				vagar()
				return
			if _t_sem_ver > TEMPO_ESQUECER:
				investigar(_ultimo_visto)               # perdeu você de vista
				if dist_jogador < ALCANCE_SOM:
					_tocar("gemido%d" % (randi() % 4), randf_range(0.7, 0.8), -2.0)
				return
			# logo depois de perder de vista ainda "sabe" para onde ele foi (só um instante: 0.80)
			_destino = j.global_position if _t_sem_ver < MEMORIA else _ultimo_visto
			if _t_sem_ver >= MEMORIA and _dist_xz(p, _destino) < 1.5:
				investigar(_ultimo_visto)
				return
			_vel_alvo = _vel_correr
			if dist_jogador < 2.5:
				_vel_alvo = clampf((dist_jogador - 0.95) * 3.0, 0.0, _vel_correr)
			var dy := absf(j.global_position.y - p.y)
			if dist_jogador < DIST_ATAQUE and _recarga <= 0.0 and _t_sem_ver < VISTO_ATAQUE and dy < 1.6 and _atordoado <= 0.0:
				estado = ATACANDO
				_t_ataque = 0.0
				_golpeou = false
				modelo.atacar()
				_tocar("rosnado", randf_range(1.0, 1.25), 1.0)
				gerente.rede_ani(self, "atacar", {})
		ATACANDO:
			_vel_alvo = 0.0
			_destino = j.global_position
			_t_ataque += dt
			if not _golpeou and _t_ataque >= PREPARO_ATAQUE:
				_golpeou = true
				var dy := absf(j.global_position.y - p.y)
				if not bool(j.get("morto")) and dist_jogador < DIST_ATAQUE + 0.35 and dy < 1.6 \
						and _linha_livre(p + Vector3(0, 1.3, 0), j.global_position + Vector3(0, 1.1, 0)):
					_acertar(j)                         # 0.80: nada de morder através da parede
				_recarga = RECARGA_ATAQUE
			if _t_ataque >= PREPARO_ATAQUE + 0.45:
				estado = PERSEGUINDO

# porta fechada perto e para o lado de onde ele quer ir: perto dela, bate; um pouco longe, vai até ela
func _porta_no_caminho(p: Vector3, quer: Vector3) -> bool:
	var pt = PortaCls.perto(p, 4.5)
	if pt == null or not pt.fechada():
		return false
	var para_porta: Vector3 = pt.global_position - p
	para_porta.y = 0.0
	if para_porta.normalized().dot(quer.normalized()) < -0.3:
		return false                                  # a porta fica para trás: não é o caminho
	if para_porta.length() > 1.5:
		_dir_desvio = para_porta.normalized()
		_t_desvio = 0.7
		return true
	_t_preso = 1.25                                   # um golpe a cada ~1,2 s
	modelo.atacar()
	if gerente != null:
		gerente.rede_ani(self, "atacar", {})
	_tocar("rosnado", randf_range(0.9, 1.15), 0.0)
	rotation.y = atan2(-para_porta.x, -para_porta.z)
	pt.golpear(randf_range(DANO_MIN, DANO_MAX) * DANO_PORTA * _mult_dano)
	return true

func _acertar(j: Node3D) -> void:
	var dano := randf_range(DANO_MIN, DANO_MAX) * _mult_dano * (float(gerente.mult_dano) if gerente != null else 1.0)
	if j.has_method("receber_ataque"):
		j.receber_ataque(dano, CHANCE_SANGRAR, global_position)
	_tocar("baque", randf_range(0.7, 0.85), 2.0)
	if gerente != null and gerente.has_method("_vago_acertou"):
		gerente._vago_acertou(self, dano)

func _novo_destino_vagar() -> void:
	var p := global_position
	for i in 6:
		var a := randf() * TAU
		var d := randf_range(8.0, 22.0)
		var q := p + Vector3(cos(a) * d, 0.0, sin(a) * d)
		if not gerente.mundo.dentro_de_predio(q.x, q.z, 1.5):
			_destino = q
			return
	_destino = p

static func _dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# ---------- movimento ----------
func _bloqueado(q: Vector3) -> bool:
	return _bate(q, 0.4, 0.3)

# true se o ponto cai num prédio/obstáculo (sem física, os prédios abertos também contam como parede)
func _bate(q: Vector3, m_predio: float, m_obst: float) -> bool:
	var m = gerente.mundo
	if m.dentro_de_predio(q.x, q.z, m_predio, not _fisica):
		return true
	if _fisica:
		return false
	return m.dentro_de_obstaculo(q.x, q.z, m_obst) or gerente.dentro_de_veiculo(q.x, q.z, m_obst) \
		or gerente.Locais.em_construcao(Vector2(q.x, q.z), m_predio)

# CONTORNAR: se o caminho direto está livre, vai direto. Se não, segue a parede sempre pelo mesmo lado
# (escolhido pelo lado que abre primeiro), pegando a direção livre mais próxima do destino (de 30 em 30°).
# Assim ele dá a volta no quarteirão em vez de ficar batendo na parede.
func _direcao_livre(p: Vector3, dir: Vector3, L: float) -> Vector3:
	var olhar := clampf(L, 0.5, 1.6)
	if not _bloqueado(p + dir * olhar):
		_contorno = false
		return dir
	if not _contorno:
		_contorno = true
		_t_contorno = 0.0
		var melhor := 99
		var melhor_lado := _lado
		for s in [_lado, -_lado]:
			for i in range(1, 7):
				if not _bloqueado(p + dir.rotated(Vector3.UP, s * i * 0.5236) * olhar):
					if i < melhor:
						melhor = i
						melhor_lado = s
					break
		_lado = melhor_lado
	for i in range(1, 7):
		var d2 := dir.rotated(Vector3.UP, _lado * i * 0.5236)
		if not _bloqueado(p + d2 * olhar):
			return d2
	return -dir

func _mover(dt: float) -> void:
	var p := global_position
	var quer := Vector3.ZERO
	if _vel_alvo > 0.01 and _atordoado <= 0.0:
		var para := Vector3(_destino.x - p.x, 0.0, _destino.z - p.z)
		var L := para.length()
		if L > 0.05:
			var dir := para / L
			if _t_desvio > 0.0:                         # preso: anda de lado um pouco (ver _checar_preso)
				_t_desvio -= dt
				dir = _dir_desvio
			else:
				_t_predio -= dt
				if _t_predio <= 0.0:
					_t_predio = 0.12 if (_contorno or _vel_alvo > 2.0) else 0.25
					_dir_contorno = _direcao_livre(p, dir, L)
				if _contorno:
					dir = _dir_contorno
					_t_contorno += dt
					if _t_contorno > 15.0:              # rodando demais: tenta pelo outro lado
						_t_contorno = 0.0
						_lado = -_lado
			quer = dir * _vel_alvo
	# afasta dos outros Vagos (mesmo parado, para cercarem o jogador em vez de se empilharem)
	if _atordoado <= 0.0 and estado != MORTO:
		quer += separacao * 1.6
	# colado no jogador (atacando/perseguindo): dá meio passo para trás em vez de entrar nele
	if esta_cacando() and dist_jogador < 0.75 and dist_jogador > 0.01 and _alvo != null:
		var pj: Vector3 = _alvo.global_position
		quer = Vector3(p.x - pj.x, 0.0, p.z - pj.z).normalized() * 0.8
	var acel := 3.5
	if _vel_alvo > 2.0:
		acel = 7.0
	if quer.length_squared() < _vel_xz.length_squared():
		acel = 14.0                                     # frear é mais rápido que acelerar
	_vel_xz = _vel_xz.move_toward(quer, acel * dt)
	var empurro := _empurrao
	_empurrao *= exp(-dt * 7.0)
	if _fisica:
		velocity = Vector3(_vel_xz.x + empurro.x, 0.0, _vel_xz.z + empurro.z)
		if velocity.length_squared() > 0.0025:
			move_and_slide()
			var rv := get_real_velocity()
			_vel_h = Vector2(rv.x, rv.z).length()
		else:
			_vel_h = 0.0
		_checar_preso(dt, quer)
		# chão: raio para baixo (pega rua, calçada e o piso dos interiores) 5x por segundo
		var g := global_position
		_t_chao -= dt
		if _t_chao <= 0.0:
			_t_chao = 0.2
			_consulta.from = g + Vector3(0, 1.0, 0)
			_consulta.to = g + Vector3(0, -1.5, 0)
			var r := get_world_3d().direct_space_state.intersect_ray(_consulta)
			if r.is_empty():
				_y_chao = gerente.mundo.altura(g.x, g.z)
			else:
				_y_chao = (r["position"] as Vector3).y
			if _y_chao < Y_AGUA and _seco != Vector3.INF:
				g = Vector3(_seco.x, g.y, _seco.z)          # entrou na água funda: volta para a margem
				global_position = g
				_y_chao = _seco.y
				_vel_xz = Vector3.ZERO
			elif _y_chao >= Y_AGUA:
				_seco = Vector3(g.x, _y_chao, g.z)
		if absf(g.y - _y_chao) > 0.002:
			g.y = lerpf(g.y, _y_chao, minf(1.0, dt * 12.0))
			global_position = g
	else:
		var np := p + (_vel_xz + empurro) * dt
		# 0.80: preso dentro da planta de um prédio (sem física não há porta): não sai atravessando a parede
		var m_ = gerente.mundo
		if m_.dentro_de_predio(p.x, p.z, 0.0, true) and not m_.dentro_de_predio(np.x, np.z, -0.35, true):
			np = Vector3(p.x, np.y, p.z)
			_vel_xz *= 0.5
		# bate e desliza nas plantas (prédios são caixas alinhadas aos eixos): tenta só X, depois só Z
		if (np.x != p.x or np.z != p.z) and _bate(np, 0.3, 0.25) and not _bate(p, 0.3, 0.25):
			var so_x := Vector3(np.x, np.y, p.z)
			var so_z := Vector3(p.x, np.y, np.z)
			if not _bate(so_x, 0.3, 0.25):
				np = so_x
			elif not _bate(so_z, 0.3, 0.25):
				np = so_z
			else:
				np = Vector3(p.x, np.y, p.z)
				_vel_xz *= 0.5
		_t_chao -= dt
		if _t_chao <= 0.0:
			_t_chao = 0.3
			_y_chao = gerente.mundo.altura(np.x, np.z)
			if (_y_chao < Y_AGUA or absf(_y_chao - 0.2) < 0.001) and _seco != Vector3.INF:
				np = Vector3(_seco.x, np.y, _seco.z)        # água (mar -0,5 / lago 0,2): não entra
				_y_chao = _seco.y
				_vel_xz = Vector3.ZERO
			else:
				_seco = Vector3(np.x, _y_chao, np.z)
		np.y = lerpf(p.y, _y_chao, minf(1.0, dt * 8.0))
		_vel_h = Vector2(np.x - p.x, np.z - p.z).length() / maxf(dt, 0.0001)
		global_position = np
		_checar_preso(dt, quer)
	# virar para onde anda (ou para o jogador quando ataca / está muito perto)
	var olha := Vector3.ZERO
	if (estado == ATACANDO or (estado == PERSEGUINDO and dist_jogador < 2.5)) and _alvo != null:
		var pj: Vector3 = _alvo.global_position
		olha = Vector3(pj.x - p.x, 0.0, pj.z - p.z)
	elif estado == DESCONFIADO:
		olha = Vector3(_foco.x - p.x, 0.0, _foco.z - p.z)      # vira para o que chamou a atenção
	elif _vel_h > 0.15:
		olha = _vel_xz
	if olha.length_squared() > 0.0001:
		var giro := lerpf(4.0, 9.0, clampf(_vel_h / 4.0, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, atan2(-olha.x, -olha.z), minf(1.0, dt * giro))

# preso numa parede/carro: anda de lado por um tempo (e troca de lado se continuar preso)
func _checar_preso(dt: float, quer: Vector3) -> void:
	_t_preso -= dt
	if _t_preso > 0.0:
		return
	_t_preso = 0.5
	var p := global_position
	var andou := _dist_xz(p, _pos_preso)
	_pos_preso = p
	if quer.length() < 0.3 or _t_desvio > 0.0:
		_n_preso = 0
		return
	if andou < quer.length() * 0.5 * 0.3:
		_n_preso += 1
		if estado == VAGANDO:
			_novo_destino_vagar()
			return
		# 0.73: preso atrás de uma PORTA FECHADA (mundo/porta.gd) indo atrás de alguém: vai até ela e bate até quebrar
		if _fisica and _porta_no_caminho(p, quer):
			return
		var dir := quer.normalized()
		var nova := dir.cross(Vector3.UP) * _lado
		if _fisica and is_on_wall():
			var n := get_wall_normal()
			n.y = 0.0
			if n.length_squared() > 0.001:
				n = n.normalized()
				var desliza := dir.slide(n)
				if desliza.length() > 0.3:
					nova = desliza.normalized()
				else:
					nova = n.cross(Vector3.UP) * _lado
				nova = (nova + n * 0.35).normalized()
		_dir_desvio = nova
		_t_desvio = randf_range(0.6, 1.3)
		if _n_preso >= 3:
			_lado = -_lado
			_n_preso = 0
	else:
		_n_preso = 0

func _corpo(dt: float) -> void:
	morto_ha += dt
	if morto_ha < 3.0:
		modelo.atualizar(dt, 0.0)
	elif morto_ha > TEMPO_CORPO:
		modelo.position.y -= dt * 0.25                  # afunda no chão e some
		if morto_ha > TEMPO_CORPO + 3.0:
			queue_free()

# ---------- sons ----------
func _tocar(nome: String, tom: float, vol_db: float, canal2 := false) -> void:
	if sons.is_empty() or not sons.has(nome) or som == null:
		return
	if dist_jogador > ALCANCE_SOM + 5.0:
		return
	var s3: AudioStreamPlayer3D = som2 if canal2 and som2 != null else som
	s3.stream = sons[nome]
	s3.pitch_scale = tom * (0.85 if tipo == "pesado" else 1.0)
	s3.volume_db = vol_db
	# vozes GRAVADAS (audio/sons/infectados) no lugar das sintetizadas, quando existem
	var grav: AudioStream = null
	if nome.begins_with("gemido"):
		grav = SonsBaixados.sortear("infectados/morte" if estado == MORTO else "infectados/gemido")
	elif nome == "rosnado":
		grav = SonsBaixados.sortear("infectados/grito" if tom > 1.3 else "infectados/ataque")
	if grav != null:
		s3.stream = grav
		s3.pitch_scale = randf_range(0.9, 1.08) * (0.82 if tipo == "pesado" else (1.08 if tipo == "corredor" else 1.0))
		s3.volume_db = vol_db - 2.0
	s3.play()

static func definir_sons(r: Dictionary) -> void:
	sons = r

# chamado numa thread pelo gerente (leva um tempinho; não mexe na cena)
static func sintetizar_sons() -> Dictionary:
	var r := {}
	r["gemido0"] = _wav(_gemido(11, 92.0, 1.5, Vector3(320, 700, 2300), Vector3(650, 1050, 2450)))
	r["gemido1"] = _wav(_gemido(23, 76.0, 1.9, Vector3(380, 650, 2400), Vector3(480, 820, 2350)))
	r["gemido2"] = _wav(_gemido(37, 112.0, 1.1, Vector3(720, 1150, 2500), Vector3(480, 1600, 2500)))
	r["gemido3"] = _wav(_gemido(51, 68.0, 2.1, Vector3(420, 900, 2400), Vector3(600, 980, 2300)))
	r["rosnado"] = _wav(_rosnado(77))
	r["baque"] = _wav(_baque(91))
	return r

static func _wav(a: PackedFloat32Array) -> AudioStreamWAV:
	var pico := 0.0001
	for x in a:
		pico = maxf(pico, absf(x))
	var g := 0.9 / pico
	var dados := PackedByteArray()
	dados.resize(a.size() * 2)
	for i in a.size():
		dados.encode_s16(i * 2, int(clampf(a[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA_SOM
	w.stereo = false
	w.data = dados
	return w

# gemido rouco: pulsos da garganta irregulares (voz "rasgada") + chiado de ar, passando por 3 formantes
# (ressonâncias da boca) que deslizam de uma vogal para outra (fa -> fb)
static func _gemido(semente: int, f0: float, dur: float, fa: Vector3, fb: Vector3) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var n := int(TAXA_SOM * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var fase := 0.0
	var amp := 1.0
	var sub := false
	var deriva := 0.0
	var y1 := Vector3.ZERO
	var y2 := Vector3.ZERO
	var c1 := Vector3.ZERO
	var c2 := Vector3.ZERO
	var g := Vector3.ZERO
	var bw := Vector3(110.0, 150.0, 220.0)
	var ganho := Vector3(1.0, 0.6, 0.25)
	for i in n:
		var t := float(i) / TAXA_SOM
		var u := t / dur
		if i % 64 == 0:
			var f := fa.lerp(fb, smoothstep(0.0, 1.0, u))
			for k in 3:
				var rr := exp(-PI * bw[k] / TAXA_SOM)
				c1[k] = 2.0 * rr * cos(TAU * f[k] / TAXA_SOM)
				c2[k] = rr * rr
				g[k] = (1.0 - rr) * ganho[k]
		deriva += (rng.randf_range(-1.0, 1.0) * 6.0 - deriva) * 0.003
		var fq := f0 * (1.0 + 0.2 * sin(PI * u) - 0.3 * u * u) * (1.0 + 0.025 * sin(TAU * 5.0 * t)) + deriva
		fase += fq / TAXA_SOM
		if fase >= 1.0:
			fase -= 1.0
			sub = not sub
			amp = rng.randf_range(0.4, 1.0) * (0.55 if sub else 1.0)      # aspereza + "voz dobrada"
		var x := (1.0 - 2.0 * fase) * amp + rng.randf_range(-1.0, 1.0) * 0.45
		var s := 0.0
		for k in 3:
			var y := g[k] * x + c1[k] * y1[k] - c2[k] * y2[k]
			y2[k] = y1[k]
			y1[k] = y
			s += y
		var env := minf(1.0, t / 0.18) * minf(1.0, (dur - t) / 0.45)
		env *= 0.75 + 0.25 * sin(TAU * 3.3 * t + 1.0)                     # soluço
		a[i] = tanh(s * 6.0) * env
	return a

# rosnado do ataque: mais agudo, muito ar e chocalho rápido
static func _rosnado(semente: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var dur := 0.75
	var n := int(TAXA_SOM * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var fase := 0.0
	var amp := 1.0
	var y1 := Vector3.ZERO
	var y2 := Vector3.ZERO
	var c1 := Vector3.ZERO
	var c2 := Vector3.ZERO
	var g := Vector3.ZERO
	var f := Vector3(780.0, 1250.0, 2650.0)
	var bw := Vector3(160.0, 220.0, 300.0)
	var ganho := Vector3(1.0, 0.8, 0.4)
	for k in 3:
		var rr := exp(-PI * bw[k] / TAXA_SOM)
		c1[k] = 2.0 * rr * cos(TAU * f[k] / TAXA_SOM)
		c2[k] = rr * rr
		g[k] = (1.0 - rr) * ganho[k]
	for i in n:
		var t := float(i) / TAXA_SOM
		var u := t / dur
		var fq := 120.0 + 110.0 * sin(PI * minf(1.0, u * 1.4)) + rng.randf_range(-8.0, 8.0)
		fase += fq / TAXA_SOM
		if fase >= 1.0:
			fase -= 1.0
			amp = rng.randf_range(0.3, 1.0)
		var x := (1.0 - 2.0 * fase) * amp * 0.8 + rng.randf_range(-1.0, 1.0) * 0.9
		x *= 0.55 + 0.45 * sin(TAU * 31.0 * t)                            # chocalho na garganta
		var s := 0.0
		for k in 3:
			var y := g[k] * x + c1[k] * y1[k] - c2[k] * y2[k]
			y2[k] = y1[k]
			y1[k] = y
			s += y
		var env := minf(1.0, t / 0.04) * minf(1.0, (dur - t) / 0.3)
		a[i] = tanh(s * 9.0) * env
	return a

# baque surdo (soco/tiro na carne): grave que cai + estalo molhado
static func _baque(semente: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var dur := 0.3
	var n := int(TAXA_SOM * dur)
	var a := PackedFloat32Array()
	a.resize(n)
	var fase := 0.0
	var lp := 0.0
	var bp1 := 0.0
	var bp2 := 0.0
	for i in n:
		var t := float(i) / TAXA_SOM
		fase += (45.0 + 85.0 * exp(-t * 18.0)) / TAXA_SOM
		var grave := sin(TAU * fase) * exp(-t * 13.0)
		var r := rng.randf_range(-1.0, 1.0)
		lp += (r - lp) * 0.25
		var estalo := lp * exp(-t * 45.0) * 0.9
		bp1 += (r - bp1) * 0.12
		bp2 += (bp1 - bp2) * 0.12
		var molhado := (bp1 - bp2) * exp(-t * 22.0) * 2.5
		a[i] = grave + estalo + molhado
	return a
