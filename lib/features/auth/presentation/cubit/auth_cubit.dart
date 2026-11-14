import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/usecases/auth_usecases.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthUseCases _useCases;
  StreamSubscription<AuthUserEntity?>? _authSub;

  AuthCubit(this._useCases) : super(const AuthState()) {
    checkPersistentSession();
    _authSub = _useCases.watchAuthState().listen((user) {
      if (user != null) {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isSubmitting: false,
            clearFailure: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            clearUser: true,
            isSubmitting: false,
          ),
        );
      }
    });
  }

  Future<void> checkPersistentSession() async {
    emit(
      state.copyWith(status: AuthStatus.initialChecking, clearFailure: true),
    );
    try {
      final user = await _useCases.getCurrentUser();
      if (user != null) {
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      } else {
        emit(
          state.copyWith(status: AuthStatus.unauthenticated, clearUser: true),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      final user = await _useCases.signIn(email: email, password: password);
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isSubmitting: false,
          clearFailure: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isSubmitting: false,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<bool> changePassword({required String newPassword}) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      await _useCases.updatePassword(newPassword: newPassword);
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'تم تغيير كلمة المرور بنجاح',
        ),
      );
      return true;
    } catch (e) {
      emit(
        state.copyWith(isSubmitting: false, failure: ErrorHandler.handle(e)),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      await _useCases.signOut();
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isSubmitting: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(isSubmitting: false, failure: ErrorHandler.handle(e)),
      );
    }
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
