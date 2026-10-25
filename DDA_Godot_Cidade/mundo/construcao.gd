extends Node
# CONSTRUIR A BASE (0.90 · estilo Project Zomboid). Criado por main.gd (_criar_jogo); as peças: mundo/peca_base.gd.
#   · Botão CONSTRUIR (tecla B) abre o menu com as peças, o custo em TÁBUAS (e trapos na cama) e o que você tem.
#     Precisa de um MARTELO no inventário.
#   · Escolhida a peça, ela aparece na sua frente (verde = cabe, vermelha = não cabe). GIRAR (tecla R) gira 90°,
#     OK (tecla E ou clique) constrói, CANCELAR (botão direito) desiste. A obra leva TEMPO_CONSTRUIR s martelando
#     (barulho: os infectados ouvem até BARULHO_MARTELO m) e você tem que ficar parado.
#   · DESMONTAR (no menu): a peça mais perto sai e devolve metade das tábuas (martelo, pé de cabra ou machado).
#   · Os infectados batem nas peças até quebrar (inimigos/vago.gd); a barricada baixa eles pulam.
#   · Tudo vai no jogo salvo e, no multijogador, para todos (rede/sessao_rede.gd: base_nova, base_tira, base_vida,
#     base_agua; quem entra recebe base_tudo). A porta da parede é uma porta de verdade (estado no loot, "porta") e
#     o caixote guarda os itens no loot (grade "b<id>").
# Mexa AQUI para: as peças, o custo, a vida, o tempo e o barulho da obra.

const PecaCls := preload("res://mundo/peca_base.gd")
const ItemCls := preload("res://inventario/item.gd")
const UI := preload("res://menu/ui.gd")
const Sons := preload("res://audio/sons.gd")

const PECAS := {
	"parede": {"nome": "PAREDE DE TÁBUAS", "custo": {"tabuas": 3}, "tam": Vector3(2.0, 2.4, 0.16), "vida": 350.0,
		"desc": "Fecha a sua base. Os infectados batem até quebrar."},
	"porta": {"nome": "PAREDE COM PORTA", "custo": {"tabuas": 4}, "tam": Vector3(2.0, 2.4, 0.16), "vida": 350.0,
		"desc": "Porta de verdade: abre, fecha e dá para barricar."},
	"cerca": {"nome": "BARRICADA BAIXA", "custo": {"tabuas": 2}, "tam": Vector3(2.0, 1.0, 0.2), "vida": 150.0,
		"desc": "Segura e atrasa: os infectados tombam por cima."},
	"caixa": {"nome": "CAIXOTE", "pronto": "PRONTO", "custo": {"tabuas": 2}, "tam": Vector3(1.0, 0.8, 0.7), "vida": 120.0,
		"desc": "Guarda itens (8 x 6)."},
	"cama": {"nome": "CAMA IMPROVISADA", "custo": {"tabuas": 3, "trapos": 2}, "tam": Vector3(1.0, 0.5, 2.0), "vida": 100.0,
		"desc": "PEGAR nela: você passa a renascer aqui."},
	"coletor": {"nome": "COLETOR DE CHUVA", "pronto": "PRONTO", "custo": {"tabuas": 2}, "tam": Vector3(0.9, 1.1, 0.9), "vida": 100.0,
		"desc": "Junta água limpa quando chove. PEGAR enche uma garrafa."},
}
const ORDEM := ["parede", "porta", "cerca", "caixa", "cama", "coletor"]
const NOMES_ITENS := {"tabuas": "TÁBUAS", "trapos": "TRAPOS"}
const TEMPO_CONSTRUIR := 2.5
const BARULHO_MARTELO := 18.0
const DIST_POR := 2.2                  # m na sua frente
const GRADE := 0.5                     # as peças encaixam de meio em meio metro
const CEL := 4.0                       # tabela das peças (consultas dos infectados)
const CHUVA_A_CADA := 12.0             # s: com chuva, cada coletor ganha 1 gole

