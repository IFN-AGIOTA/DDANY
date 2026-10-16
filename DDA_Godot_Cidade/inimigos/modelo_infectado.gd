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
# Mesma interface do modelo antigo (inimigos/modelo_vago.gd, que continua nas cutscenes):
#   montar(semente) · atualizar(dt, vel) · atacar() · levar_golpe(forca, lado) · morrer(para_tras) · pos_cabeca()
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
			_tocar("andar", 0.3)
		else:
			_tocar("parado", 0.35)
	match _atual:
		"andar": anim.speed_scale = clampf(vel / VEL_ANDAR_ANIM, 0.6, 1.8)
		"correr": anim.speed_scale = clampf(vel / VEL_CORRER_ANIM, 0.75, 1.3)
		_: anim.speed_scale = 1.0
	anim.advance(dt)
	_postura()

# jeito de infectado por cima da animação: cabeça torta e, correndo, braços esticados para a frente
func _postura() -> void:
	_girar("Head", Vector3(0, 0, 1), _cab_incl)
	if _corr > 0.05 and _at < 0.0:
		_girar("upperarm_l", Vector3.RIGHT, -1.0 * _corr)
		_girar("upperarm_r", Vector3.RIGHT, -0.9 * _corr)

# gira um osso em volta de um eixo do espaço do esqueleto (y = cima, +z = frente do manequim)
func _girar(nome: String, eixo: Vector3, ang: float) -> void:
	var i: int = _osso.get(nome, -1)
	if i < 0 or absf(ang) < 0.001:
		return
	var pai := esqueleto.get_bone_parent(i)
	var g := esqueleto.get_bone_global_pose(i)
	var ng := Transform3D(Basis(eixo, ang) * g.basis, g.origin)
	var local := ng if pai < 0 else esqueleto.get_bone_global_pose(pai).affine_inverse() * ng
	esqueleto.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
