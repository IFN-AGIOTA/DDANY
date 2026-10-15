extends RefCounted
# FACHADAS DE NOVA YORK (peças 3D presas nos prédios; o resto da fachada é do shader PREDIO):
#   - ESCADAS DE INCÊNDIO de ferro (a marca de NY) nos prédios de tijolo/concreto de 4 a ~13 andares:
#     um patamar com grade em cada andar, em frente a 2 janelas, e a escada até o patamar de cima.
#     Começam no 1º andar (a escada de baixar fica recolhida, como na vida real).
#   - APARELHOS DE AR-CONDICIONADO enfiados em algumas janelas.
# As peças batem com a grade de janelas do shader PREDIO (mundo/materiais_cidade.gd: andar 3,3 m a partir
# de 4,6 m, colunas de 2,7 m). Sem colisão (é só enfeite, fica fora do alcance do jogador).
# Ficam em pedaços de CEL x CEL m (MultiMesh) e só aparecem perto (Opções › Distância dos detalhes).
# Mexa AQUI para: quantos prédios têm escada, quantos aparelhos, tamanhos e cores.

const Malhas := preload("res://mundo/malhas.gd")
const CEL := 400.0
const ANDAR := 3.3
const BASE := 4.6
const COLUNA := 2.7
const CHANCE_ESCADA := 0.3              # dos prédios que podem ter (tijolo/concreto, 4 a 13 andares)
const MAX_AR := 10                      # aparelhos por prédio (no máximo)
const ALCANCES := [150.0, 220.0, 300.0, 400.0]   # por Opções › Distância dos detalhes

var instancias := 0                     # (para testes)

# monta tudo e devolve os MultiMeshInstance3D (a cidade adota e controla o alcance)
func montar(cidade: Node3D, y_rua: float) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = 5150
	var escadas := {}                   # Vector2i -> [Transform3D]
	var ares := {}                      # Vector2i -> [[Transform3D, Color]]
	for info in cidade.predio_info:
		if info["ruina"] or not info.has("t"):
			continue
		var tipo: int = info["tipo"]
		if tipo == 3:
			continue                    # torres de vidro: nada disso
		var h: float = info["h"]
		var sx: float = info["sx"]
		var sz: float = info["sz"]
		var c := Vector3(info["x"], y_rua, info["z"])
		var chave := Vector2i(floori(c.x / CEL), floori(c.z / CEL))
		var andares := int(floor((h - 1.3 - BASE) / ANDAR))
		if andares < 1:
			continue
		# fachada da escada: um dos 4 lados (normal para fora e eixo ao longo da fachada)
		var lado := r.randi() % 4
		var ocupado := {}               # "lado:coluna" das janelas tapadas pela escada
		if (tipo == 0 or tipo == 1) and andares >= 3 and andares <= 12 and r.randf() < CHANCE_ESCADA:
			var f := _fachada(lado, sx, sz)
			var meia: float = f[2]
			var kmax := int(floor((meia - 3.2) / COLUNA))
			if kmax >= 1:
				var k := r.randi_range(-kmax, kmax - 1)
				var u := (k + 1) * COLUNA            # entre as janelas k e k + 1
				ocupado["%d:%d" % [lado, k]] = true
				ocupado["%d:%d" % [lado, k + 1]] = true
				if not escadas.has(chave):
					escadas[chave] = []
				for j in range(0, andares, 2):              # cada peça = 2 andares (a escada vai e volta)
					var p: Vector3 = c + f[0] * f[3] + f[1] * u + Vector3(0, BASE + j * ANDAR, 0)
					escadas[chave].append(Transform3D(Basis(f[1], Vector3.UP, f[0]), p))
		# ar-condicionado: algumas janelas de 2 fachadas
		if tipo == 2 and r.randf() < 0.5:
			continue
		var n_ar := r.randi_range(0, MAX_AR)
		for i in n_ar:
			var ld := lado if r.randf() < 0.6 else r.randi() % 4
			var f := _fachada(ld, sx, sz)
			var kmax := int(floor(f[2] / COLUNA)) - 1
			if kmax < 1:
				continue
			var k := r.randi_range(-kmax, kmax - 1)
			if ocupado.has("%d:%d" % [ld, k]):
				continue
			var j := r.randi_range(0, mini(andares - 1, 9))
			var u := (k + 0.5) * COLUNA
			var p: Vector3 = c + f[0] * f[3] + f[1] * u + Vector3(0, BASE + j * ANDAR + 0.22 * ANDAR + 0.2, 0)
			if not ares.has(chave):
				ares[chave] = []
			var cor: Color = [Color(0.82, 0.80, 0.74), Color(0.7, 0.7, 0.68), Color(0.62, 0.55, 0.45), Color(0.9, 0.9, 0.88)][r.randi() % 4]
			ares[chave].append([Transform3D(Basis(f[1], Vector3.UP, f[0]), p), cor * r.randf_range(0.8, 1.05)])
	var o := []
	var mat := Malhas.mat_cores(0.6)
	mat.metallic = 0.3
	var malha_escada := _malha_escada(mat)
	var malha_ar := _malha_ar(Malhas.mat_cores(0.7))
	for chave in escadas:
		o.append(_mmi(malha_escada, escadas[chave], [], "Escadas_%d_%d" % [chave.x, chave.y]))
	for chave in ares:
		var ts := []
		var cs := []
		for e in ares[chave]:
			ts.append(e[0])
			cs.append(e[1])
		o.append(_mmi(malha_ar, ts, cs, "ArCond_%d_%d" % [chave.x, chave.y]))
	return o

