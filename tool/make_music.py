"""Lo que suena de fondo mientras el pueblo está ahí.

Cinco piezas, y una suena cada vez que se abre la app.

La anterior era una sola: bordón de zanfoña, laúd y flauta en re dórico. El
problema no era la mezcla, era la armonía. Un bordón que no se mueve nunca
debajo de un modo con la sexta subida es, exactamente, el sonido de lo
misterioso: nada resuelve porque nada se mueve, y la oreja lo lee como
suspenso. Sonaba a cripta.

Lo que hace que una música suene tranquila y no rara, según quien lo hace:

  · Acordes de séptima mayor, novena añadida y sus2. La séptima mayor «aporta
    calidez sin introducir disonancia áspera»; la novena añadida «abre y
    espacia sin disonancia». Lo que NO hay aquí es una sola séptima de
    dominante ni un solo tritono: ése es el acorde de la tensión, y su trabajo
    es pedir resolución.
  · Voces cerradas dentro de una octava —íntimas y cálidas— y la fundamental
    abajo, en el bajo, que es como se voicea en jazz para dejar aire en medio.
  · Despacio: entre sesenta y setenta y dos, que es donde los acordes respiran.
  · Y armonía que se mueve de verdad. Cuatro acordes que van a algún lado y
    vuelven. Eso es lo único que separa «tranquilo» de «inquietante».

Y lo que hace que suene cálida y no digital:

  · El Rhodes es FM de dos operadores, que es como se hizo siempre: el índice
    de modulación se apaga rápido y deja el diente —el golpe metálico— encima
    de una barra que dura. Un piano eléctrico son esas dos cosas.
  · Los pads son una pila de sierras desafinadas entre sí y un paso bajo
    apretado: desafinar + filtrar + ataque lento es la receta entera.
  · Wow de cinta: la afinación deriva despacio, medio tono de nada. Y una
    saturación suave encima. Las dos cosas juntas son lo que hace que algo
    grabado suene acogedor en vez de exacto.

La estructura es la de Eno en «Music for Airports»: capas de largos distintos
que se cruzan y no vuelven a coincidir en un buen rato. Pero con una regla que
allí no hacía falta y aquí sí: **las dos capas que llevan armonía duran lo
mismo**, porque si los acordes se desfasan chocan. La que flota libre es la de
arriba, y sus notas están elegidas para que suenen bien sobre los cuatro
acordes de la pieza — que es literalmente lo que hizo Eno, «notas que
funcionan juntas sin disonancia», sólo que él lo tenía fácil porque no tenía
acordes debajo.
"""
import math
import os
import random
import struct
import wave

OUT = 'assets/sfx'
os.makedirs(OUT, exist_ok=True)

TAU = 2 * math.pi

# Una tabla de seno en vez de math.sin por muestra. Son decenas de millones de
# llamadas; con tabla el generador tarda minutos y sin ella, mucho más.
TBL = 8192
SIN = [math.sin(TAU * i / TBL) for i in range(TBL)]
MASK = TBL - 1

# Los pads no tienen nada por encima de kiloherzio y pico, así que no hace
# falta gastarles el doble de archivo. Lo de arriba —dientes y campanas— sí.
SR_LOW = 8000
SR_HI = 16000

STEP = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def n(name):
    """'Bb3' o 'F#4' o 'C4' a número midi, con do central en 60."""
    step = STEP[name[0]]
    i = 1
    while i < len(name) and name[i] in '#b':
        step += 1 if name[i] == '#' else -1
        i += 1
    return 12 * (int(name[i:]) + 1) + step


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ------------------------------------------------------------------- la cinta

def lowpass(sig, cutoff, sr, cyclic=False, poles=2):
    """Con `cyclic` el filtro se carga dando una vuelta en vacío antes de
    escribir nada: un filtro que arranca de cero deja al principio del archivo
    un transitorio que al final no está, y eso es un chasquido justo en el
    empalme del bucle."""
    a = math.exp(-TAU * cutoff / sr)
    out = sig
    for _ in range(poles):
        prev = 0.0
        if cyclic:
            for x in out:
                prev = (1 - a) * x + a * prev
        nxt = []
        for x in out:
            prev = (1 - a) * x + a * prev
            nxt.append(prev)
        out = nxt
    return out


def highpass(sig, cutoff, sr):
    """Fuera lo de muy abajo. Un pad con retumbe por debajo de los cincuenta
    hercios en un altavoz de teléfono no es grave, es un zumbido."""
    a = math.exp(-TAU * cutoff / sr)
    prev = 0.0
    out = []
    for x in sig:
        prev = (1 - a) * x + a * prev
        out.append(x - prev)
    return out


def saturate(sig, drive=1.4):
    """Tangente hiperbólica, por aproximación de Padé porque son millones de
    muestras. Redondea los picos y añade armónicos pares: es la diferencia
    entre algo calculado y algo grabado."""
    out = []
    for x in sig:
        v = x * drive
        v = max(-3.0, min(3.0, v))
        out.append(v * (27 + v * v) / (27 + 9 * v * v))
    return out


