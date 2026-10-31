extends RefCounted
# =====================================================================================================================
# BLOCO DE DESENVOLVIMENTO · MODO DESENVOLVEDOR (1.09) — REMOVER NA VERSÃO FINAL
# Para tirar: apague a pasta dev/ inteira. O chat (hud/chat.gd) só carrega este arquivo se ele existir; sem ele o
# chat continua normal e "INFINITYDEV" vira uma mensagem comum. Nada mais no jogo depende daqui.
# ---------------------------------------------------------------------------------------------------------------------
# Escreva INFINITYDEV no chat e envie: liga o modo (fica ligado neste aparelho, em user://dev.cfg, até /devoff).
# Ligado, começar com "/" mostra a LISTA DE COMANDOS (como no Minecraft): vai filtrando enquanto você escreve, mostra
# o jeito de usar e, depois do nome do comando, as opções de cada parte (itens, locais, tipos de infectado...).
# Toque/clique numa linha preenche; Tab completa a primeira. Os comandos e as respostas não vão para a rede.
# No multijogador, os que mexem no MUNDO (hora, clima, infectados...) só valem no host (ou no jogo solo).
# Mexa AQUI para: os comandos (lista COMANDOS + uma função _c_<nome> para cada um), os kits e a senha.
# =====================================================================================================================

const SENHA := "INFINITYDEV"
const ARQ := "user://dev.cfg"
const Itens := preload("res://inventario/itens.gd")
const ItemCls := preload("res://inventario/item.gd")
const Locais := preload("res://mundo/locais.gd")
const ModeloInfectado := preload("res://inimigos/modelo_infectado.gd")
const VeiculoCls := preload("res://mundo/veiculo.gd")

# [nome, como usar, o que faz, só no host/solo (mexe no mundo)]
const COMANDOS := [
	["ajuda", "/ajuda [comando]", "lista os comandos (ou explica um)", false],
	["dar", "/dar <item> [quantidade]", "põe um item no inventário (sem lugar: no chão)", false],
	["itens", "/itens [filtro]", "lista os ids dos itens (filtra pelo nome ou id)", false],
	["kit", "/kit <armas|medico|comida|militar|ferramentas>", "um conjunto de itens pronto", false],
	["municao", "/municao", "enche a arma na mão e dá munição e pentes dela", false],
	["dinheiro", "/dinheiro <valor>", "dá dólares", false],
	["cartao", "/cartao <1-4>", "dá o cartão de acesso de um bunker", false],
	["curar", "/curar", "vida, sangue, fome, sede, frio, doenças, perna e sangramentos", false],
	["deus", "/deus", "imortal liga/desliga", false],
	["perna", "/perna", "quebra/conserta a perna (para testar)", false],
	["tp", "/tp <x> <z> · /tp <tipo de local> [nº] · /tp comboio [nº]", "teleporta", false],
	["locais", "/locais [tipo]", "lista os locais especiais com o número de cada", false],
	["comboio", "/comboio [nº]", "vai até um comboio do Exército (sem nº: o mais perto)", false],
	["pos", "/pos", "mostra onde você está", false],
	["voo", "/voo", "câmera livre (voar) liga/desliga", false],
	["fps", "/fps", "contador de FPS e posição na tela liga/desliga", false],
	["gasolina", "/gasolina", "enche o tanque do veículo que você dirige", false],
	["salvar", "/salvar", "salva o jogo agora", false],
	["hora", "/hora <0-24>", "muda a hora do dia", true],
	["dia", "/dia", "meio-dia", true],
	["noite", "/noite", "meia-noite", true],
	["congelar", "/congelar", "para/solta a passagem do tempo", true],
	["clima", "/clima <limpo|nublado|chuva|tempestade>", "muda o tempo na hora", true],
	["tempo", "/tempo <0.1-4>", "velocidade do jogo (1 = normal; só no solo)", true],
	["infectados", "/infectados <on|off>", "liga/desliga os infectados", true],
	["matar", "/matar [raio]", "mata os infectados perto (padrão 50 m)", true],
	["spawn", "/spawn [quantos] [lento|rapido|corredor|rastejante|mutado|soldado]", "cria infectados na sua frente", true],
	["horda", "/horda", "o Diretor solta uma horda agora", true],
	["diretor", "/diretor", "mostra o estado do Diretor de IA", false],
	["limpar", "/limpar", "limpa o chat", false],
	["devoff", "/devoff", "desliga o modo desenvolvedor", false],
]
const KITS := {
	"armas": [["m4", 1], ["pente_stanag", 2], ["mun_556", 60], ["pistola", 1], ["pente_pistola", 1], ["mun_9mm", 30], ["mira_acog", 1]],
	"medico": [["kit_medico", 1], ["bandagem", 3], ["antibiotico", 1], ["soro", 1], ["analgesico", 1]],
	"comida": [["feijao", 2], ["agua", 2], ["barra", 3]],
	"militar": [["colete", 1], ["capacete", 1], ["mochila_combate", 1], ["mascara_gas", 1]],
	"ferramentas": [["martelo", 1], ["pe_de_cabra", 1], ["tabuas", 6], ["galao", 1], ["lanterna", 1], ["pilha", 2]],
}
const TEMPOS := ["limpo", "nublado", "chuva", "tempestade"]
const TIPOS_INFECTADO := ["lento", "rapido", "corredor", "rastejante", "mutado", "soldado"]

