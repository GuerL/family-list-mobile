// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FamilyDto _$FamilyDtoFromJson(Map<String, dynamic> json) => FamilyDto(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String,
  description: json['description'] as String,
  members:
      (json['members'] as List<dynamic>?)
          ?.map((e) => FamilyUserDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  creator: json['creator'] == null
      ? null
      : FamilyUserDto.fromJson(json['creator'] as Map<String, dynamic>),
  imageUrl: json['imageUrl'] as String?,
  inviteCode: json['inviteCode'] as String?,
  isActive: json['isActive'] as bool?,
);

Map<String, dynamic> _$FamilyDtoToJson(FamilyDto instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'members': instance.members,
  'creator': instance.creator,
  'imageUrl': instance.imageUrl,
  'inviteCode': instance.inviteCode,
  'isActive': instance.isActive,
};

FamilyUserDto _$FamilyUserDtoFromJson(Map<String, dynamic> json) =>
    FamilyUserDto(
      id: (json['id'] as num?)?.toInt(),
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$FamilyUserDtoToJson(FamilyUserDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'email': instance.email,
    };
