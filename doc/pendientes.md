# Pendientes

Cosas decididas para más adelante. Están acá para que no se pierdan entre
conversaciones; cuando se hagan, se borran de la lista.

## Fundar el siguiente pueblo: una pantalla dedicada

Hoy, fundar el segundo pueblo (y los siguientes) es tocar el **+** de la barra
y rellenar la misma hoja con la que se edita un hábito. Funciona, pero se siente
como un formulario, y no debería: no pasa seguido, y llegar ahí es la
recompensa de haber sostenido el primero.

Lo que tiene que transmitir: **que avanzaste**, que desbloqueaste algo por tu
esfuerzo. Una pantalla propia, con su momento —algo más cerca de la primera
vez que de la hoja de editar—, y no un formulario más.

Antes de rediseñarla falta probar la actual tal como está. Para probarla sin
tener que ganarse el segundo pueblo: *Ajustes → Sin límite de hábitos*.

Puntos de partida en el código:

- `lib/ui/home_screen.dart`, `_addHabit`: la puerta (fundar, o enterarse de
  cuánto falta para poder).
- `lib/ui/habits_sheet.dart`, con `startNew: true`: la hoja de hoy.
- `lib/ui/unlock_sheet.dart`: lo que se ve mientras la puerta sigue cerrada.
- `lib/ui/first_run.dart`: la primera vez, que es la referencia de cómo se
  siente fundar —con la comarca elegida mirando su retrato (`TownPortrait`)—.
