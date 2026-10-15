extends Node
# SOBREVIVÊNCIA (estilo DayZ) · filho do Jogador. Guarda e atualiza o estado do corpo:
#   vida (0-100) ........ cai com mordidas, fome/sede zeradas, frio, pouco sangue e infecção; volta devagar bem alimentado
#   sangue (0-5000 ml) .. cai com SANGRAMENTOS (cada um ~5 ml/s); volta com comida/água ou soro
#   fome / sede (0-100) . 100 = satisfeito; caem com o tempo (mais rápido correndo)
#   temperatura (°C) .... vai para o "conforto": clima + roupas (calor) - chuva/molhado (roupas impermeáveis ajudam)
#   molhado (0-1) ....... chuva sem cobertura molha; seca devagar
#   sangramentos ........ cada mordida pode abrir um (atadura/trapos/kit estancam)
#   infeccao ............ mordidas às vezes infeccionam: a vida cai até tomar antibióticos/vitaminas
# Morte: vida 0 ou sangue < 500 -> sinal "morreu". As roupas protegem (campo "protecao" em itens.gd).
# Mexa AQUI para: velocidade da fome/sede, dano do sangramento, frio, regeneração.

signal morreu(causa: String)
signal ferido(dano: float)           # tela pisca em vermelho

const FOME_POR_S := 100.0 / 3600.0   # fome zera em ~1 h de jogo andando
const SEDE_POR_S := 100.0 / 2400.0   # sede zera em ~40 min
const SANGRA_ML_S := 5.0             # por sangramento
const CONFORTO := 36.6

var vida := 100.0
var sangue := 5000.0
var fome := 85.0
var sede := 85.0
var temperatura := 36.6
var molhado := 0.0
var sangramentos := 0
var infeccao := 0.0                  # 0 = saudável · >0 = infectado (sobe com o tempo)
var tempo_vivo := 0.0
var causa := ""
var imortal := false                 # testes / história

var jogador: CharacterBody3D
var clima = null                     # mundo/clima.gd (temperatura do ar, chuva); pode ser null
var tendencias := {}                 # nome -> -1 / 0 / +1 (setas da HUD)
var _ant := {}
var _t_tend := 0.0

func _ready() -> void:
	jogador = get_parent() as CharacterBody3D

func inventario():
	return jogador.get("inventario")

# ---------- roupas ----------
func _soma_roupas(campo: String) -> float:
	var inv = inventario()
	if inv == null:
		return 0.0
	var t := 0.0
	for s in inv.slots:
		if s == "maos":
			continue
		var it = inv.slots[s]
		if it != null:
			t += float(it.def().get(campo, 0.0)) * (0.4 + 0.6 * it.estado)
	return t

func protecao() -> float:
	return clampf(_soma_roupas("protecao"), 0.0, 0.8)

# ---------- tempo passando ----------
func _process(dt: float) -> void:
	if jogador == null or jogador.morto or not jogador.ativo:
		return
	tempo_vivo += dt
	var v: float = jogador.vel_horizontal
	var esforco := 1.0 + (1.0 if v > 5.0 else (0.3 if v > 2.5 else 0.0))
	fome = maxf(0.0, fome - FOME_POR_S * esforco * dt)
	sede = maxf(0.0, sede - SEDE_POR_S * (esforco * 0.8 + 0.2) * dt * (1.0 + maxf(0.0, temperatura - 37.5)))
	# chuva e temperatura
	var p := jogador.global_position
	var chuva := 0.0
	var ar := 18.0
	if clima != null:
		chuva = clima.molhando(p) if clima.has_method("molhando") else 0.0
		ar = clima.temperatura_ar() if clima.has_method("temperatura_ar") else 18.0
	var imperm := clampf(_soma_roupas("imperm"), 0.0, 0.95)
	if chuva > 0.0:
		molhado = minf(1.0, molhado + chuva * (1.0 - imperm) * dt / 90.0)
	else:
		molhado = maxf(0.0, molhado - dt / (240.0 if ar < 12.0 else 150.0))
	var calor := _soma_roupas("calor")
	var alvo := 35.2 + (ar - 10.0) * 0.08 + calor * 2.6 - molhado * 1.6 + (0.6 if v > 5.0 else 0.0)
	alvo = clampf(alvo, 33.5, 39.5)
	temperatura += (alvo - temperatura) * minf(1.0, dt / 120.0)
	# sangue
	if sangramentos > 0:
		sangue -= SANGRA_ML_S * sangramentos * dt
	elif fome > 40.0 and sede > 40.0 and sangue < 5000.0:
		sangue = minf(5000.0, sangue + 1.2 * dt)
	# vida
	var perda := 0.0
	if fome <= 0.0:
		perda += 0.15
	if sede <= 0.0:
		perda += 0.25
	if temperatura < 35.0:
		perda += 0.12 * (35.0 - temperatura)
	if sangue < 2500.0:
		perda += 0.3 * (1.0 - sangue / 2500.0)
	if infeccao > 0.0:
		infeccao += dt / 600.0
		perda += 0.05 + 0.1 * minf(infeccao, 2.0)
	if perda > 0.0:
		_dano(perda * dt, "fome" if fome <= 0.0 else ("sede" if sede <= 0.0 else ("frio" if temperatura < 35.0 else ("infecção" if infeccao > 0.0 else "sangue"))))
	elif fome > 50.0 and sede > 50.0 and sangramentos == 0 and sangue > 3500.0:
		vida = minf(100.0, vida + 0.1 * dt)
	if sangue < 500.0:
		_morrer("sangue")
	_t_tend -= dt
	if _t_tend <= 0.0:
		_t_tend = 2.0
		for k in ["vida", "sangue", "fome", "sede", "temperatura"]:
			var atual: float = get(k)
			var antes: float = _ant.get(k, atual)
			var lim: float = {"vida": 0.05, "sangue": 1.0, "fome": 0.3, "sede": 0.3, "temperatura": 0.01}[k]
			tendencias[k] = 1 if atual - antes > lim else (-1 if antes - atual > lim else 0)
			_ant[k] = atual

