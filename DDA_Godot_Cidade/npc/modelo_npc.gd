extends Node3D
# MODELO DE UM SOBREVIVENTE DO HOSPITAL (0.91) · o mesmo manequim dos infectados (inimigos/infectados/homem_*.scn e
# mulher_*.scn, Quaternius CC0) REPINTADO por região como gente viva: pele saudável, olhos, boca, cabelo e a roupa de
# cada um (tabela VISUAIS, conforme a Bíblia da Lore). A malha repintada é feita uma vez por personagem e reaproveitada.
# Animações (inimigos/infectados/animacoes.res, acrescentadas por ferramentas/animacoes_npcs.gd): npc_parado,
# npc_falando, npc_bracos (braços cruzados), npc_radio (falando no rádio), npc_sentado, npc_sim, npc_nao.
# CARLOS perdeu o braço esquerdo nos primeiros dias do colapso: o braço sai da malha (fica a manga presa).
# A frente é -Z (igual à Godot). Mexa AQUI para: a cara e a roupa de cada um (VISUAIS) e a animação de cada pose.

const PASTA := "res://inimigos/infectados/"
const ALTURA_ORIGINAL := 1.83
# nome -> visual · arquivo = qual manequim · cores por região · "sem_braco_e" = sem o braço esquerdo
const VISUAIS := {
	"monica": {"arquivo": "mulher_1", "altura": 1.68, "pele": Color(0.78, 0.6, 0.48), "camisa": Color(0.86, 0.88, 0.9),
		"calca": Color(0.42, 0.58, 0.66), "sapato": Color(0.85, 0.85, 0.85), "cabelo": Color(0.2, 0.12, 0.07),
		"manga_curta": true, "longo": true},                                # ex-enfermeira: jaleco branco, calça de hospital
	"carlos": {"arquivo": "homem_2", "altura": 1.84, "pele": Color(0.55, 0.38, 0.27), "camisa": Color(0.3, 0.34, 0.22),
		"calca": Color(0.26, 0.28, 0.22), "sapato": Color(0.12, 0.1, 0.08), "cabelo": Color(0.08, 0.07, 0.06),
		"manga_curta": false, "careca": true, "sem_braco_e": true},          # ex-militar, sem o braço esquerdo
	"lucas": {"arquivo": "homem_5", "altura": 1.72, "pele": Color(0.82, 0.64, 0.52), "camisa": Color(0.62, 0.2, 0.18),
		"calca": Color(0.22, 0.27, 0.4), "sapato": Color(0.85, 0.85, 0.82), "cabelo": Color(0.32, 0.2, 0.1),
		"manga_curta": false},                                              # garoto de 17 anos, moletom vermelho, rádio
	"jose": {"arquivo": "homem_6", "altura": 1.76, "pele": Color(0.66, 0.47, 0.35), "camisa": Color(0.24, 0.34, 0.5),
		"calca": Color(0.3, 0.27, 0.22), "sapato": Color(0.25, 0.18, 0.12), "cabelo": Color(0.1, 0.08, 0.07),
		"manga_curta": true},
	"senhora": {"arquivo": "mulher_3", "altura": 1.6, "pele": Color(0.8, 0.66, 0.56), "camisa": Color(0.45, 0.3, 0.4),
		"calca": Color(0.3, 0.28, 0.3), "sapato": Color(0.2, 0.17, 0.15), "cabelo": Color(0.82, 0.8, 0.78),
		"manga_curta": false, "longo": true},                               # a senhora: cabelo branco
	"jhon": {"arquivo": "homem_3", "altura": 1.78, "pele": Color(0.74, 0.56, 0.44), "camisa": Color(0.18, 0.2, 0.22),
		"calca": Color(0.2, 0.22, 0.26), "sapato": Color(0.1, 0.1, 0.1), "cabelo": Color(0.05, 0.05, 0.05),
		"manga_curta": false, "bone": Color(0.05, 0.05, 0.06)},              # boné preto, sempre perto do rádio
}

static var _malhas := {}
static var _cenas := {}
static var _anims: AnimationLibrary = null
static var _mat: StandardMaterial3D = null

var corpo: Node3D
var esqueleto: Skeleton3D
var anim: AnimationPlayer
var pose := "npc_parado"

