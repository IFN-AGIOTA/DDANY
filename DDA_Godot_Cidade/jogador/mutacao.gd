extends RefCounted
# MUTAÇÃO DO JOGADOR (0.94) · lore (Bíblia 2.7): o mutado é o vírus "aprendendo" num corpo que MORREU. Quem morre
# pelos infectados (golpe, puxado para o chão ou o vírus) tem CHANCE de 1% de não morrer: o corpo fica no chão uns
# segundos e LEVANTA MUTADO, com tudo o que carregava (main.gd: _morreu / _mutar).
# Mutado (nível 1):
#   - os INFECTADOS IGNORAM ele (não veem, não ouvem os passos, não atacam · inimigos/vagos.gd e vago.gd);
#   - mais RESISTENTE (leva menos dano, sangra menos, sem vírus/infecção), mais RÁPIDO, PULA mais alto, cansa menos;
#   - GARRAS no lugar dos punhos e ARMAS BRANCAS mais fortes; COLETA arma de fogo e qualquer item, mas NÃO USA arma
#     de fogo (armas/armas.gd);
#   - pele escura com VEIOS VERMELHOS que pulsam, olhos amarelados e corpo CURVADO (jogador/modelo_sobrevivente.gd e
#     jogador/camada_mutado.gd); os amigos veem assim também (rede: bit 512 do estado);
#   - os sobreviventes do hospital não negociam com ele (npc/hospitais.gd).
#   - MORREU de novo = volta HUMANO normal (sobrevivencia.reiniciar zera a mutação).
# Nível 2 (CONTROLADO, para a 2ª parte: o soro que devolve o controle, ainda não existe no jogo): mais rápido,
# resistente e com pulo maior que um humano e usa as garras, mas mais fraco que o mutado completo.
# Mexa AQUI para: a chance, as causas e os números de cada nível.

const CHANCE := 0.01
const CAUSAS := ["infectados", "puxado para o chão pelos infectados", "o vírus"]
const TEMPO_LEVANTAR := 6.0             # segundos caído antes de levantar mutado
# nível -> números (1,0 = como o humano)
const NIVEIS := {
	1: {"vel": 1.22, "pulo": 1.4, "dano": 0.45, "sangra": 0.4, "estamina": 0.5, "queda": 1.35,
		"garras": 30.0, "branca": 1.3, "ignorado": true, "arma_fogo": false},
	2: {"vel": 1.1, "pulo": 1.2, "dano": 0.7, "sangra": 0.7, "estamina": 0.75, "queda": 1.15,
		"garras": 20.0, "branca": 1.1, "ignorado": false, "arma_fogo": true},
}
const NOMES := {1: "MUTADO", 2: "CONTROLADO"}

static var forcar := false              # testes: a próxima morte por infectado sempre muta

# morreu disso: levanta mutado? (já mutado morre de verdade)
static func sorteia(causa: String, nivel_atual: int) -> bool:
	if nivel_atual != 0 or not causa in CAUSAS:
		return false
	if forcar:
		forcar = false
		return true
	return randf() < CHANCE

static func valor(nivel: int, chave: String, padrao = 1.0):
	return NIVEIS[nivel].get(chave, padrao) if NIVEIS.has(nivel) else padrao