def wow(sig, sr, cents=7.0, cycles=(1, 3), seed=0):
    """La deriva de afinación de una cinta: la lee desde un retardo que se mueve
    despacio. Los ciclos son enteros por bucle a propósito — un wow que no cierra
    el bucle es un salto de tono en el empalme, que es peor que no tener wow."""
    ln = len(sig)
    if ln == 0:
        return sig
    rnd = random.Random(seed)
    # Profundidad en muestras a partir de los cents: al ir el retardo de cero a
    # `depth` en un cuarto de ciclo, la desviación de tono es depth*w/sr.
    depth = 0.0
    lfos = []
    for c in cycles:
        w = TAU * c / ln
        amp = (cents / 1731.0) / w / len(cycles)
        lfos.append((w, amp, rnd.uniform(0, TAU)))
        depth += amp
    out = []
    for i in range(ln):
        d = depth
        for w, amp, ph in lfos:
            d += amp * SIN[int((w * i + ph) / TAU * TBL) & MASK]
        j = i - d
        k = int(math.floor(j))
        f = j - k
        out.append(sig[k % ln] * (1 - f) + sig[(k + 1) % ln] * f)
    return out


def reverb(sig, sr, wet=0.34, size=1.0, dark=0.62):
    """Una sala grande y sorda: cuatro peines y dos passtodo, las paredes se
    comen los agudos. La de antes era una sala de piedra pequeña y brillante, y
    parte de lo raro venía de ahí."""
    ln = len(sig)
    out = [0.0] * ln
    base = sr / 16000.0 * size
    for delay, gain in ((1231, 0.84), (1607, 0.82), (1913, 0.80), (2251, 0.78)):
        d = max(8, int(delay * base))
        buf = [0.0] * d
        p = 0
        prev = 0.0
        for i in range(ln):
            v = buf[p]
            out[i] += v * 0.25
            prev = dark * v + (1 - dark) * prev
            buf[p] = sig[i] + prev * gain
            p = p + 1 if p + 1 < d else 0
    for delay, gain in ((331, 0.7), (109, 0.7)):
        d = max(4, int(delay * base))
        buf = [0.0] * d
        p = 0
        for i in range(ln):
            v = buf[p]
            y = v - gain * out[i]
            buf[p] = out[i] + gain * y
            out[i] = y
            p = p + 1 if p + 1 < d else 0
    return [s * (1 - wet) + w * wet for s, w in zip(sig, out)]


def wrap(sig, seconds, sr):
    """Cierra el bucle: lo que sigue sonando pasado el final se suma otra vez al
    principio, que es donde va a sonar cuando el bucle vuelva a empezar. La
    última campanada sigue ahí cuando vuelve el compás uno."""
    ln = int(round(seconds * sr))
    out = sig[:ln]
    for i in range(min(len(sig) - ln, ln)):
        out[i] += sig[ln + i]
    return out


# -------------------------------------------------------------------- voces

def tine(out, at, note, dur, vel, sr, bright=2.6, hold=1.5):
    """El Rhodes, que es FM de dos operadores y siempre lo fue.

    Portadora y moduladora a la misma frecuencia. El índice se apaga en una
    décima: ése es el diente, el golpe metálico del martillo. Debajo queda la
    barra, que es casi una sinusoide y dura. Un piano eléctrico son esas dos
    cosas y nada más."""
    f = hz(note)
    start = int(at * sr)
    total = int(dur * sr)
    step = f / sr * TBL
    ph = 0.0
    for i in range(total):
        j = start + i
        if j >= len(out):
            break
        t = i / sr
        idx = bright * math.exp(-t * 16.0)
        amp = math.exp(-t / hold) * min(1.0, i / 24.0)
        m = SIN[int(ph) & MASK]
        s = SIN[int(ph + idx * m * TBL / TAU) & MASK]
        out[j] += s * amp * vel
        ph += step


def bell(out, at, note, dur, vel, sr, ratios=(1.0, 2.02, 3.01, 4.97)):
    """Caja de música: parciales que no son múltiplos enteros —por eso una
    campana no suena a nota sino a campana— y una cola larguísima."""
    f = hz(note)
    start = int(at * sr)
    total = int(dur * sr)
    voices = []
    for k, r in enumerate(ratios):
        fr = f * r
        if fr > sr * 0.45:
            continue
        voices.append((fr / sr * TBL, 0.0, 1.0 / (1 + k * 1.7), 1.0 / (2.6 - k * 0.42)))
    for i in range(total):
        j = start + i
        if j >= len(out):
            break
        t = i / sr
        s = 0.0
        for k in range(len(voices)):
            step, ph, a, dec = voices[k]
            s += SIN[int(ph) & MASK] * a * math.exp(-t * dec)
            voices[k] = (step, ph + step, a, dec)
        out[j] += s * vel * min(1.0, i / 12.0)


def pluck(out, at, note, dur, vel, sr, damp=0.9970, seed=0):
    """Cuerda de nailon: Karplus-Strong, que es literalmente lo que hace una
    cuerda pulsada. El ruido de arranque va filtrado —una cuerda de tripa
    pulsada con la yema no tiene el brillo de una púa— y sin continua, porque
    el lazo es un promediador y cualquier continua no se apaga jamás."""
    f = hz(note)
    ln = max(4, int(round(sr / f - 0.5)))
    rnd = random.Random(seed * 7919 + note)
    buf = [rnd.uniform(-1, 1) for _ in range(ln)]
    for _ in range(3):
        buf = [(buf[i] + buf[i - 1]) * 0.5 for i in range(ln)]
    avg = sum(buf) / ln
    buf = [v - avg for v in buf]
    start = int(at * sr)
    idx = 0
    for i in range(int(dur * sr)):
        a = buf[idx]
        buf[idx] = damp * 0.5 * (a + buf[(idx + 1) % ln])
        idx = (idx + 1) % ln
        j = start + i
        if j >= len(out):
            break
        out[j] += a * vel * min(1.0, i / 80.0)


