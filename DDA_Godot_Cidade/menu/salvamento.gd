extends RefCounted
# JOGO SALVO (user://save.json): onde o jogador está, vida/fome/sede..., tudo o que ele carrega, a hora e o tempo,
# o que já foi saqueado nos prédios/carros (mundo/loot_mundo.gd) e os itens largados no chão.
# Salva sozinho a cada 2 minutos, ao pausar, ao voltar ao menu e quando o celular sai do jogo.
# No menu principal aparece "Continuar" quando existe um jogo salvo.
# 0.77 · MULTIJOGADOR (separado: não mexe no jogo salvo sozinho): cada aparelho guarda o seu PERSONAGEM da partida em
# rede (o que carrega, vida/fome/sede..., abates); o HOST guarda também o MUNDO (semente do loot, o que foi saqueado e
# pego do chão, portas, carros, hora/tempo). 1.03: VÁRIOS MUNDOS com nome (como no Minecraft): um arquivo por mundo
# (menu/mundos_rede.gd), o personagem é de cada mundo e volta para onde estava.
# Mexa AQUI para: o que é salvo (e a versão do arquivo, se mudar o formato).

const ItemCls := preload("res://inventario/item.gd")
const ItemMundoCls := preload("res://inventario/item_mundo.gd")

const ARQUIVO := "user://save.json"
const VERSAO := 1
const MAX_CHAO := 300                 # itens largados no chão guardados (os mais perto do jogador)

static func existe() -> bool:
	return FileAccess.file_exists(ARQUIVO)

# texto curto para o botão "Continuar" ("" = não tem jogo salvo)
static func resumo() -> String:
	var d := ler()
	if d.is_empty():
		return ""
	var s := int(d.get("tempo_jogo", 0.0))
	var h := float(d.get("clima", {}).get("hora", 8.0))
	return "Dia %d · %02d:%02d · %d min jogados" % [int(d.get("clima", {}).get("dia", 1)), int(h), int(fmod(h, 1.0) * 60.0), s / 60]

static func ler() -> Dictionary:
	if not existe():
		return {}
	var f := FileAccess.open(ARQUIVO, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary) or int(d.get("versao", 0)) != VERSAO:
		return {}
	return d

static func apagar() -> void:
	if existe():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))

# main = main.gd com o jogo rodando
# morto = true: grava a morte (os itens ficaram no chão) para "Continuar" não desfazer a morte
static func salvar(main, morto := false) -> bool:
	var j = main.jogador
	if j == null or not is_instance_valid(j) or (j.morto and not morto):
		return false
	var p: Vector3 = j.global_position
	var d := {
		"versao": VERSAO,
		"tempo_jogo": main._tempo_jogo,
		"abates": main.abates,
		"jogador": {"x": p.x, "y": p.y, "z": p.z, "yaw": j.cam_yaw},
		"sobrevivencia": j.sobrevivencia.salvar(),
		"inventario": j.inventario.salvar(),
		"morto": morto,
		"loot": main.loot_mundo.salvar(main.interiores.abertos if main.interiores != null else {},
			main.locais.abertos if main.get("locais") != null else {}) if main.loot_mundo != null else {},
		"clima": main.clima.salvar() if main.clima != null and main.clima.has_method("salvar") else {},
		"missoes": main.missoes.salvar() if main.get("missoes") != null else {},
		"vagos": main.vagos.salvar() if main.get("vagos") != null else {},              # 0.90: a horda da cidade
		"construcao": main.construcao.salvar() if main.get("construcao") != null else {},   # 0.90: a base
		"hospitais": main.hospitais.salvar_personagem() if main.get("hospitais") != null else {},   # 0.91: loja e trégua
		"trocas": main.hospitais.trocas.salvar() if main.get("hospitais") != null else {},   # 0.91: trocas com o rádio
		"chao": _chao(main, p),
		"mapa_predios": MAPA_PREDIOS,
	}
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true

