import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/profile/public_profile_screen.dart';
import 'screens/shell/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/seed_service.dart';
import 'services/session_service.dart';
import 'theme.dart';

class AlightCreatorsApp extends StatelessWidget {
  const AlightCreatorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthService>.value(
      value: AuthService.instance,
      child: MaterialApp(
        title: 'Alight Creators',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: '/',
        routes: {
          '/': (_) => const _Bootstrap(),
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignUpScreen(),
          '/forgot': (_) => const ForgotPasswordScreen(),
          '/reset': (_) => const ResetPasswordScreen(),
          '/home': (_) => const HomeShell(),
          '/404': (_) => const NotFoundScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/user') {
            final username = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => PublicProfileScreen(username: username),
            );
          }
          return null;
        },
        builder: (context, child) {
          final scale = MediaQuery.textScalerOf(context).clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.2,
          );
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scale),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

/// Boots the app: opens the DB, seeds if empty, restores the session,
/// then shows either the shell or the welcome screen. Shows a loading
/// indicator while doing so, so the user never sees a frozen screen.
/// If something throws, offers a Retry button.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<void> _init;

  @override
  void initState() {
    super.initState();
    _init = _boot();
  }

  Future<void> _boot() async {
    await DatabaseService.instance.database;
    await SeedService.instance.seedIfEmpty();
    await SessionService.instance.load();
    await AuthService.instance.restoreSession();
  }

  void _retry() {
    setState(() {
      _init = _boot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _SplashLoading();
        }
        if (snap.hasError) {
          return _SplashError(
            error: snap.error.toString(),
            onRetry: _retry,
          );
        }
        final loggedIn =
            context.select<AuthService, bool>((a) => a.isLoggedIn);
        return loggedIn ? const HomeShell() : const WelcomeScreen();
      },
    );
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }
}

class _SplashError extends StatelessWidget {
  const _SplashError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              const Text('Startup error',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}