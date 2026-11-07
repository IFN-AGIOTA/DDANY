extends Node3D
# PORTA BLINDADA / ELEVADOR DOS BUNKERS (0.83) · criado por mundo/local.gd (lista "elevadores" de mundo/local_bunker.gd).
#   - Em cima, na porta blindada: PEGAR = "ABRIR BUNKER N". Só abre com o CARTÃO DE ACESSO do mesmo número
#     (item "cartao_bunker_N" em qualquer lugar do inventário; o cartão não some). Abriu: a tela escurece, toca a
#     porta pesada e você chega na cabine do elevador do NÍVEL 1, lá embaixo.
#   - Lá embaixo, na cabine: PEGAR = "SUBIR ELEVADOR" (não precisa de cartão para sair) e você volta para a frente da porta.
# O botão PEGAR mostra o texto (inventario/tela_inventario.gd) e jogador/jogador.gd chama usar().
# Mexa AQUI para: o texto do botão, as mensagens e o escurecer da tela.

const Sons := preload("res://audio/sons.gd")
const RAIO := 1.7

static var todas: Array = []

var numero := 1
var desce := true
var destino_local := Vector3.ZERO      # no espaço do bunker (pai)
var olhar_local := Vector2(0, 1)       # para onde a câmera olha ao chegar

static func id_cartao(n: int) -> String:
	return "cartao_bunker_%d" % n

static func perto(p: Vector3, raio := RAIO):
	var melhor = null
	var md := raio
	for pb in todas:
		if not is_instance_valid(pb) or not pb.is_inside_tree():
			continue
		var g: Vector3 = pb.global_position
		if absf(g.y - p.y) > 1.6:
			continue
		var d := Vector2(g.x - p.x, g.z - p.z).length()
		if d < md:
			md = d
			melhor = pb
	return melhor

func _enter_tree() -> void:
	if not todas.has(self):
		todas.append(self)

func _exit_tree() -> void:
	todas.erase(self)

func acao(inv) -> String:
	if not desce:
		return "SUBIR\nELEVADOR"
	return "ABRIR\nBUNKER %d" % numero

func tem_cartao(inv) -> bool:
	return inv != null and inv.contar(id_cartao(numero)) > 0

# devolve a mensagem para a tela ("" = nada)
func usar(inv, jogador: Node3D) -> String:
	if desce and not tem_cartao(inv):
		Sons.em("impactos/bala_madeira", global_position + Vector3(0, 1.2, 0), -10.0, 15.0, 1.6)
		return "ACESSO NEGADO · PRECISA DO CARTÃO DO BUNKER %d" % numero
	var pai := get_parent() as Node3D
	var destino: Vector3 = pai.global_transform * destino_local
	var dir3: Vector3 = pai.global_transform.basis * Vector3(olhar_local.x, 0, olhar_local.y)
	_escurecer()
	Sons.em("mundo/porta_abrir", global_position + Vector3(0, 1.2, 0), 0.0, 30.0, 0.55)
	jogador.teleportar(destino + Vector3(0, 0.1, 0), atan2(-dir3.x, -dir3.z))
	Sons.em("mundo/porta_fechar", destino + Vector3(0, 1.2, 0), -2.0, 25.0, 0.5)
	if desce:
		return "BUNKER %d · NÍVEL 1 (22 m abaixo da rua) · está escuro: use a lanterna" % numero
	return "VOCÊ SAIU DO BUNKER %d" % numero

# a tela fica preta e clareia (a viagem do elevador)
func _escurecer() -> void:
	var arvore := get_tree()
	if arvore == null:
		return
	var camada := CanvasLayer.new()
	camada.layer = 50
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(r)
	arvore.root.add_child(camada)
	var tw := camada.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(r, "color:a", 0.0, 0.9)
	tw.tween_callback(camada.queue_free)
