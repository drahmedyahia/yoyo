import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_to_moon_learning_game/rocket_journey.dart';

void main() {
  test('speed model stays in a realistic range', () {
    expect(speedKmhAt(0), 0);
    expect(speedKmhAt(1000), closeTo(37300, 100));
    final mid = speedKmhAt(250000);
    expect(mid, greaterThan(2000));
    expect(mid, lessThan(10000));
    expect(kmAtProgress(1), kEarthMoonKm);
  });

  test('a player who keeps shooting reaches the Moon', () {
    final w = JourneyWorld(arabic: true)..size = const Size(400, 800);
    w.setFiring(true);
    for (int i = 0; i < 60 * 400 && w.phase != JourneyPhase.won; i++) {
      w.lives = 3; // الاختبار يركز على مسار الرحلة وليس على المهارة
      final target = w.boss ?? (w.monsters.isEmpty ? null : w.monsters.first);
      if (target != null) w.steer(target.x - w.rocketPx);
      w.tick(1 / 60);
    }
    expect(w.phase, JourneyPhase.won);
    expect(w.bossDefeated, isTrue);
    expect(w.km, kEarthMoonKm);
    expect(w.kills, greaterThan(0));
    // Apollo-like journey: roughly 2–5 days.
    expect(w.realSeconds / 3600, inInclusiveRange(40, 120));
  });

  test('losing all lives ends the journey', () {
    final w = JourneyWorld(arabic: false)..size = const Size(400, 800);
    for (int i = 0; i < 60 * 300 && w.phase != JourneyPhase.lost; i++) {
      w.invulnerable = 0;
      if (w.monsters.isNotEmpty) w.steer(w.monsters.first.x - w.rocketPx);
      w.tick(1 / 60);
    }
    expect(w.phase, JourneyPhase.lost);
  });

  testWidgets('journey page renders and runs without errors', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RocketJourneyPage(
        arabic: true,
        tr: (ar, en) => ar,
        buildNext: (score) => Text('next $score'),
      ),
    ));
    for (int i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(RocketJourneyPage), findsOneWidget);
  });
}
