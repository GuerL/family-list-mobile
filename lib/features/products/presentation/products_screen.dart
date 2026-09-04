import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../../families/data/family_models.dart';
import '../../families/presentation/families_controller.dart';
import '../../families/presentation/selected_family_provider.dart';
import '../data/product_models.dart';
import 'products_controller.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  static const routePath = '/products';

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.listenManual(familiesControllerProvider, (_, next) {
      next.whenData(_selectDefaultFamilyIfNeeded);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familiesState = ref.watch(familiesControllerProvider);
    final productsState = ref.watch(productsControllerProvider);
    final filteredProducts = ref.watch(filteredProductsProvider);
    final selectedFamily = ref.watch(selectedFamilyProvider);
    final scope = ref.watch(productsScopeProvider);
    final query = ref.watch(productsSearchProvider);
    final roles =
        ref.watch(authControllerProvider).value?.user.roles ?? const [];
    final canManageGlobal = canManageGlobalProducts(roles);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (canManageGlobal)
            PopupMenuButton<_ProductsAdminAction>(
              tooltip: 'Product administration',
              onSelected: (action) {
                switch (action) {
                  case _ProductsAdminAction.manageCategories:
                    _openManageCategories();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ProductsAdminAction.manageCategories,
                  child: ListTile(
                    leading: Icon(Icons.category_outlined),
                    title: Text('Manage categories'),
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Add product',
            onPressed:
                _canAddProduct(
                  selectedFamily: selectedFamily,
                  canManageGlobal: canManageGlobal,
                )
                ? () => _showAddProductSheet(canManageGlobal)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: familiesState.when(
        data: (families) {
          return Column(
            children: [
              _ProductsToolbar(
                families: families,
                selectedFamily: selectedFamily,
                scope: scope,
                searchController: _searchController,
                searchQuery: query,
                onScopeChanged: (value) =>
                    ref.read(productsScopeProvider.notifier).setScope(value),
                onSelectFamily: _showFamilySelector,
                onSearchChanged: (value) =>
                    ref.read(productsSearchProvider.notifier).setQuery(value),
              ),
              Expanded(
                child: AsyncValueView<List<ProductEntry>>(
                  value: productsState,
                  onRetry: _reloadProducts,
                  data: (products) {
                    if (_requiresFamily(scope) && selectedFamily == null) {
                      return EmptyState(
                        title: 'Select a family',
                        message: 'Select or create a family to manage family products.',
                        action: families.length > 1
                            ? FilledButton.icon(
                                onPressed: _showFamilySelector,
                                icon: const Icon(Icons.group_outlined),
                                label: const Text('Choose family'),
                              )
                            : null,
                      );
                    }

                    if (filteredProducts.isEmpty) {
                      return _ProductsEmptyState(
                        scope: scope,
                        hasQuery: query.trim().isNotEmpty,
                        selectedFamily: selectedFamily,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _reloadProducts,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filteredProducts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _ProductTile(
                            product: product,
                            canManage: product.isFamily || canManageGlobal,
                            onTap: () => _showProductDetails(
                              product,
                              canManage: product.isFamily || canManageGlobal,
                            ),
                            onEdit: () => _showEditProductSheet(product),
                            onDelete: () => _confirmDeleteProduct(product),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          final apiError = ApiError.fromObject(error);
          return EmptyState(
            title: 'Could not load families',
            message: apiError.message,
            action: FilledButton.icon(
              onPressed: () => ref.invalidate(familiesControllerProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          );
        },
      ),
    );
  }

  bool _canAddProduct({
    required FamilyDto? selectedFamily,
    required bool canManageGlobal,
  }) {
    return selectedFamily?.id != null || canManageGlobal;
  }

  bool _requiresFamily(ProductScope scope) {
    return scope == ProductScope.family;
  }

  void _selectDefaultFamilyIfNeeded(List<FamilyDto> families) {
    final resolved = resolveProductsFamilySelection(
      families: families,
      selectedFamily: ref.read(selectedFamilyProvider),
    );
    if (resolved?.id != ref.read(selectedFamilyProvider)?.id) {
      ref.read(selectedFamilyProvider.notifier).select(resolved);
    }
  }

  Future<void> _reloadProducts() async {
    ref.invalidate(productsControllerProvider);
    await ref.read(productsControllerProvider.future);
  }

  Future<void> _showFamilySelector() async {
    final families = ref.read(familiesControllerProvider).value;
    if (families == null || families.length <= 1) {
      return;
    }

    final selected = await showModalBottomSheet<FamilyDto>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: families.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final family = families[index];
            return ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(family.name),
              subtitle: Text('${family.members.length} members'),
              onTap: () => Navigator.of(context).pop(family),
            );
          },
        ),
      ),
    );

    if (selected != null) {
      ref.read(selectedFamilyProvider.notifier).select(selected);
    }
  }

  Future<void> _openManageCategories() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const _ManageCategoriesScreen(),
      ),
    );
  }

  Future<void> _showAddProductSheet(bool canManageGlobal) async {
    final selectedFamily = ref.read(selectedFamilyProvider);
    final familyId = selectedFamily?.id;
    ProductKind? kind;

    if (canManageGlobal && familyId != null) {
      kind = await showModalBottomSheet<ProductKind>(
        context: context,
        showDragHandle: true,
        builder: (context) => const _ProductKindSheet(),
      );
      if (kind == null || !mounted) {
        return;
      }
    } else if (canManageGlobal) {
      kind = ProductKind.global;
    } else {
      kind = ProductKind.family;
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        if (kind == ProductKind.global) {
          return _GlobalProductFormSheet(
            title: 'Add global product',
            onSubmit: (label, imageUrl, category) => ref
                .read(productManagementControllerProvider)
                .createGlobalProduct(
                  label: label,
                  imageUrl: imageUrl,
                  productCategory: category,
                ),
          );
        }

        return _FamilyProductFormSheet(
          title: 'Add family product',
          familyName: selectedFamily?.name,
          onSubmit: (label, description) => ref
              .read(productManagementControllerProvider)
              .createFamilyProduct(
                familyId: familyId!,
                label: label,
                description: description,
              ),
        );
      },
    );
  }

  Future<void> _showEditProductSheet(ProductEntry product) async {
    if (product.isGlobal) {
      final global = product.globalProduct;
      final id = global?.id;
      if (global == null || id == null) {
        return;
      }
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _GlobalProductFormSheet(
          title: 'Edit global product',
          product: global,
          onSubmit: (label, imageUrl, category) => ref
              .read(productManagementControllerProvider)
              .updateGlobalProduct(
                id: id,
                label: label,
                imageUrl: imageUrl,
                productCategory: category,
              ),
        ),
      );
      return;
    }

    final family = product.familyProduct;
    final id = family?.id;
    if (family == null || id == null) {
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FamilyProductFormSheet(
        title: 'Edit family product',
        familyName: product.family?.name,
        product: family,
        onSubmit: (label, description) => ref
            .read(productManagementControllerProvider)
            .updateFamilyProduct(
              id: id,
              label: label,
              description: description,
            ),
      ),
    );
  }

  Future<void> _showProductDetails(
    ProductEntry product, {
    required bool canManage,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ProductDetailsSheet(
        product: product,
        canEdit: canManage,
        onEdit: () {
          Navigator.of(context).pop();
          _showEditProductSheet(product);
        },
      ),
    );
  }

  Future<void> _confirmDeleteProduct(ProductEntry product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${product.name}"?'),
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

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      final controller = ref.read(productManagementControllerProvider);
      if (product.isGlobal) {
        await controller.deleteGlobalProduct(product.globalProduct!);
      } else {
        await controller.deleteFamilyProduct(product.familyProduct!);
      }
      if (mounted) {
        await _reloadProducts();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final apiError = ApiError.fromObject(error);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiError.message)));
    }
  }
}

