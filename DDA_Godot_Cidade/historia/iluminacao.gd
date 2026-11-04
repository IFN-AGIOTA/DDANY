extends Node3D
# 1.13.1 · ILUMINAÇÃO DO MODO HISTÓRIA, SÓ ONDE OS PERSONAGENS PASSAM (a cidade antes do caos ainda tem luz):
#   · POSTES ACESOS ao longo do caminho (a cada ~26 m, alternando os lados da rua): de longe, um brilho barato
#     (quadrado virado para a câmera, somado à cena); de perto, LUZ DE VERDADE: poucas OmniLight3D (POOL) que vão
#     para os postes mais perto da câmera (a da cena ou a do jogo) — no celular são menos;
#   · PRÉDIOS da beira do caminho com JANELAS ACESAS (luz quente, umas apagadas, sempre as mesmas) e VITRINES no térreo;
#   · tudo num punhado de MultiMesh (poucas chamadas de desenho), montado uma vez por missão.
# acender(caminho, pontos): caminho = pontos (x, z) por onde eles passam; pontos = lugares extras (largada, chegada).
# Mexa AQUI para: a distância entre os postes, quantas luzes de verdade, as cores e quantas janelas acendem.

const PASSO_POSTE := 26.0
const ALCANCE_PREDIO := 34.0          # prédios a até isso do caminho ganham janelas acesas
const POOL_PC := 14
const POOL_CELULAR := 7
const COR_POSTE := Color(1.0, 0.74, 0.42)
const CORES_JANELA := [Color(1.0, 0.82, 0.55), Color(1.0, 0.9, 0.7), Color(0.85, 0.9, 1.0), Color(1.0, 0.7, 0.45)]

