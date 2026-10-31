extends RefCounted
# LOOT DA CIDADE (estilo DayZ): o que aparece em cada móvel, no chão dos prédios e nos porta-malas dos carros.
# Cada lugar tem uma TABELA (abaixo). O conteúdo é sorteado na 1ª vez que o prédio é aberto, sempre igual para o
# mesmo lugar (semente = id do lugar), e depois fica GUARDADO: o que você deixou fica.
# Cidade abandonada: muita coisa já foi saqueada (CHANCE_VAZIO).
# 0.72 · O LOOT VOLTA (estilo DayZ): passado um CICLO no relógio do jogo (dia/hora do mundo/clima.gd, igual para
# todos na partida em rede), o lugar ganha um sorteio novo na próxima vez que abrir. Nada é apagado: o sorteio novo
# só COMPLETA até a quantidade dele (o que já está lá, inclusive o que você guardou, conta). Cada lugar tem o seu
# momento (fase sorteada pelo id), então a cidade não enche toda de uma vez. Os locais especiais (zonas de PvP)
# voltam mais rápido (CICLO_LOCAL).
# Mexa AQUI para: o que aparece em cada lugar, raridade (peso), quantidades, estado dos itens, quão vazia a cidade
# está e de quanto em quanto tempo o loot volta.

const ItemCls := preload("res://inventario/item.gd")
const GradeCls := preload("res://inventario/grade.gd")
const ItemMundoCls := preload("res://inventario/item_mundo.gd")
const Itens := preload("res://inventario/itens.gd")

const CHANCE_VAZIO := 0.35            # móvel já saqueado
const CHANCE_VAZIO_LOCAL := 0.15      # 0.68: locais especiais (posto, hospital, supermercado, armazém...) têm mais coisa
const CHANCE_CHAO := 0.45             # chance de cada ponto livre do chão ter alguma coisa
const MAX_CHAO := 4                   # itens soltos por prédio
const CICLO := 16.0                   # 0.72: horas de JOGO para o loot de um prédio/carro voltar (16 h = 32 min de verdade)
const CICLO_LOCAL := 10.0             # 0.72: postos, hospitais, supermercados e armazéns (10 h = 20 min)
const CHANCE_VAZIO_BUNKER := 0.03     # 0.83: bunkers: quase nada foi saqueado (muito loot)
const MAX_CHAO_USO := {"bunker": 14}  # 0.83: itens soltos no chão (os outros: MAX_CHAO)
const CHANCE_CARTAO := 0.12           # 0.83: chance de cada ÁREA MILITAR ter o cartão de um bunker (a cada ciclo do loot)