func _dano(d: float, por: String) -> void:
	if imortal or jogador.morto:
		return
	vida -= d
	if vida <= 0.0:
		vida = 0.0
		_morrer(por)

func _morrer(por: String) -> void:
	if jogador.morto or imortal:
		return
	causa = por
	jogador.morto = true
	morreu.emit(por)

# ---------- ataques (infectados) ----------
func receber_ataque(dano: float, chance_sangrar: float, _origem: Vector3) -> void:
	if jogador.morto:
		return
	var prot := protecao()
	var d := dano * (1.0 - prot * 0.6)
	_dano(d, "Vagos")
	ferido.emit(d)
	if randf() < chance_sangrar * (1.0 - prot):
		sangramentos += 1
		var inv = inventario()
		if inv != null:
			inv.aviso.emit("SANGRANDO")
	if randf() < 0.04 * (1.0 - prot):
		infeccao = maxf(infeccao, 0.01)
	# a roupa leva o golpe
	var inv = inventario()
	if inv != null:
		var vestidos := []
		for s in ["camisa", "colete", "calca", "cabeca"]:
			if inv.slots.get(s) != null:
				vestidos.append(inv.slots[s])
		if not vestidos.is_empty():
			var it = vestidos[randi() % vestidos.size()]
			it.estado = maxf(0.0, it.estado - randf_range(0.03, 0.12))

# ---------- consumíveis (inventario.usar chama aqui) ----------
# devolve "" quando usou; ou um aviso quando não dá para usar (o item não é gasto)
func aplicar(efeito: Dictionary, _id: String) -> String:
	if efeito.has("reparo_arma"):
		var inv = inventario()
		var arma = inv.slots.get("maos") if inv != null else null
		if arma == null or not arma.eh_arma() or arma.estado >= 0.99:
			return "SEGURE A ARMA NAS MÃOS"
		arma.estado = minf(1.0, arma.estado + float(efeito["reparo_arma"]))
		return ""
	if efeito.has("reparo_roupa"):
		var inv = inventario()
		var feito := false
		if inv != null:
			for s in inv.slots:
				var it = inv.slots[s]
				if s != "maos" and it != null and it.estado < 0.99:
					it.estado = minf(1.0, it.estado + float(efeito["reparo_roupa"]))
					feito = true
		return "" if feito else "NADA PARA CONSERTAR"
	if efeito.has("sangrar") and sangramentos == 0 and efeito.size() == 1:
		return "NÃO ESTÁ SANGRANDO"
	fome = clampf(fome + float(efeito.get("fome", 0.0)), 0.0, 100.0)
	sede = clampf(sede + float(efeito.get("sede", 0.0)), 0.0, 100.0)
	vida = clampf(vida + float(efeito.get("vida", 0.0)), 0.0, 100.0)
	sangue = clampf(sangue + float(efeito.get("sangue", 0.0)), 0.0, 5000.0)
	sangramentos = maxi(0, sangramentos - int(efeito.get("sangrar", 0)))
	if float(efeito.get("doenca", 0.0)) < 0.0:
		infeccao = 0.0
	return ""

# o frio faz a mira tremer (armas.gd multiplica a dispersão)
func tremor() -> float:
	return clampf((35.8 - temperatura) * 0.6, 0.0, 1.2)

func reiniciar() -> void:
	vida = 100.0
	sangue = 5000.0
	fome = 70.0
	sede = 70.0
	temperatura = 36.6
	molhado = 0.0
	sangramentos = 0
	infeccao = 0.0
	tempo_vivo = 0.0
	causa = ""

func salvar() -> Dictionary:
	return {"vida": vida, "sangue": sangue, "fome": fome, "sede": sede, "temperatura": temperatura, "molhado": molhado,
		"sangramentos": sangramentos, "infeccao": infeccao, "tempo_vivo": tempo_vivo}

func carregar(d: Dictionary) -> void:
	for k in d:
		if k in ["vida", "sangue", "fome", "sede", "temperatura", "molhado", "infeccao", "tempo_vivo"]:
			set(k, float(d[k]))
	sangramentos = int(d.get("sangramentos", 0))
