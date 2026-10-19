# Pendientes

**Ahora no se agregan cosas: se consolida lo que hay.** Para cada cosa,
«terminada» quiere decir que **una persona la miró en la app y dijo que sí**.
Que pase los tests o que la haya revisado Claude no alcanza.

Cada colección dice:
- qué hay hoy;
- dónde se mira;
- con qué criterio se aprueba;
- qué falta.

Lo que no pasa la revisión **se borra**, no se arregla de a poco. Se puede
volver a hacer después, ya entera.

Marcas: `[ ]` sin revisar · `[x]` aprobada por una persona · ~~tachada~~
para borrar.

---

## 1. Animaciones de la gente

**Hay 23 actividades**, más andar y quedarse mirando, en
`lib/data/doings.dart`. Cada una tiene su objeto en `lib/engine/folk_body.dart`.

**Dónde se miran:**
- Ajustes → *El expositor de la gente*: de cerca, dando la vuelta, con edad y
  región elegibles.
- En el pueblo de verdad: tocá a alguien para seguirlo y usá **Probar una
  actividad**. Va andando hasta un sitio donde tenga sentido —su puerta, la
  plaza, el agua, una obra o el prado—, la hace un rato y vuelve a su casa. Si
  en el pueblo no hay sitio de esa clase, la hace donde está.

**Criterio:**
- Se entiende qué hace **sin leer el nombre**.
- No es otra actividad con otro nombre.
- El objeto es ese objeto y no un palo.
- Tiene sentido en ese sitio.
- **Es plausible.** Lo que se saca tiene que poder llevarse encima —un libro
  del bolsillo, la escoba, el cayado—. Nada grande ni vivo aparece de la nada:
  o ya está en el pueblo, fijo en su sitio, o la persona va a su casa, entra,
  sale con ello, lo usa y lo vuelve a guardar.

**Plan acordado con la regla de lo plausible:**
- Lo saca de casa y lo vuelve a guardar: banqueta, carretilla, barreño de
  lavar, madero de serrar.
- Fijo en el pueblo y se va a usarlo: tocón con leña junto a la casa,
  tendedero junto a la puerta, puesto en la plaza, sillares al pie de la obra.
- Animales que viven en su sitio: gallinas en un corralito junto a algunas
  casas, ovejas pastando en el prado aunque nadie las cuide.
- Barco de papel: sólo donde ya hay agua, sin charco que aparece.
- Quitada: la cometa (demasiado moderna para el resto).

**Pendiente:** revisar las 22 y quitar las malas. Las nueve últimas, marcadas
*(nueva)*, no las miró nadie todavía.

- **Puerta**
  - [ ] barrer — barre el umbral
  - [ ] sentarse — se sienta en una banqueta
  - [ ] tender — tiende la ropa
  - [ ] lena — parte leña *(nueva)*
  - [ ] gallinas — echa de comer a las gallinas *(nueva)*
- **Plaza**
  - [ ] laud — toca el laúd
  - [ ] puesto — atiende el puesto
  - [ ] malabares — hace malabares *(nueva)*
  - [ ] tambor — toca el tambor *(nueva)*
  - [ ] comba — salta a la comba *(nueva, críos)*
- **Agua**
  - [ ] pozo — saca agua
  - [ ] lavar — lava la ropa
  - [ ] pescar — pesca
  - [ ] barquito — echa un barco de papel *(nueva, críos)*
- **Obra**
  - [ ] cantero — pica piedra
  - [ ] serrar — sierra un madero
  - [ ] carretilla — empuja la carretilla *(nueva)*
- **Prado**
  - [ ] segar — siega
  - [ ] leer — lee
  - [ ] nubes — se tumba a mirar las nubes
  - [ ] pastorear — cuida las ovejas *(nueva)*
  - [ ] flores — coge flores *(nueva)*
- **Sin sitio**
  - [ ] andar *(ahora a saltitos, uno por paso)*
  - [ ] quieto — se queda mirando
  - [ ] volver a casa al caer la tarde *(rehecho: cada uno a su hora y por la
    calle, no en línea recta)*

**Y la persona en sí:**
- [ ] La figura: proporciones, ropa, críos frente a mayores.
- [ ] El pelo: ellos, un gorro corto; ellas, el mismo gorro y una melena hasta
  media espalda, a ras con él. Lleva cuatro vueltas; falta el visto bueno.
- [ ] Que nada de nadie atraviese nada: ni las casas, ni la plaza, ni su propio
  pelo. Está resuelto por regla y medido por tests (ver *Lo que no se ve*),
  pero falta mirarlo en el teléfono.
- [ ] Seguir a alguien al tocarlo: el zoom, la ficha con nombre, oficio, fecha
  y casa, y que haga más cosas mientras se lo sigue.

