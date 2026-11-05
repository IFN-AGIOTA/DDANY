extends Node
# 1.14 · INTERLÚDIO "TRÊS DIAS" (Livro 1, começo do Cap. 3): uma MONTAGEM, a mesma esquina em três dias:
#   DIA -4 · manhã de sol: gente rindo da "nova gripe" na frente da banca; no celular, piada do grupo da corrida.
#   DIA -3 · tarde nublada: FILA na porta do mercado; no celular, a notícia das prateleiras vazias.
#   DIA -2 · noite de chuva: a rua vazia, os primeiros carros largados e lixo, uma viatura de giroflex parada; no
#     celular, o aviso da central de aviação. A cidade "respirando de forma curta, entrecortada".
# Cada dia: um plano lento, a cartela com o dia e a hora, e a FUSÃO para o próximo (historia/cutscene.gd).
# Mexa AQUI para: a esquina (ESQUINA), quem aparece em cada dia e as mensagens.

const Atores := preload("res://historia/atores.gd")
const LuzCls := preload("res://historia/iluminacao.gd")
const CenarioCls := preload("res://historia/cenario.gd")
const RotaGps := preload("res://hud/rota_gps.gd")

const PERTO_DE := Vector2(-1700.0, 300.0)     # procura a esquina mais cheia de prédios por aqui (centro de Manhattan)

var h = null
var main = null
var gente: Array = []
var luz: Node3D = null
var lojas: Array = []
var viatura: Node3D = null

