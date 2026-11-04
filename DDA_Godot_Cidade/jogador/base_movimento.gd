extends RefCounted
# 1.12 · "MOTION MATCHING" DO JOGO (correspondência de movimento, como o Game Animation Sample da Unreal 5).
# A biblioteca (jogador/sobrevivente/base_movimento_<m|f>.json, feita por ferramentas/gerar_base_movimento.gd) tem,
# para cada quadro de cada animação de locomoção, onde estão os dois pés e para onde vão (em relação ao quadril).
# buscar() recebe a velocidade que o personagem tem (de lado, para a frente) e o quadro que está tocando agora, e
# devolve a animação, o QUADRO e a velocidade de tocar que melhor continuam o movimento:
#   custo = velocidade (a animação, na escala escolhida, anda na velocidade/direção pedida)
#         + escala (prefere a animação na velocidade natural dela)
#         + pose (os pés no mesmo lugar e indo para o mesmo lado: o passo continua, sem "pulo" de pé)
# O animador (jogador/animador_modelo.gd) só troca se a melhor for bem melhor que continuar (sem ficar trocando).
# Mexa AQUI para: os pesos (P_*) e os limites de escala.

const P_VEL := 1.0        # erro de velocidade (m/s)²
const P_ESCALA := 2.5     # tocar longe da velocidade natural (log da escala)²
const P_POS := 4.0        # posição dos pés (m)²
const P_VPE := 0.012      # velocidade dos pés (m/s)²
const ESCALA_MIN := 0.55
const ESCALA_MAX := 1.6
const PARADO_ATE := 0.25  # m/s: abaixo disto quer ficar parado

static var _cache := {}

var hz := 30.0
var clipes := {}          # nome -> {"dir": Vector2, "ref": float, "duracao": float, "q": Array[PackedFloat32Array]}

static func carregar(sexo: String):
	if _cache.has(sexo):
		return _cache[sexo]
	var p := "res://jogador/sobrevivente/base_movimento_%s.json" % sexo
	if not FileAccess.file_exists(p):
		_cache[sexo] = null
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (d is Dictionary):
		_cache[sexo] = null
		return null
	var b = load("res://jogador/base_movimento.gd").new()
	b.hz = float(d.get("hz", 30.0))
	for nome in d["clipes"]:
		var c: Dictionary = d["clipes"][nome]
		var qs: Array = []
		for q in c["quadros"]:
			qs.append(PackedFloat32Array(q))
		b.clipes[nome] = {"dir": Vector2(c["dir"][0], c["dir"][1]), "ref": float(c["ref"]), "duracao": float(c["duracao"]), "q": qs}
	_cache[sexo] = b
	return b

func tem(nome: String) -> bool:
	return clipes.has(nome)

# quadro (os 12 números: pés e velocidades) de uma animação num tempo
func quadro(nome: String, t: float) -> PackedFloat32Array:
	var c: Dictionary = clipes[nome]
	var qs: Array = c["q"]
	var k := int(fposmod(t, maxf(c["duracao"], 0.001)) * hz) % qs.size()
	return qs[k]

# escala de tocar para a animação andar na velocidade v
func escala(nome: String, v: float) -> float:
	var r: float = clipes[nome]["ref"]
	if r <= 0.0:
		return 1.0
	return clampf(v / r, ESCALA_MIN, ESCALA_MAX)

# custo da velocidade (e da escala) de usar a animação "nome" para andar com "vel" (lado, frente)
func custo_velocidade(nome: String, vel: Vector2) -> float:
	var c: Dictionary = clipes[nome]
	var r: float = c["ref"]
	var v := vel.length()
	if r <= 0.0:
		return P_VEL * v * v * 3.0 + (0.0 if v < PARADO_ATE else 1.0)
	if v < PARADO_ATE:
		return 50.0
	var s := escala(nome, v)
	var prevista: Vector2 = c["dir"] * r * s
	var e := vel - prevista
	var l := log(v / r)
	return P_VEL * e.length_squared() + P_ESCALA * l * l

func custo_pose(a: PackedFloat32Array, sa: float, b: PackedFloat32Array, sb: float) -> float:
	var cp := 0.0
	for i in 6:
		var d := a[i] - b[i]
		cp += d * d
	var cv := 0.0
	for i in range(6, 12):
		var d := a[i] * sa - b[i] * sb
		cv += d * d
	return P_POS * cp + P_VPE * cv

# melhor [nome, tempo, escala, custo] entre as animações permitidas, partindo da pose q_atual (12 números: pés e
# velocidades, que valem vezes s_atual; vazia = só pela velocidade)
func buscar(permitidas: Array, vel: Vector2, q_atual: PackedFloat32Array, s_atual: float) -> Array:
	var tem_atual := q_atual.size() == 12
	var melhor := ["", 0.0, 1.0, INF]
	for nome in permitidas:
		if not clipes.has(nome):
			continue
		var cv := custo_velocidade(nome, vel)
		if cv >= melhor[3]:
			continue
		var s := escala(nome, vel.length())
		var qs: Array = clipes[nome]["q"]
		if not tem_atual:
			if cv < melhor[3]:
				melhor = [nome, 0.0, s, cv]
			continue
		for k in qs.size():
			var custo := cv + custo_pose(q_atual, s_atual, qs[k], s)
			if custo < melhor[3]:
				melhor = [nome, k / hz, s, custo]
	return melhor

# custo de CONTINUAR na animação atual (o quadro seguinte é o próprio: pose = 0)
func custo_continuar(atual: String, vel: Vector2) -> float:
	if not clipes.has(atual):
		return INF
	return custo_velocidade(atual, vel)
