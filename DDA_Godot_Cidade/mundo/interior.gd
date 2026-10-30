extends RefCounted
# MONTA O TÉRREO DE UM PRÉDIO POR DENTRO (chamado por mundo/interiores.gd quando o jogador chega perto):
#   - paredes externas com PORTAS (do lado da rua), janelas (algumas tapadas com tábuas) e VITRINES nas lojas
#   - cômodos conforme o uso: casa (sala, cozinha, quartos, banheiro), loja, mercado, farmácia, restaurante,
#     escritório, delegacia (recepção, cela, armas) e clínica (espera, consultórios)
#   - móveis de mundo/moveis.gd arrumados encostados nas paredes/em fileiras, sem bloquear portas;
#     cidade abandonada: móveis caídos, entulho, papéis e manchas
#   - colisão (paredes, piso, teto, móveis grandes), loot nos móveis (mundo/loot_mundo.gd) e itens no chão
#   - ANDARES DE CIMA (até 2 além do térreo): escada em rampa com degraus num canto, buraco na laje com corrimão,
#     cômodos, móveis e loot em cada andar (apartamentos nas casas; escritório/depósito no comércio)
#   - prédios baixos (até 3 andares): a escada chega ao TELHADO, com mureta em volta
#   - 0.73: PORTAS DE VERDADE (mundo/porta.gd) nos vãos: dupla na rua (abre para dentro), comum entre os cômodos;
#     umas abertas, outras fechadas, algumas quebradas no chão ou arrancadas (só o vão)
#   - acima disso, a "casca" do prédio com as mesmas janelas do bloco original
#   - 0.81 · SISTEMA DE PREENCHIMENTO: o andar guarda um MAPA DAS PAREDES (_muros: cada pedaço com a altura de
#     baixo e de cima, então sabe onde há parede cheia, peitoril de janela, vão de janela ou de porta) e das ABERTURAS
#     de cada fachada (_vaos). Com isso:
#       · as divisórias entre cômodos nunca encostam na fachada em cima de porta/janela (são deslocadas);
#       · porta da rua não abre para dentro do vão da escada; janela não fica onde a parede da escada encosta;
#       · móvel "de parede" só vai onde há PAREDE DE VERDADE atrás dele na largura toda (nada em vão de porta, borda
#         sem parede ou buraco); móvel ALTO (guarda-roupa, estante, geladeira...) não fica na frente de janela; os
#         baixos (sofá, cama, bancada) podem ficar embaixo dela; nenhum móvel cruza parede; a frente das portas fica livre;
#       · escada: patamar de 1,4 m no fundo e uma PORTA na parede do vão (quem chega pelo lance do fundo sai para o
#         cômodo; antes dava de cara com a parede); grade da cela antes dos móveis (cama não atravessa a grade).
# Tudo de um prédio vira UMA malha (4 superfícies) + um corpo de colisão: leve no celular.
# Mexa AQUI para: pé-direito, portas, janelas, divisão dos cômodos e quais móveis vão em cada cômodo.

const Malhas := preload("res://mundo/malhas.gd")
const Moveis := preload("res://mundo/moveis.gd")
const Mat := preload("res://mundo/materiais_cidade.gd")
const ItemMundo := preload("res://inventario/item_mundo.gd")
const CaixaMundo := preload("res://inventario/caixa_mundo.gd")
const PortaCls := preload("res://mundo/porta.gd")
const JanelaCls := preload("res://mundo/janela.gd")

const PE_DIREITO := 4.0
const LAJE := 0.6
const ESP := 0.25
const PORTA_L := 1.8
const PORTA_A := 2.6
const DIV := 0.14                     # espessura das paredes internas
const ALTURA_ANDAR := PE_DIREITO + LAJE   # 4,6 m de um piso ao outro
const MAX_ANDARES_EXTRA := 2          # além do térreo (os mais altos ficam com a "casca" acima)
const ESCADA_L := 1.45                # largura de cada lance da escada
const ESCADA_C := 7.0                 # comprimento de cada lance (rampa com degraus)
const PATAMAR := 1.4                  # 0.81: patamar no fundo do vão da escada (chegada do lance que sobe para o fundo)
# 0.81: altura de cada móvel "de parede" (m): acima de ALTURA_PEITORIL ele precisa de parede cheia atrás (não tapa janela)
const ALTURA_PEITORIL := 1.0
const ALTO := {"guarda_roupa": 2.0, "estante_livros": 1.9, "geladeira": 1.8, "prateleira": 1.9, "armario_armas": 1.9,
	"armario_remedios": 1.8, "arquivo": 1.3, "estante_tv": 1.3, "quadro": 1.8, "luminaria": 1.6, "arara": 1.6,
	"barricada": 1.5, "caixas": 1.2, "balcao": 1.05, "poltrona": 1.0, "cama": 1.0, "planta": 1.0, "freezer": 0.9}

# o que vai em cada cômodo: [móvel, modo] · modo: parede / centro / fileiras / meio (centro do cômodo)
const COMODOS := {
	"sala": [["sofa", "parede"], ["estante_tv", "parede"], ["poltrona", "parede"], ["estante_livros", "parede"], ["tapete", "meio"], ["mesa_centro", "meio"],
		["aparador", "parede"], ["planta", "parede"], ["luminaria", "parede"], ["quadro", "parede"], ["quadro", "parede"]],
	"sala_jantar": [["mesa_jantar", "meio"], ["aparador", "parede"], ["estante_livros", "parede"], ["planta", "parede"], ["quadro", "parede"], ["luminaria", "parede"]],
	"escritorio_casa": [["mesa_escritorio", "parede"], ["estante_livros", "parede"], ["estante_livros", "parede"], ["arquivo", "parede"], ["planta", "parede"], ["quadro", "parede"]],
	"cozinha": [["bancada", "parede"], ["geladeira", "parede"], ["fogao", "parede"], ["bancada", "parede"], ["mesa_jantar", "meio"], ["lixeira", "parede"]],
	"quarto": [["cama", "parede"], ["guarda_roupa", "parede"], ["criado", "parede"], ["tapete", "centro"], ["quadro", "parede"], ["luminaria", "parede"], ["cadeira", "parede"]],
	"banheiro": [["banheira", "parede"], ["vaso", "parede"], ["pia", "parede"]],
	"loja": [["balcao", "parede"], ["prateleira", "parede"], ["prateleira", "parede"], ["prateleira", "parede"], ["arara", "fileiras"]],
	"mercado": [["balcao", "parede"], ["freezer", "parede"], ["freezer", "parede"], ["prateleira", "parede"], ["prateleira", "parede"], ["gondola", "fileiras"]],
	"farmacia": [["balcao", "parede"], ["armario_remedios", "parede"], ["armario_remedios", "parede"], ["prateleira", "parede"], ["prateleira", "parede"], ["gondola", "fileiras"]],
	"restaurante": [["balcao", "parede"], ["geladeira", "parede"], ["planta", "parede"], ["quadro", "parede"], ["quadro", "parede"], ["mesa_bar", "fileiras"]],
	"cozinha_rest": [["fogao_industrial", "parede"], ["bancada", "parede"], ["geladeira", "parede"], ["freezer", "parede"]],
	"escritorio": [["arquivo", "parede"], ["arquivo", "parede"], ["arquivo", "parede"], ["planta", "parede"], ["planta", "parede"], ["lixeira", "parede"], ["quadro", "parede"], ["mesa_escritorio", "fileiras"]],
	"reuniao": [["mesa_jantar", "meio"], ["estante_livros", "parede"], ["arquivo", "parede"]],
	"copa": [["bancada", "parede"], ["geladeira", "parede"], ["mesa_bar", "meio"]],
	"recepcao": [["balcao", "parede"], ["cadeiras_espera", "parede"], ["cadeiras_espera", "parede"], ["arquivo", "parede"], ["planta", "parede"], ["quadro", "parede"], ["lixeira", "parede"]],
	"armas": [["armario_armas", "parede"], ["armario_armas", "parede"], ["armario_armas", "parede"], ["caixas", "parede"]],
	"escritorio_pol": [["mesa_escritorio", "parede"], ["mesa_escritorio", "parede"], ["arquivo", "parede"], ["armario_armas", "parede"]],
	"cela": [["cama", "parede"], ["vaso", "parede"]],
	"espera": [["balcao", "parede"], ["cadeiras_espera", "parede"], ["cadeiras_espera", "parede"], ["cadeiras_espera", "parede"], ["planta", "parede"], ["quadro", "parede"], ["maca", "parede"]],
	"consultorio": [["maca", "parede"], ["armario_remedios", "parede"], ["mesa_escritorio", "parede"], ["pia", "parede"]],
	"deposito": [["prateleira", "parede"], ["prateleira", "parede"], ["caixas", "parede"], ["caixas", "parede"], ["caixas", "centro"]],
}
const PAPEL_PAREDE := [Color(0.62, 0.58, 0.48), Color(0.5, 0.56, 0.52), Color(0.6, 0.5, 0.46), Color(0.55, 0.55, 0.58), Color(0.66, 0.62, 0.55), Color(0.48, 0.52, 0.6)]

