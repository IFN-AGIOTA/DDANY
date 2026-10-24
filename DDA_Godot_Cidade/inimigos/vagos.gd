extends Node
# VAGOS · gerente dos INFECTADOS (inimigos/vago.gd + modelo inimigos/modelo_infectado.gd).
# Nome: os arquivos ficaram "vago/vagos" (vem do HTML), mas na LORE "Vagos" é a GANGUE de Edy e V;
# no jogo (textos da tela) eles são chamados de INFECTADOS.
# - 0.89 · ESTILO PROJECT ZOMBOID: quem decide quantos e onde é a POPULAÇÃO da cidade (inimigos/horda.gd): grupos
#   virtuais por toda a cidade que viram infectados de verdade perto de você (até max_ativos, o limite do
#   aparelho) e voltam a ser grupo longe (a horda que você puxou fica lá). As regras (velocidade, sentidos,
#   memória, população...) vêm de Opções › Infectados (inimigos/regras_infectados.gd).
# - Os que não são da horda (prédio infestado, locais, missões) somem a mais de 160 m. Corpos: até MAX_CORPOS.
# - AUDIÇÃO: tiros (sinal armas.barulho), carro, portas e os passos do jogador (a cada 0,5 s, regras_infectados:
#   correndo 20 m, trote 14 m, andando 7 m, devagar 3,5 m, agachado 2,5 m; chuva abafa). Quem ouve vai investigar.
# - MANADA: quem está parado/à toa e vê outro infectado caçando perto (14 m) vai atrás dele (as hordas crescem).
# - PUXAR PARA O CHÃO: 3 infectados te acertando juntos (1,6 s) te derrubam (morte), se a opção estiver ligada.
# - Alguém perseguindo = a música aperta (Musica.adicionar_tensao).
# - ativo = false: some com todos e para de criar (os testes usam).
# - clima (opcional): objeto com escuridao() -> 0..1; à noite os Vagos enxergam menos.
#
# Uso (main.gd, _criar_jogo):
#   vagos = VagosCls.new(); vagos.name = "Vagos"; jogo.add_child(vagos)
#   vagos.ligar(cidade, mundo, jogador, jogador.armas)
#
# Mexa AQUI para: quantos infectados de verdade cabem (MAX_ATIVOS_PADRAO, FATOR_PC), distância de sumir, corpos.
# (população e hordas: inimigos/horda.gd · barulho dos passos e números do estilo Project Zomboid: regras_infectados.gd)
# (velocidade, vida e dano de cada Vago ficam em inimigos/vago.gd)

signal abatido(cabeca: bool)            # um Vago morreu (cabeca = tiro na cabeça)
signal atacou_jogador(dano: float)      # um Vago acertou o jogador (útil para HUD, tremer a tela e testes)

const Locais := preload("res://mundo/locais.gd")
const VagoCls := preload("res://inimigos/vago.gd")
const HordaCls := preload("res://inimigos/horda.gd")
const Regras := preload("res://inimigos/regras_infectados.gd")

const MAX_ATIVOS_PADRAO := 22               # 0.89: infectados DE VERDADE ao mesmo tempo (o resto fica virtual na horda)
const FATOR_PC := 1.4                       # no PC cabem mais
const ESCALA_DIFICULDADE := [0.7, 1.0, 1.3]    # Opções › Dificuldade (fácil, normal, difícil)
const DANO_DIFICULDADE := [0.7, 1.0, 1.3]
const DIST_MAX := 120.0
const DIST_SUMIR := 160.0
const MAX_CORPOS := 20

var max_ativos := MAX_ATIVOS_PADRAO
var horda: Node = null                  # 0.89: inimigos/horda.gd (população da cidade; solo e host)
var _mult_pop := 1.0
var _golpes: Array = []                 # 0.89: [hora (s), infectado] dos últimos golpes no jogador (puxar para o chão)
var mult_dano := 1.0                    # dificuldade: força das mordidas
var ativo := true:
	set(v):
		ativo = v
		if not v:
			limpar()
var clima = null
var mato = null                        # mundo/mato.gd (agachado no capim alto = quase invisível)
var veiculos = null                    # 0.79: mundo/veiculos.gd (carros que funcionam: obstáculo para quem anda sem física)
var abates := 0
var cidade = null
var mundo = null
var jogador: Node3D = null
var armas = null
var vivos: Array = []
var corpos: Array = []

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
const TIPOS_REDE := ["lento", "rapido", "corredor", "rastejante"]   # 0.89: o jeito de andar (vago.gd CLASSES)

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
		max_ativos = int(round(MAX_ATIVOS_PADRAO * float(ESCALA_DIFICULDADE[dif]) * (1.0 if OS.has_feature("mobile") else FATOR_PC)))
		mult_dano = float(DANO_DIFICULDADE[dif])
		_mult_pop = float(ESCALA_DIFICULDADE[dif])
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

