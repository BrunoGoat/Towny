# Los sonidos de la fiesta del valle completo (ver lib/fx/fiesta.dart).
#
#   python3 tool/make_fiesta_sfx.py
#
# Aparte de make_sfx.py para poder rehacer éstos sin tocar los demás. Todo
# sale de semillas fijas: correrlo dos veces da los mismos archivos.
#
# Cuando se elija una fiesta, los sonidos de las otras sobran y se borran.
import os
import struct
import wave

import numpy as np

SR = 22050
OUT = 'assets/sfx'
os.makedirs(OUT, exist_ok=True)


def write(name, x, peak=0.89):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    # Un fundido de cinco milésimas en cada punta: un corte seco suena a clic.
    k = min(len(x) // 2, int(0.005 * SR))
    if k > 0:
        x[:k] *= np.linspace(0, 1, k)
        x[-k:] *= np.linspace(1, 0, k)
    data = (np.clip(x, -1, 1) * 32767).astype('<i2').tobytes()
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(name, round(len(x) / SR, 2), 's')


def T(dur):
    return np.arange(int(dur * SR)) / SR


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    prev = 0.0
    for i, s in enumerate(x):
        prev = (1 - a) * s + a * prev
        y[i] = prev
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def at(out, t0, sig, amp=1.0):
    i0 = int(t0 * SR)
    n = min(len(sig), len(out) - i0)
    if n > 0:
        out[i0:i0 + n] += sig[:n] * amp


# ------------------------------------------------------------------ campanas
#
# Campana de iglesia y no campanita: los parciales de una campana de verdad
# no son armónicos —el zumbido una octava abajo, la tercera menor, la quinta,
# el nominal— y es eso lo que hace que suene a bronce y no a teclado.
BELL = [(0.5, 0.55, 1.0), (1.0, 1.0, 0.75), (1.19, 0.42, 0.55),
        (1.5, 0.30, 0.45), (2.0, 0.38, 0.35), (2.52, 0.16, 0.22),
        (3.0, 0.10, 0.16)]


def bell(f, dur=2.2, bright=1.0):
    t = T(dur)
    x = np.zeros_like(t)
    for ratio, amp, dec in BELL:
        a = amp * (bright if ratio > 1.5 else 1.0)
        # Un batido mínimo en cada parcial: el bronce no es perfecto.
        beat = 1 + 0.04 * np.sin(2 * np.pi * (0.7 + ratio) * t)
        x += a * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (dec * 2.0)) * beat
    strike = np.random.default_rng(int(f)).uniform(-1, 1, len(t))
    x += lowpass(strike, 3000) * np.exp(-t / 0.006) * 0.5
    return x


# Una por pueblo, bajando por una pentatónica: con cualquier cantidad de
# pueblos, cualquier par suena bien.
BELLS = [784.0, 659.3, 587.3, 523.3, 440.0, 392.0, 329.6, 293.7]

# --------------------------------------------------------------------- notas
#
# Celesta: lo del hilo y la constelación. Más claras y más cortas que las
# campanas, subiendo.
NOTAS = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0, 2349.3, 2637.0]


def celesta(f, dur=1.1, amp=1.0):
    t = T(dur)
    x = (np.sin(2 * np.pi * f * t) + 0.28 * np.sin(2 * np.pi * 2 * f * t)
         + 0.08 * np.sin(2 * np.pi * 4.07 * f * t) * np.exp(-t / 0.05))
    return x * np.exp(-t / 0.42) * np.minimum(1, t / 0.003) * amp


def flauta(f, dur, amp=1.0, seed=0):
    """Un pito de caña: seno con su segundo armónico, vibrato y aire."""
    t = T(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.15)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    aire = lowpass(np.random.default_rng(seed).uniform(-1, 1, len(t)), 2500)
    x += aire * 0.18
    env = np.minimum(1, t / 0.025) * np.minimum(1, (dur - t) / 0.04)
    return x * np.clip(env, 0, 1) * amp


def tambor(dur=0.35, f=95, amp=1.0, seed=1):
    t = T(dur)
    cuerpo = np.sin(2 * np.pi * f * t * (1 + 0.5 * np.exp(-t / 0.03))) * np.exp(-t / 0.11)
    parche = lowpass(np.random.default_rng(seed).uniform(-1, 1, len(t)), 1800) * np.exp(-t / 0.035)
    return (cuerpo + parche * 0.6) * amp


