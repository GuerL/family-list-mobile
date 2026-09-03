import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../data/families_api.dart';
import '../data/family_models.dart';

final familiesControllerProvider = FutureProvider.autoDispose<List<FamilyDto>>((
  ref,
) async {
  return FamiliesController(ref).load();
});

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
