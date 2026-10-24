extends Node
# SOBREVIVÊNCIA (estilo DayZ) · filho do Jogador. Guarda e atualiza o estado do corpo:
#   vida (0-100) ........ cai com mordidas, fome/sede zeradas, frio, pouco sangue e infecção; volta devagar bem alimentado
#   sangue (0-5000 ml) .. cai com SANGRAMENTOS (cada um ~5 ml/s); volta com comida/água ou soro
#   fome / sede (0-100) . 100 = satisfeito; caem com o tempo (mais rápido correndo)
#   temperatura (°C) .... vai para o "conforto": clima + roupas (calor) - chuva/molhado (roupas impermeáveis ajudam)
#   molhado (0-1) ....... chuva sem cobertura molha; seca devagar
#   sangramentos ........ cada mordida pode abrir um (atadura/trapos/kit estancam)
#   infeccao ............ mordidas às vezes infeccionam: a vida cai até tomar antibióticos
#   ESTAMINA (0-100) .... correr gasta; peso demais deixa a estamina menor; zerou = não corre
#   PERNA QUEBRADA ...... queda alta ou golpe forte: só anda devagar, sem pular, até usar uma TALA
#   DESMAIO ............. com pouco sangue o jogador apaga por alguns segundos (tela preta)
#   DOENÇAS ............. GRIPE (frio/molhado demais: tosse que os infectados ouvem · vitaminas curam)
#                         CÓLERA (água suja: sede dobrada e vômito · antibióticos curam)
#                         INTOXICAÇÃO (comida estragada: vômito · carvão ativado cura ou passa sozinha)
#   FOGUEIRA perto ...... esquenta e seca a roupa
#   ÁGUA (0.72) ......... entrar na água molha a roupa (até a altura da água); NADAR gasta estamina (peso pesa muito);
#                         boiando parado ela volta se não estiver pesado. Sem estamina afunda (jogador.gd) e o FÔLEGO
#                         (0-100) acaba em ~8 s embaixo d'água; depois disso, afoga (morte "afogado").
#   0.89 · FERIMENTOS (estilo Project Zomboid): o golpe que passa pela roupa vira ARRANHÃO, LACERAÇÃO ou MORDIDA
#                         (pelas costas a mordida é mais provável; o rastejante só pega o tornozelo: sem mordida).
#   0.89 · O VÍRUS (lore: fase febril): mordida passa sempre; laceração 25%; arranhão 7% (Opções › Infectados ›
#                         Transmissão). Ninguém avisa: primeiro nada, depois ENJOO, depois FEBRE ALTA (veias escuras,
#                         tosse) e no fim a vida vai embora. Antibiótico NÃO cura. Quem morre assim LEVANTA como
#                         infectado (main.gd). Tempo até morrer: Opções › Infectados (padrão 2-3 dias do jogo).
#   0.89 · PUXADO PARA O CHÃO: 3 infectados te acertando juntos (inimigos/vagos.gd) = morte.
# Morte: vida 0 ou sangue < 500 -> sinal "morreu". As roupas protegem (campo "protecao" em itens.gd).
# Mexa AQUI para: velocidade da fome/sede, dano do sangramento, frio, regeneração.

signal morreu(causa: String)
signal ferido(dano: float)           # tela pisca em vermelho
signal atingido(origem: Vector3)     # de onde veio o golpe (a HUD mostra um arco vermelho naquele lado)
signal tossiu(pos: Vector3)          # main avisa os infectados (barulho)
signal aviso(texto: String)          # mensagens curtas ("VOCÊ VOMITOU", "PERNA QUEBRADA"...)

