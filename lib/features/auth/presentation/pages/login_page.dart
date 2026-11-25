import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
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
            backgroundColor: AppColors.primaryNavy,
            body: SafeArea(
              child: Column(
                children: [
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              color: AppColors.accentCyan,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'جاري استعادة الجلسة...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: _DeveloperSignatureFooter(),
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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final ValueNotifier<bool> _obscurePasswordNotifier = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _obscurePasswordNotifier.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
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
        backgroundColor: AppColors.primaryNavy,
        body: Stack(
          children: [
            // خلفية متدرجة ثابتة ومعزولة لمنع إعادة الرسم مع الكيبورد
            const RepaintBoundary(child: _ColdStorageBackgroundDecor()),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: BlocConsumer<AuthCubit, AuthState>(
                      listenWhen: (prev, curr) =>
                          prev.failure != curr.failure && curr.failure != null,
                      listener: (context, state) {
                        if (state.failure != null) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.circleAlert,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        state.failure!.message,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.dangerRed,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                        }
                      },
                      builder: (context, state) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // البطاقة الرئيسية لتسجيل الدخول
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.32),
                                    blurRadius: 32,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // اللوجو داخل إطار Squircle متناسق مع زوايا اللوجو
                                    Center(
                                      child: Container(
                                        width: 84,
                                        height: 84,
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryNavy,
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          border: Border.all(
                                            color: AppColors.accentCyan
                                                .withValues(alpha: 0.35),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.zoneC2Blue
                                                  .withValues(alpha: 0.22),
                                              blurRadius: 18,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.asset(
                                            AppAssets.logoSq,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  LucideIcons.snowflake,
                                                  size: 42,
                                                  color: AppColors.accentCyan,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),

                                    // شارة النظام
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.zoneC2Blue
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.snowflake,
                                              size: 13,
                                              color: AppColors.zoneC2Blue,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              ' مخازن المنتج التام',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.zoneC2Blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    const Text(
                                      'ثلاجة المخفض',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryNavy,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'سجّل دخولك للوصول إلى الراكات وعمليات الاستلام والصرف',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 26),

                                    // حقل البريد الإلكتروني
                                    const _FieldLabel(
                                      label: 'البريد الإلكتروني',
                                      icon: LucideIcons.mail,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _emailController,
                                      focusNode: _emailFocus,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.left,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).requestFocus(
                                            _passwordFocus,
                                          ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: AppColors.primaryNavy,
                                      ),
                                      decoration: _inputDecoration(
                                        hintText: 'user@beyti.com',
                                        prefixIcon: LucideIcons.atSign,
                                      ),
                                      validator: (val) =>
                                          (val == null ||
                                              !val.trim().contains('@'))
                                          ? 'الرجاء إدخال بريد إلكتروني صحيح'
                                          : null,
                                    ),
                                    const SizedBox(height: 18),

                                    // حقل كلمة المرور
                                    const _FieldLabel(
                                      label: 'كلمة المرور',
                                      icon: LucideIcons.lock,
                                    ),
                                    const SizedBox(height: 8),
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _obscurePasswordNotifier,
                                      builder: (context, obscure, _) {
                                        return TextFormField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocus,
                                          obscureText: obscure,
                                          textInputAction: TextInputAction.done,
                                          textDirection: TextDirection.ltr,
                                          textAlign: TextAlign.left,
                                          onFieldSubmitted: (_) =>
                                              _submitLogin(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                            color: AppColors.primaryNavy,
                                          ),
                                          decoration: _inputDecoration(
                                            hintText: '••••••••',
                                            prefixIcon: LucideIcons.keyRound,
                                            suffixIcon: IconButton(
                                              tooltip: obscure
                                                  ? 'إظهار كلمة المرور'
                                                  : 'إخفاء كلمة المرور',
                                              icon: Icon(
                                                obscure
                                                    ? LucideIcons.eyeOff
                                                    : LucideIcons.eye,
                                                color: AppColors.textSecondary,
                                                size: 19,
                                              ),
                                              onPressed: () =>
                                                  _obscurePasswordNotifier
                                                          .value =
                                                      !obscure,
                                            ),
                                          ),
                                          validator: (val) =>
                                              (val == null || val.length < 6)
                                              ? 'كلمة المرور يجب ألا تقل عن 6 أحرف'
                                              : null,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 26),

                                    // زر تسجيل الدخول
                                    SizedBox(
                                      height: 52,
                                      child: FilledButton(
                                        onPressed: state.isSubmitting
                                            ? null
                                            : _submitLogin,
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryNavy,
                                          disabledBackgroundColor: AppColors
                                              .primaryNavy
                                              .withValues(alpha: 0.6),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        child: state.isSubmitting
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    LucideIcons.logIn,
                                                    size: 19,
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'تسجيل الدخول',
                                                    style: TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // التوقيع السفلي By Alaa Mansour
                            const _DeveloperSignatureFooter(),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintTextDirection: TextDirection.ltr,
      hintStyle: TextStyle(
        color: Colors.blueGrey.shade300,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.zoneC2Blue, size: 19),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.zoneC2Blue, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.8),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.zoneC2Blue),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
        ),
      ],
    );
  }
}

class _DeveloperSignatureFooter extends StatelessWidget {
  const _DeveloperSignatureFooter();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.codeXml,
              size: 15,
              color: AppColors.accentCyan,
            ),
            const SizedBox(width: 8),
            Text(
              'By ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const Text(
              'Alaa Mansour',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColdStorageBackgroundDecor extends StatelessWidget {
  const _ColdStorageBackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF091122),
            AppColors.primaryNavy,
            Color(0xFF132A52),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.zoneC2Blue.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentCyan.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}