# [id, peso (raridade relativa), qtd mínima, qtd máxima]
const TABELAS := {
	"casa_sala": [["pilha", 2, 1, 1], ["revista", 4, 1, 1], ["ursinho", 2, 1, 1], ["celular", 3, 1, 1], ["dinheiro", 3, 10, 60], ["bone", 2, 1, 1],
		["barra", 3, 1, 2], ["salgadinho", 3, 1, 1], ["refrigerante", 3, 1, 1], ["isqueiro", 2, 1, 1], ["lanterna", 2, 1, 1],
		["mun_9mm", 1, 4, 12], ["taco", 1, 1, 1]],
	"casa_quarto": [["camiseta", 5, 1, 1], ["moletom", 4, 1, 1], ["jeans", 4, 1, 1], ["gorro", 3, 1, 1], ["bone", 2, 1, 1],
		["jaqueta", 2, 1, 1], ["capa_chuva", 1, 1, 1], ["mochila_escolar", 2, 1, 1], ["mochila_trilha", 1, 1, 1], ["pochete", 2, 1, 1], ["trapos", 3, 1, 3],
		["kit_costura", 2, 1, 1], ["pistola", 1, 1, 1], ["pente_pistola", 1, 1, 1], ["mun_9mm", 2, 5, 15], ["dinheiro", 2, 10, 50],
		["revista", 2, 1, 1], ["ursinho", 2, 1, 1], ["lanterna_cabeca", 1, 1, 1], ["taco", 1, 1, 1]],
	"casa_cozinha": [["feijao", 5, 1, 1], ["atum", 4, 1, 1], ["sardinha", 4, 1, 1], ["pessego", 3, 1, 1], ["biscoito", 4, 1, 1], ["leite_condensado", 2, 1, 1],
		["barra", 2, 1, 3], ["agua", 3, 1, 1], ["refrigerante", 3, 1, 1], ["suco", 3, 1, 1], ["faca", 2, 1, 1], ["isqueiro", 2, 1, 1],
		["fita", 1, 1, 1], ["garrafa_vazia", 2, 1, 1], ["carvao", 1, 1, 1]],
	"geladeira": [["agua", 5, 1, 1], ["refrigerante", 5, 1, 1], ["suco", 4, 1, 1], ["maca", 3, 1, 1], ["pessego", 2, 1, 1]],
	"banheiro": [["bandagem", 4, 1, 2], ["analgesico", 4, 1, 1], ["vitaminas", 3, 1, 1], ["antibiotico", 1, 1, 1],
		["trapos", 3, 1, 2], ["kit_medico", 1, 1, 1], ["carvao", 2, 1, 1], ["pastilha", 2, 2, 6]],
	"mercado": [["pilha", 3, 1, 1], ["feijao", 6, 1, 1], ["atum", 5, 1, 1], ["sardinha", 5, 1, 1], ["pessego", 4, 1, 1], ["biscoito", 5, 1, 1], ["leite_condensado", 3, 1, 1],
		["barra", 4, 1, 3], ["salgadinho", 4, 1, 1], ["agua", 6, 1, 1], ["refrigerante", 5, 1, 1], ["suco", 4, 1, 1], ["maca", 2, 1, 1],
		["fita", 2, 1, 1], ["isqueiro", 2, 1, 1], ["lanterna", 1, 1, 1], ["kit_costura", 1, 1, 1]],
	"farmacia": [["bandagem", 6, 1, 4], ["analgesico", 5, 1, 1], ["vitaminas", 5, 1, 1], ["antibiotico", 3, 1, 1], ["soro", 2, 1, 1],
		["kit_medico", 2, 1, 1], ["trapos", 2, 1, 3], ["agua", 2, 1, 1], ["barra", 2, 1, 2], ["carvao", 3, 1, 1],
		["pastilha", 3, 2, 8], ["tala", 1, 1, 1]],
	"loja": [["tabuas", 1, 1, 3], ["pilha", 4, 1, 1], ["lanterna", 3, 1, 1], ["lanterna_cabeca", 2, 1, 1], ["isqueiro", 3, 1, 1], ["fita", 3, 1, 1], ["corda", 2, 1, 1],
		["radio", 2, 1, 1], ["kit_costura", 2, 1, 1], ["pochete", 2, 1, 1], ["mochila_escolar", 2, 1, 1], ["mochila_trilha", 1, 1, 1],
		["martelo", 1, 1, 1], ["pe_de_cabra", 1, 1, 1], ["machado", 1, 1, 1], ["facao", 1, 1, 1], ["celular", 2, 1, 1], ["barra", 2, 1, 2], ["refrigerante", 2, 1, 1]],
	"loja_roupas": [["camiseta", 5, 1, 1], ["moletom", 5, 1, 1], ["jeans", 5, 1, 1], ["calca", 3, 1, 1], ["jaqueta", 3, 1, 1],
		["capa_chuva", 3, 1, 1], ["gorro", 4, 1, 1], ["bone", 4, 1, 1], ["mochila_escolar", 2, 1, 1], ["mochila_trilha", 2, 1, 1],
		["pochete", 2, 1, 1]],
	"balcao": [["dinheiro", 5, 10, 100], ["revista", 2, 1, 1], ["celular", 2, 1, 1], ["barra", 3, 1, 2], ["refrigerante", 2, 1, 1],
		["isqueiro", 2, 1, 1], ["pistola", 1, 1, 1], ["mun_9mm", 2, 4, 12], ["fita", 1, 1, 1]],
	"escritorio": [["pilha", 2, 1, 1], ["revista", 4, 1, 1], ["celular", 3, 1, 1], ["dinheiro", 3, 10, 50], ["barra", 2, 1, 2], ["fita", 2, 1, 1],
		["lanterna", 2, 1, 1], ["radio", 1, 1, 1], ["analgesico", 1, 1, 1], ["refrigerante", 2, 1, 1]],
	"armas_policia": [["mascara_gas", 1, 1, 1], ["pilha", 2, 1, 1], ["pistola", 4, 1, 1], ["pente_pistola", 5, 1, 1], ["mun_9mm", 6, 10, 40], ["espingarda", 2, 1, 1],
		["mun_12", 4, 4, 16], ["m4", 1, 1, 1], ["mp5", 1, 1, 1], ["pente_mp5", 2, 1, 1], ["pente_stanag", 2, 1, 1], ["mun_556", 2, 10, 40], ["colete_policia", 2, 1, 1],
		["capacete", 1, 1, 1], ["lanterna", 2, 1, 1], ["kit_armas", 2, 1, 1], ["bandagem", 2, 1, 2], ["silenciador", 1, 1, 1],
		["ak", 1, 1, 1], ["pente_ak", 1, 1, 1], ["mun_762", 1, 8, 30], ["mira_acog", 1, 1, 1]],
	"deposito": [["galao", 2, 1, 1], ["tabuas", 3, 1, 3], ["mascara_gas", 1, 1, 1], ["pilha", 2, 1, 1], ["corda", 3, 1, 1], ["fita", 3, 1, 1], ["cano", 3, 1, 1], ["martelo", 2, 1, 1], ["pe_de_cabra", 2, 1, 1], ["machado", 2, 1, 1], ["facao", 2, 1, 1],
		["lanterna", 2, 1, 1], ["trapos", 3, 1, 4], ["agua", 2, 1, 1], ["feijao", 2, 1, 1], ["kit_armas", 1, 1, 1],
		["mochila_trilha", 1, 1, 1], ["mun_308", 1, 3, 10], ["rifle_caca", 1, 1, 1], ["galho", 3, 1, 4], ["isqueiro", 1, 1, 1],
		["luneta", 1, 1, 1], ["mun_762", 1, 5, 15], ["tijolo", 2, 1, 2]],
	"carro": [["galao", 2, 1, 1], ["tabuas", 1, 1, 3], ["pilha", 1, 1, 1], ["agua", 3, 1, 1], ["refrigerante", 2, 1, 1], ["biscoito", 2, 1, 1], ["barra", 2, 1, 2], ["lanterna", 2, 1, 1],
		["fita", 2, 1, 1], ["corda", 2, 1, 1], ["martelo", 2, 1, 1], ["pe_de_cabra", 2, 1, 1], ["kit_medico", 1, 1, 1], ["bandagem", 2, 1, 2],
		["mochila_escolar", 2, 1, 1], ["jaqueta", 1, 1, 1], ["capa_chuva", 1, 1, 1], ["taco", 1, 1, 1], ["espingarda", 1, 1, 1],
		["mun_12", 1, 4, 10], ["rifle_caca", 1, 1, 1], ["mun_308", 1, 3, 8], ["kit_armas", 1, 1, 1], ["dinheiro", 1, 10, 50],
		["ak", 1, 1, 1], ["pente_ak", 1, 1, 1], ["mun_762", 1, 5, 20], ["mochila_trilha", 1, 1, 1]],
	# caixa de SUPRIMENTO MILITAR (missões do rádio no modo livre)
	"militar": [["mascara_gas", 3, 1, 1], ["pilha", 2, 1, 1], ["m4", 3, 1, 1], ["ak", 3, 1, 1], ["mp5", 2, 1, 1], ["pente_mp5", 3, 1, 1], ["pente_stanag", 4, 1, 1], ["pente_ak", 4, 1, 1], ["mun_556", 5, 20, 60],
		["mun_762", 5, 20, 50], ["colete", 3, 1, 1], ["colete_policia", 2, 1, 1], ["capacete", 3, 1, 1], ["mochila_combate", 2, 1, 1],
		["kit_medico", 4, 1, 1], ["soro", 2, 1, 1], ["antibiotico", 3, 1, 1], ["mira_acog", 2, 1, 1], ["silenciador", 2, 1, 1],
		["luneta", 1, 1, 1], ["rifle_caca", 1, 1, 1], ["mun_308", 2, 5, 15], ["kit_armas", 3, 1, 1], ["agua", 3, 1, 1], ["feijao", 3, 1, 1], ["facao", 2, 1, 1],
		["leite_condensado", 2, 1, 1]],
	# ---- 0.68: LOCAIS ESPECIAIS (zonas de PvP: mundo/local.gd) ----
	"posto_loja": [["isqueiro", 5, 1, 1], ["barra", 5, 1, 3], ["salgadinho", 5, 1, 1], ["biscoito", 4, 1, 1], ["refrigerante", 4, 1, 1],
		["agua", 3, 1, 1], ["fita", 3, 1, 1], ["pilha", 4, 1, 1], ["lanterna", 3, 1, 1], ["lanterna_cabeca", 1, 1, 1], ["corda", 2, 1, 1],
		["kit_costura", 2, 1, 1], ["radio", 2, 1, 1], ["revista", 2, 1, 1], ["bone", 2, 1, 1], ["analgesico", 2, 1, 1], ["bandagem", 2, 1, 1],
		["atum", 2, 1, 1], ["feijao", 2, 1, 1], ["dinheiro", 2, 10, 75]],
	"posto_bebidas": [["agua", 6, 1, 1], ["refrigerante", 6, 1, 1], ["suco", 4, 1, 1], ["agua_suja", 1, 1, 1], ["garrafa_vidro", 3, 1, 2]],
	"posto_deposito": [["galao", 3, 1, 1], ["tabuas", 2, 1, 3], ["fita", 3, 1, 1], ["corda", 3, 1, 1], ["trapos", 3, 1, 4], ["pilha", 3, 1, 1], ["agua", 3, 1, 1], ["barra", 2, 1, 3],
		["lanterna", 2, 1, 1], ["isqueiro", 2, 1, 1], ["mochila_escolar", 1, 1, 1], ["refrigerante", 2, 1, 1]],
	"posto_oficina": [["galao", 4, 1, 1], ["tabuas", 3, 1, 3], ["martelo", 4, 1, 1], ["pe_de_cabra", 4, 1, 1], ["cano", 4, 1, 1], ["machado", 2, 1, 1], ["facao", 2, 1, 1], ["fita", 4, 1, 1], ["corda", 3, 1, 1],
		["trapos", 4, 1, 4], ["lanterna", 3, 1, 1], ["lanterna_cabeca", 2, 1, 1], ["isqueiro", 2, 1, 1], ["mascara_gas", 1, 1, 1],
		["kit_armas", 1, 1, 1], ["calca", 2, 1, 1], ["jaqueta", 1, 1, 1], ["espingarda", 1, 1, 1], ["mun_12", 1, 4, 10]],
	"lixo": [["garrafa_vazia", 5, 1, 1], ["trapos", 4, 1, 3], ["revista", 3, 1, 1], ["celular", 2, 1, 1], ["galho", 2, 1, 2],
		["agua_suja", 2, 1, 1], ["cano", 1, 1, 1], ["ursinho", 1, 1, 1], ["mun_9mm", 1, 2, 6], ["garrafa_vidro", 5, 1, 2], ["tijolo", 2, 1, 1]],
	"hospital_farmacia": [["analgesico", 6, 1, 1], ["antibiotico", 5, 1, 1], ["vitaminas", 5, 1, 1], ["soro", 4, 1, 1], ["kit_medico", 3, 1, 1],
		["bandagem", 6, 1, 4], ["tala", 3, 1, 1], ["carvao", 4, 1, 1], ["pastilha", 4, 2, 8], ["agua", 1, 1, 1]],
	"hospital_enfermaria": [["bandagem", 6, 1, 3], ["trapos", 4, 1, 3], ["analgesico", 4, 1, 1], ["soro", 3, 1, 1], ["tala", 2, 1, 1],
		["kit_medico", 1, 1, 1], ["vitaminas", 2, 1, 1], ["camiseta", 2, 1, 1], ["agua", 2, 1, 1], ["ursinho", 1, 1, 1], ["revista", 1, 1, 1]],
	"hospital_lab": [["antibiotico", 5, 1, 1], ["carvao", 4, 1, 1], ["pastilha", 4, 2, 8], ["vitaminas", 3, 1, 1], ["soro", 3, 1, 1],
		["mascara_gas", 1, 1, 1], ["analgesico", 2, 1, 1]],
	"hospital_cirurgia": [["kit_medico", 6, 1, 1], ["soro", 5, 1, 1], ["antibiotico", 4, 1, 1], ["tala", 4, 1, 1], ["bandagem", 4, 2, 4],
		["analgesico", 3, 1, 1], ["faca", 1, 1, 1]],
	"hospital_deposito": [["soro", 4, 1, 1], ["bandagem", 5, 2, 4], ["kit_medico", 2, 1, 1], ["mascara_gas", 2, 1, 1], ["trapos", 3, 1, 4],
		["pastilha", 3, 2, 8], ["carvao", 3, 1, 1], ["agua", 3, 1, 1], ["tala", 2, 1, 1], ["lanterna", 1, 1, 1]],
	"ambulancia": [["kit_medico", 5, 1, 1], ["bandagem", 5, 1, 4], ["soro", 4, 1, 1], ["tala", 4, 1, 1], ["analgesico", 3, 1, 1],
		["antibiotico", 2, 1, 1], ["lanterna", 2, 1, 1], ["radio", 1, 1, 1]],
	"militar_med": [["kit_medico", 5, 1, 1], ["soro", 4, 1, 1], ["antibiotico", 4, 1, 1], ["bandagem", 4, 2, 4], ["mascara_gas", 3, 1, 1],
		["m4", 2, 1, 1], ["pente_stanag", 3, 1, 1], ["mun_556", 4, 15, 45], ["mp5", 2, 1, 1], ["pente_mp5", 3, 1, 1], ["mun_9mm", 4, 15, 40],
		["colete", 2, 1, 1], ["capacete", 2, 1, 1], ["mochila_combate", 1, 1, 1], ["agua", 2, 1, 1], ["feijao", 2, 1, 1]],
	"super_mercearia": [["feijao", 6, 1, 1], ["atum", 5, 1, 1], ["sardinha", 5, 1, 1], ["pessego", 5, 1, 1], ["biscoito", 5, 1, 1],
		["leite_condensado", 4, 1, 1], ["barra", 4, 1, 3], ["salgadinho", 4, 1, 1], ["suco", 2, 1, 1]],
	"super_bebidas": [["agua", 7, 1, 1], ["refrigerante", 6, 1, 1], ["suco", 5, 1, 1]],
	"super_hortifruti": [["maca", 6, 1, 1], ["pessego", 3, 1, 1], ["agua", 1, 1, 1]],
	"super_congelados": [["atum", 3, 1, 1], ["sardinha", 3, 1, 1], ["suco", 3, 1, 1], ["agua", 3, 1, 1], ["refrigerante", 2, 1, 1]],
	"super_utilidades": [["pilha", 5, 1, 1], ["lanterna", 4, 1, 1], ["lanterna_cabeca", 2, 1, 1], ["isqueiro", 4, 1, 1], ["fita", 4, 1, 1],
		["corda", 3, 1, 1], ["kit_costura", 3, 1, 1], ["radio", 2, 1, 1], ["faca", 2, 1, 1], ["taco", 2, 1, 1], ["mochila_escolar", 2, 1, 1],
		["pochete", 2, 1, 1], ["capa_chuva", 2, 1, 1], ["gorro", 2, 1, 1], ["camiseta", 2, 1, 1], ["moletom", 1, 1, 1]],
	"super_higiene": [["bandagem", 5, 1, 3], ["analgesico", 4, 1, 1], ["vitaminas", 4, 1, 1], ["trapos", 3, 1, 3], ["pastilha", 3, 2, 6],
		["carvao", 3, 1, 1], ["antibiotico", 1, 1, 1], ["kit_medico", 1, 1, 1]],
	"super_estoque": [["tabuas", 2, 1, 3], ["feijao", 5, 1, 1], ["atum", 4, 1, 1], ["agua", 5, 1, 1], ["refrigerante", 3, 1, 1], ["biscoito", 3, 1, 1],
		["leite_condensado", 3, 1, 1], ["barra", 3, 2, 4], ["fita", 2, 1, 1], ["corda", 2, 1, 1], ["pilha", 2, 1, 1], ["mochila_trilha", 1, 1, 1],
		["lanterna", 1, 1, 1], ["martelo", 1, 1, 1], ["pe_de_cabra", 1, 1, 1]],
	"cofre": [["dinheiro", 8, 50, 300], ["pistola", 3, 1, 1], ["pente_pistola", 3, 1, 1], ["mun_9mm", 4, 8, 24], ["celular", 2, 1, 1],
		["radio", 2, 1, 1], ["lanterna", 1, 1, 1]],
	"armazem_carga": [["galao", 2, 1, 1], ["tabuas", 4, 1, 3], ["jaqueta", 3, 1, 1], ["calca", 3, 1, 1], ["capa_chuva", 3, 1, 1], ["moletom", 3, 1, 1], ["gorro", 2, 1, 1],
		["mochila_trilha", 2, 1, 1], ["mochila_escolar", 2, 1, 1], ["pochete", 2, 1, 1], ["corda", 4, 1, 1], ["fita", 4, 1, 1], ["lanterna", 3, 1, 1],
		["pilha", 3, 1, 1], ["radio", 2, 1, 1], ["kit_costura", 2, 1, 1], ["feijao", 3, 1, 1], ["agua", 3, 1, 1], ["atum", 2, 1, 1],
		["martelo", 2, 1, 1], ["pe_de_cabra", 2, 1, 1], ["machado", 1, 1, 1], ["facao", 1, 1, 1], ["mascara_gas", 1, 1, 1], ["lanterna_cabeca", 1, 1, 1]],
	"armazem_conteiner": [["rifle_caca", 3, 1, 1], ["mun_308", 4, 4, 15], ["luneta", 2, 1, 1], ["espingarda", 3, 1, 1], ["mun_12", 4, 6, 18],
		["ak", 2, 1, 1], ["pente_ak", 2, 1, 1], ["mun_762", 3, 10, 30], ["colete", 2, 1, 1], ["mochila_combate", 2, 1, 1], ["kit_armas", 3, 1, 1],
		["mira_acog", 1, 1, 1], ["silenciador", 1, 1, 1], ["capacete", 1, 1, 1], ["jaqueta", 2, 1, 1], ["calca", 2, 1, 1]],
	"armazem_escritorio": [["dinheiro", 3, 10, 75], ["revista", 2, 1, 1], ["celular", 2, 1, 1], ["radio", 2, 1, 1], ["lanterna", 2, 1, 1],
		["pilha", 2, 1, 1], ["mun_9mm", 2, 4, 12], ["pente_pistola", 1, 1, 1], ["refrigerante", 2, 1, 1], ["barra", 2, 1, 2]],
	"armazem_seguranca": [["pistola", 4, 1, 1], ["pente_pistola", 4, 1, 1], ["mun_9mm", 5, 10, 30], ["espingarda", 2, 1, 1], ["mun_12", 3, 6, 16],
		["colete_policia", 2, 1, 1], ["lanterna", 3, 1, 1], ["radio", 2, 1, 1], ["mp5", 1, 1, 1], ["pente_mp5", 1, 1, 1]],
	# ---- 0.78: DELEGACIA, ESCOLA, METRÔ e QUARTEL (mundo/local_novos.gd) ----
	"delegacia_arsenal": [["pistola", 4, 1, 1], ["pente_pistola", 5, 1, 1], ["mun_9mm", 6, 12, 40], ["espingarda", 3, 1, 1], ["mun_12", 4, 6, 18],
		["mp5", 2, 1, 1], ["pente_mp5", 3, 1, 1], ["m4", 2, 1, 1], ["pente_stanag", 3, 1, 1], ["mun_556", 3, 15, 45], ["colete_policia", 3, 1, 1],
		["capacete", 2, 1, 1], ["mascara_gas", 2, 1, 1], ["kit_armas", 2, 1, 1], ["silenciador", 1, 1, 1], ["mira_acog", 1, 1, 1], ["lanterna", 2, 1, 1]],
	"delegacia_escritorio": [["dinheiro", 3, 10, 75], ["celular", 3, 1, 1], ["radio", 2, 1, 1], ["lanterna", 3, 1, 1], ["pilha", 3, 1, 1],
		["mun_9mm", 3, 4, 14], ["pente_pistola", 1, 1, 1], ["revista", 2, 1, 1], ["refrigerante", 2, 1, 1], ["barra", 2, 1, 2],
		["analgesico", 1, 1, 1], ["isqueiro", 1, 1, 1], ["fita", 1, 1, 1]],
	"delegacia_vestiario": [["colete_policia", 2, 1, 1], ["lanterna", 3, 1, 1], ["lanterna_cabeca", 2, 1, 1], ["jaqueta", 3, 1, 1], ["calca", 3, 1, 1],
		["bone", 3, 1, 1], ["capa_chuva", 2, 1, 1], ["camiseta", 3, 1, 1], ["bandagem", 3, 1, 2], ["mun_9mm", 3, 5, 15], ["pistola", 1, 1, 1],
		["pente_pistola", 1, 1, 1], ["mochila_trilha", 1, 1, 1], ["pochete", 2, 1, 1], ["barra", 1, 1, 2]],
	"delegacia_provas": [["dinheiro", 5, 25, 200], ["pistola", 3, 1, 1], ["faca", 3, 1, 1], ["facao", 2, 1, 1], ["taco", 2, 1, 1], ["celular", 3, 1, 1],
		["mun_9mm", 3, 4, 16], ["mun_12", 2, 3, 10], ["espingarda", 1, 1, 1], ["pastilha", 2, 2, 6], ["analgesico", 2, 1, 1], ["radio", 1, 1, 1],
		["isqueiro", 2, 1, 1], ["ak", 1, 1, 1], ["pente_ak", 1, 1, 1], ["mun_762", 1, 5, 15], ["revista", 1, 1, 1]],
	"viatura": [["espingarda", 3, 1, 1], ["mun_12", 4, 4, 14], ["pistola", 2, 1, 1], ["pente_pistola", 2, 1, 1], ["mun_9mm", 3, 6, 18],
		["colete_policia", 2, 1, 1], ["kit_medico", 1, 1, 1], ["bandagem", 3, 1, 2], ["lanterna", 3, 1, 1], ["radio", 2, 1, 1], ["agua", 1, 1, 1],
		["barra", 1, 1, 2], ["galao", 1, 1, 1]],
	"central_radio": [["radio", 6, 1, 1], ["pilha", 5, 1, 2], ["lanterna", 3, 1, 1], ["celular", 2, 1, 1], ["mun_9mm", 2, 4, 12], ["pente_pistola", 1, 1, 1],
		["barra", 2, 1, 2], ["agua", 2, 1, 1], ["revista", 1, 1, 1], ["fita", 2, 1, 1]],
	"escola_sala": [["mochila_escolar", 5, 1, 1], ["revista", 3, 1, 1], ["barra", 4, 1, 2], ["salgadinho", 3, 1, 1], ["refrigerante", 3, 1, 1],
		["suco", 3, 1, 1], ["lanterna", 2, 1, 1], ["pilha", 2, 1, 1], ["celular", 3, 1, 1], ["dinheiro", 2, 5, 30], ["kit_costura", 1, 1, 1],
		["ursinho", 2, 1, 1], ["fita", 2, 1, 1], ["moletom", 1, 1, 1], ["bone", 1, 1, 1]],
	"escola_armario": [["mochila_escolar", 4, 1, 1], ["moletom", 3, 1, 1], ["camiseta", 3, 1, 1], ["bone", 3, 1, 1], ["gorro", 2, 1, 1],
		["celular", 3, 1, 1], ["barra", 3, 1, 2], ["refrigerante", 3, 1, 1], ["salgadinho", 2, 1, 1], ["revista", 2, 1, 1], ["taco", 2, 1, 1],
		["lanterna", 1, 1, 1], ["dinheiro", 2, 5, 25], ["jaqueta", 1, 1, 1], ["pochete", 1, 1, 1]],
	"escola_cantina": [["feijao", 5, 1, 1], ["atum", 3, 1, 1], ["sardinha", 3, 1, 1], ["pessego", 3, 1, 1], ["biscoito", 4, 1, 1], ["leite_condensado", 3, 1, 1],
		["suco", 4, 1, 1], ["agua", 4, 1, 1], ["maca", 3, 1, 1], ["barra", 2, 1, 2], ["faca", 2, 1, 1], ["isqueiro", 1, 1, 1]],
	"escola_secretaria": [["dinheiro", 3, 10, 60], ["celular", 2, 1, 1], ["radio", 2, 1, 1], ["lanterna", 2, 1, 1], ["pilha", 3, 1, 1], ["revista", 3, 1, 1],
		["fita", 2, 1, 1], ["analgesico", 1, 1, 1], ["refrigerante", 2, 1, 1], ["barra", 2, 1, 2]],
	"escola_enfermaria": [["bandagem", 6, 1, 3], ["analgesico", 5, 1, 1], ["vitaminas", 4, 1, 1], ["trapos", 3, 1, 3], ["tala", 2, 1, 1],
		["antibiotico", 1, 1, 1], ["kit_medico", 1, 1, 1], ["pastilha", 2, 2, 6], ["carvao", 2, 1, 1]],
	"escola_lab": [["carvao", 4, 1, 1], ["pastilha", 4, 2, 8], ["isqueiro", 3, 1, 1], ["fita", 3, 1, 1], ["mascara_gas", 2, 1, 1], ["garrafa_vazia", 3, 1, 1],
		["lanterna", 2, 1, 1], ["pilha", 2, 1, 1], ["antibiotico", 1, 1, 1], ["corda", 1, 1, 1]],
	"escola_biblioteca": [["revista", 6, 1, 1], ["lanterna", 2, 1, 1], ["pilha", 2, 1, 1], ["barra", 2, 1, 1], ["celular", 1, 1, 1], ["mochila_escolar", 2, 1, 1],
		["ursinho", 1, 1, 1], ["kit_costura", 1, 1, 1]],
	"escola_abrigo": [["agua", 5, 1, 1], ["feijao", 4, 1, 1], ["atum", 3, 1, 1], ["biscoito", 3, 1, 1], ["barra", 3, 1, 2], ["bandagem", 3, 1, 2],
		["analgesico", 2, 1, 1], ["lanterna", 3, 1, 1], ["pilha", 3, 1, 2], ["radio", 2, 1, 1], ["ursinho", 2, 1, 1], ["mochila_trilha", 1, 1, 1],
		["trapos", 2, 1, 3], ["taco", 2, 1, 1], ["pistola", 1, 1, 1], ["mun_9mm", 2, 3, 10], ["capa_chuva", 1, 1, 1], ["isqueiro", 2, 1, 1]],
	"onibus_escolar": [["mochila_escolar", 5, 1, 1], ["kit_medico", 2, 1, 1], ["bandagem", 3, 1, 2], ["agua", 3, 1, 1], ["barra", 3, 1, 2], ["salgadinho", 2, 1, 1],
		["lanterna", 2, 1, 1], ["ursinho", 2, 1, 1], ["revista", 2, 1, 1], ["celular", 2, 1, 1], ["galao", 1, 1, 1]],
	"metro_vagao": [["mochila_escolar", 3, 1, 1], ["mochila_trilha", 2, 1, 1], ["pochete", 3, 1, 1], ["celular", 4, 1, 1], ["dinheiro", 3, 10, 75],
		["agua", 3, 1, 1], ["barra", 3, 1, 2], ["salgadinho", 2, 1, 1], ["refrigerante", 2, 1, 1], ["jaqueta", 2, 1, 1], ["capa_chuva", 2, 1, 1],
		["gorro", 2, 1, 1], ["revista", 2, 1, 1], ["analgesico", 2, 1, 1], ["bandagem", 2, 1, 2], ["lanterna", 2, 1, 1], ["isqueiro", 1, 1, 1],
		["pistola", 1, 1, 1], ["mun_9mm", 1, 3, 10], ["faca", 1, 1, 1], ["radio", 1, 1, 1]],
	"metro_bilheteria": [["dinheiro", 6, 25, 150], ["celular", 2, 1, 1], ["radio", 2, 1, 1], ["lanterna", 2, 1, 1], ["pilha", 2, 1, 1], ["barra", 2, 1, 2],
		["refrigerante", 2, 1, 1], ["pistola", 1, 1, 1], ["mun_9mm", 1, 3, 10]],
	"metro_banca": [["revista", 6, 1, 1], ["barra", 4, 1, 3], ["salgadinho", 4, 1, 1], ["refrigerante", 4, 1, 1], ["agua", 3, 1, 1], ["isqueiro", 3, 1, 1],
		["pilha", 2, 1, 1], ["celular", 1, 1, 1], ["dinheiro", 2, 5, 40], ["biscoito", 2, 1, 1]],
	"quartel_arsenal": [["m4", 4, 1, 1], ["ak", 3, 1, 1], ["mp5", 2, 1, 1], ["pente_stanag", 5, 1, 1], ["pente_ak", 4, 1, 1], ["pente_mp5", 3, 1, 1],
		["mun_556", 6, 20, 60], ["mun_762", 5, 20, 50], ["mun_9mm", 3, 15, 40], ["pistola", 2, 1, 1], ["pente_pistola", 2, 1, 1], ["mira_acog", 2, 1, 1],
		["silenciador", 2, 1, 1], ["luneta", 1, 1, 1], ["rifle_caca", 1, 1, 1], ["mun_308", 2, 5, 15], ["colete", 3, 1, 1], ["capacete", 3, 1, 1],
		["mochila_combate", 2, 1, 1], ["kit_armas", 3, 1, 1], ["mascara_gas", 2, 1, 1]],
	"quartel_alojamento": [["camiseta", 3, 1, 1], ["calca", 3, 1, 1], ["jaqueta", 3, 1, 1], ["capa_chuva", 2, 1, 1], ["gorro", 2, 1, 1], ["bone", 2, 1, 1],
		["mochila_combate", 1, 1, 1], ["mochila_trilha", 2, 1, 1], ["lanterna", 3, 1, 1], ["lanterna_cabeca", 2, 1, 1], ["pilha", 3, 1, 2],
		["barra", 3, 1, 2], ["agua", 3, 1, 1], ["feijao", 2, 1, 1], ["mun_556", 2, 10, 30], ["pente_stanag", 1, 1, 1], ["pistola", 1, 1, 1],
		["mun_9mm", 2, 5, 15], ["bandagem", 3, 1, 2], ["isqueiro", 2, 1, 1], ["revista", 2, 1, 1], ["faca", 2, 1, 1], ["facao", 1, 1, 1]],
	# itens soltos no chão dos prédios, por uso do prédio
	"chao_residencial": [["tabuas", 1, 1, 3], ["galho", 2, 1, 3], ["garrafa_vazia", 2, 1, 1], ["revista", 3, 1, 1], ["trapos", 3, 1, 2], ["barra", 2, 1, 1], ["refrigerante", 2, 1, 1], ["agua", 1, 1, 1],
		["cano", 1, 1, 1], ["faca", 1, 1, 1], ["mun_9mm", 1, 3, 8], ["celular", 2, 1, 1], ["ursinho", 1, 1, 1], ["garrafa_vidro", 3, 1, 1], ["tijolo", 2, 1, 2]],
	"chao_comercio": [["garrafa_vazia", 3, 1, 1], ["galho", 1, 1, 2], ["refrigerante", 3, 1, 1], ["salgadinho", 3, 1, 1], ["biscoito", 2, 1, 1], ["dinheiro", 3, 5, 40],
		["revista", 2, 1, 1], ["cano", 2, 1, 1], ["trapos", 2, 1, 2], ["agua", 1, 1, 1], ["garrafa_vidro", 3, 1, 2], ["tijolo", 1, 1, 1]],
	"chao_saude": [["bandagem", 4, 1, 2], ["trapos", 3, 1, 2], ["analgesico", 2, 1, 1], ["soro", 1, 1, 1], ["agua", 1, 1, 1]],
	"chao_posto": [["galao", 1, 1, 1], ["garrafa_vazia", 3, 1, 1], ["refrigerante", 3, 1, 1], ["salgadinho", 2, 1, 1], ["trapos", 3, 1, 2], ["cano", 2, 1, 1],
		["isqueiro", 2, 1, 1], ["fita", 1, 1, 1], ["dinheiro", 2, 5, 30], ["mun_9mm", 1, 3, 8], ["martelo", 1, 1, 1], ["pe_de_cabra", 1, 1, 1]],
	"chao_hospital": [["bandagem", 5, 1, 2], ["trapos", 3, 1, 2], ["analgesico", 3, 1, 1], ["soro", 2, 1, 1], ["antibiotico", 1, 1, 1],
		["tala", 1, 1, 1], ["mun_556", 1, 5, 15], ["mun_9mm", 1, 4, 10], ["agua", 1, 1, 1]],
	"chao_super": [["garrafa_vazia", 2, 1, 1], ["refrigerante", 3, 1, 1], ["biscoito", 3, 1, 1], ["salgadinho", 3, 1, 1], ["feijao", 2, 1, 1],
		["agua", 2, 1, 1], ["dinheiro", 2, 5, 40], ["trapos", 2, 1, 2], ["taco", 1, 1, 1]],
	"chao_armazem": [["tabuas", 2, 1, 3], ["trapos", 3, 1, 3], ["corda", 2, 1, 1], ["fita", 2, 1, 1], ["cano", 3, 1, 1], ["martelo", 1, 1, 1], ["pe_de_cabra", 1, 1, 1], ["galho", 2, 1, 2],
		["agua", 1, 1, 1], ["mun_762", 1, 4, 12], ["mun_12", 1, 3, 8], ["tijolo", 3, 1, 3], ["garrafa_vidro", 1, 1, 1]],
	"chao_policia": [["mun_9mm", 4, 3, 12], ["mun_12", 2, 2, 6], ["pente_pistola", 1, 1, 1], ["bandagem", 2, 1, 1],
		["lanterna", 2, 1, 1], ["cano", 1, 1, 1]],
	"chao_escola": [["revista", 3, 1, 1], ["garrafa_vazia", 3, 1, 1], ["barra", 2, 1, 1], ["refrigerante", 2, 1, 1], ["trapos", 2, 1, 2], ["cano", 1, 1, 1],
		["taco", 1, 1, 1], ["ursinho", 1, 1, 1], ["celular", 1, 1, 1], ["bandagem", 1, 1, 1], ["mun_9mm", 1, 3, 8]],
	"chao_metro": [["garrafa_vazia", 3, 1, 1], ["revista", 2, 1, 1], ["celular", 2, 1, 1], ["dinheiro", 2, 5, 30], ["trapos", 3, 1, 2], ["cano", 2, 1, 1],
		["galho", 1, 1, 2], ["refrigerante", 1, 1, 1], ["mun_9mm", 1, 3, 10], ["martelo", 1, 1, 1], ["pe_de_cabra", 1, 1, 1], ["garrafa_vidro", 3, 1, 2], ["tijolo", 1, 1, 1]],
	# ---- 0.83: BUNKERS (mundo/local_bunker.gd): muito loot, militar e de sobrevivência ----
	"bunker_arsenal": [["m4", 4, 1, 1], ["ak", 4, 1, 1], ["mp5", 3, 1, 1], ["pistola", 3, 1, 1], ["espingarda", 2, 1, 1], ["rifle_caca", 2, 1, 1],
		["pente_stanag", 5, 1, 1], ["pente_ak", 5, 1, 1], ["pente_mp5", 4, 1, 1], ["pente_pistola", 4, 1, 1], ["mun_556", 6, 30, 90],
		["mun_762", 6, 30, 90], ["mun_9mm", 5, 20, 60], ["mun_12", 3, 8, 24], ["mun_308", 3, 10, 30], ["silenciador", 2, 1, 1],
		["mira_acog", 2, 1, 1], ["luneta", 2, 1, 1], ["kit_armas", 3, 1, 1]],
	"bunker_militar": [["colete", 3, 1, 1], ["capacete", 3, 1, 1], ["mochila_combate", 3, 1, 1], ["mascara_gas", 3, 1, 1], ["kit_medico", 3, 1, 1],
		["mun_556", 4, 20, 60], ["mun_762", 4, 20, 60], ["pente_stanag", 2, 1, 1], ["pente_ak", 2, 1, 1], ["radio", 2, 1, 1], ["pilha", 4, 1, 2],
		["lanterna", 2, 1, 1], ["lanterna_cabeca", 2, 1, 1], ["agua", 3, 1, 1], ["feijao", 3, 1, 1], ["barra", 3, 2, 4], ["m4", 1, 1, 1], ["ak", 1, 1, 1]],
	"bunker_med": [["kit_medico", 5, 1, 1], ["soro", 5, 1, 1], ["antibiotico", 5, 1, 1], ["bandagem", 5, 2, 4], ["tala", 3, 1, 1], ["analgesico", 4, 1, 1],
		["vitaminas", 3, 1, 1], ["carvao", 3, 1, 1], ["pastilha", 3, 2, 8], ["mascara_gas", 2, 1, 1]],
	"bunker_comida": [["feijao", 5, 1, 1], ["atum", 5, 1, 1], ["sardinha", 4, 1, 1], ["pessego", 4, 1, 1], ["leite_condensado", 4, 1, 1],
		["biscoito", 4, 1, 1], ["barra", 5, 2, 4], ["agua", 6, 1, 1], ["suco", 3, 1, 1], ["refrigerante", 2, 1, 1]],
	"bunker_deposito": [["agua", 4, 1, 1], ["feijao", 4, 1, 1], ["atum", 3, 1, 1], ["pilha", 5, 1, 2], ["lanterna", 3, 1, 1], ["lanterna_cabeca", 2, 1, 1],
		["radio", 2, 1, 1], ["corda", 3, 1, 1], ["fita", 3, 1, 1], ["tabuas", 2, 1, 3], ["galao", 2, 1, 1], ["mochila_trilha", 2, 1, 1],
		["mochila_combate", 1, 1, 1], ["jaqueta", 2, 1, 1], ["calca", 2, 1, 1], ["capa_chuva", 2, 1, 1], ["gorro", 2, 1, 1],
		["kit_costura", 2, 1, 1], ["isqueiro", 3, 1, 1], ["mascara_gas", 2, 1, 1], ["kit_medico", 1, 1, 1]],
	"bunker_alojamento": [["camiseta", 2, 1, 1], ["calca", 2, 1, 1], ["jaqueta", 2, 1, 1], ["moletom", 2, 1, 1], ["gorro", 2, 1, 1], ["bone", 2, 1, 1],
		["mochila_combate", 1, 1, 1], ["pistola", 1, 1, 1], ["pente_pistola", 2, 1, 1], ["mun_9mm", 3, 10, 30], ["revista", 2, 1, 1],
		["barra", 3, 1, 3], ["agua", 2, 1, 1], ["lanterna", 2, 1, 1], ["pilha", 3, 1, 1], ["faca", 2, 1, 1]],
	"bunker_controle": [["radio", 4, 1, 1], ["pilha", 4, 1, 2], ["lanterna", 2, 1, 1], ["revista", 2, 1, 1], ["mun_9mm", 2, 10, 30], ["pistola", 1, 1, 1],
		["pente_pistola", 2, 1, 1], ["celular", 2, 1, 1], ["lanterna_cabeca", 1, 1, 1], ["agua", 1, 1, 1]],
	"chao_bunker": [["mun_556", 4, 5, 20], ["mun_762", 3, 5, 20], ["mun_9mm", 3, 5, 15], ["pilha", 3, 1, 1], ["bandagem", 3, 1, 2], ["agua", 2, 1, 1],
		["barra", 2, 1, 2], ["feijao", 2, 1, 1], ["pente_stanag", 1, 1, 1], ["trapos", 2, 1, 2], ["lanterna", 1, 1, 1]],
	# 1.06: IGREJA (virou abrigo) e PREFEITURA (comando de crise da evacuação) · mundo/local_igreja.gd
	"igreja_doacoes": [["feijao", 6, 1, 1], ["atum", 5, 1, 1], ["sardinha", 5, 1, 1], ["pessego", 4, 1, 1], ["biscoito", 5, 1, 1],
		["leite_condensado", 3, 1, 1], ["barra", 4, 1, 2], ["agua", 6, 1, 1], ["moletom", 3, 1, 1], ["jaqueta", 2, 1, 1], ["gorro", 3, 1, 1],
		["camiseta", 3, 1, 1], ["calca", 2, 1, 1], ["trapos", 4, 1, 3], ["bandagem", 2, 1, 2], ["ursinho", 1, 1, 1]],
	"igreja_abrigo": [["agua", 5, 1, 1], ["biscoito", 4, 1, 1], ["barra", 4, 1, 2], ["bandagem", 4, 1, 2], ["analgesico", 3, 1, 1],
		["antibiotico", 1, 1, 1], ["lanterna", 3, 1, 1], ["pilha", 4, 1, 1], ["mochila_escolar", 2, 1, 1], ["mochila_trilha", 1, 1, 1],
		["ursinho", 2, 1, 1], ["celular", 3, 1, 1], ["dinheiro", 3, 5, 40], ["faca", 2, 1, 1], ["taco", 1, 1, 1], ["pistola", 1, 1, 1],
		["pente_pistola", 1, 1, 1], ["mun_9mm", 2, 4, 14], ["isqueiro", 3, 1, 1], ["radio", 1, 1, 1]],
	"igreja_sacristia": [["dinheiro", 6, 10, 120], ["isqueiro", 4, 1, 1], ["analgesico", 3, 1, 1], ["bandagem", 3, 1, 2], ["kit_costura", 3, 1, 1],
		["lanterna", 3, 1, 1], ["pilha", 3, 1, 1], ["radio", 2, 1, 1], ["agua", 3, 1, 1], ["garrafa_vidro", 3, 1, 1], ["vitaminas", 2, 1, 1]],
	"igreja_torre": [["rifle_caca", 3, 1, 1], ["mun_308", 4, 3, 12], ["luneta", 1, 1, 1], ["agua", 3, 1, 1], ["barra", 3, 1, 2], ["radio", 2, 1, 1],
		["lanterna", 2, 1, 1], ["pilha", 2, 1, 1], ["moletom", 2, 1, 1], ["bandagem", 2, 1, 2]],
	"chao_igreja": [["trapos", 4, 1, 2], ["garrafa_vazia", 4, 1, 1], ["revista", 2, 1, 1], ["isqueiro", 2, 1, 1], ["biscoito", 2, 1, 1],
		["agua_suja", 2, 1, 1], ["bandagem", 2, 1, 1], ["ursinho", 1, 1, 1], ["pilha", 2, 1, 1], ["celular", 2, 1, 1]],
	"prefeitura_cofre": [["dinheiro", 8, 60, 400], ["pistola", 3, 1, 1], ["pente_pistola", 3, 1, 1], ["mun_9mm", 3, 8, 24], ["celular", 2, 1, 1],
		["radio", 2, 1, 1]],
	"prefeitura_gabinete": [["dinheiro", 5, 20, 150], ["celular", 4, 1, 1], ["radio", 2, 1, 1], ["revista", 3, 1, 1], ["lanterna", 2, 1, 1],
		["pilha", 3, 1, 1], ["isqueiro", 2, 1, 1], ["analgesico", 2, 1, 1], ["pistola", 1, 1, 1], ["pente_pistola", 1, 1, 1]],
	"prefeitura_crise": [["radio", 5, 1, 1], ["pilha", 6, 1, 2], ["lanterna", 4, 1, 1], ["lanterna_cabeca", 2, 1, 1], ["mascara_gas", 2, 1, 1],
		["kit_medico", 1, 1, 1], ["bandagem", 3, 1, 2], ["agua", 4, 1, 1], ["barra", 4, 1, 2], ["feijao", 2, 1, 1], ["colete", 1, 1, 1],
		["colete_policia", 1, 1, 1], ["corda", 2, 1, 1], ["fita", 2, 1, 1]],
	"chao_prefeitura": [["revista", 3, 1, 1], ["celular", 3, 1, 1], ["garrafa_vazia", 3, 1, 1], ["trapos", 2, 1, 2], ["dinheiro", 2, 5, 30],
		["bandagem", 2, 1, 1], ["pilha", 2, 1, 1], ["mun_556", 2, 5, 15], ["pente_stanag", 1, 1, 1], ["agua", 1, 1, 1]],
	# 1.07: PORTO e HANGAR DE CARGA · mundo/local_porto.gd
	"porto_conteiner": [["camiseta", 4, 1, 2], ["moletom", 3, 1, 1], ["jaqueta", 2, 1, 1], ["jeans", 3, 1, 1], ["bone", 2, 1, 1], ["celular", 4, 1, 2],
		["radio", 3, 1, 1], ["lanterna", 4, 1, 1], ["pilha", 5, 1, 3], ["martelo", 2, 1, 1], ["pe_de_cabra", 2, 1, 1], ["corda", 3, 1, 1],
		["fita", 3, 1, 1], ["feijao", 3, 1, 2], ["atum", 3, 1, 2], ["biscoito", 3, 1, 2], ["agua", 3, 1, 2], ["mochila_trilha", 1, 1, 1],
		["kit_costura", 2, 1, 1], ["tabuas", 2, 1, 3]],
	"porto_apreendido": [["pistola", 3, 1, 1], ["pente_pistola", 4, 1, 1], ["mun_9mm", 4, 10, 30], ["espingarda", 2, 1, 1], ["mun_12", 3, 4, 12],
		["ak", 2, 1, 1], ["pente_ak", 2, 1, 1], ["mun_762", 3, 10, 30], ["colete", 1, 1, 1], ["dinheiro", 4, 50, 300], ["celular", 2, 1, 1]],
	"porto_bagagem": [["camiseta", 4, 1, 1], ["moletom", 3, 1, 1], ["jaqueta", 3, 1, 1], ["capa_chuva", 2, 1, 1], ["dinheiro", 4, 10, 120],
		["celular", 3, 1, 1], ["analgesico", 3, 1, 1], ["antibiotico", 1, 1, 1], ["bandagem", 3, 1, 2], ["agua", 3, 1, 1], ["barra", 3, 1, 2],
		["ursinho", 2, 1, 1], ["mochila_escolar", 2, 1, 1], ["mochila_trilha", 1, 1, 1], ["lanterna", 2, 1, 1], ["revista", 2, 1, 1]],
	"porto_navio": [["radio", 5, 1, 1], ["lanterna", 4, 1, 1], ["pilha", 4, 1, 2], ["kit_medico", 2, 1, 1], ["bandagem", 3, 1, 2], ["agua", 3, 1, 2],
		["barra", 3, 1, 2], ["pistola", 2, 1, 1], ["pente_pistola", 2, 1, 1], ["mun_9mm", 2, 6, 18], ["dinheiro", 3, 40, 200], ["capa_chuva", 2, 1, 1],
		["corda", 2, 1, 1], ["mascara_gas", 1, 1, 1]],
	"porto_guindaste": [["radio", 3, 1, 1], ["lanterna", 3, 1, 1], ["pilha", 3, 1, 2], ["martelo", 2, 1, 1], ["fita", 3, 1, 1], ["corda", 2, 1, 1],
		["agua", 3, 1, 1], ["barra", 3, 1, 2], ["capa_chuva", 2, 1, 1], ["kit_armas", 1, 1, 1]],
	"porto_escritorio": [["dinheiro", 4, 10, 80], ["celular", 4, 1, 1], ["radio", 2, 1, 1], ["revista", 3, 1, 1], ["pilha", 3, 1, 1], ["lanterna", 2, 1, 1],
		["isqueiro", 2, 1, 1], ["analgesico", 2, 1, 1], ["barra", 2, 1, 1], ["refrigerante", 2, 1, 1]],
	"porto_carga": [["feijao", 4, 1, 2], ["atum", 4, 1, 2], ["sardinha", 3, 1, 2], ["agua", 4, 1, 2], ["refrigerante", 3, 1, 2], ["tabuas", 3, 1, 3],
		["corda", 2, 1, 1], ["fita", 2, 1, 1], ["galao", 1, 1, 1], ["pe_de_cabra", 1, 1, 1], ["machado", 1, 1, 1]],
	"carga_paletes": [["feijao", 6, 1, 3], ["atum", 5, 1, 3], ["sardinha", 5, 1, 3], ["pessego", 4, 1, 2], ["biscoito", 5, 1, 3], ["leite_condensado", 3, 1, 2],
		["agua", 6, 1, 3], ["refrigerante", 3, 1, 2], ["suco", 3, 1, 2], ["barra", 3, 1, 3], ["vitaminas", 1, 1, 1], ["tabuas", 2, 1, 3]],
	"carga_escritorio": [["dinheiro", 4, 10, 80], ["celular", 3, 1, 1], ["radio", 3, 1, 1], ["pilha", 3, 1, 2], ["revista", 3, 1, 1], ["lanterna", 2, 1, 1],
		["isqueiro", 2, 1, 1], ["refrigerante", 2, 1, 1]],
	"carga_cofre": [["dinheiro", 8, 80, 400], ["pistola", 3, 1, 1], ["pente_pistola", 3, 1, 1], ["mun_9mm", 3, 8, 24], ["celular", 2, 1, 1]],
	"carga_motoristas": [["refrigerante", 4, 1, 2], ["agua", 4, 1, 2], ["biscoito", 3, 1, 1], ["salgadinho", 3, 1, 1], ["jaqueta", 3, 1, 1], ["bone", 3, 1, 1],
		["lanterna", 3, 1, 1], ["isqueiro", 2, 1, 1], ["galao", 2, 1, 1], ["taco", 1, 1, 1], ["espingarda", 1, 1, 1], ["mun_12", 1, 3, 8], ["mochila_trilha", 1, 1, 1]],
	"chao_porto": [["garrafa_vazia", 3, 1, 1], ["trapos", 3, 1, 2], ["revista", 2, 1, 1], ["celular", 2, 1, 1], ["pilha", 2, 1, 1], ["corda", 1, 1, 1],
		["cano", 2, 1, 1], ["fita", 1, 1, 1], ["agua", 1, 1, 1], ["dinheiro", 2, 5, 30]],
	"chao_hangar": [["garrafa_vazia", 3, 1, 1], ["trapos", 3, 1, 2], ["revista", 2, 1, 1], ["pilha", 2, 1, 1], ["cano", 2, 1, 1], ["tabuas", 2, 1, 2],
		["biscoito", 2, 1, 1], ["agua", 1, 1, 1], ["galao", 1, 1, 1], ["fita", 1, 1, 1]],
	"chao_quartel": [["mun_556", 4, 5, 20], ["mun_762", 3, 5, 15], ["mun_9mm", 2, 4, 12], ["pente_stanag", 1, 1, 1], ["bandagem", 3, 1, 2], ["trapos", 2, 1, 2],
		["agua", 2, 1, 1], ["barra", 2, 1, 2], ["feijao", 1, 1, 1], ["garrafa_vazia", 2, 1, 1]],
}
const CHAO_DO_USO := {"igreja": "chao_igreja", "prefeitura": "chao_prefeitura", "porto": "chao_porto", "hangar": "chao_hangar", "residencial": "chao_residencial", "loja": "chao_comercio", "mercado": "chao_comercio",
	"restaurante": "chao_comercio", "escritorio": "chao_comercio", "farmacia": "chao_saude", "clinica": "chao_saude",
	"delegacia": "chao_policia", "posto": "chao_posto", "hospital": "chao_hospital", "supermercado": "chao_super", "armazem": "chao_armazem",
	"escola": "chao_escola", "metro": "chao_metro", "quartel": "chao_quartel", "bunker": "chao_bunker"}

