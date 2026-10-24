#!/usr/bin/env python3
# PREPARAR SONS (0.49): pega os pacotes baixados (licença livre, ver audio/sons/LICENCA.txt) e gera os .ogg do jogo
# em audio/sons/: corta, tira o silêncio, iguala o volume (pico -1 dB), mono, e alguns sons são MONTADOS aqui
# (entrada da partida, morte, respiração, gole, cápsula caindo). NÃO roda dentro do jogo.
# Uso: python3 ferramentas/preparar_sons.py <pasta com os downloads>
#   (a pasta tem: kenney_interface-sounds/, kenney_ui-audio/, kenney_rpg-audio/, kenney_impact-sounds/,
#    oga/ (OpenGameArt) e fa/Prepared SFX Library/ (The Free Firearm Sound Library))
# Depois abra o projeto na Godot (ou rode godot --headless --import) para importar os .ogg novos.
import os, subprocess, sys
import numpy as np

TAXA = 44100
DL = sys.argv[1]
SAIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "sons")
KI = os.path.join(DL, "kenney_interface-sounds", "Audio")
KU = os.path.join(DL, "kenney_ui-audio", "Audio")
KR = os.path.join(DL, "kenney_rpg-audio", "Audio")
KM = os.path.join(DL, "kenney_impact-sounds", "Audio")
OGA = os.path.join(DL, "oga")
FA = os.path.join(DL, "fa", "Prepared SFX Library")
rng = np.random.default_rng(49)
feitos = []


def ler(arq, filtro=None):
    cmd = ["ffmpeg", "-v", "error", "-i", arq]
    if filtro:
        cmd += ["-af", filtro]
    cmd += ["-ac", "1", "-ar", str(TAXA), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, dtype=np.float32).copy()


def aparar(x, limiar=0.02, folga=0.004):
    # tira o silêncio do começo e do fim
    a = np.abs(x)
    pk = a.max() if len(a) else 0.0
    if pk <= 0:
        return x
    idx = np.where(a > pk * limiar)[0]
    i0 = max(0, idx[0] - int(folga * TAXA))
    i1 = min(len(x), idx[-1] + int(0.03 * TAXA))
    return x[i0:i1]


def fade(x, ent=0.002, sai=0.05):
    x = x.copy()
    n1 = min(len(x), int(ent * TAXA))
    n2 = min(len(x), int(sai * TAXA))
    if n1 > 0:
        x[:n1] *= np.linspace(0, 1, n1)
    if n2 > 0:
        x[-n2:] *= np.linspace(1, 0, n2) ** 2
    return x


def gravar(nome, x, pico_db=-1.0, q=4, loop=False):
    x = np.asarray(x, dtype=np.float32)
    x = x - np.mean(x) if loop else x
    pk = np.abs(x).max()
    if pk > 0:
        x = x / pk * (10 ** (pico_db / 20))
    arq = os.path.join(SAIDA, nome + ".ogg")
    os.makedirs(os.path.dirname(arq), exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(TAXA), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), arq], input=x.tobytes(), check=True)
    feitos.append(nome)


def corte(x, t0, t1):
    return x[int(t0 * TAXA):int(t1 * TAXA)]


def grupo(nome, arquivos, filtro=None, **kw):
    for i, a in enumerate(arquivos):
        gravar("%s_%d" % (nome, i), fade(aparar(ler(a, filtro))), **kw)


def loop_cruzado(x, cruz=1.0):
    # emenda o fim no começo (loop sem "clique"): os últimos "cruz" s viram a entrada
    n = int(cruz * TAXA)
    corpo = x[:-n].copy()
    rampa = np.linspace(0, 1, n)
    corpo[:n] = corpo[:n] * rampa + x[-n:] * (1 - rampa)
    return corpo


