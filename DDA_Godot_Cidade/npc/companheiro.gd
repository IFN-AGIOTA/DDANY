extends CharacterBody3D
# COMPANHEIRO COM INTELIGÊNCIA PRÓPRIA (Greg e Mavie, depois do encontro no Capítulo 3).
# O que ele faz sozinho:
#   SEGUIR ... anda/corre atrás do jogador numa posição própria (Greg à direita, Mavie à esquerda), no mesmo ritmo;
#              desvia de paredes; se ficar muito longe ou preso, reaparece atrás do jogador (fora da vista).
#   LUTAR .... vê infectados perto (que estão atrás de alguém do grupo, ou a poucos metros) e vai para cima com a
#              arma dele (Greg: taco · Mavie: cano). Volta para perto do jogador se a briga ficar longe demais.
#   PROTEGER . dá prioridade ao infectado mais perto do JOGADOR.
#   CAIR ..... sem vida, cai no chão (não morre: é personagem da história). Chegue perto para levantar
#              (3 s) ou ele levanta sozinho depois de um tempo, se não tiver infectado perto.
#   FALAR .... frases curtas sobre a cabeça (viu infectado, acertou, se machucou, caiu, você ferido, a Mavie tosse).
# Os infectados atacam os companheiros também (inimigos/vagos.gd › alvo_para). Os tiros do jogador não acertam
# os companheiros (sem fogo amigo).
# Mexa AQUI para: vida, dano, velocidade, distâncias e as falas (FALAS).

signal falou(quem: String, texto: String)

const ModeloCls := preload("res://npc/modelo_humano.gd")

const DADOS := {
	"greg": {"nome": "GREG", "vida": 120.0, "arma": "taco", "dano": 46.0, "recarga": 0.95, "lado": 1.0, "cor": Color(0.55, 0.85, 0.55)},
	"mavie": {"nome": "MAVIE", "vida": 85.0, "arma": "cano", "dano": 38.0, "recarga": 1.15, "lado": -1.0, "cor": Color(1.0, 0.65, 0.65)},
}
const FALAS := {
	"chegou": ["Vamos, Dom. Eu cuido da retaguarda.", "Tô com você. Não me deixa pra trás."],
	"viu": ["Infectado!", "Atrás de você!", "Tem um vindo aí!", "Cuidado, Dom!", "Mais deles!"],
	"matou": ["Esse não levanta mais.", "Um a menos.", "Tá limpo aqui.", "Fica no chão!"],
	"ferido": ["Ai! Ele me pegou!", "Argh!", "Tô bem, tô bem...", "Saiu de cima!"],
	"caiu": ["Dom... me ajuda...", "Não consigo levantar...", "Tô caído aqui!"],
	"levantou": ["Valeu... achei que era o fim.", "Tô de pé. Vamos."],
	"jogador_ferido": ["Dom, você tá sangrando!", "Você tá mal, cara. Faz um curativo.", "Para um pouco, você precisa se cuidar."],
	"tosse_mavie": ["*tosse*", "Tô bem... é só a febre.", "Minha cabeça tá latejando..."],
	"parado": ["A gente precisa achar comida.", "Esse silêncio me dá arrepio.", "Fica de olho nas janelas.", "Quanto tempo será que dura isso?"],
}
const DIST_SEGUIR := 2.6
const DIST_CORRER := 7.0
const DIST_REAPARECER := 45.0
const VISAO := 16.0
const ALCANCE_GOLPE := 1.7
const RAIO_LUTA := 22.0            # não se afasta mais que isso do jogador para lutar
const TEMPO_LEVANTAR := 3.0
const TEMPO_LEVANTAR_SOZINHO := 40.0

var quem := "greg"
var nome := "GREG"
var vida := 100.0
var vida_max := 100.0
var morto := false                 # = caído (os infectados e a interface tratam como fora de combate)
var agachado := false
var jogador: CharacterBody3D = null
var mundo = null
var vagos = null
var modelo: Node3D