var info: Dictionary
var idx := 0
var cid
var loot
var r := RandomNumberGenerator.new()
var paredes := Malhas.Construtor.new()
var piso := Malhas.Construtor.new()
var resto := Malhas.Construtor.new()
var _descarte := Malhas.Construtor.new()   # 0.90: o que não é desenhado (as janelas do térreo se desenham sozinhas)
var teto := Malhas.Construtor.new()
var col: Array = []                    # [centro local, tamanho, giro]
var cont: Array = []                   # lugares com loot
var ocupado: Array[Rect2] = []
var proibido: Array[Rect2] = []
var hx := 10.0
var hz := 10.0
var frente := 2
var cor_fora := Color.GRAY
var cor_dentro := Color.GRAY
var comodos: Array = []                # [Rect2, tipo]
var _pontos: Array = []                # pontos livres no chão (loot solto)
var portas: Array = []                 # 0.73: {pos (meio do vão, no chão), giro, larg, alt, parede, dupla, estado, abertura}
var janelas: Array = []                # 0.90: janelas do térreo {pos, giro, larg, y0, y1, parede, vidro, tabuas}
var _rp := RandomNumberGenerator.new() # 0.73: sorteio das portas de dentro (separado: não muda o resto do prédio)
var _pad_piso := 1.0
# 0.82: o piso (o desenho) fica 1,5 cm acima do chão do lote: na mesma altura os dois "brigavam" e piscavam
const PISO_Y := 0.015
var _malha: ArrayMesh = null
var _malha_detalhes: ArrayMesh = null   # 1.00: móveis, escada, papéis e manchas (só de perto: DETALHES_ALCANCE)
# 1.00 · DETALHES SÓ DE PERTO (estudos/ESTUDO_AAA.md 1.3 e 1.13): os móveis e objetos são ~80% dos triângulos de um
# prédio aberto (~27 mil). Ficam num nó próprio que só aparece a até DETALHES_ALCANCE m do meio do prédio (de dentro
# e de perto, igual; de longe nem se vê pela janela). A colisão dos móveis continua sempre.
const DETALHES_ALCANCE := 34.0
var nivel := 0                         # 0 = térreo · 1, 2 = andares de cima
var extras := 0                        # quantos andares de cima este prédio tem abertos
var telhado := false                   # prédio baixo: a escada chega ao telhado (com mureta)
var _w_max := 1e9                      # lado da escada: os cômodos vão só até aqui
var _escada := false
var _muros: Array = []                 # 0.81: pedaços de parede [Rect2 no plano XZ, y de baixo, y de cima]
var _vaos := {}                        # 0.81: fachada -> aberturas [s0, s1, y0, y1, tipo]
static var criar_malha_na_thread := true

static func montar(inf: Dictionary, i: int, cidade, lm) -> Node3D:
	var m = preparar(inf, i, cidade)
	return m.criar(lm)

# 1ª parte (pode rodar numa thread: só cálculo, sem nós nem física): paredes, cômodos, móveis
static func preparar(inf: Dictionary, i: int, cidade) -> RefCounted:
	var cls = load("res://mundo/interior.gd")
	var m = cls.new()
	# quantos níveis cabem na altura do prédio (e se dá para chegar ao telhado)
	var h: float = inf["h"]
	var niveis := maxi(1, int(floor((h + 0.8) / ALTURA_ANDAR)))
	m.extras = clampi(niveis - 1, 0, MAX_ANDARES_EXTRA)
	m.telhado = niveis <= MAX_ANDARES_EXTRA + 1
	var prof_min := minf(float(inf["sx"]), float(inf["sz"]))
	if prof_min < ESCADA_C + PATAMAR + 4.5 or maxf(float(inf["sx"]), float(inf["sz"])) < 11.0:
		m.extras = 0                      # pequeno demais para ter escada
		m.telhado = false
	m._gerar(inf, i, cidade)
	for k in range(1, m.extras + 1):
		var a = cls.new()
		a._herdar(m, k)
		a._gerar_andar()
		m._anexar(a, k * ALTURA_ANDAR)
	if criar_malha_na_thread:
		m._criar_malha()
	return m

# ---------- fachadas ----------
# f: 0 = +X · 1 = -X · 2 = +Z · 3 = -Z  (n = normal para fora, t = direção ao longo da fachada)
func _n(f: int) -> Vector2:
	return [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)][f]

func _t(f: int) -> Vector2:
	return Vector2(0, 1) if f < 2 else Vector2(1, 0)

func _comp(f: int) -> float:
	return hz * 2.0 if f < 2 else hx * 2.0

func _meia(f: int) -> float:
	return hx if f < 2 else hz

func _tem_rua(f: int) -> int:
	var n := 0
	var c := Vector2(info["x"], info["z"])
	for k in [-0.3, 0.0, 0.3]:
		var p: Vector2 = c + _n(f) * (_meia(f) + 9.0) + _t(f) * _comp(f) * float(k)
		var cc := int((p.x + cid.WORLD.x) / cid.CELL)
		var rr := int((p.y + cid.WORLD.y) / cid.CELL)
		if cc >= 0 and cc < cid.W and rr >= 0 and rr < cid.H and cid.road[rr * cid.W + cc] == 1:
			n += 1
	return n

# pedaço de parede externa entre s0..s1 (ao longo da fachada) e y0..y1: lado de fora com a cor do prédio,
# lado de dentro com papel de parede
func _parede_ext(f: int, s0: float, s1: float, y0: float, y1: float) -> void:
	if s1 - s0 < 0.02 or y1 - y0 < 0.02:
		return
	var n := _n(f)
	var t := _t(f)
	var o := _meia(f)
	var meio := (s0 + s1) * 0.5
	var h := y1 - y0
	for camada in [[o - ESP * 0.25, cor_fora], [o - ESP * 0.75, cor_dentro]]:
		var p2: Vector2 = n * camada[0] + t * meio
		var tam := Vector3(ESP * 0.5, h, s1 - s0) if f < 2 else Vector3(s1 - s0, h, ESP * 0.5)
		paredes.caixa(Vector3(p2.x, y0 + h * 0.5, p2.y), tam, camada[1])
	var pc: Vector2 = n * (o - ESP * 0.5) + t * meio
	col.append([Vector3(pc.x, y0 + h * 0.5, pc.y), Vector3(ESP, h, s1 - s0) if f < 2 else Vector3(s1 - s0, h, ESP), 0.0])
	var t2 := Vector2(ESP, s1 - s0) if f < 2 else Vector2(s1 - s0, ESP)
	_muros.append([Rect2(pc - t2 * 0.5, t2), y0, y1])

func _fachada(f: int, aberturas: Array) -> void:
	aberturas.sort_custom(func(a, b): return a[0] < b[0])
	_vaos[f] = aberturas
	var L := _comp(f)
	var cur := -L * 0.5
	for ab in aberturas:
		var s0: float = maxf(ab[0], cur)
		var s1: float = ab[1]
		_parede_ext(f, cur, s0, 0.0, PE_DIREITO)
		_parede_ext(f, s0, s1, 0.0, ab[2])
		_parede_ext(f, s0, s1, ab[3], PE_DIREITO)
		_enfeite_abertura(f, s0, s1, ab)
		cur = s1
	_parede_ext(f, cur, L * 0.5, 0.0, PE_DIREITO)

