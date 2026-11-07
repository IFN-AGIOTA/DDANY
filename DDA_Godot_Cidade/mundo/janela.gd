extends Node3D
# JANELA DE VERDADE (0.90 · estilo Project Zomboid) · criada por mundo/interior.gd nas janelas do TÉRREO dos prédios
# abertos. Tem a MESMA interface da porta (mundo/porta.gd) e entra na mesma lista (PortaCls.todas): por isso o botão
# PEGAR, as TÁBUAS do inventário, os infectados batendo, o jogo salvo (loot_mundo.portas) e a rede ("porta")
# funcionam igual, sem nada à parte.
#   - Com VIDRO: PEGAR = QUEBRAR (barulho alto; sem arma na mão você pode cortar a mão e sangrar).
#   - Quebrada: PEGAR = PULAR A JANELA (você passa para o outro lado por cima do peitoril).
#   - TÁBUAS (inventário: USAR perto) = BARRICAR, até MAX_TABUAS (com ou sem vidro). Com PÉ DE CABRA ou MACHADO,
#     PEGAR = TIRAR UMA TÁBUA.
#   - INFECTADOS (inimigos/vago.gd): batem nas tábuas, depois no vidro (quebra fácil) e então PULAM para dentro (caem
#     no chão do outro lado e levantam), como no Project Zomboid.
# O nó fica no meio do vão, no nível do chão; o +Z local aponta para FORA do prédio.
# Mexa AQUI para: vida do vidro e das tábuas, barulho, chance de cortar a mão, tempo para pular.

const PortaCls := preload("res://mundo/porta.gd")
const Sons := preload("res://audio/sons.gd")

const VIDA_VIDRO := 22.0
const VIDA_TABUA := 140.0
const MAX_TABUAS := 3
const BARULHO_QUEBRAR := 22.0         # m: a janela estourando chama os infectados
const CHANCE_CORTE := 0.5             # quebrando sem arma na mão
const COR_TABUA := Color(0.58, 0.44, 0.28)
const COR_CAIXILHO := Color(0.15, 0.15, 0.16)

var janela := true                    # (as portas não têm isso: inimigos/vago.gd sabe que é janela)
var id := ""
var largura := 1.3
var y0 := 1.05                        # peitoril
var y1 := 2.5                         # topo do vão
var parede := 0.14
var vidro := true
var tabuas := 0
var lado_tabuas := 1.0                # +1 = por fora (+Z) · -1 = por dentro
var quebrada := false                 # (só para quem trata como porta: janela nunca "cai")
var vida_vidro := VIDA_VIDRO
var vida_tabua := VIDA_TABUA

var _corpo: StaticBody3D
var _vidro: MeshInstance3D
var _nos_tabuas: Array[Node3D] = []
static var _mat_vidro: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("portas")
	if id != "":
		PortaCls.todas[id] = self
	var h := y1 - y0
	# caixilho (peitoril e verga escuros)
	for y in [y0, y1]:
		var mi := MeshInstance3D.new()
		mi.mesh = PortaCls._caixa(Vector3(largura, 0.08, parede + 0.04), COR_CAIXILHO)
		mi.position = Vector3(0, y, 0)
		mi.visibility_range_end = 60.0
		add_child(mi)
	# o vidro (fino, transparente)
	if _mat_vidro == null:
		_mat_vidro = StandardMaterial3D.new()
		_mat_vidro.albedo_color = Color(0.55, 0.68, 0.72, 0.28)
		_mat_vidro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_vidro.roughness = 0.08
		_mat_vidro.metallic_specular = 0.9
	_vidro = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(largura - 0.04, h - 0.04, 0.012)
	_vidro.mesh = bm
	_vidro.material_override = _mat_vidro
	_vidro.position = Vector3(0, y0 + h * 0.5, 0)
	_vidro.visibility_range_end = 60.0
	_vidro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_vidro)
	# colisão do vão (com vidro ou tábuas ninguém passa; quebrada e sem tábuas só pulando)
	_corpo = StaticBody3D.new()
	_corpo.collision_layer = 1
	_corpo.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(largura, h, parede)
	cs.shape = bs
	cs.position = Vector3(0, y0 + h * 0.5, 0)
	_corpo.add_child(cs)
	add_child(_corpo)
	_refazer()

func _exit_tree() -> void:
	if id != "" and PortaCls.todas.get(id) == self:
		PortaCls.todas.erase(id)

# ---------- o que o jogador pode fazer aqui (texto do botão PEGAR) ----------
func acao(_inv) -> String:
	if tabuas > 0:
		return "TIRAR\nTÁBUA"
	return "QUEBRAR\nJANELA" if vidro else "PULAR\nJANELA"