var semente := 1234                   # muda o loot do mundo inteiro (salvo junto com o jogo)
var _grades := {}                     # id do lugar -> grade (já sorteada; o que o jogador mexeu fica aqui)
var _chao := {}                       # id do prédio -> [[item.gd, Vector3 local], ...] (itens soltos ainda não pegos)
# multijogador (rede/sessao_rede.gd): uids dos itens fixos (chão dos prédios "p12:3", base "base:2") que alguém já
# pegou: não aparecem mais em nenhum aparelho · grade_criada avisa a sessão quando um móvel é sorteado (conteúdo base)
var pegos := {}
var grade_criada := Callable()
var grade_reabastecida := Callable()
# 0.73: portas mexidas (mundo/porta.gd): id "p12:3" -> [aberta, tábuas, quebrada, lado das tábuas]; vai no jogo salvo
var portas := {}
var porta_mudou := Callable()          # rede/sessao_rede.gd: manda para todos
# 0.76: carros que viraram veículo e foram mexidos (mundo/veiculos.gd): id "v123_-456" -> estado (posição, giro,
# gasolina, motor, tipo, cor); vai no jogo salvo e na rede
var veiculos := {}

func mudar_porta(id: String, e: Array) -> void:
	portas[id] = e
	if porta_mudou.is_valid():
		porta_mudou.call(id, e)  # 0.72: o loot de uma grade voltou aqui (a sessão manda o conteúdo novo para todos)