const FOME_POR_S := 100.0 / 3600.0   # fome zera em ~1 h de jogo andando
const SEDE_POR_S := 100.0 / 2400.0   # sede zera em ~40 min
const SANGRA_ML_S := 5.0             # por sangramento
const Regras := preload("res://inimigos/regras_infectados.gd")
const FERIDAS := ["arranhao", "laceracao", "mordida"]
const NOMES_FERIDA := {"arranhao": "ARRANHÃO", "laceracao": "LACERAÇÃO", "mordida": "MORDIDA!"}
# [dano (x), chance de abrir sangramento, chance de infeccionar (bactéria, antibiótico cura)]
const EFEITO_FERIDA := {"arranhao": [0.7, 0.15, 0.03], "laceracao": [1.0, 0.75, 0.08], "mordida": [1.3, 1.0, 0.15]}
const CONFORTO := 36.6

var vida := 100.0
var sangue := 5000.0
var fome := 85.0
var sede := 85.0
var temperatura := 36.6
var molhado := 0.0
var sangramentos := 0
var _t_lento := 0.0
var _chuva_aqui := 0.0
var infeccao := 0.0                  # 0 = saudável · >0 = infectado (sobe com o tempo)
var virus := -1.0                    # 0.89: -1 = não pegou · >= 0 = horas do jogo desde que pegou o vírus
var virus_fim := 60.0                # 0.89: com quantas horas o vírus mata (sorteado ao pegar)
var _fase_virus := 0
var _t_relogio := -1.0
var tempo_vivo := 0.0
var causa := ""
var imortal := false                 # testes
var estamina := 100.0
var estamina_max := 100.0
var perna_quebrada := false
var desmaiado := 0.0                 # segundos restantes apagado
var gripe := 0.0                     # 0..1 pegando · >=1 doente
var colera := 0.0                    # >0 doente
var intoxicacao := 0.0               # segundos restantes
var perto_fogo := false
var _t_tosse := 20.0
var _t_vomito := 40.0
var parado := 0.0                    # segundos sem se mexer (vômito)
var gas := 0.0                       # 0.65: 0..1 quanto gás tóxico tem aqui (mundo/eventos.gd: ZONA CONTAMINADA)
var folego := 100.0                  # 0.72: ar embaixo d'água
var _t_aviso_ar := 0.0
var _t_gas := 0.0

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
# OTIMIZAÇÃO: somas das roupas e o peso ficam guardados; recalcula quando o inventário muda e a cada 2 s
# (o estado das roupas gasta devagar). Antes percorria o inventário todo várias vezes por quadro.
var _cache := {}
var _t_cache := 0.0
var _inv_ligado = null

func _cache_ok() -> void:
	var inv = inventario()
	if inv != _inv_ligado and inv != null:
		_inv_ligado = inv
		inv.mudou.connect(func(): _cache.clear())
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _t_cache > 2.0:
		_t_cache = agora
		_cache.clear()

func _soma_roupas(campo: String) -> float:
	_cache_ok()
	if _cache.has(campo):
		return _cache[campo]
	var t := _soma_roupas_real(campo)
	_cache[campo] = t
	return t

func _peso() -> float:
	_cache_ok()
	if not _cache.has("@peso"):
		var inv = inventario()
		_cache["@peso"] = inv.peso_total() if inv != null else 0.0
	return _cache["@peso"]

