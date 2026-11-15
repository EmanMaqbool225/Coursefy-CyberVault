import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/security/device_identity_service.dart';
import '../../core/theme/app_theme.dart';
import 'admin_courses_screen.dart';
import 'course_details_screen.dart';
import 'course_model.dart';
import 'course_storage_service.dart';
import 'secure_video_player_screen.dart';
import '../../core/config/app_edition.dart';

class HomeCoursesScreen extends StatefulWidget {
  const HomeCoursesScreen({super.key});

  @override
  State<HomeCoursesScreen> createState() => _HomeCoursesScreenState();
}

class _HomeCoursesScreenState extends State<HomeCoursesScreen> with SingleTickerProviderStateMixin {
  final CourseStorageService _storageService = CourseStorageService();
  List<Course> _courses = [];
  bool _isLoading = true;
  int _secretTapCount = 0;
  late TabController _tabController;
  String _hardwareFingerprint = 'جاري القراءة...';
  
  final TextEditingController _searchCtrl = TextEditingController();
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCourses();
    _loadHardwareId();
  }

  Future<void> _loadHardwareId() async {
    final hid = await DeviceIdentityService().getHardwareFingerprint();
    if (mounted) setState(() => _hardwareFingerprint = hid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCourses() async {
    final list = await _storageService.getCourses();
    if (mounted) {
      setState(() {
        _courses = list;
        _isLoading = false;
      });
    }
  }

  void _handleSecretTap() {
    _secretTapCount++;
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _showAdminPinDialog();
    }
  }

  void _showAdminPinDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: Text(
            'الدخول لإدارة المحتوى',
            style: GoogleFonts.cairo(color: AppTheme.textMain, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: pinCtrl,
            obscureText: true,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'رمز المرور السري (PIN)',
              hintStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.scaffoldDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinCtrl.text.trim() == 'yemen1995') {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminCoursesScreen()),
                  ).then((_) => _fetchCourses());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('رمز المرور غير صحيح!'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: Text('دخول', style: GoogleFonts.cairo(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearPlaybackCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      int deletedCount = 0;
      for (var f in files) {
        if (f.path.contains('locksel_stream_') || f.path.endsWith('.mp4')) {
          try {
            f.deleteSync();
            deletedCount++;
          } catch (_) {}
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تنظيف الملفات المؤقتة بنجاح ($deletedCount ملفات)'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
  }

  void _openFavoritesDialog() {
    final List<Map<String, dynamic>> favoriteItems = [];
    for (var c in _courses) {
      for (var l in c.lessons) {
        if (l.isFavorite) {
          favoriteItems.add({'course': c, 'lesson': l});
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 580,
            height: 480,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      'الدروس المفضلة',
                      style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                Expanded(
                  child: favoriteItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_border_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                              const SizedBox(height: 8),
                              Text('لم تقم بإضافة أي درس إلى المفضلة بعد.', style: GoogleFonts.cairo(color: AppTheme.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: favoriteItems.length,
                          itemBuilder: (context, i) {
                            final item = favoriteItems[i];
                            final Lesson lesson = item['lesson'];
                            final Course course = item['course'];
                            return Card(
                              color: AppTheme.scaffoldDark,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryBlue, size: 28),
                                title: Text(lesson.title, style: GoogleFonts.cairo(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('مسار: ${course.title} • المدة: ${lesson.duration}', style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 12)),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SecureVideoPlayerScreen(
                                          title: lesson.title,
                                          encryptedFilePath: lesson.videoPath,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text('مشاهدة', style: GoogleFonts.cairo(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
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

  List<Map<String, dynamic>> _getMatchingLessons(String query) {
    String normalizeNumbers(String input) {
      const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
      const englishDigits = '0123456789';
      for (int i = 0; i < arabicDigits.length; i++) {
        input = input.replaceAll(arabicDigits[i], englishDigits[i]);
      }
      return input;
    }

    final raw = normalizeNumbers(query.trim().toLowerCase());
    if (raw.isEmpty) return [];

    final List<Map<String, dynamic>> matches = [];
    final numberSearchMatch = RegExp(r'^(?:درس|الدرس|#)?\s*(\d+)$').firstMatch(raw);

    for (var c in _courses) {
      for (int i = 0; i < c.lessons.length; i++) {
        final lesson = c.lessons[i];
        final normalizedTitle = normalizeNumbers(lesson.title.toLowerCase());

        if (numberSearchMatch != null) {
          final targetNum = numberSearchMatch.group(1)!;
          final exactNumberInTitle = RegExp('(^|[^0-9])' + RegExp.escape(targetNum) + '([^0-9]|\$)');
          
          if (exactNumberInTitle.hasMatch(normalizedTitle)) {
            matches.add({'course': c, 'lesson': lesson, 'index': i + 1});
          }
        } else {
          final titleMatch = normalizedTitle.contains(raw);
          final courseMatch = c.title.toLowerCase().contains(raw);
          final pathMatch = lesson.videoPath.toLowerCase().contains(raw);

          if (titleMatch || courseMatch || pathMatch) {
            matches.add({'course': c, 'lesson': lesson, 'index': i + 1});
          }
        }
      }
    }
    return matches;
  }
  
  @override
  Widget build(BuildContext context) {
    final inProgressCourses = _courses.where((c) => c.progress < 1.0).toList();
    final completedCourses = _courses.where((c) => c.progress >= 1.0 && c.lessons.isNotEmpty).toList();
    final searchResults = _getMatchingLessons(_currentQuery);
    final isSearching = _currentQuery.trim().isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldDark,
        drawer: Drawer(
          backgroundColor: AppTheme.surfaceDark,
          child: Column(
            children: [
             DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.surfaceDark, AppTheme.scaffoldDark],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  border: Border(bottom: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3), width: 1.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryBlue.withOpacity(0.15),
                          radius: 26,
                          child: Icon(AppEdition.editionIcon, color: AppTheme.primaryBlue, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppEdition.shortName,
                                style: GoogleFonts.cairo(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
                                ),
                                child: Text(
                                  AppEdition.editionBadge,
                                  style: GoogleFonts.robotoMono(color: AppTheme.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.star_rounded, color: Colors.amber),
                title: Text('المفضلة', style: GoogleFonts.cairo(color: AppTheme.textMain)),
                onTap: () {
                  Navigator.pop(context);
                  _openFavoritesDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.fingerprint_rounded, color: Colors.tealAccent),
                title: Text('معرّف الجهاز', style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 14)),
                subtitle: Text(_hardwareFingerprint, style: GoogleFonts.robotoMono(color: AppTheme.textSecondary, fontSize: 11)),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_rounded, color: Colors.orangeAccent),
                title: Text('تنظيف الذاكرة المؤقتة', style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 14)),
                subtitle: Text('تفريغ مساحة المشاهدة المؤقتة', style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 11)),
                onTap: _clearPlaybackCache,
              ),
              const Spacer(),
              const Divider(color: Colors.white10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.code_rounded, size: 18, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المطور: dev.Eman', style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('الإصدار: v1.0.0', style: GoogleFonts.robotoMono(color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceDark,
          elevation: 0,
          title: GestureDetector(
            onTap: _handleSecretTap,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.auto_stories_rounded, color: AppTheme.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Icon(AppEdition.editionIcon, color: AppTheme.primaryBlue, size: 24),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppEdition.appName,
                          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        ),
                        Text(
                          AppEdition.editionBadge,
                          style: GoogleFonts.robotoMono(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.star_rounded, color: Colors.amber),
              tooltip: 'المفضلة',
              onPressed: _openFavoritesDialog,
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text('مرخص ومحمي', style: GoogleFonts.cairo(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          bottom: isSearching
              ? null
              : TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primaryBlue,
                  indicatorWeight: 3,
                  labelColor: AppTheme.primaryBlue,
                  unselectedLabelColor: AppTheme.textSecondary,
                  labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timelapse_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text('قيد المذاكرة (${inProgressCourses.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text('المنجزة بالكامل (${completedCourses.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _currentQuery = val;
                    });
                  },
                  style: GoogleFonts.cairo(color: AppTheme.textMain, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم الدرس، اسم المقطع، أو الامتداد (.mp4, .enc)...',
                    hintStyle: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue),
                    suffixIcon: _currentQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _currentQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : isSearching
                      ? _buildSearchResultsList(searchResults)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildCoursesGrid(inProgressCourses, isCompletedTab: false),
                            _buildCoursesGrid(completedCourses, isCompletedTab: true),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'لا توجد مقاطع أو ملفات تطابق "$_currentQuery"',
              style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final item = results[i];
        final Lesson lesson = item['lesson'];
        final Course course = item['course'];

        return Card(
          color: AppTheme.surfaceDark,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
              child: const Icon(Icons.play_arrow_rounded, color: AppTheme.primaryBlue),
            ),
            title: Text(
              lesson.title,
              style: GoogleFonts.cairo(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'المسار: ${course.title} • المدة: ${lesson.duration}',
                  style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 12),
                ),
                Text(
                  'الملف: ${lesson.videoPath}',
                  style: GoogleFonts.robotoMono(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SecureVideoPlayerScreen(
                      title: lesson.title,
                      encryptedFilePath: lesson.videoPath,
                    ),
                  ),
                ).then((_) => _fetchCourses());
              },
              icon: const Icon(Icons.play_circle_filled_rounded, size: 18),
              label: Text('تشغيل الآن', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoursesGrid(List<Course> list, {required bool isCompletedTab}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompletedTab ? Icons.military_tech_outlined : Icons.school_outlined,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isCompletedTab ? 'لم تكتمل أي دورة بعد. واصلي التعلم لتظهر هنا!' : 'لا توجد دورات قيد المذاكرة حالياً.',
              style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420, // أقصى عرض للبطاقة (ستزيد عدد الأعمدة تلقائياً في الشاشات الكبيرة)
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        mainAxisExtent: 380, // تثبيت الارتفاع تماماً لمنع اختناق النصوص أو تمددها
      ),
      
      itemBuilder: (context, index) {
        final course = list[index];
        final progressPercent = (course.progress * 100).toInt();

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isCompletedTab ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
          ),
          clipBehavior: Clip.antiAlias, // مهم لقص حواف الصورة العلوية مع الإطار
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. قسم الصورة العلوية
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Builder(
                      builder: (context) {
                        if (course.imagePath.isNotEmpty) {
                          // استخراج اسم الصورة فقط (يتعامل مع مسارات الويندوز والماك)
                          final imageName = course.imagePath.split('\\').last.split('/').last;
                          // بناء المسار الديناميكي الديناميكي داخل مجلد data/images
                          final exeDir = File(Platform.resolvedExecutable).parent.path;
                          final dynamicImagePath = '$exeDir\\data\\images\\$imageName';
                          
                          // التحقق من وجود الصورة في المسار الجديد
                          if (File(dynamicImagePath).existsSync()) {
                            return Image.file(File(dynamicImagePath), fit: BoxFit.cover);
                          }
                        }
                        
                        // في حال لم تكن هناك صورة، أو لم يتم العثور عليها، نعرض الأيقونة البديلة
                        return Container(
                          color: (isCompletedTab ? Colors.green : AppTheme.primaryBlue).withValues(alpha: 0.08),
                          child: Icon(
                            isCompletedTab ? Icons.verified_rounded : course.iconData,
                            color: isCompletedTab ? Colors.greenAccent.withValues(alpha: 0.5) : AppTheme.primaryBlue.withValues(alpha: 0.5),
                            size: 48,
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                        child: Text(course.duration, style: GoogleFonts.cairo(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. قسم النصوص والنبذة السفلية
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المدرب: ${course.instructor} • ${course.lessons.length} دروس',
                        style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      
                      const SizedBox(height: 8),
                      // النبذة التعريفية (بحد أقصى سطرين)
                      if (course.description.isNotEmpty)
                        Text(
                          course.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.8), height: 1.4),
                        ),

                      const Spacer(),
                      
                      // النسبة المئوية
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isCompletedTab ? 'مكتملة بنجاح 🏆' : 'نسبة الإنجاز',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: isCompletedTab ? Colors.greenAccent : AppTheme.textSecondary,
                                  fontWeight: isCompletedTab ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text(
                                '$progressPercent%',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCompletedTab ? Colors.greenAccent : AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: course.progress,
                              minHeight: 6,
                              backgroundColor: AppTheme.scaffoldDark,
                              valueColor: AlwaysStoppedAnimation<Color>(isCompletedTab ? Colors.greenAccent : AppTheme.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CourseDetailsScreen(course: course)),
                            ).then((_) => _fetchCourses());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCompletedTab ? const Color(0xFF065F46) : AppTheme.primaryBlue,
                            foregroundColor: isCompletedTab ? Colors.white : const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            isCompletedTab ? 'مراجعة الدورة' : 'متابعة المذاكرة',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}