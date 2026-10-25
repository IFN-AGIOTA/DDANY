extends Node
# SISTEMA DE ARMAS (porte do HTML v1.1.18 + estilo DayZ): pistola, M4, AKM, espingarda, rifle de caça e
# armas brancas (faca, facão, taco, machado, cano, pé de cabra) + PUNHOS com as mãos vazias.
# DayZ: a arma usa PENTE (item); RECARREGAR troca pelo pente mais cheio que você carrega (o vazio volta para o
# bolso). Sem pente cheio, enche o pente encaixado com munição solta. Espingarda e rifle carregam munição solta.
# ESTADO da arma: gasta com o uso; gasta = trava de vez em quando (RECARREGAR destrava); arruinada não atira.
# Silenciador: tiro baixo (os infectados só ouvem de perto). Mira/luneta: aproxima mais ao MIRAR.
# - O tiro sai do CENTRO DA TELA (mira) e a traçante sai do cano até o ponto acertado.
# - Mesma munição, cadência, alcance, dispersão, recuo de câmera, recarga em 3 estalos e tempo de saque.
# - Dispersão maior andando/correndo e no ar; MENOR agachado (0,6x) e mirando (0,5x).
# - Dano igual ao do HTML: pistola 34 · M4 21 · tiro na cabeça x3 (vida 100).
# Qualquer coisa atingível precisa ter o método receber_tiro(dano, ponto, direcao, forma, atirador) -> Dictionary
# INVENTÁRIO: a arma usada é a que está nas MÃOS (inventario/inventario.gd). As balas do pente ficam no próprio
# item da arma e a recarga puxa munição (mun_9mm / mun_556) dos bolsos e da mochila. Mãos vazias = sem arma.
# (veja mundo/estande_tiro.gd). Use a camada de física 3 ("inimigos") para alvos/inimigos.
# 0.94 · MUTADO (jogador/mutacao.gd): os PUNHOS viram GARRAS (mais dano e alcance, golpes de rasgar) e as armas
# brancas batem mais forte. ARMA DE FOGO ele carrega, mas não usa: na mão ela fica parada (não aparece) e o golpe
# continua sendo o das garras.

signal mudou                          # munição / arma / recarga mudaram (HUD)
signal acertou(cabeca: bool, matou: bool)
signal aviso(texto: String)
signal disparou(arma: String)
signal barulho(posicao: Vector3, raio: float)   # para os inimigos ouvirem (próximo passo)

const ModelosArmas := preload("res://armas/modelos_armas.gd")
# 0.89 (estilo Project Zomboid): o tiro se ouve bem mais longe (pistola ~40-60 m, fuzil ~120 m, espingarda ~170 m)
# e o golpe corpo a corpo também chama quem está perto (faca ~6 m, taco ~10 m, machado ~12 m)
const MULT_RUIDO_TIRO := 1.4
const MULT_RUIDO_GOLPE := 2.0
const EfeitosCls := preload("res://armas/efeitos_tiro.gd")
const SonsCls := preload("res://armas/sons_armas.gd")
const Sons := preload("res://audio/sons.gd")
const Itens := preload("res://inventario/itens.gd")
const Mutacao := preload("res://jogador/mutacao.gd")

