# PREPARA OS MODELOS DO CENÁRIO (0.69) baixados do Poly Haven (CC0) para o jogo. Roda no BLENDER (4.2), fora do jogo:
#   ORIGEM=<pasta com os downloads> DESTINO=<pasta DDA_Godot_Cidade> blender -b -P ferramentas/preparar_cenario.py
# ORIGEM/ph/<nome>/<nome>_1k.gltf = modelo do Poly Haven (glTF, texturas 1k; endereços em mundo/cenario/LICENCA.txt).
# Para cada um: junta numa malha só, simplifica até "tris" triângulos, reduz as texturas para "tex" px, deixa no
# TAMANHO REAL (metros) com a origem embaixo no meio e grava mundo/cenario/<id>.glb.
# Os modelos do Quaternius (rua e natureza) já são leves: vão direto para mundo/cenario/ (veja o LICENCA.txt).
import bpy, os
from mathutils import Vector, Matrix

ORIGEM = os.environ.get("ORIGEM", "")
DESTINO = os.environ.get("DESTINO", "")

# id: arquivo do Poly Haven, peças (pedaço do nome; vazio = todas), limite de triângulos, textura (px)
MODELOS = {
	"hidrante": dict(ph="fire_hydrant", pecas=["_aged"], tris=500, tex=512),
	"barreira": dict(ph="concrete_road_barrier_02", tris=300, tex=512),
	"lixeira": dict(ph="metal_trash_can", pecas=["rust"], tris=500, tex=512),
	"caixa_energia": dict(ph="utility_box_02", tris=400, tex=512),
	"bueiro": dict(ph="water_manhole_cover", tris=120, tex=256),
	"saco_lixo": dict(ph="trashbag", tris=250, tex=256),
	"barril": dict(ph="Barrel_01", tris=320, tex=512),
	"pneu": dict(ph="old_tyre", tris=240, tex=256),
	"caixote": dict(ph="wooden_crate_02", tris=260, tex=512),
	"carro_coberto": dict(ph="covered_car", tris=1200, tex=512),
	"caixa_papelao": dict(ph="cardboard_box_01", tris=150, tex=256),
}

def preparar(id, c):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=os.path.join(ORIGEM, "ph", c["ph"], c["ph"] + "_1k.gltf"))
	malhas = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	if c.get("pecas"):
		malhas = [o for o in malhas if any(p in o.name for p in c["pecas"])]
	bpy.ops.object.select_all(action="DESELECT")
	for o in malhas:
		o.select_set(True)
	bpy.context.view_layer.objects.active = malhas[0]
	bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
	for o in list(bpy.context.scene.objects):
		if o not in malhas:
			bpy.data.objects.remove(o, do_unlink=True)
	if len(malhas) > 1:
		bpy.ops.object.join()
	ob = bpy.context.view_layer.objects.active
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	ob.name = "Malha"
	ob.data.name = "Malha_" + id
	vs = [v.co for v in ob.data.vertices]
	mn = Vector([min(v[i] for v in vs) for i in range(3)])
	mx = Vector([max(v[i] for v in vs) for i in range(3)])
	ob.data.transform(Matrix.Translation(-Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))))
	tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
	if tris > c["tris"]:
		mod = ob.modifiers.new("simplificar", "DECIMATE")
		mod.ratio = c["tris"] / tris
		bpy.ops.object.modifier_apply(modifier=mod.name)
	tris2 = sum(len(p.vertices) - 2 for p in ob.data.polygons)
	for m in ob.data.materials:
		if m is None or not m.use_nodes:
			continue
		for n in m.node_tree.nodes:
			if n.type == "TEX_IMAGE" and n.image is not None and (n.image.size[0] > c["tex"] or n.image.size[1] > c["tex"]):
				n.image.scale(c["tex"], c["tex"])
	pasta = os.path.join(DESTINO, "mundo/cenario")
	os.makedirs(pasta, exist_ok=True)
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(filepath=os.path.join(pasta, id + ".glb"), export_format="GLB", use_selection=True,
		export_apply=True, export_yup=True, export_animations=False, export_image_format="JPEG", export_jpeg_quality=85,
		export_cameras=False, export_lights=False)
	print("PRONTO", id, "tris", tris, "->", tris2, "medidas", tuple(round(x, 2) for x in (mx - mn)))

# arbusto LEVE para o mato em volta do jogador (são muitos): o Bush_Common do Quaternius (900 triângulos) simplificado
def arbusto_leve():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	pasta = os.path.join(DESTINO, "mundo/cenario/natureza")
	bpy.ops.import_scene.gltf(filepath=os.path.join(pasta, "Bush_Common.gltf"))
	ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
	bpy.context.view_layer.objects.active = ob
	tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
	mod = ob.modifiers.new("simplificar", "DECIMATE")
	mod.ratio = 240.0 / tris
	bpy.ops.object.modifier_apply(modifier=mod.name)
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(filepath=os.path.join(pasta, "Bush_Leve.gltf"), export_format="GLTF_SEPARATE", use_selection=True,
		export_apply=True, export_yup=True, export_animations=False, export_vertex_color="ACTIVE", export_image_format="NONE",
		export_cameras=False, export_lights=False)
	print("PRONTO arbusto_leve tris", tris, "->", sum(len(p.vertices) - 2 for p in ob.data.polygons))

so = os.environ.get("SO", "")
if so == "arbusto_leve":
	arbusto_leve()
	so = "-"
for id, c in MODELOS.items():
	if so and id not in so.split(","):
		continue
	preparar(id, c)
