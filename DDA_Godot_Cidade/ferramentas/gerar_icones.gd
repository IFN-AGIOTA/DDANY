extends SceneTree
# GERA OS ÍCONES DO INVENTÁRIO a partir dos MODELOS 3D do jogo ("foto" de cada item, fundo transparente):
#   comida, remédios e ferramentas com modelo realista (inventario/modelos_itens.gd), armas de fogo (e as versões com silenciador/mira encaixados: m4_cano, m4_mira, m4_cano_mira...),
#   armas brancas, acessórios, chapéus/capacete, mochilas, pochete, coletes e roupas (camisas e calças
#   são feitas da própria malha do sobrevivente, "estendidas" como numa vitrine).
# Saída: inventario/icones/<id>.png, já no formato do item na grade (w x h células). O inventário
# (inventario/visual.gd) usa a imagem quando ela existe; os outros itens continuam desenhados por código.
# Rodar (precisa de tela; no servidor use xvfb-run), dentro da pasta DDA_Godot_Cidade:
#   godot --rendering-driver opengl3 -s ferramentas/gerar_icones.gd
#   godot --headless --import          (para a Godot importar os PNG novos)
# Esta pasta (ferramentas/) não vai para o APK.

const Itens := preload("res://inventario/itens.gd")
const ModelosArmas := preload("res://armas/modelos_armas.gd")
const Equip := preload("res://equipamentos/modelos_equip.gd")
const Sob := preload("res://jogador/modelo_sobrevivente.gd")
const ModelosItens := preload("res://inventario/modelos_itens.gd")
# itens com modelo realista que continuam com o ícone desenhado por código (o desenho diferencia melhor:
# munições de calibres diferentes, água limpa x suja x garrafa vazia)
const SEM_FOTO := ["mun_9mm", "mun_556", "mun_762", "mun_12", "mun_308", "agua_suja", "garrafa_vazia", "bandagem"]

const PASTA := "res://inventario/icones/"
const CEL := 64                        # pixels por célula da grade
const RES := 1024                      # tamanho da foto antes de recortar

var vp: SubViewport
var cam: Camera3D
var palco: Node3D
var _corpo_arrays: Array = []

func _initialize() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	_montar_estudio()
	# armas de fogo: de lado, cano para a direita
	for id in ["pistola", "m4", "ak", "espingarda", "rifle_caca"]:
		var acess: Array = Itens.def(id).get("acess", [])
		var combos: Array = [[]]
		for a in acess:
			var novos: Array = []
			for c in combos:
				novos.append(c + [a])
			combos += novos
		for c in combos:
			var nome: String = id
			for a in c:
				nome += "_" + a
			await _foto(nome, Itens.def(id), _arma(id, c), "lado")
	# armas brancas: em pé (cabo embaixo)
	for id in ["faca", "facao", "taco", "machado", "cano", "lanca", "pe_de_cabra"]:
		await _foto(id, Itens.def(id), _arma(id, []), "lado_em_pe")
	# comida, remédios, ferramentas (modelos realistas de inventario/modelos_itens.gd)
	var com_modelo: Array = ModelosItens.ITENS.keys() + ["refrigerante", "analgesico", "vitaminas", "antibiotico", "carvao", "pastilha"]
	for id in com_modelo:
		if id in SEM_FOTO:
			continue
		await _foto(id, Itens.def(id), ModelosItens.instancia(id, false), "de_cima" if id == "galho" else "tres_quartos")
	# acessórios
	for id in ["silenciador", "mira_acog", "luneta"]:
		var mi := MeshInstance3D.new()
		mi.mesh = load("res://equipamentos/modelos/" + id + ".res")
		await _foto(id, Itens.def(id), mi, "lado")
	# cabeça, mochilas, pochete
	for id in ["capacete", "bone", "gorro", "lanterna_cabeca"]:
		await _foto(id, Itens.def(id), Equip.instancia(id), "tres_quartos")
	for id in ["mochila_escolar", "mochila_trilha", "mochila_combate"]:
		await _foto(id, Itens.def(id), Equip.instancia(id), "costas")
	await _foto("pochete", Itens.def("pochete"), Equip.instancia("pochete"), "tres_quartos")
	# roupas feitas da malha do corpo
	for id in Sob.CAMISAS:
		await _foto(id, Itens.def(id), _roupa(id), "frente")
	for id in Sob.CALCAS:
		await _foto(id, Itens.def(id), _roupa(id), "frente")
	for id in Sob.COLETES:
		await _foto(id, Itens.def(id), _roupa(id), "frente")
	print("ícones prontos em ", PASTA)
	quit()

