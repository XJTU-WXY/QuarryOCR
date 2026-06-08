// lib/services/ocr_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/ocr_result.dart';
import '../models/app_settings.dart';

class OcrService {
  static Future<OcrResult> recognize({
    required Uint8List imageBytes,
    required AppSettings settings,
  }) async {
    final base64Image = base64Encode(imageBytes);

    final response = await http.post(
      Uri.parse(settings.apiUrl),
      body: {
        'image_data': base64Image,
        'use_det': settings.useDet ? 'true' : 'false',
        'use_cls': settings.useCls ? 'true' : 'false',
      },
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('OCR API error: HTTP ${response.statusCode}\n${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return OcrResult.fromJson(json);
  }
}
