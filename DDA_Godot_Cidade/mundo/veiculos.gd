extends Node
# VEÍCULOS (0.76): alguns carros largados FUNCIONAM (sedã, táxi e van inteiros: nem queimados, nem capotados, nem
# tombados; CHANCE deles, sempre os mesmos em todo aparelho: a escolha vem da posição do carro).
#   - Perto de um (RAIO_ENTRAR), o botão PEGAR (E) vira "ENTRAR NO CARRO"; dentro, "SAIR DO CARRO".
#   - Ao entrar, o carro largado vira um mundo/veiculo.gd (física de carro) no mesmo lugar; o obstáculo e o desenho
#     do largado somem. Saindo, ele fica ESTACIONADO onde parou (guardado em mundo/loot_mundo.gd "veiculos": vai no
#     jogo salvo e, na rede, para todos). Estacionado longe do jogador vira estátua (sem física).
#   - COMBUSTÍVEL: cada carro tem um pouco (0 a COMB_MAX litros, às vezes nada). GALÃO DE GASOLINA (item): USAR perto
#     do carro = abastecer; PEGAR perto de uma BOMBA de posto com o galão = encher (algumas bombas estão secas).
#   - Painel embaixo da tela enquanto dirige: velocidade, gasolina e estado do motor.
#   - Multijogador (rede/sessao_rede.gd): quem dirige manda a posição do carro junto com a dele; os outros veem o carro
#     andando ("dirigindo" no estado); ao sair, "veiculo" manda o carro estacionado para todos. Carro ocupado não abre.
# Mexa AQUI para: quantos carros funcionam, gasolina inicial, distâncias, painel.

const VeiculoCls := preload("res://mundo/veiculo.gd")
const UI := preload("res://menu/ui.gd")

const CHANCE := 0.045                    # dos carros inteiros que podem funcionar
const CHANCE_MILITAR := 0.25             # 1.08: do humvee e do caminhão dos comboios do Exército (mundo/comboios.gd)
const COMB_MAX := 9.0                    # litros que um carro largado pode ter
const RAIO_ENTRAR := 3.2
const RAIO_BOMBA := 1.9
const RAIO_MONTAR := 230.0               # estacionados (mexidos) aparecem a até essa distância
const RAIO_FISICA := 30.0                # estacionado mais longe que isso: sem física (estátua)
const CEL := 50.0
const LITROS_GALAO := 10.0

var cidade = null
var mundo = null
var jogador: Node3D = null
var loot = null
var vagos = null
var ab = null                            # mundo/abandono.gd
var _ids := {}                           # id -> índice em abandono.carros (só os que funcionam)
var _hash := {}                          # Vector2i -> Array de ids
var nos := {}                            # id -> veículo montado (estacionado perto ou sendo dirigido)
var tirados := {}                        # ids cujo largado original já sumiu (virou veículo)
var ocupados := {}                       # id -> id de rede de quem está dirigindo (outro aparelho)
var dirigindo = null                     # veículo que ESTE jogador dirige
var perto: String = ""                   # id do carro que dá para entrar agora ("" = nenhum)
var mudou := Callable()                  # (tipo: "entrou"/"saiu", id, estado) -> rede
var _t := 0.0
var _t_guardar := 2.0
var _painel: Label = null

func ligar(cid, mun, jog: Node3D, lm, vg) -> void:
	cidade = cid
	mundo = mun
	jogador = jog
	loot = lm
	vagos = vg
	if vagos != null:
		vagos.veiculos = self             # 0.79: os infectados sem física desviam dos carros que funcionam
	ab = cidade.abandono if cidade != null else null
	_ids.clear()
	_hash.clear()
	if ab == null:
		return
	for i in ab.carros.size():
		var c: Array = ab.carros[i]
		if c.size() < 8 or not (c[2] in VeiculoCls.TIPOS) or str(c[4]) != "":
			continue
		var cid_s := id_de(c[0])
		var chance: float = CHANCE_MILITAR if c[2] in ["humvee", "caminhao_exercito"] else CHANCE
		if absi(hash(cid_s)) % 1000 >= int(chance * 1000.0):
			continue
		_ids[cid_s] = i
		var k := Vector2i(floori(c[0].x / CEL), floori(c[0].z / CEL))
		if not _hash.has(k):
			_hash[k] = []
		_hash[k].append(cid_s)
	# carros já mexidos (jogo salvo / rede): o largado original some
	for vid in loot.veiculos:
		tirar_original(vid)
	print("Veículos que funcionam: ", _ids.size())

