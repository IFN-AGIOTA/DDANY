extends Node3D
# PORTA DE VERDADE (0.73) · criada por mundo/interior.gd nos prédios abertos (térreo e andares de cima).
# Uma folha (porta de dentro) ou duas (porta dupla da rua), cada uma numa dobradiça; ABRE girando para o lado -Z
# deste nó (o prédio escolhe o lado: as da rua abrem para dentro).
#   - JOGADOR: botão PEGAR (tecla E) perto da porta = ABRIR / FECHAR (os infectados ouvem o barulho).
#     TÁBUAS (inventário: USAR perto de uma porta FECHADA) = BARRICAR, até MAX_TABUAS: barricada não abre.
#     Com PÉ DE CABRA ou MACHADO no inventário, PEGAR perto da barricada = TIRAR UMA TÁBUA (ela volta para você).
#   - INFECTADOS: presos na frente de uma porta fechada, batem nela (inimigos/vago.gd) até QUEBRAR: primeiro as
#     tábuas (VIDA_TABUA cada), depois a porta (VIDA). Quebrada, a folha cai no chão e o vão fica livre.
#   - O estado (aberta, tábuas, quebrada) fica guardado em mundo/loot_mundo.gd (portas): vai no jogo salvo, volta
#     igual quando o prédio abre de novo e é o mesmo para todos na partida em rede (rede/sessao_rede.gd, "porta").
# Mexa AQUI para: vida da porta e das tábuas, quantas tábuas, ângulo e tempo de abrir, distância para usar.

const Sons := preload("res://audio/sons.gd")

const VIDA := 100.0
const VIDA_TABUA := 140.0
const MAX_TABUAS := 3
const ANGULO := 1.75                  # aberta: ~100°
const TEMPO := 0.45                   # segundos para abrir/fechar
const RAIO_USAR := 1.9                # do jogador até o meio do vão
const BARULHO := 7.0                  # metros: infectados ouvem abrir/fechar
const COR_TABUA := Color(0.58, 0.44, 0.28)

static var todas := {}                # id -> porta montada agora
static var ao_mudar := Callable()     # (porta) -> void: o estado mudou AQUI (loot guarda, rede manda)
static var barulho := Callable()      # (posição, raio) -> void: main liga nos infectados

var id := ""
var largura := 1.24                   # vão
var altura := 2.2
var parede := 0.14                    # espessura da parede (as tábuas ficam por fora dela)
var dupla := false
var cor := Color(0.45, 0.3, 0.18)
var aberta := false
var abertura := 1.0                   # quanto abre (0..1); sorteada nas que já nascem abertas
var tabuas := 0
var lado_tabuas := 1.0                # tábuas do lado +Z (1) ou -Z (-1) do nó
var quebrada := false
var vida := VIDA
var vida_tabua := VIDA_TABUA

var _k := 0.0                         # 0 fechada .. 1 aberta (animação)
var _dobradicas: Array[Node3D] = []
var _corpos: Array[AnimatableBody3D] = []
var _nos_tabuas: Array[Node3D] = []
var _caida: MeshInstance3D = null

static var _malhas := {}
static var _mats := {}

static func _mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mats[k] = m
	return _mats[k]

static func _caixa(t: Vector3, c: Color) -> BoxMesh:
	var k := "%s|%s" % [str(t.snapped(Vector3.ONE * 0.01)), c.to_html()]
	if not _malhas.has(k):
		var b := BoxMesh.new()
		b.size = t
		b.material = _mat(c)
		_malhas[k] = b
	return _malhas[k]

# a porta mais perto de p (até raio, no plano; altura parecida) ou null
static func perto(p: Vector3, raio := RAIO_USAR):
	var melhor = null
	var md := raio
	for k in todas:
		var pt = todas[k]
		if not is_instance_valid(pt) or not pt.is_inside_tree():
			continue
		var g: Vector3 = pt.global_position
		if absf(g.y - p.y) > 1.6:
			continue
		var d := Vector2(g.x - p.x, g.z - p.z).length()
		if d < md:
			md = d
			melhor = pt
	return melhor

