import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/auth_user_entity.dart';

typedef AuthJsonMap = Map<String, dynamic>;

class AuthUserModel extends AuthUserEntity {
  const AuthUserModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.employeeCode,
    required super.role,
    required super.customAlertDays,
    required super.notificationsEnabled,
    required super.isActive,
  });

  factory AuthUserModel.fromUserAndProfile(User user, AuthJsonMap? profile) {
    final metaName = user.userMetadata?['full_name'] as String?;
    final fallbackName = (user.email ?? 'user').split('@').first;
    return AuthUserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: profile?['full_name'] as String? ?? metaName ?? fallbackName,
      employeeCode: profile?['employee_code'] as String?,
      role: profile?['role'] as String? ?? 'operator',
      customAlertDays: (profile?['custom_alert_days'] as num?)?.toInt() ?? 7,
      notificationsEnabled: profile?['notifications_enabled'] as bool? ?? true,
      isActive: profile?['is_active'] as bool? ?? true,
    );
  }
}

abstract class IAuthRemoteDataSource {
  Future<AuthUserModel?> getCurrentSessionUser();
  Future<AuthUserModel> signIn({required String email, required String password});
  Future<void> updatePassword({required String newPassword});
  Future<void> signOut();
  Stream<AuthUserModel?> onAuthStateChanged();
}

class AuthRemoteDataSourceImpl implements IAuthRemoteDataSource {
  final SupabaseClient _supabase;

  AuthRemoteDataSourceImpl(this._supabase);

  Future<AuthUserModel> _buildUserModel(User user) async {
    final profileData = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    final map = profileData != null ? AuthJsonMap.from(profileData as Map) : null;
    final model = AuthUserModel.fromUserAndProfile(user, map);

    if (!model.isActive) {
      await _supabase.auth.signOut();
      throw const AuthException('هذا الحساب موقوف من قبل إدارة الثلاجة.');
    }
    return model;
  }

  @override
  Future<AuthUserModel?> getCurrentSessionUser() async {
    final session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;
    if (session == null || user == null) return null;
    return _buildUserModel(user);
  }

  @override
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('تعذر التحقق من بيانات الحساب.');
    }
    return _buildUserModel(user);
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Stream<AuthUserModel?> onAuthStateChanged() {
    return _supabase.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;
      try {
        return await _buildUserModel(user);
      } catch (_) {
        return null;
      }
    });
  }
}