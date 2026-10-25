extends Node
# HOSPITAIS: ZONA NEUTRA E OS SOBREVIVENTES DO LIVRO (0.91). Criado por main.gd (_criar_jogo).
#   - Os 4 HOSPITAIS (mundo/locais.gd) viram ZONAS NEUTRAS: dentro do terreno (com MARGEM) ninguém fere ninguém
#     (PvP desligado, rede/sessao_rede.gd pvp_vale_em), infectados não nascem e os que entram são abatidos pelos
#     GUARDAS do Carlos (tiro abafado, não chama a horda). O hospital não enche mais de infectados (mundo/locais.gd).
#   - Saiu da zona: TRÉGUA de IMUNIDADE segundos (2 min): ninguém te fere e você não fere ninguém. Aparece no alto da
#     tela (ZONA NEUTRA / TRÉGUA 1:42) e os outros jogadores sabem pela rede (rede/sessao_rede.gd, bit 256 do estado).
#   - Quando o hospital é montado (mundo/locais.gd ao_abrir), entram os SOBREVIVENTES DO HOSPITAL (npc/npc_hospital.gd):
#     Mônica (LOJA, npc/tela_loja.gd), Lucas (TROCAS, npc/tela_trocas.gd + npc/trocas.gd), Carlos (guarda) e
#     moradores. PEGAR (E) perto = falar / abrir a tela.
#   - DINHEIRO: o item "dinheiro" (cada um = US$ 1), achado no loot. Aqui ficam contar, dar e tirar.
#   - MAPA (hud/mapa.gd notas_mapa): marca nos hospitais o que está te esperando nas trocas.
# Mexa AQUI para: o tamanho da zona, a trégua, onde cada NPC fica (NPCS) e os guardas.

const Locais := preload("res://mundo/locais.gd")
const NpcCls := preload("res://npc/npc_hospital.gd")
const TrocasCls := preload("res://npc/trocas.gd")
const Loja := preload("res://npc/loja.gd")
const Precos := preload("res://npc/precos.gd")
const ItemCls := preload("res://inventario/item.gd")
const TelaLoja := preload("res://npc/tela_loja.gd")
const TelaTrocas := preload("res://npc/tela_trocas.gd")
const UI := preload("res://menu/ui.gd")
const Sons := preload("res://audio/sons.gd")

const MARGEM := 8.0                     # m em volta do terreno do hospital que ainda é zona neutra
const IMUNIDADE := 120.0                # s de trégua depois de sair
const GUARDAS_A_CADA := 0.5
# [quem, pose, posição LOCAL no hospital (mundo/local.gd _hospital: +Z = frente/rua, y = piso), giro (PI = olha a rua)]
const NPCS := [["monica", "npc_falando", Vector3(-1.25, 0.0, -9.95), PI],    # atrás do balcão da recepção
	["lucas", "npc_radio", Vector3(1.25, 0.0, -9.95), PI],
	["carlos", "npc_bracos", Vector3(-3.4, 0.0, 1.6), PI],                     # na porta, embaixo da marquise
	["jose", "npc_parado", Vector3(5.6, 0.0, -3.6), -PI * 0.5],
	["senhora", "npc_parado", Vector3(-5.6, 0.0, -3.7), PI * 0.6],
	["jhon", "npc_parado", Vector3(3.4, 0.0, -10.4), PI * 1.1]]

var main = null
var jogador = null
var trocas = null                       # npc/trocas.gd
var na_zona := -1                       # hospital em que você está (-1 = fora)
var imune := 0.0                        # s de trégua que faltam
var comprados := {}                     # "hospital|dia" -> {índice do estoque: true} (loja da Mônica)
var tela = null
var _rotulo: Label
var _t_guardas := 0.0
var _camada: CanvasLayer

static func hospitais() -> Array:
	var l: Array = []
	for i in Locais.LOCAIS.size():
		if Locais.LOCAIS[i][0] == "hospital":
			l.append(i)
	return l

# índice do hospital cuja zona neutra contém p (-1 = nenhum)
static func zona(p: Vector2, margem := MARGEM) -> int:
	for i in Locais.LOCAIS.size():
		if Locais.LOCAIS[i][0] == "hospital" and Locais.retangulo(i, margem).has_point(p):
			return i
	return -1

func ligar(m) -> void:
	main = m
	jogador = m.jogador
	trocas = TrocasCls.new()
	trocas.name = "Trocas"
	trocas.gerente = self
	add_child(trocas)
	if m.locais != null:
		m.locais.ao_abrir = _montar_npcs
		for i in m.locais.abertos:                    # já estava montado (nasceu perto)
			_montar_npcs(i, m.locais.abertos[i])
	_camada = CanvasLayer.new()
	_camada.layer = 5
	add_child(_camada)
	_rotulo = UI.rotulo("", 2.6 * UI.vh(m), Color(0.6, 1.0, 0.65), 900)
	_rotulo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_rotulo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.offset_top = 9.5 * UI.vh(m)
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_rotulo)