var chat = null                        # hud/chat.gd
var main = null                        # main.gd
var ativo := false
var manter_aberto := false             # listas longas: o chat fica aberto para ler

func _init() -> void:
	var cf := ConfigFile.new()
	if cf.load(ARQ) == OK:
		ativo = bool(cf.get_value("dev", "ativo", false))

func _gravar() -> void:
	var cf := ConfigFile.new()
	cf.set_value("dev", "ativo", ativo)
	cf.save(ARQ)

# o chat chama com tudo o que é enviado; true = era para cá (não vai para a rede)
func tratar(t: String) -> bool:
	manter_aberto = false
	if t.strip_edges().to_upper() == SENHA:
		ativo = true
		_gravar()
		_diz("MODO DESENVOLVEDOR LIGADO. Escreva / para ver os comandos (/devoff desliga).")
		return true
	if not ativo or not t.begins_with("/"):
		return false
	var partes := t.substr(1).strip_edges().split(" ", false)
	if partes.is_empty():
		return true
	var nome := partes[0].to_lower()
	var args: Array = Array(partes.slice(1))
	var c := _comando(nome)
	if c.is_empty():
		_erro("Comando desconhecido: /%s (escreva / para ver a lista)" % nome)
		return true
	if bool(c[3]) and not _manda_no_mundo():
		_erro("/%s mexe no mundo: no multijogador só o host pode." % nome)
		return true
	if main == null or main.jogador == null:
		_erro("Só dentro do jogo.")
		return true
	call("_c_" + nome, args)
	return true

# ---------- a lista (como no Minecraft) ----------
# [texto que preenche o campo, como usar, descrição]
func sugestoes(t: String) -> Array:
	var r: Array = []
	var s := t.substr(1)
	if not s.contains(" "):
		for c in COMANDOS:
			if String(c[0]).begins_with(s.to_lower()):
				r.append(["/%s " % c[0], c[1], c[2] + (" · só host" if bool(c[3]) else "")])
		return r
	var partes := s.split(" ", false)
	var c := _comando(partes[0].to_lower())
	if c.is_empty():
		return r
	r.append([t, c[1], c[2]])
	# a parte que está sendo escrita agora e as opções para ela
	var n_arg := partes.size() - 1 if not s.ends_with(" ") else partes.size()
	var parcial := "" if s.ends_with(" ") else String(partes[partes.size() - 1]).to_lower()
	var antes := "/" + " ".join(partes.slice(0, n_arg + 1 if s.ends_with(" ") else n_arg)) + " "
	if n_arg >= 1:
		for o in _opcoes(String(c[0]), n_arg - 1, partes):
			if String(o[0]).to_lower().begins_with(parcial):
				r.append([antes + String(o[0]) + " ", String(o[0]), String(o[1])])
	return r

