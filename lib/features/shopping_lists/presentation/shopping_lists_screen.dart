import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/debug/app_logger.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../families/data/family_models.dart';
import '../../families/presentation/families_controller.dart';
import '../../families/presentation/selected_family_provider.dart';
import '../data/shopping_list_models.dart';
import 'shopping_list_detail_screen.dart';
import 'shopping_lists_controller.dart';

class ShoppingListsScreen extends ConsumerStatefulWidget {
  const ShoppingListsScreen({super.key});

  static const routePath = '/lists';

  @override
  ConsumerState<ShoppingListsScreen> createState() =>
      _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends ConsumerState<ShoppingListsScreen> {
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
    final selectedFamily = ref.watch(selectedFamilyProvider);
    final listsState = ref.watch(shoppingListsControllerProvider);
    final filteredLists = ref.watch(filteredShoppingListsProvider);
    final searchQuery = ref.watch(shoppingListsSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lists'),
        actions: [
          IconButton(
            tooltip: 'Create list',
            onPressed: selectedFamily == null ? null : _showCreateListSheet,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: familiesState.when(
        data: (families) {
          if (families.isEmpty) {
            return const EmptyState(
              title: 'No family yet',
              message: 'Create or join a family before managing lists.',
            );
          }

          if (selectedFamily == null) {
            return _NoFamilySelected(
              families: families,
              onSelectFamily: _showFamilySelector,
            );
          }

          return Column(
            children: [
              _ListsToolbar(
                families: families,
                selectedFamily: selectedFamily,
                searchController: _searchController,
                searchQuery: searchQuery,
                onSelectFamily: _showFamilySelector,
                onSearchChanged: (value) => ref
                    .read(shoppingListsSearchProvider.notifier)
                    .setQuery(value),
              ),
              Expanded(
                child: AsyncValueView<List<ShoppingListDto>>(
                  value: listsState,
                  onRetry: _reloadLists,
                  data: (lists) {
                    if (lists.isEmpty) {
                      return EmptyState(
                        title: 'No lists yet',
                        message: 'Create the first list for this family.',
                        action: FilledButton.icon(
                          onPressed: _showCreateListSheet,
                          icon: const Icon(Icons.add),
                          label: const Text('Create list'),
                        ),
                      );
                    }

                    if (filteredLists.isEmpty) {
                      return const EmptyState(
                        title: 'No matching lists',
                        message: 'Try a different search term.',
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _reloadLists,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filteredLists.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _ShoppingListCard(
                            list: filteredLists[index],
                            onDelete: () =>
                                _confirmDeleteList(filteredLists[index]),
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

  void _selectDefaultFamilyIfNeeded(List<FamilyDto> families) {
    final selectedFamily = ref.read(selectedFamilyProvider);
    if (families.isEmpty) {
      ref.read(selectedFamilyProvider.notifier).select(null);
      return;
    }

    if (selectedFamily != null &&
        families.any((family) => family.id == selectedFamily.id)) {
      return;
    }

    ref
        .read(selectedFamilyProvider.notifier)
        .select(families.length == 1 ? families.first : null);
  }

  Future<void> _reloadLists() async {
    ref.invalidate(shoppingListsControllerProvider);
    await ref.read(shoppingListsControllerProvider.future);
  }

  Future<void> _showFamilySelector() async {
    final families = ref.read(familiesControllerProvider).value;
    if (families == null || families.length <= 1) {
      return;
    }

    final selected = await showModalBottomSheet<FamilyDto>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: families.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final family = families[index];
              return ListTile(
                title: Text(family.name),
                subtitle: Text('${family.members.length} members'),
                onTap: () => Navigator.of(context).pop(family),
              );
            },
          ),
        );
      },
    );

    if (selected != null) {
      ref.read(selectedFamilyProvider.notifier).select(selected);
      ref.read(shoppingListsSearchProvider.notifier).clear();
      _searchController.clear();
    }
  }

  Future<void> _showCreateListSheet() async {
    final selectedFamily = ref.read(selectedFamilyProvider);
    if (selectedFamily == null) {
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _CreateListSheet(),
    );

    if (created == true && mounted) {
      appLogger.debug('Lists: create sheet closed, refreshing lists');
      await _reloadLists();
    }
  }

  Future<void> _confirmDeleteList(ShoppingListDto list) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${list.description}"?'),
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
      await ref.read(deleteShoppingListControllerProvider).delete(list);
      if (mounted) {
        await _reloadLists();
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

class _ListsToolbar extends StatelessWidget {
  const _ListsToolbar({
    required this.families,
    required this.selectedFamily,
    required this.searchController,
    required this.searchQuery,
    required this.onSelectFamily,
    required this.onSearchChanged,
  });

  final List<FamilyDto> families;
  final FamilyDto selectedFamily;
  final TextEditingController searchController;
  final String searchQuery;
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
          Align(
            alignment: Alignment.centerLeft,
            child: families.length == 1
                ? Chip(
                    avatar: const Icon(Icons.group_outlined, size: 18),
                    label: Text(selectedFamily.name),
                  )
                : OutlinedButton.icon(
                    onPressed: onSelectFamily,
                    icon: const Icon(Icons.group_outlined),
                    label: Text(selectedFamily.name),
                  ),
          ),
          const SizedBox(height: 8),
          SearchBar(
            controller: searchController,
            hintText: 'Search lists',
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
        ],
      ),
    );
  }
}

class _NoFamilySelected extends StatelessWidget {
  const _NoFamilySelected({
    required this.families,
    required this.onSelectFamily,
  });

  final List<FamilyDto> families;
  final VoidCallback onSelectFamily;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'Select a family',
      message: 'Choose a family to browse its shopping lists.',
      action: FilledButton.icon(
        onPressed: families.length > 1 ? onSelectFamily : null,
        icon: const Icon(Icons.group_outlined),
        label: const Text('Choose family'),
      ),
    );
  }
}

class _ShoppingListCard extends StatelessWidget {
  const _ShoppingListCard({required this.list, required this.onDelete});

  final ShoppingListDto list;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final createdAt = list.createdAt;
    final meta = [
      '${list.itemCount} item${list.itemCount == 1 ? '' : 's'}',
      '${list.remainingItemCount} remaining',
      if (createdAt != null) _formatDate(createdAt),
    ].join(' · ');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          list.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${list.family.name}\n$meta'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right),
            PopupMenuButton<_ShoppingListAction>(
              tooltip: 'List actions',
              onSelected: (action) {
                switch (action) {
                  case _ShoppingListAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ShoppingListAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete list'),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          final listId = list.id;
          if (listId == null) {
            return;
          }
          context.push(ShoppingListDetailScreen.routePath(listId), extra: list);
        },
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

enum _ShoppingListAction { delete }

class _CreateListSheet extends ConsumerStatefulWidget {
  const _CreateListSheet();

  @override
  ConsumerState<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends ConsumerState<_CreateListSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create list', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'List name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'List name is required.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
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

    try {
      await ref
          .read(createShoppingListControllerProvider)
          .create(_descriptionController.text.trim());
      appLogger.debug('Lists: create sheet succeeded, closing sheet');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      appLogger.debug(
        'Lists: create sheet failed: ${error.runtimeType} - $error',
      );
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
