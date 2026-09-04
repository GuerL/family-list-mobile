import 'package:dio/dio.dart';
import 'package:familylist/features/families/data/families_api.dart';
import 'package:familylist/features/families/data/family_models.dart';
import 'package:familylist/features/families/presentation/families_controller.dart';
import 'package:familylist/features/families/presentation/selected_family_provider.dart';
import 'package:familylist/features/shopping_lists/data/shopping_list_models.dart';
import 'package:familylist/features/shopping_lists/presentation/shopping_lists_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FamilyDto parses detail fields used by family detail', () {
    final family = FamilyDto.fromJson({
      'id': 7,
      'name': 'Default Fam',
      'description': 'Main household',
      'imageUrl': 'https://example.com/family.jpg',
      'inviteCode': 'INVITE-123',
      'isActive': true,
      'creator': {
        'id': 1,
        'fullName': 'Owner User',
        'email': 'owner@example.com',
      },
      'members': [
        {'id': 1, 'fullName': 'Owner User', 'email': 'owner@example.com'},
        {'id': 2, 'fullName': 'Member User', 'email': 'member@example.com'},
      ],
    });

    expect(family.id, 7);
    expect(family.imageUrl, 'https://example.com/family.jpg');
    expect(family.inviteCode, 'INVITE-123');
    expect(family.creator?.email, 'owner@example.com');
    expect(family.members, hasLength(2));
  });

  test(
    'creating a family sends supported fields and selects created family',
    () async {
      final api = _FakeFamiliesApi();
      final container = _containerWith(api);
      addTearDown(container.dispose);

      final created = await container
          .read(familyManagementControllerProvider)
          .create(
            name: 'New family',
            description: 'Shared home',
            imageUrl: 'https://example.com/home.jpg',
          );

      expect(api.createdFamilies.single.name, 'New family');
      expect(api.createdFamilies.single.description, 'Shared home');
      expect(
        api.createdFamilies.single.imageUrl,
        'https://example.com/home.jpg',
      );
      expect(container.read(selectedFamilyProvider), created);
    },
  );

  test('joining a family selects joined family', () async {
    final api = _FakeFamiliesApi();
    final container = _containerWith(api);
    addTearDown(container.dispose);

    final joined = await container
        .read(familyManagementControllerProvider)
        .join('INVITE-123');

    expect(api.joinedInviteCodes, ['INVITE-123']);
    expect(container.read(selectedFamilyProvider), joined);
  });

  test(
    'delete selected family selects another family and clears shopping context',
    () async {
      final deletedFamily = _family(id: 1, name: 'Deleted');
      final remainingFamily = _family(id: 2, name: 'Remaining');
      final api = _FakeFamiliesApi(familiesAfterDelete: [remainingFamily]);
      final container = _containerWith(api);
      addTearDown(container.dispose);

      container.read(selectedFamilyProvider.notifier).select(deletedFamily);
      container
          .read(selectedShoppingListProvider.notifier)
          .select(
            ShoppingListDto(
              id: 10,
              description: 'List',
              family: deletedFamily,
              listItems: const [],
            ),
          );

      await container
          .read(familyManagementControllerProvider)
          .delete(deletedFamily);

      expect(api.deletedFamilyIds, [1]);
      expect(container.read(selectedFamilyProvider)?.id, 2);
      expect(container.read(selectedShoppingListProvider), isNull);
    },
  );

  test('delete unselected family preserves current selection', () async {
    final selectedFamily = _family(id: 1, name: 'Selected');
    final deletedFamily = _family(id: 2, name: 'Deleted');
    final api = _FakeFamiliesApi(familiesAfterDelete: [selectedFamily]);
    final container = _containerWith(api);
    addTearDown(container.dispose);

    container.read(selectedFamilyProvider.notifier).select(selectedFamily);

    await container
        .read(familyManagementControllerProvider)
        .delete(deletedFamily);

    expect(api.deletedFamilyIds, [2]);
    expect(container.read(selectedFamilyProvider)?.id, 1);
  });
}

ProviderContainer _containerWith(_FakeFamiliesApi api) {
  return ProviderContainer(
    overrides: [familiesApiProvider.overrideWithValue(api)],
  );
}

FamilyDto _family({required int id, required String name}) {
  return FamilyDto(
    id: id,
    name: name,
    description: '$name description',
    members: const [],
    creator: const FamilyUserDto(email: 'owner@example.com'),
    inviteCode: 'INVITE-$id',
    isActive: true,
  );
}

class _CreateFamilyCall {
  const _CreateFamilyCall({
    required this.name,
    required this.description,
    this.imageUrl,
  });

  final String name;
  final String description;
  final String? imageUrl;
}

class _FakeFamiliesApi extends FamiliesApi {
  _FakeFamiliesApi({this.familiesAfterDelete = const []}) : super(Dio());

  final List<FamilyDto> familiesAfterDelete;
  final createdFamilies = <_CreateFamilyCall>[];
  final joinedInviteCodes = <String>[];
  final deletedFamilyIds = <int>[];

  @override
  Future<FamilyDto> createFamily({
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    createdFamilies.add(
      _CreateFamilyCall(
        name: name,
        description: description,
        imageUrl: imageUrl,
      ),
    );
    return FamilyDto(
      id: 99,
      name: name,
      description: description,
      members: const [],
      imageUrl: imageUrl,
      inviteCode: 'INVITE-99',
      isActive: true,
    );
  }

  @override
  Future<void> deleteFamily(int familyId) async {
    deletedFamilyIds.add(familyId);
  }

  @override
  Future<List<FamilyDto>> getFamilies() async {
    return familiesAfterDelete;
  }

  @override
  Future<FamilyDto> getFamily(int familyId) async {
    return _family(id: familyId, name: 'Family $familyId');
  }

  @override
  Future<FamilyDto> joinFamily(String inviteCode) async {
    joinedInviteCodes.add(inviteCode);
    return FamilyDto(
      id: 88,
      name: 'Joined family',
      description: 'Joined description',
      members: const [],
      inviteCode: inviteCode,
      isActive: true,
    );
  }

  @override
  Future<FamilyDto> updateFamily(FamilyDto family) async {
    return family;
  }
}
