import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

import 'app_core.dart';

class EditStudentScreen extends StatefulWidget {
  final String token;
  final String studentId;

  const EditStudentScreen({
    super.key,
    required this.token,
    required this.studentId,
  });

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, dynamic>? _studentData;
  File? _pickedImage;

  // Arabic display names for coded EMIS values. The raw coded values are
  // deliberately kept inside _studentData so saving still sends the exact
  // values returned by EMIS.
  final Map<String, String> _displayValues = {};
  final Map<String, Map<String, String>> _referenceMaps = {};

  // Reference fields whose option endpoints are confirmed by the supplied
  // EMIS source files. Raw values remain in _studentData for saving.
  static const Set<String> _referenceFields = {
    'stageId',
    'classRoomId',
  };

  final Map<String, String> _officialArabicNames = {
    'name': 'الإسم',
    'fatherName': 'إسم الأب',
    'grandFatherName': 'اسم والد الأب',
    'surName': 'اللقب',
    'motherName': 'إسم الأم',
    'mothersFatherName': 'اسم والد الأم',
    'mothersGrandFatherName': 'اسم جد الأم',
    'birthDate': 'تاريخ التولد',
    'idNumber': 'رقم البطاقة الوطنية الموحدة',
    'recordNumber': 'رقم السجل',
    'pageNumber': 'رقم الصحيفة',
    'town': 'المدينة/القرية',
    'closestLocation': 'أقرب نقطة دالة',
    'street': 'المحلة',
    'homePhoneNumber': 'رقم الهاتف',
    'religion': 'الديانة',
    'bloodGroup': 'فئة الدم',
    'gender': 'الجنس',
    'nationality': 'الجنسية',
    'name': 'الإسم',
    'fatherName': 'إسم الأب',
    'grandFatherName': 'اسم والد الأب',
    'fathersGrandFatherName': 'اسم جد الأب',
    'surName': 'اللقب',
    'motherName': 'إسم الأم',
    'mothersFatherName': 'اسم والد الأم',
    'mothersGrandFatherName': 'اسم جد الأم',
    'dateOfBirth': 'تاريخ التولّد',
    'birthDate': 'تاريخ التولّد',
    'countryOfBirth': 'محل الولادة',
    'gender': 'الجنس',
    'nationality': 'الجنسية',
    'homeTown': 'مسقط الرأس',
    'motherTongue': 'اللغة الأم',
    'maritalStatus': 'الحالة الاجتماعية',
    'bloodGroup': 'فئة الدم',
    'religion': 'الديانة',
    'homePhoneNumber': 'رقم الهاتف',
    'notes': 'ملاحظات',
    'identification': 'المعلومات الرئيسية',
    'idNumber': 'رقم الهوية',
    'idType': 'نوع الهوية',
    'issuingCountry': 'بلد الإصدار',
    'recordNumber': 'رقم السجل',
    'pageNumber': 'رقم الصحيفة',
    'issuer': 'جهة الإصدار',
    'issuingDate': 'تاريخ الإصدار',
    'nameOfDocument': 'نوع الوثيقة',
    'fatherIdentification': 'هوية الأب',
    'address': 'العنوان',
    'addressType': 'نوع العنوان',
    'countryStructureId': 'هيكل الدولة',
    'town': 'المدينة/القرية',
    'area': 'الحي',
    'quarter': 'المحلة',
    'street': 'زقاق',
    'apartmentNumber': 'رقم الشقة',
    'closestLocation': 'أقرب نقطة دالة',
    'buildingNumber': 'رقم البناية',
    'schoolId': 'المدرسة',
    'stageId': 'الصف',
    'classRoomId': 'الشعبة',
    'censusNumber': 'الرقم الإحصائي',
    'specialNeeds': 'الاحتياجات الخاصة',
    'studyLanguage': 'لغة الدراسة',
    'economicLevel': 'المستوى الاقتصادي',
    'isCoveredBySocialWelfare': 'مشمول بالرعاية الاجتماعية؟',
    'isDroppedOutFromSchool': 'متسرّب من المدرسة؟',
    'lastYearResult': 'نتيجة العام الدراسي السابق',
    'ageExceptionReason': 'سبب استثناء العمر',
    'genderExceptionReason': 'سبب استثناء الجنس',
    'isDisabled': 'مفعّل',
  };

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    final url = Uri.parse(
      'https://emis.moedu.gov.iq/api/student/getstudent/${widget.studentId}',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': widget.token,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        if (decoded is! Map) {
          throw Exception('استجابة بيانات الطالب غير صالحة');
        }

