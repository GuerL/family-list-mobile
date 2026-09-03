import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/shopping_list_models.dart';
import 'shopping_list_items_controller.dart';

class ShoppingListDetailScreen extends ConsumerWidget {
  const ShoppingListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  final int listId;
  final String listName;

  static String routePath(int listId) => '/lists/$listId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsState = ref.watch(shoppingListItemsControllerProvider(listId));

    return Scaffold(
      appBar: AppBar(
        title: Text(listName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: AsyncValueView<List<ListItemDto>>(
        value: itemsState,
        onRetry: () => ref
            .read(shoppingListItemsControllerProvider(listId).notifier)
            .reload(),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              title: 'Empty list',
              message:
                  'Items can be added from list management in a later step.',
            );
          }

          final sortedItems = [...items]
            ..sort((a, b) {
              if (a.purchased == b.purchased) {
                return a.productName.compareTo(b.productName);
              }
              return a.purchased == true ? 1 : -1;
            });

          return RefreshIndicator(
            onRefresh: () => ref
                .read(shoppingListItemsControllerProvider(listId).notifier)
                .reload(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: sortedItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = sortedItems[index];
                return _ListItemTile(
                  item: item,
                  onToggle: () async {
                    try {
                      await ref
                          .read(
                            shoppingListItemsControllerProvider(listId)
                                .notifier,
                          )
                          .togglePurchased(item);
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      final apiError = ApiError.fromObject(error);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(apiError.message)));
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add item will be added later.')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }
}

class _ListItemTile extends StatelessWidget {
  const _ListItemTile({required this.item, required this.onToggle});

  final ListItemDto item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPurchased = item.purchased == true;
    final quantity = item.quantity ?? 1;

    return Card(
      color: isPurchased ? theme.colorScheme.surfaceContainerHighest : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(value: isPurchased, onChanged: (_) => onToggle()),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: isPurchased
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: isPurchased
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty &&
                        item.description != item.productName)
                      Text(
                        item.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'x$quantity',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isPurchased
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
