import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'rocket_journey.dart';

void main() => runApp(const EarthToMoonApp());

class EarthToMoonApp extends StatefulWidget {
  const EarthToMoonApp({super.key});
  @override
  State<EarthToMoonApp> createState() => _EarthToMoonAppState();
}

class _EarthToMoonAppState extends State<EarthToMoonApp> {
  bool arabic = true;
  int level = 1;

  String t(String ar, String en) => arabic ? ar : en;

  Widget _levelsPage(int score) => Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: GamePage(arabic: arabic, level: level, tr: t, initialScore: score),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Earth to Moon',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: HomePage(
          arabic: arabic,
          level: level,
          tr: t,
          onLanguage: () => setState(() => arabic = !arabic),
          onStart: (ctx) => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => RocketJourneyPage(
                arabic: arabic,
                tr: t,
                buildNext: _levelsPage,
              ),
            ),
          ),
          onSkipToLevels: (ctx) => Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => _levelsPage(0)),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final bool arabic;
  final int level;
  final String Function(String, String) tr;
  final VoidCallback onLanguage;
  final void Function(BuildContext) onStart;
  final void Function(BuildContext) onSkipToLevels;

  const HomePage({
    super.key,
    required this.arabic,
    required this.level,
    required this.tr,
    required this.onLanguage,
    required this.onStart,
    required this.onSkipToLevels,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SpaceBackground(),
          // صورة حقيقية: شروق الأرض فوق القمر (أبولو 8، ناسا)
          Image.asset('assets/images/earthrise.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA000000), Color(0x33000000), Color(0xDD000000)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton(
                      onPressed: onLanguage,
                      child: Text(arabic ? 'English' : 'العربية'),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  tr('من الأرض إلى القمر', 'Earth to Moon'),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 12)],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  tr('رحلة تعليمية بين الأرض والفضاء', 'An educational journey from Earth to space'),
                  style: const TextStyle(fontSize: 17),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.black.withOpacity(.35),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      Text(tr('المستوى الحالي', 'Current level'),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('$level / 20',
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.deepOrange.withOpacity(.18),
                    border: Border.all(color: Colors.deepOrangeAccent.withOpacity(.6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.rocket_launch, color: Colors.orangeAccent, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('المرحلة 1: رحلة أوريون إلى القمر', 'Stage 1: Orion to the Moon'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tr('رحلة ثلاثية الأبعاد بمركبة ناسا: 384,400 كم بين الصخور والنيازك، مع صور حقيقية للفضاء',
                                  'A 3D trip on NASA\'s spacecraft: 384,400 km through space rocks, with real space photos'),
                              style: const TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => onStart(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    tr('ابدأ الرحلة', 'Start Journey'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => onSkipToLevels(context),
                  child: Text(tr('تخطَّ إلى مستويات الأسئلة', 'Skip to quiz levels')),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    tr('20 مستوى من الصعوبة', '20 difficulty levels'),
                    style: const TextStyle(fontSize: 15, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  final bool arabic;
  final int level;
  final String Function(String, String) tr;
  final int initialScore;
  const GamePage({
    super.key,
    required this.arabic,
    required this.level,
    required this.tr,
    this.initialScore = 0,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late int level;
  int score = 0;
  int monster = 0;
  int question = 0;

  final List<List<int>> questions = [
    [2, 3, 5],
    [7, 4, 11],
    [9, 6, 15],
    [12, 5, 17],
    [15, 7, 22],
    [18, 9, 27],
    [20, 13, 33],
    [24, 8, 32],
    [27, 14, 41],
    [30, 15, 45],
    [35, 12, 47],
    [40, 16, 56],
    [42, 18, 60],
    [45, 20, 65],
    [50, 25, 75],
    [54, 21, 75],
    [60, 30, 90],
    [64, 16, 80],
    [72, 18, 90],
    [80, 20, 100],
  ];

  @override
  void initState() {
    super.initState();
    level = widget.level;
    score = widget.initialScore;
  }

  void answer(bool correct) {
    setState(() {
      if (correct) score += level * 10;
      monster++;
      question++;
      if (question >= 5) {
        question = 0;
        if (level < 20) level++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[level - 1];
    final correct = q[2];
    final options = [correct, correct + 2 + level % 3, math.max(1, correct - 2)];
    options.shuffle();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SpaceBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(widget.tr('المستوى', 'Level'),
                                style: const TextStyle(color: Colors.white70)),
                            Text('$level / 20',
                                style: const TextStyle(
                                    fontSize: 21, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Text('${widget.tr('النقاط', 'Score')}: $score',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: c.maxHeight * .03),
                              child: const EarthGraphic(),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: c.maxHeight * .02),
                              child: const MoonGraphic(),
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MonsterGraphic(level: level),
                                const SizedBox(height: 12),
                                Text(
                                  widget.tr('وحش المستوى', 'Level monster'),
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 22),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(.55),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        widget.tr(
                                          'أجب للتقدم في الطريق',
                                          'Answer to move forward',
                                        ),
                                        style: const TextStyle(fontSize: 18),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        '${q[0]} + ${q[1]} = ?',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        alignment: WrapAlignment.center,
                                        children: options.map((v) {
                                          return FilledButton(
                                            onPressed: () => answer(v == correct),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 20, vertical: 10),
                                              child: Text('$v',
                                                  style: const TextStyle(fontSize: 20)),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpaceBackground extends StatelessWidget {
  const SpaceBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: SpacePainter());
  }
}

class SpacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF02030B), Color(0xFF071B35), Color(0xFF06101D)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final stars = Paint()..color = Colors.white;
    final rnd = math.Random(7);
    for (int i = 0; i < 150; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = .4 + rnd.nextDouble() * 1.3;
      canvas.drawCircle(Offset(x, y), r, stars);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EarthGraphic extends StatelessWidget {
  const EarthGraphic({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 120, height: 120,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: Alignment(-.3, -.35),
        radius: .8,
        colors: [Color(0xFF75C8FF), Color(0xFF1261A0), Color(0xFF041A35)],
      ),
      boxShadow: [BoxShadow(blurRadius: 35, spreadRadius: 4, color: Colors.blue)],
    ),
    child: const Icon(Icons.public, size: 70, color: Colors.white70),
  );
}

class MoonGraphic extends StatelessWidget {
  const MoonGraphic({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 88, height: 88,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: Alignment(-.25, -.3),
        colors: [Color(0xFFEFEFEF), Color(0xFF9B9B9B), Color(0xFF4D4D4D)],
      ),
      boxShadow: [BoxShadow(blurRadius: 24, spreadRadius: 2, color: Colors.white30)],
    ),
    child: const Icon(Icons.circle, size: 6, color: Colors.black38),
  );
}

class MonsterGraphic extends StatelessWidget {
  final int level;
  const MonsterGraphic({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final size = 62.0 + level * 1.8;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade700,
        borderRadius: BorderRadius.circular(size * .35),
        boxShadow: const [BoxShadow(blurRadius: 18, color: Colors.black54)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: size * .2,
            top: size * .25,
            child: _eye(),
          ),
          Positioned(
            right: size * .2,
            top: size * .25,
            child: _eye(),
          ),
          Positioned(
            bottom: size * .18,
            child: Container(
              width: size * .45,
              height: size * .14,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eye() => Container(
    width: 14, height: 18,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Container(
        width: 6, height: 9,
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}
