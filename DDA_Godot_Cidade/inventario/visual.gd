extends RefCounted
# DESENHO DOS ÍCONES (sem imagens: tudo desenhado por código, como o resto da HUD).
# Para usar imagens próprias: ponha res://inventario/icones/<id>.png e elas substituem o desenho.

const Itens := preload("res://inventario/itens.gd")

const FUNDO_CELULA := Color(0.10, 0.11, 0.12, 0.85)
const LINHA_CELULA := Color(1, 1, 1, 0.07)
const TEXTO := Color(0.92, 0.92, 0.90)

static var _cache_icones := {}

static func _imagem(id: String) -> Texture2D:
	if not _cache_icones.has(id):
		var c := "res://inventario/icones/" + id + ".png"
		_cache_icones[id] = load(c) if ResourceLoader.exists(c) else null
	return _cache_icones[id]

static func texto(ci: CanvasItem, f: Font, t: String, pos: Vector2, tam: int, cor: Color, sombra := true) -> void:
	if sombra:
		ci.draw_string(f, pos + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.8 * cor.a))
	ci.draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)

# desenha o item dentro do retângulo r (r já está do tamanho do item, girado ou não)
static func desenhar_item(ci: CanvasItem, it, r: Rect2, f: Font, girado: bool, alfa := 1.0) -> void:
	var c := Itens.cor(it.id)
	var caixa := r.grow(-2.0)
	ci.draw_rect(caixa, Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, 0.94 * alfa))
	ci.draw_rect(caixa, Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, 0.9 * alfa), false, 1.5)
	var img := _imagem(it.id)
	var margem := minf(caixa.size.x, caixa.size.y) * 0.14
	var area := caixa.grow(-margem)
	if img != null:
		ci.draw_texture_rect(img, area, false, Color(1, 1, 1, alfa))
	elif girado:
		# ícone desenhado deitado e girado 90° para caber no retângulo em pé
		var centro := area.get_center()
		ci.draw_set_transform(centro, PI * 0.5, Vector2.ONE)
		_icone(ci, it, Rect2(-area.size.y * 0.5, -area.size.x * 0.5, area.size.y, area.size.x), alfa)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_icone(ci, it, area, alfa)
	var tam := int(clampf(minf(caixa.size.x / 6.0, caixa.size.y / 3.2), 9.0, 14.0))
	var sigla: String = it.def().get("sigla", "")
	if caixa.size.x >= 40.0 and sigla != "":
		texto(ci, f, sigla, caixa.position + Vector2(3, tam + 1), tam, Color(TEXTO.r, TEXTO.g, TEXTO.b, 0.85 * alfa))
	var rot: String = it.rotulo()
	if rot != "":
		var t2 := tam + 2
		var w := f.get_string_size(rot, HORIZONTAL_ALIGNMENT_LEFT, -1, t2).x
		texto(ci, f, rot, caixa.end - Vector2(w + 3, 4), t2, Color(1, 1, 1, alfa))
	if it.estado < 0.7:
		# estado (DayZ): bolinha colorida no canto (amarelo = gasto ... vermelho = muito danificado)
		var raio := clampf(minf(caixa.size.x, caixa.size.y) * 0.09, 2.5, 5.0)
		ci.draw_circle(caixa.position + Vector2(caixa.size.x - raio - 3, raio + 3), raio, Color(Itens.cor_estado(it.estado), alfa))
	if it.conteudo != null:
		var g = it.conteudo
		var frac := float(g.celulas_usadas()) / float(maxi(1, g.largura * g.altura))
		ci.draw_rect(Rect2(caixa.position.x + 3, caixa.end.y - 5, (caixa.size.x - 6) * frac, 3), Color(0.9, 0.75, 0.3, alfa))

static func _p(a: Rect2, x: float, y: float) -> Vector2:
	return a.position + Vector2(x * a.size.x, y * a.size.y)

static func _r(ci: CanvasItem, a: Rect2, x0: float, y0: float, x1: float, y1: float, cor: Color) -> void:
	ci.draw_rect(Rect2(_p(a, x0, y0), _p(a, x1, y1) - _p(a, x0, y0)), cor)

