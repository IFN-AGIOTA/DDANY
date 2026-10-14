extends Node
# SISTEMA DE ARMAS (porte do HTML v1.1.18): pistola + M4.
# - O tiro sai do CENTRO DA TELA (mira) e a traçante sai do cano até o ponto acertado.
# - Mesma munição, cadência, alcance, dispersão, recuo de câmera, recarga em 3 estalos e tempo de saque.
# - Dispersão maior andando/correndo e no ar; MENOR agachado (0,6x) e mirando (0,5x).
# - Dano igual aos inimigos Vagos do HTML: pistola 34 · M4 21 · tiro na cabeça x3 (vida 100).
# Qualquer coisa atingível precisa ter o método receber_tiro(dano, ponto, direcao, forma, atirador) -> Dictionary
# (veja mundo/estande_tiro.gd). Use a camada de física 3 ("inimigos") para alvos/inimigos.

signal mudou                          # munição / arma / recarga mudaram (HUD)
signal acertou(cabeca: bool, matou: bool)
signal aviso(texto: String)
signal disparou(arma: String)
signal barulho(posicao: Vector3, raio: float)   # para os inimigos ouvirem (próximo passo)

const ModelosArmas := preload("res://armas/modelos_armas.gd")
const EfeitosCls := preload("res://armas/efeitos_tiro.gd")
const SonsCls := preload("res://armas/sons_armas.gd")

const WDEF := {
	"pistola": {"nome": "PISTOLA", "mag": 12, "res": 60, "rate": 0.17, "auto": false, "range": 150.0, "spread": 0.004,
		"kick": 0.028, "ky": 0.006, "rel": 1.15, "v": 420.0, "tl": 4.5, "fl": 0.55, "dano": 34.0, "ruido": 28.0, "vibra": 14},
	"m4": {"nome": "M4", "mag": 30, "res": 180, "rate": 0.085, "auto": true, "range": 260.0, "spread": 0.007,
		"kick": 0.014, "ky": 0.007, "rel": 1.9, "v": 520.0, "tl": 7.0, "fl": 0.8, "dano": 21.0, "ruido": 75.0, "vibra": 8},
}
const ORDEM := ["pistola", "m4"]
const MASCARA_TIRO := 1 | 4           # camadas 1 (mundo) e 3 (inimigos)

var atual := "pistola"
var municao := {}                     # tipo -> {mag, res}
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
var _prev := false
var _pend := false                    # um tiro pedido (toque) que ainda vai sair
var _pend_t := 0.0                    # o pedido vale por este tempo, mesmo depois de soltar o dedo
const BUFFER_TOQUE := 0.35            # toque rápido com a arma baixa: guarda o tiro até a arma subir
var vibrar := true
var acertos := 0
var tiros := 0

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
	for k in ORDEM:
		municao[k] = {"mag": WDEF[k]["mag"], "res": WDEF[k]["res"]}
	atual = "pistola"
	for t in nos:
		(nos[t] as Node3D).visible = (t == atual)
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
	mudou.emit()

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
		n.visible = (k == atual)

func cano() -> Node3D:
	var n: Node3D = nos.get(atual)
	if n == null:
		return null
	return n.get_node_or_null("Cano")

func pode_usar() -> bool:
	return jogador != null and jogador.ativo and not jogador.morto

func recarregar() -> void:
	if not pode_usar():
		return
	var W: Dictionary = WDEF[atual]
	var A: Dictionary = municao[atual]
	if rel > 0.0 or A["mag"] >= W["mag"] or A["res"] <= 0:
		return
	rel = W["rel"]
	rel_tot = rel
	rel_s = 0
	_vibrar(10)
	mudou.emit()

func selecionar(k: String) -> void:
	if not pode_usar() or not WDEF.has(k) or k == atual:
		return
	atual = k
	rel = 0.0
	cd = 0.22
	draw = 1.0
	for t in nos:
		(nos[t] as Node3D).visible = (t == atual)
	_vibrar(15)
	sons.tocar("clique_520")
	aviso.emit(WDEF[k]["nome"])
	mudou.emit()

func proxima_arma() -> void:
	selecionar(ORDEM[(ORDEM.find(atual) + 1) % ORDEM.size()])

func dispersao() -> float:
	var W: Dictionary = WDEF[atual]
	var sp: float = jogador.vel_horizontal
	var ar := 0.0 if jogador.is_on_floor() else 1.5
	var s: float = W["spread"] * (1.0 + 1.5 * (minf(1.0, sp / 6.0) + ar))
	if jogador.agachado:
		s *= 0.6
	if jogador.mirando:
		s *= 0.5
	return s

func _physics_process(dt: float) -> void:
	if jogador == null:
		return
	var W: Dictionary = WDEF[atual]
	var A: Dictionary = municao[atual]
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
		if rel_s < 1 and e > 0.3:
			rel_s = 1
			sons.tocar("clique_380")
		if rel_s < 2 and e > 0.72:
			rel_s = 2
			sons.tocar("clique_620")
		rel -= dt
		if rel <= 0.0:
			rel = 0.0
			var take := mini(int(W["mag"]) - int(A["mag"]), int(A["res"]))
			A["mag"] += take
			A["res"] -= take
			sons.tocar("clique_300")
		mudou.emit()
	var aim_t := 0.3 if rel > 0.0 else (1.0 if (held or _pend or since < 1.6 or jogador.mirando) else 0.0)
	aim += (aim_t - aim) * minf(1.0, dt * 11.0)
	if (held or _pend) and rel <= 0.0 and cd <= 0.0 and draw < 0.3 and aim > 0.6:
		if A["mag"] > 0:
			if (W["auto"] and held) or _pend:
				_atirar(W, A)
				_pend = false
		elif A["res"] > 0:
			recarregar()
		elif dry <= 0.0:
			dry = 0.35
			_pend = false
			sons.tocar("clique_900")
			aviso.emit("SEM MUNIÇÃO")

# ---------- tiro ----------
func _atirar(W: Dictionary, A: Dictionary) -> void:
	A["mag"] -= 1
	cd = W["rate"]
	since = 0.0
	rec = 1.0
	tiros += 1
	var cam: Camera3D = jogador.camera
	var o := cam.global_position
	var d := -cam.global_basis.z
	var sp := dispersao()
	d += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * sp
	d = d.normalized()
	var alcance: float = W["range"]
	var r := raio(o, d, alcance)
	var ponto: Vector3 = r["pos"] if r["hit"] else o + d * alcance
	var k: int = r["k"]
	var n: Vector3 = r["n"]
	var alvo = r["alvo"]
	# o cano pode estar atrás de uma parede que a câmera não vê: confere o caminho cano -> ponto
	var cn := cano()
	var m := cn.global_position if cn != null else o
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
		acertos += 1
		acertou.emit(bool(res.get("cabeca", false)), bool(res.get("morto", false)))
	efeitos.camera = cam
	efeitos.tracante(m, ponto, W["v"], W["tl"], k, n)
	if cn != null:
		efeitos.clarao(cn, W["fl"])
	kick = minf(kick + float(W["kick"]), 0.14)
	ky += randf_range(-1.0, 1.0) * float(W["ky"])
	sons.tocar("tiro_" + atual)
	_vibrar(int(W["vibra"]))
	barulho.emit(jogador.global_position, W["ruido"])
	disparou.emit(atual)
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
