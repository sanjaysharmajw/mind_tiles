import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Sfx {
  flip('flip.wav', 0.7),
  match('match.wav', 0.8),
  mismatch('mismatch.wav', 0.6),
  button('button.wav', 0.5),
  victory('victory.wav', 0.8),
  fail('fail.wav', 0.7),
  hint('hint.wav', 0.6),
  star('star.wav', 0.6);

  const Sfx(this.file, this.volume);
  final String file;
  final double volume;
}

/// Low-level audio playback. Swappable so tests run silently.
abstract class AudioBackend {
  Future<void> preload(List<String> files);
  Future<void> play(String file, double volume);
  Future<void> startMusic(String file, double volume);
  Future<void> stopMusic();
  Future<void> pauseMusic();
  Future<void> resumeMusic();
}

/// Plays sounds with `audioplayers`, using a fixed bank of reusable players
/// (a few "voices" per effect, round-robin) instead of creating a player per
/// sound. Position tracking is disabled because the game never needs it, so
/// no per-frame callbacks run while sounds play. Every call is guarded: a
/// missing codec or audio device leaves the game silent, never crashed.
class AudioPlayersBackend implements AudioBackend {
  static const int voicesPerSound = 3;
  static const String _assetDir = 'audio/'; // relative to assets/

  final Map<String, Future<List<AudioPlayer>>> _bank = {};
  final Map<String, int> _nextVoice = {};
  AudioPlayer? _music;
  String? _musicFile;

  /// iOS: "ambient" (respects the silent switch, mixes with the player's
  /// own music). Android: media stream without taking audio focus.
  static AudioContext _context() => defaultTargetPlatform == TargetPlatform.iOS
      ? AudioContextConfig(respectSilence: true).build()
      : AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build();

  Future<AudioPlayer> _newPlayer(PlayerMode mode, ReleaseMode release) async {
    final p = AudioPlayer()..positionUpdater = null;
    if (!kIsWeb) await p.setAudioContext(_context()); // not supported on web
    await p.setPlayerMode(mode);
    await p.setReleaseMode(release);
    return p;
  }

  /// Futures are cached so concurrent first plays share one set of voices.
  Future<List<AudioPlayer>> _voicesFor(String file) =>
      _bank.putIfAbsent(file, () async {
        final voices = <AudioPlayer>[];
        for (var i = 0; i < voicesPerSound; i++) {
          final p = await _newPlayer(PlayerMode.lowLatency, ReleaseMode.stop);
          await p.setSource(AssetSource('$_assetDir$file'));
          voices.add(p);
        }
        return voices;
      });

  @override
  Future<void> preload(List<String> files) async {
    for (final f in files) {
      try {
        await _voicesFor(f);
      } catch (e) {
        debugPrint('Audio preload failed for $f: $e');
      }
    }
  }

  @override
  Future<void> play(String file, double volume) async {
    try {
      final voices = await _voicesFor(file);
      final i = (_nextVoice[file] ?? 0) % voices.length;
      _nextVoice[file] = i + 1;
      final p = voices[i];
      await p.stop();
      await p.setVolume(volume);
      await p.resume();
    } catch (e) {
      debugPrint('Audio play failed: $e');
    }
  }

  @override
  Future<void> startMusic(String file, double volume) async {
    try {
      final m = _music ??= await _newPlayer(
        PlayerMode.mediaPlayer,
        ReleaseMode.loop,
      );
      if (_musicFile != file) {
        await m.setSource(AssetSource('$_assetDir$file'));
        _musicFile = file;
      }
      await m.setVolume(volume);
      await m.resume();
    } catch (e) {
      debugPrint('Music start failed: $e');
    }
  }

  @override
  Future<void> stopMusic() async {
    try {
      await _music?.stop();
    } catch (_) {}
  }

  @override
  Future<void> pauseMusic() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }

  @override
  Future<void> resumeMusic() async {
    try {
      await _music?.resume();
    } catch (_) {}
  }
}

class SilentAudioBackend implements AudioBackend {
  final List<String> played = [];
  bool musicPlaying = false;

  @override
  Future<void> preload(List<String> files) async {}
  @override
  Future<void> play(String file, double volume) async => played.add(file);
  @override
  Future<void> startMusic(String file, double volume) async =>
      musicPlaying = true;
  @override
  Future<void> stopMusic() async => musicPlaying = false;
  @override
  Future<void> pauseMusic() async => musicPlaying = false;
  @override
  Future<void> resumeMusic() async => musicPlaying = true;
}

/// Applies the player's sound/music preferences on top of an [AudioBackend].
class AudioManager {
  AudioManager(this.backend);

  final AudioBackend backend;
  static const String musicFile = 'music_loop.m4a';
  static const double musicVolume = 0.35;

  bool _soundOn = true;
  bool _musicOn = false;
  bool _musicStarted = false;
  bool _appActive = true;
  bool _platformAudio = true;

  bool get soundOn => _soundOn;
  bool get musicOn => _musicOn;

  /// Whether the host platform allows audio right now (e.g. the YouTube
  /// Playables mute button). When false, nothing is played at all.
  bool get platformAudioEnabled => _platformAudio;

  bool get _canPlay => _appActive && _platformAudio;

  Future<void> init() => backend.preload([for (final s in Sfx.values) s.file]);

  void play(Sfx sfx) {
    if (!_soundOn || !_canPlay) return;
    backend.play(sfx.file, sfx.volume);
  }

  void apply({required bool soundOn, required bool musicOn}) {
    _soundOn = soundOn;
    if (musicOn == _musicOn) return;
    _musicOn = musicOn;
    _syncMusic();
  }

  /// Called from app lifecycle changes (or Playables onPause/onResume).
  void setAppActive(bool active) {
    if (active == _appActive) return;
    final before = _canPlay;
    _appActive = active;
    _onGateChanged(before);
  }

  /// Host mute (YouTube Playables isAudioEnabled / onAudioEnabledChange).
  void setPlatformAudioEnabled(bool enabled) {
    if (enabled == _platformAudio) return;
    final before = _canPlay;
    _platformAudio = enabled;
    _onGateChanged(before);
  }

  void _onGateChanged(bool before) {
    final now = _canPlay;
    if (before == now) return;
    if (!_musicStarted) {
      _syncMusic();
      return;
    }
    if (now && _musicOn) {
      backend.resumeMusic();
    } else if (!now) {
      backend.pauseMusic();
    }
  }

  /// Browsers block audio until the first user gesture. Call this on the
  /// first tap so music that was refused at start-up begins playing.
  void retryAfterUserGesture() {
    if (_musicStarted && _musicOn && _canPlay) {
      backend.startMusic(musicFile, musicVolume);
    }
  }

  void _syncMusic() {
    if (_musicOn && _canPlay) {
      _musicStarted = true;
      backend.startMusic(musicFile, musicVolume);
    } else if (_musicStarted) {
      _musicStarted = false;
      backend.stopMusic();
    }
  }
}
