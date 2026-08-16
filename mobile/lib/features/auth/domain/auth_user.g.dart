// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthUser _$AuthUserFromJson(Map<String, dynamic> json) => _AuthUser(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  role: json['role'] as String,
);

Map<String, dynamic> _$AuthUserToJson(_AuthUser instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'role': instance.role,
};

_AuthSession _$AuthSessionFromJson(Map<String, dynamic> json) => _AuthSession(
  user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  token: json['token'] as String,
  refreshToken: json['refreshToken'] as String?,
);

Map<String, dynamic> _$AuthSessionToJson(_AuthSession instance) =>
    <String, dynamic>{
      'user': instance.user,
      'token': instance.token,
      'refreshToken': instance.refreshToken,
    };
