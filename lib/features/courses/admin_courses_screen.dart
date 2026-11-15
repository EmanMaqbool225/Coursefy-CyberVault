import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'course_model.dart';
import 'course_storage_service.dart';
import '../../core/config/app_edition.dart';


class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  final CourseStorageService _storageService = CourseStorageService();
  List<Course> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final list = await _storageService.getCourses();
    if (mounted) {
      setState(() {
        _courses = list;
        _isLoading = false;
      });
    }
  }

  // مستعرض اختيار مجلد كامل
  Future<String?> _pickFolderNative() async {
    try {
      final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
\$dialog.Description = "اختر مجلد الفيديوهات لإضافتها وتشفيرها"
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Output \$dialog.SelectedPath
}
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', script],
        stdoutEncoding: utf8,
      );

      final path = result.stdout.toString().trim();
      if (path.isNotEmpty && Directory(path).existsSync()) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  // مستعرض اختيار ملف فيديو فردي
  Future<String?> _pickVideoFileNative() async {
    try {
      final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.OpenFileDialog
\$dialog.Filter = "Video Files (*.mp4;*.mkv;*.avi)|*.mp4;*.mkv;*.avi|All Files (*.*)|*.*"
\$dialog.Title = "اختر ملف الفيديو لتشفيره"
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Output \$dialog.FileName
}
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', script],
        stdoutEncoding: utf8,
      );

      final path = result.stdout.toString().trim();
      if (path.isNotEmpty && File(path).existsSync()) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  // مستعرض اختيار صورة غلاف للكورس
  Future<String?> _pickImageFileNative() async {
    try {
      final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.OpenFileDialog
\$dialog.Filter = "Image Files (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg|All Files (*.*)|*.*"
\$dialog.Title = "اختر صورة غلاف الدورة"
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Output \$dialog.FileName
}
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', script],
        stdoutEncoding: utf8,
      );

      final path = result.stdout.toString().trim();
      if (path.isNotEmpty && File(path).existsSync()) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  // مستعرض اختيار ملفات المراجع (PDF أو ملفات نصية)
  Future<String?> _pickAttachmentFileNative() async {
    try {
      final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.OpenFileDialog
\$dialog.Filter = "Documents (*.pdf;*.txt;*.md)|*.pdf;*.txt;*.md|All Files (*.*)|*.*"
\$dialog.Title = "اختر الملف المرجعي لتشفيره وربطه بالدرس"
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Output \$dialog.FileName
}
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', script],
        stdoutEncoding: utf8,
      );

      final path = result.stdout.toString().trim();
      if (path.isNotEmpty && File(path).existsSync()) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  // تشفير ملف وحفظه في الخزينة
  Future<String?> _encryptFile(String rawFilePath, {String prefix = 'enc'}) async {
    try {
      final inputFile = File(rawFilePath);
      final bytes = await inputFile.readAsBytes();

      final key = enc.Key.fromUtf8(AppEdition.encryptionKey);
      final iv = enc.IV.fromUtf8('LOCKSEL_IV_V1_26');
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(bytes, iv: iv);

      
      // الحصول على مسار تشغيل التطبيق الفعلي
      final exeDir = File(Platform.resolvedExecutable).parent;
// توجيه الحفظ إلى داخل مجلد data المحمي الخاص بالتطبيق
     final secureFolder = Directory('${exeDir.path}\\data\\${AppEdition.vaultFolderName}');
      if (!await secureFolder.exists()) {
        await secureFolder.create(recursive: true);
      }

      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${rawFilePath.hashCode.abs()}.enc';
      final outputFile = File('${secureFolder.path}\\$fileName');
      await outputFile.writeAsBytes(encrypted.bytes);

      return fileName;
    } catch (e) {
      return null;
    }
  }

  // نافذة إدارة وإضافة المراجع للدرس
  void _showLessonAttachmentsDialog(Course course, Lesson lesson) {
    bool isImportingFolder = false;
    int currentFolderIdx = 0;
    int totalFolderCount = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: Row(
              children: [
                const Icon(Icons.folder_special_rounded, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مراجع ومرفقات: ${lesson.title}',
                    style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isImportingFolder) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final selectedPath = await _pickAttachmentFileNative();
                              if (selectedPath != null) {
                                final fileName = selectedPath.split(RegExp(r'[/\\]')).last;
                                final ext = fileName.split('.').last.toLowerCase();
                                final type = ext == 'pdf' ? 'pdf' : (ext == 'txt' || ext == 'md' ? 'text' : 'other');

                                final encPath = await _encryptFile(selectedPath, prefix: 'att');
                                if (encPath != null) {
                                  final newAtt = Attachment(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    name: fileName,
                                    path: encPath,
                                    type: type,
                                  );

                                  lesson.attachments = List<Attachment>.from(lesson.attachments)..add(newAtt);
                                  await _storageService.updateCourse(course);

                                  setDialogState(() {});
                                  setState(() {});
                                }
                              }
                            },
                            icon: const Icon(Icons.note_add_rounded, size: 18),
                            label: Text('ملف مفرد (PDF/نص)', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final folderPath = await _pickFolderNative();
                              if (folderPath != null) {
                                final dir = Directory(folderPath);
                                final allowedExts = ['.pdf', '.txt', '.md', '.doc', '.docx', '.png', '.jpg'];
                                final docFiles = dir.listSync().whereType<File>().where((f) {
                                  final ext = f.path.toLowerCase();
                                  return allowedExts.any((e) => ext.endsWith(e));
                                }).toList();

                                if (docFiles.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('لم يتم العثور على أي ملفات PDF أو مستندات في هذا المجلد!')),
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  isImportingFolder = true;
                                  totalFolderCount = docFiles.length;
                                  currentFolderIdx = 0;
                                });

                                final List<Attachment> addedAtts = List<Attachment>.from(lesson.attachments);

                                for (int i = 0; i < docFiles.length; i++) {
                                  final file = docFiles[i];
                                  final fName = file.path.split(RegExp(r'[/\\]')).last;
                                  final ext = fName.split('.').last.toLowerCase();
                                  final type = ext == 'pdf' ? 'pdf' : (ext == 'txt' || ext == 'md' ? 'text' : 'other');

                                  setDialogState(() => currentFolderIdx = i + 1);

                                  final encPath = await _encryptFile(file.path, prefix: 'att');
                                  if (encPath != null) {
                                    addedAtts.add(
                                      Attachment(
                                        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
                                        name: fName,
                                        path: encPath,
                                        type: type,
                                      ),
                                    );
                                  }
                                }

                                lesson.attachments = addedAtts;
                                await _storageService.updateCourse(course);

                                setDialogState(() {
                                  isImportingFolder = false;
                                });
                                setState(() {});
                              }
                            },
                            icon: const Icon(Icons.folder_zip_rounded, size: 18),
                            label: Text('استيراد مجلد مراجع كامل', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.scaffoldDark, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('جاري تشفير المراجع وحفظها...', style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('$currentFolderIdx / $totalFolderCount', style: GoogleFonts.robotoMono(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: totalFolderCount > 0 ? currentFolderIdx / totalFolderCount : null,
                              minHeight: 6,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Text('المراجع المرتبطة بالدرس (${lesson.attachments.length}):', style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),

                  if (lesson.attachments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('لا توجد مراجع مرفقة حالياً.', style: GoogleFonts.cairo(color: AppTheme.textSecondary)),
                      ),
                    )
                  else
                    SizedBox(
                      height: 190,
                      child: ListView.builder(
                        itemCount: lesson.attachments.length,
                        itemBuilder: (context, idx) {
                          final att = lesson.attachments[idx];
                          return Card(
                            color: AppTheme.scaffoldDark,
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                att.type == 'pdf'
                                    ? Icons.picture_as_pdf_rounded
                                    : (att.type == 'text' ? Icons.description_rounded : Icons.insert_drive_file_rounded),
                                color: att.type == 'pdf' ? Colors.redAccent : Colors.tealAccent,
                                size: 22,
                              ),
                              title: Text(att.name, style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 13), maxLines: 1),
                              subtitle: Text(att.type.toUpperCase(), style: GoogleFonts.robotoMono(color: AppTheme.textSecondary, fontSize: 10)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                onPressed: () async {
                                  lesson.attachments.removeAt(idx);
                                  await _storageService.updateCourse(course);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              if (!isImportingFolder)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إغلاق', style: GoogleFonts.cairo(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // استيراد مجلد كامل دفعة واحدة
  void _showBatchImportDialog(Course course) {
    String? selectedFolderPath;
    List<File> detectedVideos = [];
    bool isProcessing = false;
    int currentIndex = 0;
    int totalCount = 0;
    String currentFileName = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: Text(
              'استيراد مجلد كامل إلى (${course.title})',
              style: GoogleFonts.cairo(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اختاري مجلداً من جهازك يحتوي على مقاطع (.mp4, .mkv, .avi) ليتم تشفيرها وإضافتها كدروس تلقائياً.',
                    style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (!isProcessing) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        final folder = await _pickFolderNative();
                        if (folder != null) {
                          final dir = Directory(folder);
                          final files = dir.listSync().whereType<File>().where((f) {
                            final ext = f.path.toLowerCase();
                            return ext.endsWith('.mp4') || ext.endsWith('.mkv') || ext.endsWith('.avi');
                          }).toList();

                          setModalState(() {
                            selectedFolderPath = folder;
                            detectedVideos = files;
                          });
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded),
                      label: Text('اختيار المجلد من الجهاز', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (selectedFolderPath != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.scaffoldDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('المسار المحدد: $selectedFolderPath', style: GoogleFonts.robotoMono(color: AppTheme.textSecondary, fontSize: 11), maxLines: 1),
                            const SizedBox(height: 6),
                            Text(
                              'تم العثور على ${detectedVideos.length} مقطع فيديو جاهز للتشفير.',
                              style: GoogleFonts.cairo(color: detectedVideos.isNotEmpty ? Colors.greenAccent : Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('جاري تشفير وحفظ المقاطع...', style: GoogleFonts.cairo(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                            Text('$currentIndex / $totalCount', style: GoogleFonts.robotoMono(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: totalCount > 0 ? currentIndex / totalCount : null,
                            minHeight: 8,
                            backgroundColor: AppTheme.scaffoldDark,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          currentFileName,
                          style: GoogleFonts.robotoMono(color: AppTheme.textSecondary, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!isProcessing)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء', style: GoogleFonts.cairo(color: AppTheme.textSecondary)),
                ),
              ElevatedButton(
                onPressed: (isProcessing || detectedVideos.isEmpty)
                    ? null
                    : () async {
                        setModalState(() {
                          isProcessing = true;
                          totalCount = detectedVideos.length;
                          currentIndex = 0;
                        });

                        final List<Lesson> newLessons = List.from(course.lessons);

                        for (int i = 0; i < detectedVideos.length; i++) {
                          final file = detectedVideos[i];
                          final fileName = file.path.split(RegExp(r'[/\\]')).last;
                          final cleanTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

                          setModalState(() {
                            currentIndex = i + 1;
                            currentFileName = 'تشفير: $fileName';
                          });

                          final encryptedPath = await _encryptFile(file.path, prefix: 'enc');
                          if (encryptedPath != null) {
                            newLessons.add(
                              Lesson(
                                id: '${DateTime.now().millisecondsSinceEpoch}_$i',
                                title: cleanTitle,
                                duration: 'غير محدد',
                                videoPath: encryptedPath,
                                attachments: [],
                              ),
                            );
                          }
                        }

                        final updatedCourse = Course(
                          id: course.id,
                          title: course.title,
                          instructor: course.instructor,
                          duration: course.duration,
                          lessonsCount: newLessons.length,
                          iconData: course.iconData,
                          lessons: newLessons,
                          description: course.description, // الحفاظ على النبذة
                          imagePath: course.imagePath,     // الحفاظ على الصورة
                        );

                        await _storageService.updateCourse(updatedCourse);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _loadCourses();
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                child: Text('بدء الاستيراد والتشفير', style: GoogleFonts.cairo(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // إضافة فيديو مفرد
  void _showAddSingleLessonDialog(Course course) {
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    String? encryptedResultPath;
    bool isEncrypting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: Text(
              'إضافة فيديو مشفر مفرد',
              style: GoogleFonts.cairo(color: AppTheme.textMain, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.cairo(color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'عنوان الدرس',
                      labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.scaffoldDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationCtrl,
                    style: GoogleFonts.cairo(color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'المدة (مثال: 12 دقيقة)',
                      labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.scaffoldDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.scaffoldDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          onPressed: isEncrypting
                              ? null
                              : () async {
                                  final selectedPath = await _pickVideoFileNative();
                                  if (selectedPath != null) {
                                    setDialogState(() {
                                      isEncrypting = true;
                                      if (titleCtrl.text.isEmpty) {
                                        final name = selectedPath.split(RegExp(r'[/\\]')).last;
                                        titleCtrl.text = name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                                      }
                                    });

                                    final encPath = await _encryptFile(selectedPath, prefix: 'enc');

                                    setDialogState(() {
                                      isEncrypting = false;
                                      encryptedResultPath = encPath;
                                    });
                                  }
                                },
                          icon: isEncrypting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.video_file_rounded),
                          label: Text(
                            isEncrypting ? 'جاري التشفير...' : 'اختيار فيديو وتشفيره',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (encryptedResultPath != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('تم التشفير والحفظ بنجاح!', style: GoogleFonts.cairo(color: Colors.greenAccent, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (isEncrypting || encryptedResultPath == null)
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty) return;

                        final newLesson = Lesson(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleCtrl.text.trim(),
                          duration: durationCtrl.text.trim().isEmpty ? 'غير محدد' : durationCtrl.text.trim(),
                          videoPath: encryptedResultPath!,
                          attachments: [],
                        );

                        final updatedLessons = List<Lesson>.from(course.lessons)..add(newLesson);
                        final updatedCourse = Course(
                          id: course.id,
                          title: course.title,
                          instructor: course.instructor,
                          duration: course.duration,
                          lessonsCount: updatedLessons.length,
                          iconData: course.iconData,
                          lessons: updatedLessons,
                          description: course.description, // الحفاظ على النبذة
                          imagePath: course.imagePath,     // الحفاظ على الصورة
                        );

                        await _storageService.updateCourse(updatedCourse);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _loadCourses();
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                child: Text('حفظ الدرس', style: GoogleFonts.cairo(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // نافذة تعديل بيانات الكورس (محدثة لدعم الصورة والنبذة)
  void _showEditCourseDialog(Course course) {
    final titleCtrl = TextEditingController(text: course.title);
    final instructorCtrl = TextEditingController(text: course.instructor);
    final durationCtrl = TextEditingController(text: course.duration);
    final descCtrl = TextEditingController(text: course.description);
    String? selectedImagePath = course.imagePath.isEmpty ? null : course.imagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: Text(
              'تعديل معلومات الدورة',
              style: GoogleFonts.cairo(color: AppTheme.textMain, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.cairo(color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'عنوان الدورة',
                      labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: instructorCtrl,
                    style: GoogleFonts.cairo(color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'اسم المدرب',
                      labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationCtrl,
                    style: GoogleFonts.cairo(color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'إجمالي الساعات',
                      labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    style: GoogleFonts.cairo(color: AppTheme.textMain),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'نبذة عن الدورة (الوصف)',
                      labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.scaffoldDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final path = await _pickImageFileNative();
                            if (path != null) {
                              setDialogState(() => selectedImagePath = path);
                            }
                          },
                          icon: const Icon(Icons.image_rounded),
                          label: Text(
                            selectedImagePath == null ? 'اختيار صورة الغلاف' : 'تغيير صورة الغلاف',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
                            foregroundColor: AppTheme.primaryBlue,
                            elevation: 0,
                          ),
                        ),
                        if (selectedImagePath != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            selectedImagePath!.split(RegExp(r'[/\\]')).last,
                            style: GoogleFonts.robotoMono(color: Colors.greenAccent, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;

                  final updatedCourse = Course(
                    id: course.id,
                    title: titleCtrl.text.trim(),
                    instructor: instructorCtrl.text.trim().isEmpty ? 'غير محدد' : instructorCtrl.text.trim(),
                    duration: durationCtrl.text.trim().isEmpty ? 'مفتوح' : durationCtrl.text.trim(),
                    lessonsCount: course.lessons.length,
                    iconData: course.iconData,
                    lessons: course.lessons,
                    description: descCtrl.text.trim(),
                    imagePath: selectedImagePath ?? '',
                  );

                  await _storageService.updateCourse(updatedCourse);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadCourses();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                child: Text(
                  'حفظ التعديل',
                  style: GoogleFonts.cairo(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // نافذة إضافة مسار تعليمي (محدثة لدعم الصورة والنبذة)
  void _showAddCourseDialog() {
    final titleCtrl = TextEditingController();
    final instructorCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: Text('إضافة مسار تعليمي جديد', style: GoogleFonts.cairo(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, style: GoogleFonts.cairo(color: AppTheme.textMain), decoration: InputDecoration(labelText: 'عنوان الدورة', labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary))),
                  const SizedBox(height: 8),
                  TextField(controller: instructorCtrl, style: GoogleFonts.cairo(color: AppTheme.textMain), decoration: InputDecoration(labelText: 'اسم المدرب', labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary))),
                  const SizedBox(height: 8),
                  TextField(controller: durationCtrl, style: GoogleFonts.cairo(color: AppTheme.textMain), decoration: InputDecoration(labelText: 'إجمالي الساعات', labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    style: GoogleFonts.cairo(color: AppTheme.textMain),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'نبذة عن الدورة (الوصف)',
                      labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.scaffoldDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final path = await _pickImageFileNative();
                            if (path != null) {
                              setDialogState(() => selectedImagePath = path);
                            }
                          },
                          icon: const Icon(Icons.image_rounded),
                          label: Text(
                            selectedImagePath == null ? 'اختيار صورة الغلاف' : 'تم اختيار الصورة بنجاح',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
                            foregroundColor: AppTheme.primaryBlue,
                            elevation: 0,
                          ),
                        ),
                        if (selectedImagePath != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            selectedImagePath!.split(RegExp(r'[/\\]')).last,
                            style: GoogleFonts.robotoMono(color: Colors.greenAccent, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(color: AppTheme.textSecondary))),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final newCourse = Course(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleCtrl.text.trim(),
                    instructor: instructorCtrl.text.trim().isEmpty ? 'غير محدد' : instructorCtrl.text.trim(),
                    duration: durationCtrl.text.trim().isEmpty ? 'مفتوح' : durationCtrl.text.trim(),
                    description: descCtrl.text.trim(), // حفظ النبذة
                    imagePath: selectedImagePath ?? '', // حفظ الصورة
                    lessonsCount: 0,
                    lessons: [],
                  );
                  await _storageService.addCourse(newCourse);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadCourses();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                child: Text('حفظ المسار', style: GoogleFonts.cairo(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldDark,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceDark,
          title: Text('لوحة تحكم الأدمن (التشفير وإدارة المحتوى)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              onPressed: _showAddCourseDialog,
              icon: const Icon(Icons.add_circle_rounded, color: AppTheme.primaryBlue, size: 28),
              tooltip: 'إضافة دورة جديدة',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _courses.length,
                itemBuilder: (ctx, i) {
                  final c = _courses[i];
                  return Card(
                    color: AppTheme.surfaceDark,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0284C7),
                        child: Icon(Icons.video_library_rounded, color: Colors.white, size: 20),
                      ),
                      title: Text(c.title, style: GoogleFonts.cairo(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                      subtitle: Text('${c.instructor} • ${c.lessons.length} فيديوهات مشفرة', style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.lightBlueAccent, size: 24),
                            tooltip: 'تعديل معلومات الدورة',
                            onPressed: () => _showEditCourseDialog(c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.create_new_folder_rounded, color: Colors.amberAccent, size: 26),
                            tooltip: 'استيراد مجلد كامل وتشفيره',
                            onPressed: () => _showBatchImportDialog(c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.video_call_rounded, color: Colors.greenAccent, size: 26),
                            tooltip: 'إضافة فيديو مفرد',
                            onPressed: () => _showAddSingleLessonDialog(c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            tooltip: 'حذف الدورة',
                            onPressed: () async {
                              await _storageService.deleteCourse(c.id);
                              _loadCourses();
                            },
                          ),
                        ],
                      ),
                      children: c.lessons.map((lesson) {
                        final hasAttachments = lesson.attachments.isNotEmpty;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                          leading: const Icon(Icons.lock_rounded, color: AppTheme.primaryBlue, size: 20),
                          title: Text(lesson.title, style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 13)),
                          subtitle: Text(
                            hasAttachments ? 'المرفقات: ${lesson.attachments.length} ملفات' : 'لا توجد مرفقات',
                            style: GoogleFonts.cairo(color: hasAttachments ? Colors.tealAccent : AppTheme.textSecondary, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  hasAttachments ? Icons.attach_file_rounded : Icons.attachment_rounded,
                                  color: hasAttachments ? Colors.amberAccent : Colors.white60,
                                ),
                                tooltip: 'إدارة المراجع والمرفقات (PDF/نصوص)',
                                onPressed: () => _showLessonAttachmentsDialog(c, lesson),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () async {
                                  final updatedLessons = List<Lesson>.from(c.lessons)..removeWhere((l) => l.id == lesson.id);
                                  final updatedCourse = Course(
                                    id: c.id,
                                    title: c.title,
                                    instructor: c.instructor,
                                    duration: c.duration,
                                    lessonsCount: updatedLessons.length,
                                    iconData: c.iconData,
                                    lessons: updatedLessons,
                                    description: c.description, // الحفاظ على النبذة عند حذف درس
                                    imagePath: c.imagePath,     // الحفاظ على الصورة عند حذف درس
                                  );
                                  await _storageService.updateCourse(updatedCourse);
                                  _loadCourses();
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
      ),
    );
  }
}