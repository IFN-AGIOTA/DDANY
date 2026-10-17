#!/usr/bin/env python3
# COMPÕE A MÚSICA DA ABERTURA (audio/abertura.ogg), sintetizada aqui (sem amostras baixadas), no clima do teaser:
#   ~76 bpm em ré menor · "relógio" agudo (ré + lá) a cada tempo do começo ao fim · baixo e cordas graves
#   (si bemol, lá, dó, ré, fá, mi, sol) · chimbal crescendo · pausa e PANCADA nos clarões · subida (riser) antes
#   do título · bateria grande no título · e, ao fundo, um RÁDIO (voz de noticiário + alerta de emergência)
#   com chiado, falhas e filtro de radinho, BAIXO, quase sem dar para entender (comunicado sobre a infecção).
# As vozes do rádio vêm de arquivos .wav (texto em inglês, como uma rádio de Nova York), feitos com voz
# sintética: noticiário = Piper TTS (voz LJSpeech, domínio público), alerta = eSpeak NG.
# Uso: python3 compor_abertura.py <pasta_das_vozes> <saida.wav>
#   (depois: ffmpeg -i saida.wav -c:a libvorbis -q:a 4 audio/abertura.ogg)
# Os tempos dos clarões ficam em CLAROES e precisam bater com historia/abertura.gd.
import sys, wave, numpy as np

SR = 44100
DUR = 75.0
BPM = 76.0
BEAT = 60.0 / BPM
T0 = 0.63                                  # primeiro tempo
CLAROES = [15.0, 29.0, 41.0, 47.0, 51.0, 65.0]
RNG = np.random.default_rng(7)
N = int(SR * DUR)
L = np.zeros(N)
R = np.zeros(N)

def hz(nota):                              # "D5", "Bb1", "F#2"...
    nomes = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    n = nomes[nota[0]]
    i = 1
    while nota[i] in "#b":
        n += 1 if nota[i] == "#" else -1
        i += 1
    oit = int(nota[i:])
    return 440.0 * 2 ** ((n + (oit - 4) * 12) / 12.0)

def por(sinal, t, ganho=1.0, pan=0.0):
    i = int(t * SR)
    if i >= N:
        return
    s = sinal[: N - i] * ganho
    L[i:i + len(s)] += s * np.sqrt(0.5 * (1 - pan))
    R[i:i + len(s)] += s * np.sqrt(0.5 * (1 + pan))

def env(n, a, r):
    e = np.ones(n)
    na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return e

def passa_baixa(x, corte):
    k = 1 - np.exp(-2 * np.pi * corte / SR)
    y = np.zeros_like(x); v = 0.0
    for i in range(len(x)):
        v += k * (x[i] - v); y[i] = v
    return y

def lp_rapido(x, corte):                   # passa-baixa por FFT (para sinais longos)
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (f / corte) ** 4)
    return np.fft.irfft(X, len(x))

def faixa(x, lo, hi):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= ((f > lo) & (f < hi)) * 1.0
    return np.fft.irfft(X, len(x))

# ---------- instrumentos ----------
def sino(f, dur=3.0):                      # "relógio": piano/sino agudo, ataque limpo e cauda longa
    t = np.arange(int(dur * SR)) / SR
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t * 1.6) + 0.35 * np.sin(2 * np.pi * f * 2.001 * t) * np.exp(-t * 3.5)
         + 0.12 * np.sin(2 * np.pi * f * 3.98 * t) * np.exp(-t * 7))
    return s * np.minimum(1, t * 600)

def corda_grave(f, dur):                   # cordas graves (serra filtrada, 3 vozes desafinadas)
    t = np.arange(int(dur * SR)) / SR
    s = np.zeros_like(t)
    for d in (1.0, 1.004, 0.996):
        ph = (f * d * t + RNG.random()) % 1.0
        s += 2 * ph - 1
    s = lp_rapido(s, 600)
    return s * env(len(t), 0.8, 1.2) / 3

def sub(f, dur):                           # grave de cinema (seno + 2º harmônico leve), cresce e some
    t = np.arange(int(dur * SR)) / SR
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)
    return s * env(len(t), 0.5, 0.9)

def chimbal(dur=0.09, brilho=1.0):
    n = int(dur * SR)
    x = RNG.standard_normal(n)
    x = np.diff(np.concatenate([[0], x]))
    return x * np.exp(-np.arange(n) / SR * 55) * 0.5 * brilho