var main: Node = null
var jogador = null
var controles = null
var loot = null
var mundo = null
var clima = null
var pecas := {}                        # id -> peça (mundo/peca_base.gd)
var minha_cama := ""                   # id da cama onde você renasce
var tipo_pondo := ""                   # peça na mão (pondo)
var _giro := 0.0
var _fantasma: Node3D = null
var _mat_ok: StandardMaterial3D
var _mat_ruim: StandardMaterial3D
var _valido := false
var _pos := Vector3.ZERO
var _t_obra := 0.0
var _obra := {}
var _t_martelo := 0.0
var _t_chuva := CHUVA_A_CADA
var _tab := {}                         # Vector2i -> [ids]
var _menu: CanvasLayer = null
var _n := 0

func ligar(m) -> void:
	main = m
	jogador = m.jogador
	controles = m.controles
	loot = m.loot_mundo
	mundo = m.mundo
	clima = m.clima
	_mat_ok = _transp(Color(0.2, 0.9, 0.3, 0.45))
	_mat_ruim = _transp(Color(0.95, 0.15, 0.1, 0.45))
	if controles != null:
		controles.construir_pedido.connect(alternar_menu)
		controles.girar_pedido.connect(girar)
		controles.confirmar_pedido.connect(confirmar)
		controles.cancelar_pedido.connect(cancelar)

func _exit_tree() -> void:
	fechar_menu()

