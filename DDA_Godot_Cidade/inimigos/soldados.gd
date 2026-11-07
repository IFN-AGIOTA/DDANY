extends RefCounted
# 1.08 · SOLDADOS INFECTADOS perto dos COMBOIOS DO EXÉRCITO (mundo/comboios.gd): quando alguém (você ou, no host, um
# amigo) chega a RAIO m do meio de um comboio, nascem de 2 a 5 soldados (farda camuflada e capacete:
# inimigos/modelo_infectado.gd SOLDADOS) no asfalto, entre os veículos. Igual aos locais (mundo/locais.gd _infestar):
# uma vez por CICLO (horas do jogo, cada comboio na sua hora) e só o que falta (os de antes ainda estão por aí).
# Nos locais do Exército (quartel, prefeitura, guarita) quem põe os soldados é o mundo/locais.gd (COM_SOLDADOS).
# Quem chama: inimigos/vagos.gd (_process, só no jogo solo e no host; no cliente os soldados chegam pela rede).
# Mexa AQUI para: quantos, a que distância nascem e de quanto em quanto tempo voltam.

const ModeloCls := preload("res://inimigos/modelo_infectado.gd")

const RAIO := 130.0                     # alguém a menos disso do comboio: nascem
const PERTO := 30.0                     # mas não na cara de ninguém
const CICLO := 24.0                     # horas do jogo até voltarem
const MIN := 2
const MAX := 5

var _feitos := {}                       # índice do comboio -> ciclo em que já nasceram
var _t := 0.0

func processar(vg, dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.5
	var cid = vg.cidade
	if cid == null or cid.get("abandono") == null:
		return
	var centros: Array = cid.abandono.centros_comboio
	if centros.is_empty() or vg.horda == null:
		return
	var jogs: Array = vg._centros()
	var h: float = vg.horda.hora()
	for i in centros.size():
		var cc: Array = centros[i]
		var c: Vector3 = cc[0]
		if _dist(c, jogs) > RAIO:
			continue
		var ciclo := floori((h + fposmod(i * 0.618034, 1.0) * CICLO) / CICLO)
		if int(_feitos.get(i, -1)) >= ciclo:
			continue
		_feitos[i] = ciclo
		var r := RandomNumberGenerator.new()
		r.seed = hash(Vector2i(i, ciclo))
		var falta: int = r.randi_range(MIN, MAX) - vg.vivos_perto(c, float(cc[3]) + 12.0)
		var d: Vector3 = cc[1]
		var n: Vector3 = cc[2]
		var tent := 0
		while falta > 0 and tent < 15:
			tent += 1
			# ao longo da fila, do lado do meio da rua (entre os veículos e a outra pista)
			var p: Vector3 = c + d * r.randf_range(-float(cc[3]), float(cc[3])) + n * r.randf_range(2.2, float(cc[4]) + 2.0)
			if _dist(p, jogs) < PERTO:
				continue
			if vg.mundo != null:
				p.y = vg.mundo.altura(p.x, p.z)
			vg._criar(p + Vector3(0, 0.05, 0), Vector3.INF, false, "", ModeloCls.semente_soldado())
			falta -= 1

static func _dist(p: Vector3, jogs: Array) -> float:
	var m := INF
	for q in jogs:
		m = minf(m, Vector2(p.x - q.x, p.z - q.z).length())
	return m
