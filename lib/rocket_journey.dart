import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'space3d.dart';
import 'space_art.dart';
import 'space_audio.dart';

// المرحلة الأولى: رحلة مركبة أوريون (ناسا) من الأرض إلى القمر بعرض
// ثلاثي الأبعاد. الأرض والقمر مرسومان بخرائط ناسا الحقيقية، والخلفية
// خريطة النجوم ودرب التبانة الحقيقية، وتظهر صور حقيقية من مهمات أبولو
// وأرتميس ومحطة الفضاء الدولية مع المعلومات أثناء الرحلة.
// العقبات صخور فضائية ونيازك يحطمها اللاعب بالليزر.

const double kEarthMoonKm = 384400;
const double kEarthRadiusKm = 6371;
const double kMoonRadiusKm = 1737;

/// ارتفاع مدار القمر في النهاية (مثل أرتميس 1 عند أقرب نقطة).
const double kLunarOrbitKm = 130;

/// عدد الثواني (من وقت اللعب) لقطع الرحلة كاملة بالسرعة القصوى.
const double kJourneySeconds = 105;

/// نقطة ظهور الكويكب العملاق (نسبة من تقدم الرحلة).
const double kBossAt = 0.93;

const double kCountdownSeconds = 5.4;
const double kLiftoffSeconds = 2.6;
const double kArrivalSeconds = 8;

/// حدود حركة المركبة في المستوى أمام الكاميرا (وحدات العالم).
const double kMaxX = 5.2, kMinY = -3.2, kMaxY = 3.6;

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _smooth(double a, double b, double v) {
  final t = _clamp01((v - a) / (b - a));
  return t * t * (3 - 2 * t);
}

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

enum JourneyPhase { countdown, liftoff, flying, arrival, won, lost }

class JourneyFact {
  final double km;
  final String ar, en;

  /// صورة حقيقية من ناسا (اختيارية) مع وصفها.
  final String? image;
  final String? captionAr, captionEn;
  const JourneyFact(this.km, this.ar, this.en, {this.image, this.captionAr, this.captionEn});
}

const List<JourneyFact> journeyFacts = [
  JourneyFact(0, 'انطلق صاروخ SLS، أقوى صاروخ أطلقته ناسا، وعلى قمته مركبة أوريون',
      'Liftoff! SLS, NASA\'s most powerful rocket, carries the Orion spacecraft',
      image: 'assets/images/liftoff.jpg',
      captionAr: 'إطلاق أرتميس 1 — 16 نوفمبر 2022',
      captionEn: 'Artemis I launch — Nov 16, 2022'),
  JourneyFact(12, 'عبرنا الغيوم: طبقة التروبوسفير تنتهي على ارتفاع نحو 12 كم، وفيها يحدث الطقس كله',
      'Above the clouds: the troposphere ends at ~12 km — all weather happens below'),
  JourneyFact(20, 'يميل الصاروخ تدريجياً نحو الأفق (مناورة الدوران بالجاذبية) ليكتسب سرعة المدار: 28,000 كم/س',
      'The rocket slowly tips toward the horizon (gravity turn) to gain orbital speed: 28,000 km/h'),
  JourneyFact(30, 'طبقة الأوزون (15–35 كم) تحمي الأرض من الأشعة فوق البنفسجية',
      'The ozone layer (15–35 km) shields Earth from UV rays'),
  JourneyFact(45, 'انفصل المعززان الصاروخيان بعد دقيقتين تقريباً من الإطلاق',
      'The two solid rocket boosters separate about two minutes after launch'),
  JourneyFact(70, 'طبقة الميزوسفير (50–85 كم): هنا تحترق معظم الشهب وتتوهج بسبب احتكاكها بالهواء — تفادَها!',
      'Mesosphere (50–85 km): most meteors burn up and glow here — dodge them!'),
  JourneyFact(100, 'خط كارمان 100 كم: بداية الفضاء. لا يوجد هواء هنا، لذلك لا ينتقل الصوت ويخفت هدير المحرك',
      'Kármán line, 100 km: space begins. No air means no sound — the engine roar fades',
      image: 'assets/images/earth_limb.jpg',
      captionAr: 'حافة الغلاف الجوي كما تُرى من محطة الفضاء',
      captionEn: 'Earth\'s thin atmosphere seen from the ISS'),
  JourneyFact(125, 'انفصلت المرحلة الأساسية، وفتحت أوريون ألواحها الشمسية الأربعة لتوليد الكهرباء من ضوء الشمس',
      'Core stage separation! Orion unfolds its four solar wings to make electricity'),
  JourneyFact(330, 'محطة الفضاء الدولية على ارتفاع 400 كم تدور بسرعة 28,000 كم/س وتكمل دورة كل 90 دقيقة',
      'The ISS orbits at 400 km, moving at 28,000 km/h — one lap every 90 minutes',
      image: 'assets/images/iss.jpg',
      captionAr: 'محطة الفضاء الدولية — صورة حقيقية',
      captionEn: 'The International Space Station — real photo'),
  JourneyFact(600, 'احذر الصخور الفضائية! النيازك الصغيرة تتحرك أسرع من الرصاصة بعشرات المرات — حطّمها بالليزر',
      'Watch out for space rocks! Tiny meteoroids move many times faster than a bullet — blast them'),
  JourneyFact(1000, 'حرق الانتقال إلى القمر (TLI): سرعتنا الآن نحو 37,000 كم/س!',
      'Trans-lunar injection burn: we are now moving at ~37,000 km/h!'),
  JourneyFact(2500, 'أحزمة فان ألن: جسيمات مشحونة يحبسها المجال المغناطيسي للأرض، والمركبة محمية منها',
      'Van Allen belts: charged particles trapped by Earth\'s magnetic field'),
  JourneyFact(18000, 'أقمار نظام GPS تدور على ارتفاع 20,200 كم وتحدد موقعك على الخريطة',
      'GPS satellites orbit at 20,200 km and tell your phone where you are'),
  JourneyFact(33000, 'المدار الثابت 35,786 كم: أقمار الطقس والاتصالات. في 2029 سيمر الكويكب أبوفيس أقرب من هذا المدار!',
      'Geostationary orbit, 35,786 km. In 2029 asteroid Apophis will pass even closer than this!'),
  JourneyFact(55000, 'لاحظ الكواكب في السماء: الزهرة والمريخ والمشتري تلمع مثل نجوم لا تومض',
      'Spot the planets: Venus, Mars and Jupiter shine like stars that don\'t twinkle'),
  JourneyFact(75000, 'صورة "الكرة الزرقاء" الشهيرة التقطها رواد أبولو 17 عام 1972 في طريقهم إلى القمر',
      'The famous "Blue Marble" photo was taken by Apollo 17 astronauts on the way to the Moon',
      image: 'assets/images/blue_marble.jpg',
      captionAr: 'الكرة الزرقاء — أبولو 17، 1972',
      captionEn: 'Blue Marble — Apollo 17, 1972'),
  JourneyFact(105000, 'مذنّب! كرة من الجليد والغبار، وذيله يشير دائماً بعيداً عن الشمس',
      'A comet! A ball of ice and dust — its tail always points away from the Sun',
      image: 'assets/images/comet.jpg',
      captionAr: 'المذنب نيووايز فوق الأرض — من محطة الفضاء 2020',
      captionEn: 'Comet NEOWISE above Earth — from the ISS, 2020'),
  JourneyFact(150000, 'الشريط اللامع في السماء هو مجرتنا درب التبانة، وفيها أكثر من 100 مليار نجم',
      'The glowing band across the sky is our galaxy, the Milky Way — over 100 billion stars'),
  JourneyFact(192200, 'منتصف الطريق! قطعنا 192,200 كم وجاذبية الأرض تُبطئنا',
      'Halfway! 192,200 km done — Earth\'s gravity is slowing us down',
      image: 'assets/images/orion_earth_moon.jpg',
      captionAr: 'أوريون تصوّر الأرض والقمر معاً — أرتميس 1',
      captionEn: 'Orion sees Earth and Moon together — Artemis I'),
  JourneyFact(290000, 'دخلنا منطقة جاذبية القمر. سطحه مليء بالفوهات لأنه بلا غلاف جوي يحرق النيازك',
      'Entering the Moon\'s gravity zone. It is full of craters: no air to burn up meteoroids',
      image: 'assets/images/moon_flyby.jpg',
      captionAr: 'القمر من كاميرا أوريون — أرتميس 1',
      captionEn: 'The Moon from Orion\'s camera — Artemis I'),
];

class _Rock {
  final int kind; // 0 صغيرة، 1 متوسطة، 2 كبيرة، 3 شهاب (في الغلاف الجوي)، 4 الكويكب العملاق
  V3 pos;
  V3 vel;
  final double radius;
  double hp;
  final double maxHp;
  final int mesh;
  double ax, ay, az;
  final double sx, sy, sz;
  double age = 0;
  double hitFlash = 0;
  double throwTimer = 2.5;
  bool dead = false;
  bool passed = false;

