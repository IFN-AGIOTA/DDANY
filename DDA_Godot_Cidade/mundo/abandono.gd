extends RefCounted
# CIDADE ABANDONADA: carros largados nas ruas (estacionados, parados no meio da pista, batidos, capotados e
# queimados), engavetamentos em cruzamentos, barreiras de concreto, barris, caçambas, sacos de lixo,
# montes de entulho e pedaços de concreto (mais perto dos prédios em ruína).
# Tudo em MultiMesh por blocos de 250 m (o celular só desenha o que está perto, na frente da câmera e não escondido
# atrás dos prédios: "visibility_range_end" + frustum + oclusão).
# Devolve também os OBSTÁCULOS (caixas para a colisão perto do jogador) e os CARROS (porta-malas com loot).
# 0.69: MODELOS BAIXADOS (mundo/cenario.gd): semáforo, hidrante, barris, sacos de lixo, barreiras, placas, lixeiras,
# caixas de energia, bueiros, pneus, caixotes, caixas de papelão, carros cobertos, poste antigo e árvores de calçada.
# De longe continuam as versões simples feitas por código (LOD). Se faltar o arquivo, usa o modelo de código.
# Mexa AQUI para: quantos carros/obstáculos por rua, modelos dos carros, cores.

const Malhas := preload("res://mundo/malhas.gd")
const Cenario := preload("res://mundo/cenario.gd")
# nome da instância -> modelo baixado (mundo/cenario.gd)
const BAIXADOS := {"semaforo": "semaforo_braco", "hidrante": "hidrante", "barril": "barril",
	"saco_lixo": "saco_lixo", "barreira": "barreira", "lixeira": "lixeira", "caixa_energia": "caixa_energia", "bueiro": "bueiro", "pneu": "pneu", "caixote": "caixote",
	"caixa_papelao": "caixa_papelao", "carro_coberto": "carro_coberto", "placa_pare": "placa_pare",
	"placa_proibido": "placa_proibido", "placa_atencao": "placa_atencao", "poste_duplo": "poste_duplo",
	"arvore_rua_1": "arvore_1", "arvore_rua_2": "arvore_4", "arvore_rua_seca_1": "arvore_seca_2"}
# objetos esparsos (poucos por quadra): pedaços de 500 m (menos nós na cena; alcance de pelo menos 420 m)
const ESPARSOS := ["placa_pare", "placa_proibido", "placa_atencao", "lixeira", "caixa_energia", "pneu", "caixote",
	"caixa_papelao", "carro_coberto", "bueiro"]
const BLOCO_ESPARSO := 500.0
# até onde vai o modelo baixado (depois, a versão simples de código; os pesados ficam mais perto)
const PERTO_BAIXADO := {"arvore_rua": 110.0, "poste_duplo": 180.0, "carro_coberto": 250.0}
const BLOCO := 250.0
const Y := 0.6                       # altura do asfalto

const CORES_CARRO := [Color(0.55, 0.08, 0.07), Color(0.12, 0.2, 0.42), Color(0.75, 0.75, 0.72), Color(0.1, 0.1, 0.11),
	Color(0.3, 0.32, 0.3), Color(0.22, 0.34, 0.22), Color(0.6, 0.55, 0.42), Color(0.45, 0.45, 0.5)]
const AMARELO_TAXI := Color(0.95, 0.7, 0.08)
const QUEIMADO := Color(0.13, 0.11, 0.1)

var cid                                  # mundo/cidade.gd
var rng := RandomNumberGenerator.new()
var densidade := 1.0
var obstaculos := PackedFloat32Array()   # x, z, giro, tam_x, tam_y, tam_z, y_centro (7 por obstáculo)
var carros: Array = []                   # [pos Vector3, giro, tipo, cor, estado, obstáculo, bloco, índice no bloco]
										  # (porta-malas; 0.76: veículos dirigíveis, mundo/veiculos.gd)
var _mm_bloco := {}                       # 0.76: tipo -> bloco -> [MultiMesh perto, MultiMesh longe] (sumir um carro)
var _inst := {}                          # nome do modelo -> {Vector2i: [[Transform3D, Color, cor de longe], ...]}
var baixados := true                     # usar os modelos baixados (falso = só os de código, para comparar)
var nos: Array[GeometryInstance3D] = []
# 0.84: fios entre os postes e halos das lâmpadas/semáforos (mundo/luzes_rua.gd) · Opções › Gráficos
const LuzesRua := preload("res://mundo/luzes_rua.gd")
var fios: Array = []                     # [[a, b], ...] topo de dois postes seguidos
var halos: Array = []                    # [[posição, semáforo], ...]
var nos_fios: Array = []
var nos_halos: Array = []

func construir(cidade, ruinas: Array, dens: float) -> void:
	preparar(cidade, ruinas, dens)
	for e in etapas():
		e[2].call()

var _ruinas: Array = []
func preparar(cidade, ruinas: Array, dens: float) -> void:
	cid = cidade
	_ruinas = ruinas
	densidade = dens
	rng.seed = 777

# 0.99: as partes de construir(), uma de cada vez (a tela de carregamento mostra cada uma) · [texto, peso, Callable]
func etapas() -> Array:
	return [
		["Carros abandonados nas ruas", 1.5, _carros_nas_ruas],
		["Engavetamentos e barreiras", 0.5, func(): _engavetamentos(); _barreiras()],
		["Lixo nas calçadas", 1.3, _lixo_nas_calcadas],
		["Postes, semáforos e placas", 3.5, _mobiliario_urbano],
		["Entulho das ruínas", 1.3, func(): _entulho(_ruinas)],
		["Juntando os objetos da rua", 11.5, _montar],
		["Fios e luzes da rua", 16.0, _fios_e_halos],
	]

func _fios_e_halos() -> void:
	nos_fios = await LuzesRua.montar_fios(fios, cid.respirar)
	nos_halos = LuzesRua.montar_halos(halos)
	for n in nos_fios + nos_halos:
		nos.append(n)

# 0.84: Opções › Gráficos "Detalhes dos modelos": até onde carros, postes, árvores e objetos da rua aparecem (e onde
# trocam para a versão simples) · nível 0..3
const FATOR_MODELOS := [0.55, 0.75, 1.0, 1.3]
func aplicar_modelos(nivel: int) -> void:
	var f: float = FATOR_MODELOS[clampi(nivel, 0, 3)]
	# 1.02: fios e halos num dicionário (antes "n in nos_fios" procurava na lista inteira para cada objeto: ~0,55 s)
	var fora := {}
	for n in nos_fios + nos_halos:
		fora[n] = true
	for n in nos:
		if not is_instance_valid(n) or fora.has(n):
			continue
		if not n.has_meta("alc"):
			n.set_meta("alc", Vector2(n.visibility_range_begin, n.visibility_range_end))
		var a: Vector2 = n.get_meta("alc")
		n.visibility_range_begin = a.x * f
		n.visibility_range_end = a.y * f

