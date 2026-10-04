import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GradesScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  const GradesScreen({super.key, required this.token, required this.schoolId});
  @override State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  List<Map<String,dynamic>> stages=[], subjects=[], rooms=[], exams=[], students=[];
  String? stageId,subjectId,roomId,examId;
  final Map<int,TextEditingController> grades={};
  bool loading=true,saving=false,examIgnored=false;
  String? error;
  Map<String,String> get h=>{'Authorization':widget.token,'Accept':'application/json','Content-Type':'application/json'};
  dynamic unwrap(dynamic d)=>d is Map&&d['data']!=null?d['data']:d;
  @override void initState(){super.initState();_loadStages();}
  @override void dispose(){for(final c in grades.values)c.dispose();super.dispose();}
  Future<dynamic> getJson(String ep)async{final r=await http.get(Uri.parse('https://emis.moedu.gov.iq/api$ep'),headers:h);if(r.statusCode<200||r.statusCode>=300)throw Exception('HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');return unwrap(jsonDecode(utf8.decode(r.bodyBytes)));}
  Future<List<Map<String,dynamic>>> list(String ep)async{final d=await getJson(ep);return d is List?d.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];}
  Future<void> _loadStages()async{try{stages=await list('/selectoption/getschoolstages/${widget.schoolId}');if(mounted)setState(()=>loading=false);}catch(e){if(mounted)setState(() { loading=false; error='$e'; });}}
  Future<void> _stageChanged(String? v)async{if(v==null)return;setState(() { stageId=v; subjectId=null; roomId=null; examId=null; subjects=[]; rooms=[]; exams=[]; students=[]; });try{subjects=await list('/subject/getsubjectsselect?stageId=$v&schoolId=${widget.schoolId}');if(mounted)setState((){});}catch(e){if(mounted)setState(()=>error='$e');}}
  Future<void> _subjectChanged(String? v)async{if(v==null||stageId==null)return;setState(() { subjectId=v; roomId=null; examId=null; rooms=[]; exams=[]; students=[]; });try{rooms=await list('/selectoption/getClassRooms?stageId=$stageId&schoolId=${widget.schoolId}&subjectId=$v');exams=await _getExams(v);if(mounted)setState((){});}catch(e){if(mounted)setState(()=>error='$e');}}
  Future<List<Map<String,dynamic>>> _getExams(String sid)async{final d=await getJson('/examscore/getexamsformarks?schoolId=${widget.schoolId}&stageId=$stageId&subjectId=$sid');final a=d is Map&&d['exams'] is List?d['exams']:[];return a.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
  Future<void> _loadStudents()async{if(stageId==null||subjectId==null)return;try{String ep='/examscore/getstudentswithgrades?schoolId=${widget.schoolId}&stageId=$stageId&subjectId=$subjectId';if(roomId!=null)ep+='&classroomId=$roomId';final d=await getJson(ep);students=d is List?d.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];for(final c in grades.values)c.dispose();grades.clear();for(final s in students){final id=int.tryParse('${s['id']}');if(id==null)continue;Map<String,dynamic> g={}; for(final raw in (s['grades'] is List ? s['grades'] : [])){ if(raw is Map && '${raw['examId'] ?? raw['id']}'==examId){ g=Map<String,dynamic>.from(raw); break; }} final v=g['grade']??g['score']??g['value'];grades[id]=TextEditingController(text:v==null?'':'$v');}if(mounted)setState((){});}catch(e){if(mounted)setState(()=>error='$e');}}
  Map<String,dynamic>? get currentExam{for(final e in exams)if('${e['id']}'==examId)return e;return null;}
  Future<void> _saveGrades()async{final ex=currentExam;if(ex==null)return;setState(()=>saving=true);int ok=0,failed=0;for(final s in students){final id=int.tryParse('${s['id']}');if(id==null)continue;final value=grades[id]?.text.trim()??'';if(value.isEmpty)continue;final grade=double.tryParse(value);if(grade==null)continue;try{final r=await http.post(Uri.parse('https://emis.moedu.gov.iq/api/examscore/updateexamgrade'),headers:h,body:jsonEncode({'studentId':id,'examId':int.tryParse('${ex['id']}'),'grade':grade}));if(r.statusCode>=200&&r.statusCode<300)ok++;else failed++;}catch(_){failed++;}}if(mounted){setState(()=>saving=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم حفظ $ok درجة${failed>0?' — فشل $failed':''}'),backgroundColor:failed==0?Colors.green:Colors.orange));}}
  Future<void> _changeIgnore(bool ignore)async{final ex=currentExam;if(ex==null||students.isEmpty)return;setState(()=>saving=true);final ids=students.map((s)=>int.tryParse('${s['id']}')).whereType<int>().toList();final path=ignore?'/examscore/ignoreexamgrade':'/examScore/unignoreexamgrade';try{final r=await http.post(Uri.parse('https://emis.moedu.gov.iq/api$path'),headers:h,body:jsonEncode({'examId':int.tryParse('${ex['id']}'),'studentIds':ids}));if(r.statusCode<200||r.statusCode>=300)throw Exception('HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');if(mounted){setState(() { saving=false; examIgnored=ignore; });ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ignore?'تم إهمال الفصل الدراسي':'تم إلغاء إهمال الفصل الدراسي'),backgroundColor:Colors.green));}}catch(e){if(mounted){setState(()=>saving=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشلت العملية: $e'),backgroundColor:Colors.red));}}}
  @override
  Widget build(BuildContext context) {
    final ex = currentExam;
    final max = double.tryParse('${ex?['maxAllowedGrade'] ?? 100}') ?? 100;
    return Scaffold(
      appBar: AppBar(title: const Text('الدرجات', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange.shade800, iconTheme: const IconThemeData(color: Colors.white)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null) Text(error!, style: const TextStyle(color: Colors.red), textDirection: TextDirection.rtl),
                _drop('الصف الدراسي', stageId, stages, (x) => '${x['displayName'] ?? x['name'] ?? x['label'] ?? x['value']}', _stageChanged),
                const SizedBox(height: 10),
                _drop('المادة', subjectId, subjects, (x) => '${x['displayName'] ?? x['name'] ?? x['label'] ?? x['value']}', _subjectChanged),
                const SizedBox(height: 10),
                _drop('الشعبة', roomId, rooms, (x) => '${x['displayName'] ?? x['name'] ?? x['label'] ?? x['value']}', (v) { setState(() => roomId = v); _loadStudents(); }),
                const SizedBox(height: 10),
                _drop('فصل الدرجات / الامتحان', examId, exams, (x) => '${x['label'] ?? x['displayName'] ?? x['name'] ?? x['id']}', (v) { setState(() => examId = v); _loadStudents(); }),
                if (ex != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: Text('${ex['label'] ?? ''}', textDirection: TextDirection.rtl),
                      subtitle: Text('الدرجة القصوى: $max | الطلاب: ${students.length}', textDirection: TextDirection.rtl),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(tooltip: 'إهمال الفصل', onPressed: saving ? null : () => _changeIgnore(true), icon: const Icon(Icons.visibility_off, color: Colors.red)),
                          IconButton(tooltip: 'إلغاء الإهمال', onPressed: saving ? null : () => _changeIgnore(false), icon: const Icon(Icons.visibility, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...students.map((s) {
                    final id = int.tryParse('${s['id']}') ?? -1;
                    return Card(
                      child: ListTile(
                        title: Text('${s['name'] ?? s['fullName'] ?? ''}', textDirection: TextDirection.rtl),
                        subtitle: Text('رقم الطالب: ${s['id'] ?? ''}'),
                        trailing: SizedBox(
                          width: 90,
                          child: TextField(
                            controller: grades[id],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(hintText: '0-$max', border: const OutlineInputBorder()),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (students.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(height: 50, child: FilledButton.icon(onPressed: saving ? null : _saveGrades, icon: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: const Text('حفظ الدرجات'))),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _drop(String label, String? value, List<Map<String,dynamic>> data, String Function(Map<String,dynamic>) labelOf, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: data.map((x) {
        final v = '${x['id'] ?? x['value'] ?? ''}';
        return DropdownMenuItem(value: v, child: Text(labelOf(x), overflow: TextOverflow.ellipsis));
      }).where((x) => x.value!.isNotEmpty).toList(),
      onChanged: data.isEmpty ? null : onChanged,
    );
  }
}
