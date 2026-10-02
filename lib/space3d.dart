import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

// محرك ثلاثي الأبعاد صغير مبني على Canvas.drawVertices:
// إسقاط منظوري، شبكات مضلعات بإضاءة من الشمس، وكرات مُكساة بخرائط
// حقيقية (الأرض والقمر ودرب التبانة).
//
// إحداثيات العالم: x يمين، y أعلى، z للأمام (نحو القمر).

class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);
  static const zero = V3(0, 0, 0);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  V3 operator -() => V3(-x, -y, -z);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l == 0 ? this : V3(x / l, y / l, z / l);
  }

  static V3 lerp(V3 a, V3 b, double t) => a + (b - a) * t;

  @override
  String toString() => 'V3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// مصفوفة دوران 3×3 (صفوف).
class M3 {
  final double a, b, c, d, e, f, g, h, i;
  const M3(this.a, this.b, this.c, this.d, this.e, this.f, this.g, this.h, this.i);
  static const identity = M3(1, 0, 0, 0, 1, 0, 0, 0, 1);

  V3 apply(V3 v) => V3(
        a * v.x + b * v.y + c * v.z,
        d * v.x + e * v.y + f * v.z,
        g * v.x + h * v.y + i * v.z,
      );

  M3 operator *(M3 o) => M3(
        a * o.a + b * o.d + c * o.g, a * o.b + b * o.e + c * o.h, a * o.c + b * o.f + c * o.i,
        d * o.a + e * o.d + f * o.g, d * o.b + e * o.e + f * o.h, d * o.c + e * o.f + f * o.i,
        g * o.a + h * o.d + i * o.g, g * o.b + h * o.e + i * o.h, g * o.c + h * o.f + i * o.i,
      );

  M3 get transposed => M3(a, d, g, b, e, h, c, f, i);

  static M3 rotX(double t) {
    final c = math.cos(t), s = math.sin(t);
    return M3(1, 0, 0, 0, c, -s, 0, s, c);
  }

  static M3 rotY(double t) {
    final c = math.cos(t), s = math.sin(t);
    return M3(c, 0, s, 0, 1, 0, -s, 0, c);
  }

  static M3 rotZ(double t) {
    final c = math.cos(t), s = math.sin(t);
    return M3(c, -s, 0, s, c, 0, 0, 0, 1);
  }

  /// دوران حول محور اعتباطي (صيغة رودريغز).
  static M3 axisAngle(V3 axis, double t) {
    final k = axis.normalized;
    final c = math.cos(t), s = math.sin(t), v = 1 - c;
    return M3(
      c + k.x * k.x * v, k.x * k.y * v - k.z * s, k.x * k.z * v + k.y * s,
      k.y * k.x * v + k.z * s, c + k.y * k.y * v, k.y * k.z * v - k.x * s,
      k.z * k.x * v - k.y * s, k.z * k.y * v + k.x * s, c + k.z * k.z * v,
    );
  }

  /// الأعمدة هي المحاور الثلاثة.
  static M3 fromColumns(V3 x, V3 y, V3 z) => M3(x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z);

  /// دوران يأخذ الاتجاه المحلي [a1] إلى [b1]، والاتجاه [a2] (تقريباً) إلى [b2].
  static M3 align(V3 a1, V3 a2, V3 b1, V3 b2) {
    M3 frame(V3 p, V3 q) {
      final x = p.normalized;
      final y = (q - x * q.dot(x)).normalized;
      return fromColumns(x, y, x.cross(y));
    }

    return frame(b1, b2) * frame(a1, a2).transposed;
  }
}

/// كاميرا منظورية. فضاء الكاميرا: x يمين، y أعلى، z للأمام.
class Camera {
  V3 pos;
  M3 rot; // من العالم إلى الكاميرا
  double focal;
  double cx, cy;
  static const double near = 0.05;

  Camera({this.pos = V3.zero, this.rot = M3.identity, this.focal = 500, this.cx = 0, this.cy = 0});

  /// تضبط الكاميرا لتنظر من [eye] نحو [target] مع ميلان [roll].
  void lookAt(V3 eye, V3 target, {double roll = 0}) {
    pos = eye;
    final f = (target - eye).normalized;
    var r = const V3(0, 1, 0).cross(f).normalized;
    if (r.length < 1e-6) r = const V3(1, 0, 0);
    final u = f.cross(r);
    final cr = math.cos(roll), sr = math.sin(roll);
    final r2 = r * cr + u * sr;
    final u2 = u * cr - r * sr;
    rot = M3(r2.x, r2.y, r2.z, u2.x, u2.y, u2.z, f.x, f.y, f.z);
  }

  void setViewport(Size s, {double hfovDeg = 68}) {
    cx = s.width / 2;
    cy = s.height / 2;
    focal = (s.width / 2) / math.tan(hfovDeg * math.pi / 360);
  }

  V3 toCam(V3 p) => rot.apply(p - pos);