func _enfeite_abertura(f: int, s0: float, s1: float, ab: Array) -> void:
	var n := _n(f)
	var t := _t(f)
	var o := _meia(f)
	var meio := (s0 + s1) * 0.5
	var b := Basis(Vector3.UP, 0.0 if f >= 2 else PI * 0.5)
	if ab[4] == "porta":
		# porta caída/aberta para dentro + área livre na frente dela (lado de dentro)
		var dentro: Vector2 = n * (o - 1.4) + t * meio
		proibido.append(Rect2(dentro - Vector2(1.6, 1.6), Vector2(3.2, 3.2)))
		# 0.73: porta dupla de verdade (mundo/porta.gd), abre para dentro: 60% aberta, 20% quebrada, 20% fechada
		var estado := "fechada"
		var abre := 1.0
		if r.randf() < 0.6:
			estado = "aberta"
			abre = r.randf_range(0.85, 1.0)        # 1.02: era 0,6-1,0 (a 60% o vão ficava mais estreito que o corpo)
		elif r.randf() < 0.5:
			estado = "quebrada"
			r.randf_range(-0.3, 0.3)
		var pc: Vector2 = n * (o - ESP * 0.5) + t * meio
		portas.append({"pos": Vector3(pc.x, 0.0, pc.y), "giro": atan2(n.x, n.y), "larg": s1 - s0, "alt": float(ab[3]) - 0.05,
			"parede": ESP, "dupla": true, "estado": estado, "abertura": abre})
	else:
		var fora: Vector2 = n * (o + 0.03) + t * meio
		# 0.90 · no TÉRREO a janela é de verdade (mundo/janela.gd: vidro, quebrar, pular, tábuas): as tábuas e o caixilho
		# daqui vão para um construtor descartado (os sorteios continuam os mesmos: os móveis não mudam de lugar)
		var real := nivel == 0
		var pb = _descarte if real else paredes
		var rj := RandomNumberGenerator.new()
		rj.seed = hash([idx, f, int(s0 * 10.0)])
		var tem_vidro := false
		var tab := 0
		if r.randf() < 0.35:
			# janela tapada com tábuas (por fora)
			tab = rj.randi_range(1, 3)
			var y0: float = ab[2]
			var y1: float = ab[3]
			for k in 3:
				var y := lerpf(y0 + 0.2, y1 - 0.2, k / 2.0)
				var tam := Vector3(0.04, 0.22, s1 - s0 + 0.3) if f < 2 else Vector3(s1 - s0 + 0.3, 0.22, 0.04)
				pb.caixa(Vector3(fora.x, y, fora.y), tam, Moveis.MADEIRA * r.randf_range(0.7, 1.0), Basis(Vector3.FORWARD if f >= 2 else Vector3.RIGHT, r.randf_range(-0.15, 0.15)))
		else:
			# caixilho escuro + cacos de vidro no chão de dentro (térreo: 55% ainda com o vidro inteiro, sem cacos)
			tem_vidro = real and rj.randf() < 0.55
			var rb = _descarte if tem_vidro else resto
			var y1: float = ab[3]
			var tam2 := Vector3(0.08, 0.08, s1 - s0) if f < 2 else Vector3(s1 - s0, 0.08, 0.08)
			pb.caixa(Vector3(fora.x, ab[2], fora.y), tam2, Color(0.15, 0.15, 0.16))
			pb.caixa(Vector3(fora.x, y1, fora.y), tam2, Color(0.15, 0.15, 0.16))
			for k in r.randi_range(1, 4):
				var q: Vector2 = n * (o - ESP - r.randf_range(0.2, 1.2)) + t * r.randf_range(s0, s1)
				rb.caixa(Vector3(q.x, PISO_Y + 0.01, q.y), Vector3(r.randf_range(0.05, 0.2), 0.01, r.randf_range(0.05, 0.15)), Color(0.55, 0.65, 0.68), Basis(Vector3.UP, r.randf() * 3.0))
		if real:
			var pc: Vector2 = n * (o - ESP * 0.5) + t * meio
			janelas.append({"pos": Vector3(pc.x, 0.0, pc.y), "giro": atan2(n.x, n.y), "larg": s1 - s0, "y0": float(ab[2]),
				"y1": float(ab[3]), "parede": ESP, "vidro": tem_vidro, "tabuas": tab})

# ---------- paredes internas ----------
# parede reta de a até b (alinhada a X ou Z) com vãos de porta nas posições "vaos" (distância a partir de a)
func _parede_int(a: Vector2, b: Vector2, vaos: Array) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var em_x := absf(d.x) > 0.5
	vaos.sort()
	var cur := 0.0
	var pedacos: Array = []
	for v in vaos:
		var s0: float = clampf(v - 0.65, 0.0, L)
		var s1: float = clampf(v + 0.65, 0.0, L)
		pedacos.append([cur, s0, 0.0, PE_DIREITO])
		pedacos.append([s0, s1, 2.25, PE_DIREITO])
		var meio: Vector2 = a + d * v
		var nrm := Vector2(-d.y, d.x)
		proibido.append(Rect2(meio - Vector2(1.3, 1.3), Vector2(2.6, 2.6)))
		# 0.73: porta de dentro: 25% arrancada (só o vão), 40% aberta, 35% fechada; abre para um lado sorteado
		var x := _rp.randf()
		var giro := atan2(nrm.x, nrm.y) + (PI if _rp.randf() < 0.5 else 0.0)
		if x >= 0.25 and s1 - s0 > 1.0:
			portas.append({"pos": Vector3(meio.x, 0.0, meio.y), "giro": giro, "larg": s1 - s0 - 0.04, "alt": 2.2,
				"parede": DIV, "dupla": false, "estado": "aberta" if x < 0.65 else "fechada", "abertura": _rp.randf_range(0.85, 1.0)})   # 1.02: era 0,55-1,0 (meio aberta trancava a passagem)
		cur = s1
	pedacos.append([cur, L, 0.0, PE_DIREITO])
	for p in pedacos:
		var s0: float = p[0]
		var s1: float = p[1]
		if s1 - s0 < 0.02:
			continue
		var c2: Vector2 = a + d * (s0 + s1) * 0.5
		var h: float = p[3] - p[2]
		var tam := Vector3(s1 - s0, h, DIV) if em_x else Vector3(DIV, h, s1 - s0)
		paredes.caixa(Vector3(c2.x, p[2] + h * 0.5, c2.y), tam, cor_dentro * 0.95)
		col.append([Vector3(c2.x, p[2] + h * 0.5, c2.y), tam, 0.0])
		_muros.append([Rect2(c2 - Vector2(tam.x, tam.z) * 0.5, Vector2(tam.x, tam.z)), float(p[2]), float(p[3])])

# ---------- cômodos ----------
# converte profundidade (d, da frente para o fundo; d = meia na fachada da frente) e largura (w) em XZ local
func _xz(d: float, w: float) -> Vector2:
	return _n(frente) * d + _t(frente) * w

func _ret(d0: float, d1: float, w0: float, w1: float) -> Rect2:
	var a := _xz(d0, w0)
	var b := _xz(d1, w1)
	var r2 := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())
	return r2.grow(-0.12)

func _dividir(fundo: float, tipos_frente, tipos_fundo: Array) -> void:
	# frente: do fim do fundo até a fachada da frente (uma ou mais salas lado a lado, ligadas por portas)
	# fundo: faixas lado a lado, cada uma com porta para a frente
	var o := _meia(frente) - ESP
	var L := _comp(frente) * 0.5 - ESP
	var wa := -L
	var wb := minf(L, _w_max)            # com escada, os cômodos não entram no vão dela
	var d_div := -o + fundo
	var frentes: Array = tipos_frente if tipos_frente is Array else [tipos_frente]
	# 0.81: a parede da frente/fundo (d_div) encosta nas fachadas dos lados: fora de porta/janela
	var f_neg := _f_de(-_t(frente))
	var f_pos := _f_de(_t(frente))
	d_div = _ajustar(d_div, -o + 2.5, o - 2.5, func(d): return _encontro_livre(f_neg, _xz(d, wa)) and (wb < L - 0.01 or _encontro_livre(f_pos, _xz(d, wb))))
	var f_fundo := _f_de(-_n(frente))
	var nf := frentes.size()
	var lf := (wb - wa) / nf
	var cortes_f: Array = [wa]                     # divisórias da frente: encostam na fachada da frente
	for k in range(1, nf):
		cortes_f.append(_ajustar(wa + lf * k, cortes_f.back() + 2.4, wb - 2.4, func(w): return _encontro_livre(frente, _xz(o, w))))
	cortes_f.append(wb)
	for k in nf:
		var w0: float = cortes_f[k]
		comodos.append([_ret(d_div, o, w0, cortes_f[k + 1]), frentes[k]])
		if k > 0:
			var prof_f := o - d_div
			_parede_int(_xz(d_div, w0), _xz(o, w0), [prof_f * r.randf_range(0.35, 0.65)])
	var n := tipos_fundo.size()
	var larg := (wb - wa) / n
	var cortes: Array = [wa]                       # divisórias do fundo: encostam na fachada do fundo
	for k in range(1, n):
		cortes.append(_ajustar(wa + larg * k, cortes.back() + 2.2, wb - 2.2, func(w): return _encontro_livre(f_fundo, _xz(-o, w))))
	cortes.append(wb)
	var vaos := []
	for k in n:
		var w0: float = cortes[k]
		var w1: float = cortes[k + 1]
		comodos.append([_ret(-o, d_div, w0, w1), tipos_fundo[k]])
		vaos.append((w0 - wa) + (w1 - w0) * r.randf_range(0.3, 0.7))
		if k > 0:
			_parede_int(_xz(-o, w0), _xz(d_div, w0), [])
	_parede_int(_xz(d_div, wa), _xz(d_div, wb), vaos)

