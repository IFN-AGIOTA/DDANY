extends Node3D
# MODELO DO INFECTADO com os personagens animados do QUATERNIUS (CC0, "Ultimate Animated Character Pack").
# Os modelos foram convertidos para o jogo (ferramentas/preparar_infectados.gd): 1 malha por personagem
# (1 chamada de desenho), cor por vértice, pele de infectado, roupa suja e manchas de sangue, 4 ossos por
# vértice. Ficam em inimigos/infectados/*.scn; as animações (andar, parado, soco, golpe, morte) em
# inimigos/infectados/animacoes.res (o esqueleto é o mesmo para todos).
# Tipos: zumbis do pacote + civis infectados (casual, operário, soldado, policial, médico, terno, cozinheiro...).
# Por cima da animação, o código curva o tronco, entorta a cabeça e, correndo, ergue os braços para a frente
# (jeito de infectado). Correr = a animação de andar acelerada.
# Mesma interface do modelo antigo (inimigos/modelo_vago.gd, que continua nas cutscenes):
#   montar(semente) · atualizar(dt, vel) · atacar() · levar_golpe(forca, lado) · morrer(para_tras) · pos_cabeca()
# A frente é -Z (igual à Godot). Altura ~1,75 m.
# Mexa AQUI para: quais tipos aparecem e quanto (TIPOS), altura, postura (CURVA) e velocidade da animação.

const PASTA := "res://inimigos/infectados/"
# [arquivo, peso no sorteio]
const TIPOS := [["zombie_male", 3.0], ["zombie_female", 2.0], ["casual_male", 1.0], ["casual2_male", 1.0],
	["casual3_male", 1.0], ["casual_bald", 1.0], ["casual_female", 1.0], ["casual2_female", 1.0],
	["worker_male", 1.0], ["worker_female", 0.7], ["soldier_male", 0.6], ["bluesoldier_male", 0.6],
	["doctor_male_young", 0.6], ["doctor_female_old", 0.5], ["suit_male", 0.8], ["chef_male", 0.5],
	["oldclassy_male", 0.6]]
const ALTURA_ORIGINAL := 2.76          # altura dos modelos do pacote (m)
const ALTURA := 1.75
const CURVA := 0.3                     # tronco curvado para a frente (rad)
const VEL_ANDAR_ANIM := 0.95           # m/s em que a animação de andar não "patina" (no tamanho do jogo)
const DUR_ATAQUE := 0.95

static var _cenas := {}
static var _anims: AnimationLibrary = null
static var _mat: StandardMaterial3D = null
static var _sombra_malha: PlaneMesh = null

var sombra: MeshInstance3D
var morto := false
var corpo: Node3D                      # o personagem (cena do pacote)
var queda: Node3D                      # pivô nos pés: gira o corpo inteiro ao morrer
var esqueleto: Skeleton3D
var anim: AnimationPlayer
var _osso := {}                        # nome -> índice
var _atual := ""
var _t := 0.0
var _at := -1.0
var _fl := 0.0
var _corr := 0.0
var _cab_incl := 0.0
var _curva := CURVA
var _mt := 0.0
var _para_tras := true

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
	corpo.rotation.y = PI                                   # o pacote olha para +Z
	corpo.scale = Vector3.ONE * (ALTURA / ALTURA_ORIGINAL) * r.randf_range(0.93, 1.06)
	queda = Node3D.new()
	add_child(queda)
	queda.add_child(corpo)
	esqueleto = corpo.find_child("Skeleton3D", true, false)
	for mi in corpo.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat
		mi.visibility_range_end = 140.0
	for nome in ["Torso", "Neck", "Head", "UpperArm.L", "UpperArm.R", "Abdomen"]:
		_osso[nome] = esqueleto.find_bone(nome)
	anim = AnimationPlayer.new()
	corpo.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", _anims)
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_cab_incl = r.randf_range(-0.35, 0.35)
	_curva = CURVA * r.randf_range(0.6, 1.3)
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

# posição (global) do centro da cabeça: a colisão da cabeça (tiro x3) acompanha a animação
func pos_cabeca() -> Vector3:
	var i: int = _osso.get("Head", -1)
	if i < 0:
		return global_position + Vector3(0, 1.6, 0)
	# o osso "Head" fica na base da cabeça; o centro fica ~0,2 m acima (na direção do corpo, que pode estar caído)
	var g := esqueleto.global_transform * esqueleto.get_bone_global_pose(i)
	return g.origin + g.basis.y.normalized() * 0.2

# ---------- comandos da animação ----------
func atacar() -> void:
	_at = 0.0
	_tocar("soco", 0.08, true)

func levar_golpe(forca: float, _lado: float = 0.0) -> void:
	if morto:
		return
	_fl = clampf(_fl + forca, 0.0, 1.3)
	if _at < 0.0:
		_tocar("golpe", 0.05, true)

# a animação "morte" do pacote não cai no chão: o tranco do golpe + o corpo tombando é feito aqui
func morrer(para_tras: bool) -> void:
	if morto:
		return
	morto = true
	_mt = 0.0
	_para_tras = para_tras
	_tocar("golpe", 0.05, true)

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
		if _mt < 3.0:
			anim.speed_scale = 0.8
			anim.advance(dt)
			# tomba (de costas = para +Z, a frente é -Z), acelerando como quem cai, e quica de leve
			var k := clampf(_mt / 0.75, 0.0, 1.0)
			var ang := 1.5 * k * k
			if k >= 1.0:
				ang = 1.5 - 0.06 * sin(clampf((_mt - 0.75) / 0.25, 0.0, 1.0) * PI)
			queda.rotation.x = ang if _para_tras else -ang
			queda.position.y = 0.12 * k            # a espessura do corpo (não afunda no chão)
		return
	_corr = lerpf(_corr, clampf((vel - 1.8) / 2.4, 0.0, 1.0), minf(1.0, dt * 5.0))
	if _at >= 0.0:
		_at += dt
		if _at > DUR_ATAQUE:
			_at = -1.0
	_fl = maxf(0.0, _fl - dt * 2.0)
	if _at < 0.0 and not (_atual == "golpe" and anim.is_playing()):
		if vel > 0.15:
			_tocar("andar", 0.25)
		else:
			_tocar("parado", 0.3)
	anim.speed_scale = clampf(vel / VEL_ANDAR_ANIM, 0.6, 2.7) if _atual == "andar" else 1.0
	anim.advance(dt)
	_postura()

# jeito de infectado por cima da animação: tronco curvado, cabeça torta, braços para a frente correndo
func _postura() -> void:
	var curva := _curva + 0.2 * _corr
	_girar("Abdomen", Vector3.RIGHT, curva * 0.5)
	_girar("Torso", Vector3.RIGHT, curva * 0.5)
	_girar("Head", Vector3.UP, _cab_incl)
	if _corr > 0.05 and _at < 0.0:
		_girar("UpperArm.L", Vector3.RIGHT, -1.25 * _corr)
		_girar("UpperArm.R", Vector3.RIGHT, -1.15 * _corr)

# gira um osso em volta de um eixo do espaço do esqueleto (z = cima, -y = frente), por cima da animação
func _girar(nome: String, eixo: Vector3, ang: float) -> void:
	var i: int = _osso.get(nome, -1)
	if i < 0 or absf(ang) < 0.001:
		return
	var pai := esqueleto.get_bone_parent(i)
	var g := esqueleto.get_bone_global_pose(i)
	var ng := Transform3D(Basis(eixo, ang) * g.basis, g.origin)
	var local := ng if pai < 0 else esqueleto.get_bone_global_pose(pai).affine_inverse() * ng
	esqueleto.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
