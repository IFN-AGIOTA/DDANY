extends Node3D
# ARREMESSO (1.00 · como no The Last of Us, onde "uma garrafa vale tanto quanto uma arma": estudos/ESTUDO_AAA.md 2.2).
# Com um item de arremesso NA MÃO (o que tem "arremesso" em inventario/itens.gd: GARRAFA DE VIDRO, TIJOLO, a garrafa
# vazia de metal), SEGURAR o ATIRAR (ou o MIRAR) mostra o ARCO até onde vai cair e SOLTAR o ATIRAR arremessa.
#   · Onde bate faz BARULHO ("ruido" m): os infectados que ouvem vão ver o que foi (inimigos/vago.gd ouvir) e a horda
#     virtual também, se for alto. Assim dá para tirar infectados do caminho ou passar por trás deles.
#   · Acertar um infectado machuca e atordoa ("dano"), mas ele te descobre.
#   · A garrafa de vidro QUEBRA; o tijolo e a garrafa de metal quicam e ficam no chão (dá para pegar de volta).
#   · Multijogador: rede/sessao_rede.gd manda o arremesso para os outros (sinal "arremessou"), que veem o voo e os
#     infectados de lá ouvem a batida; o item que fica no chão aparece para todos como item largado.
# Criado por jogador/jogador.gd (nó "Arremesso").
# Mexa AQUI para: força, gravidade, quanto o arco sobe, quicar; ruído/dano de cada item ficam em inventario/itens.gd.

const ItemMundo := preload("res://inventario/item_mundo.gd")
const ItemCls := preload("res://inventario/item.gd")
const ModelosItens := preload("res://inventario/modelos_itens.gd")
const Sons := preload("res://audio/sons.gd")

const GRAVIDADE := 12.0               # um pouco mais que a de verdade: o arco fica fácil de ler
const ERGUE := 0.28                   # o arremesso sai um pouco acima de onde você olha
const PASSO_ARCO := 0.06              # s entre os pontos do arco
const TEMPO_ARCO := 2.6               # s de voo mostrados
const SOLTA_EM := 0.2                 # s depois de soltar o botão (o braço chega lá em cima)
const QUICA := 0.35                   # quanto da velocidade sobra depois de bater
const PARA := 2.2                     # m/s: mais devagar que isso no chão, para
const MASCARA := 1 | 4 | 16           # mundo, infectados e chão
const TEMPO_MAX := 6.0

signal arremessou(id: String, de: Vector3, vel: Vector3)

var jogador: CharacterBody3D = null
var _segurando := false
var _fila: Array = []                 # [tempo, item, id] esperando o braço
var _voando: Array = []               # {"no", "p", "v", "id", "item", "t", "bateu", "def"}
var _arco: MeshInstance3D
var _malha: ImmediateMesh
var _alvo: MeshInstance3D
var _t_arco := 0.0
var arremessos := 0                   # (testes)
var ultima_batida := Vector3.INF      # (testes) onde o último bateu primeiro

func _ready() -> void:
	jogador = get_parent() as CharacterBody3D
	top_level = true
	global_transform = Transform3D.IDENTITY
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.95, 0.8, 0.75)
	mat.no_depth_test = true
	mat.render_priority = 10
	_malha = ImmediateMesh.new()
	_arco = MeshInstance3D.new()
	_arco.mesh = _malha
	_arco.material_override = mat
	_arco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arco.visible = false
	add_child(_arco)
	_alvo = MeshInstance3D.new()
	var anel := TorusMesh.new()
	anel.inner_radius = 0.32
	anel.outer_radius = 0.42
	anel.rings = 16
	anel.ring_segments = 4
	_alvo.mesh = anel
	_alvo.material_override = mat
	_alvo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_alvo.visible = false
	add_child(_alvo)

static func def_de(it) -> Dictionary:
	if it == null:
		return {}
	return it.def().get("arremesso", {})

# o item de arremesso das mãos (ou null)
func item_na_mao():
	var inv = jogador.get("inventario")
	if inv == null:
		return null
	var it = inv.slots.get("maos")
	return it if not def_de(it).is_empty() else null

func pode() -> bool:
	return not jogador.morto and jogador.veiculo == null and not jogador.nadando and not bool(jogador.get("construindo")) \
		and item_na_mao() != null

