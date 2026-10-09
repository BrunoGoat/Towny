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

### Lo que no se pinta

El coste de un fotograma es **lineal en caras**, así que la única optimización
que sirve es no tocarlas. Dos redes, ninguna de las cuales toca el orden —eso
lo siguen decidiendo los planos, que es lo que costó arreglar en su día—:

- **La cara que cae entera fuera del lienzo no se guarda.** Medido con la
  cámara donde la pone la app, **la mitad de las caras de un fotograma no
  tocan ni un píxel**: 1 741 de 3 378 con doscientas piezas. El recorte contra
  el plano cercano ya pasó cuando se mide, así que la proyección es finita y un
  polígono convexo cabe en el rectángulo de sus vértices: si ese rectángulo no
  toca el lienzo, el polígono tampoco.
- **El edificio que no toca la pantalla no se recorre.** Lo mismo con la caja
  del grupo entero, con un margen de ciento diez píxeles — que no es prudencia
  de borde: es que una ventana encendida deja un halo de cien píxeles de radio
  y un edificio que se salió por el canto todavía puede estar alumbrando
  dentro.

Lo garantiza `test/clip_test.dart`, y lo garantiza de la única manera que vale
para esto: **pinta la misma escena con el recorte y sin él y exige cero píxeles
de diferencia** — ocho ángulos, tres distancias, de noche con las ventanas
encendidas, a ras del suelo y a plomo, un valle de seis pueblos y las sesenta
obras del catálogo de cerca. No es «no se nota»: es que es
el mismo fotograma.

Y hay una tercera, ésta al construir y no al pintar: **la cara enterrada no se
archiva**. Un pueblo es piedra apilada —el suelo de un piso contra el techo del
de abajo, la casa sobre su zócalo, el zócalo sobre la tierra— y todas esas
caras se cortaban, se ordenaban y se pintaban sin haberse visto jamás. Se
descartan dos clases, las dos exactas: la que mira hacia abajo y está en la
tierra (la cámara no baja del horizonte), y la que está pegada contra una caja
maciza que la cubre entera. Una de cada cuatro caras antes de cortar, que
después de cortar son un 13% menos de caras y un 20% menos de tiempo de
levantar el pueblo.

**Sólo tapa lo que es más viejo.** La pieza que está cayendo se dibuja aparte,
levantada en el aire, y si al archivarse hubiera borrado la cara de debajo, el
agujero se vería durante todo el vuelo. Se cumple por partida doble: se archiva
en orden, así que cuando le toca a una cara la pieza que la taparía todavía no
existe; y además se compara la edad. Lo fija una prueba con una obra escrita a
mano para eso — una caja angosta y encima otra que la desborda — porque en el
catálogo de verdad ese caso no se da y se daría el día que se escriba una obra
que lo tenga.

Esta última **no da cero píxeles**, y conviene saber por qué antes de mirar el
número: cada cara lleva un trazo de un píxel alrededor para cerrar la costura
con sus vecinas, y las enterradas lo llevaban también — el culo de una casa
dejaba un pelo de su color en la línea donde toca la hierba. Al no archivarlas
ese pelo desaparece, y con otras caras el árbol corta por otro sitio y los
bordes suavizados se mueven medio píxel. Lo que la prueba exige entonces es
**cuánto** cambia cada píxel y no cuántos: hasta ahí llega una costura, y un
agujero —una pared que falta, piedra que pasa a hierba— no cabe en ese margen.

### Una sola llamada de dibujo

Lo que queda después de no pintar lo que no se ve es pintar lo que sí, y eso
costaba **dos llamadas por cara**: el relleno y un trazo de un píxel alrededor
para cerrar la costura con las vecinas. A doscientas piezas son casi siete mil
llamadas por fotograma, y ahí se iban **dos tercios del tiempo**.

Ahora las caras se convierten en triángulos —una cara convexa es un abanico
desde su primer vértice— y se mandan todas juntas con el color en cada
vértice. **El orden no corre peligro**, que es lo primero que hay que
preguntarle a esto: los triángulos se rasterizan en el orden de la lista, uno
encima de otro, exactamente igual que las llamadas sueltas. No hay z-buffer ni
reordenamiento, y quien decide el orden sigue siendo el árbol de planos; lo
único que cambia es cómo se entrega una lista que ya venía ordenada. Las
lámparas parten la tanda, porque van con otro modo de fusión y en su sitio.