def breath(out, at, note, dur, vel, sr, seed=0):
    """Flauta de madera, tibia. Menos armónicos y menos vibrato que la de antes:
    una sinusoide con vibrato encima de un bordón era medio ocarina de cueva."""
    f = hz(note)
    rnd = random.Random(seed * 104729 + note)
    start = int(at * sr)
    total = int(dur * sr)
    rise = 0.16 * sr
    fade = min(total * 0.4, 0.30 * sr)
    step = f / sr * TBL
    ph = rnd.uniform(0, TBL)
    air = 0.0
    for i in range(total):
        j = start + i
        if j >= len(out):
            break
        t = i / sr
        env = min(1.0, i / rise) * min(1.0, (total - i) / fade)
        p = int(ph) & MASK
        s = SIN[p] + 0.16 * SIN[(p * 2) & MASK] + 0.04 * SIN[(p * 3) & MASK]
        air = 0.95 * air + 0.05 * rnd.uniform(-1, 1)
        out[j] += (s * 0.66 + air * 0.06) * env * vel
        ph += step * (1 + 0.0035 * SIN[int((TAU * 4.2 * t) / TAU * TBL) & MASK]
                      * min(1.0, t / 1.1))


def stack(out, notes, seconds, sr, cut=760.0, spread=9.0, gain=1.0,
          rise=0.9, fall=1.8, at=0.0, voices=3, tilt=1.35):
    """El pad: por cada nota, una pila de sierras desafinadas entre sí.

    Aditiva y no una sierra de verdad porque una sierra ideal alias como una
    escopeta; sumando armónicos hasta Nyquist no hay nada que doblar. Los cents
    de separación entre las copias son los que hacen el coro, y el paso bajo de
    después es lo que la vuelve un pad y no un órgano."""
    total = int(seconds * sr)
    start = int(at * sr)
    riseN = max(1, int(rise * sr))
    fallN = max(1, int(fall * sr))
    env = [min(1.0, i / riseN) * min(1.0, (total - i) / fallN)
           for i in range(total)]
    for note in notes:
        f0 = hz(note)
        top = min(sr * 0.45, cut * 3.2)
        harms = max(1, int(top / f0))
        for v in range(voices):
            det = (v - (voices - 1) / 2.0) * spread
            fv = f0 * 2 ** (det / 1200.0)
            for h in range(1, harms + 1):
                a = gain / h ** tilt / voices
                if a < 0.0035:
                    break
                step = fv * h / sr * TBL
                ph = (h * 977 + v * 313 + note * 71) % TBL * 1.0
                for i in range(total):
                    j = start + i
                    if j >= len(out):
                        break
                    out[j] += SIN[int(ph) & MASK] * a * env[i]
                    ph += step


# ------------------------------------------------------------------ el papel

def finish(sig, seconds, sr, wet=0.32, size=1.4, cents=6.0, drive=1.25,
           cut=None, seed=0):
    """De la nota tocada al archivo: sala, cierre del bucle, cinta.

    En este orden y no en otro. La reverberación antes de cerrar el bucle,
    porque lo que hay que doblar sobre el principio es la cola con sala y todo.
    El wow después de cerrarlo, leyendo con módulo, para que la deriva de tono
    también dé la vuelta y no haya salto en el empalme."""
    if cut:
        sig = lowpass(sig, cut, sr, poles=1)
    sig = reverb(sig, sr, wet=wet, size=size)
    sig = wrap(sig, seconds, sr)
    sig = wow(sig, sr, cents=cents, cycles=(1, 3), seed=seed)
    return saturate(sig, drive)


def pad_of(chords, bar, sr, cut=700.0, spread=11.0, gain=1.0, tail=1.8,
           voices=2, tilt=1.9, seed=0):
    """La cama: un acorde por compás, cada uno entrando mientras el anterior se
    va. Los acordes se solapan a propósito — un pad que corta en la barra de
    compás no es una cama, es un órgano con alguien soltando las teclas."""
    total = len(chords) * bar
    out = [0.0] * int((total + tail) * sr)
    for b, notes in enumerate(chords):
        stack(out, notes, bar + tail, sr, cut=cut, spread=spread, gain=gain,
              rise=bar * 0.42, fall=bar * 0.78, at=b * bar, voices=voices,
              tilt=tilt)
    out = lowpass(out, cut, sr, poles=2)
    out = highpass(out, 44, sr)
    return finish(out, total, sr, wet=0.26, size=1.7, cents=5.0, drive=1.15,
                  seed=seed)


def notes_of(score, beat):
    """Una partitura es una lista de (pulso, nota, duración, fuerza)."""
    for t, note, dur, vel in score:
        yield t * beat, note, dur * beat, vel


# ------------------------------------------------------------------- las cinco

