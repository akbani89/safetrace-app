// lib/core/language_toggle.dart
// Add this widget to the home screen AppBar actions

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translations.dart';
import 'theme.dart';

class LanguageToggle extends StatefulWidget {
  final VoidCallback onChanged;
  const LanguageToggle({super.key, required this.onChanged});

  @override
  State<LanguageToggle> createState() => _LanguageToggleState();
}

class _LanguageToggleState extends State<LanguageToggle> {
  bool _isUrdu = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final isUrdu = prefs.getBool('lang_urdu') ?? false;
    setState(() => _isUrdu = isUrdu);
    AppTranslations.setUrdu(isUrdu);
  }

  Future<void> _toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final newVal = !_isUrdu;
    await prefs.setBool('lang_urdu', newVal);
    setState(() => _isUrdu = newVal);
    AppTranslations.setUrdu(newVal);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isUrdu ? 'EN' : 'اردو',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