# ---------- 0.81: encontros das paredes com as fachadas ----------
func _f_de(n: Vector2) -> int:
	for f in 4:
		if _n(f).is_equal_approx(n):
			return f
	return 0

# uma parede de dentro que encosta na fachada f no ponto p (local) não pode cair numa porta/janela dela
func _encontro_livre(f: int, p: Vector2) -> bool:
	var s := p.dot(_t(f))
	for ab in _vaos.get(f, []):
		if s > float(ab[0]) - 0.35 and s < float(ab[1]) + 0.35:
			return false
	return true

# valor mais perto de "v" (dentro de mn..mx) que passa no teste (de 0,25 em 0,25 m, até 10 m; 1.00: antes 3 m, e
# numa fachada cheia de janelas dos dois lados a divisória acabava encostando numa janela); senão, o próprio v
func _ajustar(v: float, mn: float, mx: float, teste: Callable) -> float:
	for k in 81:
		var off := ceilf(k * 0.5) * 0.25 * (1.0 if k % 2 == 1 else -1.0)
		var c := v + off
		if c >= mn and c <= mx and teste.call(c):
			return c
	return v

# trecho (ao longo da fachada f) ocupado pelo vão da escada: lá não abre porta da rua
func _zona_escada(f: int) -> Array:
	if not _escada:
		return []
	var e := _esc()
	if not (_n(f).is_equal_approx(-_n(frente)) or _n(f).is_equal_approx(_t(frente))):
		return []
	var ss: Array = []
	for d in [-float(e["o"]), float(e["d1"]) + 0.6]:
		for w in [float(e["parede"]) - 0.4, float(e["lw"])]:
			ss.append(_xz(d, w).dot(_t(f)))
	return [ss.min(), ss.max()]

func _cruza(a: float, b: float, zona: Array) -> bool:
	return not zona.is_empty() and b > float(zona[0]) and a < float(zona[1])

# onde a parede do vão da escada encosta na fachada do fundo (lá não pode ter janela) · NAN = não encosta
func _junta_escada(f: int) -> float:
	if not _escada or not _n(f).is_equal_approx(-_n(frente)):
		return NAN
	var e := _esc()
	return _xz(-float(e["o"]), float(e["parede"])).dot(_t(f))

func _layout(uso_forcado := "") -> void:
	var uso: String = info["uso"] if uso_forcado == "" else uso_forcado
	var prof := _meia(frente) * 2.0 - ESP * 2.0
	var largura := _comp(frente) - ESP * 2.0
	match uso:
		"residencial":
			var tipos := ["cozinha", "quarto", "banheiro"] if largura > 23.0 else ["cozinha", "quarto"]
			if largura > 29.0:
				tipos = ["cozinha", "quarto", "quarto", "banheiro"]
			_embaralhar(tipos)
			var frentes := ["sala"]
			var extras := ["sala_jantar", "quarto", "escritorio_casa"]
			_embaralhar(extras)
			for k in clampi(int(largura / 11.0), 1, 3) - 1:
				frentes.append(extras[k])
			_dividir(prof * r.randf_range(0.42, 0.55), frentes, tipos)
		"loja", "mercado", "farmacia":
			_dividir(r.randf_range(5.0, 7.0), uso, ["deposito", "banheiro"])
		"restaurante":
			_dividir(r.randf_range(6.0, 8.0), "restaurante", ["cozinha_rest", "deposito"])
		"escritorio":
			_dividir(r.randf_range(6.0, 8.0), "escritorio", ["reuniao", "copa", "banheiro"] if largura > 23.0 else ["reuniao", "copa"])
		"delegacia":
			_dividir(prof - r.randf_range(7.0, 9.0), "recepcao", ["cela", "armas", "escritorio_pol"])
		"clinica":
			_dividir(prof - r.randf_range(7.0, 9.0), "espera", ["consultorio", "consultorio", "deposito"] if largura > 22.0 else ["consultorio", "deposito"])
		_:
			_dividir(prof * 0.5, "sala", ["cozinha", "quarto"])

# ---------- arrumar móveis ----------
func _livre(ret: Rect2, sala: Rect2) -> bool:
	if not sala.grow(0.01).encloses(ret):
		return false
	for o in ocupado:
		if o.grow(0.05).intersects(ret):
			return false
	for p in proibido:
		if p.intersects(ret):
			return false
	var dentro := ret.grow(-0.03)                      # 0.81: nenhum móvel cruza parede (nem a grade da cela)
	for m in _muros:
		if float(m[1]) < 1.0 and (m[0] as Rect2).intersects(dentro):
			return false
	return true

# 0.81: tem parede (pedaço cheio) no ponto p (plano XZ) na altura y?
func _tem_parede(p: Vector2, y: float) -> bool:
	for m in _muros:
		if y >= float(m[1]) and y <= float(m[2]) and (m[0] as Rect2).grow(0.02).has_point(p):
			return true
	return false

# 0.81: o móvel "de parede" (centro c, giro g = a frente dele, tam = largura x fundura) tem parede de verdade atrás
# na largura toda? Baixo: só parede (não vão de porta, não borda aberta). Alto: parede cheia também em cima
# (não fica na frente de janela).
func _parede_atras(nome: String, c: Vector2, g: float, tam: Vector2) -> bool:
	var fr := Vector2(sin(g), cos(g))
	var lado := Vector2(fr.y, -fr.x)
	var atras := c - fr * (tam.y * 0.5 + 0.15)
	var alto: float = ALTO.get(nome, 0.9)
	var alturas := [0.4] if alto <= ALTURA_PEITORIL else [0.4, minf(alto, 2.2) - 0.05]
	var n := maxi(2, int(ceil(tam.x / 0.3)) + 1)
	for k in n:
		var q := atras + lado * lerpf(-tam.x * 0.45, tam.x * 0.45, float(k) / (n - 1))
		for y in alturas:
			if not _tem_parede(q, y):
				return false
	return true

func _colocar(nome: String, giro: float, centro: Vector2, ret: Rect2, uso: String) -> void:
	ocupado.append(ret)
	var b := Basis(Vector3.UP, giro + r.randf_range(-0.06, 0.06))
	Moveis.desenhar(nome, resto, Vector3(centro.x, 0.0, centro.y), b, r, col, cont, uso)

func _por_parede(nome: String, sala: Rect2, uso: String) -> bool:
	var tam: Vector2 = Moveis.TAM[nome]
	var cands := []
	var x := sala.position.x + tam.x * 0.5
	while x <= sala.end.x - tam.x * 0.5:
		cands.append([Vector2(x, sala.position.y + tam.y * 0.5), 0.0, Rect2(x - tam.x * 0.5, sala.position.y, tam.x, tam.y)])
		cands.append([Vector2(x, sala.end.y - tam.y * 0.5), PI, Rect2(x - tam.x * 0.5, sala.end.y - tam.y, tam.x, tam.y)])
		x += 0.45
	var z := sala.position.y + tam.x * 0.5
	while z <= sala.end.y - tam.x * 0.5:
		cands.append([Vector2(sala.position.x + tam.y * 0.5, z), PI * 0.5, Rect2(sala.position.x, z - tam.x * 0.5, tam.y, tam.x)])
		cands.append([Vector2(sala.end.x - tam.y * 0.5, z), -PI * 0.5, Rect2(sala.end.x - tam.y, z - tam.x * 0.5, tam.y, tam.x)])
		z += 0.45
	_embaralhar(cands)
	for c in cands:
		if _livre(c[2], sala) and _parede_atras(nome, c[0], c[1], tam):
			_colocar(nome, c[1], c[0], c[2], uso)
			return true
	return false

