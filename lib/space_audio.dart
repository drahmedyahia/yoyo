import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// أصوات الرحلة: هدير الإطلاق الحقيقي (تسجيل ناسا لإطلاق أرتميس 2)،
/// أجواء الفضاء، صوت المحرك، والمؤثرات (ليزر، انفجار صخرة، اصطدام...).
/// كل الاستدعاءات محمية حتى لا تتعطل اللعبة إذا لم يتوفر الصوت.
class SpaceAudio {
  bool enabled;
  bool muted = false;

  SpaceAudio({this.enabled = true});

  static const _sfx = {
    'beep': 2,
    'beep_go': 1,
    'laser': 4,
    'explosion': 4,
    'hit': 2,
    'whoosh': 3,
    'warning': 1,
    'success': 1,
  };

  final Map<String, AudioPool> _pools = {};
  AudioPlayer? _roar, _ambience, _engine, _thrusters, _voice;
  final Map<AudioPlayer, double> _volumes = {};
  bool _ready = false;

  Future<void> init() async {
    if (!enabled) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      for (final e in _sfx.entries) {
        _pools[e.key] = await AudioPool.createFromAsset(
          path: 'audio/${e.key}.ogg',
          maxPlayers: e.value,
          playerMode: PlayerMode.lowLatency,
        );
      }
      _roar = await _player('audio/launch_roar.ogg', loop: false);
      _ambience = await _player('audio/space_ambience.ogg', loop: true);
      _engine = await _player('audio/engine_loop.ogg', loop: true);
      _thrusters = await _player('audio/thrusters.ogg', loop: false);
      _voice = await _player('audio/eagle_has_landed.ogg', loop: false);
      _ready = true;
    } catch (_) {
      enabled = false;
    }
  }

  Future<AudioPlayer> _player(String asset, {required bool loop}) async {
    final p = AudioPlayer();
    await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await p.setSource(AssetSource(asset));
    await p.setVolume(0);
    _volumes[p] = 0;
    return p;
  }

  void _safe(Future<void> Function() f) {
    try {
      unawaited(f().catchError((_) {}));
    } catch (_) {}
  }

  void play(String id, {double volume = 1}) {
    if (!_ready || muted) return;
    switch (id) {
      case 'roar':
        _start(_roar, volume);
        return;
      case 'thrusters':
        _start(_thrusters, volume);
        return;
      case 'eagle':
        _start(_voice, volume);
        return;
    }
    final pool = _pools[id];
    if (pool == null) return;
    _safe(() => pool.start(volume: volume));
  }

  void _start(AudioPlayer? p, double volume) {
    if (p == null) return;
    _volumes[p] = volume;
    _safe(() async {
      await p.stop();
      await p.setVolume(volume);
      await p.resume();
    });
  }

  /// مستويات الأصوات المستمرة (0..1) — تُستدعى كل إطار، وتُرسل فقط عند التغير.
  void levels({double roar = 0, double ambience = 0, double engine = 0}) {
    if (!_ready) return;
    _level(_roar, roar, loop: false);
    _level(_ambience, ambience, loop: true);
    _level(_engine, engine, loop: true);
  }

  final Set<AudioPlayer> _looping = {};

  void _level(AudioPlayer? p, double v, {required bool loop}) {
    if (p == null) return;
    if (muted) v = 0;
    final old = _volumes[p] ?? 0;
    if ((old - v).abs() < .03 && !(v == 0 && old != 0)) return;
    _volumes[p] = v;
    _safe(() async {
      await p.setVolume(v);
      if (loop) {
        if (v > 0 && !_looping.contains(p)) {
          _looping.add(p);
          await p.resume();
        } else if (v == 0 && _looping.contains(p)) {
          _looping.remove(p);
          await p.pause();
        }
      }
    });
  }

  void setMuted(bool m) {
    muted = m;
    if (m) {
      for (final p in [_roar, _thrusters, _voice]) {
        if (p != null) _safe(() => p.pause());
      }
      levels();
    }
  }

  void stopAll() {
    for (final p in [_roar, _ambience, _engine, _thrusters, _voice]) {
      if (p != null) _safe(() => p.stop());
    }
    _looping.clear();
    _volumes.updateAll((_, __) => 0);
  }

  void dispose() {
    _ready = false;
    for (final p in [_roar, _ambience, _engine, _thrusters, _voice]) {
      if (p != null) _safe(() => p.dispose());
    }
    for (final pool in _pools.values) {
      _safe(() => pool.dispose());
    }
    _pools.clear();
  }
}