# NUMERAÇÃO DOS PRÉDIOS: a 0.43 tirou os prédios em cima da água/rua (mundo/cidade.gd _predio_ruim) e os
# números mudaram. O loot dos prédios é salvo por número ("p12" = chão do prédio 12, "p12_3" = móvel 3 dele):
# save de antes (sem "mapa_predios") é convertido com cidade.remapa_predios (número antigo -> novo; -1 = sumiu).
# A 0.68 tirou os prédios que ficavam nos terrenos dos locais especiais (mundo/locais.gd): save da 0.43..0.67
# ("mapa_predios" = 2) é convertido com cidade.remapa_v2.
# A 0.78 tirou os prédios dos terrenos dos locais NOVOS (delegacias, escolas, metrôs): save da 0.68..0.77
# ("mapa_predios" = 3) é convertido com cidade.remapa_v3 (também o do multijogador, que não tinha o número).
const MAPA_PREDIOS := 4

# id de algo de um prédio ("p12", "p12_3", "p12:3") com o número trocado pelo novo ("" = o prédio sumiu);
# ids que não são de prédio (carros "c..", locais "L..") voltam iguais
static func _remapear_id(s: String, remapa: PackedInt32Array) -> String:
	if not s.begins_with("p") or not s.substr(1, 1).is_valid_int():
		return s
	var k := 1
	while k < s.length() and s.substr(k, 1).is_valid_int():
		k += 1
	var i := int(s.substr(1, k - 1))
	if i < 0 or i >= remapa.size() or remapa[i] < 0:
		return ""
	return "p%d%s" % [remapa[i], s.substr(k)]

static func _remapear_loot(loot: Dictionary, remapa: PackedInt32Array) -> Dictionary:
	var o := loot.duplicate(true)
	for parte in ["grades", "chao", "ciclos", "ciclos_chao", "portas"]:
		var velho: Dictionary = loot.get(parte, {})
		var novo := {}
		for id in velho:
			var n := _remapear_id(String(id), remapa)
			if n != "":                               # prédio removido: o loot dele some
				novo[n] = velho[id]
		o[parte] = novo
	return o

# a tabela certa para converter um save com essa versão do mapa (vazia = não precisa)
static func _remapa_de(main, versao_mapa: int) -> PackedInt32Array:
	if versao_mapa < 2:
		return main.cidade.remapa_predios
	if versao_mapa < 3:
		return main.cidade.remapa_v2
	if versao_mapa < MAPA_PREDIOS:
		return main.cidade.remapa_v3
	return PackedInt32Array()

# itens largados pelo jogador (filhos do nó Jogo; os dos prédios ficam no loot_mundo)
static func _chao(main, p: Vector3) -> Array:
	var lista := []
	for n in main.jogo.get_children():
		if n.is_in_group("itens_chao") and not n.is_queued_for_deletion() and n.item != null:
			var q: Vector3 = n.global_position
			lista.append([q.distance_squared_to(p), [n.item.para_dict(), q.x, q.y, q.z]])
	lista.sort_custom(func(a, b): return a[0] < b[0])
	var r := []
	for k in mini(lista.size(), MAX_CHAO):
		r.append(lista[k][1])
	return r

# chamado logo depois de _criar_jogo (o jogo novo já existe; aqui ele vira o salvo)
static func carregar(main, d: Dictionary) -> void:
	var j = main.jogador
	main._tempo_jogo = float(d.get("tempo_jogo", 0.0))
	main.abates = int(d.get("abates", 0))
	if main.loot_mundo != null:
		var loot: Dictionary = d.get("loot", {})
		var remapa := _remapa_de(main, int(d.get("mapa_predios", 1)))
		if not remapa.is_empty():
			loot = _remapear_loot(loot, remapa)
		main.loot_mundo.carregar(loot)
		if main.get("veiculos") != null:
			main.veiculos.sincronizar()           # 0.76: carros já mexidos (some o largado original)
	j.inventario.carregar(d.get("inventario", {}))
	j.sobrevivencia.carregar(d.get("sobrevivencia", {}))
	if main.clima != null and main.clima.has_method("carregar") and d.has("clima"):
		main.clima.carregar(d["clima"])
	# tira o loot de teste da base (já foi pego/mexido no jogo salvo) e põe os itens largados
	for n in main.jogo.get_children():
		if n.is_in_group("itens_chao"):
			n.free()
		elif n.is_in_group("conteineres_mundo") and n.grade != null:
			n.grade.itens.clear()
	for e in d.get("chao", []):
		var it = ItemCls.de_dict(e[0])
		if it != null:
			ItemMundoCls.soltar(main.jogo, it, Vector3(e[1], e[2], e[3]))
	var jd: Dictionary = d.get("jogador", {})
	if not jd.is_empty():
		var pos := Vector3(float(jd["x"]), float(jd["y"]), float(jd["z"]))
		main.mundo.forcar(Vector2(pos.x, pos.z))
		if main.interiores != null:
			main.interiores.abrir_agora(Vector2(pos.x, pos.z))     # se salvou dentro de um prédio
		if main.get("locais") != null:
			main.locais.abrir_agora(Vector2(pos.x, pos.z))         # ou dentro de um local especial (0.68)
		j.teleportar(pos + Vector3(0, 0.05, 0), float(jd.get("yaw", 0.0)))
	if main.get("missoes") != null and d.has("missoes"):
		main.missoes.carregar(d["missoes"])
	if main.get("vagos") != null and d.has("vagos"):
		main.vagos.carregar(d["vagos"])
	if main.get("construcao") != null and d.has("construcao"):
		main.construcao.carregar(d["construcao"])
	if main.get("hospitais") != null and d.has("hospitais"):
		main.hospitais.carregar_personagem(d["hospitais"])
	if main.get("hospitais") != null and d.has("trocas"):
		main.hospitais.trocas.carregar(d["trocas"])