func _soma_roupas_real(campo: String) -> float:
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
	# teto/fogueira mudam devagar: confere 3 vezes por segundo (antes era um raio por quadro)
	_t_lento -= dt
	var conferir := _t_lento <= 0.0
	if conferir:
		_t_lento = 0.33
	if clima != null:
		if conferir:
			_chuva_aqui = clima.molhando(p) if clima.has_method("molhando") else 0.0
		chuva = _chuva_aqui
		ar = clima.temperatura_ar() if clima.has_method("temperatura_ar") else 18.0
	var imperm := clampf(_soma_roupas("imperm"), 0.0, 0.95)
	if chuva > 0.0:
		molhado = minf(1.0, molhado + chuva * (1.0 - imperm) * dt / 90.0)
	else:
		molhado = maxf(0.0, molhado - dt / (240.0 if ar < 12.0 else 150.0))
	# fogueira perto: esquenta e seca
	if conferir:
		perto_fogo = false
		for f in get_tree().get_nodes_in_group("fogueiras"):
			if is_instance_valid(f) and f.acesa and (f as Node3D).global_position.distance_to(p) < 4.5:
				perto_fogo = true
				break
	if perto_fogo:
		molhado = maxf(0.0, molhado - dt / 40.0)
	# 0.72: na água a roupa molha até onde a água chega (nadando: inteira)
	var prof: float = float(jogador.get("prof_agua")) if jogador.get("prof_agua") != null else 0.0
	if bool(jogador.get("nadando")):
		molhado = 1.0
	elif prof > 0.1:
		molhado = maxf(molhado, clampf(prof / 1.3, 0.0, 1.0))
	var calor := _soma_roupas("calor")
	var alvo := 35.2 + (ar - 10.0) * 0.08 + calor * 2.6 - molhado * 1.6 + (0.6 if v > 5.0 else 0.0) + (2.6 if perto_fogo else 0.0)
	alvo = clampf(alvo, 33.5, 39.5)
	temperatura += (alvo - temperatura) * minf(1.0, dt / 120.0)
	_condicoes(dt, v, p)
	_virus(dt)
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
	if gripe >= 1.0:
		perda += 0.02
	if colera > 0.0:
		perda += 0.05
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
func receber_ataque(dano: float, chance_sangrar: float, origem: Vector3, tipo := "") -> void:
	if jogador.morto:
		return
	atingido.emit(origem)
	var prot := protecao()
	# 0.89 · a roupa segura? (quanto mais proteção, mais golpes só machucam por cima, sem ferida)
	if randf() < prot * 0.8:
		var d0 := dano * (1.0 - prot * 0.6) * 0.6
		_dano(d0, "infectados")
		ferido.emit(d0)
	else:
		# passou: arranhão, laceração ou mordida (Project Zomboid)
		var chances: Array = Regras.FERIDA
		var frente := -jogador.global_basis.z
		var de := origem - jogador.global_position
		de.y = 0.0
		if de.length_squared() > 0.0001 and frente.dot(de.normalized()) < -0.2:
			chances = Regras.FERIDA_POR_TRAS              # pelas costas
		if tipo == "tornozelo":
			chances = [0.6, 0.4, 0.0]                     # o rastejante pega o tornozelo
		var x := randf()
		var ferida := "arranhao"
		for i in 3:
			x -= float(chances[i])
			if x <= 0.0:
				ferida = FERIDAS[i]
				break
		var ef: Array = EFEITO_FERIDA[ferida]
		var d := dano * float(ef[0])
		_dano(d, "infectados")
		ferido.emit(d)
		aviso.emit(NOMES_FERIDA[ferida])
		if randf() < maxf(float(ef[1]), chance_sangrar * 0.5):
			sangramentos += 1
			var inv = inventario()
			if inv != null:
				inv.aviso.emit("SANGRANDO")
		if randf() < float(ef[2]):
			infeccao = maxf(infeccao, 0.01)
		# o VÍRUS
		var trans := Regras.transmissao()
		var pega: float = float(Regras.VIRUS[ferida]) if trans == 0 else (1.0 if trans == 1 and ferida == "mordida" else 0.0)
		if virus < 0.0 and randf() < pega:
			pegar_virus()
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