var _alvo = null
var _t_busca := 0.0
var _recarga := 0.0
var _golpe_t := -1.0
var _t_preso := 0.0
var _pos_ant := Vector3.ZERO
var _t_caido := 0.0
var _levantando := 0.0
var _rotulo: Label3D
var _t_fala := 0.0
var _fala_dur := 0.0
var _t_tagarela := 30.0
var _t_tosse := 40.0
var _avisou_jogador := 0.0
var _desvio := 0.0
var _t_desvio := 0.0
var _consulta: PhysicsRayQueryParameters3D

func configurar(q: String, j: CharacterBody3D, m, v) -> void:
	quem = q
	jogador = j
	mundo = m
	vagos = v
	var d: Dictionary = DADOS[q]
	nome = d["nome"]
	vida_max = d["vida"]
	vida = vida_max

func _ready() -> void:
	add_to_group("pausa_por_chunk")    # fora dos chunks ativos fica pausado (mundo/chunks.gd)
	add_to_group("companheiros")
	collision_layer = 0              # não atrapalha o jogador nem os tiros dele
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	modelo = ModeloCls.new()
	add_child(modelo)
	modelo.montar(quem, DADOS[quem]["arma"])
	_rotulo = Label3D.new()
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.position.y = 2.15
	_rotulo.font_size = 40
	_rotulo.pixel_size = 0.004
	_rotulo.outline_size = 10
	_rotulo.modulate = DADOS[quem]["cor"]
	_rotulo.no_depth_test = true
	_rotulo.fixed_size = false
	_rotulo.visible = false
	add_child(_rotulo)
	_consulta = PhysicsRayQueryParameters3D.new()
	_consulta.collision_mask = 1
	_t_tagarela = randf_range(25.0, 60.0)
	_t_tosse = randf_range(30.0, 70.0)

func falar(tipo: String, forcar := false) -> void:
	if not forcar and _t_fala > 0.0 and _fala_dur - _t_fala < 1.5:
		return
	var lista: Array = FALAS.get(tipo, [])
	if lista.is_empty():
		return
	var t: String = lista[randi() % lista.size()]
	_rotulo.text = nome + ": " + t
	_rotulo.visible = true
	_fala_dur = clampf(1.5 + t.length() * 0.05, 2.0, 4.5)
	_t_fala = _fala_dur
	falou.emit(nome, t)

# ---------- dano (infectados chamam igual ao jogador) ----------
func receber_ataque(dano: float, _chance_sangrar: float, _origem: Vector3) -> void:
	if morto:
		return
	vida -= dano
	modelo.levar_golpe()
	if vida <= 0.0:
		_cair()
	elif randf() < 0.45:
		falar("ferido")

func _cair() -> void:
	vida = 0.0
	morto = true
	modelo.caido = true
	_t_caido = 0.0
	_levantando = 0.0
	_alvo = null
	falar("caiu", true)

func _levantar() -> void:
	morto = false
	modelo.caido = false
	vida = vida_max * 0.4
	falar("levantou", true)

