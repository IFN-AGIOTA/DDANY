extends Node
# ANIMADOR DO MODELO · liga o estado do jogador (parado, andando, correndo, no ar...) às animações do modelo.
# Funciona com QUALQUER modelo que tenha um AnimationPlayer (GLB/GLTF/FBX importado, ex.: Mixamo):
#   1) procura as animações pelo NOME (palavras-chave abaixo: "idle", "walk", "run", "jump"...);
#   2) se faltar alguma, usa a mais parecida (correr -> andar -> parado ...);
#   3) se o modelo NÃO tiver AnimationPlayer (o soldado original), usa a animação por código dele.
# Animações em arquivos separados (como o Mixamo entrega): coloque em res://modelos/animacoes/ e elas são
# adicionadas ao modelo sozinhas (veja importar_animacoes).
# Para fixar nomes exatos: animador.nomes_exatos["correr"] = "Rifle Run"
# EXTRAS (quando o modelo tem as animações do jogo, jogador/sobrevivente/animacoes.res):
#   · 8 DIREÇÕES: mirando/atirando o corpo fica virado para a mira; as pernas andam/correm de frente, de costas
#     (andar_tras) ou de lado (andar_lado_esq / andar_lado_dir), escolhendo pela direção do movimento em relação ao corpo;
#   · fuzil na mão: correr_fuzil e mirar_fuzil;
#   · AÇÕES (acao()): recarregar, golpes, pegar do chão, comer/beber, curar, levar golpe. Parado = corpo todo;
#     andando = só a parte de cima (jogador/camada_acao.gd), as pernas continuam;
#   · morte com 3 variações.
#   · 0.59 · CAMINHADAS por velocidade (captura de movimento real da CMU, ferramentas/retarget_cmu.gd):
#     devagar (andar_lento) · normal (andar_normal) · apressada (andar_rapido) · trote · corrida; agachado devagar =
#     andar_agachado (1.04: rápido também, mais depressa); perna quebrada = mancar. Cada uma com a velocidade de
#     referência em REF (a animação acompanha o chão sem "patinar").
#   · 0.59 · POSTURA DA ARMA (jogador/camada_postura.gd): com pistola, faca/facão/pé de cabra ou taco/machado/
#     cano/lança na mão, os braços seguram a arma do jeito dela por cima de qualquer caminhada (POSTURAS).
#   · 1.12 · "MOTION MATCHING" (como o Game Animation Sample da Unreal 5), com o sobrevivente: parado, andando,
#     correndo e agachado, a animação E O QUADRO vêm de jogador/base_movimento.gd (a velocidade/direção pedida + onde
#     estão os pés agora: o passo continua, sem recomeçar do início). A troca é instantânea e a diferença de pose some
#     sozinha (jogador/camada_inercia.gd). Na diagonal as pernas giram para a direção do passo e o tronco fica na mira;
#     nas curvas o tronco inclina (jogador/camada_orientacao.gd). usar_mm = false volta ao jeito antigo.

signal tocou_acao(nome: String, velocidade: float, corpo_todo: bool)   # multijogador repassa (rede/sessao_rede.gd)

enum Estado { PARADO, ANDAR, CORRER, PULAR, CAINDO, MIRAR, ATIRAR, MORRER, AGACHADO, ANDAR_AGACHADO }

const NOMES := ["parado", "andar", "correr", "pular", "cair", "mirar", "atirar", "morrer", "agachado", "andar_agachado"]
const COM_LOOP := ["parado", "andar", "correr", "cair", "mirar", "agachado", "andar_agachado"]
const PRECEDENCIA := ["morrer", "andar_agachado", "agachado", "atirar", "mirar", "pular", "cair", "correr", "andar", "parado"]
const VEL_ANDAR := 0.3       # m/s acima disto = andando
const VEL_CORRER := 2.8      # m/s acima disto = correndo

