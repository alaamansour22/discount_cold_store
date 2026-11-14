import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/receiving_entities.dart';

class ReceivingState extends Equatable {
  final bool isLoading;
  final bool isSubmitting;
  final List<ReceivingRackSlotEntity> slots;
  final List<ReceivingMovementEntity> movements;
  final String selectedZone; // 'C2' or 'C3'
  final String selectedRackLetter; // 'A' .. 'T'
  final AppFailure? failure;
  final String? successMessage;

  const ReceivingState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.slots = const [],
    this.movements = const [],
    this.selectedZone = 'C2',
    this.selectedRackLetter = 'A',
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
    List<ReceivingMovementEntity>? movements,
    String? selectedZone,
    String? selectedRackLetter,
    AppFailure? failure,
    bool clearFailure = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ReceivingState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      slots: slots ?? this.slots,
      movements: movements ?? this.movements,
      selectedZone: selectedZone ?? this.selectedZone,
      selectedRackLetter: selectedRackLetter ?? this.selectedRackLetter,
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
    movements,
    selectedZone,
    selectedRackLetter,
    failure,
    successMessage,
  ];
}
