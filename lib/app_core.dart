import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AppCore {
  static ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  static final AudioPlayer audioPlayer = AudioPlayer();
  static bool isAudioMuted = false;

  static Future<void> playRelaxMusic() async {
    // التحقق الصارم: إذا كان المستخدم أوقفه، لا تقم بتشغيله أبداً
    if (isAudioMuted) return;
    
    audioPlayer.setReleaseMode(ReleaseMode.loop);
    if (audioPlayer.state != PlayerState.playing) {
      await audioPlayer.play(AssetSource('relax.mp3'));
    }
  }

  static Future<void> toggleAudio() async {
    isAudioMuted = !isAudioMuted;
    if (isAudioMuted) {
      // إيقاف جذري للصوت
      await audioPlayer.stop();
    } else {
      await playRelaxMusic();
    }
  }

  static void toggleTheme() {
    themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}
