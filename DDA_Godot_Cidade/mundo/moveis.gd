extends RefCounted
# MÓVEIS dos interiores (tudo feito de caixas/cilindros, juntado numa malha só por prédio).
# Cada função desenha um móvel com a FRENTE para +Z local (as costas encostam na parede) e devolve:
#   col  -> caixas de colisão [centro, tamanho, giro]
#   cont -> lugares com loot {"pos", "loot" (tabela em mundo/loot_mundo.gd), "nome", "tam" (grade)}
# TAMANHOS (largura x profundidade) ficam em TAM, usados pelo arrumador de cômodos (mundo/interior.gd).
# Mexa AQUI para: aparência e tamanho dos móveis, ou para criar um móvel novo (função + linha em TAM).

const Malhas := preload("res://mundo/malhas.gd")

const TAM := {
	"sofa": Vector2(2.2, 0.95), "poltrona": Vector2(0.95, 0.9), "mesa_centro": Vector2(1.1, 0.6), "estante_tv": Vector2(1.8, 0.5),
	"tapete": Vector2(2.4, 1.6), "mesa_jantar": Vector2(2.2, 2.0), "cama": Vector2(1.6, 2.1), "guarda_roupa": Vector2(1.6, 0.62),
	"criado": Vector2(0.5, 0.45), "bancada": Vector2(2.4, 0.62), "fogao": Vector2(0.76, 0.66), "geladeira": Vector2(0.82, 0.72),
	"vaso": Vector2(0.45, 0.7), "pia": Vector2(0.6, 0.5), "banheira": Vector2(1.7, 0.78), "prateleira": Vector2(2.4, 0.6),
	"gondola": Vector2(2.4, 1.1), "balcao": Vector2(2.4, 0.75), "freezer": Vector2(2.0, 0.85), "arara": Vector2(1.6, 0.55),
	"mesa_escritorio": Vector2(1.5, 1.4), "arquivo": Vector2(0.5, 0.65), "armario_armas": Vector2(1.2, 0.55), "maca": Vector2(0.9, 2.0),
	"armario_remedios": Vector2(1.0, 0.42), "mesa_bar": Vector2(1.6, 1.6), "cadeiras_espera": Vector2(2.4, 0.65),
	"caixas": Vector2(1.3, 1.1), "entulho": Vector2(1.8, 1.8), "fogao_industrial": Vector2(1.6, 0.8), "estante_livros": Vector2(1.6, 0.4),
	"planta": Vector2(0.5, 0.5), "luminaria": Vector2(0.4, 0.4), "quadro": Vector2(0.9, 0.12), "colchao": Vector2(1.0, 2.0),
	"cadeira": Vector2(0.5, 0.5), "lixeira": Vector2(0.4, 0.4), "barricada": Vector2(1.8, 0.8), "aparador": Vector2(1.2, 0.42),
}

const TECIDOS := [Color(0.45, 0.18, 0.15), Color(0.2, 0.3, 0.45), Color(0.38, 0.36, 0.3), Color(0.25, 0.35, 0.22), Color(0.5, 0.42, 0.3), Color(0.3, 0.22, 0.32)]
const MADEIRA := Color(0.42, 0.28, 0.17)
const MADEIRA_ESC := Color(0.26, 0.17, 0.11)
const METAL := Color(0.45, 0.46, 0.48)
const BRANCO := Color(0.82, 0.8, 0.76)
const PRETO := Color(0.07, 0.07, 0.08)

# caixa no espaço do móvel
static func _b(c, p: Vector3, b: Basis, centro: Vector3, tam: Vector3, cor: Color, rot := Basis.IDENTITY) -> void:
	c.caixa(p + b * centro, tam, cor, b * rot)

static func _col(col: Array, p: Vector3, b: Basis, centro: Vector3, tam: Vector3) -> void:
	var giro := atan2(b.x.z, b.x.x) * -1.0
	col.append([p + b * centro, tam, giro])

static func _cont(cont: Array, p: Vector3, b: Basis, frente: float, loot: String, nome: String, tam: Vector2i) -> void:
	cont.append({"pos": p + b * Vector3(0, 0, frente + 0.6), "loot": loot, "nome": nome, "tam": tam})

