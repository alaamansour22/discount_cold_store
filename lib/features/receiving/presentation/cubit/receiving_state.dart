import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/receiving_entities.dart';

class ReceivingState extends Equatable {
  final bool isLoading;
  final bool isSubmitting;
  final List<ReceivingRackSlotEntity> slots;
  final String selectedZone; // 'C2' or 'C3'
  final String selectedRackLetter; // 'A' .. 'T'

  // حالة سجل الاستلامات (مجمّع ومُرقّم بالكامل من قاعدة البيانات)
  final bool isReceiptsLoading;
  final bool receiptsInitialized;
  final ReceiptsHistoryPageEntity receiptsHistory;
  final ReceiptsHistoryFilter receiptsFilter;

  final AppFailure? failure;
  final String? successMessage;

  const ReceivingState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.slots = const [],
    this.selectedZone = 'C2',
    this.selectedRackLetter = 'A',
    this.isReceiptsLoading = false,
    this.receiptsInitialized = false,
    this.receiptsHistory = const ReceiptsHistoryPageEntity.empty(),
    this.receiptsFilter = const ReceiptsHistoryFilter(),
    this.failure,
    this.successMessage,
  });

  List<ReceivingRackSlotEntity> get currentRackSlots => slots
      .where(
        (s) => s.zoneCode == selectedZone && s.rackLetter == selectedRackLetter,
      )
      .toList();

  List<ReceivingPalletItemEntity> get allActiveItems {
    final list = <ReceivingPalletItemEntity>[];
    for (final s in slots) {
      if (s.occupiedPallet != null) {
        list.addAll(s.occupiedPallet!.items);
      }
    }
    return list;
  }

  ReceivingState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<ReceivingRackSlotEntity>? slots,
    String? selectedZone,
    String? selectedRackLetter,
    bool? isReceiptsLoading,
    bool? receiptsInitialized,
    ReceiptsHistoryPageEntity? receiptsHistory,
    ReceiptsHistoryFilter? receiptsFilter,
    AppFailure? failure,
    bool clearFailure = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ReceivingState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      slots: slots ?? this.slots,
      selectedZone: selectedZone ?? this.selectedZone,
      selectedRackLetter: selectedRackLetter ?? this.selectedRackLetter,
      isReceiptsLoading: isReceiptsLoading ?? this.isReceiptsLoading,
      receiptsInitialized: receiptsInitialized ?? this.receiptsInitialized,
      receiptsHistory: receiptsHistory ?? this.receiptsHistory,
      receiptsFilter: receiptsFilter ?? this.receiptsFilter,
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
    slots,
    selectedZone,
    selectedRackLetter,
    isReceiptsLoading,
    receiptsInitialized,
    receiptsHistory,
    receiptsFilter,
    failure,
    successMessage,
  ];
}