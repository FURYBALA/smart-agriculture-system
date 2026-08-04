import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get irrigationNodeHost => dotenv.env['IRRIGATION_NODE_HOST'] ?? '192.168.1.50';
  static String get visionNodeHost => dotenv.env['VISION_NODE_HOST'] ?? '192.168.1.51';

  static bool get hasGeminiKey =>
      geminiApiKey.isNotEmpty && geminiApiKey != 'your-gemini-api-key-here';
}
