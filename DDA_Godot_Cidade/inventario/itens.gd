extends RefCounted
# BANCO DE ITENS (estilo DayZ). Cada item ocupa um retângulo de células (w x h) nas grades.
# Campos:
#   nome / sigla (texto curto desenhado no ícone) / desc
#   w, h ......... tamanho na grade (células) · peso (kg por unidade)
#   max .......... quantidade máxima na pilha (1 = não empilha)
#   cat .......... categoria (cor do ícone): arma, municao, medico, comida, roupa, mochila, ferramenta, diverso
#   slot ......... onde pode ser VESTIDO/GUARDADO no corpo: cabeca, camisa, colete, calca, cinto, mochila, ombro, coldre
#   grade ........ [largura, altura] se o item tem espaço dentro (roupas, mochilas)
#   arma ......... tipo em armas.gd (WDEF) quando o item é uma arma · municao (id) e pente (balas no pente)
#   usar ......... texto da ação de uso (consumíveis) · some ao usar quando "consome" = true
# Para criar um item novo basta acrescentar uma linha aqui e usar Item.novo("id").

const CORES := {
	"arma": Color(0.36, 0.38, 0.33),
	"municao": Color(0.55, 0.45, 0.20),
	"medico": Color(0.62, 0.22, 0.22),
	"comida": Color(0.45, 0.50, 0.22),
	"roupa": Color(0.32, 0.36, 0.42),
	"mochila": Color(0.30, 0.38, 0.26),
	"ferramenta": Color(0.40, 0.40, 0.44),
	"diverso": Color(0.55, 0.35, 0.50),
}

