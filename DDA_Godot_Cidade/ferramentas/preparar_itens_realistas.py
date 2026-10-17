# PREPARA OS MODELOS 3D REALISTAS (baixados, licença livre) para o jogo. Roda no BLENDER (4.2), fora do jogo:
#   ORIGEM=<pasta com os downloads> DESTINO=<pasta DDA_Godot_Cidade> blender -b -P ferramentas/preparar_itens_realistas.py
# Pastas esperadas dentro de ORIGEM (veja os endereços em armas/modelos/LICENCA.txt e inventario/modelos/LICENCA.txt):
#   ph/<nome>/<nome>_1k.gltf ......... modelos do Poly Haven (glTF, texturas 1k)
#   m4a1_0/M4A1/M4A1.fbx (+ png) ..... M4A1 (nisu, OpenGameArt)
#   akm/akm54.blend .................. AKM (LonesomeDucky, OpenGameArt)
#   Shotgun_2/Shotgun.blend .......... Remington 870 (MikeMoon, OpenGameArt)
# O que faz com cada modelo: escolhe as peças, gira, junta numa malha só ("Malha"), simplifica se tiver
# triângulos demais, reduz as texturas e põe no tamanho real e na convenção do jogo:
#   ARMA DE FOGO: cano para +Z da Godot, origem na empunhadura, nós vazios "Cano" (boca do cano) e "Mira"
#                 (onde a mira/luneta encaixa) -> armas/modelos/<id>.glb
#   ARMA BRANCA:  lâmina/cabeça para +Z, origem no cabo -> armas/modelos/<id>.glb
#   ITEM:         em pé no chão, origem embaixo no meio -> inventario/modelos/<nome>.glb
# (Blender: Z para cima e -Y = frente; a exportação glTF converte para a Godot: Y para cima e +Z = frente.)
import bpy, bmesh, os, math
from mathutils import Vector, Matrix

ORIGEM = os.environ.get("ORIGEM", "")
DESTINO = os.environ.get("DESTINO", "")
PH = lambda n: os.path.join(ORIGEM, "ph", n, n + "_1k.gltf")

# id: tipo, arquivo, peças (pedaço do nome; vazio = todas), giros [(eixo, graus)], medida (m), fração da
#     empunhadura (a partir de trás), limite de triângulos, tamanho das texturas
MODELOS = {
	# ---- armas de fogo (comprimento total) ----
	"pistola": dict(tipo="fogo", arq=PH("service_pistol"), pecas=["pistol_a", "slide_a", "hammer_a", "trigger_a"],
		giros=[("Z", -90)], medida=0.21, emp=0.22, tris=7000, tex=512),
	"m4": dict(tipo="fogo", arq="m4a1_0/M4A1/M4A1.fbx", giros=[], medida=0.86, emp=0.36, tris=8000, tex=1024,
		texturas="m4a1_0/M4A1/M4A1_"),
	"ak": dict(tipo="fogo", arq="akm/akm54.blend", giros=[], medida=0.88, emp=0.34, tris=8000, tex=1024),
	"espingarda": dict(tipo="fogo", arq="Shotgun_2/Shotgun.blend", giros=[], medida=1.05, emp=0.3, tris=8000, tex=512,
		cores={"Synthetic": ((0.035, 0.035, 0.038), 0.7, 0.42), "Wood": ((0.22, 0.1, 0.04), 0.0, 0.5)}),
	"rifle_caca": dict(tipo="fogo", arq=PH("bolt_action_rifle_7_62"), giros=[("Z", -90)], medida=1.1, emp=0.3,
		tris=8000, tex=512),
	# ---- armas brancas (comprimento total) ----
	"faca": dict(tipo="branca", arq=PH("fish_knife"), giros=[("X", 90), ("Y", 90)], medida=0.3, emp=0.2, tris=3000, tex=512),
	"facao": dict(tipo="branca", arq=PH("machete"), giros=[("X", 90)], medida=0.6, emp=0.15, tris=3000, tex=512),
	"taco": dict(tipo="branca", arq=PH("baseball_bat"), giros=[("X", 90)], medida=0.85, emp=0.12, tris=3000, tex=512),
	"machado": dict(tipo="branca", arq=PH("hatchet"), giros=[("X", 90), ("Y", 180)], medida=0.5, emp=0.12, tris=4000, tex=512),
	"pe_de_cabra": dict(tipo="branca", arq=PH("crowbar_01"), giros=[("X", 90)], medida=0.62, emp=0.15, tris=3000, tex=512),
	# ---- itens do chão (maior medida) ----
	"kit_medico": dict(tipo="item", arq=PH("medical_box"), medida=0.3, tris=3000, tex=512),
	"fita": dict(tipo="item", arq=PH("medical_tape"), medida=0.1, tris=1500, tex=256),
	"lata_feijao": dict(tipo="item", arq=PH("long_life_food"), pecas=["beans"], medida=0.13, tris=1600, tex=256),
	"lata_tomate": dict(tipo="item", arq=PH("long_life_food"), pecas=["tomatoes"], medida=0.11, tris=1600, tex=256),
	"lata_sardinha": dict(tipo="item", arq=PH("long_life_food"), pecas=["sardines"], medida=0.13, tris=1600, tex=256),
	"caixa_leite": dict(tipo="item", arq=PH("long_life_food"), pecas=["milk"], medida=0.17, tris=400, tex=256),
	"lata_peixe": dict(tipo="item", arq=PH("russian_food_cans_01"), pecas=["can_fish"], medida=0.1, tris=800, tex=256),
	"lata_leite": dict(tipo="item", arq=PH("russian_food_cans_01"), pecas=["can_cond"], medida=0.08, tris=800, tex=256),
	"maca": dict(tipo="item", arq=PH("food_apple_01"), medida=0.085, tris=1500, tex=256),
	"garrafa_termica": dict(tipo="item", arq=PH("plastic_thermos"), medida=0.28, tris=2500, tex=512),
	"lanterna": dict(tipo="item", arq=PH("small_plastic_torch"), medida=0.2, tris=2500, tex=512),
	"isqueiro": dict(tipo="item", arq=PH("vintage_lighter"), medida=0.06, tris=2000, tex=256),
	"radio": dict(tipo="item", arq=PH("boombox"), medida=0.34, tris=3000, tex=512),
	"municao": dict(tipo="item", arq=PH("ammo_box"), medida=0.2, tris=2500, tex=512),
	"caixa_ferramentas": dict(tipo="item", arq=PH("metal_toolbox"), medida=0.36, tris=3000, tex=512),
	"pote_plastico": dict(tipo="item", arq=PH("plastic_container"), medida=0.16, tris=2000, tex=256),
	"pente_pistola": dict(tipo="item", arq=PH("service_pistol"), pecas=["magazine_loaded"], medida=0.12, tris=2500, tex=512),
	"galho": dict(tipo="item", arq=PH("dry_branches_medium_01"), pecas=["_b"], giros=[("Z", 90)], medida=0.7, tris=2500, tex=512),
	"caixa_militar": dict(tipo="item", arq=PH("old_military_crate"), pecas=["crate_a", "lid_a", "loop_a", "latch_a", "cloth_a"],
		medida=1.3, tris=6000, tex=512),
}

