extends Node3D
# ATOR 3D DE VERDADE nas cutscenes (hoje: o DOMINIC VAIDER, personagens/dominic/dominic.scn). Tem a MESMA interface
# do boneco de caixas (npc/modelo_humano.gd) que historia/cutscene.gd usa: montar(), pose, caido, golpear(),
# levar_golpe(), pos_cabeca() e atualizar(dt, vel). Por dentro é o jogador/modelo_sobrevivente.gd com as
# animações do jogo (andar, correr, sentar, dirigir, acenar...).
# Frente = -Z (igual ao boneco de caixas). Mexa AQUI para: qual animação cada "pose" usa.

const SobreviventeCls := preload("res://jogador/modelo_sobrevivente.gd")
const ModelosArmas := preload("res://armas/modelos_armas.gd")
# pose da cutscene -> animação
const POSES := {"sentado": "sentado", "dirigindo": "dirigindo", "acenar": "acenar", "abraco": "empurrar",
	"segurar_luz": "parado_lanterna"}
# personagens que já têm modelo 3D
const COM_MODELO := ["dominic"]

var pose := ""
var caido := false
var escala := 1.0
var modelo                             # jogador/modelo_sobrevivente.gd
var _arma := ""
var _atual := ""

static func tem_modelo(quem: String) -> bool:
	return quem in COM_MODELO and ResourceLoader.exists("res://personagens/%s/%s.scn" % [quem, quem])

func montar(quem: String, tipo_arma: String) -> void:
	modelo = SobreviventeCls.new()
	modelo.personagem = quem
	add_child(modelo)
	modelo.rotation.y = PI                 # o manequim olha para +Z; o ator olha para -Z
	_arma = tipo_arma
	if tipo_arma != "":
		var n := ModelosArmas.construir(tipo_arma)
		for nome in ["Acc_cano", "Acc_mira"]:
			var x := n.get_node_or_null(nome)
			if x != null:
				x.visible = false
		modelo.segurar_arma(tipo_arma, n)

func golpear() -> void:
	_tocar_por_cima("golpe_1m_a", 1.4)

func levar_golpe() -> void:
	_tocar_por_cima("levar_golpe_a", 1.3)

func _tocar_por_cima(nome: String, vel: float) -> void:
	if modelo != null and modelo.camada != null and modelo.anim.has_animation(nome):
		modelo.camada.tocar(modelo.anim.get_animation(nome), vel)

func pos_cabeca() -> Vector3:
	var sk: Skeleton3D = modelo.esqueleto
	var b := sk.find_bone("Head")
	return sk.global_transform * sk.get_bone_global_pose(b).origin + Vector3(0, 0.12, 0)

# vel = velocidade horizontal (m/s)
func atualizar(_dt: float, vel: float) -> void:
	if modelo == null or modelo.anim == null:
		return
	var nome := "parado"
	var escala_t := 1.0
	if caido:
		nome = "morrer"
	elif POSES.has(pose):
		nome = POSES[pose]
	elif vel > 2.6:
		nome = "correr"
		escala_t = clampf(vel / 5.5, 0.8, 1.4)
	elif vel > 0.15:
		nome = "andar"
		escala_t = clampf(vel / 1.7, 0.6, 1.5)
	elif _arma != "":
		nome = "parado_arma"
	if not modelo.anim.has_animation(nome):
		nome = "parado"
	if nome != _atual:
		_atual = nome
		modelo.anim.play(nome, 0.25)
	modelo.anim.speed_scale = escala_t