La costura desaparece sin hacer falta: dos triángulos que comparten vértices
exactos no dejan pelo entre ellos. Lo que cambia en la imagen es justamente lo
contrario de un fallo — el trazo de un píxel **sobresalía** medio píxel del
contorno de cada cara, y ese halo del color de la cara ya no está. Medido a
resolución de teléfono, el 4% de los píxeles cambia y casi todo son esos
medios píxeles de contorno; las láminas puestas una al lado de otra son
indistinguibles.

Cuando aun así no llega, hay un presupuesto de caras que el termostato de
`town_view.dart` sube y baja con lo que tarde el fotograma. **Se gasta por lo
que ocupa cada edificio en la pantalla, y el pueblo que se está mirando va
primero.** Antes se gastaba de cerca a lejos, que con el teléfono justo hacía
desaparecer medio pueblo de golpe y por detrás; ahora lo primero que se cae de
la lista es el caserón de doce píxeles del pueblo de al lado. El suelo son
nueve mil caras en pantalla —un pueblo de trescientas piezas entero— y sube más
rápido de lo que baja, porque de los dos errores posibles, enseñar de menos es
el que se nota.

Lo que **no** vale la pena, medido: cachear el color de las caras. Calcular el
tono, el sombreado y la bruma de cada cara cuesta, a doscientas piezas,
**−0,07 ms de un fotograma de 4,7** — o sea nada. Pintar el pueblo entero de un
gris plano no lo hace más rápido.

### El pueblo se levanta en otro hilo

Cortar y ordenar un pueblo de doscientas piezas cuesta unos **280 ms** —tres
tercios parejos: sacar los sólidos, cortar los ochenta grupos, y ordenarlos
entre sí— y se pagaban en el primer fotograma que lo pedía, o sea al abrir la
app. No hay forma de que eso sea barato; sí de que no lo pague el hilo de la
pantalla.

`warmTown` se lo encarga a otro isolate mientras sigue puesta la pantalla de
apertura, que es un valle sin pueblo, que es exactamente lo que hay mientras
tanto. Cuando vuelve queda en la caché de siempre, así que el primer fotograma
que pregunte lo encuentra hecho. Los otros pueblos del valle se encargan
después sin esperar a nadie, para que subir a mirarlo tampoco cueste.

**Un plano no se puede mandar a otro hilo**: lleva dentro el catálogo de obras,
y una obra es una receta, o sea una función. Lo que se manda es el encargo
—ocho datos planos— y el plano se levanta del otro lado. Dos planos del mismo
encargo son el mismo plano pieza por pieza, y `townOrder` es el único sitio
donde se arma un encargo justamente para que la vista y el arranque no puedan
pedir cosas distintas.

Y si algo sale mal del otro lado no pasa nada: la caché sigue vacía y el
fotograma lo levanta como antes. Es más: un pueblo que volviera equivocado
tampoco se usaría, porque lo guardado lleva la firma de las piezas con las que
se levantó y el fotograma la comprueba. Por eso las dos pruebas de
`warm_test.dart` son dos y no una: la de la huella dice que lo que se pinta es
idéntico a lo de aquí, y la del reloj dice que **se usó** — si hubiera vuelto
mal, el primer fotograma tardaría lo que tardaba antes.

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
flutter test          # 741 tests
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

> **Del nombre viejo no queda nada.** Esto se llamó La Muralla antes de ser
> Towny, y el rastro que quedaba —el paquete de Dart, el `applicationId`, el
> paquete de Kotlin, la clave de firma, los identificadores de iOS y las claves
> viejas del cajón— se fue entero. Hoy es `com.towny.app` en los dos sistemas,
> el paquete de Dart es `towny` y el certificado dice `CN=Towny`.
>
> Se pudo hacer porque la app no está publicada y la única copia instalada era
> la de quien la escribe. **Cambiar el `applicationId` o la clave de firma no
> renombra una app: la build siguiente se instala al lado de la anterior, con
> el valle vacío, y la vieja se queda con los pueblos.** Fue una decisión
> tomada sabiendo eso, con una copia sacada antes desde *el viaje → Tus datos*.
>
> A partir de aquí las tres vuelven a ser intocables, y por lo mismo. El día
> que esto se publique, además, la clave sale del repositorio o pasa a ser la
> de Play.

### Herramientas de desarrollo

`--dart-define` para ver estados que de otro modo tardarían un año:

| define | para qué |
|---|---|
| `SEED=365` | arranca con esa cantidad de piezas |
| `IDLE_DAYS=13` | las coloca hace N días, para ver la vuelta |
| `REGION=2` | funda el pueblo en esa región |
| `VALLEY=300,120:9,40` | un valle entero: piezas y días parado por pueblo |
| `HOUR=19` | fija la hora del día (entero — `1.5` se ignora en silencio) |
| `GALLERY=1` | abre el expositor de estructuras en vez del pueblo |
| `CAM_YAW/CAM_PITCH/CAM_DIST/CAM_X/CAM_Z` | encuadre fijo |
| `BUDGET=340` | fija el presupuesto de detalle |

Y dentro de la app, en *Ajustes*: **el expositor**, con todo lo que el pueblo
sabe construir; **ver el pueblo a futuro**, con atajos a 100, 500 y 5000 piezas,
que es sólo una vista y no escribe nada; **tus datos**, para copiar el valle
entero y volver a meterlo; y **quitar la última pieza**.

```bash
python3 tool/make_sfx.py          # regenera los sonidos
python3 tool/make_music.py        # regenera la música
python3 tool/make_icons.py        # recorta el icono desde tool/icon/towny.png
```

Y unos cuantos que no prueban nada — son para **mirar y medir**, que es lo que
los tests no saben hacer:

```bash
flutter test tool/shot_test.dart          # la foto del README
flutter test tool/reel_frames_test.dart   # fotogramas de la cinemática a disco
flutter test tool/marks_sheet_test.dart   # el catálogo entero, de doce en doce
flutter test tool/doings_sheet_test.dart  # lo que hace la gente, cuatro instantes cada una
flutter test tool/vocab_sheet_test.dart   # las palabras del albañil, una por casilla
flutter test tool/chrome_shot_test.dart   # la pantalla a varias horas y la tarjeta de elegir
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
tocar una palabra. Lista el castellano, que es el original: la versión inglesa
de cada cosa está al lado, en `lib/l10n/`.

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
  model/     hábitos, piezas, ritmo, hallazgos, persistencia
  engine/    el pueblo y cómo se dibuja
  fx/        partículas, sonido y vibración
  l10n/      el idioma de ahora, las fechas y los catálogos en inglés
  ui/        la pantalla, el botón, las hojas
```

**Los dos idiomas.** La app habla castellano e inglés. Las frases sueltas van
escritas en su sitio con las dos versiones juntas —`tr('Fundar mi pueblo',
'Found my town')`, de `l10n/lang.dart`—; los catálogos largos —obras, bandos,
comarcas, marcas— tienen su versión inglesa al lado en `l10n/en_*.dart`, por id
o en el mismo orden, y `test/english_test.dart` falla si falta una o si al abrir
las pantallas en inglés se cuela una palabra en castellano. Sin idioma elegido
en Ajustes, manda el del teléfono; los tests no pasan por `main()` y hablan
castellano. El widget de Android sigue al teléfono (`values/` en inglés,
`values-es/` en castellano).

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
| `cinema.dart` | la calidad máxima: sombras proyectadas, resplandor, rayos de sol y color |
| `tones.dart` | de qué color va el prado, la hoja, la nieve y lo que está lejos |
| `folk.dart`, `folk_body.dart`, `streets.dart` | quién vive ahí, de qué está hecho y por dónde anda |
| `sigils.dart` | las marcas de los hábitos, trazadas a mano |

De `model/`, los dos que hacen falta conocer:

`works_log.dart` fecha las obras. No guarda nada: cruza la crónica con el plan
para saber en qué pieza empieza y acaba cada hito, y de ahí saca las fechas de
las piezas de sus extremos. Lo usa la tarjeta del día en que se remata una obra.

`pledge.dart` son las tres cosas que no se deducen de las piezas —el plan, la
identidad y la regla— y todo lo que se puede decir de ellas: cómo se lee cada una
en voz alta, a qué hora aparecés de verdad, cuánto se cumple el plan y cuánto la
regla. Los campos viven en `Habit` (`vowHour`, `vowPlace`, `identity`,
`afterId`), las frases y las cuentas viven aquí, y las notas que salen de ellas
en `findings.dart` como cualquier otra. La regla se guarda contra el
**identificador** del otro hábito, así que renombrarlo no la rompe y borrarlo la
deshace sin que nadie tenga que limpiar nada.

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
cada arranque. Lo que sí se guarda son las piezas con su fecha, los
hábitos —con las cuatro líneas que escribiste y el plan—, la crónica de obra de
cada pueblo —lo que ya se decidió construir— y las constelaciones vistas.