func rodar(hist) -> bool:
	h = hist
	main = h.main
	var esquina := _esquina_cheia()
	var cam := RotaGps.rota(esquina, esquina + Vector2(0, -140))
	var p0: Vector2 = cam[0] if cam.size() > 0 else esquina
	var p1: Vector2 = cam[cam.size() - 1] if cam.size() > 1 else esquina + Vector2(0, -140)
	var d := (p1 - p0).normalized()
	var esq := Vector2(d.y, -d.x)
	var y0: float = main.mundo.altura(p0.x, p0.y)
	var c := Vector3(p0.x, y0, p0.y)
	var fr := Vector3(d.x, 0, d.y)
	var la := Vector3(esq.x, 0, esq.y)
	h.teleportar(c + Vector3(0, 0.2, 0), 0.0)         # o jogador (escondido) no meio da rua: o chão e os prédios carregam
	main.jogador.visible = false
	luz = LuzCls.new()
	luz.cidade = main.cidade
	luz.mundo = main.mundo
	main.jogo.add_child(luz)
	luz.acender(cam, [c])
	# a banca e o mercado: fachadas na calçada (lado esquerdo da rua)
	# a banca e o mercado: fachadas nos prédios de verdade da beira da rua (lado esquerdo)
	var pb := Vector2(c.x, c.z) + Vector2(la.x, la.z) * 16.0 + Vector2(fr.x, fr.z) * 6.0
	var pm := Vector2(c.x, c.z) + Vector2(la.x, la.z) * 16.0 + Vector2(fr.x, fr.z) * 30.0
	var fb := CenarioCls.fachada_perto(main.cidade, pb, 90.0, h.preencher.lotes_perto(pb, 90.0))
	var fm := CenarioCls.fachada_perto(main.cidade, pm, 90.0, h.preencher.lotes_perto(pm, 90.0))
	var banca := Vector3(fb[0].x, main.mundo.altura(fb[0].x, fb[0].y), fb[0].y)
	var mercado := Vector3(fm[0].x, main.mundo.altura(fm[0].x, fm[0].y), fm[0].y)
	var nb := Vector3(fb[1].x, 0, fb[1].y)
	var nm := Vector3(fm[1].x, 0, fm[1].y)
	lojas.append(CenarioCls.fachada(main.jogo, banca + nb * 0.02, atan2(nb.x, nb.z), "BANCA · REVISTAS"))
	lojas.append(CenarioCls.fachada(main.jogo, mercado + nm * 0.02, atan2(nm.x, nm.z), "MERCADO 24H"))
	# as pessoas ficam na calçada, na frente das fachadas; a câmera fica na rua olhando para cada loja
	banca += nb * 2.5
	mercado += nm * 2.5
	var tb := Vector3(-nb.z, 0, nb.x)              # ao longo da fachada da banca
	var tm := Vector3(-nm.z, 0, nm.x)
	var olho := c - la * 8.0 + fr * 2.0 + Vector3(0, 3.0, 0)
	await h.cena.tocar([
		# DIA -4: sol, gente rindo da "nova gripe" na frente da banca
		{"de": banca + nb * 11.0 + tb * 6.0 + Vector3(0, 2.6, 0), "para": banca + nb * 9.0 + tb * 4.0 + Vector3(0, 2.0, 0), "olha": banca + Vector3(0, 1.3, 0),
			"fov": 46, "dur": 6.5, "escuro": true, "titulo": ["DIA -4", "MANHÃ"], "acao": func(): _dia4(banca, nb, tb),
			"celular": ["Grupo da corrida", "kkkk \"nova gripe\"? a mídia inventa cada uma"]},
		{"de": banca + nb * 3.6 + tb * 1.4 + Vector3(0, 1.6, 0), "para": banca + nb * 3.1 + tb * 0.6 + Vector3(0, 1.6, 0), "olha": banca + Vector3(0, 1.35, 0),
			"fov": 38, "dur": 4.5, "frase": "O mundo parecia dividido entre os que zombavam da \"nova gripe\"..."},
		# DIA -3: nublado, a fila na porta do mercado
		{"de": mercado + nm * 12.0 + tm * 9.0 + Vector3(0, 2.8, 0), "para": mercado + nm * 10.0 + tm * 7.0 + Vector3(0, 2.2, 0), "olha": mercado + tm * 3.5 + Vector3(0, 1.2, 0),
			"fov": 46, "dur": 6.5, "titulo": ["DIA -3", "TARDE"], "acao": func(): _dia3(mercado, nm, tm),
			"celular": ["Notícias", "Supermercados de Nova York registram filas e prateleiras vazias"]},
		{"de": mercado + nm * 2.8 + tm * 8.0 + Vector3(0, 1.5, 0), "para": mercado + nm * 2.6 + tm * 6.5 + Vector3(0, 1.5, 0), "olha": mercado + tm * 2.0 + Vector3(0, 1.3, 0),
			"fov": 40, "dur": 4.5, "frase": "...e os que já trancavam portas, empilhando alimentos e carregando armas."},
		# DIA -2: noite, chuva, a rua vazia e os primeiros sinais
		{"de": olho + fr * 6.0 + Vector3(0, 2.0, 0), "para": olho + fr * 10.0 + Vector3(0, 1.6, 0), "olha": c + fr * 30.0 + Vector3(0, 1.0, 0), "fov": 50, "dur": 7.0,
			"titulo": ["DIA -2", "NOITE"], "acao": func(): _dia2(c, la, fr),
			"celular": ["Central de aviação", "Atenção: operações podem ser suspensas sem aviso prévio."]},
		{"de": c + fr * 30.0 - la * 2.0 + Vector3(0, 1.2, 0), "para": c + fr * 32.0 - la * 1.5 + Vector3(0, 1.1, 0), "olha": c + fr * 45.0 + Vector3(0, 0.8, 0),
			"fov": 40, "dur": 5.0, "frase": "A cidade continuava respirando — mas de forma curta, entrecortada.", "escurece": true},
	], true)
	_limpar()
	return true

# a esquina com MAIS prédios em volta (rua de verdade, não parque): procura numa grade perto de PERTO_DE
func _esquina_cheia() -> Vector2:
	var pr: PackedFloat32Array = main.cidade.predios
	var grade := {}
	for i in range(0, pr.size(), 5):
		var c := Vector2i(floori(pr[i] / 50.0), floori(pr[i + 1] / 50.0))
		grade[c] = int(grade.get(c, 0)) + 1
	var melhor := PERTO_DE
	var mn := -1
	for gx in range(-8, 9):
		for gz in range(-8, 9):
			var q := PERTO_DE + Vector2(gx, gz) * 120.0
			var r: Array = RotaGps._rua_perto(q)
			if int(r[0]) < 0:
				continue
			var p: Vector2 = r[1]
			var c0 := Vector2i(floori(p.x / 50.0), floori(p.y / 50.0))
			var n := 0
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					n += int(grade.get(c0 + Vector2i(dx, dz), 0))
			if n > mn:
				mn = n
				melhor = p
	return melhor

