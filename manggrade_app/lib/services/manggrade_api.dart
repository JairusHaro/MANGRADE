import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/mango_view.dart';

class MangoApiResponse {
  final bool predictionAvailable;
  final String message;
  final String? predictedGrade;
  final double? confidence;
  final int? imageWidth;
  final int? imageHeight;

  const MangoApiResponse({
    required this.predictionAvailable,
    required this.message,
    this.predictedGrade,
    this.confidence,
    this.imageWidth,
    this.imageHeight,
  });
}

class MangGradeApi {
  MangGradeApi._();

  // Android emulator: use 10.0.2.2.
  // Physical phone: replace with your computer's LAN IP address.
  // Flutter desktop or web on the same computer: use 127.0.0.1.
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Single-image upload to /predict (kept for compatibility).
  static Future<MangoApiResponse> analyzeImage(String imagePath) async {
    final uri = Uri.parse('$baseUrl/predict');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imagePath));

    return _send(request);
  }

  /// Uploads the front, back and top photos of one mango to
  /// /predict-multiview in a single request.
  static Future<MangoApiResponse> analyzeViews(
    Map<MangoView, String> imagePaths,
  ) async {
    final missing = MangoView.values
        .where((view) => imagePaths[view] == null)
        .map((view) => view.label)
        .toList();
    if (missing.isNotEmpty) {
      throw Exception('Missing photo: ${missing.join(', ')}.');
    }

    final uri = Uri.parse('$baseUrl/predict-multiview');
    final request = http.MultipartRequest('POST', uri);

    for (final view in MangoView.values) {
      request.files.add(
        await http.MultipartFile.fromPath(view.apiField, imagePaths[view]!),
      );
    }

    // Three photos take longer to upload than one.
    return _send(request, timeout: const Duration(seconds: 60));
  }

  static Future<MangoApiResponse> _send(
    http.MultipartRequest request, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      final Map<String, dynamic> data;

      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } on FormatException {
        throw Exception('The server returned an unreadable response.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = data['detail'];
        throw Exception(
          detail is String
              ? detail
              : 'Image upload failed '
                  '(HTTP ${response.statusCode}).',
        );
      }

      return MangoApiResponse(
        predictionAvailable: data['prediction_is_real'] == true &&
            data['predicted_grade'] is String &&
            data['confidence'] is num,
        message: data['message'] as String? ?? 'The server received the image.',
        predictedGrade: data['predicted_grade'] as String?,
        confidence: (data['confidence'] as num?)?.toDouble(),
        imageWidth: data['width'] as int?,
        imageHeight: data['height'] as int?,
      );
    } on SocketException {
      throw Exception(
        'Could not reach the MangGrade backend. '
        'Check that the server is running and the address is correct.',
      );
    } on HttpException {
      throw Exception('The image upload failed.');
    } on FormatException {
      throw Exception('The server returned an invalid response.');
    }
  }
}