# de onde sai e com que velocidade (pela câmera)
func lancamento(d: Dictionary) -> Array:
	var cam: Camera3D = jogador.camera
	var frente := -cam.global_basis.z
	var dir := (frente + Vector3.UP * ERGUE).normalized()
	var de: Vector3 = jogador.global_position + Vector3(0, 1.55, 0) + cam.global_basis.x * 0.22 + Vector3(frente.x, 0.0, frente.z).normalized() * 0.35
	return [de, dir * float(d.get("vel", 14.0))]

func _physics_process(dt: float) -> void:
	_voar(dt)
	for i in range(_fila.size() - 1, -1, -1):
		_fila[i][0] -= dt
		if _fila[i][0] <= 0.0:
			var f: Array = _fila[i]
			_fila.remove_at(i)
			_soltar(f[1], f[2])
	var ok := pode()
	var gatilho: bool = jogador.armas.gatilho
	if ok and gatilho:
		_segurando = true
	elif _segurando:
		_segurando = false
		if ok:
			_pegar_impulso()
	var mostrar: bool = ok and (gatilho or jogador.mirando)
	_arco.visible = mostrar
	_alvo.visible = mostrar and _alvo.visible
	if mostrar:
		# 1.01: mirando, o item já aparece na mão (antes só aparecia no movimento do braço, ao soltar)
		var it = item_na_mao()
		if it != null and jogador.get("animador") != null and jogador.animador.has_method("manter_item"):
			jogador.animador.manter_item(it.id)
		_t_arco -= dt
		if _t_arco <= 0.0:
			_t_arco = 0.05                     # 20 vezes por segundo basta
			_desenhar_arco()
	else:
		_alvo.visible = false

# solta o botão: tira um do inventário, toca a animação e o item sai daqui a pouco
func _pegar_impulso() -> void:
	var it = item_na_mao()
	if it == null:
		return
	var inv = jogador.inventario
	var um = it
	if it.qtd > 1:
		it.qtd -= 1
		um = ItemCls.novo(it.id, 1)
		um.estado = it.estado
	else:
		inv.retirar(it)
	inv._depois()
	var anim := "arremesso_alto" if jogador.animador._tem("arremesso_alto") else "arremessar"
	jogador.animador.acao(anim + ":" + um.id, 1.5, false)
	_fila.append([SOLTA_EM, um, um.id])

func _soltar(it, id: String) -> void:
	var d: Dictionary = ItemCls.novo(id, 1).def().get("arremesso", {}) if it == null else def_de(it)
	var l := lancamento(d)
	lancar(id, l[0], l[1], it)
	arremessos += 1
	arremessou.emit(id, l[0], l[1])

# põe um item voando (it = null: é o arremesso de outro jogador, só o efeito e o barulho)
func lancar(id: String, de: Vector3, vel: Vector3, it = null) -> void:
	var d: Dictionary = ItemCls.novo(id, 1).def().get("arremesso", {})
	var no := Node3D.new()
	var m := ModelosItens.instancia(id, false)
	if m != null:
		no.add_child(m)
	add_child(no)
	no.global_position = de
	_voando.append({"no": no, "p": de, "v": vel, "id": id, "item": it, "t": 0.0, "bateu": false, "def": d,
		"giro": Vector3(randf_range(-9, 9), randf_range(-4, 4), randf_range(-9, 9))})

func _voar(dt: float) -> void:
	if _voando.is_empty():
		return
	var espaco := get_world_3d().direct_space_state
	for i in range(_voando.size() - 1, -1, -1):
		var pj: Dictionary = _voando[i]
		pj["t"] = float(pj["t"]) + dt
		var p: Vector3 = pj["p"]
		var v: Vector3 = pj["v"]
		v.y -= GRAVIDADE * dt
		var novo := p + v * dt
		var fim := false
		var hit := _raio(espaco, p, novo)
		if hit.is_empty():
			var chao := _altura(novo)
			if novo.y < chao:
				hit = {"position": Vector3(novo.x, chao, novo.z), "normal": Vector3.UP, "collider": null}
		if not hit.is_empty():
			fim = _bateu(pj, hit, v)
			v = pj["v"]
			novo = pj["p"]
		else:
			pj["v"] = v
			pj["p"] = novo
		var no: Node3D = pj["no"]
		if is_instance_valid(no):
			no.global_position = pj["p"]
			no.rotation += (pj["giro"] as Vector3) * dt * (1.0 if not pj["bateu"] else 0.3)
		if fim or float(pj["t"]) > TEMPO_MAX:
			if not fim:
				_parar(pj, pj["p"])
			if is_instance_valid(no):
				no.queue_free()
			_voando.remove_at(i)