# 0.84: fios de poste e halos de luz ligados/desligados
func aplicar_luzes(com_fios: bool, com_halos: bool) -> void:
	for n in nos_fios:
		if is_instance_valid(n):
			n.visible = com_fios
	LuzesRua.ligar_halos(com_halos)          # de dia ficam escondidos de qualquer jeito

# ---------- modelos ----------
static func modelo(nome: String) -> ArrayMesh:
	var c := Malhas.Construtor.new()
	var vidro := Color(0.1, 0.11, 0.12)
	var pneu := Color(0.05, 0.05, 0.05)
	var roda := Basis(Vector3.RIGHT, PI * 0.5)
	match nome:
		"sedan", "taxi":
			c.caixa(Vector3(0, 0.62, 0), Vector3(4.4, 0.72, 1.85), Color.WHITE)
			c.caixa(Vector3(-0.25, 1.28, 0), Vector3(2.3, 0.62, 1.66), Color(0.95, 0.95, 0.95))
			c.caixa(Vector3(-0.25, 1.27, 0), Vector3(2.34, 0.4, 1.7), vidro)
			c.caixa(Vector3(2.21, 0.72, 0.6), Vector3(0.04, 0.16, 0.36), Color(1.6, 1.6, 1.4))
			c.caixa(Vector3(2.21, 0.72, -0.6), Vector3(0.04, 0.16, 0.36), Color(1.6, 1.6, 1.4))
			c.caixa(Vector3(-2.21, 0.75, 0.62), Vector3(0.04, 0.14, 0.3), Color(1.8, 0.2, 0.15))
			c.caixa(Vector3(-2.21, 0.75, -0.62), Vector3(0.04, 0.14, 0.3), Color(1.8, 0.2, 0.15))
			if nome == "taxi":
				c.caixa(Vector3(-0.25, 1.68, 0), Vector3(0.6, 0.18, 0.3), Color(1.1, 1.1, 1.0))
			for x in [1.4, -1.35]:
				for z in [0.86, -0.86]:
					c.cilindro(Vector3(x, 0.34, z), 0.34, 0.24, 10, pneu, roda)
		"van":
			c.caixa(Vector3(0, 1.15, 0), Vector3(4.9, 1.75, 1.98), Color.WHITE)
			c.caixa(Vector3(1.75, 1.55, 0), Vector3(1.42, 0.55, 2.02), vidro)
			c.caixa(Vector3(0.0, 1.62, 0), Vector3(1.8, 0.4, 2.02), vidro)
			for x in [1.6, -1.6]:
				for z in [0.9, -0.9]:
					c.cilindro(Vector3(x, 0.36, z), 0.36, 0.26, 10, pneu, roda)
		"onibus":
			c.caixa(Vector3(0, 1.75, 0), Vector3(11.0, 2.7, 2.5), Color.WHITE)
			c.caixa(Vector3(0, 2.15, 0), Vector3(11.04, 0.9, 2.54), vidro)
			c.caixa(Vector3(5.5, 1.5, 0), Vector3(0.06, 1.2, 2.2), vidro)
			for x in [3.8, -3.6]:
				for z in [1.05, -1.05]:
					c.cilindro(Vector3(x, 0.5, z), 0.5, 0.35, 12, pneu, roda)
		"barreira":
			c.caixa(Vector3(0, 0.2, 0), Vector3(3.0, 0.4, 0.62), Color.WHITE)
			c.caixa(Vector3(0, 0.62, 0), Vector3(3.0, 0.45, 0.3), Color.WHITE)
		"barril":
			c.cilindro(Vector3(0, 0.45, 0), 0.3, 0.9, 10, Color.WHITE)
			c.cilindro(Vector3(0, 0.3, 0), 0.315, 0.05, 10, Color(0.7, 0.7, 0.7))
			c.cilindro(Vector3(0, 0.62, 0), 0.315, 0.05, 10, Color(0.7, 0.7, 0.7))
		"cacamba":
			c.caixa(Vector3(0, 0.65, 0), Vector3(2.0, 1.1, 1.3), Color.WHITE)
			c.caixa(Vector3(0, 1.25, -0.1), Vector3(2.05, 0.06, 1.2), Color(0.8, 0.8, 0.8), Basis(Vector3.RIGHT, -0.25))
			c.caixa(Vector3(0, 0.08, 0), Vector3(1.8, 0.16, 1.1), Color(0.3, 0.3, 0.3))
		"lixo":
			for q in [[Vector3(0, 0.22, 0), Vector3(0.6, 0.45, 0.5), 0.3], [Vector3(0.45, 0.18, 0.25), Vector3(0.5, 0.36, 0.45), -0.5],
					[Vector3(-0.3, 0.16, 0.35), Vector3(0.45, 0.32, 0.4), 1.1], [Vector3(0.1, 0.5, 0.05), Vector3(0.4, 0.3, 0.35), 0.8]]:
				c.caixa(q[0], q[1], Color.WHITE, Basis(Vector3.UP, q[2]) * Basis(Vector3.RIGHT, q[2] * 0.3))
		"entulho":
			var r := RandomNumberGenerator.new()
			r.seed = 31
			for i in 14:
				var a := r.randf() * TAU
				var d := r.randf() * 1.6
				var s := Vector3(r.randf_range(0.4, 1.4), r.randf_range(0.2, 0.7), r.randf_range(0.3, 1.1))
				var b := Basis.from_euler(Vector3(r.randf_range(-0.6, 0.6), r.randf() * TAU, r.randf_range(-0.6, 0.6)))
				var g := r.randf_range(0.75, 1.1)
				c.caixa(Vector3(cos(a) * d, s.y * 0.4 + (1.6 - d) * 0.35, sin(a) * d), s, Color(g, g * 0.97, g * 0.93), b)
			c.caixa(Vector3(0.3, 0.9, 0.1), Vector3(2.4, 0.08, 0.12), Color(0.45, 0.3, 0.2), Basis(Vector3.FORWARD, 0.5))   # viga
		"cacos":
			var r := RandomNumberGenerator.new()
			r.seed = 77
			for i in 7:
				var s := Vector3(r.randf_range(0.15, 0.5), r.randf_range(0.06, 0.18), r.randf_range(0.12, 0.4))
				c.caixa(Vector3(r.randf_range(-1.2, 1.2), s.y * 0.5, r.randf_range(-1.2, 1.2)), s, Color.WHITE, Basis(Vector3.UP, r.randf() * TAU))
			c.caixa(Vector3(0.2, 0.04, -0.3), Vector3(1.6, 0.06, 0.18), Color(0.5, 0.35, 0.22), Basis(Vector3.UP, 0.7))    # tábua
		"poste":
			var ferro := Color(0.2, 0.21, 0.22)
			c.cilindro(Vector3(0, 4.0, 0), 0.13, 8.0, 8, ferro, Basis.IDENTITY, 0.09)
			c.caixa(Vector3(0.9, 7.9, 0), Vector3(1.9, 0.12, 0.12), ferro)
			c.caixa(Vector3(1.75, 7.78, 0), Vector3(0.6, 0.18, 0.3), Color(0.25, 0.25, 0.25))
			c.caixa(Vector3(1.75, 7.67, 0), Vector3(0.5, 0.04, 0.24), Color(0.8, 0.78, 0.65))
			c.cilindro(Vector3(0, 0.2, 0), 0.22, 0.4, 8, ferro)
		"semaforo":
			var ferro := Color(0.18, 0.19, 0.2)
			c.cilindro(Vector3(0, 3.0, 0), 0.12, 6.0, 8, ferro)
			c.caixa(Vector3(2.6, 5.8, 0), Vector3(5.2, 0.14, 0.14), ferro)
			for x in [2.2, 4.6]:
				c.caixa(Vector3(x, 5.25, 0), Vector3(0.38, 1.0, 0.32), Color(0.12, 0.12, 0.08))
				c.caixa(Vector3(x, 5.55, 0.17), Vector3(0.18, 0.18, 0.04), Color(0.5, 0.08, 0.06))
				c.caixa(Vector3(x, 5.25, 0.17), Vector3(0.18, 0.18, 0.04), Color(0.45, 0.35, 0.05))
				c.caixa(Vector3(x, 4.95, 0.17), Vector3(0.18, 0.18, 0.04), Color(0.06, 0.3, 0.12))
			c.caixa(Vector3(0, 1.3, 0.15), Vector3(0.3, 0.4, 0.15), Color(0.15, 0.15, 0.15))
		"hidrante":
			var verm := Color(0.6, 0.1, 0.07)
			c.cilindro(Vector3(0, 0.35, 0), 0.14, 0.7, 8, verm)
			c.cilindro(Vector3(0, 0.75, 0), 0.1, 0.12, 8, verm, Basis.IDENTITY, 0.04)
			c.cilindro(Vector3(0, 0.45, 0), 0.06, 0.45, 6, verm, Basis(Vector3.FORWARD, PI * 0.5))
		"banco":
			var mad := Color(0.42, 0.28, 0.16)
			var fer := Color(0.15, 0.15, 0.16)
			for i in 3:
				c.caixa(Vector3(0, 0.45, -0.18 + i * 0.16), Vector3(1.8, 0.05, 0.12), mad)
			for i in 2:
				c.caixa(Vector3(0, 0.62 + i * 0.16, 0.24), Vector3(1.8, 0.1, 0.04), mad, Basis(Vector3.RIGHT, -0.2))
			for x in [-0.75, 0.75]:
				c.caixa(Vector3(x, 0.22, 0), Vector3(0.08, 0.44, 0.5), fer)
		"arvore_rua":
			c.cilindro(Vector3(0, 1.6, 0), 0.16, 3.2, 6, Color(0.32, 0.24, 0.17), Basis.IDENTITY, 0.11)
			c.cilindro(Vector3(0, 0.04, 0), 0.65, 0.08, 8, Color(0.25, 0.2, 0.15))          # canteiro
			for q in [[Vector3(0, 3.9, 0), 1.7, 2.2], [Vector3(0.4, 4.7, 0.2), 1.3, 1.6], [Vector3(-0.3, 5.3, -0.2), 0.9, 1.2]]:
				c.cilindro(q[0], q[1], q[2], 7, Color.WHITE, Basis(Vector3.UP, q[1]), q[1] * 0.55)

	return c.malha()

