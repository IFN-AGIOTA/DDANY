extends Node3D
# MODELO DO INFECTADO: manequim de proporção humana (low poly) da "Universal Animation Library" 1 e 2 do
# QUATERNIUS (CC0), convertido para o jogo por ferramentas/preparar_infectados.gd:
#   - homens e mulheres pintados por região (cor por vértice): pele de infectado, camisa (manga curta ou
#     comprida), calça ou bermuda, sapato, cabelo (ou careca), olhos fundos, boca suja, roupa rasgada e sangue;
#   - malha simplificada (~4.700 vértices, 1 chamada de desenho por infectado), 4 ossos por vértice.
# Ficam em inimigos/infectados/homem_*.scn e mulher_*.scn; as animações (o esqueleto é o mesmo para todos)
# em inimigos/infectados/animacoes.res:
#   andar / parado / ataque (arranhar) = animações de ZUMBI da biblioteca 2 · correr / morte / golpe = da 1.
# Por cima da animação: cabeça torta e, correndo, braços para a frente (jeito de infectado).
# Mesma interface do modelo antigo (o antigo inimigos/modelo_vago.gd, apagado na 0.63):
#   montar(semente) · atualizar(dt, vel) · atacar() · levar_golpe(forca, lado) · morrer(para_tras) · pos_cabeca()
# 0.89 (estilo Project Zomboid): cair() (derrubado: cai e fica no chão) · deitado() (fingindo de morto, já no chão)
#   levantar() (LayToIdle da UAL2: levanta do chão) · rastejante = true (anda de bruços: Swim_Fwd da UAL1 no chão)
# A frente é -Z (igual à Godot). Altura ~1,75 m.
# Mexa AQUI para: quais tipos aparecem e quanto (TIPOS), altura e velocidade das animações.

const PASTA := "res://inimigos/infectados/"
# [arquivo, peso no sorteio]
const TIPOS := [["homem_0", 1.0], ["homem_1", 1.0], ["homem_2", 1.0], ["homem_3", 1.0], ["homem_4", 1.0],
	["homem_5", 1.0], ["homem_6", 1.0], ["homem_7", 1.0], ["mulher_0", 1.0], ["mulher_1", 1.0],
	["mulher_2", 1.0], ["mulher_3", 1.0]]
const ALTURA_ORIGINAL := 1.83          # altura do manequim (m)
const ALTURA := 1.75
const VEL_ANDAR_ANIM := 0.9            # m/s em que a animação de andar (zumbi) não "patina"
const VEL_CORRER_ANIM := 5.0           # idem para a de correr
const DUR_ATAQUE := 0.95
const VEL_RASTEJAR_ANIM := 0.3         # 0.89: m/s em que o rastejar casa com o chão
const DUR_LEVANTAR := 1.5              # 0.89: duração da animação de levantar do chão
# 0.61 · JEITO DE ANDAR de cada infectado (captura real da CMU, ferramentas/retarget_cmu.gd ALVO=infectados):
# [animação, velocidade em que os pés casam com o chão (m/s), peso no sorteio]. O infectado anda à toa mais devagar
# ou mais depressa conforme o jeito dele (fator_vel(), usado em inimigos/vago.gd).
const ESTILOS := [["andar", VEL_ANDAR_ANIM, 2.0], ["andar_zumbi", 0.42, 1.5], ["andar_zumbi_b", 0.57, 1.5],
	["andar_marcha", 0.87, 1.0], ["andar_frank", 0.5, 1.0], ["andar_ferido", 0.52, 1.0], ["andar_velho", 0.38, 0.7]]

static var _cenas := {}
static var _anims: AnimationLibrary = null
static var _mat: StandardMaterial3D = null
static var _sombra_malha: PlaneMesh = null

var sombra: MeshInstance3D
var morto := false
var corpo: Node3D                      # o personagem (cena convertida)
var esqueleto: Skeleton3D
var anim: AnimationPlayer
var _osso := {}                        # nome -> índice
var _atual := ""
var _t := 0.0
var _at := -1.0
var _fl := 0.0
var _corr := 0.0
var _cab_incl := 0.0
var _mt := 0.0
var caido := false                     # 0.89: no chão (derrubado ou fingindo de morto)
var levantando := 0.0                  # 0.89: > 0 = levantando do chão (segundos que faltam)
var rastejante := false                # 0.89: rastejante (perna ruim): anda de bruços
var _y_rastejar := 0.0                 # quanto o corpo desce para o rastejar (a animação é de nado, no ar)
var _andar := "andar"                  # animação de andar deste infectado (ESTILOS)
var _ref_andar := VEL_ANDAR_ANIM

