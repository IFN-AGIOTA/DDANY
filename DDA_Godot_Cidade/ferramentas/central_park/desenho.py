# 1.20 · DESENHO DO CENTRAL PARK (mundo/central_park.gd lê o data/central_park.json que este script grava).
# O parque do mapa (Liberty City) tem ~950 x 1730 m (o de verdade tem 800 x 4000): os lugares mais conhecidos foram
# encaixados mais ou menos na mesma ordem do de verdade (sul -> norte), com as fotos de referência:
#   SUL: The Pond + Gapstow Bridge (canto sudeste), Wollman Rink, o Carrossel, campos de beisebol (Heckscher),
#        Sheep Meadow (o gramadão), The Mall/Literary Walk (alameda reta com 4 fileiras de olmos, estátuas e bancos),
#        Naumburg Bandshell, East Green e Pilgrim Hill (gramados do leste).
#   A rua que atravessa o parque (a "72nd Street") separa as metades.
#   NORTE: Bethesda Terrace (terraço alto com a arcada, 2 escadarias e a praça de tijolos com a Fonte do Anjo) na
#        beira do THE LAKE; Bow Bridge (ponte de ferro branca) no estreito do lago; Cherry Hill; Strawberry Fields
#        (mosaico "IMAGINE"); Loeb Boathouse; Conservatory Water (laguinho dos barquinhos); The Ramble (mata fechada);
#        Belvedere Castle em cima da Vista Rock, de frente para o Turtle Pond; Delacorte Theater; Great Lawn com
#        os campos; Cleopatra's Needle (o obelisco).
#   Pistas do parque (West/East Drive) em volta, caminhos curvos por todo lado, postes e bancos ao longo deles,
#   muro baixo de pedra no contorno (com as entradas) e MATA DENSA em todo o resto (árvores do mundo/arvores.gd).
# Coordenadas do mundo do jogo (x = leste, z = sul; o norte é -z). Rodar: python3 ferramentas/central_park/desenho.py
#   [--foto arquivo.png]  -> grava data/central_park.json (e a planta, se pedir)
import json, math, os, random, sys
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, '..', '..'))
cidade = json.load(open(os.path.join(RAIZ, 'data', 'city.json')))
PARQUES = [cidade['parks'][92], cidade['parks'][91]]     # as duas metades (a rua da "72nd" passa entre elas)
LAGO_ANTIGO = 5                                          # o lago do mapa que ficava escondido embaixo da grama

def pares(f):
    return [(f[i], f[i + 1]) for i in range(0, len(f) - 1, 2)]

# ---------------------------------------------------------------------------------------------------------------
# LAGOS (entram no lugar do lago antigo em data/city.json "lands", tipo 1)
# ---------------------------------------------------------------------------------------------------------------
LAGOS = {
    'the_lake': [(-1560, -1402), (-1640, -1402), (-1678, -1416), (-1700, -1447), (-1736, -1451), (-1768, -1430),
                 (-1822, -1412), (-1878, -1424), (-1906, -1463), (-1892, -1508), (-1842, -1530), (-1790, -1516),
                 (-1758, -1484), (-1736, -1473), (-1700, -1475), (-1666, -1503), (-1642, -1543), (-1602, -1560),
                 (-1566, -1576), (-1548, -1610), (-1524, -1646), (-1492, -1641), (-1494, -1602), (-1478, -1562),
                 (-1440, -1547), (-1407, -1521), (-1399, -1470), (-1420, -1430), (-1480, -1406)],
    'the_pond': [(-1442, -300), (-1395, -280), (-1320, -282), (-1262, -300), (-1250, -345), (-1275, -385),
                 (-1330, -392), (-1366, -404), (-1384, -432), (-1406, -446), (-1424, -426), (-1410, -398),
                 (-1416, -362), (-1446, -336)],
    'turtle_pond': [(-1722, -1882), (-1662, -1870), (-1592, -1874), (-1522, -1882), (-1470, -1900), (-1482, -1926),
                    (-1552, -1934), (-1632, -1930), (-1702, -1922), (-1732, -1904)],
    'conservatory_water': [(-1345 + 45 * math.cos(a) * (1.0 if abs(math.cos(a)) < 0.8 else 1.06) - 45 + 45, -1365 + 25 * math.sin(a))
                           for a in [k * math.tau / 20 for k in range(20)]],
}
# ---------------------------------------------------------------------------------------------------------------
# GRAMADOS (sem árvore, grama mais baixa) e PRAÇAS (piso)
# ---------------------------------------------------------------------------------------------------------------
def elipse(cx, cz, rx, rz, n=28, giro=0.0):
    out = []
    for k in range(n):
        a = k * math.tau / n
        x, z = rx * math.cos(a), rz * math.sin(a)
        out.append((cx + x * math.cos(giro) - z * math.sin(giro), cz + x * math.sin(giro) + z * math.cos(giro)))
    return out