# LOD: versão de LONGE (sem rodas, luzes, grades nem detalhes; ~5 a 10x menos triângulos). Só os modelos que
# aparecem longe; os pequenos (lixo, cacos, hidrante...) já somem antes de PERTO_LOD.
const PERTO_LOD := 300.0                 # até aqui o modelo completo (medido até o centro do pedaço de 250 m)
const TEM_LOD := ["sedan", "taxi", "van", "onibus", "entulho", "poste", "semaforo", "arvore_rua", "poste_duplo", "carro_coberto"]

static func modelo_longe(nome: String) -> ArrayMesh:
	var c := Malhas.Construtor.new()
	var vidro := Color(0.1, 0.11, 0.12)
	match nome:
		"sedan", "taxi":
			c.caixa(Vector3(0, 0.55, 0), Vector3(4.4, 0.86, 1.85), Color.WHITE)
			c.caixa(Vector3(-0.25, 1.27, 0), Vector3(2.3, 0.6, 1.68), vidro)
		"van":
			c.caixa(Vector3(0, 1.0, 0), Vector3(4.9, 2.05, 1.98), Color.WHITE)
		"onibus":
			c.caixa(Vector3(0, 1.6, 0), Vector3(11.0, 3.0, 2.5), Color.WHITE)
			c.caixa(Vector3(0, 2.15, 0), Vector3(11.04, 0.9, 2.54), vidro)
		"entulho":
			c.caixa(Vector3(0, 0.35, 0), Vector3(3.0, 0.7, 2.6), Color.WHITE, Basis(Vector3.UP, 0.4))
			c.caixa(Vector3(0.2, 0.75, 0.1), Vector3(1.6, 0.5, 1.4), Color(0.9, 0.88, 0.85), Basis(Vector3.UP, -0.3))
		"poste":
			var ferro := Color(0.2, 0.21, 0.22)
			c.caixa(Vector3(0, 4.0, 0), Vector3(0.22, 8.0, 0.22), ferro)
			c.caixa(Vector3(1.0, 7.85, 0), Vector3(2.1, 0.2, 0.25), ferro)
		"semaforo":
			var ferro := Color(0.18, 0.19, 0.2)
			c.caixa(Vector3(0, 3.0, 0), Vector3(0.22, 6.0, 0.22), ferro)
			c.caixa(Vector3(2.6, 5.6, 0), Vector3(5.2, 0.5, 0.25), Color(0.14, 0.14, 0.12))
		"arvore_rua":
			c.caixa(Vector3(0, 1.6, 0), Vector3(0.3, 3.2, 0.3), Color(0.32, 0.24, 0.17))
			c.cilindro(Vector3(0, 4.4, 0), 1.6, 3.0, 5, Color.WHITE, Basis.IDENTITY, 0.9)
		"poste_duplo":
			c.caixa(Vector3(0, 3.6, 0), Vector3(0.2, 7.2, 0.2), Color(0.08, 0.08, 0.08))
			c.caixa(Vector3(0, 6.8, 0), Vector3(0.25, 0.25, 1.9), Color(0.08, 0.08, 0.08))
		"carro_coberto":
			c.caixa(Vector3(0, 0.62, 0), Vector3(1.75, 0.9, 4.3), Color(0.16, 0.17, 0.18))
			c.caixa(Vector3(0, 1.15, 0.1), Vector3(1.5, 0.45, 2.2), Color(0.16, 0.17, 0.18))
	return c.malha()

