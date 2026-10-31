extends Node3D
# CONTÊINER NO MUNDO (caixa, armário, geladeira...). Tem uma grade própria que aparece na coluna da
# ESQUERDA do inventário quando o jogador está perto. É sólido (camada 1, como o resto do mundo).
# Uso: var c = CaixaMundo.new(); c.nome = "CAIXA MILITAR"; c.tamanho = Vector2i(10, 6); add_child(c);
#      c.guardar(Item.novo("bandagem", 4))

const GradeCls := preload("res://inventario/grade.gd")

var nome := "CAIXA"
var tamanho := Vector2i(8, 5)
var medidas := Vector3(1.2, 0.7, 0.6)        # metros
var cor := Color(0.24, 0.30, 0.20)
var grade = null
var invisivel := false                        # true = é um móvel do interior (o móvel já é desenhado e tem colisão)
var id_loot := ""                             # mundo/loot_mundo.gd: guarda o conteúdo enquanto o prédio está fechado
var modelo := "caixa_militar"                 # modelo 3D de inventario/modelos/ (esticado para as medidas); "" = caixa simples

func _ready() -> void:
	add_to_group("conteineres_mundo")
	if grade == null:
		grade = GradeCls.new(tamanho.x, tamanho.y, nome, self)
	grade.largura = tamanho.x
	grade.altura = tamanho.y
	grade.nome = nome
	grade.dono = self
	if invisivel:
		return
	_colisao()
	var ps: PackedScene = load("res://inventario/modelos/" + modelo + ".glb") if modelo != "" and ResourceLoader.exists("res://inventario/modelos/" + modelo + ".glb") else null
	if ps != null:
		var m: Node3D = ps.instantiate()
		add_child(m)
		var ab := AABB()
		var prim := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
			ab = a if prim else ab.merge(a)
			prim = false
		m.scale = Vector3(medidas.x / maxf(ab.size.x, 0.01), medidas.y / maxf(ab.size.y, 0.01), medidas.z / maxf(ab.size.z, 0.01))
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = medidas
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.85
	bm.material = mat
	mi.mesh = bm
	mi.position.y = medidas.y * 0.5
	add_child(mi)
	var tampa := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(medidas.x + 0.04, 0.05, medidas.z + 0.04)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = cor.darkened(0.3)
	tb.material = tm
	tampa.mesh = tb
	tampa.position.y = medidas.y
	add_child(tampa)

func _colisao() -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = medidas
	cs.shape = bs
	cs.position.y = medidas.y * 0.5
	corpo.add_child(cs)
	add_child(corpo)

# põe um item na primeira vaga livre (usado para encher a caixa no começo)
func guardar(it) -> bool:
	if grade == null:
		grade = GradeCls.new(tamanho.x, tamanho.y, nome, self)
	grade.largura = tamanho.x
	grade.altura = tamanho.y
	var v: Vector3i = grade.achar_vaga(it)
	if v.x < 0:
		return false
	grade.colocar(it, v.x, v.y, v.z == 1)
	return true