        final student = _unwrapStudentResponse(decoded);
        await _loadReferenceLabels(student);

        if (!mounted) return;
        setState(() {
          _studentData = student;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('خطأ في جلب بيانات الطالب: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // EMIS FIELD / DISPLAY MAPPING
  // ============================================================

  // The saved HTML is the rendered EMIS edit page. Closed Quasar selects do
  // not contain their complete option lists in the DOM, so we never invent
  // endpoint names here. If EMIS returns {value, displayName}, that Arabic
  // displayName is used directly; otherwise the raw code is preserved.
  Map<String, dynamic> _unwrapStudentResponse(dynamic decoded) {
    if (decoded is Map) {
      final data = decoded['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception('استجابة بيانات الطالب غير صالحة');
  }

  Future<void> _loadReferenceLabels(Map<String, dynamic> student) async {
    _displayValues.clear();
    _referenceMaps.clear();
    _collectInlineDisplayValues(student);

    // These two endpoints are present in the supplied EMIS source material.
    // They return {value, displayName}.
    final schoolId = student['schoolId']?.toString() ?? '';
    final stageId = student['stageId']?.toString() ?? '';

    if (schoolId.isNotEmpty) {
      final stages = await _fetchOptions(
        '/selectoption/getAvailableStagesForStudent',
        query: {'schoolId': schoolId},
      );
      if (stages.isNotEmpty) {
        _referenceMaps['stageId'] = stages;
        final display = _lookupDisplayName(stages, student['stageId']);
        if (display != null) _displayValues['stageId'] = display;
      }

      // Fallback endpoint also confirmed by the supplied EMIS scripts.
      if (!_referenceMaps.containsKey('stageId')) {
        final fallback = await _fetchOptions(
          '/selectoption/getschoolstages/$schoolId',
        );
        if (fallback.isNotEmpty) {
          _referenceMaps['stageId'] = fallback;
          final display = _lookupDisplayName(fallback, student['stageId']);
          if (display != null) _displayValues['stageId'] = display;
        }
      }
    }

    if (schoolId.isNotEmpty && stageId.isNotEmpty) {
      final classrooms = await _fetchOptions(
        '/selectoption/getClassRooms',
        query: {'schoolId': schoolId, 'stageId': stageId},
      );
      if (classrooms.isNotEmpty) {
        _referenceMaps['classRoomId'] = classrooms;
        final display = _lookupDisplayName(classrooms, student['classRoomId']);
        if (display != null) _displayValues['classRoomId'] = display;
      }
    }
  }

  Future<Map<String, String>> _fetchOptions(
    String endpoint, {
    Map<String, String>? query,
  }) async {
    try {
      final base = Uri.parse('https://emis.moedu.gov.iq/api$endpoint');
      final uri = query == null || query.isEmpty
          ? base
          : base.replace(queryParameters: query);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': widget.token,
          'Accept': 'application/json',
        },
      );
      if (response.statusCode != 200) return {};

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final items = _extractOptionList(decoded);
      final result = <String, String>{};
      for (final item in items) {
        final value = _firstNonNull(item, const ['value', 'id', 'code', 'key']);
        final display = _firstNonNull(
          item,
          const ['displayName', 'name', 'label', 'text', 'title'],
        );
        if (value != null && display != null) {
          result[_normaliseCode(value)] = display.toString().trim();
        }
      }
      return result;
    } catch (e) {
      debugPrint('تعذر جلب خيارات EMIS من $endpoint: $e');
      return {};
    }
  }

  List<Map<String, dynamic>> _extractOptionList(dynamic decoded) {
    dynamic value = decoded;
    if (value is Map) {
      for (final key in const ['data', 'items', 'results', 'options', 'list']) {
        final candidate = value[key];
        if (candidate is List) {
          value = candidate;
          break;
        }
      }
    }
    if (value is! List) return [];
    return value.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item)).toList();
  }

  dynamic _firstNonNull(Map item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  String _normaliseCode(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    final number = num.tryParse(text);
    if (number != null && number == number.toInt()) return number.toInt().toString();
    return text.toLowerCase();
  }

  String? _lookupDisplayName(Map<String, String> map, dynamic rawValue) {
    if (rawValue is Map) {
      final inline = _firstNonNull(rawValue, const [
        'displayName', 'name', 'label', 'text', 'title'
      ]);
      if (inline != null) return inline.toString().trim();
      rawValue = _firstNonNull(rawValue, const ['value', 'id', 'code']);
    }
    return map[_normaliseCode(rawValue)];
  }

  void _collectInlineDisplayValues(Map<String, dynamic> map, [String prefix = '']) {
    map.forEach((key, value) {
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map) {
        final display = _firstNonNull(value, const [
          'displayName', 'name', 'label', 'text', 'title'
        ]);
        if (display != null) _displayValues[path] = display.toString().trim();
        _collectInlineDisplayValues(Map<String, dynamic>.from(value), path);
      }
    });
  }

  String _displayValueFor(String key, dynamic value) {
    final inline = _displayValues[key];
    if (inline != null && inline.isNotEmpty) return inline;
    if (value is Map) {
      final display = _firstNonNull(value, const [
        'displayName', 'name', 'label', 'text', 'title'
      ]);
      if (display != null) return display.toString().trim();
    }
    return value?.toString() ?? '';
  }

  // ============================================================
  // LOCAL BACKGROUND REMOVAL - Google ML Kit Selfie Segmentation
  // ============================================================
  //
  // The segmentation is performed locally on the phone.
  // No image is uploaded to a background-removal website or API.
  //
  // We intentionally reduce the working image to a maximum of 512 px
  // because this application only needs a student ID/avatar image.
  // This keeps processing fast and the resulting file small.

  SelfieSegmenter? _selfieSegmenter;

  Future<void> _initializeSelfieSegmenter() async {
    _selfieSegmenter ??= SelfieSegmenter(
      mode: SegmenterMode.single,
      enableRawSizeMask: false,
    );
  }

  Future<File?> _removeBackgroundUsingSelfieSegmentation(
    File imageFile,
  ) async {
    final stopwatch = Stopwatch()..start();
    File? normalizedFile;

    try {
      await _initializeSelfieSegmenter();

      final segmenter = _selfieSegmenter;
      if (segmenter == null) {
        throw Exception('تعذر تهيئة أداة إزالة الخلفية');
      }

      final sourceBytes = await imageFile.readAsBytes();
      var sourceImage = img.decodeImage(sourceBytes);

      if (sourceImage == null) {
        throw Exception('تعذر قراءة الصورة');
      }

      // Apply EXIF orientation before sending the image to ML Kit so that
      // the image and segmentation mask always have the same orientation.
      sourceImage = img.bakeOrientation(sourceImage);

      // Keep the processing image small. The longest side will be <= 512 px.
      const maxDimension = 512;
      if (sourceImage.width > maxDimension ||
          sourceImage.height > maxDimension) {
        sourceImage = img.copyResize(
          sourceImage,
          width: sourceImage.width >= sourceImage.height
              ? maxDimension
              : null,
          height: sourceImage.height > sourceImage.width
              ? maxDimension
              : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // Convert to a simple JPEG for ML Kit input. This avoids depending on
      // EXIF metadata after the orientation has already been baked in.
      normalizedFile = File(
        '${imageFile.path}_segmentation_input_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await normalizedFile.writeAsBytes(
        img.encodeJpg(sourceImage, quality: 90),
        flush: true,
      );

      final inputImage = InputImage.fromFilePath(normalizedFile.path);
      final mask = await segmenter.processImage(inputImage);

      if (mask == null) {
        throw Exception('لم يتم الحصول على قناع الشخص من ML Kit');
      }

      if (mask.width <= 0 || mask.height <= 0 || mask.confidences.isEmpty) {
        throw Exception('قناع إزالة الخلفية غير صالح');
      }

      if (mask.width != sourceImage.width ||
          mask.height != sourceImage.height) {
        throw Exception(
          'أبعاد قناع إزالة الخلفية لا تطابق الصورة: '
          '${mask.width}x${mask.height} مقابل '
          '${sourceImage.width}x${sourceImage.height}',
        );
      }

      // ML Kit returns a foreground confidence in the range 0..1 for each
      // pixel. Keep a small soft edge rather than using a hard binary cut.
      final result = img.Image(
        width: sourceImage.width,
        height: sourceImage.height,
        numChannels: 4,
      );

      final pixelCount = sourceImage.width * sourceImage.height;
      if (mask.confidences.length < pixelCount) {
        throw Exception(
          'عدد قيم القناع غير كافٍ: ${mask.confidences.length}',
        );
      }

      for (var y = 0; y < sourceImage.height; y++) {
        for (var x = 0; x < sourceImage.width; x++) {
          final index = y * sourceImage.width + x;
          final confidence = mask.confidences[index].clamp(0.0, 1.0);

          // Remove low-confidence background while keeping a smooth edge.
          // 0.35 -> transparent, 0.75 -> fully opaque.
          final alpha = ((confidence - 0.35) / 0.40 * 255.0)
              .round()
              .clamp(0, 255);

          final sourcePixel = sourceImage.getPixel(x, y);
          result.setPixelRgba(
            x,
            y,
            sourcePixel.r,
            sourcePixel.g,
            sourcePixel.b,
            alpha,
          );
        }
      }

      final outputPath =
          '${imageFile.path}_nobg_${DateTime.now().millisecondsSinceEpoch}.png';
      final outputFile = File(outputPath);

      await outputFile.writeAsBytes(
        img.encodePng(result, level: 6),
        flush: true,
      );

      debugPrint(
        'ML Kit background removal completed in '
        '${stopwatch.elapsedMilliseconds} ms: $outputPath',
      );

      return outputFile;
    } catch (e, stackTrace) {
      debugPrint('ML Kit background removal error: $e');
      debugPrint('$stackTrace');
      rethrow;
    } finally {
      if (normalizedFile != null) {
        try {
          if (await normalizedFile.exists()) {
            await normalizedFile.delete();
          }
        } catch (e) {
          debugPrint('تعذر حذف ملف المعالجة المؤقت: $e');
        }
      }
      stopwatch.stop();
    }
  }

  @override
  void dispose() {
    final segmenter = _selfieSegmenter;
    _selfieSegmenter = null;
    if (segmenter != null) {
      segmenter.close();
    }
    super.dispose();
  }

  // ============================================================
  // IMAGE PREVIEW
  // ============================================================

  Future<void> _showImagePreviewDialog(File imageFile) async {
    File currentImage = imageFile;
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'معاينة الصورة الشخصية',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          panEnabled: true,
                          boundaryMargin: const EdgeInsets.all(20),
                          minScale: 0.5,
                          maxScale: 4,
                          child: Image.file(
                            currentImage,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'يمكنك تقريب الصورة لمراجعتها قبل اعتمادها',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 15),
                    if (isProcessing)
                      const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'جاري إزالة الخلفية محليًا...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'يرجى الانتظار',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            setDialogState(() => isProcessing = true);
                            try {
                              final processed =
                                  await _removeBackgroundUsingSelfieSegmentation(
                                currentImage,
                              );

                              if (processed == null) {
                                throw Exception(
                                  'لم يتم الحصول على الصورة المعالجة',
                                );
                              }

                              if (!mounted) return;

                              setDialogState(() {
                                currentImage = processed;
                                isProcessing = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تمت إزالة الخلفية بنجاح'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              debugPrint('ML Kit background removal error: $e');
                              if (!mounted) return;

                              setDialogState(() => isProcessing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تعذر إزالة الخلفية: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.auto_fix_high,
                            color: Colors.black87,
                          ),
                          label: const Text(
                            'حذف الخلفية',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                          setState(() => _pickedImage = currentImage);
                          Navigator.pop(dialogContext);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
                    'اعتماد',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2500,
        maxHeight: 2500,
      );

      if (picked != null && mounted) {
        await _showImagePreviewDialog(File(picked.path));
      }
    } catch (e) {
      debugPrint('خطأ في اختيار الصورة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الكاميرا أو معرض الصور'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteCurrentPhoto() {
    setState(() {
      _pickedImage = null;
      if (_studentData != null) _studentData!['imageUrl'] = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف صورة الطالب')),
    );
  }

  // ============================================================
  // UPLOAD IMAGE TO EMIS
  // ============================================================

  Future<String?> _uploadImageToEmisServer(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://emis.moedu.gov.iq/api/student/uploadimage'),
    );

    request.headers['Authorization'] = widget.token;
    request.headers['Accept'] = 'application/json';

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: 'avatar.png',
      ),
    );

    try {
      final streamedResponse = await request.send();
      final responseData =
          await streamedResponse.stream.bytesToString();

      debugPrint('رفع صورة EMIS: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(responseData);
        if (jsonResponse is Map) {
          return jsonResponse['imageUrl']?.toString();
        }
      }

      debugPrint('استجابة رفع الصورة: $responseData');
    } catch (e) {
      debugPrint('خطأ في رفع الصورة إلى EMIS: $e');
    }

    return null;
  }

  // ============================================================
  // SAVE STUDENT
  // ============================================================

  Future<void> _saveStudentData() async {
    if (_studentData == null) return;

    setState(() => _isSaving = true);

    try {
      if (_pickedImage != null) {
        final newImageUrl =
            await _uploadImageToEmisServer(_pickedImage!);

        if (newImageUrl != null && newImageUrl.isNotEmpty) {
          _studentData!['imageUrl'] = newImageUrl;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تعذر رفع صورة الطالب'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final response = await http.post(
        Uri.parse(
          'https://emis.moedu.gov.iq/api/student/updatestudent',
        ),
        headers: {
          'Authorization': widget.token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(_studentData),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        debugPrint('Update student status: ${response.statusCode}');
        debugPrint('Update student response: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل الحفظ! تأكد من المدخلات'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('خطأ في حفظ بيانات الطالب: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في الاتصال'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================
  // DYNAMIC FIELDS
  // ============================================================

  List<Widget> _buildDynamicFields(
    Map<String, dynamic> dataMap,
    bool isDark,
    Color textColor, {
    String prefix = '',
  }) {
    final List<Widget> widgets = [];

    dataMap.forEach((key, value) {
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (key == 'imageUrl' ||
          key == 'id' ||
          key == 'createdAt' ||
          key == 'updatedAt' ||
          key == 'schoolId') {
        return;
      }

      final arabicLabel = _officialArabicNames[key] ?? key;

      if (value is Map<String, dynamic>) {
        widgets.add(
          Card(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            margin: const EdgeInsets.only(bottom: 15, top: 10),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arabicLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ..._buildDynamicFields(
                    value,
                    isDark,
                    textColor,
                    prefix: path,
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (value is List) {
        // Complex lists are intentionally not rendered as text fields.
      } else {
        widgets.add(
          PlainTextField(
            label: arabicLabel,
            initialValue: _displayValueFor(key, value),
            isDark: isDark,
            textColor: textColor,
            readOnly: _referenceFields.contains(key),
            onChanged: (v) {
              // Coded EMIS fields must keep their original numeric/code value
              // for the API. Their Arabic name is display-only.
              if (!_referenceFields.contains(key)) {
                dataMap[key] = v;
              }
            },
          ),
        );
      }
    });

    return widgets;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark;
        final bgColor =
            isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
        final cardColor =
            isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        String imgUrl = _studentData?['imageUrl']?.toString() ?? '';
        if (imgUrl.isNotEmpty && !imgUrl.startsWith('http')) {
          imgUrl = 'https://emis.moedu.gov.iq$imgUrl';
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text(
              'تعديل بيانات الطالب',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1A237E),
                    Color(0xFF4A90E2),
                  ],
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _studentData == null
                  ? const Center(child: Text('فشل جلب البيانات'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(15),
                            children: [
                              Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.blueAccent,
                                          width: 3,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: _pickedImage != null
                                            ? Image.file(
                                                _pickedImage!,
                                                fit: BoxFit.cover,
                                              )
                                            : imgUrl.isNotEmpty
                                                ? Image.network(
                                                    imgUrl,
                                                    headers: {
                                                      'Authorization':
                                                          widget.token,
                                                    },
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Icon(
                                                        Icons.person,
                                                        size: 80,
                                                        color: Colors.grey[400],
                                                      );
                                                    },
                                                  )
                                                : Icon(
                                                    Icons.person,
                                                    size: 80,
                                                    color: Colors.grey[400],
                                                  ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.blue,
                                        radius: 20,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed: () => _pickImage(
                                            ImageSource.camera,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.green,
                                        radius: 20,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.photo_library,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed: () => _pickImage(
                                            ImageSource.gallery,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: TextButton.icon(
                                  onPressed: _deleteCurrentPhoto,
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'حذف الصورة الحالية',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              ..._buildDynamicFields(
                                _studentData!,
                                isDark,
                                textColor,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(15),
                          color: cardColor,
                          child: SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed:
                                  _isSaving ? null : _saveStudentData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'حفظ',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

// ================================================================
// NORMAL TEXT FIELD
// لا يوجد ميكروفون هنا.
// ================================================================

class PlainTextField extends StatefulWidget {
  final String label;
  final dynamic initialValue;
  final bool isDark;
  final Color textColor;
  final Function(String) onChanged;
  final bool readOnly;

  const PlainTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.isDark,
    required this.textColor,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<PlainTextField> createState() => _PlainTextFieldState();
}

class _PlainTextFieldState extends State<PlainTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: _controller,
        readOnly: widget.readOnly,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: widget.textColor,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: widget.isDark ? Colors.black12 : Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}