const WDEF := {
	"pistola": {"nome": "PISTOLA", "mag": 12, "rate": 0.17, "auto": false, "range": 150.0, "spread": 0.004,
		"kick": 0.028, "ky": 0.006, "rel": 1.15, "v": 420.0, "tl": 4.5, "fl": 0.55, "dano": 34.0, "ruido": 28.0, "vibra": 14,
		"pose": "pistola", "desgaste": 0.0008},
	"m4": {"nome": "M4", "mag": 30, "rate": 0.085, "auto": true, "range": 260.0, "spread": 0.007,
		"kick": 0.014, "ky": 0.007, "rel": 1.9, "v": 520.0, "tl": 7.0, "fl": 0.8, "dano": 21.0, "ruido": 75.0, "vibra": 8,
		"pose": "m4", "desgaste": 0.0004},
	"mp5": {"nome": "MP5", "mag": 30, "rate": 0.075, "auto": true, "range": 170.0, "spread": 0.0085,
		"kick": 0.011, "ky": 0.006, "rel": 1.7, "v": 400.0, "tl": 5.0, "fl": 0.6, "dano": 22.0, "ruido": 45.0, "vibra": 7,
		"pose": "m4", "desgaste": 0.0005},
	"ak": {"nome": "AKM", "mag": 30, "rate": 0.1, "auto": true, "range": 240.0, "spread": 0.0085,
		"kick": 0.021, "ky": 0.01, "rel": 2.1, "v": 500.0, "tl": 7.0, "fl": 0.95, "dano": 29.0, "ruido": 85.0, "vibra": 10,
		"pose": "m4", "desgaste": 0.0004},
	"espingarda": {"nome": "ESPINGARDA", "mag": 6, "rate": 0.85, "auto": false, "range": 70.0, "spread": 0.004,
		"kick": 0.06, "ky": 0.012, "rel": 0.45, "rel_bala": 0.42, "v": 380.0, "tl": 3.0, "fl": 1.2, "dano": 15.0, "chumbos": 8,
		"aberto": 0.045, "ruido": 95.0, "vibra": 22, "pose": "m4", "desgaste": 0.0015},
	"rifle_caca": {"nome": "RIFLE DE CAÇA", "mag": 5, "rate": 1.25, "auto": false, "range": 450.0, "spread": 0.0012,
		"kick": 0.065, "ky": 0.006, "rel": 0.5, "rel_bala": 0.5, "v": 700.0, "tl": 9.0, "fl": 1.0, "dano": 95.0,
		"ruido": 120.0, "vibra": 20, "pose": "m4", "desgaste": 0.001},
	# corpo a corpo: alcance (m), rate = tempo entre golpes, dano por golpe
	"faca": {"nome": "FACA", "corpo": true, "dano": 38.0, "alcance": 1.7, "rate": 0.55, "ruido": 3.0, "vibra": 12, "pose": "branca", "desgaste": 0.002},
	"taco": {"nome": "TACO", "corpo": true, "dano": 46.0, "alcance": 2.1, "rate": 0.85, "ruido": 5.0, "vibra": 18, "pose": "branca", "desgaste": 0.003},
	"machado": {"nome": "MACHADO", "corpo": true, "dano": 85.0, "alcance": 2.1, "rate": 1.25, "ruido": 6.0, "vibra": 24, "pose": "branca", "desgaste": 0.002},
	"cano": {"nome": "CANO", "corpo": true, "dano": 42.0, "alcance": 2.0, "rate": 0.9, "ruido": 5.0, "vibra": 18, "pose": "branca", "desgaste": 0.001},
	"lanca": {"nome": "LANÇA", "corpo": true, "dano": 40.0, "alcance": 2.6, "rate": 0.8, "ruido": 3.0, "vibra": 14, "pose": "branca", "desgaste": 0.004},
	"facao": {"nome": "FACÃO", "corpo": true, "dano": 55.0, "alcance": 1.95, "rate": 0.7, "ruido": 4.0, "vibra": 16, "pose": "branca", "desgaste": 0.002},
	"pe_de_cabra": {"nome": "PÉ DE CABRA", "corpo": true, "dano": 48.0, "alcance": 2.0, "rate": 0.9, "ruido": 5.0, "vibra": 18, "pose": "branca", "desgaste": 0.001},
	"punhos": {"nome": "PUNHOS", "corpo": true, "dano": 13.0, "alcance": 1.45, "rate": 0.5, "ruido": 2.0, "vibra": 8, "pose": "punhos", "desgaste": 0.0},
}
const ORDEM := ["pistola", "mp5", "m4", "ak", "espingarda", "rifle_caca", "faca", "facao", "taco", "machado", "cano", "pe_de_cabra", "lanca"]
const MASCARA_TIRO := 1 | 4           # camadas 1 (mundo) e 3 (inimigos)

var atual := ""                       # tipo da arma nas mãos ("" = mãos vazias ou outro item)
var item_arma = null                  # item (inventario/item.gd) da arma nas mãos
var inventario = null                 # inventario/inventario.gd
var cd := 0.0                         # tempo até poder atirar de novo
var rel := 0.0                        # tempo restante de recarga (0 = não está recarregando)
var rel_tot := 1.0
var rel_s := 0
var since := 9.0                      # segundos desde o último tiro
var kick := 0.0                       # recuo vertical da câmera
var ky := 0.0                         # recuo lateral da câmera
var aim := 0.0                        # 0 = arma baixa · 1 = erguida
var draw := 0.0                       # animação de sacar (1 -> 0)
var rec := 0.0                        # coice da arma
var dry := 0.0
var gatilho := false                  # o jogador está segurando o gatilho
var escondida := false                # 0.72: nadando, a arma da mão some (não dá para usar na água)
var _prev := false
var _pend := false                    # um tiro pedido (toque) que ainda vai sair
var _pend_t := 0.0                    # o pedido vale por este tempo, mesmo depois de soltar o dedo
const BUFFER_TOQUE := 0.35            # toque rápido com a arma baixa: guarda o tiro até a arma subir
var vibrar := true
var acertos := 0
var tiros := 0
var golpe := 0.0                      # animação do golpe corpo a corpo (1 -> 0)
var _golpe_pend := false              # o golpe ainda vai acertar (no meio do movimento)
var travada := false                  # arma travou (gasta): RECARREGAR destrava
var _pente_novo = null                # pente que entra no fim da recarga (DayZ)
var _encher := 0                      # recarga sem pente cheio: quantas balas soltas entram

