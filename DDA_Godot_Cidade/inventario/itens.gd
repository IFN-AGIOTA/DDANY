extends RefCounted
# BANCO DE ITENS (estilo DayZ). Cada item ocupa um retângulo de células (w x h) nas grades.
# Campos:
#   nome / sigla (texto curto desenhado no ícone) / desc
#   w, h ......... tamanho na grade (células) · peso (kg por unidade)
#   max .......... quantidade máxima na pilha (1 = não empilha)
#   cat .......... categoria (cor do ícone): arma, branca, municao, pente, acessorio, medico, comida, bebida, roupa,
#                  mochila, ferramenta, diverso
#   slot ......... onde pode ser VESTIDO/GUARDADO no corpo: cabeca, camisa, colete, calca, cinto, mochila, ombro, coldre
#   grade ........ [largura, altura] se o item tem espaço dentro (roupas, mochilas)
#   arma ......... tipo em armas.gd (WDEF) quando o item é uma arma · municao (id) e pente (balas no pente)
#   usa_pente .... pente (item) que encaixa na arma · acess = encaixes de acessório ("cano", "mira")
#   pente_de/cap . pentes: munição que aceitam e quantas balas cabem
#   encaixe/serve  acessórios: onde encaixam e em quais armas
#   usar ......... texto da ação de uso (consumíveis) · some ao usar quando "consome" = true
#   efeito ....... o que o consumível faz (jogador/sobrevivencia.gd): fome, sede, vida, sangue, sangrar, doenca,
#                  reparo_arma, reparo_roupa
#   calor/imperm/protecao  roupas: frio, chuva e proteção contra mordidas/golpes (0 a 1)
# Todo item tem ESTADO (item.gd): perfeito, gasto, danificado, muito danificado, arruinado.
# Para criar um item novo basta acrescentar uma linha aqui e usar Item.novo("id").

const CORES := {
	"arma": Color(0.36, 0.38, 0.33),
	"municao": Color(0.55, 0.45, 0.20),
	"pente": Color(0.42, 0.40, 0.30),
	"acessorio": Color(0.30, 0.33, 0.36),
	"branca": Color(0.45, 0.36, 0.30),
	"bebida": Color(0.25, 0.42, 0.58),
	"medico": Color(0.62, 0.22, 0.22),
	"comida": Color(0.45, 0.50, 0.22),
	"roupa": Color(0.32, 0.36, 0.42),
	"mochila": Color(0.30, 0.38, 0.26),
	"ferramenta": Color(0.40, 0.40, 0.44),
	"diverso": Color(0.55, 0.35, 0.50),
}

