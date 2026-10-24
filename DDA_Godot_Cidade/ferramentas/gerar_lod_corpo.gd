extends SceneTree
# LOD DO CORPO: o preparar_personagem.gd monta a malha do corpo de novo (para guardar as partes do corpo em COLOR) e
# ela sai SEM níveis de detalhe. Este script gera os LODs (versões com menos triângulos, mesmos vértices: as partes
# do corpo e as roupas continuam iguais) e grava o jogador/sobrevivente/corpo.scn de volta. A Godot troca de nível
# sozinha pela distância (outros jogadores e o boneco de longe ficam bem mais leves).
# NÃO roda dentro do jogo. Rodar depois do preparar_personagem.gd:
#   godot --headless -s res://ferramentas/gerar_lod_corpo.gd
const CENA := "res://jogador/sobrevivente/corpo.scn"

func _initialize():
	var n: Node = load(CENA).instantiate()
	var corpo: MeshInstance3D = n.find_children("Corpo", "MeshInstance3D", true, false)[0]
	var m: ArrayMesh = corpo.mesh
	var im := ImporterMesh.new()
	im.resource_name = m.resource_name
	for s in m.get_surface_count():
		im.add_surface(m.surface_get_primitive_type(s), m.surface_get_arrays(s), [], {}, m.surface_get_material(s),
			m.surface_get_name(s), m.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	im.generate_lods(25.0, 60.0, [])
	var nova := im.get_mesh()
	nova.resource_name = m.resource_name
	corpo.mesh = nova
	for c in n.find_children("*", "", true, false):
		c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	var tris := []
	for l in im.get_surface_lod_count(0):
		tris.append(im.get_surface_lod_indices(0, l).size() / 3)
	print("corpo: ", nova.surface_get_array_index_len(0) / 3, " triângulos · LODs: ", tris, " -> ", ResourceSaver.save(ps, CENA))
	n.free()
	quit()
