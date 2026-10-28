extends Node3D
# JOGADOR REMOTO · o boneco de OUTRO jogador da partida (multijogador do modo livre).
# É o mesmo sobrevivente do jogador (jogador/modelo_sobrevivente.gd) com o mesmo animador
# (jogador/animador_modelo.gd), mas sem física nem controles: só segue o que chega pela rede
# (rede/sessao_rede.gd), suavizado (interpolação ATRASO segundos no passado, para não tremer).
# Mostra o nome em cima da cabeça, a roupa equipada e a arma das mãos.
# 0.71 · PvP: tem um ALVO (rede/alvo_jogador.gd) que os tiros e golpes acertam; o dano vai para o aparelho dele.
# Mexa AQUI para: atraso da interpolação, altura/tamanho do nome.

const SobreviventeCls := preload("res://jogador/modelo_sobrevivente.gd")
const AnimadorCls := preload("res://jogador/animador_modelo.gd")
const ModelosArmas := preload("res://armas/modelos_armas.gd")
const ItemCls := preload("res://inventario/item.gd")
const AlvoCls := preload("res://rede/alvo_jogador.gd")
const VeiculoCls := preload("res://mundo/veiculo.gd")
const ATRASO := 0.12                           # segundos (2 pacotes a 15/s)
const FUZIS := ["mp5", "m4", "ak", "espingarda", "rifle_caca"]

var id := 0
var nome := ""
var sessao = null                              # rede/sessao_rede.gd (manda o dano do PvP)
var alvo                                       # rede/alvo_jogador.gd
# --- lidos pelo animador_modelo.gd (mesmos nomes do jogador/jogador.gd) ---
var velocity := Vector3.ZERO
var vel_horizontal := 0.0
var mirando := false
var agachado := false
var mancando := false
var nadando := false                           # 0.72
var afundando := false
var protegido := false                         # 0.91: na zona neutra do hospital ou na trégua (não fere nem é ferido)
var mutado := false                            # 0.94: mutado (bit 512): os infectados ignoram, corpo do mutado
var falando := false:                          # 0.97: chat de voz (rede/voz.gd): ")))" junto do nome
	set(v):
		if v != falando and _rotulo != null:
			_rotulo.text = (nome + "  )))") if v else nome
			_rotulo.modulate = Color(0.55, 1.0, 0.55) if v else Color.WHITE
		falando = v
var mira_pitch := 0.0
var morto := false
var armas := _Armas.new()
var _no_chao := true

var modelo: Node3D                            # o sobrevivente
var animador: Node
var _slot: Node3D
var _rotulo: Label3D
var _amostras: Array = []                     # [[tempo, pos, yaw], ...]
var _relogio := 0.0
var _armas_3d := {}                           # tipo -> Node3D
var dirigindo_id := ""                         # 0.76: carro que ele está dirigindo ("" = a pé)
var _carro = null                              # cópia do carro (mundo/veiculo.gd remoto, sem física própria)
var _rot_carro := Vector3.ZERO
var _arma_atual := ""

func _ready() -> void:
	add_to_group("jogadores_remotos")          # os infectados do host caçam os amigos também (inimigos/vagos.gd)
	add_to_group("pausa_por_chunk")            # longe: para só a animação (mundo/chunks.gd chama pausar_por_chunk)
	_slot = Node3D.new()
	_slot.name = "Modelo"
	add_child(_slot)
	modelo = SobreviventeCls.new()
	modelo.name = "Sobrevivente"
	modelo.rotation_degrees.y = 180.0          # como no jogador (modelos olham para +Z)
	_slot.add_child(modelo)
	animador = AnimadorCls.new()
	animador.name = "Animador"
	add_child(animador)
	animador.configurar(modelo)
	animador.nomes_exatos = modelo.NOMES_ANIM
	animador.atualizar_mapa()
	_rotulo = Label3D.new()
	_rotulo.text = nome
	_rotulo.position.y = 2.05
	_rotulo.pixel_size = 0.0035
	_rotulo.font_size = 48
	_rotulo.outline_size = 12
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.no_depth_test = true
	_rotulo.fixed_size = false
	_rotulo.modulate = Color("#ffe9d0")
	add_child(_rotulo)
	alvo = AlvoCls.new()
	alvo.name = "Alvo"
	alvo.dono = self
	add_child(alvo)
	vestir({})

