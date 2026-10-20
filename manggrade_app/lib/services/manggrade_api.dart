import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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

  static Future<MangoApiResponse> analyzeImage(String imagePath) async {
    final uri = Uri.parse('$baseUrl/predict');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imagePath));

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );
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