# palavras (minúsculas) procuradas dentro do nome de cada animação; a primeira que casar vence
@export var palavras: Dictionary = {
	"parado": ["idle", "parado", "stand", "breath"],
	"andar": ["walk", "andar", "caminh"],
	"correr": ["run", "sprint", "correr", "jog"],
	"pular": ["jump", "pular", "pulo"],
	"cair": ["fall", "cair", "queda"],
	"mirar": ["aim", "mirar"],
	"atirar": ["shoot", "fire", "firing", "atirar", "tiro"],
	"morrer": ["death", "die", "dying", "morrer", "morte"],
	"andar_agachado": ["crouch walk", "crouched walk", "crouch_walk", "crouchwalk", "andar agachado", "sneak"],
	"agachado": ["crouch", "agach"],
}
# nome exato por estado (tem prioridade sobre as palavras). Ex.: {"correr": "Rifle Run"}
@export var nomes_exatos: Dictionary = {}
@export var mistura := 0.2    # segundos de transição entre animações

var _modelo: Node3D
var _ap: AnimationPlayer
var _esqueleto: Skeleton3D
var _ponto_arma: Node3D
var _atual := -1
var _achadas := {}            # Estado (int) -> nome da animação ("" = não achou)
var _nome_atual := ""
var _t_acao := 0.0            # ação no corpo todo tocando (segundos que faltam)
var _camada = null            # jogador/camada_acao.gd do modelo (parte de cima)
var _morte := ""
var _vel_h := 0.0
var _no_chao := true
const FUZIS := ["mp5", "m4", "ak", "espingarda", "rifle_caca"]
# ---- 1.12 · motion matching ----
const BaseMovCls := preload("res://jogador/base_movimento.gd")
const BUSCA_A_CADA := 0.1      # s entre buscas (e na hora, quando a animação atual não serve mais)
const MARGEM_TROCA := 0.08     # só troca se a melhor for este tanto melhor que continuar
var usar_mm := true
var _base = null               # jogador/base_movimento.gd (null = modelo sem a biblioteca: jeito antigo)
var _inercia = null            # jogador/camada_inercia.gd do modelo
var _orient = null             # jogador/camada_orientacao.gd do modelo
var _t_busca := 0.0
var _escala_mm := 1.0
var _yaw_ant := INF
var _giro := 0.0               # rad/s (suavizado): + = virando para a esquerda
var trocas_mm := 0               # quantas trocas a busca fez (teste)
var _pes_ant := PackedVector3Array()
var _i_pes := []
var _i_pelvis := -1
# velocidade (m/s) em que cada animação de andar/correr acompanha o chão (os pés não "patinam"): medida por
# ferramentas/medir_passos.gd (pé apoiado) e, nas capturas da CMU, pelo quanto a pessoa andou de verdade
const REF := {"andar": 1.0, "andar_lento": 0.95, "andar_normal": 1.6, "andar_rapido": 1.95, "trote": 3.35,
	"correr": 6.4, "correr_fuzil": 7.0, "andar_agachado": 0.76, "andar_espreita": 1.05, "mancar": 0.8,
	"andar_tras": 0.75, "andar_lado_esq": 0.5, "andar_lado_dir": 0.5}
# arma na mão -> postura dos braços (jogador/camada_postura.gd); fuzis ficam com o IK (jogador/ik_fuzil.gd)
const POSTURAS := {"pistola": "porte_pistola", "faca": "porte_branca", "facao": "porte_branca",
	"pe_de_cabra": "porte_branca", "taco": "porte_2m", "machado": "porte_2m", "cano": "porte_2m", "lanca": "porte_2m"}
# 0.60: mirando ANDANDO (parado usa a animação "mirar" do corpo todo): os braços apontam a arma para a frente
const POSTURAS_MIRA := {"pistola": "mira_pistola"}
var _postura = null           # jogador/camada_postura.gd do modelo
var _mancando := false
var _arma := ""
var _arma_ocupada := false    # golpeando, recarregando ou sacando: a postura sai

func configurar(modelo: Node3D) -> void:
	_modelo = modelo
	_ap = null
	_esqueleto = null
	_ponto_arma = null
	_atual = -1
	if modelo == null:
		return
	var aps := modelo.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		_ap = aps[0] as AnimationPlayer
	var sks := modelo.find_children("*", "Skeleton3D", true, false)
	if sks.size() > 0:
		_esqueleto = sks[0] as Skeleton3D
	_camada = modelo.get("camada")
	_postura = modelo.get("postura")
	_inercia = modelo.get("inercia")
	_orient = modelo.get("orientacao")
	_base = BaseMovCls.carregar(str(modelo.sexo())) if modelo.has_method("sexo") else null
	_i_pes = []
	_i_pelvis = -1
	if _esqueleto != null:
		_i_pelvis = _esqueleto.find_bone("pelvis")
		for o in ["foot_l", "foot_r"]:
			_i_pes.append(_esqueleto.find_bone(o))
	_pes_ant = PackedVector3Array()
	_nome_atual = ""
	_t_acao = 0.0
	_morte = ""
	_resolver()

