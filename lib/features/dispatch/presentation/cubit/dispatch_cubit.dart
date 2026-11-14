import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/dispatch_entities.dart';
import '../../domain/usecases/dispatch_usecases.dart';
import 'dispatch_state.dart';

class DispatchCubit extends Cubit<DispatchState> {
  final DispatchUseCases useCases;
  DispatchCubit(this.useCases) : super(const DispatchState());

  bool _isLoading = false;

  Future<void> load() async {
    // The shell uses IndexedStack, so both dispatch pages may initialize
    // together. Avoid duplicate concurrent requests to the same endpoint.
    if (_isLoading || isClosed) return;
    _isLoading = true;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final values = await Future.wait([
        useCases.availableItems(),
        useCases.documents(),
      ]);
      emit(
        state.copyWith(
          loading: false,
          availableItems: values[0] as dynamic,
          documents: values[1] as dynamic,
        ),
      );
    } catch (e) {
      if (!isClosed) emit(state.copyWith(loading: false, error: _message(e)));
    } finally {
      _isLoading = false;
    }
  }

  Future<Map<String, dynamic>?> create(List<DispatchDraftLine> lines) async {
    if (lines.isEmpty) {
      emit(state.copyWith(error: 'اختر صنفًا واحدًا على الأقل'));
      return null;
    }
    emit(
      state.copyWith(submitting: true, clearError: true, clearSuccess: true),
    );
    try {
      final result = await useCases.create(lines);
      emit(
        state.copyWith(
          submitting: false,
          success: 'تم إنشاء مستند الصرف ${result['document_number'] ?? ''}',
        ),
      );
      await load();
      return result;
    } catch (e) {
      emit(state.copyWith(submitting: false, error: _message(e)));
      return null;
    }
  }

  Future<List<DispatchDocumentLineEntity>> loadDetails(String id) async {
    try {
      final rows = await useCases.documentLines(id);
      final map = Map<String, List<DispatchDocumentLineEntity>>.from(
        state.details,
      )..[id] = rows;
      emit(state.copyWith(details: map));
      return rows;
    } catch (e) {
      emit(state.copyWith(error: _message(e)));
      return [];
    }
  }

  Future<bool> reverse(String id, String reason) async {
    emit(
      state.copyWith(submitting: true, clearError: true, clearSuccess: true),
    );
    try {
      await useCases.reverse(id, reason);
      emit(
        state.copyWith(submitting: false, success: 'تم عكس مستند الصرف بنجاح'),
      );
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(submitting: false, error: _message(e)));
      return false;
    }
  }

  String _message(Object e) {
    final s = e.toString();
    return s
        .replaceFirst('Exception: ', '')
        .replaceFirst('PostgrestException(message: ', '')
        .split(', code:')
        .first;
  }
}
