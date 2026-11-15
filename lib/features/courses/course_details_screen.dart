import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'course_model.dart';
import 'course_storage_service.dart';
import 'secure_video_player_screen.dart';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import '../../core/config/app_edition.dart'; 

class CourseDetailsScreen extends StatefulWidget {
  final Course course;

  const CourseDetailsScreen({super.key, required this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  late Course _currentCourse;
  final CourseStorageService _storageService = CourseStorageService();
  final TextEditingController _lessonSearchCtrl = TextEditingController();
  String _searchQuery = '';



  @override
  void initState() {
    super.initState();
    _currentCourse = widget.course;
  }

  @override
  void dispose() {
    _lessonSearchCtrl.dispose();
    super.dispose();
  }

  // فك تشفير المرجع وفتحه بأمان للمطالعة
  Future<void> _openSecureAttachment(Attachment att) async {
  try {
    // جلب مسار البرنامج الحالي
    final exeDir = File(Platform.resolvedExecutable).parent;
    // دمج المسار للوصول إلى ملف المرجع المشفر
    final fullPath = '${exeDir.path}\\data\\${AppEdition.vaultFolderName}\\${att.path}';
    
    final file = File(fullPath);
    if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ملف المرجع غير موجود أو تم نقله!'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      final encryptedBytes = await file.readAsBytes();
     final key = enc.Key.fromUtf8(AppEdition.encryptionKey);
      final iv = enc.IV.fromUtf8('LOCKSEL_IV_V1_26');
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);

      // استخراج الامتداد المناسب
      final ext = att.name.split('.').last.toLowerCase();
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}\\coursefy_doc_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(decrypted, flush: true);

      // فتح الملف في عارض ويندوز الافتراضي
      await Process.run('explorer.exe', [tempFilePath]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح المرجع: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // نافذة عرض المراجع المتاحة للطالب
  void _showStudentAttachmentsDialog(Lesson lesson) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: AppTheme.primaryBlue, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المراجع والمرفقات: ${lesson.title}',
                        style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                Text(
                  'انقر على أي ملف للمطالعة المباشرة:',
                  style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: lesson.attachments.length,
                    itemBuilder: (context, idx) {
                      final att = lesson.attachments[idx];
                      return Card(
                        color: AppTheme.scaffoldDark,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: att.type == 'pdf'
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : Colors.tealAccent.withValues(alpha: 0.15),
                            child: Icon(
                              att.type == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                              color: att.type == 'pdf' ? Colors.redAccent : Colors.tealAccent,
                              size: 20,
                            ),
                          ),
                          title: Text(att.name, style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                          trailing: ElevatedButton.icon(
                            onPressed: () => _openSecureAttachment(att),
                            icon: const Icon(Icons.visibility_rounded, size: 16),
                            label: Text('قراءة', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markLessonCompleted(Lesson lesson) async {
    if (!lesson.isCompleted) {
      setState(() {
        lesson.isCompleted = true;
      });
      await _storageService.updateCourse(_currentCourse);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تهانينا! تم إكمال درس "${lesson.title}" 🎉'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleLessonCompletion(Lesson lesson) async {
    setState(() {
      lesson.isCompleted = !lesson.isCompleted;
    });
    await _storageService.updateCourse(_currentCourse);
  }

  Future<void> _toggleFavorite(Lesson lesson) async {
    setState(() {
      lesson.isFavorite = !lesson.isFavorite;
    });
    await _storageService.updateCourse(_currentCourse);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lesson.isFavorite ? 'تمت الإضافة إلى المفضلة ⭐' : 'تمت الإزالة من المفضلة'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercentage = (_currentCourse.progress * 100).toInt();

    // دالة توحيد الأرقام المشرقية (٠١٢٣٤٥٦٧٨٩) إلى إنجليزية
    String normalizeNumbers(String input) {
      const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
      const englishDigits = '0123456789';
      for (int i = 0; i < arabicDigits.length; i++) {
        input = input.replaceAll(arabicDigits[i], englishDigits[i]);
      }
      return input;
    }

    final rawQuery = normalizeNumbers(_searchQuery.trim().toLowerCase());

    final filteredLessons = _currentCourse.lessons.where((lesson) {
      if (rawQuery.isEmpty) return true;

      final normalizedTitle = normalizeNumbers(lesson.title.toLowerCase());

      // إذا كان الإدخال في شريط البحث عبارة عن رقم فقط (مثل "3" أو "الدرس 3" أو "#3")
      final numberSearchMatch = RegExp(r'^(?:درس|الدرس|#)?\s*(\d+)$').firstMatch(rawQuery);

      if (numberSearchMatch != null) {
        final targetNum = numberSearchMatch.group(1)!;

        // مطابقة الرقم كرقم كامل مستقل محاط بحدود كلمات أو رموز (مثل "3." أو " 3 " أو بداية السطر)
        // هذا الشرط يمنع ظهور الرقم 100 أو 30 نهائياً عند البحث عن 3
        final exactNumberInTitle = RegExp('(^|[^0-9])' + RegExp.escape(targetNum) + '([^0-9]|\$)');
        return exactNumberInTitle.hasMatch(normalizedTitle);
      }

      // إذا كان البحث نصياً نبحث بالاسم أو بالمسار
      final titleMatch = normalizedTitle.contains(rawQuery);
      final pathMatch = lesson.videoPath.toLowerCase().contains(rawQuery);

      return titleMatch || pathMatch;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldDark,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceDark,
          title: Text(_currentCourse.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // كرت معلومات الكورس والتقدم
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                          child: Icon(_currentCourse.iconData, color: AppTheme.primaryBlue, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_currentCourse.title, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                              Text('المدرب: ${_currentCourse.instructor} • إجمالي المدة: ${_currentCourse.duration}', style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Text(
                          '$progressPercentage%',
                          style: GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _currentCourse.progress,
                        minHeight: 8,
                        backgroundColor: AppTheme.scaffoldDark,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // رأس القائمة ومربع البحث
              Row(
                children: [
                  Text(
                    'فهرس الدروس المشفرة',
                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                  ),
                  const Spacer(),
                  Text(
                    '(${filteredLessons.length} من ${_currentCourse.lessons.length})',
                    style: GoogleFonts.robotoMono(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // مربع البحث داخل الدروس
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _lessonSearchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم الدرس (مثلاً: 1)، العنوان، أو الامتداد...',
                    hintStyle: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 16),
                            onPressed: () {
                              _lessonSearchCtrl.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // عرض قائمة الدروس المفلترة
              Expanded(
                child: _currentCourse.lessons.isEmpty
                    ? Center(
                        child: Text('لا توجد دروس متاحة في هذه الدورة حالياً.', style: GoogleFonts.cairo(color: AppTheme.textSecondary)),
                      )
                    : filteredLessons.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                                const SizedBox(height: 10),
                                Text(
                                  'لا يوجد درس يطابق "$_searchQuery"',
                                  style: GoogleFonts.cairo(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredLessons.length,
                            itemBuilder: (ctx, idx) {
                              final lesson = filteredLessons[idx];
                              return Card(
                                color: AppTheme.surfaceDark,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: lesson.isCompleted ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.transparent,
                                  ),
                                ),
                                child: ListTile(
                                  leading: IconButton(
                                    icon: Icon(
                                      lesson.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: lesson.isCompleted ? Colors.greenAccent : AppTheme.textSecondary,
                                      size: 26,
                                    ),
                                    tooltip: lesson.isCompleted ? 'مكتمل (اضغط للإلغاء)' : 'تحديد كمكتمل',
                                    onPressed: () => _toggleLessonCompletion(lesson),
                                  ),
                                  title: Text(
                                    lesson.title,
                                    style: GoogleFonts.cairo(
                                      color: AppTheme.textMain,
                                      fontWeight: FontWeight.w600,
                                      decoration: lesson.isCompleted ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  subtitle: Text('المدة: ${lesson.duration}', style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 12)),
                                 trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // زر المراجع والمرفقات (يظهر فقط إذا كان الدرس يحتوي على مراجع)
                                      if (lesson.attachments.isNotEmpty)
                                        IconButton(
                                          icon: Badge(
                                            label: Text('${lesson.attachments.length}'),
                                            backgroundColor: Colors.tealAccent.shade700,
                                            child: const Icon(Icons.attach_file_rounded, color: Colors.tealAccent),
                                          ),
                                          tooltip: 'المراجع والملفات المرفقة',
                                          onPressed: () => _showStudentAttachmentsDialog(lesson),
                                        ),

                                      IconButton(
                                        icon: Icon(
                                          lesson.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                                          color: lesson.isFavorite ? Colors.amber : AppTheme.textSecondary,
                                        ),
                                        tooltip: 'المفضلة',
                                        onPressed: () => _toggleFavorite(lesson),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SecureVideoPlayerScreen(
                                                title: lesson.title,
                                                encryptedFilePath: lesson.videoPath,
                                                onVideoCompleted: () => _markLessonCompleted(lesson),
                                              ),
                                            ),
                                          ).then((_) => setState(() {}));
                                        },
                                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                        label: Text('مشاهدة', style: GoogleFonts.cairo(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryBlue,
                                          foregroundColor: const Color(0xFF0F172A),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}