# use depois de mudar nomes_exatos ou palavras
func atualizar_mapa() -> void:
	_resolver()

# decide, para cada estado, qual animação do modelo usar
func _resolver() -> void:
	_achadas.clear()
	_atual = -1
	if _ap == null:
		return
	var lista: Array[String] = []
	for n in _ap.get_animation_list():
		if not str(n).begins_with("RESET"):
			lista.append(str(n))
	# cada animação é classificada em UM estado, do mais específico ao mais geral
	# ("Falling Idle" vira "cair", não "parado"; "Running Jump" vira "pular")
	var por_estado := {}
	for n in lista:
		var baixo := n.to_lower()
		for chave in PRECEDENCIA:
			var casou := false
			for kw in palavras.get(chave, []):
				if baixo.contains(str(kw)):
					casou = true
					break
			if casou:
				if not por_estado.has(chave):
					por_estado[chave] = []
				por_estado[chave].append(n)
				break
	for e in Estado.values():
		var chave: String = NOMES[e]
		var escolhida := ""
		var exato := str(nomes_exatos.get(chave, ""))
		if exato != "" and _ap.has_animation(exato):
			escolhida = exato
		elif por_estado.has(chave):
			var cands: Array = por_estado[chave]
			cands.sort_custom(func(a, b): return a.length() < b.length() or (a.length() == b.length() and a < b))
			escolhida = cands[0]          # entre várias, o nome mais curto ("Run" antes de "Run Forward Left")
		_achadas[e] = escolhida
	# modelo com uma única animação de nome desconhecido: usa como "parado"
	if str(_achadas[Estado.PARADO]) == "" and lista.size() == 1:
		_achadas[Estado.PARADO] = lista[0]
	for e in Estado.values():
		var nome := str(_achadas[e])
		if nome != "":
			var a := _ap.get_animation(nome)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR if COM_LOOP.has(NOMES[e]) else Animation.LOOP_NONE

# animação de reserva quando a do estado não existe
func _nome_para(e: int) -> String:
	var nome := str(_achadas.get(e, ""))
	if nome != "":
		return nome
	match e:
		Estado.CORRER: return _nome_para(Estado.ANDAR)
		Estado.ANDAR: return _nome_para(Estado.PARADO)
		Estado.CAINDO: return _nome_para(Estado.PULAR)
		Estado.ATIRAR: return _nome_para(Estado.MIRAR)
		Estado.MIRAR: return _nome_para(Estado.PARADO)
		Estado.PULAR: return _nome_para(Estado.PARADO)
		Estado.MORRER: return _nome_para(Estado.PARADO)
		Estado.ANDAR_AGACHADO: return _nome_para(Estado.AGACHADO) if str(_achadas.get(Estado.AGACHADO, "")) != "" else _nome_para(Estado.ANDAR)
		Estado.AGACHADO: return _nome_para(Estado.PARADO)
	return ""

func decidir(vel_h: float, no_chao: bool, vel_v: float, mirando: bool, atirando: bool, morto: bool, agachado := false) -> int:
	if morto:
		return Estado.MORRER
	if not no_chao:
		return Estado.PULAR if vel_v > 0.5 else Estado.CAINDO
	if agachado:
		return Estado.ANDAR_AGACHADO if vel_h > VEL_ANDAR else Estado.AGACHADO
	if atirando:
		return Estado.ATIRAR
	if vel_h > VEL_CORRER:
		return Estado.CORRER
	if vel_h > VEL_ANDAR:
		return Estado.ANDAR
	if mirando:
		return Estado.MIRAR
	return Estado.PARADO

