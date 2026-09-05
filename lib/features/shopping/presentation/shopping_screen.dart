import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../families/data/family_models.dart';
import '../../families/presentation/families_controller.dart';
import '../../families/presentation/selected_family_provider.dart';
import '../../shopping_lists/data/shopping_list_models.dart';
import '../../shopping_lists/presentation/shopping_list_detail_screen.dart';
import '../../shopping_lists/presentation/shopping_list_items_controller.dart';
import '../../shopping_lists/presentation/shopping_lists_controller.dart';
import '../../shopping_lists/presentation/shopping_lists_screen.dart';
import '../../shopping_lists/realtime/shopping_list_realtime_client.dart';

enum ShoppingItemFilter { remaining, all, purchased }

final shoppingItemFilterProvider =
    NotifierProvider<ShoppingItemFilterController, ShoppingItemFilter>(
      ShoppingItemFilterController.new,
    );

class ShoppingItemFilterController extends Notifier<ShoppingItemFilter> {
  @override
  ShoppingItemFilter build() => ShoppingItemFilter.remaining;

  void setFilter(ShoppingItemFilter filter) {
    state = filter;
  }
}

List<ListItemDto> filterShoppingItems(
  List<ListItemDto> items,
  ShoppingItemFilter filter,
) {
  return switch (filter) {
    ShoppingItemFilter.remaining =>
      items.where((item) => item.purchased != true).toList(),
    ShoppingItemFilter.all => items,
    ShoppingItemFilter.purchased =>
      items.where((item) => item.purchased == true).toList(),
  };
}

FamilyDto? resolveShoppingFamilySelection({
  required List<FamilyDto> families,
  required FamilyDto? selectedFamily,
}) {
  if (families.isEmpty) {
    return null;
  }

  if (selectedFamily != null &&
      families.any((family) => family.id == selectedFamily.id)) {
    return selectedFamily;
  }

  return families.length == 1 ? families.first : null;
}