# ---------- colocação ----------
# cor_longe: cor da versão simples de longe (árvore: a de perto já tem textura colorida, a de longe é verde)
func _por(nome: String, t: Transform3D, cor: Color, cor_longe := Color(0, 0, 0, 0)) -> void:
	if not _inst.has(nome):
		_inst[nome] = {}
	var bl := BLOCO_ESPARSO if nome in ESPARSOS else BLOCO
	var k := Vector2i(floori(t.origin.x / bl), floori(t.origin.z / bl))
	if not _inst[nome].has(k):
		_inst[nome][k] = []
	_inst[nome][k].append([t, cor, cor if cor_longe.a <= 0.0 else cor_longe])

# instância -> nome do modelo de código (o de longe e o que vale se faltar o arquivo baixado)
static func _base(nome: String) -> String:
	if nome.begins_with("arvore_rua"):
		return "arvore_rua"
	return {"barril_2": "barril", "saco_lixo": "lixo"}.get(nome, nome)

func _tem_baixado(nome: String) -> bool:
	return baixados and BAIXADOS.has(nome) and Cenario.tem(BAIXADOS[nome])

func _obstaculo(p: Vector3, giro: float, tam: Vector3) -> void:
	obstaculos.append_array(PackedFloat32Array([p.x, p.z, giro, tam.x, tam.y, tam.z, p.y + tam.y * 0.5]))

static func _giro(dir: Vector2) -> float:
	return atan2(-dir.y, dir.x)

func _carro(pos: Vector2, giro: float, estado: String) -> void:
	var r := rng.randf()
	var nome := "sedan"
	if r < 0.1:
		nome = "taxi"
	elif r < 0.3:
		nome = "van"
	elif r < 0.33:
		nome = "onibus"
	var cor: Color = AMARELO_TAXI if nome == "taxi" else CORES_CARRO[rng.randi() % CORES_CARRO.size()]
	if nome == "onibus":
		cor = [Color(0.85, 0.6, 0.1), Color(0.75, 0.75, 0.75), Color(0.2, 0.35, 0.6)][rng.randi() % 3]
	cor = cor * rng.randf_range(0.7, 1.0)
	var queimado := false
	if rng.randf() < 0.2:
		cor = QUEIMADO * rng.randf_range(0.8, 1.3)
		queimado = true
	cor.a = 1.0
	var b := Basis(Vector3.UP, giro)
	var y := Y
	var alto: float = {"sedan": 1.6, "taxi": 1.6, "van": 2.0, "onibus": 3.1}[nome]
	var tam: Vector3 = {"sedan": Vector3(4.4, 1.6, 1.9), "taxi": Vector3(4.4, 1.6, 1.9), "van": Vector3(4.9, 2.0, 2.0), "onibus": Vector3(11, 3.1, 2.5)}[nome]
	if estado == "capotado" and nome != "onibus":
		b = b * Basis(Vector3.RIGHT, PI)
		y = Y + alto
	elif estado == "tombado" and nome != "onibus":
		b = b * Basis(Vector3.RIGHT, PI * 0.5)
		y = Y + tam.z * 0.5
		tam = Vector3(tam.x, tam.z, tam.y)
	var bk := Vector2i(floori(pos.x / BLOCO), floori(pos.y / BLOCO))
	var n_bloco: int = _inst[nome][bk].size() if _inst.has(nome) and _inst[nome].has(bk) else 0
	var n_obst := obstaculos.size() / 7
	_por(nome, Transform3D(b, Vector3(pos.x, y, pos.y)), cor)
	_obstaculo(Vector3(pos.x, Y, pos.y), giro, tam)
	carros.append([Vector3(pos.x, Y, pos.y), giro, nome, cor, "queimado" if queimado and estado == "" else estado, n_obst, bk, n_bloco])

# 0.76: some com o desenho do carro largado i (virou veículo: mundo/veiculos.gd)
func esconder_carro(i: int) -> void:
	var c: Array = carros[i]
	var por_bloco: Dictionary = _mm_bloco.get(c[2], {})
	for mm in por_bloco.get(c[6], []):
		if mm != null and int(c[7]) < (mm as MultiMesh).instance_count:
			(mm as MultiMesh).set_instance_transform(int(c[7]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(c[0].x, -500.0, c[0].z)))

func _carros_nas_ruas() -> void:
	for rd in cid.dados_cidade["roads"]:
		var hw: float = float(rd[0]) * 0.5
		var pts: PackedVector2Array = cid._pts(rd[1])
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var l := a.distance_to(b)
			if l < 20.0:
				continue
			var dir := (b - a) / l
			var nrm := Vector2(-dir.y, dir.x)
			var ra: float = cid._cruzamento(a)
			var rb: float = cid._cruzamento(b)
			# engarrafamento abandonado: fila de carros colados numa pista
			if rng.randf() < 0.32 * densidade and l > 60.0:
				var lado := 1.0 if rng.randf() < 0.5 else -1.0
				var faixa := lado * hw * rng.randf_range(0.2, 0.75)
				var giro := _giro(dir * lado)
				var tf := rng.randf_range(10.0, l * 0.5)
				for j in rng.randi_range(3, 10):
					if tf > l - 10.0:
						break
					if not ((ra >= 0.0 and tf < ra + 9.0) or (rb >= 0.0 and tf > l - rb - 9.0)):
						_carro(a + dir * tf + nrm * (faixa + rng.randf_range(-0.6, 0.6)), giro + rng.randf_range(-0.25, 0.25), "")
					tf += rng.randf_range(5.6, 8.5)
			var t := rng.randf_range(6.0, 30.0)
			while t < l - 8.0:
				var perto_a := ra >= 0.0 and t < ra + 9.0
				var perto_b := rb >= 0.0 and t > l - rb - 9.0
				if not (perto_a or perto_b):
					var lado := 1.0 if rng.randf() < 0.5 else -1.0
					var giro := _giro(dir * lado)
					var e := rng.randf()
					if e < 0.55:      # estacionado na beira
						_carro(a + dir * t + nrm * lado * (hw - 1.7), giro + rng.randf_range(-0.06, 0.06), "")
					elif e < 0.86:    # largado no meio da pista
						_carro(a + dir * t + nrm * lado * hw * rng.randf_range(0.15, 0.7), giro + rng.randf_range(-0.4, 0.4), "")
					elif e < 0.95:    # batido, atravessado
						_carro(a + dir * t + nrm * lado * hw * rng.randf_range(0.0, 0.6), rng.randf() * TAU, "")
					else:
						_carro(a + dir * t + nrm * lado * hw * rng.randf_range(0.1, 0.6), rng.randf() * TAU, "capotado" if rng.randf() < 0.5 else "tombado")
				t += rng.randf_range(14.0, 48.0) / densidade