# chamar todo quadro com o jogador (lê velocidade, chão, agachado, mira, tiro, morte)
func atualizar(dt: float, j) -> void:
	if _ap == null:
		if _modelo != null and _modelo.has_method("atualizar_procedural"):
			_modelo.call("atualizar_procedural", dt, j)
		return
	var tiro_recente: bool = j.armas != null and j.armas.since < 0.25 and not (j.armas.eh_corpo() if j.armas.has_method("eh_corpo") else false)
	var mira: bool = j.mirando or (j.armas != null and j.armas.aim > 0.6)
	# direção do movimento em relação ao corpo (frente = -Z do jogador)
	var yaw: float = j.rotation.y
	var v: Vector3 = j.velocity
	var frente := Vector3(-sin(yaw), 0, -cos(yaw))
	var lado := Vector3(cos(yaw), 0, -sin(yaw))
	_dir = Vector2(v.dot(lado), v.dot(frente))
	_fuzil = j.armas != null and str(j.armas.atual) in FUZIS
	_arma = str(j.armas.atual) if j.armas != null else ""
	_mancando = bool(j.get("mancando")) if "mancando" in j else false
	_fp = bool(j.get("primeira_pessoa")) if "primeira_pessoa" in j else false
	usar_mm = bool(Config.valor("movimento_mm"))           # 1.12: Opções › Câmera › Movimento do personagem
	# 1.12: quanto o corpo está girando (inclinar na curva)
	if _yaw_ant != INF and dt > 0.0:
		_giro = lerpf(_giro, wrapf(yaw - _yaw_ant, -PI, PI) / dt, minf(1.0, dt * 8.0))
	_yaw_ant = yaw
	# 0.72: nadando (jogador/jogador.gd): a braçada no lugar de tudo
	if bool(j.get("nadando")):
		_nadar(j.vel_horizontal, bool(j.get("afundando")))
		return
	_arma_ocupada = false
	if j.armas != null:
		for campo in ["golpe", "rel", "draw"]:
			var valor = j.armas.get(campo)
			if valor != null and float(valor) > 0.0:
				_arma_ocupada = true
	atualizar_estado(dt, j.vel_horizontal, j.is_on_floor(), j.velocity.y, mira, tiro_recente, j.morto, j.agachado)

# nado de peito (animação "nadar"): parado boiando = braçada lenta; afundando = braçada desesperada
func _nadar(vel_h: float, afundando: bool) -> void:
	_t_acao = 0.0
	_vel_h = vel_h
	_no_chao = false
	_atual = Estado.PARADO
	var nome := "nadar" if _tem("nadar") else _nome_para(Estado.PARADO)
	if nome != "" and nome != _nome_atual:
		_nome_atual = nome
		_ap.play(nome, 0.35)
	_ap.speed_scale = clampf(0.35 + vel_h / 1.5, 0.35, 1.7) * (1.7 if afundando else 1.0)
	if _postura != null:
		_postura.usar("", false)

var _dir := Vector2.ZERO      # (lado, frente) da velocidade em relação ao corpo
var _fp := false             # 0.65: 1ª pessoa (o corpo fica virado para a câmera: pernas em 8 direções sempre)
var _fuzil := false

func _tem(n: String) -> bool:
	return n != "" and _ap != null and _ap.has_animation(n)

