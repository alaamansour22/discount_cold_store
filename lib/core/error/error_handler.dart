import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// نوع الخطأ لتسهيل التعامل معه في الـ UI (مثلاً إظهار زر تحديث عند تعارض التزامن)
enum FailureType {
  concurrencyConflict,
  insufficientQuantity,
  validationError,
  unauthorized,
  networkError,
  serverError,
}

class AppFailure extends Equatable implements Exception {
  final String message;
  final String? code;
  final FailureType type;

  const AppFailure({required this.message, required this.type, this.code});

  @override
  String toString() => message;

  @override
  List<Object?> get props => [message, code, type];
}

class ErrorHandler {
  const ErrorHandler._();

  static AppFailure handle(Object error) {
    if (error is AppFailure) return error;

    if (error is PostgrestException) {
      return _mapPostgrestException(error);
    }

    if (error is AuthException) {
      return AppFailure(
        message: 'جلسة الدخول انتهت أو غير مصرح لك بالعملية: ${error.message}',
        code: error.statusCode,
        type: FailureType.unauthorized,
      );
    }

    if (error is SocketException) {
      return const AppFailure(
        message: 'لا يوجد اتصال بالإنترنت، تأكد من الشبكة وحاول مرة أخرى.',
        type: FailureType.networkError,
      );
    }

    final raw = error.toString();
    if (raw.contains('SLOT_ALREADY_OCCUPIED')) {
      return const AppFailure(
        message: 'تنبيه تزامن: هذه البنة تم تسكينها للتو بواسطة مستخدم آخر! تم تحديث الراك.',
        code: 'SLOT_ALREADY_OCCUPIED',
        type: FailureType.concurrencyConflict,
      );
    }
    if (raw.contains('INSUFFICIENT_QUANTITY')) {
      return const AppFailure(
        message:
            'الكمية المطلوبة أكبر من الرصيد الفعلي المتاح حالياً على البالتة.',
        code: 'INSUFFICIENT_QUANTITY',
        type: FailureType.insufficientQuantity,
      );
    }
    if (raw.contains('ITEM_NOT_AVAILABLE')) {
      return const AppFailure(
        message: 'هذا الصنف لم يعد متاحاً بالرصيد (تم صرفه أو إعدامه أو حذفه بواسطة مستخدم آخر).',
        code: 'ITEM_NOT_AVAILABLE',
        type: FailureType.concurrencyConflict,
      );
    }

    return AppFailure(
      message: 'حدث خطأ غير متوقع: ${raw.replaceAll('Exception: ', '')}',
      type: FailureType.serverError,
    );
  }