GRAMADOS = {
    'sheep_meadow': [(-2040, -600), (-1985, -560), (-1800, -560), (-1748, -600), (-1738, -880), (-1782, -932),
                     (-1990, -936), (-2046, -890)],
    'great_lawn': elipse(-1968, -1765, 98, 140),
    'east_green': [(-1395, -790), (-1300, -770), (-1262, -820), (-1268, -930), (-1330, -960), (-1395, -900)],
    'pilgrim_hill': [(-1420, -1060), (-1330, -1040), (-1270, -1080), (-1275, -1170), (-1360, -1185), (-1425, -1140)],
    'cherry_hill': elipse(-1790, -1376, 38, 22),
    'heckscher': [(-2120, -300), (-1870, -290), (-1850, -420), (-2110, -440)],
    'north_meadow': [(-1440, -1700), (-1330, -1690), (-1280, -1760), (-1300, -1810), (-1420, -1800)],
}
# praças: [nome, polígono, piso] · piso: "tijolo" (Bethesda), "pedra" (lajotas), "asfalto", "terra"
PRACAS = [
    ['bethesda_baixo', [(-1652, -1316), (-1548, -1316), (-1548, -1402), (-1652, -1402)], 'tijolo'],
    ['concert_ground', [(-1625, -1150), (-1555, -1150), (-1530, -1205), (-1625, -1230)], 'pedra'],
    ['cherry_hill_praca', elipse(-1770, -1410, 16, 10, 16), 'pedra'],
    ['imagine', elipse(-2045, -1360, 13, 13, 20), 'pedra'],
    ['boathouse', [(-1390, -1458), (-1352, -1458), (-1352, -1525), (-1390, -1525)], 'pedra'],
    ['conservatory', elipse(-1345, -1365, 56, 34, 24), 'pedra'],
    ['cleopatra', elipse(-1340, -1862, 22, 22, 20), 'pedra'],
    ['castelo', [(-1640, -1832), (-1568, -1832), (-1568, -1866), (-1640, -1866)], 'pedra'],
    ['wollman', elipse(-1530, -370, 62, 36, 24), 'pedra'],
    ['carrossel', elipse(-1700, -520, 22, 22, 16), 'pedra'],
    ['mall_sul', elipse(-1645, -752, 26, 18, 16), 'pedra'],
    ['delacorte', elipse(-1790, -1880, 30, 30, 20), 'pedra'],
]
# ---------------------------------------------------------------------------------------------------------------
# PISTAS (West/East Drive: 9 m, asfalto) e CAMINHOS (4 m; a Mall 12 m)
# ---------------------------------------------------------------------------------------------------------------
PISTAS = [
    [(-1690, -246), (-1712, -330), (-1790, -405), (-1950, -450), (-2075, -540), (-2105, -700), (-2108, -900),
     (-2110, -1100), (-2112, -1215), (-2114, -1300), (-2118, -1500), (-2120, -1700), (-2100, -1880), (-2010, -1948),
     (-1800, -1952), (-1560, -1952), (-1400, -1945), (-1300, -1890), (-1278, -1750), (-1280, -1560), (-1285, -1430),
     (-1292, -1290), (-1300, -1215), (-1318, -1050), (-1350, -820), (-1378, -640), (-1440, -510), (-1570, -455),
     (-1680, -415), (-1712, -330)],
]
CAMINHOS = [
    # sul: entradas -> Pond/Gapstow, Wollman, carrossel, Mall
    [(-1235, -262), (-1250, -300), (-1240, -360), (-1265, -405), (-1330, -415), (-1372, -418), (-1410, -425), (-1452, -460), (-1520, -520), (-1600, -620), (-1640, -745)],
    [(-1480, -248), (-1470, -300), (-1460, -340), (-1445, -420), (-1460, -480)],
    [(-1610, -248), (-1615, -300), (-1590, -330), (-1580, -420), (-1620, -470), (-1680, -500)],
    [(-2150, -258), (-2100, -275), (-1990, -280), (-1860, -275), (-1800, -320), (-1760, -420), (-1720, -500), (-1690, -560), (-1660, -660), (-1645, -745)],
    [(-1720, -540), (-1745, -585), (-1790, -545), (-1990, -548), (-2055, -590), (-2060, -900), (-2000, -948), (-1775, -950), (-1725, -900), (-1724, -620), (-1745, -585)],
    [(-2160, -481), (-2120, -490), (-2075, -540)],
    [(-2160, -869), (-2120, -872), (-2060, -880)],
    [(-1222, -725), (-1260, -720), (-1330, -700), (-1420, -690), (-1520, -700), (-1600, -730), (-1630, -750)],
    [(-1222, -1019), (-1260, -1010), (-1300, -980), (-1380, -960), (-1450, -980), (-1520, -1040), (-1575, -1110)],
    [(-1640, -760), (-1700, -900), (-1720, -1000), (-1700, -1100), (-1640, -1190), (-1610, -1215)],
    [(-1580, -1110), (-1540, -1080), (-1470, -1050), (-1440, -1130), (-1460, -1200)],
    [(-2160, -1100), (-2060, -1050), (-1950, -1020), (-1850, -1040), (-1760, -1080), (-1700, -1100)],
    # norte: margens do lago, Bow Bridge, Ramble, castelo, Turtle Pond, Great Lawn
    [(-1548, -1316), (-1520, -1300), (-1460, -1300), (-1400, -1320), (-1330, -1320), (-1268, -1340), (-1225, -1360)],
    [(-1652, -1316), (-1690, -1330), (-1730, -1360), (-1770, -1395), (-1730, -1430), (-1718, -1446)],
    [(-1718, -1478), (-1700, -1510), (-1680, -1560), (-1640, -1600), (-1600, -1640), (-1580, -1700), (-1600, -1760), (-1610, -1832)],
    [(-1770, -1395), (-1840, -1395), (-1900, -1410), (-1935, -1460), (-1920, -1520), (-1860, -1555), (-1780, -1545), (-1740, -1505), (-1718, -1478)],
    [(-1640, -1600), (-1700, -1640), (-1760, -1690), (-1800, -1760), (-1830, -1840), (-1810, -1880)],
    [(-1580, -1700), (-1520, -1700), (-1460, -1690), (-1420, -1640), (-1440, -1580), (-1470, -1555)],
    [(-1600, -1760), (-1540, -1770), (-1470, -1790), (-1420, -1830), (-1380, -1860), (-1362, -1862)],
    [(-1420, -1520), (-1405, -1560), (-1380, -1620), (-1360, -1700), (-1360, -1780), (-1345, -1840)],
    [(-1390, -1458), (-1410, -1420), (-1440, -1400), (-1500, -1395), (-1548, -1395)],
    [(-1352, -1490), (-1300, -1470), (-1250, -1480), (-1218, -1488)],
    [(-1345, -1399), (-1360, -1430), (-1372, -1458)],
    [(-2168, -1360), (-2120, -1360), (-2058, -1360)],
    [(-2032, -1360), (-1960, -1365), (-1880, -1385), (-1840, -1395)],
    [(-1968, -1622), (-1880, -1660), (-1860, -1765), (-1880, -1880), (-1968, -1908), (-2060, -1880), (-2075, -1765), (-2060, -1650), (-1968, -1622)],
    [(-2160, -1738), (-2120, -1740), (-2075, -1760)],
    [(-1868, -1962), (-1860, -1920), (-1830, -1880)],
    [(-1500, -1962), (-1495, -1940), (-1480, -1928), (-1460, -1905), (-1430, -1880), (-1380, -1865)],
    [(-1735, -1905), (-1640, -1945), (-1530, -1945), (-1470, -1915)],
    [(-1214, -1738), (-1260, -1745), (-1300, -1760)],
    [(-1610, -1866), (-1660, -1870), (-1720, -1872)],
]
MALL = [(-1645, -752), (-1600, -1238)]                      # alameda reta (12 m) com 4 fileiras de olmos (até a rua da Bethesda)
# ---------------------------------------------------------------------------------------------------------------
# CONSTRUÇÕES (mundo/central_park.gd monta cada uma): [tipo, x, z, giro (rad; 0 = frente para +z/sul), extra]
# ---------------------------------------------------------------------------------------------------------------
ESTRUTURAS = [
    ['bethesda', -1600, -1292, 0.0, {}],                # montada já virada para o norte (-z: o lago)
    ['bow_bridge', -1718, -1462, 0.0, {'vao': 44.0}],    # atravessa o estreito norte-sul
    ['gapstow', -1395, -421, 0.62, {'vao': 30.0}],
    ['belvedere', -1604, -1849, 0.0, {}],                 # de frente para o Turtle Pond (norte)
    ['boathouse', -1371, -1491, -math.pi / 2, {}],        # de frente para o lago (oeste)
    ['bandshell', -1552, -1188, -1.15, {}],
    ['cleopatra', -1340, -1862, 0.0, {}],
    ['wollman', -1530, -370, 0.0, {}],
    ['carrossel', -1700, -520, 0.0, {}],
    ['imagine', -2045, -1360, 0.0, {}],
    ['delacorte', -1790, -1880, -2.3, {}],
    ['kerbs', -1345, -1404, 0.0, {}],                    # casinha dos barquinhos (Conservatory Water), de frente para a água
    ['alice', -1393, -1394, 0.4, {}],
    ['cherry_fonte', -1770, -1410, 0.0, {}],
    ['estatua', -1636, -772, 0.0, {'quem': 'shakespeare'}],
    ['estatua', -1656, -772, 0.0, {'quem': 'colombo'}],
    ['estatua', -1634, -800, 0.0, {'quem': 'burns'}],
    ['estatua', -1658, -800, 0.0, {'quem': 'scott'}],
    ['beisebol', -2040, -370, 0.6, {}],
    ['beisebol', -1920, -355, -0.4, {}],
    ['beisebol', -2010, -1700, 0.2, {}],
    ['beisebol', -1930, -1830, 3.0, {}],
]
ROCHAS = [(-1930, -425, 16), (-1560, -520, 11), (-1470, -620, 9), (-2020, -1000, 12), (-1880, -1110, 8), (-1360, -1110, 9),
          (-1530, -1730, 10), (-1700, -1720, 12), (-1440, -1740, 8), (-1250, -620, 7), (-1800, -1600, 9), (-2140, -1600, 7),
          (-1460, -880, 8), (-1790, -460, 7)]