func atualizar_estado(dt: float, vel_h: float, no_chao: bool, vel_v: float, mirando: bool, atirando: bool, morto: bool, agachado := false) -> void:
	if _ap == null:
		return
	_vel_h = vel_h
	_no_chao = no_chao
	# ação no corpo todo (pegar do chão, comer parado...): espera acabar; se começar a correr, corta
	if _t_acao > 0.0:
		_t_acao -= dt
		if morto or vel_h > 1.2 or not no_chao:
			_t_acao = 0.0
		else:
			if _postura != null:
				_postura.usar("", false)         # a ação usa os braços: a postura da arma sai
			return
	var e := decidir(vel_h, no_chao, vel_v, mirando, atirando, morto, agachado)
	_atual = e
	# 1.12: motion matching (parado, andando, correndo, agachado; mirando/atirando só andando)
	if _base != null and usar_mm and no_chao and not morto and not (mirando and _fuzil and vel_h <= VEL_ANDAR) \
			and (e in [Estado.PARADO, Estado.ANDAR, Estado.CORRER, Estado.AGACHADO, Estado.ANDAR_AGACHADO] \
			or (e in [Estado.MIRAR, Estado.ATIRAR] and vel_h > VEL_ANDAR)):
		_morte = ""
		_motion_matching(dt, mirando or atirando or _fp, agachado)
		_atualizar_postura(e, vel_h, mirando, atirando)
		return
	_orientar(0.0, 0.0)
	var nome := _nome_para(e)
	var escala := 1.0
	match e:
		Estado.ANDAR:
			nome = _andar_por_velocidade(vel_h) if _andar_por_velocidade(vel_h) != "" else nome
			escala = _escala(nome, vel_h)
		Estado.ANDAR_AGACHADO:
			# 1.04: agachado rápido continua com a animação AGACHADA (mais depressa). A "andar_espreita" é uma caminhada
			# de pé: com ela o personagem "levantava" andando agachado (a câmera e o resto continuavam agachados)
			escala = _escala(nome, vel_h)
		Estado.CORRER:
			if vel_h < 5.0 and _andar_por_velocidade(vel_h) != "":
				nome = _andar_por_velocidade(vel_h)
			elif _fuzil and _tem("correr_fuzil"):
				nome = "correr_fuzil"
			escala = _escala(nome, vel_h)
		Estado.MIRAR, Estado.PARADO:
			if mirando and _fuzil and _tem("mirar_fuzil"):
				nome = "mirar_fuzil"
		Estado.MORRER:
			if _morte == "":
				var op: Array = ["morrer", "morrer_a", "morrer_b"].filter(func(x): return _tem(x))
				_morte = op[randi() % op.size()] if not op.is_empty() else nome
			nome = _morte
	if e != Estado.MORRER:
		_morte = ""
	# 8 direções: mirando/atirando e andando, as pernas seguem a direção em relação ao corpo (para trás, passos de
	# lado para a direita/esquerda, ou a caminhada da velocidade)
	if (mirando or atirando or _fp) and no_chao and not agachado and not morto and vel_h > VEL_ANDAR:
		var ang := atan2(_dir.x, _dir.y)               # 0 = frente, + = direita
		if absf(ang) > 2.25 and _tem("andar_tras"):
			nome = "andar_tras"
		elif ang > 0.95 and _tem("andar_lado_dir"):
			nome = "andar_lado_dir"
		elif ang < -0.95 and _tem("andar_lado_esq"):
			nome = "andar_lado_esq"
		elif vel_h <= VEL_CORRER and _andar_por_velocidade(vel_h) != "":
			nome = _andar_por_velocidade(vel_h)
		escala = _escala(nome, vel_h)
	if nome != "" and nome != _nome_atual:
		_nome_atual = nome
		if _inercia != null and usar_mm:
			_ap.play(nome, 0.0)                    # 1.12: troca na hora; a camada de inércia suaviza
			_inercia.disparar()
		else:
			_ap.play(nome, 0.1 if e == Estado.MORRER else mistura)
	_ap.speed_scale = escala
	_atualizar_postura(e, vel_h, mirando, atirando)

# ---------- 1.12 · MOTION MATCHING ----------
func _permitidas(livre_dir: bool, agachado: bool) -> Array:
	if agachado:
		return ["agachado", "andar_agachado"]
	if _mancando:
		return ["parado", "mancar"]
	var l := ["parado", "andar_lento", "andar_normal", "andar_rapido", "trote",
		"correr_fuzil" if _fuzil and _base.tem("correr_fuzil") else "correr"]
	if livre_dir:
		l.append_array(["andar_tras", "andar_lado_dir", "andar_lado_esq"])
	return l

