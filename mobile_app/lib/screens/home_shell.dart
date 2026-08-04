import 'package:flutter/material.dart';

import 'sensor_dashboard_screen.dart';
import 'irrigation_control_screen.dart';
import 'diagnosis_screen.dart';
import 'history_screen.dart';
import 'chatbot_screen.dart';
import 'esp32_tests_screen.dart';

/// Bottom-nav shell holding the six modules described in the project
/// report's Mobile Application Workflow section.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    SensorDashboardScreen(),
    IrrigationControlScreen(),
    DiagnosisScreen(),
    HistoryScreen(),
    ChatbotScreen(),
    Esp32TestsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Sensors'),
    NavigationDestination(icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop), label: 'Irrigation'),
    NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt), label: 'Diagnose'),
    NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
    NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
    NavigationDestination(icon: Icon(Icons.settings_ethernet_outlined), selectedIcon: Icon(Icons.settings_ethernet), label: 'Device'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
