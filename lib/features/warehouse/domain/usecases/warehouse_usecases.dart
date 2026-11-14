import '../../../receiving/domain/entities/receiving_entities.dart';
import '../repositories/i_warehouse_repository.dart';

class GetWarehouseRackSlotsUseCase {
  final IWarehouseRepository repository;
  const GetWarehouseRackSlotsUseCase(this.repository);
  Future<List<ReceivingRackSlotEntity>> call() =>
      repository.getRackSlotsWithPallets();
}

class WatchWarehouseUpdatesUseCase {
  final IWarehouseRepository repository;
  const WatchWarehouseUpdatesUseCase(this.repository);
  Stream<void> call() => repository.watchRackUpdates();
}

class WarehouseUseCases {
  final GetWarehouseRackSlotsUseCase getRackSlots;
  final WatchWarehouseUpdatesUseCase watchUpdates;
  WarehouseUseCases(IWarehouseRepository repository)
    : getRackSlots = GetWarehouseRackSlotsUseCase(repository),
      watchUpdates = WatchWarehouseUpdatesUseCase(repository);
}
