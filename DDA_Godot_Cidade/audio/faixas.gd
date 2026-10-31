extends RefCounted
# MÚSICAS COMPOSTAS (5 faixas com começo, meio e fim), tocadas pelos instrumentos sintetizados do jogo
# (audio/instrumentos.gd) por cima da música procedural (audio/musica_procedural.gd, que escolhe quando):
#   nova_york ...... "Nova York Silenciosa" · piano e teclado, lenta e triste (menu e momentos calmos)
#   chuva .......... "Dias de Chuva" · violão dedilhado e caixinha de música (explorando de dia)
#   noite .......... "Noite sem Luz" · coro, piano e sino, quase parada e escura (de noite)
#   correria ....... "Correria" · baixo, bateria e metais, rápida (perseguição, tiroteio)
#   abrigo ......... "Último Abrigo" · violão, cordas e coro, triste mas com esperança (calma depois do perigo)
# Como cada faixa é escrita:
#   bpm, raiz (semitons acima do Lá grave), escala (semitons de cada grau)
#   acordes ... grau da escala de cada COMPASSO (o acorde é grau, grau+2, grau+4)
#   melodia ... compassos separados por "|", 8 colcheias cada: número = grau da escala (7 = uma oitava acima),
#               "." = pausa (a nota anterior continua soando até sumir)
#   partes .... a ordem do arranjo: cada parte toca a sequência de acordes "ciclos" vezes com os instrumentos
#               indicados (melodia, acordes, arpejo, baixo, bateria, sino, coração; "oitava_mel"/"oitava_ac" =
#               altura da melodia/dos acordes em semitons acima do Lá 55 Hz); "barras" toca só os
#               primeiros compassos; "final" termina com o acorde da tônica segurado.
# Mexa AQUI para: compor/mudar as músicas (as notas são só números, dá para trocar à vontade).

const ARPEJO := [0, 4, 7, 9, 11, 9, 7, 4]           # dedilhado: graus acima da nota do acorde, uma por colcheia
const BATERIAS := {
	# instrumento: colcheias em que toca (0..7) e volume extra
	"lenta": [["tambor", [0], -6.0]],
	"pulso": [["tambor", [0, 5], -3.0], ["caixa", [4], -4.0], ["chimbal", [0, 1, 2, 3, 4, 5, 6, 7], -2.0]],
	"acao": [["tambor", [0, 3, 5], 0.0], ["caixa", [2, 6], 0.0], ["chimbal", [0, 1, 2, 3, 4, 5, 6, 7], 0.0]],
}

const MENOR := [0, 2, 3, 5, 7, 8, 10]
const MAIOR := [0, 2, 4, 5, 7, 9, 11]
const FRIGIO := [0, 1, 3, 5, 7, 8, 10]
const HARMONICA := [0, 2, 3, 5, 7, 8, 11]

