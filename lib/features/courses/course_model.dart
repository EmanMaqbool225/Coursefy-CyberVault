import 'dart:convert';
import 'package:flutter/material.dart';

// نموذج المرفقات والمراجع المشفرة (PDF، نصوص، وغيرها)
class Attachment {
  final String id;
  final String name;
  final String path;
  final String type; // 'pdf', 'text', 'other'

  Attachment({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      path: map['path'] ?? '',
      type: map['type'] ?? 'other',
    );
  }
}

class Lesson {
  final String id;
  final String title;
  final String duration;
  final String videoPath;
  bool isCompleted;
  bool isFavorite;
  List<Attachment> attachments; // قائمة المراجع والمرفقات للدرس

  Lesson({
    required this.id,
    required this.title,
    required this.duration,
    required this.videoPath,
    this.isCompleted = false,
    this.isFavorite = false,
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'videoPath': videoPath,
      'isCompleted': isCompleted,
      'isFavorite': isFavorite,
      'attachments': attachments.map((a) => a.toMap()).toList(),
    };
  }

  factory Lesson.fromMap(Map<String, dynamic> map) {
    List<Attachment> parsedAttachments = [];
    if (map['attachments'] != null && map['attachments'] is List) {
      for (var item in map['attachments']) {
        if (item != null && item is Map<String, dynamic>) {
          parsedAttachments.add(Attachment.fromMap(item));
        }
      }
    }

    return Lesson(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      duration: map['duration']?.toString() ?? '',
      videoPath: map['videoPath']?.toString() ?? '',
      isCompleted: map['isCompleted'] == true,
      isFavorite: map['isFavorite'] == true,
      attachments: parsedAttachments,
    );
  }
}

class Course {
  final String id;
  final String title;
  final String instructor;
  final String duration;
  final int lessonsCount;
  final IconData iconData;
  final List<Lesson> lessons;
  
  // الحقول الجديدة التي أضفناها
  final String description;
  final String imagePath;

  Course({
    required this.id,
    required this.title,
    required this.instructor,
    required this.duration,
    required this.lessonsCount,
    this.iconData = Icons.auto_stories_rounded,
    this.lessons = const [],
    this.description = '', // قيمة افتراضية حتى لا تتعطل الكورسات القديمة
    this.imagePath = '',   // مسار الصورة من الكمبيوتر
  });

  double get progress {
    if (lessons.isEmpty) return 0.0;
    final completedCount = lessons.where((l) => l.isCompleted).length;
    return completedCount / lessons.length;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'instructor': instructor,
      'duration': duration,
      'lessonsCount': lessonsCount,
      'iconCodePoint': iconData.codePoint,
      'description': description, // حفظ النبذة
      'imagePath': imagePath,     // حفظ مسار الصورة
      'lessons': lessons.map((l) => l.toMap()).toList(),
    };
  }

  static String toJsonList(List<Course> list) {
    return json.encode(list.map((c) => c.toMap()).toList());
  }

  static List<Course> fromJsonList(String jsonStr) {
    if (jsonStr.trim().isEmpty) return [];
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded.map((item) => Course.fromMap(item as Map<String, dynamic>)).toList();
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    var rawLessons = map['lessons'] as List? ?? [];
    return Course(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      instructor: map['instructor'] ?? '',
      duration: map['duration'] ?? '',
      lessonsCount: map['lessonsCount'] ?? 0,
      description: map['description'] ?? '', // استدعاء النبذة بأمان
      imagePath: map['imagePath'] ?? '',     // استدعاء الصورة بأمان
      iconData: map['iconCodePoint'] != null
          ? IconData(map['iconCodePoint'], fontFamily: 'MaterialIcons')
          : Icons.auto_stories_rounded,
      lessons: rawLessons.map((e) => Lesson.fromMap(e)).toList(),
    );
  }

  String toJson() => json.encode(toMap());
  factory Course.fromJson(String source) => Course.fromMap(json.decode(source));
}