import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
    'notes': 'ملاحظات',
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
        setState(() {
          _studentData = jsonDecode(
            utf8.decode(response.bodyBytes),
          ) as Map<String, dynamic>;
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
  // LOCAL BACKGROUND REMOVAL - BiRefNet Lite 512 ONNX
  // ============================================================
  //
  // The model is bundled locally with the application:
  //   assets/models/birefnet_lite_512.onnx
  //
  // Input:
  //   RGB, 512x512, NCHW
  //   ImageNet normalization
  //
  // Output:
  //   Single-channel logits, 512x512.
  //   Sigmoid is applied here and the result becomes the alpha mask.
  //
  // This implementation does NOT contact remove.bg or any other
  // background-removal service.

  static const String _birefNetModelAsset =
      'assets/models/birefnet_lite_512.onnx';

  OrtSession? _birefNetSession;
  OrtSessionOptions? _birefNetSessionOptions;

  Future<void> _initializeBiRefNet() async {
    if (_birefNetSession != null) return;

    OrtEnv.instance.init();

    _birefNetSessionOptions = OrtSessionOptions();

    final modelData = await rootBundle.load(_birefNetModelAsset);
    final modelBytes = modelData.buffer.asUint8List(
      modelData.offsetInBytes,
      modelData.lengthInBytes,
    );

    _birefNetSession = OrtSession.fromBuffer(
      modelBytes,
      _birefNetSessionOptions!,
    );

    debugPrint(
      'BiRefNet Lite loaded. '
      'inputs=${_birefNetSession!.inputNames} '
      'outputs=${_birefNetSession!.outputNames}',
    );
  }

  List<double> _flattenOrtValue(dynamic value) {
    final result = <double>[];

    void walk(dynamic item) {
      if (item is List) {
        for (final child in item) {
          walk(child);
        }
      } else if (item is num) {
        result.add(item.toDouble());
      }
    }

    walk(value);
    return result;
  }

  double _sigmoid(double value) {
    if (value >= 0) {
      final z = math.exp(-value);
      return 1.0 / (1.0 + z);
    }

    final z = math.exp(value);
    return z / (1.0 + z);
  }

  Future<File?> _removeBackgroundUsingBiRefNet(File imageFile) async {
    final stopwatch = Stopwatch()..start();

    try {
      await _initializeBiRefNet();

      final session = _birefNetSession;
      if (session == null) {
        throw Exception('تعذر تهيئة نموذج BiRefNet Lite 512');
      }

      final sourceBytes = await imageFile.readAsBytes();
      var sourceImage = img.decodeImage(sourceBytes);

      if (sourceImage == null) {
        throw Exception('تعذر قراءة الصورة');
      }

      // Respect the original camera/gallery orientation before inference.
      sourceImage = img.bakeOrientation(sourceImage);

      final originalWidth = sourceImage.width;
      final originalHeight = sourceImage.height;

      if (originalWidth <= 0 || originalHeight <= 0) {
        throw Exception('أبعاد الصورة غير صحيحة');
      }

      // BiRefNet Lite 512 expects a square 512x512 RGB input.
      final resized = img.copyResize(
        sourceImage,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.linear,
      );

      const mean = <double>[0.485, 0.456, 0.406];
      const std = <double>[0.229, 0.224, 0.225];

      // NCHW: [1, 3, 512, 512].
      final inputData = Float32List(1 * 3 * 512 * 512);
      final planeSize = 512 * 512;

      for (var y = 0; y < 512; y++) {
        for (var x = 0; x < 512; x++) {
          final pixel = resized.getPixel(x, y);

          final r = pixel.r.toDouble() / 255.0;
          final g = pixel.g.toDouble() / 255.0;
          final b = pixel.b.toDouble() / 255.0;

          final offset = y * 512 + x;

          inputData[offset] = (r - mean[0]) / std[0];
          inputData[planeSize + offset] = (g - mean[1]) / std[1];
          inputData[(2 * planeSize) + offset] =
              (b - mean[2]) / std[2];
        }
      }

      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputData,
        const [1, 3, 512, 512],
      );

      final runOptions = OrtRunOptions();

      try {
        final inputName = session.inputNames.contains('input_image')
            ? 'input_image'
            : session.inputNames.first;

        final outputName = session.outputNames.contains('logits')
            ? 'logits'
            : session.outputNames.first;

        debugPrint(
          'BiRefNet inference: input=$inputName output=$outputName',
        );

        final outputs = await session.runAsync(
          runOptions,
          {inputName: inputTensor},
          [outputName],
        );

        if (outputs == null || outputs.isEmpty || outputs.first == null) {
          throw Exception('لم يرجع نموذج BiRefNet أي نتيجة');
        }

        final output = outputs.first!;

        final logits = _flattenOrtValue(output.value);

        if (logits.length < 512 * 512) {
          throw Exception(
            'حجم خرج BiRefNet غير متوقع: ${logits.length}',
          );
        }

        // Convert logits -> alpha mask.
        final mask512 = img.Image(
          width: 512,
          height: 512,
          numChannels: 1,
        );

        for (var y = 0; y < 512; y++) {
          for (var x = 0; x < 512; x++) {
            final index = y * 512 + x;
            final alpha = (_sigmoid(logits[index]) * 255.0)
                .round()
                .clamp(0, 255);

            mask512.setPixelRgba(
              x,
              y,
              alpha,
              alpha,
              alpha,
              255,
            );
          }
        }

        // Restore the mask to the original photo dimensions using
        // bilinear interpolation, as recommended for this model.
        final fullMask = img.copyResize(
          mask512,
          width: originalWidth,
          height: originalHeight,
          interpolation: img.Interpolation.linear,
        );

        // Preserve the original RGB pixels and replace only alpha.
        final result = img.Image(
          width: originalWidth,
          height: originalHeight,
          numChannels: 4,
        );

        for (var y = 0; y < originalHeight; y++) {
          for (var x = 0; x < originalWidth; x++) {
            final sourcePixel = sourceImage.getPixel(x, y);
            final maskPixel = fullMask.getPixel(x, y);

            result.setPixelRgba(
              x,
              y,
              sourcePixel.r,
              sourcePixel.g,
              sourcePixel.b,
              maskPixel.r,
            );
          }
        }

        final outputPath =
            '${imageFile.path}_birefnet_${DateTime.now().millisecondsSinceEpoch}.png';

        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(
          img.encodePng(result, level: 6),
          flush: true,
        );

        debugPrint(
          'BiRefNet Lite completed in '
          '${stopwatch.elapsedMilliseconds} ms: $outputPath',
        );

        return outputFile;
      } finally {
        inputTensor.release();
        runOptions.release();
      }
    } catch (e, stackTrace) {
      debugPrint('BiRefNet Lite error: $e');
      debugPrint('$stackTrace');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  @override
  void dispose() {
    _birefNetSession?.release();
    _birefNetSession = null;

    _birefNetSessionOptions?.release();
    _birefNetSessionOptions = null;

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
                            'جاري معالجة الصورة وإزالة الخلفية محليًا...',
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
                                  await _removeBackgroundUsingBiRefNet(
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
                              debugPrint('BiRefNet Lite error: $e');
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
        filename: 'avatar.jpg',
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
    Color textColor,
  ) {
    final List<Widget> widgets = [];

    dataMap.forEach((key, value) {
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
                  ..._buildDynamicFields(value, isDark, textColor),
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
            initialValue: value,
            isDark: isDark,
            textColor: textColor,
            onChanged: (v) => dataMap[key] = v,
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

  const PlainTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.isDark,
    required this.textColor,
    required this.onChanged,
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