# ---------- estúdio: luz, câmera e fundo transparente ----------
func _montar_estudio() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(RES, RES)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()                    # luz principal: de cima, da frente e da esquerda
	sol.light_energy = 1.25
	vp.add_child(sol)
	sol.look_at_from_position(Vector3(-2, 4, 3), Vector3.ZERO)
	var recorte := DirectionalLight3D.new()                # luz de contorno: de trás
	recorte.light_energy = 0.5
	recorte.light_color = Color(0.85, 0.9, 1.0)
	vp.add_child(recorte)
	recorte.look_at_from_position(Vector3(3, 2, -4), Vector3.ZERO)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	palco = Node3D.new()
	vp.add_child(palco)

# ---------- modelos ----------
func _arma(tipo: String, acess: Array) -> Node3D:
	var n := ModelosArmas.construir(tipo)
	for nome in ["Cano", "Acc_cano", "Acc_mira"]:
		var x := n.get_node_or_null(nome)
		if x == null:
			continue
		if nome == "Cano":
			x.free()
		else:
			x.visible = acess.has(nome.substr(4))
	return n

# camisa / calça / colete: triângulos das partes do corpo que a peça cobre, na pose de repouso (braços abertos)
func _roupa(id: String) -> MeshInstance3D:
	if _corpo_arrays.is_empty():
		var c: Node3D = load("res://jogador/sobrevivente/corpo.scn").instantiate()
		var mi0: MeshInstance3D = c.find_children("*", "MeshInstance3D", true, false)[0]
		_corpo_arrays = mi0.mesh.surface_get_arrays(0)
		c.free()
	var V: PackedVector3Array = _corpo_arrays[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = _corpo_arrays[Mesh.ARRAY_NORMAL]
	var C: PackedColorArray = _corpo_arrays[Mesh.ARRAY_COLOR]
	var I: PackedInt32Array = _corpo_arrays[Mesh.ARRAY_INDEX]
	var regs: Array = []
	var cor := Color.WHITE
	var grosso := 0.004
	if Sob.CAMISAS.has(id):
		cor = Sob.CAMISAS[id][0]
		regs = [Sob.TRONCO, Sob.BRACO, Sob.PESCOCO]
		if Sob.CAMISAS[id][1]:
			regs.append(Sob.ANTEBRACO)
	elif Sob.CALCAS.has(id):
		cor = Sob.CALCAS[id]
		regs = [Sob.QUADRIL, Sob.COXA, Sob.CANELA]
	else:
		cor = Sob.COLETES[id]
		regs = [Sob.TRONCO, Sob.QUADRIL]
		grosso = 0.026
	var y_tronco := Vector2(1e9, -1e9)
	var y_perna := Vector2(1e9, -1e9)
	for i in V.size():
		var r := int(C[i].r * 15.0 + 0.5)
		if r == Sob.TRONCO:
			y_tronco = Vector2(minf(y_tronco.x, V[i].y), maxf(y_tronco.y, V[i].y))
		elif r == Sob.COXA or r == Sob.CANELA:
			y_perna = Vector2(minf(y_perna.x, V[i].y), maxf(y_perna.y, V[i].y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, I.size(), 3):
		var ok := true
		for j in 3:
			var r := int(C[I[t + j]].r * 15.0 + 0.5)
			if not regs.has(r):
				ok = false
		if not ok:
			continue
		var cy := (V[I[t]].y + V[I[t + 1]].y + V[I[t + 2]].y) / 3.0
		if Sob.COLETES.has(id) and cy < y_tronco.x + (y_tronco.y - y_tronco.x) * 0.05:
			continue
		if Sob.CAMISAS.has(id) and int(C[I[t]].r * 15.0 + 0.5) == Sob.PESCOCO and cy > y_tronco.y + 0.03:
			continue                                                        # só a gola
		for j in 3:
			var vi: int = I[t + j]
			var p: Vector3 = V[vi] + N[vi] * grosso
			var nv: Vector3 = N[vi]
			if Sob.CAMISAS.has(id):
				# mangas caídas para baixo (como a roupa estendida), dobrando aos poucos a partir do ombro
				var ax := absf(p.x)
				var f := smoothstep(0.13, 0.24, ax)
				if f > 0.0:
					var ang := deg_to_rad(52.0) * f * (-signf(p.x))
					var piv := Vector3(signf(p.x) * 0.15, 1.43, p.z)
					var rot := Basis(Vector3.BACK, ang)
					p = piv + rot * (p - piv)
					nv = rot * nv
			st.set_normal(nv)
			st.set_color(_detalhe(id, p, cor * (0.88 + 0.24 * C[vi].g), y_tronco, y_perna))
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi

# detalhes pintados na roupa (zíper, bolsos, costuras)
func _detalhe(id: String, p: Vector3, c: Color, yt: Vector2, yp: Vector2) -> Color:
	var ft := (p.y - yt.x) / maxf(yt.y - yt.x, 0.001)
	var fp := (p.y - yp.x) / maxf(yp.y - yp.x, 0.001)
	var frente := p.z > 0.02
	match id:
		"jaqueta", "capa_chuva":
			if frente and absf(p.x) < 0.008 and ft < 1.0:
				return c * 0.55                                              # zíper
			if frente and ft > 0.12 and ft < 0.32 and absf(p.x) > 0.05 and absf(p.x) < 0.13:
				return c * 0.78                                              # bolsos
		"moletom":
			if frente and ft > 0.08 and ft < 0.36 and absf(p.x) < 0.1:
				return c * 0.8                                               # bolso canguru
			if ft > 0.97:
				return c * 0.85                                              # capuz caído
		"camiseta":
			if ft > 0.95:
				return c * 0.8                                               # gola
		"calca":
			if fp > 0.45 and fp < 0.7 and absf(p.x) > 0.15:
				return c * 0.76                                              # bolsos cargo
			if fp > 0.98:
				return c * 0.6                                               # cós
		"jeans":
			if fp > 0.97:
				return c * 0.65
		"colete":
			if frente and ft > 0.25 and ft < 0.55 and absf(p.x) < 0.14:
				return c * 0.72                                              # porta-pentes
		"colete_policia":
			if frente and ft > 0.3 and ft < 0.75 and absf(p.x) < 0.15:
				return c * 1.35                                              # placa balística
	return c

# ---------- foto ----------
func _foto(nome: String, d: Dictionary, n: Node3D, vista: String) -> void:
	if n == null:
		push_warning("sem modelo: " + nome)
		return
	for c in palco.get_children():
		c.free()
	var suporte := Node3D.new()
	palco.add_child(suporte)
	suporte.add_child(n)
	var w := int(d.get("w", 1))
	var h := int(d.get("h", 1))
	# orientação do item (frente do item = +Z)
	match vista:
		"lado":                                     # cano (+Z) para a direita da tela
			suporte.rotation = Vector3(0.0, 0.0, 0.0)
		"lado_em_pe":                               # cano/lâmina (+Z) para cima
			suporte.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		"lado_em_pe_virado":                        # idem, mostrando o lado chato da lâmina
			suporte.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			suporte.rotate_y(PI * 0.5)
		"de_cima":                                  # deitado no chão, visto de cima, comprido na vertical da tela
			suporte.rotation = Vector3(0.0, PI * 0.5, 0.0)
	var dir_cam := Vector3.ZERO                     # de onde a câmera olha
	match vista:
		"lado":
			dir_cam = Vector3(-1.0, 0.18, 0.12)
		"lado_em_pe", "lado_em_pe_virado":
			dir_cam = Vector3(-1.0, 0.1, 0.0)
		"tres_quartos":
			dir_cam = Vector3(-0.7, 0.55, 1.0)
		"costas":
			dir_cam = Vector3(-0.5, 0.3, -1.0)
		"frente":
			dir_cam = Vector3(0.0, 0.08, 1.0)
		"de_cima":
			dir_cam = Vector3(0.0, 1.0, 0.02)
	await process_frame
	var caixa := _aabb(suporte)
	var centro := caixa.get_center()
	var raio := caixa.size.length() * 0.5
	cam.size = raio * 2.1
	cam.near = 0.01
	cam.far = raio * 6.0 + 10.0
	var up := Vector3.UP if absf(dir_cam.normalized().y) < 0.95 else Vector3.BACK
	cam.look_at_from_position(centro + dir_cam.normalized() * (raio * 3.0 + 1.0), centro, up)
	for i in 4:
		await process_frame
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var usado := img.get_used_rect()
	if usado.size.x < 2 or usado.size.y < 2:
		push_warning("foto vazia: " + nome)
		return
	var recorte := img.get_region(usado)
	var W := w * CEL
	var H := h * CEL
	var margem := 0.9 if maxi(w, h) > 1 else 0.84
	var esc := minf(W * margem / usado.size.x, H * margem / usado.size.y)
	var nw := maxi(1, int(usado.size.x * esc))
	var nh := maxi(1, int(usado.size.y * esc))
	recorte.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var saida := Image.create(W, H, false, Image.FORMAT_RGBA8)
	saida.fill(Color(0, 0, 0, 0))
	saida.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i((W - nw) / 2, (H - nh) / 2))
	saida.save_png(ProjectSettings.globalize_path(PASTA + nome + ".png"))
	print("ícone ", nome, " ", W, "x", H)

func _aabb(n: Node3D) -> AABB:
	var a := AABB()
	var primeiro := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		a = b if primeiro else a.merge(b)
		primeiro = false
	return a