const FAIXAS := {
	"nova_york": {
		"nome": "Nova York Silenciosa", "bpm": 58.0, "raiz": 0, "escala": MENOR, "quando": "calma",
		"acordes": [0, 5, 2, 6, 0, 3, 4, 0],
		"melodia": "4 . . 2 . 0 . . | 5 . 4 . 2 . . . | 2 . 4 . 6 . 7 . | 6 . . . 4 . . . | 4 . . 7 . 6 4 . | 3 . 5 . 4 . 3 . | 1 . 2 . 4 . 1 . | 0 . . . . . . .",
		"partes": [
			{"ciclos": 1, "barras": 4, "acordes": "pad", "sino": true},
			{"ciclos": 1, "acordes": "pad", "melodia": "piano", "baixo": "lento"},
			{"ciclos": 1, "acordes": "cordas", "melodia": "piano", "arpejo": "caixinha", "baixo": "lento"},
			{"ciclos": 1, "barras": 4, "acordes": "pad", "melodia": "caixinha", "oitava_mel": 36, "final": true},
		],
	},
	"chuva": {
		"nome": "Dias de Chuva", "bpm": 76.0, "raiz": 5, "escala": MENOR, "quando": "calma",
		"acordes": [0, 6, 5, 6, 0, 3, 5, 4],
		"melodia": "4 . 7 . 9 . 8 7 | 8 . . . 6 . 8 . | 9 . 7 . 5 . 7 . | 8 . . . . . . . | 4 . 7 . 9 . 11 10 | 10 . 9 . 7 . 5 . | 7 . 9 . 8 . 7 . | 8 . . . 4 . . .",
		"partes": [
			{"ciclos": 1, "arpejo": "violao"},
			{"ciclos": 1, "arpejo": "violao", "melodia": "caixinha", "baixo": "lento"},
			{"ciclos": 1, "arpejo": "violao", "melodia": "piano", "acordes": "pad", "baixo": "lento"},
			{"ciclos": 1, "arpejo": "violao", "melodia": "caixinha", "acordes": "pad", "baixo": "lento"},
			{"ciclos": 1, "barras": 2, "arpejo": "violao", "final": true},
		],
	},
	"noite": {
		"nome": "Noite sem Luz", "bpm": 50.0, "raiz": -2, "escala": FRIGIO, "quando": "noite",
		"acordes": [0, 1, 0, 1, 0, 5, 1, 0],
		"melodia": "4 . . . . . . . | 5 . . . 4 . . . | 2 . . 1 . . 0 . | . . . . . . . . | 7 . . . 8 . . . | 7 . . 5 . . 4 . | 5 . . . 4 . 1 . | 0 . . . . . . .",
		"partes": [
			{"ciclos": 1, "barras": 4, "acordes": "coro", "sino": true},
			{"ciclos": 1, "acordes": "coro", "melodia": "piano", "oitava_mel": 12},
			{"ciclos": 1, "acordes": "cordas", "melodia": "piano", "oitava_mel": 12, "coracao": true, "bateria": "lenta"},
			{"ciclos": 1, "barras": 4, "acordes": "coro", "melodia": "caixinha", "oitava_mel": 36, "sino": true, "final": true},
		],
	},
	"correria": {
		"nome": "Correria", "bpm": 132.0, "raiz": 7, "escala": HARMONICA, "quando": "tensao",
		"acordes": [0, 0, 5, 5, 3, 3, 4, 4],
		"melodia": "7 . 7 8 7 . 4 . | 7 . 7 8 9 . 8 . | 10 . 9 . 8 . 7 . | 8 . . . 5 . . . | 10 . 10 9 8 . 7 . | 8 . 7 . 5 . 3 . | 6 . . . 4 . 6 . | 8 . 6 . 4 . . .",
		"partes": [
			{"ciclos": 1, "baixo": "rapido", "bateria": "pulso"},
			{"ciclos": 2, "baixo": "rapido", "bateria": "acao", "melodia": "metal", "oitava_mel": 12},
			{"ciclos": 1, "baixo": "rapido", "bateria": "acao", "acordes": "tremolo", "oitava_ac": 24, "melodia": "metal", "oitava_mel": 12},
			{"ciclos": 2, "baixo": "rapido", "bateria": "acao", "acordes": "cordas", "melodia": "metal", "oitava_mel": 12},
			{"ciclos": 1, "barras": 2, "baixo": "rapido", "bateria": "acao", "final": true},
		],
	},
	"abrigo": {
		"nome": "Último Abrigo", "bpm": 66.0, "raiz": 3, "escala": MAIOR, "quando": "calma",
		"acordes": [5, 3, 0, 4, 5, 3, 4, 0],
		"melodia": "9 . 8 . 7 . 5 . | 7 . . 5 . 3 . . | 4 . 7 . 9 . 8 . | 8 . . . 6 . . . | 9 . 10 . 12 . 11 . | 10 . 9 . 7 . 8 . | 8 . 9 . 11 . 8 . | 7 . . . . . . .",
		"partes": [
			{"ciclos": 1, "barras": 4, "arpejo": "violao", "acordes": "pad"},
			{"ciclos": 1, "arpejo": "violao", "melodia": "piano", "baixo": "lento"},
			{"ciclos": 1, "arpejo": "violao", "acordes": "cordas", "melodia": "piano", "baixo": "lento"},
			{"ciclos": 1, "arpejo": "violao", "acordes": "coro", "melodia": "caixinha", "baixo": "lento", "sino": true},
			{"ciclos": 1, "barras": 4, "arpejo": "violao", "acordes": "pad", "final": true},
		],
	},
}

