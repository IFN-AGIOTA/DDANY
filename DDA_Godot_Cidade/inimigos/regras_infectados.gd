extends RefCounted
# REGRAS DOS INFECTADOS (0.89 · estilo PROJECT ZOMBOID): as opções de Opções › Infectados (as "sandbox" do Project
# Zomboid) viradas em números. Quem usa: inimigos/vago.gd (cada infectado), inimigos/vagos.gd (barulho, ataques)
# inimigos/horda.gd (população, hordas) e jogador/sobrevivencia.gd (ferimentos e o vírus).
# Na lore (Bíblia, 2.5/2.7) o infectado comum é "lento, tropeça, avança em massa", anda em HORDAS e é atraído por
# BARULHO e CHEIRO de gente viva: por isso o padrão é "Lentos" (os "shamblers" do Project Zomboid) e eles também
# sentem o CHEIRO de quem está perto (mais longe se estiver sangrando).
# Mexa AQUI para: velocidades de cada tipo, alcance da visão/audição/cheiro, memória, população, chances dos ferimentos.

# ----- velocidade (m/s). O jogador: devagar 1,0 · andando 2,0 · trote 3,9 · correndo 7,2 -----
# lento = "shambler" (mais devagar que você andando) · rápido = "fast shambler" (arrasta os pés depressa: andando você
# não escapa, no trote sim) · corredor = "sprinter" (corre quase como você) · rastejante = 1/5 de quem anda
const VEL := {
	"lento": {"vagar": Vector2(0.3, 0.5), "ir": Vector2(0.75, 0.95), "cacar": Vector2(0.95, 1.2)},
	"rapido": {"vagar": Vector2(0.45, 0.7), "ir": Vector2(1.3, 1.6), "cacar": Vector2(2.2, 2.6)},
	"corredor": {"vagar": Vector2(0.5, 0.8), "ir": Vector2(1.3, 1.6), "cacar": Vector2(5.3, 6.0)},
	"rastejante": {"vagar": Vector2(0.08, 0.12), "ir": Vector2(0.18, 0.22), "cacar": Vector2(0.22, 0.28)},
	# 1.00 · MUTADO (lore, Bíblia 2.7: "muito rápido; corre e salta como animal"): corre como você no sprint
	"mutado": {"vagar": Vector2(0.7, 1.0), "ir": Vector2(3.0, 3.6), "cacar": Vector2(7.0, 7.6)},
}
# ----- 1.00 · MUTADOS (especiais raros; quem os solta é o Diretor, inimigos/diretor.gd) -----
const MUTADO_VIDA := 2.2              # aguenta 2,2x mais que o comum
const MUTADO_DANO := 1.4
const MUTADO_CHEIRO := 8.0            # m: fareja gente viva ...
const MUTADO_CHEIRO_SANGUE := 40.0    # ... e sangue de BEM longe (lore)
const MUTADO_SALTO := Vector2(3.5, 7.0)   # m: de quanto ele salta em cima de você
# "misto" (o "Random" do Project Zomboid): chance de cada um
const MISTO := {"lento": 0.72, "rapido": 0.2, "corredor": 0.08}
const CHANCE_RASTEJANTE := 0.03       # já nascem rastejando (pernas ruins)
const CHANCE_FINGINDO := 0.06         # deitados no chão "fingindo de morto" (levantam quando você chega perto)

# ----- sentidos -----
const VISAO_DIA := 22.0               # m (≈ 20 "tiles" do Project Zomboid de dia)
const VISAO_ESCURO := 5.0             # noite sem luz: só de pertinho
const VISAO_LANTERNA := 26.0          # noite com a lanterna acesa: a luz denuncia
const CONE := 120.0                   # graus à frente (atrás ele não vê: só ouve/cheira)
const CHEIRO := 3.5                   # m: sente o cheiro de gente viva (atravessa parede pela metade)
const CHEIRO_SANGUE := 9.0            # sangrando: de bem mais longe
# multiplicadores das opções (0, 1, 2)
const MULT_VISAO := [0.55, 1.0, 1.5]          # ruim · normal · águia
const MULT_AUDICAO := [0.55, 1.0, 1.4]        # ruim · normal · exata
const ERRO_AUDICAO := [1.8, 1.0, 0.0]         # quanto ele erra o lugar do barulho (exata = vai no ponto)
const MEMORIA := [3.0, 20.0, 60.0, 120.0]     # s procurando você depois de te perder (nenhuma · curta · normal · longa)
const MULT_FORCA := [0.6, 1.0, 1.5]           # dano da mordida: fraca · normal · sobre-humana
const MULT_VIDA := [0.6, 1.0, 1.6]            # aguenta: frágil · normal · resistente
const MULT_POP := [0.4, 1.0, 2.0, 3.0]        # população: pouca · normal · muita · insana

# ----- barulho (raio em metros) -----
const PASSO_AGACHADO := 2.5
const PASSO_DEVAGAR := 3.5
const PASSO_ANDANDO := 7.0
const PASSO_TROTE := 14.0
const PASSO_CORRENDO := 20.0
const GOLPE_PORTA := 18.0             # cada pancada de um infectado numa porta (chama os outros)
const SEGUIR_SOM := 100.0             # a horda (inimigos/horda.gd) vem atrás de barulho até essa distância

