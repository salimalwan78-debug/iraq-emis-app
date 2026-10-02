import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'edit_student_screen.dart';

class SelectStudentScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  final List<dynamic> preLoadedStudents;

  const SelectStudentScreen({
    super.key, 
    required this.token, 
    required this.schoolId, 
    required this.preLoadedStudents,
  });

  @override
  State<SelectStudentScreen> createState() => _SelectStudentScreenState();
}

class _SelectStudentScreenState extends State<SelectStudentScreen> {
  List<dynamic> _allStudents = []; 
  List<dynamic> _filteredStudents = []; 
  
  List<String> _stages = [];
  List<String> _classRooms = [];
  
  String? _selectedStage;
  String? _selectedClassRoom;
  String? _selectedStudentId; 

  @override
  void initState() {
    super.initState();
    _allStudents = widget.preLoadedStudents;
    
    // استخراج المراحل (الصفوف) المتاحة من البيانات المحملة
    _stages = _allStudents
        .map((s) => s['studentStage']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  void _onStageSelected(String? stage) {
    setState(() {
      _selectedStage = stage;
      _selectedClassRoom = null;
      _selectedStudentId = null;
      
      // استخراج شعب هذه المرحلة فقط
      _classRooms = _allStudents
          .where((s) => s['studentStage'] == stage)
          .map((s) => (s['classRoomName'] ?? s['classRoom'])?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
          
      _filterStudents();
    });
  }

  void _onClassRoomSelected(String? classRoom) {
    setState(() {
      _selectedClassRoom = classRoom;
      _selectedStudentId = null;
      _filterStudents();
    });
  }

  void _filterStudents() {
    _filteredStudents = _allStudents.where((student) {
      bool matchStage = _selectedStage == null || student['studentStage'] == _selectedStage;
      bool matchClass = _selectedClassRoom == null || (student['classRoomName'] ?? student['classRoom']) == _selectedClassRoom;
      return matchStage && matchClass;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('تعديل الطلاب', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'اختر الصف', border: OutlineInputBorder()),
                    value: _selectedStage,
                    items: _stages.map((stage) => DropdownMenuItem(value: stage, child: Text(stage))).toList(),
                    onChanged: _onStageSelected,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'اختر الشعبة', border: OutlineInputBorder()),
                    value: _selectedClassRoom,
                    items: _classRooms.map((cr) => DropdownMenuItem(value: cr, child: Text(cr))).toList(),
                    onChanged: _stages.isEmpty ? null : _onClassRoomSelected,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredStudents.isEmpty
                ? const Center(child: Text('الرجاء اختيار الصف والشعبة لعرض الطلاب'))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      var student = _filteredStudents[index];
                      String studentId = student['id'].toString();
                      bool isSelected = _selectedStudentId == studentId;

                      return Card(
                        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
                        elevation: isSelected ? 2 : 1,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: isSelected ? Colors.blue : Colors.transparent, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
                            child: Icon(Icons.person, color: isSelected ? Colors.white : Colors.grey[600]),
                          ),
                          title: Text(student['fullName'] ?? student['name'] ?? 'بدون اسم', 
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('رقم الطالب: $studentId'),
                          onTap: () {
                            setState(() {
                              _selectedStudentId = studentId;
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _selectedStudentId == null
                    ? null
                    : () {
                        // الانتقال لصفحة التعديل
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditStudentScreen(token: widget.token),
                          ),
                        );
                      },
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text('تعديل بيانات الطالب المحدد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
