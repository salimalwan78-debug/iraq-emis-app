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
        if (!mounted) return;

        setState(() {
          _studentData = jsonDecode(
            utf8.decode(response.bodyBytes),
          ) as Map<String, dynamic>;
          _isLoading = false;
        });
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
  // REMOVE.BG WEBSITE WORKFLOW
  // ============================================================

  Future<String?> _getRemoveBgTrustToken(
    http.Client client,
    Uri uploadPageUri,
    String html,
    Map<String, String> headers,
  ) async {
    String? trustToken;

    // بعض إصدارات الصفحة تضع token داخل HTML.
    final patterns = <RegExp>[
      RegExp(
        r'''<meta[^>]+name=["']csrf-token["'][^>]+content=["']([^"']+)''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<meta[^>]+content=["']([^"']+)["'][^>]+name=["']csrf-token["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''useToken\(["']([^"']+)["']\)''',
        caseSensitive: false,
      ),
      RegExp(
        r'''"trust_token"\s*:\s*"([^"]+)"''',
        caseSensitive: false,
      ),
      RegExp(
        r'''"trustToken"\s*:\s*"([^"]+)"''',
        caseSensitive: false,
      ),
      RegExp(
        r'''trust_token["']?\s*[:=]\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null && match.groupCount >= 1) {
        trustToken = match.group(1);
        if (trustToken != null && trustToken.isNotEmpty) {
          break;
        }
      }
    }

    // إذا لم يوجد token في HTML، نحاول endpoint الخاص بالموقع.
    if (trustToken == null || trustToken.isEmpty) {
      try {
        final response = await client.post(
          Uri.parse('https://www.remove.bg/trust_tokens'),
          headers: {
            ...headers,
            'Content-Type': 'application/json',
            'Referer': uploadPageUri.toString(),
            'Origin': 'https://www.remove.bg',
          },
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = response.body;

          try {
            final decoded = jsonDecode(body);

            if (decoded is Map) {
              final candidates = [
                decoded['trust_token'],
                decoded['trustToken'],
                decoded['token'],
                decoded['csrf_token'],
                decoded['csrfToken'],
              ];

              for (final candidate in candidates) {
                if (candidate != null &&
                    candidate.toString().trim().isNotEmpty) {
                  trustToken = candidate.toString();
                  break;
                }
              }

              if (trustToken == null) {
                final data = decoded['data'];

                if (data is Map) {
                  final nestedCandidates = [
                    data['trust_token'],
                    data['trustToken'],
                    data['token'],
                  ];

                  for (final candidate in nestedCandidates) {
                    if (candidate != null &&
                        candidate.toString().trim().isNotEmpty) {
                      trustToken = candidate.toString();
                      break;
                    }
                  }
                }
              }
            }
          } catch (_) {
            final match = RegExp(
              r'''["']?(?:trust_token|trustToken|token)["']?\s*[:=]\s*["']([^"']+)["']''',
              caseSensitive: false,
            ).firstMatch(body);

            if (match != null) {
              trustToken = match.group(1);
            }
          }
        }
      } catch (e) {
        debugPrint('خطأ في الحصول على trust token: $e');
      }
    }

    return trustToken;
  }

  Future<File?> _removeBackgroundUsingWebsite(File imageFile) async {
    final client = http.Client();

    try {
      const uploadPageUrl = 'https://www.remove.bg/upload';

      final baseHeaders = <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,'
            'image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'ar-IQ,ar;q=0.9,en-US;q=0.8,en;q=0.7',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

      // ----------------------------------------------------------
      // 1. فتح صفحة /upload
      // ----------------------------------------------------------

      final pageResponse = await client.get(
        Uri.parse(uploadPageUrl),
        headers: baseHeaders,
      );

      if (pageResponse.statusCode < 200 ||
          pageResponse.statusCode >= 400) {
        throw Exception(
          'فشل فتح صفحة remove.bg/upload: '
          '${pageResponse.statusCode}',
        );
      }

      final pageHtml = utf8.decode(
        pageResponse.bodyBytes,
        allowMalformed: true,
      );

      final trustToken = await _getRemoveBgTrustToken(
        client,
        Uri.parse(uploadPageUrl),
        pageHtml,
        baseHeaders,
      );

      debugPrint(
        'remove.bg trust token: '
        '${trustToken == null ? "غير موجود" : "تم الحصول عليه"}',
      );

      // ----------------------------------------------------------
      // 2. إرسال الصورة إلى /images
      // ----------------------------------------------------------

      final imageRequest = http.MultipartRequest(
        'POST',
        Uri.parse('https://www.remove.bg/images'),
      );

      imageRequest.headers.addAll({
        ...baseHeaders,
        'Accept': 'application/json, text/plain, */*',
        'Origin': 'https://www.remove.bg',
        'Referer': uploadPageUrl,
      });

      if (trustToken != null && trustToken.isNotEmpty) {
        imageRequest.headers['X-CSRF-Token'] = trustToken;
        imageRequest.fields['trust_token'] = trustToken;
      }

      imageRequest.files.add(
        await http.MultipartFile.fromPath(
          'image_file',
          imageFile.path,
          filename: 'student.jpg',
        ),
      );

      final uploadResponse = await imageRequest.send();
      final uploadBytes = await uploadResponse.stream.toBytes();

      final uploadBody = utf8.decode(
        uploadBytes,
        allowMalformed: true,
      );

      debugPrint(
        'remove.bg /images status: ${uploadResponse.statusCode}',
      );
      debugPrint(
        'remove.bg /images response: '
        '${uploadBody.length > 1000 ? uploadBody.substring(0, 1000) : uploadBody}',
      );

      if (uploadResponse.statusCode < 200 ||
          uploadResponse.statusCode >= 300) {
        throw Exception(
          'فشل رفع الصورة إلى remove.bg: '
          '${uploadResponse.statusCode}',
        );
      }

      // ----------------------------------------------------------
      // 3. استخراج image id
      // ----------------------------------------------------------

      String? imageId;

      try {
        final decoded = jsonDecode(uploadBody);

        if (decoded is Map) {
          final candidates = [
            decoded['id'],
            decoded['image_id'],
            decoded['imageId'],
          ];

          for (final candidate in candidates) {
            if (candidate != null && candidate.toString().isNotEmpty) {
              imageId = candidate.toString();
              break;
            }
          }

          if (imageId == null && decoded['image'] is Map) {
            final imageObject = decoded['image'] as Map;

            final candidates = [
              imageObject['id'],
              imageObject['image_id'],
              imageObject['imageId'],
            ];

            for (final candidate in candidates) {
              if (candidate != null &&
                  candidate.toString().isNotEmpty) {
                imageId = candidate.toString();
                break;
              }
            }
          }
        }
      } catch (_) {
        // إذا لم تكن الاستجابة JSON، نحاول regex أدناه.
      }

      imageId ??= RegExp(
        r'''"(?:id|image_id|imageId)"\s*:\s*"([^"]+)"''',
        caseSensitive: false,
      ).firstMatch(uploadBody)?.group(1);

      imageId ??= RegExp(
        r'''(?:image_id|imageId|image)["']?\s*[:=]\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(uploadBody)?.group(1);

      if (imageId == null || imageId.isEmpty) {
        throw Exception(
          'لم يتم العثور على image ID في استجابة remove.bg',
        );
      }

      debugPrint('remove.bg image ID: $imageId');

      // ----------------------------------------------------------
      // 4. Polling على /images/inline/{image_id}
      // ----------------------------------------------------------

      Uri? downloadUri;

      for (int attempt = 0; attempt < 30; attempt++) {
        await Future.delayed(
          Duration(seconds: attempt == 0 ? 1 : 2),
        );

        final inlineUri = Uri.parse(
          'https://www.remove.bg/images/inline/$imageId',
        );

        final inlineResponse = await client.get(
          inlineUri,
          headers: {
            ...baseHeaders,
            'Accept': 'application/json, text/plain, */*',
            'Referer': uploadPageUrl,
            'Origin': 'https://www.remove.bg',
          },
        );

        final inlineBody = utf8.decode(
          inlineResponse.bodyBytes,
          allowMalformed: true,
        );

        debugPrint(
          'remove.bg polling ${attempt + 1}/30 '
          'status=${inlineResponse.statusCode}',
        );

        if (inlineResponse.statusCode < 200 ||
            inlineResponse.statusCode >= 300) {
          continue;
        }

        String? state;
        String? resultUrl;

        try {
          final decoded = jsonDecode(inlineBody);

          if (decoded is Map) {
            state = decoded['state']?.toString();

            resultUrl = _findStringRecursively(
              decoded,
              const [
                'url',
                'download_url',
                'downloadUrl',
                'preview_url',
                'previewUrl',
              ],
            );

            if (state == null && decoded['preview_result'] is Map) {
              final preview = decoded['preview_result'] as Map;
              state = preview['state']?.toString();

              resultUrl ??= _findStringRecursively(
                preview,
                const [
                  'url',
                  'download_url',
                  'downloadUrl',
                  'preview_url',
                  'previewUrl',
                ],
              );
            }
          }
        } catch (_) {
          // نحاول regex في حالة الرد ليس JSON.
        }

        state ??= RegExp(
          r'''"state"\s*:\s*"([^"]+)"''',
          caseSensitive: false,
        ).firstMatch(inlineBody)?.group(1);

        resultUrl ??= RegExp(
          r'''"(?:url|download_url|downloadUrl|preview_url|previewUrl)"\s*:\s*"([^"]+)"''',
          caseSensitive: false,
        ).firstMatch(inlineBody)?.group(1);

        if (state != null) {
          debugPrint('remove.bg processing state: $state');
        }

        if (resultUrl != null && resultUrl.isNotEmpty) {
          resultUrl = _decodeJsonUrl(resultUrl);

          if (resultUrl.startsWith('http://') ||
              resultUrl.startsWith('https://')) {
            downloadUri = Uri.tryParse(resultUrl);
          }
        }

        if (state?.toLowerCase() == 'finished' &&
            downloadUri != null) {
          break;
        }

        if (downloadUri != null) {
          break;
        }

        if (state?.toLowerCase() == 'failed' ||
            state?.toLowerCase() == 'error') {
          throw Exception(
            'remove.bg فشل في معالجة الصورة',
          );
        }
      }

      if (downloadUri == null) {
        throw Exception(
          'انتهى وقت انتظار معالجة الصورة من remove.bg',
        );
      }

      debugPrint(
        'remove.bg download URL: $downloadUri',
      );

      // ----------------------------------------------------------
      // 5. تنزيل نتيجة Free
      // ----------------------------------------------------------

      final resultResponse = await client.get(
        downloadUri,
        headers: {
          ...baseHeaders,
          'Accept': '*/*',
          'Referer': uploadPageUrl,
        },
      );

      if (resultResponse.statusCode < 200 ||
          resultResponse.statusCode >= 300) {
        throw Exception(
          'فشل تنزيل نتيجة remove.bg: '
          '${resultResponse.statusCode}',
        );
      }

      final resultBytes = resultResponse.bodyBytes;

      // ----------------------------------------------------------
      // 6. إذا كانت النتيجة ZIP نستخرج color.jpg
      // ----------------------------------------------------------

      List<int>? finalImageBytes;

      final isZip = resultBytes.length >= 4 &&
          resultBytes[0] == 0x50 &&
          resultBytes[1] == 0x4B &&
          resultBytes[2] == 0x03 &&
          resultBytes[3] == 0x04;

      if (isZip) {
        final archive = ZipDecoder().decodeBytes(
          resultBytes,
          verify: false,
        );

        // الأفضلية لـ color.jpg لأنها نتيجة Free الظاهرة في
        // سير عمل موقع remove.bg.
        ArchiveFile? colorFile;

        for (final file in archive) {
          final name = file.name.toLowerCase();

          if (name == 'color.jpg' ||
              name.endsWith('/color.jpg') ||
              name == 'color.jpeg' ||
              name.endsWith('/color.jpeg')) {
            colorFile = file;
            break;
          }
        }

        // احتياط إذا تغير اسم الملف.
        colorFile ??= archive.firstWhere(
          (file) {
            final name = file.name.toLowerCase();

            return file.isFile &&
                (name.endsWith('.jpg') ||
                    name.endsWith('.jpeg') ||
                    name.endsWith('.png'));
          },
          orElse: () => throw Exception(
            'لم يتم العثور على صورة داخل نتيجة remove.bg',
          ),
        );

        finalImageBytes = colorFile.readBytes();
      } else {
        // أحياناً قد يرجع الموقع الصورة مباشرة.
        finalImageBytes = resultBytes;
      }

      if (finalImageBytes == null || finalImageBytes.isEmpty) {
        throw Exception(
          'ملف الصورة الناتج من remove.bg فارغ',
        );
      }

      final outputPath =
          '${imageFile.path}_removebg_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final outputFile = File(outputPath);

      await outputFile.writeAsBytes(
        finalImageBytes,
        flush: true,
      );

      return outputFile;
    } finally {
      client.close();
    }
  }

  String? _findStringRecursively(
    dynamic object,
    List<String> wantedKeys,
  ) {
    if (object is Map) {
      for (final key in wantedKeys) {
        final value = object[key];

        if (value != null &&
            value is String &&
            value.trim().isNotEmpty) {
          return value;
        }
      }

      for (final value in object.values) {
        final result = _findStringRecursively(
          value,
          wantedKeys,
        );

        if (result != null) {
          return result;
        }
      }
    }

    if (object is List) {
      for (final value in object) {
        final result = _findStringRecursively(
          value,
          wantedKeys,
        );

        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }

  String _decodeJsonUrl(String value) {
    var result = value;

    try {
      result = jsonDecode('"$value"') as String;
    } catch (_) {
      result = value
          .replaceAll(r'\/', '/')
          .replaceAll(r'\u0026', '&');
    }

    return result;
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
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
                        border: Border.all(
                          color: Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          panEnabled: true,
                          boundaryMargin:
                              const EdgeInsets.all(20),
                          minScale: 0.5,
                          maxScale: 4,
                          child: Image.file(
                            currentImage,
                            fit: BoxFit.contain,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
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
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 15),

                    if (isProcessing)
                      const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'جاري رفع الصورة ومعالجة الخلفية...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'يرجى الانتظار',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            setDialogState(
                              () => isProcessing = true,
                            );

                            try {
                              final processed =
                                  await _removeBackgroundUsingWebsite(
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

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تمت إزالة الخلفية بنجاح',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              debugPrint(
                                'Remove.bg error: $e',
                              );

                              if (!mounted) return;

                              setDialogState(
                                () => isProcessing = false,
                              );

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تعذر إزالة الخلفية: $e',
                                  ),
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
                            backgroundColor:
                                Colors.amberAccent,
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
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
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                          setState(() {
                            _pickedImage = currentImage;
                          });

                          Navigator.pop(dialogContext);
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
        await _showImagePreviewDialog(
          File(picked.path),
        );
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

  // ============================================================
  // UPLOAD IMAGE TO EMIS
  // ============================================================

  Future<String?> _uploadImageToEmisServer(
    File imageFile,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://emis.moedu.gov.iq/api/student/uploadimage',
      ),
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

      debugPrint(
        'رفع صورة EMIS: ${streamedResponse.statusCode}',
      );

      if (streamedResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(responseData);

        if (jsonResponse is Map) {
          return jsonResponse['imageUrl']?.toString();
        }
      }

      debugPrint(
        'استجابة رفع الصورة: $responseData',
      );
    } catch (e) {
      debugPrint(
        'خطأ في رفع الصورة إلى EMIS: $e',
      );
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
            await _uploadImageToEmisServer(
          _pickedImage!,
        );

        if (newImageUrl != null &&
            newImageUrl.isNotEmpty) {
          _studentData!['imageUrl'] = newImageUrl;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تعذر رفع صورة الطالب',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }

          return;
        }
      }

      final url = Uri.parse(
        'https://emis.moedu.gov.iq/api/student/updatestudent',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': widget.token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(_studentData),
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } else {
        debugPrint(
          'Update student status: ${response.statusCode}',
        );
        debugPrint(
          'Update student response: ${response.body}',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'فشل الحفظ! تأكد من المدخلات',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'خطأ في حفظ بيانات الطالب: $e',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في الاتصال'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (value is List) {
        // القوائم المعقدة لا تعرض كحقول نصية.
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder: (
        context,
        currentMode,
        child,
      ) {
        final isDark =
            currentMode == ThemeMode.dark;

        final bgColor = isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF5F7FA);

        final cardColor = isDark
            ? const Color(0xFF1E1E1E)
            : Colors.white;

        final textColor =
            isDark ? Colors.white : Colors.black87;

        String imgUrl =
            _studentData?['imageUrl']?.toString() ?? '';

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
                  child: CircularProgressIndicator(),
                )
              : _studentData == null
                  ? const Center(
                      child: Text(
                        'فشل جلب البيانات',
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding:
                                const EdgeInsets.all(15),
                            children: [
                              Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 140,
                                      height: 140,
                                      decoration:
                                          BoxDecoration(
                                        color: Colors.white,
                                        shape:
                                            BoxShape.circle,
                                        border:
                                            Border.all(
                                          color: Colors
                                              .blueAccent,
                                          width: 3,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child:
                                            _pickedImage !=
                                                    null
                                                ? Image.file(
                                                    _pickedImage!,
                                                    fit: BoxFit
                                                        .cover,
                                                  )
                                                : imgUrl
                                                        .isNotEmpty
                                                    ? Image
                                                        .network(
                                                        imgUrl,
                                                        headers: {
                                                          'Authorization':
                                                              widget.token,
                                                        },
                                                        fit: BoxFit
                                                            .cover,
                                                        errorBuilder:
                                                            (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return Icon(
                                                            Icons
                                                                .person,
                                                            size:
                                                                80,
                                                            color: Colors
                                                                .grey[400],
                                                          );
                                                        },
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .person,
                                                        size: 80,
                                                        color: Colors
                                                            .grey[400],
                                                      ),
                                      ),
                                    ),

                                    // الكاميرا
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
                                            Icons
                                                .camera_alt,
                                            color: Colors
                                                .white,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _pickImage(
                                            ImageSource
                                                .camera,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // المعرض
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
                                            Icons
                                                .photo_library,
                                            color: Colors
                                                .white,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _pickImage(
                                            ImageSource
                                                .gallery,
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
                                  icon: const Icon(
                                    Icons
                                        .delete_forever,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'حذف الصورة الحالية',
                                    style: TextStyle(
                                      color: Colors.red,
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
                              const EdgeInsets.all(15),
                          color: cardColor,
                          child: SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isSaving
                                  ? null
                                  : _saveStudentData,
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.green[700],
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    12,
                                  ),
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
                                        fontWeight:
                                            FontWeight.bold,
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
  State<PlainTextField> createState() =>
      _PlainTextFieldState();
}

class _PlainTextFieldState
    extends State<PlainTextField> {
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
      padding:
          const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: widget.textColor,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle:
              const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: widget.isDark
              ? Colors.black12
              : Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }
}