# ---------- PvP (0.71): tiro/golpe de OUTRO JOGADOR (rede/sessao_rede.gd) ----------
# Cabeça: x2,5 (capacete segura boa parte). Corpo: o colete segura. Tiro tira sangue e costuma abrir sangramento.
func levar_tiro_pvp(dano: float, cabeca: bool, origem: Vector3, quem: String, golpe: bool) -> void:
	if jogador.morto:
		return
	atingido.emit(origem)
	var inv = inventario()
	var capacete: bool = inv != null and inv.slots.get("cabeca") != null and float(inv.slots["cabeca"].def().get("protecao", 0.0)) >= 0.3
	var colete: bool = inv != null and inv.slots.get("colete") != null and float(inv.slots["colete"].def().get("protecao", 0.0)) >= 0.3
	var d := dano
	if cabeca:
		d *= 1.4 if capacete else 2.5
	elif colete:
		d *= 0.55
	var por := ("golpeado por " if golpe else "baleado por ") + quem
	_dano(d, por)
	ferido.emit(d)
	if not golpe:
		sangue = maxf(0.0, sangue - d * 10.0)
		if sangue < 500.0:
			_morrer(por)
	if randf() < (0.3 if golpe else 0.6) * (0.5 if colete and not cabeca else 1.0):
		sangramentos += 1
		if inv != null:
			inv.aviso.emit("SANGRANDO")
	# a roupa leva o tiro
	if inv != null:
		var s: String = "cabeca" if cabeca else ["camisa", "colete", "calca"][randi() % 3]
		var it = inv.slots.get(s)
		if it != null:
			it.estado = maxf(0.0, it.estado - randf_range(0.08, 0.2))

# ---------- consumíveis (inventario.usar chama aqui) ----------
# devolve "" quando usou; ou um aviso quando não dá para usar (o item não é gasto)
func aplicar(efeito: Dictionary, _id: String, estado := 1.0) -> String:
	if efeito.has("tala"):
		if not perna_quebrada:
			return "SUA PERNA ESTÁ BOA"
		perna_quebrada = false
		return ""
	if efeito.has("reparo_arma"):
		var inv = inventario()
		var arma = inv.slots.get("maos") if inv != null else null
		if arma == null or not arma.eh_arma():
			return "SEGURE A ARMA NAS MÃOS (OU SOLTE O KIT EM CIMA DELA)"
		if arma.estado >= 0.99 and not inv._arma_travada(arma):
			return "A ARMA JÁ ESTÁ PERFEITA"
		inv.limpar_arma(arma, false)          # 0.65: também destrava
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
	for c in efeito.get("cura", []):
		match c:
			"gripe":
				gripe = 0.0
			"colera":
				colera = 0.0
			"intoxicacao":
				intoxicacao = 0.0
			"infeccao":
				infeccao = 0.0
	# água suja: chance de cólera · comida estragada (estado baixo): chance de intoxicação
	if efeito.has("suja") and randf() < 0.6:
		colera = 1.0
	if (efeito.has("fome")) and estado < 0.3 and randf() < 0.7:
		intoxicacao = 240.0
		aviso.emit("ESSA COMIDA ESTAVA ESTRAGADA")
	return ""

# ---------- estamina, perna, desmaio e doenças ----------
# ZONA CONTAMINADA (0.65): sem MÁSCARA DE GÁS (slot ROSTO) o gás tira vida e faz tossir (os infectados ouvem).
# Com a máscara, nada acontece, mas o FILTRO gasta (a máscara perde estado); arruinada não protege mais.
func _gas(dt: float, p: Vector3) -> void:
	if gas <= 0.0:
		return
	var inv = inventario()
	var masc = inv.slots.get("rosto") if inv != null else null
	if masc != null and masc.id == "mascara_gas" and masc.estado > 0.0:
		masc.estado = maxf(0.0, masc.estado - dt * 0.0012 * gas)     # filtro novo dura ~14 min dentro do gás
		if masc.estado <= 0.0:
			aviso.emit("O FILTRO DA MÁSCARA ACABOU")
		return
	_dano(dt * 2.2 * gas, "gás tóxico")
	_t_gas -= dt
	if _t_gas <= 0.0:
		_t_gas = randf_range(2.5, 5.0)
		tossiu.emit(p)
		aviso.emit("*TOSSE* · GÁS TÓXICO!")

