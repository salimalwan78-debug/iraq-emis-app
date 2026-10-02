import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
        if (mounted) {
          setState(() {
            _studentData =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('خطأ في جلب بيانات الطالب: $e');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // remove.bg website workflow
  // ============================================================

  Future<String?> _extractCsrfToken(http.Response response) async {
    String body = utf8.decode(response.bodyBytes);

    final patterns = <RegExp>[
      RegExp(
        r'<meta[^>]+name=["' r"']csrf-token["' r"'][^>]+content=["' r"']([^"' r"']+)',
        caseSensitive: false,
      ),
      RegExp(
        r'<meta[^>]+content=["' r"']([^"' r"']+)["' r"'][^>]+name=["' r"']csrf-token["' r"']',
        caseSensitive: false,
      ),
      RegExp(
        r'csrf-token[^>]+content=["' r"']([^"' r"']+)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null && match.groupCount >= 1) {
        final token = match.group(1);
        if (token != null && token.isNotEmpty) {
          return token;
        }
      }
    }

    // Some versions of remove.bg expose the token in JavaScript.
    final jsPatterns = <RegExp>[
      RegExp(
        r'csrfToken["' r"']?\s*[:=]\s*["' r"']([^"' r"']+)',
        caseSensitive: false,
      ),
      RegExp(
        r'csrf-token["' r"']?\s*[:=]\s*["' r"']([^"' r"']+)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in jsPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null && match.groupCount >= 1) {
        final token = match.group(1);
        if (token != null && token.isNotEmpty) {
          return token;
        }
      }
    }

    return null;
  }

  Map<String, String> _extractCookies(http.Response response) {
    final cookies = <String, String>{};

    final setCookieHeaders = response.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'set-cookie')
        .map((entry) => entry.value)
        .toList();

    for (final header in setCookieHeaders) {
      final parts = header.split(';');

      for (final part in parts) {
        final trimmed = part.trim();

        if (trimmed.isEmpty) continue;

        final index = trimmed.indexOf('=');

        if (index <= 0) continue;

        final name = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();

        if (name.isNotEmpty) {
          cookies[name] = value;
        }

        break;
      }
    }

    return cookies;
  }

  String _cookieHeader(Map<String, String> cookies) {
    return cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  Future<File?> _removeBackgroundUsingRemoveBgWebsite(
    File imageFile,
    void Function(String message) onProgress,
  ) async {
    final client = http.Client();

    final cookies = <String, String>{};

    try {
      // ----------------------------------------------------------
      // 1. Open the actual remove.bg/upload page.
      // ----------------------------------------------------------

      onProgress('الاتصال بموقع remove.bg...');

      final uploadPageResponse = await client.get(
        Uri.parse('https://www.remove.bg/upload'),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36',
        },
      );

      if (uploadPageResponse.statusCode < 200 ||
          uploadPageResponse.statusCode >= 400) {
        throw Exception(
          'فشل فتح remove.bg/upload: ${uploadPageResponse.statusCode}',
        );
      }

      cookies.addAll(_extractCookies(uploadPageResponse));

      String? csrfToken =
          await _extractCsrfToken(uploadPageResponse);

      if (csrfToken == null || csrfToken.isEmpty) {
        throw Exception(
          'لم يتم العثور على CSRF token في صفحة remove.bg',
        );
      }

      // ----------------------------------------------------------
      // 2. Request trust token.
      // ----------------------------------------------------------

      onProgress('تهيئة رفع الصورة...');

      final trustResponse = await client.post(
        Uri.parse('https://www.remove.bg/trust_tokens'),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Origin': 'https://www.remove.bg',
          'Referer': 'https://www.remove.bg/upload',
          'X-CSRF-Token': csrfToken,
          'X-Requested-With': 'XMLHttpRequest',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36',
          if (cookies.isNotEmpty) 'Cookie': _cookieHeader(cookies),
        },
      );

      if (trustResponse.statusCode != 200) {
        throw Exception(
          'فشل الحصول على trust token: ${trustResponse.statusCode}',
        );
      }

      cookies.addAll(_extractCookies(trustResponse));

      final trustBody =
          utf8.decode(trustResponse.bodyBytes);

      String? trustToken;

      final trustMatch = RegExp(
        r'useToken\(["' r"']([^"' r"']+)["' r"']\)',
      ).firstMatch(trustBody);

      if (trustMatch != null) {
        trustToken = trustMatch.group(1);
      }

      // Fallback in case the response format changes.
      if (trustToken == null || trustToken.isEmpty) {
        try {
          final decoded = jsonDecode(trustBody);

          if (decoded is Map<String, dynamic>) {
            final requestValue = decoded['request']?.toString();

            if (requestValue != null) {
              final fallbackMatch = RegExp(
                r'useToken\(["' r"']([^"' r"']+)["' r"']\)',
              ).firstMatch(requestValue);

              if (fallbackMatch != null) {
                trustToken = fallbackMatch.group(1);
              }
            }
          }
        } catch (_) {}
      }

      if (trustToken == null || trustToken.isEmpty) {
        throw Exception(
          'لم يتم العثور على trust_token من remove.bg',
        );
      }

      // ----------------------------------------------------------
      // 3. Upload the actual image to /images.
      // ----------------------------------------------------------

      onProgress('رفع الصورة إلى remove.bg...');

      final uploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse('https://www.remove.bg/images'),
      );

      uploadRequest.headers.addAll({
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Origin': 'https://www.remove.bg',
        'Referer': 'https://www.remove.bg/upload',
        'X-CSRF-Token': csrfToken,
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36',
        if (cookies.isNotEmpty) 'Cookie': _cookieHeader(cookies),
      });

      uploadRequest.files.add(
        await http.MultipartFile.fromPath(
          'image[original]',
          imageFile.path,
          filename: imageFile.uri.pathSegments.isNotEmpty
              ? imageFile.uri.pathSegments.last
              : 'image.jpg',
        ),
      );

      uploadRequest.fields['trust_token'] = trustToken;
      uploadRequest.fields['new_editor'] = 'true';

      final uploadResponse = await uploadRequest.send();

      final uploadBody =
          await uploadResponse.stream.bytesToString();

      if (uploadResponse.statusCode != 200) {
        throw Exception(
          'فشل رفع الصورة إلى remove.bg: '
          '${uploadResponse.statusCode}\n$uploadBody',
        );
      }

      final uploadJson =
          jsonDecode(uploadBody) as Map<String, dynamic>;

      final data = uploadJson['data'];

      if (data is! List || data.isEmpty) {
        throw Exception(
          'remove.bg لم يرجع بيانات الصورة.',
        );
      }

      final first = data.first;

      if (first is! Map<String, dynamic>) {
        throw Exception(
          'صيغة استجابة remove.bg غير متوقعة.',
        );
      }

      final meta = first['meta'];

      if (meta is! Map<String, dynamic>) {
        throw Exception(
          'لم يتم العثور على معلومات الصورة.',
        );
      }

      final imageId = meta['id']?.toString();

      if (imageId == null || imageId.isEmpty) {
        throw Exception(
          'لم يتم الحصول على image ID.',
        );
      }

      // ----------------------------------------------------------
      // 4. Poll /images/inline/{id} until preview is finished.
      // ----------------------------------------------------------

      onProgress('جاري إزالة الخلفية...');

      String? downloadUrl;

      const maxAttempts = 30;

      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        await Future.delayed(
          Duration(
            milliseconds: attempt == 0 ? 800 : 1200,
          ),
        );

        final statusResponse = await client.get(
          Uri.parse(
            'https://www.remove.bg/images/inline/$imageId',
          ),
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Referer': 'https://www.remove.bg/upload',
            'X-CSRF-Token': csrfToken,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36',
            if (cookies.isNotEmpty)
              'Cookie': _cookieHeader(cookies),
          },
        );

        if (statusResponse.statusCode != 200) {
          throw Exception(
            'فشل فحص حالة المعالجة: '
            '${statusResponse.statusCode}',
          );
        }

        cookies.addAll(_extractCookies(statusResponse));

        final statusBody =
            utf8.decode(statusResponse.bodyBytes);

        final statusJson =
            jsonDecode(statusBody) as Map<String, dynamic>;

        final statusData = statusJson['data'];

        if (statusData is! List || statusData.isEmpty) {
          continue;
        }

        final statusItem = statusData.first;

        if (statusItem is! Map<String, dynamic>) {
          continue;
        }

        final previewResult =
            statusItem['preview_result'];

        if (previewResult is! Map<String, dynamic>) {
          continue;
        }

        final state =
            previewResult['state']?.toString();

        if (state == 'finished') {
          final url =
              previewResult['url']?.toString();

          if (url != null && url.isNotEmpty) {
            downloadUrl = url;
            break;
          }
        }

        if (state == 'failed' ||
            state == 'error') {
          throw Exception(
            'remove.bg فشل في معالجة الصورة.',
          );
        }

        final nextFetch =
            previewResult['next_fetch_in'];

        if (nextFetch is num && nextFetch > 0) {
          final milliseconds =
              (nextFetch * 1.0).clamp(500, 2500).round();

          await Future.delayed(
            Duration(milliseconds: milliseconds),
          );
        }

        final percent =
            ((attempt + 1) / maxAttempts * 100)
                .clamp(1, 99)
                .round();

        onProgress(
          'جاري إزالة الخلفية... $percent%',
        );
      }

      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception(
          'انتهت مهلة انتظار معالجة الصورة.',
        );
      }

      // ----------------------------------------------------------
      // 5. Download the FREE result.
      //
      // The HAR shows that the free download is a ZIP containing:
      // color.jpg
      // alpha.png
      // shadow_color.jpg
      // shadow_alpha.png
      // ----------------------------------------------------------

      onProgress('جاري تنزيل النتيجة المجانية...');

      final downloadResponse = await client.get(
        Uri.parse(downloadUrl),
        headers: {
          'Accept': '*/*',
          'Origin': 'https://www.remove.bg',
          'Referer': 'https://www.remove.bg/',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36',
          if (cookies.isNotEmpty)
            'Cookie': _cookieHeader(cookies),
        },
      );

      if (downloadResponse.statusCode != 200) {
        throw Exception(
          'فشل تنزيل نتيجة remove.bg: '
          '${downloadResponse.statusCode}',
        );
      }

      final zipBytes = downloadResponse.bodyBytes;

      // ----------------------------------------------------------
      // 6. Extract color.jpg from the downloaded ZIP.
      // ----------------------------------------------------------

      onProgress('تجهيز الصورة الناتجة...');

      final archive = ZipDecoder().decodeBytes(
        zipBytes,
        verify: false,
      );

      ArchiveFile? colorFile;

      for (final file in archive) {
        if (!file.isFile) continue;

        final normalizedName =
            file.name.replaceAll('\\', '/').toLowerCase();

        if (normalizedName == 'color.jpg' ||
            normalizedName.endsWith('/color.jpg')) {
          colorFile = file;
          break;
        }
      }

      if (colorFile == null) {
        throw Exception(
          'لم يتم العثور على color.jpg داخل نتيجة remove.bg.',
        );
      }

      final extractedBytes =
          colorFile.content is List<int>
              ? List<int>.from(colorFile.content as List<int>)
              : <int>[];

      if (extractedBytes.isEmpty) {
        throw Exception(
          'ملف color.jpg الناتج فارغ.',
        );
      }

      final directory =
          imageFile.parent;

      final outputPath =
          '${directory.path}/emis_removebg_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final outputFile = File(outputPath);

      await outputFile.writeAsBytes(
        extractedBytes,
        flush: true,
      );

      onProgress('تمت إزالة الخلفية بنجاح.');

      return outputFile;
    } finally {
      client.close();
    }
  }

  // ============================================================
  // Image preview
  // ============================================================

  Future<void> _showImagePreviewDialog(File imageFile) async {
    File currentImage = imageFile;
    bool isProcessing = false;
    String processingMessage = 'جاري إزالة الخلفية...';

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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin:
                          const EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 4,
                      child: Image.file(
                        currentImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'يمكنك تقريب الصورة لضبطها بدقة',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 15),

                  if (isProcessing)
                    Padding(
                      padding:
                          const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 10),
                          Text(
                            processingMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () async {
                        setDialogState(() {
                          isProcessing = true;
                          processingMessage =
                              'جاري الاتصال بـ remove.bg...';
                        });

                        try {
                          final result =
                              await _removeBackgroundUsingRemoveBgWebsite(
                            currentImage,
                            (message) {
                              if (context.mounted) {
                                setDialogState(() {
                                  processingMessage =
                                      message;
                                });
                              }
                            },
                          );

                          if (result != null &&
                              context.mounted) {
                            setDialogState(() {
                              currentImage = result;
                              isProcessing = false;
                              processingMessage =
                                  'تمت إزالة الخلفية بنجاح';
                            });
                          }
                        } catch (e) {
                          debugPrint(
                            'Remove.bg error: $e',
                          );

                          if (context.mounted) {
                            setDialogState(() {
                              isProcessing = false;
                            });

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'فشل حذف الخلفية: $e',
                                ),
                                backgroundColor:
                                    Colors.red,
                                duration:
                                    const Duration(
                                  seconds: 5,
                                ),
                              ),
                            );
                          }
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
                        backgroundColor:
                            Colors.amberAccent,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () =>
                          Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                          setState(() {
                            _pickedImage =
                                currentImage;
                          });

                          Navigator.pop(
                            dialogContext,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
                    'اعتماد',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage(
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();

      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (picked != null) {
        await _showImagePreviewDialog(
          File(picked.path),
        );
      }
    } catch (e) {
      debugPrint(
        'خطأ في اختيار الصورة: $e',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر فتح الكاميرا أو معرض الصور',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteCurrentPhoto() {
    setState(() {
      _pickedImage = null;

      if (_studentData != null) {
        _studentData!['imageUrl'] = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف صورة الطالب'),
      ),
    );
  }

  Future<String?> _uploadImageToEmisServer(
    File imageFile,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://emis.moedu.gov.iq/api/student/uploadimage',
      ),
    );

    request.headers['Authorization'] =
        widget.token;

    request.headers['Accept'] =
        'application/json';

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: 'avatar.png',
      ),
    );

    try {
      final streamedResponse =
          await request.send();

      if (streamedResponse.statusCode == 200) {
        final responseData =
            await streamedResponse.stream
                .bytesToString();

        final jsonResponse =
            jsonDecode(responseData);

        return jsonResponse['imageUrl'];
      }

      debugPrint(
        'فشل رفع صورة EMIS: ${streamedResponse.statusCode}',
      );
    } catch (e) {
      debugPrint(
        'خطأ في رفع الصورة: $e',
      );
    }

    return null;
  }

  Future<void> _saveStudentData() async {
    setState(() => _isSaving = true);

    try {
      if (_pickedImage != null) {
        final newImageUrl =
            await _uploadImageToEmisServer(
          _pickedImage!,
        );

        if (newImageUrl != null) {
          _studentData!['imageUrl'] =
              newImageUrl;
        }
      }

      final url = Uri.parse(
        'https://emis.moedu.gov.iq/api/student/updatestudent',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': widget.token,
          'Content-Type':
              'application/json',
        },
        body: jsonEncode(_studentData),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'تم الحفظ بنجاح!',
              ),
              backgroundColor:
                  Colors.green,
            ),
          );

          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'فشل الحفظ! تأكد من المدخلات',
              ),
              backgroundColor:
                  Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(
        'خطأ في حفظ بيانات الطالب: $e',
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'خطأ في الاتصال',
            ),
            backgroundColor:
                Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _isSaving = false,
        );
      }
    }
  }

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

      final arabicLabel =
          _officialArabicNames[key] ?? key;

      if (value is Map<String, dynamic>) {
        widgets.add(
          Card(
            color: isDark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            margin: const EdgeInsets.only(
              bottom: 15,
              top: 10,
            ),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    arabicLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Colors.indigo.shade400,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ..._buildDynamicFields(
                    value,
                    isDark,
                    textColor,
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (value is List) {
        // تخطي القوائم المعقدة
      } else {
        widgets.add(
          PlainTextField(
            label: arabicLabel,
            initialValue: value,
            isDark: isDark,
            textColor: textColor,
            onChanged: (v) {
              dataMap[key] = v;
            },
          ),
        );
      }
    });

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder:
          (context, currentMode, child) {
        final isDark =
            currentMode == ThemeMode.dark;

        final bgColor = isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF5F7FA);

        final cardColor = isDark
            ? const Color(0xFF1E1E1E)
            : Colors.white;

        final textColor = isDark
            ? Colors.white
            : Colors.black87;

        String imgUrl =
            _studentData?['imageUrl'] ?? '';

        if (imgUrl.isNotEmpty &&
            !imgUrl.startsWith('http')) {
          imgUrl =
              'https://emis.moedu.gov.iq$imgUrl';
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
              decoration:
                  const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1A237E),
                    Color(0xFF4A90E2),
                  ],
                ),
              ),
            ),
            iconTheme:
                const IconThemeData(
              color: Colors.white,
            ),
          ),
          body: _isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : _studentData == null
                  ? const Center(
                      child:
                          Text('فشل جلب البيانات'),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding:
                                const EdgeInsets
                                    .all(15),
                            children: [
                              Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 140,
                                      height: 140,
                                      decoration:
                                          BoxDecoration(
                                        color:
                                            Colors.white,
                                        shape:
                                            BoxShape.circle,
                                        border:
                                            Border.all(
                                          color: Colors
                                              .blueAccent,
                                          width: 3,
                                        ),
                                      ),
                                      child:
                                          ClipOval(
                                        child:
                                            _pickedImage !=
                                                    null
                                                ? Image.file(
                                                    _pickedImage!,
                                                    fit: BoxFit
                                                        .cover,
                                                  )
                                                : (imgUrl
                                                        .isNotEmpty
                                                    ? Image.network(
                                                        imgUrl,
                                                        headers: {
                                                          'Authorization':
                                                              widget.token,
                                                        },
                                                        fit: BoxFit
                                                            .cover,
                                                        errorBuilder:
                                                            (c, o, s) =>
                                                                Icon(
                                                          Icons.person,
                                                          size: 80,
                                                          color: Colors.grey[400],
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons.person,
                                                        size: 80,
                                                        color:
                                                            Colors.grey[400],
                                                      )),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child:
                                          CircleAvatar(
                                        backgroundColor:
                                            Colors.blue,
                                        radius: 20,
                                        child:
                                            IconButton(
                                          icon:
                                              const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => _pickImage(
                                            ImageSource.camera,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      child:
                                          CircleAvatar(
                                        backgroundColor:
                                            Colors.green,
                                        radius: 20,
                                        child:
                                            IconButton(
                                          icon:
                                              const Icon(
                                            Icons.photo_library,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => _pickImage(
                                            ImageSource.gallery,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Center(
                                child:
                                    TextButton.icon(
                                  onPressed:
                                      _deleteCurrentPhoto,
                                  icon:
                                      const Icon(
                                    Icons
                                        .delete_forever,
                                    color:
                                        Colors.red,
                                  ),
                                  label:
                                      const Text(
                                    'حذف الصورة الحالية',
                                    style: TextStyle(
                                      color:
                                          Colors.red,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 15,
                              ),
                              ..._buildDynamicFields(
                                _studentData!,
                                isDark,
                                textColor,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets.all(
                            15,
                          ),
                          color: cardColor,
                          child: SizedBox(
                            width:
                                double.infinity,
                            height: 55,
                            child:
                                ElevatedButton(
                              onPressed:
                                  _isSaving
                                      ? null
                                      : _saveStudentData,
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    Colors.green[
                                        700],
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    12,
                                  ),
                                ),
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(
                                      color:
                                          Colors.white,
                                    )
                                  : const Text(
                                      'حفظ',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            18,
                                        color: Colors
                                            .white,
                                        fontWeight:
                                            FontWeight
                                                .bold,
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
// Normal text field
// ================================================================
//
// تم استبدال SpeechTextField بالكامل.
// لا يوجد أي اعتماد على SpeechRecognizer أو الميكروفون.
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
  State<PlainTextField> createState() =>
      _PlainTextFieldState();
}

class _PlainTextFieldState
    extends State<PlainTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        TextEditingController(
      text:
          widget.initialValue?.toString() ??
              '',
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
      padding:
          const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: widget.textColor,
          fontSize: 16,
        ),
        decoration:
            InputDecoration(
          labelText: widget.label,
          labelStyle:
              const TextStyle(
            color: Colors.grey,
          ),
          filled: true,
          fillColor:
              widget.isDark
                  ? Colors.black12
                  : Colors.grey[50],
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide:
                BorderSide(
              color:
                  Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }
    }
