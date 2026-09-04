import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/app_logger.dart';
import '../../../core/network/api_error.dart';
import '../../shopping_lists/presentation/shopping_lists_controller.dart';
import '../data/families_api.dart';
import '../data/family_models.dart';
import 'selected_family_provider.dart';

final familiesControllerProvider = FutureProvider.autoDispose<List<FamilyDto>>((
  ref,
) async {
  return FamiliesController(ref).load();
});

final familyDetailProvider = FutureProvider.autoDispose.family<FamilyDto, int>((
  ref,
  familyId,
) async {
  try {
    return await ref.read(familiesApiProvider).getFamily(familyId);
  } catch (error) {
    throw ApiError.fromObject(error);
  }
});

final familyManagementControllerProvider = Provider<FamilyManagementController>(
  FamilyManagementController.new,
);

class FamiliesController {
  const FamiliesController(this._ref);

  final Ref _ref;

  Future<List<FamilyDto>> load() async {
    try {
      return await _ref.read(familiesApiProvider).getFamilies();
    } catch (error) {
      throw ApiError.fromObject(error);
    }
  }
}

class FamilyManagementController {
  const FamilyManagementController(this._ref);

  final Ref _ref;

  Future<FamilyDto> create({
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final created = await _ref
          .read(familiesApiProvider)
          .createFamily(
            name: name,
            description: description,
            imageUrl: imageUrl,
          );
      _ref.read(selectedFamilyProvider.notifier).select(created);
      _ref.invalidate(familiesControllerProvider);
      return created;
    } catch (error) {
      appLogger.debug('Families: create controller failed: $error');
      throw ApiError.fromObject(error);
    }
  }

  Future<FamilyDto> join(String inviteCode) async {
    try {
      final joined = await _ref
          .read(familiesApiProvider)
          .joinFamily(inviteCode);
      _ref.read(selectedFamilyProvider.notifier).select(joined);
      _ref.invalidate(familiesControllerProvider);
      return joined;
    } catch (error) {
      appLogger.debug('Families: join controller failed: $error');
      throw ApiError.fromObject(error);
    }
  }

  Future<FamilyDto> update(FamilyDto family) async {
    try {
      final updated = await _ref.read(familiesApiProvider).updateFamily(family);
      if (_ref.read(selectedFamilyProvider)?.id == updated.id) {
        _ref.read(selectedFamilyProvider.notifier).select(updated);
      }
      _ref.invalidate(familiesControllerProvider);
      final familyId = updated.id;
      if (familyId != null) {
        _ref.invalidate(familyDetailProvider(familyId));
      }
      return updated;
    } catch (error) {
      appLogger.debug('Families: update controller failed: $error');
      throw ApiError.fromObject(error);
    }
  }

  Future<void> delete(FamilyDto family) async {
    final familyId = family.id;
    if (familyId == null) {
      throw const ApiError(message: 'Family id is missing.');
    }

    try {
      await _ref.read(familiesApiProvider).deleteFamily(familyId);
      _ref
          .read(selectedShoppingListProvider.notifier)
          .clearIfFamilySelected(familyId);

      final currentSelection = _ref.read(selectedFamilyProvider);
      _ref.invalidate(familiesControllerProvider);

      if (currentSelection?.id == familyId) {
        final remainingFamilies = await _ref.read(
          familiesControllerProvider.future,
        );
        final replacement = remainingFamilies.isEmpty
            ? null
            : remainingFamilies.first;
        _ref.read(selectedFamilyProvider.notifier).select(replacement);
      }
    } catch (error) {
      appLogger.debug('Families: delete controller failed: $error');
      throw ApiError.fromObject(error);
    }
  }
}