def limpar():
	bpy.ops.wm.read_factory_settings(use_empty=True)

def carregar(arq):
	ext = arq.lower().rsplit(".", 1)[1]
	if ext == "blend":
		bpy.ops.wm.open_mainfile(filepath=arq)
	else:
		limpar()
		if ext in ("gltf", "glb"):
			bpy.ops.import_scene.gltf(filepath=arq)
		elif ext == "fbx":
			bpy.ops.import_scene.fbx(filepath=arq)

def material_com_texturas(prefixo):
	m = bpy.data.materials.new("M4A1")
	m.use_nodes = True
	nt = m.node_tree
	p = nt.nodes["Principled BSDF"]
	def tex(nome, cor):
		n = nt.nodes.new("ShaderNodeTexImage")
		n.image = bpy.data.images.load(prefixo + nome + ".png")
		if not cor:
			n.image.colorspace_settings.name = "Non-Color"
		return n
	nt.links.new(tex("Base_Color", True).outputs["Color"], p.inputs["Base Color"])
	nt.links.new(tex("Metallic", False).outputs["Color"], p.inputs["Metallic"])
	nt.links.new(tex("Roughness", False).outputs["Color"], p.inputs["Roughness"])
	nm = nt.nodes.new("ShaderNodeNormalMap")
	nt.links.new(tex("Normal", False).outputs["Color"], nm.inputs["Color"])
	nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
	return m

