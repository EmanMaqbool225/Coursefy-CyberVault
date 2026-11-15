import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/app_edition.dart';
import 'course_model.dart';

class CourseStorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String get _coursesKey => AppEdition.isCyber
      ? 'locksel_cyber_courses_data_v2' 
      : 'locksel_saved_courses_data'; 

  // الدالة التي تحدد مسار ملف الكورسات المحمول بجوار الفيديوهات
  Future<File> _getLocalFile() async {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final filePath = '${exeDir.path}\\data\\courses.json';
    return File(filePath);
  }

  Future<List<Course>> getCourses() async {
    try {
      final file = await _getLocalFile();

      // 1. هل ملف الكورسات موجود بالفعل بجوار البرنامج؟ (سيعمل هذا عند صديقتك)
      if (await file.exists()) {
        final String jsonString = await file.readAsString();
        if (jsonString.isNotEmpty) {
          final List decoded = json.decode(jsonString);
          return decoded.map((e) => Course.fromMap(e as Map<String, dynamic>)).toList();
        }
      } else {
        // 2. إذا لم يكن موجوداً (في جهازك أنتِ)، نسحب البيانات من خزنة الويندوز السرية
        final rawData = await _secureStorage.read(key: _coursesKey);
        if (rawData != null && rawData.isNotEmpty) {
          // ننسخ البيانات فوراً إلى الملف المحمول الجديد
          await file.create(recursive: true);
          await file.writeAsString(rawData);
          
          final List decoded = json.decode(rawData);
          return decoded.map((e) => Course.fromMap(e as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Storage Error: $e');
      return [];
    }
  }

  Future<void> addCourse(Course course) async {
    final current = await getCourses();
    current.add(course);
    await _saveAll(current);
  }

  Future<void> updateCourse(Course updatedCourse) async {
    final current = await getCourses();
    final index = current.indexWhere((c) => c.id == updatedCourse.id);
    if (index != -1) {
      current[index] = updatedCourse;
      await _saveAll(current);
    }
  }

  Future<void> deleteCourse(String id) async {
    final current = await getCourses();
    current.removeWhere((item) => item.id == id);
    await _saveAll(current);
  }

  Future<void> _saveAll(List<Course> courses) async {
    final file = await _getLocalFile();
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    final raw = json.encode(courses.map((e) => e.toMap()).toList());
    
    // حفظ البيانات في الملف المحمول
    await file.writeAsString(raw);
    
    // حفظ نسخة احتياطية في خزنة الويندوز
    await _secureStorage.write(key: _coursesKey, value: raw);
  }
}