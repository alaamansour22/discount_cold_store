import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/di/injection_container.dart';
import 'core/navigation/app_navigation_shell.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/condemnations/presentation/pages/condemnations_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/dispatch/presentation/pages/dispatch_page.dart';
import 'features/movements_log/presentation/pages/deleted_records_page.dart';
import 'features/movements_log/presentation/pages/movements_log_page.dart';
import 'features/rack_transfer/presentation/pages/rack_transfer_page.dart';
import 'features/receiving/presentation/pages/receiving_page.dart';
import 'features/reports/presentation/pages/reports_center_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

 await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await sl.init();

  runApp(const DiscountColdStoreApp());
}

class DiscountColdStoreApp extends StatelessWidget {
  const DiscountColdStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl.createAuthCubit()),
        BlocProvider(create: (_) => sl.createDashboardCubit()),
        BlocProvider(create: (_) => sl.createReceivingCubit()),
        BlocProvider(create: (_) => sl.createDispatchCubit()),
        BlocProvider(create: (_) => sl.createRackTransferCubit()),
        BlocProvider(create: (_) => sl.createCondemnationsCubit()),
        BlocProvider(create: (_) => sl.createSettingsCubit()),
        BlocProvider(create: (_) => sl.createMovementsLogCubit()),
        BlocProvider(create: (_) => sl.createDeletedRecordsCubit()),
      ],
      child: MaterialApp(
        title: 'ثلاجة المخفض',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AuthGate(
          authenticatedChild: ColdStorageMainOrchestratorPage(),
        ),
      ),
    );
  }
}

class ColdStorageMainOrchestratorPage extends StatefulWidget {
  const ColdStorageMainOrchestratorPage({super.key});

  @override
  State<ColdStorageMainOrchestratorPage> createState() =>
      _ColdStorageMainOrchestratorPageState();
}

class _ColdStorageMainOrchestratorPageState
    extends State<ColdStorageMainOrchestratorPage> {
  int _currentTabIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return AppNavigationShell(
      currentIndex: _currentTabIndex,
      onTabSelected: _navigateToTab,
      title: 'ثلاجة المخفض',
      tabs: [
        AppShellTabItem(
          label: 'الرئيسية',
          section: 'نظرة عامة',
          icon: LucideIcons.layoutDashboard,
          page: DashboardPage(onQuickNavigateToTab: _navigateToTab),
        ),
        AppShellTabItem(
          label: 'الاستلام والتسكين',
          section: 'العمليات والرقابة',
          icon: LucideIcons.grid3x3,
          page: const ReceivingPage(),
        ),
        AppShellTabItem(
          label: 'سجل الاستلامات',
          section: 'العمليات والرقابة',
          icon: LucideIcons.clipboardList,
          page: const ReceivingPage(historyOnly: true),
        ),
        AppShellTabItem(
          label: 'تحويل الراكات',
          section: 'العمليات والرقابة',
          icon: LucideIcons.arrowLeftRight,
          page: const RackTransferPage(),
        ),
        AppShellTabItem(
          label: 'سجل التحويلات',
          section: 'العمليات والرقابة',
          icon: LucideIcons.clipboardList,
          page: const RackTransferPage(historyOnly: true),
        ),
        AppShellTabItem(
          label: 'الإعدامات',
          section: 'العمليات والرقابة',
          icon: LucideIcons.flame,
          page: const CondemnationsPage(),
        ),
        AppShellTabItem(
          label: 'سجل الحركات',
          section: 'العمليات والرقابة',
          icon: LucideIcons.history,
          page: const MovementsLogPage(),
        ),
        AppShellTabItem(
          label: 'إنشاء صرف',
          section: 'الصرف والتقارير',
          icon: LucideIcons.packageOpen,
          page: const DispatchPage(),
        ),
        AppShellTabItem(
          label: 'سجل الصرف',
          section: 'الصرف والتقارير',
          icon: LucideIcons.clipboardList,
          page: const DispatchPage(historyOnly: true),
        ),
        AppShellTabItem(
          label: 'مركز التقارير',
          section: 'الصرف والتقارير',
          icon: LucideIcons.chartNoAxesCombined,
          page: const ReportsCenterPage(),
        ),
        AppShellTabItem(
          label: 'سجل المحذوفات',
          section: 'النظام',
          icon: LucideIcons.trash2,
          page: const DeletedRecordsPage(),
        ),
        AppShellTabItem(
          label: 'الإعدادات',
          section: 'النظام',
          icon: LucideIcons.userCog,
          page: const SettingsPage(),
        ),
      ],
    );
  }
}