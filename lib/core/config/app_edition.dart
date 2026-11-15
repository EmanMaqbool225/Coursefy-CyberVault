import 'package:flutter/material.dart';

enum EditionType { cyber, tech }

class AppEdition {
  // للعودة لكورساتك وفيديوهاتك الأصلية، اجعلي هذه tech
  static const EditionType current = EditionType.cyber;

  static const bool isCyber = current == EditionType.cyber;

  static String get appName => isCyber ? 'كورسفاي | الأمن السيبراني' : 'كورسفاي | التقنية والبرمجة';
  static String get editionBadge => isCyber ? 'Cyber Security Edition' : 'Tech & IT Edition';
  static String get shortName => isCyber ? 'Coursefy Cyber' : 'Coursefy Tech';

  static Color get primaryColor => isCyber ? const Color(0xFF10B981) : const Color(0xFF38BDF8);
  static IconData get editionIcon => isCyber ? Icons.security_rounded : Icons.terminal_rounded;

  // إصلاح الخطأ: استعادة اسم مجلدك الأصلي للنسخة التقنية حتى تظهر فيديوهاتك
  static String get vaultFolderName => isCyber ? 'Coursefy_CyberVault' : 'LockselVault';

  static String get dbFileName => isCyber ? 'courses_cyber_data.json' : 'courses_tech_data.json';

  // إصلاح الخطأ: استعادة مفتاح تشفيرك الأصلي حتى تفتح الفيديوهات
  static String get encryptionKey => isCyber
      ? 'COURSEFY_CYBER_SECURE_KEY_2026!!'
      : 'LOCKSEL_VIDEO_SECURE_KEY_2026_!!';
}