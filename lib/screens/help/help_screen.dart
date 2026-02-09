import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Contact')),
      body: const Center(child: Text('FAQ and KCA Foundation support contacts here')), // TODO: List of FAQs, email/phone
    );
  }
}