static func _poli(ci: CanvasItem, a: Rect2, pts: Array, cor: Color) -> void:
	var pv := PackedVector2Array()
	for q in pts:
		pv.append(_p(a, q[0], q[1]))
	ci.draw_colored_polygon(pv, cor)

# ícones simples por tipo/categoria (coordenadas de 0 a 1 dentro da área)
static func _icone(ci: CanvasItem, it, a: Rect2, alfa: float) -> void:
	var d: Dictionary = it.def()
	var escuro := Color(0.08, 0.08, 0.09, alfa)
	var claro := Color(0.85, 0.85, 0.82, alfa)
	var cor := Itens.cor(it.id).lightened(0.35)
	cor.a = alfa
	match d.get("arma", ""):
		"pistola":
			_r(ci, a, 0.05, 0.2, 0.95, 0.45, escuro)
			_poli(ci, a, [[0.55, 0.45], [0.85, 0.45], [0.78, 0.95], [0.5, 0.95]], escuro)
			_r(ci, a, 0.4, 0.45, 0.55, 0.6, escuro)
			if it.acessorios.has("cano"):
				_r(ci, a, 0.0, 0.24, 0.12, 0.41, Color(0.2, 0.2, 0.22, alfa))
			return
		"m4", "ak":
			var ak: bool = d["arma"] == "ak"
			var mad := Color(0.42, 0.26, 0.14, alfa) if ak else escuro
			_poli(ci, a, [[0.0, 0.35], [0.2, 0.4], [0.2, 0.6], [0.0, 0.7]], mad)
			_r(ci, a, 0.2, 0.35, 0.58, 0.58, escuro)
			_r(ci, a, 0.58, 0.38, 0.82, 0.56, mad)
			_r(ci, a, 0.82, 0.44, 1.0, 0.5, escuro)
			if not ak:
				_r(ci, a, 0.3, 0.22, 0.46, 0.35, escuro)
			if it.pente_id != "":
				if ak:
					_poli(ci, a, [[0.4, 0.58], [0.5, 0.58], [0.6, 0.9], [0.5, 0.95]], escuro)
				else:
					_poli(ci, a, [[0.4, 0.58], [0.5, 0.58], [0.54, 0.92], [0.44, 0.92]], escuro)
			_poli(ci, a, [[0.24, 0.58], [0.31, 0.58], [0.29, 0.85], [0.22, 0.85]], escuro)
			if it.acessorios.has("mira"):
				_r(ci, a, 0.3, 0.12, 0.5, 0.3, Color(0.15, 0.15, 0.17, alfa))
			if it.acessorios.has("cano"):
				_r(ci, a, 0.86, 0.4, 1.0, 0.54, Color(0.2, 0.2, 0.22, alfa))
			return
		"espingarda", "rifle_caca":
			var mad := Color(0.45, 0.28, 0.15, alfa)
			_poli(ci, a, [[0.0, 0.4], [0.28, 0.42], [0.3, 0.62], [0.0, 0.78]], mad)
			_r(ci, a, 0.28, 0.4, 0.5, 0.58, escuro)
			_r(ci, a, 0.5, 0.42, 1.0, 0.5, escuro)
			if d["arma"] == "espingarda":
				_r(ci, a, 0.55, 0.5, 0.8, 0.6, mad)
			else:
				_r(ci, a, 0.5, 0.5, 0.75, 0.57, mad)
				_r(ci, a, 0.36, 0.3, 0.42, 0.4, escuro)
			if it.acessorios.has("mira"):
				_r(ci, a, 0.3, 0.2, 0.6, 0.34, Color(0.15, 0.15, 0.17, alfa))
			return
	if d.get("cat", "") == "branca":
		var metal := Color(0.7, 0.72, 0.75, alfa)
		var cabo := Color(0.35, 0.22, 0.12, alfa)
		match it.id:
			"faca":
				_r(ci, a, 0.42, 0.62, 0.58, 0.98, escuro)
				_poli(ci, a, [[0.4, 0.62], [0.6, 0.62], [0.58, 0.15], [0.5, 0.0]], metal)
			"machado":
				_r(ci, a, 0.45, 0.05, 0.55, 1.0, cabo)
				_poli(ci, a, [[0.5, 0.05], [0.95, 0.0], [0.95, 0.35], [0.5, 0.25]], metal)
			"lanca":
				_r(ci, a, 0.46, 0.15, 0.54, 1.0, cabo)
				_poli(ci, a, [[0.44, 0.17], [0.56, 0.17], [0.5, 0.0]], metal)
			"taco":
				_poli(ci, a, [[0.44, 1.0], [0.56, 1.0], [0.7, 0.0], [0.3, 0.0]], cabo)
			_:
				_r(ci, a, 0.4, 0.0, 0.6, 1.0, metal.darkened(0.3) if it.id == "cano" else Color(0.55, 0.12, 0.1, alfa))
		return
	match d.get("cat", ""):
		"pente":
			_poli(ci, a, [[0.25, 0.05], [0.75, 0.05], [0.8, 0.95], [0.3, 0.95]], escuro)
			var f := float(it.municao) / float(maxi(1, it.capacidade()))
			_r(ci, a, 0.33, 0.1, 0.67, 0.1 + 0.8 * f, Color(0.85, 0.68, 0.25, 0.8 * alfa))
		"acessorio":
			_r(ci, a, 0.05, 0.3, 0.95, 0.7, escuro)
			_r(ci, a, 0.05, 0.25, 0.2, 0.75, escuro)
			_r(ci, a, 0.8, 0.25, 0.95, 0.75, escuro)
		"bebida":
			_r(ci, a, 0.25, 0.3, 0.75, 0.95, cor)
			_r(ci, a, 0.4, 0.05, 0.6, 0.3, cor.darkened(0.3))
		"municao":
			for i in 3:
				var x := 0.12 + i * 0.28
				_r(ci, a, x, 0.4, x + 0.18, 0.92, Color(0.85, 0.68, 0.25, alfa))
				_poli(ci, a, [[x, 0.4], [x + 0.18, 0.4], [x + 0.09, 0.1]], Color(0.72, 0.42, 0.22, alfa))
		"medico":
			_r(ci, a, 0.38, 0.12, 0.62, 0.88, claro)
			_r(ci, a, 0.12, 0.38, 0.88, 0.62, claro)
		"comida":
			if it.id == "agua":
				_r(ci, a, 0.25, 0.3, 0.75, 0.95, Color(0.45, 0.7, 0.9, alfa))
				_r(ci, a, 0.4, 0.05, 0.6, 0.3, Color(0.3, 0.5, 0.8, alfa))
			else:
				_r(ci, a, 0.15, 0.15, 0.85, 0.9, Color(0.7, 0.7, 0.72, alfa))
				_r(ci, a, 0.15, 0.38, 0.85, 0.68, cor)
		"roupa":
			if d.get("slot", "") == "cabeca":
				_poli(ci, a, [[0.1, 0.75], [0.2, 0.3], [0.5, 0.12], [0.8, 0.3], [0.9, 0.75]], cor)
			else:
				_poli(ci, a, [[0.3, 0.1], [0.7, 0.1], [0.95, 0.3], [0.82, 0.45], [0.75, 0.38], [0.75, 0.95],
					[0.25, 0.95], [0.25, 0.38], [0.18, 0.45], [0.05, 0.3]], cor)
		"mochila":
			_r(ci, a, 0.18, 0.2, 0.82, 0.95, cor)
			_r(ci, a, 0.18, 0.2, 0.82, 0.42, cor.darkened(0.3))
			_r(ci, a, 0.4, 0.05, 0.6, 0.2, cor.darkened(0.3))
		"ferramenta":
			ci.draw_line(_p(a, 0.15, 0.85), _p(a, 0.85, 0.15), cor, maxf(3.0, a.size.x * 0.12))
			ci.draw_circle(_p(a, 0.82, 0.18), minf(a.size.x, a.size.y) * 0.14, cor)
		_:
			var c := _p(a, 0.5, 0.58)
			var raio := minf(a.size.x, a.size.y) * 0.32
			ci.draw_circle(c, raio, cor)
			ci.draw_circle(c + Vector2(-raio * 0.8, -raio * 0.85), raio * 0.38, cor)
			ci.draw_circle(c + Vector2(raio * 0.8, -raio * 0.85), raio * 0.38, cor)