# ================= 0.77: PARTIDA EM REDE · 1.03: um arquivo por MUNDO (menu/mundos_rede.gd) =================
const MundosRede := preload("res://menu/mundos_rede.gd")

# 1.03: voltou o lugar onde o personagem estava nesse mundo (main.gd _ligar_rede não põe ele na base)
static var posicao_voltou := false
static var _id_partida := ""          # o mundo da partida em andamento (a conexão cai e Rede.mundo some)

# o mundo desta partida: o id que o host mandou (rede/rede.gd mundo["mundo_id"]); host de versão sem mundos = pelo nome
static func id_mundo_atual() -> String:
	var rede = Engine.get_main_loop().root.get_node_or_null("/root/Rede") if Engine.get_main_loop() is SceneTree else null
	if rede == null:
		return ""
	var id := str(rede.mundo.get("mundo_id", ""))
	if id == "" and rede.has_method("eh_cliente") and rede.eh_cliente():
		id = "sala_" + str(rede.get("_host_nome")).to_lower().validate_filename().left(20)
	if id == "" and not rede.ligado:
		id = _id_partida
	return id

# salva o personagem (todos) e o mundo (só o host). morto = morreu: o personagem volta do zero
static func salvar_rede(main, morto := false) -> bool:
	var j = main.jogador
	if j == null or not is_instance_valid(j) or (j.morto and not morto):
		return false
	var rede = main.get_node_or_null("/root/Rede")
	var id := id_mundo_atual()
	if rede == null or id == "":
		return false
	var d := MundosRede.ler(id)
	if d.is_empty() and not rede.ligado:
		return false                         # (sem conexão e sem o arquivo: não inventa um mundo)
	if d.is_empty():
		d = {"id": id, "meu": rede.eh_host(), "nome": str(rede.mundo.get("mundo_nome", "")), "criado": int(Time.get_unix_time_from_system())}
	if not bool(d.get("meu", false)) and rede.ligado:
		d["nome"] = str(rede.mundo.get("mundo_nome", d.get("nome", "")))
		d["host"] = str(rede.get("_host_nome"))
	d["jogado"] = int(Time.get_unix_time_from_system())
	if not bool(j.get("servidor")):          # o "jogador" do servidor do PC não é gente
		var p: Vector3 = j.global_position
		d["personagem"] = {"sobrevivencia": j.sobrevivencia.salvar(), "inventario": j.inventario.salvar(),
			"abates": main.abates, "tempo_jogo": main._tempo_jogo, "morto": morto,
			"pos": [] if morto else [p.x, p.y, p.z, j.cam_yaw],                                         # 1.03: onde estava
			"cama": main.construcao.minha_cama if main.get("construcao") != null and not morto else "",   # 0.90: a sua cama na base
			"hospitais": main.hospitais.salvar_personagem() if main.get("hospitais") != null else {}}     # 0.91: loja e trégua
		d["minutos"] = int(main._tempo_jogo / 60.0)
	if rede.eh_host() and main.loot_mundo != null:
		var lm = main.loot_mundo
		d["meu"] = true
		d["semente"] = lm.semente
		var clima: Dictionary = main.clima.salvar() if main.clima != null and main.clima.has_method("salvar") else {}
		d["dia"] = int(clima.get("dia", d.get("dia", 1)))
		d["mundo"] = {"semente": lm.semente,
			"loot": lm.salvar(main.interiores.abertos if main.interiores != null else {}, main.locais.abertos if main.get("locais") != null else {}),
			"pegos": lm.pegos.keys(),
			"mapa_predios": MAPA_PREDIOS,
			"clima": clima,
			"vagos": main.vagos.salvar() if main.get("vagos") != null else {},
			"construcao": main.construcao.salvar() if main.get("construcao") != null else {},
			"trocas": main.hospitais.trocas.salvar() if main.get("hospitais") != null else {}}   # 0.91: o que está com o Lucas
	return MundosRede.gravar(d)

