import 'package:equatable/equatable.dart';

class NotificationSettingsEntity extends Equatable {
  final int globalThresholdDays;
  final int userCustomAlertDays;
  final bool notificationsEnabled;
  final bool receiveMondayAlert;

  const NotificationSettingsEntity({
    this.globalThresholdDays = 7,
    this.userCustomAlertDays = 7,
    this.notificationsEnabled = true,
    this.receiveMondayAlert = true,
  });

  @override
  List<Object?> get props => [
    globalThresholdDays,
    userCustomAlertDays,
    notificationsEnabled,
    receiveMondayAlert,
  ];
}