func _engavetamentos() -> void:
	for k in cid._nos:
		var e = cid._nos[k]
		if e["n"] < 4 or rng.randf() > 0.12 * densidade:
			continue
		var c := Vector2(k)
		for i in rng.randi_range(2, 4):
			_carro(c + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7)), rng.randf() * TAU, "capotado" if rng.randf() < 0.15 else "")

func _barreiras() -> void:
	# fileiras de barreiras de concreto fechando parte de algumas ruas (bloqueios do exército)
	for rd in cid.dados_cidade["roads"]:
		var hw: float = float(rd[0]) * 0.5
		var pts: PackedVector2Array = cid._pts(rd[1])
		if rng.randf() > 0.045 * densidade or pts.size() < 2:
			continue
		var a := pts[0]
		var b := pts[1]
		if a.distance_to(b) < 30.0:
			continue
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var c := a + dir * rng.randf_range(14.0, minf(40.0, a.distance_to(b) - 10.0))
		var giro := _giro(nrm)
		var k := -hw + 1.6
		while k < hw - 1.5:
			if rng.randf() > 0.18:          # algumas faltando (passagem)
				var p := c + nrm * k + dir * rng.randf_range(-0.3, 0.3)
				var bb := Basis(Vector3.UP, giro + rng.randf_range(-0.12, 0.12))
				if _tem_baixado("barreira"):
					# modelo baixado tem 1,57 m: duas lado a lado no lugar de uma de 3 m (já vem com a cor do concreto)
					for lado in [-0.79, 0.79]:
						var q: Vector3 = Vector3(p.x, Y - 0.02, p.y) + bb * Vector3(lado, 0, 0)
						_por("barreira", Transform3D(bb * Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), q), Color.WHITE * rng.randf_range(0.8, 1.0))
					_obstaculo(Vector3(p.x, Y, p.y), giro, Vector3(3.1, 1.1, 0.45))
				else:
					_por("barreira", Transform3D(bb, Vector3(p.x, Y, p.y)), Color(0.62, 0.6, 0.56) * rng.randf_range(0.85, 1.05))
					_obstaculo(Vector3(p.x, Y, p.y), giro, Vector3(3.0, 0.85, 0.62))
			k += 3.1

func _lixo_nas_calcadas() -> void:
	var cores_barril := [Color(0.5, 0.2, 0.08), Color(0.15, 0.25, 0.45), Color(0.2, 0.35, 0.2), Color(0.55, 0.12, 0.08)]
	for rd in cid.dados_cidade["roads"]:
		var hw: float = float(rd[0]) * 0.5
		var pts: PackedVector2Array = cid._pts(rd[1])
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var l := a.distance_to(b)
			if l < 25.0:
				continue
			var dir := (b - a) / l
			var nrm := Vector2(-dir.y, dir.x)
			var t := rng.randf_range(5.0, 40.0)
			while t < l - 5.0:
				var lado := 1.0 if rng.randf() < 0.5 else -1.0
				var p := a + dir * t + nrm * lado * (hw + rng.randf_range(1.0, 4.0))     # na calçada
				var g := Basis(Vector3.UP, rng.randf() * TAU)
				var r := rng.randf()
				if r < 0.4:
					if _tem_baixado("saco_lixo"):
						# monte de 2 a 5 sacos de lixo
						for j in rng.randi_range(2, 5):
							var q := p + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
							var sb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
							_por("saco_lixo", Transform3D(sb.scaled(Vector3.ONE * rng.randf_range(0.8, 1.25)), Vector3(q.x, Y - 0.06, q.y)), Color.WHITE if rng.randf() < 0.8 else Color(0.45, 0.6, 1.0))
					else:
						_por("lixo", Transform3D(g.scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(p.x, Y - 0.05, p.y)), Color(0.07, 0.07, 0.08) if rng.randf() < 0.8 else Color(0.2, 0.25, 0.4))
				elif r < 0.65:
					var n := rng.randi_range(1, 3)
					for j in n:
						var q := p + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
						var deitado := rng.randf() < 0.25
						var bb := g * Basis(Vector3.FORWARD, PI * 0.5) if deitado else g
						if _tem_baixado("barril"):
							_por("barril", Transform3D(bb, Vector3(q.x, Y - 0.05 + (0.28 if deitado else 0.0), q.y)), Color.WHITE * rng.randf_range(0.7, 1.0))
						else:
							_por("barril", Transform3D(bb, Vector3(q.x, Y - 0.05 + (0.3 if deitado else 0.0), q.y)), cores_barril[rng.randi() % cores_barril.size()] * rng.randf_range(0.7, 1.0))
						_obstaculo(Vector3(q.x, Y, q.y), 0.0, Vector3(0.6, 0.9, 0.6))
				elif r < 0.8:
					var giro := _giro(dir)
					_por("cacamba", Transform3D(Basis(Vector3.UP, giro + rng.randf_range(-0.3, 0.3)), Vector3(p.x, Y - 0.05, p.y)), [Color(0.15, 0.3, 0.18), Color(0.15, 0.2, 0.35), Color(0.4, 0.3, 0.1)][rng.randi() % 3])
					_obstaculo(Vector3(p.x, Y, p.y), giro, Vector3(2.0, 1.3, 1.3))
				elif r < 0.86 or not baixados:
					_por("cacos", Transform3D(g, Vector3(p.x, Y - 0.05, p.y)), Color(0.55, 0.53, 0.5) * rng.randf_range(0.8, 1.1))
				elif r < 0.9:
					# pneus velhos: deitados empilhados ou um em pé encostado
					if rng.randf() < 0.6:
						for j in rng.randi_range(1, 4):
							_por("pneu", Transform3D(g * Basis(Vector3.RIGHT, PI * 0.5), Vector3(p.x, Y - 0.04 + 0.085 + j * 0.16 - 0.16, p.y)), Color.WHITE)
					else:
						_por("pneu", Transform3D(g * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)), Vector3(p.x, Y - 0.05, p.y)), Color.WHITE)
				elif r < 0.94:
					_por("caixote", Transform3D(g, Vector3(p.x, Y - 0.05, p.y)), Color.WHITE * rng.randf_range(0.75, 1.0))
					if rng.randf() < 0.4:
						_por("caixote", Transform3D(g * Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), Vector3(p.x, Y - 0.05 + 0.46, p.y)), Color.WHITE * rng.randf_range(0.75, 1.0))
					_obstaculo(Vector3(p.x, Y, p.y), atan2(-g.x.z, g.x.x), Vector3(0.6, 0.9, 1.2))
				elif r < 0.97:
					for j in rng.randi_range(2, 5):
						var q := p + Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.9))
						var cb := Basis(Vector3.UP, rng.randf() * TAU)
						if rng.randf() < 0.3:
							cb = cb * Basis(Vector3.RIGHT, PI * 0.5)
						_por("caixa_papelao", Transform3D(cb, Vector3(q.x, Y - 0.05, q.y)), Color.WHITE * rng.randf_range(0.7, 1.0))
				else:
					# carro coberto com lona, estacionado colado no meio-fio (do lado da rua)
					var pc: Vector2 = a + dir * t + nrm * lado * (hw - 1.6)
					var gc := _giro(dir * lado) + PI * 0.5
					_por("carro_coberto", Transform3D(Basis(Vector3.UP, gc + rng.randf_range(-0.05, 0.05)), Vector3(pc.x, Y - 0.02, pc.y)), Color.WHITE * rng.randf_range(0.7, 1.0))
					_obstaculo(Vector3(pc.x, Y, pc.y), gc - PI * 0.5, Vector3(4.4, 1.4, 1.8))
				t += rng.randf_range(25.0, 70.0) / densidade