VISTA_ROCK = (-1604, -1849)                                # a rocha do castelo (montada junto com ele)

# ---------------------------------------------------------------------------------------------------------------
def suavizar(pts, passo=3.0, fechado=False):
    """Catmull-Rom: pontos a cada ~passo m"""
    p = list(pts)
    if fechado and p[0] != p[-1]:
        p = p + [p[0]]
    out = []
    n = len(p)
    for i in range(n - 1):
        p0 = p[i - 1] if i > 0 else (p[-2] if fechado else p[0])
        p1, p2 = p[i], p[i + 1]
        p3 = p[i + 2] if i + 2 < n else (p[1] if fechado else p[-1])
        seg = math.dist(p1, p2)
        k = max(1, int(seg / passo))
        for j in range(k):
            t = j / k
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            z = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((round(x, 2), round(z, 2)))
    out.append((round(p[-1][0], 2), round(p[-1][1], 2)))
    return out

def dentro_poli(x, z, poli):
    c = False
    j = len(poli) - 1
    for i in range(len(poli)):
        xi, zi = poli[i]
        xj, zj = poli[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            c = not c
        j = i
    return c

# ---------------------------------------------------------------------------------------------------------------
# MÁSCARA (células de CEL m): 0 = mata (pode árvore), 1 = gramado, 2 = praça/caminho/pista, 3 = água, 4 = construção,
#   5 = fora do parque. Vai para o jogo (plantas e capim não nascem em caminho/água/construção) e serve para as árvores.
# ---------------------------------------------------------------------------------------------------------------
CEL = 2.0
X0, X1, Z0, Z1 = -2180.0, -1200.0, -1980.0, -232.0
W = int((X1 - X0) / CEL)
H = int((Z1 - Z0) / CEL)
xs = X0 + (np.arange(W) + 0.5) * CEL
zs = Z0 + (np.arange(H) + 0.5) * CEL
GX, GZ = np.meshgrid(xs, zs)

def mascara_poli(poli):
    poli = np.asarray(poli, dtype=np.float64)
    c = np.zeros(GX.shape, dtype=bool)
    n = len(poli)
    j = n - 1
    for i in range(n):
        xi, zi = poli[i]
        xj, zj = poli[j]
        cond = (zi > GZ) != (zj > GZ)
        with np.errstate(divide='ignore', invalid='ignore'):
            xint = (xj - xi) * (GZ - zi) / (zj - zi) + xi
        c ^= cond & (GX < xint)
        j = i
    return c

def mascara_linha(pts, meia):
    m = np.zeros(GX.shape, dtype=bool)
    for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
        x0, x1 = min(ax, bx) - meia, max(ax, bx) + meia
        z0, z1 = min(az, bz) - meia, max(az, bz) + meia
        c0 = max(0, int((x0 - X0) / CEL)); c1 = min(W, int((x1 - X0) / CEL) + 1)
        r0 = max(0, int((z0 - Z0) / CEL)); r1 = min(H, int((z1 - Z0) / CEL) + 1)
        if c0 >= c1 or r0 >= r1:
            continue
        sx = GX[r0:r1, c0:c1]; sz = GZ[r0:r1, c0:c1]
        dx, dz = bx - ax, bz - az
        l2 = dx * dx + dz * dz
        t = np.clip(((sx - ax) * dx + (sz - az) * dz) / max(l2, 1e-6), 0, 1)
        d2 = (sx - (ax + dx * t)) ** 2 + (sz - (az + dz * t)) ** 2
        m[r0:r1, c0:c1] |= d2 <= meia * meia
    return m

def mascara_disco(cx, cz, r):
    return (GX - cx) ** 2 + (GZ - cz) ** 2 <= r * r

def principal(foto=None):
    rnd = random.Random(1904)
    dentro_parque = np.zeros(GX.shape, dtype=bool)
    for p in PARQUES:
        dentro_parque |= mascara_poli(pares(p))
    masc = np.full(GX.shape, 5, dtype=np.uint8)
    masc[dentro_parque] = 0
    for nome, poli in GRAMADOS.items():
        masc[mascara_poli(poli) & dentro_parque] = 1
    caminhos_s = [suavizar(c, 3.0) for c in CAMINHOS]
    pistas_s = [suavizar(c, 4.0) for c in PISTAS]
    for nome, poli, piso in PRACAS:
        masc[mascara_poli(poli) & dentro_parque] = 2
    for c in caminhos_s:
        masc[mascara_linha(c, 2.0) & dentro_parque] = 2
    for c in pistas_s:
        masc[mascara_linha(c, 4.5) & dentro_parque] = 2
    masc[mascara_linha(MALL, 6.0) & dentro_parque] = 2
    for nome, poli in LAGOS.items():
        masc[mascara_poli(poli)] = 3
    # construções (raio de cada uma, para a máscara)
    RAIO = {'bethesda': 0, 'bow_bridge': 0, 'gapstow': 0, 'belvedere': 30, 'boathouse': 26, 'bandshell': 18, 'cleopatra': 8,
            'wollman': 0, 'carrossel': 14, 'imagine': 0, 'delacorte': 0, 'kerbs': 8, 'alice': 4, 'cherry_fonte': 5, 'estatua': 3,
            'beisebol': 42}
    for e in ESTRUTURAS:
        r = RAIO.get(e[0], 6)
        if r > 0:
            masc[mascara_disco(e[1], e[2], r) & dentro_parque] = np.where(e[0] == 'beisebol', 1, 4)
    masc[(GX > -1662) & (GX < -1538) & (GZ < -1290) & (GZ > -1320) & dentro_parque] = 4   # terraço alto da Bethesda
    for (x, z, r) in ROCHAS:
        masc[mascara_disco(x, z, r * 0.6) & dentro_parque] = 4
    # guaritas (mundo/locais.gd: as duas que já ficavam no parque)
    for gx, gz in [(-1695.5, -740.5), (-1731.5, -1620.5)]:
        masc[(np.abs(GX - gx) < 17) & (np.abs(GZ - gz) < 17) & dentro_parque] = 4
    # ---------- ÁRVORES ----------
    arv = []
    livre = (masc == 0)
    # distância a caminho/água/construção (em células) para não plantar colado
    from scipy.ndimage import distance_transform_edt as dist_edt
    d_obst = dist_edt(~np.isin(masc, [2, 3, 4])) * CEL
    d_gram = dist_edt(masc != 1) * CEL
    ocupado = {}
    def perto(x, z, r):
        cx, cz = int(x // 6), int(z // 6)
        for i in range(cx - 3, cx + 4):
            for j in range(cz - 3, cz + 4):
                for (ox, oz, orr) in ocupado.get((i, j), ()):
                    if (ox - x) ** 2 + (oz - z) ** 2 < (max(r, orr)) ** 2:
                        return True
        return False
    def marcar(x, z, r):
        ocupado.setdefault((int(x // 6), int(z // 6)), []).append((x, z, r))
    # 1) a MALL: 4 fileiras de olmos (a "catedral" de copas)
    (ax, az), (bx, bz) = MALL
    comp = math.dist((ax, az), (bx, bz))
    ux, uz = (bx - ax) / comp, (bz - az) / comp
    lx, lz = -uz, ux
    olmos = ['olmo_1', 'olmo_2', 'olmo_3', 'olmo_4']
    t = 18.0
    while t < comp - 8:
        for lado in (-1, 1):
            for dist_ in (9.0, 16.5):
                x = ax + ux * t + lx * lado * dist_ + rnd.uniform(-0.4, 0.4)
                z = az + uz * t + lz * lado * dist_ + rnd.uniform(-0.4, 0.4)
                # os olmos da Mall são os maiores do parque (as copas se encontram por cima da alameda)
                arv.append([rnd.choice(olmos), round(x, 2), round(z, 2), round(rnd.uniform(0, math.tau), 3), round(rnd.uniform(1.3, 1.5), 3), 1.0])
                marcar(x, z, 7.0)
        t += 9.0
    # 2) MATA: amostragem com distância mínima (mais fechada no Ramble e no Hallett)
    zonas_densas = [('ramble', [(-1760, -1560), (-1480, -1560), (-1440, -1820), (-1780, -1820)]),
                    ('hallett', [(-1470, -420), (-1380, -440), (-1420, -520), (-1500, -520)]),
                    ('north_woods', [(-2175, -1260), (-2120, -1260), (-2120, -1960), (-2175, -1960)])]
    densas = np.zeros(GX.shape, dtype=bool)
    for _, poli in zonas_densas:
        densas |= mascara_poli(poli)
    especies_mata = [('carvalho_p', 5), ('carvalho_m', 10), ('carvalho_m2', 10), ('carvalho_g', 5), ('carvalho_g2', 4),
                     ('freixo_p', 4), ('freixo_m', 9), ('freixo_m2', 9), ('freixo_g', 4), ('olmo_1', 3), ('olmo_2', 2),
                     ('olmo_3', 4), ('olmo_4', 4), ('alamo_p', 4), ('alamo_m', 5), ('alamo_g', 2), ('pinheiro_p', 2),
                     ('pinheiro_m', 3), ('pinheiro_g', 2), ('seca_carvalho', 2), ('seca_carvalho_g', 1), ('seca_freixo', 1),
                     ('seca_olmo', 1), ('seca_alamo', 1)]
    tot = sum(p for _, p in especies_mata)
    def sortear():
        x = rnd.uniform(0, tot)
        for n, p in especies_mata:
            x -= p
            if x <= 0:
                return n
        return especies_mata[0][0]
    cand = np.argwhere(livre)
    rnd.shuffle(cand_l := cand.tolist())
    for (r, c) in cand_l:
        x = X0 + (c + rnd.random()) * CEL
        z = Z0 + (r + rnd.random()) * CEL
        do = d_obst[r, c]
        if do < 3.0:
            continue
        dmin = 6.2 if densas[r, c] else 7.6
        if d_gram[r, c] < 6.0:
            dmin += 2.5                           # na beira dos gramados, mais espaçadas
        if perto(x, z, dmin):
            continue
        nome = sortear()
        s = rnd.uniform(0.8, 1.15)
        tom = rnd.uniform(0.84, 1.08)
        if rnd.random() < 0.08 and not nome.startswith('seca') and not nome.startswith('pinheiro'):
            tom = -tom                            # negativo = outono (o jogo põe o laranja)
        arv.append([nome, round(x, 2), round(z, 2), round(rnd.uniform(0, math.tau), 3), round(s, 3), round(tom, 3)])
        marcar(x, z, dmin)
    # 3) poucas árvores soltas nos gramados (sombra no meio do campo)
    gr = np.argwhere(masc == 1).tolist()
    rnd.shuffle(gr)
    for (r, c) in gr[:4000]:
        if rnd.random() > 0.015:
            continue
        x = X0 + (c + rnd.random()) * CEL
        z = Z0 + (r + rnd.random()) * CEL
        if d_obst[r, c] < 6 or perto(x, z, 22.0):
            continue
        nome = rnd.choice(['carvalho_g', 'carvalho_g2', 'olmo_2', 'freixo_g'])
        arv.append([nome, round(x, 2), round(z, 2), round(rnd.uniform(0, math.tau), 3), round(rnd.uniform(0.95, 1.15), 3), 1.0])
        marcar(x, z, 22.0)
    # ---------- POSTES E BANCOS ao longo dos caminhos ----------
    postes, bancos = [], []
    def ao_longo(pts, passo, lateral, f):
        acum = passo * 0.5
        for (ax_, az_), (bx_, bz_) in zip(pts[:-1], pts[1:]):
            seg = math.dist((ax_, az_), (bx_, bz_))
            if seg < 1e-6:
                continue
            ux_, uz_ = (bx_ - ax_) / seg, (bz_ - az_) / seg
            d = 0.0
            while acum <= seg - d + 1e-9:
                d += acum
                x = ax_ + ux_ * d
                z = az_ + uz_ * d
                f(x, z, ux_, uz_)
                acum = passo
            acum -= (seg - d)
    def dentro_ok(x, z):
        c = int((x - X0) / CEL); r = int((z - Z0) / CEL)
        if not (0 <= c < W and 0 <= r < H):
            return False
        # nem na água, nem fora, nem em cima/colado de construção (escadas, terraços)
        r0, r1, c0, c1 = max(0, r - 2), min(H, r + 3), max(0, c - 2), min(W, c + 3)
        return masc[r, c] not in (3, 5) and not (masc[r0:r1, c0:c1] == 4).any()
    lado_poste = [1]
    def por_poste(x, z, ux_, uz_):
        lado_poste[0] = -lado_poste[0]
        px, pz = x - uz_ * 2.6 * lado_poste[0], z + ux_ * 2.6 * lado_poste[0]
        if dentro_ok(px, pz):
            postes.append([round(px, 2), round(pz, 2)])
    def por_banco(x, z, ux_, uz_):
        if rnd.random() < 0.45:
            return
        lado = rnd.choice((-1, 1))
        bx_, bz_ = x - uz_ * 2.9 * lado, z + ux_ * 2.9 * lado
        if dentro_ok(bx_, bz_):
            giro = math.atan2(-uz_ * lado, ux_ * lado)        # de frente para o caminho
            bancos.append([round(bx_, 2), round(bz_, 2), round(math.atan2(uz_ * lado, -ux_ * lado) + math.pi / 2, 3)])
    for c in caminhos_s:
        ao_longo(c, 30.0, 2.6, por_poste)
        ao_longo(c, 22.0, 2.9, por_banco)
    for c in pistas_s:
        ao_longo(c, 48.0, 5.6, lambda x, z, ux_, uz_: postes.append([round(x - uz_ * 5.6, 2), round(z + ux_ * 5.6, 2)]) if dentro_ok(x - uz_ * 5.6, z + ux_ * 5.6) else None)
    # a Mall: bancos dos dois lados, encostados uns nos outros, e postes a cada 20 m
    t = 12.0
    while t < comp - 6:
        for lado in (-1, 1):
            x = ax + ux * t + lx * lado * 6.6
            z = az + uz * t + lz * lado * 6.6
            bancos.append([round(x, 2), round(z, 2), round(math.atan2(lz * lado, -lx * lado) + math.pi / 2, 3)])
        t += 3.0
    t = 10.0
    while t < comp - 4:
        for lado in (-1, 1):
            postes.append([round(ax + ux * t + lx * lado * 5.4, 2), round(az + uz * t + lz * lado * 5.4, 2)])
        t += 20.0
    # ---------- MURO (contorno, com as entradas onde caminhos/pistas tocam a borda) ----------
    entradas = []
    for c in CAMINHOS + PISTAS:
        for p in (c[0], c[-1]):
            entradas.append(p)
    muros = []
    for poli in PARQUES:
        pts = pares(poli)
        muros.append(pts)
    dados = {
        '_leia': '1.20 · gerado por ferramentas/central_park/desenho.py (não editar à mão: mudar lá e rodar de novo)',
        'parques': [pares(p) for p in PARQUES],
        'lago_antigo': LAGO_ANTIGO,
        'lagos': {k: [[round(x, 2), round(z, 2)] for x, z in v] for k, v in LAGOS.items()},
        'gramados': {k: [[round(x, 2), round(z, 2)] for x, z in v] for k, v in GRAMADOS.items()},
        'pracas': [[n, [[round(x, 2), round(z, 2)] for x, z in p], piso] for n, p, piso in PRACAS],
        'pistas': [[list(p) for p in c] for c in pistas_s],
        'caminhos': [[list(p) for p in c] for c in caminhos_s],
        'mall': [list(p) for p in MALL],
        'estruturas': [[e[0], e[1], e[2], round(e[3], 4), e[4]] for e in ESTRUTURAS],
        'rochas': [list(r) for r in ROCHAS],
        'entradas': [list(p) for p in entradas],
        'muros': [[list(p) for p in m] for m in muros],
        'arvores': arv,
        'postes': postes,
        'bancos': bancos,
        'mascara': {'x0': X0, 'z0': Z0, 'cel': CEL, 'w': W, 'h': H,
                    'dados': ''.join('%d' % v for v in masc.flatten().tolist())},
    }
    saida = os.path.join(RAIZ, 'data', 'central_park.json')
    with open(saida, 'w') as f:
        json.dump(dados, f, separators=(',', ':'), ensure_ascii=False)
    from collections import Counter
    print('árvores:', len(arv), dict(Counter(a[0].split('_')[0] for a in arv)))
    print('postes:', len(postes), 'bancos:', len(bancos), 'tamanho:', os.path.getsize(saida) // 1024, 'KB')
    if foto:
        from PIL import Image, ImageDraw
        cores = {0: (52, 92, 40), 1: (128, 170, 88), 2: (170, 165, 150), 3: (60, 110, 160), 4: (150, 90, 70), 5: (40, 40, 44)}
        img = np.zeros((H, W, 3), dtype=np.uint8)
        for k, cc in cores.items():
            img[masc == k] = cc
        im = Image.fromarray(img).resize((W, H))
        d = ImageDraw.Draw(im)
        for a in arv:
            c = int((a[1] - X0) / CEL); r = int((a[2] - Z0) / CEL)
            d.point((c, r), fill=(20, 50, 15))
        for p in postes:
            d.point((int((p[0] - X0) / CEL), int((p[1] - Z0) / CEL)), fill=(255, 230, 120))
        for e in ESTRUTURAS:
            c = int((e[1] - X0) / CEL); r = int((e[2] - Z0) / CEL)
            d.ellipse((c - 3, r - 3, c + 3, r + 3), outline=(255, 60, 60))
            d.text((c + 4, r - 4), e[0], fill=(255, 255, 255))
        im.save(foto)

if __name__ == '__main__':
    principal(sys.argv[sys.argv.index('--foto') + 1] if '--foto' in sys.argv else None)