# 0.72: relógio do jogo em horas (main.gd liga no clima) e em que ciclo cada lugar foi sorteado/reabastecido
var relogio := Callable()
var _ciclo := {}                      # id da grade -> ciclo
var _ciclo_chao := {}                 # id do prédio -> ciclo do chão

func horas() -> float:
	return float(relogio.call()) if relogio.is_valid() else 0.0

# em que ciclo o lugar está agora (cada lugar com a sua fase: não volta tudo junto)
func ciclo(id: String) -> int:
	var c := CICLO_LOCAL if id.begins_with("L") else CICLO
	var fase := float(absi(hash(id + "fase")) % 1000) / 1000.0 * c
	return floori((horas() + fase) / c)

# o relógio pulou (o cliente recebeu a hora do host): o que já foi sorteado conta como deste ciclo
func sincronizar_ciclos() -> void:
	for id in _grades:
		_ciclo[id] = ciclo(id)
	for id in _ciclo_chao:
		_ciclo_chao[id] = ciclo(id)

# grade de um móvel / porta-malas (sorteada na 1ª vez, depois a mesma)
func grade(id: String, tabela: String, nome: String, tam: Vector2i, vazio := CHANCE_VAZIO):
	if _grades.has(id):
		var g0 = _grades[id]
		g0.nome = nome
		_reabastecer(id, g0, tabela, tam, vazio)
		return g0
	var g = GradeCls.new(tam.x, tam.y, nome, null)
	_encher(g, tabela, tam, vazio, hash(id) ^ semente)
	_grades[id] = g
	_ciclo[id] = ciclo(id)
	if grade_criada.is_valid():
		grade_criada.call(id, g)
	return g