func _no_meio(nome: String, sala: Rect2, uso: String, sorteado := false) -> bool:
	var tam: Vector2 = Moveis.TAM[nome]
	for tentativa in 12:
		var giro := (r.randi() % 4) * PI * 0.5 if sorteado else 0.0
		var t2 := tam if int(round(giro / (PI * 0.5))) % 2 == 0 else Vector2(tam.y, tam.x)
		var c := sala.get_center()
		if sorteado or tentativa > 0:
			c += Vector2(r.randf_range(-1, 1) * maxf(0.0, sala.size.x * 0.5 - t2.x * 0.5 - 0.8), r.randf_range(-1, 1) * maxf(0.0, sala.size.y * 0.5 - t2.y * 0.5 - 0.8))
		var ret := Rect2(c - t2 * 0.5, t2)
		if nome == "tapete":
			if sala.grow(-0.3).encloses(ret):
				resto_tapete(c, giro)
				return true
			continue
		if _livre(ret, sala):
			_colocar(nome, giro, c, ret, uso)
			return true
	return false

func resto_tapete(c: Vector2, giro: float) -> void:
	Moveis.desenhar("tapete", resto, Vector3(c.x, 0.0, c.y), Basis(Vector3.UP, giro), r, col, cont)

func _fileiras(nome: String, sala: Rect2, uso: String) -> void:
	var tam: Vector2 = Moveis.TAM[nome]
	var corredor: float = {"gondola": 2.0, "arara": 1.8, "mesa_bar": 1.3, "mesa_escritorio": 1.1}.get(nome, 1.6)
	var area := sala.grow(-2.3)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var horiz := area.size.x >= area.size.y
	var passo_a := tam.x + (0.0 if nome == "gondola" else corredor * 0.6)
	var passo_b := tam.y + corredor
	var a := 0.0
	while a + tam.x <= (area.size.x if horiz else area.size.y):
		var b := 0.0
		while b + tam.y <= (area.size.y if horiz else area.size.x):
			var c: Vector2
			var ret: Rect2
			var giro := 0.0
			if horiz:
				c = area.position + Vector2(a + tam.x * 0.5, b + tam.y * 0.5)
				ret = Rect2(c - tam * 0.5, tam)
			else:
				c = area.position + Vector2(b + tam.y * 0.5, a + tam.x * 0.5)
				ret = Rect2(c - Vector2(tam.y, tam.x) * 0.5, Vector2(tam.y, tam.x))
				giro = PI * 0.5
			if r.randf() < 0.85 and _livre(ret, sala):
				_colocar(nome, giro, c, ret, uso)
			b += passo_b
		a += passo_a

func _mobiliar() -> void:
	var uso: String = info["uso"]
	for cm in comodos:
		var sala: Rect2 = cm[0]
		var tipo: String = cm[1]
		if tipo == "cela":
			_grades_cela(sala)                        # 0.81: antes dos móveis (a cama não atravessa a grade)
		for item in COMODOS.get(tipo, []):
			match item[1]:
				"parede":
					_por_parede(item[0], sala, uso)
				"meio":
					_no_meio(item[0], sala, uso)
				"centro":
					_no_meio(item[0], sala, uso, true)
				"fileiras":
					_fileiras(item[0], sala, uso)
		# cômodos grandes ganham mais coisas nas paredes (casa e comércio)
		var extra := int(sala.get_area() / 45.0) - 1
		for k in clampi(extra, 0, 4):
			_por_parede(["planta", "quadro", "luminaria", "cadeira", "estante_livros", "aparador", "lixeira", "caixas"][r.randi() % 8], sala, uso)
		# sinais de sobreviventes: colchão com latas vazias e móveis empilhados na janela
		if r.randf() < 0.1 and sala.get_area() > 14.0:
			_no_meio("colchao", sala, uso, true)
		if r.randf() < 0.12:
			_por_parede("barricada", sala, uso)
		# abandono: entulho, papéis e manchas
		if r.randf() < 0.35:
			_no_meio("entulho", sala, uso, true)
		for k in r.randi_range(2, 8):
			var p := Vector2(r.randf_range(sala.position.x, sala.end.x), r.randf_range(sala.position.y, sala.end.y))
			resto.caixa(Vector3(p.x, PISO_Y + 0.008, p.y), Vector3(0.21, 0.004, 0.3), Moveis.BRANCO * r.randf_range(0.7, 1.0), Basis(Vector3.UP, r.randf() * 3.0))
		if r.randf() < 0.4:
			var p := Vector2(r.randf_range(sala.position.x, sala.end.x), r.randf_range(sala.position.y, sala.end.y))
			var s := r.randf_range(0.5, 1.4)
			resto.caixa(Vector3(p.x, PISO_Y + 0.004, p.y), Vector3(s, 0.003, s * r.randf_range(0.5, 1.0)), Color(0.18, 0.08, 0.06), Basis(Vector3.UP, r.randf() * 3.0))

func _grades_cela(sala: Rect2) -> void:
	# grade de ferro atravessando a cela, com a porta aberta. 0.81: na direção em que as DUAS pontas encostam em
	# parede cheia (não termina numa janela da fachada)
	var meio := sala.get_center()
	var horiz := sala.size.x >= sala.size.y
	var achou := false
	for k in 31:                                   # do meio para os lados, de 0,4 em 0,4 m (1.00: até 6 m; antes 2,4)
		var off := ceilf(k * 0.5) * 0.4 * (1.0 if k % 2 == 1 else -1.0)
		for tenta in [horiz, not horiz]:
			var m2 := sala.get_center() + (Vector2(0, off) if tenta else Vector2(off, 0))
			if not sala.grow(-1.0).has_point(m2):
				continue
			var a2 := Vector2(sala.position.x - 0.2, m2.y) if tenta else Vector2(m2.x, sala.position.y - 0.2)
			var b2 := Vector2(sala.end.x + 0.2, m2.y) if tenta else Vector2(m2.x, sala.end.y + 0.2)
			# com folga até a borda da janela (1.00: 0,45; com 0,35 a grade de 0,1 m de espessura ainda encostava nela)
			var lat := Vector2(0, 0.45) if tenta else Vector2(0.45, 0)
			if _tem_parede(a2, 1.8) and _tem_parede(b2, 1.8) and _tem_parede(a2 + lat, 1.8) and _tem_parede(a2 - lat, 1.8) \
					and _tem_parede(b2 + lat, 1.8) and _tem_parede(b2 - lat, 1.8):
				horiz = tenta
				meio = m2
				achou = true
				break
		if achou:
			break
	if not achou:
		return                                     # 1.00: sem lugar com parede cheia nas duas pontas: cela sem grade
	var L := sala.size.x if horiz else sala.size.y
	var ini := (sala.position.x if horiz else sala.position.y)
	var porta := r.randf_range(0.2, 0.7) * L
	var k := 0.1
	while k < L:
		if absf(k - porta) > 0.55:
			var p := Vector2(ini + k, meio.y) if horiz else Vector2(meio.x, ini + k)
			resto.cilindro(Vector3(p.x, 1.4, p.y), 0.025, 2.8, 5, Color(0.25, 0.25, 0.27))
		k += 0.16
	var barra := Vector3(L, 0.06, 0.06) if horiz else Vector3(0.06, 0.06, L)
	resto.caixa(Vector3(meio.x, 2.8, meio.y), barra, Color(0.25, 0.25, 0.27))
	resto.caixa(Vector3(meio.x, 0.15, meio.y), barra, Color(0.25, 0.25, 0.27))
	for seg in [[0.0, porta - 0.55], [porta + 0.55, L]]:
		var a: float = ini + float(seg[0])
		var b: float = ini + float(seg[1])
		if b - a > 0.1:
			var c := Vector2((a + b) * 0.5, meio.y) if horiz else Vector2(meio.x, (a + b) * 0.5)
			col.append([Vector3(c.x, 1.4, c.y), Vector3(b - a, 2.8, 0.1) if horiz else Vector3(0.1, 2.8, b - a), 0.0])
			var t2 := Vector2(b - a, 0.1) if horiz else Vector2(0.1, b - a)
			_muros.append([Rect2(c - t2 * 0.5, t2), 0.0, 2.8])
	# a passagem da porta da grade fica livre
	var pp := Vector2(ini + porta, meio.y) if horiz else Vector2(meio.x, ini + porta)
	proibido.append(Rect2(pp - Vector2(0.8, 0.8), Vector2(1.6, 1.6)))