var jogador: CharacterBody3D
var efeitos: Node3D
var sons: Node
var nos := {}                         # tipo -> Node3D (modelo 3D da arma)

func _ready() -> void:
	jogador = get_parent() as CharacterBody3D
	efeitos = EfeitosCls.new()
	efeitos.name = "EfeitosTiro"
	add_child(efeitos)
	sons = SonsCls.new()
	sons.name = "SonsArmas"
	add_child(sons)
	for k in ORDEM:
		nos[k] = ModelosArmas.construir(k)
	reiniciar()

func reiniciar() -> void:
	for t in nos:
		(nos[t] as Node3D).visible = (t == atual) and not escondida
	cd = 0.0
	rel = 0.0
	gatilho = false
	_prev = false
	_pend = false
	_pend_t = 0.0
	since = 9.0
	kick = 0.0
	ky = 0.0
	aim = 0.0
	draw = 0.0
	rec = 0.0
	_sincronizar()
	mudou.emit()

func ligar_inventario(inv) -> void:
	inventario = inv
	inv.mudou.connect(_sincronizar)
	inv.mudou.connect(_invalidar_estado)
	if not mudou.is_connected(_invalidar_estado):
		mudou.connect(_invalidar_estado)     # tiro, recarga, troca de pente
	_sincronizar()

var _fogo_travada = null               # 0.94: arma de fogo na mão do mutado (para avisar uma vez só)

# a arma das mãos mudou? (trocou no inventário, atalho 1..8, botão ARMA, largou no chão...)
func _sincronizar() -> void:
	var it = inventario.arma_na_mao() if inventario != null else null
	if it != null and not WDEF.has(it.def()["arma"]):
		it = null
	var maos_vazias: bool = inventario != null and inventario.slots.get("maos") == null
	if it != null and not WDEF[it.def()["arma"]].get("corpo", false) and not bool(Mutacao.valor(_nivel_mut(), "arma_fogo", true)):
		if it != _fogo_travada:
			aviso.emit("MUTADO: NÃO CONSEGUE USAR ARMA DE FOGO")
		_fogo_travada = it
		it = null                              # 0.94: mutado não usa arma de fogo (fica com as garras)
		maos_vazias = true
	else:
		_fogo_travada = null
	var k: String = it.def()["arma"] if it != null else ("punhos" if maos_vazias else "")
	if it == item_arma and k == atual:
		_mostrar_acessorios()
		return
	item_arma = it
	atual = k
	travada = false
	_pente_novo = null
	rel = 0.0
	cd = 0.22
	draw = 1.0
	for t in nos:
		(nos[t] as Node3D).visible = (t == atual) and not escondida
	_mostrar_acessorios()
	if k != "" and k != "punhos":
		_vibrar(15)
		if sons != null:
			Sons.tocar("armas/sacar_faca" if WDEF[k].get("corpo", false) else "armas/sacar", -4.0)
		aviso.emit(WDEF[k]["nome"])
	mudou.emit()

# balas no pente e no inventário da arma das mãos
# OTIMIZAÇÃO: o resultado fica guardado até o inventário ou a arma mudarem (antes contava a munição do
# inventário inteiro 2 vezes por quadro: aqui na física e na HUD)
var _estado_cache = null

func _invalidar_estado() -> void:
	_estado_cache = null

func estado() -> Dictionary:
	if item_arma == null or eh_corpo():
		return {"mag": 0, "res": 0}
	if _estado_cache != null and _estado_cache["item"] == item_arma and _estado_cache["mag"] == item_arma.municao:
		return _estado_cache
	var r := 0
	if inventario != null:
		r = inventario.contar(item_arma.def().get("municao", ""))
		var tipo: String = item_arma.usa_pente()
		if tipo != "":
			for g in inventario.grades_do_jogador():
				for o in g.itens:
					if o.id == tipo:
						r += o.municao
	_estado_cache = {"mag": item_arma.municao, "res": r, "item": item_arma}
	return _estado_cache