# postes (alguns caídos), semáforos nos cruzamentos (alguns tortos), hidrantes, bancos e árvores de calçada
func _mobiliario_urbano() -> void:
	var n_rua := 0
	for rd in cid.dados_cidade["roads"]:
		n_rua += 1
		await cid.respirar(n_rua, cid.dados_cidade["roads"].size() + 1)
		var hw: float = float(rd[0]) * 0.5
		var pts: PackedVector2Array = cid._pts(rd[1])
		var com_arvores := rng.randf() < 0.45
		var poste_antigo := baixados and com_arvores and rng.randf() < 0.45     # ruas arborizadas: poste de ferro antigo
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var l := a.distance_to(b)
			if l < 30.0:
				continue
			var dir := (b - a) / l
			var nrm := Vector2(-dir.y, dir.x)
			var ra: float = cid._cruzamento(a)
			var rb: float = cid._cruzamento(b)
			for lado in [-1.0, 1.0]:
				var t := (ra + 6.0 if ra >= 0.0 else 6.0) + rng.randf_range(0.0, 8.0)
				var fim := l - (rb + 6.0 if rb >= 0.0 else 6.0)
				var k := 0
				var anterior := Vector3.INF          # 0.84: topo do poste anterior deste lado (fios)
				while t < fim:
					var p: Vector2 = a + dir * t + nrm * lado * (hw + 1.0)
					var giro := _giro(-nrm * lado)          # braço do poste por cima da rua
					if k % 2 == 0:
						if rng.randf() < 0.08:
							# poste caído atravessado na rua
							var bb := Basis(Vector3.UP, giro) * Basis(Vector3.FORWARD, -PI * 0.47)
							_por("poste", Transform3D(bb, Vector3(p.x, Y + 0.1, p.y)), Color.WHITE)
							anterior = Vector3.INF
						elif poste_antigo:
							var tp := Transform3D(Basis(Vector3.UP, giro + PI * 0.5) * Basis(Vector3.FORWARD, rng.randf_range(-0.03, 0.03)), Vector3(p.x, Y - 0.05, p.y))
							_por("poste_duplo", tp, Color.WHITE * rng.randf_range(0.8, 1.0))
							_obstaculo(Vector3(p.x, Y, p.y), giro, Vector3(0.45, 7.5, 0.45))
							anterior = _poste_luzes(p, tp, anterior, [Vector3(0, 6.6, 0.95), Vector3(0, 6.6, -0.95)], 6.9)
						else:
							var tp := Transform3D(Basis(Vector3.UP, giro) * Basis(Vector3.FORWARD, rng.randf_range(-0.04, 0.04)), Vector3(p.x, Y - 0.05, p.y))
							_por("poste", tp, Color.WHITE)
							_obstaculo(Vector3(p.x, Y, p.y), giro, Vector3(0.35, 8.0, 0.35))
							anterior = _poste_luzes(p, tp, anterior, [Vector3(1.75, 7.55, 0)], 7.3)
					elif com_arvores:
						var q: Vector2 = a + dir * t + nrm * lado * (hw + 3.2)
						var verde := Color(0.24, 0.36, 0.15) * rng.randf_range(0.7, 1.2)
						if rng.randf() < 0.3:
							verde = Color(0.35, 0.27, 0.16) * rng.randf_range(0.8, 1.2)    # árvore seca
						verde.a = 1.0
						var s := rng.randf_range(0.85, 1.25)
						if baixados:
							# modelo baixado: árvore viva (5 tipos) ou seca (3 tipos), um pouco menor que as dos parques
							var seca := verde.r > verde.g
							var nome_a := "arvore_rua_seca_1" if seca else ("arvore_rua_%d" % (rng.randi() % 2 + 1))
							var tom := Color(1, 1, 1) * rng.randf_range(0.75, 1.0)
							if not seca and rng.randf() < 0.15:
								tom = Color(1.0, 0.72, 0.42)                  # amarelando (outono)
							tom.a = 1.0
							var se := s * 0.72
							_por(nome_a, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(se, se, se)), Vector3(q.x, Y - 0.05, q.y)), tom, verde)
						else:
							_por("arvore_rua", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(q.x, Y - 0.05, q.y)), verde)
						_obstaculo(Vector3(q.x, Y, q.y), 0.0, Vector3(0.45, 3.0, 0.45))
					var r := rng.randf()
					var q2: Vector2 = a + dir * (t + 7.0) + nrm * lado * (hw + 1.4)
					if r < 0.12:
						_por("hidrante", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q2.x, Y - 0.05, q2.y)), Color.WHITE)
						_obstaculo(Vector3(q2.x, Y, q2.y), 0.0, Vector3(0.35, 0.8, 0.35))
					elif r < 0.2:
						var q3: Vector2 = a + dir * (t + 7.0) + nrm * lado * (hw + 3.8)
						_por("banco", Transform3D(Basis(Vector3.UP, _giro(dir) + (PI if lado > 0.0 else 0.0)), Vector3(q3.x, Y - 0.05, q3.y)), Color.WHITE)
					elif r < 0.28 and baixados:
						# placa na beira da calçada, virada para quem vem pela rua
						var qp: Vector2 = a + dir * (t + 4.0) + nrm * lado * (hw + 0.7)
						var tipo_p := "placa_proibido" if rng.randf() < 0.6 else "placa_atencao"
						var gp := _giro(dir * lado) + rng.randf_range(-0.08, 0.08)      # a face da placa é o eixo X do modelo
						var torta := Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12)) if rng.randf() < 0.3 else Basis.IDENTITY
						_por(tipo_p, Transform3D(Basis(Vector3.UP, gp) * torta, Vector3(qp.x, Y - 0.05, qp.y)), Color.WHITE * rng.randf_range(0.75, 1.0))
						_obstaculo(Vector3(qp.x, Y, qp.y), 0.0, Vector3(0.2, 2.7, 0.2))
					elif r < 0.36 and baixados:
						var ql: Vector2 = a + dir * (t + 9.0) + nrm * lado * (hw + 1.3)
						if rng.randf() < 0.25:
							_por("lixeira", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(ql.x, Y + 0.25, ql.y)), Color.WHITE)   # caída
						else:
							_por("lixeira", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(ql.x, Y - 0.05, ql.y)), Color.WHITE)
							_obstaculo(Vector3(ql.x, Y, ql.y), 0.0, Vector3(0.6, 0.9, 0.6))
					elif r < 0.43 and baixados:
						# caixa de energia encostada do lado dos prédios
						var qe: Vector2 = a + dir * (t + 11.0) + nrm * lado * (hw + 4.6)
						var ge := _giro(dir) + (0.0 if lado > 0.0 else PI)
						_por("caixa_energia", Transform3D(Basis(Vector3.UP, ge), Vector3(qe.x, Y - 0.05, qe.y)), Color.WHITE * rng.randf_range(0.75, 1.0))
						_obstaculo(Vector3(qe.x, Y, qe.y), ge, Vector3(0.95, 1.15, 0.45))
					# bueiro no asfalto, perto da sarjeta
					if baixados and k % 3 == 1:
						var qb: Vector2 = a + dir * (t + 3.0) + nrm * lado * (hw - 1.2)
						_por("bueiro", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(qb.x, Y - 0.045, qb.y)), Color.WHITE)
					t += rng.randf_range(16.0, 22.0)
					k += 1
	# placas de PARE nos cruzamentos em T (0.69, modelos baixados)
	if baixados:
		for kk in cid._nos:
			var e = cid._nos[kk]
			if e["n"] != 3:
				continue
			var r: float = e["r"] + 2.0
			for canto in 2:
				if rng.randf() < 0.35:
					continue
				var ang := PI * 0.25 + (canto * 2 + rng.randi() % 2) * PI * 0.5
				var p := Vector2(kk) + Vector2(cos(ang), sin(ang)) * r * 1.414
				_por("placa_pare", Transform3D(Basis(Vector3.UP, _giro(Vector2(cos(ang), sin(ang))) + rng.randf_range(-0.2, 0.2)), Vector3(p.x, Y - 0.05, p.y)), Color.WHITE * rng.randf_range(0.8, 1.0))
				_obstaculo(Vector3(p.x, Y, p.y), 0.0, Vector3(0.2, 2.7, 0.2))
	# semáforos: um em cada canto dos cruzamentos grandes
	for kk in cid._nos:
		var e = cid._nos[kk]
		if e["n"] < 4:
			continue
		var r: float = e["r"] + 2.0
		for canto in 4:
			var ang := PI * 0.25 + canto * PI * 0.5
			var p := Vector2(kk) + Vector2(cos(ang), sin(ang)) * r * 1.414
			var giro := ang + PI * 0.75
			var torto := Basis.IDENTITY
			if rng.randf() < 0.2:
				torto = Basis(Vector3.FORWARD, rng.randf_range(-0.35, 0.35))
			var ts := Transform3D(Basis(Vector3.UP, giro) * torto, Vector3(p.x, Y - 0.05, p.y))
			_por("semaforo", ts, Color.WHITE)
			_obstaculo(Vector3(p.x, Y, p.y), 0.0, Vector3(0.3, 6.0, 0.3))
			for lx in [2.2, 4.6]:                        # 0.84: halo amarelo piscando nas duas caixas de luz
				halos.append([ts * Vector3(lx, 5.3, 0.3), true])

