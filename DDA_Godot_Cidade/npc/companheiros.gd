extends Node
# GRUPO DO JOGADOR: cria e guarda os companheiros (npc/companheiro.gd). A história chama chegar(["greg", "mavie"])
# depois do encontro no Capítulo 3; a partir daí eles andam com o jogador, lutam e falam.
# Avisa o gerente dos infectados (vagos.companheiros) para eles também virarem alvo.
# Mexa AQUI para: quem entra no grupo e onde aparece.

const CompanheiroCls := preload("res://npc/companheiro.gd")

var jogador: CharacterBody3D = null
var mundo = null
var vagos = null
var membros := {}                  # "greg" -> companheiro

func ligar(j: CharacterBody3D, m, v) -> void:
	jogador = j
	mundo = m
	vagos = v

func chegar(quem: Array, falar := true) -> void:
	for q in quem:
		if membros.has(q):
			continue
		var c = CompanheiroCls.new()
		c.name = String(q).capitalize()
		c.configurar(q, jogador, mundo, vagos)
		add_child(c)
		var lado: float = c.DADOS[q]["lado"]
		var pj := jogador.global_position
		c.global_position = pj + Basis(Vector3.UP, jogador.rotation.y) * Vector3(lado * 1.6, 0.3, 2.0)
		c.rotation.y = jogador.rotation.y
		membros[q] = c
		if falar and q == "greg":
			c.falar("chegou", true)
	_atualizar_vagos()

func remover_todos() -> void:
	for q in membros:
		if is_instance_valid(membros[q]):
			membros[q].queue_free()
	membros.clear()
	_atualizar_vagos()

func _atualizar_vagos() -> void:
	if vagos != null:
		vagos.companheiros = membros.values()

# depois de teleportar o jogador (carregar jogo, renascer, história): o grupo vai junto
func reagrupar() -> void:
	for q in membros:
		var c = membros[q]
		if is_instance_valid(c):
			c._reaparecer()

func salvar() -> Dictionary:
	var d := {}
	for q in membros:
		d[q] = membros[q].salvar()
	return d

func carregar(d: Dictionary) -> void:
	remover_todos()
	if d.is_empty():
		return
	chegar(d.keys(), false)
	for q in d:
		membros[q].carregar(d[q])
