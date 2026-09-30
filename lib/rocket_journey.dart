import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// المرحلة الأولى: رحلة الصاروخ من الأرض إلى القمر.
// اللاعب يقود صاروخاً ويطلق النار بمسدس على الوحوش، بينما تُعرض
// الأجرام السماوية والمعالم الحقيقية للرحلة (الغلاف الجوي، محطة الفضاء
// الدولية، أحزمة فان ألن، الأقمار الصناعية، الكواكب، مذنب، القمر...).

const double kEarthMoonKm = 384400;
const double kEarthRadiusKm = 6371;
const double kMoonRadiusKm = 1737;

/// عدد الثواني (من وقت اللعب) لقطع الرحلة كاملة بالسرعة القصوى.
const double kJourneySeconds = 105;

/// نقطة ظهور الوحش العملاق (نسبة من تقدم الرحلة).
const double kBossAt = 0.93;

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
Color _fade(Color c, double o) => c.withOpacity(_clamp01(o));

/// المسافة الحقيقية (كم) مقابل تقدم اللعب. منحنى تكعيبي حتى تأخذ
/// المراحل القريبة من الأرض (الغيوم، خط كارمان، محطة الفضاء) وقتاً كافياً.
double kmAtProgress(double p) => kEarthMoonKm * p * p * p;

/// سرعة المركبة الحقيقية تقريبياً (كم/س) بناءً على قوانين الجاذبية:
/// صعود إلى المدار ثم حرق الانتقال للقمر (~39,000 كم/س) ثم تباطؤ بسبب
/// جاذبية الأرض، ثم تسارع مع اقترابنا من القمر.
double speedKmhAt(double km) {
  if (km < 300) return 27600 * math.sqrt(_clamp01(km / 300));
  if (km < 1000) return _lerp(27600, 37300, (km - 300) / 700);
  const muEarth = 398600.0; // km^3/s^2
  const muMoon = 4903.0;
  const v0 = 10.36; // km/s بعد حرق الانتقال (قرب سرعة الإفلات)
  const r0 = kEarthRadiusKm + 1000;
  final r = kEarthRadiusKm + km;
  final rm = math.max(kMoonRadiusKm + 100, kEarthMoonKm - km);
  var v2 = v0 * v0 -
      2 * muEarth * (1 / r0 - 1 / r) +
      2 * muMoon * (1 / rm - 1 / (kEarthMoonKm - 1000));
  if (v2 < 0.8) v2 = 0.8;
  return math.sqrt(v2) * 3600;
}

String formatInt(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return v < 0 ? '-$b' : b.toString();
}

enum JourneyPhase { countdown, flying, landing, won, lost }

class _Fact {
  final double km;
  final String ar;
  final String en;
  const _Fact(this.km, this.ar, this.en);
}

const List<_Fact> _facts = [
  _Fact(0, 'انطلاق! اسحب الصاروخ يميناً ويساراً واضغط زر المسدس لإطلاق النار',
      'Liftoff! Drag to steer and press the pistol button to shoot'),
  _Fact(12, 'تجاوزنا الغيوم: طبقة التروبوسفير تنتهي على ارتفاع نحو 12 كم',
      'Above the clouds: the troposphere ends at about 12 km'),
  _Fact(30, 'طبقة الأوزون (15–35 كم) تحمي الأرض من الأشعة فوق البنفسجية',
      'The ozone layer (15–35 km) shields Earth from UV rays'),
  _Fact(100, 'خط كارمان 100 كم: هنا يبدأ الفضاء رسمياً والسماء تصبح سوداء',
      'Kármán line, 100 km: space officially begins and the sky turns black'),
  _Fact(330, 'محطة الفضاء الدولية تدور على ارتفاع 400 كم بسرعة 28,000 كم/س',
      'The ISS orbits at 400 km, moving at 28,000 km/h'),
  _Fact(1000, 'حرق الانتقال إلى القمر: سرعتنا الآن نحو 37,000 كم/س!',
      'Trans-lunar injection: we are now moving at ~37,000 km/h!'),
  _Fact(2500, 'أحزمة فان ألن: جسيمات مشحونة يحبسها المجال المغناطيسي للأرض',
      'Van Allen belts: charged particles trapped by Earth\'s magnetic field'),
  _Fact(18000, 'أقمار نظام GPS تدور على ارتفاع 20,200 كم',
      'GPS satellites orbit at 20,200 km'),
  _Fact(33000, 'المدار الثابت 35,786 كم: هنا أقمار الاتصالات والطقس',
      'Geostationary orbit, 35,786 km: home of weather & TV satellites'),
  _Fact(60000, 'الأرض تصغر خلفنا... لاحظ الكواكب البعيدة: الزهرة والمريخ والمشتري',
      'Earth shrinks behind us… spot the planets: Venus, Mars and Jupiter'),
  _Fact(105000, 'مذنّب! ذيله يشير دائماً بعيداً عن الشمس',
      'A comet! Its tail always points away from the Sun'),
  _Fact(192200, 'منتصف الطريق! قطعنا 192,200 كم وجاذبية الأرض تُبطئنا',
      'Halfway! 192,200 km done — Earth\'s gravity is slowing us down'),
  _Fact(290000, 'دخلنا منطقة جاذبية القمر: القمر يسحبنا الآن نحوه',
      'Entering the Moon\'s sphere of influence: it now pulls us in'),
];

class _Star {
  final double x, y, r, speed, twinkle;
  final Color color;
  const _Star(this.x, this.y, this.r, this.speed, this.twinkle, this.color);
}

class _Blob {
  final double lon, lat, size, stretch;
  const _Blob(this.lon, this.lat, this.size, this.stretch);
}

class _Shot {
  double x, y, vx, vy;
  bool dead = false;
  _Shot(this.x, this.y, this.vx, this.vy);
}

class _Particle {
  double x, y, vx, vy, life;
  final double maxLife, size;
  final Color color;
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color)
      : maxLife = life;
}

class _Monster {
  final int kind; // 0 فقاعة، 1 أخطبوط، 2 شوكي، 3 الوحش العملاق
  double x, y;
  final double baseX;
  double hp;
  final double maxHp;
  final double radius;
  final double speed;
  final double phase;
  double age = 0;
  double shootTimer;
  double hitFlash = 0;
  bool dead = false;

  _Monster({
    required this.kind,
    required this.x,
    required this.y,
    required this.hp,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.shootTimer,
  })  : baseX = x,
        maxHp = hp;

  bool get isBoss => kind == 3;
}

class JourneyWorld extends ChangeNotifier {
  final bool arabic;
  final math.Random rnd = math.Random();

  Size size = Size.zero;
  JourneyPhase phase = JourneyPhase.countdown;
  double countdown = 3.5;
  double time = 0;
  double clock = 0; // وقت عام للرسوم المتحركة
  double progress = 0;
  double km = 0;
  double realSeconds = 0;
  double scroll = 0;

  double rocketX = 0.5;
  double rocketLift = 0;
  double rocketScale = 1;
  bool firing = false;
  double fireCooldown = 0;
  double muzzle = 0;

