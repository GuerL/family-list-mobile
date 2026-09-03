import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/product_search.dart';
import '../data/shopping_list_models.dart';
import 'shopping_list_items_controller.dart';
import 'shopping_lists_controller.dart';
import 'shopping_lists_screen.dart';

class ShoppingListDetailScreen extends ConsumerWidget {
  const ShoppingListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.familyId,
  });

  final int listId;
  final String listName;
  final int? familyId;

  static String routePath(int listId) => '/lists/$listId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsState = ref.watch(shoppingListItemsControllerProvider(listId));

    return Scaffold(
      appBar: AppBar(
        title: Text(listName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<_ListDetailAction>(
            tooltip: 'List actions',
            onSelected: (action) {
              switch (action) {
                case _ListDetailAction.delete:
                  _confirmDeleteList(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ListDetailAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete list'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: AsyncValueView<List<ListItemDto>>(
        value: itemsState,
        onRetry: () => ref
            .read(shoppingListItemsControllerProvider(listId).notifier)
            .reload(),
        data: (items) {
          final sortedItems = [...items]
            ..sort((a, b) => a.productName.compareTo(b.productName));

          return RefreshIndicator(
            onRefresh: () => ref
                .read(shoppingListItemsControllerProvider(listId).notifier)
                .reload(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _ListDetailHeader(
                    itemCount: sortedItems.length,
                    onAddItem: () => _showAddItemSheet(context, ref),
                  ),
                ),
                if (sortedItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: 'Empty list',
                      message: 'Add items to prepare this list.',
                      action: FilledButton.icon(
                        onPressed: () => _showAddItemSheet(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: sortedItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = sortedItems[index];
                        return _ListItemTile(
                          item: item,
                          onEdit: () => _showEditItemSheet(context, ref, item),
                          onDelete: () =>
                              _confirmDeleteItem(context, ref, item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddItemSheet(BuildContext context, WidgetRef ref) async {
    final currentFamilyId = familyId;
    if (currentFamilyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('List family is unavailable.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddListItemSheet(
        familyId: currentFamilyId,
        onSave: (product, quantity, description) async {
          await ref
              .read(shoppingListItemsControllerProvider(listId).notifier)
              .createItem(
                familyId: currentFamilyId,
                product: product,
                quantity: quantity,
                description: description,
              );
        },
      ),
    );
  }

  Future<void> _showEditItemSheet(
    BuildContext context,
    WidgetRef ref,
    ListItemDto item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditListItemSheet(
        item: item,
        onSave: (quantity, description) async {
          await ref
              .read(shoppingListItemsControllerProvider(listId).notifier)
              .updateItem(
                item: item,
                quantity: quantity,
                description: description,
              );
        },
      ),
    );
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    WidgetRef ref,
    ListItemDto item,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove ${item.productName} from this list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await ref
          .read(shoppingListItemsControllerProvider(listId).notifier)
          .deleteItem(item);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final apiError = ApiError.fromObject(error);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiError.message)));
    }
  }

  Future<void> _confirmDeleteList(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$listName"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await ref.read(deleteShoppingListControllerProvider).deleteById(listId);
      if (context.mounted) {
        context.go(ShoppingListsScreen.routePath);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final apiError = ApiError.fromObject(error);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiError.message)));
    }
  }
}

enum _ListDetailAction { delete }

class _ListDetailHeader extends StatelessWidget {
  const _ListDetailHeader({required this.itemCount, required this.onAddItem});

  final int itemCount;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemLabel = itemCount == 1 ? '1 item' : '$itemCount items';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              itemLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onAddItem,
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ],
      ),
    );
  }
}

class _ListItemTile extends StatelessWidget {
  const _ListItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ListItemDto item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = item.quantity ?? 1;
    final subtitle = item.managementSubtitle;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        title: Text(
          item.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'x$quantity',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            PopupMenuButton<_ListItemAction>(
              tooltip: 'Item actions',
              onSelected: (action) {
                switch (action) {
                  case _ListItemAction.edit:
                    onEdit();
                  case _ListItemAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ListItemAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem(
                  value: _ListItemAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

enum _ListItemAction { edit, delete }

class _AddListItemSheet extends ConsumerStatefulWidget {
  const _AddListItemSheet({required this.familyId, required this.onSave});

  final int familyId;
  final Future<void> Function(
    AddableProduct product,
    int quantity,
    String? description,
  )
  onSave;

  @override
  ConsumerState<_AddListItemSheet> createState() => _AddListItemSheetState();
}

class _AddListItemSheetState extends ConsumerState<_AddListItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  AddableProduct? _selectedProduct;
  int _quantity = 1;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    final selectedProduct = _selectedProduct;
    if (selectedProduct == null) {
      setState(() {});
      return;
    }

    if (_nameController.text.trim() != selectedProduct.label) {
      setState(() => _selectedProduct = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final query = _nameController.text.trim();
    final catalogState = ref.watch(
      addableProductCatalogProvider(widget.familyId),
    );

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add item', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Product name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Product name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _ProductSearchResults(
                catalogState: catalogState,
                query: query,
                selectedProduct: _selectedProduct,
                onSelected: _selectProduct,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional note',
                ),
                maxLines: 2,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              _QuantityStepper(
                quantity: _quantity,
                isSubmitting: _isSubmitting,
                onChanged: (value) => setState(() => _quantity = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final description = _descriptionController.text.trim();
    final selectedProduct =
        _selectedProduct ?? AddableProduct.custom(_nameController.text);

    try {
      await widget.onSave(
        selectedProduct,
        _quantity,
        description.isEmpty ? null : description,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = ApiError.fromObject(error).message;
        _isSubmitting = false;
      });
    }
  }

  void _selectProduct(AddableProduct product) {
    setState(() {
      _selectedProduct = product;
      _nameController.value = TextEditingValue(
        text: product.label,
        selection: TextSelection.collapsed(offset: product.label.length),
      );
    });
  }
}

class _ProductSearchResults extends StatelessWidget {
  const _ProductSearchResults({
    required this.catalogState,
    required this.query,
    required this.selectedProduct,
    required this.onSelected,
  });

  final AsyncValue<AddableProductCatalog> catalogState;
  final String query;
  final AddableProduct? selectedProduct;
  final ValueChanged<AddableProduct> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (selectedProduct != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.check_circle_outline),
          title: Text(selectedProduct!.label),
          subtitle: Text(selectedProduct!.sourceLabel),
        ),
      );
    }

    if (query.isEmpty) {
      return Text(
        'Search existing products or enter a custom item.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return catalogState.when(
      data: (catalog) {
        final matches = catalog.search(query);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (matches.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No existing products found.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final product in matches)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          product.kind == AddableProductKind.family
                              ? Icons.group_outlined
                              : Icons.inventory_2_outlined,
                        ),
                        title: Text(product.label),
                        subtitle: Text(product.sourceLabel),
                        onTap: () => onSelected(product),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onSelected(AddableProduct.custom(query)),
              icon: const Icon(Icons.add),
              label: Text('Create "$query"'),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) {
        final apiError = ApiError.fromObject(error);
        return Text(
          apiError.message,
          style: TextStyle(color: theme.colorScheme.error),
        );
      },
    );
  }
}

class _EditListItemSheet extends StatefulWidget {
  const _EditListItemSheet({required this.item, required this.onSave});

  final ListItemDto item;
  final Future<void> Function(int quantity, String? description) onSave;

  @override
  State<_EditListItemSheet> createState() => _EditListItemSheetState();
}

class _EditListItemSheetState extends State<_EditListItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late int _quantity;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.item.description ?? '',
    );
    _quantity = widget.item.quantity ?? 1;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.item.productName, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional note',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _QuantityStepper(
              quantity: _quantity,
              isSubmitting: _isSubmitting,
              onChanged: (value) => setState(() => _quantity = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final description = _descriptionController.text.trim();

    try {
      await widget.onSave(_quantity, description.isEmpty ? null : description);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = ApiError.fromObject(error).message;
        _isSubmitting = false;
      });
    }
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.isSubmitting,
    required this.onChanged,
  });

  final int quantity;
  final bool isSubmitting;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: Text('Quantity', style: theme.textTheme.titleMedium)),
        IconButton.outlined(
          onPressed: quantity > 1 && !isSubmitting
              ? () => onChanged(quantity - 1)
              : null,
          icon: const Icon(Icons.remove),
          tooltip: 'Decrease quantity',
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        IconButton.outlined(
          onPressed: isSubmitting ? null : () => onChanged(quantity + 1),
          icon: const Icon(Icons.add),
          tooltip: 'Increase quantity',
        ),
      ],
    );
  }
}

extension on ListItemDto {
  String? get managementSubtitle {
    final rawDescription = description?.trim();
    final productDescription = familyProduct?.description?.trim();
    final values = [
      if (rawDescription != null &&
          rawDescription.isNotEmpty &&
          rawDescription != productName)
        rawDescription,
      if (productDescription != null &&
          productDescription.isNotEmpty &&
          productDescription != productName &&
          productDescription != rawDescription)
        productDescription,
    ];

    if (values.isEmpty) {
      return null;
    }

    return values.join('\n');
  }
}