func _raio(espaco: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, MASCARA)
	q.exclude = [jogador.get_rid()]
	q.hit_from_inside = false
	return espaco.intersect_ray(q)

func _altura(p: Vector3) -> float:
	var m = jogador.get("mundo")
	if m != null and m.has_method("altura"):
		return float(m.altura(p.x, p.z))
	return -INF

# bateu: na 1ª batida faz o barulho (e machuca o infectado); vidro quebra; o resto quica até parar
func _bateu(pj: Dictionary, hit: Dictionary, v: Vector3) -> bool:
	var ponto: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	var d: Dictionary = pj["def"]
	var alvo = hit.get("collider")
	if not pj["bateu"]:
		pj["bateu"] = true
		ultima_batida = ponto
		# (o arremesso de um amigo não machuca aqui: quem acerta é o aparelho dele, pela rede)
		if pj["item"] != null and alvo != null and is_instance_valid(alvo) and alvo.has_method("receber_golpe") and alvo != jogador:
			alvo.receber_golpe(float(d.get("dano", 8.0)), v.normalized(), jogador)
		Sons.em(str(d.get("som", "impactos/soco")), ponto, 2.0, 70.0, float(d.get("tom", 1.0)))
		jogador.armas.barulho.emit(ponto, float(d.get("ruido", 20.0)))
		if bool(d.get("quebra", false)):
			_cacos(ponto, n)
			return true
	else:
		Sons.em(str(d.get("som", "impactos/soco")), ponto, -8.0, 30.0, float(d.get("tom", 1.0)) * 1.1)
	var vb := v.bounce(n) * QUICA if n.length_squared() > 0.5 else -v * QUICA
	if n.y > 0.6 and vb.length() < PARA:
		_parar(pj, ponto)
		return true
	pj["v"] = vb
	pj["p"] = ponto + n * 0.04
	return false

# parou: o item fica no chão (só no aparelho de quem jogou; os outros recebem como item largado)
func _parar(pj: Dictionary, p: Vector3) -> void:
	var it = pj["item"]
	if it == null:
		return
	var chao := _altura(p)
	var pos := p
	if chao > -INF and pos.y - chao > 0.6:
		# parou numa parede ou caiu longe da física: no chão de baixo
		var hit := _raio(get_world_3d().direct_space_state, p + Vector3.UP * 0.2, p + Vector3.DOWN * 40.0)
		pos.y = float((hit["position"] as Vector3).y) if not hit.is_empty() else chao
	ItemMundo.soltar(jogador.get_parent(), it, pos)

# cacos de vidro (umas poucas lascas que caem e somem)
func _cacos(p: Vector3, n: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.55, 0.35, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.005, 0.02)
	for k in 7:
		var c := MeshInstance3D.new()
		c.mesh = bm
		c.material_override = mat
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c)
		c.global_position = p + n * 0.03
		var para := p + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
		para.y = maxf(_altura(para), p.y - 0.3) + 0.01
		var tw := c.create_tween()
		tw.tween_property(c, "global_position", para, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "rotation", Vector3(randf() * TAU, randf() * TAU, 0), 0.35)
		tw.tween_interval(6.0)
		tw.tween_callback(c.queue_free)

# o arco (uma linha) e o anel onde cai
func _desenhar_arco() -> void:
	var it = item_na_mao()
	if it == null:
		return
	var l := lancamento(def_de(it))
	var p: Vector3 = l[0]
	var v: Vector3 = l[1]
	var espaco := get_world_3d().direct_space_state
	_malha.clear_surfaces()
	_malha.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_malha.surface_add_vertex(p)
	var t := 0.0
	var caiu := Vector3.INF
	var normal := Vector3.UP
	while t < TEMPO_ARCO:
		var nv := v + Vector3.DOWN * GRAVIDADE * PASSO_ARCO
		var np := p + (v + nv) * 0.5 * PASSO_ARCO
		var hit := _raio(espaco, p, np)
		if hit.is_empty() and np.y < _altura(np):
			hit = {"position": Vector3(np.x, _altura(np), np.z), "normal": Vector3.UP}
		if not hit.is_empty():
			caiu = hit["position"]
			normal = hit["normal"]
			_malha.surface_add_vertex(caiu)
			break
		_malha.surface_add_vertex(np)
		p = np
		v = nv
		t += PASSO_ARCO
	_malha.surface_end()
	_alvo.visible = caiu != Vector3.INF
	if _alvo.visible:
		var up := normal.normalized()
		var lado := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		_alvo.global_transform = Transform3D(Basis(lado, up, lado.cross(up)), caiu + up * 0.03)
