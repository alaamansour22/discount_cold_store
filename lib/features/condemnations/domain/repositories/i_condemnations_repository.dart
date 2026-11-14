import '../entities/condemnations_entities.dart';

abstract class ICondemnationsRepository {
  /// جلب الأصناف المستحقة للإعدام حالياً + حدود التنبيه (العام والخاص بالمستخدم)
  Future<
    ({
      List<CondemnationAlertItemEntity> alertItems,
      int globalThresholdDays,
      int userCustomAlertDays,
    })
  >
  getActiveCondemnationAlerts();

  /// جلب سجل الإعدامات الفعلي مع دعم الفلترة من تاريخ إلى تاريخ
  Future<List<CondemnationHistoryRecordEntity>> getCondemnationRecords({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 300,
  });

  /// اعتماد إعدام صنف (جزئياً أو كلياً) عبر الدالة الذرية rpc_adjust_or_release_item
  Future<void> approveItemCondemnation({
    required String palletItemId,
    required double quantityToCondemn,
    required String reason,
  });

  /// متابعة التحديثات اللحظية للراكات وسجل الإعدامات
  Stream<void> watchRealtimeCondemnationChanges();
}
