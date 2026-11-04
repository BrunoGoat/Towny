import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/landmarks.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';
const dir = '/tmp/claude-0/-home-user-Towny/a131de33-bf5a-5d7a-a66b-8ec350750de4/scratchpad/sheet/';
void main() {
  test('sheet', () async {
    Directory(dir).createSync(recursive: true);
    final solo = Platform.environment['OBRAS']?.split(',');
    for (final m in landmarks) {
      if (solo != null && !solo.contains(m.id)) continue;
      final l = TownLayout.showcase(TownCharacter.all[0], landmark: m, placed: m.cost);
      final r = m.reach;
      final cam = OrbitCamera()..yaw = 0.55..pitch = 0.45..distance = r * 3.2 + 2..focusY = r * 0.35..travel = 0..focusZ = 0..wallLength = 6;
      final rec = ui.PictureRecorder();
      TownPainter(TownScene(placed: m.cost, palette: Palette.forMoment(11), camera: cam, time: 3, hourOfDay: 11,
        effects: EffectSystem(), budget: 60000,
        towns: [TownEntry(layout: l, name: 'P', symbol: 'wheel', placed: m.cost)],
        active: 0, labels: false, folk: false, ghost: false, cinematic: true), TouchMap()).paint(Canvas(rec), const Size(320, 320));
      final img = await rec.endRecording().toImage(320, 320);
      File('$dir${m.id}.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    }
  });
}