# [normal para fora, eixo ao longo da fachada, meia-largura, distância do centro]
# (eixo = cima x normal, para a base x, cima, normal não sair espelhada)
static func _fachada(lado: int, sx: float, sz: float) -> Array:
	var n: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][lado]
	var largo := sx if lado < 2 else sz
	var fundo := sz if lado < 2 else sx
	return [n, Vector3.UP.cross(n), largo * 0.5, fundo * 0.5]

func _mmi(malha: Mesh, ts: Array, cores: Array, nome: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true                    # (sem isso a cor da malha sai preta no renderizador do celular)
	mm.mesh = malha
	mm.instance_count = ts.size()
	for i in ts.size():
		mm.set_instance_transform(i, ts[i])
		mm.set_instance_color(i, cores[i] if i < cores.size() else Color.WHITE)
	instancias += ts.size()
	var mi := MultiMeshInstance3D.new()
	mi.name = nome
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 300.0
	return mi

# 2 andares de escada de incêndio (x = ao longo da fachada, z = para fora, y = para cima; parede em z = 0)
func _malha_escada(mat: Material) -> ArrayMesh:
	var c := Malhas.Construtor.new()
	c.ao = 0.15
	for andar in 2:
		_andar_escada(c, andar * ANDAR, 1.0 if andar == 0 else -1.0)
	return c.malha(mat)

# um patamar com grade + a escada até o de cima; lado = 1 sobe da esquerda p/ direita, -1 ao contrário
func _andar_escada(c, y0: float, lado: float) -> void:
	var ferro := Color(0.13, 0.12, 0.11)
	var L := 5.0
	var P := 1.25
	c.caixa(Vector3(0, y0 - 0.03, P * 0.5), Vector3(L, 0.06, P), ferro)                        # patamar (grade)
	c.caixa(Vector3(0, y0 - 0.12, P - 0.03), Vector3(L, 0.18, 0.04), ferro)                    # borda
	for y in [0.5, 0.98]:
		c.caixa(Vector3(0, y0 + y, P - 0.02), Vector3(L, 0.04, 0.04), ferro)                   # corrimão da frente
		for sx in [-1.0, 1.0]:
			c.caixa(Vector3(sx * (L * 0.5 - 0.02), y0 + y, P * 0.5), Vector3(0.04, 0.04, P), ferro)   # laterais
	for i in 11:
		var w := 0.04 if i % 5 == 0 else 0.02
		c.caixa(Vector3(-L * 0.5 + 0.02 + i * (L - 0.04) / 10.0, y0 + 0.5, P - 0.02), Vector3(w, 1.0, w), ferro)   # postes e barras
	# escada até o patamar de cima, encostada na grade
	var a := Vector3(-1.9 * lado, y0, P - 0.42)
	var b := Vector3(1.6 * lado, y0 + ANDAR, P - 0.42)
	var dir := (b - a).normalized()
	var up := Vector3(-dir.y * signf(dir.x), absf(dir.x), 0.0)
	var base := Basis(dir, up, dir.cross(up))
	var meio := (a + b) * 0.5
	var comp := a.distance_to(b)
	c.caixa(meio, Vector3(comp, 0.05, 0.62), ferro, base)                                       # degraus (rampa)
	c.caixa(meio + Vector3(0, 0.9, 0.3), Vector3(comp, 0.04, 0.04), ferro, base)                 # corrimão

func _malha_ar(mat: Material) -> ArrayMesh:
	var c := Malhas.Construtor.new()
	c.caixa(Vector3(0, 0, 0.18), Vector3(0.66, 0.42, 0.5), Color(1, 1, 1))
	c.caixa(Vector3(0, 0, 0.44), Vector3(0.56, 0.3, 0.02), Color(0.45, 0.45, 0.45))      # grade da frente
	c.caixa(Vector3(0, -0.24, 0.3), Vector3(0.6, 0.04, 0.04), Color(0.4, 0.35, 0.3))     # suporte
	return c.malha(mat)