  static AppFailure _mapPostgrestException(PostgrestException e) {
    final msg = e.message;
if (msg.contains('EMAIL_ALREADY_EXISTS')) {
      return const AppFailure(
        message: 'البريد الإلكتروني مسجل بالفعل لمستخدم آخر.',
        code: 'EMAIL_ALREADY_EXISTS',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('EMPLOYEE_CODE_EXISTS') ||
        msg.contains('profiles_employee_code_key')) {
      return const AppFailure(
        message: 'كود الموظف مسجل بالفعل لمستخدم آخر.',
        code: 'EMPLOYEE_CODE_EXISTS',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('ADMIN_ONLY')) {
      return const AppFailure(
        message: 'غير مصرح: إدارة حسابات المستخدمين متاحة لمدير النظام فقط.',
        code: 'ADMIN_ONLY',
        type: FailureType.unauthorized,
      );
    }
if (msg.contains('CANNOT_DELETE_SELF')) {
      return const AppFailure(
        message: 'لا يمكنك حذف حسابك الشخصي أثناء تسجيل الدخول به.',
        code: 'CANNOT_DELETE_SELF',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('CANNOT_DELETE_LAST_ADMIN')) {
      return const AppFailure(
        message: 'لا يمكن حذف آخر مدير نظام نشط في الثلاجة.',
        code: 'CANNOT_DELETE_LAST_ADMIN',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('USER_NOT_FOUND')) {
      return const AppFailure(
        message: 'حساب الموظف غير موجود أو تم حذفه بالفعل.',
        code: 'USER_NOT_FOUND',
        type: FailureType.concurrencyConflict,
      );
    }

    if (msg.contains('USER_ALREADY_DEACTIVATED')) {
      return const AppFailure(
        message:
            'هذا الحساب موقوف بالفعل ومحفوظ للأرشفة لوجود حركات مخزنية مسجلة عليه.',
        code: 'USER_ALREADY_DEACTIVATED',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('USER_HAS_HISTORY_RETRY')) {
      return const AppFailure(
        message:
            'تم تسجيل حركة جديدة لهذا الموظف، يرجى المحاولة مرة أخرى لإيقاف الحساب بأمان.',
        code: 'USER_HAS_HISTORY_RETRY',
        type: FailureType.concurrencyConflict,
      );
    }

    if (msg.contains('FULL_NAME_REQUIRED')) {
      return const AppFailure(
        message: 'يرجى إدخال اسم الموظف بشكل صحيح.',
        code: 'FULL_NAME_REQUIRED',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('EMPLOYEE_CODE_REQUIRED')) {
      return const AppFailure(
        message: 'يرجى إدخال كود الموظف.',
        code: 'EMPLOYEE_CODE_REQUIRED',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('INVALID_EMAIL')) {
      return const AppFailure(
        message: 'صيغة البريد الإلكتروني غير صحيحة.',
        code: 'INVALID_EMAIL',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('WEAK_PASSWORD')) {
      return const AppFailure(
        message: 'كلمة المرور يجب أن تكون بين 6 و 72 حرفاً.',
        code: 'WEAK_PASSWORD',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('INVALID_ROLE')) {
      return const AppFailure(
        message: 'الصلاحية المختارة غير معتمدة.',
        code: 'INVALID_ROLE',
        type: FailureType.validationError,
      );
    }
    if (msg.contains('SLOT_ALREADY_OCCUPIED') || e.code == '23505') {
      return const AppFailure(
        message: 'تنبيه تزامن: الموقع مشغول بالفعل ببالتة أخرى (تم تسكينه بواسطة مستخدم آخر).',
        code: 'SLOT_ALREADY_OCCUPIED',
        type: FailureType.concurrencyConflict,
      );
    }

    if (msg.contains('INSUFFICIENT_QUANTITY')) {
      return AppFailure(
        message: msg.split('INSUFFICIENT_QUANTITY:').last.trim(),
        code: 'INSUFFICIENT_QUANTITY',
        type: FailureType.insufficientQuantity,
      );
    }

    if (msg.contains('ITEM_NOT_AVAILABLE') ||
        msg.contains('PALLET_NOT_ACTIVE') ||
        msg.contains('PALLET_NOT_FOUND')) {
      return const AppFailure(
        message: 'الصنف أو البالتة لم تعد متاحة بالرصيد (تم صرفها أو إعدامها أو حذفها للتو).',
        code: 'ITEM_NOT_AVAILABLE',
        type: FailureType.concurrencyConflict,
      );
    }

    if (msg.contains('ITEM_HAS_DISPATCH_HISTORY') ||
        msg.contains('ITEM_HAS_OFFICIAL_MOVEMENTS')) {
      return const AppFailure(
        message:
            'لا يمكن حذف هذا الصنف لوجود مستند صرف رسمي مرتبط به. استخدم عكس مستند الصرف أو تعديل الكمية.',
        code: 'ITEM_HAS_DISPATCH_HISTORY',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('ITEM_HAS_CONDEMNATION_HISTORY')) {
      return const AppFailure(
        message: 'لا يمكن حذف هذا الصنف لوجود سجل إعدام معتمد مرتبط به.',
        code: 'ITEM_HAS_CONDEMNATION_HISTORY',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('PALLET_HAS_DISPATCH_HISTORY') ||
        msg.contains('PALLET_HAS_OFFICIAL_MOVEMENTS')) {
      return const AppFailure(
        message:
            'لا يمكن حذف هذه البالتة لوجود مستند صرف رسمي مرتبط بها. استخدم عكس مستند الصرف أو التعديل.',
        code: 'PALLET_HAS_DISPATCH_HISTORY',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('PALLET_HAS_CONDEMNATION_HISTORY')) {
      return const AppFailure(
        message: 'لا يمكن حذف هذه البالتة لوجود سجل إعدام معتمد مرتبط بها.',
        code: 'PALLET_HAS_CONDEMNATION_HISTORY',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('DELETE_FORBIDDEN')) {
      return const AppFailure(
        message:
            'غير مصرح لك بحذف سجل قام مستخدم آخر بإدخاله (متاح للمدير أو لمنفذ العملية).',
        code: 'DELETE_FORBIDDEN',
        type: FailureType.unauthorized,
      );
    }

    if (msg.contains('REASON_REQUIRED')) {
      return const AppFailure(
        message: 'يرجى كتابة سبب الحذف قبل التأكيد.',
        code: 'REASON_REQUIRED',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('REASON_TOO_LONG')) {
      return const AppFailure(
        message: 'سبب الحذف أطول من الحد المسموح (500 حرف).',
        code: 'REASON_TOO_LONG',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('TARGET_SLOT_OCCUPIED')) {
      return const AppFailure(
        message: 'الموقع المستهدف للنقل مشغول حالياً ببالتة أخرى.',
        code: 'TARGET_SLOT_OCCUPIED',
        type: FailureType.concurrencyConflict,
      );
    }

    if (msg.contains('SAME_SLOT')) {
      return const AppFailure(
        message: 'البالتة موجودة بالفعل في هذا الموقع.',
        code: 'SAME_SLOT',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('INVALID_DATES')) {
      return const AppFailure(
        message: 'تاريخ الانتهاء يجب أن يكون بعد تاريخ الإنتاج.',
        code: 'INVALID_DATES',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('UNAUTHORIZED')) {
      return const AppFailure(
        message: 'يجب تسجيل الدخول أولاً لتنفيذ هذه العملية.',
        code: 'UNAUTHORIZED',
        type: FailureType.unauthorized,
      );
    }

    if (msg.contains('EMPTY_PALLET')) {
      return const AppFailure(
        message: 'يجب إضافة صنف واحد على الأقل قبل الحفظ.',
        code: 'EMPTY_PALLET',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('INVALID_ITEM_NAME')) {
      return const AppFailure(
        message: 'يرجى إدخال اسم الصنف بشكل صحيح.',
        code: 'INVALID_ITEM_NAME',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('INVALID_QUANTITY') ||
        msg.contains('INVALID_RELEASE_QUANTITY')) {
      return const AppFailure(
        message: 'الكمية المدخلة غير صحيحة أو تتجاوز الرصيد المتاح.',
        code: 'INVALID_QUANTITY',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('INVALID_DAYS')) {
      return const AppFailure(
        message: 'عدد أيام التنبيه يجب أن يكون بين 1 و 365 يوماً.',
        code: 'INVALID_DAYS',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('NOTES_TOO_LONG')) {
      return const AppFailure(
        message: 'الملاحظات أطول من الحد المسموح (500 حرف).',
        code: 'NOTES_TOO_LONG',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('PALLET_NOT_IN_STOCK') ||
        msg.contains('PALLET_SLOT_NOT_FOUND')) {
      return const AppFailure(
        message:
            'البالتة لم تعد متاحة في موقعها الحالي (تم نقلها أو صرفها للتو). تم تحديث البيانات.',
        code: 'PALLET_NOT_IN_STOCK',
        type: FailureType.concurrencyConflict,
      );
    }

    if (msg.contains('SLOT_NOT_FOUND') ||
        msg.contains('TARGET_SLOT_NOT_FOUND')) {
      return const AppFailure(
        message: 'موقع الراك المختار غير موجود أو غير نشط حالياً.',
        code: 'SLOT_NOT_FOUND',
        type: FailureType.validationError,
      );
    }

    if (msg.contains('INVALID_REPORT_KEY') ||
        msg.contains('UNSUPPORTED_ACTION')) {
      return const AppFailure(
        message: 'نوع العملية أو التقرير المطلوب غير مدعوم.',
        code: 'UNSUPPORTED_ACTION',
        type: FailureType.validationError,
      );
    }

    return AppFailure(
      message: 'خطأ من قاعدة البيانات: ${e.message}',
      code: e.code,
      type: FailureType.serverError,
    );
  }



  
}