# silenciador/mira aparecem no modelo da arma quando estão encaixados
func _mostrar_acessorios() -> void:
	var n: Node3D = nos.get(atual)
	if n == null:
		return
	for enc in ["cano", "mira"]:
		var a := n.get_node_or_null("Acc_" + enc)
		if a != null:
			a.visible = item_arma != null and item_arma.acessorios.has(enc)

func eh_corpo() -> bool:
	return atual != "" and WDEF[atual].get("corpo", false)

# balas que cabem na arma das mãos agora (0 = sem pente)
func capacidade() -> int:
	if item_arma == null:
		return 0
	return item_arma.capacidade()

# zoom extra da mira/luneta (o jogador divide o campo de visão por isto ao MIRAR)
func zoom_mira() -> float:
	if item_arma == null or not item_arma.acessorios.has("mira"):
		return 1.0
	return float(Itens.def(item_arma.acessorios["mira"]).get("zoom", 1.0))

# entrega os modelos das armas ao personagem (soldado: tronco · modelo importado: osso da mão)
func anexar(modelo: Node3D, ponto_mao: Node3D) -> void:
	for k in nos:
		var n: Node3D = nos[k]
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.transform = Transform3D.IDENTITY
		if modelo != null and modelo.has_method("segurar_arma"):
			modelo.segurar_arma(k, n)
		elif ponto_mao != null:
			ponto_mao.add_child(n)
		n.visible = (k == atual) and not escondida

func cano() -> Node3D:
	var n: Node3D = nos.get(atual)
	if n == null:
		return null
	return n.get_node_or_null("Cano")

func pode_usar() -> bool:
	return jogador != null and jogador.ativo and not jogador.morto and not bool(jogador.get("construindo"))

func recarregar() -> void:
	if not pode_usar():
		return
	if atual == "" or eh_corpo() or item_arma == null or rel > 0.0:
		return
	var W: Dictionary = WDEF[atual]
	var it = item_arma
	_pente_novo = null
	_encher = 0
	if inventario != null and inventario.carregando():
		inventario.cancelar_carga()     # 0.65: recarregar para de encher pente no inventário
	if travada:
		# destravar (0.65): quanto pior a arma, mais demora; a bala presa é jogada fora
		rel = 1.0 + (1.0 - clampf(it.estado, 0.0, 1.0)) * 1.6
	elif it.usa_pente() != "":
		var novo = inventario.pente_para_recarga(it)
		var soltas: int = inventario.contar(it.def().get("municao", ""))
		if novo != null:
			_pente_novo = novo
			rel = W["rel"]
		elif it.pente_id != "" and soltas > 0 and it.municao < it.capacidade():
			_encher = mini(soltas, it.capacidade() - it.municao)
			rel = W["rel"] + 0.35 * _encher        # enchendo o pente bala por bala (0.65: mais demorado)
		else:
			aviso.emit("SEM PENTE" if it.pente_id == "" else "SEM MUNIÇÃO")
			return
	else:
		var falta: int = it.capacidade() - it.municao
		var soltas: int = inventario.contar(it.def().get("municao", ""))
		_encher = mini(falta, soltas)
		if _encher <= 0:
			return
		rel = float(W["rel"]) + float(W.get("rel_bala", 0.0)) * _encher
	rel_tot = rel
	rel_s = 0
	_rel_bala = 0
	_som_recarga("inicio")
	_animar(("recarregar_fuzil" if atual in ["mp5", "m4", "ak", "espingarda", "rifle_caca"] else "recarregar_pistola"), rel, false)
	_vibrar(10)
	mudou.emit()

func _fim_recarga() -> void:
	if travada:
		travada = false
		if item_arma != null and item_arma.municao > 0:
			item_arma.municao -= 1          # a bala que emperrou sai fora
		aviso.emit("DESTRAVADA")
		return
	if item_arma == null or inventario == null:
		return
	if _pente_novo != null:
		if _pente_novo.onde != null or _pente_novo.slot != "":
			inventario.trocar_pente(item_arma, _pente_novo)
		_pente_novo = null
	elif _encher > 0:
		item_arma.municao += inventario.consumir(item_arma.def().get("municao", ""), _encher)
		_encher = 0

# ---------- sons de mexer na arma (0.49: gravações de verdade, audio/sons/armas) ----------
var _rel_bala := 0                     # balas soltas que já fizeram som nesta recarga