  _Rock({
    required this.kind,
    required this.pos,
    required this.vel,
    required this.radius,
    required this.hp,
    required this.mesh,
    required math.Random rnd,
  })  : maxHp = hp,
        ax = rnd.nextDouble() * 6,
        ay = rnd.nextDouble() * 6,
        az = rnd.nextDouble() * 6,
        sx = (rnd.nextDouble() - .5) * 2.4,
        sy = (rnd.nextDouble() - .5) * 2.4,
        sz = (rnd.nextDouble() - .5) * 1.4;

  bool get isBoss => kind == 4;
  M3 get rot => M3.rotZ(az) * M3.rotY(ay) * M3.rotX(ax);
}

class _Laser {
  V3 pos, prev;
  final V3 vel;
  double age = 0;
  bool dead = false;
  _Laser(this.pos, this.vel) : prev = pos;
}

class _Particle {
  V3 pos;
  V3 vel;
  double life;
  final double maxLife, size;
  final Color color;
  final double drag;
  final bool glow;
  _Particle(this.pos, this.vel, this.life, this.size, this.color, {this.drag = 1.2, this.glow = true}) : maxLife = life;
}

/// أجسام المشهد غير الخطرة: محطة الفضاء، الأقمار الصناعية، المراحل المنفصلة.
class _Scenery {
  final String kind; // iss, gps, geo, srbL, srbR, core
  V3 pos;
  V3 vel;
  double angle = 0;
  final double spin;
  final V3 axis;
  _Scenery(this.kind, this.pos, this.vel, {this.spin = 0, this.axis = const V3(1, 0, 0)});
}

class _Puff {
  V3 pos;
  final double size;
  _Puff(this.pos, this.size);
}

class JourneyWorld extends ChangeNotifier {
  final bool arabic;
  final math.Random rnd;

  Size size = Size.zero;
  JourneyPhase phase = JourneyPhase.countdown;
  bool ready = true;
  double countdown = kCountdownSeconds;
  double liftoffT = 0;
  double time = 0;
  double clock = 0;
  double progress = 0;
  double km = 0;
  double realSeconds = 0;
  double groundAngle = 0;

  // المركبة
  double px = 0, py = 0;
  double vx = 0, vy = 0;
  double bank = 0;
  bool srbAttached = true;
  bool coreAttached = true;
  double separationT = 0; // زمن منذ انفصال المرحلة الأساسية
  double deploy = 0; // الألواح الشمسية
  double engineBurn = 1;

  bool firing = false;
  double fireCooldown = 0;
  int lives = 3;
  double invulnerable = 0;
  double damageFlash = 0;
  int score = 0;
  int kills = 0;
  double spawnTimer = 1.5;
  double puffTimer = 0;
  bool bossSpawned = false;
  bool bossDefeated = false;
  double arrivalT = 0;
  double shake = 0;

  int nextFact = 0;
  JourneyFact? fact;
  String factText = '';
  double factTimer = 0;
  int arrivalFacts = 0;

  final List<_Rock> rocks = [];
  final List<_Laser> lasers = [];
  final List<_Particle> particles = [];
  final List<_Scenery> scenery = [];
  final List<_Puff> puffs = [];
  late final List<V3> dust;

  /// أحداث صوتية ينفذها مشغل الصوت ثم يفرغها.
  final List<(String, double)> sounds = [];

  JourneyWorld({required this.arabic, int? seed}) : rnd = math.Random(seed) {
    final r = math.Random(5);
    dust = List.generate(110, (_) => V3((r.nextDouble() - .5) * 30, (r.nextDouble() - .5) * 20, r.nextDouble() * 110));
  }

  String tr(String ar, String en) => arabic ? ar : en;

  V3 get probePos => V3(px, py, 0);
  double get speedKmh => (phase == JourneyPhase.countdown || phase == JourneyPhase.liftoff) ? 0 : speedKmhAt(km);
  bool get bossFight => bossSpawned && !bossDefeated;
  bool get stackAttached => coreAttached;

  /// اتجاه المركبة: يبدأ الصاروخ عمودياً تقريباً ثم يميل نحو الأفق
  /// (مناورة الدوران بالجاذبية)، مع ميلان جانبي أثناء التوجيه.
  M3 get probeRot {
    final pitch = coreAttached ? 1.05 * (1 - _smooth(0, 70, km)) : 0.0;
    return M3.rotZ(bank) * M3.rotX(-pitch - vy * .02);
  }

  /// 1 داخل الغلاف الجوي و0 في الفضاء.
  double get atmosphere => 1 - _smooth(8, 100, km);

  _Rock? get boss {
    for (final m in rocks) {
      if (m.isBoss) return m;
    }
    return null;
  }

  /// سرعة اقتراب الأجسام بوحدات العالم في الثانية.
  double get approachSpeed {
    if (phase == JourneyPhase.flying) return (26 + 30 * progress) * _clamp01(.25 + time / 6);
    if (phase == JourneyPhase.arrival) return 26 * (1 - _smooth(0, 3, arrivalT));
    return 0;
  }

  String get zoneName {
    if (phase == JourneyPhase.arrival || phase == JourneyPhase.won) return tr('مدار القمر', 'Lunar orbit');
    if (km < 12) return tr('التروبوسفير', 'Troposphere');
    if (km < 50) return tr('الستراتوسفير', 'Stratosphere');
    if (km < 85) return tr('الميزوسفير', 'Mesosphere');
    if (km < 100) return tr('الثيرموسفير', 'Thermosphere');
    if (km < 2000) return tr('مدار أرضي منخفض', 'Low Earth orbit');
    if (km < 60000) return tr('أحزمة فان ألن والأقمار الصناعية', 'Van Allen belts & satellites');
    if (km < 290000) return tr('الفضاء بين الأرض والقمر', 'Cislunar space');
    return tr('مجال جاذبية القمر', 'Moon\'s gravity zone');
  }

  // مستويات الصوت المستمرة
  double get roarLevel {
    if (phase == JourneyPhase.liftoff) return 1;
    if (phase != JourneyPhase.flying) return 0;
    final tli = km > 950 && km < 1600 ? .35 : 0.0; // حرق الانتقال إلى القمر
    return math.max(1 - _smooth(20, 100, km), tli);
  }

  double get ambienceLevel {
    if (phase == JourneyPhase.countdown || phase == JourneyPhase.liftoff) return 0;
    return .55 * _smooth(50, 130, km);
  }

  double get engineLevel {
    if (phase == JourneyPhase.flying && !coreAttached) return .18 + engineBurn * .3;
    if (phase == JourneyPhase.arrival) return .25;
    return 0;
  }

  void sound(String id, [double volume = 1]) => sounds.add((id, volume));

  void showFact(JourneyFact f) {
    fact = f;
    factText = tr(f.ar, f.en);
    factTimer = f.image != null ? 7 : 5.5;
  }

  void showText(String ar, String en, {String? image, String? capAr, String? capEn}) =>
      showFact(JourneyFact(km, ar, en, image: image, captionAr: capAr, captionEn: capEn));

  void setFiring(bool v) {
    firing = v;
    if (v) tapFire();
  }

  void tapFire() {
    if (phase == JourneyPhase.flying && fireCooldown <= 0.06) _shoot();
  }

  /// توجيه بالسحب: [dx] و[dy] بالبكسل.
  void steer(double dx, [double dy = 0]) {
    if (size.width <= 0) return;
    if (phase != JourneyPhase.flying && phase != JourneyPhase.countdown) return;
    final k = 2 * kMaxX / size.width * 1.15;
    final nx = (px + dx * k).clamp(-kMaxX, kMaxX);
    final ny = (py - dy * k).clamp(kMinY, kMaxY);
    vx = vx * .5 + (nx - px) * 30;
    vy = vy * .5 + (ny - py) * 30;
    px = nx;
    py = ny;
  }

  void tick(double dt) {
    if (size.isEmpty || !ready) return;
    if (dt > .05) dt = .05;
    clock += dt;
    if (factTimer > 0) factTimer -= dt;
    if (shake > 0) shake = math.max(0, shake - dt * 2.2);
    damageFlash = math.max(0, damageFlash - dt * 2);
    vx *= math.max(0, 1 - dt * 8);
    vy *= math.max(0, 1 - dt * 8);
    bank += ((-vx * .045).clamp(-.45, .45) - bank) * math.min(1, dt * 6);
    _updateParticles(dt);

    switch (phase) {
      case JourneyPhase.countdown:
        final before = countdown.ceil();
        countdown -= dt;
        final after = countdown.ceil();
        if (after != before && after >= 1 && after <= 5) sound('beep', .8);
        if (countdown <= 0) {
          phase = JourneyPhase.liftoff;
          liftoffT = 0;
          sound('beep_go');
          sound('roar');
          shake = .8;
        }
        break;
      case JourneyPhase.liftoff:
        liftoffT += dt;
        shake = math.max(shake, .55);
        if (liftoffT >= kLiftoffSeconds) {
          phase = JourneyPhase.flying;
          _checkFacts();
        }
        break;
      case JourneyPhase.flying:
        _updateFlight(dt);
        break;
      case JourneyPhase.arrival:
        _updateArrival(dt);
        break;
      case JourneyPhase.won:
        arrivalT += dt;
        _updateRocks(dt);
        _updateLasers(dt);
        break;
      case JourneyPhase.lost:
        _updateRocks(dt);
        _updateLasers(dt);
        break;
    }
    _updateScenery(dt);
    _updateAmbient(dt);
    notifyListeners();
  }

