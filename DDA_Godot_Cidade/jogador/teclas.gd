extends RefCounted
# TECLAS DO TECLADO E MOUSE (0.62): cada AÇÃO do jogo tem uma tecla (ou botão do mouse) que o jogador pode trocar em
# Opções › Teclado e mouse. Guardado em Config "teclas" ({ação: código}); o que não foi trocado usa o PADRÃO abaixo.
# Código: "k:<keycode>" (tecla) ou "m:<botão>" (mouse: 1 esquerdo, 2 direito, 3 meio, 8/9 laterais).
# Quem usa: jogador/controles.gd (andar, atirar...), hud/mapa.gd (mapa), inventario/tela_inventario.gd (fechar).
# Mexa AQUI para: as ações que existem, os nomes mostrados e as teclas padrão.

# [ação, nome na tela, padrão, grupo]
const ACOES := [
	["frente", "Andar para a frente", "k:%d" % KEY_W, "Movimento"],
	["tras", "Andar para trás", "k:%d" % KEY_S, "Movimento"],
	["esquerda", "Andar para a esquerda", "k:%d" % KEY_A, "Movimento"],
	["direita", "Andar para a direita", "k:%d" % KEY_D, "Movimento"],
	["correr", "Correr", "k:%d" % KEY_SHIFT, "Movimento"],
	["andar", "Andar devagar (segurar)", "k:%d" % KEY_ALT, "Movimento"],
	["pular", "Pular", "k:%d" % KEY_SPACE, "Movimento"],
	["agachar", "Agachar", "k:%d" % KEY_C, "Movimento"],
	["atirar", "Atirar / golpear", "m:%d" % MOUSE_BUTTON_LEFT, "Combate"],
	["mirar", "Mirar", "m:%d" % MOUSE_BUTTON_RIGHT, "Combate"],
	["recarregar", "Recarregar", "k:%d" % KEY_R, "Combate"],
	["trocar_arma", "Trocar de arma", "k:%d" % KEY_X, "Combate"],
	["roda", "Roda do inventário rápido", "k:%d" % KEY_Q, "Combate"],
	["atalho_1", "Atalho 1", "k:%d" % KEY_1, "Inventário rápido"],
	["atalho_2", "Atalho 2", "k:%d" % KEY_2, "Inventário rápido"],
	["atalho_3", "Atalho 3", "k:%d" % KEY_3, "Inventário rápido"],
	["atalho_4", "Atalho 4", "k:%d" % KEY_4, "Inventário rápido"],
	["atalho_5", "Atalho 5", "k:%d" % KEY_5, "Inventário rápido"],
	["atalho_6", "Atalho 6", "k:%d" % KEY_6, "Inventário rápido"],
	["atalho_7", "Atalho 7", "k:%d" % KEY_7, "Inventário rápido"],
	["atalho_8", "Atalho 8", "k:%d" % KEY_8, "Inventário rápido"],
	["pegar", "Pegar item do chão", "k:%d" % KEY_E, "Interação"],
	["inventario", "Inventário", "k:%d" % KEY_TAB, "Interação"],
	["mapa", "Mapa", "k:%d" % KEY_M, "Interação"],
	["pausa", "Pausa", "k:%d" % KEY_ESCAPE, "Interação"],
	["camera", "1ª / 3ª pessoa", "k:%d" % KEY_F, "Interação"],
	["mensagem", "Mensagens rápidas (multijogador)", "k:%d" % KEY_T, "Interação"],
	["voo", "Câmera livre (voo)", "k:%d" % KEY_V, "Câmera livre"],
	["voo_sobe", "Câmera livre: subir", "k:%d" % KEY_E, "Câmera livre"],
	["voo_desce", "Câmera livre: descer", "k:%d" % KEY_Q, "Câmera livre"],
	["voo_vel", "Câmera livre: velocidade", "k:%d" % KEY_SHIFT, "Câmera livre"],
]
# ações que podem ter a mesma tecla (valem em situações diferentes: andando x câmera livre)
const SO_NO_VOO := ["voo_sobe", "voo_desce", "voo_vel"]

static var _mapa := {}                 # ação -> código (padrão + trocadas)