# ---------- cérebro ----------
func _physics_process(dt: float) -> void:
	if jogador == null or not is_instance_valid(jogador):
		return
	_falas(dt)
	var p := global_position
	var pj := jogador.global_position
	var dj := Vector2(pj.x - p.x, pj.z - p.z).length()
	if morto:
		_caido(dt, dj)
		_gravidade(dt)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		modelo.atualizar(dt, 0.0)
		return
	# longe demais (ou o jogador voou/caiu longe): reaparece atrás dele
	if dj > DIST_REAPARECER:
		_reaparecer()
		return
	_recarga = maxf(0.0, _recarga - dt)
	_t_busca -= dt
	if _t_busca <= 0.0:
		_t_busca = randf_range(0.25, 0.35)
		_procurar_alvo(pj)
	var destino := pj
	var vel_alvo := 0.0
	if _alvo != null:
		var pa: Vector3 = _alvo.global_position
		var da := Vector2(pa.x - p.x, pa.z - p.z).length()
		destino = pa
		vel_alvo = 5.6 if da > 2.0 else 0.0
		if da > ALCANCE_GOLPE * 0.8:
			vel_alvo = clampf((da - ALCANCE_GOLPE * 0.7) * 3.0, 0.0, 5.6)
		_olhar_para(pa, dt)
		if da <= ALCANCE_GOLPE and _recarga <= 0.0 and _golpe_t < 0.0:
			_golpe_t = 0.0
			modelo.golpear()
			_recarga = DADOS[quem]["recarga"]
	else:
		# posição no grupo: atrás e para o lado do jogador
		var yaw: float = jogador.rotation.y
		var lado: float = DADOS[quem]["lado"]
		destino = pj + Basis(Vector3.UP, yaw) * Vector3(lado * 1.6, 0.0, 1.8)
		var dd := Vector2(destino.x - p.x, destino.z - p.z).length()
		var vj: float = jogador.get("vel_horizontal")
		if dd > DIST_CORRER:
			vel_alvo = maxf(6.4, vj)
		elif dd > DIST_SEGUIR:
			vel_alvo = clampf(maxf(vj, dd * 0.9), 1.5, 7.0)
		elif dd > 0.8:
			vel_alvo = minf(vj, 1.7)
		if vel_alvo > 0.1:
			_olhar_para(destino, dt)
		elif dj < 6.0:
			_olhar_para(pj - (Basis(Vector3.UP, yaw) * Vector3(0, 0, 4.0)), dt)   # olha para onde o jogador olha
	# golpe em andamento: acerta no meio do movimento
	if _golpe_t >= 0.0:
		_golpe_t += dt
		if _golpe_t >= 0.3 and _golpe_t - dt < 0.3:
			_acertar()
		if _golpe_t >= 0.55:
			_golpe_t = -1.0
		vel_alvo = 0.0
	_mover(destino, vel_alvo, dt)
	var vh := Vector2(velocity.x, velocity.z).length()
	modelo.atualizar(dt, vh)
	# preso (parede/prédio): tenta reaparecer
	if vel_alvo > 1.0 and vh < 0.3:
		_t_preso += dt
		if _t_preso > 3.5 and dj > 8.0:
			_reaparecer()
	else:
		_t_preso = 0.0

func _procurar_alvo(pj: Vector3) -> void:
	if vagos == null:
		_alvo = null
		return
	var p := global_position
	var melhor = null
	var md := 1e9
	for v in vagos.vivos:
		if not is_instance_valid(v) or v.estado == v.MORTO:
			continue
		var q: Vector3 = v.global_position
		var d_mim := Vector2(q.x - p.x, q.z - p.z).length()
		var d_jog := Vector2(q.x - pj.x, q.z - pj.z).length()
		if d_jog > RAIO_LUTA:
			continue
		var ameaca: bool = v.esta_cacando() or d_mim < 6.0 or d_jog < 6.0
		if not ameaca or d_mim > VISAO:
			continue
		var nota := d_mim * 0.6 + d_jog * 0.8          # prefere o que está mais perto do jogador
		if nota < md:
			md = nota
			melhor = v
	if melhor != null and melhor != _alvo:
		falar("viu")
	_alvo = melhor

func _acertar() -> void:
	if _alvo == null or not is_instance_valid(_alvo):
		return
	var p := global_position
	var pa: Vector3 = _alvo.global_position
	if Vector2(pa.x - p.x, pa.z - p.z).length() > ALCANCE_GOLPE + 0.4:
		return
	var dir := (pa - p)
	dir.y = 0.0
	var res: Dictionary = _alvo.receber_golpe(float(DADOS[quem]["dano"]), dir.normalized(), self)
	if vagos != null:
		vagos.barulho(p, 7.0, false)
	if bool(res.get("morto", false)):
		_alvo = null
		if randf() < 0.6:
			falar("matou")