func _exit_tree() -> void:
	if tela != null and is_instance_valid(tela):
		tela.fechar()

# ---------- NPCs ----------
func _montar_npcs(i: int, no: Node3D) -> void:
	if Locais.LOCAIS[i][0] != "hospital" or no.get_node_or_null("Sobreviventes") != null:
		return
	var g := Node3D.new()
	g.name = "Sobreviventes"
	no.add_child(g)
	for e in NPCS:
		var n = NpcCls.new()
		n.quem = e[0]
		n.pose = e[1]
		n.hospital = i
		n.position = e[2] + Vector3(0, 0.02, 0)
		n.rotation.y = e[3]
		g.add_child(n)

func npc_perto(pos: Vector3):
	var melhor = null
	var md := NpcCls.RAIO
	for n in get_tree().get_nodes_in_group("npcs_hospital"):
		var d: float = (n as Node3D).global_position.distance_to(pos)
		if d < md and absf(n.global_position.y - pos.y) < 1.6:
			md = d
			melhor = n
	return melhor

# item no chão só ganha do NPC no PEGAR se estiver mais perto que ele
func dist_npc(n, pos: Vector3) -> float:
	return minf(1.6, Vector2(n.global_position.x - pos.x, n.global_position.z - pos.z).length())

# 0.94: o que dizem para um jogador MUTADO (não negociam com ele)
const FALAS_MUTADO := {"monica": "MÔNICA: \"Para aí! O que aconteceu com você?... Aqui você não compra nada. Sai devagar.\"",
	"lucas": "LUCAS: \"Cara... teus olhos. Não, não, não. Sem troca. Vai embora, por favor.\"",
	"carlos": "CARLOS: \"Mais um passo e eu atiro. Fora do meu hospital.\""}

# PEGAR perto de um NPC (jogador/jogador.gd)
func falar_com(n) -> void:
	if tela != null and is_instance_valid(tela):
		return
	if jogador != null and bool(jogador.get("mutado")):
		avisar(FALAS_MUTADO.get(str(n.quem), "%s SE AFASTA DE VOCÊ, COM MEDO." % str(n.NOMES.get(n.quem, "O SOBREVIVENTE")).to_upper()))
		return
	match str(n.quem):
		"monica":
			var t = TelaLoja.new()
			t.gerente = self
			t.npc = n
			t.hospital = n.hospital
			_abrir(t, "MÔNICA · LOJA", "Ex-enfermeira, líder do hospital. Compra e vende por dólares · HOSPITAL %s" % nome_hospital(n.hospital), ["COMPRAR", "VENDER"])
		"lucas":
			var t2 = TelaTrocas.new()
			t2.gerente = self
			t2.npc = n
			t2.hospital = n.hospital
			t2.trocas = trocas
			_abrir(t2, "LUCAS · TROCAS", "Ele passa as ofertas pelo rádio e guarda os itens e o dinheiro até a outra pessoa responder", ["PARA VOCÊ", "VENDER", "SUAS OFERTAS"])
		_:
			avisar(n.falar())

func _abrir(t, titulo: String, sub: String, abas: Array) -> void:
	tela = t
	main.add_child(t)
	t.abrir(titulo, sub, abas)
	t.fechou.connect(func(): tela = null)
	Sons.ui("clique")

func nome_hospital(i: int) -> String:
	return "%d · %s" % [Loja.numero(i) + 1, Loja.especialidade(i)[0]]

func avisar(t: String) -> void:
	if main != null and main.hud != null:
		main.hud.mostrar_aviso(t, 6.0)

# ---------- zona neutra, trégua e guardas ----------
func protegido() -> bool:
	return na_zona >= 0 or imune > 0.0

func _process(dt: float) -> void:
	if jogador == null or not is_instance_valid(jogador):
		return
	var p := Vector2(jogador.global_position.x, jogador.global_position.z)
	var z := zona(p) if not jogador.morto else -1
	if z != na_zona:
		if z >= 0:
			avisar("HOSPITAL %s · ZONA NEUTRA: aqui ninguém fere ninguém. Mônica (loja), Lucas (trocas) e Carlos (guarda)." % nome_hospital(z))
			imune = 0.0
		elif na_zona >= 0 and not jogador.morto:
			imune = IMUNIDADE
			avisar("SAIU DA ZONA NEUTRA · TRÉGUA DE 2 MINUTOS: ninguém te fere e você não fere ninguém")
		na_zona = z
	if na_zona < 0 and imune > 0.0:
		imune = maxf(0.0, imune - dt)
		if imune <= 0.0:
			avisar("A TRÉGUA ACABOU: cuidado com os outros sobreviventes")
	if jogador.morto:
		imune = 0.0
		if tela != null and is_instance_valid(tela):
			tela.fechar()
	if na_zona >= 0:
		_rotulo.text = "ZONA NEUTRA · HOSPITAL"
		_rotulo.modulate = Color(0.6, 1.0, 0.65)
	elif imune > 0.0:
		_rotulo.text = "TRÉGUA %d:%02d" % [int(imune) / 60, int(imune) % 60]
		_rotulo.modulate = Color(0.55, 0.85, 1.0)
	else:
		_rotulo.text = ""
	_rotulo.visible = _rotulo.text != "" and (main.tela_inventario == null or not main.tela_inventario.aberto) and tela == null
	# NPCs olham para quem chega perto
	for n in get_tree().get_nodes_in_group("npcs_hospital"):
		if (n as Node3D).global_position.distance_squared_to(jogador.global_position) < 36.0:
			n.olhar_para(jogador.global_position, dt)
	_t_guardas -= dt
	if _t_guardas <= 0.0:
		_t_guardas = GUARDAS_A_CADA
		_guardas()

