import '../entities/auth_user_entity.dart';

abstract class IAuthRepository {
  Future<AuthUserEntity?> getCurrentLoggedUser();

  Future<AuthUserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> updatePassword({required String newPassword});

  Future<void> signOut();

  Stream<AuthUserEntity?> watchAuthStateChanges();
}
