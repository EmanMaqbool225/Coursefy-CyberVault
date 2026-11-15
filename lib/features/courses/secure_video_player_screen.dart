import 'dart:async';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/security/device_identity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_edition.dart';

class SecureVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String encryptedFilePath;
  final VoidCallback? onVideoCompleted;

  const SecureVideoPlayerScreen({
    super.key,
    required this.title,
    required this.encryptedFilePath,
    this.onVideoCompleted,
  });

  @override
  State<SecureVideoPlayerScreen> createState() => _SecureVideoPlayerScreenState();
}

class _SecureVideoPlayerScreenState extends State<SecureVideoPlayerScreen> {
  VideoPlayerController? _controller;
  File? _tempDecryptedFile;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _hasTriggeredCompletion = false;

  // شريط التحكم
  bool _showControls = true;
  Timer? _hideTimer;
  double _currentSpeed = 1.0;

  // إدارة التقديم السلس بالدائرة
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;
  Timer? _debounceSeekTimer;

  // التحكم بالصوت والسطوع
  double _currentVolume = 1.0;
  double _previousVolume = 1.0;
  double _brightnessLevel = 1.0; // 1.0 تعني سطوع كامل، و 0.2 تعني إضاءة ليلية خافتة
  bool _showBrightnessSlider = false;

