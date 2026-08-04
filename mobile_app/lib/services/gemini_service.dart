import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/diagnosis_result.dart';

class GeminiServiceException implements Exception {
  final String message;
  GeminiServiceException(this.message);
  @override
  String toString() => message;
}

/// Wraps the Gemini Vision API for plant disease diagnosis, and a
/// separate, domain-restricted chat session for the plant-care
/// chatbot described in the project report.
class GeminiService {
  final String apiKey;
  late final GenerativeModel _visionModel;
  late final GenerativeModel _chatModel;
  ChatSession? _chatSession;

  // 'gemini-flash-lite-latest' is Google's rolling alias for the
  // current lite flash model, not a pinned version -- deliberately
  // chosen after 'gemini-1.5-flash' turned out to be already
  // deprecated (confirmed by a live API call returning 404) and even
  // 'gemini-2.5-flash'/'gemini-2.0-flash' were unavailable to this
  // key (deprecated-for-new-users or zero free-tier quota,
  // respectively). The alias avoids repeating this exact breakage the
  // next time a dated model name gets sunset.
  GeminiService({required this.apiKey}) {
    _visionModel = GenerativeModel(model: 'gemini-flash-lite-latest', apiKey: apiKey);
    _chatModel = GenerativeModel(
      model: 'gemini-flash-lite-latest',
      apiKey: apiKey,
      systemInstruction: Content.text(
        'You are a plant-care assistant for a home gardening app. Only '
        'answer questions about plant care, soil, irrigation, pests, and '
        'crop diseases. If asked about anything unrelated, politely say '
        "that's outside what you can help with here and redirect back to "
        'plant care. Keep answers concise and practical.',
      ),
    );
  }

  Future<DiagnosisResult> diagnoseLeafImage(Uint8List imageBytes, {String mimeType = 'image/jpeg'}) async {
    const prompt = '''
Analyze this plant leaf photo for disease. Respond ONLY with compact JSON,
no markdown fences, in exactly this shape:
{
  "diseaseName": "string, e.g. Early Blight, or Healthy if no disease visible",
  "confidencePercent": number from 0-100,
  "symptomDescription": "1-3 sentences describing what's visible in the image",
  "correctiveMeasures": "1-4 short actionable steps, separated by newlines"
}
''';

    final content = [
      Content.multi([TextPart(prompt), DataPart(mimeType, imageBytes)]),
    ];

    final response = await _visionModel.generateContent(content);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw GeminiServiceException('Gemini returned an empty response');
    }

    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(_stripMarkdownFences(text)) as Map<String, dynamic>;
    } on FormatException {
      throw GeminiServiceException('Could not parse Gemini response as JSON: $text');
    }

    return DiagnosisResult(
      source: DiagnosisSource.geminiVision,
      diseaseName: parsed['diseaseName'] as String? ?? 'Unknown',
      confidence: ((parsed['confidencePercent'] as num?)?.toDouble() ?? 0) / 100.0,
      symptomDescription: parsed['symptomDescription'] as String? ?? '',
      correctiveMeasures: parsed['correctiveMeasures'] as String? ?? '',
      timestamp: DateTime.now(),
    );
  }

  Future<String> sendChatMessage(String message) async {
    _chatSession ??= _chatModel.startChat();
    final response = await _chatSession!.sendMessage(Content.text(message));
    return response.text ?? "Sorry, I didn't catch that -- could you rephrase?";
  }

  String _stripMarkdownFences(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.substring(t.indexOf('\n') + 1);
      if (t.endsWith('```')) {
        t = t.substring(0, t.lastIndexOf('```'));
      }
    }
    return t.trim();
  }
}
