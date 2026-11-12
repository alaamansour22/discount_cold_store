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

  const AppFailure({
    required this.message,
    required this.type,
    this.code,
  });

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
        message: 'الكمية المطلوبة أكبر من الرصيد الفعلي المتاح حالياً على البالتة.',
        code: 'INSUFFICIENT_QUANTITY',
        type: FailureType.insufficientQuantity,
      );
    }
    if (raw.contains('ITEM_NOT_AVAILABLE')) {
      return const AppFailure(
        message: 'هذا الصنف لم يعد متاحاً بالرصيد (تم صرفه أو إعدامه بواسطة مستخدم آخر).',
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

    if (msg.contains('ITEM_NOT_AVAILABLE') || msg.contains('PALLET_NOT_ACTIVE')) {
      return const AppFailure(
        message: 'الصنف أو البالتة لم تعد متاحة بالرصيد (تم صرفها أو إعدامها للتو بواسطة زميل آخر).',
        code: 'ITEM_NOT_AVAILABLE',
        type: FailureType.concurrencyConflict,
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

    return AppFailure(
      message: 'خطأ من قاعدة البيانات: ${e.message}',
      code: e.code,
      type: FailureType.serverError,
    );
  }
}