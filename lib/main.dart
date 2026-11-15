import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:video_player_win/video_player_win.dart'; // استيراد ويندوز
import 'core/security/device_identity_service.dart';
import 'core/security/license_service.dart';
import 'core/theme/app_theme.dart';
import 'features/activation/activation_screen.dart';
import 'features/activation/splash_intro_screen.dart';
import 'features/courses/home_courses_screen.dart';
import 'core/config/app_edition.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // تسجيل مشغل الفيديو المسرّع تلقائياً إذا كان النظام ويندوز
  if (Platform.isWindows) {
    WindowsVideoPlayer.registerWith();
  }
  runApp(const LockselApp());
}

class LockselApp extends StatelessWidget {
  const LockselApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
     title: AppEdition.shortName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainGate(),
    );
  }
}

class MainGate extends StatefulWidget {
  const MainGate({super.key});

  @override
  State<MainGate> createState() => _MainGateState();
}

class _MainGateState extends State<MainGate> {
  bool _showSplash = true;
  bool _isActivated = false;

  @override
  void initState() {
    super.initState();
    _checkInitialActivation();
  }

  Future<void> _checkInitialActivation() async {
    final identity = DeviceIdentityService();
    final license = LicenseService();
    final deviceCode = await identity.getHardwareFingerprint();
    final activated = await license.isAlreadyActivated(deviceCode);
    if (mounted) {
      setState(() {
        _isActivated = activated;
      });
    }
  }

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  void _onActivationSuccess() {
    setState(() {
      _isActivated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashIntroScreen(
        key: const ValueKey('splash'),
        onAnimationComplete: _onSplashComplete,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: _isActivated
          ? const HomeCoursesScreen(key: ValueKey('home'))
          : ActivationScreen(
              key: const ValueKey('activation'),
              onActivationSuccess: _onActivationSuccess,
            ),
    );
  }
}