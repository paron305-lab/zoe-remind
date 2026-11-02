import 'package:flutter/material.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';

/// TEMPORARY placeholder — shows what onboarding saved.
/// Replaced by the real Home screen next.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settings = SettingsRepository();
  late final Future<(String?, ZoeLanguage)> _saved = _load();

  Future<(String?, ZoeLanguage)> _load() async {
    final name = await _settings.getUserName();
    final language = await _settings.getLanguage();
    return (name, language);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder<(String?, ZoeLanguage)>(
        future: _saved,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) return const CircularProgressIndicator();
          final (name, language) = data;
          return Text(
            'Hi, ${name ?? 'there'}!\nSaved language: ${language.label}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          );
        },
      ),
    );
  }
}