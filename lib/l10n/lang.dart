/// En qué idioma habla la app.
///
/// Dos, y escritos uno al lado del otro en el propio sitio donde se dicen:
/// `tr('Fundar mi pueblo', 'Found my town')`. Nada de archivos de claves. Una
/// frase de esta app casi nunca se reutiliza —cada una está escrita para su
/// sitio— y con las dos versiones juntas se ve de un vistazo si dicen lo mismo,
/// y no hay clave que inventar ni que se quede huérfana.
///
/// Los catálogos largos —las obras, los bandos, los símbolos— son otra cosa:
/// listas de cientos de frases que viven en `lib/data`. Ésos tienen su
/// versión inglesa en un archivo al lado (`lib/l10n/en_*.dart`), con la misma
/// forma, y un test que comprueba que no falte ninguna.
library;

/// Los idiomas que hay.
enum Lang {
  es('es', 'Español'),
  en('en', 'English');

  const Lang(this.code, this.name);

  /// El código ISO, el que manda el teléfono.
  final String code;

  /// Cómo se llama en sí mismo: en el selector, «English» se lee en inglés
  /// aunque la app esté en castellano, que es como lo busca quien lo necesita.
  final String name;

  /// El que corresponde a un código de idioma del aparato: castellano para
  /// cualquier variante de `es`, inglés para todo lo demás. Quien no habla
  /// castellano entiende mejor el inglés que el castellano.
  static Lang ofCode(String? code) =>
      (code ?? '').toLowerCase().startsWith('es') ? Lang.es : Lang.en;
}

/// El idioma en el que se está hablando ahora. Lo pone [Appearance] al
/// cargar y al cambiarlo; nadie más lo toca.
Lang lang = Lang.es;

/// La frase en el idioma de ahora.
String tr(String es, String en) => lang == Lang.en ? en : es;

/// Si se está en inglés. Para lo que no es una frase sino una manera de
/// decirla —el orden de una fecha, un plural—.
bool get inEnglish => lang == Lang.en;
