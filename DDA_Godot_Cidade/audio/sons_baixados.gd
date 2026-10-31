extends RefCounted
# SONS GRAVADOS (baixados, licença livre, créditos no menu Créditos e em audio/sons/LICENCA.txt), em audio/sons/:
#   (0.49: tiros, recargas, menu, inventário, ambiente etc. ficam em audio/sons.gd, que acha os grupos sozinho)
#   infectados/ .. gemidos, ataques, gritos, morte, passos
#   jogador/ ..... passos, dor, morte
#   impactos/ .... golpe acertando, bala batendo
#   ambiente/ .... sirene ao longe
# Quem usa: armas/sons_armas.gd, inimigos/vago.gd, jogador/jogador.gd, audio/ambiente.gd.
# Se um arquivo faltar, quem chamou continua com o som sintetizado de antes.
# Mexa AQUI para: quantos arquivos há em cada grupo (se acrescentar mais).

const PASTA := "res://audio/sons/"
const GRUPOS := {
	"infectados/gemido": 8, "infectados/ataque": 8, "infectados/grito": 4, "infectados/morte": 4,
	"infectados/passo": 5, "jogador/passo": 6, "jogador/dor": 5, "jogador/morte": 2,
	"impactos/soco": 5, "impactos/bala": 5,
}
static var _cache := {}

# um som avulso ("armas/tiro_pistola") ou null
static func som(nome: String) -> AudioStream:
	if not _cache.has(nome):
		var c := PASTA + nome + ".ogg"
		_cache[nome] = load(c) if ResourceLoader.exists(c) else null
	return _cache[nome]

# todos os sons de um grupo ("infectados/gemido" -> gemido_0 ... gemido_7); vazio se não houver
static func grupo(nome: String) -> Array:
	var k := "grupo:" + nome
	if not _cache.has(k):
		var lista: Array = []
		for i in int(GRUPOS.get(nome, 0)):
			var s := som("%s_%d" % [nome, i])
			if s != null:
				lista.append(s)
		_cache[k] = lista
	return _cache[k]

static func sortear(nome: String) -> AudioStream:
	var g := grupo(nome)
	return g[randi() % g.size()] if not g.is_empty() else null