# ---------------------------------------------------------------- TIROS (The Free Firearm Sound Library, CC0)
def tiro(arq, t, dur=1.5, filtro=None, forca=3.2):
    x = ler(os.path.join(FA, arq), filtro)
    s = corte(x, max(0.0, t - 0.012), t + dur)
    # limitador suave: o estalo da gravação é muito mais alto que o "corpo" do tiro; sem isso o tiro soa fraco
    # perto dos outros sons (o pico manda no volume). tanh aperta o pico e sobe o corpo e o eco.
    s = np.tanh(s / (np.abs(s).max() + 1e-9) * forca) / np.tanh(forca)
    return fade(s, 0.001, dur * 0.45)


TIROS = {  # arma: ([(arquivo perto, início do tiro)...], [(arquivo meia distância, início)...], duração)
    "pistola": ([("1911/A_42P.wav", 0.94), ("1911/A_42P.wav", 5.01), ("Walther PPQ/X_39P.wav", 1.41),
                 ("Walther PPQ/X_39P.wav", 6.45)], [("1911/A_34P.wav", 1.54), ("Walther PPQ/X_31P.wav", 1.08)], 1.3),
    "m4": ([("AR-15/D_32P.wav", 0.7), ("AR-15/D_32P.wav", 5.66)], [("AR-15/D_24P.wav", 0.55), ("AR-15/D_24P.wav", 3.91)], 1.2),
    "ak": ([("AK-47/C_28P.wav", 0.61), ("AK-47/C_28P.wav", 3.26), ("AK-47/C_28P.wav", 6.03), ("AK-47/C_28P.wav", 9.17)],
           [("AK-47/C_34P.wav", 0.74), ("AK-47/C_34P.wav", 5.18)], 1.2),
    "espingarda": ([("Nova/O_21P.wav", 0.43), ("Nova/O_21P.wav", 3.47), ("Mossberg/N_30P.wav", 1.7)],
                   [("Nova/O_17P.wav", 0.69), ("Mossberg/N_26P.wav", 0.78)], 1.7),
    "rifle_caca": ([("Tikka/W_29P.wav", 0.57), ("Tikka/W_29P.wav", 5.67), ("Savage 10 .300 Blackout/T_27P.wav", 0.95)],
                   [("Tikka/W_24P.wav", 0.75), ("Savage 10 .300 Blackout/T_17P.wav", 0.86)], 1.8),
}
for arma, (perto, meio, dur) in TIROS.items():
    for i, (a, t) in enumerate(perto):
        gravar("armas/tiro_%s_%d" % (arma, i), tiro(a, t, dur))
    # de longe: gravação de meia distância, sem os agudos (o ar "come" os agudos) e com mais cauda
    for i, (a, t) in enumerate(meio):
        gravar("armas/longe_%s_%d" % (arma, i), tiro(a, t, dur + 0.8, "lowpass=f=1400,lowpass=f=2200"), pico_db=-3.0)
# silenciado: .22 (Ruger Mark III) abafado, sem o estalo agudo e com pouca cauda
for i, t in enumerate([0.48, 4.49]):
    x = tiro("Ruger Mark III/R_35P.wav", t, 0.45, "highpass=f=380,lowpass=f=2600,acompressor=threshold=0.1:ratio=6")
    gravar("armas/tiro_silenciado_%d" % i, x, pico_db=-4.0)

# ---------------------------------------------------------------- RECARGAS (OpenGameArt, CC0)
rel = ler(os.path.join(OGA, "reload.wav"))                     # pistola (zer0_sol)
for nome, a, b in [("sai", 0.0, 0.6), ("entra", 0.6, 1.05), ("ferrolho", 1.05, 1.59)]:
    gravar("armas/pistola_%s" % nome, fade(aparar(corte(rel, a, b))))
rf = ler(os.path.join(OGA, "assaultriflereload1_0.wav"))       # fuzil (SpringySpringo)
for nome, a, b in [("sai", 0.0, 0.5), ("entra", 0.5, 1.0), ("ferrolho", 1.0, 1.56)]:
    gravar("armas/fuzil_%s" % nome, fade(aparar(corte(rf, a, b))))
