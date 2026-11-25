import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/admin_user_entity.dart';
import '../../domain/entities/notification_settings_entity.dart';

class SettingsState extends Equatable {
  final bool isLoading;
  final bool isSubmitting;
  final NotificationSettingsEntity settings;

  // إدارة الموظفين والصلاحيات للأدمن (Server-Side Pagination & Search)
  final bool isUsersLoading;
  final bool usersInitialized;
  final AdminUsersPageEntity usersData;
  final AdminUsersFilter usersFilter;
  final Set<String> updatingUserIds;
  final AppFailure? usersFailure;

  final AppFailure? failure;
  final String? successMessage;

  const SettingsState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.settings = const NotificationSettingsEntity(),
    this.isUsersLoading = false,
    this.usersInitialized = false,
    this.usersData = const AdminUsersPageEntity.empty(),
    this.usersFilter = const AdminUsersFilter(),
    this.updatingUserIds = const {},
    this.usersFailure,
    this.failure,
    this.successMessage,
  });

  SettingsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    NotificationSettingsEntity? settings,
    bool? isUsersLoading,
    bool? usersInitialized,
    AdminUsersPageEntity? usersData,
    AdminUsersFilter? usersFilter,
    Set<String>? updatingUserIds,
    AppFailure? usersFailure,
    bool clearUsersFailure = false,
    AppFailure? failure,
    bool clearFailure = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      settings: settings ?? this.settings,
      isUsersLoading: isUsersLoading ?? this.isUsersLoading,
      usersInitialized: usersInitialized ?? this.usersInitialized,
      usersData: usersData ?? this.usersData,
      usersFilter: usersFilter ?? this.usersFilter,
      updatingUserIds: updatingUserIds ?? this.updatingUserIds,
      usersFailure: clearUsersFailure
          ? null
          : (usersFailure ?? this.usersFailure),
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
    isUsersLoading,
    usersInitialized,
    usersData,
    usersFilter,
    updatingUserIds,
    usersFailure,
    failure,
    successMessage,
  ];
}