# ---------- montagem ----------
func _gerar(inf: Dictionary, i: int, cidade) -> void:
	info = inf
	idx = i
	cid = cidade
	r.seed = i * 7919 + 13
	_rp.seed = i * 4241 + 5
	hx = float(info["sx"]) * 0.5
	hz = float(info["sz"]) * 0.5
	cor_fora = info["cor"] * 0.95
	cor_fora.a = 1.0
	cor_dentro = PAPEL_PAREDE[r.randi() % PAPEL_PAREDE.size()]
	var uso: String = info["uso"]
	# fachadas com rua: portas (a principal decide a "frente" dos cômodos)
	var melhor := -1
	var ruas := [0, 0, 0, 0]
	for f in 4:
		ruas[f] = _tem_rua(f)
		if melhor < 0 or ruas[f] > ruas[melhor]:
			melhor = f
	if ruas[melhor] == 0:
		melhor = r.randi() % 4
	frente = melhor
	var loja := uso in ["loja", "mercado", "farmacia", "restaurante"]
	_escada = extras > 0 or telhado
	for f in 4:
		var L := _comp(f)
		var ab: Array = []
		var tem_porta: bool = f == frente or (ruas[f] > 0 and r.randf() < 0.45)
		var porta_s := r.randf_range(-L * 0.5 + 3.0, L * 0.5 - 3.0) if f != frente else r.randf_range(-L * 0.25, L * 0.25)
		# 0.81: porta da rua não abre para dentro do vão da escada (tenta outro lugar; senão, sem porta deste lado)
		var zona := _zona_escada(f)
		if tem_porta and f != frente and _cruza(porta_s - PORTA_L * 0.5 - 0.3, porta_s + PORTA_L * 0.5 + 0.3, zona):
			tem_porta = false
			for k in 8:
				var tenta := r.randf_range(-L * 0.5 + 3.0, L * 0.5 - 3.0)
				if not _cruza(tenta - PORTA_L * 0.5 - 0.3, tenta + PORTA_L * 0.5 + 0.3, zona):
					porta_s = tenta
					tem_porta = true
					break
		if tem_porta:
			ab.append([porta_s - PORTA_L * 0.5, porta_s + PORTA_L * 0.5, 0.0, PORTA_A, "porta"])
		var vitrine := loja and f == frente
		var lj := 2.6 if vitrine else 1.3
		var passo := 3.3 if vitrine else 3.4
		var junta := _junta_escada(f)
		var s := -L * 0.5 + 1.6
		while s + lj < L * 0.5 - 1.2:
			if (not tem_porta or absf(s + lj * 0.5 - porta_s) > (PORTA_L + lj) * 0.5 + 0.5) and not (s - 0.35 < junta and junta < s + lj + 0.35):
				if vitrine:
					ab.append([s, s + lj, 0.55, 3.3, "janela"])
				elif r.randf() < 0.85:
					ab.append([s, s + lj, 1.05, 2.5, "janela"])
			s += passo
		_fachada(f, ab)
	if _escada:
		_reservar_escada()
	_layout()
	_mobiliar()
	if _escada:
		_construir_escada(true, false)
	# piso e teto
	var cor_piso: Color = {"residencial": Color(0.5, 0.34, 0.2), "escritorio": Color(0.38, 0.38, 0.4), "loja": Color(0.72, 0.7, 0.64),
		"mercado": Color(0.75, 0.74, 0.7), "farmacia": Color(0.78, 0.78, 0.76), "clinica": Color(0.7, 0.74, 0.72),
		"delegacia": Color(0.55, 0.55, 0.52), "restaurante": Color(0.55, 0.36, 0.24)}.get(uso, Color(0.5, 0.5, 0.5))
	_pad_piso = {"residencial": 2.0, "restaurante": 2.0, "escritorio": 4.0}.get(uso, 1.0)
	piso.caixa(Vector3(0, PISO_Y - 0.05, 0), Vector3(hx * 2.0 - 0.02, 0.1, hz * 2.0 - 0.02), cor_piso, Basis.IDENTITY, true)
	col.append([Vector3(0, -0.05, 0), Vector3(hx * 2.0, 0.1, hz * 2.0), 0.0])
	_laje(teto, PE_DIREITO, LAJE, _buraco(0) if _escada else Rect2(), Color(0.78, 0.77, 0.74), true, extras > 0)
	if extras == 0 and telhado:
		_telhado(PE_DIREITO + LAJE, 0)
	_pontos = _pontos_chao()

# a malha (4 superfícies) também pode ser feita na thread (o RenderingServer aceita)
func _criar_malha() -> void:
	var caixa := Vector4(info["x"], info["z"], hx - ESP, hz - ESP)
	var am := ArrayMesh.new()
	paredes.malha(Mat.material(Mat.INTERIOR, {"caixa": caixa, "padrao": 3.0, "semente": float(info["sem"]), "papel": 1.0,
		"tipo_predio": float(info.get("tipo", 0))}), am)   # 0.92: papel de parede velho por dentro, o material do prédio por fora
	piso.malha(Mat.material(Mat.INTERIOR, {"caixa": caixa, "padrao": _pad_piso}), am)
	teto.malha(Mat.material(Mat.INTERIOR, {"caixa": caixa, "padrao": 0.0}), am)
	_malha = am
	var ad := ArrayMesh.new()
	resto.malha(Mat.material(Mat.INTERIOR, {"caixa": caixa, "padrao": 0.0}), ad)
	_malha_detalhes = ad if ad.get_surface_count() > 0 else null

# 2ª parte (thread principal): cria os nós, a malha, a colisão e os contêineres de loot
# 1.00: com "tarefas" (uma Array, mundo/interiores.gd), as caixas de loot dos móveis, as portas e as janelas não são
# montadas aqui: cada uma vira uma tarefa que o interiores.gd faz aos poucos, sem engasgar o quadro
func criar(lm, tarefas = null) -> Node3D:
	loot = lm
	var uso: String = info["uso"]
	var raiz := Node3D.new()
	raiz.name = "Interior_%d" % idx
	raiz.position = Vector3(info["x"], cid.Y_CALCADA, info["z"])     # piso no nível do lote (sem degrau na porta)
	if _malha == null:
		_criar_malha()
	var mi := MeshInstance3D.new()
	mi.name = "Malha"
	mi.mesh = _malha
	raiz.add_child(mi)
	if _malha_detalhes != null:
		var md := MeshInstance3D.new()
		md.name = "Detalhes"
		md.mesh = _malha_detalhes
		md.visibility_range_end = DETALHES_ALCANCE
		md.visibility_range_end_margin = 3.0
		raiz.add_child(md)
	# casca dos andares de cima (mesmo shader e janelas do bloco original)
	var h: float = info["h"]
	var base := ALTURA_ANDAR * (extras + 1)
	if h > base + 0.5 and not telhado:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		var bm := BoxMesh.new()
		bm.material = cid.mat_predio
		mm.mesh = bm
		mm.instance_count = 1
		var hu := h - base
		mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(hx * 2.0, hu, hz * 2.0)), Vector3(0, base + hu * 0.5, 0)))
		var cc: Color = info["cor"]
		cc.a = 1.0 - base / 40.0
		mm.set_instance_color(0, cc)
		mm.set_instance_custom_data(0, Color(hx * 2.0, hu, hz * 2.0, cid.dado_predio(int(info["tipo"]), float(info["sem"]))))
		var casca := MultiMeshInstance3D.new()
		casca.name = "Casca"
		casca.multimesh = mm
		raiz.add_child(casca)
		col.append([Vector3(0, base + hu * 0.5, 0), Vector3(hx * 2.0, hu, hz * 2.0), 0.0])
	# colisão (1.00: as caixas vão direto no corpo, sem um nó CollisionShape3D para cada: ~500 nós a menos por prédio)
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	adicionar_caixas(corpo, col)
	raiz.add_child(corpo)
	# loot nos móveis (contêineres invisíveis) e no chão
	if loot != null:
		for k in cont.size():
			_fazer(tarefas, func(): _caixa(raiz, k))
		raiz.set_meta("pontos_chao", _pontos)
	for k in portas.size():
		_fazer(tarefas, func(): _porta(raiz, k))
	for k in janelas.size():
		_fazer(tarefas, func(): _janela(raiz, k))
	return raiz

static func _fazer(tarefas, f: Callable) -> void:
	if tarefas == null:
		f.call()
	else:
		tarefas.append(f)

# 1.00: caixas de colisão [centro, tamanho, giro (, Basis)] num corpo, como "donos de forma" (sem nós filhos)
static func adicionar_caixas(corpo: CollisionObject3D, caixas: Array) -> void:
	for c in caixas:
		var bs := BoxShape3D.new()
		bs.size = (c[1] as Vector3).abs() + Vector3(0.001, 0.001, 0.001)
		var dono := corpo.create_shape_owner(corpo)
		corpo.shape_owner_add_shape(dono, bs)
		corpo.shape_owner_set_transform(dono, Transform3D(c[3] if c.size() > 3 else Basis(Vector3.UP, c[2]), c[0]))