sg = ler(os.path.join(OGA, "z/shotgun/ShotgunSounds/4 Shell Reload.mp3"))   # espingarda (zer0_sol)
for i, t in enumerate([0.1, 1.15, 2.21, 3.26]):
    gravar("armas/cartucho_espingarda_%d" % i, fade(aparar(corte(sg, t - 0.04, t + 0.8))))
gravar("armas/bombear_0", fade(aparar(ler(os.path.join(OGA, "shotguncock_0.wav")))))
gravar("armas/bombear_1", fade(aparar(ler(os.path.join(OGA, "z/shotgun/ShotgunSounds/Rack.mp3")))))
eq = ler(os.path.join(OGA, "equipment_clicks3.wav"))           # ferrolho de rifle (LFA, gravado de um rifle)
for i, t in enumerate([0.21, 0.88, 2.19, 2.86]):
    gravar("armas/ferrolho_rifle_%d" % i, fade(aparar(corte(eq, t - 0.03, t + 0.5))))
for i, t in enumerate([7.23, 9.65, 12.16]):                    # gatilho em seco
    gravar("armas/seco_%d" % i, fade(aparar(corte(eq, t - 0.01, t + 0.16)), 0.001, 0.05), pico_db=-4.0)
grupo("armas/bala_pente", [os.path.join(OGA, f) for f in ["singlebullet1.wav", "clipload1.wav", "clipload2.wav"]])
# sacar/guardar arma: couro e metal (Kenney RPG Audio)
grupo("armas/sacar", [os.path.join(KR, f) for f in ["metalClick.ogg", "metalLatch.ogg", "beltHandle1.ogg", "beltHandle2.ogg"]])
grupo("armas/sacar_faca", [os.path.join(KR, f) for f in ["drawKnife1.ogg", "drawKnife2.ogg", "drawKnife3.ogg"]])


# cápsula caindo no chão: metal leve da Kenney, bem mais agudo (latão pequeno) e com quiques
def capsula(arq, quiques):
    base = aparar(ler(os.path.join(KM, arq), "asetrate=%d,aresample=%d,highpass=f=1800" % (TAXA * 2, TAXA)))
    base = fade(base[:int(0.12 * TAXA)], 0.001, 0.05)
    out = np.zeros(int(0.7 * TAXA), dtype=np.float32)
    for t, g in quiques:
        i = int(t * TAXA)
        n = min(len(base), len(out) - i)
        out[i:i + n] += base[:n] * g
    return aparar(out)


for i, a in enumerate(["impactMetal_light_000.ogg", "impactMetal_light_002.ogg", "impactMetal_light_004.ogg"]):
    gravar("armas/capsula_%d" % i, capsula(a, [(0.0, 1.0), (0.11 + 0.02 * i, 0.45), (0.19 + 0.03 * i, 0.2)]), pico_db=-6.0)

# ---------------------------------------------------------------- IMPACTOS DE BALA (Kenney Impact Sounds)
grupo("impactos/bala_terra", [os.path.join(KM, "impactSoft_medium_%03d.ogg" % i) for i in range(5)], "highpass=f=200")
grupo("impactos/bala_metal", [os.path.join(KM, "impactMetal_light_%03d.ogg" % i) for i in range(5)])
grupo("impactos/bala_madeira", [os.path.join(KM, "impactWood_light_%03d.ogg" % i) for i in range(5)])
grupo("impactos/bala_carne", [os.path.join(KM, "impactPunch_medium_%03d.ogg" % i) for i in range(5)], "lowpass=f=2500")
grupo("impactos/vidro", [os.path.join(KM, "impactGlass_heavy_%03d.ogg" % i) for i in range(5)])


