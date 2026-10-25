extends Node
# SENTIDOS DO MUTADO (0.95) · botão próprio SENTIDO (tecla H), só aparece para quem NÃO é humano (jogador/mutacao.gd).
# Criado por main.gd (_criar_jogo).
#   MUTADO (nível 1) · FAREJAR: por DURA s ele sente o CHEIRO das pessoas (outros jogadores e os sobreviventes do
#     hospital) até ALCANCE_CHEIRO m: cada uma aparece com uma AURA VERMELHA que pulsa, vista através das paredes,
#     e a borda da tela fica vermelha. Depois espera ESPERA s para usar de novo.
#     ESTALO DE DENTES (lore: o aviso sonoro dos mutados): a cada ESTALO_A_CADA s os dentes dele batem sozinhos. Quem
#     está perto ouve (som no lugar) e, no multijogador, ele aparece no MAPA dos outros como MUTADO por DURA s. Fora
#     disso o mutado NÃO aparece no mapa dos outros (rede: evento "estalo"; hud/mapa.gd lê marcas_mapa/escondido).
#   CONTROLADO (nível 2, quem tomou o soro · 2ª parte) · ESCUTAR (o "modo de escuta" de The Last of Us): por DURA s
#     o mundo fica cinza e quem está até ALCANCE_ESCUTA m (jogadores, infectados e sobreviventes) aparece como um
#     VULTO BRANCO DESFOCADO através das paredes. Depois espera ESPERA s.
# Mexa AQUI para: tempos, alcances e as cores dos efeitos.

const Sons := preload("res://audio/sons.gd")
const DURA := 10.0
const ESPERA := 20.0
const ESTALO_A_CADA := 30.0
const ALCANCE_CHEIRO := 250.0
const ALCANCE_ESCUTA := 40.0
const MAX_ALVOS := 24
const COR_CHEIRO := Color(0.95, 0.08, 0.05)
const COR_ESCUTA := Color(0.82, 0.88, 1.0)