def tarde():
    """Fa mayor, setenta y dos. Famaj7 · Rem9 · Sibmaj7 · Dosus2.

    El sonido de estudiar con auriculares: Rhodes, bajo redondo y campanitas.
    El cuarto acorde es sus2 y no add9 a propósito — sin tercera, el fa de la
    capa de arriba pasa por encima sin rozar con nada."""
    bar, beat = 4 * 60 / 72.0, 60 / 72.0
    chords = [
        [n('F2'), n('A3'), n('C4'), n('E4')],
        [n('D2'), n('F3'), n('A3'), n('E4')],
        [n('Bb2'), n('D3'), n('F3'), n('A3')],
        [n('C2'), n('D3'), n('G3'), n('C4')],
    ]
    pad = pad_of(chords, bar, SR_LOW, cut=680, spread=12, gain=0.85, seed=1)

    keys = [
        (0.0, 'F3', 2.4, .85), (0.75, 'C4', 2.0, .52), (1.5, 'E4', 2.2, .62),
        (2.5, 'A3', 1.8, .48), (3.25, 'C4', 1.6, .40),
        (4.0, 'D3', 2.4, .82), (4.75, 'A3', 2.0, .50), (5.5, 'E4', 2.4, .60),
        (6.5, 'F3', 1.8, .46), (7.25, 'A3', 1.4, .38),
        (8.0, 'Bb2', 2.6, .84), (8.75, 'F3', 2.0, .50), (9.5, 'D4', 2.2, .58),
        (10.5, 'A3', 1.8, .46), (11.25, 'F3', 1.6, .38),
        (12.0, 'C3', 2.6, .80), (12.75, 'G3', 2.0, .48), (13.5, 'D4', 2.4, .56),
        (14.5, 'C4', 2.0, .44), (15.25, 'G3', 1.8, .36),
    ]
    ln = int((4 * bar + 3.4) * SR_HI)
    out = [0.0] * ln
    for at, note, dur, vel in notes_of(keys, beat):
        tine(out, at, n(note), dur, vel * 0.34, SR_HI, bright=2.5, hold=1.4)
    keys = finish(out, 4 * bar, SR_HI, wet=0.34, size=1.4, cents=7.0, seed=2)

    # Cinco compases contra cuatro: no vuelven a coincidir hasta los veinte.
    air = [
        (0.0, 'C5', 3.0, .60), (3.0, 'A4', 2.5, .48), (6.5, 'D5', 3.0, .52),
        (11.0, 'G4', 2.5, .44), (14.0, 'F5', 3.0, .40),
        (18.0, 'C5', 2.5, .46),
    ]
    ln = int((5 * bar + 4.0) * SR_HI)
    out = [0.0] * ln
    for at, note, dur, vel in notes_of(air, beat):
        bell(out, at, n(note), dur, vel * 0.26, SR_HI)
    air = finish(out, 5 * bar, SR_HI, wet=0.44, size=1.9, cents=9.0, seed=3)
    return [('pad', pad, SR_LOW, 1.00), ('keys', keys, SR_HI, 0.92),
            ('air', air, SR_HI, 0.60)]


def bruma():
    """Lab mayor, sin pulso ninguno. Labmaj9 · Fam9 · Rebmaj7 · Mibsus2.

    Esto es lo de Eno tal cual: no hay compás, sólo cosas que entran y salen.
    Cinco segundos por acorde y nada que marque el tiempo."""
    bar = 5.0
    chords = [
        [n('Ab2'), n('C4'), n('Eb4'), n('G4')],
        [n('F2'), n('Ab3'), n('C4'), n('G4')],
        [n('Db2'), n('F3'), n('Ab3'), n('C4')],
        [n('Eb2'), n('F3'), n('Bb3'), n('Eb4')],
    ]
    pad = pad_of(chords, bar, SR_LOW, cut=560, spread=14, gain=0.95, tail=2.8,
                 seed=4)

    # La segunda capa es la misma idea una octava arriba y más abierta: coro
    # antes que colchón. Mismo largo que el pad, porque lleva armonía.
    high = [[m + 12 for m in c[1:]] for c in chords]
    out = [0.0] * int((4 * bar + 4.0) * SR_LOW)
    for b, notes in enumerate(high):
        stack(out, notes, bar + 4.0, SR_LOW, cut=1500, spread=20, gain=0.5,
              rise=bar * 0.55, fall=bar * 0.9, at=b * bar, voices=2, tilt=1.2)
    out = lowpass(out, 1500, SR_LOW, poles=2)
    keys = finish(out, 4 * bar, SR_LOW, wet=0.40, size=2.0, cents=8.0, seed=5)

    air = [
        (0.0, 'Eb5', 6.0, .55), (7.0, 'C5', 6.0, .45), (16.0, 'Ab5', 6.0, .38),
        (24.0, 'Bb4', 6.0, .42),
    ]
    ln = int((3 * bar + 8.0) * SR_HI)
    out = [0.0] * ln
    for at, note, dur, vel in notes_of(air, 1.0):
        bell(out, at, n(note), dur, vel * 0.22, SR_HI,
             ratios=(1.0, 2.01, 2.99))
    air = finish(out, 3 * bar, SR_HI, wet=0.50, size=2.2, cents=11.0, seed=6)
    return [('pad', pad, SR_LOW, 1.00), ('keys', keys, SR_LOW, 0.72),
            ('air', air, SR_HI, 0.52)]