# 0.89: a população da cidade (horda) vai no jogo salvo: os grupos ficam onde estavam
func salvar() -> Dictionary:
	var d := {"abates": abates}
	if horda != null:
		d["horda"] = horda.salvar(vivos)
	return d

func carregar(d: Dictionary) -> void:
	abates = int(d.get("abates", abates))
	if d.has("horda"):
		_garantir_horda()
		horda.carregar(d["horda"])
		for v in vivos:
			if is_instance_valid(v) and bool(v.get("da_horda")):
				por_id.erase(v.id_rede)
				v.queue_free()
		vivos = vivos.filter(func(v): return is_instance_valid(v) and not bool(v.get("da_horda")))

func _garantir_horda() -> void:
	if horda == null:
		horda = HordaCls.new()
		horda.name = "Horda"
		horda.gerente = self
		add_child(horda)

# quantos infectados de verdade ainda cabem (o limite do aparelho)
func vagas_reais() -> int:
	if not ativo:
		return 0
	return max_ativos - vivos.size()

func mult_populacao() -> float:
	return _mult_pop

func limpar() -> void:
	for v in vivos:
		if is_instance_valid(v):
			v.queue_free()
	for v in corpos:
		if is_instance_valid(v):
			v.queue_free()
	vivos.clear()
	corpos.clear()

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
# 0.89: a horda virtual (longe) também ouve; a opção Audição aumenta/diminui o círculo
func barulho(posicao: Vector3, raio: float, do_jogador := true) -> void:
	barulho_real(posicao, raio, do_jogador)
	if horda != null:
		horda.barulho(posicao, raio)

func barulho_real(posicao: Vector3, raio: float, do_jogador := true) -> void:
	var r := raio * Regras.mult_audicao()
	for v in vivos:
		v.ouvir(posicao, r, do_jogador)

func _vago_acertou(_v: Node, dano: float) -> void:
	if _v.get("_alvo") == null or _v._alvo == jogador:      # mordida num amigo: o aparelho dele que treme
		atacou_jogador.emit(dano)
		_contar_golpe(_v)

# 0.89 · PUXAR PARA O CHÃO (drag down do Project Zomboid): DERRUBAR_N infectados diferentes te acertando em
# DERRUBAR_JANELA s te levam para o chão
# (quem = o infectado, ou no aparelho do amigo o lugar de onde veio a mordida: cada um conta uma vez)
func _contar_golpe(quem) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	_golpes.append([agora, quem if not (quem is Object) else (quem as Object).get_instance_id()])
	_golpes = _golpes.filter(func(x): return agora - float(x[0]) <= Regras.DERRUBAR_JANELA)
	var distintos := {}
	for x in _golpes:
		distintos[x[1]] = true
	if distintos.size() >= Regras.DERRUBAR_N and Regras.derrubam() and jogador != null and not bool(jogador.get("morto")):
		var sv = jogador.get("sobrevivencia")
		if sv != null and sv.has_method("derrubado"):
			sv.derrubado()
		_golpes.clear()

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
		var lim_v := lim2 if not bool(v.get("da_horda")) else 260.0 * 260.0    # da horda: horda.gd recolhe (volta a ser grupo)
		if _longe_de_todos(p, lim_v):
			if bool(v.get("da_horda")) and horda != null:
				horda.recolher(v)
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
	# 0.89: a população da cidade (grupos virtuais) vira infectados de verdade perto de vocês (servidor vazio: ninguém)
	if ativo and not (sem_jogador and _centros().is_empty()):
		_garantir_horda()
		horda.processar(dt)
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

func _ruido_jogador() -> void:
	if sem_jogador or bool(jogador.get("morto")):
		return
	var vel: float = jogador.get("vel_horizontal")
	if vel < 0.3:
		return
	barulho(jogador.global_position, raio_passos(vel, bool(jogador.get("agachado"))), true)

