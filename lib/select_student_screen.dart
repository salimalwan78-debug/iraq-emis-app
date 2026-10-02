import 'package:flutter/material.dart';
import 'edit_student_screen.dart';
import 'app_core.dart';

class SelectStudentScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  final List<dynamic> preLoadedStudents;

  const SelectStudentScreen({super.key, required this.token, required this.schoolId, required this.preLoadedStudents});

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
    _stages = _allStudents.map((s) => s['studentStage']?.toString() ?? '').where((s) => s.isNotEmpty).toSet().toList();
  }

  void _onStageSelected(String? stage) {
    setState(() {
      _selectedStage = stage; _selectedClassRoom = null; _selectedStudentId = null;
      _classRooms = _allStudents.where((s) => s['studentStage'] == stage).map((s) => (s['classRoomName'] ?? s['classRoom'])?.toString() ?? '').where((s) => s.isNotEmpty).toSet().toList();
      _filterStudents();
    });
  }

  void _onClassRoomSelected(String? classRoom) {
    setState(() { _selectedClassRoom = classRoom; _selectedStudentId = null; _filterStudents(); });
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder: (context, currentMode, child) {
        bool isDark = currentMode == ThemeMode.dark;
        Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
        Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        Color textColor = isDark ? Colors.white : Colors.black87;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(title: const Text('تعديل الطلاب', style: TextStyle(color: Colors.white)), flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A90E2)]))), iconTheme: const IconThemeData(color: Colors.white)),
          body: Column(
            children: [
              Container(
                color: cardColor, padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'اختر الصف', labelStyle: TextStyle(color: textColor), filled: true, fillColor: isDark ? Colors.black12 : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                      value: _selectedStage, dropdownColor: cardColor, style: TextStyle(color: textColor),
                      items: _stages.map((stage) => DropdownMenuItem(value: stage, child: Text(stage))).toList(),
                      onChanged: _onStageSelected,
                    )),
                    const SizedBox(width: 15),
                    Expanded(child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'اختر الشعبة', labelStyle: TextStyle(color: textColor), filled: true, fillColor: isDark ? Colors.black12 : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                      value: _selectedClassRoom, dropdownColor: cardColor, style: TextStyle(color: textColor),
                      items: _classRooms.map((cr) => DropdownMenuItem(value: cr, child: Text(cr))).toList(),
                      onChanged: _stages.isEmpty ? null : _onClassRoomSelected,
                    )),
                  ],
                ),
              ),
              Expanded(
                child: _filteredStudents.isEmpty
                    ? Center(child: Text('الرجاء اختيار الصف والشعبة لعرض الطلاب', style: TextStyle(color: textColor)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10), itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          var student = _filteredStudents[index];
                          String studentId = student['id'].toString();
                          bool isSelected = _selectedStudentId == studentId;
                          return Card(
                            color: isSelected ? Colors.blue.withOpacity(0.2) : cardColor,
                            shape: RoundedRectangleBorder(side: BorderSide(color: isSelected ? Colors.blue : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: isSelected ? Colors.blue : (isDark ? Colors.grey[800] : Colors.grey[300]), child: Icon(Icons.person, color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]))),
                              title: Text(student['fullName'] ?? student['name'] ?? 'بدون اسم', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                              subtitle: Text('رقم الطالب: $studentId', style: const TextStyle(color: Colors.grey)),
                              onTap: () => setState(() => _selectedStudentId = studentId),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(15), color: cardColor,
                child: SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _selectedStudentId == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => EditStudentScreen(token: widget.token, studentId: _selectedStudentId!))),
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text('تعديل بيانات الطالب المحدد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), disabledBackgroundColor: Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