# 0.84: fio do poste anterior até este (se perto) e halo nas lâmpadas dos postes que ainda acendem (sempre os
# mesmos: sorteio pela posição, sem mexer no sorteio do resto da cidade). Devolve o topo deste poste.
func _poste_luzes(p: Vector2, tp: Transform3D, anterior: Vector3, lampadas: Array, topo: float) -> Vector3:
	var ponta := Vector3(p.x, Y + topo, p.y)
	if anterior != Vector3.INF and anterior.distance_to(ponta) < 60.0:
		fios.append([anterior, ponta])
	if absi(hash(Vector2i(roundi(p.x * 4.0), roundi(p.y * 4.0)))) % 1000 < int(LuzesRua.CHANCE_ACESO * 1000.0):
		for lp in lampadas:
			halos.append([tp * (lp as Vector3), false])
	return ponta

func _entulho(ruinas: Array) -> void:
	for r in ruinas:
		var c := Vector2(r[0], r[1])
		var sx: float = r[2]
		var sz: float = r[3]
		# entulho em cima da metade desabada e pedaços grandes caídos na calçada/rua
		if r.size() >= 8:
			for i in rng.randi_range(2, 4):
				var q := Vector2(r[5], r[6]) + Vector2(rng.randf_range(-0.3, 0.3) * sx * 0.5, rng.randf_range(-0.3, 0.3) * sz * 0.5)
				var s := rng.randf_range(2.0, 3.5)
				_por("entulho", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(q.x, Y + float(r[7]) - 0.4, q.y)), Color(0.4, 0.38, 0.36) * rng.randf_range(0.8, 1.1))
		for i in rng.randi_range(7, 13):
			var lado := rng.randi() % 4
			var p := c
			if lado < 2:
				p += Vector2((sx * 0.5 + rng.randf_range(0.5, 4.0)) * (1 if lado == 0 else -1), rng.randf_range(-sz, sz) * 0.5)
			else:
				p += Vector2(rng.randf_range(-sx, sx) * 0.5, (sz * 0.5 + rng.randf_range(0.5, 4.0)) * (1 if lado == 2 else -1))
			var s := rng.randf_range(1.2, 3.4)
			_por("entulho", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.6, 1.2), s)), Vector3(p.x, Y - 0.1, p.y)), Color(0.42, 0.4, 0.37) * rng.randf_range(0.75, 1.1))
			if s > 1.3:
				_obstaculo(Vector3(p.x, Y, p.y), 0.0, Vector3(2.4 * s, 0.9 * s, 2.4 * s))
		for i in rng.randi_range(8, 16):
			var p := c + Vector2(rng.randf_range(-1, 1) * (sx * 0.5 + 16.0), rng.randf_range(-1, 1) * (sz * 0.5 + 16.0))
			_por("cacos", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, Y - 0.05, p.y)), Color(0.55, 0.53, 0.5) * rng.randf_range(0.8, 1.1))