func _tipo_recarga() -> String:
	if atual in ["mp5", "m4", "ak"]:
		return "fuzil"
	return atual                        # pistola, espingarda, rifle_caca

# etapa: "inicio" · "meio" · "bala" (cada bala que entra) · "fim" · "fim_trava" (destravou)
func _som_recarga(etapa: String) -> void:
	var t := _tipo_recarga()
	var com_pente := _pente_novo != null
	match etapa:
		"inicio":
			if travada:
				Sons.tocar("armas/ferrolho_rifle", -4.0, 1.1)
			elif t in ["pistola", "fuzil"] and com_pente:
				Sons.tocar("armas/%s_sai" % t, -3.0)
			elif t == "rifle_caca":
				Sons.tocar("armas/ferrolho_rifle", -3.0)
		"meio":
			if t in ["pistola", "fuzil"] and com_pente:
				Sons.tocar("armas/%s_entra" % t, -2.0)
		"bala":
			Sons.tocar("armas/cartucho_espingarda" if t == "espingarda" else "armas/bala_pente", -4.0)
		"fim":
			match t:
				"pistola", "fuzil":
					Sons.tocar("armas/%s_ferrolho" % t, -2.0)
				"espingarda":
					Sons.tocar("armas/bombear", -2.0)
				"rifle_caca":
					Sons.tocar("armas/ferrolho_rifle", -3.0)
		"fim_trava":
			Sons.tocar("armas/pistola_ferrolho" if t == "pistola" else "armas/fuzil_ferrolho", -3.0)

# cápsula caindo no chão (pistola/fuzis) ou bombear/ferrolho (espingarda/rifle: a cápsula sai aí)
func _depois_do_tiro() -> void:
	if atual == "" or eh_corpo():
		return
	var t := _tipo_recarga()
	var atraso := randf_range(0.38, 0.62)
	var nome := "armas/capsula"
	var vol := -14.0
	if t == "espingarda":
		atraso = 0.32
		nome = "armas/bombear"
		vol = -6.0
	elif t == "rifle_caca":
		atraso = 0.5
		nome = "armas/ferrolho_rifle"
		vol = -6.0
	elif jogador != null and not jogador.is_on_floor():
		return
	get_tree().create_timer(atraso).timeout.connect(func(): Sons.tocar(nome, vol))

# troca de arma agora passa pelo inventário (coldre/ombro <-> mãos)
func proxima_arma() -> void:
	if pode_usar() and inventario != null:
		inventario.trocar_arma()

func dispersao() -> float:
	var W: Dictionary = WDEF.get(atual, WDEF["pistola"])
	if W.get("corpo", false):
		return 0.004
	var sp: float = jogador.vel_horizontal
	var ar := 0.0 if jogador.is_on_floor() else 1.5
	var s: float = W["spread"] * (1.0 + 1.5 * (minf(1.0, sp / 6.0) + ar))
	if jogador.agachado:
		s *= 0.6
	if jogador.mirando:
		s *= 0.5
	var sv = jogador.get("sobrevivencia")
	if sv != null:
		s *= 1.0 + sv.tremor() + (0.6 if sv.vida < 30.0 else 0.0)     # frio e ferido: a mira treme
	return s

