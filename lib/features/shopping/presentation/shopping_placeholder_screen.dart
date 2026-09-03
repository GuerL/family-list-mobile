import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

class ShoppingPlaceholderScreen extends StatelessWidget {
  const ShoppingPlaceholderScreen({super.key});

  static const routePath = '/shopping';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping')),
      body: const EmptyState(
        title: 'Shopping mode is next',
        message: 'Fast in-store shopping will be implemented separately.',
      ),
    );
  }
}
