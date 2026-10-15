extends Node3D
# ESTANDE DE TIRO na base militar (para testar as armas os infectados também usam receber_tiro).
# Alvos em forma de silhueta a 15, 25, 40 e 60 m: vida 100 como os infectados (pistola 34 · M4 21 · cabeça x3).
# Caem ao "morrer" e levantam sozinhos depois de 3 s. Placar em cima do estande.
# Cada alvo usa o mesmo contrato que os inimigos vão usar: receber_tiro(dano, ponto, direcao, forma, atirador).

var mundo = null            # colisao_mundo.gd (para assentar os alvos no chão)
var acertos := 0
var cabecas := 0
var abates := 0
var _placar: Label3D

class Alvo extends StaticBody3D:
	const VIDA := 100.0
	const CABECA_X := 3.0
	var vida := 100.0
	var caido := 0.0          # 0 em pé · 1 deitado
	var volta := 0.0
	var _piv: Node3D
	var _mat: StandardMaterial3D
	var _flash := 0.0
	var estande: Node3D

	func montar(e: Node3D) -> void:
		estande = e
		collision_layer = 4     # camada 3 = inimigos/alvos
		collision_mask = 0
		_piv = Node3D.new()
		add_child(_piv)
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.85, 0.55, 0.2)
		_mat.roughness = 0.9
		var poste := StandardMaterial3D.new()
		poste.albedo_color = Color(0.25, 0.25, 0.27)
		_caixa(_piv, Vector3(0.5, 1.3, 0.06), Vector3(0, 0.85, 0), _mat)        # corpo
		_caixa(_piv, Vector3(0.26, 0.28, 0.06), Vector3(0, 1.66, 0), _mat)      # cabeça
		_caixa(self, Vector3(0.06, 0.2, 0.06), Vector3(0, 0.1, 0), poste)        # pé
		_caixa(self, Vector3(0.6, 0.04, 0.3), Vector3(0, 0.02, 0), poste)
		# formas de colisão: 0 = corpo · 1 = cabeça
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.5, 1.3, 0.2)
		cs.shape = bs
		cs.position = Vector3(0, 0.85, 0)
		add_child(cs)
		var ch := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.26, 0.28, 0.2)
		ch.shape = sh
		ch.position = Vector3(0, 1.66, 0)
		add_child(ch)

	func _caixa(p: Node3D, tam: Vector3, pos: Vector3, m: Material) -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = tam
		mi.mesh = bm
		mi.material_override = m
		mi.position = pos
		p.add_child(mi)

	func receber_tiro(dano: float, _ponto: Vector3, _dir: Vector3, forma: int, _atirador: Node) -> Dictionary:
		if vida <= 0.0:
			return {"cabeca": false, "morto": false}
		var cabeca := forma == 1
		vida -= dano * (CABECA_X if cabeca else 1.0)
		_flash = 1.0
		var morreu := vida <= 0.0
		if morreu:
			volta = 3.0
			for c in get_children():
				if c is CollisionShape3D:
					c.set_deferred("disabled", true)
		estande.registrar(cabeca, morreu)
		return {"cabeca": cabeca, "morto": morreu}

	func _process(dt: float) -> void:
		_flash = maxf(0.0, _flash - dt * 6.0)
		_mat.albedo_color = Color(0.85, 0.55, 0.2).lerp(Color(1, 1, 1), _flash)
		var alvo_c := 1.0 if vida <= 0.0 else 0.0
		caido += (alvo_c - caido) * minf(1.0, dt * 10.0)
		_piv.rotation.x = -caido * PI * 0.48
		if vida <= 0.0:
			volta -= dt
			if volta <= 0.0:
				vida = VIDA
				for c in get_children():
					if c is CollisionShape3D:
						c.set_deferred("disabled", false)

# centro e direção para onde os alvos "olham" (de frente para o atirador)
func montar(centro: Vector2, atirador: Vector2) -> void:
	var frente := (atirador - centro).normalized()
	var lado := Vector2(-frente.y, frente.x)
	var linhas := [[15.0, [-3.0, 0.0, 3.0]], [25.0, [-5.0, 2.0]], [40.0, [-2.0, 4.0]], [60.0, [0.0]]]
	for ln in linhas:
		var d: float = ln[0]
		for off in ln[1]:
			var p: Vector2 = atirador - frente * d + lado * float(off)
			var a := Alvo.new()
			a.name = "Alvo_%dm" % int(d)
			add_child(a)
			a.montar(self)
			var y := 0.0
			if mundo != null:
				y = mundo.altura(p.x, p.y)
			a.global_position = Vector3(p.x, y, p.y)
			a.rotation.y = atan2(frente.x, frente.y)
	_placar = Label3D.new()
	_placar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_placar.font_size = 64
	_placar.pixel_size = 0.01
	_placar.outline_size = 12
	var pp: Vector2 = atirador - frente * 30.0 - lado * 10.0    # à direita da linha de tiro, mais alto
	add_child(_placar)
	_placar.global_position = Vector3(pp.x, 7.0, pp.y)
	_atualizar_placar()

func registrar(cabeca: bool, morreu: bool) -> void:
	acertos += 1
	if cabeca:
		cabecas += 1
	if morreu:
		abates += 1
	_atualizar_placar()

func _atualizar_placar() -> void:
	if _placar != null:
		_placar.text = "ESTANDE DE TIRO\nacertos %d · cabeça %d · derrubados %d" % [acertos, cabecas, abates]
