# Pendientes

Lo que está empezado, lo que está medido y lo que está decidido a medias, para
que no se pierda entre sesiones. Cada cosa dice **en qué punto está** y **qué
hace falta para seguir**.

---

## 1. Que la app hable otros idiomas

**En qué punto está.** El inventario está hecho y es lo que hay que mirar
antes de escribir una línea de código: **`TEXTOS.md`**, con las 1.187 entradas
—unas 1.800 frases— que ve quien usa la app, agrupadas por dónde salen y con
archivo, renglón y clase de cada una. No está escrito a mano: se regenera con

```bash
flutter test tool/textos_test.dart    # vuelca el catálogo a /tmp/towny
python3 tool/textos.py                # escribe TEXTOS.md
```

**Qué falta para seguir: decidir qué se borra.** Son más frases de las que
parecía, y de ahí salió la pausa. Las cuentas, para poder decidir:

| Bloque | Frases | Nota |
|---|---|---|
| Bandos del tablón | 872 | **El 48% de todo.** Costumbrismo de pueblo castellano: es lo más caro de traducir y lo que peor viaja |
| Obras del catálogo | 120 | Nombre + la frase que se dice el día que se remata |
| Obras retiradas | 106 | Sólo las ven los pueblos que ya las levantaron |
| La interfaz entera | 347 | Las 35 pantallas |
| Lo que el tablón dice de vos | 90 | Con huecos: números, fechas, nombres |
| Símbolos de hábito | 72 | Etiquetas del selector de marcas |
| Nombres de la gente | 87 | **No se traducen**: son nombres propios |
| Constelaciones | 24 | **Hoy no se leen en ningún sitio** |
| Comarcas, casas, sonidos, música, avisos, widget | ~90 | |

**Sin los bandos y sin las retiradas, un idioma son unas 700 frases.** Con
todo, 1.800.

**Tres decisiones que hay que tomar antes de empezar:**

1. **Los bandos.** Todos, ninguno, o una tanda de 150 que se reparta entre
   ellos — el tablón cambia igual cada día y nadie cuenta cuántos hay.
2. **Los nombres de la gente.** «Sancho de Aguilar» en una app en inglés no
   está mal: es un pueblo castellano. Pero si se quiere que el pueblo sea de
   quien lo juega, cada idioma necesita su propia lista de 49 nombres, 24
   oficios y 14 procedencias. Es una decisión de diseño, no de traducción.
3. **Las 24 palabras de las constelaciones.** O vuelven a usarse, o se borran:
   traducirlas a cinco idiomas es pagar por algo que no se ve.

**El plan, cuando haya decisión.** Un archivo por idioma con las frases, `es`
como original, y la interfaz pidiendo cada frase por su código en vez de
llevarla escrita dentro. Con una prueba que falle si un idioma se deja una
frase sin traducir — que es la única manera de que no se pudra sola.

---

## 2. Deuda medida

### Lo que queda del render

Hecho ya: tirar lo que no toca la pantalla y un presupuesto que recorta por
tamaño en pantalla en vez de por distancia (`ARCHITECTURE.md`). Con eso el
fotograma baja entre un 20 % y un 45 % según el encuadre. Lo que sigue sobre la
mesa, con lo medido al lado:

- **Una sola llamada de dibujo.** Hoy cada cara son dos `drawPath` con
  antialias —el relleno y la costura que tapa el pelo entre caras vecinas—, y
  eso es **dos tercios del fotograma**. Juntarlas todas en un `drawVertices`
  con color por vértice deja 11,5 ms en 4,4 a doscientas piezas, y 19,1 en 7,6
  a seiscientas. El orden no corre peligro: los triángulos se rasterizan en el
  orden de la lista, igual que las llamadas sueltas. Lo que sí cambia es que
  se pierde el suavizado por primitiva, así que **hay que verlo en un teléfono
  antes de decidir** — las costuras mejoran (los triángulos comparten vértices
  exactos), la silueta contra el cielo puede empeorar.