  /// إسقاط نقطة: يعيد null إذا كانت خلف الكاميرا.
  Offset? project(V3 p) {
    final c = toCam(p);
    if (c.z < near) return null;
    return Offset(cx + focal * c.x / c.z, cy - focal * c.y / c.z);
  }

  /// إسقاط اتجاه (جرم بعيد جداً): الدوران فقط.
  Offset? projectDir(V3 d) {
    final c = rot.apply(d);
    if (c.z < 1e-3) return null;
    return Offset(cx + focal * c.x / c.z, cy - focal * c.y / c.z);
  }

  double depth(V3 p) => toCam(p).z;
}

/// شبكة مضلعات بإضاءة مسطحة (لون لكل مثلث).
class Mesh {
  final List<V3> verts;
  final List<int> tris; // ثلاثيات من الفهارس، المتجه الطبيعي = (b-a)×(c-a) للخارج
  final List<Color> colors; // لون لكل مثلث
  final List<bool> twoSided;
  final List<double> emissive;

  Mesh(this.verts, this.tris, this.colors, this.twoSided, this.emissive);

  int get triCount => tris.length ~/ 3;
}

class MeshBuilder {
  final List<V3> verts = [];
  final List<int> tris = [];
  final List<Color> colors = [];
  final List<bool> twoSided = [];
  final List<double> emissive = [];

  int v(V3 p) {
    verts.add(p);
    return verts.length - 1;
  }

  /// يضيف مثلثاً، ويقلب ترتيبه إذا كان متجهه يشير نحو [inside].
  void tri(int a, int b, int c, Color color, {V3? inside, bool twoSide = false, double glow = 0}) {
    if (inside != null) {
      final pa = verts[a], pb = verts[b], pc = verts[c];
      final n = (pb - pa).cross(pc - pa);
      final centroid = (pa + pb + pc) * (1 / 3);
      if (n.dot(centroid - inside) < 0) {
        final t = b;
        b = c;
        c = t;
      }
    }
    tris..add(a)..add(b)..add(c);
    colors.add(color);
    twoSided.add(twoSide);
    emissive.add(glow);
  }

  void quad(int a, int b, int c, int d, Color color, {V3? inside, bool twoSide = false, double glow = 0}) {
    tri(a, b, c, color, inside: inside, twoSide: twoSide, glow: glow);
    tri(a, c, d, color, inside: inside, twoSide: twoSide, glow: glow);
  }

  /// مخروط مقطوع على محور z من [z0] إلى [z1].
  void frustum(double z0, double r0, double z1, double r1, int seg, Color color,
      {bool cap0 = false, bool cap1 = false, Color? capColor, double cx = 0, double cy = 0, double glow = 0}) {
    final inside = V3(cx, cy, (z0 + z1) / 2);
    final ring0 = <int>[], ring1 = <int>[];
    for (int i = 0; i < seg; i++) {
      final a = i / seg * math.pi * 2;
      ring0.add(v(V3(cx + math.cos(a) * r0, cy + math.sin(a) * r0, z0)));
      ring1.add(v(V3(cx + math.cos(a) * r1, cy + math.sin(a) * r1, z1)));
    }
    for (int i = 0; i < seg; i++) {
      final j = (i + 1) % seg;
      // تظليل خفيف متناوب يعطي إحساساً بالألواح
      final shade = i.isEven ? color : Color.lerp(color, const Color(0xFF000000), .06)!;
      quad(ring0[i], ring0[j], ring1[j], ring1[i], shade, inside: inside, glow: glow);
    }
    if (cap0 && r0 > 0) {
      final c = v(V3(cx, cy, z0));
      for (int i = 0; i < seg; i++) {
        tri(c, ring0[i], ring0[(i + 1) % seg], capColor ?? color, inside: V3(cx, cy, z0 + 1));
      }
    }
    if (cap1 && r1 > 0) {
      final c = v(V3(cx, cy, z1));
      for (int i = 0; i < seg; i++) {
        tri(c, ring1[i], ring1[(i + 1) % seg], capColor ?? color, inside: V3(cx, cy, z1 - 1), glow: glow);
      }
    }
  }

  /// صندوق محوري.
  void box(V3 min, V3 max, Color color, {double glow = 0}) {
    final c = (min + max) * .5;
    final p = [
      for (final z in [min.z, max.z])
        for (final y in [min.y, max.y])
          for (final x in [min.x, max.x]) v(V3(x, y, z))
    ];
    // 0:(-,-,-) 1:(+,-,-) 2:(-,+,-) 3:(+,+,-) 4..7 نفسها بـ z+
    quad(p[0], p[1], p[3], p[2], color, inside: c, glow: glow);
    quad(p[4], p[5], p[7], p[6], color, inside: c, glow: glow);
    quad(p[0], p[1], p[5], p[4], color, inside: c, glow: glow);
    quad(p[2], p[3], p[7], p[6], color, inside: c, glow: glow);
    quad(p[0], p[2], p[6], p[4], color, inside: c, glow: glow);
    quad(p[1], p[3], p[7], p[5], color, inside: c, glow: glow);
  }