# os carros mexidos mudaram de fora (jogo salvo carregado): some os largados originais deles
func sincronizar() -> void:
	for vid in loot.veiculos:
		tirar_original(vid)

# 1.08: veículo comprido (caminhão do Exército): dá para entrar de mais longe do meio dele
static func _alem(tipo: String) -> float:
	var d: Array = VeiculoCls.TIPOS.get(tipo, VeiculoCls.TIPOS["sedan"])
	return maxf(0.0, (d[4] as Vector3).z - 4.4) * 0.5

static func id_de(p: Vector3) -> String:
	return "v%d_%d" % [roundi(p.x), roundi(p.z)]

# tipo e cor do carro (para montar a cópia de um amigo dirigindo)
func dados(vid: String) -> Dictionary:
	if loot.veiculos.has(vid):
		return loot.veiculos[vid]
	if _ids.has(vid):
		var c: Array = ab.carros[_ids[vid]]
		return {"t": c[2], "cor": (c[3] as Color).to_html(false)}
	return {}

func tirar_original(vid: String) -> void:
	if tirados.has(vid) or not _ids.has(vid):
		return
	tirados[vid] = true
	var i: int = _ids[vid]
	ab.esconder_carro(i)
	if mundo != null:
		mundo.desligar_obstaculo(int(ab.carros[i][5]))

func _combustivel_inicial(vid: String) -> float:
	var h := absi(hash(vid + "gasolina")) % 1000
	if h < 200:
		return 0.0                               # 20%: tanque seco
	return COMB_MAX * float(h - 200) / 800.0

# ---------- montar um veículo ----------
func _montar(vid: String) -> Node:
	if nos.has(vid) and is_instance_valid(nos[vid]):
		return nos[vid]
	var v = VeiculoCls.new()
	v.id = vid
	v.mundo = mundo
	v.vagos = vagos
	v.name = "Veiculo_" + vid
	var p := Vector3.ZERO
	var giro := 0.0
	if loot.veiculos.has(vid):
		var e: Dictionary = loot.veiculos[vid]
		v.tipo = str(e.get("t", "sedan"))
		v.cor = Color.html(str(e.get("cor", "ffffff")))
		var pp: Array = e.get("p", [0, 0, 0])
		p = Vector3(pp[0], pp[1], pp[2])
		giro = float(e.get("g", 0.0))
		v.combustivel = float(e.get("c", 0.0))
		v.motor = float(e.get("m", 1.0))
	elif _ids.has(vid):
		var c: Array = ab.carros[_ids[vid]]
		v.tipo = c[2]
		v.cor = c[3]
		p = c[0]
		giro = float(c[1]) + PI * 0.5               # o modelo largado tem a frente em +X; o veículo, em +Z
		v.combustivel = _combustivel_inicial(vid)
		tirar_original(vid)
	else:
		v.free()
		return null
	v.freeze = true
	v.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	add_child(v)
	v.global_position = p
	v.rotation = Vector3(0.0, giro, 0.0)
	nos[vid] = v
	return v