- **El edificio simplificado de lejos.** Una versión de cada grupo con su
  silueta y sin ventanas ni buhardillas, construida una vez. Es lo que debería
  hacer el presupuesto en vez de dejar de pintar.
- **Quitar las caras enterradas al construir.** Entre un 15 y un 30 % de las
  caras no se ven nunca. Regla imprescindible: **sólo se borra una cara si la
  pieza que la tapa es más vieja**, porque la que cae se dibuja aparte y
  dejaría un agujero mientras está en el aire.
- **El arranque.** Levantar el pueblo de cero cuesta **434 ms a doscientas
  piezas**, 707 a seiscientas y un segundo a mil, en el hilo principal. Pasa al
  abrir la app, al cambiar de hábito y en cada paso de la cinemática. O se va a
  otro isolate o se construye por grupos a lo largo de varios fotogramas.
- **Un contador en ajustes** con el fotograma medio, las caras y el presupuesto
  de ahora mismo. Todo lo de arriba está medido en una máquina de escritorio;
  lo que importa es lo que pasa en el teléfono.

- **La notificación tarda ~282 ms en el peor caso.** El ~20% de las piezas
  cambian la rejilla de calles y obligan a recalcular el pueblo entero para
  decidir qué decir. Es lo único de la app que hace trabajo pesado fuera de un
  fotograma. Hay que re-medirlo y, si sigue, cortarlo: la notificación no
  necesita el pueblo, necesita saber qué obra está en marcha.
- **Tres scripts muertos en `tool/`**: `tiers.sh`, `city.sh` y `matrix.sh`
  apuntan a `/home/user/the-wall` y a un Flutter que no existe en esta
  máquina.
- **Campos que no lee nadie**: `name`, `latin` y `blurb` en las ocho
  constelaciones, desde que dejaron de anotarse.
- **`ndkVersion` en `android/app/build.gradle.kts`**: ningún plugin del
  proyecto trae código nativo, así que no lo usa nada.

---

## 3. Ideas que quedaron sobre la mesa

En orden de lo que más daría por lo que menos cuesta. *(Fechar las obras, que
encabezaba esta lista, ya está hecho: el calendario del libro del atril.)*

1. **Volver a mirar un día.** En ajustes está «ver el pueblo a futuro». El
   pasado vale más: tu pueblo el día que empezaste, hace un año, el día que
   casi lo dejás. Es una vista, no un guardado.
2. **La lámina.** Guardar o compartir una imagen del pueblo a la hora que
   elijas. El render ya lo hace para el README.
3. **El widget con el pueblo dentro.** Hoy cuenta piezas; el puente ya manda
   un PNG por hábito, así que mandar un render chico del pueblo es más de lo
   mismo.
4. **Jubilar un hábito con dignidad.** Hay pausa y hay pueblo a la deriva.
   Falta un final que no sea un fracaso: «este pueblo está terminado», se
   queda en el valle como monumento, sin deterioro y sin culpa.
5. **Accesibilidad.** No hay «menos movimiento» ni tamaño de letra. La cámara
   deriva sola, las nubes corren, la gente camina.
6. **Más maravillas.** La gramática está limpia y una obra nueva son quince
   minutos — pero sesenta que se distinguen valen más que ochenta borrosas.
   Mejor esperar a echar una de menos.

---

## 4. Decisiones abiertas

- **Las obras retiradas.** Hoy siguen en pie en los pueblos que ya las
  levantaron: no se ofrecen más, pero no se borran. La alternativa es que esos
  pueblos se rehagan sin ellas, y eso mueve piedras que ya estaban puestas.
  Mientras no se decida, sus 106 frases siguen contando para los idiomas.
- **Lo que no se va a hacer**, y conviene que siga escrito: rachas que
  castiguen, medallas encima del pueblo, comparación con otra gente,
  notificaciones que pidan atención, y cobrar por el catálogo. Cada una
  convierte «un registro de lo que hiciste» en «una app que te vigila».