static func _transp(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _inv():
	return jogador.inventario if jogador != null else null

func _aviso(t: String) -> void:
	var inv = _inv()
	if inv != null and t != "":
		inv.aviso.emit(t)

func tem_martelo() -> bool:
	var inv = _inv()
	return inv != null and inv.contar("martelo") > 0

func pode_pagar(tipo: String) -> bool:
	var inv = _inv()
	if inv == null:
		return false
	var c: Dictionary = PECAS[tipo]["custo"]
	for k in c:
		if inv.contar(k) < int(c[k]):
			return false
	return true

func _pagar(tipo: String) -> void:
	var c: Dictionary = PECAS[tipo]["custo"]
	for k in c:
		_inv().consumir(k, int(c[k]))

static func texto_custo(tipo: String) -> String:
	var c: Dictionary = PECAS[tipo]["custo"]
	var l := PackedStringArray()
	for k in c:
		l.append("%d %s" % [int(c[k]), NOMES_ITENS.get(k, k.to_upper())])
	return " + ".join(l)

# ---------- menu ----------
func alternar_menu() -> void:
	if _menu != null:
		fechar_menu()
	elif tipo_pondo != "":
		cancelar()
	elif jogador != null and jogador.ativo and not jogador.morto and jogador.veiculo == null:
		abrir_menu()

func abrir_menu() -> void:
	var v := UI.vh(main)
	_menu = CanvasLayer.new()
	_menu.layer = 20
	main.add_child(_menu)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.add_child(raiz)
	var veu := ColorRect.new()
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.color = Color(0.03, 0.03, 0.04, 0.72)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(veu)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(0.9 * v))
	raiz.add_child(col)
	var t := UI.rotulo("CONSTRUIR", 6.0 * v, UI.AMBAR, 900, 0.0, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var inv = _inv()
	var sub := "Você tem %d TÁBUAS e %d TRAPOS · %s" % [inv.contar("tabuas"), inv.contar("trapos"),
		"tem MARTELO" if tem_martelo() else "FALTA UM MARTELO"]
	var s := UI.rotulo(sub, 2.6 * v, Color(1, 1, 1, 0.85) if tem_martelo() else Color(1.0, 0.45, 0.35), 700)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(s)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", int(1.2 * v))
	grade.add_theme_constant_override("v_separation", int(0.9 * v))
	col.add_child(grade)
	for tipo in ORDEM:
		var d: Dictionary = PECAS[tipo]
		var b := UI.BotaoMenu.new(d["nome"], texto_custo(tipo) + " · " + d["desc"], false, 3.0, 52.0)
		if not (tem_martelo() and pode_pagar(tipo)):
			b.modulate.a = 0.5
		b.apertado.connect(func(): _escolheu(tipo))
		grade.add_child(b)
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", int(1.2 * v))
	col.add_child(linha)
	var bd := UI.BotaoMenu.new("DESMONTAR", "a peça mais perto (devolve metade)", false, 3.0, 40.0)
	bd.apertado.connect(func():
		fechar_menu()
		_aviso(desmontar_mais_perto()))
	linha.add_child(bd)
	var bf := UI.BotaoMenu.new("FECHAR", "", true, 3.0, 24.0)
	bf.apertado.connect(fechar_menu)
	linha.add_child(bf)
	if controles != null:
		controles.set_bloqueado(true)

func fechar_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	if controles != null:
		controles.set_bloqueado(false)

func _escolheu(tipo: String) -> void:
	if not tem_martelo():
		_aviso("PRECISA DE UM MARTELO PARA CONSTRUIR")
		return
	if not pode_pagar(tipo):
		_aviso("FALTA MATERIAL: " + texto_custo(tipo))
		return
	fechar_menu()
	comecar(tipo)

# ---------- pondo a peça ----------
func comecar(tipo: String) -> void:
	cancelar()
	tipo_pondo = tipo
	_giro = snappedf(jogador.cam_yaw, PI * 0.5)
	_fantasma = _nova_peca("", tipo, true)
	main.jogo.add_child(_fantasma)
	_modo_pondo(true)
	if controles != null and bool(controles.get("modo_pc")):
		_aviso("R GIRA · E OU CLIQUE CONSTRÓI · BOTÃO DIREITO CANCELA")

func _modo_pondo(sim: bool) -> void:
	jogador.construindo = sim
	if controles == null:
		return
	controles.construindo = sim
	for b in ["GIRAR", "OK", "CANCELAR"]:
		controles.ocultos[b] = not sim
	for b in ["ATIRAR", "MIRAR", "RECARREGAR", "EMPURRAR"]:
		controles.ocultos[b] = sim

func girar() -> void:
	if tipo_pondo != "" and _t_obra <= 0.0:
		_giro = fposmod(_giro + PI * 0.5, TAU)

func cancelar() -> void:
	if _fantasma != null:
		_fantasma.queue_free()
		_fantasma = null
	if tipo_pondo != "" and jogador != null:
		_modo_pondo(false)
	tipo_pondo = ""
	_t_obra = 0.0

func confirmar() -> void:
	if tipo_pondo == "" or _t_obra > 0.0:
		return
	if not tem_martelo():
		_aviso("PRECISA DE UM MARTELO PARA CONSTRUIR")
		return
	if not pode_pagar(tipo_pondo):
		_aviso("FALTA MATERIAL: " + texto_custo(tipo_pondo))
		return
	if not _valido:
		_aviso("NÃO CABE AQUI")
		return
	_t_obra = TEMPO_CONSTRUIR
	_t_martelo = 0.0
	_obra = {"t": tipo_pondo, "p": _pos, "r": _giro, "de": jogador.global_position}
	jogador.animador.acao("usar_item", 0.7, true)

func _process(dt: float) -> void:
	if jogador == null or not is_instance_valid(jogador):
		return
	if tipo_pondo != "" and (jogador.morto or jogador.veiculo != null):
		cancelar()
	if tipo_pondo != "" and _t_obra <= 0.0:
		_mover_fantasma()
	if _t_obra > 0.0:
		_t_obra -= dt
		_t_martelo -= dt
		if _t_martelo <= 0.0:
			_t_martelo = 0.42
			Sons.em("mundo/martelo", _obra["p"] + Vector3(0, 0.8, 0), 0.0, 40.0)
			if main.vagos != null:
				main.vagos.barulho(_obra["p"], BARULHO_MARTELO, true)
		if jogador.global_position.distance_to(_obra["de"]) > 0.7:
			_t_obra = 0.0
			_aviso("VOCÊ SE MEXEU: A OBRA PAROU")
		elif _t_obra <= 0.0:
			_terminar_obra()
	# chuva enche os coletores (só quem manda no mundo: solo ou host)
	_t_chuva -= dt
	if _t_chuva <= 0.0:
		_t_chuva = CHUVA_A_CADA
		if clima != null and float(clima.chuva) > 0.3 and _mando():
			for k in pecas:
				var p = pecas[k]
				if is_instance_valid(p) and p.tipo == "coletor" and p.agua < PecaCls.AGUA_MAX:
					p.agua += 1
					agua_mudou(p)

func _mover_fantasma() -> void:
	var f := Vector3(-sin(jogador.cam_yaw), 0.0, -cos(jogador.cam_yaw))
	var alvo: Vector3 = jogador.global_position + f * DIST_POR
	alvo.x = snappedf(alvo.x, GRADE)
	alvo.z = snappedf(alvo.z, GRADE)
	var h := _chao(alvo, jogador.global_position.y)
	_pos = Vector3(alvo.x, h, alvo.z)
	_fantasma.global_position = _pos
	_fantasma.rotation.y = _giro
	_valido = h > -1000.0 and cabe(tipo_pondo, _pos, _giro)
	var m: Material = _mat_ok if _valido else _mat_ruim
	for mi in _fantasma.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m

# chão em (x, z) perto da altura "ref": raio de cima para baixo na física (rua, calçada, piso dos prédios)
func _chao(p: Vector3, ref: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, ref + 1.6, p.z), Vector3(p.x, ref - 2.5, p.z), 1)
	q.exclude = [jogador.get_rid()]
	var r: Dictionary = jogador.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return -10000.0
	return (r["position"] as Vector3).y

