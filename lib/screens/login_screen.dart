import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/salsa_logo_header.dart';

/// מסך התחברות
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'שגיאה בהתחברות'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
                        scale: _compactHeader ? 0.8 : 1.0,
                        child: const SalsaLogoHeader(
                          isCompact: false,
                          showSubtitle: true,
                          logoSize: 100,
                          titleSize: 28,
                          subtitleSize: 15,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: _compactHeader ? 32 : 48),

                  // טופס התחברות עם אנימציה
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: _showForm ? 1.0 : 0.0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      offset: _showForm ? Offset.zero : const Offset(0, 0.3),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                                // שדה אימייל
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                    labelText: 'אימייל',
                                    prefixIcon: Icon(Icons.email),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'נא להזין אימייל';
                                    }
                                    if (!value.contains('@')) {
                                      return 'אימייל לא תקין';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // שדה סיסמה
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textDirection: TextDirection.ltr,
                                  decoration: InputDecoration(
                                    labelText: 'סיסמה',
                                    prefixIcon: const Icon(Icons.lock),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: const OutlineInputBorder(),
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
                                const SizedBox(height: 24),

                                // כפתור התחברות
                                Consumer<AuthProvider>(
                                  builder: (context, authProvider, _) {
                                    if (authProvider.isLoading) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    return ElevatedButton(
                                      onPressed: _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text(
                                        'התחבר',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