func _motion_matching(dt: float, livre_dir: bool, agachado: bool) -> void:
	var perm := _permitidas(livre_dir, agachado)
	var atual_ok: bool = perm.has(_nome_atual) and _base.tem(_nome_atual)
	# corpo virado para o movimento (sem mira): tudo é "para a frente"; mirando, a direção vale (frente, lado, costas)
	var vel := _dir if livre_dir else Vector2(0.0, _dir.length())
	var viva := _pose_viva(dt)
	_t_busca -= dt
	if _t_busca <= 0.0 or not atual_ok:
		_t_busca = BUSCA_A_CADA
		var q: PackedFloat32Array = _base.quadro(_nome_atual, _ap.current_animation_position) if atual_ok else viva
		var s_q := _escala_mm if atual_ok else 1.0
		var r: Array = _base.buscar(perm, vel, q, s_q)
		if r[0] != "" and (not atual_ok or (r[0] != _nome_atual and float(r[3]) < _base.custo_continuar(_nome_atual, vel) - MARGEM_TROCA)):
			_nome_atual = r[0]
			trocas_mm += 1
			if _inercia != null:
				_ap.play(r[0], 0.0)
				_ap.seek(float(r[1]), true)
				_inercia.disparar()
			else:
				_ap.play(r[0], mistura)
				_ap.seek(float(r[1]), true)
	if _base.tem(_nome_atual):
		_escala_mm = _base.escala(_nome_atual, vel.length())
		_ap.speed_scale = _escala_mm
		# pernas na direção do passo (o que a animação não cobre) e inclinar na curva
		var d: Vector2 = _base.clipes[_nome_atual]["dir"]
		var ang := 0.0
		if d.length() > 0.1 and _dir.length() > VEL_ANDAR:
			ang = wrapf(atan2(_dir.x, _dir.y) - atan2(d.x, d.y), -PI, PI)
		_orientar(ang, -_giro * _vel_h * 0.015 if d.length() > 0.1 else 0.0)

func _orientar(ang: float, inclina: float) -> void:
	if _orient != null:
		_orient.angulo = ang
		_orient.inclinacao = inclina

# pés agora (do esqueleto), no mesmo formato da biblioteca (posições + velocidades por segundo)
func _pose_viva(dt: float) -> PackedFloat32Array:
	var q := PackedFloat32Array()
	q.resize(12)
	if _esqueleto == null or _i_pelvis < 0 or _i_pes.size() < 2:
		return q
	var p0 := _esqueleto.get_bone_global_pose(_i_pelvis).origin
	var agora := PackedVector3Array()
	for k in 2:
		var p := _esqueleto.get_bone_global_pose(_i_pes[k]).origin - Vector3(p0.x, 0.0, p0.z)
		agora.append(p)
		q[k * 3] = p.x
		q[k * 3 + 1] = p.y
		q[k * 3 + 2] = p.z
		if _pes_ant.size() == 2 and dt > 0.0:
			var v := (p - _pes_ant[k]) / dt
			q[6 + k * 3] = v.x
			q[6 + k * 3 + 1] = v.y
			q[6 + k * 3 + 2] = v.z
	_pes_ant = agora
	return q

# velocidade da animação para os pés acompanharem o chão (REF); fora da tabela, 1
func _escala(nome: String, vel_h: float) -> float:
	if not REF.has(nome):
		return 1.0
	return clampf(vel_h / float(REF[nome]), 0.5, 2.2)

# caminhada pela velocidade (devagar, normal, apressada, trote); perna quebrada = mancar
func _andar_por_velocidade(v: float) -> String:
	var op := ""
	if _mancando:
		op = "mancar"
	elif v < 1.3:
		op = "andar_lento"
	elif v < 1.8:
		op = "andar_normal"
	elif v < 2.7:
		op = "andar_rapido"
	elif v < 5.0:
		op = "trote"
	return op if _tem(op) and REF.has(op) else ""

# braços segurando a arma do jeito dela (porte) ou apontando (mira andando). Sem postura ao golpear, recarregar,
# correr, no ar ou numa ação (comer, pegar...)
func _atualizar_postura(e: int, vel_h: float, mirando: bool, atirando: bool) -> void:
	if _postura == null:
		return
	var nome := ""
	var livre := not _arma_ocupada and not tocando_acao() and vel_h < 5.0 \
		and e in [Estado.PARADO, Estado.ANDAR, Estado.CORRER, Estado.AGACHADO, Estado.ANDAR_AGACHADO, Estado.MIRAR, Estado.ATIRAR]
	if livre:
		if mirando or atirando:
			# parado mirando, a animação "mirar"/"atirar" do corpo todo já aponta a arma
			if vel_h > VEL_ANDAR or e in [Estado.AGACHADO, Estado.ANDAR_AGACHADO]:
				nome = POSTURAS_MIRA.get(_arma, "")
		else:
			nome = POSTURAS.get(_arma, "")
	_postura.usar(nome, nome != "")

# 1.01: item na mão sem animação (mirando o arremesso: armas/arremesso.gd chama todo quadro enquanto mira)
func manter_item(id: String, duracao := 0.2) -> void:
	if _modelo != null and _modelo.has_method("manter_item"):
		_modelo.manter_item(id, duracao)

