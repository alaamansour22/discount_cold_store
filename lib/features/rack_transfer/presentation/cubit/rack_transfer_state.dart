import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/rack_transfer_entities.dart';

class RackTransferState extends Equatable {
  final bool isLoading;
  final bool isSubmitting;
  final List<TransferSlotEntity> allSlots;
  final List<RackTransferHistoryEntity> history;
  final String? selectedSourceSlotId;
  final String? selectedTargetSlotId;
  final String targetZoneFilter; // 'ALL' | 'C2' | 'C3'
  final AppFailure? failure;
  final String? successMessage;

  const RackTransferState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.allSlots = const [],
    this.history = const [],
    this.selectedSourceSlotId,
    this.selectedTargetSlotId,
    this.targetZoneFilter = 'ALL',
    this.failure,
    this.successMessage,
  });

  List<TransferSlotEntity> get occupiedSlots =>
      allSlots.where((s) => s.isOccupied && s.palletId != null).toList();

  List<TransferSlotEntity> get filteredEmptySlots => allSlots.where((s) {
    if (s.isOccupied) return false;
    if (targetZoneFilter == 'ALL') return true;
    return s.zoneCode == targetZoneFilter;
  }).toList();

  TransferSlotEntity? get selectedSourceSlot {
    final occ = occupiedSlots;
    if (occ.isEmpty) return null;
    if (selectedSourceSlotId != null) {
      final match = occ.where((s) => s.slotId == selectedSourceSlotId).toList();
      if (match.isNotEmpty) return match.first;
    }
    return occ.first;
  }

  TransferSlotEntity? get selectedTargetSlot {
    final emp = filteredEmptySlots;
    if (emp.isEmpty) return null;
    if (selectedTargetSlotId != null) {
      final match = emp.where((s) => s.slotId == selectedTargetSlotId).toList();
      if (match.isNotEmpty) return match.first;
    }
    return emp.first;
  }

  RackTransferState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<TransferSlotEntity>? allSlots,
    List<RackTransferHistoryEntity>? history,
    String? selectedSourceSlotId,
    String? selectedTargetSlotId,
    String? targetZoneFilter,
    AppFailure? failure,
    bool clearFailure = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return RackTransferState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      allSlots: allSlots ?? this.allSlots,
      history: history ?? this.history,
      selectedSourceSlotId: selectedSourceSlotId ?? this.selectedSourceSlotId,
      selectedTargetSlotId: selectedTargetSlotId ?? this.selectedTargetSlotId,
      targetZoneFilter: targetZoneFilter ?? this.targetZoneFilter,
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
    allSlots,
    history,
    selectedSourceSlotId,
    selectedTargetSlotId,
    targetZoneFilter,
    failure,
    successMessage,
  ];
}
