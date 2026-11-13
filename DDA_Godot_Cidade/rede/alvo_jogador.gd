extends AnimatableBody3D
# ALVO DO JOGADOR REMOTO (0.71 · PvP): o "corpo" que os tiros e golpes acertam no boneco de outro jogador
# (rede/jogador_remoto.gd). Mesmo contrato dos infectados e dos alvos do estande:
#   receber_tiro(dano, ponto, direcao, forma, atirador) -> {"cabeca", "morto"}  (forma 1 = CABEÇA)
#   receber_golpe(dano, direcao, atacante) -> {"cabeca", "morto"}
# O dano de verdade é aplicado no aparelho de quem levou (rede/sessao_rede.gd, evento "pvp").
# Camadas: 3 (alvos: tiro e corpo a corpo acham) e 5 (jogadores: o seu personagem não atravessa o do amigo).
# Mexa AQUI para: tamanho do corpo e da cabeça.

const CAMADA_ALVOS := 4                       # camada 3
const CAMADA_JOGADORES := 16                  # camada 5

var dono                                      # rede/jogador_remoto.gd
var _corpo := CollisionShape3D.new()
var _cabeca := CollisionShape3D.new()
var _agachado := false

func _init() -> void:
	sync_to_physics = false
	collision_layer = CAMADA_ALVOS | CAMADA_JOGADORES
	collision_mask = 0
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.45
	_corpo.shape = cap
	var esf := SphereShape3D.new()
	esf.radius = 0.16
	_cabeca.shape = esf
	add_child(_corpo)                         # forma 0 = corpo
	add_child(_cabeca)                        # forma 1 = cabeça
	_posicionar(false)

func _posicionar(agachado: bool) -> void:
	_agachado = agachado
	var cap := _corpo.shape as CapsuleShape3D
	cap.height = 1.0 if agachado else 1.45
	_corpo.position = Vector3(0, cap.height * 0.5, 0)
	_cabeca.position = Vector3(0, 1.17 if agachado else 1.62, 0)

# chamado pelo jogador remoto a cada quadro
func atualizar(agachado: bool, ativo: bool) -> void:
	if agachado != _agachado:
		_posicionar(agachado)
	var camadas := (CAMADA_ALVOS | CAMADA_JOGADORES) if ativo else 0
	if collision_layer != camadas:
		collision_layer = camadas

func receber_tiro(dano: float, _ponto: Vector3, direcao: Vector3, forma: int, _atirador: Node) -> Dictionary:
	if dono == null:
		return {"cabeca": false, "morto": false}
	return dono.levar_dano(dano, forma == 1, direcao, false)

func receber_golpe(dano: float, direcao: Vector3, _atacante: Node) -> Dictionary:
	if dono == null:
		return {"cabeca": false, "morto": false}
	return dono.levar_dano(dano, false, direcao, true)
