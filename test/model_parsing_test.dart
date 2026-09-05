import 'package:familylist/features/authentication/data/auth_models.dart';
import 'package:familylist/features/families/data/family_models.dart';
import 'package:familylist/features/shopping_lists/data/shopping_list_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses current AuthUserDto JSON', () {
    final user = AuthUserDto.fromJson({
      'fullName': 'Test User',
      'email': 'test@example.com',
      'roles': ['ROLE_USER'],
      'iat': 1000,
      'exp': 2000,
    });

    expect(user.email, 'test@example.com');
    expect(user.roles.single, 'ROLE_USER');
  });

  test('maps register request JSON', () {
    const request = RegisterUserDto(
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      password: 'secret',
    );

    expect(request.toJson(), {
      'email': 'test@example.com',
      'password': 'secret',
      'firstName': 'Test',
      'lastName': 'User',
    });
  });

  test('parses current FamilyDto JSON', () {
    final family = FamilyDto.fromJson({
      'id': 1,
      'name': 'Default Fam',
      'description': 'Default Fam',
      'members': [
        {'id': 10, 'fullName': 'Owner User', 'email': 'owner@example.com'},
      ],
      'creator': {
        'id': 10,
        'fullName': 'Owner User',
        'email': 'owner@example.com',
      },
      'imageUrl': '',
      'inviteCode': 'abc',
      'isActive': true,
    });

    expect(family.id, 1);
    expect(family.members.single.email, 'owner@example.com');
    expect(family.isActive, isTrue);
  });

  test('parses current FamilyListDto JSON', () {
    final list = ShoppingListDto.fromJson({
      'id': 12,
      'description': 'Weekend shopping',
      'family': {
        'id': 1,
        'name': 'Default Fam',
        'description': 'Default Fam',
        'members': [],
        'creator': null,
        'imageUrl': '',
        'inviteCode': 'abc',
        'isActive': true,
      },
      'listItems': [
        {'id': 1, 'description': 'Milk', 'quantity': 1, 'purchased': false},
        {'id': 2, 'description': 'Bread', 'quantity': 1, 'purchased': true},
      ],
      'createdAt': '2026-09-03T12:30:00',
    });

    expect(list.description, 'Weekend shopping');
    expect(list.itemCount, 2);
    expect(list.remainingItemCount, 1);
  });
}
