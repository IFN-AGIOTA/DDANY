extends Node3D
# SOBREVIVENTE DO HOSPITAL (0.91) · um NPC parado no hospital (npc/hospitais.gd cria quando o hospital é montado).
# São os sobreviventes do hospital do Livro 1 (Bíblia da Lore, "Sobreviventes do hospital"):
#   MÔNICA (ex-enfermeira, líder) .... LOJA: compra e vende itens por dólares (npc/tela_loja.gd)
#   LUCAS (17 anos, não larga o rádio) TROCAS entre jogadores: ele guarda os itens e o dinheiro (npc/tela_trocas.gd)
#   CARLOS (ex-militar, sem o braço esquerdo) GUARDA: mantém a zona neutra (nada de tiro entre sobreviventes) e
#                                      derruba os infectados que entram
#   JOSÉ, A SENHORA e JHON ........... moradores (só falam)
# Botão PEGAR (tecla E) perto dele (RAIO) = falar / abrir a tela dele. Mexa AQUI para: as falas e o nome em cima.

const ModeloCls := preload("res://npc/modelo_npc.gd")

const RAIO := 2.4
const NOMES := {"monica": "MÔNICA", "carlos": "CARLOS", "lucas": "LUCAS", "jose": "JOSÉ", "senhora": "A SENHORA", "jhon": "JHON"}
const PAPEIS := {"monica": "LOJA", "lucas": "TROCAS", "carlos": "GUARDA"}
const FALAS := {
	"carlos": ["Aqui dentro ninguém atira em ninguém. Lá fora é com vocês.", "Os mortos ficam do lado de fora. Eu cuido disso.",
		"Saiu daqui, ainda tem dois minutos de trégua. Depois, cada um por si.", "Perdi um braço, não a mira."],
	"jose": ["A Mônica tem de tudo, se você tiver dólar.", "O Lucas passa o dia no rádio. Quer trocar alguma coisa com alguém, fala com ele.",
		"Dizem que os Vagos andam rondando os hospitais."],
	"senhora": ["Eu vi muita coisa, meu filho. Muita coisa.", "Descansa um pouco. Aqui é seguro.", "Não confie em quem chega sorrindo."],
	"jhon": ["...", "O que você quer?", "Não tenho nada pra você."],
	"monica": ["O que vai ser?"], "lucas": ["Fala aí!"],
}

var quem := "jose"
var pose := "npc_parado"
var hospital := -1                     # índice do local (mundo/locais.gd)
var modelo
var _rotulo: Label3D
var _fala := 0

func _ready() -> void:
	add_to_group("npcs_hospital")
	modelo = ModeloCls.new()
	modelo.pose = pose
	add_child(modelo)
	modelo.montar(quem)
	_rotulo = Label3D.new()
	_rotulo.text = NOMES.get(quem, quem.to_upper()) + (("\n" + PAPEIS[quem]) if PAPEIS.has(quem) else "")
	_rotulo.position.y = 2.1
	_rotulo.pixel_size = 0.003
	_rotulo.font_size = 44
	_rotulo.outline_size = 12
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.modulate = Color(0.75, 1.0, 0.8) if PAPEIS.has(quem) else Color(0.9, 0.9, 0.85)
	_rotulo.visibility_range_end = 25.0
	add_child(_rotulo)
	# corpo para não atravessarem ele
	var c := StaticBody3D.new()
	c.collision_layer = 1
	c.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	c.add_child(cs)
	add_child(c)

func nome() -> String:
	return NOMES.get(quem, quem.to_upper())

# texto do botão PEGAR
func acao() -> String:
	match quem:
		"monica": return "LOJA\nMÔNICA"
		"lucas": return "TROCAS\nLUCAS"
	return "FALAR\n" + nome()

# fala seguinte (moradores e o guarda)
func falar() -> String:
	var l: Array = FALAS.get(quem, ["..."])
	var t: String = l[_fala % l.size()]
	_fala += 1
	modelo.gesto("npc_sim" if _fala % 2 == 0 else "npc_nao")
	return "%s: \"%s\"" % [nome(), t]

# virar para quem chegou perto (só a cabeça/corpo, devagar)
func olhar_para(p: Vector3, dt: float) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() < 0.1:
		return
	var alvo := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, alvo, minf(1.0, dt * 3.0))