func is_on_floor() -> bool:
	return _no_chao

# PvP: um tiro/golpe MEU acertou este jogador. A reação aparece já aqui; o dano é decidido no aparelho dele.
func levar_dano(dano: float, cabeca: bool, direcao: Vector3, golpe: bool) -> Dictionary:
	if morto or sessao == null:
		return {"cabeca": false, "morto": false}
	if not sessao.mandar_pvp(id, dano, cabeca, direcao, golpe):
		return {"cabeca": false, "morto": false}              # PvP desligado aqui (fora da zona): não conta acerto
	animador.acao(["levar_golpe_a", "levar_golpe_b"][randi() % 2], 1.3, false)
	return {"cabeca": cabeca, "morto": false}

# um infectado do HOST mordeu este amigo: o dano vai para o aparelho dele (rede/sessao_rede.gd "mordida")
func receber_ataque(dano: float, chance_sangrar: float, origem: Vector3, tipo := "") -> void:
	Rede.enviar_evento("mordida", {"d": dano, "c": chance_sangrar, "o": origem, "t": tipo}, id)

# 0.89: um infectado do host agarrou este amigo (ele anda devagar um instante no aparelho dele)
func agarrar(t: float) -> void:
	Rede.enviar_evento("agarrado", {"t": t}, id)

# ---------- o que chega pela rede ----------
# estado (rede/sessao_rede.gd monta): [pos, yaw, vel, bits, arma, aim, since]
func receber_estado(d: Array) -> void:
	if d.size() < 7:
		return
	var pos: Vector3 = d[0]
	if _amostras.is_empty():
		global_position = pos
		rotation.y = float(d[1])
		_relogio = 0.0
	_amostras.append([_relogio + ATRASO, pos, float(d[1])])
	if _amostras.size() > 20:
		_amostras.pop_front()
	velocity = d[2]
	vel_horizontal = Vector2(velocity.x, velocity.z).length()
	var b := int(d[3])
	agachado = b & 1 != 0
	mirando = b & 2 != 0
	morto = b & 4 != 0
	_no_chao = b & 8 == 0
	mancando = b & 16 != 0
	nadando = b & 32 != 0
	afundando = b & 64 != 0
	protegido = b & 256 != 0
	if (b & 512 != 0) != mutado:
		mutado = b & 512 != 0
		if modelo != null and modelo.has_method("definir_mutacao"):
			modelo.definir_mutacao(1 if mutado else 0)
	armas.aim = float(d[5])
	armas.since = float(d[6])
	mira_pitch = float(d[7]) if d.size() > 7 else 0.0
	var vid := str(d[8]) if d.size() > 8 and b & 128 != 0 else ""
	if d.size() > 9:
		_rot_carro = d[9]
	if vid != dirigindo_id:
		_trocar_carro(vid)
	_mostrar_arma(str(d[4]))

# roupa: slot -> id do item ("" = vazio)
func vestir(slots: Dictionary) -> void:
	var eq := _Equip.new()
	for s in slots:
		if str(slots[s]) != "":
			eq.slots[s] = ItemCls.novo(str(slots[s]))
	modelo.vestir(eq)

func tocar_acao(nm: String, vel: float, corpo_todo: bool) -> void:
	animador.acao(nm, vel, corpo_todo)

func definir_nome(n: String) -> void:
	nome = n
	if _rotulo != null:
		_rotulo.text = n

# boca do cano da arma na mão (para o traçante do tiro)
func cano() -> Vector3:
	var n: Node3D = _armas_3d.get(_arma_atual)
	var c := n.get_node_or_null("Cano") as Node3D if n != null else null
	return c.global_position if c != null else global_position + Vector3(0, 1.4, 0)

