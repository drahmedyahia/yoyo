import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_to_moon_learning_game/rocket_journey.dart';
import 'package:earth_to_moon_learning_game/space3d.dart';

/// يشغّل العالم بخطوات 60 إطاراً في الثانية.
void run(JourneyWorld w, bool Function() until, {void Function()? each, int maxSeconds = 400}) {
  for (int i = 0; i < 60 * maxSeconds && !until(); i++) {
    each?.call();
    w.tick(1 / 60);
  }
}

JourneyWorld newWorld({bool arabic = true}) => JourneyWorld(arabic: arabic, seed: 1)..size = const Size(400, 800);

void main() {
  test('speed model stays in a realistic range', () {
    expect(speedKmhAt(0), 0);
    expect(speedKmhAt(1000), closeTo(37300, 100));
    final mid = speedKmhAt(250000);
    expect(mid, greaterThan(2000));
    expect(mid, lessThan(10000));
    expect(kmAtProgress(1), kEarthMoonKm);
  });

  test('countdown and liftoff come before the flight', () {
    final w = newWorld();
    expect(w.phase, JourneyPhase.countdown);
    run(w, () => w.phase != JourneyPhase.countdown);
    expect(w.phase, JourneyPhase.liftoff);
    expect(w.sounds.map((s) => s.$1), containsAll(['beep', 'beep_go', 'roar']));
    run(w, () => w.phase != JourneyPhase.liftoff);
    expect(w.phase, JourneyPhase.flying);
    expect(w.fact?.image, 'assets/images/liftoff.jpg');
  });

  test('a player who keeps shooting reaches lunar orbit', () {
    final w = newWorld();
    w.setFiring(true);
    var sawStages = false;
    run(w, () => w.phase == JourneyPhase.won, each: () {
      w.lives = 3; // الاختبار يركز على مسار الرحلة وليس على المهارة
      w.sounds.clear();
      if (w.km > 200 && !w.srbAttached && !w.coreAttached) sawStages = true;
      final target = w.boss ?? (w.rocks.isEmpty ? null : w.rocks.first);
      if (target != null) {
        w.px = target.pos.x.clamp(-kMaxX, kMaxX);
        w.py = target.pos.y.clamp(kMinY, kMaxY);
      }
    });
    expect(w.phase, JourneyPhase.won);
    expect(w.bossDefeated, isTrue);
    expect(w.km, kEarthMoonKm);
    expect(w.kills, greaterThan(10));
    expect(sawStages, isTrue);
    expect(w.deploy, 1);
    expect(w.nextFact, journeyFacts.length);
    // Apollo-like journey: roughly 2–5 days.
    expect(w.realSeconds / 3600, inInclusiveRange(40, 120));
  });

  test('losing all shields ends the journey', () {
    final w = newWorld(arabic: false);
    run(w, () => w.phase == JourneyPhase.lost, each: () {
      w.invulnerable = 0;
      if (w.rocks.isNotEmpty) {
        final r = w.rocks.reduce((a, b) => a.pos.z.abs() < b.pos.z.abs() ? a : b);
        w.px = r.pos.x.clamp(-kMaxX, kMaxX);
        w.py = r.pos.y.clamp(kMinY, kMaxY);
      }
    });
    expect(w.phase, JourneyPhase.lost);
    expect(w.lives, 0);
  });

  test('sky uses real apparent sizes of Earth and Moon', () {
    final w = newWorld();
    run(w, () => w.km > 400);
    var s = skyFor(w);
    // من مدار منخفض تملأ الأرض معظم السماء تحتنا
    expect(s.earthAlpha * 180 / math.pi, greaterThan(60));
    expect(s.earthDir.y, lessThan(-.9));
    w.km = 300000;
    w.progress = math.pow(300000 / kEarthMoonKm, 1 / 3).toDouble();
    s = skyFor(w);
    expect(s.earthAlpha * 180 / math.pi, closeTo(1.2, .2));
    expect(s.earthDir.z, lessThan(0)); // الأرض خلفنا
    expect(s.moonDir.z, greaterThan(.9)); // القمر أمامنا
  });

  test('3D helpers project and align correctly', () {
    final cam = Camera()
      ..setViewport(const Size(400, 800))
      ..lookAt(V3.zero, const V3(0, 0, 10));
    expect(cam.project(const V3(0, 0, 5)), const Offset(200, 400));
    expect(cam.project(const V3(1, 0, 5))!.dx, greaterThan(200));
    expect(cam.project(const V3(0, 1, 5))!.dy, lessThan(400));
    expect(cam.project(const V3(0, 0, -5)), isNull);
    final m = M3.align(const V3(1, 0, 0), const V3(0, 1, 0), const V3(0, 0, 1), const V3(0, 1, 0));
    final v = m.apply(const V3(1, 0, 0));
    expect(v.z, closeTo(1, 1e-9));
    final orion = buildOrion();
    expect(orion.triCount, greaterThan(200));
  });

  testWidgets('journey page renders and runs without errors', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RocketJourneyPage(
        arabic: true,
        tr: (ar, en) => ar,
        buildNext: (score) => Text('next $score'),
        loadMedia: false,
      ),
    ));
    for (int i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(RocketJourneyPage), findsOneWidget);
  });
}