static func desenhar(nome: String, c, p: Vector3, b: Basis, r: RandomNumberGenerator, col: Array, cont: Array, uso := "") -> void:
	if nome in ["planta", "luminaria", "quadro", "colchao", "cadeira", "lixeira", "barricada", "aparador"]:
		_decoracao(nome, c, p, b, r, col, cont)
		return
	match nome:
		"sofa":
			var t: Color = TECIDOS[r.randi() % TECIDOS.size()]
			_b(c, p, b, Vector3(0, 0.25, 0.05), Vector3(2.2, 0.4, 0.85), t)
			_b(c, p, b, Vector3(0, 0.62, -0.32), Vector3(2.2, 0.75, 0.25), t * 0.9)
			_b(c, p, b, Vector3(-1.0, 0.45, 0.05), Vector3(0.2, 0.5, 0.85), t * 0.85)
			_b(c, p, b, Vector3(1.0, 0.45, 0.05), Vector3(0.2, 0.5, 0.85), t * 0.85)
			for x in [-0.5, 0.5]:
				_b(c, p, b, Vector3(x, 0.5, 0.08), Vector3(0.95, 0.12, 0.7), t * 1.1, Basis(Vector3.UP, r.randf_range(-0.15, 0.15)))
			_col(col, p, b, Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 0.95))
		"poltrona":
			var t: Color = TECIDOS[r.randi() % TECIDOS.size()]
			_b(c, p, b, Vector3(0, 0.25, 0.05), Vector3(0.9, 0.4, 0.8), t)
			_b(c, p, b, Vector3(0, 0.62, -0.32), Vector3(0.9, 0.75, 0.22), t * 0.9)
			_b(c, p, b, Vector3(-0.37, 0.45, 0.05), Vector3(0.16, 0.45, 0.8), t * 0.85)
			_b(c, p, b, Vector3(0.37, 0.45, 0.05), Vector3(0.16, 0.45, 0.8), t * 0.85)
			_col(col, p, b, Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.9))
		"mesa_centro":
			_b(c, p, b, Vector3(0, 0.42, 0), Vector3(1.1, 0.06, 0.6), MADEIRA)
			for x in [-0.48, 0.48]:
				for z in [-0.24, 0.24]:
					_b(c, p, b, Vector3(x, 0.2, z), Vector3(0.06, 0.4, 0.06), MADEIRA_ESC)
			if r.randf() < 0.6:
				_b(c, p, b, Vector3(r.randf_range(-0.3, 0.3), 0.47, 0.05), Vector3(0.25, 0.04, 0.32), Color(0.85, 0.83, 0.78) * r.randf_range(0.6, 1.0), Basis(Vector3.UP, r.randf() * 3.0))
		"estante_tv":
			_b(c, p, b, Vector3(0, 0.28, 0), Vector3(1.8, 0.56, 0.48), MADEIRA_ESC)
			if r.randf() < 0.75:
				_b(c, p, b, Vector3(0, 0.95, -0.05), Vector3(1.2, 0.72, 0.08), PRETO)
				_b(c, p, b, Vector3(0, 0.6, -0.05), Vector3(0.3, 0.1, 0.2), PRETO)
			else:
				_b(c, p, b, Vector3(0.1, 0.06, 0.7), Vector3(1.2, 0.08, 0.72), PRETO, Basis(Vector3.UP, 0.3))   # TV caída no chão
			_col(col, p, b, Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 0.5))
			_cont(cont, p, b, 0.24, "casa_sala", "ESTANTE", Vector2i(4, 2))
		"tapete":
			var t: Color = TECIDOS[r.randi() % TECIDOS.size()] * 0.8
			_b(c, p, b, Vector3(0, 0.012, 0), Vector3(2.4, 0.02, 1.6), t)
		"mesa_jantar":
			_b(c, p, b, Vector3(0, 0.74, 0), Vector3(1.4, 0.06, 0.85), MADEIRA)
			for x in [-0.62, 0.62]:
				for z in [-0.35, 0.35]:
					_b(c, p, b, Vector3(x, 0.36, z), Vector3(0.07, 0.72, 0.07), MADEIRA_ESC)
			for q in [[Vector3(-0.35, 0, 0.7), 0.0], [Vector3(0.35, 0, 0.7), 0.0], [Vector3(-0.35, 0, -0.7), PI], [Vector3(0.35, 0, -0.7), PI]]:
				_cadeira(c, p + b * q[0], b * Basis(Vector3.UP, q[1] + r.randf_range(-0.4, 0.4)), r, MADEIRA)
			_col(col, p, b, Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 0.85))
		"cama":
			var t: Color = TECIDOS[r.randi() % TECIDOS.size()]
			_b(c, p, b, Vector3(0, 0.2, 0), Vector3(1.6, 0.3, 2.05), MADEIRA_ESC)
			_b(c, p, b, Vector3(0, 0.45, 0.02), Vector3(1.5, 0.22, 1.95), BRANCO * 0.85)
			_b(c, p, b, Vector3(0, 0.58, 0.35), Vector3(1.55, 0.08, 1.3), t, Basis(Vector3.UP, r.randf_range(-0.1, 0.1)))
			_b(c, p, b, Vector3(0, 0.62, -0.75), Vector3(1.2, 0.15, 0.35), BRANCO)
			_b(c, p, b, Vector3(0, 0.65, -1.0), Vector3(1.6, 0.9, 0.08), MADEIRA_ESC)
			_col(col, p, b, Vector3(0, 0.35, 0), Vector3(1.6, 0.7, 2.05))
			_cont(cont, p, b, 1.0, "casa_quarto", "CAMA", Vector2i(3, 2))
		"guarda_roupa":
			_b(c, p, b, Vector3(0, 1.05, 0), Vector3(1.6, 2.1, 0.6), MADEIRA)
			_b(c, p, b, Vector3(0, 1.05, 0.305), Vector3(0.02, 1.9, 0.01), MADEIRA_ESC)
			if r.randf() < 0.4:
				_b(c, p, b, Vector3(0.75, 1.05, 0.65), Vector3(0.75, 1.9, 0.03), MADEIRA, Basis(Vector3.UP, -1.1))   # porta aberta
			_col(col, p, b, Vector3(0, 1.05, 0), Vector3(1.6, 2.1, 0.6))
			_cont(cont, p, b, 0.3, "casa_quarto", "GUARDA-ROUPA", Vector2i(5, 5))
		"criado":
			_b(c, p, b, Vector3(0, 0.27, 0), Vector3(0.5, 0.54, 0.44), MADEIRA)
			_b(c, p, b, Vector3(0, 0.62, 0), Vector3(0.18, 0.16, 0.18), Color(0.7, 0.6, 0.4))
			_cont(cont, p, b, 0.22, "casa_quarto", "CRIADO-MUDO", Vector2i(2, 2))
		"bancada":
			_b(c, p, b, Vector3(0, 0.44, 0), Vector3(2.4, 0.88, 0.6), BRANCO * 0.9)
			_b(c, p, b, Vector3(0, 0.9, 0.0), Vector3(2.44, 0.04, 0.64), Color(0.3, 0.3, 0.32))
			_b(c, p, b, Vector3(0.6, 0.86, 0.05), Vector3(0.6, 0.06, 0.4), METAL)                      # pia
			_b(c, p, b, Vector3(0, 1.85, -0.12), Vector3(2.4, 0.7, 0.36), BRANCO * 0.85)               # armários de cima
			for i in r.randi_range(0, 3):
				_b(c, p, b, Vector3(r.randf_range(-1.0, 1.0), 0.98, r.randf_range(-0.1, 0.15)), Vector3(0.12, 0.14, 0.12), Color(r.randf(), r.randf(), r.randf()) * 0.7)
			_col(col, p, b, Vector3(0, 0.46, 0), Vector3(2.4, 0.92, 0.62))
			_cont(cont, p, b, 0.3, "casa_cozinha", "ARMÁRIO DA COZINHA", Vector2i(5, 3))
		"fogao":
			_b(c, p, b, Vector3(0, 0.45, 0), Vector3(0.76, 0.9, 0.64), BRANCO * 0.9)
			_b(c, p, b, Vector3(0, 0.91, 0), Vector3(0.74, 0.02, 0.6), PRETO)
			for x in [-0.18, 0.18]:
				for z in [-0.14, 0.14]:
					c.cilindro(p + b * Vector3(x, 0.93, z), 0.09, 0.02, 8, Color(0.15, 0.15, 0.15), b)
			_col(col, p, b, Vector3(0, 0.45, 0), Vector3(0.76, 0.9, 0.64))
		"fogao_industrial":
			_b(c, p, b, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.8), METAL * 0.8)
			_b(c, p, b, Vector3(0, 0.92, 0), Vector3(1.6, 0.04, 0.8), PRETO)
			_b(c, p, b, Vector3(0, 1.9, -0.2), Vector3(1.8, 0.5, 0.8), METAL)                         # coifa
			_col(col, p, b, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.8))
		"geladeira":
			_b(c, p, b, Vector3(0, 0.9, 0), Vector3(0.8, 1.8, 0.7), BRANCO)
			_b(c, p, b, Vector3(-0.3, 1.15, 0.36), Vector3(0.04, 0.5, 0.04), METAL)
			if r.randf() < 0.3:
				_b(c, p, b, Vector3(0.2, 0.9, 0.75), Vector3(0.78, 1.75, 0.05), BRANCO * 0.95, Basis(Vector3.UP, -1.2))   # aberta
			_col(col, p, b, Vector3(0, 0.9, 0), Vector3(0.8, 1.8, 0.7))
			_cont(cont, p, b, 0.35, "geladeira", "GELADEIRA", Vector2i(4, 4))
		"vaso":
			_b(c, p, b, Vector3(0, 0.2, 0.05), Vector3(0.38, 0.4, 0.5), BRANCO)
			_b(c, p, b, Vector3(0, 0.55, -0.25), Vector3(0.42, 0.4, 0.18), BRANCO)
		"pia":
			_b(c, p, b, Vector3(0, 0.82, 0), Vector3(0.6, 0.16, 0.48), BRANCO)
			_b(c, p, b, Vector3(0, 0.4, -0.05), Vector3(0.2, 0.75, 0.2), BRANCO * 0.9)
			_b(c, p, b, Vector3(0, 1.45, -0.22), Vector3(0.55, 0.7, 0.04), Color(0.55, 0.6, 0.62))      # espelho
			_cont(cont, p, b, 0.24, "banheiro", "ARMÁRIO DO BANHEIRO", Vector2i(3, 2))
		"banheira":
			_b(c, p, b, Vector3(0, 0.28, 0), Vector3(1.7, 0.56, 0.76), BRANCO)
			_b(c, p, b, Vector3(0, 0.5, 0), Vector3(1.5, 0.1, 0.56), Color(0.4, 0.38, 0.33))
			_col(col, p, b, Vector3(0, 0.3, 0), Vector3(1.7, 0.6, 0.76))
		"prateleira", "gondola":
			var dupla: bool = nome == "gondola"
			var prof := 1.1 if dupla else 0.6
			_b(c, p, b, Vector3(0, 0.9, 0), Vector3(2.4, 1.8, 0.06 if dupla else 0.04), METAL * 0.75)
			for i in 4:
				var y := 0.15 + i * 0.5
				_b(c, p, b, Vector3(0, y, 0), Vector3(2.4, 0.04, prof), METAL)
				for lado in ([-1.0, 1.0] if dupla else [1.0]):
					var x := -1.05
					while x < 1.05:
						if r.randf() < 0.55:          # prateleiras meio vazias (saqueadas)
							var w := r.randf_range(0.12, 0.3)
							var h := r.randf_range(0.12, 0.35)
							var cor := Color(r.randf(), r.randf(), r.randf()).lerp(Color(0.7, 0.65, 0.55), 0.5) * r.randf_range(0.6, 1.0)
							if uso == "farmacia" or uso == "clinica":
								cor = Color(0.9, 0.9, 0.88).lerp(Color(r.randf(), 0.3, 0.3), 0.3)
							_b(c, p, b, Vector3(x, y + h * 0.5 + 0.02, lado * prof * 0.25), Vector3(w * 0.9, h, prof * 0.4), cor)
						x += r.randf_range(0.15, 0.35)
			if r.randf() < 0.25:            # coisas caídas no chão
				for i in r.randi_range(2, 5):
					_b(c, p, b, Vector3(r.randf_range(-1.2, 1.2), 0.06, prof * 0.5 + r.randf_range(0.2, 0.9)), Vector3(0.2, 0.12, 0.15), Color(r.randf(), r.randf(), r.randf()) * 0.6, Basis(Vector3.UP, r.randf() * 3.0))
			_col(col, p, b, Vector3(0, 0.9, 0), Vector3(2.4, 1.8, prof))
			var loot: String = {"mercado": "mercado", "farmacia": "farmacia", "clinica": "farmacia", "loja": "loja", "delegacia": "escritorio"}.get(uso, "casa_sala")
			_cont(cont, p, b, prof * 0.5, loot, "PRATELEIRA", Vector2i(6, 3))
		"balcao":
			_b(c, p, b, Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 0.7), MADEIRA_ESC)
			_b(c, p, b, Vector3(0, 1.02, 0), Vector3(2.5, 0.05, 0.8), Color(0.3, 0.3, 0.3))
			_b(c, p, b, Vector3(0.6, 1.17, 0), Vector3(0.45, 0.25, 0.4), PRETO)                     # caixa registradora
			_col(col, p, b, Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 0.75))
			_cont(cont, p, b, 0.38, "balcao", "BALCÃO", Vector2i(4, 2))
		"freezer":
			_b(c, p, b, Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 0.85), BRANCO)
			_b(c, p, b, Vector3(0, 0.92, 0), Vector3(1.9, 0.04, 0.75), Color(0.35, 0.45, 0.5))
			_col(col, p, b, Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 0.85))
			_cont(cont, p, b, 0.42, "geladeira", "FREEZER", Vector2i(5, 3))
		"arara":
			_b(c, p, b, Vector3(0, 1.5, 0), Vector3(1.6, 0.04, 0.04), METAL)
			for x in [-0.78, 0.78]:
				_b(c, p, b, Vector3(x, 0.75, 0), Vector3(0.04, 1.5, 0.04), METAL)
				_b(c, p, b, Vector3(x, 0.02, 0), Vector3(0.05, 0.04, 0.5), METAL)
			var x2 := -0.7
			while x2 < 0.7:
				if r.randf() < 0.65:
					_b(c, p, b, Vector3(x2, 1.1, 0), Vector3(0.06, 0.75, 0.45), TECIDOS[r.randi() % TECIDOS.size()] * r.randf_range(0.8, 1.3))
				x2 += 0.12
			_col(col, p, b, Vector3(0, 0.8, 0), Vector3(1.6, 1.6, 0.5))
			_cont(cont, p, b, 0.25, "loja_roupas", "ARARA DE ROUPAS", Vector2i(5, 4))
		"mesa_escritorio":
			_b(c, p, b, Vector3(0, 0.74, -0.3), Vector3(1.5, 0.05, 0.75), Color(0.55, 0.5, 0.42))
			_b(c, p, b, Vector3(-0.55, 0.36, -0.3), Vector3(0.4, 0.72, 0.7), Color(0.4, 0.4, 0.42))
			_b(c, p, b, Vector3(0.72, 0.36, -0.3), Vector3(0.04, 0.72, 0.7), Color(0.4, 0.4, 0.42))
			if r.randf() < 0.8:
				_b(c, p, b, Vector3(0.1, 1.0, -0.5), Vector3(0.55, 0.38, 0.05), PRETO, Basis(Vector3.RIGHT, -0.1) if r.randf() < 0.8 else Basis(Vector3.RIGHT, -1.4))
				_b(c, p, b, Vector3(0.1, 0.78, -0.25), Vector3(0.45, 0.02, 0.15), PRETO)
			for i in r.randi_range(0, 4):
				_b(c, p, b, Vector3(r.randf_range(-0.6, 0.6), 0.775, r.randf_range(-0.6, 0.0)), Vector3(0.21, 0.01, 0.3), BRANCO, Basis(Vector3.UP, r.randf() * 3.0))
			_cadeira(c, p + b * Vector3(0.1, 0, 0.35), b * Basis(Vector3.UP, PI + r.randf_range(-0.8, 0.8)), r, PRETO, true)
			_col(col, p, b, Vector3(0, 0.38, -0.3), Vector3(1.5, 0.76, 0.75))
			_cont(cont, p, b, -0.1, "escritorio", "GAVETAS", Vector2i(3, 2))
		"arquivo":
			_b(c, p, b, Vector3(0, 0.65, 0), Vector3(0.5, 1.3, 0.62), Color(0.4, 0.42, 0.4))
			for i in 4:
				_b(c, p, b, Vector3(0, 0.18 + i * 0.32, 0.315), Vector3(0.35, 0.03, 0.01), METAL)
			_col(col, p, b, Vector3(0, 0.65, 0), Vector3(0.5, 1.3, 0.62))
			_cont(cont, p, b, 0.31, "escritorio", "ARQUIVO", Vector2i(2, 4))
		"armario_armas":
			_b(c, p, b, Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.5), Color(0.25, 0.3, 0.27))
			_b(c, p, b, Vector3(0, 1.0, 0.26), Vector3(1.1, 1.85, 0.02), Color(0.2, 0.24, 0.22))
			_col(col, p, b, Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.5))
			_cont(cont, p, b, 0.25, "armas_policia", "ARMÁRIO DE ARMAS", Vector2i(6, 5))
		"maca":
			_b(c, p, b, Vector3(0, 0.62, 0), Vector3(0.85, 0.12, 1.95), BRANCO)
			_b(c, p, b, Vector3(0, 0.7, 0.1), Vector3(0.8, 0.06, 1.7), Color(0.55, 0.65, 0.68))
			for x in [-0.38, 0.38]:
				for z in [-0.85, 0.85]:
					_b(c, p, b, Vector3(x, 0.3, z), Vector3(0.04, 0.6, 0.04), METAL)
			_col(col, p, b, Vector3(0, 0.4, 0), Vector3(0.85, 0.8, 1.95))
		"armario_remedios":
			_b(c, p, b, Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 0.4), BRANCO)
			_b(c, p, b, Vector3(0, 1.2, 0.205), Vector3(0.9, 1.0, 0.01), Color(0.5, 0.6, 0.62))
			c.caixa(p + b * Vector3(0, 1.65, 0.21), Vector3(0.12, 0.3, 0.01), Color(0.7, 0.1, 0.1), b)
			c.caixa(p + b * Vector3(0, 1.65, 0.21), Vector3(0.3, 0.12, 0.01), Color(0.7, 0.1, 0.1), b)
			_col(col, p, b, Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 0.4))
			_cont(cont, p, b, 0.2, "farmacia", "ARMÁRIO DE REMÉDIOS", Vector2i(4, 4))
		"mesa_bar":
			c.cilindro(p + b * Vector3(0, 0.74, 0), 0.45, 0.05, 10, MADEIRA, b)
			c.cilindro(p + b * Vector3(0, 0.37, 0), 0.05, 0.72, 6, METAL, b)
			for i in r.randi_range(2, 4):
				var a := TAU * i / 4.0 + r.randf_range(-0.3, 0.3)
				var bb := b * Basis(Vector3.UP, -a + PI * 0.5)
				if r.randf() < 0.2:
					bb = bb * Basis(Vector3.RIGHT, PI * 0.5)      # cadeira caída
				_cadeira(c, p + b * Vector3(cos(a) * 0.72, 0, sin(a) * 0.72), bb, r, MADEIRA_ESC)
			_col(col, p, b, Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 0.9))
		"cadeiras_espera":
			for i in 4:
				_cadeira(c, p + b * Vector3(-0.9 + i * 0.6, 0, 0), b, r, Color(0.2, 0.3, 0.45), true)
		"caixas":
			for i in r.randi_range(2, 5):
				var s := Vector3(r.randf_range(0.4, 0.7), r.randf_range(0.3, 0.55), r.randf_range(0.35, 0.6))
				_b(c, p, b, Vector3(r.randf_range(-0.35, 0.35), s.y * 0.5 + (0.0 if i < 3 else 0.5), r.randf_range(-0.3, 0.3)), s, Color(0.55, 0.42, 0.28) * r.randf_range(0.8, 1.1), Basis(Vector3.UP, r.randf_range(-0.4, 0.4)))
			_col(col, p, b, Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.0))
			_cont(cont, p, b, 0.4, "deposito", "CAIXAS", Vector2i(4, 3))
		"entulho":
			for i in 9:
				var s := Vector3(r.randf_range(0.2, 0.7), r.randf_range(0.1, 0.4), r.randf_range(0.2, 0.6))
				var g := r.randf_range(0.4, 0.6)
				_b(c, p, b, Vector3(r.randf_range(-0.8, 0.8), s.y * 0.4, r.randf_range(-0.8, 0.8)), s, Color(g, g * 0.97, g * 0.93), Basis.from_euler(Vector3(r.randf_range(-0.5, 0.5), r.randf() * 3.0, r.randf_range(-0.5, 0.5))))
			_b(c, p, b, Vector3(0.2, 0.25, 0.1), Vector3(1.8, 0.08, 0.15), MADEIRA_ESC, Basis(Vector3.FORWARD, 0.25))
		"estante_livros":
			_b(c, p, b, Vector3(0, 0.95, 0), Vector3(1.6, 1.9, 0.38), MADEIRA_ESC)
			for i in 4:
				var x := -0.7
				while x < 0.7:
					if r.randf() < 0.7:
						_b(c, p, b, Vector3(x, 0.25 + i * 0.45, 0.04), Vector3(0.05, r.randf_range(0.22, 0.32), 0.25), TECIDOS[r.randi() % TECIDOS.size()])
					x += 0.06
			_col(col, p, b, Vector3(0, 0.95, 0), Vector3(1.6, 1.9, 0.38))