def bumbo(dur=1.6, f0=55.0):               # tambor grande (taiko / boom)
    t = np.arange(int(dur * SR)) / SR
    fase = 2 * np.pi * np.cumsum(f0 + 70 * np.exp(-t * 20)) / SR
    s = np.sin(fase) * np.exp(-t * 2.5)
    ruido = passa_baixa(RNG.standard_normal(len(t)) * np.exp(-t * 12), 900)
    return s + ruido * 0.8

def pancada(dur=5.0):                      # impacto dos clarões: boom grave + estrondo metálico + cauda
    t = np.arange(int(dur * SR)) / SR
    boom = np.sin(2 * np.pi * np.cumsum(32 + 90 * np.exp(-t * 6)) / SR) * np.exp(-t * 0.9)
    metal = np.zeros_like(t)
    for f in (173, 241, 389, 517, 733, 1021):
        metal += np.sin(2 * np.pi * f * t + RNG.random() * 6) * np.exp(-t * (1.2 + f / 600))
    ruido = lp_rapido(RNG.standard_normal(len(t)), 2500) * np.exp(-t * 3)
    return boom * 1.2 + metal * 0.12 + ruido * 0.5

def reverso(dur=1.8):                      # chiado subindo antes da pancada
    t = np.arange(int(dur * SR)) / SR
    x = faixa(RNG.standard_normal(len(t)), 1500, 12000)
    return x * (t / dur) ** 3

def riser(t0, dur, f_de, f_para):          # subida antes do título: nota deslizando + ruído abrindo
    t = np.arange(int(dur * SR)) / SR
    f = f_de * (f_para / f_de) ** (t / dur)
    fase = 2 * np.pi * np.cumsum(f) / SR
    s = (np.sin(fase) + 0.5 * np.sin(2 * fase) + 0.3 * np.sin(3 * fase)) * (t / dur) ** 1.5
    ruido = faixa(RNG.standard_normal(len(t)), 800, 9000) * (t / dur) ** 3
    por(s * 0.5, t0, 1.0)
    por(ruido * 0.25, t0, 1.0, -0.3)
    por(ruido * 0.25, t0, 1.0, 0.3)

def tempo(k):
    return T0 + k * BEAT

# ---------- arranjo ----------
# 1) relógio: ré5 + lá5 em todo tempo (o lá um pouco depois, como dedilhado), mais forte no fim
k = 0
while tempo(k) < 73.5:
    t = tempo(k)
    if 28.0 <= t < 29.0:                   # a pausa antes da pancada
        k += 1
        continue
    g = 0.10 if t < 4 else (0.14 if t < 54.3 else 0.2)
    if t > 72.0:
        g *= max(0.0, (73.5 - t) / 1.5)
    por(sino(hz("D5")), t, g, -0.25)
    por(sino(hz("A5")), t + 0.012, g * 0.8, 0.25)
    k += 1

# 2) baixo e cordas graves por compasso (4 tempos)
COMP = 4 * BEAT
progressao = [(1, "Bb"), (2, "A"), (3, "D"), (4, "D"), (5, "Bb"), (6, "Bb"), (7, "F"), (8, "E"),
              (9, "D"), (10, "G"), (11, "Bb"), (12, "Bb"), (13, "F"), (14, "F"),
              (17, "D"), (18, "D"), (19, "E"), (20, "Bb"), (21, "F"), (22, "F")]
terca = {"Bb": "D", "A": "C", "D": "F", "F": "A", "E": "G", "G": "Bb"}
for c, nota in progressao:
    t = T0 + c * COMP
    dur = COMP + 0.6
    if c == 8:
        dur = 28.0 - t                     # corta na pausa
    forte = 1.4 if c >= 17 else 1.0
    por(sub(hz(nota + "1"), dur), t, 0.32 * forte)
    por(corda_grave(hz(nota + "2"), dur), t, 0.22 * forte, -0.2)
    por(corda_grave(hz(terca[nota] + "3"), dur), t, 0.10 * forte, 0.2)
    if c == 2:                             # lá -> dó no meio do compasso (como no teaser)
        por(corda_grave(hz("C3"), dur / 2), t + COMP / 2, 0.12, 0.1)
    if c == 20:                            # si bemol com mi em cima (trítono) = tensão
        por(corda_grave(hz("E3"), dur), t, 0.08, 0.3)

# 3) chimbal: colcheias 22,7 -> 27,6 (crescendo) e no título colcheias + semicolcheias
for i in range(int((27.6 - 22.7) / (BEAT / 2))):
    t = 22.7 + i * BEAT / 2
    por(chimbal(), t, 0.05 + 0.08 * i / 12, 0.4)
t = T0 + 17 * COMP
i = 0
while t < 72.5:
    sem = t > 63.8
    por(chimbal(brilho=1.0 if i % 2 == 0 else 0.6), t, 0.12, 0.4 if i % 2 else -0.3)
    t += BEAT / (4 if sem else 2)
    i += 1

