import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/shell_screen.dart';

void main() {
  runApp(const ClinicalAtelierApp());
}

class ClinicalAtelierApp extends StatelessWidget {
  const ClinicalAtelierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clinical Atelier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const ShellScreen(),
    );
  }
}
