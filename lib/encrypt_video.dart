import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

void main(List<String> args) async {
  if (args.isEmpty) {
    print('--------------------------------------------------');
    print('  Locksel Video Encryptor - أداة تشفير الفيديوهات  ');
    print('--------------------------------------------------');
    print('الاستخدام:');
    print('dart run bin/encrypt_video.dart "مسار_الفيديو.mp4"');
    print('--------------------------------------------------');
    return;
  }

  final inputPath = args[0].replaceAll('"', '').trim();
  final inputFile = File(inputPath);

  if (!await inputFile.exists()) {
    print('خطأ: لم يتم العثور على الملف في المسار المحدد: $inputPath');
    return;
  }

  print('جاري قراءة ملف الفيديو: ${inputFile.path} ...');
  final fileBytes = await inputFile.readAsBytes();

  // المفتاح السري الثابت لنظام Locksel (32 بايت = 256 بت)
  final key = enc.Key.fromUtf8('LOCKSEL_VIDEO_SECURE_KEY_2026_!!');
  // متجه التهيئة IV (16 بايت)
  final iv = enc.IV.fromUtf8('LOCKSEL_IV_V1_26');

  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

  print('جاري تشفير الفيديو باستخدام AES-256 ...');
  final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);

  final outputPath = inputPath.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '') + '.enc';
  final outputFile = File(outputPath);

  await outputFile.writeAsBytes(encrypted.bytes);

  print('--------------------------------------------------');
  print('تم التشفير بنجاح! 🎉');
  print('الملف المشفر الناتج: $outputPath');
  print('الحجم: ${(outputFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} ميغابايت');
  print('--------------------------------------------------');
}