func _physics_process(dt: float) -> void:
	if jogador == null:
		return
	golpe = maxf(0.0, golpe - dt / 0.42)
	if eh_corpo():
		_corpo_a_corpo(dt)
		return
	if atual == "" or item_arma == null:
		# mãos vazias: nada para atirar, só deixa os valores voltarem ao repouso
		_pend = false
		_prev = false
		since += dt
		draw = maxf(0.0, draw - dt * 4.5)
		rec *= exp(-dt * 16.0)
		kick *= exp(-dt * 6.5)
		ky *= exp(-dt * 6.5)
		aim += (0.0 - aim) * minf(1.0, dt * 11.0)
		return
	var W: Dictionary = WDEF[atual]
	var A := estado()
	var held := gatilho and pode_usar()
	if held and not _prev:
		_pend = true
		_pend_t = BUFFER_TOQUE
	_pend_t -= dt
	if not pode_usar() or (not held and _pend_t <= 0.0):
		_pend = false
	_prev = held
	cd -= dt
	since += dt
	dry -= dt
	draw = maxf(0.0, draw - dt * 4.5)
	rec *= exp(-dt * 16.0)
	kick *= exp(-dt * 6.5)
	ky *= exp(-dt * 6.5)
	if rel > 0.0:
		var e := 1.0 - rel / rel_tot
		if rel_s < 1 and e > 0.45:
			rel_s = 1
			_som_recarga("meio")
		if _encher > 0 and _rel_bala < _encher and e > (_rel_bala + 0.6) / (_encher + 1.0):
			_rel_bala += 1
			_som_recarga("bala")
		rel -= dt
		if rel <= 0.0:
			rel = 0.0
			var era_travada := travada
			_fim_recarga()
			_som_recarga("fim_trava" if era_travada else "fim")
		mudou.emit()
	var aim_t := 0.3 if rel > 0.0 else (1.0 if (held or _pend or since < 1.6 or jogador.mirando) else 0.0)
	aim += (aim_t - aim) * minf(1.0, dt * 11.0)
	if (held or _pend) and rel <= 0.0 and cd <= 0.0 and draw < 0.3 and aim > 0.6:
		if travada:
			if dry <= 0.0:
				dry = 0.5
				_pend = false
				Sons.tocar("armas/seco", -2.0)
				aviso.emit("ARMA EMPERRADA · RECARREGAR")
		elif item_arma.estado <= 0.0:
			if dry <= 0.0:
				dry = 0.5
				_pend = false
				aviso.emit("ARMA ARRUINADA")
		elif A["mag"] > 0:
			if (W["auto"] and held) or _pend:
				_atirar(W)
				_pend = false
		elif A["res"] > 0:
			recarregar()
		elif dry <= 0.0:
			dry = 0.35
			_pend = false
			Sons.tocar("armas/seco", -2.0)
			aviso.emit("SEM MUNIÇÃO")

# ---------- tiro ----------
func _atirar(W: Dictionary) -> void:
	item_arma.municao -= 1
	cd = W["rate"]
	since = 0.0
	rec = 1.0
	tiros += 1
	var cam: Camera3D = jogador.camera
	var o := cam.global_position
	var d0 := -cam.global_basis.z
	var sp := dispersao()
	var cn := cano()
	var m := cn.global_position if cn != null else o
	var n_chumbos := int(W.get("chumbos", 1))
	var algum := false
	var cabeca := false
	var matou := false
	for c in n_chumbos:
		var d := d0 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * sp
		if n_chumbos > 1:
			d += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * float(W["aberto"])
		d = d.normalized()
		var alcance: float = W["range"]
		var r := raio(o, d, alcance)
		var ponto: Vector3 = r["pos"] if r["hit"] else o + d * alcance
		var k: int = r["k"]
		var n: Vector3 = r["n"]
		var alvo = r["alvo"]
		# o cano pode estar atrás de uma parede que a câmera não vê: confere o caminho cano -> ponto
		var L := m.distance_to(ponto)
		if L > 0.6:
			var dm := (ponto - m) / L
			var r2 := raio(m, dm, L + 1.0)
			if r2["hit"] and m.distance_to(r2["pos"]) < L - 0.4:
				ponto = r2["pos"]
				k = r2["k"]
				n = r2["n"]
				alvo = r2["alvo"]
				r = r2
		if alvo != null and is_instance_valid(alvo) and alvo.has_method("receber_tiro"):
			var res: Dictionary = alvo.receber_tiro(float(W["dano"]), ponto, d, int(r.get("forma", 0)), jogador)
			algum = true
			cabeca = cabeca or bool(res.get("cabeca", false))
			matou = matou or bool(res.get("morto", false))
		efeitos.camera = cam
		if c == 0 or randf() < 0.35:
			efeitos.tracante(m, ponto, W["v"], W["tl"], k, n)
	if algum:
		acertos += 1
		acertou.emit(cabeca, matou)
	var silenciada: bool = item_arma.acessorios.has("cano")
	if cn != null and not silenciada:
		efeitos.clarao(cn, W["fl"])
	kick = minf(kick + float(W["kick"]), 0.14)
	ky += randf_range(-1.0, 1.0) * float(W["ky"])
	sons.tocar("tiro_silenciado" if silenciada else "tiro_" + atual)
	_depois_do_tiro()
	_vibrar(int(W["vibra"]))
	barulho.emit(jogador.global_position, float(W["ruido"]) * MULT_RUIDO_TIRO * (0.22 if silenciada else 1.0))
	disparou.emit(atual)
	# desgaste e EMPERRAR (0.65, DayZ; nomes do estado em inventario/itens.gd nome_estado): PERFEITA nunca
	# emperra · GASTA quase nunca (0,5%) · DANIFICADA às vezes (3,5%) · MUITO DANIFICADA muito (12% por tiro).
	# KIT DE LIMPEZA conserta e destrava.
	var e: float = item_arma.estado
	item_arma.estado = maxf(0.0, e - float(W.get("desgaste", 0.0005)))
	var chance := 0.0
	if e <= 0.3:
		chance = 0.12
	elif e <= 0.5:
		chance = 0.035
	elif e <= 0.7:
		chance = 0.005
	if randf() < chance:
		travada = true
		Sons.tocar("armas/seco", 0.0, 0.9)
		aviso.emit("ARMA EMPERROU · RECARREGAR")
	mudou.emit()