func _mover(destino: Vector3, vel: float, dt: float) -> void:
	var p := global_position
	var d := Vector3(destino.x - p.x, 0.0, destino.z - p.z)
	var dir := d.normalized() if d.length() > 0.05 else Vector3.ZERO
	# desvio simples: raio à frente na altura do joelho; se bater, gira para um lado por um tempo
	_t_desvio -= dt
	if dir != Vector3.ZERO and vel > 0.5:
		_consulta.from = p + Vector3(0, 0.5, 0)
		_consulta.to = p + Vector3(0, 0.5, 0) + dir * 1.1
		if _consulta.exclude.is_empty():
			_consulta.exclude = [get_rid()]      # uma vez só (antes criava a lista a cada quadro)
		var hit := get_world_3d().direct_space_state.intersect_ray(_consulta)
		if not hit.is_empty():
			if _t_desvio <= 0.0:
				_desvio = 1.1 if randf() < 0.5 else -1.1
			_t_desvio = 0.6
		if _t_desvio > 0.0:
			dir = dir.rotated(Vector3.UP, _desvio)
	var k := minf(1.0, dt * 8.0)
	velocity.x += (dir.x * vel - velocity.x) * k
	velocity.z += (dir.z * vel - velocity.z) * k
	_gravidade(dt)
	move_and_slide()

func _gravidade(dt: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 15.0 * dt
		if global_position.y < -20.0:
			_reaparecer()

func _olhar_para(alvo: Vector3, dt: float) -> void:
	var d := alvo - global_position
	if Vector2(d.x, d.z).length() < 0.05:
		return
	var yaw := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, dt * 9.0))

# reaparece atrás do jogador, fora da vista da câmera, num lugar livre
func _reaparecer() -> void:
	var pj := jogador.global_position
	var yaw: float = jogador.rotation.y
	var lado: float = DADOS[quem]["lado"]
	for tentativa in 8:
		var off := Basis(Vector3.UP, yaw + randf_range(-0.6, 0.6)) * Vector3(lado * randf_range(1.0, 2.5), 0.0, randf_range(3.0, 6.0))
		var q := pj + off
		if mundo != null and mundo.has_method("dentro_de_predio") and mundo.dentro_de_predio(q.x, q.z, 0.6):
			continue
		var y := pj.y
		global_position = Vector3(q.x, y + 0.3, q.z)
		velocity = Vector3.ZERO
		_t_preso = 0.0
		return
	global_position = pj + Vector3(0, 0.3, 0)
	velocity = Vector3.ZERO

func _caido(dt: float, dj: float) -> void:
	_t_caido += dt
	if dj < 2.2 and not bool(jogador.get("morto")):
		_levantando += dt
		_rotulo.text = "LEVANTANDO %s... %d%%" % [nome, int(_levantando / TEMPO_LEVANTAR * 100.0)]
		_rotulo.visible = true
		_t_fala = 0.5
		if _levantando >= TEMPO_LEVANTAR:
			_levantar()
	else:
		_levantando = 0.0
		if _t_caido > TEMPO_LEVANTAR_SOZINHO and _ninguem_perto():
			_levantar()

func _ninguem_perto() -> bool:
	if vagos == null:
		return true
	var p := global_position
	for v in vagos.vivos:
		if is_instance_valid(v) and v.estado != v.MORTO and p.distance_to(v.global_position) < 15.0:
			return false
	return true

func _falas(dt: float) -> void:
	if _t_fala > 0.0:
		_t_fala -= dt
		if _t_fala <= 0.0:
			_rotulo.visible = false
	if morto:
		return
	_t_tagarela -= dt
	if _t_tagarela <= 0.0:
		_t_tagarela = randf_range(45.0, 90.0)
		if _alvo == null:
			falar("parado")
	if quem == "mavie":
		_t_tosse -= dt
		if _t_tosse <= 0.0:
			_t_tosse = randf_range(35.0, 80.0)
			falar("tosse_mavie")
	_avisou_jogador -= dt
	var sv = jogador.get("sobrevivencia")
	if sv != null and _avisou_jogador <= 0.0 and (sv.sangramentos > 0 or sv.vida < 35.0):
		_avisou_jogador = 40.0
		if quem == "greg" or randf() < 0.5:
			falar("jogador_ferido")

func salvar() -> Dictionary:
	return {"vida": vida, "caido": morto}

func carregar(d: Dictionary) -> void:
	vida = float(d.get("vida", vida_max))
	if bool(d.get("caido", false)):
		_cair()