  // العلامة الهادئة
  String _deviceWatermark = '';

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initDeviceAndVideo();
  }

  Future<void> _initDeviceAndVideo() async {
    final identity = DeviceIdentityService();
    final deviceCode = await identity.getHardwareFingerprint();
    if (mounted) {
      setState(() {
        _deviceWatermark = 'ID: $deviceCode';
      });
    }
    await _decryptAndPlay();
  }

  Future<void> _decryptAndPlay() async {
    try {
      // 1. جلب مسار البرنامج الحالي
      final exeDir = File(Platform.resolvedExecutable).parent;
      // 2. دمج المسار مع مجلد data واسم الخزينة واسم الملف المشفر
      final fullPath = '${exeDir.path}\\data\\${AppEdition.vaultFolderName}\\${widget.encryptedFilePath}';
      
      final file = File(fullPath);
      if (!await file.exists()) {
        throw Exception('ملف الفيديو غير موجود: $fullPath');
      }
      

      final encryptedBytes = await file.readAsBytes();
     final key = enc.Key.fromUtf8(AppEdition.encryptionKey);
      final iv = enc.IV.fromUtf8('LOCKSEL_IV_V1_26');
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}\\coursefy_stream_${DateTime.now().millisecondsSinceEpoch}.mp4';
      _tempDecryptedFile = File(tempPath);
      await _tempDecryptedFile!.writeAsBytes(decrypted, flush: true);

      _controller = VideoPlayerController.file(_tempDecryptedFile!);
      await _controller!.initialize();
      await _controller!.setVolume(_currentVolume);
      await _controller!.play();

      _controller!.addListener(_videoListener);
      _startHideTimer();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;

    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    if (dur > Duration.zero && (dur - pos) <= const Duration(seconds: 2)) {
      if (!_hasTriggeredCompletion) {
        _hasTriggeredCompletion = true;
        widget.onVideoCompleted?.call();
      }
    }

    if (!_isDraggingSlider) {
      setState(() {});
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller != null && _controller!.value.isPlaying && !_isDraggingSlider) {
        setState(() {
          _showControls = false;
          _showBrightnessSlider = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (!_showControls) _showBrightnessSlider = false;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  void _seekTo(double seconds) {
    if (_controller == null) return;
    _debounceSeekTimer?.cancel();
    _debounceSeekTimer = Timer(const Duration(milliseconds: 40), () {
      _controller!.seekTo(Duration(milliseconds: (seconds * 1000).toInt()));
    });
  }

  void _seekRelative(int seconds) {
    if (_controller == null) return;
    final current = _controller!.value.position;
    final target = current + Duration(seconds: seconds);
    _controller!.seekTo(target);
    _startHideTimer();
  }

  void _changeSpeed() {
    final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    int nextIndex = (speeds.indexOf(_currentSpeed) + 1) % speeds.length;
    setState(() {
      _currentSpeed = speeds[nextIndex];
    });
    _controller?.setPlaybackSpeed(_currentSpeed);
    _startHideTimer();
  }

  void _toggleMute() {
    if (_currentVolume > 0) {
      _previousVolume = _currentVolume;
      _setVolume(0.0);
    } else {
      _setVolume(_previousVolume > 0 ? _previousVolume : 1.0);
    }
  }

  void _setVolume(double val) {
    setState(() {
      _currentVolume = val;
    });
    _controller?.setVolume(val);
    _startHideTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _controller != null && _controller!.value.isInitialized) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() {
          _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
        });
        _startHideTimer();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seekRelative(5);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seekRelative(-5);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _setVolume((_currentVolume + 0.1).clamp(0.0, 1.0));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _setVolume((_currentVolume - 0.1).clamp(0.0, 1.0));
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _hideTimer?.cancel();
    _debounceSeekTimer?.cancel();
    _controller?.dispose();
    _focusNode.dispose();
    if (_tempDecryptedFile != null && _tempDecryptedFile!.existsSync()) {
      try {
        _tempDecryptedFile!.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _controller?.value.duration.inSeconds.toDouble() ?? 0.0;
    final position = _controller?.value.position.inSeconds.toDouble() ?? 0.0;
    final currentSliderValue = _isDraggingSlider
        ? _dragValue
        : (position <= duration ? position : duration);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (_) {
              if (!_showControls) {
                setState(() => _showControls = true);
              }
              _startHideTimer();
            },
            child: GestureDetector(
              onTap: _toggleControls,
              child: Stack(
                children: [
                  // شاشة التحميل
                  if (_isLoading)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: AppTheme.primaryBlue),
                          const SizedBox(height: 16),
                          Text(
                            'جاري تحضير البث الآمن للمقطع...',
                            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                  // عرض الفيديو
                  if (!_isLoading && _errorMessage.isEmpty && _controller != null && _controller!.value.isInitialized)
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),

                  // طبقة التحكم في السطوع والإضاءة المريحة (Brightness Dimming Layer)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(alpha: (1.0 - _brightnessLevel) * 0.75),
                      ),
                    ),
                  ),

                  if (_errorMessage.isNotEmpty)
                    Center(
                      child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
                    ),

                  // علامة مائية هادئة في الزاوية
                  Positioned(
                    bottom: 75,
                    right: 20,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _deviceWatermark,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white.withValues(alpha: 0.2),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // الشريط العلوي (العنوان، الإضاءة، الرجوع)
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.title,
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),

                          // منزلق إضاءة الشاشة التفاعلي
                          if (_showBrightnessSlider)
                            Container(
                              width: 140,
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3.0,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                    activeTrackColor: Colors.amberAccent,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: _brightnessLevel,
                                    min: 0.2,
                                    max: 1.0,
                                    onChanged: (val) {
                                      setState(() => _brightnessLevel = val);
                                      _startHideTimer();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              _brightnessLevel > 0.6 ? Icons.brightness_high_rounded : Icons.brightness_medium_rounded,
                              color: Colors.amberAccent,
                              size: 22,
                            ),
                            tooltip: 'التحكم في الإضاءة',
                            onPressed: () {
                              setState(() {
                                _showBrightnessSlider = !_showBrightnessSlider;
                              });
                              _startHideTimer();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // شريط التحكم السفلي المتكامل
                  if (_controller != null && _controller!.value.isInitialized)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black87],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // شريط التقديم والتأخير مع الدائرة
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                                  activeTrackColor: AppTheme.primaryBlue,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                  overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.3),
                                ),
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Slider(
                                    value: currentSliderValue.clamp(0.0, duration > 0 ? duration : 1.0),
                                    min: 0.0,
                                    max: duration > 0 ? duration : 1.0,
                                    onChangeStart: (val) {
                                      setState(() {
                                        _isDraggingSlider = true;
                                        _dragValue = val;
                                      });
                                    },
                                    onChanged: (val) {
                                      setState(() {
                                        _dragValue = val;
                                      });
                                      _seekTo(val);
                                    },
                                    onChangeEnd: (val) {
                                      setState(() {
                                        _isDraggingSlider = false;
                                      });
                                      _seekTo(val);
                                      _startHideTimer();
                                    },
                                  ),
                                ),
                              ),

                              // أزرار التحكم، الصوت، الوقت، والسرعة
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                                      });
                                      _startHideTimer();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 24),
                                    tooltip: 'تأخير 10 ثوانٍ',
                                    onPressed: () => _seekRelative(-10),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 24),
                                    tooltip: 'تقديم 10 ثوانٍ',
                                    onPressed: () => _seekRelative(10),
                                  ),

                                  const SizedBox(width: 8),

                                  // قسم الصوت التفاعلي (Mute + Slider)
                                  IconButton(
                                    icon: Icon(
                                      _currentVolume == 0.0
                                          ? Icons.volume_off_rounded
                                          : _currentVolume < 0.5
                                              ? Icons.volume_down_rounded
                                              : Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: _currentVolume == 0.0 ? 'إلغاء الكتم' : 'كتم الصوت',
                                    onPressed: _toggleMute,
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3.0,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: Colors.white,
                                        ),
                                        child: Slider(
                                          value: _currentVolume,
                                          min: 0.0,
                                          max: 1.0,
                                          onChanged: _setVolume,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),
                                  Text(
                                    '${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}',
                                    style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 13),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: _changeSpeed,
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white10,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      '${_currentSpeed}x',
                                      style: GoogleFonts.robotoMono(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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