def preparar(id, c):
	arq = c["arq"] if os.path.isabs(c["arq"]) else os.path.join(ORIGEM, c["arq"])
	carregar(arq)
	malhas = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	pecas = c.get("pecas")
	if pecas:
		malhas = [o for o in malhas if any(p in o.name for p in pecas)]
	# solta as peças dos "pais" (guardando a posição) antes de apagar o resto
	bpy.ops.object.select_all(action="DESELECT")
	for o in malhas:
		o.hide_set(False)
		o.select_set(True)
	bpy.context.view_layer.objects.active = malhas[0]
	bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
	for o in list(bpy.context.scene.objects):
		if o not in malhas:
			bpy.data.objects.remove(o, do_unlink=True)
	if "texturas" in c:
		m = material_com_texturas(os.path.join(ORIGEM, c["texturas"]))
		for o in malhas:
			o.data.materials.clear()
			o.data.materials.append(m)
	for nome, (cor, metal, rug) in c.get("cores", {}).items():
		m = bpy.data.materials.get(nome)
		if m is None:
			continue
		m.use_nodes = True
		p = m.node_tree.nodes.get("Principled BSDF")
		p.inputs["Base Color"].default_value = (*cor, 1.0)
		p.inputs["Metallic"].default_value = metal
		p.inputs["Roughness"].default_value = rug
	# junta tudo numa malha só, já com as transformações aplicadas
	bpy.ops.object.select_all(action="DESELECT")
	for o in malhas:
		o.hide_set(False)
		o.select_set(True)
	bpy.context.view_layer.objects.active = malhas[0]
	if len(malhas) > 1:
		bpy.ops.object.join()
	ob = bpy.context.view_layer.objects.active
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	ob.name = "Malha"
	ob.data.name = "Malha_" + id
	for eixo, graus in c.get("giros", []):
		ob.data.transform(Matrix.Rotation(math.radians(graus), 4, eixo))
	vs = [v.co.copy() for v in ob.data.vertices]
	mn = Vector([min(v[i] for v in vs) for i in range(3)])
	mx = Vector([max(v[i] for v in vs) for i in range(3)])
	extras = {}
	if c["tipo"] == "fogo":
		# o comprido fica em Y; descobre de que lado está a boca do cano (a ponta mais fina) e põe em -Y
		compr = mx.y - mn.y
		def area(ponta_menor):
			pts = [v for v in vs if (v.y < mn.y + compr * 0.05 if ponta_menor else v.y > mx.y - compr * 0.05)]
			return (max(p.x for p in pts) - min(p.x for p in pts)) * (max(p.z for p in pts) - min(p.z for p in pts))
		if area(False) < area(True):
			ob.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
			vs = [v.co.copy() for v in ob.data.vertices]
			mn = Vector([min(v[i] for v in vs) for i in range(3)])
			mx = Vector([max(v[i] for v in vs) for i in range(3)])
		k = c["medida"] / compr
		ponta = [v for v in vs if v.y < mn.y + compr * 0.03]
		boca = sum(ponta, Vector()) / len(ponta)
		origem = Vector(((mn.x + mx.x) / 2, mx.y - compr * c["emp"], boca.z - 0.04 / k))
		# topo do corpo entre 30% e 55% do comprimento (a partir de trás): onde a mira encaixa
		faixa = [v for v in vs if mx.y - compr * 0.55 < v.y < mx.y - compr * 0.3]
		topo = max(v.z for v in faixa)
		frac_mira = 0.3 if id == "rifle_caca" else 0.36
		extras["Cano"] = (Vector((origem.x, mn.y, boca.z)) - origem) * k
		extras["Mira"] = (Vector((origem.x, mx.y - compr * frac_mira, topo - 0.004 / k)) - origem) * k
	elif c["tipo"] == "branca":
		compr = mx.y - mn.y
		k = c["medida"] / compr
		origem = Vector(((mn.x + mx.x) / 2, mx.y - compr * c["emp"], (mn.z + mx.z) / 2))
	else:
		k = c["medida"] / max(mx - mn)
		origem = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
	ob.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(-origem))
	# suaviza as normais de modelos sem textura (a espingarda) e simplifica os pesados
	tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
	if tris > c["tris"]:
		mod = ob.modifiers.new("simplificar", "DECIMATE")
		mod.ratio = c["tris"] / tris
		bpy.ops.object.modifier_apply(modifier=mod.name)
	tris2 = sum(len(p.vertices) - 2 for p in ob.data.polygons)
	# itens pequenos no chão: sem mapa de relevo (normal map), quase não aparece e pesa no APK
	if c["tipo"] == "item":
		for m in ob.data.materials:
			if m is None or not m.use_nodes:
				continue
			for n in list(m.node_tree.nodes):
				if n.type == "NORMAL_MAP":
					for l in list(n.outputs["Normal"].links):
						m.node_tree.links.remove(l)
	# texturas menores (o celular agradece)
	for m in ob.data.materials:
		if m is None or not m.use_nodes:
			continue
		for n in m.node_tree.nodes:
			if n.type == "TEX_IMAGE" and n.image is not None:
				img = n.image
				if img.size[0] > c["tex"] or img.size[1] > c["tex"]:
					img.scale(c["tex"], c["tex"])
	for nome, pos in extras.items():
		e = bpy.data.objects.new(nome, None)
		e.location = pos
		bpy.context.scene.collection.objects.link(e)
	pasta = os.path.join(DESTINO, "inventario/modelos" if c["tipo"] == "item" else "armas/modelos")
	os.makedirs(pasta, exist_ok=True)
	saida = os.path.join(pasta, id + ".glb")
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", use_selection=True, export_apply=True,
		export_yup=True, export_animations=False, export_image_format="JPEG", export_jpeg_quality=88,
		export_cameras=False, export_lights=False)
	print("PRONTO", id, "tris", tris, "->", tris2, "escala", round(k, 4), {n: tuple(round(x, 3) for x in p) for n, p in extras.items()})

so = os.environ.get("SO", "")
for id, c in MODELOS.items():
	if so and id not in so.split(","):
		continue
	preparar(id, c)
