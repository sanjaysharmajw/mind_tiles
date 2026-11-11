import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/data/player_data_controller.dart';
import 'package:mind_tiles_game/data/repositories/save_repository.dart';
import 'package:mind_tiles_game/game/systems/audio_manager.dart';
import 'package:mind_tiles_game/playables/playables_ad_service.dart';
import 'package:mind_tiles_game/playables/playables_platform.dart';
import 'package:mind_tiles_game/playables/playables_store.dart';
import 'package:mind_tiles_game/services/ads/ad_service.dart';

class FlakyPlatform extends LocalPlayablesPlatform {
  FlakyPlatform({super.initialSave, this.failLoads = 0});
  int failLoads;
  int loadCalls = 0;

  @override
  Future<String> loadData() async {
    loadCalls++;
    if (failLoads > 0) {
      failLoads--;
      throw StateError('API_UNAVAILABLE');
    }
    return initialSave;
  }
}

class AdsPlatform extends LocalPlayablesPlatform {
  AdsPlatform({required this.earn});
  final bool earn;
  final List<String> calls = [];
  @override
  bool get inPlayablesEnv => true;
  @override
  bool get adsAvailable => true;
  @override
  Future<bool> requestRewardedAd(String rewardId) async {
    calls.add('rewarded:$rewardId');
    return earn;
  }

  @override
  Future<void> requestInterstitialAd() async => calls.add('interstitial');
}

void main() {
  group('PlayablesStore (cloud save)', () {
    test('loads existing cloud data and saves the whole map as JSON', () async {
      final p = LocalPlayablesPlatform(initialSave: jsonEncode({'a': '1'}));
      final store = await PlayablesStore.open(p);
      expect(store.loaded, isTrue);
      expect(await store.getString('a'), '1');
      await store.setString('b', '2');
      expect(jsonDecode(p.lastSaved!), {'a': '1', 'b': '2'});
      await store.remove('a');
      expect(jsonDecode(p.lastSaved!), {'b': '2'});
    });

    test('empty or corrupt cloud data starts fresh', () async {
      expect(PlayablesStore.decode(''), isEmpty);
      expect(PlayablesStore.decode('not json'), isEmpty);
      expect(PlayablesStore.decode('[1,2]'), isEmpty);
      expect(PlayablesStore.decode('{"k":1,"ok":"v"}'), {'ok': 'v'});
    });

    test(
      'failed load: no save until a later load succeeds (empty → saves)',
      () async {
        final p = FlakyPlatform(failLoads: 2);
        final store = await PlayablesStore.open(p);
        expect(store.loaded, isFalse);
        await store.setString('k', 'v'); // load fails again → not saved
        expect(p.saveCount, 0);
        await store.setString('k', 'v2'); // load succeeds, cloud empty → saves
        expect(p.saveCount, 1);
        expect(jsonDecode(p.lastSaved!), {'k': 'v2'});
      },
    );

    test(
      'failed load: never overwrites progress that exists in the cloud',
      () async {
        final p = FlakyPlatform(
          failLoads: 1,
          initialSave: jsonEncode({'k': 'old'}),
        );
        final store = await PlayablesStore.open(p);
        await store.setString('k', 'new');
        await store.setString('k', 'newer');
        expect(p.saveCount, 0);
      },
    );

    test('player progress round-trips through cloud save', () async {
      final p = LocalPlayablesPlatform();
      final c = await PlayerDataController.load(
        SaveRepository(await PlayablesStore.open(p)),
      );
      c.markTutorialSeen();
      await c.flush();
      final p2 = LocalPlayablesPlatform(initialSave: p.lastSaved!);
      final c2 = await PlayerDataController.load(
        SaveRepository(await PlayablesStore.open(p2)),
      );
      expect(c2.tutorialSeen, isTrue);
      expect(
        p.lastSaved!.length * 2,
        lessThan(PlayablesStore.recommendedSaveBytes),
      );
    });
  });

  group('PlayablesAdService (ytgame.ads)', () {
    test('rewarded hint only when the SDK reports the reward', () async {
      final yes = AdsPlatform(earn: true);
      expect(
        await PlayablesAdService(yes).showRewarded(),
        RewardOutcome.rewarded,
      );
      expect(yes.calls, ['rewarded:${PlayablesAdService.hintRewardId}']);
      expect(
        await PlayablesAdService(AdsPlatform(earn: false)).showRewarded(),
        RewardOutcome.dismissed,
      );
      expect(
        await PlayablesAdService(LocalPlayablesPlatform()).showRewarded(),
        RewardOutcome.unavailable,
      );
      expect(
        PlayablesAdService(LocalPlayablesPlatform()).isRewardedReady,
        isFalse,
      );
    });

    test(
      'interstitials follow the frequency policy and never banner',
      () async {
        final p = AdsPlatform(earn: true);
        final ads = PlayablesAdService(p);
        for (var i = 0; i < 2; i++) {
          ads.onGameFinished();
          expect(await ads.maybeShowInterstitial(), isFalse);
        }
        ads.onGameFinished();
        expect(await ads.maybeShowInterstitial(), isTrue);
        expect(p.calls, ['interstitial']);
      },
    );
  });

  group('Audio respects YouTube mute', () {
    test('platform mute blocks effects and pauses music; unmute resumes', () {
      final backend = SilentAudioBackend();
      final audio = AudioManager(backend)..apply(soundOn: true, musicOn: true);
      expect(backend.musicPlaying, isTrue);
      audio.setPlatformAudioEnabled(false);
      expect(backend.musicPlaying, isFalse);
      audio.play(Sfx.match);
      expect(
        backend.played,
        isEmpty,
        reason: 'no sound while YouTube is muted',
      );
      audio.setPlatformAudioEnabled(true);
      expect(backend.musicPlaying, isTrue);
      audio.play(Sfx.match);
      expect(backend.played, ['match.wav']);
    });

    test('in-game music toggle cannot unmute while YouTube is muted', () {
      final backend = SilentAudioBackend();
      AudioManager(backend)
        ..setPlatformAudioEnabled(false)
        ..apply(soundOn: true, musicOn: true);
      expect(backend.musicPlaying, isFalse);
    });
  });
}
