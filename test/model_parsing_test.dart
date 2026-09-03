import 'package:familylist/features/authentication/data/auth_models.dart';
import 'package:familylist/features/families/data/family_models.dart';
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
}