---

## 2. Estructuras

**Hay 60 hitos** en `lib/data/landmarks.dart`:
- 12 chicos;
- 24 medianos;
- 24 grandes.

**Y 7 clases de casa:** cobertizo, casita, taller, casa, granero, casona y
posada.

**Dónde se miran:** Ajustes → *El expositor*. Se ve cada una sola, dando la
vuelta y **subiendo pieza a pieza**.

**Criterio:**
- Se reconoce qué es.
- No se parece a otra.
- Ninguna pieza flota ni atraviesa otra mientras sube.
- Se ve bien en las ocho comarcas.

**Pendiente:** revisar los 60 y las 7 casas, y quitar lo que no se distinga.
Sesenta que se distinguen valen más que sesenta con diez repetidas.

**Hitos chicos**
- [ ] Pozo del concejo
- [ ] Cruz de término
- [ ] Palomar
- [ ] Colmenar
- [ ] Huerto del cura
- [ ] Pajar
- [ ] Corral
- [ ] Gallinero
- [ ] Alfarería
- [ ] Camposanto
- [ ] Atalaya
- [ ] Almenara

**Hitos medianos**
- [ ] Molino de viento
- [ ] Almazara y olivar
- [ ] Cervecería
- [ ] Mercado cubierto
- [ ] Salinas
- [ ] Casa de la moneda
- [ ] Gremio de tejedores
- [ ] Hospital de peregrinos
- [ ] Botica
- [ ] Escuela de gramática
- [ ] Escribanía
- [ ] Capilla
- [ ] Campanario exento
- [ ] Claustro
- [ ] Refectorio
- [ ] Bodega
- [ ] Silos de grano
- [ ] Faro
- [ ] Herrería mayor
- [ ] Campo de la horca
- [ ] Palenque de torneos
- [ ] Huerto de los monjes
- [ ] Viñedo del cabildo
- [ ] Colmenar mayor

**Hitos grandes**
- [ ] Castillo
- [ ] Torre del homenaje
- [ ] Puerta de la villa
- [ ] Lienzo de muralla
- [ ] Alcázar
- [ ] Palacio del señor
- [ ] Casa del concejo
- [ ] Lonja de mercaderes
- [ ] Iglesia
- [ ] Catedral
- [ ] Monasterio
- [ ] Abadía
- [ ] Colegiata
- [ ] Sinagoga
- [ ] Mezquita
- [ ] Baptisterio
- [ ] Hospital mayor
- [ ] Universidad
- [ ] Biblioteca
- [ ] Corral de misterios
- [ ] Coso y graderío
- [ ] Jardín del palacio
- [ ] Arco de la villa
- [ ] Panteón de los fundadores

**Casas**
- [ ] Cobertizo
- [ ] Casita
- [ ] Taller
- [ ] Casa
- [ ] Granero
- [ ] Casona
- [ ] Posada
- [ ] Techos de paja: cuáles los llevan y si se leen como paja.

**Y cómo crece un pueblo**, que no es ninguna pieza suelta:
- [ ] Calles, plaza y tablón: que el trazado tenga sentido a las 50, 300 y
  1000 piezas.
- [ ] Que nada quede tapado ni metido dentro de otra cosa desde ningún ángulo.

---

## 3. Comarcas

**Hay 8** en `lib/data/character.dart`: Ribera, Sierra, Marca, Valle, Costa,
Robledal, Encrucijada y Alfar. Cada una cambia la altura de las casas, los
techos, los colores y la talla de la gente.

**Dónde se miran:** en el selector de comarca al fundar, con la vista previa
de 100 piezas, y en el expositor cambiando de región.

**Criterio:**
- Se distinguen entre sí de lejos.
- El texto de «para qué hábitos» tiene que ver con cómo se ve.

**Pendiente:**
- [ ] Ribera
- [ ] Sierra
- [ ] Marca
- [ ] Valle
- [ ] Costa
- [ ] Robledal
- [ ] Encrucijada
- [ ] Alfar

---

## 4. El paisaje y el cielo

**Qué hay:**
- montañas, suelo y estaciones (nieve, colores del año);
- día y noche con su luz;
- nubes;
- 9 constelaciones (`lib/data/constellations.dart`), que muestran su nombre
  al tocarlas;
- estrellas fugaces, siempre por detrás de las montañas.

**Dónde se mira:** en la app, con la hora y la estación fingidas de Ajustes →
Desarrollo.

**Pendiente:**
- [ ] Un día entero, de amanecer a noche: que la luz no salte.
- [ ] Las cuatro estaciones, sobre todo la nieve: pegada al suelo y quieta.
- [ ] Las 9 constelaciones: que se reconozca la figura y el nombre quede
  encima.
