import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      _ref.invalidate(shoppingListsControllerProvider);
    } catch (error) {
      throw ApiError.fromObject(error);
    }
  }
}
