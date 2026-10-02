import 'package:flutter/material.dart';

class TeachersListScreen extends StatelessWidget {
  const TeachersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة المعلمين', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Text(
          'سيتم عرض قائمة المعلمين هنا قريباً...',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ),
    );
  }
}
