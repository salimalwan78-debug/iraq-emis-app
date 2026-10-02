import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AppCore {
  // للتحكم بالوضع الداكن على مستوى التطبيق
  static ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  
  // للتحكم بالصوت
  static final AudioPlayer audioPlayer = AudioPlayer();
  static bool isAudioMuted = false;

  static Future<void> playRelaxMusic() async {
    audioPlayer.setReleaseMode(ReleaseMode.loop); // إعادة التشغيل تلقائياً
    if (!isAudioMuted) {
      await audioPlayer.play(AssetSource('relax.mp3'));
    }
  }

  static Future<void> toggleAudio() async {
    isAudioMuted = !isAudioMuted;
    if (isAudioMuted) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.resume();
    }
  }

  static void toggleTheme() {
    themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}