# ---------- corpo a corpo ----------
# animação de cada arma branca (alterna entre as da lista)
const GOLPES := {"faca": ["facada", "golpe_1m_diag"], "machado": ["golpe_2m", "golpe_2m_lado"], "taco": ["golpe_2m_lado", "golpe_2m"],
	"punhos": ["soco", "soco_cruzado", "soco_gancho"], "lanca": ["facada"], "facao": ["golpe_1m_a", "golpe_1m_b", "golpe_1m"],
	"cano": ["golpe_1m_a", "golpe_1m_b"], "pe_de_cabra": ["golpe_1m_b", "golpe_1m_a"]}
var _n_golpe := 0

# toca a animação do corpo com a duração pedida (o jogador/animador_modelo.gd decide corpo todo ou só parte de cima)
func _animar(nome: String, duracao: float, corpo_todo: bool) -> void:
	var an = jogador.get("animador") if jogador != null else null
	if an == null or not an.has_method("acao") or an._ap == null or not an._ap.has_animation(nome):
		return
	var a: Animation = an._ap.get_animation(nome)
	an.acao(nome, clampf(a.length / maxf(duracao, 0.1), 0.5, 3.0), corpo_todo)

# 0.94: nível da mutação de quem segura (0 = humano)
func _nivel_mut() -> int:
	var s = jogador.get("sobrevivencia") if jogador != null else null
	return int(s.mutacao) if s != null else 0

# números do golpe agora (mutado: punhos = GARRAS e armas brancas mais fortes)
func def_corpo() -> Dictionary:
	var W: Dictionary = WDEF[atual]
	var n := _nivel_mut()
	if n == 0:
		return W
	W = W.duplicate()
	if atual == "punhos":
		W["nome"] = "GARRAS"
		W["dano"] = float(Mutacao.valor(n, "garras", 13.0))
		W["alcance"] = 1.65
		W["rate"] = 0.55
	else:
		W["dano"] = float(W["dano"]) * float(Mutacao.valor(n, "branca"))
	return W

func nome_atual() -> String:
	if atual == "":
		return "ARMA"
	return "GARRAS" if atual == "punhos" and _nivel_mut() != 0 else str(WDEF[atual]["nome"])

func _corpo_a_corpo(dt: float) -> void:
	var W: Dictionary = def_corpo()
	var held := gatilho and pode_usar()
	if held and not _prev:
		_pend = true
		_pend_t = BUFFER_TOQUE
	_pend_t -= dt
	if not held and _pend_t <= 0.0:
		_pend = false
	_prev = held
	cd -= dt
	since += dt
	draw = maxf(0.0, draw - dt * 4.5)
	rec *= exp(-dt * 16.0)
	kick *= exp(-dt * 6.5)
	ky *= exp(-dt * 6.5)
	aim += (0.0 - aim) * minf(1.0, dt * 11.0)
	if (held or _pend) and cd <= 0.0 and draw < 0.3:
		if item_arma != null and item_arma.estado <= 0.0:
			if dry <= 0.0:
				dry = 0.5
				aviso.emit("ARMA ARRUINADA")
			dry -= dt
			return
		_pend = false
		cd = W["rate"]
		since = 0.0
		golpe = 1.0
		_golpe_pend = true
		sons.tocar("golpe", -4.0)
		_n_golpe += 1
		var anims: Array = GOLPES.get(atual, ["golpe_1m_a", "golpe_1m_b"])
		if atual == "punhos" and _nivel_mut() != 0:
			anims = ["golpe_1m_a", "golpe_1m_b", "golpe_1m_diag"]     # garras: rasga de lado e na diagonal
		_animar(anims[_n_golpe % anims.size()], maxf(float(W["rate"]) * 0.9, 0.5), true)
	if _golpe_pend and golpe < 0.62:      # o golpe acerta no meio do movimento
		_golpe_pend = false
		_acertar_golpe(W)
	dry -= dt

