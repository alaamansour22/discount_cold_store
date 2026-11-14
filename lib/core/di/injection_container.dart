import 'package:discount_cold_store/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:discount_cold_store/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:discount_cold_store/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:discount_cold_store/features/auth/domain/usecases/auth_usecases.dart';
import 'package:discount_cold_store/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:discount_cold_store/features/condemnations/data/datasources/condemnations_remote_data_source.dart';
import 'package:discount_cold_store/features/condemnations/data/repositories/condemnations_repository_impl.dart';
import 'package:discount_cold_store/features/condemnations/domain/repositories/i_condemnations_repository.dart';
import 'package:discount_cold_store/features/condemnations/domain/usecases/condemnations_usecases.dart';
import 'package:discount_cold_store/features/condemnations/presentation/cubit/condemnations_cubit.dart';
import 'package:discount_cold_store/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:discount_cold_store/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:discount_cold_store/features/dashboard/domain/repositories/i_dashboard_repository.dart';
import 'package:discount_cold_store/features/dashboard/domain/usecases/dashboard_usecases.dart';
import 'package:discount_cold_store/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:discount_cold_store/features/dispatch/data/datasources/dispatch_remote_data_source.dart';
import 'package:discount_cold_store/features/dispatch/data/repositories/dispatch_repository_impl.dart';
import 'package:discount_cold_store/features/dispatch/domain/repositories/i_dispatch_repository.dart';
import 'package:discount_cold_store/features/dispatch/domain/usecases/dispatch_usecases.dart';
import 'package:discount_cold_store/features/dispatch/presentation/cubit/dispatch_cubit.dart';
import 'package:discount_cold_store/features/movements_log/data/datasources/movements_log_remote_data_source.dart';
import 'package:discount_cold_store/features/movements_log/data/repositories/movements_log_repository_impl.dart';
import 'package:discount_cold_store/features/movements_log/domain/repositories/i_movements_log_repository.dart';
import 'package:discount_cold_store/features/movements_log/domain/usecases/movements_log_usecases.dart';
import 'package:discount_cold_store/features/movements_log/presentation/cubit/movements_log_cubit.dart';
import 'package:discount_cold_store/features/rack_transfer/data/datasources/rack_transfer_remote_data_source.dart';
import 'package:discount_cold_store/features/rack_transfer/data/repositories/rack_transfer_repository_impl.dart';
import 'package:discount_cold_store/features/rack_transfer/domain/repositories/i_rack_transfer_repository.dart';
import 'package:discount_cold_store/features/rack_transfer/domain/usecases/rack_transfer_usecases.dart';
import 'package:discount_cold_store/features/rack_transfer/presentation/cubit/rack_transfer_cubit.dart';
import 'package:discount_cold_store/features/receiving/data/datasources/receiving_remote_data_source.dart';
import 'package:discount_cold_store/features/receiving/data/repositories/receiving_repository_impl.dart';
import 'package:discount_cold_store/features/receiving/domain/repositories/i_receiving_repository.dart';
import 'package:discount_cold_store/features/receiving/domain/usecases/receiving_usecases.dart';
import 'package:discount_cold_store/features/receiving/presentation/cubit/receiving_cubit.dart';
import 'package:discount_cold_store/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:discount_cold_store/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:discount_cold_store/features/reports/domain/repositories/i_reports_repository.dart';
import 'package:discount_cold_store/features/reports/domain/usecases/reports_usecases.dart';
import 'package:discount_cold_store/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:discount_cold_store/features/warehouse/data/datasources/warehouse_remote_data_source.dart';
import 'package:discount_cold_store/features/warehouse/data/repositories/warehouse_repository_impl.dart';
import 'package:discount_cold_store/features/warehouse/domain/repositories/i_warehouse_repository.dart';
import 'package:discount_cold_store/features/warehouse/domain/usecases/warehouse_usecases.dart';
import 'package:discount_cold_store/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:discount_cold_store/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:discount_cold_store/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:discount_cold_store/features/settings/domain/usecases/settings_usecases.dart';
import 'package:discount_cold_store/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// مدير التوصيلات المركزي (Dependency Injection Container)
/// يربط كافة الموديولات الستة بنظام Clean Architecture + UseCases
class InjectionContainer {
  InjectionContainer._();
  static final InjectionContainer instance = InjectionContainer._();

  late final SupabaseClient supabaseClient;

  // Repositories
  late final IAuthRepository authRepository;
  late final IDashboardRepository dashboardRepository;
  late final IReceivingRepository receivingRepository;
  late final IDispatchRepository dispatchRepository;
  late final IWarehouseRepository warehouseRepository;
  late final IRackTransferRepository rackTransferRepository;
  late final ICondemnationsRepository condemnationsRepository;
  late final ISettingsRepository settingsRepository;
  late final IMovementsLogRepository movementsLogRepository;
  late final IReportsRepository reportsRepository;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    supabaseClient = Supabase.instance.client;

    // 1. Repositories initialization
    authRepository = AuthRepositoryImpl(
      AuthRemoteDataSourceImpl(supabaseClient),
    );
    dashboardRepository = DashboardRepositoryImpl(
      DashboardRemoteDataSourceImpl(supabaseClient),
    );
    receivingRepository = ReceivingRepositoryImpl(
      ReceivingRemoteDataSourceImpl(supabaseClient),
    );
    dispatchRepository = DispatchRepositoryImpl(
      DispatchRemoteDataSourceImpl(supabaseClient),
    );
    warehouseRepository = WarehouseRepositoryImpl(
      WarehouseRemoteDataSourceImpl(supabaseClient),
    );
    rackTransferRepository = RackTransferRepositoryImpl(
      RackTransferRemoteDataSourceImpl(supabaseClient),
    );
    condemnationsRepository = CondemnationsRepositoryImpl(
      CondemnationsRemoteDataSourceImpl(supabaseClient),
    );
    settingsRepository = SettingsRepositoryImpl(
      SettingsRemoteDataSourceImpl(supabaseClient),
    );
    movementsLogRepository = MovementsLogRepositoryImpl(
      MovementsLogRemoteDataSourceImpl(supabaseClient),
    );
    reportsRepository = ReportsRepositoryImpl(
      ReportsRemoteDataSourceImpl(supabaseClient),
    );

    _isInitialized = true;
  }

  // Cubit Factories with UseCases injection
  AuthCubit createAuthCubit() => AuthCubit(AuthUseCases(authRepository));

  DashboardCubit createDashboardCubit() =>
      DashboardCubit(DashboardUseCases(dashboardRepository));

  ReceivingCubit createReceivingCubit() => ReceivingCubit(
    ReceivingUseCases(receivingRepository),
    WarehouseUseCases(warehouseRepository),
  );

  DispatchCubit createDispatchCubit() =>
      DispatchCubit(DispatchUseCases(dispatchRepository));

  RackTransferCubit createRackTransferCubit() =>
      RackTransferCubit(RackTransferUseCases(rackTransferRepository));

  CondemnationsCubit createCondemnationsCubit() =>
      CondemnationsCubit(CondemnationsUseCases(condemnationsRepository));

  SettingsCubit createSettingsCubit() =>
      SettingsCubit(SettingsUseCases(settingsRepository));

  MovementsLogCubit createMovementsLogCubit() =>
      MovementsLogCubit(MovementsLogUseCases(movementsLogRepository));

  ReportsCubit createReportsCubit() =>
      ReportsCubit(ReportsUseCases(reportsRepository));
}

final sl = InjectionContainer.instance;