const DB := {
	# ----- armas de fogo (arma = tipo em armas/armas.gd · usa_pente = pente que encaixa; sem ele a munição vai direto) -----
	"pistola": {"nome": "PISTOLA M9", "sigla": "M9", "w": 3, "h": 2, "peso": 0.9, "max": 1, "cat": "arma", "slot": "coldre",
		"arma": "pistola", "municao": "mun_9mm", "pente": 12, "usa_pente": "pente_pistola", "acess": ["cano"],
		"desc": "Semiautomática 9 mm. Usa o PENTE DE PISTOLA (12). Aceita silenciador."},
	"m4": {"nome": "M4A1", "sigla": "M4A1", "w": 7, "h": 3, "peso": 3.4, "max": 1, "cat": "arma", "slot": "ombro",
		"arma": "m4", "municao": "mun_556", "pente": 30, "usa_pente": "pente_stanag", "acess": ["cano", "mira"],
		"desc": "Fuzil automático 5,56 mm. Usa o pente STANAG (30). Aceita silenciador e mira."},
	"ak": {"nome": "AKM", "sigla": "AKM", "w": 7, "h": 3, "peso": 3.6, "max": 1, "cat": "arma", "slot": "ombro",
		"arma": "ak", "municao": "mun_762", "pente": 30, "usa_pente": "pente_ak", "acess": ["cano", "mira"],
		"desc": "Fuzil automático 7,62 mm. Coice forte e muito dano. Usa o PENTE DE AK (30)."},
	"espingarda": {"nome": "ESPINGARDA 12", "sigla": "ESPING.", "w": 7, "h": 2, "peso": 3.2, "max": 1, "cat": "arma", "slot": "ombro",
		"arma": "espingarda", "municao": "mun_12", "pente": 6,
		"desc": "Calibre 12, de bomba. Devastadora de perto. Carrega 6 cartuchos (sem pente)."},
	"rifle_caca": {"nome": "RIFLE DE CAÇA", "sigla": "RIFLE", "w": 8, "h": 2, "peso": 4.0, "max": 1, "cat": "arma", "slot": "ombro",
		"arma": "rifle_caca", "municao": "mun_308", "pente": 5, "acess": ["mira"],
		"desc": "Ferrolho .308. Lento, preciso e mortal de longe. Carrega 5 balas. Aceita luneta."},
	# ----- armas brancas (corpo a corpo com o botão ATIRAR) -----
	"faca": {"nome": "FACA DE COMBATE", "sigla": "FACA", "w": 1, "h": 3, "peso": 0.3, "max": 1, "cat": "branca", "slot": "",
		"arma": "faca", "desc": "Rápida e silenciosa. Golpe com o botão ATIRAR."},
	"taco": {"nome": "TACO DE BEISEBOL", "sigla": "TACO", "w": 1, "h": 5, "peso": 1.0, "max": 1, "cat": "branca", "slot": "ombro",
		"arma": "taco", "desc": "Golpe forte que derruba."},
	"machado": {"nome": "MACHADO", "sigla": "MACHADO", "w": 2, "h": 5, "peso": 1.8, "max": 1, "cat": "branca", "slot": "ombro",
		"arma": "machado", "desc": "Lento, mas mata com um ou dois golpes."},
	"cano": {"nome": "CANO DE FERRO", "sigla": "CANO", "w": 1, "h": 4, "peso": 1.2, "max": 1, "cat": "branca", "slot": "ombro",
		"arma": "cano", "desc": "Achado no entulho. Pesado e confiável."},
	"pe_de_cabra": {"nome": "PÉ DE CABRA", "sigla": "PÉ CABRA", "w": 1, "h": 4, "peso": 1.4, "max": 1, "cat": "branca", "slot": "ombro",
		"arma": "pe_de_cabra", "desc": "Ferramenta e arma ao mesmo tempo."},
	# ----- munição (solta) -----
	"mun_9mm": {"nome": "MUNIÇÃO 9MM", "sigla": "9mm", "w": 1, "h": 1, "peso": 0.01, "max": 50, "cat": "municao", "slot": "",
		"desc": "Pistola. Arraste em cima de um pente para encher."},
	"mun_556": {"nome": "MUNIÇÃO 5.56", "sigla": "5.56", "w": 1, "h": 1, "peso": 0.012, "max": 60, "cat": "municao", "slot": "",
		"desc": "M4A1. Arraste em cima de um pente STANAG para encher."},
	"mun_762": {"nome": "MUNIÇÃO 7.62", "sigla": "7.62", "w": 1, "h": 1, "peso": 0.016, "max": 40, "cat": "municao", "slot": "",
		"desc": "AKM. Arraste em cima de um pente de AK para encher."},
	"mun_12": {"nome": "CARTUCHOS 12", "sigla": "12", "w": 1, "h": 1, "peso": 0.04, "max": 20, "cat": "municao", "slot": "",
		"desc": "Espingarda calibre 12."},
	"mun_308": {"nome": "MUNIÇÃO .308", "sigla": ".308", "w": 1, "h": 1, "peso": 0.025, "max": 20, "cat": "municao", "slot": "",
		"desc": "Rifle de caça."},
	# ----- pentes (guardam balas; "cap" = capacidade · "pente_de" = munição que aceita) -----
	"pente_pistola": {"nome": "PENTE DE PISTOLA", "sigla": "PENTE", "w": 1, "h": 2, "peso": 0.08, "max": 1, "cat": "pente", "slot": "",
		"pente_de": "mun_9mm", "cap": 12, "desc": "12 balas de 9 mm. USAR = encher com a munição que você carrega."},
	"pente_stanag": {"nome": "PENTE STANAG", "sigla": "STANAG", "w": 1, "h": 2, "peso": 0.12, "max": 1, "cat": "pente", "slot": "",
		"pente_de": "mun_556", "cap": 30, "desc": "30 balas de 5,56. USAR = encher com a munição que você carrega."},
	"pente_ak": {"nome": "PENTE DE AK", "sigla": "PENTE AK", "w": 1, "h": 2, "peso": 0.2, "max": 1, "cat": "pente", "slot": "",
		"pente_de": "mun_762", "cap": 30, "desc": "30 balas de 7,62. USAR = encher com a munição que você carrega."},
	# ----- acessórios (arraste em cima da arma para encaixar) -----
	"silenciador": {"nome": "SILENCIADOR", "sigla": "SILENC.", "w": 2, "h": 1, "peso": 0.3, "max": 1, "cat": "acessorio", "slot": "",
		"encaixe": "cano", "serve": ["pistola", "m4", "ak"], "desc": "Tiro bem mais baixo: os infectados só ouvem de bem perto."},
	"mira_acog": {"nome": "MIRA 4X", "sigla": "MIRA", "w": 2, "h": 1, "peso": 0.4, "max": 1, "cat": "acessorio", "slot": "",
		"encaixe": "mira", "serve": ["m4", "ak"], "zoom": 2.0, "desc": "Aproxima bem mais ao mirar (M4A1 e AKM)."},
	"luneta": {"nome": "LUNETA", "sigla": "LUNETA", "w": 3, "h": 1, "peso": 0.5, "max": 1, "cat": "acessorio", "slot": "",
		"encaixe": "mira", "serve": ["rifle_caca"], "zoom": 3.4, "desc": "Para o rifle de caça. Mira de longe."},
	# ----- médico (efeito: sangrar = estanca · sangue/vida = recupera) -----
	"bandagem": {"nome": "ATADURA", "sigla": "ATAD.", "w": 1, "h": 1, "peso": 0.05, "max": 4, "cat": "medico", "slot": "",
		"usar": "Fez um curativo.", "consome": true, "efeito": {"sangrar": 1}, "desc": "Estanca um sangramento."},
	"trapos": {"nome": "TRAPOS", "sigla": "TRAPOS", "w": 1, "h": 1, "peso": 0.05, "max": 6, "cat": "medico", "slot": "",
		"usar": "Amarrou os trapos no ferimento.", "consome": true, "efeito": {"sangrar": 1}, "desc": "Pano velho. Estanca um sangramento."},
	"analgesico": {"nome": "ANALGÉSICOS", "sigla": "ANALG.", "w": 1, "h": 1, "peso": 0.05, "max": 1, "cat": "medico", "slot": "",
		"usar": "Tomou analgésicos.", "consome": true, "efeito": {"vida": 15}, "desc": "Alivia a dor (+15 de vida)."},
	"soro": {"nome": "SORO FISIOLÓGICO", "sigla": "SORO", "w": 1, "h": 2, "peso": 0.3, "max": 1, "cat": "medico", "slot": "",
		"usar": "Aplicou o soro.", "consome": true, "efeito": {"sangue": 1200}, "desc": "Repõe o sangue perdido."},
	"kit_medico": {"nome": "KIT DE PRIMEIROS SOCORROS", "sigla": "KIT", "w": 2, "h": 2, "peso": 0.6, "max": 1, "cat": "medico", "slot": "",
		"usar": "Usou o kit de primeiros socorros.", "consome": true, "efeito": {"sangrar": 9, "vida": 40, "sangue": 400},
		"desc": "Estanca todos os sangramentos e cura bastante."},
	"vitaminas": {"nome": "VITAMINAS", "sigla": "VIT.", "w": 1, "h": 1, "peso": 0.05, "max": 1, "cat": "medico", "slot": "",
		"usar": "Tomou vitaminas.", "consome": true, "efeito": {"vida": 5, "doenca": -1}, "desc": "Reforça a imunidade."},
	"antibiotico": {"nome": "ANTIBIÓTICOS", "sigla": "ANTIB.", "w": 1, "h": 1, "peso": 0.05, "max": 1, "cat": "medico", "slot": "",
		"usar": "Tomou antibióticos.", "consome": true, "efeito": {"doenca": -1}, "desc": "Cura infecções."},
	# ----- comida e bebida (efeito: fome / sede = quanto enche, em %) -----
	"feijao": {"nome": "LATA DE FEIJÃO", "sigla": "FEIJÃO", "w": 1, "h": 2, "peso": 0.4, "max": 1, "cat": "comida", "slot": "",
		"usar": "Comeu a lata de feijão.", "consome": true, "efeito": {"fome": 35, "sede": -3}, "desc": "Comida enlatada."},
	"atum": {"nome": "LATA DE ATUM", "sigla": "ATUM", "w": 1, "h": 1, "peso": 0.2, "max": 1, "cat": "comida", "slot": "",
		"usar": "Comeu o atum.", "consome": true, "efeito": {"fome": 25}, "desc": "Proteína em lata."},
	"sardinha": {"nome": "SARDINHAS", "sigla": "SARD.", "w": 1, "h": 1, "peso": 0.15, "max": 1, "cat": "comida", "slot": "",
		"usar": "Comeu as sardinhas.", "consome": true, "efeito": {"fome": 20, "sede": -4}, "desc": "Salgadas."},
	"pessego": {"nome": "PÊSSEGOS EM CALDA", "sigla": "PÊSSEGO", "w": 1, "h": 2, "peso": 0.4, "max": 1, "cat": "comida", "slot": "",
		"usar": "Comeu os pêssegos.", "consome": true, "efeito": {"fome": 22, "sede": 15}, "desc": "Doce e molhado."},
	"biscoito": {"nome": "PACOTE DE BISCOITOS", "sigla": "BISC.", "w": 2, "h": 1, "peso": 0.2, "max": 1, "cat": "comida", "slot": "",
		"usar": "Comeu os biscoitos.", "consome": true, "efeito": {"fome": 18, "sede": -5}, "desc": "Secos, mas enchem."},
	"barra": {"nome": "BARRA DE CEREAL", "sigla": "BARRA", "w": 1, "h": 1, "peso": 0.05, "max": 3, "cat": "comida", "slot": "",
		"usar": "Comeu uma barra de cereal.", "consome": true, "efeito": {"fome": 10}, "desc": "Leve."},
	"salgadinho": {"nome": "SALGADINHO", "sigla": "SALG.", "w": 2, "h": 2, "peso": 0.1, "max": 1, "cat": "comida", "slot": "",
		"usar": "Comeu o salgadinho.", "consome": true, "efeito": {"fome": 12, "sede": -8}, "desc": "Dá sede."},
	"maca": {"nome": "MAÇÃ", "sigla": "MAÇÃ", "w": 1, "h": 1, "peso": 0.15, "max": 1, "cat": "comida", "slot": "",
		"usar": "Comeu a maçã.", "consome": true, "efeito": {"fome": 8, "sede": 6}, "desc": "Ainda está boa."},
	"agua": {"nome": "GARRAFA D'ÁGUA", "sigla": "ÁGUA", "w": 1, "h": 2, "peso": 0.5, "max": 1, "cat": "bebida", "slot": "",
		"usar": "Bebeu água.", "consome": true, "efeito": {"sede": 40}, "desc": "Água potável."},
	"refrigerante": {"nome": "REFRIGERANTE", "sigla": "REFRI", "w": 1, "h": 1, "peso": 0.35, "max": 1, "cat": "bebida", "slot": "",
		"usar": "Bebeu o refrigerante.", "consome": true, "efeito": {"sede": 22, "fome": 4}, "desc": "Quente e sem gás."},
	"suco": {"nome": "CAIXA DE SUCO", "sigla": "SUCO", "w": 1, "h": 1, "peso": 0.25, "max": 1, "cat": "bebida", "slot": "",
		"usar": "Bebeu o suco.", "consome": true, "efeito": {"sede": 20, "fome": 6}, "desc": "Suco de laranja."},
	# ----- ferramentas / diversos -----
	"fita": {"nome": "FITA ADESIVA", "sigla": "FITA", "w": 1, "h": 1, "peso": 0.1, "max": 1, "cat": "ferramenta", "slot": "",
		"usar": "Remendou a roupa com fita.", "consome": true, "efeito": {"reparo_roupa": 0.3}, "desc": "Conserta um pouco a roupa que você veste."},
	"kit_armas": {"nome": "KIT DE LIMPEZA DE ARMAS", "sigla": "KIT ARMA", "w": 2, "h": 1, "peso": 0.4, "max": 1, "cat": "ferramenta", "slot": "",
		"usar": "Limpou a arma.", "consome": true, "efeito": {"reparo_arma": 0.4}, "desc": "Conserta a arma que está nas MÃOS (menos travamentos)."},
	"kit_costura": {"nome": "KIT DE COSTURA", "sigla": "COSTURA", "w": 1, "h": 1, "peso": 0.1, "max": 1, "cat": "ferramenta", "slot": "",
		"usar": "Costurou a roupa.", "consome": true, "efeito": {"reparo_roupa": 0.5}, "desc": "Conserta as roupas que você veste."},
	"lanterna": {"nome": "LANTERNA", "sigla": "LANT.", "w": 1, "h": 2, "peso": 0.25, "max": 1, "cat": "ferramenta", "slot": "",
		"desc": "Segure nas MÃOS para iluminar."},
	"lanterna_cabeca": {"nome": "LANTERNA DE CABEÇA", "sigla": "LANT. CAB.", "w": 2, "h": 1, "peso": 0.2, "max": 1, "cat": "roupa", "slot": "cabeca",
		"desc": "Vista na CABEÇA: ilumina com as mãos livres."},
	"corda": {"nome": "CORDA", "sigla": "CORDA", "w": 2, "h": 2, "peso": 0.8, "max": 1, "cat": "ferramenta", "slot": "",
		"desc": "Corda de náilon."},
	"radio": {"nome": "RÁDIO", "sigla": "RÁDIO", "w": 1, "h": 2, "peso": 0.4, "max": 1, "cat": "ferramenta", "slot": "",
		"desc": "Rádio portátil. Só chiado... por enquanto."},
	"isqueiro": {"nome": "ISQUEIRO", "sigla": "ISQ.", "w": 1, "h": 1, "peso": 0.05, "max": 1, "cat": "ferramenta", "slot": "",
		"desc": "Ainda tem gás."},
	"ursinho": {"nome": "URSINHO DE PELÚCIA", "sigla": "URSO", "w": 2, "h": 2, "peso": 0.2, "max": 1, "cat": "diverso", "slot": "",
		"desc": "Não serve para nada. Mas é fofo."},
	"revista": {"nome": "REVISTA VELHA", "sigla": "REVISTA", "w": 2, "h": 2, "peso": 0.2, "max": 1, "cat": "diverso", "slot": "",
		"desc": "\"O FIM ESTÁ PRÓXIMO?\" diz a capa."},
	"dinheiro": {"nome": "MAÇO DE DÓLARES", "sigla": "US$", "w": 1, "h": 1, "peso": 0.05, "max": 20, "cat": "diverso", "slot": "",
		"desc": "Não compra mais nada."},
	"celular": {"nome": "CELULAR QUEBRADO", "sigla": "CEL.", "w": 1, "h": 1, "peso": 0.15, "max": 1, "cat": "diverso", "slot": "",
		"desc": "Tela trincada. Sem sinal."},
	# ----- roupas (calor = protege do frio · imperm = protege da chuva · protecao = segura mordidas/golpes) -----
	"capacete": {"nome": "CAPACETE TÁTICO", "sigla": "CAPACETE", "w": 3, "h": 2, "peso": 1.2, "max": 1, "cat": "roupa", "slot": "cabeca",
		"calor": 0.05, "protecao": 0.5, "desc": "Protege a cabeça."},
	"gorro": {"nome": "GORRO DE LÃ", "sigla": "GORRO", "w": 2, "h": 1, "peso": 0.1, "max": 1, "cat": "roupa", "slot": "cabeca",
		"calor": 0.15, "desc": "Esquenta bem."},
	"bone": {"nome": "BONÉ", "sigla": "BONÉ", "w": 2, "h": 1, "peso": 0.1, "max": 1, "cat": "roupa", "slot": "cabeca",
		"calor": 0.03, "imperm": 0.05, "desc": "Um boné de beisebol."},
	"camiseta": {"nome": "CAMISETA", "sigla": "CAMISETA", "w": 2, "h": 2, "peso": 0.2, "max": 1, "cat": "roupa", "slot": "camisa",
		"grade": [2, 2], "calor": 0.08, "desc": "Fina, quase sem bolso."},
	"moletom": {"nome": "MOLETOM", "sigla": "MOLETOM", "w": 3, "h": 3, "peso": 0.6, "max": 1, "cat": "roupa", "slot": "camisa",
		"grade": [4, 3], "calor": 0.3, "desc": "Quente, com bolso na frente."},
	"jaqueta": {"nome": "JAQUETA ACOLCHOADA", "sigla": "JAQUETA", "w": 3, "h": 3, "peso": 1.1, "max": 1, "cat": "roupa", "slot": "camisa",
		"grade": [6, 4], "calor": 0.45, "imperm": 0.4, "protecao": 0.1, "desc": "Quente e com muitos bolsos."},
	"capa_chuva": {"nome": "CAPA DE CHUVA", "sigla": "CAPA", "w": 3, "h": 3, "peso": 0.5, "max": 1, "cat": "roupa", "slot": "camisa",
		"grade": [4, 4], "calor": 0.15, "imperm": 0.9, "desc": "Não deixa a chuva molhar você."},
	"colete": {"nome": "COLETE TÁTICO", "sigla": "COLETE", "w": 3, "h": 3, "peso": 1.6, "max": 1, "cat": "roupa", "slot": "colete",
		"grade": [4, 3], "calor": 0.05, "protecao": 0.15, "desc": "Bolsos para pentes e munição."},
	"colete_policia": {"nome": "COLETE À PROVA DE BALAS", "sigla": "COLETE PM", "w": 3, "h": 3, "peso": 3.0, "max": 1, "cat": "roupa", "slot": "colete",
		"grade": [2, 2], "calor": 0.08, "protecao": 0.45, "desc": "Da polícia. Aguenta mordidas e golpes."},
	"calca": {"nome": "CALÇA CARGO", "sigla": "CALÇA", "w": 3, "h": 3, "peso": 0.8, "max": 1, "cat": "roupa", "slot": "calca",
		"grade": [5, 4], "calor": 0.2, "protecao": 0.05, "desc": "Calça com bolsos laterais."},
	"jeans": {"nome": "CALÇA JEANS", "sigla": "JEANS", "w": 3, "h": 3, "peso": 0.7, "max": 1, "cat": "roupa", "slot": "calca",
		"grade": [3, 3], "calor": 0.15, "protecao": 0.05, "desc": "Resistente."},
	"pochete": {"nome": "POCHETE", "sigla": "POCHETE", "w": 2, "h": 2, "peso": 0.2, "max": 1, "cat": "mochila", "slot": "cinto",
		"grade": [3, 2], "desc": "Pequena, vai na cintura."},
	"mochila_escolar": {"nome": "MOCHILA ESCOLAR", "sigla": "MOCHILA", "w": 4, "h": 4, "peso": 0.6, "max": 1, "cat": "mochila", "slot": "mochila",
		"grade": [6, 5], "desc": "Mochila simples."},
	"mochila_trilha": {"nome": "MOCHILA DE TRILHA", "sigla": "MOCHILA", "w": 5, "h": 5, "peso": 1.2, "max": 1, "cat": "mochila", "slot": "mochila",
		"grade": [7, 6], "calor": 0.05, "desc": "Grande e confortável."},
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

# estado (0..1) -> nome e cor, como no DayZ
static func nome_estado(e: float) -> String:
	if e > 0.7:
		return "PERFEITO"
	if e > 0.5:
		return "GASTO"
	if e > 0.3:
		return "DANIFICADO"
	if e > 0.0:
		return "MUITO DANIFICADO"
	return "ARRUINADO"

static func cor_estado(e: float) -> Color:
	if e > 0.7:
		return Color(0.45, 0.85, 0.4)
	if e > 0.5:
		return Color(0.85, 0.85, 0.35)
	if e > 0.3:
		return Color(0.95, 0.6, 0.2)
	if e > 0.0:
		return Color(0.9, 0.25, 0.15)
	return Color(0.5, 0.1, 0.1)

static func cor(id: String) -> Color:
	return CORES.get(def(id).get("cat", "diverso"), Color(0.4, 0.4, 0.4))
