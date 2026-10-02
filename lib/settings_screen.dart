import 'package:flutter/material.dart';
import 'app_core.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder: (context, currentMode, child) {
        bool isDark = currentMode == ThemeMode.dark;
        Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
        Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        Color textColor = isDark ? Colors.white : Colors.black87;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('الإعدادات', style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1A237E),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Colors.amber),
                    title: Text('الوضع الداكن (Dark Mode)', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    trailing: Switch(
                      value: isDark,
                      activeColor: Colors.amber,
                      onChanged: (val) {
                        AppCore.toggleTheme();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: Icon(AppCore.isAudioMuted ? Icons.volume_off : Icons.music_note, color: Colors.blue),
                    title: Text('الموسيقى الهادئة', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    trailing: Switch(
                      value: !AppCore.isAudioMuted,
                      activeColor: Colors.blue,
                      onChanged: (val) async {
                        await AppCore.toggleAudio();
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}
