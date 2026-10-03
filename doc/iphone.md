# Towny en el iPhone

Lo que hay que hacer, en orden, para abrir la app en un iPhone desde una Mac.
El código ya está listo: no hay nada en el Dart que sea de Android —ni una
línea de `dart:io`, ni un `Platform.isAndroid`— y los cuatro paquetes que usa
(guardado, sonido, avisos y husos horarios) corren en los dos teléfonos.

Lo único que faltaba era el proyecto de Xcode, y está hecho: `ios/`.

---

## 1. La Mac, una vez

```sh
# Xcode, de la App Store. Y después, sus herramientas de línea de comandos:
xcode-select --install
sudo xcodebuild -license accept

# Flutter, si no está:
#   https://docs.flutter.dev/get-started/install/macos
# CocoaPods, que es lo que baja las dependencias nativas de los paquetes:
sudo gem install cocoapods     # o: brew install cocoapods
```

Y comprobar que la Mac se ve a sí misma entera:

```sh
flutter doctor
```

Tiene que decir que sí a Xcode y a CocoaPods. Lo de Android puede fallar sin
que importe.

## 2. El repo

```sh
git clone https://github.com/BrunoGoat/Towny.git
cd Towny
git checkout claude/sustainable-habits-design-snpxyb
flutter pub get
```

## 3. El teléfono

1. Enchufá el iPhone a la Mac con cable. La primera vez, el teléfono pregunta
   si confía en la computadora: que sí.
2. En el iPhone: **Ajustes → Privacidad y seguridad → Modo desarrollador**,
   encendido. Pide reiniciar.
3. En la Mac, `flutter devices` tiene que listarlo.

## 4. Firmar

Esto es lo único que no se puede hacer desde el código: Apple exige que cada
app instalada en un teléfono esté firmada por alguien.

```sh
open ios/Runner.xcworkspace
```

En Xcode, en el panel de la izquierda, elegí el proyecto **Runner**, pestaña
**Signing & Capabilities**, objetivo **Runner**:

- **Automatically manage signing**, marcado.
- **Team**: tu Apple ID. Si no está, `Xcode → Settings → Accounts → +`.
- **Bundle Identifier**: `com.towny.app`. Si Xcode se queja de que ya
  existe, cambialo por algo tuyo —`uy.brunogoat.towny`, por ejemplo— que es
  gratis y no se lo pisa a nadie.

## 5. Correr

```sh
flutter run --release
```

La primera vez tarda: CocoaPods baja las dependencias y Xcode compila el motor
de Flutter entero.

Y la primera vez que la abras, el iPhone va a decir que el desarrollador no es
de confianza. Se arregla en **Ajustes → General → VPN y gestión de dispositivos
→ tu Apple ID → Confiar**.

### Con un Apple ID gratis

Funciona, con dos peajes:

- La app **caduca a los siete días**. Pasado ese plazo deja de abrir y hay que
  volver a hacer `flutter run`. Los pueblos no se pierden: están en el
  teléfono, no en la firma.
- **No se puede instalar el widget.** Ver abajo.

Con el Apple Developer Program (99 dólares al año) la firma dura un año y el
widget funciona.

---

## El widget

El cuadrito de la pantalla de inicio —una fila por pueblo, con lo que llevás
hoy, y dos toques para poner una pieza— está escrito para los dos teléfonos:

- `ios/Shared/WidgetBox.swift` — la caja compartida entre la app y el widget.
  Es el hermano de `WidgetBox.kt` y guarda lo mismo con los mismos nombres.
- `ios/Runner/AppDelegate.swift` — la aduana: los tres verbos del canal
  (`publish`, `drain`, `ack`), iguales que los de `MainActivity.kt`.
- `ios/TownyWidget/TownyWidget.swift` — el cuadrito.

Lo que falta no es código: es **crear el objetivo de la extensión en Xcode**,
que es lo único que escribe el fichero del proyecto, y encender el grupo de
aplicaciones. Diez minutos:

### a. El grupo de aplicaciones

En iOS la app y el widget son **dos procesos distintos**, cada uno en su caja
de arena. Lo único que comparten es el contenedor de un *App Group*, y por eso
todo el buzón cuelga de él.

**Esto pide el Apple Developer Program de pago.** Una cuenta gratis no puede
crear grupos, así que con Apple ID gratis la app corre pero el widget no tiene
dónde leer. No hay vuelta: es de Apple, no del código.

### b. El objetivo

1. En Xcode: **File → New → Target… → Widget Extension**.
2. Nombre: `TownyWidget`. **Desmarcá** «Include Live Activity» y «Include
   Configuration App Intent».
3. Cuando pregunte si activar el esquema, que sí.
4. Xcode crea `ios/TownyWidget/` con dos ficheros suyos: `TownyWidget.swift` y
   `TownyWidgetBundle.swift`. **Borralos los dos** (Move to Trash) — el que
   hay en el repo ya trae el `@main` y tener dos no compila.
5. Arrastrá a Xcode el `TownyWidget.swift` del repo, dentro del grupo
   `TownyWidget`, con **Target Membership: TownyWidget**.
6. `ios/Shared/WidgetBox.swift` **ya está en el objetivo `Runner`** —viene
   puesto en el proyecto, por eso la app compila sin hacer nada de esto—. Lo
   que falta es marcarle también el otro: seleccionalo en el panel de la
   izquierda y en el inspector de la derecha, **Target Membership**, marcá
   `TownyWidget`. Que los dos lean la misma caja es lo único que hace que esto
   funcione.

   (Si por lo que sea no aparece en el panel, arrastralo a Xcode desde
   `ios/Shared/` y marcale los dos objetivos.)
7. En el objetivo `TownyWidget`, **Minimum Deployments: iOS 17.0**. Los botones
   que hacen algo sin abrir la app no existen antes de la 17.

### c. La capacidad, en los dos

En **Signing & Capabilities**, para `Runner` y otra vez para `TownyWidget`:

- **+ Capability → App Groups**
- **+** y escribí `group.com.towny.app`

Tiene que estar escrito igual en los dos, y tiene que coincidir con la
constante `group` de `WidgetBox.swift`. Si cambiás el identificador, cambialo
en los tres sitios.

### d. Probar

`flutter run --release`, abrí la app una vez —que es lo que publica el
resumen— y después mantené el dedo en la pantalla de inicio del iPhone,
**Editar → Añadir widget → Towny**.

El primer toque en una fila la tiñe y saca un botón que dice «Poner pieza»; el
segundo deja la pieza apuntada. La pieza de verdad la pone la app la próxima
vez que la abras, con la hora a la que la tocaste y enseñándola caer — igual
que en Android, y por el mismo motivo: levantar un pueblo entero dentro de una
extensión para poner una piedra sería arrancar el motor de la app cada vez que
alguien pasa por su pantalla de inicio.

---

## Lo que no cambia

El guardado es el mismo fichero de siempre, así que un pueblo exportado desde
el Android se pega tal cual en el iPhone: *el viaje → Tus datos → Copiar* en
uno, *Pegar* en el otro.