def sendero():
    """Sol mayor, sesenta y seis. Soladd9 · Mim9 · Domaj7 · Resus2.

    La de cuerda de nailon y flauta de madera, que es la que más se parece a la
    de antes — pero en mayor y con acordes que se mueven, que es justo lo que
    separa un paseo de una cripta."""
    bar, beat = 4 * 60 / 66.0, 60 / 66.0
    chords = [
        [n('G2'), n('B3'), n('D4'), n('A4')],
        [n('E2'), n('G3'), n('B3'), n('F#4')],
        [n('C2'), n('E3'), n('G3'), n('B3')],
        [n('D2'), n('E3'), n('A3'), n('D4')],
    ]
    pad = pad_of(chords, bar, SR_LOW, cut=620, spread=10, gain=0.72, seed=7)

    picking = [
        (0.0, 'G3', 3.0, .80), (0.5, 'D4', 2.6, .46), (1.0, 'B3', 2.4, .54),
        (1.5, 'A4', 2.4, .42), (2.0, 'D4', 2.2, .40), (3.0, 'B3', 2.0, .44),
        (4.0, 'E3', 3.0, .78), (4.5, 'B3', 2.6, .44), (5.0, 'G3', 2.4, .52),
        (5.5, 'F#4', 2.4, .40), (6.0, 'B3', 2.2, .38), (7.0, 'G3', 2.0, .42),
        (8.0, 'C3', 3.0, .80), (8.5, 'G3', 2.6, .46), (9.0, 'E3', 2.4, .52),
        (9.5, 'B3', 2.4, .42), (10.0, 'G3', 2.2, .38), (11.0, 'E3', 2.0, .42),
        (12.0, 'D3', 3.0, .78), (12.5, 'A3', 2.6, .44), (13.0, 'E3', 2.4, .50),
        (13.5, 'D4', 2.4, .40), (14.0, 'A3', 2.2, .38), (15.0, 'E3', 2.0, .40),
    ]
    ln = int((4 * bar + 3.4) * SR_HI)
    out = [0.0] * ln
    for k, (at, note, dur, vel) in enumerate(notes_of(picking, beat)):
        pluck(out, at, n(note), dur, vel * 0.30, SR_HI, damp=0.9974, seed=k)
    keys = finish(out, 4 * bar, SR_HI, wet=0.36, size=1.5, cents=6.0, seed=8)

    tune = [
        (0.0, 'B4', 2.0, .55), (2.0, 'A4', 1.0, .44), (3.0, 'G4', 3.0, .50),
        # un compás entero callado: una melodía que no calla deja de ser fondo
        (8.0, 'D5', 1.5, .48), (9.5, 'E5', 1.5, .42), (11.0, 'B4', 3.0, .46),
        (16.0, 'A4', 2.0, .42), (18.0, 'G4', 3.0, .46),
    ]
    ln = int((5 * bar + 3.4) * SR_HI)
    out = [0.0] * ln
    for k, (at, note, dur, vel) in enumerate(notes_of(tune, beat)):
        breath(out, at, n(note), dur, vel * 0.24, SR_HI, seed=k)
    air = finish(out, 5 * bar, SR_HI, wet=0.42, size=1.8, cents=7.0, seed=9)
    return [('pad', pad, SR_LOW, 1.00), ('keys', keys, SR_HI, 0.95),
            ('air', air, SR_HI, 0.72)]


def caja():
    """Do mayor, sesenta. Domaj7 · Lam9 · Famaj7 · Solsus2.

    Caja de música: parciales que no son múltiplos enteros y una cola que no se
    acaba. Es la más pequeña de las cinco, a propósito."""
    bar, beat = 4.0, 1.0
    chords = [
        [n('C2'), n('E3'), n('G3'), n('B3')],
        [n('A2'), n('C3'), n('E3'), n('B3')],
        [n('F2'), n('A3'), n('C4'), n('E4')],
        [n('G2'), n('A3'), n('D4'), n('G4')],
    ]
    pad = pad_of(chords, bar, SR_LOW, cut=520, spread=9, gain=0.80, seed=10)

    box = [
        (0.0, 'E5', 3.5, .62), (1.0, 'G5', 3.0, .44), (2.0, 'B4', 3.0, .50),
        (3.0, 'D5', 2.5, .38),
        (4.0, 'C5', 3.5, .60), (5.0, 'E5', 3.0, .42), (6.0, 'A4', 3.0, .48),
        (7.0, 'B4', 2.5, .36),
        (8.0, 'A4', 3.5, .58), (9.0, 'C5', 3.0, .42), (10.0, 'E5', 3.0, .46),
        (11.0, 'G5', 2.5, .34),
        (12.0, 'D5', 3.5, .56), (13.0, 'G4', 3.0, .40), (14.0, 'A4', 3.0, .44),
        (15.0, 'D5', 2.5, .34),
    ]
    ln = int((4 * bar + 4.0) * SR_HI)
    out = [0.0] * ln
    for at, note, dur, vel in notes_of(box, beat):
        bell(out, at, n(note), dur, vel * 0.24, SR_HI,
             ratios=(1.0, 2.03, 3.68, 5.42))
    keys = finish(out, 4 * bar, SR_HI, wet=0.40, size=1.7, cents=6.0, seed=11)

    # Tres compases contra cuatro, y notas graves para que no compita.
    low = [(0.0, 'G3', 4.0, .50), (4.5, 'E3', 4.0, .44), (8.0, 'C4', 4.0, .40)]
    ln = int((3 * bar + 4.0) * SR_HI)
    out = [0.0] * ln
    for at, note, dur, vel in notes_of(low, beat):
        bell(out, at, n(note), dur, vel * 0.20, SR_HI, ratios=(1.0, 2.01, 3.0))
    air = finish(out, 3 * bar, SR_HI, wet=0.46, size=2.0, cents=8.0, seed=12)
    return [('pad', pad, SR_LOW, 1.00), ('keys', keys, SR_HI, 0.85),
            ('air', air, SR_HI, 0.62)]


