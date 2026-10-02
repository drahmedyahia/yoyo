import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// الخرائط الحقيقية المستخدمة في الرسم ثلاثي الأبعاد (كلها من ناسا):
/// - earth_day: Blue Marble (NASA Earth Observatory)
/// - earth_clouds: غيوم الأرض (NASA Earth Observatory)
/// - moon: خريطة القمر الملونة من مسبار LRO (NASA SVS CGI Moon Kit)
/// - milky_way: خريطة النجوم ودرب التبانة (NASA SVS Deep Star Maps 2020)
class SpaceArt {
  ui.Image? earth, clouds, moon, sky;

  /// نسخ مصغرة تُستخدم عندما يظهر الجرم صغيراً (تمنع التشويش عند التصغير).
  ui.Image? earthSmall, cloudsSmall, moonSmall;

  SpaceArt();

  bool get loaded => earth != null && moon != null && sky != null;

  static Future<ui.Image?> _load(String path, {int? width}) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  static Future<SpaceArt> load() async {
    final a = SpaceArt();
    final r = await Future.wait([
      _load('assets/textures/earth_day.jpg'),
      _load('assets/textures/earth_clouds.jpg'),
      _load('assets/textures/moon.jpg'),
      _load('assets/textures/milky_way.jpg'),
      _load('assets/textures/earth_day.jpg', width: 256),
      _load('assets/textures/earth_clouds.jpg', width: 256),
      _load('assets/textures/moon.jpg', width: 256),
    ]);
    a
      ..earth = r[0]
      ..clouds = r[1]
      ..moon = r[2]
      ..sky = r[3]
      ..earthSmall = r[4]
      ..cloudsSmall = r[5]
      ..moonSmall = r[6];
    return a;
  }

  void dispose() {
    for (final i in [earth, clouds, moon, sky, earthSmall, cloudsSmall, moonSmall]) {
      i?.dispose();
    }
  }
}
