import 'package:flutter/material.dart';

class SpacePickerPage extends StatelessWidget {
  const SpacePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select a Space')),
      body: const SizedBox.shrink(),
    );
  }
}
