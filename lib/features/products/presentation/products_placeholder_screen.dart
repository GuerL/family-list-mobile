import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

class ProductsPlaceholderScreen extends StatelessWidget {
  const ProductsPlaceholderScreen({super.key});

  static const routePath = '/products';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: const EmptyState(
        title: 'Products are next',
        message: 'Product browsing and management will be implemented later.',
      ),
    );
  }
}
