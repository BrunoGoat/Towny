#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Escribe TEXTOS.md: todas las frases que ve quien usa la app.

    flutter test tool/textos_test.dart   # vuelca el catálogo a /tmp/towny
    python3 tool/textos.py               # arma TEXTOS.md

La mitad de los textos son listas de Dart —las obras, los bandos, las
comarcas— y ésas las escribe el test, que las importa de verdad. La otra
mitad son frases sueltas dentro de las pantallas, y ésas salen de leer el
código: se busca cada literal, se descartan los que no ve nadie
(identificadores, rutas, nombres de fuente) y se apunta en qué archivo, en
qué renglón y dentro de qué clase vive cada uno.

Nada de esto se escribe a mano: cambiar una frase y volver a generar tiene
que dar el inventario nuevo sin tocar nada más.
"""
import json, os, re


def sin_comentarios(src):
    """Quita comentarios pero deja los saltos de línea, para no perder la cuenta."""
    src = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), src, flags=re.S)
    out = []
    for l in src.split('\n'):
        out.append('' if l.strip().startswith('//') else l)
    return '\n'.join(out)

def literales(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in "'\"":
            triple = src[i:i+3] in ("'''", '"""')
            cierre = src[i:i+3] if triple else c
            j, buf = i + len(cierre), []
            while j < n:
                if src[j] == '\\':
                    buf.append(src[j:j+2]); j += 2; continue
                if src[j:j+len(cierre)] == cierre:
                    j += len(cierre); break
                if src[j:j+2] == '${':
                    k, prof = j + 2, 1
                    while k < n and prof:
                        if src[k] == '{': prof += 1
                        elif src[k] == '}': prof -= 1
                        elif src[k] in "'\"":
                            q = src[k]; k += 1
                            while k < n and src[k] != q:
                                k += 2 if src[k] == '\\' else 1
                        k += 1
                    buf.append(src[j:k]); j = k; continue
                buf.append(src[j]); j += 1
            out.append((''.join(buf), i)); i = j; continue
        i += 1
    return out