func _condicoes(dt: float, v: float, p: Vector3) -> void:
	_gas(dt, p)
	var peso: float = _peso()
	estamina_max = clampf(100.0 - maxf(0.0, peso - 18.0) * 2.5, 35.0, 100.0)
	if bool(jogador.get("nadando")):
		# 0.72: nadar (rápido gasta muito; o peso da mochila puxa para baixo) · boiando parado descansa
		var pesado := maxf(0.0, peso - 15.0)
		if v > 1.9:
			estamina -= dt * (5.0 + peso * 0.1)
		elif v > 0.3:
			estamina -= dt * (0.35 + pesado * 0.12)
		else:
			estamina += dt * (2.0 - pesado * 0.2)
		_afogar(dt)
	elif v > 5.0:
		estamina -= dt * (13.0 + peso * 0.15)
	elif v > 2.5:
		estamina += dt * 4.0
	else:
		estamina += dt * 9.0
	estamina = clampf(estamina, 0.0, estamina_max)
	if not bool(jogador.get("nadando")):
		folego = minf(100.0, folego + dt * 30.0)
	desmaiado = maxf(0.0, desmaiado - dt)
	parado = maxf(0.0, parado - dt)
	if sangue < 2400.0 and desmaiado <= 0.0 and randf() < dt * 0.025:
		desmaiado = randf_range(3.0, 6.0)
		aviso.emit("VOCÊ DESMAIOU")
	# gripe: frio ou roupa molhada por muito tempo
	if gripe < 1.0:
		if temperatura < 35.6:
			gripe += dt / 360.0
		elif molhado > 0.6:
			gripe += dt / 900.0
		else:
			gripe = maxf(0.0, gripe - dt / 1200.0)
		if gripe >= 1.0:
			aviso.emit("VOCÊ PEGOU UMA GRIPE")
	else:
		_t_tosse -= dt
		if _t_tosse <= 0.0:
			_t_tosse = randf_range(18.0, 45.0)
			tossiu.emit(p)
			aviso.emit("*TOSSE*")
	# cólera e intoxicação: vômito (perde comida e água)
	if colera > 0.0:
		sede = maxf(0.0, sede - SEDE_POR_S * dt)
	if intoxicacao > 0.0:
		intoxicacao = maxf(0.0, intoxicacao - dt)
		if intoxicacao <= 0.0:
			aviso.emit("A INTOXICAÇÃO PASSOU")
	if colera > 0.0 or intoxicacao > 0.0:
		_t_vomito -= dt
		if _t_vomito <= 0.0:
			_t_vomito = randf_range(45.0, 110.0)
			fome = maxf(0.0, fome - 15.0)
			sede = maxf(0.0, sede - 20.0)
			parado = 2.5
			tossiu.emit(p)
			aviso.emit("VOCÊ VOMITOU")

# 0.72: afundando (cabeça embaixo d'água) o fôlego acaba; sem fôlego, afoga
func _afogar(dt: float) -> void:
	if not bool(jogador.get("afundando")):
		folego = minf(100.0, folego + dt * 30.0)
		return
	folego = maxf(0.0, folego - dt * 12.0)
	if folego <= 0.0:
		_dano(dt * 9.0, "afogado")
		_t_aviso_ar -= dt
		if _t_aviso_ar <= 0.0:
			_t_aviso_ar = 3.0
			ferido.emit(9.0)
			aviso.emit("SEM AR! VOCÊ ESTÁ SE AFOGANDO")

# queda: jogador.gd chama ao pousar com a velocidade vertical (negativa)
func queda(vel_y: float) -> void:
	var v := -vel_y
	if v < 9.5:
		return
	var d := (v - 9.5) * 9.0
	_dano(d, "queda")
	ferido.emit(d)
	if v > 11.5 and not perna_quebrada:
		perna_quebrada = true
		aviso.emit("PERNA QUEBRADA · USE UMA TALA")

# 0.89 · O VÍRUS: começa a contar (as horas do jogo) e sorteia quando ele mata
func pegar_virus() -> void:
	if virus >= 0.0:
		return
	virus = 0.0
	_fase_virus = 0
	var h := Regras.horas_virus()
	virus_fim = randf_range(h.x, h.y)

# 0.89 · PUXADO PARA O CHÃO pela horda (inimigos/vagos.gd)
func derrubado() -> void:
	_morrer("puxado para o chão pelos infectados")

