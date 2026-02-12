import 'package:flutter/material.dart';
import 'package:mucron/components/routes/tuner_screen.dart';

void main() => runApp(const TunerApp());

class TunerApp extends StatelessWidget {
  const TunerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note Tuner',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const TunerScreen(),
    );
  }
}