  void _setProgress(double p) {
    progress = p;
    final newKm = kmAtProgress(p);
    final v = math.max(1500.0, speedKmhAt((km + newKm) / 2));
    final dtReal = (newKm - km) / v * 3600;
    realSeconds += dtReal;
    if (km < 2000) groundAngle += dtReal * 7.6 / kEarthRadiusKm;
    km = newKm;
  }

  void _checkFacts() {
    while (nextFact < journeyFacts.length && km >= journeyFacts[nextFact].km) {
      final f = journeyFacts[nextFact];
      showFact(f);
      nextFact++;
      _onMilestone(f.km);
    }
  }

  void _onMilestone(double at) {
    if (at == 330) {
      scenery.add(_Scenery('iss', const V3(10, -2.5, 170), const V3(0, 0, -30), spin: .05, axis: const V3(0, 1, 0)));
    } else if (at == 18000) {
      scenery.add(_Scenery('gps', const V3(-9, 3, 160), const V3(0, 0, -34), spin: .3, axis: const V3(0, 0, 1)));
    } else if (at == 33000) {
      scenery.add(_Scenery('geo', const V3(9, -3, 160), const V3(0, 0, -34), spin: .2, axis: const V3(0, 1, 0)));
    } else if (at == 1000) {
      engineBurn = 1;
      sound('roar', .35);
      shake = .4;
    }
  }

  void _updateFlight(double dt) {
    time += dt;
    final ramp = _clamp01(.2 + time / 7);
    if (!bossFight) {
      _setProgress(math.min(1.0, progress + dt * ramp / kJourneySeconds));
    }
    _checkFacts();

    // مراحل الصاروخ
    if (srbAttached && km >= 45) {
      srbAttached = false;
      scenery
        ..add(_Scenery('srbL', V3(px, py, 0), V3(-4, 1, -26), spin: 1.2, axis: const V3(0, 1, .3)))
        ..add(_Scenery('srbR', V3(px, py, 0), V3(4, 1, -26), spin: -1.2, axis: const V3(0, 1, -.3)));
      shake = .5;
      sound('whoosh', .8);
    }
    if (coreAttached && km >= 125) {
      coreAttached = false;
      scenery.add(_Scenery('core', V3(px, py, 0), const V3(0, -2.5, -14), spin: .5, axis: const V3(1, 0, .2)));
      shake = .4;
      sound('whoosh', .8);
      engineBurn = .3;
    }
    if (!coreAttached) {
      separationT += dt;
      deploy = _clamp01(deploy + dt / 3);
    }
    // حرق الانتقال إلى القمر بين 1000 و 1600 كم
    final targetBurn = coreAttached ? 1.0 : (km > 950 && km < 1600 ? 1.0 : .2);
    engineBurn += (targetBurn - engineBurn) * math.min(1, dt * 2);

    if (!bossSpawned && progress >= kBossAt) _spawnBoss();
    if (bossDefeated && progress >= 1) {
      phase = JourneyPhase.arrival;
      arrivalT = 0;
      firing = false;
      sound('thrusters', .9);
      showText('إطلاق المحركات للإبطاء… ندخل مدار القمر على ارتفاع 130 كم مثل أرتميس 1',
          'Braking burn… entering lunar orbit at 130 km, just like Artemis I');
    }

    // العقبات
    if (!bossSpawned) {
      spawnTimer -= dt;
      if (spawnTimer <= 0) {
        if (km > 60 && km < 115) {
          _spawnShootingStar();
          spawnTimer = .9 + rnd.nextDouble() * .8;
        } else if (km >= 400) {
          _spawnRock();
          if (progress > .55 && rnd.nextDouble() < .3) _spawnRock();
          spawnTimer = _lerp(1.7, .6, progress) * (.7 + rnd.nextDouble() * .6);
        } else {
          spawnTimer = .3;
        }
      }
    }

    fireCooldown -= dt;
    if (firing && fireCooldown <= 0) _shoot();
    invulnerable = math.max(0, invulnerable - dt);

    _updateLasers(dt);
    _updateRocks(dt);
    _collisions();
  }

  void _updateArrival(double dt) {
    arrivalT += dt;
    px = _lerp(px, 0, dt * 1.5);
    py = _lerp(py, -.6, dt * 1.5);
    engineBurn += (.15 - engineBurn) * math.min(1, dt);
    _updateLasers(dt);
    _updateRocks(dt);
    if (arrivalFacts == 0 && arrivalT > 3.2) {
      arrivalFacts = 1;
      showText('انظر! شروق الأرض فوق أفق القمر — المنظر نفسه الذي صوّره رواد أبولو 8',
          'Look! Earthrise over the lunar horizon — the view Apollo 8 astronauts photographed',
          image: 'assets/images/earthrise.jpg', capAr: 'شروق الأرض — أبولو 8، 1968', capEn: 'Earthrise — Apollo 8, 1968');
    }
    if (arrivalT >= kArrivalSeconds) {
      phase = JourneyPhase.won;
      score += lives * 100;
      sound('success');
    }
  }