# ao começar a partida em rede (main.gd _ligar_rede): o personagem volta; o host continua o mundo salvo
static func carregar_rede(main) -> String:
	posicao_voltou = false
	var id := id_mundo_atual()
	_id_partida = id
	var d := MundosRede.ler(id)
	var avisos := PackedStringArray()
	var j = main.jogador
	var pj: Dictionary = d.get("personagem", {})
	var rede = main.get_node_or_null("/root/Rede")
	if pj.is_empty() and rede != null and rede.eh_cliente():
		pj = MundosRede.pegar_personagem_antigo()      # quem vinha da 1.02: o personagem de antes vai para este mundo
	if not pj.is_empty() and not bool(pj.get("morto", false)) and not bool(j.get("servidor")):
		j.inventario.carregar(pj.get("inventario", {}))
		j.sobrevivencia.carregar(pj.get("sobrevivencia", {}))
		main.abates = int(pj.get("abates", 0))
		main._tempo_jogo = float(pj.get("tempo_jogo", 0.0))
		avisos.append("SEU PERSONAGEM NESTE MUNDO VOLTOU")
	var m: Dictionary = d.get("mundo", {})
	if rede != null and rede.eh_host() and not m.is_empty() and main.loot_mundo != null and int(m.get("semente", -1)) == main.loot_mundo.semente:
		var remapa := _remapa_de(main, int(m.get("mapa_predios", 3)))      # o da 0.77 não tinha o número: era o 3
		var loot: Dictionary = m.get("loot", {})
		if not remapa.is_empty():
			loot = _remapear_loot(loot, remapa)
		main.loot_mundo.carregar(loot)
		main.loot_mundo.semente = int(m["semente"])
		for u in m.get("pegos", []):
			var uid := _remapear_id(str(u), remapa) if not remapa.is_empty() else str(u)
			if uid != "":
				main.loot_mundo.pegos[uid] = true
		if main.clima != null and m.has("clima"):
			main.clima.carregar(m["clima"])
		if main.get("vagos") != null and m.has("vagos"):
			main.vagos.carregar(m["vagos"])
		if main.get("construcao") != null and m.has("construcao"):
			main.construcao.carregar(m["construcao"])
		if main.get("hospitais") != null and m.has("trocas"):
			main.hospitais.trocas.carregar(m["trocas"])
		if main.get("veiculos") != null:
			main.veiculos.sincronizar()
		avisos.append("O MUNDO \"%s\" CONTINUA DE ONDE PAROU" % str(d.get("nome", "")))
	if main.get("construcao") != null and not pj.is_empty() and not bool(pj.get("morto", false)):
		main.construcao.minha_cama = str(pj.get("cama", ""))   # a cama vem do personagem (a peça chega do host)
	if main.get("hospitais") != null and not pj.is_empty() and not bool(pj.get("morto", false)):
		main.hospitais.carregar_personagem(pj.get("hospitais", {}))
	# 1.03: volta para onde estava nesse mundo (morto ou sem lugar salvo: nasce na base, como antes)
	var pos: Array = pj.get("pos", [])
	if pos.size() >= 4 and not bool(pj.get("morto", false)) and not bool(j.get("servidor")):
		var q := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		main.mundo.forcar(Vector2(q.x, q.z))
		if main.interiores != null:
			main.interiores.abrir_agora(Vector2(q.x, q.z))     # se salvou dentro de um prédio
		if main.get("locais") != null:
			main.locais.abrir_agora(Vector2(q.x, q.z))
		j.teleportar(q + Vector3(0, 0.05, 0), float(pos[3]))
		posicao_voltou = true
	return " · ".join(avisos)