# ---------- a cada 0,25 s: o que está perto, estacionados aparecendo/sumindo, física ligada só perto ----------
func _process(dt: float) -> void:
	if jogador == null or ab == null:
		return
	if dirigindo != null:
		_atualizar_painel()
		if not is_instance_valid(dirigindo):
			dirigindo = null
		elif bool(jogador.get("morto")):
			sair()                               # morreu dirigindo: o corpo cai do lado do carro
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.25
	var pj := jogador.global_position
	# o estado de quem está montado vai sendo guardado (jogo salvo no meio da viagem)
	_t_guardar -= 0.25
	if _t_guardar <= 0.0:
		_t_guardar = 2.0
		for vid in nos:
			var vv = nos[vid]
			if is_instance_valid(vv) and not vv.remoto and (vv == dirigindo or loot.veiculos.has(vid)):
				loot.veiculos[vid] = vv.estado()
	# estacionados (mexidos) perto aparecem
	for vid in loot.veiculos:
		if nos.has(vid) or ocupados.has(vid):
			continue
		var pp: Array = loot.veiculos[vid].get("p", [0, 0, 0])
		if Vector2(pp[0] - pj.x, pp[2] - pj.z).length() < RAIO_MONTAR:
			_montar(vid)
	# longe somem (guardando onde estão) · física só perto e com chão de física
	for vid in nos.keys():
		var v = nos[vid]
		if not is_instance_valid(v):
			nos.erase(vid)
			continue
		if v == dirigindo:
			continue
		var d := Vector2(v.global_position.x - pj.x, v.global_position.z - pj.z).length()
		if d > RAIO_MONTAR + 40.0:
			loot.veiculos[vid] = v.estado()
			nos.erase(vid)
			v.queue_free()
			continue
		var fisica: bool = d < RAIO_FISICA and mundo != null and mundo.tem_chao_fisico(v.global_position.x, v.global_position.z)
		if v.freeze == fisica:
			v.freeze = not fisica
	# o carro que dá para entrar agora
	perto = ""
	if dirigindo != null:
		return
	var md := RAIO_ENTRAR
	for vid in nos:
		var v = nos[vid]
		if is_instance_valid(v) and not v.remoto and not ocupados.has(vid):
			var dd: float = v.global_position.distance_to(pj) - _alem(v.tipo)
			if dd < md:
				md = dd
				perto = vid
	var k := Vector2i(floori(pj.x / CEL), floori(pj.z / CEL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for vid in _hash.get(k + Vector2i(dx, dz), []):
				if tirados.has(vid) or ocupados.has(vid):
					continue
				var c: Array = ab.carros[_ids[vid]]
				var dd: float = (c[0] as Vector3).distance_to(pj) - _alem(c[2])
				if dd < md:
					md = dd
					perto = vid

# ---------- entrar e sair ----------
func entrar(vid: String) -> String:
	if ocupados.has(vid):
		return "TEM ALGUÉM DIRIGINDO ESSE CARRO"
	var v = _montar(vid)
	if v == null:
		return ""
	v.freeze = false
	if v.virado():
		v.desvirar()                             # capotado: desvira ao entrar
	v.can_sleep = false                         # parado, a física "dorme" e o motor não acordaria o carro
	v.sleeping = false
	v.motorista = jogador
	v.ao_bater = func(dano: float) -> void:
		if jogador != null and jogador.get("sobrevivencia") != null and dano > 6.0:
			jogador.sobrevivencia.receber_ataque(dano * 0.4, 0.0, v.global_position)
	dirigindo = v
	perto = ""
	if jogador.has_method("entrar_veiculo"):
		jogador.entrar_veiculo(v)
	_mostrar_painel(true)
	if mudou.is_valid():
		mudou.call("entrou", vid, v.estado())
	var msg: String = v.ligar_motor()
	return msg if msg != "" else ("%s · GASOLINA %.0f/%.0f L" % [VeiculoCls.NOMES.get(v.tipo, "CARRO"), v.combustivel, VeiculoCls.TANQUE])

func sair() -> void:
	var v = dirigindo
	if v == null:
		return
	dirigindo = null
	v.desligar_motor()
	v.motorista = null
	v.can_sleep = true
	v.ao_bater = Callable()
	loot.veiculos[v.id] = v.estado()
	# sai pela porta do motorista (esquerda); se tiver parede ali, pela direita
	var lado: Vector3 = v.global_transform * Vector3(1.5, 0.3, 0.4)
	var outro: Vector3 = v.global_transform * Vector3(-1.5, 0.3, 0.4)
	var q := PhysicsRayQueryParameters3D.create(v.global_position + Vector3(0, 0.8, 0), lado + Vector3(0, 0.5, 0), 1, [v.get_rid()])
	if not v.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		lado = outro
	var y: float = mundo.altura(lado.x, lado.z) if mundo != null else lado.y
	if jogador.has_method("sair_veiculo"):
		jogador.sair_veiculo(Vector3(lado.x, maxf(y, v.global_position.y - 0.3) + 0.05, lado.z))
	_mostrar_painel(false)
	if mudou.is_valid():
		mudou.call("saiu", v.id, v.estado())

# ---------- gasolina ----------
# USAR o galão perto de um carro: abastece. Devolve o aviso
func abastecer(galao) -> String:
	var vid := perto
	if dirigindo != null:
		return "SAIA DO CARRO PARA ABASTECER"
	if vid == "":
		return "CHEGUE PERTO DE UM CARRO PARA ABASTECER"
	var litros := maxf(galao.carga, 0.0) * LITROS_GALAO
	if litros <= 0.05:
		return "O GALÃO ESTÁ VAZIO · ENCHA NA BOMBA DE UM POSTO"
	var v = _montar(vid)
	if v == null:
		return ""
	var cabe: float = VeiculoCls.TANQUE - v.combustivel
	if cabe <= 0.1:
		return "O TANQUE ESTÁ CHEIO"
	var pos := minf(cabe, litros)
	v.combustivel += pos
	galao.carga = maxf(0.0, (litros - pos) / LITROS_GALAO)
	loot.veiculos[vid] = v.estado()
	if mudou.is_valid():
		mudou.call("saiu", vid, v.estado())
	return "ABASTECEU %.1f L · TANQUE %.0f/%.0f L" % [pos, v.combustivel, VeiculoCls.TANQUE]

# bomba de posto perto (mundo/local.gd põe as bombas no grupo "bombas")
func bomba_perto() -> Node3D:
	if jogador == null:
		return null
	for b in get_tree().get_nodes_in_group("bombas"):
		if is_instance_valid(b) and (b as Node3D).global_position.distance_to(jogador.global_position) < RAIO_BOMBA:
			return b
	return null

static func bomba_tem_gasolina(b: Node3D) -> bool:
	return absi(hash(str(b.get_meta("id", "")))) % 10 < 7

# PEGAR perto da bomba com um galão: enche
func encher_galao(inv) -> String:
	var b := bomba_perto()
	if b == null:
		return ""
	var g = null
	for it in _itens_do_jogador(inv):
		if it.id == "galao" and it.carga < 0.999:
			g = it
			break
	if g == null:
		return "PRECISA DE UM GALÃO (QUE NÃO ESTEJA CHEIO) PARA PEGAR GASOLINA"
	if not bomba_tem_gasolina(b):
		return "ESSA BOMBA ESTÁ SECA · TENTE A OUTRA"
	g.carga = 1.0
	inv._depois()
	return "ENCHEU O GALÃO (%.0f L)" % LITROS_GALAO

func tem_galao_para_encher(inv) -> bool:
	for it in _itens_do_jogador(inv):
		if it.id == "galao" and it.carga < 0.999:
			return true
	return false

static func _itens_do_jogador(inv) -> Array:
	var l := []
	for g in inv.grades_do_jogador():
		l.append_array(g.itens)
	var m = inv.slots.get("maos")
	if m != null:
		l.append(m)
	return l

# ---------- painel do motorista ----------
func _mostrar_painel(sim: bool) -> void:
	if _painel == null and sim:
		var cl := CanvasLayer.new()
		cl.layer = 6
		add_child(cl)
		_painel = UI.rotulo("", 2.6 * UI.vh(self), Color(1, 1, 1), 800, 0.0, true)
		_painel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_painel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_painel.position.y -= 11.0 * UI.vh(self)
		cl.add_child(_painel)
	if _painel != null:
		_painel.visible = sim

func _atualizar_painel() -> void:
	if _painel == null or dirigindo == null or not is_instance_valid(dirigindo):
		return
	var v = dirigindo
	var mot := "MOTOR %d%%" % int(round(v.motor * 100.0))
	_painel.text = "%d km/h   ·   GASOLINA %.1f/%.0f L   ·   %s%s" % [int(v.velocidade_kmh()), v.combustivel, VeiculoCls.TANQUE, mot,
		"" if v.ligado else "   ·   DESLIGADO"]
	_painel.modulate = Color(1, 0.55, 0.45) if v.combustivel < 3.0 or v.motor < 0.3 else Color.WHITE

# ---------- rede ----------
# outro jogador entrou num carro: some o largado/estacionado daqui (a cópia dele aparece com o boneco)
func remoto_entrou(vid: String, quem: int) -> void:
	ocupados[vid] = quem
	tirar_original(vid)
	if nos.has(vid) and is_instance_valid(nos[vid]) and nos[vid] != dirigindo:
		nos[vid].queue_free()
		nos.erase(vid)

# saiu (ou abasteceu): o carro fica estacionado onde ele deixou
func remoto_saiu(vid: String, e: Dictionary) -> void:
	ocupados.erase(vid)
	loot.veiculos[vid] = e
	tirar_original(vid)
	if nos.has(vid) and is_instance_valid(nos[vid]) and nos[vid] != dirigindo:
		nos[vid].queue_free()
		nos.erase(vid)