- [ ] Estrellas fugaces: cuántas salen y por dónde pasan.
- [ ] La vista del valle entero con varios pueblos, y el vuelo entre ellos.

---

## 5. Símbolos de hábito

**Hay 72** en `lib/data/symbols.dart`. Se dibujan en la barra de hábitos, en
el cartel del pueblo y en el tablón.

**Criterio:**
- Se reconoce qué es en chico.
- Ninguno se confunde con otro.

**Pendiente:** [ ] mirar los 72 juntos y quitar los que no se entiendan.

---

## 6. Textos

Todos los textos de la app, en castellano y en inglés, están en `TEXTOS.md`.
Se regenera con `flutter test tool/textos_test.dart` seguido de
`python3 tool/textos.py`. Desde ahí se revisan sin abrir el código.

**Criterio:**
- Suena a pueblo y no a app.
- No reprocha nada.
- No se repite.
- La versión inglesa dice lo mismo y no una traducción literal.

**Pendiente:**
- [ ] **Descripciones de los 60 hitos**: reescritas para que inspiren y sin
  humor. Falta que alguien las apruebe.
- [ ] **Nombres y oficios de la gente** (`lib/data/folknames.dart`): que los
  oficios tengan sentido con la casa en que viven.
- [ ] **Lo que dice el tablón sobre tus hábitos**: obras en marcha y
  crónica. Rachas no hay en ningún sitio (comprobado): lo único que las
  nombra es la hoja de desbloqueo, para decir que no se miden.
- [ ] **Avisos** (`lib/fx/notifier.dart`): que ninguno pida atención ni
  culpe.
- [ ] **Interfaz**: hojas, botones, ajustes y la primera vez que se abre.
- [x] **Letras del tablón**: quedan dos (`lib/ui/note_font.dart`), la de las
  notas del pueblo y la de las tuyas.

**Idiomas:** castellano e inglés están hechos, toda la app. Para un tercero,
`Lang` en `lib/l10n/lang.dart` y un `en_*.dart` hermano por catálogo. No se
hace ahora.

---

## 7. Sonido

**Qué hay** (en `assets/sfx/`; el catálogo está en `lib/fx/sensory.dart`):
- **2 músicas de fondo**: Tarde y Sendero (`lib/data/tunes.dart`). Cada una
  son tres capas que se mezclan según la hora.
- **2 piezas sueltas**: la del recuerdo (`mus_cronica`) y la de volver a la
  app (`mus_regreso`).
- **7 sonidos**: poner una pieza, toque, reparar, obra terminada, hito del
  pueblo, estrella fugaz y constelación.

**Pendiente:**
- [ ] Escucharlos todos en el teléfono.
- [ ] Que ninguno moleste a la décima vez.
- [ ] Que las capas de cada música no salten al cambiar la hora.

---

## 8. Lo que no se ve

### Rendimiento en el teléfono

Todo lo medido hasta ahora es de una máquina de escritorio. Fotograma:
- de 12,0 a 4,3 ms con 200 piezas;
- de 40,2 a 14,8 ms con 1500 piezas.

- [x] **Un contador en Ajustes → Desarrollo → Rendimiento**: fotogramas por
  segundo, lo que tarda cada uno y el pueblo, y cuántas caras; y llaves para
  apagar sombras, color, resplandor, rayos, gente y agua por separado.
- [ ] **Medir en el teléfono con ese contador** y atacar lo que pese.
- [x] **La notificación tardaba unos 282 ms en el peor caso.** Re-medido con
  un pueblo de 1500 piezas: planear los tres avisos siguientes son 11 ms, y
  lo que dice de la obra en marcha, 0,4 ms. Ya no hace falta cortar nada.
- [x] **La cámara que sigue a alguien se metía a veces dentro de un tejado.**
  Ahora se acerca lo justo para que entre ella y la persona no haya nada
  (`lib/engine/clear_view.dart`); lo prueba `clear_view_test.dart` en casi
  tres mil encuadres.

### El orden de pintado de la gente

**Hecho.** La gente se ordenaba contra los edificios por el punto de sus pies
y se pintaba entera ahí, así que todo lo que se alejaba de ese punto —el
cuerpo contra el bordillo de la plaza, el taburete contra su pared, la cometa,
las ovejas— salía por delante o por detrás de lo que no tocaba. Ahora:

- cada cara de una persona pasa por el árbol de planos de los edificios,
  partiéndose donde cruza uno (`walkOrderRiders` en `world.dart`,
  `BspTree.paintRiders` en `bsp.dart`);
- de cerca, el orden entre sus propias caras también lo da un árbol de planos;
- nadie se para donde lo que lleva se mete en algo construido: se mira todo lo
  que ocupa el gesto entero contra el plano de calles (`_fitsAt` en
  `folk.dart`).

