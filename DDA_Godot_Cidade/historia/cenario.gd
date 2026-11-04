extends Node3D
# 1.14 · CENÁRIOS DOS INTERIORES DO MODO HISTÓRIA (o bar dos corredores; depois, os apartamentos): cada um é montado
# LONGE da cidade (ORIGEM, no alto, em cima do mar ao norte: nada da cidade aparece nem colide), com paredes, móveis,
# luz e colisão próprios. A PORTA fica numa fachada de verdade na rua (fachada()); ao entrar, a tela escurece e o
# jogador vai para dentro do cenário (é o jeito dos jogos com interiores caprichados).
# Texturas: as mesmas livres do jogo (mundo/texturas, Poly Haven CC0), LIMPAS (a cidade antes do caos), aplicadas
# sozinhas em qualquer caixa (triplanar). pontos = lugares nomeados do cenário (porta, mesa do canto, TV...).
# Mexa AQUI para: o tamanho do bar, os móveis, as luzes e o noticiário da TV.

const Mat := preload("res://mundo/materiais_cidade.gd")
const Malhas := preload("res://mundo/malhas.gd")
const Moveis := preload("res://mundo/moveis.gd")

const ORIGEM := Vector3(-1500.0, 900.0, -9000.0)

var pontos := {}                     # nome -> Vector3 (global)
var tv: SubViewport = null
var _corpo: StaticBody3D
var _t := 0.0
var _luz_tv: OmniLight3D = null
var _faixa: Label = null
var _cidade_tv: Label = null
var _cenas_tv := ["TÓQUIO", "PARIS", "NOVA YORK"]

