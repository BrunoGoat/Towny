# Towny por dentro

Lo que hay debajo de [lo que se ve](README.md): el rasterizador, los sonidos,
cómo se compila y dónde está cada cosa.

Las decisiones de diseño —por qué no hay rachas, por qué se puede pausar, por
qué el segundo hábito se gana— están aparte, en [DESIGN.md](DESIGN.md).

## Cómo está hecho el render

Un rasterizador propio (`lib/engine/`), sin dependencias nativas, escrito
alrededor de tres reglas:

1. **Todo lo que se construye es un sólido cerrado.** No cáscaras. Un tejado
   tiene sus dos faldones, sus dos hastiales y su suelo.
2. **Dentro de un sólido cerrado no hace falta ordenar nada**: descartar las
   caras que miran para el otro lado es exacto desde cualquier ángulo. Cero
   heurística.
3. **Entre sólidos se ordena por geometría exacta, no por una media.** Un BSP por
   edificio, construido una vez cuando ese edificio gana una pieza y guardado; y
   entre edificios, un árbol de separación por planos. Donde dos sólidos se
   atraviesan de verdad, la geometría se corta **una vez al construir**, no se
   compensa cada cuadro.

No hay z-buffer ni ordenación por profundidad. El mundo es *append-only* y
estático: una pieza colocada no se mueve nunca, así que todo el trabajo caro se
hace cuando cae la pieza y no sesenta veces por segundo.

Hay un test (`test/depth_test.dart`) que recorre las estructuras del catálogo
desde un barrido de cámaras y exige que, para todo par de polígonos que se solapan
en pantalla, el que se pinta después no esté más lejos. Es exactamente el fallo
que se ve, comprobado por máquina, porque «se ve mal desde ciertos ángulos» a ojo
se escapa.

Sin z-buffer, **cualquier cosa pintada al final se pinta encima de todo**, y eso
incluye lo que no parece geometría. El resplandor de las ventanas encendidas se
pintaba así —una pasada de halos cálidos sobre el pueblo ya levantado— y el
resultado era que la luz de una ventana de la fila de atrás salía a través de la
casa de delante. Ahora cada halo va intercalado en el orden de pintado, justo
detrás de su ventana, y lo tapa lo que esté delante. Lo vigila
`test/lamp_test.dart`, que no compara con ninguna imagen guardada: cuenta
cuántos tonos distintos hay dentro de un tejado. Una cara plana se pinta de un
color plano, así que un degradado ahí dentro sólo puede venir de algo pintado
encima fuera de orden.

## Sonido

Cinco sonidos —poner una pieza, toque, reparar, obra terminada, hito del pueblo—
y dos temas de música de fondo, *Tarde* y *Sendero*, cada uno con su propio
reparto por hora del día: suena uno de los dos al abrir la app. Todo está
generado por `tool/make_sfx.py` y `tool/make_music.py`, no grabado.

Se escribieron cinco temas y se probaron los cinco durante un tiempo con un
selector en ajustes; quedaron dos. Los otros tres siguen escritos en
`tool/make_music.py` por si alguno vuelve, pero no se generan: un asset que no
suena en ninguna parte son doscientos kilos de APK por nada.

**El volumen de la música no sube en línea recta.** La mitad del deslizador
suena al quince por ciento, que es donde acaba quien la usa de verdad —es música
de fondo—, y de ahí al tope crece rápido para que subirla sirva de algo. La
curva es la potencia que pasa por esos dos puntos y sale de ellos, así que
cambiar cuánto suena la mitad la recalcula sola.

## Correr y compilar

```bash
flutter pub get
flutter test          # 498 tests
flutter analyze
flutter run
flutter build apk --release
```

### APK

Cada push a la rama de desarrollo compila la APK en GitHub Actions
(`.github/workflows/apk.yml`) y la publica como *release*. Va firmada **siempre
con la misma clave**, y el propio flujo lo verifica antes de publicar: es lo
único que permite instalar una build encima de la anterior sin perder los
pueblos. Android 7.0 (API 24) o superior.

> El certificado sigue diciendo `CN=La Muralla`, que es como se llamaba esto
> antes, y tiene que seguir diciéndolo. Renombrarlo sería cambiar de clave. Por
> lo mismo el `applicationId` sigue siendo `com.lamuralla.la_muralla` y el
> paquete de Dart, `la_muralla`.

### Herramientas de desarrollo

`--dart-define` para ver estados que de otro modo tardarían un año:

| define | para qué |
|---|---|
| `SEED=365` | arranca con esa cantidad de piezas |
| `IDLE_DAYS=13` | las coloca hace N días, para ver el deterioro |
| `REGION=2` | funda el pueblo en esa región |
| `VALLEY=300,120:9,40` | un valle entero: piezas y días parado por pueblo |
| `HOUR=19` | fija la hora del día (entero — `1.5` se ignora en silencio) |
| `GALLERY=1` | abre el expositor de estructuras en vez del pueblo |
| `CAM_YAW/CAM_PITCH/CAM_DIST/CAM_X/CAM_Z` | encuadre fijo |
| `BUDGET=340` | fija el presupuesto de detalle |

Y dentro de la app, en *Ajustes*: **el expositor**, con todo lo que el pueblo
sabe construir; **ver el pueblo a futuro**, con atajos a 100, 500 y 5000 piezas,
que es sólo una vista y no escribe nada; **tus datos**, para copiar el valle
entero y volver a meterlo; y **quitar la última pieza**, que dice qué leyenda se
va con ella antes de hacerlo.

