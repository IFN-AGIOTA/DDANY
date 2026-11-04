extends Node
# 1.13 · MODO HISTÓRIA (Ato 1 "Nova York", estudos/ROTEIRO_MODO_HISTORIA.md): liga o mundo ANTES DO CAOS e toca as
# missões em ordem, uma depois da outra (linear, sem escolhas). Criado por main.gd (_jogar_historia).
#   · MUNDO ANTES DO CAOS: sem infectados, sem loot espalhado, sem eventos/missões do modo livre, sem fome e sede, sem
#     morrer; as peças de ABANDONO (carros largados, lixo, entulho, barreiras do Exército, caçambas) somem — ficam os
#     postes, semáforos, hidrantes, bancos e árvores. A hora e o tempo ficam presos no que a missão pedir.
#   · O jogador VIRA O DOMINIC (historia/atores.gd: cabelo branco, óculos de aviador, jaqueta de couro preta).
#   · PROGRESSO salvo em user://historia.json (qual missão e o que já viu); o jogo salvo do modo livre não é tocado.
#   · Ferramentas das missões: objetivo() (texto + GPS), chegar(), cartela(), escuro()/clarear(), cutscene.tocar().
# MISSOES = a ordem do Ato 1 (cada uma é um arquivo historia/missao_*.gd com func rodar(h)).
# Mexa AQUI para: a ordem das missões e o que some da cidade (ESCONDER).

const CutsceneCls := preload("res://historia/cutscene.gd")
const Atores := preload("res://historia/atores.gd")
const RotaGps := preload("res://hud/rota_gps.gd")
const UI := preload("res://menu/ui.gd")

const ARQUIVO := "user://historia.json"
const MISSOES := [["corrida", "res://historia/missao_corrida.gd", "MISSÃO 1 · A ÚLTIMA CORRIDA"]]
const PROXIMA_EM_BREVE := "MISSÃO 2 · PÂNICO MIDIÁTICO"
# peças do abandono que somem antes do caos (nomes dos MultiMesh de mundo/abandono.gd: "<modelo>_<x>_<z>")
const ESCONDER := ["sedan", "taxi", "van", "onibus", "barreira", "barril", "cacamba", "lixo", "entulho", "cacos", "pneu",
	"caixote", "caixa_papelao", "carro_coberto", "humvee", "mrap", "caminhao_exercito", "caminhao_tanque", "tanque",
	"sacos_areia", "saco_lixo"]

signal acabou(ok: bool)

var main = null
var cena: CanvasLayer                 # historia/cutscene.gd
var progresso := {}
var missao: Node = null
var _hud: CanvasLayer
var _obj: Label
var _sub: Label
var _veu: ColorRect
var _escondidos: Array = []
var _obst_original := PackedFloat32Array()
var testando := false                 # testes automáticos (pula esperas)

static func ler() -> Dictionary:
	if not FileAccess.file_exists(ARQUIVO):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	return d if d is Dictionary else {}

static func resumo() -> String:
	var d := ler()
	if d.is_empty():
		return ""
	if bool(d.get("ato1_corrida", false)):
		return "Missão 1 concluída · a Missão 2 chega na próxima atualização"
	return "Missão 1 · A Última Corrida"

func salvar() -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(progresso))

func ligar(m) -> void:
	main = m
	progresso = ler()
	cena = CutsceneCls.new()
	cena.name = "Cutscene"
	add_child(cena)
	_criar_hud()
	_mundo_antes_do_caos()
	Atores.vestir_jogador(main.jogador, "dominic")

func _process(_dt: float) -> void:
	if main == null or main.jogador == null or not is_instance_valid(main.jogador):
		return
	var s = main.jogador.sobrevivencia
	if s != null:
		s.fome = 100.0
		s.sede = 100.0
		s.estamina = s.estamina_max
		s.imortal = true

# ---------- o mundo antes do caos ----------
func _mundo_antes_do_caos() -> void:
	if main.vagos != null:
		main.vagos.ativo = false
	if main.clima != null:
		main.clima.parado = true
	if main.hud_status != null:
		main.hud_status.visible = false
	var cid = main.cidade
	for n in cid.detalhes_abandono:
		if not is_instance_valid(n):
			continue
		var base := str(n.name).rsplit("_", true, 2)[0]
		if base in ESCONDER:
			n.visible = false
			_escondidos.append(n)
	# obstáculos de física: ficam só os pequenos (postes, hidrantes, lixeiras, placas)
	if cid.abandono != null and main.mundo != null:
		_obst_original = cid.abandono.obstaculos
		var o := PackedFloat32Array()
		for i in range(0, _obst_original.size(), 7):
			if maxf(_obst_original[i + 3], _obst_original[i + 5]) <= 1.0:
				for k in 7:
					o.append(_obst_original[i + k])
		main.mundo.configurar_obstaculos(o)
	# o inventário começa vazio (o Dominic não carrega nada na noite da corrida)
	var inv = main.jogador.inventario
	if inv != null and inv.has_method("esvaziar"):
		inv.esvaziar()

