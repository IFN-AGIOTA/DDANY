# texturas das roupas -> jogador/roupas/texturas/<peça>.png (512). Sem transparência (o fundo fora das "ilhas" do UV é
# preenchido com a cor mais perto, para o mipmap e a malha simplificada não mostrarem buracos), menos nas peças de ALFA.
import json, glob, os, sys
import numpy as np
from PIL import Image, ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = True
from scipy import ndimage
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "jogador", "roupas", "texturas") + "/"
ALFA = {"mindfront_tactical_vest_male", "mindfront_tactical_vest_female"}
def achar(nm, tex):
    for root, _, fs in os.walk("roupas/" + nm):
        for x in fs:
            if x.lower() == tex.lower(): return os.path.join(root, x)
    return None
nomes = sys.argv[1:] or sorted({os.path.basename(f)[:-7] for f in glob.glob("saida/*_m.json")})
# peças "__cima"/"__baixo" usam a mesma textura: junta as UVs das duas para a máscara das ilhas
feitos = set()
for nm in nomes:
    j = json.load(open("saida/%s_m.json" % nm)); nm = nm.split("__")[0]
    if nm in feitos: continue
    feitos.add(nm)
    for extra in glob.glob("saida/%s__*_m.json" % nm):
        if extra != "saida/%s_m.json" % nm:
            e = json.load(open(extra)); off = len(j["UV"])
            j = dict(j); j["UV"] = j["UV"] + e["UV"]; j["I"] = j["I"] + [i + off for i in e["I"]]
    src = achar(nm, j["tex"]) if j["tex"] else None
    if not src:
        print("SEM TEXTURA", nm, j["tex"]); continue
    im = Image.open(src).convert("RGBA")
    im.thumbnail((512, 512), Image.LANCZOS)
    a = np.array(im)
    # máscara das "ilhas" do UV (onde a malha usa a textura), desenhando os triângulos do UV
    from PIL import ImageDraw
    H, W = a.shape[:2]
    mk = Image.new("L", (W, H), 0); dr = ImageDraw.Draw(mk)
    UV = np.array(j["UV"]); I = np.array(j["I"]).reshape(-1, 3)
    pts = np.stack([UV[:, 0] * W, (1 - UV[:, 1]) * H], 1)
    for t in I:
        dr.polygon([tuple(pts[t[0]]), tuple(pts[t[1]]), tuple(pts[t[2]])], fill=255)
    usado = ndimage.binary_dilation(np.array(mk) > 0, iterations=2)
    if nm not in ALFA:
        a[:, :, 3] = np.where(usado, a[:, :, 3], 0)
    if nm in ALFA:
        Image.fromarray(a).save(D + nm + ".png")
    else:
        opaco = a[:, :, 3] > 8
        if not opaco.all() and opaco.any():
            _, (iy, ix) = ndimage.distance_transform_edt(~opaco, return_indices=True)
            a[:, :, :3] = a[iy, ix, :3]
        Image.fromarray(a[:, :, :3]).save(D + nm + ".png")
    print(nm, im.size)