# 0.89: barulho dos passos (Project Zomboid: andar ~7, trote 2x, correr ~3x; agachado quase nada; chuva abafa)
func raio_passos(vel: float, agachado: bool) -> float:
	var raio := Regras.PASSO_ANDANDO
	if agachado:
		raio = Regras.PASSO_AGACHADO
	elif vel > 5.5:
		raio = Regras.PASSO_CORRENDO
	elif vel > 2.5:
		raio = Regras.PASSO_TROTE
	elif vel < 1.3:
		raio = Regras.PASSO_DEVAGAR
	if clima != null:
		raio *= 1.0 - 0.35 * clampf(float(clima.chuva), 0.0, 1.0)
	return raio

func _separar() -> void:
	var n := vivos.size()
	for i in n:
		var a = vivos[i]
		var pa: Vector3 = a.global_position
		var sep := Vector3.ZERO
		var cacando_a: bool = a.esta_cacando()
		var lider = null
		var d_lider := 196.0                               # 0.89 · MANADA: até 14 m
		for k in n:
			if k == i:
				continue
			var b = vivos[k]
			var pb: Vector3 = b.global_position
			var dx := pa.x - pb.x
			var dz := pa.z - pb.z
			var d2 := dx * dx + dz * dz
			if d2 < 1.44 and d2 > 0.0001:
				var d := sqrt(d2)
				sep += Vector3(dx / d, 0.0, dz / d) * (1.2 - d) / 1.2
			if not cacando_a and d2 < d_lider and b.esta_cacando() and float(b._vel_h) > 0.5:
				d_lider = d2
				lider = b
		if sep.length_squared() > 1.0:
			sep = sep.normalized()
		a.separacao = sep * 0.9
		if lider != null:
			a.seguir_manada(lider)

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

# passos dos amigos (o host não tem o "jogador" deles: usa a velocidade que chega pela rede)
func _ruido_remotos() -> void:
	for r in remotos():
		if not is_instance_valid(r) or not r.visible or r.morto:
			continue
		var vel: float = r.vel_horizontal
		if vel < 0.3:
			continue
		barulho(r.global_position, raio_passos(vel, r.agachado), true)

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
			v.rede_tipo(TIPOS_REDE[clampi(int(d[k + 7]), 0, TIPOS_REDE.size() - 1)])

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

# 0.72: quantos infectados vivos a até "raio" metros (no plano) de p (prédio/local só volta a ter se esvaziou)
func vivos_perto(p: Vector3, raio: float) -> int:
	var n := 0
	var r2 := raio * raio
	for v in vivos:
		if is_instance_valid(v):
			var d := Vector2(v.global_position.x - p.x, v.global_position.z - p.z)
			if d.length_squared() < r2:
				n += 1
	return n

func _criar(p: Vector3, destino: Vector3, da_horda := false) -> Node:
	if espelho:
		return null       # 0.70: no cliente quem cria é o host (prédio infestado, local, missão e evento chamam aqui)
	var v = VagoCls.new()
	v.gerente = self
	v.da_horda = da_horda
	v.position = p + Vector3(0, 0.02, 0)
	v.rotation.y = randf() * TAU
	add_child(v)
	if destino != Vector3.INF:                 # horda: andam juntos para o mesmo lado (0.89: indo atrás do barulho)
		v.investigar(destino + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0)))
	v.morreu.connect(_ao_morrer)
	vivos.append(v)
	v.id_rede = _prox_id
	por_id[_prox_id] = v
	_prox_id += 1
	return v

func _ao_morrer(v: Node, cabeca: bool) -> void:
	vivos.erase(v)
	corpos.append(v)
	if horda != null and not espelho:
		horda.morreu_em(v.global_position)          # 0.89: a quadra perdeu um (pode reaparecer depois)
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

# 0.79: (x, z) cai dentro de um carro que funciona (estacionado ou dirigido)? O carro largado comum é obstáculo do
# mapa (mundo/colisao_mundo.gd), mas o que virou veículo perde esse obstáculo: sem física, o infectado o atravessava.
func dentro_de_veiculo(x: float, z: float, margem := 0.0) -> bool:
	if veiculos == null:
		return false
	for v in veiculos.nos.values():
		if not is_instance_valid(v):
			continue
		var d: Vector3 = Vector3(x, 0.0, z) - (v as Node3D).global_position
		if d.x * d.x + d.z * d.z > 16.0:
			continue
		var b: Basis = (v as Node3D).global_basis
		var lx := d.dot(b.x)
		var lz := d.dot(b.z)
		if absf(lx) < 1.0 + margem and absf(lz) < 2.4 + margem:
			return true
	return false
