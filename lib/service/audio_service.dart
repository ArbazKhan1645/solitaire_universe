import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  factory AudioService() => instance;
  AudioService._internal();

  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _soundEffectPlayer = AudioPlayer();

  bool _isMusicEnabled = true;
  bool _areSoundEffectsEnabled = true;
  bool _isInitialized = false;

  bool get isMusicEnabled => _isMusicEnabled;
  bool get areSoundEffectsEnabled => _areSoundEffectsEnabled;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isMusicEnabled = prefs.getBool('music_enabled') ?? true;
      _areSoundEffectsEnabled = prefs.getBool('sound_effects_enabled') ?? true;

      // Set audio mode for background music
      await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _backgroundMusicPlayer.setVolume(0.3);

      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio service: $e');
    }
  }

  Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) return;

    try {
      // Use asset source for background music
      // Make sure to add your audio file to assets folder
      await _backgroundMusicPlayer.play(AssetSource('music/background.mp3'));
    } catch (e) {
      print('Error playing background music: $e');
      // If asset doesn't exist, just continue without error
    }
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.stop();
    } catch (e) {
      print('Error stopping background music: $e');
    }
  }

  Future<void> pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
    } catch (e) {
      print('Error pausing background music: $e');
    }
  }

  Future<void> resumeBackgroundMusic() async {
    if (!_isMusicEnabled) return;

    try {
      await _backgroundMusicPlayer.resume();
    } catch (e) {
      print('Error resuming background music: $e');
    }
  }

  Future<void> playSoundEffect(String soundName) async {
    if (!_areSoundEffectsEnabled) return;

    try {
      await _soundEffectPlayer.play(AssetSource(soundName));
    } catch (e) {
      print('Error playing sound effect: $e');
    }
  }

  Future<void> toggleMusic(bool enabled) async {
    _isMusicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', enabled);

    if (enabled) {
      await playBackgroundMusic();
    } else {
      await stopBackgroundMusic();
    }
  }

  Future<void> toggleSoundEffects(bool enabled) async {
    _areSoundEffectsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_effects_enabled', enabled);
  }

  Future<void> setMusicVolume(double volume) async {
    await _backgroundMusicPlayer.setVolume(volume);
  }

  void dispose() {
    _backgroundMusicPlayer.dispose();
    _soundEffectPlayer.dispose();
  }
}