# a peça cabe aqui? (nada no caminho, chão quase plano, fora da água e dos prédios fechados)
func cabe(tipo: String, p: Vector3, giro: float) -> bool:
	var t: Vector3 = PECAS[tipo]["tam"]
	var b := Basis(Vector3.UP, giro)
	if p.y < -0.3:
		return false                                          # água
	if mundo != null and mundo.has_method("dentro_de_predio") and mundo.dentro_de_predio(p.x, p.z, 0.0):
		return false                                          # prédio fechado (sem o interior aberto)
	for c in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5)]:
		var q: Vector3 = p + b * Vector3(c.x * t.x, 0, c.z * t.z)
		if absf(_chao(q, p.y) - p.y) > 0.35:
			return false                                      # torto demais (degrau, rampa)
	var bs := BoxShape3D.new()
	bs.size = Vector3(t.x - 0.08, t.y - 0.2, maxf(t.z - 0.08, 0.06))
	var pq := PhysicsShapeQueryParameters3D.new()
	pq.shape = bs
	pq.collision_mask = 1 | 2 | 4
	pq.transform = Transform3D(b, p + Vector3(0, t.y * 0.5 + 0.12, 0))
	return jogador.get_world_3d().direct_space_state.intersect_shape(pq, 1).is_empty()

func _terminar_obra() -> void:
	var tipo: String = _obra["t"]
	if not pode_pagar(tipo) or not cabe(tipo, _obra["p"], _obra["r"]):
		_aviso("NÃO DEU PARA CONSTRUIR AQUI")
		return
	_pagar(tipo)
	var id := _novo_id()
	criar(id, tipo, _obra["p"], _obra["r"])
	_aviso(PECAS[tipo]["nome"] + " " + str(PECAS[tipo].get("pronto", "PRONTA")))
	_mandar("base_nova", {"l": [_linha(pecas[id])]})
	if not pode_pagar(tipo):
		cancelar()                                            # acabou o material

func _novo_id() -> String:
	_n += 1
	var quem := 1
	if main.get_node_or_null("/root/Rede") != null and bool(main.get_node("/root/Rede").ligado):
		quem = main.multiplayer.get_unique_id()
	return "%d_%d_%d" % [quem, Time.get_ticks_msec() % 100000000, _n]

func _nova_peca(id: String, tipo: String, fantasma := false) -> Node3D:
	var p = PecaCls.new()
	p.id = id
	p.tipo = tipo
	p.tam = PECAS[tipo]["tam"]
	p.vida = float(PECAS[tipo]["vida"])
	p.vida_max = p.vida
	p.fantasma = fantasma
	p.mat_fantasma = _mat_ok
	p.gerente = self
	return p