  void _shoot() {
    fireCooldown = .17;
    final nose = V3(px, py, 1.5);
    const speed = 150.0;
    // مساعدة تصويب: نحو أقرب صخرة أمام المركبة
    _Rock? best;
    var bestD = double.infinity;
    for (final r in rocks) {
      if (r.dead || r.pos.z < 3) continue;
      final dx = r.pos.x - px, dy = r.pos.y - py;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < r.radius * .9 + 1.8 && d < bestD) {
        bestD = d;
        best = r;
      }
    }
    var dir = const V3(0, 0, 1);
    if (best != null) {
      final t = (best.pos.z - nose.z) / (speed - best.vel.z);
      final target = best.pos + best.vel * t;
      dir = (target - nose).normalized;
    }
    lasers.add(_Laser(nose, dir * speed));
    sound('laser', .45);
  }

  void _spawnRock() {
    final roll = rnd.nextDouble();
    int kind;
    if (progress < .35) {
      kind = roll < .7 ? 0 : 1;
    } else if (progress < .7) {
      kind = roll < .45 ? 0 : (roll < .85 ? 1 : 2);
    } else {
      kind = roll < .3 ? 0 : (roll < .65 ? 1 : 2);
    }
    final radius = [.75, 1.35, 2.1][kind] * (.85 + rnd.nextDouble() * .3);
    final aimed = rnd.nextDouble() < .4;
    final x = aimed ? px + (rnd.nextDouble() - .5) * 2 : (rnd.nextDouble() - .5) * 2 * (kMaxX + 1.5);
    final y = aimed ? py + (rnd.nextDouble() - .5) * 2 : _lerp(kMinY - 1, kMaxY + 1, rnd.nextDouble());
    final speed = approachSpeed * (kind == 0 && rnd.nextDouble() < .3 ? 1.7 : 1.0);
    rocks.add(_Rock(
      kind: kind,
      pos: V3(x, y, 150),
      vel: V3((rnd.nextDouble() - .5) * 2, (rnd.nextDouble() - .5) * 1.5, -speed),
      radius: radius,
      hp: [1.0, 2.0, 4.0][kind],
      mesh: rnd.nextInt(6),
      rnd: rnd,
    ));
  }

  void _spawnShootingStar() {
    final x = (rnd.nextDouble() - .5) * 2 * kMaxX;
    final y = _lerp(kMinY, kMaxY, rnd.nextDouble());
    rocks.add(_Rock(
      kind: 3,
      pos: V3(x + (rnd.nextBool() ? 6 : -6), y + 4, 140),
      vel: V3(x > 0 ? -2.0 : 2.0, -1.2, -approachSpeed * 1.4),
      radius: .45,
      hp: 1,
      mesh: rnd.nextInt(6),
      rnd: rnd,
    ));
  }

  void _spawnBoss() {
    bossSpawned = true;
    rocks.add(_Rock(
      kind: 4,
      pos: const V3(0, 9, 170),
      vel: const V3(0, 0, -20),
      radius: 12,
      hp: 30,
      mesh: 6,
      rnd: rnd,
    ));
    sound('warning');
    showText('كويكب عملاق يسدّ الطريق إلى القمر! حطّمه بالليزر لتتمكن من الوصول',
        'A giant asteroid blocks the way to the Moon! Blast it with your laser to get through');
  }

  void _updateLasers(double dt) {
    for (final s in lasers) {
      s.prev = s.pos;
      s.pos = s.pos + s.vel * dt;
      s.age += dt;
      if (s.pos.z > 190 || s.age > 1.6) s.dead = true;
    }
    lasers.removeWhere((s) => s.dead);
  }

  void _updateRocks(double dt) {
    final pp = probePos;
    final thrown = <_Rock>[];
    for (final m in rocks) {
      m.age += dt;
      m.hitFlash = math.max(0, m.hitFlash - dt * 5);
      m.ax += m.sx * dt;
      m.ay += m.sy * dt;
      m.az += m.sz * dt;
      if (m.isBoss) {
        final tz = 52.0;
        final z = m.pos.z + (tz - m.pos.z) * math.min(1, dt * .8);
        m.pos = V3(math.sin(m.age * .5) * 4, 9 + math.sin(m.age * .37) * 1.5, z);
        if (phase == JourneyPhase.flying && m.pos.z < 70) {
          m.throwTimer -= dt;
          if (m.throwTimer <= 0) {
            final rage = m.hp < m.maxHp / 2;
            m.throwTimer = rage ? 1.0 : 1.5;
            for (int i = 0; i < (rage ? 2 : 1); i++) {
              final from = m.pos + V3((rnd.nextDouble() - .5) * 4, (rnd.nextDouble() - .5) * 4, -m.radius * .8);
              final aim = pp + V3((rnd.nextDouble() - .5) * 2.5, (rnd.nextDouble() - .5) * 2.5, 0);
              thrown.add(_Rock(
                kind: 0,
                pos: from,
                vel: (aim - from).normalized * 30,
                radius: .55 + rnd.nextDouble() * .3,
                hp: 1,
                mesh: rnd.nextInt(6),
                rnd: rnd,
              ));
            }
          }
        }
        continue;
      }
      m.pos = m.pos + m.vel * dt;
      if (m.kind == 3) {
        // الشهاب يحترق ويترك أثراً متوهجاً
        if (rnd.nextDouble() < .8) {
          particles.add(_Particle(m.pos, m.vel * .1 + V3(rnd.nextDouble() - .5, rnd.nextDouble() - .5, 0), .45, .35 + rnd.nextDouble() * .3,
              const Color(0xFFFFB04A)));
        }
      }
      if (!m.passed && m.pos.z < -2) {
        m.passed = true;
        final dx = m.pos.x - px, dy = m.pos.y - py;
        if (dx * dx + dy * dy < 16 && phase == JourneyPhase.flying) sound('whoosh', .5);
      }
      if (m.pos.z < -16) m.dead = true;
    }
    rocks
      ..removeWhere((m) => m.dead)
      ..addAll(thrown);
  }

  void _collisions() {
    for (final s in lasers) {
      for (final m in rocks) {
        if (m.dead || s.dead) continue;
        // أقرب نقطة على مسار الشعاع خلال هذا الإطار
        final seg = s.pos - s.prev;
        final l2 = seg.dot(seg);
        final t = l2 == 0 ? 0.0 : _clamp01((m.pos - s.prev).dot(seg) / l2);
        final c = s.prev + seg * t;
        final d = (m.pos - c).length;
        if (d < m.radius * 1.05 + .3) {
          s.dead = true;
          m.hp -= 1;
          m.hitFlash = 1;
          _sparks(c, 8, const Color(0xFF9EF6FF), 10);
          if (m.hp <= 0) _destroy(m);
          break;
        }
      }
    }
    lasers.removeWhere((s) => s.dead);

    if (invulnerable <= 0 && phase == JourneyPhase.flying) {
      for (final m in rocks) {
        if (m.dead || m.isBoss) continue;
        if (m.pos.z.abs() > m.radius + .7) continue;
        final dx = m.pos.x - px, dy = m.pos.y - py;
        final rr = m.radius * .8 + .7;
        if (dx * dx + dy * dy < rr * rr) {
          m.dead = true;
          _explode(m.pos, m.radius, m.kind == 3);
          _hitProbe();
          break;
        }
      }
    }
    rocks.removeWhere((m) => m.dead);
  }

  void _destroy(_Rock m) {
    m.dead = true;
    kills++;
    const points = [10, 20, 35, 15, 500];
    score += points[m.kind];
    _explode(m.pos, m.radius, m.kind == 3);
    if (m.kind == 1 || m.kind == 2) {
      // الصخرة تتفتت إلى قطع أصغر
      final n = m.kind == 1 ? 2 : 3;
      for (int i = 0; i < n; i++) {
        final a = i / n * math.pi * 2 + rnd.nextDouble();
        rocks.add(_Rock(
          kind: 0,
          pos: m.pos + V3(math.cos(a), math.sin(a), 0) * m.radius * .6,
          vel: m.vel + V3(math.cos(a) * 5, math.sin(a) * 5, 0),
          radius: m.radius * .45,
          hp: 1,
          mesh: rnd.nextInt(6),
          rnd: rnd,
        ));
      }
    }
    if (m.isBoss) {
      bossDefeated = true;
      shake = 1.4;
      for (final r in rocks) {
        if (!r.isBoss && r.pos.z > 0) {
          r.dead = true;
          _explode(r.pos, r.radius, false);
        }
      }
      for (int i = 0; i < 4; i++) {
        _explode(m.pos + V3((rnd.nextDouble() - .5) * 6, (rnd.nextDouble() - .5) * 6, 0), 3, false);
      }
      showText('حطّمت الكويكب العملاق! الطريق إلى القمر مفتوح الآن',
          'You smashed the giant asteroid! The way to the Moon is clear');
    }
  }

  void _hitProbe() {
    lives--;
    invulnerable = 1.8;
    shake = 1;
    damageFlash = 1;
    sound('hit');
    _sparks(probePos, 24, const Color(0xFFFF8A50), 9);
    if (lives <= 0) {
      phase = JourneyPhase.lost;
      firing = false;
      _explode(probePos, 2.5, false);
      _sparks(probePos, 60, const Color(0xFFFFD27A), 14);
    }
  }

  void _explode(V3 at, double r, bool hot) {
    sound('explosion', (.35 + r * .25).clamp(.3, 1.0));
    particles.add(_Particle(at, V3.zero, .35, r * 2.6, const Color(0xFFFFF1C4)));
    final n = (10 + r * 14).round();
    for (int i = 0; i < n; i++) {
      final d = V3(rnd.nextDouble() - .5, rnd.nextDouble() - .5, rnd.nextDouble() - .5).normalized;
      final v = d * (r * (3 + rnd.nextDouble() * 6));
      particles.add(_Particle(at + d * r * .4, v, .7 + rnd.nextDouble() * .8, r * (.08 + rnd.nextDouble() * .14),
          hot ? const Color(0xFFFFB04A) : const Color(0xFF9A8F84),
          drag: .4, glow: hot));
    }
    _sparks(at, (6 + r * 6).round(), const Color(0xFFFFC66B), 6 + r * 3);
  }

  void _sparks(V3 at, int n, Color c, double speed) {
    for (int i = 0; i < n; i++) {
      final d = V3(rnd.nextDouble() - .5, rnd.nextDouble() - .5, rnd.nextDouble() - .5).normalized;
      particles.add(_Particle(at, d * speed * (.4 + rnd.nextDouble() * .6), .25 + rnd.nextDouble() * .35, .12 + rnd.nextDouble() * .12, c));
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.pos = p.pos + p.vel * dt;
      p.vel = p.vel * math.max(0, 1 - dt * p.drag);
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);
    if (particles.length > 900) particles.removeRange(0, particles.length - 900);
  }

  void _updateScenery(double dt) {
    for (final s in scenery) {
      s.pos = s.pos + s.vel * dt;
      s.angle += s.spin * dt;
      if (s.kind == 'core' || s.kind.startsWith('srb')) s.vel = s.vel + const V3(0, -1.5, -3) * dt;
    }
    scenery.removeWhere((s) => s.pos.z < -60 || s.pos.y < -60);
  }

  /// غيوم، غبار فضائي، ونار العادم.
  void _updateAmbient(double dt) {
    final v = approachSpeed;
    // غيوم أثناء الصعود
    if ((phase == JourneyPhase.flying) && km < 11) {
      puffTimer -= dt;
      if (puffTimer <= 0) {
        puffTimer = .09;
        puffs.add(_Puff(V3((rnd.nextDouble() - .5) * 70, -5 + rnd.nextDouble() * 14 - km * 2.2, 120), 5 + rnd.nextDouble() * 8));
      }
    }
    for (final p in puffs) {
      p.pos = p.pos + V3(0, -6 - km * .8, -v * 2.4) * dt;
    }
    puffs.removeWhere((p) => p.pos.z < -20);

    for (int i = 0; i < dust.length; i++) {
      var d = dust[i];
      d = d + V3(0, 0, -v * 1.6 * dt);
      if (d.z < -12) d = V3((rnd.nextDouble() - .5) * 30, (rnd.nextDouble() - .5) * 20, 100 + rnd.nextDouble() * 10);
      dust[i] = d;
    }

    // عادم المحرك
    if (phase == JourneyPhase.flying || phase == JourneyPhase.liftoff || phase == JourneyPhase.arrival) {
      if (coreAttached) {
        final inAir = km < 40;
        final rot = probeRot;
        final base = probePos;
        for (int k = 0; k < 3; k++) {
          final off = V3((rnd.nextDouble() - .5) * .8, (rnd.nextDouble() - .5) * .8, 0);
          particles.add(_Particle(base + rot.apply(V3(off.x, off.y, -7.9)), rot.apply(V3(off.x * 4, off.y * 4, -40 - rnd.nextDouble() * 20)),
              inAir ? 1.2 : .7, inAir ? 1.1 + rnd.nextDouble() : .8, inAir ? const Color(0xFFD8D2CA) : const Color(0xFFFFB45A),
              drag: inAir ? 1.5 : .3, glow: !inAir));
        }
        if (srbAttached) {
          for (final s in [-1.0, 1.0]) {
            particles.add(_Particle(base + rot.apply(V3(s, 0, -8)), rot.apply(V3(s * 2, (rnd.nextDouble() - .5) * 3, -45)), 1.4,
                1.4 + rnd.nextDouble(), const Color(0xFFE8E2DA), drag: 1.6, glow: false));
          }
        }
      } else if (engineBurn > .35 && rnd.nextDouble() < engineBurn) {
        particles.add(_Particle(V3(px, py, -1.25), V3((rnd.nextDouble() - .5) * 2, (rnd.nextDouble() - .5) * 2, -22), .35, .35,
            const Color(0xFF8FB8FF)));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// الهندسة السماوية (اتجاهات الأجرام وأحجامها الظاهرية الحقيقية)
// ---------------------------------------------------------------------------

/// اتجاه الشمس (من الأجسام نحو الشمس) — خلف المركبة ومن الأعلى يساراً.
final V3 kSunDir = const V3(-.86, .42, -.2).normalized;
final V3 _moonDirFlight = const V3(.16, .1, 1).normalized;
final V3 _moonDirOrbit = const V3(0, -1, .36).normalized;

class SkyState {
  final V3 earthDir;
  final double earthAlpha; // نصف القطر الزاوي (راديان)
  final V3 moonDir;
  final double moonAlpha;
  final double earthDistKm;
  final double moonDistKm;
  const SkyState(this.earthDir, this.earthAlpha, this.moonDir, this.moonAlpha, this.earthDistKm, this.moonDistKm);
}

SkyState skyFor(JourneyWorld w) {
  final km = w.km;
  if (w.phase == JourneyPhase.arrival || w.phase == JourneyPhase.won || (w.phase == JourneyPhase.lost && w.progress >= 1)) {
    final u = _smooth(0, 4.5, w.arrivalT);
    final moonDir = V3.lerp(_moonDirFlight, _moonDirOrbit, u).normalized;
    final moonAlpha = angularRadius(kMoonRadiusKm, kMoonRadiusKm + kLunarOrbitKm);
    final rise = _smooth(2.5, 8.5, w.arrivalT);
    final earthDir = V3(-.32, _lerp(-.3, .1, rise), 1).normalized;
    return SkyState(earthDir, angularRadius(kEarthRadiusKm, kEarthMoonKm) * 2.6, moonDir, moonAlpha, kEarthMoonKm, kMoonRadiusKm + kLunarOrbitKm);
  }
  // الأرض: تحتنا في المدار المنخفض، ثم تنتقل خلفنا بعد الانطلاق نحو القمر
  final behind = _smooth(math.log(900), math.log(30000), math.log(km + 1));
  final earthDir = V3.lerp(const V3(0, -1, 0), const V3(0, -.35, -1).normalized, behind).normalized;
  final ed = kEarthRadiusKm + km;
  final md = math.max(kMoonRadiusKm + kLunarOrbitKm, kEarthMoonKm - km);
  // القمر يُكبّر قليلاً للعرض عندما يكون بعيداً، ثم يعود لحجمه الحقيقي عند الاقتراب
  final mag = 1 + 2 * (1 - _smooth(.88, .99, w.progress));
  final moonAlpha = math.min(1.2, angularRadius(kMoonRadiusKm, md) * mag);
  return SkyState(earthDir, angularRadius(kEarthRadiusKm, ed), _moonDirFlight, moonAlpha, ed, md);
}

// ---------------------------------------------------------------------------
// الصفحة
// ---------------------------------------------------------------------------

class RocketJourneyPage extends StatefulWidget {
  final bool arabic;
  final String Function(String, String) tr;

  /// تُبنى الصفحة التالية (مستويات الأسئلة) بعد الوصول للقمر.
  final Widget Function(int score) buildNext;

  /// تحميل الصور والأصوات (يُعطّل في الاختبارات).
  final bool loadMedia;

  const RocketJourneyPage({
    super.key,
    required this.arabic,
    required this.tr,
    required this.buildNext,
    this.loadMedia = true,
  });

  @override
  State<RocketJourneyPage> createState() => _RocketJourneyPageState();
}

class _RocketJourneyPageState extends State<RocketJourneyPage> with SingleTickerProviderStateMixin {
  late JourneyWorld world;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  SpaceArt art = SpaceArt();
  late final SpaceAudio audio;
  late final JourneyScene scene;

  @override
  void initState() {
    super.initState();
    world = _newWorld();
    audio = SpaceAudio(enabled: widget.loadMedia);
    scene = JourneyScene();
    _ticker = createTicker(_onTick)..start();
    if (widget.loadMedia) _loadMedia();
  }

  JourneyWorld _newWorld() => JourneyWorld(arabic: widget.arabic)..ready = !widget.loadMedia || art.loaded;

  Future<void> _loadMedia() async {
    final results = await Future.wait([SpaceArt.load(), audio.init()]);
    if (!mounted) {
      (results[0] as SpaceArt).dispose();
      return;
    }
    setState(() {
      art = results[0] as SpaceArt;
      world.ready = true;
    });
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    world.tick(dt);
    for (final (id, v) in world.sounds) {
      audio.play(id, volume: v);
    }
    world.sounds.clear();
    audio.levels(roar: world.roarLevel, ambience: world.ambienceLevel, engine: world.engineLevel);
  }

  void _restart() {
    audio.stopAll();
    setState(() {
      world.dispose();
      world = _newWorld();
    });
  }

  void _continue() {
    audio.stopAll();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.buildNext(world.score)),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    world.dispose();
    audio.stopAll();
    audio.dispose();
    art.dispose();
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
          final pad = MediaQuery.of(context).padding;
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => world.steer(d.delta.dx, d.delta.dy),
                onTapDown: (_) => world.tapFire(),
                child: RepaintBoundary(
                  child: CustomPaint(painter: JourneyPainter(world, art, scene, bottomPad: pad.bottom)),
                ),
              ),
              AnimatedBuilder(
                animation: world,
                builder: (context, _) => _LaunchPhotos(world: world, tr: tr),
              ),
              AnimatedBuilder(
                animation: world,
                builder: (context, _) => _Hud(
                  world: world,
                  tr: tr,
                  muted: audio.muted,
                  onMute: () => setState(() => audio.setMuted(!audio.muted)),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 26 + pad.bottom,
                child: _FireButton(world: world, label: tr('ليزر', 'Laser')),
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
        if (!world.ready) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                Text(tr('جارٍ تجهيز المركبة…', 'Preparing the spacecraft…')),
              ],
            ),
          );
        }
        final n = world.countdown.ceil();
        return IgnorePointer(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('المرحلة 1: من الأرض إلى القمر', 'Stage 1: Earth to Moon'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 10)]),
                ),
                const SizedBox(height: 12),
                Text(
                  n > 5 ? '' : 'T-$n',
                  style: const TextStyle(
                      fontSize: 84, fontWeight: FontWeight.w900, color: Colors.amber, shadows: [Shadow(blurRadius: 18)]),
                ),
              ],
            ),
          ),
        );
      case JourneyPhase.liftoff:
        return IgnorePointer(
          child: Center(
            child: Text(
              tr('انطلاق!', 'Liftoff!'),
              style: const TextStyle(
                  fontSize: 64, fontWeight: FontWeight.w900, color: Colors.amber, shadows: [Shadow(blurRadius: 18)]),
            ),
          ),
        );
      case JourneyPhase.won:
        if (world.arrivalT < kArrivalSeconds + 1.2) return const SizedBox.shrink();
        return _EndCard(
          image: 'assets/images/earthrise.jpg',
          icon: Icons.emoji_events,
          color: Colors.amber,
          title: tr('وصلت إلى القمر!', 'You reached the Moon!'),
          lines: [
            '${tr('النقاط', 'Score')}: ${world.score}',
            '${tr('الصخور المحطمة', 'Rocks smashed')}: ${world.kills}',
            '${tr('زمن الرحلة الحقيقي', 'Real mission time')}: ${_missionTime(world, tr)}',
          ],
          extra: widget.loadMedia
              ? TextButton.icon(
                  onPressed: () => audio.play('eagle'),
                  icon: const Icon(Icons.record_voice_over),
                  label: Text(tr('استمع لصوت أبولو 11 الحقيقي: "The Eagle has landed"',
                      'Hear the real Apollo 11 call: "The Eagle has landed"')),
                )
              : null,
          primary: tr('تابع إلى المستويات', 'Continue to levels'),
          onPrimary: _continue,
          secondary: tr('العب مجدداً', 'Play again'),
          onSecondary: _restart,
        );
      case JourneyPhase.lost:
        return _EndCard(
          icon: Icons.rocket_launch,
          color: Colors.redAccent,
          title: tr('تحطمت المركبة!', 'Spacecraft destroyed!'),
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
  final d = total ~/ 86400;
  final h = (total % 86400) ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final hm = '$h${tr('س', 'h')} ${m.toString().padLeft(2, '0')}${tr('د', 'm')}';
  return d > 0 ? '$d${tr('ي', 'd')} $hm' : hm;
}

