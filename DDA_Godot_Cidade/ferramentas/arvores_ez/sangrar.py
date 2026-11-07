# 1.20 · "sangra" a cor das folhas para os pixels transparentes do atlas dos impostores (mundo/arvores/impostores.png).
# Sem isso, de longe (mipmaps) a borda das copas fica escura/preta: o transparente tem cor preta e ela se mistura.
# Uso: python3 ferramentas/arvores_ez/sangrar.py mundo/arvores/impostores.png
import sys
import numpy as np
from PIL import Image

arq = sys.argv[1]
im = np.asarray(Image.open(arq).convert('RGBA')).astype(np.float32) / 255.0
rgb = im[..., :3]
a = im[..., 3:4]
cheio = (a > 0.02).astype(np.float32)
cor = rgb * cheio
peso = cheio.copy()
for _ in range(24):                       # espalha a média dos vizinhos com cor para quem não tem
    c2 = cor.copy()
    p2 = peso.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        c2 += np.roll(np.roll(cor, dy, 0), dx, 1)
        p2 += np.roll(np.roll(peso, dy, 0), dx, 1)
    vazio = peso[..., 0] < 0.5
    tem = p2[..., 0] > 0.0
    m = vazio & tem
    cor[m] = c2[m] / p2[m]
    peso[m] = 1.0
saida = np.where(cheio > 0.5, rgb, cor)
out = np.concatenate([saida, a], axis=-1)
Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(arq, optimize=True)
print('sangrou', arq)
