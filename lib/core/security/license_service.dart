import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LicenseService {
  // مفتاح سري خاص بمنظومتك لتوقيع التراخيص (يمكنك تعديل هذه العبارة لاحقاً)
  static const String _secretSalt = "LOCKSEL_MASTER_SECURITY_KEY_2026";
  static const String _storageKey = "locksel_license_activated";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// التحقق من صحة مفتاح التفعيل مقارنة ببصمة الجهاز
  bool verifyKey({required String deviceCode, required String enteredKey}) {
    final expectedKey = generateLicenseKey(deviceCode);
    return expectedKey.toUpperCase().trim() == enteredKey.toUpperCase().trim();
  }

  /// خوارزمية توليد المفتاح المطابق لبصمة الجهاز
  static String generateLicenseKey(String deviceCode) {
    // تنظيف الكود من الفواصل
    final cleanCode = deviceCode.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    
    // دمج بصمة الجهاز مع المفتاح السري وتشفيرهما بـ HMAC-SHA256
    final hmac = Hmac(sha256, utf8.encode(_secretSalt));
    final digest = hmac.convert(utf8.encode(cleanCode));
    final hash = digest.toString().toUpperCase();

    // تشكيل مفتاح ترخيص منظم وسهل القراءة: ACT-XXXX-XXXX-XXXX
    final part1 = hash.substring(0, 4);
    final part2 = hash.substring(4, 8);
    final part3 = hash.substring(8, 12);

    return 'ACT-$part1-$part2-$part3';
  }

  /// حفظ حالة التفعيل في التخزين المشفر للجهاز
  Future<void> saveActivation(String validKey) async {
    await _storage.write(key: _storageKey, value: validKey);
  }

  /// التحقق مما إذا كان التطبيق مفعلاً مسبقاً على هذا الجهاز
  Future<bool> isAlreadyActivated(String currentDeviceCode) async {
    final savedKey = await _storage.read(key: _storageKey);
    if (savedKey == null) return false;
    return verifyKey(deviceCode: currentDeviceCode, enteredKey: savedKey);
  }
}