  /// لوح رقيق مرئي من الجهتين (لوح شمسي مثلاً).
  void panel(V3 origin, V3 along, V3 across, Color color, {int cells = 1, Color? gridColor}) {
    for (int k = 0; k < cells; k++) {
      final o = origin + along * (k / cells);
      final a = along * (1 / cells * .94);
      final p0 = v(o), p1 = v(o + a), p2 = v(o + a + across), p3 = v(o + across);
      final col = (gridColor != null && k.isOdd) ? gridColor : color;
      quad(p0, p1, p2, p3, col, twoSide: true);
    }
  }

  Mesh build() => Mesh(List.of(verts), List.of(tris), List.of(colors), List.of(twoSided), List.of(emissive));
}

/// كويكب: كرة مشوهة بضجيج ثابت (لكل بذرة شكل مختلف).
Mesh buildAsteroid(int seed, {int detail = 1, Color base = const Color(0xFF8A8178)}) {
  final rnd = math.Random(seed);
  // تبدأ بعشريني الوجوه ثم نقسمه
  final t = (1 + math.sqrt(5)) / 2;
  var verts = <V3>[
    V3(-1, t, 0), V3(1, t, 0), V3(-1, -t, 0), V3(1, -t, 0),
    V3(0, -1, t), V3(0, 1, t), V3(0, -1, -t), V3(0, 1, -t),
    V3(t, 0, -1), V3(t, 0, 1), V3(-t, 0, -1), V3(-t, 0, 1),
  ].map((v) => v.normalized).toList();
  var faces = <List<int>>[
    [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
    [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
    [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
    [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
  ];
  for (int d = 0; d < detail; d++) {
    final cache = <int, int>{};
    int mid(int a, int b) {
      final key = a < b ? a * 100000 + b : b * 100000 + a;
      return cache.putIfAbsent(key, () {
        verts.add(((verts[a] + verts[b]) * .5).normalized);
        return verts.length - 1;
      });
    }

    final nf = <List<int>>[];
    for (final f in faces) {
      final a = mid(f[0], f[1]), b = mid(f[1], f[2]), c = mid(f[2], f[0]);
      nf..add([f[0], a, c])..add([f[1], b, a])..add([f[2], c, b])..add([a, b, c]);
    }
    faces = nf;
  }
  // تشويه: بضع "حفر" ونتوءات + تمدد عشوائي على المحاور
  final bumps = List.generate(7, (_) => (V3(rnd.nextDouble() - .5, rnd.nextDouble() - .5, rnd.nextDouble() - .5).normalized, .12 + rnd.nextDouble() * .25, rnd.nextBool() ? -1.0 : 1.0));
  final stretch = V3(.75 + rnd.nextDouble() * .5, .7 + rnd.nextDouble() * .4, .8 + rnd.nextDouble() * .5);
  verts = verts.map((p) {
    var r = 1.0;
    for (final (dir, size, sign) in bumps) {
      final d = 1 - p.dot(dir);
      if (d < size) r += sign * (size - d) * .55;
    }
    r += (rnd.nextDouble() - .5) * .12;
    return V3(p.x * r * stretch.x, p.y * r * stretch.y, p.z * r * stretch.z);
  }).toList();
  final b = MeshBuilder();
  for (final p in verts) {
    b.v(p);
  }
  for (final f in faces) {
    final k = rnd.nextDouble();
    final col = Color.lerp(base, k < .5 ? const Color(0xFF5E554D) : const Color(0xFFA59A8C), (k - .5).abs() * 1.4)!;
    b.tri(f[0], f[1], f[2], col, inside: V3.zero);
  }
  return b.build();
}

/// مركبة أوريون (ناسا): كبسولة الطاقم + وحدة الخدمة الأوروبية + 4 ألواح شمسية.
/// الأنف نحو +z. [deploy] من 0 (مطوية) إلى 1 (مفتوحة).
Mesh buildOrion({double deploy = 1}) {
  final b = MeshBuilder();
  const white = Color(0xFFE6E9EE);
  const silver = Color(0xFFB9BEC6);
  const tiles = Color(0xFFCDD2D9);
  const gold = Color(0xFFC9A23A);
  const dark = Color(0xFF3A3D42);
  // درع الحرارة
  b.frustum(.28, .02, .30, .58, 20, const Color(0xFF6B4B32), cap0: true);
  // كبسولة الطاقم (مخروط مقطوع)
  b.frustum(.30, .58, 1.12, .24, 20, tiles);
  // نوافذ
  for (final a in [.35, .9, 2.25, 2.8]) {
    final c = V3(math.cos(a) * .47, math.sin(a) * .47, .5);
    b.box(c - const V3(.05, .05, .03), c + const V3(.05, .05, .03), const Color(0xFF1B2433));
  }
  // آلية الالتحام في الأنف
  b.frustum(1.12, .2, 1.32, .17, 14, silver, cap1: true, capColor: dark);
  // وحدة الخدمة الأوروبية
  b.frustum(-.78, .52, .28, .52, 20, white, cap0: true, capColor: silver);
  b.frustum(-.30, .535, .02, .535, 20, gold); // عازل حراري ذهبي
  b.frustum(-.78, .54, -.66, .54, 20, silver);
  // المحرك الرئيسي
  b.frustum(-.78, .2, -1.18, .34, 16, dark);
  b.frustum(-1.16, .30, -1.18, .02, 16, const Color(0xFFFF9A3C), glow: 1); // فوهة متوهجة
  // محركات صغيرة حول القاعدة
  for (int k = 0; k < 4; k++) {
    final a = k * math.pi / 2 + math.pi / 4;
    b.frustum(-.86, .05, -.78, .05, 6, dark, cx: math.cos(a) * .35, cy: math.sin(a) * .35);
  }
  // الألواح الشمسية بترتيب X
  const cell = Color(0xFF1F3A78);
  const cell2 = Color(0xFF2A4B93);
  for (int k = 0; k < 4; k++) {
    final a = math.pi / 4 + k * math.pi / 2;
    final radial = V3(math.cos(a), math.sin(a), 0);
    final tangent = V3(-math.sin(a), math.cos(a), 0);
    final root = radial * .54 + const V3(0, 0, -.45);
    final dir = V3.lerp(const V3(0, 0, -1), radial, deploy).normalized;
    // ذراع
    final boomEnd = root + dir * .22;
    b.box(
      V3(math.min(root.x, boomEnd.x) - .02, math.min(root.y, boomEnd.y) - .02, math.min(root.z, boomEnd.z) - .02),
      V3(math.max(root.x, boomEnd.x) + .02, math.max(root.y, boomEnd.y) + .02, math.max(root.z, boomEnd.z) + .02),
      silver,
    );
    final width = tangent * .42;
    b.panel(boomEnd - width * .5, dir * 1.9, width, cell, cells: 3, gridColor: cell2);
  }
  return b.build();
}

/// صاروخ SLS: المرحلة الأساسية البرتقالية مع معززين أبيضين.
Mesh buildSlsCore() {
  final b = MeshBuilder();
  const orange = Color(0xFFD9772B);
  b.frustum(-7.2, .62, -.78, .62, 18, orange, cap1: true, capColor: const Color(0xFF8A5A2B));
  b.frustum(-7.25, .6, -7.2, .62, 18, const Color(0xFF3A3D42), cap0: true);
  // 4 محركات RS-25
  for (int k = 0; k < 4; k++) {
    final a = k * math.pi / 2 + math.pi / 4;
    b.frustum(-7.25, .12, -7.7, .2, 8, const Color(0xFF2B2D31), cx: math.cos(a) * .3, cy: math.sin(a) * .3);
  }
  return b.build();
}

Mesh buildBooster(double side) {
  final b = MeshBuilder();
  const white = Color(0xFFEDEDED);
  final x = side * 1.0;
  b.frustum(-7.4, .3, -2.0, .3, 14, white, cx: x);
  b.frustum(-2.0, .3, -1.3, .05, 14, white, cx: x);
  b.frustum(-6.2, .31, -5.9, .31, 14, const Color(0xFF2B2D31), cx: x);
  b.frustum(-7.4, .22, -7.8, .3, 10, const Color(0xFF2B2D31), cx: x);
  return b.build();
}

/// محطة الفضاء الدولية (مبسطة): الجملون الطويل وأجنحة الألواح الشمسية والوحدات.
Mesh buildIss() {
  final b = MeshBuilder();
  const truss = Color(0xFFB8BCC2);
  const module = Color(0xFFE2E4E8);
  const panel = Color(0xFF7A5A2A); // ألواح المحطة لونها نحاسي ذهبي
  const panel2 = Color(0xFF8E6A33);
  b.box(const V3(-5.5, -.12, -.12), const V3(5.5, .12, .12), truss);
  b.frustum(-2.4, .32, 2.4, .32, 12, module, cap0: true, cap1: true, cy: -.5);
  b.frustum(-.6, .3, .6, .3, 12, module, cap0: true, cap1: true, cx: 0, cy: -.5);
  b.box(const V3(-1.6, -.85, -.3), const V3(1.6, -.25, .3), module);
  for (final x in [-4.6, -3.4, 3.4, 4.6]) {
    b.panel(V3(x - .45, .15, -3.6), const V3(0, 0, 3.4), const V3(.9, 0, 0), panel, cells: 4, gridColor: panel2);
    b.panel(V3(x - .45, .15, .2), const V3(0, 0, 3.4), const V3(.9, 0, 0), panel, cells: 4, gridColor: panel2);
  }
  // مشعات بيضاء
  b.panel(const V3(-1.6, -.1, .4), const V3(0, 0, 1.6), const V3(-.9, 0, 0), const Color(0xFFF2F2F2), cells: 2);
  b.panel(const V3(1.6, -.1, .4), const V3(0, 0, 1.6), const V3(.9, 0, 0), const Color(0xFFF2F2F2), cells: 2);
  return b.build();
}

/// قمر صناعي (GPS أو اتصالات): جسم صندوقي ذهبي مع لوحين.
Mesh buildSatellite({Color body = const Color(0xFFC9A23A)}) {
  final b = MeshBuilder();
  b.box(const V3(-.5, -.5, -.6), const V3(.5, .5, .6), body);
  b.frustum(.6, .05, .9, .45, 12, const Color(0xFFE8E8E8), cap1: true);
  for (final s in [-1.0, 1.0]) {
    b.box(V3(s * .5, -.04, -.04), V3(s * .9, .04, .04), const Color(0xFF9EA3AA));
    b.panel(V3(s * .9, -.6, -.5), V3(s * 2.6, 0, 0), const V3(0, 1.2, 0), const Color(0xFF1F3A78), cells: 3, gridColor: const Color(0xFF2A4B93));
  }
  return b.build();
}

// ---------------------------------------------------------------------------
// الرسم
// ---------------------------------------------------------------------------

Color _shade(Color c, double k) {
  k = k.clamp(0.0, 1.6);
  int ch(double v) => (v * k).round().clamp(0, 255);
  return Color.fromARGB(255, ch(c.r * 255), ch(c.g * 255), ch(c.b * 255));
}

/// يجمع مثلثات عدة أجسام في دفعة واحدة مرتبة من البعيد إلى القريب.
class TriBatch {
  final List<double> _depth = [];
  final List<double> _pos = [];
  final List<int> _col = [];

  void clear() {
    _depth.clear();
    _pos.clear();
    _col.clear();
  }

  bool get isEmpty => _depth.isEmpty;

  /// يضيف [mesh] بعد تدويره بـ [rot] وتكبيره بـ [scale] ووضعه في [at].
  void add(Camera cam, Mesh mesh, {required V3 at, M3 rot = M3.identity, double scale = 1, required V3 light, double ambient = .22, double opacity = 1, Color? tint, double flash = 0}) {
    final n = mesh.verts.length;
    final wx = Float64List(n), wy = Float64List(n), wz = Float64List(n);
    final sx = Float64List(n), sy = Float64List(n), sz = Float64List(n);
    final cr = cam.rot;
    for (int k = 0; k < n; k++) {
      final p = mesh.verts[k];
      final w = rot.apply(p) * scale + at;
      wx[k] = w.x;
      wy[k] = w.y;
      wz[k] = w.z;
      final dx = w.x - cam.pos.x, dy = w.y - cam.pos.y, dz = w.z - cam.pos.z;
      final cz = cr.g * dx + cr.h * dy + cr.i * dz;
      sz[k] = cz;
      if (cz > Camera.near) {
        sx[k] = cam.cx + cam.focal * (cr.a * dx + cr.b * dy + cr.c * dz) / cz;
        sy[k] = cam.cy - cam.focal * (cr.d * dx + cr.e * dy + cr.f * dz) / cz;
      }
    }
    final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
    final t = mesh.tris;
    for (int f = 0; f < mesh.triCount; f++) {
      final a = t[f * 3], b = t[f * 3 + 1], c = t[f * 3 + 2];
      if (sz[a] <= Camera.near || sz[b] <= Camera.near || sz[c] <= Camera.near) continue;
      final e1x = wx[b] - wx[a], e1y = wy[b] - wy[a], e1z = wz[b] - wz[a];
      final e2x = wx[c] - wx[a], e2y = wy[c] - wy[a], e2z = wz[c] - wz[a];
      var nx = e1y * e2z - e1z * e2y, ny = e1z * e2x - e1x * e2z, nz = e1x * e2y - e1y * e2x;
      final vx = wx[a] - cam.pos.x, vy = wy[a] - cam.pos.y, vz = wz[a] - cam.pos.z;
      final facing = nx * vx + ny * vy + nz * vz;
      if (facing >= 0) {
        if (!mesh.twoSided[f]) continue;
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }
      final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (nl == 0) continue;
      final lambert = math.max(0.0, (nx * light.x + ny * light.y + nz * light.z) / nl);
      // لمعة معدنية بسيطة
      final glow = mesh.emissive[f];
      var k = glow > 0 ? 1.0 + glow * .3 : ambient + (1 - ambient) * lambert;
      var col = _shade(mesh.colors[f], k);
      if (tint != null) col = Color.lerp(col, tint, .35)!;
      if (flash > 0) col = Color.lerp(col, const Color(0xFFFFFFFF), flash.clamp(0.0, 1.0))!;
      final argb = (alpha << 24) | (col.toARGB32() & 0xFFFFFF);
      _depth.add((sz[a] + sz[b] + sz[c]) / 3);
      _pos..add(sx[a])..add(sy[a])..add(sx[b])..add(sy[b])..add(sx[c])..add(sy[c]);
      _col..add(argb)..add(argb)..add(argb);
    }
  }

  void draw(Canvas canvas) {
    final n = _depth.length;
    if (n == 0) return;
    final order = List<int>.generate(n, (i) => i)..sort((p, q) => _depth[q].compareTo(_depth[p]));
    final pos = Float32List(n * 6);
    final col = Int32List(n * 3);
    for (int k = 0; k < n; k++) {
      final o = order[k];
      for (int j = 0; j < 6; j++) {
        pos[k * 6 + j] = _pos[o * 6 + j];
      }
      col[k * 3] = _col[o * 3];
      col[k * 3 + 1] = _col[o * 3 + 1];
      col[k * 3 + 2] = _col[o * 3 + 2];
    }
    canvas.drawVertices(
      ui.Vertices.raw(ui.VertexMode.triangles, pos, colors: col),
      BlendMode.modulate,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    clear();
  }
}

/// كرة بإحداثيات خط طول/عرض لتطبيق خرائط equirectangular.
class UvSphere {
  final int lonSeg, latSeg;
  late final List<V3> dirs; // اتجاهات وحدة لكل رأس
  late final Float32List uv; // 0..1
  late final Uint16List indices;

  UvSphere(this.lonSeg, this.latSeg) {
    final d = <V3>[];
    final u = <double>[];
    for (int j = 0; j <= latSeg; j++) {
      final v = j / latSeg;
      for (int i = 0; i <= lonSeg; i++) {
        final uu = i / lonSeg;
        d.add(dirFromUv(uu, v));
        u..add(uu)..add(v);
      }
    }
    dirs = d;
    uv = Float32List.fromList(u);
    final idx = <int>[];
    final row = lonSeg + 1;
    for (int j = 0; j < latSeg; j++) {
      for (int i = 0; i < lonSeg; i++) {
        final a = j * row + i, b = a + 1, c = a + row, e = c + 1;
        idx..addAll([a, c, b])..addAll([b, c, e]);
      }
    }
    indices = Uint16List.fromList(idx);
  }

  /// u: خط الطول (0 = ‎-180°)، v: خط العرض (0 = القطب الشمالي).
  static V3 dirFromUv(double u, double v) {
    final lon = (u - .5) * math.pi * 2;
    final lat = (.5 - v) * math.pi;
    return V3(math.cos(lat) * math.sin(lon), math.sin(lat), -math.cos(lat) * math.cos(lon));
  }

  static V3 dirFromLatLon(double latDeg, double lonDeg) => dirFromUv((lonDeg + 180) / 360, .5 - latDeg / 180);
}

class SphereStyle {
  final ui.Image? texture;
  final Color fallback;
  final double ambient;
  final BlendMode blend;
  final double opacity;
  final bool lit;

  /// مضاعف السطوع (التعريض) — يجعل الكوكب يبدو كما في صور رواد الفضاء.
  final double gain;
  const SphereStyle(
      {this.texture, required this.fallback, this.ambient = .04, this.blend = BlendMode.srcOver, this.opacity = 1, this.lit = true, this.gain = 1});
}

/// يرسم كرة مُكساة. [center] و[radius] في إحداثيات العالم، [orient] يدوّر
/// الاتجاهات المحلية. إذا كان [inside] صحيحاً تُرسم من الداخل (سماء).
void drawSphere(Canvas canvas, Camera cam, UvSphere s, {required V3 center, required double radius, required M3 orient, required SphereStyle style, V3? light, bool inside = false}) {
  final n = s.dirs.length;
  final pos = Float32List(n * 2);
  final cols = Int32List(n);
  final camZ = Float64List(n);
  final nrm = List<V3>.filled(n, V3.zero);
  final tex = style.texture;
  final tw = tex?.width.toDouble() ?? 1, th = tex?.height.toDouble() ?? 1;
  final tc = Float32List(n * 2);
  final cr = cam.rot;
  final fb = style.fallback;
  final alpha = (style.opacity.clamp(0.0, 1.0) * 255).round();
  for (int k = 0; k < n; k++) {
    final d = orient.apply(s.dirs[k]);
    nrm[k] = d;
    final w = center + d * radius;
    final dx = w.x - cam.pos.x, dy = w.y - cam.pos.y, dz = w.z - cam.pos.z;
    final cz = cr.g * dx + cr.h * dy + cr.i * dz;
    camZ[k] = cz;
    final z = cz < 1e-4 ? 1e-4 : cz;
    pos[k * 2] = cam.cx + cam.focal * (cr.a * dx + cr.b * dy + cr.c * dz) / z;
    pos[k * 2 + 1] = cam.cy - cam.focal * (cr.d * dx + cr.e * dy + cr.f * dz) / z;
    tc[k * 2] = s.uv[k * 2] * tw;
    tc[k * 2 + 1] = s.uv[k * 2 + 1] * th;
    double l = 1;
    if (style.lit && light != null) {
      final dl = d.dot(light);
      // انتقال ناعم عند خط الفجر/الغسق
      l = style.ambient + (1 - style.ambient) * (dl * 1.15 + .08).clamp(0.0, 1.0);
    }
    if (tex != null) {
      final c = (l * 255).round().clamp(0, 255);
      cols[k] = (alpha << 24) | (c << 16) | (c << 8) | c;
    } else {
      int ch(double v) => (v * 255 * l).round().clamp(0, 255);
      cols[k] = (alpha << 24) | (ch(fb.r) << 16) | (ch(fb.g) << 8) | ch(fb.b);
    }
  }
  final idx = s.indices;
  final vis = <int>[];
  for (int t = 0; t < idx.length; t += 3) {
    final a = idx[t], b = idx[t + 1], c = idx[t + 2];
    if (camZ[a] < Camera.near || camZ[b] < Camera.near || camZ[c] < Camera.near) continue;
    if (!inside) {
      final mid = (nrm[a] + nrm[b] + nrm[c]);
      final w = center + mid.normalized * radius;
      if (mid.dot(w - cam.pos) >= 0) continue;
    }
    vis..add(a)..add(b)..add(c);
  }
  if (vis.isEmpty) return;
  final paint = Paint()..blendMode = style.blend;
  if (tex != null) {
    paint.shader = ImageShader(tex, TileMode.repeated, TileMode.clamp, Matrix4Identity.storage, filterQuality: FilterQuality.medium);
  } else {
    paint.color = const Color(0xFFFFFFFF);
  }
  canvas.drawVertices(
    ui.Vertices.raw(ui.VertexMode.triangles, pos, textureCoordinates: tex != null ? tc : null, colors: cols, indices: Uint16List.fromList(vis)),
    BlendMode.modulate,
    paint,
  );
}

class Matrix4Identity {
  static final Float64List storage = Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
}

/// زاوية (راديان) نصف القطر الظاهري لجرم نصف قطره [r] على بعد [d] من مركزه.
double angularRadius(double r, double d) => d <= r ? math.pi / 2 : math.asin(r / d);

/// يرسم الجزء المرئي فقط من كرة مُكساة (القبة المواجهة للكاميرا) مع قص
/// المثلثات عند مستوى الكاميرا القريب. يعطي حافة ناعمة للكوكب ولا فجوات
/// حتى عندما تكون الكاميرا قريبة جداً من السطح (الصعود من الأرض أو مدار القمر).
void drawCap(Canvas canvas, Camera cam,
    {required V3 center, required double radius, required M3 orient, required SphereStyle style, V3? light, int rings = 24, int segs = 72}) {
  final toCam = cam.pos - center;
  final dist = toCam.length;
  if (dist <= radius * 1.0000001) return;
  final theta = math.acos((radius / dist).clamp(-1.0, 1.0));
  final a = toCam * (1 / dist);
  final u0 = (a.y.abs() < .9 ? const V3(0, 1, 0) : const V3(1, 0, 0)).cross(a).normalized;
  final v0 = a.cross(u0);
  final inv = orient.transposed;
  final tex = style.texture;
  final tw = tex?.width.toDouble() ?? 1, th = tex?.height.toDouble() ?? 1;
  final alpha = style.opacity.clamp(0.0, 1.0);
  final cr = cam.rot;

  // رؤوس الحلقات: [x,y,z في فضاء الكاميرا، u، v، إضاءة]
  final nv = 1 + rings * segs;
  final vx = Float64List(nv), vy = Float64List(nv), vz = Float64List(nv);
  final tu = Float64List(nv), tv = Float64List(nv), lit = Float64List(nv);
  void put(int k, V3 dir) {
    final w = center + dir * radius;
    final dx = w.x - cam.pos.x, dy = w.y - cam.pos.y, dz = w.z - cam.pos.z;
    vx[k] = cr.a * dx + cr.b * dy + cr.c * dz;
    vy[k] = cr.d * dx + cr.e * dy + cr.f * dz;
    vz[k] = cr.g * dx + cr.h * dy + cr.i * dz;
    final l = inv.apply(dir);
    tu[k] = math.atan2(l.x, -l.z) / (2 * math.pi) + .5;
    tv[k] = .5 - math.asin(l.y.clamp(-1.0, 1.0)) / math.pi;
    double s = 1;
    if (style.lit && light != null) {
      s = style.ambient + (1 - style.ambient) * (dir.dot(light) * 1.15 + .08).clamp(0.0, 1.0);
    }
    lit[k] = (s * style.gain).clamp(0.0, 1.0);
  }

  put(0, a);
  for (int i = 1; i <= rings; i++) {
    final t = i / rings;
    // حلقات أكثف قرب الحافة؛ وأكثر انتظاماً عندما يكون السطح قريباً جداً
    final phi = theta * (1 - math.pow(1 - t, theta < .6 ? 1.35 : 2).toDouble());
    final cp = math.cos(phi), sp = math.sin(phi);
    for (int j = 0; j < segs; j++) {
      final b = j / segs * math.pi * 2;
      final dir = a * cp + (u0 * math.cos(b) + v0 * math.sin(b)) * sp;
      put(1 + (i - 1) * segs + j, dir);
    }
  }

  final pos = <double>[], tc = <double>[];
  final cols = <int>[];
  final fb = style.fallback;
  const near = Camera.near;

  // رأس مقصوص مؤقت
  final px = <double>[], py = <double>[], pz = <double>[], pu = <double>[], pv = <double>[], pl = <double>[];
  void emitPoly() {
    final n = px.length;
    if (n < 3) return;
    // إصلاح خط التاريخ في الخريطة
    var minU = pu[0], maxU = pu[0];
    for (final u in pu) {
      if (u < minU) minU = u;
      if (u > maxU) maxU = u;
    }
    final wrap = maxU - minU > .5;
    int col(int k) {
      final l = pl[k];
      final aa = (alpha * 255).round();
      if (tex != null) {
        final c = (l * 255).round().clamp(0, 255);
        return (aa << 24) | (c << 16) | (c << 8) | c;
      }
      int ch(double v) => (v * 255 * l).round().clamp(0, 255);
      return (aa << 24) | (ch(fb.r) << 16) | (ch(fb.g) << 8) | ch(fb.b);
    }

    for (int k = 1; k < n - 1; k++) {
      for (final q in [0, k, k + 1]) {
        pos..add(cam.cx + cam.focal * px[q] / pz[q])..add(cam.cy - cam.focal * py[q] / pz[q]);
        final u = wrap && pu[q] < .5 ? pu[q] + 1 : pu[q];
        tc..add(u * tw)..add(pv[q] * th);
        cols.add(col(q));
      }
    }
  }

  void tri(int p, int q, int r) {
    px.clear();
    py.clear();
    pz.clear();
    pu.clear();
    pv.clear();
    pl.clear();
    final ids = [p, q, r];
    if (vz[p] >= near && vz[q] >= near && vz[r] >= near) {
      for (final k in ids) {
        px.add(vx[k]);
        py.add(vy[k]);
        pz.add(vz[k]);
        pu.add(tu[k]);
        pv.add(tv[k]);
        pl.add(lit[k]);
      }
      emitPoly();
      return;
    }
    if (vz[p] < near && vz[q] < near && vz[r] < near) return;
    // قص Sutherland–Hodgman مقابل z = near
    for (int e = 0; e < 3; e++) {
      final s = ids[e], f = ids[(e + 1) % 3];
      final sIn = vz[s] >= near, fIn = vz[f] >= near;
      if (sIn) {
        px.add(vx[s]);
        py.add(vy[s]);
        pz.add(vz[s]);
        pu.add(tu[s]);
        pv.add(tv[s]);
        pl.add(lit[s]);
      }
      if (sIn != fIn) {
        final t = (near - vz[s]) / (vz[f] - vz[s]);
        px.add(vx[s] + (vx[f] - vx[s]) * t);
        py.add(vy[s] + (vy[f] - vy[s]) * t);
        pz.add(near);
        var uf = tu[f];
        if ((uf - tu[s]).abs() > .5) uf += tu[s] > uf ? 1 : -1;
        pu.add(tu[s] + (uf - tu[s]) * t);
        pv.add(tv[s] + (tv[f] - tv[s]) * t);
        pl.add(lit[s] + (lit[f] - lit[s]) * t);
      }
    }
    for (int k = 0; k < pu.length; k++) {
      pu[k] = pu[k] - pu[k].floorToDouble();
    }
    emitPoly();
  }

  for (int j = 0; j < segs; j++) {
    tri(0, 1 + j, 1 + (j + 1) % segs);
  }
  for (int i = 1; i < rings; i++) {
    final r0 = 1 + (i - 1) * segs, r1 = 1 + i * segs;
    for (int j = 0; j < segs; j++) {
      final j1 = (j + 1) % segs;
      tri(r0 + j, r1 + j, r1 + j1);
      tri(r0 + j, r1 + j1, r0 + j1);
    }
  }
  if (pos.isEmpty) return;
  final paint = Paint()..blendMode = style.blend;
  if (tex != null) {
    paint.shader = ImageShader(tex, TileMode.repeated, TileMode.clamp, Matrix4Identity.storage, filterQuality: FilterQuality.medium);
  } else {
    paint.color = const Color(0xFFFFFFFF);
  }
  canvas.drawVertices(
    ui.Vertices.raw(ui.VertexMode.triangles, Float32List.fromList(pos),
        textureCoordinates: tex != null ? Float32List.fromList(tc) : null, colors: Int32List.fromList(cols)),
    BlendMode.modulate,
    paint,
  );
}