def visible(t):
    if len(t) < 2: return False
    if t.startswith('assets/') or t.startswith('package:'): return False
    if re.fullmatch(r'[a-z][A-Za-z0-9_]*', t): return False
    if re.fullmatch(r'[\W\d\s]+', t): return False
    sin = re.sub(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*', '', t).strip()
    if not sin: return False
    if re.fullmatch(r'[a-z][A-Za-z0-9_]*', sin): return False
    return (' ' in sin or re.search(r'[áéíóúñÁÉÍÓÚÑ¿¡]', sin)
            or (sin[0].isupper() and len(sin) > 2))

CLASE = re.compile(r'^(?:abstract )?class (\w+)')
# Una declaración de verdad lleva tipo delante del nombre. Sin eso, `Text(`
# y `Expanded(` se cuelan como si fueran métodos y el sitio deja de decir nada.
MIEMBRO = re.compile(
    r'^  (?:@override\s+)?(?:static |final |const |late )*'
    r'[\w<>,\?\[\]]+(?:<[^>]*>)?\s+(_?[A-Za-z]\w*)\s*\(')
SUELTO = re.compile(r'^(?:const|final|String|List|Map|Widget|void|bool|int|double)[\w<>,\s\?]* (\w+)\s*(?:=|\()')

def sitio(lineas, ln):
    clase = miembro = None
    for k in range(ln, -1, -1):
        l = lineas[k]
        if miembro is None:
            m = MIEMBRO.match(l)
            if m and m.group(1) not in ('return', 'if', 'for', 'while', 'switch'):
                miembro = m.group(1)
        if clase is None:
            m = CLASE.match(l)
            if m:
                clase = m.group(1)
                break
        if miembro is None:
            m = SUELTO.match(l)
            if m:
                miembro = m.group(1); break
    if clase and miembro: return f'{clase}.{miembro}'
    return clase or miembro or '—'

res = {}
for root, _, files in os.walk('lib'):
    for f in sorted(files):
        if not f.endswith('.dart'): continue
        p = os.path.join(root, f)
        src = sin_comentarios(open(p).read())
        lineas = src.split('\n')
        cortes = []
        acc = 0
        for l in lineas:
            cortes.append(acc); acc += len(l) + 1
        def linea_de(pos):
            lo, hi = 0, len(cortes) - 1
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if cortes[mid] <= pos: lo = mid
                else: hi = mid - 1
            return lo
        vistos, orden = {}, []
        for t, pos in literales(src):
            if not visible(t) or t in vistos: continue
            ln = linea_de(pos)
            vistos[t] = True
            orden.append({'t': t, 'l': ln + 1, 'd': sitio(lineas, ln)})
        if orden: res[p] = orden
ui = res
print(sum(len(v) for v in res.values()), 'frases encontradas en el código')

datos = open('/tmp/towny/datos.md').read()
out = []
A = out.append

A('# Todos los textos que ve quien usa la app')
A('')
A('Sacado del código, no escrito a mano: si mañana cambia una frase, se vuelve')
A('a generar y ya está.')
A('')
A('**Cómo leerlo.** Cada entrada lleva un código —`O12`, `B305`, `U77`— para que')
A('puedas decir «fuera B14, B92» sin copiar la frase. Debajo de cada bloque')
A('está *cuándo lo ve* quien usa la app, y cada línea de interfaz dice además')
A('en qué archivo y en qué renglón vive, por si querés mirarla en su sitio.')
A('')
A('Lo que **no** está: los identificadores internos (`pozo`, `libro`), los')
A('nombres de fuente (`RockSalt.ttf`), la hoja de pruebas y los comentarios.')
A('')
RESUMEN = len(out)
A('')

def bloque(titulo, cuando, cuerpo):
    A(f'\n## {titulo}\n')
    A(f'> **Cuándo se ve.** {cuando}\n')
    A(cuerpo)

# ----------------------------------------------------------------- el mundo
sec, actual = {}, None
for ln in datos.split('\n'):
    if ln.startswith('## '):
        actual = ln[3:]; sec[actual] = []
    elif actual:
        sec[actual].append(ln)

def numera(pref, lineas):
    n, res = 0, []
    for ln in lineas:
        if ln.startswith('- '):
            n += 1
            res.append(f'- **{pref}{n}** · {ln[2:]}')
        elif ln.strip():
            res.append(ln)
    return '\n'.join(res), n

MUNDO = [
 ('OBRAS (60)', 'O', 'Las obras del catálogo (60)',
  'El **nombre** sale en tres sitios: en la tarjeta de elegir cuando el pueblo '
  'va a empezar una obra, en el cartel que flota sobre ella mientras se '
  'construye, y en la bitácora. La **frase** se dice una sola vez, el día que '
  'la obra se remata, y también se lee en la tarjeta de elegir y en el '
  'expositor. Una obra llega cada dos o tres semanas.'),
 ('OBRAS RETIRADAS (53)', 'R', 'Las obras retiradas (53)',
  'Ya no se ofrecen a nadie, pero siguen en pie en los pueblos que las '
  'levantaron antes de la poda: ahí su nombre sigue saliendo en el cartel y en '
  'la bitácora. Si decidís que los pueblos viejos se rehagan sin ellas, estas '
  '106 frases se van enteras.'),
 ('CASAS CORRIENTES (7)', 'C', 'Las casas corrientes (7)',
  'El nombre de un edificio que no es un hito. Se ve al tocar una casa y en el '
  'expositor de estructuras. Cada comarca puede llamarlas a su manera —las 42 '
  'variantes están en el bloque siguiente—.'),
 ('COMARCAS (6)', 'M', 'Las comarcas (6)',
  'Cuando fundás un hábito elegís comarca: ahí se lee el nombre en mayúsculas '
  'y la descripción debajo. Después el nombre vuelve a salir en el expositor y '
  'en el de la gente. Las líneas sangradas son cómo llama esa comarca a cada '
  'clase de casa.'),
 ('CONSTELACIONES (8)', 'E', 'Las constelaciones (8)',
  '**Hoy no se ve ninguna de estas palabras.** Las figuras se dibujan en el '
  'cielo y se tocan, pero dejaron de anotarse y con ellas dejó de leerse su '
  'nombre. Son 24 frases que o vuelven a usarse o se borran.'),
 ('BANDOS DEL TABLÓN (436)', 'B', 'Los bandos del tablón (436)',
  'Los papeles clavados en el tablón de la plaza: un titular y un renglón '
  'debajo. Cambian cada día y salen de la fecha, así que cada día hay un par '
  'distinto. Ninguno habla de vos — eso lo dice el tablón por su cuenta, en el '
  'bloque «lo que el tablón dice de vos». **Es el bloque más grande de la app '
  'y el más fácil de recortar.**'),
]
for clave, pref, titulo, cuando in MUNDO:
    cuerpo, n = numera(pref, sec[clave])
    bloque(titulo, cuando, cuerpo)

# ------------------------------------------------------------------ la gente
src = open('lib/data/folknames.dart').read()
dados = re.findall(r"\('([^']+)', (?:true|false)\)", src)
oficios = re.findall(r"\('([^']+)', '([^']+)'\)", src)
sitios = re.findall(r"^  '([^']+)',$", src, re.M)
bloque(f'Los nombres de la gente ({len(dados)}+{len(oficios)}+{len(sitios)})',
  'Cada vecino nace con nombre el día que se remata su casa, y ya no cambia. '
  'Se lee al tocar a alguien en el pueblo y en el expositor de la gente: «Mar '
  'la tejedora», «Sancho de Aguilar». **Son nombres propios: no se traducen.** '
  'Si un idioma quiere los suyos, se cambian por otros, no se traducen éstos.',
  '**De pila** — ' + ', '.join(dados) + '\n\n'
  '**Oficios** — ' + ', '.join(f'{a} / {b}' for a, b in oficios) + '\n\n'
  '**Procedencias** — ' + ', '.join(sitios))

bloque('Lo que hace la gente (6)',
  'Debajo del nombre, en el expositor de la gente: «Mar la tejedora **barre el '
  'umbral**». Hay noventa maneras de moverse pero sólo estas seis tienen frase '
  'escrita; las demás se nombran solas.',
  '\n'.join(f'- **G{i+1}** · {e["t"]}' for i, e in enumerate(ui['lib/data/doings.dart'])))

bloque(f"Los símbolos de hábito ({len(ui['lib/data/symbols.dart'])})",
  'La marca que lleva un hábito. Se lee al elegirla, en la cuadrícula de '
  'símbolos de la hoja de hábitos.',
  '\n'.join(f'- **S{i+1}** · {e["t"]}' for i, e in enumerate(ui['lib/data/symbols.dart'])))

bloque(f"Lo que el tablón dice de vos ({len(ui['lib/model/findings.dart'])})",
  'El tablón del pueblo, la parte que sí habla de vos: cuándo queda en pie lo '
  'que estás construyendo, a qué hora sueles poner la pieza, qué pasa el día '
  'después de fallar. Se calcula con tus datos y cambia solo. `${...}` es un '
  'hueco que se rellena con un número, una fecha o un nombre.',
  '\n'.join(f'- **T{i+1}** · `{e["t"]}`  <sub>:{e["l"]}</sub>'
            for i, e in enumerate(ui['lib/model/findings.dart'])))

# --------------------------------------------------------------- la interfaz
FUERA = {'lib/core/math3.dart', 'lib/engine/folk.dart', 'lib/engine/town.dart',
         'lib/model/findings.dart', 'lib/ui/debug_sheet.dart'}

PANTALLAS = [
 ('lib/ui/first_run.dart', 'La primera vez',
  'La pantalla que sale una sola vez, al abrir la app por primera vez: fundar '
  'el primer pueblo, ponerle nombre y elegir marca.'),
 ('lib/ui/home_screen.dart', 'La pantalla de inicio',
  'El pueblo y todo lo que se abre desde él. Estas frases son las de los '
  'diálogos y los avisos que lanza.'),
 ('lib/ui/home_chrome.dart', 'Los rótulos de arriba y del costado',
  'El nombre del hábito, la cuenta de piezas y los botones de la columna '
  'derecha: siempre a la vista.'),
 ('lib/ui/hold_button.dart', 'El botón de poner una pieza',
  'El botón grande de abajo. Dice SOSTENÉ mientras mantenés el dedo y EN OBRA '
  'cuando la pieza ya está puesta.'),
 ('lib/ui/habit_bar.dart', 'La fila de hábitos',
  'La fila de marcas de abajo, para cambiar de pueblo.'),
 ('lib/ui/habits_sheet.dart', 'La hoja de hábitos',
  'Crear un hábito, cambiarle el nombre, la marca o la comarca, y pausarlo.'),
 ('lib/ui/choice_sheet.dart', 'La tarjeta de elegir obra',
  'La única vez que la app te pregunta algo: cada vez que el pueblo va a '
  'empezar un hito, entre dos.'),
 ('lib/ui/town_view.dart', 'El pueblo en escena',
  'Carteles y avisos que se pintan dentro de la escena, encima del pueblo.'),
 ('lib/ui/overlays.dart', 'Lo que se dice al terminar algo',
  'La tarjeta que aparece el día que se remata una obra, con su frase.'),
 ('lib/ui/notice_board.dart', 'El tablón: escribir y quitar',
  'Lo que sale al tocar el tablón de la plaza: escribir una nota, borrarla.'),
 ('lib/ui/board_scene.dart', 'El tablón: mover una nota',
  'Lo que aparece al dejar una nota apretada para cambiarla de sitio.'),
 ('lib/ui/legends_book.dart', 'La bitácora',
  'El cuaderno con una entrada por pieza puesta, fechada.'),
 ('lib/ui/legend_card.dart', 'La ficha de una pieza',
  'Lo que sale al tocar una pieza concreta del pueblo.'),
 ('lib/ui/papyrus.dart', 'Las fechas en pergamino',
  'Cómo se escriben los días y los meses en la bitácora: números romanos y '
  'meses con nombre.'),
 ('lib/ui/reel_screen.dart', 'La cinemática',
  'La película de cómo se construyó el pueblo, y la que sale al entrar cuando '
  'pusiste piezas desde el widget.'),
 ('lib/ui/gallery_screen.dart', 'El expositor de estructuras',
  'En ajustes: todo lo que el pueblo sabe construir, de una en una.'),
 ('lib/ui/folk_gallery_screen.dart', 'El expositor de la gente',
  'En ajustes: todos los vecinos, con su nombre y lo que están haciendo.'),
 ('lib/ui/rest_sheet.dart', 'Pausar un hábito',
  'Poner un pueblo en pausa por una semana, dos o un mes, sin que se deteriore.'),
 ('lib/ui/adrift_sheet.dart', 'El pueblo a la deriva',
  'Lo que dice la app cuando volvés después de mucho tiempo y el pueblo se '
  'apagó.'),
 ('lib/ui/unlock_sheet.dart', 'El segundo hábito',
  'Lo que se lee cuando se abre el sitio para un segundo pueblo en el valle.'),
 ('lib/ui/backup_sheet.dart', 'Tus datos',
  'En ajustes: copiar el valle entero al portapapeles y volver a meterlo.'),
 ('lib/ui/settings_sheet.dart', 'Ajustes',
  'Todo lo de la hoja de ajustes: sonido, hora, año, avisos, y los atajos de '
  'desarrollo del final.'),
 ('lib/ui/note_font.dart', 'Las letras del tablón',
  'Elegir con qué letra se escriben las notas. Sólo los nombres en castellano '
  'se leen; los que parecen ingleses son el nombre técnico de la fuente.'),
 ('lib/ui/style.dart', 'Estilo', 'Un mensaje de error para quien programa.'),
 ('lib/main.dart', 'El arranque',
  'El nombre de la app y lo que se ve mientras carga.'),
 ('lib/model/store.dart', 'Mensajes del guardado',
  'Lo que contesta la app al pegar una copia del valle, y los nombres por '
  'defecto de un hábito.'),
 ('lib/model/habit.dart', 'Un hábito sin nombre',
  'El nombre que lleva un hábito si no le pusiste ninguno.'),
 ('lib/model/board.dart', 'El tablón por dentro',
  'Los encabezados de las secciones del tablón.'),
 ('lib/fx/sensory.dart', 'Los sonidos',
  'Los nombres de cada sonido, que se leen en la lista de ajustes de sonido.'),
 ('lib/data/tunes.dart', 'Las músicas',
  'El nombre de cada pieza de música y de qué está hecha.'),
 ('lib/engine/season.dart', 'Las estaciones',
  'Invierno, primavera, verano y otoño, en ajustes y en el tablón.'),
]

A('\n## La interfaz, pantalla por pantalla\n')
A('> Cada línea dice el archivo, el renglón y la clase donde vive, así:')
A('> `home_screen.dart:340 · _HomeScreenState`.\n')
n = 0
hechas = set()
def util(p, t):
    if p == 'lib/ui/note_font.dart':
        return not (t.endswith('.ttf') or re.fullmatch(r'[A-Z][A-Za-z]+', t))
    return True

for p, titulo, cuando in PANTALLAS:
    if p not in ui or p in FUERA: continue
    hechas.add(p)
    A(f'\n### {titulo}\n')
    A(f'{cuando}\n')
    for e in ui[p]:
        if not util(p, e['t']): continue
        n += 1
        corto = p.split('/')[-1]
        A(f'- **U{n}** · `{e["t"]}`  <sub>{corto}:{e["l"]} · {e["d"]}</sub>')

restos = [p for p in ui if p not in hechas and p not in FUERA
          and not p.startswith('lib/data/')
          and p not in ('lib/model/nudge.dart', 'lib/fx/notifier.dart')]
if restos:
    A('\n### Sueltas\n')
    A('Frases que no caen en ninguna pantalla concreta.\n')
    for p in sorted(restos):
        for e in ui[p]:
            n += 1
            corto = p.split('/')[-1]
            A(f'- **U{n}** · `{e["t"]}`  <sub>{corto}:{e["l"]} · {e["d"]}</sub>')

# ------------------------------------------------------------ fuera de la app
avisos = [('nudge.dart', e) for e in ui.get('lib/model/nudge.dart', [])] + \
         [('notifier.dart', e) for e in ui.get('lib/fx/notifier.dart', [])]
bloque(f'Las notificaciones ({len(avisos)})',
  'Lo único que la app te dice cuando no la estás mirando. Como mucho dos por '
  'ausencia, y ninguna si no te retrasás. Las de `notifier.dart` son el nombre '
  'y la explicación del canal de avisos de Android, que se leen en los ajustes '
  'del teléfono.',
  '\n'.join(f'- **N{i+1}** · `{e["t"]}`  <sub>{f}:{e["l"]}</sub>'
            for i, (f, e) in enumerate(avisos)))

xml = open('android/app/src/main/res/values/towny_widget_strings.xml').read()
w = re.findall(r'<string name="([^"]+)">([^<]*)</string>', xml)
bloque(f'El widget de Android ({len(w) + 1})',
  'El cuadrito de la pantalla de inicio del teléfono. `label` y `name` son el '
  'nombre del widget en la bandeja, `about` la descripción que se lee al '
  'elegirlo, `confirm` el botón que aparece tras el primer toque y `empty` lo '
  'que dice cuando todavía no hay ningún pueblo.',
  '\n'.join(f'- **W{i+1}** · [{k}] {v}' for i, (k, v) in enumerate(w)) +
  '\n- **W6** · [nombre de la app, en el lanzador] Towny')

# --------------------------------------------------------------- el resumen
texto = '\n'.join(out)
cuenta = lambda p: len(re.findall(rf'^- \*\*{p}\d+\*\*', texto, re.M))
tabla = ['## Resumen\n',
 '| Bloque | Entradas | Frases | ¿Se traduce? |',
 '|---|---|---|---|',
 f'| Obras del catálogo | {cuenta("O")} | {cuenta("O")*2} | sí |',
 f'| Obras retiradas | {cuenta("R")} | {cuenta("R")*2} | sí, si se quedan |',
 f'| Casas corrientes | {cuenta("C")} | {cuenta("C")} | sí |',
 f'| Comarcas | {cuenta("M")} | {cuenta("M")*2} + 42 | sí |',
 f'| Constelaciones | {cuenta("E")} | {cuenta("E")*3} | **hoy no se ven** |',
 f'| Bandos del tablón | {cuenta("B")} | {cuenta("B")*2} | sí — el grueso |',
 f'| Lo que el tablón dice de vos | {cuenta("T")} | {cuenta("T")} | sí |',
 f'| Nombres de la gente | 87 | 87 | no: nombres propios |',
 f'| Lo que hace la gente | {cuenta("G")} | {cuenta("G")} | sí |',
 f'| Símbolos de hábito | {cuenta("S")} | {cuenta("S")} | sí |',
 f'| La interfaz | {cuenta("U")} | {cuenta("U")} | sí |',
 f'| Notificaciones | {cuenta("N")} | {cuenta("N")} | sí |',
 f'| Widget de Android | {cuenta("W")} | {cuenta("W")} | sí |',
 '',
 f'**{sum(cuenta(x) for x in "ORCMEBTGSUNW") + 87} entradas**, que son unas '
 f'{cuenta("O")*2 + cuenta("R")*2 + cuenta("C") + cuenta("M")*2 + 42 + cuenta("E")*3 + cuenta("B")*2 + cuenta("T") + 87 + cuenta("G") + cuenta("S") + cuenta("U") + cuenta("N") + cuenta("W")} '
 'frases sueltas. Sin las retiradas y sin los bandos se quedan en unas 700.',
 '']
out[RESUMEN:RESUMEN] = tabla
open('TEXTOS.md','w').write('\n'.join(out) + '\n')
print('TEXTOS.md:', len(open('TEXTOS.md').read().split('\n')), 'líneas')