ShoppingListDto? resolveShoppingListSelection({
  required int? familyId,
  required List<ShoppingListDto> lists,
  required ShoppingListDto? selectedList,
  required int? rememberedListId,
}) {
  if (familyId == null || lists.isEmpty) {
    return null;
  }

  ShoppingListDto? findList(int? listId) {
    if (listId == null) {
      return null;
    }

    for (final list in lists) {
      if (list.id == listId) {
        return list;
      }
    }
    return null;
  }

  if (selectedList?.family.id == familyId) {
    final refreshedSelectedList = findList(selectedList?.id);
    if (refreshedSelectedList != null) {
      return refreshedSelectedList;
    }
  }

  final rememberedList = findList(rememberedListId);
  if (rememberedList != null) {
    return rememberedList;
  }

  return lists.length == 1 ? lists.first : null;
}

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  static const routePath = '/shopping';

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final Map<int, int> _rememberedListIdsByFamily = <int, int>{};

  @override
  void initState() {
    super.initState();
    ref.listenManual(familiesControllerProvider, (_, next) {
      next.whenData(_reconcileFamilySelection);
    }, fireImmediately: true);
    ref.listenManual(selectedFamilyProvider, (previous, next) {
      _rememberSelectedList(previous);
      final selectedList = ref.read(selectedShoppingListProvider);
      if (next == null || selectedList?.family.id != next.id) {
        ref.read(selectedShoppingListProvider.notifier).select(null);
      }
    });
    ref.listenManual(shoppingListsControllerProvider, (_, next) {
      next.whenData(_reconcileListSelection);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final familiesState = ref.watch(familiesControllerProvider);
    final selectedFamily = ref.watch(selectedFamilyProvider);
    final listsState = ref.watch(shoppingListsControllerProvider);
    final selectedList = ref.watch(selectedShoppingListProvider);
    final selectedListId = selectedList?.id;
    final filter = ref.watch(shoppingItemFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping')),
      body: familiesState.when(
        data: (families) {
          if (families.isEmpty) {
            return const EmptyState(
              title: 'No families',
              message: 'Create or join a family to start shopping.',
            );
          }

          return Column(
            children: [
              _ShoppingContextBar(
                families: families,
                selectedFamily: selectedFamily,
                listsState: listsState,
                selectedList: selectedList,
                onChooseFamily: _showFamilySelector,
                onChooseList: _showListSelector,
              ),
              Expanded(
                child: _ShoppingBody(
                  selectedFamily: selectedFamily,
                  listsState: listsState,
                  selectedList: selectedList,
                  filter: filter,
                  onFilterChanged: (value) => ref
                      .read(shoppingItemFilterProvider.notifier)
                      .setFilter(value),
                  onRetryLists: _reloadLists,
                  onGoToLists: () => context.go(ShoppingListsScreen.routePath),
                  onGoToList: selectedListId == null
                      ? null
                      : () => context.go(
                          ShoppingListDetailScreen.routePath(selectedListId),
                          extra: selectedList,
                        ),
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

  void _rememberSelectedList(FamilyDto? family) {
    final familyId = family?.id;
    final selectedList = ref.read(selectedShoppingListProvider);
    final selectedListId = selectedList?.id;
    if (familyId != null &&
        selectedListId != null &&
        selectedList?.family.id == familyId) {
      _rememberedListIdsByFamily[familyId] = selectedListId;
    }
  }

  void _reconcileFamilySelection(List<FamilyDto> families) {
    final current = ref.read(selectedFamilyProvider);
    final resolved = resolveShoppingFamilySelection(
      families: families,
      selectedFamily: current,
    );

    if (resolved?.id != current?.id) {
      ref.read(selectedFamilyProvider.notifier).select(resolved);
    }
  }

  void _reconcileListSelection(List<ShoppingListDto> lists) {
    final familyId = ref.read(selectedFamilyProvider)?.id;
    final current = ref.read(selectedShoppingListProvider);
    final resolved = resolveShoppingListSelection(
      familyId: familyId,
      lists: lists,
      selectedList: current,
      rememberedListId: familyId == null
          ? null
          : _rememberedListIdsByFamily[familyId],
    );

    if (resolved?.id != current?.id) {
      ref.read(selectedShoppingListProvider.notifier).select(resolved);
    }
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
      builder: (context) => SafeArea(
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
      ),
    );

    if (selected != null) {
      ref.read(selectedFamilyProvider.notifier).select(selected);
    }
  }

  Future<void> _showListSelector() async {
    final lists = ref.read(shoppingListsControllerProvider).value;
    if (lists == null || lists.length <= 1) {
      return;
    }

    final selected = await showModalBottomSheet<ShoppingListDto>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: lists.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final list = lists[index];
            return ListTile(
              title: Text(list.description),
              subtitle: Text(
                '${list.remainingItemCount} remaining of ${list.itemCount}',
              ),
              onTap: () => Navigator.of(context).pop(list),
            );
          },
        ),
      ),
    );

    if (selected != null) {
      final familyId = selected.family.id;
      final listId = selected.id;
      if (familyId != null && listId != null) {
        _rememberedListIdsByFamily[familyId] = listId;
      }
      ref.read(selectedShoppingListProvider.notifier).select(selected);
    }
  }
}

class _ShoppingContextBar extends StatelessWidget {
  const _ShoppingContextBar({
    required this.families,
    required this.selectedFamily,
    required this.listsState,
    required this.selectedList,
    required this.onChooseFamily,
    required this.onChooseList,
  });

  final List<FamilyDto> families;
  final FamilyDto? selectedFamily;
  final AsyncValue<List<ShoppingListDto>> listsState;
  final ShoppingListDto? selectedList;
  final VoidCallback onChooseFamily;
  final VoidCallback onChooseList;

  @override
  Widget build(BuildContext context) {
    final lists = listsState.value ?? const <ShoppingListDto>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _ContextChipButton(
              icon: Icons.group_outlined,
              label: selectedFamily?.name ?? 'Choose family',
              enabled: families.length > 1,
              onTap: onChooseFamily,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ContextChipButton(
              icon: Icons.list_alt_outlined,
              label: selectedList?.description ?? 'Choose list',
              enabled: lists.length > 1,
              onTap: onChooseList,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextChipButton extends StatelessWidget {
  const _ContextChipButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _ShoppingBody extends ConsumerWidget {
  const _ShoppingBody({
    required this.selectedFamily,
    required this.listsState,
    required this.selectedList,
    required this.filter,
    required this.onFilterChanged,
    required this.onRetryLists,
    required this.onGoToLists,
    required this.onGoToList,
  });

  final FamilyDto? selectedFamily;
  final AsyncValue<List<ShoppingListDto>> listsState;
  final ShoppingListDto? selectedList;
  final ShoppingItemFilter filter;
  final ValueChanged<ShoppingItemFilter> onFilterChanged;
  final Future<void> Function() onRetryLists;
  final VoidCallback onGoToLists;
  final VoidCallback? onGoToList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedFamily == null) {
      return const EmptyState(
        title: 'Choose a family',
        message: 'Choose a family to start shopping.',
      );
    }

    return AsyncValueView<List<ShoppingListDto>>(
      value: listsState,
      onRetry: onRetryLists,
      data: (lists) {
        if (lists.isEmpty) {
          return EmptyState(
            title: 'No shopping lists yet.',
            message: 'Create a list before shopping.',
            action: FilledButton.icon(
              onPressed: onGoToLists,
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Go to Lists'),
            ),
          );
        }

        if (selectedList == null) {
          return const EmptyState(
            title: 'Choose a list',
            message: 'Choose a list to start shopping.',
          );
        }

        final listId = selectedList!.id;
        if (listId == null) {
          return const EmptyState(
            title: 'Choose a list',
            message: 'Choose a list to start shopping.',
          );
        }

        final itemsState = ref.watch(
          shoppingListItemsControllerProvider(listId),
        );
        ref.listen(shoppingListPurchasedEventsProvider(listId), (_, next) {
          next.whenData((event) {
            ref
                .read(shoppingListItemsControllerProvider(listId).notifier)
                .applyPurchasedEvent(event);
          });
        });

        return AsyncValueView<List<ListItemDto>>(
          value: itemsState,
          onRetry: () => ref
              .read(shoppingListItemsControllerProvider(listId).notifier)
              .reload(),
          data: (items) {
            final visibleItems = filterShoppingItems(items, filter);
            final purchasedCount = items
                .where((item) => item.purchased == true)
                .length;

            return RefreshIndicator(
              onRefresh: () => ref
                  .read(shoppingListItemsControllerProvider(listId).notifier)
                  .reload(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _ShoppingHeader(
                      filter: filter,
                      onFilterChanged: onFilterChanged,
                    ),
                  ),
                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        title: 'Nothing to buy yet.',
                        message: 'Add items to this list before shopping.',
                        action: onGoToList == null
                            ? null
                            : FilledButton.icon(
                                onPressed: onGoToList,
                                icon: const Icon(Icons.add),
                                label: const Text('Go to list'),
                              ),
                      ),
                    )
                  else if (visibleItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        title:
                            filter == ShoppingItemFilter.remaining &&
                                purchasedCount > 0
                            ? 'Everything is checked off 🎉'
                            : 'No items here',
                        message: 'Switch filters to see other items.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: visibleItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = visibleItems[index];
                          return _ShoppingItemRow(
                            listId: listId,
                            item: item,
                            onToggle: (purchased) => _togglePurchased(
                              context,
                              ref,
                              listId,
                              item,
                              purchased,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _togglePurchased(
    BuildContext context,
    WidgetRef ref,
    int listId,
    ListItemDto item,
    bool purchased,
  ) async {
    try {
      await ref
          .read(shoppingListItemsControllerProvider(listId).notifier)
          .togglePurchased(item: item, purchased: purchased);
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

class _ShoppingHeader extends StatelessWidget {
  const _ShoppingHeader({required this.filter, required this.onFilterChanged});

  final ShoppingItemFilter filter;
  final ValueChanged<ShoppingItemFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ShoppingItemFilter>(
          segments: const [
            ButtonSegment(
              value: ShoppingItemFilter.remaining,
              label: Text('Remaining'),
            ),
            ButtonSegment(value: ShoppingItemFilter.all, label: Text('All')),
            ButtonSegment(
              value: ShoppingItemFilter.purchased,
              label: Text('Purchased'),
            ),
          ],
          selected: {filter},
          onSelectionChanged: (selection) => onFilterChanged(selection.single),
          showSelectedIcon: false,
        ),
      ),
    );
  }
}

class _ShoppingItemRow extends ConsumerWidget {
  const _ShoppingItemRow({
    required this.listId,
    required this.item,
    required this.onToggle,
  });

  final int listId;
  final ListItemDto item;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemId = item.id;
    final purchased = item.purchased == true;
    final isPending =
        itemId != null &&
        ref
            .read(shoppingListItemsControllerProvider(listId).notifier)
            .isPurchasedTogglePending(itemId);
    final subtitle = item.shoppingPreview;

    return Material(
      color: purchased
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            children: [
              Checkbox(
                value: purchased,
                onChanged: isPending
                    ? null
                    : (value) => onToggle(value ?? !purchased),
              ),
              const SizedBox(width: 6),
              _ProductThumbnail(item: item, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: purchased
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                        decoration: purchased
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'x${item.quantity ?? 1}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: purchased
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ProductDetailsSheet(item: item),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.item, required this.size});

  final ListItemDto item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = item.product?.imageUrl?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: imageUrl == null || imageUrl.isEmpty
            ? ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: size * 0.5,
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: size * 0.5,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProductDetailsSheet extends StatelessWidget {
  const _ProductDetailsSheet({required this.item});

  final ListItemDto item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = item.shoppingDetails;
    final badge = item.productSourceBadge;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: _ProductThumbnail(item: item, size: 112)),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'x${item.quantity ?? 1}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              details ?? 'No description available.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(height: 16),
              Chip(
                label: Text(badge),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on ListItemDto {
  String? get shoppingPreview {
    final descriptionText = description?.trim();
    final familyDescription = familyProduct?.description?.trim();
    final subtitle = descriptionText?.isNotEmpty == true
        ? descriptionText
        : familyDescription;
    if (subtitle == null || subtitle.isEmpty || subtitle == productName) {
      return null;
    }
    return subtitle;
  }

  String? get shoppingDetails {
    final descriptionText = description?.trim();
    final familyDescription = familyProduct?.description?.trim();
    final details = [
      if (descriptionText != null && descriptionText.isNotEmpty)
        descriptionText,
      if (familyDescription != null &&
          familyDescription.isNotEmpty &&
          familyDescription != descriptionText)
        familyDescription,
    ].join('\n\n');
    return details.isEmpty ? null : details;
  }

  String? get productSourceBadge {
    if (familyProduct != null) {
      return 'Family';
    }
    if (product != null) {
      return 'Global';
    }
    return null;
  }
}