const DB := {
	# ----- armas -----
	"pistola": {"nome": "PISTOLA", "sigla": "PISTOLA", "w": 3, "h": 2, "peso": 0.9, "max": 1, "cat": "arma", "slot": "coldre",
		"arma": "pistola", "municao": "mun_9mm", "pente": 12, "desc": "Semiautomática 9 mm. Pente de 12 balas."},
	"m4": {"nome": "M4A1", "sigla": "M4A1", "w": 7, "h": 3, "peso": 3.4, "max": 1, "cat": "arma", "slot": "ombro",
		"arma": "m4", "municao": "mun_556", "pente": 30, "desc": "Fuzil automático 5,56 mm. Pente de 30 balas."},
	"faca": {"nome": "FACA DE COMBATE", "sigla": "FACA", "w": 1, "h": 3, "peso": 0.3, "max": 1, "cat": "ferramenta", "slot": "",
		"desc": "Lâmina de aço. Ainda não serve para lutar."},
	# ----- munição -----
	"mun_9mm": {"nome": "MUNIÇÃO 9MM", "sigla": "9mm", "w": 1, "h": 1, "peso": 0.01, "max": 50, "cat": "municao", "slot": "",
		"desc": "Usada pela PISTOLA. Recarregar puxa balas do inventário."},
	"mun_556": {"nome": "MUNIÇÃO 5.56", "sigla": "5.56", "w": 1, "h": 1, "peso": 0.012, "max": 60, "cat": "municao", "slot": "",
		"desc": "Usada pelo M4A1. Recarregar puxa balas do inventário."},
	# ----- médico / comida -----
	"bandagem": {"nome": "ATADURA", "sigla": "ATAD.", "w": 1, "h": 1, "peso": 0.05, "max": 4, "cat": "medico", "slot": "",
		"usar": "Fez um curativo.", "consome": true, "desc": "Para sangramentos."},
	"vitaminas": {"nome": "VITAMINAS", "sigla": "VIT.", "w": 1, "h": 1, "peso": 0.05, "max": 1, "cat": "medico", "slot": "",
		"usar": "Tomou vitaminas.", "consome": true, "desc": "Reforça a imunidade."},
	"feijao": {"nome": "LATA DE FEIJÃO", "sigla": "FEIJÃO", "w": 1, "h": 2, "peso": 0.4, "max": 1, "cat": "comida", "slot": "",
		"usar": "Comeu a lata de feijão.", "consome": true, "desc": "Comida enlatada."},
	"agua": {"nome": "GARRAFA D'ÁGUA", "sigla": "ÁGUA", "w": 1, "h": 2, "peso": 0.5, "max": 1, "cat": "comida", "slot": "",
		"usar": "Bebeu água.", "consome": true, "desc": "Água potável."},
	# ----- ferramentas / diversos -----
	"fita": {"nome": "FITA ADESIVA", "sigla": "FITA", "w": 1, "h": 1, "peso": 0.1, "max": 1, "cat": "ferramenta", "slot": "",
		"desc": "Conserta quase tudo."},
	"lanterna": {"nome": "LANTERNA", "sigla": "LANT.", "w": 1, "h": 2, "peso": 0.25, "max": 1, "cat": "ferramenta", "slot": "",
		"desc": "Ilumina à noite."},
	"corda": {"nome": "CORDA", "sigla": "CORDA", "w": 2, "h": 2, "peso": 0.8, "max": 1, "cat": "ferramenta", "slot": "",
		"desc": "Corda de náilon."},
	"radio": {"nome": "RÁDIO", "sigla": "RÁDIO", "w": 1, "h": 2, "peso": 0.4, "max": 1, "cat": "ferramenta", "slot": "",
		"desc": "Rádio portátil."},
	"ursinho": {"nome": "URSINHO DE PELÚCIA", "sigla": "URSO", "w": 2, "h": 2, "peso": 0.2, "max": 1, "cat": "diverso", "slot": "",
		"desc": "Não serve para nada. Mas é fofo."},
	# ----- roupas e mochilas (têm espaço dentro) -----
	"capacete": {"nome": "CAPACETE TÁTICO", "sigla": "CAPACETE", "w": 3, "h": 2, "peso": 1.2, "max": 1, "cat": "roupa", "slot": "cabeca",
		"desc": "Protege a cabeça."},
	"jaqueta": {"nome": "JAQUETA ACOLCHOADA", "sigla": "JAQUETA", "w": 3, "h": 3, "peso": 1.1, "max": 1, "cat": "roupa", "slot": "camisa",
		"grade": [6, 4], "desc": "Quente e com muitos bolsos."},
	"colete": {"nome": "COLETE TÁTICO", "sigla": "COLETE", "w": 3, "h": 3, "peso": 1.6, "max": 1, "cat": "roupa", "slot": "colete",
		"grade": [4, 3], "desc": "Bolsos para pentes e munição."},
	"calca": {"nome": "CALÇA CARGO", "sigla": "CALÇA", "w": 3, "h": 3, "peso": 0.8, "max": 1, "cat": "roupa", "slot": "calca",
		"grade": [5, 4], "desc": "Calça com bolsos laterais."},
	"pochete": {"nome": "POCHETE", "sigla": "POCHETE", "w": 2, "h": 2, "peso": 0.2, "max": 1, "cat": "mochila", "slot": "cinto",
		"grade": [3, 2], "desc": "Pequena, vai na cintura."},
	"mochila_escolar": {"nome": "MOCHILA ESCOLAR", "sigla": "MOCHILA", "w": 4, "h": 4, "peso": 0.6, "max": 1, "cat": "mochila", "slot": "mochila",
		"grade": [6, 5], "desc": "Mochila simples."},
	"mochila_combate": {"nome": "MOCHILA DE COMBATE", "sigla": "MOCHILA", "w": 5, "h": 5, "peso": 1.5, "max": 1, "cat": "mochila", "slot": "mochila",
		"grade": [8, 7], "desc": "Mochila grande do exército."},
}

# nomes dos lugares do corpo (na ordem em que aparecem na coluna do meio)
const SLOTS := {
	"cabeca": "CABEÇA", "camisa": "CAMISA", "colete": "COLETE", "cinto": "CINTO",
	"ombro": "OMBRO", "coldre": "COLDRE", "calca": "CALÇA", "mochila": "MOCHILA", "maos": "MÃOS",
}

static func def(id: String) -> Dictionary:
	return DB.get(id, {})

static func cor(id: String) -> Color:
	return CORES.get(def(id).get("cat", "diverso"), Color(0.4, 0.4, 0.4))
