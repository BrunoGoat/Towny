import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/first_run.dart';

/// «Ver la primera vez otra vez», desde ajustes, es un ensayo: se contesta,
/// se funda, y se vuelve al valle tal como estaba.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Store> unValle() async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setOnboarded();
    final s = Store();
    await s.load();
    s.renameHabit(0, name: 'Leer', symbol: 'libro');
    s.settle(0, TownCharacter.all[1].order);
    s.pledgeHabit(0, identity: 'alguien sabio');
    s.placePiece();
    return s;
  }

  test('fundar en el ensayo no le toca nada al valle', () async {
    final s = await unValle();
    final antes = s.exportSave();

    Appearance.instance.rehearseOnboarding();
    expect(Appearance.instance.onboarded, isFalse);
    final fundo = await foundFirstTown(
      s,
      'Otra cosa',
      'carrera',
      character: TownCharacter.all[4].order,
      why: 'por probar',
      identity: 'alguien distinto',
    );

    expect(fundo, isFalse);
    expect(s.exportSave(), antes);
    expect(Appearance.instance.onboarded, isTrue);
    expect(Appearance.instance.rehearsing, isFalse);
  });

  test('y a mitad del ensayo el disco sigue diciendo que ya se pasó', () async {
    await unValle();
    Appearance.instance.rehearseOnboarding();
    // Cualquier otro ajuste que se toque mientras tanto se guarda, y con él
    // la marca de la primera vez: tiene que quedar puesta.
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.flush();
    await Appearance.instance.load();
    expect(Appearance.instance.onboarded, isTrue);
  });

  test('la primera vez de verdad sí funda', () async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    final s = Store();
    await s.load();
    final fundo = await foundFirstTown(
      s,
      'Correr',
      'carrera',
      character: TownCharacter.all[4].order,
      identity: 'alguien constante',
    );
    expect(fundo, isTrue);
    expect(s.habit.name, 'Correr');
    expect(s.habit.character, TownCharacter.all[4].order);
    expect(s.habit.identity, 'alguien constante');
    expect(Appearance.instance.onboarded, isTrue);
  });
}
