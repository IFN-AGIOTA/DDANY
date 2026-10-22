extends RefCounted
# JOGO SALVO (user://save.json): onde o jogador está, vida/fome/sede..., tudo o que ele carrega, a hora e o tempo,
# o que já foi saqueado nos prédios/carros (mundo/loot_mundo.gd) e os itens largados no chão.
# Salva sozinho a cada 2 minutos, ao pausar, ao voltar ao menu e quando o celular sai do jogo.
# No menu principal aparece "Continuar" quando existe um jogo salvo.
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
		"loot": main.loot_mundo.salvar(main.interiores.abertos if main.interiores != null else {}) if main.loot_mundo != null else {},
		"clima": main.clima.salvar() if main.clima != null and main.clima.has_method("salvar") else {},
		"missoes": main.missoes.salvar() if main.get("missoes") != null else {},
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
const MAPA_PREDIOS := 2

static func _remapear_loot(loot: Dictionary, remapa: PackedInt32Array) -> Dictionary:
	var o := loot.duplicate(true)
	for parte in ["grades", "chao"]:
		var velho: Dictionary = loot.get(parte, {})
		var novo := {}
		for id in velho:
			var s := String(id)
			if not s.begins_with("p") or not s.substr(1, 1).is_valid_int():
				novo[id] = velho[id]                  # carros e outros: não dependem do número do prédio
				continue
			var resto := s.substr(1)
			var num := resto.get_slice("_", 0)
			var i := int(num)
			if i < 0 or i >= remapa.size() or remapa[i] < 0:
				continue                              # prédio removido: o loot dele some
			novo["p%d%s" % [remapa[i], resto.substr(num.length())]] = velho[id]
		o[parte] = novo
	return o

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
		if int(d.get("mapa_predios", 1)) < MAPA_PREDIOS:
			loot = _remapear_loot(loot, main.cidade.remapa_predios)
		main.loot_mundo.carregar(loot)
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
		j.teleportar(pos + Vector3(0, 0.05, 0), float(jd.get("yaw", 0.0)))
	if main.get("missoes") != null and d.has("missoes"):
		main.missoes.carregar(d["missoes"])