func montar(quem: String) -> void:
	var v: Dictionary = VISUAIS.get(quem, VISUAIS["jose"])
	if _anims == null:
		_anims = load(PASTA + "animacoes.res")
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.85
	var arq: String = v["arquivo"]
	if not _cenas.has(arq):
		_cenas[arq] = load(PASTA + arq + ".scn")
	corpo = _cenas[arq].instantiate()
	corpo.rotation.y = PI
	corpo.scale = Vector3.ONE * (float(v.get("altura", 1.75)) / ALTURA_ORIGINAL)
	add_child(corpo)
	esqueleto = corpo.find_child("Skeleton3D", true, false)
	for mi in corpo.find_children("*", "MeshInstance3D", true, false):
		if not _malhas.has(quem):
			_malhas[quem] = _repintar(mi.mesh, v)
		mi.mesh = _malhas[quem]
		mi.material_override = _mat
		mi.visibility_range_end = 90.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_rosto(v)
	anim = AnimationPlayer.new()
	corpo.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", _anims)
	tocar(pose)
	anim.seek(randf() * 2.0, true)

func tocar(nome: String, mistura := 0.3) -> void:
	pose = nome
	if anim != null and _anims.has_animation(nome):
		anim.play(nome, mistura)

# um gesto (sim/não) e volta para a pose
func gesto(nome: String) -> void:
	if anim == null or not _anims.has_animation(nome):
		return
	var volta := pose
	anim.play(nome, 0.2)
	await get_tree().create_timer(_anims.get_animation(nome).length * 0.9).timeout
	if is_instance_valid(self) and anim.current_animation == nome:
		tocar(volta)

# OLHOS, SOBRANCELHAS E BOCA: pecinhas presas ao osso da cabeça (a malha do rosto é simples demais para pintar),
# encostadas na frente do rosto (a altura e a frente vêm da própria malha)
static var _malhas_rosto := {}
func _rosto(v: Dictionary) -> void:
	var sk := esqueleto
	var hb := sk.find_bone("Head")
	var rest := sk.get_bone_global_rest(hb)
	var mi: MeshInstance3D = corpo.find_children("*", "MeshInstance3D", true, false)[0]
	var a: Array = mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var y_olho := rest.origin.y + 0.105
	var y_boca := rest.origin.y + 0.045
	var z_olho := -INF
	var z_boca := -INF
	for p in vs:
		if absf(p.x) < 0.06 and p.z > 0.0:
			if absf(p.y - y_olho) < 0.05:
				z_olho = maxf(z_olho, p.z)
			if absf(p.y - y_boca) < 0.04:
				z_boca = maxf(z_boca, p.z)
	if z_olho == -INF:
		return
	if z_boca == -INF:
		z_boca = z_olho - 0.01
	if _malhas_rosto.is_empty():
		var esf := SphereMesh.new()
		esf.radius = 0.011
		esf.height = 0.016
		esf.radial_segments = 8
		esf.rings = 4
		_malhas_rosto["olho"] = esf
		var b := BoxMesh.new()
		b.size = Vector3(0.03, 0.006, 0.006)
		_malhas_rosto["sobrancelha"] = b
		var bm := BoxMesh.new()
		bm.size = Vector3(0.032, 0.006, 0.005)
		_malhas_rosto["boca"] = bm
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Head"
	sk.add_child(ba)
	var inv := rest.affine_inverse()
	var pecas := [["olho", Vector3(-0.031, y_olho, z_olho - 0.004), Color(0.1, 0.07, 0.05)],
		["olho", Vector3(0.031, y_olho, z_olho - 0.004), Color(0.1, 0.07, 0.05)],
		["boca", Vector3(0, y_boca, z_boca - 0.001), (v["pele"] as Color) * Color(0.7, 0.42, 0.4)]]
	if not v.has("bone"):
		pecas.append(["sobrancelha", Vector3(-0.032, y_olho + 0.022, z_olho - 0.006), (v["cabelo"] as Color) * 0.85])
		pecas.append(["sobrancelha", Vector3(0.032, y_olho + 0.022, z_olho - 0.006), (v["cabelo"] as Color) * 0.85])
	for e in pecas:
		var m3 := MeshInstance3D.new()
		m3.mesh = _malhas_rosto[e[0]]
		var mt := StandardMaterial3D.new()
		mt.albedo_color = e[2]
		mt.roughness = 0.5 if e[0] == "olho" else 0.9
		m3.material_override = mt
		m3.transform = Transform3D(inv.basis, inv * (e[1] as Vector3))
		m3.visibility_range_end = 25.0
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ba.add_child(m3)

