extends Node
# ANIMADOR DO MODELO · liga o estado do jogador (parado, andando, correndo, no ar...) às animações do modelo.
# Funciona com QUALQUER modelo que tenha um AnimationPlayer (GLB/GLTF/FBX importado, ex.: Mixamo):
#   1) procura as animações pelo NOME (palavras-chave abaixo: "idle", "walk", "run", "jump"...);
#   2) se faltar alguma, usa a mais parecida (correr -> andar -> parado ...);
#   3) se o modelo NÃO tiver AnimationPlayer (o soldado original), usa a animação por código dele.
# Animações em arquivos separados (como o Mixamo entrega): coloque em res://modelos/animacoes/ e elas são
# adicionadas ao modelo sozinhas (veja importar_animacoes).
# Para fixar nomes exatos: animador.nomes_exatos["correr"] = "Rifle Run"

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
	_resolver()

# use depois de mudar nomes_exatos ou palavras
func atualizar_mapa() -> void:
	_resolver()

func tem_animation_player() -> bool:
	return _ap != null

func animacoes_disponiveis() -> PackedStringArray:
	if _ap == null:
		return PackedStringArray()
	return _ap.get_animation_list()

func animacao_do_estado(e: int) -> String:
	return str(_achadas.get(e, ""))

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
	var tiro_recente: bool = j.armas != null and j.armas.since < 0.25
	atualizar_estado(dt, j.vel_horizontal, j.is_on_floor(), j.velocity.y, j.mirando or (j.armas != null and j.armas.aim > 0.6), tiro_recente, j.morto, j.agachado)

func atualizar_estado(dt: float, vel_h: float, no_chao: bool, vel_v: float, mirando: bool, atirando: bool, morto: bool, agachado := false) -> void:
	if _ap == null:
		return
	var e := decidir(vel_h, no_chao, vel_v, mirando, atirando, morto, agachado)
	if e != _atual:
		_atual = e
		var nome := _nome_para(e)
		if nome != "" and _ap.current_animation != nome:
			_ap.play(nome, 0.1 if e == Estado.MORRER else mistura)
	if _atual == Estado.ANDAR:
		_ap.speed_scale = clampf(vel_h / 1.7, 0.7, 1.5)
	elif _atual == Estado.ANDAR_AGACHADO:
		_ap.speed_scale = clampf(vel_h / 1.0, 0.7, 1.6)
	elif _atual == Estado.CORRER:
		_ap.speed_scale = clampf(vel_h / 5.5, 0.8, 1.5)
	else:
		_ap.speed_scale = 1.0

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
