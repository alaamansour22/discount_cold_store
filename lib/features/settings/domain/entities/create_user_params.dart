import 'package:equatable/equatable.dart';

/// الصلاحيات المعتمدة في قاعدة البيانات (جدول public.profiles)
enum AppUserRole {
  operator('operator', 'مشغل', 'تنفيذ عمليات الاستلام والتسكين والتحويل والصرف'),
  supervisor('supervisor', 'مشرف', 'متابعة العمليات المخزنية والمراجعة اليومية'),
  qualityInspector(
    'quality_inspector',
    'مراقب جودة',
    'مراجعة الصلاحيات وعمليات فحص الجودة والإعدامات',
  ),
  admin('admin', 'مدير النظام', 'كامل الصلاحيات وإدارة المستخدمين وتعيين الأدوار');

  final String dbValue;
  final String arLabel;
  final String description;

  const AppUserRole(this.dbValue, this.arLabel, this.description);
}

/// نتيجة تنفيذ حذف حساب الموظف من قاعدة البيانات
enum UserDeletionMode {
  hardDeleted('hard_deleted'),
  deactivatedHasHistory('deactivated_has_history');

  final String dbValue;
  const UserDeletionMode(this.dbValue);

  static UserDeletionMode fromDb(String? value) {
    if (value == 'deactivated_has_history') {
      return UserDeletionMode.deactivatedHasHistory;
    }
    return UserDeletionMode.hardDeleted;
  }
}

class CreateUserParams extends Equatable {
  final String fullName;
  final String employeeCode;
  final String email;
  final String password;
  final AppUserRole role;
  final bool grantDispatchReversal;

  const CreateUserParams({
    required this.fullName,
    required this.employeeCode,
    required this.email,
    required this.password,
    required this.role,
    this.grantDispatchReversal = false,
  });

  @override
  List<Object?> get props => [
    fullName,
    employeeCode,
    email,
    role,
    grantDispatchReversal,
  ];
}