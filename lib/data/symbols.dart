/// The marks a habit can wear.
///
/// Not emoji. An emoji is a font character: it is drawn by whatever the phone
/// happens to have installed, it looks like a different thing on every device,
/// and it never belongs to the same world as the town it is standing over. The
/// landmarks were always given their own drawn mark; the habits get the same
/// treatment. A symbol here is an *id* — the drawing lives in
/// `ui/habit_sigil.dart` and is made of the same straight lines and squared
/// masses everything else in the app is made of.
library;

import '../l10n/en_symbols.dart';
import '../l10n/lang.dart';

/// Every mark, in the order the picker shows them.
///
/// Ordered so the first row is what most people are actually here for — read,
/// run, lift, sit still, stop smoking, drink water — and the rest widens out
/// from there.
const List<String> habitSymbols = [
  'book',
  'run',
  'weight',
  'lotus',
  'pipe',
  'drop',
  'leaf',
  'moon',
  'quill',
  'lute',
  'brush',
  'broom',
  'flask',
  'tooth',
  'bell',
  'sprout',
  'wheel',
  'wave',
  'footprint',
  'pot',
  'target',
  'sun',
  'star',
  'heart',
  'mountain',
  'tree',
  'wheat',
  'goblet',
  'purse',
  'key',
  'anvil',
  'sword',
  'shield',
  'clock',
  'lantern',
  'tower',

  // Los treinta que faltaban: la mesa, los animales, el oficio, la
  // casa y el aseo. Van detrás porque los primeros son los que casi
  // todo el mundo viene a buscar, y esta lista se lee de izquierda a
  // derecha hasta que aparece el tuyo.
  'cup',
  'mug',
  'bread',
  'plate',
  'fish',
  'bird',
  'cat',
  'wolf',
  'horseshoe',
  'bow',
  'fist',
  'hands',
  'eye',
  'speech',
  'scroll',
  'abacus',
  'gear',
  'hammer',
  'axe',
  'compass',
  'sickle',
  'scales',
  'candle',
  'house',
  'door',
  'bridge',
  'boat',
  'ladder',
  'boot',
  'bed',
  'bucket',
  'mirror',
  'comb',
  'die',
  'cloud',
  'snowflake',
];

/// What each mark is, for anyone who cannot see it.
/// El nombre de cada marca en el idioma de ahora.
Map<String, String> get habitSymbolNames =>
    inEnglish ? habitSymbolNamesEn : _habitSymbolNamesEs;

const Map<String, String> _habitSymbolNamesEs = {
  'book': 'Libro abierto',
  'run': 'Corredor',
  'weight': 'Pesa',
  'lotus': 'Figura sentada',
  'pipe': 'Pipa tachada',
  'drop': 'Gota de agua',
  'leaf': 'Hoja',
  'moon': 'Luna',
  'quill': 'Pluma de escribir',
  'lute': 'Laúd',
  'brush': 'Pincel',
  'broom': 'Escoba',
  'flask': 'Frasco de botica',
  'tooth': 'Diente',
  'bell': 'Campana',
  'sprout': 'Brote',
  'wheel': 'Rueda',
  'wave': 'Olas',
  'footprint': 'Huella',
  'pot': 'Olla',
  'target': 'Diana',
  'sun': 'Sol',
  'star': 'Estrella',
  'heart': 'Corazón',
  'mountain': 'Montaña',
  'tree': 'Árbol',
  'wheat': 'Espiga',
  'goblet': 'Copa',
  'purse': 'Bolsa de monedas',
  'key': 'Llave',
  'anvil': 'Yunque',
  'sword': 'Espada',
  'shield': 'Escudo',
  'clock': 'Reloj de arena',
  'lantern': 'Farol',
  'tower': 'Torre',
  'cup': 'Taza',
  'mug': 'Jarra tachada',
  'bread': 'Hogaza de pan',
  'plate': 'Plato y cuchara',
  'fish': 'Pez',
  'bird': 'Pájaro',
  'cat': 'Gato',
  'wolf': 'Lobo',
  'horseshoe': 'Herradura',
  'bow': 'Arco y flecha',
  'fist': 'Puño',
  'hands': 'Manos abiertas',
  'eye': 'Ojo',
  'speech': 'Bocadillo de charla',
  'scroll': 'Pergamino',
  'abacus': 'Ábaco',
  'gear': 'Engranaje',
  'hammer': 'Martillo',
  'axe': 'Hacha',
  'compass': 'Brújula',
  'sickle': 'Hoz',
  'scales': 'Balanza',
  'candle': 'Vela encendida',
  'house': 'Casa',
  'door': 'Puerta',
  'bridge': 'Puente',
  'boat': 'Barco de vela',
  'ladder': 'Escalera',
  'boot': 'Bota',
  'bed': 'Cama',
  'bucket': 'Balde',
  'mirror': 'Espejo de mano',
  'comb': 'Peine',
  'die': 'Dado',
  'cloud': 'Nube',
  'snowflake': 'Copo de nieve',
};