func _opcoes(cmd: String, i: int, partes: Array) -> Array:
	var o: Array = []
	match cmd:
		"dar":
			if i == 0:
				var ids: Array = Itens.DB.keys()
				ids.sort()
				for id in ids:
					o.append([id, str(Itens.DB[id].get("nome", ""))])
			elif i == 1:
				for q in ["1", "5", "10", "30", "60"]:
					o.append([q, "quantidade"])
		"kit":
			if i == 0:
				for k in KITS:
					o.append([k, ", ".join(KITS[k].map(func(p): return p[0]))])
		"tp", "locais":
			if i == 0:
				for tp in _tipos_locais():
					o.append([tp, "%d no mapa" % _do_tipo(tp).size()])
				if cmd == "tp":
					o.append(["comboio", "comboios do Exército"])
			elif i == 1 and partes.size() > 1:
				var tp := String(partes[1]).to_lower()
				var n: int = _centros_comboio().size() if tp == "comboio" else _do_tipo(tp).size()
				for k in n:
					o.append([str(k + 1), _nome_local(tp, k)])
		"comboio":
			if i == 0:
				for k in _centros_comboio().size():
					o.append([str(k + 1), "comboio %d" % (k + 1)])
		"cartao":
			if i == 0:
				for k in 4:
					o.append([str(k + 1), "bunker %d" % (k + 1)])
		"clima":
			if i == 0:
				for tp in TEMPOS:
					o.append([tp, "tempo"])
		"hora":
			if i == 0:
				for h in ["0", "6", "12", "18", "21"]:
					o.append([h, "horas"])
		"tempo":
			if i == 0:
				for x in ["0.25", "0.5", "1", "2", "4"]:
					o.append([x, "x a velocidade"])
		"infectados":
			if i == 0:
				o.append(["on", "liga"])
				o.append(["off", "desliga"])
		"spawn":
			if i == 0:
				for q in ["1", "5", "10", "20"]:
					o.append([q, "quantos"])
			elif i == 1:
				for tp in TIPOS_INFECTADO:
					o.append([tp, "tipo"])
		"matar":
			if i == 0:
				for q in ["20", "50", "100", "300"]:
					o.append([q, "metros"])
		"ajuda":
			if i == 0:
				for c in COMANDOS:
					o.append([c[0], c[2]])
	return o

# ---------- comandos ----------
func _c_ajuda(a: Array) -> void:
	manter_aberto = true
	if not a.is_empty():
		var c := _comando(String(a[0]).to_lower())
		if c.is_empty():
			_erro("Não existe /%s" % a[0])
		else:
			_diz("%s — %s%s" % [c[1], c[2], " (só host/solo)" if bool(c[3]) else ""])
		return
	_diz("COMANDOS (%d): escreva / e o começo do nome para filtrar" % COMANDOS.size())
	for c in COMANDOS:
		_diz("%s — %s" % [c[1], c[2]])

func _c_dar(a: Array) -> void:
	if a.is_empty():
		_erro("Use: /dar <item> [quantidade] (ex.: /dar m4)")
		return
	var id := String(a[0]).to_lower()
	if not Itens.DB.has(id):
		_erro("Item não existe: %s (veja /itens)" % id)
		return
	var q := maxi(1, int(a[1])) if a.size() > 1 else 1
	var n := _dar(id, q)
	_diz("Recebeu %d x %s" % [n, str(Itens.DB[id].get("nome", id))])

func _c_itens(a: Array) -> void:
	manter_aberto = true
	var f := String(a[0]).to_lower() if not a.is_empty() else ""
	var ids: Array = Itens.DB.keys()
	ids.sort()
	var lista: Array = []
	for id in ids:
		var nome := str(Itens.DB[id].get("nome", "")).to_lower()
		if f == "" or String(id).contains(f) or nome.contains(f):
			lista.append(id)
	_diz("%d itens%s:" % [lista.size(), (" com \"%s\"" % f) if f != "" else ""])
	for k in range(0, lista.size(), 8):
		_diz(", ".join(lista.slice(k, k + 8)))