# ----- ataque -----
# ferimento de cada mordida que passa pela roupa: [arranhão, laceração, mordida] (somam 1) e a chance de pegar o vírus
const FERIDA := [0.55, 0.3, 0.15]
const FERIDA_POR_TRAS := [0.35, 0.3, 0.35]    # pelas costas, a mordida é bem mais provável
const VIRUS := {"arranhao": 0.07, "laceracao": 0.25, "mordida": 1.0}
const CHANCE_AGARRAR := 0.35          # depois do golpe ele te segura um instante (você anda devagar)
const DERRUBAR_N := 3                 # tantos infectados te acertando juntos (em DERRUBAR_JANELA s) = te puxam para o chão
const DERRUBAR_JANELA := 1.6

# ----- população (inimigos/horda.gd) -----
const CRESCE_ATE := 1.5               # a população sobe devagar até 1,5x ...
const DIA_PICO := 28.0                # ... no dia 28 (igual ao Project Zomboid)
const GRUPO_MAX := 20                 # "rally group size": até tantos andam juntos
const GRUPO_JUNTAR := 20.0            # "rally travel distance": grupos parados a menos disso se juntam
const GRUPO_SEPARAR := 15.0           # "rally group separation"
const REDISTRIBUIR_H := 12.0          # a cada 12 horas do jogo parte das hordas migra
const REAPARECER_H := 72.0            # "respawn hours": lugar esvaziado volta a ter infectados ...
const SEM_VER_H := 16.0               # ... se ninguém passou por lá nessas horas ...
const REAPARECER_FRACAO := 0.1        # ... 10% do que tinha de cada vez

static func _cfg():
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("Config")
	return null

static func valor(chave: String, padrao):
	var c = _cfg()
	if c == null:
		return padrao
	var o: Dictionary = c.get("o")
	return o.get(chave, padrao)

static func _i(chave: String, padrao: int, n: int) -> int:
	return clampi(int(valor(chave, padrao)), 0, n - 1)

static func mult_visao() -> float: return MULT_VISAO[_i("z_visao", 1, 3)]
static func mult_audicao() -> float: return MULT_AUDICAO[_i("z_audicao", 1, 3)]
static func erro_audicao() -> float: return ERRO_AUDICAO[_i("z_audicao", 1, 3)]
static func memoria() -> float: return MEMORIA[_i("z_mem", 2, 4)]
static func mult_forca() -> float: return MULT_FORCA[_i("z_forca", 1, 3)]
static func mult_vida() -> float: return MULT_VIDA[_i("z_resist", 1, 3)]
static func mult_pop() -> float: return MULT_POP[_i("z_pop", 1, 4)]
static func abrem_portas() -> bool: return int(valor("z_cog", 0)) == 1
static func derrubam() -> bool: return bool(valor("z_derrubar", true))
# 1.00: mutados: 0 = não aparecem · 1 = raros · 2 = frequentes
static func mutados() -> int: return _i("z_mutados", 1, 3)
static func reaparecem() -> bool: return bool(valor("z_reaparecer", true))
# transmissão: 0 = sangue e saliva (arranhão, laceração e mordida podem passar) · 1 = só mordida · 2 = desligada
static func transmissao() -> int: return _i("z_trans", 0, 3)
# horas do jogo até o vírus matar (fase febril): 0 = 6-12 h · 1 = 1-2 dias · 2 = 2-3 dias (padrão) · 3 = 1 semana
static func horas_virus() -> Vector2:
	return [Vector2(6, 12), Vector2(24, 48), Vector2(48, 72), Vector2(150, 190)][_i("z_morte", 2, 4)]
# só de dia / só de noite (os inativos ficam parados e quase não sentem nada)
static func ativo_agora(escuridao: float) -> bool:
	match str(valor("z_ativos", "ambos")):
		"dia": return escuridao < 0.5
		"noite": return escuridao >= 0.5
	return true

# tipo de andar de um infectado novo (pela opção Velocidade)
static func sortear_classe(rng: RandomNumberGenerator = null) -> String:
	var x := rng.randf() if rng != null else randf()
	match str(valor("z_vel", "lentos")):
		"rapidos": return "rapido"
		"corredores": return "corredor"
		"misto":
			for k in MISTO:
				x -= float(MISTO[k])
				if x <= 0.0:
					return k
			return "lento"
	return "lento"

static func vel(classe: String, modo: String, rng: RandomNumberGenerator = null) -> float:
	var v: Vector2 = (VEL.get(classe, VEL["lento"]) as Dictionary)[modo]
	return lerpf(v.x, v.y, rng.randf() if rng != null else randf())

# quanto a população já cresceu (1,0 no dia 1 até CRESCE_ATE no DIA_PICO)
static func crescimento(dia: float) -> float:
	return lerpf(1.0, CRESCE_ATE, clampf((dia - 1.0) / (DIA_PICO - 1.0), 0.0, 1.0))
