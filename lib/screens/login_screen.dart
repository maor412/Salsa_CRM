import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/salsa_logo_header.dart';
import '../config/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_button.dart';

/// מסך התחברות
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // משתני אנימציה
  bool _compactHeader = false;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    // הפעל אנימציה אחרי frame ראשון
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _compactHeader = true);
        }
      });

      Future.delayed(const Duration(milliseconds: 550), () {
        if (mounted) {
          setState(() => _showForm = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    // המרת שם משתמש לפורמט מייל עבור Firebase
    String username = _usernameController.text.trim();
    String email = username.contains('@') ? username : '$username@salsacrm.com';

    final success = await authProvider.signIn(
      email,
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'שגיאה בהתחברות'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mediumRadius,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background,
                AppColors.accent.withOpacity(0.2),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header עם אנימציה
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      alignment: _compactHeader ? Alignment.topCenter : Alignment.center,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.only(top: _compactHeader ? 0 : 40),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          scale: _compactHeader ? 0.85 : 1.0,
                          child: const SalsaLogoHeader(
                            isCompact: false,
                            showSubtitle: true,
                            logoSize: 110,
                            titleSize: 32,
                            subtitleSize: 16,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: _compactHeader ? AppSpacing.xxxl : AppSpacing.xxxl + AppSpacing.lg),

                    // טופס התחברות עם אנימציה
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: _showForm ? 1.0 : 0.0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        offset: _showForm ? Offset.zero : const Offset(0, 0.3),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.largeRadius,
                            boxShadow: AppShadows.medium,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // כותרת כניסה
                                Text(
                                  'כניסה למערכת',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                // שדה שם משתמש
                                AppTextField(
                                  controller: _usernameController,
                                  label: 'שם משתמש',
                                  hint: 'הזן את שם המשתמש שלך',
                                  prefixIcon: Icons.person_outline,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                  textDirection: TextDirection.ltr,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'נא להזין שם משתמש';
                                    }
                                    if (value.length < 3) {
                                      return 'שם המשתמש חייב להכיל לפחות 3 תווים';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // שדה סיסמה
                                AppTextField(
                                  controller: _passwordController,
                                  label: 'סיסמה',
                                  hint: 'הזן את הסיסמה שלך',
                                  prefixIcon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  textDirection: TextDirection.ltr,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _handleLogin(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'נא להזין סיסמה';
                                    }
                                    if (value.length < 6) {
                                      return 'הסיסמה חייבת להכיל לפחות 6 תווים';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                // כפתור התחברות
                                Consumer<AuthProvider>(
                                  builder: (context, authProvider, _) {
                                    return AppPrimaryButton(
                                      text: 'התחבר',
                                      icon: Icons.login,
                                      onPressed: _handleLogin,
                                      isLoading: authProvider.isLoading,
                                      fullWidth: true,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // הערה
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: _showForm ? 1.0 : 0.0,
                      child: Text(
                        'אם אינך זוכר את פרטי הגישה שלך, צור קשר עם המנהל',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
