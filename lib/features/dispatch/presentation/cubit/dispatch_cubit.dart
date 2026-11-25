import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/dispatch_entities.dart';
import '../../domain/usecases/dispatch_usecases.dart';
import 'dispatch_state.dart';

class DispatchCubit extends Cubit<DispatchState> {
  final DispatchUseCases useCases;
  StreamSubscription<void>? _realtimeSub;
  int _palletsRequestSeq = 0;
  int _docsRequestSeq = 0;
  bool _realtimeQueued = false;

  DispatchCubit(this.useCases) : super(const DispatchState()) {
    _realtimeSub = useCases.watchRealtimeChanges().listen((_) {
      if (isClosed || _realtimeQueued) {
        return;
      }
      _realtimeQueued = true;
      scheduleMicrotask(() {
        _realtimeQueued = false;
        if (isClosed) {
          return;
        }
        if (state.palletsInitialized) {
          unawaited(loadAvailablePallets(silent: true));
        }
        if (state.docsInitialized) {
          unawaited(loadDocuments(silent: true));
        }
      });
    });
  }

  // ==================== 1. البالتات المتاحة للصرف ====================

  Future<void> ensureAvailablePalletsLoaded() async {
    if (!state.palletsInitialized && !state.isPalletsLoading) {
      await loadAvailablePallets();
    }
  }