  int lives = 3;
  double invulnerable = 0;
  int score = 0;
  int kills = 0;
  double spawnTimer = 2.5;
  bool bossSpawned = false;
  bool bossDefeated = false;
  double landingT = 0;
  double shake = 0;

  int nextFact = 0;
  String factText = '';
  double factTimer = 0;

  final List<_Monster> monsters = [];
  final List<_Shot> shots = [];
  final List<_Shot> enemyShots = [];
  final List<_Particle> particles = [];
  final List<_Shot> meteors = [];
  double meteorTimer = 3;

  late final List<_Star> stars;
  late final List<_Blob> continents;
  late final List<_Blob> earthClouds;
  late final List<_Blob> craters;
  late final List<_Blob> maria;
  late final List<Offset> skyClouds;

  JourneyWorld({required this.arabic}) {
    final r = math.Random(11);
    const starColors = [
      Colors.white,
      Color(0xFFCFE3FF),
      Color(0xFFFFF1C9),
      Color(0xFFFFD2C2),
    ];
    stars = List.generate(170, (i) {
      final layer = i % 3;
      return _Star(
        r.nextDouble(),
        r.nextDouble(),
        .4 + r.nextDouble() * (0.6 + layer * .5),
        [.08, .22, .5][layer],
        r.nextDouble() * math.pi * 2,
        starColors[r.nextInt(starColors.length)],
      );
    });
    continents = List.generate(12, (_) => _Blob(
          r.nextDouble() * math.pi * 2,
          (r.nextDouble() - .5) * 2.7,
          .18 + r.nextDouble() * .25,
          .6 + r.nextDouble() * .9,
        ));
    earthClouds = List.generate(12, (_) => _Blob(
          r.nextDouble() * math.pi * 2,
          (r.nextDouble() - .5) * 2.6,
          .08 + r.nextDouble() * .14,
          1.5 + r.nextDouble() * 2,
        ));
    craters = List.generate(22, (_) {
      final a = r.nextDouble() * math.pi * 2;
      final d = math.sqrt(r.nextDouble()) * .85;
      return _Blob(math.cos(a) * d, math.sin(a) * d, .03 + r.nextDouble() * .1, 1);
    });
    maria = const [
      _Blob(-.25, -.2, .28, 1.3),
      _Blob(.2, -.35, .2, 1.1),
      _Blob(.1, .1, .22, .9),
      _Blob(-.4, .25, .16, 1.2),
    ];
    skyClouds = List.generate(9, (_) => Offset(r.nextDouble(), r.nextDouble()));
  }

  String tr(String ar, String en) => arabic ? ar : en;

  double get rocketPx => rocketX * size.width;
  double get rocketPy => size.height * .78 - rocketLift;
  double get speedKmh =>
      phase == JourneyPhase.countdown ? 0 : speedKmhAt(km);
  bool get bossFight => bossSpawned && !bossDefeated;

  _Monster? get boss {
    for (final m in monsters) {
      if (m.isBoss) return m;
    }
    return null;
  }

  String get zoneName {
    if (km < 12) return tr('التروبوسفير', 'Troposphere');
    if (km < 50) return tr('الستراتوسفير', 'Stratosphere');
    if (km < 100) return tr('الغلاف الجوي العلوي', 'Upper atmosphere');
    if (km < 2000) return tr('مدار أرضي منخفض', 'Low Earth orbit');
    if (km < 60000) return tr('أحزمة فان ألن والأقمار الصناعية', 'Van Allen belts & satellites');
    if (km < 290000) return tr('الفضاء بين الأرض والقمر', 'Cislunar space');
    return tr('مجال جاذبية القمر', 'Moon\'s gravity zone');
  }

  void showFact(String text) {
    factText = text;
    factTimer = 5;
  }

  void setFiring(bool v) {
    firing = v;
    if (v) tapFire();
  }

  void tapFire() {
    if (phase == JourneyPhase.flying && fireCooldown <= 0.08) _shoot();
  }

  void steer(double dx) {
    if (size.width <= 0) return;
    if (phase != JourneyPhase.flying && phase != JourneyPhase.countdown) return;
    final margin = 28 / size.width;
    rocketX = (rocketX + dx / size.width).clamp(margin, 1 - margin);
  }

  void tick(double dt) {
    if (size.isEmpty) return;
    if (dt > .05) dt = .05;
    clock += dt;
    if (factTimer > 0) factTimer -= dt;
    if (shake > 0) shake = math.max(0, shake - dt * 2.5);
    _updateParticles(dt);

    switch (phase) {
      case JourneyPhase.countdown:
        countdown -= dt;
        if (countdown < 1.2) _exhaust(dt, 2.5);
        if (countdown <= 0) {
          phase = JourneyPhase.flying;
          _checkFacts();
        }
        break;
      case JourneyPhase.flying:
        _updateFlight(dt);
        break;
      case JourneyPhase.landing:
        _updateLanding(dt);
        break;
      case JourneyPhase.won:
      case JourneyPhase.lost:
        _updateShots(dt);
        break;
    }
    notifyListeners();
  }

  void _setProgress(double p) {
    progress = p;
    final newKm = kmAtProgress(p);
    final v = math.max(1500.0, speedKmhAt((km + newKm) / 2));
    realSeconds += (newKm - km) / v * 3600;
    km = newKm;
  }

  void _checkFacts() {
    while (nextFact < _facts.length && km >= _facts[nextFact].km) {
      final f = _facts[nextFact];
      showFact(tr(f.ar, f.en));
      nextFact++;
    }
  }

  void _updateFlight(double dt) {
    time += dt;
    final ramp = _clamp01(.2 + time / 7);
    if (!bossFight) {
      _setProgress(math.min(1.0, progress + dt * ramp / kJourneySeconds));
    }
    scroll += dt * (40 + 260 * ramp);
    _checkFacts();
    if (time < 5) _exhaust(dt, 3 - time * .5);

    if (!bossSpawned && progress >= kBossAt) _spawnBoss();
    if (bossDefeated && progress >= 1) {
      phase = JourneyPhase.landing;
      landingT = 0;
      showFact(tr('الطريق مفتوح! نهبط الآن على سطح القمر…',
          'The way is clear! Landing on the Moon…'));
    }

    if (!bossSpawned && progress > .045) {
      spawnTimer -= dt;
      if (spawnTimer <= 0) {
        _spawnMonster();
        spawnTimer = _lerp(1.8, .6, progress) * (.7 + rnd.nextDouble() * .6);
      }
    }

    if (km > 100) {
      meteorTimer -= dt;
      if (meteorTimer <= 0) {
        meteorTimer = 3 + rnd.nextDouble() * 5;
        meteors.add(_Shot(rnd.nextDouble() * size.width, -20,
            -150 - rnd.nextDouble() * 200, 350 + rnd.nextDouble() * 250));
      }
    }

    fireCooldown -= dt;
    muzzle = math.max(0, muzzle - dt * 9);
    if (firing && fireCooldown <= 0) _shoot();
    invulnerable = math.max(0, invulnerable - dt);

    _updateShots(dt);
    _updateMonsters(dt);
    _collisions();
  }

