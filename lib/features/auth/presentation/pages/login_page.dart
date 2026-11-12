import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class AuthGate extends StatelessWidget {
  final Widget authenticatedChild;
  const AuthGate({super.key, required this.authenticatedChild});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.initialChecking) {
          return Scaffold(
            backgroundColor: AppTheme.primaryNavy,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.accentCyan),
                  const SizedBox(height: 16),
                  const Text(
                    'جاري استعادة جلسة المستخدم والاتصال بالثلاجة...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == AuthStatus.authenticated && state.user != null) {
          return authenticatedChild;
        }

        return const ColdStorageLoginPage();
      },
    );
  }
}

class ColdStorageLoginPage extends StatefulWidget {
  const ColdStorageLoginPage({super.key});

  @override
  State<ColdStorageLoginPage> createState() => _ColdStorageLoginPageState();
}

class _ColdStorageLoginPageState extends State<ColdStorageLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthCubit>().signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.primaryNavy,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: BlocConsumer<AuthCubit, AuthState>(
                    listener: (context, state) {
                      if (state.failure != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.failure!.message),
                            backgroundColor: AppTheme.dangerRed,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              AppAssets.logoBlue,
                              height: 82,
                              errorBuilder: (_, __, ___) => Icon(
                                LucideIcons.snowflake,
                                size: 68,
                                color: AppTheme.zoneC2Blue,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'ثلاجة مخفض (رمز C)',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'نظام إدارة الراكات (C2 & C3) والبالتات والإعدامات',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'البريد الإلكتروني للمستخدم',
                                prefixIcon: Icon(LucideIcons.mail),
                              ),
                              validator: (val) =>
                                  (val == null || !val.contains('@'))
                                      ? 'أدخل بريداً إلكترونياً صحيحاً'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textDirection: TextDirection.ltr,
                              onFieldSubmitted: (_) => _submitLogin(),
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(LucideIcons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? LucideIcons.eyeOff
                                        : LucideIcons.eye,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.length < 6)
                                      ? 'كلمة المرور لا تقل عن 6 أحرف'
                                      : null,
                            ),
                            const SizedBox(height: 24),
                            AppActionButton(
                              label: 'تسجيل الدخول وحفظ الجلسة',
                              icon: LucideIcons.logIn,
                              fullWidth: true,
                              isLoading: state.isSubmitting,
                              onPressed: _submitLogin,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}