func usar(inv) -> String:
	if tabuas > 0:
		if inv == null or not _tem_ferramenta(inv):
			return "JANELA BARRICADA · PRECISA DE PÉ DE CABRA OU MACHADO PARA TIRAR AS TÁBUAS"
		tabuas -= 1
		vida_tabua = VIDA_TABUA
		_refazer()
		Sons.em("impactos/bala_madeira", global_position + Vector3(0, y0 + 0.5, 0), -4.0, 25.0, 0.7)
		inv._guardar_ou_largar(load("res://inventario/item.gd").novo("tabuas", 1))
		inv._depois()
		_avisar_mudou()
		return "TIROU UMA TÁBUA" + (" · AINDA FALTAM %d" % tabuas if tabuas > 0 else "")
	var j = inv.jogador if inv != null else null
	if vidro:
		quebrar_vidro()
		# sem arma na mão: pode cortar a mão (Project Zomboid)
		if j != null and j.get("armas") != null and str(j.armas.atual) in ["", "punhos"] and randf() < CHANCE_CORTE:
			var sv = j.get("sobrevivencia")
			if sv != null:
				sv.sangramentos += 1
				sv.vida = maxf(1.0, sv.vida - 4.0)
				return "CORTOU A MÃO NO VIDRO · SANGRANDO"
		return "QUEBROU A JANELA"
	if j != null and j.has_method("passar_janela"):
		j.passar_janela(ponto_do_outro_lado(j.global_position))
	return ""

func _tem_ferramenta(inv) -> bool:
	for id_f in ["pe_de_cabra", "machado"]:
		if inv.contar(id_f) > 0:
			return true
		for s in inv.slots:
			if inv.slots[s] != null and inv.slots[s].id == id_f:
				return true
	return false

# do outro lado do vão, no chão, em frente da janela (de quem está em "p")
func ponto_do_outro_lado(p: Vector3) -> Vector3:
	var local := global_transform.affine_inverse() * p
	var lado := 1.0 if local.z >= 0.0 else -1.0
	var x := clampf(local.x, -largura * 0.3, largura * 0.3)
	return global_transform * Vector3(x, 0.05, -lado * (parede * 0.5 + 0.7))

func quebrar_vidro() -> void:
	if not vidro:
		return
	vidro = false
	_refazer()
	Sons.em("mundo/vidro_quebrar", global_position + Vector3(0, y0 + 0.6, 0), 3.0, 60.0)
	if PortaCls.barulho.is_valid():
		PortaCls.barulho.call(global_position, BARULHO_QUEBRAR)
	_avisar_mudou()

# a porta também "abre": a janela não (os infectados que abrem portas quebram o vidro)
func definir_aberta(_sim: bool, _com_som := false) -> void:
	pass

func fechada() -> bool:
	return vidro or tabuas > 0

func barricar(lado_de: Vector3) -> String:
	if tabuas >= MAX_TABUAS:
		return "JÁ TEM %d TÁBUAS AQUI" % MAX_TABUAS
	if tabuas == 0:
		lado_tabuas = 1.0 if (global_transform.affine_inverse() * lado_de).z >= 0.0 else -1.0
	tabuas += 1
	vida_tabua = VIDA_TABUA
	_refazer()
	Sons.em("mundo/martelo", global_position + Vector3(0, y0 + 0.5, 0), 0.0, 30.0)
	if PortaCls.barulho.is_valid():
		PortaCls.barulho.call(global_position, PortaCls.BARULHO * 1.5)
	_avisar_mudou()
	return "JANELA BARRICADA (%d/%d TÁBUAS)" % [tabuas, MAX_TABUAS]

# infectado batendo: primeiro as tábuas, depois o vidro
func golpear(dano: float) -> void:
	if tabuas > 0:
		Sons.em("impactos/bala_madeira", global_position + Vector3(0, y0 + 0.5, 0), -2.0, 35.0, randf_range(0.55, 0.7))
		vida_tabua -= dano
		if vida_tabua <= 0.0:
			tabuas -= 1
			vida_tabua = VIDA_TABUA
			_refazer()
			_avisar_mudou()
		return
	if vidro:
		Sons.em("mundo/vidro", global_position + Vector3(0, y0 + 0.6, 0), -2.0, 30.0)
		vida_vidro -= dano
		if vida_vidro <= 0.0:
			quebrar_vidro()

func _refazer() -> void:
	if _vidro == null:
		return
	_vidro.visible = vidro
	_corpo.collision_layer = 1 if fechada() else 0
	for n in _nos_tabuas:
		n.queue_free()
	_nos_tabuas.clear()
	var r := RandomNumberGenerator.new()
	r.seed = hash(id)
	var h := y1 - y0
	for k in tabuas:
		var mi := MeshInstance3D.new()
		mi.mesh = PortaCls._caixa(Vector3(largura + 0.3, 0.2, 0.04), COR_TABUA * r.randf_range(0.8, 1.05))
		mi.position = Vector3(0.0, y0 + h * [0.25, 0.55, 0.85][k % 3], lado_tabuas * (parede * 0.5 + 0.03))
		mi.rotation.z = r.randf_range(-0.18, 0.18)
		mi.visibility_range_end = 60.0
		add_child(mi)
		_nos_tabuas.append(mi)

# ---------- estado (loot_mundo guarda; rede manda). Mesmo tamanho do da porta: [vidro, tábuas, -, lado] ----------
func estado() -> Array:
	return [vidro, tabuas, false, lado_tabuas]

func aplicar(e: Array) -> void:
	var tinha_vidro := vidro
	vidro = bool(e[0])
	tabuas = int(e[1])
	lado_tabuas = float(e[3]) if e.size() > 3 else 1.0
	if not is_inside_tree():
		return
	if tinha_vidro and not vidro:
		Sons.em("mundo/vidro_quebrar", global_position + Vector3(0, y0 + 0.6, 0), 3.0, 60.0)
	_refazer()

func _avisar_mudou() -> void:
	if PortaCls.ao_mudar.is_valid():
		PortaCls.ao_mudar.call(self)
