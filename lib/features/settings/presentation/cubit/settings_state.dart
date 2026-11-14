import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/notification_settings_entity.dart';

class SettingsState extends Equatable {
  final bool isLoading;
  final bool isSubmitting;
  final NotificationSettingsEntity settings;
  final AppFailure? failure;
  final String? successMessage;

  const SettingsState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.settings = const NotificationSettingsEntity(),
    this.failure,
    this.successMessage,
  });

  SettingsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    NotificationSettingsEntity? settings,
    AppFailure? failure,
    bool clearFailure = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      settings: settings ?? this.settings,
      failure: clearFailure ? null : (failure ?? this.failure),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSubmitting,
    settings,
    failure,
    successMessage,
  ];
}