static func grau(f: Dictionary, g: int) -> int:
	var esc: Array = f["escala"]
	var n := esc.size()
	return int(esc[posmod(g, n)]) + 12 * floori(float(g) / n) + int(f["raiz"])

static func _melodia(f: Dictionary) -> Array:
	var barras: Array = []
	for b in String(f["melodia"]).split("|"):
		var notas: Array = []
		for tk in b.strip_edges().split(" ", false):
			notas.append(null if tk == "." else int(tk))
		while notas.size() < 8:
			notas.append(null)
		barras.append(notas)
	return barras

# lista de notas da faixa inteira: [tempo (s), instrumento, semitons acima do Lá 55 Hz, volume extra (dB)],
# em ordem de tempo. A última entrada é ["fim", ...] com a duração total.
static func eventos(id: String) -> Array:
	var f: Dictionary = FAIXAS[id]
	var col := 30.0 / float(f["bpm"])               # duração de uma colcheia
	var acordes: Array = f["acordes"]
	var mel := _melodia(f)
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	var ev: Array = []
	var t := 0.0
	var ultimo_acorde := 0
	for p in f["partes"]:
		var nb: int = int(p.get("barras", acordes.size()))
		var db: float = float(p.get("db", 0.0))
		for c in int(p.get("ciclos", 1)):
			for b in nb:
				var ac: int = acordes[b % acordes.size()]
				ultimo_acorde = ac
				var t0 := t
				# acordes segurados (nota do acorde, 3ª e 5ª), uma vez por compasso
				var inst_ac: String = p.get("acordes", "")
				if inst_ac != "":
					for k in 3:
						ev.append([t0 + k * 0.02, inst_ac, grau(f, ac + k * 2) + int(p.get("oitava_ac", 12)), db - 2.0 - k * 1.5])
				if p.get("sino", false) and b == 0 and c == 0:
					ev.append([t0, "sino", grau(f, 0) + 12, db - 3.0])
				for e in 8:
					var te := t0 + e * col
					var hum := rng.randf_range(-1.5, 0.0)           # cada nota com força um pouco diferente
					var arp: String = p.get("arpejo", "")
					if arp != "":
						var oit := 12 if arp == "violao" else 24
						ev.append([te, arp, grau(f, ac + ARPEJO[e]) + oit, db + hum - (0.0 if e == 0 else 3.0)])
					var nota = mel[b % mel.size()][e]
					var inst_m: String = p.get("melodia", "")
					if inst_m != "" and nota != null:
						ev.append([te + 0.01, inst_m, grau(f, int(nota)) + int(p.get("oitava_mel", 24)), db + hum + 1.0])
					match String(p.get("baixo", "")):
						"lento":
							if e == 0 or e == 4:
								ev.append([te, "baixo", grau(f, ac) + (0 if e == 0 else 12), db - 3.0])
						"rapido":
							var oitava := 12 if e == 3 or e == 6 else 0
							ev.append([te, "baixo", grau(f, ac) + oitava, db + (0.0 if e % 2 == 0 else -4.0)])
					var bat: String = p.get("bateria", "")
					if bat != "":
						for linha in BATERIAS[bat]:
							if e in linha[1]:
								ev.append([te, linha[0], 0.0, db + float(linha[2]) + hum])
					if p.get("coracao", false) and e % 4 == 0:
						ev.append([te, "coracao", 0.0, db - 6.0])
				t += 8.0 * col
		if p.get("final", false):
			for k in 3:
				ev.append([t + k * 0.03, "pad", grau(f, 0) + 12 + [0, 7, 12][k], db - 2.0])
			ev.append([t, "piano", grau(f, 0) + 12, db])
			ev.append([t, "sino", grau(f, 0) + 12, db - 4.0])
			t += 5.0
	ev.sort_custom(func(a, b): return a[0] < b[0])
	ev.append([t + 1.0, "fim", 0.0, 0.0])
	return ev
