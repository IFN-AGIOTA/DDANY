extends RefCounted
# OCLUSÃO (occlusion culling): cada prédio inteiro ganha uma CAIXA OCLUSORA invisível, um pouco menor que ele.
# A Godot desenha essas caixas numa imagem de profundidade pequena (no processador) e NÃO MANDA PARA A PLACA o
# que ficou todo escondido atrás delas: carros, árvores, lixo, infectados, pessoas e os blocos de prédios de trás.
# Na rua de Nova York quase tudo atrás da primeira fileira de prédios some. Do alto/campo aberto não muda nada.
# As caixas ficam juntas em pedaços de CEL x CEL m (um ArrayOccluder3D por pedaço = poucos nós).
# Prédio com o INTERIOR montado (mundo/interiores.gd -> cidade.esconder_predio) sai da oclusão até fechar de
# novo: senão a caixa esconderia o próprio interior (e o jogador lá dentro).
# Ruínas ficam de fora (formato irregular). Liga/desliga: Opções › Gráficos › "Ocultar o que está atrás".
# Mexa AQUI para: tamanho dos pedaços, quanto a caixa é menor que o prédio, altura mínima.

const CEL := 250.0
const RECUO := 0.5            # a caixa fica 0,5 m para dentro de cada parede/telhado (nada visível some)
const ALTURA_MIN := 8.0

var cidade
var nos: Array[OccluderInstance3D] = []
var _cels := {}               # Vector2i -> [índice em cidade.predio_info]
var _no := {}                 # Vector2i -> OccluderInstance3D
var _fora := {}               # prédios fora da oclusão agora (interior montado)

func montar(c) -> void:
	cidade = c
	for i in c.predio_info.size():
		var inf: Dictionary = c.predio_info[i]
		if inf["ruina"] or float(inf["h"]) < ALTURA_MIN:
			continue
		var k := Vector2i(floori(inf["x"] / CEL), floori(inf["z"] / CEL))
		if not _cels.has(k):
			_cels[k] = []
		_cels[k].append(i)
	for k in _cels:
		var oi := OccluderInstance3D.new()
		oi.name = "Oclusor_%d_%d" % [k.x, k.y]
		_no[k] = oi
		nos.append(oi)
		_refazer(k)

# o interior do prédio i foi montado (fora = true) ou fechado (fora = false)
func predio_fora(i: int, fora: bool) -> void:
	if i < 0 or i >= cidade.predio_info.size():
		return
	var inf: Dictionary = cidade.predio_info[i]
	var k := Vector2i(floori(inf["x"] / CEL), floori(inf["z"] / CEL))
	if not _cels.has(k) or fora == _fora.has(i):
		return
	if fora:
		_fora[i] = true
	else:
		_fora.erase(i)
	_refazer(k)

func _refazer(k: Vector2i) -> void:
	var v := PackedVector3Array()
	var ix := PackedInt32Array()
	for i in _cels[k]:
		if not _fora.has(i):
			_caixa(v, ix, cidade.predio_info[i])
	var oc := ArrayOccluder3D.new()
	oc.set_arrays(v, ix)
	_no[k].occluder = oc

# caixa sem o fundo (a câmera nunca fica embaixo do chão): 8 cantos, 10 triângulos
func _caixa(v: PackedVector3Array, ix: PackedInt32Array, inf: Dictionary) -> void:
	var hx: float = inf["sx"] * 0.5 - RECUO
	var hz: float = inf["sz"] * 0.5 - RECUO
	if hx <= 0.5 or hz <= 0.5:
		return
	var x: float = inf["x"]
	var z: float = inf["z"]
	var y0: float = cidade.Y_TERRA
	var y1: float = cidade.Y_RUA + float(inf["h"]) - RECUO
	var b := v.size()
	for y in [y0, y1]:
		v.append(Vector3(x - hx, y, z - hz))
		v.append(Vector3(x + hx, y, z - hz))
		v.append(Vector3(x + hx, y, z + hz))
		v.append(Vector3(x - hx, y, z + hz))
	for f in [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7]]:
		ix.append_array(PackedInt32Array([b + f[0], b + f[1], b + f[2], b + f[0], b + f[2], b + f[3]]))