func criar(id: String, tipo: String, pos: Vector3, giro: float, vida := -1.0, agua := 0) -> Node3D:
	if pecas.has(id) or not PECAS.has(tipo):
		return pecas.get(id)
	var p = _nova_peca(id, tipo)
	if vida > 0.0:
		p.vida = vida
	p.agua = agua
	p.position = pos
	p.rotation.y = giro
	main.jogo.add_child(p)
	pecas[id] = p
	_indexar()
	return p

func remover(id: String, com_som := false) -> void:
	var p = pecas.get(id)
	pecas.erase(id)
	if p != null and is_instance_valid(p):
		if com_som:
			Sons.em("impactos/bala_madeira", p.global_position + Vector3(0, 0.8, 0), 4.0, 45.0, 0.45)
		p.queue_free()
	if minha_cama == id:
		minha_cama = ""
	_indexar()

# DESMONTAR: a peça mais perto (até 2,5 m) sai e devolve metade das tábuas
func desmontar_mais_perto() -> String:
	var inv = _inv()
	var ok := false
	for f in ["martelo", "pe_de_cabra", "machado"]:
		if inv.contar(f) > 0:
			ok = true
	if not ok:
		return "PRECISA DE MARTELO, PÉ DE CABRA OU MACHADO PARA DESMONTAR"
	var p = mais_perto(jogador.global_position, 2.5)
	if p == null:
		return "CHEGUE PERTO DE ALGO QUE VOCÊ CONSTRUIU"
	if p.caixa != null and p.caixa.grade != null and not p.caixa.grade.itens.is_empty():
		return "ESVAZIE O CAIXOTE ANTES DE DESMONTAR"
	var volta := maxi(1, int(PECAS[p.tipo]["custo"].get("tabuas", 0)) / 2)
	inv._guardar_ou_largar(ItemCls.novo("tabuas", volta))
	inv._depois()
	var nome: String = PECAS[p.tipo]["nome"]
	var id: String = p.id
	var masc: bool = PECAS[p.tipo].has("pronto")
	remover(id, true)
	_mandar("base_tira", {"i": id})
	return "%s %s · %s" % [nome, "DESMONTADO" if masc else "DESMONTADA", "VOLTOU 1 TÁBUA" if volta == 1 else "VOLTARAM %d TÁBUAS" % volta]

func mais_perto(pos: Vector3, raio: float):
	var melhor = null
	var md := raio
	for k in pecas:
		var p = pecas[k]
		if not is_instance_valid(p):
			continue
		var d: float = Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length()
		if d < md and absf(p.global_position.y - pos.y) < 2.0:
			md = d
			melhor = p
	return melhor

# peça com uso no botão PEGAR (cama, coletor) perto de você
func usavel_perto(pos: Vector3):
	var p = mais_perto(pos, 1.8)
	if p != null and p.acao(_inv()) != "":
		return p
	return null

# ---------- vida (só quem manda no mundo: solo ou o host, onde os infectados batem) ----------
func _mando() -> bool:
	var r = main.get_node_or_null("/root/Rede")
	return r == null or not bool(r.ligado) or r.eh_host()

func peca_levou_dano(p) -> void:
	if p.vida <= 0.0:
		var id: String = p.id
		remover(id, true)
		if main.vagos != null:
			main.vagos.barulho(p.global_position, 20.0, false)
		_mandar("base_tira", {"i": id, "q": true})
	else:
		_mandar("base_vida", {"i": p.id, "v": p.vida})

func agua_mudou(p) -> void:
	_mandar("base_agua", {"i": p.id, "a": p.agua})

# ---------- o que os infectados consultam (inimigos/vago.gd) ----------
func _indexar() -> void:
	_tab.clear()
	for k in pecas:
		var p = pecas[k]
		if not is_instance_valid(p):
			continue
		var c := Vector2i(floori(p.position.x / CEL), floori(p.position.z / CEL))
		if not _tab.has(c):
			_tab[c] = []
		_tab[c].append(k)