/// الصور الحقيقية للصاروخ على منصة الإطلاق ثم لحظة الانطلاق.
class _LaunchPhotos extends StatelessWidget {
  final JourneyWorld world;
  final String Function(String, String) tr;
  const _LaunchPhotos({required this.world, required this.tr});

  @override
  Widget build(BuildContext context) {
    final w = world;
    if (!w.ready) return const SizedBox.shrink();
    double opacity;
    String image;
    double scale;
    String caption;
    Offset jitter = Offset.zero;
    switch (w.phase) {
      case JourneyPhase.countdown:
        image = 'assets/images/launch_pad.jpg';
        opacity = 1;
        scale = 1.05 + (kCountdownSeconds - w.countdown) * .02;
        caption = tr('صورة حقيقية: صاروخ SLS ومركبة أوريون على منصة الإطلاق 39B — مركز كينيدي، ناسا',
            'Real photo: SLS rocket and Orion on Launch Pad 39B — NASA Kennedy Space Center');
        break;
      case JourneyPhase.liftoff:
        image = 'assets/images/liftoff.jpg';
        opacity = 1;
        scale = 1.1 + w.liftoffT * .06;
        jitter = Offset(math.sin(w.clock * 70) * 4, math.cos(w.clock * 55) * 4);
        caption = tr('صورة حقيقية: إطلاق أرتميس 1 — ناسا', 'Real photo: Artemis I liftoff — NASA');
        break;
      case JourneyPhase.flying:
        if (w.time > 1.2) return const SizedBox.shrink();
        image = 'assets/images/liftoff.jpg';
        opacity = 1 - w.time / 1.2;
        scale = 1.26 + w.time * .3;
        caption = '';
        break;
      default:
        return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Opacity(
        opacity: _clamp01(opacity),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: Transform.translate(
                offset: jitter,
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
                  stops: [0, .25, .7, 1],
                ),
              ),
            ),
            if (caption.isNotEmpty)
              Positioned(
                left: 16,
                right: 110,
                bottom: 34 + MediaQuery.of(context).padding.bottom,
                child: Text(caption, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.35)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  final JourneyWorld world;
  final String Function(String, String) tr;
  final bool muted;
  final VoidCallback onMute;
  const _Hud({required this.world, required this.tr, required this.muted, required this.onMute});

  @override
  Widget build(BuildContext context) {
    final w = world;
    final frac = _clamp01(w.km / kEarthMoonKm);
    const small = TextStyle(fontSize: 12, color: Colors.white70);
    final f = w.fact;
    return SafeArea(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            padding: const EdgeInsets.fromLTRB(4, 2, 12, 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${formatInt(w.km)} / ${formatInt(kEarthMoonKm)} ${tr('كم', 'km')}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(w.zoneName, style: small),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onMute,
                      icon: Icon(muted ? Icons.volume_off : Icons.volume_up, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                    Row(
                      children: List.generate(
                        3,
                        (i) => Icon(i < w.lives ? Icons.shield : Icons.shield_outlined, color: Colors.lightBlueAccent, size: 19),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${w.score}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.amber)),
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
                      Text('${tr('السرعة', 'Speed')}: ${formatInt(w.speedKmh)} ${tr('كم/س', 'km/h')}', style: small),
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
                  Text(tr('الكويكب العملاق', 'Giant asteroid'),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: w.boss!.hp / w.boss!.maxHp,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ),
          AnimatedOpacity(
            opacity: w.factTimer > 0 && f != null ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2745).withValues(alpha: .86),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: .5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f?.image != null) ...[
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(f!.image!, width: 92, height: 92, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(width: 92, height: 92)),
                        ),
                        const SizedBox(height: 2),
                        Text(tr('صورة حقيقية: ناسا', 'Real photo: NASA'),
                            style: const TextStyle(fontSize: 9, color: Colors.white54)),
                      ],
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.factText, style: const TextStyle(fontSize: 14, height: 1.35)),
                        if (f?.captionAr != null) ...[
                          const SizedBox(height: 4),
                          Text(tr(f!.captionAr!, f.captionEn ?? f.captionAr!),
                              style: const TextStyle(fontSize: 11, color: Colors.lightBlueAccent)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (w.phase == JourneyPhase.flying && w.time < 7)
            Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: Text(
                tr('اسحب لتوجيه المركبة • اضغط زر الليزر لتحطيم الصخور', 'Drag to steer • Hold the laser button to blast rocks'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.white, shadows: [Shadow(blurRadius: 8)]),
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
          gradient: const RadialGradient(colors: [Color(0xFF7FE8FF), Color(0xFF0B6C9E)]),
          border: Border.all(color: Colors.white70, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 16, color: Color(0xFF29B6F6))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flare, size: 36, color: Colors.white),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _EndCard extends StatelessWidget {
  final String? image;
  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;
  final Widget? extra;
  final String primary;
  final VoidCallback onPrimary;
  final String secondary;
  final VoidCallback onSecondary;

  const _EndCard({
    this.image,
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
    this.extra,
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
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(22),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1830).withValues(alpha: .95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: .7), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(image!, height: 150, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                )
              else
                Icon(icon, color: color, size: 56),
              const SizedBox(height: 10),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l, style: const TextStyle(fontSize: 16)),
                ),
              if (extra != null) ...[const SizedBox(height: 6), extra!],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14)),
                child: Text(primary, style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(height: 6),
              TextButton(onPressed: onSecondary, child: Text(secondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الرسم ثلاثي الأبعاد
// ---------------------------------------------------------------------------

/// موارد الرسم الثابتة (الشبكات) — تُبنى مرة واحدة.
class JourneyScene {
  final UvSphere skySphere = UvSphere(40, 20);
  final List<Mesh> asteroids = [for (int i = 0; i < 6; i++) buildAsteroid(i * 7 + 3), buildAsteroid(99, detail: 2)];
  final Mesh core = buildSlsCore();
  final Mesh srbL = buildBooster(-1);
  final Mesh srbR = buildBooster(1);
  final Mesh iss = buildIss();
  final Mesh gps = buildSatellite();
  final Mesh geo = buildSatellite(body: const Color(0xFFD8D8D8));
  final Map<int, Mesh> _orion = {};
  final TriBatch batch = TriBatch();

  Mesh orion(double deploy) => _orion.putIfAbsent((deploy * 20).round(), () => buildOrion(deploy: (deploy * 20).round() / 20));

  /// اتجاه مركز المجرة على الخريطة (القوس/الرامي): u≈0.77 ، v≈0.66
  late final M3 skyOrient = M3.align(
    UvSphere.dirFromUv(.77, .66),
    const V3(0, 1, 0),
    const V3(.42, .2, 1).normalized,
    const V3(.45, 1, 0),
  );

  /// موقع مركز كينيدي للفضاء (28.6° شمالاً، 80.6° غرباً) تحت المركبة عند الانطلاق.
  static final V3 _ksc = UvSphere.dirFromLatLon(28.6, -80.6);

  M3 earthOrient(JourneyWorld w, V3 earthDir) {
    // الشمال المحلي نحو يسار مسار الرحلة (نحن نطير نحو الشرق)
    final align = M3.align(_ksc, const V3(0, 1, 0), -earthDir, const V3(-1, 0, 0));
    final spin = M3.rotY(-w.realSeconds * 2 * math.pi / 86164);
    return M3.rotX(-w.groundAngle) * align * spin;
  }

  M3 moonOrient(V3 moonDir) {
    // الوجه القريب من القمر يواجه الأرض دائماً (ونحن قادمون من الأرض)
    return M3.align(const V3(0, 0, -1), const V3(0, 1, 0), -moonDir, const V3(0, 1, 0));
  }
}

class JourneyPainter extends CustomPainter {
  final JourneyWorld w;
  final SpaceArt art;
  final JourneyScene scene;
  final double bottomPad;
  JourneyPainter(this.w, this.art, this.scene, {this.bottomPad = 0}) : super(repaint: w);

  final Camera cam = Camera();
  final Camera sky = Camera();

  void _setupCamera(Size size) {
    cam.setViewport(size, hfovDeg: 70);
    final p = w.probePos;
    // كاميرا جانبية خلفية أثناء صعود الصاروخ، ثم كاميرا مطاردة خلف أوريون
    final chase = _smooth(0, 2.2, w.separationT);
    final eyeA = p * .7 + const V3(6.5, 2.4, -10.5);
    final tgtA = p * .9 + w.probeRot.apply(const V3(0, 0, -2.6)) + const V3(-.4, .3, 0);
    final eyeB = V3(p.x * .55, p.y * .55 + 2.1, -8.2);
    final tgtB = V3(p.x * .72, p.y * .72 + .95, 20);
    var eye = V3.lerp(eyeA, eyeB, chase);
    final tgt = V3.lerp(tgtA, tgtB, chase);
    if (w.shake > 0) {
      final m = w.shake * .18;
      eye = eye + V3(math.sin(w.clock * 83) * m, math.cos(w.clock * 71) * m, 0);
    }
    cam.lookAt(eye, tgt, roll: w.bank * .45);
    sky
      ..rot = cam.rot
      ..focal = cam.focal
      ..cx = cam.cx
      ..cy = cam.cy
      ..pos = V3.zero;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    if (!w.ready) return;
    _setupCamera(size);
    final st = skyFor(w);
    final atm = w.atmosphere;

    _drawSkybox(canvas, sky, 1 - atm * .97);
    _drawAtmosphereSky(canvas, size, atm);
    if (atm < .5) {
      _drawPlanets(canvas, size);
      _drawComet(canvas, size);
    }
    _drawEarth(canvas, size, sky, st);
    _drawMoon(canvas, sky, st);
    _drawHaze(canvas, size, atm);
    _drawPuffs(canvas);
    _drawDust(canvas);
    _drawObjects(canvas);
    _drawEffects(canvas);
    if (w.damageFlash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.transparent, Colors.red.withValues(alpha: .55 * w.damageFlash)],
            stops: const [.55, 1],
          ).createShader(Offset.zero & size),
      );
    }
    _drawRearView(canvas, size, st);
  }

  // --- السماء -------------------------------------------------------------

  void _drawSkybox(Canvas canvas, Camera c, double opacity) {
    if (opacity <= 0.01) return;
    if (art.sky != null) {
      drawSphere(canvas, c, scene.skySphere,
          center: V3.zero,
          radius: 500,
          orient: scene.skyOrient,
          inside: true,
          style: SphereStyle(texture: art.sky, fallback: Colors.black, lit: false, opacity: opacity));
    } else {
      // نجوم احتياطية
      final r = math.Random(3);
      final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
      for (int i = 0; i < 300; i++) {
        final d = V3(r.nextDouble() - .5, r.nextDouble() - .5, r.nextDouble() - .5).normalized;
        final o = c.projectDir(d);
        if (o != null) canvas.drawCircle(o, .5 + r.nextDouble(), paint);
      }
    }
  }

  void _drawAtmosphereSky(Canvas canvas, Size size, double atm) {
    if (atm <= 0) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF000814), const Color(0xFF1E64B4), atm)!.withValues(alpha: atm),
            Color.lerp(const Color(0xFF02142E), const Color(0xFF8CC8F0), atm)!.withValues(alpha: atm),
          ],
        ).createShader(rect),
    );
  }

  void _label(Canvas canvas, Offset at, String text, Color color, {double size = 11}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, shadows: const [Shadow(blurRadius: 4)])),
      textDirection: w.arabic ? TextDirection.rtl : TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, 0));
  }

  void _drawPlanets(Canvas canvas, Size size) {
    if (w.km < 55000 || w.phase == JourneyPhase.arrival || w.phase == JourneyPhase.won) return;
    final fade = _smooth(55000, 70000, w.km);
    final labels = _clamp01(1 - (w.km - 90000) / 40000);
    final planets = [
      (const V3(-.62, .32, 1), const Color(0xFFFFF4D6), 3.2, w.tr('الزهرة', 'Venus')),
      (const V3(-.28, .52, 1), const Color(0xFFFF9E6B), 2.2, w.tr('المريخ', 'Mars')),
      (const V3(.66, .5, 1), const Color(0xFFFFE6B8), 2.8, w.tr('المشتري', 'Jupiter')),
    ];
    for (final (d, c, r, name) in planets) {
      final o = sky.projectDir(d.normalized);
      if (o == null) continue;
      canvas.drawCircle(o, r * 3, Paint()..color = c.withValues(alpha: .18 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(o, r, Paint()..color = c.withValues(alpha: fade));
      if (labels > 0) _label(canvas, o + const Offset(0, 8), name, Colors.white.withValues(alpha: .8 * labels * fade));
    }
  }

  void _drawComet(Canvas canvas, Size size) {
    if (w.km < 100000 || w.km > 200000) return;
    final fade = _smooth(100000, 110000, w.km) * (1 - _smooth(185000, 200000, w.km));
    final head = const V3(-.7, .55, 1).normalized;
    final o = sky.projectDir(head);
    final t = sky.projectDir((head - kSunDir * .12).normalized);
    if (o == null || t == null) return;
    final tail = t - o;
    final dir = tail / tail.distance;
    final len = math.min(size.width * .45, tail.distance * 4);
    final end = o + dir * len;
    final normal = Offset(-dir.dy, dir.dx);
    final path = Path()
      ..moveTo(o.dx + normal.dx * 2, o.dy + normal.dy * 2)
      ..lineTo(end.dx + normal.dx * len * .16, end.dy + normal.dy * len * .16)
      ..lineTo(end.dx - normal.dx * len * .1, end.dy - normal.dy * len * .1)
      ..lineTo(o.dx - normal.dx * 2, o.dy - normal.dy * 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(colors: [
          const Color(0xFFCDEBFF).withValues(alpha: .75 * fade),
          const Color(0xFF7FB2FF).withValues(alpha: 0),
        ]).createShader(Rect.fromPoints(o, end))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(o, 6, Paint()..color = const Color(0xFFE8F6FF).withValues(alpha: .5 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(o, 2.4, Paint()..color = Colors.white.withValues(alpha: fade));
    _label(canvas, o + const Offset(0, 10), w.tr('مذنّب', 'Comet'), Colors.white.withValues(alpha: .8 * fade));
  }

  // --- الأرض والقمر ----------------------------------------------------------

  bool _inView(Camera c, V3 dir, double alpha) {
    final cd = c.rot.apply(dir);
    final angle = math.acos(cd.z.clamp(-1.0, 1.0));
    return angle - alpha < 1.2;
  }

  void _drawEarth(Canvas canvas, Size size, Camera c, SkyState st, {bool rear = false}) {
    if (!_inView(c, st.earthDir, st.earthAlpha)) return;
    const d = 1000.0;
    final r = d * math.sin(st.earthAlpha);
    final center = st.earthDir * d;
    final orient = scene.earthOrient(w, st.earthDir);
    final rings = rear ? 10 : (st.earthAlpha > .6 ? 34 : 24), segs = rear ? 40 : 72;
    final small = c.focal * math.tan(st.earthAlpha) < 70;
    // هالة الغلاف الجوي الأزرق حول حافة الأرض
    for (final (k, op) in [(1.035, .14), (1.014, .3)]) {
      drawCap(canvas, c,
          center: center,
          radius: r * k,
          orient: orient,
          light: kSunDir,
          rings: 3,
          segs: segs,
          style: SphereStyle(fallback: const Color(0xFF5FA8FF), blend: BlendMode.plus, opacity: op, ambient: 0));
    }
    drawCap(canvas, c,
        center: center,
        radius: r,
        orient: orient,
        light: kSunDir,
        rings: rings,
        segs: segs,
        style: SphereStyle(texture: small ? art.earthSmall : art.earth, fallback: const Color(0xFF2F6DB5), ambient: .035, gain: 1.7));
    if (art.clouds != null) {
      drawCap(canvas, c,
          center: center,
          radius: r * (1 + 4 / kEarthRadiusKm),
          orient: orient * M3.rotY(w.clock * .004),
          light: kSunDir,
          rings: rings,
          segs: segs,
          style: SphereStyle(
              texture: small ? art.cloudsSmall : art.clouds, fallback: Colors.white, blend: BlendMode.screen, ambient: 0, opacity: .95, gain: 1.5));
    }
    // تشتت الضوء في الغلاف الجوي يعطي الأرض لونها الأزرق المضيء
    drawCap(canvas, c,
        center: center,
        radius: r * (1 + 6 / kEarthRadiusKm),
        orient: orient,
        light: kSunDir,
        rings: rings,
        segs: segs,
        style: SphereStyle(fallback: const Color(0xFF8CC0F5), opacity: .22, ambient: 0, gain: 1.3));
  }

  void _drawMoon(Canvas canvas, Camera c, SkyState st) {
    if (!_inView(c, st.moonDir, st.moonAlpha)) return;
    const d = 1000.0;
    final r = d * math.sin(st.moonAlpha);
    final center = st.moonDir * d;
    if (st.moonAlpha < .006) {
      // بعيد جداً: نقطة لامعة
      final o = c.projectDir(st.moonDir);
      if (o != null) canvas.drawCircle(o, 2.5, Paint()..color = const Color(0xFFE8E4DA));
    } else {
      drawCap(canvas, c,
          center: center,
          radius: r,
          rings: st.moonAlpha > .05 ? (st.moonAlpha > .6 ? 34 : 24) : 10,
          segs: st.moonAlpha > .05 ? 72 : 36,
          orient: scene.moonOrient(st.moonDir),
          light: kSunDir,
          style: SphereStyle(
              texture: c.focal * math.tan(st.moonAlpha) < 70 ? art.moonSmall : art.moon,
              fallback: const Color(0xFFB8B4AC),
              ambient: .02,
              gain: 1.25));
    }
    if (w.phase == JourneyPhase.flying && st.moonAlpha < .08) {
      final o = c.projectDir(st.moonDir);
      if (o != null) {
        final rr = c.focal * math.tan(st.moonAlpha);
        _label(canvas, o + Offset(0, rr + 6), '${w.tr('القمر', 'Moon')} • ${formatInt(st.moonDistKm)} ${w.tr('كم', 'km')}',
            Colors.white70);
      }
    }
  }

  void _drawHaze(Canvas canvas, Size size, double atm) {
    if (atm <= 0.02 || w.km > 300) return;
    final dip = math.acos(kEarthRadiusKm / (kEarthRadiusKm + w.km));
    final h = sky.projectDir(V3(0, -math.sin(dip), math.cos(dip)));
    if (h == null) return;
    final band = size.height * .22;
    final rect = Rect.fromLTRB(0, h.dy - band, size.width, h.dy + band * .5);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFBFE3FF).withValues(alpha: 0),
            const Color(0xFFD9EEFF).withValues(alpha: .7 * atm),
            const Color(0xFFBFE3FF).withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  void _drawPuffs(Canvas canvas) {
    for (final p in w.puffs) {
      final o = cam.project(p.pos);
      if (o == null) continue;
      final z = cam.depth(p.pos);
      final r = cam.focal * p.size / z;
      if (r < 2 || r > w.size.width * .9) continue;
      final a = _clamp01((z - 3) / 22) * _clamp01((120 - z) / 40) * .55;
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: a), Colors.white.withValues(alpha: a * .5), Colors.white.withValues(alpha: 0)],
            stops: const [0, .45, 1],
          ).createShader(Rect.fromCircle(center: o, radius: r)),
      );
    }
  }

  void _drawDust(Canvas canvas) {
    if (w.km < 90) return;
    final v = w.approachSpeed;
    if (v <= 0) return;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .55 * _smooth(90, 200, w.km));
    for (final d in w.dust) {
      final a = cam.project(d);
      final b = cam.project(d + V3(0, 0, v * .045));
      if (a == null || b == null) continue;
      final z = cam.depth(d);
      paint.strokeWidth = (cam.focal * .05 / z).clamp(.6, 2.5);
      canvas.drawLine(a, b, paint);
    }
  }

  // --- الأجسام ثلاثية الأبعاد -------------------------------------------------

  void _drawObjects(Canvas canvas) {
    final b = scene.batch..clear();
    final light = kSunDir;
    for (final s in w.scenery) {
      final mesh = switch (s.kind) {
        'iss' => scene.iss,
        'gps' => scene.gps,
        'geo' => scene.geo,
        'srbL' => scene.srbL,
        'srbR' => scene.srbR,
        _ => scene.core,
      };
      final rot = M3.axisAngle(s.axis, s.angle);
      b.add(cam, mesh, at: s.pos, rot: rot, light: light, ambient: .25);
    }
    for (final r in w.rocks) {
      if (r.kind == 3) continue;
      final dist = r.pos.z;
      final fade = _clamp01((160 - dist) / 30);
      b.add(cam, scene.asteroids[r.mesh], at: r.pos, rot: r.rot, scale: r.radius, light: light, ambient: .1, opacity: fade, flash: r.hitFlash * .7);
    }
    final blink = w.invulnerable > 0 && (w.clock * 12).floor().isOdd;
    if (w.phase != JourneyPhase.lost && !blink) {
      final probeRot = w.probeRot;
      final p = w.probePos;
      b.add(cam, scene.orion(w.deploy), at: p, rot: probeRot, light: light, ambient: .3);
      if (w.coreAttached) b.add(cam, scene.core, at: p, rot: probeRot, light: light, ambient: .3);
      if (w.srbAttached) {
        b.add(cam, scene.srbL, at: p, rot: probeRot, light: light, ambient: .3);
        b.add(cam, scene.srbR, at: p, rot: probeRot, light: light, ambient: .3);
      }
    }
    b.draw(canvas);
  }

  void _glow(Canvas canvas, Offset o, double r, Color c, double alpha) {
    if (r <= .5 || alpha <= 0) return;
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: [
          c.withValues(alpha: alpha),
          c.withValues(alpha: alpha * .35),
          c.withValues(alpha: 0),
        ], stops: const [0, .35, 1])
            .createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  void _drawEffects(Canvas canvas) {
    // نار المحركات
    if (w.phase != JourneyPhase.lost && w.phase != JourneyPhase.countdown) {
      final p = w.probePos;
      final rot = w.probeRot;
      if (w.coreAttached) {
        final nozzle = p + rot.apply(const V3(0, 0, -8.1));
        final o = cam.project(nozzle);
        if (o != null) {
          final z = cam.depth(nozzle);
          final s = cam.focal / z;
          final flick = .85 + math.sin(w.clock * 47) * .1;
          final vac = _smooth(30, 120, w.km); // العادم يتمدد في الفراغ
          _glow(canvas, o, s * (1.2 + vac) * flick, const Color(0xFFFFF1C8), .85);
          _glow(canvas, o, s * (2.6 + vac * 2) * flick, const Color(0xFFFF9A3C), .5 - vac * .2);
          if (w.srbAttached) {
            for (final sx in [-1.0, 1.0]) {
              final q = cam.project(p + rot.apply(V3(sx, 0, -8.2)));
              if (q != null) _glow(canvas, q, s * 1.8 * flick, const Color(0xFFFFF0C8), .9);
            }
          }
        }
      } else {
        final at = p + rot.apply(const V3(0, 0, -1.25));
        final o = cam.project(at);
        if (o != null) {
          final s = cam.focal / cam.depth(at);
          final burn = w.engineBurn;
          _glow(canvas, o, s * (.2 + burn * 1.1), const Color(0xFFBFD8FF), .2 + burn * .6);
        }
      }
    }
    // الشهب المتوهجة
    for (final r in w.rocks) {
      if (r.kind != 3) continue;
      final o = cam.project(r.pos);
      if (o == null) continue;
      final s = cam.focal / cam.depth(r.pos);
      final tailEnd = cam.project(r.pos - r.vel * .06);
      if (tailEnd != null) {
        canvas.drawLine(
          o,
          tailEnd,
          Paint()
            ..strokeWidth = math.max(1.5, s * .5)
            ..strokeCap = StrokeCap.round
            ..shader = LinearGradient(colors: [const Color(0xFFFFF0C0), const Color(0x00FF7A2A)]).createShader(Rect.fromPoints(o, tailEnd)),
        );
      }
      _glow(canvas, o, s * 1.6, const Color(0xFFFFC46B), .9);
    }
    // أشعة الليزر
    final core = Paint()
      ..color = const Color(0xFFE6FDFF)
      ..strokeCap = StrokeCap.round;
    final halo = Paint()
      ..color = const Color(0xFF29D3FF).withValues(alpha: .45)
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    for (final s in w.lasers) {
      final a = cam.project(s.pos);
      final b = cam.project(s.pos - s.vel * .03);
      if (a == null || b == null) continue;
      final k = cam.focal / cam.depth(s.pos);
      halo.strokeWidth = math.max(2, k * .35);
      core.strokeWidth = math.max(1, k * .12);
      canvas.drawLine(a, b, halo);
      canvas.drawLine(a, b, core);
    }
    // الجسيمات
    final pp = Paint();
    for (final p in w.particles) {
      final o = cam.project(p.pos);
      if (o == null) continue;
      final z = cam.depth(p.pos);
      final r = cam.focal * p.size / z;
      final a = _clamp01(p.life / p.maxLife);
      if (p.glow) {
        _glow(canvas, o, r * 2, p.color, a);
      } else {
        pp
          ..blendMode = BlendMode.srcOver
          ..color = p.color.withValues(alpha: a * .6);
        canvas.drawCircle(o, r, pp);
      }
    }
  }

  // --- الكاميرا الخلفية ------------------------------------------------------

  void _drawRearView(Canvas canvas, Size size, SkyState st) {
    if (w.phase != JourneyPhase.flying || w.km < 3000) return;
    const side = 118.0;
    final rect = Rect.fromLTWH(12, size.height - side - 30 - bottomPad, side, side);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(rect, Paint()..color = Colors.black);
    final rc = Camera();
    rc.setViewport(rect.size, hfovDeg: (st.earthAlpha * 180 / math.pi * 6).clamp(3.0, 40.0));
    rc.cx += rect.left;
    rc.cy += rect.top;
    rc.lookAt(V3.zero, st.earthDir);
    _drawSkybox(canvas, rc, 1);
    _drawEarth(canvas, size, rc, st, rear: true);
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.lightBlueAccent.withValues(alpha: .6),
    );
    _label(canvas, Offset(rect.center.dx, rect.top - 30), w.tr('الكاميرا الخلفية: الأرض', 'Rear camera: Earth'), Colors.white70, size: 10);
    _label(canvas, Offset(rect.center.dx, rect.top - 16), '${formatInt(st.earthDistKm - kEarthRadiusKm)} ${w.tr('كم', 'km')}',
        Colors.lightBlueAccent, size: 10);
  }

  @override
  bool shouldRepaint(covariant JourneyPainter old) => old.w != w || old.art != art;
}