static func carregar(trocadas: Dictionary) -> void:
	_mapa.clear()
	for a in ACOES:
		_mapa[a[0]] = a[2]
	for k in trocadas:
		if _mapa.has(k) and str(trocadas[k]) != "":
			_mapa[k] = str(trocadas[k])

static func padrao(acao: String) -> String:
	for a in ACOES:
		if a[0] == acao:
			return a[2]
	return ""

static func codigo(acao: String) -> String:
	if _mapa.is_empty():
		carregar({})
	return str(_mapa.get(acao, ""))

# a tecla/botão da ação está apertada agora?
static func apertado(acao: String) -> bool:
	var c := codigo(acao)
	if c.begins_with("k:"):
		return Input.is_key_pressed(int(c.substr(2)))
	if c.begins_with("m:"):
		return Input.is_mouse_button_pressed(int(c.substr(2)))
	return false

# o evento é a tecla/botão desta ação? (só compara; quem chama olha pressed/echo)
static func casa(e: InputEvent, acao: String) -> bool:
	var c := codigo(acao)
	return c != "" and c == codigo_do_evento(e)

static func codigo_do_evento(e: InputEvent) -> String:
	if e is InputEventKey:
		var k: Key = (e as InputEventKey).keycode
		if k == KEY_NONE:
			k = (e as InputEventKey).physical_keycode
		return "k:%d" % k
	if e is InputEventMouseButton:
		var b: int = (e as InputEventMouseButton).button_index
		if b in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return ""                  # a rodinha é a troca de arma (opção à parte)
		return "m:%d" % b
	return ""

# nome para mostrar ("W", "Shift", "Mouse esquerdo"...)
static func texto(c: String) -> String:
	if c.begins_with("k:"):
		var k := int(c.substr(2))
		match k:
			KEY_SPACE: return "Espaço"
			KEY_ESCAPE: return "Esc"
			KEY_TAB: return "Tab"
			KEY_SHIFT: return "Shift"
			KEY_CTRL: return "Ctrl"
			KEY_ALT: return "Alt"
			KEY_ENTER: return "Enter"
			KEY_BACKSPACE: return "Backspace"
			KEY_UP: return "Seta ↑"
			KEY_DOWN: return "Seta ↓"
			KEY_LEFT: return "Seta ←"
			KEY_RIGHT: return "Seta →"
		return OS.get_keycode_string(k)
	if c.begins_with("m:"):
		match int(c.substr(2)):
			MOUSE_BUTTON_LEFT: return "Mouse esquerdo"
			MOUSE_BUTTON_RIGHT: return "Mouse direito"
			MOUSE_BUTTON_MIDDLE: return "Mouse do meio"
			MOUSE_BUTTON_XBUTTON1: return "Mouse lateral 1"
			MOUSE_BUTTON_XBUTTON2: return "Mouse lateral 2"
		return "Mouse " + c.substr(2)
	return "—"

static func texto_de(acao: String) -> String:
	return texto(codigo(acao))

# troca a tecla de uma ação; se outra ação (que vale ao mesmo tempo) já usava esse código, ela fica com a tecla
# antiga desta (troca as duas). Devolve o dicionário de teclas trocadas para salvar em Config "teclas".
static func definir(acao: String, novo: String) -> Dictionary:
	if _mapa.is_empty():
		carregar({})
	var antigo := codigo(acao)
	for a in ACOES:
		var outra: String = a[0]
		if outra != acao and _mapa.get(outra) == novo and ((outra in SO_NO_VOO) == (acao in SO_NO_VOO)):
			_mapa[outra] = antigo
	_mapa[acao] = novo
	return trocadas()

# qual ação usa este código ("" se nenhuma)
static func acao_da_tecla(c: String) -> String:
	if _mapa.is_empty():
		carregar({})
	for a in ACOES:
		if _mapa.get(a[0]) == c:
			return a[0]
	return ""

static func trocadas() -> Dictionary:
	var d := {}
	for a in ACOES:
		if _mapa.get(a[0], a[2]) != a[2]:
			d[a[0]] = _mapa[a[0]]
	return d