static func _regiao(osso: String) -> String:
	if osso == "Head" or osso == "neck_01": return "cabeca"
	if osso.begins_with("hand") or osso.begins_with("index") or osso.begins_with("middle") or osso.begins_with("pinky") or osso.begins_with("ring") or osso.begins_with("thumb"): return "mao"
	if osso.begins_with("lowerarm"): return "antebraco"
	if osso.begins_with("upperarm") or osso.begins_with("clavicle") or osso.begins_with("spine"): return "tronco"
	if osso == "pelvis" or osso.begins_with("thigh"): return "coxa"
	if osso.begins_with("calf"): return "canela"
	if osso.begins_with("foot") or osso.begins_with("ball"): return "pe"
	return "tronco"

static func _braco_esquerdo(osso: String) -> bool:
	return osso == "lowerarm_l" or osso == "hand_l" or (osso.ends_with("_l") and (osso.begins_with("index") or osso.begins_with("middle")
		or osso.begins_with("pinky") or osso.begins_with("ring") or osso.begins_with("thumb")))

# pinta cada vértice pela parte do corpo (o osso que mais puxa ele), como ferramentas/preparar_infectados.gd, mas vivo
func _repintar(m: Mesh, v: Dictionary) -> ArrayMesh:
	var sk: Skeleton3D = esqueleto
	var ph := sk.get_bone_global_rest(sk.find_bone("Head")).origin
	var frente := sk.get_bone_global_rest(sk.find_bone("ball_l")).origin - sk.get_bone_global_rest(sk.find_bone("foot_l")).origin
	frente.y = 0.0
	frente = frente.normalized()
	var ombro_e := sk.get_bone_global_rest(sk.find_bone("upperarm_l")).origin
	var ruido := FastNoiseLite.new()
	ruido.seed = hash(str(v["arquivo"]))
	ruido.frequency = 2.2
	var nova := ArrayMesh.new()
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var nb := bs.size() / maxi(vs.size(), 1)
		var C := PackedColorArray()
		C.resize(vs.size())
		var fora := PackedByteArray()
		fora.resize(vs.size())
		for vi in vs.size():
			var melhor := 0
			var pm := -1.0
			for j in nb:
				if ws[vi * nb + j] > pm:
					pm = ws[vi * nb + j]
					melhor = bs[vi * nb + j]
			var osso := sk.get_bone_name(melhor)
			var p: Vector3 = vs[vi]
			var reg := _regiao(osso)
			var cor: Color = v["pele"]
			match reg:
				"cabeca":
					var d := p - ph
					var na_frente := d.dot(frente)
					var longo: bool = v.get("longo", false)
					if not v.get("careca", false) and (d.y > 0.12 - (0.06 if longo else 0.0) and na_frente < 0.05 or d.y > 0.17):
						cor = v["cabelo"]
					if longo and na_frente < -0.02 and d.y > -0.04:
						cor = v["cabelo"]
					if v.has("bone") and d.y > 0.13:
						cor = v["bone"]
				"mao": cor = v["pele"]
				"antebraco": cor = v["pele"] if v.get("manga_curta", false) else v["camisa"]
				"tronco": cor = v["camisa"]
				"coxa": cor = v["calca"]
				"canela": cor = v["calca"]
				"pe": cor = v["sapato"]
			cor = cor * (0.93 + 0.1 * ruido.get_noise_3d(p.x * 30.0, p.y * 30.0, p.z * 30.0))
			cor.a = 1.0
			C[vi] = cor
			if v.get("sem_braco_e", false) and (_braco_esquerdo(osso) or (osso == "upperarm_l" and p.distance_to(ombro_e) > 0.07)):
				fora[vi] = 1
		a[Mesh.ARRAY_COLOR] = C
		if v.get("sem_braco_e", false):
			var I: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var I2 := PackedInt32Array()
			for t in range(0, I.size(), 3):
				if fora[I[t]] == 0 and fora[I[t + 1]] == 0 and fora[I[t + 2]] == 0:
					I2.append(I[t])
					I2.append(I[t + 1])
					I2.append(I[t + 2])
			a[Mesh.ARRAY_INDEX] = I2
		var oito: bool = (m.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if oito else 0)
	return nova
