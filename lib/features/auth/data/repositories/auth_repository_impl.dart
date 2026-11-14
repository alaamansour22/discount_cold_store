import '../../../../core/error/error_handler.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final IAuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<AuthUserEntity?> getCurrentLoggedUser() async {
    try {
      return await _remoteDataSource.getCurrentSessionUser();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<AuthUserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _remoteDataSource.signIn(email: email, password: password);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _remoteDataSource.updatePassword(newPassword: newPassword);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<AuthUserEntity?> watchAuthStateChanges() {
    return _remoteDataSource.onAuthStateChanged();
  }
}
