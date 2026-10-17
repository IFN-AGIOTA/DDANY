# Exporta as peças do Dominic (do .blend feito por modelar_dominic.py) para um .glb parado, com as cores nos vértices.
# Rodar:  SAIDA=<arquivo .glb> blender -b <dominic.blend> -P exportar_dominic.py
import bpy, os
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.context.scene.objects:
	if o.type == "MESH":
		o.select_set(True)
kw = dict(filepath=os.environ["SAIDA"], export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
	export_animations=False, export_cameras=False, export_lights=False)
try:
	bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
except TypeError:
	bpy.ops.export_scene.gltf(**kw)
print("EXPORTOU", [o.name for o in bpy.context.selected_objects])