func _acertar_golpe(W: Dictionary) -> void:
	var cam: Camera3D = jogador.camera
	var frente := -cam.global_basis.z
	frente.y = clampf(frente.y, -0.5, 0.5)
	frente = frente.normalized()
	var peito := jogador.global_position + Vector3(0, 1.2 if not jogador.agachado else 0.8, 0)
	var esfera := SphereShape3D.new()
	esfera.radius = 0.55
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = esfera
	q.collision_mask = 4
	q.exclude = [jogador.get_rid()]
	var alcance: float = W["alcance"]
	var espaco := jogador.get_world_3d().direct_space_state
	var melhor = null
	var md := 1e9
	for passo in [0.5, 0.75, 1.0]:
		q.transform = Transform3D(Basis.IDENTITY, peito + frente * alcance * passo - frente * 0.3)
		for h in espaco.intersect_shape(q, 6):
			var c = h["collider"]
			if c == null or not (c.has_method("receber_golpe") or c.has_method("receber_tiro")):
				continue
			var d: float = (c as Node3D).global_position.distance_to(peito)
			if d < md:
				md = d
				melhor = c
		if melhor != null:
			break
	if melhor == null:
		return
	var dano: float = W["dano"] * (0.5 + 0.5 * (item_arma.estado if item_arma != null else 1.0))
	var res: Dictionary
	if melhor.has_method("receber_golpe"):
		res = melhor.receber_golpe(dano, frente, jogador)
	else:
		res = melhor.receber_tiro(dano, (melhor as Node3D).global_position + Vector3(0, 1.2, 0), frente, 0, jogador)
	acertos += 1
	acertou.emit(bool(res.get("cabeca", false)), bool(res.get("morto", false)))
	sons.tocar("impacto")
	_vibrar(int(W["vibra"]))
	barulho.emit(jogador.global_position, float(W["ruido"]) * MULT_RUIDO_GOLPE)
	if item_arma != null:
		item_arma.estado = maxf(0.0, item_arma.estado - float(W.get("desgaste", 0.002)))
	mudou.emit()

# raio contra o mundo: física (chão/prédios perto e alvos) + prédios e chão distantes pelos dados da cidade.
# devolve {hit, pos, n, k (1 terra · 2 água · 3 concreto · 4 alvo), alvo, forma, dist}
func raio(o: Vector3, d: Vector3, alcance: float) -> Dictionary:
	var melhor := {"hit": false, "pos": o + d * alcance, "n": Vector3.UP, "k": 0, "alvo": null, "forma": 0, "dist": alcance}
	var espaco := jogador.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(o, o + d * alcance, MASCARA_TIRO, [jogador.get_rid()])
	var r := espaco.intersect_ray(q)
	if not r.is_empty():
		var p: Vector3 = r["position"]
		var col: Object = r["collider"]
		var k := 3
		var alvo = null
		if col != null and col.has_method("receber_tiro"):
			k = 4
			alvo = col
		elif (r["normal"] as Vector3).y > 0.7 and p.y < 0.8:
			k = _tipo_chao(p)
		melhor = {"hit": true, "pos": p, "n": r["normal"], "k": k, "alvo": alvo, "forma": r.get("shape", 0), "dist": o.distance_to(p)}
	var mundo = jogador.get("mundo")
	if mundo != null and mundo.has_method("raio"):
		var w: Dictionary = mundo.raio(o, d, melhor["dist"])
		if w["hit"] and w["dist"] < melhor["dist"] - 0.01:
			var k2 := 3 if w["predio"] else _tipo_chao(w["pos"])
			melhor = {"hit": true, "pos": w["pos"], "n": w["n"], "k": k2, "alvo": null, "forma": 0, "dist": w["dist"]}
	return melhor

func _tipo_chao(p: Vector3) -> int:
	var mundo = jogador.get("mundo")
	if mundo != null and mundo.has_method("altura"):
		var h: float = mundo.altura(p.x, p.z)
		if h < 0.0 or absf(h - 0.2) < 0.01:
			return 2      # mar ou lago
	return 1

func _vibrar(ms: int) -> void:
	if vibrar and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

# 0.72: esconde/mostra a arma da mão (jogador/jogador.gd: nadando)
func esconder_arma(sim: bool) -> void:
	if escondida == sim:
		return
	escondida = sim
	for t in nos:
		(nos[t] as Node3D).visible = (t == atual) and not escondida
	if sim:
		gatilho = false
		aim = 0.0
