extends Node3D
# SINO DA IGREJA (1.06) · criado por mundo/local.gd (lista "sinos" de mundo/local_igreja.gd, lá em cima da torre).
#   - PEGAR perto do sino = "TOCAR SINO": badaladas que se ouvem de longe e CHAMAM OS INFECTADOS (RAIO_BARULHO m;
#     é o barulho mais alto do jogo). Serve para atrair a horda para longe de você (ou de um amigo) — ou é suicídio.
#   - Espera ESPERA s entre um toque e outro.
#   - No multijogador o toque vai para todos (rede/sessao_rede.gd, evento "sino"): todos ouvem, e o host faz o barulho.
# O botão PEGAR mostra o texto (inventario/tela_inventario.gd) e jogador/jogador.gd chama usar().
# Mexa AQUI para: o alcance do barulho, o tempo entre toques e o som.

const Sons := preload("res://audio/sons.gd")
const RAIO := 1.9
const RAIO_BARULHO := 400.0             # (de dia os infectados ouvem só 40% disso: regras_infectados.gd)
const ESPERA := 8.0
const ACIMA := 16.0                      # m acima do sino de onde "sai" o barulho (para os infectados)

static var todas: Array = []
static var ao_tocar := Callable()        # (posição) rede/sessao_rede.gd manda para os outros

var _t := 0.0

static func perto(p: Vector3, raio := RAIO):
	var melhor = null
	var md := raio
	for s in todas:
		if not is_instance_valid(s) or not s.is_inside_tree():
			continue
		var g: Vector3 = s.global_position
		if absf(g.y - p.y) > 2.2:
			continue
		var d := Vector2(g.x - p.x, g.z - p.z).length()
		if d < md:
			md = d
			melhor = s
	return melhor

func _enter_tree() -> void:
	if not todas.has(self):
		todas.append(self)

func _exit_tree() -> void:
	todas.erase(self)

func _process(dt: float) -> void:
	_t = maxf(_t - dt, 0.0)

func acao(_inv) -> String:
	return "TOCAR\nSINO"

func usar(_inv, jogador: Node3D) -> String:
	if _t > 0.0:
		return ""
	_t = ESPERA
	badalar(global_position, true)
	if ao_tocar.is_valid():
		ao_tocar.call(global_position)
	var mus := get_node_or_null("/root/Musica")
	if mus != null:
		mus.adicionar_tensao(0.5)
	return "O SINO ECOA PELA CIDADE · OS INFECTADOS VÃO OUVIR"

# toca as badaladas em "pos" (som: audio/sons/mundo/sino.ogg, feito por síntese) e (quem tem os infectados: solo/host)
# faz o barulho
static func badalar(pos: Vector3, fazer_barulho: bool) -> void:
	Sons.em("mundo/sino", pos, 8.0, 900.0)
	var arv := Engine.get_main_loop() as SceneTree
	if arv == null or arv.current_scene == null or not fazer_barulho:
		return
	var vagos = arv.current_scene.get("vagos")
	if vagos != null and vagos.has_method("barulho"):
		# o som sai pelo ALTO da torre (por cima da agulha): parapeito, paredes e prédios em volta não abafam o sino
		vagos.barulho(pos + Vector3(0, ACIMA, 0), RAIO_BARULHO, true)