# os guardas do Carlos derrubam o infectado que entra na zona (só quem manda nos infectados: sozinho ou o host)
func _guardas() -> void:
	var vg = main.vagos
	if vg == null or not is_instance_valid(vg):
		return
	var r = get_node_or_null("/root/Rede")
	if r != null and bool(r.ligado) and not r.eh_host():
		return
	for v in vg.vivos:
		if not is_instance_valid(v) or v.estado == v.MORTO:
			continue
		var q: Vector3 = v.global_position
		var h := zona(Vector2(q.x, q.z), 2.0)
		if h < 0:
			continue
		var c := Vector3(Locais.LOCAIS[h][1], q.y + 3.0, Locais.LOCAIS[h][2])
		var dir := (q - c).normalized()
		Sons.em("armas/tiro_silenciado", q.lerp(c, 0.5), 2.0, 70.0)
		v.receber_tiro(999.0, q + Vector3(0, 1.6, 0), dir, 1, null)

# ---------- dinheiro e inventário ----------
func dinheiro() -> int:
	return jogador.inventario.contar("dinheiro")

func dar_dinheiro(n: int) -> void:
	var inv = jogador.inventario
	while n > 0:
		var q := mini(n, 1000)
		var it = ItemCls.novo("dinheiro", q)
		if not inv._guardar_auto(it):
			inv._soltar_no_chao(it)
			avisar("SEM ESPAÇO: %s FICARAM NO CHÃO" % Precos.texto(it.qtd))
		n -= q
	inv._depois()

func tirar_dinheiro(n: int) -> bool:
	if dinheiro() < n:
		return false
	return jogador.inventario.consumir("dinheiro", n) == n

# os itens das suas roupas e mochila (o que está na mão ou vestido não entra)
func meus_itens() -> Array:
	var l: Array = []
	for g in jogador.inventario.grades_do_jogador():
		for it in g.itens:
			l.append(it)
	return l

# o item cabe nas suas roupas/mochila? (sem mexer em nada)
func cabe(it) -> bool:
	var inv = jogador.inventario
	var sobra := 0
	if it.max_pilha() > 1:
		for g in inv.grades_do_jogador():
			for o in g.itens:
				if o.empilha_com(it):
					sobra += o.max_pilha() - o.qtd
		if sobra >= it.qtd:
			return true
	if it.tem_conteudo():
		return false
	for g in inv.grades_do_jogador():
		if g.achar_vaga(it).x >= 0:
			return true
	return false

# ---------- loja da Mônica ----------
func dia() -> int:
	return int(floor(main.loot_mundo.horas() / 24.0)) if main.loot_mundo != null else 0

func tempo_ate_renovar() -> String:
	var h: float = main.loot_mundo.horas() if main.loot_mundo != null else 0.0
	var falta := (24.0 - fposmod(h, 24.0)) * 2.0             # 1 dia do jogo = 48 min: 1 h = 2 min
	return "renova em ~%d min" % maxi(1, int(ceil(falta)))

func _chave_loja() -> String:
	var k: String = trocas.minha_chave()
	return k if k != "" else "solo"

func estoque(h: int) -> Array:
	return Loja.estoque(h, _chave_loja(), dia())

func comprado(h: int, k: int) -> bool:
	return (comprados.get("%d|%d" % [h, dia()], {}) as Dictionary).has(str(k))

func marcar_comprado(h: int, k: int) -> void:
	var c := "%d|%d" % [h, dia()]
	for chave in comprados.keys():
		if not str(chave).ends_with("|%d" % dia()):
			comprados.erase(chave)                       # dias que já passaram
	if not comprados.has(c):
		comprados[c] = {}
	comprados[c][str(k)] = true

# ---------- mapa ----------
func notas_mapa() -> Array:
	return trocas.notas() if trocas != null else []

# ---------- jogo salvo ----------
func salvar_personagem() -> Dictionary:
	return {"comprados": comprados, "imune": imune}

func carregar_personagem(d: Dictionary) -> void:
	comprados = d.get("comprados", {})
	imune = float(d.get("imune", 0.0))