func _caixa(raiz: Node3D, k: int) -> void:
	if not is_instance_valid(raiz):
		return
	var c: Dictionary = cont[k]
	var cx = CaixaMundo.new()
	cx.invisivel = true
	cx.nome = c["nome"]
	cx.tamanho = c["tam"]
	cx.grade = loot.grade("p%d_%d" % [idx, k], c["loot"], c["nome"], c["tam"])
	raiz.add_child(cx)
	cx.position = c["pos"] + Vector3(0, 0.1, 0)

# 0.73: portas (o estado mexido fica guardado no loot: loot.portas)
func _porta(raiz: Node3D, k: int) -> void:
	if not is_instance_valid(raiz):
		return
	var e: Dictionary = portas[k]
	var pt = PortaCls.new()
	pt.id = "p%d:%d" % [idx, k]
	pt.largura = e["larg"]
	pt.altura = e["alt"]
	pt.parede = e["parede"]
	pt.dupla = e["dupla"]
	pt.cor = Moveis.MADEIRA * (0.75 if e["dupla"] else 0.95)
	pt.aberta = e["estado"] == "aberta"
	pt.quebrada = e["estado"] == "quebrada"
	pt.abertura = e["abertura"]
	if loot != null and loot.get("portas") != null and loot.portas.has(pt.id):
		pt.aplicar(loot.portas[pt.id])
	pt.position = e["pos"]
	pt.rotation.y = e["giro"]
	raiz.add_child(pt)

# 0.90: janelas do térreo (mesmo esquema das portas: id "j<prédio>:<n>", estado no loot)
func _janela(raiz: Node3D, k: int) -> void:
	if not is_instance_valid(raiz):
		return
	var e: Dictionary = janelas[k]
	var jn = JanelaCls.new()
	jn.id = "j%d:%d" % [idx, k]
	jn.largura = e["larg"]
	jn.y0 = e["y0"]
	jn.y1 = e["y1"]
	jn.parede = e["parede"]
	jn.vidro = e["vidro"]
	jn.tabuas = e["tabuas"]
	if loot != null and loot.get("portas") != null and loot.portas.has(jn.id):
		jn.aplicar(loot.portas[jn.id])
	jn.position = e["pos"]
	jn.rotation.y = e["giro"]
	raiz.add_child(jn)

# 1.00: embaralha com o sorteio do PRÉDIO (o shuffle() da Godot usa o sorteio global: o mesmo prédio saía com outros
# móveis cada vez que abria, e o loot guardado nas caixas "p<prédio>_<n>" trocava de móvel ou sumia)
func _embaralhar(a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var t = a[k]
		a[k] = a[j]
		a[j] = t

# lugares livres no chão para itens soltos (entre os móveis)
func _pontos_chao() -> Array:
	var pts := []
	for cm in comodos:
		var sala: Rect2 = cm[0]
		for k in 6:
			var p := Vector2(r.randf_range(sala.position.x + 0.5, sala.end.x - 0.5), r.randf_range(sala.position.y + 0.5, sala.end.y - 0.5))
			var ok := true
			for o in ocupado:
				if o.grow(0.2).has_point(p):
					ok = false
					break
			if ok:
				pts.append([Vector3(p.x, 0.0, p.y), cm[1]])
	return pts

# ---------- ANDARES DE CIMA ----------
func _herdar(m, k: int) -> void:
	info = m.info
	idx = m.idx
	cid = m.cid
	hx = m.hx
	hz = m.hz
	frente = m.frente
	cor_fora = m.cor_fora
	extras = m.extras
	telhado = m.telhado
	nivel = k
	r.seed = idx * 7919 + 13 + k * 101
	_rp.seed = idx * 4241 + 5 + k * 37
	cor_dentro = PAPEL_PAREDE[r.randi() % PAPEL_PAREDE.size()]

func _gerar_andar() -> void:
	# fachadas: só janelas (sem portas, sem vitrine)
	for f in 4:
		var L := _comp(f)
		var ab: Array = []
		var junta := _junta_escada(f)
		var s := -L * 0.5 + 1.6
		while s + 1.3 < L * 0.5 - 1.2:
			if r.randf() < 0.85 and not (s - 0.35 < junta and junta < s + 1.3 + 0.35):
				ab.append([s, s + 1.3, 1.05, 2.5, "janela"])
			s += 3.4
		_fachada(f, ab)
	_escada = true
	_reservar_escada()
	var uso: String = info["uso"]
	var uso_andar := "residencial" if uso == "residencial" else "escritorio"
	_layout(uso_andar)
	_mobiliar()
	var topo := nivel == extras
	_construir_escada(not topo or telhado, true)
	var cor_piso: Color = Color(0.5, 0.34, 0.2) if uso_andar == "residencial" else Color(0.38, 0.38, 0.4)
	_pad_piso = 2.0 if uso_andar == "residencial" else 4.0
	_laje(piso, PISO_Y - 0.1, 0.1, _buraco(nivel - 1), cor_piso, false, false)
	var buraco_cima := _buraco(nivel) if (not topo or telhado) else Rect2()
	_laje(teto, PE_DIREITO, LAJE, buraco_cima, Color(0.78, 0.77, 0.74), true, not topo)
	if topo and telhado:
		_telhado(PE_DIREITO + LAJE, nivel)
	_pontos = _pontos_chao()

# junta um andar (gerado à parte) neste interior, "dy" metros acima
func _anexar(a, dy: float) -> void:
	for par in [[paredes, a.paredes], [piso, a.piso], [resto, a.resto], [teto, a.teto]]:
		var dst = par[0]
		var src = par[1]
		for v in src.v:
			dst.v.append(v + Vector3(0, dy, 0))
		dst.n.append_array(src.n)
		dst.c.append_array(src.c)
		dst.uv.append_array(src.uv)
	for c in a.col:
		var e: Array = c.duplicate()
		e[0] = (c[0] as Vector3) + Vector3(0, dy, 0)
		col.append(e)
	for c in a.cont:
		var e: Dictionary = c.duplicate()
		e["pos"] = (c["pos"] as Vector3) + Vector3(0, dy, 0)
		cont.append(e)
	for p in a._pontos:
		_pontos.append([(p[0] as Vector3) + Vector3(0, dy, 0), p[1]])
	for pt in a.portas:
		var e: Dictionary = pt.duplicate()
		e["pos"] = (pt["pos"] as Vector3) + Vector3(0, dy, 0)
		portas.append(e)

# ---------- escada ----------
# vão da escada: canto do fundo, encostado na parede lateral. Dois lances lado a lado (A e B):
#   lance A sobe do fundo para a frente (térreo->1º, 2º->telhado) · lance B sobe da frente para o fundo (1º->2º)
func _esc() -> Dictionary:
	var o := _meia(frente) - ESP
	var lw := _comp(frente) * 0.5 - ESP
	var d0 := -o + PATAMAR                       # 0.81: patamar no fundo (antes 0,3 m: dava de cara com a parede)
	return {"o": o, "lw": lw, "d0": d0, "d1": d0 + ESCADA_C,
		"a": [lw - ESCADA_L, lw], "b": [lw - 2.0 * ESCADA_L, lw - ESCADA_L], "parede": lw - 2.0 * ESCADA_L - 0.08}

func _reservar_escada() -> void:
	var e := _esc()
	_w_max = float(e["parede"]) - 0.1
	proibido.append(_ret(-float(e["o"]), float(e["d1"]) + 1.6, float(e["parede"]) - 0.3, float(e["lw"])))
	# parede do vão da escada (do fundo até um pouco depois do fim dos lances), com uma PORTA no patamar do fundo
	_parede_int(_xz(-float(e["o"]), float(e["parede"])), _xz(float(e["d1"]) + 0.3, float(e["parede"])), [PATAMAR * 0.5 + 0.05])

# retângulo (no plano XZ local) do lance que SAI do nível k (para o buraco na laje)
func _buraco(k: int) -> Rect2:
	var e := _esc()
	var faixa: Array = e["a"] if k % 2 == 0 else e["b"]
	var a := _xz(float(e["d0"]), float(faixa[0]))
	var b := _xz(float(e["d1"]), float(faixa[1]))
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())

func _tam_xz(ao_longo: float, lateral: float, alto: float) -> Vector3:
	# tamanho de uma caixa alinhada com a "frente": ao_longo = direção frente/fundo
	return Vector3(ao_longo, alto, lateral) if frente < 2 else Vector3(lateral, alto, ao_longo)