# horas do jogo que passaram (pelo relógio do clima; sem clima: 48 min de verdade = 1 dia)
func _horas_passadas(dt: float) -> float:
	if clima == null or clima.get("dia") == null:
		return dt * 24.0 / 2880.0
	var agora := (float(clima.dia) - 1.0) * 24.0 + float(clima.hora)
	if _t_relogio < 0.0 or agora < _t_relogio or agora - _t_relogio > 2.0:
		_t_relogio = agora
		return dt * 24.0 / 2880.0
	var h := agora - _t_relogio
	_t_relogio = agora
	return h

# fases: até 15% nada · ENJOO · 50% FEBRE ALTA (veias escuras, tosse) · 85% a vida vai embora · 100% morre
func _virus(dt: float) -> void:
	if virus < 0.0:
		return
	virus += _horas_passadas(dt)
	var u := virus / maxf(1.0, virus_fim)
	var fase := 0 if u < 0.15 else (1 if u < 0.5 else (2 if u < 0.85 else 3))
	if fase != _fase_virus:
		_fase_virus = fase
		match fase:
			1: aviso.emit("VOCÊ SE SENTE ENJOADO")
			2: aviso.emit("FEBRE ALTA · VEIAS ESCURAS NA PELE")
			3: aviso.emit("VOCÊ ESTÁ MORRENDO")
	if fase >= 2:
		temperatura = maxf(temperatura, lerpf(37.8, 39.6, clampf((u - 0.5) / 0.35, 0.0, 1.0)))
		sede = maxf(0.0, sede - SEDE_POR_S * 0.5 * dt)
		if randf() < dt / 70.0:
			tossiu.emit(jogador.global_position)          # tosse com sangue (os infectados ouvem)
			aviso.emit("VOCÊ TOSSIU SANGUE")
	if fase >= 3:
		# a vida vai embora até zerar quando o tempo acabar (1 hora do jogo = 120 s de verdade)
		var resta_s := maxf(5.0, (1.0 - u) * virus_fim * 120.0)
		_dano(dt * vida / resta_s, "o vírus")
	if u >= 1.0:
		_morrer("o vírus")

func pode_correr() -> bool:
	return estamina > 3.0 and not perna_quebrada and desmaiado <= 0.0

func doencas() -> Array:
	var r := []
	if gripe >= 1.0:
		r.append("GRIPE")
	if colera > 0.0:
		r.append("CÓLERA")
	if intoxicacao > 0.0:
		r.append("INTOXICAÇÃO")
	if infeccao > 0.0:
		r.append("INFECÇÃO")
	# 0.89: o vírus não aparece com nome: só os sintomas (como no Project Zomboid)
	if _fase_virus == 1:
		r.append("ENJOO")
	elif _fase_virus >= 2:
		r.append("FEBRE")
	return r

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
	virus = -1.0
	_fase_virus = 0
	tempo_vivo = 0.0
	causa = ""
	estamina = 100.0
	folego = 100.0
	perna_quebrada = false
	desmaiado = 0.0
	gripe = 0.0
	colera = 0.0
	intoxicacao = 0.0
	gas = 0.0

func salvar() -> Dictionary:
	return {"vida": vida, "sangue": sangue, "fome": fome, "sede": sede, "temperatura": temperatura, "molhado": molhado,
		"sangramentos": sangramentos, "infeccao": infeccao, "tempo_vivo": tempo_vivo, "perna": perna_quebrada,
		"gripe": gripe, "colera": colera, "intoxicacao": intoxicacao, "virus": virus, "virus_fim": virus_fim}

func carregar(d: Dictionary) -> void:
	for k in d:
		if k in ["vida", "sangue", "fome", "sede", "temperatura", "molhado", "infeccao", "tempo_vivo", "gripe", "colera", "intoxicacao"]:
			set(k, float(d[k]))
	sangramentos = int(d.get("sangramentos", 0))
	perna_quebrada = bool(d.get("perna", false))
	virus = float(d.get("virus", -1.0))
	virus_fim = float(d.get("virus_fim", 60.0))
	_fase_virus = 0