func _mostrar_arma(tipo: String) -> void:
	armas.atual = tipo
	if tipo == _arma_atual:
		return
	_arma_atual = tipo
	if tipo != "" and tipo != "punhos" and not _armas_3d.has(tipo):
		var n := ModelosArmas.construir(tipo)
		modelo.segurar_arma(tipo, n)
		_armas_3d[tipo] = n
	for t in _armas_3d:
		(_armas_3d[t] as Node3D).visible = t == tipo and not nadando

# ---------- movimento suave ----------
func _process(dt: float) -> void:
	_relogio += dt
	# acha as duas amostras em volta de "agora" e mistura
	while _amostras.size() > 2 and float(_amostras[1][0]) <= _relogio:
		_amostras.pop_front()
	if _amostras.size() >= 2:
		var a: Array = _amostras[0]
		var b: Array = _amostras[1]
		var k := clampf((_relogio - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
		global_position = (a[1] as Vector3).lerp(b[1], k)
		rotation.y = lerp_angle(float(a[2]), float(b[2]), k)
	elif _amostras.size() == 1:
		global_position = global_position.lerp(_amostras[0][1], minf(1.0, dt * 10.0))
		rotation.y = lerp_angle(rotation.y, float(_amostras[0][2]), minf(1.0, dt * 10.0))
	armas.since += dt
	if _carro != null and is_instance_valid(_carro):
		_carro.global_position = global_position - Vector3(0, 1.0, 0)
		_carro.quaternion = _carro.quaternion.slerp(Quaternion.from_euler(_rot_carro), minf(1.0, dt * 12.0))
	if _arma_atual != "" and _armas_3d.has(_arma_atual) and (_armas_3d[_arma_atual] as Node3D).visible == nadando:
		(_armas_3d[_arma_atual] as Node3D).visible = not nadando      # 0.72: nadando, a arma some
	if alvo != null:
		alvo.atualizar(agachado, visible and not morto and dirigindo_id == "")
	if not _pausado:
		animador.atualizar(dt, self)

# fora dos chunks ativos: o boneco não anima (a posição continua seguindo a rede: os infectados do host usam)
var _pausado := false
func pausar_por_chunk(p: bool) -> void:
	if p == _pausado:
		return
	_pausado = p
	_slot.process_mode = Node.PROCESS_MODE_DISABLED if p else Node.PROCESS_MODE_INHERIT

# o que o animador e o modelo leem de "armas" no jogador de verdade
class _Armas extends RefCounted:
	var atual := ""
	var aim := 0.0
	var since := 9.0
	func eh_corpo() -> bool:
		return atual in ["punhos", "faca", "machado", "taco", "lanca", "facao", "cano", "pe_de_cabra"]

class _Equip extends RefCounted:
	var slots := {}

# 0.76: entrou/saiu de um carro: mostra a cópia do carro (o boneco some) ou tira
func _trocar_carro(vid: String) -> void:
	if _carro != null and is_instance_valid(_carro):
		_carro.queue_free()
	_carro = null
	dirigindo_id = vid
	_slot.visible = vid == ""
	if vid == "" or sessao == null or sessao.main.get("veiculos") == null:
		return
	var vm = sessao.main.veiculos
	var dd: Dictionary = vm.dados(vid)
	vm.remoto_entrou(vid, id)
	var c = VeiculoCls.new()
	c.remoto = true
	c.id = vid
	c.tipo = str(dd.get("t", "sedan"))
	c.cor = Color.html(str(dd.get("cor", "ffffff")))
	c.name = "CarroDe_%d" % id
	sessao.main.jogo.add_child(c)
	c.global_position = global_position - Vector3(0, 1.0, 0)
	c.rotation = _rot_carro
	_carro = c

func _exit_tree() -> void:
	if _carro != null and is_instance_valid(_carro):
		_carro.queue_free()