func montar(semente: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = semente
	if _anims == null:
		_anims = load(PASTA + "animacoes.res")
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.9
	var total := 0.0
	for t in TIPOS:
		total += float(t[1])
	var s := r.randf() * total
	var arquivo: String = TIPOS[0][0]
	for t in TIPOS:
		s -= float(t[1])
		if s <= 0.0:
			arquivo = t[0]
			break
	if not _cenas.has(arquivo):
		_cenas[arquivo] = load(PASTA + arquivo + ".scn")
	corpo = _cenas[arquivo].instantiate()
	corpo.rotation.y = PI                                   # o manequim olha para +Z
	corpo.scale = Vector3.ONE * (ALTURA / ALTURA_ORIGINAL) * r.randf_range(0.93, 1.06)
	add_child(corpo)
	esqueleto = corpo.find_child("Skeleton3D", true, false)
	for mi in corpo.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat
		mi.visibility_range_end = 140.0
	for nome in ["Head", "upperarm_l", "upperarm_r"]:
		_osso[nome] = esqueleto.find_bone(nome)
	anim = AnimationPlayer.new()
	corpo.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", _anims)
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_cab_incl = r.randf_range(-0.3, 0.3)
	var tot := 0.0
	for e in ESTILOS:
		if _anims.has_animation(e[0]):
			tot += float(e[2])
	var sorteio := r.randf() * tot
	for e in ESTILOS:
		if not _anims.has_animation(e[0]):
			continue
		sorteio -= float(e[2])
		if sorteio <= 0.0:
			_andar = e[0]
			_ref_andar = float(e[1])
			break
	_tocar("parado", 0.0)
	anim.seek(r.randf() * 3.0, true)
	# sombra falsa (barata, ajuda a "assentar" o corpo no chão)
	if _sombra_malha == null:
		_sombra_malha = PlaneMesh.new()
		_sombra_malha.size = Vector2(1.1, 1.1)
		var sm := StandardMaterial3D.new()
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(0, 0, 0, 0.5))
		gr.set_color(1, Color(0, 0, 0, 0))
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		sm.albedo_texture = gt
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_sombra_malha.material = sm
	sombra = MeshInstance3D.new()
	sombra.mesh = _sombra_malha
	sombra.position.y = 0.04
	sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sombra.visibility_range_end = 60.0
	add_child(sombra)
	atualizar(0.0, 0.0)

# quanto este infectado anda à toa em relação ao normal (jeito de andar mais lento ou mais rápido)
func fator_vel() -> float:
	return clampf(_ref_andar / 0.7, 0.6, 1.2)

# posição (global) do centro da cabeça: a colisão da cabeça (tiro x3) acompanha a animação
func pos_cabeca() -> Vector3:
	var i: int = _osso.get("Head", -1)
	if i < 0:
		return global_position + Vector3(0, 1.6, 0)
	if _cabeca_ok:                                      # já calculada na postura (sem recalcular o esqueleto)
		return esqueleto.global_transform * _cabeca_g.origin + (esqueleto.global_transform.basis * _cabeca_g.basis.y).normalized() * 0.1
	# o osso "Head" fica na base do crânio; o centro fica ~0,1 m acima (na direção do osso)
	var g := esqueleto.global_transform * esqueleto.get_bone_global_pose(i)
	return g.origin + g.basis.y.normalized() * 0.1

# ---------- comandos da animação ----------
func atacar() -> void:
	_at = 0.0
	_tocar("ataque", 0.08, true)

func levar_golpe(forca: float, _lado: float = 0.0) -> void:
	if morto:
		return
	_fl = clampf(_fl + forca, 0.0, 1.3)
	if _at < 0.0:
		_tocar("golpe", 0.05, true)

# 0.89 · DERRUBADO: cai (mesma queda da morte) e fica no chão até levantar()
func cair() -> void:
	if morto:
		return
	caido = true
	levantando = 0.0
	_at = -1.0
	_tocar("morte", 0.1, true)

# 0.89 · FINGINDO DE MORTO: já deitado no chão (último quadro da queda), sem animar a queda
func deitado() -> void:
	caido = true
	levantando = 0.0
	_tocar("morte", 0.0, true)
	anim.seek(anim.current_animation_length - 0.01, true)

# 0.89: levanta do chão (deitado de costas, como a queda termina); devolve quanto tempo leva
func levantar() -> float:
	if morto or not caido:
		return 0.0
	caido = false
	levantando = DUR_LEVANTAR
	_tocar("levantar", 0.25, true)
	return DUR_LEVANTAR

func morrer(_para_tras: bool) -> void:
	if morto:
		return
	morto = true
	_mt = 0.0
	_tocar("morte", 0.1, true)

func _tocar(nome: String, mistura: float, do_inicio := false) -> void:
	if nome == _atual and not do_inicio:
		return
	_atual = nome
	anim.play(nome, mistura)
	if do_inicio:
		anim.seek(0.0, false)

