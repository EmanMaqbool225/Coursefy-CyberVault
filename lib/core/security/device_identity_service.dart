import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceIdentityService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// جلب بصمة العتاد الفريدة للنظام الحالي (سواء كان هاتفاً أو ويندوز)
  Future<String> getHardwareFingerprint() async {
    String rawIdentifier = '';

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        // دمج معرّفات فريدة وثابتة للجهاز
        rawIdentifier = '${androidInfo.id}_${androidInfo.hardware}_${androidInfo.brand}_${androidInfo.model}';
      } else if (Platform.isWindows) {
        WindowsDeviceInfo windowsInfo = await _deviceInfo.windowsInfo;
        // معرّف GUID الفريد للوحة والويندوز
        rawIdentifier = '${windowsInfo.deviceId}_${windowsInfo.computerName}';
      } else {
        rawIdentifier = 'unsupported_platform_${Platform.operatingSystem}';
      }
    } catch (e) {
      rawIdentifier = 'fallback_device_identifier_default';
    }

    // تجزئة المعرّف الخام باستخدام SHA-256
    final bytes = utf8.encode(rawIdentifier);
    final digest = sha256.convert(bytes);
    final hashString = digest.toString().toUpperCase();

    // تنسيق البصمة إلى كود سهل القراءة للطالب (مثل: LK-XXXX-XXXX-XXXX)
    return _formatAsKeyCode(hashString);
  }

  /// تحويل الهاش الطويل إلى كتل مقروءة وسهلة النسخ والمشاركة
  String _formatAsKeyCode(String hash) {
    // نأخذ أول 16 حرفاً ونقسمها لـ 4 مجموعات
    final sub = hash.substring(0, 16);
    return 'LK-${sub.substring(0, 4)}-${sub.substring(4, 8)}-${sub.substring(8, 12)}-${sub.substring(12, 16)}';
  }
}