```bash
python3 tool/make_sfx.py          # regenera los sonidos
python3 tool/make_music.py        # regenera la música
python3 tool/make_icons.py        # recorta el icono desde tool/icon/towny.png
```

Y cuatro que no prueban nada — son para **mirar y medir**, que es lo que los
tests no saben hacer:

```bash
flutter test tool/shot_test.dart          # la foto del README
flutter test tool/reel_frames_test.dart   # fotogramas de la cinemática a disco
flutter test tool/marks_sheet_test.dart   # el catálogo entero, de doce en doce
flutter test tool/doings_sheet_test.dart  # lo que hace la gente, cuatro instantes cada una
flutter test tool/vocab_sheet_test.dart   # las palabras del albañil, una por casilla
flutter test tool/bench_test.dart         # cuánto cuesta un fotograma, por etapas
flutter test tool/censo_test.dart         # cuánto cuesta poner cien piezas

flutter test tool/textos_test.dart        # y después:
python3 tool/textos.py                    # escribe TEXTOS.md con todo lo que se lee
```

`TEXTOS.md` es el inventario de **todas las frases que ve quien usa la app**,
con el sitio del que sale cada una. Se genera, no se escribe: la mitad la
vuelca el test —el catálogo de obras, los bandos, las comarcas, que son listas
de Dart y leerlas con una expresión regular es adivinar— y la otra mitad sale
de rastrear los literales de cada pantalla. Es lo que hay que mirar antes de
tocar una palabra, y lo que habrá que traducir el día que la app hable en otro
idioma.

Las tres hojas de contacto son para juzgar un catálogo, que es una cosa que no
se puede hacer de una en una: el expositor de la app enseña una obra —o un
vecino— y sirve para ver si *ése* está bien, y lo que hay que ver es si **se
distinguen entre sí**. La de la gente pone además cuatro instantes del mismo
gesto uno al lado de otro, porque lo que separa a dos actividades no es la
postura: es el movimiento, y una foto quieta no lo enseña. Con `--dart-define=SOLO=castillo,coso` se miran unas pocas, y con `GIRO`
y `REGION` las mismas desde otro lado o en otra comarca.

Los dos primeros existen porque los tests dicen que algo no se cae y que los
números salen bien, y ninguna de las dos cosas dice si está bien encuadrado. Los
otros dos son el cronómetro con el que se decide qué vale la pena optimizar,
porque a ojo siempre se acierta en lo que no es — y los fotogramas de la
cinemática sirven además de red: un refactor del render que cambie un solo píxel
se ve comparándolos con los de antes.

## Mapa del código

```
lib/
  core/      hash determinista y matemática 3D
  data/      hitos, regiones, marcas, constelaciones y temas de música
  model/     hábitos, piezas, leyendas, ritmo, hallazgos, persistencia
  engine/    el pueblo y cómo se dibuja
  fx/        partículas, sonido y vibración
  ui/        la pantalla, el botón, las hojas
```

Dentro de `engine/`, que es el más poblado:

| | |
|---|---|
| `town.dart`, `mason.dart`, `solids.dart` | qué se construye y de qué caras está hecho |
| `landmarks.dart` | las sesenta obras, cada una en una docena de líneas |
| `landmarks_retired.dart` | las que ya no se ofrecen y hay que saber levantar igual |
| `world.dart`, `bsp.dart` | en qué orden se pinta, resuelto una vez al poner la pieza |
| `scene.dart` | lo que hay que pintar, dicho antes de pintarlo |
| `renderer.dart` | el rasterizador: recortar, sombrear y rellenar caras |
| `backdrop.dart` | el cielo, el sol, el prado y las cordilleras |
| `tones.dart` | de qué color va el prado, la hoja, la nieve y lo que está lejos |
| `folk.dart`, `folk_body.dart`, `streets.dart` | quién vive ahí, de qué está hecho y por dónde anda |
| `sigils.dart` | las marcas de los hábitos, trazadas a mano |

El widget de la pantalla de inicio vive entero en `android/` —Kotlin, `RemoteViews`
y unas preferencias suyas— y habla con la app por un canal de tres verbos
(`lib/fx/widget_bridge.dart`): la app **publica** el resumen que hay que pintar,
el widget **apunta** los toques en su buzón, y la app **confirma** cuando ya
puso las piezas. Cada lado escribe sólo en lo suyo, que es lo que evita tener
que sincronizar dos procesos; y confirmar va aparte de leer para que morirse por
el medio no pueda ni perder una pieza ni contarla dos veces.

Hay dos reglas de forma que vigila `test/tree_test.dart` y no la buena voluntad:
a todo fichero de `lib/` se llega desde `main.dart` —un huérfano compila igual y
no se puede abrir desde la app— y **nada por debajo de `ui/` sabe que `ui/`
existe**, que es lo que deja probar el motor sin levantar Flutter.

Nada de la **forma** del pueblo se guarda en disco: se deriva del identificador
de cada pieza. Una casa levantada hace un año se vuelve a dibujar idéntica en
cada arranque. Lo que sí se guarda son las piezas con su fecha y su leyenda, los
hábitos, la crónica de obra de cada pueblo —lo que ya se decidió construir— y las
constelaciones vistas.
