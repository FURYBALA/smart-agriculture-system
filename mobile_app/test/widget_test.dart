// Smoke test: the app shell builds and shows all five bottom-nav
// destinations, without needing a real .env or network access.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:plant_doctor/screens/home_shell.dart';
import 'package:plant_doctor/services/esp32_service.dart';
import 'package:plant_doctor/services/gemini_service.dart';
import 'package:plant_doctor/services/history_database.dart';

void main() {
  // HomeShell keeps all six screens alive (IndexedStack, so tab state
  // like scroll position and chat history isn't lost when switching
  // tabs) -- which means every screen builds up front, including ones
  // that read AppConfig/dotenv and sqflite. main() normally loads .env
  // before runApp, and a real device provides sqflite's platform
  // channel; tests need both set up explicitly.
  setUpAll(() {
    dotenv.testLoad(fileInput: 'IRRIGATION_NODE_HOST=127.0.0.1\nVISION_NODE_HOST=127.0.0.1');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Home shell renders all navigation destinations', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Esp32Service>(
            create: (_) => Esp32Service(irrigationHost: '127.0.0.1', visionHost: '127.0.0.1'),
          ),
          Provider<GeminiService?>(create: (_) => null),
          Provider<HistoryDatabase>(create: (_) => HistoryDatabase()),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );

    expect(find.text('Sensors'), findsOneWidget);
    expect(find.text('Irrigation'), findsOneWidget);
    expect(find.text('Diagnose'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Device'), findsOneWidget);
  });
}
