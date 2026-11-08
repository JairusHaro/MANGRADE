import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/mango_view.dart';

/// The model's result for one photo (front, back or top).
class MangoViewPrediction {
  final String grade;
  final double confidence;
  final Map<String, double> probabilities;

  const MangoViewPrediction({
    required this.grade,
    required this.confidence,
    required this.probabilities,
  });

  static MangoViewPrediction? fromJson(Object? json) {
    if (json is! Map) return null;
    final grade = json['grade'];
    final confidence = json['confidence'];
    if (grade is! String || confidence is! num) return null;
    return MangoViewPrediction(
      grade: grade,
      confidence: confidence.toDouble(),
      probabilities: _parseProbabilities(json['probabilities']) ?? const {},
    );
  }
}

class MangoApiResponse {
  final bool predictionAvailable;
  final String message;
  final String? predictedGrade;
  final double? confidence;
  final int? imageWidth;
  final int? imageHeight;

  /// Final probability for each grade, in the backend's grade order.
  final Map<String, double>? probabilities;

  /// Per-photo results from /predict-multiview, keyed 'front', 'back', 'top'.
  final Map<String, MangoViewPrediction>? viewPredictions;

  /// True when the front, back and top photos all gave the same grade.
  final bool? viewsAgree;

  /// How the backend combined the three photos (provisional method note).
  final String? aggregationNote;

  /// What the confidence value means.
  final String? confidenceNote;

  const MangoApiResponse({
    required this.predictionAvailable,
    required this.message,
    this.predictedGrade,
    this.confidence,
    this.imageWidth,
    this.imageHeight,
    this.probabilities,
    this.viewPredictions,
    this.viewsAgree,
    this.aggregationNote,
    this.confidenceNote,
  });

  /// Reads a successful /predict or /predict-multiview response.
  ///
  /// Fields added by newer backends are optional, so older responses
  /// (without them) still parse.
  factory MangoApiResponse.fromJson(Map<String, dynamic> data) {
    final views = data['views'];
    Map<String, MangoViewPrediction>? viewPredictions;
    if (views is Map) {
      final parsed = <String, MangoViewPrediction>{};
      for (final view in MangoView.values) {
        final entry = views[view.apiField];
        final prediction =
            entry is Map ? MangoViewPrediction.fromJson(entry['prediction']) : null;
        if (prediction != null) parsed[view.apiField] = prediction;
      }
      if (parsed.isNotEmpty) viewPredictions = parsed;
    }

    final aggregation = data['aggregation'];

    return MangoApiResponse(
      predictionAvailable: data['prediction_is_real'] == true &&
          data['predicted_grade'] is String &&
          data['confidence'] is num,
      message: data['message'] as String? ?? 'The server received the image.',
      predictedGrade: data['predicted_grade'] as String?,
      confidence: (data['confidence'] as num?)?.toDouble(),
      imageWidth: data['width'] as int?,
      imageHeight: data['height'] as int?,
      probabilities: _parseProbabilities(data['probabilities']),
      viewPredictions: viewPredictions,
      viewsAgree: data['views_agree'] as bool?,
      aggregationNote: aggregation is Map ? aggregation['note'] as String? : null,
      confidenceNote: data['confidence_note'] as String?,
    );
  }
}

Map<String, double>? _parseProbabilities(Object? json) {
  if (json is! Map) return null;
  final result = <String, double>{};
  json.forEach((key, value) {
    if (key is String && value is num) result[key] = value.toDouble();
  });
  return result;
}

class MangGradeApi {
  MangGradeApi._();

  // Backend address. Set it at build/run time without editing code:
  //   flutter run --dart-define=MANGGRADE_API_URL=http://192.168.1.20:8000
  // Default (no --dart-define): Android emulator -> your computer (10.0.2.2).
  // Physical phone: use your computer's LAN IP address.
  // Flutter desktop or web on the same computer: use http://127.0.0.1:8000.
  static const String baseUrl = String.fromEnvironment(
    'MANGGRADE_API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

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
      // The timeout covers the whole exchange: upload, grading and the
      // response body, not only the time until the first response byte.
      final response = await request
          .send()
          .then(http.Response.fromStream)
          .timeout(timeout);
      final Object? decoded;

      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw Exception('The server returned an unreadable response.');
      }
      if (decoded is! Map<String, dynamic>) {
        throw Exception('The server returned an unreadable response.');
      }
      final data = decoded;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = data['detail'];
        throw Exception(
          detail is String
              ? detail
              : 'Image upload failed '
                  '(HTTP ${response.statusCode}).',
        );
      }

      return MangoApiResponse.fromJson(data);
    } on TimeoutException {
      throw Exception(
        'The MangGrade backend took too long to respond. '
        'Check your connection and try again.',
      );
    } on SocketException {
      throw Exception(
        'Could not reach the MangGrade backend at $baseUrl. '
        'Check that the server is running and the address is correct.',
      );
    } on http.ClientException {
      throw Exception(
        'Could not reach the MangGrade backend at $baseUrl. '
        'Check that the server is running and the address is correct.',
      );
    } on HttpException {
      throw Exception('The image upload failed.');
    } on FormatException {
      throw Exception('The server returned an invalid response.');
    }
  }
}