# água: "plop" montado (ruído filtrado + bolhas)
def agua(sem):
    r = np.random.default_rng(sem)
    n = int(0.35 * TAXA)
    t = np.arange(n) / TAXA
    ruido = r.standard_normal(n).astype(np.float32)
    k = 0.2
    lp = np.zeros(n, dtype=np.float32)
    for i in range(1, n):
        lp[i] = lp[i - 1] + (ruido[i] - lp[i - 1]) * k
    corpo = lp * np.exp(-t * 14.0)
    bolha = sum(np.sin(2 * np.pi * (500 + 900 * r.random()) * (t - d) * (1 + 3 * (t - d))) * np.exp(-(t - d) * 40) * (t > d)
                for d in r.random(4) * 0.18)
    return fade(corpo * 1.5 + bolha * 0.25, 0.001, 0.08)


for i in range(3):
    gravar("impactos/bala_agua_%d" % i, agua(10 + i))

# ---------------------------------------------------------------- MENU / INTERFACE (Kenney Interface Sounds e UI Audio)
grupo("ui/clique", [os.path.join(KU, "click%d.ogg" % i) for i in range(1, 6)], pico_db=-6.0)
grupo("ui/voltar", [os.path.join(KI, "back_%03d.ogg" % i) for i in range(1, 5)], pico_db=-6.0)
grupo("ui/abrir", [os.path.join(KI, "maximize_%03d.ogg" % i) for i in (1, 3, 6)], pico_db=-6.0)
grupo("ui/fechar", [os.path.join(KI, "minimize_%03d.ogg" % i) for i in (1, 3, 6)], pico_db=-6.0)
grupo("ui/alternar", [os.path.join(KI, "toggle_%03d.ogg" % i) for i in range(1, 5)], pico_db=-6.0)
grupo("ui/aba", [os.path.join(KI, "select_%03d.ogg" % i) for i in (1, 2, 5)], pico_db=-6.0)
grupo("ui/tique", [os.path.join(KI, "tick_%03d.ogg" % i) for i in (1, 2, 4)], pico_db=-8.0)
grupo("ui/confirmar", [os.path.join(KI, "confirmation_%03d.ogg" % i) for i in (1, 2)], pico_db=-5.0)
grupo("ui/erro", [os.path.join(KI, "error_%03d.ogg" % i) for i in (4, 6)], pico_db=-6.0)
grupo("ui/aviso", [os.path.join(KI, "bong_001.ogg"), os.path.join(KI, "question_001.ogg")], pico_db=-7.0)

# ---------------------------------------------------------------- INVENTÁRIO E CORPO (Kenney RPG Audio, OGA)
grupo("inventario/mochila", [os.path.join(KR, "cloth%d.ogg" % i) for i in range(1, 5)])
grupo("inventario/pegar", [os.path.join(KR, f) for f in ["handleSmallLeather.ogg", "handleSmallLeather2.ogg", "clothBelt.ogg"]])
grupo("inventario/largar", [os.path.join(KR, "dropLeather.ogg"), os.path.join(KR, "bookPlace1.ogg"), os.path.join(KR, "bookPlace3.ogg")])
grupo("inventario/vestir", [os.path.join(KR, f) for f in ["clothBelt.ogg", "clothBelt2.ogg", "cloth3.ogg"]])
grupo("inventario/comer", [os.path.join(OGA, "z/crunch/crunch.%d.ogg" % i) for i in (2, 3, 4, 5, 7)])
grupo("inventario/atadura", [os.path.join(KR, f) for f in ["cloth1.ogg", "cloth2.ogg"]], "asetrate=%d,aresample=%d" % (int(TAXA * 1.35), TAXA))


