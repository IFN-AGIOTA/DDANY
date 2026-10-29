extends RefCounted
# PRÉ-AQUECER (1.00 · estudos/ESTUDO_AAA.md 1.6 "compilação de shaders"): no celular, cada material novo compila o
# shader na 1ª vez que aparece na tela, e esse quadro trava (o "engasgo do primeiro tiro"). Aqui, ainda DEBAIXO da
# tela de carregamento (main.gd _fim_carregamento), mostramos na frente da câmera, UMA PEÇA POR VEZ (cada uma num
# quadro: a barra e as dicas continuam andando), tudo o que só aparece mais tarde: traçante, faísca, poeira, clarão
# do cano e a luz dele, marca de bala, sangue, o arco e o anel do arremesso, um caco de vidro, a chuva, o céu da
# noite, a lente da luneta e o fundo da pausa. Cada peça volta ao que era logo depois. Sem som.
# progresso(fração) avisa a tela de carregamento.
# Mexa AQUI para: o que mais aquecer (algo novo que engasga na 1ª vez).

const VistaLuneta := preload("res://armas/vista_luneta.gd")
const Pausa := preload("res://menu/pausa.gd")
const QUADROS := 2                     # quadros que cada peça fica na tela

static func rodar(main: Node, progresso := Callable()) -> void:
	var j = main.get("jogador")
	if j == null or not is_instance_valid(j) or j.get("camera") == null:
		return
	var arvore: SceneTree = main.get_tree()
	var cam: Camera3D = j.camera
	var p := cam.global_position - cam.global_basis.z * 4.0
	# cada peça: [liga (Callable), desliga (Callable)]
	var pecas: Array = []
	var ef = j.armas.get("efeitos") if j.get("armas") != null else null
	if ef != null and ef.has_method("pecas_aquecer"):
		for n in ef.pecas_aquecer():
			pecas.append([func(): ef.aquecer(n, p, true), func(): ef.aquecer(n, p, false)])
	var arr = j.get("arremesso")
	if arr != null:
		pecas.append([func():
			arr._malha.clear_surfaces()
			arr._malha.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			arr._malha.surface_add_vertex(p)
			arr._malha.surface_add_vertex(p + Vector3(0.5, 0.3, 0))
			arr._malha.surface_end()
			arr._alvo.global_position = p
			arr._arco.visible = true
			arr._alvo.visible = true,
		func():
			arr._arco.visible = false
			arr._alvo.visible = false])
		pecas.append([func(): arr._cacos(p, Vector3.UP),
			func():
				for c in arr.get_children():
					if c != arr._arco and c != arr._alvo:
						c.queue_free()])
	var cl = main.get("clima")
	if cl != null:
		for nome in ["_malha_chuva", "_ceu_noite"]:
			var n = cl.get(nome)
			if n != null and is_instance_valid(n) and n is Node3D:
				var antes: bool = (n as Node3D).visible
				# (o clima pode escondê-los a cada quadro: liga logo antes de desenhar)
				var mostra := func():
					if is_instance_valid(n):
						n.visible = true
				pecas.append([func(): RenderingServer.frame_pre_draw.connect(mostra, CONNECT_ONE_SHOT),
					func():
						if is_instance_valid(n):
							n.visible = antes])
	# telas: a lente da luneta e o fundo da pausa (um quadradinho, por baixo da tela de carregamento)
	var camada := CanvasLayer.new()
	camada.layer = 59
	main.add_child(camada)
	for sh in [VistaLuneta.shader(), Pausa.shader_veu(), Pausa.shader_xadrez()]:
		var r := ColorRect.new()
		r.size = Vector2(8, 8)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		var mat := ShaderMaterial.new()
		mat.shader = sh
		r.material = mat
		camada.add_child(r)
		pecas.append([func(): r.visible = true, func(): r.visible = false])
	for k in pecas.size():
		pecas[k][0].call()
		for i in QUADROS:
			await arvore.process_frame
		pecas[k][1].call()
		if progresso.is_valid():
			progresso.call(float(k + 1) / pecas.size())
	camada.queue_free()