const SHADER_HALO := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
varying vec4 cor;
void vertex() {
	cor = INSTANCE_CUSTOM;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = pow(max(1.0 - r, 0.0), 2.0);
	ALBEDO = cor.rgb * a * 1.7;
}
"""

var cidade = null
var mundo = null
var postes: Array = []              # Vector3 da lâmpada
var _luzes: Array = []
var _t := 0.0

func acender(caminho: PackedVector2Array, pontos: Array = []) -> void:
	apagar()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	# postes ao longo do caminho
	var lado := 1.0
	var acum := 0.0
	for i in caminho.size() - 1:
		var a := caminho[i]
		var b := caminho[i + 1]
		var seg := a.distance_to(b)
		var d := (b - a) / maxf(seg, 0.001)
		var esq := Vector2(d.y, -d.x)
		var s := PASSO_POSTE - acum
		while s < seg:
			var p := a + d * s + esq * lado * 7.5
			postes.append(Vector3(p.x, _altura(p) + 6.2, p.y))
			lado = -lado
			s += PASSO_POSTE
		acum = seg - (s - PASSO_POSTE)
	for q in pontos:
		var v: Vector3 = q
		for k in 4:
			var ang := TAU * k / 4.0
			postes.append(v + Vector3(cos(ang) * 9.0, 6.2, sin(ang) * 9.0))
	_halos()
	_janelas(caminho, pontos, rng)
	# luzes de verdade (o pool)
	var n := POOL_CELULAR if OS.has_feature("mobile") else POOL_PC
	for k in n:
		var o := OmniLight3D.new()
		o.light_color = COR_POSTE
		o.light_energy = 2.4
		o.omni_range = 19.0
		o.omni_attenuation = 1.4
		o.shadow_enabled = false
		o.visible = false
		add_child(o)
		_luzes.append(o)
	_t = 0.0

func apagar() -> void:
	for c in get_children():
		c.queue_free()
	_luzes.clear()
	postes.clear()

func _altura(p: Vector2) -> float:
	return mundo.altura(p.x, p.y) if mundo != null else 0.6

func _halos() -> void:
	if postes.is_empty():
		return
	var sh := Shader.new()
	sh.code = SHADER_HALO
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = postes.size()
	for i in postes.size():
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 2.2), postes[i]))
		mm.set_instance_custom_data(i, COR_POSTE)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# o poste em si (fino, escuro): de longe só a lâmpada importa, mas de perto ele segura a luz
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.1
	pm.height = 6.2
	pm.radial_segments = 6
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.16, 0.17, 0.18)
	mp.metallic = 0.6
	pm.material = mp
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.mesh = pm
	mm2.instance_count = postes.size()
	for i in postes.size():
		mm2.set_instance_transform(i, Transform3D(Basis(), postes[i] - Vector3(0, 3.1, 0)))
	var mi2 := MultiMeshInstance3D.new()
	mi2.multimesh = mm2
	mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi2)

# janelas acesas e vitrines nas fachadas viradas para o caminho
func _janelas(caminho: PackedVector2Array, pontos: Array, rng: RandomNumberGenerator) -> void:
	if cidade == null:
		return
	var pr: PackedFloat32Array = cidade.predios
	var RotaGps = load("res://hud/rota_gps.gd")
	var janelas: Array = []          # [Transform3D, cor]
	var vitrines: Array = []
	var extra: Array = []
	for q in pontos:
		extra.append(Vector2(q.x, q.z))
	# retângulo em volta do caminho e dos pontos (descarta depressa os prédios longe)
	var caixa := Rect2()
	var primeiro := true
	for q in Array(caminho) + extra:
		if primeiro:
			caixa = Rect2(q, Vector2.ZERO)
			primeiro = false
		else:
			caixa = caixa.expand(q)
	caixa = caixa.grow(ALCANCE_PREDIO + 60.0)
	for i in range(0, pr.size(), 5):
		var c := Vector2(pr[i], pr[i + 1])
		if not caixa.has_point(c):
			continue
		var sx: float = pr[i + 2]
		var sz: float = pr[i + 3]
		var h: float = pr[i + 4]
		var raio := maxf(sx, sz) * 0.5
		var perto: float = RotaGps.distancia(caminho, c) if caminho.size() > 1 else INF
		for e in extra:
			perto = minf(perto, (e as Vector2).distance_to(c))
		if perto > ALCANCE_PREDIO + raio:
			continue
		# as 4 fachadas: só as que olham para o caminho (o meio da fachada mais perto do caminho que o centro)
		for f in 4:
			var n := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)][f] as Vector2
			var meia := sx * 0.5 if f < 2 else sz * 0.5
			var larg := sz if f < 2 else sx
			var meio := c + n * meia
			var dm: float = RotaGps.distancia(caminho, meio) if caminho.size() > 1 else INF
			for e2 in extra:
				dm = minf(dm, (e2 as Vector2).distance_to(meio))
			if dm > ALCANCE_PREDIO or dm >= perto:
				continue
			var lado := Vector2(-n.y, n.x)
			var base := _altura(meio)
			var giro := atan2(n.x, n.y)
			var cols := int(larg / 3.2)
			var andares := clampi(int(minf(h, 34.0) / 3.3), 1, 10)
			for a in andares:
				for k in cols:
					var off := (float(k) - (cols - 1) * 0.5) * 3.2
					var p := meio + n * 0.06 + lado * off
					if a == 0:
						if k % 2 == 0 and rng.randf() < 0.7:
							vitrines.append([Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(2.8, 2.0, 1)), Vector3(p.x, base + 1.4, p.y)),
								CORES_JANELA[rng.randi() % CORES_JANELA.size()]])
						continue
					if rng.randf() > 0.42:
						continue
					janelas.append([Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(1.3, 1.5, 1)), Vector3(p.x, base + a * 3.3 + 1.6, p.y)),
						CORES_JANELA[rng.randi() % CORES_JANELA.size()] * rng.randf_range(0.6, 1.0)])
	for grupo in [[janelas, 1.0], [vitrines, 1.25]]:
		var lista: Array = grupo[0]
		if lista.is_empty():
			continue
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(grupo[1], grupo[1], grupo[1])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		quad.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = lista.size()
		for j in lista.size():
			mm.set_instance_transform(j, lista[j][0])
			mm.set_instance_color(j, lista[j][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

# as luzes de verdade vão para os postes mais perto da câmera (a da cena ou a do jogo)
func _process(dt: float) -> void:
	if _luzes.is_empty() or postes.is_empty():
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.2
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pc := cam.global_position
	var ordem: Array = []
	for i in postes.size():
		var d: float = (postes[i] as Vector3).distance_squared_to(pc)
		if d < 160.0 * 160.0:
			ordem.append([d, i])
	ordem.sort_custom(func(x, y): return x[0] < y[0])
	for k in _luzes.size():
		var o: OmniLight3D = _luzes[k]
		if k < ordem.size():
			o.global_position = postes[ordem[k][1]] - Vector3(0, 0.4, 0)
			o.visible = true
		else:
			o.visible = false
