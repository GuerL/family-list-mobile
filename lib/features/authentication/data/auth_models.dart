import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

@JsonSerializable()
class LoginUserDto {
  const LoginUserDto({required this.email, required this.password});

  final String email;
  final String password;

  factory LoginUserDto.fromJson(Map<String, dynamic> json) =>
      _$LoginUserDtoFromJson(json);

  Map<String, dynamic> toJson() => _$LoginUserDtoToJson(this);
}

@JsonSerializable()
class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

@JsonSerializable()
class AuthUserDto {
  const AuthUserDto({
    required this.fullName,
    required this.email,
    required this.roles,
    this.iat,
    this.exp,
  });

  final String? fullName;
  final String email;
  @JsonKey(defaultValue: <String>[])
  final List<String> roles;
  final int? iat;
  final int? exp;

  factory AuthUserDto.fromJson(Map<String, dynamic> json) =>
      _$AuthUserDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AuthUserDtoToJson(this);
}

class AuthSession {
  const AuthSession({required this.user});

  final AuthUserDto user;
}
