import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;

import 'config/app_config.dart';
import 'services/esp32_service.dart';
import 'services/gemini_service.dart';
import 'services/history_database.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // sqflite has no platform channels on web; HistoryDatabase's plain
  // openDatabase()/getDatabasesPath() calls route through whichever
  // factory is registered here, so mobile (unset -- default platform
  // channel factory) is unaffected by this branch.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  await dotenv.load(fileName: '.env');
  runApp(const PlantDoctorApp());
}

class PlantDoctorApp extends StatelessWidget {
  const PlantDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Esp32Service>(
          create: (_) => Esp32Service(
            irrigationHost: AppConfig.irrigationNodeHost,
            visionHost: AppConfig.visionNodeHost,
          ),
        ),
        Provider<GeminiService?>(
          create: (_) => AppConfig.hasGeminiKey
              ? GeminiService(apiKey: AppConfig.geminiApiKey)
              : null,
        ),
        Provider<HistoryDatabase>(create: (_) => HistoryDatabase()),
      ],
      child: MaterialApp(
        title: 'Plant Doctor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        home: const HomeShell(),
      ),
    );
  }
}