# AÇÃO por cima do estado: recarregar, golpe, pegar, comer... (nome da animação, velocidade).
# corpo_todo: parado usa o corpo todo; andando/correndo vira camada só na parte de cima.
# 0.61: "comer:feijao" = a ação com o ITEM na mão (o modelo mostra o item na mão direita enquanto ela dura)
func acao(nome: String, velocidade := 1.0, corpo_todo := true) -> void:
	var item := nome.get_slice(":", 1) if nome.contains(":") else ""
	var anim := nome.get_slice(":", 0)
	if not _tem(anim):
		return
	tocou_acao.emit(nome, velocidade, corpo_todo)
	nome = anim
	var a := _ap.get_animation(nome)
	if item != "" and _modelo != null and _modelo.has_method("segurar_item"):
		_modelo.segurar_item(item, a.length / maxf(velocidade, 0.05))
	var parado := _vel_h < 0.6 and _no_chao
	if corpo_todo and parado:
		if _camada != null:
			_camada.parar()
		_ap.play(nome, 0.12)
		_ap.speed_scale = velocidade
		_nome_atual = nome
		_t_acao = a.length / maxf(velocidade, 0.05)
	elif _camada != null:
		_camada.tocar(a, velocidade)

func tocando_acao() -> bool:
	return _t_acao > 0.0 or (_camada != null and _camada.tocando())

# adiciona ao modelo as animações de arquivos separados (.glb/.gltf/.fbx/.tscn) de uma pasta.
# Arquivo com UMA animação: ela ganha o nome do arquivo ("Rifle Run.glb" -> "Rifle Run").
# As trilhas precisam apontar para os mesmos ossos do modelo (mesmo esqueleto, ex.: tudo do Mixamo).
func importar_animacoes(pasta: String) -> int:
	if _ap == null or not DirAccess.dir_exists_absolute(pasta):
		return 0
	var lib: AnimationLibrary = _ap.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		_ap.add_animation_library("", lib)
	var vistos := {}
	var total := 0
	for arq in DirAccess.get_files_at(pasta):
		var nome_arq: String = arq
		if nome_arq.ends_with(".import") or nome_arq.ends_with(".remap"):
			nome_arq = nome_arq.get_basename()
		if vistos.has(nome_arq):
			continue
		if not (nome_arq.get_extension().to_lower() in ["glb", "gltf", "fbx", "tscn", "scn"]):
			continue
		vistos[nome_arq] = true
		var res = load(pasta.path_join(nome_arq))
		if not (res is PackedScene):
			continue
		var inst: Node = (res as PackedScene).instantiate()
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			var nomes: Array[String] = []
			for n in (ap as AnimationPlayer).get_animation_list():
				if not str(n).begins_with("RESET"):
					nomes.append(str(n))
			for n in nomes:
				var final_nome := nome_arq.get_basename() if nomes.size() == 1 else n
				if lib.has_animation(final_nome):
					continue
				lib.add_animation(final_nome, (ap as AnimationPlayer).get_animation(n).duplicate())
				total += 1
		inst.free()
	_resolver()
	return total

# onde prender a arma: osso da mão direita do esqueleto (o soldado original segura a arma pelo tronco)
func ponto_arma() -> Node3D:
	if _ponto_arma != null and is_instance_valid(_ponto_arma):
		return _ponto_arma
	if _modelo != null and _modelo.has_method("pegar_ponto_arma"):
		_ponto_arma = _modelo.call("pegar_ponto_arma")
		return _ponto_arma
	if _esqueleto != null:
		var osso := _achar_osso(["righthand", "handr", "rhand"])
		if osso >= 0:
			var ba := BoneAttachment3D.new()
			ba.name = "PontoArma"
			_esqueleto.add_child(ba)
			ba.bone_name = _esqueleto.get_bone_name(osso)
			_ponto_arma = ba
			return ba
	return _modelo

func _achar_osso(finais: Array) -> int:
	for i in _esqueleto.get_bone_count():
		var s := _esqueleto.get_bone_name(i).to_lower().replace("_", "").replace(":", "").replace(".", "").replace(" ", "").replace("-", "")
		for f in finais:
			if s.ends_with(str(f)):
				return i
	return -1