# gole: "glug" montado (pulso grave com bolha subindo), 3 goles por som
def gole(sem):
    r = np.random.default_rng(sem)
    n = int(0.9 * TAXA)
    t = np.arange(n) / TAXA
    out = np.zeros(n, dtype=np.float32)
    for k in range(3):
        d = 0.05 + k * 0.27 + r.random() * 0.03
        tt = t - d
        m = tt > 0
        f = 180 + 120 * r.random()
        env = np.exp(-tt * 18) * m
        out += (np.sin(2 * np.pi * f * tt * (1 + 2.5 * tt)) * env).astype(np.float32)
        out += (r.standard_normal(n) * 0.08 * np.exp(-tt * 30) * m).astype(np.float32)
    return fade(out, 0.002, 0.1)


for i in range(3):
    gravar("inventario/beber_%d" % i, gole(30 + i))

grupo("jogador/passo_grama", [os.path.join(KM, "footstep_grass_%03d.ogg" % i) for i in range(5)])
grupo("jogador/passo_madeira", [os.path.join(KM, "footstep_wood_%03d.ogg" % i) for i in range(5)])
grupo("jogador/passo_concreto", [os.path.join(KM, "footstep_concrete_%03d.ogg" % i) for i in range(5)])
grupo("jogador/aterrissar", [os.path.join(KM, "impactSoft_heavy_%03d.ogg" % i) for i in range(3)], "lowpass=f=1800")
grupo("jogador/pulo", [os.path.join(KR, f) for f in ["cloth2.ogg", "cloth4.ogg"]])
for nome, arq in [("coracao_lento", "heartbeat_slow_0.wav"), ("coracao_rapido", "heartbeat_fast_0.wav")]:
    gravar("jogador/" + nome, ler(os.path.join(OGA, arq)), loop=True)        # inteiro: o ritmo do laço fica certo


# respiração cansada: inspira/expira (ruído com formante de "h"), em loop de 2 respirações
def respiracao(sem, ritmo):
    r = np.random.default_rng(sem)
    n = int(ritmo * 2 * TAXA)
    t = np.arange(n) / TAXA
    ruido = r.standard_normal(n).astype(np.float32)
    # filtro passa-faixa simples (duas passa-baixas) ~ 500-2000 Hz
    a1, a2 = 0.25, 0.06
    lp1 = np.zeros(n, dtype=np.float32)
    lp2 = np.zeros(n, dtype=np.float32)
    for i in range(1, n):
        lp1[i] = lp1[i - 1] + (ruido[i] - lp1[i - 1]) * a1
        lp2[i] = lp2[i - 1] + (ruido[i] - lp2[i - 1]) * a2
    banda = lp1 - lp2
    fase = (t % ritmo) / ritmo
    insp = np.where(fase < 0.4, np.sin(np.pi * fase / 0.4), 0.0) * 0.55
    exp_ = np.where(fase >= 0.42, np.sin(np.pi * (fase - 0.42) / 0.5).clip(0) ** 0.7, 0.0)
    return banda * (insp + exp_)


gravar("jogador/respiracao_0", respiracao(5, 0.95), loop=True)

# ---------------------------------------------------------------- MUNDO (portas, fogo, vento, pássaros, grilos)
grupo("mundo/porta_abrir", [os.path.join(KR, f) for f in ["doorOpen_1.ogg", "doorOpen_2.ogg"]])
grupo("mundo/porta_fechar", [os.path.join(KR, "doorClose_%d.ogg" % i) for i in range(1, 5)])
grupo("mundo/rangido", [os.path.join(KR, "creak%d.ogg" % i) for i in range(1, 4)], pico_db=-4.0)
fogo = ler(os.path.join(OGA, "fire-1.wav"))
fogo2 = np.concatenate([fogo, fogo[::-1] * 0.9, fogo])                # mais longo (a repetição some)
gravar("mundo/fogo", loop_cruzado(fogo2, 0.6), loop=True)
gravar("mundo/vento", loop_cruzado(ler(os.path.join(OGA, "wind woosh loop.ogg")), 1.0), loop=True, q=2)
passaros = ler(os.path.join(OGA, "Birds and Wind - Ambient_1.ogg"))
gravar("mundo/passaros", loop_cruzado(passaros[:int(40 * TAXA)], 2.0), loop=True, q=2)
gravar("mundo/grilos", loop_cruzado(ler(os.path.join(OGA, "crickets_1.mp3")), 1.0), loop=True, q=2)