# ao sair do modo história: a cidade volta como era (para o modo livre)
func restaurar() -> void:
	for n in _escondidos:
		if is_instance_valid(n):
			n.visible = true
	_escondidos.clear()
	RotaGps.limitar_area(PackedVector2Array())
	Engine.time_scale = 1.0

# ---------- missões ----------
func comecar() -> void:
	for m in MISSOES:
		if bool(progresso.get("ato1_" + m[0], false)):
			continue
		var scr = load(m[1])
		missao = scr.new()
		missao.name = "Missao_" + m[0]
		add_child(missao)
		var ok: bool = await missao.rodar(self)
		if not is_instance_valid(self):
			return
		if missao != null and is_instance_valid(missao):
			missao.queue_free()
		missao = null
		if not ok:
			acabou.emit(false)
			return
		progresso["ato1_" + m[0]] = true
		salvar()
	# acabou o que existe por enquanto
	await cartela("CONTINUA", PROXIMA_EM_BREVE + " · na próxima atualização", 4.0)
	acabou.emit(true)

# ---------- ferramentas das missões ----------
func _criar_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 35
	add_child(_hud)
	var v := UI.vh(_hud)
	_veu = ColorRect.new()
	_veu.color = Color(0, 0, 0, 0)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_veu)
	_obj = UI.rotulo("", 2.6 * v, Color(1, 0.95, 0.85), 800, 0.0, true)
	_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj.add_theme_constant_override("outline_size", int(0.45 * v))
	_obj.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_obj.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_obj.position = Vector2(-60.0 * v, 8.5 * v)
	_obj.size = Vector2(120.0 * v, 4.0 * v)
	_hud.add_child(_obj)
	_sub = UI.rotulo("", 2.2 * v, UI.AMBAR, 800, 0.0, true)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_constant_override("outline_size", int(0.4 * v))
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sub.position = Vector2(-60.0 * v, 12.5 * v)
	_sub.size = Vector2(120.0 * v, 3.5 * v)
	_hud.add_child(_sub)

# texto do objetivo no alto da tela ("" apaga) e, com destino, a linha do GPS até lá
func objetivo(texto: String, destino := Vector2.INF, nome := "", cor := Color(-1, 0, 0)) -> void:
	_obj.text = texto
	if main.mapa == null:
		return
	if destino == Vector2.INF:
		main.mapa.limpar_rota()
		main.mapa.limpar_objetivo()
		return
	main.mapa.definir_rota(destino, main.mapa.COR_ROTA_MISSAO if cor.r < 0.0 else cor, nome)

func info(texto: String) -> void:
	_sub.text = texto

func esconder_hud(sim: bool) -> void:
	_obj.visible = not sim
	_sub.visible = not sim
	if main.mapa != null:
		main.mapa.visivel_hud = not sim
	if main.hud != null:
		main.hud.visible = not sim
	if main.controles != null:
		main.controles.set_bloqueado(sim)
		main.controles.visible = not sim

# espera o jogador chegar perto de p (m)
func chegar(p: Vector3, raio := 8.0) -> void:
	while is_instance_valid(main.jogador):
		var j: Vector3 = main.jogador.global_position
		if Vector2(j.x - p.x, j.z - p.z).length() <= raio:
			return
		await get_tree().process_frame

# tela preta (alvo 1) ou clara (alvo 0)
func escuro(t := 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(_veu, "color:a", 1.0, t)
	await tw.finished

func clarear(t := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_veu, "color:a", 0.0, t)
	await tw.finished

# cartela de capítulo / fim (fundo preto, título e subtítulo)
func cartela(titulo: String, sub: String, dur := 3.0) -> void:
	esconder_hud(true)
	await escuro(0.5)
	await cena.tocar([{"titulo": [titulo, sub], "dur": dur, "barras": false}])
	esconder_hud(false)

# o jogador (e a câmera) vai para um lugar sem ver o caminho
func teleportar(p: Vector3, giro: float) -> void:
	var j = main.jogador
	main.mundo.forcar(Vector2(p.x, p.z))
	if main.chunks != null and main.chunks.has_method("forcar"):
		main.chunks.forcar(p)
	j.teleportar(p, giro)

func esperar(s: float) -> void:
	if testando:
		s = minf(s, 0.05)
	await get_tree().create_timer(s, false).timeout
