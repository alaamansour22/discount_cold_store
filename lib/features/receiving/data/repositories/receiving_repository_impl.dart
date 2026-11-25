import '../../../../core/error/error_handler.dart';
import '../../domain/entities/receiving_entities.dart';
import '../../domain/repositories/i_receiving_repository.dart';
import '../datasources/receiving_remote_data_source.dart';

class ReceivingRepositoryImpl implements IReceivingRepository {
  final IReceivingRemoteDataSource _remoteDataSource;

  ReceivingRepositoryImpl(this._remoteDataSource);

 @override
  Future<ReceiptsHistoryPageEntity> getReceiptsHistoryPaginated(
    ReceiptsHistoryFilter filter,
  ) async {
    try {
      return await _remoteDataSource.fetchReceiptsHistoryPaginated(filter);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> receiveNewPallet({
    required ReceivingSource sourceEntity,
    required String slotId,
    required List<PalletItemDraft> items,
  }) async {
    try {
      await _remoteDataSource.rpcReceivePallet(
        sourceEntity: sourceEntity,
        slotId: slotId,
        items: items,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> addItemsToExistingPallet({
    required String palletId,
    required ReceivingSource sourceEntity,
    required List<PalletItemDraft> items,
  }) async {
    try {
      await _remoteDataSource.rpcAddItemsToExistingPallet(
        palletId: palletId,
        sourceEntity: sourceEntity,
        items: items,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> adjustOrReleaseItem({
    required String palletItemId,
    required MovementActionType action,
    required double targetQuantity,
    String notes = '',
  }) async {
    try {
      await _remoteDataSource.rpcAdjustOrReleaseItem(
        palletItemId: palletItemId,
        action: action,
        targetQuantity: targetQuantity,
        notes: notes,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteMistakenPallet({
    required String palletId,
    required String reason,
  }) async {
    try {
      await _remoteDataSource.rpcDeleteMistakenPallet(
        palletId: palletId,
        reason: reason,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<bool> deleteMistakenPalletItem({
    required String palletItemId,
    required String reason,
  }) async {
    try {
      return await _remoteDataSource.rpcDeleteMistakenPalletItem(
        palletItemId: palletItemId,
        reason: reason,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}