func _encher(g, tabela: String, tam: Vector2i, vazio: float, sem: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = sem
	if r.randf() >= vazio:
		var n := r.randi_range(1, clampi(tam.x * tam.y / 5, 1, 4))
		for k in n:
			# só sorteia o que cabe no móvel; se a grade já estiver cheia, tenta outro item (até 3 vezes)
			for tentativa in 3:
				var it = _sortear(tabela, r, tam)
				if it == null:
					break
				var v: Vector3i = g.achar_vaga(it)
				if v.x >= 0:
					g.colocar(it, v.x, v.y, v.z == 1)
					break

# 0.72: passou um ciclo desde o último sorteio deste lugar -> sorteio novo, que só COMPLETA (não apaga nada)
func _reabastecer(id: String, g, tabela: String, tam: Vector2i, vazio: float) -> void:
	var agora := ciclo(id)
	var antes: int = _ciclo.get(id, agora)
	_ciclo[id] = agora
	if agora <= antes:
		return
	var novo = GradeCls.new(tam.x, tam.y, "", null)
	_encher(novo, tabela, tam, vazio, (hash(id) ^ semente) + agora * 7919)
	var alvo: int = novo.itens.size()
	var n: int = g.itens.size()
	var mudou := false
	for it in novo.itens.duplicate():
		if n >= alvo:
			break
		novo.remover(it)
		var v: Vector3i = g.achar_vaga(it)
		if v.x >= 0:
			g.colocar(it, v.x, v.y, v.z == 1)
			n += 1
			mudou = true
	if mudou and grade_reabastecida.is_valid():
		grade_reabastecida.call(id, g)

# itens soltos no chão de um prédio (pontos = meta "pontos_chao" do interior: [[Vector3 local, cômodo], ...])
func espalhar_chao(id: String, uso: String, pontos: Array, pai: Node3D) -> void:
	var agora := ciclo(id)
	if not _chao.has(id):
		_chao[id] = _sortear_chao(id, uso, pontos, 0, int(MAX_CHAO_USO.get(uso, MAX_CHAO)), [])
		_ciclo_chao[id] = agora
	elif int(_ciclo_chao.get(id, agora)) < agora:
		# 0.72: o chão do prédio ganha coisa nova (até MAX_CHAO contando o que ainda está lá)
		var ficou: Array = []
		for par in _chao[id]:
			if not pegos.has(par[0].uid):
				ficou.append(par)
		_chao[id] = ficou + _sortear_chao(id, uso, pontos, agora, int(MAX_CHAO_USO.get(uso, MAX_CHAO)) - ficou.size(), ficou)
		_ciclo_chao[id] = agora
	else:
		_ciclo_chao[id] = agora
	for par in _chao[id]:
		var it = par[0]
		if it.no_mundo != null or it.onde != null or it.slot != "" or pegos.has(it.uid):
			continue
		ItemMundoCls.soltar(pai, it, pai.global_transform * (par[1] as Vector3), false)
	_chao[id] = []                    # agora os itens estão no mundo; ao fechar o prédio, guardar_chao devolve

# sorteio do chão · ciclo 0 = o 1º (uid "p12:3", como antes) · ciclos seguintes têm uid próprio ("p12:5:0")
func _sortear_chao(id: String, uso: String, pontos: Array, c: int, maximo: int, ocupados: Array) -> Array:
	var lista := []
	var r := RandomNumberGenerator.new()
	r.seed = (hash(id + "chao") ^ semente) + c * 7919
	var tabela: String = CHAO_DO_USO.get(uso, "chao_residencial")
	for p in pontos:
		if lista.size() >= maximo:
			break
		if r.randf() < CHANCE_CHAO:
			var it = _sortear(tabela, r)
			if it == null:
				continue
			var livre := true
			for par in ocupados:
				if (par[1] as Vector3).distance_to(p[0]) < 0.6:
					livre = false
					break
			if not livre:
				continue
			it.uid = ("%s:%d" % [id, lista.size()]) if c == 0 else ("%s:%d:%d" % [id, c, lista.size()])   # igual em todos os aparelhos
			lista.append([it, p[0]])
	return lista

# o prédio vai fechar: guarda o que ainda está no chão dele (posição local)
func guardar_chao(id: String, pai: Node3D) -> void:
	var lista := []
	for n in pai.get_children():
		if n.is_in_group("itens_chao") and not n.is_queued_for_deletion() and n.item != null:
			var it = n.item
			it.no_mundo = null
			lista.append([it, pai.global_transform.affine_inverse() * n.global_position])
	_chao[id] = lista

# ---------- 0.83: CARTÕES DE ACESSO DOS BUNKERS ----------
# Cada vez que uma ÁREA MILITAR (mundo/locais.gd AREAS_MILITARES) é montada num ciclo novo do loot, CHANCE_CARTAO de
# um cartão aparecer numa das caixas militares dela. Só existe UM cartão de cada bunker: depois de sorteado ele fica
# registrado em "cartoes" (vai no jogo salvo) e só volta a poder aparecer se sumir de vez do mundo (jogando sozinho:
# não está em nenhum móvel, chão ou com o jogador). Em rede só o host sorteia (o cliente recebe a caixa pronta).
var cartoes := {}                     # "3" -> true: o cartão do bunker 3 já apareceu
var _ciclo_cartao := {}               # id da área -> ciclo em que já tentou
var sorteia_cartoes := true           # main.gd: false no cliente em rede
var verifica_perdidos := true         # main.gd: false em rede (não dá para ver o inventário dos outros)
var procurar_item := Callable()       # main.gd: (id) -> bool: está no chão do mundo ou com o jogador?

func tentar_cartao(area: String, ids: Array, n_bunkers: int) -> int:
	if not sorteia_cartoes or ids.is_empty() or n_bunkers <= 0:
		return 0
	var agora := ciclo(area)
	if int(_ciclo_cartao.get(area, -999999)) >= agora:
		return 0
	_ciclo_cartao[area] = agora
	var r := RandomNumberGenerator.new()
	r.seed = (hash(area + "cartao") ^ semente) + agora * 7919
	if r.randf() >= CHANCE_CARTAO:
		return 0
	var livres: Array = []
	for k in range(1, n_bunkers + 1):
		if not cartoes.has(str(k)) or (verifica_perdidos and not cartao_existe(k)):
			livres.append(k)
	if livres.is_empty():
		return 0
	var num: int = livres[r.randi() % livres.size()]
	var it = ItemCls.novo("cartao_bunker_%d" % num)
	var ordem := ids.duplicate()
	for i in range(ordem.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = ordem[i]
		ordem[i] = ordem[j]
		ordem[j] = tmp
	for gid in ordem:
		var g = _grades.get(gid)
		if g == null:
			continue
		var v: Vector3i = g.achar_vaga(it)
		if v.x < 0:
			continue
		g.colocar(it, v.x, v.y, v.z == 1)
		cartoes[str(num)] = true
		if grade_reabastecida.is_valid():
			grade_reabastecida.call(gid, g)
		return num
	return 0

# o cartão do bunker n ainda existe em algum lugar (móvel, chão guardado, chão do mundo, com o jogador)?
func cartao_existe(n: int) -> bool:
	var id := "cartao_bunker_%d" % n
	for gid in _grades:
		if _grade_tem(_grades[gid], id):
			return true
	for k in _chao:
		for par in _chao[k]:
			if par[0].id == id:
				return true
	return procurar_item.is_valid() and bool(procurar_item.call(id))

static func _grade_tem(g, id: String) -> bool:
	if g == null:
		return false
	for it in g.itens:
		if it.id == id:
			return true
		if it.has_method("grades"):
			for g2 in it.grades():
				if _grade_tem(g2, id):
					return true
	return false

# ---------- multijogador: conteúdo das grades pela rede ----------
# "assinatura" curta do conteúdo (muda quando alguém põe/tira/gira/gasta algo)
static func assinatura(g) -> String:
	var s := PackedStringArray()
	for it in g.itens:
		s.append("%s,%d,%d,%d,%d,%d" % [it.id, it.qtd, it.x, it.y, int(it.rot), it.municao])
	return "|".join(s)

static func conteudo(g) -> Array:
	var l := []
	for it in g.itens:
		l.append(it.para_dict())
	return l

# troca o conteúdo da grade "id" pelo que veio da rede (cria a grade se este aparelho ainda não abriu o lugar)
func definir_conteudo(id: String, larg: int, alt: int, nome: String, itens: Array):
	var g = _grades.get(id)
	if g == null:
		g = GradeCls.new(larg, alt, nome, null)
		_grades[id] = g
	for it in g.itens.duplicate():
		g.remover(it)
	for od in itens:
		var it = ItemCls.de_dict(od)
		if it != null:
			g.colocar(it, it.x, it.y, it.rot)
	_ciclo[id] = ciclo(id)                 # veio da rede: já é deste ciclo (não reabastece de novo aqui)
	return g

func _sortear(tabela: String, r: RandomNumberGenerator, tam := Vector2i(99, 99)):
	var t: Array = []
	for e in TABELAS.get(tabela, []):            # só o que cabe no móvel (deitado ou em pé)
		var d := Itens.def(e[0])
		var w := int(d.get("w", 1))
		var h := int(d.get("h", 1))
		if (w <= tam.x and h <= tam.y) or (h <= tam.x and w <= tam.y):
			t.append(e)
	var total := 0.0
	for e in t:
		total += float(e[1])
	if total <= 0.0:
		return null
	var x := r.randf() * total
	for e in t:
		x -= float(e[1])
		if x <= 0.0:
			if Itens.def(e[0]).is_empty():
				return null
			var it = ItemCls.novo(e[0], r.randi_range(int(e[2]), int(e[3])))
			_estado_inicial(it, r)
			return it
	return null

# cidade abandonada: as coisas não estão novas; armas vêm com o pente pela metade (ou sem) e munição solta
func _estado_inicial(it, r: RandomNumberGenerator) -> void:
	if it.id == "galao":
		it.carga = 0.0 if r.randf() < 0.5 else r.randf_range(0.15, 1.0)      # 0.76: metade vem vazio
	var x := r.randf()
	it.estado = 1.0 if x < 0.3 else (r.randf_range(0.55, 0.95) if x < 0.75 else r.randf_range(0.2, 0.55))
	if it.eh_arma_de_fogo():
		if it.usa_pente() != "":
			if r.randf() < 0.4:
				it.pente_id = ""
				it.municao = 0
			else:
				it.municao = r.randi_range(0, it.capacidade())
		else:
			it.municao = r.randi_range(0, it.capacidade() / 2)
	elif it.eh_pente():
		it.municao = r.randi_range(0, it.capacidade())

# ---------- salvar ----------
# abertos = interiores.abertos (índice -> nó): o que está no chão dos prédios abertos AGORA também é salvo
# (sem mexer nos itens, que continuam no mundo)
func salvar(abertos := {}, locais_abertos := {}) -> Dictionary:
	var g := {}
	for id in _grades:
		var lista := []
		for it in _grades[id].itens:
			lista.append(it.para_dict())
		g[id] = lista
	var c := {}
	for id in _chao:
		var lista := []
		for par in _chao[id]:
			var p: Vector3 = par[1]
			lista.append([par[0].para_dict(), p.x, p.y, p.z])
		c[id] = lista
	for i in abertos:
		var no: Node3D = abertos[i]
		if not is_instance_valid(no):
			continue
		var lista := []
		for n in no.get_children():
			if n.is_in_group("itens_chao") and not n.is_queued_for_deletion() and n.item != null:
				var p: Vector3 = no.global_transform.affine_inverse() * n.global_position
				lista.append([n.item.para_dict(), p.x, p.y, p.z])
		c["p%d" % i] = lista
	for i in locais_abertos:                   # 0.68: chão dos locais especiais abertos ("L3")
		var no: Node3D = locais_abertos[i]
		if not is_instance_valid(no):
			continue
		var lista := []
		for n in no.get_children():
			if n.is_in_group("itens_chao") and not n.is_queued_for_deletion() and n.item != null:
				var p: Vector3 = no.global_transform.affine_inverse() * n.global_position
				lista.append([n.item.para_dict(), p.x, p.y, p.z])
		c["L%d" % i] = lista
	return {"semente": semente, "grades": g, "chao": c, "ciclos": _ciclo.duplicate(), "ciclos_chao": _ciclo_chao.duplicate(), "portas": portas.duplicate(), "veiculos": veiculos.duplicate(true),
		"cartoes": cartoes.duplicate(), "ciclo_cartao": _ciclo_cartao.duplicate()}

func carregar(d: Dictionary) -> void:
	semente = int(d.get("semente", semente))
	_grades.clear()
	_chao.clear()
	_ciclo.clear()
	_ciclo_chao.clear()
	portas = (d.get("portas", {}) as Dictionary).duplicate()
	veiculos = (d.get("veiculos", {}) as Dictionary).duplicate(true)
	cartoes = (d.get("cartoes", {}) as Dictionary).duplicate()
	_ciclo_cartao = (d.get("ciclo_cartao", {}) as Dictionary).duplicate()
	var g: Dictionary = d.get("grades", {})
	for id in g:
		var gr = GradeCls.new(12, 12, "", null)
		for od in g[id]:
			var it = ItemCls.de_dict(od)
			if it != null:
				gr.colocar(it, it.x, it.y, it.rot)
		_grades[id] = gr
	var c: Dictionary = d.get("chao", {})
	for id in c:
		var lista := []
		for e in c[id]:
			var it = ItemCls.de_dict(e[0])
			if it != null:
				lista.append([it, Vector3(e[1], e[2], e[3])])
		_chao[id] = lista
	# 0.72: ciclo de cada lugar (save antigo não tem: conta como do ciclo de agora, volta no próximo)
	var cg: Dictionary = d.get("ciclos", {})
	for id in _grades:
		_ciclo[id] = int(cg[id]) if cg.has(id) else ciclo(id)
	var cc: Dictionary = d.get("ciclos_chao", {})
	for id in _chao:
		_ciclo_chao[id] = int(cc[id]) if cc.has(id) else ciclo(id)