def brasa():
    """Reb mayor, sesenta y tres. Sibm9 · Solbmaj7 · Rebadd9 · Labsus2.

    La de la noche: Rhodes grave, la cama muy abajo y una campana cada tanto,
    muy arriba. El tono elegido para que casi todo caiga en teclas negras y
    quede oscuro sin ser triste."""
    bar, beat = 4 * 60 / 63.0, 60 / 63.0
    chords = [
        [n('Bb2'), n('Db3'), n('F3'), n('C4')],
        [n('Gb2'), n('Bb3'), n('Db4'), n('F4')],
        [n('Db2'), n('F3'), n('Ab3'), n('Eb4')],
        [n('Ab2'), n('Bb3'), n('Eb4'), n('Ab4')],
    ]
    pad = pad_of(chords, bar, SR_LOW, cut=600, spread=13, gain=0.95, seed=13)

    keys = [
        (0.0, 'Bb2', 3.2, .82), (1.0, 'F3', 2.8, .50), (2.0, 'Db4', 2.6, .56),
        (3.0, 'C4', 2.2, .40),
        (4.0, 'Gb2', 3.2, .80), (5.0, 'Db3', 2.8, .48), (6.0, 'Bb3', 2.6, .54),
        (7.0, 'F4', 2.2, .38),
        (8.0, 'Db2', 3.2, .82), (9.0, 'Ab3', 2.8, .48), (10.0, 'F3', 2.6, .52),
        (11.0, 'Eb4', 2.2, .38),
        (12.0, 'Ab2', 3.2, .78), (13.0, 'Eb3', 2.8, .46), (14.0, 'Bb3', 2.6, .50),
        (15.0, 'Ab3', 2.2, .36),
    ]
    ln = int((4 * bar + 3.6) * SR_HI)
    out = [0.0] * ln
    for at, note, dur, vel in notes_of(keys, beat):
        tine(out, at, n(note), dur, vel * 0.32, SR_HI, bright=2.0, hold=1.7)
    keys = finish(out, 4 * bar, SR_HI, wet=0.36, size=1.6, cents=6.5, seed=14)

    air = [(0.0, 'Ab5', 5.0, .42), (5.5, 'Db5', 5.0, .36), (11.0, 'Eb5', 5.0, .32)]
    ln = int((3 * bar + 5.0) * SR_HI)
    out = [0.0] * ln
    for at, note, dur, vel in notes_of(air, beat):
        bell(out, at, n(note), dur, vel * 0.20, SR_HI, ratios=(1.0, 2.02, 3.01))
    air = finish(out, 3 * bar, SR_HI, wet=0.50, size=2.1, cents=10.0, seed=15)
    return [('pad', pad, SR_LOW, 1.00), ('keys', keys, SR_HI, 0.90),
            ('air', air, SR_HI, 0.55)]



# ------------------------------------------------------- y la que no es bucle

