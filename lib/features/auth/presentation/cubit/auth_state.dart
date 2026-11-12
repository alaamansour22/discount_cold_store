import 'package:equatable/equatable.dart';
import '../../../../core/error/error_handler.dart';
import '../../domain/entities/auth_user_entity.dart';

enum AuthStatus {
  initialChecking,
  authenticated,
  unauthenticated,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final bool isSubmitting;
  final AuthUserEntity? user;
  final AppFailure? failure;
  final String? successMessage;

  const AuthState({
    this.status = AuthStatus.initialChecking,
    this.isSubmitting = false,
    this.user,
    this.failure,
    this.successMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isSubmitting,
    AuthUserEntity? user,
    bool clearUser = false,
    AppFailure? failure,
    bool clearFailure = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      user: clearUser ? null : (user ?? this.user),
      failure: clearFailure ? null : (failure ?? this.failure),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [status, isSubmitting, user, failure, successMessage];
}