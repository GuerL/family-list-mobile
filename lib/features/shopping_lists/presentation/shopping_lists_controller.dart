import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/app_logger.dart';
import '../../../core/network/api_error.dart';
import '../../families/presentation/selected_family_provider.dart';
import '../data/shopping_list_models.dart';
import '../data/shopping_lists_api.dart';

final shoppingListsSearchProvider =
    NotifierProvider<ShoppingListsSearchController, String>(
      ShoppingListsSearchController.new,
    );

class ShoppingListsSearchController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final selectedShoppingListProvider =
    NotifierProvider<SelectedShoppingListController, ShoppingListDto?>(
      SelectedShoppingListController.new,
    );

class SelectedShoppingListController extends Notifier<ShoppingListDto?> {
  @override
  ShoppingListDto? build() => null;

  void select(ShoppingListDto? list) {
    state = list;
  }

  void clearIfSelected(int listId) {
    if (state?.id == listId) {
      state = null;
    }
  }
}

final shoppingListsControllerProvider =
    FutureProvider.autoDispose<List<ShoppingListDto>>((ref) async {
      final selectedFamily = ref.watch(selectedFamilyProvider);
      if (selectedFamily == null) {
        return const [];
      }

      try {
        return await ref
            .read(shoppingListsApiProvider)
            .getListsForFamily(selectedFamily);
      } catch (error) {
        throw ApiError.fromObject(error);
      }
    });

final deleteShoppingListControllerProvider =
    Provider.autoDispose<DeleteShoppingListController>(
      DeleteShoppingListController.new,
    );

class DeleteShoppingListController {
  const DeleteShoppingListController(this._ref);

  final Ref _ref;

  Future<void> delete(ShoppingListDto list) async {
    final listId = list.id;
    if (listId == null) {
      throw const ApiError(message: 'List id is missing.');
    }

    await deleteById(listId);
  }

  Future<void> deleteById(int listId) async {
    try {
      await _ref.read(shoppingListsApiProvider).deleteList(listId);
      _ref.read(selectedShoppingListProvider.notifier).clearIfSelected(listId);
      _ref.invalidate(shoppingListsControllerProvider);
    } catch (error) {
      appLogger.debug('Lists: delete controller failed: $error');
      throw ApiError.fromObject(error);
    }
  }
}

final filteredShoppingListsProvider =
    Provider.autoDispose<List<ShoppingListDto>>((ref) {
      final lists = ref
          .watch(shoppingListsControllerProvider)
          .whenOrNull(data: (lists) => lists);
      final query = ref.watch(shoppingListsSearchProvider).trim().toLowerCase();

      if (lists == null) {
        return const [];
      }

      if (query.isEmpty) {
        return lists;
      }

      return lists
          .where((list) => list.description.toLowerCase().contains(query))
          .toList();
    });

final createShoppingListControllerProvider =
    Provider.autoDispose<CreateShoppingListController>(
      CreateShoppingListController.new,
    );

class CreateShoppingListController {
  const CreateShoppingListController(this._ref);

  final Ref _ref;

  Future<void> create(String description) async {
    final selectedFamily = _ref.read(selectedFamilyProvider);
    if (selectedFamily == null) {
      throw const ApiError(message: 'Select a family before creating a list.');
    }

    try {
      await _ref
          .read(shoppingListsApiProvider)
          .createList(family: selectedFamily, description: description);
    } catch (error) {
      appLogger.debug('Lists: create controller failed: $error');
      throw ApiError.fromObject(error);
    }
  }
}
