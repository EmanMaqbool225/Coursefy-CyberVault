import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/security/device_identity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/license_service.dart';

class ActivationScreen extends StatefulWidget {
  final VoidCallback onActivationSuccess;

  const ActivationScreen({
    super.key,
    required this.onActivationSuccess,
  });

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final DeviceIdentityService _identityService = DeviceIdentityService();
  final TextEditingController _licenseController = TextEditingController();

  // ضع هنا رقم الواتساب الخاص بالدعم الفني مع الرمز الدولي
  final String _supportWhatsAppNumber = "967716058576"; 

  String _requestCode = 'جاري التوليد...';
  bool _isLoading = true;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDeviceFingerprint();
  }

  Future<void> _loadDeviceFingerprint() async {
    final code = await _identityService.getHardwareFingerprint();
    if (mounted) {
      setState(() {
        _requestCode = code;
        _isLoading = false;
      });
    }
  }

  void _copyRequestCode() {
    Clipboard.setData(ClipboardData(text: _requestCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ كود جهازك بنجاح',
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendViaWhatsApp() async {
    final message = Uri.encodeComponent(
      'مرحباً، أود تفعيل اشتراكي في منصة Locksel.\nكود جهازي هو:\n$_requestCode',
    );
    final url = Uri.parse('https://wa.me/$_supportWhatsAppNumber?text=$message');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر فتح واتساب تلقائياً، يمكنك نسخ الكود ومراسلتي يدوياً',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  final LicenseService _licenseService = LicenseService();

  Future<void> _verifyActivationKey() async {
    final key = _licenseController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال مفتاح التفعيل أولاً';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    final isValid = _licenseService.verifyKey(
      deviceCode: _requestCode,
      enteredKey: key,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (isValid) {
      await _licenseService.saveActivation(key);
      widget.onActivationSuccess();
    } else {
      setState(() {
        _errorMessage = 'مفتاح التفعيل غير صحيح أو لا يخص هذا الجهاز';
      });
    }
  }

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldDark,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceDark,
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppTheme.primaryBlue,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'تفعيل الترخيص',
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أرسل كود جهازك عبر واتساب للحصول على مفتاح التفعيل الفوري.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // بطاقة كود الطلب مع زري النسخ والمراسلة
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'كود جهازك (Request Code):',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.scaffoldDark.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : SelectableText(
                                    _requestCode,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // زر نسخ الكود
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _copyRequestCode,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: Text('نسخ الكود', style: GoogleFonts.cairo(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.textMain,
                                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // زر المراسلة عبر واتساب
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _sendViaWhatsApp,
                                icon: const Icon(Icons.chat_rounded, size: 18),
                                label: Text('إرسال للواتساب', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E), // أخضر واتساب مريح
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // حقل إدخال مفتاح التفعيل
                  TextField(
                    controller: _licenseController,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoMono(
                      color: AppTheme.textMain,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      hintText: 'أدخل مفتاح التفعيل المستلم هنا',
                      hintStyle: GoogleFonts.cairo(
                        color: AppTheme.textSecondary.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                      ),
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.cairo(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // زر التفعيل
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyActivationKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF0F172A),
                              ),
                            )
                          : Text(
                              'تأكيد وتفعيل الترخيص',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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