/// The mark a habit gets when nobody has chosen one.
const String kDefaultHabitSymbol = 'tower';

/// The mark to actually draw for whatever is saved against a habit.
///
/// Never fails and never returns nothing: a town always has a mark over it.
String resolveHabitSymbol(String? saved) {
  if (saved == null || saved.isEmpty) return kDefaultHabitSymbol;
  if (habitSymbolNames.containsKey(saved)) return saved;
  if (_spanishIds[saved] case final id?) return id;
  // Something nobody planned for — a file touched by hand, a mark from a
  // version that came later. Choose one and always choose the same one: a
  // town must not change its sign every time the app opens.
  var h = 0;
  for (final c in saved.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return habitSymbols[h % habitSymbols.length];
}

/// Los ids de antes, que estaban en castellano: los valles guardados hasta
/// entonces —en el teléfono, en una copia, en la nube— los siguen trayendo, y
/// tienen que seguir viendo la misma marca. Al guardar ya se escribe el nuevo.
const Map<String, String> _spanishIds = {
  'libro': 'book',
  'carrera': 'run',
  'pesa': 'weight',
  'loto': 'lotus',
  'pipa': 'pipe',
  'gota': 'drop',
  'hoja': 'leaf',
  'luna': 'moon',
  'pluma': 'quill',
  'laud': 'lute',
  'pincel': 'brush',
  'escoba': 'broom',
  'frasco': 'flask',
  'diente': 'tooth',
  'campana': 'bell',
  'brote': 'sprout',
  'rueda': 'wheel',
  'ola': 'wave',
  'huella': 'footprint',
  'olla': 'pot',
  'diana': 'target',
  'sol': 'sun',
  'estrella': 'star',
  'corazon': 'heart',
  'montana': 'mountain',
  'arbol': 'tree',
  'espiga': 'wheat',
  'copa': 'goblet',
  'bolsa': 'purse',
  'llave': 'key',
  'yunque': 'anvil',
  'espada': 'sword',
  'escudo': 'shield',
  'reloj': 'clock',
  'farol': 'lantern',
  'torre': 'tower',
  'taza': 'cup',
  'jarra': 'mug',
  'pan': 'bread',
  'plato': 'plate',
  'pez': 'fish',
  'ave': 'bird',
  'gato': 'cat',
  'lobo': 'wolf',
  'herradura': 'horseshoe',
  'arco': 'bow',
  'puno': 'fist',
  'manos': 'hands',
  'ojo': 'eye',
  'dialogo': 'speech',
  'pergamino': 'scroll',
  'abaco': 'abacus',
  'engranaje': 'gear',
  'martillo': 'hammer',
  'hacha': 'axe',
  'brujula': 'compass',
  'hoz': 'sickle',
  'balanza': 'scales',
  'vela': 'candle',
  'casa': 'house',
  'puerta': 'door',
  'puente': 'bridge',
  'barco': 'boat',
  'escalera': 'ladder',
  'bota': 'boot',
  'cama': 'bed',
  'balde': 'bucket',
  'espejo': 'mirror',
  'peine': 'comb',
  'dado': 'die',
  'nube': 'cloud',
  'copo': 'snowflake',
};
