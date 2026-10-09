# Pendientes

Lo que está empezado, lo que está medido y lo que está decidido a medias, para
que no se pierda entre sesiones. Cada cosa dice **en qué punto está** y **qué
hace falta para seguir**.

---

## 1. Que la app hable otros idiomas

**Hecho: castellano e inglés, la app entera.** Las dos decisiones que estaban
abiertas se tomaron así:

1. **Los bandos**: todos, los 436, en el mismo orden. Los nombres propios que
   salen en ellos se quedan, salvo «Tomás», que pasa a «Tom» porque la tilde
   es castellano en mitad de una frase inglesa.
2. **Los nombres de la gente**: el de pila se queda —es un pueblo castellano—
   y lo que va detrás se traduce: «Andrés el Herrero» es «Andrés the Smith».


**Para un tercer idioma**: `Lang` en `lib/l10n/lang.dart` tiene los dos;
`tr()` pasaría a tomar uno por idioma, y cada `en_*.dart` tendría su hermano.
El inventario de lo que hay que traducir sigue siendo `TEXTOS.md`.

---

## 2. La nube (Supabase)

**Hecho: todo listo menos el enchufe.** Las tablas están en
`supabase/migrations/` (probadas contra un Postgres 16 con el esquema `auth` de
Supabase simulado: se crean, aceptan las filas de la app, cada usuario ve sólo
lo suyo y borrar un hábito se lleva sus piezas). El traductor está en
`lib/sync/tables.dart` y la interfaz en `lib/sync/remote.dart`.

**Para conectarlo:**

1. Crear el proyecto en Supabase y correr la migración (`supabase db push`, o
   pegar el SQL en el editor).
2. Agregar `supabase_flutter` y escribir una clase que implemente `Remote`:
   `push` borra las filas del usuario que ya no están y hace `upsert` del resto,
   tabla por tabla en el orden de `Tables.all`; `pull` hace `select` de cada
   una.
3. Decidir cómo se entra (correo con enlace mágico, Google…) y **cuándo** se
   sube: al poner una pieza, al cerrar la app, o con un botón en Ajustes.
4. Decidir qué pasa si el teléfono y la nube no coinciden. Lo más simple que no
   pierde nada: gana el que tenga más piezas, y antes de pisar se guarda una
   copia local.
5. Decidir qué ajustes viajan. Hoy viajan todos; los de volumen y los de
   desarrollo (hora fingida) quizá deberían quedarse en cada teléfono.

---

## 3. Deuda medida

### Lo que queda del render

Hecho ya: tirar lo que no toca la pantalla, un presupuesto que recorta por
tamaño en pantalla en vez de por distancia —y que lo que no cabe entero lo
pinta en una versión simple, una caja con su tejado, en vez de no pintarlo—, no archivar las caras enterradas, y
mandar todas las caras en una sola llamada de dibujo, y levantar el pueblo en
otro hilo mientras se ve la pantalla de apertura (`ARCHITECTURE.md`). El
fotograma pasó de 12,0 a 4,3 ms con doscientas piezas y de 40,2 a 14,8 con mil
quinientas; y los 280 ms de levantarlo de cero ya no los paga la pantalla. Lo que sigue sobre la
mesa, con lo medido al lado:

- **Un contador en ajustes** con el fotograma medio, las caras y el presupuesto
  de ahora mismo. Todo lo de arriba está medido en una máquina de escritorio;
  lo que importa es lo que pasa en el teléfono.

- **La notificación tarda ~282 ms en el peor caso.** El ~20% de las piezas
  cambian la rejilla de calles y obligan a recalcular el pueblo entero para
  decidir qué decir. Es lo único de la app que hace trabajo pesado fuera de un
  fotograma. Hay que re-medirlo y, si sigue, cortarlo: la notificación no
  necesita el pueblo, necesita saber qué obra está en marcha.
- **`ndkVersion` en `android/app/build.gradle.kts`**: ningún plugin del
  proyecto trae código nativo, así que no lo usa nada.

---

## 4. Ideas que quedaron sobre la mesa

En orden de lo que más daría por lo que menos cuesta. *(Fechar las obras, que
encabezaba esta lista, ya está hecho: la tarjeta del día que se remata dice
entre qué dos fechas se levantó.)*

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
7. **El aviso a la hora del plan.** Ahora que el plan guarda una hora de verdad
   (`Habit.vowHour`), el recordatorio podría caer ahí en vez de a la hora que el
   avisador deduce solo. Es lo único que falta para que el plan escrito haga
   trabajo además de estar escrito, y es un cambio de una línea en
   `fx/notifier.dart` — pero hay que decidir qué pasa con quien no escribió
   ninguno y con el hábito que aparece a otra hora que la que prometió.
8. **La identidad en la hoja que pregunta si seguimos.** Al desenganchate salen
   el motivo y el mínimo. La frase de identidad —«este pueblo es de alguien que
   lee todos los días»— es la que más pesa de las tres en ese momento exacto, y
   hay que probar si pesa demasiado: en la hoja del abandono puede leerse como un
   reproche, que es justo lo que esa hoja no puede ser.

---

## 5. Decisiones abiertas

- **Lo que no se va a hacer**, y conviene que siga escrito: rachas que
  castiguen, medallas encima del pueblo, comparación con otra gente,
  notificaciones que pidan atención, y cobrar por el catálogo. Cada una
  convierte «un registro de lo que hiciste» en «una app que te vigila».
