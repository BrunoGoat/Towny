import math, struct, wave, random, os

SR = 22050
OUT = 'assets/sfx'
os.makedirs(OUT, exist_ok=True)

def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = 0.89 / peak
    frames = b''.join(struct.pack('<h', int(max(-32767, min(32767, s * norm * 32767)))) for s in samples)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(frames)
    print(name, len(samples)/SR, 'sec')

def env(i, n, attack, decay, curve=2.0):
    t = i / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    d = math.exp(-t / decay) ** 1.0
    return a * d

def lowpass(sig, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    out, prev = [], 0.0
    for s in sig:
        prev = (1 - a) * s + a * prev
        out.append(prev)
    return out

# ---- place.wav : a stone landing. Click, crack, then a low body thump.
def place():
    n = int(0.42 * SR)
    rnd = random.Random(7)
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    crack = lowpass(noise, 2600)
    out = []
    for i in range(n):
        t = i / SR
        # sharp contact transient
        click = crack[i] * math.exp(-t / 0.012) * 0.85
        # gritty scrape as it seats
        grit = crack[i] * math.exp(-t / 0.075) * 0.30
        # the weight: two low damped modes
        body = (math.sin(2 * math.pi * 88 * t) * math.exp(-t / 0.13) * 0.85 +
                math.sin(2 * math.pi * 132 * t) * math.exp(-t / 0.09) * 0.45 +
                math.sin(2 * math.pi * 58 * t) * math.exp(-t / 0.17) * 0.55)
        # a touch of stone ring
        ring = math.sin(2 * math.pi * 940 * t) * math.exp(-t / 0.035) * 0.16
        out.append(click + grit + body + ring)
    return lowpass(out, 6500)

# ---- epic.wav : something ancient waking up.
def epic():
    n = int(2.3 * SR)
    out = []
    partials = [(523.25, 1.0, 1.9), (659.25, 0.62, 1.6), (783.99, 0.72, 1.7),
                (1046.5, 0.45, 1.2), (1318.5, 0.30, 0.9), (1567.98, 0.22, 0.7)]
    for i in range(n):
        t = i / SR
        s = 0.0
        for f, amp, dec in partials:
            s += math.sin(2 * math.pi * f * t + 0.4 * math.sin(2 * math.pi * 3.1 * t)) \
                 * amp * math.exp(-t / dec)
        # a slow swell underneath
        sweep = 220 + 500 * (1 - math.exp(-t / 0.5))
        s += math.sin(2 * math.pi * sweep * t) * min(1.0, t / 0.18) * math.exp(-t / 0.9) * 0.5
        out.append(s * min(1.0, t / 0.02))
    return out

# ---- milestone.wav : a horn call for a finished landmark.
def milestone():
    n = int(2.0 * SR)
    out = []
    chord = [196.0, 261.63, 293.66, 392.0]
    for i in range(n):
        t = i / SR
        s = 0.0
        for k, f in enumerate(chord):
            delay = k * 0.055
            if t < delay:
                continue
            tt = t - delay
            a = min(1.0, tt / 0.07) * math.exp(-tt / 1.05)
            # a few harmonics so it reads as brass rather than a sine
            s += (math.sin(2 * math.pi * f * tt) +
                  0.42 * math.sin(2 * math.pi * 2 * f * tt) +
                  0.20 * math.sin(2 * math.pi * 3 * f * tt)) * a * (0.9 - k * 0.11)
        out.append(s)
    return lowpass(out, 4200)

# ---- repair.wav : the wall knitting itself back together.
def repair():
    n = int(1.2 * SR)
    out = []
    for i in range(n):
        t = i / SR
        f = 320 + 900 * (t / 1.2) ** 0.7
        trem = 0.75 + 0.25 * math.sin(2 * math.pi * 11 * t)
        a = min(1.0, t / 0.05) * math.exp(-t / 0.55)
        out.append((math.sin(2 * math.pi * f * t) * 0.7 +
                    math.sin(2 * math.pi * f * 1.5 * t) * 0.3) * a * trem)
    return out

# ---- tap.wav : a small dry UI tick.
def tap():
    n = int(0.07 * SR)
    rnd = random.Random(3)
    noise = lowpass([rnd.uniform(-1, 1) for _ in range(n)], 3800)
    return [noise[i] * math.exp(-(i / SR) / 0.008) for i in range(n)]

# ---- wish.wav : una estrella fugaz cruzando, cinco segundos.
#
# Tiene que durar lo que dura ella y apagarse con ella, así que acaba en cero
# exacto a los cinco segundos: si quedara cola, el sonido seguiría sonando con
# el cielo ya vacío y eso se oye como un fallo.
#
# La primera versión llevaba una capa de ruido filtrado con el corte moviéndose
# —la idea era el aire del vuelo— y sonaba a nave espacial. El ruido se fue
# entero. Lo que queda no lleva ruido de ninguna clase: son campanitas, que es
# lo que suena a magia, sobre una cama de cuerdas apagada.
def wish():
    dur = 5.0
    n = int(dur * SR)
    rnd = random.Random(2027)
    out = [0.0] * n

    # --- la cama: un acorde suspendido, bajo y con algo de armónico para que
    # no sea un seno pelado. El vibrato es mínimo: con el de antes, cinco senos
    # ondulando a la vez sonaban a theremin, que es la otra manera de sonar a
    # marciano.
    chord = [164.81, 246.94, 293.66, 369.99, 493.88]
    for k, f in enumerate(chord):
        entra = 0.25 + k * 0.16
        for i in range(n):
            t = i / SR
            if t < entra:
                continue
            tt = t - entra
            a = min(1.0, tt / 1.1) * (0.20 - k * 0.028)
            vib = 1 + 0.0012 * math.sin(2 * math.pi * (3.1 + 0.4 * k) * t)
            ph = 2 * math.pi * f * vib * tt
            out[i] += (math.sin(ph) + 0.22 * math.sin(2 * ph)) * a

    # --- el brillo: campanitas sueltas, amontonadas en el medio del vuelo.
    # Esto es lo que se tiene que oír, así que va por delante de la cama.
    escala = [1046.5, 1174.66, 1396.91, 1567.98, 1760.0, 2093.0, 2349.32, 2793.83]
    for c in range(30):
        u = 0.5 + 0.5 * math.copysign(abs(rnd.uniform(-1, 1)) ** 1.7, rnd.uniform(-1, 1))
        t0 = 0.15 + u * (dur - 1.1)
        f = escala[rnd.randrange(len(escala))]
        dec = 0.30 + rnd.random() * 0.60
        amp = 0.20 + 0.14 * rnd.random()
        i0 = int(t0 * SR)
        for i in range(i0, min(n, i0 + int(dec * 5 * SR))):
            tt = (i - i0) / SR
            e = math.exp(-tt / dec)
            # El parcial de arriba es el que hace que suene a campana y no a
            # flauta, y va en una relación que no es entera a propósito.
            out[i] += (math.sin(2 * math.pi * f * tt) +
                       0.26 * math.sin(2 * math.pi * f * 2.76 * tt)) * e * amp

    # --- y el sobre de todo: entra en medio segundo, se apaga hasta cero justo
    # al final. El cuadrado del coseno acaba plano, no en punta, que es lo que
    # hace que no se oiga dónde corta.
    for i in range(n):
        t = i / SR
        a = min(1.0, t / 0.45)
        cae = 1.0
        if t > 2.9:
            x = (t - 2.9) / (dur - 2.9)
            cae = math.cos(math.pi * 0.5 * min(1.0, x)) ** 2
        out[i] *= a * cae
    out[n - 1] = 0.0
    return out

write('place.wav', place())
write('epic.wav', epic())
write('milestone.wav', milestone())
write('repair.wav', repair())
write('tap.wav', tap())
write('wish.wav', wish())


# ---- estrella.wav : tocar una constelación.
#
# Se escribieron diez y se probaron las diez en el teléfono. Quedó **la sexta**:
# dos notas a la vez, una quinta — un acorde de una sola pulsación. Las otras
# nueve siguen escritas aquí abajo por si alguna vuelve, pero no se generan: un
# asset que no suena en ninguna parte es sitio en la APK por nada. Es lo mismo
# que se hizo con los tres temas de música que no quedaron.
#
# Por qué una quinta y no una campanita sola: las de una nota se leen como un
# aviso —algo te contestó—, y las de tres o cuatro como una pequeña melodía,
# que ya es demasiado para un dedo en el cielo. Dos a la vez no suenan a
# mensaje: suenan a que el sitio tiene una nota, y ya.
#
# Lo que tienen en común las diez, y era el encargo: **cortas**. La fugaz dura
# cinco segundos porque acompaña a algo que cruza el cielo; esto acompaña a un
# dedo, y un dedo no dura cinco segundos. Ninguna pasa de ocho décimas.
#
# Y ninguna es un «bien hecho». Tocar una constelación no es un logro, no
# desbloquea nada y no lleva la cuenta nadie: es mirar para arriba.

def _campana(out, t0, f, dec, amp, arm=0.35):
    """Una campanita: fundamental, un armónico y caída exponencial."""
    n = len(out)
    i0 = int(t0 * SR)
    for i in range(i0, n):
        tt = (i - i0) / SR
        e = math.exp(-tt / dec)
        if e < 0.0006:
            break
        ph = 2 * math.pi * f * tt
        out[i] += (math.sin(ph) + arm * math.sin(2.76 * ph)) * e * amp


def _soplo(out, t0, dur, corte, amp):
    """Un soplo de aire filtrado, para lo que tiene que sonar a noche."""
    rnd = random.Random(int(t0 * 10000) + 7)
    n = len(out)
    i0, i1 = int(t0 * SR), min(len(out), int((t0 + dur) * SR))
    crudo = [rnd.uniform(-1, 1) for _ in range(max(0, i1 - i0))]
    suave = lowpass(lowpass(crudo, corte), corte)
    for k, s in enumerate(suave):
        i = i0 + k
        if i >= n:
            break
        u = k / max(1, len(suave))
        out[i] += s * math.sin(math.pi * u) ** 2 * amp


def _estrellas():
    """Las diez. Cada una devuelve (nombre, muestras)."""
    # Un pentatónico alto: no hay manera de que dos notas de acá suenen mal
    # juntas, que es lo que hace falta cuando se sortea el orden.
    P = [1046.5, 1174.7, 1396.9, 1568.0, 1760.0, 2093.0, 2349.3, 2793.8, 3136.0]

    def vacio(dur):
        return [0.0] * int(dur * SR)

    hechas = []

    # 1 · una sola campanita alta y limpia. El mínimo que se puede hacer.
    o = vacio(0.55)
    _campana(o, 0.0, P[5], 0.17, 1.0)
    hechas.append(('estrella1.wav', o))

    # 2 · dos notas subiendo, muy juntas. Suena a «sí».
    o = vacio(0.55)
    _campana(o, 0.0, P[3], 0.11, 0.85)
    _campana(o, 0.055, P[5], 0.17, 1.0)
    hechas.append(('estrella2.wav', o))

    # 3 · tres subiendo, como quien pulsa un arpa de tres cuerdas.
    o = vacio(0.70)
    for k, f in enumerate([P[2], P[4], P[6]]):
        _campana(o, k * 0.048, f, 0.13 + k * 0.05, 0.7 + k * 0.12)
    hechas.append(('estrella3.wav', o))

    # 4 · dos bajando. Lo mismo del revés, y se lee más como «ah» que como «sí».
    o = vacio(0.60)
    _campana(o, 0.0, P[6], 0.12, 0.95)
    _campana(o, 0.06, P[4], 0.20, 0.85)
    hechas.append(('estrella4.wav', o))

    # 5 · campanita con un soplo de aire detrás: la nota, y la noche.
    o = vacio(0.75)
    _campana(o, 0.0, P[5], 0.16, 0.9)
    _soplo(o, 0.0, 0.55, 2600, 0.16)
    hechas.append(('estrella5.wav', o))

    # 6 · dos a la vez, una quinta: un acorde de una sola pulsación.
    o = vacio(0.70)
    _campana(o, 0.0, P[3], 0.19, 0.75)
    _campana(o, 0.006, P[6], 0.19, 0.75)
    hechas.append(('estrella6.wav', o))

    # 7 · muy corta y muy alta, casi un tilín. La más discreta de las diez.
    o = vacio(0.35)
    _campana(o, 0.0, P[8], 0.075, 1.0, arm=0.18)
    hechas.append(('estrella7.wav', o))

    # 8 · una nota con su eco, ya lejos. El cielo está lejos.
    o = vacio(0.80)
    _campana(o, 0.0, P[5], 0.13, 1.0)
    _campana(o, 0.20, P[5], 0.16, 0.26)
    hechas.append(('estrella8.wav', o))

    # 9 · cuatro chispas menudas, desordenadas: un puñado de estrellas y no una.
    o = vacio(0.70)
    rnd = random.Random(31)
    for k in range(4):
        _campana(o, k * 0.035 + rnd.random() * 0.02,
                 P[rnd.randrange(4, 9)], 0.09 + rnd.random() * 0.08,
                 0.55 + rnd.random() * 0.35, arm=0.22)
    hechas.append(('estrella9.wav', o))

    # 10 · sólo aire, sin nota ninguna. Es la que contesta sin decir nada.
    o = vacio(0.60)
    _soplo(o, 0.0, 0.50, 3400, 1.0)
    _campana(o, 0.0, P[7], 0.05, 0.22, arm=0.1)
    hechas.append(('estrella10.wav', o))

    return hechas


# La que quedó. Cambiar este número y volver a correr esto es lo único que hace
# falta si algún día se prefiere otra de las nueve.
ELEGIDA = 6

for _nombre, _muestras in _estrellas():
    if _nombre == 'estrella%d.wav' % ELEGIDA:
        write('estrella.wav', _muestras)