func _c_kit(a: Array) -> void:
	var k := String(a[0]).to_lower() if not a.is_empty() else ""
	if not KITS.has(k):
		_erro("Kits: " + ", ".join(KITS.keys()))
		return
	for p in KITS[k]:
		if Itens.DB.has(p[0]):
			_dar(p[0], p[1])
	_diz("Kit %s entregue." % k)

func _c_municao(_a: Array) -> void:
	var ar = main.jogador.get("armas")
	if ar == null or ar.item_arma == null or ar.eh_corpo():
		_erro("Pegue uma arma de fogo na mão.")
		return
	var d: Dictionary = ar.item_arma.def()
	ar.item_arma.municao = ar.capacidade()
	if ar.has_method("_invalidar_estado"):
		ar._invalidar_estado()
	var mun := str(d.get("municao", ""))
	if mun != "" and Itens.DB.has(mun):
		_dar(mun, 60)
	var pente: String = ar.item_arma.usa_pente()
	if pente != "" and Itens.DB.has(pente):
		_dar(pente, 2)
	_diz("Arma cheia, mais munição%s." % (" e 2 pentes" if pente != "" else ""))

func _c_dinheiro(a: Array) -> void:
	var v := int(a[0]) if not a.is_empty() else 0
	if v <= 0:
		_erro("Use: /dinheiro <valor>")
		return
	_dar("dinheiro", v)
	_diz("Recebeu US$ %d" % v)

func _c_cartao(a: Array) -> void:
	var n := int(a[0]) if not a.is_empty() else 0
	var id := "cartao_bunker_%d" % n
	if not Itens.DB.has(id):
		_erro("Use: /cartao <1-4>")
		return
	_dar(id, 1)
	_diz("Recebeu o cartão do bunker %d." % n)

func _c_curar(_a: Array) -> void:
	var s = main.jogador.sobrevivencia
	var valores := {"vida": 100.0, "sangue": 5000.0, "fome": 100.0, "sede": 100.0, "temperatura": 36.6, "infeccao": 0.0,
		"sangramentos": 0, "perna_quebrada": false, "gripe": 0.0, "colera": 0.0}
	for k in valores:
		if k in s:
			s.set(k, valores[k])
	if "estamina" in s:
		s.estamina = s.estamina_max
	_diz("Curado.")

func _c_deus(_a: Array) -> void:
	var s = main.jogador.sobrevivencia
	s.imortal = not s.imortal
	_diz("Imortal: %s" % ("LIGADO" if s.imortal else "desligado"))

func _c_perna(_a: Array) -> void:
	var s = main.jogador.sobrevivencia
	s.perna_quebrada = not s.perna_quebrada
	_diz("Perna quebrada: %s" % ("SIM" if s.perna_quebrada else "não"))

func _c_tp(a: Array) -> void:
	if a.is_empty():
		_erro("Use: /tp <x> <z> · /tp <tipo> [nº] · /tp comboio [nº]")
		return
	var t := String(a[0]).to_lower()
	if t.is_valid_float() and a.size() > 1 and String(a[1]).is_valid_float():
		_ir(Vector2(float(a[0]), float(a[1])))
		return
	if t == "comboio":
		_c_comboio(a.slice(1))
		return
	var lista := _do_tipo(t)
	if lista.is_empty():
		_erro("Não conheço \"%s\". Tipos: %s" % [t, ", ".join(_tipos_locais())])
		return
	var n := clampi(int(a[1]) if a.size() > 1 else 1, 1, lista.size())
	var i: int = lista[n - 1]
	var tam: Vector2 = Locais.TAMANHO[t]
	_ir(Locais.local_para_mundo(i, Vector2(0, tam.y * 0.5 + 5.0)))
	_diz("Foi para %s (%d de %d)." % [_nome_local(t, n - 1), n, lista.size()])

func _c_locais(a: Array) -> void:
	manter_aberto = true
	var f := String(a[0]).to_lower() if not a.is_empty() else ""
	var p: Vector3 = main.jogador.global_position
	for tp in _tipos_locais():
		if f != "" and tp != f:
			continue
		var l := _do_tipo(tp)
		var partes: Array = []
		for k in l.size():
			var e: Array = Locais.LOCAIS[l[k]]
			partes.append("%d (%d m)" % [k + 1, int(Vector2(e[1], e[2]).distance_to(Vector2(p.x, p.z)))])
		_diz("%s: %s" % [tp, ", ".join(partes)])

