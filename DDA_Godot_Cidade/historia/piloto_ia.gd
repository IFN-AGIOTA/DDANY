extends Node
# 1.13 · PILOTO DO JOGO (o Greg na corrida): dirige um carro (mundo/veiculo.gd) por um caminho (pontos x, z):
#   · direção: mira um ponto À FRENTE no caminho (mais longe quanto mais rápido);
#   · velocidade: freia antes das curvas (olha o ângulo do caminho até ~60 m à frente);
#   · "elástico" (rubber band): longe na frente do jogador, alivia; muito atrás, força um pouco mais. A corrida fica
#     apertada até o fim, como no livro ("uma batida de coração separava os dois");
#   · preso (bateu e parou): depois de 2,5 s volta para o caminho um pouco à frente.
# progresso() = metros já percorridos no caminho (o mesmo cálculo serve para o jogador: posicao()).
# Mexa AQUI para: o quanto ele arrisca nas curvas (CURVA_*), o elástico e a velocidade máxima.

const RotaGps := preload("res://hud/rota_gps.gd")

const CURVA_LENTA := 13.0         # m/s numa curva fechada (90°)
const ELASTICO_FRENTE := 45.0     # m na frente do jogador: começa a aliviar
const ELASTICO_ATRAS := 35.0      # m atrás do jogador: começa a forçar

var carro: VehicleBody3D
var caminho := PackedVector2Array()
var _acum := PackedFloat32Array()  # metros do começo até cada ponto
var ligado := false
var progresso_jogador := -1.0      # metros do jogador (para o elástico); <0 = sem elástico
var vel_max := 38.0
var _i := 0                        # trecho atual
var _t_preso := 0.0
var _s := 0.0

func definir(cam: PackedVector2Array) -> void:
	caminho = cam
	_acum = PackedFloat32Array()
	var t := 0.0
	_acum.append(0.0)
	for i in range(1, cam.size()):
		t += cam[i - 1].distance_to(cam[i])
		_acum.append(t)
	_i = 0
	_s = 0.0

func total() -> float:
	return _acum[_acum.size() - 1] if not _acum.is_empty() else 0.0

# metros percorridos no caminho por um ponto qualquer (procura perto do trecho "dica")
func medir(p: Vector2, dica := -1) -> Array:
	var melhor := INF
	var mi := 0
	var mt := 0.0
	var de := 0 if dica < 0 else maxi(0, dica - 3)
	var ate := caminho.size() - 1 if dica < 0 else mini(caminho.size() - 1, dica + 6)
	for i in range(de, ate):
		var a := caminho[i]
		var ab := caminho[i + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_squared_to(a + ab * t)
		if d < melhor:
			melhor = d
			mi = i
			mt = t
	return [_acum[mi] + caminho[mi].distance_to(caminho[mi + 1]) * mt, mi, sqrt(melhor)]

func progresso() -> float:
	return _s

func ponto_em(s: float) -> Vector2:
	s = clampf(s, 0.0, total())
	for i in range(_acum.size() - 1):
		if _acum[i + 1] >= s:
			var seg := _acum[i + 1] - _acum[i]
			return caminho[i].lerp(caminho[i + 1], (s - _acum[i]) / maxf(seg, 0.001))
	return caminho[caminho.size() - 1]

func direcao_em(s: float) -> Vector2:
	return (ponto_em(s + 2.0) - ponto_em(s - 2.0)).normalized()

func _physics_process(dt: float) -> void:
	if carro == null or not is_instance_valid(carro) or caminho.size() < 2:
		return
	var p := Vector2(carro.global_position.x, carro.global_position.z)
	var m := medir(p, _i)
	_s = float(m[0])
	_i = int(m[1])
	if not ligado:
		carro.controlar(0.0, 0.0, true)
		return
	var vel := carro.linear_velocity.length()
	# direção: ponto à frente
	var olhar := 9.0 + vel * 0.7
	var alvo := ponto_em(_s + olhar)
	var frente := carro.global_basis.z
	var local := carro.global_basis.inverse() * (Vector3(alvo.x, carro.global_position.y, alvo.y) - carro.global_position)
	var ang := atan2(local.x, local.z)                 # + = alvo à esquerda
	var giro := clampf(-ang * 2.4, -1.0, 1.0)
	# velocidade: curva mais forte nos próximos ~60 m
	var curva := 0.0
	var d0 := direcao_em(_s + 4.0)
	for k in range(1, 7):
		var dk := direcao_em(_s + 4.0 + k * 10.0)
		curva = maxf(curva, absf(d0.angle_to(dk)) * (1.0 - k * 0.07))
	var v_alvo := lerpf(vel_max, CURVA_LENTA, clampf(curva / (PI * 0.5), 0.0, 1.0))
	# elástico
	if progresso_jogador >= 0.0:
		var dif := _s - progresso_jogador
		if dif > ELASTICO_FRENTE:
			v_alvo *= clampf(1.0 - (dif - ELASTICO_FRENTE) / 120.0, 0.72, 1.0)
		elif dif < -ELASTICO_ATRAS:
			v_alvo = minf(v_alvo * 1.12, vel_max * 1.05)
	var acel := clampf((v_alvo - vel) / 4.0, -1.0, 1.0)
	if vel < 4.0 and acel < 0.3:
		acel = 0.6
	var _f := frente
	carro.controlar(acel, giro, false)
	# preso: volta ao caminho
	if vel < 1.0 and _s < total() - 15.0:
		_t_preso += dt
		if _t_preso > 2.5:
			_t_preso = 0.0
			var q := ponto_em(_s + 6.0)
			var dq := direcao_em(_s + 6.0)
			carro.linear_velocity = Vector3.ZERO
			carro.angular_velocity = Vector3.ZERO
			carro.global_transform = Transform3D(Basis(Vector3.UP, atan2(dq.x, dq.y)), Vector3(q.x, carro.global_position.y + 0.6, q.y))
	else:
		_t_preso = 0.0