func _construir_escada(sobe: bool, buraco_embaixo: bool) -> void:
	var e := _esc()
	var concreto := Color(0.52, 0.51, 0.49)
	if sobe:
		var faixa: Array = e["a"] if nivel % 2 == 0 else e["b"]
		var w_meio := (float(faixa[0]) + float(faixa[1])) * 0.5
		var d0: float = e["d0"]
		var d1: float = e["d1"]
		var sobe_para_frente := nivel % 2 == 0
		var n := 20
		var hd := ALTURA_ANDAR / n
		var cd := ESCADA_C / n
		for i in n:
			var t := (i + 0.5) / n
			var d := lerpf(d0, d1, t) if sobe_para_frente else lerpf(d1, d0, t)
			var topo_y := (i + 1) * hd
			var p := _xz(d, w_meio)
			resto.caixa(Vector3(p.x, topo_y * 0.5, p.y), _tam_xz(cd + 0.01, ESCADA_L - 0.06, topo_y), concreto * (0.95 if i % 2 == 0 else 1.0))
		# corrimão do lado de dentro (1.02: sempre na borda ENTRE os dois lances, que é o lado aberto; no lance B ele
		# ficava encostado na parede e o lado do vão não tinha nada)
		var borda := float(e["a"][0])
		var w_corr := borda + (0.05 if nivel % 2 == 0 else -0.05)
		for i in range(0, n, 4):
			var t := (i + 0.5) / n
			var d := lerpf(d0, d1, t) if sobe_para_frente else lerpf(d1, d0, t)
			var p := _xz(d, w_corr)
			resto.cilindro(Vector3(p.x, (i + 1) * hd + 0.5, p.y), 0.025, 1.0, 5, Color(0.25, 0.25, 0.27))
		# rampa invisível de colisão (sobe suave; o personagem não tropeça nos degraus)
		var dir3 := Vector3(_n(frente).x, 0.0, _n(frente).y) * (1.0 if sobe_para_frente else -1.0)
		var lat3 := Vector3(_t(frente).x, 0.0, _t(frente).y)
		var u := (dir3 * ESCADA_C + Vector3.UP * ALTURA_ANDAR).normalized()
		var x := lat3
		var y := u.cross(x)
		if y.y < 0.0:
			x = -x
			y = -y
		var base := Basis(x, y, u)
		var meio := _xz((d0 + d1) * 0.5, w_meio)
		var comp := sqrt(ESCADA_C * ESCADA_C + ALTURA_ANDAR * ALTURA_ANDAR)
		col.append([Vector3(meio.x, ALTURA_ANDAR * 0.5, meio.y) - y * 0.15, Vector3(ESCADA_L, 0.3, comp + 0.4), 0.0, base])
		# 1.02: barra de cima do corrimão e a "parede" fina dele (segura: antes dava para cair no vão da escada)
		var mc := _xz((d0 + d1) * 0.5, w_corr)
		var sobre := Vector3(mc.x, ALTURA_ANDAR * 0.5, mc.y)
		resto.caixa(sobre + y * 1.0, Vector3(0.05, 0.05, comp), Color(0.25, 0.25, 0.27), base)
		col.append([sobre + y * 0.55, Vector3(0.08, 1.1, comp), 0.0, base])
	if buraco_embaixo:
		# corrimão em volta do buraco do lance que chegou de baixo (não deixa cair)
		var veio_a := (nivel - 1) % 2 == 0
		var lim: float = float(e["a"][0])          # borda entre os dois lances (a outra é parede)
		var ini: float = float(e["d0"]) if veio_a else float(e["d0"]) + 1.4
		var fim: float = float(e["d1"]) - 1.4 if veio_a else float(e["d1"])
		_grade(_xz(ini, lim), _xz(fim, lim))
		if not veio_a:
			# lance B: a ponta da frente do buraco é o pé da escada lá embaixo -> grade atravessada
			_grade(_xz(float(e["d1"]), float(e["b"][0])), _xz(float(e["d1"]), float(e["b"][1])))

# grade de proteção (1 m de altura) de a até b
func _grade(a: Vector2, b: Vector2) -> void:
	var L := a.distance_to(b)
	if L < 0.1:
		return
	var cor := Color(0.25, 0.25, 0.27)
	var k := 0.0
	while k <= L:
		var p := a.lerp(b, k / L)
		resto.cilindro(Vector3(p.x, 0.5, p.y), 0.025, 1.0, 5, cor)
		k += 1.0
	var m := (a + b) * 0.5
	var em_x := absf(b.x - a.x) > absf(b.y - a.y)
	var tam := Vector3(L, 0.05, 0.05) if em_x else Vector3(0.05, 0.05, L)
	resto.caixa(Vector3(m.x, 1.0, m.y), tam, cor)
	resto.caixa(Vector3(m.x, 0.5, m.y), tam, cor)
	col.append([Vector3(m.x, 0.55, m.y), Vector3(L, 1.1, 0.08) if em_x else Vector3(0.08, 1.1, L), 0.0])

# laje (piso/teto) com um buraco retangular (o vão da escada)
func _laje(c, y: float, esp: float, buraco: Rect2, cor: Color, colisao: bool, sem_cima: bool) -> void:
	var cheio := Rect2(-hx, -hz, hx * 2.0, hz * 2.0)
	var partes: Array[Rect2] = []
	if buraco.size.x <= 0.0:
		partes.append(cheio)
	else:
		var b := buraco.intersection(cheio)
		partes.append(Rect2(cheio.position.x, cheio.position.y, b.position.x - cheio.position.x, cheio.size.y))
		partes.append(Rect2(b.end.x, cheio.position.y, cheio.end.x - b.end.x, cheio.size.y))
		partes.append(Rect2(b.position.x, cheio.position.y, b.size.x, b.position.y - cheio.position.y))
		partes.append(Rect2(b.position.x, b.end.y, b.size.x, cheio.end.y - b.end.y))
	for p in partes:
		if p.size.x < 0.02 or p.size.y < 0.02:
			continue
		var ctr := p.get_center()
		c.caixa(Vector3(ctr.x, y + esp * 0.5, ctr.y), Vector3(p.size.x, esp, p.size.y), cor, Basis.IDENTITY, false, sem_cima)
		if colisao:
			col.append([Vector3(ctr.x, y + esp * 0.5, ctr.y), Vector3(p.size.x, esp, p.size.y), 0.0])

# telhado: piso de concreto (a laje de cima), mureta em volta e grade no buraco da escada
func _telhado(y: float, k: int) -> void:
	var mureta := Color(0.6, 0.58, 0.55)
	for f in 4:
		var n := _n(f)
		var o := _meia(f)
		var comp := _comp(f)
		var pc: Vector2 = n * (o - 0.12)
		var tam := Vector3(0.24, 1.0, comp) if f < 2 else Vector3(comp, 1.0, 0.24)
		paredes.caixa(Vector3(pc.x, y + 0.5, pc.y), tam, mureta)
		col.append([Vector3(pc.x, y + 0.5, pc.y), tam + Vector3(0, 0.3, 0), 0.0])
	# caixa d'água e um varal de antenas para dar vida
	var cx := Vector2(-hx * 0.4, -hz * 0.4)
	paredes.cilindro(Vector3(cx.x, y + 1.0, cx.y), 0.9, 2.0, 10, Color(0.45, 0.35, 0.25))
	col.append([Vector3(cx.x, y + 1.0, cx.y), Vector3(1.8, 2.0, 1.8), 0.0])
	# grade em volta do buraco da escada que chega ao telhado (aberta só onde se chega)
	var e := _esc()
	var veio_a := k % 2 == 0
	var faixa: Array = e["a"] if veio_a else e["b"]
	var d0: float = e["d0"]
	var d1: float = e["d1"]
	var pe := d0 if veio_a else d1                     # pé da escada (lá embaixo): fechado
	var chega_ini := d1 - 1.4 if veio_a else d0 + 1.4  # perto de onde se chega: aberto
	for w in [float(faixa[0]), float(faixa[1])]:
		_grade_y(_xz(pe, w), _xz(chega_ini, w), y)
	_grade_y(_xz(pe, float(faixa[0])), _xz(pe, float(faixa[1])), y)

func _grade_y(a: Vector2, b: Vector2, y: float) -> void:
	var antes_v := resto.v.size()
	var antes_c := col.size()
	_grade(a, b)
	for i in range(antes_v, resto.v.size()):
		resto.v[i] += Vector3(0, y, 0)
	for i in range(antes_c, col.size()):
		col[i][0] += Vector3(0, y, 0)