def cronica():
    """Re mayor, sesenta y ocho. Diecisiete compases que empiezan y acaban.

    Ésta no es como las otras dos y no se puede juzgar con la misma vara. Las
    dos de fondo tienen prohibido resolver: suenan durante horas detrás de un
    pueblo y cualquier cosa que pida un final se vuelve insoportable a la
    tercera vuelta. Por eso allí no hay una sola séptima de dominante ni un
    tritono — el acorde de la tensión — y por eso el bucle se cierra doblando
    la cola sobre el principio para que no se oiga dónde empalma.

    **Aquí es justo al revés.** Esto dura sesenta segundos exactos, se oye una
    vez, y lo que está pasando en pantalla es un valle vacío que se llena hasta
    llegar a hoy. Una música que no va a ninguna parte contaría lo contrario de
    lo que se está viendo. Así que esta pieza sí tira hacia algún sitio, sí
    tiene un compás en el que rompe, y sí acaba en el acorde de casa, ancho y
    abierto. No se cierra el bucle porque no hay bucle que cerrar.

    De dónde sale la épica sin un solo tambor —esta app no tiene percusión y no
    la va a tener, un pueblo de madera no suena a taiko—: sale de tres cosas
    que crecen a la vez. El registro sube compás a compás. La cama se abre de
    dos voces a cuatro. Y sobre todo **la figuración se va apretando**: una
    nota por compás al principio, dos en el desarrollo, cuatro y el pulso del
    bajo en lo alto. Es el mismo truco de cualquier passacaglia y funciona sin
    nada que golpee.

    Los tiempos están escritos contra los del reloj de la reproducción, que
    están en `lib/model/reel.dart`. La entrada dura lo que el valle está vacío,
    la última pieza cae al empezar el compás quince, y los dos últimos compases
    son el pueblo terminado sonando solo. Si alguno de los dos números se mueve,
    se mueven los dos."""
    sr = SR_HI
    bar, beat = 4 * 60 / 68.0, 60 / 68.0
    BARS = 17
    total = BARS * bar                      # sesenta segundos justos

    # Un acorde por compás. Re · Sim · Sol · La, que es la vuelta de siempre,
    # y la primera vez sin tercera: un valle en el que todavía no hay nada no
    # puede sonar ni alegre ni triste.
    chords = [
        [n('D2'), n('A3'), n('D4')],                                    # 0
        [n('D2'), n('A3'), n('D4'), n('F#4')],                          # 1
        [n('D2'), n('A3'), n('D4'), n('F#4')],                          # 2
        [n('B2'), n('F#3'), n('D4'), n('C#5')],                         # 3
        [n('G2'), n('B3'), n('D4'), n('F#4')],                          # 4
        [n('A2'), n('B3'), n('E4'), n('A4')],                           # 5
        [n('D2'), n('A3'), n('D4'), n('F#4')],                          # 6
        [n('B2'), n('F#3'), n('D4'), n('A4')],                          # 7
        [n('G2'), n('D4'), n('F#4'), n('B4')],                          # 8
        [n('A2'), n('E4'), n('A4'), n('C#5')],                          # 9
        [n('D2'), n('D4'), n('F#4'), n('A4')],                          # 10
        [n('B2'), n('D4'), n('F#4'), n('B4')],                          # 11
        [n('G2'), n('B3'), n('D4'), n('G4')],                           # 12
        [n('A2'), n('C#4'), n('E4'), n('A4')],                          # 13
        [n('B2'), n('D4'), n('F#4'), n('A4')],                          # 14
        [n('G2'), n('B3'), n('D4'), n('E4')],                           # 15
        [n('D2'), n('A2'), n('D3'), n('F#3'), n('A3'), n('D4')],        # 16
    ]

    # Cuánto abre la cama en cada compás. Es la curva entera de la pieza en una
    # sola línea: entra sola, crece, se planta arriba cuatro compases, y el
    # último se queda abierto de par en par.
    #
    # Los números de la primera versión iban de 0,34 a 1,00 y **no se oían**:
    # medida compás a compás, la pieza se plantaba en su volumen final en el
    # quinto y el clímax sonaba más bajo que el desarrollo. Dos errores a la
    # vez. El primero, que un tercio no es poco: hace falta bajar a la décima
    # parte para que la entrada suene a que no hay nada. El segundo, que abrir
    # la cama de dos voces a cuatro no la hace más grande — `stack` reparte la
    # amplitud entre las voces a propósito, para que desafinar no suba el
    # volumen —, así que todo aquel escalonado de voces engordaba el coro y
    # dejaba el tamaño donde estaba.
    swell = [.10, .17, .30, .34, .42, .50, .62, .70, .82, .92,
             1.00, 1.00, 1.00, 1.00, .84, .62, .74]
    voices = [2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 3, 3, 4]

    # Y lo que sí la hace más grande: en lo alto, la fundamental doblada una
    # octava abajo. Un acorde que crece hacia arriba se vuelve estridente; lo
    # que se siente como tamaño es que crezca hacia los dos lados.
    chords = [
        (c + [c[0] - 12]) if 10 <= i <= 13 else c
        for i, c in enumerate(chords)
    ]

    ln = int((total + 4.0) * sr)
    out = [0.0] * ln
    for b, notes in enumerate(chords):
        # El último dura hasta el final del archivo: es el que queda sonando.
        largo = (bar * 3.4) if b == BARS - 1 else (bar * 1.7)
        stack(out, notes, largo, sr, cut=720 + 90 * swell[b], spread=11,
              gain=0.80 * swell[b], rise=bar * 0.46, fall=bar * 1.05,
              at=b * bar, voices=voices[b], tilt=1.85)

    # La voz que canta. Un solo tema, dicho tres veces: entero, una quinta más
    # arriba, y en lo alto con las campanas encima. Que sea el mismo las tres
    # veces es lo que hace que la tercera se reconozca, y reconocer algo que
    # vuelve más grande es exactamente la sensación que se busca.
    tema = [
        # el tema, compases 2-5
        (8.0, 'F#4', 2.2, .70), (10.0, 'A4', 2.2, .66),
        (12.0, 'B4', 3.0, .74), (15.0, 'A4', 1.0, .52),
        (16.0, 'G4', 2.2, .70), (18.0, 'F#4', 2.0, .60),
        (20.0, 'E4', 3.6, .64),
        # otra vez, más arriba, compases 6-9
        (24.0, 'A4', 2.2, .74), (26.0, 'D5', 2.4, .72),
        (28.0, 'E5', 3.0, .78), (31.0, 'D5', 1.0, .56),
        (32.0, 'B4', 2.4, .74), (34.0, 'A4', 2.0, .64),
        (36.0, 'F#4', 3.6, .68),
        # y en lo alto, compases 10-13
        (40.0, 'D5', 2.6, .86), (42.5, 'F#5', 2.2, .82),
        (44.0, 'B4', 2.0, .72), (46.0, 'D5', 2.0, .74),
        (48.0, 'G4', 2.4, .80), (50.0, 'B4', 2.4, .76),
        (52.0, 'A4', 2.4, .82), (54.0, 'C#5', 2.0, .70),
        # la bajada, compases 14-16
        (56.0, 'B4', 3.2, .74), (59.0, 'A4', 2.0, .58),
        (60.0, 'G4', 2.6, .64), (62.0, 'F#4', 3.0, .58),
        (64.0, 'D4', 7.0, .70),
    ]
    for at, note, dur, vel in notes_of(tema, beat):
        # La misma curva que la cama: si la voz cantase siempre igual de
        # fuerte, en lo alto se quedaría debajo y al principio taparía el
        # silencio que hace falta que haya.
        b = min(BARS - 1, int(at / bar))
        breath(out, at, n(note), dur, vel * 0.34 * (0.45 + 0.55 * swell[b]),
               sr, seed=7)

    # Lo que aprieta: el arpegio de cada acorde, cada vez más seguido. Una por
    # compás hasta el 5, dos hasta el 9, cuatro arriba, y se abre la mano al
    # final. Nada de esto es una melodía y no tiene que serlo — es el motor.
    paso = [4.0] * 6 + [2.0] * 4 + [1.0] * 4 + [2.0, 2.0, 4.0]
    for b in range(BARS):
        notes = [x for x in chords[b] if x >= n('A3')] or chords[b][1:]
        k = 0
        t = 0.0
        while t < 4.0 - 1e-6:
            alto = notes[k % len(notes)]
            fuerte = 0.62 if t == 0.0 else 0.38
            tine(out, (b * 4.0 + t) * beat, alto, 2.3 * beat,
                 fuerte * swell[b] * 0.30, sr, bright=2.4, hold=1.5)
            t += paso[b]
            k += 1

    # El pulso del bajo, sólo en lo alto. Es lo más cerca de un tambor que hay
    # aquí, y es una nota grave con la nota tocada corta: un corazón, no un
    # golpe. Sin él los cuatro compases de arriba se quedan planos por mucho
    # que haya encima.
    for b in range(9, 15):
        raiz = chords[b][0]
        for p in range(4):
            vel = .50 if p == 0 else (.30 if p == 2 else .20)
            tine(out, (b * 4.0 + p) * beat, raiz, 1.4 * beat, vel * 0.26, sr,
                 bright=1.5, hold=0.55)

    # Y las campanas, que entran sólo cuando el tema llega arriba. Guardarlas
    # hasta el compás diez es lo que hace que la tercera vuelta se oiga más
    # grande sin tocar un solo volumen.
    luces = [
        (40.0, 'D6', 3.0, .44), (43.0, 'A5', 2.6, .36),
        (46.0, 'F#6', 3.0, .40), (49.0, 'D6', 2.6, .34),
        (52.0, 'E6', 3.0, .42), (55.0, 'C#6', 2.6, .32),
        (58.0, 'D6', 3.4, .38), (64.0, 'A5', 4.0, .30),
        (64.5, 'D6', 4.0, .26),
    ]
    for at, note, dur, vel in notes_of(luces, beat):
        bell(out, at, n(note), dur, vel * 0.26, sr)

    # Al papel. Lo mismo que las otras menos una cosa: **no se cierra el bucle**.
    # `finish` dobla la cola sobre el principio, que es justo lo que no se puede
    # hacer aquí — la última nota acabaría sonando encima de la primera.
    out = lowpass(out, 6200, sr, poles=1)
    # Menos sala que en las de fondo. Una cola larga rellena los huecos, y los
    # huecos del principio son el principio: con wet de 0,30 la entrada sonaba
    # tan llena como el clímax.
    out = reverb(out, sr, wet=0.23, size=1.9, dark=0.58)
    out = highpass(out, 38, sr)
    out = wow(out, sr, cents=4.0, cycles=(1, 3), seed=11)
    return saturate(out, 1.20)