func _c_comboio(a: Array) -> void:
	var cs := _centros_comboio()
	if cs.is_empty():
		_erro("Nenhum comboio no mapa.")
		return
	var k := 0
	if not a.is_empty() and int(a[0]) >= 1:
		k = clampi(int(a[0]) - 1, 0, cs.size() - 1)
	else:
		var p: Vector3 = main.jogador.global_position
		var md := INF
		for i in cs.size():
			var d := (cs[i][0] as Vector3).distance_to(p)
			if d < md:
				md = d
				k = i
	var c: Vector3 = cs[k][0]
	var n: Vector3 = cs[k][2]
	_ir(Vector2(c.x + n.x * 6.0, c.z + n.z * 6.0))
	_diz("Comboio %d de %d." % [k + 1, cs.size()])

func _c_pos(_a: Array) -> void:
	var p: Vector3 = main.jogador.global_position
	var i := Locais.em(Vector2(p.x, p.z), 20.0)
	_diz("x %.1f · y %.1f · z %.1f%s" % [p.x, p.y, p.z, (" · em: " + Locais.nome(i)) if i >= 0 else ""])

func _c_voo(_a: Array) -> void:
	if main.get("voo") != null:
		main.voo.alternar()
		_diz("Câmera livre: %s" % ("LIGADA" if main.voo.ativo else "desligada"))

func _c_fps(_a: Array) -> void:
	var c = main.controles
	c.set_info(not c.mostrar_info)
	_diz("FPS na tela: %s" % ("sim" if c.mostrar_info else "não"))

func _c_gasolina(_a: Array) -> void:
	var v = main.veiculos.dirigindo if main.get("veiculos") != null else null
	if v == null:
		_erro("Entre num veículo primeiro.")
		return
	v.combustivel = VeiculoCls.TANQUE
	_diz("Tanque cheio.")

func _c_salvar(_a: Array) -> void:
	main.salvar_jogo()
	_diz("Jogo salvo.")

func _c_hora(a: Array) -> void:
	if a.is_empty() or not String(a[0]).is_valid_float():
		_erro("Use: /hora <0-24>")
		return
	main.clima.hora = fposmod(float(a[0]), 24.0)
	_diz("Hora: %.1f" % main.clima.hora)

func _c_dia(_a: Array) -> void:
	main.clima.hora = 12.0
	_diz("Meio-dia.")

func _c_noite(_a: Array) -> void:
	main.clima.hora = 0.0
	_diz("Meia-noite.")

func _c_congelar(_a: Array) -> void:
	main.clima.parado = not main.clima.parado
	_diz("Tempo %s." % ("PARADO" if main.clima.parado else "andando"))

func _c_clima(a: Array) -> void:
	var t := String(a[0]).to_lower() if not a.is_empty() else ""
	if not t in TEMPOS:
		_erro("Use: /clima <%s>" % "|".join(TEMPOS))
		return
	main.clima.forcar_tempo(t, true)
	_diz("Clima: %s" % t)

func _c_tempo(a: Array) -> void:
	var r = Engine.get_main_loop().root.get_node_or_null("/root/Rede")
	if r != null and bool(r.get("ligado")):
		_erro("/tempo só no jogo solo.")
		return
	var x := clampf(float(a[0]) if not a.is_empty() else 1.0, 0.1, 4.0)
	Engine.time_scale = x
	_diz("Velocidade do jogo: %.2fx" % x)

func _c_infectados(a: Array) -> void:
	var v := String(a[0]).to_lower() if not a.is_empty() else ""
	if not v in ["on", "off"]:
		_erro("Use: /infectados <on|off>")
		return
	main.vagos.ativo = v == "on"
	_diz("Infectados: %s" % ("ligados" if v == "on" else "DESLIGADOS (os que já estão aí continuam: /matar)"))

