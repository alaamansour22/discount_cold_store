import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/i_auth_repository.dart';
import '../features/auth/domain/usecases/auth_usecases.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';

import '../features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import '../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../features/dashboard/domain/repositories/i_dashboard_repository.dart';
import '../features/dashboard/domain/usecases/dashboard_usecases.dart';
import '../features/dashboard/presentation/cubit/dashboard_cubit.dart';

import '../features/receiving_dispatch/data/datasources/receiving_dispatch_remote_data_source.dart';
import '../features/receiving_dispatch/data/repositories/receiving_dispatch_repository_impl.dart';
import '../features/receiving_dispatch/domain/repositories/i_receiving_dispatch_repository.dart';
import '../features/receiving_dispatch/domain/usecases/receiving_dispatch_usecases.dart';
import '../features/receiving_dispatch/presentation/cubit/receiving_dispatch_cubit.dart';

import '../features/rack_transfer/data/datasources/rack_transfer_remote_data_source.dart';
import '../features/rack_transfer/data/repositories/rack_transfer_repository_impl.dart';
import '../features/rack_transfer/domain/repositories/i_rack_transfer_repository.dart';
import '../features/rack_transfer/domain/usecases/rack_transfer_usecases.dart';
import '../features/rack_transfer/presentation/cubit/rack_transfer_cubit.dart';

import '../features/condemnations/data/datasources/condemnations_remote_data_source.dart';
import '../features/condemnations/data/repositories/condemnations_repository_impl.dart';
import '../features/condemnations/domain/repositories/i_condemnations_repository.dart';
import '../features/condemnations/domain/usecases/condemnations_usecases.dart';
import '../features/condemnations/presentation/cubit/condemnations_cubit.dart';

import '../features/settings/data/datasources/settings_remote_data_source.dart';
import '../features/settings/data/repositories/settings_repository_impl.dart';
import '../features/settings/domain/repositories/i_settings_repository.dart';
import '../features/settings/domain/usecases/settings_usecases.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';

import '../features/movements_log/data/datasources/movements_log_remote_data_source.dart';
import '../features/movements_log/data/repositories/movements_log_repository_impl.dart';
import '../features/movements_log/domain/repositories/i_movements_log_repository.dart';
import '../features/movements_log/domain/usecases/movements_log_usecases.dart';
import '../features/movements_log/presentation/cubit/movements_log_cubit.dart';

/// مدير التوصيلات المركزي (Dependency Injection Container)
/// يربط كافة الموديولات الستة بنظام Clean Architecture + UseCases
class InjectionContainer {
  InjectionContainer._();
  static final InjectionContainer instance = InjectionContainer._();

  late final SupabaseClient supabaseClient;

  // Repositories
  late final IAuthRepository authRepository;
  late final IDashboardRepository dashboardRepository;
  late final IReceivingDispatchRepository receivingDispatchRepository;
  late final IRackTransferRepository rackTransferRepository;
  late final ICondemnationsRepository condemnationsRepository;
  late final ISettingsRepository settingsRepository;
  late final IMovementsLogRepository movementsLogRepository;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    supabaseClient = Supabase.instance.client;

    // 1. Repositories initialization
    authRepository = AuthRepositoryImpl(AuthRemoteDataSourceImpl(supabaseClient));
    dashboardRepository = DashboardRepositoryImpl(DashboardRemoteDataSourceImpl(supabaseClient));
    receivingDispatchRepository = ReceivingDispatchRepositoryImpl(ReceivingDispatchRemoteDataSourceImpl(supabaseClient));
    rackTransferRepository = RackTransferRepositoryImpl(RackTransferRemoteDataSourceImpl(supabaseClient));
    condemnationsRepository = CondemnationsRepositoryImpl(CondemnationsRemoteDataSourceImpl(supabaseClient));
    settingsRepository = SettingsRepositoryImpl(SettingsRemoteDataSourceImpl(supabaseClient));
    movementsLogRepository = MovementsLogRepositoryImpl(MovementsLogRemoteDataSourceImpl(supabaseClient));

    _isInitialized = true;
  }

  // Cubit Factories with UseCases injection
  AuthCubit createAuthCubit() => AuthCubit(AuthUseCases(authRepository));

  DashboardCubit createDashboardCubit() =>
      DashboardCubit(DashboardUseCases(dashboardRepository));

  ReceivingDispatchCubit createReceivingDispatchCubit() =>
      ReceivingDispatchCubit(ReceivingDispatchUseCases(receivingDispatchRepository));

  RackTransferCubit createRackTransferCubit() =>
      RackTransferCubit(RackTransferUseCases(rackTransferRepository));

  CondemnationsCubit createCondemnationsCubit() =>
      CondemnationsCubit(CondemnationsUseCases(condemnationsRepository));

  SettingsCubit createSettingsCubit() =>
      SettingsCubit(SettingsUseCases(settingsRepository));

  MovementsLogCubit createMovementsLogCubit() =>
      MovementsLogCubit(MovementsLogUseCases(movementsLogRepository));
}

final sl = InjectionContainer.instance;
