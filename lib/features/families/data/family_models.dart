import 'package:json_annotation/json_annotation.dart';

part 'family_models.g.dart';

@JsonSerializable()
class FamilyDto {
  const FamilyDto({
    this.id,
    required this.name,
    required this.description,
    required this.members,
    this.creator,
    this.imageUrl,
    this.inviteCode,
    this.isActive,
  });

  final int? id;
  final String name;
  final String description;
  @JsonKey(defaultValue: <FamilyUserDto>[])
  final List<FamilyUserDto> members;
  final FamilyUserDto? creator;
  final String? imageUrl;
  final String? inviteCode;
  final bool? isActive;

  factory FamilyDto.fromJson(Map<String, dynamic> json) =>
      _$FamilyDtoFromJson(json);

  Map<String, dynamic> toJson() => _$FamilyDtoToJson(this);
}

@JsonSerializable()
class FamilyUserDto {
  const FamilyUserDto({this.id, this.fullName, this.email});

  final int? id;
  final String? fullName;
  final String? email;

  factory FamilyUserDto.fromJson(Map<String, dynamic> json) =>
      _$FamilyUserDtoFromJson(json);

  Map<String, dynamic> toJson() => _$FamilyUserDtoToJson(this);
}