# 4) bateria grande no título (54,3 ->): bumbo nos tempos 1 e 3, caixa grave no 2 e 4
k = 0
t = T0 + 17 * COMP
while t < 72.5:
    if k % 4 in (0, 2):
        por(bumbo(), t, 0.55)
    else:
        caixa = bumbo(0.8, 110.0) * 0.6
        ch = chimbal(0.25, 2.0)
        caixa[: len(ch)] += ch
        por(caixa, t, 0.35)
    k += 1
    t += BEAT

# 5) pancadas nos clarões (com o chiado ao contrário antes) e a subida antes do título
for c in CLAROES:
    por(reverso(), c - 1.8, 0.18)
    por(pancada(), c, 0.55, 0.0)
riser(T0 + 15 * COMP, 2 * COMP, hz("F#2"), hz("G#3"))
# um silêncio de verdade na pausa
i0, i1 = int(28.0 * SR), int(28.9 * SR)
L[i0:i1] *= np.linspace(1, 0.05, i1 - i0)
R[i0:i1] *= np.linspace(1, 0.05, i1 - i0)

# ---------- rádio ao fundo ----------
def ler_wav(caminho):
    w = wave.open(caminho)
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768
    if w.getnchannels() == 2:
        x = x[::2]
    sr = w.getframerate()
    n2 = int(len(x) * SR / sr)
    return np.interp(np.linspace(0, len(x) - 1, n2), np.arange(len(x)), x)

def radinho(x):
    x = faixa(x, 450, 2400)
    x = np.tanh(x * 3.0) / np.tanh(3.0)                     # alto-falante saturado
    t = np.arange(len(x)) / SR
    x *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.7 * t + RNG.random() * 6)   # sinal oscilando
    for _ in range(int(len(x) / SR / 2.5)):                 # falhas curtas do sinal
        i = RNG.integers(0, len(x)); n = int(RNG.uniform(0.04, 0.18) * SR)
        x[i:i + n] *= 0.15
    chiado = faixa(RNG.standard_normal(len(x)), 1200, 4000) * 0.03
    estalos = (RNG.random(len(x)) < 0.0004) * RNG.standard_normal(len(x)) * 0.3
    return lp_rapido(x + chiado + estalos, 3800)

pasta = sys.argv[1]
falas = [("anc_1.wav", 4.2), ("anc_2.wav", 12.6), ("anc_3.wav", 20.3), ("anc_4.wav", 30.4), ("anc_5.wav", 36.6),
         ("eas.wav", 41.6)]
radio = np.zeros(N)
for arq, t in falas:
    v = radinho(ler_wav(pasta + "/" + arq))
    i = int(t * SR)
    v = v[: N - i]
    radio[i:i + len(v)] += v * (0.7 if arq == "eas.wav" else 1.0)
# sintonia: chiado de rádio procurando estação no começo e entre as falas
t = np.arange(N) / SR
sint = faixa(RNG.standard_normal(N), 900, 3500) * 0.02 * np.clip((t - 3.0) / 1.5, 0, 1) * (t < 60.0)
sint *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.23 * t)
radio += sint
radio *= np.clip((60.0 - t) / 4.0, 0, 1)                    # o rádio some antes do título
por(radio, 0.0, 0.085, -0.15)   # bem baixo: quase não dá para entender (como no teaser)
por(radio, 0.0, 0.05, 0.25)

# ---------- reverb simples, volume e saída ----------
def reverb(x):
    y = np.zeros_like(x)
    for atraso, g in ((1931, 0.82), (2111, 0.8), (2333, 0.78), (2551, 0.76)):
        b = np.zeros_like(x)
        b[atraso:] = x[:-atraso]
        # pente com realimentação por blocos (aproximação barata)
        acc = b.copy()
        for k in range(1, 8):
            d = atraso * k
            if d >= len(x):
                break
            acc[d:] += x[:-d] * g ** k
        y += acc
    return lp_rapido(y, 5000) * 0.12

L2 = L + reverb(L)
R2 = R + reverb(R)
fade = np.clip((DUR - t) / 1.5, 0, 1) * np.clip(t / 0.4, 0, 1)
L2 *= fade; R2 *= fade
pico = max(np.abs(L2).max(), np.abs(R2).max())
L2 *= 0.89 / pico; R2 *= 0.89 / pico
saida = np.stack([L2, R2], 1)
w = wave.open(sys.argv[2], "wb")
w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((saida * 32767).astype(np.int16).tobytes())
w.close()
print("ok", sys.argv[2], round(DUR, 1), "s")