# vulto através das paredes: sem teste de profundidade, somando luz; mais forte na borda (desfocado)
const SHADER_VULTO := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, blend_add, cull_back, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(0.82, 0.88, 1.0);
uniform float forca = 1.0;
void fragment() {
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.4);
	float onda = 0.8 + 0.2 * sin(TIME * 3.0 + VERTEX.y * 3.0);
	ALBEDO = cor * (0.3 + borda * 0.9) * onda * forca;
}
"""
# aura do cheiro: esfera que pulsa, sem teste de profundidade
const SHADER_AURA := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, blend_mix, cull_back, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(0.95, 0.08, 0.05);
uniform float forca = 1.0;
void fragment() {
	float centro = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float pulso = 0.7 + 0.3 * sin(TIME * 4.0);
	ALBEDO = cor * (0.7 + 0.5 * centro);
	ALPHA = clamp(centro * pulso * forca * 0.85, 0.0, 1.0);
}
"""
# tela: cinza escuro com o centro mais claro (ESCUTAR) ou borda vermelha (FAREJAR)
const SHADER_TELA := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float cinza = 0.0;
uniform float vermelho = 0.0;
void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	float borda = smoothstep(0.55, 1.05, length(SCREEN_UV - 0.5) * 1.6);
	vec3 g = mix(c, vec3(l) * 0.55, cinza);
	g = mix(g, g * vec3(0.9, 0.25, 0.2) + vec3(0.18, 0.0, 0.0), vermelho * borda);
	COLOR = vec4(g, 1.0);
}
"""

var main = null
var jogador = null
var ativo := 0.0                        # segundos restantes do sentido ligado
var espera := 0.0                       # segundos até poder usar de novo
var _t_estalo := ESTALO_A_CADA
var _t_alvos := 0.0
var _alvos := {}                        # nó alvo -> [aura (MeshInstance3D) ou null, [malhas com o vulto]]
var _mat_vulto: ShaderMaterial
var _mat_aura: ShaderMaterial
var _tela: CanvasLayer
var _mat_tela: ShaderMaterial
var _efeito := 0.0                      # 0..1 (entra e sai suave)
var _nivel_efeito := 0
static var _som_estalo: AudioStreamWAV = null
# multijogador: id -> [Vector2 posição, segundos restantes] dos mutados que estalaram (hud/mapa.gd)
var estalos := {}

func ligar(m) -> void:
	main = m
	jogador = m.jogador
	var sv := Shader.new()
	sv.code = SHADER_VULTO
	_mat_vulto = ShaderMaterial.new()
	_mat_vulto.shader = sv
	_mat_vulto.set_shader_parameter("cor", COR_ESCUTA)
	var sa := Shader.new()
	sa.code = SHADER_AURA
	_mat_aura = ShaderMaterial.new()
	_mat_aura.shader = sa
	_mat_aura.set_shader_parameter("cor", COR_CHEIRO)
	_tela = CanvasLayer.new()
	_tela.layer = 4                     # embaixo da HUD e dos botões
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Shader.new()
	st.code = SHADER_TELA
	_mat_tela = ShaderMaterial.new()
	_mat_tela.shader = st
	r.material = _mat_tela
	_tela.add_child(r)
	_tela.visible = false
	add_child(_tela)
	if m.controles != null:
		m.controles.sentido_pedido.connect(usar)

func nivel() -> int:
	return int(jogador.sobrevivencia.mutacao) if jogador != null and jogador.sobrevivencia != null else 0

# botão SENTIDO / tecla H
func usar() -> void:
	var n := nivel()
	if n == 0 or jogador.morto:
		return
	if ativo > 0.0:
		return
	if espera > 0.0:
		_aviso("%s DE NOVO EM %d s" % [_nome(n), ceili(espera)])
		return
	ativo = DURA
	_nivel_efeito = n
	_t_alvos = 0.0
	Sons.tocar("jogador/respiracao", -6.0, 0.7 if n == 1 else 1.0)
	_aviso("FAREJANDO..." if n == 1 else "ESCUTANDO...")

func _nome(n: int) -> String:
	return "FAREJAR" if n == 1 else "ESCUTAR"

func _aviso(t: String) -> void:
	if main != null and main.hud != null:
		main.hud.mostrar_aviso(t, 2.5)

func _process(dt: float) -> void:
	if jogador == null or not is_instance_valid(jogador):
		return
	var n := nivel()
	# botão: só para quem não é humano · texto com a espera
	var c = main.controles if main != null else null
	if c != null:
		c.ocultos["SENTIDO"] = n == 0
		c.indicadores["SENTIDO"] = ativo > 0.0
		c.textos["SENTIDO"] = ("%d" % ceili(espera)) if espera > 0.0 and ativo <= 0.0 else _nome(maxi(n, 1))
	if n == 0 or jogador.morto:
		if ativo > 0.0:
			ativo = 0.0
			espera = 0.0
		_t_estalo = ESTALO_A_CADA
	# tempo do sentido
	if ativo > 0.0:
		ativo -= dt
		if ativo <= 0.0:
			ativo = 0.0
			espera = ESPERA
	elif espera > 0.0:
		espera = maxf(0.0, espera - dt)
	_efeito = move_toward(_efeito, 1.0 if ativo > 0.0 else 0.0, dt * 2.5)
	_atualizar_efeito(dt)
	# estalo de dentes do mutado
	if n == 1 and not jogador.morto:
		_t_estalo -= dt
		if _t_estalo <= 0.0:
			_t_estalo = ESTALO_A_CADA
			estalar()
	# marcas dos outros mutados no mapa
	for id in estalos.keys():
		estalos[id][1] -= dt
		if estalos[id][1] <= 0.0:
			estalos.erase(id)

# ---------- estalo de dentes ----------
func estalar() -> void:
	var p: Vector3 = jogador.global_position
	_tocar_estalo(p, true)
	if Rede.ligado:
		Rede.enviar_evento("estalo", {"p": p})
		_aviso("ESTALO DE DENTES · OS OUTROS TE VEEM NO MAPA (%d s)" % int(DURA))

# chegou pela rede (rede/sessao_rede.gd): um mutado estalou em "p"
func estalo_remoto(id: int, d: Dictionary) -> void:
	var p: Vector3 = d.get("p", Vector3.ZERO)
	estalos[id] = [Vector2(p.x, p.z), DURA]
	_tocar_estalo(p, false)

func _tocar_estalo(p: Vector3, meu: bool) -> void:
	if _som_estalo == null:
		_som_estalo = _fazer_estalo()
	var s := AudioStreamPlayer3D.new()
	s.stream = _som_estalo
	s.unit_size = 6.0
	s.max_distance = 45.0
	s.volume_db = -6.0 if meu else 2.0
	s.pitch_scale = randf_range(0.92, 1.08)
	s.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	main.add_child(s)
	s.global_position = p + Vector3(0, 1.6, 0)
	s.play()
	s.finished.connect(s.queue_free)

# som feito por código: 9 estalos secos e rápidos (dentes batendo), cada vez mais fracos
static func _fazer_estalo() -> AudioStreamWAV:
	var taxa := 22050
	var total := int(taxa * 0.75)
	var dados := PackedByteArray()
	dados.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var inicios: Array = []
	var t0 := 0.02
	for k in 9:
		inicios.append(t0)
		t0 += rng.randf_range(0.055, 0.085)
	for i in total:
		var t := float(i) / taxa
		var v := 0.0
		for k in inicios.size():
			var de: float = t - float(inicios[k])
			if de >= 0.0 and de < 0.014:
				v += (rng.randf_range(-1.0, 1.0) * 0.6 + sin(TAU * 2400.0 * de) * 0.4) * exp(-de * 420.0) * (1.0 - k * 0.07)
		dados.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.data = dados
	return w

# ---------- efeitos ----------
func _atualizar_efeito(dt: float) -> void:
	_tela.visible = _efeito > 0.01
	_mat_tela.set_shader_parameter("cinza", _efeito * 0.75 if _nivel_efeito == 2 else 0.0)
	_mat_tela.set_shader_parameter("vermelho", _efeito * 0.7 if _nivel_efeito == 1 else 0.0)
	_mat_vulto.set_shader_parameter("forca", _efeito)
	_mat_aura.set_shader_parameter("forca", _efeito)
	if _efeito <= 0.0:
		if not _alvos.is_empty():
			_limpar()
		return
	_t_alvos -= dt
	if _t_alvos <= 0.0 and ativo > 0.0:
		_t_alvos = 0.5
		_procurar()
	# as auras acompanham as pessoas (de longe, maiores para continuar visíveis)
	var cam := get_viewport().get_camera_3d()
	for a in _alvos:
		var aura = _alvos[a][0]
		if aura != null and is_instance_valid(a) and is_instance_valid(aura):
			aura.global_position = (a as Node3D).global_position + Vector3(0, 1.1, 0)
			var d := cam.global_position.distance_to(aura.global_position) if cam != null else 10.0
			aura.scale = Vector3.ONE * maxf(1.0, d / 22.0)

# quem aparece agora
func candidatos() -> Array:
	var l := []
	var p: Vector3 = jogador.global_position
	var alcance := ALCANCE_CHEIRO if _nivel_efeito == 1 else ALCANCE_ESCUTA
	var s = main.get("sessao_rede")
	if s != null and is_instance_valid(s):
		for id in s.remotos:
			var r = s.remotos[id]
			if is_instance_valid(r) and r.visible and not r.morto and not (_nivel_efeito == 1 and r.mutado):
				l.append(r)
	for npc in get_tree().get_nodes_in_group("npcs_hospital"):
		l.append(npc)
	if _nivel_efeito == 2 and main.vagos != null:
		for v in main.vagos.vivos:
			if is_instance_valid(v) and v.estado != v.MORTO:
				l.append(v)
	var perto := []
	for a in l:
		var d := p.distance_to((a as Node3D).global_position)
		if d <= alcance:
			perto.append([d, a])
	perto.sort_custom(func(x, y): return x[0] < y[0])
	var r2 := []
	for i in mini(perto.size(), MAX_ALVOS):
		r2.append(perto[i][1])
	return r2

func _procurar() -> void:
	var novos := candidatos()
	for a in _alvos.keys():
		if not is_instance_valid(a) or not a in novos:
			_tirar(a)
	for a in novos:
		if _alvos.has(a):
			continue
		if _nivel_efeito == 1:
			var aura := MeshInstance3D.new()
			var esf := SphereMesh.new()
			esf.radius = 0.9
			esf.height = 1.8
			esf.radial_segments = 16
			esf.rings = 8
			aura.mesh = esf
			aura.material_override = _mat_aura
			aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			main.add_child(aura)
			aura.global_position = (a as Node3D).global_position + Vector3(0, 1.1, 0)
			_alvos[a] = [aura, []]
		else:
			var malhas := []
			var mod = a.get("modelo")
			var raiz: Node = mod if mod is Node else a
			for mi in raiz.find_children("*", "MeshInstance3D", true, false):
				if mi.material_overlay == null:
					mi.material_overlay = _mat_vulto
					malhas.append(mi)
			_alvos[a] = [null, malhas]

func _tirar(a) -> void:
	var e: Array = _alvos[a]
	if e[0] != null and is_instance_valid(e[0]):
		e[0].queue_free()
	for mi in e[1]:
		if is_instance_valid(mi) and mi.material_overlay == _mat_vulto:
			mi.material_overlay = null
	_alvos.erase(a)

func _limpar() -> void:
	for a in _alvos.keys():
		_tirar(a)

func _exit_tree() -> void:
	_limpar()

# hud/mapa.gd: este jogador remoto fica escondido no mapa? (mutado sem estalar)
func escondido(id: int, r) -> bool:
	return bool(r.get("mutado")) and not estalos.has(id)