# decoração e sinais de sobreviventes (sem loot, exceto o colchão do acampamento)
static func _decoracao(nome: String, c, p: Vector3, b: Basis, r: RandomNumberGenerator, col: Array, cont: Array) -> void:
	match nome:
		"planta":
			c.cilindro(p + b * Vector3(0, 0.2, 0), 0.2, 0.4, 8, Color(0.55, 0.3, 0.2), b, 0.24)
			var seca := r.randf() < 0.7          # abandonada: quase todas secas
			var folha := Color(0.4, 0.35, 0.18) if seca else Color(0.2, 0.4, 0.15)
			for i in 6:
				var a := TAU * i / 6.0
				c.caixa(p + b * Vector3(cos(a) * 0.12, 0.6 + r.randf() * 0.2, sin(a) * 0.12), Vector3(0.06, 0.45, 0.2), folha, b * Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.5 if seca else 0.25))
		"luminaria":
			var caida := r.randf() < 0.35
			var bb := b * Basis(Vector3.RIGHT, PI * 0.5) if caida else b
			var base := p + (b * Vector3(0, 0.1, 0) if caida else Vector3.ZERO)
			c.cilindro(base + bb * Vector3(0, 0.02, 0), 0.16, 0.04, 8, PRETO, bb)
			c.cilindro(base + bb * Vector3(0, 0.8, 0), 0.015, 1.55, 5, METAL, bb)
			c.cilindro(base + bb * Vector3(0, 1.62, 0), 0.22, 0.3, 8, Color(0.85, 0.78, 0.6), bb, 0.12)
		"quadro":
			var cor := Color(r.randf_range(0.2, 0.7), r.randf_range(0.2, 0.6), r.randf_range(0.2, 0.6))
			var torto := Basis(Vector3.FORWARD, r.randf_range(-0.12, 0.12))
			_b(c, p, b, Vector3(0, 1.6, -0.02), Vector3(0.9, 0.65, 0.04), MADEIRA_ESC, torto)
			_b(c, p, b, Vector3(0, 1.6, 0.005), Vector3(0.78, 0.53, 0.02), cor, torto)
		"colchao":
			var t: Color = TECIDOS[r.randi() % TECIDOS.size()] * 0.7
			_b(c, p, b, Vector3(0, 0.1, 0), Vector3(0.95, 0.18, 1.9), BRANCO * 0.6, Basis(Vector3.UP, r.randf_range(-0.1, 0.1)))
			_b(c, p, b, Vector3(0.05, 0.21, 0.2), Vector3(0.85, 0.06, 1.2), t, Basis(Vector3.UP, r.randf_range(-0.2, 0.2)))
			for i in r.randi_range(2, 5):             # latas vazias e garrafas do acampamento
				var q := Vector3(r.randf_range(-0.8, 0.8), 0.06, r.randf_range(-1.2, 1.2))
				c.cilindro(p + b * q, 0.04, 0.12, 6, METAL if r.randf() < 0.6 else Color(0.3, 0.5, 0.3), b * Basis(Vector3.RIGHT, PI * 0.5 if r.randf() < 0.5 else 0.0))
			_cont(cont, p, b, 0.5, "casa_quarto", "ACAMPAMENTO", Vector2i(4, 3))
		"cadeira":
			var bb := b * Basis(Vector3.UP, r.randf_range(-0.6, 0.6))
			if r.randf() < 0.4:
				bb = bb * Basis(Vector3.RIGHT, PI * 0.5)
				p += Vector3(0, 0.22, 0)
			_cadeira(c, p, bb, r, MADEIRA if r.randf() < 0.5 else METAL * 0.6)
		"lixeira":
			var caida := r.randf() < 0.4
			var bb := b * Basis(Vector3.RIGHT, PI * 0.5) if caida else b
			c.cilindro(p + (b * Vector3(0, 0.2, 0) if caida else b * Vector3(0, 0.3, 0)), 0.18, 0.6, 8, METAL * 0.7, bb)
			for i in 4:
				_b(c, p, b, Vector3(r.randf_range(-0.6, 0.6), 0.03, r.randf_range(-0.2, 0.8)), Vector3(0.15, 0.06, 0.12), Color(r.randf(), r.randf(), r.randf()) * 0.5, Basis(Vector3.UP, r.randf() * 3.0))
		"barricada":
			# móveis empilhados contra a parede/janela (alguém tentou se proteger)
			_b(c, p, b, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.6), MADEIRA, Basis(Vector3.UP, r.randf_range(-0.1, 0.1)))
			_b(c, p, b, Vector3(0.1, 1.1, -0.05), Vector3(1.2, 0.5, 0.5), MADEIRA_ESC, Basis(Vector3.FORWARD, r.randf_range(-0.2, 0.2)))
			_b(c, p, b, Vector3(-0.3, 1.5, 0), Vector3(0.6, 0.4, 0.4), TECIDOS[r.randi() % TECIDOS.size()], Basis(Vector3.UP, 0.5))
			for i in 3:
				_b(c, p, b, Vector3(r.randf_range(-0.8, 0.8), 0.9 + i * 0.35, 0.32), Vector3(0.12, 0.9, 0.04), MADEIRA * 0.8, Basis(Vector3.FORWARD, r.randf_range(-0.8, 0.8)))
			_col(col, p, b, Vector3(0, 0.8, 0), Vector3(1.8, 1.6, 0.8))
		"aparador":
			_b(c, p, b, Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.4), MADEIRA_ESC)
			for i in r.randi_range(1, 3):
				_b(c, p, b, Vector3(r.randf_range(-0.45, 0.45), 0.88, 0), Vector3(0.12, 0.16, 0.12), Color(r.randf(), r.randf(), r.randf()) * 0.6)
			_col(col, p, b, Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.4))
			_cont(cont, p, b, 0.2, "casa_sala", "APARADOR", Vector2i(3, 2))

static func _cadeira(c, p: Vector3, b: Basis, r: RandomNumberGenerator, cor: Color, estofada := false) -> void:
	c.caixa(p + b * Vector3(0, 0.46, 0), Vector3(0.44, 0.05, 0.44), cor, b)
	c.caixa(p + b * Vector3(0, 0.75, -0.2), Vector3(0.44, 0.55 if estofada else 0.45, 0.05), cor, b)
	for x in [-0.19, 0.19]:
		for z in [-0.19, 0.19]:
			c.caixa(p + b * Vector3(x, 0.22, z), Vector3(0.04, 0.44, 0.04), cor * 0.7, b)
