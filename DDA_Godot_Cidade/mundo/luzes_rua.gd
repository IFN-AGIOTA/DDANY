extends RefCounted
# FIOS DE POSTE E HALOS DE LUZ (0.84) · Opções › Gráficos "Fios de poste" e "Halos de luz".
#   - FIOS: entre dois postes seguidos do mesmo lado da rua (mundo/abandono.gd anota onde cada um fica), 2 fios
#     caídos em curva (catenária). Poste caído = a linha de fios para ali. Uma malha por bloco de 250 m (1 desenho).
#   - HALOS: um brilho (quadrado sempre virado para a câmera, somado à cena, sem luz de verdade: leve) na lâmpada
#     dos postes que ainda têm energia (CHANCE_ACESO, sempre os mesmos) e nos SEMÁFOROS, que piscam em amarelo.
#     Só aparecem à noite: mundo/clima.gd chama noite() com a escuridão do céu (de dia os nós nem são desenhados).
#     Um MultiMesh por bloco de 500 m.
# Mexa AQUI para: cor/tamanho dos halos, quantos postes acesos, quanto o fio cai e até onde aparecem.

const Malhas := preload("res://mundo/malhas.gd")

const BLOCO := 500.0                     # blocos grandes: poucos desenhos
const CHANCE_ACESO := 0.3
const FIO_ALCANCE := 320.0
const HALO_ALCANCE := 1100.0
const CAIDA := 0.7                       # quanto o fio cai no meio do vão (m)
const COR_FIO := Color(0.06, 0.06, 0.06)
const COR_POSTE := Color(1.0, 0.78, 0.45)
const COR_SEMAFORO := Color(1.0, 0.62, 0.1)

const SHADER_HALO := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float noite = 0.0;
varying vec4 cor;
void vertex() {
	cor = INSTANCE_CUSTOM;
	// sempre virado para a câmera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = pow(max(1.0 - r, 0.0), 2.2);
	// semáforo (cor.a > 0.5): pisca em amarelo, cada um no seu tempo
	float pisca = cor.a > 0.5 ? step(0.5, fract(TIME * 0.8 + cor.a * 7.0)) : 1.0;
	ALBEDO = cor.rgb * a * noite * pisca * 1.6;
}
"""

static var _mat: ShaderMaterial = null
static var _halos: Array = []            # nós dos halos (de dia ficam escondidos)
static var opcao_halos := true           # Opções › Gráficos "Halos de luz"
static var _noite := 0.0

static func material() -> ShaderMaterial:
	if _mat == null:
		var s := Shader.new()
		s.code = SHADER_HALO
		_mat = ShaderMaterial.new()
		_mat.shader = s
	return _mat

# 0 = dia ... 1 = noite fechada (mundo/clima.gd)
static func noite(escuridao: float) -> void:
	_noite = clampf((escuridao - 0.35) / 0.45, 0.0, 1.0)
	material().set_shader_parameter("noite", _noite)
	_mostrar()

static func ligar_halos(v: bool) -> void:
	opcao_halos = v
	_mostrar()

static func _mostrar() -> void:
	var ver := opcao_halos and _noite > 0.0
	var vivos: Array = []
	for n in _halos:
		if is_instance_valid(n):
			n.visible = ver
			vivos.append(n)
	_halos = vivos

static func _bloco(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / BLOCO), floori(p.z / BLOCO))

# fios: [[a, b], ...] (pontos de amarração no topo dos postes) · devolve os nós (um por bloco)
static func montar_fios(fios: Array) -> Array:
	var por_bloco := {}
	for f in fios:
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var k := _bloco((a + b) * 0.5)
		if not por_bloco.has(k):
			por_bloco[k] = Malhas.Construtor.new()
		var c = por_bloco[k]
		var lado := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * 0.18
		for desvio in [lado, -lado]:
			var n := 5
			var ant: Vector3 = a + desvio
			for i in range(1, n + 1):
				var t := float(i) / n
				var q: Vector3 = a.lerp(b, t) + desvio - Vector3(0, CAIDA * 4.0 * t * (1.0 - t), 0)
				var m := (ant + q) * 0.5
				var d := q - ant
				var L := d.length()
				if L > 0.01:
					var z := d / L
					var x := Vector3.UP.cross(z).normalized()
					var y := z.cross(x)
					c.caixa(m, Vector3(0.025, 0.025, L), COR_FIO, Basis(x, y, z))
				ant = q
	var nos: Array = []
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	for k in por_bloco:
		var mi := MeshInstance3D.new()
		mi.name = "Fios_%d_%d" % [k.x, k.y]
		mi.mesh = por_bloco[k].malha(mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = FIO_ALCANCE
		mi.add_to_group("fios_poste")
		nos.append(mi)
	return nos

# halos: [[posição, é semáforo], ...] · devolve os nós (um MultiMesh por bloco)
static func montar_halos(halos: Array) -> Array:
	var por_bloco := {}
	for h in halos:
		var k := _bloco(h[0])
		if not por_bloco.has(k):
			por_bloco[k] = []
		por_bloco[k].append(h)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = material()
	var nos: Array = []
	for k in por_bloco:
		var lista: Array = por_bloco[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = lista.size()
		for i in lista.size():
			var sem: bool = lista[i][1]
			var tam := 1.6 if sem else 2.6
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * tam), lista[i][0]))
			var cor: Color = COR_SEMAFORO if sem else COR_POSTE
			cor.a = (0.51 + fposmod((lista[i][0] as Vector3).x * 0.013, 0.48)) if sem else 0.0
			mm.set_instance_custom_data(i, cor)
		var mi := MultiMeshInstance3D.new()
		mi.name = "Halos_%d_%d" % [k.x, k.y]
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = HALO_ALCANCE
		mi.add_to_group("halos_luz")
		mi.visible = opcao_halos and _noite > 0.0
		_halos.append(mi)
		nos.append(mi)
	return nos