func _c_matar(a: Array) -> void:
	var r := float(a[0]) if not a.is_empty() and String(a[0]).is_valid_float() else 50.0
	var p: Vector3 = main.jogador.global_position
	var n := 0
	for v in main.vagos.vivos.duplicate():
		if is_instance_valid(v) and v.global_position.distance_to(p) <= r:
			v.receber_tiro(99999.0, v.global_position + Vector3(0, 1.6, 0), Vector3.DOWN, 1, null)
			n += 1
	_diz("%d infectados mortos (até %d m)." % [n, int(r)])

func _c_spawn(a: Array) -> void:
	var q := clampi(int(a[0]) if not a.is_empty() else 1, 1, 50)
	var tp := String(a[1]).to_lower() if a.size() > 1 else ""
	if tp != "" and not tp in TIPOS_INFECTADO:
		_erro("Tipos: " + ", ".join(TIPOS_INFECTADO))
		return
	var j = main.jogador
	var yaw: float = j.cam_yaw
	var frente := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var n := 0
	for k in q:
		var p: Vector3 = j.global_position + frente * randf_range(6.0, 10.0) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		p.y = main.mundo.altura(p.x, p.z) + 0.05
		var classe := tp if tp != "soldado" else ""
		var semente: int = ModeloInfectado.semente_soldado() if tp == "soldado" else -1
		if main.vagos._criar(p, Vector3.INF, false, classe, semente) != null:
			n += 1
	_diz("%d infectado(s) %s na sua frente." % [n, tp if tp != "" else "comum(ns)"])

func _c_horda(_a: Array) -> void:
	var d = main.vagos.get("diretor")
	if d == null or not d.soltar_horda(main.jogador):
		_erro("A horda não achou lugar para vir agora. Tente em outro ponto.")
		return
	_diz("HORDA a caminho.")

func _c_diretor(_a: Array) -> void:
	var d = main.vagos.get("diretor")
	_diz("Diretor: " + (d.estado_texto() if d != null else "(sem Diretor)"))

func _c_limpar(_a: Array) -> void:
	chat.limpar()

func _c_devoff(_a: Array) -> void:
	ativo = false
	_gravar()
	_diz("Modo desenvolvedor DESLIGADO.")

# ---------- ajudantes ----------
func _comando(nome: String) -> Array:
	for c in COMANDOS:
		if c[0] == nome:
			return c
	return []

func _manda_no_mundo() -> bool:
	var r = Engine.get_main_loop().root.get_node_or_null("/root/Rede")
	return r == null or not bool(r.get("ligado")) or r.eh_host()

func _dar(id: String, q: int) -> int:
	var inv = main.jogador.inventario
	var mx := maxi(1, int(Itens.def(id).get("max", 1)))
	var dado := 0
	while q > 0:
		var n := mini(q, mx)
		var it = ItemCls.novo(id, n)
		if it == null:
			break
		inv._guardar_ou_largar(it)
		dado += n
		q -= n
	if inv.has_method("_depois"):
		inv._depois()
	return dado

func _ir(p: Vector2) -> void:
	main.mundo.forcar(p)
	var y: float = main.mundo.altura(p.x, p.y)
	main.jogador.teleportar(Vector3(p.x, y + 0.3, p.y), main.jogador.cam_yaw)
	main.jogador.velocity = Vector3.ZERO

func _tipos_locais() -> Array:
	var r: Array = []
	for e in Locais.LOCAIS:
		if not e[0] in r:
			r.append(e[0])
	return r

func _do_tipo(t: String) -> Array:
	var r: Array = []
	for i in Locais.LOCAIS.size():
		if Locais.LOCAIS[i][0] == t:
			r.append(i)
	return r

func _nome_local(t: String, k: int) -> String:
	return "%s %d" % [str(Locais.NOMES.get(t, t.to_upper())), k + 1]

func _centros_comboio() -> Array:
	var c = main.cidade.get("abandono") if main != null and main.cidade != null else null
	return c.centros_comboio if c != null else []

func _diz(t: String) -> void:
	if chat != null:
		chat.sistema(t)

func _erro(t: String) -> void:
	if chat != null:
		chat.sistema("✕ " + t)
