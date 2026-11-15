import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_edition.dart';
import '../../core/theme/app_theme.dart';

class SplashIntroScreen extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const SplashIntroScreen({
    super.key,
    this.onAnimationComplete,
  });

  @override
  State<SplashIntroScreen> createState() => _SplashIntroScreenState();
}

class _SplashIntroScreenState extends State<SplashIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. حركة دوران الرموز حول الشعار
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 2. حركة النبض والوهج للشعار
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. ظهور النصوص
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // إنهاء السبلاش والتوجيه للشاشة التالية بعد 3.2 ثوانٍ
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        if (widget.onAnimationComplete != null) {
          widget.onAnimationComplete!();
        }
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // الرموز المدارية بحسب النسخة
  List<IconData> get _orbitIcons {
    if (AppEdition.isCyber) {
      return [
        Icons.shield_outlined,
        Icons.lock_outline_rounded,
        Icons.terminal_rounded,
        Icons.vpn_key_outlined,
        Icons.wifi_protected_setup_rounded,
        Icons.radar_rounded,
      ];
    } else {
      return [
        Icons.code_rounded,
        Icons.data_object_rounded,
        Icons.storage_rounded,
        Icons.devices_rounded,
        Icons.lan_outlined,
        Icons.memory_rounded,
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryBlue;
    final isCyber = AppEdition.isCyber;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldDark,
        body: Stack(
          children: [
            // خلفية بتدرج لوني
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.15),
                    radius: 0.85,
                    colors: [
                      primaryColor.withOpacity(isCyber ? 0.18 : 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // الشعار والمدار الدوار
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // دائرة المسار
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                        ),

                        // الرموز الدوارة
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationController.value * 2 * math.pi,
                              child: Stack(
                                alignment: Alignment.center,
                                children: List.generate(_orbitIcons.length, (index) {
                                  final angle = (index * 2 * math.pi) / _orbitIcons.length;
                                  const radius = 110.0;
                                  final x = radius * math.cos(angle);
                                  final y = radius * math.sin(angle);

                                  return Transform.translate(
                                    offset: Offset(x, y),
                                    child: Transform.rotate(
                                      angle: -_rotationController.value * 2 * math.pi,
                                      child: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.surfaceDark,
                                          border: Border.all(
                                            color: primaryColor.withOpacity(0.4),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withOpacity(0.25),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _orbitIcons[index],
                                          color: primaryColor,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),

                        // الشعار النابض بالمنتصف
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.45),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              isCyber ? Icons.shield_rounded : Icons.terminal_rounded,
                              size: 48,
                              color: const Color(0xFF090D16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // النصوص والهوية
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          AppEdition.appName,
                          style: GoogleFonts.cairo(
                            color: AppTheme.textMain,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primaryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            AppEdition.editionBadge,
                            style: GoogleFonts.robotoMono(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isCyber
                              ? '🔒 منصة تعليمية مشفرة ومحمية لاختصاصات الأمن والدفاع السيبراني'
                              : '⚡ منصة تعليمية احترافية لعلوم التقنية والبرمجة الحديثة',
                          style: GoogleFonts.cairo(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}