import '../../../../core/error/error_handler.dart';
import '../entities/auth_user_entity.dart';
import '../repositories/i_auth_repository.dart';

class GetCurrentLoggedUserUseCase {
  final IAuthRepository _repository;
  const GetCurrentLoggedUserUseCase(this._repository);

  Future<AuthUserEntity?> call() => _repository.getCurrentLoggedUser();
}

class SignInUseCase {
  final IAuthRepository _repository;
  const SignInUseCase(this._repository);

  Future<AuthUserEntity> call({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw const AppFailure(
        message: 'يرجى إدخال بريد إلكتروني صحيح.',
        type: FailureType.validationError,
      );
    }
    if (password.length < 6) {
      throw const AppFailure(
        message: 'كلمة المرور يجب ألا تقل عن 6 أحرف.',
        type: FailureType.validationError,
      );
    }
    return _repository.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }
}

class UpdatePasswordUseCase {
  final IAuthRepository _repository;
  const UpdatePasswordUseCase(this._repository);

  Future<void> call({required String newPassword}) async {
    if (newPassword.trim().length < 6) {
      throw const AppFailure(
        message: 'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف.',
        type: FailureType.validationError,
      );
    }
    return _repository.updatePassword(newPassword: newPassword.trim());
  }
}

class SignOutUseCase {
  final IAuthRepository _repository;
  const SignOutUseCase(this._repository);

  Future<void> call() => _repository.signOut();
}

class WatchAuthStateChangesUseCase {
  final IAuthRepository _repository;
  const WatchAuthStateChangesUseCase(this._repository);

  Stream<AuthUserEntity?> call() => _repository.watchAuthStateChanges();
}

/// حزمة UseCases مجمعة لموديول Auth لسهولة حقنها في AuthCubit
class AuthUseCases {
  final GetCurrentLoggedUserUseCase getCurrentUser;
  final SignInUseCase signIn;
  final UpdatePasswordUseCase updatePassword;
  final SignOutUseCase signOut;
  final WatchAuthStateChangesUseCase watchAuthState;

  AuthUseCases(IAuthRepository repository)
    : getCurrentUser = GetCurrentLoggedUserUseCase(repository),
      signIn = SignInUseCase(repository),
      updatePassword = UpdatePasswordUseCase(repository),
      signOut = SignOutUseCase(repository),
      watchAuthState = WatchAuthStateChangesUseCase(repository);
}