func _ready() -> void:
	add_to_group("portas")
	if id != "":
		todas[id] = self
	var n := 2 if dupla else 1
	var lf := largura / n - 0.03
	for k in n:
		var dob := Node3D.new()
		dob.position = Vector3(-largura * 0.5 + 0.015 if k == 0 else largura * 0.5 - 0.015, 0.0, 0.0)
		dob.rotation.y = 0.0 if k == 0 else PI
		add_child(dob)
		var corpo := AnimatableBody3D.new()
		corpo.collision_layer = 1
		corpo.collision_mask = 0
		corpo.sync_to_physics = false
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(lf, altura - 0.02, 0.06)
		cs.shape = bs
		cs.position = Vector3(lf * 0.5, altura * 0.5, 0.0)
		corpo.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = _caixa(Vector3(lf, altura - 0.02, 0.045), cor)
		mi.position = cs.position
		mi.visibility_range_end = 60.0
		corpo.add_child(mi)
		for lado in [-1.0, 1.0]:              # maçaneta dos dois lados
			var mq := MeshInstance3D.new()
			mq.mesh = _caixa(Vector3(0.1, 0.035, 0.035), Color(0.62, 0.6, 0.55))
			mq.position = Vector3(lf - 0.11, 1.0, lado * 0.045)
			mq.visibility_range_end = 25.0
			mq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			corpo.add_child(mq)
		dob.add_child(corpo)
		_dobradicas.append(dob)
		_corpos.append(corpo)
	if quebrada:
		_derrubar(false)
	_k = abertura if aberta else 0.0
	_girar()
	_refazer_tabuas()
	set_physics_process(false)

func _exit_tree() -> void:
	if id != "" and todas.get(id) == self:
		todas.erase(id)

func _girar() -> void:
	var a := _k * ANGULO
	for k in _dobradicas.size():
		_dobradicas[k].rotation.y = a if k == 0 else PI - a

# 1.02 · A FOLHA NÃO PRENDE NINGUÉM: girando, ela não bate em ninguém; parada, só volta a ser sólida quando nenhum
# jogador/infectado está dentro dela. Antes, abrir (ou fechar) com o personagem no vão fazia a folha passar por dentro
# dele e prendê-lo entre ela, a parede e o batente: só saía pulando, e com a perna quebrada não saía.
const PRENDE := 2 | 4                 # camadas de quem a folha poderia prender (jogador · infectados)

func _physics_process(dt: float) -> void:
	var alvo := abertura if aberta else 0.0
	if _k != alvo:
		_solida(false)
		_k = move_toward(_k, alvo, dt / TEMPO)
		_girar()
		return
	if _alguem_na_folha():
		_solida(false)                    # parada, mas tem alguém dentro dela: espera ele sair
		return
	_solida(true)
	set_physics_process(false)

func _solida(sim: bool) -> void:
	for c in _corpos:
		c.collision_layer = 1 if (sim and not quebrada) else 0

func _alguem_na_folha() -> bool:
	if quebrada or not is_inside_tree():
		return false
	var espaco := get_world_3d().direct_space_state
	for c in _corpos:
		for cs in c.get_children():
			if cs is CollisionShape3D:
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = (cs as CollisionShape3D).shape
				q.transform = (cs as CollisionShape3D).global_transform
				q.collision_mask = PRENDE
				if not espaco.intersect_shape(q, 1).is_empty():
					return true
	return false

# ---------- o que o jogador pode fazer aqui (texto do botão PEGAR) ----------
func acao(inv) -> String:
	if quebrada:
		return ""
	if tabuas > 0:
		return "TIRAR\nTÁBUA"
	return "FECHAR\nPORTA" if aberta else "ABRIR\nPORTA"

# PEGAR perto da porta. Devolve um aviso para a tela ("" = nada a dizer)
func usar(inv) -> String:
	if quebrada:
		return ""
	if tabuas > 0:
		if inv == null or not _tem_ferramenta(inv):
			return "PORTA BARRICADA · PRECISA DE PÉ DE CABRA OU MACHADO PARA TIRAR AS TÁBUAS"
		tabuas -= 1
		vida_tabua = VIDA_TABUA
		_refazer_tabuas()
		Sons.em("impactos/bala_madeira", global_position + Vector3(0, 1.2, 0), -4.0, 25.0, 0.7)
		inv._guardar_ou_largar(load("res://inventario/item.gd").novo("tabuas", 1))
		inv._depois()
		_avisar_mudou()
		return "TIROU UMA TÁBUA" + (" · AINDA FALTAM %d" % tabuas if tabuas > 0 else "")
	alternar()
	return ""

func _tem_ferramenta(inv) -> bool:
	for id_f in ["pe_de_cabra", "machado"]:
		if inv.contar(id_f) > 0:
			return true
		for s in inv.slots:
			if inv.slots[s] != null and inv.slots[s].id == id_f:
				return true
	return false

func alternar() -> void:
	if quebrada or tabuas > 0:
		return
	definir_aberta(not aberta, true)
	_avisar_mudou()

# 1.02 · EMPURRAR: quem anda contra uma porta ABERTA pela metade termina de abrir (antes a folha meio aberta deixava
# um vão mais estreito que o corpo e só passava pulando; com a perna quebrada, não passava). Fechada não abre sozinha.
func empurrar() -> void:
	if aberta and not quebrada and tabuas <= 0 and abertura < 1.0:
		abertura = 1.0
		set_physics_process(true)