func _vizinhas(x: float, z: float) -> Array:
	var l: Array = []
	var c := Vector2i(floori(x / CEL), floori(z / CEL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for k in _tab.get(c + Vector2i(dx, dz), []):
				var p = pecas.get(k)
				if p != null and is_instance_valid(p):
					l.append(p)
	return l

# ponto dentro da planta de alguma peça (com folga "m")
func dentro(x: float, z: float, m := 0.0) -> bool:
	return _peca_em(x, z, m) != null

func _peca_em(x: float, z: float, m: float):
	for p in _vizinhas(x, z):
		var l: Vector3 = p.global_transform.affine_inverse() * Vector3(x, p.global_position.y, z)
		if absf(l.x) < p.tam.x * 0.5 + m and absf(l.z) < p.tam.z * 0.5 + m:
			return p
	return null

# Y do topo da peça em (x, z) (-INF se não tem): a barricada baixa, o caixote e a cama eles pulam
func topo(x: float, z: float, m := 0.0) -> float:
	var p = _peca_em(x, z, m)
	return p.global_position.y + p.tam.y if p != null else -INF

# peça para bater: na frente de quem está em "de" indo para "quer" (a porta da parede quem cuida é a porta)
func no_caminho(de: Vector3, quer: Vector3, raio := 1.6):
	var melhor = null
	var md := raio
	for p in _vizinhas(de.x, de.z):
		if p.tipo == "porta" or p.tam.y < 1.2:
			continue
		var l: Vector3 = p.global_transform.affine_inverse() * de
		var fora := Vector2(maxf(absf(l.x) - p.tam.x * 0.5, 0.0), maxf(absf(l.z) - p.tam.z * 0.5, 0.0)).length()
		var para: Vector3 = p.global_position - de
		para.y = 0.0
		if fora < md and (para.length() < 0.5 or para.normalized().dot(quer.normalized()) > -0.2):
			md = fora
			melhor = p
	return melhor

# ---------- renascer na cama ----------
func ponto_cama():
	var p = pecas.get(minha_cama)
	if p == null or not is_instance_valid(p):
		return null
	return p.global_transform * Vector3(0.9, 0.1, 0.0)

# ---------- jogo salvo ----------
func _linha(p) -> Array:
	return [p.id, p.tipo, p.position.x, p.position.y, p.position.z, p.rotation.y, p.vida, p.agua]

func estado() -> Array:
	var l: Array = []
	for k in pecas:
		if is_instance_valid(pecas[k]):
			l.append(_linha(pecas[k]))
	return l

func salvar() -> Dictionary:
	return {"pecas": estado(), "cama": minha_cama}

func carregar(d: Dictionary) -> void:
	for k in pecas.keys():
		remover(k)
	aplicar_lista(d.get("pecas", []))
	minha_cama = str(d.get("cama", ""))

func aplicar_lista(l: Array) -> void:
	for e in l:
		if e is Array and e.size() >= 8:
			criar(str(e[0]), str(e[1]), Vector3(float(e[2]), float(e[3]), float(e[4])), float(e[5]), float(e[6]), int(e[7]))

# ---------- rede (rede/sessao_rede.gd chama receber) ----------
func _mandar(tipo: String, d: Dictionary) -> void:
	var r = main.get_node_or_null("/root/Rede")
	if r != null and bool(r.ligado):
		r.enviar_evento(tipo, d)

func receber(tipo: String, d: Dictionary) -> void:
	match tipo:
		"base_nova", "base_tudo":
			aplicar_lista(d.get("l", []))
		"base_tira":
			var id := str(d.get("i", ""))
			remover(id, bool(d.get("q", false)))
		"base_vida":
			var p = pecas.get(str(d.get("i", "")))
			if p != null and is_instance_valid(p):
				p.vida = float(d.get("v", p.vida))
		"base_agua":
			var p2 = pecas.get(str(d.get("i", "")))
			if p2 != null and is_instance_valid(p2):
				p2.agua = int(d.get("a", p2.agua))