func _limpar_gente() -> void:
	for a in gente:
		if is_instance_valid(a):
			a.queue_free()
	gente.clear()

func _dia4(banca: Vector3, nb: Vector3, tb: Vector3) -> void:
	if main.clima != null:
		main.clima.definir_hora(9.5)
		main.clima.forcar_tempo("limpo", true)
	_limpar_gente()
	var rotulos := ["corredor", "corredora", "corredor", "corredora", "garoto"]
	for i in rotulos.size():
		var p := banca + tb * (i * 1.1 - 2.2) + nb * ((i % 2) * 0.9)
		var a := Atores.criar(main.jogo, rotulos[i], p, 0.0)
		a.olhar_para = banca + tb * (0.6 if i % 2 == 0 else -0.6) + nb * 0.5
		a.tocar(["acenar", "sim", "parado", "acenar", "sim"][i])
		gente.append(a)
	for i in 3:
		var a2 := Atores.criar(main.jogo, "corredor" if i % 2 == 0 else "corredora", banca + nb * 3.2 + tb * (i * 6.0 - 14.0), atan2(tb.x, tb.z))
		a2.andar_ate(banca + nb * 3.2 + tb * (i * 6.0 + 18.0))
		gente.append(a2)

func _dia3(mercado: Vector3, nm: Vector3, tm: Vector3) -> void:
	if main.clima != null:
		main.clima.definir_hora(16.5)
		main.clima.forcar_tempo("nublado", true)
	_limpar_gente()
	# a fila: virada para a porta do mercado
	for i in 8:
		var p := mercado + tm * (1.2 + i * 0.95)
		var a := Atores.criar(main.jogo, ["corredor", "corredora", "garoto", "corredora"][i % 4], p, atan2(-tm.x, -tm.z))
		a.tocar("parado")
		gente.append(a)

func _dia2(c: Vector3, la: Vector3, fr: Vector3) -> void:
	if main.clima != null:
		main.clima.definir_hora(22.3)
		main.clima.forcar_tempo("chuva", true)
	_limpar_gente()
	# os primeiros carros largados e o lixo voltam a aparecer nesta rua
	h.revelar_abandono(Vector2(c.x, c.z), 220.0, ["sedan", "taxi", "lixo", "saco_lixo", "caixa_papelao", "cacamba"])
	# uma viatura parada de giroflex ligado
	viatura = Node3D.new()
	main.jogo.add_child(viatura)
	var t := Transform3D(Basis(Vector3.UP, atan2(fr.x, fr.z) + 0.4), c + fr * 38.0 - la * 3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = preload("res://mundo/abandono.gd").modelo("sedan")
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.12, 0.13, 0.16)
	mi.material_override = mat
	mi.transform = t * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO)
	viatura.add_child(mi)
	for k in 2:
		var o := OmniLight3D.new()
		o.light_color = Color(1, 0.1, 0.1) if k == 0 else Color(0.15, 0.3, 1.0)
		o.omni_range = 16.0
		o.light_energy = 3.0
		o.transform = t * Transform3D(Basis(), Vector3((k - 0.5) * 0.6, 1.9, 0))
		viatura.add_child(o)
	var tw := viatura.create_tween().set_loops()
	tw.tween_callback(func():
		var a: Node3D = viatura.get_child(1)
		var b: Node3D = viatura.get_child(2)
		a.visible = not a.visible
		b.visible = not a.visible)
	tw.tween_interval(0.18)
	# um só passando com pressa, de capuz, debaixo da chuva
	var a3 := Atores.criar(main.jogo, "corredor", c - la * 6.5 - fr * 4.0, atan2(fr.x, fr.z))
	a3.andar_ate(c - la * 6.5 + fr * 40.0, true)
	gente.append(a3)

func _limpar() -> void:
	_limpar_gente()
	h.esconder_revelados()
	main.jogador.visible = true
	for n in [luz, viatura] + lojas:
		if n != null and is_instance_valid(n):
			n.queue_free()
	if main.clima != null:
		main.clima.forcar_tempo("nublado", true)