enum _ProductsAdminAction { manageCategories }

class _ProductsToolbar extends StatelessWidget {
  const _ProductsToolbar({
    required this.families,
    required this.selectedFamily,
    required this.scope,
    required this.searchController,
    required this.searchQuery,
    required this.onScopeChanged,
    required this.onSelectFamily,
    required this.onSearchChanged,
  });

  final List<FamilyDto> families;
  final FamilyDto? selectedFamily;
  final ProductScope scope;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<ProductScope> onScopeChanged;
  final VoidCallback onSelectFamily;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    if (searchController.text != searchQuery) {
      searchController.value = TextEditingValue(
        text: searchQuery,
        selection: TextSelection.collapsed(offset: searchQuery.length),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchBar(
            controller: searchController,
            hintText: 'Search products',
            leading: const Icon(Icons.search),
            onChanged: onSearchChanged,
            trailing: [
              if (searchQuery.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    searchController.clear();
                    onSearchChanged('');
                  },
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<ProductScope>(
            segments: const [
              ButtonSegment(value: ProductScope.all, label: Text('All')),
              ButtonSegment(value: ProductScope.family, label: Text('Family')),
              ButtonSegment(value: ProductScope.global, label: Text('Global')),
            ],
            selected: {scope},
            onSelectionChanged: (selection) => onScopeChanged(selection.single),
          ),
          if (scope != ProductScope.global && families.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: families.length == 1
                  ? Chip(
                      avatar: const Icon(Icons.group_outlined, size: 18),
                      label: Text(families.first.name),
                    )
                  : OutlinedButton.icon(
                      onPressed: onSelectFamily,
                      icon: const Icon(Icons.group_outlined),
                      label: Text(selectedFamily?.name ?? 'Choose family'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductEntry product;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        leading: _ProductThumbnail(imageUrl: product.imageUrl, size: 56),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.subtitle != null)
              Text(
                product.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              product.metadataLine,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right),
            if (canManage)
              PopupMenuButton<_ProductAction>(
                tooltip: 'Product actions',
                onSelected: (action) {
                  switch (action) {
                    case _ProductAction.edit:
                      onEdit();
                    case _ProductAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ProductAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ProductAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

enum _ProductAction { edit, delete }

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = imageUrl?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: url == null || url.isEmpty
            ? ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ProductsEmptyState extends StatelessWidget {
  const _ProductsEmptyState({
    required this.scope,
    required this.hasQuery,
    required this.selectedFamily,
  });

  final ProductScope scope;
  final bool hasQuery;
  final FamilyDto? selectedFamily;

  @override
  Widget build(BuildContext context) {
    if (hasQuery) {
      return const EmptyState(
        title: 'No products match your search',
        message: 'Try a different product name or description.',
      );
    }

    return switch (scope) {
      ProductScope.global => const EmptyState(
        title: 'No global products found',
        message: 'Global products will appear here.',
      ),
      ProductScope.family => const EmptyState(
        title: 'No products for this family yet',
        message: 'Add a family product to reuse it in shopping lists.',
      ),
      ProductScope.all =>
        selectedFamily == null
            ? const EmptyState(
                title: 'No products found',
                message: 'Global products will appear here.',
              )
            : const EmptyState(
                title: 'No products found',
                message: 'Add a family product or browse global products.',
              ),
    };
  }
}

class _ProductKindSheet extends StatelessWidget {
  const _ProductKindSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('Family product'),
            subtitle: const Text('Available only in the selected family'),
            onTap: () => Navigator.of(context).pop(ProductKind.family),
          ),
          ListTile(
            leading: const Icon(Icons.public_outlined),
            title: const Text('Global product'),
            subtitle: const Text('Available to everyone'),
            onTap: () => Navigator.of(context).pop(ProductKind.global),
          ),
        ],
      ),
    );
  }
}

class _ProductDetailsSheet extends StatelessWidget {
  const _ProductDetailsSheet({
    required this.product,
    required this.canEdit,
    required this.onEdit,
  });

  final ProductEntry product;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final familyName = product.isFamily ? product.family?.name : null;
    final categoryName = product.categoryName;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: _ProductThumbnail(imageUrl: product.imageUrl, size: 120),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                _ScopeBadge(label: product.scopeLabel),
              ],
            ),
            if (product.subtitle != null) ...[
              const SizedBox(height: 12),
              Text(product.subtitle!, style: theme.textTheme.bodyLarge),
            ],
            if (categoryName != null && categoryName != product.subtitle) ...[
              const SizedBox(height: 12),
              Text(
                categoryName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (familyName != null) ...[
              const SizedBox(height: 12),
              Text(
                familyName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManageCategoriesScreen extends ConsumerWidget {
  const _ManageCategoriesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(productCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            onPressed: () => _showCategoryForm(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AsyncValueView<List<ProductCategoryDto>>(
        value: categoriesState,
        onRetry: () async {
          ref.invalidate(productCategoriesProvider);
          await ref.read(productCategoriesProvider.future);
        },
        data: (categories) {
          if (categories.isEmpty) {
            return EmptyState(
              title: 'No categories found',
              message: 'Create categories for global products.',
              action: FilledButton.icon(
                onPressed: () => _showCategoryForm(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add category'),
              ),
            );
          }

          final sorted = [...categories]
            ..sort(
              (a, b) => (a.name ?? '').toLowerCase().compareTo(
                (b.name ?? '').toLowerCase(),
              ),
            );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productCategoriesProvider);
              await ref.read(productCategoriesProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = sorted[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(
                      category.name?.trim().isNotEmpty == true
                          ? category.name!.trim()
                          : 'Unnamed category',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_linkedProductLabel(category)),
                    trailing: PopupMenuButton<_CategoryAction>(
                      tooltip: 'Category actions',
                      onSelected: (action) {
                        switch (action) {
                          case _CategoryAction.edit:
                            _showCategoryForm(context, ref, category: category);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _CategoryAction.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _linkedProductLabel(ProductCategoryDto category) {
    final count = category.linkedProductCount;
    if (count == 0) {
      return 'No linked products';
    }
    return '$count linked product${count == 1 ? '' : 's'}';
  }

  Future<void> _showCategoryForm(
    BuildContext context,
    WidgetRef ref, {
    ProductCategoryDto? category,
  }) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CategoryFormSheet(
        category: category,
        onSubmit: (name) {
          final id = category?.id;
          if (id == null) {
            return ref
                .read(productManagementControllerProvider)
                .createProductCategory(name: name);
          }
          return ref
              .read(productManagementControllerProvider)
              .updateProductCategory(id: id, name: name);
        },
      ),
    );
  }
}

enum _CategoryAction { edit }

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({required this.onSubmit, this.category});

  final ProductCategoryDto? category;
  final Future<void> Function(String name) onSubmit;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final isEditing = widget.category != null;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Edit category' : 'Add category',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Category name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Category name is required.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
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

    try {
      await widget.onSubmit(_nameController.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
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

class _FamilyProductFormSheet extends StatefulWidget {
  const _FamilyProductFormSheet({
    required this.title,
    required this.onSubmit,
    this.familyName,
    this.product,
  });

  final String title;
  final String? familyName;
  final FamilyProductDto? product;
  final Future<void> Function(String label, String? description) onSubmit;

  @override
  State<_FamilyProductFormSheet> createState() =>
      _FamilyProductFormSheetState();
}

class _FamilyProductFormSheetState extends State<_FamilyProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _descriptionController;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.product?.label ?? '');
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              if (widget.familyName != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.familyName!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Product name'),
                validator: _requiredProductName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Description'),
                onFieldSubmitted: (_) => _submit(),
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

    try {
      final description = _descriptionController.text.trim();
      await widget.onSubmit(
        _labelController.text.trim(),
        description.isEmpty ? null : description,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
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

class _GlobalProductFormSheet extends ConsumerStatefulWidget {
  const _GlobalProductFormSheet({
    required this.title,
    required this.onSubmit,
    this.product,
  });

  final String title;
  final GlobalProductDto? product;
  final Future<void> Function(
    String label,
    String? imageUrl,
    ProductCategoryDto? productCategory,
  )
  onSubmit;

  @override
  ConsumerState<_GlobalProductFormSheet> createState() =>
      _GlobalProductFormSheetState();
}

class _GlobalProductFormSheetState
    extends ConsumerState<_GlobalProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _imageUrlController;
  int? _categoryId;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.product?.label ?? '');
    _imageUrlController = TextEditingController(
      text: widget.product?.imageUrl ?? '',
    );
    _categoryId = widget.product?.productCategory?.id;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final categoriesState = ref.watch(productCategoriesProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Product name'),
                validator: _requiredProductName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
              const SizedBox(height: 12),
              categoriesState.when(
                data: (categories) {
                  final categoriesWithIds = categories
                      .where((category) => category.id != null)
                      .toList();
                  final selectedId =
                      categoriesWithIds.any(
                        (category) => category.id == _categoryId,
                      )
                      ? _categoryId
                      : -1;

                  return DropdownButtonFormField<int>(
                    initialValue: selectedId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('No category'),
                      ),
                      ...categoriesWithIds.map(
                        (category) => DropdownMenuItem(
                          value: category.id!,
                          child: Text(category.name ?? 'Unnamed category'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Categories unavailable.'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _submit(categoriesState.value),
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
      ),
    );
  }

  Future<void> _submit(List<ProductCategoryDto>? categories) async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final imageUrl = _imageUrlController.text.trim();
      final category = _categoryId == null || _categoryId == -1
          ? null
          : categories?.where((item) => item.id == _categoryId).firstOrNull;
      await widget.onSubmit(
        _labelController.text.trim(),
        imageUrl.isEmpty ? null : imageUrl,
        category,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
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

String? _requiredProductName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Product name is required.';
  }
  return null;
}