  void _updateLanding(double dt) {
    landingT += dt;
    final t = _clamp01(landingT / 4);
    scroll += dt * 300 * (1 - t);
    final ease = t * t * (3 - 2 * t);
    rocketX = _lerp(rocketX, .5, dt * 2);
    rocketLift = ease * size.height * .36;
    rocketScale = 1 - ease * .55;
    _exhaust(dt, 1.5);
    _updateShots(dt);
    if (landingT >= 4.2) {
      phase = JourneyPhase.won;
      score += lives * 100;
      showFact(tr(
          'وصلنا! القمر يبعد 384,400 كم، وقطعت أبولو 11 هذه المسافة في نحو 3 أيام',
          'We made it! The Moon is 384,400 km away — Apollo 11 took about 3 days'));
    }
  }

  void _shoot() {
    fireCooldown = .2;
    muzzle = 1;
    shots.add(_Shot(rocketPx + 19 * rocketScale, rocketPy - 52 * rocketScale, 0, -780));
  }

  void _exhaust(double dt, double amount) {
    final n = (amount * 60 * dt).ceil();
    for (int i = 0; i < n; i++) {
      particles.add(_Particle(
        rocketPx + (rnd.nextDouble() - .5) * 16 * rocketScale,
        rocketPy + 40 * rocketScale,
        (rnd.nextDouble() - .5) * 60,
        120 + rnd.nextDouble() * 120,
        .6 + rnd.nextDouble() * .7,
        6 + rnd.nextDouble() * 8,
        km < 60 ? const Color(0xFFDDDDDD) : const Color(0xFFFFB74D),
      ));
    }
  }

  void _spawnMonster() {
    final roll = rnd.nextDouble();
    int kind;
    if (progress < .3) {
      kind = roll < .8 ? 0 : 1;
    } else if (progress < .65) {
      kind = roll < .45 ? 0 : (roll < .85 ? 1 : 2);
    } else {
      kind = roll < .25 ? 0 : (roll < .6 ? 1 : 2);
    }
    const radii = [19.0, 22.0, 24.0];
    const hps = [1.0, 2.0, 4.0];
    const speeds = [95.0, 75.0, 58.0];
    final r = radii[kind];
    monsters.add(_Monster(
      kind: kind,
      x: r + 30 + rnd.nextDouble() * (size.width - 2 * r - 60),
      y: -r - 10,
      hp: hps[kind],
      radius: r,
      speed: speeds[kind] * (1 + progress * .8),
      phase: rnd.nextDouble() * math.pi * 2,
      shootTimer: 1.2 + rnd.nextDouble() * 1.5,
    ));
  }

  void _spawnBoss() {
    bossSpawned = true;
    monsters.add(_Monster(
      kind: 3,
      x: size.width / 2,
      y: -80,
      hp: 30,
      radius: 52,
      speed: 0,
      phase: 0,
      shootTimer: 2,
    ));
    showFact(tr('وحش القمر العملاق يسدّ الطريق! اهزمه لتتمكن من الهبوط',
        'The giant Moon monster blocks the way! Defeat it to land'));
  }

  void _updateShots(double dt) {
    for (final s in shots) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      if (s.y < -30) s.dead = true;
    }
    for (final s in enemyShots) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      if (s.y > size.height + 20 || s.y < -40 || s.x < -20 || s.x > size.width + 20) {
        s.dead = true;
      }
    }
    for (final s in meteors) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      if (s.y > size.height + 60) s.dead = true;
    }
    shots.removeWhere((s) => s.dead);
    enemyShots.removeWhere((s) => s.dead);
    meteors.removeWhere((s) => s.dead);
  }

  void _fireAt(_Monster m, double angle, double speed) {
    enemyShots.add(_Shot(m.x, m.y + m.radius * .6,
        math.cos(angle) * speed, math.sin(angle) * speed));
  }

  void _updateMonsters(double dt) {
    final w = size.width, h = size.height;
    for (final m in monsters) {
      m.age += dt;
      m.hitFlash = math.max(0, m.hitFlash - dt * 5);
      if (m.isBoss) {
        m.y += (h * .22 - m.y) * dt * 1.2;
        m.x = w / 2 + math.sin(m.age * .9) * w * .3;
        m.shootTimer -= dt;
        if (m.shootTimer <= 0 && m.y > h * .1) {
          final rage = m.hp < m.maxHp / 2;
          m.shootTimer = rage ? .8 : 1.2;
          final aim = math.atan2(rocketPy - m.y, rocketPx - m.x);
          final n = rage ? 7 : 5;
          for (int i = 0; i < n; i++) {
            _fireAt(m, aim + (i - (n - 1) / 2) * .2, 210);
          }
        }
        continue;
      }
      m.y += m.speed * dt;
      switch (m.kind) {
        case 0:
          m.x += math.sin(m.age * 3 + m.phase) * 30 * dt;
          break;
        case 1:
          m.x = m.baseX + math.sin(m.age * 2.2 + m.phase) * 45;
          break;
        case 2:
          m.shootTimer -= dt;
          if (m.shootTimer <= 0 && m.y < h * .6) {
            m.shootTimer = 1.8 + rnd.nextDouble();
            _fireAt(m, math.atan2(rocketPy - m.y, rocketPx - m.x), 230);
          }
          break;
      }
      m.x = m.x.clamp(m.radius, w - m.radius);
      if (m.y > h + 50) m.dead = true;
    }
    monsters.removeWhere((m) => m.dead);
  }

  void _collisions() {
    for (final s in shots) {
      for (final m in monsters) {
        if (m.dead) continue;
        final dx = s.x - m.x, dy = s.y - m.y;
        if (dx * dx + dy * dy < (m.radius + 5) * (m.radius + 5)) {
          s.dead = true;
          m.hp -= 1;
          m.hitFlash = 1;
          _burst(s.x, s.y, 5, const Color(0xFFFFF59D), 120);
          if (m.hp <= 0) _kill(m);
          break;
        }
      }
    }
    shots.removeWhere((s) => s.dead);

    if (invulnerable <= 0) {
      final rx = rocketPx, ry = rocketPy;
      for (final m in monsters) {
        final dx = m.x - rx, dy = m.y - ry;
        final rr = m.radius + 16;
        if (dx * dx + dy * dy < rr * rr) {
          if (!m.isBoss) {
            m.dead = true;
            _burst(m.x, m.y, 18, _monsterColor(m.kind), 220);
          }
          _hitRocket();
          break;
        }
      }
    }
    if (invulnerable <= 0) {
      for (final s in enemyShots) {
        final dx = s.x - rocketPx, dy = s.y - (rocketPy - 6);
        if (dx * dx + dy * dy < 17 * 17) {
          s.dead = true;
          _hitRocket();
          break;
        }
      }
    }
    monsters.removeWhere((m) => m.dead);
    enemyShots.removeWhere((s) => s.dead);
  }

  void _kill(_Monster m) {
    m.dead = true;
    kills++;
    const points = [10, 20, 35, 500];
    score += points[m.kind];
    _burst(m.x, m.y, m.isBoss ? 90 : 26, _monsterColor(m.kind), m.isBoss ? 380 : 230);
    _burst(m.x, m.y, m.isBoss ? 40 : 10, Colors.white, m.isBoss ? 250 : 150);
    if (m.isBoss) {
      bossDefeated = true;
      shake = 1.2;
      enemyShots.clear();
      showFact(tr('هزمت وحش القمر! أحسنت يا رائد الفضاء',
          'You beat the Moon monster! Great job, astronaut'));
    }
  }

  void _hitRocket() {
    lives--;
    invulnerable = 1.8;
    shake = 1;
    _burst(rocketPx, rocketPy, 20, const Color(0xFFFF7043), 200);
    if (lives <= 0) {
      phase = JourneyPhase.lost;
      firing = false;
      _burst(rocketPx, rocketPy, 80, const Color(0xFFFFA726), 320);
      _burst(rocketPx, rocketPy, 40, Colors.white, 200);
    }
  }

  void _burst(double x, double y, int n, Color c, double speed) {
    for (int i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final v = speed * (.3 + rnd.nextDouble() * .7);
      particles.add(_Particle(x, y, math.cos(a) * v, math.sin(a) * v,
          .4 + rnd.nextDouble() * .6, 2 + rnd.nextDouble() * 4, c));
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 1 - dt * 1.5;
      p.vy *= 1 - dt * 1.5;
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);
  }
}