func _tex_mat(nome: String, tinta: Color, escala := 0.5, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Mat._textura(nome)
	m.albedo_color = tinta
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * escala
	m.roughness = rough
	return m

func _caixa(p: Vector3, tam: Vector3, mat: Material, colide := true, giro := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	bm.material = mat
	mi.mesh = bm
	mi.position = p
	mi.rotation.y = giro
	add_child(mi)
	if colide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = tam
		cs.shape = bs
		cs.position = p
		cs.rotation.y = giro
		_corpo.add_child(cs)
	return mi

func _cor(c: Color, rough := 0.7, metal := 0.0, emissao := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissao
	return m

func _luz(p: Vector3, cor: Color, energia: float, alcance: float, sombra := false) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = p
	o.light_color = cor
	o.light_energy = energia
	o.omni_range = alcance
	o.shadow_enabled = sombra
	add_child(o)
	return o

# sala fechada (piso, paredes, teto) de w x d x h, com a porta no meio da parede da frente (-Z)
func _sala(w: float, d: float, h: float, piso: Material, parede: Material, teto: Material) -> void:
	_caixa(Vector3(0, -0.1, 0), Vector3(w + 0.4, 0.2, d + 0.4), piso)
	_caixa(Vector3(0, h + 0.1, 0), Vector3(w + 0.4, 0.2, d + 0.4), teto)
	_caixa(Vector3(-w * 0.5 - 0.1, h * 0.5, 0), Vector3(0.2, h, d), parede)
	_caixa(Vector3(w * 0.5 + 0.1, h * 0.5, 0), Vector3(0.2, h, d), parede)
	_caixa(Vector3(0, h * 0.5, d * 0.5 + 0.1), Vector3(w, h, 0.2), parede)
	# parede da frente com o vão da porta (1,4 m)
	var lado := (w - 1.4) * 0.5
	_caixa(Vector3(-0.7 - lado * 0.5, h * 0.5, -d * 0.5 - 0.1), Vector3(lado, h, 0.2), parede)
	_caixa(Vector3(0.7 + lado * 0.5, h * 0.5, -d * 0.5 - 0.1), Vector3(lado, h, 0.2), parede)
	_caixa(Vector3(0, h - 0.4, -d * 0.5 - 0.1), Vector3(1.4, 0.8, 0.2), parede)
	# a porta (fechada: o jogador sai pela interação)
	_caixa(Vector3(0, 1.1, -d * 0.5 - 0.16), Vector3(1.4, 2.2, 0.08), _cor(Color(0.22, 0.13, 0.08), 0.6))

func _moveis(lista: Array) -> void:
	# lista: [nome, posição local, giro]
	var c := Malhas.Construtor.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var col: Array = []
	var cont: Array = []
	for m in lista:
		Moveis.desenhar(str(m[0]), c, m[1], Basis(Vector3.UP, float(m[2])), rng, col, cont)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.75
	var mi := MeshInstance3D.new()
	mi.mesh = c.malha(mat)
	add_child(mi)
	for k in col:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = k[1]
		cs.shape = bs
		cs.position = k[0]
		cs.rotation.y = -float(k[2])
		_corpo.add_child(cs)

func _ponto(nome: String, local: Vector3) -> void:
	pontos[nome] = global_transform * local

# ---------- O BAR DOS CORREDORES (Cap. 2) ----------
# "As paredes eram sujas, os copos mal lavados, mas era o único lugar onde se sentiam seguros. Sentaram-se na mesa
# do canto, enquanto uma televisão passava as notícias em segundo plano."
func montar_bar() -> void:
	position = ORIGEM
	_corpo = StaticBody3D.new()
	add_child(_corpo)
	var w := 14.0
	var d := 10.0
	var h := 3.4
	_sala(w, d, h, _tex_mat("interior_madeira", Color(0.55, 0.42, 0.32), 0.45), _tex_mat("predio_tijolo", Color(0.62, 0.45, 0.38), 0.4),
		_tex_mat("interior_concreto", Color(0.25, 0.24, 0.24), 0.3))
	# balcão ao longo da parede da direita, com as garrafas atrás
	var madeira := _tex_mat("interior_madeira", Color(0.35, 0.22, 0.14), 0.8, 0.5)
	_caixa(Vector3(4.6, 0.55, 0.8), Vector3(0.7, 1.1, 6.5), madeira)
	_caixa(Vector3(4.55, 1.13, 0.8), Vector3(0.95, 0.06, 6.8), _cor(Color(0.12, 0.08, 0.05), 0.25, 0.1))
	_caixa(Vector3(6.75, 1.5, 0.8), Vector3(0.3, 2.4, 6.5), madeira)
	for prateleira in [1.25, 1.75, 2.25]:
		_caixa(Vector3(6.5, prateleira, 0.8), Vector3(0.35, 0.04, 6.4), madeira, false)
	_garrafas(Vector3(6.5, 0, 0.8), 6.0)
	# banquetas do balcão
	var banco := _cor(Color(0.6, 0.12, 0.1), 0.5)
	var ferro := _cor(Color(0.2, 0.2, 0.22), 0.4, 0.8)
	for k in 5:
		var z := -1.6 + k * 1.2
		var pe := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.12
		cm.height = 0.75
		cm.material = ferro
		pe.mesh = cm
		pe.position = Vector3(3.75, 0.38, z)
		add_child(pe)
		var as_ := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.2
		cm2.bottom_radius = 0.2
		cm2.height = 0.08
		cm2.material = banco
		as_.mesh = cm2
		as_.position = Vector3(3.75, 0.78, z)
		add_child(as_)
	# mesas (a do CANTO é a dos dois: fundo à esquerda)
	_moveis([["mesa_bar", Vector3(-4.6, 0, 3.4), PI], ["mesa_bar", Vector3(-1.2, 0, 3.4), PI], ["mesa_bar", Vector3(-4.6, 0, -0.6), PI],
		["mesa_bar", Vector3(-1.2, 0, -0.6), PI], ["luminaria", Vector3(-6.4, 0, 4.4), PI]])
	# mesa de sinuca no meio
	_caixa(Vector3(1.0, 0.75, -3.0), Vector3(2.6, 0.18, 1.4), _cor(Color(0.08, 0.32, 0.16), 0.9))
	_caixa(Vector3(1.0, 0.38, -3.0), Vector3(2.3, 0.75, 1.1), madeira)
	# a TV na parede do fundo, virada para a mesa do canto
	_tv(Vector3(-3.2, 2.35, d * 0.5 - 0.06))
	# letreiro de neon por dentro e quadros
	var neon := Label3D.new()
	neon.text = "A MORTE DO MEDO"
	neon.font_size = 64
	neon.pixel_size = 0.004
	neon.modulate = Color(1.0, 0.25, 0.45)
	neon.outline_size = 0
	neon.shaded = false
	neon.position = Vector3(6.55, 2.85, 0.8)
	neon.rotation.y = -PI * 0.5
	add_child(neon)
	_luz(Vector3(6.0, 2.8, 0.8), Color(1.0, 0.3, 0.5), 0.7, 5.0)
	# luzes: pendentes quentes sobre as mesas e o balcão (pouca luz: um bar escuro)
	for p in [Vector3(-4.6, 2.9, 3.4), Vector3(-1.2, 2.9, 3.4), Vector3(-4.6, 2.9, -0.6), Vector3(-1.2, 2.9, -0.6), Vector3(1.0, 2.9, -3.0), Vector3(4.4, 2.9, 0.8)]:
		_luz(p, Color(1.0, 0.72, 0.42), 1.1, 5.5, p.x < -4.0 and p.z > 3.0)
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.18
		sm.material = _cor(Color(1.0, 0.75, 0.45), 0.4, 0.0, 3.0)
		lamp.mesh = sm
		lamp.position = p
		add_child(lamp)
	var amb := _luz(Vector3(0, 2.6, 0), Color(0.6, 0.55, 0.6), 0.35, 14.0)
	amb.name = "Ambiente"
	# pontos
	_ponto("porta", Vector3(0, 0, -d * 0.5 + 0.9))
	_ponto("dentro", Vector3(0, 0, -d * 0.5 + 1.6))
	_ponto("mesa_canto", Vector3(-4.6, 0, 3.4))
	_ponto("cadeira_dom", Vector3(-4.6, 0, 2.55))
	_ponto("cadeira_greg", Vector3(-4.6, 0, 4.25))
	_ponto("tv", Vector3(-3.2, 2.35, d * 0.5 - 0.06))
	_ponto("balcao", Vector3(4.0, 0, 0.8))
	_ponto("atras_balcao", Vector3(5.4, 0, 0.6))
	_ponto("mesa_2", Vector3(-1.2, 0, -0.6))
	_ponto("sinuca", Vector3(1.0, 0, -3.0))

func _garrafas(base: Vector3, compr: float) -> void:
	var cores := [Color(0.25, 0.45, 0.2), Color(0.45, 0.25, 0.1), Color(0.75, 0.75, 0.8), Color(0.5, 0.1, 0.12), Color(0.85, 0.6, 0.2)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for prat in [1.27, 1.77, 2.27]:
		var z := -compr * 0.5 + 0.15
		while z < compr * 0.5 - 0.15:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			var alt := rng.randf_range(0.24, 0.34)
			cm.top_radius = 0.025
			cm.bottom_radius = 0.045
			cm.height = alt
			cm.radial_segments = 8
			var cor: Color = cores[rng.randi() % cores.size()]
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(cor.r, cor.g, cor.b, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.1
			m.metallic = 0.2
			m.emission_enabled = true
			m.emission = cor * 0.25
			cm.material = m
			mi.mesh = cm
			mi.position = base + Vector3(rng.randf_range(-0.08, 0.08), prat + alt * 0.5, z)
			add_child(mi)
			z += rng.randf_range(0.11, 0.2)

# ---------- A TV com o NOTICIÁRIO (SubViewport: a tela é uma textura viva) ----------
func _tv(p: Vector3) -> void:
	tv = SubViewport.new()
	tv.size = Vector2i(512, 288)
	tv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(tv)
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.08, 0.16)
	fundo.size = Vector2(512, 288)
	tv.add_child(fundo)
	# "imagens": gente correndo (silhuetas que passam), sirenes (luzes que piscam)
	var cena := Control.new()
	cena.name = "Cena"
	cena.size = Vector2(512, 214)
	tv.add_child(cena)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 14:
		var r := ColorRect.new()
		r.color = Color(0.02, 0.02, 0.03)
		r.size = Vector2(rng.randf_range(10, 18), rng.randf_range(38, 60))
		r.position = Vector2(rng.randf_range(0, 512), 214 - r.size.y - rng.randf_range(0, 20))
		r.set_meta("v", rng.randf_range(60, 160))
		cena.add_child(r)
	for k in 2:
		var s := ColorRect.new()
		s.name = "Sirene%d" % k
		s.color = Color(1, 0.1, 0.1, 0.16) if k == 0 else Color(0.2, 0.35, 1, 0.16)   # só um clarão leve
		s.size = Vector2(512, 214)
		cena.add_child(s)
	# barra vermelha de URGENTE + letreiro correndo + AO VIVO + a cidade
	var barra := ColorRect.new()
	barra.color = Color(0.75, 0.05, 0.05)
	barra.position = Vector2(0, 214)
	barra.size = Vector2(512, 40)
	tv.add_child(barra)
	var urg := Label.new()
	urg.text = "URGENTE"
	urg.add_theme_font_size_override("font_size", 22)
	urg.add_theme_color_override("font_color", Color.WHITE)
	urg.position = Vector2(8, 220)
	tv.add_child(urg)
	var faixa_fundo := ColorRect.new()
	faixa_fundo.color = Color(0.04, 0.04, 0.06)
	faixa_fundo.position = Vector2(0, 254)
	faixa_fundo.size = Vector2(512, 34)
	tv.add_child(faixa_fundo)
	_faixa = Label.new()
	_faixa.text = "RELATOS DE ATAQUES VIOLENTOS EM VÁRIAS CIDADES DO MUNDO · AUTORIDADES INVESTIGAM POSSÍVEL MUTAÇÃO VIRAL ASSOCIADA A COMPORTAMENTO AGRESSIVO EXTREMO · EVITE AGLOMERAÇÕES · "
	_faixa.add_theme_font_size_override("font_size", 18)
	_faixa.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_faixa.position = Vector2(512, 259)
	tv.add_child(_faixa)
	var vivo := Label.new()
	vivo.text = "● AO VIVO"
	vivo.add_theme_font_size_override("font_size", 16)
	vivo.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	vivo.position = Vector2(420, 10)
	tv.add_child(vivo)
	_cidade_tv = Label.new()
	_cidade_tv.text = "TÓQUIO"
	_cidade_tv.add_theme_font_size_override("font_size", 26)
	_cidade_tv.add_theme_color_override("font_color", Color.WHITE)
	_cidade_tv.position = Vector2(14, 10)
	tv.add_child(_cidade_tv)
	# o aparelho
	_caixa(p + Vector3(0, 0, 0.04), Vector3(1.5, 0.9, 0.08), _cor(Color(0.04, 0.04, 0.05), 0.3), false)
	var tela := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.36, 0.765)
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = tv.get_texture()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = mt
	tela.mesh = qm
	tela.position = p + Vector3(0, 0, -0.005)
	tela.rotation.y = PI                       # a tela olha para dentro do bar (-Z)
	add_child(tela)
	_luz_tv = _luz(p + Vector3(0, -0.2, -0.8), Color(0.45, 0.55, 1.0), 0.6, 4.0)

func _process(dt: float) -> void:
	if tv == null:
		return
	_t += dt
	# letreiro correndo, gente passando, sirene piscando, a cidade trocando
	if _faixa != null:
		_faixa.position.x -= dt * 70.0
		if _faixa.position.x < -_faixa.size.x:
			_faixa.position.x = 512.0
	var cena := tv.get_node_or_null("Cena")
	if cena != null:
		for r in cena.get_children():
			if r.has_meta("v"):
				r.position.x -= float(r.get_meta("v")) * dt
				if r.position.x < -20.0:
					r.position.x = 530.0
		var fase := int(_t * 3.0) % 2
		cena.get_node("Sirene0").visible = fase == 0
		cena.get_node("Sirene1").visible = fase == 1
	if _cidade_tv != null:
		_cidade_tv.text = _cenas_tv[int(_t / 4.0) % _cenas_tv.size()]
	if _luz_tv != null:
		_luz_tv.light_energy = 0.45 + 0.25 * absf(sin(_t * 7.0)) + (0.2 if int(_t * 3.0) % 2 == 0 else 0.0)
		_luz_tv.light_color = Color(0.8, 0.3, 0.35) if int(_t * 3.0) % 2 == 0 else Color(0.4, 0.5, 1.0)

# a fachada de prédio mais perto de um ponto da rua: [ponto no chão da fachada (x, z), normal (para a rua)]
static func fachada_perto(cidade, rua: Vector2, raio := 90.0) -> Array:
	var pr: PackedFloat32Array = cidade.predios
	var melhor := INF
	var mp := rua
	var mn := Vector2(0, 1)
	for i in range(0, pr.size(), 5):
		var c := Vector2(pr[i], pr[i + 1])
		if c.distance_to(rua) > raio:
			continue
		var hx: float = pr[i + 2] * 0.5
		var hz: float = pr[i + 3] * 0.5
		if hx < 4.0 or hz < 4.0:
			continue
		var q := Vector2(clampf(rua.x, c.x - hx, c.x + hx), clampf(rua.y, c.y - hz, c.y + hz))
		var d := q.distance_to(rua)
		if d < melhor and d > 2.0:
			melhor = d
			mp = q
			var dx := absf(q.x - (c.x + hx)) if rua.x > c.x else absf(q.x - (c.x - hx))
			var dz := absf(q.y - (c.y + hz)) if rua.y > c.y else absf(q.y - (c.y - hz))
			mn = Vector2(signf(rua.x - c.x), 0.0) if dx < dz else Vector2(0.0, signf(rua.y - c.y))
	return [mp, mn]

# ---------- a FACHADA na rua (porta + letreiro de neon + toldo), presa num prédio de verdade ----------
# p = meio da fachada no chão (x, y, z) · giro = para onde a fachada olha (a rua)
static func fachada(pai: Node, p: Vector3, giro: float, nome: String) -> Node3D:
	var f := Node3D.new()
	f.name = "Fachada"
	pai.add_child(f)
	f.global_position = p
	f.rotation.y = giro
	var porta := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 2.3, 0.12)
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.2, 0.12, 0.07)
	bm.material = mp
	porta.mesh = bm
	porta.position = Vector3(0, 1.15, 0.06)
	f.add_child(porta)
	var vitrine := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(3.0, 1.6)
	var mv := StandardMaterial3D.new()
	mv.albedo_color = Color(1.0, 0.72, 0.4)
	mv.emission_enabled = true
	mv.emission = Color(1.0, 0.6, 0.3)
	mv.emission_energy_multiplier = 0.8
	qm.material = mv
	vitrine.mesh = qm
	vitrine.position = Vector3(2.6, 1.5, 0.07)
	f.add_child(vitrine)
	var toldo := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(7.0, 0.12, 1.4)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.45, 0.06, 0.08)
	tb.material = mt
	toldo.mesh = tb
	toldo.position = Vector3(1.2, 2.75, 0.7)
	toldo.rotation.x = 0.15
	f.add_child(toldo)
	var neon := Label3D.new()
	neon.text = nome
	neon.font_size = 96
	neon.pixel_size = 0.006
	neon.modulate = Color(1.0, 0.3, 0.5)
	neon.shaded = false
	neon.position = Vector3(1.2, 3.5, 0.1)
	f.add_child(neon)
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.3, 0.5)
	o.light_energy = 1.6
	o.omni_range = 9.0
	o.position = Vector3(1.2, 3.3, 1.2)
	f.add_child(o)
	var o2 := OmniLight3D.new()
	o2.light_color = Color(1.0, 0.7, 0.4)
	o2.light_energy = 1.0
	o2.omni_range = 6.0
	o2.position = Vector3(2.6, 1.4, 1.5)
	f.add_child(o2)
	return f