Los tests de `depth_test.dart` lo miden en pueblos de verdad (3300 encuadres)
y de cerca para cada actividad desde 24 ángulos; ninguno falla.

### La nube (Supabase)

**Hecho, menos el enchufe:**
- las tablas (`supabase/migrations/`, probadas contra Postgres 16);
- el traductor (`lib/sync/tables.dart`);
- la sincronización (`lib/sync/remote.dart` y `merge.dart`). Sube cada cambio,
  sólo lo nuevo; al entrar gana lo más reciente, y la copia que pierde queda
  guardada en el teléfono. Los ajustes de desarrollo no viajan.

**Para conectarlo, con Google:**
1. Crear el proyecto en Supabase y correr la migración.
2. En Google Cloud, crear un cliente OAuth tipo *Web*. Pegar su id y su secreto
   en Supabase → Authentication → Providers → Google. Para Android hace falta
   además un cliente *Android* con la huella SHA-1 de la firma.
3. Pasar a la app la URL y la clave `anon` por `--dart-define`, nunca en el
   repositorio.
4. Agregar `supabase_flutter`, el botón de entrar en Ajustes y una clase que
   implemente `Remote`:
   - `apply`: `upsert` y `delete` tabla por tabla en el orden de `Tables.all`
     (los borrados al revés);
   - `pull`: `select` de cada tabla.

   Al entrar se llama a `CloudSync.connect()`, y desde ahí sube solo.

---

## 9. El consejero

El viejo de la barba que anda por la plaza del primer pueblo
(`Townsfolk.sage`), su banco, lo que sabe (`lib/data/advice.dart`), la
libreta que lo va ganando (`lib/model/advice_book.dart`) y su pantalla
(`lib/ui/sage_screen.dart`, el botón debajo del tablón).

**Criterio:** un consejo queda sólo si al autor le sirvió en su propia vida.
Por ahora entran todos, para probarlos; se van sacando los que no.

- [ ] Revisar los consejos uno por uno: cuáles quedan, cuáles se reescriben y
  cuáles faltan.
- [x] La pantalla: el viejo en 3D abajo a la izquierda, lo que dice a su
  derecha, encima cada consejo en su tarjeta (sólo el dicho), y el valle
  detrás.
- [x] El detalle de un consejo: el dicho grande y la explicación en gris,
  que aparece **un segundo después** — primero se lee la frase sola, como si
  te la dijera, y después llega la aclaración.
- [x] Cómo elige el consejo del día: manda el hábito que más te cuesta (el
  más nuevo y el que menos días tuvo en las dos últimas semanas), y lo que
  le acaba de pasar (si ayer faltaste, que no sean dos; si viene costando,
  más chico y más fácil).
- [x] Tocar al viejo en la plaza abre el consejero.
- [x] El rollo: el de bambú (`lib/ui/sage_scroll.dart`), y el detalle es el
  mismo rollo, grande, que se desenrolla al tocarlo.
- [ ] Las palomas (`lib/engine/pigeons.dart`): mirarlas en el teléfono. Bajan
  una vuelta de cada tres que se sienta en el banco, de día.

---

## 10. Decisiones abiertas

- **¿Los cobertizos y graneros siguen trayendo vecinos?** Hoy los traen todas
  las casas, y los hitos no traen ninguno. El padrón no se reescribe nunca, así
  que cambiarlo valdría sólo de aquí en adelante.
- **El botón «Probar una actividad»**: hoy sale siempre al seguir a alguien.
  Una vez revisadas las actividades, ¿se queda, o pasa a Ajustes →
  Desarrollo?
- **El aviso a la hora del plan** (`Habit.vowHour`): hay que decidir qué pasa
  con quien no escribió hora, y con el hábito que se hace a otra hora que la
  prometida.
- **Lo que no se va a hacer**, y conviene que siga escrito:
  - rachas que castiguen;
  - medallas encima del pueblo;
  - comparación con otra gente;
  - notificaciones que pidan atención;
  - cobrar por el catálogo.

  Cada una convierte «un registro de lo que hiciste» en «una app que te
  vigila».

---

## 11. Ideas congeladas

No se tocan hasta terminar todo lo de arriba. Quedan anotadas para que no se
pierdan:

- **Volver a mirar un día del pasado**: tu pueblo el día que empezaste. Es una
  vista, no un guardado.
- **La lámina**: guardar o compartir una imagen del pueblo a la hora que
  elijas.
- **El widget con el pueblo dentro**, en vez de sólo contar piezas.
- **Jubilar un hábito con dignidad**: «este pueblo está terminado», sin
  deterioro y sin culpa.
- **Accesibilidad**: menos movimiento y tamaño de letra.
- **La identidad en la hoja que pregunta si seguimos**: hay que probar antes
  si se lee como reproche.