Color _monsterColor(int kind) => const [
      Color(0xFF66BB6A),
      Color(0xFFAB47BC),
      Color(0xFFEF5350),
      Color(0xFF7E57C2),
    ][kind];

// ---------------------------------------------------------------------------
// الصفحة
// ---------------------------------------------------------------------------

class RocketJourneyPage extends StatefulWidget {
  final bool arabic;
  final String Function(String, String) tr;

  /// تُبنى الصفحة التالية (مستويات الأسئلة) بعد الوصول للقمر.
  final Widget Function(int score) buildNext;

  const RocketJourneyPage({
    super.key,
    required this.arabic,
    required this.tr,
    required this.buildNext,
  });

  @override
  State<RocketJourneyPage> createState() => _RocketJourneyPageState();
}

class _RocketJourneyPageState extends State<RocketJourneyPage>
    with SingleTickerProviderStateMixin {
  late JourneyWorld world;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    world = JourneyWorld(arabic: widget.arabic);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    world.tick(dt);
  }

  void _restart() {
    setState(() {
      world.dispose();
      world = JourneyWorld(arabic: widget.arabic);
    });
  }

  void _continue() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.buildNext(world.score)),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    world.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(builder: (context, c) {
          world.size = Size(c.maxWidth, c.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => world.steer(d.delta.dx),
                onTapDown: (_) => world.tapFire(),
                child: RepaintBoundary(
                  child: CustomPaint(painter: JourneyPainter(world)),
                ),
              ),
              AnimatedBuilder(
                animation: world,
                builder: (context, _) => _Hud(world: world, tr: tr),
              ),
              Positioned(
                right: 18,
                bottom: 26,
                child: _FireButton(world: world, label: tr('مسدس', 'Pistol')),
              ),
              AnimatedBuilder(
                animation: world,
                builder: (context, _) => _overlay(tr),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _overlay(String Function(String, String) tr) {
    switch (world.phase) {
      case JourneyPhase.countdown:
        final n = world.countdown.ceil();
        return IgnorePointer(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('المرحلة 1: من الأرض إلى القمر', 'Stage 1: Earth to Moon'),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 10)]),
                ),
                const SizedBox(height: 12),
                Text(
                  n > 3 ? '' : (n <= 0 ? tr('انطلق!', 'Go!') : '$n'),
                  style: const TextStyle(
                      fontSize: 90,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber,
                      shadows: [Shadow(blurRadius: 18)]),
                ),
              ],
            ),
          ),
        );
      case JourneyPhase.won:
        return _EndCard(
          icon: Icons.emoji_events,
          color: Colors.amber,
          title: tr('هبطت على القمر!', 'You landed on the Moon!'),
          lines: [
            '${tr('النقاط', 'Score')}: ${world.score}',
            '${tr('الوحوش المهزومة', 'Monsters defeated')}: ${world.kills}',
            '${tr('زمن الرحلة الحقيقي', 'Real mission time')}: ${_missionTime(world, tr)}',
          ],
          primary: tr('تابع إلى المستويات', 'Continue to levels'),
          onPrimary: _continue,
          secondary: tr('العب مجدداً', 'Play again'),
          onSecondary: _restart,
        );
      case JourneyPhase.lost:
        return _EndCard(
          icon: Icons.rocket_launch,
          color: Colors.redAccent,
          title: tr('تحطم الصاروخ!', 'Rocket destroyed!'),
          lines: [
            '${tr('المسافة المقطوعة', 'Distance travelled')}: ${formatInt(world.km)} ${tr('كم', 'km')}',
            '${tr('النقاط', 'Score')}: ${world.score}',
          ],
          primary: tr('حاول مجدداً', 'Try again'),
          onPrimary: _restart,
          secondary: tr('الرئيسية', 'Home'),
          onSecondary: () => Navigator.pop(context),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

String _missionTime(JourneyWorld w, String Function(String, String) tr) {
  final total = w.realSeconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  return '$h${tr('س', 'h')} ${m.toString().padLeft(2, '0')}${tr('د', 'm')}';
}

class _Hud extends StatelessWidget {
  final JourneyWorld world;
  final String Function(String, String) tr;
  const _Hud({required this.world, required this.tr});

  @override
  Widget build(BuildContext context) {
    final w = world;
    final frac = _clamp01(w.km / kEarthMoonKm);
    const small = TextStyle(fontSize: 12, color: Colors.white70);
    return SafeArea(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${formatInt(w.km)} / ${formatInt(kEarthMoonKm)} ${tr('كم', 'km')}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(w.zoneName, style: small),
                        ],
                      ),
                    ),
                    Row(
                      children: List.generate(
                        3,
                        (i) => Icon(
                          i < w.lives ? Icons.favorite : Icons.favorite_border,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${w.score}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.public, size: 16, color: Colors.lightBlueAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 7,
                            backgroundColor: Colors.white12,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.brightness_2, size: 16, color: Colors.white70),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Row(
                    children: [
                      Text(
                        '${tr('السرعة', 'Speed')}: ${formatInt(w.speedKmh)} ${tr('كم/س', 'km/h')}',
                        style: small,
                      ),
                      const Spacer(),
                      Text('T+ ${_missionTime(w, tr)}', style: small),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (w.bossFight && w.boss != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
              child: Column(
                children: [
                  Text(tr('وحش القمر العملاق', 'Giant Moon Monster'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: w.boss!.hp / w.boss!.maxHp,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
            ),
          AnimatedOpacity(
            opacity: w.factTimer > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2745).withOpacity(.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.lightBlueAccent.withOpacity(.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(w.factText,
                        style: const TextStyle(fontSize: 14, height: 1.35)),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (w.phase == JourneyPhase.flying && w.time < 6)
            Padding(
              padding: const EdgeInsets.only(bottom: 110),
              child: Text(
                tr('↔ اسحب لتوجيه الصاروخ', '↔ Drag to steer the rocket'),
                style: const TextStyle(
                    fontSize: 15, color: Colors.white70, shadows: [Shadow(blurRadius: 6)]),
              ),
            ),
        ],
      ),
    );
  }
}

class _FireButton extends StatelessWidget {
  final JourneyWorld world;
  final String label;
  const _FireButton({required this.world, required this.label});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => world.setFiring(true),
      onPointerUp: (_) => world.setFiring(false),
      onPointerCancel: (_) => world.setFiring(false),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFF8A65), Color(0xFFD84315)],
          ),
          border: Border.all(color: Colors.white70, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.deepOrange)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 32,
              child: CustomPaint(painter: PistolIconPainter()),
            ),
            Text(label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _EndCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;
  final String primary;
  final VoidCallback onPrimary;
  final String secondary;
  final VoidCallback onSecondary;

  const _EndCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1830).withOpacity(.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(.7), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 56),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l, style: const TextStyle(fontSize: 16)),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              ),
              child: Text(primary, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: onSecondary, child: Text(secondary)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الرسم
// ---------------------------------------------------------------------------

class PistolIconPainter extends CustomPainter {
  const PistolIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44;
    canvas.save();
    canvas.scale(s);
    final metal = Paint()..color = const Color(0xFF263238);
    final grip = Paint()..color = const Color(0xFF5D4037);
    // الجسم والسبطانة
    canvas.drawRRect(
        RRect.fromLTRBR(4, 4, 42, 13, const Radius.circular(2)), metal);
    // المقبض
    final g = Path()
      ..moveTo(8, 12)
      ..lineTo(19, 12)
      ..lineTo(16, 30)
      ..lineTo(5, 30)
      ..close();
    canvas.drawPath(g, grip);
    // واقي الزناد
    canvas.drawArc(
      const Rect.fromLTWH(17, 9, 10, 11),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF263238)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(const Offset(40, 8.5), 2, Paint()..color = Colors.amber);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class JourneyPainter extends CustomPainter {
  final JourneyWorld w;
  JourneyPainter(this.w) : super(repaint: w);

  double get km => w.km;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (w.shake > 0) {
      final m = w.shake * 7;
      canvas.translate(math.sin(w.clock * 83) * m, math.cos(w.clock * 71) * m);
    }
    final atm = _clamp01(1 - km / 100); // 1 على الأرض، 0 في الفضاء
    _sky(canvas, size, atm);
    final space = _clamp01(1 - atm * 1.3);
    _milkyWay(canvas, size, space);
    _stars(canvas, size, space);
    _sun(canvas, size, atm);
    _planets(canvas, size, space);
    _moon(canvas, size, atm);
    _earth(canvas, size);
    _vanAllen(canvas, size);
    _meteors(canvas);
    _comet(canvas, size);
    _satellites(canvas, size);
    _iss(canvas, size);
    _launchPad(canvas, size);
    _clouds(canvas, size);
    _particles(canvas, (p) => p.color != Colors.white);
    for (final m in w.monsters) {
      _monster(canvas, m);
    }
    _enemyShots(canvas);
    _shots(canvas);
    if (w.phase != JourneyPhase.lost) _rocket(canvas);
    _particles(canvas, (p) => p.color == Colors.white);
    canvas.restore();
  }

  void _sky(Canvas canvas, Size size, double atm) {
    final top = Color.lerp(const Color(0xFF01020A), const Color(0xFF2F7FD8), atm)!;
    final bottom = Color.lerp(const Color(0xFF040A18), const Color(0xFFA7D8FF), atm)!;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
  }

  void _milkyWay(Canvas canvas, Size size, double alpha) {
    if (alpha <= 0) return;
    final h = size.height;
    final y = (h * .45 + w.scroll * .015) % (h * 1.8) - h * .4;
    canvas.save();
    canvas.translate(size.width * .5, y);
    canvas.rotate(-.55);
    final p = Paint()
      ..color = _fade(const Color(0xFF8E7CC3), .16 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: size.width * 2.4, height: 120), p);
    p.color = _fade(const Color(0xFFE1D5FF), .1 * alpha);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: size.width * 1.8, height: 45), p);
    canvas.restore();
  }

  void _stars(Canvas canvas, Size size, double alpha) {
    if (alpha <= 0) return;
    final paint = Paint();
    final h = size.height + 10;
    for (final s in w.stars) {
      final y = (s.y * h + w.scroll * s.speed) % h - 5;
      final tw = .65 + .35 * math.sin(w.clock * 2 + s.twinkle);
      paint.color = _fade(s.color, alpha * tw);
      canvas.drawCircle(Offset(s.x * size.width, y), s.r, paint);
    }
  }

  void _sun(Canvas canvas, Size size, double atm) {
    final c = Offset(size.width * .1, size.height * .13);
    final glowR = 110.0 - atm * 30;
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [
          _fade(const Color(0xFFFFF8E1), .9),
          _fade(const Color(0xFFFFE082), .25),
          _fade(const Color(0xFFFFE082), 0),
        ], stops: const [0, .25, 1])
            .createShader(Rect.fromCircle(center: c, radius: glowR)),
    );
    canvas.drawCircle(c, 15, Paint()..color = Colors.white);
    _label(canvas, w.tr('الشمس', 'Sun'), c + const Offset(0, 22), .75 * (1 - atm));
  }

  void _planets(Canvas canvas, Size size, double alpha) {
    if (alpha <= 0) return;
    final show = _clamp01((km - 40000) / 30000);
    final planets = [
      (Offset(size.width * .2, size.height * .42), const Color(0xFFFFF3C4), 3.4,
          w.tr('الزهرة', 'Venus')),
      (Offset(size.width * .85, size.height * .55), const Color(0xFFFF7043), 2.6,
          w.tr('المريخ', 'Mars')),
      (Offset(size.width * .38, size.height * .24), const Color(0xFFFFE0B2), 3.0,
          w.tr('المشتري', 'Jupiter')),
    ];
    for (final (pos, color, r, name) in planets) {
      canvas.drawCircle(
          pos,
          r * 3,
          Paint()
            ..color = _fade(color, .25 * alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(pos, r, Paint()..color = _fade(color, alpha));
      _label(canvas, name, pos + Offset(0, r + 9), .7 * alpha * show);
    }
  }

  void _label(Canvas canvas, String text, Offset center, double alpha) {
    if (alpha <= .01) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: _fade(Colors.white, alpha),
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, 0));
  }

  // --- الأرض ---
  void _earth(Canvas canvas, Size size) {
    final wd = size.width, h = size.height;
    final r = wd * 2.7 * kEarthRadiusKm / (kEarthRadiusKm + km);
    final shrink = _clamp01(1 - r / (wd * 2.7));
    final low = _clamp01(km / 80);
    final mid = _clamp01((km - 150) / 2500);
    final top = _lerp(_lerp(h * .86, h * 1.08, low), _lerp(h * .86, h * .9, shrink), mid);
    final c = Offset(_lerp(wd * .5, wd * .2, shrink * shrink), top + r);
    if (top > h + 5) return;

    // الهالة الجوية
    canvas.drawCircle(
      c,
      r * 1.04 + 4,
      Paint()
        ..color = _fade(const Color(0xFF64B5F6), .55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (r * .06).clamp(3, 30)),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.45),
          radius: .9,
          colors: [Color(0xFF5DB8FF), Color(0xFF1565C0), Color(0xFF0A2A5E)],
        ).createShader(rect),
    );
    final rot = w.clock * .05;
    _surfaceBlobs(canvas, c, r, w.continents, rot, const Color(0xFF4CAF50), .95,
        brown: true);
    _surfaceBlobs(canvas, c, r, w.earthClouds, rot * 1.4, Colors.white, .55);
    // الجانب الليلي
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.transparent, _fade(Colors.black, .65)],
          stops: const [.45, 1],
        ).createShader(rect),
    );
    canvas.restore();
    if (r < wd * .5) {
      _label(canvas, w.tr('الأرض', 'Earth'), c + Offset(0, -r - 18),
          .8 * _clamp01((wd * .5 - r) / (wd * .2)));
    }
  }

  void _surfaceBlobs(Canvas canvas, Offset c, double r, List<_Blob> blobs,
      double rot, Color color, double alpha, {bool brown = false}) {
    final paint = Paint();
    for (int i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final lon = b.lon + rot;
      final z = math.cos(lon) * math.cos(b.lat);
      if (z <= 0) continue;
      final x = c.dx + r * math.sin(lon) * math.cos(b.lat);
      final y = c.dy - r * math.sin(b.lat);
      final bw = r * b.size * b.stretch * math.cos(lon);
      final bh = r * b.size;
      paint.color = _fade(
          brown && i % 3 == 0 ? const Color(0xFF8D6E63) : color, alpha * (.4 + z * .6));
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: bw, height: bh), paint);
    }
  }

  void _launchPad(Canvas canvas, Size size) {
    if (km > 4) return;
    final base = size.height * .9 + km * 90;
    final x = size.width * .22;
    final metal = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, base, size.width, 400),
        Paint()..color = const Color(0xFF6D8B4E));
    canvas.drawRect(Rect.fromLTWH(x - 12, base - 170, 24, 170), metal);
    for (double y = base - 170; y < base; y += 20) {
      canvas.drawLine(Offset(x - 12, y), Offset(x + 12, y + 20), metal);
    }
    canvas.drawLine(Offset(x + 12, base - 120), Offset(x + 55, base - 120), metal);
  }

  void _clouds(Canvas canvas, Size size) {
    if (km > 15) return;
    final alpha = _clamp01(1 - km / 15);
    final h = size.height;
    final paint = Paint()
      ..color = _fade(Colors.white, .85 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (int i = 0; i < w.skyClouds.length; i++) {
      final cl = w.skyClouds[i];
      final y = (cl.dy * h * 1.4 + w.scroll * 1.8) % (h * 1.4) - h * .2;
      final x = cl.dx * size.width;
      final s = 30.0 + (i % 3) * 14;
      canvas.drawCircle(Offset(x, y), s, paint);
      canvas.drawCircle(Offset(x + s * .9, y + 6), s * .8, paint);
      canvas.drawCircle(Offset(x - s * .9, y + 8), s * .7, paint);
    }
  }

  // --- القمر ---
  void _moon(Canvas canvas, Size size, double atm) {
    final wd = size.width, h = size.height;
    final d = kEarthMoonKm - km + kMoonRadiusKm;
    final r = math.max(4.0, wd * 2.7 * kMoonRadiusKm / d);
    final bottom = math.min(h * .16 + r, h * .44);
    final grow = _clamp01(r / (wd * .5));
    final c = Offset(_lerp(wd * .68, wd * .5, grow), bottom - r);
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c,
      r * 1.25 + 6,
      Paint()
        ..color = _fade(Colors.white, .18 * (1 - atm * .5))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (r * .15).clamp(4, 40)),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.35),
          colors: [Color(0xFFF2F2F0), Color(0xFFBDBDBD), Color(0xFF7A7A7A)],
        ).createShader(rect),
    );
    final mare = Paint()..color = _fade(const Color(0xFF7D7F86), .55);
    for (final m in w.maria) {
      canvas.drawOval(
          Rect.fromCenter(
              center: c + Offset(m.lon * r, m.lat * r),
              width: m.size * r * 2 * m.stretch,
              height: m.size * r * 2),
          mare);
    }
    if (r > 10) {
      final rim = Paint()
        ..color = _fade(Colors.white, .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.6, r * .008);
      final pit = Paint()..color = _fade(const Color(0xFF5E5E5E), .45);
      for (final cr in w.craters) {
        final cc = c + Offset(cr.lon * r, cr.lat * r);
        final cs = cr.size * r;
        canvas.drawCircle(cc, cs, pit);
        canvas.drawCircle(cc - Offset(cs * .15, cs * .15), cs, rim);
      }
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.transparent, _fade(Colors.black, .55)],
          stops: const [.55, 1],
        ).createShader(rect),
    );
    canvas.restore();
    if (r < wd * .35) {
      _label(canvas, w.tr('القمر', 'Moon'), c + Offset(0, r + 6), .85);
    }
  }

  // --- أحزمة فان ألن ---
  void _vanAllen(Canvas canvas, Size size) {
    if (km < 500 || km > 80000) return;
    final a = math.sin(math.pi * _clamp01((km - 500) / 79500));
    final wd = size.width;
    final r = wd * 2.7 * kEarthRadiusKm / (kEarthRadiusKm + km);
    final shrink = _clamp01(1 - r / (wd * 2.7));
    final mid = _clamp01((km - 150) / 2500);
    final top = _lerp(size.height * 1.08, _lerp(size.height * .86, size.height * .9, shrink), mid);
    final c = Offset(_lerp(wd * .5, wd * .2, shrink * shrink), top + r);
    final pulse = .8 + .2 * math.sin(w.clock * 2);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .6
      ..color = _fade(const Color(0xFF26C6DA), .22 * a * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, (r * .2).clamp(6, 50));
    canvas.drawCircle(c, r * 1.55, inner);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 3
      ..color = _fade(const Color(0xFFEC407A), .16 * a * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, (r * .5).clamp(10, 60));
    canvas.drawCircle(c, r * 5.5, outer);
  }

  // --- محطة الفضاء الدولية ---
  void _iss(Canvas canvas, Size size) {
    const start = 200.0, end = 700.0;
    if (km < start || km > end) return;
    final t = (km - start) / (end - start);
    final pos = Offset(_lerp(-60, size.width + 60, t), _lerp(size.height * .3, size.height * .55, t));
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(-.15);
    final panel = Paint()..color = const Color(0xFF3F51B5);
    final truss = Paint()..color = const Color(0xFFB0BEC5);
    canvas.drawRect(const Rect.fromLTWH(-48, -2, 96, 4), truss);
    for (final x in [-46.0, -30.0, 18.0, 34.0]) {
      canvas.drawRect(Rect.fromLTWH(x, -22, 12, 18), panel);
      canvas.drawRect(Rect.fromLTWH(x, 4, 12, 18), panel);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -9, 16, 18), const Radius.circular(3)),
        Paint()..color = const Color(0xFFECEFF1));
    canvas.restore();
    _label(canvas, w.tr('محطة الفضاء الدولية', 'ISS'), pos + const Offset(0, 26), .9);
  }

  // --- الأقمار الصناعية ---
  void _satellites(Canvas canvas, Size size) {
    void sat(double start, double end, double y0, double y1, bool ltr, String name) {
      if (km < start || km > end) return;
      final t = (km - start) / (end - start);
      final x = ltr ? _lerp(-30, size.width + 30, t) : _lerp(size.width + 30, -30, t);
      final pos = Offset(x, _lerp(size.height * y0, size.height * y1, t));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(w.clock * .6);
      canvas.drawRect(const Rect.fromLTWH(-24, -4, 16, 8), Paint()..color = const Color(0xFF1E88E5));
      canvas.drawRect(const Rect.fromLTWH(8, -4, 16, 8), Paint()..color = const Color(0xFF1E88E5));
      canvas.drawRect(const Rect.fromLTWH(-7, -7, 14, 14), Paint()..color = const Color(0xFFFFC107));
      canvas.restore();
      _label(canvas, name, pos + const Offset(0, 14), .8);
    }

    sat(14000, 26000, .25, .6, true, 'GPS');
    sat(16000, 24000, .5, .35, false, 'GPS');
    sat(29000, 42000, .3, .5, false, w.tr('قمر اتصالات', 'Comms sat'));
    sat(31000, 41000, .6, .45, true, w.tr('قمر طقس', 'Weather sat'));
  }

  // --- المذنب ---
  void _comet(Canvas canvas, Size size) {
    const start = 95000.0, end = 165000.0;
    if (km < start || km > end) return;
    final t = (km - start) / (end - start);
    final head = Offset(_lerp(size.width * 1.1, -size.width * .1, t),
        _lerp(size.height * .08, size.height * .5, t));
    final sun = Offset(size.width * .1, size.height * .13);
    var dir = head - sun;
    dir = dir / dir.distance;
    final tail = head + dir * 170;
    final perp = Offset(-dir.dy, dir.dx) * 22;
    final path = Path()
      ..moveTo(head.dx + perp.dx * .2, head.dy + perp.dy * .2)
      ..lineTo(tail.dx + perp.dx, tail.dy + perp.dy)
      ..lineTo(tail.dx - perp.dx, tail.dy - perp.dy)
      ..lineTo(head.dx - perp.dx * .2, head.dy - perp.dy * .2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(colors: [
          _fade(const Color(0xFFB3E5FC), .7),
          _fade(const Color(0xFFB3E5FC), 0),
        ]).createShader(Rect.fromPoints(head, tail))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
        head,
        9,
        Paint()
          ..color = _fade(Colors.white, .7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(head, 3.5, Paint()..color = Colors.white);
    _label(canvas, w.tr('مذنّب', 'Comet'), head + const Offset(0, 12), .8);
  }

  void _meteors(Canvas canvas) {
    for (final m in w.meteors) {
      final p = Offset(m.x, m.y);
      final tail = p - Offset(m.vx, m.vy) * .12;
      canvas.drawLine(
        p,
        tail,
        Paint()
          ..shader = LinearGradient(colors: [Colors.white, _fade(Colors.white, 0)])
              .createShader(Rect.fromPoints(p, tail))
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // --- الصاروخ مع رائد الفضاء والمسدس ---
  void _rocket(Canvas canvas) {
    if (w.invulnerable > 0 && (w.clock * 12).floor() % 2 == 0) return;
    canvas.save();
    canvas.translate(w.rocketPx, w.rocketPy);
    canvas.scale(w.rocketScale);

    final flying = w.phase != JourneyPhase.countdown || w.countdown < 1.2;
    if (flying) {
      final len = 30 + math.sin(w.clock * 40) * 6 + w.rnd.nextDouble() * 6;
      final flame = Path()
        ..moveTo(-10, 30)
        ..quadraticBezierTo(0, 30 + len * 1.4, 10, 30)
        ..close();
      canvas.drawPath(
          flame,
          Paint()
            ..color = _fade(const Color(0xFFFF6D00), .6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawPath(
        flame,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDE7), Color(0xFFFFC107), Color(0x00FF5722)],
          ).createShader(Rect.fromLTWH(-10, 30, 20, len)),
      );
    }

    final red = Paint()..color = const Color(0xFFE53935);
    // الزعانف
    canvas.drawPath(
        Path()
          ..moveTo(-13, 8)
          ..lineTo(-26, 30)
          ..lineTo(-13, 26)
          ..close(),
        red);
    canvas.drawPath(
        Path()
          ..moveTo(13, 8)
          ..lineTo(26, 30)
          ..lineTo(13, 26)
          ..close(),
        red);
    // الجسم
    const body = Rect.fromLTWH(-13, -30, 26, 60);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(6)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB0BEC5), Colors.white, Color(0xFF90A4AE)],
        ).createShader(body),
    );
    canvas.drawRect(const Rect.fromLTWH(-13, 18, 26, 5), red);
    // المقدمة
    canvas.drawPath(
        Path()
          ..moveTo(-13, -29)
          ..quadraticBezierTo(-10, -50, 0, -60)
          ..quadraticBezierTo(10, -50, 13, -29)
          ..close(),
        red);
    // النافذة ورائد الفضاء
    canvas.drawCircle(const Offset(0, -10), 9.5, Paint()..color = const Color(0xFF90A4AE));
    canvas.drawCircle(const Offset(0, -10), 8, Paint()..color = const Color(0xFF0D47A1));
    canvas.drawCircle(const Offset(0, -10), 5.5, Paint()..color = Colors.white);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -10), width: 7, height: 4.5),
        Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(const Offset(-1.5, -11), 1, Paint()..color = Colors.white70);
    // ذراع رائد الفضاء يمسك المسدس
    canvas.drawLine(
        const Offset(6, -8),
        const Offset(19, -24),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    // المسدس
    final gun = Paint()..color = const Color(0xFF263238);
    canvas.drawRRect(
        RRect.fromLTRBR(15, -52, 23, -22, const Radius.circular(2)), gun);
    canvas.drawPath(
        Path()
          ..moveTo(15, -30)
          ..lineTo(26, -26)
          ..lineTo(26, -18)
          ..lineTo(15, -22)
          ..close(),
        Paint()..color = const Color(0xFF5D4037));
    if (w.muzzle > 0) {
      canvas.drawCircle(
          const Offset(19, -55),
          7 * w.muzzle,
          Paint()
            ..color = _fade(const Color(0xFFFFEB3B), w.muzzle)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    canvas.restore();
  }

  void _shots(Canvas canvas) {
    final glow = Paint()
      ..color = _fade(const Color(0xFFFFEB3B), .6)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final core = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final s in w.shots) {
      final a = Offset(s.x, s.y), b = Offset(s.x, s.y + 16);
      canvas.drawLine(a, b, glow);
      canvas.drawLine(a, b, core);
    }
  }

  void _enemyShots(Canvas canvas) {
    final glow = Paint()
      ..color = _fade(const Color(0xFFFF4081), .7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final core = Paint()..color = const Color(0xFFFFCDD2);
    for (final s in w.enemyShots) {
      canvas.drawCircle(Offset(s.x, s.y), 7, glow);
      canvas.drawCircle(Offset(s.x, s.y), 3.5, core);
    }
  }

  void _particles(Canvas canvas, bool Function(_Particle) include) {
    final paint = Paint();
    for (final p in w.particles) {
      if (!include(p)) continue;
      final t = p.life / p.maxLife;
      paint.color = _fade(p.color, t);
      canvas.drawCircle(Offset(p.x, p.y), p.size * (.5 + t * .5), paint);
    }
  }

  // --- الوحوش ---
  void _monster(Canvas canvas, _Monster m) {
    canvas.save();
    canvas.translate(m.x, m.y);
    final r = m.radius;
    final base = _monsterColor(m.kind);
    final color = Color.lerp(base, Colors.white, m.hitFlash * .7)!;
    final body = Paint()..color = color;
    final dark = Paint()..color = Color.lerp(base, Colors.black, .45)!;
    final wob = math.sin(m.age * 6 + m.phase);

    switch (m.kind) {
      case 0: // فقاعة خضراء بعين واحدة
        final path = Path()..moveTo(-r, 0);
        path.arcTo(Rect.fromCircle(center: Offset.zero, radius: r), math.pi, math.pi, false);
        for (int i = 0; i < 4; i++) {
          final x0 = r - i * r / 2;
          path.quadraticBezierTo(x0 - r / 4, r * (.9 + .25 * (i.isEven ? wob : -wob)),
              x0 - r / 2, r * .6);
        }
        path.close();
        canvas.drawPath(path, body);
        _eye(canvas, Offset(0, -r * .15), r * .38);
        break;
      case 1: // أخطبوط بنفسجي
        final tp = Paint()
          ..color = color
          ..strokeWidth = r * .22
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        for (int i = 0; i < 4; i++) {
          final x = -r * .6 + i * r * .4;
          final sway = math.sin(m.age * 5 + i + m.phase) * r * .3;
          final p = Path()
            ..moveTo(x, r * .2)
            ..quadraticBezierTo(x + sway, r * .8, x - sway * .5, r * 1.3);
          canvas.drawPath(p, tp);
        }
        canvas.drawOval(
            Rect.fromCenter(center: Offset(0, -r * .1), width: r * 2, height: r * 1.6), body);
        _eye(canvas, Offset(-r * .35, -r * .2), r * .25);
        _eye(canvas, Offset(r * .35, -r * .2), r * .25);
        break;
      case 2: // شوكي أحمر يطلق النار
        final spikes = Path();
        const n = 10;
        for (int i = 0; i <= n * 2; i++) {
          final a = i * math.pi / n + m.age;
          final rr = i.isEven ? r * 1.25 : r * .85;
          final p = Offset(math.cos(a) * rr, math.sin(a) * rr);
          if (i == 0) {
            spikes.moveTo(p.dx, p.dy);
          } else {
            spikes.lineTo(p.dx, p.dy);
          }
        }
        spikes.close();
        canvas.drawPath(spikes, dark);
        canvas.drawCircle(Offset.zero, r * .9, body);
        _eye(canvas, Offset(-r * .35, -r * .15), r * .22, angry: true);
        _eye(canvas, Offset(r * .35, -r * .15), r * .22, angry: true);
        canvas.drawArc(Rect.fromCenter(center: Offset(0, r * .45), width: r * .8, height: r * .4),
            math.pi, math.pi, false, Paint()..color = Colors.black87);
        break;
      case 3: // الوحش العملاق
        canvas.drawCircle(
            Offset.zero,
            r * 1.3,
            Paint()
              ..color = _fade(const Color(0xFFB388FF), .35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
        final horn = Paint()..color = const Color(0xFFFFE0B2);
        for (final s in [-1.0, 1.0]) {
          canvas.drawPath(
              Path()
                ..moveTo(s * r * .45, -r * .7)
                ..quadraticBezierTo(s * r * 1.1, -r * 1.2, s * r * .95, -r * 1.55)
                ..quadraticBezierTo(s * r * .8, -r * 1.05, s * r * .15, -r * .85)
                ..close(),
              horn);
        }
        final arm = Paint()
          ..color = color
          ..strokeWidth = r * .25
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        for (final s in [-1.0, 1.0]) {
          canvas.drawPath(
              Path()
                ..moveTo(s * r * .8, r * .1)
                ..quadraticBezierTo(s * r * 1.5, r * (.3 + .3 * wob), s * r * 1.3, r * 1.0),
              arm);
        }
        canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: r * 2.1, height: r * 1.9), body);
        _eye(canvas, Offset(-r * .45, -r * .25), r * .22, angry: true);
        _eye(canvas, Offset(r * .45, -r * .25), r * .22, angry: true);
        _eye(canvas, Offset(0, -r * .5), r * .28, angry: true);
        final mouth = Path()..moveTo(-r * .55, r * .25);
        for (int i = 0; i < 6; i++) {
          mouth.lineTo(-r * .55 + (i + .5) * r * .183, r * (i.isEven ? .5 : .3));
        }
        mouth
          ..lineTo(r * .55, r * .25)
          ..quadraticBezierTo(0, r * .85, -r * .55, r * .25);
        canvas.drawPath(mouth, Paint()..color = const Color(0xFF1A0033));
        break;
    }
    if (m.kind == 2 && m.hp < m.maxHp) {
      final bw = r * 1.6;
      canvas.drawRect(Rect.fromLTWH(-bw / 2, -r * 1.55, bw, 4), Paint()..color = Colors.black54);
      canvas.drawRect(Rect.fromLTWH(-bw / 2, -r * 1.55, bw * m.hp / m.maxHp, 4),
          Paint()..color = Colors.greenAccent);
    }
    canvas.restore();
  }

  void _eye(Canvas canvas, Offset c, double r, {bool angry = false}) {
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(c + Offset(0, r * .2), r * .5, Paint()..color = Colors.black);
    canvas.drawCircle(c + Offset(-r * .15, 0), r * .15, Paint()..color = Colors.white);
    if (angry) {
      canvas.drawLine(
          c + Offset(-r * 1.1, -r * 1.2),
          c + Offset(r * 1.1, -r * .7),
          Paint()
            ..color = Colors.black
            ..strokeWidth = r * .35
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant JourneyPainter oldDelegate) => oldDelegate.w != w;
}