# ---------------------------------------------------------------- PARTIDA (montados)
def boom(dur, f0, f1, sem):
    r = np.random.default_rng(sem)
    n = int(dur * TAXA)
    t = np.arange(n) / TAXA
    f = f0 * (f1 / f0) ** (t / dur)
    fase = np.cumsum(f) / TAXA
    corpo = np.sin(2 * np.pi * fase) * np.exp(-t * 2.2)
    ruido = r.standard_normal(n)
    lp = np.zeros(n)
    for i in range(1, n):
        lp[i] = lp[i - 1] + (ruido[i] - lp[i - 1]) * 0.02
    return (corpo + lp * 6.0 * np.exp(-t * 5.0)).astype(np.float32)


def eco(x, atraso=0.23, ganho=0.35, vezes=4):
    out = np.concatenate([x, np.zeros(int(atraso * vezes * TAXA), dtype=np.float32)])
    for k in range(1, vezes + 1):
        i = int(atraso * k * TAXA)
        out[i:i + len(x)] += x * (ganho ** k)
    return out


# ENTRADA DA PARTIDA: subida (ruído ao contrário) -> PANCADA grave + metal + eco da cidade -> coração
sino = aparar(ler(os.path.join(KM, "impactBell_heavy_000.ogg"), "asetrate=%d,aresample=%d" % (int(TAXA * 0.5), TAXA)))
tiro_cauda = ler(os.path.join(FA, "AK-47/C_36P.wav"), "lowpass=f=900")[int(0.63 * TAXA):int(2.6 * TAXA)]
sub = (tiro_cauda[::-1] * np.linspace(0, 1, len(tiro_cauda)) ** 2).astype(np.float32)   # tiro ao contrário = "sucção"
pancada = boom(2.6, 70, 32, 3)
entrada = np.zeros(int(5.2 * TAXA), dtype=np.float32)
entrada[:len(sub)] += sub * 0.9
i = len(sub)
entrada[i:i + len(pancada)] += pancada * 0.9
entrada[i:i + len(sino)] += sino[:len(entrada) - i] * 0.35
coracao = aparar(ler(os.path.join(OGA, "heartbeat_slow_0.wav")), 0.005)
j = i + int(1.7 * TAXA)
n = min(len(coracao), len(entrada) - j)
entrada[j:j + n] += coracao[:n] * 0.5
gravar("partida/entrada", fade(eco(entrada, 0.31, 0.25, 3), 0.01, 1.2))
# MORTE: pancada mais grave + coração parando
morte = np.zeros(int(4.0 * TAXA), dtype=np.float32)
pm = boom(3.0, 55, 25, 9)
morte[:len(pm)] += pm
cf = aparar(ler(os.path.join(OGA, "heartbeat_slow_0.wav"), "asetrate=%d,aresample=%d" % (int(TAXA * 0.85), TAXA)), 0.005)
for k, g in enumerate([0.7, 0.45, 0.25]):
    i = int((0.4 + k * 1.05) * TAXA)
    n = min(len(cf), len(morte) - i)
    morte[i:i + n] += cf[:n] * g
gravar("partida/morte", fade(morte, 0.005, 0.8))
# MISSÃO / OBJETIVO: confirmação curta e grave (sem ser "festa")
grupo("partida/objetivo", [os.path.join(KI, "confirmation_003.ogg"), os.path.join(KI, "confirmation_004.ogg")],
      "asetrate=%d,aresample=%d" % (int(TAXA * 0.8), TAXA), pico_db=-5.0)

print("%d sons gerados em %s" % (len(feitos), os.path.normpath(SAIDA)))