  Future<void> loadAvailablePallets({
    DispatchAvailablePalletsFilter? filter,
    bool silent = false,
  }) async {
    if (isClosed) {
      return;
    }
    final targetFilter = filter ?? state.palletsFilter;
    final seq = ++_palletsRequestSeq;

    if (!silent) {
      emit(
        state.copyWith(
          isPalletsLoading: true,
          palletsFilter: targetFilter,
          clearFailure: true,
          clearSuccess: true,
        ),
      );
    }

    try {
      final result = await useCases.availablePallets(targetFilter);
      if (isClosed || seq != _palletsRequestSeq) {
        return;
      }

      if (targetFilter.page > result.page.totalPages &&
          result.page.totalPages >= 1) {
        await loadAvailablePallets(
          filter: targetFilter.copyWith(page: result.page.totalPages),
          silent: silent,
        );
        return;
      }

      emit(
        state.copyWith(
          isPalletsLoading: false,
          palletsInitialized: true,
          palletsFilter: targetFilter,
          palletsData: result,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (isClosed || seq != _palletsRequestSeq) {
        return;
      }
      emit(
        state.copyWith(
          isPalletsLoading: false,
          palletsInitialized: true,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> updatePalletsFilter(DispatchAvailablePalletsFilter nextFilter) =>
      loadAvailablePallets(filter: nextFilter.copyWith(page: 1));

  Future<void> goToPalletsPage(int page) =>
      loadAvailablePallets(filter: state.palletsFilter.copyWith(page: page));

  Future<void> changePalletsPageSize(int pageSize) => loadAvailablePallets(
    filter: state.palletsFilter.copyWith(page: 1, pageSize: pageSize),
  );

  Future<void> clearPalletsFilters() => loadAvailablePallets(
    filter: DispatchAvailablePalletsFilter(
      pageSize: state.palletsFilter.pageSize,
    ),
  );

  // ==================== 2. سجل مستندات الصرف ====================

  Future<void> ensureDocumentsLoaded() async {
    if (!state.docsInitialized && !state.isDocsLoading) {
      await loadDocuments();
    }
  }

  Future<void> loadDocuments({
    DispatchDocumentsFilter? filter,
    bool silent = false,
  }) async {
    if (isClosed) {
      return;
    }
    final targetFilter = filter ?? state.docsFilter;
    final seq = ++_docsRequestSeq;

    if (!silent) {
      emit(
        state.copyWith(
          isDocsLoading: true,
          docsFilter: targetFilter,
          clearFailure: true,
          clearSuccess: true,
        ),
      );
    }

    try {
      final result = await useCases.documents(targetFilter);
      if (isClosed || seq != _docsRequestSeq) {
        return;
      }

      if (targetFilter.page > result.page.totalPages &&
          result.page.totalPages >= 1) {
        await loadDocuments(
          filter: targetFilter.copyWith(page: result.page.totalPages),
          silent: silent,
        );
        return;
      }

      emit(
        state.copyWith(
          isDocsLoading: false,
          docsInitialized: true,
          docsFilter: targetFilter,
          docsData: result,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (isClosed || seq != _docsRequestSeq) {
        return;
      }
      emit(
        state.copyWith(
          isDocsLoading: false,
          docsInitialized: true,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> updateDocumentsFilter(DispatchDocumentsFilter nextFilter) =>
      loadDocuments(filter: nextFilter.copyWith(page: 1));

  Future<void> goToDocumentsPage(int page) =>
      loadDocuments(filter: state.docsFilter.copyWith(page: page));

  Future<void> changeDocumentsPageSize(int pageSize) => loadDocuments(
    filter: state.docsFilter.copyWith(page: 1, pageSize: pageSize),
  );

  Future<void> clearDocumentsFilters() => loadDocuments(
    filter: DispatchDocumentsFilter(pageSize: state.docsFilter.pageSize),
  );

  Future<DispatchDocumentsPageEntity> fetchDocumentsForExport() {
    return useCases.documents(state.docsFilter.copyWith(page: 1, pageSize: 500));
  }

  // ==================== 3. تفاصيل مستند + إنشاء + عكس ====================

  Future<List<DispatchDocumentLineEntity>> loadDetails(String id) async {
    if (isClosed) {
      return const [];
    }
    if (state.loadingDetailIds.contains(id)) {
      return state.details[id] ?? const [];
    }

    final nextLoading = Set<String>.from(state.loadingDetailIds)..add(id);
    emit(state.copyWith(loadingDetailIds: nextLoading));

    try {
      final rows = await useCases.documentLines(id);
      if (isClosed) {
        return rows;
      }
      final nextDetails = Map<String, List<DispatchDocumentLineEntity>>.from(
        state.details,
      )..[id] = rows;
      final doneLoading = Set<String>.from(state.loadingDetailIds)..remove(id);
      emit(
        state.copyWith(details: nextDetails, loadingDetailIds: doneLoading),
      );
      return rows;
    } catch (e) {
      if (!isClosed) {
        final doneLoading = Set<String>.from(state.loadingDetailIds)
          ..remove(id);
        emit(
          state.copyWith(
            loadingDetailIds: doneLoading,
            failure: ErrorHandler.handle(e),
          ),
        );
      }
      return const [];
    }
  }

  Future<DispatchReversalReadinessEntity?> checkReversalReadiness(
    String documentId,
  ) async {
    if (isClosed) {
      return null;
    }
    try {
      return await useCases.checkReversalReadiness(documentId);
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(failure: ErrorHandler.handle(e)));
      }
      return null;
    }
  }

  Future<DispatchJsonMap?> create(List<DispatchDraftLine> lines) async {
    if (isClosed) {
      return null;
    }
    emit(
      state.copyWith(submitting: true, clearFailure: true, clearSuccess: true),
    );
    try {
      final result = await useCases.create(lines);
      if (isClosed) {
        return result;
      }
      await Future.wait([
        loadAvailablePallets(silent: true),
        if (state.docsInitialized) loadDocuments(silent: true),
      ]);
      if (isClosed) {
        return result;
      }
      emit(
        state.copyWith(
          submitting: false,
          success: 'تم إنشاء مستند الصرف ${result['document_number'] ?? ''}',
        ),
      );
      return result;
    } catch (e) {
      if (!isClosed) {
        final failure = ErrorHandler.handle(e);
        if (failure.type == FailureType.concurrencyConflict ||
            failure.type == FailureType.insufficientQuantity) {
          await loadAvailablePallets(silent: true);
        }
        if (!isClosed) {
          emit(state.copyWith(submitting: false, failure: failure));
        }
      }
      return null;
    }
  }

  Future<bool> reverse({
    required String documentId,
    required String reason,
    List<DispatchSlotAssignment> alternativeSlots = const [],
  }) async {
    if (isClosed) {
      return false;
    }
    emit(
      state.copyWith(submitting: true, clearFailure: true, clearSuccess: true),
    );
    try {
      await useCases.reverse(
        documentId: documentId,
        reason: reason,
        alternativeSlots: alternativeSlots,
      );
      if (isClosed) {
        return true;
      }
      final cleanedDetails = Map<String, List<DispatchDocumentLineEntity>>.from(
        state.details,
      )..remove(documentId);
      emit(state.copyWith(details: cleanedDetails));

      await Future.wait([
        loadDocuments(silent: true),
        if (state.palletsInitialized) loadAvailablePallets(silent: true),
      ]);
      if (isClosed) {
        return true;
      }
      emit(
        state.copyWith(submitting: false, success: 'تم عكس مستند الصرف بنجاح'),
      );
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(submitting: false, failure: ErrorHandler.handle(e)),
        );
      }
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await super.close();
  }
}