def pad(freqs, dur, attack, release, amp=1.0, shimmer=0.0):
    t = T(dur)
    x = np.zeros_like(t)
    for k, f in enumerate(freqs):
        det = 1 + 0.0025 * np.sin(2 * np.pi * (0.13 + 0.07 * k) * t)
        ph = 2 * np.pi * f * np.cumsum(det) / SR
        x += (np.sin(ph) + 0.25 * np.sin(2 * ph)) / len(freqs)
    if shimmer:
        x += shimmer * np.sin(2 * np.pi * freqs[-1] * 4 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.9 * t))
    env = np.minimum(1, t / attack) * np.clip((dur - t) / release, 0, 1)
    return x * env * amp


def main():
    for i, f in enumerate(BELLS):
        write(f'fiesta_campana{i}', bell(f, 2.0), peak=0.8)

    # Todas juntas: el final de las campanadas y del hilo.
    o = np.zeros(int(3.0 * SR))
    for k, f in enumerate([392.0, 523.3, 659.3, 784.0]):
        at(o, 0.03 * k, bell(f, 2.9, bright=0.8), 1.0 - 0.1 * k)
    write('fiesta_campanas', o)

    for i, f in enumerate(NOTAS):
        write(f'fiesta_nota{i}', celesta(f), peak=0.7)

    # La cuenta: madera contra madera, chiquito.
    t = T(0.12)
    ruido = np.random.default_rng(5).uniform(-1, 1, len(t))
    clic = (np.sin(2 * np.pi * 1900 * t) * np.exp(-t / 0.012)
            + np.sin(2 * np.pi * 1150 * t) * np.exp(-t / 0.02) * 0.7
            + lowpass(ruido, 4000) * np.exp(-t / 0.004) * 0.8)
    write('fiesta_cuenta', clic, peak=0.6)

    # Y cuando se juntan: dos notas de vidrio.
    o = np.zeros(int(1.6 * SR))
    at(o, 0.0, celesta(1568.0, 1.5))
    at(o, 0.09, celesta(2093.0, 1.5), 0.8)
    write('fiesta_cuenta_fin', o, peak=0.55)

    # La luz: un acorde que entra despacio y se va del todo a los cinco
    # segundos y medio, con un brillo arriba.
    write('fiesta_luz', pad([293.7, 370.0, 440.0, 587.3], 5.5, 1.6, 2.4,
                            shimmer=0.12), peak=0.5)

    # El sello: un golpe sordo sobre papel, con el lacre aplastándose.
    t = T(0.7)
    golpe = (np.sin(2 * np.pi * 72 * t) * np.exp(-t / 0.09)
             + np.sin(2 * np.pi * 118 * t) * np.exp(-t / 0.06) * 0.6)
    papel = lowpass(np.random.default_rng(9).uniform(-1, 1, len(t)), 1400)
    golpe += papel * np.exp(-t / 0.03) * 0.9
    golpe += lowpass(np.random.default_rng(10).uniform(-1, 1, len(t)), 700) * np.exp(-((t - 0.05) / 0.08) ** 2) * 0.25
    write('fiesta_sello', golpe, peak=0.85)

    # El pasacalle: pito y tamboril, en re mayor, a 132.
    negra = 60 / 132
    mel = [  # (nota en semitonos sobre re, duración en negras)
        (7, .5), (9, .5), (11, 1), (9, .5), (7, .5), (4, 1),
        (7, .5), (9, .5), (11, .5), (12, .5), (14, 1.5), (None, .5),
        (14, .5), (12, .5), (11, 1), (9, .5), (7, .5), (9, 1),
        (11, .5), (9, .5), (7, .5), (4, .5), (7, 1.5),
    ]
    total = sum(d for _, d in mel) * negra + 0.8
    o = np.zeros(int(total * SR))
    tt = 0.0
    for k, (st, d) in enumerate(mel):
        if st is not None:
            f = 587.33 * 2 ** (st / 12)
            at(o, tt, flauta(f, d * negra * 0.92, seed=k), 0.55)
        tt += d * negra
    pulsos = int(sum(d for _, d in mel))
    for b in range(pulsos):
        at(o, b * negra, tambor(f=90 if b % 2 == 0 else 120, seed=b), 0.55 if b % 2 == 0 else 0.35)
        at(o, b * negra + negra / 2, tambor(dur=0.12, f=200, seed=100 + b), 0.12)
    write('fiesta_pasacalle', o, peak=0.75)

    # La brisa de los pétalos: aire que crece y se va, y unas campanitas
    # sueltas, como cristales colgados.
    t = T(7.0)
    aire = lowpass(lowpass(np.random.default_rng(21).uniform(-1, 1, len(t)), 900), 900)
    aire *= np.sin(np.pi * t / 7.0) ** 2 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.31 * t))
    o = aire * 3.0
    rng = np.random.default_rng(22)
    for k in range(9):
        at(o, 0.5 + k * 0.62 + rng.uniform(0, 0.3), celesta(NOTAS[rng.integers(3, 8)], 1.0), 0.12)
    write('fiesta_brisa', o, peak=0.45)

    # El aleteo: muchas alas a la vez que arrancan, y se alejan.
    t = T(2.8)
    rng = np.random.default_rng(31)
    o = np.zeros_like(t)
    for k in range(26):
        t0 = rng.uniform(0, 1.2)
        f = rng.uniform(8, 13)
        dur = rng.uniform(0.6, 1.4)
        tt = T(dur)
        ala = lowpass(rng.uniform(-1, 1, len(tt)), rng.uniform(1500, 3200))
        ala *= np.maximum(0, np.sin(2 * np.pi * f * tt)) ** 3
        ala *= np.exp(-tt / (dur * 0.5))
        at(o, t0, ala, rng.uniform(0.4, 1.0))
    write('fiesta_aleteo', o, peak=0.6)

    # El arpa: un glissando que sube por la pentatónica y se queda sonando.
    o = np.zeros(int(3.6 * SR))
    esc = [293.7, 329.6, 370.0, 440.0, 493.9]
    notas = [f * 2 ** o_ for o_ in range(3) for f in esc][:13]
    for k, f in enumerate(notas):
        t = T(2.4)
        cuerda = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(4 * np.pi * f * t)
                  + 0.15 * np.sin(6 * np.pi * f * t)) * np.exp(-t / 0.7)
        at(o, k * 0.095, cuerda * np.minimum(1, t / 0.002), 0.8)
    write('fiesta_arpa', o, peak=0.6)

    # El cohete subiendo: un silbido que se afina.
    t = T(1.05)
    f = 700 + 1300 * (t / 1.05) ** 1.4
    ph = 2 * np.pi * np.cumsum(f) / SR
    sil = np.sin(ph) * 0.5 + lowpass(np.random.default_rng(41).uniform(-1, 1, len(t)), 3000) * 0.4
    sil *= np.minimum(1, t / 0.1) * np.clip((1.05 - t) / 0.08, 0, 1)
    write('fiesta_silbido', sil, peak=0.22)

    # Y reventando: el estampido y la chisporroteo detrás.
    t = T(2.0)
    rng = np.random.default_rng(42)
    boom = lowpass(rng.uniform(-1, 1, len(t)), 500) * np.exp(-t / 0.18) * 2.2
    boom += np.sin(2 * np.pi * 55 * t) * np.exp(-t / 0.25) * 0.8
    crep = np.zeros_like(t)
    for k in range(70):
        t0 = 0.15 + rng.uniform(0, 1.4) ** 1.3
        i0 = int(t0 * SR)
        n = int(0.006 * SR)
        if i0 + n < len(crep):
            crep[i0:i0 + n] += rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / (n / 4)) * rng.uniform(0.2, 0.7)
    o = boom + highpass(crep, 1200) * 0.9
    write('fiesta_cohete', o, peak=0.6)

    # La aurora: un acorde suspendido muy abierto, que respira.
    t = T(8.5)
    o = pad([146.8, 220.0, 329.6, 440.0, 659.3], 8.5, 2.5, 3.0, shimmer=0.1)
    o += lowpass(np.random.default_rng(51).uniform(-1, 1, len(t)), 500) * 0.05 * np.sin(np.pi * t / 8.5)
    write('fiesta_aurora', o, peak=0.5)


if __name__ == '__main__':
    main()