# ---------- animação (chamar todo quadro, ou a cada poucos quadros de longe) ----------
func atualizar(dt: float, vel: float) -> void:
	_t += dt
	if morto:
		_mt += dt
		if _mt < 4.0:                                   # depois fica parado no chão (a animação acabou)
			anim.speed_scale = 1.0
			anim.advance(dt)
		return
	# 0.89: no chão (derrubado / fingindo de morto): a queda termina e fica parado ali
	if caido:
		anim.speed_scale = 1.0
		if anim.is_playing():
			anim.advance(dt)
		return
	if levantando > 0.0:
		levantando -= dt
		anim.speed_scale = 1.0
		anim.advance(dt)
		return
	if rastejante:
		_rastejar(dt, vel)
		return
	_corr = lerpf(_corr, clampf((vel - 2.2) / 2.0, 0.0, 1.0), minf(1.0, dt * 5.0))
	if _at >= 0.0:
		_at += dt
		if _at > DUR_ATAQUE:
			_at = -1.0
	_fl = maxf(0.0, _fl - dt * 2.0)
	if _at < 0.0 and not (_atual == "golpe" and anim.is_playing()):
		if vel > 2.2:
			_tocar("correr", 0.25)
		elif vel > 0.15:
			_tocar(_andar, 0.3)
		else:
			_tocar("parado", 0.35)
	if _atual == _andar:
		anim.speed_scale = clampf(vel / _ref_andar, 0.5, 3.0)       # 0.89: o "rápido" arrasta os pés depressa
	elif _atual == "correr":
		anim.speed_scale = clampf(vel / VEL_CORRER_ANIM, 0.75, 1.3)
	else:
		anim.speed_scale = 1.0
	_cabeca_ok = false
	anim.advance(dt)
	_postura()

# 0.89 · RASTEJANTE: de bruços no chão. A animação (nado da UAL1) fica no ar: o corpo desce até o peito
# encostar no chão (medido uma vez pelo osso da bacia).
func _rastejar(dt: float, vel: float) -> void:
	if _atual != "rastejar":
		_tocar("rastejar", 0.0)
		anim.seek(0.0, true)
		anim.advance(0.0)
		var i: int = _osso.get("pelvis", -1)
		if i >= 0:
			var bacia := (esqueleto.global_transform * esqueleto.get_bone_global_pose(i)).origin
			_y_rastejar = maxf(0.0, (bacia - global_position).y - 0.16)
	corpo.position.y = lerpf(corpo.position.y, -_y_rastejar, minf(1.0, dt * 6.0))
	anim.speed_scale = clampf(vel / VEL_RASTEJAR_ANIM, 0.15, 1.6)
	anim.advance(dt)

# jeito de infectado por cima da animação: cabeça torta e, correndo, braços esticados para a frente.
# OTIMIZADO: lê primeiro as poses globais dos PAIS (o esqueleto é recalculado uma vez só) e depois grava as
# rotações locais (cabeça e braços não são pais uns dos outros, então a ordem não muda o resultado).
# A pose global da cabeça fica guardada para pos_cabeca() (antes recalculava o esqueleto de novo).
var _cabeca_ok := false
var _cabeca_g := Transform3D.IDENTITY

func _postura() -> void:
	var lista := [["Head", Vector3(0, 0, 1), _cab_incl]]
	if _corr > 0.05 and _at < 0.0:
		lista.append(["upperarm_l", Vector3.RIGHT, -1.0 * _corr])
		lista.append(["upperarm_r", Vector3.RIGHT, -0.9 * _corr])
	var feitos := []
	for x in lista:                                     # 1) só leituras
		var i: int = _osso.get(x[0], -1)
		if i < 0:
			continue
		var pai := esqueleto.get_bone_parent(i)
		var gp := esqueleto.get_bone_global_pose(pai) if pai >= 0 else Transform3D.IDENTITY
		feitos.append([i, gp, x[1], x[2]])
	for f in feitos:                                    # 2) só escritas
		var i: int = f[0]
		var gp: Transform3D = f[1]
		var ang: float = f[3]
		var local := Transform3D(Basis(esqueleto.get_bone_pose_rotation(i)), esqueleto.get_bone_pose_position(i))
		if absf(ang) >= 0.001:
			# girar em volta de um eixo do espaço do esqueleto = girar em volta do mesmo eixo visto pelo pai
			var eixo_pai: Vector3 = (gp.basis.orthonormalized().inverse() * (f[2] as Vector3)).normalized()
			local.basis = Basis(eixo_pai, ang) * local.basis
			esqueleto.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		if i == int(_osso.get("Head", -1)):
			_cabeca_g = gp * local
			_cabeca_ok = true