# ------------------------------------------------------------------ escribir

def loudness(sig):
    """Cuánto suena cuando suena, no cuánto vale el archivo entero.

    Una capa de campanas con nueve segundos de silencio entre nota y nota tiene
    un valor eficaz bajísimo, y medirla así la dejaría siempre demasiado alta:
    el silencio le baja la nota. Así que se mide sólo por encima de un umbral,
    que es lo que hace cualquiera que mida sonoridad de verdad."""
    peak = max(abs(s) for s in sig) or 1.0
    gate = peak * 0.08
    loud = [s for s in sig if abs(s) > gate]
    if len(loud) < len(sig) // 50:
        loud = sig
    return math.sqrt(sum(s * s for s in loud) / max(1, len(loud)))


# Dónde queda cada capa en la mezcla, en sonoridad y no en pico. Es lo único
# que decide el equilibrio: los `gain` de la síntesis están puestos para que
# cada voz suene como esa voz, no para que suene a su volumen final.
BASE = {'pad': 0.130, 'keys': 0.150, 'air': 0.100}


def write(name, samples, sr, scale):
    peak = max(abs(s) for s in samples) * scale
    rms = loudness(samples) * scale
    frames = b''.join(
        struct.pack('<h', int(max(-32767, min(32767, s * scale * 32767))))
        for s in samples)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(frames)
    print('  %-20s %5.1f s  %5d Hz  %5d KB   pico %.2f  sonoridad %.3f'
          % (name, len(samples) / sr, sr, len(frames) / 1024, peak, rms))


# Se probaron cinco y quedaron dos. Las otras tres —bruma, caja, brasa— siguen
# aquí abajo escritas por si alguna vuelve, pero no se generan: un asset que no
# suena en ninguna parte son doscientos kilos de APK por nada.
PIECES = (('tarde', tarde), ('sendero', sendero))

# La de la cinemática va aparte porque no es lo mismo: no son tres capas que se
# mezclan según la hora, es una pieza entera que suena sola de principio a fin.
# Un archivo, y nada que sincronizar en el teléfono — tres reproductores
# arrancando a la vez se desfasan lo justo para que un acorde llegue partido.
SOLAS = (('cronica', cronica, 0.220),)

if __name__ == '__main__':
    import sys
    only = sys.argv[1:] or ([p for p, _ in PIECES] + [p for p, _, _ in SOLAS])
    for name, make in PIECES:
        if name not in only:
            continue
        print(name)
        layers = make()
        # El equilibrio queda escrito en el archivo y no repartido entre el
        # generador y el Dart, donde tarde o temprano una de las dos copias se
        # queda vieja. Cada capa se lleva a su sonoridad, y si con eso alguna
        # se pasa de pico, bajan las tres juntas: bajar sólo la que se pasa
        # sería deshacer el equilibrio que acabamos de poner.
        scales = [BASE[suffix] * rel / max(1e-9, loudness(sig))
                  for suffix, sig, _, rel in layers]
        top = max(max(abs(s) for s in sig) * k
                  for (_, sig, _, _), k in zip(layers, scales))
        guard = min(1.0, 0.90 / top)
        for (suffix, sig, sr, _), k in zip(layers, scales):
            write('mus_%s_%s.wav' % (name, suffix), sig, sr, k * guard)

    for name, make, target in SOLAS:
        if name not in only:
            continue
        print(name)
        sig = make()
        k = target / max(1e-9, loudness(sig))
        # Y que no se pase de pico, que en una pieza con un final abierto de
        # par en par es justo el último acorde el que se pasaría.
        k = min(k, 0.94 / max(1e-9, max(abs(s) for s in sig)))
        write('mus_%s.wav' % name, sig, SR_HI, k)
