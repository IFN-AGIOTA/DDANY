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
#     (andar_tras) ou de lado (correr_esq / correr_dir), escolhendo pela direção do movimento em relação ao corpo;
#   · fuzil na mão: correr_fuzil e mirar_fuzil;
#   · AÇÕES (acao()): recarregar, golpes, pegar do chão, comer/beber, curar, levar golpe. Parado = corpo todo;
#     andando = só a parte de cima (jogador/camada_acao.gd), as pernas continuam;
#   · morte com 3 variações.
#   · 0.59 · CAMINHADAS por velocidade (captura de movimento real da CMU, ferramentas/retarget_cmu.gd):
#     devagar (andar_lento) · normal (andar_normal) · apressada (andar_rapido) · trote · corrida; agachado devagar =
#     andar_agachado, agachado rápido = andar_espreita; perna quebrada = mancar. Cada uma com a velocidade de
#     referência em REF (a animação acompanha o chão sem "patinar").
#   · 0.59 · POSTURA DA ARMA (jogador/camada_postura.gd): com pistola, faca/facão/pé de cabra ou taco/machado/
#     cano/lança na mão, os braços seguram a arma do jeito dela por cima de qualquer caminhada (POSTURAS).

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
const FUZIS := ["m4", "ak", "espingarda", "rifle_caca"]
# velocidade (m/s) em que cada animação de andar acompanha o chão
const REF := {"andar_lento": 0.95, "andar_normal": 1.6, "andar_rapido": 1.9, "trote": 3.4, "andar_espreita": 1.2,
	"mancar": 0.7}
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
	_arma_ocupada = false
	if j.armas != null:
		for campo in ["golpe", "rel", "draw"]:
			var valor = j.armas.get(campo)
			if valor != null and float(valor) > 0.0:
				_arma_ocupada = true
	atualizar_estado(dt, j.vel_horizontal, j.is_on_floor(), j.velocity.y, mira, tiro_recente, j.morto, j.agachado)

var _dir := Vector2.ZERO      # (lado, frente) da velocidade em relação ao corpo
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
			return
	var e := decidir(vel_h, no_chao, vel_v, mirando, atirando, morto, agachado)
	_atual = e
	var nome := _nome_para(e)
	var escala := 1.0
	match e:
		Estado.ANDAR:
			escala = clampf(vel_h / 1.7, 0.7, 1.5)
			var n_andar := _andar_por_velocidade(vel_h)
			if n_andar != "":
				nome = n_andar
				escala = clampf(vel_h / float(REF[n_andar]), 0.6, 1.6)
		Estado.ANDAR_AGACHADO:
			escala = clampf(vel_h / 1.0, 0.7, 1.6)
			if vel_h > 1.4 and _tem("andar_espreita"):
				nome = "andar_espreita"
				escala = clampf(vel_h / float(REF["andar_espreita"]), 0.7, 1.6)
		Estado.CORRER:
			escala = clampf(vel_h / 5.5, 0.8, 1.5)
			if vel_h < 5.0:
				var n_trote := _andar_por_velocidade(vel_h)
				if n_trote != "":
					nome = n_trote
					escala = clampf(vel_h / float(REF[n_trote]), 0.6, 1.6)
			if _fuzil and _tem("correr_fuzil") and vel_h >= 5.0:
				nome = "correr_fuzil"
				escala = clampf(vel_h / 4.5, 0.8, 1.4)
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
	# 8 direções: mirando/atirando e andando, as pernas seguem a direção em relação ao corpo
	if (mirando or atirando) and no_chao and not agachado and not morto and vel_h > VEL_ANDAR:
		var ang := atan2(_dir.x, _dir.y)               # 0 = frente, + = direita
		if absf(ang) > 2.25 and _tem("andar_tras"):
			nome = "andar_tras"
			escala = clampf(vel_h / 1.5, 0.7, 1.8)
		elif ang > 0.95 and _tem("correr_dir"):
			nome = "correr_dir"
			escala = clampf(vel_h / 4.0, 0.55, 1.4)
		elif ang < -0.95 and _tem("correr_esq"):
			nome = "correr_esq"
			escala = clampf(vel_h / 4.0, 0.55, 1.4)
		elif vel_h <= VEL_CORRER:
			nome = _nome_para(Estado.ANDAR)
			escala = clampf(vel_h / 1.7, 0.7, 1.5)
	if nome != "" and nome != _nome_atual:
		_nome_atual = nome
		_ap.play(nome, 0.1 if e == Estado.MORRER else mistura)
	_ap.speed_scale = escala
	_atualizar_postura(e, vel_h, mirando, atirando)

# caminhada pela velocidade (devagar, normal, apressada, trote); perna quebrada = mancar
func _andar_por_velocidade(v: float) -> String:
	var op := ""
	if _mancando:
		op = "mancar"
	elif v < 1.3:
		op = "andar_lento"
	elif v < 1.8:
		op = "andar_normal"
	elif v < 2.8:
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

# AÇÃO por cima do estado: recarregar, golpe, pegar, comer... (nome da animação, velocidade).
# corpo_todo: parado usa o corpo todo; andando/correndo vira camada só na parte de cima.
func acao(nome: String, velocidade := 1.0, corpo_todo := true) -> void:
	if not _tem(nome):
		return
	tocou_acao.emit(nome, velocidade, corpo_todo)
	var a := _ap.get_animation(nome)
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
