import 'package:equatable/equatable.dart';

class AuthUserEntity extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String? employeeCode;
  final String role; // 'admin', 'supervisor', 'operator', 'quality_inspector'
  final int customAlertDays;
  final bool notificationsEnabled;
  final bool isActive;

  const AuthUserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    this.employeeCode,
    required this.role,
    required this.customAlertDays,
    required this.notificationsEnabled,
    required this.isActive,
  });

  bool get isAdminOrSupervisor => role == 'admin' || role == 'supervisor';

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    employeeCode,
    role,
    customAlertDays,
    notificationsEnabled,
    isActive,
  ];
}