func definir_aberta(sim: bool, com_som := false) -> void:
	aberta = sim
	if sim:
		abertura = 1.0
	set_physics_process(true)
	if com_som:
		Sons.em("mundo/porta_abrir" if sim else "mundo/porta_fechar", global_position + Vector3(0, 1.2, 0), -3.0, 30.0)
		if barulho.is_valid():
			barulho.call(global_position, BARULHO)

# inventário: USAR as TÁBUAS perto daqui. lado_de = posição de quem pregou (as tábuas ficam do lado dele)
func barricar(lado_de: Vector3) -> String:
	if quebrada:
		return "ESSA PORTA ESTÁ QUEBRADA"
	if aberta:
		return "FECHE A PORTA ANTES DE BARRICAR"
	if tabuas >= MAX_TABUAS:
		return "JÁ TEM %d TÁBUAS AQUI" % MAX_TABUAS
	if tabuas == 0:
		lado_tabuas = 1.0 if (global_transform.affine_inverse() * lado_de).z >= 0.0 else -1.0
	tabuas += 1
	vida_tabua = VIDA_TABUA
	_refazer_tabuas()
	Sons.em("impactos/bala_madeira", global_position + Vector3(0, 1.2, 0), 0.0, 30.0, 0.85)
	if barulho.is_valid():
		barulho.call(global_position, BARULHO * 1.5)          # martelar faz barulho
	_avisar_mudou()
	return "PORTA BARRICADA (%d/%d TÁBUAS)" % [tabuas, MAX_TABUAS]

# infectado batendo (inimigos/vago.gd): primeiro as tábuas, depois a porta
func golpear(dano: float) -> void:
	if quebrada or aberta:
		return
	Sons.em("impactos/bala_madeira", global_position + Vector3(0, 1.2, 0), -2.0, 35.0, randf_range(0.55, 0.7))
	if tabuas > 0:
		vida_tabua -= dano
		if vida_tabua <= 0.0:
			tabuas -= 1
			vida_tabua = VIDA_TABUA
			_refazer_tabuas()
			_avisar_mudou()
		return
	vida -= dano
	if vida <= 0.0:
		quebrar()

func quebrar() -> void:
	if quebrada:
		return
	quebrada = true
	tabuas = 0
	_refazer_tabuas()
	_derrubar(true)
	_avisar_mudou()

func fechada() -> bool:
	return not quebrada and not aberta

func _derrubar(com_som: bool) -> void:
	for c in _corpos:
		c.visible = false
		c.collision_layer = 0
	if _caida == null:
		_caida = MeshInstance3D.new()
		_caida.mesh = _caixa(Vector3(largura * (0.5 if dupla else 1.0), 0.045, altura - 0.1), cor * 0.85)
		_caida.position = Vector3(0.1, 0.03, -altura * 0.5 - 0.15)
		_caida.rotation.y = 0.25
		_caida.visibility_range_end = 60.0
		add_child(_caida)
	if com_som:
		Sons.em("impactos/bala_madeira", global_position + Vector3(0, 0.5, 0), 4.0, 40.0, 0.45)
		if barulho.is_valid():
			barulho.call(global_position, BARULHO * 2.0)

func _refazer_tabuas() -> void:
	for n in _nos_tabuas:
		n.queue_free()
	_nos_tabuas.clear()
	var r := RandomNumberGenerator.new()
	r.seed = hash(id)
	for k in tabuas:
		var mi := MeshInstance3D.new()
		mi.mesh = _caixa(Vector3(largura + 0.4, 0.2, 0.04), COR_TABUA * r.randf_range(0.8, 1.05))
		mi.position = Vector3(0.0, [0.75, 1.45, 2.0][k % 3], lado_tabuas * (parede * 0.5 + 0.03))
		mi.rotation.z = r.randf_range(-0.22, 0.22)
		mi.visibility_range_end = 60.0
		add_child(mi)
		_nos_tabuas.append(mi)

# ---------- estado (loot_mundo guarda; rede manda) ----------
func estado() -> Array:
	return [aberta, tabuas, quebrada, lado_tabuas]

func aplicar(e: Array) -> void:
	var era_quebrada := quebrada
	var era_aberta := aberta
	aberta = bool(e[0])
	tabuas = int(e[1])
	quebrada = bool(e[2])
	lado_tabuas = float(e[3]) if e.size() > 3 else 1.0
	if aberta:
		abertura = 1.0
	if not is_inside_tree():
		return
	if quebrada and not era_quebrada:
		_derrubar(true)
	elif aberta != era_aberta:
		Sons.em("mundo/porta_abrir" if aberta else "mundo/porta_fechar", global_position + Vector3(0, 1.2, 0), -3.0, 30.0)
	_refazer_tabuas()
	set_physics_process(true)

func _avisar_mudou() -> void:
	if ao_mudar.is_valid():
		ao_mudar.call(self)
