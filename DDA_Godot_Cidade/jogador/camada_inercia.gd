extends SkeletonModifier3D
# 1.12 · TROCAS SEM TRANCO ("inertialization" da Unreal 5, do jeito "dead blending"): quando o animador troca de
# animação, a nova entra NA HORA (responde ao controle sem atraso). A pose que estava na tela continua se mexendo com a
# VELOCIDADE que tinha (freando aos poucos, MEIA_VIDA) e a nova entra por cima dela com uma curva suave em DURACAO
# segundos. Assim nem a posição nem a velocidade dos ossos "pulam" (o crossfade antigo misturava duas animações
# paradas uma na outra; o "offset" simples parava o pé de repente).
# É a PRIMEIRA camada do esqueleto (antes da postura da arma, da ação, da mira, do IK): trabalha só na animação.
# disparar() é chamado pelo jogador/animador_modelo.gd na troca.
# Mexa AQUI para: DURACAO e MEIA_VIDA.

const DURACAO := 0.25
const MEIA_VIDA := 0.06       # s: em quanto tempo a velocidade da pose antiga cai pela metade

var ligado := true
var dt_fixo := 0.0            # > 0: passo fixo (testes); 0 = o tempo real do quadro
var _ult_r: Array = []        # rotação local de cada osso no último quadro mostrado
var _ant_r: Array = []        # ... e no anterior (para a velocidade)
var _ult_p: Array = []        # posição local (só ossos que andam: root, pelvis)
var _ant_p: Array = []
var _src_r: Array = []        # pose de saída na hora da troca
var _vel_r: Array = []        # velocidade angular (eixo * rad/s) na hora da troca
var _src_p: Array = []
var _vel_p: Array = []
var _ossos_pos: Array = []
var _t := 1e9
var _dt_ant := 0.016
var _pedido := false

func preparar(sk: Skeleton3D) -> void:
	var n := sk.get_bone_count()
	for a in [_ult_r, _ant_r, _src_r, _vel_r, _ult_p, _ant_p, _src_p, _vel_p]:
		a.resize(n)
	for o in ["root", "pelvis"]:
		var i := sk.find_bone(o)
		if i >= 0:
			_ossos_pos.append(i)
	active = true

func disparar() -> void:
	if ligado:
		_pedido = true

func em_transicao() -> bool:
	return _t < DURACAO

static func _log_q(q: Quaternion) -> Vector3:
	if q.w < 0.0:
		q = -q
	var s := Vector3(q.x, q.y, q.z)
	var l := s.length()
	if l < 1e-6:
		return Vector3.ZERO
	return s / l * (2.0 * atan2(l, q.w))

static func _exp_q(v: Vector3) -> Quaternion:
	var a := v.length()
	if a < 1e-6:
		return Quaternion.IDENTITY
	return Quaternion(v / a, a)

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _ult_r.is_empty():
		return
	var dt := dt_fixo if dt_fixo > 0.0 else (get_process_delta_time() if is_inside_tree() else 0.016)
	var n := sk.get_bone_count()
	if _pedido and _ult_r[0] != null and _ant_r[0] != null:
		_t = 0.0
		var inv := 1.0 / maxf(_dt_ant, 0.001)
		for i in n:
			_src_r[i] = _ult_r[i]
			_vel_r[i] = _log_q((_ult_r[i] as Quaternion) * (_ant_r[i] as Quaternion).inverse()) * inv
		for i in _ossos_pos:
			_src_p[i] = _ult_p[i]
			_vel_p[i] = ((_ult_p[i] as Vector3) - (_ant_p[i] as Vector3)) * inv
	_pedido = false
	if _t < DURACAO:
		_t += dt
		var x := clampf(_t / DURACAO, 0.0, 1.0)
		var w := x * x * (3.0 - 2.0 * x)                     # 0 -> 1 suave (velocidade contínua no começo e no fim)
		# quanto a pose antiga andou até agora, com a velocidade freando: v * tau * (1 - e^(-t/tau))
		var tau := MEIA_VIDA / log(2.0)
		var andou := tau * (1.0 - exp(-_t / tau))
		for i in n:
			var ext: Quaternion = _exp_q((_vel_r[i] as Vector3) * andou) * (_src_r[i] as Quaternion)
			sk.set_bone_pose_rotation(i, ext.slerp(sk.get_bone_pose_rotation(i), w))
		for i in _ossos_pos:
			var extp: Vector3 = (_src_p[i] as Vector3) + (_vel_p[i] as Vector3) * andou
			sk.set_bone_pose_position(i, extp.lerp(sk.get_bone_pose_position(i), w))
	for i in n:
		_ant_r[i] = _ult_r[i]
		_ult_r[i] = sk.get_bone_pose_rotation(i)
	for i in _ossos_pos:
		_ant_p[i] = _ult_p[i]
		_ult_p[i] = sk.get_bone_pose_position(i)
	_dt_ant = dt
