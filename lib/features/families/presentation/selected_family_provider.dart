import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family_models.dart';

final selectedFamilyProvider =
    NotifierProvider<SelectedFamilyController, FamilyDto?>(
      SelectedFamilyController.new,
    );

class SelectedFamilyController extends Notifier<FamilyDto?> {
  @override
  FamilyDto? build() => null;

  void select(FamilyDto? family) {
    state = family;
  }
}