func _montar() -> void:
	var mat_metal := _material(0.6)
	var mat_concreto := _material(0.0)
	var alcance := {"sedan": 900.0, "taxi": 900.0, "van": 900.0, "onibus": 1200.0, "barreira": 600.0, "barril": 350.0,
		"cacamba": 450.0, "lixo": 300.0, "entulho": 700.0, "cacos": 250.0, "poste": 600.0, "semaforo": 600.0,
		"hidrante": 200.0, "banco": 250.0, "arvore_rua": 700.0, "lixeira": 220.0, "caixa_energia": 250.0, "caixa_energia_2": 250.0,
		"bueiro": 120.0, "pneu": 160.0, "caixote": 200.0, "caixa_papelao": 140.0, "carro_coberto": 900.0, "placa_pare": 260.0,
		"placa_proibido": 220.0, "placa_atencao": 220.0, "poste_duplo": 600.0}
	var n_nome := 0
	for nome in _inst:
		n_nome += 1
		await cid.respirar(n_nome, _inst.size())        # 0.99.1: a tela de carregamento não congela
		var base := _base(nome)
		var concreto: bool = base in ["barreira", "entulho", "cacos", "lixo", "arvore_rua", "banco"]
		var malha: Mesh
		var perto := PERTO_LOD
		if _tem_baixado(nome):
			malha = Cenario.malha(BAIXADOS[nome])
			perto = PERTO_BAIXADO.get(base, PERTO_LOD)
		elif BAIXADOS.has(nome) and base == nome and not (nome in ["semaforo", "hidrante", "barril", "barreira"]):
			continue                              # placa, lixeira... sem arquivo baixado e sem versão de código: não põe
		else:
			malha = modelo(base)
			malha.surface_set_material(0, mat_concreto if concreto else mat_metal)
		var longe: ArrayMesh = null
		if base in TEM_LOD:
			longe = modelo_longe(base)
			longe.surface_set_material(0, mat_concreto if concreto else mat_metal)
		for k in _inst[nome]:
			await cid.respirar(n_nome, _inst.size())
			var lista: Array = _inst[nome][k]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = malha
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, lista[i][0])
				mm.set_instance_color(i, lista[i][1])
			if not _mm_bloco.has(nome):
				_mm_bloco[nome] = {}
			_mm_bloco[nome][k] = [mm]
			var mi := MultiMeshInstance3D.new()
			mi.name = "%s_%d_%d" % [nome, k.x, k.y]
			mi.multimesh = mm
			mi.visibility_range_end = alcance.get(base, 600.0)
			if nome in ESPARSOS:
				mi.visibility_range_end = maxf(mi.visibility_range_end, 380.0)
			if base in ["lixo", "cacos", "barril", "hidrante", "banco", "bueiro", "pneu", "caixa_papelao", "placa_pare", "placa_proibido", "placa_atencao"]:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			nos.append(mi)
			if longe != null:
				# mesmas posições (instancing), malha simples: completo até PERTO_LOD, simples dali até o alcance
				mi.visibility_range_end = perto
				var mm_l := mm.duplicate() as MultiMesh
				_mm_bloco[nome][k].append(mm_l)
				mm_l.mesh = longe
				for i in lista.size():
					mm_l.set_instance_color(i, lista[i][2])
				var ml := MultiMeshInstance3D.new()
				ml.name = "%sLonge_%d_%d" % [nome, k.x, k.y]
				ml.multimesh = mm_l
				ml.visibility_range_begin = perto
				ml.visibility_range_end = alcance.get(base, 600.0)
				ml.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # sombra de longe nem aparece
				nos.append(ml)

static func _material(ferrugem: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var s := Shader.new()
	s.code = SHADER_PROPS
	m.shader = s
	m.set_shader_parameter("ferrugem", ferrugem)
	return m

# sujeira, desgaste e ferrugem (usa o UV em metros + a posição de cada objeto para variar)
const SHADER_PROPS := """
shader_type spatial;
uniform float ferrugem = 0.5;
varying vec3 wo;
// "aleatório" sem sin(): sin() de número grande (coordenadas de milhares de metros) perde a precisão na placa do
// celular (Mali) e o resultado vira quase constante -> bolinhas iguais em grade e listras. Números pequenos (mod) e
// só multiplicações = igual no celular e no PC.
float hash(vec2 p) {
	p = mod(p, 4096.0);
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wo = MODEL_MATRIX[3].xyz; }
void fragment() {
	vec3 c = COLOR.rgb;
	vec2 q = UV * 1.7 + wo.xz * 0.37;
	float n = ruido(q) * 0.6 + ruido(q * 3.1) * 0.4;
	float r = smoothstep(0.55, 0.8, ruido(UV * 0.9 + wo.xz)) * ferrugem;
	c = mix(c, vec3(0.32, 0.17, 0.08) * (0.7 + 0.5 * n), r);
	c *= 0.72 + 0.36 * n;
	ALBEDO = clamp(c, 0.0, 1.0);
	EMISSION = max(COLOR.rgb - vec3(1.0), vec3(0.0)) * 0.15;    // faróis/lanternas (cor > 1)
	ROUGHNESS = mix(0.55, 0.95, max(r, n * 0.5));
}
"""
